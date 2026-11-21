// lib/core/l10n/remote/remote_localizations.dart
//
// Phase K: plugs the remote overrides into the existing localization system without changing any screen.
//   * [buildAppLocalizations] is what the delegate and `offroNoContext` use: bundled text, with validated remote text on top for
//     Arabic only. English is never touched.
//   * [appLocalizationsDelegate] is the delegate main.dart installs. In a build without remote translations it IS the generated
//     `AppLocalizations.delegate`, so production behaves exactly as before Phase K.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../l10n/gen/app_localizations.dart';
import 'generated/app_localizations_ar_remote.dart';
import 'remote_overrides.dart';
import 'remote_translation_service.dart';

/// Bundled localizations for [locale], with [overrides] applied when the locale is the remote language.
AppLocalizations buildAppLocalizations(
    Locale locale, RemoteOverrides overrides) {
  if (locale.languageCode == kRemoteLanguage &&
      overrides.lang == kRemoteLanguage &&
      !overrides.isEmpty) {
    return AppLocalizationsArRemote(overrides.strings);
  }
  return lookupAppLocalizations(locale);
}

/// Same supported locales as the generated delegate; reloads (synchronously) only when the override snapshot changes.
class RemoteAwareLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const RemoteAwareLocalizationsDelegate(this.overrides);

  final RemoteOverrides overrides;

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(
          buildAppLocalizations(locale, overrides));

  @override
  bool shouldReload(RemoteAwareLocalizationsDelegate old) =>
      old.overrides != overrides;
}

/// The delegate for the current language: the plain generated one unless remote translations are enabled in this build.
LocalizationsDelegate<AppLocalizations> appLocalizationsDelegate(
    {RemoteTranslationService? service, String? languageCode}) {
  final s = service ?? RemoteTranslationService.instance;
  if (!s.enabled) return AppLocalizations.delegate;
  return RemoteAwareLocalizationsDelegate(s.overridesFor(languageCode ?? ''));
}
