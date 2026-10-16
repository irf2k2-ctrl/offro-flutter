// lib/core/widgets/product_share_card.dart
// OFFRO — Product share card.
//
// Turns "Share" on Product Details into a branded image + caption instead of
// plain text. Everything lives here so main.dart only calls [ProductShare.share].
//
//   ProductLink          one place that builds the product link (placeholder
//                        https://offro.app/p/<id> — change it HERE later)
//   ProductShareData     the public fields shown on the card, read from the
//                        product map Product Details already holds
//   ProductShareCard     the card widget (no QR code)
//   ProductShare.share   preload image → render off-screen → PNG → share_plus;
//                        any failure falls back to the plain-text share
//
// Privacy: only fields Product Details already shows are used (name, store
// name, prices, offer text, store rating, store area/city, product/store
// image). No phone numbers, ids other than the product id in the link, tokens
// or merchant/customer data.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'base64_image.dart';

// ─────────────────────────────────────────────────────────────────────────
// Link helper — the ONLY place the product link format is defined.
// ─────────────────────────────────────────────────────────────────────────
class ProductLink {
  ProductLink._();

  /// PLACEHOLDER. The final Smart Link domain/path will be changed here only.
  static const String base = 'https://offro.app/p/';

  /// Full link for [productId], or '' when there is no id.
  static String forProduct(String productId) {
    final id = productId.trim();
    return id.isEmpty ? '' : '$base${Uri.encodeComponent(id)}';
  }

  /// Link without the scheme, for compact display on the card.
  static String display(String url) => url.replaceFirst(RegExp(r'^https?://'), '');
}

// ─────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────
class ProductShareData {
  final String productId;
  final String name;
  final String storeName;
  final String locationLine; // "Area, City" / "City" / ''
  final num? salePrice;
  final num? origPrice;
  final String offerText;
  final String discountBadge; // "20% OFF" / ''
  final double storeRating; // 0 = not available
  final String imageSrc; // http(s) URL or data:image…; '' = none
  final String link; // '' when no product id

  const ProductShareData({
    required this.productId,
    required this.name,
    required this.storeName,
    required this.locationLine,
    required this.salePrice,
    required this.origPrice,
    required this.offerText,
    required this.discountBadge,
    required this.storeRating,
    required this.imageSrc,
    required this.link,
  });

  bool get showOrig =>
      origPrice != null && salePrice != null && origPrice! > salePrice!;

