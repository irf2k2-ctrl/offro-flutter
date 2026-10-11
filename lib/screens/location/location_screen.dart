// lib/screens/location/location_screen.dart
// OFFRO — the ONE location-selection screen (Customer AND Merchant).
//
// Search, "Use current location" (with device-services / app-permission /
// permanently-denied handling), Popular cities and All supported cities.
//
// Selection result:
//  * [onSelected] != null → called with the chosen [OffroLocation] (used when
//    this screen is the first route and the caller replaces the stack).
//  * otherwise the screen pops with the [OffroLocation].
// [mandatory] hides the close button and blocks back (first-time customer,
// Merchant Home gate).
//
// GPS permission is requested ONLY from an explicit tap on the access card.
// If permission is already granted, the screen reads GPS on open.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/offro_location.dart';
import '../../core/services/api_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/location_store.dart';
import 'location_access_card.dart';

class LocationScreen extends StatefulWidget {
  final LocationMode mode;
  final bool mandatory;
  final OffroLocation? current;
  final Future<void> Function(OffroLocation loc)? onSelected;

  const LocationScreen({
    super.key,
    required this.mode,
    this.mandatory = false,
    this.current,
    this.onSelected,
  });

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> with WidgetsBindingObserver {
  final TextEditingController _search = TextEditingController();
  StreamSubscription? _svcSub;

  List<SupportedCity> _supported = const []; // OffrO-active cities (/cities)
  List<SupportedCity> _cities = const [];    // cities shown in the list
  bool _citiesLoading = true;
  late Future<void> _citiesFuture;

  LocationAccess? _access;
  OffroLocation? _detected;
  bool _detecting = false;
  String _detectError = '';
  DateTime? _fixAt;
  Position? _fix; // last accepted fix (re-used if only geocoding failed)
  String _note = '';
  int _accessGen = 0;
  int _detectGen = 0;
  bool _busy = false;

  String _query = '';
  final Map<String, List<String>> _areas = {};
  bool _areasStarted = false;
  bool _areasLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _svcSub = LocationService.serviceStatusStream.listen((_) => _refreshAccess(), onError: (_) {});
    } catch (_) {}
    _citiesFuture = _loadCities();
    _refreshAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _svcSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from device / app settings → re-check what changed.
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  // ── data ────────────────────────────────────────────────────────────────
  Future<void> _loadCities() async {
    if (mounted) setState(() => _citiesLoading = true);
    final list = await LocationService.fetchSupportedCities();
    if (!mounted) return;
    setState(() {
      _supported = list;
      // Customers can choose ANY Indian city (OffrO stores or not — the Home
      // No-Store state handles empty cities). Merchants: supported only.
      _cities = widget.mode == LocationMode.customer ? LocationService.allIndiaCities(list) : list;
      _citiesLoading = false;
    });
  }

  Future<void> _loadAreasOnce() async {
    if (_areasStarted) return;
    _areasStarted = true;
    if (mounted) setState(() => _areasLoading = true);
    await _citiesFuture;
    final targets = _supported.take(20).toList();
    await Future.wait(targets.map((c) async {
      final a = await Api.fetchAreas(c.name);
      if (a.isNotEmpty) _areas[c.name] = a;
    }));
    if (mounted) setState(() => _areasLoading = false);
  }

  // ── access state ────────────────────────────────────────────────────────
  Future<void> _refreshAccess() async {
    final gen = ++_accessGen;
    final a = await LocationService.status();
    if (!mounted || gen != _accessGen) return;
    setState(() {
      _access = a;
      if (a != LocationAccess.ready) {
        _detectGen++; // invalidate any in-flight detection
        _detected = null; _detecting = false; _detectError = ''; _fix = null;
      } else {
        _note = '';
      }
    });
    if (a == LocationAccess.ready && _detected == null && !_detecting) _detect();
  }

  Future<void> _detect() async {
    final g = ++_detectGen;
    setState(() { _detecting = true; _detectError = ''; });
    // 1. Fresh, accurate GPS fix (re-use the last one if only geocoding failed).
    var fix = _fix;
    if (fix == null || _fixAt == null || DateTime.now().difference(_fixAt!) > const Duration(minutes: 2)) {
      fix = await LocationService.acquireFix();
      if (!mounted || g != _detectGen) return;
      if (fix == null) {
        setState(() {
          _detecting = false;
          _detectError = "Couldn't get a precise GPS fix. Move to an open area or check your signal.";
        });
        return;
      }
      _fix = fix;
      _fixAt = DateTime.now();
    }
    // 2. Reverse-geocode only the accepted fix.
    await _citiesFuture;
    final loc = await LocationService.resolveFix(fix!, _supported);
    if (!mounted || g != _detectGen) return;
    setState(() {
      _detecting = false;
      _detected = loc;
      _detectError = loc == null ? "Got your position but couldn't identify the city." : '';
    });
  }

