// Default Store Image for a city with no stores (approved enhancement 3). The backend already filters /default-images by country
// (images mapped to the country first, else the "All countries" ones, never another country's); these tests cover what the app does with
// the answer. No network, no real storage.
import 'dart:io';
import 'dart:math' show Random;

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

  group('emptyCityImage: every empty city gets the Default Store Image; service-area registration is not a condition', () {
    test('a successful empty store list with a Default Store Image configured -> the Default Store Image', () {
      expect(emptyCityImage(storeImage: countrySpecific, noServiceImage: noService), countrySpecific);
      expect(emptyCityImage(storeImage: allCountries, noServiceImage: noService), allCountries);
    });

    test('a brand-new city and a city outside the service area get the SAME result: never the No Service Area image', () {
      // The function has no service-area input at all, so a city with no database record and an unregistered city are identical.
      final newCity = emptyCityImage(storeImage: countrySpecific, noServiceImage: noService);
      final outside = emptyCityImage(storeImage: countrySpecific, noServiceImage: noService);
      expect(newCity, countrySpecific);
      expect(outside, newCity);
      expect(newCity, isNot(noService));
    });

    test('no / invalid Default Store Image configured -> the unchanged No Service image fallback', () {
      expect(emptyCityImage(storeImage: '', noServiceImage: noService), noService);
      expect(emptyCityImage(storeImage: 'junk', noServiceImage: noService), noService);
    });

    test('nothing configured -> empty, so the existing plain no-service screen shows', () {
      expect(emptyCityImage(storeImage: '', noServiceImage: ''), '');
    });
  });

  group('several Default Store Images (rotation)', () {
    const a = 'https://cdn.example.com/default/store_a.jpg';
    const b = 'https://cdn.example.com/default/store_b.jpg';
    test('store_images is read in configured order; unusable entries are dropped', () {
      expect(defaultStoreImagesFrom({'store_images': ['', 'junk', a, b], 'store': a, 'country': 'SA'}, expectedCountry: 'SA'), [a, b]);
    });
    test('an older server (only `store`) still works', () {
      expect(defaultStoreImagesFrom({'store': a}), [a]);
      expect(defaultStoreImagesFrom({'store': ['junk', a, b]}), [a, b]);
    });
    test('an answer chosen for another country is not used', () {
      expect(defaultStoreImagesFrom({'store_images': [a], 'country': 'SA'}, expectedCountry: 'IN'), isEmpty);
    });
    test('one image is used as it is; several are picked at random (every one is reachable, never an unknown one)', () {
      expect(pickDefaultStoreImage([]), '');
      expect(pickDefaultStoreImage([a]), a);
      final seen = <String>{};
      final rnd = Random(7);
      for (var i = 0; i < 60; i++) {
        seen.add(pickDefaultStoreImage([a, b], rnd));
      }
      expect(seen, {a, b});
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
      expect(main.contains('if (!_netError && !_isTimeout && !_fetchFailed && emptyImg.isNotEmpty) {'), isTrue); // old screen: errors / no default image
    });

    test('Home reads the store image next to the no-service fields, and replaces it per country', () {
      expect(RegExp(r'defaultStoreImagesFrom\(defaults, expectedCountry: Api\.customerCountry\)').allMatches(main).length, 2,
          reason: '_applyDefaults and _loadNoStoreContent');
      expect(RegExp(r'_defaultStoreImg = pickDefaultStoreImage\(storeImgs\);').allMatches(main).length, 2);
      expect(main.contains('if (_defaultsFuture != null && iso != _defaultsIso) _defaultsFuture = null;'), isTrue);
      expect(main.contains('Api.getDefaultImages(country: iso)'), isTrue);
    });

    test('a Default Store Image that cannot be loaded falls back to the No-Service image', () {
      expect(main.contains('() => _noServiceImg.isNotEmpty ? noServiceImage() : nsFallback()'), isTrue);
    });

    test('Home no longer consults the service area for the empty state (default content for EVERY empty city)', () {
      expect(main.contains('Api.cityInServiceArea'), isFalse);
      expect(main.contains('_cityInServiceArea'), isFalse);
      expect(main.contains('cityInServiceArea:'), isFalse);
      expect(main.contains('emptyCityImage(\n            storeImage: _defaultStoreImg,\n            noServiceImage: _noServiceImg);'), isTrue);
    });

    test('NO replacement screen: the Home body is the normal Home whenever a default store image applies', () {
      expect(main.contains("ValueKey('home_default_content')"), isFalse);          // the Phase-5 replacement layout is gone
      expect(main.contains('(_cityFiltered.isEmpty && _homeDefaultStoreImage.isEmpty)\n                      ? _emptyState()'), isTrue);
      // the bottom navigation stays visible on that Home
      expect(main.contains('_homeDefaultStoreImage.isNotEmpty ||'), isTrue);
    });

    test('the default image goes INSIDE the existing Stores Near You section (same heading), only when its store list is empty', () {
      expect(main.contains('defaultStoreImage: _homeDefaultStoreImage,'), isTrue);
      final i = main.indexOf('if (stores.isEmpty && defaultStoreImage.isNotEmpty) {');
      expect(i > 0, isTrue);
      final seg = main.substring(i, i + 1400);
      expect(seg.contains('title: context.l10n.homeStoresNearTitle'), isTrue);
      expect(seg.contains("ValueKey('home_default_store_image')"), isTrue);
      // the real store content below is untouched
      expect(main.contains('_storeCard(context, filtered[i], cardW)'), isTrue);
    });

    test('every other Home section is still built when the store list is empty (they are not conditional on stores)', () {
      final home = main.substring(main.indexOf('// ══════ 4. STORES NEAR YOU'));
      for (final marker in ['5. PRODUCTS NEAR YOU', '_DiscoverProductsSection(', '6. EXCLUSIVE DEALS', '7. REWARDS', 'CityInfluencersSection(']) {
        expect(home.contains(marker), isTrue, reason: marker);
      }
      final upTo = main.substring(0, main.indexOf('// ══════ 4. STORES NEAR YOU'));
      expect(upTo.contains('2. HERO') && upTo.contains('3. CATEGORIES'), isTrue); // hero / categories blocks precede it, unchanged
    });

    test('a failed load never gets the default image: all three error flags are required to be false', () {
      final i = main.indexOf('String get _homeDefaultStoreImage');
      final seg = main.substring(i, i + 520);
      for (final f in ['!_loading', '!_netError', '!_isTimeout', '!_fetchFailed', '_cityFiltered.isEmpty', 'isUsableImageSource(_defaultStoreImg)']) {
        expect(seg.contains(f), isTrue, reason: f);
      }
    });

    test('API failures keep their own error states: the empty-state branch is only reached after a successful, empty response', () {
      final i = main.indexOf('if (storeList.isEmpty && mounted) {');
      final before = main.substring(0, i);
      expect(before.contains('_fetchFailed = true'), isTrue);
      expect(before.contains('storeFetchError'), isTrue);
      expect(main.contains('if (!_netError && !_isTimeout && !_fetchFailed && emptyImg.isNotEmpty) {'), isTrue); // old screen: errors / no default image
    });

    test('the store listing logic was not changed: stores are still fetched with Api.fetchStores(city: c)', () {
      expect(main.contains('storeList = await Api.fetchStores(city: c);'), isTrue);
      expect(main.contains('if (storeList.isEmpty && mounted) {'), isTrue);
    });
  });
}
