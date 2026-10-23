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
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// ─────────────────────── SPLIT IMPORTS ───────────────────────
import 'core/constants/app_constants.dart';
import 'core/utils/image_url.dart';
import 'core/utils/geo.dart';
import 'core/utils/navigation.dart';
import 'core/utils/store_hours.dart';
import 'core/widgets/shimmer_box.dart';
import 'core/widgets/base64_image.dart';
import 'core/design/design.dart';
import 'screens/legal/privacy_policy_page.dart';
import 'core/services/api_service.dart';
import 'core/services/error_mapper.dart';
import 'core/services/fav_state.dart';
import 'core/services/prefs_service.dart';
import 'core/services/fcm_service.dart';
import 'core/models/offro_location.dart';
import 'core/services/location_service.dart';
import 'core/services/location_store.dart';
import 'screens/location/location_screen.dart';
import 'screens/location/location_access_gate.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/loading/location_loading_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'core/widgets/brand_logo.dart';
import 'screens/auth/login_screen.dart';
import 'screens/merchant/merchant_screens.dart';
import 'screens/favorites/favorites_page.dart';
import 'screens/store/store_detail_page.dart';
import 'screens/home/popup_campaign_overlay.dart';
import 'screens/home/influencer_section.dart';
import 'screens/influencer/my_influencer_profile.dart';
import 'screens/wallet/wallet_page.dart';
import 'screens/home/explore_tab.dart';
import 'screens/home/profile_tab.dart';
import 'screens/payment/payment_success_screen.dart';
import 'core/widgets/store_cards.dart';
import 'core/widgets/product_share_card.dart';
// Round 12 (Task 5): reuse the exact same full-screen deal-gallery opener
// StoreOffersSection ("Today's Offers" inside Store Detail) already uses,
// instead of duplicating that Navigator.push + FullScreenImageViewer logic
// here for the Home "Hot Deals" list.
import 'screens/store/widgets/store_offers_section.dart' show openDealGallery;

// ─────────────────────── CONFIG ───────────────────────
const kRazorpayKey = "rzp_live_SdiI6kcuZzZjsl";


// Brand colours (kPrimary, kLight, kAccent, kBeige, kBg, OffroColors.text, OffroColors.textMuted, OffroColors.border)
// now live only in core/constants/app_constants.dart.


// ─────────────────────── FCM (see core/services/fcm_service.dart) ───────────────────────
// ─────────────────────── API ───────────────────────

// ─────────────────────── NOTIFICATION NOTIFIER ───────────────────────
/// Global ValueNotifier — FCM handlers call .value++ to update badge in real time
final _unreadNotifier = ValueNotifier<int>(0);

// ── FIX 2: iOS app icon badge clearing ──
// The backend sends badge:1 in the APNs payload. When the user reads all
// notifications or presses Clear All, we reset the badge to 0 via a native
// method channel (offro/badge). Android doesn't use this — badge is managed
// by the notification shade automatically.
const _badgeChannel = MethodChannel('offro/badge');
Future<void> _clearIOSBadge() async {
  if (!Platform.isIOS) return;
  try {
    await _badgeChannel.invokeMethod('clearBadge');
  } catch (e) {
  }
}

// BUG FIX (Item 2 — iOS badge doesn't reflect real unread count): the
// backend used to send a hardcoded "badge": 1 in every push's APNs payload
// (routers/admin.py's _build_fcm_message), which iOS applies as an absolute
// value the instant the push is delivered — even while the app is
// backgrounded, with no app code involved — so 5 backgrounded pushes would
// still only ever show "1", never "5". The backend has no server-side
// per-device unread-count to send instead (unread state is tracked purely
// on-device via Prefs, same as the existing in-app bell badge), so the
// payload's badge key is now omitted entirely and the app asserts the true
// count itself via the same already-existing native method channel used by
// _clearIOSBadge() above — reusing Prefs.getUnreadCount(), the same source
// of truth the in-app bell badge already reads.
Future<void> _syncIOSBadgeCount(int n) async {
  if (!Platform.isIOS) return;
  try {
    await _badgeChannel.invokeMethod('setBadge', n);
  } catch (e) {
  }
}

// ─────────────────────── PREFS ───────────────────────

// Location selection / permission / GPS now live in ONE place:
// core/services/location_service.dart, core/services/location_store.dart and
// screens/location/ (LocationScreen, LocationAccessGate).


// ─────────────────────── NOTIFICATION NAVIGATION ───────────────────────
/// Handle navigation when a notification is tapped. Routes to the appropriate
/// screen based on the `screen` and `type` fields in the FCM data payload.
/// Falls back to NotificationsPage when no specific screen is specified.
void _handleNotificationNavigation(String screen, String type) {
  final nav = MyApp.navigatorKey.currentState;
  if (nav == null) {
    return;
  }

  // If screen field contains a route identifier, navigate accordingly.
  // For now, all notifications route to the NotificationsPage since the
  // backend doesn't yet send specific screen targets. When it does,
  // add cases here:
  //   case 'store_detail': nav.push(...StoreDetailPage(storeId: screen));
  //   case 'product_detail': nav.push(...ProductDetailPage(productId: screen));
  nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
}

// ─────────────────────── MAIN ───────────────────────
// Background FCM handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate needs Flutter binding for platform channels (SharedPreferences)
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // CASE 4: Background notification received without opening app.
  // On Android this fires reliably. On iOS it only fires for data-only messages.
  try {
    final title     = message.notification?.title ?? message.data['title'] ?? '';
    final body      = message.notification?.body  ?? message.data['body']  ?? '';
    final imageUrl  = message.data['image_url'] ?? message.data['image'] ?? '';
    final notifType = message.data['type'] ?? 'promo';
    final screen    = message.data['screen'] ?? '';
    final msgId     = message.messageId ?? '';
    if (title.isNotEmpty) {
      final saved = await Prefs.saveNotification(
        title: title, body: body, imageUrl: imageUrl,
        type: notifType, screen: screen, messageId: msgId,
      );
      if (saved) {
        await Prefs.incrementUnread();
        // Item 2: assert the real unread count as the iOS badge right away —
        // see _syncIOSBadgeCount's comment for why the payload can't do this.
        await _syncIOSBadgeCount(await Prefs.getUnreadCount());
      }
    }
  } catch (e) {
  }
}

Future<void> main() async {
  // ── STEP 0: Flutter binding MUST be first ──
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
  };

  // ── STEP 1: Firebase ──
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5), onTimeout: () {
      throw TimeoutException('Firebase.initializeApp() timed out after 5s');
    });
    firebaseReady = true;
  } catch (e, st) {
  }

  // ── STEP 2-8: All FCM/notification setup gated by firebaseReady ──
  if (firebaseReady) {
    try { FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler); } catch (e) { }
  }

  try {
    await initLocalNotifications()
        .timeout(const Duration(seconds: 3), onTimeout: () {
    });
    onLocalNotifTap = (payload) {
      _handleNotificationNavigation(payload, 'promo');
    };
  } catch (e) { }

  if (firebaseReady) {
    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false)
          .timeout(const Duration(seconds: 3), onTimeout: () {
      });
      await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true, announcement: false, carPlay: false, criticalAlert: false, provisional: false)
          .timeout(const Duration(seconds: 3));  // throws TimeoutException -> caught by try/catch below
      // ── DIAGNOSTIC: query tokens after a delay ──
      Future.delayed(const Duration(seconds: 10), () async {
        try {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
        } catch (e) { }
        try {
          final fcm = await FirebaseMessaging.instance.getToken();
        } catch (e) { }
      });
    } catch (e) { }

    try {
      // FIX: getInitialMessage() can hang indefinitely on iOS with the
      // FlutterSceneDelegate/UIScene migration (FlutterFire #17854).
      // A hang here blocks app startup past iOS's launch watchdog
      // timeout, which kills the app — looks like a crash on open.
      // Timeout after 3s so startup never blocks.
      final initialMsg = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        return null;
      });
      if (initialMsg != null) {
        final _it  = initialMsg.notification?.title ?? initialMsg.data['title'] ?? '';
        final _ib  = initialMsg.notification?.body  ?? initialMsg.data['body']  ?? '';
        final _ii  = initialMsg.data['image_url'] ?? initialMsg.data['image'] ?? '';
        final _iy  = initialMsg.data['type'] ?? 'promo';
        final _isc = initialMsg.data['screen'] ?? '';
        final _im = initialMsg.messageId ?? '';
        if (_it.isNotEmpty) {
          final saved = await Prefs.saveNotification(
            title: _it, body: _ib, imageUrl: _ii,
            type: _iy, screen: _isc, messageId: _im,
          );
          if (saved) {
            await Prefs.incrementUnread();
            await _syncIOSBadgeCount(await Prefs.getUnreadCount());
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationNavigation(_isc, _iy);
        });
      }
    } catch (e) {
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      try {
        // STEP 1: Extract complete payload
        final _t  = msg.notification?.title ?? msg.data['title'] ?? '';
        final _b  = msg.notification?.body  ?? msg.data['body']  ?? '';
        final _i  = msg.data['image_url'] ?? msg.data['image'] ?? '';
        final _y  = msg.data['type'] ?? 'promo';
        final _sc = msg.data['screen'] ?? '';
        final _mi = msg.messageId ?? '';
        // STEP 2: SAVE FIRST — independent of display. Even if showLocalNotification
        // throws, the notification is already in history.
        if (_t.isNotEmpty) {
          final saved = await Prefs.saveNotification(
            title: _t, body: _b, imageUrl: _i,
            type: _y, screen: _sc, messageId: _mi,
          );
          if (saved) {
            await Prefs.incrementUnread();
            _unreadNotifier.value++;
            await _syncIOSBadgeCount(await Prefs.getUnreadCount());
          }
        }

        // STEP 3: Display the notification banner (after save)
        showLocalNotification(msg);
      } catch (e) {
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) async {
      try {
        final _t  = msg.notification?.title ?? msg.data['title'] ?? '';
        final _b  = msg.notification?.body  ?? msg.data['body']  ?? '';
        final _i  = msg.data['image_url'] ?? msg.data['image'] ?? '';
        final _y  = msg.data['type'] ?? 'promo';
        final _sc = msg.data['screen'] ?? '';
        final _mi = msg.messageId ?? '';
        // Save (dedup via messageId ensures this won't double-save if background
        // handler already saved it)
        if (_t.isNotEmpty) {
          final saved = await Prefs.saveNotification(
            title: _t, body: _b, imageUrl: _i,
            type: _y, screen: _sc, messageId: _mi,
          );
          if (saved) {
            await Prefs.incrementUnread();
            await _syncIOSBadgeCount(await Prefs.getUnreadCount());
          }
        }
        // Navigate to the appropriate screen
        _handleNotificationNavigation(_sc, _y);
      } catch (e) {
      }
    });
  }

  // BUG FIX (Item 2 — "kill/reopen app must restore correct badge"): the OS
  // badge is a native, persistent value that lives outside Flutter/Prefs, so
  // if it was ever left out of sync (e.g. an older push still carrying a
  // stale hardcoded badge before this fix, or a delivery outside the app's
  // control), it would keep showing that stale number across app restarts
  // forever, never self-correcting. Every cold start now re-asserts the
  // badge from the real stored unread count exactly once, so the two can
  // never drift apart for more than a moment.
  try {
    await _syncIOSBadgeCount(await Prefs.getUnreadCount());
  } catch (e) { }

  try {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  } catch (e) { }
  runApp(const MyApp());
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
  //
  // Enters the customer Home.
  //
  // Uses the SAVED location (structured, persisted by LocationStore) — no
  // fresh GPS is forced. [city] is only a legacy fallback (older builds
  // persisted just a city string) and is migrated into the saved location.
  // If there is no saved location at all, the customer must choose one on
  // the Location screen before Home opens.
  static void goHome({required String token, required String name,
      required String phone, required String userId, required String city}) {
    // TASK 2 FIX: clear stale cache + save mode so all sections reload correctly
    Api.clearCache();
    if (token.isNotEmpty) Prefs.saveMode('user');
    unawaited(_enterHome(token: token, name: name, phone: phone, userId: userId, legacyCity: city));
  }

  static Future<void> _enterHome({
    required String token, required String name,
    required String phone, required String userId,
    String legacyCity = '',
  }) async {
    OffroLocation? saved = await LocationStore.load(LocationMode.customer);
    if (saved == null && legacyCity.trim().isNotEmpty) {
      saved = OffroLocation(
        city: legacyCity.trim(),
        state: LocationService.stateForCity(legacyCity),
        source: LocationSource.manual,
        updatedAt: DateTime.now(),
      );
      await LocationStore.save(LocationMode.customer, saved);
    }
    if (saved != null && saved.hasCity) {
      _pushLoader(token: token, name: name, phone: phone, userId: userId, city: saved.city);
      return;
    }

    // No saved location → the customer must choose one before Home.
    Future<void> onPicked(OffroLocation loc) async {
      await LocationStore.save(LocationMode.customer, loc);
      if (token.isNotEmpty) unawaited(Api.updateCity(token, loc.city, state: loc.state));
      _pushLoader(token: token, name: name, phone: phone, userId: userId, city: loc.city);
    }
    final access = await LocationService.status();
    final Widget first = access == LocationAccess.permissionDenied
        ? LocationAccessGate(mode: LocationMode.customer, onSelected: onPicked)
        : LocationScreen(mode: LocationMode.customer, mandatory: true, onSelected: onPicked);
    navigatorKey.currentState?.pushAndRemoveUntil(appRoute(first), (r) => false);
  }

  /// Fetches stores for [city] (pure loader — no location logic) then opens Home.
  static void _pushLoader({
    required String token, required String name,
    required String phone, required String userId, required String city,
  }) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      appRoute(LocationLoadingScreen(
        token: token, name: name, phone: phone, userId: userId, city: city,
        onReady: ({required String city, required List<Map<String,dynamic>> stores,
                   required double? lat, required double? lng,
                   bool fetchFailed = false}) =>
            goHomeWithData(token: token, name: name, phone: phone, userId: userId,
                city: city, stores: stores, lat: lat, lng: lng,
                fetchFailed: fetchFailed),
      )),
      (r) => false,
    );
  }

  /// Check/request the app location permission for the merchant Add Store
  /// "Current Location" button ONLY (store-address capture, a separate
  /// concern from the account/browsing location). It runs from an explicit
  /// tap on that button and is not used by login, Home or Merchant Home.
  static Future<bool> ensureLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  static void goLogin() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      appRoute(LoginScreen(
        onGuest: () {
          Prefs.saveGuest(true);
          Api.clearCache();
          unawaited(_enterHome(token: '', name: 'Guest', phone: '', userId: ''));
        },
        onSuccess: (tok, nm, ph, uid, role, city) async {
        if (role == 'merchant') {
          // Merchant role selected → straight to the merchant loader. The
          // MERCHANT ACCOUNT's location (mandatory, device-only) is enforced
          // inside MerchantHome itself, so every entry point (login, Switch
          // Mode, splash restore) is covered. It is independent of store
          // location, which is captured separately in AddEditStorePage.
          await _goMerchantViaUnified(merchantToken: tok, phone: ph, name: nm);
        } else if (role == 'influencer') {
          // C3: Influencer role selected. No new auth system, no location
          // gate — the existing C1/C2 flow already handles both "has a
          // profile" (shows it) and "no profile yet" (shows the existing
          // Add Influencer Profile form) once inside the module, using
          // only the authenticated token. Never a client-supplied
          // influencer_id/account_id.
          navigatorKey.currentState?.pushAndRemoveUntil(
            appRoute(InfluencerModuleScreen(
              token: tok, phone: ph, currentMode: 'influencer',
              onSwitchMode: (newRole) => goSwitchMode(tok, nm, ph, uid, newRole),
            )),
            (r) => false,
          );
        } else {
          // User role selected + Continue tapped → use the saved location
          // (no forced GPS). If none is saved, the Location screen is shown.
          Api.clearCache();
          unawaited(_enterHome(token: tok, name: nm, phone: ph, userId: uid));
        }
      })),
      (r) => false,
    );
  }

  /// Switch mode — called from SwitchModeSheet in user profile
  static void goSwitchMode(String token, String name, String phone, String userId, String role) {
    if (role == 'merchant') {
      _goMerchantViaUnified(phone: phone, name: name);
    } else if (role == 'influencer') {
      // C4: same authenticated account/token — no separate identity to
      // fetch (unlike User/Merchant, which issue a fresh role-specific
      // token below). Just navigates into the existing C1/C2-backed
      // Influencer module, which resolves everything from the token alone
      // — never a client-supplied influencer_id/account_id.
      _goInfluencerViaUnified(token: token, name: name, phone: phone, userId: userId);
    } else {
      // TASK 2 FIX: get a fresh user token so getWallet and user APIs work correctly
      _goUserViaUnified(phone: phone, name: name, userId: userId);
    }
  }

  static void _goInfluencerViaUnified({required String token, required String name, required String phone, required String userId}) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      appRoute(InfluencerModuleScreen(
        token: token, phone: phone, currentMode: 'influencer',
        onSwitchMode: (newRole) => goSwitchMode(token, name, phone, userId, newRole),
      )),
      (r) => false,
    );
  }

  /// Switch to user mode — issues a fresh user session token, then routes home.
  ///
  /// Home opens with the customer's SAVED location (no forced GPS); if none
  /// is saved the Location screen is shown first. The customer can change it
  /// any time from the Home location header.
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
      await Prefs.saveMode('user');
      goHome(token: '', name: name, phone: phone, userId: userId, city: '');
    }
  }

  /// Unified merchant flow: fresh login → merchant loader → merchant home.
  /// Called both from post-OTP flow and from Switch Mode.
  /// [merchantToken] — pass if we already have a valid merchant token (e.g. splash restore).
  /// [phone] — used to issue a fresh merchant token when switching from user mode.
  static Future<void> _goMerchantViaUnified({
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
        goLogin();
        return;
      }

      navigatorKey.currentState?.pushAndRemoveUntil(
        appRoute(MerchantLoadingScreen(
          token: token,
          merchant: merchantData,
          onReady: (tok, merch) {
            navigatorKey.currentState?.pushAndRemoveUntil(
              appRoute(MerchantHome(token: tok, merchant: merch)),
              (r) => false,
            );
          },
        )),
        (r) => false,
      );
    } catch (e) {
      // If merchant not registered, go to login so they can register
      goLogin();
    }
  }

  static void goHomeWithData({
    required String token, required String name, required String phone,
    required String userId,  required String city,
    required List<Map<String,dynamic>> stores,
    required double? lat,    required double? lng,
    bool fetchFailed = false,
  }) {
    final isGuest = token.isEmpty;
    navigatorKey.currentState?.pushAndRemoveUntil(
      appRoute(HomeScreen(
        token: token, name: name, phone: phone,
        savedCity: city, userId: userId,
        preloadedStores: stores,
        preloadFailed: fetchFailed,
        preloadedLat: lat, preloadedLng: lng,
        isGuest: isGuest,
      )),
      (r) => false,
    );
  }

  static void goOnboarding() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      appRoute(OnboardingScreen(onComplete: goLogin)),
      (r) => false,
    );
  }

  static void goMerchant({required String token, required Map merchant}) {
    navigatorKey.currentState?.pushAndRemoveUntil(
      appRoute(MerchantHome(token: token, merchant: merchant)),
      (r) => false,
    );
  }

  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: navigatorKey,
    navigatorObservers: [routeObserver],
    builder: (ctx, child) => Stack(
      children: [
        child!,
      ],
    ),
    theme: OffroTheme.light(),
    home: SplashScreen(
      onUser:       (token, name, phone, city, userId) => goHome(token: token, name: name, phone: phone, userId: userId, city: city),
      onMerchant:   (token, merchant) => goMerchant(token: token, merchant: merchant),
      onOnboarding: goOnboarding,
      onLogin:      goLogin,
    ),
  );
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
      try { return Image.memory(decodeBase64ImageCached(img),fit:BoxFit.cover,width:double.infinity,height:double.infinity,gaplessPlayback:true); }
      catch(_) { }
    }
    final imgUrl = resolveImageUrl(img);
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
        onTap:()=>Navigator.push(context,appRoute(StoreDetailPage(store:Map<String,dynamic>.from(s), token:token, userName:"", onProductTap:(p,tk)=>Navigator.push(context,appRoute(ProductDetailsPage(product:p,token:tk)))))),
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
                    const Icon(Icons.star_rounded,color:OffroColors.amber,size:10),const SizedBox(width:2),
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
  /// True when the pre-Home store request FAILED (preloadedStores is empty
  /// because nothing loaded, not because the city has no stores).
  final bool preloadFailed;
  final double? preloadedLat, preloadedLng;
  final bool isGuest;
  const HomeScreen({
    super.key,
    required this.token,
    required this.name,
    required this.phone,
    required this.savedCity,
    this.userId = "",
    this.preloadedStores = const [],
    this.preloadFailed = false,
    this.preloadedLat,
    this.preloadedLng,
    this.isGuest = false,
  });
  @override State<HomeScreen> createState() => _HomeState();
}
class _HomeState extends State<HomeScreen> with WidgetsBindingObserver {
  String city=""; bool cityDone=false; int _navIdx=0; String? _profilePhoto;
  String _noServiceImg=""; String _noServiceTitle=""; String _noServiceMsg="";
  bool _netError=false; bool _fetchFailed=false;
  bool _loadAllRunning=false; // FIX 4: prevent parallel _loadAll calls
  int _loadAllGen=0; // newest _loadAll wins: an older city's late response must not overwrite a newer city
  // /default-images is requested ONCE, early and independently of stores, so the
  // Admin No-Store image/message is ready the moment a city turns out empty.
  Future<Map<String,dynamic>>? _defaultsFuture;
  bool _noStoreReady=false;  // default-images succeeded OR its single retry was exhausted
  bool _noStoreFailed=false; // both attempts failed (≠ "Admin configured nothing")
  bool _isTimeout=false; // FIX 10: distinguish timeout from other errors
  bool _popupShown=false;

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
  OffroLocation? _loc; // structured saved location (display + persistence)
  Timer? _catTimer;
  String _cat="All"; bool _loading=true;
  List<Map<String,dynamic>> _stores=[]; List<String> _cats=["All"]; List<Map<String,dynamic>> _richCats=[];
  List<Map<String,dynamic>> _products=[];
  bool _productsLoading=true;
  double _radiusKm = 0.0; // Nearby radius filter (0=All, 1, 3, 5, 10)
  int _dealsNonce = 0; // bumped on pull-to-refresh to reload Exclusive Deals
  // ROUND 12 FIX (partial-Home fix): tracks ONLY the hero/city-image fetch
  // (the /default-images call inside _loadSupplementary()) — mirrors
  // the products flag's pattern so _CityHeroSection can show a shimmer
  // while its own photo is still loading instead of jumping straight to
  // the "no image" flat-gradient fallback look.
  bool _heroImageLoading=true;
  // ROUND 12 FIX (stale-request protection): bumped by every _loadSupplementary()
  // call. Each call captures its own value at start; if a newer call bumps this
  // before an older one finishes, the older call's results are dropped instead
  // of overwriting the newer call's state. Nothing is cancelled — old network
  // calls still run to completion, only their effect on state is suppressed.
  int  _supplementaryGen = 0;
  int  _unreadCount=0; // notification badge count
  final Set<String> _favStoreIds = {}; // track favorited stores
  int  _walletPoints=0; // wallet visit points
  // FIX 1: FAB scroll-aware visibility
  final ScrollController _scrollCtrl = ScrollController();
  final ValueNotifier<bool> _fabVisible = ValueNotifier<bool>(false);
  final Set<int> _builtTabs = {0}; // tabs shown at least once (lazy IndexedStack)
  final ValueNotifier<bool> _navVisible = ValueNotifier<bool>(true); // FIX 3: hide nav on scroll down
  List<Map<String,dynamic>> _sliders=[];
  String _cityImageUrl = ""; // fetched from /cities backend
  List<String> _cityImageUrls = []; // all city images for rotation
  int    _heroImgIndex = 0;          // current hero image index
  Timer? _heroRotateTimer;           // rotates hero image every 2 min
  List<String> _defaultProductImageUrls = []; // default product images from /admin/default-images (all configured)
  List<Map<String,dynamic>> _mbFallbackSliders = []; // default merchant banners (may be multiple, images OR videos)
  Timer? _sliderTimer;
  // FIX 2: ValueNotifier for slider page — avoids full-tree rebuild on swipe
  final ValueNotifier<int> _sliderPageNotifier = ValueNotifier<int>(0);

  // Stores marked "new_in_town" go to big carousel; they also appear in top stores
  // Backend already filters by city — no double-filtering here.
  // If store["city"] is empty or mismatched due to data entry, we still show it.
  // Category filtering is client-side only.
  List<Map<String,dynamic>> get _cityFiltered => _stores;

