// lib/core/widgets/store_cards.dart
import 'dart:async';
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';
import 'package:offro_user/screens/detail/detail_page.dart';
import 'package:offro_user/screens/store/store_detail_page.dart';

PageRoute _offroRoute(Widget w) => MaterialPageRoute(builder: (_) => w);

// ── Open/close status helper ──────────────────────────────────────────────────
({bool? isOpen, String label, String sub}) _getStoreStatus(Map store) {
  final openTime  = store['open_time']?.toString()  ?? '';
  final closeTime = store['close_time']?.toString() ?? '';
  if (closeTime.isEmpty ||
      (openTime == '00:00' && closeTime == '00:00') ||
      (openTime.isEmpty  && closeTime == '00:00')) {
    return (isOpen: null, label: '', sub: '');
  }
  try {
    final now      = TimeOfDay.now();
    final nowMins  = now.hour * 60 + now.minute;
    final cParts   = closeTime.split(':');
    final cH       = int.parse(cParts[0]);
    final cM       = cParts.length > 1 ? int.parse(cParts[1]) : 0;
    final closeMins = cH * 60 + cM;
    final cSuffix   = cH >= 12 ? 'PM' : 'AM';
    final cH12      = cH > 12 ? cH - 12 : (cH == 0 ? 12 : cH);
    final cMinStr   = cM > 0 ? ':${cM.toString().padLeft(2, '0')}' : '';
    if (nowMins < closeMins) {
      return (isOpen: true,  label: 'Open',   sub: 'Closes $cH12$cMinStr $cSuffix');
    } else {
      String sub = '';
      if (openTime.isNotEmpty) {
        final oParts  = openTime.split(':');
        final oH      = int.parse(oParts[0]);
        final oM      = oParts.length > 1 ? int.parse(oParts[1]) : 0;
        final oSuffix = oH >= 12 ? 'PM' : 'AM';
        final oH12    = oH > 12 ? oH - 12 : (oH == 0 ? 12 : oH);
        final oMinStr = oM > 0 ? ':${oM.toString().padLeft(2, '0')}' : '';
        sub = 'Opens $oH12$oMinStr $oSuffix';
      }
      return (isOpen: false, label: 'Closed', sub: sub);
    }
  } catch (_) {
    return (isOpen: null, label: '', sub: '');
  }
}

// PromoSliderCard, NitHorizontalCard, ProductViewAllPage
class PromoSliderCard extends StatelessWidget {
  final Map<String,dynamic> slider;
  final String token;
  final bool squareCorners; // true = no rounding (full-width banner)
  final bool hideText;      // true = suppress title/subtitle overlay
  const PromoSliderCard({
    required this.slider,
    this.token = "",
    this.squareCorners = false,
    this.hideText = false,
    Key? key,
  }) : super(key: key);

  Widget _buildImg(String imgUrl) {
    if (imgUrl.isEmpty) return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF2c4a3e), Color(0xFF3E5F55)],
          begin: Alignment.topLeft, end: Alignment.bottomRight)));
    if (imgUrl.startsWith("data:image")) {
      try { return Image.memory(base64Decode(imgUrl.split(",").last),
        fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true); }
      catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }
    return CachedNetworkImage(
      imageUrl: imgUrl, fit: BoxFit.cover,
      width: double.infinity, height: double.infinity, memCacheWidth: 900,
      placeholder: (_, __) => Container(color: const Color(0xFF3E5F55)),
      errorWidget: (_, __, ___) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF2c4a3e), Color(0xFF3E5F55)],
            begin: Alignment.topLeft, end: Alignment.bottomRight))),
    );
  }

  @override Widget build(BuildContext context) {
    final imgUrl   = slider["image"]?.toString() ?? slider["image_url"]?.toString() ?? "";
    final storeId  = slider["store_id"]?.toString() ?? "";
    final title    = slider["title"]?.toString() ?? "";
    final subtitle = slider["subtitle"]?.toString() ?? slider["text"]?.toString() ?? "";

    final radius = squareCorners ? 0.0 : 20.0;

    return GestureDetector(
      onTap: storeId.isNotEmpty ? () async {
        try {
          final store = await Api.fetchStoreDetail(storeId);
          if (context.mounted) {
            Navigator.push(context, _offroRoute(
              StoreDetailPage(store: Map<String,dynamic>.from(store as Map), token: token, userName: "")));
          }
        } catch(_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
      } : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(fit: StackFit.expand, children: [
          // Full-bleed clear image
          _buildImg(imgUrl),

          // Downward gradient overlay: transparent top → dark bottom
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: .55),
                Colors.black.withValues(alpha: .80),
              ],
              stops: const [0.0, 0.40, 0.75, 1.0],
            ),
          ))),

          // Bottom text overlay — suppressed when hideText is true
          if (!hideText && (title.isNotEmpty || subtitle.isNotEmpty))
            Positioned(bottom: 14, left: 14, right: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (title.isNotEmpty)
                  Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900,
                      height: 1.2, shadows: [Shadow(blurRadius: 8, color: Colors.black87)]),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty && subtitle != title) ...[
                  const SizedBox(height: 3),
                  Text(subtitle,
                    style: TextStyle(color: Colors.white.withValues(alpha: .80), fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────── NIT HORIZONTAL CARD ───────────────────────
class NitHorizontalCard extends StatelessWidget {
  final Map<String,dynamic> store;
  const NitHorizontalCard({required this.store});

  Widget _img(String? url, String name) {
    if (url == null || url.isEmpty) return _fallback(name);
    if (url.startsWith("data:image")) {
      try { return Image.memory(base64Decode(url.split(",").last),fit:BoxFit.cover,width:double.infinity,height:double.infinity,gaplessPlayback:true); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }
    if (url.startsWith("http")) {
      return CachedNetworkImage(imageUrl:url,fit:BoxFit.cover,width:double.infinity,height:double.infinity,
        placeholder:(_,__)=>_fallback(name), errorWidget:(_,__,___)=>_fallback(name));
    }
    return _fallback(name);
  }
  Widget _fallback(String n) => Container(color:kAccent,child:Center(child:Text(n.isNotEmpty?n[0]:"S",style:const TextStyle(color:kPrimary,fontWeight:FontWeight.w900,fontSize:18))));

  @override Widget build(BuildContext context) {
    final name     = store["store_name"]?.toString() ?? "";
    final category = store["category"]?.toString() ?? "";
    // CDN-first: prefer image_url (CDN), fall back to image_thumb
    final imgUrl   = (store["image_url"]?.toString() ?? "").isNotEmpty ? store["image_url"].toString() : (store["image_thumb"]?.toString() ?? "");
    final double? distKm = (store["distance_km"] as num?)?.toDouble();

    return GestureDetector(
      onTap: () async {
        try {
          final storeDetail = await Api.fetchStoreDetail(store["_id"]?.toString() ?? "");
          if (context.mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => StoreDetailPage(store: Map<String,dynamic>.from(storeDetail as Map), token: "", userName: "")));
          }
        } catch (_) {
          // fallback: open with whatever data we already have
          if (context.mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => StoreDetailPage(store: Map<String,dynamic>.from(store as Map), token: "", userName: "")));
          }
        }
      },
      child: Container(
        width: 148,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.08), blurRadius:14, offset: const Offset(0,5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(fit: StackFit.expand, children: [
            // Full background image
            _img(imgUrl.isNotEmpty ? imgUrl : null, name),

            // Bottom gradient for readability
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: .65)],
                stops: const [0.0, 0.45, 1.0],
              ),
            ))),

            // Bottom ribbon
            Positioned(bottom: 0, left: 0, right: 0, child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, height: 1.2,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)]),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  if (category.isNotEmpty) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: .75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(category,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                  ),
                  if (distKm != null) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.near_me_rounded, color: Colors.white.withValues(alpha:.80), size: 9),
                    const SizedBox(width: 2),
                    Text(
                      distKm < 1 ? "${(distKm * 1000).round()}m" : "${distKm.toStringAsFixed(1)}km",
                      style: TextStyle(color: Colors.white.withValues(alpha:.80), fontSize: 9, fontWeight: FontWeight.w600)),
                  ],
                ]),
                // ── Open/close status ──
                Builder(builder: (_) {
                  final st = _getStoreStatus(store);
                  if (st.label.isEmpty) return const SizedBox.shrink();
                  final isOpen = st.isOpen == true;
                  return Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isOpen
                            ? const Color(0xFF6FFFA0).withValues(alpha: .5)
                            : const Color(0xFFFF9090).withValues(alpha: .5),
                          width: 0.8),
                      ),
                      child: Text(
                        st.sub.isNotEmpty ? '${st.label} · ${st.sub}' : st.label,
                        style: TextStyle(
                          color: isOpen ? const Color(0xFF6FFFA0) : const Color(0xFFFF9090),
                          fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                  );
                }),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────── PRODUCT VIEW ALL PAGE ───────────────────────
