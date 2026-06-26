// lib/core/services/api_service.dart
// OFFRO — All API calls (extracted from main.dart)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

class Api {
  static Map<String,String> _h(String? token) => {
    "Content-Type": "application/json",
    if (token != null) "Authorization": "Bearer $token",
  };

  static Future<Map<String,dynamic>> _post(String path, Map body, {String? token}) async {
    final r = await http.post(Uri.parse("$kBaseUrl$path"), headers: _h(token), body: json.encode(body)).timeout(const Duration(seconds: 20));
    final d = json.decode(r.body);
    if (r.statusCode >= 400) throw Exception(d["detail"] ?? "Error ${r.statusCode}");
    return d;
  }

  static Future<dynamic> _get(String path, {String? token}) async {
    // FIX 5: Increased timeout to 30s for Railway cold starts
    final r = await http.get(Uri.parse("$kBaseUrl$path"), headers: _h(token))
        .timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400) {
      final d = json.decode(r.body);
      throw Exception(d["detail"] ?? "HTTP ${r.statusCode}");
    }
    return json.decode(r.body);
  }

  /// Public GET wrapper — used by screens that need ad-hoc requests (e.g. _AllDealsScreen)
  static Future<dynamic> get(String path, {String? token}) => _get(path, token: token);

  // ── API Response Cache (30-second TTL) ──
  static final Map<String, dynamic> _apiCache = {};
  static final Map<String, DateTime> _apiCacheTime = {};
  static const _cacheTTL = const Duration(minutes: 3);

  static bool _isCacheValid(String key) {
    final t = _apiCacheTime[key];
    return t != null && DateTime.now().difference(t) < _cacheTTL;
  }

  static void clearCache() {
    _apiCache.clear();
    _apiCacheTime.clear();
  }

  /// Clear cache for a specific category so next fetch always hits the backend
  static void clearCategoryCache(String categoryName) {
    final catLower = categoryName.toLowerCase().trim();
    final keysToRemove = _apiCache.keys.where((k) => k.contains(':$catLower')).toList();
    for (final k in keysToRemove) {
      _apiCache.remove(k);
      _apiCacheTime.remove(k);
    }
    debugPrint("[OFFRO] clearCategoryCache: removed cache for '$categoryName'");
  }

  static Future<dynamic> _put(String path, Map body, {String? token}) async {
    final r = await http.put(Uri.parse("$kBaseUrl$path"), headers: _h(token), body: json.encode(body)).timeout(const Duration(seconds: 20));
    final d = json.decode(r.body);
    if (r.statusCode >= 400) throw Exception(d["detail"] ?? "Error");
    return d;
  }

  // ── User ──
  static Future<Map<String,dynamic>> loginUser(String phone) => _post("/user/account-login", {"phone": phone});

  /// Unified account login — checks users + merchants, returns one token + is_merchant flag
  static Future<Map<String,dynamic>> loginAccount(String phone) => _post("/user/account-login", {"phone": phone});
  static Future<Map<String,dynamic>> registerUser(String name, String phone) =>
      _post("/user/register", {"name": name, "phone": phone, "city": ""});
  /// Check if phone is already registered as a user
  static Future<bool> checkUserPhone(String phone) async {
    try {
      final d = await _post("/user/check-phone", {"phone": phone});
      return d["registered"] == true;
    } catch (_) { return false; }
  }

  /// Check phone in BOTH users + merchants collections.
  /// Returns {"registered": bool, "role": "user"|"merchant"|"both"|"none"}
  static Future<Map<String, dynamic>> checkPhoneFull(String phone) async {
    try {
      final d = await _post("/user/check-phone", {"phone": phone});
      return {
        "registered": d["registered"] == true,
        "role": d["role"]?.toString() ?? (d["registered"] == true ? "user" : "none"),
      };
    } catch (_) {
      return {"registered": false, "role": "none"};
    }
  }
  // ── MSG91 Widget OTP flow ──
  // OTP send + verify is handled entirely by sendotp_flutter_sdk (OTPWidget).
  // After OTPWidget.verifyOTP() succeeds on device, call loginUser(phone)
  // to get the OFFRO session token from our backend.
  // loginUser() below validates phone exists → issues token → sets cookie.


  static Future<void> updateCity(String token, String city) async {
    try { await _put("/user/city", {"city": city}, token: token); } catch (_) {}
  }
  static Future<Map<String,dynamic>> getWallet(String token) async {
    try { return Map<String,dynamic>.from(await _get("/user/wallet", token: token)); } catch (_) { return {}; }
  }
  static Future<Map<String,dynamic>> withdraw(String token, int amount) async =>
      Map<String,dynamic>.from(await _post("/user/wallet/withdraw", {"amount": amount}, token: token));
  static Future<List> getRedemptions(String token) async {
    try { return await _get("/user/redemptions", token: token); } catch (_) { return []; }
  }
  static Future<Map<String,dynamic>> redeemQR(String storeId, String token) async =>
      Map<String,dynamic>.from(await _post("/user/redeem", {"store_id": storeId, "user_token": token}));

  // ── Merchant ──
  static Future<Map<String,dynamic>?> getMerchantMe(String token) async {
    try {
      return await _get("/merchant/me", token: token);
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains("401") || msg.contains("403") || msg.contains("Unauthorized") || msg.contains("Forbidden")) {
        return null;
      }
      rethrow;
    }
  }
  static Future<Map<String,dynamic>> loginMerchant(String phone) => _post("/merchant/login", {"phone": phone});
  /// Unified login — same OTP flow, returns merchant token via /user/merchant-login
  static Future<Map<String,dynamic>> loginMerchantUnified(String phone) => _post("/merchant/login", {"phone": phone});
  static Future<Map<String,dynamic>> registerMerchant(String name, String phone, String city, String area) =>
      _post("/merchant/register", {"name": name, "phone": phone, "city": city, "area": area});
  static Future<List> getMerchantStores(String token) async {
    try { return await _get("/merchant/stores", token: token); } catch (_) { return []; }
  }
  static Future<Map<String,dynamic>?> getMerchantStoreDetail(String token, String storeId) async {
    try {
      final d = await _get("/merchant/stores/$storeId", token: token);
      return d is Map ? Map<String,dynamic>.from(d) : null;
    } catch (_) { return null; }
  }

  static Future<Map<String,dynamic>> resolveMapsLink(String url) async {
    try {
      final encoded = Uri.encodeQueryComponent(url);
      final r = await http.get(
        Uri.parse("$kBaseUrl/resolve-maps-link?url=$encoded"),
      ).timeout(const Duration(seconds: 15));
      final d = json.decode(r.body);
      if (d is Map) return Map<String,dynamic>.from(d);
      return {"error": "Unexpected response from server."};
    } catch (e) {
      return {"error": "Network error. Please check your connection and try again."};
    }
  }
  static Future<Map<String,dynamic>> createMerchantStore(String token, Map<String,dynamic> data) =>
      _post("/merchant/stores", data, token: token);
  static Future<Map<String,dynamic>> updateMerchantStore(String token, String sid, Map<String,dynamic> data) async {
    final r = await http.put(Uri.parse("$kBaseUrl/merchant/stores/$sid"), headers: _h(token), body: json.encode(data)).timeout(const Duration(seconds: 20));
    final d = json.decode(r.body);
    if (r.statusCode >= 400) throw Exception(d["detail"] ?? "Error");
    return d;
  }
  static Future<List> getPlans(String token) async {
    try { return await _get("/merchant/plans", token: token); } catch (_) { return []; }
  }
  static Future<Map<String,dynamic>> initiateSubscription(String token, Map body) =>
      _post("/merchant/subscribe", body, token: token);
  static Future<Map<String,dynamic>> verifyPayment(String token, Map body) =>
      _post("/merchant/subscribe/verify", body, token: token);
  static Future<Map<String,dynamic>> activateFreeSubscription(String token, Map body) =>
      _post("/merchant/subscribe/free", body, token: token);
  static Future<List> getInvoices(String token) async {
    try { return await _get("/merchant/invoices/full", token: token); } catch (_) { return []; }
  }
  static Future<List> getMerchantTransactions(String token) async {
    try { return await _get("/merchant/transactions", token: token); } catch (_) { return []; }
  }
  static Future<String> getMerchantTerms() async {
    try { final d = await _get("/merchant/terms"); return d["content"] ?? ""; } catch (_) { return ""; }
  }
  static Future<List> getMerchantDeals(String token) async {
    try { return await _get("/merchant/deals", token: token); } catch (_) { return []; }
  }
  static Future<Map<String,dynamic>> addDeal(String token, Map<String,dynamic> data) =>
      _post("/merchant/deals", data, token: token);
  static Future<void> deleteDeal(String token, String dealId) async {
    try {
      final r = await http.delete(Uri.parse("$kBaseUrl/merchant/deals/$dealId"), headers: _h(token)).timeout(const Duration(seconds: 20));
      if (r.statusCode >= 400) { final d = jsonDecode(r.body); throw Exception(d["detail"] ?? "Error"); }
    } catch (_) {}
  }

  // ── Public ──
  static Future<Map<String,dynamic>> fetchStoreDetail(String storeId) async =>
      Map<String,dynamic>.from(await _get("/stores/$storeId"));

  static Future<List> fetchStores({String? city, String? category, int limit=100, int skip=0}) async {
    final p = <String>[];
    p.add("limit=$limit");
    p.add("skip=$skip");
    // FIX 1: Always send city to backend for DB-level filtering
    final String? cleanCity = (city != null && city.trim().isNotEmpty && city != "Detecting...") ? city.trim() : null;
    if (cleanCity != null) p.add("city=${Uri.encodeComponent(cleanCity)}");
    if (category != null && category != "All") p.add("category=${Uri.encodeComponent(category)}");
    final url = "/stores?" + p.join("&");
    // FIX: category must be in cache key — without it all categories return the same cached list
    final String _catSfx = (category != null && category != 'All' && category!.isNotEmpty)
        ? ':${category!.toLowerCase()}' : '';
    final cacheKey = "stores:\${cleanCity?.toLowerCase() ?? 'all'}\$_catSfx";
    debugPrint("[OFFRO] fetchStores URL: $kBaseUrl$url");
    debugPrint("[OFFRO] city param: $cleanCity | cacheKey: $cacheKey");
    if (_isCacheValid(cacheKey)) {
      final cached = List.from(_apiCache[cacheKey]);
      debugPrint("[OFFRO] fetchStores: returning ${cached.length} stores from cache");
      return cached;
    }
    // FIX 2: Do NOT catch here — throw errors so _loadAll can set correct error state
    final raw = await _get(url);
    final List result;
    if (raw is List) {
      result = raw;
    } else if (raw is Map && raw.containsKey('stores')) {
      result = raw['stores'] as List;
    } else {
      result = [];
    }
    debugPrint("[OFFRO] fetchStores: got ${result.length} stores from API");
    // FIX 3: NEVER cache empty results — empty may be a transient failure
    if (result.isNotEmpty) {
      _apiCache[cacheKey] = result;
      _apiCacheTime[cacheKey] = DateTime.now();
    }
    return result;
  }
  static Future<List<dynamic>> fetchCategories() async {
    const cacheKey = "categories";
    if (_isCacheValid(cacheKey)) return List<dynamic>.from(_apiCache[cacheKey]);
    try {
      final raw = await _get("/categories");
      final result = (raw as List).map((e) {
        if (e is Map) return Map<String,dynamic>.from(e);
        // old flat-string fallback
        return <String,dynamic>{"name":e.toString(),"icon":"🏪","image_url":"","subtitle":""};
      }).toList();
      _apiCache[cacheKey] = result;
      _apiCacheTime[cacheKey] = DateTime.now();
      return result;
    } catch (_) {
      return [
        {"name":"Grocery","icon":"🛒","image_url":"","subtitle":"Fresh & daily"},
        {"name":"Restaurant","icon":"🍽️","image_url":"","subtitle":"500+ places"},
        {"name":"Pharmacy","icon":"💊","image_url":"","subtitle":"Health essentials"},
        {"name":"Electronics","icon":"📱","image_url":"","subtitle":"Trending gadgets"},
        {"name":"Fashion","icon":"👗","image_url":"","subtitle":"New arrivals"},
        {"name":"Bakery","icon":"🎂","image_url":"","subtitle":"Fresh baked daily"},
        {"name":"Salon","icon":"💇","image_url":"","subtitle":"Look your best"},
      ];
    }
  }

  /// Fetch predefined areas for a given city from /areas
  static Future<List<String>> fetchAreas(String city) async {
    if (city.trim().isEmpty) return [];
    try {
      final raw = await _get("/areas?city=${Uri.encodeComponent(city.trim())}");
      final areas = (raw["areas"] as List? ?? []).map((e) => e.toString()).toList();
      return areas;
    } catch (e) {
      debugPrint("[OFFRO] fetchAreas error: $e");
      return [];
    }
  }
  static Future<String> fetchTerms(String type) async {
    try { final d = await _get("/terms/$type"); return d["content"] ?? ""; } catch (_) { return ""; }
  }
  static Future<String> fetchPolicy(String type) async {
    try { final d = await _get("/policy/$type"); return d["content"] ?? ""; } catch (_) { return ""; }
  }
  static Future<Map<String,dynamic>> getSocialLinks() async {
    try { return Map<String,dynamic>.from(await _get("/social")); } catch(_){ return {}; }
  }
  static Future<Map<String,dynamic>?> getMe(String token) async {
    try {
      return Map<String,dynamic>.from(await _get("/user/me", token: token));
    } on Exception catch (e) {
      // Only return null for auth errors (401/403) — rethrow network/timeout errors
      final msg = e.toString();
      if (msg.contains("401") || msg.contains("403") || msg.contains("Unauthorized") || msg.contains("Forbidden")) {
        return null; // Token invalid → splash will clear + go to login
      }
      rethrow; // Network error → splash catches and uses saved session
    }
  }

  static Future<Map<String,dynamic>> updateUserProfile(String token, Map<String,dynamic> data) async {
    try { return Map<String,dynamic>.from(await _put("/user/profile", data, token: token)); } catch(e) { throw Exception(e.toString().replaceAll("Exception: ","")); }
  }
  static Future<Map<String,dynamic>> updateMerchantProfile(String token, Map<String,dynamic> data) async {
    try { return Map<String,dynamic>.from(await _put("/merchant/profile", data, token: token)); } catch(e) { throw Exception(e.toString().replaceAll("Exception: ","")); }
  }
  static Future<String> getAboutUs() async {
    try { final d = await _get("/about"); return d["content"] ?? ""; } catch (_) { return ""; }
  }
  // ── Gift Vouchers ──
  static Future<List> getGiftVouchers() async {
    try {
      final raw = await _get("/gift-vouchers-public");
      // FIX 4: backend may return {"vouchers": [...]} or directly a list
      if (raw is List) return raw;
      if (raw is Map) {
        if (raw["vouchers"] is List) return raw["vouchers"] as List;
        if (raw["data"] is List) return raw["data"] as List;
        if (raw["results"] is List) return raw["results"] as List;
      }
      return [];
    } catch(_) { return []; }
  }
  static Future<List> getSliders() async {
    try { return await _get("/promo-sliders"); } catch(_) { return []; }
  }

  static Future<List> getCities() async {
    try { return await _get("/cities"); } catch(_) { return []; }
  }

  /// Fetch default fallback images — tries /admin/default-images then /default-images
  /// Returns a map with keys: city_image_url, store_image_url, product_image_url, etc.
  static Future<Map<String,dynamic>> getDefaultImages() async {
    for (final path in ["/default-images", "/admin/default-images", "/admin/defaults"]) {
      try {
        final raw = await _get(path).timeout(const Duration(seconds: 8));
        if (raw is Map && raw.isNotEmpty) {
          debugPrint("[OFFRO] getDefaultImages from $path: ${raw.keys.toList()}");
          return Map<String,dynamic>.from(raw);
        }
      } catch (_) { continue; }
    }
    debugPrint("[OFFRO] getDefaultImages: all endpoints failed");
    return {};
  }

  static Future<Map<String,dynamic>> validateDiscount(String code) =>
      _post("/discount/validate", {"code": code});

  // Merchant-authenticated discount code validation (Item 6)
  static Future<Map<String,dynamic>> validateDiscountCode(String token, String code) =>
      _post("/merchant/discounts/validate", {"code": code}, token: token);

  // Check merchant phone registered before sending OTP (Item 8)
  static Future<bool> checkMerchantPhone(String phone) async {
    try {
      final d = await _post("/merchant/check-phone", {"phone": phone});
      return d["ok"] == true;
    } catch (_) { return false; }
  }

  // ── Ratings ──
  static Future<Map<String,dynamic>> rateStore(String token, String storeId, double rating) =>
      _post("/stores/$storeId/rate", {"rating": rating}, token: token);
  static Future<Map<String,dynamic>?> getUserRating(String token, String storeId) async {
    try { return Map<String,dynamic>.from(await _get("/stores/$storeId/my-rating", token: token)); } catch(_) { return null; }
  }

  // FIX 7: FCM token registration — call after login to enable push notifications
  static Future<void> registerFcmToken(String fcmToken, {String phone="", String userId=""}) async {
    try {
      final resp = await http.post(
        Uri.parse("$kBaseUrl/register-fcm-token"),
        headers:{"Content-Type":"application/json"},
        body:json.encode({"token":fcmToken,"phone":phone,"user_id":userId}),
      ).timeout(const Duration(seconds: 10));
      debugPrint('[FCM] registerFcmToken → ${resp.statusCode}: ${resp.body}');
      if (resp.statusCode == 200) {
        debugPrint('[FCM] ✅ Token saved in DB for phone=$phone userId=$userId');
      } else {
        debugPrint('[FCM] ⚠️ Token registration failed: ${resp.statusCode} ${resp.body}');
      }
    } catch(e) {
      debugPrint('[FCM] ⚠️ registerFcmToken error: $e');
    }  // silent fail — never block login flow
  }


  // ── Reviews ──
  static Future<Map<String,dynamic>> submitReview(
      String token, String storeId, double rating, String text, {String userName = ""}) async {
    try {
      return Map<String,dynamic>.from(await _post(
        "/stores/\$storeId/review",
        {"rating": rating, "text": text, "user_name": userName},
        token: token,
      ));
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  static Future<Map<String,dynamic>> getReviews(String storeId, {int limit = 10, int skip = 0}) async {
    try {
      final d = await _get("/stores/\$storeId/reviews?limit=\$limit&skip=\$skip");
      return d is Map ? Map<String,dynamic>.from(d) : {"reviews": [], "total": 0};
    } catch (_) {
      return {"reviews": [], "total": 0};
    }
  }

  // ── Favorites ──
  static Future<void> toggleFavorite(String token, String storeId) async {
    try { await _post("/user/favorites/$storeId", {}, token: token); } catch(_) {}
  }
  static Future<List> getFavorites(String token) async {
    try { return await _get("/user/favorites", token: token); } catch(_) { return []; }
  }
  static Future<bool> isFavorite(String token, String storeId) async {
    try { final d = await _get("/user/favorites/$storeId/check", token: token); return d["is_favorite"]==true; } catch(_) { return false; }
  }
  /// Regenerate QR code for a store
  static Future<Map<String,dynamic>> resetStoreQr(String storeId, String token) async {
    return await _post("/merchant/stores/$storeId/reset-qr", {}, token: token);
  }


  // ══════════════════════════════════════════════
  // MERCHANT BANNERS
  // ══════════════════════════════════════════════

  static Future<List> getMerchantBanners(String token) async {
    try {
      final r = await _get("/merchant/banners", token: token);
      return r is List ? r : [];
    } catch(_) { return []; }
  }

  static Future<Map<String,dynamic>> getBannerPricing(String token) async =>
    Map<String,dynamic>.from(await _get("/merchant/banners/pricing", token: token));

  static Future<Map<String,dynamic>> createBannerOrder(String token, Map body) =>
    _post("/merchant/banners/order", body, token: token);

  static Future<Map<String,dynamic>> verifyBannerPayment(String token, Map body) =>
    _post("/merchant/banners/verify", body, token: token);

  static Future<Map<String,dynamic>> activateFreeBanner(String token, Map body) =>
    _post("/merchant/banners/activate-free", body, token: token);

  // ══════════════════════════════════════════════
  // MERCHANT VOUCHERS
  // ══════════════════════════════════════════════

  static Future<List> getMerchantVouchers(String token) async {
    try {
      final r = await _get("/merchant/vouchers", token: token);
      return r is List ? r : [];
    } catch(_) { return []; }
  }

  static Future<Map<String,dynamic>> getVoucherPricing(String token) async =>
    Map<String,dynamic>.from(await _get("/merchant/vouchers/pricing", token: token));

  static Future<Map<String,dynamic>> createVoucherOrder(String token, Map body) =>
    _post("/merchant/vouchers/order", body, token: token);

  static Future<Map<String,dynamic>> verifyVoucherPayment(String token, Map body) =>
    _post("/merchant/vouchers/verify", body, token: token);

  static Future<Map<String,dynamic>> activateFreeVoucher(String token, Map body) =>
    _post("/merchant/vouchers/activate-free", body, token: token);

  // ══════════════════════════════════════════════
  // FULL INVOICES (banner + voucher + store)
  // ══════════════════════════════════════════════

  static Future<List> getFullInvoices(String token) async {
    try {
      final r = await _get("/merchant/invoices/full", token: token);
      return r is List ? r : [];
    } catch(_) { return []; }
  }

  // ── Public Products / Product Cards ──
  static Future<List> getPublicProducts({String? city}) async {
    try {
      final cityParam = (city != null && city.trim().isNotEmpty && city != "Detecting...")
          ? "?city=${Uri.encodeComponent(city.trim())}" : "";
      final raw = await _get("/gift-vouchers$cityParam");
      if (raw is List) return raw;
      if (raw is Map) {
        if (raw["vouchers"] is List) return raw["vouchers"] as List;
        if (raw["data"]    is List) return raw["data"]    as List;
      }
      return [];
    } catch(_) { return []; }
  }

  static Future<List> fetchPublicProducts({String? city}) => getPublicProducts(city: city);

  static Future<List> getProductCards({String? city}) => getPublicProducts(city: city);

  // ── Admin / Promo Banners (public) ──
  static Future<List> getAdminBanners() async {
    try {
      final raw = await _get("/promo-sliders");
      return raw is List ? raw : [];
    } catch(_) { return []; }
  }

  // ── Product Favorites ──
  static Future<void> toggleProductFavorite(String token, String productId) async {
    try { await _post("/user/product-favorites/$productId", {}, token: token); } catch(_) {}
  }

  static Future<bool> isProductFavorite(String token, String productId) async {
    try {
      final d = await _get("/user/product-favorites/$productId/check", token: token);
      return d["is_favorite"] == true;
    } catch(_) { return false; }
  }

  // ── Product Reviews ──
  static Future<void> submitProductReview(
      String token, String productId, double rating, String text) async {
    try {
      await _post("/products/$productId/review",
          {"rating": rating, "text": text}, token: token);
    } catch(e) { throw Exception(e.toString().replaceAll("Exception: ", "")); }
  }

  // ── User's own review for a store ──
  static Future<Map<String,dynamic>> getUserReview(String token, String storeId) async {
    try {
      final d = await _get("/stores/$storeId/my-review", token: token);
      return d is Map ? Map<String,dynamic>.from(d) : {};
    } catch(_) { return {}; }
  }

}

// ─────────────────────── PREFS ───────────────────────
