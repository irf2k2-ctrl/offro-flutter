// Country <-> language mapping in the app: which bundled languages the chooser lists for a country, how the backend's manifest
// carries the mapping, and how the service keeps it (cache, kill switch, throttling). No real network, no real storage.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/l10n/language_availability.dart';
import 'package:offro_user/core/l10n/language_sheet.dart';
import 'package:offro_user/core/l10n/locale_controller.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_service.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_validator.dart';
import 'package:offro_user/core/phone/phone_country.dart';

const String stagingUrl = 'https://offro-backend-staging-d375.up.railway.app';
const List<String> bundled = ['en', 'ar'];

Map<String, Set<String>> map(Map<String, List<String>> m) =>
    {for (final e in m.entries) e.key: e.value.toSet()};

/// A scriptable manifest server that also does ETag / 304.
class Be {
  bool kill = false;
  bool offline = false;
  Object? mapping = {
    'en': ['SA', 'IN'],
    'ar': ['SA'],
  };
  String etag = '"m1"';
  int manifestCalls = 0;
  int languageCalls = 0;
  int notModified = 0;

  Map<String, Object?> manifest() => {
        'schema': 1,
        'kill_switch': kill,
        'overrides_enabled': !kill,
        'languages': <Object?>[],
        if (mapping != null && !kill) 'language_countries': mapping,
      };

