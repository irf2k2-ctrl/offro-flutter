// lib/screens/location/location_access_gate.dart
// OFFRO — login/onboarding location-access page.
//
// Shown only when the person has NO saved location, device Location Services
// are ON and the OffrO permission has not been granted. It explains why
// location helps and hands off to the single LocationScreen — it has no
// location logic of its own. The permission dialog appears only after the
// person taps "Allow location".

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/offro_location.dart';
import '../../core/services/location_service.dart';
import '../../core/services/location_store.dart';
import 'location_screen.dart';

class LocationAccessGate extends StatefulWidget {
  final LocationMode mode;
  final Future<void> Function(OffroLocation loc) onSelected;
  const LocationAccessGate({super.key, required this.mode, required this.onSelected});

  @override
  State<LocationAccessGate> createState() => _LocationAccessGateState();
}

class _LocationAccessGateState extends State<LocationAccessGate> {
  String _msg = '';
  bool _busy = false;

  void _openScreen() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LocationScreen(
          mode: widget.mode,
          mandatory: true,
          onSelected: widget.onSelected,
        ),
      ),
    );
  }

  Future<void> _allow() async {
    if (_busy) return;
    setState(() { _busy = true; _msg = ''; });
    final res = await LocationService.requestPermission();
    if (!mounted) return;
    setState(() => _busy = false);
    if (res == LocationAccess.ready) {
      _openScreen();
    } else if (res == LocationAccess.permissionDeniedForever) {
      setState(() => _msg = 'Location permission is turned off for OffrO. You can allow it in app '
          'settings, or choose your city manually.');
    } else if (res == LocationAccess.serviceOff) {
      setState(() => _msg = "Your device's location services are off. Turn them on, or choose your city manually.");
    } else {
      setState(() => _msg = "Location permission wasn't allowed. You can still choose your city manually.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(color: kLight.withValues(alpha: .5), shape: BoxShape.circle),
              child: const Icon(Icons.location_on_rounded, color: kPrimary, size: 48),
            ),
            const SizedBox(height: 24),
            const Text('Allow location access',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kText)),
            const SizedBox(height: 10),
            const Text('OffrO needs your location to show nearby and relevant content.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, color: kMuted, height: 1.4)),
            if (_msg.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_msg, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFD64545), height: 1.35)),
              if (_msg.contains('app settings'))
                TextButton(
                  onPressed: LocationService.openAppSettings,
                  child: const Text('Open app settings', style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
                ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _allow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Allow location', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _openScreen,
              child: const Text('Choose city manually',
                  style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
            ),
          ]),
        ),
      ),
    );
  }
}