  void _recomputeDistances() {
    if (_userLat == null || _userLng == null) return;
    for (final s in _stores) {
      final lat = double.tryParse(s["latitude"]?.toString() ?? "");
      final lng = double.tryParse(s["longitude"]?.toString() ?? "");
      if (lat != null && lng != null) {
        s["distance_km"] = haversineKm(_userLat!, _userLng!, lat, lng);
      }
    }
  }

  // Nearby Stores: if GPS known, show stores within 5km sorted by distance.
  // If GPS unavailable, fall back to top 10 stores so section is never blank.
  // FIX (2026-07-10): This getter no longer applies _radiusKm — it only computes
  // distances and sorts. All radius filtering is done ONCE inside _NearbyStoresSection
  // so there is exactly one source of truth and no conflicting fallbacks.
  // City filtering is preserved via _cityFiltered.
  List<Map<String,dynamic>> get _nearbyStores {
    final base = _cityFiltered;
    if (_userLat == null || _userLng == null) return base; // GPS unavailable → show all
    final withCoords = <Map<String,dynamic>>[];
    final noCoords   = <Map<String,dynamic>>[];
    for (final s in base) {
      final lat = double.tryParse(s["latitude"]?.toString() ?? s["lat"]?.toString() ?? "");
      final lng = double.tryParse(s["longitude"]?.toString() ?? s["lng"]?.toString() ?? "");
      if (lat != null && lng != null) {
        s["distance_km"] = haversineKm(_userLat!, _userLng!, lat, lng);
        withCoords.add(s);
      } else {
        noCoords.add(s);
      }
    }
    withCoords.sort((a, b) {
      final da = (a["distance_km"] as num?)?.toDouble() ?? 9999.0;
      final db = (b["distance_km"] as num?)?.toDouble() ?? 9999.0;
      return da.compareTo(db);
    });
    // Stores without coords appended — appear only when "All" chip selected
    return [...withCoords, ...noCoords];
  }

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _loadRadius(); // load saved radius preference
    _loadUnreadCount(); // Issue 8: load notification badge
    _loadFavStores(); // load fav store ids for home screen hearts
    // Sync badge with real-time notifier (updates from FCM foreground messages)
    _unreadNotifier.addListener(_onUnreadChanged);
    FavState.instance.productRevision.addListener(_onFavChanged);
    // FIX 1: scroll listener for FAB visibility
    // Item 3: the "hide bottom nav on scroll down" behavior (previously
    // toggling _navVisible here) has been removed — the existing bottom
    // nav (Home | Deals | Scan | Search | Profile) now stays fixed/visible
    // while Home content scrolls. _navVisible itself, its ValueNotifier,
    // and the AnimatedPositioned that reads it are all untouched — this
    // only removes what was setting it to false.
    _scrollCtrl.addListener(() {
      final offset = _scrollCtrl.offset;
      // FAB: show when scrolled down > 120px
      _fabVisible.value = offset > 120;
    });
    unawaited(_loadSavedLocation());
    unawaited(_loadNoStoreContent());
    // Silent GPS check AFTER the first frame, so it can never delay Home.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_autoRefreshLocation());
    });
    if (widget.preloadedStores.isNotEmpty) {
      _usePreloadedData(); // async — clears _loading when done
      // Always fetch live GPS even when preloaded — ensures distance_km is computed
      _fetchLiveGpsAndRecomputeDistances();
    } else if (widget.savedCity.isNotEmpty) {
      // A city was already resolved BEFORE Home was reached — either via
      // GPS (LocationLoadingScreen's normal flow) or an explicit manual
      // State+City selection (AccountBootstrapScreen's mandatory fallback
      // when GPS/permission wasn't available). Either way, widget.savedCity
      // is an AUTHORITATIVE, already-known location for this session.
      //
      // An empty preloadedStores list here means "zero stores in that
      // city" (a valid, expected result — see _emptyState()/the "No
      // Service" UI below), NOT "location unavailable". It must never be
      // treated as a reason to re-run GPS/location-permission detection:
      // that would incorrectly show the "Location Access Required" screen
      // for a location the user (or GPS) already explicitly resolved, and
      // would silently discard a manually-selected city in favor of GPS.
      //
      // So this takes the same path as the non-empty-stores branch above,
      // just without the live-GPS distance refresh (there are no stores to
      // compute distance to, and firing a GPS/permission prompt here is
      // exactly the unwanted "second location request" this fix removes).
      _usePreloadedData(); // async — clears _loading when done; _stores stays []
    } else {
      // No city known at all (normally impossible — the entry flow requires a
      // location first). Ask for one on the Location screen; never read GPS.
      _requireLocation();
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
    if (_unreadNotifier.value == 0) _clearIOSBadge();
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
      FavState.instance.initStores(ids);
    } catch (_) { }
    try {
      final pids = await Api.getProductFavorites(widget.token);
      FavState.instance.initProducts(pids);
    } catch (_) { }
  }


  Future<void> _openNotifications(BuildContext ctx) async {
    await Prefs.clearUnread();
    _unreadNotifier.value = 0;
    await _clearIOSBadge();
    if (mounted) setState(() => _unreadCount = 0);
    await Navigator.push(ctx, appRoute(NotificationsPage()));
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
          s["distance_km"] = haversineKm(_userLat!, _userLng!, lat2, lng2);
        }
      }
      sl.sort((a, b) =>
          ((a["distance_km"] as double?) ?? 9999.0)
          .compareTo((b["distance_km"] as double?) ?? 9999.0));
    }

    // ROUND 11 FIX (Task 3, Candidate E): this used to keep `_loading` (and
    // therefore the FULL-SCREEN skeleton — see build()'s `_loading ? ... :`
    // branch) true until _loadSupplementary() below finished — i.e. until
    // categories, sliders, both product endpoints, wallet AND admin
    // banners had all come back, including two hard-coded 800ms/500ms retry
    // delays if any came back empty. City + the actual store list are
    // already fully known right here (LocationLoadingScreen already
    // resolved and fetched them), so there is no real reason for Home's
    // main content to keep waiting on that unrelated secondary data. Each
    // section below (_CategoryChipsRow, _BannerStoresBlock,
    // _DiscoverProductsSection, _PromoSliderSection, ...) already renders
    // straight from its own list (_richCats/_adminBanners/_products/
    // _sliders) with no separate loading flag, so it's safe to let those
    // populate independently — they simply show empty/skeleton for the
    // brief moment before _loadSupplementary's own setState (below) fills
    // them in, exactly like a normal incremental page load.
    // The loading screen reports a FAILED store request separately from a
    // genuinely empty city. Failed → show the error + Try Again state (no
    // stores were loaded, so never claim the city has none).
    final bool preloadFailed = widget.preloadFailed && sl.isEmpty;
    setState(() {
      city     = cityStr;
      _stores  = sl;
      _loading = false;
      if (preloadFailed) { _netError = false; _fetchFailed = true; }
    });
    if (cityStr.isNotEmpty) {
      Prefs.saveCity(cityStr);
    }

    if (!preloadFailed) {
      // Populate static cache with preloaded data
      _cachedCity   = cityStr;
      _cachedStores = List<Map<String,dynamic>>.from(sl);
      _cachedLat    = widget.preloadedLat;
      _cachedLng    = widget.preloadedLng;
      _cacheTime    = DateTime.now();

      // Fire-and-forget: secondary/supplementary content loads in the
      // background and fills in via its own setState once ready — Home's
      // main store content is already visible by this point (see above).
      unawaited(_loadSupplementary(cityStr));
    }
    // (On a failed preload, "Try Again" runs _fetchStores → _loadAll, which
    // loads the stores AND the supplementary content together.)
    FcmService.init(
      city: cityStr,
      token: widget.token,
      userId: widget.userId.isNotEmpty ? widget.userId : null,
      phone: widget.phone,
      onTokenReady: (t, {required String phone, required String userId}) =>
          Api.registerFcmToken(t, phone: phone, userId: userId),
    );
  }

  /// Single shared /default-images request with ONE automatic retry.
  /// `Api.getDefaultImages()` returns `{}` only on failure (a reachable
  /// server always sends a non-empty map, even when nothing is configured),
  /// so an empty result means FAILED. A successful result is cached for the
  /// session; a double failure is not cached, so a later user-triggered load
  /// can try again (never an endless loop).
  Future<Map<String,dynamic>> _defaults() {
    return _defaultsFuture ??= (() async {
      Map<String,dynamic> d = {};
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          d = await Api.getDefaultImages().timeout(const Duration(seconds: 10));
        } catch (_) { d = {}; }
        if (d.isNotEmpty) break;
        if (attempt == 1) await Future.delayed(const Duration(seconds: 2));
      }
      if (d.isEmpty) _defaultsFuture = null; // exhausted → allow a later retry
      return d;
    })();
  }

  /// Loads ONLY the Admin No-Store image/title/message — independent of the
  /// store, product, slider and banner requests.
  Future<void> _loadNoStoreContent() async {
    final defaults = await _defaults();
    if (!mounted) return;
    if (defaults.isEmpty) {
      // Request FAILED (twice). Not the same as "no image configured".
      setState(() { _noStoreReady = true; _noStoreFailed = true; });
      return;
    }
    final nsImgs = defaults["no_service_url"];
    String nsUrl = "";
    if (nsImgs is List && nsImgs.isNotEmpty) {
      nsUrl = nsImgs.last.toString().trim();
    } else if (nsImgs is String && nsImgs.trim().isNotEmpty) {
      nsUrl = nsImgs.trim();
    }
    final nsTitle = (defaults["no_service_title"] ?? "").toString().trim();
    final nsMsg   = (defaults["no_service_message"] ?? "").toString().trim();
    setState(() {
      _noStoreReady = true;
      _noStoreFailed = false;
      if (nsUrl.startsWith("http") || nsUrl.startsWith("data:image")) _noServiceImg = nsUrl;
      if (nsTitle.isNotEmpty) _noServiceTitle = nsTitle;
      if (nsMsg.isNotEmpty)   _noServiceMsg   = nsMsg;
    });
  }

  static bool _sameStrings(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) { if (a[i] != b[i]) return false; }
    return true;
  }

  /// Manual retry from the No-Store state after a failed content load.
  void _retryNoStoreContent() {
    setState(() { _noStoreReady = false; _noStoreFailed = false; });
    unawaited(_loadNoStoreContent());
  }

  // ── Home secondary data (categories, sliders, products, wallet, admin
  // banners, hero/default images) ─────────────────────────────────────────
  // QA round (Oct 2026) — rewritten so Home fills in ONE coordinated step:
  //   * every independent request starts at the same time (parallel),
  //     including /default-images, which used to run AFTER the others;
  //   * the duplicate product calls are gone (getPublicProducts and
  //     fetchPublicProducts hit the same /gift-vouchers-public URL, and the
  //     "<8 products" retries hit it twice more);
  //   * products, categories, sliders and banners are applied together in a
  //     single setState, and the Discover Products section shows a skeleton
  //     until then — default product images can no longer flash first;
  //   * default images are only waited for when they are actually needed as
  //     a fallback (no products or no sliders).
  // [coreLoaded]: _loadAll() already fetched categories/sliders/products
  // moments ago — don't fetch those again, only banners/wallet/defaults.
  Future<void> _loadSupplementary(String c, {bool coreLoaded = false}) async {
    // Stale-request protection (Round 12): only the newest call may write state.
    final myGen = ++_supplementaryGen;
    if (mounted && (!_productsLoading || (!_heroImageLoading && _cityImageUrl.isEmpty))) {
      setState(() {
        _productsLoading = true;
        // Hero shimmer only while there is NO hero URL yet — never flash it back on
        // a reload when the same hero image is already shown.
        if (_cityImageUrl.isEmpty) _heroImageLoading = true;
      });
    }
    try {
      List<String> cats2 = List<String>.from(_cats);
      List<Map<String,dynamic>> richCats2 = List<Map<String,dynamic>>.from(_richCats);
      List slides = coreLoaded ? List.from(_sliders) : [];
      List voucs  = coreLoaded ? List.from(_products) : [];
      Map<String,dynamic> wallet = {};
      final bool needCats    = !(coreLoaded && _richCats.isNotEmpty);
      final bool needSliders = !(coreLoaded && _sliders.isNotEmpty);
      final bool needProds   = !(coreLoaded && _products.isNotEmpty);
      if (needCats) { cats2 = ["All"]; richCats2 = []; }

      // /default-images starts NOW, in parallel with everything below. It
      // feeds the hero photo, fallback banners and the default-product
      // fallback. Applied in its own single setState as soon as it resolves.
      final Future<void> defaultsApplied = (() async {
        final Map<String,dynamic> defaults = await _defaults();
        if (!mounted || myGen != _supplementaryGen) return;

        List<String> cityImgs = [];
        final cityVal = defaults["city"];
        bool okHero(String v) => v.startsWith("http") || v.startsWith("data:image");
        if (cityVal is List) {
          cityImgs = cityVal.map((v) => v.toString().trim()).where(okHero).toList();
        } else if (cityVal is String && okHero(cityVal.trim())) {
          cityImgs = [cityVal.trim()];
        }
        if (cityImgs.isEmpty) {
          for (final key in ["city_image_url", "city_image", "hero_image_url", "image_url"]) {
            final v = (defaults[key] ?? "").toString().trim();
            if (okHero(v)) { cityImgs = [v]; break; }
          }
        }
        final nsImgs = defaults["no_service_url"];
        String nsUrl = "";
        if (nsImgs is List && nsImgs.isNotEmpty) {
          nsUrl = nsImgs.last.toString().trim();
        } else if (nsImgs is String && nsImgs.trim().isNotEmpty) {
          nsUrl = nsImgs.trim();
        }
        final nsTitle = (defaults["no_service_title"] ?? "").toString().trim();
        final nsMsg   = (defaults["no_service_message"] ?? "").toString().trim();
        // Default product images: full configured list (tolerates a legacy
        // single-string response).
        final defProdVal = defaults["product"];
        List<String> defProd = [];
        bool okImg(String v) => v.startsWith("http") || v.startsWith("data:image") || v.startsWith("data:video");
        if (defProdVal is List) {
          defProd = defProdVal.map((v) => v.toString().trim()).where(okImg).toList();
        } else if (defProdVal is String && defProdVal.trim().isNotEmpty && okImg(defProdVal.trim())) {
          defProd = [defProdVal.trim()];
        }
        // merchant_banner: array of URLs (images or mp4 videos)
        List<Map<String,dynamic>> mb = [];
        final mbRaw = defaults["merchant_banner"];
        if (mbRaw is List) {
          mb = mbRaw.where((u) => u is String && okImg(u)).map<Map<String,dynamic>>((u) {
            final uid = "mb_${(u as String).hashCode.abs()}";
            return {"id": uid, "title": "", "subtitle": "", "image": u, "image_url": u,
              "link_url": "", "bg_color": "", "sort_order": 0, "city": ""};
          }).toList();
        } else if (mbRaw is String && mbRaw.startsWith("http")) {
          mb = [{"id":"default","title":"","subtitle":"","image":mbRaw,"image_url":mbRaw,"link_url":"","bg_color":"","sort_order":0,"city":""}];
        }
        setState(() {
          _heroImageLoading = false;
          // Only replace when the list actually changed (keeps the shown hero + rotation stable).
          if (cityImgs.isNotEmpty && !_sameStrings(_cityImageUrls, cityImgs)) {
            _cityImageUrls = cityImgs; _cityImageUrl = cityImgs[0]; _heroImgIndex = 0;
          }
          if ((nsUrl.startsWith("http") || nsUrl.startsWith("data:image"))) _noServiceImg = nsUrl;
          if (nsTitle.isNotEmpty) _noServiceTitle = nsTitle;
          if (nsMsg.isNotEmpty)   _noServiceMsg   = nsMsg;
          if (defProd.isNotEmpty) _defaultProductImageUrls = defProd;
          _mbFallbackSliders = mb;
        });
        _startHeroRotation();
      })().catchError((_) {
        // A malformed /default-images payload must never leave the hero
        // shimmer spinning or block the fallback decision below.
        if (mounted && myGen == _supplementaryGen) setState(() { _heroImageLoading = false; });
      });

      // Core data — all in parallel. Each future guards its own failure so
      // one bad endpoint can't blank the others.
      await Future.wait([
        if (needCats) Api.fetchCategories().then((v) {
          final raw = v as List;
          richCats2 = raw.map((e) => e is Map ? Map<String,dynamic>.from(e) : <String,dynamic>{"name":e.toString(),"icon":"🏪","image_url":"","subtitle":""}).toList();
          cats2 = ["All", ...richCats2.map((e) => e["name"].toString())];
        }).catchError((_) {}),
        if (needSliders) Api.getSliders().then((v) async {
          slides = v as List;
          if (slides.isEmpty) { // race-condition retry, now concurrent with the rest
            await Future.delayed(const Duration(milliseconds: 800));
            try { slides = await Api.getSliders(); } catch (_) { }
          }
        }).catchError((_) {}),
        // ONE products request (getPublicProducts + fetchPublicProducts were
        // the same endpoint; merging them by title returned the same list).
        // A single retry only when the first response is genuinely empty.
        if (needProds) Api.getPublicProducts(city: c).then((v) async {
          voucs = v as List;
          if (voucs.isEmpty) {
            try { voucs = await Api.getPublicProducts(city: c); } catch (_) { }
          }
        }).catchError((_) {}),
        Api.getWallet(widget.token).then((v) => wallet = v as Map<String,dynamic>).catchError((_) {}),
      ]);

      if (!mounted || myGen != _supplementaryGen) return;

      // City filter for promo sliders
      if (c.isNotEmpty) {
        slides = slides.where((s) {
          final sCity = (s["city"] ?? "").toString().trim().toLowerCase();
          return sCity.isEmpty || sCity == c.toLowerCase().trim();
        }).toList();
      }
      // TASK 6 FIX: filter out expired products (end_date in past)
      final now6 = DateTime.now();
      voucs = voucs.where((v) {
        final endRaw = (v["end_date"] ?? v["validity_end"] ?? "").toString();
        if (endRaw.isEmpty) return true;
        try { return DateTime.parse(endRaw).isAfter(now6); } catch (_) { return true; }
      }).toList();
      // City filter: only products matching the current city
      if (c.isNotEmpty) {
        voucs = voucs.where((v) {
          final vCity = (v["city"] ?? v["store_city"] ?? "").toString().trim().toLowerCase();
          return vCity.isEmpty || vCity == c.toLowerCase().trim();
        }).toList();
      }

      // Default images are only needed as a fallback. If there ARE real
      // products and sliders we don't wait for them at all.
      if (slides.isEmpty || voucs.isEmpty) await defaultsApplied;
      if (!mounted || myGen != _supplementaryGen) return;

      // Fallback — no active banners for the city: default merchant banners
      if (slides.isEmpty && _mbFallbackSliders.isNotEmpty) {
        slides = List<Map<String,dynamic>>.from(_mbFallbackSliders);
      }
      final sliderList  = List<Map<String,dynamic>>.from(slides);
      final productList = List<Map<String,dynamic>>.from(voucs);
      for (int i = 0; i < sliderList.length; i++)  sliderList[i]["_idx"]  = i;
      for (int i = 0; i < productList.length; i++) productList[i]["_idx"] = i;

      // ONE setState: categories, sliders, banners, products and wallet
      // appear in the same frame.
      setState(() {
        if (cats2.length > 1 || _cats.length <= 1) _cats = List<String>.from(cats2);
        if (richCats2.isNotEmpty) _richCats = richCats2;
        else if (_richCats.isEmpty) Api.clearCache(); // force refetch next time
        _sliders             = sliderList;
        _products            = productList;
        _productsLoading     = false;
        _walletPoints        = (wallet["visit_points"] as num?)?.toInt() ?? 0;
        _recomputeDistances();
      });
      _startSliderAutoPlay();
      _startHeroRotation();
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndShowPopup());
    } catch (e) {
      // Never leave a section stuck on its loading skeleton.
      if (mounted && myGen == _supplementaryGen) {
        setState(() { _productsLoading = false; _heroImageLoading = false; });
      }
    }
  }

  Future<void> _checkAndShowPopup() async {
    if (_popupShown || !mounted) return;
    _popupShown = true;
    final c = city.isNotEmpty ? city : widget.savedCity;
    await showPopupCampaignIfNeeded(context: context, city: c, token: widget.token);
  }

  Future<void> _loadAll(String c) async {
    // FIX 4: Guard against parallel _loadAll calls (race condition prevention)
    if (_loadAllRunning) {
      return;
    }

    // ── Cache hit: same city + fresh data → show instantly, refresh in bg ──
    final sameCity = c.toLowerCase().trim() == _cachedCity.toLowerCase().trim();
    if (sameCity && _hasFreshCache) {
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
    final int myLoad = ++_loadAllGen;
    unawaited(_loadNoStoreContent()); // no-op if already loaded

    if(mounted) setState((){_loading=true; _netError=false; _fetchFailed=false;});
    // FIX 6: Retry up to 3 times with 2s backoff
    List storeList = [];
    bool storeFetchFailed = false;
    bool isNetworkError = false;
    bool isTimeoutError = false;
    Object? storeFetchError; // last failure, used to word the refresh message

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        if (attempt > 1) {
          await Future.delayed(const Duration(seconds: 2));
          Api.clearCache(); // clear cache before retry
        }
        storeList = await Api.fetchStores(city: c);
        storeFetchFailed = false;
        break; // success
      } on SocketException catch(e) {
        storeFetchError = e;
        isNetworkError = true;
        storeFetchFailed = true;
        if (attempt == 3 && mounted) {
          _loadAllRunning = false;
          setState((){_loading=false; _netError=true; _fetchFailed=true;});
          return;
        }
      } on TimeoutException catch(e) {
        storeFetchError = e;
        isTimeoutError = true;
        storeFetchFailed = true;
        // On timeout: clear cache and retry
        Api.clearCache();
      } catch(e) {
        storeFetchError = e;
        storeFetchFailed = true;
      }
    }

    // A newer city selection started while this request was in flight → drop it.
    if (myLoad != _loadAllGen) return;

    // If all 3 attempts failed
    if (storeFetchFailed && storeList.isEmpty) {
      if (mounted) {
        _loadAllRunning = false;
        // A refresh (or city change) that fails while stores are already on
        // screen must NOT blank Home or claim "no stores": keep the content
        // and say what happened. The full-screen error state below is only
        // for the case where there is nothing to show.
        final bool hadContent = _stores.isNotEmpty;
        setState((){
          _loading=false;
          if (!hadContent) {
            _netError = isNetworkError;
            _fetchFailed = true;
          }
          _productsLoading = false;
        });
        if (hadContent) {
          final raw = (storeFetchError ?? "").toString();
          final bool offline = storeFetchError is SocketException ||
              storeFetchError is TimeoutException ||
              ["SocketException", "Failed host lookup", "Network is unreachable",
               "ClientException", "Connection", "Handshake", "TimeoutException", "timed out"]
                  .any(raw.contains);
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(SnackBar(
            content: Text(offline
                ? "Unable to connect. Please check your internet connection and try again."
                : "Couldn't refresh stores. Please try again."),
          ));
        }
      }
      return;
    }

    // SUCCESSFUL response with zero stores → show the Admin No-Store state NOW.
    // (Do not wait for categories / sliders / products / retries below.)
    if (storeList.isEmpty && mounted) {
      setState(() {
        _stores = [];
        _loading = false;
        _netError = false;
        _fetchFailed = false;
        _isTimeout = false;
      });
    }

    // Fetch everything else in parallel (non-critical — fail silently)
    List cats = ["All"]; List<Map<String,dynamic>> richCats3 = []; List slides = []; List voucs = [];
    try {
      // FIX 5: guard each future individually
      await Future.wait([
        Api.fetchCategories().then((v) {
          final raw = v as List;
          richCats3 = raw.map((e) => e is Map ? Map<String,dynamic>.from(e) : <String,dynamic>{"name":e.toString(),"icon":"🏪","image_url":"","subtitle":""}).toList();
          cats = ["All", ...richCats3.map((e) => e["name"].toString())];
        }).catchError((_) {}),
        Api.getSliders().then((v) => slides = v as List).catchError((_) {}),
        // ONE products request. fetchPublicProducts hits the same
        // /gift-vouchers-public URL, so it is no longer fired in parallel;
        // the wallet is fetched by _loadSupplementary() (its only consumer).
        Api.getPublicProducts(city: c).then((v) => voucs = v as List).catchError((_) {}),
      ]);
    } catch(e) {
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
    if (myLoad != _loadAllGen) return; // superseded by a newer city

    final sl = List<Map<String,dynamic>>.from(storeList);
    if(_userLat != null && _userLng != null) {
      for(final s in sl){
        final lat = double.tryParse(s["latitude"]?.toString()??"");
        final lng = double.tryParse(s["longitude"]?.toString()??"");
        if(lat!=null && lng!=null) s["distance_km"] = haversineKm(_userLat!,_userLng!,lat,lng);
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
      } catch(e) {
      }
    }
    // Last-resort retry (FIX 4c) — only when nothing was returned. With 1-7
    // products the first request already succeeded, and this would just
    // re-request the same endpoint.
    if (voucs.isEmpty) {
      try {
        final pubProds = await Api.fetchPublicProducts(city: c);
        final existingTitles = Set<String>.from(
            voucs.map((x) => (x["title"] ?? x["name"] ?? "").toString().toLowerCase()));
        for (final p in pubProds) {
          final t = (p["title"] ?? p["name"] ?? "").toString().toLowerCase();
          if (!existingTitles.contains(t)) { voucs.add(p); existingTitles.add(t); }
        }
      } catch(e) {
      }
    }
    final productList = List<Map<String,dynamic>>.from(voucs);
    for(int i=0;i<productList.length;i++) productList[i]["_idx"] = i;
    // FIX: retry sliders once if empty (banner race condition)
    if (slides.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 800));
      try { slides = await Api.getSliders(); } catch (_) { }
    }
    final sliderList = List<Map<String,dynamic>>.from(slides);
    for(int i=0;i<sliderList.length;i++) sliderList[i]["_idx"] = i;

    // City-filter banners immediately — prevents other-city banners flashing on screen
    final List<Map<String,dynamic>> filteredSliders;
    if (c.isNotEmpty) {
      final cf = sliderList.where((s) {
        final sCity = (s["city"] ?? "").toString().trim().toLowerCase();
        return sCity.isEmpty || sCity == c.toLowerCase().trim();
      }).toList();
      for (int i = 0; i < cf.length; i++) cf[i]["_idx"] = i;
      filteredSliders = cf;
    } else {
      filteredSliders = sliderList;
    }

    // Update static cache
    _cachedCity   = c;
    _cachedStores = List<Map<String,dynamic>>.from(sl);
    _cachedLat    = _userLat;
    _cachedLng    = _userLng;
    _cacheTime    = DateTime.now();

    setState((){
      _stores   = sl;
      if (cats.length > 1 || _cats.length <= 1) _cats = List<String>.from(cats);
        if (richCats3.isNotEmpty) _richCats = richCats3;
        else if (_richCats.isEmpty) Api.clearCache(); // force refetch
      // Apply city-filtered sliders; use fallback if empty and URL already known
      _sliders  = filteredSliders.isNotEmpty ? filteredSliders
          : (_mbFallbackSliders.isNotEmpty ? List<Map<String,dynamic>>.from(_mbFallbackSliders) : filteredSliders);
      _products = productList;
      _productsLoading = false;
      _loading  = false;
      _fetchFailed = false;
    });
    _recomputeDistances(); // called after setState so _stores is committed before mutation

    _loadAllRunning = false;
    _startSliderAutoPlay();
    // FIX 6: trigger hero + admin banners load immediately on first open
    _loadSupplementary(c, coreLoaded: true);
    if(mounted) setState((){_isTimeout=false;});
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
    try { final d=await Api.getMe(widget.token); if(mounted&&d!=null) setState(()=>_profilePhoto=d["photo"]?.toString()); } catch(_){ }
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

  // The hero is ONE fixed card; only its media layer changes (crossfade).
  void _advanceHeroSlide(){
    if(!mounted || _sliders.length < 2) return;
    _sliderPageNotifier.value = (_sliderPageNotifier.value + 1) % _sliders.length;
  }

  // Hero video is tap-to-play: once the customer starts one, stop the timed
  // rotation until it finishes, then resume (finish -> next slide).
  void _onHeroVideoPlayStarted(){ _sliderTimer?.cancel(); }
  void _heroVideoDone(){
    _advanceHeroSlide();
    _startSliderAutoPlay();
  }

  void _startSliderAutoPlay(){
    _sliderTimer?.cancel();
    // Auto-play even for 1 item (will loop to same) — only skip if empty
    if(_sliders.isNotEmpty){
      _sliderTimer=Timer.periodic(const Duration(seconds:10),(_){
        _advanceHeroSlide();
      });
    }
  }
  // _startProductSlide — removed (not needed)

  // ── Location (single system: LocationScreen + LocationStore) ───────────
  // Display/selection only — store filtering stays CITY-based (`city`).

  OffroLocation get _effectiveLoc =>
      (_loc != null && _loc!.sameCity(city))
          ? _loc!
          : OffroLocation(city: city, state: LocationService.stateForCity(city));
  String get _locTitle => city.isEmpty ? "Select location" : _effectiveLoc.title;
  String get _locSubtitle => city.isEmpty ? "" : _effectiveLoc.subtitle;

  /// Loads the saved structured location for the header (never changes `city`).
  Future<void> _loadSavedLocation() async {
    final saved = await LocationStore.load(LocationMode.customer);
    if (!mounted || saved == null) return;
    setState(() {
      _loc = saved;
    });
  }

  /// Home location header tap → the shared Location screen.
  bool _locScreenOpen = false;
  Future<void> _openLocationScreen() async {
    if (_locScreenOpen) return; // no double-open / loops
    _locScreenOpen = true;
    final OffroLocation? picked;
    try {
      picked = await Navigator.push<OffroLocation>(
        context,
        MaterialPageRoute<OffroLocation>(
          builder: (_) => LocationScreen(mode: LocationMode.customer, current: _effectiveLoc),
        ),
      );
    } finally {
      _locScreenOpen = false;
    }
    if (picked == null || !mounted) return;
    await _applyLocation(picked);
  }

  /// Persists [loc], updates the header and reloads Home when the city changed.
  Future<void> _applyLocation(OffroLocation loc) async {
    final oldCity = city;
    final cityChanged = !loc.sameCity(oldCity);
    await LocationStore.save(LocationMode.customer, loc);
    if (!mounted) return;
    final gps = loc.source == LocationSource.gps && loc.lat != null && loc.lng != null;
    setState(() {
      _loc = loc;
      city = loc.city;
      if (gps) { _userLat = loc.lat; _userLng = loc.lng; }
    });
    if (gps) _recomputeDistances();
    if (widget.token.isNotEmpty) {
      unawaited(Api.updateCity(widget.token, loc.city, state: loc.state));
      FcmService.updateCityTopic(loc.city, oldCity: oldCity);
    }
    if (cityChanged) await _fetchStores(loc.city);
  }

  // Silent refresh of a saved GPS location (app open / resume), same service
  // call Merchant Home uses. Skips manual cities, never prompts, keeps the
  // saved location on any failure; 2-min throttle + 1.5 km threshold are
  // enforced inside LocationService.autoRefreshIfMoved.
  bool _autoLocBusy = false;
  Future<void> _autoRefreshLocation() async {
    if (_autoLocBusy || _locScreenOpen || !mounted) return;
    _autoLocBusy = true;
    try {
      final saved = await LocationStore.load(LocationMode.customer);
      final fresh = await LocationService.autoRefreshIfMoved(saved);
      if (fresh == null || !mounted || _locScreenOpen) return;
      await _applyLocation(fresh);
    } catch (_) {
      // keep the current location
    } finally {
      _autoLocBusy = false;
    }
  }

  /// Only reached when Home is created with no city (normally impossible).
  void _requireLocation() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final picked = await Navigator.push<OffroLocation>(
        context,
        MaterialPageRoute<OffroLocation>(
          builder: (_) => const LocationScreen(mode: LocationMode.customer, mandatory: true),
        ),
      );
      if (picked == null || !mounted) return;
      await _applyLocation(picked);
    });
  }

  Future<void> _fetchLiveGpsAndRecomputeDistances() async {
    // Called when preloaded data is used — refreshes distance_km from live GPS.
    // SILENT: reads GPS only when device Location Services are on AND the app
    // permission is already granted. It never shows a permission dialog and
    // never changes the saved/selected city.
    try {
      final pos = await LocationService.silentPosition(
        timeout: const Duration(seconds: 12),
        accuracy: LocationAccuracy.high,
      );
      if (pos == null || !mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        // Recompute distance_km on all store maps in-place
        for (final s in _stores) {
          final lat = double.tryParse(s["latitude"]?.toString() ?? s["lat"]?.toString() ?? "");
          final lng = double.tryParse(s["longitude"]?.toString() ?? s["lng"]?.toString() ?? "");
          if (lat != null && lng != null) {
            s["distance_km"] = haversineKm(pos.latitude, pos.longitude, lat, lng);
          }
        }
      });
      // Persist for next session
      Prefs.saveLocation(pos.latitude, pos.longitude);
    } catch (e) {
    }
  }

  // Called ONLY when the city changes — category changes are client-side only
  Future<void> _fetchStores(String c) async {
    _loadAllRunning = false; // reset guard so city change always goes through
    // Also drop Home's own 5-minute store cache (same reset a city change does) —
    // otherwise _loadAll() would "refresh" from memory and never hit the
    // network, which made pull-to-refresh a silent no-op.
    _cachedCity   = "";
    _cachedStores = [];
    _cacheTime    = null;
    Api.clearCache();
    await _loadAll(c);
  }


  // _startSlide removed — _pc was orphaned, not connected to any PageView in build



  void _onFavChanged() { if (mounted) setState(() {}); }

  @override void dispose() {
    FavState.instance.productRevision.removeListener(_onFavChanged);
    _unreadNotifier.removeListener(_onUnreadChanged);
    WidgetsBinding.instance.removeObserver(this);
    _catTimer?.cancel(); _sliderTimer?.cancel(); _heroRotateTimer?.cancel();
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
      // Silent GPS check on return to the app (throttled inside the service).
      unawaited(_autoRefreshLocation());
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearbyStores = _nearbyStores; // GPS-aware, sorted by distance
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: OffroColors.background,
      ),
      child: PopScope(
       canPop: _navIdx == 0,
       onPopInvokedWithResult: (didPop, _) { if (!didPop) setState(() => _navIdx = 0); },
       child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: OffroColors.background,
        body: Stack(children: [
              IndexedStack(index: _navIdx, children: [
              _loading
              ? LayoutBuilder(builder: (ctx, bc) => SizedBox(
                  width: bc.maxWidth,
                  height: bc.maxHeight.isFinite ? bc.maxHeight : MediaQuery.sizeOf(ctx).height,
                  child: ColoredBox(
                    color: OffroColors.background,
                    child: _buildLoadingSkeleton(),
                  ),
                ))
              : _cityFiltered.isEmpty
                ? _emptyState()
                : Column(children: [
                  // Figma header: logo + bell, then "Exploring <location>"
                  _HomeHeader(
                    locationTitle: _locTitle,
                    locationSubtitle: _locSubtitle,
                    unreadCount: _unreadCount,
                    onCityTap: _openLocationScreen,
                    onBellTap: () => _openNotifications(context),
                  ),
                  Expanded(child: RefreshIndicator(
                  onRefresh: () { setState(() => _dealsNonce++); return _fetchStores(city); },
                  color: kPrimary,
                  child: CustomScrollView(controller: _scrollCtrl, slivers:[

                    // ══════ 1. SEARCH (opens the existing store search) ══════
                    SliverToBoxAdapter(child: _HomeSearchBar(onTap: () => _searchStores(context))),

                    // ══════ 2. HERO — the single promotional area (promo sliders; city artwork fallback) ══════
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: _CityHeroSection(
                        city: city,
                        cityImageUrl: _cityImageUrl,
                        // while the hero photo is loading, shimmer instead of the flat fallback
                        imageLoading: _heroImageLoading,
                        onCtaTap: () => _searchStores(context),
                        sliders: _sliders,
                        sliderPageNotifier: _sliderPageNotifier,
                        token: widget.token,
                        onAdvance: _heroVideoDone,
                        onVideoPlayStarted: _onHeroVideoPlayStarted,
                      ),
                    )),

                    // ══════ 3. CATEGORIES ══════
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: _CategoryChipsRow(
                        cats: _richCats,
                        token: widget.token,
                        userLat: _userLat,
                        userLng: _userLng,
                        selectedCity: city,
                        onMoreTap: () => Navigator.push(context, appRoute(_BrowseAllCategoriesScreen(
                          token: widget.token,
                          userLat: _userLat, userLng: _userLng,
                          selectedCity: city))),
                      ),
                    )),

                    // ══════ 4. STORES NEAR YOU (real stores, distance chips, existing Store Detail) ══════
                    SliverToBoxAdapter(child: _NearbyStoresSection(
                      stores: nearbyStores,
                      radiusKm: _radiusKm,
                      token: widget.token,
                      onRadiusChanged: (km) async {
                        setState(() => _radiusKm = km);
                        await Prefs.saveRadius(km);
                      },
                      onViewAll: () => _viewAll(context, "Nearby Stores", nearbyStores),
                      onStoreTap: (s) => Navigator.push(context, appRoute(
                        StoreDetailPage(store: _enrichStoreForDetail(Map<String,dynamic>.from(s)), token: widget.token, userName: "", onProductTap:(p,tk)=>Navigator.push(context,appRoute(ProductDetailsPage(product:p,token:tk)))))).then((_) => _loadFavStores()),
                    )),

                    // ══════ 5. PRODUCTS NEAR YOU ══════
                    SliverToBoxAdapter(child: _DiscoverProductsSection(
                      products: _products,
                      onViewAll: () => _viewAllProducts(context),
                      token: widget.token,
                      defaultProductImageUrls: _defaultProductImageUrls,
                      // True until the real product request finishes — shows a
                      // skeleton instead of the default images (no flash).
                      loading: _productsLoading,
                    )),

                    // ══════ 6. EXCLUSIVE DEALS (existing /deals/all) ══════
                    SliverToBoxAdapter(child: _ExclusiveDealsSection(
                      key: ValueKey("deals_${city}_$_dealsNonce"),
                      city: city,
                      token: widget.token,
                      onViewAll: () => Navigator.push(context, appRoute(_AllDealsScreen(token: widget.token, city: city))),
                    )),

                    // ══════ 7. REWARDS (real wallet points) ══════
                    SliverToBoxAdapter(child: _HomeRewardsCard(
                      points: _walletPoints,
                      onTap: () {
                        if (!_requireLogin(context, 'My Rewards')) return;
                        Navigator.push(context, appRoute(WalletPage(token: widget.token)));
                      },
                    )),

                    // ══════ 8. LOCAL VOICES (screens/home/influencer_section.dart) ══════
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: CityInfluencersSection(city: city, token: widget.token),
                    )),

                    const SliverToBoxAdapter(child: SizedBox(height: 124)),
                  ]),
                )),
                ]),
              // ── Tabs 1–4 (built lazily, state kept while switching) ──
              _builtTabs.contains(1)
                  ? ExploreTab(
                      stores: _cityFiltered,
                      city: city,
                      token: widget.token,
                      onStoreTap: (s) => Navigator.push(context, appRoute(
                        StoreDetailPage(store: _enrichStoreForDetail(Map<String,dynamic>.from(s)), token: widget.token, userName: "", onProductTap:(p,tk)=>Navigator.push(context,appRoute(ProductDetailsPage(product:p,token:tk)))))).then((_) => _loadFavStores()),
                    )
                  : const SizedBox.shrink(),
              _builtTabs.contains(2)
                  ? _AllDealsScreen(key: ValueKey("tab_deals_${city}_$_dealsNonce"), token: widget.token, city: city, embedded: true)
                  : const SizedBox.shrink(),
              _builtTabs.contains(3)
                  ? WalletPage(token: widget.token, embedded: true)
                  : const SizedBox.shrink(),
              _builtTabs.contains(4) ? _profileTab() : const SizedBox.shrink(),
              ]),

            // Scroll-to-top FAB (Home tab only)
            if (_navIdx == 0) Positioned(
              bottom: 104, right: 16,
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

            // ══ BOTTOM NAV (Figma) — Home | Explore | Deals | Rewards | Profile ══
            // QR is no longer a tab; it stays inside Store Detail. Same
            // show/hide behaviour as before (_navVisible + empty-state hide).
            ValueListenableBuilder<bool>(
              valueListenable: _navVisible,
              builder: (_, visible, child) => AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                bottom: (visible && (_navIdx != 0 || _cityFiltered.isNotEmpty || _loading)) ? 0 : -140,
                left: 0, right: 0,
                child: child!,
              ),
              child: OffroBottomNav(
                items: _customerNavItems(),
                currentIndex: _navIdx,
                onTap: _onNavTap,
              ),
            ),
          ]),
      ),
     ),
    );
  }



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
        appRoute(ContinueAsScreen(
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
      color: OffroColors.background,
      padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + bottomPad),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Button 1 — Back to Home (primary: kPrimary bg, white icon + text)
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            // No-Store (successful load, zero stores) → the Location screen so
            // the customer can pick another city / current location. Error
            // states keep the previous behaviour.
            onPressed: (!_netError && !_isTimeout && !_fetchFailed)
                ? () { _openLocationScreen(); }
                : _goRoleSelect,
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
      // Shown if the image itself can't be loaded: the Admin message (if any)
      // on the brand colour — never a blank box without explanation.
      Widget nsFallback() => Container(
            color: kPrimary,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _noServiceMsg.isEmpty
                ? null
                : Text(_noServiceMsg,
                    style: const TextStyle(color: kLight, fontSize: 15),
                    textAlign: TextAlign.center),
          );
      Widget nsImgWidget;
      if (_noServiceImg.startsWith("data:image")) {
        // Shared base64 helper: same Uint8List per source → decoded once, and
        // Flutter's image cache hits on every rebuild.
        try {
          nsImgWidget = Image.memory(
            decodeBase64ImageCached(_noServiceImg),
            fit: BoxFit.cover, width: double.infinity, height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => nsFallback());
        } catch (_) { nsImgWidget = nsFallback(); }
      } else {
        // Same cached loader as the Hero: disk + memory cache, no re-download
        // on rebuilds.
        nsImgWidget = CachedNetworkImage(
          imageUrl: _noServiceImg,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheWidth: 1080,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, __) => const ColoredBox(
            color: kPrimary,
            child: Center(child: SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white54))),
          ),
          errorWidget: (_, __, ___) => nsFallback(),
        );
      }
      return Column(children: [Expanded(child: nsImgWidget), footer]);
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
          ] else if (_noServiceMsg.isNotEmpty)
            // Successful load with zero stores → the Admin Dashboard "No
            // Store" message (same _noServiceMsg as before; no hard-coded
            // "No stores in <city> yet" text any more).
            Text(_noServiceMsg, style: const TextStyle(color: kLight, fontSize: 15), textAlign: TextAlign.center)
          else if (_noStoreFailed) ...[
            // default-images could not be loaded (after one retry). Say so —
            // do NOT imply the Admin has no image configured.
            const Icon(Icons.cloud_off_rounded, color: Colors.white54, size: 40),
            const SizedBox(height: 10),
            const Text("Couldn't load this page", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _retryNoStoreContent,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
              child: const Text('Retry'),
            ),
          ]
          else if (!_noStoreReady)
            // Admin No Store content (/default-images) is still loading —
            // wait quietly instead of flashing placeholder text first.
            const SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white54)),
          // Failure states (and only those) get a Try Again action.
          if (_netError || _isTimeout || _fetchFailed) ...[
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () => _fetchStores(city),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.refresh_rounded, size: 18),
                SizedBox(width: 8),
                Text('Try Again', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
            ),
          ],
        ]))),
        footer,
      ]),
    );
  }



  // ── Customer bottom navigation (Figma) ───────────────────────────────
  List<OffroNavItem> _customerNavItems() {
    final base = OffroBottomNav.customerItems;
    final photo = _profilePhoto;
    final name = widget.name;
    return [
      base[0], base[1], base[2], base[3],
      OffroNavItem(
        label: 'Profile',
        icon: OffroIcons.user,
        iconBuilder: (active) {
          ImageProvider? img;
          if (photo != null && photo.startsWith("data:image")) {
            img = MemoryImage(decodeBase64ImageCached(photo));
          } else if (photo != null && photo.startsWith("http")) {
            img = NetworkImage(photo);
          }
          if (img == null) {
            return OffroIcon(OffroIcons.user, size: 19,
                color: active ? OffroColors.primary : OffroColors.secondarySolid);
          }
          return Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? OffroColors.primary : Colors.transparent, width: 1.5),
            ),
            child: CircleAvatar(
              radius: 9.5,
              backgroundColor: OffroColors.mint,
              backgroundImage: img,
              child: null,
            ),
          );
        },
      ),
    ];
  }

  // Bottom nav: Home | Explore | Deals | Rewards | Profile. Each tab now
  // renders in place (the floating nav stays visible); Rewards is still
  // login-gated exactly as before.
  void _onNavTap(int i) {
    if (i == 3 && !_requireLogin(context, 'My Rewards')) return;
    setState(() { _navIdx = i; _builtTabs.add(i); });
  }

  // Home search bar / hero CTA → Explore tab (store search lives there).
  void _searchStores(BuildContext ctx) => _onNavTap(1);

  Future<void> _showInfoDialog(String title, Future<String> Function() load, {String fallback = ""}) async {
    final c = await load();
    if (!mounted) return;
    showDialog(context: context, builder: (_) => OffroDialog(title: title, body: c.isEmpty ? fallback : c));
  }

  void _openSwitchMode() {
    showModalBottomSheet(
      context: MyApp.navigatorKey.currentContext ?? context,
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
  }

  // Profile tab — same actions the old profile sheet offered.
  Widget _profileTab() {
    void gated(String feature, VoidCallback go) { if (_requireLogin(context, feature)) go(); }
    return ProfileTab(
      token: widget.token,
      name: widget.name,
      phone: widget.phone,
      isGuest: widget.isGuest,
      savedCount: _favStoreIds.length,
      points: _walletPoints,
      activity: [
        ProfileEntry(icon: OffroIcons.heart, label: "My Favourites", note: "Stores you saved",
          onTap: () => gated("My Favourites", () => Navigator.push(context, appRoute(FavoritesPage(token: widget.token))).then((_) => _loadFavStores()))),
        ProfileEntry(icon: OffroIcons.gift, label: "My Rewards", note: "Reward points and vouchers",
          onTap: () => _onNavTap(3)),
        ProfileEntry(icon: OffroIcons.clock, label: "Scan History", note: "Points earned at stores",
          onTap: () => gated("Scan History", () => Navigator.push(context, appRoute(HistoryPage(token: widget.token))))),
        ProfileEntry(icon: OffroIcons.bell, label: "Notifications", note: "Offers, rewards and account updates",
          onTap: () => Navigator.push(context, appRoute(NotificationsPage()))),
      ],
      account: [
        if (!widget.isGuest)
          ProfileEntry(icon: OffroIcons.sparkles, label: "Switch Mode", note: "Switch between User & Merchant",
            onTap: _openSwitchMode),
        ProfileEntry(icon: OffroIcons.message, label: "Contact Offro", note: "Chat with us on WhatsApp",
          onTap: () async {
            final s = await Api.getSocialLinks();
            final rawWa = s["whatsapp"] ?? "";
            if (rawWa.isNotEmpty) {
              final digits = rawWa.replaceAll(RegExp(r'[^0-9]'), '');
              final waNum = digits.length >= 10 ? (digits.length == 10 ? "91$digits" : digits) : digits;
              await launchUrl(Uri.parse("https://wa.me/$waNum"), mode: LaunchMode.externalApplication);
            }
          }),
      ],
      legal: [
        ProfileEntry(icon: OffroIcons.store, label: "About Us",
          onTap: () => _showInfoDialog("About Us", Api.getAboutUs,
            fallback: "Offro connects local stores with customers through deals and loyalty points.")),
        ProfileEntry(icon: OffroIcons.tag, label: "Terms & Conditions",
          onTap: () => _showInfoDialog("Terms & Conditions", () => Api.fetchTerms("user"))),
        ProfileEntry(icon: OffroIcons.shield, label: "Privacy Policy", note: "Includes delete account",
          onTap: () => Navigator.push(context, appRoute(PrivacyPolicyPage(token: widget.token)))),
        ProfileEntry(icon: OffroIcons.route, label: "Refund Policy",
          onTap: () => _showInfoDialog("Refund Policy", () => Api.fetchPolicy("refund"))),
      ],
      sessionAction: widget.isGuest
          ? ProfileEntry(icon: OffroIcons.user, label: "Login / Register",
              onTap: () async {
                await Prefs.clearGuest();
                Api.clearCache();
                MyApp.goLogin();
              })
          : ProfileEntry(icon: OffroIcons.arrow, label: "Logout", destructive: true,
              onTap: () async {
                await Prefs.clear();
                FcmService.reset();
                Api.clearCache();
                // Use navigatorKey so OnboardingScreen gets the goLogin callback
                MyApp.goOnboarding();
              }),
    );
  }

  bool _requireLogin(BuildContext ctx, String featureName) {
    if (!widget.isGuest) return true;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: OffroColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const Icon(Icons.lock_outline_rounded, color: kPrimary, size: 40),
          const SizedBox(height: 16),
          const Text('Login Required',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: OffroColors.text)),
          const SizedBox(height: 8),
          Text('Please login or register to use $featureName.',
            style: const TextStyle(fontSize: 14, color: OffroColors.textMuted, height: 1.5)),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Prefs.clearGuest();
                MyApp.goLogin();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Login / Register',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Maybe later', style: TextStyle(color: OffroColors.textMuted, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
    return false;
  }

  // View All page
  // Cast _products to proper type for ProductViewAllPage
  void _viewAllProducts(BuildContext ctx) =>
    Navigator.push(ctx, appRoute(ProductViewAllPage(
      products: _products.map((v)=>Map<String,dynamic>.from(v as Map)).toList(),
      token: widget.token,
      city: city)));

  void _viewAll(BuildContext ctx, String title, List<Map<String,dynamic>> stores, {bool bigCards=false}) =>
    Navigator.push(ctx, appRoute(_ViewAllPage(title:title, stores:stores, token:widget.token, bigCards:bigCards)));
}

