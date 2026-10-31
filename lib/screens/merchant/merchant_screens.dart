// lib/screens/merchant/merchant_screens.dart
// FIX 14: requires in pubspec.yaml:
//   printing: ^5.13.1
//   share_plus: ^10.0.3
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../main.dart' show MyApp;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/design/design.dart' show OffroBottomNav, OffroNavVariant, OffroColors, OffroText, OffroRadii, OffroShadows, OffroSpacing, OffroButton, OffroCard, OffroIcons, OffroIcon, OffroIconData, OffroTones;
import '../../core/constants/india_locations.dart';
import '../../core/services/api_service.dart';
import '../../core/services/error_mapper.dart';
import '../../core/models/offro_location.dart';
import '../../core/services/location_service.dart';
import '../../core/services/location_store.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';
import '../location/location_screen.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../payment/payment_success_screen.dart';
import 'products_phase2.dart';
import '../collab/collab_screens.dart' show CollabWorkspacePage;
// Round 7 Item 2: reuse the existing full-screen image viewer for the Merchant
// Deals list thumbnail tap-to-view — no duplicate viewer implementation.
import '../store/widgets/store_header.dart' show FullScreenImageViewer;
import '../../core/utils/navigation.dart';

/// Figma-style page header for Merchant screens: eyebrow + headline on the
/// cream background, flat (no elevation), optional trailing actions.
PreferredSizeWidget merchantHeaderBar({
  required String eyebrow,
  required String title,
  List<Widget>? actions,
  bool back = true,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    automaticallyImplyLeading: back,
    toolbarHeight: 84,
    centerTitle: false,
    titleSpacing: back ? 0 : OffroSpacing.gutter,
    backgroundColor: kMerchantBg,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(), style: OffroText.eyebrow.copyWith(color: OffroColors.sageStrong)),
        const SizedBox(height: 4),
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: OffroText.headline.copyWith(fontSize: 26)),
      ],
    ),
    actions: actions,
    bottom: bottom,
  );
}


/// PERMANENT HEADER REDESIGN: small circular filled "+" action button used
/// in place of the old large outlined "New X" buttons across merchant list
/// screens (My Stores / My Products / My Banners / etc). 42-44px perfect
/// circle, primary green fill, white icon.
Widget offroHeaderAddButton({
  required IconData icon,
  required VoidCallback onPressed,
  String tooltip = "Add",
  double size = 44,
}) {
  final btn = Material(
    color: kMerchantPrimary,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: SizedBox(
        width: size, height: size,
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    ),
  );
  return Tooltip(message: tooltip, child: btn);
}

// ══════════════════════════════════════════════════════════
// MERCHANT HOME PAGE — 3 section cards
// ══════════════════════════════════════════════════════════

class MerchantHomePage extends StatefulWidget {
  final String token;
  // Merchant ACCOUNT location header (device-only; never the store address).
  final String locationTitle;
  final String locationSubtitle;
  final VoidCallback? onLocationTap;
  final String merchantName;
  const MerchantHomePage({
    super.key,
    required this.token,
    this.merchantName = '',
    this.locationTitle = '',
    this.locationSubtitle = '',
    this.onLocationTap,
  });
  @override State<MerchantHomePage> createState() => _MerchantHomePageState();
}
class _MerchantHomePageState extends State<MerchantHomePage> {
  List<Map<String,dynamic>> _stores   = [];
  List<Map<String,dynamic>> _banners  = [];
  List<Map<String,dynamic>> _products = [];
  bool _loading   = true;
  bool _loadError = false;
  int? _freeLimit;  // admin-configured free product slots (from the backend; null until loaded)
  int  _slotsUsed = 0;   // qualifying products (backend count)

  // Data already on screen is kept while a refresh runs (no full-screen spinner after the
  // first load), and overlapping loads share one request instead of firing duplicates.
  bool _hasData = false;
  Future<void>? _inFlight;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load({int retryCount = 0}) {
    if (_inFlight != null && retryCount == 0) return _inFlight!;
    final f = _loadAll(retryCount: retryCount);
    if (retryCount == 0) {
      _inFlight = f;
      f.whenComplete(() { if (identical(_inFlight, f)) _inFlight = null; });
    }
    return f;
  }

  /// Refresh only the parts a sub-screen can have changed (instead of re-fetching everything
  /// every time the merchant navigates back). Silent: current data stays visible.
  Future<void> _refreshParts({bool stores = false, bool banners = false, bool products = false, bool slots = false}) async {
    try {
      final r = await Future.wait<dynamic>([
        stores   ? Api.getMerchantStores(widget.token).timeout(const Duration(seconds: 15))   : Future<dynamic>.value(null),
        banners  ? Api.getMerchantBanners(widget.token).timeout(const Duration(seconds: 10))  : Future<dynamic>.value(null),
        products ? Api.getMerchantProducts(widget.token).timeout(const Duration(seconds: 10)) : Future<dynamic>.value(null),
        slots    ? Api.getProductLimit(widget.token).timeout(const Duration(seconds: 10))     : Future<dynamic>.value(null),
      ]);
      if (!mounted) return;
      setState(() {
        if (r[0] is Iterable) _stores   = List<Map<String,dynamic>>.from(r[0] as Iterable);
        if (r[1] is Iterable) _banners  = List<Map<String,dynamic>>.from(r[1] as Iterable);
        if (r[2] is Iterable) _products = List<Map<String,dynamic>>.from(r[2] as Iterable);
        if (r[3] is Map) {
          final limitMap = Map<String,dynamic>.from(r[3] as Map);
          _freeLimit = (limitMap["free_limit"] as num?)?.toInt() ?? _freeLimit;
          _slotsUsed = (limitMap["used"] as num?)?.toInt() ?? _slotsUsed;
        }
      });
    } catch (e) {
      debugPrint('[MerchantHome] partial refresh error: $e');   // keep what is on screen
    }
  }

  Future<void> _loadAll({int retryCount = 0}) async {
    if (!_hasData) setState(()=>_loading=true);
    try {
      final storesFuture   = Api.getMerchantStores(widget.token).timeout(const Duration(seconds: 15));
      final bannersFuture  = Api.getMerchantBanners(widget.token).timeout(const Duration(seconds: 10));
      final productsFuture = Api.getMerchantProducts(widget.token).timeout(const Duration(seconds: 10));
      final limitFuture    = Api.getProductLimit(widget.token).timeout(const Duration(seconds: 10));

      final results = await Future.wait([storesFuture, bannersFuture, productsFuture, limitFuture]);
      if (mounted) setState((){
        _stores   = List<Map<String,dynamic>>.from(results[0] as Iterable);
        _banners  = List<Map<String,dynamic>>.from(results[1] as Iterable);
        _products = List<Map<String,dynamic>>.from(results[2] as Iterable);
        final limitMap = results[3] as Map<String,dynamic>;
        _freeLimit = (limitMap["free_limit"] as num?)?.toInt();
        _slotsUsed = (limitMap["used"] as num?)?.toInt() ?? 0;
        _loading  = false;
        _loadError = false;
        _hasData = true;
      });
    } catch(e) {
      debugPrint('[MerchantHome] _load error (attempt ${retryCount+1}): $e');
      if (retryCount == 0 && mounted) {
        await Future.delayed(const Duration(seconds: 2));
        return _loadAll(retryCount: 1);
      }
      if (mounted) setState(() { _loading = false; _loadError = !_hasData; });
    }
  }

  // FIX7: never treat load-error as "new merchant" — only show onboarding if stores truly empty
  //
  // BUG FIX: this used to be named _hasEligibleStore and included "draft"
  // (and other non-active statuses) in the list that counted as
  // "eligible", which meant a brand-new, never-subscribed store already
  // unlocked Banner/Product creation — the exact bug reported. Banner/
  // Product must stay locked until at least one of the merchant's stores
  // is genuinely subscribed AND admin-approved, which is the single
  // "active" value of stores.status (the same field this screen already
  // reads for the "X Active" count above, and the same field
  // routers/admin.py's approve_store() sets — no new status system).
  bool get _hasActiveStore => !_loadError && _stores.any((s) => s["status"] == "active");

  // Real counts only (from the same lists already loaded above).
  int get _activeStores => _stores.where((s) => s['status'] == 'active').length;
  int get _liveBanners => _banners.where((b) => (b['approval_status'] ?? b['status'] ?? '') == 'approved').length;
  int get _liveProducts => _products.where((v) => (v['approval_status'] ?? v['status'] ?? '').toString() == 'approved').length;

  String get _storeNote => _stores.isEmpty
      ? "No stores yet — tap to add your first"
      : "${_stores.length} Store${_stores.length > 1 ? 's' : ''} • $_activeStores Active";

  String get _bannerNote {
    if (!_hasActiveStore) return "Subscribe your store to create banners.";
    if (_banners.isEmpty) return "No banners yet — promote your store";
    final pend = _banners.where((b) {
      final st = (b['approval_status'] ?? b['status'] ?? '').toString();
      return st == 'pending' || st == 'pending_approval';
    }).length;
    final parts = <String>[];
    if (_liveBanners > 0) parts.add("$_liveBanners Live");
    if (pend > 0) parts.add("$pend Pending");
    return "${_banners.length} Banner${_banners.length > 1 ? 's' : ''} • ${parts.isEmpty ? 'Submitted' : parts.join(' · ')}";
  }

  String get _productNote {
    if (!_hasActiveStore) return "Subscribe your store to add products.";
    if (_products.isEmpty) return "No products yet — add your first product";
    final parts = <String>[if (_freeLimit != null) "$_slotsUsed/$_freeLimit free slots used"];
    if (_liveProducts > 0) parts.add("$_liveProducts Live");
    return parts.join('  ·  ');
  }

  void _lockedSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _hero() {
    final first = widget.merchantName.trim().split(' ').first;
    return Container(
      width: double.infinity,
      color: OffroColors.mint,
      padding: EdgeInsets.fromLTRB(OffroSpacing.gutter, MediaQuery.of(context).padding.top + 20, OffroSpacing.gutter, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        buildImageLogo(height: 26),
        const SizedBox(height: 32),
        Text('MERCHANT WORKSPACE', style: OffroText.eyebrow.copyWith(color: OffroColors.sageStrong)),
        const SizedBox(height: 4),
        Text(first.isEmpty ? 'Welcome back' : 'Welcome back, $first', style: OffroText.headline),
        if (widget.onLocationTap != null) ...[
          const SizedBox(height: 14),
          InkWell(
            onTap: widget.onLocationTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const OffroIcon(OffroIcons.pin, size: 16, color: OffroColors.primary, filled: true),
                const SizedBox(width: 8),
                Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.locationTitle.isEmpty ? 'Select location' : widget.locationTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: OffroText.value.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
                  if (widget.locationSubtitle.isNotEmpty)
                    Text(widget.locationSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: OffroText.caption.copyWith(color: OffroColors.secondarySolid)),
                ])),
                const SizedBox(width: 6),
                const OffroIcon(OffroIcons.chevron, size: 13, color: OffroColors.secondarySolid),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _statTile(String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: OffroColors.surface,
        borderRadius: BorderRadius.circular(OffroRadii.card),
        boxShadow: OffroShadows.card,
      ),
      child: Column(children: [
        Text(value, style: OffroText.title.copyWith(fontSize: 20)),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: OffroText.caption.copyWith(color: OffroColors.secondarySolid)),
      ]),
    ),
  );

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kMerchantBg,
    body: _loading
      ? const Center(child:CircularProgressIndicator(color:kMerchantPrimary))
      // FIX7: show retry instead of new-merchant flow when network failed
      : (_loadError && _stores.isEmpty)
          ? Center(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off_rounded, color: kMerchantMuted, size: 48),
                const SizedBox(height: 16),
                Text("Couldn't load your dashboard", style: OffroText.title.copyWith(fontSize: 18)),
                const SizedBox(height: 6),
                Text("Check your connection and try again", style: OffroText.body),
                const SizedBox(height: 20),
                OffroButton.small(label: "Retry", onPressed: () => _load()),
              ]),
            ))
      : RefreshIndicator(
          onRefresh:_load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _hero(),
              Transform.translate(
                offset: const Offset(0, -14),
                child: Padding(
                  padding: OffroSpacing.gutterH,
                  child: Row(children: [
                    _statTile('$_activeStores', 'Live stores'),
                    const SizedBox(width: 8),
                    _statTile('$_liveBanners', 'Live banners'),
                    const SizedBox(width: 8),
                    _statTile('$_liveProducts', 'Live products'),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 14, OffroSpacing.gutter, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MANAGE YOUR BUSINESS', style: OffroText.eyebrow.copyWith(color: OffroColors.sageStrong)),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: OffroIcons.store,
                    bgColor: OffroColors.mint,
                    title: "My Store",
                    subtitle: _storeNote,
                    onTap: () => Navigator.push(context, appRoute(MerchantStoresPage(token: widget.token))).then((_) => _refreshParts(stores: true, slots: true)),
                  ),
                  const SizedBox(height: 12),
                  // Banner card — locked until a subscribed+active store exists
                  _SectionCard(
                    icon: OffroIcons.play,
                    bgColor: OffroColors.beige,
                    title: "My Banner",
                    locked: !_hasActiveStore,
                    subtitle: _bannerNote,
                    onTap: _hasActiveStore
                      ? () => Navigator.push(context, appRoute(MerchantBannersPage(token: widget.token))).then((_) => _refreshParts(banners: true))
                      : () => _lockedSnack("Subscribe your store to create banners."),
                  ),
                  const SizedBox(height: 12),
                  // Product card — locked until a subscribed+active store exists
                  _SectionCard(
                    icon: OffroIcons.tag,
                    bgColor: OffroTones.electronics.background,
                    title: "My Products",
                    locked: !_hasActiveStore,
                    subtitle: _productNote,
                    onTap: _hasActiveStore
                      ? () => Navigator.push(context, appRoute(MerchantProductsPage(token: widget.token))).then((_) => _refreshParts(products: true, slots: true))
                      : () => _lockedSnack("Subscribe your store to add products."),
                  ),
                  const SizedBox(height: 12),
                  // Creator collaborations — brief, match and manage local creators
                  _SectionCard(
                    icon: OffroIcons.sparkles,
                    bgColor: OffroTones.fashion.background,
                    title: "Creator collaborations",
                    locked: !_hasActiveStore,
                    subtitle: "Brief, match and manage local creators",
                    onTap: _hasActiveStore
                      ? () => Navigator.push(context, appRoute(CollabWorkspacePage(token: widget.token)))
                      : () => _lockedSnack("Subscribe your store to work with creators."),
                  ),
                ]),
              ),
            ]),
          ),
        ),
  );
}

class _SectionCard extends StatelessWidget {
  final OffroIconData icon; final Color bgColor;
  final String title, subtitle; final VoidCallback onTap;
  // Item 1 (draft-store lock): when true, shows a "Locked" pill instead of
  // "Open" so the card visually communicates it can't be opened yet.
  final bool locked;
  const _SectionCard({required this.icon, required this.bgColor,
    required this.title, required this.subtitle, required this.onTap, this.locked = false});

  @override Widget build(BuildContext context) => OffroCard(
    onTap: onTap,
    radius: 22,
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: locked ? OffroColors.mint : bgColor, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: OffroIcon(icon, size: 20, color: OffroColors.primary),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: OffroText.value.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: OffroText.caption.copyWith(color: OffroColors.secondarySolid, height: 1.35)),
      ])),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: OffroColors.mint, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (locked) ...[
            const Icon(Icons.lock_rounded, color: OffroColors.primary, size: 11),
            const SizedBox(width: 4),
          ],
          Text(locked ? "Locked" : "Manage",
              style: OffroText.caption.copyWith(color: OffroColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ),
    ]),
  );
}



// ══════════════════════════════════════════════════════════
// MERCHANT BANNERS PAGE
// ══════════════════════════════════════════════════════════

class MerchantBannersPage extends StatefulWidget {
  final String token;
  const MerchantBannersPage({super.key, required this.token});
  @override State<MerchantBannersPage> createState() => _MerchantBannersState();
}
class _MerchantBannersState extends State<MerchantBannersPage> {
  List<Map<String,dynamic>> _banners = [];
  bool _loading = true;
  bool _loadError = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load({int retry = 0}) async {
    if (mounted) setState((){_loading=true; _loadError=false;});
    try {
      final data = List<Map<String,dynamic>>.from(
        await Api.getMerchantBanners(widget.token).timeout(const Duration(seconds:15))
      );
      if (mounted) setState((){_banners=data; _loading=false; _loadError=false;});
    } catch(e) {
      debugPrint('[MerchantBanners] _load error (attempt ${retry+1}): $e');
      if (retry==0 && mounted) {
        await Future.delayed(const Duration(seconds:2));
        return _load(retry:1);
      }
      if (mounted) setState((){_loading=false; _loadError=true;});
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kMerchantBg,
    appBar:merchantHeaderBar(eyebrow: "Promotions", title: "My Banners", back: true,
              actions:[
        Padding(
          padding:const EdgeInsets.only(right:18),
          child:offroHeaderAddButton(
            icon:Icons.add,
            tooltip:"New Banner",
            onPressed:()=>Navigator.push(context,appRoute(AddBannerPage(token:widget.token))).then((_)=>_load()),
          ),
        ),
      ],
    ),
    body:_loading
      ? const Center(child:CircularProgressIndicator(color:kMerchantPrimary))
      : _loadError
          ? Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
              const Icon(Icons.wifi_off_rounded,color:kMerchantMuted,size:48),
              const SizedBox(height:12),
              const Text("Couldn't load banners",style:TextStyle(color:kMerchantText,fontSize:15,fontWeight:FontWeight.w700)),
              const SizedBox(height:8),
              ElevatedButton.icon(onPressed:()=>_load(),icon:const Icon(Icons.refresh),label:const Text("Retry"),
                style:ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor:kMerchantPrimary,foregroundColor:Colors.white)),
            ]))
      : Column(children:[
          Expanded(child:_banners.isEmpty
            ? const Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Icon(Icons.view_carousel_outlined,size:64,color:kMerchantAccent),
                SizedBox(height:12),
                Text("No banners yet",style:TextStyle(color:kMerchantMuted,fontSize:16)),
                SizedBox(height:6),
                Text("Tap + to create your first banner",style:TextStyle(color:kMerchantMuted,fontSize:13)),
              ]))
            : RefreshIndicator(
                onRefresh:_load,
                child:ListView.builder(
                  padding:const EdgeInsets.all(14),
                  itemCount:_banners.length,
                  itemBuilder:(_,i){
                    final b = _banners[i];
                    // FIX 1: use approval_status as primary, fall back to status
                    // PERMANENT FIX: trust the server's authoritative "is_expired"
                    // flag first (it parses end_date in ANY stored format —
                    // ISO or "%d %b %Y" — so it's always correct, unlike a local
                    // DateTime.parse() which silently fails on non-ISO strings).
                    String rawStatus = (b["approval_status"]??"") != ""
                        ? (b["approval_status"] ?? "pending")
                        : (b["status"] ?? "pending");
                    if (b["is_expired"] == true) {
                      rawStatus = "expired";
                    } else if (rawStatus == "approved") {
                      // Fallback for older backend responses without is_expired
                      final _bEndRaw = b["end_date"]?.toString() ?? "";
                      if (_bEndRaw.isNotEmpty) {
                        try { final _bEnd = DateTime.parse(_bEndRaw);
                          if (DateTime.now().isAfter(_bEnd)) rawStatus = "expired";
                        } catch (_) {}
                      }
                    }
                    // Override rawStatus with is_active / deleted_by_admin flags
                    final bool _bIsActive      = b["is_active"] != false;
                    final bool _bDeletedByAdmin = b["deleted_by_admin"] == true;
                    final String displayStatus = _bDeletedByAdmin
                        ? "removed"
                        : (!_bIsActive ? "off" : rawStatus);

                    final (Color sc, String sl, IconData si) = switch(displayStatus) {
                      "approved"  => (OffroColors.statusLive,"Approved — Live", Icons.check_circle),
                      "rejected"  => (Colors.red, "Rejected", Icons.cancel),
                      "expired"   => (Colors.grey.shade600, "Expired", Icons.event_busy_rounded),
                      "removed"   => (Colors.red.shade700, "Removed by Admin", Icons.block_rounded),
                      "off"       => (Colors.grey.shade500, "Turned Off", Icons.pause_circle_outline_rounded),
                      "pending_approval" || "pending" => (OffroColors.statusPending,"Pending Approval", Icons.access_time_rounded),
                      _ => (kMerchantMuted,"Submitted", Icons.hourglass_empty),
                    };
                    // FIX 2: prefer from_date/end_date, fallback start_date
                    final fromDate = b["from_date"]?.toString() ?? b["start_date"]?.toString() ?? "";
                    final endDate  = b["end_date"]?.toString() ?? "";
                    final imgUrl   = b["image_url"]?.toString() ?? "";
                    final bool _isVideo = imgUrl.isNotEmpty && (
                      imgUrl.toLowerCase().endsWith(".mp4") ||
                      imgUrl.toLowerCase().contains(".mp4?") ||
                      imgUrl.toLowerCase().contains("video/mp4") ||
                      imgUrl.startsWith("data:video"));

                    final String titleStr = (b["title"] ?? "").toString().trim();
                    final String initialStr = titleStr.isNotEmpty ? titleStr[0].toUpperCase() : "B";

                    Widget _thumb;
                    if (imgUrl.isNotEmpty) {
                      if (_isVideo) {
                        _thumb = _BannerThumbVideo(url: imgUrl, initial: initialStr);
                      } else if (imgUrl.startsWith("data:image")) {
                        _thumb = Image.memory(
                          base64Decode(imgUrl.split(",").last),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: kMerchantAccent,
                            child: Center(
                              child: Text(initialStr, style: const TextStyle(color: kMerchantPrimary, fontWeight: FontWeight.w900, fontSize: 22)),
                            ),
                          ),
                        );
                      } else {
                        _thumb = Image.network(
                          imgUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: kMerchantAccent,
                            child: Center(
                              child: Text(initialStr, style: const TextStyle(color: kMerchantPrimary, fontWeight: FontWeight.w900, fontSize: 22)),
                            ),
                          ),
                        );
                      }
                    } else {
                      _thumb = Container(
                        width: 80,
                        height: 80,
                        color: kMerchantAccent,
                        child: Center(
                          child: Text(initialStr, style: const TextStyle(color: kMerchantPrimary, fontWeight: FontWeight.w900, fontSize: 22)),
                        ),
                      );
                    }

                    Widget _editAndToggleButtons = Row(children:[
                      Expanded(child:OutlinedButton.icon(
                        onPressed:() async {
                          final ctrl = TextEditingController(text:b["title"]??"");
                          final newTitle = await showDialog<String>(context:context,builder:(_)=>AlertDialog(
                            title:const Text("Edit Banner Title",style:TextStyle(color:kMerchantPrimary,fontWeight:FontWeight.bold)),
                            content:TextField(controller:ctrl,decoration:InputDecoration(
                              hintText:"Banner title",
                              border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)),
                              enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)))),
                            actions:[
                              TextButton(onPressed:()=>Navigator.pop(context),child:const Text("Cancel",style:TextStyle(color:kMerchantMuted))),
                              ElevatedButton(
                                style:ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor:kMerchantPrimary),
                                onPressed:()=>Navigator.pop(context,ctrl.text.trim()),
                                child:const Text("Save",style:TextStyle(color:Colors.white))),
                            ],
                          ));
                          if (newTitle!=null && newTitle.isNotEmpty && newTitle!=b["title"]) {
                            try {
                              await Api.updateMerchantBanner(widget.token, b["_id"]??"", {"title": newTitle});
                              _load();
                            } catch(e) {
                              debugPrint('[MerchantBanners] rename error: $e');
                              if(mounted) ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content:Text(friendlyError(e)),backgroundColor:Colors.red));
                            }
                          }
                        },
                        icon:const Icon(Icons.edit_rounded,size:14,color:kMerchantPrimary),
                        label:const Text("Edit Title",style:TextStyle(color:kMerchantPrimary,fontSize:12)),
                        style:OutlinedButton.styleFrom(elevation: 0, 
                          side:const BorderSide(color:kMerchantPrimary),
                          shape: const StadiumBorder(),
                          padding:const EdgeInsets.symmetric(vertical:6),
                          minimumSize:Size.zero, tapTargetSize:MaterialTapTargetSize.shrinkWrap),
                      )),
                      if (displayStatus == "approved" || displayStatus == "off") ...[
                        const SizedBox(width:8),
                        Expanded(child:OutlinedButton.icon(
                          onPressed: () async {
                            final isOn = _bIsActive;
                            final confirm = await showDialog<bool>(context:context,
                              builder:(_)=>AlertDialog(
                                title:Text(isOn?"Turn Off Banner?":"Turn On Banner?",
                                  style:const TextStyle(color:kMerchantPrimary,fontWeight:FontWeight.bold)),
                                content:Text(isOn
                                  ?"This banner will be hidden from stores until you turn it back on."
                                  :"This banner will go live again in stores."),
                                actions:[
                                  TextButton(onPressed:()=>Navigator.pop(context,false),
                                    child:const Text("Cancel",style:TextStyle(color:kMerchantMuted))),
                                  ElevatedButton(
                                    style:ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), 
                                      backgroundColor:isOn?Colors.orange:kMerchantPrimary),
                                    onPressed:()=>Navigator.pop(context,true),
                                    child:Text(isOn?"Turn Off":"Turn On",
                                      style:const TextStyle(color:Colors.white))),
                                ],
                              ));
                            if (confirm==true) {
                              try {
                                await Api.toggleMerchantBanner(widget.token, b["_id"]??"");
                                _load();
                              } catch(e) {
                                debugPrint('[MerchantBanners] toggle error: $e');
                                if(mounted) ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content:Text(friendlyError(e)),backgroundColor:Colors.red));
                              }
                            }
                          },
                          icon:Icon(_bIsActive?Icons.pause_circle_outline:Icons.play_circle_outline,
                            size:14,color:_bIsActive?Colors.orange:kMerchantPrimary),
                          label:Text(_bIsActive?"Turn Off":"Turn On",
                            style:TextStyle(color:_bIsActive?Colors.orange:kMerchantPrimary,fontSize:12)),
                          style:OutlinedButton.styleFrom(elevation: 0, 
                            side:BorderSide(color:_bIsActive?Colors.orange:kMerchantPrimary),
                            shape: const StadiumBorder(),
                            padding:const EdgeInsets.symmetric(vertical:6),
                            minimumSize:Size.zero, tapTargetSize:MaterialTapTargetSize.shrinkWrap),
                        )),
                      ],
                    ]);

                    // Actions per banner state (existing lifecycle only — no new
                    // backend actions). Real statuses: pending / approved /
                    // rejected / expired / off / removed. There is no "draft"
                    // banner: a banner is only created after the order is
                    // paid/activated, so the closest state is "pending"
                    // (submitted, awaiting admin approval).
                    Widget _noteRow(String text, {Widget? action}) => Container(
                      padding:EdgeInsets.fromLTRB(12,action==null?10:6,action==null?12:6,action==null?10:6),
                      decoration:BoxDecoration(color:OffroColors.beige,borderRadius:BorderRadius.circular(16)),
                      child:Row(children:[
                        Expanded(child:Text(text,style:OffroText.caption.copyWith(color:OffroColors.text,fontSize:11,fontWeight:FontWeight.w600))),
                        if(action!=null) ...[const SizedBox(width:8),action],
                      ]),
                    );
                    final Widget _actionButtons;
                    if (displayStatus == "expired") {
                      // EXPIRED: no Edit Title. Renew = the existing paid banner
                      // flow (Create Banner → order → payment → activate) with
                      // the title prefilled; no separate banner-renewal API exists.
                      _actionButtons = _noteRow("Expired · Choose a new start date",
                        action:ElevatedButton(
                          onPressed:()=>Navigator.push(context,appRoute(AddBannerPage(token:widget.token,renewFrom:Map<String,dynamic>.from(b)))).then((_)=>_load()),
                          style:ElevatedButton.styleFrom(elevation:0,shape:const StadiumBorder(),backgroundColor:OffroColors.primary,foregroundColor:Colors.white,
                            padding:const EdgeInsets.symmetric(horizontal:18,vertical:9),minimumSize:Size.zero,tapTargetSize:MaterialTapTargetSize.shrinkWrap),
                          child:const Text("Renew",style:TextStyle(fontSize:12,fontWeight:FontWeight.w700))));
                    } else if (displayStatus == "rejected") {
                      _actionButtons = _noteRow("Rejected · Create a new banner to resubmit",
                        action:ElevatedButton(
                          onPressed:()=>Navigator.push(context,appRoute(AddBannerPage(token:widget.token))).then((_)=>_load()),
                          style:ElevatedButton.styleFrom(elevation:0,shape:const StadiumBorder(),backgroundColor:OffroColors.primary,foregroundColor:Colors.white,
                            padding:const EdgeInsets.symmetric(horizontal:16,vertical:9),minimumSize:Size.zero,tapTargetSize:MaterialTapTargetSize.shrinkWrap),
                          child:const Text("Create new",style:TextStyle(fontSize:12,fontWeight:FontWeight.w700))));
                    } else if (displayStatus == "removed") {
                      _actionButtons = _noteRow("Removed by admin");
                    } else if (displayStatus == "pending" || displayStatus == "pending_approval") {
                      _actionButtons = Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                        _noteRow("Awaiting admin approval"),
                        const SizedBox(height:8),
                        _editAndToggleButtons,
                      ]);
                    } else {
                      _actionButtons = _editAndToggleButtons;
                    }

                    return Container(
                      margin:const EdgeInsets.only(bottom:12),
                      decoration:BoxDecoration(
                        color:Colors.white,
                        borderRadius:BorderRadius.circular(22),
                        border:Border.all(color:OffroColors.border),
                      ),
                      child:IntrinsicHeight(
                        child:Row(
                          crossAxisAlignment:CrossAxisAlignment.start,
                          children:[
                            Padding(
                              padding:const EdgeInsets.all(12),
                              child:ClipRRect(borderRadius:BorderRadius.circular(16),child:_thumb),
                            ),
                            Expanded(child:Padding(
                              padding:const EdgeInsets.fromLTRB(0,10,12,10),
                              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                                // Row 1: Title + status badge
                                Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                                  Expanded(child:Text(b["title"]??"",style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:kMerchantText),maxLines:1,overflow:TextOverflow.ellipsis)),
                                  Container(
                                    padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                                    decoration:BoxDecoration(color:sc.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),
                                    child:Row(mainAxisSize:MainAxisSize.min,children:[
                                      Icon(si,size:11,color:sc),
                                      const SizedBox(width:3),
                                      Text(sl,style:TextStyle(color:sc,fontSize:10,fontWeight:FontWeight.w700)),
                                    ]),
                                  ),
                                ]),
                                const SizedBox(height:4),
                                // Duration + Amount row
                                Row(children:[
                                  const Icon(Icons.schedule_rounded,size:13,color:kMerchantMuted),
                                  const SizedBox(width:4),
                                  Text("${b['duration']??b['duration_days']??30} Days",style:const TextStyle(color:kMerchantMuted,fontSize:11,fontWeight:FontWeight.w600)),
                                  const SizedBox(width:10),
                                  const Icon(Icons.payments_outlined,size:13,color:kMerchantMuted),
                                  const SizedBox(width:4),
                                  Text("₹${b['amount']??0}",style:const TextStyle(color:kMerchantMuted,fontSize:11,fontWeight:FontWeight.w600)),
                                ]),
                                if (fromDate.isNotEmpty || endDate.isNotEmpty) ...[
                                  const SizedBox(height:4),
                                  Container(
                                    padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                                    decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(6)),
                                    child:Row(children:[
                                      const Icon(Icons.calendar_month_rounded,size:12,color:kMerchantPrimary),
                                      const SizedBox(width:5),
                                      Expanded(child:Text(
                                        fromDate.isNotEmpty && endDate.isNotEmpty
                                          ? "Start: $fromDate   →   End: $endDate"
                                          : fromDate.isNotEmpty ? "From: $fromDate" : "Until: $endDate",
                                        style:const TextStyle(color:kMerchantPrimary,fontSize:10,fontWeight:FontWeight.w600),
                                        maxLines:1,
                                        overflow:TextOverflow.ellipsis,
                                      )),
                                    ]),
                                  ),
                                ],
                                if ((b["invoice_no"]??"").isNotEmpty) ...[
                                  const SizedBox(height:3),
                                  Text("Invoice: ${b['invoice_no']}",style:const TextStyle(color:kMerchantMuted,fontSize:10)),
                                ],
                                const SizedBox(height:8),
                                const Divider(height:1,thickness:.5,color:OffroColors.border),
                                const SizedBox(height:8),
                                _actionButtons,
                              ]),
                            )),
                          ],
                        ),
                      ),
                    );                  },
                ),
              )),
        ]),
  );
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip(this.text);
  @override Widget build(BuildContext context) => Container(
    padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
    decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.6),borderRadius:BorderRadius.circular(6)),
    child:Text(text,style:const TextStyle(fontSize:10,color:kMerchantPrimary,fontWeight:FontWeight.w600)),
  );
}

