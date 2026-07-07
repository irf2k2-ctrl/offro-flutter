// lib/screens/store/widgets/store_products_section.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';

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

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Featured Products',
              style: TextStyle(
                  color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          const Text('Products available at this store',
              style: TextStyle(color: kMuted, fontSize: 12)),
        ]),
      ),
      // FIX Issue-1: height 210 → 260
      SizedBox(
        height: 260,
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

  const _ProductCard({
    required this.product,
    required this.index,
    this.storeName = '',
    this.storeId = '',
    this.token = '',
    this.onProductTap,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  static const List<List<Color>> _palettes = [
    [Color(0xFFCDEBD6), Color(0xFFA9CDBA)],
    [Color(0xFFE7D7C8), Color(0xFFD4B896)],
    [Color(0xFFD6EAF8), Color(0xFFAED6F1)],
    [Color(0xFFFDE8E8), Color(0xFFF1ABAB)],
    [Color(0xFFFFF3CD), Color(0xFFFFD966)],
    [Color(0xFFEDE7F6), Color(0xFFCE93D8)],
  ];

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
    } catch (_) {
      if (mounted) setState(() => _isFav = prev);
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Widget _img() {
    final url = widget.product['logo_url']?.toString() ?? '';
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(base64Decode(url.split(',').last),
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
    final pal = _palettes[widget.index % _palettes.length];
    return Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: pal)));
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
    final price    = p['price']?.toString() ?? '';
    final origPrice = p['original_price']?.toString() ?? '';
    final discount  = p['discount']?.toString() ?? '';
    final validity  = _isPremium ? '' : (p['validity']?.toString() ?? '');
    // FIX Issue-2: read rating from product data
    final rating    = (p['rating'] as num?)?.toDouble() ?? 0.0;

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

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        // FIX Issue-1: width 150 → 160
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──────────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                // FIX Issue-1: height 110 → 130
                height: 130,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  _img(),

                  // Discount badge (top-left)
                  if (discLabel.isNotEmpty)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(discLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),

                  // FIX Issue-2: Rating badge (bottom-left on image)
                  if (rating > 0)
                    Positioned(
                      bottom: 7, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFFD700), size: 11),
                              const SizedBox(width: 3),
                              Text(rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ]),
                      ),
                    ),

                  // FIX Issue-5: Favorite heart (top-right on image)
                  if (widget.token.isNotEmpty)
                    Positioned(
                      top: 6, right: 6,
                      child: GestureDetector(
                        onTap: _toggleFav,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .88),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12, blurRadius: 4)
                            ],
                          ),
                          child: Icon(
                            _isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _isFav
                                ? Colors.redAccent
                                : Colors.grey.shade500,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),

            // ── Info ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: kText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1.3)),
                    const Spacer(),
                    if (price.isNotEmpty) ...[
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('₹$price',
                                style: const TextStyle(
                                    color: kPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900)),
                            if (origPrice.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text('₹$origPrice',
                                  style: TextStyle(
                                      color: kMuted.withValues(alpha: .7),
                                      fontSize: 10,
                                      decoration:
                                          TextDecoration.lineThrough)),
                            ],
                          ]),
                    ] else if (validity.isNotEmpty)
                      Text('Valid: $validity',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: kMuted, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
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
      if (mounted) {
        setState(() => _submitting = false);
        final msg = e.toString().replaceFirst("Exception: ", "");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't submit rating: $msg"), backgroundColor: const Color(0xFFc0392b)));
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
