import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ─────────────────────── SPLIT IMPORTS ───────────────────────
import 'core/constants/app_constants.dart';
import 'core/services/api_service.dart';
import 'core/services/prefs_service.dart';
import 'core/services/fcm_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/loading/location_loading_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'core/widgets/brand_logo.dart';
import 'screens/auth/login_screen.dart';
import 'screens/merchant/merchant_screens.dart';
import 'screens/favorites/favorites_page.dart';
import 'screens/detail/detail_page.dart';
import 'screens/store/store_detail_page.dart';
import 'screens/qr/qr_page.dart';
import 'screens/wallet/wallet_page.dart';
import 'screens/payment/payment_success_screen.dart';
import 'core/widgets/store_cards.dart';

PageRoute _route(Widget w) => MaterialPageRoute(builder: (_) => w);


// ─────────────────────── CONFIG ───────────────────────
const kBaseUrl = "https://offro-backend-production.up.railway.app";
const kRazorpayKey = "rzp_live_SdiI6kcuZzZjsl";

// ─────────────────────── COLORS ───────────────────────
const kPrimary  = Color(0xFF3E5F55);
const kLight    = Color(0xFFCDEBD6);
const kAccent   = Color(0xFFA9CDBA);
const kBeige    = Color(0xFFE7D7C8);
const kBg       = Color(0xFFFDFBF6);
const kText     = Color(0xFF2c3e35);
const kMuted    = Color(0xFF6b8c7e);
const kBorder   = Color(0xFFd4e8de);



// ─────────────────────── FCM (see core/services/fcm_service.dart) ───────────────────────
// ─────────────────────── API ───────────────────────

// ─────────────────────── NOTIFICATION NOTIFIER ───────────────────────
/// Global ValueNotifier — FCM handlers call .value++ to update badge in real time
final _unreadNotifier = ValueNotifier<int>(0);

// ─────────────────────── PREFS ───────────────────────

// ─────────────────────── LOCATION ───────────────────────
// Haversine distance in km between two lat/lng points
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2-lat1)*pi/180; final dLon = (lon2-lon1)*pi/180;
  final a = sin(dLat/2)*sin(dLat/2)+cos(lat1*pi/180)*cos(lat2*pi/180)*sin(dLon/2)*sin(dLon/2);
  return r*2*atan2(sqrt(a),sqrt(1-a));
}

/// Detect city from a pre-fetched GPS position.
/// Tries: (1) Haversine match against /cities if they have lat/lng,
///        (2) geocoder locality matched against city name list,
///        (3) raw geocoder locality,
///        (4) "Ballari" hardcoded fallback.
Future<String> detectCityFromPosition(Position pos) async {
  try {
    List cityList = [];
    try { cityList = await Api.getCities().timeout(const Duration(seconds: 6)); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }

    // Build a quick lookup set of supported city names (lowercase)
    final cityNames = cityList
        .cast<Map>()
        .map((c) => c["name"]?.toString() ?? "")
        .where((n) => n.isNotEmpty)
        .toList();

    // ── Step 1: Haversine match (only if cities have lat/lng fields) ──
    String? haversineMatch;
    double bestDist = double.infinity;
    for (final c in cityList.cast<Map>()) {
      final lat  = (c["lat"] as num?)?.toDouble();
      final lng  = (c["lng"] as num?)?.toDouble();
      final name = c["name"]?.toString() ?? "";
      if (lat == null || lng == null || name.isEmpty) continue;
      final dist = _gpsHaversineKm(pos.latitude, pos.longitude, lat, lng);
      if (dist < bestDist) { bestDist = dist; haversineMatch = name; }
    }
    if (haversineMatch != null && bestDist < 80) {
      if (kDebugMode) debugPrint("[OFFRO] Haversine match: $haversineMatch (${bestDist.toStringAsFixed(1)} km)");
      return haversineMatch;
    }

    // ── Step 2: Geocoder + normalize against known city names ──
    final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude)
        .timeout(const Duration(seconds: 8));
    final rawLocality = marks.first.locality?.trim() ?? "";
    final rawSubAdmin = marks.first.subAdministrativeArea?.trim() ?? "";
    final rawAdmin    = marks.first.administrativeArea?.trim() ?? "";
    if (kDebugMode) debugPrint("[OFFRO] Geocoder → locality=$rawLocality subAdmin=$rawSubAdmin admin=$rawAdmin");

    // Try to match geocoder result against supported city names (case-insensitive)
    for (final candidate in [rawLocality, rawSubAdmin, rawAdmin]) {
      if (candidate.isEmpty) continue;
      // Exact match
      final exact = cityNames.firstWhere(
        (n) => n.toLowerCase() == candidate.toLowerCase(),
        orElse: () => "",
      );
      if (exact.isNotEmpty) {
        if (kDebugMode) debugPrint("[OFFRO] City matched by name: $exact");
        return exact;
      }
      // Partial match (geocoder sometimes returns sub-district names)
      final partial = cityNames.firstWhere(
        (n) => candidate.toLowerCase().contains(n.toLowerCase()) ||
               n.toLowerCase().contains(candidate.toLowerCase()),
        orElse: () => "",
      );
      if (partial.isNotEmpty) {
        if (kDebugMode) debugPrint("[OFFRO] City partial match: $partial from $candidate");
        return partial;
      }
    }

    // ── Step 3: Return raw geocoder result if no city list match ──
    final fallback = rawLocality.isNotEmpty ? rawLocality :
                     rawSubAdmin.isNotEmpty ? rawSubAdmin : "Ballari";
    if (kDebugMode) debugPrint("[OFFRO] No city list match — using geocoder raw: $fallback");
    return fallback;
  } catch (e) {
    if (kDebugMode) debugPrint("[OFFRO] detectCityFromPosition error: $e");
    return "Ballari";
  }
}

// Legacy wrapper (kept for any other call sites)
Future<String> detectCity() async {
  try {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return "Ballari";
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .timeout(const Duration(seconds: 10));
    return detectCityFromPosition(pos);
  } catch (_) { return "Ballari"; }
}

/// Haversine distance in km between two lat/lng points (uses dart:math)
double _gpsHaversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = pow(sin(dLat / 2), 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(a.clamp(0.0, 1.0)));
}


// ─────────────────────── MAIN ───────────────────────
// Background FCM handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) debugPrint('[FCM] Background message: \${message.notification?.title}');
  // Issue 2: Save notification to local history
  try {
    final title    = message.notification?.title ?? message.data['title'] ?? '';
    final body     = message.notification?.body  ?? message.data['body']  ?? '';
    final imageUrl = message.data['image_url'] ?? message.data['image'] ?? '';
    if (title.isNotEmpty) {
      await Prefs.saveNotification(title: title, body: body, imageUrl: imageUrl);
      await Prefs.incrementUnread(); // Update badge count persistently
    }
  } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp();

  // 2. Register background message handler (must be before runApp)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 3. Initialize flutter_local_notifications + create high-importance channel
  await initLocalNotifications();
  // Wire local notification tap → navigate to NotificationsPage
  onLocalNotifTap = (payload) {
    MyApp.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  };

  // 4. Configure FCM foreground presentation (iOS only — Android needs local notif)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );

  // 5. Request Android 13+ POST_NOTIFICATIONS permission early
  await FirebaseMessaging.instance.requestPermission(
    alert: true, badge: true, sound: true,
    announcement: false, carPlay: false, criticalAlert: false, provisional: false,
  );

  // 6. Handle notification that LAUNCHED the app (cold start / terminated state tap)
  final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMsg != null) {
    if (kDebugMode) debugPrint('[FCM] App launched from notification: \${initialMsg.notification?.title}');
    final _it = initialMsg.notification?.title ?? initialMsg.data['title'] ?? '';
    final _ib = initialMsg.notification?.body  ?? initialMsg.data['body']  ?? '';
    final _ii = initialMsg.data['image_url'] ?? initialMsg.data['image'] ?? '';
    if (_it.isNotEmpty) {
      await Prefs.saveNotification(title: _it, body: _ib, imageUrl: _ii);
      await Prefs.incrementUnread();
    }
    // Navigate to NotificationsPage after app fully loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MyApp.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationsPage()),
      );
    });
  }

  // 7. Foreground message listener — show local notification manually
  FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
    if (kDebugMode) debugPrint('[FCM] ▶ Foreground message received: \${msg.notification?.title} | \${msg.notification?.body}');
    if (kDebugMode) debugPrint('[FCM] Data payload: \${msg.data}');
    showLocalNotification(msg); // show banner while app is open
    // Save to notification history (must await inside async listener)
    final _t = msg.notification?.title ?? msg.data['title'] ?? '';
    final _b = msg.notification?.body  ?? msg.data['body']  ?? '';
    final _i = msg.data['image_url'] ?? msg.data['image'] ?? '';
    if (_t.isNotEmpty) {
      await Prefs.saveNotification(title:_t, body:_b, imageUrl:_i);
      await Prefs.incrementUnread(); // Prefs is static — safe to call anywhere
      _unreadNotifier.value++; // Update UI badge in real time
    }
  });

  // 8. Background-to-foreground tap listener (app was in background, user tapped)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) async {
    if (kDebugMode) debugPrint('[FCM] 🔔 User tapped notification (from background): \${msg.notification?.title}');
    if (kDebugMode) debugPrint('[FCM] Data: \${msg.data}');
    // Save to notification history (await to ensure SharedPreferences write completes)
    final _t = msg.notification?.title ?? msg.data['title'] ?? '';
    final _b = msg.notification?.body  ?? msg.data['body']  ?? '';
    final _i = msg.data['image_url'] ?? msg.data['image'] ?? '';
    if (_t.isNotEmpty) {
      await Prefs.saveNotification(title:_t, body:_b, imageUrl:_i);
      await Prefs.incrementUnread();
    }
    // Navigate to NotificationsPage when user taps notification from background
    MyApp.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  });

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

IconData _categoryIcon(String cat) {
  switch(cat.toLowerCase()) {
    case "all": return Icons.apps_rounded;
    case "grocery": return Icons.shopping_basket_rounded;
    case "restaurant": return Icons.restaurant_rounded;
    case "pharmacy": return Icons.local_pharmacy_rounded;
    case "electronics": return Icons.devices_rounded;
    case "clothing": return Icons.checkroom_rounded;
    case "bakery": return Icons.cake_rounded;
    case "salon": return Icons.content_cut_rounded;
    case "pet store": return Icons.pets_rounded;
    default: return Icons.store_rounded;
  }
}


// Helper: safely decode a base64 image string, return fallback on error
Widget _b64Img(String src, Widget fallback) {
  try {
    return Image.memory(base64Decode(src.split(",").last), fit: BoxFit.cover);
  } catch (_) {
    return fallback;
  }
}

/// Synthesises a minimal deals list from store list data so StoreDetailPage
/// can render the Offers section immediately before the full API call returns.
Map<String,dynamic> _enrichStoreForDetail(Map<String,dynamic> s) {
  // If full deals list already present, return as-is
  if (s['deals'] is List && (s['deals'] as List).isNotEmpty) return s;
  // Build a placeholder deal from deal_summary / offer string
  final offerStr = s['offer']?.toString() ?? '';
  if (offerStr.isNotEmpty && offerStr.toLowerCase() != 'null') {
    final discMatch = RegExp(r'(\d+)%').firstMatch(offerStr);
    final disc = discMatch?.group(1) ?? '0';
    s['deals'] = [
      {
        'title':       offerStr.contains(' — ') ? offerStr.split(' — ').last : offerStr,
        'description': '',
        'discount':    disc,
        'end_date':    '',
      }
    ];
  }
  return s;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // NavigatorKey lets us navigate from anywhere (callbacks, FCM tap handlers, etc.)
  // without depending on a captured BuildContext that may become stale.
  static final navigatorKey = GlobalKey<NavigatorState>();

  // Central navigation helpers — called from SplashScreen / Login / Onboarding callbacks.
  static void goHome({required String token, required String name,
      required String phone, required String userId, required String city}) {
    // TASK 2 FIX: clear stale cache + save mode so all sections reload correctly
    Api.clearCache();
    Prefs.saveMode('user');
    // Route through LocationLoadingScreen so home opens fully loaded
    navigatorKey.currentState?.pushAndRemoveUntil(
      _route(LocationLoadingScreen(
        token: token, name: name, phone: phone, userId: userId,
        // Pass saved city so it loads instantly without GPS wait
        forcedCity: city.isNotEmpty ? city : null,
        onReady: ({required String city, required List<Map<String,dynamic>> stores,
                   required double? lat, required double? lng}) =>
            goHomeWithData(token: token, name: name, phone: phone, userId: userId,
                city: city, stores: stores, lat: lat, lng: lng),
      )),
      (r) => false,
    );
  }

  static void goLogin() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      _route(LoginScreen(onSuccess: (tok, nm, ph, uid, role) {
        if (role == 'merchant') {
          // Merchant role selected → merchant loader → merchant home
          _goMerchantViaUnified(merchantToken: tok, phone: ph, name: nm);
        } else {
          // User role selected → GPS location loader → user home
          navigatorKey.currentState?.pushAndRemoveUntil(
            _route(LocationLoadingScreen(
              token: tok, name: nm, phone: ph, userId: uid,
              onReady: ({required String city, required List<Map<String,dynamic>> stores,
                         required double? lat, required double? lng}) =>
                  goHomeWithData(token: tok, name: nm, phone: ph, userId: uid,
                      city: city, stores: stores, lat: lat, lng: lng),
            )),
            (r) => false,
          );
        }
      })),
      (r) => false,
    );
  }

  /// Switch mode — called from SwitchModeSheet in user profile
  static void goSwitchMode(String token, String name, String phone, String userId, String role) {
    if (role == 'merchant') {
      _goMerchantViaUnified(phone: phone, name: name);
    } else {
      // TASK 2 FIX: get a fresh user token so getWallet and user APIs work correctly
      _goUserViaUnified(phone: phone, name: name, userId: userId);
    }
  }

  /// Switch to user mode — issues a fresh user session token, then routes home.
  static void _goUserViaUnified({required String phone, required String name, required String userId}) async {
    try {
      Api.clearCache();
      // Issue a fresh user session token
      final resp = await Api.loginUser(phone);
      final freshToken = resp['token']?.toString() ?? '';
      final freshId    = resp['user_id']?.toString() ?? userId;
      final freshName  = resp['name']?.toString() ?? name;
      if (freshToken.isNotEmpty) {
        await Prefs.save(freshToken, freshName, phone, 'user', userId: freshId);
        await Prefs.saveMode('user');
        goHome(token: freshToken, name: freshName, phone: phone, userId: freshId, city: '');
      } else {
        // Fallback — use existing token (may cause wallet 401 but banners still load)
        await Prefs.saveMode('user');
        goHome(token: '', name: name, phone: phone, userId: userId, city: '');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Switch] _goUserViaUnified error: $e');
      await Prefs.saveMode('user');
      goHome(token: '', name: name, phone: phone, userId: userId, city: '');
    }
  }

  /// Unified merchant flow: fresh login → merchant loader → merchant home.
  /// Called both from post-OTP flow and from Switch Mode.
  /// [merchantToken] — pass if we already have a valid merchant token (e.g. splash restore).
  /// [phone] — used to issue a fresh merchant token when switching from user mode.
  static void _goMerchantViaUnified({
    String? merchantToken,
    required String phone,
    required String name,
  }) async {
    try {
      String token = merchantToken ?? '';
      Map<String, dynamic>? merchantData;

      // If we already have a merchant token, try it first
      if (token.isNotEmpty) {
        merchantData = await Api.getMerchantMe(token);
      }

      // No valid token or it failed → issue a fresh token via unified account-login
      if (merchantData == null) {
        final loginResp = await Api.loginAccount(phone);
        token = loginResp['token']?.toString() ?? '';
        if (token.isEmpty) {
          if (kDebugMode) debugPrint('[Switch] loginAccount returned empty token for merchant switch');
          goLogin();
          return;
        }
        final mName   = loginResp['name']?.toString()        ?? name;
        final mId     = loginResp['merchant_id']?.toString() ?? loginResp['account_id']?.toString() ?? '';
        await Prefs.save(token, mName, phone, 'merchant', userId: mId);
        await Prefs.saveMerchantId(mId);
        await Prefs.saveMode('merchant');
        merchantData = await Api.getMerchantMe(token);
      }

      if (merchantData == null) {
        if (kDebugMode) debugPrint('[Switch] getMerchantMe returned null after fresh login');
        goLogin();
        return;
      }

      navigatorKey.currentState?.pushAndRemoveUntil(
        _route(MerchantLoadingScreen(
          token: token,
          merchant: merchantData,
          onReady: (tok, merch) {
            navigatorKey.currentState?.pushAndRemoveUntil(
              _route(MerchantHome(token: tok, merchant: merch)),
              (r) => false,
            );
          },
        )),
        (r) => false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Switch] _goMerchantViaUnified error: $e');
      // If merchant not registered, go to login so they can register
      goLogin();
    }
  }

  static void goHomeWithData({
    required String token, required String name, required String phone,
    required String userId,  required String city,
    required List<Map<String,dynamic>> stores,
    required double? lat,    required double? lng,
  }) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      _route(HomeScreen(
        token: token, name: name, phone: phone,
        savedCity: city, userId: userId,
        preloadedStores: stores,
        preloadedLat: lat, preloadedLng: lng,
      )),
      (r) => false,
    );
  }

  static void goOnboarding() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      _route(OnboardingScreen(onComplete: goLogin)),
      (r) => false,
    );
  }

  static void goMerchant({required String token, required Map merchant}) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      _route(MerchantHome(token: token, merchant: merchant)),
      (r) => false,
    );
  }

  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: navigatorKey,
    theme: ThemeData(
      primaryColor: kPrimary,
      colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
      useMaterial3: false,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: kText),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
    ),
    home: SplashScreen(
      onUser:       (token, name, phone, city, userId) => goHome(token: token, name: name, phone: phone, userId: userId, city: city),
      onMerchant:   (token, merchant) => goMerchant(token: token, merchant: merchant),
      onOnboarding: goOnboarding,
      onLogin:      goLogin,
    ),
  );
}


// ─────────────────────── SCALE ON TAP WIDGET ───────────────────────
class _ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _ScaleOnTap({required this.child, this.onTap});
  @override State<_ScaleOnTap> createState() => _ScaleOnTapState();
}
class _ScaleOnTapState extends State<_ScaleOnTap> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _scale;
  @override void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeInOut));
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) { _ac.reverse(); widget.onTap?.call(); },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ─────────────────────── NAV BTN (label on active only) ───────────────────────
class _NavBtn extends StatelessWidget {
  final IconData icon; final String label; final bool active;
  const _NavBtn({required this.icon,required this.label,required this.active});

  @override Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFCDEBD6) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: active ? kPrimary : const Color(0xFF9aada8), size: 22),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: active ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(label, style: const TextStyle(
                color: kPrimary, fontSize: 10, fontWeight: FontWeight.w800))),
            secondChild: const SizedBox(height: 14),
          ),
        ],
      ),
    );
  }
}

// ── Profile nav button with avatar ──
class _ProfileNavBtn extends StatelessWidget {
  final String? profilePhoto;
  final String name;
  final bool active;
  const _ProfileNavBtn({required this.profilePhoto, required this.name, required this.active});

  @override Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFFCDEBD6) : Colors.transparent,
            ),
            child: CircleAvatar(
              radius: 11,
              backgroundColor: kAccent,
              backgroundImage: (profilePhoto != null && profilePhoto!.startsWith("data:image"))
                ? MemoryImage(base64Decode(profilePhoto!.split(",").last)) as ImageProvider
                : (profilePhoto != null && profilePhoto!.startsWith("http"))
                  ? NetworkImage(profilePhoto!) as ImageProvider
                  : null,
              child: (profilePhoto == null || profilePhoto!.isEmpty)
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : "U",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))
                : null,
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: active ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: const Text("Me", style: TextStyle(color: kPrimary, fontSize: 10, fontWeight: FontWeight.w800))),
            secondChild: const SizedBox(height: 14),
          ),
        ],
      ),
    );
  }
}



// ─────────────────────── MASONRY SEARCH GRID ───────────────────────
class _MasonrySearchGrid extends StatelessWidget {
  final List<Map<String,dynamic>> stores; final String token;
  const _MasonrySearchGrid({required this.stores,required this.token});

  Widget _imgWidget(Map s) {
    String img = s["image_url"]?.toString() ?? "";
    if (img.isEmpty) img = s["image_thumb"]?.toString() ?? "";
    if (img.isEmpty) img = s["image"]?.toString() ?? "";
    if (img.isEmpty) img = s["image2"]?.toString() ?? "";
    if (img.startsWith("data:image")) {
      try { return Image.memory(base64Decode(img.split(",").last),fit:BoxFit.cover,width:double.infinity,height:double.infinity,gaplessPlayback:true); }
      catch(_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }
    final imgUrl = img.startsWith("/") ? "$kBaseUrl$img" : img;
    if (imgUrl.startsWith("http")) {
      return CachedNetworkImage(imageUrl:imgUrl,fit:BoxFit.cover,width:double.infinity,height:double.infinity,
        placeholder:(_,__)=>Container(color:kAccent,child:const Center(child:Icon(Icons.store,color:kPrimary,size:32))),
        errorWidget:(_,__,___)=>Container(color:kAccent,child:const Center(child:Icon(Icons.store,color:kPrimary,size:32))));
    }
    return Container(color:kAccent, child:Center(child:Icon(Icons.store,color:kPrimary,size:32)));
  }

  @override Widget build(BuildContext context) {
    // Generate random heights: alternate between tall/medium/short
    final heights = List.generate(stores.length, (i) => [140.0,180.0,120.0,160.0,200.0,130.0][i%6]);
    // Build 2-column masonry
    final col1 = <int>[]; final col2 = <int>[];
    double h1=0, h2=0;
    for(int i=0;i<stores.length;i++){
      if(h1<=h2){col1.add(i);h1+=heights[i]+10;}
      else{col2.add(i);h2+=heights[i]+10;}
    }
    Widget _card(int idx) {
      final s=Map<String,dynamic>.from(stores[idx] as Map);
      final dist = s["distance_km"] != null ? (s["distance_km"] as num).toDouble() : null;
      final rating=(s["rating"] as num?)?.toDouble()??0;
      return GestureDetector(
        onTap:()=>Navigator.push(context,_route(StoreDetailPage(store:Map<String,dynamic>.from(s), token:token, userName:"", onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk)))))),
        child:Container(
          height:heights[idx],
          margin:const EdgeInsets.only(bottom:10),
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(16),
            boxShadow:[BoxShadow(color:Colors.black.withValues(alpha: .1),blurRadius:8,offset:const Offset(0,3))],
          ),
          child:ClipRRect(
            borderRadius:BorderRadius.circular(16),
            child:Stack(fit:StackFit.expand,children:[
              _imgWidget(s),
              Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
                gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
                  colors:[Colors.transparent,Colors.transparent,Colors.black.withValues(alpha: .7)],stops:const[0,.5,1]),
              ))),
              if(dist!=null) Positioned(top:7,right:7,child:Container(
                padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),
                decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(8)),
                child:Text(dist<1?"${(dist*1000).round()}m":"${dist.toStringAsFixed(1)}km",
                  style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w700)),
              )),
              Positioned(bottom:0,left:0,right:0,child:Padding(
                padding:const EdgeInsets.fromLTRB(8,0,8,8),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
                  Text(s["store_name"]?.toString()??"",style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800),maxLines:1,overflow:TextOverflow.ellipsis),
                  if(rating>0) Row(children:[
                    const Icon(Icons.star_rounded,color:Color(0xFFFFD700),size:10),const SizedBox(width:2),
                    Text(rating.toStringAsFixed(1),style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w700)),
                  ]),
                ]),
              )),
            ]),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding:const EdgeInsets.fromLTRB(12,12,12,24),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Column(children:col1.map(_card).toList())),
        const SizedBox(width:10),
        Expanded(child:Column(children:col2.map(_card).toList())),
      ]),
    );
  }
}

// ─────────────────────── GIFT VOUCHER CARD WIDGET ───────────────────────

class HomeScreen extends StatefulWidget {
  final String token, name, phone, savedCity, userId;
  final List<Map<String, dynamic>> preloadedStores;
  final double? preloadedLat, preloadedLng;
  const HomeScreen({
    super.key,
    required this.token,
    required this.name,
    required this.phone,
    required this.savedCity,
    this.userId = "",
    this.preloadedStores = const [],
    this.preloadedLat,
    this.preloadedLng,
  });
  @override State<HomeScreen> createState() => _HomeState();
}
class _HomeState extends State<HomeScreen> with WidgetsBindingObserver {
  String city="Detecting..."; bool cityDone=false; bool _locationDenied=false; int _navIdx=0; String? _profilePhoto;
  String _noServiceImg=""; String _noServiceTitle=""; String _noServiceMsg="";
  bool _netError=false; bool _fetchFailed=false;
  bool _loadAllRunning=false; // FIX 4: prevent parallel _loadAll calls
  bool _isTimeout=false; // FIX 10: distinguish timeout from other errors

  // ── Location + store cache (static so it survives rebuilds) ──
  static String _cachedCity = "";
  static double? _cachedLat;
  static double? _cachedLng;
  static List<Map<String,dynamic>> _cachedStores = [];
  static DateTime? _cacheTime;
  static const Duration _cacheTtl = Duration(minutes: 5);
  bool get _hasFreshCache =>
    _cachedCity.isNotEmpty &&
    _cachedStores.isNotEmpty &&
    _cacheTime != null &&
    DateTime.now().difference(_cacheTime!) < _cacheTtl;
  double? _userLat; double? _userLng;
  bool _cityManual = false;
  String _gpsDetectedCity = ''; // tracks the last GPS-detected city (not manual overrides)
  Timer? _catTimer;
  String _cat="All"; bool _loading=true;
  double _radiusKm = 0.0; // Nearby radius filter (0=All, 1, 3, 5, 10)
  List<Map<String,dynamic>> _stores=[]; List<String> _cats=["All"]; List<Map<String,dynamic>> _richCats=[];
  List<Map<String,dynamic>> _products=[];
  bool _productsLoading=true;
  int  _unreadCount=0; // notification badge count
  final Set<String> _favStoreIds = {}; // track favorited stores
  int  _walletPoints=0; // wallet visit points
  // FIX 1: FAB scroll-aware visibility
  final ScrollController _scrollCtrl = ScrollController();
  final ValueNotifier<bool> _fabVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _navVisible = ValueNotifier<bool>(true); // FIX 3: hide nav on scroll down
  List<Map<String,dynamic>> _sliders=[];
  List<Map<String,dynamic>> _adminBanners=[];
  String _cityImageUrl = ""; // fetched from /cities backend
  List<String> _cityImageUrls = []; // all city images for rotation
  int    _heroImgIndex = 0;          // current hero image index
  Timer? _heroRotateTimer;           // rotates hero image every 2 min
  String _defaultCityImageUrl = ""; // fallback from /admin/default-images
  int _sliderPage=0;
  final PageController _sliderPc = PageController(initialPage: 49999); // FIX 5: start at midpoint for infinite scroll
  Timer? _sliderTimer;
  // FIX 2: ValueNotifier for slider page — avoids full-tree rebuild on swipe
  final ValueNotifier<int> _sliderPageNotifier = ValueNotifier<int>(0);

  // Stores marked "new_in_town" go to big carousel; they also appear in top stores
  // Backend already filters by city — no double-filtering here.
  // If store["city"] is empty or mismatched due to data entry, we still show it.
  // Category filtering is client-side only.
  List<Map<String,dynamic>> get _cityFiltered => _stores;
  List<Map<String,dynamic>> get _topStores => _cityFiltered;

  void _recomputeDistances() {
    if (_userLat == null || _userLng == null) return;
    for (final s in _stores) {
      final lat = double.tryParse(s["latitude"]?.toString() ?? "");
      final lng = double.tryParse(s["longitude"]?.toString() ?? "");
      if (lat != null && lng != null) {
        s["distance_km"] = _haversineKm(_userLat!, _userLng!, lat, lng);
      }
    }
  }