// ══════════════════════════════════════════════════════════
// Discount preview helper — shared by Store Subscription, Add Banner and
// Add Product's discount UIs so all three follow the same mechanism.
// Mirrors the backend's exact discount formula (pre-tax discount, then
// GST on the remainder) so the on-screen preview stays consistent with
// what the order-creation endpoint will actually compute. This is
// preview-only: it never affects what's sent to the backend — every
// request only ever carries discount_code; the backend independently
// and authoritatively recalculates the real amount at order-creation time.
// ══════════════════════════════════════════════════════════
double previewDiscountAmount(double basePrice, String? discountType, double discountValue) {
  if (discountType == null) return 0;
  final amt = discountType == "PERCENTAGE"
      ? basePrice * discountValue / 100.0
      : discountValue;
  if (amt > basePrice) return basePrice;
  if (amt < 0) return 0;
  return amt;
}

// ══════════════════════════════════════════════════════════
// ADD BANNER PAGE — with checkout flow
// ══════════════════════════════════════════════════════════

class AddBannerPage extends StatefulWidget {
  final String token;
  /// When set (Renew on an expired banner), the existing Create Banner flow
  /// opens with that banner's title prefilled. Everything else (media, store,
  /// dates, payment) is chosen again exactly as for a new banner.
  final Map<String,dynamic>? renewFrom;
  const AddBannerPage({super.key, required this.token, this.renewFrom});
  @override State<AddBannerPage> createState() => _AddBannerState();
}
class _AddBannerState extends State<AddBannerPage> {
  final _titleC    = TextEditingController();
  final _daysC     = TextEditingController(text:"30");
  final _discountC = TextEditingController();
  String? _imgB64; bool _loading = false; String _msg = "";
  // Renew: the existing banner's image (CDN url) stays in use unless the merchant replaces/removes it.
  String? _existingImgUrl;
  // Banner media: "image" (default, unchanged) or "video" (max 15 s / 10 MB).
  static const int _kVideoMaxBytes = 10 * 1024 * 1024;
  static const Duration _kVideoMaxDuration = Duration(seconds: 15);
  String _mediaType = "image";
  String? _videoPath;                 // picked file (already validated)
  String? _videoUrl;                  // CDN url after upload (done once, right before payment)
  VideoPlayerController? _videoCtrl;  // muted preview
  bool _videoBusy = false;
  DateTime _fromDate = DateTime.now();
  Map<String,dynamic>? _pricing;
  String? _selCity;
  // ── Store selection ──
  List<Map<String,dynamic>> _stores = [];
  Map<String,dynamic>? _selectedBannerStore;
  bool _storesLoading = false;
  // ── CTA destination (Store / Deal / Product). Only Deal/Product records
  // that really exist for this merchant are offered; Store is always valid. ──
  String _ctaType = "store";
  Map<String,dynamic>? _ctaItem;
  List<Map<String,dynamic>> _ctaDeals = [];
  List<Map<String,dynamic>> _ctaProducts = [];
  bool _ctaLoading = true;
  // Discount code state
  String? _appliedCode; double _appliedDiscount = 0; String? _appliedDiscountType;
  String _discountMsg = ""; bool _discountOk = false; bool _applyingCode = false;

  @override void dispose() { _titleC.dispose(); _daysC.dispose(); _discountC.dispose(); _razorpay.clear(); _videoCtrl?.dispose(); super.dispose(); }

  Future<void> _loadPricing() async {
    try {
      final p = await Api.getBannerPricing(widget.token);
      if (mounted) setState(()=>_pricing=Map<String,dynamic>.from(p));
    } catch(_){}
  }

  int get _days => int.tryParse(_daysC.text.trim()) ?? 0;
  double get _pricePerDay => (_pricing?["price_per_day"] as num?)?.toDouble() ?? 15;
  double get _basePrice   => double.parse((_pricePerDay * _days).toStringAsFixed(2));
  double get _gstPct      => (_pricing?["gst_pct"] as num?)?.toDouble() ?? 18;
  double get _discountAmt => previewDiscountAmount(_basePrice, _appliedDiscountType, _appliedDiscount);
  double get _taxable     => (_basePrice - _discountAmt) < 0 ? 0 : (_basePrice - _discountAmt);
  double get _gst         => double.parse((_taxable * _gstPct / 100).toStringAsFixed(2));
  double get _total       => double.parse((_taxable + _gst).toStringAsFixed(2));

  String get _fromDateStr => "${_fromDate.year}-${_fromDate.month.toString().padLeft(2,'0')}-${_fromDate.day.toString().padLeft(2,'0')}";
  String get _fromDateDisplay => "${_fromDate.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_fromDate.month-1]} ${_fromDate.year}";
  DateTime get _endDate => _fromDate.add(Duration(days:_days));
  String get _endDateDisplay => "${_endDate.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_endDate.month-1]} ${_endDate.year}";

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(context:context, initialDate:_fromDate,
      firstDate:DateTime.now(), lastDate:DateTime.now().add(const Duration(days:365)));
    if(picked!=null) setState(()=>_fromDate=picked);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source:ImageSource.gallery,imageQuality:80,maxWidth:1200);
    if (img==null) return;
    final bytes = await File(img.path).readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text("Image too large. Max 2MB."),backgroundColor:Colors.red));
      return;
    }
    setState(()=>_imgB64="data:image/jpeg;base64,${base64Encode(bytes)}");
  }

  // What gets sent as the banner media: the CDN video url, or the image data URI.
  String? get _mediaPayload => _mediaType == "video" ? _videoUrl : (_imgB64 ?? _existingImgUrl);

  void _videoError(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  // Validates size (<= 10 MB) and duration (<= 15 s) BEFORE anything is uploaded.
  Future<void> _pickVideo() async {
    if (_videoBusy) return;
    final XFile? picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _videoBusy = true);
    VideoPlayerController? c;
    try {
      final file = File(picked.path);
      if (await file.length() > _kVideoMaxBytes) {
        _videoError("Video is too large. Please select a video up to 10 MB.");
        return;
      }
      c = VideoPlayerController.file(file);
      await c.initialize();
      if (c.value.duration > _kVideoMaxDuration) {
        await c.dispose();
        c = null;
        _videoError("Video is too long. Please select a video up to 15 seconds.");
        return;
      }
      await c.setVolume(0);
      await c.setLooping(true);
      await c.play();
      final old = _videoCtrl;
      if (!mounted) return;
      setState(() { _videoCtrl = c; _videoPath = picked.path; _videoUrl = null; _msg = ""; });
      c = null; // now owned by the state
      old?.dispose();
    } catch (_) {
      _videoError("Could not read this video. Please select another video.");
    } finally {
      c?.dispose();
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  void _removeVideo() {
    final old = _videoCtrl;
    setState(() { _videoCtrl = null; _videoPath = null; _videoUrl = null; });
    old?.dispose();
  }

  // Uploads the validated video once (before payment, so a failed upload never
  // costs the merchant anything). Reused on retry. Returns false + sets _msg on failure.
  Future<bool> _uploadVideoIfNeeded() async {
    if (_videoUrl != null) return true;
    final path = _videoPath;
    if (path == null) return false;
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.length > _kVideoMaxBytes) {
        if (mounted) setState(() => _msg = "Video is too large. Please select a video up to 10 MB.");
        return false;
      }
      debugPrint("[BannerVideo] POST $kBaseUrl/merchant/banners/upload-video bytes=${bytes.length}");
      final res = await Api.uploadBannerVideo(widget.token, "data:video/mp4;base64,${base64Encode(bytes)}");
      final url = (res["url"] ?? "").toString();
      if (url.isEmpty) throw Exception("empty video url");
      _videoUrl = url;
      return true;
    } catch (e) {
      debugPrint("[BannerVideo] upload failed: $e");
      if (mounted) setState(() => _msg = friendlyError(e, fallback: "Could not upload the video. Please try again."));
      return false;
    }
  }

  Widget _mediaTypeChip(String label, IconData icon, String value) {
    final sel = _mediaType == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _mediaType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: sel ? kMerchantPrimary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? kMerchantPrimary : kMerchantBorder)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: sel ? Colors.white : kMerchantMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: sel ? Colors.white : kMerchantText, fontSize: 13, fontWeight: FontWeight.w700)),
        ]))));
  }

  Widget _videoBox() {
    final c = _videoCtrl;
    final has = c != null && c.value.isInitialized;
    return GestureDetector(
      onTap: has ? null : _pickVideo,   // (an existing renewed video is replaced by tapping)
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: has ? kMerchantPrimary : kMerchantBorder, width: has ? 2 : 1)),
        child: _videoBusy
          ? const Center(child: SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: kMerchantPrimary)))
          : has
            ? Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(11),
                  child: SizedBox(width: double.infinity, height: 110,
                    child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge,
                      child: SizedBox(width: c!.value.size.width, height: c.value.size.height,
                        child: VideoPlayer(c))))),
                Positioned(top: 6, right: 6, child: GestureDetector(
                  onTap: _removeVideo,
                  child: Container(padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14)))),
              ])
            : (_videoUrl != null && _videoPath == null)
            ? Stack(children: [
                Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.check_circle_outline, size: 34, color: kMerchantPrimary),
                  const SizedBox(height: 6),
                  const Text("Existing banner video will be reused", style: TextStyle(color: kMerchantText, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  const Text("Tap to replace", style: TextStyle(color: kMerchantMuted, fontSize: 11)),
                ])),
                Positioned(top: 6, right: 6, child: GestureDetector(
                  onTap: _removeVideo,
                  child: Container(padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14)))),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.video_library_outlined, size: 36, color: kMerchantAccent),
                const SizedBox(height: 6),
                const Text("Tap to select banner video", style: TextStyle(color: kMerchantMuted, fontSize: 13)),
                const SizedBox(height: 3),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _InfoChip("📐 1080×1080px (1:1)"), const SizedBox(width: 6), _InfoChip("Max 15 sec · 10 MB"),
                ]),
              ]),
      ));
  }

  Future<void> _proceed() async {
    if (_titleC.text.trim().isEmpty) { setState(()=>_msg="Banner title required"); return; }
    if (_selectedBannerStore==null) { setState(()=>_msg="Please select a store"); return; }
    if (_selCity==null || _selCity!.trim().isEmpty) { setState(()=>_msg="Please select a city"); return; }
    if (_mediaType=="video") {
      if (_videoPath==null && _videoUrl==null) { setState(()=>_msg="Please select a banner video"); return; }
    } else if (_imgB64==null && _existingImgUrl==null) { setState(()=>_msg="Please upload a banner image"); return; }
    if (_days<1) { setState(()=>_msg="Enter number of days (minimum 1)"); return; }
    setState((){_loading=true; _msg="";});
    try {
      // Video: upload once, before any order/payment is created.
      if (_mediaType=="video" && !await _uploadVideoIfNeeded()) {
        if (mounted) setState(()=>_loading=false);
        return;
      }
      final order = await Api.createBannerOrder(widget.token, {
        "days":       _days,
        "from_date":  _fromDateStr,
        "discount_code": _appliedCode ?? "",
        // Item 1 (draft-store lock): send store_id here too so a draft/
        // unsubscribed store is rejected fail-fast at order-creation time,
        // instead of only at activation. Backend's create_banner_order()
        // treats this field as optional, so this is purely an earlier,
        // better-UX check — activate_free_banner()/verify_banner_payment()
        // still enforce it regardless.
        "store_id":   (_selectedBannerStore?["_id"] ?? _selectedBannerStore?["id"] ?? "").toString(),
      });
      if (!mounted) return;
      final payMode = order["pay_mode"] ?? "manual";
      final amtPaise = (order["amount_paise"] as num?)?.toInt() ?? 0;

      if (payMode=="manual" || amtPaise<=0) {
        // Manual flow — show confirm dialog
        final confirmed = await _showBannerSummaryDialog(order, manual:true);
        if (confirmed==true && mounted) {
          final res = await Api.activateFreeBanner(widget.token, {
            "order_id":  order["order_id"],
            "title":     _titleC.text.trim(),
            "image_url": _mediaPayload,
            "media_type": _mediaType,
            "city":      _selCity??"",
            "store_id":  (_selectedBannerStore?["_id"] ?? _selectedBannerStore?["id"] ?? "").toString(),
            "store_name":(_selectedBannerStore?["store_name"] ?? "").toString(),
            ..._ctaPayload,
          });
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:Text("✅ Banner submitted! ${res['message']??''}"),
              backgroundColor:OffroColors.statusLive));
          }
        }
      } else {
        final confirmed = await _showBannerSummaryDialog(order, manual:false);
        if (confirmed==true && mounted) {
          _openRazorpayBanner(order);
        }
      }
    } catch(e) { setState(()=>_msg=friendlyError(e)); }
    if (mounted) setState(()=>_loading=false);
  }

  late Razorpay _razorpay;
  Map<String,dynamic>? _pendingOrder;

  @override void initState() {
    super.initState();
    if (widget.renewFrom != null) {
      _titleC.text = widget.renewFrom!["title"]?.toString() ?? "";
      // Load the existing banner media so the merchant does not have to upload it again.
      final url = (widget.renewFrom!["image_url"] ?? "").toString().trim();
      if (url.isNotEmpty) {
        final low = url.toLowerCase();
        final isVideo = (widget.renewFrom!["media_type"]?.toString() == "video") ||
            low.endsWith(".mp4") || low.contains(".mp4?") || low.contains("video/mp4") || url.startsWith("data:video");
        if (isVideo) { _mediaType = "video"; _videoUrl = url; }
        else { _existingImgUrl = url; }
      }
    }
    _loadPricing();
    _loadBannerStores();
    _loadCtaOptions();
    _daysC.addListener(()=>setState((){}));
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
  }

  Future<void> _loadBannerStores() async {
    if (!mounted) return;
    setState(() => _storesLoading = true);
    try {
      final list = await Api.getMerchantStores(widget.token);
      if (mounted) setState(() {
        _stores = List<Map<String,dynamic>>.from(list);
        if (_stores.length == 1) _onBannerStoreSelected(_stores.first);
        _storesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _storesLoading = false);
    }
  }

  static String _ctaId(Map<String,dynamic> m) => (m["_id"] ?? m["id"] ?? "").toString();
  static String _ctaName(Map<String,dynamic> m, String type) {
    for (final k in const ["title", "deal_title", "name", "product_name", "voucher_name"]) {
      final v = (m[k] ?? "").toString().trim();
      if (v.isNotEmpty) return v;
    }
    return type == "deal" ? "Untitled deal" : "Untitled product";
  }

  Future<void> _loadCtaOptions() async {
    try {
      final r = await Future.wait([
        Api.getMerchantDeals(widget.token),
        Api.getMerchantProducts(widget.token),
      ]);
      Map<String,dynamic> m(e) => Map<String,dynamic>.from(e as Map);
      // Same "usable" rule the backend enforces: active deals; products that
      // are not deleted/inactive/rejected.
      final deals = (r[0] as List).where((e) => e is Map).map(m)
          .where((d) => _ctaId(d).isNotEmpty && (d["status"] ?? "active").toString() == "active").toList();
      final prods = (r[1] as List).where((e) => e is Map).map(m)
          .where((p) {
            final st = (p["approval_status"] ?? p["status"] ?? "").toString();
            return _ctaId(p).isNotEmpty && p["is_active"] != false && p["is_deleted"] != true
                && st != "deleted" && st != "rejected";
          }).toList();
      if (!mounted) return;
      setState(() {
        _ctaDeals = deals; _ctaProducts = prods; _ctaLoading = false;
        // Preferred order Product → Deal → Store, only when records exist.
        _ctaType = prods.isNotEmpty ? "product" : deals.isNotEmpty ? "deal" : "store";
      });
    } catch (_) {
      if (mounted) setState(() { _ctaLoading = false; _ctaType = "store"; });
    }
  }

  /// Destination actually sent to the backend. Falls back to the selected
  /// Store whenever no valid Product/Deal is chosen.
  Map<String,dynamic> get _ctaPayload {
    final storeId = _ctaId(_selectedBannerStore ?? {});
    if (_ctaType != "store" && _ctaItem != null) {
      final id = _ctaId(_ctaItem!);
      final list = _ctaType == "deal" ? _ctaDeals : _ctaProducts;
      if (id.isNotEmpty && list.any((e) => _ctaId(e) == id)) {
        return {"cta_type": _ctaType, "cta_id": id};
      }
    }
    return {"cta_type": "store", "cta_id": storeId};
  }

  Widget _ctaChip(String label, IconData icon, String value, bool enabled) {
    final sel = _ctaType == value;
    return Expanded(child: GestureDetector(
      onTap: enabled ? () => setState(() { _ctaType = value; _ctaItem = null; }) : null,
      child: Opacity(opacity: enabled ? 1 : 0.45, child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? OffroColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: sel ? OffroColors.primary : OffroColors.border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: sel ? Colors.white : OffroColors.secondarySolid),
          const SizedBox(width: 5),
          Text(label, style: OffroText.caption.copyWith(
            color: sel ? Colors.white : OffroColors.text, fontWeight: FontWeight.w700)),
        ])))));
  }

  Widget _ctaSection() {
    if (_ctaLoading) return const SizedBox.shrink();
    final isDeal = _ctaType == "deal";
    final list = isDeal ? _ctaDeals : _ctaProducts;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OffroColors.mint.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OffroColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("CTA destination", style: OffroText.title),
        const SizedBox(height: 2),
        Text("Choose where this banner should take the customer.",
          style: OffroText.caption.copyWith(color: OffroColors.secondarySolid)),
        const SizedBox(height: 10),
        Row(children: [
          _ctaChip("Product", Icons.local_activity_outlined, "product", _ctaProducts.isNotEmpty),
          const SizedBox(width: 8),
          _ctaChip("Deal", Icons.local_offer_outlined, "deal", _ctaDeals.isNotEmpty),
          const SizedBox(width: 8),
          _ctaChip("Store", Icons.storefront_outlined, "store", true),
        ]),
        if (_ctaType != "store") ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _ctaItem == null ? null : _ctaId(_ctaItem!),
            hint: Text(isDeal ? "Select Deal" : "Select Product"),
            items: list.map((e) => DropdownMenuItem<String>(
              value: _ctaId(e),
              child: Text(_ctaName(e, _ctaType), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (id) => setState(() {
              _ctaItem = list.firstWhere((e) => _ctaId(e) == id, orElse: () => <String,dynamic>{});
              if (_ctaItem!.isEmpty) _ctaItem = null;
            }),
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OffroColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OffroColors.border)))),
        ],
        const SizedBox(height: 8),
        Text(
          _ctaType == "store"
            ? "Customers will open the selected store."
            : (_ctaItem == null
                ? "Nothing selected yet — the banner will open the store."
                : "If this ${isDeal ? 'deal' : 'product'} is later removed, the banner opens the store instead."),
          style: OffroText.caption.copyWith(color: OffroColors.secondarySolid)),
      ]),
    );
  }

  void _onBannerStoreSelected(Map<String,dynamic> store) {
    final city = (store["city"] ?? "").toString().trim();
    setState(() {
      _selectedBannerStore = store;
      if (city.isNotEmpty) _selCity = city;
    });
  }

  Future<void> _applyDiscountCode() async {
    final code = _discountC.text.trim();
    if (code.isEmpty) return;
    setState(() { _applyingCode = true; _discountMsg = ""; });
    try {
      final r = await Api.validateDiscountCode(widget.token, code, scope: "BANNERS");
      final val = (r["value"] as num).toDouble();
      final type = (r["type"]?.toString() ?? "VALUE").toUpperCase();
      setState(() {
        _appliedCode         = r["code"]?.toString() ?? code;
        _appliedDiscount     = val;
        _appliedDiscountType = type;
        _discountOk      = true;
        _discountMsg     = r["message"]?.toString() ?? "✅ Discount applied!";
      });
    } catch (e) {
      setState(() {
        _appliedCode         = null;
        _appliedDiscount     = 0;
        _appliedDiscountType = null;
        _discountOk      = false;
        _discountMsg     = friendlyError(e);
      });
    }
    if (mounted) setState(() => _applyingCode = false);
  }

  void _openRazorpayBanner(Map order) {
    final rzpKey = order["razorpay_key"]?.toString() ?? '';
    final rzpOrderId = order["razorpay_order_id"]?.toString() ?? '';
    if (rzpKey.isEmpty || rzpOrderId.isEmpty) {
      setState(()=>_msg="Payment gateway not configured. Contact support.");
      return;
    }
    _pendingOrder = Map<String,dynamic>.from(order);
    // FIX 4: ensure amount is int and handle launch errors
    try {
      _razorpay.open({
        "key":         rzpKey,
        "amount":      (order["amount_paise"] as num?)?.toInt() ?? 0,
        "name":        "OFFRO",
        "description": "Banner – ${order['days']} Days",
        "order_id":    rzpOrderId,
        "prefill":     {"contact":"","email":""},
        "theme":       {"color":"#3E5F55"},
      });
    } catch (e) {
      debugPrint('[MerchantBanners] Razorpay open error: $e');
      if (mounted) setState(()=>_msg=friendlyError(e, fallback: "Could not open payment. Please try again."));
    }
  }

  void _onPaySuccess(PaymentSuccessResponse res) async {
    if (_pendingOrder==null || !mounted) return;
    final captured = _pendingOrder;
    _pendingOrder = null;   // T1/T4: clear immediately to prevent double-fire
    try {
      final result = await Api.verifyBannerPayment(widget.token, {
        "order_id":           captured!["order_id"],
        "title":              _titleC.text.trim(),
        "image_url":          _mediaPayload,
        "media_type":         _mediaType,
        "city":               _selCity??"",
        "store_id":           (_selectedBannerStore?["_id"] ?? _selectedBannerStore?["id"] ?? "").toString(),
        "store_name":         (_selectedBannerStore?["store_name"] ?? "").toString(),
        ..._ctaPayload,
        "razorpay_payment_id": res.paymentId,
        "razorpay_order_id":  res.orderId,
        "razorpay_signature": res.signature,
      });
      if (mounted) {
        // FIX 3: Capture navigator before pushReplacement so onDone works after context deactivated
        final nav = Navigator.of(context);
        final invoiceNo = result["invoice_no"]?.toString() ?? result["message"]?.toString() ?? "";
        nav.pushReplacement(MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            storeName: _titleC.text.trim(),
            invoiceNo: invoiceNo,
            onDone: () => nav.popUntil((r) => r.isFirst),
          ),
        ));
      }
    } catch(e) { if(mounted) setState(()=>_msg=friendlyError(e)); }
  }

  void _onPayError(PaymentFailureResponse res) {
    if(mounted) setState(()=>_msg="Payment failed: ${friendlyRazorpayError(res.message)}");
  }

  Future<bool?> _showBannerSummaryDialog(Map order, {required bool manual}) async =>
    showDialog<bool>(context:context, builder:(_)=>AlertDialog(
      title:const Text("Banner Order Summary",style:TextStyle(color:kMerchantPrimary,fontWeight:FontWeight.bold)),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        _dRow("Title",    _titleC.text.trim()),
        _dRow("Duration", "${order['days']} Days"),
        _dRow("Period",   "${order['from_date']} → ${order['end_date']}"),
        _dRow("Rate",     "₹${order['price_per_day']}/day"),
        const Divider(),
        _dRow("Base Price","₹${order['base_price']}"),
        if((order['discount_amount']??0)>0) _dRow("Discount","−₹${order['discount_amount']}",
          color:OffroColors.statusLive),
        _dRow("GST (${order['gst_percent']}%)","₹${order['gst_amount']}"),
        _dRow("Total","₹${order['amount_display']}",bold:true),
        const SizedBox(height:10),
        Container(padding:const EdgeInsets.all(10),
          decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(8)),
          child:Text(manual
            ? "Your banner will be submitted for admin review after confirmation."
            : "Razorpay checkout will open. Banner goes live after admin approval.",
            style:const TextStyle(fontSize:12,color:kMerchantPrimary))),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text("Cancel",style:TextStyle(color:kMerchantMuted))),
        ElevatedButton(
          style:ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor:kMerchantPrimary),
          onPressed:()=>Navigator.pop(context,true),
          child:Text(manual?"Confirm Submit":"Pay ₹${order['amount_display']}",style:const TextStyle(color:Colors.white))),
      ],
    ));

  Widget _dRow(String k,String v,{bool bold=false,Color? color}) => Padding(
    padding:const EdgeInsets.symmetric(vertical:3),
    child:Row(children:[
      Expanded(child:Text(k,style:const TextStyle(color:kMerchantMuted,fontSize:13))),
      Text(v,style:TextStyle(fontSize:13,fontWeight:bold?FontWeight.bold:FontWeight.w500,color:color??(bold?kMerchantPrimary:kMerchantText))),
    ]));

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kMerchantBg,
    appBar:AppBar(title:Text(widget.renewFrom != null ? "Renew Banner" : "Create Banner")),
    body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[

      // Title field
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Banner Title *",style:TextStyle(fontWeight:FontWeight.w700,color:kMerchantText,fontSize:13)),
          const SizedBox(height:8),
          TextField(controller:_titleC,decoration:InputDecoration(
            hintText:"e.g. 50% OFF at Raj Store",isDense:true,
            contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
            enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
          )),
        ])),
      const SizedBox(height:12),

      // ── Store selection (auto-fills city) ──
      if (_storesLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: kMerchantPrimary))),
        )
      else
        DropdownButtonFormField<Map<String,dynamic>>(
          isExpanded: true,
          value: _selectedBannerStore,
          hint: const Text("Select Store *"),
          items: _stores.map((s) => DropdownMenuItem<Map<String,dynamic>>(
            value: s,
            child: Text(s["store_name"]?.toString() ?? "Unnamed Store",
              overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (s) { if (s != null) _onBannerStoreSelected(s); },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.store, color: kMerchantMuted, size: 20),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)))),
      const SizedBox(height: 12),

      // ── City (auto-filled from store) ──
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: OffroColors.mint,
          border: Border.all(color: kMerchantBorder),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.location_city, color: kMerchantMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(
            (_selCity != null && _selCity!.isNotEmpty) ? _selCity! : "City auto-filled from store",
            style: TextStyle(
              color: (_selCity != null && _selCity!.isNotEmpty) ? kMerchantText : kMerchantMuted,
              fontSize: 15))),
          if (_selCity != null && _selCity!.isNotEmpty)
            const Icon(Icons.check_circle, color: kMerchantPrimary, size: 18),
        ]),
      ),
      const SizedBox(height: 12),

      // ── CTA destination ──
      _ctaSection(),

      // Banner type: Image / Video
      Row(children:[
        _mediaTypeChip("Image", Icons.image_outlined, "image"),
        const SizedBox(width:10),
        _mediaTypeChip("Video", Icons.videocam_outlined, "video"),
      ]),
      const SizedBox(height:10),

      // Upload (Image = existing behaviour, Video = new)
      if (_mediaType=="image") GestureDetector(
        onTap:_pickImage,
        child:Container(
          height:110,
          decoration:BoxDecoration(
            color:Colors.white,
            borderRadius:BorderRadius.circular(12),
            border:Border.all(color:(_imgB64!=null||_existingImgUrl!=null)?kMerchantPrimary:kMerchantBorder,
              style:BorderStyle.solid,width:(_imgB64!=null||_existingImgUrl!=null)?2:1),
          ),
          child:(_imgB64!=null||_existingImgUrl!=null)
            ? Stack(children:[
                ClipRRect(borderRadius:BorderRadius.circular(11),
                  child:_imgB64!=null
                    ? Image.memory(base64Decode(_imgB64!.split(",").last),width:double.infinity,height:110,fit:BoxFit.cover)
                    : Image.network(_existingImgUrl!,width:double.infinity,height:110,fit:BoxFit.cover,
                        errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image_outlined,color:kMerchantMuted,size:32)))),
                Positioned(top:6,right:6,child:GestureDetector(
                  onTap:()=>setState((){_imgB64=null;_existingImgUrl=null;}),
                  child:Container(padding:const EdgeInsets.all(4),
                    decoration:const BoxDecoration(color:Colors.red,shape:BoxShape.circle),
                    child:const Icon(Icons.close,color:Colors.white,size:14)))),
              ])
            : Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                const Icon(Icons.add_photo_alternate_outlined,size:36,color:kMerchantAccent),
                const SizedBox(height:6),
                const Text("Tap to upload banner image",style:TextStyle(color:kMerchantMuted,fontSize:13)),
                const SizedBox(height:3),
                Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                  _InfoChip("📐 1080×1080px (1:1)"),const SizedBox(width:6),_InfoChip("📦 Max 2MB"),
                ]),
              ]),
        ))
      else _videoBox(),
      const SizedBox(height:12),

      // Duration + From Date
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Duration & Start Date",style:TextStyle(fontWeight:FontWeight.w700,color:kMerchantText,fontSize:13)),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:TextField(
              controller:_daysC,
              keyboardType:TextInputType.number,
              onChanged:(_)=>setState((){}),
              decoration:InputDecoration(
                labelText:"Number of Days",hintText:"e.g. 7",
                prefixIcon:const Icon(Icons.today_rounded,color:kMerchantMuted,size:18),
                filled:true,fillColor:kMerchantBg,isDense:true,
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
                enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
              ),
            )),
            const SizedBox(width:10),
            Expanded(child:GestureDetector(
              onTap:_pickFromDate,
              child:Container(
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),
                decoration:BoxDecoration(color:kMerchantBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:kMerchantBorder)),
                child:Row(children:[
                  const Icon(Icons.event_rounded,size:18,color:kMerchantMuted),
                  const SizedBox(width:8),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    const Text("From Date",style:TextStyle(fontSize:11,color:kMerchantMuted)),
                    Text(_fromDateDisplay,style:const TextStyle(fontSize:13,color:kMerchantText,fontWeight:FontWeight.w600)),
                  ])),
                ]),
              ),
            )),
          ]),
          if(_days>0) Padding(padding:const EdgeInsets.only(top:10),
            child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
              decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(8)),
              child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                const Text("Active period:",style:TextStyle(fontSize:12,color:kMerchantMuted)),
                Text("$_fromDateDisplay → $_endDateDisplay",style:const TextStyle(fontSize:12,color:kMerchantPrimary,fontWeight:FontWeight.w600)),
              ]),
            )),
          if(_pricing!=null && _days>0) Padding(padding:const EdgeInsets.only(top:6),
            child:Text("₹${_pricePerDay.toStringAsFixed(0)}/day × $_days days",
              style:const TextStyle(fontSize:12,color:kMerchantMuted))),
        ])),
      const SizedBox(height:12),

      // Price summary
      if (_pricing!=null && _days>0)
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(12)),
          child:Column(children:[
            _dRow("Base Price","₹${_basePrice.toStringAsFixed(2)}"),
            _dRow("GST (${_gstPct.toInt()}%)","₹${_gst.toStringAsFixed(2)}"),
            const Divider(height:16),
            _dRow("Total","₹${_total.toStringAsFixed(2)}",bold:true),
          ])),

      const SizedBox(height:4),
      if (_msg.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:6),
        child:Text(_msg,style:const TextStyle(color:Colors.red,fontSize:12))),
      const SizedBox(height:12),

      // TASK 6 FIX: Discount code shown ABOVE Proceed to Checkout
      // Item 6: Discount code field
      Container(
        padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Discount Code",style:TextStyle(fontWeight:FontWeight.w700,color:kMerchantText,fontSize:13)),
          const SizedBox(height:4),
          const Text("Have a promo code? Enter it below.",style:TextStyle(color:kMerchantMuted,fontSize:11)),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:TextField(
              controller:_discountC,
              textCapitalization:TextCapitalization.characters,
              onChanged:(_){ if((_appliedCode ?? "").isNotEmpty) setState((){_appliedCode="";_appliedDiscount=0;_appliedDiscountType=null;_discountMsg="";_discountOk=false;}); },
              decoration:InputDecoration(
                hintText:"e.g. OFFRO20",isDense:true,
                prefixIcon:const Icon(Icons.local_offer_outlined,color:kMerchantMuted,size:18),
                contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
                enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:_discountOk?kMerchantPrimary:kMerchantBorder)),
              ),
            )),
            const SizedBox(width:8),
            ElevatedButton(
              onPressed:_applyingCode?null:_applyDiscountCode,
              style:ElevatedButton.styleFrom(elevation: 0,  
                padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
                shape: const StadiumBorder()),
              child:_applyingCode
                ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                : const Text("Apply",style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
            ),
          ]),
          if (_discountMsg.isNotEmpty) ...[
            const SizedBox(height:6),
            Text(_discountMsg,style:TextStyle(color:_discountOk?OffroColors.statusLive:Colors.red,fontWeight:FontWeight.w600,fontSize:12)),
          ],
          if (_appliedDiscount > 0) ...[
            const SizedBox(height:6),
            Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
              decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(8)),
              child:Row(children:[
                const Icon(Icons.check_circle,color:OffroColors.statusLive,size:14),
                const SizedBox(width:6),
                Text(_appliedDiscountType == "PERCENTAGE"
                      ? "−₹${_discountAmt.toStringAsFixed(2)} (${_appliedDiscount.toStringAsFixed(0)}%) off  →  Total: ₹${_total.toStringAsFixed(2)}"
                      : "−₹${_appliedDiscount.toStringAsFixed(0)} off  →  Total: ₹${_total.toStringAsFixed(2)}",
                  style:const TextStyle(color:OffroColors.statusLive,fontWeight:FontWeight.w700,fontSize:12)),
              ]),
            ),
          ],
        ])),
      const SizedBox(height:16),
      const SizedBox(height:24),
      const SizedBox(height:12),

      ElevatedButton.icon(
        icon:_loading?const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):const Icon(Icons.arrow_forward_rounded),
        label:const Text("Proceed to Checkout"),
        style:ElevatedButton.styleFrom(elevation: 0,  
          shape: const StadiumBorder(),
          padding:const EdgeInsets.symmetric(vertical:14)),
        onPressed:_loading?null:_proceed,
      ),
    ])),
  );
}

