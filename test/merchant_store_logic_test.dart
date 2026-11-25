import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/models/offro_location.dart';
import 'package:offro_user/core/services/merchant_store_logic.dart';

void main() {
  const riyadh = SupportedCity(name: 'Riyadh', names: {'ar': 'الرياض'}, isPopular: true, popularOrder: 1);
  const jeddah = SupportedCity(name: 'Jeddah', names: {'ar': 'جدة'});
  const madinah = SupportedCity(name: 'Madinah', isPopular: true, popularOrder: 2);
  const cities = [jeddah, madinah, riyadh];

  group('country of the account', () {
    test('India and unknown accounts keep the existing experience', () {
      expect(isIndiaAccount(null), isTrue);
      expect(isIndiaAccount(''), isTrue);
      expect(isIndiaAccount('in'), isTrue);
      expect(isIndiaAccount('SA'), isFalse);
      expect(storeCountryToSend('IN'), '');
      expect(storeCountryToSend(null), '');
      expect(storeCountryToSend('sa'), 'SA');
    });
  });

  group('a place in another country', () {
    test('is detected only for a supported, different country', () {
      expect(otherCountryOfPlace(placeIso: 'IN', accountIso: 'SA'), 'IN');
      expect(otherCountryOfPlace(placeIso: 'sa', accountIso: 'IN'), 'SA');
      expect(otherCountryOfPlace(placeIso: 'SA', accountIso: 'SA'), isNull);
      expect(otherCountryOfPlace(placeIso: '', accountIso: 'SA'), isNull);
      expect(otherCountryOfPlace(placeIso: 'ZZ', accountIso: 'SA'), isNull);     // unsupported country: nothing assumed
      expect(otherCountryOfPlace(placeIso: 'IN', accountIso: null), isNull);     // account country unknown: nothing blocked
    });
  });

  group('City Master matching', () {
    test('matches by English or Arabic name, ignoring case and spacing', () {
      expect(matchCountryCity('  riyadh ', cities)?.name, 'Riyadh');
      expect(matchCountryCity('الرياض', cities)?.name, 'Riyadh');
      expect(matchCountryCity('Mumbai', cities), isNull);
      expect(matchCountryCity('', cities), isNull);
      expect(matchCountryCity(null, cities), isNull);
    });
    test('suggestions filter by what was typed, popular first, capped', () {
      expect(suggestCountryCities('', cities).map((c) => c.name), ['Riyadh', 'Madinah', 'Jeddah']);
      expect(suggestCountryCities('jed', cities).map((c) => c.name), ['Jeddah']);
      expect(suggestCountryCities('رياض', cities).map((c) => c.name), ['Riyadh']);
      expect(suggestCountryCities('zzz', cities), isEmpty);
      expect(suggestCountryCities('', cities, max: 2).length, 2);
    });
  });

  group('storeCityAcceptable', () {
    test('India / unknown: always, whatever the city', () {
      expect(storeCityAcceptable(city: 'Ballari', accountIso: 'IN', cities: const [], listLoaded: true), isTrue);
      expect(storeCityAcceptable(city: 'Ballari', accountIso: null, cities: cities, listLoaded: true), isTrue);
    });
    test('another country: the city must be in that country list', () {
      expect(storeCityAcceptable(city: 'Riyadh', accountIso: 'SA', cities: cities, listLoaded: true), isTrue);
      expect(storeCityAcceptable(city: 'Mumbai', accountIso: 'SA', cities: cities, listLoaded: true), isFalse);
    });
    test('an unavailable or empty list never blocks (the server decides)', () {
      expect(storeCityAcceptable(city: 'Mumbai', accountIso: 'SA', cities: const [], listLoaded: true), isTrue);
      expect(storeCityAcceptable(city: 'Mumbai', accountIso: 'SA', cities: cities, listLoaded: false), isTrue);
    });
  });
}
