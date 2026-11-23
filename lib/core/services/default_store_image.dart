// lib/core/services/default_store_image.dart
//
// Pure helpers for the Default Store Image shown on Home when the selected city has no stores. No Flutter, no network, no storage.
//
// Source: GET /default-images?country=XX -> `store`. The BACKEND already filters by country (images mapped to the requested country
// first, otherwise the images mapped to no country = "All countries"; never an image mapped to another country), so this app does no
// country matching of its own. The only thing checked here is a cached answer: the payload also carries `country` (the country it was
// chosen for), and a cached payload for another country is not used.

/// True for an image the app can draw: an http(s) URL or an inline data:image URI. Anything else (empty, junk, a video) is not usable.
bool isUsableImageSource(String? v) {
  final s = (v ?? '').trim();
  return RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(s) || s.startsWith('data:image');
}

/// The Default Store Image from a /default-images payload, or "" when there is none / it is invalid / the payload was chosen for
/// another country than [expectedCountry] (the signed-in account's country; null or empty = unknown).
/// `store` is a single URL, but an array (the shape of the other categories) is tolerated: its first usable entry is taken.
String defaultStoreImageFrom(Map<String, dynamic> defaults, {String? expectedCountry}) {
  final payloadCountry = (defaults['country'] ?? '').toString().trim().toUpperCase();
  final expected = (expectedCountry ?? '').trim().toUpperCase();
  if (payloadCountry.isNotEmpty && payloadCountry != expected) return '';
  final v = defaults['store'];
  if (v is String) return isUsableImageSource(v) ? v.trim() : '';
  if (v is List) {
    for (final e in v) {
      if (e is String && isUsableImageSource(e)) return e.trim();
    }
  }
  return '';
}

/// The image for a city that has NO stores: the Default Store Image when there is one, otherwise the existing "No service" image
/// (which may be "" too: the existing plain no-service screen is then shown).
String emptyCityImage({required String storeImage, required String noServiceImage}) =>
    isUsableImageSource(storeImage) ? storeImage.trim() : noServiceImage;
