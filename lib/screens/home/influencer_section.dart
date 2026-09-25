import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';

// ══════════════════════════════════════════════════════════
// INFLUENCER MODULE — connected to the real backend (Phase 2/3).
//
// Every screen/widget below reads influencer data through
// fetchInfluencers() immediately below. This used to return mock data;
// it now calls the real, backend-authoritative public endpoint
// (GET /influencers?city=...) via Api.getInfluencers(). No other widget
// in this file, and nothing in main.dart, needed to change — this was
// the one seam the whole module was built around.
//
// PRIVACY: the public API response (see routers/public.py) never includes
// a phone field — it's stripped server-side before this ever reaches the
// client, not merely hidden here.
// ══════════════════════════════════════════════════════════

/// [city] is required — the backend does the actual city filtering
/// (case-insensitive, escaped regex) and only ever returns active
/// influencers for that exact city. No client-side fallback to another
/// city exists anywhere in this file; an empty/failed response simply
/// means "no influencers for this city," which callers already render
/// correctly (CityInfluencersSection hides the section entirely;
/// InfluencerListingScreen shows the existing "No influencers available
/// in {city} yet" empty state).
Future<List<Map<String, dynamic>>> fetchInfluencers({required String city}) async {
  final raw = await Api.getInfluencers(city: city);
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Color _avatarColor(String seed) {
  final palette = [kLight, kBeige, kAccent];
  final idx = seed.isNotEmpty ? seed.codeUnitAt(0) % palette.length : 0;
  return palette[idx];
}

// Local route helper — main.dart/home_screen.dart's own `_route` is
// file-private and not visible here, so this mirrors it for this file.
PageRoute _route(Widget w) => MaterialPageRoute(builder: (_) => w);

Future<void> _openSocial(String? url) async {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Widget _socialIcons(Map social, {double size = 16}) {
  final icons = <Widget>[];
  void addIfPresent(String key, IconData icon, Color color) {
    final url = social[key]?.toString() ?? "";
    if (url.isNotEmpty) {
      icons.add(GestureDetector(
        onTap: () => _openSocial(url),
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(icon, size: size, color: color),
        ),
      ));
    }
  }
  addIfPresent("instagram", Icons.camera_alt_rounded, const Color(0xFFD4537E));
  addIfPresent("youtube", Icons.play_circle_fill_rounded, const Color(0xFFE24B4A));
  addIfPresent("facebook", Icons.facebook_rounded, const Color(0xFF378ADD));
  return Row(mainAxisSize: MainAxisSize.min, children: icons);
}

/// Polished social row for the profile screen — icon + platform name +
/// chevron, tappable, using the same _openSocial launcher as the compact
/// icon row above.
Widget _socialRow(Map social) {
  final rows = <Widget>[];
  void addIfPresent(String key, String label, IconData icon, Color color) {
    final url = social[key]?.toString() ?? "";
    if (url.isEmpty) return;
    rows.add(InkWell(
      onTap: () => _openSocial(url),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: kMuted),
        ]),
      ),
    ));
  }
  addIfPresent("instagram", "Instagram", Icons.camera_alt_rounded, const Color(0xFFD4537E));
  addIfPresent("youtube", "YouTube", Icons.play_circle_fill_rounded, const Color(0xFFE24B4A));
  addIfPresent("facebook", "Facebook", Icons.facebook_rounded, const Color(0xFF378ADD));
  if (rows.isEmpty) {
    return const Text("No social links added yet", style: TextStyle(fontSize: 12, color: kMuted));
  }
  return Column(children: rows);
}

Widget _ratingRow(Map influencer, {double fontSize = 11}) {
  final rating = (influencer["rating"] as num?)?.toStringAsFixed(1) ?? "-";
  final reviews = influencer["review_count"]?.toString() ?? "0";
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.star_rounded, color: const Color(0xFFFFB800), size: fontSize + 2),
    const SizedBox(width: 2),
    Text(rating, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: kText)),
    const SizedBox(width: 3),
    Text("($reviews)", style: TextStyle(fontSize: fontSize, color: kMuted)),
  ]);
}

