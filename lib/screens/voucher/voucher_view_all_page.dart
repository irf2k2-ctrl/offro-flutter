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

// ── OFFRO Brand Colors ──────────────────────────────────────────────────────
const _kPrimary = Color(0xFF3E5F55);
const _kLight   = Color(0xFFCDEBD6);
const _kAccent  = Color(0xFFA9CDBA);
const _kBeige   = Color(0xFFE7D7C8);
const _kBg      = Color(0xFFFDFBF6);
const _kText    = Color(0xFF2c3e35);
const _kMuted   = Color(0xFF6b8c7e);
const _kBorder  = Color(0xFFd4e8de);

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
                          Text("\${(voucher["distance_km"] as num?)?.toStringAsFixed(1) ?? ""}km away",
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
