// Phase J, batch 1: Home screen + bottom navigation in English and Arabic.
// Needs the generated localizations (lib/l10n/gen): run `flutter gen-l10n` first.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/design/design.dart';
import 'package:offro_user/core/l10n/l10n.dart';
import 'package:offro_user/core/utils/store_hours.dart';
import 'package:offro_user/l10n/gen/app_localizations_ar.dart';
import 'package:offro_user/l10n/gen/app_localizations_en.dart';

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

Widget navPage(List<OffroNavItem> items, {OffroNavVariant variant = OffroNavVariant.customer}) => Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: OffroBottomNav(items: items, currentIndex: 0, onTap: (_) {}, variant: variant),
    );

void main() {
  const ar = Locale('ar');

  group('bottom navigation', () {
    testWidgets('customer tabs: English text is unchanged', (t) async {
      await t.pumpWidget(app(navPage(OffroBottomNav.customerItems)));
      for (final s in ['Home', 'Explore', 'Deals', 'Rewards', 'Profile']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
    });

    testWidgets('customer tabs: Arabic text, no English left, tabs run right-to-left', (t) async {
      await t.pumpWidget(app(navPage(OffroBottomNav.customerItems), locale: ar));
      for (final s in ['الرئيسية', 'استكشف', 'العروض', 'المكافآت', 'الملف الشخصي']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      for (final s in ['Home', 'Explore', 'Deals', 'Rewards', 'Profile']) {
        expect(find.text(s), findsNothing, reason: s);
      }
      // first tab (Home) sits at the right edge in Arabic
      expect(t.getCenter(find.text('الرئيسية')).dx, greaterThan(t.getCenter(find.text('الملف الشخصي')).dx));
    });

    testWidgets('merchant and influencer tabs are translated too', (t) async {
      await t.pumpWidget(app(navPage(OffroBottomNav.merchantItems, variant: OffroNavVariant.merchant), locale: ar));
      for (final s in ['الرئيسية', 'العروض', 'الفواتير', 'النشاط', 'الملف الشخصي']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      await t.pumpWidget(app(navPage(const [
        OffroNavItem(label: 'Home', icon: OffroIcons.home),
        OffroNavItem(label: 'Opportunities', icon: OffroIcons.sparkles),
        OffroNavItem(label: 'Profile', icon: OffroIcons.user),
      ]), locale: ar));
      expect(find.text('الفرص'), findsOneWidget);
    });

    testWidgets('semantics label follows the language; an unknown tab keeps its own text', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(app(navPage(const [
        OffroNavItem(label: 'Home', icon: OffroIcons.home),
        OffroNavItem(label: 'Brand new tab', icon: OffroIcons.tag),
      ]), locale: ar));
      expect(find.bySemanticsLabel('الرئيسية'), findsOneWidget);
      expect(find.text('Brand new tab'), findsOneWidget);
      handle.dispose();
    });
  });

  group('helpers', () {
    Future<String> run(WidgetTester t, Locale l, String Function(BuildContext) f) async {
      late String out;
      await t.pumpWidget(app(Builder(builder: (c) { out = f(c); return const SizedBox(); }), locale: l));
      return out;
    }

    testWidgets('category names: known ones translate, others and logic names are untouched', (t) async {
      expect(await run(t, ar, (c) => localizedCategoryName(c, 'Bakery')), 'المخابز');
      expect(await run(t, ar, (c) => localizedCategoryName(c, ' restaurant ')), 'المطاعم');
      expect(await run(t, ar, (c) => localizedCategoryName(c, 'Automobile')), 'السيارات');
      expect(await run(t, ar, (c) => localizedCategoryName(c, 'Grocery')), 'البقالة');
      expect(await run(t, ar, (c) => localizedCategoryName(c, 'Pet Care')), 'Pet Care');
      expect(await run(t, const Locale('en'), (c) => localizedCategoryName(c, 'Bakery')), 'Bakery');
    });

    testWidgets('store hours sub-label: English equals the old text, Arabic is translated', (t) async {
      const closes = StoreHoursStatus(true, 'Closes 9 PM', subKind: 'closes', subHour: 21, subMinute: 0);
      const opens = StoreHoursStatus(false, 'Opens 9:30 AM', subKind: 'opens', subHour: 9, subMinute: 30);
      const noon = StoreHoursStatus(true, 'Closes 12 PM', subKind: 'closes', subHour: 12, subMinute: 0);
      const midnight = StoreHoursStatus(false, 'Opens 12 AM', subKind: 'opens', subHour: 0, subMinute: 0);
      const none = StoreHoursStatus(false, '');
      for (final s in [closes, opens, noon, midnight, none]) {
        expect(await run(t, const Locale('en'), (c) => localizedStoreHoursSub(c, s)), s.subLabel);
      }
      expect(await run(t, ar, (c) => localizedStoreHoursSub(c, closes)), 'يغلق 9 م');
      expect(await run(t, ar, (c) => localizedStoreHoursSub(c, opens)), 'يفتح 9:30 ص');
      expect(await run(t, ar, (c) => localizedStoreHoursSub(c, midnight)), 'يفتح 12 ص');
      expect(await run(t, ar, (c) => localizedStoreHoursSub(c, none)), '');
    });

    test('computeStoreOpenStatus still produces the same English sub-label as before', () {
      final s = computeStoreOpenStatus('00:00', '23:59');
      expect(s, isNotNull);
      if (s!.subKind == 'closes') expect(s.subLabel, 'Closes 11:59 PM');
    });
  });

  group('Home strings', () {
    final en = AppLocalizationsEn(), arL = AppLocalizationsAr();

    test('English text is exactly what the Home screen showed before', () {
      expect(en.homeSearchHint, 'Search stores, products or services');
      expect(en.homeExploring, 'Exploring');
      expect(en.homeHeroBadge, 'LOCAL DEALS & STORES');
      expect(en.homeHeroSubtitle, 'Discover stores, deals & local favorites');
      expect(en.homeDiscoverStores, 'Discover stores');
      expect(en.homeCategoriesTitle, 'Explore categories');
      expect(en.homeSeeAll, 'See All');
      expect(en.homeSeeAllLower, 'See all');
      expect(en.homeViewAll, 'View all');
      expect(en.homeViewArrow, 'View →');
      expect(en.homeViewAllArrow, 'View all →');
      expect(en.homeProductsTitle, 'Products near you');
      expect(en.homeStoresNearTitle, 'Stores near you');
      expect(en.homeExploreAreasTitle, 'Explore Areas');
      expect(en.homeBadgeNew, 'NEW');
      expect(en.homeRewardsBadge, 'OFFRO REWARDS');
      expect(en.homeDealDaysLeft('3'), '3 days left');
      expect(en.homePercentOff('20'), '20% off');
      expect(en.homeDistanceUnder('5'), 'Under 5 km');
      expect(en.homeNoStoresWithin('3'), 'No stores within 3 km');
      expect(en.homeOfferInline('Free tea'), 'Offer · Free tea');
      expect(en.homeFavoriteSaveFailed('x'), "Couldn't save favorite: x");
      expect(en.storeClosesAt('9 PM'), 'Closes 9 PM');
    });

    test('Arabic is present for every Home string and keeps Western digits', () {
      expect(arL.homeSearchHint, isNot(en.homeSearchHint));
      expect(arL.homeDealDaysLeft('3'), 'يتبقى 3 أيام');
      expect(arL.homePercentOff('20'), 'خصم 20%');
      expect(arL.homeDistanceUnder('5'), 'أقل من 5 كم');
      expect(arL.homeNoStoresWithin('3'), 'لا توجد متاجر ضمن 3 كم');
      expect(arL.homeViewArrow, contains('←'));
      expect(arL.homeViewAllArrow, contains('←'));
      expect(arL.homeSeeAll, isNot('See All'));
    });
  });

  // Ratchet: the Batch 1 English sentences must not come back as literals. main.dart still hard-codes a few of them in screens
  // that belong to later batches; each is listed with its remaining count and may only go DOWN.
  group('no new hard-coded copies of migrated Home text', () {
    String strip(String s) {
      final noBlock = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      return noBlock.split('\n').map((l) => l.replaceAll(RegExp(r'''(?<![:'"])//.*$'''), '')).join('\n');
    }

    int count(String code, String v) {
      final lit = v.replaceAll('\n', r'\n');
      return "'$lit'".allMatches(code).length + '"$lit"'.allMatches(code).length;
    }

    final en = AppLocalizationsEn();
    // value -> allowed remaining occurrences in main.dart (all in later-batch screens, or a tab identity label)
    final allowedInMain = <String, int>{
      en.navProfile: 1,            // OffroNavItem identity label (text is translated at display time)
      en.homeDealEndsToday: 1,     // deals list screen (Customer batch)
      en.homeCategoriesEyebrow: 1, // all-categories screen (Customer batch)
      en.catBakery: 1, en.catRestaurant: 1, en.catGrocery: 1, // category tone tables keyed by name (logic, not display)
      en.homeProductsEyebrow: 1,   // products list screen (Customer batch)
      en.homeClosed: 1,            // banner store card (Customer batch)
      en.homeFeatureRewards: 1,    // profile menu (Customer batch)
      en.homeCouldntLoadStores: 1, // category stores screen (Customer batch)
      en.commonRetry: 1,           // other screens (shared components batch)
      en.homeLoginRegister: 1,     // profile menu item (Customer batch)
    };

    test('lib/main.dart', () {
      final code = strip(File('lib/main.dart').readAsStringSync());
      final values = <String>{
        en.homeSearchHint, en.homeExploring, en.homeHeroBadge, en.homeHeroSubtitle, en.homeDiscoverStores, en.homeYourCity,
        en.homeDealEndsToday, en.homeDealOneDayLeft, en.homeExclusiveEyebrow, en.homeExclusiveTitle, en.homeViewAll,
        en.homeDealOffer, en.homeRewardsBadge, en.homeRewardsTapToView, en.homeRewardsEarnHint, en.homeCategoriesEyebrow,
        en.homeCategoriesTitle, en.homeSeeAll, en.homeSeeAllLower, en.homeProductsEyebrow, en.homeProductsTitle,
        en.homeBrowseAll, en.homeNearbyEyebrow, en.homeStoresNearTitle, en.homeNearbyStoresTitle, en.homeBadgeNew,
        en.homeOpenNow, en.homeClosed, en.homeDistanceAny, en.homeTryLargerRadius, en.homeExploreAreasTitle,
        en.homeExploreAreasSubtitle, en.homeViewArrow, en.homeViewAllArrow, en.homeStoreWord, en.homeFeatureRewards,
        en.homeBackToHome, en.homeContactSupport, en.homeNoInternet, en.homeCheckConnection, en.homeServerSlow,
        en.homeColdStart, en.homeCouldntLoadStores, en.homePleaseTryAgain, en.homeCouldntLoadPage, en.commonRetry,
        en.commonTryAgain, en.homeLoginRequiredTitle, en.homeLoginRegister, en.homeMaybeLater, en.catBakery, en.catAutomobile, en.catRestaurant, en.catGrocery, en.navProfile,
      };
      final over = <String>[];
      for (final v in values) {
        final n = count(code, v);
        if (n > (allowedInMain[v] ?? 0)) over.add("'$v' x$n (allowed ${allowedInMain[v] ?? 0})");
      }
      expect(over, isEmpty, reason: 'Home text is hard-coded again - use context.l10n: $over');
    });

    test('promo slider has no hard-coded copy', () {
      final code = strip(File('lib/screens/home/widgets/promo_slider_section.dart').readAsStringSync());
      for (final v in [en.homePromoTitle, en.homePromoSubtitle]) {
        expect(count(code, v), 0, reason: v);
      }
    });
  });
}
