// lib/screens/store/widgets/store_highlights.dart
// "Active Offer" chip REMOVED per requirement (point 5).
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class StoreHighlights extends StatelessWidget {
  final Map<String, dynamic> store;
  const StoreHighlights({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final visitPts    = (store['visit_points'] as num?)?.toInt() ?? 0;
    final isTrending  = store['is_trending'] == true;
    final isNew       = store['is_new_in_town'] == true;
    final isPopular   = store['is_popular'] == true;
    final reviewCount = (store['review_count'] as num?)?.toInt() ?? 0;

    final chips = <_ChipData>[];

    // Active Offer chip intentionally excluded
    // Earn pts chip removed — shown in Rewards tab only
    // Review badge intentionally removed — shown in Reviews tab only
    if (isTrending)
      chips.add(_ChipData(
          'Trending',
          Icons.trending_up_rounded,
          const Color(0xFFFF6B35),
          const Color(0xFFFFF0EB)));
    if (isNew)
      chips.add(_ChipData(
          'Just Opened',
          Icons.fiber_new_rounded,
          const Color(0xFF2E7D5E),
          const Color(0xFFE8F5EE)));
    if (isPopular && !isTrending)
      chips.add(_ChipData(
          'Popular',
          Icons.thumb_up_rounded,
          const Color(0xFF2C4A7A),
          const Color(0xFFE3ECF7)));

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips.map((c) => _HighlightChip(data: c)).toList(),
      ),
    );
  }
}

class _ChipData {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  const _ChipData(this.label, this.icon, this.fg, this.bg);
}

class _HighlightChip extends StatelessWidget {
  final _ChipData data;
  const _HighlightChip({super.key, required this.data});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: data.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: data.fg.withValues(alpha: .20), width: 1),
          boxShadow: [
            BoxShadow(
                color: data.fg.withValues(alpha: .08),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(data.icon, color: data.fg, size: 13),
          const SizedBox(width: 5),
          Text(data.label,
              style: TextStyle(
                  color: data.fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}