  /// Reads the same fields Product Details reads (same keys, same order).
  factory ProductShareData.fromProduct(Map<String, dynamic> p) {
    String s(Object? v) => (v ?? '').toString().trim();
    String firstNonEmpty(List<Object?> vs) {
      for (final v in vs) {
        final t = s(v);
        if (t.isNotEmpty) return t;
      }
      return '';
    }

    num? numOf(List<String> keys) {
      for (final k in keys) {
        final raw = p[k];
        if (raw == null) continue;
        if (raw is num) return raw;
        final parsed = num.tryParse(raw.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
        if (parsed != null && parsed > 0) return parsed;
      }
      return null;
    }

    double? ratingOf(Object? v) {
      final d = v is num ? v.toDouble() : double.tryParse(s(v));
      return (d != null && d > 0) ? d : null;
    }

    final storeObj = p['store'] is Map
        ? Map<String, dynamic>.from(p['store'] as Map)
        : <String, dynamic>{};

    final id = firstNonEmpty([p['_id'], p['id']]);
    final name = firstNonEmpty([p['title'], p['name']]);
    final storeName = firstNonEmpty([storeObj['store_name'], p['store_name']]);

    final city = firstNonEmpty([storeObj['city'], p['store_city'], p['city']]);
    final area = firstNonEmpty([storeObj['area'], p['store_area'], p['area']]);
    final loc = <String>[
      if (area.isNotEmpty) area,
      if (city.isNotEmpty && city.toLowerCase() != area.toLowerCase()) city,
    ].join(', ');

    final sale = numOf(['offer_price', 'sale_price', 'price', 'current_price']);
    final orig = numOf(['original_price', 'mrp', 'was_price', 'compare_price']);

    final offerText = firstNonEmpty([p['text'], p['offer_text'], p['offer'], p['discount']]);
    String badge = '';
    final m = RegExp(r'(\d+)%').firstMatch(offerText);
    if (m != null) {
      badge = '${m.group(1)}% OFF';
    } else if (sale != null && orig != null && orig > sale) {
      final pct = ((orig - sale) / orig * 100).round();
      if (pct >= 1) badge = '$pct% OFF';
    }

    final rating = ratingOf(storeObj['rating']) ??
        ratingOf(storeObj['admin_rating']) ??
        ratingOf(p['store_rating']) ??
        0.0;

    return ProductShareData(
      productId: id,
      name: name.isEmpty ? 'Product' : name,
      storeName: storeName,
      locationLine: loc,
      salePrice: sale,
      origPrice: orig,
      offerText: offerText,
      discountBadge: badge,
      storeRating: rating,
      imageSrc: _pickImage(p, storeObj),
      link: ProductLink.forProduct(id),
    );
  }

  /// Same priority as Product Details' hero image: store images first (when
  /// the product carries a store map), then the product's own image keys.
  static String _pickImage(Map<String, dynamic> p, Map<String, dynamic> storeObj) {
    bool ok(String v) => v.startsWith('http') || v.startsWith('data:image');
    for (final k in const ['image_url', 'image_thumb', 'image', 'image2']) {
      final v = (storeObj[k] ?? '').toString();
      if (ok(v)) return v;
    }
    for (final k in const ['image_url', 'image_thumb', 'image', 'logo_url', 'logo']) {
      final v = (p[k] ?? '').toString();
      if (ok(v)) return v;
    }
    return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Card widget — a product-focused version of the Home Store Card
// (_BannerStoresBlockState._storeCard in main.dart). Same design system:
//   • white card, radius 22, 1px #e0ece6 border, soft shadow, clipped image
//   • image 0.57 × card width, BoxFit.cover (fallback = #A9CDBA + initial)
//   • #3E5F55 filled pill over the image (here: the OffrO logo)
//   • #3a3a35 ribbon band directly under the image, 30 px, white 11/w800 caps
//     with emoji — used for the discount/offer, and only when there is one
//   • name 16/w800 #1a2e27; secondary text #8a9a93 / #5f6f68 12.5/w500
//   • rating chip: gold star + 13.5/w800 value
//   • #CDEBD6 pill (#2f5a47, 13/w800) | 1px divider | muted text row
// Rendered at fixed size on the cream app background (#FDFBF6). No QR code.
// ─────────────────────────────────────────────────────────────────────────
class ProductShareCard extends StatelessWidget {
  static const double cardWidth = 320;
  static const double outerPad = 20; // room for the card shadow
  static const double outerWidth = cardWidth + outerPad * 2;
  /// Store Card ratio: cardW * 0.57 (rounded).
  static const double imageHeight = 182;
  /// Store Card `_kBadgeRibbonH`.
  static const double ribbonHeight = 30;

  static const Color _green = Color(0xFF3E5F55);
  static const Color _ink = Color(0xFF1A2E27);
  static const Color _muted = Color(0xFF8A9A93);
  static const Color _muted2 = Color(0xFF5F6F68);
  static const Color _icon = Color(0xFF6B7C75);
  static const Color _line = Color(0xFFE6ECE9);

  final ProductShareData data;

  /// Already-decoded product photo, or null → Store Card style fallback.
  final ui.Image? photo;

  const ProductShareCard({super.key, required this.data, this.photo});

  /// ₹ with Indian digit grouping; whole numbers without decimals.
  static String inr(num v) {
    final whole = v == v.roundToDouble();
    final str = whole ? v.round().toString() : v.toStringAsFixed(2);
    final parts = str.split('.');
    var ip = parts[0];
    if (ip.length > 3) {
      final last3 = ip.substring(ip.length - 3);
      var rest = ip.substring(0, ip.length - 3);
      final groups = <String>[];
      while (rest.length > 2) {
        groups.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) groups.insert(0, rest);
      ip = '${groups.join(',')},$last3';
    }
    return '₹$ip${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  /// Ribbon text, or null when the product has no discount / offer (then no
  /// band is drawn at all — nothing is reserved).
  String? _ribbonLabel() {
    final badge = data.discountBadge; // "25% OFF" or ''
    final offer = data.offerText.trim();
    String norm(String v) => v.toLowerCase().replaceAll(RegExp(r'\s'), '');
    if (offer.isEmpty) return badge.isEmpty ? null : '🏷️ $badge';
    if (badge.isNotEmpty && norm(offer) == norm(badge)) return '🏷️ $badge';
    // Offer text already carries the percentage → it IS the ribbon text.
    if (badge.isEmpty || RegExp(r'\d+%').hasMatch(offer)) {
      return '🏷️ ${offer.toUpperCase()}';
    }
    return '🏷️ $badge • ${offer.toUpperCase()}';
  }

  Widget _logo({double height = 18}) => Image.asset(
        'assets/logo_white.png',
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text('OffrO',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
      );

  Widget _photoPanel() {
    if (photo != null) {
      return RawImage(
        image: photo,
        fit: BoxFit.cover,
        width: double.infinity,
        height: imageHeight,
        filterQuality: FilterQuality.high,
      );
    }
    // Same fallback as the Store Card's _storeFallback.
    final n = data.name.trim();
    return Container(
      color: const Color(0xFFA9CDBA),
      child: Center(
        child: Text(n.isNotEmpty ? n[0].toUpperCase() : 'P',
            style: const TextStyle(color: _green, fontSize: 28, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _ratingChip(double rating) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1),
            style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
      ]);

  @override
  Widget build(BuildContext context) {
    final d = data;
    final mainPrice = d.salePrice ?? d.origPrice;
    final ribbon = _ribbonLabel();
    final hasRating = d.storeRating > 0;
    final hasLoc = d.locationLine.isNotEmpty;

    return Material(
      color: const Color(0xFFFDFBF6), // app background (kBg)
      child: Padding(
        padding: const EdgeInsets.all(outerPad),
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE0ECE6), width: 1.0),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .09), blurRadius: 16, offset: const Offset(0, 5)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image with OffrO pill (Store Card's green pill position) ──
                SizedBox(
                  width: double.infinity,
                  height: imageHeight,
                  child: Stack(children: [
                    Positioned.fill(child: _photoPanel()),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .20), blurRadius: 5)],
                        ),
                        child: _logo(),
                      ),
                    ),
                  ]),
                ),

                // ── Ribbon band (only when there is a discount / offer) ──
                if (ribbon != null)
                  Container(
                    width: double.infinity,
                    height: ribbonHeight,
                    color: const Color(0xFF3A3A35),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(ribbon,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),

                // ── Info block ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _ink, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),

                      // Store name (category-line style) + store rating on the right
                      if (d.storeName.isNotEmpty || hasRating) ...[
                        const SizedBox(height: 2),
                        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Expanded(
                            child: d.storeName.isNotEmpty
                                ? Text(d.storeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _muted, fontSize: 12.5, fontWeight: FontWeight.w500))
                                : const SizedBox.shrink(),
                          ),
                          if (hasRating) ...[
                            const SizedBox(width: 6),
                            _ratingChip(d.storeRating),
                          ],
                        ]),
                      ],

