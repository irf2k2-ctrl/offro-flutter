// lib/core/constants/app_constants.dart
// OFFRO — Central constants (colors, URLs, keys)
// Import this in every screen/widget file.

import 'package:flutter/material.dart';

// ── Backend ──
const String kBaseUrl     = "https://offro-backend-production.up.railway.app";
const String kRazorpayKey = "rzp_live_SdiI6kcuZzZjsl";

// ── Brand colours ──
const Color kPrimary = Color(0xFF3E5F55);
const Color kLight   = Color(0xFFCDEBD6);
const Color kAccent  = Color(0xFFA9CDBA);
const Color kBeige   = Color(0xFFE7D7C8);
const Color kBg      = Color(0xFFFDFBF6);
const Color kText    = Color(0xFF2c3e35);
const Color kMuted   = Color(0xFF6b8c7e);
const Color kBorder  = Color(0xFFd4e8de);

// FIX: shared RouteObserver so screens (e.g. StoreDetailPage) can detect
// when the user navigates back to them (e.g. after rating a product) and
// refresh their data instead of showing stale info until a full re-open.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
