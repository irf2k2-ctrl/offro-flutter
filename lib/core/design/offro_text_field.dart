// lib/core/design/offro_text_field.dart
//
// OffrO text field (Figma redesign, Phase 1): optional label above, 16px
// rounded white box, hairline border, optional leading icon / "+91" prefix.
// It wraps a plain TextField - controllers, formatters and callbacks stay
// with the caller.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'offro_icons.dart';
import 'offro_tokens.dart';
import 'offro_typography.dart';

class OffroTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final OffroIconData? leadingIcon;
  /// Text shown before the input and separated by a divider, e.g. '+91'.
  final String? prefixText;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final TextAlign textAlign;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? textStyle;

  const OffroTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.leadingIcon,
    this.prefixText,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final style = textStyle ?? OffroText.value.copyWith(fontSize: 14);

    final field = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: enabled ? OffroColors.surface : const Color(0xFFF4F2EC),
        borderRadius: OffroRadii.inputRadius,
        border: Border.all(color: hasError ? OffroColors.error : OffroColors.border),
      ),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (leadingIcon != null) ...[
            OffroIcon(leadingIcon!, size: 18, color: OffroColors.sage),
            const SizedBox(width: 12),
          ],
          if (prefixText != null) ...[
            Text(prefixText!, style: style.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Container(width: 1, height: 18, color: const Color(0x1A000000)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: autofocus,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              inputFormatters: inputFormatters,
              maxLength: maxLength,
              maxLines: maxLines,
              minLines: 1,
              textAlign: textAlign,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              cursorColor: OffroColors.primary,
              style: style,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                counterText: '',
                hintText: hint,
                hintStyle: style.copyWith(
                  color: OffroColors.textPlaceholder,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: OffroText.caption.copyWith(color: OffroColors.primary.withValues(alpha: .7)),
          ),
          const SizedBox(height: 8),
        ],
        field,
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(errorText!, style: OffroText.caption.copyWith(color: OffroColors.error, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}
