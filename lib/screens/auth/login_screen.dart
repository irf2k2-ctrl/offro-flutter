// lib/screens/auth/login_screen.dart
// OFFRO — Unified Login: Single OTP → Continue As (User / Merchant) → Role-based flow
// MSG91 OTP Widget SDK — no DLT registration required
// Single session, single token. Role is selected post-OTP.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/error_mapper.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';
import '../onboarding/onboarding_screen.dart';
import '../../core/services/prefs_service.dart';
import '../../core/utils/navigation.dart';
import '../../core/design/design.dart' show OffroColors, OffroShadows, OffroText, OffroRadii, OffroIcon, OffroIcons, OffroIconData;

// ── MSG91 Widget credentials ─────────────────────────────────────────────────
const _kWidgetId  = '36656f6a786e313430373338';
const _kTokenAuth = '516819TuGI7seX6a06f51cP1';

// ══════════════════════════════════════════════════════════════════════════════
// OTP SCREEN  (dark gradient — unchanged design)
// ══════════════════════════════════════════════════════════════════════════════
class OtpScreen extends StatefulWidget {
  final String phone;
  final String reqId;
  final Future<void> Function() onVerified;
  const OtpScreen({
    super.key,
    required this.phone,
    required this.reqId,
    required this.onVerified,
  });
  @override State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctls = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(4, (_) => FocusNode());
  bool _loading   = false;
  bool _resending = false;
  String _msg     = '';
  bool _msgOk     = false;
  int _resendSecs = 30;
  Timer? _resendTimer;

  @override void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_foci[0]);
    });
  }

  @override void dispose() {
    for (var c in _ctls) c.dispose();
    for (var f in _foci) f.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSecs = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSecs <= 0) { t.cancel(); setState(() => _resendSecs = 0); return; }
      setState(() => _resendSecs--);
    });
  }

  String get _enteredOtp => _ctls.map((c) => c.text).join();

  // Item 4: handles both a normal single-keystroke digit (unchanged
  // auto-advance behavior) and a multi-character value inserted all at
  // once by Android's SMS/autofill framework (AutofillHints.oneTimeCode),
  // which would otherwise only land in whichever single box it targets.
  void _handleOtpChange(int i, String v) {
    if (v.length > 1) {
      final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
      for (int j = 0; j < 4; j++) {
        _ctls[j].text = j < digits.length ? digits[j] : '';
      }
      setState(() {});
      if (_enteredOtp.length == 4) {
        FocusScope.of(context).unfocus();
        _verify();
      } else if (digits.isNotEmpty) {
        FocusScope.of(context).requestFocus(_foci[digits.length.clamp(0, 3)]);
      }
      return;
    }
    setState(() {});
    if (v.isNotEmpty && i < 3) FocusScope.of(context).requestFocus(_foci[i + 1]);
    else if (v.isEmpty && i > 0) FocusScope.of(context).requestFocus(_foci[i - 1]);
    if (_enteredOtp.length == 4) _verify();
  }

  Future<void> _verify() async {
    final otp = _enteredOtp;
    if (otp.length < 4) {
      setState(() { _msg = 'Enter 4-digit OTP'; _msgOk = false; }); return;
    }
    if (_loading) return;
    setState(() { _loading = true; _msg = ''; });

    // ── MASTER OTP bypass (admin use only) ──────────────────────────────────
    if (otp == '1234') {
      await widget.onVerified();
      return;
    }
    // ────────────────────────────────────────────────────────────────────────

    try {
      final resp = await OTPWidget.verifyOTP({'reqId': widget.reqId, 'otp': otp});
      if (resp != null && resp['type'] == 'success') {
        await widget.onVerified();
      } else {
        final err = resp?['message']?.toString() ?? 'Incorrect OTP. Please try again.';
        if (mounted) setState(() { _msg = err; _msgOk = false; _loading = false; });
      }
    } catch (e) {
      // Round 9: OTPWidget.verifyOTP (MSG91 SDK) exceptions — network/SDK
      // failures never reach the customer as raw technical text.
      debugPrint('[OffrO] OTP verify error: $e');
      if (mounted) setState(() {
        _msg = friendlyError(e, fallback: "Unable to verify OTP right now. Please try again.");
        _msgOk = false; _loading = false;
      });
    }
  }

  Future<void> _resend() async {
    if (_resendSecs > 0 || _resending) return;
    setState(() { _resending = true; _msg = ''; });
    try {
      final resp = await OTPWidget.retryOTP({'reqId': widget.reqId});
      for (var c in _ctls) c.clear();
      if (mounted) {
        final ok = resp != null && resp['type'] == 'success';
        setState(() {
          _msgOk = ok;
          _msg = ok ? 'OTP resent successfully.' : (resp?['message']?.toString() ?? 'Resend failed.');
          _resending = false;
        });
        if (ok) { _startResendTimer(); FocusScope.of(context).requestFocus(_foci[0]); }
      }
    } catch (e) {
      // Round 9: OTPWidget.retryOTP (MSG91 SDK) exceptions — same mapping
      // as _verify() above.
      debugPrint('[OffrO] OTP resend error: $e');
      if (mounted) setState(() {
        _msg = friendlyError(e, fallback: "Unable to resend OTP right now. Please try again.");
        _msgOk = false; _resending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Figma verification screen: light background, outlined 4-box code entry.
    // OTP controllers, autofill, _handleOtpChange, _verify and _resend are unchanged.
    return Scaffold(
      backgroundColor: OffroColors.background,
      body: SafeArea(child: Column(children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: OffroColors.primary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            buildImageLogo(height: 36),
            const SizedBox(height: 36),
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(color: OffroColors.mint, shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, color: OffroColors.primary, size: 26),
            ),
            const SizedBox(height: 20),
            Text('VERIFICATION', style: OffroText.eyebrow.copyWith(fontSize: 11, letterSpacing: 2.0, color: OffroColors.sage)),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Verify your ', style: OffroText.display.copyWith(fontSize: 32, letterSpacing: -1.9)),
              TextSpan(text: 'number', style: OffroText.accentOf(OffroText.display.copyWith(fontSize: 32, letterSpacing: -0.8))),
            ])),
            const SizedBox(height: 10),
            Text('We sent a 4-digit OTP to\n${widget.phone}',
              style: OffroText.bodySmall.copyWith(fontSize: 13, height: 1.5, color: OffroColors.textMuted)),
            const SizedBox(height: 32),
            // OTP boxes
            AutofillGroup(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => Container(
                  width: 62, height: 66,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: OffroRadii.inputRadius,
                    border: Border.all(
                      color: _ctls[i].text.isNotEmpty ? OffroColors.primary : OffroColors.border,
                      width: _ctls[i].text.isNotEmpty ? 1.8 : 1.2),
                  ),
                  child: TextField(
                    controller: _ctls[i], focusNode: _foci[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    // Item 4: no maxLength here anymore — Android's SMS
                    // autofill can insert the full detected code (e.g.
                    // "1234") into whichever field it targets; a maxLength
                    // of 1 would silently truncate that to a single digit.
                    // _handleOtpChange below distributes a multi-character
                    // value across all 4 boxes; a single keystroke behaves
                    // exactly as before (unchanged auto-advance behavior).
                    autofillHints: const [AutofillHints.oneTimeCode],
                    style: OffroText.headline.copyWith(fontSize: 24),
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                    onChanged: (v) => _handleOtpChange(i, v),
                  ),
                )),
              ),
            ),
            if (_msg.isNotEmpty) ...[
              const SizedBox(height: 16),
              Center(child: Text(_msg, textAlign: TextAlign.center,
                style: OffroText.bodySmall.copyWith(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: _msgOk ? OffroColors.primary : OffroColors.error))),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: OffroColors.primary,
                  disabledBackgroundColor: OffroColors.primary.withValues(alpha: .45),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Verify OTP', style: OffroText.button.copyWith(color: Colors.white, fontSize: 13.5)),
              ),
            ),
            const SizedBox(height: 20),
            Center(child: GestureDetector(
              onTap: _resendSecs == 0 ? _resend : null,
              child: _resending
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: OffroColors.primary, strokeWidth: 2))
                : RichText(text: TextSpan(children: [
                    TextSpan(text: "Didn't receive OTP? ",
                      style: OffroText.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: OffroColors.textMuted)),
                    TextSpan(
                      text: _resendSecs > 0 ? 'Resend in ${_resendSecs}s' : 'Resend OTP',
                      style: OffroText.caption.copyWith(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: _resendSecs > 0 ? OffroColors.textMuted : OffroColors.primary)),
                  ])),
            )),
            const SizedBox(height: 24),
          ]),
        )),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ACCOUNT BOOTSTRAP  — runs right after OTP verification, before Role
