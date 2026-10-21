// lib/core/design/offro_pill.dart
//
// OffrO pills / badges / chips (Figma redesign, Phase 1).
import 'package:flutter/material.dart';

import 'offro_icons.dart';
import 'offro_tokens.dart';
import 'offro_typography.dart';

enum OffroPillTone {
  /// Mint tint (category, tier).
  mint,
  /// Dark translucent (distance on a photo).
  dark,
  /// Solid primary (deal discount).
  primary,
  /// White translucent (offer / expiry on a photo).
  light,
  /// Warm beige.
  beige,
}

/// A small rounded label with optional leading icon.
class OffroPill extends StatelessWidget {
  final String label;
  final OffroIconData? icon;
  final OffroPillTone tone;
  final double fontSize;

  const OffroPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = OffroPillTone.mint,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    switch (tone) {
      case OffroPillTone.mint:
        bg = const Color(0x80CDEBD6); // mint @ 50%
        fg = OffroColors.primary;
        break;
      case OffroPillTone.dark:
        bg = const Color(0xCC21332D); // text @ 80%
        fg = Colors.white;
        break;
      case OffroPillTone.primary:
        bg = OffroColors.primary;
        fg = Colors.white;
        break;
      case OffroPillTone.light:
        bg = const Color(0xE6FDFBF6); // background @ 90%
        fg = OffroColors.primary;
        break;
      case OffroPillTone.beige:
        bg = const Color(0x99FFFFFF);
        fg = OffroColors.primary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: OffroRadii.pillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            OffroIcon(icon!, size: fontSize + 1, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OffroText.caption.copyWith(color: fg, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable filter chip ("Any distance", "Under 1 km" ...).
class OffroChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const OffroChip({super.key, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? OffroColors.primary : OffroColors.surface,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : const BorderSide(color: OffroColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: OffroText.caption.copyWith(
                color: selected ? Colors.white : OffroColors.primary.withValues(alpha: .65),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Star rating shown in a mint pill, e.g. "★ 4.8".
class OffroRatingPill extends StatelessWidget {
  final String rating;
  const OffroRatingPill({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: OffroColors.mintFill, borderRadius: OffroRadii.pillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OffroIcon(OffroIcons.star, size: 11, color: OffroColors.amber, filled: true),
          const SizedBox(width: 4),
          Text(rating, style: OffroText.caption.copyWith(color: OffroColors.text)),
        ],
      ),
    );
  }
}

/// Small dot + uppercase label, e.g. the green "NEW" marker.
class OffroDotLabel extends StatelessWidget {
  final String label;
  final Color color;
  const OffroDotLabel({super.key, required this.label, this.color = OffroColors.success});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: OffroText.caption.copyWith(color: color, fontSize: 10, letterSpacing: 0.6),
        ),
      ],
    );
  }
}
