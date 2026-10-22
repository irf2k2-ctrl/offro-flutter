// lib/screens/store/widgets/store_header.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/base64_image.dart' show decodeBase64ImageCached;
import '../../../core/utils/store_hours.dart';
import '../../../core/design/design.dart';

class StoreHeader extends StatelessWidget {
  final Map<String, dynamic> store;
  final List<String> images;
  final int imgPage;
  final PageController imgController;
  final bool isFav;
  final VoidCallback onFavToggle;
  final VoidCallback onShare;
  final VoidCallback onBack;

  const StoreHeader({
    super.key,
    required this.store,
    required this.images,
    required this.imgPage,
    required this.imgController,
    required this.isFav,
    required this.onFavToggle,
    required this.onShare,
    required this.onBack,
  });

  void _openFullScreen(BuildContext context) {
    if (images.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => FullScreenImageViewer(
          images: images,
          initialIndex: imgPage,
        ),
      ),
    );
  }

  /// Badge label (Trending / New store / …) from the same store fields the
  /// old inline badge used. Returns null when there is no badge.
  String? _badgeLabel() {
    const meta = <String, String>{
      'new_store':     'NEW STORE',
      'just_opened':   'JUST OPENED',
      'newly_added':   'NEWLY ADDED',
      'newly_opened':  'NEWLY OPENED',
      'trending':      'TRENDING',
      'popular':       'POPULAR',
      'top_rated':     'TOP RATED',
      'must_visit':    'MUST VISIT',
      'limited_offer': 'LIMITED OFFER',
    };
    final rb = (store['badge'] as String?)?.trim() ?? '';
    String? key;
    if (rb.isNotEmpty && meta.containsKey(rb)) {
      key = rb;
    } else {
      try {
        final c = store['created_at']?.toString()
            ?? store['created_date']?.toString() ?? '';
        if (c.isNotEmpty) {
          final dt = DateTime.tryParse(c);
          if (dt != null && DateTime.now().difference(dt).inDays < 10) {
            key = 'newly_added';
          }
        }
      } catch (_) {}
      if (key == null) {
        final isNewInTown = store['is_new_in_town'] == true
            || store['is_new_in_town']?.toString() == 'true'
            || store['is_new'] == true
            || store['is_new']?.toString() == 'true';
        if (isNewInTown) {
          key = 'new_store';
        } else if (store['is_trending'] == true) {
          key = 'trending';
        } else if (store['is_popular'] == true) {
          key = 'popular';
        }
      }
    }
    return key == null ? null : meta[key];
  }

  /// "Offer · 20% off" from the store's real offer / deals. Null if none.
  String? _offerLabel() {
    final offer = store['offer']?.toString().trim() ?? '';
    if (offer.isNotEmpty && offer.toLowerCase() != 'null') {
      final m = RegExp(r'(\d+)\s*%').firstMatch(offer);
      return m != null ? 'Offer · ${m.group(1)}% off' : 'Offer · $offer';
    }
    final deals = store['deals'];
    if (deals is List) {
      int best = 0;
      for (final d in deals) {
        if (d is Map) {
          final v = int.tryParse(d['discount']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ?? 0;
          if (v > best) best = v;
        }
      }
      if (best > 0) return 'Offer · $best% off';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Figma store detail: edge-to-edge photo with floating back / share /
    // favourite, offer badge, then a rounded sheet with category, rating,
    // name, location and Call / WhatsApp / Directions.
    final name        = store['store_name']?.toString() ?? '';
    final category    = store['category']?.toString() ?? '';
    final area        = store['area']?.toString() ?? '';
    final city        = store['city']?.toString() ?? '';
    final rating      = (store['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (store['review_count'] as num?)?.toInt() ?? 0;
    final distKm      = (store['distance_km'] as num?)?.toDouble();
    final locationText = [area, city].where((x) => x.isNotEmpty).join(', ');
    final distText = distKm == null
        ? ''
        : (distKm < 1 ? '${(distKm * 1000).round()} m' : '${distKm.toStringAsFixed(1)} km');
    final mainImage = images.isNotEmpty ? images[0] : '';
    final offer = _offerLabel();
    final badge = _badgeLabel();
    final topInset = MediaQuery.of(context).padding.top;
    const heroH = 320.0;

    Widget circleBtn(Widget child, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), shape: BoxShape.circle),
        child: child,
      ),
    );

    Widget pill(String text, {Color bg = Colors.white, Color fg = OffroColors.primary}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: OffroRadii.pillRadius),
      child: Text(text, style: OffroText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600, color: fg)),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: heroH,
        child: Stack(fit: StackFit.expand, children: [
          GestureDetector(
            onTap: () => _openFullScreen(context),
            child: mainImage.isEmpty
                ? Container(
                    color: OffroColors.mint,
                    child: const Center(child: OffroIcon(OffroIcons.store, size: 64, color: OffroColors.sage)))
                : _buildImage(mainImage),
          ),
          const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x40000000), Color(0x00000000), Color(0x00000000), Color(0x26000000)],
              stops: [0.0, 0.3, 0.7, 1.0])))),
          Positioned(
            top: topInset + 8, left: 16, right: 16,
            child: Row(children: [
              circleBtn(const OffroIcon(OffroIcons.back, size: 18, color: OffroColors.text), onBack),
              const Spacer(),
              circleBtn(const OffroIcon(OffroIcons.share, size: 17, color: OffroColors.text), onShare),
              const SizedBox(width: 8),
              circleBtn(
                OffroIcon(OffroIcons.heart, size: 17,
                  color: isFav ? OffroColors.terracotta : OffroColors.text, filled: isFav),
                onFavToggle),
            ]),
          ),
          if (offer != null)
            Positioned(left: 20, bottom: 44, child: pill(offer)),
        ]),
      ),

      Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: OffroColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (category.isNotEmpty) pill(category, bg: OffroColors.mintSoft),
              if (badge != null) ...[
                const SizedBox(width: 8),
                pill(badge, bg: OffroColors.beige.withValues(alpha: .6), fg: OffroColors.text),
              ],
              const Spacer(),
              if (rating > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: OffroColors.beige.withValues(alpha: .45), borderRadius: OffroRadii.pillRadius),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const OffroIcon(OffroIcons.star, size: 12, color: OffroColors.amber, filled: true),
                    const SizedBox(width: 4),
                    Text(rating.toStringAsFixed(1), style: OffroText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: OffroColors.text)),
                    if (reviewCount > 0) ...[
                      const SizedBox(width: 3),
                      Text('($reviewCount)', style: OffroText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w400, color: OffroColors.textMuted)),
                    ],
                  ]),
                ),
            ]),
            const SizedBox(height: 14),
            Text(name, style: OffroText.display.copyWith(fontSize: 28, letterSpacing: -1.6, height: 1.1)),
            if (locationText.isNotEmpty || distText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const OffroIcon(OffroIcons.pin, size: 13, color: OffroColors.sage),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  [locationText, distText].where((x) => x.isNotEmpty).join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: OffroColors.textMuted))),
              ]),
            ],

            // ── Open/close status (same shared helper as the About tab) ──
            Builder(builder: (ctx) {
              final status = computeStoreOpenStatus(
                  store['open_time']?.toString() ?? '', store['close_time']?.toString() ?? '');
              if (status == null) return const SizedBox.shrink();
              final isOpen = status.isOpen;
              final sub = status.subLabel;
              final fg = isOpen ? OffroColors.success : OffroColors.error;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: fg.withValues(alpha: .10), borderRadius: OffroRadii.pillRadius),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(isOpen ? 'Open' : 'Closed',
                      style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
                    if (sub.isNotEmpty)
                      Text(' · $sub', style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: fg)),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 20),
            _ActionButtonsRow(store: store),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildImage(String im) {
    if (im.startsWith('data:image')) {
      try {
        return Image.memory(
          decodeBase64ImageCached(im),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        );
      } catch (_) {}
    }
    if (im.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: im,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, __) => Container(color: kLight),
        errorWidget: (_, __, ___) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF2a4a40), kPrimary]),
          ),
        ),
      );
    }
    return Container(color: kLight);
  }
}