class ProductCard extends StatefulWidget {
  final Map product;
  final int colorIdx;
  const ProductCard({required this.product, this.colorIdx = 0});
  @override State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isFav = false;

  Map get product => widget.product;
  int  get colorIdx => widget.colorIdx;

  @override void initState() {
    super.initState();
    _loadFavState();
  }

  Future<void> _loadFavState() async {
    try {
      final vId = (widget.product["_id"] ?? widget.product["id"] ?? "").toString();
      if (vId.isNotEmpty) {
        final favs = await Prefs.getFavoriteProducts();
        if (mounted) setState(() => _isFav = favs.contains(vId));
      }
    } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
  }

  static const List<List<Color>> _palettes = [
    [Color(0xFFCDEBD6), Color(0xFFA9CDBA)],
    [Color(0xFFE7D7C8), Color(0xFFD4B896)],
    [Color(0xFFD6EAF8), Color(0xFFAED6F1)],
    [Color(0xFFFDE8E8), Color(0xFFF1ABAB)],
    [Color(0xFFFFF3CD), Color(0xFFFFD966)],
    [Color(0xFFEDE7F6), Color(0xFFCE93D8)],
  ];

  // Try to load store image (same chain as before, no gift box fallback)
  Widget _imgWidget() {
    final storeObj = product["store"];
    if (storeObj is Map) {
      for (final k in ["image2","image","img","photo"]) {
        final si = storeObj[k]?.toString() ?? "";
        if (si.startsWith("data:image")) {
          try { return Image.memory(base64Decode(si.split(",").last), fit:BoxFit.cover, width:double.infinity, height:double.infinity, gaplessPlayback:true); } catch(_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
        }
        final siUrl = si.startsWith("/") ? "$kBaseUrl$si" : si;
        if (siUrl.startsWith("http")) {
          return CachedNetworkImage(imageUrl:siUrl, fit:BoxFit.cover, width:double.infinity, height:double.infinity,
            placeholder:(_,__)=>Container(color:const Color(0xFFCDEBD6)),
            errorWidget:(_,__,___)=>_brandedBg());
        }
      }
    }
    for (final key in ["logo_url","logo_thumb","logo","image_url","image_thumb","image2","store_image2","image","photo","img"]) {
      final img = product[key]?.toString() ?? "";
      if (img.startsWith("data:image")) {
        try { return Image.memory(base64Decode(img.split(",").last), fit:BoxFit.cover, width:double.infinity, height:double.infinity, gaplessPlayback:true); } catch(_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
      }
      final imgUrl2 = img.startsWith("/") ? "$kBaseUrl$img" : img;
      if (imgUrl2.startsWith("http")) {
        return CachedNetworkImage(imageUrl:imgUrl2, fit:BoxFit.cover, width:double.infinity, height:double.infinity,
          placeholder:(_,__)=>Container(color:const Color(0xFFCDEBD6)),
          errorWidget:(_,__,___)=>_brandedBg());
      }
    }
    return _brandedBg();
  }

  Widget _brandedBg() => Container(
    decoration:const BoxDecoration(
      gradient:LinearGradient(colors:[Color(0xFF3E5F55),Color(0xFF3E5F55)],begin:Alignment.topLeft,end:Alignment.bottomRight)),
  );

  void _openDetail(BuildContext context) {
    final title    = product["title"]?.toString() ?? "";
    final text     = product["text"]?.toString() ?? "";
    final validity = product["validity"]?.toString() ?? "";
    final storeName = (product["store"] is Map ? product["store"]["store_name"] : null)?.toString()
        ?? product["store_name"]?.toString() ?? "";
    final pal = _palettes[colorIdx % _palettes.length];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // Banner image
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(height: 170, width: double.infinity, child: _imgWidget()),
          ),
          const SizedBox(height: 20),
          // Offer badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: pal, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(title.isNotEmpty ? title : "Special Offer",
              style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 15, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 14),
          if (text.isNotEmpty) Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 16, fontWeight: FontWeight.w700, height: 1.4)),
          if (storeName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.store_rounded, color: Color(0xFF6b8c7e), size: 15),
              const SizedBox(width: 5),
              Text(storeName, style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ],
          if (validity.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.calendar_today_rounded, color: Color(0xFF6b8c7e), size: 13),
              const SizedBox(width: 5),
              Text("Valid till: $validity", style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 12)),
            ]),
          ],
          const SizedBox(height: 24),
          // FIX 12: Replace "Got it" with "Download" button
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text("Close", style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3E5F55),
                side: const BorderSide(color: Color(0xFF3E5F55)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text("Download", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3E5F55),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final shareText = [
                  "🎁 OFFRO Product",
                  if (title.isNotEmpty) "Offer: $title",
                  if (text.isNotEmpty) text,
                  if (storeName.isNotEmpty) "Store: $storeName",
                  if (validity.isNotEmpty) "Valid till: $validity",
                  "Download OFFRO for exclusive deals!",
                ].join("\n");
                Share.share(shareText, subject: "OFFRO Product – $title");
              },
            )),
          ]),
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final title    = product["title"]?.toString() ?? "";
    final text     = product["text"]?.toString() ?? "";
    final storeName = (product["store"] is Map
        ? product["store"]["store_name"]
        : null)?.toString() ?? product["store_name"]?.toString() ?? "";
    final priceRaw = product["price"]?.toString() ?? "";
    final origRaw  = product["original_price"]?.toString() ?? product["mrp"]?.toString() ?? "";
    final discount = product["discount"]?.toString() ?? "";
    final isBestSeller = (product["best_seller"] == true) ||
        (product["tag"]?.toString().toLowerCase() == "best seller");

    String badgeLabel = "";
    Color  badgeColor = const Color(0xFFFF6B35);
    if (isBestSeller) { badgeLabel = "BEST SELLER"; badgeColor = const Color(0xFFFFBF00); }
    else if (discount.isNotEmpty && discount != "0") { badgeLabel = "$discount% OFF"; badgeColor = const Color(0xFFFF6B35); }

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: const BoxDecoration(color: Colors.black),
          child: Stack(fit: StackFit.expand, children: [
            // Full background image
            _imgWidget(),

            // Dark gradient overlay — bottom 60%
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: .72),
                  Colors.black.withValues(alpha: .88),
                ],
                stops: const [0.0, 0.30, 0.70, 1.0],
              ),
            ))),

            // Badge top-left
            if (badgeLabel.isNotEmpty)
              Positioned(top: 10, left: 10, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: badgeColor.withValues(alpha:.45), blurRadius:6)],
                ),
                child: Text(badgeLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .3)),
              )),

            // Favorite icon top-right — functional toggle
            Positioned(top: 10, right: 10,
              child: GestureDetector(
                onTap: () {
                  setState(() => _isFav = !_isFav);
                  // Persist to prefs (best-effort — visual update is instant)
                  try {
                    final vId = product["_id"]?.toString() ?? product["id"]?.toString() ?? "";
                    if (vId.isNotEmpty) Prefs.toggleFavoriteProduct(vId);
                  } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
                },
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _isFav
                      ? kPrimary.withValues(alpha: .92)
                      : Colors.white.withValues(alpha: .88),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.18), blurRadius:8)],
                  ),
                  child: Icon(
                    _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFav ? Colors.white : kPrimary,
                    size: 15,
                  ),
                ),
              ),
            ),

            // ── Bottom ribbon — solid black semi-transparent, taller (40% of card) ──
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .68),
                  borderRadius: const BorderRadius.only(
                    bottomLeft:  Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  // Price chip — shown when price exists
                  if (priceRaw.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: .18),
                          blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text("₹$priceRaw",
                            style: const TextStyle(
                              color: Color(0xFF3E5F55), fontSize: 12,
                              fontWeight: FontWeight.w900)),
                          if (origRaw.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text("₹$origRaw",
                              style: TextStyle(
                                color: const Color(0xFF3E5F55).withValues(alpha:.55),
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: const Color(0xFF3E5F55))),
                          ],
                        ],
                      ),
                    ),
                  ],
                  // Line 1: product/offer name
                  Text(
                    title.isNotEmpty ? title : (text.isNotEmpty ? text : "Special Offer"),
                    style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, height: 1.2),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // Line 2: store name
                  Text(
                    storeName.isNotEmpty ? storeName
                      : (product["area"]?.toString() ?? ""),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .80),
                      fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


