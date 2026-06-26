// lib/screens/store/store_detail_page.dart
//
// OFFRO Store Detail Page V3
// Tabbed layout: About | Products | Reviews | Rewards
// Location section removed (info shown in header).
//
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import 'widgets/store_header.dart';
import 'widgets/store_highlights.dart';
import 'widgets/store_offers_section.dart';
import 'widgets/store_products_section.dart';
import 'widgets/reward_points_section.dart';
import 'widgets/store_about_section.dart';
import 'widgets/store_reviews_section.dart';
import 'widgets/bottom_action_bar.dart';

class StoreDetailPage extends StatefulWidget {
  final Map store;
  final String token;
  final String userName;
  // FIX ISSUE-2: callback to navigate to ProductDetailsPage (defined in main.dart)
  final void Function(Map<String, dynamic> product, String token)? onProductTap;

  const StoreDetailPage({
    super.key,
    required this.store,
    required this.token,
    this.userName = '',
    this.onProductTap,
  });

  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _store = {};
  bool  _loading   = true;
  bool  _isFav     = false;
  int   _imgPage   = 0;
  int   _walletPts = 0;
  final PageController _imgPc = PageController();

  late TabController _tabCtrl;
  static const _tabs = ['About', 'Products', 'Reviews', 'Rewards'];

  @override
  void initState() {
    super.initState();
    _store = Map<String, dynamic>.from(widget.store);
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _imgPc.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    try {
      final id = widget.store['_id']?.toString() ?? '';
      if (id.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final hasToken = widget.token.isNotEmpty;
      final results = await Future.wait([
        Api.fetchStoreDetail(id),
        hasToken ? Api.isFavorite(widget.token, id) : Future.value(false),
        hasToken ? Api.getWallet(widget.token) : Future.value(<String,dynamic>{}),
      ]);

      final full   = results[0] as Map<String, dynamic>;
      final isFav  = results[1] as bool;
      final wallet = results[2] as Map<String, dynamic>;

      final savedDist     = _store['distance_km'];
      final savedBadge    = _store['badge'];
      final savedIsNew    = _store['is_new_in_town'];
      if (mounted) {
        setState(() {
          _store = Map<String, dynamic>.from(full);
          if (savedDist  != null) _store['distance_km'] = savedDist;
          // Preserve badge + is_new_in_town from initial store data if API response omits them
          if ((full['badge'] == null || full['badge'].toString().isEmpty) && savedBadge != null) {
            _store['badge'] = savedBadge;
          }
          // Preserve is_new_in_town flag so "Newly Added" badge stays visible after detail load
          if ((full['is_new_in_town'] == null || full['is_new_in_town'] == false)
              && (savedIsNew == true || widget.store['is_new_in_town'] == true)) {
            _store['is_new_in_town'] = true;
          }
          _isFav    = isFav;
          _walletPts = (wallet['points'] as num?)?.toInt() ?? 0;
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _allImages {
    final imgs = (_store['images'] as List?)
            ?.map((x) => x.toString()).toList() ?? [];
    final main = (_store['image_url']?.toString() ?? '').isNotEmpty
        ? _store['image_url'].toString()
        : _store['image_thumb']?.toString() ??
          _store['image']?.toString() ?? '';
    final img2 = _store['image2']?.toString() ?? '';
    final resolve =
        (String u) => u.startsWith('/') ? '$kBaseUrl$u' : u;
    final all = [
      if (main.isNotEmpty) resolve(main),
      if (img2.isNotEmpty) resolve(img2),
      ...imgs.map(resolve),
    ];
    final seen = <String>{};
    return all
        .where((u) => u.isNotEmpty && seen.add(u))
        .toList();
  }


  Future<void> _toggleFav() async {
    final id = _store['_id']?.toString() ?? '';
    if (id.isEmpty || widget.token.isEmpty) return;
    final prev = _isFav;
    setState(() => _isFav = !_isFav);
    try {
      await Api.toggleFavorite(widget.token, id);
    } catch (_) {
      if (mounted) setState(() => _isFav = prev);
    }
  }

  Future<void> _share() async {
    final name    = _store['store_name']?.toString() ?? '';
    final area    = _store['area']?.toString() ?? '';
    final city    = _store['city']?.toString() ?? '';
    final id      = _store['_id']?.toString() ?? '';
    final offer   = _store['offer']?.toString() ?? '';
    final appLink = 'https://offro.app/store/$id';
    final text    = [
      '🏪 $name',
      '📍 $area${city.isNotEmpty ? ", $city" : ""}',
      if (offer.isNotEmpty) '🎁 $offer',
      'Discover deals & earn reward points on OFFRO!',
      appLink,
    ].join('\n');
    await Share.share(text, subject: 'Check out $name on OFFRO');
  }

  @override
  Widget build(BuildContext context) {
    final allImgs  = _allImages;
    // FIX 8: Show deals from initial store data immediately — don't wait for _loading
    final deals    = ((_store['deals'] as List?) ?? [])
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList();
    final products = _loading
        ? <Map<String, dynamic>>[]
        : ((_store['products'] as List?) ?? [])
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
    final visitPts = (_store['visit_points'] as num?)?.toInt() ?? 0;
    final storeId  = _store['_id']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: Stack(children: [
        CustomScrollView(slivers: [
          // ── HERO HEADER ──
          SliverToBoxAdapter(
            child: StoreHeader(
              store:         _store,
              images:        allImgs,
              imgPage:       _imgPage,
              imgController: _imgPc,
              isFav:         _isFav,
              onFavToggle:   _toggleFav,
              onShare:       _share,
              onBack:        () => Navigator.pop(context),
            ),
          ),

          // ── HIGHLIGHTS ──
          SliverToBoxAdapter(
            child: _loading
                ? const SizedBox.shrink()
                : StoreHighlights(store: _store),
          ),

          // ── TODAY'S OFFERS (FIX ISSUE-5: only render after load to prevent layout flicker) ──
          if (!_loading && deals.isNotEmpty)
            SliverToBoxAdapter(
              child: StoreOffersSection(
                      deals:     deals,
                      storeName: _store['store_name']?.toString() ?? '',
                      storeArea: _store['area']?.toString() ?? '',
                      storeCity: _store['city']?.toString() ?? '',
                      storeId:   storeId,
                    ),
            ),

          // ── TABS: About · Products · Reviews · Rewards ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab bar
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabCtrl,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: kPrimary,
                      unselectedLabelColor: kMuted,
                      labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      indicatorColor: kPrimary,
                      indicatorWeight: 2.5,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: kBorder,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      tabs: _tabs
                          .map((t) => Tab(
                              text: t,
                              height: 40))
                          .toList(),
                    ),
                  ),
                  // Tab content (non-lazy — renders inline)
                  _TabContent(
                    tabController: _tabCtrl,
                    store:      _store,
                    products:   products,
                    visitPts:   visitPts,
                    walletPts:  _walletPts,
                    token:      widget.token,
                    userName:   widget.userName,
                    storeId:    storeId,
                    loading:    _loading,
                    onProductTap: widget.onProductTap,
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
              child: SizedBox(height: 100)),
        ]),

        // ── STICKY BOTTOM BAR (Scan QR if rewards exist) ──
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: BottomActionBar(
            store:       _store,
            token:       widget.token,
            visitPoints: 0,
          ),
        ),
      ]),
    );
  }

  Widget _skelBox(double w, double h, {double r = 12}) =>
      Container(
        width: w,
        height: h,
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFD1E0DA),
          borderRadius: BorderRadius.circular(r),
        ),
      );