// ══════════════════════════════════════════════════════════
// MERCHANT PRODUCTS PAGE  (Phase 2 — redesigned)
// ══════════════════════════════════════════════════════════

class MerchantProductsPage extends StatefulWidget {
  final String token;
  const MerchantProductsPage({super.key, required this.token});
  @override State<MerchantProductsPage> createState() => _MerchantProductsState();
}

class _MerchantProductsState extends State<MerchantProductsPage> {
  List<Map<String,dynamic>> _products = [];
  List<Map<String,dynamic>> _filtered = [];
  Map<String,dynamic>? _slots;                 // free-slot usage + additional price (backend)
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String _activeFilter = "All";
  // Store filter: "" = All Stores, otherwise a store id of THIS merchant (the stores API only returns their own).
  String _storeFilter = "";
  List<Map<String,dynamic>> _myStores = [];

  List<dynamic> _expiryWarnings = [];

  @override void initState() { super.initState(); _load(); }
  @override void dispose()   { _searchCtrl.dispose(); super.dispose(); }

  bool _loadError = false;

  Future<void> _load({int retry = 0}) async {
    if (mounted) setState(() { _loading = true; _loadError = false; });
    try {
      final results = await Future.wait([
        Api.getMerchantProducts(widget.token).timeout(const Duration(seconds:15)),
        Api.checkProductExpiry(widget.token).timeout(const Duration(seconds:10)),
        Api.getProductSlots(widget.token).timeout(const Duration(seconds:10)),
        Api.getMerchantStores(widget.token).timeout(const Duration(seconds:15)),
      ]);
      _products = List<Map<String,dynamic>>.from(results[0] as Iterable);
      _myStores = List<Map<String,dynamic>>.from((results[3] as Iterable).map((e) => Map<String,dynamic>.from(e as Map)));
      // A store that no longer exists cannot stay selected.
      if (_storeFilter.isNotEmpty && !_myStores.any((st) => (st["_id"] ?? "").toString() == _storeFilter)) _storeFilter = "";
      final exp = results[1];
      _expiryWarnings = exp is Map ? ((exp["items"] ?? []) as List) : <dynamic>[];
      _slots = results[2] is Map ? Map<String,dynamic>.from(results[2] as Map) : null;
      _applyFilters();
      if (mounted) setState(() { _loading = false; _loadError = false; });
    } catch(e) {
      debugPrint('[MerchantProducts] _load error (attempt ${retry+1}): $e');
      if (retry == 0 && mounted) {
        await Future.delayed(const Duration(seconds:2));
        return _load(retry:1);
      }
      _applyFilters();
      if (mounted) setState(() { _loading = false; _loadError = true; });
    }
  }

  // Parses ISO "2026-07-04" OR "04 Jul 2026" OR "04-07-2026" → DateTime
  DateTime? _parseAnyDate(String raw) {
    if (raw.isEmpty) return null;
    try { return DateTime.parse(raw); } catch (_) {}
    try {
      final parts = raw.trim().split(RegExp(r'[\s\-/]+'));
      if (parts.length >= 3) {
        const months = {"jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
                        "jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12};
        // "dd MMM yyyy"
        final mon = months[parts[1].toLowerCase().substring(0, 3)];
        if (mon != null) {
          final day = int.tryParse(parts[0]);
          final yr  = int.tryParse(parts[2]);
          if (day != null && yr != null) return DateTime(yr, mon, day);
        }
      }
    } catch (_) {}
    return null;
  }

  String _effectiveStatus(Map<String,dynamic> v) {
    String st = (v["approval_status"] ?? v["status"] ?? "pending_approval")
        .toString().toLowerCase().trim();
    // Normalize all pending/waiting variants → "pending_approval"
    const pendingVariants = {"pending", "waiting_approval", "waiting",
                              "submitted", "new", "under_review", "in_review"};
    if (pendingVariants.contains(st)) st = "pending_approval";
    if (st == "approved") {
      // Backend flags expiry (valid through the end date). Fall back to the
      // product's own end_date; products with no end date never expire.
      if (v["is_expired"] == true) {
        st = "expired";
      } else {
        final dt = _parseAnyDate(v["end_date"]?.toString() ?? "");
        if (dt != null && DateTime.now().isAfter(DateTime(dt.year, dt.month, dt.day, 23, 59, 59))) {
          st = "expired";
        }
      }
    }
    return st;
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase();
    _filtered = _products.where((v) {
      final title = (v["title"] ?? "").toString().toLowerCase();
      final offer = (v["offer_text"] ?? "").toString().toLowerCase();
      final st    = _effectiveStatus(v);
      if (q.isNotEmpty && !title.contains(q) && !offer.contains(q)) return false;
      if (_storeFilter.isNotEmpty && (v["store_id"] ?? "").toString() != _storeFilter) return false;
      switch (_activeFilter) {
        case "approved":        return st == "approved";
        case "pending_approval":return st == "pending_approval";
        case "expired":         return st == "expired";
        default:                return true; // "All" shows everything including expired
      }
    }).toList();
  }

  String _pid(Map<String,dynamic> v) {
    final raw = v["_id"];
    return (raw is Map) ? (raw["\$oid"] ?? raw["oid"] ?? "").toString() : (raw ?? "").toString();
  }

  // ── Filter bottom sheet ──────────────────────────────────
  void _openFilter() {
    final opts = [
      ("All",              "All Products",         Icons.grid_view_rounded,         kMerchantText),
      ("approved",         "Live",                 Icons.check_circle_rounded,       OffroColors.statusLive),
      ("pending_approval", "Pending Approval",     Icons.hourglass_top_rounded,      OffroColors.statusPending),
      ("expired",          "Expired",              Icons.event_busy_rounded,         Colors.red),
    ];
    final storeOpts = <(String, String)>[("", "All Stores"),
      ..._myStores.map((st) => ((st["_id"] ?? "").toString(), (st["store_name"] ?? "Store").toString()))];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Filter Products", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kMerchantText)),
            const SizedBox(height: 14),
            ...opts.map((o) {
              final selected = _activeFilter == o.$1;
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: (selected ? o.$4 : kMerchantBorder).withValues(alpha: .15),
                  child: Icon(o.$3, color: selected ? o.$4 : kMerchantMuted, size: 18)),
                title: Text(o.$2, style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? o.$4 : kMerchantText, fontSize: 14)),
                trailing: selected ? Icon(Icons.check_rounded, color: o.$4, size: 20) : null,
                onTap: () {
                  setState(() { _activeFilter = o.$1; _applyFilters(); });
                  Navigator.pop(context);
                },
              );
            }),
            if (_myStores.isNotEmpty) ...[
              const Divider(height: 20),
              const Text("Store", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kMerchantText)),
              const SizedBox(height: 6),
              ...storeOpts.map((o) {
                final selected = _storeFilter == o.$1;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: (selected ? kMerchantPrimary : kMerchantBorder).withValues(alpha: .15),
                    child: Icon(o.$1.isEmpty ? Icons.storefront_outlined : Icons.store_rounded,
                      color: selected ? kMerchantPrimary : kMerchantMuted, size: 18)),
                  title: Text(o.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? kMerchantPrimary : kMerchantText, fontSize: 14)),
                  trailing: selected ? const Icon(Icons.check_rounded, color: kMerchantPrimary, size: 20) : null,
                  onTap: () {
                    setState(() { _storeFilter = o.$1; _applyFilters(); });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ]),
        )),
      ),
    );
  }

  // ── On/Off toggle (optimistic) ──────────────────────────
  Future<void> _toggleActive(Map<String,dynamic> v, String pid) async {
    final current = v["is_active"] as bool? ?? true;
    setState(() { v["is_active"] = !current; _applyFilters(); });
    try {
      await Api.setProductAvailability(widget.token, pid, !current);
    } catch (e) {
      debugPrint('[MerchantProducts] toggle availability error: $e');
      if (mounted) setState(() { v["is_active"] = current; _applyFilters(); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Toggle failed: ${friendlyError(e)}"), backgroundColor: Colors.red));
    }
  }

  // ── Full-screen image viewer ─────────────────────────────
  void _showImageFullscreen(BuildContext ctx, String logoUrl) {
    if (logoUrl.isEmpty) return;
    showDialog(context: ctx, builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(children: [
        Center(child: InteractiveViewer(
          child: logoUrl.startsWith("data:image")
            ? Image.memory(base64Decode(logoUrl.split(",").last), fit: BoxFit.contain)
            : Image.network(logoUrl, fit: BoxFit.contain,
                errorBuilder: (_,__,___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64)),
        )),
        Positioned(top: 44, right: 16, child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 22)))),
      ]),
    ));
  }

  // ── More actions bottom sheet ────────────────────────────
  void _openMore(Map<String,dynamic> v, String pid) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(v["title"] ?? "Product",
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kMerchantText)),
            const SizedBox(height: 4),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(radius: 18, backgroundColor: OffroColors.mint,
                child: Icon(Icons.edit_rounded, color: kMerchantPrimary, size: 18)),
              title: const Text("Edit Product", style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(context); _showEditDialog(v, pid); }),
            if (pid.isNotEmpty)
              ListTile(
                leading: const CircleAvatar(radius: 18, backgroundColor: Color(0xFFFFF3CD),
                  child: Icon(Icons.bar_chart_rounded, color: OffroColors.statusPending, size: 18)),
                title: const Text("Analytics", style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context);
                  Navigator.push(context, appRoute(ProductAnalyticsPage(token: widget.token, product: v))); }),
            ListTile(
              leading: const CircleAvatar(radius: 18, backgroundColor: Color(0xFFFFEBEB),
                child: Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18)),
              title: const Text("Delete Product", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () { Navigator.pop(context); _confirmDelete(v, pid); }),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _activeFilter != "All" || _storeFilter.isNotEmpty;
    final storeLabel = _storeFilter.isEmpty ? "" : (_myStores.firstWhere(
        (st) => (st["_id"] ?? "").toString() == _storeFilter, orElse: () => <String,dynamic>{})["store_name"] ?? "Store").toString();
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: merchantHeaderBar(eyebrow: "Catalogue", title: "My Products", back: true,
                actions: [
          // Filter button with active indicator — unchanged, kept before the + button
          Stack(clipBehavior: Clip.none, children: [
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
              color: hasFilter ? kMerchantPrimary : kMerchantMuted,
              tooltip: "Filter",
              onPressed: _openFilter,
            ),
            if (hasFilter)
              Positioned(top: 8, right: 8,
                child: Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: kMerchantPrimary, shape: BoxShape.circle))),
          ]),
          Padding(
            padding:const EdgeInsets.only(right:18),
            child:offroHeaderAddButton(
              icon:Icons.add,
              tooltip:"New Product",
              onPressed:()=>Navigator.push(context, appRoute(AddProductPage(token: widget.token))).then((_) => _load()),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // ── Expiry warning banner ──
        if (_expiryWarnings.isNotEmpty) ExpiryWarningBanner(
          expiring: List<Map<String,dynamic>>.from(
              _expiryWarnings.whereType<Map>().map((e) => Map<String,dynamic>.from(e))),
          onRenewTap: () => setState(() { _activeFilter = "expired"; _applyFilters(); }),
        ),

        _slotBanner(),

        // ── Search + active filter chip ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(_applyFilters),
              decoration: InputDecoration(
                hintText: "Search products…",
                hintStyle: const TextStyle(color: kMerchantMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: kMerchantMuted, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18, color: kMerchantMuted),
                        onPressed: () { _searchCtrl.clear(); setState(_applyFilters); })
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true, fillColor: Colors.white,
                border:        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantPrimary, width: 1.5)),
              ),
            )),
          ]),
        ),
        // Active filter label
        if (hasFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              if (_storeFilter.isNotEmpty) ...[
                Flexible(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: kMerchantPrimary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kMerchantPrimary.withValues(alpha: .3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.store_rounded, size: 13, color: kMerchantPrimary),
                    const SizedBox(width: 5),
                    Flexible(child: Text(storeLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kMerchantPrimary, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() { _storeFilter = ""; _applyFilters(); }),
                      child: const Icon(Icons.close_rounded, size: 13, color: kMerchantPrimary)),
                  ]),
                )),
                const SizedBox(width: 6),
              ],
              if (_activeFilter != "All") Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kMerchantPrimary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kMerchantPrimary.withValues(alpha: .3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.filter_list_rounded, size: 13, color: kMerchantPrimary),
                  const SizedBox(width: 5),
                  Text(_activeFilter == "approved" ? "Live"
                    : _activeFilter == "pending_approval" ? "Pending"
                    : _activeFilter == "expired" ? "Expired"
                    : _activeFilter,
                    style: const TextStyle(fontSize: 12, color: kMerchantPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() { _activeFilter = "All"; _applyFilters(); }),
                    child: const Icon(Icons.close_rounded, size: 13, color: kMerchantPrimary)),
                ]),
              ),
              const Spacer(),
              Text("${_filtered.length} result${_filtered.length == 1 ? '' : 's'}",
                style: const TextStyle(fontSize: 12, color: kMerchantMuted)),
            ]),
          ),
        const SizedBox(height: 8),

        // ── List ──
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: kMerchantPrimary))
          : _loadError
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, color: kMerchantMuted, size: 48),
                  const SizedBox(height: 12),
                  const Text("Couldn't load products", style: TextStyle(color: kMerchantText, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(onPressed: ()=>_load(), icon: const Icon(Icons.refresh), label: const Text("Retry"),
                    style: ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor: kMerchantPrimary, foregroundColor: Colors.white)),
                ]))
          : _filtered.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.local_activity_outlined, size: 64, color: kMerchantAccent),
                  const SizedBox(height: 12),
                  Text(_products.isEmpty ? "No products yet" : "No matching products",
                    style: const TextStyle(color: kMerchantMuted, fontSize: 16)),
                  if (_products.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 6),
                      child: Text("Tap + New Product to get started",
                        style: TextStyle(color: kMerchantMuted, fontSize: 13))),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 180),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildCard(_filtered[i]),
                  ),
                ),
        ),
      ]),
    );
  }

  /// "8 / 10 free product slots used" + the additional-product price once
  /// every free slot is taken. Numbers come from the backend (never hard-coded).
  Widget _slotBanner() {
    final s = _slots;
    if (s == null) return const SizedBox.shrink();
    final used  = (s["used"] as num?)?.toInt() ?? 0;
    final limit = (s["free_limit"] as num?)?.toInt();
    if (limit == null) return const SizedBox.shrink();   // limit unknown → show nothing, never a made-up number
    final ppd = (s["price_per_day"] as num?)?.toDouble() ?? 0;
    final allUsed = used >= limit;
    final priceTxt = ppd == ppd.truncate() ? "₹${ppd.toInt()}" : "₹${ppd.toStringAsFixed(2)}";
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: OffroColors.mint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMerchantBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.inventory_2_outlined, size: 16, color: kMerchantPrimary),
          const SizedBox(width: 8),
          Text("$used / $limit free product slots used",
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kMerchantText)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: limit <= 0 ? 1 : (used / limit).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white,
            valueColor: const AlwaysStoppedAnimation<Color>(kMerchantPrimary))),
        if (allUsed) ...[
          const SizedBox(height: 8),
          Text("Additional products are charged at $priceTxt per day of validity.",
            style: const TextStyle(fontSize: 12, color: kMerchantMuted)),
        ],
      ]),
    );
  }

  String _shortDate(String raw) {
    final dt = _parseAnyDate(raw);
    if (dt == null) return "";
    const m = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${dt.day} ${m[dt.month-1]} ${dt.year}";
  }

  Widget _buildCard(Map<String,dynamic> v) {
    final pid      = _pid(v);
    final status   = _effectiveStatus(v);
    final endRaw   = v["end_date"]?.toString() ?? "";
    final isActive = v["is_active"] as bool? ?? true;
    final isExpired  = status == "expired";
    final isFree   = (v["pricing_tier"] ?? "free").toString() == "free";

    // ── Status badge ──
    final (Color sc, String sl, IconData si) = switch(status) {
      "approved"         => (OffroColors.statusLive, "Live",    Icons.check_circle_rounded),
      "rejected"         => (Colors.red,              "Rejected",Icons.cancel_rounded),
      "expired"          => (Colors.red.shade400,     "Expired", Icons.event_busy_rounded),
      "subscription_expired" => (Colors.grey.shade600, "Paused", Icons.pause_circle_rounded),
      _                  => (OffroColors.statusPending, "Pending", Icons.hourglass_top_rounded),
    };
    final deactivated = !isActive && !isExpired && status == "approved";

    final expiryLabel = _shortDate(endRaw);
    final logoUrl = v["logo_url"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMerchantBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => _showImageFullscreen(context, logoUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72, height: 72,
                  child: _ProductThumb(logoUrl: logoUrl),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, children: [
                _StatusBadge(label: sl, color: sc, icon: si),
                _StatusBadge(
                  label: isFree ? "Free" : "Paid",
                  color: isFree ? OffroColors.statusLive : OffroColors.primary,
                  icon: isFree ? Icons.redeem_rounded : Icons.payments_outlined),
                if (deactivated)
                  _StatusBadge(label: "Deactivated", color: Colors.grey.shade600, icon: Icons.pause_circle_outline_rounded),
              ]),
              const SizedBox(height: 6),
              Text(v["title"] ?? "",
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kMerchantText),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              if ((v["offer_text"] ?? "").toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(v["offer_text"].toString(),
                  style: const TextStyle(fontSize: 12, color: kMerchantMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (expiryLabel.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.event_rounded, size: 11,
                    color: isExpired ? Colors.red : kMerchantMuted),
                  const SizedBox(width: 3),
                  Text(isExpired ? "Expired $expiryLabel" : "Expires $expiryLabel",
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: isExpired ? Colors.red : kMerchantMuted)),
                ]),
              ],
              Builder(builder: (_ctx) {
                final sName = (v["store_name"] ?? "").toString().trim();
                final sCity = (v["city"] ?? "").toString().trim();
                if (sName.isEmpty && sCity.isEmpty) return const SizedBox.shrink();
                final label = sName.isNotEmpty && sCity.isNotEmpty
                    ? "$sName  •  $sCity"
                    : sName.isNotEmpty ? sName : sCity;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Icon(Icons.store_mall_directory_rounded, size: 11, color: kMerchantMuted),
                    const SizedBox(width: 3),
                    Expanded(child: Text(label,
                      style: const TextStyle(fontSize: 11, color: kMerchantMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                );
              }),
            ])),

            Column(children: [
              GestureDetector(
                onTap: () => _openMore(v, pid),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: kMerchantBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kMerchantBorder)),
                  child: const Icon(Icons.more_vert_rounded, size: 18, color: kMerchantMuted),
                ),
              ),
              const SizedBox(height: 6),
              // An expired product cannot be switched back on - it has to be renewed.
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: isActive && !isExpired,
                  onChanged: (pid.isEmpty || isExpired) ? null : (_) => _toggleActive(v, pid),
                  activeColor: kMerchantPrimary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Text(isActive && !isExpired ? "On" : "Off",
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: isActive && !isExpired ? kMerchantPrimary : kMerchantMuted)),
            ]),
          ]),

          if (isExpired) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMerchantPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                icon: const Icon(Icons.autorenew_rounded, size: 16),
                label: const Text("Renew", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () => Navigator.push(context,
                  appRoute(RenewProductPage(token: widget.token, product: v))).then((_) => _load()),
              )),
          ],
        ]),
      ),
    );
  }

  Future<void> _showEditDialog(Map<String,dynamic> v, String pid) async {
    final tCtrl  = TextEditingController(text: v["title"] ?? "");
    final oCtrl  = TextEditingController(text: v["offer_text"] ?? "");
    final opCtrl = TextEditingController(text: (v["original_price"] ?? v["original_amount"] ?? "").toString());
    final prCtrl = TextEditingController(text: (v["price"] ?? v["offer_price"] ?? v["amount"] ?? "").toString());
    final saved  = await showDialog<Map<String,dynamic>>(context: context, builder: (_) => AlertDialog(
      title: const Text("Edit Product", style: TextStyle(color: kMerchantPrimary, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _EditField(ctrl: tCtrl,  label: "Title"),
        const SizedBox(height: 10),
        _EditField(ctrl: oCtrl,  label: "Offer Text"),
        const SizedBox(height: 10),
        _EditField(ctrl: opCtrl, label: "Original Price", type: TextInputType.number),
        const SizedBox(height: 10),
        _EditField(ctrl: prCtrl, label: "Offer Price",    type: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: kMerchantMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor: kMerchantPrimary),
          onPressed: () {
            final opVal = double.tryParse(opCtrl.text.trim());
            final prVal = double.tryParse(prCtrl.text.trim());
            Navigator.pop(context, <String,dynamic>{
              "title": tCtrl.text.trim(),
              "offer_text": oCtrl.text.trim(),
              if (opVal != null) "original_price": opVal,
              if (prVal != null) "price": prVal,
              if (prVal != null) "amount": prVal,
            });
          },
          child: const Text("Save", style: TextStyle(color: Colors.white))),
      ],
    ));
    if (saved != null && saved.isNotEmpty) {
      try {
        if (pid.isEmpty) throw Exception("Product ID missing — cannot update");
        await Api.updateMerchantProduct(widget.token, pid, saved);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product updated!"), backgroundColor: OffroColors.statusLive));
      } catch (e) {
        debugPrint('[MerchantProducts] update error: $e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${friendlyError(e)}"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmDelete(Map<String,dynamic> v, String pid) async {
    final confirm = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text("Delete this product?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Text("\"${v['title'] ?? 'This product'}\" will be permanently removed and cannot be reactivated. "
          "Any payment already made for this product will not be refunded."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: kMerchantMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete Product", style: TextStyle(color: Colors.white))),
      ],
    ));
    if (confirm == true && mounted) {
      try {
        await Api.deleteMerchantProduct(widget.token, pid);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product deleted."), backgroundColor: Colors.red));
      } catch (e) {
        debugPrint('[MerchantProducts] delete error: $e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting: ${friendlyError(e)}"), backgroundColor: Colors.red));
      }
    }
  }
}

// ── Compact status badge ────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusBadge({required this.label, required this.color, required this.icon});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Inline edit field helper ──
class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType type;
  const _EditField({required this.ctrl, required this.label, this.type = TextInputType.text});
  @override Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: type,
    decoration: InputDecoration(
      labelText: label, isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
    ));
}

// ── Product image thumbnail — handles both URL and base64 ──
class _ProductThumb extends StatelessWidget {
  final String logoUrl;
  const _ProductThumb({required this.logoUrl});
  @override Widget build(BuildContext context) {
    if (logoUrl.isEmpty) {
      return Container(width:48,height:48,
        decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(10)),
        child:const Icon(Icons.local_activity,color:kMerchantPrimary,size:24));
    }
    if (logoUrl.startsWith("data:image")) {
      try {
        final bytes = base64Decode(logoUrl.split(",").last);
        return ClipRRect(borderRadius:BorderRadius.circular(10),
          child:Image.memory(bytes,width:48,height:48,fit:BoxFit.cover,
            errorBuilder:(_,__,___) => Container(width:48,height:48,
              decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(10)),
              child:const Icon(Icons.local_activity,color:kMerchantPrimary,size:24))));
      } catch (_) {
        return Container(width:48,height:48,
          decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(10)),
          child:const Icon(Icons.local_activity,color:kMerchantPrimary,size:24));
      }
    }
    return Container(width:48,height:48,
      decoration:BoxDecoration(
        color:kMerchantLight.withValues(alpha:.5),
        borderRadius:BorderRadius.circular(10),
        image:DecorationImage(image:NetworkImage(logoUrl),fit:BoxFit.cover),
      ));
  }
}