// ─────────────────────── OTP SCREEN ───────────────────────

class ProductViewAllPage extends StatefulWidget {
  final List<Map<String,dynamic>> products; // initial list (may be partial)
  final String token;
  const ProductViewAllPage({required this.products, this.token = ""});
  @override State<ProductViewAllPage> createState()=>_ProductViewAllPageState();
}
class _ProductViewAllPageState extends State<ProductViewAllPage>{
  String _cat = "All";
  String _query = "";
  bool   _fetching = true;
  List<Map<String,dynamic>> _all = [];

  @override void initState() {
    super.initState();
    _all = List<Map<String,dynamic>>.from(widget.products); // show passed list instantly
    _fetchAll();
  }

  // Fetch full product list from API (home may have cached a partial set)
  Future<void> _fetchAll() async {
    try {
      final fresh = await Api.getProductCards();
      if (mounted) setState(() {
        _all = List<Map<String,dynamic>>.from(fresh);
        _fetching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _fetching = false);
    }
  }

  List<String> get _cats {
    final s = {"All"};
    for(final v in _all){
      final c = v["category"]?.toString() ?? "";
      if(c.isNotEmpty) s.add(c);
    }
    return s.toList();
  }
  List<Map<String,dynamic>> get _filtered {
    var list = _cat == "All"
        ? _all
        : _all.where((v) => (v["category"]?.toString() ?? "") == _cat).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((v) =>
        (v["title"]?.toString() ?? "").toLowerCase().contains(q) ||
        (v["text"]?.toString() ?? "").toLowerCase().contains(q) ||
        (v["store_name"]?.toString() ?? "").toLowerCase().contains(q) ||
        ((v["store"] is Map ? v["store"]["store_name"] : null)?.toString() ?? "").toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(slivers: [
        // Glossy warm-tone SliverAppBar
        SliverAppBar(
          expandedHeight: 100,
          pinned: true,
          backgroundColor: const Color(0xFFFDFBF6),
          foregroundColor: kText,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: _VapSearchBar(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            title: const Text("See All Products",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kText)),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFFFDFBF6), Color(0xFFE7D7C8), Color(0xFFFDFBF6)],
                ),
              ),
              child: Stack(children: [
                Positioned(top: 0, left: 0, right: 0, child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: .4), Colors.transparent],
                    ),
                  ),
                )),
              ]),
            ),
          ),
        ),
        // Category filter chips row
        SliverToBoxAdapter(child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(children: _cats.map((cat) => GestureDetector(
              onTap: () => setState(() => _cat = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _cat == cat ? kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _cat == cat ? kPrimary : kBorder, width: 1.2),
                  boxShadow: _cat == cat
                    ? [BoxShadow(color: kPrimary.withValues(alpha: .25), blurRadius: 8, offset: const Offset(0,2))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 4)],
                ),
                child: Text(cat, style: TextStyle(
                  color: _cat == cat ? Colors.white : kMuted,
                  fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            )).toList()),
          ),
        )),
        // Content
        if (_fetching && _all.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)))
        else if (_filtered.isEmpty)
          SliverFillRemaining(
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFE7D7C8), Color(0xFFFDFBF6)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_outlined, color: Color(0xFFB8A090), size: 40)),
              const SizedBox(height: 16),
              const Text("No products found",
                style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
            ])))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => ProductCard(
                  product: Map<String,dynamic>.from(_filtered[i]),
                  colorIdx: i,
                ),
                childCount: _filtered.length,
              ),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────── DETAIL PAGE ───────────────────────


