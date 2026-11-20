// lib/core/l10n/l10n.dart
//
// THE single access point for translated text (Phase I).
//   Text(context.l10n.loginGuest)
// Screens never import the generated class directly. A later phase can put remote (admin-published) overrides behind this one
// accessor without touching any screen again.
//
// Generated code lives in lib/l10n/gen (run `flutter gen-l10n`).
import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../l10n/gen/app_localizations_en.dart';
import '../utils/store_hours.dart';

export '../../l10n/gen/app_localizations.dart' show AppLocalizations;

extension OffroL10n on BuildContext {
  /// Falls back to the bundled English text when the widget is not under the app's localization delegates (a stand-alone
  /// MaterialApp such as a diagnostic screen, or a test), so a missing delegate can never crash a screen.
  AppLocalizations get l10n => Localizations.of<AppLocalizations>(this, AppLocalizations) ?? AppLocalizationsEn();
}

/// Keeps a phone number (or other always-left-to-right token) in order inside right-to-left text. In left-to-right layouts the value
/// is returned UNCHANGED, so English text is exactly as before. Use only for values passed as placeholder arguments.
String ltrIsolate(BuildContext context, String value) =>
    Directionality.of(context) == TextDirection.rtl ? '\u2066$value\u2069' : value;

/// Text of a bottom-navigation tab. The tab items keep their English label as a stable identity; the shown text comes from here.
/// An unknown label is returned unchanged, so a tab added later still renders.
String localizedNavLabel(BuildContext context, String label) {
  final l = context.l10n;
  switch (label) {
    case 'Home': return l.navHome;
    case 'Explore': return l.navExplore;
    case 'Deals': return l.navDeals;
    case 'Rewards': return l.navRewards;
    case 'Profile': return l.navProfile;
    case 'Invoices': return l.navInvoices;
    case 'Activity': return l.navActivity;
    case 'Opportunities': return l.navOpportunities;
    default: return label;
  }
}

/// A category name for display. Category names are admin data; the known ones are shown in the app language, any other name is
/// shown exactly as the admin entered it. (Logic always keeps using the original name.)
String localizedCategoryName(BuildContext context, String name) {
  final l = context.l10n;
  switch (name.trim().toLowerCase()) {
    case 'bakery': return l.catBakery;
    case 'automobile': return l.catAutomobile;
    case 'restaurant': return l.catRestaurant;
    case 'grocery': return l.catGrocery;
    default: return name;
  }
}

/// "Closes 9 PM" / "Opens 9 AM" in the app language (Western digits). English output equals StoreHoursStatus.subLabel.
String localizedStoreHoursSub(BuildContext context, StoreHoursStatus s) {
  if (s.subKind.isEmpty) return s.subLabel;
  final l = context.l10n;
  final h = s.subHour, m = s.subMinute;
  final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  final mStr = m > 0 ? ':${m.toString().padLeft(2, '0')}' : '';
  final time = '$h12$mStr ${h >= 12 ? l.timePm : l.timeAm}';
  return s.subKind == 'closes' ? l.storeClosesAt(time) : l.storeOpensAt(time);
}
