// Influencer profile: which cities are offered for IN, SA, NP and JO, localized labels with English fallback, and clearing an invalid city
// when the country changes. Pure unit tests (no widgets, no network).
// Run:  flutter test test/influencer_city_logic_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/constants/india_locations.dart' show kIndiaStates, kIndiaCities;
import 'package:offro_user/core/models/offro_location.dart';
import 'package:offro_user/core/services/city_list_logic.dart';
import 'package:offro_user/core/services/influencer_city_logic.dart';

/// What GET /cities?country=XX returns (filtered by the server): the payload each country gets.
final Map<String, List> _api = {
  'SA': [
    {'id': '1', 'name': 'Riyadh', 'state': '', 'names': {'ar': 'الرياض'}},
    {'id': '2', 'name': 'Jeddah', 'state': '', 'names': {'ar': 'جدة'}},
    {'id': '3', 'name': 'Madinah', 'state': '', 'names': {}},                        // no Arabic name -> English fallback
  ],
  'NP': [
    {'id': '4', 'name': 'Kathmandu', 'state': 'Bagmati', 'names': {'ar': 'كاتماندو'}},
    {'id': '5', 'name': 'Pokhara', 'state': 'Gandaki', 'names': {}},
  ],
  'JO': [
    {'id': '6', 'name': 'Amman', 'state': 'Amman', 'names': {'ar': 'عمّان'}},
    {'id': '7', 'name': 'Irbid', 'state': 'Irbid', 'names': {'ar': 'إربد'}},
  ],
};

List<SupportedCity> _cities(String country) => parseCityList(_api[country] ?? const [], stateFor: (_) => '');

const _indian = ['Mumbai', 'Delhi', 'New Delhi', 'Hyderabad', 'Bengaluru', 'Chennai', 'Pune'];

void main() {
  group('which country uses the bundled India lists', () {
    test('only India', () {
      for (final c in ['IN', 'in', ' IN ']) {
        expect(influencerUsesIndiaLists(c), isTrue, reason: c);
      }
      for (final c in ['SA', 'NP', 'JO', 'AE', '', null]) {
        expect(influencerUsesIndiaLists(c), isFalse, reason: '$c');
      }
    });

    test('India still has its State -> City lists (unchanged)', () {
      expect(kIndiaStates.contains('Maharashtra'), isTrue);
      expect((kIndiaCities['Maharashtra'] ?? []).contains('Mumbai'), isTrue);
    });
  });

  for (final iso in ['SA', 'NP', 'JO']) {
    group('$iso account', () {
      test('offers only $iso cities - never an Indian city and nothing from the bundled India list', () {
        final choices = influencerCityChoices(_cities(iso), 'en');
        final names = choices.map((c) => c.name).toList();
        expect(names.length, _api[iso]!.length);
        for (final n in _indian) {
          expect(names.contains(n), isFalse, reason: '$iso list must not contain $n');
        }
        final all = kIndiaCities.values.expand((e) => e).toSet();
        expect(names.any(all.contains), isFalse);
      });

      test('English labels in English, Arabic labels in Arabic with an English fallback', () {
        final en = influencerCityChoices(_cities(iso), 'en').map((c) => c.labelFor('en')).toList();
        final ar = influencerCityChoices(_cities(iso), 'ar');
        final arLabels = ar.map((c) => c.labelFor('ar')).toList();
        expect(en, _cities(iso).map((c) => c.name).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
        if (iso == 'SA') {
          expect(arLabels.contains('الرياض'), isTrue);
          expect(arLabels.contains('Madinah'), isTrue);            // no Arabic name: falls back to English
          expect(arLabels.last, 'Madinah');                         // fallbacks sort after the Arabic names
        }
        // the saved value is the English name whatever the label language
        expect(ar.map((c) => c.name).toSet(), _cities(iso).map((c) => c.name).toSet());
      });

      test('a city of another country is not kept; a city of this country is kept (canonical spelling)', () {
        final choices = influencerCityChoices(_cities(iso), 'en');
        expect(keepValidInfluencerCity('Mumbai', choices), isNull);
        final first = _api[iso]!.first['name'] as String;
        expect(keepValidInfluencerCity(first.toLowerCase(), choices), first);
        expect(keepValidInfluencerCity(null, choices), isNull);
        expect(keepValidInfluencerCity('  ', choices), isNull);
      });

      test('the profile state is the City Master state of the chosen city (may be empty)', () {
        final choices = _cities(iso);
        final first = _api[iso]!.first;
        expect(influencerStateFor(first['name'] as String, choices), first['state']);
        expect(influencerStateFor('Nowhere', choices), '');
      });
    });
  }

  group('changing the country', () {
    test('SA -> JO: a Saudi city is cleared, a Jordanian one is kept', () {
      final jo = influencerCityChoices(_cities('JO'), 'en');
      expect(keepValidInfluencerCity('Riyadh', jo), isNull);
      expect(keepValidInfluencerCity('Amman', jo), 'Amman');
    });

    test('NP -> SA: a Nepali city is cleared', () {
      expect(keepValidInfluencerCity('Kathmandu', influencerCityChoices(_cities('SA'), 'en')), isNull);
    });

    test('a country with no cities yet offers nothing (and a selection cannot survive)', () {
      final none = influencerCityChoices(_cities('ZZ'), 'en');
      expect(none.isEmpty, isTrue);
      expect(keepValidInfluencerCity('Riyadh', none), isNull);
    });
  });
}
