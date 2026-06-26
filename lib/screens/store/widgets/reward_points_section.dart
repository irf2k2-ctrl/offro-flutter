// lib/screens/store/widgets/reward_points_section.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../qr/qr_page.dart';

class RewardPointsSection extends StatelessWidget {
  final int visitPoints;
  final String token;
  final int currentPoints;

  const RewardPointsSection({
    super.key,
    required this.visitPoints,
    required this.token,
    this.currentPoints = 0,
  });

  @override
  Widget build(BuildContext context) {
    // No rewards configured — show empty state
    if (visitPoints <= 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: kLight.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder, width: 1),
          ),
          child: Column(children: [
            Icon(Icons.card_giftcard_outlined,
                color: kAccent, size: 34),
            const SizedBox(height: 10),
            const Text(
              'Rewards coming soon',
              style: TextStyle(
                  color: kMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QRPage(token: token)),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3E5F55), Color(0xFF5A8A7A)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withValues(alpha: .35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(children: [
              // Gloss
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: .20),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withValues(alpha: .18),
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white
                              .withValues(alpha: .25)),
                    ),
                    child: const Center(
                      child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white,
                          size: 32),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Earn Reward Points',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scan QR after purchase to earn $visitPoints pts',
                          style: TextStyle(
                              color: Colors.white
                                  .withValues(alpha: .80),
                              fontSize: 12,
                              height: 1.4),
                        ),
                        if (currentPoints > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 10,
                                vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(alpha: .20),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Your Points: $currentPoints',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