  /// Returns stores that the admin pinned to float on the banner.
  /// For each banner, reads its `floating_store_ids` list.
  /// Falls back to _topStores (first 8) if no banner has pinned stores.
  List<Map<String,dynamic>> _floatingStores(
      List<Map<String,dynamic>> banners, List<Map<String,dynamic>> allStores) {
    final pinned = <String>{};
    for (final b in banners) {
      final ids = b["floating_store_ids"];
      if (ids is List) {
        for (final id in ids) {
          if (id != null) pinned.add(id.toString());
        }
      }
    }
    if (pinned.isEmpty) return allStores; // no pins → show all top stores
    final result = allStores
        .where((s) => pinned.contains(s["_id"]?.toString() ?? s["id"]?.toString() ?? ""))
        .toList();
    return result.isEmpty ? allStores : result;
  }
  List<Map<String,dynamic>> get _sl => _cityFiltered;
  // Nearby Stores: if GPS known, show stores within 5km sorted by distance.
  // If GPS unavailable, fall back to top 10 stores so section is never blank.
  List<Map<String,dynamic>> get _nearbyStores {
    final base = _cityFiltered;
    if (_userLat != null && _userLng != null) {
      // TASK 2 FIX: compute distance on-the-fly for stores missing distance_km
      // so 10km filter catches all stores regardless of when _rebuildCaches ran
      final withCoords = <Map<String,dynamic>>[];
      final noCoords   = <Map<String,dynamic>>[];
      for (final s in base) {
        final lat = double.tryParse(s["latitude"]?.toString() ?? s["lat"]?.toString() ?? "");
        final lng = double.tryParse(s["longitude"]?.toString() ?? s["lng"]?.toString() ?? "");
        if (lat != null && lng != null) {
          // Always recompute for accuracy
          s["distance_km"] = _haversineKm(_userLat!, _userLng!, lat, lng);
          withCoords.add(s);
        } else {
          noCoords.add(s);
        }
      }
      withCoords.sort((a,b) {
        final da=(a["distance_km"] as num?)?.toDouble()??9999.0;
        final db=(b["distance_km"] as num?)?.toDouble()??9999.0;
        return da.compareTo(db);
      });
      // Apply radius filter — stores with no lat/lng coords are shown only when "All" selected
      final filtered = _radiusKm > 0
          ? withCoords.where((s) {
              final d = (s["distance_km"] as num?)?.toDouble() ?? 9999.0;
              return d <= _radiusKm;
            }).toList()
          : [...withCoords, ...noCoords];
      if (filtered.isNotEmpty) return filtered;
      // If radius filter returns nothing (all stores beyond radius), show nearest 5
      if (_radiusKm > 0 && withCoords.isNotEmpty) {
        return withCoords.take(5).toList();
      }
    }
    // GPS unavailable — show all stores
    return base;
  }

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _loadRadius(); // Issue 1: load saved radius preference
    _loadUnreadCount(); // Issue 8: load notification badge
    _loadFavStores(); // load fav store ids for home screen hearts
    // Sync badge with real-time notifier (updates from FCM foreground messages)
    _unreadNotifier.addListener(_onUnreadChanged);
    // FIX 1: scroll listener for FAB visibility
    double _lastScrollOffset = 0;
    _scrollCtrl.addListener(() {
      final offset = _scrollCtrl.offset;
      // FAB: show when scrolled down > 120px
      _fabVisible.value = offset > 120;
      // Nav: hide when scrolling DOWN, show when scrolling UP or near top
      if (offset <= 10) {
        _navVisible.value = true;
      } else if (offset > _lastScrollOffset + 8) {
        _navVisible.value = false; // scrolling down
      } else if (offset < _lastScrollOffset - 8) {
        _navVisible.value = true;  // scrolling up
      }
      _lastScrollOffset = offset;
    });
    if (widget.preloadedStores.isNotEmpty) {
      _usePreloadedData(); // async — clears _loading when done
      // Always fetch live GPS even when preloaded — ensures distance_km is computed
      _fetchLiveGpsAndRecomputeDistances();
    } else {
      _initLoc();
    }
  }

  Future<void> _loadRadius() async {
    final r = await Prefs.getRadius();
    if (mounted) {
        _radiusKm = r;
        _recomputeDistances();
        setState(() {});
      }
  }

  Future<void> _loadUnreadCount() async {
    final n = await Prefs.getUnreadCount();
    if (mounted) setState(() => _unreadCount = n);
  }

  void _onUnreadChanged() {
    if (mounted) setState(() => _unreadCount = _unreadNotifier.value);
  }

  Future<void> _loadFavStores() async {
    if (widget.token.isEmpty) return;
    try {
      final raw = await Api.get("/user/favorites", token: widget.token);
      final ids = <String>{};
      if (raw is List) {
        for (final s in raw) {
          final id = (s["_id"] ?? s["id"] ?? s["store_id"] ?? "").toString();
          if (id.isNotEmpty) ids.add(id);
        }
      }
      if (mounted) setState(() => _favStoreIds.addAll(ids));
    } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
  }

  void _incrementUnread() async {
    await Prefs.incrementUnread();
    final n = await Prefs.getUnreadCount();
    if (mounted) setState(() => _unreadCount = n);
  }

  Future<void> _openNotifications(BuildContext ctx) async {
    await Prefs.clearUnread();
    if (mounted) setState(() => _unreadCount = 0);
    await Navigator.push(ctx, _route(NotificationsPage()));
  }

  Future<void> _usePreloadedData() async {
    final sl = List<Map<String,dynamic>>.from(widget.preloadedStores);
    final cityStr = widget.savedCity.isNotEmpty ? widget.savedCity : "";
    if (widget.preloadedLat != null) _userLat = widget.preloadedLat;
    if (widget.preloadedLng != null) _userLng = widget.preloadedLng;

    // Compute distances if GPS available
    if (_userLat != null && _userLng != null) {
      for (final s in sl) {
        final lat2 = double.tryParse(s["latitude"]?.toString() ?? "");
        final lng2 = double.tryParse(s["longitude"]?.toString() ?? "");
        if (lat2 != null && lng2 != null) {
          s["distance_km"] = _haversineKm(_userLat!, _userLng!, lat2, lng2);
        }
      }
      sl.sort((a, b) =>
          ((a["distance_km"] as double?) ?? 9999.0)
          .compareTo((b["distance_km"] as double?) ?? 9999.0));
    }

    setState(() {
      city     = cityStr;
      _stores  = sl;
      // Keep _loading=true until banners + products are ready
    });
    if (cityStr.isNotEmpty) {
      Prefs.saveCity(cityStr);
      Api.updateCity(widget.token, cityStr);
    }

    // Populate static cache with preloaded data
    _cachedCity   = cityStr;
    _cachedStores = List<Map<String,dynamic>>.from(sl);
    _cachedLat    = widget.preloadedLat;
    _cachedLng    = widget.preloadedLng;
    _cacheTime    = DateTime.now();

    // Await banners + products — only then clear loading overlay
    await _loadSupplementary(cityStr);
    if (mounted) setState(() => _loading = false);
    FcmService.init(
      city: cityStr,
      token: widget.token,
      userId: widget.userId.isNotEmpty ? widget.userId : null,
      phone: widget.phone,
      onTokenReady: (t, {required String phone, required String userId}) =>
          Api.registerFcmToken(t, phone: phone, userId: userId),
    );
  }

  Future<void> _loadSupplementary(String c) async {
    // Show loading state for supplementary sections while fetching
    if (mounted) setState(() { _productsLoading = true; });
    try {
      // FIX 5: individual guards — one failure won't blank all sections
      List<String> cats2 = ["All"]; List<Map<String,dynamic>> richCats2 = [];
      List slides = []; List voucs = []; Map<String,dynamic> wallet = {};
      List adminBannerList = []; String resolvedCityImg = "";
      await Future.wait([
        Api.fetchCategories().then((v) {
          final raw = v as List;
          richCats2 = raw.map((e) => e is Map ? Map<String,dynamic>.from(e) : <String,dynamic>{"name":e.toString(),"icon":"🏪","image_url":"","subtitle":""}).toList();
          cats2 = ["All", ...richCats2.map((e) => e["name"].toString())];
        }).catchError((_) {}),
        Api.getSliders().then((v) => slides = v as List).catchError((_) {}),
        Api.getPublicProducts(city: c).then((v) => voucs = v as List).catchError((_) {}),
        Api.fetchPublicProducts(city: c).then((v) {
          // Merge public products into products list (avoid duplicates by title)
          final existing = Set<String>.from(
              voucs.map((x) => (x["title"] ?? x["name"] ?? "").toString().toLowerCase()));
          for (final p in v) {
            final t = (p["title"] ?? p["name"] ?? "").toString().toLowerCase();
            if (!existing.contains(t)) { voucs.add(p); existing.add(t); }
          }
        }).catchError((_) {}),
        Api.getWallet(widget.token).then((v) => wallet = v as Map<String,dynamic>).catchError((_) {}),
        Api.getAdminBanners().then((v) => adminBannerList = v).catchError((_) {}),

      ]);
      // ── Hero images: fetch arrays from /default-images, rotate every 2 min ──
      List<String> resolvedCityImgs = [];
      String _mbFallbackUrl = "";
      try {
        final defaults = await Api.getDefaultImages().timeout(const Duration(seconds: 10));
        if (kDebugMode) debugPrint("[OFFRO] /default-images keys: \${defaults.keys.toList()}");
        final cityVal = defaults["city"];
        if (cityVal is List) {
          resolvedCityImgs = cityVal
              .map((v) => v.toString().trim())
              .where((v) => v.startsWith("http"))
              .toList();
        } else if (cityVal is String && cityVal.startsWith("http")) {
          resolvedCityImgs = [cityVal];
        }
        // Fallback: old single-string keys
        if (resolvedCityImgs.isEmpty) {
          for (final key in ["city_image_url", "city_image", "hero_image_url", "image_url"]) {
            final v = (defaults[key] ?? "").toString().trim();
            if (v.startsWith("http")) { resolvedCityImgs = [v]; break; }
          }
        }
        resolvedCityImg = resolvedCityImgs.isNotEmpty ? resolvedCityImgs[0] : "";
        if (kDebugMode) debugPrint("[OFFRO] Hero imgs loaded: \${resolvedCityImgs.length}");
        // Load no-service config (handle String or List from backend)
        final nsImgs = defaults["no_service"];
        String _nsUrl = "";
        if (nsImgs is List && (nsImgs as List).isNotEmpty) {
          _nsUrl = (nsImgs as List).last.toString().trim();
        } else if (nsImgs is String && nsImgs.trim().isNotEmpty) {
          _nsUrl = nsImgs.trim();
        }
        if (_nsUrl.startsWith("http") && mounted) {
          setState(() { _noServiceImg = _nsUrl; });
        }
        final nsTitle = (defaults["no_service_title"] ?? "").toString().trim();
        final nsMsg   = (defaults["no_service_message"] ?? "").toString().trim();
        if (mounted) setState(() {
          if (nsTitle.isNotEmpty) _noServiceTitle = nsTitle;
          if (nsMsg.isNotEmpty)   _noServiceMsg   = nsMsg;
        });
        _mbFallbackUrl = (defaults["merchant_banner"] ?? "").toString().trim();
      } catch (e) { if (kDebugMode) debugPrint("[OFFRO] getDefaultImages error: $e"); }

      final cats = cats2;

      // Retry sliders once if empty (FIX: banner disappear race condition)
      if (slides.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 800));
        try { slides = await Api.getSliders(); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
      }
      // City filter for promo sliders/banners
      if (c.isNotEmpty) {
        slides = (slides).where((s) {
          final sCity = (s["city"] ?? "").toString().trim().toLowerCase();
          return sCity.isEmpty || sCity == c.toLowerCase().trim();
        }).toList();
      }
      // Issue 4: Fallback — when no active banners exist for the city, show the default merchant banner
      if (slides.isEmpty && _mbFallbackUrl.startsWith("http")) {
        slides = [{"id": "default", "title": "", "subtitle": "", "image": _mbFallbackUrl, "image_url": _mbFallbackUrl, "link_url": "", "bg_color": "", "sort_order": 0, "city": ""}];
      }
      // Retry admin banners once if empty (large base64 image can timeout)
      if (adminBannerList.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        try { adminBannerList = await Api.getAdminBanners(); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
      }
      // Retry products if fewer than expected
      if (voucs.length < 8) {
        try {
          final extra = await Api.getPublicProducts(city: c);
          final existingT = Set<String>.from(voucs.map((x)=>(x["title"]??x["name"]??"").toString().toLowerCase()));
          for (final p in extra) {
            final t = (p["title"]??p["name"]??"").toString().toLowerCase();
            if (!existingT.contains(t)) { voucs.add(p); existingT.add(t); }
          }
        } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
      }
      if (voucs.length < 8) {
        try {
          final pubP = await Api.fetchPublicProducts(city: c);
          final existingT2 = Set<String>.from(voucs.map((x)=>(x["title"]??x["name"]??"").toString().toLowerCase()));
          for (final p in pubP) {
            final t = (p["title"]??p["name"]??"").toString().toLowerCase();
            if (!existingT2.contains(t)) { voucs.add(p); existingT2.add(t); }
          }
        } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
      }

      // TASK 6 FIX: filter out expired products (end_date in past)
      final _now6 = DateTime.now();
      voucs = voucs.where((v) {
        final endRaw = (v["end_date"] ?? v["validity_end"] ?? "").toString();
        if (endRaw.isEmpty) return true;
        try { return DateTime.parse(endRaw).isAfter(_now6); } catch (_) { return true; }
      }).toList();
      // City filter: only show products/banners matching current city
      if (c.isNotEmpty) {
        voucs = voucs.where((v) {
          final vCity = (v["city"] ?? v["store_city"] ?? "").toString().trim().toLowerCase();
          return vCity.isEmpty || vCity == c.toLowerCase().trim();
        }).toList();
      }


      if (!mounted) return;
      final sliderList  = List<Map<String,dynamic>>.from(slides);
      final productList = List<Map<String,dynamic>>.from(voucs);
      for (int i = 0; i < sliderList.length; i++)  sliderList[i]["_idx"]  = i;
      for (int i = 0; i < productList.length; i++) productList[i]["_idx"] = i;

      // City image fetched in parallel in Future.wait above

      setState(() {
        _cats            = List<String>.from(cats);
        if (richCats2.isNotEmpty) _richCats = richCats2;
        else if (_richCats.isEmpty) Api.clearCache(); // force refetch next time
        _sliders         = sliderList;
        _adminBanners    = List<Map<String,dynamic>>.from(adminBannerList);
        _products        = productList;
        _productsLoading = false;
        _walletPoints    = (wallet["visit_points"] as num?)?.toInt() ?? 0;
        if (resolvedCityImgs.isNotEmpty) {
          _cityImageUrls = resolvedCityImgs;
          _cityImageUrl  = resolvedCityImgs[0];
        } else if (resolvedCityImg.isNotEmpty) {
          _cityImageUrls = [resolvedCityImg];
          _cityImageUrl  = resolvedCityImg;
        }
        _recomputeDistances();
      });
      _startSliderAutoPlay();
      _startHeroRotation();
    } catch (e) {
      if (kDebugMode) debugPrint("[OFFRO] _loadSupplementary error: $e");
    }
  }

  Future<void> _loadAll(String c) async {
    // FIX 4: Guard against parallel _loadAll calls (race condition prevention)
    if (_loadAllRunning) {
      if (kDebugMode) debugPrint("[OFFRO] _loadAll($c) skipped — already running");
      return;
    }

    // ── Cache hit: same city + fresh data → show instantly, refresh in bg ──
    final sameCity = c.toLowerCase().trim() == _cachedCity.toLowerCase().trim();
    if (sameCity && _hasFreshCache) {
      if (kDebugMode) debugPrint("[OFFRO] _loadAll($c) — CACHE HIT, rendering stores instantly");
      if (mounted) {
        setState(() {
          _stores  = List<Map<String,dynamic>>.from(_cachedStores);
          _netError = false;
          _fetchFailed = false;
          city = c;
          if (_cachedLat != null) _userLat = _cachedLat;
          if (_cachedLng != null) _userLng = _cachedLng;
        });
        _recomputeDistances();
      }
      // Still load banners/products if not yet loaded (keeps loading overlay until ready)
      if (_sliders.isEmpty || _products.isEmpty) {
        await _loadSupplementary(c);
      }
      if (mounted) setState(() => _loading = false);
      _loadAllRunning = false;
      return;
    }

    _loadAllRunning = true;

    if(mounted) setState((){_loading=true; _netError=false; _fetchFailed=false;});
    if (kDebugMode) debugPrint("[OFFRO] _loadAll starting for city: $c");

    // FIX 6: Retry up to 3 times with 2s backoff
    List storeList = [];
    bool storeFetchFailed = false;
    bool isNetworkError = false;
    bool isTimeoutError = false;

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        if (attempt > 1) {
          if (kDebugMode) debugPrint("[OFFRO] stores retry attempt $attempt...");
          await Future.delayed(const Duration(seconds: 2));
          Api.clearCache(); // clear cache before retry
        }
        storeList = await Api.fetchStores(city: c);
        storeFetchFailed = false;
        if (kDebugMode) debugPrint("[OFFRO] stores loaded: ${storeList.length} items on attempt $attempt");
        break; // success
      } on SocketException catch(e) {
        if (kDebugMode) debugPrint("[OFFRO] stores attempt $attempt — network error: $e");
        isNetworkError = true;
        storeFetchFailed = true;
        if (attempt == 3 && mounted) {
          _loadAllRunning = false;
          setState((){_loading=false; _netError=true; _fetchFailed=true;});
          return;
        }
      } on TimeoutException catch(e) {
        if (kDebugMode) debugPrint("[OFFRO] stores attempt $attempt — timeout: $e");
        isTimeoutError = true;
        storeFetchFailed = true;
        // On timeout: clear cache and retry
        Api.clearCache();
      } catch(e) {
        if (kDebugMode) debugPrint("[OFFRO] stores attempt $attempt — API error: $e");
        storeFetchFailed = true;
      }
    }

    // If all 3 attempts failed
    if (storeFetchFailed && storeList.isEmpty) {
      if (mounted) {
        _loadAllRunning = false;
        setState((){
          _loading=false;
          _netError = isNetworkError;
          _fetchFailed = true;
          _productsLoading = false;
        });
      }
      return;
    }

    // Fetch everything else in parallel (non-critical — fail silently)
    List cats = ["All"]; List<Map<String,dynamic>> richCats3 = []; List slides = []; List voucs = []; Map<String,dynamic> wallet = {};
    try {
      // FIX 5: guard each future individually
      await Future.wait([
        Api.fetchCategories().then((v) {
          final raw = v as List;
          richCats3 = raw.map((e) => e is Map ? Map<String,dynamic>.from(e) : <String,dynamic>{"name":e.toString(),"icon":"🏪","image_url":"","subtitle":""}).toList();
          cats = ["All", ...richCats3.map((e) => e["name"].toString())];
        }).catchError((_) {}),
        Api.getSliders().then((v) => slides = v as List).catchError((_) {}),
        Api.getPublicProducts(city: c).then((v) => voucs = v as List).catchError((_) {}),
        Api.fetchPublicProducts(city: c).then((v) {
          // Merge public products into products list (avoid duplicates by title)
          final existing = Set<String>.from(
              voucs.map((x) => (x["title"] ?? x["name"] ?? "").toString().toLowerCase()));
          for (final p in v) {
            final t = (p["title"] ?? p["name"] ?? "").toString().toLowerCase();
            if (!existing.contains(t)) { voucs.add(p); existing.add(t); }
          }
        }).catchError((_) {}),
        Api.getWallet(widget.token).then((v) => wallet = v as Map<String,dynamic>).catchError((_) {}),
      ]);
    } catch(e) {
      if (kDebugMode) debugPrint("[OFFRO] secondary data error (non-fatal): $e");
    }

    // TASK 6 FIX: filter out expired products
    final _now6b = DateTime.now();
    voucs = voucs.where((v) {
      final endRaw = (v["end_date"] ?? v["validity_end"] ?? "").toString();
      if (endRaw.isEmpty) return true;
      try { return DateTime.parse(endRaw).isAfter(_now6b); } catch (_) { return true; }
    }).toList();
    // City filter: only show products/banners matching current city
    if (c.isNotEmpty) {
      voucs = voucs.where((v) {
        final vCity = (v["city"] ?? v["store_city"] ?? "").toString().trim().toLowerCase();
        return vCity.isEmpty || vCity == c.toLowerCase().trim();
      }).toList();
    }


    if(!mounted) { _loadAllRunning = false; return; }

    final sl = List<Map<String,dynamic>>.from(storeList);
    if(_userLat != null && _userLng != null) {
      for(final s in sl){
        final lat = double.tryParse(s["latitude"]?.toString()??"");
        final lng = double.tryParse(s["longitude"]?.toString()??"");
        if(lat!=null && lng!=null) s["distance_km"] = _haversineKm(_userLat!,_userLng!,lat,lng);
      }
      sl.sort((a,b){
        final da=(a["distance_km"] as double?)??9999.0;
        final db=(b["distance_km"] as double?)??9999.0;
        return da.compareTo(db);
      });
    }

    // FIX 4b: If products empty, retry both endpoints
    if (voucs.isEmpty) {
      try {
        voucs = await Api.getPublicProducts(city: c);
        if (kDebugMode) debugPrint("[OFFRO] Product retry (products): ${voucs.length} products");
      } catch(e) {
        if (kDebugMode) debugPrint("[OFFRO] Product retry failed: $e");
      }
    }
    // Also merge public products on the secondary path (FIX 4c)
    if (voucs.length < 8) {
      try {
        final pubProds = await Api.fetchPublicProducts(city: c);
        final existingTitles = Set<String>.from(
            voucs.map((x) => (x["title"] ?? x["name"] ?? "").toString().toLowerCase()));
        for (final p in pubProds) {
          final t = (p["title"] ?? p["name"] ?? "").toString().toLowerCase();
          if (!existingTitles.contains(t)) { voucs.add(p); existingTitles.add(t); }
        }
        if (kDebugMode) debugPrint("[OFFRO] FIX4c public products merged: ${voucs.length} total");
      } catch(e) {
        if (kDebugMode) debugPrint("[OFFRO] FIX4c fetchPublicProducts failed: $e");
      }
    }
    final productList = List<Map<String,dynamic>>.from(voucs);
    for(int i=0;i<productList.length;i++) productList[i]["_idx"] = i;
    // FIX: retry sliders once if empty (banner race condition)
    if (slides.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 800));
      try { slides = await Api.getSliders(); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }
    final sliderList = List<Map<String,dynamic>>.from(slides);
    for(int i=0;i<sliderList.length;i++) sliderList[i]["_idx"] = i;

    // Update static cache
    _cachedCity   = c;
    _cachedStores = List<Map<String,dynamic>>.from(sl);
    _cachedLat    = _userLat;
    _cachedLng    = _userLng;
    _cacheTime    = DateTime.now();

    setState((){
      _stores   = sl;
      _cats     = List<String>.from(cats);
        if (richCats3.isNotEmpty) _richCats = richCats3;
        else if (_richCats.isEmpty) Api.clearCache(); // force refetch
      _sliders  = sliderList;
      _products = productList;
      _productsLoading = false;
      _loading  = false;
      _fetchFailed = false;
    });
    _recomputeDistances(); // called after setState so _stores is committed before mutation

    _loadAllRunning = false;
    _startSliderAutoPlay();
    // FIX 6: trigger hero + admin banners load immediately on first open
    _loadSupplementary(c);
    if(mounted) setState((){_isTimeout=false;});
    if (kDebugMode) debugPrint("[OFFRO] _loadAll complete. stores=${sl.length}");

    // Init FCM after data loads — city is known at this point
    FcmService.init(
      city: c,
      token: widget.token,
      userId: widget.userId.isNotEmpty ? widget.userId : null,
      phone: widget.phone,
      onTokenReady: (t, {required String phone, required String userId}) =>
          Api.registerFcmToken(t, phone: phone, userId: userId),
    );
  }

  // _loadWallet merged into _loadAll
  Future<void> _loadProfile() async {
    try { final d=await Api.getMe(widget.token); if(mounted&&d!=null) setState(()=>_profilePhoto=d["photo"]?.toString()); } catch(_){ if (kDebugMode) debugPrint('[Offro] suppressed error'); }
  }
  // _loadProducts merged into _loadAll
  // _loadSliders merged into _loadAll
  void _startHeroRotation() {
    _heroRotateTimer?.cancel();
    if (_cityImageUrls.length < 2) return;
    _heroRotateTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (!mounted) return;
      setState(() {
        _heroImgIndex = (_heroImgIndex + 1) % _cityImageUrls.length;
        _cityImageUrl = _cityImageUrls[_heroImgIndex];
      });
    });
  }

  void _startSliderAutoPlay(){
    _sliderTimer?.cancel();
    if(_sliders.length>1){
      _sliderTimer=Timer.periodic(const Duration(minutes:2),(_){
        if(_sliderPc.hasClients){
          // FIX 5c: always go forward by 1 real page — no modulo jump
          final nextPage = (_sliderPc.page?.round() ?? 49999) + 1;
          _sliderPc.animateToPage(nextPage,duration:const Duration(milliseconds:500),curve:Curves.easeInOut);
        }
      });
    }
  }
  // _startProductSlide — removed (not needed)

  // ── City Picker ──────────────────────────────────────
  Future<void> _showCityPicker(BuildContext context) async {
    // Use cities map from merchant_screens (imported library — re-declare locally)
    const _cityMap = {
      "Andhra Pradesh":["Visakhapatnam","Vijayawada","Guntur","Nellore","Kurnool","Rajahmundry","Tirupati"],
      "Karnataka":["Bengaluru","Mysuru","Hubli","Mangaluru","Ballari","Belagavi","Davangere","Shivamogga"],
      "Telangana":["Hyderabad","Warangal","Karimnagar","Nizamabad","Khammam","Mahbubnagar"],
      "Maharashtra":["Mumbai","Pune","Nagpur","Nashik","Aurangabad","Solapur","Kolhapur"],
      "Tamil Nadu":["Chennai","Coimbatore","Madurai","Tiruchirappalli","Salem","Tirunelveli"],
      "Delhi":["New Delhi","Dwarka","Rohini","Saket","Lajpat Nagar","Connaught Place"],
      "Gujarat":["Ahmedabad","Surat","Vadodara","Rajkot","Bhavnagar","Jamnagar"],
      "Rajasthan":["Jaipur","Jodhpur","Udaipur","Kota","Ajmer","Bikaner"],
      "Uttar Pradesh":["Lucknow","Kanpur","Agra","Varanasi","Meerut","Allahabad","Ghaziabad","Noida"],
      "West Bengal":["Kolkata","Howrah","Durgapur","Asansol","Siliguri"],
      "Punjab":["Chandigarh","Ludhiana","Amritsar","Jalandhar","Patiala"],
      "Haryana":["Gurugram","Faridabad","Hisar","Rohtak","Panipat"],
      "Kerala":["Thiruvananthapuram","Kochi","Kozhikode","Thrissur","Kollam"],
      "Madhya Pradesh":["Bhopal","Indore","Gwalior","Jabalpur","Ujjain"],
      "Bihar":["Patna","Gaya","Bhagalpur","Muzaffarpur"],
      "Odisha":["Bhubaneswar","Cuttack","Rourkela","Sambalpur"],
      "Jharkhand":["Ranchi","Jamshedpur","Dhanbad","Bokaro"],
      "Chhattisgarh":["Raipur","Bilaspur","Durg","Bhilai"],
      "Assam":["Guwahati","Dibrugarh","Silchar","Jorhat"],
      "Himachal Pradesh":["Shimla","Manali","Dharamshala","Solan"],
      "Uttarakhand":["Dehradun","Haridwar","Roorkee","Haldwani"],
      "Jammu and Kashmir":["Srinagar","Jammu","Leh"],
      "Goa":["Panaji","Margao","Vasco da Gama"],
      "Puducherry":["Puducherry","Karaikal"],
    };
    final states = _cityMap.keys.toList()..sort();
    String selState = "";
    String selCity  = "";
    // Pre-fill current city's state if possible
    for(final st in states){
      if(_cityMap[st]!.contains(city)){selState=st; selCity=city; break;}
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        final cities = selState.isNotEmpty?(_cityMap[selState]!.toList()..sort()):<String>[];
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom+20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20,16,20,8),
            child: Column(mainAxisSize:MainAxisSize.min, crossAxisAlignment:CrossAxisAlignment.start, children:[
              Row(children:[
                const Icon(Icons.location_on, color:kPrimary, size:20),
                const SizedBox(width:8),
                const Text("Select Your City", style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:kText)),
                const Spacer(),
                // GPS button — refresh to live location
                IconButton(
                  icon: const Icon(Icons.gps_fixed, color:kPrimary),
                  tooltip:"Use GPS",
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState((){_cityManual=false; city="Detecting..."; _loading=true; _productsLoading=true;});
                    final det = await detectCity();
                    try {
                      final pos = await Geolocator.getCurrentPosition(desiredAccuracy:LocationAccuracy.medium)
                          .timeout(const Duration(seconds:10));
                      if(mounted) setState((){
                        _userLat=pos.latitude; _userLng=pos.longitude;
                        _cityManual=false; // Explicitly restore GPS mode
                      });
                      _recomputeDistances(); // Recompute distances after GPS restored
                    } catch(_){ if (kDebugMode) debugPrint('[Offro] suppressed error'); }
                    if(!mounted) return;
                    _gpsDetectedCity = det; // restore GPS city reference
                    setState((){city=det; _locationDenied=false; _cityManual=false;});
                    await Prefs.saveCity(det);
                    await Api.updateCity(widget.token, det);
                    await _fetchStores(det);
                  },
                ),
              ]),
              const Divider(height:1),
              const SizedBox(height:14),
              // State dropdown
              const Text("State", style:TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:kMuted)),
              const SizedBox(height:6),
              DropdownButtonFormField<String>(
                value: selState.isNotEmpty?selState:null,
                hint: const Text("Select State"),
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
                  contentPadding: const EdgeInsets.symmetric(horizontal:14,vertical:10),
                ),
                items: states.map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
                onChanged:(v){ setS((){selState=v??''; selCity='';});},
              ),
              const SizedBox(height:14),
              // City dropdown
              const Text("City", style:TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:kMuted)),
              const SizedBox(height:6),
              DropdownButtonFormField<String>(
                value: selCity.isNotEmpty?selCity:null,
                hint: const Text("Select City"),
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
                  contentPadding: const EdgeInsets.symmetric(horizontal:14,vertical:10),
                ),
                items: cities.map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),
                onChanged:(v){ setS((){selCity=v??'';});},
              ),
              const SizedBox(height:20),
              SizedBox(width:double.infinity, child:ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:kPrimary, foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
                  padding:const EdgeInsets.symmetric(vertical:14),
                ),
                onPressed: selCity.isEmpty?null:() async {
                  Navigator.pop(ctx);
                  final oldCity = city;
                  // If user picks the same city GPS detected → restore GPS mode (show KM chips)
                  // Compare against _gpsDetectedCity (in-memory), NOT Prefs.getCity()
                  // because Prefs.getCity() returns the LAST saved city (could be manual)
                  final isGpsCity = _gpsDetectedCity.isNotEmpty &&
                      _gpsDetectedCity.trim().toLowerCase() == selCity.trim().toLowerCase();
                  setState((){city=selCity; _cityManual=!isGpsCity;});
                  await Prefs.saveCity(selCity);
                  await Api.updateCity(widget.token, selCity);
                  FcmService.updateCityTopic(selCity, oldCity: oldCity);
                  await _fetchStores(selCity);
                },
                child: const Text("Apply", style:TextStyle(fontSize:15,fontWeight:FontWeight.w700)),
              )),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _fetchLiveGpsAndRecomputeDistances() async {
    // Called when preloaded data is used — fetches live GPS and recomputes distances
    // This ensures banner store cards always show real distance, not "0.0 km"
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (mounted) setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        // Recompute distance_km on all store maps in-place
        for (final s in _stores) {
          final lat = double.tryParse(s["latitude"]?.toString() ?? s["lat"]?.toString() ?? "");
          final lng = double.tryParse(s["longitude"]?.toString() ?? s["lng"]?.toString() ?? "");
          if (lat != null && lng != null) {
            s["distance_km"] = _haversineKm(pos.latitude, pos.longitude, lat, lng);
          }
        }
      });
      // Persist for next session
      Prefs.saveLocation(pos.latitude, pos.longitude);
      if (kDebugMode) debugPrint("[OFFRO] Live GPS recomputed distances: lat=${pos.latitude} lng=${pos.longitude}");
    } catch (e) {
      if (kDebugMode) debugPrint("[OFFRO] GPS recompute failed: $e");
    }
  }

  Future<void> _initLoc() async {
    // ── Permission-first location flow ──
    // Step 0: Request location permission if needed BEFORE calling GPS.
    // This shows the native OS dialog on first launch.
    // Only show the Settings screen on permanent denial.

    // FIX 1: Always invalidate static cache at the start of every _initLoc call.
    // This ensures that if the user physically moved to a different city since
    // last session, the stale sameCity cache never blocks a fresh fetch.
    _cachedCity   = "";
    _cachedStores = [];
    _cacheTime    = null;
    Api.clearCache();

    String? firstLoadCity;

    // Step 1: Show savedCity immediately while we wait for GPS
    if (widget.savedCity.isNotEmpty) {
      firstLoadCity = widget.savedCity;
      setState(() { city = widget.savedCity; _locationDenied = false; });
    } else {
      if (mounted) setState(() { _loading = true; });
    }

    // Step 2: Check and request permission (shows native dialog if needed)
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      // Show native OS permission dialog
      perm = await Geolocator.requestPermission();
    }

    if (!mounted) return;

    if (perm == LocationPermission.deniedForever) {
      // Truly permanently denied — only NOW show the Settings screen
      if (kDebugMode) debugPrint("[OFFRO] Location permanently denied → Settings state");
      setState(() { city = ""; _loading = false; _locationDenied = true; });
      // Still load all stores without city filter
      if (firstLoadCity != null) {
        await _loadAll(firstLoadCity);
      } else {
        await _loadAll("");
      }
      return;
    }

    // Step 3: Try GPS — first use cached GPS for instant render, then refresh in background
    String det = widget.savedCity;

    // 3a: Try to restore last known GPS from Prefs (instant, no network)
    final savedLoc = await Prefs.getSavedLocation();
    if (savedLoc != null) {
      _userLat = savedLoc["lat"];
      _userLng = savedLoc["lng"];
      if (kDebugMode) debugPrint("[OFFRO] Restored cached GPS: lat=$_userLat lng=$_userLng");
    }

    // 3b: Live GPS — single fetch, then resolve city name
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 12));
      _userLat = pos.latitude;
      _userLng = pos.longitude;
      if (mounted) {
        setState(() { _userLat = pos.latitude; _userLng = pos.longitude; });
        _recomputeDistances();
        if (mounted) setState(() {}); // trigger rebuild with updated distances
      };
      // Pass position directly — avoids a second GPS fetch inside detectCity()
      det = await detectCityFromPosition(pos).timeout(const Duration(seconds: 10));
      if (kDebugMode) debugPrint("[OFFRO] Live GPS city: $det (lat=${pos.latitude}, lng=${pos.longitude})");
    } catch (e) {
      if (kDebugMode) debugPrint("[OFFRO] GPS/city detection failed: $e");
      // Use cached coords city if available, else savedCity, else default
      if (_userLat != null && _userLng != null) {
        try {
          final cachedPos = Position(
            latitude: _userLat!, longitude: _userLng!,
            timestamp: DateTime.now(), accuracy: 0, altitude: 0,
            altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
          );
          det = await detectCityFromPosition(cachedPos).timeout(const Duration(seconds: 8));
          if (kDebugMode) debugPrint("[OFFRO] Used cached coords city: $det");
        } catch (_) {
          det = widget.savedCity.isNotEmpty ? widget.savedCity : "Ballari";
        }
      } else {
        det = widget.savedCity.isNotEmpty ? widget.savedCity : "Ballari";
      }
    }

    if (!mounted) return;

    // Step 4: Commit city and load stores
    _gpsDetectedCity = det; // remember GPS city for chip logic
    setState(() { city = det; _locationDenied = false; });
    Prefs.saveCity(det);
    // Persist GPS coords so next restart skips GPS detection
    if (_userLat != null && _userLng != null) {
      Prefs.saveLocation(_userLat!, _userLng!);
    }
    Api.updateCity(widget.token, det);

    // FIX 1: If GPS city differs from cached city, wipe stale static cache
    // so _loadAll always fetches fresh stores for the new location.
    if (det.toLowerCase().trim() != _cachedCity.toLowerCase().trim()) {
      _cachedCity   = "";
      _cachedStores = [];
      _cacheTime    = null;
      Api.clearCache();
      if (kDebugMode) debugPrint("[OFFRO] City changed (${{_cachedCity}} → $det) — cache cleared");
    }

    if (kDebugMode) debugPrint("[OFFRO] _initLoc: detected city=$det → loading stores...");
    await _loadAll(det);

    // Step 5: Recalculate distances if GPS available
    if (_userLat != null && _userLng != null && mounted) {
      setState(() {
        for (final s in _stores) {
          final lat = double.tryParse(s["latitude"]?.toString() ?? "");
          final lng = double.tryParse(s["longitude"]?.toString() ?? "");
          if (lat != null && lng != null) {
            s["distance_km"] = _haversineKm(_userLat!, _userLng!, lat, lng);
          }
        }
        _recomputeDistances();
      });
    }
  }

  // Called ONLY when the city changes — category changes are client-side only
  Future<void> _fetchStores(String c) async {
    if (kDebugMode) debugPrint("[OFFRO] _fetchStores: city changed to $c");
    _loadAllRunning = false; // reset guard so city change always goes through
    Api.clearCache();
    await _loadAll(c);
  }


  // _startSlide removed — _pc was orphaned, not connected to any PageView in build



  void _showCatMenu() { _catTimer?.cancel();
    _catTimer=Timer(const Duration(seconds:5),(){});
  }

  @override void dispose() {
    _unreadNotifier.removeListener(_onUnreadChanged);
    WidgetsBinding.instance.removeObserver(this);
    _catTimer?.cancel(); _sliderTimer?.cancel(); _heroRotateTimer?.cancel(); _sliderPc.dispose();
    _scrollCtrl.dispose(); // FIX 1: FAB scroll controller
    _fabVisible.dispose(); // FIX 1: FAB notifier
    _navVisible.dispose(); // FIX 3: nav visible notifier
    _sliderPageNotifier.dispose(); // FIX 2: slider notifier
    super.dispose();
  }

  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh unread badge when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _loadUnreadCount();
      if (mounted) setState(() => _unreadCount = _unreadNotifier.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sl=_sl;
    final nearbyStores=_nearbyStores;  // GPS-aware with fallback to top stores
    final size = MediaQuery.of(context).size;
    final topStores = _topStores;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.white,
        body: _locationDenied
          ? _locationDeniedState()
          : Stack(children: [
              _loading
              ? LayoutBuilder(builder: (ctx, bc) => SizedBox(
                  width: bc.maxWidth,
                  height: bc.maxHeight.isFinite ? bc.maxHeight : MediaQuery.of(ctx).size.height,
                  child: ColoredBox(
                    color: Colors.white,
                    child: _buildLoadingSkeleton(),
                  ),
                ))
              : _cityFiltered.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                  onRefresh: ()=>_fetchStores(city),
                  color: kPrimary,
                  child: CustomScrollView(controller: _scrollCtrl, slivers:[

                    // ══════ 1. HERO — City image (flush to top, header merged) ══════
                    SliverToBoxAdapter(child: _CityHeroSection(
                      city: city,
                      cityImageUrl: _cityImageUrl,
                      cityManual: _cityManual,
                      unreadCount: _unreadCount,
                      onCityTap: () => _showCityPicker(context),
                      onBellTap: () => _openNotifications(context),
                    )),

                    // ══════ 3. CATEGORY CHIPS (below search) ══════
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                      child: _CategoryChipsRow(
                        cats: _richCats,
                        token: widget.token,
                        userLat: _userLat,
                        userLng: _userLng,
                        selectedCity: city,
                        onMoreTap: () => Navigator.push(context, _route(_BrowseAllCategoriesScreen(
                          cats: _richCats, token: widget.token,
                          userLat: _userLat, userLng: _userLng,
                          selectedCity: city))),
                      ),
                    )),

                                        // ══════ 4+5. ADMIN BANNER + EXPLORE STORES — one merged block ══════
                    SliverToBoxAdapter(child: _BannerStoresBlock(
                      banners: _adminBanners,
                      stores: _floatingStores(_adminBanners, _topStores),
                      token: widget.token,
                      favStoreIds: _favStoreIds,
                      onFavChanged: _loadFavStores,
                      onViewAll: () => _viewAll(context, "Explore Stores", _topStores, bigCards: false),
                    )),


                    // ══════ 6. DISCOVER PRODUCTS ══════
                    SliverToBoxAdapter(child: _DiscoverProductsSection(
                      products: _products,
                      onViewAll: () => _viewAllProducts(context),
                      token: widget.token,
                    )),

                    // ══════ 7. PROMO SLIDERS (merchant banners, small) ══════
                    SliverToBoxAdapter(child: _PromoSliderSection(
                      sliders: _sliders,
                      sliderPc: _sliderPc,
                      sliderPageNotifier: _sliderPageNotifier,
                      token: widget.token,
                      onSliderPageChanged: (i) {
                        _sliderPageNotifier.value = i % (_sliders.isEmpty ? 1 : _sliders.length);
                      },
                    )),

                    // ══════ 8. NEARBY STORES ══════
                    SliverToBoxAdapter(child: _NearbyStoresSection(
                      stores: nearbyStores,
                      radiusKm: _radiusKm,
                      token: widget.token,
                      onRadiusChanged: (km) async {
                        setState(() => _radiusKm = km);
                        await Prefs.saveRadius(km);
                      },
                      onViewAll: () => _viewAll(context, "Nearby Stores", nearbyStores),
                      onStoreTap: (s) => Navigator.push(context, _route(
                        StoreDetailPage(store: _enrichStoreForDetail(Map<String,dynamic>.from(s)), token: widget.token, userName: "", onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk)))))).then((_) => _loadFavStores()),
                    )),

                    // ══════ EXPLORE AREAS ══════
                    SliverToBoxAdapter(child: _ExploreAreasSection(
                      stores: _stores,
                      token: widget.token,
                    )),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ]),
                ),

            // Scroll-to-top FAB
            Positioned(
              bottom: 90, right: 16,
              child: ValueListenableBuilder<bool>(
                valueListenable: _fabVisible,
                builder: (_, visible, __) => AnimatedOpacity(
                  opacity: visible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: GestureDetector(
                      onTap: () => _scrollCtrl.animateTo(0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut),
                      child: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: kPrimary.withValues(alpha:.40), blurRadius: 12, offset: const Offset(0,4))],
                        ),
                        child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ══ BOTTOM NAV v2 — Home | Deals | [QR] | Search | Profile ══
            ValueListenableBuilder<bool>(
              valueListenable: _navVisible,
              builder: (_, visible, child) => AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                bottom: (visible && (_cityFiltered.isNotEmpty || _loading)) ? 0 : -80,
                left: 0, right: 0,
                child: child!,
              ),
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .92),
                      border: const Border(top: BorderSide(color: Color(0xFFe8f5ee), width: 1)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 16, offset: const Offset(0,-3)),
                      ],
                    ),
                    child: Row(children: [
                      // Home
                      Expanded(child: GestureDetector(
                        onTap: () { setState(() => _navIdx = 0); },
                        child: _NavBtn(icon: Icons.home_rounded, label: "Home", active: _navIdx == 0),
                      )),
                      // Deals
                      Expanded(child: GestureDetector(
                        onTap: () {
                          setState(() => _navIdx = 1);
                          // Pass city only when detection is complete (not "Detecting...")
                          final _dealsCity = (city == "Detecting..." || city.isEmpty) ? "" : city;
                          Navigator.push(context, _route(_AllDealsScreen(token: widget.token, city: _dealsCity)));
                        },
                        child: _NavBtn(icon: Icons.local_offer_rounded, label: "Deals", active: _navIdx == 1),
                      )),
                      // QR — center floating
                      GestureDetector(
                        onTap: () => Navigator.push(context, _route(QRPage(token: widget.token, onDone: () {}))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: 52, height: 52,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kPrimary,
                              boxShadow: [
                                BoxShadow(color: kPrimary.withValues(alpha: .40), blurRadius: 14, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                      // Search
                      Expanded(child: GestureDetector(
                        onTap: () { setState(() => _navIdx = 2); _searchStores(context); },
                        child: _NavBtn(icon: Icons.search_rounded, label: "Search", active: _navIdx == 2),
                      )),
                      // Profile
                      Expanded(child: GestureDetector(
                        onTap: () { setState(() => _navIdx = 3); _showProfile(context); },
                        child: _ProfileNavBtn(
                          profilePhoto: _profilePhoto,
                          name: widget.name,
                          active: _navIdx == 3,
                        ),
                      )),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
      ),
    );
  }


  Widget _buildCardContent(Map s){
    String imgStr = s["image_url"]?.toString() ?? "";
    if (imgStr.isEmpty) imgStr = s["image_thumb"]?.toString() ?? "";
    if (imgStr.isEmpty) imgStr = s["image"]?.toString() ?? "";
    if (imgStr.isEmpty) imgStr = s["image2"]?.toString() ?? "";
    if (imgStr.startsWith("data:image")) {
      try { return Image.memory(base64Decode(imgStr.split(",").last), fit:BoxFit.cover, gaplessPlayback:true); }
      catch(_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }
    if (imgStr.startsWith("http")) {
      return CachedNetworkImage(imageUrl: imgStr, fit: BoxFit.cover,
        width: double.infinity, height: double.infinity,
        placeholder: (_, __) => _placeholder(s),
        errorWidget: (_, __, ___) => _placeholder(s));
    }
    return _placeholder(s);
  }

  Widget _placeholder(Map s)=>Container(
    decoration:BoxDecoration(
      gradient:LinearGradient(colors:[kPrimary,const Color(0xFF3E5F55)],begin:Alignment.topLeft,end:Alignment.bottomRight)),
    child:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      const Icon(Icons.store_mall_directory_outlined,size:80,color:kLight),const SizedBox(height:14),
      Text(s["store_name"]??"",style:const TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold),textAlign:TextAlign.center),
      const SizedBox(height:4),
      Text(s["city"]??"",style:const TextStyle(color:kAccent,fontSize:13)),
    ])));

  Widget _locationDeniedState() => Container(
    color: kPrimary,
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.location_off, color: kLight, size: 64),
      const SizedBox(height: 20),
      const Text("Location Access Required", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text("Please allow location access to find stores near you.", style: TextStyle(color: kAccent, fontSize: 14), textAlign: TextAlign.center)),
      const SizedBox(height: 28),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: kLight, foregroundColor: kPrimary, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
        icon: const Icon(Icons.settings),
        label: const Text("Open Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => Geolocator.openAppSettings(),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () async { setState(()=>_locationDenied=false); await _initLoc(); },
        child: const Text("Try Again", style: TextStyle(color: Colors.white70)),
      ),
    ])),
  );

  // Skeleton extracted to: core/widgets/shimmer/home_skeleton.dart
  Widget _buildLoadingSkeleton() {
    // Native Flutter loading skeleton — no shimmer package needed
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Banner placeholder
        _skeletonBox(double.infinity, 150, radius: 14),
        const SizedBox(height: 14),
        // Category chips row
        Row(children: List.generate(4, (_) =>
          Padding(padding: const EdgeInsets.only(right: 8),
            child: _skeletonBox(70, 32, radius: 20)))),
        const SizedBox(height: 18),
        // Store cards
        ...List.generate(4, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _skeletonBox(double.infinity, 110, radius: 14),
        )),
      ]),
    );
  }

  Widget _skeletonBox(double w, double h, {double radius = 8}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 0.9),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (ctx, v, _) => AnimatedOpacity(
        opacity: v,
        duration: const Duration(milliseconds: 600),
        child: Container(
          width: w, height: h,
          decoration: BoxDecoration(
            color: const Color(0xFFd4e8de),
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    void _goRoleSelect() {
      Navigator.of(context).pushAndRemoveUntil(
        _route(ContinueAsScreen(
          phone: widget.phone,
          onRoleSelected: (role, remember) async => MyApp.goSwitchMode(
            widget.token, widget.name, widget.phone, widget.userId, role),
        )),
        (route) => false,
      );
    }

    Future<void> _openSupport() async {
      final s = await Api.getSocialLinks();
      final rawWa = (s["whatsapp"] ?? "").toString();
      if (rawWa.isNotEmpty) {
        final digits = rawWa.replaceAll(RegExp(r'[^0-9]'), '');
        final waNum = digits.length >= 10 ? (digits.length == 10 ? "91$digits" : digits) : digits;
        await launchUrl(Uri.parse("https://wa.me/$waNum"), mode: LaunchMode.externalApplication);
      }
    }

    final bottomPad = MediaQuery.of(context).padding.bottom;

    // ── Shared footer: two full-width pill buttons on white background ──
    final footer = Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomPad),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Button 1 — Back to Home (primary: kPrimary bg, white icon + text)
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _goRoleSelect,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.home_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Back to Home',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // Button 2 — Contact Support (secondary: white bg, kPrimary border, WhatsApp green icon)
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: () => _openSupport(),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kPrimary,
              side: const BorderSide(color: kPrimary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
              SizedBox(width: 8),
              Text('Contact Support',
                style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ]),
          ),
        ),
      ]),
    );

    // ── No-service with image: image fills top, footer below ──
    if (!_netError && !_isTimeout && !_fetchFailed && _noServiceImg.isNotEmpty) {
      return Column(children: [
        Expanded(
          child: Image.network(
            _noServiceImg,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => Container(color: kPrimary),
          ),
        ),
        footer,
      ]);
    }

    // ── Error / no-image states: kPrimary background + footer ──
    return Container(
      color: kPrimary,
      child: Column(children: [
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_netError) ...[
            const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 40),
            const SizedBox(height: 10),
            const Text("No internet connection", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text("Check your connection and try again", style: TextStyle(color: Colors.white60, fontSize: 13)),
          ] else if (_isTimeout) ...[
            const Icon(Icons.hourglass_empty_rounded, color: Colors.white54, size: 40),
            const SizedBox(height: 10),
            const Text("Server taking too long", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text("Cold start — please wait a moment and retry", style: TextStyle(color: Colors.white60, fontSize: 13)),
          ] else if (_fetchFailed) ...[
            const Icon(Icons.cloud_off_rounded, color: Colors.white54, size: 40),
            const SizedBox(height: 10),
            const Text("Couldn't load stores", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text("Please try again", style: TextStyle(color: Colors.white60, fontSize: 13)),
          ] else ...[
            Builder(builder: (_) {
              final displayCity = (city.isNotEmpty && city != 'Detecting...') ? city : 'your area';
              if (_noServiceMsg.isNotEmpty) {
                return Text(_noServiceMsg, style: const TextStyle(color: kLight, fontSize: 15), textAlign: TextAlign.center);
              }
              return Text('No stores in $displayCity yet', style: const TextStyle(color: kLight, fontSize: 16));
            }),
          ],
        ]))),
        footer,
      ]),
    );
  }



  // ── Filter sheet: radius + open now ──
  void _showFilterSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx2, setSt) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width:40,height:4,
              decoration:BoxDecoration(color:Colors.grey.shade300,borderRadius:BorderRadius.circular(2))),
            const SizedBox(height:20),
            const Text("Filter Stores", style: TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:kText)),
            const SizedBox(height:20),
            Align(alignment:Alignment.centerLeft,
              child:const Text("Distance",style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:kText))),
            const SizedBox(height:10),
            Row(children:[
              for(final km in [5.0, 10.0, 0.0])
                Expanded(child:Padding(
                  padding:const EdgeInsets.only(right:8),
                  child:GestureDetector(
                    onTap:() async {
                      setState(()=>_radiusKm=km);
                      await Prefs.saveRadius(km);
                      setSt((){});
                    },
                    child:AnimatedContainer(
                      duration:const Duration(milliseconds:200),
                      padding:const EdgeInsets.symmetric(vertical:10),
                      decoration:BoxDecoration(
                        color:_radiusKm==km?kPrimary:Colors.white,
                        border:Border.all(color:_radiusKm==km?kPrimary:kBorder,width:1.5),
                        borderRadius:BorderRadius.circular(12),
                      ),
                      child:Center(child:Text(
                        km==0?"All Distance":km==5?"5 km":"10 km",
                        style:TextStyle(color:_radiusKm==km?Colors.white:kMuted,fontSize:12,fontWeight:FontWeight.w700))),
                    ),
                  ),
                )),
            ]),
            const SizedBox(height:24),
            SizedBox(width:double.infinity,child:ElevatedButton(
              style:ElevatedButton.styleFrom(
                backgroundColor:kPrimary,foregroundColor:Colors.white,
                padding:const EdgeInsets.symmetric(vertical:14),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
              ),
              onPressed:()=>Navigator.pop(ctx),
              child:const Text("Apply Filters",style:TextStyle(fontSize:15,fontWeight:FontWeight.w800)),
            )),
          ]),
        );
      }),
    );
  }

  void _searchStores(BuildContext ctx) {
    Navigator.push(ctx, _route(_SearchPage(token:widget.token, city:city)));
  }

  // Profile sheet (replaces _more) — all options inside
  void _showProfile(BuildContext ctx) => showModalBottomSheet(
    context:ctx,
    isScrollControlled:true,
    backgroundColor:Colors.transparent,
    builder:(ctx2)=>DraggableScrollableSheet(
      initialChildSize:0.72,
      minChildSize:0.45,
      maxChildSize:0.92,
      expand:false,
      builder:(_,sc)=>Container(
        decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
        child:Column(children:[
          Container(width:40,height:4,margin:const EdgeInsets.only(top:12,bottom:4),
            decoration:BoxDecoration(color:Colors.grey.shade300,borderRadius:BorderRadius.circular(2))),
          UserProfileHeader(token:widget.token,name:widget.name,phone:widget.phone),
          const Divider(height:1),
          Expanded(child:ListView(controller:sc,children:[
            _pItem(ctx,Icons.search_rounded,"Search Stores",()=>_searchStores(ctx)),
            _pItem(ctx,Icons.account_balance_wallet_rounded,"My Wallet",()=>Navigator.push(ctx,_route(WalletPage(token:widget.token)))),
            _pItem(ctx,Icons.history_rounded,"Scan History",()=>Navigator.push(ctx,_route(HistoryPage(token:widget.token)))),
            _pItem(ctx,Icons.favorite_rounded,"My Favourites",()=>Navigator.push(ctx,_route(FavoritesPage(token:widget.token)))),
            _pItem(ctx,Icons.notifications_rounded,"Notifications",()=>Navigator.push(ctx,_route(NotificationsPage()))),
            const Divider(height:1),
            _pItem(ctx,Icons.info_outline_rounded,"About Us",()async{final c=await Api.getAboutUs();if(!ctx.mounted)return;showDialog(context:ctx,builder:(_)=>OffroDialog(title:"About Us",body:c.isEmpty?"Offro connects local stores with customers through deals and loyalty points.":c));}),
            _pItem(ctx,Icons.description_rounded,"Terms & Conditions",()async{final c=await Api.fetchTerms("user");if(!ctx.mounted)return;showDialog(context:ctx,builder:(_)=>OffroDialog(title:"Terms & Conditions",body:c));}),
            _pItem(ctx,Icons.privacy_tip_rounded,"Privacy Policy",()async{final c=await Api.fetchPolicy("privacy");if(!ctx.mounted)return;showDialog(context:ctx,builder:(_)=>OffroDialog(title:"Privacy Policy",body:c));}),
            _pItem(ctx,Icons.receipt_rounded,"Refund Policy",()async{final c=await Api.fetchPolicy("refund");if(!ctx.mounted)return;showDialog(context:ctx,builder:(_)=>OffroDialog(title:"Refund Policy",body:c));}),
            const Divider(height:1),
            // ── Switch Mode ──
            _switchModeItem(ctx),
            const Divider(height:1),
            _pItem(ctx,Icons.chat_bubble_rounded,"Contact Offro",()async{
              final s=await Api.getSocialLinks();
              final rawWa=s["whatsapp"]??"";
              if(rawWa.isNotEmpty){
                final digits=rawWa.replaceAll(RegExp(r'[^0-9]'),'');
                final waNum=digits.length>=10?(digits.length==10?"91$digits":digits):digits;
                await launchUrl(Uri.parse("https://wa.me/$waNum"),mode:LaunchMode.externalApplication);
              }
            },color:const Color(0xFF25D366)),
            _pItem(ctx,Icons.logout_rounded,"Logout",()async{
              await Prefs.clear();
              Api.clearCache();
              // Use navigatorKey so OnboardingScreen gets the goLogin callback
              MyApp.goOnboarding();
            },color:Colors.red),
            const SizedBox(height:28),
          ])),
        ]),
      ),
    ));

  Widget _switchModeItem(BuildContext ctx) => ListTile(
    leading: Container(
      width:38, height:38,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.swap_horiz_rounded, color: kPrimary, size: 20)),
    title: const Text('Switch Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kText)),
    subtitle: const Text('Switch between User & Merchant', style: TextStyle(fontSize: 11, color: kMuted)),
    trailing: const Icon(Icons.chevron_right, color: kMuted, size: 20),
    onTap: () {
      Navigator.pop(ctx); // close bottom sheet first
      showModalBottomSheet(
        context: MyApp.navigatorKey.currentContext ?? ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SwitchModeSheet(
          currentMode: 'user',
          token: widget.token,
          phone: widget.phone,
          onSwitch: (role) => MyApp.goSwitchMode(
            widget.token, widget.name, widget.phone, widget.userId, role),
        ),
      );
    },
  );

  Widget _pItem(BuildContext ctx,IconData icon,String title,VoidCallback onTap,{Color color=kPrimary})=>
    ListTile(
      leading:Container(
        width:38,height:38,
        decoration:BoxDecoration(
          color:color==kPrimary?kLight:color.withValues(alpha: .1),
          borderRadius:BorderRadius.circular(10)),
        child:Icon(icon,color:color==kPrimary?kPrimary:color,size:18)),
      title:Text(title,style:TextStyle(color:color==kPrimary?kText:color,fontWeight:FontWeight.w600,fontSize:14)),
      trailing:color==kPrimary?const Icon(Icons.arrow_forward_ios_rounded,size:13,color:kMuted):null,
      onTap:(){ Navigator.pop(ctx); onTap(); });

  // View All page
  // Cast _products to proper type for ProductViewAllPage
  void _viewAllProducts(BuildContext ctx) =>
    Navigator.push(ctx, _route(ProductViewAllPage(
      products: _products.map((v)=>Map<String,dynamic>.from(v as Map)).toList(),
      token: widget.token,
      city: city)));

  void _viewAll(BuildContext ctx, String title, List<Map<String,dynamic>> stores, {bool bigCards=false}) =>
    Navigator.push(ctx, _route(_ViewAllPage(title:title, stores:stores, token:widget.token, bigCards:bigCards)));
}

