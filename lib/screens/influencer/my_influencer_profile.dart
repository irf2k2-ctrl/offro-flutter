import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/india_locations.dart' show kIndiaStates, kIndiaCities;
import '../../core/services/api_service.dart';
import '../../core/services/error_mapper.dart';
import '../auth/login_screen.dart' show SwitchModeSheet;
import '../../core/design/design.dart' show OffroColors, OffroText, OffroRadii, OffroShadows, OffroSpacing, OffroButton, OffroCard, OffroIcons, OffroIcon, OffroIconData, OffroTones, OffroBottomNav, OffroNavVariant, OffroNavItem, OffroScreenHeader;
import '../../core/widgets/brand_logo.dart' show buildImageLogo;
import '../merchant/merchant_screens.dart' show merchantHeaderBar;
import '../collab/collab_screens.dart' show InfluencerOpportunitiesView, CampaignOpportunitiesSection;

/// Local equivalent of the file-private `_timeAgo()` helpers already used
/// elsewhere (lib/main.dart, notifications_page.dart) — same exact pattern,
/// just written here since a leading-underscore top-level function is
/// private to its own file and cannot be imported across files in Dart.
///
/// BUG FIX (Round 4 — Bug 2, "review shows 5h ago instead of just now"):
/// the backend stores/returns UTC timestamps, but historically without an
/// explicit timezone suffix (a naive ISO string). DateTime.parse() treats
/// a timezone-less string as LOCAL time rather than UTC, so on a device in
/// IST (UTC+5:30) the parsed instant ended up 5.5 hours in the future
/// relative to the real (UTC) instant, making "just now" render as "5h
/// ago" — exactly the reported symptom, and exactly matching IST's offset.
/// Fixed by explicitly forcing UTC interpretation whenever the string has
/// no timezone marker of its own, rather than trusting DateTime.parse's
/// default (which silently assumes local time). This is correct for both
/// old (naive) and new (now explicitly "Z"-suffixed by the backend)
/// timestamps — a string that already carries a marker is left untouched.
DateTime _parseServerTimestamp(String isoTs) {
  final s = isoTs.trim();
  final hasTzMarker = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(s);
  return DateTime.parse(hasTzMarker ? s : '${s}Z');
}

String _reviewTimeAgo(String isoTs) {
  try {
    final dt   = _parseServerTimestamp(isoTs);
    final diff = DateTime.now().toUtc().difference(dt);
    if (diff.inMinutes < 1)  return "just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours  < 24)  return "${diff.inHours}h ago";
    if (diff.inDays   < 7)   return "${diff.inDays}d ago";
    return "${(diff.inDays / 7).floor()}w ago";
  } catch (_) { return ""; }
}

// ══════════════════════════════════════════════════════════
// C2 — INFLUENCER MODULE (authenticated, owner-only)
//
// This is deliberately SEPARATE from the public, customer-facing
// InfluencerProfileScreen in lib/screens/home/influencer_section.dart —
// that screen is for browsing OTHER influencers (read-only, submits a
// review ABOUT them). This file is the authenticated owner's own
// create/view/edit management screen, per the explicit separation
// required for C2.
//
// Data source: exclusively the C1 authenticated endpoints
// (GET/POST/PUT /user/influencer-profile). No separate local model —
// whatever the backend returns is what's shown, refetched after every
// save so the screen never drifts from db.influencers.
//
// Reused from Merchant/Store, not reinvented:
// - State/City: kIndiaStates / kIndiaCities (lib/screens/merchant/merchant_screens.dart)
// - Categories: Api.fetchCategories() (same source Product/Store forms use)
// - Photo: ImagePicker + base64 "data:image/jpeg;base64,..." + 2MB client
//   guard — the exact pattern used in merchant_screens.dart's _pickImage()
// ══════════════════════════════════════════════════════════

// Round 9: the local _friendlyError() that used to live here has been
// generalized into the shared lib/core/services/error_mapper.dart
// (friendlyError()) so every screen uses the same classifier instead of
// each reinventing its own. Call sites below now call friendlyError(e)
// directly — behavior is unchanged for this screen's existing messages.

/// Entry point: decides Create vs View based on the authenticated
/// account's own profile — never asks the user for an account_id or
/// influencer_id.
class InfluencerModuleScreen extends StatefulWidget {
  final String token;
  final String phone;
  final String currentMode; // C4: needed for the Switch Mode entry point below
  final void Function(String role)? onSwitchMode;
  const InfluencerModuleScreen({
    super.key,
    required this.token,
    this.phone = '',
    this.currentMode = 'influencer',
    this.onSwitchMode,
  });

  @override
  State<InfluencerModuleScreen> createState() => _InfluencerModuleScreenState();
}

