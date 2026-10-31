// lib/screens/store/widgets/bottom_action_bar.dart
// Only shows Scan QR button if store has reward points configured.
// Call / Directions / Share are now in the header action row per mockup.
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../qr/qr_page.dart';
import '../../../core/design/design.dart';

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


/// Figma "Scan the store QR" card — lives INSIDE Store Detail (QR is not a
/// bottom-nav tab). Shown only when the store really has visit points
/// configured; opens the existing QRPage scanner.
class StoreScanQrCard extends StatelessWidget {
  final String token;
  final int visitPoints;
  const StoreScanQrCard({super.key, required this.token, required this.visitPoints});

  @override
  Widget build(BuildContext context) {
    if (visitPoints <= 0) return const SizedBox.shrink();
    void open() => Navigator.push(
        context, MaterialPageRoute(builder: (_) => QRPage(token: token)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: OffroColors.mint,
          padding: const EdgeInsets.all(20),
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(
              right: -40, top: -50,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .25), width: 22)),
              ),
            ),
            Row(children: [
              Container(
                width: 48, height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: OffroColors.primary, shape: BoxShape.circle),
                child: const OffroIcon(OffroIcons.scan, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Scan the store QR', style: OffroText.cardTitle.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                Text('Verify your visit/purchase and earn $visitPoints reward points.',
                  style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, height: 1.4,
                    color: OffroColors.primary.withValues(alpha: .65))),
              ])),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: open,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .7),
                    borderRadius: OffroRadii.pillRadius),
                  child: Text('Scan QR',
                    style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: OffroColors.primary)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
