import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../store/store_detail_page.dart';

// Enrich store data with deal info for detail page
Map<String,dynamic> _enrichStoreForDetail(Map<String,dynamic> s) {
  if (s['deals'] is List && (s['deals'] as List).isNotEmpty) return s;
  final offerStr = s['offer']?.toString() ?? '';
  if (offerStr.isNotEmpty && offerStr.toLowerCase() != 'null') {
    final discMatch = RegExp(r'(\d+)%').firstMatch(offerStr);
    final disc = discMatch?.group(1) ?? '0';
    s['deals'] = [
      {
        'title':       offerStr.contains(' — ') ? offerStr.split(' — ').last : offerStr,
        'description': '',
        'discount':    disc,
        'end_date':    '',
      }
    ];
  }
  return s;
}

class BannerStoresBlock extends StatefulWidget {
  final List<Map<String,dynamic>> banners;
  final List<Map<String,dynamic>> stores;
  final String token;
  final VoidCallback onViewAll;
  const BannerStoresBlock({
    required this.banners, required this.stores,
    required this.token,   required this.onViewAll,
  });
  @override State<BannerStoresBlock> createState() => BannerStoresBlockState();
}

class BannerStoresBlockState extends State<BannerStoresBlock> {
  final PageController _pc = PageController(initialPage: 49999);
  final ValueNotifier<int> _page = ValueNotifier<int>(0);
  Timer? _timer;

  @override List<Map<String,dynamic>> _localBanners = [];

