import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
// lib/core/services/fcm_service.dart
// ─────────────────────────────────────────────────────────────
// All FCM + local-notification logic in one place.
//
// What lives here:
//   • offroLocalNotif   — shared FlutterLocalNotificationsPlugin instance
//   • offroNotifChannel — the single Android notification channel
//   • initLocalNotifications()  — call once in main() before runApp
//   • showLocalNotification()   — show banner while app is in foreground
//   • FcmService                — permission, topic subscriptions, token reg
//
// What stays in main.dart (must be top-level in the same isolate as main):
//   • _firebaseMessagingBackgroundHandler
//   • FirebaseMessaging.onMessage.listen(...)
//   • FirebaseMessaging.onMessageOpenedApp.listen(...)
//
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─────────────────────── SHARED INSTANCES ───────────────────────
// These are accessed from main.dart via:
//   import 'core/services/fcm_service.dart';
//   showLocalNotification(msg);

final FlutterLocalNotificationsPlugin offroLocalNotif =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel offroNotifChannel = AndroidNotificationChannel(
  'offro_high_importance',       // id — must match AndroidManifest meta-data
  'OFFRO Notifications',         // name shown in Android settings
  description: 'Deals, vouchers and store alerts from OFFRO',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

// ─────────────────────── INIT ───────────────────────
/// Call once in main() BEFORE runApp().
/// Initialises flutter_local_notifications and creates the Android channel.
// Called by main.dart to wire navigation without circular imports.
// Set this before calling initLocalNotifications().
void Function(String payload)? onLocalNotifTap;

Future<void> initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: false, // requested separately via FCM
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await offroLocalNotif.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (resp) {
      debugPrint('[LOCAL-NOTIF] tapped: payload=\${resp.payload}');
      // Delegate navigation to main.dart (avoids circular imports)
      onLocalNotifTap?.call(resp.payload ?? '');
    },
  );
  // Create the Android 8+ notification channel
  await offroLocalNotif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(offroNotifChannel);
  debugPrint('[LOCAL-NOTIF] ✅ Channel created: ${offroNotifChannel.id}');
}

// ─────────────────────── SHOW NOTIFICATIONS ───────────────────────
/// Called from main.dart's FirebaseMessaging.onMessage listener.
/// Shows a local banner while the app is in the foreground.
/// Supports image notifications: shows text immediately, upgrades to image
/// once the download completes (no delay for the user).
void showLocalNotification(RemoteMessage msg) {
  final notif = msg.notification;
  if (notif == null && msg.data.isEmpty) return;

  final title    = notif?.title ?? msg.data['title'] ?? 'OFFRO';
  final body     = notif?.body  ?? msg.data['body']  ?? '';
  // Prefer data field image_url, fallback to FCM notification image
  final imageUrl = (msg.data['image_url'] ??
                    msg.data['image'] ??
                    notif?.android?.imageUrl ??
                    '').trim();

  debugPrint('[LOCAL-NOTIF] title=$title imageUrl=$imageUrl');

  if (imageUrl.isNotEmpty) {
    _showNotifWithImage(
        msg.hashCode, title, body, imageUrl, msg.data['screen'] ?? '');
  } else {
    _showNotifText(msg.hashCode, title, body, msg.data['screen'] ?? '');
  }
}

/// Show a plain text notification immediately.
void _showNotifText(int id, String title, String body, String payload) {
  final android = AndroidNotificationDetails(
    offroNotifChannel.id, offroNotifChannel.name,
    channelDescription: offroNotifChannel.description,
    importance: Importance.max,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    styleInformation: BigTextStyleInformation(body),
  );
  offroLocalNotif.show(
      id, title, body, NotificationDetails(android: android),
      payload: payload);
  debugPrint('[LOCAL-NOTIF] Text notif shown: $title');
}

/// Download image bytes then replace the text notification with a big-picture one.
Future<void> _showNotifWithImage(
    int id, String title, String body, String imageUrl, String payload) async {
  try {
    // Show text version immediately — don't make user wait for download
    _showNotifText(id, title, body, payload);

    final response =
        await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      final android = AndroidNotificationDetails(
        offroNotifChannel.id, offroNotifChannel.name,
        channelDescription: offroNotifChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        largeIcon: ByteArrayAndroidBitmap(bytes),
        styleInformation: BigPictureStyleInformation(
          ByteArrayAndroidBitmap(bytes),
          largeIcon: ByteArrayAndroidBitmap(bytes),
          contentTitle: title,
          summaryText: body,
          hideExpandedLargeIcon: false,
        ),
      );
      // Replace the text version with the image version (same notification id)
      await offroLocalNotif.show(
          id, title, body, NotificationDetails(android: android),
          payload: payload);
      debugPrint('[LOCAL-NOTIF] ✅ Image notif shown: $title');
    }
  } catch (e) {
    // Text version already showing — safe to silently ignore
    debugPrint('[LOCAL-NOTIF] Image load failed (text shown): $e');
  }
}

