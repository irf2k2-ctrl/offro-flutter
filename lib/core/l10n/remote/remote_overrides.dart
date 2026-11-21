// lib/core/l10n/remote/remote_overrides.dart

import 'package:flutter/foundation.dart';

/// The only language that can receive remote translations in this phase (English is the bundled source and is never overridden).
const String kRemoteLanguage = 'ar';

/// The translation track the app uses (the legal track is not part of this phase).
const String kRemoteTrack = 'app';

/// An immutable, already-validated set of remote overrides for one language, plus the published version it came from.
@immutable
class RemoteOverrides {
  const RemoteOverrides(
      {required this.lang,
      required this.version,
      required this.hash,
      required this.strings});

  /// No overrides: the app shows the bundled text only.
  static const RemoteOverrides empty = RemoteOverrides(
      lang: '', version: 0, hash: '', strings: <String, String>{});

  final String lang;
  final int version;
  final String hash;

  /// key -> validated text. Never contains an empty value.
  final Map<String, String> strings;

  bool get isEmpty => strings.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is RemoteOverrides &&
      other.lang == lang &&
      other.version == version &&
      other.hash == hash;

  @override
  int get hashCode => Object.hash(lang, version, hash);
}
