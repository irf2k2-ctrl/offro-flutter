// Phase B (temporary, staging-only tool): unit tests for the pure logic. No network, no SDK.
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/otp_test/msg91_test_logic.dart';

void main() {
  final india = kTestCountries.firstWhere((c) => c.iso == 'IN');
  final saudi = kTestCountries.firstWhere((c) => c.iso == 'SA');

  test('exactly the five supported countries, alphabetical, with the right codes and expected channels', () {
    expect(kTestCountries.map((c) => c.name).toList(),
        ['India', 'Jordan', 'Nepal', 'Philippines', 'Saudi Arabia']);
    final names = kTestCountries.map((c) => c.name).toList();
    expect(names, [...names]..sort());
    expect(kTestCountries.map((c) => c.dialLabel).toList(), ['+91', '+962', '+977', '+63', '+966']);
    expect(kTestCountries.map((c) => c.expectedChannel).toList(),
        ['SMS', 'WhatsApp', 'WhatsApp', 'WhatsApp', 'WhatsApp']);
    for (final c in kTestCountries) {
      expect(c.flag.isNotEmpty, isTrue);
    }
  });

  test('identifier is country code digits plus national number with no plus, and one leading 0 is dropped', () {
    expect(identifierFor(india, '98765 43210'), '919876543210');
    expect(identifierFor(saudi, '0501234567'), '966501234567');
    expect(identifierFor(saudi, '501234567'), '966501234567');
    expect(identifierFor(saudi, '+9665012'), '9669665012'); // nothing is guessed or stripped except one leading 0
  });

  test('sanity check is lenient but rejects empty and absurd lengths', () {
    expect(sanityError(india, ''), isNotNull);
    expect(sanityError(india, '123'), isNotNull);
    expect(sanityError(india, '1234567890123'), isNotNull);
    expect(sanityError(india, '9876543210'), isNull);
    expect(sanityError(saudi, '501234567'), isNull);
  });

  test('retry channel codes: none for the configured channel, 11 for SMS, 12 for WhatsApp', () {
    expect(retryCode(RetryChoice.configured), isNull);
    expect(retryCode(RetryChoice.sms), 11);
    expect(retryCode(RetryChoice.whatsapp), 12);
  });

  test('masking never reveals more than the code and the last four digits', () {
    final m = maskPhone(saudi, '0501234567');
    expect(m, '+966 •••••4567');
    expect(m.contains('50123'), isFalse);
    expect(maskReqId('3463abcdef43931'), '3463…931');
    expect(maskReqId(''), '(none)');
    expect(maskReqId('abc'), 'ab…');
  });

  test('scrubMessage removes phone-like numbers and code-like digits', () {
    final s = scrubMessage('OTP 123456 sent to +966 50 123 4567 for request');
    expect(s.contains('123456'), isFalse);
    expect(s.contains('4567'), isFalse);
    expect(s.contains('966'), isFalse);
    expect(scrubMessage('x' * 400).length <= 161, isTrue);
  });

  test('report contains only masked values and the tester observation', () {
    final e = TestEntry(
      at: DateTime(2026, 11, 20, 16, 5, 9),
      country: saudi,
      step: StepKind.send,
      requested: 'no channel sent',
      apiOk: true,
      detail: 'request id 3463…931',
      maskedPhone: maskPhone(saudi, '0501234567'),
    );
    e.observed = Observed.whatsapp;
    e.secondsToArrive = 12;
    final r = buildReport([e]);
    expect(r.contains('Saudi Arabia'), isTrue);
    expect(r.contains('Received on WhatsApp (12s)'), isTrue);
    expect(r.contains('0501234567'), isFalse);
    expect(r.contains('501234567'), isFalse);
  });

  test('the tool runs only with the flag AND a debug build AND the staging host', () {
    expect(testToolAllowed(flag: true, debug: true, stagingHost: true), isTrue);
    expect(testToolAllowed(flag: false, debug: true, stagingHost: true), isFalse);
    expect(testToolAllowed(flag: true, debug: false, stagingHost: true), isFalse);
    expect(testToolAllowed(flag: true, debug: true, stagingHost: false), isFalse);
  });
}
