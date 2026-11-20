// lib/otp_test/msg91_country_test_main.dart
// PHASE B - TEMPORARY, STAGING-ONLY MSG91 COUNTRY TEST TOOL. Never merge, never ship.
//
// Separate entry point, so no existing screen or the real app's main() is touched. Run it with:
//   flutter run -t lib/otp_test/msg91_country_test_main.dart \
//     --dart-define=OTP_COUNTRY_TEST=true \
//     --dart-define=API_BASE_URL=https://offro-backend-staging-d375.up.railway.app
// It refuses to start unless the flag is set, the build is a debug build, and API_BASE_URL is the exact staging host.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart' show kBaseUrl;
import '../core/services/otp_token_shape.dart' show isStagingProbeUrl;
import 'msg91_country_test_screen.dart';
import 'msg91_test_logic.dart';

const bool _kOtpCountryTest = bool.fromEnvironment('OTP_COUNTRY_TEST');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final allowed = testToolAllowed(
    flag: _kOtpCountryTest,
    debug: kDebugMode,
    stagingHost: isStagingProbeUrl(kBaseUrl),
  );
  runApp(allowed ? const Msg91TestApp() : const BlockedTestApp());
}
