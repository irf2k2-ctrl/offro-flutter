// lib/core/services/payment_outcome.dart
// Pure Dart (no Flutter): classifies a Razorpay failure event into one of four outcomes. See error_mapper.dart for the texts.

import 'dart:convert';

// A Razorpay failure event for a user pressing back/cancel carries the literal text "undefined" (or JSON whose description is
// "undefined"); these helpers turn any such event into cancelled / failed / pending / network. Nothing here ever marks a payment as
// paid: success only comes from the SDK success event followed by the server's signature verification.

enum PaymentOutcome { cancelled, failed, pending, network }

/// razorpay_flutter error codes: NETWORK_ERROR 0, INVALID_OPTIONS 1, PAYMENT_CANCELLED 2, TLS_ERROR 3, UNKNOWN_ERROR 4.
const int _kRzpNetwork = 0, _kRzpCancelled = 2, _kRzpTls = 3;

/// The human text inside a Razorpay failure message: unwraps the JSON form ({"error":{"description":...}}) and drops the junk values
/// the SDK sends for "no message" ("undefined", "null", "{}"). Returns "" when there is nothing usable.
String razorpayMessageText(String? message) {
  var m = (message ?? '').trim();
  if (m.isEmpty) return '';
  if (m.startsWith('{')) {
    try {
      final j = jsonDecode(m);
      final err = j is Map && j['error'] is Map ? j['error'] as Map : (j is Map ? j : const {});
      m = '${err['description'] ?? err['reason'] ?? err['message'] ?? ''}'.trim();
    } catch (_) {
      return '';
    }
  }
  final low = m.toLowerCase();
  if (low == 'undefined' || low == 'null' || low == 'none' || low == 'nan' || low == '{}' || low == '[]') return '';
  return m;
}

PaymentOutcome classifyPaymentFailure({int? code, String? message, bool afterPayment = false}) {
  final text = razorpayMessageText(message).toLowerCase();
  bool has(List<String> w) => w.any(text.contains);
  if (afterPayment) {
    // Raised while confirming a payment the gateway already accepted: it is "not confirmed yet", never a failure.
    return PaymentOutcome.pending;
  }
  if (code == _kRzpCancelled || has(['cancel', 'dismiss', 'back button', 'closed by user'])) return PaymentOutcome.cancelled;
  if (code == _kRzpTls || has(['network', 'internet', 'connect', 'timeout', 'timed out', 'unreachable', 'offline'])) {
    return PaymentOutcome.network;
  }
  if (has(['pending', 'not confirmed', 'processing', 'awaiting'])) return PaymentOutcome.pending;
  // The Android SDK reports a plain dismissal as code 0 with no message: nothing was paid, so it is a cancellation.
  if (code == _kRzpNetwork && text.isEmpty) return PaymentOutcome.cancelled;
  return PaymentOutcome.failed;
}

