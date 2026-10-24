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
const String kBaseUrl = String.fromEnvironment('API_BASE_URL');

// ── Brand colours ──
// Customer-facing legacy names now resolve to the central OffroColors palette
// (single colour system). Do NOT hard-code brand hex values elsewhere.
const Color kPrimary = OffroColors.primary;
const Color kLight = OffroColors.mint;
const Color kAccent = OffroColors.accent;
const Color kBeige = OffroColors.beige;
const Color kBg = OffroColors.background;
const Color kText = OffroColors.text;
const Color kMuted = OffroColors.textMuted;
const Color kBorder = OffroColors.border;

// Merchant screens use the same central OffrO palette as Customer (aliases
// kept so Merchant code reads the shared tokens instead of its own colours).
const Color kMerchantPrimary = OffroColors.primary;
const Color kMerchantLight = OffroColors.mint;
const Color kMerchantAccent = OffroColors.accent;
const Color kMerchantBg = OffroColors.background;
const Color kMerchantText = OffroColors.text;
const Color kMerchantMuted = OffroColors.textMuted;
const Color kMerchantBorder = OffroColors.border;

// FIX: shared RouteObserver so screens (e.g. StoreDetailPage) can detect
// when the user navigates back to them (e.g. after rating a product) and
// refresh their data instead of showing stale info until a full re-open.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