  Widget _skelSection() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Container(
            width: 120,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFD1E0DA),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),
          _skelBox(double.infinity, 72, r: 16),
        ]),
      );
}

// ─── Tab Content Widget ───────────────────────────────────────
class _TabContent extends StatefulWidget {
  final TabController tabController;
  final Map<String, dynamic> store;
  final List<Map<String, dynamic>> products;
  final int visitPts;
  final int walletPts;
  final String token;
  final String userName;
  final String storeId;
  final bool loading;
  final void Function(Map<String, dynamic>, String)? onProductTap;

  const _TabContent({
    required this.tabController,
    required this.store,
    required this.products,
    required this.visitPts,
    required this.walletPts,
    required this.token,
    required this.userName,
    required this.storeId,
    required this.loading,
    this.onProductTap,
  });

  @override
  State<_TabContent> createState() => _TabContentState();
}

class _TabContentState extends State<_TabContent> {
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    widget.tabController.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (mounted && !widget.tabController.indexIsChanging) {
      setState(() => _selected = widget.tabController.index);
    }
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_selected) {
      case 0:
        return widget.loading
            ? _skelPad()
            : StoreAboutSection(store: widget.store);
      case 1:
        return widget.loading
            ? _skelPad()
            : StoreProductsSection(
              products: widget.products,
              token: widget.token,
              onProductTap: widget.onProductTap != null
                  ? (p) => widget.onProductTap!(p, widget.token)
                  : null,
            );
      case 2:
        return widget.storeId.isNotEmpty
            ? StoreReviewsSection(
                storeId:  widget.storeId,
                token:    widget.token,
                userName: widget.userName,
              )
            : const SizedBox.shrink();
      case 3:
        return RewardPointsSection(
          visitPoints:   widget.visitPts,
          token:         widget.token,
          currentPoints: widget.walletPts,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _skelPad() => Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFD1E0DA),
          borderRadius: BorderRadius.circular(12),
        ),
      );
}