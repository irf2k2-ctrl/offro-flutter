// Test-only. Applies to every test file in this folder.
//
// OtpScreen.dispose() calls SmsConsentOtp.cancel(); on the (test-default) Android platform that reaches the real smart_auth plugin, which
// has no native side in a test run (PlatformException channel-error). Individual OTP tests already substitute a fake; this makes the safe
// no-op the default for every test so a screen that is mounted by any other test cannot hit the missing plugin either. A test that sets
// its own SmsConsentOtp.debugNative still wins (its setUp runs after this one). Production code is untouched.
import 'dart:async';

import 'package:offro_user/screens/auth/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoNativePlugin implements SmsConsentNative {
  @override
  Future<void> removeListener() async {}
  @override
  Future<String?> waitForCode() async => null;
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => SmsConsentOtp.debugNative = _NoNativePlugin());
  tearDown(() => SmsConsentOtp.debugNative = _NoNativePlugin()); // runs after a test's own tearDown(() => debugNative = null)
  await testMain();
}
