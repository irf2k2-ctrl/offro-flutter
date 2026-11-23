// lib/core/services/default_store_image.dart
//
// Pure helpers for the Default Store Image shown on Home when the selected city has no stores. No Flutter, no network, no storage.
//
// Source: GET /default-images?country=XX -> `store`. The BACKEND already filters by country (images mapped to the requested country
// first, otherwise the images mapped to no country = "All countries"; never an image mapped to another country), so this app does no
// country matching of its own. The only thing checked here is a cached answer: the payload also carries `country` (the country it was
// chosen for), and a cached payload for another country is not used.

import 'dart:math' show Random;

/// True for an image the app can draw: an http(s) URL or an inline data:image URI. Anything else (empty, junk, a video) is not usable.

bool isUsableImageSource(String? v) {
  final s = (v ?? '').trim();
  return RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(s) || s.startsWith('data:image');
}

/// The Default Store Image from a /default-images payload, or "" when there is none / it is invalid / the payload was chosen for
/// another country than [expectedCountry] (the signed-in account's country; null or empty = unknown).
/// `store` is a single URL, but an array (the shape of the other categories) is tolerated: its first usable entry is taken.
String defaultStoreImageFrom(Map<String, dynamic> defaults, {String? expectedCountry}) {
  final all = defaultStoreImagesFrom(defaults, expectedCountry: expectedCountry);
  return all.isEmpty ? '' : all.first;
}

/// ALL usable Default Store Images for this country (the server's `store_images` list, else `store` from an older server), in the
/// order the admin configured them. Empty when none / the payload was chosen for another country. Same country check as above.
List<String> defaultStoreImagesFrom(Map<String, dynamic> defaults, {String? expectedCountry}) {
  final payloadCountry = (defaults['country'] ?? '').toString().trim().toUpperCase();
  final expected = (expectedCountry ?? '').trim().toUpperCase();
  if (payloadCountry.isNotEmpty && payloadCountry != expected) return const [];
  List<String> usable(dynamic v) {
    if (v is String) return isUsableImageSource(v) ? [v.trim()] : const [];
    if (v is List) return [for (final e in v) if (e is String && isUsableImageSource(e)) e.trim()];
    return const [];
  }

  final multi = usable(defaults['store_images']);
  return multi.isNotEmpty ? multi : usable(defaults['store']);
}

/// One image out of the configured Default Store Images: the only one, or a random one when several are configured (the same
/// "rotation" the other default images use). "" when there are none. [random] can be injected for tests.
String pickDefaultStoreImage(List<String> images, [Random? random]) {
  if (images.isEmpty) return '';
  if (images.length == 1) return images.first;
  return images[(random ?? Random()).nextInt(images.length)];
}

/// The image for an empty Home. Two different situations:
///  * [cityInServiceArea] == true  : a city OffrO serves that has no stores yet -> the Default Store Image (when there is one),
///                                   otherwise the No Service image.
///  * false (outside the service area) or null (not known, e.g. the check failed) -> always the No Service Area image, never the store image.
/// The result may be "" (nothing configured): the existing plain no-service screen is then shown.
String emptyCityImage({required String storeImage, required String noServiceImage, required bool? cityInServiceArea}) =>
    (cityInServiceArea == true && isUsableImageSource(storeImage)) ? storeImage.trim() : noServiceImage;
