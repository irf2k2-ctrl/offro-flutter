// Stage 5/6: remote translations for STAGING and PRODUCTION builds: exact host allowlist, no cross-environment requests, per-environment
// cache isolation, bundled fallback, kill switch, version/hash changes, and no regression in OTP / login / registration code.
// Uses a fake backend (no real network) and mock SharedPreferences (no real storage).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/l10n/locale_controller.dart';
import 'package:offro_user/core/l10n/remote/generated/remote_l10n_schema.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_cache.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_config.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_service.dart';
import 'package:offro_user/core/services/staging_gate.dart';

const String stagingUrl = 'https://offro-backend-staging-d375.up.railway.app';
const String productionUrl = 'https://offro-backend-production.up.railway.app';

String hashOf(int n) => n.toRadixString(16).padLeft(64, '0');
String get aKey => kRemoteL10nSchema.entries
    .firstWhere((e) => e.value.isEmpty)
    .key; // a key without placeholders

/// A scriptable backend that records every request (host, path, query, headers).
class Fake {
  bool kill = false;
  bool offline = false;
  int status = 200;
  int version = 1;
  String text = 'remote';
  final List<Uri> requests = [];
  final List<Map<String, String>> headers = [];

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
                    // a legal track exists on the server; the app must never ask for it
                    'legal': {'version': 1, 'hash': hashOf(99)},
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