class _InfluencerModuleScreenState extends State<InfluencerModuleScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile; // null = not loaded yet or error; {} = no profile; populated = has profile

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await Api.getMyInfluencerProfile(widget.token);
      if (!mounted) return;
      setState(() { _profile = p; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  /// Applies whatever InfluencerProfileFormScreen popped back with. Payment
  /// verification (Save & Publish) can succeed server-side while the
  /// immediately-following profile refetch fails on the client (a separate,
  /// unrelated network hiccup) — the form signals that case with a
  /// `{"_needs_refresh": true}` sentinel instead of guessing at profile
  /// data. That sentinel is never treated as real profile content; it
  /// always triggers a full, correct reload here instead.
  void _applyProfileUpdate(Map<String, dynamic> updated) {
    if (updated.containsKey("_needs_refresh")) {
      _load();
    } else {
      setState(() => _profile = updated);
      // Never trust only what the form handed back (e.g. a draft copy sent before a
      // free / 100%-discount publish): re-read the real profile from the backend.
      _refreshProfileSilently();
    }
  }

  /// Re-reads the profile from the backend WITHOUT a loading spinner or error state, so Home
  /// and Profile always reflect the real payment/publish status (used after save/publish/pay
  /// and whenever the person returns to Home).
  Future<void> _refreshProfileSilently() async {
    try {
      final p = await Api.getMyInfluencerProfile(widget.token);
      if (!mounted || p.isEmpty) return;
      setState(() => _profile = p);
    } catch (_) {
      // keep what we have; pull-to-refresh / next visit retries
    }
  }

  // Workspace tab: 0 Home, 1 Opportunities, 2 Activity, 3 Profile.
  int _tab = 0;

  /// C4: same Switch Mode sheet already used by User/Merchant — unchanged
  /// behaviour. Only wired when a parent supplies onSwitchMode.
  void _openSwitchMode() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SwitchModeSheet(
          currentMode: widget.currentMode,
          token: widget.token,
          phone: widget.phone,
          onSwitch: widget.onSwitchMode!,
        ),
      );

  bool get _hasProfile => !_loading && _error == null && (_profile ?? {}).isNotEmpty;

  List<Widget> _headerActions() => [
        if (widget.onSwitchMode != null)
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: OffroColors.text),
            tooltip: "Switch Mode",
            onPressed: _openSwitchMode,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        backgroundColor: OffroColors.background,
        appBar: (_tab == 2 && !_hasProfile)
            ? merchantHeaderBar(
                eyebrow: "Creator account",
                title: "Profile",
                back: Navigator.canPop(context),
                actions: _headerActions(),
              )
            : null,
        body: _tabBody(),
        bottomNavigationBar: OffroBottomNav(
          variant: OffroNavVariant.merchant,
          currentIndex: _tab,
          onTap: (i) {
            setState(() => _tab = i);
            if (i == 0 || i == 2) _refreshProfileSilently();
          },
          items: const [
            OffroNavItem(label: 'Home', icon: OffroIcons.home, fillWhenActive: true),
            OffroNavItem(label: 'Opportunities', icon: OffroIcons.sparkles),
            OffroNavItem(label: 'Profile', icon: OffroIcons.user),
          ],
        ),
      ),
    );
  }

  Widget _tabBody() {
    switch (_tab) {
      case 1:
        return InfluencerOpportunitiesView(
          token: widget.token,
          headerTrailing: widget.onSwitchMode == null
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: _headerActions()),
        );
      case 2:
        return _buildBody();
      default:
        return _buildHome();
    }
  }

  Widget _statTile(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: OffroColors.surface,
            borderRadius: BorderRadius.circular(OffroRadii.card),
            boxShadow: OffroShadows.card,
          ),
          child: Column(children: [
            Text(value, style: OffroText.title.copyWith(fontSize: 20)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: OffroText.caption.copyWith(color: OffroColors.secondarySolid)),
          ]),
        ),
      );

  /// Influencer Home — real profile data only (name, category, city, views,
  /// saves, reviews, publish state). Campaign opportunities come from the
  /// collaboration backend (pending requests only).
  Widget _buildHome() {
    if (_loading || _error != null || (_profile ?? {}).isEmpty) {
      return SafeArea(child: _buildBody());
    }
    final p = _profile!;
    final name = p["name"]?.toString() ?? "";
    final first = name.trim().split(' ').first;
    final cats = (p["categories"] is List)
        ? (p["categories"] as List).map((c) => c.toString()).toList()
        : <String>[];
    final cat = cats.isNotEmpty ? cats.first : (p["category"]?.toString() ?? "");
    final city = p["city"]?.toString() ?? "";
    final views = (p["view_count"] as num?)?.toInt() ?? 0;
    final saves = (p["favorite_count"] as num?)?.toInt() ?? 0;
    final reviews = (p["review_count"] as num?)?.toInt() ?? 0;
    // Same defaults the Profile tab uses: a missing payment/publish field (older profiles) counts as PAID / published.
    final live = (p["payment_status"]?.toString() ?? "PAID") == "PAID" && (p["publish_status"]?.toString() ?? "published") == "published";
    final sub = [cat, city].where((e) => e.isNotEmpty).join(' · ');
    return RefreshIndicator(
      color: OffroColors.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: OffroColors.mint,
            padding: EdgeInsets.fromLTRB(OffroSpacing.gutter, MediaQuery.of(context).padding.top + 20, OffroSpacing.gutter, 36),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                buildImageLogo(height: 26),
                const Spacer(),
                if (widget.onSwitchMode != null)
                  IconButton(
                    icon: const Icon(Icons.swap_horiz_rounded, color: OffroColors.primary),
                    tooltip: "Switch Mode",
                    onPressed: _openSwitchMode,
                  ),
              ]),
              const SizedBox(height: 28),
              Text('CREATOR WORKSPACE', style: OffroText.eyebrow.copyWith(color: OffroColors.sageStrong)),
              const SizedBox(height: 4),
              Text(first.isEmpty ? 'Welcome back' : 'Welcome back, $first', style: OffroText.headline),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(sub, style: OffroText.body.copyWith(color: OffroColors.secondarySolid)),
              ],
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -14),
            child: Padding(
              padding: OffroSpacing.gutterH,
              child: Row(children: [
                _statTile('$views', 'Profile views'),
                const SizedBox(width: 8),
                _statTile('$saves', 'Saved by'),
                const SizedBox(width: 8),
                _statTile('$reviews', 'Reviews'),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 14, OffroSpacing.gutter, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              OffroCard(
                onTap: () => setState(() => _tab = 2),
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: OffroColors.mint, borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.center,
                    child: const OffroIcon(OffroIcons.user, size: 20, color: OffroColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(live ? "Your profile is live" : "Your profile isn't live yet",
                        style: OffroText.value.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(live ? "Merchants and customers can discover you." : "Open your profile to review and publish it.",
                        style: OffroText.caption.copyWith(color: OffroColors.secondarySolid)),
                  ])),
                  const OffroIcon(OffroIcons.chevron, size: 14, color: OffroColors.secondarySolid),
                ]),
              ),
              const SizedBox(height: 28),
              Text('MATCHED FOR YOU', style: OffroText.eyebrow.copyWith(color: OffroColors.sageStrong)),
              const SizedBox(height: 4),
              Text('Campaign opportunities', style: OffroText.title),
              const SizedBox(height: 14),
              CampaignOpportunitiesSection(
                token: widget.token,
                onSeeAll: () => setState(() => _tab = 1),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 40, color: kMuted),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor: kPrimary),
              child: const Text("Try Again", style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      );
    }
    final profile = _profile ?? {};
    if (profile.isEmpty) {
      return _buildEmptyState();
    }
    return _MyInfluencerProfileView(
      token: widget.token,
      profile: profile,
      onProfileUpdated: _applyProfileUpdate,
      phone: widget.phone,
      onSwitchMode: widget.onSwitchMode == null ? null : _openSwitchMode,
      // Delete (rule 4 — permanent): returning to the empty state ({}) is
      // exactly what InfluencerModuleScreen already renders for "no profile
      // yet" — the same _buildEmptyState() a brand-new influencer sees. A
      // future "Add Influencer Profile" from here creates a genuinely new
      // profile/payment relationship server-side (see routers/users.py
      // delete_my_influencer_profile), so there is nothing special to do
      // here beyond clearing local state.
      onProfileDeleted: () => setState(() => _profile = {}),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: OffroTones.fashion.background, borderRadius: BorderRadius.circular(28)),
            alignment: Alignment.center,
            child: OffroIcon(OffroIcons.sparkles, size: 32, color: OffroTones.fashion.foreground),
          ),
          const SizedBox(height: 24),
          Text('INFLUENCER WORKSPACE', style: OffroText.eyebrow.copyWith(color: OffroColors.sageStrong)),
          const SizedBox(height: 8),
          Text("Create your local profile.", textAlign: TextAlign.center, style: OffroText.headline),
          const SizedBox(height: 10),
          Text("You'll need an Influencer profile to use the Influencer module — it's how customers and merchants discover you on OffrO.",
              textAlign: TextAlign.center, style: OffroText.body),
          const SizedBox(height: 28),
          OffroButton(
            label: "+ Add influencer profile",
            expand: false,
            onPressed: () async {
              final created = await Navigator.push<Map<String,dynamic>>(context,
                MaterialPageRoute(builder: (_) => InfluencerProfileFormScreen(
                  token: widget.token, existing: null, onProfileSaved: _applyProfileUpdate)));
              if (created != null && mounted) _applyProfileUpdate(created);
            },
          ),
        ]),
      ),
    );
  }
}

/// "My Influencer Profile" — the owner's own management view. Distinct
/// from the public InfluencerProfileScreen (no review-submission UI, no
/// Follow, no Share — it's a self-management screen, not a browse screen).
class _MyInfluencerProfileView extends StatefulWidget {
  final String token;
  final Map<String, dynamic> profile;
  final void Function(Map<String,dynamic>) onProfileUpdated;
  final VoidCallback onProfileDeleted;
  final String phone;
  final VoidCallback? onSwitchMode; // null = no Switch Mode row (no parent handler)
  const _MyInfluencerProfileView({
    required this.token,
    required this.profile,
    required this.onProfileUpdated,
    required this.onProfileDeleted,
    this.phone = '',
    this.onSwitchMode,
  });

  @override
  State<_MyInfluencerProfileView> createState() => _MyInfluencerProfileViewState();
}

class _MyInfluencerProfileViewState extends State<_MyInfluencerProfileView> {
  bool _busy = false; // guards Enable/Disable and Delete from double-taps

  String get token => widget.token;
  Map<String, dynamic> get profile => widget.profile;
  void Function(Map<String,dynamic>) get onProfileUpdated => widget.onProfileUpdated;