  @override
  void initState() {
    super.initState();
    _startTimer();
    if (widget.banners.isEmpty) _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    try {
      final data = await Api.getAdminBanners().timeout(const Duration(seconds: 15));
      if (mounted && data.isNotEmpty) {
        setState(() => _localBanners = data);
        _startTimer();
      }
    } catch (_) {}
  }
  void _startTimer() {
    _timer?.cancel();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        _pc.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      });
    }
  }
  @override void didUpdateWidget(BannerStoresBlock old) {
    super.didUpdateWidget(old);
    if (old.banners.length != widget.banners.length) _startTimer();
  }
  @override void dispose() { _timer?.cancel(); _pc.dispose(); _page.dispose(); super.dispose(); }

  String _resolveImg(Map b) {
    for (final k in ["image_url","image"]) {
      final v = b[k]?.toString() ?? "";
      if (v.isNotEmpty) return v;
    }
    return "";
  }

  Widget _bannerImg(String imgUrl) {
    if (imgUrl.startsWith("data:image")) {
      try {
        return Image.memory(base64Decode(imgUrl.split(",").last),
          fit: BoxFit.fitWidth, alignment: Alignment.topCenter,
          width: double.infinity, gaplessPlayback: true);
      } catch (_) {}
    }
    if (imgUrl.startsWith("http")) {
      return CachedNetworkImage(imageUrl: imgUrl,
        fit: BoxFit.fitWidth, alignment: Alignment.topCenter,
        width: double.infinity,
        placeholder: (_, __) => Container(color: const Color(0xFF3E5F55)),
        errorWidget: (_, __, ___) => _gradBox());
    }
    return _gradBox();
  }
  Widget _gradBox() => Container(decoration: const BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFF1e3d35), Color(0xFF3E5F55)],
      begin: Alignment.topLeft, end: Alignment.bottomRight)));

  String _resolveStoreImg(Map s) {
    for (final k in ["image_url","image_thumb","_thumb","image"]) {
      final v = s[k]?.toString() ?? "";
      if (v.isNotEmpty) return v;
    }
    final imgs = s["images"];
    if (imgs is List && imgs.isNotEmpty) return imgs.first.toString();
    return "";
  }

  @override Widget build(BuildContext context) {
    final effectiveBanners = widget.banners.isNotEmpty ? widget.banners : _localBanners;
    final hasBanners = effectiveBanners.isNotEmpty;
    final hasStores  = widget.stores.isNotEmpty;
    if (!hasBanners && !hasStores) return const SizedBox.shrink();

    // Heights — 3:2 banner, 35-40% card overlap
    const double bannerH   = 320.0;
    const double overlapPx = 100.0; // ~31% of bannerH — cards peek but don't obscure banner
    const double cardH     = 212.0; // reduced ~22% — compact card height
    const double headerH   = 0.0;
    const double topPad    = 14.0;

    // Stores-only (no banner)
    if (!hasBanners) return _storesOnly(cardH, headerH);

    // Banner-only (no stores)
    if (!hasStores) {
      return Padding(
        padding: const EdgeInsets.only(top: topPad),
        child: SizedBox(height: bannerH, child: _bannerPageView(bannerH, effectiveBanners)));
    }

    // Both: banner + overlapping store cards
    final totalH = topPad + bannerH + cardH - overlapPx;
    return SizedBox(
      height: totalH,
      child: Stack(clipBehavior: Clip.none, children: [

        // ── Banner ──
        Positioned(top: topPad, left: 0, right: 0, height: bannerH,
          child: _bannerPageView(bannerH, effectiveBanners)),

        // ── Store cards overlap the bottom of the banner (no heading) ──
        Positioned(
          top: topPad + bannerH - overlapPx,
          left: 0, right: 0,
          child: SizedBox(
            height: cardH,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
              // +1 for the "See All" card at the end
              itemCount: (widget.stores.length > 8 ? 8 : widget.stores.length) + 1,
              itemBuilder: (ctx, i) {
                final storeCount = widget.stores.length > 8 ? 8 : widget.stores.length;
                if (i < storeCount) return _storeCard(ctx, widget.stores[i]);
                // Last card: "See All" — 50% height, centred vertically
                return GestureDetector(
                  onTap: widget.onViewAll,
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 52,
                      height: 90,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF3E5F55), width: 1.5),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFFe8f4ef),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, color: Color(0xFF3E5F55), size: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text("See All",
                          style: TextStyle(color: Color(0xFF3E5F55), fontSize: 9, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  // ── Banner PageView ──────────────────────────────────────────
  Widget _bannerPageView(double h, List<Map<String,dynamic>> banners) {
    final count = banners.length;
    return Stack(children: [
      PageView.builder(
        controller: _pc,
        clipBehavior: Clip.none,
        itemCount: count > 1 ? 99999 : count,
        onPageChanged: (i) => _page.value = i % count,
        itemBuilder: (_, i) {
          final b = banners[i % count];
          final imgUrl = _resolveImg(b);
          return GestureDetector(
            onTap: () {
              final link = b["link_url"]?.toString() ?? "";
              if (link.isNotEmpty) launchUrl(Uri.parse(link));
            },
            child: _bannerImg(imgUrl),
          );
        },
      ),
      // Dots
      if (banners.length > 1)
        Positioned(bottom: 100, left: 0, right: 0,
          child: ValueListenableBuilder<int>(
            valueListenable: _page,
            builder: (_, pg, __) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: pg == i ? 18 : 6, height: 6,
                  decoration: BoxDecoration(
                    color: pg == i ? Colors.white : Colors.white.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
          ),
        ),
    ]);
  }

  // ── Stores-only fallback (no banner) — no heading, See All as last card ──
  Widget _storesOnly(double cardH, double headerH) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: cardH,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          itemCount: (widget.stores.length > 8 ? 8 : widget.stores.length) + 1,
          itemBuilder: (ctx, i) {
            final storeCount = widget.stores.length > 8 ? 8 : widget.stores.length;
            if (i < storeCount) return _storeCard(ctx, widget.stores[i]);
            return GestureDetector(
              onTap: widget.onViewAll,
              child: Container(
                width: 52,
                margin: const EdgeInsets.only(right: 10, top: 18, bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF3E5F55), width: 1.5),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFe8f4ef),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded, color: Color(0xFF3E5F55), size: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text("See All",
                    style: TextStyle(color: Color(0xFF3E5F55), fontSize: 9, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Individual store card ────────────────────────────────────
  Widget _storeCard(BuildContext ctx, Map<String,dynamic> s) {
    final name      = s["store_name"]?.toString() ?? "";
    final cat       = s["category"]?.toString() ?? "";
    final rating    = (s["rating"] as num?)?.toDouble() ?? 0.0;
    final revCount  = (s["rating_count"] ?? s["review_count"] as num?)?.toInt() ?? 0;
    final dist      = (s["distance_km"] as num?)?.toDouble();
    final String? distTxt = (dist != null && dist > 0)
        ? (dist < 1.0 ? "${(dist * 1000).toStringAsFixed(0)} m" : "${dist.toStringAsFixed(1)} km")
        : null; // FIX4: null hides badge when GPS unknown
    final openTime  = s["open_time"]?.toString()  ?? "";
    final closeTime = s["close_time"]?.toString() ?? "";
    final now       = TimeOfDay.now();

    // Open/close status
    String statusLabel = "";
    String closingInfo = "";
    // ITEM4: treat "00:00" as "not configured" to avoid showing "Opens 12 AM • Closes 12 AM"
    final bool _timesConfigured = !(openTime == "00:00" && closeTime == "00:00")
        && !(openTime.isEmpty && closeTime == "00:00");
    if (closeTime.isNotEmpty && _timesConfigured) {
      try {
        final cParts    = closeTime.split(":");
        final closeH    = int.parse(cParts[0]);
        final closeM    = cParts.length > 1 ? int.parse(cParts[1]) : 0;
        final nowMins   = now.hour * 60 + now.minute;
        final closeMins = closeH * 60 + closeM;
        final cSuffix   = closeH >= 12 ? "PM" : "AM";
        final cH12      = closeH > 12 ? closeH - 12 : (closeH == 0 ? 12 : closeH);
        final cMinStr   = closeM > 0 ? ":${closeM.toString().padLeft(2,'0')}" : "";
        if (nowMins < closeMins) {
          statusLabel = "Open";
          closingInfo = "Closes $cH12$cMinStr $cSuffix";
        } else {
          statusLabel = "Closed";
          if (openTime.isNotEmpty) {
            final oParts  = openTime.split(":");
            final oH      = int.parse(oParts[0]);
            final oM      = oParts.length > 1 ? int.parse(oParts[1]) : 0;
            final oSuffix = oH >= 12 ? "PM" : "AM";
            final oH12    = oH > 12 ? oH - 12 : (oH == 0 ? 12 : oH);
            final oMinStr = oM > 0 ? ":${oM.toString().padLeft(2,'0')}" : "";
            closingInfo = "Opens $oH12$oMinStr $oSuffix";
          }
        }
      } catch (_) {}
    }

    // Resolve logo
    String logoSrc = s["logo_url"]?.toString() ?? s["logo"]?.toString() ?? s["logo_thumb"]?.toString() ?? "";
    if (logoSrc.isEmpty)
      logoSrc = s["image_url"]?.toString() ?? s["image"]?.toString() ?? s["image_thumb"]?.toString() ?? "";

    Widget logoWidget;
    if (logoSrc.startsWith("http")) {
      logoWidget = CachedNetworkImage(
        imageUrl: logoSrc,
        fit: BoxFit.cover,    // FIX 2: cover inside rounded square
        width: 60, height: 60,
        placeholder: (_, __) => Container(color: const Color(0xFFA9CDBA)),
        errorWidget: (_, __, ___) => _storeFallback(name));
    } else if (logoSrc.startsWith("data:image")) {
      try {
        logoWidget = Image.memory(base64Decode(logoSrc.split(",").last),
          fit: BoxFit.cover, width: 60, height: 60);
      } catch (_) { logoWidget = _storeFallback(name); }
    } else {
      logoWidget = _storeFallback(name);
    }


    // ── FIX4: Compute store badge with priority ──
    final bool _isNewStore = () {
      final ca = s["created_at"];
      if (ca == null) return false;
      try {
        DateTime? dt;
        if (ca is DateTime) dt = ca;
        else dt = DateTime.tryParse(ca.toString());
        if (dt == null) return false;
        return DateTime.now().difference(dt).inDays <= 30;
      } catch (_) { return false; }
    }();
    final double _storeRating = (s["rating"] as num?)?.toDouble() ?? 0.0;
    final int _revCount = (s["rating_count"] ?? s["review_count"] as num?)?.toInt() ?? 0;
    final String? _storeBadgeRaw = (s["badge"] as String?)?.trim().isNotEmpty == true ? s["badge"].toString().trim() : null;
    final bool _isTopRated  = _storeRating >= 4.3 && _revCount >= 5;
    final bool _isTrending  = s["is_trending"] == true;
    final bool _isPopular   = s["is_popular"] == true;
    final bool _isMustVisit = _storeBadgeRaw == "📍 MUST VISIT" || _storeBadgeRaw == "MUST VISIT";
    final bool _isLimitedOffer = _storeBadgeRaw == "⏳ LIMITED OFFER" || _storeBadgeRaw == "LIMITED OFFER";
    // Priority: Top Rated > Trending > Popular > Must Visit > Newly Added > Limited Offer > custom badge
    String? _activeBadge;
    if      (_isTopRated)    _activeBadge = "🏆 TOP RATED";
    else if (_isTrending)    _activeBadge = "🔥 TRENDING";
    else if (_isPopular)     _activeBadge = "⭐ POPULAR";
    else if (_isMustVisit)   _activeBadge = "📍 MUST VISIT";
    else if (_isNewStore)    _activeBadge = "🆕 NEWLY ADDED";
    else if (_isLimitedOffer) _activeBadge = "⏳ LIMITED OFFER";
    else if (_storeBadgeRaw != null && _storeBadgeRaw.isNotEmpty) _activeBadge = _storeBadgeRaw.toUpperCase();

    return GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => StoreDetailPage(
          store: _enrichStoreForDetail(Map<String,dynamic>.from(s)),
          token: widget.token, userName: ""))),
      child: Container(
        width: 152,
        margin: const EdgeInsets.only(right: 12, top: 8, bottom: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFe0ece6), width: 1.0),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: .07),
            blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [

            // ── Top row: distance badge (FIX3: only here) + heart + rating (FIX4) ──
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              // Distance badge — only location_top
              if (distTxt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFe8f5f0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on_rounded,
                      color: Color(0xFF3E5F55), size: 9),
                    const SizedBox(width: 2),
                    Text(distTxt,
                      style: const TextStyle(
                        color: Color(0xFF3E5F55),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700)),
                  ]),
                )
              else
                const SizedBox(width: 4),

              // FIX 6 restored: rating + heart in top row
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (rating > 0) ...[  
                  const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 12),
                  const SizedBox(width: 2),
                  Text(rating.toStringAsFixed(1),
                    style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.favorite_border_rounded,
                  color: Color(0xFF9e9e9e), size: 17),
              ]),
            ]),

            const SizedBox(height: 7),

            // ── FIX 2: Double circle logo ──
            // Outer circle: white bg + Offro green border (84px)
            Container(
              width: 78, height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFA9CDBA), width: 1.5),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Center(
                // Inner rounded image (62px, radius 16)
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 56, height: 56,
                    child: logoWidget,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 5),

            // ── Store name ──
            Text(name,
              style: const TextStyle(
                color: Color(0xFF1a2e27),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.2),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),

            if (cat.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(cat,
                style: const TextStyle(
                  color: Color(0xFF9e9e9e),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 4),

            // ── Divider ──
            Container(height: 1, color: const Color(0xFFf0f0f0)),

            const SizedBox(height: 3),

            // ── Open / Closed status row (always shown) ──
            Builder(builder: (_ctx) {
              final _displayLabel = statusLabel.isNotEmpty ? statusLabel : "";
              final _displayInfo  = closingInfo.isNotEmpty ? closingInfo
                  : "";  // FIX 2: empty = hide row when no times configured
              if (_displayLabel.isEmpty && _displayInfo.isEmpty) return const SizedBox.shrink();
              return Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, children: [
                  if (_displayLabel.isNotEmpty) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _displayLabel == "Open"
                        ? const Color(0xFFe8f5f0)
                        : const Color(0xFFfdf0f0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_displayLabel,
                      style: TextStyle(
                        color: _displayLabel == "Open"
                          ? const Color(0xFF3E5F55)
                          : const Color(0xFFc0392b),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800)),
                  ),
                  if (_displayLabel.isNotEmpty && _displayInfo.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    const Text("·",
                      style: TextStyle(color: Color(0xFF9e9e9e), fontSize: 12)),
                    const SizedBox(width: 5),
                  ],
                  if (_displayInfo.isNotEmpty) Flexible(
                    child: Text(_displayInfo,
                      style: const TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ]);
            }),

          ]),
            )),  // Expanded
            // ── Badge ribbon — pinned at bottom of all floating store cards ──
            if (_activeBadge != null)
              Container(
                width: double.infinity,
                height: 26,
                color: const Color(0xFF1a1a1a),
                alignment: Alignment.center,
                child: Text(
                  _activeBadge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _storeFallback(String name) => Container(
    color: const Color(0xFFA9CDBA),
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : "S",
      style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 28, fontWeight: FontWeight.w900))),
  );
}


// ═══════════════════════════════════════════════════════════════
// 3. PROMO SLIDER SECTION — merchant banners, compact (160px)
// ═══════════════════════════════════════════════════════════════