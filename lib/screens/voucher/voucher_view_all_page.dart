// lib/screens/voucher/voucher_view_all_page.dart
// OFFRO — Discover Products: full list + premium WhatsApp share card

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../store/store_detail_page.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/fav_state.dart';
import '../detail/detail_page.dart';

// ── OFFRO Brand Colors ──────────────────────────────────────────────────────
const _kPrimary = Color(0xFF3E5F55);
const _kLight   = Color(0xFFCDEBD6);
const _kAccent  = Color(0xFFA9CDBA);
const _kBeige   = Color(0xFFE7D7C8);
const _kBg      = Color(0xFFFDFBF6);
const _kText    = Color(0xFF2c3e35);
const _kMuted   = Color(0xFF6b8c7e);
const _kBorder  = Color(0xFFd4e8de);

PageRoute _route(Widget w) => MaterialPageRoute(builder: (_) => w);

// ═══════════════════════════════════════════════════════════════════════════
//  VIEW ALL PAGE
// ═══════════════════════════════════════════════════════════════════════════
class VoucherViewAllPage extends StatefulWidget {
  final List<Map<String,dynamic>> vouchers;
  final String token;
  const VoucherViewAllPage({super.key, required this.vouchers, this.token = ""});
  @override State<VoucherViewAllPage> createState() => _VoucherViewAllPageState();
}

class _VoucherViewAllPageState extends State<VoucherViewAllPage> {
  String _filter = "";

  List<Map<String,dynamic>> get _filtered {
    if (_filter.isEmpty) return widget.vouchers;
    final q = _filter.toLowerCase();
    return widget.vouchers.where((v) =>
      (v["title"]?.toString() ?? "").toLowerCase().contains(q) ||
      (v["text"]?.toString()  ?? "").toLowerCase().contains(q) ||
      (v["offer_text"]?.toString() ?? "").toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _kText,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        title: const Text("Discover Products",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _kText)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              style: const TextStyle(color: _kText, fontSize: 14),
              cursorColor: _kPrimary,
              decoration: InputDecoration(
                hintText: "Search products...",
                hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: _kPrimary, size: 18),
                filled: true,
                fillColor: const Color(0xFFF2FAF5),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _kBorder)),
              ),
            ),
          ),
        ),
      ),
      body: _filtered.isEmpty
        ? _emptyState()
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) => _ProductCard(
              voucher: _filtered[i], colorIdx: i,
              token: widget.token,
            ),
          ),
    );
  }

  Widget _emptyState() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.local_activity_outlined, size: 72, color: _kAccent),
      const SizedBox(height: 16),
      Text(_filter.isEmpty ? "No products available" : "No results for '$_filter'",
        style: const TextStyle(color: _kMuted, fontSize: 16)),
      const SizedBox(height: 8),
      const Text("Check back soon for exciting offers!",
        style: TextStyle(color: _kMuted, fontSize: 13)),
    ],
  ));
}


// ═══════════════════════════════════════════════════════════════════════════
//  PRODUCT CARD (list item)
// ═══════════════════════════════════════════════════════════════════════════
// ─── Validity helpers ─────────────────────────────────────────────────────
DateTime? _parseValidityDate(String val) {
  if (val.isEmpty) return null;
  try {
    final iso = DateTime.tryParse(val.trim());
    if (iso != null) return iso;
  } catch (_) {}
  try {
    final parts = val.trim().split(RegExp(r'[/\-]'));
    if (parts.length == 3 && parts[0].length <= 2) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) return DateTime(y, m, d);
    }
  } catch (_) {}
  try {
    const months = {"jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
                    "jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12,
                    "january":1,"february":2,"march":3,"april":4,"june":6,
                    "july":7,"august":8,"september":9,"october":10,"november":11,"december":12};
    final parts = val.trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final d = int.tryParse(parts[0]);
      final m = months[parts[1].toLowerCase()];
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) return DateTime(y, m, d);
    }
  } catch (_) {}
  return null;
}

bool _isVoucherExpired(String validity) {
  final dt = _parseValidityDate(validity);
  if (dt == null) return false;
  return DateTime.now().isAfter(dt.add(const Duration(days: 1)));
}


/// Top-level share helper used by _ProductCard.
Future<void> _shareProduct(
  BuildContext context,
  String title,
  String offer,
  String valid,
  String logo,
  String phone,
  String merchant,
) async {
  final text = '${title.isNotEmpty ? title : "Product"}'
      '${offer.isNotEmpty    ? "\n🎁 $offer"           : ""}'
      '${merchant.isNotEmpty ? "\n🏪 $merchant"        : ""}'
      '${valid.isNotEmpty    ? "\nValid till: $valid"  : ""}'
      '\n\nDiscover deals & earn points on OFFRO!';
  await Share.share(text);
}

