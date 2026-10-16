// ─────────────────────────────────────────────────────────────────────────
// OffrO product links — https://offro.app/p/<product_id>
//
// Receives the link when the app is opened from it (Android App Links / iOS
// Universal Links, set up by the manifest / entitlements + the files served at
// offro.app/.well-known) and hands the product to the customer Home screen,
// which opens Product Details. Works for a cold start (link waits until Home
// is on screen) and when the app is already running.
//
// Only product links on the offro.app host are accepted; anything else is
// ignored. No analytics are touched here: Product Details fires its normal
// "view" event when it opens, exactly as for any other entry point.
// ─────────────────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:app_links/app_links.dart';

import 'api_service.dart';

typedef ProductLinkHandler = void Function(Map<String, dynamic> product);

class DeepLinkService {
  DeepLinkService._();

  static const Set<String> _hosts = {'offro.app', 'www.offro.app'};
  static const Duration _maxAge = Duration(minutes: 5);

  static StreamSubscription<Uri>? _sub;
  static bool _started = false;
  static ProductLinkHandler? _handler;
  static String? _pendingId;
  static DateTime? _pendingAt;
  static String? _lastId;
  static DateTime? _lastAt;

  /// Product id from an offro.app/p/<id> link, or null for any other URI.
  static String? productIdFrom(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    if (!_hosts.contains(uri.host.toLowerCase())) return null;
    final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (seg.length != 2 || seg[0] != 'p') return null;
    final id = seg[1].trim();
    return RegExp(r'^[A-Za-z0-9_-]{6,64}$').hasMatch(id) ? id : null;
  }

  /// Start listening. Safe to call more than once; never throws.
  static void start() {
    if (_started) return;
    _started = true;
    try {
      final links = AppLinks();
      links.getInitialLink().then(_onUri).catchError((_) {});
      _sub = links.uriLinkStream.listen(_onUri, onError: (_) {});
    } catch (_) {
      // Link handling is optional — the app works without it.
    }
  }

  /// A customer Home screen is on screen and can open a product. Delivers a
  /// waiting link, if any.
  static void attach(ProductLinkHandler handler) {
    _handler = handler;
    _deliver();
  }

  /// The Home screen went away.
  static void detach(ProductLinkHandler handler) {
    if (_handler == handler) _handler = null;
  }

  static void _onUri(Uri? uri) {
    final id = productIdFrom(uri);
    if (id == null) return;
    final now = DateTime.now();
    // The same link can be reported twice on a cold start (initial + stream).
    if (_lastId == id && _lastAt != null && now.difference(_lastAt!) < const Duration(seconds: 3)) return;
    _lastId = id;
    _lastAt = now;
    _pendingId = id;
    _pendingAt = now;
    _deliver();
  }

  static Future<void> _deliver() async {
    final handler = _handler;
    final id = _pendingId;
    final at = _pendingAt;
    if (handler == null || id == null || at == null) return;
    _pendingId = null;
    _pendingAt = null;
    if (DateTime.now().difference(at) > _maxAge) return; // stale: do not surprise the user later
    try {
      final product = await Api.getPublicProduct(id);
      if (product == null) return; // expired / removed / offline: stay where we are
      if (_handler != handler) return; // Home went away meanwhile
      handler(product);
    } catch (_) {}
  }
}
