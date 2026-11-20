// lib/otp_test/msg91_country_test_screen.dart
// PHASE B - TEMPORARY, STAGING-ONLY MSG91 COUNTRY TEST TOOL. Never merge, never ship.
//
// A stand-alone screen (own entry point, own MaterialApp) used to learn what MSG91 really does for each of the
// five countries: which channel the FIRST send uses, what a plain resend uses, and whether an explicit SMS
// resend works. It does not touch the real login, the backend, the master OTP or any stored data.
//
// Safety rules kept here:
//   * It talks only to MSG91 through the same SDK the real login uses. It never calls our backend.
//   * The master OTP is NOT honoured: a code is only ever checked by MSG91.
//   * Phone numbers and request ids are masked before they are shown or copied. The OTP is never stored,
//     logged or copied, and the OTP box is cleared after every verify.
//   * Nothing is saved to disk. Closing the app clears the log.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';

import 'msg91_test_logic.dart';

// The mobile widget the real app uses (both values are public client identifiers by design). They can be
// overridden at build time with --dart-define=MSG91_WIDGET_ID=... --dart-define=MSG91_TOKEN_AUTH=...
const String _kWidgetId = String.fromEnvironment('MSG91_WIDGET_ID', defaultValue: '36656f6a786e313430373338');
const String _kTokenAuth = String.fromEnvironment('MSG91_TOKEN_AUTH', defaultValue: '516819TuGI7seX6a06f51cP1');

class Msg91TestApp extends StatelessWidget {
  const Msg91TestApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MSG91 country test',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF1B5E3F)),
        home: const Msg91CountryTestScreen(),
      );
}

/// Shown instead of the tool when it is not allowed to run (no flag, not a debug build, or not the staging host).
class BlockedTestApp extends StatelessWidget {
  const BlockedTestApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'MSG91 test tool disabled.\n\nIt runs only with --dart-define=OTP_COUNTRY_TEST=true, '
                  'in a debug build, with API_BASE_URL set to the staging host.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
}

class Msg91CountryTestScreen extends StatefulWidget {
  const Msg91CountryTestScreen({super.key});
  @override
  State<Msg91CountryTestScreen> createState() => _Msg91CountryTestState();
}

class _Msg91CountryTestState extends State<Msg91CountryTestScreen> {
  TestCountry _country = kTestCountries.first;
  final _phoneC = TextEditingController();
  final _otpC = TextEditingController();
  final List<TestEntry> _log = [];

  String? _reqId; // the id MSG91 returned for the current session
  TestCountry? _sessionCountry;
  String _sessionMaskedPhone = '';
  bool _busy = false;
  String _banner = '';
  bool _bannerOk = false;
  RetryChoice _retry = RetryChoice.configured;

  @override
  void initState() {
    super.initState();
    OTPWidget.initializeWidget(_kWidgetId, _kTokenAuth);
  }

  @override
  void dispose() {
    _phoneC.dispose();
    _otpC.dispose();
    super.dispose();
  }

  void _say(String m, {bool ok = false}) => setState(() {
        _banner = m;
        _bannerOk = ok;
      });

  // The SDK's return type is not declared in its docs, so answers are handled as dynamic, exactly as the real login does.
  bool _isOk(dynamic r) => r != null && r['type'] == 'success';

  void _record(StepKind step, String requested, bool ok, String detail) {
    _log.insert(
      0,
      TestEntry(
        at: DateTime.now(),
        country: _sessionCountry ?? _country,
        step: step,
        requested: requested,
        apiOk: ok,
        detail: detail,
        maskedPhone: _sessionMaskedPhone,
        maskedReqId: _reqId == null ? '' : maskReqId(_reqId!),
      ),
    );
  }