class _ProductCard extends StatelessWidget {
  final Map<String,dynamic> voucher;
  final int colorIdx;
  final String token;
  const _ProductCard({required this.voucher, required this.colorIdx, this.token = ""});

  static const List<Color> _badgeColors = [
    Color(0xFF3E5F55), Color(0xFF1a6640), Color(0xFF4a7c6f), Color(0xFF2d5a4e),
  ];

  @override
  Widget build(BuildContext context) {
    final title    = voucher["title"]?.toString()                    ?? "";
    final offer    = (voucher["text"] ?? voucher["offer_text"] ?? "").toString();
    final valid    = voucher["validity"]?.toString()                 ?? "";
    final logo     = (voucher["logo"] ?? voucher["logo_url"] ?? "").toString();
    final phone    = voucher["merchant_phone"]?.toString()           ?? "";
    final merchant = voucher["merchant_name"]?.toString()            ?? "";
    final price    = voucher["price"]?.toString()                    ?? "";
    final origPrice = voucher["original_price"]?.toString()          ?? "";
    final discount = voucher["discount"]?.toString()                 ?? "";
    final isExpired = _isVoucherExpired(valid);
    final badgeCol = isExpired ? const Color(0xFF888888) : _badgeColors[colorIdx % _badgeColors.length];

    return Opacity(
      opacity: isExpired ? 0.65 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExpired ? Colors.red.withValues(alpha:.4) : _kBorder,
            width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha:.08), blurRadius:16, offset: const Offset(0,5)),
            BoxShadow(color: Colors.white.withValues(alpha:.9), blurRadius:2, offset: const Offset(0,-1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Image banner (top, full width) ──
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                _LogoWidget(logoUrl: logo, size: 0, fullBleed: true),
                // Gradient overlay bottom
                Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha:.55)],
                    stops: const [0, 0.5, 1.0],
                  ),
                ))),
                // Glossy top shine
                Positioned(top: 0, left: 0, right: 0, child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha:.22), Colors.transparent],
                    ),
                  ),
                )),
                // Offer badge — top left
                if (offer.isNotEmpty || discount.isNotEmpty)
                  Positioned(top: 10, left: 10, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isExpired ? const Color(0xFF888888) : const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.20), blurRadius:6)],
                    ),
                    child: Text(discount.isNotEmpty ? "$discount% OFF" : "OFFER",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  )),
                // Expired badge
                if (isExpired)
                  Positioned(top: 10, right: 10, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700.withValues(alpha:.90),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text("EXPIRED", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  )),
                // Title on image bottom
                if (title.isNotEmpty)
                  Positioned(bottom: 10, left: 12, right: 12, child: Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black87)]),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),

            // ── Content below image ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Offer text
                if (offer.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeCol.withValues(alpha:.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: badgeCol.withValues(alpha:.25), width: 1),
                    ),
                    child: Text(offer,
                      style: TextStyle(color: badgeCol, fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                if (offer.isNotEmpty) const SizedBox(height: 10),

                // Price row
                if (price.isNotEmpty)
                  Row(children: [
                    Text("₹$price",
                      style: const TextStyle(color: _kText, fontSize: 20, fontWeight: FontWeight.w900)),
                    if (origPrice.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text("₹$origPrice",
                        style: const TextStyle(color: _kMuted, fontSize: 14,
                          decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 8),
                      if (discount.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5EE),
                            borderRadius: BorderRadius.circular(8)),
                          child: Text("You save ₹${(int.tryParse(origPrice) ?? 0) - (int.tryParse(price) ?? 0)}",
                            style: const TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ]),
                if (price.isNotEmpty) const SizedBox(height: 8),

                // Meta row: validity + merchant
                Row(children: [
                  if (valid.isNotEmpty) ...[
                    const Icon(Icons.calendar_today_rounded, color: _kMuted, size: 12),
                    const SizedBox(width: 4),
                    Text("Valid till $valid",
                      style: const TextStyle(color: _kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                  ],
                  if (merchant.isNotEmpty) ...[
                    const Icon(Icons.store_rounded, color: _kMuted, size: 12),
                    const SizedBox(width: 4),
                    Expanded(child: Text(merchant,
                      style: const TextStyle(color: _kMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis)),
                  ],
                ]),
                const SizedBox(height: 12),

                // Store info row
                if (merchant.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2FAF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.store_rounded, size: 13, color: _kPrimary),
                        const SizedBox(width: 5),
                        Expanded(child: Text(merchant,
                          style: const TextStyle(color: _kText, fontSize: 12, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                      if ((voucher["store_address"] ?? voucher["address"] ?? "").toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.location_on_rounded, size: 12, color: _kMuted),
                          const SizedBox(width: 4),
                          Expanded(child: Text(
                            (voucher["store_address"] ?? voucher["address"] ?? "").toString(),
                            style: const TextStyle(color: _kMuted, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                      if ((voucher["distance_km"] ?? "").toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.near_me_rounded, size: 12, color: _kMuted),
                          const SizedBox(width: 4),
                          Text('${(voucher["distance_km"] as num?)?.toStringAsFixed(1) ?? ""}km away',
                            style: const TextStyle(color: _kMuted, fontSize: 11)),
                        ]),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
                // Bottom action row
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => _shareProduct(context, title, offer, valid, logo, phone, merchant),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder, width: 1.2),
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.share_rounded, color: _kPrimary, size: 15),
                        SizedBox(width: 6),
                        Text("Share", style: TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    onTap: () {
                      final storeData = <String,dynamic>{
                        "_id":        (voucher["store_id"] ?? "").toString(),
                        "store_name": merchant,
                        "phone":      phone,
                        "address":    (voucher["store_address"] ?? voucher["address"] ?? "").toString(),
                        "image_url":  logo,
                        "category":   (voucher["category"] ?? "").toString(),
                      };
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StoreDetailPage(
                          store: storeData, token: token, userName: "")));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Color(0xFF5a8a7a), Color(0xFF3E5F55)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: const Color(0xFF3E5F55).withValues(alpha:.30), blurRadius:8, offset: const Offset(0,3))],
                      ),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.store_rounded, color: Colors.white, size: 15),
                        SizedBox(width: 6),
                        Text("View Store", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  )),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}


class _LogoWidget extends StatelessWidget {
  final String logoUrl;
  final double size;
  final bool fullBleed;
  const _LogoWidget({required this.logoUrl, required this.size, this.fullBleed = false});

  @override Widget build(BuildContext context) {
    if (logoUrl.isEmpty) return fullBleed ? _fullBleedPlaceholder() : _placeholder();

    Widget img;
    if (logoUrl.startsWith("data:image")) {
      try {
        final bytes = base64Decode(logoUrl.split(",").last);
        img = Image.memory(bytes,
          width: fullBleed ? double.infinity : size,
          height: fullBleed ? double.infinity : size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fullBleed ? _fullBleedPlaceholder() : _placeholder());
      } catch (_) { return fullBleed ? _fullBleedPlaceholder() : _placeholder(); }
    } else {
      final fullUrl = logoUrl.startsWith("http")
        ? logoUrl
        : "https://offro-backend-production.up.railway.app$logoUrl";
      img = Image.network(
        fullUrl,
        width: fullBleed ? double.infinity : size,
        height: fullBleed ? double.infinity : size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fullBleed ? _fullBleedPlaceholder() : _placeholder());
    }

    if (fullBleed) {
      // No ClipRRect — parent ClipRRect handles the rounding
      return SizedBox.expand(child: img);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: img,
    );
  }

  Widget _fullBleedPlaceholder() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF3E5F55), Color(0xFF2a4a40)],
      ),
    ),
    child: const Center(child: Text("🛍️", style: TextStyle(fontSize: 36))),
  );

  Widget _placeholder() => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha:.15),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text("🛍️",
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 28, height: 2.1)),
  );
}


