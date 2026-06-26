// lib/screens/store/widgets/bottom_action_bar.dart
// Only shows Scan QR button if store has reward points configured.
// Call / Directions / Share are now in the header action row per mockup.
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../qr/qr_page.dart';

class BottomActionBar extends StatelessWidget {
  final Map<String, dynamic> store;
  final String token;
  final int visitPoints;

  const BottomActionBar({
    super.key,
    required this.store,
    required this.token,
    this.visitPoints = 0,
  });

  @override
  Widget build(BuildContext context) {
    // If no reward points, no bottom bar needed (actions are in header)
    if (visitPoints <= 0) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => QRPage(token: token)),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: kPrimary.withValues(alpha: .30),
                    blurRadius: 12,
                    offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Scan & Earn $visitPoints pts',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
