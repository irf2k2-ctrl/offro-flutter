// lib/screens/store/widgets/store_products_section.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/base64_image.dart' show decodeBase64ImageCached;
import '../../../core/services/api_service.dart';
import '../../../core/services/error_mapper.dart';
import 'store_header.dart' show FullScreenImageViewer;

// ─────────────────────────────────────────────────────────────────────────────
// Round 10 — shared pricing/discount resolution, used by both the card and
// the full-screen gallery overlay so the two always agree.
// ─────────────────────────────────────────────────────────────────────────────
class _ProductPricing {
  final num? saleP;
  final num? origP;
  final String discLabel;
  const _ProductPricing(this.saleP, this.origP, this.discLabel);
}

_ProductPricing _resolveProductPricing(Map<String, dynamic> p) {
  final price     = p['price']?.toString() ?? '';
  final origPrice = p['original_price']?.toString() ?? '';
  final discount  = p['discount']?.toString() ?? '';

  num? saleP;
  if (price.isNotEmpty) { saleP = num.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')); }
  if (saleP == null || saleP == 0) { saleP = (p['sale_price'] as num?)?.toDouble(); }
  num? origP;
  if (origPrice.isNotEmpty) { origP = num.tryParse(origPrice.replaceAll(RegExp(r'[^0-9.]'), '')); }
  if (origP != null && saleP != null && origP <= saleP) origP = null;

  String discLabel = discount;
  if (discLabel.isEmpty && price.isNotEmpty && origPrice.isNotEmpty) {
    try {
      final pv = double.parse(price);
      final op = double.parse(origPrice);
      if (op > pv && pv > 0) {
        discLabel = '${((op - pv) / op * 100).round()}% OFF';
      }
    } catch (_) {}
  }
  return _ProductPricing(saleP, origP, discLabel);
}

/// Round 10: the product's image URL, or '' if none — used to build the
/// full-screen gallery's image list (index-aligned with the products list).
String _productImageUrl(Map<String, dynamic> p) => p['logo_url']?.toString() ?? '';

/// Round 10 (extended in Round 12, Task 4): bottom-overlay content shown in
/// the full-screen product gallery. Task 2 (Round 12) strips the normal
/// card down to just title + price, so this full-screen overlay is now
/// the ONLY place several of these fields are shown at all — it carries
/// every detail the card no longer does: name (bold), tagline, discount,
/// sale/original price, rating, and validity (all previously either on
/// the card or nowhere in the gallery). Nothing here reads product data
/// differently than before; this only widens what gets DISPLAYED.
// ROUND 12 FOLLOW-UP (product viewer redesign): rating and validity are no
// longer shown here — validity is not required per the new design, and
// rating never appeared in the reference mockup. Discount now lives INSIDE
// the single price row (same red badge style used on the card) instead of
// as a separate line above it, so it appears exactly once, next to the
// price it applies to.
Widget _productGalleryOverlay(Map<String, dynamic> p) {
  final title    = p['title']?.toString() ?? '';
  final subtitle = p['offer_text']?.toString() ?? '';
  final pricing  = _resolveProductPricing(p);
  final hasPrice = pricing.saleP != null && pricing.saleP! > 0;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    if (title.isNotEmpty)
      Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    if (subtitle.isNotEmpty) ...[
      const SizedBox(height: 3),
      Text(subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 13, fontWeight: FontWeight.w500)),
    ],
    if (hasPrice || pricing.discLabel.isNotEmpty) ...[
      const SizedBox(height: 8),
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (pricing.discLabel.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFe74c3c), borderRadius: BorderRadius.circular(20)),
            child: Text(pricing.discLabel,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
        ],
        if (hasPrice) ...[
          Text('₹${pricing.saleP!.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          if (pricing.origP != null) ...[
            const SizedBox(width: 8),
            Text('₹${pricing.origP!.toStringAsFixed(0)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .65),
                    fontSize: 14,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.white.withValues(alpha: .65))),
          ],
        ],
      ]),
    ],
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// StoreProductsSection
// ─────────────────────────────────────────────────────────────────────────────
class StoreProductsSection extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final String token;
  final String storeName;
  final String storeId;   // FIX Issue-3: needed to open correct store card on tap
  final void Function(Map<String, dynamic> product, String token)? onProductTap;

  const StoreProductsSection({
    super.key,
    required this.products,
    this.token = '',
    this.storeName = '',
    this.storeId = '',
    this.onProductTap,
  });

  // Round 10: opens the swipeable full-screen product gallery across every
  // Featured Product for this store, starting at the exact product tapped.
  void _openProductGallery(BuildContext context, int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => FullScreenImageViewer(
          images: products.map(_productImageUrl).toList(),
          initialIndex: index,
          bottomOverlays: products.map(_productGalleryOverlay).toList(),
          // ROUND 12 FOLLOW-UP (product viewer redesign): spacedOverlay
          // (image shifted up + a reserved gap below it) was what created
          // the "separate details panel" / unwanted side-bar look. Reverting
          // to the default (false) makes the product gallery share the
          // exact same full-bleed image + direct bottom-gradient-overlay
          // style already used by the deal gallery and the plain
          // store-photo gallery — no new viewer code, just reusing what
          // already works elsewhere in this shared widget.
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Featured Products',
                style: TextStyle(
                    color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(width: 4),
            // FOLLOW-UP: single tap now opens the full-screen gallery, and
            // the older "view full details + leave a review" flow moved to
            // long-press — a change that isn't otherwise visible anywhere
            // on the card. This small (i) is just a discoverability hint
            // for that, not a promo — tapping it shows a one-line tip and
            // does nothing else (doesn't open the gallery or the detail
            // sheet, so it can't be confused with either).
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Tip: Long-press a product image to view details and leave a review.'),
                  backgroundColor: kPrimary,
                  duration: Duration(seconds: 4),
                  showCloseIcon: true,
                ));
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.info_outline, size: 15, color: kMuted),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          const Text('Products available at this store',
              style: TextStyle(color: kMuted, fontSize: 12)),
        ]),
      ),
      // Round 12 (Task 1): 210 now matches Today's Offers' deal-card
      // height/aspect ratio exactly (see store_offers_section.dart) so the
      // two sections feel like the same card/gallery style.
      SizedBox(
        height: 210,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          physics: const BouncingScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (_, i) => _ProductCard(
            product: products[i],
            index: i,
            storeName: storeName,
            storeId: storeId,
            token: token,
            onProductTap: onProductTap,
            onOpenGallery: () => _openProductGallery(context, i),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProductCard — StatefulWidget (FIX Issue-5: favorites state)
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final int index;
  final String storeName;
  final String storeId;
  final String token;
  final void Function(Map<String, dynamic> product, String token)? onProductTap;
  // Round 10: tapping the card now opens the swipeable full-screen gallery
  // (required behavior). The pre-existing detail sheet / onProductTap
  // navigation (product info + submit-a-rating) is preserved, reachable via
  // long-press, so that existing functionality isn't lost.
  final VoidCallback? onOpenGallery;

  const _ProductCard({
    required this.product,
    required this.index,
    this.storeName = '',
    this.storeId = '',
    this.token = '',
    this.onProductTap,
    this.onOpenGallery,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {

  // FIX Issue-5: favorite state
  bool _isFav = false;
  bool _favLoading = false;

  String get _productId =>
      widget.product['_id']?.toString() ??
      widget.product['id']?.toString() ?? '';

  bool get _isPremium =>
      (widget.product['product_type']?.toString() ?? '').toLowerCase() ==
      'premium';

  @override
  void initState() {
    super.initState();
    // FIX Issue-5: load favorite status on init
    if (widget.token.isNotEmpty && _productId.isNotEmpty) {
      _loadFav();
    }
  }

  Future<void> _loadFav() async {
    final fav = await Api.isProductFavorite(widget.token, _productId);
    if (mounted) setState(() => _isFav = fav);
  }

  Future<void> _toggleFav() async {
    if (widget.token.isEmpty || _productId.isEmpty || _favLoading) return;
    final prev = _isFav;
    setState(() { _isFav = !_isFav; _favLoading = true; });
    try {
      await Api.toggleProductFavorite(widget.token, _productId);
    } catch (e) {
      // FIX: was a silent revert with zero feedback — now surface the real
      // reason so a failed save is actually diagnosable instead of invisible.
      debugPrint('[OffrO] product favorite toggle error: $e');
      if (mounted) {
        setState(() => _isFav = prev);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Couldn't save favorite: ${friendlyError(e)}"),
          backgroundColor: const Color(0xFFc0392b),
          duration: const Duration(seconds: 12),
          showCloseIcon: true));
      }
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Widget _img() {
    final url = widget.product['logo_url']?.toString() ?? '';
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(decodeBase64ImageCached(url),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity);
      } catch (_) {}
    }
    if (url.startsWith('http')) {
      return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorWidget: (_, __, ___) => _bgGrad());
    }
    return _bgGrad();
  }

  Widget _bgGrad() {
    return Container(color: const Color(0xFFF5F5F5));
  }

  void _handleTap(BuildContext context) {
    if (widget.onProductTap != null) {
      final enriched = Map<String, dynamic>.from(widget.product);
      if (widget.storeName.isNotEmpty) enriched['store_name'] = widget.storeName;
      // FIX Issue-3: inject store_id so ProductDetailsPage can open correct store card
      if (widget.storeId.isNotEmpty) {
        enriched['store_id']         = widget.storeId;
        enriched['sold_by_store_id'] = widget.storeId;
      }
      widget.onProductTap!(enriched, widget.token);
    } else {
      _showDetail(context);
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailSheet(
        product: widget.product,
        token: widget.token,
        imgWidget: _img(),
        isPremium: _isPremium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p        = widget.product;
    final title    = p['title']?.toString() ?? '';
    final pricing = _resolveProductPricing(p);
    final saleP = pricing.saleP;
    final origP = pricing.origP;
    final discLabel = pricing.discLabel;

    // ROUND 12 REDESIGN (Tasks 1-3):
    // - Task 1: card is now 210x210 — the exact same size/aspect ratio as
    //   the Today's Offers deal card in store_offers_section.dart — so the
    //   two sections feel like the same card/gallery style.
    // - Task 2: the normal card now shows ONLY title (line 1) and
    //   sale/original price (line 2) over a small translucent bottom
    //   ribbon. Tagline (offer_text), the rating chip, and validity are
    //   no longer shown here — they're not gone, just moved to the
    //   full-screen gallery (_productGalleryOverlay), reachable by tapping
    //   the card, exactly like the rest of the product data always was.
    // - Task 3: the bottom-ribbon discount text is removed entirely — the
    //   red badge below is the only discount indicator on the card now.
    return GestureDetector(
      // Round 10: primary tap opens the swipeable full-screen gallery
      // (required behavior). Long-press preserves the previous
      // detail/rating flow so that functionality isn't lost.
      onTap: widget.onOpenGallery,
      onLongPress: () => _handleTap(context),
      child: Container(
        width: 210,
        height: 210,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder, width: 1),
          boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: .08), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(fit: StackFit.expand, children: [
            // ── Product image fills the card ──
            _img(),

            // ── Bottom gradient + info ribbon — title + price only ──
            // No fixed height needed any more: with the content now always
            // exactly these two short, single-line pieces (never a
            // variable-length tagline), a plain mainAxisSize.min Column
            // can't grow unpredictably the way the old 4-field version
            // could, so the simpler approach used by Today's Offers'
            // equivalent scrim is safe to reuse here too.
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: product title
                    if (title.isNotEmpty)
                      Text(title,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    // Line 2: sale price + original price (struck through)
                    if (saleP != null && saleP > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text("₹${saleP.toStringAsFixed(0)}",
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                          if (origP != null) ...[
                            const SizedBox(width: 6),
                            Text("₹${origP.toStringAsFixed(0)}",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .65), fontSize: 11.5,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.white.withValues(alpha: .65))),
                          ],
                        ]),
                      ),
                  ],
                ),
              ),
            ),

            // Discount badge (top-left) — the ONE discount indicator on the
            // card now (Task 3 removed the bottom-ribbon yellow discount
            // text that used to duplicate this).
            if (discLabel.isNotEmpty)
              Positioned(top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFe74c3c), borderRadius: BorderRadius.circular(20)),
                  child: Text(discLabel, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                )),

            // Favorite heart (top-right) — unchanged functionality, repositioned over the image
            if (widget.token.isNotEmpty)
              Positioned(top: 6, right: 6,
                child: GestureDetector(
                  onTap: _toggleFav,
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .88),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 4)],
                    ),
                    child: Icon(
                      _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFav ? const Color(0xFFe74c3c) : const Color(0xFF9e9e9e),
                      size: 14),
                  ),
                )),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProductDetailSheet — stateful bottom sheet
