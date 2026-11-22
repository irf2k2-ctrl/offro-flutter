// lib/core/l10n/remote/remote_translation_cache.dart
//
// Phase K: stores the last successfully fetched, already-validated published set in SharedPreferences (the storage the app already
// uses for the language choice). One key per language: `remote_l10n_cache_v1_<lang>`.
//
//   * Only validated data is ever passed to [write]; a failed or invalid refresh never reaches this class, so a good cache is never
//     overwritten by bad data. SharedPreferences replaces a single key atomically.
//   * [read] re-validates what it loads (the cache may come from an older app build with a different key set) and returns null
//     for anything unusable, so a corrupted cache simply means "bundled text".
//   * Nothing here throws.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'generated/remote_l10n_schema.dart';
import 'remote_translation_validator.dart';

class CachedTranslations {
  const CachedTranslations({
    required this.lang,
    required this.version,
    required this.hash,
    required this.strings,
    required this.checkedAtMs,
    this.etag,
  });
  final String lang;
  final int version;
  final String hash;
  final Map<String, String> strings;

  /// Epoch milliseconds when the backend last confirmed this version (set when fetched and refreshed on every unchanged check).
  final int checkedAtMs;

  /// The HTTP ETag the backend sent with this exact language file (null when it sent none). Used only for If-None-Match.
  final String? etag;

  CachedTranslations touched(int nowMs) => CachedTranslations(
      lang: lang,
      version: version,
      hash: hash,
      strings: strings,
      checkedAtMs: nowMs,
      etag: etag);
}

/// The last valid manifest body together with its ETag, so a 304 on the manifest can be answered from local storage.
class CachedManifest {
  const CachedManifest({required this.etag, required this.body});
  final String etag;
  final String body;
}

/// Only a well-formed entity tag (strong or weak, quoted, printable, short) is ever stored or sent back as If-None-Match.
final RegExp _etagShape = RegExp(r'^(?:W/)?"[\x21\x23-\x7E]{1,200}"$');
bool isValidEtag(String? v) => v != null && _etagShape.hasMatch(v);

class RemoteTranslationCache {
  /// [environment] ('staging' / 'production'), when given, is stored with the data and REQUIRED to match on read, so a cache written
  /// by a build for one environment is never used by a build for another (for example a staging APK installed over a production
  /// app shares the same storage). A cache without a matching environment is ignored and simply replaced by the next refresh.
  RemoteTranslationCache(
      {Future<SharedPreferences> Function()? prefs,
      Map<String, List<String>>? schema,
      String? environment})
      : _prefs = prefs ?? SharedPreferences.getInstance,
        _schema = schema ?? kRemoteL10nSchema,
        _environment = environment;

  final Future<SharedPreferences> Function() _prefs;
  final Map<String, List<String>> _schema;
  final String? _environment;

  static const int formatVersion = 1;
  static String keyFor(String lang) => 'remote_l10n_cache_v1_$lang';
  static const String manifestKey = 'remote_l10n_manifest_v1';

  Future<CachedTranslations?> read(String lang) async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(keyFor(lang));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['format'] != formatVersion) return null;
      if (_environment != null && decoded['environment'] != _environment) {
        return null;
      }
      final checkedAt = decoded['checked_at'];
      if (checkedAt is! int) return null;
      // Same rules as a fresh download (a new app build may know fewer keys); entries that no longer fit are dropped.
      final res = RemoteTranslationValidator.parseLanguageFile(
        <String, Object?>{
          'schema': 1,
          'lang': decoded['lang'],
          'track': 'app',
          'version': decoded['version'],
          'hash': decoded['hash'],
          'strings': decoded['strings'],
        },
        lang: lang,
        schema: _schema,
      );
      final p = res.payload;
      if (p == null) return null;
      final tag = decoded['etag'];
      return CachedTranslations(
          lang: lang,
          version: p.version,
          hash: p.hash,
          strings: p.strings,
          checkedAtMs: checkedAt,
          etag: tag is String && isValidEtag(tag) ? tag : null);
    } catch (_) {
      return null;
    }
  }

  /// Returns true when the data was stored. The caller passes only validated data.
  Future<bool> write(CachedTranslations c) async {
    try {
      final prefs = await _prefs();
      final body = jsonEncode(<String, Object?>{
        'format': formatVersion,
        'lang': c.lang,
        'version': c.version,
        'hash': c.hash,
        'strings': c.strings,
        'checked_at': c.checkedAtMs,
        if (isValidEtag(c.etag)) 'etag': c.etag,
        if (_environment != null) 'environment': _environment,
      });
      return await prefs.setString(keyFor(c.lang), body);
    } catch (_) {
      return false;
    }
  }

  Future<void> clear(String lang) async {
    try {
      final prefs = await _prefs();
      await prefs.remove(keyFor(lang));
    } catch (_) {/* nothing more to do */}
  }

  /// The stored manifest (body + ETag), or null when there is none, it was written by another environment, or it is unusable.
  Future<CachedManifest?> readManifest() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(manifestKey);
      if (raw == null) return null;
      final d = jsonDecode(raw);
      if (d is! Map || d['format'] != formatVersion) return null;
      if (_environment != null && d['environment'] != _environment) return null;
      final etag = d['etag'];
      final body = d['body'];
      if (etag is! String || !isValidEtag(etag) || body is! String) return null;
      return CachedManifest(etag: etag, body: body);
    } catch (_) {
      return null;
    }
  }

  /// Called only with a manifest that already passed validation and an ETag in a valid shape.
  Future<void> writeManifest(String etag, String body) async {
    try {
      if (!isValidEtag(etag)) return;
      final prefs = await _prefs();
      await prefs.setString(
          manifestKey,
          jsonEncode(<String, Object?>{
            'format': formatVersion,
            'etag': etag,
            'body': body,
            if (_environment != null) 'environment': _environment,
          }));
    } catch (_) {/* nothing more to do */}
  }

  Future<void> clearManifest() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(manifestKey);
    } catch (_) {/* nothing more to do */}
  }
}
