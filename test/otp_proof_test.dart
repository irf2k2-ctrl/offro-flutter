import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/services/otp_proof.dart';

void main() {
  const jwt = 'eyJhbGciOiJSUzI1NiJ9.eyJyZXF1ZXN0SWQiOiIxMjMifQ.c2lnbmF0dXJl';

  test('token in message (MSG91 SDK success response)', () {
    expect(otpProofFromVerifyResponse({'type': 'success', 'message': jwt}), {'kind': 'msg91', 'token': jwt});
  });
  test('token under a named key wins over message', () {
    expect(otpProofFromVerifyResponse({'type': 'success', 'access_token': jwt, 'message': 'OTP verified'})!['token'], jwt);
    expect(otpProofFromVerifyResponse({'accessToken': jwt})!['token'], jwt);
    expect(otpProofFromVerifyResponse({'access-token': jwt})!['token'], jwt);
  });
  test('token nested in data', () {
    expect(otpProofFromVerifyResponse({'type': 'success', 'data': {'token': jwt}})!['token'], jwt);
  });
  test('plain text messages are not tokens', () {
    expect(otpProofFromVerifyResponse({'type': 'success', 'message': 'OTP verified successfully'}), isNull);
    expect(otpProofFromVerifyResponse({'type': 'success', 'message': 'ok'}), isNull);
  });
  test('null and non-map responses', () {
    expect(otpProofFromVerifyResponse(null), isNull);
    expect(otpProofFromVerifyResponse('x' * 30), isNull);
    expect(otpProofFromVerifyResponse([jwt]), isNull);
  });
  test('whitespace is trimmed', () {
    expect(otpProofFromVerifyResponse({'message': '  $jwt  '})!['token'], jwt);
  });
  test('staging proof shape', () {
    expect(stagingTestProof('1234'), {'kind': 'staging_test', 'code': '1234'});
  });
}