// ─────────────────────── VIEW ALL PAGE ───────────────────────

// ─────────────────────── SEARCH PAGE ───────────────────────
class _SearchPage extends StatefulWidget {
  final String token; final String city;
  const _SearchPage({required this.token, required this.city});
  @override State<_SearchPage> createState()=>_SearchPageState();
}
class _SearchPageState extends State<_SearchPage> {
  final _sc = TextEditingController();
  String _q = ""; bool _busy = false;
  List<Map<String,dynamic>> _results = [];

  @override void dispose(){ _sc.dispose(); super.dispose(); }

  Future<void> _doSearch(String q) async {
    final qt = q.trim();
    if (qt.isEmpty) { setState(()=>_results=[]); return; }
    setState(()=>_busy=true);
    try {
      final all = await Api.fetchStores(city:widget.city);
      final ql = qt.toLowerCase();
      _results = List<Map<String,dynamic>>.from(all.where((s)=>
        (s["store_name"]??'').toLowerCase().contains(ql)||
        (s["category"]??'').toLowerCase().contains(ql)||
        (s["area"]??'').toLowerCase().contains(ql)||
        (s["offer"]??'').toLowerCase().contains(ql)
      ).toList());
    } catch(_) { _results = []; }
    if (mounted) setState(()=>_busy=false);
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: TextField(
          controller: _sc,
          autofocus: true,
          style: const TextStyle(color:Colors.white, fontSize:15),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: "Search stores in ${widget.city}...",
            hintStyle: const TextStyle(color:Colors.white60, fontSize:14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical:14),
          ),
          onChanged:(v){ setState(()=>_q=v); if(v.trim().isNotEmpty) _doSearch(v); else setState(()=>_results=[]); },
          onSubmitted:_doSearch,
        ),
        actions:[
          if (_q.isNotEmpty) IconButton(icon:const Icon(Icons.clear,color:Colors.white),onPressed:(){ _sc.clear(); setState((){ _q=''; _results=[]; }); }),
        ],
      ),
      body: _busy
        ? const Center(child:CircularProgressIndicator(color:kPrimary))
        : _q.isEmpty
          ? _SearchLandingGrid(token:widget.token, city:widget.city)
          : _results.isEmpty
            ? Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
                const Icon(Icons.search_off,color:kAccent,size:56),
                const SizedBox(height:12),
                Text("No results for '$_q'",style:const TextStyle(color:kMuted,fontSize:15)),
              ]))
            : ListView.separated(
                padding:const EdgeInsets.all(14),
                separatorBuilder:(_,__)=>const SizedBox(height:8),
                itemCount:_results.length,
                itemBuilder:(_,i){
                  final s=_results[i];
                  String img=s["image_url"]?.toString()??''; if(img.isEmpty)img=s["image_thumb"]?.toString()??''; if(img.isEmpty)img=s["image"]?.toString()??''; if(img.isEmpty)img=s["image2"]?.toString()??'';
                  return GestureDetector(
                    onTap:()=>Navigator.push(context,_route(StoreDetailPage(store:Map<String,dynamic>.from(s), token:widget.token, userName:"", onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk)))))),
                    child:Container(padding:const EdgeInsets.all(12),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha: .05),blurRadius:8,offset:const Offset(0,2))]),
                      child:Row(children:[
                        ClipRRect(borderRadius:BorderRadius.circular(10),child:SizedBox(width:62,height:62,
                          child:img.isNotEmpty&&img.startsWith("data:image")
                            ? Image.memory(base64Decode(img.split(",").last),fit:BoxFit.cover)
                            : Container(color:kAccent,child:const Icon(Icons.store,color:kPrimary,size:28)))),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(s["store_name"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:kText,fontSize:14)),
                          Text("${s['category']??''} · ${s['area']??''}",style:const TextStyle(color:kMuted,fontSize:12)),
                          if ((s['visit_points']??0)>0) Padding(padding:const EdgeInsets.only(top:3),
                            child:Text("${s['visit_points']} pts on visit",style:const TextStyle(color:kPrimary,fontSize:11,fontWeight:FontWeight.w600))),
                        ])),
                        const Icon(Icons.arrow_forward_ios_rounded,color:kBorder,size:14),
                      ])));
                }),
    );
  }
}