// ─── Action Buttons Row ───────────────────────────────────────
class _ActionButtonsRow extends StatelessWidget {
  final Map<String, dynamic> store;
  const _ActionButtonsRow({required this.store});

  Future<void> _call() async {
    final phone = store['phone']?.toString() ?? '';
    if (phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _whatsapp() async {
    final phone = store['phone']?.toString() ?? '';
    if (phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    await launchUrl(
      Uri.parse('https://wa.me/$clean'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _directions() async {
    final lat  = store['latitude']?.toString()  ?? '';
    final lng  = store['longitude']?.toString() ?? '';
    final addr = store['address']?.toString()   ?? '';
    final url  = (lat.isNotEmpty && lng.isNotEmpty)
        ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
        : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}';
    await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final btns = [
      _BtnData('Call',       OffroIcons.phone,   _call),
      _BtnData('WhatsApp',   OffroIcons.message, _whatsapp),
      _BtnData('Directions', OffroIcons.route,   _directions),
    ];
    return Row(
      children: btns.asMap().entries.map((e) {
        final b = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 10),
            child: GestureDetector(
              onTap: b.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: OffroColors.borderSoft),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  OffroIcon(b.icon, color: OffroColors.primary, size: 20),
                  const SizedBox(height: 8),
                  Text(b.label,
                    style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: OffroColors.text),
                    textAlign: TextAlign.center),
                ]),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BtnData {
  final String label;
  final OffroIconData icon;
  final VoidCallback onTap;
  const _BtnData(this.label, this.icon, this.onTap);
}

// ─── Full Screen Image Viewer ─────────────────────────────────
// Made public (Round 6 — Issue 2) so other screens can reuse the same
// gallery viewer instead of building a second one — e.g. the Store Detail
// "Today's Offers" deal card now opens a tapped deal image through this
// same widget. Works for a single image too (images: [url], initialIndex: 0
// — the "n / total" counter simply doesn't render for a length-1 list).
class FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  // Round 10: optional per-image bottom overlay content (e.g. a deal title,
  // or a product's name/tagline/discount/price) shown above a subtle
  // bottom gradient, same position for every caller so the deal and
  // product galleries share one consistent viewer. Index-aligned with
  // `images`; a caller that passes nothing (e.g. the existing store-photo
  // gallery in this file) keeps the exact previous look — this is purely
  // additive and optional.
  final List<Widget>? bottomOverlays;
  // Round 12 (Task 4): when true, the image sits higher on screen (instead
  // of dead-centered) and the bottom overlay gets extra top padding, so
  // there's real visual separation between the image and the info panel
  // below it, rather than the overlay's gradient floating directly over
  // the bottom of the image. Defaults to false so the two existing callers
  // (the plain store-photo gallery here, and the deal gallery in
  // store_offers_section.dart) keep their exact previous look — only the
  // product gallery opts into this.
  final bool spacedOverlay;
  const FullScreenImageViewer(
      {super.key, required this.images, required this.initialIndex, this.bottomOverlays,
       this.spacedOverlay = false});

  @override
  State<FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState
    extends State<FullScreenImageViewer> {
  late int _current;
  late PageController _pc;
  late TransformationController _tc;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pc = PageController(initialPage: widget.initialIndex);
    _tc = TransformationController();
  }

  @override
  void dispose() {
    _pc.dispose();
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if (d.primaryVelocity != null &&
              d.primaryVelocity!.abs() > 300) {
            Navigator.pop(context);
          }
        },
        child: Stack(children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final im = widget.images[i];
              final overlay = (widget.bottomOverlays != null && i < widget.bottomOverlays!.length)
                  ? widget.bottomOverlays![i]
                  : null;
              final imageWidget = im.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: im,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 60),
                    )
                  : im.startsWith('data:image')
                      ? Builder(builder: (_) {
                          try {
                            return Image.memory(
                              base64Decode(im.split(',').last),
                              fit: BoxFit.contain,
                            );
                          } catch (_) {
                            return const SizedBox.shrink();
                          }
                        })
                      : const SizedBox.shrink();
              return Stack(fit: StackFit.expand, children: [
                InteractiveViewer(
                  transformationController: _tc,
                  minScale: 0.8,
                  maxScale: 4.0,
                  // Round 12 (Task 4): spacedOverlay shifts the image up
                  // (Align above center) and reserves blank space below it
                  // (the bottom Padding shrinks the box BoxFit.contain sizes
                  // against) so the image and the info panel underneath are
                  // visually separated instead of the info gradient sitting
                  // directly over the image's lower edge. Pan/zoom/swipe
                  // still work over the FULL screen — only where the image
                  // itself is laid out changes, not InteractiveViewer's
                  // hit-testing area.
                  child: widget.spacedOverlay
                      ? Align(
                          alignment: const Alignment(0, -0.22),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 150),
                            child: imageWidget,
                          ),
                        )
                      : Center(child: imageWidget),
                ),
                // ── Round 10: optional bottom overlay (deal/product info) ──
                // IgnorePointer so it never blocks the InteractiveViewer's
                // pan/zoom/swipe gestures underneath it.
                if (overlay != null)
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(20, widget.spacedOverlay ? 90 : 48, 20, 32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0),
                              Colors.black.withValues(alpha: widget.spacedOverlay ? .70 : .75),
                            ],
                          ),
                        ),
                        child: SafeArea(top: false, child: overlay),
                      ),
                    ),
                  ),
              ]);
            },
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  if (widget.images.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_current + 1} / ${widget.images.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