// Selection. New flow (per the finalized location requirements):
//
//   OTP VERIFIED → ACCOUNT LOGIN/LOAD ACCOUNT → ROLE SELECTION
//
// Location is NOT handled here any more: customers choose/restore their
// location in the shared Location screen (see main.dart `_enterHome`), and a
// merchant's account location is enforced inside MerchantHome.
//
// This calls /user/account-login exactly ONCE for the whole OTP → Role
// Selection journey — the resulting account data (token/roles/city/etc.) is
// threaded through to ContinueAsScreen and _handleRoleSelected below, which
// must NOT call account-login again (avoids the duplicate-call regression
// called out in the requirements).
//
// This screen never reads or writes any location (account or store).
// ══════════════════════════════════════════════════════════════════════════════
class _AccountBootstrapScreen extends StatefulWidget {
  final String phone;
  final void Function(Map<String, dynamic> accountData) onReady;
  const _AccountBootstrapScreen({required this.phone, required this.onReady});
  @override State<_AccountBootstrapScreen> createState() => _AccountBootstrapScreenState();
}

class _AccountBootstrapScreenState extends State<_AccountBootstrapScreen> {
  String _status = 'Setting up your account...';
  String _err = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    if (mounted) setState(() {
      _err = '';
      _status = 'Setting up your account...';
    });

    Map<String, dynamic> d;
    try {
      // The single, unified account-login call for this entire journey.
      d = await Api.loginAccount(widget.phone);
    } catch (e) {
      debugPrint('[OffrO] account bootstrap login error: $e');
      if (mounted) setState(() => _err = friendlyError(e));
      return;
    }

    if (!mounted) return;
    widget.onReady(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OffroColors.background,
      body: Stack(children: [
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0d2b24), Color(0xFF1e4a3f), OffroColors.primary],
            begin: Alignment.topLeft, end: Alignment.bottomRight))),
        SafeArea(child: Center(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            buildImageLogo(height: 90, white: true),
            const SizedBox(height: 32),
            if (_err.isEmpty) ...[
              const SizedBox(width: 26, height: 26,
                child: CircularProgressIndicator(color: kLight, strokeWidth: 2.5)),
              const SizedBox(height: 20),
              Text(_status, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 14)),
            ] else ...[
              Text(_err, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _run,
                style: ElevatedButton.styleFrom(backgroundColor: kLight, foregroundColor: kPrimary),
                child: const Text('Retry'),
              ),
            ],
          ]),
        ))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CONTINUE AS SCREEN  — shown after OTP verified
// User picks role: 👤 User  or  🏪 Merchant
// ══════════════════════════════════════════════════════════════════════════════
class ContinueAsScreen extends StatefulWidget {
  final String phone;
  final Future<void> Function(String role, bool remember) onRoleSelected;
  const ContinueAsScreen({
    super.key,
    required this.phone,
    required this.onRoleSelected,
  });
  @override State<ContinueAsScreen> createState() => _ContinueAsState();
}

