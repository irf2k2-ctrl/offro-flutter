// lib/screens/payment/payment_success_screen.dart
import 'package:flutter/material.dart';

// ─── Inline colour constants (mirrors app_constants.dart) ───────────────
const Color _kPrimary = Color(0xFF3E5F55);
const Color _kBg      = Color(0xFFFDFBF6);
const Color _kLight   = Color(0xFFCDEBD6);
const Color _kMuted   = Color(0xFF6b8c7e);

class PaymentSuccessScreen extends StatelessWidget {
  final String storeName;
  final String invoiceNo;
  final VoidCallback onDone;

  const PaymentSuccessScreen({
    super.key,
    required this.storeName,
    required this.invoiceNo,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Success icon ──────────────────────────────────────
                Container(
                  width: 90, height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1a6640),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
                ),
                const SizedBox(height: 24),

                const Text(
                  "Payment Successful!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  storeName.isNotEmpty
                      ? 'Your "$storeName" purchase is now pending admin approval.'
                      : 'Your purchase is now pending admin approval.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _kMuted, fontSize: 15),
                ),

                // ── Invoice badge ─────────────────────────────────────
                if (invoiceNo.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kLight.withOpacity(.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long, color: _kPrimary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Invoice: $invoiceNo",
                          style: const TextStyle(
                            color: _kPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Info box ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFd1f0e0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF1a6640)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Admin will review and activate your purchase within 24 hours.",
                          style: TextStyle(color: Color(0xFF1a6640), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Button ────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onDone,   // ← calls the callback passed from merchant_screens.dart
                    child: const Text(
                      "Back to Home",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
