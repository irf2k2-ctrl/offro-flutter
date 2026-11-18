/// Home-screen category helpers (pure Dart, no Flutter imports, unit-tested).
///
/// A category is "used" when at least one store available to the customer
/// belongs to it, and its store count is the number of such stores. The match
/// rule is the same one the category screen uses to list a category's stores,
/// so the number on a category always equals the stores shown when it is opened.
/// Matching is deliberately strict (see [storeMatchesCategory]) so similar-looking
/// names never inflate each other's counts.

/// Categories shown before "See All" is needed: 2 rows x 4 per row.
const int kCategoryColumns = 4;
const int kCategoryInitialVisible = 8;

/// Canonical form used for comparing category names: lower-case, "&" read as
/// "and", every character that is not a letter or digit (any script) removed ("Fast Food" == "fast-food" == "FastFood").
String normalizeCategoryName(String? name) {
  final lower = (name ?? '').toLowerCase().replaceAll('&', 'and');
  return lower.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
}

/// True when a store saved under [storeCategory] belongs to the admin category
/// [categoryName]: the names must be the same after normalising, or differ only
/// as singular / plural of the WHOLE name ("Restaurant" / "Restaurants",
/// "Bakery" / "Bakeries"). Names that merely contain or start with one another
/// do NOT match ("Bar" is not "Barber Shop", "Pet" is not "Petrol Pump",
/// "Food" is not "Fast Food"). A blank store category never matches.
bool storeMatchesCategory(String? storeCategory, String categoryName) {
  final a = normalizeCategoryName(storeCategory);
  final b = normalizeCategoryName(categoryName);
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  bool plural(String single, String many) =>
      many == '${single}s' ||
      many == '${single}es' ||
      (single.endsWith('y') && many == '${single.substring(0, single.length - 1)}ies');
  return plural(a, b) || plural(b, a);
}

class CategoryCount {
  final String name;
  final int count;
  const CategoryCount(this.name, this.count);

  @override
  bool operator ==(Object other) =>
      other is CategoryCount && other.name == name && other.count == count;
  @override
  int get hashCode => Object.hash(name, count);
  @override
  String toString() => 'CategoryCount($name, $count)';
}

/// Admin categories (in admin order, duplicates by name dropped) that have at
/// least one store, each with its store count. Categories with no stores are
/// left out.
List<CategoryCount> usedCategoryCounts(
  Iterable<String> categoryNames,
  Iterable<Map<String, dynamic>> stores,
) {
  final storeCats = <String>[
    for (final s in stores) (s['category'] ?? '').toString(),
  ];
  final seen = <String>{};
  final out = <CategoryCount>[];
  for (final raw in categoryNames) {
    final name = raw.trim();
    if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
    var n = 0;
    for (final sc in storeCats) {
      if (storeMatchesCategory(sc, name)) n++;
    }
    if (n > 0) out.add(CategoryCount(name, n));
  }
  return out;
}

/// EVERY admin category (admin order, duplicates by name dropped) with its store count, including
/// categories that currently have no stores (count 0). Same match rule and same counting as [usedCategoryCounts].
List<CategoryCount> allCategoryCounts(
  Iterable<String> categoryNames,
  Iterable<Map<String, dynamic>> stores,
) {
  final storeCats = <String>[
    for (final s in stores) (s['category'] ?? '').toString(),
  ];
  final seen = <String>{};
  final out = <CategoryCount>[];
  for (final raw in categoryNames) {
    final name = raw.trim();
    if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
    var n = 0;
    for (final sc in storeCats) {
      if (storeMatchesCategory(sc, name)) n++;
    }
    out.add(CategoryCount(name, n));
  }
  return out;
}

/// Categories ranked for the Home screen: most stores first. Equal counts are ordered by the
/// category name (normalised, then as written) so the order is the same on every rebuild and device.
/// Returns a new list; [all] is not modified.
List<CategoryCount> rankedCategories(Iterable<CategoryCount> all) {
  final out = List<CategoryCount>.of(all);
  out.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    final byNorm = normalizeCategoryName(a.name).compareTo(normalizeCategoryName(b.name));
    if (byNorm != 0) return byNorm;
    return a.name.compareTo(b.name);
  });
  return out;
}

/// The Home screen's categories: always [kCategoryInitialVisible] (8) when at least 8 exist. Highest store count
/// first, equal counts alphabetical; when fewer than 8 categories have stores the remaining places are filled with
/// the next categories in the same order, i.e. categories with 0 stores (alphabetical). Fewer than 8 are returned
/// only when fewer than 8 categories exist in total. Pass [allCategoryCounts] (zero-store categories included).
List<CategoryCount> topCategoriesByStoreCount(Iterable<CategoryCount> all) {
  final ranked = rankedCategories(all);
  return ranked.length <= kCategoryInitialVisible ? ranked : ranked.sublist(0, kCategoryInitialVisible);
}

/// The categories to draw: the first [kCategoryInitialVisible] until the user
/// expands the list. (No longer used by Home, which shows [topCategoriesByStoreCount] and opens the
/// full Categories screen from "See All"; kept because it is unit-tested.)
List<CategoryCount> visibleCategories(List<CategoryCount> all, {required bool expanded}) =>
    expanded || all.length <= kCategoryInitialVisible
        ? all
        : all.sublist(0, kCategoryInitialVisible);

/// "See All" is offered only when more than [kCategoryInitialVisible] exist.
bool needsSeeAll(List<CategoryCount> all) => all.length > kCategoryInitialVisible;

/// Splits [items] into rows of [perRow] (last row may be shorter).
List<List<T>> chunkRows<T>(List<T> items, [int perRow = kCategoryColumns]) {
  final rows = <List<T>>[];
  for (var i = 0; i < items.length; i += perRow) {
    rows.add(items.sublist(i, i + perRow > items.length ? items.length : i + perRow));
  }
  return rows;
}

/// Count shown in the pill; very large numbers are capped so the pill stays small.
String categoryCountLabel(int count) => count > 99 ? '99+' : '$count';