  Future<void> _onAccessTap() async {
    // Always act on the LIVE state, never a possibly stale one (e.g. right
    // after returning from device / app settings).
    final a = await LocationService.status();
    if (!mounted) return;
    if (a != _access) setState(() => _access = a);

    switch (a) {
      case LocationAccess.ready:
        if (_detected != null) {
          await _select(_detected!);
        } else if (!_detecting) {
          _detect();
        }
        return;
      case LocationAccess.serviceOff:
        await _settingsDialog(
          message: "Your device's location services are turned off. Please turn them on in settings.",
          onGo: LocationService.openDeviceLocationSettings,
        );
        return;
      case LocationAccess.permissionDeniedForever:
        await _settingsDialog(
          message: "Location permission is turned off for OffrO. Please allow it in app settings.",
          onGo: LocationService.openAppSettings,
        );
        return;
      case LocationAccess.permissionDenied:
        // Services ON + permission not granted → explicit tap → OS dialog.
        final res = await LocationService.requestPermission();
        if (!mounted) return;
        setState(() { _access = res; _note = ''; });
        if (res == LocationAccess.ready) {
          _detect();
        } else if (res == LocationAccess.permissionDeniedForever) {
          await _settingsDialog(
            message: "Location permission is turned off for OffrO. Please allow it in app settings.",
            onGo: LocationService.openAppSettings,
          );
        } else if (res == LocationAccess.serviceOff) {
          await _settingsDialog(
            message: "Your device's location services are turned off. Please turn them on in settings.",
            onGo: LocationService.openDeviceLocationSettings,
          );
        } else {
          setState(() => _note = "Location permission wasn't allowed. Tap the card to try again, "
              "or choose a city below.");
        }
        return;
    }
  }

