// lib/screens/loading/location_loading_screen.dart
// OFFRO — Premium store-loading screen.
//
// PURE LOADER: it receives an already-chosen [city] (from the saved location
// or the Location screen), fetches that city's stores with retry, then calls
// [onReady]. It does NO location selection, permission handling or GPS city
// detection — that lives in LocationScreen / LocationService. Live GPS is
// read only SILENTLY (when the permission is already granted) to improve
// distance sorting, and never changes the city.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/geo.dart';
import '../../core/services/api_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/prefs_service.dart';

typedef OnReadyCallback = void Function({
  required String city,
  required List<Map<String, dynamic>> stores,
  required double? lat,
  required double? lng,
  // true when the store request FAILED (so `stores` is empty because nothing
  // could be loaded, not because the city genuinely has no stores).
  bool fetchFailed,
});

class LocationLoadingScreen extends StatefulWidget {
  final String token, name, phone, userId;
  final String city;
  final OnReadyCallback onReady;

  const LocationLoadingScreen({
    super.key,
    required this.token,
    required this.name,
    required this.phone,
    required this.userId,
    required this.city,
    required this.onReady,
  });

  @override
  State<LocationLoadingScreen> createState() => _LocationLoadingScreenState();
}

class _LocationLoadingScreenState extends State<LocationLoadingScreen>
    with TickerProviderStateMixin {

  int _step = 0;
  final List<String> _stepLabels = [
    "Locating your position...",
    "Finding nearby deals...",
    "Checking local stores...",
    "Loading today's offers...",
  ];
  final List<IconData> _stepIcons = [
    Icons.location_on_outlined,
    Icons.search_rounded,
    Icons.storefront_outlined,
    Icons.local_offer_outlined,
  ];

  late AnimationController _dotCtrl;
  Timer? _stepTimer;
  late AnimationController _pinPulse;
  late Animation<double> _pinScale;
  late Animation<double> _ringOpacity;
  late Animation<double> _ringScale;
  late AnimationController _fadeCtrl;
  late Animation<double> _screenFade;

  String _statusText = "Locating your position...";
  bool _done = false;
  double? _lat, _lng;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _screenFade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);

    _pinPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _pinScale = Tween<double>(begin: 0.92, end: 1.08).animate(
        CurvedAnimation(parent: _pinPulse, curve: Curves.easeInOut));
    _ringOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
        CurvedAnimation(parent: _pinPulse, curve: Curves.easeOut));
    _ringScale = Tween<double>(begin: 1.0, end: 2.2).animate(
        CurvedAnimation(parent: _pinPulse, curve: Curves.easeOut));

    _startStepTimer();
    _doLoad();
  }

  void _startStepTimer() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted || _done) return;
      setState(() {
        _step = (_step + 1) % _stepLabels.length;
        _statusText = _stepLabels[_step];
      });
    });
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _pinPulse.dispose();
    _fadeCtrl.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _doLoad() async {
    try {
      // Last known physical coordinates → instant distance sorting.
      final savedLoc = await Prefs.getSavedLocation();
      if (savedLoc != null) {
        _lat = savedLoc["lat"];
        _lng = savedLoc["lng"];
      }
      // Live GPS runs in the background ONLY if permission is already granted
      // (never prompts) and only refreshes coordinates — never the city.
      final gpsFuture = _silentGps();
      await _fetchAndGo(widget.city, _lat, _lng, backgroundGps: gpsFuture);
    } catch (e) {
      debugPrint("[LocationLoading] _doLoad fatal error: $e");
      // Open Home with the chosen city so the person is never stuck.
      if (!mounted) return;
      widget.onReady(
        city: widget.city,
        stores: const [],
        lat: _lat,
        lng: _lng,
        fetchFailed: true, // nothing was loaded — not a genuinely empty city
      );
    }
  }

  Future<Map<String, dynamic>?> _silentGps() async {
    final pos = await LocationService.silentPosition(timeout: const Duration(seconds: 6));
    if (pos == null) return null;
    _lat = pos.latitude;
    _lng = pos.longitude;
    await Prefs.saveLocation(_lat!, _lng!);
    return {"lat": _lat, "lng": _lng};
  }

  Future<void> _fetchAndGo(String city, double? lat, double? lng, {Future<Map<String,dynamic>?>? backgroundGps}) async {
    try {
    if (!mounted) return;
    setState(() => _statusText = "Finding deals in $city...");

    List<Map<String, dynamic>> stores = [];
    // Stays false unless a store request actually succeeded. A successful
    // response with zero stores sets it true (genuinely empty city); three
    // failed attempts leave it false so Home can show an error + Retry
    // instead of "no stores".
    bool fetchOk = false;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        if (attempt > 1) {
          await Future.delayed(const Duration(seconds: 2));
          Api.clearCache();
        }
        final raw = await Api.fetchStores(city: city);
        stores = List<Map<String, dynamic>>.from(raw);
        fetchOk = true;
        debugPrint("[LoadingScreen] Loaded ${stores.length} stores for $city (attempt $attempt)");
        break;
      } on SocketException {
        debugPrint("[LoadingScreen] Network error on attempt $attempt");
      } on TimeoutException {
        debugPrint("[LoadingScreen] Timeout on attempt $attempt");
        Api.clearCache();
      } catch (e) {
        debugPrint("[LoadingScreen] Error on attempt $attempt: $e");
      }
    }

    // Compute distances using proper haversine
    if (lat != null && lng != null) {
      for (final s in stores) {
        final slat = double.tryParse(s["latitude"]?.toString() ?? "");
        final slng = double.tryParse(s["longitude"]?.toString() ?? "");
        if (slat != null && slng != null) {
          s["distance_km"] = haversineKm(lat, lng, slat, slng);
        }
      }
      stores.sort((a, b) =>
          ((a["distance_km"] as double?) ?? 9999.0)
          .compareTo((b["distance_km"] as double?) ?? 9999.0));
    }

    // ── Wait for live GPS (up to 8s) before calling onReady ──
    // This ensures distance_km is computed with real GPS, not cached/null coords
    if (backgroundGps != null) {
      try {
        final gpsResult = await backgroundGps.timeout(const Duration(seconds: 8));
        if (gpsResult != null) {
          final gpsLat = gpsResult["lat"] as double?;
          final gpsLng = gpsResult["lng"] as double?;
          if (gpsLat != null && gpsLng != null) {
            lat = gpsLat;
            lng = gpsLng;
            // Recompute distances with live GPS coords
            for (final s in stores) {
              final slat = double.tryParse(s["latitude"]?.toString() ?? "");
              final slng = double.tryParse(s["longitude"]?.toString() ?? "");
              if (slat != null && slng != null) {
                s["distance_km"] = haversineKm(lat!, lng!, slat, slng);
              }
            }
            stores.sort((a, b) =>
                ((a["distance_km"] as double?) ?? 9999.0)
                .compareTo((b["distance_km"] as double?) ?? 9999.0));
          }
        }
      } catch (_) {
        debugPrint("[LoadingScreen] backgroundGps timed out — using cached coords");
      }
    }

    if (!mounted) return;
    _done = true;
    _stepTimer?.cancel();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    widget.onReady(city: city, stores: stores, lat: lat, lng: lng, fetchFailed: !fetchOk);
    } catch (e) {
      debugPrint("[LocationLoading] _fetchAndGo error: $e");
      if (mounted) {
        widget.onReady(
          city: city,
          stores: const [],
          lat: lat,
          lng: lng,
          fetchFailed: true, // stores were not delivered — not a genuinely empty city
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _screenFade,
        child: SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
            // Pin pulse animation
            SizedBox(
              width: 120, height: 120,
              child: Stack(alignment: Alignment.center, children: [
                AnimatedBuilder(
                  animation: _pinPulse,
                  builder: (_, __) => Transform.scale(
                    scale: _ringScale.value,
                    child: Opacity(
                      opacity: _ringOpacity.value,
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kPrimary, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _pinPulse,
                  builder: (_, __) => Transform.scale(
                    scale: _pinScale.value,
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: .08),
                        shape: BoxShape.circle,
                        border: Border.all(color: kPrimary, width: 2),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: kPrimary, size: 32),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 32),
            // FIX 7: Logo removed — only official splash screen shows logo
            const SizedBox(height: 16),
            // Step labels
            ...List.generate(_stepLabels.length, (i) => AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: i == _step ? 1.0 : 0.3,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_stepIcons[i],
                    color: i == _step ? kPrimary : const Color(0xFFB0BEC5),
                    size: i == _step ? 18 : 14),
                  const SizedBox(width: 8),
                  Text(_stepLabels[i],
                    style: TextStyle(
                      color: i == _step ? const Color(0xFF2c3e35) : const Color(0xFFB0BEC5),
                      fontSize: i == _step ? 15 : 13,
                      fontWeight: i == _step ? FontWeight.w700 : FontWeight.w400,
                    )),
                ]),
              ),
            )),
            const SizedBox(height: 28),
            // Dot progress
            AnimatedBuilder(
              animation: _dotCtrl,
              builder: (_, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: i == _step % 3
                        ? kPrimary
                        : const Color(0xFFD4E8DE),
                    shape: BoxShape.circle,
                  ),
                )),
              ),
            ),
            const Spacer(flex: 2),
          ]),
        ),
      ),
    );
  }
}