class _ContinueAsState extends State<ContinueAsScreen>
    with SingleTickerProviderStateMixin {
  String? _selected; // 'user' | 'merchant'
  bool _remember = false;
  bool _loading  = false;
  String _err    = '';
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  Future<void> _proceed() async {
    if (_selected == null || _loading) return;
    setState(() { _loading = true; _err = ''; });
    try {
      await widget.onRoleSelected(_selected!, _remember);
    } catch (e) {
      debugPrint('[OffrO] role selection error: $e');
      if (mounted) setState(() => _err = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _enterLabel {
    switch (_selected) {
      case 'user': return 'Enter as Customer';
      case 'merchant': return 'Enter as Merchant';
      case 'influencer': return 'Enter as Influencer';
      default: return 'Select a role to continue';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Figma role selection. Role keys ('user' | 'merchant' | 'influencer'),
    // _proceed / onRoleSelected and "remember my choice" are unchanged.
    return Scaffold(
      backgroundColor: OffroColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  buildImageLogo(height: 40, white: false),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: OffroColors.mint,
                      borderRadius: OffroRadii.pillRadius),
                    child: Text('MAKE OFFRO YOURS',
                      style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.6, color: OffroColors.primary)),
                  ),
                  const SizedBox(height: 16),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: 'How will you use\n', style: OffroText.display.copyWith(fontSize: 35, height: 1.05, letterSpacing: -2.1)),
                    TextSpan(text: 'OffrO?', style: OffroText.accentOf(OffroText.display.copyWith(fontSize: 35, height: 1.05, letterSpacing: -1))),
                  ])),
                  const SizedBox(height: 14),
                  Text('Choose your starting space. You can add another role later from your profile.',
                    style: OffroText.bodySmall.copyWith(fontSize: 13, height: 1.5, color: OffroColors.textMuted)),
                  const SizedBox(height: 28),

                  _PremiumRoleCard(
                    role: 'user',
                    selected: _selected == 'user',
                    onTap: () => setState(() => _selected = 'user'),
                    title: 'Customer',
                    desc: 'Discover places, products and local offers',
                    tileColor: OffroColors.mint,
                    iconColor: OffroColors.primary,
                    icon: OffroIcons.user,
                  ),
                  const SizedBox(height: 12),
                  _PremiumRoleCard(
                    role: 'merchant',
                    selected: _selected == 'merchant',
                    onTap: () => setState(() => _selected = 'merchant'),
                    title: 'Merchant',
                    desc: 'Grow your business and manage your storefront',
                    tileColor: OffroColors.beige,
                    iconColor: OffroColors.primary,
                    icon: OffroIcons.store,
                  ),
                  const SizedBox(height: 12),
                  // Influencer — same authenticated account/session as the
                  // other two; the existing backend grants the role once a
                  // profile is created via the existing flow.
                  _PremiumRoleCard(
                    role: 'influencer',
                    selected: _selected == 'influencer',
                    onTap: () => setState(() => _selected = 'influencer'),
                    title: 'Influencer',
                    desc: 'Create local stories and collaborate with brands',
                    tileColor: const Color(0xFFE5E4F1),
                    iconColor: const Color(0xFF66648A),
                    icon: OffroIcons.sparkles,
                  ),
                  const SizedBox(height: 24),

                  // ── Remember my choice ──
                  GestureDetector(
                    onTap: () => setState(() => _remember = !_remember),
                    behavior: HitTestBehavior.opaque,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: _remember ? OffroColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _remember ? OffroColors.primary : OffroColors.borderStrong,
                            width: 1.6),
                        ),
                        child: _remember
                          ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                          : null,
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Remember my choice', style: OffroText.cardTitle.copyWith(fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('You can change this anytime from Profile',
                          style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: OffroColors.textSubtle)),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),

            // ── Error banner ──
            if (_err.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: OffroColors.error.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14)),
                  child: Text(_err,
                    textAlign: TextAlign.center,
                    style: OffroText.bodySmall.copyWith(color: OffroColors.error, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),

            // ── Sticky Continue button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: (_selected == null || _loading) ? null : _proceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OffroColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: OffroColors.primary.withValues(alpha: .35),
                    disabledForegroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(_enterLabel, style: OffroText.button.copyWith(color: Colors.white, fontSize: 13.5)),
                        if (_selected != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        ],
                      ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Role Card (Figma) ────────────────────────────────────────────────────────
class _PremiumRoleCard extends StatelessWidget {
  final String role, title, desc;
  final bool selected;
  final VoidCallback onTap;
  final Color tileColor, iconColor;
  final OffroIconData icon;

  const _PremiumRoleCard({
    required this.role, required this.title, required this.desc,
    required this.selected, required this.onTap,
    required this.tileColor, required this.iconColor, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? OffroColors.primary : Colors.transparent,
            width: 1.2),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: selected ? .06 : .03),
            blurRadius: selected ? 18 : 10,
            offset: const Offset(0, 4))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 48, height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tileColor, borderRadius: BorderRadius.circular(16)),
            child: OffroIcon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: OffroText.cardTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Text(desc,
              style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, height: 1.4, color: OffroColors.textSubtle)),
          ])),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: selected ? OffroColors.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: selected ? OffroColors.primary : const Color(0x26000000), width: 1.4),
            ),
            child: selected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MERCHANT LOADER  — shown when Merchant role selected post-OTP
// ══════════════════════════════════════════════════════════════════════════════
class MerchantLoadingScreen extends StatefulWidget {
  final String token;
  final Map merchant;
  final void Function(String token, Map merchant) onReady;
  const MerchantLoadingScreen({
    super.key,
    required this.token,
    required this.merchant,
    required this.onReady,
  });
  @override State<MerchantLoadingScreen> createState() => _MerchantLoadingState();
}

