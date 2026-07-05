// lib/screens/store/widgets/store_header.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_constants.dart';

class StoreHeader extends StatelessWidget {
  final Map<String, dynamic> store;
  final List<String> images;
  final int imgPage;
  final PageController imgController;
  final bool isFav;
  final VoidCallback onFavToggle;
  final VoidCallback onShare;
  final VoidCallback onBack;

  const StoreHeader({
    super.key,
    required this.store,
    required this.images,
    required this.imgPage,
    required this.imgController,
    required this.isFav,
    required this.onFavToggle,
    required this.onShare,
    required this.onBack,
  });

  void _openFullScreen(BuildContext context) {
    if (images.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => _FullScreenImageViewer(
          images: images,
          initialIndex: imgPage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name        = store['store_name']?.toString() ?? '';
    final category    = store['category']?.toString() ?? '';
    final area        = store['area']?.toString() ?? '';
    final city        = store['city']?.toString() ?? '';
    final rating      = (store['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (store['review_count'] as num?)?.toInt() ?? 0;
    final distKm      = (store['distance_km'] as num?)?.toDouble();
    final locationText =
        [area, city].where((x) => x.isNotEmpty).join(', ');

    // Logo: logo_url → logo → store image (always show circle on wave)
    final logoUrl = (store['logo_url']?.toString() ?? '').isNotEmpty
        ? store['logo_url'].toString()
        : (store['logo']?.toString() ?? '').isNotEmpty
            ? store['logo'].toString()
            : (store['image_url']?.toString() ?? '').isNotEmpty
                ? store['image_url'].toString()
                : (store['image']?.toString() ?? '').isNotEmpty
                    ? store['image'].toString()
                    : '';
    // Always show logo circle on the wave divider
    const hasLogo = true;

    // Use only main image (index 0) — no auto-scroll per requirement
    final mainImage = images.isNotEmpty ? images[0] : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Hero Image (260px) + wave curve + centered logo ─
        SizedBox(
          // Extra height for logo overlap on wave
          height: 308, // always show logo circle
          child: Stack(clipBehavior: Clip.none, children: [
            // Hero image (fixed, no pageview auto-scroll)
            Positioned(
              top: 0, left: 0, right: 0,
              child: GestureDetector(
                onTap: () => _openFullScreen(context),
                child: SizedBox(
                  height: 260,
                  child: mainImage.isEmpty
                      ? Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2a4a40), kPrimary],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.store_mall_directory_outlined,
                              color: Colors.white24,
                              size: 80,
                            ),
                          ),
                        )
                      : _buildImage(mainImage),
                ),
              ),
            ),

            // Top gradient for button readability
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .52),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Wave curve at bottom of hero (sits at y=242)
            Positioned(
              top: 242, left: 0, right: 0,
              child: CustomPaint(
                painter: _WavePainter(),
                child: const SizedBox(height: 36),
              ),
            ),

            // Top bar — back + fav + share
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(children: [
                    _glassBtn(Icons.arrow_back_ios_new_rounded, onBack),
                    const Spacer(),
                    _glassFavBtn(isFav, onFavToggle),
                    const SizedBox(width: 8),
                    _glassBtn(Icons.ios_share_rounded, onShare),
                  ]),
                ),
              ),
            ),

            // Merchant logo — centered on the wave line (y ≈ 242+8 = 250)
            if (hasLogo)
              Positioned(
                top: 214,   // centers the 80px circle on the wave (wave y=242, center=251, top=251-40=211)
                left: 0, right: 0,
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFA9CDBA), width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .15),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: logoUrl.isNotEmpty
                          ? _buildLogoImage(logoUrl)
                          : Container(
                              color: const Color(0xFFe8f5f0),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                  style: const TextStyle(
                                    color: Color(0xFF3E5F55),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
          ]),
        ),

        // ─── Store Info ───────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, hasLogo ? 8 : 14, 16, 0),
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kText,
              height: 1.2,
            ),
          ),
        ),
        if (category.isNotEmpty || locationText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 0),
            child: Text(
              [category, locationText]
                  .where((x) => x.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(
                  color: kMuted, fontSize: 13, height: 1.3),
            ),
          ),
        const SizedBox(height: 8),
        // ─── Rating row with inline badge (same line, matches home screen) ───
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Distance
            if (distKm != null) ...[
              const Icon(Icons.near_me_rounded, color: kMuted, size: 13),
              const SizedBox(width: 3),
              Text(
                distKm < 1
                    ? '${(distKm * 1000).round()} m'
                    : '${distKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                    color: kMuted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
            // Dot separator
            if (distKm != null && rating > 0) ...[
              const SizedBox(width: 8),
              const Text('·', style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(width: 8),
            ],
            // Stars + count
            if (rating > 0) ...[
              const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 15),
              const SizedBox(width: 3),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                    color: kText, fontSize: 13, fontWeight: FontWeight.w800),
              ),
              if (reviewCount > 0) ...[
                const SizedBox(width: 3),
                Text(
                  '($reviewCount)',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ],
            // ─── Inline badge — same black pill as home screen ───
            Builder(builder: (_ctx) {
              const _meta = <String, String>{
                'new_store':     '🆕 NEW STORE',
                'just_opened':   '🎉 JUST OPENED',
                'newly_added':   '✨ NEWLY ADDED',
                'trending':      '🔥 TRENDING',
                'popular':       '⭐ POPULAR',
                'top_rated':     '🏆 TOP RATED',
                'must_visit':    '📍 MUST VISIT',
                'limited_offer': '⏳ LIMITED OFFER',
              };
              final _rb = (store['badge'] as String?)?.trim() ?? '';
              String? _key;
              if (_rb.isNotEmpty && _meta.containsKey(_rb)) {
                _key = _rb;
              } else {
                try {
                  final _c = store['created_at']?.toString()
                      ?? store['created_date']?.toString() ?? '';
                  if (_c.isNotEmpty) {
                    final _dt = DateTime.tryParse(_c);
                    if (_dt != null &&
                        DateTime.now().difference(_dt).inDays < 10) {
                      _key = 'newly_added';
                    }
                  }
                } catch (_) {}
                if (_key == null) {
                  if (store['is_new_in_town'] == true)   _key = 'new_store';
                  else if (store['is_trending'] == true) _key = 'trending';
                  else if (store['is_popular']  == true) _key = 'popular';
                }
              }
              if (_key == null) return const SizedBox.shrink();
              return Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _meta[_key]!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ]);
            }),
          ]),
        ),

        const SizedBox(height: 8),

        // ── Open/close status ──
        Builder(builder: (ctx) {
          final openTime  = store['open_time']?.toString()  ?? '';
          final closeTime = store['close_time']?.toString() ?? '';
          if (closeTime.isEmpty ||
              (openTime == '00:00' && closeTime == '00:00') ||
              (openTime.isEmpty  && closeTime == '00:00') ||
              (closeTime == '00:00:00')) {
            return const SizedBox.shrink();
          }
          try {
            // Strip seconds if stored as HH:MM:SS
            final _ct      = closeTime.length > 5 ? closeTime.substring(0, 5) : closeTime;
            final _ot      = openTime.length  > 5 ? openTime.substring(0, 5)  : openTime;
            final now      = TimeOfDay.now();
            final nowMins  = now.hour * 60 + now.minute;
            final cParts   = _ct.split(':');
            final cH       = int.parse(cParts[0]);
            final cM       = cParts.length > 1 ? int.parse(cParts[1]) : 0;
            final closeMins = cH * 60 + cM;
            final cSuffix   = cH >= 12 ? 'PM' : 'AM';
            final cH12      = cH > 12 ? cH - 12 : (cH == 0 ? 12 : cH);
            final cMinStr   = cM > 0 ? ':${cM.toString().padLeft(2, '0')}' : '';
            final bool isOpen = nowMins < closeMins;
            String sub = isOpen ? 'Closes $cH12$cMinStr $cSuffix' : '';
            if (!isOpen && openTime.isNotEmpty) {
              final oParts  = _ot.split(':');
              final oH      = int.parse(oParts[0]);
              final oM      = oParts.length > 1 ? int.parse(oParts[1]) : 0;
              final oSuffix = oH >= 12 ? 'PM' : 'AM';
              final oH12    = oH > 12 ? oH - 12 : (oH == 0 ? 12 : oH);
              final oMinStr = oM > 0 ? ':${oM.toString().padLeft(2, '0')}' : '';
              sub = 'Opens $oH12$oMinStr $oSuffix';
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOpen ? const Color(0xFFe8f5ee) : const Color(0xFFfdf0f0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: isOpen ? const Color(0xFF2e7d52) : const Color(0xFFc0392b),
                      shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(isOpen ? 'Open' : 'Closed',
                    style: TextStyle(
                      color: isOpen ? const Color(0xFF2e7d52) : const Color(0xFFc0392b),
                      fontSize: 11, fontWeight: FontWeight.w800)),
                  if (sub.isNotEmpty) ...[
                    Text(' · ',
                      style: TextStyle(
                        color: (isOpen ? const Color(0xFF2e7d52) : const Color(0xFFc0392b)).withValues(alpha: .6),
                        fontSize: 11)),
                    Text(sub,
                      style: TextStyle(
                        color: (isOpen ? const Color(0xFF2e7d52) : const Color(0xFFc0392b)).withValues(alpha: .75),
                        fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            );
          } catch (_) {
            return const SizedBox.shrink();
          }
        }),
        // ─── Action Buttons: Call · WhatsApp · Visit Store ────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: _ActionButtonsRow(store: store),
        ),
      ],
    );
  }

  Widget _buildImage(String im) {
    if (im.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(im.split(',').last),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        );
      } catch (_) {}
    }
    if (im.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: im,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, __) => Container(color: kLight),
        errorWidget: (_, __, ___) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF2a4a40), kPrimary]),
          ),
        ),
      );
    }
    return Container(color: kLight);
  }

  Widget _buildLogoImage(String url) {
    if (url.isEmpty) return const SizedBox.shrink();
    // Relative path — prepend base URL
    final resolved = url.startsWith('/') ? '$kBaseUrl$url' : url;
    if (resolved.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: resolved,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, __) => Container(
          color: kLight,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: kPrimary,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: kLight,
          child: const Icon(Icons.store_rounded,
              color: kPrimary, size: 24),
        ),
      );
    }
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(url.split(',').last),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (_) {}
    }
    // Raw base64 without header
    if (url.length > 100 && !url.contains('/') && !url.contains('.')) {
      try {
        return Image.memory(
          base64Decode(url),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (_) {}
    }
    return Container(
      color: kLight,
      child: const Icon(Icons.store_rounded, color: kPrimary, size: 24),
    );
  }

  Widget _glassFavBtn(bool isFav, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: .2), width: 1),
          ),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFav ? const Color(0xFFFF4D6D) : Colors.white,
            size: 18,
          ),
        ),
      );

  Widget _glassBtn(IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .32),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: .25), width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
}

