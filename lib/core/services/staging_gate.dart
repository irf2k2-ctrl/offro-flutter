// lib/core/services/staging_gate.dart
// Phase F1: the temporary master OTP (1234) is honoured ONLY by a build whose API_BASE_URL is exactly the staging backend.
// Production builds, builds with no API_BASE_URL, and any other host reject it. Fails closed.
//
// Temporary testing arrangement, to be removed before international production launch (separate pre-launch task: remove the
// master OTP branch from OtpScreen._verify entirely and delete this file).

import '../constants/app_constants.dart' show kBaseUrl;

/// The one staging backend host (exact match, nothing else).
const String kStagingApiHost = 'offro-backend-staging-d375.up.railway.app';

/// The temporary master OTP.
const String kMasterOtp = '1234';

/// True only for https://offro-backend-staging-d375.up.railway.app[/...] with no user-info and no custom port. No sub-domain,
/// no trailing dot, no look-alike host, and "staging" merely appearing in a path or in user-info does not count. Empty, blank
/// or unparsable values are false.
bool isStagingApiUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null) return false;
  return u.scheme == 'https' &&
      u.host == kStagingApiHost &&
      u.userInfo.isEmpty &&
      (!u.hasPort || u.port == 443);
}

/// Whether [otp] is the master OTP AND this build is allowed to honour it. [baseUrl] defaults to the build's API_BASE_URL.
bool isMasterOtp(String otp, {String baseUrl = kBaseUrl}) => otp == kMasterOtp && isStagingApiUrl(baseUrl);
