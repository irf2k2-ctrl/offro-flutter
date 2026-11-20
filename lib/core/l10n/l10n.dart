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
import '../phone/phone_country.dart';
import '../phone/phone_input.dart';
import 'locale_controller.dart';

export '../../l10n/gen/app_localizations.dart' show AppLocalizations;

extension OffroL10n on BuildContext {
  /// Falls back to the bundled English text when the widget is not under the app's localization delegates (a stand-alone
  /// MaterialApp such as a diagnostic screen, or a test), so a missing delegate can never crash a screen.
  AppLocalizations get l10n => Localizations.of<AppLocalizations>(this, AppLocalizations) ?? AppLocalizationsEn();
}

/// Text for code that has no BuildContext (a top-level helper, a static method). It follows the app language chosen in
/// [LocaleController]; with English selected the text is exactly the English text. Prefer `context.l10n` wherever a context exists.
AppLocalizations get offroNoContext => lookupAppLocalizations(LocaleController.instance.locale);

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
    case 'pharmacy': return l.catPharmacy;
    case 'fashion': return l.catFashion;
    case 'beauty': return l.catBeauty;
    case 'electronics': return l.catElectronics;
    case 'education': return l.catEducation;
    case 'hospital': return l.catHospital;
    case 'cafe': return l.catCafe;
    case 'fitness': return l.catFitness;
    case 'jewelry': return l.catJewelry;
    default: return name;
  }
}

/// A category card's small subtitle. Only the built-in fallback subtitles are translated; a subtitle from the server is shown as it is.
String localizedCategorySubtitle(BuildContext context, String sub) {
  final l = context.l10n;
  switch (sub) {
    case '500+ places': return l.catSubRestaurant;
    case 'Health essentials': return l.catSubPharmacy;
    case 'New arrivals': return l.catSubFashion;
    case 'Skincare & more': return l.catSubBeauty;
    case 'Trending gadgets': return l.catSubElectronics;
    case 'Learn & grow': return l.catSubEducation;
    case 'Healthcare near you': return l.catSubHospital;
    case 'Coffee & more': return l.catSubCafe;
    case 'Fresh & daily': return l.catSubGrocery;
    case 'Stay strong': return l.catSubFitness;
    case 'Precious finds': return l.catSubJewelry;
    case 'Fresh baked daily': return l.catSubBakery;
    default: return sub;
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

/// A filter chip's text. The chips keep their English value as the stable key (used for filtering); only the shown text changes.
/// Known words are translated, category names go through [localizedCategoryName], anything else is shown as it is.
String localizedFilterLabel(BuildContext context, String label) {
  switch (label) {
    case 'All': return context.l10n.commonAll;
    case 'Ending soon': return context.l10n.dealsEndingSoon;
    default: return localizedCategoryName(context, label);
  }
}

/// The 12 short month names (Jan..Dec) in the app language. Used with Western digits for dates such as "5 Mar 2026".
List<String> localizedMonthsShort(BuildContext context) => monthsShortOf(context.l10n);

/// Same as [localizedMonthsShort] for code that already holds an [AppLocalizations] (or uses [offroNoContext]).
List<String> monthsShortOf(AppLocalizations l) {
  return [l.monthJan, l.monthFeb, l.monthMar, l.monthApr, l.monthMay, l.monthJun, l.monthJul, l.monthAug, l.monthSep, l.monthOct, l.monthNov, l.monthDec];
}

/// A discount label such as "20% OFF". Only the generated "<n>% OFF" form is translated; any other text (written by a merchant) is
/// shown as it is.
String localizedDiscountLabel(BuildContext context, String label) {
  final m = RegExp(r'^(\d+)% OFF$').firstMatch(label);
  return m == null ? label : context.l10n.storeDiscOff(m.group(1)!);
}

/// Badge text on a store list card. Only the three built-in English words are translated; text written by an admin is shown as it is.
String localizedTopCardBadge(BuildContext context, String label) {
  final l = context.l10n;
  switch (label) {
    case 'New Store': return l.storeNewStoreTitle;
    case 'Trending': return l.storeChipTrending;
    case 'Popular': return l.storeChipPopular;
    default: return label;
  }
}

/// Shown text of a delete-account reason. The English text is what is sent to the server, so only the display is translated.
String localizedDeleteReason(BuildContext context, String reason) {
  final l = context.l10n;
  switch (reason) {
    case 'I no longer use the app': return l.delReasonUnused;
    case 'I have privacy concerns': return l.delReasonPrivacy;
    case 'I have a duplicate account': return l.delReasonDuplicate;
    case 'Too many notifications or irrelevant content': return l.delReasonNoisy;
    case 'Other': return l.delReasonOther;
    case 'I no longer run my business': return l.bizINoLongerRunMy;
    case 'The app is not working properly for me': return l.bizTheAppIsNotWorking;
    default: return reason;
  }
}

/// Text of one step on the location loading screen (index 0..3).
String localizedLoadingStep(BuildContext context, int index) {
  final l = context.l10n;
  switch (index) {
    case 0: return l.loadStep1;
    case 1: return l.loadStep2;
    case 2: return l.loadStep3;
    default: return l.loadStep4;
  }
}

/// Text of the glass ribbon on a store card ("🔥 TRENDING"). [key] is the admin badge key; [fallback] is the English text used for a key
/// this function does not know.
String localizedBadgeRibbon(BuildContext context, String key, String fallback) {
  final l = context.l10n;
  switch (key) {
    case 'new_store': return '🆕 ${l.badgeNewStore}';
    case 'just_opened': return '🎉 ${l.badgeJustOpened}';
    case 'newly_added': return '✨ ${l.badgeNewlyAdded}';
    case 'newly_opened': case 'newly_open': case 'new_open': case 'opened': return '🎉 ${l.badgeNewlyOpened}';
    case 'trending': return '🔥 ${l.badgeTrending}';
    case 'popular': return '⭐ ${l.badgePopular}';
    case 'top_rated': return '🏆 ${l.badgeTopRated}';
    case 'must_visit': return '📍 ${l.badgeMustVisit}';
    case 'limited_offer': return '⏳ ${l.badgeLimitedOffer}';
    default: return fallback;
  }
}

/// A supported country's name in the app language (the country list itself keeps the English name for logic and the server).
String localizedCountryName(BuildContext context, PhoneCountry country) {
  final l = context.l10n;
  switch (country.iso) {
    case 'IN': return l.countryNameIN;
    case 'JO': return l.countryNameJO;
    case 'NP': return l.countryNameNP;
    case 'PH': return l.countryNamePH;
    case 'SA': return l.countryNameSA;
    default: return country.name;
  }
}

/// The message to show for a phone number that failed [checkPhoneInput]. The English message inside the result is unchanged; this only
/// chooses the text in the app language (same three cases as the rules in phone_input.dart).
String localizedPhoneInputError(BuildContext context, PhoneCountry country, PhoneInputResult result) {
  if (result.ok) return result.message;
  final l = context.l10n;
  if (result.error == PhoneInputError.empty) return l.phoneEnterNumber;
  if (country.iso == 'IN') return l.phoneInvalid10;
  return l.phoneInvalidCountry(localizedCountryName(context, country));
}