// ─────────────────────── SEARCH LANDING GRID ───────────────────────
class _SearchLandingGrid extends StatefulWidget {
  final String token; final String city;
  const _SearchLandingGrid({required this.token,required this.city});
  @override State<_SearchLandingGrid> createState()=>_SearchLandingGridState();
}
class _SearchLandingGridState extends State<_SearchLandingGrid> {
  List<Map<String,dynamic>> _stores=[];bool _loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try{final d=await Api.fetchStores(city:widget.city);if(mounted)setState((){_stores=List<Map<String,dynamic>>.from(d);_loading=false;});}
    catch(_){if(mounted)setState(()=>_loading=false);}
  }
  @override Widget build(BuildContext context){
    if(_loading) return const Center(child:CircularProgressIndicator(color:kPrimary));
    if(_stores.isEmpty) return const Center(child:Text("No stores yet",style:TextStyle(color:kMuted)));
    return _MasonrySearchGrid(stores:_stores, token:widget.token);
  }
}

class _ViewAllPage extends StatefulWidget {
  final String title;
  final List<Map<String,dynamic>> stores;
  final String token;
  final bool bigCards; // true = Explore Stores style, false = grid
  const _ViewAllPage({required this.title, required this.stores, required this.token, this.bigCards=false});
  @override State<_ViewAllPage> createState()=>_ViewAllPageState();
}
class _ViewAllPageState extends State<_ViewAllPage>{
  final _searchCtrl = TextEditingController();
  String _q = "";
  @override void dispose(){ _searchCtrl.dispose(); super.dispose(); }

  List<Map<String,dynamic>> get _filtered {
    if (_q.trim().isEmpty) return widget.stores;
    final q = _q.toLowerCase();
    return widget.stores.where((s){
      return (s["store_name"]??"").toString().toLowerCase().contains(q)
          || (s["area"]??"").toString().toLowerCase().contains(q)
          || (s["city"]??"").toString().toLowerCase().contains(q)
          || (s["category"]??"").toString().toLowerCase().contains(q)
          || (s["offer"]??"").toString().toLowerCase().contains(q)
          || (s["about"]??"").toString().toLowerCase().contains(q);
    }).toList();
  }

  @override Widget build(BuildContext context){
    final filtered = _filtered;
    final scrH = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        title: Text(widget.title, style:const TextStyle(fontWeight:FontWeight.w800)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14,0,14,10),
            child: Container(
              decoration: BoxDecoration(color:Colors.white, borderRadius:BorderRadius.circular(12)),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v)=>setState(()=>_q=v),
                style: const TextStyle(color:kText, fontSize:14),
                decoration: InputDecoration(
                  hintText: "Search store, area, offer...",
                  hintStyle: const TextStyle(color:kMuted, fontSize:13),
                  prefixIcon: const Icon(Icons.search, color:kMuted, size:20),
                  suffixIcon: _q.isNotEmpty ? IconButton(icon:const Icon(Icons.clear,size:18,color:kMuted), onPressed:(){_searchCtrl.clear();setState(()=>_q="");}) : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical:12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
        ? Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            const Icon(Icons.search_off,color:kAccent,size:56),const SizedBox(height:12),
            Text(_q.isEmpty?"No stores yet":"No results for '$_q'",style:const TextStyle(color:kMuted,fontSize:15))]))
        : ListView.builder(
            padding:const EdgeInsets.fromLTRB(14,8,14,24),
            itemCount:filtered.length,
            itemBuilder:(_,i)=>Padding(
              padding:const EdgeInsets.only(bottom:10),
              child:GestureDetector(
                onTap:()=>Navigator.push(context,_route(StoreDetailPage(store:Map<String,dynamic>.from(filtered[i]), token:widget.token, userName:"", onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk)))))),
                child:TopStoreCard(store:filtered[i]),
              ),
            )),
    );
  }
}

// ─────────────────────── FAVORITES PAGE ───────────────────────


// ─────────────────────── NOTIFICATIONS PAGE ───────────────────────
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String,dynamic>> _notifs = [];
  bool _loading = true;

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Prefs.clearUnread(); // Mark all as read when page opens
    // Auto-purge notifications older than 30 days
    final rawList = await Prefs.getNotifications();
    final cutoff  = DateTime.now().subtract(const Duration(days: 30));
    final list = rawList.where((n) {
      final ts = n["ts"] as String? ?? "";
      if (ts.isEmpty) return true;
      try { return DateTime.parse(ts).isAfter(cutoff); } catch (_) { return true; }
    }).toList();
    if (list.length != rawList.length) {
      // Persist pruned list — re-save via saveNotification
      await Prefs.clearNotifications();
      for (final n in list.reversed) {
        await Prefs.saveNotification(
          title:    n["title"]     as String? ?? "",
          body:     n["body"]      as String? ?? "",
          imageUrl: n["image_url"] as String? ?? "",
          type:     n["type"]      as String? ?? "promo",
        );
      }
    }
    if (mounted) setState(() { _notifs = list; _loading = false; });
  }

  Future<void> _deleteNotif(int index) async {
    setState(() => _notifs.removeAt(index));
    // Rebuild stored list without deleted notification
    await Prefs.clearNotifications();
    for (final n in _notifs.reversed) {
      await Prefs.saveNotification(
        title:    n["title"]     as String? ?? "",
        body:     n["body"]      as String? ?? "",
        imageUrl: n["image_url"] as String? ?? "",
        type:     n["type"]      as String? ?? "promo",
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear All Notifications?"),
        content: const Text("This will permanently remove all your notifications."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await Prefs.clearNotifications();
      if (mounted) setState(() => _notifs = []);
    }
  }

  String _timeAgo(String isoTs) {
    try {
      final dt   = DateTime.parse(isoTs);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1)  return "just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours  < 24)  return "${diff.inHours}h ago";
      if (diff.inDays   < 7)   return "${diff.inDays}d ago";
      return "${(diff.inDays / 7).floor()}w ago";
    } catch (_) { return ""; }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        elevation: 0,
        actions: [
          if (_notifs.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text("Clear All", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _notifs.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: kMuted.withValues(alpha: .4)),
                  const SizedBox(height: 16),
                  const Text("No notifications yet", style: TextStyle(color: kMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text("You'll see deals and alerts here", style: TextStyle(color: kMuted, fontSize: 13)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, i) {
                    final n       = _notifs[i];
                    final title   = n["title"] ?? "";
                    final body    = n["body"]  ?? "";
                    final imgUrl  = n["image_url"] ?? "";
                    final ts      = n["ts"] ?? "";
                    return Dismissible(
                      key: Key(ts + title + i.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade400,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
                      ),
                      onDismissed: (_) => _deleteNotif(i),
                      child: GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (imgUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imgUrl.startsWith("data:image")
                                    ? Image.memory(base64Decode(imgUrl.split(",").last), height: 160, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true)
                                    : CachedNetworkImage(imageUrl: imgUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                                ),
                              if (imgUrl.isNotEmpty) const SizedBox(height: 14),
                              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kText)),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(body, style: const TextStyle(fontSize: 14, color: kMuted, height: 1.5)),
                              ],
                              if (ts.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(_timeAgo(ts), style: const TextStyle(fontSize: 11, color: kMuted)),
                              ],
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Close", style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                      child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Notification icon or image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52, height: 52,
                            child: imgUrl.isNotEmpty
                                ? (imgUrl.startsWith("data:image")
                                    ? Image.memory(base64Decode(imgUrl.split(",").last), fit: BoxFit.cover, gaplessPlayback: true)
                                    : CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: kLight),
                                        errorWidget: (_, __, ___) => Container(color: kLight,
                                            child: const Icon(Icons.notifications_rounded, color: kPrimary, size: 24))))
                                : Container(color: kLight,
                                    child: const Icon(Icons.notifications_rounded, color: kPrimary, size: 24)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(title, style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (ts.isNotEmpty) Text(_timeAgo(ts), style: const TextStyle(color: kMuted, fontSize: 11)),
                          ]),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(body, style: const TextStyle(color: kMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ])),
                      ]),
                      ), // close GestureDetector child Container
                    ),  // GestureDetector
                    );  // Dismissible
                  },
                ),
    );
  }
}


// ══════════════════════════════════════════════════════
// BROWSE BY CATEGORIES SECTION
// ══════════════════════════════════════════════════════
class _BrowseByCategoriesSection extends StatelessWidget {
  final List<Map<String,dynamic>> cats;
  final String token;
  final double? userLat;
  final double? userLng;
  final String? selectedCity;
  const _BrowseByCategoriesSection({required this.cats, required this.token, this.userLat, this.userLng, this.selectedCity});

  static const List<Map<String,dynamic>> _fallback = [
    {"name":"Restaurant","icon":"🍽️","subtitle":"500+ places","image_url":""},
    {"name":"Pharmacy","icon":"💊","subtitle":"Health essentials","image_url":""},
    {"name":"Fashion","icon":"👗","subtitle":"New arrivals","image_url":""},
    {"name":"Beauty","icon":"💄","subtitle":"Skincare & more","image_url":""},
    {"name":"Electronics","icon":"📱","subtitle":"Trending gadgets","image_url":""},
    {"name":"Education","icon":"📚","subtitle":"Learn & grow","image_url":""},
    {"name":"Hospital","icon":"🏥","subtitle":"Healthcare near you","image_url":""},
    {"name":"Cafe","icon":"☕","subtitle":"Coffee & more","image_url":""},
    {"name":"Grocery","icon":"🛒","subtitle":"Fresh & daily","image_url":""},
    {"name":"Fitness","icon":"🏋️","subtitle":"Stay strong","image_url":""},
    {"name":"Jewelry","icon":"💍","subtitle":"Precious finds","image_url":""},
    {"name":"Bakery","icon":"🥐","subtitle":"Fresh baked daily","image_url":""},
  ];

  static const List<List<Color>> _gradients = [
    [Color(0xFF3E5F55), Color(0xFF6b8c7e)],   // OFFRO green (restaurant)
    [Color(0xFF7a5533), Color(0xFFD4936A)],   // warm brown (grocery)
    [Color(0xFF2C4A7A), Color(0xFF5B85C8)],   // navy blue (pharmacy)
    [Color(0xFF6A3FA0), Color(0xFFB57FD4)],   // violet (electronics)
    [Color(0xFF8C3F3F), Color(0xFFD47A7A)],   // deep rose (fashion)
    [Color(0xFF2C7A5A), Color(0xFF5BBEA0)],   // teal (fitness)
    [Color(0xFF7A5A2C), Color(0xFFD4A85B)],   // amber (cafe)
    [Color(0xFF3F558C), Color(0xFF7A99D4)],   // steel blue (education)
  ];

  @override
  Widget build(BuildContext context) {
    final displayCats = cats.isNotEmpty ? cats.take(6).toList() : _fallback;  // still 6 shown in grid; View All shows rest
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: const Text("Browse by Categories",
            style: TextStyle(color: Color(0xFF2c3e35), fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        _buildMasonryGrid(context, displayCats),
      ]),
    );
  }

  Widget _buildMasonryGrid(BuildContext context, List<Map<String,dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 5,
            child: _CategoryCard(cat: items[0], gradIdx: 0, height: 200,
              onTap: () => _openCategory(context, items[0])),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Column(children: [
              if (items.length > 1) _CategoryCard(cat: items[1], gradIdx: 1, height: 95,
                onTap: () => _openCategory(context, items[1])),
              if (items.length > 2) ...[
                const SizedBox(height: 10),
                _CategoryCard(cat: items[2], gradIdx: 2, height: 95,
                  onTap: () => _openCategory(context, items[2])),
              ],
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      if (items.length > 3)
        Row(children: [
          // Slot 3
          Expanded(child: _CategoryCard(cat: items[3], gradIdx: 3, height: 110,
            onTap: () => _openCategory(context, items[3]))),
          const SizedBox(width: 10),
          // Slot 4
          if (items.length > 4)
            Expanded(child: _CategoryCard(cat: items[4], gradIdx: 4, height: 110,
              onTap: () => _openCategory(context, items[4])))
          else
            const Expanded(child: SizedBox()),
          const SizedBox(width: 10),
          // Slot 5: always yellow + button (View All)
          Expanded(child: GestureDetector(
            onTap: () {
              // Merge API cats with fallback — show everything, never just 1
              final merged = List<Map<String,dynamic>>.from(cats.isNotEmpty ? cats : _fallback);
              final existingNames = merged.map((c) => (c["name"]??'').toString().toLowerCase()).toSet();
              for (final fb in _fallback) {
                if (!existingNames.contains((fb["name"]??'').toString().toLowerCase())) {
                  merged.add(fb);
                }
              }
              Navigator.push(context, _route(_CategoryListScreen(cats: merged, token: token, userLat: userLat, userLng: userLng, selectedCity: selectedCity)));
            },
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC00),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(
                  color: const Color(0xFFFFCC00).withValues(alpha:.45),
                  blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Color(0xFF2c3e35), size: 32),
                  SizedBox(height: 4),
                  Text("View", style: TextStyle(
                    color: Color(0xFF2c3e35),
                    fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          )),
        ]),
    ]);
  }

  void _openCategory(BuildContext context, Map<String,dynamic> cat) {
    final catName = cat["name"].toString();
    Navigator.push(context, _route(_CategoryStoresScreen(
      key: ValueKey(catName),
      categoryName: catName, token: token,
      userLat: userLat, userLng: userLng,
      selectedCity: selectedCity)));
  }
}

class _CategoryCard extends StatelessWidget {
  final Map<String,dynamic> cat;
  final int gradIdx;
  final double height;
  final VoidCallback onTap;
  const _CategoryCard({required this.cat, required this.gradIdx, required this.height, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Resolve category image — supports both HTTP URLs and base64 data URIs
    String _rawImg = (cat["image_url"] ?? cat["image"] ?? cat["img"] ?? cat["photo"] ?? "").toString().trim();
    // Resolve relative URLs to absolute
    if (_rawImg.isNotEmpty && _rawImg.startsWith("/")) {
      _rawImg = "https://offro-backend-production.up.railway.app$_rawImg";
    }
    final bool _isBase64 = _rawImg.startsWith("data:image");
    final bool _isHttp   = _rawImg.startsWith("http://") || _rawImg.startsWith("https://");
    final imgUrl     = _isHttp ? _rawImg : "";
    // Decode base64 for MemoryImage fallback (when Cloudinary not configured)
    Uint8List? _imgBytes;
    if (_isBase64) {
      try {
        final commaIdx = _rawImg.indexOf(",");
        if (commaIdx >= 0) {
          _imgBytes = base64Decode(_rawImg.substring(commaIdx + 1));
        }
      } catch (_) { _imgBytes = null; }
    }
    final name   = (cat["name"] ?? "").toString();
    final sub    = (cat["subtitle"] ?? "").toString();
    final icon   = (cat["icon"] ?? "🏪").toString();
    final grad   = _BrowseByCategoriesSection._gradients[gradIdx % _BrowseByCategoriesSection._gradients.length];

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: grad,
            ),
          ),
          child: Stack(fit: StackFit.expand, children: [
            // Real category image — HTTP URL or base64 decoded MemoryImage
            if (imgUrl.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imgUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  memCacheWidth: 400,
                  placeholder: (_, __) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: grad),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: grad),
                    ),
                  ),
                ),
              )
            else if (_imgBytes != null)
              Positioned.fill(
                child: Image.memory(
                  _imgBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            // Gradient overlay — text readability on rich colored bg
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .10),
                  Colors.black.withValues(alpha: .50),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ))),
            // Subtle glossy shine (soft for pastel backgrounds)
            Positioned(top: 0, left: 0, right: 0, child: Container(
              height: height * 0.35,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: .30), Colors.transparent],
                ),
              ),
            )),
            // Bottom text content
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (height >= 150) ...[
                  Text(icon, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 4),
                ],
                Text(name,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black54)]),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                if (sub.isNotEmpty)
                  Text(sub,
                    style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 10,
                      shadows: const [Shadow(blurRadius: 3, color: Colors.black45)]),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CategoryStoresScreen extends StatefulWidget {
  final String categoryName;
  final String token;
  final double? userLat;
  final double? userLng;
  final String? selectedCity;
  const _CategoryStoresScreen({super.key, required this.categoryName, required this.token, this.userLat, this.userLng, this.selectedCity});
  @override State<_CategoryStoresScreen> createState() => _CategoryStoresScreenState();
}
class _CategoryStoresScreenState extends State<_CategoryStoresScreen> {
  List<Map<String,dynamic>> _stores = [];
  bool _loading = true;
  String _q = "";

  @override void initState() { super.initState(); _load(); }

