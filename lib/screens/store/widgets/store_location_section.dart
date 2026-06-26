// lib/screens/store/widgets/store_location_section.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';

class StoreLocationSection extends StatelessWidget {
  final Map<String, dynamic> store;
  const StoreLocationSection({super.key, required this.store});

  Future<void> _openMaps() async {
    final lat  = store['latitude']?.toString()  ?? '';
    final lng  = store['longitude']?.toString() ?? '';
    final addr = store['address']?.toString()   ?? '';
    final url  = (lat.isNotEmpty && lng.isNotEmpty)
        ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
        : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final area    = store['area']?.toString()    ?? '';
    final city    = store['city']?.toString()    ?? '';
    final address = store['address']?.toString() ?? '';
    final distKm  = (store['distance_km'] as num?)?.toDouble();

    final locationText = [area, city].where((x) => x.isNotEmpty).join(', ');
    if (locationText.isEmpty && address.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Location',
            style: TextStyle(
                color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .07),
                  blurRadius: 14,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(children: [
            // Mini map preview (static gradient placeholder with pin icon)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: GestureDetector(
                onTap: _openMaps,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFCDEBD6), Color(0xFFE7D7C8)],
                    ),
                  ),
                  child: Stack(children: [
                    // Grid lines to simulate map
                    ...List.generate(4, (i) => Positioned(
                      top: i * 30.0, left: 0, right: 0,
                      child: Container(height: 1,
                          color: Colors.white.withValues(alpha: .4)),
                    )),
                    ...List.generate(5, (i) => Positioned(
                      left: i * 80.0, top: 0, bottom: 0,
                      child: Container(width: 1,
                          color: Colors.white.withValues(alpha: .4)),
                    )),
                    // Center pin
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: kPrimary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: kPrimary.withValues(alpha: .4),
                                    blurRadius: 12)
                              ],
                            ),
                            child: const Icon(Icons.location_on_rounded,
                                color: Colors.white, size: 22),
                          ),
                          Container(
                            width: 2, height: 8,
                            color: kPrimary,
                          ),
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                                color: kPrimary, shape: BoxShape.circle),
                          ),
                        ],
                      ),
                    ),
                    // Tap hint
                    Positioned(
                      bottom: 8, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Tap to open maps',
                            style: TextStyle(
                                color: kPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),

            // Address info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                if (locationText.isNotEmpty)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.location_on_rounded,
                        color: kPrimary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(locationText,
                          style: const TextStyle(
                              color: kText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(address,
                        style: const TextStyle(color: kMuted, fontSize: 12)),
                  ),
                ],
                if (distKm != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Row(children: [
                      const Icon(Icons.near_me_rounded,
                          color: kPrimary, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        distKm < 1
                            ? '${(distKm * 1000).round()} metres away'
                            : '${distKm.toStringAsFixed(1)} km away',
                        style: const TextStyle(
                            color: kPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                // CTA button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openMaps,
                    icon: const Icon(Icons.directions_rounded, size: 16),
                    label: const Text('Visit Store',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
