// lib/core/design/offro_tokens.dart
//
// OffrO design tokens (Figma redesign, Phase 1).
//
// Pure values only - no widgets, no business logic. Later screens read their
// colours / spacing / radii / shadows from here instead of hard-coding them.
// The legacy constants in app_constants.dart (kPrimary, kLight, kBg ...) are
// untouched and still used by existing screens; the colours below share the
// same brand values where they overlap.
import 'package:flutter/material.dart';

/// Brand + semantic colours.
class OffroColors {
  OffroColors._();

  // Brand
  static const Color primary    = Color(0xFF3E5F55);
  static const Color mint       = Color(0xFFCDEBD6);
  static const Color sage       = Color(0xFF759A89);
  static const Color accent     = Color(0xFFA9CDBA);
  static const Color beige      = Color(0xFFE7D7C8);
  static const Color background = Color(0xFFF3EBDD); // solid darker cream (was #FDFBF6)
  static const Color surface    = Color(0xFFFFFFFF);

  // Text
  static const Color text     = Color(0xFF21332D);
  static const Color textDark = Color(0xFF17231F);

  // Accents / status
  static const Color amber      = Color(0xFFC78D3E); // star ratings
  static const Color terracotta = Color(0xFFD67858); // notification dot, highlights
  static const Color success    = Color(0xFF5C9274); // "New" dot
  static const Color open       = Color(0xFF64A17D); // "Open now" dot
  static const Color error      = Color(0xFFA95F4A);

  // Muted text = black at a given opacity (as in the design).
  static const Color textMuted     = Color(0xFF54776A); // solid secondary (was black 45%)
  static const Color textSubtle    = Color(0xFF54776A); // solid secondary (was black 40%)
  static const Color textFaint     = Color(0xFF759A89); // solid sage tertiary (was black 35%)
  static const Color textPlaceholder = Color(0xFF759A89); // solid sage (was black 25%)
  /// Readable secondary: black 55%. Only for functional secondary text/icons
  /// that must stay legible on device (inactive nav, location info, search
  /// placeholder). Not a replacement for textMuted/textSubtle/textFaint.
  static const Color textReadableSecondary = Color(0xFF54776A); // alias of secondarySolid
  /// Home eyebrow: sage deepened ~60% toward primary (#759A89 -> #54776A).
  static const Color sageStrong = Color(0xFF54776A);
  /// Solid secondary text/icon colour (Test C: replaces black-alpha secondary on Home). Same value as sageStrong.
  static const Color secondarySolid = Color(0xFF54776A);

  // Hairlines: primary at low opacity.
  static const Color border      = Color(0x1A3E5F55); // 10%
  static const Color borderSoft  = Color(0x143E5F55); // 8%
  static const Color borderStrong = Color(0x2E3E5F55); // 18%

  // Soft fills
  static const Color mintSoft = Color(0xFFCDEBD6); // solid mint (was mint @ 55%)
  static const Color mintFill = Color(0xFFCDEBD6); // solid mint (was mint @ 65%)
}

/// A pastel category tile colour pair (background + icon colour).
class OffroTone {
  final Color background;
  final Color foreground;
  const OffroTone(this.background, this.foreground);
}

/// Pastel tones used by category tiles.
class OffroTones {
  OffroTones._();
  static const OffroTone restaurant  = OffroTone(Color(0xFFF6E3D2), Color(0xFF9A6249));
  static const OffroTone grocery     = OffroTone(Color(0xFFDDEEDF), Color(0xFF4F745C));
  static const OffroTone pharmacy    = OffroTone(Color(0xFFE1EBF2), Color(0xFF4A7088));
  static const OffroTone fashion     = OffroTone(Color(0xFFEEE1E7), Color(0xFF865D72));
  static const OffroTone electronics = OffroTone(Color(0xFFE5E4F1), Color(0xFF66648A));
  static const OffroTone salon       = OffroTone(Color(0xFFF2E4DC), Color(0xFF916B55));
  static const OffroTone fitness     = OffroTone(Color(0xFFDCE9E4), Color(0xFF477064));
  static const OffroTone doctor      = OffroTone(Color(0xFFE7EBF4), Color(0xFF5F6F90));
  /// Fallback for any category that has no dedicated tone.
  static const OffroTone neutral     = OffroTone(Color(0xFFE7D7C8), Color(0xFF3E5F55));
}

/// Spacing scale and layout constants (logical px).
class OffroSpacing {
  OffroSpacing._();
  static const double xxs = 2;
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 28;

  /// Horizontal page gutter.
  static const double gutter = 20;
  /// Normal card padding.
  static const double card = 16;
  /// Compact card padding.
  static const double cardCompact = 12;
  /// Vertical gap between home/page sections.
  static const double section = 36;
  /// Max content width of the design (the Figma phone frame).
  static const double maxContentWidth = 480;
  /// Height of the floating bottom navigation bar.
  static const double navHeight = 76;
  /// Inset of the floating bottom navigation from the screen edges.
  static const double navInset = 12;

  static const EdgeInsets gutterH = EdgeInsets.symmetric(horizontal: gutter);
}

/// Corner radii (logical px).
class OffroRadii {
  OffroRadii._();
  static const double pill  = 999;
  static const double input = 16;
  static const double card  = 24;
  static const double cardSm = 22;
  static const double hero  = 29;
  static const double tile  = 18;
  static const double nav   = 26;

  static BorderRadius get pillRadius  => BorderRadius.circular(pill);
  static BorderRadius get inputRadius => BorderRadius.circular(input);
  static BorderRadius get cardRadius  => BorderRadius.circular(card);
  static BorderRadius get cardSmRadius => BorderRadius.circular(cardSm);
  static BorderRadius get heroRadius  => BorderRadius.circular(hero);
  static BorderRadius get tileRadius  => BorderRadius.circular(tile);
  static BorderRadius get navRadius   => BorderRadius.circular(nav);
}

/// Soft green-tinted shadows.
class OffroShadows {
  OffroShadows._();

  /// Search field / card resting shadow: 0 8 30 rgba(62,95,85,.06)
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F3E5F55), blurRadius: 30, offset: Offset(0, 8)),
  ];

  /// Selected card (e.g. chosen role): 0 10 32 rgba(62,95,85,.09)
  static const List<BoxShadow> selected = [
    BoxShadow(color: Color(0x173E5F55), blurRadius: 32, offset: Offset(0, 10)),
  ];

  /// Floating bottom navigation: 0 14 45 rgba(39,65,56,.17)
  static const List<BoxShadow> nav = [
    BoxShadow(color: Color(0x2B274138), blurRadius: 45, offset: Offset(0, 14)),
  ];

  /// Small floating pill / toast.
  static const List<BoxShadow> pill = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}