  @override void didUpdateWidget(_CategoryStoresScreen old) {
    super.didUpdateWidget(old);
    if (old.categoryName != widget.categoryName) {
      setState(() { _stores = []; _loading = true; _q = ""; });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      // Clear category cache so fresh fetch always goes to backend
      Api.clearCategoryCache(widget.categoryName);
      // FIX ISSUE-3: pass city so backend filters by selected city
      final all = await Api.fetchStores(category: widget.categoryName, city: widget.selectedCity);
      // Use backend-filtered list directly (backend already applies category regex filter)
      // Client-side re-filter is removed — it was incorrectly dropping stores
      // where category had slight case/spacing differences vs. the chip label
      final filtered = List<Map<String,dynamic>>.from(all);
      // Compute distance_km client-side if GPS is available (same as home screen)
      final result = filtered.map((s) {
        final m = Map<String,dynamic>.from(s);
        if (widget.userLat != null && widget.userLng != null && m["distance_km"] == null) {
          final lat = (m["latitude"] as num?)?.toDouble() ?? (m["lat"] as num?)?.toDouble();
          final lng = (m["longitude"] as num?)?.toDouble() ?? (m["lng"] as num?)?.toDouble();
          if (lat != null && lng != null) {
            final dlat = (widget.userLat! - lat) * 0.01745329251;
            final dlng = (widget.userLng! - lng) * 0.01745329251;
            final a = (dlat/2)*(dlat/2) + (dlng/2)*(dlng/2) * 0.99664719 * 0.99664719;
            final dist = 6371.0 * 2 * 0.0174533 * (a < 1 ? a : 1);
            m["distance_km"] = double.parse(dist.toStringAsFixed(1));
          }
        }
        return m;
      }).toList();
      if (mounted) setState(() { _stores = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String,dynamic>> get _filtered {
    if (_q.isEmpty) return _stores;
    final q = _q.toLowerCase();
    return _stores.where((s) =>
      (s["store_name"] ?? "").toString().toLowerCase().contains(q) ||
      (s["area"] ?? "").toString().toLowerCase().contains(q)
    ).toList();
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        title: Text(widget.categoryName,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
        elevation: 0,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: "Search ${widget.categoryName} stores...",
              hintStyle: const TextStyle(color: kMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: kPrimary, size: 20),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
            ),
          ),
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : _filtered.isEmpty
              ? Center(child: Text("No ${widget.categoryName} stores found",
                  style: const TextStyle(color: kMuted, fontSize: 14)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => StoreDetailPage(
                        store: Map<String,dynamic>.from(_filtered[i]),
                        token: widget.token,
                        userName: "",
                        onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk))),
                      ))),
                    child: TopStoreCard(store: _filtered[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}
class _CategoryListScreen extends StatefulWidget {
  final List<Map<String,dynamic>> cats;
  final String token;
  final double? userLat;
  final double? userLng;
  final String? selectedCity;
  const _CategoryListScreen({required this.cats, required this.token, this.userLat, this.userLng, this.selectedCity});
  @override State<_CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<_CategoryListScreen> {
  String _q = "";

  List<Map<String,dynamic>> get _filtered {
    if (_q.isEmpty) return widget.cats;
    final q = _q.toLowerCase();
    return widget.cats.where((c) =>
      (c["name"] ?? "").toString().toLowerCase().contains(q)).toList();
  }

  @override Widget build(BuildContext context) {
    final cats = _filtered;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text("Categories",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kText)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0,2))],
            ),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(fontSize: 14, color: kText),
              decoration: const InputDecoration(
                hintText: "Search categories...",
                hintStyle: TextStyle(color: kMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: kMuted, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
        // Pinterest grid
        Expanded(
          child: cats.isEmpty
            ? const Center(child: Text("No categories found", style: TextStyle(color: kMuted)))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                physics: const BouncingScrollPhysics(),
                child: _PinterestCategoryGrid(cats: cats, token: widget.token, userLat: widget.userLat, userLng: widget.userLng, selectedCity: widget.selectedCity),
              ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Pinterest-style dynamic tile grid — matches the design mockup
// ─────────────────────────────────────────────────────────────────
class _PinterestCategoryGrid extends StatelessWidget {
  final List<Map<String,dynamic>> cats;
  final String token;
  final double? userLat;
  final double? userLng;
  final String? selectedCity;
  const _PinterestCategoryGrid({required this.cats, required this.token, this.userLat, this.userLng, this.selectedCity});

  void _open(BuildContext ctx, Map<String,dynamic> cat) {
    final name = cat["name"].toString();
    Navigator.push(ctx, _route(_CategoryStoresScreen(
      key: ValueKey(name), categoryName: name, token: token,
      userLat: userLat, userLng: userLng,
      selectedCity: selectedCity)));
  }

  @override Widget build(BuildContext context) {
    if (cats.isEmpty) return const SizedBox.shrink();
    final List<Widget> rows = [];

    // ── Row 1: hero left (tall) + 2 stacked right ──
    // Matches mockup: Restaurant big | Grocery + Electronics stacked
    if (cats.length >= 1) {
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Large featured hero card
          Expanded(flex: 52, child: _PinCard(
            cat: cats[0], gradIdx: 0, minHeight: 200,
            onTap: () => _open(context, cats[0]),
          )),
          const SizedBox(width: 10),
          // Two stacked smaller cards
          Expanded(flex: 40, child: Column(children: [
            if (cats.length > 1) _PinCard(
              cat: cats[1], gradIdx: 1, minHeight: 95,
              onTap: () => _open(context, cats[1]),
            ),
            if (cats.length > 2) ...[
              const SizedBox(height: 10),
              _PinCard(
                cat: cats[2], gradIdx: 2, minHeight: 95,
                onTap: () => _open(context, cats[2]),
              ),
            ],
          ])),
        ]),
      ));
    }

    // ── Row 2: 2 equal medium cards (Pharmacy + Fashion) ──
    if (cats.length > 3) {
      rows.add(const SizedBox(height: 10));
      rows.add(Row(children: [
        Expanded(child: _PinCard(cat: cats[3], gradIdx: 3, minHeight: 150, onTap: () => _open(context, cats[3]))),
        const SizedBox(width: 10),
        if (cats.length > 4)
          Expanded(child: _PinCard(cat: cats[4], gradIdx: 4, minHeight: 150, onTap: () => _open(context, cats[4]))),
      ]));
    }

    // ── Row 3: wide bakery card (full-width-ish) + taller hospital ──
    if (cats.length > 5) {
      rows.add(const SizedBox(height: 10));
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Wide horizontal bakery card (left 57%)
          Expanded(flex: 57, child: _PinCard(
            cat: cats[5], gradIdx: 5, minHeight: 140,
            curvedShape: true,
            onTap: () => _open(context, cats[5]),
          )),
          const SizedBox(width: 10),
          // Taller hospital/care card (right 40%)
          if (cats.length > 6)
            Expanded(flex: 40, child: _PinCard(
              cat: cats[6], gradIdx: 6, minHeight: 140,
              onTap: () => _open(context, cats[6]),
            )),
        ]),
      ));
    }

    // ── Row 4: 4-card row (Education, Fitness, Automobile, Travel) ──
    if (cats.length > 7) {
      rows.add(const SizedBox(height: 10));
      final row4 = cats.sublist(7, cats.length < 11 ? cats.length : 11);
      rows.add(Row(children: [
        for (int i = 0; i < row4.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _PinCard(
            cat: row4[i], gradIdx: 7 + i, minHeight: 130,
            compact: true,
            onTap: () => _open(context, row4[i]),
          )),
        ],
      ]));
    }

    // ── Row 5: full-width banner (Hotels / remaining cats) ──
    if (cats.length > 11) {
      final remaining = cats.sublist(11);
      // First one as full-width banner
      rows.add(const SizedBox(height: 10));
      rows.add(_PinCard(
        cat: remaining[0], gradIdx: 11, minHeight: 100,
        fullWidth: true,
        onTap: () => _open(context, remaining[0]),
      ));

      // Any further cats in pairs
      int idx = 1;
      while (idx < remaining.length) {
        rows.add(const SizedBox(height: 10));
        final pair = remaining.sublist(idx, idx + 2 <= remaining.length ? idx + 2 : remaining.length);
        rows.add(Row(children: [
          for (int i = 0; i < pair.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _PinCard(
              cat: pair[i], gradIdx: 12 + idx + i, minHeight: 130,
              onTap: () => _open(context, pair[i]),
            )),
          ],
          if (pair.length == 1) const Expanded(child: SizedBox.shrink()),
        ]));
        idx += 2;
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

// ─── Single Pinterest category card ───────────────────────────────────────────
class _PinCard extends StatelessWidget {
  final Map<String,dynamic> cat;
  final int gradIdx;
  final double minHeight;
  final VoidCallback onTap;
  final bool curvedShape;   // asymmetric/wave-like border radius
  final bool compact;       // 4-up small card — icon only at top
  final bool fullWidth;     // full-width banner card

  const _PinCard({
    required this.cat,
    required this.gradIdx,
    required this.minHeight,
    required this.onTap,
    this.curvedShape = false,
    this.compact = false,
    this.fullWidth = false,
  });

  static const List<List<Color>> _gradients = [
    [Color(0xFF3E5F55), Color(0xFF6b8c7e)],   // OFFRO green
    [Color(0xFF7a5533), Color(0xFFD4936A)],   // warm brown
    [Color(0xFF2C4A7A), Color(0xFF5B85C8)],   // navy
    [Color(0xFF6A3FA0), Color(0xFFB57FD4)],   // violet
    [Color(0xFF8C3F3F), Color(0xFFD47A7A)],   // rose
    [Color(0xFF2C7A5A), Color(0xFF5BBEA0)],   // teal
    [Color(0xFF7A5A2C), Color(0xFFD4A85B)],   // amber
    [Color(0xFF3F558C), Color(0xFF7A99D4)],   // steel blue
    [Color(0xFF5A3F8C), Color(0xFF9B7FD4)],   // indigo
    [Color(0xFF8C5A2C), Color(0xFFD4A068)],   // caramel
    [Color(0xFF2C5A7A), Color(0xFF5B9EC8)],   // sky blue
    [Color(0xFF7A3F5A), Color(0xFFD47AA8)],   // mauve
    [Color(0xFF3F7A5A), Color(0xFF7AD4A8)],   // mint green
  ];

  BorderRadius get _borderRadius {
    if (fullWidth) return BorderRadius.circular(24);
    if (curvedShape) {
      // Bakery-style: more rounded on top-left and bottom-right
      return const BorderRadius.only(
        topLeft:     Radius.circular(32),
        topRight:    Radius.circular(20),
        bottomLeft:  Radius.circular(20),
        bottomRight: Radius.circular(32),
      );
    }
    if (compact) return BorderRadius.circular(20);
    return BorderRadius.circular(28);
  }

  @override Widget build(BuildContext context) {
    // ── Image resolution ──
    String rawImg = (cat["image_url"] ?? cat["image"] ?? cat["img"] ?? cat["photo"] ?? "").toString().trim();
    if (rawImg.isNotEmpty && rawImg.startsWith("/")) {
      rawImg = "https://offro-backend-production.up.railway.app$rawImg";
    }
    final bool isBase64 = rawImg.startsWith("data:image");
    final bool isHttp   = rawImg.startsWith("http://") || rawImg.startsWith("https://");
    Uint8List? imgBytes;
    if (isBase64) {
      try {
        final ci = rawImg.indexOf(",");
        if (ci >= 0) imgBytes = base64Decode(rawImg.substring(ci + 1));
      } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }

    final name  = (cat["name"] ?? "").toString();
    final sub   = (cat["subtitle"] ?? "").toString();
    final icon  = (cat["icon"] ?? "🏪").toString();
    final grad  = _gradients[gradIdx % _gradients.length];

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: _borderRadius,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad),
          ),
          child: Stack(fit: StackFit.expand, children: [
            // ── Full bleed image ──
            if (isHttp)
              Positioned.fill(child: CachedNetworkImage(
                imageUrl: rawImg, fit: BoxFit.cover,
                memCacheWidth: 500,
                placeholder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad))),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ))
            else if (imgBytes != null)
              Positioned.fill(child: Image.memory(imgBytes!, fit: BoxFit.cover)),

            // ── Gradient overlay — readability on rich colored bg ──
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .10),
                  Colors.black.withValues(alpha: .52),
                ],
              ),
            ))),

            // ── Top-left: floating icon bubble ──
            if (!compact)
              Positioned(top: 12, left: 12,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .35),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .25), width: 1),
                  ),
                  child: Center(child: Text(icon,
                    style: const TextStyle(fontSize: 16), textAlign: TextAlign.center)),
                ),
              )
            else
              // compact: small icon no bubble
              Positioned(top: 10, left: 10,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .30),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(icon,
                    style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                ),
              ),

            // ── Bottom text ribbon ──
            Positioned(left: 0, right: 0, bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 8 : 12,
                  0,
                  compact ? 8 : 12,
                  compact ? 10 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 11 : (fullWidth ? 16 : 13),
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: 0.1,
                        shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                      )),
                    if (sub.isNotEmpty && !compact) ...[
                      const SizedBox(height: 3),
                      Text(sub,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .85),
                          fontSize: 10, fontWeight: FontWeight.w500,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 6)])),
                    ],
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════
class _SpecialFindsSection extends StatelessWidget {
  final List<Map<String,dynamic>> stores;
  final String token;
  const _SpecialFindsSection({required this.stores, required this.token});

  static const List<Map<String,dynamic>> _defs = [
    {"label":"People Love",       "filter":"popular",   "fallback1":0xFFFF6B6B,"fallback2":0xFFFF8E53},
    {"label":"Late Night Spots",  "filter":"latenight", "fallback1":0xFF1a2550,"fallback2":0xFF2C3E7A},
    {"label":"Just Opened",       "filter":"new",       "fallback1":0xFF2E7D5E,"fallback2":0xFF1a5040},
    {"label":"Popular This Week", "filter":"trending",  "fallback1":0xFFE67E22,"fallback2":0xFFD35400},
  ];

  List<Map<String,dynamic>> _ranked(String type) {
    if (stores.isEmpty) return [];
    final list = List<Map<String,dynamic>>.from(stores);
    switch (type) {
      case "popular":
        list.sort((a, b) {
          final pa = (a["is_popular"] == true) ? 3 : (a["favorite_count"] ?? 0) > 0 ? 2 : 1;
          final pb = (b["is_popular"] == true) ? 3 : (b["favorite_count"] ?? 0) > 0 ? 2 : 1;
          if (pa != pb) return pb.compareTo(pa);
          final fc = ((b["favorite_count"] ?? 0) as num).compareTo((a["favorite_count"] ?? 0) as num);
          if (fc != 0) return fc;
          return ((b["rating"] ?? 0) as num).compareTo((a["rating"] ?? 0) as num);
        });
        return list.take(5).toList();
      case "latenight":
        final lateKeywords = ["late night","late","night","24","open late","night service"];
        final late = list.where((s) {
          if (s["late_night"] == true) return true;
          final tags = ((s["tags"] ?? []) as List).map((t) => t.toString().toLowerCase());
          return tags.any((t) => lateKeywords.any((k) => t.contains(k)));
        }).toList();
        if (late.isNotEmpty) {
          late.sort((a,b) => ((b["rating"]??0) as num).compareTo((a["rating"]??0) as num));
          return late.take(5).toList();
        }
        return [];
      case "new":
        final now = DateTime.now();
        final newS = list.where((s) {
          final tags = ((s["tags"] ?? []) as List).map((t) => t.toString().toLowerCase());
          if (tags.any((t) => ["new","just opened","newly opened","grand opening"].any((k) => t.contains(k)))) return true;
          final cs = s["created_at"]?.toString() ?? "";
          if (cs.isNotEmpty) {
            try { final dt = DateTime.tryParse(cs); if (dt != null && now.difference(dt).inDays <= 14) return true; } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
          }
          return false;
        }).toList();
        if (newS.isNotEmpty) {
          newS.sort((a,b) => ((b["favorite_count"]??0) as num).compareTo((a["favorite_count"]??0) as num));
          return newS.take(5).toList();
        }
        final withDate = list.where((s) => (s["created_at"]?.toString() ?? "").isNotEmpty).toList();
        withDate.sort((a,b) => (b["created_at"]?.toString() ?? "").compareTo(a["created_at"]?.toString() ?? ""));
        return withDate.isNotEmpty ? withDate.take(3).toList() : list.take(3).toList();
      case "trending":
        list.sort((a, b) {
          final ta = (a["is_trending"] == true) ? 1 : 0;
          final tb = (b["is_trending"] == true) ? 1 : 0;
          if (ta != tb) return tb.compareTo(ta);
          final vc = ((b["view_count"] ?? 0) as num).compareTo((a["view_count"] ?? 0) as num);
          if (vc != 0) return vc;
          final dc = ((b["deal_count"] ?? 0) as num).compareTo((a["deal_count"] ?? 0) as num);
          if (dc != 0) return dc;
          return ((b["rating"] ?? 0) as num).compareTo((a["rating"] ?? 0) as num);
        });
        return list.take(5).toList();
      default:
        return list.take(5).toList();
    }
  }

  String? _storeImg(Map<String,dynamic> s) {
    for (final k in ["image_url","image_thumb","image","image2"]) {
      final v = s[k]?.toString() ?? "";
      if (v.isNotEmpty && v.startsWith("http")) return v;
    }
    final imgs = s["images"];
    if (imgs is List && imgs.isNotEmpty) {
      final v = imgs.first.toString();
      if (v.startsWith("http")) return v;
    }
    return null;
  }

  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text("Special Finds",
              style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
            SizedBox(height: 2),
            Text("Handpicked just for you",
              style: TextStyle(color: kMuted, fontSize: 12)),
          ]),
        ),
        SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _defs.length,
            itemBuilder: (_, i) {
              final def          = _defs[i];
              final ranked       = _ranked(def["filter"] as String);
              final imgUrl       = ranked.isNotEmpty ? _storeImg(ranked[0]) : null;
              final storeCount   = ranked.length;
              final color1       = Color(def["fallback1"] as int);
              final color2       = Color(def["fallback2"] as int);
              final isComingSoon = def["filter"] == "latenight" && ranked.isEmpty;
              final label        = def["label"] as String;

              return GestureDetector(
                onTap: () {
                  if (ranked.isEmpty) return;
                  Navigator.push(context, _route(_SpecialCategoryScreen(
                    label: label,
                    emoji: "",
                    stores: ranked,
                    token: token,
                    color1: color1,
                    color2: color2,
                  )));
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    width: 160,
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [color1, color2]),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: .14),
                          blurRadius: 14, offset: const Offset(0, 4))],
                      ),
                      child: Stack(fit: StackFit.expand, children: [
                        // ── Background image (always shown, even for Coming Soon) ──
                        if (imgUrl != null)
                          Positioned.fill(child: CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              decoration: BoxDecoration(gradient: LinearGradient(
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: [color1, color2]))),
                            errorWidget: (_, __, ___) => Container(
                              decoration: BoxDecoration(gradient: LinearGradient(
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: [color1, color2]))),
                          ))
                        else
                          // No image yet — gradient background
                          Positioned.fill(child: Container(
                            decoration: BoxDecoration(gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [color1, color2])),
                          )),

                        // ── Transparent ribbon at bottom ──
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .58),
                              borderRadius: const BorderRadius.only(
                                bottomLeft:  Radius.circular(22),
                                bottomRight: Radius.circular(22),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  )),
                                const SizedBox(height: 3),
                                Text(
                                  isComingSoon
                                    ? "Coming Soon"
                                    : "$storeCount Store${storeCount == 1 ? "" : "s"}",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .80),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  )),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _PopularAreasSection extends StatelessWidget {
  final List<Map<String,dynamic>> stores;
  final String token;
  const _PopularAreasSection({required this.stores, required this.token});

  // ── Build area list from store.area field ─────────────────────────
  // All keys where a store image might live
  static const _imgKeys = [
    "image_url","image_thumb","image","image2","logo_url","logo","img","photo",
    "_thumb","banner","cover","thumbnail","store_image","store_image2",
  ];

  String? _pickImg(Map<String,dynamic> store) {
    bool _validImg(String v) =>
        v.isNotEmpty && (v.startsWith("http") || v.startsWith("data:image"));
    for (final k in _imgKeys) {
      final v = store[k]?.toString() ?? "";
      if (_validImg(v)) return v;
    }
    // Try images array
    final imgs = store["images"];
    if (imgs is List) {
      for (final img in imgs) {
        final v = img?.toString() ?? "";
        if (_validImg(v)) return v;
      }
    }
    return null;
  }

  List<Map<String,dynamic>> _buildAreas() {
    final Map<String, List<Map<String,dynamic>>> grouped = {};
    for (final s in stores) {
      final area = (s["area"] ?? "").toString().trim();
      if (area.isEmpty || area == "null") continue;
      grouped.putIfAbsent(area, () => []).add(s);
    }
    if (grouped.isEmpty) return [];

    return grouped.entries.map((e) {
      final areaStores = e.value;
      // Priority: most favorited → highest rated → most viewed → any with image
      String? imgUrl;

      // Sort by favorites first, then rating, then views
      final sorted = List<Map<String,dynamic>>.from(areaStores)
        ..sort((a, b) {
          final fa = (a["favorite_count"] ?? 0) as num;
          final fb = (b["favorite_count"] ?? 0) as num;
          if (fb != fa) return fb.compareTo(fa);
          final ra = (a["rating"] ?? a["admin_rating"] ?? 0) as num;
          final rb = (b["rating"] ?? b["admin_rating"] ?? 0) as num;
          if (rb != ra) return rb.compareTo(ra);
          final va = (a["view_count"] ?? 0) as num;
          final vb = (b["view_count"] ?? 0) as num;
          return vb.compareTo(va);
        });

      // Try priority-sorted stores first
      for (final s in sorted) {
        imgUrl = _pickImg(s);
        if (imgUrl != null) break;
      }
      // Last resort: iterate ALL stores in area
      if (imgUrl == null) {
        for (final s in areaStores) {
          imgUrl = _pickImg(s);
          if (imgUrl != null) break;
        }
      }

      return {
        "name":      e.key,
        "count":     e.value.length,
        "image_url": imgUrl ?? "",
        "stores":    areaStores,
        "subtitle":  "",
      };
    }).toList()
      ..sort((a,b) => (b["count"] as int).compareTo(a["count"] as int));
  }

  @override Widget build(BuildContext context) {
    final areas = _buildAreas();
    if (areas.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header with "See all areas →"
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text("Popular Areas",
                  style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text("Discover local neighbourhoods",
                  style: TextStyle(color: kMuted, fontSize: 12)),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(context, _route(_AllAreasScreen(
                  stores: stores, token: token))),
                child: const Text("See all areas →",
                  style: TextStyle(
                    color: kPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        // Horizontal scroll — identical structure to Special Finds
        SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: areas.length > 8 ? 8 : areas.length,
            itemBuilder: (_, i) {
              final area = areas[i];
              final _areaImg = area["image_url"] as String;
              final _areaGrad = _AreaBg._fallbackGrads[
                (area["name"] as String).isEmpty ? 0
                : (area["name"] as String).codeUnitAt(0) % _AreaBg._fallbackGrads.length
              ];
              return GestureDetector(
                onTap: () => Navigator.push(context, _route(_AreaDetailScreen(
                  areaName:  area["name"] as String,
                  stores:    List<Map<String,dynamic>>.from(area["stores"] as List),
                  token:     token,
                ))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    width: 160,
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: _areaGrad),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: .14),
                          blurRadius: 14, offset: const Offset(0, 4))],
                      ),
                      child: Stack(fit: StackFit.expand, children: [
                        // ── Full-bleed background image (same as SF) ──
                        if (_areaImg.isNotEmpty)
                          Positioned.fill(child: CachedNetworkImage(
                            imageUrl: _areaImg,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              decoration: BoxDecoration(gradient: LinearGradient(
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: _areaGrad))),
                            errorWidget: (_, __, ___) => Container(
                              decoration: BoxDecoration(gradient: LinearGradient(
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: _areaGrad))),
                          ))
                        else
                          Positioned.fill(child: Container(
                            decoration: BoxDecoration(gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: _areaGrad)),
                            child: Center(child: Text(
                              (area["name"] as String).trim().split(" ").take(2)
                                .map((w) => w.isEmpty ? "" : w[0].toUpperCase()).join(),
                              style: const TextStyle(color: Colors.white38, fontSize: 42, fontWeight: FontWeight.w900),
                            )),
                          )),

                        // ── Ribbon — exact SF style ──
                        Positioned(
                          left: 0, right: 0, bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .58),
                              borderRadius: const BorderRadius.only(
                                bottomLeft:  Radius.circular(22),
                                bottomRight: Radius.circular(22),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(area["name"] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  )),
                                const SizedBox(height: 3),
                                Text(
                                  "${area["count"]} Store${(area["count"] as int) == 1 ? "" : "s"}",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .80),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  )),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// Background image widget for area card
class _AreaBg extends StatelessWidget {
  final String imgUrl;
  final String areaName;
  const _AreaBg({required this.imgUrl, this.areaName = ""});

  static const List<List<Color>> _fallbackGrads = [
    [Color(0xFF1a3329), Color(0xFF3E5F55)],
    [Color(0xFF1a2535), Color(0xFF2C4A7A)],
    [Color(0xFF3b2a1a), Color(0xFF7a5533)],
    [Color(0xFF2a1a35), Color(0xFF6A3FA0)],
    [Color(0xFF1a3340), Color(0xFF2C7A8C)],
    [Color(0xFF3E2020), Color(0xFF8C3F3F)],
  ];

  @override Widget build(BuildContext context) {
    if (imgUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imgUrl, fit: BoxFit.cover,
        width: double.infinity, height: double.infinity,
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final grad = _fallbackGrads[(areaName.isEmpty ? 0 : areaName.codeUnitAt(0)) % _fallbackGrads.length];
    final initials = areaName.trim().isEmpty ? "?"
        : areaName.trim().split(" ").take(2).map((w) => w.isEmpty ? "" : w[0].toUpperCase()).join();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad)),
      child: Center(child: Text(initials,
        style: const TextStyle(color: Colors.white38, fontSize: 42, fontWeight: FontWeight.w900))),
    );
  }
}



// ─────────────────────── ALL DEALS SCREEN ───────────────────────
class _AllDealsScreen extends StatefulWidget {
  final String token;
  final String city;
  const _AllDealsScreen({required this.token, required this.city});
  @override State<_AllDealsScreen> createState() => _AllDealsScreenState();
}

class _AllDealsScreenState extends State<_AllDealsScreen> {
  List<Map<String,dynamic>> _deals = [];
  bool _loading = true;
  String _q = "";

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      // Try city-filtered first, fall back to all deals if empty
      dynamic raw = await Api.get("/deals/all?city=" + Uri.encodeComponent(widget.city));
      List<Map<String,dynamic>> list = (raw is List)
          ? List<Map<String,dynamic>>.from(raw.map((e) => Map<String,dynamic>.from(e as Map)))
          : <Map<String,dynamic>>[];
      // If city returned nothing, fetch all deals (city might not match exactly)
      if (list.isEmpty && widget.city.isNotEmpty) {
        raw = await Api.get("/deals/all");
        list = (raw is List)
            ? List<Map<String,dynamic>>.from(raw.map((e) => Map<String,dynamic>.from(e as Map)))
            : <Map<String,dynamic>>[];
      }
      if (mounted) setState(() { _deals = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String,dynamic>> get _filtered {
    if (_q.trim().isEmpty) return _deals;
    final q = _q.toLowerCase();
    return _deals.where((d) =>
      (d["title"]      ?? "").toString().toLowerCase().contains(q) ||
      (d["store_name"] ?? "").toString().toLowerCase().contains(q) ||
      (d["store_area"] ?? "").toString().toLowerCase().contains(q)
    ).toList();
  }

  // Parse validity date string to DateTime
  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    return null;
  }

  String _fmtDate(String s) {
    // Guard: reject raw Dart template strings stored accidentally in DB
    if (s.contains('dt.day') || s.contains('months[') || (s.contains('{') && s.contains('}'))) return "";
    final dt = _parseDate(s);
    if (dt == null) return "";
    final months = ["Jan","Feb","Mar","Apr","May","Jun",
                    "Jul","Aug","Sep","Oct","Nov","Dec"];
    return "\${dt.day} \${months[dt.month-1]} \${dt.year}";
  }

  bool _isExpired(String s) {
    final dt = _parseDate(s);
    if (dt == null) return false;
    return DateTime.now().isAfter(dt.add(const Duration(days: 1)));
  }

  @override Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Hot Deals",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: kText)),
            if (widget.city.isNotEmpty)
              Text(widget.city,
                style: const TextStyle(fontSize: 11, color: kMuted, fontWeight: FontWeight.w400)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(fontSize: 14, color: kText),
              decoration: const InputDecoration(
                hintText: "Search deals...",
                hintStyle: TextStyle(color: kMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: kMuted, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
        // Count label
        if (!_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "${items.length} active deal${items.length == 1 ? '' : 's'}",
                style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        // List
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : items.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_offer_outlined, size: 56, color: kAccent),
                    const SizedBox(height: 12),
                    Text(_q.isEmpty ? "No active deals right now" : "No deals match your search",
                      style: const TextStyle(color: kMuted, fontSize: 15)),
                  ],
                ))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 32),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final d = items[i];
                    final imgUrl  = (d["image_url"]  ?? "").toString();
                    final discount= (d["discount"]   ?? "").toString();
                    final endDate = (d["end_date"]   ?? "").toString();
                    final storeName = (d["store_name"] ?? "").toString();
                    final storeArea = (d["store_area"] ?? "").toString();
                    final title   = (d["title"]      ?? "").toString();
                    final storeId = (d["store_id"]   ?? "").toString();
                    final expired = _isExpired(endDate);
                    return GestureDetector(
                      onTap: () {
                        // Navigate to the store's detail page
                        final store = <String,dynamic>{
                          "_id":        storeId,
                          "store_name": storeName,
                          "area":       storeArea,
                          "city":       (d["store_city"] ?? "").toString(),
                          "address":    (d["store_address"] ?? "").toString(),
                          "phone":      (d["store_phone"] ?? "").toString(),
                          "image_url":  imgUrl,
                          "category":   (d["category"] ?? "").toString(),
                        };
                        Navigator.push(ctx, _route(
                          StoreDetailPage(store: store, token: widget.token, userName: "", onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk))))));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: expired ? const Color(0xFFE0E0E0) : kBorder),
                          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
                        ),
                        child: Row(children: [
                          // Store image
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                            child: Stack(children: [
                              imgUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imgUrl, width: 88, height: 88, fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 88, height: 88, color: kAccent,
                                      child: const Icon(Icons.store_rounded, color: kPrimary, size: 28)))
                                : Container(width: 88, height: 88, color: kAccent,
                                    child: const Icon(Icons.store_rounded, color: kPrimary, size: 28)),
                              if (expired)
                                Container(width: 88, height: 88, color: Colors.black38),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              // Discount badge
                              if (discount.isNotEmpty && !expired)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 5),
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: kPrimary,
                                    borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                    discount.contains('%') ? discount : "${discount}% OFF",
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              if (expired)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 5),
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(20)),
                                  child: const Text("Expired",
                                    style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              // Deal title
                              Text(title,
                                style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: expired ? kMuted : kText),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              // Store name
                              Row(children: [
                                const Icon(Icons.store_rounded, size: 12, color: kMuted),
                                const SizedBox(width: 4),
                                Expanded(child: Text(storeName,
                                  style: const TextStyle(fontSize: 12, color: kMuted),
                                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ]),
                              if (storeArea.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.location_on_rounded, size: 12, color: kMuted),
                                  const SizedBox(width: 4),
                                  Text(storeArea,
                                    style: const TextStyle(fontSize: 11, color: kMuted)),
                                ]),
                              ],
                              // Validity
                              if (endDate.isNotEmpty && !endDate.contains('dt.day') && !endDate.contains(r'\${')) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.calendar_today_rounded, size: 11,
                                    color: expired ? Colors.red : kMuted),
                                  const SizedBox(width: 4),
                                  Text("Valid till ${_fmtDate(endDate)}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: expired ? Colors.red : kMuted,
                                      fontWeight: expired ? FontWeight.w600 : FontWeight.normal)),
                                ]),
                              ],
                            ]),
                          )),
                          // Chevron
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: expired ? const Color(0xFFCCCCCC) : kPrimary),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}