// ══════════════════════════════════════════════════════════
// ADD PRODUCT — one product type. Free while free slots remain, otherwise the
// backend-configured additional-product price. The backend makes the final call.
// ══════════════════════════════════════════════════════════
class AddProductPage extends StatefulWidget {
  final String token;
  const AddProductPage({super.key, required this.token});
  @override State<AddProductPage> createState() => _AddProductState();
}
class _AddProductState extends State<AddProductPage> {
  final _titleC          = TextEditingController();
  final _offerC          = TextEditingController();
  final _priceC          = TextEditingController();
  final _originalPriceC  = TextEditingController();
  final _discountVC = TextEditingController(); // discount code input
  String? _logoB64; bool _loading=false; String _msg="";
  DateTime _fromDate = DateTime.now();
  // Merchant-chosen end date (valid through that day).
  DateTime _endDate  = DateTime.now().add(const Duration(days:29));
  final _daysC = TextEditingController(text:"30");   // subscription length in days (synced with end date)
  Map<String,dynamic>? _slots;   // free-slot usage + price per day (estimate; backend decides)
  String? _selCity;
  // ── Store selection ──
  List<Map<String,dynamic>> _stores = [];
  Map<String,dynamic>? _selectedStore;
  bool _storesLoading = false;
  late Razorpay _razorpay;
  Map<String,dynamic>? _pendingOrder;
  // Item 6: code-based discount
  bool   _applyingVCode    = false;
  String _appliedVCode     = "";
  double _appliedVDiscount = 0.0;
  String? _appliedVDiscountType;
  String _discountVMsg     = "";
  bool   _discountVOk      = false;

  @override void initState() {
    super.initState();
    _loadSlots();
    _loadStores();
    _razorpay=Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,_onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,  _onPayError);
  }

  Future<void> _loadStores() async {
    if (!mounted) return;
    setState(() => _storesLoading = true);
    try {
      final list = await Api.getMerchantStores(widget.token);
      if (mounted) setState(() {
        _stores = List<Map<String,dynamic>>.from(list);
        if (_stores.length == 1) _onStoreSelected(_stores.first);
        _storesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _storesLoading = false);
    }
  }

  void _onStoreSelected(Map<String,dynamic> store) {
    final city = (store["city"] ?? "").toString().trim();
    setState(() {
      _selectedStore = store;
      if (city.isNotEmpty) _selCity = city;
      _slots = null;                      // quota belongs to the store: reload for the new one
    });
    _loadSlots();
  }
  @override void dispose(){ _titleC.dispose();_offerC.dispose();_priceC.dispose();_originalPriceC.dispose();_discountVC.dispose(); _daysC.dispose(); _razorpay.clear(); super.dispose(); }

  // Free slots are counted PER STORE, so the quota is loaded for the selected store.
  String get _selectedStoreId => (_selectedStore?["_id"] ?? _selectedStore?["id"] ?? "").toString();
  String _slotsForStore = "";
  Future<void> _loadSlots() async {
    final sid = _selectedStoreId;
    if (sid.isEmpty) { if (mounted) setState(() { _slots = null; _slotsForStore = ""; }); return; }
    final sl = await Api.getProductSlots(widget.token, storeId: sid);
    if (mounted && sid == _selectedStoreId) setState(() { _slots = sl; _slotsForStore = sid; });
  }

  DateTime get _fromDay => DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
  // Inclusive: a product is live THROUGH its end date (start == end is 1 day).
  int get _days => DateTime(_endDate.year, _endDate.month, _endDate.day).difference(_fromDay).inDays + 1;
  bool get _slotsKnown => _slots != null && _slotsForStore == _selectedStoreId;
  bool get _nextIsFree => !_slotsKnown ? true : (_slots!["next_is_free"] as bool? ?? true);
  int get _freeLimit => (_slots?["free_limit"] as num?)?.toInt() ?? 0;
  int get _freeRemaining => (_slots?["free_remaining"] as num?)?.toInt() ?? 0;
  int get _maxDays => (_slots?["max_validity_days"] as num?)?.toInt() ?? 365;
  double get _pricePerDay => (_slots?["price_per_day"] as num?)?.toDouble() ?? 0;
  String _money(double v) => v == v.truncate() ? "₹${v.toInt()}" : "₹${v.toStringAsFixed(2)}";
  // Preview only: price = configured per-day price × days. The order response is authoritative.
  double get _basePrice => _nextIsFree || _days < 1 ? 0 : double.parse((_pricePerDay * _days).toStringAsFixed(2));
  double get _gstPct=>(_slots?["gst_pct"] as num?)?.toDouble()??18;
  double get _discountVAmt => previewDiscountAmount(_basePrice, _appliedVDiscountType, _appliedVDiscount);
  double get _taxableV => (_basePrice - _discountVAmt) < 0 ? 0 : (_basePrice - _discountVAmt);
  double get _gst=>double.parse((_taxableV*_gstPct/100).toStringAsFixed(2));
  double get _total=>double.parse((_taxableV+_gst).toStringAsFixed(2));

  String get _fromDateStr=>"${_fromDate.year}-${_fromDate.month.toString().padLeft(2,'0')}-${_fromDate.day.toString().padLeft(2,'0')}";
  String get _endDateStr=>"${_endDate.year}-${_endDate.month.toString().padLeft(2,'0')}-${_endDate.day.toString().padLeft(2,'0')}";
  String get _fromDateDisplay=>"${_fromDate.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_fromDate.month-1]} ${_fromDate.year}";
  String get _endDateDisplay=>"${_endDate.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_endDate.month-1]} ${_endDate.year}";

  Future<void> _pickFromDate() async {
    final picked=await showDatePicker(context:context,initialDate:_fromDate,
      firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));
    if(picked!=null) setState((){
      final keep=_days<1?30:_days;          // keep the chosen number of days when the start moves
      _fromDate=picked;
      _endDate=DateTime(picked.year,picked.month,picked.day).add(Duration(days:keep-1));
    });
  }

  void _setDaysFromText(String raw){
    final n=int.tryParse(raw.trim());
    if(n==null||n<1) return;
    setState((){ _endDate=_fromDay.add(Duration(days:n-1)); });
  }

  Future<void> _pickEndDate() async {
    final first=_fromDay;
    final picked=await showDatePicker(context:context,
      initialDate:_endDate.isBefore(first)?first:_endDate,
      firstDate:first,lastDate:_fromDay.add(Duration(days:_maxDays-1)));
    if(picked!=null) setState((){ _endDate=picked; _daysC.text="$_days"; });
  }

  Future<void> _pickLogo() async {
    final picker=ImagePicker();
    final img=await picker.pickImage(source:ImageSource.gallery,imageQuality:80,maxWidth:400);
    if(img==null)return;
    final bytes=await File(img.path).readAsBytes();
    if(bytes.length>1*1024*1024){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text("Logo too large. Max 1MB."),backgroundColor:Colors.red));
      return;
    }
    setState(()=>_logoB64="data:image/jpeg;base64,${base64Encode(bytes)}");
  }


  // Item 6: Apply discount code — product
  Future<void> _applyVDiscountCode() async {
    final code = _discountVC.text.trim().toUpperCase();
    if (code.isEmpty) { setState((){ _discountVMsg="Enter a code"; _discountVOk=false; }); return; }
    setState(()=>_applyingVCode=true);
    try {
      final res = await Api.validateDiscountCode(widget.token, code, scope: "PRODUCTS");
      final val = (res["value"] as num?)?.toDouble() ?? 0.0;
      final type = (res["type"]?.toString() ?? "VALUE").toUpperCase();
      if (mounted) setState((){
        _appliedVCode         = code;
        _appliedVDiscount     = val;
        _appliedVDiscountType = type;
        _discountVMsg     = res["message"]?.toString() ??
            (type == "PERCENTAGE"
                ? "✅ Code applied — ${val.toStringAsFixed(0)}% off!"
                : "✅ Code applied — ₹${val.toStringAsFixed(0)} off!");
        _discountVOk      = true;
        _applyingVCode    = false;
      });
    } catch (e) {
      if (mounted) setState((){
        _appliedVCode         = "";
        _appliedVDiscount     = 0;
        _appliedVDiscountType = null;
        _discountVMsg     = friendlyError(e);
        _discountVOk      = false;
        _applyingVCode    = false;
      });
    }
  }


  Future<void> _proceed() async {
    if(_titleC.text.trim().isEmpty){setState(()=>_msg="Product title required");return;}
    if(_selectedStore==null){setState(()=>_msg="Please select a store for this product");return;}
    if(_selCity==null||_selCity!.trim().isEmpty){setState(()=>_msg="Please select a city for this product");return;}
    if(_logoB64==null){setState(()=>_msg="Please upload a product image");return;}
    if(_days<1){setState(()=>_msg="Enter the number of days (minimum 1)");return;}
    if(_slotsKnown && _days>_maxDays){setState(()=>_msg="Maximum validity is $_maxDays days");return;}
    setState((){_loading=true;_msg="";});
    try{
      // Item 1 (draft-store lock): send store_id here too so a draft/
      // unsubscribed store is rejected fail-fast at order-creation time
      // (backend's create_voucher_order() treats it as optional) instead of
      // only at activation — activate_free_voucher()/verify_voucher_payment()
      // still enforce it regardless.
      // Free vs paid and the price are decided by the backend from the live slot
      // count - the client only sends the validity the merchant picked.
      final order=await Api.createProductOrder(widget.token,{
        "from_date":_fromDateStr,
        "end_date":_endDateStr,
        "days":_days,
        "discount_code":_nextIsFree?"":_appliedVCode,
        "store_id":(_selectedStore?["_id"] ?? _selectedStore?["id"] ?? "").toString(),
      });
      if(!mounted)return;
      final payMode=order["pay_mode"]??"manual";
      final amtPaise=(order["amount_paise"] as num?)?.toInt()??0;

      if(payMode=="manual"||amtPaise<=0){
        final confirmed=await _showProductSummaryDialog(order,manual:true);
        if(confirmed==true&&mounted){
          final res=await Api.activateFreeProduct(widget.token,{
            "order_id":       order["order_id"],
            "title":          _titleC.text.trim(),
            "offer_text":     _offerC.text.trim(),
            "logo_url":       _logoB64??"",
            "price":          _priceC.text.trim(),
            "original_price": _originalPriceC.text.trim(),
            "store_id":       (_selectedStore?["_id"] ?? _selectedStore?["id"] ?? "").toString(),
            "store_name":     (_selectedStore?["store_name"] ?? "").toString(),
            "city":           _selCity ?? "",
          });
          if(mounted){
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:Text("✅ Product submitted! ${res['message']??''}"),
              backgroundColor:OffroColors.statusLive));
          }
        }
      } else {
        final confirmed=await _showProductSummaryDialog(order,manual:false);
        if(confirmed==true&&mounted) _openRazorpay(order);
      }
    }catch(e){setState(()=>_msg=friendlyError(e));}
    if(mounted)setState(()=>_loading=false);
  }

  void _openRazorpay(Map order){
    final rzpKey = order["razorpay_key"]?.toString() ?? '';
    final rzpOrderId = order["razorpay_order_id"]?.toString() ?? '';
    if (rzpKey.isEmpty || rzpOrderId.isEmpty) {
      setState(()=>_msg="Payment gateway not configured. Contact support.");
      return;
    }
    _pendingOrder=Map<String,dynamic>.from(order);
    // FIX 4: ensure amount is int and handle launch errors
    try {
    _razorpay.open({
      "key":rzpKey,
      "amount":(order["amount_paise"] as num?)?.toInt()??0,
      "name":"OFFRO",
      "description":"Additional product",
      "order_id":rzpOrderId,
      "prefill":{"contact":"","email":""},
      "theme":{"color":"#3E5F55"},
    });
    } catch(e) {
      debugPrint('[MerchantProducts] Razorpay open error: $e');
      if(mounted) setState(()=>_msg="Payment error: ${friendlyError(e, fallback: "Could not open payment. Please try again.")}");
    }
  }

  void _onPaySuccess(PaymentSuccessResponse res) async {
    if(_pendingOrder==null||!mounted)return;
    final captured=_pendingOrder;
    _pendingOrder=null;   // T1/T4: clear immediately to prevent double-fire
    try{
      final result=await Api.verifyProductPayment(widget.token,{
        "order_id":           captured!["order_id"],
        "title":              _titleC.text.trim(),
        "offer_text":         _offerC.text.trim(),
        "logo_url":           _logoB64??"",
        "city":               _selCity??"",
        "store_id":           (_selectedStore?["_id"] ?? _selectedStore?["id"] ?? "").toString(),
        "store_name":         (_selectedStore?["store_name"] ?? "").toString(),
        "razorpay_payment_id":res.paymentId,
        "razorpay_order_id":  res.orderId,
        "razorpay_signature": res.signature,
      });
      if(mounted){
        // FIX 3: Capture navigator before pushReplacement so onDone works after context deactivated
        final nav = Navigator.of(context);
        final invoiceNo = result["invoice_no"]?.toString() ?? result["message"]?.toString() ?? "";
        nav.pushReplacement(MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            storeName: _titleC.text.trim(),
            invoiceNo: invoiceNo,
            onDone: () => nav.popUntil((r) => r.isFirst),
          ),
        ));
      }
    }catch(e){if(mounted)setState(()=>_msg=friendlyError(e));}
  }

  void _onPayError(PaymentFailureResponse res){
    if(mounted)setState(()=>_msg="Payment failed: ${friendlyRazorpayError(res.message)}");
  }

  Future<bool?> _showProductSummaryDialog(Map order,{required bool manual})=>
    showDialog<bool>(context:context,builder:(_)=>AlertDialog(
      title:const Text("Product Order Summary",style:TextStyle(color:kMerchantPrimary,fontWeight:FontWeight.bold)),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        _dRow("Title",_titleC.text.trim()),
        _dRow("Offer",_offerC.text.trim()),
        _dRow("Plan",order['pricing_tier']=="free"?"Free product":"Additional product"),
        _dRow("Period","${order['from_date']} → ${order['end_date']}"),
        if(order['pricing_tier']!="free") ...[
          const Divider(),
          _dRow("Price","₹${order['base_price']}"),
          if((order['discount_amount']??0)>0) _dRow("Discount","−₹${order['discount_amount']}",
            color:OffroColors.statusLive),
          _dRow("GST (${order['gst_percent']}%)","₹${order['gst_amount']}"),
          _dRow("Total","₹${order['amount_display']}",bold:true),
        ],
        const SizedBox(height:10),
        Container(padding:const EdgeInsets.all(10),
          decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(8)),
          child:Text(manual?"Product will go to admin review. No payment needed.":"Razorpay opens. Product live after admin approval.",
            style:const TextStyle(fontSize:12,color:kMerchantPrimary))),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text("Cancel",style:TextStyle(color:kMerchantMuted))),
        ElevatedButton(
          style:ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor:kMerchantPrimary),
          onPressed:()=>Navigator.pop(context,true),
          child:Text(manual?"Save Product":"Pay ₹${order['amount_display']}",style:const TextStyle(color:Colors.white))),
      ],
    ));

  Widget _dRow(String k,String v,{bool bold=false,Color? color})=>Padding(
    padding:const EdgeInsets.symmetric(vertical:3),
    child:Row(children:[
      Expanded(child:Text(k,style:const TextStyle(color:kMerchantMuted,fontSize:13))),
      Text(v,style:TextStyle(fontSize:13,fontWeight:bold?FontWeight.bold:FontWeight.w500,color:color??(bold?kMerchantPrimary:kMerchantText))),
    ]));

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:kMerchantBg,
    appBar:AppBar(title:const Text("Add Product"), ),
    body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      // Free / additional notice - shown BEFORE the form so the price is never a surprise
      _pricingNotice(),
      // Fields
      _field(_titleC,"Product Title *","e.g. Raj Store ₹50 Off",Icons.confirmation_number),
      const SizedBox(height:12),
      _field(_offerC,"Offer Text","e.g. Get ₹50 off on orders above ₹299",Icons.local_offer),
      const SizedBox(height:12),

      // Price fields — optional
      Row(children:[
        Expanded(child:_field(_originalPriceC,"Original Price","e.g. 299",Icons.currency_rupee,keyboardType:TextInputType.number)),
        const SizedBox(width:10),
        Expanded(child:_field(_priceC,"Offer Price","e.g. 199",Icons.local_offer_outlined,keyboardType:TextInputType.number)),
      ]),
      const SizedBox(height:4),
      const Padding(
        padding:EdgeInsets.only(left:4,bottom:8),
        child:Text("Discount is auto-calculated from prices",
          style:TextStyle(color:kMerchantMuted,fontSize:11)),
      ),

      // ── Store selection (mandatory, above city) ──
      if (_storesLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: kMerchantPrimary))),
        )
      else
        DropdownButtonFormField<Map<String,dynamic>>(
          isExpanded: true,
          value: _selectedStore,
          hint: const Text("Select Store *"),
          items: _stores.map((s) => DropdownMenuItem<Map<String,dynamic>>(
            value: s,
            child: Text(s["store_name"]?.toString() ?? "Unnamed Store",
              overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (s) { if (s != null) _onStoreSelected(s); },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.store, color: kMerchantMuted, size: 20),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)))),
      const SizedBox(height: 12),

      // ── City (auto-filled from store, read-only) ──
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: OffroColors.mint,
          border: Border.all(color: kMerchantBorder),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.location_city, color: kMerchantMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(
            (_selCity != null && _selCity!.isNotEmpty) ? _selCity! : "City auto-filled from store",
            style: TextStyle(
              color: (_selCity != null && _selCity!.isNotEmpty) ? kMerchantText : kMerchantMuted,
              fontSize: 15))),
          if (_selCity != null && _selCity!.isNotEmpty)
            const Icon(Icons.check_circle, color: kMerchantPrimary, size: 18),
        ]),
      ),
      const SizedBox(height: 12),

      // Logo upload
      GestureDetector(
        onTap:_pickLogo,
        child:Container(
          height:90,
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:_logoB64!=null?kMerchantPrimary:kMerchantBorder,width:_logoB64!=null?2:1)),
          child:_logoB64!=null
            ? Stack(children:[
                Center(child:ClipRRect(borderRadius:BorderRadius.circular(11),
                  child:Image.memory(base64Decode(_logoB64!.split(",").last),height:80,width:80,fit:BoxFit.cover))),
                Positioned(top:4,right:4,child:GestureDetector(onTap:()=>setState(()=>_logoB64=null),
                  child:Container(padding:const EdgeInsets.all(3),decoration:const BoxDecoration(color:Colors.red,shape:BoxShape.circle),
                    child:const Icon(Icons.close,color:Colors.white,size:12)))),
              ])
            : Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                const Icon(Icons.image_rounded,size:28,color:kMerchantAccent),
                const SizedBox(height:4),
                const Text("Upload Image",style:TextStyle(color:kMerchantMuted,fontSize:12)),
                Row(mainAxisAlignment:MainAxisAlignment.center,children:[_InfoChip("📐 400×400px"),const SizedBox(width:6),_InfoChip("📦 Max 1MB")]),
              ]),
        )),
      const SizedBox(height:12),

      // Start date + end date (merchant decides how long the product stays live)
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Validity (Days)",style:TextStyle(fontWeight:FontWeight.w700,color:kMerchantText,fontSize:13)),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:_dateTile("Start date",_fromDateDisplay,_pickFromDate)),
            const SizedBox(width:10),
            Expanded(child:_dateTile("End date",_endDateDisplay,_pickEndDate)),
          ]),
          const SizedBox(height:10),
          TextField(
            controller:_daysC,
            keyboardType:TextInputType.number,
            inputFormatters:[FilteringTextInputFormatter.digitsOnly],
            onChanged:_setDaysFromText,
            decoration:InputDecoration(
              labelText:"Number of days",
              hintText:"e.g. 30",
              helperText:_slotsKnown?"Maximum $_maxDays days":null,
              prefixIcon:const Icon(Icons.calendar_month_rounded,color:kMerchantMuted,size:20),
              filled:true,fillColor:Colors.white,
              border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
              enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
              contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:14))),
          if(_days>0) Padding(padding:const EdgeInsets.only(top:10),
            child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
              decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(8)),
              child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                const Text("Live period:",style:TextStyle(fontSize:12,color:kMerchantMuted)),
                Text("$_fromDateDisplay → $_endDateDisplay",style:const TextStyle(fontSize:12,color:kMerchantPrimary,fontWeight:FontWeight.w600)),
              ]),
            )),
        ])),
      const SizedBox(height:12),

      if (_slotsKnown && _nextIsFree && _days>0)
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(12)),
          child:_dRow("$_days ${_days==1?'day':'days'}","Free (₹0)",bold:true)),
      if (_slotsKnown && !_nextIsFree && _days>0)
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(12)),
          child:Column(children:[
            _dRow("$_days ${_days==1?'day':'days'} × ${_money(_pricePerDay)}/day",_money(_basePrice)),
            if(_discountVAmt>0) _dRow("Discount","−${_money(_discountVAmt)}",color:OffroColors.statusLive),
            _dRow("GST (${_gstPct.toInt()}%)","₹${_gst.toStringAsFixed(2)}"),
            const Divider(height:16),
            _dRow("Total","₹${_total.toStringAsFixed(2)}",bold:true),
          ])),

      const SizedBox(height:4),
      if(_msg.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:6),
        child:Text(_msg,style:const TextStyle(color:Colors.red,fontSize:12))),
      const SizedBox(height:12),

      // Discount code - only relevant for an additional (paid) product
      if (_slotsKnown && !_nextIsFree) Container(
        padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Discount Code",style:TextStyle(fontWeight:FontWeight.w700,color:kMerchantText,fontSize:13)),
          const SizedBox(height:4),
          const Text("Have a promo code? Enter it below.",style:TextStyle(color:kMerchantMuted,fontSize:11)),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:TextField(
              controller:_discountVC,
              textCapitalization:TextCapitalization.characters,
              onChanged:(_){ if(_appliedVCode.isNotEmpty) setState((){_appliedVCode="";_appliedVDiscount=0;_appliedVDiscountType=null;_discountVMsg="";_discountVOk=false;}); },
              decoration:InputDecoration(
                hintText:"e.g. OFFRO20",isDense:true,
                prefixIcon:const Icon(Icons.local_offer_outlined,color:kMerchantMuted,size:18),
                contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
                enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:_discountVOk?kMerchantPrimary:kMerchantBorder)),
              ),
            )),
            const SizedBox(width:8),
            ElevatedButton(
              onPressed:_applyingVCode?null:_applyVDiscountCode,
              style:ElevatedButton.styleFrom(elevation: 0,  
                padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
                shape: const StadiumBorder()),
              child:_applyingVCode
                ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                : const Text("Apply",style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
            ),
          ]),
          if (_discountVMsg.isNotEmpty) ...[
            const SizedBox(height:6),
            Text(_discountVMsg,style:TextStyle(color:_discountVOk?OffroColors.statusLive:Colors.red,fontWeight:FontWeight.w600,fontSize:12)),
          ],
          if (_appliedVDiscount > 0) ...[
            const SizedBox(height:6),
            Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
              decoration:BoxDecoration(color:kMerchantLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(8)),
              child:Row(children:[
                const Icon(Icons.check_circle,color:OffroColors.statusLive,size:14),
                const SizedBox(width:6),
                Text(_appliedVDiscountType == "PERCENTAGE"
                      ? "−₹${_discountVAmt.toStringAsFixed(2)} (${_appliedVDiscount.toStringAsFixed(0)}%) off  →  Total: ₹${_total.toStringAsFixed(2)}"
                      : "−₹${_appliedVDiscount.toStringAsFixed(0)} off  →  Total: ₹${_total.toStringAsFixed(2)}",
                  style:const TextStyle(color:OffroColors.statusLive,fontWeight:FontWeight.w700,fontSize:12)),
              ]),
            ),
          ],
        ])),
      const SizedBox(height:16),
      const SizedBox(height:12),
      ElevatedButton.icon(
        icon:_loading?const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):const Icon(Icons.arrow_forward_rounded),
        label:Text(_nextIsFree?"Save Product":"Proceed to Checkout"),
        style:ElevatedButton.styleFrom(elevation: 0,  
          shape: const StadiumBorder(),
          padding:const EdgeInsets.symmetric(vertical:14)),
        onPressed:_loading?null:_proceed,
      ),
      const SizedBox(height:24),
    ])),
  );

  Widget _dateTile(String label,String value,VoidCallback onTap)=>GestureDetector(
    onTap:onTap,
    child:Container(
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),
      decoration:BoxDecoration(color:kMerchantBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:kMerchantBorder)),
      child:Row(children:[
        const Icon(Icons.event_rounded,size:18,color:kMerchantMuted),
        const SizedBox(width:8),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(label,style:const TextStyle(fontSize:11,color:kMerchantMuted)),
          Text(value,style:const TextStyle(fontSize:13,color:kMerchantText,fontWeight:FontWeight.w600)),
        ])),
      ]),
    ));

  /// Pricing notice: free slots remaining, or the additional-product price.
  Widget _pricingNotice(){
    if(!_slotsKnown) return const SizedBox.shrink();
    final free=_nextIsFree;
    return Container(
      margin:const EdgeInsets.only(bottom:14),
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:OffroColors.mint,borderRadius:BorderRadius.circular(16),border:Border.all(color:kMerchantBorder)),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(free?Icons.redeem_rounded:Icons.payments_outlined,color:kMerchantPrimary,size:22),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(free?"Free product":"Additional product",
            style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14,color:kMerchantText)),
          const SizedBox(height:3),
          Text(free
            ? "You have $_freeRemaining of $_freeLimit free product slots remaining."
            : "You have used all $_freeLimit free product slots.\nPrice is ${_money(_pricePerDay)} per day + GST for the days you choose.",
            style:const TextStyle(fontSize:12,color:kMerchantMuted)),
        ])),
      ]));
  }

  Widget _field(TextEditingController c,String label,String hint,IconData icon,{TextInputType keyboardType=TextInputType.text})=>TextField(
    controller:c,
    decoration:InputDecoration(
      labelText:label,hintText:hint,prefixIcon:Icon(icon,color:kMerchantMuted,size:20),
      filled:true,fillColor:Colors.white,
      border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
      enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
    ));
}



/// Format backend date string ("13 May 2026 14:30") → "13 May 2026, 2:30 PM"
String _fmtDateTime(String? raw) {
  // T3: Handles ISO "2026-05-21T14:37:00", datetime "2026-05-21 14:37", 
  //     and legacy "21 May 2026 14:37:00" formats.
  // Output: "21 May 2026 | 02:45 PM"
  if (raw == null || raw.isEmpty) return "";
  try {
    DateTime? dt;
    // Try ISO / datetime string parse first
    final clean = raw.trim().replaceAll("T", " ").split(".").first;
    dt = DateTime.tryParse(clean);
    if (dt == null) {
      // Legacy: "21 May 2026 14:37:00" — rebuild as parseable
      final months = {"Jan":1,"Feb":2,"Mar":3,"Apr":4,"May":5,"Jun":6,
                      "Jul":7,"Aug":8,"Sep":9,"Oct":10,"Nov":11,"Dec":12};
      final parts = clean.split(" ");
      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]);
        final mon = months[parts[1]];
        final yr  = int.tryParse(parts[2]);
        if (day != null && mon != null && yr != null) {
          int h=0, mi=0;
          if (parts.length >= 4) {
            final tp = parts[3].split(":");
            h  = int.tryParse(tp[0]) ?? 0;
            mi = int.tryParse(tp.length>1?tp[1]:"0") ?? 0;
          }
          dt = DateTime(yr, mon, day, h, mi);
        }
      }
    }
    if (dt == null) return raw;
    const mos = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    final d   = dt.day.toString().padLeft(2,"0");
    final mo  = mos[dt.month - 1];
    final yr  = dt.year;
    int   h   = dt.hour;
    final mi  = dt.minute.toString().padLeft(2,"0");
    final ampm = h >= 12 ? "PM" : "AM";
    h = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return "$d $mo $yr | ${h.toString().padLeft(2,'0')}:$mi $ampm";
  } catch (_) { return raw; }
}


