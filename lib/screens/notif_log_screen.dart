// lib/screens/notif_log_screen.dart
// In-app notification lifecycle event log — no Mac/Console.app needed.
// Captures which FCM handlers fire on iOS so you can see exactly
// what happens when a notification arrives.

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kNotifLog = 'offro_notif_event_log';
const int _kMaxLogEntries = 100;

// ─── NOTIF EVENT LOGGER ───
class NotifEventLog {
  static Future<void> log(
    String event, {
    String title = '',
    String body = '',
    String msgId = '',
    String imageUrl = '',
    String type = '',
    String screen = '',
    bool? saved,
    String? error,
  }) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final raw = p.getString(_kNotifLog);
      final List<dynamic> list = raw != null ? json.decode(raw) as List : [];
      list.insert(0, {
        'ts': DateTime.now().toIso8601String(),
        'event': event,
        'title': title,
        'body': body,
        'msgId': msgId,
        'imageUrl': imageUrl,
        'type': type,
        'screen': screen,
        'saved': saved,
        'error': error,
        'platform': _platformStr,
      });
      if (list.length > _kMaxLogEntries) {
        list.removeRange(_kMaxLogEntries, list.length);
      }
      await p.setString(_kNotifLog, json.encode(list));
    } catch (e) {
      debugPrint('[NOTIF-EVENT-LOG] Failed to log: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final raw = p.getString(_kNotifLog);
      if (raw == null) return [];
      return (json.decode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kNotifLog);
    } catch (_) {}
  }

  static String get _platformStr {
    try {
      return Platform.isIOS ? 'iOS' : (Platform.isAndroid ? 'Android' : 'other');
    } catch (_) {
      return 'unknown';
    }
  }
}

// ─── NOTIF LOG SCREEN ───
class NotifLogScreen extends StatefulWidget {
  const NotifLogScreen({super.key});
  @override
  State<NotifLogScreen> createState() => _NotifLogScreenState();
}

class _NotifLogScreenState extends State<NotifLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  static const Color kPrimary = Color(0xFF3E5F55);
  static const Color kBg = Color(0xFFFDFBF6);
  static const Color kText = Color(0xFF2c3e35);
  static const Color kMuted = Color(0xFF6b8c7e);
  static const Color kBorder = Color(0xFFd4e8de);
  static const Color kGreen = Color(0xFF2E7D32);
  static const Color kRed = Color(0xFFC62828);
  static const Color kOrange = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await NotifEventLog.getAll();
    if (mounted) setState(() { _logs = logs; _loading = false; });
  }

  Future<void> _clear() async {
    await NotifEventLog.clear();
    if (mounted) setState(() { _logs = []; });
  }

  Color _eventColor(String event) {
    if (event == 'error') return kRed;
    if (event == 'onMessage' || event == 'onBackground' ||
        event == 'onOpenedApp' || event == 'getInitialMessage') return kPrimary;
    return kMuted;
  }

  String _timeStr(String isoTs) {
    try {
      final dt = DateTime.parse(isoTs);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTs;
    }
  }

  IconData _eventIcon(String event) {
    switch (event) {
      case 'onMessage':
        return Icons.phone_android_rounded;
      case 'onBackground':
        return Icons.cloud_sync_rounded;
      case 'onOpenedApp':
        return Icons.touch_app_rounded;
      case 'getInitialMessage':
        return Icons.launch_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _shortMsgId(String mid) {
    if (mid.length > 25) return mid.substring(0, 25);
    return mid;
  }

  // Build detail lines for a single log entry as a list of widgets.
  // Avoids complex inline expressions that confuse the Dart parser.
  List<Widget> _detailLines(Map<String, dynamic> e) {
    final lines = <Widget>[];

    final title = e['title'] as String? ?? '';
    if (title.isNotEmpty) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('title: ' + title, style: const TextStyle(fontSize: 12, color: kText)),
      ));
    }

    final msgId = e['msgId'] as String? ?? '';
    if (msgId.isNotEmpty) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text('msgId: ' + _shortMsgId(msgId) + '...',
          style: const TextStyle(fontSize: 10, color: kMuted, fontFamily: 'monospace')),
      ));
    }

    final saved = e['saved'];
    if (saved != null) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text('saved: ' + saved.toString(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: saved == true ? kGreen : kOrange)),
      ));
    }

    final error = e['error'] as String? ?? '';
    if (error.isNotEmpty) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text('error: ' + error, style: const TextStyle(fontSize: 11, color: kRed)),
      ));
    }

    final type = e['type'] as String? ?? '';
    if (type.isNotEmpty) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text('type: ' + type, style: const TextStyle(fontSize: 10, color: kMuted)),
      ));
    }

    return lines;
  }

  Widget _buildEntry(Map<String, dynamic> e) {
    final event = e['event'] as String? ?? '?';
    final color = _eventColor(event);
    final ts = e['ts'] as String? ?? '';

    final children = <Widget>[];
    children.add(Row(children: [
      Text(event, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
      const Spacer(),
      Text(_timeStr(ts), style: const TextStyle(fontSize: 10, color: kMuted)),
    ]));
    children.addAll(_detailLines(e));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_eventIcon(event), color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        title: const Text('Notification Event Log',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 22),
          ),
          if (_logs.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear Log?'),
                    content: const Text('This will remove all notification event entries.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear', style: TextStyle(color: kRed)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) await _clear();
              },
              child: const Text('Clear',
                style: TextStyle(color: kRed, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bug_report_outlined, size: 60,
                        color: kMuted.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('No events logged yet',
                        style: TextStyle(color: kMuted, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text('Send a notification and check back\nto see which handlers fired',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kMuted, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _buildEntry(_logs[i]),
                ),
    );
  }
}