// ─────────────────────── VIEW ALL PAGE ───────────────────────

// ─────────────────────── SEARCH PAGE ───────────────────────
// Retired: search now lives in the Explore tab (screens/home/explore_tab.dart).
// ignore: unused_element
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
      backgroundColor: OffroColors.background,
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
                Text("No results for '$_q'",style:const TextStyle(color:OffroColors.textMuted,fontSize:15)),
              ]))
            : ListView.separated(
                padding:const EdgeInsets.all(14),
                separatorBuilder:(_,__)=>const SizedBox(height:8),
                itemCount:_results.length,
                itemBuilder:(_,i){
                  final s=_results[i];
                  String img=s["image_url"]?.toString()??''; if(img.isEmpty)img=s["image_thumb"]?.toString()??''; if(img.isEmpty)img=s["image"]?.toString()??''; if(img.isEmpty)img=s["image2"]?.toString()??'';
                  return GestureDetector(
                    onTap:()=>Navigator.push(context,appRoute(StoreDetailPage(store:Map<String,dynamic>.from(s), token:widget.token, userName:"", onProductTap:(p,tk)=>Navigator.push(context,appRoute(ProductDetailsPage(product:p,token:tk)))))),
                    child:Container(padding:const EdgeInsets.all(12),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha: .05),blurRadius:8,offset:const Offset(0,2))]),
                      child:Row(children:[
                        ClipRRect(borderRadius:BorderRadius.circular(10),child:SizedBox(width:62,height:62,
                          child:img.isNotEmpty&&img.startsWith("data:image")
                            ? Image.memory(decodeBase64ImageCached(img),fit:BoxFit.cover)
                            : Container(color:kAccent,child:const Icon(Icons.store,color:kPrimary,size:28)))),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(s["store_name"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:OffroColors.text,fontSize:14)),
                          Text("${s['category']??''} · ${s['area']??''}",style:const TextStyle(color:OffroColors.textMuted,fontSize:12)),
                          if ((s['visit_points']??0)>0) Padding(padding:const EdgeInsets.only(top:3),
                            child:Text("${s['visit_points']} pts on visit",style:const TextStyle(color:kPrimary,fontSize:11,fontWeight:FontWeight.w600))),
                        ])),
                        const Icon(Icons.arrow_forward_ios_rounded,color:OffroColors.border,size:14),
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
    if(_stores.isEmpty) return const Center(child:Text("No stores yet",style:TextStyle(color:OffroColors.textMuted)));
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
    final scrH = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: OffroColors.background,
      appBar: AppBar(
        backgroundColor: OffroColors.background,
        foregroundColor: OffroColors.text,
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
                style: const TextStyle(color:OffroColors.text, fontSize:14),
                decoration: InputDecoration(
                  hintText: "Search store, area, offer...",
                  hintStyle: const TextStyle(color:OffroColors.textMuted, fontSize:13),
                  prefixIcon: const Icon(Icons.search, color:OffroColors.textMuted, size:20),
                  suffixIcon: _q.isNotEmpty ? IconButton(icon:const Icon(Icons.clear,size:18,color:OffroColors.textMuted), onPressed:(){_searchCtrl.clear();setState(()=>_q="");}) : null,
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
            Text(_q.isEmpty?"No stores yet":"No results for '$_q'",style:const TextStyle(color:OffroColors.textMuted,fontSize:15))]))
        : ListView.builder(
            padding:const EdgeInsets.fromLTRB(14,8,14,24),
            itemCount:filtered.length,
            itemBuilder:(_,i)=>Padding(
              padding:const EdgeInsets.only(bottom:10),
              child:GestureDetector(
                onTap:()=>Navigator.push(context,appRoute(StoreDetailPage(store:Map<String,dynamic>.from(filtered[i]), token:widget.token, userName:"", onProductTap:(p,tk)=>Navigator.push(context,appRoute(ProductDetailsPage(product:p,token:tk)))))),
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
    // BUG FIX (Item 2 — iOS badge stuck after reading): this is the ONE
    // place that always runs whenever the Notifications page is opened,
    // regardless of entry path (home-screen bell tap via _openNotifications
    // — which already did this two lines below — OR tapping a push
    // notification directly via _handleNotificationNavigation, which pushes
    // this same page WITHOUT going through _openNotifications). The direct-
    // from-push path never reset _unreadNotifier or called _clearIOSBadge(),
    // so the real iOS home-screen badge stayed stuck at whatever value the
    // last push delivered — this is the actual root cause of "badge remains
    // after reading" for that entry path. Doing it here as well (harmless,
    // idempotent, if _openNotifications also just ran it) closes the gap
    // for every current and future way of reaching this page.
    _unreadNotifier.value = 0;
    await _clearIOSBadge();
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
      await Prefs.clearUnread();
      _unreadNotifier.value = 0;
      await _clearIOSBadge();
      if (mounted) setState(() => _notifs = []);
    }
  }

  // BUG FIX (Round 4 — Bug 2, "time shown is wrong"): backend timestamps
  // are UTC, but historically serialized without an explicit timezone
  // suffix. DateTime.parse() treats a timezone-less string as LOCAL time
  // instead of UTC, which on an IST (UTC+5:30) device silently shifted the
  // parsed instant, making a fresh timestamp look ~5.5h old. Force UTC
  // interpretation whenever the string has no timezone marker of its own —
  // correct for both old (naive) and new (explicit "Z") timestamps.
  String _timeAgo(String isoTs) {
    try {
      final s = isoTs.trim();
      final hasTzMarker = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(s);
      final dt   = DateTime.parse(hasTzMarker ? s : '${s}Z');
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
      backgroundColor: OffroColors.background,
      appBar: AppBar(
        backgroundColor: OffroColors.background,
        foregroundColor: OffroColors.text,
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
                  Icon(Icons.notifications_none_rounded, size: 64, color: OffroColors.textMuted.withValues(alpha: .4)),
                  const SizedBox(height: 16),
                  const Text("No notifications yet", style: TextStyle(color: OffroColors.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text("You'll see deals and alerts here", style: TextStyle(color: OffroColors.textMuted, fontSize: 13)),
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
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 240),
                                    child: imgUrl.startsWith("data:image")
                                      ? Image.memory(decodeBase64ImageCached(imgUrl), width: double.infinity, fit: BoxFit.contain, gaplessPlayback: true)
                                      : CachedNetworkImage(imageUrl: imgUrl, width: double.infinity, fit: BoxFit.contain,
                                          placeholder: (_, __) => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: kPrimary))),
                                          errorWidget: (_, __, ___) => const SizedBox(height: 80, child: Icon(Icons.broken_image_outlined, color: OffroColors.textMuted, size: 40))),
                                  ),
                                ),
                              if (imgUrl.isNotEmpty) const SizedBox(height: 14),
                              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: OffroColors.text)),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(body, style: const TextStyle(fontSize: 14, color: OffroColors.textMuted, height: 1.5)),
                              ],
                              if (ts.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(_timeAgo(ts), style: const TextStyle(fontSize: 11, color: OffroColors.textMuted)),
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
                      color: OffroColors.background,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Notification icon or image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52, height: 52,
                            child: imgUrl.isNotEmpty
                                ? (imgUrl.startsWith("data:image")
                                    ? Image.memory(decodeBase64ImageCached(imgUrl), fit: BoxFit.cover, gaplessPlayback: true)
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
                            Expanded(child: Text(title, style: const TextStyle(color: OffroColors.text, fontSize: 14, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (ts.isNotEmpty) Text(_timeAgo(ts), style: const TextStyle(color: OffroColors.textMuted, fontSize: 11)),
                          ]),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(body, style: const TextStyle(color: OffroColors.textMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
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
            style: TextStyle(color: OffroColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
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
              Navigator.push(context, appRoute(_CategoryListScreen(cats: merged, token: token, userLat: userLat, userLng: userLng, selectedCity: selectedCity)));
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
                  Icon(Icons.add_rounded, color: OffroColors.text, size: 32),
                  SizedBox(height: 4),
                  Text("View", style: TextStyle(
                    color: OffroColors.text,
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
    Navigator.push(context, appRoute(_CategoryStoresScreen(
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
      _rawImg = resolveImageUrl(_rawImg);
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
          _imgBytes = decodeBase64ImageCached(_rawImg);
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

// FIX (2026-07-09): root cause of "type 'String' is not a subtype of type
// 'num?' in type cast" crash on the category-stores screen — some store
// records have latitude/longitude stored as a String instead of a number.
// A direct `as num?` cast throws in that case; this helper accepts either.
double? _safeDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
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
  // FIX: surface real failures instead of silently showing "No stores found"
  // for both network/parsing errors AND genuine zero-match cases.
  String? _error;
  int _totalFetchedInCity = 0;
  List<String> _categoriesSeen = [];

  @override void initState() { super.initState(); _load(); }

  @override void didUpdateWidget(_CategoryStoresScreen old) {
    super.didUpdateWidget(old);
    if (old.categoryName != widget.categoryName) {
      setState(() { _stores = []; _loading = true; _q = ""; });
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() { _error = null; });
    try {
      // Fetch ALL city stores — same call as home screen, reuses its 3-min cache instantly.
      // We then apply flexible client-side filtering so category mismatches in the DB
      // (e.g. "Restaurants" saved when admin label is "Restaurant") never cause empty screens.
      final all = await Api.fetchStores(city: widget.selectedCity);
      final catLower = widget.categoryName.toLowerCase().trim();

      final filtered = List<Map<String,dynamic>>.from(
        all.where((s) {
          final sc = (s["category"] ?? "").toString().toLowerCase().trim();
          if (sc.isEmpty) return false;
          // Exact match → starts-with (handles plurals) → contains (handles compound names)
          return sc == catLower
              || sc.startsWith(catLower)
              || catLower.startsWith(sc)
              || sc.contains(catLower)
              || catLower.contains(sc);
        }),
      );

      // Compute distance_km client-side if GPS is available
      // FIX (2026-07-09): was `(m["latitude"] as num?)` — crashes with
      // "type 'String' is not a subtype of type 'num?' in type cast" when a
      // store's lat/lng is stored as a String. _safeDouble() handles both.
      final result = filtered.map((s) {
        final m = Map<String,dynamic>.from(s);
        if (widget.userLat != null && widget.userLng != null && m["distance_km"] == null) {
          final lat = _safeDouble(m["latitude"]) ?? _safeDouble(m["lat"]);
          final lng = _safeDouble(m["longitude"]) ?? _safeDouble(m["lng"]);
          if (lat != null && lng != null) {
            final dist = haversineKm(widget.userLat!, widget.userLng!, lat, lng);
            m["distance_km"] = double.parse(dist.toStringAsFixed(1));
          }
        }
        return m;
      }).toList();

      // FIX: diagnostic info so a genuine zero-match (as opposed to a fetch
      // failure) is immediately explainable on-screen — no DB access needed.
      final catsSeen = all
          .map((s) => (s["category"] ?? "").toString().trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      if (mounted) {
        setState(() {
          _stores = result;
          _totalFetchedInCity = all.length;
          _categoriesSeen = catsSeen;
          _loading = false;
        });
      }
    } catch (e) {
      // FIX: was a silent swallow (`catch (_)`) — a real crash/network error
      // looked EXACTLY like "no stores in this category," making the two
      // impossible to tell apart. Now the real reason is shown on-screen.
      // Round 9: shown through the shared classifier so the reason is
      // never a raw exception/stack trace.
      debugPrint('[OffrO] category stores load error: $e');
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _loading = false;
        });
      }
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
      backgroundColor: OffroColors.background,
      appBar: AppBar(
        backgroundColor: OffroColors.background,
        foregroundColor: OffroColors.text,
        title: Text(widget.categoryName,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: OffroColors.text)),
        elevation: 0,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: "Search ${widget.categoryName} stores...",
              hintStyle: const TextStyle(color: OffroColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: kPrimary, size: 20),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: OffroColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: OffroColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
            ),
          ),
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            // FIX: real fetch/crash failure — now shown explicitly with Retry,
            // instead of looking identical to "0 stores in this category".
            : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFc0392b), size: 40),
                    const SizedBox(height: 10),
                    const Text("Couldn't load stores", style: TextStyle(color: OffroColors.text, fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: OffroColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () => setState(() { _loading = true; _load(); }),
                      style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                      child: const Text("Retry"),
                    ),
                  ]),
                ))
              : _filtered.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text("No ${widget.categoryName} stores found",
                        style: const TextStyle(color: OffroColors.textMuted, fontSize: 14)),
                    // FIX: diagnostic — reveals the actual category strings stored
                    // in this city so a text-mismatch (e.g. "Restaurant " with a
                    // trailing space, or a wrong category assigned to a store) is
                    // visible on-screen immediately, without needing DB access.
                    if (_totalFetchedInCity > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        "Found $_totalFetchedInCity store(s) in this city, but none matched \"${widget.categoryName}\".",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: OffroColors.textMuted, fontSize: 11)),
                      if (_categoriesSeen.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Categories found: ${_categoriesSeen.join(', ')}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: OffroColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ]),
                ))
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
                        onProductTap:(p,tk)=>Navigator.push(context,appRoute(ProductDetailsPage(product:p,token:tk))),
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
      backgroundColor: OffroColors.background,
      appBar: AppBar(
        backgroundColor: OffroColors.background,
        foregroundColor: OffroColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text("Categories",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: OffroColors.text)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: OffroColors.border),
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
              border: Border.all(color: OffroColors.border),
              boxShadow: OffroShadows.card,
            ),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(fontSize: 14, color: OffroColors.text),
              decoration: const InputDecoration(
                hintText: "Search categories...",
                hintStyle: TextStyle(color: OffroColors.textMuted, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: OffroColors.textMuted, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
        // Pinterest grid
        Expanded(
          child: cats.isEmpty
            ? const Center(child: Text("No categories found", style: TextStyle(color: OffroColors.textMuted)))
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
    Navigator.push(ctx, appRoute(_CategoryStoresScreen(
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
      rawImg = resolveImageUrl(rawImg);
    }
    final bool isBase64 = rawImg.startsWith("data:image");
    final bool isHttp   = rawImg.startsWith("http://") || rawImg.startsWith("https://");
    Uint8List? imgBytes;
    if (isBase64) {
      try {
        final ci = rawImg.indexOf(",");
        if (ci >= 0) imgBytes = decodeBase64ImageCached(rawImg);
      } catch (_) { }
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


// ─────────────────────── ALL DEALS SCREEN ───────────────────────
class _AllDealsScreen extends StatefulWidget {
  final String token;
  final String city;
  // true when shown as the Deals tab inside Home (no own Scaffold / back
  // button, the floating bottom nav stays visible).
  final bool embedded;
  const _AllDealsScreen({super.key, required this.token, required this.city, this.embedded = false});
  @override State<_AllDealsScreen> createState() => _AllDealsScreenState();
}

class _AllDealsScreenState extends State<_AllDealsScreen> {
  List<Map<String,dynamic>> _deals = [];
  bool _loading = true;
  String _q = "";
  String _filter = "All"; // All | Ending soon | <deal category>

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final endpoint = widget.city.isNotEmpty
          ? "/deals/all?city=" + Uri.encodeComponent(widget.city)
          : "/deals/all";
      final dynamic raw = await Api.get(endpoint);
      final List<Map<String,dynamic>> list = (raw is List)
          ? List<Map<String,dynamic>>.from(raw.map((e) => Map<String,dynamic>.from(e as Map)))
          : <Map<String,dynamic>>[];
      if (mounted) setState(() { _deals = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String,dynamic>> get _filtered {
    Iterable<Map<String,dynamic>> list = _deals;
    if (_filter == "Ending soon") {
      list = list.where((d) {
        final left = _daysLeft((d["end_date"] ?? "").toString());
        return left != null && left >= 0 && left <= 3;
      });
    } else if (_filter != "All") {
      list = list.where((d) => (d["category"] ?? "").toString() == _filter);
    }
    if (_q.trim().isEmpty) return list.toList();
    final q = _q.toLowerCase();
    return list.where((d) =>
      (d["title"]      ?? "").toString().toLowerCase().contains(q) ||
      (d["store_name"] ?? "").toString().toLowerCase().contains(q) ||
      (d["store_area"] ?? "").toString().toLowerCase().contains(q)
    ).toList();
  }

  /// Whole days until the deal ends (today = 0); null when there is no usable date.
  int? _daysLeft(String endRaw) {
    final dt = _parseDate(endRaw);
    if (dt == null) return null;
    final today = DateTime.now();
    return DateTime(dt.year, dt.month, dt.day)
        .difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  /// Filter chips: All, Ending soon, then the categories real deals carry.
  List<String> get _filterOptions {
    final cats = <String>[];
    for (final d in _deals) {
      final c = (d["category"] ?? "").toString().trim();
      if (c.isNotEmpty && c != "null" && !cats.contains(c)) cats.add(c);
    }
    return ["All", "Ending soon", ...cats.take(4)];
  }

  // Round 12 (Task 5): the currently-visible (filtered) deals that have an
  // image — same "only these can open the gallery" rule StoreOffersSection
  // already applies to Today's Offers. `.where()` doesn't clone the Map
  // elements, so a tapped deal from `items`/`_filtered` is still the same
  // object instance found here, which is what openDealGallery's identity
  // -based indexOf relies on.
  List<Map<String,dynamic>> get _dealsWithImages =>
      _filtered.where((d) => (d["image_url"] ?? "").toString().isNotEmpty).toList();

  // Parse validity date string to DateTime — handles multiple formats
  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    // 1. Try ISO-8601
    try { return DateTime.parse(s); } catch (_) {}
    // 2. Try DD-MM-YYYY or DD/MM/YYYY
    try {
      final p = s.split(RegExp('[-/]'));
      if (p.length == 3 && int.tryParse(p[0]) != null) {
        final d = int.parse(p[0]); final m = int.parse(p[1]); final y = int.parse(p[2]);
        if (d <= 31 && m <= 12 && y > 2000) return DateTime(y, m, d);
      }
    } catch (_) {}
    // 3. Try "15 Aug 2026"
    try {
      final months = {"jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
                      "jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12};
      final m = RegExp(r'(\d{1,2})\s+(\w+)\s+(\d{4})').firstMatch(s);
      if (m != null) {
        final d = int.parse(m.group(1)!);
        final mon = months[m.group(2)!.toLowerCase().substring(0,3)];
        final y = int.parse(m.group(3)!);
        if (mon != null) return DateTime(y, mon, d);
      }
    } catch (_) {}
    // 4. Try "Aug 15, 2026"
    try {
      final months = {"jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
                      "jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12};
      final m = RegExp(r'(\w+)\s+(\d{1,2}),?\s+(\d{4})').firstMatch(s);
      if (m != null) {
        final mon = months[m.group(1)!.toLowerCase().substring(0,3)];
        final d = int.parse(m.group(2)!);
        final y = int.parse(m.group(3)!);
        if (mon != null) return DateTime(y, mon, d);
      }
    } catch (_) {}
    return null;
  }


  bool _isExpired(String s) {
    final dt = _parseDate(s);
    if (dt == null) return false;
    return DateTime.now().isAfter(dt.add(const Duration(days: 1)));
  }

  void _openDeal(BuildContext ctx, Map<String,dynamic> d) {
    final imgUrl    = (d["image_url"]  ?? "").toString();
    final storeId   = (d["store_id"]   ?? "").toString();
    final storeName = (d["store_name"] ?? "").toString();
    final storeArea = (d["store_area"] ?? "").toString();
    // Same behaviour as before: a deal with an image opens the swipeable
    // full-screen deal gallery; one without goes to Store Detail.
    if (imgUrl.isNotEmpty) {
      openDealGallery(ctx, _dealsWithImages, d);
      return;
    }
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
    Navigator.push(ctx, appRoute(
      StoreDetailPage(store: store, token: widget.token, userName: "", onProductTap:(p,tk)=>Navigator.push(context,appRoute(ProductDetailsPage(product:p,token:tk))))));
  }

  Widget _dealCard(BuildContext ctx, Map<String,dynamic> d) {
    final imgUrl    = (d["image_url"]  ?? "").toString();
    final endDate   = (d["end_date"]   ?? "").toString();
    final storeName = (d["store_name"] ?? "").toString();
    final storeArea = (d["store_area"] ?? "").toString();
    final title     = (d["title"]      ?? "").toString();
    final category  = (d["category"]   ?? "").toString().trim();
    final discInt   = int.tryParse((d["discount"] ?? "").toString()) ?? 0;
    final expired   = _isExpired(endDate);
    final left      = _daysLeft(endDate);
    final endsText  = expired
        ? "Expired"
        : left == null ? "" : left <= 0 ? "Ends today" : left == 1 ? "Ends in 1 day" : "Ends in $left days";
    final sub = [if (storeName.isNotEmpty) storeName, if (storeArea.isNotEmpty) storeArea].join(" · ");

    return GestureDetector(
      onTap: () => _openDeal(ctx, d),
      child: Container(
        height: 256,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: OffroColors.text,
          borderRadius: BorderRadius.circular(27),
        ),
        child: Stack(fit: StackFit.expand, children: [
          OffroNetworkImage(
            url: imgUrl,
            errorWidget: const ColoredBox(color: OffroColors.primary),
          ),
          if (expired) const ColoredBox(color: Color(0x73000000)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: .90),
                  Colors.black.withValues(alpha: .35),
                  Colors.black.withValues(alpha: .20),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .15),
                    borderRadius: OffroRadii.pillRadius,
                    border: Border.all(color: Colors.white.withValues(alpha: .25)),
                  ),
                  child: Text(category.isNotEmpty && category != "null" ? category.toUpperCase() : "LOCAL DEAL",
                    style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ]),
              const Spacer(),
              if (discInt > 0)
                Text("$discInt%",
                  style: OffroText.display.copyWith(fontSize: 43, letterSpacing: -2.8, height: 1, color: Colors.white)),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: OffroText.cardTitle.copyWith(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white)),
              ),
              if (sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: .65))),
                ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .15))),
                ),
                child: Row(children: [
                  if (endsText.isNotEmpty) ...[
                    OffroIcon(OffroIcons.clock, size: 12, color: Colors.white.withValues(alpha: .65)),
                    const SizedBox(width: 4),
                    Text(endsText,
                      style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: .65))),
                  ],
                  const Spacer(),
                  Text("AVAILABLE IN STORE",
                    style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .65))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final items = _filtered;
    final topPad = MediaQuery.of(context).padding.top;
    final options = _filterOptions;

    final content = ListView(
      padding: EdgeInsets.only(top: widget.embedded ? topPad : 0, bottom: widget.embedded ? 124 : 32),
      physics: const BouncingScrollPhysics(),
      children: [
        OffroScreenHeader(
          eyebrow: "Fresh around you",
          title: "Local deals",
          description: widget.city.isNotEmpty
              ? "Member-only prices and limited offers from verified businesses in ${widget.city}."
              : "Member-only prices and limited offers from verified businesses nearby.",
          showBack: !widget.embedded,
        ),
        // Search (kept from the previous Deals screen)
        Padding(
          padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 20, OffroSpacing.gutter, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: OffroColors.surface,
              borderRadius: BorderRadius.circular(OffroRadii.input),
              boxShadow: const [BoxShadow(color: Color(0x0F3E5F55), blurRadius: 30, offset: Offset(0, 8))],
            ),
            child: Row(children: [
              const OffroIcon(OffroIcons.search, size: 18, color: Color(0x803E5F55)),
              const SizedBox(width: 12),
              Expanded(child: TextField(
                onChanged: (v) => setState(() => _q = v),
                style: OffroText.body.copyWith(fontSize: 13, color: OffroColors.text),
                cursorColor: OffroColors.primary,
                decoration: InputDecoration(
                  hintText: "Search deals, stores or areas",
                  hintStyle: OffroText.body.copyWith(fontSize: 13, color: OffroColors.secondarySolid),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              )),
            ]),
          ),
        ),
        // Filter chips
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: OffroSpacing.gutterH,
            child: Row(children: [
              for (final o in options)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _filter == o ? OffroColors.primary : OffroColors.surface,
                        borderRadius: OffroRadii.pillRadius,
                        border: _filter == o ? null : Border.all(color: OffroColors.border),
                      ),
                      child: Text(o,
                        style: OffroText.caption.copyWith(
                          fontSize: 12, fontWeight: FontWeight.w500,
                          color: _filter == o ? Colors.white : OffroColors.text)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        // Count banner (real count of active deals)
        if (!_loading && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 20, OffroSpacing.gutter, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OffroColors.mint,
                borderRadius: BorderRadius.circular(OffroRadii.input),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("THIS WEEK",
                    style: OffroText.eyebrow.copyWith(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: const Color(0xA63E5F55))),
                  const SizedBox(height: 4),
                  Text("${items.length} active ${items.length == 1 ? 'deal' : 'deals'} for you",
                    style: OffroText.titleSm.copyWith(fontSize: 18)),
                ])),
                Container(
                  width: 44, height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0xB3FFFFFF), shape: BoxShape.circle),
                  child: const OffroIcon(OffroIcons.tag, size: 20, color: OffroColors.primary),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 24),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: OffroColors.primary)),
          )
        else if (items.isEmpty)
          Padding(
            padding: OffroSpacing.gutterH,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: OffroColors.borderStrong),
              ),
              child: Column(children: [
                const OffroIcon(OffroIcons.tag, size: 28, color: OffroColors.accent),
                const SizedBox(height: 12),
                Text(_q.isEmpty && _filter == "All" ? "No active deals right now" : "No deals match your search",
                  style: OffroText.cardTitle.copyWith(fontSize: 13)),
              ]),
            ),
          )
        else
          Padding(
            padding: OffroSpacing.gutterH,
            child: Column(children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                _dealCard(context, items[i]),
              ],
            ]),
          ),
      ],
    );

    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: OffroColors.background,
      body: SafeArea(bottom: false, child: content),
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
      backgroundColor: OffroColors.background,
      appBar: AppBar(
        backgroundColor: OffroColors.background,
        foregroundColor: OffroColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text("All Areas",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: OffroColors.text)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            color: OffroColors.background,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: const TextStyle(color: OffroColors.text, fontSize: 14),
              cursorColor: kPrimary,
              decoration: InputDecoration(
                hintText: "Search areas...",
                hintStyle: const TextStyle(color: OffroColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: kPrimary, size: 18),
                filled: true,
                fillColor: const Color(0xFFF2FAF5),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: OffroColors.border)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: OffroColors.border)),
              ),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
        ? Center(child: Text(
            _q.isEmpty ? "No areas available" : "No results for \"$_q\"",
            style: const TextStyle(color: OffroColors.textMuted, fontSize: 15)))
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
                onTap: () => Navigator.push(context, appRoute(_AreaDetailScreen(
                  areaName: name,
                  stores: List<Map<String,dynamic>>.from(area["stores"] as List),
                  token: widget.token,
                ))),
                child: Container(
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: OffroColors.border, width: 1),
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
                            color: OffroColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text("$count Store${count == 1 ? "" : "s"}",
                          style: const TextStyle(color: OffroColors.textMuted, fontSize: 12)),
                      ],
                    )),
                    const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Icon(Icons.chevron_right_rounded, color: OffroColors.textMuted, size: 20)),
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
      backgroundColor: OffroColors.background,
      body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
        // App bar
        SliverAppBar(
          pinned: true,
          backgroundColor: OffroColors.background,
          foregroundColor: OffroColors.text,
          elevation: 0,
          shadowColor: Colors.black12,
          expandedHeight: 0,
          toolbarHeight: 52,
          title: Text(widget.areaName,
            style: const TextStyle(color: OffroColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
          centerTitle: false,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: OffroColors.border),
          ),
        ),
        // Search
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OffroColors.border),
              boxShadow: OffroShadows.card,
            ),
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 14, color: OffroColors.text),
              decoration: InputDecoration(
                hintText: "Search in ${widget.areaName}...",
                hintStyle: const TextStyle(color: OffroColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: OffroColors.textMuted, size: 20),
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
            style: const TextStyle(color: OffroColors.textMuted, fontSize: 12)),
        )),
        // Store list
        filtered.isEmpty
          ? const SliverFillRemaining(child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.store_mall_directory_outlined, color: kAccent, size: 48),
                SizedBox(height: 12),
                Text("No stores found", style: TextStyle(color: OffroColors.textMuted, fontSize: 14)),
              ])))
          : SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context,
                      appRoute(StoreDetailPage(store: Map<String,dynamic>.from(filtered[i]), token: widget.token, userName: "", onProductTap:(p,tk)=>Navigator.push(context,appRoute(ProductDetailsPage(product:p,token:tk)))))),
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