  Future<void> _send() async {
    final err = sanityError(_country, _phoneC.text);
    if (err != null) {
      _say(err);
      return;
    }
    setState(() => _busy = true);
    _sessionCountry = _country;
    _sessionMaskedPhone = maskPhone(_country, _phoneC.text);
    try {
      final dynamic resp = await OTPWidget.sendOTP({'identifier': identifierFor(_country, _phoneC.text)});
      final ok = _isOk(resp);
      final msg = resp == null ? 'no response' : scrubMessage(resp['message']?.toString() ?? '');
      if (ok) _reqId = resp!['message']?.toString();
      _record(StepKind.send, 'no channel sent', ok, ok ? 'request id ${maskReqId(_reqId ?? '')}' : msg);
      _say(ok ? 'MSG91 accepted the send. Now look at the phone: SMS or WhatsApp?' : 'MSG91 rejected the send: $msg', ok: ok);
    } catch (e) {
      _record(StepKind.send, 'no channel sent', false, 'exception ${e.runtimeType}');
      _say('Send failed (${e.runtimeType}).');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resend(StepKind step, RetryChoice choice) async {
    final id = _reqId;
    if (id == null || id.isEmpty) {
      _say('Send an OTP first.');
      return;
    }
    setState(() => _busy = true);
    final code = retryCode(choice);
    // The SDK documents retryChannel as an int (11 = SMS, 12 = WhatsApp) and says to omit it for the widget's default.
    final body = <String, Object>{'reqId': id};
    if (code != null) body['retryChannel'] = code;
    final requested = code == null ? 'no channel sent' : 'retryChannel=$code';
    try {
      final dynamic resp = await OTPWidget.retryOTP(body);
      final ok = _isOk(resp);
      final msg = resp == null ? 'no response' : scrubMessage(resp['message']?.toString() ?? '');
      _record(step, requested, ok, ok ? 'accepted' : msg);
      _say(ok ? 'MSG91 accepted the resend. Look at the phone: SMS or WhatsApp?' : 'MSG91 rejected the resend: $msg', ok: ok);
    } catch (e) {
      _record(step, requested, false, 'exception ${e.runtimeType}');
      _say('Resend failed (${e.runtimeType}).');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _verify() async {
    final id = _reqId;
    final otp = _otpC.text.trim();
    if (id == null || id.isEmpty) {
      _say('Send an OTP first.');
      return;
    }
    if (otp.length < 4) {
      _say('Enter the code you received.');
      return;
    }
    setState(() => _busy = true);
    try {
      final dynamic resp = await OTPWidget.verifyOTP({'reqId': id, 'otp': otp});
      final ok = _isOk(resp);
      final msg = resp == null ? 'no response' : scrubMessage(resp['message']?.toString() ?? '');
      _record(StepKind.verify, 'code typed by tester', ok, ok ? 'verified' : msg);
      _say(ok ? 'Verified by MSG91.' : 'MSG91 did not verify the code: $msg', ok: ok);
    } catch (e) {
      _record(StepKind.verify, 'code typed by tester', false, 'exception ${e.runtimeType}');
      _say('Verify failed (${e.runtimeType}).');
    }
    _otpC.clear(); // the code is never kept
    if (mounted) setState(() => _busy = false);
  }

  void _newSession() {
    setState(() {
      _reqId = null;
      _sessionCountry = null;
      _sessionMaskedPhone = '';
      _otpC.clear();
      _banner = '';
    });
  }

  void _observe(TestEntry e, Observed o) {
    setState(() {
      e.observed = o;
      e.secondsToArrive =
          (o == Observed.sms || o == Observed.whatsapp) ? DateTime.now().difference(e.at).inSeconds : null;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: buildReport(_log.reversed.toList())));
    _say('Masked report copied.', ok: true);
  }

  @override
  Widget build(BuildContext context) {
    final waCountry = _country.expectedChannel == 'WhatsApp';
    final hasSession = _reqId != null && _reqId!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('MSG91 country test (staging)')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'Temporary Phase B test tool. It sends REAL OTPs to the number you enter. It is not the app login. '
                'The master OTP does not work here. Never ship or merge this.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<TestCountry>(
              value: _country,
              decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
              items: [for (final c in kTestCountries) DropdownMenuItem(value: c, child: Text(c.label))],
              onChanged: _busy ? null : (c) => setState(() => _country = c ?? _country),
            ),
            const SizedBox(height: 6),
            Text('Expected first channel for ${_country.name}: ${_country.expectedChannel}',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneC,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(14)],
              decoration: InputDecoration(
                labelText: 'Mobile number (without country code)',
                prefixText: '${_country.flag} ${_country.dialLabel}  ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: _busy ? null : _send, child: const Text('1. Send OTP')),
            const SizedBox(height: 14),
            if (_banner.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _bannerOk ? const Color(0xFFE3F5EA) : const Color(0xFFFDE8E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_banner, style: const TextStyle(fontSize: 13)),
              ),
            if (hasSession) ...[
              const SizedBox(height: 14),
              Text('Session: ${_sessionCountry?.name ?? ''} $_sessionMaskedPhone  request ${maskReqId(_reqId!)}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 10),
              TextField(
                controller: _otpC,
                keyboardType: TextInputType.number,
                obscureText: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                decoration: const InputDecoration(labelText: 'Code you received', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: _busy ? null : _verify, child: const Text('2. Verify code')),
              const SizedBox(height: 16),
              const Text('Resend', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<RetryChoice>(
                value: _retry,
                decoration: const InputDecoration(labelText: 'Resend channel', border: OutlineInputBorder()),
                items: [for (final r in RetryChoice.values) DropdownMenuItem(value: r, child: Text(retryChoiceLabel(r)))],
                onChanged: _busy ? null : (r) => setState(() => _retry = r ?? _retry),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _resend(StepKind.resend, _retry),
                child: const Text('3. Resend with the channel above'),
              ),
              if (waCountry) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _resend(StepKind.resendSms, RetryChoice.sms),
                  child: const Text('Send code by SMS instead (fallback)'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(onPressed: _busy ? null : _newSession, child: const Text('Start a new test')),
            ],
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(child: Text('Results', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              TextButton(onPressed: _log.isEmpty ? null : _copy, child: const Text('Copy masked report')),
            ]),
            const Text(
              'MSG91 "accepted" only means the request was taken. After each send or resend, record on this screen '
              'what actually arrived on the phone.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (_log.isEmpty) const Text('No attempts yet.', style: TextStyle(fontSize: 12)),
            for (final e in _log) _entryCard(e),
          ],
        ),
      ),
    );
  }

  Widget _entryCard(TestEntry e) {
    final canObserve = e.step == StepKind.send || e.step == StepKind.resend || e.step == StepKind.resendSms;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${e.country.flag} ${e.country.name} - ${stepLabel(e.step)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${e.maskedPhone}   asked: ${e.requested}', style: const TextStyle(fontSize: 12)),
          Text('MSG91 ${e.apiOk ? 'accepted' : 'rejected'}: ${e.detail}', style: const TextStyle(fontSize: 12)),
          if (canObserve && e.apiOk) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              for (final o in [Observed.sms, Observed.whatsapp, Observed.nothing])
                ChoiceChip(
                  label: Text(observedLabel(o), style: const TextStyle(fontSize: 11)),
                  selected: e.observed == o,
                  onSelected: (_) => _observe(e, o),
                ),
            ]),
            if (e.secondsToArrive != null)
              Text('Arrived after about ${e.secondsToArrive}s', style: const TextStyle(fontSize: 11)),
          ],
        ]),
      ),
    );
  }
}
