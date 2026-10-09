// lib/screens/home/widgets/promo_slider_section.dart
//
// Home "Featured Banners" carousel (merchant promo sliders, looping PageView
// with indicator dots). Extracted unchanged from lib/main.dart; the class was
// _PromoSliderSection and only its name became public.
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/store_cards.dart' show PromoSliderCard;

// ═══════════════════════════════════════════════════════════════
// 3. PROMO SLIDER SECTION — merchant banners, compact (160px)
// ═══════════════════════════════════════════════════════════════
class PromoSliderSection extends StatelessWidget {
  final List<Map<String,dynamic>> sliders;
  final PageController sliderPc;
  final ValueNotifier<int> sliderPageNotifier;
  final String token;
  final ValueChanged<int> onSliderPageChanged;
  const PromoSliderSection({
    required this.sliders, required this.sliderPc,
    required this.sliderPageNotifier, required this.token,
    required this.onSliderPageChanged,
  });

  @override Widget build(BuildContext context) {
    if (sliders.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Featured Banners",
              style: TextStyle(color: Color(0xFF2c3e35), fontSize: 18, fontWeight: FontWeight.w800)),
            Text("Latest offers from our stores", style: TextStyle(color: kMuted, fontSize: 12)),
          ]),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Banner aspect ratio 2.35:1 — matches typical promotional banner dimensions
            // This ensures the full image is shown without top/bottom letterboxing or cropping
            final bannerWidth  = constraints.maxWidth - 32; // 16px padding each side
            final bannerHeight = (bannerWidth / 2.35).clamp(140.0, 220.0);
            return SizedBox(
              height: bannerHeight,
              child: PageView.builder(
                controller: sliderPc,
                clipBehavior: Clip.none,
                itemCount: sliders.isNotEmpty ? 99999 : 0, // always loop
                onPageChanged: onSliderPageChanged,
                itemBuilder: (_, i) {
                  final s = sliders[i % sliders.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PromoSliderCard(
                      slider: Map<String,dynamic>.from(s as Map),
                      token: token,
                      squareCorners: false,
                      hideText: false,
                      onVideoComplete: () {
                        if (sliderPc.hasClients) {
                          sliderPc.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut);
                        }
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
        // Dots
        const SizedBox(height: 10),
        ValueListenableBuilder<int>(
          valueListenable: sliderPageNotifier,
          builder: (_, pg, __) {
            final count = sliders.length;
            return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: pg == i ? 20 : 6, height: 6,
                  decoration: BoxDecoration(
                    color: pg == i ? const Color(0xFFD4A017) : const Color(0xFFe8d9a0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]);
          },
        ),
        const SizedBox(height: 6),
      ]),
    );
  }
}
