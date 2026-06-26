// lib/screens/detail/detail_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';
import '../qr/qr_page.dart';
import '../wallet/wallet_page.dart';
import '../payment/payment_success_screen.dart';

PageRoute _offroRoute(Widget w) => MaterialPageRoute(builder: (_) => w);


class DetailPage extends StatefulWidget {
  final Map store; final String token;
  const DetailPage({super.key,required this.store,required this.token});
  @override State<DetailPage> createState() => _DetailPageState();
}
class _DetailPageState extends State<DetailPage> with SingleTickerProviderStateMixin {
  Map<String,dynamic> _store = {};
  bool _loadingDetail = true;
  bool _isFav = false;
  double? _myRating;
  bool _ratingSubmitting = false;
  int _imgPage = 0;
  late TabController _tabCtrl;
  final PageController _imgPc = PageController();
  Timer? _autoScroll;
  // FIX 6: key for share card screenshot
  final GlobalKey _shareCardKey = GlobalKey();

  @override void initState() {
    super.initState();
    _tabCtrl = TabController(length:3, vsync:this);
    _store = Map<String,dynamic>.from(widget.store);
    _fetchFullStore();
  }

  void _startAutoScroll(int imgCount) {
    _autoScroll?.cancel();
    if (imgCount < 2) return;
    _autoScroll = Timer.periodic(const Duration(seconds:3), (_) {
      if (!mounted) return;
      final next = (_imgPage + 1) % imgCount;
      _imgPc.animateToPage(next, duration:const Duration(milliseconds:400), curve:Curves.easeInOut);
    });
  }

  @override void dispose(){ _tabCtrl.dispose(); _imgPc.dispose(); _autoScroll?.cancel(); super.dispose(); }

  Future<void> _fetchFullStore() async {
    try {
      final id = widget.store["_id"]?.toString() ?? "";
      if (id.isEmpty) { setState(()=>_loadingDetail=false); return; }
      final full = await Api.fetchStoreDetail(id);
      final fav  = await Api.isFavorite(widget.token, id);
      final myR  = await Api.getUserRating(widget.token, id);
      final imgs2 = (full["images"] as List?)?.map((x)=>x.toString()).toList() ?? [];
      final mainImg2 = (full["image_url"]?.toString() ?? "").isNotEmpty
                   ? full["image_url"].toString()
                   : full["image_thumb"]?.toString() ?? full["image"]?.toString() ?? "";
      final allImgs2 = [if(mainImg2.isNotEmpty) mainImg2, ...imgs2];
      if (mounted) setState(() {
        // Preserve client-computed distance_km (backend doesn't return it)
        final savedDist = _store["distance_km"];
        _store = Map<String,dynamic>.from(full);
        if (savedDist != null) _store["distance_km"] = savedDist;
        _isFav = fav;
        _myRating = (myR?["rating"] as num?)?.toDouble();
        _loadingDetail = false;
      });
      _startAutoScroll(allImgs2.length);
    } catch(_) { if(mounted) setState(()=>_loadingDetail=false); }
  }

