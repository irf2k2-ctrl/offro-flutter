// lib/core/phone/phone_country.dart
// Phase C: reusable country foundation for international phone numbers. Pure Dart (no Flutter, no network, no storage).
//
// NOT wired into any screen yet. The existing login and registration flows are untouched in this phase.
//
// Supported countries (Phase 1): India +91, Jordan +962, Nepal +977, Philippines +63, Saudi Arabia +966.
// This file knows country names, flags and calling codes, picks a suggested country, and builds an E.164 string.
// It deliberately does NOT decide whether a number is valid: per-country validation comes from libphonenumber
// metadata in a later phase (the backend already does this in utils/phone.py), so no prefix rules are kept here.

class PhoneCountry {
  const PhoneCountry({required this.iso, required this.name, required this.dial, required this.flag});

  final String iso; // ISO 3166-1 alpha-2, upper case
  final String name; // English name (translated through localization in a later phase)
  final String dial; // calling code digits only, no plus
  final String flag; // emoji flag

  String get dialLabel => '+$dial';

  @override
  bool operator ==(Object other) => other is PhoneCountry && other.iso == iso;
  @override
  int get hashCode => iso.hashCode;
  @override
  String toString() => 'PhoneCountry($iso $dialLabel)';
}

/// The supported countries, alphabetical by name (this is the order the selector shows).
const List<PhoneCountry> kPhoneCountries = <PhoneCountry>[
  PhoneCountry(iso: 'IN', name: 'India', dial: '91', flag: '\u{1F1EE}\u{1F1F3}'),
  PhoneCountry(iso: 'JO', name: 'Jordan', dial: '962', flag: '\u{1F1EF}\u{1F1F4}'),
  PhoneCountry(iso: 'NP', name: 'Nepal', dial: '977', flag: '\u{1F1F3}\u{1F1F5}'),
  PhoneCountry(iso: 'PH', name: 'Philippines', dial: '63', flag: '\u{1F1F5}\u{1F1ED}'),
  PhoneCountry(iso: 'SA', name: 'Saudi Arabia', dial: '966', flag: '\u{1F1F8}\u{1F1E6}'),
];

/// India is the default when nothing can be detected.
const PhoneCountry kDefaultPhoneCountry = PhoneCountry(iso: 'IN', name: 'India', dial: '91', flag: '\u{1F1EE}\u{1F1F3}');

/// The supported country for an ISO code such as 'sa' or 'SA', or null when it is not one of the five.
PhoneCountry? phoneCountryByIso(String? iso) {
  final k = (iso ?? '').trim().toUpperCase();
  if (k.isEmpty) return null;
  for (final c in kPhoneCountries) {
    if (c.iso == k) return c;
  }
  return null;
}

/// The supported country for a calling code such as '966' or '+966', or null.
PhoneCountry? phoneCountryByDial(String? dial) {
  var k = (dial ?? '').trim();
  if (k.startsWith('+')) k = k.substring(1);
  if (k.isEmpty) return null;
  for (final c in kPhoneCountries) {
    if (c.dial == k) return c;
  }
  return null;
}

/// Where a suggested country came from.
enum CountrySource { sim, network, ip, locale, defaultIndia, manual }

class CountrySuggestion {
  const CountrySuggestion(this.country, this.source);
  final PhoneCountry country;
  final CountrySource source;
}

/// Picks the country to PRE-SELECT. The user can always change it.
///
/// Order: SIM country, then network country, then IP-based country, then the device locale region, then India.
/// Only the five supported countries are ever suggested. A detected country that is not supported (for example a
/// tourist's SIM) is skipped as if it were unavailable, never forced to India while a later source is still usable.
/// Each input is an ISO code (any case) or null. Gathering the inputs (SIM, network, IP) is done elsewhere.
CountrySuggestion suggestCountry({String? simIso, String? networkIso, String? ipIso, String? localeRegion}) {
  final tries = <MapEntry<CountrySource, String?>>[
    MapEntry(CountrySource.sim, simIso),
    MapEntry(CountrySource.network, networkIso),
    MapEntry(CountrySource.ip, ipIso),
    MapEntry(CountrySource.locale, localeRegion),
  ];
  for (final t in tries) {
    final c = phoneCountryByIso(t.value);
    if (c != null) return CountrySuggestion(c, t.key);
  }
  return const CountrySuggestion(kDefaultPhoneCountry, CountrySource.defaultIndia);
}

/// Digits only. Arabic-Indic and Extended Arabic-Indic digits are turned into 0-9. One leading 0 (a national
/// trunk prefix, as people type 05xxxxxxxx in Saudi Arabia) is removed. Nothing else is guessed or cut: digits are never
/// truncated to a fixed length.
String nationalDigits(String raw) {
  final b = StringBuffer();
  for (final r in raw.runes) {
    if (r >= 0x30 && r <= 0x39) {
      b.writeCharCode(r);
    } else if (r >= 0x0660 && r <= 0x0669) {
      b.writeCharCode(0x30 + (r - 0x0660));
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      b.writeCharCode(0x30 + (r - 0x06F0));
    }
  }
  var d = b.toString();
  if (d.startsWith('0')) d = d.substring(1);
  return d;
}

/// '+<calling code><national digits>' for display and for sending to the server. This is formatting, NOT validation.
String toE164(PhoneCountry country, String rawNational) => '+${country.dial}${nationalDigits(rawNational)}';
