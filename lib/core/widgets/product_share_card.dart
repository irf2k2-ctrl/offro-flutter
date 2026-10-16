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
// Card widget — a simple promotional preview, like a brand message card:
//   • card radius 22, clipped image running edge to edge (no border/margin)
//   • image 0.57 × card width, BoxFit.cover (fallback = #A9CDBA + initial)
//   • #3E5F55 filled pill over the image (here: the OffrO logo)
//   • green offer section under the image, white "25% OFF" text — only when
//     the product has a discount / offer
//
// Layout rule: the card holds ONLY the photo, the OffrO logo and the offer
// section. Product details (name, store, location, prices) and the clickable
// OffrO link are sent as the share TEXT — see ProductShare.caption.
// Rendered at fixed size, edge to edge, on an opaque white background (the
// corners outside the rounded card are white, never transparent). No QR code.
// ─────────────────────────────────────────────────────────────────────────
class ProductShareCard extends StatelessWidget {
  static const double cardWidth = 320;
  static const double outerPad = 0; // none: the photo runs edge to edge of the image
  /// Corner radius of the card. The pixels outside the rounded corners are
  /// painted with [_cornerFill] — never left transparent, because WhatsApp
  /// shows transparent PNG pixels as black.
  static const double cornerRadius = 22;
  static const Color _cornerFill = Colors.white;
  static const double outerWidth = cardWidth + outerPad * 2;
  /// Store Card ratio: cardW * 0.57 (rounded).
  static const double imageHeight = 182;

  static const Color _green = Color(0xFF3E5F55);

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

  /// Offer-section text: the discount ("25% OFF"); with no percentage but an
  /// offer text, that text. Null → no offer section.
  String? _offerLabel() {
    if (data.discountBadge.isNotEmpty) return data.discountBadge;
    final offer = data.offerText.trim();
    return offer.isNotEmpty ? offer.toUpperCase() : null;
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

  @override
  Widget build(BuildContext context) {
    final offer = _offerLabel();

    return Material(
      color: _cornerFill, // opaque: no transparent pixels anywhere in the PNG
      child: Padding(
        padding: const EdgeInsets.all(outerPad),
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cornerRadius),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image area: photo + OffrO pill only ──
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

                // ── Offer section (green) — only when there is a discount / offer ──
                if (offer != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    color: _green,
                    alignment: Alignment.center,
                    child: Text(offer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: 0.6)),
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

  /// WhatsApp (and Telegram-style) bold marker. share_plus sends plain text,
  /// so this is the only way to get bold in a WhatsApp caption. Other apps
  /// show the asterisks literally — kept to the two lines that matter.
  static String _bold(String t) {
    final clean = t.replaceAll('*', '').trim();
    return clean.isEmpty ? '' : '*$clean*';
  }

  /// Share text (WhatsApp caption / plain-text fallback): the product details
  /// as clean plain-text labels, no emojis, then a "View on OffrO" call to
  /// action and the full https:// link on its own line so chat apps make it
  /// clickable. A custom-text hyperlink ("View on OffrO" being the link) is not
  /// possible in a shared plain-text message — WhatsApp only auto-links URLs.
  static String caption(ProductShareData d) {
    final main = d.salePrice ?? d.origPrice;
    final save = (d.showOrig && main != null) ? (d.origPrice! - main) : 0;
    final details = <String>[
      if (d.storeName.isNotEmpty) 'Store: ${d.storeName}',
      if (d.locationLine.isNotEmpty) 'Location: ${d.locationLine}',
      if (main != null && main > 0)
        d.showOrig ? 'Offer Price: ${ProductShareCard.inr(main)}' : 'Price: ${ProductShareCard.inr(main)}',
      if (d.showOrig) 'Original Price: ${ProductShareCard.inr(d.origPrice!)}',
      if (save > 0) 'Save: ${ProductShareCard.inr(save)}',
    ];
    final title = _bold(d.name);
    return [
      if (title.isNotEmpty) title,
      if (details.isNotEmpty) '\n${details.join('\n')}',
      if (d.link.isNotEmpty) '\n${_bold('View on OffrO')}\n${d.link}',
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
