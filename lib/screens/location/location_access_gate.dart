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
import '../../core/design/offro_tokens.dart' show OffroColors;
import '../../core/l10n/l10n.dart';

class LocationAccessGate extends StatefulWidget {
  final LocationMode mode;
  final Future<void> Function(OffroLocation loc) onSelected;
  const LocationAccessGate({super.key, required this.mode, required this.onSelected});

  @override
  State<LocationAccessGate> createState() => _LocationAccessGateState();
}

class _LocationAccessGateState extends State<LocationAccessGate> {
  String _msg = '';
  bool _showSettings = false;
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
    setState(() { _busy = true; _msg = ''; _showSettings = false; });
    final res = await LocationService.requestPermission();
    if (!mounted) return;
    setState(() => _busy = false);
    if (res == LocationAccess.ready) {
      _openScreen();
    } else if (res == LocationAccess.permissionDeniedForever) {
      setState(() { _showSettings = true; _msg = context.l10n.locGateBlockedMsg; }
          );
    } else if (res == LocationAccess.serviceOff) {
      setState(() => _msg = context.l10n.locGateServiceOffMsg);
    } else {
      setState(() => _msg = context.l10n.locGateDeniedMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OffroColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(color: kLight, shape: BoxShape.circle),
              child: const Icon(Icons.location_on_rounded, color: kPrimary, size: 48),
            ),
            const SizedBox(height: 24),
            Text(context.l10n.locGateTitle,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: OffroColors.text)),
            const SizedBox(height: 10),
            Text(context.l10n.locGateBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, color: OffroColors.textMuted, height: 1.4)),
            if (_msg.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_msg, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFD64545), height: 1.35)),
              if (_showSettings)
                TextButton(
                  onPressed: LocationService.openAppSettings,
                  child: Text(context.l10n.locGateOpenSettings, style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
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
                child: Text(context.l10n.locGateAllow, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _openScreen,
              child: Text(context.l10n.locGateChooseManually,
                  style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
            ),
          ]),
        ),
      ),
    );
  }
}