// ═══════════════════════════════════════════════════════════════════
// FINAL 1.1 — NEW HOME WIDGETS
// ═══════════════════════════════════════════════════════════════════

// ─── 1. Hero Greeting Section ────────────────────────────────────
// City Hero Section — full-bleed image from Default Images module (key: "city")
// ─── Figma header: logo + bell, then "Exploring <location>" ───
class _HomeHeader extends StatelessWidget {
  final String locationTitle;
  final String locationSubtitle;
  final int unreadCount;
  final VoidCallback onCityTap;
  final VoidCallback onBellTap;
  const _HomeHeader({
    required this.locationTitle, required this.locationSubtitle,
    required this.unreadCount, required this.onCityTap, required this.onBellTap,
  });

  @override Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: OffroColors.background,
      padding: EdgeInsets.fromLTRB(OffroSpacing.gutter, topPad + 14, OffroSpacing.gutter, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          buildImageLogo(height: 30),
          const Spacer(),
          GestureDetector(
            onTap: onBellTap,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: OffroColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: OffroColors.border),
                ),
                child: const OffroIcon(OffroIcons.bell, size: 18, color: OffroColors.text),
              ),
              if (unreadCount > 0)
                Positioned(top: 9, right: 10,
                  child: Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(color: OffroColors.terracotta, shape: BoxShape.circle),
                  )),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onCityTap,
          behavior: HitTestBehavior.opaque,
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
            const OffroIcon(OffroIcons.pin, size: 14, color: Color(0xFF61917A), filled: true),
            const SizedBox(width: 8),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text("Exploring", style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.secondarySolid)),
              Text(locationTitle.isNotEmpty ? locationTitle : "Select location",
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: OffroColors.text)),
              if (locationSubtitle.isNotEmpty)
                Text(locationSubtitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.secondarySolid)),
            ])),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: OffroColors.secondarySolid),
          ]),
        ),
      ]),
    );
  }
}

