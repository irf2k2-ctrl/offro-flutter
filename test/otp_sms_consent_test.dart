// Tests for Android SMS User Consent OTP autofill (shared OtpScreen: Customer + Merchant).
//
// What these cover: the pure extraction rules, the pure SmsAutofillGate decision logic (duplicate
// protection, resend race, cancellation), failure-safety of SmsConsentOtp, and what OtpScreen
// shows in its four boxes. OtpScreen calls the static MSG91 SDK and the Android plugin directly,
// so these tests do NOT prove MSG91 accepted a code, nor the native listener order; use the
// on-device checklist for that.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/screens/auth/login_screen.dart';

Widget host(Future<String?>? sms, {Key? key}) => MaterialApp(
      home: OtpScreen(key: key, phone: '+919999999999', reqId: 'REQ1', smsCode: sms, onVerified: () async {}),
    );


/// Records native listener operations so ordering/overlap can be asserted.
class FakeNative implements SmsConsentNative {
  final events = <String>[];
  final waits = <Completer<String?>>[];
  int active = 0, maxActive = 0;
  @override
  Future<void> removeListener() async {
    events.add('remove:begin');
    active++;
    if (active > maxActive) maxActive = active;
    await Future<void>.delayed(const Duration(milliseconds: 20)); // slow removal -> overlap would show
    active--;
    events.add('remove:end');
  }

  @override
  Future<String?> waitForCode() {
    events.add(active > 0 ? 'wait(DURING-REMOVAL!)' : 'wait');
    final c = Completer<String?>();
    waits.add(c);
    return c.future;
  }
}

String boxes(WidgetTester t) =>
    List.generate(4, (i) => t.widget<TextField>(find.byType(TextField).at(i)).controller!.text).join();

