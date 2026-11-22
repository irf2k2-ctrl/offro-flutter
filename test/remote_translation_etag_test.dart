// Client-side ETag support for remote translations (If-None-Match, 304, per-environment persistence, fallback on failure).
// Uses a fake backend that behaves like the real one (ETag on 200, 304 when If-None-Match matches); no real network or storage.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/l10n/locale_controller.dart';
import 'package:offro_user/core/l10n/remote/generated/remote_l10n_schema.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_cache.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_service.dart';

const String stagingUrl = 'https://offro-backend-staging-d375.up.railway.app';
const String productionUrl = 'https://offro-backend-production.up.railway.app';

String hashOf(int n) => n.toRadixString(16).padLeft(64, '0');
String get aKey =>
    kRemoteL10nSchema.entries.firstWhere((e) => e.value.isEmpty).key;

/// Like the real backend: manifest ETag follows the manifest body, language ETag is the file hash; If-None-Match => 304.
class EtagBackend {
  bool kill = false;
  bool offline = false;
  int version = 1;
  int manifestRevision = 1; // bump to change the manifest body (and so its ETag) without a new language version
  String text = 'remote';
  bool sendEtags = true;
  String? badEtag; // a malformed ETag header to send instead
  bool alwaysLanguage304 = false; // a misbehaving server
  bool always304 = false;
  final List<Uri> requests = [];
  final List<Map<String, String>> headers = [];

  String get manifestTag => '"m-$manifestRevision-$version-${kill ? 'k' : 'a'}"';
  String get languageTag => '"${hashOf(version)}"';

  Map<String, Object?> manifest() => {
        'schema': 1,
        'kill_switch': kill,
        'overrides_enabled': !kill,
        'languages': kill
            ? <Object?>[]
            : [
                {
                  'code': 'ar',
                  'name_en': 'Arabic',
                  'name_native': 'Arabic',
                  'direction': 'rtl',
                  'tracks': {
                    'app': {'version': version, 'hash': hashOf(version)},
                  },
                },
              ],
      };

  Map<String, Object?> language() => {
        'schema': 1,
        'lang': 'ar',
        'track': 'app',
        'version': version,
        'direction': 'rtl',
        'hash': hashOf(version),
        'strings': {aKey: text},
      };

  http.Response _ok(Object body, String tag) => http.Response.bytes(
      utf8.encode(jsonEncode(body)), 200, headers: {
        'content-type': 'application/json',
        if (sendEtags) 'etag': badEtag ?? tag,
      });

  http.Response _304(String tag) =>
      http.Response.bytes(<int>[], 304, headers: {'etag': tag});

  bool _matches(String? header, String tag) =>
      header != null &&
      header.split(',').map((e) => e.trim()).any((e) => e == tag || e == '*');

  MockClient get client => MockClient((req) async {
        requests.add(req.url);
        headers.add({
          for (final e in req.headers.entries) e.key.toLowerCase(): e.value
        });
        if (offline) throw http.ClientException('no route to host');
        final inm = req.headers['If-None-Match'];
        if (always304) return _304('"x"');
        if (req.url.path == '/translations/manifest') {
          return _matches(inm, manifestTag)
              ? _304(manifestTag)
              : _ok(manifest(), manifestTag);
        }
        if (req.url.path == '/translations/ar') {
          if (alwaysLanguage304) return _304(languageTag);
          return _matches(inm, languageTag)
              ? _304(languageTag)
              : _ok(language(), languageTag);
        }
        return http.Response('{}', 404);
      });

  Iterable<Map<String, String>> hdr(String path) => [
        for (var i = 0; i < requests.length; i++)
          if (requests[i].path == path) headers[i]
      ];
  int count(String path) => requests.where((u) => u.path == path).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EtagBackend be;
  late DateTime now;
  final services = <RemoteTranslationService>[];

