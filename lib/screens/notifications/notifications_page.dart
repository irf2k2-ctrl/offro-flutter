import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ─── Local imports ───
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/prefs_service.dart';

const kBaseUrl     = "https://offro-backend-production.up.railway.app";
const kRazorpayKey = "rzp_live_SdiI6kcuZzZjsl";
const kPrimary  = Color(0xFF3E5F55);
const kLight    = Color(0xFFCDEBD6);
const kAccent   = Color(0xFFA9CDBA);
const kBeige    = Color(0xFFE7D7C8);
const kBg       = Color(0xFFFDFBF6);
const kText     = Color(0xFF2c3e35);
const kMuted    = Color(0xFF6b8c7e);
const kBorder   = Color(0xFFd4e8de);

PageRoute _route(Widget w) => MaterialPageRoute(builder: (_) => w);

// ─────────────────────── NOTIFICATIONS PAGE ───────────────────────
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String,dynamic>> _notifs = [];
  bool _loading = true;

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Prefs.clearUnread(); // Mark all as read when page opens
    // Auto-purge notifications older than 30 days
    final rawList = await Prefs.getNotifications();
    final cutoff  = DateTime.now().subtract(const Duration(days: 30));
    final list = rawList.where((n) {
      final ts = n["ts"] as String? ?? "";
      if (ts.isEmpty) return true;
      try { return DateTime.parse(ts).isAfter(cutoff); } catch (_) { return true; }
    }).toList();
    if (list.length != rawList.length) {
      // Persist pruned list — re-save via saveNotification
      await Prefs.clearNotifications();
      for (final n in list.reversed) {
        await Prefs.saveNotification(
          title:    n["title"]     as String? ?? "",
          body:     n["body"]      as String? ?? "",
          imageUrl: n["image_url"] as String? ?? "",
          type:     n["type"]      as String? ?? "promo",
        );
      }
    }
    if (mounted) setState(() { _notifs = list; _loading = false; });
  }

  Future<void> _deleteNotif(int index) async {
    setState(() => _notifs.removeAt(index));
    // Rebuild stored list without deleted notification
    await Prefs.clearNotifications();
    for (final n in _notifs.reversed) {
      await Prefs.saveNotification(
        title:    n["title"]     as String? ?? "",
        body:     n["body"]      as String? ?? "",
        imageUrl: n["image_url"] as String? ?? "",
        type:     n["type"]      as String? ?? "promo",
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear All Notifications?"),
        content: const Text("This will permanently remove all your notifications."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await Prefs.clearNotifications();
      if (mounted) setState(() => _notifs = []);
    }
  }

  String _timeAgo(String isoTs) {
    try {
      final dt   = DateTime.parse(isoTs);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return "just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours  < 24)  return "${diff.inHours}h ago";
      if (diff.inDays   < 7)   return "${diff.inDays}d ago";
      return "${(diff.inDays / 7).floor()}w ago";
    } catch (_) { return ""; }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        elevation: 0,
        actions: [
          if (_notifs.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text("Clear All", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _notifs.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: kMuted.withValues(alpha: .4)),
                  const SizedBox(height: 16),
                  const Text("No notifications yet", style: TextStyle(color: kMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text("You'll see deals and alerts here", style: TextStyle(color: kMuted, fontSize: 13)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final n       = _notifs[i];
                    final title   = n["title"] ?? "";
                    final body    = n["body"]  ?? "";
                    final imgUrl  = n["image_url"] ?? "";
                    final ts      = n["ts"] ?? "";
                    return Dismissible(
                      key: Key(ts + title + i.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade400,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
                      ),
                      onDismissed: (_) => _deleteNotif(i),
                      child: GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (imgUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imgUrl.startsWith("data:image")
                                    ? Image.memory(base64Decode(imgUrl.split(",").last), height: 160, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true)
                                    : CachedNetworkImage(imageUrl: imgUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                                ),
                              if (imgUrl.isNotEmpty) const SizedBox(height: 14),
                              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kText)),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(body, style: const TextStyle(fontSize: 14, color: kMuted, height: 1.5)),
                              ],
                              if (ts.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(_timeAgo(ts), style: const TextStyle(fontSize: 11, color: kMuted)),
                              ],
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Close", style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                      child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Notification icon or image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52, height: 52,
                            child: imgUrl.isNotEmpty
                                ? (imgUrl.startsWith("data:image")
                                    ? Image.memory(base64Decode(imgUrl.split(",").last), fit: BoxFit.cover, gaplessPlayback: true)
                                    : CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: kLight),
                                        errorWidget: (_, __, ___) => Container(color: kLight,
                                            child: const Icon(Icons.notifications_rounded, color: kPrimary, size: 24))))
                                : Container(color: kLight,
                                    child: const Icon(Icons.notifications_rounded, color: kPrimary, size: 24)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(title, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (ts.isNotEmpty) Text(_timeAgo(ts), style: const TextStyle(color: kMuted, fontSize: 11)),
                          ]),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(body, style: const TextStyle(color: kMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ])),
                      ]),
                      ), // close GestureDetector child Container
                    ),  // GestureDetector
                    );  // Dismissible
                  },
                ),
    );
  }
}