class MerchantHome extends StatefulWidget {
  final String token; final Map merchant;
  const MerchantHome({super.key, required this.token, required this.merchant});
  @override State<MerchantHome> createState() => _MerchantHomeState();
}
class _MerchantHomeState extends State<MerchantHome> with WidgetsBindingObserver {
  int _idx = 0;
  // The merchant ACCOUNT location (device-only, shared Location screen).
  // Pages are not built — and no merchant API calls start — until a valid
  // location exists. This never reads or writes the registered store address.
  OffroLocation? _loc;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureLocation();
    // Silent GPS check AFTER the first frame, so it can never delay Home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_autoRefreshLocation());
    });
    // Same silent check, repeated while the app stays open (service throttles).
    _locTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (mounted && _lifecycle == AppLifecycleState.resumed) unawaited(_autoRefreshLocation());
    });
  }

  Timer? _locTimer;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override void dispose() {
    _locTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    // Silent GPS check on return to the app (throttled inside the service).
    if (state == AppLifecycleState.resumed) unawaited(_autoRefreshLocation());
  }

  // Silent GPS refresh of the shared device location (app open / resume).
  // Only replaces a saved GPS location after the person really moved; a manual
  // pick is never touched, nothing is prompted, failures keep the saved value.
  // Saves ONLY to the shared LocationStore: no Api.updateCity, and the
  // merchant's registered store address / lat / lng are never read or written.
  bool _autoLocBusy = false;
  bool _picking = false; // Location screen currently open
  Future<void> _autoRefreshLocation() async {
    if (_autoLocBusy) return;
    _autoLocBusy = true;
    try {
      if (!mounted || _picking) return;
      final saved = await LocationStore.load(LocationMode.merchant);
      final fresh = await LocationService.autoRefreshIfMoved(saved);
      if (fresh == null || !mounted || _picking) return;
      final oldCity = _loc?.city ?? saved?.city ?? '';
      await LocationStore.save(LocationMode.merchant, fresh);
      if (!mounted) return;
      setState(() => _loc = fresh);
      if (!fresh.sameCity(oldCity)) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text("Location updated to ${fresh.city}"),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } catch (_) {
      // keep the saved location
    } finally {
      _autoLocBusy = false;
    }
  }

  Future<void> _ensureLocation() async {
    final saved = await LocationStore.load(LocationMode.merchant);
    if (!mounted) return;
    if (saved != null && saved.hasCity) {
      setState(() => _loc = saved);
      return;
    }
    await _chooseLocation(mandatory: true);
  }

  Future<void> _chooseLocation({required bool mandatory}) async {
    _picking = true;
    final OffroLocation? picked;
    try {
      picked = await Navigator.push<OffroLocation>(
        context,
        MaterialPageRoute<OffroLocation>(
          builder: (_) => LocationScreen(mode: LocationMode.merchant, mandatory: mandatory, current: _loc),
        ),
      );
    } finally {
      _picking = false;
    }
    if (!mounted) return;
    if (picked != null) {
      await LocationStore.save(LocationMode.merchant, picked);
      if (!mounted) return;
      setState(() => _loc = picked);
    } else if (mandatory) {
      await _chooseLocation(mandatory: true); // never proceed without a location
    }
  }

  List<Widget> get _pages => [
    MerchantHomePage(
      token: widget.token,
      merchantName: widget.merchant['name']?.toString() ?? '',
      locationTitle: _loc?.title ?? '',
      locationSubtitle: _loc?.subtitle ?? '',
      onLocationTap: () => _chooseLocation(mandatory: false),
    ),
    MerchantDealsPage(token: widget.token),
    MerchantInvoicesPage(token: widget.token),
    MerchantTxnPage(token: widget.token),
    MerchantProfilePage(token: widget.token, merchant: widget.merchant),
  ];

  @override Widget build(BuildContext context) {
    if (_loc == null) {
      return const PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: kMerchantBg,
          body: Center(child: CircularProgressIndicator(color: kMerchantPrimary)),
        ),
      );
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: kMerchantBg,
        body: _pages[_idx],
        bottomNavigationBar: OffroBottomNav(
          variant: OffroNavVariant.merchant,
          items: OffroBottomNav.merchantItems,
          currentIndex: _idx,
          onTap: (i) => setState(() => _idx = i),
        ),
      ),
    );
  }
}

class MerchantStoresPage extends StatefulWidget {
  final String token;
  const MerchantStoresPage({super.key, required this.token});
  @override State<MerchantStoresPage> createState() => _MerchantStoresState();
}
class _MerchantStoresState extends State<MerchantStoresPage> {
  List<Map<String,dynamic>> stores = []; bool loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(()=>loading=true);
    stores = List<Map<String,dynamic>>.from(await Api.getMerchantStores(widget.token));
    if (mounted) setState(()=>loading=false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kMerchantBg,
    appBar: merchantHeaderBar(eyebrow: "Your business", title: "My Stores", back: true,
                actions:[
          Padding(
            padding:const EdgeInsets.only(right:18),
            child:offroHeaderAddButton(
              icon:Icons.add_business,
              tooltip:"New Store",
              onPressed:()=>Navigator.push(context,appRoute(AddEditStorePage(token:widget.token))).then((_)=>_load()),
            ),
          ),
        ]),
    body: loading ? const Center(child:CircularProgressIndicator(color:kMerchantPrimary)) :
      stores.isEmpty ? Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        buildLogo(44,kMerchantAccent), const SizedBox(height:12),
        const Text("No stores yet",style:TextStyle(color:kMerchantMuted,fontSize:16)),
        const SizedBox(height:8), const Text("Tap + to add your first store",style:TextStyle(color:kMerchantMuted,fontSize:13)),
      ])) :
      RefreshIndicator(onRefresh:_load,child:ListView.builder(
        padding:const EdgeInsets.all(14),
        itemCount:stores.length,
        itemBuilder:(_,i){
          final s = stores[i] as Map;
          final status = s["status"]??"draft";
          // Status badge config — small, consistent, colored
          Color sc = kMerchantMuted;
          String sl = status;
          if (status=="active") { sc=OffroColors.statusLive; sl="Active"; }
          else if (status=="expired") { sc=Colors.red.shade700; sl="Expired"; }
          else if (status=="waiting_approval") { sc=OffroColors.statusPending; sl="Pending"; }
          else if (status=="paid") { sc=OffroColors.statusPending; sl="Paid"; }
          else if (status=="draft") { sc=kMerchantMuted; sl="Draft"; }
          else if (status=="inactive") { sc=Colors.red.shade700; sl="Inactive"; }
          else if (status=="pending") { sc=kMerchantMuted; sl="Pending"; }
          else if (status=="deleted") { sc=Colors.red.shade400; sl="Deleted"; }
          else if (status=="removed") { sc=Colors.red.shade400; sl="Removed"; }

          final storeImg = (s["image"]??"").toString();
          Widget _thumb;
          if (storeImg.isNotEmpty) {
            _thumb = storeImg.startsWith("data:")
              ? Image.memory(base64Decode(storeImg.split(",").last),width:80,height:80,fit:BoxFit.cover,
                  errorBuilder:(_,__,___) => Container(width:80,height:80,color:kMerchantAccent,child:Center(child:Text((s["store_name"]??"S").toString().isNotEmpty?(s["store_name"]??"S")[0]:"S",style:const TextStyle(color:kMerchantPrimary,fontWeight:FontWeight.w900,fontSize:22)))))
              : Image.network(storeImg,width:80,height:80,fit:BoxFit.cover,
                  errorBuilder:(_,__,___) => Container(width:80,height:80,color:kMerchantAccent,child:Center(child:Text((s["store_name"]??"S").toString().isNotEmpty?(s["store_name"]??"S")[0]:"S",style:const TextStyle(color:kMerchantPrimary,fontWeight:FontWeight.w900,fontSize:22)))));
          } else {
            _thumb = Container(width:80,height:80,color:kMerchantAccent,child:Center(child:Text((s["store_name"]??"S").toString().isNotEmpty?(s["store_name"]??"S")[0]:"S",style:const TextStyle(color:kMerchantPrimary,fontWeight:FontWeight.w900,fontSize:22))));
          }

          // Category icon mapping
          final cat = (s["category"]??"").toString().toLowerCase();
          IconData catIcon = Icons.store;
          if (cat.contains("restaurant")) catIcon = Icons.restaurant;
          else if (cat.contains("bakery")) catIcon = Icons.bakery_dining;
          else if (cat.contains("cafe")||cat.contains("coffee")) catIcon = Icons.coffee;
          else if (cat.contains("grocery")||cat.contains("mart")||cat.contains("super")) catIcon = Icons.local_grocery_store;
          else if (cat.contains("pharmacy")||cat.contains("medical")) catIcon = Icons.local_pharmacy;
          else if (cat.contains("salon")||cat.contains("spa")||cat.contains("beauty")) catIcon = Icons.spa;
          else if (cat.contains("gym")||cat.contains("fitness")) catIcon = Icons.fitness_center;
          else if (cat.contains("cloth")||cat.contains("fashion")) catIcon = Icons.checkroom;
          else if (cat.contains("electronic")||cat.contains("mobile")) catIcon = Icons.devices;
          else if (cat.contains("book")) catIcon = Icons.menu_book;
          else if (cat.contains("toy")) catIcon = Icons.toys;

          // Build action-buttons row as a plain variable (avoids fragile inline
          // collection-if/else-if chains inside list literals, which are easy to
          // break with a stray trailing comma and hard for the Dart parser to recover from).
          Widget _actionButtons;
          if (status=="draft"||status=="inactive"||status=="pending_subscription"||status=="expired") {
            _actionButtons = Row(children:[
              Expanded(child:OutlinedButton.icon(
                icon:const Icon(Icons.edit,size:15,color:kMerchantPrimary), label:const Text("Edit",style:TextStyle(color:kMerchantPrimary,fontSize:12)),
                style:OutlinedButton.styleFrom(elevation: 0, side:const BorderSide(color:kMerchantPrimary),shape: const StadiumBorder(),padding:const EdgeInsets.symmetric(vertical:7)),
                onPressed:()=>Navigator.push(context,appRoute(AddEditStorePage(token:widget.token,store:s))).then((_)=>_load()))),
              const SizedBox(width:6),
              Expanded(child:ElevatedButton.icon(
                icon:const Icon(Icons.payment,size:15), label:const Text("Subscribe",style:TextStyle(fontSize:12)),
                style:ElevatedButton.styleFrom(elevation: 0, backgroundColor: kMerchantPrimary, foregroundColor: Colors.white,shape: const StadiumBorder(),padding:const EdgeInsets.symmetric(vertical:7)),
                onPressed:()=>Navigator.push(context,appRoute(SubscribePage(token:widget.token,store:s))).then((_)=>_load()))),
            ]);
          } else if (status=="waiting_approval") {
            _actionButtons = Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Center(child:Text("Awaiting Admin Approval",style:const TextStyle(color:OffroColors.statusPending,fontSize:11,fontWeight:FontWeight.w600))));
          } else if (status=="active") {
            _actionButtons = Row(children:[
              Expanded(child:OutlinedButton.icon(
                icon:const Icon(Icons.edit,size:15,color:kMerchantPrimary), label:const Text("Edit",style:TextStyle(color:kMerchantPrimary,fontSize:12)),
                style:OutlinedButton.styleFrom(elevation: 0, side:const BorderSide(color:kMerchantPrimary),shape: const StadiumBorder(),padding:const EdgeInsets.symmetric(vertical:7)),
                onPressed:()=>Navigator.push(context,appRoute(AddEditStorePage(token:widget.token,store:s))).then((_)=>_load()))),
              const SizedBox(width:6),
              Expanded(child:OutlinedButton.icon(
                icon:const Icon(Icons.add_shopping_cart,size:15,color:kMerchantPrimary),label:const Text("Deals",style:TextStyle(color:kMerchantPrimary,fontSize:12)),
                style:OutlinedButton.styleFrom(elevation: 0, side:const BorderSide(color:kMerchantBorder),shape: const StadiumBorder(),padding:const EdgeInsets.symmetric(vertical:7)),
                onPressed:()=>Navigator.push(context,appRoute(AddDealPage(token:widget.token,storeId:s["_id"]??"",storeName:s["store_name"]??""))))),
              const SizedBox(width:6),
              Expanded(child:OutlinedButton.icon(
                icon:Icon((s["qr_code"]??'').isNotEmpty?Icons.qr_code:Icons.crop_free,size:15,color:kMerchantPrimary),
                label:Text((s["qr_code"]??'').isNotEmpty?"QR":"Gen QR",style:const TextStyle(color:kMerchantPrimary,fontSize:12)),
                style:OutlinedButton.styleFrom(elevation: 0, side:const BorderSide(color:kMerchantBorder),shape: const StadiumBorder(),padding:const EdgeInsets.symmetric(vertical:7)),
                onPressed:(s["qr_code"]??'').isNotEmpty
                  ?()=>_showQR(context,s["store_name"]??"",s["qr_code"]??'')
                  :() async {
                      final sid = s["_id"]??"";
                      try {
                        final res = await Api.resetStoreQr(sid, widget.token);
                        final qr = res["qr_code"]??"";
                        if(qr.isNotEmpty){ setState(()=>s["qr_code"]=qr); if(mounted)_showQR(context,s["store_name"]??"",qr); }
                      } catch(e){ debugPrint('[MerchantStores] reset QR error: $e'); if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text("Failed: ${friendlyError(e)}"))); }
                    })),
            ]);
          } else {
            _actionButtons = Row(children:[
              Expanded(child:OutlinedButton.icon(
                icon:const Icon(Icons.edit,size:15,color:kMerchantPrimary), label:const Text("Edit",style:TextStyle(color:kMerchantPrimary,fontSize:12)),
                style:OutlinedButton.styleFrom(elevation: 0, side:const BorderSide(color:kMerchantPrimary),shape: const StadiumBorder(),padding:const EdgeInsets.symmetric(vertical:7)),
                onPressed:()=>Navigator.push(context,appRoute(AddEditStorePage(token:widget.token,store:s))).then((_)=>_load()))),
            ]);
          }

          return Container(
            margin:const EdgeInsets.only(bottom:10),
            decoration:BoxDecoration(
              color:Colors.white,
              borderRadius:BorderRadius.circular(12),
              boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.06),blurRadius:8,offset:const Offset(0,2))],
            ),
            child:IntrinsicHeight(
              child:Row(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  // Green vertical accent line (4px)
                  Container(width:4,decoration:BoxDecoration(color:kMerchantPrimary,borderRadius:const BorderRadius.only(topLeft:Radius.circular(12),bottomLeft:Radius.circular(12)))),
                  // Thumbnail
                  Padding(
                    padding:const EdgeInsets.all(10),
                    child:ClipRRect(borderRadius:BorderRadius.circular(10),child:_thumb),
                  ),
                  // Content area
                  Expanded(child:Padding(
                    padding:const EdgeInsets.fromLTRB(0,10,12,10),
                    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      // Row 1: Store name + status badge
                      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Expanded(child:Text(s["store_name"]??"",style:const TextStyle(fontWeight:FontWeight.bold,fontSize:20,color:kMerchantText),maxLines:1,overflow:TextOverflow.ellipsis)),
                        Container(
                          padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                          decoration:BoxDecoration(color:sc.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),
                          child:Text(sl,style:TextStyle(color:sc,fontSize:10,fontWeight:FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height:4),
                      // Location
                      Text("${s['city']??''}, ${s['area']??''}",style:const TextStyle(color:kMerchantMuted,fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),
                      const SizedBox(height:2),
                      // Category with icon
                      Row(children:[
                        Icon(catIcon,size:14,color:kMerchantMuted),
                        const SizedBox(width:4),
                        Flexible(child:Text(s["category"]??"",style:const TextStyle(color:kMerchantMuted,fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height:6),
                      // Compact deal + subscription badges
                      Row(children:[
                        if ((s["deal_count"] as int? ?? 0) > 0)
                          Container(
                            padding:const EdgeInsets.symmetric(horizontal:7,vertical:2),
                            decoration:BoxDecoration(color:const Color(0xFFFFF0D0),borderRadius:BorderRadius.circular(6),border:Border.all(color:const Color(0xFFE6A817),width:.5)),
                            child:Row(mainAxisSize:MainAxisSize.min,children:[
                              const Icon(Icons.local_offer,size:11,color:Color(0xFFB87A00)),
                              const SizedBox(width:3),
                              Text("${s['deal_count']??0} Deal${((s['deal_count']??0)>1)?'s':''}",style:const TextStyle(color:Color(0xFFB87A00),fontSize:10,fontWeight:FontWeight.w700)),
                            ])),
                        if ((s["deal_count"] as int? ?? 0) > 0 && (s["subscription_end"]??'').isNotEmpty)
                          const SizedBox(width:6),
                        if ((s["subscription_end"]??'').isNotEmpty)
                          Container(
                            padding:const EdgeInsets.symmetric(horizontal:7,vertical:2),
                            decoration:BoxDecoration(
                              color: status=="active" ? OffroColors.mint : const Color(0xFFFFF3CD),
                              borderRadius:BorderRadius.circular(6)),
                            child:Row(mainAxisSize:MainAxisSize.min,children:[
                              Icon(Icons.event_available,size:11,color: status=="active" ? OffroColors.statusLive : OffroColors.statusPending),
                              const SizedBox(width:3),
                              Text("${status=='active'?'Till':'Exp'}: ${(s['subscription_end']?.toString() ?? '').split('T').first}",
                                style:TextStyle(color: status=="active" ? OffroColors.statusLive : OffroColors.statusPending,fontSize:10,fontWeight:FontWeight.w700)),
                            ])),
                      ]),
                      // Divider above buttons
                      const SizedBox(height:8),
                      const Divider(height:1,thickness:.5,color:OffroColors.border),
                      const SizedBox(height:8),
                      // Action buttons — computed above as a plain widget variable
                      _actionButtons,
                    ]),
                  )),
                ],
              ),
            ),
          );
        },
      )),
  );

  void _showQR(BuildContext ctx, String name, String qr) => showDialog(context:ctx, builder:(_)=>AlertDialog(
    title:Text(name,style:const TextStyle(fontSize:15,color:kMerchantPrimary)),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
      qr.startsWith("data:image") ? Image.memory(base64Decode(qr.split(",").last),width:220,height:220) : const Icon(Icons.qr_code,size:100),
      const SizedBox(height:8), const Text("Show this to customers to earn points",textAlign:TextAlign.center,style:TextStyle(color:kMerchantMuted,fontSize:12)),
    ]),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text("Close",style:TextStyle(color:kMerchantPrimary)))],
  ));
}

// ─────────── Add/Edit Store Page ───────────

// ─────────────────────── INDIA STATES & CITIES ───────────────────────
// kIndiaCities/kIndiaStates now live in
// lib/core/constants/india_locations.dart (imported above) so they can be
// shared with the account-level manual State+City entry flow in
// login_screen.dart without a circular import. Values are unchanged.


class AddEditStorePage extends StatefulWidget {
  final String token; final Map? store;
  const AddEditStorePage({super.key, required this.token, this.store});
  @override State<AddEditStorePage> createState() => _AddEditStoreState();
}
class _AddEditStoreState extends State<AddEditStorePage> {
  final _name = TextEditingController();
  final _area = TextEditingController(); final _addr = TextEditingController();
  final _phone= TextEditingController(); final _lat  = TextEditingController();
  final _lng  = TextEditingController();
  String _category = ""; String? _imgB64; String? _img2B64; bool _loading = false; String _msg = "";
  // FIX (blank Edit screen): the store's image can be EITHER a base64 data
  // URI (freshly picked, not yet saved) OR a Cloudinary CDN URL (already
  // saved). Previously both were dumped into _imgB64 and unconditionally
  // passed to base64Decode() — decoding a URL string threw a FormatException
  // during build, which in a release APK renders as a silent blank screen.
  // Keep them in separate fields so the UI renders Image.network for URLs
  // and Image.memory only for genuine base64.
  String? _imgUrl; String? _img2Url;
  List<dynamic> _categories = [];
  // City / State are now editable text fields (same "Location captured"
  // card). _selState/_selCity keep their old String? API so every existing
  // read/write (GPS, Maps resolve, edit-store populate, _save) is unchanged,
  // but they are backed by controllers so a manual edit is exactly what
  // Create Store submits.
  final _cityC = TextEditingController();
  final _stateC = TextEditingController();
  String? get _selCity => _cityC.text.trim().isEmpty ? null : _cityC.text.trim();
  set _selCity(String? v) => _cityC.text = v ?? '';
  String? get _selState => _stateC.text.trim().isEmpty ? null : _stateC.text.trim();
  set _selState(String? v) => _stateC.text = v ?? '';
  bool _locLoading = false; bool _locConfirmed = false;
  bool _locDenied = false; // true after a denial THIS attempt — button stays enabled, tapping again retries
  // Location-specific error, shown directly under the "Current Location"
  // button — kept separate from the form-wide _msg (which only shows after
  // Create Store validation) so a GPS/permission problem never appears at
  // the bottom of the whole form.
  String _locMsg = "";
  // Maps-link resolve error — shown directly under the URL field / Resolve
  // button (NOT in the form-wide _msg at the bottom).
  String _mapsMsg = "";
  final _mapsUrlCtrl = TextEditingController();
  bool _mapsResolving = false;
  bool _mapsApplied = false;
  String _resolvedPlaceName = '';
  String _resolvedAddress = '';
  final _about = TextEditingController();
  String? _openTime;   // e.g. "09:00"
  String? _closeTime;  // e.g. "22:00"

  // 30-min interval time slots for dropdowns
  static List<Map<String,String>> _timeSlots() {
    final slots = <Map<String,String>>[];
    for (int h = 0; h < 24; h++) {
      for (int m = 0; m < 60; m += 30) {
        final val = "${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}";
        final suffix = h >= 12 ? "PM" : "AM";
        final h12    = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        final mStr   = m > 0 ? ":${m.toString().padLeft(2,'0')}" : ":00";
        final label  = "$h12$mStr $suffix";
        slots.add({"value": val, "label": label});
      }
    }
    return slots;
  }

