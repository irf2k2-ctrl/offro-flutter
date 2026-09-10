import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';

// ══════════════════════════════════════════════════════════
// INFLUENCER MODULE — Step 1: Home Screen UI only, mock data.
//
// FUTURE API SWAP: every screen/widget below reads influencer data through
// fetchInfluencers() at the bottom of this file. When the real backend
// exists, that single function is the only place that needs to change
// (swap its body for `Api.getInfluencers(city: city)`, matching the same
// field names already used here) — no other widget in this file, and
// nothing in home_screen.dart, needs to change.
//
// PRIVACY: the influencer data model deliberately has NO phone/mobile
// field anywhere — not hidden, not omitted from display, genuinely never
// modeled — so there is nothing that could accidentally leak onto a card
// or profile later.
// ══════════════════════════════════════════════════════════

/// Mock data provider. Returns the same shape the real `/influencers`
/// endpoint is expected to return later (see class docs above).
/// [city] is accepted now so call sites don't need to change when this
/// becomes a real network call — the mock simply filters in-memory.
Future<List<Map<String, dynamic>>> fetchInfluencers({required String city}) async {
  final all = _mockInfluencers;
  final matches = all.where((i) => i["city"].toString().toLowerCase() == city.toLowerCase()).toList();
  // Fallback so the section/listing still shows something on devices whose
  // selected city has no mock influencer yet — real API won't need this.
  return matches.isNotEmpty ? matches : all;
}

final List<Map<String, dynamic>> _mockInfluencers = [
  {
    "id": "inf_mock_001",
    "name": "Priya Sharma",
    "city": "Chennai",
    "category": "Lifestyle & Food",
    "photo_url": "",
    "rating": 4.8,
    "review_count": 126,
    "social": {
      "instagram": "https://instagram.com/priya.mock",
      "youtube": "",
      "facebook": "",
    },
  },
  {
    "id": "inf_mock_002",
    "name": "Arjun Vlogs",
    "city": "Chennai",
    "category": "Travel & Tech",
    "photo_url": "",
    "rating": 4.6,
    "review_count": 84,
    "social": {
      "instagram": "https://instagram.com/arjun.mock",
      "youtube": "https://youtube.com/@arjun.mock",
      "facebook": "",
    },
  },
  {
    "id": "inf_mock_003",
    "name": "Meera Fashion",
    "city": "Chennai",
    "category": "Fashion & Beauty",
    "photo_url": "",
    "rating": 4.9,
    "review_count": 203,
    "social": {
      "instagram": "https://instagram.com/meera.mock",
      "youtube": "",
      "facebook": "https://facebook.com/meera.mock",
    },
  },
];

Color _avatarColor(String seed) {
  final palette = [kLight, kBeige, kAccent];
  final idx = seed.isNotEmpty ? seed.codeUnitAt(0) % palette.length : 0;
  return palette[idx];
}

// Local route helper — home_screen.dart's `_route` is file-private and not
// visible here, so this mirrors it exactly for this file's own navigation.
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
        padding: EdgeInsets.symmetric(horizontal: widget.small ? 10 : 12, vertical: widget.small ? 4 : 5),
        decoration: BoxDecoration(
          color: _following ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kPrimary, width: 1),
        ),
        child: Text(_following ? "Following" : "Follow",
          style: TextStyle(
            fontSize: widget.small ? 11 : 12,
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

/// City Influencers — home screen section. Placed immediately after
/// Discover Products (see home_screen.dart). Mirrors the header layout
/// already used by _NearbyStoresSection for visual consistency.
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
              ? Center(child: Text("No influencers in ${widget.city} yet", style: const TextStyle(color: kMuted)))
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
                              const _FollowButton(),
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

/// Minimal profile screen — reached by tapping a card. Kept intentionally
/// simple for this UI-only step; will grow once real data/reviews exist.
class InfluencerProfileScreen extends StatelessWidget {
  final Map<String, dynamic> influencer;
  const InfluencerProfileScreen({super.key, required this.influencer});

  @override
  Widget build(BuildContext context) {
    final social = (influencer["social"] is Map) ? influencer["social"] as Map : {};
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kText),
        title: Text(influencer["name"]?.toString() ?? "Influencer",
          style: const TextStyle(color: kText, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: _avatar(influencer, 96)),
          const SizedBox(height: 14),
          Center(child: Text(influencer["name"]?.toString() ?? "",
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kText))),
          Center(child: Text("${influencer["city"] ?? ""} · ${influencer["category"] ?? ""}",
            style: const TextStyle(fontSize: 13, color: kMuted))),
          const SizedBox(height: 10),
          Center(child: _ratingRow(influencer, fontSize: 13)),
          const SizedBox(height: 16),
          Center(child: _socialIcons(social, size: 22)),
          const SizedBox(height: 20),
          Center(child: _FollowButton()),
        ]),
      ),
    );
  }
}
