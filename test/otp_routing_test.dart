// Phase F: staging-only master OTP (F1) and the user-tapped SMS fallback (F2).
// Pure logic plus light widget checks. No network, no MSG91 call. The SMS User Consent native layer is replaced by a no-op fake
// (SmsConsentOtp.debugNative): OtpScreen.dispose() calls SmsConsentOtp.cancel(), which in a test run would otherwise reach the real
// smart_auth plugin, whose reply never arrives, leaving its 2 s guard timer pending when the test ends.
// These tests do NOT prove MSG91 delivers an SMS for retryChannel 11; that needs a real-device test.
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/services/staging_gate.dart';
import 'package:offro_user/screens/auth/login_screen.dart';

const _staging = 'https://offro-backend-staging-d375.up.railway.app';

/// Stands in for the Android SMS User Consent plugin; counts how often the listener is released.
class _NoopSmsNative implements SmsConsentNative {
  int removals = 0;
  @override
  Future<void> removeListener() async {
    removals++;
  }

  @override
  Future<String?> waitForCode() async => null;
}

void main() {
  group('F1: master OTP is honoured only on the exact staging host', () {
    test('accepted on the staging host (with or without a path, slash or the default port)', () {
      for (final u in [
        _staging,
        '$_staging/',
        '$_staging/user/check-phone',
        '$_staging:443',
        '  $_staging  ',
        'HTTPS://OFFRO-BACKEND-STAGING-D375.UP.RAILWAY.APP',
      ]) {
        expect(isStagingApiUrl(u), isTrue, reason: u);
        expect(isMasterOtp('1234', baseUrl: u), isTrue, reason: u);
      }
    });

    test('rejected for an empty, blank or unparsable URL', () {
      for (final u in ['', '   ', 'not a url', '://', 'offro-backend-staging-d375.up.railway.app']) {
        expect(isStagingApiUrl(u), isFalse, reason: '"$u"');
        expect(isMasterOtp('1234', baseUrl: u), isFalse, reason: '"$u"');
      }
    });

    test('rejected for production and any other host', () {
      for (final u in [
        'https://api.theoffro.com',
        'https://offro-backend-production.up.railway.app',
        'https://offro-backend.up.railway.app',
        'http://localhost:8000',
        'http://10.0.2.2:8000',
      ]) {
        expect(isMasterOtp('1234', baseUrl: u), isFalse, reason: u);
      }
    });

    test('rejected for look-alike hosts and tricks', () {
      for (final u in [
        'https://evil-offro-backend-staging-d375.up.railway.app',
        'https://sub.offro-backend-staging-d375.up.railway.app',
        'https://offro-backend-staging-d375.up.railway.app.evil.com',
        'https://offro-backend-staging-d375.up.railway.app.', // trailing dot
        'https://evil.com/offro-backend-staging-d375.up.railway.app',
        'https://evil.com/?h=offro-backend-staging-d375.up.railway.app',
        'https://offro-backend-staging-d375.up.railway.app@evil.com',
        'https://offro-backend-staging-d375.up.railway.app:evil@evil.com',
        'https://user@offro-backend-staging-d375.up.railway.app', // user-info
        'https://offro-backend-staging-d375.up.railway.app:8443', // custom port
        'http://offro-backend-staging-d375.up.railway.app', // not https
        'ftp://offro-backend-staging-d375.up.railway.app',
      ]) {
        expect(isStagingApiUrl(u), isFalse, reason: u);
        expect(isMasterOtp('1234', baseUrl: u), isFalse, reason: u);
      }
    });

    test('only the exact code 1234 is the master OTP, even on staging', () {
      for (final otp in ['', '123', '12345', '4321', '0000', ' 1234', '1234 ', 'abcd']) {
        expect(isMasterOtp(otp, baseUrl: _staging), isFalse, reason: '"$otp"');
      }
      expect(isMasterOtp('1234', baseUrl: _staging), isTrue);
    });

    test('a build with no API_BASE_URL (this test run) rejects 1234 by default: fails closed', () {
      expect(isMasterOtp('1234'), isFalse);
    });
  });

  group('F2: SMS fallback', () {
    // SmsConsentOtp keeps a STATIC serial queue (`_tail`). A Dart future remembers the zone it was created in, and a testWidgets body
    // runs in a FakeAsync zone that is discarded when the test ends. If the queue were first touched inside a widget test, every
    // later cancel() would schedule its work into that dead zone and never run. Touching it once here, in the real zone, keeps the
    // queue usable for the whole group (production code is not involved: this only calls its public cancel() with the fake).
    setUpAll(() async {
      SmsConsentOtp.debugNative = _NoopSmsNative();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await SmsConsentOtp.cancel();
      } finally {
        debugDefaultTargetPlatformOverride = null;
        SmsConsentOtp.debugNative = null;
      }
    });

    late _NoopSmsNative native;
    setUp(() {
      native = _NoopSmsNative();
      SmsConsentOtp.debugNative = native;
    });
    tearDown(() => SmsConsentOtp.debugNative = null);

    test('offered for the four non-India countries only', () {
      for (final iso in ['JO', 'NP', 'PH', 'SA', 'sa', ' SA ']) {
        expect(showSmsFallback(iso), isTrue, reason: iso);
      }
      for (final iso in [null, '', ' ', 'IN', 'in', 'US', 'XX']) {
        expect(showSmsFallback(iso), isFalse, reason: '$iso');
      }
    });

    test('retry body: normal Resend is unchanged, SMS fallback adds retryChannel 11', () {
      expect(kMsg91SmsRetryChannel, 11);
      expect(otpRetryBody('REQ1'), {'reqId': 'REQ1'});
      expect(otpRetryBody('REQ1', smsFallback: false), {'reqId': 'REQ1'});
      expect(otpRetryBody('REQ1', smsFallback: true), {'reqId': 'REQ1', 'retryChannel': 11});
    });

    test('SmsConsentOtp.cancel() releases the native listener through the debugNative seam (Android only)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await SmsConsentOtp.cancel(); // not Android: nothing to release, the native layer is not touched
        expect(native.removals, 0);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        await SmsConsentOtp.cancel();
        await SmsConsentOtp.cancel();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(native.removals, 2, reason: 'each cancel() removes the listener once, in order');
    });

    Future<void> pumpOtp(WidgetTester t, {String? countryIso}) async {
      await t.pumpWidget(MaterialApp(
        home: OtpScreen(phone: '+966501234567', reqId: 'REQ1', onVerified: () async {}, countryIso: countryIso),
      ));
      await t.pump();
    }

    Future<void> close(WidgetTester t) async {
      await t.pumpWidget(const SizedBox()); // dispose the screen so its resend timer is cancelled
      await t.pump();
    }

    // Keep this the FIRST widget test of the group (see setUpAll): it counts the removal that OtpScreen.dispose() triggers.
    testWidgets('closing the OTP screen releases the SMS listener once and leaves no timer behind', (t) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android; // the only platform where the listener exists
      try {
        await pumpOtp(t, countryIso: 'SA');
        expect(native.removals, 0, reason: 'nothing is released while the screen is open');
        await close(t); // fails with "A Timer is still pending" if the resend timer or the native guard were left running
        // cancel() queues the removal behind the (real-zone) queue; give the real event loop a turn to run it.
        await t.runAsync(() => Future<void>.delayed(Duration.zero));
        expect(native.removals, 1, reason: 'dispose() calls SmsConsentOtp.cancel() exactly once');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('link is shown for Saudi Arabia, and the normal Resend line is still there', (t) async {
      await pumpOtp(t, countryIso: 'SA');
      expect(find.byKey(const ValueKey('sms_fallback_link')), findsOneWidget);
      expect(find.text('Send code by SMS instead'), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
      await close(t);
    });

    testWidgets('link is NOT shown for India or when no country is given (existing screens unchanged)', (t) async {
      await pumpOtp(t, countryIso: 'IN');
      expect(find.byKey(const ValueKey('sms_fallback_link')), findsNothing);
      await close(t);
      await pumpOtp(t);
      expect(find.byKey(const ValueKey('sms_fallback_link')), findsNothing);
      await close(t);
    });
  });
}