  Future<void> _captureGpsLocation() async {
    setState(() { _locLoading = true; _locConfirmed = false; _locMsg = ""; });
    try {
      // Always retry the permission/location flow on every tap — including
      // after a previous denial. A first denial must not permanently block
      // this button; MyApp.ensureLocationPermission() checks the current
      // platform state and re-requests when it is still "denied" (as
      // opposed to "deniedForever", which the OS itself won't re-prompt
      // for), so tapping again after allowing it via Settings, or after
      // dismissing the OS dialog, can still succeed. This is the SAME
      // permission-request helper used everywhere else in the app
      // (MyApp.ensureLocationPermission → Geolocator.checkPermission() then
      // Geolocator.requestPermission()), so tapping the button when
      // permission isn't granted always triggers the native OS prompt
      // (or, on a platform/state where the OS won't re-show it, surfaces
      // the denial below so the merchant knows to allow it from Settings).
      final hasPermission = await MyApp.ensureLocationPermission();
      if (!hasPermission) {
        if (mounted) setState(() {
          _locLoading = false;
          _locDenied  = true;
          _locMsg = "Location permission is required for current location. "
              "Allow it and try again.";
        });
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() {
          _locLoading = false;
          _locMsg = "Device location is turned off. Turn it on and try again.";
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() {
        _lat.text = pos.latitude.toStringAsFixed(6);
        _lng.text = pos.longitude.toStringAsFixed(6);
        _locConfirmed = true;
        _locLoading   = false;
        _locDenied    = false;
        _locMsg       = "";
      });
      await _reverseGeocode(pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) setState(() {
        _locLoading = false;
        _locMsg = "Could not get location: ${e.toString().replaceAll('Exception: ','')}";
      });
    }
  }

  // ── Reverse geocode: fill state/city/area/address from lat/lng ──
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final res = await Api.reverseGeocode(lat, lng);
      if (!mounted || res.containsKey('error')) return;
      setState(() {
        final st = res['state']?.toString() ?? '';
        final ct = res['city']?.toString() ?? '';
        final ar = res['area']?.toString() ?? '';
        final ad = res['address']?.toString() ?? '';
        // Case-insensitive state match
        final matchedState = st.isNotEmpty
            ? kIndiaStates.firstWhere((s) => s.toLowerCase() == st.toLowerCase(), orElse: () => '')
            : '';
        if (matchedState.isNotEmpty) _selState = matchedState;
        else if (st.isNotEmpty) _selState = st;
        // Case-insensitive city match within the matched state's city list
        if (ct.isNotEmpty) {
          final stateKey = matchedState.isNotEmpty ? matchedState : (_selState ?? '');
          final cities = kIndiaCities[stateKey] ?? [];
          final matchedCity = cities.firstWhere(
              (c) => c.toLowerCase() == ct.toLowerCase(), orElse: () => '');
          _selCity = matchedCity.isNotEmpty ? matchedCity : ct;
        }
        if (ar.isNotEmpty) _area.text = ar;
        if (ad.isNotEmpty) _addr.text = ad;
      });
    } catch (_) {}
  }

  // ── Google Maps link resolution (inline Blinkit-style) ──
  Future<void> _resolveMapsLink(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _mapsResolving = true;
      _mapsApplied = false;
      _mapsMsg = '';
      _resolvedPlaceName = '';
      _resolvedAddress = '';
    });
    final res = await Api.resolveMapsLink(trimmed);
    if (!mounted) return;
    if (res.containsKey('error') || res['lat'] == null || res['lng'] == null) {
      setState(() {
        _mapsResolving = false;
        _resolvedPlaceName = '';
        _resolvedAddress = '';
        // Friendly text only: a server detail / raw URL is never shown.
        final e = res['error']?.toString() ?? '';
        _mapsMsg = (e.isNotEmpty && e.startsWith('Network error'))
            ? e
            : 'Unable to identify the exact location from this Google Maps link. Please open Google Maps, drop a pin on the exact location, tap Share → Copy link, and try again.';
      });
    } else {
      setState(() {
        _mapsResolving = false;
        _resolvedPlaceName = res['place_name']?.toString() ?? '';
        _resolvedAddress   = res['address']?.toString() ?? '';
        _lat.text = res['lat'].toString();
        _lng.text = res['lng'].toString();
        _mapsApplied  = true;
        _mapsMsg = '';
        _locConfirmed = true;
      });
      // Auto-fill address fields from resolved location
      final st = res['state']?.toString() ?? '';
      final ct = res['city']?.toString() ?? '';
      final ar = res['area']?.toString() ?? '';
      final ad = res['address']?.toString() ?? '';
      if (mounted && (st.isNotEmpty || ct.isNotEmpty || ar.isNotEmpty || ad.isNotEmpty)) {
        setState(() {
          // Case-insensitive state match
          final matchedState = st.isNotEmpty
              ? kIndiaStates.firstWhere((s) => s.toLowerCase() == st.toLowerCase(), orElse: () => '')
              : '';
          if (matchedState.isNotEmpty) _selState = matchedState;
          else if (st.isNotEmpty) _selState = st;
          // Case-insensitive city match within the matched state's city list
          if (ct.isNotEmpty) {
            final stateKey = matchedState.isNotEmpty ? matchedState : (_selState ?? '');
            final cities = kIndiaCities[stateKey] ?? [];
            final matchedCity = cities.firstWhere(
                (c) => c.toLowerCase() == ct.toLowerCase(), orElse: () => '');
            _selCity = matchedCity.isNotEmpty ? matchedCity : ct;
          }
          if (ar.isNotEmpty) _area.text = ar;
          if (ad.isNotEmpty) _addr.text = ad;
        });
      }
      // Safety net: coordinates resolved but city/state still empty →
      // fill them through the same reverse-geocode used for GPS.
      if (mounted && (_selCity == null || _selState == null)) {
        final la = double.tryParse(res['lat'].toString());
        final ln = double.tryParse(res['lng'].toString());
        if (la != null && ln != null) await _reverseGeocode(la, ln);
      }
    }
  }

  Widget _locTile(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label.toUpperCase(),
          style: OffroText.caption.copyWith(fontSize: 8.5, letterSpacing: .8, color: OffroColors.secondarySolid)),
      const SizedBox(height: 2),
      Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: OffroText.value.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  /// Editable variant of [_locTile] — same look, but a text field so the
  /// merchant can correct the captured value. Whatever is typed is what
  /// Create Store submits.
  Widget _locEdit(String label, TextEditingController c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label.toUpperCase(),
          style: OffroText.caption.copyWith(fontSize: 8.5, letterSpacing: .8, color: OffroColors.secondarySolid)),
      const SizedBox(height: 2),
      TextField(
        controller: c,
        maxLines: 1,
        onChanged: (_) => setState(() {}),
        style: OffroText.value.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          isDense: true, border: InputBorder.none,
          contentPadding: EdgeInsets.zero, hintText: '—'),
      ),
    ]),
  );

  /// Compact result card shown once a location exists (GPS, resolved Maps
  /// link, or an already-saved store). Display only: it reads the same
  /// state/city/area/address values the form already holds; lat/lng stay in
  /// their controllers and are saved exactly as before.
  Widget _capturedLocationCard() {
    final addr = _addr.text.trim().isNotEmpty
        ? _addr.text.trim()
        : (_resolvedAddress.trim().isNotEmpty ? _resolvedAddress.trim() : _resolvedPlaceName.trim());
    final pin = RegExp(r'\b\d{6}\b').firstMatch(addr)?.group(0) ?? '';
    final tiles = <Widget>[
      _locEdit('City', _cityC),
      _locEdit('State', _stateC),
      _locEdit('Area', _area),
      if (pin.isNotEmpty) _locTile('Postal code', pin),
    ];
    final rows = <Widget>[];
    for (var k = 0; k < tiles.length; k += 2) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: k == 0 ? 0 : 6),
        child: Row(children: [
          Expanded(child: tiles[k]),
          const SizedBox(width: 6),
          Expanded(child: k + 1 < tiles.length ? tiles[k + 1] : const SizedBox.shrink()),
        ]),
      ));
    }
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: OffroColors.mint, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const OffroIcon(OffroIcons.check, size: 13, color: OffroColors.primary),
          const SizedBox(width: 6),
          Text("Location captured",
              style: OffroText.caption.copyWith(color: OffroColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        ...rows,
        if (addr.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(addr, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: OffroText.caption.copyWith(fontSize: 10, color: OffroColors.secondarySolid, height: 1.35)),
        ],
      ]),
    );
  }

  bool get _isEdit => widget.store != null;

  @override void initState() {
    super.initState();
    _loadCategories();
    if (_isEdit) {
      _populateFromStore(widget.store!);
      // Also fetch the full store detail to get image2 + state/city (list API may omit them)
      _fetchFullStoreDetail();
    }
  }

  // Safe string coercion — backend fields occasionally come back as numbers
  // (e.g. lat/lng saved as double for legacy/admin-created stores) instead of
  // strings. Assigning a non-String directly to TextEditingController.text
  // throws a type error mid-setState, which in a release APK renders as a
  // blank screen with no visible crash log. Always coerce via toString().
  static String _sv(dynamic v) => v == null ? "" : v.toString();

  void _populateFromStore(Map s) {
    _name.text  = _sv(s["store_name"]);
    final rawState = _sv(s["state"]).trim();
    final rawCity  = _sv(s["city"]).trim();
    // Case-insensitive match against kIndiaStates so dropdown shows the saved value
    if (rawState.isNotEmpty) {
      final matched = kIndiaStates.firstWhere(
        (st) => st.toLowerCase() == rawState.toLowerCase(),
        orElse: () => rawState,
      );
      _selState = matched;
    } else {
      _selState = null;
    }
    // Case-insensitive match against city list for the matched state
    if (rawCity.isNotEmpty) {
      final stateKey = _selState ?? '';
      final cities = kIndiaCities[stateKey] ?? [];
      final matchedCity = cities.firstWhere(
        (c) => c.toLowerCase() == rawCity.toLowerCase(),
        orElse: () => rawCity,
      );
      _selCity = matchedCity;
    } else {
      _selCity = null;
    }
    _area.text  = _sv(s["area"]);       _addr.text = _sv(s["address"]);
    _phone.text = _sv(s["phone"]);      _lat.text  = _sv(s["lat"]);
    _lng.text   = _sv(s["lng"]);        _category  = _sv(s["category"]);
    // FIX: route to the correct field based on actual content — never let a
    // Cloudinary URL end up in the base64 variable (see _imgUrl comment above).
    final rawImg  = _sv(s["image"]);
    final rawImg2 = _sv(s["image2"]);
    if (rawImg.startsWith("data:")) { _imgB64 = rawImg; _imgUrl = null; }
    else if (rawImg.isNotEmpty)      { _imgUrl = rawImg; _imgB64 = null; }
    if (rawImg2.startsWith("data:")) { _img2B64 = rawImg2; _img2Url = null; }
    else if (rawImg2.isNotEmpty)     { _img2Url = rawImg2; _img2B64 = null; }
    _about.text = _sv(s["about"]);
    final rawOpen  = s["open_time"] == null ? null : _sv(s["open_time"]);
    final rawClose = s["close_time"] == null ? null : _sv(s["close_time"]);
    _openTime  = rawOpen!=null  ? rawOpen.split(":").take(2).join(":") : null;
    _closeTime = rawClose!=null ? rawClose.split(":").take(2).join(":") : null;
  }

  Future<void> _fetchFullStoreDetail() async {
    try {
      final storeId = widget.store!["_id"]?.toString() ?? "";
      if (storeId.isEmpty) return;
      final detail = await Api.getMerchantStoreDetail(widget.token, storeId);
      if (mounted && detail != null) {
        setState(() => _populateFromStore(detail));
      }
    } catch (_) {}
  }
  @override void dispose() { _name.dispose();_area.dispose();_addr.dispose();_phone.dispose();_lat.dispose();_lng.dispose();_about.dispose();_mapsUrlCtrl.dispose();_cityC.dispose();_stateC.dispose(); super.dispose(); }

  Future<void> _loadCategories() async { _categories = await Api.fetchCategories(token: widget.token); if (mounted) setState((){}); }


  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Image too large. Max 2MB allowed."), backgroundColor: Colors.red));
      return;
    }
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Image too large. Max 2MB allowed."), backgroundColor: Colors.red));
      return;
    }
    setState(() { _imgB64 = "data:image/jpeg;base64,${base64Encode(bytes)}"; _imgUrl = null; });
  }


  Future<void> _pickImage2() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    setState(() { _img2B64 = "data:image/jpeg;base64,${base64Encode(bytes)}"; _img2Url = null; });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) { setState(()=>_msg="Store name required"); return; }
    if (_selState == null || _selState!.trim().isEmpty) { setState(()=>_msg='Please set the store location using "Use current location" or a Google Maps link'); return; }
    if (_selCity == null || _selCity!.trim().isEmpty) { setState(()=>_msg='Please set the store location using "Use current location" or a Google Maps link'); return; }
    final _phoneVal = _phone.text.trim();
    if (_phoneVal.isEmpty) { setState(()=>_msg="Mobile number is required"); return; }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phoneVal)) { setState(()=>_msg="Enter a valid 10-digit mobile number (starts with 6–9)"); return; }

    // COORDINATES ARE MANDATORY — a store cannot be created with only
    // State + City. "Use Current Location" and the Google Maps link
    // resolver both already populate _lat/_lng with valid values; this is
    // the save-time gate that enforces it (mirrored server-side as
    // defense-in-depth in routers/merchant_app.py).
    final latVal = double.tryParse(_lat.text.trim());
    final lngVal = double.tryParse(_lng.text.trim());
    final hasValidCoords = latVal != null && lngVal != null &&
        latVal >= -90 && latVal <= 90 && lngVal >= -180 && lngVal <= 180;
    if (!_isEdit && !hasValidCoords) {
      setState(() => _msg = 'Please set the store\'s location using "Use Current Location" '
          'or a Google Maps link before creating the store.');
      return;
    }
    if (_isEdit && (_lat.text.trim().isNotEmpty || _lng.text.trim().isNotEmpty) && !hasValidCoords) {
      // Only blocks a location left in a broken/partial state THIS session
      // — an older store's untouched (possibly empty) coordinates are left
      // alone here and are not force-fixed on an unrelated edit.
      setState(() => _msg = 'The store location looks incomplete. Use "Use Current Location" '
          'or a Google Maps link to set a valid location.');
      return;
    }
    setState(()=>_loading=true); _msg="";
    final data = {
      "store_name":_name.text.trim(),"category":_category,
      "state":_selState??"","city":_selCity??"","area":_area.text.trim(),
      "address":_addr.text.trim(),"phone":_phone.text.trim(),
      "lat":_lat.text.trim(),"lng":_lng.text.trim(),
      "about":_about.text.trim(),
      if(_openTime!=null)"open_time":_openTime!,
      if(_closeTime!=null)"close_time":_closeTime!,
      if(_imgB64!=null)"image":_imgB64,
      if(_img2B64!=null)"image2":_img2B64,
    };
    try {
      if (_isEdit) await Api.updateMerchantStore(widget.token, widget.store!["_id"], data);
      else         await Api.createMerchantStore(widget.token, data);
      if (!mounted) return;
      Navigator.pop(context);
    } catch(e) { setState(()=>_msg=friendlyError(e)); }
    if (mounted) setState(()=>_loading=false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kMerchantBg,
    appBar: AppBar(
        title:Text(_isEdit?"Edit Store":"Add Store"),
         
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kMerchantPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    body: SingleChildScrollView(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      _field(_name,"Store Name *",Icons.store),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(value:_category.isEmpty?null:_category,
        items:[..._categories.map((e){final c=(e is Map?e['name']:e).toString();return DropdownMenuItem<String>(value:c,child:Text(c));})],
        onChanged:(v)=>setState(()=>_category=v??''),
        decoration:_dec("Category",Icons.category),
        hint:const Text("Select category")),
      const SizedBox(height:12),
      // GPS location capture
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: kMerchantBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: OffroColors.mint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const OffroIcon(OffroIcons.pin, size: 16, color: OffroColors.primary, filled: true),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Store location", style: OffroText.value.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
              Text("Use GPS or paste a Maps link.", style: OffroText.caption.copyWith(color: OffroColors.secondarySolid)),
            ])),
          ]),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            // The button stays enabled even after a denial — tapping it
            // again retries the permission/location flow (see
            // _captureGpsLocation) instead of permanently blocking it. The
            // label stays permanently "Current Location" — it never
            // switches to a "permission denied" variant; a denial is
            // surfaced only in the small message below the button.
            onPressed: _locLoading ? null : _captureGpsLocation,
            icon: _locLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: OffroColors.primary))
                : const Icon(Icons.gps_fixed, size: 18),
            label: const Text("Use current location"),
            style: ElevatedButton.styleFrom(elevation: 0,
              backgroundColor: OffroColors.mint, foregroundColor: OffroColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: const StadiumBorder(),
            ),
          ),
          if (_locMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_locMsg, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          // ── Blinkit-style Google Maps inline input ──────────────────
          const Text("or paste Google Maps link",
              style: TextStyle(color: kMerchantMuted, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _mapsApplied
                    ? OffroColors.statusLive
                    : _mapsMsg.isNotEmpty
                        ? const Color(0xFFc0392b)
                        : kMerchantBorder,
              ),
            ),
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _mapsResolving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kMerchantPrimary))
                    : Image.asset('assets/images/google_maps_pin.png',
                        width: 22, height: 22,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.place, color: Color(0xFF4285F4), size: 22)),
              ),
              Expanded(
                child: TextField(
                  controller: _mapsUrlCtrl,
                  style: const TextStyle(fontSize: 13, color: kMerchantText),
                  decoration: const InputDecoration(
                    hintText: 'Paste Google Maps link here',
                    hintStyle: TextStyle(fontSize: 12, color: kMerchantMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (v) => _resolveMapsLink(v),
                  onChanged: (v) {
                    if (_mapsApplied || _mapsMsg.isNotEmpty) setState(() { _mapsApplied = false; _mapsMsg = ''; _resolvedPlaceName = ''; _resolvedAddress = ''; });
                  },
                ),
              ),
              if (_mapsUrlCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _mapsUrlCtrl.clear();
                    _mapsApplied = false;
                    _mapsMsg = '';
                    _resolvedPlaceName = '';
                    _resolvedAddress = '';
                  }),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.close_rounded, size: 18, color: kMerchantMuted),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          // Resolve button
          if (!_mapsApplied)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _mapsResolving ? null : () => _resolveMapsLink(_mapsUrlCtrl.text),
                style: ElevatedButton.styleFrom(elevation: 0, 
                  backgroundColor: kMerchantPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: const StadiumBorder(),
                ),
                child: _mapsResolving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Resolve Location", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          // Resolve error — directly under the URL field / Resolve button.
          if (_mapsMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_mapsMsg, style: const TextStyle(color: Color(0xFFc0392b), fontSize: 12)),
          ],
          // ── Compact captured-location card (GPS, Maps link, or saved store) ──
          if (_locConfirmed || (_lat.text.trim().isNotEmpty && _lng.text.trim().isNotEmpty)) _capturedLocationCard(),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(_lat, "Latitude", Icons.gps_fixed, type: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _field(_lng, "Longitude", Icons.gps_not_fixed, type: TextInputType.number)),
          ]),
          const SizedBox(height: 4),
          const Text("Auto-filled by GPS or Google Maps — you can edit any value. Edited values are saved as entered.",
              style: TextStyle(color: kMerchantMuted, fontSize: 11)),
        ]),
      ),
      const SizedBox(height:12),
      _field(_phone,"Phone",Icons.phone,type:TextInputType.phone,maxLen:10),
      const SizedBox(height: 16),
      // Image picker
      GestureDetector(onTap:_pickImage,child:Container(height:150,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder,style:BorderStyle.solid)),
        child: _imgB64!=null
            ? ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(_imgB64!.split(",").last),fit:BoxFit.cover,width:double.infinity))
            : (_imgUrl!=null && _imgUrl!.isNotEmpty)
                ? ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network(_imgUrl!,fit:BoxFit.cover,width:double.infinity,
                    errorBuilder:(_,__,___)=>Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.broken_image_outlined,color:kMerchantMuted,size:36),const SizedBox(height:8),const Text("Tap to change image",style:TextStyle(color:kMerchantMuted,fontSize:13,fontWeight:FontWeight.w600))])))
                : Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.add_a_photo,color:kMerchantMuted,size:36),const SizedBox(height:8),const Text("Main Store Image",style:TextStyle(color:kMerchantMuted,fontSize:13,fontWeight:FontWeight.w600)),const SizedBox(height:4),Row(mainAxisAlignment:MainAxisAlignment.center,children:[_InfoChip("📐 800×600px (4:3)"),const SizedBox(width:6),_InfoChip("📦 Max 2MB")])]))),
      const SizedBox(height:12),
      // Second image picker — optional logo
      const Text("Upload Logo [Optional]",style:TextStyle(color:kMerchantMuted,fontSize:12,fontWeight:FontWeight.w600)),
      const SizedBox(height:6),
      GestureDetector(onTap:_pickImage2,child:Container(height:110,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder,style:BorderStyle.solid)),
        child: _img2B64!=null
            ? Stack(children:[
                ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(_img2B64!.split(",").last),fit:BoxFit.cover,width:double.infinity,height:110)),
                Positioned(top:6,right:6,child:GestureDetector(
                  onTap:(){setState(()=>_img2B64=null);},
                  child:Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:Colors.black54,shape:BoxShape.circle),child:const Icon(Icons.close,color:Colors.white,size:14)))),
              ])
            : (_img2Url!=null && _img2Url!.isNotEmpty)
                ? Stack(children:[
                    ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.network(_img2Url!,fit:BoxFit.cover,width:double.infinity,height:110,
                      errorBuilder:(_,__,___)=>Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.broken_image_outlined,color:kMerchantMuted,size:32),const SizedBox(height:6),const Text("Tap to change logo",style:TextStyle(color:kMerchantMuted,fontSize:12))]))),
                    Positioned(top:6,right:6,child:GestureDetector(
                      onTap:(){setState(()=>_img2Url=null);},
                      child:Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:Colors.black54,shape:BoxShape.circle),child:const Icon(Icons.close,color:Colors.white,size:14)))),
                  ])
                : Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.image_outlined,color:kMerchantMuted,size:32),const SizedBox(height:6),const Text("Tap to upload logo",style:TextStyle(color:kMerchantMuted,fontSize:12)),const SizedBox(height:4),Row(mainAxisAlignment:MainAxisAlignment.center,children:[_InfoChip("📐 200×200px (1:1)"),const SizedBox(width:6),_InfoChip("📦 Max 2MB")])]))),
      const SizedBox(height:12),
      // ── Opening & Closing Time ──────────────────────────────────────
      const SizedBox(height:12),
      const Text("Store Timings [Optional]",
        style: TextStyle(color: kMerchantMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _openTime,
            isExpanded: true,
            items: _timeSlots().map((t) => DropdownMenuItem<String>(
              value: t["value"],
              child: Text(t["label"]!, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _openTime = v),
            decoration: _dec("Opening Time", Icons.access_time_rounded),
            hint: const Text("Open at", style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _closeTime,
            isExpanded: true,
            items: _timeSlots().map((t) => DropdownMenuItem<String>(
              value: t["value"],
              child: Text(t["label"]!, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _closeTime = v),
            decoration: _dec("Closing Time", Icons.access_time_filled_rounded),
            hint: const Text("Close at", style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ),
      ]),
      const SizedBox(height:16),
      // About field
      TextField(controller:_about, maxLines:4, keyboardType:TextInputType.multiline,
        decoration:_dec("About this store (description shown to customers)",Icons.info_outline).copyWith(
          alignLabelWithHint:true)),
      const SizedBox(height:20),
      SizedBox(height:50,child:ElevatedButton(
        onPressed:_loading?null:_save,
        style:ElevatedButton.styleFrom(elevation: 0, backgroundColor:kMerchantPrimary,shape: const StadiumBorder()),
        child:_loading?const SizedBox(width:20,height:20,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):
            Text(_isEdit?"Save Changes":"Create Store",style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w700)))),
      if (_msg.isNotEmpty)...[const SizedBox(height:10),Text(_msg,textAlign:TextAlign.center,style:TextStyle(color:Colors.red.shade700,fontSize:13))],
      const SizedBox(height:24),
    ])),
  );

  Widget _field(TextEditingController c,String hint,IconData icon,{TextInputType type=TextInputType.text,int? maxLen}) =>
    TextField(controller:c,keyboardType:type,maxLength:maxLen,decoration:_dec(hint,icon).copyWith(counterText:maxLen!=null?"":null));
  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
    hintText:hint,
    prefixIcon:Icon(icon,color:kMerchantMuted,size:20),
    filled:true,
    fillColor:Colors.white,
    contentPadding:const EdgeInsets.symmetric(vertical:14,horizontal:14),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantBorder)),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:const BorderSide(color:kMerchantPrimary,width:2)));
}

// ─────────── Subscribe Page ───────────
class SubscribePage extends StatefulWidget {
  final String token; final Map store;
  const SubscribePage({super.key,required this.token,required this.store});
  @override State<SubscribePage> createState() => _SubscribeState();
}
class _SubscribeState extends State<SubscribePage> {
  Map<String,dynamic> _pendingOrder = {};
  List _plans = []; bool _loading = true; String _selectedPlan = ""; String _fromDate = "";
  Map? _selectedPlanData; String _msg = "";
  final TextEditingController _discC = TextEditingController();
  String? _appliedCode; double _discountValue = 0; String? _discountType; bool _validatingDisc = false; String _discMsg = "";

  // Delegates to the shared previewDiscountAmount() helper (top of file) —
  // same formula used by Add Banner and Add Product's discount previews.
  double _previewDiscountAmount(double basePrice) =>
      _appliedCode == null ? 0 : previewDiscountAmount(basePrice, _discountType, _discountValue);

  // Razorpay instance must live for the lifetime of this page so its native
  // callbacks (success/error/external_wallet) are not garbage-collected while
  // the Razorpay native checkout activity is on top. Creating it inside a
  // local function caused the app to silently return after "Pay Now" on
  // newer Android versions.
  late final Razorpay _razorpay;

  @override void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExtWallet);
    _loadPlans();
    _fromDate = DateTime.now().toIso8601String().substring(0,10);
  }

  @override void dispose() {
    _razorpay.clear();
    _discC.dispose();
    super.dispose();
  }

  Future<void> _openRazorpay(Map<String,dynamic> order) async {
    try {
      // FIX: use the backend-returned key (authoritative — matches whatever
      // mode/environment the backend's RAZORPAY_KEY_ID is actually configured
      // for) instead of the hardcoded kRazorpayKey constant. Mirrors the same
      // pattern already used correctly in _openRazorpayBanner above.
      final rzpKey = order["razorpay_key"]?.toString() ?? '';
      if (rzpKey.isEmpty) {
        setState(() => _msg = "Payment gateway not configured. Contact support.");
        return;
      }
      final amountPaise = (order["amount"] as num?)?.toInt() ??
          ((double.tryParse(order["amount_display"]?.toString() ?? "0") ?? 0) * 100).round();
      final opts = {
        'key': rzpKey,
        'amount': amountPaise,
        'currency': 'INR',
        'order_id': order["razorpay_order_id"] ?? order["order_id"] ?? "",
        'name': 'Offro',
        'description': order["plan_label"] ?? 'Store Subscription',
        'prefill': {
          'contact': order["merchant_phone"] ?? "",
        },
        'image': '$kBaseUrl/static/offro_logo.png',
        'theme': {'color': '#3E5F55'},
      };
      _razorpay.open(opts);
    } catch(e) {
      debugPrint('[MerchantSubscription] Razorpay open error: $e');
      if (mounted) setState(() => _msg = friendlyError(e, fallback: "Could not open payment. Please try again."));
    }
  }

  Future<void> _onPaySuccess(PaymentSuccessResponse resp) async {
    if (!mounted) return;
    final payId = resp.paymentId ?? "";
    final ordId = resp.orderId ?? _pendingOrder["razorpay_order_id"] ?? "";
    final sig   = resp.signature ?? "";
    // Show "Confirming payment" dialog immediately so user sees action right away
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: Card(
        color: Colors.white,
        child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: kMerchantPrimary),
          SizedBox(height: 16),
          Text("Confirming payment...", style: TextStyle(fontWeight: FontWeight.w600, color: kMerchantText)),
          SizedBox(height: 4),
          Text("Please wait a moment", style: TextStyle(color: kMerchantMuted, fontSize: 12)),
        ])),
      )),
    );
    // Verify payment synchronously (with retries)
    String invoiceNo = payId;
    try {
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final result = await Api.verifyPayment(widget.token, {
            "razorpay_payment_id": payId,
            "razorpay_order_id":   ordId,
            "razorpay_signature":  sig,
            "store_id": widget.store["_id"],
          });
          invoiceNo = result["invoice_no"]?.toString() ?? payId;
          break;
        } catch(e) {
          if (attempt < 2) await Future.delayed(Duration(seconds: attempt + 1));
        }
      }
    } catch (_) {}
    if (!mounted) return;
    // Dismiss the confirming dialog
    Navigator.of(context).pop();
    // Navigate immediately to success screen
    // push (not pushReplacement) keeps MerchantHome in stack
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => PaymentSuccessScreen(
      storeName: widget.store["store_name"]?.toString() ?? "",
      invoiceNo: invoiceNo,
      onDone: () {
        Navigator.of(ctx).popUntil((route) => route.isFirst);
      },
    )));
  }

  void _onPayError(PaymentFailureResponse resp) {
    if (mounted) setState(() { final m = friendlyRazorpayError(resp.message); _msg = "Payment cancelled or failed: $m"; });
  }

  void _onExtWallet(ExternalWalletResponse resp) {
    if (mounted) setState(() { final w = resp.walletName ?? ""; _msg = "External wallet: $w"; });
  }

    Future<void> _validateDiscount() async {
    final code = _discC.text.trim();
    if (code.isEmpty) return;
    setState(()=>_validatingDisc=true);
    try {
      // scope: "STORE" lets the backend catch a wrong-scope code (e.g. a
      // BANNERS-only code entered here) right now, so the error shows next
      // to the input instead of only surfacing later when Proceed to Pay
      // calls /subscribe (which enforces scope unconditionally regardless).
      final r = await Api.validateDiscount(code, scope: "STORE");
      final val = (r["value"] as num).toDouble();
      final type = (r["type"]?.toString() ?? "VALUE").toUpperCase();
      setState((){
        _appliedCode = r["code"];
        _discountType = type;
        _discountValue = val;
        _discMsg = type == "PERCENTAGE"
            ? "✅ ${val.toStringAsFixed(0)}% discount applied!"
            : "✅ ₹${val.toStringAsFixed(0)} discount applied!";
      });
    } catch(e) {
      setState((){
        _appliedCode = null; _discountValue = 0; _discountType = null;
        _discMsg = friendlyError(e);
      });
    }
    if (mounted) setState(()=>_validatingDisc=false);
  }

  Future<void> _loadPlans() async {
    _plans = await Api.getPlans(widget.token);
    if (_plans.isNotEmpty) { _selectedPlan = _plans[0]["id"]; _selectedPlanData = Map.from(_plans[0]); }
    if (mounted) setState(()=>_loading=false);
  }

  Future<void> _subscribe() async {
    if (_selectedPlan.isEmpty) return;
    setState(()=>_loading=true); _msg="";
    try {
      final order = await Api.initiateSubscription(widget.token, {
        "store_id":     widget.store["_id"],
        "plan":         _selectedPlan,
        "from_date":    _fromDate,
        if (_appliedCode != null) "discount_code": _appliedCode,
      });
      if (!mounted) return;
      final payMode = order["pay_mode"] ?? "manual";
      // If amount is 0, always treat as manual (free plan / promo)
      final orderAmt = (order["amount"] as num?)?.toInt() ??
          ((double.tryParse(order["amount_display"]?.toString() ?? "0") ?? 0) * 100).round();

      // ── Manual / offline payment mode ──
      if (payMode == "manual" || orderAmt <= 0) {
        final discAmt = (order["discount_amount"] as num?)?.toDouble() ?? 0;
        final discType = order["discount_type"]?.toString();
        showDialog(context:context,barrierDismissible:false,builder:(ctx)=>AlertDialog(
          title:const Text("Subscription Request Sent",style:TextStyle(color:kMerchantPrimary,fontWeight:FontWeight.bold)),
          content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            _row("Store", widget.store["store_name"]??''),
            _row("Plan",  order["plan_label"]??''),
            _row("From",  order["from_date"]??''),
            _row("To",    order["end_date"]??''),
            const Divider(),
            _row("Base Price","₹${order['base_price']}"),
            if (discAmt>0)
              _row("Discount", discType=="PERCENTAGE"
                  ? "-₹${discAmt.toStringAsFixed(2)} (${(order['discount_value'] as num?)?.toStringAsFixed(0) ?? ''}%)"
                  : "-₹${discAmt.toStringAsFixed(2)}"),
            _row("GST (${order['gst_percent']}%)","₹${order['gst_amount']}"),
            _row("Total Payable","₹${order['amount_display']}",bold:true),
            const SizedBox(height:12),
            Container(
              padding:const EdgeInsets.all(10),
              decoration:BoxDecoration(color:kMerchantLight.withValues(alpha: .4),borderRadius:BorderRadius.circular(8)),
              child:Text(
                // ₹0 payable (100% discount): no payment instruction.
                orderAmt <= 0
                    ? "✅  Your subscription request has been submitted."
                    : "✅  Your subscription request has been submitted.\n\nPlease pay the amount to your Offro representative.\nThe admin will activate your store once payment is confirmed.",
                style:const TextStyle(fontSize:12,color:kMerchantPrimary,height:1.5),
              ),
            ),
          ]),
          actions:[
            ElevatedButton(
              style:ElevatedButton.styleFrom(elevation: 0, backgroundColor:kMerchantPrimary,shape: const StadiumBorder()),
              onPressed:() async {
                Navigator.pop(ctx);
                // If amount is 0, activate immediately via free endpoint
                if (orderAmt <= 0) {
                  try {
                    await Api.activateFreeSubscription(widget.token, {
                      "store_id":       widget.store["_id"]?.toString() ?? "",
                      "subscription_id": order["subscription_id"]?.toString() ?? "",
                    });
                  } catch(_) {}
                }
                if (context.mounted) Navigator.pop(context);
              },
              child:const Text("OK",style:TextStyle(color:Colors.white))),
          ],
        ));
        return;
      }

      // ── Razorpay online mode ──
      setState(() => _pendingOrder = Map<String,dynamic>.from(order));
      final planLbl = order["plan_label"]?.toString() ?? _selectedPlan;
      // Use num conversion to avoid toString() showing "0" on valid values
      final baseP   = (order["base_price"] as num?)?.toStringAsFixed(2) ?? _selectedPlanData?["price"]?.toString() ?? "0";
      final gstPct  = (order["gst_percent"] as num?)?.toString() ?? "18";
      final gstAmt  = (order["gst_amount"] as num?)?.toStringAsFixed(2) ?? "0";
      final totalD  = (order["amount_display"] as num?)?.toStringAsFixed(2) ?? (order["total"] as num?)?.toStringAsFixed(2) ?? "0";
      final fromD   = order["from_date"]?.toString() ?? "";
      final toD     = order["end_date"]?.toString() ?? "";
      showDialog(context:context,builder:(_)=>AlertDialog(
        title:const Text("Confirm Payment",style:TextStyle(color:kMerchantPrimary,fontWeight:FontWeight.bold)),
        content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          _row("Store", widget.store["store_name"]?.toString()??''),
          _row("Plan",  planLbl),
          _row("From",  fromD),
          _row("To",    toD),
          const Divider(),
          _row("Base Price","₹$baseP"),
          _row("GST ($gstPct%)","₹$gstAmt"),
          _row("Total","₹$totalD",bold:true),
          const SizedBox(height:12),
          Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:kMerchantLight.withValues(alpha: .4),borderRadius:BorderRadius.circular(8)),
            child:const Text("Razorpay checkout will open. After payment, admin will approve your store.",style:TextStyle(fontSize:12,color:kMerchantPrimary))),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context),child:const Text("Cancel",style:TextStyle(color:kMerchantMuted))),
          ElevatedButton(
            style:ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor:kMerchantPrimary),
            onPressed:() {
              Navigator.pop(context);
              _openRazorpay(_pendingOrder);
            },
            child:const Text("Pay Now",style:TextStyle(color:Colors.white))),
        ],
      ));
    } catch(e) {
      if (mounted) setState(()=>_msg=friendlyError(e));
    }
    if (mounted) setState(()=>_loading=false);
  }

  Widget _row(String k,String v,{bool bold=false}) => Padding(padding:const EdgeInsets.symmetric(vertical:3),
    child:Row(children:[Expanded(child:Text(k,style:const TextStyle(color:kMerchantMuted,fontSize:13))),Text(v,style:TextStyle(fontSize:13,fontWeight:bold?FontWeight.bold:FontWeight.w500,color:bold?kMerchantPrimary:kMerchantText))]));

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kMerchantBg,
    appBar:AppBar(title:const Text("Subscribe Store"), ),
    body:_loading?const Center(child:CircularProgressIndicator(color:kMerchantPrimary)):SingleChildScrollView(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Store",style:TextStyle(color:kMerchantMuted,fontSize:11,fontWeight:FontWeight.w600)),
          Text(widget.store["store_name"]??"",style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:kMerchantText)),
          Text("${widget.store['city']??''}, ${widget.store['area']??''}",style:const TextStyle(color:kMerchantMuted,fontSize:12)),
        ])),
      const SizedBox(height:20),
      const Text("Select Plan",style:TextStyle(fontWeight:FontWeight.bold,color:kMerchantText,fontSize:15)),
      const SizedBox(height:10),
      ..._plans.map((p){
        final sel = _selectedPlan==p["id"];
        return GestureDetector(onTap:()=>setState((){_selectedPlan=p["id"];_selectedPlanData=Map.from(p);}),
          child:Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(color:sel?kMerchantPrimary:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:sel?kMerchantPrimary:kMerchantBorder,width:sel?2:1)),
            child:Row(children:[
              Icon(sel?Icons.radio_button_checked:Icons.radio_button_unchecked,color:sel?Colors.white:kMerchantMuted),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(p["label"],style:TextStyle(fontWeight:FontWeight.bold,color:sel?Colors.white:kMerchantText)),
                Text("₹${p['price']} + ${p['gst_percent']}% GST",style:TextStyle(fontSize:12,color:sel?kMerchantLight:kMerchantMuted)),
              ])),
              Text("₹${p['total']}",style:TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:sel?Colors.white:kMerchantPrimary)),
            ])));
      }).toList(),
      const SizedBox(height:16),
      const Text("Start Date",style:TextStyle(fontWeight:FontWeight.bold,color:kMerchantText,fontSize:15)),
      const SizedBox(height:8),
      GestureDetector(
        onTap:() async {
          final d = await showDatePicker(context:context,initialDate:DateTime.now(),firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:60)),
            builder:(ctx,child)=>Theme(data:ThemeData(colorScheme:const ColorScheme.light(primary:kMerchantPrimary)),child:child!));
          if (d!=null) setState(()=>_fromDate=d.toIso8601String().substring(0,10));
        },
        child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder)),
          child:Row(children:[const Icon(Icons.calendar_today,color:kMerchantPrimary,size:18),const SizedBox(width:10),Text(_fromDate,style:const TextStyle(color:kMerchantText,fontWeight:FontWeight.w600))]))),
      if (_selectedPlanData!=null)...[
        const SizedBox(height:16),
        Builder(builder:(_) {
          final basePrice = (_selectedPlanData!['price'] as num?)?.toDouble() ?? 0;
          final gstPct    = (_selectedPlanData!['gst_percent'] as num?)?.toDouble() ?? 0;
          final discAmt   = _previewDiscountAmount(basePrice);
          final taxable   = (basePrice - discAmt).clamp(0, basePrice);
          final gstAmt    = taxable * gstPct / 100.0;
          final total     = taxable + gstAmt;
          return Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:kMerchantLight.withValues(alpha: .5),borderRadius:BorderRadius.circular(12)),
            child:Column(children:[
              _row("Base Price","₹${basePrice.toStringAsFixed(2)}"),
              if (discAmt>0) _row("Discount","-₹${discAmt.toStringAsFixed(2)}"),
              _row("GST (${gstPct.toStringAsFixed(0)}%)","₹${gstAmt.toStringAsFixed(2)}"),
              const Divider(height:16),
              _row("Total Payable","₹${total.toStringAsFixed(2)}",bold:true),
            ]));
        }),
      ],
      const SizedBox(height:16),
      // ── Discount Code ──
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Have a discount code?",style:TextStyle(fontWeight:FontWeight.w600,color:kMerchantText,fontSize:13)),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:TextField(
              controller:_discC,
              textCapitalization:TextCapitalization.characters,
              onChanged:(_){ if(_appliedCode!=null) setState((){_appliedCode=null;_discountValue=0;_discountType=null;_discMsg="";}); },
              decoration:InputDecoration(hintText:"Enter code",isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:10),border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide(color:kMerchantBorder))),
            )),
            const SizedBox(width:8),
            ElevatedButton(
              onPressed:_validatingDisc?null:_validateDiscount,
              style:ElevatedButton.styleFrom(elevation: 0, backgroundColor:kMerchantPrimary,shape: const StadiumBorder(),padding:const EdgeInsets.symmetric(horizontal:14,vertical:10)),
              child:_validatingDisc?const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):const Text("Apply",style:TextStyle(color:Colors.white,fontSize:13))),
          ]),
          if (_discMsg.isNotEmpty)...[const SizedBox(height:6),Text(_discMsg,style:TextStyle(fontSize:12,color:_appliedCode!=null?OffroColors.statusLive:Colors.red.shade700))],
          if (_appliedCode!=null && _discountType!=null)...[
            const SizedBox(height:6),
            Row(children:[
              const Text("Discount: ",style:TextStyle(fontSize:12,color:kMerchantMuted)),
              Text(_discountType=="PERCENTAGE" ? "- ${_discountValue.toStringAsFixed(0)}%" : "- ₹${_discountValue.toStringAsFixed(0)}",
                style:const TextStyle(fontSize:12,color:OffroColors.statusLive,fontWeight:FontWeight.bold)),
              const Spacer(),
              GestureDetector(onTap:(){setState((){_appliedCode=null;_discountValue=0;_discountType=null;_discMsg="";_discC.clear();});},child:const Text("Remove",style:TextStyle(fontSize:11,color:Colors.red,decoration:TextDecoration.underline)))]),
          ],
        ])),
      const SizedBox(height:24),
      SizedBox(height:52,child:ElevatedButton(
        onPressed:_loading?null:_subscribe,
        style:ElevatedButton.styleFrom(elevation: 0, backgroundColor:kMerchantPrimary,shape: const StadiumBorder()),
        child:const Text("Proceed to Pay",style:TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w700)))),
      if (_msg.isNotEmpty)...[const SizedBox(height:10),Text(_msg,textAlign:TextAlign.center,style:TextStyle(color:Colors.red.shade700,fontSize:13))],
      const SizedBox(height:24),
    ])),
  );
}

