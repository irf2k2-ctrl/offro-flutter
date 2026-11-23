// Country-specific language policy (approved enhancement): India must not see or keep Arabic while Arabic is mapped to Saudi
// Arabia only; unknown country / empty mapping = English only; a saved Arabic preference is replaced by English and the saved value is
// overwritten; the same rules hold for onboarding, login, profile, session restore and for Customer, Merchant and Influencer.
// No network and no real storage (SharedPreferences mock).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/l10n/l10n.dart';
import 'package:offro_user/core/l10n/language_policy.dart';
import 'package:offro_user/core/l10n/language_sheet.dart';
import 'package:offro_user/core/l10n/locale_controller.dart';
import 'package:offro_user/core/phone/device_country.dart';
import 'package:offro_user/core/phone/phone_country.dart';
import 'package:offro_user/core/services/api_service.dart';

const arSaOnly = <String, Set<String>>{
  'en': {'SA', 'IN', 'JO', 'NP', 'PH'},
  'ar': {'SA'},
};

Widget app(Widget home) => AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (_, __) => MaterialApp(
        locale: LocaleController.instance.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );

Future<String?> savedLanguage() async => (await SharedPreferences.getInstance()).getString(LocaleController.prefsKey);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocaleController.instance.resetForTest();
    ActiveCountry.instance.resetForTest();
    Api.customerCountry = null;
    languageMappingForTest = arSaOnly;
  });
  tearDown(() {
    languageMappingForTest = null;
    ActiveCountry.instance.resetForTest();
    Api.customerCountry = null;
  });

  group('who may use which language', () {
    test('India sees English, not Arabic; Saudi Arabia sees both', () {
      expect(allowedLanguageCodes(countryIso: 'IN'), ['en']);
      expect(allowedLanguageCodes(countryIso: 'SA'), ['en', 'ar']);
      expect(languageCodesForCountry('IN'), ['en']);
      expect(languageCodesForCountry('SA'), ['en', 'ar']);
    });

    test('every other supported country follows the mapping too (Jordan, Nepal, Philippines: English)', () {
      for (final iso in ['JO', 'NP', 'PH']) {
        expect(allowedLanguageCodes(countryIso: iso), ['en'], reason: iso);
      }
    });

    test('an unknown country or an empty / missing mapping is English only', () {
      expect(allowedLanguageCodes(countryIso: ''), ['en']);
      expect(allowedLanguageCodes(countryIso: 'SA', mapping: const {}), ['en']);
      languageMappingForTest = const {};
      expect(allowedLanguageCodes(countryIso: 'SA'), ['en']); // the real service has no mapping in tests either
    });

    test('Arabic appears for another country only when the admin maps it there', () {
      languageMappingForTest = {'en': {'IN'}, 'ar': {'SA', 'IN'}};
      expect(allowedLanguageCodes(countryIso: 'IN'), ['en', 'ar']);
    });
  });

  group('country priority: account, then device / login selection, then India', () {
    test('India is the default', () {
      expect(ActiveCountry.instance.iso, 'IN');
      expect(allowedLanguageCodes(), ['en']);
    });

    test('the device country is used before login', () async {
      await ActiveCountry.instance.detectDevice(
          detect: () async => const CountrySuggestion(
              PhoneCountry(iso: 'SA', name: 'Saudi Arabia', dial: '966', flag: ''), CountrySource.sim));
      expect(ActiveCountry.instance.iso, 'SA');
      expect(allowedLanguageCodes(), ['en', 'ar']);
    });

    test('a detection failure or timeout falls back to India', () async {
      await ActiveCountry.instance.detectDevice(detect: () async => throw StateError('no channel'));
      expect(ActiveCountry.instance.iso, 'IN');
    });

    test('the account country (from the phone) wins over the device country', () {
      ActiveCountry.instance.setSelected('SA');
      Api.setCustomerCountryFromPhone('+919876543210'); // an Indian account on a Saudi SIM
      expect(ActiveCountry.instance.iso, 'IN');
      expect(allowedLanguageCodes(), ['en']);
      Api.setCustomerCountryFromPhone('+966501234567');
      expect(ActiveCountry.instance.iso, 'SA');
      expect(allowedLanguageCodes(), ['en', 'ar']);
    });

    test('the account country is the same in Customer, Merchant and Influencer mode (one shared phone)', () {
      for (final mode in ['user', 'merchant', 'influencer']) {
        // Every mode switch / login ends in Api.setCustomerCountryFromPhone(phone) with the same account phone.
        Api.setCustomerCountryFromPhone('+919876543210');
        expect(ActiveCountry.instance.iso, 'IN', reason: mode);
        expect(allowedLanguageCodes(), ['en'], reason: mode);
      }
    });

    test('the device locale list is scanned for a supported region', () {
      // English (United States) first, Hindi (India) second: India is found. The old code looked at the first locale only (US = unsupported).
      expect(regionFromLocales(const [Locale('en', 'US'), Locale('hi', 'IN')], const Locale('en', 'US')), 'IN');
      expect(regionFromLocales(const [Locale('en', 'US'), Locale('ar', 'SA')], const Locale('en', 'US')), 'SA');
      expect(regionFromLocales(const [Locale('ar', 'SA'), Locale('en', 'IN')], const Locale('ar', 'SA')), 'SA',
          reason: 'the first supported one in the user\'s order');
      // nothing supported: the primary region is returned and suggestCountry then falls back to India
      expect(regionFromLocales(const [Locale('en', 'US')], const Locale('en', 'US')), 'US');
      expect(regionFromLocales(const [], const Locale('en')), isNull);
    });

    test('the device country suggestion uses it (locale is the only source on iOS)', () async {
      final s = await detectInitialCountry(
          readNative: () async => const DeviceCountryCodes(), localeRegion: () => regionFromLocales(const [Locale('en', 'US'), Locale('ar', 'SA')], const Locale('en', 'US')));
      expect(s.country.iso, 'SA');
      expect(s.source, CountrySource.locale);
      final d = await detectInitialCountry(
          readNative: () async => const DeviceCountryCodes(), localeRegion: () => regionFromLocales(const [Locale('en', 'US')], const Locale('en', 'US')));
      expect(d.country.iso, 'IN');
      expect(d.source, CountrySource.defaultIndia);
    });
  });

  group('a saved language can never bypass the restriction', () {
    test('saved Arabic + India: switched to English and the saved value is overwritten', () async {
      SharedPreferences.setMockInitialValues({LocaleController.prefsKey: 'ar'});
      await LocaleController.instance.load(); // session restore reads the saved language
      expect(LocaleController.instance.locale.languageCode, 'ar');
      Api.setCustomerCountryFromPhone('+919876543210'); // ... and the account country (India)
      expect(await enforceLanguagePolicy(), isTrue);
      expect(LocaleController.instance.locale.languageCode, 'en');
      expect(await savedLanguage(), 'en');
    });

    test('saved Arabic + Saudi Arabia: kept', () async {
      SharedPreferences.setMockInitialValues({LocaleController.prefsKey: 'ar'});
      await LocaleController.instance.load();
      Api.setCustomerCountryFromPhone('+966501234567');
      expect(await enforceLanguagePolicy(), isFalse);
      expect(LocaleController.instance.locale.languageCode, 'ar');
      expect(await savedLanguage(), 'ar');
    });

    test('saved Arabic + unknown mapping: English (no exception for the language in use)', () async {
      SharedPreferences.setMockInitialValues({LocaleController.prefsKey: 'ar'});
      await LocaleController.instance.load();
      Api.setCustomerCountryFromPhone('+966501234567');
      languageMappingForTest = const {};
      expect(await enforceLanguagePolicy(), isTrue);
      expect(LocaleController.instance.locale.languageCode, 'en');
      expect(await savedLanguage(), 'en');
    });

    test('English is never touched', () async {
      await LocaleController.instance.load();
      expect(await enforceLanguagePolicy(), isFalse);
      expect(await savedLanguage(), isNull);
    });

    test('the watcher re-checks when the account country arrives (login / account load / mode switch)', () async {
      LanguagePolicyWatcher.attach();
      await LocaleController.instance.setLanguage('ar'); // e.g. picked while the device country was Saudi Arabia
      ActiveCountry.instance.setSelected('SA');
      await Future<void>.delayed(Duration.zero);
      expect(LocaleController.instance.locale.languageCode, 'ar');
      Api.setCustomerCountryFromPhone('+919876543210'); // the account turns out to be Indian
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(LocaleController.instance.locale.languageCode, 'en');
      expect(await savedLanguage(), 'en');
    });

    test('changing the login-screen country to India drops Arabic at once', () async {
      LanguagePolicyWatcher.attach();
      ActiveCountry.instance.setSelected('SA');
      await LocaleController.instance.setLanguage('ar');
      ActiveCountry.instance.setSelected('IN');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(LocaleController.instance.locale.languageCode, 'en');
    });
  });

  group('the selectors (onboarding, login, profile) follow the same policy', () {
    testWidgets('India: the language button (onboarding / login) is hidden - nothing to choose', (t) async {
      ActiveCountry.instance.setSelected('IN');
      await t.pumpWidget(app(const Scaffold(body: LanguageButton())));
      expect(find.byKey(const ValueKey('language_button')), findsNothing);
      await t.pumpWidget(app(const Scaffold(body: LanguageButton(countryIso: 'IN', filled: true))));
      expect(find.byKey(const ValueKey('language_button')), findsNothing);
    });

    testWidgets('Saudi Arabia: the button shows and the chooser lists Arabic', (t) async {
      ActiveCountry.instance.setSelected('SA');
      await t.pumpWidget(app(Scaffold(body: Builder(builder: (c) => Column(children: [
            const LanguageButton(),
            TextButton(onPressed: () => showLanguageSheet(c), child: const Text('sheet')),
          ])))));
      expect(find.byKey(const ValueKey('language_button')), findsOneWidget);
      await t.tap(find.text('sheet'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('language_option_en')), findsOneWidget);
      expect(find.byKey(const ValueKey('language_option_ar')), findsOneWidget);
    });

    testWidgets('the profile chooser for an Indian account lists English only, even when Arabic is the language in use', (t) async {
      await LocaleController.instance.setLanguage('ar');
      await t.pumpWidget(app(Scaffold(body: Builder(builder: (c) => TextButton(
          onPressed: () => showLanguageSheet(c, countryIso: countryIsoForPhone('+919876543210')), child: const Text('sheet'))))));
      await t.tap(find.text('sheet'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('language_option_en')), findsOneWidget);
      expect(find.byKey(const ValueKey('language_option_ar')), findsNothing);
    });

    testWidgets('the button appears by itself when the Saudi country becomes known', (t) async {
      ActiveCountry.instance.setSelected('IN');
      await t.pumpWidget(app(const Scaffold(body: LanguageButton())));
      expect(find.byKey(const ValueKey('language_button')), findsNothing);
      ActiveCountry.instance.setSelected('SA');
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('language_button')), findsOneWidget);
    });
  });
}
