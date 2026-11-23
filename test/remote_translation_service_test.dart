// Phase K: the remote translation service against a fake backend (no real network, no real storage).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/l10n/locale_controller.dart';
import 'package:offro_user/core/l10n/remote/generated/app_localizations_ar_remote.dart';
import 'package:offro_user/core/l10n/remote/generated/remote_l10n_schema.dart';
import 'package:offro_user/core/l10n/remote/remote_overrides.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_cache.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_service.dart';
import 'package:offro_user/l10n/gen/app_localizations_ar.dart';

const String stagingUrl = 'https://offro-backend-staging-d375.up.railway.app';

String hashOf(int n) => n.toRadixString(16).padLeft(64, '0');
List<String> plainKeys(int n) => kRemoteL10nSchema.entries
    .where((e) => e.value.isEmpty)
    .map((e) => e.key)
    .take(n)
    .toList();

/// A scriptable backend. Mutate the fields between refreshes to simulate publishing, rollback, kill switch and failures.
class FakeBackend {
  bool kill = false;
  bool overridesEnabled = true;
  int? version = 1; // null = Arabic not published
  String? manifestHash; // defaults to hashOf(version)
  Map<String, Object?> strings = {};
  int manifestStatus = 200;
  int languageStatus = 200;
  Object? rawManifestBody; // overrides the JSON manifest (e.g. invalid JSON)
  Object? rawLanguageBody;
  Object? languageOverride; // a full replacement language document
  bool offline = false;
  bool hang = false;
  int manifestCalls = 0;
  int languageCalls = 0;
  final List<Uri> requests = [];

  String get hash => manifestHash ?? hashOf(version ?? 0);

  Map<String, Object?> manifestJson() => {
        'schema': 1,
        'kill_switch': kill,
        'overrides_enabled': overridesEnabled && !kill,
        'languages': kill || version == null
            ? <Object?>[]
            : [
                {
                  'code': 'ar',
                  'name_en': 'Arabic',
                  'name_native': 'Arabic',
                  'direction': 'rtl',
                  'tracks': {
                    'app': {'version': version, 'hash': hash},
                  },
                },
              ],
      };

  Map<String, Object?> languageJson() => {
        'schema': 1,
        'lang': 'ar',
        'track': 'app',
        'version': version,
        'direction': 'rtl',
        'hash': hash,
        'strings': strings,
      };

  http.Response _json(Object body, int status) => http.Response.bytes(
      body is String ? utf8.encode(body) : utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'});

  MockClient get client => MockClient((req) async {
        requests.add(req.url);
        if (hang) await Completer<void>().future;
        if (offline) throw http.ClientException('no route to host');
        if (req.url.path == '/translations/manifest') {
          manifestCalls++;
          return _json(rawManifestBody ?? manifestJson(), manifestStatus);
        }
        if (req.url.path == '/translations/ar') {
          languageCalls++;
          if (languageStatus == 404)
            return _json({'detail': 'not_available'}, 404);
          return _json(rawLanguageBody ?? languageOverride ?? languageJson(),
              languageStatus);
        }
        return _json({'detail': 'not_found'}, 404);
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBackend be;
  late DateTime now;
  late String lang;
  final services = <RemoteTranslationService>[];

  RemoteTranslationService make({
    bool enabled = true,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 5),
    Duration gap = Duration.zero,
    Duration checkInterval = Duration.zero,
    Duration cacheMaxAge = const Duration(days: 14),
    List<Duration> retryDelays = const [],
  }) {
    final s = RemoteTranslationService(
      enabled: enabled,
      baseUrl: baseUrl ?? stagingUrl,
      client: be.client,
      clock: () => now,
      currentLanguage: () => lang,
      requestTimeout: timeout,
      minAttemptGap: gap,
      minCheckInterval: checkInterval,
      cacheMaxAge: cacheMaxAge,
      retryDelays: retryDelays,
    );
    services.add(s);
    return s;
  }

  Future<CachedTranslations?> cached() => RemoteTranslationCache(environment: 'staging').read('ar');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    be = FakeBackend();
    now = DateTime.utc(2026, 11, 21, 10);
    lang = 'ar';
    LocaleController.instance.resetForTest();
  });
  tearDown(() {
    for (final s in services) {
      s.dispose();
    }
    services.clear();
    LocaleController.instance.resetForTest();
  });

