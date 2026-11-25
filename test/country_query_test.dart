import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/services/country_query.dart';

void main() {
  test('country is sent only when known', () {
    expect(countryQueryValue(null), '');
    expect(countryQueryValue(''), '');
    expect(countryQueryValue('Saudi'), '');
    expect(countryQueryValue(' sa '), 'SA');
    expect(withCountryQuery('/deals/all', null), '/deals/all');
  });
  test('appended to a path with or without a query string', () {
    expect(withCountryQuery('/deals/all', 'IN'), '/deals/all?country=IN');
    expect(withCountryQuery('/deals/all?city=Pune', 'in'), '/deals/all?city=Pune&country=IN');
  });
  test('cache keys differ per country', () {
    expect(countryCacheSuffix('SA'), ':SA');
    expect(countryCacheSuffix(null), '');
    expect(countryCacheSuffix('SA') == countryCacheSuffix('IN'), isFalse);
  });
}
