// lib/core/design/offro_theme.dart
//
// OffrO ThemeData (Figma redesign, Phase 1).
//
// NOTE: this theme is defined but NOT yet applied to MaterialApp - applying it
// switches the default font app-wide, which belongs with the first screen
// redesign (Phase 2) so existing layouts are not changed in Phase 1.
// It deliberately sets only long-stable theme pieces (no dialog/card/tab/
// input-decoration themes, whose types changed across recent Flutter
// releases); OffroTextField, OffroCard etc. style themselves.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'offro_tokens.dart';
import 'offro_typography.dart';

class OffroTheme {
  OffroTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: OffroColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: OffroColors.primary,
      onPrimary: Colors.white,
      secondary: OffroColors.sage,
      onSecondary: Colors.white,
      surface: OffroColors.surface,
      onSurface: OffroColors.text,
      error: OffroColors.error,
    );

    return ThemeData(
      useMaterial3: false, // matches the current app; Material 3 is a later, separate decision
      fontFamily: OffroFonts.sans,
      colorScheme: scheme,
      primaryColor: OffroColors.primary,
      scaffoldBackgroundColor: OffroColors.background,
      canvasColor: OffroColors.background,
      dividerColor: OffroColors.borderSoft,
      splashColor: OffroColors.primary.withValues(alpha: .06),
      highlightColor: OffroColors.primary.withValues(alpha: .04),
      iconTheme: const IconThemeData(color: OffroColors.text),
      appBarTheme: const AppBarTheme(
        backgroundColor: OffroColors.background,
        foregroundColor: OffroColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: OffroColors.text),
        titleTextStyle: TextStyle(
          fontFamily: OffroFonts.sans,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: OffroColors.text,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: OffroColors.background,
        modalBackgroundColor: OffroColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: OffroColors.text,
        behavior: SnackBarBehavior.floating,
        shape: StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: OffroColors.borderSoft, thickness: 1, space: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: OffroColors.primary,
        selectionColor: OffroColors.primary.withValues(alpha: .2),
        selectionHandleColor: OffroColors.primary,
      ),
    );
  }
}
