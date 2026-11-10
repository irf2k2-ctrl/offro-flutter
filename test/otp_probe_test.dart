// Tests for the in-app diagnostic store, scrubber and results screen.
// Sentinel secrets are pushed through the WHOLE pipeline (capture -> store -> screen -> clipboard).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/services/otp_probe_store.dart';
import 'package:offro_user/screens/auth/otp_probe_results_screen.dart';

String b64(Object o) => base64Url.encode(utf8.encode(json.encode(o))).replaceAll('=', '');

final _jwt = '${b64({'alg': 'RS256', 'typ': 'JWT'})}.${b64({'mobile': '919999912345', 'exp': 2, 'secret_claim_Z': 'CLAIM_SENTINEL'})}.SIG_SENTINEL_abc123';
const _secrets = ['9999912345', '919999912345', '4821', 'SIG_SENTINEL', 'CLAIM_SENTINEL', 'secret_claim_Z', 'Incorrect OTP', 'AUTHKEY_SENTINEL', 'reqid_SENTINEL'];

Map<String, dynamic> hostileSuccess() => {
      'type': 'success', 'message': _jwt, 'phone': '+919999912345', 'otp': '4821',
      'authkey': 'AUTHKEY_SENTINEL', 'reqId': 'reqid_SENTINEL', 'data': {'token': _jwt, 'x': 'Incorrect OTP 4821'},
    };
Map<String, dynamic> hostileFailure() => {'type': 'error', 'message': 'Incorrect OTP 4821 for 9999912345'};

void expectClean(String text) {
  for (final s in [..._secrets, _jwt]) {
    expect(text.contains(s), isFalse, reason: 'leaked "$s" in: $text');
  }
}

void main() {
  group('OtpProbeStore', () {
    test('starts with no result', () {
      final s = OtpProbeStore();
      expect(s.overall, ProbeStatus.none);
      expect(s.copyText(), contains('No diagnostic result yet'));
    });
    test('correct code -> completed; wrong code -> completed (rejected slot); both redacted', () {
      final s = OtpProbeStore()..captureResponse(hostileSuccess())..captureResponse(hostileFailure());
      expect(s.accepted!.status, ProbeStatus.completed);
      expect(s.rejected!.status, ProbeStatus.completed);
      expect(s.overall, ProbeStatus.completed);
      expectClean(s.displayText(s.accepted!));
      expectClean(s.displayText(s.rejected!));
      expectClean(s.copyText());
      expect(s.copyText(), contains('jwt-like'));
    });
    test('null, non-map and thrown cases are "failed" with fixed text', () {
      final s = OtpProbeStore()..captureResponse(null);
      expect(s.rejected!.status, ProbeStatus.failed);
      expect(s.rejected!.text, 'response=null');
      s.captureResponse('Incorrect OTP 4821 9999912345');
      expect(s.rejected!.text, 'response=String');
      s.captureFailure();
      expect(s.overall, ProbeStatus.failed);
      expect(s.rejected!.text, 'verify call threw an exception (details withheld)');
      expectClean(s.copyText());
    });
    test('clear empties everything', () {
      final s = OtpProbeStore()..captureResponse(hostileSuccess());
      s.clear();
      expect(s.overall, ProbeStatus.none);
      expect(s.accepted, isNull);
    });
  });

  group('scrubDiagnostic', () {
    test('blanks digits runs, split numbers, jwts and e-mails', () {
      for (final input in ['call 9999912345', '99999 12345', '99-99-91-23-45', '+91 99999 12345', 'otp 4821', 'a@b.com', _jwt]) {
        final out = scrubDiagnostic(input);
        expect(RegExp(r'\d{4,}').hasMatch(out), isFalse, reason: out);
        expect(out.contains('@'), isFalse);
        expect(out.contains(_jwt), isFalse);
      }
    });
    test('keeps harmless redactor output unchanged', () {
      final safe = OtpProbeStore();
      safe.captureResponse({'type': 'success', 'message': _jwt});
      expect(scrubDiagnostic(safe.accepted!.text), safe.accepted!.text);
      expect(scrubDiagnostic('len=1234 len40-199 len200+'), 'len=1234 len40-199 len200+');
    });
  });

  group('source hygiene', () {
    test('store and redactor import only dart:convert / each other (no storage, network, files)', () {
      for (final f in ['lib/core/services/otp_probe_store.dart', 'lib/core/services/otp_token_shape.dart']) {
        final imports = File(f).readAsLinesSync().where((l) => l.startsWith('import ')).toList();
        for (final i in imports) {
          expect(i == "import 'dart:convert';" || i == "import 'otp_token_shape.dart';", isTrue, reason: '$f: $i');
        }
      }
    });
  });

  group('OtpProbeLink', () {
    testWidgets('renders nothing when disabled (default build has the flag off)', (t) async {
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: OtpProbeLink())));
      expect(find.text('Diagnostic Results'), findsNothing);
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: OtpProbeLink(enabled: false))));
      expect(find.text('Diagnostic Results'), findsNothing);
    });
    testWidgets('shows and opens the results screen when enabled', (t) async {
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: OtpProbeLink(enabled: true))));
      expect(find.text('Diagnostic Results'), findsOneWidget);
      await t.tap(find.text('Diagnostic Results'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('probe-overall-status')), findsOneWidget);
    });
  });

  group('OtpProbeResultsScreen', () {
    Future<List<String>> mockClipboard(WidgetTester t) async {
      final copied = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      return copied;
    }

    testWidgets('no result yet: status shown, copy disabled', (t) async {
      await t.pumpWidget(MaterialApp(home: OtpProbeResultsScreen(store: OtpProbeStore())));
      expect(find.text('No diagnostic result yet'), findsWidgets);
      final btn = t.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Copy Safe Diagnostic Result'));
      expect(btn.onPressed, isNull);
    });
    testWidgets('completed: shows redacted text only; copied text is redacted', (t) async {
      final copied = await mockClipboard(t);
      final store = OtpProbeStore()..captureResponse(hostileSuccess())..captureResponse(hostileFailure());
      await t.pumpWidget(MaterialApp(home: OtpProbeResultsScreen(store: store)));
      expect(find.text('Probe completed'), findsWidgets);
      final shown = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? w.textSpan?.toPlainText() ?? '').join('\n');
      expectClean(shown);
      await t.tap(find.text('Copy Safe Diagnostic Result'));
      await t.pump();
      expect(copied.length, 1);
      expectClean(copied.single);
      expect(copied.single, contains('Probe completed'));
    });
    testWidgets('failed status and clear', (t) async {
      final store = OtpProbeStore()..captureFailure();
      await t.pumpWidget(MaterialApp(home: OtpProbeResultsScreen(store: store)));
      expect(find.text('Probe failed'), findsWidgets);
      await t.tap(find.text('Clear results'));
      await t.pump();
      expect(find.text('No diagnostic result yet'), findsWidgets);
    });
  });
}