  http.Response _json(Object body, [int s = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)), s,
      headers: {'content-type': 'application/json'});

  MockClient get client => MockClient((req) async {
        requests.add(req.url);
        headers.add(Map.of(req.headers));
        if (offline) throw http.ClientException('no route to host');
        if (status != 200) return _json({'detail': 'x'}, status);
        if (req.url.path == '/translations/manifest') return _json(manifest());
        if (req.url.path == '/translations/ar') return _json(language());
        return _json({'detail': 'not_found'}, 404);
      });

  int get languageCalls =>
      requests.where((u) => u.path == '/translations/ar').length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Fake be;
  late DateTime now;
  final services = <RemoteTranslationService>[];

  RemoteTranslationService make(String url,
      {bool enabled = true, Fake? backend}) {
    final s = RemoteTranslationService(
      enabled: enabled,
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
    be = Fake();
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

  group('exact HTTPS host allowlist', () {
    test('the two known hosts are pinned (changing either must be deliberate)',
        () {
      expect(kRemoteStagingHost, 'offro-backend-staging-d375.up.railway.app');
      expect(kRemoteStagingHost, kStagingApiHost);
      expect(kRemoteProductionHost, 'offro-backend-production.up.railway.app');
      expect(kRemoteStagingHost, isNot(kRemoteProductionHost));
    });
    test('staging and production are recognised, with or without a slash/443',
        () {
      for (final u in [
        stagingUrl,
        '$stagingUrl/',
        '$stagingUrl:443',
        '  $stagingUrl  '
      ]) {
        expect(remoteTranslationEnvironmentOf(u),
            RemoteTranslationEnvironment.staging,
            reason: u);
      }
      for (final u in [
        productionUrl,
        '$productionUrl/',
        '$productionUrl:443'
      ]) {
        expect(remoteTranslationEnvironmentOf(u),
            RemoteTranslationEnvironment.production,
            reason: u);
      }
    });
    test('everything else is refused', () {
      for (final u in [
        '',
        '   ',
        'not a url',
        'http://offro-backend-production.up.railway.app',
        'http://offro-backend-staging-d375.up.railway.app',
        'ftp://offro-backend-production.up.railway.app',
        'https://offro-backend-production.up.railway.app.evil.example',
        'https://evil.example/offro-backend-production.up.railway.app',
        'https://evil.example?h=offro-backend-production.up.railway.app',
        'https://offro-backend-production.up.railway.app@evil.example',
        'https://user:pw@offro-backend-production.up.railway.app',
        'https://offro-backend-production.up.railway.app:8443',
        'https://offro-backend-production.up.railway.app.',
        'https://api.offro-backend-production.up.railway.app',
        'https://xoffro-backend-production.up.railway.app',
        'https://OFFRO-BACKEND-PRODUCTION.up.railway.app.evil.example',
        'https://offro-backend-production.up.railway.app?x=1',
        'https://offro-backend-production.up.railway.app#x',
        'https://localhost',
        'https://10.0.0.1',
        'https://offro-backend-staging-d375.up.railway.app.evil.example',
        'https://offro-backend-staging.up.railway.app',
      ]) {
        expect(isRemoteTranslationsApiUrl(u), isFalse, reason: u);
      }
    });
    test('the flag is OFF by default and both conditions are required', () {
      expect(kEnableRemoteTranslations, isFalse);
      expect(remoteTranslationsAllowed(), isFalse);
      for (final u in [stagingUrl, productionUrl]) {
        expect(remoteTranslationsAllowed(flag: false, baseUrl: u), isFalse);
        expect(remoteTranslationsAllowed(flag: true, baseUrl: u), isTrue);
      }
      expect(remoteTranslationsAllowed(flag: true, baseUrl: ''), isFalse);
      expect(RemoteTranslationService.instance.enabled, isFalse);
    });
  });

  group('the service enforces the allowlist itself', () {
    test('enabled=true with a host that is not allowlisted does nothing',
        () async {
      for (final u in [
        'https://evil.example',
        'http://offro-backend-production.up.railway.app',
        '',
        '$productionUrl:8443'
      ]) {
        final s = make(u);
        expect(s.enabled, isFalse, reason: u);
        await s.init();
        s.attach();
        expect(await s.refresh(), RemoteRefreshOutcome.disabled, reason: u);
      }
      expect(be.requests, isEmpty);
    });
    test('enabled=false on an allowlisted host does nothing', () async {
      for (final u in [stagingUrl, productionUrl]) {
        final s = make(u, enabled: false);
        expect(await s.refresh(), RemoteRefreshOutcome.disabled);
      }
      expect(be.requests, isEmpty);
    });
  });

  group('no cross-environment requests', () {
    test('a staging build talks only to the staging host', () async {
      final s = make(stagingUrl);
      await s.refresh();
      be.version = 2;
      await s.refresh();
      expect(be.requests, isNotEmpty);
      expect(be.requests.map((u) => u.scheme).toSet(), {'https'});
      expect(be.requests.map((u) => u.host).toSet(), {kRemoteStagingHost});
    });
    test('a production build talks only to the production host', () async {
      final s = make(productionUrl);
      await s.refresh();
      be.version = 2;
      await s.refresh();
      expect(be.requests, isNotEmpty);
      expect(be.requests.map((u) => u.scheme).toSet(), {'https'});
      expect(be.requests.map((u) => u.host).toSet(), {kRemoteProductionHost});
    });
    test('only the two public translation paths, only the app track, no extras',
        () async {
      final s = make(productionUrl);
      await s.refresh();
      expect(be.requests.map((u) => u.path).toSet(),
          {'/translations/manifest', '/translations/ar'});
      for (final u in be.requests.where((u) => u.path == '/translations/ar')) {
        expect(u.queryParameters, {'track': 'app'},
            reason: 'the legal track is never requested');
      }
      expect(be.requests.any((u) => u.toString().contains('legal')), isFalse);
      for (final h in be.headers) {
        expect(
            h.keys.map((k) => k.toLowerCase()).toSet().difference(
                {'accept', 'if-none-match'}),
            isEmpty,
            reason:
                'no credentials, cookies or tokens are sent with translation requests');
      }
    });
    test('a cache written by one environment is never used by the other',
        () async {
      final st = make(stagingUrl);
      await st.refresh();
      expect(st.overridesFor('ar').strings[aKey], 'remote');
      // a production build installed over the same storage
      final offlineProd = Fake()..offline = true;
      final pr = make(productionUrl, backend: offlineProd);
      await pr.init();
      expect(pr.overrides.isEmpty, isTrue,
          reason: 'staging cache must not be applied by a production build');
      expect(offlineProd.requests, isEmpty);
      // and the other way round
      SharedPreferences.setMockInitialValues({});
      final p2 = make(productionUrl);
      await p2.refresh();
      final offlineStaging = Fake()..offline = true;
      final s2 = make(stagingUrl, backend: offlineStaging);
      await s2.init();
      expect(s2.overrides.isEmpty, isTrue);
    });
    test('a cache without an environment label is ignored by an allowlisted build',
        () async {
      await RemoteTranslationCache().write(CachedTranslations(
          lang: 'ar',
          version: 5,
          hash: hashOf(5),
          strings: {aKey: 'unlabelled'},
          checkedAtMs: now.millisecondsSinceEpoch));
      final s = make(productionUrl);
      await s.init();
      expect(s.overrides.isEmpty, isTrue);
    });
    test('the same environment reuses its own cache', () async {
      await make(productionUrl).refresh();
      final off = Fake()..offline = true;
      final again = make(productionUrl, backend: off);
      await again.init();
      expect(again.overridesFor('ar').strings[aKey], 'remote');
      expect(off.requests, isEmpty);
    });
  });

  for (final url in [stagingUrl, productionUrl]) {
    final label = url == stagingUrl ? 'staging' : 'production';
    group('$label build behaviour', () {
      test('downloads, validates, caches and applies the published Arabic',
          () async {
        final s = make(url);
        expect(await s.refresh(), RemoteRefreshOutcome.updated);
        expect(s.overridesFor('ar').strings[aKey], 'remote');
        expect(s.overridesFor('en').isEmpty, isTrue);
        final c =
            await RemoteTranslationCache(environment: label).read('ar');
        expect(c!.version, 1);
        expect(c.hash, hashOf(1));
      });
      test('bundled fallback: offline with nothing cached does not throw',
          () async {
        be.offline = true;
        final s = make(url);
        await s.init();
        s.attach();
        expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
        expect(s.overrides.isEmpty, isTrue);
      });
      test('bundled fallback: HTTP errors never clear a working set',
          () async {
        final s = make(url);
        await s.refresh();
        for (final code in [404, 429, 500, 503]) {
          be.status = code;
          expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent,
              reason: '$code');
          expect(s.overridesFor('ar').strings[aKey], 'remote');
        }
      });
      test('offline with a fresh cache still shows the last published text',
          () async {
        await make(url).refresh();
        final off = Fake()..offline = true;
        final s = make(url, backend: off);
        await s.init();
        expect(s.overridesFor('ar').strings[aKey], 'remote');
        expect(await s.refresh(), RemoteRefreshOutcome.failedKeptCurrent);
        expect(s.overridesFor('ar').strings[aKey], 'remote');
      });
      test('version/hash: unchanged does not download; a new version does',
          () async {
        final s = make(url);
        await s.refresh();
        expect(be.languageCalls, 1);
        expect(await s.refresh(), RemoteRefreshOutcome.unchanged);
        expect(be.languageCalls, 1, reason: 'same version and hash');
        be.version = 2;
        be.text = 'second';
        expect(await s.refresh(), RemoteRefreshOutcome.updated);
        expect(s.overrides.version, 2);
        expect(s.overrides.hash, hashOf(2));
        expect(s.overridesFor('ar').strings[aKey], 'second');
        expect(be.languageCalls, 2);
      });
      test('kill switch removes overrides and cache; turning it off restores',
          () async {
        final s = make(url);
        await s.refresh();
        be.kill = true;
        expect(await s.refresh(), RemoteRefreshOutcome.killSwitch);
        expect(s.overridesFor('ar').isEmpty, isTrue);
        expect(await RemoteTranslationCache(environment: label).read('ar'),
            isNull);
        be.kill = false;
        expect(await s.refresh(), RemoteRefreshOutcome.updated);
        expect(s.overridesFor('ar').strings[aKey], 'remote');
      });
    });
  }

  group('no regression: OTP, login, registration and unrelated code', () {
    test('the master OTP rule is unchanged: staging only, never production',
        () {
      expect(isStagingApiUrl(stagingUrl), isTrue);
      expect(isStagingApiUrl(productionUrl), isFalse);
      expect(isMasterOtp('1234', baseUrl: stagingUrl), isTrue);
      expect(isMasterOtp('1234', baseUrl: productionUrl), isFalse);
      expect(isMasterOtp('0000', baseUrl: stagingUrl), isFalse);
      expect(kStagingApiHost, 'offro-backend-staging-d375.up.railway.app');
      expect(kMasterOtp, '1234');
    });
    test('staging_gate.dart still contains the original isStagingApiUrl logic',
        () {
      final src = File('lib/core/services/staging_gate.dart').readAsStringSync();
      for (final line in [
        "return u.scheme == 'https' &&",
        'u.host == kStagingApiHost &&',
        'u.userInfo.isEmpty &&',
        '(!u.hasPort || u.port == 443);',
        'bool isMasterOtp(String otp, {String baseUrl = kBaseUrl}) => otp == kMasterOtp && isStagingApiUrl(baseUrl);',
      ]) {
        expect(src.contains(line), isTrue, reason: line);
      }
      expect(src.contains('remote'), isFalse,
          reason: 'the master OTP gate does not know about translations');
    });
    test(
        'OTP, login, registration, role-selection and networking code do not use the remote translation layer',
        () {
      final roots = [
        'lib/screens/auth',
        'lib/core/services',
        'lib/core/constants',
      ];
      for (final r in roots) {
        final d = Directory(r);
        if (!d.existsSync()) continue;
        for (final f in d.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          final text = f.readAsStringSync();
          expect(text.contains('l10n/remote/'), isFalse, reason: f.path);
          expect(text.contains('RemoteTranslationService'), isFalse,
              reason: f.path);
        }
      }
    });
    test('the remote layer never imports the app\'s auth or API services', () {
      for (final f in Directory('lib/core/l10n/remote')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final text = f.readAsStringSync();
        expect(text.contains('api_service.dart'), isFalse, reason: f.path);
        expect(text.contains('staging_gate.dart') &&
                !f.path.endsWith('remote_translation_config.dart'),
            isFalse,
            reason: f.path);
        expect(text.contains('isMasterOtp'), isFalse, reason: f.path);
      }
    });
    test('the legal track is not enabled in the app', () {
      final text = [
        'lib/core/l10n/remote/remote_translation_service.dart',
        'lib/core/l10n/remote/remote_translation_config.dart'
      ].map((p) => File(p).readAsStringSync()).join('\n');
      expect(text.contains('track=app') || text.contains("'app'"), isTrue);
      expect(RegExp(r"track=legal|'legal'").hasMatch(text), isFalse);
    });
  });

  group('build configuration (iOS and Android) carries the remote translation flag', () {
    const flag = '--dart-define=ENABLE_REMOTE_TRANSLATIONS=true';
    const stagingApi = '--dart-define=API_BASE_URL=https://offro-backend-staging-d375.up.railway.app';

    test('Codemagic iOS workflow: flag present, still the staging API host only', () {
      final y = File('codemagic.yaml').readAsStringSync();
      final build = y.substring(y.indexOf('flutter build ipa'), y.indexOf('artifacts:'));
      expect(build.contains(flag), isTrue);
      expect(build.contains(stagingApi), isTrue);
      expect(RegExp(r'API_BASE_URL=').allMatches(y).length, 1, reason: 'no other host was added');
      expect(y.contains('production'), isFalse);
    });

    test('Android staging script: flag present with the staging API host', () {
      final c = File('tools/build_staging_apk.cmd').readAsStringSync();
      expect(c.contains(flag), isTrue);
      expect(c.contains(stagingApi), isTrue);
    });

    test('Android production script keeps its flag and the staging host never appears there', () {
      final c = File('tools/build_production_apk.cmd').readAsStringSync();
      expect(c.contains(flag), isTrue);
      expect(c.contains('offro-backend-staging'), isFalse);
    });

    test('the flag alone does nothing: an exact allowlisted host is still required', () {
      expect(remoteTranslationsAllowed(flag: true, baseUrl: 'https://example.com'), isFalse);
      expect(remoteTranslationsAllowed(flag: false, baseUrl: stagingUrl), isFalse);
      expect(remoteTranslationsAllowed(flag: true, baseUrl: stagingUrl), isTrue);
    });
  });
}