                      if (hasLoc) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_rounded, size: 15, color: _icon),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(d.locationLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _muted2, fontSize: 12.5, fontWeight: FontWeight.w500)),
                          ),
                        ]),
                      ],

                      // Divider + price row (pill | divider | original price)
                      if (mainPrice != null) ...[
                        const SizedBox(height: 10),
                        Container(height: 1, color: _line),
                        const SizedBox(height: 10),
                        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCDEBD6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(inr(mainPrice),
                                style: const TextStyle(
                                    color: Color(0xFF2F5A47), fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                          if (d.showOrig) ...[
                            Container(
                              width: 1,
                              height: 22,
                              margin: const EdgeInsets.symmetric(horizontal: 11),
                              color: const Color(0xFFD5DDD9),
                            ),
                            Flexible(
                              child: Text(inr(d.origPrice!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF9E9E9E),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.lineThrough)),
                            ),
                          ],
                        ]),
                      ],

                      // Compact CTA + link (no band, no button)
                      const SizedBox(height: 10),
                      Container(height: 1, color: _line),
                      const SizedBox(height: 8),
                      const Text('Discover on OffrO',
                          style: TextStyle(color: _green, fontSize: 12.5, fontWeight: FontWeight.w800)),
                      if (d.link.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(ProductLink.display(d.link),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Rendering + sharing
// ─────────────────────────────────────────────────────────────────────────
class ProductShare {
  ProductShare._();

  /// Text used as the caption of the card AND as the plain-text fallback
  /// (same content the old text share had, plus the product link).
  static String caption(ProductShareData d) {
    return [
      '🛍️ ${d.name}',
      if (d.storeName.isNotEmpty) '📍 Store: ${d.storeName}',
      if (d.salePrice != null && d.salePrice! > 0) '💰 Offer Price: ${ProductShareCard.inr(d.salePrice!)}',
      if (d.offerText.isNotEmpty) '🎁 ${d.offerText}',
      d.link.isNotEmpty
          ? '\nDiscover on OffrO: ${d.link}'
          : '\nDownload OFFRO app to explore more deals!',
    ].join('\n');
  }

  /// Shares [product] as a branded PNG card + caption; falls back to the plain
  /// text share if the image can't be loaded / rendered / written / shared.
  ///
  /// [onInitiated] is called AT MOST ONCE, right before the first share sheet
  /// is opened (card or text fallback) — use it for the "share" analytics
  /// event so it fires once per tap and never twice when the fallback runs.
  ///
  /// Returns true when a share sheet was opened. Never throws.
  static Future<bool> share(
    BuildContext context,
    Map<String, dynamic> product, {
    VoidCallback? onInitiated,
  }) async {
    ProductShareData data;
    try {
      data = ProductShareData.fromProduct(product);
    } catch (_) {
      return false;
    }
    final text = caption(data);
    final subject = 'OFFRO – ${data.name}';
    final origin = _origin(context);

    var notified = false;
    void notify() {
      if (notified) return;
      notified = true;
      try { onInitiated?.call(); } catch (_) {}
    }

    Future<bool> textFallback() async {
      try {
        notify();
        await Share.share(text, subject: subject, sharePositionOrigin: origin);
        return true;
      } catch (_) {
        return false;
      }
    }

    String path;
    try {
      final bytes = await _renderPng(context, data).timeout(const Duration(seconds: 25));
      if (bytes == null || bytes.isEmpty) return textFallback();
      final dir = await getTemporaryDirectory();
      await _cleanOld(dir);
      final f = File('${dir.path}/offro_product_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bytes, flush: true);
      path = f.path;
    } catch (_) {
      return textFallback();
    }

    try {
      notify();
      await Share.shareXFiles(
        [XFile(path, mimeType: 'image/png', name: 'offro_product.png')],
        text: text,
        subject: subject,
        sharePositionOrigin: origin,
      );
      return true;
    } catch (_) {
      return textFallback();
    }
  }

  static Rect? _origin(BuildContext context) {
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || box.size.isEmpty) return null;
      return box.localToGlobal(Offset.zero) & box.size;
    } catch (_) {
      return null;
    }
  }

  /// Removes share PNGs left from earlier shares (older than 1 hour); the
  /// current one must survive until the target app has read it.
  static Future<void> _cleanOld(Directory dir) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      await for (final e in dir.list()) {
        if (e is File) {
          final n = e.uri.pathSegments.isNotEmpty ? e.uri.pathSegments.last : '';
          if (n.startsWith('offro_product_share_') && n.endsWith('.png')) {
            if ((await e.lastModified()).isBefore(cutoff)) await e.delete();
          }
        }
      }
    } catch (_) {}
  }

  static ImageProvider? _providerFor(String src) {
    if (src.startsWith('http')) return CachedNetworkImageProvider(src);
    if (src.startsWith('data:image')) return MemoryImage(decodeBase64ImageCached(src)); // may throw
    return null;
  }

  /// Fully decodes [provider] into a ui.Image (so the capture can never see a
  /// half-loaded picture). Returns null on error / timeout.
  static Future<ui.Image?> _loadPhoto(BuildContext context, ImageProvider provider) async {
    final done = Completer<ui.Image?>();
    // Decode no wider than the 3× capture needs — keeps big originals light.
    final resized = ResizeImage(provider, width: 1100, allowUpscaling: false);
    final stream = resized.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!done.isCompleted) done.complete(info.image.clone());
      },
      onError: (_, __) {
        if (!done.isCompleted) done.complete(null);
      },
    );
    stream.addListener(listener);
    try {
      return await done.future.timeout(const Duration(seconds: 12), onTimeout: () => null);
    } finally {
      stream.removeListener(listener);
    }
  }

  /// Builds the card in an off-screen overlay entry, waits for it to be
  /// painted and captures it. Returns null on any failure.
  static Future<Uint8List?> _renderPng(BuildContext context, ProductShareData data) async {
    if (!context.mounted) return null;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;

    // 1) Photo: when the product HAS an image it must load, otherwise bail out
    //    (→ text fallback) rather than share a card with a missing photo.
    ui.Image? photo;
    if (data.imageSrc.isNotEmpty) {
      final provider = _providerFor(data.imageSrc);
      if (provider == null) return null;
      photo = await _loadPhoto(context, provider);
      if (photo == null) return null;
    }
    if (!context.mounted) {
      photo?.dispose();
      return null;
    }

    // Brand logo is an asset — make sure it is decoded before painting.
    try {
      await precacheImage(const AssetImage('assets/logo_white.png'), context);
    } catch (_) {}
    if (!context.mounted) {
      photo?.dispose();
      return null;
    }

    final key = GlobalKey();
    final mq = MediaQuery.maybeOf(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: -6000, // far off-screen: laid out and painted, never visible
        top: 0,
        width: ProductShareCard.outerWidth,
        height: 1600,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: MediaQuery(
              // Same look for every user: ignore the phone's font-size setting.
              data: (mq ?? MediaQuery.of(ctx)).copyWith(textScaler: TextScaler.noScaling),
              child: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: key,
                  child: ProductShareCard(data: data, photo: photo),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame; // build + layout + paint
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await WidgetsBinding.instance.endOfFrame;

      for (final ratio in const [3.0, 2.0, 1.5]) {
        try {
          final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          if (boundary == null) {
            await WidgetsBinding.instance.endOfFrame;
            continue;
          }
          final img = await boundary.toImage(pixelRatio: ratio);
          try {
            final bd = await img.toByteData(format: ui.ImageByteFormat.png);
            if (bd != null) return bd.buffer.asUint8List();
          } finally {
            img.dispose();
          }
        } catch (_) {
          // not painted yet / out of memory at this ratio → wait a frame, retry smaller
          await WidgetsBinding.instance.endOfFrame;
        }
      }
      return null;
    } finally {
      entry.remove();
      // Release the photo only after the frame that drops the entry, so the
      // render object can never paint an already-disposed image.
      final toDispose = photo;
      if (toDispose != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => toDispose.dispose());
        WidgetsBinding.instance.scheduleFrame();
      }
    }
  }
}