void main() {
  group('extractFourDigitOtp', () {
    test('exactly one stand-alone 4-digit number', () {
      expect(extractFourDigitOtp(sms: 'Your OTP is 4821. Valid for 5 minutes.'), '4821');
      expect(extractFourDigitOtp(sms: '4821 is your OTP'), '4821');
      expect(extractFourDigitOtp(sms: 'OTP 4821, do not share 4821'), '4821');
      expect(extractFourDigitOtp(sms: 'Ref 123456 OTP 4821'), '4821');
    });
    test('ambiguous SMS with several different 4-digit numbers is refused', () {
      expect(extractFourDigitOtp(sms: 'OTP 4821. Help 1800'), isNull);
      expect(extractFourDigitOtp(sms: '1234 5678'), isNull);
      expect(extractFourDigitOtp(sms: 'Use 4821 before 2026'), isNull);
    });
    test('too short, too long, non-ASCII digits, empty', () {
      expect(extractFourDigitOtp(sms: 'code 482'), isNull);
      expect(extractFourDigitOtp(sms: 'code 48211'), isNull);
      expect(extractFourDigitOtp(sms: '٤٨٢١'), isNull);
      expect(extractFourDigitOtp(sms: 'no digits'), isNull);
      expect(extractFourDigitOtp(code: null, sms: null), isNull);
    });
    test('falls back to code only when there is no SMS text', () {
      expect(extractFourDigitOtp(code: '4821'), '4821');
      expect(extractFourDigitOtp(code: '48211'), isNull);
    });
  });

  group('SmsAutofillGate', () {
    SmsGateAction r(SmsAutofillGate g, int gen, String? code, {bool verifying = false, bool resending = false}) =>
        g.onResult(gen, code, verifying: verifying, resending: resending);

    test('applies a valid code once; a duplicate result for the same listener is dropped', () {
      final g = SmsAutofillGate();
      final gen = g.begin();
      expect(r(g, gen, '4821'), SmsGateAction.apply);
      expect(r(g, gen, '4821'), SmsGateAction.drop); // duplicate SMS result
      expect(r(g, gen, '9999'), SmsGateAction.drop); // even a different code for the same listener
    });
    test('drops null, malformed and non-ASCII codes', () {
      final g = SmsAutofillGate();
      final gen = g.begin();
      for (final v in <String?>[null, '', '48', '48211', 'abcd', '٤٨٢١']) {
        expect(r(g, gen, v), SmsGateAction.drop, reason: '$v');
      }
      expect(r(g, gen, '4821'), SmsGateAction.apply); // a bad value did not consume the listener
    });
    test('drops a result while a verification is already running (no duplicate verification)', () {
      final g = SmsAutofillGate();
      final gen = g.begin();
      expect(r(g, gen, '4821', verifying: true), SmsGateAction.drop);
    });
    test('SMS during resend is HELD, then applied exactly once when the resend finishes', () {
      final g = SmsAutofillGate();
      final gen = g.begin(); // resend started its new listener
      expect(r(g, gen, '4821', resending: true), SmsGateAction.hold);
      expect(g.takeHeld(), '4821');   // resend finished -> apply
      expect(g.takeHeld(), isNull);   // never twice
      expect(r(g, gen, '4821'), SmsGateAction.drop); // a duplicate afterwards is dropped
    });
    test('SMS from the previous listener is dropped after a resend starts a new one', () {
      final g = SmsAutofillGate();
      final oldGen = g.begin();
      final newGen = g.begin();
      expect(r(g, oldGen, '1111'), SmsGateAction.drop);
      expect(r(g, newGen, '2222'), SmsGateAction.apply);
    });
    test('a held code is discarded if a newer listener starts', () {
      final g = SmsAutofillGate();
      final gen = g.begin();
      expect(r(g, gen, '4821', resending: true), SmsGateAction.hold);
      g.begin();
      expect(g.takeHeld(), isNull);
    });
    test('listener cancellation / screen disposal: nothing is applied or held afterwards', () {
      final g = SmsAutofillGate();
      final gen = g.begin();
      expect(r(g, gen, '4821', resending: true), SmsGateAction.hold);
      g.invalidate();
      expect(g.takeHeld(), isNull);
      expect(r(g, gen, '4821'), SmsGateAction.drop);
    });
  });


  group('SmsConsentOtp serializes native listener operations', () {
    late FakeNative n;
    setUp(() {
      n = FakeNative();
      SmsConsentOtp.debugNative = n;
    });
    tearDown(() => SmsConsentOtp.debugNative = null);
    const rm = ['remove:begin', 'remove:end'];

    test('two overlapping start() calls: removals never overlap; only the newest registers', () async {
      final a = SmsConsentOtp.start();
      final b = SmsConsentOtp.start();
      final sa = await a;
      final sb = await b;
      expect(n.maxActive, 1);
      expect(n.events, [...rm, 'wait']);          // the superseded start never touched the native layer
      expect(await sa.code, isNull);
      n.waits.single.complete('4821');
      expect(await sb.code, '4821');
    });
    test('start() superseded WHILE removing never registers; removals stay sequential', () async {
      final a = SmsConsentOtp.start();
      await Future<void>.delayed(const Duration(milliseconds: 5)); // A is inside its removal
      final b = SmsConsentOtp.start();
      final sa = await a;
      final sb = await b;
      expect(n.maxActive, 1);
      expect(n.events, [...rm, ...rm, 'wait']);   // A removed, did NOT register; B removed then registered
      expect(await sa.code, isNull);
      n.waits.single.complete('1111');
      expect(await sb.code, '1111');
    });
    test('cancel() right after start() prevents registration', () async {
      final a = SmsConsentOtp.start();
      final c = SmsConsentOtp.cancel();
      final sa = await a;
      await c;
      expect(n.events, rm);                        // only the cancel's removal ran
      expect(n.waits, isEmpty);
      expect(await sa.code, isNull);
    });
    test('cancel() while the start() is removing prevents registration', () async {
      final a = SmsConsentOtp.start();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final c = SmsConsentOtp.cancel();
      final sa = await a;
      await c;
      expect(n.maxActive, 1);
      expect(n.events, [...rm, ...rm]);            // no 'wait'
      expect(await sa.code, isNull);
    });
    test('sequential start() -> start(): remove, register, remove, register; old result discarded', () async {
      final sa = await SmsConsentOtp.start();
      final sb = await SmsConsentOtp.start();
      expect(n.events, [...rm, 'wait', ...rm, 'wait']);
      expect(n.maxActive, 1);
      n.waits[0].complete('1111');                 // the replaced listener's late result
      n.waits[1].complete('2222');
      expect(await sa.code, isNull);
      expect(await sb.code, '2222');
    });
    test('cancel() after registration removes the listener and discards a later result', () async {
      final s = await SmsConsentOtp.start();
      await SmsConsentOtp.cancel();
      expect(n.events, [...rm, 'wait', ...rm]);
      n.waits.single.complete('4821');
      expect(await s.code, isNull);
    });
  });

  group('SmsConsentOtp is failure-safe (no exception, no code)', () {
    test('Android path without the native plugin resolves to null and cancel() completes', () async {
      final s = await SmsConsentOtp.start();
      final v = await s.code.timeout(const Duration(seconds: 3), onTimeout: () => 'TIMEOUT');
      expect(v, isNull);
      await SmsConsentOtp.cancel();
    });
    test('a newer start() supersedes the previous one', () async {
      final a = SmsConsentOtp.start();
      final b = SmsConsentOtp.start();
      final sa = await a;
      final sb = await b;
      expect(await sa.code.timeout(const Duration(seconds: 3), onTimeout: () => 'TIMEOUT'), isNull);
      expect(await sb.code.timeout(const Duration(seconds: 3), onTimeout: () => 'TIMEOUT'), isNull);
      await SmsConsentOtp.cancel();
    });
    test('unsupported platform (iOS) resolves to null immediately', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(await (await SmsConsentOtp.start()).code, isNull);
    });
  });

  group('OtpScreen SMS autofill (each scenario has its own widget tree and State)', () {
    testWidgets('a valid SMS code fills the four boxes', (t) async {
      final c = Completer<String?>();
      await t.pumpWidget(host(c.future, key: UniqueKey()));
      expect(boxes(t), '');
      c.complete('4821');
      await t.pump(const Duration(milliseconds: 50));
      expect(boxes(t), '4821');
    });

    // One testWidgets per value => a brand-new State every time (no reuse of a previous screen).
    final cases = <String, String?>{
      'declined / no result': null,
      'too short': '48',
      'too long': '48211',
      'letters': 'abcd',
      'ambiguous SMS (two different 4-digit numbers)': extractFourDigitOtp(sms: 'OTP 4821. Help 1800'),
    };
    cases.forEach((name, value) {
      testWidgets('$name leaves the boxes empty', (t) async {
        final c = Completer<String?>();
        await t.pumpWidget(host(c.future, key: UniqueKey()));
        c.complete(value);
        await t.pump(const Duration(milliseconds: 50));
        expect(boxes(t), '');
      });
    });

    testWidgets('manual entry still works after the SMS consent was declined', (t) async {
      final c = Completer<String?>();
      await t.pumpWidget(host(c.future, key: UniqueKey()));
      c.complete(null); // user tapped "Deny"
      await t.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 3; i++) {
        await t.enterText(find.byType(TextField).at(i), '${i + 1}');
        await t.pump();
      }
      expect(boxes(t), '123');
    });
    testWidgets('no SMS future at all: manual entry works', (t) async {
      await t.pumpWidget(host(null, key: UniqueKey()));
      await t.enterText(find.byType(TextField).at(0), '9');
      await t.pump();
      expect(boxes(t), '9');
    });
    testWidgets('a result after the screen is disposed is ignored (no exception)', (t) async {
      final c = Completer<String?>();
      await t.pumpWidget(host(c.future, key: UniqueKey()));
      await t.pumpWidget(const MaterialApp(home: SizedBox())); // screen disposed -> listener cancelled
      c.complete('4821');
      await t.pump(const Duration(milliseconds: 50));
      expect(t.takeException(), isNull);
    });
  });
}