// ── Search bar for ProductViewAllPage ──
class _VapSearchBar extends StatefulWidget {
  const _VapSearchBar();
  @override State<_VapSearchBar> createState() => _VapSearchBarState();
}
class _VapSearchBarState extends State<_VapSearchBar> {
  // Note: search is managed at page level; this just triggers setState via callback
  @override Widget build(BuildContext context) {
    // Find parent _ProductViewAllPageState via context
    final pageState = context.findAncestorStateOfType<_ProductViewAllPageState>();
    return Container(
      color: const Color(0xFFFDFBF6),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: TextField(
        onChanged: (v) {
          pageState?.setState(() => pageState._query = v);
        },
        style: const TextStyle(color: kText, fontSize: 13),
        cursorColor: kPrimary,
        decoration: InputDecoration(
          hintText: "Search products...",
          hintStyle: const TextStyle(color: kMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: kPrimary, size: 18),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary)),
        ),
      ),
    );
  }
}

// GridStoreCard, BigCarouselCard, TopStoreCard, StackedCards, StoreCardItem, NewInTownBadge
class GridStoreCard extends StatefulWidget {
  final Map store;
  const GridStoreCard({super.key, required this.store});
  @override State<GridStoreCard> createState() => _GridStoreCardState();
}
class _GridStoreCardState extends State<GridStoreCard> {
  int _imgIdx = 0;
  late final PageController _pc;

  @override void initState() { super.initState(); _pc = PageController(); }
  @override void dispose() { _pc.dispose(); super.dispose(); }

