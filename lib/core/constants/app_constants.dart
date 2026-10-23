// lib/core/constants/app_constants.dart
// OFFRO — Central constants (colors, URLs, keys)
// Import this in every screen/widget file.

import 'package:flutter/material.dart';
import '../design/offro_tokens.dart' show OffroColors;

// ── Backend ──
// API_BASE_URL is supplied at build time via --dart-define, e.g.:
//   flutter build apk --dart-define=API_BASE_URL=https://offro-backend-production.up.railway.app   (production)
//   flutter build apk --dart-define=API_BASE_URL=https://offro-backend-staging-d375.up.railway.app  (staging)
// There is deliberately NO default/fallback value here. A build that omits
// this define resolves kBaseUrl to an empty string, which main() checks for
// at startup and refuses to run rather than silently defaulting to LIVE.
const String kBaseUrl     = String.fromEnvironment('API_BASE_URL');


// ── Brand colours ──
// Customer-facing legacy names now resolve to the central OffroColors palette
// (single colour system). Do NOT hard-code brand hex values elsewhere.
const Color kPrimary = OffroColors.primary;
const Color kLight   = OffroColors.mint;
const Color kAccent  = OffroColors.accent;
const Color kBeige   = OffroColors.beige;
const Color kBg      = OffroColors.background;
const Color kText    = OffroColors.text;
const Color kMuted   = OffroColors.textMuted;
const Color kBorder  = OffroColors.border;

// Merchant screens keep their original (pre-darker-palette) look until the
// Merchant redesign phase. These are frozen copies of the old legacy values.
const Color kMerchantPrimary = Color(0xFF3E5F55);
const Color kMerchantLight   = Color(0xFFCDEBD6);
const Color kMerchantAccent  = Color(0xFFA9CDBA);
const Color kMerchantBg      = Color(0xFFFDFBF6);
const Color kMerchantText    = Color(0xFF2c3e35);
const Color kMerchantMuted   = Color(0xFF6b8c7e);
const Color kMerchantBorder  = Color(0xFFd4e8de);

// FIX: shared RouteObserver so screens (e.g. StoreDetailPage) can detect
// when the user navigates back to them (e.g. after rating a product) and
// refresh their data instead of showing stale info until a full re-open.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
