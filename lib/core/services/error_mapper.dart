// lib/core/services/error_mapper.dart
// OFFRO — Shared customer-facing error classifier (Round 9).
//
// Generalizes the _friendlyError() pattern already established and proven
// in lib/screens/influencer/my_influencer_profile.dart into a single
// shared utility every screen can use, instead of each screen reinventing
// (or half-reinventing) its own cleanup. Never surfaces raw exceptions,
// stack traces, certificate/TLS details, hostnames, URLs, file paths, or
// other technical internals to the customer — but PRESERVES a clean,
// short, human-readable backend business/validation message exactly as
// written (e.g. "Store subscription is required before adding a deal.").
//
// Classification order (matches the finalized Round 9 requirements):
//   A) Network / connection        -> connectivity message
//   B) Timeout                     -> "taking too long" message
//   C) Invalid/non-JSON/server     -> "temporarily unavailable" message
//   D) Auth / session              -> "session expired" message
//   E) Clean business message      -> preserved verbatim
//   F) Empty / unknown / technical -> generic fallback
//
// Developer debugging is the CALLER's responsibility: this function only
// maps the string shown to the customer. Callers keep their own
// debugPrint('[OffrO] ...: $e') (or equivalent) alongside calling this —
// see call sites for the established pattern. Nothing here suppresses or
// removes any existing debug logging.

/// Maps any caught error/exception to a short, friendly, customer-safe
/// message. Never returns raw technical text (exception class names,
/// stack traces, certificate details, URLs, hostnames, file paths,
/// database/server internals). A clean, short, human-readable backend
/// business/validation message (e.g. a subscription or discount-code
/// requirement) is preserved as-is rather than replaced.
String friendlyError(
  Object e, {
  String fallback = "Something went wrong. Please try again.",
}) {
  final raw = e.toString();

  // ── A) Network / connection ──────────────────────────────────────────
  if (_containsAny(raw, const [
    'SocketException',
    'HandshakeException',
    'CERTIFICATE',
    'Certificate',
    'Handshake',
    'Connection refused',
    'Connection closed',
    'Connection reset',
    'Failed host lookup',
    'Network is unreachable',
    'No address associated with hostname',
    'ClientException', // package:http's own network-failure wrapper
  ])) {
    return "We couldn't connect to OffrO right now. Please check your internet connection and try again.";
  }

  // ── B) Timeout ────────────────────────────────────────────────────────
  if (_containsAny(raw, const ['TimeoutException', 'timed out', 'Timeout'])) {
    return "OffrO is taking too long to respond. Please try again in a moment.";
  }

  // ── C) Invalid / non-JSON / server response ──────────────────────────
  if (_containsAny(raw, const [
    'FormatException',
    'Internal Server Error',
    'Unexpected character',
    'Invalid server response',
    '<html',
    '<!DOCTYPE',
    'Bad Gateway',
    'Gateway Timeout',
    'Service Unavailable',
  ])) {
    return "OffrO is temporarily unavailable. Please try again in a moment.";
  }

  // ── D) Auth / session ─────────────────────────────────────────────────
  if (_looksLikeAuthError(raw)) {
    return "Your session has expired. Please log in again.";
  }

  // ── E) Clean business message — preserve verbatim ────────────────────
  final cleaned = raw.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  if (_looksLikeCleanBusinessMessage(cleaned)) {
    return cleaned;
  }

  // ── F) Empty / unknown / still-technical → generic fallback ─────────
  return fallback;
}

bool _containsAny(String haystack, List<String> needles) {
  final lower = haystack.toLowerCase();
  for (final n in needles) {
    if (lower.contains(n.toLowerCase())) return true;
  }
  return false;
}

/// Auth/session detection. Deliberately conservative: an ordinary backend
/// business message that happens to contain an unrelated number must never
/// be misclassified as a 401/403. A real "Error 401"/"HTTP 403" style
/// message from _get()/_post() is short; a genuine business sentence
/// mentioning "401" or "403" incidentally is not, so length is used as a
/// second guard alongside the status-code match.
bool _looksLikeAuthError(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('unauthorized') ||
      lower.contains('forbidden') ||
      lower.contains('session expired') ||
      lower.contains('session has expired')) {
    return true;
  }
  final hasStatusCode = RegExp(r'\b(401|403)\b').hasMatch(raw);
  if (!hasStatusCode) return false;
  return raw.trim().length <= 40;
}

/// Heuristics for "this is a clean, short, human-readable backend
/// business/validation message" vs. "this is technical leakage that
/// slipped past a specific classifier above and must not reach the
/// customer verbatim". Matches the Round 9 requirement's explicit list of
/// technical markers to reject.
bool _looksLikeCleanBusinessMessage(String cleaned) {
  if (cleaned.isEmpty) return false;
  if (cleaned.length > 200) return false; // extremely long technical text
  final lower = cleaned.toLowerCase();
  const technicalMarkers = [
    'exception',
    'stacktrace',
    'stack trace',
    'traceback',
    'at package:',
    'dart:',
    'file:///',
    'http://',
    'https://',
    'certificate',
    'socketexception',
    'handshakeexception',
    'timeoutexception',
    'formatexception',
    'sqlexception',
    'sql error',
    'mongodb',
    'mongoerror',
    'pymongo',
    'psycopg',
    'starlette',
    'fastapi',
    'errno',
    'os error',
    '.dart:',
    'null check operator',
    "type '",
    'is not a subtype',
  ];
  for (final marker in technicalMarkers) {
    if (lower.contains(marker)) return false;
  }
  return true;
}

// ── Razorpay-specific classifier ────────────────────────────────────────
//
// Razorpay's PaymentFailureResponse.message is third-party SDK/gateway
// text: usually short and human-readable ("Payment Cancelled by user",
// "Your payment could not be processed"), but occasionally a raw gateway
// code or technical dump. Applies the same "preserve if clean, replace if
// technical" rule as friendlyError's business-message case, plus its own
// friendly fallback when the message is missing entirely (Razorpay does
// not always supply one).

/// Maps a Razorpay PaymentFailureResponse.message to a customer-safe
/// string. Never exposes gateway codes, SDK internals, or raw bank/network
/// technical output.
String friendlyRazorpayError(String? message) {
  final m = (message ?? '').trim();
  if (m.isEmpty) {
    return "Payment could not be completed. Please try again.";
  }
  if (_looksLikeCleanBusinessMessage(m)) {
    return m;
  }
  return "We couldn't complete your payment. Please try again.";
}
