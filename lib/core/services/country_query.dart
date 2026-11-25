/// Optional `country` query parameter of the public discovery lists (stores, influencers, deals, products).
///
/// Sent only when the customer's country is known (set from the login phone). Not sent for guests / unknown -> the server keeps its
/// existing unfiltered behaviour. The same city name in two countries never mixes once the server receives it.
String countryQueryValue(String? iso) {
  final c = (iso ?? '').trim().toUpperCase();
  return RegExp(r'^[A-Z]{2}$').hasMatch(c) ? c : '';
}

/// Appends `country=XX` to [path] (which may or may not already have a query string); unchanged when [iso] is unknown.
String withCountryQuery(String path, String? iso) {
  final c = countryQueryValue(iso);
  if (c.isEmpty) return path;
  return path + (path.contains('?') ? '&' : '?') + 'country=$c';
}

/// Cache-key suffix so a list cached for one country is never reused for another.
String countryCacheSuffix(String? iso) {
  final c = countryQueryValue(iso);
  return c.isEmpty ? '' : ':$c';
}
