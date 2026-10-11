// lib/core/services/location_store.dart
// OFFRO — persistence for the structured location.
//
// Customer and Merchant locations are stored under SEPARATE keys: a
// merchant's account location must never change the customer's browsing
// city (the same device can switch modes). Merchant location is device-only;
// it is never sent to the server and never touches the merchant's
// registered store address.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/offro_location.dart';
import 'location_service.dart';
import 'prefs_service.dart';

enum LocationMode { customer, merchant }

class LocationStore {
  LocationStore._();

  static String _key(LocationMode m) => 'offro_location_${m.name}_v1';

  /// Saved location for [mode], or null when none has been chosen yet.
  /// Customer mode migrates a legacy city-only value (Prefs city) once.
  static Future<OffroLocation?> load(LocationMode mode) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key(mode));
      if (raw != null && raw.isNotEmpty) {
        final loc = OffroLocation.fromJson(json.decode(raw));
        if (loc != null) return loc;
      }
    } catch (_) {}
    if (mode == LocationMode.customer) {
      final legacy = (await Prefs.getCity()).trim();
      if (legacy.isNotEmpty) {
        final loc = OffroLocation(
          city: legacy,
          state: LocationService.stateForCity(legacy),
          source: LocationSource.manual,
          updatedAt: DateTime.now(),
        );
        await save(LocationMode.customer, loc);
        return loc;
      }
    }
    return null;
  }

  static Future<void> save(LocationMode mode, OffroLocation loc) async {
    if (!loc.hasCity) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key(mode), json.encode(loc.toJson()));
    } catch (_) {}
    if (mode == LocationMode.customer) {
      // Keep the legacy city key in sync (splash restore etc. read it).
      await Prefs.saveCity(loc.city);
      if (loc.source == LocationSource.gps && loc.lat != null && loc.lng != null) {
        await Prefs.saveLocation(loc.lat!, loc.lng!);
      }
    }
  }
}