// ═══════════════════════════════════════════════════
// ProductViewAllPage + ProductDetailCard + _VapSearchBar
// ═══════════════════════════════════════════════════
class ProductViewAllPage extends StatefulWidget {
  final List<Map<String,dynamic>> products; // initial list (may be partial)
  final String token;
  final String city; // city filter for full fetch
  const ProductViewAllPage({required this.products, this.token = "", this.city = ""});
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

  // Fetch full product list from API filtered by city (home may have cached a partial set)
  Future<void> _fetchAll() async {
    try {
      final fresh = await Api.getProductCards(city: widget.city);
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
                (_, i) => ProductDetailCard(
                  product: Map<String,dynamic>.from(_filtered[i]),
                  colorIdx: i,
                  token: widget.token,
                ),
                childCount: _filtered.length,
              ),
            ),
          ),
      ]),
    );
  }
}


// ─────────────────────── VOUCHER SUPPORT WIDGETS ───────────────────────

class ProductDetailCard extends StatelessWidget {
  final Map product;
  final int colorIdx;
  final String token;
  const ProductDetailCard({required this.product, this.colorIdx = 0, this.token = ""});

  static num? _numVal(Map v, List<String> keys) {
    for (final k in keys) {
      final raw = v[k];
      if (raw == null) continue;
      if (raw is num) return raw;
      final parsed = num.tryParse(raw.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
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
      gradient:LinearGradient(colors:[Color(0xFF3E5F55),Color(0xFF2a4a40)],begin:Alignment.topLeft,end:Alignment.bottomRight)),
  );

  void _openDetail(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProductDetailsPage(
        product: Map<String,dynamic>.from(product as Map),
        token: token,
      ),
    ));
  }

  @override Widget build(BuildContext context) {
    final title    = product["title"]?.toString() ?? "";
    final text     = product["text"]?.toString() ?? "";
    final storeName = (product["store"] is Map
        ? product["store"]["store_name"]
        : null)?.toString() ?? product["store_name"]?.toString() ?? "";
    final saleP = _numVal(product, ["offer_price","sale_price","price","current_price"]);
    final origP0 = _numVal(product, ["original_price","mrp","was_price","compare_price"]);
    final origP  = (origP0 != null && saleP != null && origP0 > saleP) ? origP0 : null;
    final discount = product["discount"]?.toString() ?? "";
    final isBestSeller = (product["best_seller"] == true) ||
        (product["tag"]?.toString().toLowerCase() == "best seller");
    final rating = (product["rating"] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (product["rating_count"] as num?)?.toInt() ?? 0;

    // Badge label + color
    String badgeLabel = "";
    Color  badgeColor = const Color(0xFFFF6B35);
    if (isBestSeller) {
      badgeLabel = "BEST SELLER";
      badgeColor = const Color(0xFFFFBF00);
    } else if (discount.isNotEmpty && discount != "0") {
      badgeLabel = "$discount% OFF";
      badgeColor = const Color(0xFFFF6B35);
    } else if (text.isNotEmpty) {
      badgeLabel = text.length > 10 ? text.substring(0,10) : text;
      badgeColor = kPrimary;
    }

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFd4e8de), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha:.08), blurRadius:12, offset: const Offset(0,4)),
            BoxShadow(color: Colors.white.withValues(alpha:.9),  blurRadius:1,  offset: const Offset(0,-1)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top: Product image with badge overlay ──
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: _imgWidget(),
              ),
            ),
            // Offer badge top-left
            if (badgeLabel.isNotEmpty)
              Positioned(top: 7, left: 7, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: badgeColor.withValues(alpha:.4), blurRadius:6)],
                ),
                child: Text(badgeLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                  maxLines: 1),
              )),
            // Heart icon top-right
            Positioned(top: 7, right: 7, child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:.85),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.12), blurRadius:4)],
              ),
              child: const Icon(Icons.favorite_border_rounded,
                color: Color(0xFF3E5F55), size: 14),
            )),
          ]),

          // ── Bottom: text content ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Product title
              Text(
                title.isNotEmpty ? title : (text.isNotEmpty ? text : "Special Offer"),
                style: const TextStyle(
                  color: Color(0xFF2c3e35), fontSize: 12, fontWeight: FontWeight.w800,
                  height: 1.2),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              if (storeName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(storeName,
                  style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (rating > 0 || ratingCount > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  ...List.generate(5, (i) => Icon(
                    i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFFFD700), size: 10)),
                  const SizedBox(width: 3),
                  Text(rating.toStringAsFixed(1),
                    style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 9, fontWeight: FontWeight.w700)),
                  if (ratingCount > 0) ...[
                    const SizedBox(width: 2),
                    Text("($ratingCount)",
                      style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 9)),
                  ],
                ]),
              ],
              if (saleP != null || origP != null) ...[
                const SizedBox(height: 5),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  if (origP != null) ...[
                    Text("₹${origP.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Color(0xFF9e9e9e), fontSize: 10, fontWeight: FontWeight.w500,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Color(0xFF9e9e9e))),
                    const SizedBox(width: 4),
                  ],
                  if (saleP != null)
                    Text("₹${saleP.toStringAsFixed(0)}",
                      style: const TextStyle(color: Color(0xFF2c7a4b), fontSize: 13, fontWeight: FontWeight.w900)),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

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