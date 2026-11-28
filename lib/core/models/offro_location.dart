// lib/core/models/offro_location.dart
// OFFRO — Structured location (single model used by Customer AND Merchant).
//
// Store filtering stays CITY-based; locality/area/state are for display,
// persistence and future use. For a manually chosen city, locality and area
// are empty.

import '../phone/phone_country.dart';

enum LocationSource { gps, manual }

class OffroLocation {
  final String locality; // finest detail, e.g. "Radio Park Cowl Bazar"
  final String area;     // area / sub-locality, e.g. "Cowl Bazaar"
  final String city;     // OffrO city used for store filtering, e.g. "Ballari"
  final String state;    // e.g. "Karnataka"
  /// ISO country of THIS place ('IN', 'SA', ...; '' = not known). It describes the selected / GPS location, never the account's
  /// registration country: a Saudi account physically in India has a location in 'IN'. Set from verified reverse geocoding or from the
  /// country list the user picked the city from; never guessed.
  final String country;
  final double? lat;     // coordinates of the selected GPS fix (null for manual)
  final double? lng;
  final LocationSource source;
  final DateTime? updatedAt;

  const OffroLocation({
    this.locality = '',
    this.area = '',
    required this.city,
    this.state = '',
    this.country = '',
    this.lat,
    this.lng,
    this.source = LocationSource.manual,
    this.updatedAt,
  });

  bool get hasCity => city.trim().isNotEmpty;

  /// Header title: locality, else area, else city.
  String get title {
    if (locality.trim().isNotEmpty) return locality.trim();
    if (area.trim().isNotEmpty) return area.trim();
    return city.trim();
  }

  /// Header subtitle.
  ///  locality set:  "Cowl Bazaar, Ballari, Karnataka"
  ///  no locality:   "Karnataka, India"   (area-only: "Ballari, Karnataka")
  /// The country is the location's OWN country (see [country]) - never a fixed one. When it is not known nothing is appended.
  String get subtitle => subtitleFor(null);

  /// Like [subtitle]; [countryLabel] turns the ISO code into the name to show (e.g. in the app language). Default: the English name.
  String subtitleFor(String Function(String iso)? countryLabel) {
    String join(List<String> parts) =>
        parts.map((p) => p.trim()).where((p) => p.isNotEmpty).join(', ');
    if (locality.trim().isNotEmpty) return join([area, city, state]);
    if (area.trim().isNotEmpty) return join([city, state]);
    final iso = country.trim().toUpperCase();
    final name = iso.isEmpty ? '' : (countryLabel != null ? countryLabel(iso) : (phoneCountryByIso(iso)?.name ?? ''));
    return join([state, name]);
  }

  OffroLocation copyWith({String? country}) => OffroLocation(
        locality: locality, area: area, city: city, state: state, country: country ?? this.country,
        lat: lat, lng: lng, source: source, updatedAt: updatedAt);

  bool sameCity(String other) =>
      city.trim().toLowerCase() == other.trim().toLowerCase();

  Map<String, dynamic> toJson() => {
        'locality': locality,
        'area': area,
        'city': city,
        'state': state,
        'country': country,
        'lat': lat,
        'lng': lng,
        'source': source == LocationSource.gps ? 'gps' : 'manual',
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  static OffroLocation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final city = (raw['city'] ?? '').toString().trim();
    if (city.isEmpty) return null;
    return OffroLocation(
      locality: (raw['locality'] ?? '').toString(),
      area: (raw['area'] ?? '').toString(),
      city: city,
      state: (raw['state'] ?? '').toString(),
      country: (raw['country'] ?? '').toString().trim().toUpperCase(),
      lat: (raw['lat'] as num?)?.toDouble(),
      lng: (raw['lng'] as num?)?.toDouble(),
      source: raw['source'] == 'gps' ? LocationSource.gps : LocationSource.manual,
      updatedAt: DateTime.tryParse((raw['updated_at'] ?? '').toString()),
    );
  }
}

/// A city OffrO currently supports (from GET /cities).
class SupportedCity {
  /// The canonical (English) name. It is what is stored on a chosen location and used for matching; it never changes with the app language.
  final String name;
  final String state; // the City Master state / province, else (India) the bundled table; may be empty
  /// The city's id from the City Master ('' for a bundled reference city). Selection and matching never depend on the translated label.
  final String id;
  /// {language code: translated name} from the City Master ({} when the city has no translations).
  final Map<String, String> names;
  /// Admin flag from the City Master (Admin -> Cities -> Popular) and its position (1 = first; 0 = none).
  final bool isPopular;
  final int popularOrder;
  const SupportedCity({required this.name, this.state = '', this.id = '', this.names = const {}, this.isPopular = false, this.popularOrder = 0});

  /// The name to SHOW for app language [lang]: its own translation (exact code, then its base language: 'ar-SA' -> 'ar'), else [name].
  String labelFor(String? lang) => cityDisplayName(name, names, lang);
}

/// Display name of a city for app language [lang]; falls back to the English/canonical [name] when there is no (non-blank) translation.
String cityDisplayName(String name, Map<String, String> names, String? lang) {
  final code = (lang ?? '').trim().toLowerCase().replaceAll('_', '-');
  if (code.isEmpty || names.isEmpty) return name;
  for (final k in <String>{code, code.split('-').first}) {
    final v = names[k];
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return name;
}
