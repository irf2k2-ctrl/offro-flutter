// lib/core/design/offro_typography.dart
//
// OffrO typography (Figma redesign, Phase 1).
//
// Manrope is the UI face (400/500/600/700, bundled in assets/fonts).
// Lora italic is used only as a headline accent word.
// letterSpacing values are the design's em values multiplied by font size.
import 'package:flutter/material.dart';

import 'offro_tokens.dart';

class OffroFonts {
  OffroFonts._();
  static const String sans  = 'Manrope';
  static const String serif = 'Lora';
}

class OffroText {
  OffroText._();

  static const Color _ink = OffroColors.text;

  /// Large display headline (auth / role / OTP): 38px, 600.
  static const TextStyle display = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 38, fontWeight: FontWeight.w600,
    height: 1.05, letterSpacing: -2.1, color: _ink);

  /// Screen title (Explore, Deals, Profile ...): 32px, 600.
  static const TextStyle headline = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 32, fontWeight: FontWeight.w600,
    height: 1.1, letterSpacing: -1.76, color: _ink);

  /// Section title: ~21.6px, 600.
  static const TextStyle title = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 21.6, fontWeight: FontWeight.w600,
    height: 1.2, letterSpacing: -0.76, color: _ink);

  /// Large in-card heading (price, points): 24px, 600.
  static const TextStyle titleSm = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 24, fontWeight: FontWeight.w600,
    height: 1.2, letterSpacing: -0.96, color: _ink);

  /// Card title: 14px, 600.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 14, fontWeight: FontWeight.w600,
    height: 1.3, color: _ink);

  /// Body: 13px / 20px line, 400.
  static const TextStyle body = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 13, fontWeight: FontWeight.w400,
    height: 1.55, color: OffroColors.textMuted);

  /// Small body: 12px, 400.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 12, fontWeight: FontWeight.w400,
    height: 1.45, color: OffroColors.textMuted);

  /// Field / list value: 14px, 500.
  static const TextStyle value = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 14, fontWeight: FontWeight.w500,
    height: 1.3, color: _ink);

  /// Button label: 13px, 600.
  static const TextStyle button = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 13, fontWeight: FontWeight.w600,
    height: 1.2, color: Colors.white);

  /// Caption / chip: 11px, 600 (the design's 10px captions are raised to 11
  /// so they stay readable and respect the system text size).
  static const TextStyle caption = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 11, fontWeight: FontWeight.w600,
    height: 1.3, color: OffroColors.primary);

  /// Eyebrow label: 10px, 600, UPPERCASE (apply toUpperCase on the string),
  /// +0.18em tracking, sage.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 10, fontWeight: FontWeight.w600,
    height: 1.3, letterSpacing: 1.8, color: OffroColors.sage);

  /// Navigation label: 10px, 500.
  static const TextStyle navLabel = TextStyle(
    fontFamily: OffroFonts.sans, fontSize: 10, fontWeight: FontWeight.w500,
    height: 1.2);

  /// Lora italic accent used inside headlines (same size as the headline it
  /// sits in - pass the surrounding style to [accentOf]).
  static TextStyle accentOf(TextStyle base) => base.copyWith(
    fontFamily: OffroFonts.serif, fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w400);
}

/// A headline with one italic serif accent word, e.g.
/// "Find more to *love*, nearby." ->
/// OffroAccentText(before: 'Find more to ', accent: 'love', after: ', nearby.')
class OffroAccentText extends StatelessWidget {
  final String before;
  final String accent;
  final String after;
  final TextStyle style;
  final TextAlign textAlign;

  const OffroAccentText({
    super.key,
    this.before = '',
    required this.accent,
    this.after = '',
    this.style = OffroText.display,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(style: style, children: [
        if (before.isNotEmpty) TextSpan(text: before),
        TextSpan(text: accent, style: OffroText.accentOf(style)),
        if (after.isNotEmpty) TextSpan(text: after),
      ]),
      textAlign: textAlign,
    );
  }
}
