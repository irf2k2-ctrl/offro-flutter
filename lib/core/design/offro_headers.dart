// lib/core/design/offro_headers.dart
//
// OffrO section title and screen header (Figma redesign, Phase 1).
import 'package:flutter/material.dart';

import 'offro_button.dart';
import 'offro_icons.dart';
import 'offro_tokens.dart';
import 'offro_typography.dart';

/// "EYEBROW" + large title on the left, "See all >" action on the right.
class OffroSectionTitle extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const OffroSectionTitle({
    super.key,
    this.eyebrow,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = OffroSpacing.gutterH,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Text(eyebrow!.toUpperCase(), style: OffroText.eyebrow),
                if (eyebrow != null) const SizedBox(height: 4),
                Text(title, style: OffroText.title),
              ],
            ),
          ),
          if (actionLabel != null)
            InkWell(
              onTap: onAction,
              borderRadius: OffroRadii.pillRadius,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 0, 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(actionLabel!, style: OffroText.caption),
                    const SizedBox(width: 2),
                    const OffroIcon(OffroIcons.chevron, size: 13, color: OffroColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Top-of-screen header: eyebrow, 32px title, optional description.
/// An optional back button and trailing widget are supported for pushed screens.
class OffroScreenHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? description;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const OffroScreenHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.description,
    this.showBack = false,
    this.onBack,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(OffroSpacing.gutter, 20, OffroSpacing.gutter, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack || trailing != null)
            Row(
              children: [
                if (showBack) OffroBackButton(onPressed: onBack),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          if (showBack || trailing != null) const SizedBox(height: 20),
          if (eyebrow != null) Text(eyebrow!.toUpperCase(), style: OffroText.eyebrow.copyWith(letterSpacing: 2)),
          if (eyebrow != null) const SizedBox(height: 4),
          Text(title, style: OffroText.headline),
          if (description != null) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384),
              child: Text(description!, style: OffroText.body),
            ),
          ],
        ],
      ),
    );
  }
}
