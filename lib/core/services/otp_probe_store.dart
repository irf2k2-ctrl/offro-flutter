// lib/core/services/otp_probe_store.dart
// STAGING-ONLY DIAGNOSTIC (branch staging/msg91-probe-latest-ui - never merge, never ship).
// Pure Dart. IN-MEMORY ONLY: no storage, no network, no logging, cleared on app restart.
//
// The only way data gets in is captureResponse(raw) / captureFailure(). captureResponse
// redacts the raw MSG91 response itself through describeVerifyResponse (allowlist), so callers
// cannot hand in pre-formatted text, and nothing that is shown or copied was ever stored raw.
// Everything that leaves this class goes through scrubDiagnostic as a second safety net.

import 'otp_token_shape.dart';

enum ProbeStatus { none, completed, failed }

String probeStatusLabel(ProbeStatus s) {
  if (s == ProbeStatus.completed) return 'Probe completed';
  if (s == ProbeStatus.failed) return 'Probe failed';
  return 'No diagnostic result yet';
}

class ProbeEntry {
  const ProbeEntry(this.status, this.text, this.at);
  final ProbeStatus status;
  final String text; // already redacted
  final DateTime at;
}

/// Second line of defence. Blanks anything that looks like a phone number / OTP (4+ digits,
/// also when split by spaces or hyphens), a JWT (three dotted base64url parts) or an e-mail.
/// `len=<n>` (a string length produced by the redactor) is deliberately left alone.
String scrubDiagnostic(String s) {
  var out = s.replaceAll(RegExp(r'[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{3,}'), '[redacted]');
  out = out.replaceAll(RegExp(r'[^\s@]+@[^\s@]+'), '[redacted]');
  out = out.replaceAllMapped(RegExp(r'(len=)?\d[\d\s\-]{6,}\d'), (m) => m.group(1) != null ? m.group(0)! : '[redacted]');
  out = out.replaceAllMapped(RegExp(r'(len=)?\d{4,}'), (m) => m.group(1) != null ? m.group(0)! : '[redacted]');
  return out;
}

class OtpProbeStore {
  OtpProbeStore();
  static final OtpProbeStore instance = OtpProbeStore();

  ProbeEntry? _accepted; // verify returned type == success
  ProbeEntry? _rejected; // anything else (wrong code, error, exception)
  ProbeEntry? _latest;

  ProbeEntry? get accepted => _accepted;
  ProbeEntry? get rejected => _rejected;
  ProbeStatus get overall => _latest?.status ?? ProbeStatus.none;

  void captureResponse(dynamic raw, {DateTime? now}) {
    final at = now ?? DateTime.now();
    try {
      final safe = describeVerifyResponse(raw);
      final isMap = raw is Map;
      final ok = isMap && safe != 'probe-error';
      final entry = ProbeEntry(ok ? ProbeStatus.completed : ProbeStatus.failed, safe, at);
      final accepted = isMap && raw['type'] == 'success';
      if (accepted) {
        _accepted = entry;
      } else {
        _rejected = entry;
      }
      _latest = entry;
    } catch (_) {
      captureFailure(now: at);
    }
  }

  /// The verify call threw. Nothing about the exception is kept.
  void captureFailure({DateTime? now}) {
    final e = ProbeEntry(ProbeStatus.failed, 'verify call threw an exception (details withheld)', now ?? DateTime.now());
    _rejected = e;
    _latest = e;
  }

  void clear() {
    _accepted = null;
    _rejected = null;
    _latest = null;
  }

  String displayText(ProbeEntry e) => scrubDiagnostic(e.text);

  static String _t(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  String _block(String label, ProbeEntry? e) {
    if (e == null) return '$label: ${probeStatusLabel(ProbeStatus.none)}';
    return '$label [${_t(e.at)}]: ${probeStatusLabel(e.status)}\n  ${displayText(e)}';
  }

  /// Text for the "Copy Safe Diagnostic Result" button.
  String copyText() {
    final b = StringBuffer()
      ..writeln('OffRo MSG91 OTP probe (safe, redacted)')
      ..writeln('Overall: ${probeStatusLabel(overall)}')
      ..writeln(_block('Correct code', _accepted))
      ..write(_block('Wrong code / not verified', _rejected));
    return scrubDiagnostic(b.toString());
  }
}
