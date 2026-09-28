// lib/screens/store/widgets/store_offers_section.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import 'store_header.dart' show FullScreenImageViewer;

class StoreOffersSection extends StatelessWidget {
  final List<Map<String, dynamic>> deals;
  final String storeName;
  final String storeArea;
  final String storeCity;
  final String storeId;

  const StoreOffersSection({
    super.key,
    required this.deals,
    required this.storeName,
    this.storeArea = '',
    this.storeCity = '',
    this.storeId = '',
  });

  /// Format a date string (yyyy-MM-dd or dd MMM yyyy) as "d MMM yyyy"
  static String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    // Try yyyy-MM-dd
    try {
      final dt = DateTime.parse(raw.substring(0, 10));
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) {}
    // Already in "dd MMM yyyy" format — return as-is
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Section header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            const Text("Today's Offers",
                style: TextStyle(
                    color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (deals.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${deals.length} deal${deals.length == 1 ? "" : "s"}',
                  style: const TextStyle(
                      color: kPrimary, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
          ]),
        ),

        // ── Empty state ──
        if (deals.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: kLight.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder, width: 1),
              ),
              child: Column(children: [
                Icon(Icons.local_offer_outlined, color: kAccent, size: 32),
                const SizedBox(height: 8),
                const Text('Offers coming soon',
                    style: TextStyle(
                        color: kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          )
        else
          // ── Horizontal scrollable light-theme offer cards ──
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              itemCount: deals.length,
              itemBuilder: (ctx, idx) {
                final d       = deals[idx];
                final title   = d['title']?.toString() ?? '';
                final desc    = d['description']?.toString() ?? '';
                final disc    = d['discount']?.toString() ?? '0';
                final endDate = d['end_date']?.toString() ?? '';
                final discInt = int.tryParse(disc) ?? 0;
                // Round 6 (Issue 2): the deal's own uploaded image, if any.
                // Root cause of "image not showing" was purely here — the
                // backend (routers/public.py) already returned image_url in
                // this same deals list (added in Round 5), but this card
                // never read it and always rendered the generic decorative
                // design. Falls back to that exact unchanged design when
                // empty, so deals without an image keep working as before.
                final imageUrl = d['image_url']?.toString() ?? '';

                if (imageUrl.isNotEmpty) {
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      ctx,
                      PageRouteBuilder(
                        opaque: false,
                        barrierColor: Colors.black,
                        transitionDuration: const Duration(milliseconds: 280),
                        pageBuilder: (_, __, ___) => FullScreenImageViewer(
                          images: [imageUrl],
                          initialIndex: 0,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 210,
                      height: 210,
                      margin: EdgeInsets.only(right: idx < deals.length - 1 ? 12 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBorder, width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: kPrimary.withValues(alpha: .08),
                              blurRadius: 16,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // ── Deal image fills the card ──
                            imageUrl.startsWith('data:image')
                                ? Builder(builder: (_) {
                                    try {
                                      return Image.memory(
                                          base64Decode(imageUrl.split(',').last),
                                          fit: BoxFit.cover);
                                    } catch (_) {
                                      return Container(color: kLight);
                                    }
                                  })
                                : CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: kLight),
                                    errorWidget: (_, __, ___) => Container(color: kLight,
                                        child: const Icon(Icons.broken_image_outlined, color: kMuted, size: 32)),
                                  ),
                            // ── Bottom scrim for text readability ──
                            Positioned(
                              left: 0, right: 0, bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: .72)],
                                  ),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                  if (title.isNotEmpty)
                                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                                  if (endDate.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text('Valid till ${_formatDate(endDate)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 10, fontWeight: FontWeight.w600)),
                                  ],
                                ]),
                              ),
                            ),
                            // ── Discount % chip, top-left ──
                            if (discInt > 0)
                              Positioned(
                                top: 10, left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: kPrimary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('$discInt% OFF',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Container(
                  width: 210,
                  margin: EdgeInsets.only(right: idx < deals.length - 1 ? 12 : 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: kPrimary.withValues(alpha: .08),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // ── Decorative green circles (background) ──
                      Positioned(
                        top: -30, right: -30,
                        child: Container(
                          width: 110, height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                kPrimary.withValues(alpha: .13),
                                kPrimary.withValues(alpha: .0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -20, left: -20,
                        child: Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                kAccent.withValues(alpha: .18),
                                kAccent.withValues(alpha: .0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 70, right: 10,
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kLight.withValues(alpha: .6),
                          ),
                        ),
                      ),

                      // ── Card content ──
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Big centered % badge
                            if (discInt > 0) ...[
                              Center(
                                child: Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        kPrimary.withValues(alpha: .12),
                                        kAccent.withValues(alpha: .18),
                                      ],
                                    ),
                                    border: Border.all(
                                        color: kPrimary.withValues(alpha: .25),
                                        width: 1.5),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$discInt%',
                                          style: TextStyle(
                                            color: kPrimary,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                          ),
                                        ),
                                        Text(
                                          'OFF',
                                          style: TextStyle(
                                            color: kPrimary.withValues(alpha: .8),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Offer title
                            if (title.isNotEmpty)
                              Text(
                                title,
                                style: const TextStyle(
                                  color: kText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),

                            // Description
                            if (desc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  desc,
                                  style: const TextStyle(
                                      color: kMuted, fontSize: 11, height: 1.4),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            const Spacer(),

                            // Valid till — bottom
                            if (endDate.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kLight.withValues(alpha: .8),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: kBorder.withValues(alpha: .6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        size: 9, color: kPrimary),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Valid till ${_formatDate(endDate)}',
                                        style: const TextStyle(
                                            color: kPrimary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}
