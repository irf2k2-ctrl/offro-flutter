// lib/core/services/influencer_city_logic.dart
// Pure rules for the influencer profile form's State / City fields (no widgets, no network - unit tested).
//
//  * The profile's country comes from the account / phone country (ISO).
//  * India keeps the long-standing State -> City lists (kIndiaStates / kIndiaCities) exactly as before.
//  * Every other country shows ONLY the cities the existing country-aware Cities API returned for it (GET /cities?country=XX),
//    labelled in the app language with the English name as the fallback; the bundled India list is never used for them.
//  * The value that is saved is always the English (canonical) name, never the translated label.
//  * When the country changes, a selected city that is not one of the new country's cities is cleared.
import '../models/offro_location.dart';
import 'city_list_logic.dart';

/// True when the bundled India State -> City lists apply (India only).
bool influencerUsesIndiaLists(String? country) => (country ?? '').trim().toUpperCase() == 'IN';

/// The cities to offer for a non-India [country]: the server's (already country-filtered) cities, sorted for [lang].
List<SupportedCity> influencerCityChoices(List<SupportedCity> server, String? lang) => sortCitiesForLang(server, lang);

/// [selected] if it is one of [choices] (matched case-insensitively on the English name, returned in the canonical spelling), else null.
String? keepValidInfluencerCity(String? selected, List<SupportedCity> choices) {
  final s = (selected ?? '').trim().toLowerCase();
  if (s.isEmpty) return null;
  for (final c in choices) {
    if (c.name.trim().toLowerCase() == s) return c.name;
  }
  return null;
}

/// The City Master state of [city] ('' when it has none) - sent as the profile's `state` for countries without the India state list.
String influencerStateFor(String? city, List<SupportedCity> choices) {
  final s = (city ?? '').trim().toLowerCase();
  for (final c in choices) {
    if (c.name.trim().toLowerCase() == s) return c.state;
  }
  return '';
}
