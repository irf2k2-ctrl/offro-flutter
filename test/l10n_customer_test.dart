// Phase J, batch 2: Customer screens in English and Arabic.
// Needs the generated localizations (lib/l10n/gen): run `flutter gen-l10n` first.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/l10n/l10n.dart';
import 'package:offro_user/core/services/error_mapper.dart';
import 'package:offro_user/l10n/gen/app_localizations_ar.dart';
import 'package:offro_user/l10n/gen/app_localizations_en.dart';
import 'package:offro_user/screens/home/support_info_note.dart';
import 'package:offro_user/screens/store/widgets/store_highlights.dart';

Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

Future<T> run<T>(WidgetTester t, Locale l, T Function(BuildContext) f) async {
  late T out;
  await t.pumpWidget(app(Builder(builder: (c) { out = f(c); return const SizedBox(); }), locale: l));
  return out;
}

void main() {
  const ar = Locale('ar');
  const enL = Locale('en');
  final en = AppLocalizationsEn();
  final arL = AppLocalizationsAr();

  group('ARB files', () {
    final enArb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final arArb = jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync()) as Map<String, dynamic>;
    Iterable<String> keys(Map<String, dynamic> m) => m.keys.where((k) => !k.startsWith('@') && k != '@@locale');
    Set<String> ph(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

    test('English and Arabic have exactly the same keys', () {
      expect(keys(arArb).toSet(), keys(enArb).toSet());
    });

    test('every key has the same placeholders in both languages', () {
      final bad = <String>[];
      for (final k in keys(enArb)) {
        if (ph(enArb[k] as String).difference(ph(arArb[k] as String)).isNotEmpty ||
            ph(arArb[k] as String).difference(ph(enArb[k] as String)).isNotEmpty) {
          bad.add(k);
        }
      }
      expect(bad, isEmpty);
    });

    test('every English key has a description (translator note)', () {
      final missing = [for (final k in keys(enArb)) if (enArb['@$k'] == null) k];
      expect(missing, isEmpty);
    });

    test('Arabic text uses Western digits only (no Arabic-Indic digits)', () {
      final bad = [for (final k in keys(arArb)) if (RegExp('[٠-٩۰-۹]').hasMatch(arArb[k] as String)) k];
      expect(bad, isEmpty);
    });

    test('every Arabic value is translated (contains Arabic letters) except the language name English (shown in Latin on purpose)', () {
      const allowed = <String>{'languageNameEn'};
      final bad = <String>[];
      for (final k in keys(arArb)) {
        final v = arArb[k] as String;
        if (!RegExp('[؀-ۿ]').hasMatch(v) && !allowed.contains(k)) bad.add(k);
      }
      expect(bad, isEmpty, reason: 'Arabic value has no Arabic text: $bad');
    });
  });

  group('English is exactly what the customer screens showed before', () {
    test('favourites, QR, explore', () {
      expect(en.favEyebrow, 'Saved for later');
      expect(en.favPlacesOne, '1 place you love, all in one spot.');
      expect(en.favPlacesMany('4'), '4 places you love, all in one spot.');
      expect(en.favEmptyTitle, 'No favourites yet');
      expect(en.favEmptyBody, 'Tap the heart on any store to save it here');
      expect(en.qrTitle, 'Scan Store QR');
      expect(en.qrInvalid, '❌ Invalid QR');
      expect(en.qrPointsAdded, 'Points Added!');
      expect(en.qrRefreshedNote, '🔐 Store QR has been refreshed for security.');
      expect(en.exploreDiscover('Pune'), 'Discover Pune');
      expect(en.exploreNeighbourhoodsIn('Pune'), 'Neighbourhoods in Pune');
      expect(en.explorePlacesOne, '1 place nearby');
      expect(en.explorePlacesMany('7'), '7 places nearby');
      expect(en.exploreStoresInArea('Baner'), 'Stores in Baner');
      expect(en.exploreOffer('10% off'), 'Offer · 10% off');
      expect(en.exploreStoreMany('3'), '3 stores');
    });

    test('wallet and scan history', () {
      expect(en.walletBadge, 'REWARD POINTS');
      expect(en.walletBalance, 'Available balance');
      expect(en.walletVoucherRate('200', '₹20'), '200 pts = ₹20 voucher');
      expect(en.walletVoucherRate('100', 'SAR 5'), '100 pts = SAR 5 voucher');
      expect(en.walletToGo('50'), '50 pts to go');
      expect(en.walletEarnMore('50'), 'Earn 50 more points');
      expect(en.walletHowLine1('200', '₹20'), 'Redeem 200 Reward Points for a ₹20 Promotional Gift Voucher.');
      expect(en.walletVoucherDesc, 'Promotional Gift Voucher');
      expect(en.walletVoucherDescPartners('Amazon, Flipkart'), 'Promotional Gift Voucher · Amazon, Flipkart');
      expect(en.walletEarnedOn('5 Mar 2026'), 'Earned · 5 Mar 2026');
      expect(en.scanHistoryTitle, 'Scan History');
      expect(en.scanHistoryEmpty, 'No scans yet');
      expect(en.walletPtsPlus('10'), '+10 pts');
    });

    test('store page, offers, reviews, products', () {
      expect(en.storeScanEarn('10'), 'Scan & Earn 10 pts');
      expect(en.storeCostForTwo('500'), '₹500 for two');
      expect(en.storeExclusiveOne, 'Exclusive on OffrO · 1 deal');
      expect(en.storeExclusiveMany('3'), 'Exclusive on OffrO · 3 deals');
      expect(en.storeDiscOff('20'), '20% OFF');
      expect(en.storeOfferPct('20'), 'Offer · 20% off');
      expect(en.revCountOne, '(1 review)');
      expect(en.revCountMany('5'), '(5 reviews)');
      expect(en.revSelectStar, 'Please select a star rating');
      expect(en.prodRatingSubmitFailed('x'), "Couldn't submit rating: x");
      expect(en.prodValidTill('5 Mar 2026'), 'Valid till 5 Mar 2026');
      expect(en.storeDistAwayM('300'), '300m away');
      expect(en.storeDistAwayKm('1.5'), '1.5km away');
      expect(en.storeDistAwaySpM('300'), '300 m away');
    });

    test('location, legal, loading', () {
      expect(en.locCityUnsupportedBody('Pune'), "OffrO isn't available in Pune yet. Please choose another city from the list.");
      expect(en.locPermissionDenied, "Location permission wasn't allowed. Tap the card to try again, or choose a city below.");
      expect(en.legalReadMore, 'Read More');
      expect(en.delReasonUnused, 'I no longer use the app');
      expect(en.delSubmitFailed('x'), 'Failed to submit: x');
      expect(en.loadStep4, "Loading today's offers...");
    });
  });

  group('Arabic text', () {
    test('placeholders are filled and digits stay Western', () {
      expect(arL.walletVoucherRate('200', '₹20'), '200 نقطة = قسيمة ₹20');
      expect(arL.walletVoucherRate('100', '5 ر.س'), '100 نقطة = قسيمة 5 ر.س');
      expect(arL.walletToGo('50'), 'متبقٍ 50 نقطة');
      expect(arL.storeScanEarn('10'), 'امسح واكسب 10 نقطة');
      expect(arL.storeDiscOff('20'), 'خصم 20%');
      expect(arL.revCountMany('5'), '(5 مراجعات)');
      expect(arL.explorePlacesMany('7'), '7 أماكن قريبة');
      expect(arL.exploreDiscover('Pune'), 'اكتشف Pune');
      expect(arL.locCityUnsupportedBody('Pune'), contains('Pune'));
      expect(arL.walletPtsPlus('10'), '+10 نقطة');
      expect(arL.favPlacesOne, isNot(en.favPlacesOne));
      expect(arL.unitKm, 'كم');
    });

    test('brand name stays in Latin letters and the rupee sign is kept', () {
      expect(arL.locCityUnsupportedBody('X'), contains('OffrO'));
      expect(arL.walletHowLine1('200', '₹20'), contains('₹20'));
      expect(arL.walletHowLine1('100', '5 ر.س'), allOf(contains('5 ر.س'), isNot(contains('₹'))));
      expect(arL.storeCostForTwo('500'), contains('₹500'));
    });
  });

  group('helpers', () {
    testWidgets('filter chips: identity stays English, display is translated', (t) async {
      expect(await run(t, enL, (c) => localizedFilterLabel(c, 'All')), 'All');
      expect(await run(t, ar, (c) => localizedFilterLabel(c, 'All')), 'الكل');
      expect(await run(t, ar, (c) => localizedFilterLabel(c, 'Ending soon')), arL.dealsEndingSoon);
      expect(await run(t, ar, (c) => localizedFilterLabel(c, 'Bakery')), 'المخابز');
      expect(await run(t, ar, (c) => localizedFilterLabel(c, 'Pet Care')), 'Pet Care');
    });

    testWidgets('month names: English is Jan..Dec, Arabic has 12 distinct names', (t) async {
      expect(await run(t, enL, (c) => localizedMonthsShort(c)),
          ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']);
      final m = await run(t, ar, (c) => localizedMonthsShort(c));
      expect(m.length, 12);
      expect(m.toSet().length, 12);
      expect(m.any((s) => s == 'Jan'), isFalse);
    });

    testWidgets('discount label: only the generated "<n>% OFF" text is translated', (t) async {
      expect(await run(t, enL, (c) => localizedDiscountLabel(c, '20% OFF')), '20% OFF');
      expect(await run(t, ar, (c) => localizedDiscountLabel(c, '20% OFF')), 'خصم 20%');
      expect(await run(t, ar, (c) => localizedDiscountLabel(c, 'Buy 1 Get 1')), 'Buy 1 Get 1');
      expect(await run(t, ar, (c) => localizedDiscountLabel(c, '20% off')), '20% off');
    });

    testWidgets('store badges and ribbons', (t) async {
      expect(await run(t, enL, (c) => localizedBadgeRibbon(c, 'trending', 'x')), '🔥 TRENDING');
      expect(await run(t, ar, (c) => localizedBadgeRibbon(c, 'trending', 'x')), '🔥 ${arL.badgeTrending}');
      expect(await run(t, ar, (c) => localizedBadgeRibbon(c, 'unknown_key', 'FALLBACK')), 'FALLBACK');
      expect(await run(t, enL, (c) => localizedTopCardBadge(c, 'New Store')), 'New Store');
      expect(await run(t, ar, (c) => localizedTopCardBadge(c, 'New Store')), 'متجر جديد');
      expect(await run(t, ar, (c) => localizedTopCardBadge(c, 'Admin text')), 'Admin text');
    });

    testWidgets('delete-account reasons: display translated, the value sent to the server stays English', (t) async {
      const reasons = [
        'I no longer use the app',
        'I have privacy concerns',
        'I have a duplicate account',
        'Too many notifications or irrelevant content',
        'Other',
      ];
      for (final r in reasons) {
        expect(await run(t, enL, (c) => localizedDeleteReason(c, r)), r);
        expect(await run(t, ar, (c) => localizedDeleteReason(c, r)), isNot(r));
      }
      expect(await run(t, ar, (c) => localizedDeleteReason(c, 'Something else')), 'Something else');
    });

    testWidgets('category subtitles and loading steps', (t) async {
      expect(await run(t, enL, (c) => localizedCategorySubtitle(c, '500+ places')), '500+ places');
      expect(await run(t, ar, (c) => localizedCategorySubtitle(c, '500+ places')), 'أكثر من 500 مكان');
      expect(await run(t, ar, (c) => localizedCategorySubtitle(c, 'From the server')), 'From the server');
      for (var i = 0; i < 4; i++) {
        expect(await run(t, ar, (c) => localizedLoadingStep(c, i)), isNot(await run(t, enL, (c) => localizedLoadingStep(c, i))));
      }
      expect(await run(t, enL, (c) => localizedLoadingStep(c, 0)), 'Locating your position...');
    });

    testWidgets('category names beyond the first four', (t) async {
      expect(await run(t, enL, (c) => localizedCategoryName(c, 'Pharmacy')), 'Pharmacy');
      expect(await run(t, ar, (c) => localizedCategoryName(c, 'Pharmacy')), 'صيدلية');
      expect(await run(t, ar, (c) => localizedCategoryName(c, 'cafe')), 'مقهى');
    });
  });

  group('error messages', () {
    test('without l10n the English text is unchanged', () {
      expect(friendlyError(Exception('SocketException: Failed host lookup')),
          "We couldn't connect to OffrO right now. Please check your internet connection and try again.");
      expect(friendlyError(Exception('TimeoutException after 0:00:10')),
          'OffrO is taking too long to respond. Please try again in a moment.');
      expect(friendlyError(Exception('Network error. Please check your connection and try again.')),
          'Network error. Please check your connection and try again.');
      expect(friendlyError(Exception('')), 'Something went wrong. Please try again.');
    });

    test('with English l10n the text equals the unlocalized text', () {
      for (final e in [
        Exception('SocketException: x'),
        Exception('TimeoutException'),
        Exception('FormatException: x'),
        Exception('HTTP 401'),
        Exception('Network error. Please check your connection and try again.'),
        Exception('Unexpected response from server.'),
        Exception(''),
      ]) {
        expect(friendlyError(e, l10n: en), friendlyError(e), reason: e.toString());
      }
    });

    test('with Arabic l10n the app messages are Arabic', () {
      expect(friendlyError(Exception('SocketException: x'), l10n: arL), arL.errConnect);
      expect(friendlyError(Exception('TimeoutException'), l10n: arL), arL.errTimeout);
      expect(friendlyError(Exception('FormatException: x'), l10n: arL), arL.errUnavailable);
      expect(friendlyError(Exception('HTTP 401'), l10n: arL), arL.errSession);
      expect(friendlyError(Exception('Network error. Please check your connection and try again.'), l10n: arL), arL.errApiNetwork);
      expect(friendlyError(Exception('Unexpected response from server.'), l10n: arL), arL.errApiUnexpected);
      expect(friendlyError(Exception(''), l10n: arL), arL.errGeneric);
    });

    test('a backend business message is kept exactly as written in both languages', () {
      const m = 'Store subscription is required before adding a deal.';
      expect(friendlyError(Exception(m)), m);
      expect(friendlyError(Exception(m), l10n: arL), m);
    });

    test('a caller-supplied fallback is still used', () {
      expect(friendlyError(Exception(''), fallback: 'Custom'), 'Custom');
      expect(friendlyError(Exception(''), fallback: 'Custom', l10n: arL), 'Custom');
    });
  });

  group('widgets', () {
    testWidgets('support note: English unchanged, Arabic translated, text sits at the right edge in Arabic', (t) async {
      await t.pumpWidget(app(const Scaffold(body: SupportInfoNote())));
      expect(find.text(kProfileSupportNote), findsOneWidget);
      await t.pumpWidget(app(const Scaffold(body: SupportInfoNote()), locale: ar));
      expect(find.text(kProfileSupportNote), findsNothing);
      expect(find.text(arL.profileSupportNote), findsOneWidget);
      // the support icon is first in the row, so in Arabic it is on the right and the text is to its left
      final icon = t.getCenter(find.byIcon(Icons.support_agent_rounded));
      final text = t.getCenter(find.text(arL.profileSupportNote));
      expect(icon.dx, greaterThan(text.dx));
    });

    testWidgets('store highlight chips: English unchanged, Arabic translated', (t) async {
      const store = {'is_trending': true, 'is_new_in_town': true};
      await t.pumpWidget(app(const Scaffold(body: StoreHighlights(store: store))));
      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('Just Opened'), findsOneWidget);
      await t.pumpWidget(app(const Scaffold(body: StoreHighlights(store: store)), locale: ar));
      expect(find.text('Trending'), findsNothing);
      expect(find.text(arL.storeChipTrending), findsOneWidget);
      expect(find.text(arL.storeChipJustOpened), findsOneWidget);
    });
  });

  // Ratchet: sentences migrated in this batch must not come back as hard-coded literals in the same file.
  // (Generated from the files at the time of the batch; a file may only get cleaner.)
  group('no hard-coded copies of migrated customer text', () {
    String strip(String s) {
      final noBlock = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      return noBlock.split('\n').map((l) => l.replaceAll(RegExp(r'''(?<![:'"])//.*$'''), '')).join('\n');
    }

    int count(String code, String v) {
      final lit = v.replaceAll('\n', r'\n');
      return "'$lit'".allMatches(code).length + '"$lit"'.allMatches(code).length;
    }

    final guard = <String, List<String>>{
    'lib/core/widgets/store_cards.dart': [
      en.storeDealWord,
    ],
    'lib/main.dart': [
      en.profileFavourites,
      en.profileFavouritesNote,
      en.profileRewardsNote,
      en.profileScanHistory,
      en.profileScanHistoryNote,
      en.profileNotifications,
      en.profileNotificationsNote,
      en.profileSwitchMode,
      en.profileSwitchModeNote,
      en.profileContact,
      en.profileContactNote,
      en.profileAboutUs,
      en.profileAboutFallback,
      en.profileTerms,
      en.profilePrivacy,
      en.profilePrivacyNote,
      en.profileRefund,
      en.profileLogout,
      en.commonCancel,
      en.commonClose,
      en.notifClearTitle,
      en.notifClearBody,
      en.notifClearAll,
      en.notifEmptyTitle,
      en.notifEmptyBody,
      en.timeAgoJustNow,
      en.searchNoStores,
      en.searchStoreAreaOffer,
      en.catCategoriesTitle,
      en.catSearchCategories,
      en.catNoCategories,
      en.catAllCategories,
      en.dealExpired,
      en.dealEndsInOneDay,
      en.dealLocalBadge,
      en.dealAvailableInStore,
      en.dealsEyebrow,
      en.dealsTitle,
      en.dealsSubtitleNearby,
      en.dealsSearch,
      en.dealsThisWeek,
      en.dealsNoneActive,
      en.dealsNoMatch,
      en.areasTitle,
      en.areasSearch,
      en.areasNone,
      en.areaNoStores,
      en.storeSeeAllStores,
      en.storeOpenNowCaps,
      en.prodTitleFallback,
      en.prodListedBy,
      en.prodViewStore,
      en.prodStoreInactive,
      en.prodDetails,
      en.prodRateReview,
      en.prodTapToRate,
      en.ratingPoor,
      en.ratingFair,
      en.ratingGood,
      en.ratingGreat,
      en.ratingExcellent,
      en.prodShareExperience,
      en.prodSubmitReview,
      en.prodThanksReview,
      en.reviewLoginRequired,
      en.reviewSubmitted,
      en.reviewSessionExpired,
      en.prodAllProducts,
      en.prodNoProducts,
      en.prodSearch,
      en.prodBestSeller,
      en.monthJan,
      en.monthFeb,
      en.monthMar,
      en.monthApr,
      en.monthMay,
      en.monthJun,
      en.monthJul,
      en.monthAug,
      en.monthSep,
      en.monthOct,
      en.monthNov,
      en.monthDec,
      en.scanHistoryTitle,
      en.legalPrivacyTitle,
      en.catBrowseTitle,
      en.catView,
      en.prodSpecialOffer,
      en.prodDownload,
    ],
    'lib/screens/favorites/favorites_page.dart': [
      en.profileFavourites,
      en.favEyebrow,
      en.favEmptyTitle,
      en.favEmptyBody,
    ],
    'lib/screens/home/explore_tab.dart': [
      en.exploreYourCity,
      en.exploreTitle,
      en.exploreDesc,
      en.exploreSearchHint,
      en.exploreSearchNote,
      en.exploreByArea,
      en.exploreAroundYou,
      en.exploreNeighbourhood,
      en.exploreNoMatchTitle,
      en.exploreNoMatchBody,
    ],
    'lib/screens/home/profile_tab.dart': [
      en.profileGuestName,
    ],
    'lib/screens/legal/privacy_policy_page.dart': [
      en.profilePrivacy,
      en.commonCancel,
      en.commonOk,
      en.legalEyebrow,
      en.legalPrivacyTitle,
      en.legalPrivacyUpdating,
      en.legalReadLess,
      en.legalReadMore,
      en.legalAccountCaps,
      en.legalDeleteRequest,
      en.legalDeleteRequestNote,
      en.delEyebrow,
      en.delTitle,
      en.delWarning,
      en.delSelectReason,
      en.delSubmit,
      en.delConfirmTitle,
      en.delConfirmBody,
      en.delConfirmYes,
      en.delRequestedTitle,
      en.delRequestedBody,
    ],
    'lib/screens/location/location_screen.dart': [
      en.commonCancel,
      en.locGpsFailed,
      en.locCityUnknown,
      en.locServicesOff,
      en.locPermissionOff,
      en.locNotDetected,
      en.locGoToSettings,
      en.locCityUnsupportedTitle,
      en.commonOk,
      en.locTitle,
      en.locSearchHint,
      en.locCitiesLoadFailed,
      en.locTryAgain,
      en.locPopularCities,
      en.locAllCities,
      en.locCities,
      en.locAreas,
      en.locNoMatch,
    ],
    'lib/screens/qr/qr_page.dart': [
      en.qrTitle,
      en.qrInvalid,
      en.qrPointsAdded,
      en.qrDone,
      en.qrGreat,
      en.qrPointAt,
    ],
    'lib/screens/store/widgets/bottom_action_bar.dart': [
      en.storeScanCardTitle,
      en.storeScanQr,
    ],
    'lib/screens/store/widgets/reward_points_section.dart': [
      en.storeRewardsSoon,
      en.storeEarnPointsTitle,
    ],
    'lib/screens/store/widgets/store_about_section.dart': [
      en.storeTabAbout,
      en.storeShowLess,
      en.storeReadMore,
      en.storeOpenWord,
      en.storeClosedWord,
      en.storeDineIn,
    ],
    'lib/screens/store/widgets/store_header.dart': [
      en.storeOpenWord,
      en.storeClosedWord,
      en.storeCall,
      en.storeWhatsApp,
      en.storeDirections,
    ],
    'lib/screens/store/widgets/store_highlights.dart': [
      en.storeChipTrending,
      en.storeChipJustOpened,
      en.storeChipPopular,
    ],
    'lib/screens/store/widgets/store_offers_section.dart': [
      en.storeExclusive,
      en.storeDealsFromStore,
      en.storeOffersSoon,
      en.storeOffWord,
    ],
    'lib/screens/store/widgets/store_products_section.dart': [
      en.prodsAvailableEyebrow,
      en.prodsFeatured,
      en.prodsTip,
      en.prodYourRating,
      en.prodRateThis,
      en.prodReviewHint,
      en.prodSubmitRating,
      en.prodThanksRating,
      en.prodGotIt,
    ],
    'lib/screens/store/widgets/store_reviews_section.dart': [
      en.commonCancel,
      en.monthJan,
      en.monthFeb,
      en.monthMar,
      en.monthApr,
      en.monthMay,
      en.monthJun,
      en.monthJul,
      en.monthAug,
      en.monthSep,
      en.monthOct,
      en.monthNov,
      en.monthDec,
      en.storeTabReviews,
      en.prodYourRating,
      en.revStoreNotFound,
      en.revSelectStar,
      en.revMin5,
      en.revSubmittedStar,
      en.revUnavailable,
      en.revEyebrow,
      en.revTitle,
      en.revNoneTitle,
      en.revYourReview,
      en.revEdit,
      en.revWrite,
      en.revShareExp,
      en.revSubmit,
      en.revNoneDot,
      en.revBeFirst,
      en.revViewAll,
      en.revAllTitle,
      en.revAnonymous,
    ],
    'lib/screens/wallet/wallet_page.dart': [
      en.profileScanHistory,
      en.monthJan,
      en.monthFeb,
      en.monthMar,
      en.monthApr,
      en.monthMay,
      en.monthJun,
      en.monthJul,
      en.monthAug,
      en.monthSep,
      en.monthOct,
      en.monthNov,
      en.monthDec,
      en.walletDone,
      en.walletBadge,
      en.walletBalance,
      en.walletRedeem,
      en.walletReadyToRedeem,
      en.walletVoucherDesc,
      en.walletHowTitle,
      en.walletHowLine1('200', '₹20'),
      en.walletHowLine2,
      en.walletHowLine3,
      en.walletHowDisclaimer,
      en.walletRecent,
      en.walletNoScansHint,
      en.walletEyebrow,
      en.walletTitle,
      en.walletDesc,
      en.walletVouchersEyebrow,
      en.walletVouchersTitle,
      en.walletViewHistory,
      en.scanHistoryTitle,
      en.scanHistoryEmpty,
      en.storeTabRewards,
    ],
    };

    for (final entry in guard.entries) {
      test(entry.key, () {
        final code = strip(File(entry.key).readAsStringSync());
        final back = [for (final v in entry.value) if (count(code, v) > 0) v];
        expect(back, isEmpty, reason: 'text is hard-coded again - use context.l10n: $back');
      });
    }
  });
}