// ─── Figma search bar (tap opens the existing store search) ───
class _HomeSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _HomeSearchBar({required this.onTap});

  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 4, OffroSpacing.gutter, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: OffroColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: OffroColors.border),
            boxShadow: const [BoxShadow(color: Color(0x0F3E5F55), blurRadius: 32, offset: Offset(0, 8))],
          ),
          child: Row(children: [
            const OffroIcon(OffroIcons.search, size: 18, color: OffroColors.secondarySolid),
            const SizedBox(width: 12),
            Expanded(child: Text("Search stores, products or services",
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: OffroText.body.copyWith(fontSize: 14, color: OffroColors.secondarySolid))),
            const SizedBox(width: 8),
            const OffroIcon(OffroIcons.sliders, size: 18, color: OffroColors.primary),
          ]),
        ),
      ),
    );
  }
}

// ─── Figma hero: the single promotional area on Home ───
// Rotates the existing merchant promo sliders (images / videos, same data +
// auto-play as before). With no sliders it shows the city artwork card.
class _CityHeroSection extends StatelessWidget {
  final String city;
  final String cityImageUrl;   // URL from /default-images → "city" key
  // True while the hero/city-image fetch is still in flight, i.e. an empty
  // [cityImageUrl] may just mean "not fetched yet" (shows a shimmer).
  final bool imageLoading;
  final VoidCallback onCtaTap;
  final List<Map<String,dynamic>> sliders;
  final ValueNotifier<int> sliderPageNotifier;
  final String token;
  final VoidCallback onAdvance; // a promo video finished → show the next slide
  final VoidCallback? onVideoPlayStarted; // customer tapped play on a hero video
  const _CityHeroSection({
    required this.city, required this.cityImageUrl,
    this.imageLoading = false, required this.onCtaTap,
    required this.sliders,
    required this.sliderPageNotifier, required this.token,
    required this.onAdvance,
    this.onVideoPlayStarted,
  });

  static const double _heroH = 296;

  @override Widget build(BuildContext context) {
    if (sliders.isEmpty) {
      return Padding(
        padding: OffroSpacing.gutterH,
        child: _cityCard(),
      );
    }
    // ONE fixed card (size, position, radius never change). Only the media +
    // its overlay text cross-fade when the active slide changes.
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heroCard(),
      _featuredStoreCta(context),
    ]);
  }

  // The single fixed hero card (unchanged structure).
  Widget _heroCard() {
    return Padding(
      padding: OffroSpacing.gutterH,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OffroRadii.hero),
        child: SizedBox(
          height: _heroH,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: OffroColors.text),
            ValueListenableBuilder<int>(
              valueListenable: sliderPageNotifier,
              builder: (_, pg, __) {
                final idx = pg % sliders.length;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 700),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, if (current != null) current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<int>(idx),
                    child: _slideContent(Map<String,dynamic>.from(sliders[idx])),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  // "View featured store": opens the Store Detail of the store attached to the
  // hero slide currently shown (slide["store_id"]). Hidden when the current
  // slide has no store reference. Same lookup the banner tap already uses.
  Widget _featuredStoreCta(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: sliderPageNotifier,
      builder: (ctx, pg, _) {
        if (sliders.isEmpty) return const SizedBox.shrink();
        final sl = sliders[pg % sliders.length];
        final storeId = (sl["store_id"] ?? "").toString();
        if (storeId.isEmpty || storeId == "null") return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 14, OffroSpacing.gutter, 0),
          child: OffroButton.small(
            label: "View featured store",
            trailingIcon: OffroIcons.arrow,
            onPressed: () => _openFeaturedStore(ctx, storeId),
          ),
        );
      },
    );
  }

  Future<void> _openFeaturedStore(BuildContext context, String storeId) async {
    try {
      final store = await Api.fetchStoreDetail(storeId);
      if (!context.mounted) return;
      Navigator.push(context, appRoute(
        StoreDetailPage(store: Map<String, dynamic>.from(store as Map), token: token, userName: "")));
    } catch (_) { if (kDebugMode) debugPrint("[Offro] featured store open failed"); }
  }

  // ── One promo slide: real media + Figma overlay. Text/CTA only appear when
  // the slide itself carries a title (never invented). ──
  Widget _slideContent(Map<String,dynamic> sl) {
    final title    = (sl["title"] ?? "").toString().trim();
    final sub      = (sl["subtitle"] ?? sl["text"] ?? "").toString().trim();
    final promoter = (sl["store_name"] ?? sl["merchant_name"] ?? "").toString().trim();
    final hasText  = title.isNotEmpty;
    final words    = title.split(RegExp(r'\s+'));
    final accent   = words.length > 1 ? words.last : title;
    final before   = words.length > 1 ? "${words.sublist(0, words.length - 1).join(' ')} " : "";

    return Stack(fit: StackFit.expand, children: [
          Positioned.fill(child: PromoSliderCard(
            slider: sl,
            token: token,
            squareCorners: true,
            hideText: true,
            onVideoComplete: onAdvance,
            tapToPlay: true,
            onPlayStarted: onVideoPlayStarted,
          )),
          // Overlay is decoration only — taps fall through to the slide.
          IgnorePointer(child: Stack(fit: StackFit.expand, children: [
            // TEST C: hero dark gradients (left #17231F 90/55/0, bottom black 55/0/10) removed.
            if (hasText)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 285),
                    child: OffroAccentText(
                      before: before,
                      accent: accent,
                      style: OffroText.headline.copyWith(color: Colors.white, fontSize: 30),
                    ),
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: OffroText.bodySmall.copyWith(fontSize: 12, height: 1.6, color: Colors.white.withValues(alpha: .70))),
                    ),
                  ],
                ]),
              ),
            // Store title at the bottom of the hero. The dark gradient is LOCAL to
            // the bottom ~104px (fades up into the untouched image); nothing else
            // on the hero is darkened.
            if (promoter.isNotEmpty)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 44, 24, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: .72),
                        Colors.black.withValues(alpha: .0),
                      ],
                    ),
                  ),
                  child: Text(promoter,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: OffroText.cardTitle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
          ])),
    ]);
  }

  // ── No promo sliders: city artwork hero ("Explore <City>") ──
  Widget _cityCard() {
    final displayCity = city.isNotEmpty ? city : "Your City";
    Widget gradientBox() => const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2B463E), OffroColors.primary],
        ),
      ),
    );
    Widget memoryHero() {
      try {
        return Image.memory(
          decodeBase64ImageCached(cityImageUrl),
          fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          cacheWidth: 900, gaplessPlayback: true,
          errorBuilder: (_, __, ___) => gradientBox());
      } catch (_) { return gradientBox(); }
    }

    final Widget background = cityImageUrl.startsWith("data:image")
        ? memoryHero()
        : cityImageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: cityImageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: 900,
                placeholder: (_, __) => shimmerBox(width: double.infinity, height: double.infinity),
                errorWidget: (_, __, ___) => gradientBox(),
              )
            : imageLoading
                ? shimmerBox(width: double.infinity, height: double.infinity)
                : gradientBox();

    return ClipRRect(
      borderRadius: BorderRadius.circular(OffroRadii.hero),
      child: SizedBox(
        height: _heroH,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: OffroColors.text),
          background,
          // TEST C: city-hero dark gradients removed (same values as the slide hero).
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: OffroRadii.pillRadius,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: OffroColors.terracotta, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text("LOCAL DEALS & STORES",
                    style: OffroText.eyebrow.copyWith(color: Colors.white, fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 285),
                child: OffroAccentText(
                  before: "Explore\n",
                  accent: displayCity,
                  style: OffroText.headline.copyWith(color: Colors.white, fontSize: 34),
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text("Discover stores, deals & local favorites",
                  style: OffroText.bodySmall.copyWith(fontSize: 12, height: 1.6, color: Colors.white.withValues(alpha: .70))),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onCtaTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .95),
                    borderRadius: OffroRadii.pillRadius,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text("Discover stores",
                      style: OffroText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600, color: OffroColors.primary)),
                    const SizedBox(width: 6),
                    const OffroIcon(OffroIcons.arrow, size: 12, color: OffroColors.primary),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}


// ─── Figma "Exclusive deals": real active deals from the existing /deals/all ───
// Same endpoint, expiry rule and tap behaviour as the Deals screen. The whole
// section stays hidden while loading, on error, or when there are no deals.
class _ExclusiveDealsSection extends StatefulWidget {
  final String city;
  final String token;
  final VoidCallback onViewAll;
  const _ExclusiveDealsSection({
    super.key, required this.city, required this.token, required this.onViewAll,
  });
  @override State<_ExclusiveDealsSection> createState() => _ExclusiveDealsSectionState();
}

class _ExclusiveDealsSectionState extends State<_ExclusiveDealsSection> {
  List<Map<String,dynamic>> _deals = [];

  @override void initState() { super.initState(); _load(); }

  @override void didUpdateWidget(covariant _ExclusiveDealsSection old) {
    super.didUpdateWidget(old);
    if (old.city != widget.city) _load();
  }

  static DateTime? _parseEnd(String s) {
    if (s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) {}
    try {
      final p = s.split(RegExp('[-/]'));
      if (p.length == 3 && int.tryParse(p[0]) != null) {
        final d = int.parse(p[0]); final m = int.parse(p[1]); final y = int.parse(p[2]);
        if (d <= 31 && m <= 12 && y > 2000) return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _load() async {
    try {
      final endpoint = widget.city.isNotEmpty
          ? "/deals/all?city=" + Uri.encodeComponent(widget.city)
          : "/deals/all";
      final dynamic raw = await Api.get(endpoint);
      final list = (raw is List)
          ? List<Map<String,dynamic>>.from(raw.map((e) => Map<String,dynamic>.from(e as Map)))
          : <Map<String,dynamic>>[];
      final now = DateTime.now();
      final active = list.where((d) {
        final end = _parseEnd((d["end_date"] ?? "").toString());
        return end == null || !now.isAfter(end.add(const Duration(days: 1)));
      }).take(8).toList();
      if (mounted) setState(() => _deals = active);
    } catch (_) {
      // Optional section — stay hidden on error.
    }
  }

  String? _daysLeft(Map<String,dynamic> d) {
    final end = _parseEnd((d["end_date"] ?? "").toString());
    if (end == null) return null;
    final days = end.add(const Duration(days: 1)).difference(DateTime.now()).inDays;
    if (days <= 0) return "Ends today";
    return days == 1 ? "1 day left" : "$days days left";
  }

  void _open(BuildContext ctx, Map<String,dynamic> d) {
    final imgUrl = (d["image_url"] ?? "").toString();
    if (imgUrl.isNotEmpty) {
      final withImages = _deals.where((x) => (x["image_url"] ?? "").toString().isNotEmpty).toList();
      openDealGallery(ctx, withImages, d);
      return;
    }
    final store = <String,dynamic>{
      "_id":        (d["store_id"] ?? "").toString(),
      "store_name": (d["store_name"] ?? "").toString(),
      "area":       (d["store_area"] ?? "").toString(),
      "city":       (d["store_city"] ?? "").toString(),
      "address":    (d["store_address"] ?? "").toString(),
      "phone":      (d["store_phone"] ?? "").toString(),
      "image_url":  imgUrl,
      "category":   (d["category"] ?? "").toString(),
    };
    Navigator.push(ctx, appRoute(StoreDetailPage(
      store: store, token: widget.token, userName: "",
      onProductTap: (p, tk) => Navigator.push(ctx, appRoute(ProductDetailsPage(product: p, token: tk))))));
  }

  @override Widget build(BuildContext context) {
    if (_deals.isEmpty) return const SizedBox.shrink();
    final cardW = MediaQuery.sizeOf(context).width * 0.78;
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OffroSectionTitle(
          eyebrow: "Made for OffrO members",
        eyebrowColor: OffroColors.sageStrong,
          title: "Exclusive deals",
          actionLabel: "View all",
          onAction: widget.onViewAll,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 224,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: OffroSpacing.gutter, right: 4),
            itemCount: _deals.length,
            itemBuilder: (ctx, i) => _dealCard(ctx, _deals[i], cardW),
          ),
        ),
      ]),
    );
  }

  Widget _dealCard(BuildContext ctx, Map<String,dynamic> d, double width) {
    final title     = (d["title"] ?? "").toString();
    final storeName = (d["store_name"] ?? "").toString();
    final imgUrl    = (d["image_url"] ?? "").toString();
    final discInt   = int.tryParse((d["discount"] ?? "").toString()) ?? 0;
    final left      = _daysLeft(d);

    Widget image() {
      Widget fallback() => Container(
        color: OffroColors.accent,
        alignment: Alignment.center,
        child: const OffroIcon(OffroIcons.tag, size: 32, color: OffroColors.primary),
      );
      if (imgUrl.startsWith("http")) {
        return CachedNetworkImage(
          imageUrl: imgUrl, fit: BoxFit.cover,
          width: double.infinity, height: double.infinity,
          placeholder: (_, __) => const ColoredBox(color: OffroColors.mint),
          errorWidget: (_, __, ___) => fallback());
      }
      if (imgUrl.startsWith("data:image")) return base64Image(imgUrl, fallback());
      return fallback();
    }

    return GestureDetector(
      onTap: () => _open(ctx, d),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: OffroColors.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 144,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              image(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: .45),
                      Colors.transparent,
                      Colors.black.withValues(alpha: .05),
                    ],
                  ),
                ),
              ),
              Positioned(left: 12, top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: OffroColors.primary,
                    borderRadius: OffroRadii.pillRadius,
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const OffroIcon(OffroIcons.tag, size: 12, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(discInt > 0 ? "$discInt% off" : "Offer",
                      style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                )),
              if (left != null)
                Positioned(right: 12, bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .90),
                      borderRadius: OffroRadii.pillRadius,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const OffroIcon(OffroIcons.clock, size: 12, color: OffroColors.primary),
                      const SizedBox(width: 4),
                      Text(left,
                        style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: OffroColors.primary)),
                    ]),
                  )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: OffroText.cardTitle),
                const SizedBox(height: 4),
                Text(storeName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: OffroColors.secondarySolid)),
              ])),
              const SizedBox(width: 12),
              Container(
                width: 36, height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: OffroColors.mint, shape: BoxShape.circle),
                child: const OffroIcon(OffroIcons.chevron, size: 16, color: OffroColors.primary),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}


// ─── Home rewards card (Figma) — shows the existing wallet points ───
class _HomeRewardsCard extends StatelessWidget {
  final int points;
  final VoidCallback onTap;
  const _HomeRewardsCard({required this.points, required this.onTap});

  static String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 36, OffroSpacing.gutter, 0),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            color: OffroColors.beige,
            padding: const EdgeInsets.all(20),
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned(
                right: -52, top: -52,
                child: Container(
                  width: 144, height: 144,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: .20), width: 28),
                  ),
                ),
              ),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .60),
                      borderRadius: OffroRadii.pillRadius,
                    ),
                    child: Text("OFFRO REWARDS",
                      style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: OffroColors.primary)),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: _fmt(points), style: OffroText.titleSm),
                    TextSpan(text: "  points",
                      style: OffroText.caption.copyWith(fontWeight: FontWeight.w400, color: OffroColors.secondarySolid)),
                  ])),
                  const SizedBox(height: 4),
                  Text(points > 0 ? "Tap to view and redeem your rewards" : "Visit stores to start earning points",
                    style: OffroText.caption.copyWith(fontWeight: FontWeight.w400, color: OffroColors.secondarySolid)),
                ])),
                const SizedBox(width: 12),
                Container(
                  width: 48, height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: OffroColors.primary, shape: BoxShape.circle),
                  child: const OffroIcon(OffroIcons.gift, size: 20, color: Colors.white),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}


// ─── 2. Category Chips Row — single row with "More" button ──────
/// Category tile colours (solid): the Figma pastel fill pulled 18% toward its own
/// foreground (same colour family), icon pulled 15% toward the darkest text.
OffroTone _categoryTone(String name) {
  final t = OffroIcons.toneForCategory(name);
  return OffroTone(
    Color.lerp(t.background, t.foreground, .18)!,
    Color.lerp(t.foreground, OffroColors.textDark, .15)!,
  );
}

class _CategoryChipsRow extends StatelessWidget {
  final List<Map<String,dynamic>> cats;
  final String token;
  final VoidCallback onMoreTap;
  final double? userLat;
  final double? userLng;
  final String? selectedCity;
  const _CategoryChipsRow({required this.cats, required this.token, required this.onMoreTap, this.userLat, this.userLng, this.selectedCity});

  @override Widget build(BuildContext context) {
    final names = <String>[];
    for (final cat in cats) {
      final name = cat["name"]?.toString() ?? cat["category"]?.toString() ?? "";
      if (name.isNotEmpty) names.add(name);
    }
    if (names.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OffroSectionTitle(
        eyebrow: "Find what you need",
        eyebrowColor: OffroColors.sageStrong,
        title: "Explore categories",
        actionLabel: "See all",
        onAction: onMoreTap,
      ),
      const SizedBox(height: 16),
      // Every real category, swiped manually left/right (no auto-scroll, no
      // carousel/page indicator).
      SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: OffroSpacing.gutterH,
          itemCount: names.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, i) => SizedBox(width: 72, child: _tile(context, names[i])),
        ),
      ),
    ]);
  }

  Widget _tile(BuildContext context, String name) {
    final tone = _categoryTone(name);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => _CategoryStoresScreen(
          categoryName: name, token: token,
          userLat: userLat, userLng: userLng,
          selectedCity: selectedCity))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56, height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: OffroIcon(OffroIcons.forCategory(name), size: 24, color: tone.foreground),
        ),
        const SizedBox(height: 8),
        Text(name,
          maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: OffroColors.text)),
      ]),
    );
  }
}