  Future<void> _map() async {
    final lat=_store["latitude"]?.toString()??""; final lng=_store["longitude"]?.toString()??"";
    final addr=_store["address"]??"";
    final url=(lat.isNotEmpty&&lng.isNotEmpty)
        ? "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng"
        : "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}";
    await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication);
  }

  Future<void> _toggleFav() async {
    final id = _store["_id"]?.toString() ?? "";
    if(id.isEmpty) return;
    setState(()=>_isFav=!_isFav);
    await Api.toggleFavorite(widget.token, id);
  }

  Future<void> _submitRating(double r) async {
    if (_myRating != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("You've already rated this store."),
        backgroundColor: kMuted));
      return;
    }
    final id = _store["_id"]?.toString() ?? "";
    if (id.isEmpty) return;
    setState(() => _ratingSubmitting = true);
    try {
      final res = await Api.rateStore(widget.token, id, r);
      final newAvg = ((res["avg_rating"] ?? res["rating"]) as num?)?.toDouble() ?? r;
      debugPrint("[OFFRO] Rating saved: $r → avg $newAvg (store $id)");
      if (!mounted) return;
      setState(() {
        _myRating = r;
        _store = Map<String,dynamic>.from(_store)..["rating"] = newAvg;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("⭐ Rated ${r.toStringAsFixed(1)} stars! Thank you."),
        backgroundColor: kPrimary,
        duration: const Duration(seconds: 2),
      ));
      // Re-fetch from backend after 1s to confirm save + refresh avg
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      try {
        final full = await Api.fetchStoreDetail(id);
        final myR2 = await Api.getUserRating(widget.token, id);
        if (!mounted) return;
        setState(() {
          final savedDist = _store["distance_km"];
          _store = Map<String,dynamic>.from(full);
          if (savedDist != null) _store["distance_km"] = savedDist;
          if (myR2 != null) _myRating = (myR2["rating"] as num?)?.toDouble() ?? r;
        });
      } catch (e2) {
        debugPrint("[OFFRO] Post-rating refresh failed: \$e2");
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll("Exception: ", "");
      debugPrint("[OFFRO] Rating submit error: \$e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg.isNotEmpty ? msg : "Rating failed. Please try again."),
        backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _ratingSubmitting = false);
  }

  // FIX 6: Generate a share card image + share via share_plus
  Future<Uint8List?> _captureShareCard() async {
    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("[OFFRO] Share card capture failed: \$e");
      return null;
    }
  }

  Future<void> _share() async {
    final name     = _store["store_name"]?.toString() ?? "";
    final area     = _store["area"]?.toString() ?? "";
    final city     = _store["city"]?.toString() ?? "";
    final category = _store["category"]?.toString() ?? "";
    final offer    = _store["offer"]?.toString() ?? "";
    final id       = _store["_id"]?.toString() ?? "";
    final appLink  = "https://offro.app/store/\$id";
    final shareText = "🏪 \$name\n📍 \$area, \$city\n"
        "\${offer.isNotEmpty ? '🎁 \$offer\n' : ''}"
        "Discover deals & earn loyalty points on OFFRO!\n\$appLink";

    // Collect store images
    final imgs = ((_store["images"] as List?) ?? []).map((x) => x.toString()).toList();
    final mainImg = (_store["image_url"]?.toString() ?? "").isNotEmpty
        ? _store["image_url"].toString()
        : _store["image_thumb"]?.toString() ?? _store["image"]?.toString() ?? "";
    if (mainImg.isNotEmpty && !imgs.contains(mainImg)) imgs.insert(0, mainImg);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Center(child: Container(width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),

          // ── Share Card (capturable via RepaintBoundary) ──
          RepaintBoundary(
            key: _shareCardKey,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3E5F55), Color(0xFF253D35)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.15), blurRadius: 16, offset: const Offset(0,6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Store image hero
                if (imgs.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      height: 160, width: double.infinity,
                      child: imgs.first.startsWith("data:image")
                          ? Image.memory(base64Decode(imgs.first.split(",").last), fit: BoxFit.cover)
                          : imgs.first.startsWith("http")
                              ? Image.network(imgs.first, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFF253D35),
                                    child: const Center(child: Icon(Icons.store_rounded, color: Colors.white30, size: 48))))
                              : Container(color: const Color(0xFF253D35)),
                    ),
                  ),

                // Card body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // OFFRO branding top-right
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Text(name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.2),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text("OFFRO", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ),
                    ]),

                    const SizedBox(height: 6),

                    // Category badge
                    if (category.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCDEBD6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(category,
                          style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 10, fontWeight: FontWeight.w800)),
                      ),

                    // Location
                    Row(children: [
                      const Icon(Icons.location_on_rounded, color: Color(0xFFA9CDBA), size: 13),
                      const SizedBox(width: 4),
                      Expanded(child: Text("\$area, \$city",
                        style: const TextStyle(color: Color(0xFFA9CDBA), fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                    ]),

                    // Offer pill
                    if (offer.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7D7C8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_offer_rounded, color: Color(0xFF3E5F55), size: 14),
                          const SizedBox(width: 6),
                          Text(offer, style: const TextStyle(
                            color: Color(0xFF3E5F55), fontWeight: FontWeight.w900, fontSize: 13)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Divider
                    Container(height: 1, color: Colors.white12),
                    const SizedBox(height: 10),

                    // App tagline + link
                    Row(children: [
                      const Icon(Icons.download_rounded, color: Color(0xFFA9CDBA), size: 11),
                      const SizedBox(width: 5),
                      const Expanded(child: Text("Discover • Save • Earn  |  offro.app",
                        style: TextStyle(color: Color(0xFFA9CDBA), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.3))),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // ── WhatsApp share button (full width) ──
          _shareActionBtn(
            icon: Icons.chat_rounded,
            label: "Share on WhatsApp",
            bg: const Color(0xFF25D366),
            fg: Colors.white,
            onTap: () async {
              Navigator.pop(ctx);
              await Future.delayed(const Duration(milliseconds: 250));
              final bytes = await _captureShareCard();
              if (bytes != null) {
                final tmpDir = await getTemporaryDirectory();
                final file = File("\${tmpDir.path}/offro_share.png");
                await file.writeAsBytes(bytes);
                await Share.shareXFiles([XFile(file.path)], text: shareText);
              } else {
                final enc = Uri.encodeComponent(shareText);
                final wa = Uri.parse("whatsapp://send?text=\$enc");
                if (await canLaunchUrl(wa)) await launchUrl(wa, mode: LaunchMode.externalApplication);
              }
            },
          ),

          const SizedBox(height: 12),

          // Copy link — full width subtle button
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: shareText));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✓ Link copied to clipboard"), backgroundColor: kPrimary, duration: Duration(seconds: 2)));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.link_rounded, color: kPrimary, size: 18),
                const SizedBox(width: 8),
                const Text("Copy Link", style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // Styled full-width action button for share sheet
  Widget _shareActionBtn({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: bg.withValues(alpha: .25), blurRadius: 8, offset: const Offset(0,3))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
      ),
    );

  @override Widget build(BuildContext context){
    final s = _store;
    final deals = _loadingDetail ? <dynamic>[] : ((s["deals"] as List?) ?? <dynamic>[]);
    final city     = s['city']?.toString() ?? '';
    final area     = s['area']?.toString() ?? '';
    final address  = s['address']?.toString() ?? '';
    final phone    = s['phone']?.toString() ?? '';
    final desc     = (s['about']?.toString().isNotEmpty==true ? s['about']?.toString() : s['description']?.toString()) ?? '';
    final visitPts = (s['visit_points'] as num?)?.toInt() ?? 0;
    final rating   = (s['rating'] as num?)?.toDouble() ?? 0.0;
    final openTime = s['open_time']?.toString() ?? '';
    final closeTime= s['close_time']?.toString() ?? '';
    final costForTwo=s['cost_for_two']?.toString() ?? '';
    final dineIn   = s['dine_in'] == true;
    final category = s['category']?.toString() ?? '';
    final tags     = (s['tags'] as List?)?.map((t)=>t.toString()).toList() ?? [];
    final double? distKm = (s['distance_km'] as num?)?.toDouble();

    // FIX 4: Collect and resolve all images
    final imgs = (s["images"] as List?)?.map((x)=>x.toString()).toList() ?? [];
    // CDN-first: full image loaded only in detail screen
    final mainImg  = (s["image_url"]?.toString() ?? "").isNotEmpty
                   ? s["image_url"].toString()
                   : s["image_thumb"]?.toString() ?? s["image"]?.toString() ?? "";
    final mainImg2 = s["image2"]?.toString() ?? "";
    final resolveImg = (String u) => u.startsWith("/") ? "$kBaseUrl$u" : u;
    final allImgs = [
      if(mainImg.isNotEmpty)  resolveImg(mainImg),
      if(mainImg2.isNotEmpty) resolveImg(mainImg2),
      ...imgs.map(resolveImg),
    ];

    final scrH = MediaQuery.of(context).size.height;

    // Badge flags from store data
    final isTrending = s["is_trending"] == true;
    final isNew      = s["is_new_in_town"] == true || s["badge"] == "NEW";
    final isPopular  = s["is_popular"] == true || s["badge"] == "popular";
    final badgeLabel = isTrending ? "🔥 TRENDING"
                     : isNew      ? "✨ NEW"
                     : isPopular  ? "⭐ POPULAR"
                     : (s["badge"]?.toString().isNotEmpty == true) ? s["badge"].toString().toUpperCase()
                     : "";

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(fit: StackFit.expand, children: [

        // ── FULL SCREEN HERO IMAGE ──
        Positioned.fill(
          child: allImgs.isEmpty
            ? Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF2a4a40), Color(0xFF3E5F55)],
                  ),
                ),
                child: const Center(child: Icon(Icons.store_mall_directory_outlined, color: Colors.white24, size: 80)),
              )
            : PageView.builder(
                controller: _imgPc,
                itemCount: allImgs.length,
                onPageChanged: (i) => setState(() => _imgPage = i),
                itemBuilder: (_, i) {
                  final im = allImgs[i];
                  if (im.startsWith("data:image")) {
                    try {
                      return Image.memory(base64Decode(im.split(",").last),
                        fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true);
                    } catch(_) {}
                  }
                  if (im.startsWith("http") || im.startsWith(kBaseUrl)) {
                    return CachedNetworkImage(imageUrl: im, fit: BoxFit.cover,
                      width: double.infinity, height: double.infinity,
                      placeholder: (_, __) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF2a4a40), Color(0xFF3E5F55)]),
                        ),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white30))),
                      errorWidget: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF2a4a40), Color(0xFF3E5F55)]),
                        ),
                      ));
                  }
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF2a4a40), Color(0xFF3E5F55)]),
                    ),
                  );
                },
              ),
        ),

        // ── AMBIENT TOP GRADIENT (for readability of back button) ──
        Positioned(top: 0, left: 0, right: 0, child: Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: .65), Colors.transparent],
            ),
          ),
        )),

        // ── BOTTOM SHEET-STYLE INFO PANEL ──
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Drag handle
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),

              // ── STORE NAME + META ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(s["store_name"]?.toString() ?? "",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kText, height: 1.2))),
                    const SizedBox(width: 10),
                    if (rating > 0) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFB300)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: const Color(0xFFFFB300).withValues(alpha: .35), blurRadius: 8, offset: const Offset(0,2))],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 3),
                        Text(rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, color: kMuted, size: 13),
                    const SizedBox(width: 3),
                    Expanded(child: Text(
                      [area, city, address].where((x) => x.isNotEmpty).join(", "),
                      style: const TextStyle(color: kMuted, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (distKm != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: kLight, borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.near_me_rounded, color: kPrimary, size: 11),
                          const SizedBox(width: 3),
                          Text(distKm < 1 ? "${(distKm * 1000).round()}m" : "${distKm.toStringAsFixed(1)}km",
                            style: const TextStyle(color: kPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                  ]),
                  // Category + badge chips row
                  const SizedBox(height: 8),
                  Row(children: [
                    if (category.isNotEmpty) Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(category, style: const TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    if (badgeLabel.isNotEmpty) Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isTrending
                            ? [const Color(0xFFFF6B35), const Color(0xFFE55A2B)]
                            : isNew
                              ? [const Color(0xFF2E7D5E), const Color(0xFF1a5040)]
                              : [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                          color: (isTrending ? const Color(0xFFFF6B35) : isNew ? const Color(0xFF2E7D5E) : const Color(0xFFFFB300)).withValues(alpha: .35),
                          blurRadius: 6)],
                      ),
                      child: Text(badgeLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                  ]),
                  // Rating widget
                  const SizedBox(height: 8),
                  RatingWidget(
                    currentRating: _myRating,
                    submitting: _ratingSubmitting,
                    onRate: _myRating == null ? _submitRating : null,
                  ),
                ]),
              ),

              // ── GLOSSY TAB BAR ──
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFFE8F5EE), Color(0xFFCDEBD6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF3E5F55).withValues(alpha: .12), blurRadius: 8, offset: const Offset(0,2)),
                    const BoxShadow(color: Colors.white, blurRadius: 1, offset: Offset(0,-1)),
                  ],
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF5a8a7a), Color(0xFF3E5F55)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [BoxShadow(color: const Color(0xFF3E5F55).withValues(alpha: .4), blurRadius: 8, offset: const Offset(0,2))],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: kMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(text: "Offers"),
                    Tab(text: "About"),
                    Tab(text: "Directions"),
                  ],
                ),
              ),

              // ── TAB CONTENT ──
              SizedBox(
                height: scrH * 0.38,
                child: TabBarView(controller: _tabCtrl, children: [

                  // ── OFFERS TAB ──
                  _loadingDetail
                    ? _detailTabSkeleton()
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // QR Scan & Earn card
                        if (visitPts > 0)
                          GestureDetector(
                            onTap: () => Navigator.push(context, _offroRoute(QRPage(token: widget.token))),
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3E5F55), Color(0xFF5A8A7A)],
                                  begin: Alignment.centerLeft, end: Alignment.centerRight),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF3E5F55).withValues(alpha: .35), blurRadius: 14, offset: const Offset(0,4)),
                                ],
                              ),
                              child: Stack(children: [
                                // Glossy shine
                                Positioned(top: 0, left: 0, right: 0, child: Container(
                                  height: 28,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                      colors: [Colors.white.withValues(alpha: .2), Colors.transparent],
                                    ),
                                  ),
                                )),
                                Row(children: [
                                  Container(
                                    width: 52, height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: .18),
                                      borderRadius: BorderRadius.circular(14)),
                                    child: const Center(child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28))),
                                  const SizedBox(width: 14),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text("Earn $visitPts pts on checkout",
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    const Text("Tap to scan store QR at checkout",
                                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  ])),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: .22),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: .3)),
                                    ),
                                    child: const Text("Scan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
                                ]),
                              ]),
                            ),
                          ),
                        if (deals.isEmpty)
                          const Expanded(child: Center(child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_offer_outlined, color: kAccent, size: 48),
                              SizedBox(height: 12),
                              Text("No active offers", style: TextStyle(color: kMuted, fontSize: 14)),
                            ])))
                        else
                          Expanded(child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            children: deals.map((d) {
                              final dTitle  = d['title']?.toString() ?? "";
                              final dDesc   = d['description']?.toString() ?? "";
                              final dDisc   = d['discount']?.toString() ?? "0";
                              final dStart  = d['start_date']?.toString() ?? "";
                              final dEnd    = d['end_date']?.toString() ?? "";
                              final storeName = s["store_name"]?.toString() ?? "";
                              final storeCity = s["city"]?.toString() ?? "";
                              final storeArea = s["area"]?.toString() ?? "";
                              final storeId   = s["_id"]?.toString() ?? "";
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 14, offset: const Offset(0,4)),
                                    const BoxShadow(color: Colors.white, blurRadius: 1, offset: Offset(0,-1)),
                                  ],
                                  border: Border.all(color: kBorder.withValues(alpha: .5)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(children: [
                                    // Glossy top shine
                                    Positioned(top: 0, left: 0, right: 0, child: Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                          colors: [kLight.withValues(alpha: .6), Colors.transparent],
                                        ),
                                      ),
                                    )),
                                    Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                        // Glossy discount badge
                                        Container(
                                          width: 56, height: 56,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                                              colors: [Color(0xFF5a8a7a), Color(0xFF3E5F55)],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: .3), blurRadius: 8, offset: const Offset(0,3))],
                                          ),
                                          child: Center(child: Text("$dDisc%",
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(dTitle,
                                            style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w800)),
                                          if (dDesc.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(dDesc,
                                              style: const TextStyle(color: kMuted, fontSize: 11),
                                              maxLines: 2, overflow: TextOverflow.ellipsis),
                                          ],
                                          if (dStart.isNotEmpty || dEnd.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text("$dStart – $dEnd",
                                              style: const TextStyle(color: kMuted, fontSize: 10)),
                                          ],
                                        ])),
                                        GestureDetector(
                                          onTap: () {
                                            final shareText = [
                                              "🔥 $dDisc% OFF — $dTitle",
                                              if (dDesc.isNotEmpty) dDesc,
                                              "📍 $storeName${storeArea.isNotEmpty ? ', $storeArea' : ''}${storeCity.isNotEmpty ? ', $storeCity' : ''}",
                                              if (dStart.isNotEmpty || dEnd.isNotEmpty) "🗓 $dStart – $dEnd",
                                              "",
                                              "Discover more deals on OFFRO 👇",
                                              "https://offro.app/store/$storeId",
                                            ].join("\n");
                                            Share.share(shareText, subject: "OFFRO Deal – $dTitle");
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(9),
                                            decoration: BoxDecoration(
                                              color: kLight,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: .15), blurRadius: 4)],
                                            ),
                                            child: const Icon(Icons.share_rounded, color: kPrimary, size: 16)),
                                        ),
                                      ]),
                                    ),
                                  ]),
                                ),
                              );
                            }).toList(),
                          )),
                      ]),

                  // ── ABOUT TAB ──
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (desc.isNotEmpty) ...[
                        const Text("About", style: TextStyle(fontWeight: FontWeight.w800, color: kText, fontSize: 15)),
                        const SizedBox(height: 8),
                        Text(desc, style: const TextStyle(color: kMuted, fontSize: 13, height: 1.7)),
                        const SizedBox(height: 16),
                      ],
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (openTime.isNotEmpty && closeTime.isNotEmpty)
                          _chip(Icons.access_time_rounded, "$openTime – $closeTime", const Color(0xFFE8F5E9), kPrimary),
                        if (dineIn)
                          _chip(Icons.restaurant_rounded, "Dine-in", const Color(0xFFE3F2FD), Colors.blue),
                        if (costForTwo.isNotEmpty)
                          _chip(Icons.currency_rupee_rounded, "₹$costForTwo for two", kBeige, kText),
                      ]),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(spacing: 6, runSpacing: 6, children: tags.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kLight.withValues(alpha: .5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kAccent.withValues(alpha: .4)),
                          ),
                          child: Text("#$t", style: const TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                        )).toList()),
                      ],
                    ]),
                  ),

                  // ── DIRECTIONS TAB ──
                  Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Color(0xFF5a8a7a), Color(0xFF3E5F55)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0,6))],
                        ),
                        child: const Icon(Icons.map_rounded, color: Colors.white, size: 52)),
                      const SizedBox(height: 20),
                      if (area.isNotEmpty || city.isNotEmpty)
                        Text([area, city].where((x) => x.isNotEmpty).join(", "),
                          style: const TextStyle(color: kText, fontSize: 15, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(address,
                          style: const TextStyle(color: kMuted, fontSize: 13),
                          textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(
                        icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 18),
                        label: const Text("Open in Maps",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        onPressed: _map,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      )),
                    ]),
                  )),
                ]),
              ),
              // bottom safe area padding
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ]),
          ),
        ),

        // ── FLOATING BACK / SHARE / FAV BUTTONS (with blur) ──
        Positioned(top: 0, left: 0, right: 0,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              _imgBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
              const Spacer(),
              _imgBtn(Icons.share_rounded, _share),
              const SizedBox(width: 8),
              _imgBtn(
                _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                _toggleFav,
                color: _isFav ? Colors.red : Colors.white),
            ]),
          )),
        ),

        // ── IMAGE DOTS (bottom of image area) ──
        if (allImgs.length > 1)
          Positioned(
            bottom: scrH * 0.52,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(allImgs.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _imgPage == i ? 18 : 5, height: 5,
                decoration: BoxDecoration(
                  color: _imgPage == i ? Colors.white : Colors.white54,
                  borderRadius: BorderRadius.circular(3)),
              )),
            ),
          ),
      ]),
    );
  }

  Widget _imgBtn(IconData icon, VoidCallback onTap, {Color color=Colors.white})=>GestureDetector(
    onTap:onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .28),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .2), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 8)],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    ),
  );

  Widget _detailTabSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _skelBox(double.infinity, 82, r: 16),
        const SizedBox(height: 14),
        ...List.generate(3, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _skelBox(double.infinity, 68, r: 14),
        )),
      ]),
    );
  }

  Widget _skelBox(double w, double h, {double r = 8}) =>
    TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 0.85),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, v, __) => AnimatedOpacity(
        opacity: v,
        duration: const Duration(milliseconds: 600),
        child: Container(
          width: w, height: h,
          decoration: BoxDecoration(
            color: const Color(0xFFD1E0DA),
            borderRadius: BorderRadius.circular(r),
          ),
        ),
      ),
    );

  Widget _chip(IconData icon, String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [BoxShadow(color: fg.withValues(alpha: .12), blurRadius: 6, offset: const Offset(0,2))],
      border: Border.all(color: fg.withValues(alpha: .15), width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: fg, size: 13),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    ]));
}

