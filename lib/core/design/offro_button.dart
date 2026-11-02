// lib/core/design/offro_button.dart
//
// OffrO buttons (Figma redesign, Phase 1): primary / secondary / small pills
// and the round icon button. Presentation only - callers pass their own
// onPressed so no behaviour lives here.
import 'package:flutter/material.dart';

import 'offro_icons.dart';
import 'offro_tokens.dart';
import 'offro_typography.dart';

enum OffroButtonVariant { primary, secondary, small }

class OffroButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final OffroButtonVariant variant;
  /// Optional icon shown after the label (the design uses the arrow).
  final OffroIconData? trailingIcon;
  final OffroIconData? leadingIcon;
  /// Shows a spinner instead of the label and ignores taps.
  final bool loading;
  /// Full width (primary/secondary default). Small is always content-sized.
  final bool expand;

  const OffroButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = OffroButtonVariant.primary,
    this.trailingIcon,
    this.leadingIcon,
    this.loading = false,
    this.expand = true,
  });

  const OffroButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.leadingIcon,
    this.loading = false,
    this.expand = true,
  }) : variant = OffroButtonVariant.primary;

  const OffroButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.leadingIcon,
    this.loading = false,
    this.expand = true,
  }) : variant = OffroButtonVariant.secondary;

  const OffroButton.small({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.leadingIcon,
    this.loading = false,
  })  : variant = OffroButtonVariant.small,
        expand = false;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == OffroButtonVariant.primary;
    final isSmall = variant == OffroButtonVariant.small;

    final Color bg = isPrimary
        ? OffroColors.primary
        : (isSmall ? const Color(0xF2FFFFFF) : OffroColors.surface);
    final Color fg = isPrimary ? Colors.white : OffroColors.primary;
    final double fontSize = isSmall ? 11 : 13;
    final EdgeInsets pad = isSmall
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    final double iconSize = isSmall ? 13 : 16;

    final Widget content = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                OffroIcon(leadingIcon!, size: iconSize, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OffroText.button.copyWith(color: fg, fontSize: fontSize),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                OffroIcon(trailingIcon!, size: iconSize, color: fg),
              ],
            ],
          );

    final button = Opacity(
      // Disabled = 35% opacity (as in the design). A loading button keeps full
      // opacity so the spinner stays visible.
      opacity: (onPressed == null && !loading) ? 0.35 : 1.0,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: isPrimary
              ? BorderSide.none
              : const BorderSide(color: OffroColors.borderStrong),
        ),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _enabled ? onPressed : null,
          child: Padding(
            padding: pad,
            child: Align(widthFactor: expand ? null : 1, heightFactor: 1, child: content),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Round 40px icon button (white, hairline border). [filled] gives the
/// selected look (primary background, white icon) used for e.g. a saved heart.
class OffroIconButton extends StatelessWidget {
  final OffroIconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final bool filled;
  /// Fills the icon glyph itself (e.g. a solid heart).
  final bool iconFilled;
  /// Small terracotta notification dot (top-right).
  final bool showDot;
  final String? semanticLabel;
  final Color? backgroundColor;

  const OffroIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.iconSize = 18,
    this.filled = false,
    this.iconFilled = false,
    this.showDot = false,
    this.semanticLabel,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = backgroundColor ?? (filled ? OffroColors.primary : OffroColors.surface);
    final Color fg = filled ? Colors.white : OffroColors.primary;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: bg,
                shape: CircleBorder(
                  side: filled ? BorderSide.none : const BorderSide(color: OffroColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: Center(
                    child: OffroIcon(icon, size: iconSize, color: fg, filled: iconFilled),
                  ),
                ),
              ),
            ),
            if (showDot)
              Positioned(
                right: size * 0.26,
                top: size * 0.2,
                child: IgnorePointer(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: OffroColors.terracotta,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 44px circular back button used on pushed screens.
class OffroBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const OffroBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OffroIconButton(
      icon: OffroIcons.back,
      size: 44,
      iconSize: 20,
      semanticLabel: 'Back',
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}
