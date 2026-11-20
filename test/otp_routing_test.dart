// Phase F: staging-only master OTP (F1) and the user-tapped SMS fallback (F2).
// Pure logic plus one light widget check. No network, no MSG91 call, no platform channel is exercised.
// These tests do NOT prove MSG91 delivers an SMS for retryChannel 11; that needs a real-device test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/services/staging_gate.dart';
import 'package:offro_user/screens/auth/login_screen.dart';

const _staging = 'https://offro-backend-staging-d375.up.railway.app';

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
