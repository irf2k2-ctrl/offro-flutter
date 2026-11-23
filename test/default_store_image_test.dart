// Default Store Image for a city with no stores (approved enhancement 3). The backend already filters /default-images by country
// (images mapped to the country first, else the "All countries" ones, never another country's); these tests cover what the app does with
// the answer. No network, no real storage.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/services/api_service.dart';
import 'package:offro_user/core/services/default_store_image.dart';

const countrySpecific = 'https://cdn.example.com/default/store_sa.jpg';
const allCountries = 'https://cdn.example.com/default/store_all.jpg';
const noService = 'https://cdn.example.com/default/no_service.jpg';

void main() {
  group('defaultStoreImageFrom (what the app reads from /default-images)', () {
    test('a country-specific image chosen by the server is used', () {
      expect(
          defaultStoreImageFrom({'store': countrySpecific, 'country': 'SA', 'country_specific': {'store': true}},
              expectedCountry: 'SA'),
          countrySpecific);
    });

    test('an "All countries" image (server fallback when nothing is mapped to the country) is used', () {
      expect(defaultStoreImageFrom({'store': allCountries, 'country': 'IN', 'country_specific': {}}, expectedCountry: 'IN'),
          allCountries);
      // A guest has no country: the server then returns only the All-countries images and an empty `country`.
      expect(defaultStoreImageFrom({'store': allCountries, 'country': ''}), allCountries);
      expect(defaultStoreImageFrom({'store': allCountries}, expectedCountry: 'IN'), allCountries,
          reason: 'an answer from an older server (no `country` key) only ever holds unmapped images');
    });

    test('no store image configured -> empty', () {
      expect(defaultStoreImageFrom({'store': '', 'country': 'IN'}, expectedCountry: 'IN'), '');
      expect(defaultStoreImageFrom({'country': 'IN'}, expectedCountry: 'IN'), '');
      expect(defaultStoreImageFrom({'store': null}), '');
      expect(defaultStoreImageFrom({}), '');
    });

    test('invalid values are ignored', () {
      for (final bad in ['not a url', 'ftp://x/y.jpg', 'javascript:alert(1)', '   ', 'data:video/mp4;base64,AAAA', 5, true]) {
        expect(defaultStoreImageFrom({'store': bad}), '', reason: '$bad');
      }
      expect(defaultStoreImageFrom({'store': ['', 'junk', countrySpecific, allCountries]}), countrySpecific);
      expect(defaultStoreImageFrom({'store': ' $allCountries '}), allCountries);
      expect(defaultStoreImageFrom({'store': 'data:image/png;base64,AAAA'}), 'data:image/png;base64,AAAA');
    });

    test('an answer chosen for ANOTHER country is never used (cached payload / account switch)', () {
      expect(defaultStoreImageFrom({'store': countrySpecific, 'country': 'SA'}, expectedCountry: 'IN'), '');
      expect(defaultStoreImageFrom({'store': countrySpecific, 'country': 'SA'}), '');
      expect(defaultStoreImageFrom({'store': countrySpecific, 'country': 'sa'}, expectedCountry: ' SA '), countrySpecific);
    });
  });

  group('emptyCityImage (which picture a city without stores gets)', () {
    test('Default Store Image configured -> it replaces the No-Service image', () {
      expect(emptyCityImage(storeImage: countrySpecific, noServiceImage: noService), countrySpecific);
      expect(emptyCityImage(storeImage: allCountries, noServiceImage: noService), allCountries);
    });

    test('no / invalid Default Store Image -> the existing No-Service image', () {
      expect(emptyCityImage(storeImage: '', noServiceImage: noService), noService);
      expect(emptyCityImage(storeImage: 'junk', noServiceImage: noService), noService);
    });

    test('neither -> empty, so the existing plain No-Service screen shows', () {
      expect(emptyCityImage(storeImage: '', noServiceImage: ''), '');
    });
  });

  group('the Default Store Image follows the country (prefetch / cache)', () {
    tearDown(() {
      Api.customerCountry = null;
      Api.takePrefetchedDefaults();
    });

    test('the request carries the account country; a guest sends none', () {
      expect(Api.defaultImagesPath('SA'), '/default-images?country=SA');
      expect(Api.defaultImagesPath(''), '/default-images');
      Api.customerCountry = 'IN';
      expect(Api.defaultImagesPath(), '/default-images?country=IN');
    });

    test('a prefetch made for another country is not handed to Home', () {
      Future<Map<String, dynamic>> f() async => {'store': allCountries};
      Api.debugSetPrefetchedDefaults(f(), country: 'IN');
      expect(Api.takePrefetchedDefaults(country: 'SA'), isNull, reason: 'prefetched for IN, Home now needs SA');
      Api.debugSetPrefetchedDefaults(f(), country: 'IN');
      expect(Api.takePrefetchedDefaults(country: 'in'), isNotNull);
      Api.debugSetPrefetchedDefaults(f(), country: '');
      expect(Api.takePrefetchedDefaults(country: ''), isNotNull, reason: 'a guest prefetch serves a guest');
      Api.debugSetPrefetchedDefaults(f(), country: 'IN');
      expect(Api.takePrefetchedDefaults(), isNotNull, reason: 'older callers (no country) behave as before');
      expect(Api.takePrefetchedDefaults(), isNull, reason: 'one-shot');
    });
  });

  group('Home wiring (the store listing and the error states are untouched)', () {
    final main = File('lib/main.dart').readAsStringSync();

    test('the image block is reached only without network error, timeout or failed load', () {
      expect(main.contains('if (!_netError && !_isTimeout && !_fetchFailed && emptyImg.isNotEmpty) {'), isTrue);
    });

    test('Home reads the store image next to the no-service fields, and replaces it per country', () {
      expect(RegExp(r'defaultStoreImageFrom\(defaults, expectedCountry: Api\.customerCountry\)').allMatches(main).length, 2,
          reason: '_applyDefaults and _loadNoStoreContent');
      expect(main.contains('_defaultStoreImg = storeImg;'), isTrue);
      expect(main.contains('if (_defaultsFuture != null && iso != _defaultsIso) _defaultsFuture = null;'), isTrue);
      expect(main.contains('Api.getDefaultImages(country: iso)'), isTrue);
    });

    test('a Default Store Image that cannot be loaded falls back to the No-Service image', () {
      expect(main.contains('() => _noServiceImg.isNotEmpty ? noServiceImage() : nsFallback()'), isTrue);
    });

    test('the store listing logic was not changed: stores are still fetched with Api.fetchStores(city: c)', () {
      expect(main.contains('storeList = await Api.fetchStores(city: c);'), isTrue);
      expect(main.contains('if (storeList.isEmpty && mounted) {'), isTrue);
    });
  });
}
