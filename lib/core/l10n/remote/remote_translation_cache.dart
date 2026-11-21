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
  });
  final String lang;
  final int version;
  final String hash;
  final Map<String, String> strings;

  /// Epoch milliseconds when the backend last confirmed this version (set when fetched and refreshed on every unchanged check).
  final int checkedAtMs;

  CachedTranslations touched(int nowMs) => CachedTranslations(
      lang: lang,
      version: version,
      hash: hash,
      strings: strings,
      checkedAtMs: nowMs);
}

class RemoteTranslationCache {
  RemoteTranslationCache(
      {Future<SharedPreferences> Function()? prefs,
      Map<String, List<String>>? schema})
      : _prefs = prefs ?? SharedPreferences.getInstance,
        _schema = schema ?? kRemoteL10nSchema;

  final Future<SharedPreferences> Function() _prefs;
  final Map<String, List<String>> _schema;

  static const int formatVersion = 1;
  static String keyFor(String lang) => 'remote_l10n_cache_v1_$lang';

  Future<CachedTranslations?> read(String lang) async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(keyFor(lang));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['format'] != formatVersion) return null;
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
      return CachedTranslations(
          lang: lang,
          version: p.version,
          hash: p.hash,
          strings: p.strings,
          checkedAtMs: checkedAt);
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
}
