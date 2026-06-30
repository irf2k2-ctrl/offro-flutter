// lib/screens/favorites/favorites_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';
import '../store/store_detail_page.dart';
import '../../core/widgets/store_cards.dart';

PageRoute _offroRoute(Widget w) => MaterialPageRoute(builder: (_) => w);


class FavoritesPage extends StatefulWidget {
  final String token;
  const FavoritesPage({super.key,required this.token});
  @override State<FavoritesPage> createState()=>_FavoritesState();
}
class _FavoritesState extends State<FavoritesPage>{
  List _favs=[]; bool _loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try{final d=await Api.getFavorites(widget.token);if(mounted)setState((){_favs=d;_loading=false;});}
    catch(_){if(mounted)setState(()=>_loading=false);}
  }
  @override Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(slivers: [
        // Glossy gradient app bar
        SliverAppBar(
          expandedHeight: 110,
          pinned: true,
          backgroundColor: Colors.white,
          foregroundColor: kText,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text("My Favourites",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: kText)),
            background: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Stack(children: [
                // Soft bottom border shine
                Positioned(top: 0, left: 0, right: 0, child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white.withValues(alpha: .0)],
                    ),
                  ),
                )),
                // Decorative heart icon
                const Positioned(right: 20, bottom: 16, child:
                  Icon(Icons.favorite_rounded, color: Colors.white12, size: 72)),
              ]),
            ),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)))
        else if (_favs.isEmpty)
          SliverFillRemaining(
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFFCDEBD6), Color(0xFFA9CDBA)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF3E5F55).withValues(alpha: .2), blurRadius: 18, offset: const Offset(0,6))],
                ),
                child: const Icon(Icons.favorite_border_rounded, color: Color(0xFF3E5F55), size: 44),
              ),
              const SizedBox(height: 20),
              const Text("No favourites yet",
                style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text("Tap ♡ on any store to save it here",
                style: TextStyle(color: kMuted, fontSize: 13)),
            ])),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(14),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => GestureDetector(
                  onTap: () => Navigator.push(ctx, _offroRoute(
                    StoreDetailPage(store: Map<String,dynamic>.from(_favs[i] as Map), token: widget.token))),
                  child: GridStoreCard(store: Map<String,dynamic>.from(_favs[i] as Map)),
                ),
                childCount: _favs.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────── PROMO SLIDER CARD ───────────────────────
