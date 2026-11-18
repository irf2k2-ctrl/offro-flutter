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
}