// ─────────────────────── RATING WIDGET ───────────────────────
class RatingWidget extends StatefulWidget {
  final double? currentRating;
  final bool submitting;
  final void Function(double)? onRate;
  const RatingWidget({this.currentRating,required this.submitting,this.onRate});
  @override State<RatingWidget> createState()=>_RatingWidgetState();
}
class _RatingWidgetState extends State<RatingWidget>{
  double _hover=0;
  @override Widget build(BuildContext ctx){
    final rated = widget.currentRating!=null;
    return Row(children:[
      ...List.generate(5,(i){
        final filled = rated ? (i<(widget.currentRating!.round())) : (i<_hover);
        return GestureDetector(
          onTap: rated||widget.onRate==null ? null : (){widget.onRate!(i+1.0);},
          child:Padding(
            padding:const EdgeInsets.only(right:3),
            child:Icon(filled?Icons.star_rounded:Icons.star_outline_rounded,
              color:filled?const Color(0xFFFFD700):kMuted,size:22)));
      }),
      const SizedBox(width:8),
      if(widget.submitting) const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:kPrimary))
      else Text(
        rated?"Your rating: ${widget.currentRating!.toStringAsFixed(1)} ⭐":"Tap to rate",
        style:TextStyle(color:rated?kPrimary:kMuted,fontSize:12,fontWeight:rated?FontWeight.w700:FontWeight.w400)),
    ]);
  }
}


// ─────────────────────── QR SCANNER ───────────────────────