Widget _avatar(Map influencer, double size) {
  final name = influencer["name"]?.toString() ?? "?";
  final photoUrl = influencer["photo_url"]?.toString() ?? "";
  if (photoUrl.startsWith("http")) {
    // FIX (Item 7 — uploaded photo not appearing): the rest of the app
    // exclusively uses CachedNetworkImage for network photos (see
    // store_cards.dart) — this was the one place still using plain
    // Image.network, which behaves differently in this app's environment.
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: CachedNetworkImage(
        imageUrl: photoUrl, width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, __) => _avatarFallback(name, size),
        errorWidget: (_, __, ___) => _avatarFallback(name, size),
      ),
    );
  }
  if (photoUrl.startsWith("data:")) {
    try {
      final b64 = photoUrl.split(",").last;
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.memory(base64Decode(b64), width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(name, size)),
      );
    } catch (_) {
      return _avatarFallback(name, size);
    }
  }
  return _avatarFallback(name, size);
}

Widget _avatarFallback(String name, double size) {
  return Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: _avatarColor(name)),
    alignment: Alignment.center,
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?",
      style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: kPrimary)),
  );
}

String _shareText(Map influencer) {
  final name = influencer["name"]?.toString() ?? "";
  final city = influencer["city"]?.toString() ?? "";
  final rating = (influencer["rating"] as num?)?.toStringAsFixed(1) ?? "-";
  return "Check out $name on OffrO\n$city • ⭐ $rating";
}

/// Home screen card — used inside the horizontal "City Influencers" row.
class _InfluencerCard extends StatelessWidget {
  final Map<String, dynamic> influencer;
  final String token;
  const _InfluencerCard({required this.influencer, required this.token});

  @override
  Widget build(BuildContext context) {
    final name = influencer["name"]?.toString() ?? "";

    return GestureDetector(
      onTap: () => Navigator.push(context, _route(InfluencerProfileScreen(influencer: influencer, token: token))),
      child: Container(
        // Item 1: matches Discover Products' card width (155) and right
        // margin (12) exactly (see _DiscoverProductsSection in main.dart).
        // The row height is set to 170 at the SizedBox wrapper in
        // CityInfluencersSection below, also matching Discover Products.
        width: 155,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Items 8 & 9: no social-icon overlay and no city on the Home
          // card — both were removed here specifically; the profile screen
          // still shows city and social links in full.
          // Avatar kept at its exact existing explicit size (108) — NOT
          // wrapped in AspectRatio anymore, since AspectRatio would stretch
          // it to fill the new, wider card. Centered instead so only the
          // card grew, not the avatar.
          Center(child: _avatar(influencer, 108)),
          const SizedBox(height: 8),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText)),
          const SizedBox(height: 4),
          _ratingRow(influencer),
          // Item 10: Follow button removed — it was local-UI-only and never
          // actually persisted a follow relationship anywhere.
        ]),
      ),
    );
  }
}

/// City Influencers — home screen section.
class CityInfluencersSection extends StatefulWidget {
  final String city;
  final String token;
  const CityInfluencersSection({super.key, required this.city, this.token = ""});

  @override
  State<CityInfluencersSection> createState() => _CityInfluencersSectionState();
}

