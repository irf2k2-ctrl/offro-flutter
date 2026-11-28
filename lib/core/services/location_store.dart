// lib/core/services/location_store.dart
// OFFRO — persistence for the structured location.
//
// ONE shared selected location for the whole app/device. Customer and
// Merchant modes read and write the SAME value, so switching roles on a
// device never shows a different city. It is only the app/device browsing
// location: it is never sent to the server from here and never touches a
// merchant's registered store address / store city / lat / lng.
//
// [LocationMode] is kept only so call sites say which role is acting; it no
// longer selects a storage key.
//
// Migration (first load after upgrade): shared key → previous customer key →
// previous merchant key → legacy Prefs city.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/india_locations.dart';
import '../models/offro_location.dart';
import 'location_service.dart';
import 'prefs_service.dart';

enum LocationMode { customer, merchant }

class LocationStore {
  LocationStore._();

  static const String _sharedKey = 'offro_location_v2';
  static const String _oldCustomerKey = 'offro_location_customer_v1';
  static const String _oldMerchantKey = 'offro_location_merchant_v1';

  static OffroLocation? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return OffroLocation.fromJson(json.decode(raw));
    } catch (_) {
      return null;
    }
  }

  /// A location saved before locations carried a country gets one ONLY when it is certain: a city (or state) of the bundled India
  /// reference is Indian. Anything else stays unknown ('') - no country is ever guessed from the account.
  static OffroLocation _withKnownCountry(OffroLocation loc) {
    if (loc.country.isNotEmpty) return loc;
    final inIndia = LocationService.bundledCountryForCity(loc.city).isNotEmpty || kIndiaCities.containsKey(loc.state.trim());
    return inIndia ? loc.copyWith(country: LocationService.bundledReferenceCountry) : loc;
  }

  /// True when [loc] is a location the user PICKED (manual) while another country's account was signed in: it must not follow a
  /// different account (logout / login, switching accounts). A GPS location describes where the device physically is, so it is kept
  /// whatever the account's country is; so is a location whose country is not known.
  static bool staleForAccount(OffroLocation loc, String? accountCountry) {
    final acct = (accountCountry ?? '').trim().toUpperCase();
    final locCountry = loc.country.trim().toUpperCase();
    if (acct.isEmpty || locCountry.isEmpty) return false;
    return loc.source == LocationSource.manual && locCountry != acct;
  }

  /// [load], except that a manual location chosen under another country's account is forgotten (and the caller gets null, so the
  /// user is asked to choose again). [accountCountry] null (guest / unknown) never discards anything.
  static Future<OffroLocation?> loadForAccount(String? accountCountry, [LocationMode? mode]) async {
    final loc = await load(mode);
    if (loc != null && staleForAccount(loc, accountCountry)) {
      await clear();
      return null;
    }
    return loc;
  }

  /// Forgets the saved location everywhere it is kept (shared value, the two pre-merge values and the legacy city).
  static Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_sharedKey);
      await p.remove(_oldCustomerKey);
      await p.remove(_oldMerchantKey);
    } catch (_) {}
    await Prefs.clearCity();
  }

  /// The shared saved location, or null when none has been chosen yet.
  static Future<OffroLocation?> load([LocationMode? mode]) async {
    final loc = await _load(mode);
    return loc == null ? null : _withKnownCountry(loc);
  }

  static Future<OffroLocation?> _load([LocationMode? mode]) async {
    try {
      final p = await SharedPreferences.getInstance();
      final shared = _parse(p.getString(_sharedKey));
      if (shared != null) return shared;

      // One-time migration: prefer the most recently updated old value.
      final c = _parse(p.getString(_oldCustomerKey));
      final m = _parse(p.getString(_oldMerchantKey));
      OffroLocation? pick;
      if (c != null && m != null) {
        final ct = c.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final mt = m.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        pick = mt.isAfter(ct) ? m : c;
      } else {
        pick = c ?? m;
      }
      if (pick != null) {
        await save(mode ?? LocationMode.customer, pick);
        return pick;
      }
    } catch (_) {}

    final legacy = (await Prefs.getCity()).trim();
    if (legacy.isNotEmpty) {
      final loc = OffroLocation(
        city: legacy,
        state: LocationService.stateForCity(legacy),
        source: LocationSource.manual,
        updatedAt: DateTime.now(),
      );
      await save(mode ?? LocationMode.customer, loc);
      return loc;
    }
    return null;
  }

  /// Saves [loc] as THE shared location (both roles).
  static Future<void> save(LocationMode mode, OffroLocation loc) async {
    if (!loc.hasCity) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_sharedKey, json.encode(loc.toJson()));
    } catch (_) {}
    // Keep the legacy device keys in sync (splash restore, loading screen).
    await Prefs.saveCity(loc.city);
    if (loc.source == LocationSource.gps && loc.lat != null && loc.lng != null) {
      await Prefs.saveLocation(loc.lat!, loc.lng!);
    }
  }
}