  MockClient get client => MockClient((req) async {
        if (offline) throw http.ClientException('no route to host');
        if (req.url.path == '/translations/manifest') {
          manifestCalls++;
          if (req.headers['If-None-Match'] == etag) {
            notModified++;
            return http.Response('', 304, headers: {'etag': etag});
          }
          return http.Response.bytes(utf8.encode(jsonEncode(manifest())), 200,
              headers: {'content-type': 'application/json', 'etag': etag});
        }
        languageCalls++;
        return http.Response('{}', 404);
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('availableLanguageCodes', () {
    final mapping = map({
      'en': ['SA', 'IN'],
      'ar': ['SA'],
    });

    test('lists only the languages mapped to the country', () {
      expect(
          availableLanguageCodes(
              bundled: bundled, countryIso: 'IN', mapping: mapping),
          ['en']);
      expect(
          availableLanguageCodes(
              bundled: bundled, countryIso: 'SA', mapping: mapping),
          ['en', 'ar']);
    });

    test('country code case does not matter', () {
      expect(
          availableLanguageCodes(
              bundled: bundled, countryIso: ' sa ', mapping: mapping),
          ['en', 'ar']);
    });

    test('unknown country or no mapping lists English only (strict policy)', () {
      expect(
          availableLanguageCodes(
              bundled: bundled, countryIso: null, mapping: mapping),
          ['en']);
      expect(
          availableLanguageCodes(
              bundled: bundled, countryIso: '', mapping: mapping),
          ['en']);
      expect(
          availableLanguageCodes(
              bundled: bundled, countryIso: 'SA', mapping: const {}),
          ['en']);
    });

    test('a language with no countries, or not listed for the country, is NOT offered', () {
      expect(
          availableLanguageCodes(
              bundled: bundled,
              countryIso: 'JO',
              mapping: map({'en': ['SA'], 'ar': []})),
          ['en']);
      expect(
          availableLanguageCodes(
              bundled: bundled,
              countryIso: 'JO',
              mapping: map({'en': ['SA']})),
          ['en']);
    });

    test('English is always allowed, even when the mapping does not list the country for it', () {
      expect(
          availableLanguageCodes(
              bundled: bundled, countryIso: 'JO', mapping: mapping),
          ['en']);
    });

    test('Arabic mapped to Saudi Arabia only is never offered to India, unless the admin maps it', () {
      expect(
          availableLanguageCodes(
              bundled: bundled, countryIso: 'IN', mapping: mapping),
          ['en']);
      expect(
          availableLanguageCodes(
              bundled: bundled,
              countryIso: 'IN',
              mapping: map({'en': ['SA', 'IN'], 'ar': ['SA', 'IN']})),
          ['en', 'ar']);
    });

    test('the language in use gets no exception: isLanguageAllowed says no for Arabic in India', () {
      expect(
          isLanguageAllowed(
              code: 'ar', bundled: bundled, countryIso: 'IN', mapping: mapping),
          isFalse);
      expect(
          isLanguageAllowed(
              code: 'ar', bundled: bundled, countryIso: 'SA', mapping: mapping),
          isTrue);
      expect(
          isLanguageAllowed(
              code: 'en', bundled: bundled, countryIso: null, mapping: const {}),
          isTrue);
    });

    test('returns a copy and keeps the bundled order', () {
      final b = ['ar', 'en'];
      final out = availableLanguageCodes(
          bundled: b, countryIso: null, mapping: const {});
      out.add('xx');
      expect(b, ['ar', 'en']);
      expect(
          availableLanguageCodes(
              bundled: ['ar', 'en'], countryIso: 'SA', mapping: mapping),
          ['ar', 'en']);
    });

    test('without a published mapping the chooser lists English only', () {
      // The app-wide service is disabled in tests, so it has no mapping: nothing but English is offered, for any country.
      expect(languageCodesForCountry('SA'), ['en']);
      expect(languageCodesForCountry('IN'), ['en']);
      expect(languageCodesForCountry(null), ['en']);
    });
  });

  group('countryIsoForPhone', () {
    test('recognises the five supported countries from a stored number', () {
      expect(countryIsoForPhone('+966501234567'), 'SA');
      expect(countryIsoForPhone('+919876543210'), 'IN');
      expect(countryIsoForPhone('+962791234567'), 'JO');
      expect(countryIsoForPhone('+9779812345678'), 'NP');
      expect(countryIsoForPhone('+639171234567'), 'PH');
      expect(countryIsoForPhone('00966501234567'), 'SA');
      expect(countryIsoForPhone(' +966 50 123 4567 '), 'SA');
    });

    test('legacy Indian shapes are India; nothing else is guessed', () {
      expect(countryIsoForPhone('9876543210'), 'IN');
      expect(countryIsoForPhone('919876543210'), 'IN');
      expect(countryIsoForPhone('+14155552671'), isNull);
      expect(countryIsoForPhone('501234567'), isNull);
      expect(countryIsoForPhone(''), isNull);
      expect(countryIsoForPhone(null), isNull);
      expect(countryIsoForPhone('abc'), isNull);
    });
  });

  group('manifest parsing', () {
    Map<String, Object?> base([Object? lc = _absent]) => {
          'schema': 1,
          'kill_switch': false,
          'overrides_enabled': true,
          'languages': <Object?>[],
          if (!identical(lc, _absent)) 'language_countries': lc,
        };

    test('reads the mapping', () {
      final m = RemoteTranslationValidator.parseManifest(base({
        'en': ['SA', 'IN'],
        'ar': ['SA'],
      }))!;
      expect(m.languageCountries, map({'en': ['SA', 'IN'], 'ar': ['SA']}));
      expect(m.active, isTrue);
    });

    test('an older backend (no mapping) still parses, with an empty mapping (English only)', () {
      final m = RemoteTranslationValidator.parseManifest(base())!;
      expect(m.languageCountries, isEmpty);
      expect(m.appTracks, isEmpty);
    });

    test('malformed mapping is skipped, never an error', () {
      for (final bad in <Object?>[
        'x',
        5,
        null,
        ['SA'],
        {'en': 'SA'},
        {'EN!': ['SA']},
        {1: ['SA']},
      ]) {
        final m = RemoteTranslationValidator.parseManifest(base(bad));
        expect(m, isNotNull, reason: '$bad');
        expect(m!.languageCountries, isEmpty, reason: '$bad');
      }
      final m = RemoteTranslationValidator.parseManifest(base({
        'en': ['SA', 'sa', 'SAU', 5, null, 'IN'],
      }))!;
      expect(m.languageCountries['en'], {'SA', 'IN'});
    });

    test('is bounded', () {
      final many = {
        for (var i = 0; i < 80; i++)
          '${String.fromCharCode(97 + i ~/ 26)}${String.fromCharCode(97 + i % 26)}':
              ['SA'],
      };
      final m = RemoteTranslationValidator.parseManifest(base(many))!;
      expect(m.languageCountries.length,
          lessThanOrEqualTo(RemoteTranslationValidator.maxMappedLanguages));
    });

    test('the mapping does not change tracks, versions or the kill switch', () {
      final withMap = RemoteTranslationValidator.parseManifest({
        ...base({'en': ['SA']}),
        'kill_switch': true,
        'overrides_enabled': false,
      })!;
      expect(withMap.active, isFalse);
    });
  });

  group('service keeps the mapping', () {
    late Be be;
    late DateTime now;
    final made = <RemoteTranslationService>[];

    RemoteTranslationService make(
        {bool enabled = true, Duration gap = Duration.zero}) {
      final s = RemoteTranslationService(
        enabled: enabled,
        baseUrl: stagingUrl,
        client: be.client,
        clock: () => now,
        currentLanguage: () => 'en',
        minAttemptGap: gap,
        minCheckInterval: Duration.zero,
        retryDelays: const [],
      );
      made.add(s);
      return s;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      be = Be();
      now = DateTime.utc(2026, 11, 22, 10);
      LocaleController.instance.resetForTest();
    });
    tearDown(() {
      for (final s in made) {
        s.dispose();
      }
      made.clear();
    });

    test('a refresh publishes the mapping and notifies once', () async {
      final s = make();
      var notified = 0;
      s.addListener(() => notified++);
      await s.refresh();
      expect(s.languageCountries, map({'en': ['SA', 'IN'], 'ar': ['SA']}));
      expect(notified, 1);
      await s.refresh(); // same mapping again: no extra notification
      expect(notified, 1);
    });

    test('refreshCountries reads only the manifest', () async {
      final s = make();
      await s.refreshCountries();
      expect(be.manifestCalls, 1);
      expect(be.languageCalls, 0);
      expect(s.languageCountries['ar'], {'SA'});
    });

    test('refreshCountries is throttled', () async {
      final s = make(gap: const Duration(seconds: 20));
      await s.refreshCountries();
      await s.refreshCountries();
      expect(be.manifestCalls, 1);
    });

    test('a changed mapping replaces the old one', () async {
      final s = make();
      await s.refreshCountries();
      be
        ..mapping = {
          'en': ['IN'],
          'ar': ['SA', 'JO'],
        }
        ..etag = '"m2"';
      await s.refreshCountries();
      expect(s.languageCountries, map({'en': ['IN'], 'ar': ['SA', 'JO']}));
    });

    test('304 keeps the mapping', () async {
      final s = make();
      await s.refreshCountries();
      await s.refreshCountries();
      expect(be.notModified, 1);
      expect(s.languageCountries['en'], {'SA', 'IN'});
    });

    test('kill switch clears the mapping, so English only is listed', () async {
      final s = make();
      await s.refreshCountries();
      expect(s.languageCountries, isNotEmpty);
      be
        ..kill = true
        ..etag = '"m3"';
      await s.refreshCountries();
      expect(s.languageCountries, isEmpty);
      expect(
          availableLanguageCodes(
              bundled: bundled,
              countryIso: 'IN',
              mapping: s.languageCountries),
          ['en']);
    });

    test('offline: the failure keeps what the app already has', () async {
      final s = make();
      await s.refreshCountries();
      be.offline = true;
      await s.refreshCountries();
      expect(s.languageCountries['ar'], {'SA'});
    });

    test('the stored manifest gives the mapping after a restart, offline',
        () async {
      await make().refreshCountries();
      be.offline = true;
      final restarted = make();
      expect(restarted.languageCountries, isEmpty);
      await restarted.init();
      expect(restarted.languageCountries,
          map({'en': ['SA', 'IN'], 'ar': ['SA']}));
    });

    test('a stored kill-switch manifest gives no mapping', () async {
      be.kill = true;
      await make().refreshCountries();
      final restarted = make();
      await restarted.init();
      expect(restarted.languageCountries, isEmpty);
    });

    test('disabled service: no request, no mapping', () async {
      final s = make(enabled: false);
      await s.init();
      await s.refreshCountries();
      expect(be.manifestCalls, 0);
      expect(s.languageCountries, isEmpty);
    });

    test('a malformed mapping on the server only means an empty mapping (English only)', () async {
      be.mapping = 'garbage';
      final s = make();
      await s.refreshCountries();
      expect(s.languageCountries, isEmpty);
      expect(be.manifestCalls, 1);
    });
  });
}

const Object _absent = Object();
