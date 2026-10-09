// lib/core/utils/geo.dart
//
// Single shared great-circle distance helper. Previously three private copies
// existed (main.dart x2, location_loading_screen.dart) with identical intent.
import 'dart:math' as math;

/// Haversine distance in kilometres between two lat/lng points.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = a.clamp(0.0, 1.0).toDouble();
  return r * 2 * math.atan2(math.sqrt(c), math.sqrt(1 - c));
}
