// Location screen list rules for every country (India, Saudi Arabia, Nepal, Jordan, ...): Popular, All Cities, sorting, language,
// the empty-vs-failed distinction. Pure unit tests (no widgets, no network). Run:  flutter test test/city_list_logic_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/models/offro_location.dart';
import 'package:offro_user/core/services/city_list_logic.dart';

const _metros = ['Mumbai', 'New Delhi', 'Bengaluru', 'Hyderabad', 'Chennai', 'Kolkata', 'Pune'];

List<SupportedCity> _parse(List raw, {String india = ''}) =>
    parseCityList(raw, stateFor: (n) => india.isEmpty ? '' : india);

Map<String, dynamic> _c(String name, {String? ar, String state = '', bool pop = false, int order = 0}) => {
      'id': name, 'name': name, 'state': state, 'is_popular': pop, 'popular_order': order,
      'names': {if (ar != null) 'ar': ar},
    };

List<String> _n(List<SupportedCity> l) => l.map((c) => c.name).toList();

void main() {
  group('parseCityList', () {
    test('reads state, popular flag and order from the server', () {
      final l = _parse([_c('Riyadh', ar: 'الرياض', state: 'Riyadh Region', pop: true, order: 1)]);
      expect(l.single.state, 'Riyadh Region');
      expect(l.single.isPopular, isTrue);
      expect(l.single.popularOrder, 1);
      expect(l.single.labelFor('ar'), 'الرياض');
    });
    test('an older server response without the new fields still parses', () {
      final l = parseCityList([{'id': '1', 'name': 'Pune', 'names': {}}], stateFor: (_) => 'Maharashtra');
      expect(l.single.state, 'Maharashtra');
      expect(l.single.isPopular, isFalse);
      expect(l.single.popularOrder, 0);
    });
    test('same name + same state is one city; same name in different states stays two', () {
      expect(_parse([_c('Udaipur', state: 'Rajasthan'), _c('Udaipur', state: 'Rajasthan')]).length, 1);
      expect(_parse([_c('Udaipur', state: 'Rajasthan'), _c('Udaipur', state: 'Tripura')]).length, 2);
      expect(_parse([_c('Pune'), _c('pune')]).length, 1);     // no state: one per name, as before
    });
    test('blank names and non-maps are skipped', () {
      expect(_parse([_c('  '), 5, null, _c('Jeddah')]).map((c) => c.name), ['Jeddah']);
    });
  });

  group('Popular cities', () {
    final sa = _parse([
      _c('Dammam', pop: true, order: 3), _c('Riyadh', pop: true, order: 1), _c('Jeddah', pop: true, order: 2), _c('Abha'), _c('Tabuk'),
    ]);
    test('Saudi Arabia: flagged cities in popular_order, never more than six', () {
      expect(_n(popularCities(server: sa, shown: sa, legacyIndia: false)), ['Riyadh', 'Jeddah', 'Dammam']);
      final many = _parse([for (var i = 1; i <= 9; i++) _c('C$i', pop: true, order: i)]);
      expect(popularCities(server: many, shown: many, legacyIndia: false).length, 6);
    });
    test('a flagged city with no order sorts after the ordered ones, in server order', () {
      final l = _parse([_c('B', pop: true), _c('A', pop: true, order: 1), _c('C', pop: true)]);
      expect(_n(popularCities(server: l, shown: l, legacyIndia: false)), ['A', 'B', 'C']);
    });
    test('Saudi Arabia / Nepal / Jordan with nothing flagged: no Popular section, no invented cities', () {
      for (final names in [['Riyadh', 'Jeddah'], ['Kathmandu', 'Pokhara'], ['Amman', 'Irbid']]) {
        final l = _parse([for (final n in names) _c(n)]);
        expect(popularCities(server: l, shown: l, legacyIndia: false, metros: _metros), isEmpty);
      }
    });
    test('a country never receives the India metros', () {
      final l = _parse([_c('Kathmandu', pop: true, order: 1)]);
      final shown = [...l, const SupportedCity(name: 'Mumbai')];
      expect(_n(popularCities(server: l, shown: shown, legacyIndia: false, metros: _metros)), ['Kathmandu']);
    });
    test('India legacy rule while nothing is flagged: first six server cities, then the metros', () {
      final server = _parse([_c('Surat'), _c('Jaipur')]);
      final shown = [...server, for (final m in _metros) SupportedCity(name: m, state: 'X')];
      expect(_n(popularCities(server: server, shown: shown, legacyIndia: true, metros: _metros)),
          ['Surat', 'Jaipur', 'Mumbai', 'New Delhi', 'Bengaluru', 'Hyderabad']);
    });
    test('India legacy rule: six server cities need no metros', () {
      final server = _parse([for (var i = 1; i <= 8; i++) _c('S$i')]);
      expect(_n(popularCities(server: server, shown: server, legacyIndia: true, metros: _metros)), ['S1', 'S2', 'S3', 'S4', 'S5', 'S6']);
    });
    test('India: once a city is flagged the flags take over and the legacy top-up stops', () {
      final server = _parse([_c('Surat'), _c('Jaipur', pop: true, order: 1)]);
      final shown = [...server, for (final m in _metros) SupportedCity(name: m, state: 'X')];
      expect(_n(popularCities(server: server, shown: shown, legacyIndia: true, metros: _metros)), ['Jaipur']);
    });
    test('guests (no country) behave as India: legacy rule', () {
      final server = _parse([_c('Surat')]);
      expect(popularCities(server: server, shown: server, legacyIndia: true, metros: const []).length, 1);
    });
    test('the shown entry (state, translations) is preferred for a flagged name', () {
      final server = _parse([_c('Pune', pop: true, order: 1)]);
      final shown = [const SupportedCity(name: 'Pune', state: 'Maharashtra', names: {'ar': 'x'})];
      expect(popularCities(server: server, shown: shown, legacyIndia: true).single.state, 'Maharashtra');
    });
  });

  group('All cities: sorting by the selected language', () {
    final sa = _parse([
      _c('Riyadh', ar: 'الرياض'), _c('Jeddah', ar: 'جدة'), _c('Abha', ar: 'أبها'), _c('Al Khobar', ar: 'الخبر'),
      _c('Dammam', ar: 'الدمام'), _c('Madinah', ar: 'المدينة المنورة'), _c('Tabuk'),
    ]);
    test('English sorts by English name', () {
      expect(_n(sortCitiesForLang(sa, 'en')), ['Abha', 'Al Khobar', 'Dammam', 'Jeddah', 'Madinah', 'Riyadh', 'Tabuk']);
    });
    test('Arabic sorts by the Arabic name; a leading «ال» is ignored; hamza-alef sorts as alef', () {
      // keys: أبها→ابها, جدة→جده, الخبر→خبر, الدمام→دمام, الرياض→رياض, المدينة→مدينه  => ابها < جده < خبر < دمام < رياض < مدينه
      expect(_n(sortCitiesForLang(sa, 'ar')), ['Abha', 'Jeddah', 'Al Khobar', 'Dammam', 'Riyadh', 'Madinah', 'Tabuk']);
    });
    test('a city with no Arabic name uses English and sorts AFTER the Arabic names', () {
      expect(sortCitiesForLang(sa, 'ar').last.name, 'Tabuk');
    });
    test('regional Arabic code behaves as Arabic', () => expect(sortCitiesForLang(sa, 'ar-SA').first.name, 'Abha'));
    test('diacritics, tatweel and alef/yaa/taa-marbuta variants do not change the order', () {
      expect(arabicSortKey('الْمَدِينَة'), arabicSortKey('المدينه'));
      expect(arabicSortKey('أبها'), arabicSortKey('ابها'));
      expect(arabicSortKey('الـرياض'), 'رياض');
      expect(arabicSortKey('على'), arabicSortKey('علي'));
      expect(arabicSortKey('ال'), 'ال');                              // a bare «ال» is not stripped to nothing
    });
    test('sorting does not change the canonical name or id used for selection', () {
      final s = sortCitiesForLang(sa, 'ar');
      expect(s.firstWhere((c) => c.name == 'Riyadh').id, 'Riyadh');
      expect(s.firstWhere((c) => c.name == 'Riyadh').labelFor('ar'), 'الرياض');
    });
    test('ties are stable: same label sorts by English name then state', () {
      final l = [const SupportedCity(name: 'Udaipur', state: 'Tripura'), const SupportedCity(name: 'Udaipur', state: 'Rajasthan')];
      expect(sortCitiesForLang(l, 'en').map((c) => c.state), ['Rajasthan', 'Tripura']);
    });
    test('switching language re-orders the same cities without losing any', () {
      expect(sortCitiesForLang(sa, 'en').length, sortCitiesForLang(sa, 'ar').length);
      expect(_n(sortCitiesForLang(sa, 'en')).toSet(), _n(sortCitiesForLang(sa, 'ar')).toSet());
    });
  });

  group('Regression: India, Saudi Arabia, Nepal, Jordan', () {
    test('India: Hindi/Kannada (no Arabic) sorts by the shown label like before', () {
      final l = [const SupportedCity(name: 'Mysuru', names: {'kn': 'ಮೈಸೂರು'}), const SupportedCity(name: 'Bengaluru', names: {'kn': 'ಬೆಂಗಳೂರು'})];
      expect(_n(sortCitiesForLang(l, 'kn')), ['Bengaluru', 'Mysuru']);
    });
    test('Nepal and Jordan: English-only names sort in English under Arabic UI too', () {
      final np = _parse([_c('Pokhara'), _c('Kathmandu'), _c('Biratnagar')]);
      expect(_n(sortCitiesForLang(np, 'ar')), ['Biratnagar', 'Kathmandu', 'Pokhara']);
      final jo = _parse([_c('Irbid', ar: 'إربد'), _c('Amman', ar: 'عمّان'), _c('Zarqa', ar: 'الزرقاء')]);
      expect(_n(sortCitiesForLang(jo, 'ar')), ['Irbid', 'Zarqa', 'Amman']);   // اربد < زرقاء < عمان
    });
  });
}
