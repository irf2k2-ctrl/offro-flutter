// lib/screens/store/widgets/store_offers_section.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/base64_image.dart' show decodeBase64ImageCached;
import 'store_header.dart' show FullScreenImageViewer;

// ─────────────────────────────────────────────────────────────────────────────
// Round 12 (Task 5): shared full-screen deal-gallery opener. Previously
// this Navigator.push + FullScreenImageViewer construction lived only
// inside StoreOffersSection (Today's Offers, inside Store Detail). Home's
// "Hot Deals" list (_AllDealsScreen in main.dart) now needs to open the
// exact same full-screen deal viewer directly — rather than navigating to
// Store Detail first — so this is pulled out to a top-level function both
// call sites share, instead of duplicating the gallery-opening logic.
// ─────────────────────────────────────────────────────────────────────────────
/// Opens the swipeable full-screen deal gallery. [dealsWithImages] is the
/// list to swipe across — already filtered to deals that have an image,
/// since a deal without one can't be shown in an image gallery.
/// [tappedDeal] must be the SAME Map instance as one of
/// [dealsWithImages]'s entries (not a copy/clone) — the starting index is
/// resolved by object identity via `indexOf`, because deal payloads from
/// the backend (both Store Detail's `get_store()` and the city-wide
/// `/deals/all`) don't reliably carry an `_id` to match on instead.
// [fallbackSellerName]: StoreOffersSection's deals don't carry a per-deal
// store_name field (they all belong to the one store already shown on that
// page), so its call site passes the page's own storeName as a fallback.
// Home's "Hot Deals" list deals DO carry their own store_name per deal, so
// that call site doesn't need to pass this.
void openDealGallery(BuildContext context, List<Map<String, dynamic>> dealsWithImages,
    Map<String, dynamic> tappedDeal, {String fallbackSellerName = ''}) {
  final startIndex = dealsWithImages.indexOf(tappedDeal);
  Navigator.push(
    context,
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => FullScreenImageViewer(
        images: dealsWithImages.map((d) => d['image_url'].toString()).toList(),
        initialIndex: startIndex < 0 ? 0 : startIndex,
        // QA fix: add a "Seller: <name>" line below the title — sourced from
        // the actual deal/store/merchant data (never hard-coded), falling
        // back to the page-level store name when the deal itself doesn't
        // carry one, and omitted entirely when neither is available.
        bottomOverlays: dealsWithImages.map((d) {
          final t = d['title']?.toString().trim() ?? '';
          final sellerRaw = (d['store_name'] ?? d['merchant_name'] ?? d['seller'] ?? '').toString().trim();
          final seller = sellerRaw.isNotEmpty ? sellerRaw : fallbackSellerName.trim();
          if (t.isEmpty && seller.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (t.isNotEmpty)
                Text(t,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              if (seller.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("Seller: $seller",
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
            ],
          );
        }).toList(),
      ),
    ),
  );
}

class StoreOffersSection extends StatelessWidget {
  final List<Map<String, dynamic>> deals;
  final String storeName;
  final String storeArea;
  final String storeCity;
  final String storeId;
  // Round 7 (Issue 4): true while StoreDetailPage's real fetchStoreDetail()
  // call is still in flight. See the skeleton block in build() below for why
  // this exists — defaults to false so this widget's behavior is unchanged
  // for any other/future caller that doesn't pass it.
  final bool loading;

  const StoreOffersSection({
    super.key,
    required this.deals,
    required this.storeName,
    this.storeArea = '',
    this.storeCity = '',
    this.storeId = '',
    this.loading = false,
  });


  // Round 10: the deals that actually have an image — only these can be
  // opened in the full-screen gallery (a deal without an image renders the
  // decorative fallback card below, which has no tap target, unchanged).
  List<Map<String, dynamic>> get _dealsWithImages =>
      deals.where((d) => (d['image_url']?.toString() ?? '').isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Section header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            const Text("Today's Offers",
                style: TextStyle(
                    color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (deals.isNotEmpty && !loading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${deals.length} deal${deals.length == 1 ? "" : "s"}',
                  style: const TextStyle(
                      color: kPrimary, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
          ]),
        ),

        // ── Loading skeleton (Round 7, Issue 4) ──
        // Root cause of "old/default Today's Offers card flashes before the
        // current deal images load": StoreDetailPage renders this section
        // immediately in initState() using widget.store['deals'], which for
        // navigation from Home is a SYNTHESIZED placeholder deal built from
        // the home list card's plain-text offer summary (see
        // _enrichStoreForDetail() in home_screen.dart) — it never has an
        // image_url, so it always fell into the pre-Round-6 decorative
        // "green circles" card below. Once the real fetchStoreDetail() API
        // call resolved, _store['deals'] was replaced with the real deals
        // (with real image_url), and the section re-rendered with the new
        // image card — producing the reported flash from the generic
        // decorative card to the real one.
        // Fix: while the real fetch is in flight, show a proper loading
        // skeleton instead of rendering (possibly placeholder/mismatched)
        // deal content at all. This never shows stale or synthesized
        // content, and — because fetchStoreDetail() is typically fast — adds
        // no perceptible delay versus the immediate-render behavior it
        // replaces. The synthesized placeholder in _enrichStoreForDetail()
        // is left in place (harmless/unused here) in case any other caller
        // still relies on it.
        if (loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SizedBox(
              height: 210,
              child: Row(children: [
                for (var i = 0; i < 2; i++) ...[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: kLight.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBorder, width: 1),
                      ),
                    ),
                  ),
                  if (i == 0) const SizedBox(width: 12),
                ],
              ]),
            ),
          )
        // ── Empty state ──
        else if (deals.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: kLight.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder, width: 1),
              ),
              child: Column(children: [
                Icon(Icons.local_offer_outlined, color: kAccent, size: 32),
                const SizedBox(height: 8),
                const Text('Offers coming soon',
                    style: TextStyle(
                        color: kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          )
        else
          // ── Horizontal scrollable light-theme offer cards ──
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              itemCount: deals.length,
              itemBuilder: (ctx, idx) {
                final d       = deals[idx];
                final title   = d['title']?.toString() ?? '';
                final desc    = d['description']?.toString() ?? '';
                final disc    = d['discount']?.toString() ?? '0';
                final discInt = int.tryParse(disc) ?? 0;
                // Round 6 (Issue 2): the deal's own uploaded image, if any.
                // Root cause of "image not showing" was purely here — the
                // backend (routers/public.py) already returned image_url in
                // this same deals list (added in Round 5), but this card
                // never read it and always rendered the generic decorative
                // design. Falls back to that exact unchanged design when
                // empty, so deals without an image keep working as before.
                final imageUrl = d['image_url']?.toString() ?? '';

                if (imageUrl.isNotEmpty) {
                  return GestureDetector(
                    // Round 10: opens the swipeable gallery across every
                    // deal (for this store) that has an image, starting at
                    // the exact deal tapped — replaces the old single-image
                    // viewer.
                    onTap: () => openDealGallery(ctx, _dealsWithImages, d, fallbackSellerName: storeName),
                    child: Container(
                      width: 210,
                      height: 210,
                      margin: EdgeInsets.only(right: idx < deals.length - 1 ? 12 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kBorder, width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: kPrimary.withValues(alpha: .08),
                              blurRadius: 16,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // ── Deal image fills the card ──
                            imageUrl.startsWith('data:image')
                                ? Builder(builder: (_) {
                                    try {
                                      return Image.memory(
                                          decodeBase64ImageCached(imageUrl),
                                          fit: BoxFit.cover);
                                    } catch (_) {
                                      return Container(color: kLight);
                                    }
                                  })
                                : CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: kLight),
                                    errorWidget: (_, __, ___) => Container(color: kLight,
                                        child: const Icon(Icons.broken_image_outlined, color: kMuted, size: 32)),
                                  ),
                            // ── Bottom scrim for text readability ──
                            Positioned(
                              left: 0, right: 0, bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: .72)],
                                  ),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                  // Round 10: validity/date text removed from
                                  // the deal card per spec — image, discount
                                  // badge and title only.
                                  if (title.isNotEmpty)
                                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                                ]),
                              ),
                            ),
                            // ── Discount % chip, top-left ──
                            if (discInt > 0)
                              Positioned(
                                top: 10, left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: kPrimary,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('$discInt% OFF',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Container(
                  width: 210,
                  margin: EdgeInsets.only(right: idx < deals.length - 1 ? 12 : 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                          color: kPrimary.withValues(alpha: .08),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // ── Decorative green circles (background) ──
                      Positioned(
                        top: -30, right: -30,
                        child: Container(
                          width: 110, height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                kPrimary.withValues(alpha: .13),
                                kPrimary.withValues(alpha: .0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -20, left: -20,
                        child: Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                kAccent.withValues(alpha: .18),
                                kAccent.withValues(alpha: .0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 70, right: 10,
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kLight.withValues(alpha: .6),
                          ),
                        ),
                      ),

                      // ── Card content ──
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            // Big centered % badge
                            if (discInt > 0) ...[
                              Center(
                                child: Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        kPrimary.withValues(alpha: .12),
                                        kAccent.withValues(alpha: .18),
                                      ],
                                    ),
                                    border: Border.all(
                                        color: kPrimary.withValues(alpha: .25),
                                        width: 1.5),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$discInt%',
                                          style: TextStyle(
                                            color: kPrimary,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                          ),
                                        ),
                                        Text(
                                          'OFF',
                                          style: TextStyle(
                                            color: kPrimary.withValues(alpha: .8),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Offer title
                            if (title.isNotEmpty)
                              Text(
                                title,
                                style: const TextStyle(
                                  color: kText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),

                            // Description
                            if (desc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  desc,
                                  style: const TextStyle(
                                      color: kMuted, fontSize: 11, height: 1.4),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            const Spacer(),
                            // Round 10: validity/date text removed from the
                            // deal card per spec (this decorative no-image
                            // fallback card is otherwise unchanged).
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}
