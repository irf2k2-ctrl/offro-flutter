// lib/core/services/merchant_store_logic.dart
// Merchant Add/Edit Store: the pure country / city decisions (no Flutter, no network).
//
// The merchant NEVER chooses a country: it is the account's (derived from the account phone, `Api.customerCountry`). India keeps its
// existing experience (free State / City text, the bundled India lists, the 10-digit phone rule). A non-India account gets City Master
// suggestions for its own country, and a GPS / Google Maps place that lies in ANOTHER country is refused with a clear message.
// The server validates the same rules again (routers/merchant_app.py _store_country_rules); this only gives instant feedback.

import '../models/offro_location.dart';
import '../phone/phone_country.dart';

/// True for an India account, and for an account whose country is not known (the app then behaves exactly as it always did).
bool isIndiaAccount(String? iso) {
  final k = (iso ?? '').trim().toUpperCase();
  return k.isEmpty || k == 'IN';
}

/// The ISO code to send as the store's `country` (the ACCOUNT's, never chosen): '' for India / unknown, so older server behaviour and
/// India records stay exactly as they were.
String storeCountryToSend(String? accountIso) =>
    isIndiaAccount(accountIso) ? '' : (accountIso ?? '').trim().toUpperCase();

/// The supported country a geocoded place lies in, when it is NOT the account's country; null when it is the same country, or when the
/// place's country is unknown / unsupported / the account's country is unknown (nothing is assumed, nothing blocked).
String? otherCountryOfPlace({required String? placeIso, required String? accountIso}) {
  final p = (placeIso ?? '').trim().toUpperCase();
  final a = (accountIso ?? '').trim().toUpperCase();
  if (p.isEmpty || a.isEmpty) return null;
  if (phoneCountryByIso(p) == null) return null;
  return p == a ? null : p;
}

String _k(String? s) => (s ?? '').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ').toLowerCase();

/// Administrative words a geocoder puts around a city name ("Riyadh Governorate", "محافظة الرياض", "Jeddah City"). They are not part of the
/// city's name, so they are dropped when comparing a geocoded name with the City Master - never when comparing two different names.
const _cityQualifiers = <String>{
  'governorate', 'province', 'region', 'municipality', 'city', 'district', 'emirate', 'prefecture', 'county',
  'محافظة', 'منطقة', 'مدينة', 'بلدية', 'امارة', 'إمارة', 'امانة', 'أمانة',
};

String _arabicFold(String s) => s
    .replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '')
    .replaceAll(RegExp('[\u0623\u0625\u0622]'), '\u0627')
    .replaceAll('\u0649', '\u064A')
    .replaceAll('\u0629', '\u0647');

/// The qualifiers in the SAME folded form the compared text is put in. Folding changes letters inside the Arabic qualifiers themselves
/// (the final ة of "محافظة" becomes ه, the hamza on "إمارة" is dropped), so the raw list can never match folded text - both sides must be folded.
final Set<String> _cityQualifierKeys = _cityQualifiers.map((q) => _arabicFold(q.toLowerCase())).toSet();

/// A comparison key: lower-case, spacing/punctuation/diacritics normalised, qualifier words removed. Empty when nothing is left.
String _cityKey(String? s) {
  final words = _arabicFold(_k(s)).split(RegExp(r'[\s,،.\-]+')).where((w) => w.isNotEmpty && !_cityQualifierKeys.contains(w));
  return words.join(' ');
}

/// The City Master city a typed / geocoded name refers to: matched by its canonical name or any translation, ignoring case and spacing.
/// An exact (case/space-insensitive) match always wins; otherwise a geocoded name that differs only by a qualifier ("Riyadh Governorate",
/// "محافظة الرياض") or Arabic spelling variants resolves to the same master city. A different city name never matches.
SupportedCity? matchCountryCity(String? name, List<SupportedCity> cities) {
  final n = _k(name);
  if (n.isEmpty) return null;
  for (final c in cities) {
    if (_k(c.name) == n) return c;
    for (final v in c.names.values) {
      if (_k(v) == n) return c;
    }
  }
  final key = _cityKey(name);
  if (key.isEmpty) return null;
  for (final c in cities) {
    if (_cityKey(c.name) == key) return c;
    for (final v in c.names.values) {
      if (_cityKey(v) == key) return c;
    }
  }
  return null;
}

/// Suggestions for what the merchant has typed: cities whose name or translation contains the text, popular ones first; at most [max].
List<SupportedCity> suggestCountryCities(String? typed, List<SupportedCity> cities, {int max = 8}) {
  final n = _k(typed);
  final out = <SupportedCity>[];
  for (final c in cities) {
    if (n.isEmpty || _k(c.name).contains(n) || c.names.values.any((v) => _k(v).contains(n))) out.add(c);
  }
  out.sort((a, b) {
    if (a.isPopular != b.isPopular) return a.isPopular ? -1 : 1;
    if (a.isPopular && a.popularOrder != b.popularOrder) return a.popularOrder.compareTo(b.popularOrder);
    return a.name.compareTo(b.name);
  });
  return out.length > max ? out.sublist(0, max) : out;
}

/// Is the store's city acceptable before saving? India / unknown account: always (unchanged). Another country: the city must be one of
/// that country's City Master cities - unless the list could not be loaded (offline / none configured yet), when the server decides.
bool storeCityAcceptable({required String? city, required String? accountIso, required List<SupportedCity> cities, required bool listLoaded}) {
  if (isIndiaAccount(accountIso)) return true;
  if (!listLoaded || cities.isEmpty) return true;
  return matchCountryCity(city, cities) != null;
}
