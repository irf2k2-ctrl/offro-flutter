// lib/core/design/offro_card.dart
//
// OffrO card (Figma redesign, Phase 1): white surface, hairline border,
// 24px radius. Optional tap, padding, soft shadow. Photo cards put their
// overlay pills in a Stack inside [child]; use [OffroCard.clipped] when the
// child (e.g. a full-bleed image) must be clipped to the rounded corners.
import 'package:flutter/material.dart';

import 'offro_tokens.dart';

class OffroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color color;
  final bool bordered;
  final bool shadow;
  final EdgeInsetsGeometry? margin;

  const OffroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(OffroSpacing.card),
    this.onTap,
    this.radius = OffroRadii.card,
    this.color = OffroColors.surface,
    this.bordered = true,
    this.shadow = false,
    this.margin,
  });

  /// Card with no inner padding whose content is clipped to the corners
  /// (image-on-top cards).
  const OffroCard.clipped({
    super.key,
    required this.child,
    this.onTap,
    this.radius = OffroRadii.card,
    this.color = OffroColors.surface,
    this.bordered = true,
    this.shadow = false,
    this.margin,
  }) : padding = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow ? OffroShadows.card : null,
      ),
      child: Material(
        color: color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: r,
          side: bordered ? const BorderSide(color: OffroColors.border) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return card;
  }
}
