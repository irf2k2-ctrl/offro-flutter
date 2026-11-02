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
import '../../core/utils/navigation.dart';
import '../../core/design/design.dart';


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
    // Figma design system: Manrope + Lora accent, #FDFBF6 background, mint
    // empty state. Loading / empty / grid / navigation logic is unchanged.
    return OffroFontScope(child: Scaffold(
      backgroundColor: OffroColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: OffroScreenHeader(
            eyebrow: "Saved for later",
            title: "My Favourites",
            description: _loading || _favs.isEmpty
                ? null
                : "${_favs.length} ${_favs.length == 1 ? 'place' : 'places'} you love, all in one spot.",
            showBack: true,
          )),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: OffroColors.primary, strokeWidth: 2)))
          else if (_favs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 88, height: 88,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: OffroColors.mint, shape: BoxShape.circle),
                    child: const OffroIcon(OffroIcons.heart, size: 38, color: OffroColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text("No favourites yet", style: OffroText.title.copyWith(fontSize: 20)),
                  const SizedBox(height: 8),
                  Text("Tap the heart on any store to save it here",
                    textAlign: TextAlign.center,
                    style: OffroText.bodySmall.copyWith(fontSize: 13, color: OffroColors.textMuted)),
                ]),
              )),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 20, OffroSpacing.gutter, 40),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => GestureDetector(
                    onTap: () => Navigator.push(ctx, appRoute(
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
      ),
    ));
  }
}

// ─────────────────────── PROMO SLIDER CARD ───────────────────────
