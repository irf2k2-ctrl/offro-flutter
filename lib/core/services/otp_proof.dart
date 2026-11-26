// lib/core/services/otp_proof.dart
// Phase 2 / D2. Pure Dart (no Flutter imports) so it is unit-testable anywhere.
//
// After the MSG91 widget SDK says an OTP is verified, the app must give the BACKEND something it can check, because /user/account-login
// and /merchant/login no longer accept a phone number on its own. That something is the widget's ACCESS TOKEN, taken from the
// OTPWidget.verifyOTP response. The backend asks MSG91 whether the token is genuine and which number it verified, so nothing here is
// trusted: this file only picks the token out of the response. It never prints or stores it.

/// Keys of an MSG91 verifyOTP response that may hold the access token, in order of preference.
const List<String> kOtpTokenKeys = ['access_token', 'accessToken', 'access-token', 'token', 'jwt'];

/// Shortest string accepted as a token (the real one is a long JWT; a short `message` such as "OTP verified" is text, not a token).
const int kOtpTokenMinLength = 20;

/// The proof to send as `otp_proof`, or null when the response carries no token-like value.
Map<String, dynamic>? otpProofFromVerifyResponse(dynamic resp) {
  final t = _findToken(resp, 0);
  if (t == null) return null;
  return {'kind': 'msg91', 'token': t};
}

/// Proof used by the staging-only test code (the app's temporary master OTP). The backend accepts it only on the verified Staging
/// service, for listed numbers, when its own switch is on.
Map<String, dynamic> stagingTestProof(String code) => {'kind': 'staging_test', 'code': code};

String? _findToken(dynamic node, int depth) {
  if (node is! Map || depth > 2) return null;
  for (final k in kOtpTokenKeys) {
    final v = node[k];
    if (v is String && v.trim().length >= kOtpTokenMinLength) return v.trim();
  }
  final msg = node['message'];
  if (msg is String) {
    final m = msg.trim(); // judge the trimmed text: surrounding spaces must not hide a token, inner spaces still mean "a sentence"
    if (m.length >= kOtpTokenMinLength && !m.contains(' ')) return m;
  }
  final data = node['data'];
  if (data is Map) return _findToken(data, depth + 1);
  return null;
}

/// Holds the proof between the OTP screen and the login call that follows it. One use only: [take] clears it, so a proof is never
/// sent twice and never outlives the login attempt that needed it.
class OtpProofStore {
  OtpProofStore._();
  static Map<String, dynamic>? _proof;
  static void set(Map<String, dynamic>? proof) => _proof = proof;
  static Map<String, dynamic>? take() { final p = _proof; _proof = null; return p; }
  static void clear() => _proof = null;
}