  Widget _imgAt(String img, String name) {
    if (img.startsWith("data:image")) {
      try { return Image.memory(base64Decode(img.split(",").last),fit:BoxFit.cover,width:double.infinity,height:double.infinity,gaplessPlayback:true); }
      catch(_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }
    if (img.startsWith("http")) {
      return CachedNetworkImage(imageUrl:img, fit:BoxFit.cover, width:double.infinity, height:double.infinity,
        placeholder:(_,__)=>_fallback(name),
        errorWidget:(_,__,___)=>_fallback(name));
    }
    return _fallback(name);
  }

  @override
  Widget build(BuildContext context) {
    final Map store = widget.store;
    final imgs   = (store["images"] as List?)?.map((x)=>x.toString()).toList() ?? [];
    // CDN-first: prefer image_url, fall back to image_thumb
    final img    = (store["image_url"]?.toString() ?? "").isNotEmpty
                 ? store["image_url"].toString()
                 : store["image_thumb"]?.toString() ?? store["image"]?.toString() ?? "";
    final img2   = store["image2"]?.toString() ?? "";
    final allImgs = [if(img!=null&&img.isNotEmpty) img, if(img2!=null&&img2.isNotEmpty) img2, ...imgs];
    final String name     = store["store_name"]?.toString() ?? "";
    final String category = store["category"]?.toString() ?? "";
    final String area     = store["area"]?.toString() ?? "";
    final String offerStr = (store["offer"] ?? "") as String;
    final int dealCount   = ((store["deal_count"] ?? 0) as num).toInt();
    final bool hasDeal    = offerStr.isNotEmpty && dealCount > 0;
    final double rating   = ((store["rating"] as num?)?.toDouble() ?? 0.0);
    final double? distKm  = (store["distance_km"] as num?)?.toDouble();
    final pm              = hasDeal ? RegExp(r'([\d.]+)%').firstMatch(offerStr) : null;
    final String dealLbl  = pm != null ? "${pm.group(1)}% OFF" : (hasDeal?"Deal":"");

    // Image layer: swipeable PageView if multiple images, else single
    Widget imgLayer = allImgs.isEmpty
        ? _fallback(name)
        : (allImgs.length == 1
            ? _imgAt(allImgs.first, name)
            : PageView.builder(
                controller: _pc,
                physics: const BouncingScrollPhysics(),
                itemCount: allImgs.length,
                onPageChanged: (i) => setState(() => _imgIdx = i),
                itemBuilder: (_, i) => _imgAt(allImgs[i], name),
              ));

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(fit:StackFit.expand, children:[
        imgLayer,
        // tiny dot indicator at top-right when multiple images
        if(allImgs.length > 1)
          Positioned(top:6,right:6,child:Container(
            padding:const EdgeInsets.symmetric(horizontal:5,vertical:2),
            decoration:BoxDecoration(color:Colors.black45,borderRadius:BorderRadius.circular(8)),
            child:Row(mainAxisSize:MainAxisSize.min, children:
              List.generate(allImgs.length,(i)=>Container(
                width: i==_imgIdx?10:5, height:4, margin:const EdgeInsets.symmetric(horizontal:1.5),
                decoration:BoxDecoration(
                  color: i==_imgIdx?Colors.white:Colors.white54,
                  borderRadius:BorderRadius.circular(2)),
              )),
            ),
          )),
        // gradient bottom
        Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
          gradient:LinearGradient(
            begin:Alignment.topCenter, end:Alignment.bottomCenter,
            colors:[Colors.transparent,Colors.transparent,Colors.black.withValues(alpha: .55),Colors.black.withValues(alpha: .88)],
            stops:const[0,.4,.7,1]),
        ))),
        // deal badge
        if(hasDeal) Positioned(top:8,left:8,child:Container(
          padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),
          decoration:BoxDecoration(color:Colors.deepOrange.withValues(alpha: .9),borderRadius:BorderRadius.circular(8)),
          child:Text("🔥 $dealLbl",style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w800)),
        )),
        // bottom info
        Positioned(bottom:0,left:0,right:0,child:Padding(
          padding:const EdgeInsets.fromLTRB(8,0,8,8),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
            Text(name,style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800,
              shadows:[Shadow(blurRadius:4,color:Colors.black87)]),maxLines:1,overflow:TextOverflow.ellipsis),
            const SizedBox(height:2),
            Row(children:[
              if(rating>0)...[
                const Icon(Icons.star_rounded,color:Color(0xFFFFD700),size:10),
                const SizedBox(width:2),
                Text(rating.toStringAsFixed(1),style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w700)),
                const SizedBox(width:4),
              ],
              if(category.isNotEmpty) Container(
                margin:const EdgeInsets.only(right:4),
                padding:const EdgeInsets.symmetric(horizontal:5,vertical:2),
                decoration:BoxDecoration(color:kPrimary.withValues(alpha: .80),borderRadius:BorderRadius.circular(6)),
                child:Text(category,style:const TextStyle(color:Colors.white,fontSize:8,fontWeight:FontWeight.w700)),
              ),
              if(distKm!=null) Container(
                margin:const EdgeInsets.only(right:4),
                padding:const EdgeInsets.symmetric(horizontal:5,vertical:2),
                decoration:BoxDecoration(color:Colors.black45,borderRadius:BorderRadius.circular(6)),
                child:Row(mainAxisSize:MainAxisSize.min,children:[
                  const Icon(Icons.near_me_rounded,color:Colors.white70,size:8),const SizedBox(width:2),
                  Text(distKm<1?"${(distKm*1000).round()}m away":"${distKm.toStringAsFixed(1)}km away",
                    style:const TextStyle(color:Colors.white,fontSize:8,fontWeight:FontWeight.w700)),
                ]),
              ),
              const Icon(Icons.location_on,color:Colors.white60,size:10),
              Expanded(child:Text(area,style:const TextStyle(color:Colors.white70,fontSize:9),overflow:TextOverflow.ellipsis)),
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _fallback(String name)=>Container(
    color:const Color(0xFF3E5F55),
    child:Center(child:Icon(Icons.store,color:kLight,size:36)),
  );
}


// ─────────────────────── BIG CAROUSEL CARD (New In Town) ───────────────────────
// StatefulWidget so we decode base64 ONCE in initState — never re-decodes during drag
class BigCarouselCard extends StatefulWidget {
  final Map store;
  const BigCarouselCard({super.key, required this.store});
  @override State<BigCarouselCard> createState() => _BigCarouselCardState();
}
class _BigCarouselCardState extends State<BigCarouselCard> {
  Uint8List? _imgBytes;

  @override void initState() {
    super.initState();
    _decodeImage();
  }

  @override void didUpdateWidget(BigCarouselCard old) {
    super.didUpdateWidget(old);
    if (old.store["image"] != widget.store["image"]) _decodeImage();
  }

  void _decodeImage() {
    final img = (widget.store["image_url"]?.toString() ?? "").isNotEmpty
              ? widget.store["image_url"].toString()
              : widget.store["image_thumb"]?.toString() ?? widget.store["image"]?.toString() ?? "";
    if (img.startsWith("data:image")) {
      try { _imgBytes = base64Decode(img.split(",").last); } catch(_) { _imgBytes = null; }
    } else {
      _imgBytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.store["image"]?.toString() ?? "";
    final Map store = widget.store;
    final String name     = store["store_name"]?.toString() ?? "";
    final String area     = store["area"]?.toString() ?? "";
    final String city     = store["city"]?.toString() ?? "";
    final String category  = store["category"]?.toString() ?? "";
    final String offerStr = (store["offer"] ?? "") as String;
    final int dealCount   = ((store["deal_count"] ?? 0) as num).toInt();
    final bool hasDeal    = offerStr.isNotEmpty && dealCount > 0;
    final pm              = hasDeal ? RegExp(r'([\d.]+)%').firstMatch(offerStr) : null;
    final String dealLbl  = pm != null ? "🔥 ${pm.group(1)}% OFF" : (hasDeal?"🔥 Deal":"");
    final double? distKm  = (store["distance_km"] as num?)?.toDouble();
    final double rating    = ((store["rating"] as num?)?.toDouble() ?? 0.0);

    Widget imgW;
    if (_imgBytes != null) {
      // Pre-decoded bytes — Image.memory just renders, zero decode work each frame
      imgW = Image.memory(_imgBytes!, fit:BoxFit.cover,
        width:double.infinity, height:double.infinity, gaplessPlayback:true);
    } else if (img.startsWith("http")) {
      imgW = CachedNetworkImage(imageUrl:img, fit:BoxFit.cover,
        width:double.infinity, height:double.infinity,
        placeholder:(_,__)=>_fallback(name),
        errorWidget:(_,__,___)=>_fallback(name));
    } else {
      imgW = _fallback(name);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow:[
          BoxShadow(color:Colors.black.withValues(alpha: .14),blurRadius:28,spreadRadius:0,offset:const Offset(0,8)),
          BoxShadow(color:Colors.white.withValues(alpha: .06),blurRadius:2,offset:const Offset(0,-1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(fit:StackFit.expand, children:[
          Positioned.fill(child: imgW),
          // gradient
          Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
            gradient:LinearGradient(
              begin:Alignment.topCenter, end:Alignment.bottomCenter,
              colors:[Colors.transparent,Colors.transparent,Colors.black.withValues(alpha: .7),Colors.black.withValues(alpha: .92)],
              stops:const[0,.45,.75,1]),
          ))),
          // ── Store badge (top-left) ──
          Builder(builder:(ctx){
            String badge = (store["badge"] ?? "").toString();
            // Fallback: if no badge set but store is marked new in town, use newly_added
            if (badge.isEmpty && store["is_new_in_town"] == true) badge = "newly_added";
            if (badge.isEmpty) return const SizedBox.shrink();
            final Map<String,Map<String,dynamic>> badgeMeta = {
              "new_store":    {"label":"New Store",    "color":const Color(0xFF1DB954)},
              "just_opened":  {"label":"Just Opened",  "color":const Color(0xFFE91E8C)},
              "newly_added":  {"label":"Newly Added",  "color":const Color(0xFF111111)},
              "trending":     {"label":"🔥 Trending",  "color":const Color(0xFFFF6B35)},
              "popular":      {"label":"⭐ Popular",   "color":const Color(0xFFFFB400)},
              "top_rated":    {"label":"🏆 Top Rated", "color":const Color(0xFF8B5CF6)},
              "must_visit":   {"label":"📍 Must Visit","color":const Color(0xFF3E5F55)},
              "limited_offer":{"label":"⏳ Limited",  "color":const Color(0xFFEF4444)},
            };
            final meta = badgeMeta[badge] ?? {"label": badge, "color": kPrimary};
            return Positioned(top:14,left:14,child:Container(
              padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
              decoration:BoxDecoration(
                color:(meta["color"] as Color),
                borderRadius:BorderRadius.circular(20),
                boxShadow:[BoxShadow(color:Colors.black38,blurRadius:6,offset:const Offset(0,2))]
              ),
              child:Row(mainAxisSize:MainAxisSize.min,children:[
                const Icon(Icons.fiber_new_rounded,color:Colors.white,size:13),
                const SizedBox(width:4),
                Text(meta["label"] as String,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:11,letterSpacing:0.3)),
              ]),
            ));
          }),
          // ── Deal badge (top-right) ──
          if(hasDeal) Positioned(top:14,right:14,child:Container(
            padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
            decoration:BoxDecoration(
              color:Colors.deepOrange.withValues(alpha: .93),
              borderRadius:BorderRadius.circular(20),
              boxShadow:[BoxShadow(color:Colors.black38,blurRadius:6,offset:const Offset(0,2))]
            ),
            child:Text(dealLbl,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:11)),
          )),
          // bottom info
          Positioned(bottom:0,left:0,right:0,child:Padding(
            padding:const EdgeInsets.fromLTRB(16,0,16,16),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
              Text(name,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900,
                shadows:[Shadow(blurRadius:6,color:Colors.black87)]),maxLines:1,overflow:TextOverflow.ellipsis),
              const SizedBox(height:4),
              Row(children:[
                const Icon(Icons.location_on,color:kLight,size:12),const SizedBox(width:3),
                Expanded(child:Text([area,city].where((x)=>x.isNotEmpty).join(", "),
                  style:const TextStyle(color:Colors.white70,fontSize:12),overflow:TextOverflow.ellipsis)),
              ]),
              // Rating + category + distance — all in one row
              const SizedBox(height:6),
              Row(children:[
                if(rating>0) Container(
                  margin:const EdgeInsets.only(right:6),
                  padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                  decoration:BoxDecoration(color:const Color(0xFFB8860B).withValues(alpha: .9),borderRadius:BorderRadius.circular(10)),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[
                    const Icon(Icons.star_rounded,color:Colors.white,size:12),const SizedBox(width:3),
                    Text(rating.toStringAsFixed(1),style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w800)),
                  ])),
                if(category.isNotEmpty) Container(
                  margin:const EdgeInsets.only(right:6),
                  padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                  decoration:BoxDecoration(color:kPrimary.withValues(alpha: .85),borderRadius:BorderRadius.circular(10)),
                  child:Text(category,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w700)),
                ),
                if(distKm!=null) Container(
                  margin:const EdgeInsets.only(right:6),
                  padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                  decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(10)),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[
                    const Icon(Icons.near_me_rounded,color:Colors.white,size:11),const SizedBox(width:3),
                    Text(distKm!<1?"${(distKm*1000).round()}m away":"${distKm.toStringAsFixed(1)}km away",style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w700)),
                  ])),
              ]),

            ]),
          )),
        ]),
      ),
    );
  }

  Widget _fallback(String name)=>Container(
    decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF3E5F55),Color(0xFF3E5F55)],begin:Alignment.topLeft,end:Alignment.bottomRight)),
    child:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      const Icon(Icons.store_mall_directory_outlined,size:64,color:kLight),
      const SizedBox(height:10),
      Text(name,style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.bold),textAlign:TextAlign.center),
    ])),
  );
} // end _BigCarouselCardState