// FIX Issue-4: shows product rating + lets user submit their own rating
// ─────────────────────────────────────────────────────────────────────────────
class _ProductDetailSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final String token;
  final Widget imgWidget;
  final bool isPremium;

  const _ProductDetailSheet({
    required this.product,
    required this.token,
    required this.imgWidget,
    required this.isPremium,
  });

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  double _userRating = 0;
  bool   _submitting = false;
  bool   _submitted  = false;
  final  TextEditingController _reviewCtrl = TextEditingController();

  String get _productId =>
      widget.product['_id']?.toString() ??
      widget.product['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    // FIX Issue-2+4: load any existing rating the user already gave
    if (widget.token.isNotEmpty && _productId.isNotEmpty) {
      _loadMyRating();
    }
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyRating() async {
    final d = await Api.getMyProductReview(widget.token, _productId);
    if (mounted && d.isNotEmpty) {
      setState(() {
        _userRating = (d['rating'] as num?)?.toDouble() ?? 0;
        _reviewCtrl.text = d['text']?.toString() ?? '';
        _submitted = _userRating > 0;
      });
    }
  }

  // FIX Issue-2: saves rating to backend
  Future<void> _submitRating() async {
    if (_userRating == 0 || widget.token.isEmpty || _productId.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await Api.submitProductReview(
          widget.token, _productId, _userRating, _reviewCtrl.text.trim());
      if (mounted) setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      // FIX: submitProductReview now throws on real failure instead of being
      // silently swallowed — show the actual reason instead of a fake success.
      debugPrint('[OffrO] product rating submit error: $e');
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't submit rating: ${friendlyError(e)}"), backgroundColor: const Color(0xFFc0392b)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p         = widget.product;
    final title     = p['title']?.toString() ?? '';
    final offerText = p['offer_text']?.toString() ?? '';
    final price     = p['price']?.toString() ?? '';
    final origPrice = p['original_price']?.toString() ?? '';
    final validity  = widget.isPremium ? '' : (p['validity']?.toString() ?? '');
    // FIX Issue-4: average rating from product data
    final avgRating = (p['rating'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(
            child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
          ),

          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
                height: 160,
                width: double.infinity,
                child: widget.imgWidget),
          ),
          const SizedBox(height: 16),

          // Title
          Text(title,
              style: const TextStyle(
                  color: kText,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),

          // FIX Issue-4: average rating row
          if (avgRating > 0) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ...List.generate(5, (i) => Icon(
                    i < avgRating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFFFD700),
                    size: 16,
                  )),
              const SizedBox(width: 6),
              Text(avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                      color: kMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ],

          if (offerText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(offerText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: kMuted, fontSize: 14, height: 1.5)),
          ],

          if (price.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('₹$price',
                  style: const TextStyle(
                      color: kPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              if (origPrice.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text('₹$origPrice',
                    style: TextStyle(
                        color: kMuted.withValues(alpha: .7),
                        fontSize: 16,
                        decoration: TextDecoration.lineThrough)),
              ],
            ]),
          ],

          if (validity.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.calendar_today_rounded,
                  color: kMuted, size: 13),
              const SizedBox(width: 5),
              Text('Valid till $validity',
                  style: const TextStyle(color: kMuted, fontSize: 12)),
            ]),
          ],

          // ── FIX Issue-2 + Issue-4: User rating section ──────
          if (widget.token.isNotEmpty && _productId.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              _submitted ? 'Your Rating' : 'Rate this Product',
              style: const TextStyle(
                  color: kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: _submitted
                      ? null
                      : () => setState(() => _userRating = i + 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _userRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFFFD700),
                      size: 34,
                    ),
                  ),
                );
              }),
            ),
            if (!_submitted) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _reviewCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Write a short review (optional)',
                  hintStyle: TextStyle(
                      color: kMuted.withValues(alpha: .6), fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _userRating > 0 && !_submitting
                      ? _submitRating
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        kPrimary.withValues(alpha: .4),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text('Submit Rating',
                          style: TextStyle(
                              fontWeight: FontWeight.w800)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text('Thanks for your rating! ⭐',
                  style: TextStyle(color: kPrimary, fontSize: 13)),
            ],
          ],

          const SizedBox(height: 20),

          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Got it',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
