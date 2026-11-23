// lib/core/l10n/remote/remote_translation_service.dart
//
// Phase K: fetches the PUBLISHED Arabic App translations from the backend and exposes them as an immutable override snapshot.
//
// Flow (one refresh):
//   1. GET /translations/manifest            -> kill switch? is Arabic published? which version/hash?
//   2. kill switch ON / overrides disabled   -> drop the cache and the overrides (bundled text only).
//   3. Arabic not in the manifest            -> drop the cache and the overrides (nothing published).
//   4. same version+hash as what we hold     -> only refresh the "last confirmed" time (no download).
//   5. otherwise GET /translations/ar?track=app, validate, write the cache, then switch the overrides in one step.
// Both requests are conditional (If-None-Match with the ETag stored for THIS environment); a 304 reuses the stored, validated copy.
// Any network / HTTP / format failure keeps whatever is currently in use (cache or bundled) and never reaches the UI.
//
// Traffic: nothing at all happens for English users or when the feature is off. Automatic triggers are throttled.
// Everything is a no-op unless [remoteTranslationsAllowed] (build flag + an exact allowlisted staging or production host). The
// service only ever requests paths on its own configured host, and re-checks the allowlist itself (not only the build flag).

import 'dart:async';
import 'dart:convert' show utf8;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../constants/app_constants.dart' show kBaseUrl;
import '../locale_controller.dart';
import 'generated/remote_l10n_schema.dart';
import 'remote_overrides.dart';
import 'remote_translation_cache.dart';
import 'remote_translation_config.dart';
import 'remote_translation_validator.dart';

enum RemoteRefreshReason { startup, languageSelected, resume, retry, manual }

enum RemoteRefreshOutcome {
  /// The feature is off in this build.
  disabled,

  /// Nothing to do (the app language is English, so no request is made).
  skippedNotNeeded,

  /// Too soon after the last request.
  skippedThrottled,

  /// Checked: the published version is the one already in use.
  unchanged,

  /// A new published version was downloaded, validated and switched in.
  updated,

  /// The backend has no published Arabic: overrides removed.
  notPublished,

  /// The backend kill switch is on: overrides removed.
  killSwitch,

  /// Network / HTTP / format problem: whatever was in use stays in use.
  failedKeptCurrent,
}

/// One HTTP answer: 200 with a body, or 304 (only ever returned when we sent If-None-Match).
class _Resp {
  const _Resp(this.status, this.bytes, this.etag);
  final int status;
  final List<int> bytes;
  final String? etag;
  bool get notModified => status == 304;
}

class _Fetched {
  const _Fetched(this.payload, this.etag);
  final RemotePayload payload;
  final String? etag;
}

class _Transient implements Exception {
  const _Transient(this.why);
  final String why;
}

