// lib/screens/location/location_access_card.dart
// OFFRO — location access status card shown on the Location screen.
// Red = location unavailable (device services off / permission needed),
// green/blue = ready ("Use current location").

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/offro_location.dart';
import '../../core/services/location_service.dart';

const Color _kRed = Color(0xFFD64545);
const Color _kRedBg = Color(0xFFFDECEC);

class LocationAccessCard extends StatelessWidget {
  final LocationAccess? access; // null = still checking
  final bool detecting;
  final String detectError; // '' = none
  final OffroLocation? detected;
  final VoidCallback onTap;

  const LocationAccessCard({
    super.key,
    required this.access,
    required this.detecting,
    required this.detectError,
    required this.detected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = access;
    Color border = kBorder;
    Color bg = Colors.white;
    Color iconColor = kPrimary;
    IconData icon = Icons.my_location_rounded;
    String title = 'Checking location…';
    String subtitle = '';
    Widget? trailing;

    if (a == LocationAccess.serviceOff) {
      border = _kRed; bg = _kRedBg; iconColor = _kRed;
      icon = Icons.location_off_rounded;
      title = 'Location services are off';
      subtitle = 'Turn on your device location to see places near you';
      trailing = const Icon(Icons.arrow_forward_rounded, color: _kRed, size: 20);
    } else if (a == LocationAccess.permissionDenied) {
      border = _kRed; bg = _kRedBg; iconColor = _kRed;
      icon = Icons.map_outlined;
      title = 'Enable location permissions';
      subtitle = 'for more relevant suggestions near you';
      trailing = const Icon(Icons.arrow_forward_rounded, color: _kRed, size: 20);
    } else if (a == LocationAccess.permissionDeniedForever) {
      border = _kRed; bg = _kRedBg; iconColor = _kRed;
      icon = Icons.location_disabled_rounded;
      title = 'Location permission is blocked';
      subtitle = 'Allow location for OffrO in app settings';
      trailing = const Icon(Icons.arrow_forward_rounded, color: _kRed, size: 20);
    } else if (a == LocationAccess.ready) {
      border = kPrimary; bg = kLight.withValues(alpha: .35); iconColor = kPrimary;
      icon = Icons.my_location_rounded;
      title = 'Use current location';
      if (detecting) {
        subtitle = 'Detecting your location…';
        trailing = const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary));
      } else if (detected != null) {
        subtitle = '${detected!.title}\n${detected!.subtitle}';
        trailing = const Icon(Icons.chevron_right_rounded, color: kPrimary);
      } else if (detectError.isNotEmpty) {
        subtitle = '$detectError Tap to retry.';
        trailing = const Icon(Icons.refresh_rounded, color: kPrimary);
      }
    } else {
      trailing = const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: kMuted));
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: a == null ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w800,
                  color: a == null || a == LocationAccess.ready ? kText : _kRed)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: kMuted, height: 1.3)),
              ],
            ])),
            if (trailing != null) ...[const SizedBox(width: 10), trailing],
          ]),
        ),
      ),
    );
  }
}