// ─────────────────────── TOP STORE CARD (Horizontal list card) ───────────────────────
class TopStoreCard extends StatelessWidget {
  final Map store;
  const TopStoreCard({required this.store});

  String _resolveImg() {
    final s = store;
    final url = s["image_url"]?.toString() ?? "";
    final thumb = s["image_thumb"]?.toString() ?? "";
    final img = s["image"]?.toString() ?? "";
    final img2 = s["image2"]?.toString() ?? "";
    if (url.isNotEmpty) return url;
    if (thumb.isNotEmpty) return thumb;
    if (img.isNotEmpty) return img;
    if (img2.isNotEmpty) return img2;
    final imgs = s["images"];
    if (imgs is List && imgs.isNotEmpty) return imgs.first.toString();
    return "";
  }

  // Badge label priority: badge field > is_new_in_town > is_trending > is_popular
  String? _badgeLabel() {
    final badge = store["badge"]?.toString() ?? "";
    if (badge.isNotEmpty) return badge;
    if (store["is_new_in_town"] == true) return "New Store";
    if (store["is_trending"] == true) return "Trending";
    if (store["is_popular"] == true) return "Popular";
    // "NEWLY ADDED" if created within last 7 days
    try {
      final raw = store["created_at"]?.toString() ?? "";
      if (raw.isNotEmpty) {
        final dt = DateTime.parse(raw);
        if (DateTime.now().difference(dt).inDays < 10) return "newly_added";
      }
    } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    return null;
  }

  Color _badgeColor(String label) {
    switch (label.toLowerCase()) {
      case "new store": return const Color(0xFF2e7d52);
      case "trending":  return const Color(0xFFe67e22);
      case "popular":   return const Color(0xFF8e44ad);
      case "just added":return const Color(0xFF111111);
      default:          return const Color(0xFF3E5F55);
    }
  }

