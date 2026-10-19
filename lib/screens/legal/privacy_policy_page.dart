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
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text("Privacy Policy", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: kPrimary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Policy text
              if (_content.isEmpty)
                const Text("Privacy policy content is being updated. Please check back later.",
                  style: TextStyle(color: kMuted, fontSize: 14))
              else ...[
                Text(
                  _expanded ? _content : (_content.length > 280 ? _content.substring(0, 280) + "..." : _content),
                  style: const TextStyle(fontSize: 14, color: kText, height: 1.6),
                ),
                if (_content.length > 280) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? "Read Less" : "Read More",
                      style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 32),
              // Delete account section
              const Divider(height: 1, color: kBorder),
              const SizedBox(height: 16),
              // "Request to delete my account" tile
              GestureDetector(
                onTap: () => Navigator.push(context,
                  appRoute(DeleteAccountReasonPage(token: widget.token))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_remove_rounded, color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Request to delete my account",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.red)),
                        const SizedBox(height: 2),
                        Text("All your data will be permanently removed",
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                      ],
                    )),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.red),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
            ]),
          ),
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text("Delete Account", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(
              "Once your account is deleted, your data cannot be retrieved. Signing up again will create a new account.",
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900, height: 1.4),
            )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text("Select a reason for deleting your account",
              style: TextStyle(fontSize: 13, color: kMuted, fontWeight: FontWeight.w500)),
          ),
        ),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _reasons.length,
          itemBuilder: (ctx, i) {
            final r = _reasons[i];
            final selected = _selectedReason == r;
            return GestureDetector(
              onTap: () => setState(() => _selectedReason = r),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? kPrimary.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? kPrimary : kBorder),
                ),
                child: Row(children: [
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? kPrimary : kMuted, size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? kPrimary : kText,
                    )),
                  ),
                ]),
              ),
            );
          },
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedReason == null ? null : () => _showConfirmDialog(),
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: const Text("Submit Delete Request", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.red.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Account?", style: TextStyle(fontWeight: FontWeight.w800, color: kText)),
        content: const Text(
          "Your account will be marked for deletion. You will be logged out immediately and cannot log in again.\n\nOnce deleted, your data cannot be retrieved. Are you absolutely sure?",
          style: TextStyle(fontSize: 14, color: kText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: kMuted, fontWeight: FontWeight.w600)),
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
            child: const Text("Yes, Delete", style: TextStyle(fontWeight: FontWeight.w700)),
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
          title: const Text("Deletion Requested", style: TextStyle(fontWeight: FontWeight.w800, color: kText)),
          content: const Text(
            "Your account deletion request has been submitted. You have been logged out.",
            style: TextStyle(fontSize: 14, color: kText),
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
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w700)),
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
