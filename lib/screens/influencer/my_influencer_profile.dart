import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../merchant/merchant_screens.dart' show kIndiaStates, kIndiaCities;

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

/// Friendly error conversion — never surfaces raw exceptions, certificate
/// errors, stack traces, or internal details to the user.
String _friendlyError(Object e) {
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('Failed host lookup') ||
      s.contains('Connection') || s.contains('HandshakeException') ||
      s.contains('CERTIFICATE')) {
    return "We couldn't connect to OffrO right now. Please check your internet connection and try again.";
  }
  if (s.contains('TimeoutException')) {
    return "OffrO is taking too long to respond. Please try again.";
  }
  // Backend HTTPException messages come through as "Exception: <detail>" —
  // these are already user-appropriate (e.g. "Name is required",
  // "You already have an influencer profile.") so just strip the prefix.
  final cleaned = s.replaceAll('Exception: ', '').trim();
  if (cleaned.isEmpty || cleaned.length > 200) {
    return "Something went wrong. Please try again.";
  }
  return cleaned;
}

/// Entry point: decides Create vs View based on the authenticated
/// account's own profile — never asks the user for an account_id or
/// influencer_id.
class InfluencerModuleScreen extends StatefulWidget {
  final String token;
  const InfluencerModuleScreen({super.key, required this.token});

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
      setState(() { _error = _friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kText),
        title: const Text("Influencer", style: TextStyle(color: kText, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: _buildBody(),
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
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
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
      onProfileUpdated: (updated) => setState(() => _profile = updated),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(color: kLight.withValues(alpha: .4), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.star_rounded, size: 40, color: kPrimary),
          ),
          const SizedBox(height: 20),
          const Text("Create your Influencer Profile",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kText)),
          const SizedBox(height: 8),
          const Text("You'll need an Influencer profile to use the Influencer module — it's how customers and merchants discover you on OffrO.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kMuted, height: 1.4)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () async {
              final created = await Navigator.push<Map<String,dynamic>>(context,
                MaterialPageRoute(builder: (_) => InfluencerProfileFormScreen(token: widget.token, existing: null)));
              if (created != null && mounted) setState(() => _profile = created);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Add Influencer Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ]),
      ),
    );
  }
}

/// "My Influencer Profile" — the owner's own management view. Distinct
/// from the public InfluencerProfileScreen (no review-submission UI, no
/// Follow, no Share — it's a self-management screen, not a browse screen).
class _MyInfluencerProfileView extends StatelessWidget {
  final String token;
  final Map<String, dynamic> profile;
  final void Function(Map<String,dynamic>) onProfileUpdated;
  const _MyInfluencerProfileView({required this.token, required this.profile, required this.onProfileUpdated});

  Widget _avatar(double size) {
    final name = profile["name"]?.toString() ?? "?";
    final photoUrl = profile["photo_url"]?.toString() ?? "";
    Widget fallback() => Container(
      width: size, height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: kLight),
      alignment: Alignment.center,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?",
        style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: kPrimary)),
    );
    if (photoUrl.startsWith("http")) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kBorder, width: 1)),
        child: ClipOval(child: CachedNetworkImage(imageUrl: photoUrl, width: size, height: size, fit: BoxFit.cover,
          placeholder: (_, __) => fallback(), errorWidget: (_, __, ___) => fallback())),
      );
    }
    return fallback();
  }

  @override
  Widget build(BuildContext context) {
    final name = profile["name"]?.toString() ?? "";
    // Issue 3: prefer the new `categories` list (always present now, even
    // for legacy records — the backend derives it on read); join for this
    // simple subtitle display, same visual result as before for a
    // single-category profile, correctly shows all of them for a
    // multi-category one.
    final categoriesList = (profile["categories"] is List)
        ? (profile["categories"] as List).map((c) => c.toString()).toList()
        : <String>[];
    final category = categoriesList.isNotEmpty
        ? categoriesList.join(", ")
        : (profile["category"]?.toString() ?? "");
    final city = profile["city"]?.toString() ?? "";
    final state = profile["state"]?.toString() ?? "";
    final rating = (profile["rating"] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (profile["review_count"] as num?)?.toInt() ?? 0;
    final social = (profile["social"] is Map) ? profile["social"] as Map : {};

    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () async {
        try {
          final fresh = await Api.getMyInfluencerProfile(token);
          onProfileUpdated(fresh);
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: _avatar(100)),
          const SizedBox(height: 14),
          Center(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kText))),
          const SizedBox(height: 2),
          if (city.isNotEmpty || category.isNotEmpty)
            Center(child: Text([if (city.isNotEmpty) city, if (state.isNotEmpty) state, if (category.isNotEmpty) category].join(" · "),
              style: const TextStyle(fontSize: 13, color: kMuted))),
          const SizedBox(height: 8),
          Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
            const SizedBox(width: 4),
            Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kText)),
            const SizedBox(width: 4),
            Text("($reviewCount reviews)", style: const TextStyle(fontSize: 12, color: kMuted)),
          ])),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () async {
              final updated = await Navigator.push<Map<String,dynamic>>(context,
                MaterialPageRoute(builder: (_) => InfluencerProfileFormScreen(token: token, existing: profile)));
              if (updated != null) onProfileUpdated(updated);
            },
            icon: const Icon(Icons.edit_rounded, size: 16, color: kPrimary),
            label: const Text("Edit Profile", style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: kPrimary), padding: const EdgeInsets.symmetric(vertical: 12)),
          )),
          if (social.values.any((v) => (v?.toString() ?? "").isNotEmpty)) ...[
            const SizedBox(height: 24),
            const Text("Social", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kText)),
            const SizedBox(height: 8),
            if ((social["instagram"] ?? "").toString().isNotEmpty)
              _socialRow(Icons.camera_alt_rounded, const Color(0xFFD4537E), "Instagram", social["instagram"].toString()),
            if ((social["youtube"] ?? "").toString().isNotEmpty)
              _socialRow(Icons.play_circle_fill_rounded, const Color(0xFFE24B4A), "YouTube", social["youtube"].toString()),
            if ((social["facebook"] ?? "").toString().isNotEmpty)
              _socialRow(Icons.facebook_rounded, const Color(0xFF378ADD), "Facebook", social["facebook"].toString()),
          ],
        ],
      ),
    );
  }

  Widget _socialRow(IconData icon, Color color, String label, String url) {
    // Display-only here — link-opening on the owner's own management
    // screen isn't part of this scope; the value is just shown for context.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(url, style: const TextStyle(fontSize: 12, color: kText), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

/// Shared Add/Edit form — `existing == null` means create mode (POST),
/// otherwise edit mode (PUT). Never sends account_id or influencer_id;
/// ownership is entirely determined server-side from the auth token.
class InfluencerProfileFormScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic>? existing;
  const InfluencerProfileFormScreen({super.key, required this.token, required this.existing});

  @override
  State<InfluencerProfileFormScreen> createState() => _InfluencerProfileFormScreenState();
}

