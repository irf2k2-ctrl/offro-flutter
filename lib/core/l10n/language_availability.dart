// lib/core/l10n/language_availability.dart
//
// Which of the app's bundled languages the language chooser lists for a country. Pure Dart (no Flutter, no network, no storage).
//
// The admin dashboard maps each language to countries (many to many) and the backend manifest carries that mapping. The rules here
// are deliberately forgiving, so this can only ever NARROW the list when there is clear data, and never leave a user stuck:
//   * no country known, or no mapping known (older backend, kill switch on, offline and nothing cached) -> every bundled language;
//   * a language with no countries, or one the mapping does not list, is not restricted -> offered everywhere;
//   * the language currently in use is always listed, so the chooser never loses the user's own selection;
//   * if the rules would leave nothing -> every bundled language.
// Only languages the app already bundles can be listed: a mapped language the app does not contain cannot be shown here.

List<String> availableLanguageCodes({
  required List<String> bundled,
  required String? countryIso,
  required Map<String, Set<String>> mapping,
  String? currentCode,
}) {
  final iso = (countryIso ?? '').trim().toUpperCase();
  if (iso.isEmpty || mapping.isEmpty) return List<String>.of(bundled);
  final out = <String>[];
  for (final code in bundled) {
    final countries = mapping[code];
    final unrestricted = countries == null || countries.isEmpty;
    if (unrestricted || countries.contains(iso) || code == currentCode) {
      out.add(code);
    }
  }
  return out.isEmpty ? List<String>.of(bundled) : out;
}