  RemoteTranslationService make(String url, {EtagBackend? backend}) {
    final s = RemoteTranslationService(
      enabled: true,
      baseUrl: url,
      client: (backend ?? be).client,
      clock: () => now,
      currentLanguage: () => 'ar',
      requestTimeout: const Duration(seconds: 5),
      minAttemptGap: Duration.zero,
      minCheckInterval: Duration.zero,
      retryDelays: const [],
    );
    services.add(s);
    return s;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    be = EtagBackend();
    now = DateTime.utc(2026, 11, 22, 10);
    LocaleController.instance.resetForTest();
  });
  tearDown(() {
    for (final s in services) {
      s.dispose();
    }
    services.clear();
    LocaleController.instance.resetForTest();
  });

  test('isValidEtag accepts quoted tags (strong or weak) and nothing else', () {
    for (final ok in ['"abc"', 'W/"abc"', '"${hashOf(3)}"']) {
      expect(isValidEtag(ok), isTrue, reason: ok);
    }
    for (final bad in [
      null,
      '',
      'abc',
      '"',
      '""',
      '"a"b"',
      '"a\nb"',
      '"a b"',
      'W/abc',
      '"${'x' * 201}"',
      '"a", "b"'
    ]) {
      expect(isValidEtag(bad), isFalse, reason: '$bad');
    }
  });

  for (final url in [stagingUrl, productionUrl]) {
    final label = url == stagingUrl ? 'staging' : 'production';
    RemoteTranslationCache store() =>
        RemoteTranslationCache(environment: label);

    group('$label: ETag', () {
      test('200: first request is unconditional; ETags are stored per environment',
          () async {
        final s = make(url);
        expect(await s.refresh(), RemoteRefreshOutcome.updated);
        for (final h in be.headers) {
          expect(h.containsKey('if-none-match'), isFalse);
        }
        expect((await store().readManifest())!.etag, be.manifestTag);
        expect((await store().read('ar'))!.etag, be.languageTag);
        expect(s.overridesFor('ar').strings[aKey], 'remote');
      });

      test('304: unchanged check sends If-None-Match, downloads nothing, keeps text and ETag',
          () async {
        final s = make(url);
        await s.refresh();
        now = now.add(const Duration(hours: 1));
        expect(await s.refresh(), RemoteRefreshOutcome.unchanged);
        expect(be.hdr('/translations/manifest').last['if-none-match'],
            be.manifestTag);
        expect(be.count('/translations/ar'), 1,
            reason: 'no second language download');
        expect(s.overridesFor('ar').strings[aKey], 'remote');
        final c = (await store().read('ar'))!;
        expect(c.etag, be.languageTag, reason: 'ETag survives the cache refresh');
        expect(c.checkedAtMs, now.millisecondsSinceEpoch);
      });

      test('304 after an app restart: ETags come from persistent storage',
          () async {
        await make(url).refresh();
        final again = make(url);
        await again.init(); // loads the cached set
        expect(await again.refresh(), RemoteRefreshOutcome.unchanged);
        expect(be.hdr('/translations/manifest').last['if-none-match'],
            be.manifestTag);
        expect(be.count('/translations/ar'), 1);
        expect(again.overridesFor('ar').strings[aKey], 'remote');
      });

      test('304 on the language file reuses the stored copy when the in-app set had expired',
          () async {
        await make(url).refresh();
        now = now.add(const Duration(days: 30)); // cache too old to be loaded at start
        final s = make(url);
        await s.init();
        expect(s.overrides.isEmpty, isTrue);
        expect(await s.refresh(), RemoteRefreshOutcome.updated);
        expect(be.hdr('/translations/manifest').last['if-none-match'],
            be.manifestTag);
        expect(be.hdr('/translations/ar').last['if-none-match'],
            be.languageTag);
        expect(s.overridesFor('ar').strings[aKey], 'remote');
        expect(s.overrides.version, 1);
      });

      test('changed ETag: a new published version is downloaded and stored with its new ETag',
          () async {
        final s = make(url);
        await s.refresh();
        final oldLang = be.languageTag;
        be.version = 2;
        be.text = 'second';
        expect(await s.refresh(), RemoteRefreshOutcome.updated);
        expect(be.hdr('/translations/manifest').last['if-none-match'],
            isNotNull,
            reason: 'old manifest ETag was offered, server answered 200');
        expect(be.hdr('/translations/ar').last['if-none-match'], oldLang);
        expect(s.overrides.version, 2);
        expect(s.overridesFor('ar').strings[aKey], 'second');
        expect((await store().read('ar'))!.etag, be.languageTag);
        expect((await store().readManifest())!.etag, be.manifestTag);
        expect(be.languageTag, isNot(oldLang));
      });

      test('a changed manifest ETag with the same version/hash is judged by version/hash (no download)',
          () async {
        final s = make(url);
        await s.refresh();
        be.manifestRevision = 2; // manifest body differs, published set is the same
        expect(await s.refresh(), RemoteRefreshOutcome.unchanged);
        expect(be.count('/translations/ar'), 1);
        expect((await store().readManifest())!.etag, be.manifestTag);
      });

      test('kill switch through ETags: overrides and stored language ETag are removed; turning it off restores',
          () async {
        final s = make(url);
        await s.refresh();
        be.kill = true;
        expect(await s.refresh(), RemoteRefreshOutcome.killSwitch);
        expect(s.overridesFor('ar').isEmpty, isTrue);
        expect(await store().read('ar'), isNull);
        be.kill = false;
        expect(await s.refresh(), RemoteRefreshOutcome.updated);
        expect(be.hdr('/translations/ar').last.containsKey('if-none-match'),
            isFalse,
            reason: 'nothing stored, so the download is unconditional');
        expect(s.overridesFor('ar').strings[aKey], 'remote');
      });

      test('network failure with stored ETags: the stored text stays in use, nothing throws',
          () async {
        await make(url).refresh();
        final off = EtagBackend()..offline = true;
        final s = make(url, backend: off);
        await s.init();
        expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
        expect(s.overridesFor('ar').strings[aKey], 'remote');
        expect((await store().readManifest())!.etag, be.manifestTag,
            reason: 'a failure never damages the stored ETag');
      });

      test('network failure with nothing stored: bundled text, app unaffected',
          () async {
        be.offline = true;
        final s = make(url);
        await s.init();
        expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
        expect(s.overrides.isEmpty, isTrue);
      });

      test('a 304 the client did not ask for is a failure, not an answer',
          () async {
        be.always304 = true;
        final s = make(url);
        expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
        expect(s.overrides.isEmpty, isTrue);
      });

      test('a language 304 that contradicts the manifest (older stored version) is rejected',
          () async {
        final s = make(url);
        await s.refresh();
        be.version = 2;
        be.alwaysLanguage304 = true; // server wrongly says "not modified" for a newer version
        expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
        expect(s.overrides.version, 1);
        expect(s.overridesFor('ar').strings[aKey], 'remote');
      });

      test('a malformed ETag from the server is never stored or sent back',
          () async {
        be.badEtag = 'not-quoted';
        final s = make(url);
        expect(await s.refresh(), RemoteRefreshOutcome.updated);
        expect(await store().readManifest(), isNull);
        expect((await store().read('ar'))!.etag, isNull);
        await s.refresh();
        for (final h in be.headers) {
          expect(h.containsKey('if-none-match'), isFalse);
        }
      });

      test('a server that sends no ETag keeps working exactly as before',
          () async {
        be.sendEtags = false;
        final s = make(url);
        expect(await s.refresh(), RemoteRefreshOutcome.updated);
        expect(await s.refresh(), RemoteRefreshOutcome.unchanged);
        for (final h in be.headers) {
          expect(h.containsKey('if-none-match'), isFalse);
        }
      });

      test('corrupted stored manifest is ignored without a crash', () async {
        await make(url).refresh();
        final p = await SharedPreferences.getInstance();
        await p.setString(RemoteTranslationCache.manifestKey, '{not json');
        final s = make(url);
        await s.init();
        expect(await s.refresh(), RemoteRefreshOutcome.unchanged);
        expect(be.hdr('/translations/manifest').last.containsKey('if-none-match'),
            isFalse);
        expect((await store().readManifest())!.etag, be.manifestTag,
            reason: 'repaired by the 200 answer');
      });

      test('only Accept and If-None-Match are ever sent', () async {
        final s = make(url);
        await s.refresh();
        await s.refresh();
        for (final h in be.headers) {
          expect(h.keys.toSet().difference({'accept', 'if-none-match'}), isEmpty);
        }
      });
    });
  }

  group('no cross-environment ETag reuse', () {
    test('staging ETags are never offered to production, and the reverse',
        () async {
      await make(stagingUrl).refresh();
      final prodBackend = EtagBackend();
      final prod = make(productionUrl, backend: prodBackend);
      await prod.init();
      expect(prod.overrides.isEmpty, isTrue);
      await prod.refresh();
      for (final h in prodBackend.headers) {
        expect(h.containsKey('if-none-match'), isFalse,
            reason: 'production starts with no stored ETag');
      }
      // production data now owns the storage; staging must not use production's ETags
      final stagingBackend = EtagBackend();
      final st = make(stagingUrl, backend: stagingBackend);
      await st.init();
      expect(st.overrides.isEmpty, isTrue);
      await st.refresh();
      for (final h in stagingBackend.headers) {
        expect(h.containsKey('if-none-match'), isFalse);
      }
      expect(await RemoteTranslationCache(environment: 'staging').readManifest(),
          isNotNull);
      expect(
          await RemoteTranslationCache(environment: 'production').readManifest(),
          isNull,
          reason: 'storage is labelled by the environment that wrote it');
    });

    test('a manifest stored without an environment label is ignored', () async {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          RemoteTranslationCache.manifestKey,
          jsonEncode({
            'format': 1,
            'etag': be.manifestTag,
            'body': jsonEncode(be.manifest())
          }));
      final s = make(productionUrl);
      await s.refresh();
      expect(be.hdr('/translations/manifest').first.containsKey('if-none-match'),
          isFalse);
    });
  });
}