// ─────────────────────── FCM SERVICE ───────────────────────
class FcmService {
  static final _fcm = FirebaseMessaging.instance;
  static bool _initialized = false; // guard: only runs once per session
  static String? _savedPhone;

  /// Call once after user logs in — requests permission, subscribes to topics,
  /// gets the FCM device token and registers it with the backend.
  ///
  /// [onTokenReady] — callback that registers the token with your API.
  /// Pass `Api.registerFcmToken` here so FcmService doesn't import Api directly.
  ///
  /// Safe to call multiple times — only runs once per session unless force=true.
  static Future<void> init({
    required String city,
    required String? token,
    required String? userId,
    required String? phone,
    required Future<void> Function(String fcmToken,
            {required String phone, required String userId})
        onTokenReady,
    bool force = false,
  }) async {
    if (_initialized && !force) return;
    _initialized = true;
    _savedPhone = phone;

    try {
      // 1. Request notification permission (Android 13+ / iOS)
      final settings = await _fcm.requestPermission(
        alert: true, badge: true, sound: true,
        announcement: false, carPlay: false,
        criticalAlert: false, provisional: false,
      );
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Denied — skipping token registration');
        return;
      }

      // 2. Subscribe to global topics
      await _fcm.subscribeToTopic('all_users');
      await _fcm.subscribeToTopic('offers');
      debugPrint('[FCM] Subscribed to global topics');

      // 3. Subscribe to city topic
      if (city.isNotEmpty && city != 'Detecting...') {
        final cityTopic =
            city.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_') +
                '_users';
        await _fcm.subscribeToTopic(cityTopic);
        debugPrint('[FCM] City topic: $cityTopic');
      }

      // 4. Get FCM device token — retry up to 5x with 3-second delay
      String? fcmToken;
      for (int attempt = 1; attempt <= 5; attempt++) {
        try {
          fcmToken =
              await _fcm.getToken().timeout(const Duration(seconds: 10));
          if (fcmToken != null) break;
        } catch (e) {
          debugPrint('[FCM] getToken attempt $attempt: $e');
        }
        if (attempt < 5) await Future.delayed(const Duration(seconds: 3));
      }
      if (fcmToken == null) {
        debugPrint('[FCM] ⚠️ getToken() returned null after 5 attempts');
        return;
      }

      // Always print full token for logcat verification
      debugPrint('FCM TOKEN: $fcmToken');
      debugPrint('[FCM] Token (first 20): ${fcmToken.substring(0, 20)}...');

      // 5. Register token with backend via callback
      await onTokenReady(fcmToken,
          phone: phone ?? '', userId: userId ?? '');
      debugPrint('[FCM] ✅ Token registered (phone=${phone ?? "-"})');

      // 6. Listen for token refresh (device token can rotate)
      _fcm.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM TOKEN REFRESHED: $newToken');
        await onTokenReady(newToken,
            phone: _savedPhone ?? '', userId: '');
        debugPrint('[FCM] ✅ Refreshed token re-registered');
      });

      debugPrint('[FCM] ✅ FcmService.init complete');
    } catch (e) {
      // Non-fatal — app works without notifications
      debugPrint('[FCM] init error: $e');
    }
  }

  /// Re-subscribe to a new city when the user changes city manually.
  /// Pass both [newCity] and [oldCity] to cleanly swap topics.
  static Future<void> updateCityTopic(String newCity,
      {String? oldCity}) async {
    try {
      if (oldCity != null &&
          oldCity.isNotEmpty &&
          oldCity != 'Detecting...') {
        final old =
            '${oldCity.toLowerCase().replaceAll(' ', '_')}_users';
        await _fcm.unsubscribeFromTopic(old);
        debugPrint('[FCM] Unsubscribed: $old');
      }
      if (newCity.isNotEmpty && newCity != 'Detecting...') {
        final neo =
            '${newCity.toLowerCase().replaceAll(' ', '_')}_users';
        await _fcm.subscribeToTopic(neo);
        debugPrint('[FCM] Subscribed: $neo');
      }
    } catch (e) {
      debugPrint('[FCM] updateCityTopic: $e');
    }
  }

  /// Subscribe to a category deal topic (e.g. "food" → "food_category").
  static Future<void> subscribeCategory(String category) async {
    try {
      final topic =
          '${category.toLowerCase().replaceAll(' ', '_')}_category';
      await _fcm.subscribeToTopic(topic);
      debugPrint('[FCM] Category topic: $topic');
    } catch (e) {
      debugPrint('[FCM] subscribeCategory: $e');
    }
  }
}