class _InfluencerProfileFormScreenState extends State<InfluencerProfileFormScreen> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
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
  bool _saving = false;
  String? _errorMsg;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameC.text = e["name"]?.toString() ?? "";
      _phoneC.text = e["phone"]?.toString() ?? "";
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
    _nameC.dispose(); _phoneC.dispose(); _instaC.dispose(); _ytC.dispose(); _fbC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return; // prevent duplicate simultaneous submissions
    final name = _nameC.text.trim();
    if (name.isEmpty) { setState(() => _errorMsg = "Name is required"); return; }
    if (_selState == null) { setState(() => _errorMsg = "Please select a state"); return; }
    if (_selCity == null) { setState(() => _errorMsg = "Please select a city"); return; }
    // Issue 2: validate exactly-10-digits on Save too, not just via the
    // input formatter (which only blocks typing past 10 — this also
    // catches an empty/short value if the user backspaced).
    final phone = _phoneC.text.trim();
    if (phone.isNotEmpty && phone.length != 10) {
      setState(() => _errorMsg = "Please enter a valid 10-digit mobile number.");
      return;
    }
    setState(() { _saving = true; _errorMsg = null; });

    final body = <String, dynamic>{
      "name": name,
      "state": _selState,
      "city": _selCity,
      "categories": _selCategories.toList(), // Issue 3: multi-select list
      "phone": phone,
      "social": {
        "instagram": _instaC.text.trim(),
        "youtube": _ytC.text.trim(),
        "facebook": _fbC.text.trim(),
      },
    };
    if (_photoB64.isNotEmpty) body["photo_url"] = _photoB64;

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
      if (mounted) setState(() => _errorMsg = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: kText),
        title: Text(_isEdit ? "Edit Profile" : "Add Influencer Profile",
          style: const TextStyle(color: kText, fontWeight: FontWeight.w800, fontSize: 17)),
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
          const SizedBox(height: 24),
          const Text("Name *", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 6),
          TextField(controller: _nameC, decoration: _dec("e.g. Priya Sharma")),
          const SizedBox(height: 16),
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
          const Text("Category (select one or more)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 8),
          _loadingCategories
              ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(color: kPrimary))
              : _categories.isEmpty
                  ? const Text("No categories available", style: TextStyle(fontSize: 12, color: kMuted))
                  : Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _categories.map((c) {
                        final selected = _selCategories.contains(c);
                        return FilterChip(
                          label: Text(c, style: TextStyle(fontSize: 12.5, color: selected ? Colors.white : kText, fontWeight: FontWeight.w600)),
                          selected: selected,
                          selectedColor: kPrimary,
                          backgroundColor: Colors.white,
                          checkmarkColor: Colors.white,
                          side: BorderSide(color: selected ? kPrimary : kBorder),
                          onSelected: (sel) => setState(() {
                            if (sel) { _selCategories.add(c); } else { _selCategories.remove(c); }
                          }),
                        );
                      }).toList(),
                    ),
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
          if (_errorMsg != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFfde8e6), borderRadius: BorderRadius.circular(10)),
              child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isEdit ? "Save Changes" : "Save Profile", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ],
      ),
    );
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

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
  );
}
