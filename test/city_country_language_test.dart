// Location screen data rules: cities follow the account's country, names follow the app language, selection stays canonical.
// Pure unit tests (no widgets, no network). Run:  flutter test test/city_country_language_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/models/offro_location.dart';
import 'package:offro_user/core/services/api_service.dart';
import 'package:offro_user/core/services/location_service.dart';

void main() {
  group('cityDisplayName / SupportedCity.labelFor', () {
    const riyadh = SupportedCity(name: 'Riyadh', id: 'c1', names: {'ar': 'الرياض'});
    test('English shows the English name', () => expect(riyadh.labelFor('en'), 'Riyadh'));
    test('Arabic shows the Arabic name', () => expect(riyadh.labelFor('ar'), 'الرياض'));
    test('a regional code uses its base language', () {
      expect(riyadh.labelFor('ar-SA'), 'الرياض');
      expect(riyadh.labelFor('AR_sa'), 'الرياض');
    });
    test('a language with no translation falls back to English', () => expect(riyadh.labelFor('kn'), 'Riyadh'));
    test('blank / null language and blank translation fall back to English', () {
      expect(riyadh.labelFor(null), 'Riyadh');
      expect(riyadh.labelFor(''), 'Riyadh');
      expect(const SupportedCity(name: 'Riyadh', names: {'ar': '   '}).labelFor('ar'), 'Riyadh');
    });
    test('Kannada where the city has it', () {
      expect(const SupportedCity(name: 'Mysuru', names: {'kn': 'ಮೈಸೂರು'}).labelFor('kn'), 'ಮೈಸೂರು');
    });
    test('the label never changes the canonical name or id used for selection', () {
      expect(riyadh.labelFor('ar'), isNot(riyadh.name));
      expect(riyadh.name, 'Riyadh');
      expect(riyadh.id, 'c1');
    });
  });

  group('parseCityNames', () {
    test('keeps only non-blank string values, lower-cases codes', () {
      expect(LocationService.parseCityNames({'AR': ' الرياض ', 'kn': '', 'hi': 5, 'x': null}), {'ar': 'الرياض'});
    });
    test('anything else is empty', () {
      expect(LocationService.parseCityNames(null), isEmpty);
      expect(LocationService.parseCityNames('x'), isEmpty);
      expect(LocationService.parseCityNames([1]), isEmpty);
    });
  });

  group('citiesPath (the server filters; the app only asks)', () {
    test('no arguments = the plain request every older build sent', () => expect(Api.citiesPath(), '/cities'));
    test('guest / unknown country sends no country', () => expect(Api.citiesPath(country: '  ', lang: null), '/cities'));
    test('country is upper-cased', () => expect(Api.citiesPath(country: 'sa'), '/cities?country=SA'));
    test('country and language', () => expect(Api.citiesPath(country: 'SA', lang: 'ar'), '/cities?country=SA&lang=ar'));
  });

  group('citiesFor: which list a country gets', () {
    const sa = [SupportedCity(name: 'Riyadh', names: {'ar': 'الرياض'}), SupportedCity(name: 'Jeddah')];
    test('Saudi Arabia gets ONLY its server cities (no India reference data), sorted', () {
      final l = LocationService.citiesFor('SA', sa);
      expect(l.map((c) => c.name), ['Jeddah', 'Riyadh']);
      expect(l.any((c) => c.state.isNotEmpty), isFalse);
    });
    test('another country never gets the bundled India list', () {
      expect(LocationService.citiesFor('JO', const []), isEmpty);
      expect(LocationService.citiesFor('NP', const []), isEmpty);
    });
    test('India gets the bundled reference list merged with its server cities', () {
      final l = LocationService.citiesFor('IN', const [SupportedCity(name: 'Mysuru', id: 'm1', names: {'kn': 'ಮೈಸೂರು'})]);
      expect(l.length, greaterThan(50));
      final m = l.firstWhere((c) => c.name == 'Mysuru');
      expect(m.state, 'Karnataka');                         // state from the bundled data
      expect(m.id, 'm1');                                   // id and translations from the server
      expect(m.labelFor('kn'), 'ಮೈಸೂರು');
      expect(m.labelFor('en'), 'Mysuru');
    });
    test('a guest / unresolved country keeps the long-standing behaviour (India reference)', () {
      expect(LocationService.citiesFor(null, const []).length, greaterThan(50));
      expect(LocationService.citiesFor('', const []).length, greaterThan(50));
      expect(LocationService.usesBundledIndiaReference(null), isTrue);
      expect(LocationService.usesBundledIndiaReference('IN'), isTrue);
      expect(LocationService.usesBundledIndiaReference('SA'), isFalse);
    });
    test('a server city missing from the bundled data is still added for India', () {
      final l = LocationService.citiesFor('IN', const [SupportedCity(name: 'Newtown')]);
      expect(l.any((c) => c.name == 'Newtown'), isTrue);
    });
  });
}