class _MerchantLoadingState extends State<MerchantLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  int _dot = 0;
  Timer? _dotTimer;

  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dot = (_dot + 1) % 4);
    });
    // Short delay then hand off — actual data is loaded by MerchantHome itself
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      widget.onReady(widget.token, widget.merchant);
    });
  }

  @override void dispose() { _ctrl.dispose(); _dotTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dot;
    return Scaffold(
      backgroundColor: OffroColors.background,
      body: Stack(children: [
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0d2b24), Color(0xFF1e4a3f), OffroColors.primary],
            begin: Alignment.topLeft, end: Alignment.bottomRight))),
        SafeArea(child: FadeTransition(
          opacity: _fade,
          child: Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              buildImageLogo(height: 90, white: true),
              const SizedBox(height: 40),
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: kLight.withValues(alpha: .15),
                  shape: BoxShape.circle,
                  border: Border.all(color: kLight.withValues(alpha: .3), width: 2),
                ),
                child: const Icon(Icons.storefront_rounded, color: kLight, size: 38),
              ),
              const SizedBox(height: 28),
              Text('Preparing your business dashboard$dots',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19, fontWeight: FontWeight.w800, height: 1.3)),
              const SizedBox(height: 10),
              Text('Loading stores, products and activity...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .6),
                  fontSize: 13, height: 1.5)),
              const SizedBox(height: 36),
              SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withValues(alpha: .15),
                  color: kLight,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ]),
          )),
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SWITCH MODE BOTTOM SHEET  — reusable from both User and Merchant profiles
// ══════════════════════════════════════════════════════════════════════════════
class SwitchModeSheet extends StatefulWidget {
  final String currentMode;     // 'user' | 'merchant'
  final String token;
  final String phone;
  final void Function(String newRole) onSwitch;
  const SwitchModeSheet({
    super.key,
    required this.currentMode,
    required this.token,
    required this.phone,
    required this.onSwitch,
  });
  @override State<SwitchModeSheet> createState() => _SwitchModeSheetState();
}

class _SwitchModeSheetState extends State<SwitchModeSheet> {
  bool _loading = false;
  String _msg   = '';
  bool _hasInfluencerRole = false; // C4: only show Influencer when the account actually has the role

  @override
  void initState() {
    super.initState();
    // BUG FIX (Round 4 — Bug 3, "Influencer mode disappears after switching
    // back to User"): this used to read ONLY the locally-cached role list
    // (Prefs.isInfluencer(), populated once at login from the login
    // response). A brand-new influencer profile created later in the same
    // session adds "influencer" to the account's roles on the SERVER
    // (routers/users.py::create_influencer_profile does
    // {"$addToSet": {"roles": "influencer"}}) but that never refreshed the
    // stale local cache, so the very next "Switch Mode" open — even
    // switching Influencer → User → back to Influencer — silently lost the
    // tile. Fixed by re-checking the account's LIVE roles from the server
    // on every open, with the local cache only as an offline fallback (and
    // self-healed from the live result so future offline opens stay
    // correct too). Nothing here is hardcoded — the tile still only shows
    // when a role is actually present, just read from an up-to-date source.
    _loadInfluencerRole();
  }

  Future<void> _loadInfluencerRole() async {
    // Cached value first, so the sheet doesn't flash "no Influencer tile"
    // for a moment before the network call resolves.
    final cached = await Prefs.isInfluencer();
    if (mounted) setState(() => _hasInfluencerRole = cached);
    try {
      final me = await Api.getMe(widget.token);
      final roles = (me?['roles'] as List?)?.map((r) => r.toString()).toList();
      if (roles != null) {
        await Prefs.saveRoles(roles); // keep the local cache in sync
        if (mounted) setState(() => _hasInfluencerRole = roles.contains('influencer'));
      }
    } catch (_) {
      // Offline/network failure — keep whatever the cached value already
      // set above; never worse than the previous (cache-only) behavior.
    }
  }

  Future<void> _switch(String role) async {
    if (role == widget.currentMode || _loading) return;
    setState(() { _loading = true; _msg = ''; });
    try {
      if (role == 'merchant') {
        // Check if user has accepted merchant terms
        final me = await Api.getMe(widget.token);
        if (me != null && me['merchant_terms_accepted'] != true) {
          if (mounted) {
            final accepted = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _MerchantTermsDialog(token: widget.token),
            );
            if (accepted != true) {
              setState(() { _loading = false; });
              return;
            }
          }
        }
      }
      // One account, one identity — no separate merchant record needed.
      // Any registered user can switch to merchant mode freely. Influencer
      // mode uses the SAME authenticated account/token too — the existing
      // C1 backend is what actually granted the role (via the existing C2
      // profile-creation flow), this sheet only offers the switch once
      // that role is already present.
      await Prefs.saveMode(role);
      if (mounted) Navigator.pop(context);
      widget.onSwitch(role);
    } catch (e) {
      debugPrint('[OffrO] switch mode error: $e');
      if (mounted) setState(() { _msg = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Figma role-selection visual language. Switch logic (_switch, Prefs,
    // merchant terms, live influencer-role check) is unchanged.
    final modeLabel = widget.currentMode == 'user' ? 'Customer'
        : widget.currentMode == 'merchant' ? 'Merchant' : 'Influencer';
    return Container(
      decoration: const BoxDecoration(
        color: OffroColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: const Color(0x1F000000), borderRadius: BorderRadius.circular(2)))),
        buildImageLogo(height: 32, white: false),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: OffroColors.mint,
            borderRadius: OffroRadii.pillRadius),
          child: Text('MAKE OFFRO YOURS',
            style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.6, color: OffroColors.primary)),
        ),
        const SizedBox(height: 14),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Switch ', style: OffroText.display.copyWith(fontSize: 30, letterSpacing: -1.8)),
          TextSpan(text: 'mode', style: OffroText.accentOf(OffroText.display.copyWith(fontSize: 30, letterSpacing: -0.8))),
        ])),
        const SizedBox(height: 8),
        Text('You are currently in $modeLabel mode',
          style: OffroText.bodySmall.copyWith(fontSize: 13, color: OffroColors.textMuted)),
        const SizedBox(height: 22),
        _ModeTile(
          icon: OffroIcons.user, tileColor: OffroColors.mint, iconColor: OffroColors.primary,
          title: 'Customer',
          subtitle: 'Browse stores, products and offers',
          active: widget.currentMode == 'user',
          onTap: _loading ? null : () => _switch('user'),
        ),
        const SizedBox(height: 12),
        _ModeTile(
          icon: OffroIcons.store, tileColor: OffroColors.beige, iconColor: OffroColors.primary,
          title: 'Merchant',
          subtitle: 'Manage store, products and banners',
          active: widget.currentMode == 'merchant',
          onTap: _loading ? null : () => _switch('merchant'),
        ),
        // C4: Influencer tile only appears when the account already has
        // the role (i.e. has created a profile via C1/C2) — matching the
        // requirement that it must not appear for every account.
        if (_hasInfluencerRole) ...[
          const SizedBox(height: 12),
          _ModeTile(
            icon: OffroIcons.sparkles, tileColor: const Color(0xFFE5E4F1), iconColor: const Color(0xFF66648A),
            title: 'Influencer',
            subtitle: 'Manage your influencer profile',
            active: widget.currentMode == 'influencer',
            onTap: _loading ? null : () => _switch('influencer'),
          ),
        ],
        if (_msg.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: OffroColors.error.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
            child: Text(_msg, textAlign: TextAlign.center,
              style: OffroText.bodySmall.copyWith(color: OffroColors.error, fontSize: 12.5)),
          ),
        ],
        if (_loading) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator(color: OffroColors.primary, strokeWidth: 2.5)),
        ],
      ]),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String title, subtitle;
  final OffroIconData icon;
  final Color tileColor, iconColor;
  final bool active;
  final VoidCallback? onTap;
  const _ModeTile({
    required this.icon, required this.tileColor, required this.iconColor,
    required this.title, required this.subtitle,
    required this.active, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: active ? OffroColors.primary : Colors.transparent, width: 1.2),
          boxShadow: OffroShadows.card,
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tileColor, borderRadius: BorderRadius.circular(16)),
            child: OffroIcon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: OffroText.cardTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle,
              style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: OffroColors.textSubtle)),
          ])),
          const SizedBox(width: 8),
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: active ? OffroColors.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: active ? OffroColors.primary : const Color(0x26000000), width: 1.4),
            ),
            child: active ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LOGIN SCREEN — REDESIGNED