// ─────────── Merchant Invoices Page ───────────
class MerchantInvoicesPage extends StatefulWidget {
  final String token; const MerchantInvoicesPage({super.key,required this.token});
  @override State<MerchantInvoicesPage> createState() => _InvoicesState();
}
class _InvoicesState extends State<MerchantInvoicesPage> {
  List _invoices=[]; bool _loading=true;
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    if(mounted) setState(()=>_loading=true);
    _invoices = await Api.getFullInvoices(widget.token);  // T2: shows banner + product invoices too
    if(mounted) setState(()=>_loading=false);
  }


  // FIX 14: Share invoice as text
  void _shareInvoice(Map inv) {
    final text = [
      "OFFRO — Invoice",
      "Invoice No: ${inv['invoice_no']??''}",
      "Store: ${inv['store_name']??''}",
      "Plan: ${inv['plan']??''}",
      "Period: ${inv['from_date']??''} – ${inv['end_date']??''}",
      "Base: ₹${inv['base_price']??0}  GST: ₹${inv['gst']??0}",
      "Total Paid: ₹${inv['total']??0}",
      "Date: ${inv['created_at']?.toString().substring(0,10)??''}",
    ].join("\n");
    Share.share(text, subject: "OFFRO Invoice ${inv['invoice_no']??''}");
  }

  // FIX 14: Print/Download PDF — direct PDF generation (avoids iOS convertHtml crash)
  Future<void> _printInvoice(Map inv) async {
    try {
      final doc = pw.Document();

      // OFFRO brand colors
      const green = PdfColor.fromInt(0xFF3E5F55);
      const lightGreen = PdfColor.fromInt(0xFFCDEBD6);
      const textColor = PdfColor.fromInt(0xFF2c3e35);
      const mutedColor = PdfColor.fromInt(0xFF6b8c7e);

      final invoiceNo = inv['invoice_no']?.toString() ?? '';
      final storeName = inv['store_name']?.toString() ?? '';
      final plan = inv['plan']?.toString() ?? '';
      final fromDate = inv['from_date']?.toString() ?? '';
      final endDate = inv['end_date']?.toString() ?? '';
      final createdAt = inv['created_at']?.toString() ?? '';
      final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';
      final basePrice = inv['base_price']?.toString() ?? '0';
      final gst = inv['gst']?.toString() ?? '0';
      final total = inv['total']?.toString() ?? '0';

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: green,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('OFFRO', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      pw.SizedBox(height: 4),
                      pw.Text('Tax Invoice', style: pw.TextStyle(fontSize: 13, color: PdfColors.white)),
                      pw.SizedBox(height: 2),
                      pw.Text(invoiceNo, style: pw.TextStyle(fontSize: 13, color: PdfColors.white)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFd4e8de)),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      _pdfRow('Store', storeName, textColor, mutedColor),
                      pw.SizedBox(height: 6),
                      _pdfRow('Plan', plan, textColor, mutedColor),
                      pw.SizedBox(height: 6),
                      _pdfRow('Period', '$fromDate \u2013 $endDate', textColor, mutedColor),
                      pw.SizedBox(height: 6),
                      _pdfRow('Date', dateStr, textColor, mutedColor),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFd4e8de)),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      _pdfRow('Base Amount', 'Rs. $basePrice', textColor, mutedColor),
                      pw.SizedBox(height: 6),
                      _pdfRow('GST (18%)', 'Rs. $gst', textColor, mutedColor),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: lightGreen,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Total Paid', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: textColor)),
                            pw.Text('Rs. $total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: green)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('OFFRO — Thank you for your business!',
                        style: pw.TextStyle(fontSize: 11, color: mutedColor)),
                      pw.SizedBox(height: 2),
                      pw.Text('This is a system-generated invoice.',
                        style: pw.TextStyle(fontSize: 11, color: mutedColor)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (fmt) async => doc.save(),
        name: "OFFRO_Invoice_$invoiceNo",
      );
    } catch (e) {
      debugPrint('PDF generation error: $e');
      _shareInvoice(inv);
    }
  }

  // Helper for PDF rows
  pw.Widget _pdfRow(String label, String value, PdfColor textColor, PdfColor mutedColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(color: mutedColor, fontSize: 13)),
        pw.Text(value, style: pw.TextStyle(color: textColor, fontSize: 13, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kMerchantBg,
    appBar:merchantHeaderBar(eyebrow:"Billing & subscriptions",title:"Invoices",back:false,
      actions:[IconButton(icon:const Icon(Icons.refresh),onPressed:_load,tooltip:"Refresh")],
    ),
    body:_loading?const Center(child:CircularProgressIndicator(color:kMerchantPrimary)):
    RefreshIndicator(
      color:kMerchantPrimary,onRefresh:_load,
      child:_invoices.isEmpty
        ? ListView(children:[SizedBox(height:MediaQuery.sizeOf(context).height*0.4,
            child:const Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
              Icon(Icons.receipt_long_outlined,size:56,color:kMerchantAccent),
              SizedBox(height:12),
              Text("No invoices yet",style:TextStyle(color:kMerchantMuted,fontSize:15)),
              SizedBox(height:6),
              Text("Pull down to refresh",style:TextStyle(color:kMerchantMuted,fontSize:12)),
            ])))])
        : ListView.builder(
            padding:const EdgeInsets.all(14),
            itemCount:_invoices.length,
            itemBuilder:(_,i){
              final inv = _invoices[i] as Map;
              return Card(elevation:0,color:Colors.white,surfaceTintColor:Colors.transparent,margin:const EdgeInsets.only(bottom:12),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),side:const BorderSide(color:OffroColors.border)),
                child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[
                    const Icon(Icons.receipt_long,color:kMerchantPrimary,size:16),
                    const SizedBox(width:6),
                    Expanded(child:Text(inv["invoice_no"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:kMerchantPrimary,fontSize:13))),
                    Text(_fmtDateTime(inv["created_at"]?.toString()),style:const TextStyle(color:kMerchantMuted,fontSize:11)),
                  ]),
                  const Divider(height:14),
                  Text(inv["store_name"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:kMerchantText)),
                  Text("Plan: ${inv['plan']??''}  •  ${inv['from_date']??''} – ${inv['end_date']??''}",style:const TextStyle(color:kMerchantMuted,fontSize:12)),
                  const SizedBox(height:6),
                  Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                    // TASK 6: show discount info if present
                    Builder(builder: (_) {
                      final origAmt  = (inv["original_amount"] ?? inv["base_price"] ?? 0) as num;
                      final discCode = inv["discount_code"]?.toString() ?? "";
                      final discAmt  = (inv["discount_amount"] ?? 0) as num;
                      final gstAmt   = (inv["gst"] ?? 0) as num;
                      final totalAmt = (inv["total"] ?? 0) as num;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Base: ₹${origAmt.toStringAsFixed(2)}  GST: ₹${gstAmt.toStringAsFixed(2)}",
                            style:const TextStyle(color:kMerchantMuted,fontSize:12)),
                          if(discCode.isNotEmpty && discAmt > 0)
                            Text("Discount ($discCode): −₹${discAmt.toStringAsFixed(2)}",
                              style:const TextStyle(color:OffroColors.statusLive,fontSize:11,fontWeight:FontWeight.w600)),
                        ],
                      );
                    }),
                    Text("₹${((inv["total"]??0) as num).toStringAsFixed(2)}",
                      style:const TextStyle(fontWeight:FontWeight.bold,color:kMerchantPrimary,fontSize:15)),
                  ]),
                  const SizedBox(height:12),
                  // FIX 14: Action buttons
                  Row(children:[
                    Expanded(child:OutlinedButton.icon(
                      icon:const Icon(Icons.share_rounded,size:16),
                      label:const Text("Share",style:TextStyle(fontSize:12)),
                      style:OutlinedButton.styleFrom(elevation: 0, 
                        foregroundColor:kMerchantPrimary,side:const BorderSide(color:kMerchantPrimary),
                        padding:const EdgeInsets.symmetric(vertical:8),
                        shape: const StadiumBorder()),
                      onPressed:()=>_shareInvoice(inv),
                    )),
                    const SizedBox(width:10),
                    Expanded(child:ElevatedButton.icon(
                      icon:const Icon(Icons.download_rounded,size:16),
                      label:const Text("Download PDF",style:TextStyle(fontSize:12)),
                      style:ElevatedButton.styleFrom(elevation: 0, 
                         
                        padding:const EdgeInsets.symmetric(vertical:8),
                        shape: const StadiumBorder()),
                      onPressed:()=>_printInvoice(inv),
                    )),
                  ]),
                ])));
            }),
    ),
  );
}

// ─────────── Merchant Activity Page (FIX 7) ───────────

// Humanize raw transaction type/description codes → readable text
String _humanizeActivity(String raw) {
  const _map = {
    "account_created":        "Account registered",
    "store_created":          "New store created",
    "store_updated":          "Store profile updated",
    "store_approved":         "Store approved",
    "store_rejected":         "Store rejected",
    "subscription":           "Store subscription activated",
    "subscription_free":      "Free subscription activated",
    "subscription_paid":      "Subscription payment received",
    "banner":                 "Banner submitted",
    "banner_approved":        "Banner approved",
    "banner_rejected":        "Banner rejected",
    "banner_paid":            "Banner payment received",
    "product":                "Product submitted",
    "product_approved":       "Product approved",
    "product_rejected":       "Product rejected",
    "product_paid":           "Product payment received",
    "payment":                "Payment received",
    "free":                   "Free plan activated",
    "profile_updated":        "Profile updated",
    "qr_reset":               "QR code regenerated",
  };
  final key = raw.trim().toLowerCase().replaceAll(' ', '_');
  // If it's already a human-readable string (contains spaces or title case), return as-is
  if (raw.contains(' ') && !raw.contains('_')) return raw;
  return _map[key] ?? raw.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '\${w[0].toUpperCase()}\${w.substring(1)}').join(' ');
}

class MerchantTxnPage extends StatefulWidget {
  final String token; const MerchantTxnPage({super.key,required this.token});
  @override State<MerchantTxnPage> createState() => _TxnState();
}
class _TxnState extends State<MerchantTxnPage> {
  List _txns=[]; List _banners=[]; List _products=[];
  bool _loading=true;
  int _tab=0; // 0=All, 1=Banners, 2=Products, 3=Payments
  @override void initState() { super.initState(); _load(); }

  // Amounts can arrive as num or numeric String — never let a String reach a `> 0` compare.
  static num _amt(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? "") ?? 0);

  Future<void> _load() async {
    if(mounted) setState(()=>_loading=true);
    final results = await Future.wait([
      Api.getMerchantTransactions(widget.token),
      Api.getMerchantBanners(widget.token),
      Api.getMerchantProducts(widget.token),
    ]);
    if(mounted) setState((){
      _txns    = results[0];
      _banners = results[1];
      _products= results[2];
      _loading = false;
    });
  }

  List<Map> get _allActivity {
    final events = <Map>[];
    // Payments/subscriptions from txns
    for(final t in _txns) {
      events.add({
        "type":"payment","icon":Icons.payment,"color":kMerchantPrimary,
        "title":_humanizeActivity(t["description"]?.toString()??t["plan"]?.toString()??"Payment"),
        "subtitle":"₹${t['amount']??0}",
        "date":t["date"]??t["created_at"]??"",
        "amount":_amt(t["amount"]),
      });
    }
    // Banner events
    for(final b in _banners) {
      final st=(b["approval_status"]??b["status"]??"pending").toString();
      final (Color sc,IconData si) = switch(st){
        "approved"   => (OffroColors.statusLive, Icons.check_circle_outline),
        "rejected"   => (Colors.red, Icons.cancel_outlined),
        _ => (OffroColors.statusPending, Icons.hourglass_top_rounded),
      };
      events.add({
        "type":"banner","icon":Icons.photo_size_select_actual_outlined,"color":const Color(0xFF2980b9),
        "title":"Banner: ${b['title']??'Untitled'}",
        "subtitle":st=="approved"?"✅ Approved — Live":st=="rejected"?"❌ Rejected":"⏳ Pending Approval",
        "subtitle_color":sc,"status_icon":si,
        "date":b["created_at"]??"",
        "amount":_amt(b["amount"]),
        "from_date":b["from_date"]??"",
        "end_date":b["end_date"]??"",
      });
    }
    // Product events
    for(final v in _products) {
      final st=(v["approval_status"]??v["status"]??"pending").toString();
      final (Color sc,IconData si) = switch(st){
        "approved"   => (OffroColors.statusLive, Icons.check_circle_outline),
        "rejected"   => (Colors.red, Icons.cancel_outlined),
        _ => (OffroColors.statusPending, Icons.hourglass_top_rounded),
      };
      events.add({
        "type":"product","icon":Icons.local_activity_outlined,"color":const Color(0xFF8e44ad),
        "title":"Product: ${v['title']??'Untitled'}",
        "subtitle":st=="approved"?"✅ Approved — Live":st=="rejected"?"❌ Rejected":"⏳ Pending Approval",
        "subtitle_color":sc,"status_icon":si,
        "date":v["created_at"]??"",
        "amount":_amt(v["amount"]),
        "from_date":v["from_date"]??"",
        "end_date":v["end_date"]??"",
      });
    }
    // Sort by date descending
    events.sort((a,b){
      try{return (b["date"]??'').compareTo(a["date"]??'');}catch(_){return 0;}
    });
    return events;
  }

  List<Map> get _filtered {
    if(_tab==0) return _allActivity;
    if(_tab==1) return _allActivity.where((e)=>e["type"]=="banner").toList();
    if(_tab==2) return _allActivity.where((e)=>e["type"]=="product").toList();
    return _allActivity.where((e)=>e["type"]=="payment").toList();
  }

  @override Widget build(BuildContext context) {
    final items = _filtered; // once per build (was recomputed, incl. a sort, for every row)
    return Scaffold(
    backgroundColor:kMerchantBg,
    appBar:merchantHeaderBar(eyebrow:"Business timeline",title:"Activity",back:false,
      actions:[IconButton(icon:const Icon(Icons.refresh),onPressed:_load)],
    ),
    body:Column(children:[
      // Filter tabs
      Container(padding:const EdgeInsets.fromLTRB(OffroSpacing.gutter,4,OffroSpacing.gutter,10),
        child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:["All","Banners","My Products","Payments"].asMap().entries.map((e)=>
          GestureDetector(
            behavior:HitTestBehavior.opaque,
            onTap:()=>setState(()=>_tab=e.key),
            child:Container(
              margin:const EdgeInsets.only(right:8),
              padding:const EdgeInsets.symmetric(horizontal:16,vertical:9),
              decoration:BoxDecoration(
                color:_tab==e.key?OffroColors.primary:Colors.white,
                borderRadius:BorderRadius.circular(20),
                border:_tab==e.key?null:Border.all(color:OffroColors.border)),
              child:Text(e.value,style:OffroText.caption.copyWith(
                color:_tab==e.key?Colors.white:OffroColors.primary,
                fontSize:11,fontWeight:FontWeight.w700)),
            ),
          )).toList())),
      ),  // close filter-tabs Container
      // Content
      Expanded(child:_loading
        ? const Center(child:CircularProgressIndicator(color:kMerchantPrimary))
        : RefreshIndicator(
            color:kMerchantPrimary,onRefresh:_load,
            child:items.isEmpty
              ? ListView(children:[SizedBox(height:300,child:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                  const Icon(Icons.history,size:48,color:kMerchantAccent),
                  const SizedBox(height:12),
                  const Text("No activity yet",style:TextStyle(color:kMerchantMuted,fontSize:15)),
                ])))])
              : ListView.builder(
                  padding:const EdgeInsets.fromLTRB(14,12,14,24),
                  itemCount:items.length,
                  itemBuilder:(_,i){
                    final t = items[i];
                    final Color ic = t["color"] as Color? ?? kMerchantPrimary;
                    final Color sc = t["subtitle_color"] as Color? ?? kMerchantMuted;
                    return Container(
                      margin:const EdgeInsets.only(bottom:8),
                      padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:kMerchantBorder)),
                      child:Row(children:[
                        CircleAvatar(backgroundColor:OffroColors.mint,radius:22,
                          child:Icon(t["icon"] as IconData,color:OffroColors.primary,size:18)),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(t["title"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:kMerchantText,fontSize:13)),
                          const SizedBox(height:2),
                          Text(t["subtitle"]??"",style:TextStyle(color:sc,fontSize:11,fontWeight:FontWeight.w600)),
                          if((t["from_date"]??"").isNotEmpty && (t["end_date"]??"").isNotEmpty)
                            Text("${t['from_date']} → ${t['end_date']}",style:const TextStyle(color:kMerchantMuted,fontSize:10)),
                          const SizedBox(height:2),
                          Text(_fmtDateTime(t["date"]?.toString()),style:const TextStyle(color:kMerchantMuted,fontSize:10)),
                        ])),
                        if((t["amount"]??0)>0)
                          Text("₹${t['amount']}",style:const TextStyle(color:kMerchantPrimary,fontWeight:FontWeight.bold,fontSize:13)),
                      ]),
                    );
                  }),
          )),
    ]),
    );
  }
}

// ─────────── Merchant Profile Page ───────────
class MerchantProfilePage extends StatefulWidget {
  final String token; final Map merchant;
  const MerchantProfilePage({super.key,required this.token,required this.merchant});
  @override State<MerchantProfilePage> createState() => _MerchantProfileState();
}
class _MerchantProfileState extends State<MerchantProfilePage> {
  String? _imgB64;
  bool _uploading = false;
  late Map<String, dynamic> _merchantData;

  @override void initState() {
    super.initState();
    _merchantData = Map<String, dynamic>.from(widget.merchant);
    _imgB64 = _merchantData["profile_image"] as String?;
    _fetchLatestProfile();
  }

  Future<void> _fetchLatestProfile() async {
    try {
      final fresh = await Api.getMerchantProfile(widget.token);
      if (fresh != null && mounted) {
        setState(() {
          _merchantData = fresh;
          _imgB64 = fresh["profile_image"] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 600);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Image too large. Max 2MB allowed."), backgroundColor: Colors.red));
      return;
    }
    final b64 = "data:image/jpeg;base64,${base64Encode(bytes)}";
    setState(() { _uploading = true; _imgB64 = b64; });
    try {
      await Api.updateMerchantProfile(widget.token, {"profile_image": b64});
      await _fetchLatestProfile();
    } catch(_) {}
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _contactOffro() async {
    final s = await Api.getSocialLinks();
    final rawWa = s["whatsapp"] ?? "";
    if (rawWa.isNotEmpty) {
      final digits = rawWa.replaceAll(RegExp(r'[^0-9]'), '');
      final waNum = digits.length >= 10 ? (digits.length == 10 ? "91$digits" : digits) : digits;
      await launchUrl(Uri.parse("https://wa.me/$waNum"), mode: LaunchMode.externalApplication);
    }
  }

  void _openSwitchMode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SwitchModeSheet(
        currentMode: 'merchant',
        token: widget.token,
        phone: widget.merchant['phone']?.toString() ?? '',
        onSwitch: (role) {
          if (role == 'user' || role == 'influencer') {
            // Same goSwitchMode dispatch for User and Influencer (unchanged behaviour).
            final token = widget.token;
            final name  = widget.merchant['name']?.toString() ?? '';
            final phone = widget.merchant['phone']?.toString() ?? '';
            final uid   = widget.merchant['merchant_id']?.toString() ?? widget.merchant['_id']?.toString() ?? '';
            Navigator.of(context).pop(); // close profile
            MyApp.goSwitchMode(token, name, phone, uid, role);
          }
        },
      ),
    );
  }

  Future<void> _logout() async {
    await Prefs.clear(keepMode: false);
    Api.clearCache();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (_) => false,
    );
  }

  Widget _group(String eyebrow, List<Widget> rows) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(eyebrow.toUpperCase(),
        style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.8, color: OffroColors.sage)),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: OffroColors.surface, borderRadius: BorderRadius.circular(22)),
        child: Column(children: rows),
      ),
    ]),
  );

  Widget _accountRow({
    required Widget icon,
    required String label,
    String? note,
    required VoidCallback onTap,
    bool destructive = false,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: destructive ? OffroColors.error.withValues(alpha: .10) : OffroColors.mintSoft,
            shape: BoxShape.circle),
          child: icon,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: OffroText.cardTitle.copyWith(
            fontSize: 13, color: destructive ? OffroColors.error : OffroColors.text)),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textFaint)),
          ],
        ])),
        if (!destructive) const OffroIcon(OffroIcons.chevron, size: 14, color: OffroColors.sage),
      ]),
    ),
  );

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kMerchantBg,
    appBar:merchantHeaderBar(eyebrow:"Merchant account",title:"Profile",back:false,),
    body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:OffroColors.mint,borderRadius:BorderRadius.circular(24)),
        child:Column(children:[
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(alignment:Alignment.bottomRight,children:[
              CircleAvatar(radius:44, backgroundColor:OffroColors.primary,
                backgroundImage: _imgB64 != null && _imgB64!.startsWith("data:") ? MemoryImage(base64Decode(_imgB64!.split(",").last)) : null,
                child: _imgB64 == null ? buildLogo(38,OffroColors.mint) : null),
              Container(width:26,height:26,decoration:const BoxDecoration(color:Colors.white,shape:BoxShape.circle),
                child: _uploading ? const Padding(padding:EdgeInsets.all(4),child:CircularProgressIndicator(strokeWidth:2,color:kMerchantPrimary)) : const Icon(Icons.camera_alt,size:16,color:kMerchantPrimary)),
            ])),
          const SizedBox(height:8),
          Text(_merchantData["name"]??"",style:OffroText.title.copyWith(fontSize:18)),
          Text(_merchantData["phone"]??"",style:const TextStyle(color:OffroColors.secondarySolid)),
          if((_merchantData["city"]??'').isNotEmpty)
            Text("${_merchantData['city']}, ${_merchantData['area']??''}",style:const TextStyle(color:OffroColors.secondarySolid,fontSize:12)),
          const SizedBox(height:4),
          const Text("Tap photo to change",style:TextStyle(color:OffroColors.secondarySolid,fontSize:10)),
        ])),
      const SizedBox(height:20),
      _tile(context,Icons.info_outline,"About Us",() => _openAbout(context)),
      _tile(context,Icons.description,"Terms & Conditions",() => _openPolicy(context,"Terms & Conditions",Api.getMerchantTerms())),
      _tile(context,Icons.privacy_tip,"Privacy Policy",() => Navigator.push(context,MaterialPageRoute(builder:(_)=>MerchantPrivacyPolicyPage(token:widget.token)))),
      _tile(context,Icons.receipt,"Refund Policy",() => _openPolicy(context,"Refund Policy",Api.fetchPolicy("refund"))),
      _tile(context,Icons.badge,"KYC Policy",() => _openPolicy(context,"KYC Policy",Api.fetchPolicy("kyc"))),
      // ── ACCOUNT / SESSION — same grouped-card + row styling as the Customer profile
      // (ProfileTab._group/_row). Behaviour of each action is unchanged. ──
      _group("Account", [
        _accountRow(
          icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: OffroColors.primary),
          label: "Switch Mode", note: "Switch between User, Merchant & Influencer",
          onTap: _openSwitchMode),
        _accountRow(
          icon: const OffroIcon(OffroIcons.message, size: 16, color: OffroColors.primary),
          label: "Contact Offro", note: "Chat with us on WhatsApp",
          onTap: _contactOffro),
      ]),
      _group("Session", [
        _accountRow(
          icon: const OffroIcon(OffroIcons.arrow, size: 16, color: OffroColors.error),
          label: "Logout", destructive: true,
          onTap: _logout),
      ]),
    ])),
  );

  Widget _tile(BuildContext ctx, IconData icon, String title, VoidCallback onTap) =>
    Padding(padding:const EdgeInsets.only(bottom:10),child:ListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),side:const BorderSide(color:OffroColors.border)),
      leading:CircleAvatar(backgroundColor:OffroColors.mint,child:Icon(icon,color:OffroColors.primary,size:20)),
      title:Text(title,style:OffroText.value.copyWith(fontSize:13,fontWeight:FontWeight.w600)),
      trailing:const Icon(Icons.chevron_right,color:OffroColors.secondarySolid),onTap:onTap,
      contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:4)));

  void _openAbout(BuildContext ctx) async {
    final c = await Api.getAboutUs();
    if (!ctx.mounted) return;
    showDialog(context:ctx, builder:(_)=>OffroDialog(title:"About Us",body:c.isEmpty?"Offro connects local stores with customers through deals and loyalty points.":c));
  }

  void _openPolicy(BuildContext ctx, String title, Future<String> loader) {
    showDialog(context:ctx, barrierDismissible:false,
      builder:(_)=>FutureBuilder<String>(future:loader,
        builder:(c,snap){
          if(snap.connectionState!=ConnectionState.done) return const AlertDialog(content:SizedBox(height:80,child:Center(child:CircularProgressIndicator(color:kMerchantPrimary))));
          return OffroDialog(title:title,body:snap.data??"");
        }));
  }
}


// ─────────── User Profile Header (with image upload) ───────────
class UserProfileHeader extends StatefulWidget {
  final String token, name, phone;
  const UserProfileHeader({required this.token, required this.name, required this.phone});
  @override State<UserProfileHeader> createState() => _UserProfileHeaderState();
}
class _UserProfileHeaderState extends State<UserProfileHeader> {
  String? _imgB64;
  bool _uploading = false;

  @override void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    try {
      final d = await Api.getMe(widget.token);
      if (mounted && d != null && d["profile_image"] != null) setState(()=>_imgB64=d["profile_image"]);
    } catch(_){}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 600);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    final b64 = "data:image/jpeg;base64,${base64Encode(bytes)}";
    setState(() { _uploading = true; _imgB64 = b64; });
    try { await Api.updateUserProfile(widget.token, {"profile_image": b64}); } catch(_) {}
    if (mounted) setState(() => _uploading = false);
  }

  @override Widget build(BuildContext context) => ListTile(
    leading: GestureDetector(
      onTap: _pickImage,
      child: Stack(alignment:Alignment.bottomRight, children:[
        CircleAvatar(radius:24, backgroundColor:kMerchantLight,
          backgroundImage: _imgB64 != null && _imgB64!.startsWith("data:")
            ? MemoryImage(base64Decode(_imgB64!.split(",").last)) : null,
          child: _imgB64 == null ? const Icon(Icons.person, color:kMerchantPrimary) : null),
        Container(width:16,height:16,decoration:const BoxDecoration(color:kMerchantPrimary,shape:BoxShape.circle),
          child: _uploading ? const Padding(padding:EdgeInsets.all(2),child:CircularProgressIndicator(strokeWidth:1.5,color:Colors.white)) : const Icon(Icons.camera_alt,size:10,color:Colors.white)),
      ])),
    title: Text(widget.name, style:const TextStyle(fontWeight:FontWeight.bold)),
    subtitle: Text(widget.phone),
  );
}