  // ── Reviews (real data, never hardcoded — same endpoints already used by
  // the public InfluencerProfileScreen) ──
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  String get _influencerId => profile["_id"]?.toString() ?? "";

  Future<void> _loadReviews() async {
    final id = _influencerId;
    if (id.isEmpty) { if (mounted) setState(() => _loadingReviews = false); return; }
    try {
      final resp = await Api.getInfluencerReviews(id, limit: 3);
      if (!mounted) return;
      final list = resp["reviews"];
      setState(() {
        _reviews = list is List ? List<Map<String, dynamic>>.from(list) : [];
        _loadingReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Widget _avatar(double size) {
    final name = profile["name"]?.toString() ?? "?";
    final photoUrl = profile["photo_url"]?.toString() ?? "";
    Widget fallback() => Container(
      width: size, height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: OffroColors.primary),
      alignment: Alignment.center,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?",
        style: OffroText.cardTitle.copyWith(fontSize: size * 0.3, color: Colors.white)),
    );
    if (photoUrl.startsWith("http")) {
      return SizedBox(
        width: size, height: size,
        child: ClipOval(child: CachedNetworkImage(imageUrl: photoUrl, width: size, height: size, fit: BoxFit.cover,
          placeholder: (_, __) => fallback(), errorWidget: (_, __, ___) => fallback())),
      );
    }
    return fallback();
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<Map<String,dynamic>>(context,
      MaterialPageRoute(builder: (_) => InfluencerProfileFormScreen(
        token: token, existing: profile, onProfileSaved: onProfileUpdated)));
    if (updated != null) onProfileUpdated(updated);
  }

  // ── Profile layout — mirrors the Customer ProfileTab (lib/screens/home/
  // profile_tab.dart): OffroScreenHeader, mint identity card, eyebrow-headed
  // surface cards with 36px mint icon circles. Those helpers are private to
  // ProfileTab, so the same styling is mirrored here rather than editing the
  // Customer screen. ──
  static const _eyebrowGap = 12.0;

  Widget _eyebrow(String text) => Text(text.toUpperCase(),
      style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.8, color: OffroColors.sage));

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(text, style: OffroText.cardTitle.copyWith(fontSize: 13)),
      );

