// lib/screens/home/profile_tab.dart
//
// Customer "Profile" tab (Figma redesign, Phase 2).
//
// Presentation only. HomeScreen passes in the existing actions (rewards,
// scan history, favourites, notifications, legal pages, switch mode, contact,
// logout / login) as [ProfileEntry] lists, so every action keeps the exact
// behaviour it had in the old profile sheet. The avatar upload is the same
// Api.getMe / Api.updateUserProfile flow UserProfileHeader used.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/design/design.dart';
import '../../core/services/api_service.dart';

class ProfileEntry {
  final OffroIconData icon;
  final String label;
  final String? note;
  final VoidCallback onTap;
  final bool destructive;
  const ProfileEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.note,
    this.destructive = false,
  });
}

class ProfileTab extends StatefulWidget {
  final String token, name, phone;
  final bool isGuest;
  final int savedCount;
  final int points;
  final List<ProfileEntry> activity;
  final List<ProfileEntry> account;
  final List<ProfileEntry> legal;
  final ProfileEntry sessionAction; // Logout, or Login / Register for guests

  const ProfileTab({
    super.key,
    required this.token,
    required this.name,
    required this.phone,
    required this.isGuest,
    required this.savedCount,
    required this.points,
    required this.activity,
    required this.account,
    required this.legal,
    required this.sessionAction,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String? _imgB64;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    if (widget.isGuest || widget.token.isEmpty) return;
    try {
      final d = await Api.getMe(widget.token);
      if (mounted && d != null && d["profile_image"] != null) {
        setState(() => _imgB64 = d["profile_image"]);
      }
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    if (widget.isGuest) return;
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 600);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    final b64 = "data:image/jpeg;base64,${base64Encode(bytes)}";
    setState(() { _uploading = true; _imgB64 = b64; });
    try { await Api.updateUserProfile(widget.token, {"profile_image": b64}); } catch (_) {}
    if (mounted) setState(() => _uploading = false);
  }

  static String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  String get _initials {
    final parts = widget.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "U";
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Widget _avatar() {
    ImageProvider? provider;
    if (_imgB64 != null && _imgB64!.startsWith("data:")) {
      try { provider = MemoryImage(base64Decode(_imgB64!.split(",").last)); } catch (_) {}
    }
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(alignment: Alignment.bottomRight, children: [
        Container(
          width: 64, height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: OffroColors.primary,
            shape: BoxShape.circle,
            image: provider == null ? null : DecorationImage(image: provider, fit: BoxFit.cover),
          ),
          child: provider == null
              ? Text(_initials, style: OffroText.cardTitle.copyWith(fontSize: 18, color: Colors.white))
              : null,
        ),
        if (!widget.isGuest)
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: OffroColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: OffroColors.mint, width: 1.5),
            ),
            child: _uploading
                ? const Padding(
                    padding: EdgeInsets.all(4),
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: OffroColors.primary))
                : const Icon(Icons.camera_alt, size: 10, color: OffroColors.primary),
          ),
      ]),
    );
  }

  Widget _identityCard() {
    final name = widget.isGuest ? "Guest" : (widget.name.isEmpty ? "OffrO member" : widget.name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 24, OffroSpacing.gutter, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: OffroColors.mint,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(children: [
          _avatar(),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: OffroText.cardTitle.copyWith(fontSize: 16)),
            if (!widget.isGuest && widget.phone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.phone,
                style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400,
                  color: OffroColors.primary.withValues(alpha: .65))),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .55),
                borderRadius: OffroRadii.pillRadius,
              ),
              child: Text(widget.isGuest ? "Browsing as guest" : "OffrO member",
                style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: OffroColors.primary)),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _stats() {
    Widget tile(String value, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: OffroColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Text(value, style: OffroText.cardTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textFaint)),
        ]),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 16, OffroSpacing.gutter, 0),
      child: Row(children: [
        tile("${widget.savedCount}", "Saved"),
        const SizedBox(width: 8),
        tile(_fmt(widget.points), "Points"),
      ]),
    );
  }

  Widget _group(String eyebrow, List<ProfileEntry> items, {double top = 28}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(OffroSpacing.gutter, top, OffroSpacing.gutter, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow.toUpperCase(),
          style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.8, color: OffroColors.sage)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: OffroColors.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            for (int i = 0; i < items.length; i++) _row(items[i], last: i == items.length - 1),
          ]),
        ),
      ]),
    );
  }

  Widget _row(ProfileEntry e, {required bool last}) {
    final tint = e.destructive ? OffroColors.error : OffroColors.primary;
    return InkWell(
      onTap: e.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: Color(0x0D000000))),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: e.destructive ? OffroColors.error.withValues(alpha: .10) : OffroColors.mintSoft,
              shape: BoxShape.circle,
            ),
            child: OffroIcon(e.icon, size: 16, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.label,
              style: OffroText.cardTitle.copyWith(fontSize: 13, color: e.destructive ? OffroColors.error : OffroColors.text)),
            if (e.note != null) ...[
              const SizedBox(height: 2),
              Text(e.note!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textFaint)),
            ],
          ])),
          if (!e.destructive)
            const OffroIcon(OffroIcons.chevron, size: 14, color: OffroColors.sage),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ListView(
      padding: EdgeInsets.only(top: topPad, bottom: 124),
      physics: const BouncingScrollPhysics(),
      children: [
        const OffroScreenHeader(eyebrow: "Your OffrO", title: "Profile", showBack: false),
        _identityCard(),
        _stats(),
        _group("My activity", widget.activity, top: 32),
        _group("Account", widget.account),
        _group("About & legal", widget.legal),
        _group("Session", [widget.sessionAction]),
      ],
    );
  }
}