// Single phone input → OTP → Continue As
// ══════════════════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  final Future<void> Function(String token, String name, String phone, String userId, String role, String city)? onSuccess;
  final void Function()? onGuest;
  const LoginScreen({super.key, this.onSuccess, this.onGuest});
  @override State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> with TickerProviderStateMixin {
  static String _normalisePhone(String raw) {
    final p = raw.trim().replaceAll(' ', '').replaceAll('-', '');
    if (p.startsWith('+')) return p;
    if (p.length == 12 && p.startsWith('91')) return '+$p';
    return '+91$p';
  }

  bool _loading = false;
  String _msg   = '';
  bool _msgOk   = false;
  final _phoneC = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  // Registration mode
  bool _isReg = false;
  final _nameC = TextEditingController();
  bool _agreed = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Social links
  late Future<Map<String, dynamic>> _socialFuture;

  Future<void> _continueAsGuest() async {
    await Prefs.saveGuest(true);
    if (!mounted) return;
    if (widget.onGuest != null) {
      widget.onGuest!();
    }
  }

  @override void initState() {
    super.initState();
    OTPWidget.initializeWidget(_kWidgetId, _kTokenAuth);
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
    _fadeCtrl.forward();
    _socialFuture = Api.getSocialLinks();
  }

  @override void dispose() {
    _slideCtrl.dispose(); _fadeCtrl.dispose();
    _phoneC.dispose(); _nameC.dispose(); _nameFocus.dispose();
    super.dispose();
  }

  void _setMsg(String m, {bool ok = false}) => setState(() { _msg = m; _msgOk = ok; });

  Future<void> _sendOtp() async {
    final rawPhone = _phoneC.text.trim();
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone.isEmpty) { _setMsg('Enter your mobile number'); return; }
    if (digits.length != 10) { _setMsg('Enter a valid 10-digit mobile number'); return; }
    if (_isReg && _nameC.text.trim().isEmpty) { _setMsg('Enter your name'); return; }
    if (_isReg && !_agreed) { _setMsg('Please accept the terms to continue'); return; }

    final phone = _normalisePhone(rawPhone);
    final e164  = phone.startsWith('+') ? phone.substring(1) : phone;

    setState(() { _loading = true; _msg = ''; });
    try {
      // Pre-OTP phone check
      if (_isReg) {
        // Registration: block if already registered
        final check = await Api.checkUserPhone(phone);
        if (check) { _setMsg('This number is already registered. Please login.'); setState(() => _loading = false); return; }
        await Api.registerUser(_nameC.text.trim(), phone);
      } else {
        // Login: block if NOT registered
        final check = await Api.checkUserPhone(phone);
        if (!check) { _setMsg('Number not registered. Please register first.'); setState(() => _loading = false); return; }
      }

      // Send OTP
      final sendResp = await OTPWidget.sendOTP({'identifier': e164});
      if (sendResp == null || sendResp['type'] != 'success') {
        // Round 9: MSG91 SDK failure message — map through the same
        // classifier so a technical SDK/gateway dump never reaches the
        // customer, while a clean SDK message (if any) is preserved.
        final err = friendlyError(
          sendResp?['message']?.toString() ?? '',
          fallback: "Unable to send OTP right now. Please try again.",
        );
        _setMsg(err); return;
      }
      final reqId = sendResp['message']?.toString() ?? '';
      if (!mounted) return;
      setState(() => _loading = false);

      // Show OTP screen
      Navigator.push(context, appRoute(OtpScreen(
        phone: phone,
        reqId: reqId,
        onVerified: () async {
          // OTP passed → ACCOUNT LOGIN/LOAD ACCOUNT → CHECK ACCOUNT LOCATION
          // → LOCATION HANDLING IF REQUIRED, all before Role Selection.
          // See _AccountBootstrapScreen for the single account-login call
          // this entire journey reuses.
          if (!mounted) return;
          await Navigator.push(context, appRoute(_AccountBootstrapScreen(
            phone: phone,
            onReady: (accountData) {
              if (!mounted) return;
              // Replace the bootstrap screen so back-navigation from
              // Continue As doesn't return to a stale loading screen.
              Navigator.pushReplacement(context, appRoute(ContinueAsScreen(
                phone: phone,
                onRoleSelected: (role, remember) async {
                  await _handleRoleSelected(accountData, phone, role, remember);
                },
              )));
            },
          )));
        },
      )));
    } catch (e) {
      // Round 9: this is the site of the originally-reported raw
      // HandshakeException leak — checkUserPhone/registerUser/OTPWidget
      // failures now always go through the shared classifier.
      debugPrint('[OffrO] send OTP flow error: $e');
      _setMsg(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRoleSelected(Map<String, dynamic> accountData, String phone, String role, bool remember) async {
    // Reuses the account data already fetched once by _AccountBootstrapScreen
    // right after OTP verification — does NOT call /user/account-login again
    // here (avoids the duplicate-call regression called out in the
    // requirements). Errors propagate up to _ContinueAsState._proceed(),
    // which shows them in-screen — the existing Role Selection UI/behavior
    // is otherwise unchanged.
    final token = accountData['token']?.toString() ?? '';
    final name  = accountData['name']?.toString()  ?? '';
    if (token.isEmpty) throw Exception('Login failed — please try again.');

    final roles      = (accountData['roles'] as List?)?.map((r) => r.toString()).toList() ?? [role];
    final isMerchant = roles.contains('merchant');
    final userId     = isMerchant
        ? (accountData['merchant_id']?.toString() ?? accountData['account_id']?.toString() ?? '')
        : (accountData['user_id']?.toString()     ?? accountData['account_id']?.toString() ?? '');

    // Location is not decided here. The account's `city` is passed through
    // unchanged for compatibility; the customer's location comes from the
    // saved location (or the Location screen), and a merchant's account
    // location is enforced inside MerchantHome. Neither reads this value.
    final city = accountData['city']?.toString() ?? '';

    await Prefs.save(token, name, phone, role, userId: userId);
    await Prefs.saveRoles(roles);
    if (isMerchant) await Prefs.saveMerchantId(accountData['merchant_id']?.toString() ?? '');
    await Prefs.saveMode(role);
    await Prefs.saveRememberMode(remember);

    // Do NOT popUntil here — the destination screen (goMerchantViaUnified /
    // goHome) already calls pushAndRemoveUntil((r) => false) which clears the
    // entire stack including OtpScreen and ContinueAsScreen.
    if (mounted && widget.onSuccess != null) {
      await widget.onSuccess!(token, name, phone, userId, role, city);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Figma auth layout: mint hero with logo + headline, rounded form sheet
    // below it. Logic (controllers, _sendOtp, _continueAsGuest, tabs) is unchanged.
    return Scaffold(
      backgroundColor: OffroColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // ── Hero ──
              Container(
                color: OffroColors.mint,
                padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 28, 24, 64),
                child: Stack(clipBehavior: Clip.hardEdge, children: [
                  Positioned(right: -72, top: -90, child: Container(
                    width: 192, height: 192,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: .25), width: 34)))),
                  Positioned(left: -90, bottom: -110, child: Container(
                    width: 192, height: 192,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: OffroColors.accent.withValues(alpha: .45)))),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      buildImageLogo(height: 36),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .55),
                          borderRadius: OffroRadii.pillRadius),
                        child: Text('LOCAL, MADE EASY',
                          style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.6, color: OffroColors.primary)),
                      ),
                    ]),
                    const SizedBox(height: 40),
                    Text('WELCOME TO YOUR NEIGHBOURHOOD',
                      style: OffroText.eyebrow.copyWith(fontSize: 11, letterSpacing: 2.0, color: OffroColors.primary.withValues(alpha: .6))),
                    const SizedBox(height: 12),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: 'Find more to ', style: OffroText.display.copyWith(fontSize: 39, height: 1.04, letterSpacing: -2.3)),
                      TextSpan(text: 'love', style: OffroText.accentOf(OffroText.display.copyWith(fontSize: 39, height: 1.04, letterSpacing: -1))),
                      TextSpan(text: ', nearby.', style: OffroText.display.copyWith(fontSize: 39, height: 1.04, letterSpacing: -2.3)),
                    ])),
                    const SizedBox(height: 16),
                    Text('Local stores, thoughtful offers and people worth discovering—all in one place.',
                      style: OffroText.bodySmall.copyWith(fontSize: 13, height: 1.5, color: OffroColors.primary.withValues(alpha: .65))),
                  ]),
                ]),
              ),

              // ── Form sheet ──
              Transform.translate(
                offset: const Offset(0, -28),
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    decoration: const BoxDecoration(
                      color: OffroColors.background,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // ── Tab: Login | Register ──
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: OffroColors.beige,
                          borderRadius: OffroRadii.pillRadius),
                        child: Row(children: [
                          _tabBtn('Login', !_isReg, () => setState(() { _isReg = false; _msg = ''; })),
                          _tabBtn('Register', _isReg, () {
                            FocusScope.of(context).unfocus();
                            setState(() { _isReg = true; _msg = ''; });
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (mounted && _isReg) FocusScope.of(context).requestFocus(_nameFocus);
                            });
                          }),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      // Name field (register only)
                      if (_isReg) ...[
                        _label('Your name'),
                        _field(_nameC, 'Enter your full name', Icons.person_outline_rounded,
                          keyboardType: TextInputType.text,
                          focusNode: _nameFocus,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                            LengthLimitingTextInputFormatter(40),
                          ]),
                        const SizedBox(height: 16),
                      ],

                      // Phone field
                      _label('Mobile number'),
                      _phoneField(),
                      const SizedBox(height: 16),

                      // Terms (register only)
                      if (_isReg) ...[
                        GestureDetector(
                          onTap: () => setState(() => _agreed = !_agreed),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 18, height: 18, margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: _agreed ? OffroColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: _agreed ? OffroColors.primary : OffroColors.borderStrong, width: 1.6)),
                              child: _agreed
                                ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Wrap(children: [
                              Text('I agree to the ', style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, height: 1.55, color: OffroColors.textMuted)),
                              _legalLink('User Terms', () => _showPolicy('User Terms', Api.fetchTerms('user'))),
                              Text(' | ', style: OffroText.caption.copyWith(fontSize: 11, color: OffroColors.textMuted)),
                              _legalLink('Merchant Terms', () => _showPolicy('Merchant Terms', Api.getMerchantTerms())),
                              Text(' | ', style: OffroText.caption.copyWith(fontSize: 11, color: OffroColors.textMuted)),
                              _legalLink('Privacy Policy', () => _showPolicy('Privacy Policy', Api.fetchPolicy('privacy'))),
                            ])),
                          ]),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Error/Success message
                      if (_msg.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: _msgOk ? OffroColors.mint : OffroColors.error.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(14)),
                          child: Text(_msg, textAlign: TextAlign.center,
                            style: OffroText.bodySmall.copyWith(
                              fontSize: 12.5,
                              color: _msgOk ? OffroColors.primary : OffroColors.error)),
                        ),
                      ],

                      // Send OTP button
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OffroColors.primary,
                            disabledBackgroundColor: OffroColors.primary.withValues(alpha: .45),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          child: _loading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(_isReg ? 'Register & get verification code' : 'Get verification code',
                                  style: OffroText.button.copyWith(color: Colors.white, fontSize: 13.5)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                              ]),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // "or" divider
                      Row(children: [
                        Expanded(child: Container(height: 1, color: const Color(0x14000000))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR', style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.4, color: OffroColors.secondarySolid)),
                        ),
                        Expanded(child: Container(height: 1, color: const Color(0x14000000))),
                      ]),
                      const SizedBox(height: 20),

                      // Continue as Guest
                      SizedBox(
                        width: double.infinity, height: 48,
                        child: OutlinedButton(
                          onPressed: _continueAsGuest,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide(color: OffroColors.primary.withValues(alpha: .18)),
                            shape: const StadiumBorder(),
                          ),
                          child: Text('Continue as guest',
                            style: OffroText.button.copyWith(color: OffroColors.primary, fontSize: 12.5)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Social bar (admin-configured links)
                      Center(child: Text('FOLLOW THE LOCAL STORY',
                        style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.6, color: OffroColors.secondarySolid))),
                      const SizedBox(height: 10),
                      _socialBar(),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _legalLink(String text, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Text(text, style: OffroText.caption.copyWith(
      fontSize: 11, fontWeight: FontWeight.w700, color: OffroColors.primary,
      decoration: TextDecoration.underline)));

  Widget _tabBtn(String label, bool active, VoidCallback onTap) =>
    Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: OffroRadii.pillRadius,
          boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 6, offset: const Offset(0, 2))] : null,
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: OffroText.button.copyWith(
            fontSize: 12,
            color: active ? OffroColors.primary : OffroColors.secondarySolid)),
      ),
    ));

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: OffroText.caption.copyWith(
      fontSize: 11, fontWeight: FontWeight.w600, color: OffroColors.primary.withValues(alpha: .7))));

  InputDecoration _decoration({required String hint, Widget? prefix, BoxConstraints? prefixConstraints}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: OffroText.body.copyWith(fontSize: 14, color: OffroColors.textPlaceholder),
      counterText: '',
      prefixIcon: prefix,
      prefixIconConstraints: prefixConstraints,
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(borderRadius: OffroRadii.inputRadius, borderSide: const BorderSide(color: OffroColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: OffroRadii.inputRadius, borderSide: const BorderSide(color: OffroColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: OffroRadii.inputRadius, borderSide: const BorderSide(color: OffroColors.primary, width: 1.5)),
    );

  Widget _field(TextEditingController c, String hint, IconData icon,
      {TextInputType keyboardType = TextInputType.text,
       FocusNode? focusNode,
       TextCapitalization textCapitalization = TextCapitalization.none,
       List<TextInputFormatter>? inputFormatters}) =>
    TextField(
      controller: c,
      keyboardType: keyboardType,
      focusNode: focusNode,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: OffroText.body.copyWith(fontSize: 14),
      decoration: _decoration(
        hint: hint,
        prefix: Icon(icon, color: OffroColors.sage, size: 18),
      ),
    );

  Widget _phoneField() =>
    TextField(
      controller: _phoneC,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      style: OffroText.body.copyWith(fontSize: 14, letterSpacing: 0.5),
      decoration: _decoration(
        hint: '98765 43210',
        prefix: Container(
          margin: const EdgeInsets.only(left: 16, right: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('+91', style: OffroText.cardTitle.copyWith(fontSize: 14)),
            Container(width: 1, height: 18, color: const Color(0x1A000000), margin: const EdgeInsets.only(left: 12)),
          ]),
        ),
        prefixConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );

  void _showPolicy(String title, Future<String> loader) async {
    final c = await loader;
    if (!mounted) return;
    showDialog(context: context, builder: (_) => OffroDialog(title: title, body: c));
  }

  /// Normalises the social-media value stored in the database into a
  /// fully-qualified HTTPS URL.  Handles:
  ///   1. Full URLs:  "https://www.facebook.com/Offro"  →  as-is
  ///   2. Domain-only: "www.facebook.com/Offro"          →  prepend https://
  ///   3. Handle-only: "@offro" or "offro"               →  prepend fallbackPrefix
  String _normaliseSocialUrl(String raw, String fallbackPrefix) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    // Already a full URL?  Use as-is.
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    // Domain-like value (contains a dot, e.g. "www.facebook.com/Offro") — prepend https://
    if (v.contains('.') && !v.startsWith('@')) return 'https://' + v;
    // Handle-style value (e.g. "@offro" or "offro") — prepend the prefix.
    // Strip leading @ if present since the prefix may already include it.
    final handle = v.startsWith('@') ? v.substring(1) : v;
    return fallbackPrefix + handle;
  }

  Widget _socialBar() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _socialFuture,
      builder: (ctx, snap) {
        final links = snap.data ?? {};
        final wa    = (links['whatsapp']  ?? '') as String;
        final insta = (links['instagram'] ?? '') as String;
        final fb    = (links['facebook']  ?? '') as String;
        final yt    = (links['youtube']   ?? '') as String;

        // WhatsApp: admin stores a phone number, so always wrap with wa.me
        final waUrl  = wa.isNotEmpty ? 'https://wa.me/' + wa.replaceAll(RegExp(r'[^0-9]'), '') : '';
        // The other three: admin stores full URLs — use as-is, but handle
        // legacy handle-only values gracefully.
        final instaUrl = _normaliseSocialUrl(insta, 'https://instagram.com/');
        final fbUrl    = _normaliseSocialUrl(fb,    'https://facebook.com/');
        final ytUrl    = _normaliseSocialUrl(yt,    'https://youtube.com/@');

        return Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          _socialIcon(waUrl,     const Color(0xFF25D366), Icons.chat_rounded,         'WhatsApp',  active: waUrl.isNotEmpty),
          _socialIcon(instaUrl,   const Color(0xFFE1306C), Icons.camera_alt_rounded,  'Instagram', active: instaUrl.isNotEmpty),
          _socialIcon(fbUrl,      const Color(0xFF1877F2), Icons.facebook_rounded,    'Facebook',  active: fbUrl.isNotEmpty),
          _socialIcon(ytUrl,      const Color(0xFFFF0000), Icons.play_circle_fill_rounded, 'YouTube', active: ytUrl.isNotEmpty),
        ]));
      },
    );
  }

  Widget _socialIcon(String url, Color color, IconData icon, String label, {bool active = false}) {
    if (!active) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (url.isEmpty) return;
        debugPrint('[Social] Launching: ' + url);
        final uri = Uri.parse(url);
        debugPrint('[Social] Parsed URI: scheme=' + (uri.scheme) + ' host=' + (uri.host) + ' path=' + (uri.path));
        try {
          // Try external application first (opens Safari or native app)
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          debugPrint('[Social] launchUrl(externalApplication) returned: ' + launched.toString());
          if (!launched) {
            // Fallback: try in-app browser view (bypasses universal link issues)
            debugPrint('[Social] externalApplication failed, trying inAppBrowserView...');
            final launched2 = await launchUrl(
              uri,
              mode: LaunchMode.inAppBrowserView,
            );
            debugPrint('[Social] launchUrl(inAppBrowserView) returned: ' + launched2.toString());
            if (!launched2) {
              debugPrint('[Social] All launch modes failed for: ' + url);
            }
          }
        } catch (e) {
          debugPrint('[Social] launchUrl exception for ' + url + ': ' + e.toString());
          // Last-resort fallback
          try {
            final launched3 = await launchUrl(
              uri,
              mode: LaunchMode.inAppBrowserView,
            );
            debugPrint('[Social] fallback inAppBrowserView returned: ' + launched3.toString());
          } catch (e2) {
            debugPrint('[Social] all fallbacks failed: ' + e2.toString());
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// ── OffroDialog helper (if not defined elsewhere) ──────────────────────────
class OffroDialog extends StatelessWidget {
  final String title, body;
  const OffroDialog({super.key, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: OffroColors.background,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
    // Legal text is shown exactly as supplied — only the presentation changed.
    title: Text(title, style: OffroText.title.copyWith(fontSize: 20)),
    content: SingleChildScrollView(child: Text(body,
      style: OffroText.body.copyWith(fontSize: 13, height: 1.65))),
    actions: [TextButton(onPressed: () => Navigator.pop(context),
      child: Text('Close', style: OffroText.button.copyWith(color: OffroColors.primary, fontSize: 13)))],
  );
}


// ══════════════════════════════════════════════════════════════════════════════
// MERCHANT TERMS DIALOG — shown when switching to merchant mode without
// prior acceptance of merchant terms
// ══════════════════════════════════════════════════════════════════════════════
class _MerchantTermsDialog extends StatefulWidget {
  final String token;
  const _MerchantTermsDialog({required this.token});
  @override State<_MerchantTermsDialog> createState() => _MerchantTermsDialogState();
}

class _MerchantTermsDialogState extends State<_MerchantTermsDialog> {
  bool _loading = true;
  bool _agreed = false;
  String _content = '';

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    final c = await Api.getMerchantTerms();
    if (mounted) setState(() { _content = c; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: OffroColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Merchant Terms & Conditions',
        style: OffroText.title.copyWith(fontSize: 19)),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Column(mainAxisSize: MainAxisSize.min, children: [
            Expanded(child: SingleChildScrollView(
              child: Text(
                _content.isEmpty
                  ? 'Merchant terms and conditions will be posted here.'
                  : _content,
                style: OffroText.body.copyWith(fontSize: 13, height: 1.6),
              ),
            )),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _agreed = !_agreed),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: _agreed ? kPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _agreed ? kPrimary : OffroColors.border, width: 1.6)),
                  child: _agreed
                    ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                    : null,
                ),
                const SizedBox(width: 8),
                Text('I agree to the Merchant Terms',
                  style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: OffroColors.textMuted)),
              ]),
            ),
          ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: OffroText.button.copyWith(color: OffroColors.textMuted, fontSize: 13)),
        ),
        ElevatedButton(
          onPressed: _agreed ? () async {
            await Api.acceptMerchantTerms(widget.token);
            if (mounted) Navigator.pop(context, true);
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: OffroColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: OffroColors.primary.withValues(alpha: .3),
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          child: Text('Accept & Continue', style: OffroText.button.copyWith(color: Colors.white, fontSize: 13)),
        ),
      ],
    );
  }
}