  Widget _buildImage(String imgSrc, String name) {
    if (imgSrc.isEmpty) return _fallback(name);
    if (imgSrc.startsWith("data:image")) {
      try { return Image.memory(base64Decode(imgSrc.split(",").last), fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true); }
      catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }
    final url = imgSrc.startsWith("/") ? "$kBaseUrl$imgSrc" : imgSrc;
    if (url.startsWith("http")) {
      return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
        placeholder: (_, __) => _fallback(name), errorWidget: (_, __, ___) => _fallback(name));
    }
    return _fallback(name);
  }

  @override Widget build(BuildContext context) {
    final name     = store["store_name"]?.toString() ?? "";
    final category = store["category"]?.toString() ?? "";
    final area     = store["area"]?.toString() ?? "";
    final city     = store["city"]?.toString() ?? "";
    final rating   = ((store["rating"] as num?)?.toDouble() ?? 0.0);
    final distKm   = (store["distance_km"] as num?)?.toDouble();
    final offerStr = (store["offer"] ?? "").toString();
    final hasDeal  = offerStr.isNotEmpty && ((store["deal_count"] ?? 0) as num) > 0;
    final discMatch = hasDeal ? RegExp(r'(\d+)%').firstMatch(offerStr) : null;
    final dealLabel = discMatch != null ? "${discMatch.group(1)}% OFF" : (hasDeal ? "Deal" : "");
    final imgSrc   = _resolveImg();
    final badgeLabel = _badgeLabel();

    // Open/close status (same logic as main.dart _storeCard)
    final _openTime  = store["open_time"]?.toString()  ?? "";
    final _closeTime = store["close_time"]?.toString() ?? "";
    final _now       = TimeOfDay.now();
    String _statusLabel = "Open";
    Color  _statusBg    = const Color(0xFFe8f5ee);
    Color  _statusTxt   = const Color(0xFF2e7d52);
    String _statusSub   = "";
    final bool _timesOk = !(_openTime == "00:00" && _closeTime == "00:00")
        && !(_openTime.isEmpty && _closeTime == "00:00");
    if (_closeTime.isNotEmpty && _timesOk) {
      try {
        final _cP    = _closeTime.split(":");
        final _cH    = int.parse(_cP[0]);
        final _cM    = _cP.length > 1 ? int.parse(_cP[1]) : 0;
        final _nowM  = _now.hour * 60 + _now.minute;
        final _clM   = _cH * 60 + _cM;
        final _cSuf  = _cH >= 12 ? "PM" : "AM";
        final _cH12  = _cH > 12 ? _cH - 12 : (_cH == 0 ? 12 : _cH);
        final _cMin  = _cM > 0 ? ":${_cM.toString().padLeft(2,'0')}" : "";
        if (_nowM < _clM) {
          _statusLabel = "Open";
          _statusBg    = const Color(0xFFe8f5ee);
          _statusTxt   = const Color(0xFF2e7d52);
          _statusSub   = "Closes $_cH12$_cMin $_cSuf";
        } else {
          _statusLabel = "Closed";
          _statusBg    = const Color(0xFFfce8e6);
          _statusTxt   = const Color(0xFFc0392b);
          if (_openTime.isNotEmpty) {
            final _oP   = _openTime.split(":");
            final _oH   = int.parse(_oP[0]);
            final _oM   = _oP.length > 1 ? int.parse(_oP[1]) : 0;
            final _oSuf = _oH >= 12 ? "PM" : "AM";
            final _oH12 = _oH > 12 ? _oH - 12 : (_oH == 0 ? 12 : _oH);
            final _oMin = _oM > 0 ? ":\${_oM.toString().padLeft(2,'0')}" : "";
            _statusSub  = "Opens $_oH12$_oMin $_oSuf";
          }
        }
      } catch (_) {}
    }

    // Location string
    final locationParts = [area, city].where((x) => x.isNotEmpty && x != "null").toList();
    final locationStr = locationParts.join(" · ");

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFd4e8de), width: 1.0),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 16, spreadRadius: 0, offset: const Offset(0,4)),
          BoxShadow(color: const Color(0xFFA9CDBA).withValues(alpha: .12), blurRadius: 8, offset: const Offset(0,2)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Left image ──
        Stack(children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(19)),
            child: SizedBox(width: 100, height: 90, child: _buildImage(imgSrc, name)),
          ),
          // Deal badge over image
          if (dealLabel.isNotEmpty)
            Positioned(top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFe74c3c),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(dealLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
        // ── Right info ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              // Name + badge chip
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(name,
                  style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 14, fontWeight: FontWeight.w800, height: 1.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (badgeLabel != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _badgeColor(badgeLabel),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(badgeLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              // Category · Area
              Text(
                [if (category.isNotEmpty) category, if (locationStr.isNotEmpty) locationStr].join(" · "),
                style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 11, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              // Rating badge + distance + open tag
              Row(children: [
                if (rating > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E5F55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(rating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 3),
                      const Icon(Icons.star_rounded, color: Colors.white, size: 11),
                    ]),
                  ),
                  const SizedBox(width: 6),
                ],
                if (distKm != null) ...[
                  const Icon(Icons.near_me_rounded, color: Color(0xFF6b8c7e), size: 11),
                  const SizedBox(width: 2),
                  Text(
                    distKm < 1 ? "${(distKm*1000).round()}m away" : "${distKm.toStringAsFixed(1)}km away",
                    style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 11, fontWeight: FontWeight.w500)),
                ],
                const Spacer(),
                // Dynamic open/close indicator — hidden when times not configured
                if (_closeTime.isNotEmpty && _timesOk)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_statusLabel,
                        style: TextStyle(color: _statusTxt, fontSize: 10, fontWeight: FontWeight.w700)),
                      if (_statusSub.isNotEmpty)
                        Text(_statusSub,
                          style: TextStyle(color: _statusTxt.withValues(alpha: .75), fontSize: 8, fontWeight: FontWeight.w500)),
                    ]),
                  ),
              ]),
            ]),
          ),
        ),
        // Chevron
        const Padding(
          padding: EdgeInsets.only(right: 12, top: 35),
          child: Icon(Icons.chevron_right_rounded, color: Color(0xFFa9cdba), size: 20),
        ),
      ]),
    );
  }

  Widget _fallback(String name) => Container(
    color: const Color(0xFFA9CDBA),
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : "S",
      style: const TextStyle(color: Color(0xFF3E5F55), fontWeight: FontWeight.w900, fontSize: 22))),
  );
}

// ─────────────────────── STACKED STORE CARDS ───────────────────────
// ignore: unused_element
class StackedCards extends StatelessWidget {
  final List<Map<String,dynamic>> stores;
  final int page;
  final PageController pc;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<Map> onTap;
  final VoidCallback onMore;
  final VoidCallback onCategory;
  final String token;

