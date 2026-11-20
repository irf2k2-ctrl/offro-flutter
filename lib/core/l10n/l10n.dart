// lib/core/l10n/l10n.dart
//
// THE single access point for translated text (Phase I).
//   Text(context.l10n.loginGuest)
// Screens never import the generated class directly. A later phase can put remote (admin-published) overrides behind this one
// accessor without touching any screen again.
//
// Generated code lives in lib/l10n/gen (run `flutter gen-l10n`).
import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/gen/app_localizations_en.dart';

export '../../l10n/gen/app_localizations.dart' show AppLocalizations;

extension OffroL10n on BuildContext {
  /// Falls back to the bundled English text when the widget is not under the app's localization delegates (a stand-alone
  /// MaterialApp such as a diagnostic screen, or a test), so a missing delegate can never crash a screen.
  AppLocalizations get l10n => Localizations.of<AppLocalizations>(this, AppLocalizations) ?? AppLocalizationsEn();
}

/// Keeps a phone number (or other always-left-to-right token) in order inside right-to-left text. In left-to-right layouts the value
/// is returned UNCHANGED, so English text is exactly as before. Use only for values passed as placeholder arguments.
String ltrIsolate(BuildContext context, String value) =>
    Directionality.of(context) == TextDirection.rtl ? '\u2066$value\u2069' : value;
