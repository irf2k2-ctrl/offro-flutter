import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/utils/category_counts.dart';

Map<String, dynamic> store(String? cat) => {'category': cat};

void main() {
  group('storeMatchesCategory', () {
    test('exact, case-insensitive, trimmed, punctuation/spacing ignored', () {
      expect(storeMatchesCategory(' Cafe ', 'cafe'), isTrue);
      expect(storeMatchesCategory('Fast-Food', 'Fast Food'), isTrue);
      expect(storeMatchesCategory('Health & Fitness', 'Health and Fitness'), isTrue);
    });
    test('non-Latin category names still match themselves (not stripped to nothing)', () {
      expect(storeMatchesCategory('रेस्टोरेंट', 'रेस्टोरेंट'), isTrue);
      expect(storeMatchesCategory('रेस्टोरेंट', 'सैलून'), isFalse);
    });
    test('whole-name singular / plural still matches', () {
      expect(storeMatchesCategory('Restaurants', 'Restaurant'), isTrue);
      expect(storeMatchesCategory('Restaurant', 'Restaurants'), isTrue);
      expect(storeMatchesCategory('Bakeries', 'Bakery'), isTrue);
      expect(storeMatchesCategory('Bakery', 'Bakeries'), isTrue);
      expect(storeMatchesCategory('Boxes', 'Box'), isTrue);
    });
    test('similar-looking but different categories do NOT match', () {
      expect(storeMatchesCategory('Barber Shop', 'Bar'), isFalse);
      expect(storeMatchesCategory('Bar', 'Barber Shop'), isFalse);
      expect(storeMatchesCategory('Petrol Pump', 'Pet'), isFalse);
      expect(storeMatchesCategory('Smart Electronics', 'Art'), isFalse);
      expect(storeMatchesCategory('Fast Food', 'Food'), isFalse);
      expect(storeMatchesCategory('Food', 'Fast Food'), isFalse);
      expect(storeMatchesCategory('Cafeteria', 'Cafe'), isFalse);
      expect(storeMatchesCategory('Spares', 'Spa'), isFalse);
      expect(storeMatchesCategory('Gym', 'Gym & Fitness'), isFalse);
      expect(storeMatchesCategory('Hotel', 'Hostel'), isFalse);
    });
    test('blank / null / unrelated never match', () {
      expect(storeMatchesCategory('', 'Cafe'), isFalse);
      expect(storeMatchesCategory(null, 'Cafe'), isFalse);
      expect(storeMatchesCategory('Salon', 'Cafe'), isFalse);
      expect(storeMatchesCategory('Cafe', ''), isFalse);
      expect(storeMatchesCategory('---', '&&'), isFalse);
    });
  });

  group('usedCategoryCounts', () {
    test('keeps only categories with stores, counts them, preserves admin order', () {
      final r = usedCategoryCounts(
        ['Salon', 'Cafe', 'Gym', 'Pharmacy'],
        [store('Cafe'), store('cafe'), store('Salon'), store('Pharmacy'), store('Pharmacy'), store('Pharmacy')],
      );
      expect(r, [const CategoryCount('Salon', 1), const CategoryCount('Cafe', 2), const CategoryCount('Pharmacy', 3)]);
    });
    test('empty inputs, blank names and duplicate names', () {
      expect(usedCategoryCounts([], [store('Cafe')]), isEmpty);
      expect(usedCategoryCounts(['Cafe'], []), isEmpty);
      expect(usedCategoryCounts(['', '  ', 'Cafe', 'cafe'], [store('Cafe')]), [const CategoryCount('Cafe', 1)]);
    });
    test('stores without a category are ignored, not crashed on', () {
      expect(usedCategoryCounts(['Cafe'], [store(null), store(''), {}]), isEmpty);
    });
    test('similar names do not inflate each other\'s counts', () {
      final r = usedCategoryCounts(
        ['Bar', 'Barber Shop', 'Food', 'Fast Food'],
        [store('Bar'), store('Barber Shop'), store('Barber Shop'), store('Fast Food'), store('Food'), store('Food')],
      );
      expect(r, [
        const CategoryCount('Bar', 1), const CategoryCount('Barber Shop', 2),
        const CategoryCount('Food', 2), const CategoryCount('Fast Food', 1),
      ]);
    });
    test('count equals what the category screen would list for that category', () {
      final stores = [store('Restaurants'), store('Restaurant'), store('Cafe')];
      final n = stores.where((s) => storeMatchesCategory(s['category'] as String?, 'Restaurant')).length;
      expect(usedCategoryCounts(['Restaurant'], stores).single.count, n);
    });
  });

  group('layout rules', () {
    List<CategoryCount> make(int n) => [for (var i = 0; i < n; i++) CategoryCount('C$i', i + 1)];

    test('up to 8 categories: all shown, no See All', () {
      for (final n in [1, 5, 8]) {
        expect(needsSeeAll(make(n)), isFalse);
        expect(visibleCategories(make(n), expanded: false).length, n);
      }
    });
    test('more than 8: first 8 until expanded, then all', () {
      final all = make(11);
      expect(needsSeeAll(all), isTrue);
      expect(visibleCategories(all, expanded: false).length, 8);
      expect(visibleCategories(all, expanded: true).length, 11);
    });
    test('8 categories lay out as exactly 2 rows of 4', () {
      final rows = chunkRows(visibleCategories(make(8), expanded: false));
      expect(rows.map((r) => r.length), [4, 4]);
    });
    test('expanded layout keeps 4 per row with a shorter last row', () {
      expect(chunkRows(make(11)).map((r) => r.length), [4, 4, 3]);
      expect(chunkRows(make(3)).map((r) => r.length), [3]);
      expect(chunkRows(<int>[]), isEmpty);
    });
    test('count label caps very large numbers', () {
      expect(categoryCountLabel(0), '0');
      expect(categoryCountLabel(7), '7');
      expect(categoryCountLabel(99), '99');
      expect(categoryCountLabel(100), '99+');
    });
  });

  group('home categories (always 8, zero-store categories included)', () {
    // `counts` = every category in the system with the number of stores it has.
    List<CategoryCount> home(Map<String, int> counts) => topCategoriesByStoreCount(allCategoryCounts(
          counts.keys,
          [for (final e in counts.entries) for (var i = 0; i < e.value; i++) store(e.key)],
        ));
    List<String> names(List<CategoryCount> l) => l.map((c) => c.name).toList();

    test('10 categories with stores: the 8 with the most stores, highest first', () {
      final top = home({'A1': 1, 'B2': 12, 'C3': 5, 'D4': 9, 'E5': 3, 'F6': 20, 'G7': 7, 'H8': 2, 'I9': 15, 'J10': 4});
      expect(names(top), ['F6', 'I9', 'B2', 'D4', 'G7', 'C3', 'J10', 'E5']);
      expect(top.map((c) => c.count).toList(), [20, 15, 12, 9, 7, 5, 4, 3]);
    });
    test('fewer than 8 have stores: the rest are filled with zero-store categories, alphabetical', () {
      final top = home({'Salon': 5, 'Cafe': 2, 'Zoo': 0, 'Bank': 0, 'Gym': 0, 'Art': 0, 'Pet': 0, 'Spa': 0, 'Taxi': 0, 'Yoga': 0});
      expect(top.length, 8);
      expect(names(top), ['Salon', 'Cafe', 'Art', 'Bank', 'Gym', 'Pet', 'Spa', 'Taxi']);
      expect(top.map((c) => c.count).toList(), [5, 2, 0, 0, 0, 0, 0, 0]);
    });
    test('no store anywhere: still 8 categories, all with count 0, alphabetical', () {
      final top = home({for (final n in ['K', 'J', 'I', 'H', 'G', 'F', 'E', 'D', 'C', 'B', 'A']) n: 0});
      expect(names(top), ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']);
      expect(top.every((c) => c.count == 0), isTrue);
    });
    test('exactly 8 or fewer than 8 categories in total: all of them are shown', () {
      expect(home({for (var i = 0; i < 8; i++) 'C$i': i}).length, 8);
      final few = home({'Cafe': 2, 'Gym': 0, 'Salon': 5});
      expect(names(few), ['Salon', 'Cafe', 'Gym']);
      expect(home(<String, int>{}), isEmpty);
    });
    test('equal counts are alphabetical, the cut at 8 follows that order, independent of admin order', () {
      final m = {for (var i = 9; i >= 0; i--) 'Cat${String.fromCharCode(65 + i)}': 2};
      expect(names(home(m)), ['CatA', 'CatB', 'CatC', 'CatD', 'CatE', 'CatF', 'CatG', 'CatH']);
      final u = allCategoryCounts(['Zoo Shop', 'Bakery', 'apple store', 'Cafe'],
          [for (final c in ['Zoo Shop', 'Bakery', 'apple store', 'Cafe']) store(c)]);
      expect(names(rankedCategories(u)), ['apple store', 'Bakery', 'Cafe', 'Zoo Shop']);
      expect(rankedCategories(u.reversed), rankedCategories(u));
    });
    test('a category with stores always outranks one with none; counts use the shared match rule', () {
      final top = home({'Aardvark': 0, 'Restaurants': 0, 'Zebra': 1});
      expect(top.first, const CategoryCount('Zebra', 1));
      // singular store category still counts for the plural admin category
      final c = allCategoryCounts(['Restaurants'], [store('Restaurant'), store('Restaurant')]);
      expect(c.single, const CategoryCount('Restaurants', 2));
    });
    test('counts follow store changes and zero-store categories appear/disappear from the top 8 accordingly', () {
      final cats = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'];
      var top = topCategoriesByStoreCount(allCategoryCounts(cats, [store('I'), store('I')]));
      // I has stores; the 7 remaining places are filled with zero-store categories, alphabetical.
      expect(names(top), ['I', 'A', 'B', 'C', 'D', 'E', 'F', 'G']);
      expect(top.skip(1).every((c) => c.count == 0), isTrue);   // zero-store categories ARE included to fill the top 8
      expect(names(top).contains('H'), isFalse);                // H (0 stores) is the 9th alphabetically
      top = topCategoriesByStoreCount(allCategoryCounts(cats, [store('H')]));
      expect(top.first, const CategoryCount('H', 1));
      expect(top.length, 8);
    });
    test('usedCategoryCounts (stores only) is unchanged and does not include zero-store categories', () {
      expect(usedCategoryCounts(['Cafe', 'Gym'], [store('Cafe')]), [const CategoryCount('Cafe', 1)]);
    });
    test('inputs are not modified', () {
      final u = allCategoryCounts(['Cafe', 'Gym'], [store('Gym')]);
      final before = List<CategoryCount>.of(u);
      rankedCategories(u);
      topCategoriesByStoreCount(u);
      expect(u, before);
    });
  });
}
