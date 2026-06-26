import 'dart:convert';
// lib/core/services/prefs_service.dart
// OFFRO — SharedPreferences wrapper

import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static const _kToken  = 'user_token';
  static const _kName   = 'user_name';
  static const _kPhone  = 'user_phone';
  static const _kRole   = 'user_role';
  static const _kCity   = 'user_city';
  static const _kUserId = 'user_id';
  static const _kLat    = 'last_lat';
  static const _kLng    = 'last_lng';

  // ─── Role Switching ───
  static const _kAppMode      = 'app_mode';         // 'user' | 'merchant'
  static const _kRememberMode = 'remember_mode';    // bool
  static const _kMerchantId   = 'merchant_id';      // merchant's _id
  static const _kRoles        = 'account_roles';    // comma-separated: 'user,merchant'

  // ─── Nearby Radius ───
  static const _kRadius = 'nearby_radius_km';

  // ─── Notification History ───
  static const _kNotifHistory = 'notif_history';
  static const _kMaxNotifs    = 50;

  // ─────────────────────────────────────────────
  // Auth / Profile
  // ─────────────────────────────────────────────

  static Future<void> save(
      String token, String name, String phone, String role,
      {String userId = ''}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    await p.setString(_kName,  name);
    await p.setString(_kPhone, phone);
    await p.setString(_kRole,  role);
    if (userId.isNotEmpty) await p.setString(_kUserId, userId);
  }

  static Future<Map<String, String?>> get() async {
    final p = await SharedPreferences.getInstance();
    return {
      'token':   p.getString(_kToken),
      'name':    p.getString(_kName),
      'phone':   p.getString(_kPhone),
      'role':    p.getString(_kRole),
      'city':    p.getString(_kCity),
      'user_id': p.getString(_kUserId),
    };
  }

  static Future<void> clear({bool keepMode = false}) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kName);
    await p.remove(_kPhone);
    await p.remove(_kRole);
    await p.remove(_kUserId);
    await p.remove(_kMerchantId);
    // Keep city + GPS so next launch is faster
    // Keep mode preference if requested (user explicitly logged out, not expired)
    if (!keepMode) {
      await p.remove(_kAppMode);
    }
  }

  // ─────────────────────────────────────────────
  // City
  // ─────────────────────────────────────────────

  static Future<void> saveCity(String city) async {
    if (city.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCity, city);
  }

  static Future<String> getCity() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kCity) ?? '';
  }

  // ─────────────────────────────────────────────
  // GPS Location
  // ─────────────────────────────────────────────

  /// Persist last known GPS so next restart skips live GPS detection
  static Future<void> saveLocation(double lat, double lng) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kLat, lat);
    await p.setDouble(_kLng, lng);
  }

  /// Returns {lat, lng} map or null if never saved
  static Future<Map<String, double>?> getSavedLocation() async {
    final p = await SharedPreferences.getInstance();
    final lat = p.getDouble(_kLat);
    final lng = p.getDouble(_kLng);
    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng};
  }

  // ─────────────────────────────────────────────
  // Nearby Radius Preference
  // ─────────────────────────────────────────────

  /// Save user's selected nearby radius in km (5, 10, or 0 = All).
  static Future<void> saveRadius(double km) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kRadius, km);
  }

  /// Returns saved radius. Defaults to 5.0 km.
  static Future<double> getRadius() async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(_kRadius) ?? 5.0;
  }

  // ─────────────────────────────────────────────
  // App Mode / Role Switching
  // ─────────────────────────────────────────────

  /// Save selected mode. mode = 'user' | 'merchant'
  static Future<void> saveMode(String mode) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAppMode, mode);
  }

  /// Get current mode. Defaults to 'user'.
  static Future<String> getMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kAppMode) ?? 'user';
  }

  /// Save whether user wants to remember their mode choice.
  static Future<void> saveRememberMode(bool val) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRememberMode, val);
  }

  /// Get remember-mode preference. Defaults to false.
  static Future<bool> getRememberMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kRememberMode) ?? false;
  }

  /// Save merchant ID for session restoration.
  static Future<void> saveMerchantId(String id) async {
    if (id.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMerchantId, id);
  }

  /// Get saved merchant ID.
  static Future<String> getMerchantId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kMerchantId) ?? '';
  }

  // ─────────────────────────────────────────────
  // Notification History
  // ─────────────────────────────────────────────

  /// Save an incoming notification to local history.
  /// Keeps newest 50; auto-purges entries older than 30 days.
  // Mutex flag to prevent concurrent writes corrupting the notification list
  static bool _savingNotif = false;

  static Future<void> saveNotification({
    required String title,
    required String body,
    String imageUrl = '',
    String type     = 'promo',
  }) async {
    // Wait if another save is in progress (max 2 seconds to avoid deadlock)
    int waited = 0;
    while (_savingNotif && waited < 2000) {
      await Future.delayed(const Duration(milliseconds: 50));
      waited += 50;
    }
    _savingNotif = true;
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(_kNotifHistory);
      final List<dynamic> list = raw != null
          ? (json.decode(raw) as List<dynamic>)
          : [];

      final now = DateTime.now();
      // Remove entries older than 30 days
      list.removeWhere((e) {
        try {
          final ts = DateTime.parse(e['ts'] as String);
          return now.difference(ts).inDays >= 30;
        } catch (_) { return false; }
      });

      // Prepend newest entry
      list.insert(0, {
        'title':     title,
        'body':      body,
        'image_url': imageUrl,
        'type':      type,
        'ts':        now.toIso8601String(),
      });

      // Trim to max 50
      if (list.length > _kMaxNotifs) list.removeRange(_kMaxNotifs, list.length);

      await p.setString(_kNotifHistory, json.encode(list));
    } catch (_) {
    } finally {
      _savingNotif = false; // Always release lock
    }
  }

  /// Returns notification history, newest first.
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(_kNotifHistory);
      if (raw == null) return [];
      return (json.decode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear all notification history.
  static Future<void> clearNotifications() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kNotifHistory);
  }

  // ─────────────────────────────────────────────
  // Unread Notification Badge
  // ─────────────────────────────────────────────
  static const _kUnreadCount = 'notif_unread_count';

  /// Increment unread count (call when new notification arrives)
  static Future<void> incrementUnread() async {
    final p = await SharedPreferences.getInstance();
    final current = p.getInt(_kUnreadCount) ?? 0;
    await p.setInt(_kUnreadCount, current + 1);
  }

  /// Get current unread count
  static Future<int> getUnreadCount() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kUnreadCount) ?? 0;
  }

  /// Mark all as read (call when NotificationsPage opens)
  static Future<void> clearUnread() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kUnreadCount, 0);
  }


  // ─────────────────────────────────────────────
  // Roles (unified account)
  // ─────────────────────────────────────────────

  static Future<void> saveRoles(List<String> roles) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRoles, roles.join(','));
  }

  static Future<List<String>> getRoles() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kRoles) ?? 'user';
    return raw.split(',').where((r) => r.isNotEmpty).toList();
  }

  static Future<bool> isMerchant() async {
    final roles = await getRoles();
    return roles.contains('merchant');
  }

  // ── Favorite Products ──
  static const _kFavProducts = 'fav_vouchers';

  static Future<List<String>> getFavoriteProducts() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_kFavProducts) ?? [];
  }

  static Future<void> toggleFavoriteProduct(String voucherId) async {
    final p   = await SharedPreferences.getInstance();
    final cur = p.getStringList(_kFavProducts) ?? [];
    if (cur.contains(voucherId)) {
      cur.remove(voucherId);
    } else {
      cur.add(voucherId);
    }
    await p.setStringList(_kFavProducts, cur);
  }

  static Future<bool> isFavoriteProduct(String voucherId) async {
    final favs = await getFavoriteProducts();
    return favs.contains(voucherId);
  }


}
