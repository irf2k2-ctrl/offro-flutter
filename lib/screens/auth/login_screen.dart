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
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';
import '../onboarding/onboarding_screen.dart';

PageRoute _offroRoute(Widget w) => MaterialPageRoute(builder: (_) => w);

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
      if (mounted) setState(() {
        _msg = e.toString().replaceAll('Exception: ', '');
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
      if (mounted) setState(() { _msg = e.toString().replaceAll('Exception: ', ''); _msgOk = false; _resending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0d2b24), Color(0xFF1e4a3f), Color(0xFF3E5F55)],
            begin: Alignment.topLeft, end: Alignment.bottomRight))),
        SafeArea(child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const SizedBox(height: 20),
              buildImageLogo(height: 65, white: true),
              const SizedBox(height: 32),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: kLight.withValues(alpha: .15),
                  shape: BoxShape.circle,
                  border: Border.all(color: kLight.withValues(alpha: .3), width: 2),
                ),
                child: const Icon(Icons.lock_outline_rounded, color: kLight, size: 34),
              ),
              const SizedBox(height: 20),
              const Text('Verify Your Number',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('We sent a 4-digit OTP to\n${widget.phone}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: .65), fontSize: 13, height: 1.5)),
              const SizedBox(height: 32),
              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => Container(
                  width: 60, height: 64,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _ctls[i].text.isNotEmpty ? kLight : Colors.white.withValues(alpha: .25),
                      width: _ctls[i].text.isNotEmpty ? 2 : 1.5),
                  ),
                  child: TextField(
                    controller: _ctls[i], focusNode: _foci[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                    onChanged: (v) {
                      setState(() {});
                      if (v.isNotEmpty && i < 3) FocusScope.of(context).requestFocus(_foci[i + 1]);
                      else if (v.isEmpty && i > 0) FocusScope.of(context).requestFocus(_foci[i - 1]);
                      if (_enteredOtp.length == 4) _verify();
                    },
                  ),
                )),
              ),
              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(_msg, textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _msgOk ? kLight : const Color(0xFFFF6B6B),
                    fontSize: 13, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLight, foregroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5))
                    : const Text('Verify OTP',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _resendSecs == 0 ? _resend : null,
                child: _resending
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: kLight, strokeWidth: 2))
                  : RichText(text: TextSpan(children: [
                      TextSpan(text: "Didn't receive OTP? ",
                        style: TextStyle(color: Colors.white.withValues(alpha: .6), fontSize: 13)),
                      TextSpan(
                        text: _resendSecs > 0 ? 'Resend in ${_resendSecs}s' : 'Resend OTP',
                        style: TextStyle(
                          color: _resendSecs > 0 ? Colors.white38 : kLight,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                    ])),
              ),
              const SizedBox(height: 24),
            ]),
          )),
        ])),
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
    setState(() => _loading = true);
    try {
      await widget.onRoleSelected(_selected!, _remember);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(children: [
            // ── Scrollable content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [

                  // Logo
                  buildImageLogo(height: 56, white: false),
                  const SizedBox(height: 28),

                  // Welcome heading
                  const Text('Welcome to Offro! 👋',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1a2e27),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    )),
                  const SizedBox(height: 8),
                  Text('Choose how you want to use Offro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    )),

                  const SizedBox(height: 32),

                  // ── USER card ──
                  _PremiumRoleCard(
                    role: 'user',
                    selected: _selected == 'user',
                    onTap: () => setState(() => _selected = 'user'),
                    title: 'User',
                    desc: 'Explore local stores,\nproducts & offers',
                    supportText: 'Browse nearby businesses and discover savings.',
                    bgColor: const Color(0xFFf0faf4),
                    iconColor: const Color(0xFF3E5F55),
                    icon: Icons.shopping_bag_rounded,
                    emoji: '🛍️',
                  ),

                  const SizedBox(height: 16),

                  // ── MERCHANT card ──
                  _PremiumRoleCard(
                    role: 'merchant',
                    selected: _selected == 'merchant',
                    onTap: () => setState(() => _selected = 'merchant'),
                    title: 'Merchant',
                    desc: 'Manage your business,\ngrow your store',
                    supportText: 'Create offers, products and manage your store with ease.',
                    bgColor: const Color(0xFFf0f5ff),
                    iconColor: const Color(0xFF2c5fd4),
                    icon: Icons.storefront_rounded,
                    emoji: '🏪',
                  ),

                  const SizedBox(height: 28),

                  // ── Remember my choice ──
                  GestureDetector(
                    onTap: () => setState(() => _remember = !_remember),
                    behavior: HitTestBehavior.opaque,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: _remember ? kPrimary : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _remember ? kPrimary : const Color(0xFFd0d0d0),
                            width: 1.8),
                        ),
                        child: _remember
                          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                          : null,
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Remember my choice',
                          style: TextStyle(
                            color: Color(0xFF1a2e27),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          )),
                        const SizedBox(height: 2),
                        Text('You can change this anytime from Profile',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ]),
                    ]),
                  ),

                ]),
              ),
            ),

            // ── Sticky Continue button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selected == null || _loading) ? null : _proceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFc8d8d2),
                    disabledForegroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                    elevation: _selected != null ? 4 : 0,
                    shadowColor: kPrimary.withValues(alpha: .35),
                  ),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        _selected == null
                          ? 'Select a role to continue'
                          : 'Continue  →',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 0.3,
                        )),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Premium Role Card ────────────────────────────────────────────────────────