// ── All Areas Screen ──────────────────────────────────────────────
class _AllAreasScreen extends StatefulWidget {
  final List<Map<String,dynamic>> stores;
  final String token;
  const _AllAreasScreen({required this.stores, required this.token});
  @override State<_AllAreasScreen> createState() => _AllAreasScreenState();
}

class _AllAreasScreenState extends State<_AllAreasScreen> {
  String _q = "";

  static const _imgKeys = [
    "image_url","image_thumb","image","image2","logo_url","logo","img","photo",
    "_thumb","banner","cover","thumbnail","store_image","store_image2",
  ];

  String? _pickImg(Map<String,dynamic> store) {
    for (final k in _imgKeys) {
      final v = store[k]?.toString() ?? "";
      if (v.isNotEmpty && v.startsWith("http")) return v;
    }
    final imgs = store["images"];
    if (imgs is List) {
      for (final img in imgs) {
        final v = img?.toString() ?? "";
        if (v.startsWith("http")) return v;
      }
    }
    return null;
  }

  List<Map<String,dynamic>> _buildAreas() {
    final Map<String, List<Map<String,dynamic>>> grouped = {};
    for (final s in widget.stores) {
      final area = (s["area"] ?? "").toString().trim();
      if (area.isEmpty || area == "null") continue;
      grouped.putIfAbsent(area, () => []).add(s);
    }
    return grouped.entries.map((e) {
      String? imgUrl;
      final sorted = List<Map<String,dynamic>>.from(e.value)
        ..sort((a, b) {
          final fa = (a["favorite_count"] ?? 0) as num;
          final fb = (b["favorite_count"] ?? 0) as num;
          if (fb != fa) return fb.compareTo(fa);
          final ra = (a["rating"] ?? a["admin_rating"] ?? 0) as num;
          final rb = (b["rating"] ?? b["admin_rating"] ?? 0) as num;
          return rb.compareTo(ra);
        });
      for (final s in sorted) {
        imgUrl = _pickImg(s);
        if (imgUrl != null) break;
      }
      if (imgUrl == null) {
        for (final s in e.value) {
          imgUrl = _pickImg(s);
          if (imgUrl != null) break;
        }
      }
      return {
        "name": e.key, "count": e.value.length,
        "image_url": imgUrl ?? "", "stores": e.value,
      };
    }).toList()
      ..sort((a,b) => (b["count"] as int).compareTo(a["count"] as int));
  }

  @override Widget build(BuildContext context) {
    final allAreas = _buildAreas();
    final filtered = _q.isEmpty ? allAreas
      : allAreas.where((a) =>
          (a["name"] as String).toLowerCase().contains(_q.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text("All Areas",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kText)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(color: kText, fontSize: 14),
              cursorColor: kPrimary,
              decoration: InputDecoration(
                hintText: "Search areas...",
                hintStyle: const TextStyle(color: kMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: kPrimary, size: 18),
                filled: true,
                fillColor: const Color(0xFFF2FAF5),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kBorder)),
              ),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
        ? Center(child: Text(
            _q.isEmpty ? "No areas available" : "No results for \"$_q\"",
            style: const TextStyle(color: kMuted, fontSize: 15)))
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final area = filtered[i];
              final imgUrl = area["image_url"] as String;
              final count  = area["count"] as int;
              final name   = area["name"] as String;
              return GestureDetector(
                onTap: () => Navigator.push(context, _route(_AreaDetailScreen(
                  areaName: name,
                  stores: List<Map<String,dynamic>>.from(area["stores"] as List),
                  token: widget.token,
                ))),
                child: Container(
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder, width: 1),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha:.06),
                      blurRadius: 10, offset: const Offset(0,3))],
                  ),
                  child: Row(children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                      child: SizedBox(
                        width: 76, height: 76,
                        child: imgUrl.isNotEmpty
                          ? CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover,
                              errorWidget: (_,__,___) => _areaFallback(name))
                          : _areaFallback(name),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name,
                          style: const TextStyle(
                            color: kText, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text("$count Store${count == 1 ? "" : "s"}",
                          style: const TextStyle(color: kMuted, fontSize: 12)),
                      ],
                    )),
                    const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Icon(Icons.chevron_right_rounded, color: kMuted, size: 20)),
                  ]),
                ),
              );
            },
          ),
    );
  }

  Widget _areaFallback(String name) {
    const colors = [Color(0xFFCDEBD6), Color(0xFFE7D7C8), Color(0xFFA9CDBA), Color(0xFFEFF7EE)];
    final c = colors[name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length];
    final init = name.trim().isEmpty ? "?" :
      name.trim().split(" ").take(2).map((w) => w.isEmpty ? "" : w[0].toUpperCase()).join();
    return Container(
      color: c,
      child: Center(child: Text(init,
        style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 22, fontWeight: FontWeight.w900))),
    );
  }
}

// ── Area Detail Screen ─────────────────────────────────────────────
class _AreaDetailScreen extends StatefulWidget {
  final String areaName, token;
  final List<Map<String,dynamic>> stores;
  const _AreaDetailScreen({required this.areaName, required this.stores, required this.token});
  @override State<_AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<_AreaDetailScreen> {
  String _search = "";
  final _ctrl = TextEditingController();

  List<Map<String,dynamic>> get _filtered {
    if (_search.trim().isEmpty) return widget.stores;
    final q = _search.toLowerCase();
    return widget.stores.where((s) {
      final name = (s["store_name"] ?? "").toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        // App bar
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.white,
          foregroundColor: kText,
          elevation: 0,
          shadowColor: Colors.black12,
          expandedHeight: 0,
          toolbarHeight: 52,
          title: Text(widget.areaName,
            style: const TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: kBorder),
          ),
        ),
        // Search
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0,2))],
            ),
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 14, color: kText),
              decoration: InputDecoration(
                hintText: "Search in ${widget.areaName}...",
                hintStyle: const TextStyle(color: kMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: kMuted, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        )),
        // Count label
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Text("${filtered.length} store${filtered.length == 1 ? "" : "s"} in ${widget.areaName}",
            style: const TextStyle(color: kMuted, fontSize: 12)),
        )),
        // Store list
        filtered.isEmpty
          ? const SliverFillRemaining(child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.store_mall_directory_outlined, color: kAccent, size: 48),
                SizedBox(height: 12),
                Text("No stores found", style: TextStyle(color: kMuted, fontSize: 14)),
              ])))
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context,
                      _route(StoreDetailPage(store: Map<String,dynamic>.from(filtered[i]), token: widget.token, userName: "", onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk)))))),
                    child: TopStoreCard(store: filtered[i]),
                  ),
                ),
                childCount: filtered.length,
              )),
            ),
      ]),
    );
  }
}

class _SpecialCategoryScreen extends StatelessWidget {
  final String label, emoji, token;
  final List<Map<String,dynamic>> stores;
  final Color color1, color2;
  const _SpecialCategoryScreen({
    required this.label, required this.emoji, required this.token,
    required this.stores, required this.color1, required this.color2,
  });

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.white,
          foregroundColor: kText,
          elevation: 0,
          expandedHeight: 0,
          toolbarHeight: 52,
          title: Text(label,
            style: const TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.w800)),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: kBorder),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
          sliver: stores.isEmpty
            ? const SliverToBoxAdapter(child: Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: Text("No stores found", style: TextStyle(color: kMuted)))))
            : SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, _route(StoreDetailPage(store: Map<String,dynamic>.from(stores[i]), token: token, userName: "", onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk)))))),
                    child: TopStoreCard(store: stores[i]),
                  ),
                ),
                childCount: stores.length,
              )),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FINAL 1.1 — NEW HOME WIDGETS
// ═══════════════════════════════════════════════════════════════════

// ─── 1. Hero Greeting Section ────────────────────────────────────
// City Hero Section — full-bleed image from Default Images module (key: "city")
class _CityHeroSection extends StatelessWidget {
  final String city;
  final String cityImageUrl;   // URL from /default-images → "city" key
  final bool cityManual;
  final int unreadCount;
  final VoidCallback onCityTap;
  final VoidCallback onBellTap;
  const _CityHeroSection({
    required this.city, required this.cityImageUrl,
    required this.cityManual, required this.unreadCount,
    required this.onCityTap, required this.onBellTap,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good Morning 👋";
    if (h < 17) return "Good Afternoon 👋";
    if (h < 21) return "Good Evening 👋";
    return "Good Night 👋";
  }

  @override Widget build(BuildContext context) {
    final displayCity = (city.isNotEmpty && city != "Detecting...") ? city : "Your City";
    final topPad = MediaQuery.of(context).padding.top;

    return LayoutBuilder(builder: (ctx, constraints) {
      final heroH = constraints.maxWidth * (2.0 / 3.0) + topPad;
    return SizedBox(
      height: heroH,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [

        // ── Background: network image OR brand gradient ──
        cityImageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: cityImageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: 900,
              placeholder: (_, __) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1e3d35), Color(0xFF3E5F55)],
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1e3d35), Color(0xFF3E5F55)],
                  ),
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1e3d35), Color(0xFF3E5F55)],
                ),
              ),
            ),

        // ── Dark scrim for readability ──
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .40),
                  Colors.black.withValues(alpha: .15),
                  Colors.black.withValues(alpha: .55),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // ── TOP ROW: city picker + bell ──
        Positioned(top: topPad + 10, left: 16, right: 16,
          child: Row(children: [
            GestureDetector(
              onTap: onCityTap,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  cityManual ? Icons.edit_location_alt_rounded : Icons.location_on_rounded,
                  color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(
                  city.isNotEmpty ? city : "Detecting...",
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
              ]),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onBellTap,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: .30), width: 1),
                  ),
                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                ),
                if (unreadCount > 0)
                  Positioned(top: -3, right: -3,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xFFe74c3c), shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center),
                    )),
              ]),
            ),
          ]),
        ),

        // ── BOTTOM: greeting + city name + tagline ──
        Positioned(left: 16, right: 16, bottom: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .30), width: 1),
              ),
              child: Text(
                _greeting(),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Explore\n$displayCity",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.15,
                letterSpacing: 0.2,
                shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Discover stores, deals & local favorites",
              style: TextStyle(
                color: Colors.white.withValues(alpha: .85),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ]),
        ),
      ]),
    );
    }); // LayoutBuilder
  }
}


// ─── 2. Category Chips Row — single row with "More" button ──────
class _CategoryChipsRow extends StatelessWidget {
  final List<Map<String,dynamic>> cats;
  final String token;
  final VoidCallback onMoreTap;
  final double? userLat;
  final double? userLng;
  final String? selectedCity;
  const _CategoryChipsRow({required this.cats, required this.token, required this.onMoreTap, this.userLat, this.userLng, this.selectedCity});

  static const _catEmojis = <String, String>{
    'food': '🍔', 'restaurant': '🍽️', 'cafe': '☕', 'fashion': '👗',
    'electronics': '📱', 'beauty': '💄', 'pharmacy': '💊', 'hospital': '🏥',
    'education': '📚', 'grocery': '🛒', 'supermarket': '🛒',
    'gym': '💪', 'salon': '✂️', 'bakery': '🥐', 'hotel': '🏨',
    'jewellery': '💍', 'hardware': '🔧', 'furniture': '🛋️',
  };

  String _emoji(String name) {
    final k = name.toLowerCase().trim();
    for (final e in _catEmojis.entries) {
      if (k.contains(e.key)) return e.value;
    }
    return '🏪';
  }

  @override Widget build(BuildContext context) {
    // Show max 5 categories + "More" button to fit single row
    final visible = cats.take(5).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: [
        ...visible.map((cat) {
          final name = cat["name"]?.toString() ?? cat["category"]?.toString() ?? "";
          if (name.isEmpty) return const SizedBox.shrink();
          final imgUrl = cat["image_url"]?.toString() ?? cat["image"]?.toString() ?? "";
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _CategoryStoresScreen(
                categoryName: name, token: token,
                userLat: userLat, userLng: userLng,
                selectedCity: selectedCity))),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFd4e8de), width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.04), blurRadius: 6, offset: const Offset(0,2))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_emoji(name), style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(name, style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        }),
        // ··· More button
        GestureDetector(
          onTap: onMoreTap,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA9CDBA), width: 1),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text("···", style: TextStyle(color: Color(0xFF3E5F55), fontSize: 14, fontWeight: FontWeight.w700)),
              SizedBox(width: 4),
              Text("More", style: TextStyle(color: Color(0xFF3E5F55), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}


// ─── 3. Sponsored Banner + Featured Stores (combined gradient card) ──
// ═══════════════════════════════════════════════════════
// 4. Banner Section — clean image, downward gradient
// ═══════════════════════════════════════════════════════
class _BannerSection extends StatelessWidget {
  final List<Map<String,dynamic>> sliders;
  final PageController sliderPc;
  final ValueNotifier<int> sliderPageNotifier;
  final String token;
  final ValueChanged<int> onSliderPageChanged;
  const _BannerSection({
    required this.sliders, required this.sliderPc, required this.sliderPageNotifier,
    required this.token, required this.onSliderPageChanged,
  });

  @override Widget build(BuildContext context) {
    if (sliders.isEmpty) {
      return const SizedBox(height: 160,
        child: Center(child: CircularProgressIndicator(color: Color(0xFFA9CDBA), strokeWidth: 2)));
    }
    return Column(children: [
      const SizedBox(height: 16),
      SizedBox(
        height: 200,
        child: PageView.builder(
          controller: sliderPc,
          clipBehavior: Clip.hardEdge,
          itemCount: sliders.length > 1 ? 99999 : sliders.length,
          onPageChanged: onSliderPageChanged,
          itemBuilder: (_, i) {
            final s = sliders[i % sliders.length];
            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              child: PromoSliderCard(
                slider: Map<String,dynamic>.from(s as Map),
                token: token,
              ),
            );
          },
        ),
      ),
      if (sliders.length > 1) ...[
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: sliderPageNotifier,
          builder: (_, page, __) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ...List.generate(sliders.length > 5 ? 5 : sliders.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: (i == page % (sliders.length > 5 ? 5 : sliders.length)) ? 20 : 6,
              height: 6, margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: (i == page % (sliders.length > 5 ? 5 : sliders.length))
                  ? const Color(0xFF3E5F55) : const Color(0xFFd4e8de),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ]),
        ),
      ],
    ]);
  }
}



// ═══════════════════════════════════════════════════════
// 6. Discover Products — clean horizontal cards, no background
// ═══════════════════════════════════════════════════════
class _DiscoverProductsSection extends StatelessWidget {
  final List<Map<String,dynamic>> products;
  final VoidCallback onViewAll;
  final String token;
  const _DiscoverProductsSection({required this.products, required this.onViewAll, this.token = ""});

  static num? _numVal(Map v, List<String> keys) {
    for (final k in keys) {
      final raw = v[k];
      if (raw == null) continue;
      if (raw is num) return raw;
      final parsed = num.tryParse(raw.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  String _resolveImg(Map v) {
    // Try store image first, then product image
    final storeObj = v["store"];
    if (storeObj is Map) {
      for (final k in ["image_url","image_thumb","_thumb","image"]) {
        final val = storeObj[k]?.toString() ?? "";
        if (val.isNotEmpty) return val;
      }
    }
    for (final k in ["logo_url","logo_thumb","image_url","image_thumb","image","logo"]) {
      final val = v[k]?.toString() ?? "";
      if (val.isNotEmpty && (val.startsWith("http") || val.startsWith("data:"))) return val;
    }
    return "";
  }

  // Resolve display title for both product and deal formats
  String _resolveTitle(Map v) {
    final title = v["title"]?.toString() ?? "";
    if (title.isNotEmpty) return title;
    final desc = v["description"]?.toString() ?? "";
    if (desc.isNotEmpty) return desc;
    return v["name"]?.toString() ?? "";
  }

  // Resolve store name for both formats
  String _resolveStoreName(Map v) {
    if (v["store"] is Map) return (v["store"]["store_name"] ?? "").toString();
    return (v["store_name"] ?? v["name"] ?? "").toString();
  }

  Widget _fallback(String name, List<Color> grad) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : "?",
        style: const TextStyle(color: Colors.white70, fontSize: 28, fontWeight: FontWeight.w900))),
    );
  }

  @override Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final _cardGrads = [
      [Color(0xFFe8f5f0), Color(0xFFCDEBD6)],
      [Color(0xFFf5ede6), Color(0xFFE7D7C8)],
      [Color(0xFFe6f0f5), Color(0xFFbad4e8)],
      [Color(0xFFf0ece8), Color(0xFFe0d0c4)],
      [Color(0xFFe8f0e8), Color(0xFFb8d8c0)],
      [Color(0xFFf5eef0), Color(0xFFe8c8d4)],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            const Text("Discover Products",
              style: TextStyle(color: Color(0xFF2c3e35), fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
        SizedBox(
          height: 170, // ITEM8: reduced card height
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: products.length + 1,
            itemBuilder: (ctx, i) {
              final maxCount = products.length;
              if (i == maxCount) {
                return GestureDetector(
                  onTap: onViewAll,
                  child: Center(
                    child: Container(
                    width: 52, height: 120,
                    margin: const EdgeInsets.only(left: 4, right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF3E5F55), width: 1.5),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFFe8f4ef),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded, color: Color(0xFF3E5F55), size: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text("See All",
                        style: TextStyle(color: Color(0xFF3E5F55), fontSize: 9, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center),
                    ]),
                  ),
                  ),
                );
              }
              final v = Map<String,dynamic>.from(products[i] as Map);
              final title     = _resolveTitle(v);
              final offerText = v["offer"]?.toString() ?? v["discount"]?.toString() ?? "";
              final storeName = _resolveStoreName(v);
              final discMatch = RegExp(r'(\d+)%').firstMatch(title + " " + offerText);
              final badge     = discMatch != null ? "${discMatch.group(1)}% OFF" : "";
              final imgSrc    = _resolveImg(v);
              final grad      = _cardGrads[i % _cardGrads.length];

              return GestureDetector(
                onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => ProductDetailsPage(product: v, token: token))),
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [grad[0], grad[1]],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 14, offset: const Offset(0,4))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Top image
                    Stack(children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                        child: SizedBox(
                          width: 140, height: 84, // ITEM8: reduced image height
                          child: imgSrc.startsWith("http")
                            ? CachedNetworkImage(imageUrl: imgSrc, fit: BoxFit.cover,
                                width: 140, height: 84,
                                placeholder: (_, __) => Container(width:140, height:84, color: grad[1]),
                                errorWidget: (_, __, ___) => _fallback(title, [grad[0], grad[1]]))
                            : imgSrc.startsWith("data:image")
                              ? _b64Img(imgSrc, _fallback(title, [grad[0], grad[1]]))
                              : Container(width:140, height:84,
                                  decoration: BoxDecoration(gradient: LinearGradient(colors:[grad[0],grad[1]], begin:Alignment.topLeft, end:Alignment.bottomRight)),
                                  child: Center(child: Text(title.isNotEmpty ? title[0].toUpperCase() : "O",
                                    style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 26, fontWeight: FontWeight.w900)))),
                        ),
                      ),
                      if (badge.isNotEmpty)
                        Positioned(top: 7, left: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFe74c3c), borderRadius: BorderRadius.circular(6)),
                            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          )),
                      // ── Product wishlist heart — live toggle ──
                      Positioned(top: 6, right: 6,
                        child: StatefulBuilder(
                          builder: (ctx2, setH) {
                            bool _pFav = v["_isFav"] == true;
                            return GestureDetector(
                              onTap: () async {
                                final pid = v["_id"]?.toString() ?? v["id"]?.toString() ?? "";
                                if (pid.isEmpty || token.isEmpty) return;
                                final next = !_pFav;
                                setH(() { v["_isFav"] = next; _pFav = next; });
                                try {
                                  await Api.toggleProductFavorite(token, pid);
                                } catch (_) {
                                  setH(() { v["_isFav"] = !next; _pFav = !next; });
                                }
                              },
                              child: Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .88),
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.12), blurRadius: 4)],
                                ),
                                child: Icon(
                                  _pFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: _pFav ? const Color(0xFFe74c3c) : const Color(0xFF9e9e9e),
                                  size: 14),
                              ),
                            );
                          },
                        )),
                    ]),
                    // Bottom text with prices
                    Builder(builder: (_) {
                      // Resolve prices
                      num? saleP = _numVal(v, ["offer_price","sale_price","price","current_price"]); // ITEM10
                      num? origP = _numVal(v, ["original_price","mrp","was_price","compare_price"]);
                      if (origP != null && saleP != null && origP <= saleP) origP = null;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(9, 5, 9, 6), // ITEM8: tighter
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(title.isNotEmpty ? title : offerText,
                            style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 12, fontWeight: FontWeight.w800),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                          // ── FIX 6: Rating below title ──
                          Builder(builder: (_ctx) {
                            final _pr = (v["rating"] as num?)?.toDouble() ?? 0.0;
                            final _pc = (v["rating_count"] ?? v["review_count"] as num?)?.toInt() ?? 0;
                            if (_pr <= 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 11),
                                const SizedBox(width: 2),
                                Text(_pr.toStringAsFixed(1),
                                  style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 10, fontWeight: FontWeight.w700)),
                                if (_pc > 0) Text(" ($_pc)",
                                  style: const TextStyle(color: Color(0xFF9e9e9e), fontSize: 9)),
                              ]),
                            );
                          }),
                          const SizedBox(height: 3),
                          if (storeName.isNotEmpty)
                            Text(storeName,
                              style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 10),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (saleP != null || origP != null) ...[
                            const SizedBox(height: 4),
                            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                              if (origP != null) ...[
                                Text("₹${origP.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    color: Color(0xFF9e9e9e), fontSize: 9, fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Color(0xFF9e9e9e))),
                                const SizedBox(width: 4),
                              ],
                              if (saleP != null)
                                Text("₹${saleP.toStringAsFixed(0)}",
                                  style: const TextStyle(color: Color(0xFF2c7a4b), fontSize: 12, fontWeight: FontWeight.w900)),
                            ]),
                          ],
                        ]),
                      );
                    }),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}


class _NearbyStoresSection extends StatelessWidget {
  final List<Map<String,dynamic>> stores;
  final double radiusKm;
  final String token;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onViewAll;
  final ValueChanged<Map<String,dynamic>> onStoreTap;
  const _NearbyStoresSection({
    required this.stores, required this.radiusKm, required this.token,
    required this.onRadiusChanged, required this.onViewAll, required this.onStoreTap,
  });

  String _resolveImg(Map s) {
    final url = s["image_url"]?.toString() ?? "";
    final thumb = s["image_thumb"]?.toString() ?? "";
    final img = s["image"]?.toString() ?? "";
    if (url.isNotEmpty) return url;
    if (thumb.isNotEmpty) return thumb;
    if (img.isNotEmpty) return img;
    final imgs = s["images"];
    if (imgs is List && imgs.isNotEmpty) return imgs.first.toString();
    return "";
  }

  @override Widget build(BuildContext context) {
    final chips = [
      {"label": "All",    "val": 0.0},
      {"label": "1 km",   "val": 1.0},
      {"label": "3 km",   "val": 3.0},
      {"label": "5 km",   "val": 5.0},
      {"label": "10 km",  "val": 10.0},
    ];
    // ITEM6: filter by distance_km; only fall back to all stores if GPS is completely unavailable
    final bool _gpsKnown = stores.any((s) => s["distance_km"] != null);
    List<Map<String,dynamic>> filtered;
    if (radiusKm == 0.0 || !_gpsKnown) {
      filtered = stores; // All chip selected, or GPS unavailable
    } else {
      filtered = stores.where((s) {
        final d = (s["distance_km"] as num?)?.toDouble();
        return d != null && d <= radiusKm;
      }).toList();
      // Only fall back if literally zero stores match (GPS failure mid-session)
      if (filtered.isEmpty) filtered = stores;
    }
    final visible = filtered.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Nearby Stores", style: TextStyle(color: Color(0xFF2c3e35), fontSize: 18, fontWeight: FontWeight.w800)),
            Text("Stores near your location", style: TextStyle(color: Color(0xFF6b8c7e), fontSize: 12)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: onViewAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFe8f5f0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text("View All", style: TextStyle(color: Color(0xFF3E5F55), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        // Distance chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: chips.map((c) {
            final isActive = radiusKm == (c["val"] as double);
            return GestureDetector(
              onTap: () => onRadiusChanged(c["val"] as double),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF3E5F55) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isActive ? const Color(0xFF3E5F55) : const Color(0xFFd4e8de), width: 1.2),
                  boxShadow: isActive ? [BoxShadow(color: const Color(0xFF3E5F55).withValues(alpha:.18), blurRadius: 8, offset: const Offset(0,2))] : [],
                ),
                child: Text(c["label"] as String,
                  style: TextStyle(color: isActive ? Colors.white : const Color(0xFF6b8c7e),
                    fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 12),
        // Same style as Explore Stores: horizontal scroll, 140px gradient cards
        SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: filtered.length > 8 ? 8 : filtered.length,
            itemBuilder: (ctx, i) {
              final s        = filtered[i];
              final name     = s["store_name"]?.toString() ?? "";
              final category = s["category"]?.toString() ?? "";
              final area     = s["area"]?.toString() ?? "";
              final rating   = ((s["rating"] as num?)?.toDouble() ?? 0.0);
              final distKm   = (s["distance_km"] as num?)?.toDouble();
              final deal     = (s["offer"] ?? "").toString();
              final discMatch = RegExp(r'(\d+)%').firstMatch(deal);
              final badge    = discMatch != null ? "${discMatch.group(1)}% OFF" : "";
              final imgSrc   = _resolveImg(s);
              final _cardGrads = [
                [Color(0xFFe8f5f0), Color(0xFFCDEBD6)],
                [Color(0xFFf5ede6), Color(0xFFE7D7C8)],
                [Color(0xFFe6f0f5), Color(0xFFbad4e8)],
                [Color(0xFFf0ece8), Color(0xFFe0d0c4)],
                [Color(0xFFe8f0e8), Color(0xFFb8d8c0)],
                [Color(0xFFf5eef0), Color(0xFFe8c8d4)],
              ];
              final grad = _cardGrads[i % _cardGrads.length];

              return GestureDetector(
                onTap: () => onStoreTap(s),
                child: Container(
                  width: 140,
                  height: 175,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 14, offset: const Offset(0,4))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Stack(children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                        child: SizedBox(
                          width: 140, height: 100,
                          child: imgSrc.startsWith("http")
                            ? CachedNetworkImage(imageUrl: imgSrc, fit: BoxFit.cover,
                                width: 140, height: 100,
                                placeholder: (_, __) => Container(
                                  width: 140, height: 100,
                                  color: grad[1]),
                                errorWidget: (_, __, ___) => _fallback(name))
                            : imgSrc.startsWith("data:image")
                              ? _b64Img(imgSrc, _fallback(name))
                              : Container(
                                  width: 140, height: 100,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [grad[0], grad[1]],
                                      begin: Alignment.topLeft, end: Alignment.bottomRight)),
                                  child: Center(child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : "S",
                                    style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 26, fontWeight: FontWeight.w900)))),
                        ),
                      ),
                      if (badge.isNotEmpty)
                        Positioned(top: 7, left: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFe74c3c), borderRadius: BorderRadius.circular(6)),
                            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          )),
                      if (distKm != null)
                        Positioned(top: 7, right: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3E5F55).withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              distKm < 1 ? "${(distKm*1000).round()}m" : "${distKm.toStringAsFixed(1)}km",
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                          )),
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(name, style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 12, fontWeight: FontWeight.w800),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(children: [
                          if (category.isNotEmpty) Expanded(child: Text(category,
                            style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (rating > 0) Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 10),
                            const SizedBox(width: 2),
                            Text(rating.toStringAsFixed(1), style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 10, fontWeight: FontWeight.w600)),
                          ]),
                        ]),
                        if (area.isNotEmpty && area != "null") ...[
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.location_on, color: Color(0xFF6b8c7e), size: 10),
                            const SizedBox(width: 2),
                            Expanded(child: Text(area, style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 10),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _fallback(String name) => Container(
    color: const Color(0xFFA9CDBA),
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : "S",
      style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 22, fontWeight: FontWeight.w900))),
  );
}

