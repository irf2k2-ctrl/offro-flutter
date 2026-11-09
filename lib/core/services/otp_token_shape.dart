// lib/core/services/otp_token_shape.dart
// STAGING-ONLY DIAGNOSTIC (branch staging/msg91-token-field-probe - never merge, never ship).
// Pure Dart (no Flutter imports) so it is unit-testable anywhere.
//
// Describes the SHAPE of an MSG91 verifyOTP response so we can learn which key holds the
// access token, with an allowlist-only output:
//  * key names are printed ONLY if they are in [_knownKeys]; any other key is printed as
//    `<unknown-key#N>` (its position in sorted order), never by name;
//  * `type` is printed only if it is in [_knownTypes], else `<other>`;
//  * strings are never printed: only a size bucket, and for a JWT-shaped string the
//    allowlisted `alg`/`typ` header values and the allowlisted claim names;
//  * anything else (numbers, bools, lists, nested values) is a Dart type name only;
//  * any unexpected error yields the fixed text `probe-error`.

import 'dart:convert';

/// Staging backend host that may activate the probe (exact match, nothing else).
const String kProbeStagingHost = 'offro-backend-staging-d375.up.railway.app';

/// True only for https://offro-backend-staging-d375.up.railway.app[/...] with no
/// user-info, no custom port, and the EXACT host (no sub-domain, no trailing dot,
/// no look-alike, no "staging" merely appearing in the path or user-info).
bool isStagingProbeUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null) return false;
  return u.scheme == 'https' &&
      u.host == kProbeStagingHost &&
      u.userInfo.isEmpty &&
      (!u.hasPort || u.port == 443);
}

const Set<String> _knownKeys = {
  'type', 'message', 'data', 'token', 'access_token', 'accessToken', 'access-token',
  'jwt', 'status', 'statusCode', 'status_code', 'code', 'success', 'error',
};
const Set<String> _knownTypes = {'success', 'error', 'fail', 'failure', 'warning', 'info'};
const Set<String> _knownAlgs = {
  'RS256', 'RS384', 'RS512', 'HS256', 'HS384', 'HS512', 'ES256', 'ES384', 'ES512',
  'PS256', 'PS384', 'PS512', 'none',
};
const Set<String> _knownTyps = {'JWT'};
const Set<String> _knownClaims = {
  'iss', 'sub', 'aud', 'exp', 'nbf', 'iat', 'jti', 'mobile', 'phone', 'identifier',
  'email', 'company', 'user', 'reqId', 'requestId', 'widgetId',
};

String describeVerifyResponse(dynamic resp) {
  try {
    if (resp == null) return 'response=null';
    if (resp is! Map) return 'response=${_typeName(resp)}';
    return _describeMap(resp, 0);
  } catch (_) {
    return 'probe-error';
  }
}

String _typeName(dynamic v) {
  if (v is String) return 'String';
  if (v is Map) return 'Map';
  if (v is List) return 'List';
  if (v is bool) return 'bool';
  if (v is int) return 'int';
  if (v is double) return 'double';
  return 'other';
}

String _describeMap(Map m, int depth) {
  final entries = m.entries.toList()
    ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
  var unknown = 0;
  final out = <String>[];
  for (final e in entries) {
    final k = e.key is String ? e.key as String : null;
    final known = k != null && _knownKeys.contains(k);
    final label = known ? k : '<unknown-key#${++unknown}>';
    out.add('$label: ${_describeValue(known ? k : null, e.value, depth)}');
  }
  return out.isEmpty ? '(empty map)' : out.join(' | ');
}

String _describeValue(String? knownKey, dynamic v, int depth) {
  if (v == null) return 'null';
  if (v is String) {
    if (knownKey == 'type') return _knownTypes.contains(v) ? 'String "$v"' : 'String <other>';
    return _stringShape(v);
  }
  if (v is Map) return depth >= 1 ? 'Map(${v.length} keys)' : 'Map{${_describeMap(v, depth + 1)}}';
  if (v is List) return 'List';
  return _typeName(v);
}

String _bucket(int n) => n < 40 ? 'len<40' : (n < 200 ? 'len40-199' : 'len200+');

String _stringShape(String s) {
  final parts = s.split('.');
  final b64 = RegExp(r'^[A-Za-z0-9_-]+$');
  if (parts.length != 3 || !parts.every((p) => p.isNotEmpty && b64.hasMatch(p))) {
    return 'String ${_bucket(s.length)} not-jwt';
  }
  final header = _decode(parts[0]);
  final payload = _decode(parts[1]);
  final alg = header is Map && header['alg'] is String && _knownAlgs.contains(header['alg']) ? header['alg'] : '?';
  final typ = header is Map && header['typ'] is String && _knownTyps.contains(header['typ']) ? header['typ'] : '?';
  final claimKeys = payload is Map ? payload.keys.whereType<String>().toList() : <String>[];
  final known = claimKeys.where(_knownClaims.contains).toList()..sort();
  final other = (payload is Map ? payload.length : 0) - known.length;
  return 'String len=${s.length} jwt-like(parts=3, alg=$alg, typ=$typ, '
      'known-claims=[${known.join(",")}], other-claims=$other)';
}

dynamic _decode(String seg) {
  try {
    var t = seg.replaceAll('-', '+').replaceAll('_', '/');
    while (t.length % 4 != 0) {
      t += '=';
    }
    return json.decode(utf8.decode(base64.decode(t)));
  } catch (_) {
    return null;
  }
}

/// Pure activation rule for the probe UI: ALL of the explicit flag, a debug build and the
/// exact Staging host must hold. (The app wires this to the real build constants.)
bool probeActive({required bool flag, required bool debug, required String baseUrl}) =>
    flag && debug && isStagingProbeUrl(baseUrl);