class _PremiumRoleCard extends StatelessWidget {
  final String role, title, desc, supportText, emoji;
  final bool selected;
  final VoidCallback onTap;
  final Color bgColor, iconColor;
  final IconData icon;

  const _PremiumRoleCard({
    required this.role, required this.title, required this.desc,
    required this.supportText, required this.emoji,
    required this.selected, required this.onTap,
    required this.bgColor, required this.iconColor, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? kPrimary : const Color(0xFFe8e8e8),
            width: selected ? 2.0 : 1.2),
          boxShadow: [
            BoxShadow(
              color: selected
                ? kPrimary.withValues(alpha: .12)
                : Colors.black.withValues(alpha: .05),
              blurRadius: selected ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Illustration / Icon circle
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: selected
                ? iconColor.withValues(alpha: .12)
                : Colors.grey.withValues(alpha: .07),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 2),
                Icon(icon, color: selected ? iconColor : Colors.grey[400], size: 16),
              ]),
            ),
          ),

          const SizedBox(width: 16),

          // Text content
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(title,
              style: TextStyle(
                color: selected ? iconColor : const Color(0xFF1a2e27),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              )),
            const SizedBox(height: 6),
            Text(desc,
              style: TextStyle(
                color: selected ? const Color(0xFF1a2e27) : const Color(0xFF444444),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              )),
            const SizedBox(height: 6),
            Text(supportText,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                height: 1.4,
              )),
          ])),

          // Checkmark badge
          const SizedBox(width: 8),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: selected ? 1.0 : 0.0,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: kPrimary,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: kPrimary.withValues(alpha: .3),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
            ),
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
      body: Stack(children: [
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0d2b24), Color(0xFF1e4a3f), Color(0xFF3E5F55)],
            begin: Alignment.topLeft, end: Alignment.bottomRight))),
        SafeArea(child: FadeTransition(
          opacity: _fade,
          child: Center(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              buildImageLogo(height: 72, white: true),
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

  Future<void> _switch(String role) async {
    if (role == widget.currentMode || _loading) return;
    setState(() { _loading = true; _msg = ''; });
    try {
      // One account, one identity — no separate merchant record needed.
      // Any registered user can switch to merchant mode freely.
      await Prefs.saveMode(role);
      if (mounted) Navigator.pop(context);
      widget.onSwitch(role);
    } catch (e) {
      if (mounted) setState(() { _msg = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const Text('Switch Mode',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kPrimary)),
        const SizedBox(height: 6),
        Text('You are currently in ${widget.currentMode == "user" ? "User" : "Merchant"} mode',
          style: const TextStyle(fontSize: 12.5, color: kMuted)),
        const SizedBox(height: 24),
        _ModeTile(
          emoji: '👤', title: 'User',
          subtitle: 'Browse stores, products and offers',
          active: widget.currentMode == 'user',
          onTap: _loading ? null : () => _switch('user'),
        ),
        const SizedBox(height: 12),
        _ModeTile(
          emoji: '🏪', title: 'Merchant',
          subtitle: 'Manage store, products and banners',
          active: widget.currentMode == 'merchant',
          onTap: _loading ? null : () => _switch('merchant'),
        ),
        if (_msg.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFfde8e6), borderRadius: BorderRadius.circular(10)),
            child: Text(_msg, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 12.5)),
          ),
        ],
        if (_loading) ...[
          const SizedBox(height: 20),
          const CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5),
        ],
      ]),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String emoji, title, subtitle;
  final bool active;
  final VoidCallback? onTap;
  const _ModeTile({
    required this.emoji, required this.title, required this.subtitle,
    required this.active, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active ? kLight.withValues(alpha: .18) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? kPrimary : kBorder,
            width: active ? 2 : 1.2),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
              style: TextStyle(
                color: active ? kPrimary : kText,
                fontWeight: FontWeight.w800, fontSize: 15)),
            Text(subtitle,
              style: const TextStyle(color: kMuted, fontSize: 11.5)),
          ])),
          if (active)
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: kPrimary, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
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
  final void Function(String token, String name, String phone, String userId, String role)? onSuccess;
  const LoginScreen({super.key, this.onSuccess});
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
    _phoneC.dispose(); _nameC.dispose();
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
        final err = sendResp?['message']?.toString() ?? 'Failed to send OTP.';
        _setMsg(err); return;
      }
      final reqId = sendResp['message']?.toString() ?? '';
      if (!mounted) return;
      setState(() => _loading = false);

      // Show OTP screen
      Navigator.push(context, _offroRoute(OtpScreen(
        phone: phone,
        reqId: reqId,
        onVerified: () async {
          // OTP passed → show Continue As screen
          if (!mounted) return;
          await Navigator.push(context, _offroRoute(ContinueAsScreen(
            phone: phone,
            onRoleSelected: (role, remember) async {
              await _handleRoleSelected(phone, role, remember);
            },
          )));
        },
      )));
    } catch (e) {
      _setMsg(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRoleSelected(String phone, String role, bool remember) async {
    try {
      Map<String, dynamic> d;
      String token, name, userId;
      Map? merchantMap;

      // Always use unified /account-login — one token for all roles
      d     = await Api.loginAccount(phone);
      token = d['token']?.toString() ?? '';
      name  = d['name']?.toString()  ?? '';
      if (token.isEmpty) throw Exception('Login failed: no token received.');

      final roles       = (d['roles'] as List?)?.map((r) => r.toString()).toList() ?? [role];
      final isMerchant  = roles.contains('merchant');
      userId            = isMerchant
          ? (d['merchant_id']?.toString() ?? d['account_id']?.toString() ?? '')
          : (d['user_id']?.toString()     ?? d['account_id']?.toString() ?? '');

      await Prefs.save(token, name, phone, role, userId: userId);
      await Prefs.saveRoles(roles);
      if (isMerchant) await Prefs.saveMerchantId(d['merchant_id']?.toString() ?? '');
      await Prefs.saveMode(role);
      await Prefs.saveRememberMode(remember);

      if (mounted && widget.onSuccess != null) {
        // Pop ContinueAsScreen cleanly before navigating to home/merchant
        // so the stack doesn't have stale screens causing infinite loading
        Navigator.of(context).popUntil((r) => r.isFirst);
        widget.onSuccess!(token, name, phone, userId, role);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ── Full-screen gradient background ──
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0b2218), Color(0xFF1a3d33), Color(0xFF2d5548), Color(0xFF3E5F55)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter))),

        // ── Decorative circles (top-right) ──
        Positioned(top: -60, right: -60, child: Container(
          width: 220, height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kLight.withValues(alpha: .07)))),
        Positioned(top: 40, right: -20, child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kAccent.withValues(alpha: .1)))),

        SafeArea(child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(children: [
            // ── TOP: Logo area ──
            const SizedBox(height: 36),
            buildImageLogo(height: 58, white: true),
            const SizedBox(height: 8),
            const Text('Discover · Save · Earn',
              style: TextStyle(color: Colors.white38, fontSize: 11.5, letterSpacing: 1.6)),

            const Spacer(flex: 1),

            // ── BOTTOM CARD: slide-up form ──
            SlideTransition(
              position: _slideAnim,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // ── Tab: Login | Register ──
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F2),
                        borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        _tabBtn('Login', !_isReg, () => setState(() { _isReg = false; _msg = ''; })),
                        _tabBtn('Register', _isReg,  () => setState(() { _isReg = true;  _msg = ''; })),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // Name field (register only)
                    if (_isReg) ...[
                      _label('Your Name'),
                      _field(_nameC, 'e.g. Rahul Kumar', Icons.person_outline_rounded, keyboardType: TextInputType.name),
                      const SizedBox(height: 16),
                    ],

                    // Phone field
                    _label('Mobile Number'),
                    _phoneField(),
                    const SizedBox(height: 20),

                    // Terms (register only)
                    if (_isReg) ...[
                      GestureDetector(
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 20, height: 20, margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: _agreed ? kPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: _agreed ? kPrimary : kBorder, width: 1.6)),
                            child: _agreed
                              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                              : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Wrap(children: [
                            const Text('I agree to the ', style: TextStyle(fontSize: 12, color: kMuted)),
                            GestureDetector(
                              onTap: () => _showPolicy('Terms', Api.fetchTerms('user')),
                              child: const Text('Terms', style: TextStyle(fontSize: 12, color: kPrimary, decoration: TextDecoration.underline, fontWeight: FontWeight.bold))),
                            const Text(' & ', style: TextStyle(fontSize: 12, color: kMuted)),
                            GestureDetector(
                              onTap: () => _showPolicy('Privacy Policy', Api.fetchPolicy('privacy')),
                              child: const Text('Privacy Policy', style: TextStyle(fontSize: 12, color: kPrimary, decoration: TextDecoration.underline, fontWeight: FontWeight.bold))),
                          ])),
                        ]),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Error/Success message
                    if (_msg.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: _msgOk ? const Color(0xFFd1f0e0) : const Color(0xFFfde8e6),
                          borderRadius: BorderRadius.circular(10)),
                        child: Text(_msg, textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _msgOk ? const Color(0xFF1a6640) : Colors.red.shade700,
                            fontSize: 12.5)),
                      ),
                    ],

                    // Send OTP button
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          disabledBackgroundColor: kAccent.withValues(alpha: .4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(_isReg ? 'Register & Get OTP' : 'Get OTP',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Social bar
                    _socialBar(),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) =>
    Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 6, offset: const Offset(0, 2))] : null,
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? kPrimary : kMuted,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            fontSize: 14)),
      ),
    ));

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: kText, fontWeight: FontWeight.w700, fontSize: 13.5)));

  Widget _field(TextEditingController c, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text}) =>
    TextField(
      controller: c,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: kText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFb0c9c0)),
        prefixIcon: Icon(icon, color: kMuted, size: 20),
        filled: true, fillColor: const Color(0xFFF7FAF8),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kPrimary, width: 2)),
      ),
    );

  Widget _phoneField() =>
    TextField(
      controller: _phoneC,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      style: const TextStyle(fontSize: 15, color: kText, letterSpacing: 0.5),
      decoration: InputDecoration(
        hintText: '10-digit mobile number',
        hintStyle: const TextStyle(color: Color(0xFFb0c9c0), fontSize: 14),
        counterText: '',
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🇮🇳', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            const Text('+91', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            Container(width: 1, height: 18, color: kBorder, margin: const EdgeInsets.only(left: 8)),
          ]),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true, fillColor: const Color(0xFFF7FAF8),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kPrimary, width: 2)),
      ),
    );

  void _showPolicy(String title, Future<String> loader) async {
    final c = await loader;
    if (!mounted) return;
    showDialog(context: context, builder: (_) => OffroDialog(title: title, body: c));
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
        return Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          _socialIcon(wa.isNotEmpty ? 'https://wa.me/$wa' : '', const Color(0xFF25D366), Icons.chat_rounded, 'WhatsApp', active: wa.isNotEmpty),
          _socialIcon(insta.isNotEmpty ? 'https://instagram.com/$insta' : '', const Color(0xFFE1306C), Icons.camera_alt_rounded, 'Instagram', active: insta.isNotEmpty),
          _socialIcon(fb.isNotEmpty ? 'https://facebook.com/$fb' : '', const Color(0xFF1877F2), Icons.facebook_rounded, 'Facebook', active: fb.isNotEmpty),
          _socialIcon(yt.isNotEmpty ? 'https://youtube.com/@$yt' : '', const Color(0xFFFF0000), Icons.play_circle_fill_rounded, 'YouTube', active: yt.isNotEmpty),
        ]));
      },
    );
  }

  Widget _socialIcon(String url, Color color, IconData icon, String label, {bool active = false}) {
    if (!active) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () async {
        if (url.isEmpty) return;
        try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch(_) {}
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
    title: Text(title, style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w800)),
    content: SingleChildScrollView(child: Text(body, style: const TextStyle(fontSize: 13, color: kText, height: 1.6))),
    actions: [TextButton(onPressed: () => Navigator.pop(context),
      child: const Text('Close', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)))],
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}