// ═══════════════════════════════════════════════════════
// 6. Discover Products — clean horizontal cards, no background
// ═══════════════════════════════════════════════════════
class _DiscoverProductsSection extends StatelessWidget {
  final List<Map<String,dynamic>> products;
  final VoidCallback onViewAll;
  final String token;
  final List<String> defaultProductImageUrls;
  final bool loading;
  const _DiscoverProductsSection({
    required this.products,
    required this.onViewAll,
    this.token = "",
    this.defaultProductImageUrls = const [],
    this.loading = false,
  });

  // Skeleton shown while the real products are still being fetched — same
  // header + Bento footprint (1 large + 2 small), so nothing shifts when the
  // real cards replace it.
  Widget _loadingSkeleton() {
    const double h = 270;
    BorderRadius r() => BorderRadius.circular(18);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OffroSectionTitle(
          eyebrow: "Across local stores",
        eyebrowColor: OffroColors.sageStrong,
          title: "Products near you",
          actionLabel: "Browse all",
          onAction: onViewAll,
          padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 0, OffroSpacing.gutter, 12),
        ),
        SizedBox(
          height: h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              shimmerBox(width: 190, height: h, borderRadius: r()),
              const SizedBox(width: 10),
              Column(children: [
                shimmerBox(width: 150, height: (h - 10) / 2, borderRadius: r()),
                const SizedBox(height: 10),
                shimmerBox(width: 150, height: (h - 10) / 2, borderRadius: r()),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

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

  Widget _defaultProductImage(String imgUrl) {
    if (imgUrl.startsWith("data:image")) {
      try {
        return Image.memory(decodeBase64ImageCached(imgUrl),
          fit: BoxFit.cover, width: double.infinity, gaplessPlayback: true);
      } catch (_) { return Container(color: const Color(0xFFe8f5f0)); }
    } else if (imgUrl.startsWith("http")) {
      return Image.network(imgUrl, fit: BoxFit.cover, width: double.infinity,
        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFe8f5f0)));
    }
    return Container(color: const Color(0xFFe8f5f0),
      child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF6b8c7e), size: 36));
  }

  // Renders ALL configured default product images (not a hardcoded count) —
  // a single image keeps the original full-width look; multiple images lay
  // out as a scrollable row of cards.
  Widget _defaultProductPlaceholder(BuildContext context) {
    final urls = defaultProductImageUrls;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OffroSectionTitle(
          eyebrow: "Across local stores",
        eyebrowColor: OffroColors.sageStrong,
          title: "Products near you",
          actionLabel: "Browse all",
          onAction: onViewAll,
          padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 0, OffroSpacing.gutter, 12),
        ),
        if (urls.length <= 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(height: 170, width: double.infinity,
                child: _defaultProductImage(urls.isNotEmpty ? urls.first : "")),
            ),
          )
        else
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(width: 170, height: 170, child: _defaultProductImage(urls[i])),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Figma product grid: 2 columns, 1st and 4th product are full-width
  // "featured" cards (image left, details right). Same data, favourites and
  // navigation as before. ──
  static bool _isFeatured(int i) => i == 0 || i == 3;

  Widget _productImage(String imgSrc, String title) {
    const tint = [Color(0xFFe8f5f0), Color(0xFFCDEBD6)];
    if (imgSrc.startsWith("http")) {
      return CachedNetworkImage(
        imageUrl: imgSrc, fit: BoxFit.cover,
        width: double.infinity, height: double.infinity,
        placeholder: (_, __) => const ColoredBox(color: Color(0xFFCDEBD6)),
        errorWidget: (_, __, ___) => _fallback(title, tint));
    }
    if (imgSrc.startsWith("data:image")) {
      try {
        return Image.memory(decodeBase64ImageCached(imgSrc),
          fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallback(title, tint));
      } catch (_) {
        return _fallback(title, tint);
      }
    }
    return _fallback(title, tint);
  }

  Widget _productHeart(BuildContext ctx, Map<String,dynamic> v) {
    return StatefulBuilder(builder: (ctx2, setH) {
      final pid0 = v["_id"]?.toString() ?? v["id"]?.toString() ?? "";
      bool pFav = FavState.instance.hasProduct(pid0) || v["_isFav"] == true;
      return GestureDetector(
        onTap: () async {
          final pid = v["_id"]?.toString() ?? v["id"]?.toString() ?? "";
          if (pid.isEmpty || token.isEmpty) return;
          final next = !pFav;
          setH(() { v["_isFav"] = next; pFav = next; });
          FavState.instance.toggleProduct(pid);
          try {
            await Api.toggleProductFavorite(token, pid);
          } catch (e) {
            setH(() { v["_isFav"] = !next; pFav = !next; });
            FavState.instance.toggleProduct(pid);
            if (ctx2.mounted) {
              ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(
                content: Text("Couldn't save favorite: ${friendlyError(e)}"),
                backgroundColor: Colors.red.shade700,
                duration: const Duration(seconds: 12),
                showCloseIcon: true));
            }
          }
        },
        child: Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pFav ? OffroColors.primary : Colors.white.withValues(alpha: .90),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: OffroIcon(OffroIcons.heart, size: 14,
            color: pFav ? Colors.white : OffroColors.primary, filled: pFav),
        ),
      );
    });
  }

  Widget _productCard(BuildContext ctx, Map<String,dynamic> v, {required bool featured}) {
    final title     = _resolveTitle(v);
    final storeName = _resolveStoreName(v);
    final category  = (v["category"] ?? "").toString();
    final imgSrc    = _resolveImg(v);

    num? saleP = _numVal(v, ["offer_price","sale_price","price","current_price"]);
    num? origP = _numVal(v, ["original_price","mrp","was_price","compare_price"]);
    if (origP != null && saleP != null && origP <= saleP) origP = null;

    // Offer badge: computed from the real prices when both exist, otherwise
    // the product's own offer text / discount label.
    String badge = "";
    if (saleP != null && origP != null && origP > 0) {
      final pct = ((1 - saleP / origP) * 100).round();
      if (pct > 0) badge = "$pct% off";
    }
    if (badge.isEmpty) {
      final offerText = v["text"]?.toString() ?? v["offer_text"]?.toString() ?? v["offer"]?.toString() ?? v["discount"]?.toString() ?? "";
      final m = RegExp(r'(\d+)%').firstMatch("$title $offerText");
      if (m != null) {
        badge = "${m.group(1)}% off";
      } else {
        badge = v["discount_label"]?.toString() ?? "";
      }
    }

    final ratingRaw = v["rating"];
    final rating = (ratingRaw is num) ? ratingRaw.toDouble() : (double.tryParse(ratingRaw?.toString() ?? "") ?? 0.0);
    final countRaw = v["rating_count"] ?? v["review_count"];
    final count = (countRaw is num) ? countRaw.toInt() : (int.tryParse(countRaw?.toString() ?? "") ?? 0);

    final Widget imageBlock = Stack(fit: StackFit.expand, children: [
      _productImage(imgSrc, title),
      if (badge.isNotEmpty)
        Positioned(top: 10, left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: OffroColors.primary, borderRadius: OffroRadii.pillRadius),
            child: Text(badge,
              style: OffroText.caption.copyWith(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
          )),
      Positioned(top: 10, right: 10, child: _productHeart(ctx, v)),
    ]);

    final Widget details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: featured ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        if (storeName.isNotEmpty)
          Text(storeName.toUpperCase(),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: OffroText.eyebrow.copyWith(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.0, color: OffroColors.sage)),
        const SizedBox(height: 6),
        Text(title,
          maxLines: featured ? 2 : 1, overflow: TextOverflow.ellipsis,
          style: OffroText.cardTitle.copyWith(fontSize: featured ? 14 : 12, fontWeight: FontWeight.w600)),
        if (category.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.secondarySolid)),
          ),
        if (rating > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const OffroIcon(OffroIcons.star, size: 10, color: OffroColors.amber, filled: true),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1),
                style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: OffroColors.amber)),
              if (count > 0)
                Text(" ($count)",
                  style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.secondarySolid)),
            ]),
          ),
        if (saleP != null && saleP > 0)
          Padding(
            padding: EdgeInsets.only(top: featured ? 18 : 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 6,
              children: [
                Text("₹${saleP.toStringAsFixed(0)}",
                  style: OffroText.caption.copyWith(fontSize: featured ? 14 : 13, fontWeight: FontWeight.w600, color: OffroColors.primary)),
                if (origP != null)
                  Text("₹${origP.toStringAsFixed(0)}",
                    style: OffroText.caption.copyWith(
                      fontSize: 10, fontWeight: FontWeight.w400,
                      color: OffroColors.sage,
                      decoration: TextDecoration.lineThrough)),
              ],
            ),
          ),
      ],
    );

    return GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => ProductDetailsPage(product: v, token: token))),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: OffroColors.surface,
          borderRadius: BorderRadius.circular(23),
        ),
        child: featured
            ? SizedBox(
                height: 192,
                child: Row(children: [
                  Expanded(flex: 11, child: imageBlock),
                  Expanded(flex: 10, child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: details,
                  )),
                ]),
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AspectRatio(aspectRatio: 1.05, child: imageBlock),
                Padding(padding: const EdgeInsets.all(12), child: details),
              ]),
      ),
    );
  }

  Widget _productGrid(BuildContext ctx, List<Map<String,dynamic>> items) {
    final rows = <Widget>[];
    int i = 0;
    while (i < items.length) {
      if (_isFeatured(i)) {
        rows.add(_productCard(ctx, items[i], featured: true));
        i += 1;
      } else if (i + 1 < items.length && !_isFeatured(i + 1)) {
        rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _productCard(ctx, items[i], featured: false)),
          const SizedBox(width: 12),
          Expanded(child: _productCard(ctx, items[i + 1], featured: false)),
        ]));
        i += 2;
      } else {
        rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _productCard(ctx, items[i], featured: false)),
          const SizedBox(width: 12),
          const Expanded(child: SizedBox.shrink()),
        ]));
        i += 1;
      }
    }
    return Padding(
      padding: OffroSpacing.gutterH,
      child: Column(children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          rows[r],
        ],
      ]),
    );
  }

  @override Widget build(BuildContext context) {
    if (products.isEmpty) {
      // Real products still loading -> skeleton, never the default images.
      if (loading) return _loadingSkeleton();
      return defaultProductImageUrls.isNotEmpty
          ? _defaultProductPlaceholder(context)
          : const SizedBox.shrink();
    }

    // Figma shows the first four; "Browse all" opens the full product list.
    final items = products.take(4).map((p) => Map<String,dynamic>.from(p as Map)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 36, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OffroSectionTitle(
          eyebrow: "Across local stores",
        eyebrowColor: OffroColors.sageStrong,
          title: "Products near you",
          actionLabel: "Browse all",
          onAction: onViewAll,
        ),
        const SizedBox(height: 16),
        _productGrid(context, items),
      ]),
    );
  }
}


// ─── Figma "Stores near you": distance chips + store cards (real store data) ───
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

  Widget _storeImage(String imgSrc, String name) {
    Widget fallback() => Container(
      color: OffroColors.accent,
      alignment: Alignment.center,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : "S",
        style: const TextStyle(fontFamily: OffroFonts.sans, color: OffroColors.primary, fontSize: 28, fontWeight: FontWeight.w800)),
    );
    if (imgSrc.startsWith("http")) {
      return CachedNetworkImage(
        imageUrl: imgSrc, fit: BoxFit.cover,
        width: double.infinity, height: double.infinity,
        placeholder: (_, __) => const ColoredBox(color: OffroColors.mint),
        errorWidget: (_, __, ___) => fallback());
    }
    if (imgSrc.startsWith("data:image")) return base64Image(imgSrc, fallback());
    return fallback();
  }

  Widget _storeHeart(BuildContext ctx, Map s, String sid) {
    return GestureDetector(
      onTap: () async {
        if (sid.isEmpty || token.isEmpty) return;
        // One in-flight request per store; ignore taps until it settles.
        if (!FavState.instance.tryLockStore(sid)) return;
        final prev = FavState.instance.hasStore(sid);
        FavState.instance.setStore(sid, !prev); // optimistic
        try {
          final confirmed = await Api.toggleFavorite(token, sid);
          FavState.instance.setStore(sid, confirmed); // server-confirmed
        } catch (e) {
          FavState.instance.setStore(sid, prev); // restore
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text("Couldn't save favorite: ${friendlyError(e)}"),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 12),
              showCloseIcon: true));
          }
        } finally {
          FavState.instance.unlockStore(sid);
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: FavState.instance.storeListenable(sid),
        builder: (_, isFav, __) => Container(
          width: 36, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isFav ? OffroColors.primary : Colors.white.withValues(alpha: .90),
            shape: BoxShape.circle,
          ),
          child: OffroIcon(OffroIcons.heart, size: 16,
            color: isFav ? Colors.white : OffroColors.primary, filled: isFav),
        ),
      ),
    );
  }

  Widget _storeCard(BuildContext ctx, Map<String,dynamic> s, double width) {
    final sid      = s["_id"]?.toString() ?? s["id"]?.toString() ?? "";
    final name     = s["store_name"]?.toString() ?? "";
    final category = s["category"]?.toString() ?? "";
    final areaRaw  = s["area"]?.toString() ?? "";
    final area     = (areaRaw == "null") ? "" : areaRaw;
    final rating   = ((s["rating"] as num?)?.toDouble() ?? 0.0);
    final distKm   = (s["distance_km"] as num?)?.toDouble();
    final offer    = (s["offer"] ?? "").toString().trim();
    final dealCnt  = s["deal_count"];
    final hasOffer = offer.isNotEmpty && (dealCnt == null || ((dealCnt is num) ? dealCnt : 0) > 0);
    final isNew    = s["is_new_in_town"] == true || s["is_new_in_town"]?.toString() == 'true';
    final status   = computeStoreOpenStatus(s["open_time"]?.toString() ?? "", s["close_time"]?.toString() ?? "");
    final imgSrc   = _resolveImg(s);

    return GestureDetector(
      key: sid.isEmpty ? null : ValueKey("nearby_store_$sid"),
      onTap: () => onStoreTap(s),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: OffroColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: OffroColors.borderSoft),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 144,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              _storeImage(imgSrc, name),
              if (hasOffer)
                Positioned(left: 12, bottom: 12,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width - 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: OffroColors.background,
                        borderRadius: OffroRadii.pillRadius,
                      ),
                      child: Text("Offer · $offer",
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: OffroColors.primary)),
                    ),
                  )),
              if (distKm != null)
                Positioned(left: 12, top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: OffroColors.text,
                      borderRadius: OffroRadii.pillRadius,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const OffroIcon(OffroIcons.pin, size: 10, color: Colors.white, filled: true),
                      const SizedBox(width: 4),
                      Text(distKm < 1 ? "${(distKm * 1000).round()} m" : "${distKm.toStringAsFixed(1)} km",
                        style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                    ]),
                  )),
              Positioned(right: 12, top: 12, child: _storeHeart(ctx, s, sid)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: OffroText.cardTitle),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: OffroColors.mint, borderRadius: OffroRadii.pillRadius),
                        child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: OffroColors.primary)),
                      ),
                    if (isNew)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6,
                          decoration: const BoxDecoration(color: OffroColors.success, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text("NEW",
                          style: OffroText.caption.copyWith(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.9, color: OffroColors.success)),
                      ]),
                  ]),
                  if (area.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        const OffroIcon(OffroIcons.pin, size: 10, color: OffroColors.secondarySolid),
                        const SizedBox(width: 4),
                        Expanded(child: Text(area, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: OffroColors.secondarySolid))),
                      ]),
                    ),
                ])),
                if (rating > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: OffroColors.mint, borderRadius: OffroRadii.pillRadius),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const OffroIcon(OffroIcons.star, size: 10, color: OffroColors.amber, filled: true),
                      const SizedBox(width: 4),
                      Text(rating.toStringAsFixed(1),
                        style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: OffroColors.text)),
                    ]),
                  ),
                ],
              ]),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(children: [
                    Container(width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: status.isOpen ? OffroColors.open : OffroColors.secondarySolid,
                        shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      status.subLabel.isNotEmpty
                          ? "${status.isOpen ? 'Open now' : 'Closed'} · ${status.subLabel}"
                          : (status.isOpen ? "Open now" : "Closed"),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: OffroColors.secondarySolid))),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final chips = [
      {"label": "Any distance", "val": 0.0},
      {"label": "Under 1 km",   "val": 1.0},
      {"label": "Under 3 km",   "val": 3.0},
      {"label": "Under 5 km",   "val": 5.0},
      {"label": "Under 10 km",  "val": 10.0},
    ];
    // One clean filter. "Any distance" or GPS unavailable → every city store;
    // a specific radius → strict filter (distance already computed + sorted by
    // HomeScreen._nearbyStores).
    final bool gpsKnown = stores.any((s) => s["distance_km"] != null);
    final List<Map<String,dynamic>> filtered;
    if (radiusKm == 0.0 || !gpsKnown) {
      filtered = stores;
    } else {
      filtered = stores.where((s) {
        final d = (s["distance_km"] as num?)?.toDouble();
        return d != null && d <= radiusKm;
      }).toList();
    }
    final cardW = MediaQuery.sizeOf(context).width * 0.78;
    final shown = filtered.length > 8 ? 8 : filtered.length;

    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OffroSectionTitle(
          eyebrow: "Around your neighbourhood",
        eyebrowColor: OffroColors.sageStrong,
          title: "Stores near you",
          actionLabel: "See all",
          onAction: onViewAll,
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: OffroSpacing.gutterH,
          child: Row(children: chips.map((c) {
            final isActive = radiusKm == (c["val"] as double);
            return GestureDetector(
              onTap: () => onRadiusChanged(c["val"] as double),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? OffroColors.primary : OffroColors.surface,
                  borderRadius: OffroRadii.pillRadius,
                  border: isActive ? null : Border.all(color: OffroColors.border),
                ),
                child: Text(c["label"] as String,
                  style: OffroText.caption.copyWith(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : OffroColors.secondarySolid)),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty && radiusKm > 0)
          Padding(
            padding: OffroSpacing.gutterH,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: OffroColors.borderStrong),
              ),
              child: Column(children: [
                Text("No stores within ${radiusKm.toInt()} km",
                  style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: OffroColors.secondarySolid)),
                const SizedBox(height: 4),
                Text("Try a larger radius or tap Any distance",
                  style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: OffroColors.secondarySolid)),
              ]),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: OffroSpacing.gutter, right: 4),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (int i = 0; i < shown; i++) _storeCard(context, filtered[i], cardW),
              ]),
            ),
          ),
      ]),
    );
  }
}

// Retired from Customer Home (Figma Phase 2 correction); kept for the later Store Card phase.
// ignore: unused_element
class _ExploreAreasSection extends StatelessWidget {
  final List<Map<String,dynamic>> stores;
  final String token;
  const _ExploreAreasSection({required this.stores, required this.token});


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
              style: TextStyle(color: OffroColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
            Text("Discover great places nearby",
              style: TextStyle(color: OffroColors.secondarySolid, fontSize: 12)),
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
        // REDESIGN (2026-07-10 v3): dark card matching user mockup.
        // Dark outer card (solid equiv of "Newly Added" badge black) | left: green square badge
        // (count + "Store") | thin divider | right: area name + light-green distance pill.
        // Width is content-driven (mainAxisSize.min) — no excess padding.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: areas.take(8).toList().asMap().entries.map((e) {
            final area  = e.value.key;
            final count = e.value.value;

            // Nearest distance for this area
            double? nearestKm;
            for (final s in stores) {
              if ((s["area"]?.toString() ?? "").trim().toLowerCase() != area.toLowerCase()) continue;
              final d = (s["distance_km"] as num?)?.toDouble();
              if (d != null && (nearestKm == null || d < nearestKm)) nearestKm = d;
            }
            final distLabel = nearestKm != null
                ? (nearestKm < 1.0
                    ? "${(nearestKm * 1000).toStringAsFixed(0)} m"
                    : "${nearestKm.toStringAsFixed(1)} km")
                : null;

            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => _AreaDetailScreen(
                  areaName: area,
                  stores: stores.where((s) =>
                    (s["area"]?.toString() ?? "").trim().toLowerCase() == area.toLowerCase()).toList(),
                  token: token))),
              child: Container(
                margin: const EdgeInsets.only(right: 10, bottom: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  // Solid dark — same visual as floating badge "Newly Added" black overlay
                  color: const Color(0xFF1C2B26),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  // ① Dark-green square badge — count (large) + "Store" label below
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3E5F55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        "$count",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const Text(
                        "Store",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ]),
                  ),
                  // Thin vertical divider
                  Container(
                    width: 1,
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  // ② Right side: area name + distance pill
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          area,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (distLabel != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCDEBD6),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.location_on_rounded,
                              color: Color(0xFF3E5F55), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              distLabel,
                              style: const TextStyle(
                                color: Color(0xFF3E5F55),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ],
                  ),
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


// ─── 7. Browse All Categories Screen ─────────────────────────────
class _BrowseAllCategoriesScreen extends StatefulWidget {
  final String token;
  final double? userLat;
  final double? userLng;
  final String? selectedCity;
  const _BrowseAllCategoriesScreen({
    required this.token, this.userLat, this.userLng, this.selectedCity,
  });
  @override State<_BrowseAllCategoriesScreen> createState() => _BrowseAllCategoriesScreenState();
}

class _BrowseAllCategoriesScreenState extends State<_BrowseAllCategoriesScreen> {
  List<Map<String,dynamic>> _cats = [];
  bool _loading = true;

  @override void initState() { super.initState(); _loadCats(); }