class _CityInfluencersSectionState extends State<CityInfluencersSection> {
  List<Map<String, dynamic>>? _influencers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CityInfluencersSection old) {
    super.didUpdateWidget(old);
    if (old.city != widget.city) _load();
  }

  Future<void> _load() async {
    final data = await fetchInfluencers(city: widget.city);
    if (mounted) setState(() => _influencers = data);
  }

  @override
  Widget build(BuildContext context) {
    final influencers = _influencers;
    // Section stays hidden on the home feed when there's nothing for this
    // city — the dedicated listing screen (via View All) is where an
    // explicit "no influencers yet" message is shown instead.
    if (influencers == null || influencers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text("City influencers", style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        // Item 1: row height matches Discover Products (170) exactly.
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            // Item 3: "See All" trailing card replaces the old "View all →"
            // header pill — same +1/itemCount pattern _DiscoverProductsSection
            // uses for its own trailing See All card.
            itemCount: influencers.length + 1,
            itemBuilder: (ctx, i) {
              if (i == influencers.length) {
                // Exact visual/size/interaction match of Discover Products'
                // trailing See All card (see _DiscoverProductsSection in
                // main.dart) — only the destination differs.
                return GestureDetector(
                  onTap: () => Navigator.push(context, _route(InfluencerListingScreen(city: widget.city, token: widget.token))),
                  child: Center(
                    child: Container(
                      width: 52, height: 120,
                      margin: const EdgeInsets.only(left: 4, right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF3E5F55), width: 1.5),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFFe8f4ef),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, color: Color(0xFF3E5F55), size: 14),
                        ),
                        const SizedBox(height: 4),
                        const Text("See All",
                          style: TextStyle(color: Color(0xFF3E5F55), fontSize: 9, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                );
              }
              return _InfluencerCard(influencer: influencers[i], token: widget.token);
            },
          ),
        ),
      ]),
    );
  }
}

/// Full-screen influencer listing — reached via "View all". Same mock
/// data source as the home section, filtered by the same city.
class InfluencerListingScreen extends StatefulWidget {
  final String city;
  final String token;
  const InfluencerListingScreen({super.key, required this.city, this.token = ""});

  @override
  State<InfluencerListingScreen> createState() => _InfluencerListingScreenState();
}

class _InfluencerListingScreenState extends State<InfluencerListingScreen> {
  List<Map<String, dynamic>>? _influencers;

  @override
  void initState() {
    super.initState();
    fetchInfluencers(city: widget.city).then((data) {
      if (mounted) setState(() => _influencers = data);
    });
  }

  @override
  Widget build(BuildContext context) {
    final influencers = _influencers;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kText),
        title: const Text("City influencers", style: TextStyle(color: kText, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: influencers == null
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : influencers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.person_search_rounded, size: 40, color: kMuted),
                      const SizedBox(height: 10),
                      Text("No influencers available in ${widget.city} yet",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: influencers.length,
                  itemBuilder: (ctx, i) {
                    final inf = influencers[i];
                    final social = (inf["social"] is Map) ? inf["social"] as Map : {};
                    return GestureDetector(
                      onTap: () => Navigator.push(context, _route(InfluencerProfileScreen(influencer: inf, token: widget.token))),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _avatar(inf, 56),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(inf["name"]?.toString() ?? "",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText))),
                            ]),
                            const SizedBox(height: 2),
                            Text("${inf["city"] ?? ""} · ${inf["category"] ?? ""}",
                              style: const TextStyle(fontSize: 11, color: kMuted)),
                            const SizedBox(height: 6),
                            _ratingRow(inf),
                            const SizedBox(height: 8),
                            _socialIcons(social, size: 16),
                          ])),
                        ]),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Polished influencer profile screen.
class InfluencerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> influencer;
  final String token;
  const InfluencerProfileScreen({super.key, required this.influencer, this.token = ""});

  @override
  State<InfluencerProfileScreen> createState() => _InfluencerProfileScreenState();
}

class _InfluencerProfileScreenState extends State<InfluencerProfileScreen> {
  int _myStars = 0;
  final _reviewC = TextEditingController();
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = true;
  bool _submittingReview = false;
  String? _myReviewId; // non-null once we know the user already has a review

  // Item 12: branded share card — captured off-screen via RepaintBoundary,
  // same pattern already used for store sharing (see detail_page.dart).
  final GlobalKey _shareCardKey = GlobalKey();
  bool _sharing = false;

  // Item 4 fix: this used to be in-session-only state, seeded once from the
  // influencer map passed in and never touching a backend — so a submitted
  // review "disappeared" the moment the screen was reopened (nothing was
  // ever actually saved). Now seeded the same way, but immediately
  // refreshed from the real, persisted values once _loadReal() returns.
  late double _displayRating;
  late int _displayReviewCount;

  String get _influencerId => widget.influencer["_id"]?.toString() ?? "";

  @override
  void initState() {
    super.initState();
    _displayRating = (widget.influencer["rating"] as num?)?.toDouble() ?? 0.0;
    _displayReviewCount = (widget.influencer["review_count"] as num?)?.toInt() ?? 0;
    _loadReal();
  }

