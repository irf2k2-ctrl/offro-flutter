// lib/core/services/location_service.dart
// OFFRO — the ONE place that talks to Geolocator / geocoding.
//
// Device Location Services (the OS master switch) and the OffrO app
// permission are different things and are reported separately.
//
// Rule: nothing in here requests the permission by itself. Only
// [requestPermission] does, and callers invoke it ONLY from an explicit user
// tap. [silentPosition] never prompts.

import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/india_locations.dart';
import '../models/offro_location.dart';
import 'api_service.dart';

enum LocationAccess {
  /// Device Location Services (master switch) are OFF.
  serviceOff,
  /// Services ON, OffrO permission not granted (can still be requested).
  permissionDenied,
  /// Services ON, OffrO permission permanently denied → app settings.
  permissionDeniedForever,
  /// Services ON and permission granted.
  ready,
}

class LocationService {
  LocationService._();

  // ── Access state ────────────────────────────────────────────────────────
  static Future<LocationAccess> status() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        return LocationAccess.ready;
      }
      if (perm == LocationPermission.deniedForever) return LocationAccess.permissionDeniedForever;
      return LocationAccess.permissionDenied;
    } catch (_) {
      return LocationAccess.permissionDenied;
    }
  }

  /// Fires whenever the device Location Services switch changes.
  static Stream<ServiceStatus> get serviceStatusStream =>
      Geolocator.getServiceStatusStream();

  /// Asks for the OffrO location permission. MUST only be called from an
  /// explicit user action. Returns the state AFTER the attempt.
  ///
  /// Services OFF is reported as [LocationAccess.serviceOff] without asking
  /// (the OS cannot grant anything while the master switch is off).
  /// `denied` AND `unableToDetermine` are both treated as requestable.
  /// If the OS returns "still denied" instantly (no dialog was shown — the
  /// OS has silently stopped prompting) the result is escalated to
  /// [LocationAccess.permissionDeniedForever] so the UI sends the user to
  /// App Settings instead of looking dead.
  static Future<LocationAccess> requestPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.unableToDetermine) {
        final t0 = DateTime.now();
        perm = await Geolocator.requestPermission();
        final instant = DateTime.now().difference(t0) < const Duration(milliseconds: 350);
        if (perm == LocationPermission.denied && instant) {
          return LocationAccess.permissionDeniedForever;
        }
      }
    } catch (_) {}
    return status();
  }

  static Future<void> openDeviceLocationSettings() async {
    try {
      final ok = await Geolocator.openLocationSettings();
      if (!ok) await Geolocator.openAppSettings();
    } catch (_) {}
  }

  static Future<void> openAppSettings() async {
    try { await Geolocator.openAppSettings(); } catch (_) {}
  }

  // ── Position ────────────────────────────────────────────────────────────
  /// Reads GPS ONLY if services are on AND permission is already granted.
  /// Never shows a permission dialog. Returns null otherwise / on failure.
  static Future<Position?> silentPosition({
    Duration timeout = const Duration(seconds: 8),
    LocationAccuracy accuracy = LocationAccuracy.medium,
  }) async {
    try {
      if (await status() != LocationAccess.ready) return null;
      return await Geolocator.getCurrentPosition(desiredAccuracy: accuracy).timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  // ── Supported cities ────────────────────────────────────────────────────
  /// Cities OffrO currently supports (GET /cities, admin-managed).
  /// Returns an empty list when the request fails.
  static Future<List<SupportedCity>> fetchSupportedCities() async {
    try {
      final raw = await Api.getCities().timeout(const Duration(seconds: 10));
      final out = <SupportedCity>[];
      final seen = <String>{};
      for (final c in raw) {
        if (c is! Map) continue;
        final name = (c['name'] ?? '').toString().trim();
        if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
        out.add(SupportedCity(name: name, state: stateForCity(name)));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static bool isSupported(String city, List<SupportedCity> supported) {
    final c = city.trim().toLowerCase();
    if (c.isEmpty) return false;
    return supported.any((s) => s.name.toLowerCase() == c);
  }

  /// State for a city name, from the bundled India reference data.
  static String stateForCity(String city) {
    final c = city.trim().toLowerCase();
    if (c.isEmpty) return '';
    for (final e in kIndiaCities.entries) {
      if (e.value.any((n) => n.toLowerCase() == c)) return e.key;
    }
    return '';
  }

  // ── All Indian cities (customer manual selection) ──────────────────────
  /// Every city in the bundled India reference data ([kIndiaCities]), each
  /// carrying ITS OWN state (so duplicate names such as Udaipur stay
  /// distinct), plus any OffrO-supported city missing from that data.
  static List<SupportedCity> allIndiaCities(List<SupportedCity> supported) {
    final out = <SupportedCity>[];
    final seen = <String>{};
    kIndiaCities.forEach((state, cities) {
      for (final c in cities) {
        if (seen.add('${c.toLowerCase()}|${state.toLowerCase()}')) {
          out.add(SupportedCity(name: c, state: state));
        }
      }
    });
    for (final s in supported) {
      final exists = out.any((o) => o.name.toLowerCase() == s.name.toLowerCase());
      if (!exists) out.add(s);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  // ── Fresh GPS fix ───────────────────────────────────────────────────────
  /// Accept immediately at/below this horizontal accuracy (metres).
  static const double goodAccuracyM = 100;
  /// After [_settleWindow], accept the best fix if at/below this.
  static const double usableAccuracyM = 500;
  /// At [_hardLimit], accept the best fix only if at/below this (city-level).
  static const double lastResortAccuracyM = 1000;
  static const Duration _settleWindow = Duration(seconds: 10);
  static const Duration _hardLimit = Duration(seconds: 18);
  static const Duration _maxFixAge = Duration(seconds: 15);

  /// Acquires a FRESH, accurate position. Never prompts: returns null unless
  /// services are on and permission is already granted.
  ///
  /// Uses a high-accuracy position stream (not a single cached
  /// getCurrentPosition): stale fixes are ignored, the first fix within
  /// [goodAccuracyM] wins, otherwise the best fix seen is kept and a better
  /// one is awaited up to the time window. Returns null on timeout / weak
  /// signal.
  static Future<Position?> acquireFix() async {
    if (await status() != LocationAccess.ready) return null;
    final done = Completer<Position?>();
    Position? best;
    StreamSubscription<Position>? sub;
    Timer? settle;
    Timer? hard;

    void finish(Position? p) {
      if (done.isCompleted) return;
      settle?.cancel();
      hard?.cancel();
      sub?.cancel();
      done.complete(p);
    }

    try {
      sub = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
        ),
      ).listen((p) {
        final DateTime? t = p.timestamp;
        if (t != null && DateTime.now().difference(t) > _maxFixAge) return; // stale/cached
        if (best == null || p.accuracy < best!.accuracy) best = p;
        if (p.accuracy <= goodAccuracyM) finish(p);
      }, onError: (_) => finish(null), cancelOnError: true);
    } catch (_) {
      return null;
    }

    settle = Timer(_settleWindow, () {
      final b = best;
      if (b != null && b.accuracy <= usableAccuracyM) finish(b);
    });
    hard = Timer(_hardLimit, () {
      final b = best;
      finish(b != null && b.accuracy <= lastResortAccuracyM ? b : null);
    });
    return done.future;
  }

  // ── Reverse geocode an ACCEPTED fix → structured OffroLocation ─────────
  // Common alternate spellings → the name used in OffrO / India data. Exact
  // synonyms only; never a "closest supported city" guess.
  static const Map<String, String> _alias = {
    'bangalore': 'Bengaluru', 'bangalore urban': 'Bengaluru', 'bengaluru urban': 'Bengaluru',
    'bengaluru rural': 'Bengaluru', 'bellary': 'Ballari', 'mysore': 'Mysuru',
    'mangalore': 'Mangaluru', 'belgaum': 'Belagavi', 'gulbarga': 'Kalaburagi',
    'bijapur': 'Vijayapura', 'shimoga': 'Shivamogga', 'tumkur': 'Tumakuru',
    'gurgaon': 'Gurugram', 'bombay': 'Mumbai', 'madras': 'Chennai', 'calcutta': 'Kolkata',
    'poona': 'Pune', 'trivandrum': 'Thiruvananthapuram', 'cochin': 'Kochi',
    'allahabad': 'Prayagraj', 'benares': 'Varanasi', 'vizag': 'Visakhapatnam',
    'baroda': 'Vadodara', 'pondicherry': 'Puducherry', 'new delhi': 'New Delhi',
    'delhi': 'Delhi', 'north delhi': 'Delhi', 'south delhi': 'Delhi',
    'east delhi': 'Delhi', 'west delhi': 'Delhi', 'central delhi': 'Delhi',
  };

  static String _canon(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return '';
    return _alias[r.toLowerCase()] ?? r;
  }

  static bool _isKnownCity(String city, List<SupportedCity> supported) {
    final c = city.toLowerCase();
    if (c.isEmpty) return false;
    if (supported.any((s) => s.name.toLowerCase() == c)) return true;
    for (final e in kIndiaCities.values) {
      if (e.any((n) => n.toLowerCase() == c)) return true;
    }
    return false;
  }

  /// Reverse-geocodes [pos]. The device geocoder (fast, no network round-trip
  /// to a rate-limited service) is tried first; the backend (Nominatim) runs
  /// in parallel and is used when the device geocoder gives no city, or to
  /// fill area/state when it agrees on the city. Cities are only normalised by
  /// exact synonym — an unrecognised or disagreeing city is never swapped for
  /// a nearby supported one. Returns null if no city could be determined.
  static Future<OffroLocation?> resolveFix(Position pos, List<SupportedCity> supported) async {
    String s(Object? v) => (v ?? '').toString().trim();

    final backendFuture = () async {
      try {
        final r = await Api.reverseGeocode(pos.latitude, pos.longitude)
            .timeout(const Duration(seconds: 8));
        return r['error'] == null ? r : <String, dynamic>{};
      } catch (_) {
        return <String, dynamic>{};
      }
    }();

    Placemark? pm;
    try {
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude)
          .timeout(const Duration(seconds: 5));
      if (marks.isNotEmpty) pm = marks.first;
    } catch (_) {}

    final pmCity = _canon(s(pm?.locality).isNotEmpty ? s(pm?.locality) : s(pm?.subAdministrativeArea));
    final pmArea = s(pm?.subLocality);
    final pmThorough = s(pm?.thoroughfare);
    final pmState = s(pm?.administrativeArea);

    // If the device geocoder produced a recognised city we do not need to wait
    // long for the backend; otherwise wait for it.
    final pmKnownEarly = pmCity.isNotEmpty && _isKnownCity(pmCity, supported);
    final backend = await backendFuture.timeout(
      Duration(seconds: pmKnownEarly ? 2 : 8),
      onTimeout: () => <String, dynamic>{},
    );
    final bCity = _canon(s(backend['city']));
    final bArea = s(backend['area']);
    final bState = s(backend['state']);

    String city = '';
    if (pmCity.isNotEmpty && bCity.isNotEmpty && pmCity.toLowerCase() != bCity.toLowerCase()) {
      // Sources disagree → keep the one that is a recognised Indian city;
      // if both or neither are, trust the device geocoder.
      final pmKnown = _isKnownCity(pmCity, supported);
      final bKnown = _isKnownCity(bCity, supported);
      city = (!pmKnown && bKnown) ? bCity : pmCity;
    } else {
      city = pmCity.isNotEmpty ? pmCity : bCity;
    }
    if (city.isEmpty) return null;

    final agrees = bCity.toLowerCase() == city.toLowerCase();
    final pmAgrees = pmCity.toLowerCase() == city.toLowerCase();
    final area = pmAgrees && pmArea.isNotEmpty ? pmArea : (agrees ? bArea : '');
    String locality = '';
    if (pmAgrees && pmThorough.isNotEmpty && pmThorough.toLowerCase() != area.toLowerCase()) {
      locality = pmThorough;
    }

    var state = agrees && bState.isNotEmpty ? bState : (pmAgrees ? pmState : '');
    if (state.isEmpty) state = stateForCity(city);

    return OffroLocation(
      locality: locality,
      area: area,
      city: city,
      state: state,
      lat: pos.latitude,
      lng: pos.longitude,
      source: LocationSource.gps,
      updatedAt: DateTime.now(),
    );
  }
}