  Widget _card(List<Widget> rows) => Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: OffroColors.surface, borderRadius: BorderRadius.circular(22)),
        child: Column(children: rows),
      );

  Widget _iconCircle(Widget icon, {bool destructive = false}) => Container(
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: destructive ? OffroColors.error.withValues(alpha: .10) : OffroColors.mintSoft,
          shape: BoxShape.circle,
        ),
        child: icon,
      );

  /// Tappable action row (same look as ProfileTab._row).
  Widget _actionRow({
    required Widget icon,
    required String label,
    String? note,
    required VoidCallback? onTap,
    bool destructive = false,
    bool last = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: Color(0x0D000000))),
        ),
        child: Row(children: [
          _iconCircle(icon, destructive: destructive),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: OffroText.cardTitle.copyWith(
              fontSize: 13, color: destructive ? OffroColors.error : OffroColors.text)),
            if (note != null) ...[
              const SizedBox(height: 2),
              Text(note, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textFaint)),
            ],
          ])),
          if (!destructive) const OffroIcon(OffroIcons.chevron, size: 14, color: OffroColors.sage),
        ]),
      ),
    );
  }

  /// Read-only detail row (label above value); tapping opens Edit.
  Widget _infoRow(Widget icon, String label, String value, {bool last = false, int maxLines = 2}) {
    final has = value.trim().isNotEmpty;
    return InkWell(
      onTap: _openEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: Color(0x0D000000))),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _iconCircle(icon),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textFaint)),
            const SizedBox(height: 2),
            Text(has ? value : "Not added", maxLines: maxLines, overflow: TextOverflow.ellipsis,
              style: OffroText.cardTitle.copyWith(fontSize: 13,
                color: has ? OffroColors.text : OffroColors.textFaint,
                fontWeight: has ? FontWeight.w600 : FontWeight.w400)),
          ])),
        ]),
      ),
    );
  }

  Widget _identityCard(String name, String phone) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: OffroColors.mint, borderRadius: BorderRadius.circular(26)),
      child: Row(children: [
        GestureDetector(
          onTap: _openEdit, // photo is changed in the Edit form (same as the old camera badge)
          child: Stack(alignment: Alignment.bottomRight, children: [
            _avatar(64),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: OffroColors.surface, shape: BoxShape.circle,
                border: Border.all(color: OffroColors.mint, width: 1.5)),
              child: const Icon(Icons.camera_alt, size: 10, color: OffroColors.primary),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isEmpty ? "OffrO Influencer" : name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: OffroText.cardTitle.copyWith(fontSize: 16)),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(phone, style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400,
              color: OffroColors.primary.withValues(alpha: .65))),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .55), borderRadius: OffroRadii.pillRadius),
            child: Text("OffrO Influencer",
              style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: OffroColors.primary)),
          ),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = profile["name"]?.toString() ?? "";
    // `categories` is always present (the backend derives it on read, even
    // for legacy records); fall back to the legacy single `category`.
    final categoriesList = (profile["categories"] is List)
        ? (profile["categories"] as List).map((c) => c.toString()).toList()
        : <String>[];
    final legacyCategory = profile["category"]?.toString() ?? "";
    final displayCategories = categoriesList.isNotEmpty
        ? categoriesList
        : (legacyCategory.isNotEmpty ? [legacyCategory] : <String>[]);
    final city = profile["city"]?.toString() ?? "";
    final state = profile["state"]?.toString() ?? "";
    final bio = profile["bio"]?.toString() ?? "";
    final social = (profile["social"] is Map) ? profile["social"] as Map : {};
    final phone = widget.phone.isNotEmpty ? widget.phone : (profile["phone"]?.toString() ?? "");
    String s(String k) => (social[k] ?? "").toString();
    final topPad = MediaQuery.of(context).padding.top;

    return RefreshIndicator(
      color: OffroColors.primary,
      onRefresh: () async {
        try {
          final fresh = await Api.getMyInfluencerProfile(token);
          onProfileUpdated(fresh);
        } catch (_) {}
        await _loadReviews();
      },
      child: ListView(
        padding: EdgeInsets.only(top: topPad, bottom: 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          OffroScreenHeader(eyebrow: "Creator account", title: "Profile", showBack: Navigator.canPop(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 24, OffroSpacing.gutter, 0),
            child: _identityCard(name, phone),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 0, OffroSpacing.gutter, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Draft / pending / failed payment state + one-tap Pay Now (unchanged logic).
              if (!(_paymentStatus == "PAID" && _publishStatus == "published")) const SizedBox(height: 16),
              _buildSubscriptionStatusBanner(),
              if (_paymentStatus != "PAID")
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _openEdit,
                    icon: const Icon(Icons.payment_rounded, size: 16, color: Colors.white),
                    label: const Text("Continue Publishing / Pay Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: OffroColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12), shape: const StadiumBorder()),
                  )),
                ),

              // ── MY PROFILE ──
              const SizedBox(height: 28),
              _eyebrow("My profile"),

              _sectionTitle("Business Details"),
              _card([
                _infoRow(const OffroIcon(OffroIcons.user, size: 16, color: OffroColors.primary), "Display Name", name),
                _infoRow(const OffroIcon(OffroIcons.message, size: 16, color: OffroColors.primary), "Bio", bio, maxLines: 3),
                _infoRow(const OffroIcon(OffroIcons.pin, size: 16, color: OffroColors.primary), "State", state),
                _infoRow(const OffroIcon(OffroIcons.pin, size: 16, color: OffroColors.primary), "City", city, last: true),
              ]),

              _sectionTitle("Social Pages"),
              _card([
                _infoRow(const Icon(Icons.camera_alt_rounded, size: 16, color: Color(0xFFD4537E)), "Instagram", s("instagram"), maxLines: 1),
                _infoRow(const Icon(Icons.facebook_rounded, size: 16, color: Color(0xFF378ADD)), "Facebook", s("facebook"), maxLines: 1),
                _infoRow(const Icon(Icons.play_circle_fill_rounded, size: 16, color: Color(0xFFE24B4A)), "YouTube", s("youtube"), maxLines: 1, last: true),
              ]),

              _sectionTitle("Primary Specialty"),
              _card([
                InkWell(
                  onTap: _openEdit,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: displayCategories.isEmpty
                        ? Text("No specialty selected", style: OffroText.caption.copyWith(fontSize: 12, color: OffroColors.textFaint))
                        : SizedBox(width: double.infinity, child: _categoryChips(displayCategories)),
                  ),
                ),
              ]),

              _sectionTitle("Account Details"),
              _card([
                _actionRow(
                  icon: const OffroIcon(OffroIcons.user, size: 16, color: OffroColors.primary),
                  label: "Edit", note: "Update your profile details", onTap: _openEdit),
                _actionRow(
                  icon: Icon(_isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16, color: OffroColors.primary),
                  label: _isActive ? "Disable" : "Enable",
                  note: _isActive ? "Hide your profile from customers" : "Make your profile visible again",
                  onTap: _busy ? null : _toggleActive),
                _actionRow(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: OffroColors.error),
                  label: "Delete", destructive: true, last: true,
                  onTap: _busy ? null : _confirmDelete),
              ]),

              // ── Reviews (real data — never hardcoded example businesses) ──
              const SizedBox(height: 28),
              Row(children: [
                Expanded(child: _eyebrow("Reviews")),
                if (_reviews.isNotEmpty)
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _MyInfluencerAllReviewsScreen(influencerId: _influencerId, name: name))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Text("See all", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kPrimary)),
                      Icon(Icons.chevron_right_rounded, size: 16, color: kPrimary),
                    ]),
                  ),
              ]),
              const SizedBox(height: _eyebrowGap),
              if (_loadingReviews)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: kPrimary)))
              else if (_reviews.isEmpty)
                _card([
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      _iconCircle(const Icon(Icons.star_border_rounded, size: 16, color: OffroColors.primary)),
                      const SizedBox(width: 12),
                      Text("No reviews yet", style: OffroText.caption.copyWith(fontSize: 12, color: OffroColors.textFaint)),
                    ]),
                  ),
                ])
              else
                ..._reviews.map((r) => _reviewCard(r)),

              // ── ACCOUNT — Switch Mode only (same SwitchModeSheet as Customer/Merchant) ──
              if (widget.onSwitchMode != null) ...[
                const SizedBox(height: 28),
                _eyebrow("Account"),
                const SizedBox(height: _eyebrowGap),
                _card([
                  _actionRow(
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: OffroColors.primary),
                    label: "Switch Mode", note: "Switch to your Customer account",
                    onTap: widget.onSwitchMode, last: true),
                ]),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  /// Selected specialties as small chips (all of them, no cap).
  Widget _categoryChips(List<String> categories) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final c in categories)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: OffroColors.mintSoft, borderRadius: OffroRadii.pillRadius),
          child: Text(c, style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: OffroColors.primary)),
        ),
    ]);
  }

  /// Real review card — reviewer name/rating/date/text, sourced entirely
  /// from Api.getInfluencerReviews (the same data the public profile screen
  /// shows). No example/placeholder reviews are ever rendered here. A
  /// trailing chevron was added purely as a visual affordance (matches the
  /// reference) — the card isn't tappable, same as before.
  /// The optional review image (`image_url`/`photo_url`, whichever the
  /// payload happens to carry) is shown only "where available" — current
  /// review submissions never attach one, so this stays dormant until/
  /// unless the backend starts sending it; nothing here requires that field.
  Widget _reviewCard(Map<String, dynamic> r) {
    final reviewerName = (r["user_name"] ?? r["user"])?.toString() ?? "Anonymous";
    final stars = (r["rating"] as num?)?.toInt() ?? 0;
    final text = r["text"]?.toString() ?? "";
    final ts = r["created_at"]?.toString() ?? "";
    final ago = ts.isNotEmpty ? _reviewTimeAgo(ts) : "";
    final imageUrl = (r["image_url"] ?? r["photo_url"])?.toString() ?? "";
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (imageUrl.startsWith("http")) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(imageUrl: imageUrl, width: 46, height: 46, fit: BoxFit.cover,
              placeholder: (_, __) => Container(width: 46, height: 46, color: kLight),
              errorWidget: (_, __, ___) => Container(width: 46, height: 46, color: kLight)),
          ),
          const SizedBox(width: 12),
        ] else ...[
          Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: kLight),
            alignment: Alignment.center,
            child: Text(reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : "?",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kPrimary)),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(reviewerName, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kText))),
            Row(children: List.generate(5, (i) => Icon(
              i < stars ? Icons.star_rounded : Icons.star_border_rounded, size: 12, color: const Color(0xFFFFB800)))),
          ]),
          if (ago.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(ago, style: const TextStyle(fontSize: 10.5, color: kMuted)),
          ],
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 12, color: kText, height: 1.35)),
          ],
        ])),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, size: 18, color: kMuted),
      ]),
    );
  }

  // Missing payment_status/publish_status/is_active (any profile that
  // predates this feature, or an admin-created one) is always treated as
  // already paid/published/active — matching the backend's own backward-
  // compatibility default exactly, never showing a false "unpaid" state for
  // an existing profile.
  bool get _isActive => profile["is_active"] != false;
  String get _paymentStatus => profile["payment_status"]?.toString() ?? "PAID";
  String get _publishStatus => profile["publish_status"]?.toString() ?? "published";

  Widget _buildSubscriptionStatusBanner() {
    if (_paymentStatus == "PAID" && _publishStatus == "published") {
      return const SizedBox.shrink(); // fully normal state — nothing to call out
    }
    String text; Color color; IconData icon;
    if (_publishStatus == "draft" && _paymentStatus != "PAID") {
      text = "Your profile is saved as a draft. Complete the one-time subscription payment from Edit Profile → Save & Publish to make it visible to customers.";
      color = const Color(0xFFB8860B); icon = Icons.info_outline_rounded;
    } else if (_paymentStatus == "PAYMENT_PENDING") {
      text = "Payment is being processed. If you completed a payment and this doesn't update, try Save & Publish again.";
      color = const Color(0xFFB8860B); icon = Icons.hourglass_top_rounded;
    } else if (_paymentStatus == "PAYMENT_FAILED") {
      text = "Your last subscription payment attempt failed. Please try Save & Publish again to complete payment.";
      color = Colors.red; icon = Icons.error_outline_rounded;
    } else {
      text = "Your profile is not yet published.";
      color = const Color(0xFFB8860B); icon = Icons.info_outline_rounded;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color, height: 1.4))),
      ]),
    );
  }

  Future<void> _toggleActive() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Api.updateMyInfluencerProfile(token, {"is_active": !_isActive});
      final fresh = await Api.getMyInfluencerProfile(token);
      if (mounted) onProfileUpdated(fresh);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    // Exact confirmation dialog title/body/buttons as required — permanent,
    // and a future new profile will require a new payment (rule 4/5).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Influencer Profile?"),
        content: const Text(
          "Are you sure you want to delete your influencer profile? This action cannot be undone.\n\n"
          "If you create a new influencer profile in the future, a new subscription payment will be required."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete Profile", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await Api.deleteInfluencerProfile(token);
      if (mounted) widget.onProfileDeleted();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// "See all reviews" screen for the owner's own profile — fetches the full
/// real review list (not just the 3-card preview shown on the home screen).
/// A local equivalent of the existing public-profile "_InfluencerReviewsScreen"
/// (influencer_section.dart), which is file-private and cannot be reused here.
class _MyInfluencerAllReviewsScreen extends StatefulWidget {
  final String influencerId;
  final String name;
  const _MyInfluencerAllReviewsScreen({required this.influencerId, required this.name});

  @override
  State<_MyInfluencerAllReviewsScreen> createState() => _MyInfluencerAllReviewsScreenState();
}

class _MyInfluencerAllReviewsScreenState extends State<_MyInfluencerAllReviewsScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.influencerId.isEmpty) { setState(() => _loading = false); return; }
    try {
      final resp = await Api.getInfluencerReviews(widget.influencerId, limit: 100);
      if (!mounted) return;
      final list = resp["reviews"];
      setState(() {
        _reviews = list is List ? List<Map<String, dynamic>>.from(list) : [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: merchantHeaderBar(
        eyebrow: "Creator reviews",
        title: "Reviews for ${widget.name}",
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _reviews.isEmpty
              ? const Center(child: Text("No reviews yet", style: TextStyle(fontSize: 13, color: kMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reviews.length,
                  itemBuilder: (ctx, i) {
                    final r = _reviews[i];
                    final reviewerName = (r["user_name"] ?? r["user"])?.toString() ?? "Anonymous";
                    final stars = (r["rating"] as num?)?.toInt() ?? 0;
                    final text = r["text"]?.toString() ?? "";
                    final ts = r["created_at"]?.toString() ?? "";
                    final ago = ts.isNotEmpty ? _reviewTimeAgo(ts) : "";
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 34, height: 34,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: kLight),
                          alignment: Alignment.center,
                          child: Text(reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : "?",
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(reviewerName, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kText))),
                            Row(children: List.generate(5, (i) => Icon(
                              i < stars ? Icons.star_rounded : Icons.star_border_rounded, size: 12, color: const Color(0xFFFFB800)))),
                          ]),
                          if (ago.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(ago, style: const TextStyle(fontSize: 10.5, color: kMuted)),
                          ],
                          if (text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(text, style: const TextStyle(fontSize: 12, color: kText, height: 1.35)),
                          ],
                        ])),
                      ]),
                    );
                  },
                ),
    );
  }
}