  Future<void> _loadReal() async {
    final id = _influencerId;
    if (id.isEmpty) { if (mounted) setState(() => _loadingReviews = false); return; }
    final results = await Future.wait([
      Api.getInfluencerReviews(id),
      widget.token.isNotEmpty ? Api.getMyInfluencerReview(widget.token, id) : Future.value(<String,dynamic>{}),
    ]);
    final reviewsResp = results[0];
    final myReview = results[1];
    if (!mounted) return;
    setState(() {
      final list = reviewsResp["reviews"];
      _reviews = list is List ? List<Map<String, dynamic>>.from(list) : [];
      if (myReview.isNotEmpty) {
        _myReviewId = myReview["_id"]?.toString();
        _myStars = (myReview["rating"] as num?)?.toInt() ?? 0;
        _reviewC.text = myReview["text"]?.toString() ?? "";
      }
      _loadingReviews = false;
    });
  }

  @override
  void dispose() {
    _reviewC.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_myStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a star rating first")));
      return;
    }
    if (widget.token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to submit a review")));
      return;
    }
    if (_reviewC.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please write at least a few words")));
      return;
    }
    final id = _influencerId;
    if (id.isEmpty || _submittingReview) return;
    setState(() => _submittingReview = true);
    try {
      // Item 4: real, authenticated, persisted submission — replaces the
      // old local-only setState that never survived reopening the screen.
      final result = await Api.submitInfluencerReview(widget.token, id, _myStars.toDouble(), _reviewC.text.trim());
      if (mounted) {
        setState(() {
          _displayRating = (result["avg_rating"] as num?)?.toDouble() ?? _displayRating;
          _displayReviewCount = (result["review_count"] as num?)?.toInt() ?? _displayReviewCount;
        });
        // Refresh the review list from the server so what's shown matches
        // exactly what was persisted (including our own submission).
        await _loadReal();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Thanks for your review!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))));
      }
    }
    if (mounted) setState(() => _submittingReview = false);
  }


  // Item 12: capture the off-screen branded card (built in build() below,
  // inside an Offstage) as a PNG, matching the exact RepaintBoundary
  // pattern already used for store sharing (detail_page.dart).
  Future<Uint8List?> _captureShareCard() async {
    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareBrandedCard() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final inf = widget.influencer;
    final name = inf["name"]?.toString() ?? "";
    try {
      // Give the Offstage card a frame to lay out before capturing.
      await Future.delayed(const Duration(milliseconds: 50));
      final bytes = await _captureShareCard();
      if (bytes != null) {
        final tmpDir = await getTemporaryDirectory();
        final file = File("${tmpDir.path}/offro_influencer_share.png");
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: _shareText(inf));
      } else {
        await Share.share(_shareText(inf), subject: "OffrO – $name");
      }
    } catch (_) {
      await Share.share(_shareText(inf), subject: "OffrO – $name");
    }
    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    final inf = widget.influencer;
    final social = (inf["social"] is Map) ? inf["social"] as Map : {};
    final about = inf["about"]?.toString() ?? "";
    final name = inf["name"]?.toString() ?? "";

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kText),
        title: Text(name, style: const TextStyle(color: kText, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                : const Icon(Icons.share_rounded, color: kText),
            onPressed: _sharing ? null : _shareBrandedCard,
          ),
        ],
      ),
      body: Stack(children: [
        ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: _avatar(inf, 100)),
          const SizedBox(height: 14),
          Center(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kText))),
          const SizedBox(height: 2),
          Center(child: Text("${inf["city"] ?? ""} · ${inf["category"] ?? ""}",
            style: const TextStyle(fontSize: 13, color: kMuted))),
          const SizedBox(height: 8),
          Center(child: _ratingRow({"rating": _displayRating, "review_count": _displayReviewCount}, fontSize: 13)),
          const SizedBox(height: 16),
          // Item 10: Follow button removed (was local-only, never real).
          // Item 11: body "Share Profile" button removed — only the AppBar
          // share icon remains, now producing a branded share image
          // (see _buildAndShareCard below) instead of plain text.

          if (about.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text("About", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kText)),
            const SizedBox(height: 6),
            Text(about, style: const TextStyle(fontSize: 13, color: kText, height: 1.4)),
          ],

          const SizedBox(height: 24),
          const Text("Social", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kText)),
          const SizedBox(height: 4),
          _socialRow(social),

          const SizedBox(height: 24),
          const Text("Rate this influencer", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kText)),
          const SizedBox(height: 8),
          Row(children: List.generate(5, (i) {
            final filled = i < _myStars;
            return GestureDetector(
              onTap: () => setState(() => _myStars = i + 1),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(filled ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 30, color: const Color(0xFFFFB800)),
              ),
            );
          })),
          const SizedBox(height: 10),
          TextField(
            controller: _reviewC,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Share your experience (optional)",
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _submittingReview ? null : _submitReview,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: _submittingReview
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_myReviewId != null ? "Update Review" : "Submit Review", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),

          const SizedBox(height: 24),
          Row(children: [
            const Text("Reviews", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kText)),
            const Spacer(),
            if (_reviews.length > 2)
              GestureDetector(
                onTap: () => Navigator.push(context, _route(_InfluencerReviewsScreen(name: name, reviews: _reviews))),
                child: Text("See all (${_reviews.length})",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
              ),
          ]),
          const SizedBox(height: 6),
          if (_loadingReviews)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: kPrimary)))
          else if (_reviews.isEmpty)
            const Text("No reviews yet", style: TextStyle(fontSize: 12, color: kMuted))
          else
            ..._reviews.take(2).map((r) => _reviewTile(r)),
        ],
        ),
        // Off-screen branded share card — laid out and paintable, but never
        // visible to the user. Captured on demand by _shareBrandedCard().
        // Contains only public fields (name, category, rating, photo) — no
        // phone number, no internal ID, no API URL, nothing technical.
        Offstage(
          offstage: true,
          child: RepaintBoundary(
            key: _shareCardKey,
            child: Material(
              child: Container(
                width: 360,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3E5F55), Color(0xFF253D35)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(name,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text("OFFRO", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Center(child: _avatar(inf, 88)),
                  const SizedBox(height: 16),
                  if ((inf["category"]?.toString() ?? "").isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFFCDEBD6), borderRadius: BorderRadius.circular(20)),
                        child: Text(inf["category"].toString(),
                          style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
                    const SizedBox(width: 4),
                    Text(_displayRating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Text("(${_displayReviewCount} reviews)",
                      style: const TextStyle(color: Color(0xFFA9CDBA), fontSize: 12)),
                  ])),
                  const SizedBox(height: 20),
                  Container(height: 1, color: Colors.white12),
                  const SizedBox(height: 12),
                  const Row(children: [
                    Icon(Icons.download_rounded, color: Color(0xFFA9CDBA), size: 12),
                    SizedBox(width: 5),
                    Text("Discover creators • OFFRO",
                      style: TextStyle(color: Color(0xFFA9CDBA), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

Widget _reviewTile(Map review) {
  final stars = (review["rating"] as num?)?.toInt() ?? 0;
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text((review["user_name"] ?? review["user"])?.toString() ?? "Anonymous", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kText)),
        const Spacer(),
        Row(children: List.generate(5, (i) => Icon(
          i < stars ? Icons.star_rounded : Icons.star_border_rounded, size: 13, color: const Color(0xFFFFB800)))),
      ]),
      if ((review["text"]?.toString() ?? "").isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(review["text"].toString(), style: const TextStyle(fontSize: 12, color: kText)),
      ],
    ]),
  );
}

/// "See All Reviews" screen — UI only, backed by the same in-memory list.
class _InfluencerReviewsScreen extends StatelessWidget {
  final String name;
  final List<Map<String, dynamic>> reviews;
  const _InfluencerReviewsScreen({required this.name, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kText),
        title: Text("Reviews for $name", style: const TextStyle(color: kText, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reviews.length,
        itemBuilder: (ctx, i) => _reviewTile(reviews[i]),
      ),
    );
  }
}
