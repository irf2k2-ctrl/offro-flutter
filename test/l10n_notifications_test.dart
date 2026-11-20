// Phase J, batch 5: notification diagnostics screens in English and Arabic.
// Needs the generated localizations (lib/l10n/gen): run `flutter gen-l10n` first.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/l10n/gen/app_localizations_ar.dart';
import 'package:offro_user/l10n/gen/app_localizations_en.dart';

Map<String, dynamic> _arb(String f) =>
    json.decode(File('lib/l10n/$f').readAsStringSync()) as Map<String, dynamic>;

void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();
  final enArb = _arb('app_en.arb');
  final arArb = _arb('app_ar.arb');
  final keys = enArb.keys.where((k) => k.startsWith('notifDiag')).where((k) => !k.startsWith('@')).toList();

  test('English strings are unchanged from the original literals', () {
    expect(en.notifDiagTitle, 'Notification Diagnostics');
    expect(en.notifDiagRegStatusTitle, 'FCM Registration Status');
    expect(en.notifDiagCopy, 'Copy');
    expect(en.notifDiagRecheck, 'Re-check');
    expect(en.notifDiagTokenCopied, 'FCM token copied');
    expect(en.notifDiagCopiedToClipboard, 'Diagnostics copied to clipboard');
    expect(en.notifDiagClear, 'Clear');
    expect(en.notifDiagClearLogTitle, 'Clear Log?');
    expect(en.notifDiagClearLogBody, 'This will remove all notification event entries.');
    expect(en.notifDiagEmptyTitle, 'No events logged yet');
    expect(en.notifDiagEmptyHint, 'Send a notification and check back\nto see which handlers fired');
    expect(en.notifDiagRefresh, 'Refresh');
    expect(en.notifDiagChecking, 'Checking...');
    expect(en.notifDiagSecondsAgo('5'), '5s ago');
  });

  test('Arabic has every key, differs from English and keeps placeholders', () {
    expect(keys.length, 14);
    for (final k in keys) {
      expect(arArb.containsKey(k), isTrue, reason: k);
      expect(enArb.containsKey('@$k'), isTrue, reason: '@$k');
      expect(RegExp(r'[؀-ۿ]').hasMatch(arArb[k] as String), isTrue, reason: k);
      expect(RegExp(r'\{(\w+)\}').allMatches(arArb[k] as String).map((m) => m[1]).toSet(),
          RegExp(r'\{(\w+)\}').allMatches(enArb[k] as String).map((m) => m[1]).toSet(),
          reason: k);
    }
    expect(ar.notifDiagSecondsAgo('5'), 'منذ 5 ث');
    expect(ar.notifDiagEmptyHint.contains('\n'), isTrue);
  });

  test('ARB key sets match between English and Arabic', () {
    Set<String> k(Map m) => m.keys.where((x) => !x.startsWith('@')).cast<String>().toSet();
    expect(k(arArb), k(enArb));
  });

  test('technical identifiers stay untouched in the notification code', () {
    final fcm = File('lib/core/services/fcm_service.dart').readAsStringSync();
    expect(fcm.contains("'offro_high_importance'"), isTrue);
    final log = File('lib/screens/notif_log_screen.dart').readAsStringSync();
    for (final s in ["'Granted'", "'N/A (Android)'", "'offro_notif_event_log'", "'onMessage'", "'reg_error'"]) {
      expect(log.contains(s), isTrue, reason: s);
    }
  });

  test('migrated screens no longer contain the original UI literals', () {
    final log = File('lib/screens/notif_log_screen.dart').readAsStringSync();
    final diag = File('lib/screens/notification_diagnostics.dart').readAsStringSync();
    for (final s in ["'Clear Log?'", "'No events logged yet'", "'FCM token copied'", "'Re-check'", "'Notification Diagnostics'"]) {
      expect(log.contains(s), isFalse, reason: s);
    }
    for (final s in ["'Diagnostics copied to clipboard'", "'Notification Diagnostics'", "'Refresh'"]) {
      expect(diag.contains(s), isFalse, reason: s);
    }
  });
}