/// Shared Add/Edit form — `existing == null` means create mode (POST),
/// otherwise edit mode (PUT). Never sends account_id or influencer_id;
/// ownership is entirely determined server-side from the auth token.
class InfluencerProfileFormScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? existing;
  // Fired as soon as the profile is known to exist server-side — right
  // after a brand-new profile's create call succeeds, BEFORE Razorpay even
  // opens. This is what fixes the "cancel returns to empty Create screen"
  // bug: without it, InfluencerModuleScreen's cached state never learns a
  // profile now exists until the form pops (which previously only ever
  // happened on a SUCCESSFUL verified payment), so cancelling mid-payment
  // and navigating back showed the stale empty state even though the
  // profile was genuinely saved as a draft on the backend.
  final void Function(Map<String, dynamic>)? onProfileSaved;
  const InfluencerProfileFormScreen({super.key, required this.token, required this.existing, this.onProfileSaved});

  @override
  State<InfluencerProfileFormScreen> createState() => _InfluencerProfileFormScreenState();
}

class _InfluencerProfileFormScreenState extends State<InfluencerProfileFormScreen> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _bioC = TextEditingController();
  final _instaC = TextEditingController();
  final _ytC = TextEditingController();
  final _fbC = TextEditingController();
  String? _selState;
  String? _selCity;
  final Set<String> _selCategories = {}; // Issue 3: multi-select
  String _photoB64 = ""; // empty = no change (edit) / no photo (create)
  String _existingPhotoUrl = "";
  List<String> _categories = [];
  bool _loadingCategories = true;
  bool _saving = false;       // guards plain Save
  bool _publishing = false;   // guards Save & Publish (separate flag: only one of the two buttons is ever disabled at a time)
  String? _errorMsg;

  bool get _isEdit => widget.existing != null;
  // A brand-new profile (create mode — widget.existing == null) always
  // starts UNPAID; there is nothing to default to PAID here at all. Only an
  // EXISTING profile with no payment_status field at all (predates this
  // feature, or admin-created) is treated as already paid — same backward-
  // compatibility default used everywhere else in this feature. An existing
  // profile that DOES have payment_status set to UNPAID/PAYMENT_PENDING/
  // PAYMENT_FAILED is correctly NOT treated as paid.
  bool get _alreadyPaid {
    final existing = widget.existing;
    if (existing == null) return false;
    return (existing["payment_status"]?.toString() ?? "PAID") == "PAID";
  }

  // ── Influencer Subscription Fee + Payment + Publish ──
  Map<String, dynamic>? _pricing; // null while loading/unknown
  bool _loadingPricing = true;

  // Razorpay instance must live for the lifetime of this screen (same
  // reasoning as merchant_screens.dart's Store Subscription screen: created
  // inside a local function, its native callbacks can be garbage-collected
  // while the native checkout activity is still on top).
  late final Razorpay _razorpay;
  Map<String, dynamic> _pendingOrder = {};

  // ── Discount code (Influencer Subscription) ──
  final _discountCodeC = TextEditingController();
  String? _appliedDiscountCode;   // set only after a successful "Apply" validation
  bool _applyingDiscount = false;
  String? _discountError;
  Map<String, dynamic>? _appliedDiscountInfo; // {discount_amount, type, discount_value, message,...} from validate call

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameC.text = e["name"]?.toString() ?? "";
      _phoneC.text = e["phone"]?.toString() ?? "";
      _bioC.text = e["bio"]?.toString() ?? "";
      _selState = (e["state"]?.toString().isNotEmpty ?? false) ? e["state"].toString() : null;
      _selCity = (e["city"]?.toString().isNotEmpty ?? false) ? e["city"].toString() : null;
      // Issue 3: prefer the new `categories` list; fall back to the legacy
      // single `category` string for a profile created before this change.
      final rawCats = e["categories"];
      if (rawCats is List && rawCats.isNotEmpty) {
        _selCategories.addAll(rawCats.map((c) => c.toString()));
      } else if ((e["category"]?.toString().isNotEmpty ?? false)) {
        _selCategories.add(e["category"].toString());
      }
      _existingPhotoUrl = e["photo_url"]?.toString() ?? "";
      final social = (e["social"] is Map) ? e["social"] as Map : {};
      _instaC.text = social["instagram"]?.toString() ?? "";
      _ytC.text = social["youtube"]?.toString() ?? "";
      _fbC.text = social["facebook"]?.toString() ?? "";
    }
    _loadCategories();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
    if (!_alreadyPaid) _loadSubscriptionPricing();
  }

  Future<void> _loadSubscriptionPricing() async {
    try {
      final p = await Api.getInfluencerSubscriptionPricing(widget.token);
      if (mounted) setState(() { _pricing = p; _loadingPricing = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPricing = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final raw = await Api.fetchCategories(token: widget.token);
      final names = raw.map((c) => c is Map ? (c["name"]?.toString() ?? "") : c.toString())
          .where((n) => n.isNotEmpty).toSet().toList();
      if (mounted) setState(() { _categories = names; _loadingCategories = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image too large. Max 2MB."), backgroundColor: Colors.red));
      return;
    }
    setState(() => _photoB64 = "data:image/jpeg;base64,${base64Encode(bytes)}");
  }

  @override
  void dispose() {
    _nameC.dispose(); _phoneC.dispose(); _bioC.dispose(); _instaC.dispose(); _ytC.dispose(); _fbC.dispose();
    _discountCodeC.dispose();
    _razorpay.clear();
    super.dispose();
  }

  /// Shared validation + body-building for both Save and Save & Publish —
  /// returns null (and sets _errorMsg) if invalid.
  ///
  /// `requireImage`: true only for Save & Publish. A profile image is
  /// mandatory to PUBLISH, but a draft (plain Save) may still be saved
  /// without one — so this flag is the only thing that differs between
  /// the two call sites below. "Has an image" means either a NEW photo was
  /// just picked this session (_photoB64) or the profile already has one
  /// saved from before (_existingPhotoUrl) — editing an already-published
  /// profile that already has an image continues to work normally.
  Map<String, dynamic>? _validateAndBuildBody({bool requireImage = false}) {
    final name = _nameC.text.trim();
    if (name.isEmpty) { setState(() => _errorMsg = "Name is required"); return null; }
    if (_selState == null) { setState(() => _errorMsg = "Please select a state"); return null; }
    if (_selCity == null) { setState(() => _errorMsg = "Please select a city"); return null; }
    // Issue 2: validate exactly-10-digits on Save too, not just via the
    // input formatter (which only blocks typing past 10 — this also
    // catches an empty/short value if the user backspaced).
    final phone = _phoneC.text.trim();
    if (phone.isNotEmpty && phone.length != 10) {
      setState(() => _errorMsg = "Please enter a valid 10-digit mobile number.");
      return null;
    }
    if (requireImage && _photoB64.isEmpty && !_existingPhotoUrl.startsWith("http")) {
      setState(() => _errorMsg = "Profile image is required to publish your influencer profile.");
      return null;
    }
    final body = <String, dynamic>{
      "name": name,
      "state": _selState,
      "city": _selCity,
      "categories": _selCategories.toList(), // Issue 3: multi-select list
      "phone": phone,
      "bio": _bioC.text.trim(),
      "social": {
        "instagram": _instaC.text.trim(),
        "youtube": _ytC.text.trim(),
        "facebook": _fbC.text.trim(),
      },
    };
    if (_photoB64.isNotEmpty) body["photo_url"] = _photoB64;
    return body;
  }

  /// SAVE — draft-only, per the approved business rule. Never publishes and
  /// never touches payment. This is the only action a brand-new profile can
  /// take without paying anything.
  Future<void> _save() async {
    if (_saving || _publishing) return; // prevent duplicate simultaneous submissions
    final body = _validateAndBuildBody();
    if (body == null) return;
    setState(() { _saving = true; _errorMsg = null; });
    try {
      if (_isEdit) {
        await Api.updateMyInfluencerProfile(widget.token, body);
      } else {
        await Api.createInfluencerProfile(widget.token, body);
      }
      // Always re-fetch after save so the screen shows exactly what the
      // backend persisted — no separate local model that could drift.
      final fresh = await Api.getMyInfluencerProfile(widget.token);
      if (mounted) Navigator.pop(context, fresh);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// SAVE & PUBLISH — validates/saves, then asks the backend whether payment
  /// is required. If the profile is already PAID (or admin has the
  /// subscription toggle disabled, or the fee resolves to ₹0), the backend
  /// publishes immediately with no payment step. Otherwise it returns a
  /// Razorpay order and this opens checkout; publishing only actually
  /// happens after the backend verifies the payment (see _onPaySuccess).
  Future<void> _saveAndPublish() async {
    if (_saving || _publishing) return;
    final body = _validateAndBuildBody(requireImage: true);
    if (body == null) return;
    setState(() { _publishing = true; _errorMsg = null; });
    try {
      Map<String, dynamic> profileFieldsForPublish = body;
      if (!_isEdit) {
        // The publish endpoint only operates on an EXISTING profile — a
        // brand-new profile must be created first. This is still the same
        // "validate/save" step conceptually, just split across two calls
        // because create and publish are different endpoints.
        await Api.createInfluencerProfile(widget.token, body);
        profileFieldsForPublish = {}; // already saved by the create call above
        // FIX (Razorpay-cancel bug): tell the parent screen the profile now
        // exists RIGHT NOW — before Razorpay even opens — so if the user
        // cancels payment and navigates back, InfluencerModuleScreen shows
        // the real (draft/pending) profile instead of its stale empty
        // "Create your Influencer Profile" state. Best-effort only: a
        // failure here never blocks Save & Publish itself.
        await _notifyParentProfileSaved();
      }
      // Optional discount code — the backend independently re-validates
      // and computes the amount regardless of whether "Apply" was pressed;
      // this just passes along whatever code the user has entered/applied.
      final code = (_appliedDiscountCode ?? _discountCodeC.text).trim();
      if (code.isNotEmpty) profileFieldsForPublish["discount_code"] = code;

      final result = await Api.publishInfluencerProfile(widget.token, profileFieldsForPublish);
      if (result["payment_required"] == true) {
        _pendingOrder = result;
        if (mounted) setState(() => _publishing = false);
        // Same reason as above — the profile (and its PAYMENT_PENDING
        // state / reusable order) already exists server-side at this
        // point, whether or not the user ever completes checkout.
        await _notifyParentProfileSaved();
        _openRazorpayCheckout(result);
        return; // _onPaySuccess/_onPayError take over from here
      }
      // No payment needed — already published.
      final fresh = await Api.getMyInfluencerProfile(widget.token);
      if (mounted) Navigator.pop(context, fresh);
    } catch (e) {
      if (mounted) setState(() => _errorMsg = friendlyError(e));
    } finally {
      if (mounted && _publishing) setState(() => _publishing = false);
    }
  }

  /// Best-effort: fetches the current profile and hands it to the parent's
  /// onProfileSaved callback, WITHOUT closing this form and without
  /// treating a failure as fatal to Save & Publish. Silently does nothing
  /// if no callback was supplied or the fetch fails — the backend record
  /// is the source of truth regardless; this only keeps the parent
  /// screen's cached view from going stale.
  Future<void> _notifyParentProfileSaved() async {
    if (widget.onProfileSaved == null) return;
    try {
      final fresh = await Api.getMyInfluencerProfile(widget.token);
      if (fresh.isNotEmpty) widget.onProfileSaved!(fresh);
    } catch (_) {
      // Ignore — a stale parent screen is a minor cosmetic issue the user
      // can fix with pull-to-refresh; it must never surface as a Save &
      // Publish error when the actual save/publish call may still succeed.
    }
  }

  void _openRazorpayCheckout(Map<String, dynamic> order) {
    final rzpKey = order["razorpay_key"]?.toString() ?? '';
    if (rzpKey.isEmpty) {
      setState(() => _errorMsg = "Payment gateway not configured. Contact support.");
      return;
    }
    try {
      final amountPaise = (order["amount"] as num?)?.toInt() ??
          ((double.tryParse(order["amount_display"]?.toString() ?? "0") ?? 0) * 100).round();
      final opts = {
        'key': rzpKey,
        'amount': amountPaise,
        'currency': 'INR',
        'order_id': order["razorpay_order_id"] ?? "",
        'name': 'Offro',
        'description': 'Influencer Subscription',
        'prefill': { 'contact': _phoneC.text.trim() },
        'image': '$kBaseUrl/static/offro_logo.png',
        'theme': {'color': '#3E5F55'},
      };
      _razorpay.open(opts);
    } catch (e) {
      debugPrint('[OffrO] Razorpay open error: $e');
      setState(() => _errorMsg = friendlyError(e, fallback: "Could not open payment. Please try again."));
    }
  }

  Future<void> _onPaySuccess(PaymentSuccessResponse resp) async {
    if (!mounted) return;
    final payId = resp.paymentId ?? "";
    final ordId = resp.orderId ?? _pendingOrder["razorpay_order_id"]?.toString() ?? "";
    final sig   = resp.signature ?? "";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: Card(
        color: Colors.white,
        child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: kPrimary),
          SizedBox(height: 16),
          Text("Confirming payment...", style: TextStyle(fontWeight: FontWeight.w600, color: kText)),
          SizedBox(height: 4),
          Text("Please wait a moment", style: TextStyle(color: kMuted, fontSize: 12)),
        ])),
      )),
    );
    // The Flutter client never assumes success just because Razorpay
    // returned success — server-side signature verification is what
    // actually flips payment_status to PAID / publish_status to published.
    // Retried a few times to ride out a transient network blip right after
    // checkout, exactly like the existing Store Subscription flow.
    bool verified = false;
    String? failureMsg;
    for (int attempt = 0; attempt < 3 && !verified; attempt++) {
      try {
        await Api.verifyInfluencerPayment(widget.token,
          razorpayOrderId: ordId, razorpayPaymentId: payId, razorpaySignature: sig);
        verified = true;
      } catch (e) {
        failureMsg = friendlyError(e);
        if (attempt < 2) await Future.delayed(Duration(seconds: attempt + 1));
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss "Confirming payment..." dialog
    if (verified) {
      // Payment is ALREADY verified server-side at this point — a failure
      // in the immediately-following profile refetch is a separate,
      // unrelated network hiccup and must never be presented as a payment
      // failure (the payment succeeded; only re-reading the profile
      // afterward failed). Fall back to a "please refresh" sentinel that
      // InfluencerModuleScreen recognizes and turns into a full reload,
      // rather than showing this form's error banner or leaving the parent
      // with stale pre-payment data.
      try {
        final fresh = await Api.getMyInfluencerProfile(widget.token);
        if (mounted) Navigator.pop(context, fresh); // close the form, return published profile
      } catch (_) {
        if (mounted) Navigator.pop(context, const {"_needs_refresh": true});
      }
    } else {
      // Payment succeeded on Razorpay's side but our server could not
      // verify it (or a network issue) — the profile stays draft/unpaid.
      // Never mark PAID/published on the client's own say-so.
      setState(() => _errorMsg = failureMsg ?? "We couldn't confirm your payment. If money was deducted, it will be verified shortly — please try Save & Publish again in a moment.");
    }
  }

  Future<void> _onPayError(PaymentFailureResponse resp) async {
    // Cancelled or failed — profile remains saved as draft/unpublished on
    // the server (payment_status stays PAYMENT_PENDING, publish_status
    // stays draft; the client never touches either either way).
    //
    // FIX (Bug 1 — "cancel returns to empty create screen"): this used to
    // just set _errorMsg and leave the user stuck on this form. But by the
    // time Razorpay can even be cancelled, the profile already exists on
    // the server (it was saved/published-pending before checkout opened —
    // see _saveAndPublish's _notifyParentProfileSaved calls). So instead of
    // staying here, close this form and hand the parent screen the current,
    // real profile state, exactly like a successful save would. The parent
    // (InfluencerModuleScreen / _MyInfluencerProfileView) then shows the
    // existing draft/pending profile — with its own "Continue Publishing /
    // Pay Now" affordance — never the stale empty create-state, and never a
    // duplicate profile.
    if (!mounted) return;
    // Round 9 FIX: this used to discard resp.message entirely and pop
    // silently — cancelling or a genuinely failed payment gave the customer
    // no feedback at all. Show a clean, classified message (never raw
    // Razorpay/gateway text) before handing control back to the parent.
    final failMsg = friendlyRazorpayError(resp.message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failMsg), backgroundColor: Colors.red));
    try {
      final fresh = await Api.getMyInfluencerProfile(widget.token);
      if (mounted) Navigator.pop(context, fresh.isNotEmpty ? fresh : const {"_needs_refresh": true});
    } catch (_) {
      if (mounted) Navigator.pop(context, const {"_needs_refresh": true});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: merchantHeaderBar(
        eyebrow: "Creator identity",
        title: _isEdit ? "Edit profile" : "Add profile",
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(children: [
                _buildPhotoPreview(90),
                Positioned(bottom: 0, right: 0, child: Container(
                  width: 30, height: 30,
                  decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                )),
              ]),
            ),
          ),
          // Optional for a draft Save, but mandatory to Save & Publish (see
          // _validateAndBuildBody's requireImage check) — shown only while
          // no image exists yet, never for a profile that already has one.
          if (_photoB64.isEmpty && !_existingPhotoUrl.startsWith("http"))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text("Required to publish", style: TextStyle(fontSize: 11.5, color: kMuted.withValues(alpha: .9), fontStyle: FontStyle.italic)),
              ),
            ),
          const SizedBox(height: 24),
          const Text("Name *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 6),
          TextField(controller: _nameC, decoration: _dec("e.g. Priya Sharma")),
          const SizedBox(height: 16),
          const Text("Bio", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 6),
          TextField(controller: _bioC, maxLines: 3, maxLength: 280,
            decoration: _dec("Sharing the best local food, cafés, shops and great offers around your city.")),
          const SizedBox(height: 4),
          const Text("State *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: kIndiaStates.contains(_selState) ? _selState : null,
            items: kIndiaStates.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() { _selState = v; _selCity = null; }),
            decoration: _dec("Select state"),
            hint: const Text("Select state"),
          ),
          const SizedBox(height: 16),
          const Text("City *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: (_selState != null && (kIndiaCities[_selState] ?? []).contains(_selCity)) ? _selCity : null,
            items: (_selState == null ? <String>[] : (kIndiaCities[_selState] ?? []))
                .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _selCity = v),
            decoration: _dec(_selState == null ? "Select state first" : "Select city"),
            hint: Text(_selState == null ? "Select state first" : "Select city"),
          ),
          const SizedBox(height: 16),
          const Text("Primary Specialty (select one or more)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 8),
          _loadingCategories
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(color: kPrimary))
              : _categories.isEmpty
                  ? const Text("No categories available", style: TextStyle(fontSize: 12, color: kMuted))
                  : _specialtyField(),
          const SizedBox(height: 16),
          const Text("Phone", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneC,
            keyboardType: TextInputType.number,
            // Issue 2: numeric only, hard-capped at 10 digits — cannot
            // type an 11th digit at all, matching the backend's exact
            // 10-digit requirement.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: _dec("10-digit mobile number"),
          ),
          const SizedBox(height: 20),
          const Text("Social Links", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kText)),
          const SizedBox(height: 10),
          TextField(controller: _instaC, decoration: _dec("Instagram URL").copyWith(prefixIcon: const Icon(Icons.camera_alt_rounded, size: 18))),
          const SizedBox(height: 10),
          TextField(controller: _ytC, decoration: _dec("YouTube URL").copyWith(prefixIcon: const Icon(Icons.play_circle_fill_rounded, size: 18))),
          const SizedBox(height: 10),
          TextField(controller: _fbC, decoration: _dec("Facebook URL").copyWith(prefixIcon: const Icon(Icons.facebook_rounded, size: 18))),
          if (!_alreadyPaid) ...[
            const SizedBox(height: 24),
            _buildSubscriptionSummary(),
          ],
          if (_errorMsg != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFfde8e6), borderRadius: BorderRadius.circular(10)),
              child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 24),
          // SAVE — draft only, never requires or triggers payment.
          SizedBox(width: double.infinity, child: OutlinedButton(
            onPressed: (_saving || _publishing) ? null : _save,
            style: OutlinedButton.styleFrom(elevation: 0, side: const BorderSide(color: kPrimary), padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder()),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                : Text(_isEdit ? "Save (keep as draft)" : "Save", style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(height: 10),
          // SAVE & PUBLISH — the one-time-payment path. Once the profile is
          // already PAID, this simply saves + publishes with no charge.
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: (_saving || _publishing) ? null : _saveAndPublish,
            style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: kPrimary, padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const StadiumBorder()),
            child: _publishing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_alreadyPaid ? "Save & Publish" : "Save & Publish (Pay to Publish)",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ],
      ),
    );
  }

  /// Subscription summary card — Base Fee / GST / Total, exactly as
  /// specified, sourced entirely from the backend's admin-configured
  /// pricing. Shown only while this profile hasn't paid yet; a paid
  /// profile's Save & Publish never needs this explanation again.
  Widget _buildSubscriptionSummary() {
    if (_loadingPricing) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(color: kPrimary));
    }
    final pricing = _pricing;
    if (pricing == null) return const SizedBox.shrink(); // pricing lookup failed — Save & Publish will surface the real error
    if (pricing["enabled"] == false) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFf0f9f4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFc3dfc6))),
        child: const Text("No subscription payment is currently required to publish your profile.",
          style: TextStyle(fontSize: 12.5, color: OffroColors.primary)),
      );
    }
    final fee = (pricing["fee"] as num?)?.toDouble() ?? 0;
    final gstPct = (pricing["gst_percent"] as num?)?.toDouble() ?? 0;
    // When a discount has been successfully applied (preview call only —
    // the backend independently re-validates and recomputes at Save &
    // Publish time regardless), show the discounted GST/Total from that
    // preview response instead of the plain pricing figures. If the applied
    // info is missing/cleared, fall back to the undiscounted figures — the
    // discount line itself only renders when there is something to show.
    final info = _appliedDiscountInfo;
    final discountAmt = (info?["discount_amount"] as num?)?.toDouble() ?? 0;
    final gstAmt = (info?["gst_amount"] as num?)?.toDouble() ?? (pricing["gst_amount"] as num?)?.toDouble() ?? 0;
    final total = (info?["total"] as num?)?.toDouble() ?? (pricing["total"] as num?)?.toDouble() ?? 0;
    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: bold ? 13.5 : 12.5, color: bold ? kText : kMuted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: bold ? 13.5 : 12.5, color: kText, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ]),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFfff0f6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFf0c6d8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Influencer Subscription", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFa1275a))),
        const SizedBox(height: 8),
        row("Subscription Fee", "₹${fee.toStringAsFixed(2)}"),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _discountCodeC,
              enabled: !_applyingDiscount,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                isDense: true,
                hintText: "Discount code (optional)",
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kBorder)),
              ),
              onChanged: (_) {
                // The code text changed after a previous Apply — the
                // applied discount no longer reflects what's in the field,
                // so clear it. This guarantees Save & Publish never silently
                // carries forward a discount that doesn't match what's
                // currently typed (it always re-reads _appliedDiscountCode
                // which is cleared here) — the backend still re-validates
                // regardless, this is purely about the UI staying honest.
                if (_appliedDiscountCode != null || _discountError != null) {
                  setState(() { _appliedDiscountCode = null; _appliedDiscountInfo = null; _discountError = null; });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _applyingDiscount ? null : _applyDiscountCode,
              style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: const Color(0xFFa1275a), foregroundColor: Colors.white,
                shape: const StadiumBorder()),
              child: _applyingDiscount
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Apply", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        if (_discountError != null) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_discountError!, style: const TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w600)),
        ),
        if (_appliedDiscountCode != null) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            const Icon(Icons.check_circle, size: 14, color: Color(0xFF2e7d32)),
            const SizedBox(width: 4),
            Expanded(child: Text("Code '$_appliedDiscountCode' applied",
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF2e7d32), fontWeight: FontWeight.w700))),
          ]),
        ),
        const SizedBox(height: 8),
        if (discountAmt > 0) row("Discount", "-₹${discountAmt.toStringAsFixed(2)}"),
        row("GST (${gstPct.toStringAsFixed(gstPct == gstPct.roundToDouble() ? 0 : 1)}%)", "₹${gstAmt.toStringAsFixed(2)}"),
        const Divider(height: 16),
        row("Total Payable", "₹${total.toStringAsFixed(2)}", bold: true),
        const SizedBox(height: 8),
        const Text("A one-time payment — you won't be charged again for editing or re-publishing this profile.",
          style: TextStyle(fontSize: 11, color: Color(0xFFa1275a))),
      ]),
    );
  }

  /// Preview-only "Apply" check — calls the same authoritative discount
  /// resolver (via a dedicated preview endpoint) that Save & Publish will
  /// use again regardless of this result. On success, updates the summary
  /// card to show the discounted GST/Total. On any failure (invalid,
  /// inactive, expired, usage-limit reached, wrong scope, network error),
  /// shows a friendly error and — critically — clears any previously
  /// applied discount, so the UI can never keep displaying/using a
  /// discounted amount that this call just proved is no longer valid.
  Future<void> _applyDiscountCode() async {
    final code = _discountCodeC.text.trim();
    if (code.isEmpty) {
      setState(() { _discountError = "Enter a discount code first"; _appliedDiscountCode = null; _appliedDiscountInfo = null; });
      return;
    }
    setState(() { _applyingDiscount = true; _discountError = null; });
    try {
      final resp = await Api.validateInfluencerDiscountCode(widget.token, code);
      if (!mounted) return;
      setState(() {
        _appliedDiscountCode = resp["code"]?.toString() ?? code.toUpperCase();
        _appliedDiscountInfo = resp;
        _discountError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appliedDiscountCode = null;
        _appliedDiscountInfo = null;
        _discountError = friendlyError(e);
      });
    } finally {
      if (mounted) setState(() => _applyingDiscount = false);
    }
  }

  Widget _buildPhotoPreview(double size) {
    Widget fallback() => Container(
      width: size, height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: kLight),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, size: 40, color: kPrimary),
    );
    if (_photoB64.isNotEmpty) {
      try {
        final bytes = base64Decode(_photoB64.split(",").last);
        return ClipOval(child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover));
      } catch (_) { return fallback(); }
    }
    if (_existingPhotoUrl.startsWith("http")) {
      return ClipOval(child: CachedNetworkImage(imageUrl: _existingPhotoUrl, width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, __) => fallback(), errorWidget: (_, __, ___) => fallback()));
    }
    return fallback();
  }

  /// Multi-select dropdown for Primary Specialty — same `_selCategories` set
  /// and `_categories` source as before; selected values show as small chips.
  Widget _specialtyField() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickSpecialties,
      child: InputDecorator(
        decoration: _dec("Select specialties").copyWith(
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded, color: kMuted)),
        isEmpty: _selCategories.isEmpty,
        child: _selCategories.isEmpty
            ? const SizedBox.shrink()
            : Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in _selCategories)
                  InputChip(
                    label: Text(c, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: OffroColors.primary)),
                    backgroundColor: OffroColors.mintSoft,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    deleteIconColor: OffroColors.primary,
                    onDeleted: () => setState(() => _selCategories.remove(c)),
                  ),
              ]),
      ),
    );
  }

  Future<void> _pickSpecialties() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 16),
            const Text("Primary Specialty", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kText)),
            const SizedBox(height: 4),
            Flexible(child: ListView(shrinkWrap: true, children: [
              for (final c in _categories)
                CheckboxListTile(
                  value: _selCategories.contains(c),
                  activeColor: kPrimary,
                  title: Text(c, style: const TextStyle(fontSize: 14, color: kText)),
                  onChanged: (v) {
                    setState(() { if (v == true) { _selCategories.add(c); } else { _selCategories.remove(c); } });
                    setSheet(() {});
                  },
                ),
            ])),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12), shape: const StadiumBorder()),
                child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              )),
            ),
          ]),
        ),
      )),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kBorder)),
  );
}
