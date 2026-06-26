import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ─────────────────── OFFRO COLORS (local re-declarations) ───────────────────
const _kPrimary = Color(0xFF3E5F55);
const _kAccent  = Color(0xFFA9CDBA);
const _kLight   = Color(0xFFCDEBD6);
const _kBeige   = Color(0xFFE7D7C8);
const _kBg      = Color(0xFFFDFBF6);
const _kText    = Color(0xFF2c3e35);
const _kMuted   = Color(0xFF6b8c7e);

// ═══════════════════════════════════════════════════════════════
// HomeHeroSection — 3-tile premium discovery section
// Placed immediately after the Search Bar, before Explore Stores.
//
// Layout (230px tall):
//   LEFT  68%  — "Explore <City>" hero card
//   RIGHT 32%  — two stacked tiles:
//               TOP:    "Hot Deals"     → opens Discover Products
//               BOTTOM: "Popular Areas" → opens Areas screen
// ═══════════════════════════════════════════════════════════════

class HomeHeroSection extends StatelessWidget {
  /// City name to display on the left hero card
  final String city;

  /// Number of active vouchers/deals (shown in Hot Deals tile)
  final int dealCount;

  /// Maximum discount available (e.g. "70% OFF"). Pass "" to omit.
  final String maxDiscount;

  /// Number of distinct areas
  final int areaCount;

  /// Total number of stores across all areas
  final int storeCount;

  /// Callback when user taps the left hero card (opens city/store list)
  final VoidCallback? onExploreCity;

  /// Callback when "Hot Deals" tile is tapped → scroll to Discover Products
  final VoidCallback? onHotDealsTap;

  /// Callback when "Popular Areas" tile is tapped → scroll to / open areas
  final VoidCallback? onAreasTap;

  /// Optional override image URL for the left hero card (set from admin)
  final String? heroImageUrl;

  const HomeHeroSection({
    super.key,
    required this.city,
    this.dealCount = 0,
    this.maxDiscount = "",
    this.areaCount = 0,
    this.storeCount = 0,
    this.onExploreCity,
    this.onHotDealsTap,
    this.onAreasTap,
    this.heroImageUrl,
  });

  // Bundled AI Ballari image (used when no admin override URL is set)
  static const _defaultHeroUrl =
      "https://media.base44.com/images/public/69dc008cb5876dcb8680be38/37d9f2b4a_generated_image.png";

  @override
  Widget build(BuildContext context) {
    const sectionHeight = 230.0;
    const gap           = 10.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: SizedBox(
        height: sectionHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─────────────── LEFT: Explore City hero card (68%) ───────────────
            Expanded(
              flex: 68,
              child: _HeroLeftCard(
                city: city,
                imageUrl: heroImageUrl?.isNotEmpty == true
                    ? heroImageUrl!
                    : _defaultHeroUrl,
                onTap: onExploreCity,
              ),
            ),
            const SizedBox(width: gap),
            // ─────────────── RIGHT: two stacked tiles (32%) ───────────────────
            Expanded(
              flex: 32,
              child: Column(
                children: [
                  // TOP tile — Hot Deals
                  Expanded(
                    child: _HotDealsCard(
                      dealCount:   dealCount,
                      maxDiscount: maxDiscount,
                      onTap:       onHotDealsTap,
                    ),
                  ),
                  const SizedBox(height: gap),
                  // BOTTOM tile — Popular Areas (offset up by ~10px for stagger)
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: SizedBox(
                      height: (sectionHeight - gap) / 2 + 8,
                      child: _PopularAreasTile(
                        areaCount:  areaCount,
                        storeCount: storeCount,
                        onTap:      onAreasTap,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// LEFT CARD — Explore <City>
// ═══════════════════════════════════════════════════════
class _HeroLeftCard extends StatelessWidget {
  final String city;
  final String imageUrl;
  final VoidCallback? onTap;
  const _HeroLeftCard({
    required this.city,
    required this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .14),
              blurRadius: 22,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: _kPrimary.withValues(alpha: .10),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background image ──
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                placeholder: (_, __) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2c4a3e), _kPrimary],
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2c4a3e), _kPrimary],
                    ),
                  ),
                ),
              ),

              // ── Cinematic gradient overlay ──
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: .52),
                        Colors.black.withValues(alpha: .82),
                      ],
                      stops: const [0.0, 0.35, 0.70, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Top-left: glossy shine strip ──
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: .18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom content ──
              Positioned(
                left: 14, right: 14, bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // City label pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .30),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        city.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Main title
                    Text(
                      "Explore $city",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(blurRadius: 12, color: Colors.black87),
                          Shadow(blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Subtitle
                    Text(
                      "Top stores, offers & local discoveries",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        shadows: const [Shadow(blurRadius: 6, color: Colors.black45)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // CTA row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .18),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                "Explore",
                                style: TextStyle(
                                  color: _kPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, color: _kPrimary, size: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TOP-RIGHT: Hot Deals tile
// ═══════════════════════════════════════════════════════
class _HotDealsCard extends StatelessWidget {
  final int dealCount;
  final String maxDiscount;
  final VoidCallback? onTap;
  const _HotDealsCard({
    required this.dealCount,
    required this.maxDiscount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B35), Color(0xFFFF9B35)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: .35),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Glossy top strip
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: .28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Fire icon
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .25),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text("🔥", style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Hot Deals",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (dealCount > 0)
                          Text(
                            "$dealCount Active",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .90),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (maxDiscount.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "Up to $maxDiscount",
                              style: const TextStyle(
                                color: Color(0xFFFF6B35),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// BOTTOM-RIGHT: Popular Areas tile
// ═══════════════════════════════════════════════════════
class _PopularAreasTile extends StatelessWidget {
  final int areaCount;
  final int storeCount;
  final VoidCallback? onTap;
  const _PopularAreasTile({
    required this.areaCount,
    required this.storeCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3E5F55), Color(0xFF2c4a3e)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3E5F55).withValues(alpha: .35),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Glossy top strip
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: .22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Map pin icon
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text("📍", style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Popular Areas",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (areaCount > 0)
                          Text(
                            "$areaCount Areas",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .88),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (storeCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            "$storeCount Stores",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .70),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