  Future<void> _settingsDialog({required String message, required Future<void> Function() onGo}) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Location not detected'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Go to settings')),
        ],
      ),
    );
    if (go == true) await onGo();
  }

  // ── selection ───────────────────────────────────────────────────────────
  Future<void> _select(OffroLocation loc) async {
    if (_busy) return;
    // Merchant location is valid only for a supported OffrO city.
    if (widget.mode == LocationMode.merchant && !LocationService.isSupported(loc.city, _supported)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('City not supported yet'),
          content: Text("OffrO isn't available in ${loc.city} yet. Please choose one of the supported cities."),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    _busy = true;
    try {
      final cb = widget.onSelected;
      if (cb != null) {
        await cb(loc);
      } else if (mounted) {
        Navigator.pop(context, loc);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _selectCity(SupportedCity c) => _select(OffroLocation(
        city: c.name,
        state: c.state,
        source: LocationSource.manual,
        updatedAt: DateTime.now(),
      ));

  Future<void> _selectArea(String area, SupportedCity c) => _select(OffroLocation(
        area: area,
        city: c.name,
        state: c.state,
        source: LocationSource.manual,
        updatedAt: DateTime.now(),
      ));

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.mandatory,
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                if (!widget.mandatory)
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30, color: kText),
                    onPressed: () => Navigator.pop(context),
                  )
                else
                  const SizedBox(width: 16, height: 48),
                const Text('Location', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kText)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (v) {
                  setState(() => _query = v.trim());
                  if (_query.length >= 2) _loadAreasOnce();
                },
                decoration: InputDecoration(
                  hintText: 'Search city, area or locality',
                  hintStyle: const TextStyle(color: kMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: kMuted),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, color: kMuted),
                          onPressed: () { _search.clear(); setState(() => _query = ''); },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: kPrimary, width: 1.6)),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  LocationAccessCard(
                    access: _access,
                    detecting: _detecting,
                    detectError: _detectError,
                    detected: _detected,
                    onTap: _onAccessTap,
                  ),
                  if (_note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_note, style: const TextStyle(fontSize: 12.5, color: kMuted, height: 1.35)),
                    ),
                  const SizedBox(height: 20),
                  if (_query.isEmpty) ..._browseSections() else ..._searchResults(),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  bool _isCurrentCity(String city, [String state = '']) {
    final cur = widget.current;
    if (cur == null || !cur.sameCity(city)) return false;
    return state.isEmpty || cur.state.isEmpty || cur.state.toLowerCase() == state.toLowerCase();
  }

  List<Widget> _citiesStatus() {
    if (_citiesLoading) {
      return const [Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5)),
      )];
    }
    if (_cities.isEmpty) {
      return [Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          const Text("Couldn't load cities. Check your connection and try again.",
              textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 13.5)),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () { _citiesFuture = _loadCities(); },
            style: OutlinedButton.styleFrom(foregroundColor: kPrimary, side: const BorderSide(color: kPrimary)),
            child: const Text('Try again'),
          ),
        ]),
      )];
    }
    return const [];
  }

  static const _metros = ['Mumbai', 'New Delhi', 'Bengaluru', 'Hyderabad', 'Chennai', 'Kolkata', 'Pune'];

  /// OffrO-active cities first, topped up with major metros (no labels).
  List<SupportedCity> _popular() {
    final out = <SupportedCity>[];
    bool has(String n) => out.any((e) => e.name.toLowerCase() == n.toLowerCase());
    for (final c in _supported) {
      if (out.length >= 6) break;
      final match = _cities.where((x) => x.name.toLowerCase() == c.name.toLowerCase());
      out.add(match.isNotEmpty ? match.first : c);
    }
    if (widget.mode == LocationMode.customer) {
      for (final m in _metros) {
        if (out.length >= 6) break;
        if (has(m)) continue;
        final match = _cities.where((x) => x.name == m);
        if (match.isNotEmpty) out.add(match.first);
      }
    }
    return out;
  }

  List<Widget> _browseSections() {
    final status = _citiesStatus();
    if (status.isNotEmpty) return status;
    final popular = _popular();
    final all = [..._cities]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [
      const Text('Popular cities', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kText)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (ctx, c) {
        final w = (c.maxWidth - 20) / 3;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final p in popular)
            SizedBox(width: w, child: _CityTile(
              name: p.name,
              selected: _isCurrentCity(p.name, p.state),
              onTap: () => _selectCity(p),
            )),
        ]);
      }),
      const SizedBox(height: 24),
      Text(widget.mode == LocationMode.customer ? 'All cities' : 'Supported cities', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kText)),
      const SizedBox(height: 4),
      for (final c in all) _CityRow(
        title: c.name,
        subtitle: c.state,
        selected: _isCurrentCity(c.name, c.state),
        onTap: () => _selectCity(c),
      ),
    ];
  }

  List<Widget> _searchResults() {
    final status = _citiesStatus();
    if (status.isNotEmpty) return status;
    final q = _query.toLowerCase();
    final cityHits = _cities.where((c) =>
        c.name.toLowerCase().contains(q) || c.state.toLowerCase().contains(q)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final areaHits = <MapEntry<String, SupportedCity>>[];
    for (final c in _cities) {
      for (final a in (_areas[c.name] ?? const <String>[])) {
        if (a.toLowerCase().contains(q)) areaHits.add(MapEntry(a, c));
      }
    }
    final out = <Widget>[];
    if (cityHits.isNotEmpty) {
      out.add(const Text('Cities', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kText)));
      for (final c in cityHits) {
        out.add(_CityRow(title: c.name, subtitle: c.state, selected: _isCurrentCity(c.name, c.state), onTap: () => _selectCity(c)));
      }
    }
    if (areaHits.isNotEmpty) {
      out.add(const SizedBox(height: 16));
      out.add(const Text('Areas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kText)));
      for (final h in areaHits.take(40)) {
        out.add(_CityRow(
          title: h.key,
          subtitle: [h.value.name, h.value.state].where((e) => e.isNotEmpty).join(', '),
          selected: false,
          onTap: () => _selectArea(h.key, h.value),
        ));
      }
    }
    if (_areasLoading && areaHits.isEmpty) {
      out.add(const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))),
      ));
    }
    if (out.isEmpty) {
      out.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No matching places found.',
            style: TextStyle(color: kMuted, fontSize: 13.5))),
      ));
    }
    return out;
  }
}

class _CityTile extends StatelessWidget {
  final String name; final bool selected; final VoidCallback onTap;
  const _CityTile({required this.name, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? kLight.withValues(alpha: .5) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? kPrimary : kBorder, width: selected ? 1.6 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_city_rounded, color: kPrimary, size: 26),
            const SizedBox(height: 8),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText)),
          ]),
        ),
      );
}

class _CityRow extends StatelessWidget {
  final String title, subtitle; final bool selected; final VoidCallback onTap;
  const _CityRow({required this.title, required this.subtitle, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: kText)),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle, style: const TextStyle(fontSize: 12, color: kMuted)),
                ),
            ])),
            if (selected) const Icon(Icons.check_circle_rounded, color: kPrimary, size: 20),
          ]),
        ),
      );
}