  Future<void> _loadCats() async {
    try {
      // Always force-fresh from backend so all admin categories appear,
      // not just the subset that happened to be cached when the home screen loaded.
      Api.clearCategoriesListCache();
      final raw = await Api.fetchCategories();
      if (mounted) setState(() {
        _cats = raw.map<Map<String,dynamic>>((e) =>
          e is Map
            ? Map<String,dynamic>.from(e)
            : {"name": e.toString(), "icon": "🏪", "image_url": "", "subtitle": ""}
        ).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override Widget build(BuildContext context) {
    // Figma "all categories": cream page, Manrope header, 4-column grid of solid
    // pastel tiles with the OffrO category icon. Real categories from the API.
    return OffroFontScope(
      child: Scaffold(
        backgroundColor: OffroColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OffroScreenHeader(
              eyebrow: "Find what you need",
              title: "All categories",
              showBack: true,
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator(color: OffroColors.primary))
                : _cats.isEmpty
                  ? Center(child: Text("No categories found",
                      style: OffroText.body.copyWith(color: OffroColors.secondarySolid)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 4, OffroSpacing.gutter, 32),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 20, childAspectRatio: 0.78),
                      itemCount: _cats.length,
                      itemBuilder: (ctx, i) {
                        final cat = _cats[i];
                        final name = cat["name"]?.toString() ?? cat["category"]?.toString() ?? "";
                        final tone = _categoryTone(name);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.push(ctx, MaterialPageRoute(
                            builder: (_) => _CategoryStoresScreen(
                              categoryName: name, token: widget.token,
                              userLat: widget.userLat, userLng: widget.userLng,
                              selectedCity: widget.selectedCity))),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: tone.background,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: OffroIcon(OffroIcons.forCategory(name), size: 24, color: tone.foreground),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(name,
                              maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                              style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: OffroColors.text)),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
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
class _StoreCardLayout {
  final double height;
  final bool stackRating;
  const _StoreCardLayout(this.height, this.stackRating);
}

// Retired from Customer Home (Figma Phase 2 correction); kept for the later Store Card phase.
// ignore: unused_element
class _BannerStoresBlock extends StatefulWidget {
  final List<Map<String,dynamic>> banners;
  final List<Map<String,dynamic>> stores;
  final String token;
  final VoidCallback onViewAll;
  final Set<String> favStoreIds;
  final VoidCallback onFavChanged;
  // Round 12 (Task 6): true while _loadSupplementary() (Round 11's
  // background loader) is still in flight — i.e. `banners` being empty
  // might just mean "not fetched yet", not "none for this city". Lets this
  // widget reserve the banner's normal height with a shimmer instead of
  // collapsing to the stores-only layout and then jumping open once real
  // banners arrive. Defaults to false so a caller that doesn't pass it
  // keeps exactly the old behavior (empty banners == no banner space).
  final bool bannersLoading;
  const _BannerStoresBlock({
    required this.banners, required this.stores,
    required this.token,   required this.onViewAll,
    this.favStoreIds = const {},
    required this.onFavChanged,
    this.bannersLoading = false,
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
      // QA fix: slowed from 4s to 7s so each banner stays visible long
      // enough to read; manual swipe (same PageController) and the 500ms
      // easeInOut transition are unchanged.
      _timer = Timer.periodic(const Duration(seconds: 7), (_) {
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
        return Image.memory(decodeBase64ImageCached(imgUrl),
          fit: BoxFit.fitWidth, alignment: Alignment.topCenter,
          width: double.infinity, gaplessPlayback: true);
      } catch (_) { }
    }
    if (imgUrl.startsWith("http")) {
      return CachedNetworkImage(imageUrl: imgUrl,
        fit: BoxFit.fitWidth, alignment: Alignment.topCenter,
        width: double.infinity,
        // ROUND 12 FIX (Task 6): shimmer while this specific banner image
        // downloads, instead of a flat solid box. errorWidget (a genuine
        // load failure) keeps the original gradient fallback, unchanged.
        placeholder: (_, __) => shimmerBox(width: double.infinity, height: double.infinity),
        errorWidget: (_, __, ___) => _gradBox());
    }
    return _gradBox();
  }
  Widget _gradBox() => Container(decoration: const BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFF1e3d35), Color(0xFF3E5F55)],
      begin: Alignment.topLeft, end: Alignment.bottomRight)));


  @override Widget build(BuildContext context) {
    final hasBanners = widget.banners.isNotEmpty;
    final hasStores  = widget.stores.isNotEmpty;
    if (!hasBanners && !hasStores && !widget.bannersLoading) return const SizedBox.shrink();

    // Heights — 3:2 banner, 35-40% card overlap
    const double bannerH   = 320.0;
    const double overlapPx = 100.0; // ~31% of bannerH — cards peek but don't obscure banner
    // QA round (Oct 2026): computed from the tallest store card actually in
    // the list (see _storeLayout) instead of a fixed worst-case constant.
    // Each store's layout is measured ONCE per build and reused for both the
    // row height and the individual cards (stackRating).
    final List<_StoreCardLayout> layouts = _storeLayouts(context);
    final double cardH     = _storeRowHeight(layouts);
    const double headerH   = 0.0;
    const double topPad    = 14.0;

    // ROUND 12 FIX (Task 6): `banners` being empty can mean two different
    // things — "none for this city" (stay collapsed, as before) or
    // "_loadSupplementary() just hasn't come back yet" (Round 11 made this
    // load in the background after Home already appears). Previously both
    // looked the same here, so Home would render in the stores-only shape
    // and then — once the real banners arrived a moment later — suddenly
    // grow to the taller banner+overlap shape, shoving the store cards
    // (and everything below them) down. While still loading, this reserves
    // that exact same taller shape up front with a shimmer standing in for
    // the banner, so nothing shifts once the real banner swaps in.
    if (!hasBanners && widget.bannersLoading) {
      if (!hasStores) {
        return Padding(
          padding: const EdgeInsets.only(top: topPad),
          child: SizedBox(height: bannerH, child: shimmerBox(width: double.infinity, height: bannerH)));
      }
      final totalH = topPad + bannerH + cardH - overlapPx;
      return SizedBox(
        height: totalH,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(top: topPad, left: 0, right: 0, height: bannerH,
            child: shimmerBox(width: double.infinity, height: bannerH)),
          Positioned(
            top: topPad + bannerH - overlapPx,
            left: 0, right: 0,
            child: _storeCardsList(cardH, layouts, const EdgeInsets.fromLTRB(16, 0, 4, 0)),
          ),
        ]),
      );
    }

    // Stores-only (no banner, and we now know there genuinely isn't one)
    if (!hasBanners) return _storesOnly(cardH, headerH, layouts);

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
          child: _storeCardsList(cardH, layouts, const EdgeInsets.fromLTRB(16, 0, 4, 0)),
        ),
      ]),
    );
  }

  // ── Shared store-cards row (Round 12: extracted so the real "Both"
  // layout and the new loading-shimmer layout above don't each maintain
  // their own copy of this ListView.builder + "See All" card) ──────────
  Widget _storeCardsList(double cardH, List<_StoreCardLayout> layouts, EdgeInsets padding) {
    return SizedBox(
      height: cardH,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        padding: padding,
        // +1 for the "See All" card at the end
        itemCount: (widget.stores.length > 8 ? 8 : widget.stores.length) + 1,
        itemBuilder: (ctx, i) {
          final storeCount = widget.stores.length > 8 ? 8 : widget.stores.length;
          if (i < storeCount) {
            final st = widget.stores[i];
            final stId = st["_id"]?.toString() ?? st["id"]?.toString() ?? "";
            return KeyedSubtree(
              key: stId.isEmpty ? null : ValueKey("main_store_$stId"),
              child: _storeCard(
                ctx, st,
                // Reuse the layout measured in build(); fall back to measuring
                // only if the index is somehow outside the precomputed list.
                (i < layouts.length ? layouts[i] : _storeLayout(ctx, st)).stackRating));
          }
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
  // Round 12: now just calls the shared _storeCardsList helper above
  // instead of keeping its own copy of the same ListView.builder.
  Widget _storesOnly(double cardH, double headerH, List<_StoreCardLayout> layouts) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _storeCardsList(cardH, layouts, const EdgeInsets.fromLTRB(16, 0, 16, 0)),
    );
  }

  // ── Individual store card ────────────────────────────────────
  // ── Badge metadata for glass ribbon ──
  // Height of the badge ribbon, drawn as an overlay on the bottom of the store image.
  static const double _kBadgeRibbonH = 30;
  static const Map<String, Map<String,String>> _badgeRibbonMeta = {
    "new_store":     {"label": "🆕 NEW STORE"},
    "just_opened":   {"label": "🎉 JUST OPENED"},
    "newly_added":   {"label": "✨ NEWLY ADDED"},
    "newly_opened":  {"label": "🎉 NEWLY OPENED"},
    "newly_open":    {"label": "🎉 NEWLY OPENED"},
    "new_open":      {"label": "🎉 NEWLY OPENED"},
    "opened":        {"label": "🎉 NEWLY OPENED"},
    "trending":      {"label": "🔥 TRENDING"},
    "popular":       {"label": "⭐ POPULAR"},
    "top_rated":     {"label": "🏆 TOP RATED"},
    "must_visit":    {"label": "📍 MUST VISIT"},
    "limited_offer": {"label": "⏳ LIMITED OFFER"},
  };

  // FIX Issue-5: once a badge (esp. "newly_added") is resolved for a store,
  // remember it here. Some refresh cycles hand back a store map missing
  // created_at/badge momentarily (merge from a lighter-weight fetch) which
  // made the ribbon flash and then disappear. Sticking to the last known
  // good badge per store id prevents that flicker.
  static final Map<String, String> _badgeStickyCache = {};

  String? _resolveStoreBadge(Map<String,dynamic> s) {
    final String sid = s["_id"]?.toString() ?? s["id"]?.toString() ?? "";
    String? resolved;
    // 1. Explicit admin badge — highest priority
    final badge = s["badge"]?.toString() ?? "";
    if (badge.isNotEmpty && _badgeRibbonMeta.containsKey(badge)) {
      resolved = badge;
    }
    // 2. Auto: show "newly_added" if store was created within last 10 days
    if (resolved == null) {
      try {
        final raw = s["created_at"]?.toString() ?? "";
        if (raw.isNotEmpty) {
          final dt = DateTime.tryParse(raw);
          if (dt != null && DateTime.now().difference(dt).inDays < 10) {
            resolved = "newly_added";
          }
        }
      } catch (_) { }
    }
    // 3. Manual boolean flags (robust: handle string "true" too)
    if (resolved == null) {
      final _isNew = s["is_new_in_town"] == true
          || s["is_new_in_town"]?.toString() == 'true'
          || s["is_new"] == true
          || s["is_new"]?.toString() == 'true';
      if (_isNew) resolved = "new_store";
      else if (s["is_trending"] == true || s["is_trending"]?.toString() == 'true') resolved = "trending";
      else if (s["is_popular"] == true || s["is_popular"]?.toString() == 'true') resolved = "popular";
    }
    if (sid.isNotEmpty) {
      if (resolved != null) {
        _badgeStickyCache[sid] = resolved;
      } else if (_badgeStickyCache.containsKey(sid)) {
        // Keep showing the last known badge instead of letting it vanish
        resolved = _badgeStickyCache[sid];
      }
    }
    return resolved;
  }

  // Open/close status — logic moved verbatim out of _storeCard so the row-height
  // calculation below can know whether the status row will be shown. Returns
  // [statusLabel, closingInfo].
  List<String> _storeStatus(Map<String,dynamic> s) {
    // Uses the shared computeStoreOpenStatus() — same logic as Store Detail.
    final st = computeStoreOpenStatus(
      s["open_time"]?.toString() ?? "",
      s["close_time"]?.toString() ?? "",
    );
    if (st == null) return ["", ""];
    return [st.isOpen ? "Open" : "Closed", st.subLabel];
  }

  // Card geometry shared by _storeCard and the carousel row height. The card
  // hugs its content, and the parent horizontal ListView needs a fixed height,
  // so that height is computed as the tallest card actually in the list (text
  // measured with the same styles/widths the card uses) instead of a
  // worst-case constant.
  double _storeCardW(BuildContext ctx) =>
      (MediaQuery.sizeOf(ctx).width * 0.72).clamp(240.0, 290.0);

  _StoreCardLayout _storeLayout(BuildContext ctx, Map<String,dynamic> s) {
    final scaler = MediaQuery.textScalerOf(ctx);
    double mh(String t, TextStyle st, double w, [int lines = 1]) {
      final tp = TextPainter(text: TextSpan(text: t, style: st),
        textDirection: TextDirection.ltr, maxLines: lines, textScaler: scaler);
      try {
        tp.layout(maxWidth: w);
        return tp.height; // read before dispose (finally runs after the value is computed)
      } finally {
        tp.dispose();
      }
    }
    double mw(String t, TextStyle st) {
      final tp = TextPainter(text: TextSpan(text: t, style: st),
        textDirection: TextDirection.ltr, maxLines: 1, textScaler: scaler);
      try {
        tp.layout();
        return tp.width; // read before dispose
      } finally {
        tp.dispose();
      }
    }
    const nameSt  = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.2);
    const ratSt   = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800);
    const cntSt   = TextStyle(fontSize: 11.5);
    const catSt   = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500);
    const pillSt  = TextStyle(fontSize: 13, fontWeight: FontWeight.w800);
    const hoursSt = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500);

    final name     = s["store_name"]?.toString() ?? "";
    final cat      = s["category"]?.toString() ?? "";
    final rating   = (s["rating"] as num?)?.toDouble() ?? 0.0;
    final revCount = (s["rating_count"] ?? s["review_count"] as num?)?.toInt() ?? 0;
    final st       = _storeStatus(s);

    final cardW  = _storeCardW(ctx);
    final imgH   = (cardW * 0.57).roundToDouble();
    final innerW = cardW - 2 - 28; // border + horizontal padding

    // Rating width (star + value + " (count)")
    final ratingW = rating > 0
        ? 18 + mw(rating.toStringAsFixed(1), ratSt) + (revCount > 0 ? mw(" ($revCount)", cntSt) : 0)
        : 0.0;
    // If side-by-side would leave the name too narrow, the rating moves to the
    // category line instead (name never gets squeezed).
    final nameAvail = innerW - (rating > 0 ? 8 + ratingW : 0);
    final stack = rating > 0 && nameAvail < 120;

    final nameH = mh(name, nameSt, stack || rating <= 0 ? innerW : nameAvail, 2);
    double row2 = 0;
    if (stack) {
      row2 = max(cat.isNotEmpty ? mh(cat, catSt, innerW - ratingW - 6) : 0, 17);
    } else if (cat.isNotEmpty) {
      row2 = mh(cat, catSt, innerW);
    }
    double statusH = 0;
    if (st[0].isNotEmpty || st[1].isNotEmpty) {
      final pillH = st[0].isNotEmpty ? mh("Open Now", pillSt, 200) + 12 : 0.0;
      final hoursH = st[1].isNotEmpty ? max(17.0, mh(st[1], hoursSt, 200)) : 0.0;
      statusH = 10 + 1 + 10 + max(max(pillH, hoursH), 22.0);
    }
    final infoH = 22 + max(nameH, rating > 0 && !stack ? 17.0 : 0) +
        (row2 > 0 ? 2 + row2 : 0) + statusH;
    final total = 8 + 6 + 2 + imgH + infoH + 2; // margins + border + safety (ribbon is an image overlay, adds no height)
    return _StoreCardLayout(total.ceilToDouble(), stack);
  }

  // Layout of each of the (max 8) stores the carousel shows, measured once.
  // Index i matches widget.stores[i], same cap as _storeCardsList.
  List<_StoreCardLayout> _storeLayouts(BuildContext ctx) {
    final n = widget.stores.length > 8 ? 8 : widget.stores.length;
    return [for (int i = 0; i < n; i++) _storeLayout(ctx, widget.stores[i])];
  }

  double _storeRowHeight(List<_StoreCardLayout> layouts) {
    double m = 0;
    for (final l in layouts) {
      m = max(m, l.height);
    }
    return m > 0 ? m : 260.0;
  }

  Widget _ratingChip(double rating, int revCount) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, color: OffroColors.amber, size: 16),
      const SizedBox(width: 2),
      Text(rating.toStringAsFixed(1),
        style: const TextStyle(color: Color(0xFF1a2e27), fontSize: 13.5, fontWeight: FontWeight.w800)),
      if (revCount > 0) Text(" ($revCount)",
        style: const TextStyle(color: Color(0xFF9e9e9e), fontSize: 11.5)),
    ]);

  Widget _storeCard(BuildContext ctx, Map<String,dynamic> s, bool stackRating) {
    final name      = s["store_name"]?.toString() ?? "";
    final cat       = s["category"]?.toString() ?? "";
    final rating    = (s["rating"] as num?)?.toDouble() ?? 0.0;
    final revCount  = (s["rating_count"] ?? s["review_count"] as num?)?.toInt() ?? 0;
    final dist      = (s["distance_km"] as num?)?.toDouble();
    final distTxt   = dist != null
        ? (dist < 1.0 ? "${(dist * 1000).toStringAsFixed(0)} m" : "${dist.toStringAsFixed(1)} km")
        : null; // Hide badge when GPS/distance not yet available
    final _st         = _storeStatus(s);
    final String statusLabel = _st[0];
    final String closingInfo = _st[1];
    // ── Badge key for glass ribbon ──
    final String? badgeKey = _resolveStoreBadge(s);

    // Resolve logo
    String logoSrc = s["logo_url"]?.toString() ?? s["logo"]?.toString() ?? s["logo_thumb"]?.toString() ?? "";
    if (logoSrc.isEmpty)
      logoSrc = s["image_url"]?.toString() ?? s["image"]?.toString() ?? s["image_thumb"]?.toString() ?? "";

    // QA round (Oct 2026) — Main Store Card redesign (visual only).
    // Was: a small 56px circular logo centered above center-aligned text,
    // with the distance badge/heart in their own header row above it. Now:
    // the store photo is the dominant visual element at the top of the
    // card (like the reference e-commerce card), with the distance badge
    // and favorite heart overlaid directly on the image — matching the
    // reference's badge/heart placement — and the badge ribbon (new/
    // trending/etc.) moved from the bottom of the whole card to the bottom
    // of the image. All the same fields (name, category, distance, rating,
    // open/closed status, opening/closing info, favorite state, badge) are
    // still shown; only the layout/sizing/hierarchy changed. Same API/
    // data/navigation/favorite-toggle/distance calc as before — none of
    // that logic was touched below.
    // QA round (Oct 2026) — Main Store Card follows the approved mockup:
    // large full-width image (distance badge + heart over it) -> full-width
    // ribbon band directly under the image -> name (left) + rating/reviews
    // (right) -> category -> divider -> status | hours row. The card hugs its
    // content (Align below) so no blank area is left at the bottom. All data,
    // favorite toggle, distance, status logic and navigation are unchanged.
    final double _cardW = _storeCardW(ctx);
    final bool _stack = stackRating;
    final double _cardImgH = (_cardW * 0.57).roundToDouble();
    Widget storeImageWidget;
    if (logoSrc.startsWith("http")) {
      storeImageWidget = CachedNetworkImage(
        imageUrl: logoSrc,
        fit: BoxFit.cover,
        width: double.infinity, height: _cardImgH,
        placeholder: (_, __) => Container(color: const Color(0xFFA9CDBA)),
        errorWidget: (_, __, ___) => _storeFallback(name));
    } else if (logoSrc.startsWith("data:image")) {
      try {
        // Decode once per distinct image: a stable byte buffer keeps the same
        // MemoryImage key across rebuilds, so the image is not re-decoded/flashed.
        final bytes = decodeBase64ImageCached(logoSrc);
        storeImageWidget = Image.memory(bytes,
          fit: BoxFit.cover, width: double.infinity, height: _cardImgH);
      } catch (_) { storeImageWidget = _storeFallback(name); }
    } else {
      storeImageWidget = _storeFallback(name);
    }
    final String _sid = s["_id"]?.toString() ?? s["id"]?.toString() ?? "";

    return Align(
      alignment: Alignment.topLeft,
      child: GestureDetector(
      onTap: () => Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => StoreDetailPage(
          store: _enrichStoreForDetail(Map<String,dynamic>.from(s)),
          token: widget.token, userName: "",
          onProductTap:(p,tk)=>Navigator.push(context,appRoute(ProductDetailsPage(product:p,token:tk)))))).then((_) => widget.onFavChanged()),
      child: Container(
        width: _cardW,
        margin: const EdgeInsets.only(right: 12, top: 8, bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: OffroColors.border, width: 1.0),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: .09),
            blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Large store image with distance badge + heart over it ──
            SizedBox(
              width: double.infinity,
              height: _cardImgH,
              child: Stack(children: [
                Positioned.fill(child: storeImageWidget),

                // Badge ribbon — overlaid on the bottom of the image (image keeps its full
                // size; nothing is rendered or reserved when the store has no badge).
                if (badgeKey != null)
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Container(
                      width: double.infinity,
                      height: _kBadgeRibbonH,
                      color: const Color(0xFF3a3a35),
                      alignment: Alignment.center,
                      child: Text(
                        _badgeRibbonMeta[badgeKey]!["label"]!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                // Distance badge — OffrO green filled pill, white content
                if (distTxt != null)
                  Positioned(top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E5F55),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .20), blurRadius: 5)],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 3),
                        Text(distTxt,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),

                // Favorite heart — top-right, circular, light background
                // (same FavState / Api.toggleFavorite logic as before)
                Positioned(top: 10, right: 10,
                  child: GestureDetector(
                    onTap: () async {
                      final id = s["_id"]?.toString() ?? s["id"]?.toString() ?? "";
                      if (id.isEmpty || widget.token.isEmpty) return;
                      // One in-flight request per store; ignore taps until it settles.
                      if (!FavState.instance.tryLockStore(id)) return;
                      final prev = FavState.instance.hasStore(id);
                      FavState.instance.setStore(id, !prev); // optimistic
                      try {
                        final confirmed = await Api.toggleFavorite(widget.token, id);
                        FavState.instance.setStore(id, confirmed); // server-confirmed
                      } catch (e) {
                        FavState.instance.setStore(id, prev); // restore
                        if (mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text("Couldn't save favorite: ${friendlyError(e)}"),
                            backgroundColor: Colors.red.shade700,
                            duration: const Duration(seconds: 12),
                            showCloseIcon: true));
                        }
                      } finally {
                        FavState.instance.unlockStore(id);
                      }
                    },
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .95),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 5)],
                      ),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: FavState.instance.storeListenable(_sid),
                        builder: (_, isFav, __) => Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav
                              ? const Color(0xFFe74c3c)
                              : const Color(0xFF9e9e9e),
                          size: 19),
                      ),
                    ),
                  ),
                ),
              ]),
            ),

            // ── Info block ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Name (left) + rating/reviews (right). If the rating is too wide
                // to leave the name readable, it drops to the category line.
                if (_stack)
                  Text(name,
                    style: const TextStyle(
                      color: Color(0xFF1a2e27), fontSize: 16,
                      fontWeight: FontWeight.w800, height: 1.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis)
                else
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(name,
                        style: const TextStyle(
                          color: Color(0xFF1a2e27), fontSize: 16,
                          fontWeight: FontWeight.w800, height: 1.2),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    if (rating > 0) ...[
                      const SizedBox(width: 8),
                      Padding(padding: const EdgeInsets.only(top: 1), child: _ratingChip(rating, revCount)),
                    ],
                  ]),

                if (cat.isNotEmpty || (_stack && rating > 0)) ...[
                  const SizedBox(height: 2),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(
                      child: cat.isNotEmpty
                        ? Text(cat,
                            style: const TextStyle(
                              color: Color(0xFF8a9a93), fontSize: 12.5,
                              fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                        : const SizedBox.shrink(),
                    ),
                    if (_stack && rating > 0) ...[
                      const SizedBox(width: 6),
                      _ratingChip(rating, revCount),
                    ],
                  ]),
                ],

                // Divider + status row (same status/hours logic; empty = hidden)
                Builder(builder: (_ctx) {
                  final _displayLabel = statusLabel.isNotEmpty ? statusLabel : "";
                  final _displayInfo  = closingInfo.isNotEmpty ? closingInfo : "";
                  if (_displayLabel.isEmpty && _displayInfo.isEmpty) return const SizedBox.shrink();
                  final bool _open = _displayLabel == "Open";
                  return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 10),
                    Container(height: 1, color: const Color(0xFFe6ece9)),
                    const SizedBox(height: 10),
                    // Status row (matches approved reference): green pill |
                    // vertical divider | clock icon + dynamic hours text,
                    // all on one horizontal line.
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      if (_displayLabel.isNotEmpty) Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                        decoration: BoxDecoration(
                          color: _open ? const Color(0xFFCDEBD6) : const Color(0xFFfdf0f0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_open ? "Open Now" : _displayLabel,
                          style: TextStyle(
                            color: _open ? const Color(0xFF2f5a47) : const Color(0xFFc0392b),
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                      ),
                      if (_displayLabel.isNotEmpty && _displayInfo.isNotEmpty)
                        Container(
                          width: 1, height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 11),
                          color: const Color(0xFFd5ddd9)),
                      if (_displayInfo.isNotEmpty) ...[
                        const Icon(Icons.access_time_rounded, size: 17, color: Color(0xFF6b7c75)),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(_displayInfo,
                            style: const TextStyle(
                              color: Color(0xFF5f6f68),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ]),
                  ]);
                }),

              ]),
            ),
          ]),
        ),
      ),
    ));
  }

  Widget _storeFallback(String name) => Container(
    color: const Color(0xFFA9CDBA),
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : "S",
      style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 28, fontWeight: FontWeight.w900))),
  );
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
    // FIX: safe parse — rating may be stored as String "4.2"
    final _rRaw = widget.product["rating"]; _avgRating = (_rRaw is num) ? _rRaw.toDouble() : (double.tryParse(_rRaw?.toString() ?? "") ?? 0.0);
    final _rcRaw = widget.product["rating_count"]; _ratingCount = (_rcRaw is num) ? _rcRaw.toInt() : (int.tryParse(_rcRaw?.toString() ?? "") ?? 0);
    _loadFavStatus();
    _loadMyReview();
    // FIX: fire "view" analytics event — trackProductEvent() existed but was
    // never called anywhere, so Premium Product Analytics always showed 0.
    final _pidTrack = widget.product["_id"]?.toString() ?? widget.product["id"]?.toString() ?? "";
    if (_pidTrack.isNotEmpty) Api.trackProductEvent(_pidTrack, "view");
  }

  // Branded share card (image + caption + product link); plain text if the
  // card can't be built. Logic lives in core/widgets/product_share_card.dart.
  bool _shareBusy = false;
  Future<void> _shareProduct() async {
    if (_shareBusy) return; // no double taps / duplicate analytics
    setState(() => _shareBusy = true);
    try {
      await ProductShare.share(
        context,
        widget.product,
        // Called once, right before the share sheet opens (same "share"
        // analytics event as before — never twice, even if the text fallback runs).
        onInitiated: () {
          final pid = widget.product["_id"]?.toString() ?? widget.product["id"]?.toString() ?? "";
          if (pid.isNotEmpty) Api.trackProductEvent(pid, "share");
          if (mounted) setState(() => _shareBusy = false);
        },
      );
    } catch (_) {
      // ProductShare.share never throws; belt and braces.
    } finally {
      if (mounted && _shareBusy) setState(() => _shareBusy = false);
    }
  }

  Future<void> _loadMyReview() async {
    if (widget.token.isEmpty) return;
    final pid = widget.product["_id"]?.toString() ?? widget.product["id"]?.toString() ?? "";
    if (pid.isEmpty) return;
    try {
      final rev = await Api.getMyProductReview(widget.token, pid);
      if (rev.isNotEmpty && rev["rating"] != null) {
        if (mounted) setState(() {
          _userRating      = (rev["rating"] as num).toDouble();
          _reviewCtrl.text = rev["text"]?.toString() ?? "";
          _reviewSubmitted = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFavStatus() async {
    if (widget.token.isEmpty) return;
    final pid = widget.product["_id"]?.toString() ?? widget.product["id"]?.toString() ?? "";
    if (pid.isEmpty) return;
    final fav = await Api.isProductFavorite(widget.token, pid);
    FavState.instance.setProduct(pid, fav);
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
          try { return Image.memory(decodeBase64ImageCached(v), fit: BoxFit.cover, width: double.infinity, height: double.infinity); } catch (_) { }
        }
      }
    }
    for (final k in keys) {
      final v = widget.product[k]?.toString() ?? "";
      if (v.startsWith("http")) return CachedNetworkImage(imageUrl: v, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
        placeholder: (_, __) => Container(color: const Color(0xFFA9CDBA)),
        errorWidget: (_, __, ___) => _fallbackImg());
      if (v.startsWith("data:image")) {
        try { return Image.memory(decodeBase64ImageCached(v), fit: BoxFit.cover, width: double.infinity, height: double.infinity); } catch (_) { }
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
          try { return Image.memory(decodeBase64ImageCached(v), fit: BoxFit.contain); } catch (_) { }
        }
      }
    }
    for (final k in keys) {
      final v = widget.product[k]?.toString() ?? "";
      if (v.startsWith("http")) return CachedNetworkImage(imageUrl: v, fit: BoxFit.contain,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => _fallbackImg());
      if (v.startsWith("data:image")) {
        try { return Image.memory(decodeBase64ImageCached(v), fit: BoxFit.contain); } catch (_) { }
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
    if (text.length < 3 || _userRating == 0) return;
    final pid = widget.product["_id"]?.toString() ?? widget.product["id"]?.toString() ?? "";
    if (pid.isEmpty) return;
    // FIX: check token before submitting — prevents confusing "Session expired" error
    if (widget.token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text("Please log in to submit a review."),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
          showCloseIcon: true));
      }
      return;
    }
    setState(() => _reviewSubmitting = true);
    try {
      final result = await Api.submitProductReview(widget.token, pid, _userRating, text);
      if (result.containsKey("error")) {
        if (mounted) {
          setState(() => _reviewSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result["error"].toString()),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 12),
            showCloseIcon: true));
        }
        return;
      }
      // FIX: trust the backend's authoritative avg_rating (it recalculates
      // from ALL reviews in the DB) instead of calculating locally from
      // _avgRating/_ratingCount which may have been wrong if the product
      // was loaded from a feed that returned the STORE's rating instead
      // of the product's own rating.
      final serverAvg = result["avg_rating"];
      if (mounted) setState(() {
        _reviewSubmitting = false;
        _reviewSubmitted  = true;
        if (serverAvg != null) {
          _avgRating   = double.parse(serverAvg.toString());
          _ratingCount = _ratingCount + 1;
        } else {
          final newCount = _ratingCount + 1;
          final newAvg   = ((_avgRating * _ratingCount) + _userRating) / newCount;
          _ratingCount   = newCount;
          _avgRating     = double.parse(newAvg.toStringAsFixed(1));
        }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review submitted! Thank you."),
          backgroundColor: Color(0xFF3E5F55)));
    } catch (e) {
      debugPrint('[OffrO] product review submit error: $e');
      if (mounted) {
        setState(() => _reviewSubmitting = false);
        // FIX: detect "Session expired" and show a user-friendly message with login prompt
        final errStr = e.toString();
        final isSessionExpired = errStr.contains("Session expired") || errStr.contains("401");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isSessionExpired
              ? "Your session has expired. Please log in again to submit a review."
              : friendlyError(e)),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 12),
          showCloseIcon: true,
          action: isSessionExpired ? SnackBarAction(
            label: "Login",
            textColor: Colors.white,
            onPressed: () => MyApp.goLogin(),
          ) : null,
        ));
      }
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
    // FIX: read the actual offer/deal text fields (text/offer_text) — "offer" key doesn't exist
    // on real product records, which made this always render empty on the details page.
    final offerText  = p["text"]?.toString() ?? p["offer_text"]?.toString() ?? p["offer"]?.toString() ?? p["discount"]?.toString() ?? "";
    final discMatch  = RegExp(r'(\d+)%').firstMatch(offerText);
    final discBadge  = discMatch != null ? "${discMatch.group(1)}% OFF" : "";
    // Merchant "Offer Text", shown as plain text under the title. First NON-empty
    // value (an empty "text" must not hide a filled "offer_text").
    final offerDesc  = [p["offer_text"], p["text"], p["offer"]]
        .map((e) => e?.toString().trim() ?? "")
        .firstWhere((e) => e.isNotEmpty && e != "null", orElse: () => "");

    final saleP = _numVal(["offer_price","sale_price","price","current_price"]); // ITEM10
    final origP = _numVal(["original_price","mrp","was_price","compare_price"]);
    final showOrig = origP != null && saleP != null && origP > saleP;

    final topInset = MediaQuery.of(context).padding.top;
    final category = (p["category"]?.toString().trim().isNotEmpty == true ? p["category"].toString() : storeCat).trim();

    Widget circleBtn(Widget child, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), shape: BoxShape.circle),
        child: child,
      ),
    );

    Future<void> openStore() async {
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
      // FIX: fire "open" analytics event — user opened/visited the store from this product
      final pidOpen = widget.product["_id"]?.toString() ?? widget.product["id"]?.toString() ?? "";
      if (pidOpen.isNotEmpty) Api.trackProductEvent(pidOpen, "open");
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => StoreDetailPage(
          store: fullStore,
          token: widget.token,
          userName: "",
          onProductTap:(p,tk)=>Navigator.push(context,appRoute(ProductDetailsPage(product:p,token:tk))))));
    }

    void openImageViewer() => showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8, maxScale: 5.0,
              child: Center(child: _resolveImageContained()),
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
    );

    final storeRating = (storeData["rating"] as num?)?.toDouble() ??
                        (storeData["admin_rating"] as num?)?.toDouble() ?? 0.0;
    final storeDist   = (storeData["distance_km"] as num?)?.toDouble();
    final distLabel   = storeDist != null
        ? (storeDist < 1.0 ? "${(storeDist * 1000).toStringAsFixed(0)} m away"
                           : "${storeDist.toStringAsFixed(1)} km away")
        : "";

    return OffroFontScope(child: Scaffold(
      backgroundColor: OffroColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Edge-to-edge hero image ──
          SizedBox(
            height: 360,
            child: Stack(fit: StackFit.expand, children: [
              GestureDetector(onTap: openImageViewer, child: _resolveImage()),
              const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0x40000000), Color(0x00000000), Color(0x00000000), Color(0x26000000)],
                  stops: [0.0, 0.3, 0.7, 1.0])))),
              Positioned(
                top: topInset + 8, left: 16, right: 16,
                child: Row(children: [
                  circleBtn(const OffroIcon(OffroIcons.back, size: 18, color: OffroColors.text), () => Navigator.pop(context)),
                  const Spacer(),
                  // ── Share button (existing branded share + analytics) ──
                  circleBtn(
                    _shareBusy
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: OffroColors.primary))
                        : const OffroIcon(OffroIcons.share, size: 17, color: OffroColors.text),
                    _shareBusy ? null : _shareProduct),
                  const SizedBox(width: 8),
                  circleBtn(
                    OffroIcon(OffroIcons.heart, size: 17,
                      color: _isFav ? OffroColors.terracotta : OffroColors.text, filled: _isFav),
                    _toggleFavorite),
                ]),
              ),
              if (discBadge.isNotEmpty)
                Positioned(left: 20, bottom: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: OffroColors.primary, borderRadius: OffroRadii.pillRadius),
                    child: Text(discBadge.toLowerCase().replaceAll(" off", "") + " off",
                      style: OffroText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  )),
            ]),
          ),

          Transform.translate(
            offset: const Offset(0, -24),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: OffroColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (category.isNotEmpty)
                  Text(category.toUpperCase(),
                    style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.8, color: OffroColors.sage)),
                if (category.isNotEmpty) const SizedBox(height: 8),
                Text(title, style: OffroText.display.copyWith(fontSize: 30, letterSpacing: -1.8, height: 1.1)),

                // Offer text under the title (nothing when empty)
                if (offerDesc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(offerDesc, style: OffroText.bodySmall.copyWith(fontSize: 13, height: 1.45, color: OffroColors.textMuted)),
                ],

                // ── Price + rating ──
                if (saleP != null || showOrig || _avgRating > 0 || _ratingCount > 0) ...[
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    if (saleP != null)
                      Text("₹${saleP.toStringAsFixed(0)}", style: OffroText.headline.copyWith(fontSize: 22, letterSpacing: -0.8)),
                    if (showOrig) ...[
                      const SizedBox(width: 8),
                      Text("₹${origP!.toStringAsFixed(0)}",
                        style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400,
                          color: OffroColors.textFaint, decoration: TextDecoration.lineThrough)),
                    ],
                    const Spacer(),
                    if (_avgRating > 0 || _ratingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: OffroColors.beige, borderRadius: OffroRadii.pillRadius),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const OffroIcon(OffroIcons.star, size: 12, color: OffroColors.amber, filled: true),
                          const SizedBox(width: 4),
                          Text(_avgRating.toStringAsFixed(1),
                            style: OffroText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: OffroColors.text)),
                          if (_ratingCount > 0) ...[
                            const SizedBox(width: 3),
                            Text("($_ratingCount)",
                              style: OffroText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w400, color: OffroColors.textMuted)),
                          ],
                        ]),
                      ),
                  ]),
                ],

                // ── Listed by store card ──
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: (storeName.isNotEmpty || storeId.isNotEmpty) ? openStore : null,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: storeIsActive ? OffroColors.mint : const Color(0xFFF0EEE9),
                            borderRadius: BorderRadius.circular(14)),
                          child: OffroIcon(OffroIcons.store, size: 20,
                            color: storeIsActive ? OffroColors.primary : const Color(0xFF9E9E9E)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text("Listed by",
                            style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textFaint)),
                          const SizedBox(height: 2),
                          Text(storeName, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: OffroText.cardTitle.copyWith(fontSize: 13)),
                          if (storeArea.isNotEmpty || storeCat.isNotEmpty || storeRating > 0 || distLabel.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text([
                              if (storeCat.isNotEmpty) storeCat,
                              if (storeArea.isNotEmpty) storeArea,
                              if (storeRating > 0) "★ ${storeRating.toStringAsFixed(1)}",
                              if (distLabel.isNotEmpty) distLabel,
                            ].join("  ·  "),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textSubtle)),
                          ],
                        ])),
                        const SizedBox(width: 8),
                        Text("View store", style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: OffroColors.primary)),
                        const SizedBox(width: 2),
                        const OffroIcon(OffroIcons.chevron, size: 14, color: OffroColors.primary),
                      ]),
                      // ── Store inactive badge (store subscription expired) ──
                      if (!storeIsActive) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: OffroColors.amber.withValues(alpha: .12),
                            borderRadius: OffroRadii.pillRadius),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.info_outline_rounded, size: 12, color: OffroColors.amber),
                            const SizedBox(width: 5),
                            Text("Store Currently Inactive",
                              style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: OffroColors.amber)),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ),

                // ── Offer card (real offer text only) ──
                if (offerText.trim().isNotEmpty && offerText.trim() != "null") ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: OffroColors.mint, borderRadius: BorderRadius.circular(22)),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: OffroColors.primary, shape: BoxShape.circle),
                        child: const OffroIcon(OffroIcons.tag, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("OffrO offer", style: OffroText.cardTitle.copyWith(fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(offerText.trim(),
                          style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, height: 1.4,
                            color: OffroColors.primary.withValues(alpha: .7))),
                      ])),
                    ]),
                  ),
                ],

                // ── Product details ──
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Text("Product details", style: OffroText.title.copyWith(fontSize: 20)),
                  const SizedBox(height: 10),
                  Text(description, style: OffroText.bodySmall.copyWith(fontSize: 13, height: 1.6, color: OffroColors.textMuted)),
                ],

                // ── Rate & Review ──
                const SizedBox(height: 28),
                Text("Rate & Review", style: OffroText.title.copyWith(fontSize: 20)),
                const SizedBox(height: 12),
                // Star rating selector (locked once review submitted)
                AbsorbPointer(
                  absorbing: _reviewSubmitted,
                  child: Row(children: [
                    ...List.generate(5, (i) => GestureDetector(
                      onTap: () => setState(() => _userRating = i + 1.0),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          i < _userRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: OffroColors.amber, size: 30)),
                    )),
                    const SizedBox(width: 8),
                    Text(_userRating == 0 ? "Tap to rate" : ["","Poor","Fair","Good","Great","Excellent"][_userRating.toInt()],
                      style: OffroText.caption.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600,
                        color: _userRating == 0 ? OffroColors.textMuted : OffroColors.primary)),
                  ])),
                const SizedBox(height: 14),
                if (!_reviewSubmitted) ...[
                  TextField(
                    controller: _reviewCtrl,
                    maxLines: 3,
                    style: OffroText.body.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Share your experience with this product...",
                      hintStyle: OffroText.body.copyWith(fontSize: 13, color: OffroColors.textPlaceholder),
                      filled: true, fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: OffroColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: OffroColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: OffroColors.primary, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: (_userRating > 0 && !_reviewSubmitting) ? _submitReview : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OffroColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: OffroColors.primary.withValues(alpha: .35),
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: _reviewSubmitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text("Submit Review", style: OffroText.button.copyWith(color: Colors.white, fontSize: 13)),
                    ),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: OffroColors.mint, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, color: OffroColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text("Thanks for your review!", style: OffroText.cardTitle.copyWith(fontSize: 13)),
                    ]),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    ));
  }

  // Favourite toggle — same optimistic update + server-verified logic as before.
  Future<void> _toggleFavorite() async {
    final pid = widget.product["_id"]?.toString() ?? widget.product["id"]?.toString() ?? "";
    final prev = _isFav;
    setState(() => _isFav = !_isFav); // optimistic
    FavState.instance.toggleProduct(pid);
    // toggleProductFavorite throws on failure and returns the server's
    // DB-verified state on success, so we can trust it.
    if (widget.token.isNotEmpty && pid.isNotEmpty) {
      try {
        final confirmed = await Api.toggleProductFavorite(widget.token, pid);
        if (mounted && confirmed != _isFav) {
          setState(() => _isFav = confirmed);
          FavState.instance.setProduct(pid, confirmed);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isFav = prev);
          FavState.instance.setProduct(pid, prev);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Couldn't save favorite: ${friendlyError(e)}"),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 12),
            showCloseIcon: true));
        }
      }
    }
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
        // FIX: only overwrite if the fresh list is non-empty — prevents wiping
        // the initial (cached) product list when the API has a transient error
        if (fresh.isNotEmpty) {
          _all = List<Map<String,dynamic>>.from(fresh);
        }
        _fetching = false;
      });
    } catch (_) {
      // FIX: keep the initial product list on error instead of showing empty
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
    // Figma "all products": cream page, Manrope header, search field, real
    // category chips (no "All" chip - tap the active chip again to clear it),
    // 2-column grid of OffrO product cards. Real data via the existing fetch.
    final realCats = _cats.where((c) => c != "All").toList();
    return OffroFontScope(child: Scaffold(
      backgroundColor: OffroColors.background,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: SafeArea(
          bottom: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OffroScreenHeader(
              eyebrow: "Across local stores",
              title: "All products",
              showBack: true,
              onBack: () => Navigator.maybePop(context),
            ),
            const SizedBox(height: 14),
            const _VapSearchBar(),
          ]),
        )),
        if (realCats.isNotEmpty)
          SliverToBoxAdapter(child: Container(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            color: OffroColors.background,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(children: realCats.map((cat) {
                final active = _cat == cat;
                return GestureDetector(
                  onTap: () => setState(() => _cat = active ? "All" : cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? OffroColors.primary : OffroColors.surface,
                      borderRadius: OffroRadii.pillRadius,
                      border: active ? null : Border.all(color: OffroColors.border),
                    ),
                    child: Text(cat, style: OffroText.caption.copyWith(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: active ? Colors.white : OffroColors.secondarySolid)),
                  ),
                );
              }).toList()),
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
                decoration: const BoxDecoration(color: OffroColors.beige, shape: BoxShape.circle),
                child: const Icon(Icons.storefront_outlined, color: OffroColors.secondarySolid, size: 40)),
              const SizedBox(height: 16),
              Text("No products found",
                style: OffroText.cardTitle.copyWith(fontSize: 16)),
            ])))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.80,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => ProductDetailCard(
                  product: Map<String,dynamic>.from(_filtered[i]),
                  colorIdx: i,
                  token: widget.token,
                ),
                childCount: _filtered.length,
              ),
            ),
          ),
      ]),
    ));
  }
}