class RemoteTranslationService extends ChangeNotifier
    with WidgetsBindingObserver {
  RemoteTranslationService({
    bool? enabled,
    String? baseUrl,
    http.Client? client,
    RemoteTranslationCache? cache,
    DateTime Function()? clock,
    String Function()? currentLanguage,
    Map<String, List<String>>? schema,
    this.requestTimeout = const Duration(seconds: 10),
    this.cacheMaxAge = const Duration(days: 14),
    this.minAttemptGap = const Duration(seconds: 20),
    this.minCheckInterval = const Duration(minutes: 5),
    this.retryDelays = const <Duration>[
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10)
    ],
  })  : _baseUrl = (baseUrl ?? kBaseUrl).trim().replaceAll(RegExp(r'/+$'), ''),
        enabled = (enabled ?? remoteTranslationsAllowed()) &&
            isRemoteTranslationsApiUrl(
                (baseUrl ?? kBaseUrl).trim().replaceAll(RegExp(r'/+$'), '')),
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        _cache = cache ??
            RemoteTranslationCache(
                schema: schema,
                environment: remoteTranslationEnvironmentOf(
                        (baseUrl ?? kBaseUrl).trim())
                    ?.name),
        _now = clock ?? DateTime.now,
        _currentLanguage = currentLanguage ??
            (() => LocaleController.instance.locale.languageCode),
        _schema = schema ?? kRemoteL10nSchema;

  /// The app-wide instance.
  static final RemoteTranslationService instance = RemoteTranslationService();

  /// False in every build made without ENABLE_REMOTE_TRANSLATIONS=true, and for any base URL that is not an allowlisted host.
  final bool enabled;

  final Duration requestTimeout;
  final Duration cacheMaxAge;
  final Duration minAttemptGap;
  final Duration minCheckInterval;
  final List<Duration> retryDelays;

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final RemoteTranslationCache _cache;
  final DateTime Function() _now;
  final String Function() _currentLanguage;
  final Map<String, List<String>> _schema;

  static const int _maxBodyBytes = 2 * 1024 * 1024;

  RemoteOverrides _overrides = RemoteOverrides.empty;
  Map<String, Set<String>> _languageCountries = const <String, Set<String>>{};
  DateTime? _lastCountriesAttempt;
  int _checkedAtMs = 0;
  DateTime? _lastAttempt;
  DateTime? _lastSuccess;
  Future<RemoteRefreshOutcome>? _inflight;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _initialised = false;
  bool _attached = false;
  String _lastLang = '';

  /// The overrides currently in use (empty when none).
  RemoteOverrides get overrides => _overrides;

  /// Where each language is offered (language code -> ISO country codes), from the last valid manifest. Empty when unknown, when
  /// remote translations are off, or while the kill switch is on; the language chooser then lists every bundled language.
  Map<String, Set<String>> get languageCountries => _languageCountries;

  void _setLanguageCountries(Map<String, Set<String>> next) {
    if (_sameMapping(_languageCountries, next)) return;
    _languageCountries = next;
    notifyListeners();
  }

  static bool _sameMapping(Map<String, Set<String>> a, Map<String, Set<String>> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null || o.length != e.value.length || !o.containsAll(e.value)) {
        return false;
      }
    }
    return true;
  }

  /// Reads only the stored (already validated) manifest, so the mapping is known offline. Never throws.
  Future<void> _loadCachedCountries() async {
    try {
      final stored = await _cache.readManifest();
      if (stored == null) return;
      final m = RemoteTranslationValidator.parseManifest(
          RemoteTranslationValidator.decodeBytes(utf8.encode(stored.body)));
      if (m != null && m.active) _setLanguageCountries(m.languageCountries);
    } catch (_) {/* no mapping: every bundled language is listed */}
  }

  /// Refreshes ONLY the language -> country mapping (one small manifest request; no language file). Used when the language chooser
  /// opens, because English users otherwise cause no traffic. Throttled, single-flight, never throws, a no-op when disabled.
  Future<void> refreshCountries() async {
    if (!enabled || _inflight != null) return;
    final now = _now();
    final last = _lastCountriesAttempt;
    if (last != null && now.difference(last) < minAttemptGap) return;
    _lastCountriesAttempt = now;
    try {
      await _fetchManifest();
    } catch (_) {/* keep the mapping we have */}
  }

  /// The overrides to use for [lang]: only the remote language ever gets any, English never does.
  RemoteOverrides overridesFor(String lang) =>
      enabled && lang == kRemoteLanguage ? _overrides : RemoteOverrides.empty;

  /// Loads the cached set (if fresh) so Arabic shows the last published text immediately, even offline. Never throws.
  Future<void> init() async {
    if (!enabled || _initialised) return;
    _initialised = true;
    await _loadCachedCountries();
    try {
      final c = await _cache.read(kRemoteLanguage);
      if (c == null) return;
      final age = _now().millisecondsSinceEpoch - c.checkedAtMs;
      if (age < 0 || age > cacheMaxAge.inMilliseconds)
        return; // expired (or from the future): bundled text until a refresh succeeds
      _checkedAtMs = c.checkedAtMs;
      _setOverrides(RemoteOverrides(
          lang: c.lang, version: c.version, hash: c.hash, strings: c.strings));
    } catch (_) {/* stay on bundled text */}
  }

  /// Starts listening for "Arabic selected" and "app resumed". Safe to call more than once; a no-op when disabled.
  void attach() {
    if (!enabled || _attached) return;
    _attached = true;
    _lastLang = _currentLanguage();
    LocaleController.instance.addListener(_onLocaleChanged);
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {/* no binding yet: resume refresh simply will not fire */}
  }

  void _onLocaleChanged() {
    final lang = _currentLanguage();
    final changed = lang != _lastLang;
    _lastLang = lang;
    if (changed && lang == kRemoteLanguage)
      unawaited(refresh(reason: RemoteRefreshReason.languageSelected));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      unawaited(refresh(reason: RemoteRefreshReason.resume));
  }

  /// Checks the backend and updates the overrides. Never throws, never shows anything to the user.
  Future<RemoteRefreshOutcome> refresh(
      {RemoteRefreshReason reason = RemoteRefreshReason.manual}) {
    if (!enabled)
      return Future<RemoteRefreshOutcome>.value(RemoteRefreshOutcome.disabled);
    final running = _inflight;
    if (running != null)
      return running; // single flight: concurrent triggers share one request
    final automatic = reason != RemoteRefreshReason.manual;
    if (automatic &&
        reason != RemoteRefreshReason.languageSelected &&
        _currentLanguage() != kRemoteLanguage) {
      return Future<RemoteRefreshOutcome>.value(RemoteRefreshOutcome
          .skippedNotNeeded); // English users cause no traffic
    }
    final now = _now();
    if (reason != RemoteRefreshReason.retry &&
        _lastAttempt != null &&
        now.difference(_lastAttempt!) < minAttemptGap) {
      return Future<RemoteRefreshOutcome>.value(
          RemoteRefreshOutcome.skippedThrottled);
    }
    if (reason == RemoteRefreshReason.resume &&
        _lastSuccess != null &&
        now.difference(_lastSuccess!) < minCheckInterval) {
      return Future<RemoteRefreshOutcome>.value(
          RemoteRefreshOutcome.skippedThrottled);
    }
    _lastAttempt = now;
    final f = _run().whenComplete(() => _inflight = null);
    _inflight = f;
    return f;
  }

  Future<RemoteRefreshOutcome> _run() async {
    try {
      final manifest = await _fetchManifest();
      if (!manifest.active) {
        await _dropAll();
        return _definitive(RemoteRefreshOutcome.killSwitch);
      }
      final entry = manifest.appTracks[kRemoteLanguage];
      if (entry == null) {
        await _dropAll();
        return _definitive(RemoteRefreshOutcome.notPublished);
      }
      final cur = _overrides;
      if (cur.lang == kRemoteLanguage &&
          cur.version == entry.version &&
          cur.hash == entry.hash) {
        await _confirm();
        return _definitive(RemoteRefreshOutcome.unchanged);
      }
      final fetched = await _fetchLanguage(entry);
      final payload = fetched?.payload;
      if (fetched == null || payload == null) {
        // The language file vanished between the two calls: kill switch or unpublish. Safest is bundled text.
        await _dropAll();
        return _definitive(RemoteRefreshOutcome.notPublished);
      }
      final now = _now().millisecondsSinceEpoch;
      await _cache.write(CachedTranslations(
        lang: payload.lang,
        version: payload.version,
        hash: payload.hash,
        strings: payload.strings,
        checkedAtMs: now,
        etag: fetched.etag,
      ));
      _checkedAtMs = now;
      _setOverrides(RemoteOverrides(
          lang: payload.lang,
          version: payload.version,
          hash: payload.hash,
          strings: payload.strings));
      return _definitive(RemoteRefreshOutcome.updated);
    } on _Transient catch (e) {
      _log('refresh failed: ${e.why}');
      if (e.why != 'invalid_data')
        _scheduleRetry(); // bad data will not fix itself in seconds; the next resume tries again
      return RemoteRefreshOutcome.failedKeptCurrent;
    } catch (_) {
      _log('refresh failed: unexpected');
      _scheduleRetry();
      return RemoteRefreshOutcome.failedKeptCurrent;
    }
  }

  RemoteRefreshOutcome _definitive(RemoteRefreshOutcome o) {
    _lastSuccess = _now();
    _retryAttempt = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
    return o;
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _retryAttempt >= retryDelays.length) return;
    final delay = retryDelays[_retryAttempt++];
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(refresh(reason: RemoteRefreshReason.retry));
    });
  }

  // ── network ────────────────────────────────────────────────────────────────────────────────────────────────────────
  /// [ifNoneMatch] is sent only when it is a well-formed ETag we stored ourselves. A 304 is accepted only in that case.
  Future<_Resp?> _get(String path,
      {String? ifNoneMatch, bool notFoundIsNull = false}) async {
    final sendTag = isValidEtag(ifNoneMatch);
    final http.Response r;
    try {
      r = await _client.get(Uri.parse('$_baseUrl$path'), headers: {
        'Accept': 'application/json',
        if (sendTag) 'If-None-Match': ifNoneMatch!,
      }).timeout(requestTimeout);
    } on TimeoutException {
      throw const _Transient('timeout');
    } catch (_) {
      throw const _Transient('network'); // no internet, DNS, TLS, bad URL...
    }
    if (r.statusCode == 404 && notFoundIsNull) return null;
    if (r.statusCode == 304) {
      if (!sendTag) throw const _Transient('http_304');
      return const _Resp(304, <int>[], null);
    }
    if (r.statusCode != 200)
      throw _Transient(
          'http_${r.statusCode}'); // includes 429 and 5xx: keep what we have
    if (r.bodyBytes.length > _maxBodyBytes)
      throw const _Transient('invalid_data');
    final tag = r.headers['etag']?.trim();
    return _Resp(200, r.bodyBytes, isValidEtag(tag) ? tag : null);
  }

  /// Conditional request: the stored manifest ETag is sent as If-None-Match; on 304 the stored (previously validated) body is used.
  /// The manifest is then judged exactly as before (kill switch, published?, version + hash).
  Future<RemoteManifest> _fetchManifest() async {
    final stored = await _cache.readManifest();
    final res = (await _get('/translations/manifest', ifNoneMatch: stored?.etag))!;
    final List<int> bytes = res.notModified && stored != null
        ? utf8.encode(stored.body)
        : res.bytes;
    final m = RemoteTranslationValidator.parseManifest(
        RemoteTranslationValidator.decodeBytes(bytes));
    if (m == null) {
      await _cache.clearManifest(); // never keep a tag whose body we cannot use
      throw const _Transient('invalid_data');
    }
    _setLanguageCountries(m.active ? m.languageCountries : const <String, Set<String>>{});
    if (!res.notModified) {
      if (res.etag != null) {
        await _cache.writeManifest(
            res.etag!, utf8.decode(bytes, allowMalformed: true));
      } else {
        await _cache.clearManifest();
      }
    }
    return m;
  }

  /// Null when the backend answers 404 (not available). Sends the stored language ETag; on 304 the stored (re-validated) set is used,
  /// but only if it still agrees with the manifest (version never older, same hash for the same version).
  Future<_Fetched?> _fetchLanguage(ManifestEntry entry) async {
    final stored = await _cache.read(kRemoteLanguage);
    final res = await _get('/translations/$kRemoteLanguage?track=$kRemoteTrack',
        ifNoneMatch: stored?.etag, notFoundIsNull: true);
    if (res == null) return null;
    if (res.notModified) {
      if (stored == null) throw const _Transient('invalid_data');
      if (stored.version < entry.version ||
          (stored.version == entry.version && stored.hash != entry.hash)) {
        throw const _Transient('invalid_data');
      }
      return _Fetched(
          RemotePayload(
              lang: stored.lang,
              version: stored.version,
              hash: stored.hash,
              strings: stored.strings,
              rejected: 0),
          stored.etag);
    }
    final res2 = RemoteTranslationValidator.parseLanguageFile(
      RemoteTranslationValidator.decodeBytes(res.bytes),
      lang: kRemoteLanguage,
      schema: _schema,
      minVersion: entry.version,
    );
    final p = res2.payload;
    if (p == null)
      throw _Transient(
          res2.error == 'stale_version' ? 'stale' : 'invalid_data');
    if (p.version == entry.version && p.hash != entry.hash)
      throw const _Transient('invalid_data'); // inconsistent with the manifest
    return _Fetched(p, res.etag);
  }

  // ── state ──────────────────────────────────────────────────────────────────────────────────────────────────────────
  Future<void> _confirm() async {
    final now = _now().millisecondsSinceEpoch;
    _checkedAtMs = now;
    // Keep the ETag stored with this exact version (only when the stored set is the one in use).
    final stored = await _cache.read(kRemoteLanguage);
    final same = stored != null &&
        stored.version == _overrides.version &&
        stored.hash == _overrides.hash;
    await _cache.write(CachedTranslations(
      lang: _overrides.lang,
      version: _overrides.version,
      hash: _overrides.hash,
      strings: _overrides.strings,
      checkedAtMs: now,
      etag: same ? stored.etag : null,
    ));
  }

  Future<void> _dropAll() async {
    await _cache.clear(kRemoteLanguage);
    _checkedAtMs = 0;
    _setOverrides(RemoteOverrides.empty);
  }

  void _setOverrides(RemoteOverrides next) {
    if (next == _overrides) return;
    _overrides = next;
    notifyListeners(); // MaterialApp rebuilds and the localization delegate reloads in one step
  }

  void _log(String m) {
    if (kDebugMode) debugPrint('[remote-l10n] $m');
  }

  @visibleForTesting
  int get checkedAtMsForTest => _checkedAtMs;

  @override
  void dispose() {
    _retryTimer?.cancel();
    if (_attached) {
      LocaleController.instance.removeListener(_onLocaleChanged);
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
    }
    if (_ownsClient) _client.close();
    super.dispose();
  }
}
