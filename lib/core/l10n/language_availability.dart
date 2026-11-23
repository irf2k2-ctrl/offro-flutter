// lib/core/l10n/language_availability.dart
//
// Which of the app's bundled languages a country may use. Pure Dart (no Flutter, no network, no storage).
//
// The admin dashboard maps each language to countries (many to many) and the backend manifest carries that mapping. The policy is
// STRICT: a language other than English is offered only when the mapping explicitly lists the country for it.
//   * English is the default language and is always allowed, so nobody is ever left without a language;
//   * no country known, or no mapping known (older backend, kill switch on, offline and nothing cached) -> English only;
//   * a language the mapping does not list for this country (or lists for no country) is NOT allowed there, for example Arabic
//     mapped to Saudi Arabia only is never offered to a user in India;
//   * the language currently in use gets NO exception: if it is not allowed it must be replaced (see language_policy.dart).
// Only languages the app already bundles can be listed: a mapped language the app does not contain cannot be shown here.

const String kDefaultLanguageCode = 'en';

List<String> availableLanguageCodes({
  required List<String> bundled,
  required String? countryIso,
  required Map<String, Set<String>> mapping,
  String defaultCode = kDefaultLanguageCode,
}) {
  final iso = (countryIso ?? '').trim().toUpperCase();
  final out = <String>[];
  for (final code in bundled) {
    if (code == defaultCode) {
      out.add(code);
      continue;
    }
    if (iso.isEmpty || mapping.isEmpty) continue;
    final countries = mapping[code];
    if (countries != null && countries.contains(iso)) out.add(code);
  }
  return out.isEmpty ? <String>[defaultCode] : out;
}

/// Whether [code] may be used for [countryIso] under the policy above.
bool isLanguageAllowed({
  required String code,
  required List<String> bundled,
  required String? countryIso,
  required Map<String, Set<String>> mapping,
  String defaultCode = kDefaultLanguageCode,
}) =>
    availableLanguageCodes(
            bundled: bundled, countryIso: countryIso, mapping: mapping, defaultCode: defaultCode)
        .contains(code);