  group('1. remote translations disabled', () {
    test('no request, no cache read, no overrides', () async {
      await RemoteTranslationCache(environment: 'staging').write(CachedTranslations(
          lang: 'ar',
          version: 3,
          hash: hashOf(3),
          strings: {plainKeys(1).single: 'cached'},
          checkedAtMs: now.millisecondsSinceEpoch));
      final s = make(enabled: false);
      await s.init();
      s.attach();
      expect(await s.refresh(reason: RemoteRefreshReason.startup),
          RemoteRefreshOutcome.disabled);
      expect(await s.refresh(), RemoteRefreshOutcome.disabled);
      expect(be.requests, isEmpty);
      expect(s.overrides.isEmpty, isTrue);
      expect(s.overridesFor('ar').isEmpty, isTrue);
    });
  });

  group('2/4. enabled, Arabic published', () {
    test('downloads, validates, caches and applies', () async {
      final keys = plainKeys(3);
      be
        ..version = 2
        ..strings = {for (final k in keys) k: 'remote $k'};
      final s = make();
      var notified = 0;
      s.addListener(() => notified++);
      expect(await s.refresh(reason: RemoteRefreshReason.startup),
          RemoteRefreshOutcome.updated);
      expect(s.overridesFor('ar').strings[keys.first], 'remote ${keys.first}');
      expect(s.overridesFor('ar').version, 2);
      expect(notified, 1);
      final c = await cached();
      expect(c!.version, 2);
      expect(c.strings.length, 3);
      expect(be.requests.map((u) => u.path),
          ['/translations/manifest', '/translations/ar']);
      expect(be.requests.last.queryParameters['track'], 'app');
    });
    test('Arabic text is decoded as UTF-8', () async {
      final k = plainKeys(1).single;
      be.strings = {k: '\u0645\u0631\u062d\u0628\u0627'};
      final s = make();
      await s.refresh();
      expect(s.overrides.strings[k], '\u0645\u0631\u062d\u0628\u0627');
    });
    test('English is never overridden, even when overrides exist', () async {
      be.strings = {plainKeys(1).single: 'x'};
      final s = make();
      await s.refresh();
      expect(s.overridesFor('en').isEmpty, isTrue);
    });
    test('a trailing slash in the base URL is tolerated', () async {
      final s = make(baseUrl: '$stagingUrl/');
      await s.refresh();
      expect(be.requests.first.toString(), '$stagingUrl/translations/manifest');
    });
  });

  group('3. Arabic not published', () {
    test('overrides and cache are removed', () async {
      final s = make();
      be.strings = {plainKeys(1).single: 'x'};
      await s.refresh();
      expect(s.overrides.isEmpty, isFalse);
      be.version = null;
      expect(await s.refresh(), RemoteRefreshOutcome.notPublished);
      expect(s.overrides.isEmpty, isTrue);
      expect(await cached(), isNull);
      expect(be.languageCalls, 1,
          reason:
              'the language file is not requested when nothing is published');
    });
    test(
        'a 404 on the language file (kill switch raced in) falls back to bundled text',
        () async {
      final s = make();
      be
        ..languageStatus = 404
        ..strings = {plainKeys(1).single: 'x'};
      expect(await s.refresh(), RemoteRefreshOutcome.notPublished);
      expect(s.overrides.isEmpty, isTrue);
    });
  });