// ─────────────────────── USER HOME ───────────────────────


// ─── MERCHANT DEALS ───────────────────────────────────
class MerchantDealsPage extends StatefulWidget {
  final String token;
  const MerchantDealsPage({super.key, required this.token});
  @override State<MerchantDealsPage> createState() => _MerchantDealsState();
}
class _MerchantDealsState extends State<MerchantDealsPage> {
  List<Map<String,dynamic>> _deals = []; List<Map<String,dynamic>> _stores = []; bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _deals = List<Map<String,dynamic>>.from(await Api.getMerchantDeals(widget.token));
    _stores = List<Map<String,dynamic>>.from(await Api.getMerchantStores(widget.token));
    if (mounted) setState(() => _loading = false);
  }

  /// Parse "yyyy-MM-dd" or "dd MMM yyyy" without a third-party date library.
  static DateTime? _parseDealDate(String s) {
    s = s.trim();
    if (s.isEmpty) return null;
    try { return DateTime.parse(s.substring(0, 10)); } catch (_) {}
    final months = {"jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
                    "jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12};
    final parts = s.split(RegExp(r"[\s/-]+"));
    if (parts.length == 3) {
      try {
        final day = int.parse(parts[0]);
        final mon = months[parts[1].toLowerCase().substring(0,3)] ?? 0;
        final yr  = int.parse(parts[2]);
        if (mon > 0) return DateTime(yr, mon, day);
      } catch (_) {}
    }
    return null;
  }

  static String _formatDealDate(String raw) {
    final dt = _parseDealDate(raw);
    if (dt == null) return raw;
    const m = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${dt.day} ${m[dt.month - 1]} ${dt.year}";
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kMerchantBg,
    appBar: merchantHeaderBar(eyebrow: "Merchant offers", title: "My Deals", back: false,
        
        actions:[
          Padding(
            padding:const EdgeInsets.only(right:18),
            child:offroHeaderAddButton(
              icon:Icons.add,
              tooltip:"Add Deal",
              onPressed: () {
                final activeStores = _stores.where((s) => s["status"] == "active").toList();
                if (activeStores.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("You need an active store to add deals."), backgroundColor: Colors.orange));
                  return;
                }
                Navigator.push(context, appRoute(AddDealPage(
                  token: widget.token,
                  storeId: activeStores[0]["_id"] ?? "",
                  storeName: activeStores[0]["store_name"] ?? "",
                  stores: activeStores,
                ))).then((_) => _load());
              },
            ),
          ),
        ]),
    body: _loading ? const Center(child: CircularProgressIndicator(color: kMerchantPrimary)) :
      _deals.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.local_offer_outlined, size: 64, color: kMerchantAccent),
        const SizedBox(height: 12),
        const Text("No deals yet", style: TextStyle(color: kMerchantMuted, fontSize: 16)),
        const SizedBox(height: 8),
        const Text("Add deals to attract more customers", style: TextStyle(color: kMerchantMuted, fontSize: 13)),
      ])) :
      RefreshIndicator(onRefresh: _load, child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _deals.length,
        itemBuilder: (_, i) {
          final d = _deals[i] as Map;
          // Round 7 Item 2: compact 44x44 thumbnail when the deal has its own
          // image_url; falls back to the existing discount-% chip (and, for a
          // deal with neither, a generic offer icon) so the list tile's
          // height/layout never changes — same 44x44 leading slot as before.
          final dealImg = (d['image_url'] ?? '').toString();
          final discPct = "${d['discount'] ?? 0}%";
          final hasDisc = (int.tryParse((d['discount'] ?? '0').toString()) ?? 0) > 0;
          Widget leadingWidget;
          if (dealImg.isNotEmpty) {
            leadingWidget = GestureDetector(
              onTap: () => Navigator.push(context, PageRouteBuilder(
                opaque: false, barrierColor: Colors.black,
                pageBuilder: (_, __, ___) => FullScreenImageViewer(images: [dealImg], initialIndex: 0),
              )),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: dealImg.startsWith('data:image')
                    ? Image.memory(base64Decode(dealImg.split(',').last), width: 44, height: 44, fit: BoxFit.cover)
                    : CachedNetworkImage(imageUrl: dealImg, width: 44, height: 44, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(width: 44, height: 44, color: kMerchantLight.withValues(alpha: .5)),
                        errorWidget: (_, __, ___) => Container(width: 44, height: 44,
                          color: kMerchantLight.withValues(alpha: .5),
                          child: const Icon(Icons.broken_image_outlined, color: kMerchantMuted, size: 18))),
              ),
            );
          } else {
            leadingWidget = Container(width: 44, height: 44,
              decoration: BoxDecoration(color: OffroColors.mint, borderRadius: BorderRadius.circular(14)),
              child: Center(child: hasDisc
                  ? Text(discPct, style: const TextStyle(color: kMerchantPrimary, fontWeight: FontWeight.bold, fontSize: 13))
                  : const Icon(Icons.local_offer_outlined, color: kMerchantPrimary, size: 18)));
          }
          return Card(elevation: 0, color: Colors.white, surfaceTintColor: Colors.transparent, margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: OffroColors.border)),
            child: ListTile(
              leading: leadingWidget,
              title: Text(d["title"] ?? "", style: const TextStyle(fontWeight: FontWeight.w600, color: kMerchantText)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text("${d['store_name'] ?? ''} • ${d['category'] ?? ''}", style: const TextStyle(color: kMerchantMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Builder(builder: (_) {
                    final endStr = d["end_date"]?.toString() ?? "";
                    final endDt = _parseDealDate(endStr);
                    // Valid THROUGH the end date (same rule as backend/Store Detail):
                    // expired only after 23:59:59 IST of that day. IST = UTC+05:30,
                    // computed from UTC so the phone's timezone setting is irrelevant.
                    final istNow = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
                    final isExpired = endDt != null &&
                        istNow.isAfter(DateTime.utc(endDt.year, endDt.month, endDt.day, 23, 59, 59));
                    return Row(mainAxisSize: MainAxisSize.min, children: [
                      if (endStr.isNotEmpty) ...[
                        const Icon(Icons.calendar_today_rounded, size: 11, color: kMerchantMuted),
                        const SizedBox(width: 4),
                        Text("Ends ${_formatDealDate(endStr)}", style: const TextStyle(color: kMerchantMuted, fontSize: 11)),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isExpired ? Colors.red.withValues(alpha: .12) : Colors.green.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(isExpired ? "Expired" : "Active",
                          style: TextStyle(color: isExpired ? Colors.red.shade700 : Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ]);
                  }),
                ]),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: kMerchantPrimary),
                  tooltip: "Edit Deal",
                  onPressed: () {
                    Navigator.push(context, appRoute(AddDealPage(
                      token: widget.token,
                      storeId: d["store_id"]?.toString() ?? "",
                      storeName: d["store_name"]?.toString() ?? "",
                      stores: _stores.where((s) => s["status"] == "active").toList(),
                      editDeal: Map<String,dynamic>.from(d),
                    ))).then((_) => _load());
                  }),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Delete Deal?"),
                        content: Text("Delete \"${d['title']}\"?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                          ElevatedButton(style: ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.white))),
                        ]));
                    if (confirm == true) {
                      await Api.deleteDeal(widget.token, d["_id"]);
                      _load();
                    }
                  }),
              ]),
            ));
        },
      )),
  );
}

// ─────────────────────── ADD / EDIT DEAL PAGE ───────────────────────
class AddDealPage extends StatefulWidget {
  final String token; final String storeId; final String storeName;
  final List<Map<String,dynamic>> stores;
  final Map<String,dynamic>? editDeal;  // null = add mode, non-null = edit mode
  const AddDealPage({super.key, required this.token, required this.storeId,
    required this.storeName, this.stores = const <Map<String,dynamic>>[], this.editDeal});
  @override State<AddDealPage> createState() => _AddDealState();
}
class _AddDealState extends State<AddDealPage> {
  final _title = TextEditingController();
  final _desc  = TextEditingController();
  String _category = ""; bool _loading = false; String _msg = "";
  List<dynamic> _categories = [];
  late String _selectedStoreId;
  late String _selectedStoreName;
  late String _endDate;
  DateTime? _storeExpiryDate;
  // Item 3 (Add Deal image upload): same two-variable convention already
  // used by this file's other image pickers (e.g. MerchantStoreEditPage's
  // _imgB64/_imgUrl) — _dealImgB64 holds a freshly picked image as a
  // base64 data URI, _dealImgUrl holds the existing CDN URL prefilled in
  // edit mode until the merchant replaces it. Whichever is non-null is what
  // gets sent; the backend's existing _cloudinary_upload helper is a no-op
  // pass-through for an already-uploaded http(s) URL, so re-sending the
  // existing image on every save never re-uploads it.
  String? _dealImgB64;
  String? _dealImgUrl;

  bool get _isEdit => widget.editDeal != null;

  @override
  void initState() {
    super.initState();
    _selectedStoreId = widget.storeId;
    _selectedStoreName = widget.storeName;

    if (_isEdit) {
      final d = widget.editDeal!;
      _title.text = d["title"]?.toString() ?? "";
      _desc.text  = d["description"]?.toString() ?? "";
      _category  = d["category"]?.toString() ?? "";
      _endDate   = d["end_date"]?.toString() ?? "";
      _selectedStoreId = d["store_id"]?.toString() ?? widget.storeId;
      _selectedStoreName = d["store_name"]?.toString() ?? widget.storeName;
      // Item 3: prefill the existing image so Edit Deal shows it, per requirement.
      final existingImg = d["image_url"]?.toString() ?? "";
      if (existingImg.isNotEmpty) _dealImgUrl = existingImg;
    } else {
      _endDate = DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10);
    }

    _loadStoreExpiry();
    Api.fetchCategories(token: widget.token).then((v) { if (mounted) setState(() => _categories = v as List); });
  }

  void _loadStoreExpiry() {
    for (final s in widget.stores) {
      if (s["_id"]?.toString() == _selectedStoreId) {
        final subEnd = s["subscription_end"]?.toString() ?? "";
        if (subEnd.isNotEmpty) {
          _storeExpiryDate = _parseDateString(subEnd);
        }
        break;
      }
    }
  }

  /// Parse "dd MMM yyyy" (e.g. "02 Aug 2026") or "yyyy-MM-dd" without intl.
  static DateTime? _parseDateString(String s) {
    s = s.trim();
    // Try yyyy-MM-dd
    try { return DateTime.parse(s.substring(0, 10)); } catch (_) {}
    // Try "dd MMM yyyy"
    final months = {"jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
                    "jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12};
    final parts = s.split(RegExp(r"[\s/-]+"));
    if (parts.length == 3) {
      try {
        final day = int.parse(parts[0]);
        final mon = months[parts[1].toLowerCase().substring(0,3)] ?? 0;
        final yr  = int.parse(parts[2]);
        if (mon > 0) return DateTime(yr, mon, day);
      } catch (_) {}
      // Also try yyyy-MM-dd format where parts are split by -
      if (parts[0].length == 4) {
        try { return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])); } catch (_) {}
      }
    }
    return null;
  }

  @override void dispose() { _title.dispose(); _desc.dispose(); super.dispose(); }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_endDate) ?? now.add(const Duration(days: 30));
    DateTime maxDate = _storeExpiryDate ?? now.add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(maxDate) ? maxDate : (initial.isBefore(now) ? now : initial),
      firstDate: now,
      lastDate: maxDate,
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
        colorScheme: ColorScheme.light(primary: kMerchantPrimary, onPrimary: Colors.white),
      ), child: child!),
    );
    if (picked != null) {
      setState(() => _endDate = picked.toIso8601String().substring(0, 10));
    }
  }

  String _formatEndDateDisplay() {
    final dt = DateTime.tryParse(_endDate);
    if (dt == null) return _endDate;
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  String _storeExpiryDisplay() {
    if (_storeExpiryDate == null) return "";
    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${_storeExpiryDate!.day} ${months[_storeExpiryDate!.month - 1]} ${_storeExpiryDate!.year}";
  }

  // Item 3 (Add Deal image upload): identical pattern to AddBannerPage's
  // _pickImage / the Premium product form's _pickLogo elsewhere in this
  // file — same picker source, size guard and base64 data-URI encoding —
  // so this reuses the existing image-upload convention instead of a new one.
  Future<void> _pickDealImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image too large. Max 2MB."), backgroundColor: Colors.red));
      return;
    }
    setState(() { _dealImgB64 = "data:image/jpeg;base64,${base64Encode(bytes)}"; _dealImgUrl = null; });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) { setState(() => _msg = "Deal title is required"); return; }
    if (_endDate.isEmpty)           { setState(() => _msg = "End date is required"); return; }
    // Image is mandatory (new deal, or an edit that would leave the deal without one).
    if ((_dealImgB64 ?? _dealImgUrl ?? "").isEmpty) { setState(() => _msg = "Please add an image before saving."); return; }

    if (_storeExpiryDate != null) {
      final endDt = DateTime.tryParse(_endDate);
      if (endDt != null && endDt.isAfter(_storeExpiryDate!)) {
        setState(() => _msg = "End date cannot exceed store expiry (${_storeExpiryDisplay()})");
        return;
      }
    }

    setState(() => _loading = true); _msg = "";
    try {
      final payload = {
        "store_id":    _selectedStoreId,
        "title":       _title.text.trim(),
        "description": _desc.text.trim(),
        // Item 1 (Round 7): the Discount % field was removed from this form.
        // The "discount" key is intentionally omitted here rather than sent
        // as 0 so that editing an existing deal never overwrites/clears its
        // previously stored discount value (update_deal() falls back to
        // existing.get("discount", 0) when the key is absent). New deals
        // simply get the backend's existing default of 0, and every deal
        // card already guards its "% OFF" badge behind discount > 0 /
        // isNotEmpty, so a 0/absent discount just shows no badge instead of
        // a broken one.
        "category":    _category,
        "start_date":  _isEdit ? (widget.editDeal!["start_date"]?.toString() ?? DateTime.now().toIso8601String().substring(0, 10)) : DateTime.now().toIso8601String().substring(0, 10),
        "end_date":    _endDate,
        // Item 3: optional — "" if the merchant never picked one, matching
        // this app's existing pattern of optional imagery elsewhere.
        // Prefer a freshly picked image; otherwise resend the existing CDN
        // URL unchanged (backend's _cloudinary_upload is a no-op pass-
        // through for it, so this never re-uploads or loses the image).
        "image_url":   _dealImgB64 ?? _dealImgUrl ?? "",
      };
      if (_isEdit) {
        await Api.updateDeal(widget.token, widget.editDeal!["_id"].toString(), payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Deal updated!"), backgroundColor: OffroColors.statusLive));
      } else {
        await Api.addDeal(widget.token, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Deal added!"), backgroundColor: OffroColors.statusLive));
      }
      Navigator.pop(context);
    } catch (e) { setState(() => _msg = friendlyError(e)); }
    if (mounted) setState(() => _loading = false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kMerchantBg,
    appBar: AppBar(title: Text(_isEdit ? "Edit Deal" : "Add Deal", style: const TextStyle(fontWeight: FontWeight.w800)),  ),
    body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.stores.length > 1) ...[
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedStoreId,
          items: widget.stores.map<DropdownMenuItem<String>>((s) =>
            DropdownMenuItem<String>(value: s["_id"]?.toString() ?? "",
              child: Text(s["store_name"]?.toString() ?? "", overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) { final s = widget.stores.firstWhere((s) => s["_id"] == v, orElse: () => <String,dynamic>{}); setState(() { _selectedStoreId = v; _selectedStoreName = s["store_name"] ?? ""; }); _loadStoreExpiry(); } },
          decoration: InputDecoration(labelText: "Store", prefixIcon: const Icon(Icons.store, color: kMerchantMuted, size: 20),
            filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)))),
        const SizedBox(height: 14),
      ] else
        Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: kMerchantLight.withValues(alpha: .4), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [const Icon(Icons.store, color: kMerchantPrimary, size: 18), const SizedBox(width: 8),
            Text(_selectedStoreName, style: const TextStyle(color: kMerchantPrimary, fontWeight: FontWeight.w600))])),
      TextField(controller: _title,
        decoration: InputDecoration(hintText: "Deal Title (e.g. 20% off on all items)", prefixIcon: const Icon(Icons.title, color: kMerchantMuted, size: 20),
          filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)))),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        isExpanded: true,
        value: _category.isEmpty ? null : _category,
        items: _categories.map((e) { final c=(e is Map?e['name']:e).toString(); return DropdownMenuItem<String>(value:c,child:Text(c)); }).toList(),
        onChanged: (v) => setState(() => _category = v ?? ""),
        decoration: InputDecoration(hintText: "Category", prefixIcon: const Icon(Icons.category, color: kMerchantMuted, size: 20),
          filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)))),
      const SizedBox(height: 12),
      TextField(controller: _desc, maxLines: 3,
        decoration: InputDecoration(hintText: "Description (optional)", prefixIcon: const Icon(Icons.description_outlined, color: kMerchantMuted, size: 20),
          filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)))),
      const SizedBox(height: 12),
      // ── Item 3: Deal Image (required) ──
      const Text("Deal Image", style: TextStyle(color: kMerchantMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: _pickDealImage,
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (_dealImgB64 != null || _dealImgUrl != null) ? kMerchantPrimary : kMerchantBorder),
          ),
          child: _dealImgB64 != null
              ? Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(11),
                    child: Image.memory(base64Decode(_dealImgB64!.split(",").last), width: double.infinity, height: 130, fit: BoxFit.cover)),
                  Positioned(top: 6, right: 6, child: GestureDetector(
                    onTap: () => setState(() => _dealImgB64 = null),
                    child: Container(padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 14)))),
                ])
              : (_dealImgUrl != null && _dealImgUrl!.isNotEmpty)
                  ? Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(11),
                        child: Image.network(_dealImgUrl!, width: double.infinity, height: 130, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.broken_image_outlined, color: kMerchantMuted, size: 32),
                            const SizedBox(height: 6),
                            const Text("Tap to replace image", style: TextStyle(color: kMerchantMuted, fontSize: 12)),
                          ]))),
                      Positioned(top: 6, right: 6, child: GestureDetector(
                        onTap: () => setState(() => _dealImgUrl = null),
                        child: Container(padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 14)))),
                    ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_photo_alternate_outlined, size: 32, color: kMerchantAccent),
                      const SizedBox(height: 6),
                      const Text("[ Upload Image ]", style: TextStyle(color: kMerchantMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      _InfoChip("📦 Max 2MB · Required"),
                    ]),
        ),
      ),
      const SizedBox(height: 12),
      InkWell(
        onTap: _pickEndDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(22),
            border: Border.all(color: kMerchantBorder)),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, color: kMerchantMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_endDate.isEmpty ? "Select End Date" : _formatEndDateDisplay(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _endDate.isEmpty ? kMerchantMuted : kMerchantText, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (_storeExpiryDate != null) ...[
              const SizedBox(width: 8),
              Text("Max: ${_storeExpiryDisplay()}",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(color: kMerchantMuted, fontSize: 10)),
            ],
          ]))),
      const SizedBox(height: 20),
      SizedBox(height: 50, child: ElevatedButton(
        onPressed: _loading ? null : _save,
        style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: kMerchantPrimary, shape: const StadiumBorder()),
        child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(_isEdit ? "Save Changes" : "Add Deal", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)))),
      if (_msg.isNotEmpty) ...[const SizedBox(height: 10),
        Text(_msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontSize: 13))],
      const SizedBox(height: 24),
    ])),
  );

}


// ── My Banners video thumbnail: tap to play/pause in place (80x80, muted) ──
class _BannerThumbVideo extends StatefulWidget {
  final String url;
  final String initial;
  const _BannerThumbVideo({required this.url, required this.initial});
  @override State<_BannerThumbVideo> createState() => _BannerThumbVideoState();
}

class _BannerThumbVideoState extends State<_BannerThumbVideo> {
  VideoPlayerController? _c;
  bool _loading = false;
  bool _failed = false;

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      VideoPlayerController c;
      if (widget.url.startsWith("data:video")) {
        final bytes = base64Decode(widget.url.substring(widget.url.indexOf(",") + 1));
        c = VideoPlayerController.contentUri(Uri.dataFromBytes(bytes, mimeType: "video/mp4"));
      } else {
        c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      }
      _c = c;
      await c.initialize();
      await c.setVolume(0);
      await c.setLooping(true);
      await c.play();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint("[MyBanners] video thumb failed: $e");
      try { await _c?.dispose(); } catch (_) {}
      _c = null;
      if (mounted) setState(() { _loading = false; _failed = true; });
    }
  }

  void _onTap() {
    final c = _c;
    if (c == null || !c.value.isInitialized) {
      if (!_loading) _init();
      return;
    }
    setState(() { c.value.isPlaying ? c.pause() : c.play(); });
  }

  @override void dispose() { _c?.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    if (_failed) {
      return Container(width: 80, height: 80, color: kMerchantAccent,
        child: Center(child: Text(widget.initial, style: const TextStyle(color: kMerchantPrimary, fontWeight: FontWeight.w900, fontSize: 22))));
    }
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final playing = ready && c!.value.isPlaying;
    return GestureDetector(
      onTap: _onTap,
      child: SizedBox(width: 80, height: 80, child: Stack(alignment: Alignment.center, children: [
        if (ready)
          SizedBox(width: 80, height: 80, child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge,
            child: SizedBox(width: c!.value.size.width, height: c.value.size.height, child: VideoPlayer(c))))
        else
          Container(width: 80, height: 80, color: Colors.black87),
        if (_loading)
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        else if (!playing)
          const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
      ])),
    );
  }
}

// ── Banner Video Tile (merchant banner list) ──────────────────────────────
class _BannerVideoTile extends StatefulWidget {
  final String url;
  const _BannerVideoTile({required this.url});
  @override State<_BannerVideoTile> createState() => _BannerVideoTileState();
}

class _BannerVideoTileState extends State<_BannerVideoTile> {
  VideoPlayerController? _vpc;
  bool _initialized = false;

  @override void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    if (widget.url.startsWith("data:video")) {
      try {
        final commaIdx = widget.url.indexOf(",");
        if (commaIdx == -1) return;
        final bytes = base64Decode(widget.url.substring(commaIdx + 1));
        _vpc = VideoPlayerController.contentUri(
          Uri.dataFromBytes(bytes, mimeType: "video/mp4"))
          ..initialize().then((_) {
            if (mounted) setState(() => _initialized = true);
          }).catchError((_) {});
      } catch (_) {}
      return;
    }
    _vpc = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      }).catchError((_) {});
  }

  @override void dispose() {
    _vpc?.dispose();
    super.dispose();
  }

  void _openFullScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenVideoPage(url: widget.url)));
  }

  @override Widget build(BuildContext context) {
    if (_initialized && _vpc != null && _vpc!.value.isInitialized) {
      return GestureDetector(
        onTap: _openFullScreen,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: double.infinity, height: 120,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _vpc!.value.size.width,
                height: _vpc!.value.size.height,
                child: VideoPlayer(_vpc!),
              ),
            ),
          ),
          // Play icon overlay
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
          ),
        ]),
      );
    }
    // Loading placeholder
    return Container(
      width: double.infinity, height: 120,
      color: OffroColors.primary,
      child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
    );
  }
}

// ── Full Screen Video Player ──────────────────────────────────────────────
class _FullScreenVideoPage extends StatefulWidget {
  final String url;
  const _FullScreenVideoPage({required this.url});
  @override State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  VideoPlayerController? _vpc;
  bool _initialized = false;

  @override void initState() {
    super.initState();
    if (widget.url.startsWith("data:video")) {
      try {
        final commaIdx = widget.url.indexOf(",");
        if (commaIdx != -1) {
          final bytes = base64Decode(widget.url.substring(commaIdx + 1));
          _vpc = VideoPlayerController.contentUri(
            Uri.dataFromBytes(bytes, mimeType: "video/mp4"))
            ..initialize().then((_) {
              if (mounted) { setState(() => _initialized = true); _vpc!.play(); }
            }).catchError((_) {});
        }
      } catch (_) {}
      return;
    }
    _vpc = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) { setState(() => _initialized = true); _vpc!.play(); }
      }).catchError((_) {});
  }

  @override void dispose() {
    _vpc?.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(children: [
      Center(child: _initialized && _vpc != null && _vpc!.value.isInitialized
        ? GestureDetector(
            onTap: () { setState(() { _vpc!.value.isPlaying ? _vpc!.pause() : _vpc!.play(); }); },
            child: AspectRatio(aspectRatio: _vpc!.value.aspectRatio, child: VideoPlayer(_vpc!)))
        : const CircularProgressIndicator(color: Colors.white)),
      Positioned(top: 0, left: 0, right: 0,
        child: SafeArea(child: Padding(padding: const EdgeInsets.all(8),
          child: Align(alignment: Alignment.topLeft,
            child: GestureDetector(onTap: () => Navigator.pop(context),
              child: Container(width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20))))))),
    ]),
  );

}


// ══════════════════════════════════════════════════════════════════════════════
// MERCHANT PRIVACY POLICY PAGE — with Read More + Delete Account flow
// ══════════════════════════════════════════════════════════════════════════════
class MerchantPrivacyPolicyPage extends StatefulWidget {
  final String token;
  const MerchantPrivacyPolicyPage({required this.token, super.key});
  @override State<MerchantPrivacyPolicyPage> createState() => _MerchantPrivacyPolicyPageState();
}

class _MerchantPrivacyPolicyPageState extends State<MerchantPrivacyPolicyPage> {
  String _content = "";
  bool _loading = true;
  bool _expanded = false;

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await Api.fetchPolicy("privacy");
    if (mounted) setState(() { _content = c; _loading = false; });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: AppBar(
         
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text("Privacy Policy", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kMerchantBorder),
        ),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: kMerchantPrimary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_content.isEmpty)
                const Text("Privacy policy content is being updated. Please check back later.",
                  style: TextStyle(color: kMerchantMuted, fontSize: 14))
              else ...[
                Text(
                  _expanded ? _content : (_content.length > 280 ? _content.substring(0, 280) + "..." : _content),
                  style: const TextStyle(fontSize: 14, color: kMerchantText, height: 1.6),
                ),
                if (_content.length > 280) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? "Read Less" : "Read More",
                      style: const TextStyle(color: kMerchantPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 32),
              const Divider(height: 1, color: kMerchantBorder),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder:(_)=>MerchantDeleteAccountReasonPage(token: widget.token))),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_remove_rounded, color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Request to delete my account",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.red)),
                        const SizedBox(height: 2),
                        Text("All your stores, products & data will be permanently removed",
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                      ],
                    )),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.red),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
            ]),
          ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// DELETE ACCOUNT — Reason selection page (Merchant app)
// ══════════════════════════════════════════════════════════════════════════════
class MerchantDeleteAccountReasonPage extends StatefulWidget {
  final String token;
  const MerchantDeleteAccountReasonPage({required this.token, super.key});
  @override State<MerchantDeleteAccountReasonPage> createState() => _MerchantDeleteAccountReasonPageState();
}

class _MerchantDeleteAccountReasonPageState extends State<MerchantDeleteAccountReasonPage> {
  String? _selectedReason;
  final _reasons = [
    "I no longer run my business",
    "I have privacy concerns",
    "I have a duplicate account",
    "The app is not working properly for me",
    "Too many notifications or irrelevant content",
    "Other",
  ];

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: AppBar(
         
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text("Delete Account", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kMerchantBorder),
        ),
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(
              "Once your account is deleted, your stores, products, banners and data cannot be retrieved. Signing up again will create a new account.",
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900, height: 1.4),
            )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text("Select a reason for deleting your account",
              style: TextStyle(fontSize: 13, color: kMerchantMuted, fontWeight: FontWeight.w500)),
          ),
        ),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _reasons.length,
          itemBuilder: (ctx, i) {
            final r = _reasons[i];
            final selected = _selectedReason == r;
            return GestureDetector(
              onTap: () => setState(() => _selectedReason = r),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? kMerchantPrimary.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? kMerchantPrimary : kMerchantBorder),
                ),
                child: Row(children: [
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: selected ? kMerchantPrimary : kMerchantMuted, size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? kMerchantPrimary : kMerchantText,
                    )),
                  ),
                ]),
              ),
            );
          },
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedReason == null ? null : () => _showConfirmDialog(),
              icon: const Icon(Icons.delete_forever_rounded, size: 20),
              label: const Text("Submit Delete Request", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(elevation: 0, 
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.red.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Account?", style: TextStyle(fontWeight: FontWeight.w800, color: kMerchantText)),
        content: const Text(
          "Your merchant account will be marked for deletion. You will be logged out immediately and cannot log in again.\n\nOnce deleted, your stores, products and data cannot be retrieved. Are you absolutely sure?",
          style: TextStyle(fontSize: 14, color: kMerchantText, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: kMerchantMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitDeletion();
            },
            style: ElevatedButton.styleFrom(elevation: 0, 
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text("Yes, Delete", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDeletion() async {
    try {
      await Api.requestDeleteAccount(widget.token, _selectedReason!);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Deletion Requested", style: TextStyle(fontWeight: FontWeight.w800, color: kMerchantText)),
          content: const Text(
            "Your account deletion request has been submitted. You have been logged out.",
            style: TextStyle(fontSize: 14, color: kMerchantText),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await Prefs.clear(keepMode: false);
                Api.clearCache();
                if (!ctx.mounted) return;
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (_) => false,
                );
              },
              style: ElevatedButton.styleFrom(elevation: 0, 
                backgroundColor: kMerchantPrimary, foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[MerchantAccount] delete request error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit: ${friendlyError(e)}"),
          backgroundColor: Colors.red),
      );
    }
  }
}
