import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/services/otp_token_shape.dart';

String b64(Object o) => base64Url.encode(utf8.encode(json.encode(o))).replaceAll('=', '');

void main() {
  probeGateTests();
  group('isStagingProbeUrl (exact host only)', () {
    test('accepts the exact Staging host', () {
      expect(isStagingProbeUrl('https://offro-backend-staging-d375.up.railway.app'), isTrue);
      expect(isStagingProbeUrl('https://offro-backend-staging-d375.up.railway.app/'), isTrue);
      expect(isStagingProbeUrl('https://offro-backend-staging-d375.up.railway.app:443/api'), isTrue);
    });
    test('rejects everything else', () {
      for (final u in [
        '',
        'not a url',
        'https://offro-backend-production.up.railway.app',
        'http://offro-backend-staging-d375.up.railway.app', // not https
        'https://offro-backend-staging-d375.up.railway.app:8443',
        'https://x.offro-backend-staging-d375.up.railway.app', // sub-domain
        'https://offro-backend-staging-d375.up.railway.app.evil.com', // look-alike suffix
        'https://offro-backend-staging-d375.up.railway.app.', // trailing dot
        'https://evil.com/offro-backend-staging-d375.up.railway.app', // in path
        'https://evil.com/?h=offro-backend-staging-d375.up.railway.app', // in query
        'https://offro-backend-staging-d375.up.railway.app@evil.com', // user-info trick
        'https://offro-backend-staging-d375.up.railway.app:pw@evil.com',
        'https://user@offro-backend-staging-d375.up.railway.app', // user-info present
        'https://staging.example.com',
        'https://my-staging.up.railway.app',
        'HTTPS://OFFRO-BACKEND-STAGING-D375.UP.RAILWAY.APP.EVIL.COM',
      ]) {
        expect(isStagingProbeUrl(u), isFalse, reason: u);
      }
    });
  });

  group('describeVerifyResponse (allowlist redaction)', () {
    final header = b64({'alg': 'RS256', 'typ': 'JWT'});
    final payload = b64({'mobile': '919999912345', 'exp': 2, 'iat': 1, 'evilclaim_9999912345': 'SENTINEL_VALUE_XYZ'});
    const sig = 'SIGNATURE_SENTINEL_abc123';
    final jwt = '$header.$payload.$sig';

    test('known token-in-message case prints shape only', () {
      final out = describeVerifyResponse({'type': 'success', 'message': jwt});
      expect(out, 'message: String len=${jwt.length} jwt-like(parts=3, alg=RS256, typ=JWT, known-claims=[exp,iat,mobile], other-claims=1) | type: String "success"');
    });
    test('unknown keys and unknown type values are not printed', () {
      final out = describeVerifyResponse({'type': 'user 9999912345 OTP 4821', 'phone_9999912345': 'x', 'zzz': jwt});
      expect(out, contains('<unknown-key#1>'));
      expect(out, contains('<unknown-key#2>: String len=${jwt.length} jwt-like'));
      expect(out, contains('type: String <other>'));
      for (final leak in ['9999912345', '4821', 'phone_', 'zzz', 'user ']) {
        expect(out.contains(leak), isFalse, reason: 'leaked $leak');
      }
    });
    test('unknown / hostile claim names and values never printed', () {
      final out = describeVerifyResponse({'message': jwt});
      for (final leak in ['evilclaim', 'SENTINEL', '919999912345', jwt, header, payload, sig]) {
        expect(out.contains(leak), isFalse, reason: 'leaked $leak');
      }
    });
    test('hostile JWT header values become ?', () {
      final h = b64({'alg': 'alg_9999912345', 'typ': 'secret-typ'});
      final out = describeVerifyResponse({'message': '$h.${b64({'a': 1})}.sig'});
      expect(out, contains('alg=?, typ=?'));
      expect(out.contains('9999912345'), isFalse);
      expect(out.contains('secret-typ'), isFalse);
    });
    test('plain strings (request id, OTP, phone, message text) only get a size bucket', () {
      final out = describeVerifyResponse({'message': '3566abcdef0123456789abcd', 'code': '4821', 'error': 'Incorrect OTP for 9999912345'});
      expect(out, contains('message: String len<40 not-jwt'));
      expect(out, contains('code: String len<40 not-jwt'));
      for (final leak in ['3566abcdef', '4821', '9999912345', 'Incorrect']) {
        expect(out.contains(leak), isFalse, reason: 'leaked $leak');
      }
    });
    test('nested values: unknown nested keys generic, deeper levels collapsed', () {
      final out = describeVerifyResponse({'data': {'token': jwt, 'x9999912345': 'v', 'deep': {'a': 'b'}}});
      expect(out, contains('data: Map{'));
      expect(out, contains('token: String len=${jwt.length} jwt-like'));
      expect(out, contains('<unknown-key#'));
      expect(out.contains('9999912345'), isFalse);
      expect(out.contains('deep'), isFalse);
    });
    test('null / non-map / non-string keys / lists', () {
      expect(describeVerifyResponse(null), 'response=null');
      expect(describeVerifyResponse('secret text'), 'response=String');
      expect(describeVerifyResponse(['a']), 'response=List');
      expect(describeVerifyResponse({1: 'x'}), '<unknown-key#1>: String len<40 not-jwt');
    });
  });
}

// ---- activation rule -------------------------------------------------------------------
void probeGateTests() {
  group('probeActive (flag + debug + exact host)', () {
    const ok = 'https://offro-backend-staging-d375.up.railway.app';
    test('only true when all three hold', () {
      expect(probeActive(flag: true, debug: true, baseUrl: ok), isTrue);
      expect(probeActive(flag: false, debug: true, baseUrl: ok), isFalse);
      expect(probeActive(flag: true, debug: false, baseUrl: ok), isFalse);
      expect(probeActive(flag: true, debug: true, baseUrl: 'https://offro-backend-production.up.railway.app'), isFalse);
      expect(probeActive(flag: true, debug: true, baseUrl: 'https://evil.com/offro-backend-staging-d375.up.railway.app'), isFalse);
      expect(probeActive(flag: true, debug: true, baseUrl: ''), isFalse);
    });
  });
}