class _ExploreAreasSection extends StatelessWidget {
  final List<Map<String,dynamic>> stores;
  final String token;
  const _ExploreAreasSection({required this.stores, required this.token});

  static const _areaColors = [
    Color(0xFFA9CDBA), Color(0xFFB8A9CD), Color(0xFF3E5F55),
    Color(0xFFE7D7C8), Color(0xFFCDEBD6), Color(0xFF6b8c7e),
  ];

  @override Widget build(BuildContext context) {
    // Build area map from stores
    final Map<String, int> areaCount = {};
    for (final s in stores) {
      final a = (s["area"]?.toString() ?? "").trim();
      if (a.isNotEmpty && a != "null") areaCount[a] = (areaCount[a] ?? 0) + 1;
    }
    final areas = areaCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (areas.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Explore Areas",
              style: TextStyle(color: Color(0xFF2c3e35), fontSize: 18, fontWeight: FontWeight.w800)),
            Text("Discover great places nearby",
              style: TextStyle(color: Color(0xFF6b8c7e), fontSize: 12)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _AllAreasScreen(stores: stores, token: token))),
            child: const Text("View all →",
              style: TextStyle(color: Color(0xFF3E5F55), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: areas.take(8).toList().asMap().entries.map((e) {
            final idx   = e.key;
            final area  = e.value.key;
            final count = e.value.value;
            final color = _areaColors[idx % _areaColors.length];
            final initials = area.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : "").join();
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => _AreaDetailScreen(
                  areaName: area, stores: stores.where((s) =>
                    (s["area"]?.toString() ?? "").trim().toLowerCase() == area.toLowerCase()).toList(),
                  token: token))),
              child: Container(
                width: 80, margin: const EdgeInsets.only(right: 12),
                child: Column(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .22),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: .40), width: 1.5),
                    ),
                    child: Center(child: Text(initials,
                      style: TextStyle(color: color.withValues(alpha: 1.0), fontSize: 16, fontWeight: FontWeight.w800))),
                  ),
                  const SizedBox(height: 6),
                  Text(area, style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 11, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  Text("$count Store${count == 1 ? '' : 's'}",
                    style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 10),
                    textAlign: TextAlign.center),
                ]),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}


// ─── 6. All Stores Screen ───────────────────────────────────────
class _AllStoresScreen extends StatelessWidget {
  final String token;
  const _AllStoresScreen({required this.token});
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF2c3e35),
      elevation: 0,
      title: const Text("All Stores", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      surfaceTintColor: Colors.white,
    ),
    body: const Center(child: Text("Coming soon", style: TextStyle(color: Color(0xFF6b8c7e)))),
  );
}


// ─── 7. Browse All Categories Screen ─────────────────────────────
class _BrowseAllCategoriesScreen extends StatelessWidget {
  final List<Map<String,dynamic>> cats;
  final String token;
  final double? userLat;
  final double? userLng;
  final String? selectedCity;
  const _BrowseAllCategoriesScreen({required this.cats, required this.token, this.userLat, this.userLng, this.selectedCity});

  static const _catEmojis = <String, String>{
    'food': '🍔', 'restaurant': '🍽️', 'cafe': '☕', 'fashion': '👗',
    'electronics': '📱', 'beauty': '💄', 'pharmacy': '💊', 'hospital': '🏥',
    'education': '📚', 'grocery': '🛒', 'supermarket': '🛒',
    'gym': '💪', 'salon': '✂️', 'bakery': '🥐', 'hotel': '🏨',
    'jewellery': '💍', 'hardware': '🔧', 'furniture': '🛋️',
  };
  String _emoji(String name) {
    final k = name.toLowerCase().trim();
    for (final e in _catEmojis.entries) { if (k.contains(e.key)) return e.value; }
    return '🏪';
  }

  static const List<List<Color>> _gradients = [
    [Color(0xFFCDEBD6), Color(0xFFA9CDBA)],
    [Color(0xFFE7D7C8), Color(0xFFD4B8A0)],
    [Color(0xFFD6E8F5), Color(0xFFA9C4D8)],
    [Color(0xFFEBCDEB), Color(0xFFCDA9CD)],
    [Color(0xFFEBE8CD), Color(0xFFCDC8A9)],
    [Color(0xFFCDEBE0), Color(0xFFA9CDB8)],
  ];

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2c3e35),
        elevation: 0,
        title: const Text("All Categories", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        surfaceTintColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.95),
        itemCount: cats.length,
        itemBuilder: (ctx, i) {
          final cat = cats[i];
          final name = cat["name"]?.toString() ?? cat["category"]?.toString() ?? "";
          final imgUrl = cat["image_url"]?.toString() ?? cat["image"]?.toString() ?? "";
          final grad = _gradients[i % _gradients.length];
          return GestureDetector(
            onTap: () => Navigator.push(ctx, MaterialPageRoute(
              builder: (_) => _CategoryStoresScreen(
                categoryName: name, token: token,
                userLat: userLat, userLng: userLng,
                selectedCity: selectedCity))),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.06), blurRadius: 10, offset: const Offset(0,3))],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_emoji(name), style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 6),
                Text(name, style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 12, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          );
        },
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// UNIFIED BANNER + EXPLORE STORES SECTION
// Banner (full width) flows seamlessly into featured store row
// ═══════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
// 1. ADMIN BANNER SECTION — large, full-width, with page dots
// ═══════════════════════════════════════════════════════════════
class _BannerStoresBlock extends StatefulWidget {
  final List<Map<String,dynamic>> banners;
  final List<Map<String,dynamic>> stores;
  final String token;
  final VoidCallback onViewAll;
  final Set<String> favStoreIds;
  final VoidCallback onFavChanged;
  const _BannerStoresBlock({
    required this.banners, required this.stores,
    required this.token,   required this.onViewAll,
    this.favStoreIds = const {},
    required this.onFavChanged,
  });
  @override State<_BannerStoresBlock> createState() => _BannerStoresBlockState();
}

class _BannerStoresBlockState extends State<_BannerStoresBlock> {
  final PageController _pc = PageController(initialPage: 49999);
  final ValueNotifier<int> _page = ValueNotifier<int>(0);
  Timer? _timer;

  @override void initState() {
    super.initState();
    _startTimer();
  }
  void _startTimer() {
    _timer?.cancel();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        _pc.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      });
    }
  }
  @override void didUpdateWidget(_BannerStoresBlock old) {
    super.didUpdateWidget(old);
    if (old.banners.length != widget.banners.length) _startTimer();
  }
  @override void dispose() { _timer?.cancel(); _pc.dispose(); _page.dispose(); super.dispose(); }

  String _resolveImg(Map b) {
    for (final k in ["image_url","image"]) {
      final v = b[k]?.toString() ?? "";
      if (v.isNotEmpty) return v;
    }
    return "";
  }

  Widget _bannerImg(String imgUrl) {
    if (imgUrl.startsWith("data:image")) {
      try {
        return Image.memory(base64Decode(imgUrl.split(",").last),
          fit: BoxFit.fitWidth, alignment: Alignment.topCenter,
          width: double.infinity, gaplessPlayback: true);
      } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }
    if (imgUrl.startsWith("http")) {
      return CachedNetworkImage(imageUrl: imgUrl,
        fit: BoxFit.fitWidth, alignment: Alignment.topCenter,
        width: double.infinity,
        placeholder: (_, __) => Container(color: const Color(0xFF3E5F55)),
        errorWidget: (_, __, ___) => _gradBox());
    }
    return _gradBox();
  }
  Widget _gradBox() => Container(decoration: const BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFF1e3d35), Color(0xFF3E5F55)],
      begin: Alignment.topLeft, end: Alignment.bottomRight)));

  String _resolveStoreImg(Map s) {
    for (final k in ["image_url","image_thumb","_thumb","image"]) {
      final v = s[k]?.toString() ?? "";
      if (v.isNotEmpty) return v;
    }
    final imgs = s["images"];
    if (imgs is List && imgs.isNotEmpty) return imgs.first.toString();
    return "";
  }

  @override Widget build(BuildContext context) {
    final hasBanners = widget.banners.isNotEmpty;
    final hasStores  = widget.stores.isNotEmpty;
    if (!hasBanners && !hasStores) return const SizedBox.shrink();

    // Heights — 3:2 banner, 35-40% card overlap
    const double bannerH   = 320.0;
    const double overlapPx = 100.0; // ~31% of bannerH — cards peek but don't obscure banner
    const double cardH     = 212.0; // reduced ~22% — compact card height
    const double headerH   = 0.0;
    const double topPad    = 14.0;

    // Stores-only (no banner)
    if (!hasBanners) return _storesOnly(cardH, headerH);

    // Banner-only (no stores)
    if (!hasStores) {
      return Padding(
        padding: const EdgeInsets.only(top: topPad),
        child: SizedBox(height: bannerH, child: _bannerPageView(bannerH)));
    }

    // Both: banner + overlapping store cards
    final totalH = topPad + bannerH + cardH - overlapPx;
    return SizedBox(
      height: totalH,
      child: Stack(clipBehavior: Clip.none, children: [

        // ── Banner ──
        Positioned(top: topPad, left: 0, right: 0, height: bannerH,
          child: _bannerPageView(bannerH)),

        // ── Store cards overlap the bottom of the banner (no heading) ──
        Positioned(
          top: topPad + bannerH - overlapPx,
          left: 0, right: 0,
          child: SizedBox(
            height: cardH,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
              // +1 for the "See All" card at the end
              itemCount: (widget.stores.length > 8 ? 8 : widget.stores.length) + 1,
              itemBuilder: (ctx, i) {
                final storeCount = widget.stores.length > 8 ? 8 : widget.stores.length;
                if (i < storeCount) return _storeCard(ctx, widget.stores[i]);
                // Last card: "See All" — matches floating store card dimensions
                return GestureDetector(
                  onTap: widget.onViewAll,
                  child: Center(
                    child: Container(
                    width: 52, height: 120,
                    margin: const EdgeInsets.only(left: 4, right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF3E5F55), width: 1.5),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 22, height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFFe8f4ef),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.store_mall_directory_rounded, color: Color(0xFF3E5F55), size: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text("See All\nStores",
                        style: TextStyle(color: Color(0xFF3E5F55), fontSize: 9, fontWeight: FontWeight.w800, height: 1.3),
                        textAlign: TextAlign.center),
                    ]),
                  ),),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }

  // ── Banner PageView ──────────────────────────────────────────
  Widget _bannerPageView(double h) {
    final count = widget.banners.length;
    return Stack(children: [
      PageView.builder(
        controller: _pc,
        clipBehavior: Clip.none,
        itemCount: count > 1 ? 99999 : count,
        onPageChanged: (i) => _page.value = i % count,
        itemBuilder: (_, i) {
          final b = widget.banners[i % count];
          final imgUrl = _resolveImg(b);
          return GestureDetector(
            onTap: () {
              final link = b["link_url"]?.toString() ?? "";
              if (link.isNotEmpty) launchUrl(Uri.parse(link));
            },
            child: _bannerImg(imgUrl),
          );
        },
      ),
      // Dots
      if (widget.banners.length > 1)
        Positioned(bottom: 100, left: 0, right: 0,
          child: ValueListenableBuilder<int>(
            valueListenable: _page,
            builder: (_, pg, __) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: pg == i ? 18 : 6, height: 6,
                  decoration: BoxDecoration(
                    color: pg == i ? Colors.white : Colors.white.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
          ),
        ),
    ]);
  }

  // ── Stores-only fallback (no banner) — no heading, See All as last card ──
  Widget _storesOnly(double cardH, double headerH) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        height: cardH,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          itemCount: (widget.stores.length > 8 ? 8 : widget.stores.length) + 1,
          itemBuilder: (ctx, i) {
            final storeCount = widget.stores.length > 8 ? 8 : widget.stores.length;
            if (i < storeCount) return _storeCard(ctx, widget.stores[i]);
            return GestureDetector(
              onTap: widget.onViewAll,
              child: Center(
                child: Container(
                width: 52, height: 120,
                margin: const EdgeInsets.only(left: 4, right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF3E5F55), width: 1.5),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFe8f4ef),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.store_mall_directory_rounded, color: Color(0xFF3E5F55), size: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text("See All\nStores",
                    style: TextStyle(color: Color(0xFF3E5F55), fontSize: 9, fontWeight: FontWeight.w800, height: 1.3),
                    textAlign: TextAlign.center),
                ]),
              ),),
            );
          },
        ),
      ),
    );
  }

  // ── Individual store card ────────────────────────────────────
  // ── Badge metadata for glass ribbon ──
  static const Map<String, Map<String,String>> _badgeRibbonMeta = {
    "new_store":     {"label": "🆕 NEW STORE"},
    "just_opened":   {"label": "🎉 JUST OPENED"},
    "newly_added":   {"label": "✨ NEWLY ADDED"},
    "trending":      {"label": "🔥 TRENDING"},
    "popular":       {"label": "⭐ POPULAR"},
    "top_rated":     {"label": "🏆 TOP RATED"},
    "must_visit":    {"label": "📍 MUST VISIT"},
    "limited_offer": {"label": "⏳ LIMITED OFFER"},
  };

  String? _resolveStoreBadge(Map<String,dynamic> s) {
    // 1. Explicit admin badge — highest priority
    final badge = s["badge"]?.toString() ?? "";
    if (badge.isNotEmpty && _badgeRibbonMeta.containsKey(badge)) return badge;
    // 2. Auto: show "newly_added" if store was created within last 10 days
    try {
      final raw = s["created_at"]?.toString() ?? "";
      if (raw.isNotEmpty) {
        final dt = DateTime.tryParse(raw);
        if (dt != null && DateTime.now().difference(dt).inDays < 10) {
          return "newly_added";
        }
      }
    } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    // 3. Manual boolean flags
    if (s["is_new_in_town"] == true) return "new_store";
    if (s["is_trending"] == true) return "trending";
    if (s["is_popular"] == true) return "popular";
    return null;
  }

  Widget _storeCard(BuildContext ctx, Map<String,dynamic> s) {
    final name      = s["store_name"]?.toString() ?? "";
    final cat       = s["category"]?.toString() ?? "";
    final rating    = (s["rating"] as num?)?.toDouble() ?? 0.0;
    final revCount  = (s["rating_count"] ?? s["review_count"] as num?)?.toInt() ?? 0;
    final dist      = (s["distance_km"] as num?)?.toDouble();
    final distTxt   = dist != null
        ? (dist < 1.0 ? "${(dist * 1000).toStringAsFixed(0)} m" : "${dist.toStringAsFixed(1)} km")
        : null; // Hide badge when GPS/distance not yet available
    final openTime  = s["open_time"]?.toString()  ?? "";
    final closeTime = s["close_time"]?.toString() ?? "";
    final now       = TimeOfDay.now();

    // Open/close status
    String statusLabel = "";
    String closingInfo = "";
    // ITEM4: treat "00:00" as "not configured" to avoid showing "Opens 12 AM • Closes 12 AM"
    final bool _timesConfigured = !(openTime == "00:00" && closeTime == "00:00")
        && !(openTime.isEmpty && closeTime == "00:00");
    if (closeTime.isNotEmpty && _timesConfigured) {
      try {
        final cParts    = closeTime.split(":");
        final closeH    = int.parse(cParts[0]);
        final closeM    = cParts.length > 1 ? int.parse(cParts[1]) : 0;
        final nowMins   = now.hour * 60 + now.minute;
        final closeMins = closeH * 60 + closeM;
        final cSuffix   = closeH >= 12 ? "PM" : "AM";
        final cH12      = closeH > 12 ? closeH - 12 : (closeH == 0 ? 12 : closeH);
        final cMinStr   = closeM > 0 ? ":${closeM.toString().padLeft(2,'0')}" : "";
        if (nowMins < closeMins) {
          statusLabel = "Open";
          closingInfo = "Closes $cH12$cMinStr $cSuffix";
        } else {
          statusLabel = "Closed";
          if (openTime.isNotEmpty) {
            final oParts  = openTime.split(":");
            final oH      = int.parse(oParts[0]);
            final oM      = oParts.length > 1 ? int.parse(oParts[1]) : 0;
            final oSuffix = oH >= 12 ? "PM" : "AM";
            final oH12    = oH > 12 ? oH - 12 : (oH == 0 ? 12 : oH);
            final oMinStr = oM > 0 ? ":${oM.toString().padLeft(2,'0')}" : "";
            closingInfo = "Opens $oH12$oMinStr $oSuffix";
          }
        }
      } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }

    // ── Badge key for glass ribbon ──
    final String? badgeKey = _resolveStoreBadge(s);

    // Resolve logo
    String logoSrc = s["logo_url"]?.toString() ?? s["logo"]?.toString() ?? s["logo_thumb"]?.toString() ?? "";
    if (logoSrc.isEmpty)
      logoSrc = s["image_url"]?.toString() ?? s["image"]?.toString() ?? s["image_thumb"]?.toString() ?? "";

    Widget logoWidget;
    if (logoSrc.startsWith("http")) {
      logoWidget = CachedNetworkImage(
        imageUrl: logoSrc,
        fit: BoxFit.cover,    // FIX 2: cover inside rounded square
        width: 60, height: 60,
        placeholder: (_, __) => Container(color: const Color(0xFFA9CDBA)),
        errorWidget: (_, __, ___) => _storeFallback(name));
    } else if (logoSrc.startsWith("data:image")) {
      try {
        logoWidget = Image.memory(base64Decode(logoSrc.split(",").last),
          fit: BoxFit.cover, width: 60, height: 60);
      } catch (_) { logoWidget = _storeFallback(name); }
    } else {
      logoWidget = _storeFallback(name);
    }

    return GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => StoreDetailPage(
          store: _enrichStoreForDetail(Map<String,dynamic>.from(s)),
          token: widget.token, userName: "",
          onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk)))))).then((_) => widget.onFavChanged()),
      child: Container(
        width: 152,
        margin: const EdgeInsets.only(right: 12, top: 8, bottom: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFe0ece6), width: 1.0),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: .07),
            blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [

            // ── Top row: distance badge (FIX3: only here) + heart + rating (FIX4) ──
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              // Distance badge — only location_top
              if (distTxt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFe8f5f0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on_rounded,
                      color: Color(0xFF3E5F55), size: 9),
                    const SizedBox(width: 2),
                    Text(distTxt,
                      style: const TextStyle(
                        color: Color(0xFF3E5F55),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700)),
                  ]),
                )
              else
                const SizedBox(width: 4),

              // FIX 7: live heart — red if in favStoreIds
              GestureDetector(
                onTap: () async {
                  final id = s["_id"]?.toString() ?? s["id"]?.toString() ?? "";
                  if (id.isEmpty || widget.token.isEmpty) return;
                  try {
                    await Api.toggleFavorite(widget.token, id);
                    widget.onFavChanged();
                  } catch (_) {}
                },
                child: Icon(
                  widget.favStoreIds.contains(
                    s["_id"]?.toString() ?? s["id"]?.toString() ?? "")
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: widget.favStoreIds.contains(
                    s["_id"]?.toString() ?? s["id"]?.toString() ?? "")
                      ? const Color(0xFFe74c3c)
                      : const Color(0xFF9e9e9e),
                  size: 17),
              ),
            ]),

            const SizedBox(height: 7),

            // ── FIX 2: Double circle logo ──
            // Outer circle: white bg + Offro green border (84px)
            Container(
              width: 78, height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFA9CDBA), width: 1.5),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Center(
                // Inner rounded image (62px, radius 16)
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 56, height: 56,
                    child: logoWidget,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 5),

            // ── Store name ──
            Text(name,
              style: const TextStyle(
                color: Color(0xFF1a2e27),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                height: 1.2),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),

            if (cat.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(cat,
                style: const TextStyle(
                  color: Color(0xFF9e9e9e),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 4),

            // ── Divider ──
            Container(height: 1, color: const Color(0xFFf0f0f0)),

            const SizedBox(height: 3),

            // ── Open / Closed status row (always shown) ──
            Builder(builder: (_ctx) {
              final _displayLabel = statusLabel.isNotEmpty ? statusLabel : "";
              final _displayInfo  = closingInfo.isNotEmpty ? closingInfo
                  : "";  // FIX 2: empty = hide row when no times configured
              if (_displayLabel.isEmpty && _displayInfo.isEmpty) return const SizedBox.shrink();
              return Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, children: [
                  if (_displayLabel.isNotEmpty) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _displayLabel == "Open"
                        ? const Color(0xFFe8f5f0)
                        : const Color(0xFFfdf0f0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_displayLabel,
                      style: TextStyle(
                        color: _displayLabel == "Open"
                          ? const Color(0xFF3E5F55)
                          : const Color(0xFFc0392b),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800)),
                  ),
                  if (_displayLabel.isNotEmpty && _displayInfo.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    const Text("·",
                      style: TextStyle(color: Color(0xFF9e9e9e), fontSize: 12)),
                    const SizedBox(width: 5),
                  ],
                  if (_displayInfo.isNotEmpty) Flexible(
                    child: Text(_displayInfo,
                      style: const TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ]);
            }),

          ]),
        ),
              // ── Glass badge ribbon (bottom overlay, 28px, no layout shift) ──
              if (badgeKey != null)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft:  Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        height: 28,
                        color: Colors.black.withValues(alpha: 0.62),
                        alignment: Alignment.center,
                        child: Text(
                          _badgeRibbonMeta[badgeKey]!["label"]!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storeFallback(String name) => Container(
    color: const Color(0xFFA9CDBA),
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : "S",
      style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 28, fontWeight: FontWeight.w900))),
  );
}


// ═══════════════════════════════════════════════════════════════
// 3. PROMO SLIDER SECTION — merchant banners, compact (160px)
// ═══════════════════════════════════════════════════════════════
class _PromoSliderSection extends StatelessWidget {
  final List<Map<String,dynamic>> sliders;
  final PageController sliderPc;
  final ValueNotifier<int> sliderPageNotifier;
  final String token;
  final ValueChanged<int> onSliderPageChanged;
  const _PromoSliderSection({
    required this.sliders, required this.sliderPc,
    required this.sliderPageNotifier, required this.token,
    required this.onSliderPageChanged,
  });

  @override Widget build(BuildContext context) {
    if (sliders.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: sliderPc,
            clipBehavior: Clip.none,
            itemCount: sliders.length > 1 ? 99999 : sliders.length,
            onPageChanged: onSliderPageChanged,
            itemBuilder: (_, i) {
              final s = sliders[i % sliders.length];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PromoSliderCard(
                  slider: Map<String,dynamic>.from(s as Map),
                  token: token,
                  squareCorners: false,
                  hideText: false,
                ),
              );
            },
          ),
        ),
        // Dots
        const SizedBox(height: 10),
        ValueListenableBuilder<int>(
          valueListenable: sliderPageNotifier,
          builder: (_, pg, __) {
            final count = sliders.length;
            return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: pg == i ? 18 : 6, height: 6,
                  decoration: BoxDecoration(
                    color: pg == i ? const Color(0xFF3E5F55) : const Color(0xFFd4e8de),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]);
          },
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM PRODUCT CARD — full-bleed image, cinematic style
// Matches store card visual quality
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// PRODUCT DETAIL PAGE
// ═══════════════════════════════════════════════════════════════
class ProductDetailsPage extends StatefulWidget {
  final Map<String,dynamic> product;
  final String token;
  const ProductDetailsPage({super.key, required this.product, this.token = ""});
  @override State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  bool _isFav = false;
  double _userRating = 0;
  double _avgRating  = 0;
  int    _ratingCount = 0;
  final TextEditingController _reviewCtrl = TextEditingController();
  bool _reviewSubmitting = false;
  bool _reviewSubmitted  = false;

  @override void initState() {
    super.initState();
    _avgRating   = (widget.product["rating"] as num?)?.toDouble() ?? 0.0;
    _ratingCount = (widget.product["rating_count"] as num?)?.toInt() ?? 0;
    _loadFavStatus();
  }

  Future<void> _loadFavStatus() async {
    if (widget.token.isEmpty) return;
    final pid = widget.product["_id"]?.toString() ?? widget.product["id"]?.toString() ?? "";
    if (pid.isEmpty) return;
    final fav = await Api.isProductFavorite(widget.token, pid);
    if (mounted) setState(() => _isFav = fav);
  }

  @override void dispose() { _reviewCtrl.dispose(); super.dispose(); }

