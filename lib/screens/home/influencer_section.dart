import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
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
  if (photoUrl.startsWith("http") || photoUrl.startsWith("data:")) {
    // Real photo path — ready for when mock data is replaced with real URLs.
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: Image.network(photoUrl, width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(name, size)),
    );
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

/// Follow button. Local-only state for this step (no backend to persist
/// to yet) — resets on rebuild, which is expected until the real API
/// (follow/unfollow endpoint) exists.
class _FollowButton extends StatefulWidget {
  final bool small;
  const _FollowButton({this.small = false});
  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _following = !_following),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: widget.small ? 10 : 16, vertical: widget.small ? 4 : 8),
        decoration: BoxDecoration(
          color: _following ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(widget.small ? 8 : 10),
          border: Border.all(color: kPrimary, width: 1),
        ),
        child: Text(_following ? "Following" : "Follow",
          style: TextStyle(
            fontSize: widget.small ? 11 : 13,
            fontWeight: FontWeight.w700,
            color: _following ? Colors.white : kPrimary,
          )),
      ),
    );
  }
}

/// Home screen card — used inside the horizontal "City Influencers" row.
class _InfluencerCard extends StatelessWidget {
  final Map<String, dynamic> influencer;
  const _InfluencerCard({required this.influencer});

  @override
  Widget build(BuildContext context) {
    final name = influencer["name"]?.toString() ?? "";
    final city = influencer["city"]?.toString() ?? "";
    final social = (influencer["social"] is Map) ? influencer["social"] as Map : {};

    return GestureDetector(
      onTap: () => Navigator.push(context, _route(InfluencerProfileScreen(influencer: influencer))),
      child: Container(
        width: 128,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AspectRatio(aspectRatio: 1, child: _avatar(influencer, 108)),
            Positioned(
              top: 4, right: 4,
              child: Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: _socialIcons(social, size: 11),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kText)),
          Text(city, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: kMuted)),
          const SizedBox(height: 4),
          _ratingRow(influencer),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: Center(child: _FollowButton(small: true))),
        ]),
      ),
    );
  }
}

/// City Influencers — home screen section.
class CityInfluencersSection extends StatefulWidget {
  final String city;
  const CityInfluencersSection({super.key, required this.city});

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("City influencers", style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w800)),
              Text("Discover creators from your city", style: TextStyle(color: kMuted, fontSize: 12)),
            ]),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context, _route(InfluencerListingScreen(city: widget.city))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kLight.withValues(alpha: .5), borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text("View all", style: TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_rounded, size: 12, color: kPrimary),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: influencers.length,
            itemBuilder: (ctx, i) => _InfluencerCard(influencer: influencers[i]),
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
  const InfluencerListingScreen({super.key, required this.city});

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
                      onTap: () => Navigator.push(context, _route(InfluencerProfileScreen(influencer: inf))),
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
                              const _FollowButton(small: true),
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
  const InfluencerProfileScreen({super.key, required this.influencer});

  @override
  State<InfluencerProfileScreen> createState() => _InfluencerProfileScreenState();
}

class _InfluencerProfileScreenState extends State<InfluencerProfileScreen> {
  int _myStars = 0;
  final _reviewC = TextEditingController();
  List<Map<String, dynamic>> _reviews = [];

  // In-session-only aggregate display (never sent to a backend). Seeded
  // from the influencer's initial rating/review_count, then recomputed
  // locally whenever the user submits a review here, so the header stays
  // consistent with the review list for the rest of this screen's life.
  late double _displayRating;
  late int _displayReviewCount;

  @override
  void initState() {
    super.initState();
    final raw = widget.influencer["reviews"];
    _reviews = raw is List ? List<Map<String, dynamic>>.from(raw) : [];
    _displayRating = (widget.influencer["rating"] as num?)?.toDouble() ?? 0.0;
    _displayReviewCount = (widget.influencer["review_count"] as num?)?.toInt() ?? 0;
  }

  @override
  void dispose() {
    _reviewC.dispose();
    super.dispose();
  }

  void _submitReview() {
    if (_myStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a star rating first")));
      return;
    }
    // UI-only for this step — not persisted to any backend. Updates the
    // in-session review list AND recomputes the displayed aggregate
    // rating/count the same way the backend eventually will (simple
    // running average), so the header and the review list stay consistent
    // with each other for the rest of this session.
    setState(() {
      _reviews.insert(0, {"user": "You", "rating": _myStars, "text": _reviewC.text.trim()});
      final newCount = _displayReviewCount + 1;
      _displayRating = ((_displayRating * _displayReviewCount) + _myStars) / newCount;
      _displayReviewCount = newCount;
      _myStars = 0;
      _reviewC.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Thanks for your review!")));
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
            icon: const Icon(Icons.share_rounded, color: kText),
            onPressed: () => Share.share(_shareText(inf), subject: "OffrO – $name"),
          ),
        ],
      ),
      body: ListView(
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
          Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const _FollowButton(),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => Share.share(_shareText(inf), subject: "OffrO – $name"),
              icon: const Icon(Icons.ios_share_rounded, size: 16, color: kPrimary),
              label: const Text("Share Profile", style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: kPrimary), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            ),
          ])),

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
            onPressed: _submitReview,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Submit Review", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
          if (_reviews.isEmpty)
            const Text("No reviews yet", style: TextStyle(fontSize: 12, color: kMuted))
          else
            ..._reviews.take(2).map((r) => _reviewTile(r)),
        ],
      ),
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
        Text(review["user"]?.toString() ?? "Anonymous", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kText)),
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
