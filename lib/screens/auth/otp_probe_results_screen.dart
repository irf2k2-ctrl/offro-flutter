// lib/screens/auth/otp_probe_results_screen.dart
// STAGING-ONLY DIAGNOSTIC (branch staging/msg91-probe-latest-ui - never merge, never ship).
// Shows the redacted MSG91 verify-response shape captured by OtpProbeStore. Shows only what the
// allowlist redaction produced; never a token, phone, OTP, message text or raw response.
// Nothing here is persisted or sent anywhere.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/design/design.dart' show OffroColors, OffroText;
import '../../core/services/otp_probe_store.dart';
import '../../core/services/otp_token_shape.dart';

const bool _kOtpTokenProbe = bool.fromEnvironment('OTP_TOKEN_PROBE');

/// True only with --dart-define=OTP_TOKEN_PROBE=true, a debug build and the exact Staging host.
bool get otpProbeEnabled =>
    probeActive(flag: _kOtpTokenProbe, debug: kDebugMode, baseUrl: kBaseUrl);

/// Small "Diagnostic Results" link; renders nothing unless the probe is enabled.
class OtpProbeLink extends StatelessWidget {
  const OtpProbeLink({super.key, this.enabled});
  final bool? enabled; // test override; defaults to otpProbeEnabled
  @override
  Widget build(BuildContext context) {
    if (!(enabled ?? otpProbeEnabled)) return const SizedBox.shrink();
    return TextButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OtpProbeResultsScreen())),
      child: Text('Diagnostic Results',
        style: OffroText.caption.copyWith(
          fontSize: 11, fontWeight: FontWeight.w700, color: OffroColors.primary,
          decoration: TextDecoration.underline)),
    );
  }
}

class OtpProbeResultsScreen extends StatefulWidget {
  const OtpProbeResultsScreen({super.key, this.store});
  final OtpProbeStore? store; // tests pass their own
  @override
  State<OtpProbeResultsScreen> createState() => _OtpProbeResultsScreenState();
}

class _OtpProbeResultsScreenState extends State<OtpProbeResultsScreen> {
  OtpProbeStore get _s => widget.store ?? OtpProbeStore.instance;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _s.copyText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Safe diagnostic result copied')));
  }

  Widget _card(String title, ProbeEntry? e) {
    final status = e?.status ?? ProbeStatus.none;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14000000))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 4),
        Text(probeStatusLabel(status),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: status == ProbeStatus.failed ? Colors.red.shade700
                 : status == ProbeStatus.completed ? Colors.green.shade700 : Colors.black54)),
        if (e != null) ...[
          const SizedBox(height: 8),
          Text(_s.displayText(e), style: const TextStyle(fontSize: 12, height: 1.4, fontFamily: 'monospace')),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overall = _s.overall;
    return Scaffold(
      backgroundColor: OffroColors.background,
      appBar: AppBar(title: const Text('Diagnostic Results'), backgroundColor: Colors.white, foregroundColor: OffroColors.primary, elevation: 0),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(probeStatusLabel(overall), key: const Key('probe-overall-status'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Temporary Staging diagnostic. Redacted shape only: no OTP, phone, token or raw response is shown, stored or sent.',
          style: TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 16),
        _card('Correct code', _s.accepted),
        _card('Wrong code / not verified', _s.rejected),
        const SizedBox(height: 4),
        ElevatedButton(
          onPressed: overall == ProbeStatus.none ? null : _copy,
          child: const Text('Copy Safe Diagnostic Result'),
        ),
        TextButton(
          onPressed: overall == ProbeStatus.none ? null : () => setState(_s.clear),
          child: const Text('Clear results'),
        ),
      ]),
    );
  }
}
