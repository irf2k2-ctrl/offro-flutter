// lib/otp_test/msg91_test_logic.dart
// PHASE B - TEMPORARY, STAGING-ONLY MSG91 COUNTRY TEST TOOL. Never merge, never ship.
// Pure Dart (no Flutter, no network, no storage) so it can be unit-tested.
//
// What this file does NOT do: it holds no OTP value, never accepts the master OTP, and masks every
// phone number and request id before anything is displayed or copied.

/// One of the five supported countries, in the order shown in the selector (alphabetical by name).
class TestCountry {
  const TestCountry(this.name, this.iso, this.dial, this.flag, this.expectedChannel);
  final String name;
  final String iso;
  final String dial; // digits only, no plus
  final String flag; // emoji
  final String expectedChannel; // what the MSG91 widget is SUPPOSED to use for the first send

  String get dialLabel => '+$dial';
  String get label => '$flag  $name  $dialLabel';
}

const kTestCountries = <TestCountry>[
  TestCountry('India', 'IN', '91', '\u{1F1EE}\u{1F1F3}', 'SMS'),
  TestCountry('Jordan', 'JO', '962', '\u{1F1EF}\u{1F1F4}', 'WhatsApp'),
  TestCountry('Nepal', 'NP', '977', '\u{1F1F3}\u{1F1F5}', 'WhatsApp'),
  TestCountry('Philippines', 'PH', '63', '\u{1F1F5}\u{1F1ED}', 'WhatsApp'),
  TestCountry('Saudi Arabia', 'SA', '966', '\u{1F1F8}\u{1F1E6}', 'WhatsApp'),
];

/// MSG91 retry channel codes (from the MSG91 OTP widget documentation).
enum RetryChoice { configured, sms, whatsapp }

String retryChoiceLabel(RetryChoice c) {
  switch (c) {
    case RetryChoice.configured:
      return 'Configured channel (send nothing)';
    case RetryChoice.sms:
      return 'SMS (code 11)';
    case RetryChoice.whatsapp:
      return 'WhatsApp (code 12)';
  }
}

/// The retry channel code to send, or null when the widget's own configuration should decide.
int? retryCode(RetryChoice c) {
  switch (c) {
    case RetryChoice.configured:
      return null;
    case RetryChoice.sms:
      return 11;
    case RetryChoice.whatsapp:
      return 12;
  }
}

String digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

/// The national number the tester typed, cleaned: digits only, and one leading 0 removed
/// (people type 05xxxxxxxx for Saudi Arabia). A leading country code is NOT guessed or stripped.
String cleanNational(String raw) {
  var d = digitsOnly(raw);
  if (d.startsWith('0')) d = d.substring(1);
  return d;
}

/// A deliberately LENIENT sanity check (this is a delivery test, not the final per-country validation,
/// which will come from libphonenumber in a later phase). Returns an error message, or null when fine.
String? sanityError(TestCountry c, String raw) {
  final n = cleanNational(raw);
  if (n.isEmpty) return 'Enter the mobile number';
  if (n.length < 6 || n.length > 12) return 'A national number is normally 6 to 12 digits';
  return null;
}

/// The exact `identifier` handed to MSG91: country code digits + national number, no plus sign.
/// This matches what the real login sends today (it strips the plus before calling sendOTP).
String identifierFor(TestCountry c, String raw) => '${c.dial}${cleanNational(raw)}';

/// +966 ••••• 1234 style display: country code and the last four digits only.
String maskPhone(TestCountry c, String raw) {
  final n = cleanNational(raw);
  if (n.length <= 4) return '${c.dialLabel} ••••';
  return '${c.dialLabel} ${'•' * (n.length - 4)}${n.substring(n.length - 4)}';
}

/// A request id is a delivery handle, not a secret, but it is still shortened: first 4 and last 3 characters.
String maskReqId(String id) {
  final s = id.trim();
  if (s.isEmpty) return '(none)';
  if (s.length <= 10) return '${s.substring(0, 2)}…';
  return '${s.substring(0, 4)}…${s.substring(s.length - 3)}';
}

/// Removes anything that looks like a phone number (7+ digits) or an OTP-looking code from free text
/// returned by MSG91, so a message can be shown and copied safely.
String scrubMessage(String s, {int maxLen = 160}) {
  var t = s.replaceAll(RegExp(r'\+?\d[\d\s\-]{6,}\d'), '[number]');
  t = t.replaceAll(RegExp(r'\b\d{4,6}\b'), '[code]');
  if (t.length > maxLen) t = '${t.substring(0, maxLen)}…';
  return t.trim();
}

enum StepKind { send, resend, resendSms, verify }

String stepLabel(StepKind k) {
  switch (k) {
    case StepKind.send:
      return 'Send';
    case StepKind.resend:
      return 'Resend';
    case StepKind.resendSms:
      return 'Resend by SMS';
    case StepKind.verify:
      return 'Verify';
  }
}

/// What the tester observed on the phone. The app cannot see which channel delivered; the tester records it.
enum Observed { notRecorded, sms, whatsapp, nothing }

String observedLabel(Observed o) {
  switch (o) {
    case Observed.notRecorded:
      return 'Not recorded';
    case Observed.sms:
      return 'Received by SMS';
    case Observed.whatsapp:
      return 'Received on WhatsApp';
    case Observed.nothing:
      return 'Nothing received';
  }
}

/// One line of the results log. Everything stored here is already masked.
class TestEntry {
  TestEntry({
    required this.at,
    required this.country,
    required this.step,
    required this.requested,
    required this.apiOk,
    required this.detail,
    this.maskedPhone = '',
    this.maskedReqId = '',
    this.observed = Observed.notRecorded,
    this.secondsToArrive,
  });
  final DateTime at;
  final TestCountry country;
  final StepKind step;
  final String requested; // e.g. "no channel sent", "retryChannel=11"
  final bool apiOk; // MSG91 answered type == success (this is NOT proof of delivery)
  final String detail; // scrubbed message
  final String maskedPhone;
  final String maskedReqId;
  Observed observed;
  int? secondsToArrive;

  String _hhmmss() {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }

  String toLine() {
    final arrive = secondsToArrive == null ? '' : ' (${secondsToArrive}s)';
    return '${_hhmmss()} | ${country.name} | ${stepLabel(step)} | $requested | '
        'MSG91 ${apiOk ? 'accepted' : 'rejected'} | $detail | ${observedLabel(observed)}$arrive';
  }
}

/// Plain-text report for Copy. Contains only masked values.
String buildReport(List<TestEntry> entries) {
  final b = StringBuffer('Phase B MSG91 country test (staging)\n');
  b.writeln('Time | Country | Step | Requested | MSG91 API result | Detail | Tester observation');
  for (final e in entries) {
    b.writeln(e.toLine());
  }
  return b.toString();
}

/// The only conditions under which the tool may run. Mirrors the existing staging probe rule:
/// explicit flag AND a debug build AND the exact staging host. Pass in the values (the screen wires the real constants).
bool testToolAllowed({required bool flag, required bool debug, required bool stagingHost}) =>
    flag && debug && stagingHost;
