// lib/core/l10n/remote/remote_translation_validator.dart
//
// Phase K: decides whether remote data may be used. Pure Dart (no network, no storage) so every rule is unit-tested.
// Mirrors the backend's value rules (services/translations.py validate_value) as a second line of defence: the backend already
// refuses bad values, but the app never trusts the network.
//
// Policy
//   * Structural problems (not JSON, wrong schema/lang/track/direction, bad version/hash, `strings` not a map) reject the WHOLE file.
//   * A single bad entry (unknown key, empty, wrong placeholders, hidden characters, HTML...) is skipped and the bundled text is
//     used for that key. If more than [maxRejectedRatio] of the entries are bad the whole file is rejected as incompatible.
//   * Nothing here throws: every failure is a null result or a skipped entry.

import 'dart:convert';

import 'remote_overrides.dart';

/// Result of checking a language file. Exactly one of [payload] / [error] is set.
class RemotePayloadResult {
  const RemotePayloadResult.ok(this.payload) : error = null;
  const RemotePayloadResult.fail(this.error) : payload = null;
  final RemotePayload? payload;
  final String? error;
}

class RemotePayload {
  const RemotePayload(
      {required this.lang,
      required this.version,
      required this.hash,
      required this.strings,
      required this.rejected});
  final String lang;
  final int version;
  final String hash;
  final Map<String, String> strings;

  /// Entries that were skipped (unknown key or unusable value).
  final int rejected;
}

/// One language's published version, as announced by the manifest.
class ManifestEntry {
  const ManifestEntry({required this.version, required this.hash});
  final int version;
  final String hash;
}

class RemoteManifest {
  const RemoteManifest(
      {required this.killSwitch,
      required this.overridesEnabled,
      required this.appTracks});
  final bool killSwitch;
  final bool overridesEnabled;

  /// language code -> published App-track version. Only languages that have a published App track are listed.
  final Map<String, ManifestEntry> appTracks;

  /// Remote text may be used only while the backend says so.
  bool get active => !killSwitch && overridesEnabled;
}

class RemoteTranslationValidator {
  RemoteTranslationValidator._();

  static const int maxValueLength = 2000; // the backend's absolute limit
  static const double maxRejectedRatio = 0.25;
  static const int maxEntries = 5000;

