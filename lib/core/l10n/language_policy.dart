// lib/core/l10n/language_policy.dart
//
// ONE place that decides which country the language policy applies to and keeps the app language inside it.
//
// Country priority (the same for Customer, Merchant and Influencer, who share one phone number / account):
//   1. the account country (derived from the account phone, set through Api.setCustomerCountryFromPhone);
//   2. the country the device (SIM / network / locale region) or the login screen's country picker selected, before any login;
//   3. India, when nothing could be detected.
// Languages: see language_availability.dart (strict, English-only when the country or the mapping is unknown).
//
// enforceLanguagePolicy() switches the app to English AND overwrites the saved preference when the language in use is not allowed
// for the country. It runs at start-up (session restore), after every login / account load, when the country changes and whenever the
// published mapping changes, so a saved language can never bypass the restriction.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../phone/device_country.dart';
import '../phone/phone_country.dart';
import 'language_availability.dart';
import 'locale_controller.dart';
import 'remote/remote_translation_service.dart';

class ActiveCountry extends ChangeNotifier {
  ActiveCountry._();
  static final ActiveCountry instance = ActiveCountry._();

  /// Used when neither the account nor the device gives a country.
  static const String fallbackIso = 'IN';

  String? _account;
  String? _selected;
  bool _detected = false;

  /// The country the policy applies to. Never empty.
  String get iso => _account ?? _selected ?? fallbackIso;

  /// The signed-in account's country (null = signed out / unknown). Wins over everything else.
  void setAccount(String? iso) => _set(account: _clean(iso), selected: _selected);

  /// The country chosen before login: detected from the device, or picked on the login screen.
  void setSelected(String? iso) => _set(account: _account, selected: _clean(iso));

  /// Detects the device country once (SIM, network, locale region; India otherwise). Never throws, never blocks long.
  Future<void> detectDevice({Future<CountrySuggestion> Function()? detect}) async {
    if (_detected) return;
    _detected = true;
    try {
      final s = await (detect ?? detectInitialCountry)().timeout(const Duration(seconds: 2));
      if (_selected == null) setSelected(s.country.iso);
    } catch (_) {/* India is used */}
  }

  static String? _clean(String? v) {
    final s = (v ?? '').trim().toUpperCase();
    return s.length == 2 ? s : null;
  }

  void _set({required String? account, required String? selected}) {
    if (account == _account && selected == _selected) return;
    _account = account;
    _selected = selected;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _account = null;
    _selected = null;
    _detected = false;
  }
}

/// Lets tests stand in for the published mapping (the app-wide service is disabled in tests, so it has none).
@visibleForTesting
Map<String, Set<String>>? languageMappingForTest;

/// The languages [countryIso] (default: the active country) may use, from the published mapping.
List<String> allowedLanguageCodes({String? countryIso, Map<String, Set<String>>? mapping}) => availableLanguageCodes(
      bundled: LocaleController.supportedCodes,
      countryIso: countryIso ?? ActiveCountry.instance.iso,
      mapping: mapping ?? languageMappingForTest ?? RemoteTranslationService.instance.languageCountries,
    );

/// Switches to English (and saves it) when the language in use is not allowed for the country. Returns true when it switched.
/// Never throws.
Future<bool> enforceLanguagePolicy({String? countryIso, Map<String, Set<String>>? mapping}) async {
  try {
    final current = LocaleController.instance.locale.languageCode;
    if (allowedLanguageCodes(countryIso: countryIso, mapping: mapping).contains(current)) return false;
    await LocaleController.instance.setLanguage(kDefaultLanguageCode);
    return true;
  } catch (_) {
    return false;
  }
}

/// Re-checks the saved language whenever the country or the published mapping changes. Safe to call more than once.
class LanguagePolicyWatcher {
  LanguagePolicyWatcher._();
  static bool _attached = false;

  static void attach() {
    if (_attached) return;
    _attached = true;
    ActiveCountry.instance.addListener(_check);
    RemoteTranslationService.instance.addListener(_check);
  }

  static void _check() => unawaited(enforceLanguagePolicy());
}
