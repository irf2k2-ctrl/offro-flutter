// lib/screens/legal/privacy_policy_page.dart
//
// Privacy Policy page (+ Delete Account flow) for the USER app.
// Extracted unchanged from lib/main.dart; only the imports are new.
// (Merchant equivalents live in merchant_screens.dart.)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/error_mapper.dart';
import '../../core/services/fcm_service.dart';
import '../../core/services/prefs_service.dart';
import '../../core/utils/navigation.dart';
import '../../main.dart' show MyApp;
import '../../core/design/design.dart';



// ══════════════════════════════════════════════════════════════════════════════
// PRIVACY POLICY PAGE — with Read More + Delete Account flow
// ══════════════════════════════════════════════════════════════════════════════
class PrivacyPolicyPage extends StatefulWidget {
  final String token;
  const PrivacyPolicyPage({required this.token, super.key});
  @override State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  String _content = "";
  bool _loading = true;
  bool _expanded = false;

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await Api.fetchPolicy("privacy");
    if (mounted) setState(() { _content = c; _loading = false; });
  }

  @override Widget build(BuildContext context) {
    // Typography / layout only — the policy text itself is rendered exactly
    // as fetched (Api.fetchPolicy("privacy")); nothing is rewritten or shortened.
    return OffroFontScope(child: Scaffold(
      backgroundColor: OffroColors.background,
      body: SafeArea(
        bottom: false,
        child: _loading
          ? Column(children: [
              const OffroScreenHeader(eyebrow: "Legal", title: "Privacy Policy", showBack: true),
              const Expanded(child: Center(child: CircularProgressIndicator(color: OffroColors.primary))),
            ])
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                const OffroScreenHeader(eyebrow: "Legal", title: "Privacy Policy", showBack: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 20, OffroSpacing.gutter, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_content.isEmpty)
                          Text("Privacy policy content is being updated. Please check back later.",
                            style: OffroText.bodySmall.copyWith(fontSize: 14, color: OffroColors.textMuted))
                        else ...[
                          Text(
                            _expanded ? _content : (_content.length > 280 ? _content.substring(0, 280) + "..." : _content),
                            style: OffroText.body.copyWith(fontSize: 14, height: 1.65),
                          ),
                          if (_content.length > 280) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => setState(() => _expanded = !_expanded),
                              child: Text(
                                _expanded ? "Read Less" : "Read More",
                                style: OffroText.button.copyWith(color: OffroColors.primary, fontSize: 13),
                              ),
                            ),
                          ],
                        ],
                      ]),
                    ),
                    const SizedBox(height: 28),
                    Text("ACCOUNT",
                      style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.8, color: OffroColors.sage)),
                    const SizedBox(height: 12),
                    // "Request to delete my account" tile
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                        appRoute(DeleteAccountReasonPage(token: widget.token))),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: OffroColors.error.withValues(alpha: .10),
                              shape: BoxShape.circle),
                            child: const Icon(Icons.person_remove_rounded, color: OffroColors.error, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Request to delete my account",
                                style: OffroText.cardTitle.copyWith(fontSize: 13, color: OffroColors.error)),
                              const SizedBox(height: 2),
                              Text("All your data will be permanently removed",
                                style: OffroText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w400, color: OffroColors.textSubtle)),
                            ],
                          )),
                          const OffroIcon(OffroIcons.chevron, size: 14, color: Color(0x40000000)),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
      ),
    ));
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// DELETE ACCOUNT — Reason selection page (Customer app)
// ══════════════════════════════════════════════════════════════════════════════
class DeleteAccountReasonPage extends StatefulWidget {
  final String token;
  const DeleteAccountReasonPage({required this.token, super.key});
  @override State<DeleteAccountReasonPage> createState() => _DeleteAccountReasonPageState();
}

class _DeleteAccountReasonPageState extends State<DeleteAccountReasonPage> {
  String? _selectedReason;
  final _reasons = [
    "I no longer use the app",
    "I have privacy concerns",
    "I have a duplicate account",
    "Too many notifications or irrelevant content",
    "Other",
  ];

  @override Widget build(BuildContext context) {
    return OffroFontScope(child: Scaffold(
      backgroundColor: OffroColors.background,
      body: SafeArea(
        child: Column(children: [
          const OffroScreenHeader(eyebrow: "Account", title: "Delete Account", showBack: true),
          Container(
            margin: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 20, OffroSpacing.gutter, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OffroColors.amber.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: OffroColors.amber, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(
                "Once your account is deleted, your data cannot be retrieved. Signing up again will create a new account.",
                style: OffroText.bodySmall.copyWith(fontSize: 12.5, height: 1.45, color: OffroColors.text),
              )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 12, OffroSpacing.gutter, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Select a reason for deleting your account",
                style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: OffroColors.primary.withValues(alpha: .7))),
            ),
          ),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: OffroSpacing.gutter),
            itemCount: _reasons.length,
            itemBuilder: (ctx, i) {
              final r = _reasons[i];
              final selected = _selectedReason == r;
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = r),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? OffroColors.primary : Colors.transparent, width: 1.2),
                  ),
                  child: Row(children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: selected ? OffroColors.primary : OffroColors.textPlaceholder, size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r,
                      style: OffroText.cardTitle.copyWith(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? OffroColors.primary : OffroColors.text,
                      )),
                    ),
                  ]),
                ),
              );
            },
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 8, OffroSpacing.gutter, 24),
            child: SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _selectedReason == null ? null : () => _showConfirmDialog(),
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: Text("Submit Delete Request", style: OffroText.button.copyWith(color: Colors.white, fontSize: 13.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OffroColors.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: OffroColors.error.withValues(alpha: .3),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ]),
      ),
    ));
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Account?", style: TextStyle(fontFamily: OffroFonts.sans, fontWeight: FontWeight.w800, color: kText)),
        content: Text(
          "Your account will be marked for deletion. You will be logged out immediately and cannot log in again.\n\nOnce deleted, your data cannot be retrieved. Are you absolutely sure?",
          style: TextStyle(fontFamily: OffroFonts.sans, fontSize: 14, color: kText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(fontFamily: OffroFonts.sans, color: kMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitDeletion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Yes, Delete", style: TextStyle(fontFamily: OffroFonts.sans, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDeletion() async {
    try {
      await Api.requestDeleteAccount(widget.token, _selectedReason!);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Deletion Requested", style: TextStyle(fontFamily: OffroFonts.sans, fontWeight: FontWeight.w800, color: kText)),
          content: Text(
            "Your account deletion request has been submitted. You have been logged out.",
            style: TextStyle(fontFamily: OffroFonts.sans, fontSize: 14, color: kText),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await Prefs.clear();
                FcmService.reset();
                Api.clearCache();
                MyApp.goOnboarding();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text("OK", style: TextStyle(fontFamily: OffroFonts.sans, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[OffrO] delete account request error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit: ${friendlyError(e)}"),
          backgroundColor: Colors.red),
      );
    }
  }
}