  static final RegExp _langRe = RegExp(r'^[a-z]{2,3}$');
  static final RegExp _keyRe = RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,99}$');
  static final RegExp _hashRe = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _placeholderRe = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');
  static final RegExp _tagRe = RegExp(r'<\s*/?\s*[A-Za-z!?]');
  static final RegExp _entityRe =
      RegExp(r'&(?:[A-Za-z]{2,8}|#\d{1,7}|#[xX][0-9A-Fa-f]{1,6});');

  // Zero-width / bidi format characters that are legitimate in Arabic text (ZWNJ, ZWJ, LRM, RLM, ALM).
  static const Set<int> _allowedFormat = {
    0x200C,
    0x200D,
    0x200E,
    0x200F,
    0x061C
  };

  static bool isValidLanguageCode(String code) => _langRe.hasMatch(code);
  static bool isValidKey(String key) => _keyRe.hasMatch(key);
  static bool isValidHash(String hash) => _hashRe.hasMatch(hash);

  /// Placeholder names used in [text], or null when braces are malformed (a stray `{` or `}`).
  static Set<String>? placeholdersOf(String text) {
    final rest = text.replaceAll(_placeholderRe, '');
    if (rest.contains('{') || rest.contains('}')) return null;
    return _placeholderRe.allMatches(text).map((m) => m.group(1)!).toSet();
  }

  static bool _isForbiddenCodePoint(int c) {
    if (c < 0x20) return c != 0x0A; // control characters (a newline is allowed)
    if (c >= 0x7F && c <= 0x9F) return true;
    if (c == 0x00AD || c == 0x2028 || c == 0x2029 || c == 0xFEFF) return true;
    if (c >= 0x200B && c <= 0x200F)
      return !_allowedFormat
          .contains(c); // ZWSP forbidden; ZWNJ, ZWJ, LRM, RLM allowed
    if (c >= 0x202A && c <= 0x202E) return true; // bidi embeddings / overrides
    if (c >= 0x2060 && c <= 0x206F)
      return true; // word joiner, invisible operators, bidi isolates
    if (c >= 0xFFF9 && c <= 0xFFFB) return true;
    if (c >= 0xD800 && c <= 0xDFFF) return true; // lone surrogate
    return false;
  }

  /// The usable text for [key], or null when the value must not be used. [schema] maps every bundled key to its placeholders.
  static String? checkValue(
      String key, Object? value, Map<String, List<String>> schema) {
    if (value is! String) return null;
    final expected = schema[key];
    if (expected == null || !isValidKey(key))
      return null; // not a key of this app version
    final v = value.trim();
    if (v.isEmpty || v.length > maxValueLength)
      return null; // never replace a valid bundled text with nothing
    for (final c in v.runes) {
      if (_isForbiddenCodePoint(c)) return null;
    }
    if (_tagRe.hasMatch(v) || _entityRe.hasMatch(v)) return null;
    final found = placeholdersOf(v);
    if (found == null) return null;
    if (found.length != expected.length || !found.containsAll(expected))
      return null;
    return v;
  }

  /// Checks a decoded language file. [minVersion] rejects a file older than the manifest's version (a stale cached response).
  static RemotePayloadResult parseLanguageFile(
    Object? decoded, {
    required String lang,
    required Map<String, List<String>> schema,
    int minVersion = 1,
  }) {
    if (!isValidLanguageCode(lang) || lang == 'en')
      return const RemotePayloadResult.fail('language_not_allowed');
    if (decoded is! Map) return const RemotePayloadResult.fail('not_an_object');
    if (decoded['schema'] != 1)
      return const RemotePayloadResult.fail('unsupported_schema');
    if (decoded['lang'] != lang)
      return const RemotePayloadResult.fail('language_mismatch');
    if (decoded['track'] != kRemoteTrack)
      return const RemotePayloadResult.fail('track_mismatch');
    final version = decoded['version'];
    if (version is! int || version < 1)
      return const RemotePayloadResult.fail('bad_version');
    if (version < minVersion)
      return const RemotePayloadResult.fail('stale_version');
    final hash = decoded['hash'];
    if (hash is! String || !isValidHash(hash))
      return const RemotePayloadResult.fail('bad_hash');
    final direction = decoded['direction'];
    if (direction != null && lang == 'ar' && direction != 'rtl') {
      return const RemotePayloadResult.fail('direction_mismatch');
    }
    final raw = decoded['strings'];
    if (raw is! Map)
      return const RemotePayloadResult.fail('strings_not_an_object');
    if (raw.length > maxEntries)
      return const RemotePayloadResult.fail('too_many_entries');

    final accepted = <String, String>{};
    var rejected = 0;
    for (final e in raw.entries) {
      final k = e.key;
      final text = k is String ? checkValue(k, e.value, schema) : null;
      if (text == null) {
        rejected++;
      } else {
        accepted[k as String] = text;
      }
    }
    if (raw.isNotEmpty && rejected / raw.length > maxRejectedRatio)
      return const RemotePayloadResult.fail('too_many_invalid_entries');
    return RemotePayloadResult.ok(RemotePayload(
      lang: lang,
      version: version,
      hash: hash,
      strings: Map<String, String>.unmodifiable(accepted),
      rejected: rejected,
    ));
  }

  /// Parses the manifest. Null when it is not a well-formed manifest (the caller then keeps what it has).
  static RemoteManifest? parseManifest(Object? decoded) {
    if (decoded is! Map || decoded['schema'] != 1) return null;
    final kill = decoded['kill_switch'];
    final enabled = decoded['overrides_enabled'];
    final langs = decoded['languages'];
    if (kill is! bool || enabled is! bool || langs is! List) return null;
    final tracks = <String, ManifestEntry>{};
    for (final l in langs) {
      if (l is! Map) continue;
      final code = l['code'];
      final t = l['tracks'];
      if (code is! String || !isValidLanguageCode(code) || t is! Map) continue;
      final app = t[kRemoteTrack];
      if (app is! Map) continue;
      final v = app['version'];
      final h = app['hash'];
      if (v is int && v >= 1 && h is String && isValidHash(h))
        tracks[code] = ManifestEntry(version: v, hash: h);
    }
    return RemoteManifest(
        killSwitch: kill,
        overridesEnabled: enabled,
        appTracks: Map<String, ManifestEntry>.unmodifiable(tracks));
  }

  /// Decodes UTF-8 JSON bytes (never `latin1`, so Arabic survives). Null on any problem.
  static Object? decodeBytes(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }
}