// ─────────────────────── VOUCHER SUPPORT WIDGETS ───────────────────────

class ProductDetailCard extends StatefulWidget {
  final Map product;
  final int colorIdx;
  final String token;
  const ProductDetailCard({required this.product, this.colorIdx = 0, this.token = ""});
  @override State<ProductDetailCard> createState() => _ProductDetailCardState();
}
class _ProductDetailCardState extends State<ProductDetailCard> {
  Map get product => widget.product;
  int  get colorIdx => widget.colorIdx;
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    final pid = product["_id"]?.toString() ?? product["id"]?.toString() ?? "";
    if (pid.isNotEmpty) _isFav = FavState.instance.hasProduct(pid);
  }

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
          try { return Image.memory(decodeBase64ImageCached(si), fit:BoxFit.cover, width:double.infinity, height:double.infinity, gaplessPlayback:true); } catch(_) { }
        }
        final siUrl = resolveImageUrl(si);
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
        try { return Image.memory(decodeBase64ImageCached(img), fit:BoxFit.cover, width:double.infinity, height:double.infinity, gaplessPlayback:true); } catch(_) { }
      }
      final imgUrl2 = resolveImageUrl(img);
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
        validity = "${_vdt.day} ${_vmo[_vdt.month-1]} ${_vdt.year}";
      } catch (_) {
        // Not ISO format — try dd/mm/yyyy or dd-mm-yyyy
        try {
          final parts = _validSafe.split(RegExp(r'[/\-]'));
          if (parts.length == 3) {
            const _vmo2 = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
            final d = int.parse(parts[0]); final m = int.parse(parts[1]); final y = int.parse(parts[2]);
            if (m >= 1 && m <= 12) validity = "$d ${_vmo2[m-1]} $y";
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
          color: OffroColors.background,
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
              color: pal[0],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(title.isNotEmpty ? title : "Special Offer",
              style: const TextStyle(color: Color(0xFF3E5F55), fontSize: 15, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 14),
          if (text.isNotEmpty) Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OffroColors.text, fontSize: 16, fontWeight: FontWeight.w700, height: 1.4)),
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
        validity = "${_vdt.day} ${_vmo[_vdt.month-1]} ${_vdt.year}";
      } catch (_) {
        // Not ISO format — try dd/mm/yyyy or dd-mm-yyyy
        try {
          final parts = _validSafe.split(RegExp(r'[/\-]'));
          if (parts.length == 3) {
            const _vmo2 = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
            final d = int.parse(parts[0]); final m = int.parse(parts[1]); final y = int.parse(parts[2]);
            if (m >= 1 && m <= 12) validity = "$d ${_vmo2[m-1]} $y";
          }
        } catch (_) { validity = ""; } // suppress raw strings entirely
      }
    }
    final storeName = (product["store"] is Map
        ? product["store"]["store_name"]
        : null)?.toString() ?? product["store_name"]?.toString() ?? "";
    final priceRaw = product["price"]?.toString() ?? "";
    final origRaw  = product["original_price"]?.toString() ?? product["mrp"]?.toString() ?? "";
    final discount = product["discount_label"]?.toString() ?? product["discount"]?.toString() ?? "";
    final isBestSeller = (product["best_seller"] == true) ||
        (product["tag"]?.toString().toLowerCase() == "best seller");

    // Badge label + color (text-only badge removed to keep cards clean)
    String badgeLabel = "";
    Color  badgeColor = OffroColors.terracotta;
    if (isBestSeller) {
      badgeLabel = "BEST SELLER";
      badgeColor = OffroColors.amber;
    } else if (discount.isNotEmpty && discount != "0") {
      badgeLabel = discount.contains("%") ? discount.replaceAll(RegExp(r'\s*OFF\s*', caseSensitive: false), "") : "$discount%";
      badgeColor = OffroColors.terracotta;
    }

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: OffroColors.surface,
          borderRadius: BorderRadius.circular(OffroRadii.card),
          border: Border.all(color: OffroColors.border, width: 1),
          boxShadow: OffroShadows.card,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top: Product image with badge overlay ──
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(OffroRadii.card - 1)),
              child: SizedBox(
                height: 118,
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
                  borderRadius: OffroRadii.pillRadius,
                ),
                child: Text(badgeLabel,
                  style: OffroText.caption.copyWith(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  maxLines: 1),
              )),
            // Heart icon top-right — live toggle via FavState
            Positioned(top: 7, right: 7, child: GestureDetector(
              onTap: () async {
                final pid = product["_id"]?.toString() ?? product["id"]?.toString() ?? "";
                if (pid.isEmpty) return;
                final next = !_isFav;
                setState(() => _isFav = next);
                FavState.instance.setProduct(pid, next);
                try {
                  await Api.toggleProductFavorite(widget.token, pid);
                } catch (e) {
                  setState(() => _isFav = !next);
                  FavState.instance.setProduct(pid, !next);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Couldn't save favorite: ${friendlyError(e)}"),
                    backgroundColor: Colors.red.shade700,
                    duration: const Duration(seconds: 12),
                    showCloseIcon: true));
                }
              },
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: _isFav ? OffroColors.terracotta : OffroColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:.12), blurRadius:4)],
                ),
                child: Icon(
                  _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: _isFav ? Colors.white : OffroColors.primary,
                  size: 14),
              ),
            )),
            // ── Rating chip — bottom-right corner of image ──
            Builder(builder: (_) {
              final _pr = (product["rating"] as num?)?.toDouble() ?? 0.0;
              final _pc = (product["rating_count"] ?? product["review_count"] as num?)?.toInt() ?? 0;
              if (_pr <= 0) return const SizedBox.shrink();
              return Positioned(bottom: 6, right: 7,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: OffroColors.primary, borderRadius: OffroRadii.pillRadius),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, color: OffroColors.amber, size: 10),
                    const SizedBox(width: 2),
                    Text(_pr.toStringAsFixed(1),
                      style: OffroText.caption.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    if (_pc > 0) Text(" ($_pc)",
                      style: OffroText.caption.copyWith(color: OffroColors.accent, fontSize: 9, fontWeight: FontWeight.w400)),
                  ]),
                ),
              );
            }),
          ]),

          // ── Bottom: text content ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Product title — single line only, ellipsis if long (offer/description text removed from card; still shown on detail page)
              if (title.isNotEmpty)
                Text(title,
                  style: OffroText.cardTitle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              // Seller line — rating pill now on image, just show store name
              if (storeName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("Seller: " + storeName,
                    style: OffroText.caption.copyWith(color: OffroColors.secondarySolid, fontSize: 11, fontWeight: FontWeight.w400),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              if (priceRaw.isNotEmpty && priceRaw != "0") ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Text("₹$priceRaw",
                      style: OffroText.caption.copyWith(
                        color: OffroColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
                    if (origRaw.isNotEmpty && origRaw != "0") ...[
                      const SizedBox(width: 6),
                      Text("₹$origRaw",
                        style: OffroText.caption.copyWith(
                          color: OffroColors.sage, fontSize: 11, fontWeight: FontWeight.w400,
                          decoration: TextDecoration.lineThrough)),
                    ],
                  ]),
                ),
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
      color: OffroColors.background,
      padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 0, OffroSpacing.gutter, 12),
      child: TextField(
        onChanged: (v) {
          pageState?.setState(() => pageState._query = v);
        },
        style: OffroText.body.copyWith(color: OffroColors.text, fontSize: 14),
        cursorColor: OffroColors.primary,
        decoration: InputDecoration(
          hintText: "Search products...",
          hintStyle: OffroText.body.copyWith(color: OffroColors.secondarySolid, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: OffroColors.secondarySolid, size: 18),
          filled: true,
          fillColor: OffroColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: OffroColors.border)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: OffroColors.border)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: OffroColors.primary)),
        ),
      ),
    );
  }
}