  const StackedCards({
    required this.stores, required this.page, required this.pc,
    required this.onPageChanged, required this.onTap,
    required this.onMore, required this.onCategory,
    this.token = "",
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardH = size.height * 0.74;

    return Stack(
      children: [
        // ── Page view with peek ──
        PageView.builder(
          controller: PageController(viewportFraction:0.90),
          itemCount: stores.length,
          onPageChanged: onPageChanged,
          itemBuilder: (_, i) {
            final store = stores[i];
            return Padding(
              // slight padding keeps card in frame with small peek of next
              padding: const EdgeInsets.only(left:8, right:8, top:4, bottom:0),
              child: GestureDetector(
                onTap: () => onTap(store),
                child: StoreCardItem(store: store, cardH: cardH, token: token),
              ),
            );
          },
        ),

        // ── Dot indicator ──
        Positioned(
          bottom: 100,
          left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(stores.length > 8 ? 8 : stores.length, (i) {
              final active = i == (page % (stores.length > 8 ? 8 : stores.length));
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal:3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(3),
                ));
            }),
          ),
        ),

        // ── Bottom action row ──
        Positioned(
          bottom: 24, left: 16, right: 16,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCategory,
                  icon: const Icon(Icons.grid_view_rounded, size: 16),
                  label: const Text("Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(vertical:13),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onMore,
                  icon: const Icon(Icons.person_outline_rounded, size: 16),
                  label: const Text("More", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLight,
                    foregroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(vertical:13),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── SINGLE STORE CARD ITEM ───────────────────────
class StoreCardItem extends StatefulWidget {
  final Map store;
  final double cardH;
  final String token;
  const StoreCardItem({super.key, required this.store, required this.cardH, this.token = ""});
  @override State<StoreCardItem> createState() => _StoreCardItemState();
}
class _StoreCardItemState extends State<StoreCardItem> {
  int _imgIdx = 0;
  late final PageController _pc;
  Timer? _imgTimer;
  bool _isFav = false;

  @override void initState() {
    super.initState();
    _pc = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
      _loadFav();
    });
  }

  Future<void> _loadFav() async {
    if (widget.token.isEmpty) return;
    final id = (widget.store["_id"] ?? widget.store["id"] ?? "").toString();
    if (id.isEmpty) return;
    try {
      final d = await Api.isFavorite(widget.token, id);
      if (mounted) setState(() => _isFav = d);
    } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
  }

  Future<void> _toggleFav() async {
    final id = (widget.store["_id"] ?? widget.store["id"] ?? "").toString();
    if (id.isEmpty || widget.token.isEmpty) return;
    setState(() => _isFav = !_isFav);
    try { await Api.toggleFavorite(widget.token, id); } catch (_) { setState(() => _isFav = !_isFav); }
  }

  void _startAutoScroll() {
    final store = widget.store;
    final img2s  = store["image2"]?.toString() ?? "";
    final imgs2 = (store["images"] as List?)?.map((x)=>x.toString()).toList() ?? [];
    final img = store["image"]?.toString() ?? "";
    final total = [if(img.isNotEmpty) img, if(img2s.isNotEmpty) img2s, ...imgs2].length;
    if (total < 2) return;
    _imgTimer?.cancel();
    _imgTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_pc.hasClients) return;
      final nextPage = (_pc.page?.round() ?? 0) + 1;
      _pc.animateToPage(nextPage % total, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override void dispose() { _imgTimer?.cancel(); _pc.dispose(); super.dispose(); }

  Widget _imgAt(String img, String name) {
    if (img.startsWith("data:image")) {
      try { return Image.memory(base64Decode(img.split(",").last),fit:BoxFit.cover,gaplessPlayback:true,width:double.infinity,height:double.infinity); }
      catch(_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }
    if (img.startsWith("http")) {
      return CachedNetworkImage(imageUrl:img, fit:BoxFit.cover, width:double.infinity, height:double.infinity,
        placeholder:(_,__)=>_fallback(name),
        errorWidget:(_,__,___)=>_fallback(name));
    }
    return _fallback(name);
  }

  @override
  Widget build(BuildContext context) {
    final Map store = widget.store;
    final double cardH = widget.cardH;
    final img = store["image"];
    final String storeName = store["store_name"]?.toString() ?? "";
    final String city      = store["city"]?.toString() ?? "";
    final String area      = store["area"]?.toString() ?? "";
    final String category  = store["category"]?.toString() ?? "";

    final bool isNew       = store["is_new_in_town"] == true;
    final String offerStr  = (store["offer"] ?? "") as String;
    final int dealCount    = ((store["deal_count"] ?? 0) as num).toInt();
    final bool hasDeal     = offerStr.isNotEmpty && dealCount > 0;
    final percentMatch     = hasDeal ? RegExp(r'([\d.]+)%').firstMatch(offerStr) : null;
    final String dealLabel = percentMatch != null ? "🔥 ${percentMatch?.group(1) ?? ""}% OFF" : (hasDeal ? "🔥 Deal" : "");
    final double rating    = (store["rating"] as num?)?.toDouble() ?? 0.0;

    final img2s  = store["image2"]?.toString();
    final imgs2 = (store["images"] as List?)?.map((x)=>x.toString()).toList() ?? [];
    final allImgs = [if(img!=null&&img.toString().isNotEmpty) img.toString(), if(img2s!=null&&img2s.isNotEmpty) img2s, ...imgs2];

    Widget imgWidget = allImgs.isEmpty
        ? _fallback(storeName)
        : (allImgs.length == 1
            ? _imgAt(allImgs.first, storeName)
            : PageView.builder(
                controller: _pc,
                physics: const BouncingScrollPhysics(),
                itemCount: allImgs.length,
                onPageChanged: (i) => setState(() => _imgIdx = i),
                itemBuilder: (_, i) => _imgAt(allImgs[i], storeName),
              ));

    return Container(
      height: cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 24, offset: const Offset(0,10)),
          BoxShadow(color: Colors.white.withValues(alpha: .05), blurRadius: 2, offset: const Offset(0,-1)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── store image ──
            imgWidget,

            // ── dot indicator (top center) if multiple images ──
            if (allImgs.length > 1)
              Positioned(top:12, left:0, right:0,
                child: Row(mainAxisAlignment:MainAxisAlignment.center,
                  children: List.generate(allImgs.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds:200),
                    width: i==_imgIdx ? 18 : 5, height: 5,
                    margin: const EdgeInsets.symmetric(horizontal:2),
                    decoration: BoxDecoration(
                      color: i==_imgIdx ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(3)),
                  )),
                ),
              ),

            // ── dark gradient overlay bottom ──
            Positioned.fill(child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: .15),
                    Colors.black.withValues(alpha: .75),
                    Colors.black.withValues(alpha: .90),
                  ],
                  stops: const [0.0, 0.35, 0.55, 0.80, 1.0],
                ),
              ),
            )),

            // ── top-left: OFFRO LOGO overlaid on card ──
            Positioned(
              top: 16, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal:10, vertical:6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .40),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: .2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  buildLogo(16, kLight),
                  const SizedBox(width:5),
                  RichText(text: const TextSpan(children: [
                    TextSpan(text:"Offr", style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:13)),
                    TextSpan(text:"O",    style:TextStyle(color:kLight,       fontWeight:FontWeight.w900,fontSize:13)),
                  ])),
                ]),
              ),
            ),

            // ── NEW IN TOWN badge removed (NIT fix 3)

            // ── deal badge moved to left (NIT fix 5) ──
            if (!isNew && hasDeal)
              Positioned(
                top: 16, left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal:10, vertical:5),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: .92),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(dealLabel, style: const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900)),
                ),
              ),

            // ── fav heart top-right ──
            Positioned(
              top: 14, right: 14,
              child: GestureDetector(
                onTap: _toggleFav,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isFav ? const Color(0xFFe74c3c) : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

            // ── bottom info panel ──
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // store name
                    Text(
                      storeName,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 26,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(blurRadius:8, color:Colors.black87)],
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // location row
                    Row(children: [
                      const Icon(Icons.location_on, color:kLight, size:13),
                      const SizedBox(width:3),
                      Text('$area${area.isNotEmpty && city.isNotEmpty ? ', ' : ''}$city',
                        style: const TextStyle(color:Colors.white70, fontSize:12)),
                    ]),

                    const SizedBox(height: 8),

                    // rating + category row (FIX 6: category next to rating)
                    Row(children: [
                      if (rating > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal:8,vertical:3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color:Colors.white24),
                          ),
                          child: Row(mainAxisSize:MainAxisSize.min, children:[
                            const Icon(Icons.star_rounded, color:Color(0xFFFFD700), size:13),
                            const SizedBox(width:3),
                            Text(rating.toStringAsFixed(1), style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w700)),
                          ]),
                        ),
                        const SizedBox(width:6),
                      ],
                      if (category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal:8,vertical:3),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: .85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(category, style: const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w600)),
                        ),
                    ]),

                    const SizedBox(height: 6),

                    // badges row
                    Row(children: [
                      if (isNew)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal:9,vertical:4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text("✨ Newly Added",
                            style: TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w800)),
                        ),
                      if (hasDeal)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal:10,vertical:4),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: .88),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(dealLabel,
                            style: const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w700)),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(String name) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF3E5F55), Color(0xFF3E5F55)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.store_mall_directory_outlined, size:72, color:kLight),
      const SizedBox(height:12),
      Text(name, style: const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.bold), textAlign:TextAlign.center),
    ])),
  );
}

// ─────────────────────── NEW IN TOWN BADGE ───────────────────────
class NewInTownBadge extends StatefulWidget {
  @override State<NewInTownBadge> createState() => _NewInTownBadgeState();
}
class _NewInTownBadgeState extends State<NewInTownBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => ScaleTransition(
    scale: _pulse,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: .5), blurRadius: 8, spreadRadius: 1)]),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Text("✨", style: TextStyle(fontSize: 11)),
        SizedBox(width: 3),
        Text("NEW IN TOWN", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ])));
}

// ─────────────────────── PAYMENT SUCCESS SCREEN ───────────────────────