// ─── Wave Painter ─────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(
        size.width * 0.25, 0,
        size.width * 0.5, size.height * 0.35);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.7,
        size.width, size.height * 0.2);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter _) => false;
}

// ─── Action Buttons Row ───────────────────────────────────────
class _ActionButtonsRow extends StatelessWidget {
  final Map<String, dynamic> store;
  const _ActionButtonsRow({required this.store});

  Future<void> _call() async {
    final phone = store['phone']?.toString() ?? '';
    if (phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _whatsapp() async {
    final phone = store['phone']?.toString() ?? '';
    if (phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    await launchUrl(
      Uri.parse('https://wa.me/$clean'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _directions() async {
    final lat  = store['latitude']?.toString()  ?? '';
    final lng  = store['longitude']?.toString() ?? '';
    final addr = store['address']?.toString()   ?? '';
    final url  = (lat.isNotEmpty && lng.isNotEmpty)
        ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
        : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}';
    await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final btns = [
      _BtnData('Call',        Icons.phone_rounded,   _call),
      _BtnData('WhatsApp',    Icons.chat_rounded,    _whatsapp),
      _BtnData('Visit Store', Icons.near_me_rounded, _directions),
    ];

    return Row(
      children: btns.asMap().entries.map((e) {
        final b = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 10),
            child: GestureDetector(
              onTap: b.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorder, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(b.icon,
                        color: b.label == 'WhatsApp'
                            ? const Color(0xFF25D366)
                            : kPrimary,
                        size: 22),
                    const SizedBox(height: 5),
                    Text(
                      b.label,
                      style: const TextStyle(
                        color: kText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BtnData {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _BtnData(this.label, this.icon, this.onTap);
}

// ─── Full Screen Image Viewer ─────────────────────────────────
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullScreenImageViewer(
      {required this.images, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState
    extends State<_FullScreenImageViewer> {
  late int _current;
  late PageController _pc;
  late TransformationController _tc;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pc = PageController(initialPage: widget.initialIndex);
    _tc = TransformationController();
  }

  @override
  void dispose() {
    _pc.dispose();
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if (d.primaryVelocity != null &&
              d.primaryVelocity!.abs() > 300) {
            Navigator.pop(context);
          }
        },
        child: Stack(children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final im = widget.images[i];
              return InteractiveViewer(
                transformationController: _tc,
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: im.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: im,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 60),
                        )
                      : im.startsWith('data:image')
                          ? Builder(builder: (_) {
                              try {
                                return Image.memory(
                                  base64Decode(im.split(',').last),
                                  fit: BoxFit.contain,
                                );
                              } catch (_) {
                                return const SizedBox.shrink();
                              }
                            })
                          : const SizedBox.shrink(),
                ),
              );
            },
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const Spacer(),
                  if (widget.images.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_current + 1} / ${widget.images.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