  num? _numVal(List<String> keys) {
    for (final k in keys) {
      final raw = widget.product[k];
      if (raw == null) continue;
      if (raw is num) return raw;
      final parsed = num.tryParse(raw.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  Widget _resolveImage() {
    final keys = ["image_url","image_thumb","image","logo_url","logo"];
    final storeObj = widget.product["store"];
    if (storeObj is Map) {
      for (final k in ["image_url","image_thumb","image","image2"]) {
        final v = storeObj[k]?.toString() ?? "";
        if (v.startsWith("http")) return CachedNetworkImage(imageUrl: v, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          placeholder: (_, __) => Container(color: const Color(0xFFA9CDBA)),
          errorWidget: (_, __, ___) => _fallbackImg());
        if (v.startsWith("data:image")) {
          try { return Image.memory(base64Decode(v.split(",").last), fit: BoxFit.cover, width: double.infinity, height: double.infinity); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
        }
      }
    }
    for (final k in keys) {
      final v = widget.product[k]?.toString() ?? "";
      if (v.startsWith("http")) return CachedNetworkImage(imageUrl: v, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
        placeholder: (_, __) => Container(color: const Color(0xFFA9CDBA)),
        errorWidget: (_, __, ___) => _fallbackImg());
      if (v.startsWith("data:image")) {
        try { return Image.memory(base64Decode(v.split(",").last), fit: BoxFit.cover, width: double.infinity, height: double.infinity); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
      }
    }
    return _fallbackImg();
  }

  // Full-screen contained version of product image (for the viewer dialog)
  Widget _resolveImageContained() {
    final keys = ["image_url","image_thumb","image","logo_url","logo"];
    final storeObj = widget.product["store"];
    if (storeObj is Map) {
      for (final k in ["image_url","image_thumb","image","image2"]) {
        final v = storeObj[k]?.toString() ?? "";
        if (v.startsWith("http")) return CachedNetworkImage(imageUrl: v, fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => _fallbackImg());
        if (v.startsWith("data:image")) {
          try { return Image.memory(base64Decode(v.split(",").last), fit: BoxFit.contain); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
        }
      }
    }
    for (final k in keys) {
      final v = widget.product[k]?.toString() ?? "";
      if (v.startsWith("http")) return CachedNetworkImage(imageUrl: v, fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => _fallbackImg());
      if (v.startsWith("data:image")) {
        try { return Image.memory(base64Decode(v.split(",").last), fit: BoxFit.contain); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
      }
    }
    return _fallbackImg();
  }

  Widget _fallbackImg() {
    final name = widget.product["title"]?.toString() ?? widget.product["name"]?.toString() ?? "P";
    return Container(
      color: const Color(0xFFA9CDBA),
      child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : "P",
        style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 48, fontWeight: FontWeight.w900))),
    );
  }

  Future<void> _submitReview() async {
    final text = _reviewCtrl.text.trim();
    if (text.isEmpty || _userRating == 0) return;
    final pid = widget.product["_id"]?.toString() ?? widget.product["id"]?.toString() ?? "";
    if (pid.isEmpty) return;
    setState(() => _reviewSubmitting = true);
    try {
      await Api.submitProductReview(widget.token, pid, _userRating, text);
      // Update local avg optimistically
      final newCount = _ratingCount + 1;
      final newAvg   = ((_avgRating * _ratingCount) + _userRating) / newCount;
      if (mounted) setState(() {
        _reviewSubmitting = false;
        _reviewSubmitted  = true;
        _ratingCount      = newCount;
        _avgRating        = double.parse(newAvg.toStringAsFixed(1));
      });
    } catch (_) {
      if (mounted) setState(() => _reviewSubmitting = false);
    }
  }

  @override Widget build(BuildContext context) {
    final p = widget.product;
    final title      = p["title"]?.toString() ?? p["name"]?.toString() ?? "Product";
    final storeObj   = p["store"];
    final storeName  = storeObj is Map
        ? (storeObj["store_name"] ?? storeObj["business_name"] ?? storeObj["merchant_name"] ?? storeObj["name"] ?? "").toString()
        : (p["store_name"] ?? p["business_name"] ?? p["merchant_name"] ?? "").toString();
    final storeArea  = storeObj is Map ? (storeObj["area"] ?? "").toString() : (p["area"] ?? "").toString();
    final storeCat   = storeObj is Map ? (storeObj["category"] ?? "").toString() : (p["category"] ?? "").toString();
    final storeId    = storeObj is Map
        ? (storeObj["_id"] ?? storeObj["id"] ?? "").toString()
        : (widget.product["store_id"] ?? "").toString(); // merchant_id intentionally excluded (wrong entity)
    final storeData  = storeObj is Map
        ? (Map<String,dynamic>.from(storeObj as Map)..["_id"] ??= storeId)
        : <String,dynamic>{"_id": storeId, "store_name": widget.product["store_name"] ?? "",
                            "category": widget.product["category"] ?? "",
                            "area": widget.product["area"] ?? ""};
    // store_active: from API response (public.py attaches this — false if store status != active)
    // Defaults to true if field absent (backward compat with older records)
    final bool storeIsActive = widget.product["store_active"] as bool? ?? true;
    final description = p["description"]?.toString() ?? p["details"]?.toString() ?? "";
    final offerText  = p["offer"]?.toString() ?? "";
    final discMatch  = RegExp(r'(\d+)%').firstMatch(offerText);
    final discBadge  = discMatch != null ? "${discMatch.group(1)}% OFF" : "";

    final saleP = _numVal(["offer_price","sale_price","price","current_price"]); // ITEM10
    final origP = _numVal(["original_price","mrp","was_price","compare_price"]);
    final showOrig = origP != null && saleP != null && origP > saleP;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(slivers: [
        // ── Hero image app bar ──
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: const Color(0xFF3E5F55),
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .35), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18)),
          ),
          actions: [
            GestureDetector(
              onTap: () async {
                final pid = widget.product["_id"]?.toString() ?? widget.product["id"]?.toString() ?? "";
                setState(() => _isFav = !_isFav); // optimistic
                if (widget.token.isNotEmpty && pid.isNotEmpty) {
                  await Api.toggleProductFavorite(widget.token, pid);
                }
              },
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .35), shape: BoxShape.circle),
                child: Icon(_isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isFav ? const Color(0xFFe74c3c) : Colors.white, size: 20)),
            ),
            const SizedBox(width: 4),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: GestureDetector(
              onTap: () => showDialog(
                context: context,
                barrierColor: Colors.black87,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: EdgeInsets.zero,
                  child: Stack(children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        minScale: 0.8, maxScale: 5.0,
                        child: Center(
                          child: _resolveImageContained(),
                        ),
                      ),
                    ),
                    Positioned(top: 40, right: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 20)))),
                  ]),
                ),
              ),
              child: Stack(fit: StackFit.expand, children: [
              _resolveImage(),
              // Bottom scrim
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: .55)],
                  stops: const [0.0, 0.55, 1.0]),
              ))),
              // Discount badge
              if (discBadge.isNotEmpty)
                Positioned(bottom: 16, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFe74c3c), borderRadius: BorderRadius.circular(8)),
                    child: Text(discBadge, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                  )),
              ]),
            ),
          ),
        ),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Product name ──
            Text(title,
              style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 22, fontWeight: FontWeight.w900, height: 1.25)),

            const SizedBox(height: 10),

            // ── Price row ──
            if (saleP != null || showOrig)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  // ── Price row: sale price + strikethrough orig on ONE line ──
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                    if (saleP != null)
                      Text("₹${saleP.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Color(0xFF2c7a4b), fontSize: 24, fontWeight: FontWeight.w900)),
                    if (showOrig) ...[
                      const SizedBox(width: 10),
                      Text("₹${origP!.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Color(0xFF9e9e9e), fontSize: 15, fontWeight: FontWeight.w500,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Color(0xFF9e9e9e))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFe74c3c),
                          borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          "${(((origP! - saleP!) / origP!) * 100).toStringAsFixed(0)}% off",
                          style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                    ],
                  ]),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  if (saleP != null)
                    const Text("Selling Price",
                      style: TextStyle(color: Color(0xFF2c7a4b), fontSize: 11, fontWeight: FontWeight.w600)),
                  if (showOrig) ...[
                    const SizedBox(width: 12),
                    Text("MRP ₹${origP!.toStringAsFixed(0)}",
                      style: const TextStyle(color: Color(0xFF9e9e9e), fontSize: 11)),
                  ],
                ]),
              ]),

            const SizedBox(height: 14),

            // ── Rating row ──
            if (_avgRating > 0 || _ratingCount > 0)
              Row(children: [
                ...List.generate(5, (i) => Icon(
                  i < _avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFFFD700), size: 18)),
                const SizedBox(width: 6),
                Text(_avgRating.toStringAsFixed(1),
                  style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 14, fontWeight: FontWeight.w700)),
                if (_ratingCount > 0) ...[
                  const SizedBox(width: 4),
                  Text("($_ratingCount reviews)",
                    style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 12)),
                ],
              ]),

            if (_avgRating > 0 || _ratingCount > 0) const SizedBox(height: 14),

            // ── Description ──
            if (description.isNotEmpty) ...[
              const Text("About this product",
                style: TextStyle(color: Color(0xFF2c3e35), fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(description,
                style: const TextStyle(color: Color(0xFF4a6a60), fontSize: 14, height: 1.55)),
              const SizedBox(height: 20),
            ],

            // ── Offer text ──
            if (offerText.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFe8f5f0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA9CDBA)),
                ),
                child: Row(children: [
                  const Icon(Icons.local_offer_rounded, color: Color(0xFF3E5F55), size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(offerText,
                    style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 13, fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            // ── Divider ──
            const Divider(color: Color(0xFFe8f5f0)),
            const SizedBox(height: 16),

            // ── Store section ──
            const Text("Sold by",
              style: TextStyle(color: Color(0xFF6b8c7e), fontSize: 12, fontWeight: FontWeight.w600,
                letterSpacing: .5)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: (storeName.isNotEmpty || storeId.isNotEmpty)
                ? () async {
                    // Fetch full store data so the detail page has images/rating/etc.
                    Map<String,dynamic> fullStore = storeData;
                    if (storeId.isNotEmpty) {
                      try {
                        final fetched = await Api.fetchStoreDetail(storeId);
                        if (fetched.isNotEmpty) {
                          fullStore = Map<String,dynamic>.from(fetched);
                          fullStore.putIfAbsent("_id", () => storeId);
                        }
                      } catch (_) {}
                    }
                    if (!context.mounted) return;
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => StoreDetailPage(
                        store: fullStore,
                        token: widget.token,
                        userName: "",
                        onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk))))));
                  }
                : null,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFd4e8de)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Builder(builder: (_) {
                  final storeRating = (storeData["rating"] as num?)?.toDouble() ??
                                      (storeData["admin_rating"] as num?)?.toDouble() ?? 0.0;
                  final storeDist   = (storeData["distance_km"] as num?)?.toDouble();
                  final distLabel   = storeDist != null
                    ? (storeDist < 1.0 ? "${(storeDist * 1000).toStringAsFixed(0)} m away"
                                       : "${storeDist.toStringAsFixed(1)} km away")
                    : "";
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      // Store avatar
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: storeIsActive ? const Color(0xFFe8f5f0) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(child: Text(
                          storeName.isNotEmpty ? storeName[0].toUpperCase() : "S",
                          style: TextStyle(
                            color: storeIsActive ? const Color(0xFF3E5F55) : const Color(0xFF9E9E9E),
                            fontSize: 22, fontWeight: FontWeight.w900))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(storeName,
                          style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 15, fontWeight: FontWeight.w800)),
                        if (storeArea.isNotEmpty || storeCat.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text("${storeCat.isNotEmpty ? storeCat : ''}${storeCat.isNotEmpty && storeArea.isNotEmpty ? '  ·  ' : ''}${storeArea}".trim(),
                            style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 12)),
                        ],
                        const SizedBox(height: 5),
                        Row(children: [
                          if (storeRating > 0) ...[
                            const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 13),
                            const SizedBox(width: 3),
                            Text(storeRating.toStringAsFixed(1),
                              style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 12, fontWeight: FontWeight.w700)),
                            if (distLabel.isNotEmpty) const SizedBox(width: 8),
                          ],
                          if (distLabel.isNotEmpty) ...[
                            const Icon(Icons.near_me_rounded, color: Color(0xFF3E5F55), size: 12),
                            const SizedBox(width: 3),
                            Text(distLabel,
                              style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ]),
                      ])),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF3E5F55), size: 22),
                    ]),
                    // ── Store inactive badge (shown only if store subscription expired) ──
                    if (!storeIsActive) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: .4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFFE65100)),
                          const SizedBox(width: 5),
                          const Text("Store Currently Inactive",
                            style: TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                  ]);
                }),
              ),
            ),

            const SizedBox(height: 28),

            // ── Rate & Review ──
            const Text("Rate & Review",
              style: TextStyle(color: Color(0xFF2c3e35), fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),

            // Star rating selector
            Row(children: [
              ...List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _userRating = i + 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    i < _userRating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFFFD700), size: 30)),
              )),
              const SizedBox(width: 8),
              Text(_userRating == 0 ? "Tap to rate" : ["","Poor","Fair","Good","Great","Excellent"][_userRating.toInt()],
                style: TextStyle(
                  color: _userRating == 0 ? const Color(0xFF9e9e9e) : const Color(0xFF3E5F55),
                  fontSize: 13, fontWeight: FontWeight.w600)),
            ]),

            const SizedBox(height: 12),

            // Review text field
            if (!_reviewSubmitted) ...[
              TextField(
                controller: _reviewCtrl,
                maxLines: 3,
                style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Share your experience with this product...",
                  hintStyle: const TextStyle(color: Color(0xFFa0b8b0), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF7FBF9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFd4e8de))),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFd4e8de))),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF3E5F55), width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_userRating > 0 && !_reviewSubmitting) ? _submitReview : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3E5F55),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _reviewSubmitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Submit Review", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFe8f5f0),
                  borderRadius: BorderRadius.circular(14)),
                child: const Row(children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF3E5F55), size: 20),
                  SizedBox(width: 10),
                  Text("Thanks for your review!", style: TextStyle(color: Color(0xFF2c3e35), fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ),

            const SizedBox(height: 100),
          ]),
        )),
      ]),
    );
  }
}

class _PremiumProductCard extends StatelessWidget {
  final Map<String,dynamic> product;
  final int colorIdx;
  const _PremiumProductCard({required this.product, this.colorIdx = 0});

  static const _fallbackColors = [
    [Color(0xFF3E5F55), Color(0xFF2c4a3e)],
    [Color(0xFF5D4037), Color(0xFF3E2723)],
    [Color(0xFF1565C0), Color(0xFF0D47A1)],
    [Color(0xFF6A1B9A), Color(0xFF4A148C)],
    [Color(0xFFC62828), Color(0xFFB71C1C)],
    [Color(0xFF00695C), Color(0xFF004D40)],
  ];

  Widget _buildImage() {
    final storeObj = product["store"];
    if (storeObj is Map) {
      for (final k in ["image2", "image", "photo"]) {
        final si = storeObj[k]?.toString() ?? "";
        if (si.startsWith("data:image")) {
          try { return Image.memory(base64Decode(si.split(",").last), fit: BoxFit.cover, width: double.infinity, height: double.infinity); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
        }
        final url = si.startsWith("/") ? kBaseUrl + si : si;
        if (url.startsWith("http")) {
          return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
            placeholder: (_, __) => Container(color: const Color(0xFFA9CDBA)),
            errorWidget: (_, __, ___) => _fallback());
        }
      }
    }
    for (final k in ["logo_url","logo_thumb","image_url","image_thumb","image2","image","logo"]) {
      final img = product[k]?.toString() ?? "";
      if (img.startsWith("data:image")) {
        try { return Image.memory(base64Decode(img.split(",").last), fit: BoxFit.cover, width: double.infinity, height: double.infinity); } catch (_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
      }
      final url = img.startsWith("/") ? kBaseUrl + img : img;
      if (url.startsWith("http")) {
        return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          placeholder: (_, __) => Container(color: const Color(0xFFA9CDBA)),
          errorWidget: (_, __, ___) => _fallback());
      }
    }
    return _fallback();
  }

  Widget _fallback() {
    final pal = _fallbackColors[colorIdx % _fallbackColors.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: pal, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title     = product["title"]?.toString() ?? "";
    final offerText = product["offer"]?.toString() ?? product["text"]?.toString() ?? "";
    final storeName = (product["store"] is Map ? product["store"]["store_name"] : null)?.toString()
        ?? product["store_name"]?.toString() ?? "";
    final discMatch = RegExp(r'(\d+)%').firstMatch(title + " " + offerText);
    final discLabel = discMatch != null ? "${discMatch.group(1)}% OFF" : "";

    return Container(
      width: 185,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .10), blurRadius: 18, offset: const Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(fit: StackFit.expand, children: [
          // Full-bleed image
          _buildImage(),
          // Bottom gradient
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: .55),
                Colors.black.withValues(alpha: .88),
              ],
              stops: const [0.0, 0.38, 0.70, 1.0],
            ),
          ))),
          // Discount badge top-left
          if (discLabel.isNotEmpty)
            Positioned(top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFe74c3c),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.25), blurRadius: 6)],
                ),
                child: Text(discLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ),
          // Bottom content
          Positioned(bottom: 12, left: 10, right: 10,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (storeName.isNotEmpty)
                Text(storeName,
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, height: 1.2,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black87)]),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (offerText.isNotEmpty && offerText != title) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: .25)),
                  ),
                  child: Text(offerText,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}


// ─────────────────────── VOUCHER VIEW ALL PAGE ───────────────────────
class ProductViewAllPage extends StatefulWidget {
  final List<Map<String,dynamic>> products; // initial list (may be partial)
  final String token;
  final String city; // city filter for full fetch
  const ProductViewAllPage({required this.products, this.token = "", this.city = ""});
  @override State<ProductViewAllPage> createState()=>_ProductViewAllPageState();
}
class _ProductViewAllPageState extends State<ProductViewAllPage>{
  String _cat = "All";
  String _query = "";
  bool   _fetching = true;
  List<Map<String,dynamic>> _all = [];

  @override void initState() {
    super.initState();
    _all = List<Map<String,dynamic>>.from(widget.products); // show passed list instantly
    _fetchAll();
  }

  // Fetch full product list from API filtered by city (home may have cached a partial set)
  Future<void> _fetchAll() async {
    try {
      final fresh = await Api.getProductCards(city: widget.city);
      if (mounted) setState(() {
        _all = List<Map<String,dynamic>>.from(fresh);
        _fetching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _fetching = false);
    }
  }

  List<String> get _cats {
    final s = {"All"};
    for(final v in _all){
      final c = v["category"]?.toString() ?? "";
      if(c.isNotEmpty) s.add(c);
    }
    return s.toList();
  }
  List<Map<String,dynamic>> get _filtered {
    var list = _cat == "All"
        ? _all
        : _all.where((v) => (v["category"]?.toString() ?? "") == _cat).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((v) =>
        (v["title"]?.toString() ?? "").toLowerCase().contains(q) ||
        (v["text"]?.toString() ?? "").toLowerCase().contains(q) ||
        (v["store_name"]?.toString() ?? "").toLowerCase().contains(q) ||
        ((v["store"] is Map ? v["store"]["store_name"] : null)?.toString() ?? "").toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(slivers: [
        // Glossy warm-tone SliverAppBar
        SliverAppBar(
          expandedHeight: 100,
          pinned: true,
          backgroundColor: const Color(0xFFFDFBF6),
          foregroundColor: kText,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: _VapSearchBar(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            title: const Text("See All Products",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kText)),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFFFDFBF6), Color(0xFFE7D7C8), Color(0xFFFDFBF6)],
                ),
              ),
              child: Stack(children: [
                Positioned(top: 0, left: 0, right: 0, child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: .4), Colors.transparent],
                    ),
                  ),
                )),
              ]),
            ),
          ),
        ),
        // Category filter chips row
        SliverToBoxAdapter(child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(children: _cats.map((cat) => GestureDetector(
              onTap: () => setState(() => _cat = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _cat == cat ? kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _cat == cat ? kPrimary : kBorder, width: 1.2),
                  boxShadow: _cat == cat
                    ? [BoxShadow(color: kPrimary.withValues(alpha: .25), blurRadius: 8, offset: const Offset(0,2))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 4)],
                ),
                child: Text(cat, style: TextStyle(
                  color: _cat == cat ? Colors.white : kMuted,
                  fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            )).toList()),
          ),
        )),
        // Content
        if (_fetching && _all.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2)))
        else if (_filtered.isEmpty)
          SliverFillRemaining(
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFE7D7C8), Color(0xFFFDFBF6)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_outlined, color: Color(0xFFB8A090), size: 40)),
              const SizedBox(height: 16),
              const Text("No products found",
                style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
            ])))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => ProductDetailCard(
                  product: Map<String,dynamic>.from(_filtered[i]),
                  colorIdx: i,
                ),
                childCount: _filtered.length,
              ),
            ),
          ),
      ]),
    );
  }
}


// ─────────────────────── VOUCHER SUPPORT WIDGETS ───────────────────────

class ProductDetailCard extends StatelessWidget {
  final Map product;
  final int colorIdx;
  const ProductDetailCard({required this.product, this.colorIdx = 0});

  static const List<List<Color>> _palettes = [
    [Color(0xFFCDEBD6), Color(0xFFA9CDBA)],
    [Color(0xFFE7D7C8), Color(0xFFD4B896)],
    [Color(0xFFD6EAF8), Color(0xFFAED6F1)],
    [Color(0xFFFDE8E8), Color(0xFFF1ABAB)],
    [Color(0xFFFFF3CD), Color(0xFFFFD966)],
    [Color(0xFFEDE7F6), Color(0xFFCE93D8)],
  ];

  // Try to load store image (same chain as before, no gift box fallback)
  Widget _imgWidget() {
    final storeObj = product["store"];
    if (storeObj is Map) {
      for (final k in ["image2","image","img","photo"]) {
        final si = storeObj[k]?.toString() ?? "";
        if (si.startsWith("data:image")) {
          try { return Image.memory(base64Decode(si.split(",").last), fit:BoxFit.cover, width:double.infinity, height:double.infinity, gaplessPlayback:true); } catch(_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
        }
        final siUrl = si.startsWith("/") ? "$kBaseUrl$si" : si;
        if (siUrl.startsWith("http")) {
          return CachedNetworkImage(imageUrl:siUrl, fit:BoxFit.cover, width:double.infinity, height:double.infinity,
            placeholder:(_,__)=>Container(color:const Color(0xFFCDEBD6)),
            errorWidget:(_,__,___)=>_brandedBg());
        }
      }
    }
    for (final key in ["logo_url","logo_thumb","logo","image_url","image_thumb","image2","store_image2","image","photo","img"]) {
      final img = product[key]?.toString() ?? "";
      if (img.startsWith("data:image")) {
        try { return Image.memory(base64Decode(img.split(",").last), fit:BoxFit.cover, width:double.infinity, height:double.infinity, gaplessPlayback:true); } catch(_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
      }
      final imgUrl2 = img.startsWith("/") ? "$kBaseUrl$img" : img;
      if (imgUrl2.startsWith("http")) {
        return CachedNetworkImage(imageUrl:imgUrl2, fit:BoxFit.cover, width:double.infinity, height:double.infinity,
          placeholder:(_,__)=>Container(color:const Color(0xFFCDEBD6)),
          errorWidget:(_,__,___)=>_brandedBg());
      }
    }
    return _brandedBg();
  }

  Widget _brandedBg() => Container(
    decoration:const BoxDecoration(
      gradient:LinearGradient(colors:[Color(0xFF3E5F55),Color(0xFF2a4a40)],begin:Alignment.topLeft,end:Alignment.bottomRight)),
  );

  void _openDetail(BuildContext context) {
    final title    = product["title"]?.toString() ?? "";
    final text     = product["text"]?.toString() ?? "";
    final _validRaw = product["validity"]?.toString() ?? "";
    // Guard: reject raw Dart template strings (e.g. "\${dt.day}", "months[...")
    final _validSafe = (_validRaw.contains(r'\${') || _validRaw.contains('months[') ||
        (_validRaw.contains('{') && _validRaw.contains('}'))) ? "" : _validRaw;
    String validity = _validSafe;
    if (_validSafe.isNotEmpty) {
      try {
        final _vdt = DateTime.parse(_validSafe);
        const _vmo = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
        validity = "\${_vdt.day} \${_vmo[_vdt.month-1]} \${_vdt.year}";
      } catch (_) {
        // Not ISO format — try dd/mm/yyyy or dd-mm-yyyy
        try {
          final parts = _validSafe.split(RegExp(r'[/\-]'));
          if (parts.length == 3) {
            const _vmo2 = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
            final d = int.parse(parts[0]); final m = int.parse(parts[1]); final y = int.parse(parts[2]);
            if (m >= 1 && m <= 12) validity = "\$d \${_vmo2[m-1]} \$y";
          }
        } catch (_) { validity = ""; } // suppress raw strings entirely
      }
    }
    final storeName = (product["store"] is Map ? product["store"]["store_name"] : null)?.toString()
        ?? product["store_name"]?.toString() ?? "";
    final pal = _palettes[colorIdx % _palettes.length];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // Banner image
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(height: 170, width: double.infinity, child: _imgWidget()),
          ),
          const SizedBox(height: 20),
          // Offer badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: pal, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(title.isNotEmpty ? title : "Special Offer",
              style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 15, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 14),
          if (text.isNotEmpty) Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF2c3e35), fontSize: 16, fontWeight: FontWeight.w700, height: 1.4)),
          if (storeName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.store_rounded, color: Color(0xFF6b8c7e), size: 15),
              const SizedBox(width: 5),
              Text(storeName, style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ],
          if (validity.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.calendar_today_rounded, color: Color(0xFF6b8c7e), size: 13),
              const SizedBox(width: 5),
              Text("Valid till: $validity", style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 12)),
            ]),
          ],
          const SizedBox(height: 24),
          // FIX 12: Replace "Got it" with "Download" button
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text("Close", style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3E5F55),
                side: const BorderSide(color: Color(0xFF3E5F55)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text("Download", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3E5F55),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final shareText = [
                  "🎁 OFFRO Product",
                  if (title.isNotEmpty) "Offer: $title",
                  if (text.isNotEmpty) text,
                  if (storeName.isNotEmpty) "Store: $storeName",
                  if (validity.isNotEmpty) "Valid till: $validity",
                  "Download OFFRO for exclusive deals!",
                ].join("\n");
                Share.share(shareText, subject: "OFFRO Product – $title");
              },
            )),
          ]),
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final title    = product["title"]?.toString() ?? "";
    final text     = product["text"]?.toString() ?? "";
    final _validRaw = product["validity"]?.toString() ?? "";
    // Guard: reject raw Dart template strings (e.g. "\${dt.day}", "months[...")
    final _validSafe = (_validRaw.contains(r'\${') || _validRaw.contains('months[') ||
        (_validRaw.contains('{') && _validRaw.contains('}'))) ? "" : _validRaw;
    String validity = _validSafe;
    if (_validSafe.isNotEmpty) {
      try {
        final _vdt = DateTime.parse(_validSafe);
        const _vmo = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
        validity = "\${_vdt.day} \${_vmo[_vdt.month-1]} \${_vdt.year}";
      } catch (_) {
        // Not ISO format — try dd/mm/yyyy or dd-mm-yyyy
        try {
          final parts = _validSafe.split(RegExp(r'[/\-]'));
          if (parts.length == 3) {
            const _vmo2 = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
            final d = int.parse(parts[0]); final m = int.parse(parts[1]); final y = int.parse(parts[2]);
            if (m >= 1 && m <= 12) validity = "\$d \${_vmo2[m-1]} \$y";
          }
        } catch (_) { validity = ""; } // suppress raw strings entirely
      }
    }
    final storeName = (product["store"] is Map
        ? product["store"]["store_name"]
        : null)?.toString() ?? product["store_name"]?.toString() ?? "";
    final priceRaw = product["price"]?.toString() ?? "";
    final origRaw  = product["original_price"]?.toString() ?? product["mrp"]?.toString() ?? "";
    final discount = product["discount"]?.toString() ?? "";
    final isBestSeller = (product["best_seller"] == true) ||
        (product["tag"]?.toString().toLowerCase() == "best seller");

    // Badge label + color
    String badgeLabel = "";
    Color  badgeColor = const Color(0xFFFF6B35);
    if (isBestSeller) {
      badgeLabel = "BEST SELLER";
      badgeColor = const Color(0xFFFFBF00);
    } else if (discount.isNotEmpty && discount != "0") {
      badgeLabel = "$discount% OFF";
      badgeColor = const Color(0xFFFF6B35);
    } else if (text.isNotEmpty) {
      badgeLabel = text.length > 10 ? text.substring(0,10) : text;
      badgeColor = kPrimary;
    }

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFd4e8de), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha:.08), blurRadius:12, offset: const Offset(0,4)),
            BoxShadow(color: Colors.white.withValues(alpha:.9),  blurRadius:1,  offset: const Offset(0,-1)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top: Product image with badge overlay ──
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: _imgWidget(),
              ),
            ),
            // Offer badge top-left
            if (badgeLabel.isNotEmpty)
              Positioned(top: 7, left: 7, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: badgeColor.withValues(alpha:.4), blurRadius:6)],
                ),
                child: Text(badgeLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                  maxLines: 1),
              )),
            // Heart icon top-right
            Positioned(top: 7, right: 7, child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:.85),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.12), blurRadius:4)],
              ),
              child: const Icon(Icons.favorite_border_rounded,
                color: Color(0xFF3E5F55), size: 14),
            )),
          ]),

          // ── Bottom: text content ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Product title
              Text(
                title.isNotEmpty ? title : (text.isNotEmpty ? text : "Special Offer"),
                style: const TextStyle(
                  color: Color(0xFF2c3e35), fontSize: 12, fontWeight: FontWeight.w800,
                  height: 1.2),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              if (storeName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(storeName,
                  style: const TextStyle(color: Color(0xFF6b8c7e), fontSize: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (validity.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text("Valid till $validity",
                  style: const TextStyle(
                    color: Color(0xFF3E5F55), fontSize: 10, fontWeight: FontWeight.w700)),
              ],
              if (priceRaw.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text("₹$priceRaw",
                    style: const TextStyle(
                      color: Color(0xFF2c3e35), fontSize: 14, fontWeight: FontWeight.w900)),
                  if (origRaw.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Text("₹$origRaw",
                      style: const TextStyle(
                        color: Color(0xFF9aada8), fontSize: 11,
                        decoration: TextDecoration.lineThrough)),
                  ],
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _VapSearchBar extends StatefulWidget {
  const _VapSearchBar();
  @override State<_VapSearchBar> createState() => _VapSearchBarState();
}

class _VapSearchBarState extends State<_VapSearchBar> {
  // Note: search is managed at page level; this just triggers setState via callback
  @override Widget build(BuildContext context) {
    // Find parent _ProductViewAllPageState via context
    final pageState = context.findAncestorStateOfType<_ProductViewAllPageState>();
    return Container(
      color: const Color(0xFFFDFBF6),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: TextField(
        onChanged: (v) {
          pageState?.setState(() => pageState._query = v);
        },
        style: const TextStyle(color: kText, fontSize: 13),
        cursorColor: kPrimary,
        decoration: InputDecoration(
          hintText: "Search products...",
          hintStyle: const TextStyle(color: kMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: kPrimary, size: 18),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kPrimary)),
        ),
      ),
    );
  }
}