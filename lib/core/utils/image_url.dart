// lib/core/utils/image_url.dart
//
// Shared image-URL resolver. The backend returns images as absolute http(s)
// URLs, `data:image/...` base64 URIs, or server-relative paths ("/static/x.png").
// Relative paths must be prefixed with the API host of the CURRENT build
// (kBaseUrl, set via --dart-define=API_BASE_URL) so staging builds never fall
// through to another environment.
//
// NOTE: created as a shared utility; existing call sites are migrated
// incrementally in later steps (not all at once).
import '../constants/app_constants.dart';

/// True when [raw] is an inline base64 image (`data:image/...`).
bool isDataImage(String raw) => raw.trimLeft().startsWith('data:image');

/// Returns an absolute URL for [raw]:
///  * empty / null            -> ''
///  * `http(s)://...`         -> unchanged
///  * `data:image/...`        -> unchanged
///  * `/relative/path`        -> `<baseUrl>/relative/path`
///  * anything else           -> unchanged
String resolveImageUrl(String? raw, {String? baseUrl}) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return '';
  if (s.startsWith('/')) return '${baseUrl ?? kBaseUrl}$s';
  return s;
}
