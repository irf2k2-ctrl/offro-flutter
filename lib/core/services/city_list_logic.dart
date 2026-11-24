// lib/core/services/city_list_logic.dart
// Pure rules for the Location screen's two lists (no widgets, no network - unit tested).
//
//  * Popular cities: the cities the admin flagged (is_popular), in popular_order, at most [popularLimit].
//    India keeps its long-standing rule while NO Indian city is flagged: the first six server cities, topped up with the metros.
//    Any other country with no flagged city shows no Popular section at all (never an invented one).
//  * All cities: sorted by the name SHOWN in the selected language. Arabic ignores diagnostics (tashkeel, tatweel), folds the
//    alef/yaa/taa-marbuta variants and ignores a leading «ال»; names that fall back to English sort after the Arabic names.
import '../models/offro_location.dart';

const int popularLimit = 6;

bool _isArabicScript(String s) => RegExp(r'[؀-ۿ]').hasMatch(s);

/// Sort key for an Arabic city name: letters only, folded, leading «ال» removed.
String arabicSortKey(String s) {
  var t = s.trim()
      .replaceAll(RegExp(r'[ً-ٰٟـ]'), '')
      .replaceAll(RegExp(r'[آأإٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  if (t.length > 2 && t.startsWith('ال')) t = t.substring(2);
  return t;
}

/// [cities] ordered for display in app language [lang]. Ties keep a stable order (English name, then state).
List<SupportedCity> sortCitiesForLang(Iterable<SupportedCity> cities, String? lang) {
  final ar = (lang ?? '').trim().toLowerCase().startsWith('ar');
  final out = [...cities];
  int cmp(SupportedCity a, SupportedCity b) {
    var r = 0;
    if (ar) {
      final la = a.labelFor(lang), lb = b.labelFor(lang);
      final aa = _isArabicScript(la), ab = _isArabicScript(lb);
      if (aa != ab) return aa ? -1 : 1;                                   // Arabic names first, English fallbacks after
      r = aa ? arabicSortKey(la).compareTo(arabicSortKey(lb)) : la.toLowerCase().compareTo(lb.toLowerCase());
    } else {
      r = a.labelFor(lang).toLowerCase().compareTo(b.labelFor(lang).toLowerCase());
    }
    if (r != 0) return r;
    r = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return r != 0 ? r : a.state.toLowerCase().compareTo(b.state.toLowerCase());
  }
  out.sort(cmp);
  return out;
}

/// The Popular cities to show.
///  * [server]  the active cities from GET /cities, in the server's order (popular first, then sort order).
///  * [shown]   the list the screen offers (for India: bundled reference merged with the server cities), used to pick the
///              richest entry (state, translations) for a flagged name.
///  * [legacyIndia] true for India / guests: the pre-flag behaviour is kept until at least one city is flagged.
///  * [metros]  the bundled metro names used only by that legacy top-up.
List<SupportedCity> popularCities({
  required List<SupportedCity> server,
  required List<SupportedCity> shown,
  required bool legacyIndia,
  List<String> metros = const [],
  int limit = popularLimit,
}) {
  SupportedCity pick(SupportedCity c) {
    for (final x in shown) {
      if (x.name.toLowerCase() == c.name.toLowerCase() && (c.state.isEmpty || x.state.toLowerCase() == c.state.toLowerCase())) return x;
    }
    return c;
  }

  final flagged = server.where((c) => c.isPopular).toList();
  if (flagged.isNotEmpty) {
    // stable by popular_order (a missing order sorts last), then the server's own order
    final idx = <SupportedCity, int>{for (var i = 0; i < flagged.length; i++) flagged[i]: i};
    flagged.sort((a, b) {
      final oa = a.popularOrder > 0 ? a.popularOrder : 1 << 30, ob = b.popularOrder > 0 ? b.popularOrder : 1 << 30;
      return oa != ob ? oa.compareTo(ob) : idx[a]!.compareTo(idx[b]!);
    });
    return [for (final c in flagged.take(limit)) pick(c)];
  }
  if (!legacyIndia) return const [];

  final out = <SupportedCity>[];
  bool has(String n) => out.any((e) => e.name.toLowerCase() == n.toLowerCase());
  for (final c in server) {
    if (out.length >= limit) break;
    out.add(pick(c));
  }
  for (final m in metros) {
    if (out.length >= limit) break;
    if (has(m)) continue;
    final match = shown.where((x) => x.name == m);
    if (match.isNotEmpty) out.add(match.first);
  }
  return out;
}

/// {language: name} from the City Master payload; anything that is not a non-blank string is dropped, codes are lower-cased.
Map<String, String> parseCityNameMap(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, String>{};
  raw.forEach((k, v) {
    final key = k.toString().trim().toLowerCase();
    final val = v is String ? v.trim() : '';
    if (key.isNotEmpty && val.isNotEmpty) out[key] = val;
  });
  return out;
}

/// GET /cities payload -> cities. Duplicates (same name AND same state) are dropped; cities without a state keep the long-standing
/// "one per name" rule. A city's own `state` wins; otherwise [stateFor] (India's bundled table, or nothing) supplies it.
List<SupportedCity> parseCityList(List raw, {required String Function(String name) stateFor}) {
  final out = <SupportedCity>[];
  final seen = <String>{};
  for (final c in raw) {
    if (c is! Map) continue;
    final name = (c['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    final serverState = (c['state'] ?? '').toString().trim();
    if (!seen.add('${name.toLowerCase()}|${serverState.toLowerCase()}')) continue;
    final order = c['popular_order'];
    out.add(SupportedCity(
      name: name,
      state: serverState.isNotEmpty ? serverState : stateFor(name),
      id: (c['id'] ?? '').toString(),
      names: parseCityNameMap(c['names']),
      isPopular: c['is_popular'] == true,
      popularOrder: order is num ? order.toInt() : 0,
    ));
  }
  return out;
}
