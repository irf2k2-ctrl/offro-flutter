// lib/core/widgets/notif_diag_overlay.dart
// ─────────────────────────────────────────────────────────────
// TEMPORARY diagnostic overlay — iOS foreground notification debug.
// Shows real-time status of every step in the onMessage chain.
// Remove this file + its import + builder usage after debugging.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Global singleton state for the diagnostic overlay.
/// Updated from main.dart at each checkpoint in the notification chain.
class NotifDiag {
  NotifDiag._();

  static ValueNotifier<bool>   firebaseInit     = ValueNotifier(false);
  static ValueNotifier<String> apnsToken        = ValueNotifier('—');
  static ValueNotifier<String> fcmToken         = ValueNotifier('—');
  static ValueNotifier<String> lastOnMessage    = ValueNotifier('NEVER');
  static ValueNotifier<String> lastTitle        = ValueNotifier('');
  static ValueNotifier<String> lastBody         = ValueNotifier('');
  static ValueNotifier<bool>   saveCalled       = ValueNotifier(false);
  static ValueNotifier<String> saveResult       = ValueNotifier('—');
  static ValueNotifier<String> saveError        = ValueNotifier('');
  static ValueNotifier<bool>   displayCalled    = ValueNotifier(false);

  /// Reset all fields (called on app start).
  static void reset() {
    firebaseInit.value     = false;
    apnsToken.value        = '—';
    fcmToken.value         = '—';
    lastOnMessage.value    = 'NEVER';
    lastTitle.value        = '';
    lastBody.value         = '';
    saveCalled.value       = false;
    saveResult.value       = '—';
    saveError.value        = '';
    displayCalled.value    = false;
  }
}

/// The overlay widget. Add to MaterialApp.builder via:
///   builder: (ctx, child) => Stack(children: [child!, Positioned(top:0,left:0,right:0, child: NotifDiagOverlay())])
class NotifDiagOverlay extends StatefulWidget {
  const NotifDiagOverlay({super.key});
  @override State<NotifDiagOverlay> createState() => _NotifDiagOverlayState();
}

class _NotifDiagOverlayState extends State<NotifDiagOverlay> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    if (!_expanded) {
      return GestureDetector(
        onTap: () => setState(() => _expanded = true),
        child: Container(
          margin: EdgeInsets.only(top: topPad, right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bug_report, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text('DIAG', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.only(top: topPad, left: 6, right: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.redAccent, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.redAccent, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'NOTIF DIAGNOSTIC',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _expanded = false),
                  child: const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),

            _diagRow('Firebase init',
              ValueListenableBuilder<bool>(
                valueListenable: NotifDiag.firebaseInit,
                builder: (_, v, __) => _badge(v ? 'YES' : 'NO', v ? Colors.green : Colors.red),
              ),
            ),
            const SizedBox(height: 4),

            _diagRow('APNs token',
              ValueListenableBuilder<String>(
                valueListenable: NotifDiag.apnsToken,
                builder: (_, v, __) => _badge(
                  v == 'null' || v == '—' ? 'NULL' : 'OK',
                  v == 'null' || v == '—' ? Colors.red : Colors.green,
                  subtext: v.length > 12 ? '${v.substring(0, 8)}...' : v,
                ),
              ),
            ),
            const SizedBox(height: 4),

            _diagRow('FCM token',
              ValueListenableBuilder<String>(
                valueListenable: NotifDiag.fcmToken,
                builder: (_, v, __) => _badge(
                  v == 'null' || v == '—' ? 'NULL' : 'OK',
                  v == 'null' || v == '—' ? Colors.red : Colors.green,
                  subtext: v.length > 12 ? '${v.substring(0, 8)}...' : v,
                ),
              ),
            ),
            const SizedBox(height: 4),

            _diagRow('onMessage event',
              ValueListenableBuilder<String>(
                valueListenable: NotifDiag.lastOnMessage,
                builder: (_, v, __) => _badge(
                  v == 'NEVER' ? 'NEVER' : 'FIRED',
                  v == 'NEVER' ? Colors.red : Colors.green,
                  subtext: v == 'NEVER' ? '' : v.substring(11),
                ),
              ),
            ),
            const SizedBox(height: 4),

            ValueListenableBuilder<String>(
              valueListenable: NotifDiag.lastTitle,
              builder: (_, title, __) => ValueListenableBuilder<String>(
                valueListenable: NotifDiag.lastBody,
                builder: (_, body, __) {
                  if (title.isEmpty) {
                    return _diagRow('Last notif', _badge('—', Colors.white24));
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Title: $title',
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      if (body.isNotEmpty)
                        Text('Body: $body',
                          style: const TextStyle(color: Colors.white60, fontSize: 9),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),

            _diagRow('saveNotif() called',
              ValueListenableBuilder<bool>(
                valueListenable: NotifDiag.saveCalled,
                builder: (_, v, __) => _badge(v ? 'YES' : 'NO', v ? Colors.green : Colors.white24),
              ),
            ),
            const SizedBox(height: 4),

            _diagRow('Save result',
              ValueListenableBuilder<String>(
                valueListenable: NotifDiag.saveResult,
                builder: (_, v, __) {
                  Color c = Colors.white24;
                  if (v == 'SUCCESS') c = Colors.green;
                  else if (v == 'SKIPPED') c = Colors.orange;
                  else if (v == 'FAILED') c = Colors.red;
                  return _badge(v, c);
                },
              ),
            ),
            const SizedBox(height: 4),

            ValueListenableBuilder<String>(
              valueListenable: NotifDiag.saveError,
              builder: (_, v, __) {
                if (v.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Exception: $v',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 9),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),

            _diagRow('showLocalNotif()',
              ValueListenableBuilder<bool>(
                valueListenable: NotifDiag.displayCalled,
                builder: (_, v, __) => _badge(v ? 'YES' : 'NO', v ? Colors.green : Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String label, Widget valueWidget) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ),
        Expanded(child: valueWidget),
      ],
    );
  }

  Widget _badge(String text, Color color, {String subtext = ''}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            border: Border.all(color: color, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(text,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        if (subtext.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(subtext,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
