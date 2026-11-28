// The location shown under "Exploring" names the location's OWN country (reverse-geocoded / picked from the country's list), never a
// fixed "India", and a location picked under one account's country does not follow a different account. Registration country and
// physical location are separate: a Saudi / Jordan account physically in India shows an Indian location.
// No network and no real storage (SharedPreferences mock).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/models/offro_location.dart';
import 'package:offro_user/core/services/location_service.dart';
import 'package:offro_user/core/services/location_store.dart';
import 'package:offro_user/core/services/prefs_service.dart';

OffroLocation manual(String city, String state, String country) =>
    OffroLocation(city: city, state: state, country: country, source: LocationSource.manual, updatedAt: DateTime.now());
OffroLocation gps(String city, String state, String country) => OffroLocation(
    city: city, state: state, country: country, lat: 18.52, lng: 73.85, source: LocationSource.gps, updatedAt: DateTime.now());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the subtitle names the location\'s own country', () {
    test('Indian account and Indian location: unchanged ("State, India")', () {
      expect(manual('Pune', 'Maharashtra', 'IN').subtitle, 'Maharashtra, India');
      expect(manual('Pune', '', 'IN').subtitle, 'India');
    });

    test('Saudi account and Saudi location: Riyadh Province, Saudi Arabia (never India)', () {
      final s = manual('Riyadh', 'Riyadh Province', 'SA').subtitle;
      expect(s, 'Riyadh Province, Saudi Arabia');
      expect(s, isNot(contains('India')));
    });

    test('Jordan account and Jordan location', () {
      expect(manual('Amman', 'Amman', 'JO').subtitle, 'Amman, Jordan');
      expect(manual('Zarqa', 'Zarqa Governorate', 'JO').subtitle, 'Zarqa Governorate, Jordan');
    });

    test('Nepal and Philippines use their own country too', () {
      expect(manual('Kathmandu', 'Bagmati Province', 'NP').subtitle, 'Bagmati Province, Nepal');
      expect(manual('Manila', 'Metro Manila', 'PH').subtitle, 'Metro Manila, Philippines');
    });

    test('a country that is not known is not invented: nothing is appended (and never "India")', () {
      expect(manual('Riyadh', 'Riyadh Province', '').subtitle, 'Riyadh Province');
      expect(manual('Riyadh', '', '').subtitle, '');
      expect(manual('Riyadh', 'Riyadh Province', '').subtitle, isNot(contains('India')));
    });

    test('locality / area lines are exactly as before', () {
      expect(const OffroLocation(locality: 'Radio Park', area: 'Cowl Bazaar', city: 'Ballari', state: 'Karnataka', country: 'IN').subtitle,
          'Cowl Bazaar, Ballari, Karnataka');
      expect(const OffroLocation(area: 'Cowl Bazaar', city: 'Ballari', state: 'Karnataka', country: 'IN').subtitle, 'Ballari, Karnataka');
    });

    test('the country name can be shown in the app language', () {
      final s = manual('Riyadh', 'Riyadh Province', 'SA').subtitleFor((iso) => iso == 'SA' ? 'المملكة العربية السعودية' : '');
      expect(s, 'Riyadh Province, المملكة العربية السعودية');
    });

    test('the country survives saving and loading; old saved values without one load as unknown', () {
      final back = OffroLocation.fromJson(manual('Riyadh', 'Riyadh Province', 'sa').toJson())!;
      expect(back.country, 'SA');
      final old = OffroLocation.fromJson({'city': 'Pune', 'state': 'Maharashtra', 'source': 'manual'})!;
      expect(old.country, '');
    });
  });

  group('where a location\'s country comes from', () {
    test('a city picked from the account country\'s list is in that country', () {
      expect(LocationService.countryForSelection('SA', 'Riyadh'), 'SA');
      expect(LocationService.countryForSelection('JO', 'Amman'), 'JO');
      expect(LocationService.countryForSelection('IN', 'Pune'), 'IN');
    });

    test('a guest (no list country): only a city of the bundled India reference is Indian, anything else stays unknown', () {
      expect(LocationService.countryForSelection(null, 'Pune'), 'IN');
      expect(LocationService.countryForSelection(null, 'Riyadh'), '');
    });

    test('a GPS fix takes the verified backend country, else the device geocoder, else unknown - never the account country', () {
      expect(LocationService.fixCountryOf('SA', 'IN'), 'SA');
      expect(LocationService.fixCountryOf('', 'in'), 'IN');
      expect(LocationService.fixCountryOf(null, null), '');
      expect(LocationService.fixCountryOf('  ', ' '), '');
    });

    test('a failed / empty reverse-geocode gives no country, so no country line (never a default India)', () {
      final c = LocationService.fixCountryOf(null, null);
      expect(OffroLocation(city: 'Riyadh', state: 'Riyadh Province', country: c).subtitle, 'Riyadh Province');
    });

    test('the bundled (Indian) state table only fills a state for an Indian or unknown fix', () {
      expect(LocationService.bundledStateAllowedFor('IN'), isTrue);
      expect(LocationService.bundledStateAllowedFor(''), isTrue);
      expect(LocationService.bundledStateAllowedFor('SA'), isFalse);
      expect(LocationService.bundledStateAllowedFor('JO'), isFalse);
    });
  });

  group('a saved location and the signed-in account', () {
    test('Indian account, Indian location: kept', () async {
      await LocationStore.save(LocationMode.customer, manual('Pune', 'Maharashtra', 'IN'));
      final l = await LocationStore.loadForAccount('IN');
      expect(l!.city, 'Pune');
      expect(l.subtitle, 'Maharashtra, India');
    });

    test('Saudi account, Saudi location: kept, shown with Saudi Arabia', () async {
      await LocationStore.save(LocationMode.customer, manual('Riyadh', 'Riyadh Province', 'SA'));
      final l = await LocationStore.loadForAccount('SA');
      expect([l!.city, l.state, l.subtitle], ['Riyadh', 'Riyadh Province', 'Riyadh Province, Saudi Arabia']);
    });

    test('Jordan account, Jordan location: kept', () async {
      await LocationStore.save(LocationMode.customer, manual('Amman', 'Amman', 'JO'));
      expect((await LocationStore.loadForAccount('JO'))!.subtitle, 'Amman, Jordan');
    });

    test('Saudi account physically in India (GPS): the Indian location is kept and shown as India', () async {
      await LocationStore.save(LocationMode.customer, gps('Pune', 'Maharashtra', 'IN'));
      final l = await LocationStore.loadForAccount('SA');
      expect(l, isNotNull);
      expect([l!.city, l.country, l.subtitle], ['Pune', 'IN', 'Maharashtra, India']);
    });

    test('Jordan account physically in India (GPS): the Indian location is kept and shown as India', () async {
      await LocationStore.save(LocationMode.customer, gps('Pune', 'Maharashtra', 'IN'));
      final l = await LocationStore.loadForAccount('JO');
      expect([l!.country, l.subtitle], ['IN', 'Maharashtra, India']);
    });

    test('switching accounts: a location picked under the previous account\'s country is not carried over, in every direction', () async {
      // India -> Saudi account
      await LocationStore.save(LocationMode.customer, manual('Pune', 'Maharashtra', 'IN'));
      expect(await LocationStore.loadForAccount('SA'), isNull);
      expect(await LocationStore.load(), isNull, reason: 'cleared everywhere, the legacy city included');
      expect(await Prefs.getCity(), '');
      // Saudi -> Indian account
      await LocationStore.save(LocationMode.customer, manual('Riyadh', 'Riyadh Province', 'SA'));
      expect(await LocationStore.loadForAccount('IN'), isNull);
      expect(await LocationStore.load(), isNull);
      // Jordan -> Saudi account
      await LocationStore.save(LocationMode.customer, manual('Amman', 'Amman', 'JO'));
      expect(await LocationStore.loadForAccount('SA'), isNull);
      // and the new account picks its own, which then stays
      await LocationStore.save(LocationMode.customer, manual('Jeddah', 'Makkah Province', 'SA'));
      expect((await LocationStore.loadForAccount('SA'))!.city, 'Jeddah');
    });

    test('an Indian location saved by an older build (no country) is still recognised as Indian and still follows the same rules', () async {
      SharedPreferences.setMockInitialValues({
        'offro_location_v2': '{"city":"Pune","state":"Maharashtra","source":"manual","locality":"","area":""}',
      });
      final l = await LocationStore.loadForAccount('IN');
      expect([l!.country, l.subtitle], ['IN', 'Maharashtra, India']);
      expect(await LocationStore.loadForAccount('SA'), isNull); // a Saudi account does not inherit it
    });

    test('a legacy city string alone (no structured value) gets the same treatment', () async {
      SharedPreferences.setMockInitialValues({'city': 'Mumbai'});
      await Prefs.saveCity('Mumbai');
      final l = await LocationStore.load();
      expect(l!.country, 'IN');
      expect(await LocationStore.loadForAccount('JO'), isNull);
    });

    test('a guest or an account whose country is unknown never loses its location, nor does a location whose country is unknown', () async {
      await LocationStore.save(LocationMode.customer, manual('Pune', 'Maharashtra', 'IN'));
      expect(await LocationStore.loadForAccount(null), isNotNull);
      expect(await LocationStore.loadForAccount(''), isNotNull);
      await LocationStore.save(LocationMode.customer, manual('Somewhere', '', ''));
      expect(await LocationStore.loadForAccount('SA'), isNotNull);
    });

    test('staleForAccount: only a picked location of another country', () {
      expect(LocationStore.staleForAccount(manual('Pune', 'M', 'IN'), 'SA'), isTrue);
      expect(LocationStore.staleForAccount(manual('Pune', 'M', 'IN'), 'IN'), isFalse);
      expect(LocationStore.staleForAccount(gps('Pune', 'M', 'IN'), 'SA'), isFalse);
      expect(LocationStore.staleForAccount(manual('X', '', ''), 'SA'), isFalse);
      expect(LocationStore.staleForAccount(manual('Pune', 'M', 'IN'), null), isFalse);
    });
  });
}
