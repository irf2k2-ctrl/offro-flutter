// lib/screens/loading/location_loading_screen.dart
// OFFRO — Premium Location Loading Screen

import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';

typedef OnReadyCallback = void Function({
  required String city,
  required List<Map<String, dynamic>> stores,
  required double? lat,
  required double? lng,
});

class LocationLoadingScreen extends StatefulWidget {
  final String token, name, phone, userId;
  final OnReadyCallback onReady;
  final String? forcedCity;

  const LocationLoadingScreen({
    super.key,
    required this.token,
    required this.name,
    required this.phone,
    required this.userId,
    required this.onReady,
    this.forcedCity,
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
  bool _showManual = false;
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

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_done) setState(() => _showManual = true);
    });
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

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) *
        math.cos(lat2 * math.pi / 180) *
        math.pow(math.sin(dLon / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a.toDouble()), math.sqrt(1 - a.toDouble()));
  }

  Future<void> _doLoad() async {
    try {
    // If forced city (manual selection or passed from splash), skip GPS
    if (widget.forcedCity != null && widget.forcedCity!.isNotEmpty) {
      await _fetchAndGo(widget.forcedCity!, null, null);
      return;
    }

    // ── Step 0: Request location permission upfront (shows OS dialog on first launch) ──
    // Do this BEFORE using cached data so the prompt appears immediately.
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    // Note: deniedForever is handled in _refreshGpsBackground gracefully.

    // ── Blinkit-style instant load ──
    // 1. Read cached GPS + city from prefs (instant, no I/O wait)
    final savedLoc = await Prefs.getSavedLocation();
    final savedPrefs = await Prefs.get();
    final cachedCity = savedPrefs["city"] ?? "";

    if (savedLoc != null) {
      _lat = savedLoc["lat"];
      _lng = savedLoc["lng"];
    }

    // 2. Use cached city immediately to start fetching stores in parallel
    //    while live GPS refreshes in background
    final cityToUse = cachedCity.isNotEmpty ? cachedCity : "Ballari";

    // 3. Fire live GPS as a background Future (don't await it)
    final gpsFuture = _refreshGpsBackground();

    // 4. Fetch stores using cached city immediately — don't wait for GPS
    await _fetchAndGo(cityToUse, _lat, _lng, backgroundGps: gpsFuture);
    } catch (e) {
      debugPrint("[LocationLoading] _doLoad fatal error: $e");
      // Fallback: open home with whatever we have so user is never stuck
      final fallbackCity = widget.forcedCity ?? await Prefs.getCity();
      if (!mounted) return;
      widget.onReady(
        city: fallbackCity.isNotEmpty ? fallbackCity : "Ballari",
        stores: const [],
        lat: _lat,
        lng: _lng,
      );
    }
  }

  Future<Map<String, dynamic>?> _refreshGpsBackground() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 6));
      _lat = pos.latitude;
      _lng = pos.longitude;
      await Prefs.saveLocation(_lat!, _lng!);
      final placemarks = await placemarkFromCoordinates(_lat!, _lng!)
          .timeout(const Duration(seconds: 5));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? "";
        if (city.isNotEmpty) {
          await Prefs.saveCity(city);
          return {"city": city, "lat": _lat, "lng": _lng};
        }
      }
    } catch (e) {
      debugPrint("[LoadingScreen] Background GPS failed: $e");
    }
    return null;
  }

  Future<void> _fetchAndGo(String city, double? lat, double? lng, {Future<Map<String,dynamic>?>? backgroundGps}) async {
    try {
    if (!mounted) return;
    setState(() => _statusText = "Finding deals in $city...");

    List<Map<String, dynamic>> stores = [];
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        if (attempt > 1) {
          await Future.delayed(const Duration(seconds: 2));
          Api.clearCache();
        }
        final raw = await Api.fetchStores(city: city);
        stores = List<Map<String, dynamic>>.from(raw);
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
          s["distance_km"] = _haversineKm(lat, lng, slat, slng);
        }
      }
      stores.sort((a, b) =>
          ((a["distance_km"] as double?) ?? 9999.0)
          .compareTo((b["distance_km"] as double?) ?? 9999.0));
    }

    await Prefs.saveCity(city);
    try { await Api.updateCity(widget.token, city); } catch (_) {}

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
                s["distance_km"] = _haversineKm(lat!, lng!, slat, slng);
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
    widget.onReady(city: city, stores: stores, lat: lat, lng: lng);
    } catch (e) {
      debugPrint("[LocationLoading] _fetchAndGo error: $e");
      if (mounted) {
        widget.onReady(
          city: city,
          stores: const [],
          lat: lat,
          lng: lng,
        );
      }
    }
  }

  void _chooseManually() async {
    final cityController = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter Your City",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: cityController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: "e.g. Bangalore, Mumbai...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, cityController.text.trim()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Confirm", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() { _showManual = false; _statusText = "Loading $result..."; });
      await _fetchAndGo(result, null, null);
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
            if (_showManual) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(children: [
                  Text("Taking too long?",
                    style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 13)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _chooseManually,
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                    label: const Text("Enter City Manually"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimary,
                      side: const BorderSide(color: kPrimary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
            ],
          ]),
        ),
      ),
    );
  }
}
