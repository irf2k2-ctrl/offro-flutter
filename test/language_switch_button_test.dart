// The header language switch (next to the notification bell): visibility follows the existing country -> language policy, the tap uses
// the existing LocaleController, the choice is saved, the whole app flips LTR/RTL, nothing else in the header is affected.
// No network and no real storage (SharedPreferences mock).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/l10n/l10n.dart';
import 'package:offro_user/core/l10n/language_policy.dart';
import 'package:offro_user/core/l10n/language_switch_button.dart';
import 'package:offro_user/core/l10n/locale_controller.dart';
import 'package:offro_user/core/services/api_service.dart';

// Arabic is enabled for these two countries by the (simulated) admin mapping; every other country is English only.
const arabicForSaAndJo = <String, Set<String>>{
  'en': {'SA', 'IN', 'JO', 'NP', 'PH'},
  'ar': {'SA', 'JO'},
};

Widget app(Widget home) => AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (_, __) => MaterialApp(
        locale: LocaleController.instance.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: Align(alignment: Alignment.topCenter, child: home)),
      ),
    );

final switchFinder = find.byKey(const ValueKey('language_switch'));
Future<String?> savedLanguage() async => (await SharedPreferences.getInstance()).getString(LocaleController.prefsKey);
TextDirection directionOf(WidgetTester t) => Directionality.of(t.element(switchFinder.evaluate().isNotEmpty ? switchFinder : find.byType(Scaffold)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocaleController.instance.resetForTest();
    ActiveCountry.instance.resetForTest();
    Api.customerCountry = null;
    languageMappingForTest = arabicForSaAndJo;
    ActiveCountry.instance.setSelected('SA');
  });
  tearDown(() {
    languageMappingForTest = null;
    ActiveCountry.instance.resetForTest();
    Api.customerCountry = null;
  });

  group('what the switch decides (pure)', () {
    test('hidden unless Arabic is allowed; otherwise the target is the other language', () {
      expect(languageSwitchTarget(current: 'en', allowed: const ['en']), isNull);
      expect(languageSwitchTarget(current: 'ar', allowed: const ['en']), isNull);
      expect(languageSwitchTarget(current: 'en', allowed: const ['en', 'ar']), 'ar');
      expect(languageSwitchTarget(current: 'ar', allowed: const ['en', 'ar']), 'en');
    });
  });

  group('visibility follows the existing country configuration', () {
    testWidgets('1. English app + an Arabic-enabled country: green circle with ع', (t) async {
      await t.pumpWidget(app(const LanguageSwitchButton()));
      expect(find.text('ع'), findsOneWidget);
      expect(find.text('E'), findsNothing);
      final circle = t.widget<Container>(find.descendant(of: switchFinder, matching: find.byType(Container)));
      final deco = circle.decoration as BoxDecoration;
      expect(deco.color, const Color(0xFF3E5F55));
      expect(deco.shape, BoxShape.circle);
      expect(t.getSize(switchFinder), const Size(40, 40)); // the bell's size
      expect(t.widget<Text>(find.text('ع')).style!.color, Colors.white);
    });

    testWidgets('6. a country without Arabic: nothing is drawn (India, and Nepal / Philippines not in the mapping)', (t) async {
      for (final iso in ['IN', 'NP', 'PH']) {
        ActiveCountry.instance.setSelected(iso);
        await t.pumpWidget(app(const LanguageSwitchButton()));
        expect(switchFinder, findsNothing, reason: iso);
        expect(find.text('ع'), findsNothing, reason: iso);
        expect(find.text('E'), findsNothing, reason: iso);
      }
    });

    testWidgets('Arabic is enabled by the mapping, not by a country name: Jordan shows it, and so does India once it is mapped', (t) async {
      ActiveCountry.instance.setSelected('JO');
      await t.pumpWidget(app(const LanguageSwitchButton()));
      expect(switchFinder, findsOneWidget);
      ActiveCountry.instance.setSelected('IN');
      await t.pump();
      expect(switchFinder, findsNothing);
      languageMappingForTest = const {'en': {'IN'}, 'ar': {'IN'}};
      ActiveCountry.instance.setSelected('JO'); // any notification re-reads the mapping
      ActiveCountry.instance.setSelected('IN');
      await t.pump();
      expect(switchFinder, findsOneWidget);
    });

    testWidgets('no mapping known (older backend / offline, nothing cached): hidden', (t) async {
      languageMappingForTest = const {};
      await t.pumpWidget(app(const LanguageSwitchButton()));
      expect(switchFinder, findsNothing);
    });

    testWidgets('8. switching the country updates the visibility', (t) async {
      await t.pumpWidget(app(const LanguageSwitchButton()));
      expect(switchFinder, findsOneWidget);
      ActiveCountry.instance.setSelected('IN');
      await t.pump();
      expect(switchFinder, findsNothing);
      ActiveCountry.instance.setSelected('SA');
      await t.pump();
      expect(switchFinder, findsOneWidget);
      Api.setCustomerCountryFromPhone('+919876543210'); // the signed-in account's country wins over the device / login country
      await t.pump();
      expect(switchFinder, findsNothing);
      Api.setCustomerCountryFromPhone('+966501234567');
      await t.pump();
      expect(switchFinder, findsOneWidget);
    });
  });

  group('tap behaviour', () {
    testWidgets('2-4. ع switches to Arabic + RTL and shows E; E switches back to English + LTR', (t) async {
      await t.pumpWidget(app(const LanguageSwitchButton()));
      expect(directionOf(t), TextDirection.ltr);

      await t.tap(switchFinder);
      await t.pumpAndSettle();
      expect(LocaleController.instance.locale.languageCode, 'ar');
      expect(directionOf(t), TextDirection.rtl); // the whole app flips, no restart
      expect(find.text('E'), findsOneWidget);
      expect(find.text('ع'), findsNothing);
      expect(t.widget<Text>(find.text('E')).style!.color, Colors.white);
      expect(t.getSize(switchFinder), const Size(40, 40));

      await t.tap(switchFinder);
      await t.pumpAndSettle();
      expect(LocaleController.instance.locale.languageCode, 'en');
      expect(directionOf(t), TextDirection.ltr);
      expect(find.text('ع'), findsOneWidget);
    });

    testWidgets('5. the choice is saved by the existing mechanism and survives a restart', (t) async {
      await t.pumpWidget(app(const LanguageSwitchButton()));
      await t.tap(switchFinder);
      await t.pumpAndSettle();
      expect(await savedLanguage(), 'ar');

      LocaleController.instance.resetForTest(); // "close the app" ...
      expect(LocaleController.instance.locale.languageCode, 'en');
      await LocaleController.instance.load(); // ... "and reopen it"
      expect(LocaleController.instance.locale.languageCode, 'ar');
      await t.pumpWidget(app(const LanguageSwitchButton()));
      expect(find.text('E'), findsOneWidget);
    });

    testWidgets('a saved Arabic choice in a country that does not allow it is still replaced by the existing policy', (t) async {
      await t.pumpWidget(app(const LanguageSwitchButton()));
      await t.tap(switchFinder);
      await t.pumpAndSettle();
      ActiveCountry.instance.setSelected('IN');
      expect(await enforceLanguagePolicy(), isTrue);
      await t.pumpAndSettle();
      expect(LocaleController.instance.locale.languageCode, 'en');
      expect(switchFinder, findsNothing);
    });
  });

  group('Merchant / Influencer home: the switch is the last item of the header', () {
    Widget hero() => const SizedBox(
          width: 360,
          child: Row(children: [Text('logo'), Spacer(), LanguageSwitchButton(gapAfter: false)]),
        );

    testWidgets('it sits flush with the trailing edge in LTR and RTL, with the same visibility rules', (t) async {
      await t.pumpWidget(app(hero()));
      final box = t.getTopLeft(find.text('logo')).dx; // the header row's leading edge
      expect(t.getTopRight(switchFinder).dx - box, 360);
      expect(t.getSize(switchFinder), const Size(40, 40));
      await t.tap(switchFinder);
      await t.pumpAndSettle();
      expect(LocaleController.instance.locale.languageCode, 'ar');
      expect(find.text('E'), findsOneWidget);
      // RTL: the row now starts on the right, so the switch is flush with the LEFT edge of the 360 px row
      expect(t.getTopLeft(switchFinder).dx, t.getTopRight(find.text('logo')).dx - 360);
      ActiveCountry.instance.setSelected('IN');
      await t.pump();
      expect(switchFinder, findsNothing);
    });
  });

  group('the header around it', () {
    Widget header({required VoidCallback onBell, double width = 360}) => SizedBox(
          width: width,
          child: Row(children: [
            const Text('logo'),
            const Spacer(),
            const LanguageSwitchButton(),
            // Mirrors the real bell in _HomeHeader: a decorated circle of kHeaderCircleSize (an EMPTY SizedBox would not be hit-testable,
            // which is why an earlier version of this stand-in could never be tapped).
            GestureDetector(
              key: const ValueKey('bell'),
              onTap: onBell,
              child: Container(
                width: kHeaderCircleSize,
                height: kHeaderCircleSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
                child: const Icon(Icons.notifications_none_rounded, size: 18),
              ),
            ),
          ]),
        );

    testWidgets('7. the switch never triggers the bell, and the bell still works in both languages', (t) async {
      var bell = 0;
      await t.pumpWidget(app(header(onBell: () => bell++)));
      final bellFinder = find.byKey(const ValueKey('bell'));
      expect(bellFinder, findsOneWidget);
      // English: the switch changes the language and leaves the bell alone
      await t.tap(switchFinder);
      await t.pumpAndSettle();
      expect(LocaleController.instance.locale.languageCode, 'ar');
      expect(bell, 0);
      // Arabic: the bell fires its callback exactly once per tap
      await t.tap(bellFinder);
      await t.pump();
      expect(bell, 1);
      expect(LocaleController.instance.locale.languageCode, 'ar', reason: 'tapping the bell must not change the language');
      // back to English through the switch; the bell still fires once
      await t.tap(switchFinder);
      await t.pumpAndSettle();
      expect(LocaleController.instance.locale.languageCode, 'en');
      expect(bell, 1);
      await t.tap(bellFinder);
      await t.pump();
      expect(bell, 2);
    });

    testWidgets('the switch circle has exactly the bell\'s diameter, and both are vertically centred on each other, in both languages', (t) async {
      await t.pumpWidget(app(header(onBell: () {})));
      final bellFinder = find.byKey(const ValueKey('bell'));
      for (var i = 0; i < 2; i++) { // English, then Arabic
        expect(t.getSize(switchFinder), t.getSize(bellFinder));
        expect(t.getSize(switchFinder), const Size(kHeaderCircleSize, kHeaderCircleSize));
        expect(t.getCenter(switchFinder).dy, t.getCenter(bellFinder).dy);
        await t.tap(switchFinder);
        await t.pumpAndSettle();
      }
    });

    test('the real bell in the customer home header uses the same shared size constant (no second hard-coded number)', () {
      final src = File('lib/main.dart').readAsStringSync();
      final bell = src.substring(src.indexOf('onTap: onBellTap,'));
      final circle = bell.substring(0, bell.indexOf('OffroIcons.bell'));
      expect(circle, contains('width: kHeaderCircleSize'));
      expect(circle, contains('height: kHeaderCircleSize'));
      expect(const LanguageSwitchButton().size, kHeaderCircleSize);
      expect(kHeaderCircleSize, 40, reason: 'the bell size must not change');
    });

    testWidgets('spacing between the switch and the bell is the same in LTR and RTL', (t) async {
      await t.pumpWidget(app(header(onBell: () {})));
      final ltrGap = t.getTopLeft(find.byKey(const ValueKey('bell'))).dx - t.getTopRight(switchFinder).dx;
      expect(ltrGap, 8);
      await t.tap(switchFinder);
      await t.pumpAndSettle();
      final rtlGap = t.getTopLeft(switchFinder).dx - t.getTopRight(find.byKey(const ValueKey('bell'))).dx;
      expect(rtlGap, 8);
    });

    testWidgets('10. no overflow on a narrow screen with the largest text size, in both languages', (t) async {
      t.view.devicePixelRatio = 1.0;
      t.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearAllTestValues);
      for (final w in [320.0, 360.0, 411.0]) {
        t.view.physicalSize = Size(w, 800);
        await t.pumpWidget(app(header(onBell: () {}, width: w)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'English at width $w');
        expect(t.getSize(switchFinder), const Size(40, 40));
        await t.tap(switchFinder);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'Arabic at width $w');
        expect(t.getSize(switchFinder), const Size(40, 40));
        await LocaleController.instance.setLanguage('en');
      }
    });
  });
}
