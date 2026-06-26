// lib/screens/store/widgets/store_products_section.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_constants.dart';

class StoreProductsSection extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final String token;
  // FIX ISSUE-2: callback so StoreDetailPage can navigate to ProductDetailsPage
  final void Function(Map<String, dynamic> product)? onProductTap;

  const StoreProductsSection({super.key, required this.products, this.token = '', this.onProductTap});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section header
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
      // Horizontal scroll
      SizedBox(
        height: 210,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          physics: const BouncingScrollPhysics(),
          itemCount: products.length,
          itemBuilder: (_, i) {
            final p = products[i];
            return _ProductCard(product: p, index: i, token: token, onTap: onProductTap);
          },
        ),
      ),
    ]);
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int index;
  final String token;
  final void Function(Map<String, dynamic>)? onTap;

  static const List<List<Color>> _palettes = [
    [Color(0xFFCDEBD6), Color(0xFFA9CDBA)],
    [Color(0xFFE7D7C8), Color(0xFFD4B896)],
    [Color(0xFFD6EAF8), Color(0xFFAED6F1)],
    [Color(0xFFFDE8E8), Color(0xFFF1ABAB)],
    [Color(0xFFFFF3CD), Color(0xFFFFD966)],
    [Color(0xFFEDE7F6), Color(0xFFCE93D8)],
  ];

  const _ProductCard({required this.product, required this.index, this.token = '', this.onTap});

  Widget _img() {
    final url = product['logo_url']?.toString() ?? '';
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(base64Decode(url.split(',').last),
            fit: BoxFit.cover, width: double.infinity, height: double.infinity);
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
    final pal = _palettes[index % _palettes.length];
    return Container(
        decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: pal)));
  }

  @override
  Widget build(BuildContext context) {
    final title    = product['title']?.toString() ?? '';
    final price    = product['price']?.toString() ?? '';
    final origPrice= product['original_price']?.toString() ?? '';
    final discount = product['discount']?.toString() ?? '';
    final validity = product['validity']?.toString() ?? '';

    // Auto-calc discount if not provided
    String discLabel = discount;
    if (discLabel.isEmpty && price.isNotEmpty && origPrice.isNotEmpty) {
      try {
        final p = double.parse(price);
        final op = double.parse(origPrice);
        if (op > p && p > 0) {
          discLabel = '${((op - p) / op * 100).round()}% OFF';
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        width: 150,
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
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  _img(),
                  // Discount badge
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
                ]),
              ),
            ),
            // Info
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
                                      decoration: TextDecoration.lineThrough)),
                            ],
                          ]),
                    ] else if (validity.isNotEmpty)
                      Text('Valid: $validity',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: kMuted, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    // FIX ISSUE-2: Use onTap callback so StoreDetailPage handles navigation
    if (onTap != null) {
      onTap!(product);
    }
  }
}