  group('5/6. missing and empty remote values', () {
    test('only valid entries are applied; the rest stays bundled', () async {
      final keys = plainKeys(10);
      be.strings = {
        for (final k in keys.take(7)) k: 'remote $k',
        keys[7]: '',
        keys[8]: '   ',
        // keys[9] is simply absent from the remote set
      };
      final s = make();
      expect(await s.refresh(), RemoteRefreshOutcome.updated);
      expect(s.overrides.strings.keys.toSet(), keys.take(7).toSet());
      expect(s.overrides.strings.containsKey(keys[7]), isFalse);
      expect(s.overrides.strings.containsKey(keys[8]), isFalse);
    });
    test(
        'a file whose values are mostly empty is rejected as a whole and the cache is kept',
        () async {
      final keys = plainKeys(8);
      be.strings = {for (final k in keys) k: 'good'};
      final s = make();
      await s.refresh();
      be
        ..version = 2
        ..strings = {for (final k in keys) k: ''};
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.version, 1);
      expect((await cached())!.version, 1);
      expect(s.overrides.strings[keys.first], 'good');
    });
  });

  group('7. invalid JSON / malformed data', () {
    test('invalid language JSON keeps the current set and cache', () async {
      be.strings = {plainKeys(1).single: 'good'};
      final s = make();
      await s.refresh();
      be
        ..version = 2
        ..rawLanguageBody = '{ this is not json';
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.version, 1);
      expect((await cached())!.version, 1);
    });
    test('invalid manifest JSON keeps what is in use', () async {
      be.strings = {plainKeys(1).single: 'good'};
      final s = make();
      await s.refresh();
      be.rawManifestBody = 'garbage';
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.isEmpty, isFalse);
    });
    test('a manifest with a wrong shape does not clear anything', () async {
      be.strings = {plainKeys(1).single: 'good'};
      final s = make();
      await s.refresh();
      be.rawManifestBody = {'schema': 1, 'languages': 'nope'};
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.isEmpty, isFalse);
    });
    test('a language file for another language or track is rejected', () async {
      be
        ..strings = {plainKeys(1).single: 'x'}
        ..languageOverride = {...be.languageJson(), 'lang': 'fr'};
      final s = make();
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.isEmpty, isTrue);
      expect(await cached(), isNull);
    });
    test('a file that disagrees with the manifest hash is rejected', () async {
      be
        ..strings = {plainKeys(1).single: 'x'}
        ..languageOverride = {...be.languageJson(), 'hash': hashOf(999)};
      final s = make();
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.isEmpty, isTrue);
    });
    test('a stale language file (older than the manifest) is rejected',
        () async {
      be
        ..version = 5
        ..strings = {plainKeys(1).single: 'x'}
        ..languageOverride = {...be.languageJson(), 'version': 4};
      final s = make();
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.isEmpty, isTrue);
    });
    test('an oversized response is rejected', () async {
      be.rawLanguageBody = 'x' * (2 * 1024 * 1024 + 10);
      final s = make();
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
    });
  });

  group('8. invalid placeholders', () {
    test('an entry with wrong placeholders is skipped, others still apply',
        () async {
      final plain = plainKeys(9);
      final p =
          kRemoteL10nSchema.entries.firstWhere((e) => e.value.length == 1);
      be.strings = {
        for (final k in plain) k: 'ok $k',
        p.key: 'text {definitely_not_${p.value.single}}',
      };
      final s = make();
      expect(await s.refresh(), RemoteRefreshOutcome.updated);
      expect(s.overrides.strings.containsKey(p.key), isFalse);
      expect(s.overrides.strings.length, 9);
    });
    test('a file where every entry has wrong placeholders is rejected',
        () async {
      final p =
          kRemoteL10nSchema.entries.firstWhere((e) => e.value.length == 1);
      be.strings = {p.key: 'no placeholder at all'};
      final s = make();
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.isEmpty, isTrue);
    });
  });

  group('9. API timeout / 10. no internet / HTTP errors', () {
    test('timeout keeps the current set', () async {
      be.strings = {plainKeys(1).single: 'good'};
      final s = make(timeout: const Duration(milliseconds: 40));
      await s.refresh();
      be.hang = true;
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.isEmpty, isFalse);
    });
    test('no internet keeps the current set', () async {
      be.strings = {plainKeys(1).single: 'good'};
      final s = make();
      await s.refresh();
      be.offline = true;
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.isEmpty, isFalse);
      expect((await cached())!.version, 1);
    });
    test('no internet and nothing cached = bundled text, no crash', () async {
      be.offline = true;
      final s = make();
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.isEmpty, isTrue);
    });
    test('429 / 500 / 503 / 404 manifest never clear a working set', () async {
      be.strings = {plainKeys(1).single: 'good'};
      final s = make();
      await s.refresh();
      for (final code in [429, 500, 503, 404, 302]) {
        be.manifestStatus = code;
        expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent,
            reason: '$code');
        expect(s.overrides.isEmpty, isFalse, reason: '$code');
      }
    });
    test(
        'a failure schedules a bounded retry (the timer runs once per delay and stops)',
        () async {
      be.offline = true;
      final s = make(retryDelays: const [
        Duration(milliseconds: 20),
        Duration(milliseconds: 20)
      ]);
      await s.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(be.requests.length, 3,
          reason:
              'one attempt + two retries, then it stops until the next trigger');
    });
  });

  group('11. cached translation fallback', () {
    Future<void> seed({required int ageDays, int version = 7}) =>
        RemoteTranslationCache(environment: 'staging').write(CachedTranslations(
          lang: 'ar',
          version: version,
          hash: hashOf(version),
          strings: {plainKeys(1).single: 'from cache'},
          checkedAtMs:
              now.subtract(Duration(days: ageDays)).millisecondsSinceEpoch,
        ));

    test('a fresh cache is used at start, offline, without any request',
        () async {
      await seed(ageDays: 1);
      be.offline = true;
      final s = make();
      await s.init();
      expect(s.overridesFor('ar').strings[plainKeys(1).single], 'from cache');
      expect(s.overrides.version, 7);
      expect(be.requests, isEmpty);
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.version, 7,
          reason: 'still on the cache after a failed refresh');
    });
    test('an expired cache is not used', () async {
      await seed(ageDays: 30);
      final s = make();
      await s.init();
      expect(s.overrides.isEmpty, isTrue);
    });
    test('a cache dated in the future is not used', () async {
      await seed(ageDays: -3);
      final s = make();
      await s.init();
      expect(s.overrides.isEmpty, isTrue);
    });
    test('a corrupted cache is ignored without a crash', () async {
      SharedPreferences.setMockInitialValues(
          {RemoteTranslationCache.keyFor('ar'): '{broken'});
      final s = make();
      await s.init();
      expect(s.overrides.isEmpty, isTrue);
      SharedPreferences.setMockInitialValues(
          {RemoteTranslationCache.keyFor('ar'): 42});
      await make().init();
    });
    test(
        'cache entries that no longer fit this app version are dropped, valid ones stay',
        () async {
      final k = plainKeys(1).single;
      SharedPreferences.setMockInitialValues({
        RemoteTranslationCache.keyFor('ar'): jsonEncode({
          'format': 1,
          'lang': 'ar',
          'version': 2,
          'hash': hashOf(2),
          'checked_at': now.millisecondsSinceEpoch,
          // Stored by a STAGING build (the service under test is a staging service). Since Stage 5 every stored entry carries the
          // environment that wrote it, and an entry without a matching label is ignored on purpose.
          'environment': 'staging',
          'strings': {k: 'ok'},
        }),
      });
      final s = make();
      await s.init();
      expect(s.overrides.strings, {k: 'ok'});
    });
    test(
        'incompatible entries inside a cache are dropped while the valid ones stay',
        () async {
      final good = plainKeys(4);
      SharedPreferences.setMockInitialValues({
        RemoteTranslationCache.keyFor('ar'): jsonEncode({
          'format': 1,
          'lang': 'ar',
          'version': 2,
          'hash': hashOf(2),
          'checked_at': now.millisecondsSinceEpoch,
          'environment': 'staging',
          'strings': {
            for (final g in good) g: 'ok $g',
            'keyThatThisAppVersionDoesNotHave': 'x',
          },
        }),
      });
      final s = make();
      await s.init();
      expect(s.overrides.strings, {for (final g in good) g: 'ok $g'});
    });
    test(
        'a cache stored without an environment label, or by the other environment, is ignored',
        () async {
      final k = plainKeys(1).single;
      for (final env in <String?>[null, 'production']) {
        SharedPreferences.setMockInitialValues({
          RemoteTranslationCache.keyFor('ar'): jsonEncode({
            'format': 1,
            'lang': 'ar',
            'version': 2,
            'hash': hashOf(2),
            'checked_at': now.millisecondsSinceEpoch,
            if (env != null) 'environment': env,
            'strings': {k: 'ok'},
          }),
        });
        final s = make();
        await s.init();
        expect(s.overrides.isEmpty, isTrue, reason: 'environment=$env');
      }
    });
    test('an unchanged check refreshes the cache age without downloading',
        () async {
      await seed(ageDays: 10, version: 1);
      be.strings = {plainKeys(1).single: 'from cache'};
      final s = make();
      await s.init();
      expect(await s.refresh(), RemoteRefreshOutcome.unchanged);
      expect(be.languageCalls, 0);
      expect((await cached())!.checkedAtMs, now.millisecondsSinceEpoch);
    });
    test('an invalid refresh never overwrites a valid cache', () async {
      await seed(ageDays: 1, version: 1);
      be
        ..version = 2
        ..rawLanguageBody = 'not json';
      final s = make();
      await s.init();
      await s.refresh();
      final c = await cached();
      expect(c!.version, 1);
      expect(c.strings.values.single, 'from cache');
    });
  });

  group('12. published version update', () {
    test(
        'a new version is downloaded; the same version is not downloaded again',
        () async {
      final k = plainKeys(2);
      be
        ..version = 1
        ..strings = {k[0]: 'one'};
      final s = make();
      expect(await s.refresh(), RemoteRefreshOutcome.updated);
      expect(await s.refresh(), RemoteRefreshOutcome.unchanged);
      expect(be.languageCalls, 1);
      be
        ..version = 2
        ..strings = {k[0]: 'two', k[1]: 'second'};
      var notified = 0;
      s.addListener(() => notified++);
      expect(await s.refresh(), RemoteRefreshOutcome.updated);
      expect(be.languageCalls, 2);
      expect(s.overrides.version, 2);
      expect(s.overrides.strings[k[0]], 'two');
      expect(notified, 1);
      expect((await cached())!.version, 2);
    });
    test('a rollback (new higher version, different hash) is picked up',
        () async {
      final k = plainKeys(1).single;
      be
        ..version = 2
        ..strings = {k: 'two'};
      final s = make();
      await s.refresh();
      be
        ..version = 3
        ..strings = {k: 'one again'};
      expect(await s.refresh(), RemoteRefreshOutcome.updated);
      expect(s.overrides.strings[k], 'one again');
    });
    test('the same version number with a different hash is treated as a change',
        () async {
      final k = plainKeys(1).single;
      be
        ..version = 2
        ..strings = {k: 'a'};
      final s = make();
      await s.refresh();
      be
        ..manifestHash = hashOf(77)
        ..strings = {k: 'b'};
      expect(await s.refresh(), RemoteRefreshOutcome.updated);
      expect(s.overrides.strings[k], 'b');
    });
    test('a successful update after a failure recovers', () async {
      be.offline = true;
      final s = make();
      await s.refresh();
      be
        ..offline = false
        ..strings = {plainKeys(1).single: 'x'};
      expect(await s.refresh(), RemoteRefreshOutcome.updated);
    });
  });

  group('13/14. kill switch', () {
    test(
        'ON removes overrides and cache and notifies once; OFF brings them back',
        () async {
      final k = plainKeys(1).single;
      be.strings = {k: 'remote'};
      final s = make();
      await s.refresh();
      expect(s.overridesFor('ar').strings[k], 'remote');
      var notified = 0;
      s.addListener(() => notified++);

      be.kill = true;
      expect(await s.refresh(), RemoteRefreshOutcome.killSwitch);
      expect(s.overridesFor('ar').isEmpty, isTrue);
      expect(await cached(), isNull);
      expect(notified, 1);
      expect(be.languageCalls, 1,
          reason: 'no language request while the kill switch is on');

      expect(await s.refresh(), RemoteRefreshOutcome.killSwitch);
      expect(notified, 1, reason: 'already off: no second notification');

      be.kill = false;
      expect(await s.refresh(), RemoteRefreshOutcome.updated);
      expect(s.overridesFor('ar').strings[k], 'remote');
      expect(notified, 2);
      expect(await cached(), isNotNull);
    });
    test('overrides_enabled=false alone also stops the overrides', () async {
      be.strings = {plainKeys(1).single: 'remote'};
      final s = make();
      await s.refresh();
      be.overridesEnabled = false;
      expect(await s.refresh(), RemoteRefreshOutcome.killSwitch);
      expect(s.overrides.isEmpty, isTrue);
    });
    test(
        'a kill switch seen while offline later is not undone by the old cache',
        () async {
      be.strings = {plainKeys(1).single: 'remote'};
      final s = make();
      await s.refresh();
      be.kill = true;
      await s.refresh();
      final fresh = make();
      be.offline = true;
      await fresh.init();
      expect(fresh.overrides.isEmpty, isTrue);
    });
  });

  group('lifecycle and traffic control', () {
    test('English users cause no requests from automatic triggers', () async {
      lang = 'en';
      final s = make();
      for (final r in [
        RemoteRefreshReason.startup,
        RemoteRefreshReason.resume,
        RemoteRefreshReason.retry
      ]) {
        expect(
            await s.refresh(reason: r), RemoteRefreshOutcome.skippedNotNeeded);
      }
      expect(be.requests, isEmpty);
    });
    test('concurrent triggers share one request', () async {
      final s = make();
      final a = s.refresh(reason: RemoteRefreshReason.startup);
      final b = s.refresh(reason: RemoteRefreshReason.languageSelected);
      expect(await a, await b);
      expect(be.manifestCalls, 1);
    });
    test('attempts closer than the minimum gap are throttled', () async {
      final s = make(gap: const Duration(seconds: 20));
      await s.refresh(reason: RemoteRefreshReason.startup);
      expect(await s.refresh(reason: RemoteRefreshReason.languageSelected),
          RemoteRefreshOutcome.skippedThrottled);
      now = now.add(const Duration(seconds: 25));
      expect(await s.refresh(reason: RemoteRefreshReason.languageSelected),
          isNot(RemoteRefreshOutcome.skippedThrottled));
    });
    test('resume checks at most once per interval', () async {
      final s = make(checkInterval: const Duration(minutes: 15));
      await s.refresh(reason: RemoteRefreshReason.startup);
      now = now.add(const Duration(minutes: 5));
      expect(await s.refresh(reason: RemoteRefreshReason.resume),
          RemoteRefreshOutcome.skippedThrottled);
      now = now.add(const Duration(minutes: 11));
      expect(await s.refresh(reason: RemoteRefreshReason.resume),
          RemoteRefreshOutcome.unchanged);
    });
    test('selecting Arabic triggers a refresh; selecting English does not',
        () async {
      lang = 'en';
      final s = make();
      s.attach();
      lang = 'ar';
      await LocaleController.instance
          .setLanguage('ar'); // the service listens to LocaleController
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(be.manifestCalls, 1);
      lang = 'en';
      await LocaleController.instance.setLanguage('en');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(be.manifestCalls, 1);
    });
    test('app resume triggers a refresh while Arabic is selected', () async {
      final s = make();
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(be.manifestCalls, 1);
    });
  });

  group('publish -> app refresh (Rewards walletVoucherRate)', () {
    const key = 'walletVoucherRate'; // "{points} pts = INR 20 voucher": the Rewards text the admin republished
    const oldText = '{points} \u0646\u0642\u0637\u0629 = \u0642\u0633\u064a\u0645\u0629 \u20b920';
    const newText = '{points} \u0646\u0642\u0637\u0629 = \u0642\u0633\u064a\u0645\u0629 5 \u0631\u064a\u0627\u0644';

    test('the bundled Arabic text is what shows when nothing was ever published', () {
      expect(AppLocalizationsAr().walletVoucherRate('1500'), contains('1500'));
      expect(AppLocalizationsArRemote(const {}).walletVoucherRate('1500'),
          AppLocalizationsAr().walletVoucherRate('1500'));
    });

    test('a newly published version replaces the old cached value, with {points} preserved', () async {
      be
        ..version = 1
        ..strings = {key: oldText};
      final s = make();
      expect(await s.refresh(reason: RemoteRefreshReason.startup), RemoteRefreshOutcome.updated);
      expect(AppLocalizationsArRemote(s.overrides.strings).walletVoucherRate('1500'),
          '1500 \u0646\u0642\u0637\u0629 = \u0642\u0633\u064a\u0645\u0629 \u20b920');
      // The admin edits the text and publishes again: new version AND new hash.
      be
        ..version = 2
        ..strings = {key: newText};
      expect(await s.refresh(reason: RemoteRefreshReason.manual), RemoteRefreshOutcome.updated);
      expect(s.overrides.version, 2);
      final shown = AppLocalizationsArRemote(s.overrides.strings).walletVoucherRate('1500');
      expect(shown, '1500 \u0646\u0642\u0637\u0629 = \u0642\u0633\u064a\u0645\u0629 5 \u0631\u064a\u0627\u0644');
      expect(shown.contains('{points}'), isFalse);
      expect((await cached())!.strings[key], newText); // the cache holds the new value, not the old one
    });

    test('a changed version/hash in the manifest is detected; the same one is not downloaded again', () async {
      be
        ..version = 1
        ..strings = {key: oldText};
      final s = make();
      await s.refresh();
      expect(be.languageCalls, 1);
      expect(await s.refresh(), RemoteRefreshOutcome.unchanged);
      expect(be.languageCalls, 1, reason: 'same version + hash: only the small manifest is requested');
      be
        ..manifestHash = hashOf(99) // same version, a different hash (re-publish)
        ..strings = {key: newText};
      expect(await s.refresh(), RemoteRefreshOutcome.updated);
      expect(be.languageCalls, 2);
      expect(s.overrides.strings[key], newText);
    });

    test('offline: the last valid translation stays in use', () async {
      be
        ..version = 1
        ..strings = {key: oldText};
      final s = make();
      await s.refresh();
      be
        ..offline = true
        ..version = 2
        ..strings = {key: newText};
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.strings[key], oldText);
      expect((await cached())!.strings[key], oldText);
    });

    test('failed API requests (5xx, bad JSON) never remove what works and never break the bundled text', () async {
      be
        ..version = 1
        ..strings = {key: oldText};
      final s = make();
      await s.refresh();
      be.manifestStatus = 503;
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      be
        ..manifestStatus = 200
        ..version = 2
        ..languageStatus = 500;
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      be
        ..languageStatus = 200
        ..rawLanguageBody = 'not json';
      expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(s.overrides.strings[key], oldText);
      // A service that never got anything still shows the bundled Arabic text.
      final fresh = make();
      be
        ..offline = true
        ..rawLanguageBody = null;
      expect(await fresh.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
      expect(AppLocalizationsArRemote(fresh.overrides.strings).walletVoucherRate('7'),
          AppLocalizationsAr().walletVoucherRate('7'));
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('${platform.name}: the manifest and the language file load the same way', () async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        be
          ..version = 3
          ..strings = {key: newText};
        final s = make();
        expect(await s.refresh(reason: RemoteRefreshReason.startup), RemoteRefreshOutcome.updated);
        expect(be.requests.map((u) => u.path), ['/translations/manifest', '/translations/ar']);
        expect(s.overrides.strings[key], newText);
      });
    }

    test('app resume re-checks after 5 minutes by default (was 15), and only one small request when nothing changed', () async {
      expect(RemoteTranslationService(enabled: false).minCheckInterval, const Duration(minutes: 5));
      be.strings = {key: oldText};
      final s = make(checkInterval: const Duration(minutes: 5));
      await s.refresh(reason: RemoteRefreshReason.startup);
      now = now.add(const Duration(minutes: 2));
      expect(await s.refresh(reason: RemoteRefreshReason.resume), RemoteRefreshOutcome.skippedThrottled);
      now = now.add(const Duration(minutes: 4));
      be
        ..version = 2
        ..strings = {key: newText};
      expect(await s.refresh(reason: RemoteRefreshReason.resume), RemoteRefreshOutcome.updated);
      expect(s.overrides.strings[key], newText);
    });
  });

  group('RemoteOverrides value semantics', () {
    test('equal by language, version and hash', () {
      const a = RemoteOverrides(
          lang: 'ar', version: 1, hash: 'h', strings: {'a': 'x'});
      const b = RemoteOverrides(
          lang: 'ar', version: 1, hash: 'h', strings: {'a': 'x'});
      const c = RemoteOverrides(
          lang: 'ar', version: 2, hash: 'h', strings: {'a': 'x'});
      expect(a == b, isTrue);
      expect(a == c, isFalse);
      expect(RemoteOverrides.empty == RemoteOverrides.empty, isTrue);
    });
  });
}
