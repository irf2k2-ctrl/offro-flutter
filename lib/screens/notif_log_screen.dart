// lib/screens/notif_log_screen.dart
// In-app notification lifecycle event log + FCM registration status.
// No Mac/Console.app needed — everything visible from the app itself.

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

// ─── REGISTRATION STATUS DATA ───
class _RegStatus {
  String platform = '';
  String permission = 'checking...';
  String apnsToken = 'checking...';
  String fcmToken = 'checking...';
  bool fcmTokenReceived = false;
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
  _RegStatus _reg = _RegStatus();

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
    _checkRegStatus();
  }

  Future<void> _load() async {
    final logs = await NotifEventLog.getAll();
    if (mounted) setState(() { _logs = logs; _loading = false; });
  }

  Future<void> _checkRegStatus() async {
    final reg = _RegStatus();
    reg.platform = Platform.isIOS ? 'iOS' : (Platform.isAndroid ? 'Android' : 'other');

    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      final status = settings.authorizationStatus;
      if (status == AuthorizationStatus.authorized) {
        reg.permission = 'Granted';
      } else if (status == AuthorizationStatus.denied) {
        reg.permission = 'DENIED';
      } else if (status == AuthorizationStatus.notDetermined) {
        reg.permission = 'Not determined';
      } else if (status == AuthorizationStatus.provisional) {
        reg.permission = 'Provisional';
      } else {
        reg.permission = 'Unknown';
      }
    } catch (e) {
      reg.permission = 'Error: $e';
    }

    if (Platform.isIOS) {
      try {
        final apns = await FirebaseMessaging.instance.getAPNSToken().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );
        if (apns != null && apns.isNotEmpty) {
          reg.apnsToken = 'OK: ' + apns.substring(0, (apns.length < 20 ? apns.length : 20)) + '...';
        } else {
          reg.apnsToken = 'MISSING';
        }
      } catch (e) {
        reg.apnsToken = 'Error: $e';
      }
    } else {
      reg.apnsToken = 'N/A (Android)';
    }

    try {
      final fcm = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      if (fcm != null && fcm.isNotEmpty) {
        reg.fcmToken = fcm.substring(0, 20) + '...';
        reg.fcmTokenReceived = true;
        _fullFcmToken = fcm;
      } else {
        reg.fcmToken = 'NULL (no token!)';
        reg.fcmTokenReceived = false;
      }
    } catch (e) {
      reg.fcmToken = 'Error: $e';
      reg.fcmTokenReceived = false;
    }

    if (mounted) setState(() { _reg = reg; });
  }

  String? _fullFcmToken;

  Future<void> _clear() async {
    await NotifEventLog.clear();
    if (mounted) setState(() { _logs = []; });
  }

  Color _eventColor(String event) {
    if (event == 'reg_error' || event == 'error') return kRed;
    if (event.startsWith('reg_')) return kPrimary;
    if (event == 'onMessage' || event == 'onBackground' ||
        event == 'onOpenedApp' || event == 'getInitialMessage') return kPrimary;
    return kMuted;
  }

  String _timeStr(String isoTs) {
    try {
      final dt = DateTime.parse(isoTs);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return diff.inSeconds.toString() + 's ago';
      if (diff.inMinutes < 60) return diff.inMinutes.toString() + 'm ago';
      if (diff.inHours < 24) return diff.inHours.toString() + 'h ago';
      return dt.day.toString() + '/' + dt.month.toString() + ' ' +
        dt.hour.toString() + ':' + dt.minute.toString().padLeft(2, '0');
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
      case 'reg_permission':
        return Icons.security_rounded;
      case 'reg_apns':
        return Icons.apple_rounded;
      case 'reg_fcm_token':
        return Icons.key_rounded;
      case 'reg_backend':
        return Icons.cloud_done_rounded;
      case 'reg_error':
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
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_eventIcon(event), color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
        ],
      ),
    );
  }

  // ── Registration status panel ──
  Widget _buildRegPanel() {
    final permColor = _reg.permission == 'Granted' ? kGreen : kRed;
    final apnsColor = _reg.apnsToken.startsWith('OK') ? kGreen :
      (_reg.apnsToken == 'N/A (Android)' ? kMuted : kRed);
    final fcmColor = _reg.fcmTokenReceived ? kGreen : kRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.diagnostics_outlined, size: 18, color: kPrimary),
            const SizedBox(width: 6),
            const Text('FCM Registration Status',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kPrimary)),
            const Spacer(),
            Text(_reg.platform,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kMuted)),
          ]),
          const SizedBox(height: 10),
          _regRow('Permission', _reg.permission, permColor),
          _regRow('APNs Token', _reg.apnsToken, apnsColor),
          _regRow('FCM Token', _reg.fcmToken, fcmColor),
          if (_fullFcmToken != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text(_fullFcmToken!,
                style: const TextStyle(fontSize: 9, color: kMuted, fontFamily: 'monospace),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _fullFcmToken!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('FCM token copied'),
                      duration: Duration(seconds: 2)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Copy', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 8),
          Row(children: [
            GestureDetector(
              onTap: _checkRegStatus,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh_rounded, size: 14, color: kPrimary),
                  SizedBox(width: 4),
                  Text('Re-check', style: TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _regRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label,
          style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value,
          style: TextStyle(fontSize: 12, color: valueColor, fontWeight: FontWeight.w700),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        title: const Text('Notification Diagnostics',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () { _load(); _checkRegStatus(); },
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
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear', style: TextStyle(color: kRed))),
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
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildRegPanel(),
                if (_logs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    child: Column(children: [
                      Icon(Icons.bug_report_outlined, size: 60, color: kMuted.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('No events logged yet',
                        style: TextStyle(color: kMuted, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text('Send a notification and check back\nto see which handlers fired',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kMuted, fontSize: 12)),
                    ]),
                  )
                else
                  ..._logs.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildEntry(e),
                  )),
              ],
            ),
    );
  }
}
