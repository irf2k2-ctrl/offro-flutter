// Phase I: language preference rules, RTL layout and the pilot screens in English and Arabic.
// Needs the generated localizations: run `flutter gen-l10n` first (lib/l10n/gen).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/design/design.dart' show OffroIcons;
import 'package:offro_user/core/l10n/l10n.dart';
import 'package:offro_user/core/l10n/language_sheet.dart';
import 'package:offro_user/core/l10n/locale_controller.dart';
import 'package:offro_user/core/phone/country_picker_sheet.dart';
import 'package:offro_user/core/phone/phone_country.dart';
import 'package:offro_user/screens/auth/login_screen.dart';
import 'package:offro_user/screens/home/profile_tab.dart';

/// A MaterialApp configured exactly like the real app for [locale].
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

/// Same wiring as main.dart: the MaterialApp follows LocaleController.
Widget liveApp(Widget home) => AnimatedBuilder(
      animation: LocaleController.instance,
      builder: (_, __) => app(home, locale: LocaleController.instance.locale),
    );

Widget otp() => OtpScreen(phone: '+962791234567', reqId: 'R', onVerified: () async {}, countryIso: 'JO');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocaleController.instance.resetForTest();
  });

  group('language preference', () {
    test('defaults to English and ignores the device language', () async {
      await LocaleController.instance.load();
      expect(LocaleController.instance.locale.languageCode, 'en');
      expect(LocaleController.instance.isRtl, isFalse);
    });

    test('normalize accepts only supported codes', () {
      expect(LocaleController.normalize('ar'), 'ar');
      expect(LocaleController.normalize(' AR '), 'ar');
      expect(LocaleController.normalize('fr'), 'en');
      expect(LocaleController.normalize(''), 'en');
      expect(LocaleController.normalize(null), 'en');
    });

    test('a manual choice is saved and restored; a corrupted value falls back to English', () async {
      await LocaleController.instance.setLanguage('ar');
      expect((await SharedPreferences.getInstance()).getString(LocaleController.prefsKey), 'ar');
      LocaleController.instance.resetForTest();
      await LocaleController.instance.load();
      expect(LocaleController.instance.isRtl, isTrue);

      SharedPreferences.setMockInitialValues({LocaleController.prefsKey: 'klingon'});
      LocaleController.instance.resetForTest();
      await LocaleController.instance.load();
      expect(LocaleController.instance.locale.languageCode, 'en');
    });

    test('changing the language notifies listeners once and ignores a no-op change', () async {
      var n = 0;
      void l() => n++;
      LocaleController.instance.addListener(l);
      await LocaleController.instance.setLanguage('ar');
      await LocaleController.instance.setLanguage('ar');
      expect(n, 1);
      LocaleController.instance.removeListener(l);
    });
  });

  group('RTL and text', () {
    testWidgets('English is left-to-right, Arabic is right-to-left', (t) async {
      late BuildContext ctx;
      Widget probe() => Builder(builder: (c) { ctx = c; return Text(c.l10n.loginGuest); });
      await t.pumpWidget(app(probe()));
      expect(Directionality.of(ctx), TextDirection.ltr);
      expect(find.text('Continue as guest'), findsOneWidget);
      await t.pumpWidget(app(probe(), locale: const Locale('ar')));
      await t.pumpAndSettle();
      expect(Directionality.of(ctx), TextDirection.rtl);
      expect(find.text('المتابعة كضيف'), findsOneWidget);
    });

    testWidgets('without the app delegates the accessor falls back to English instead of crashing', (t) async {
      await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => Text(c.l10n.otpVerifyButton))));
      expect(find.text('Verify OTP'), findsOneWidget);
    });

    testWidgets('Western digits are used in Arabic', (t) async {
      await t.pumpWidget(app(Builder(builder: (c) => Text(c.l10n.otpResendIn('30'))), locale: const Locale('ar')));
      expect(find.textContaining('30'), findsOneWidget);
      expect(find.textContaining('٣'), findsNothing);
    });
  });

  group('OTP screen (pilot)', () {
    testWidgets('English text is unchanged and the phone number has no hidden characters', (t) async {
      await t.pumpWidget(app(otp()));
      expect(find.text('VERIFICATION'), findsOneWidget);
      expect(find.text('Verify OTP'), findsOneWidget);
      expect(find.text('We sent a 4-digit OTP to\n+962791234567'), findsOneWidget);
      expect(find.text('Send code by SMS instead'), findsOneWidget);
      await t.pumpWidget(const SizedBox()); // dispose: cancels the resend timer
    });

    testWidgets('Arabic text shows, layout is RTL, the four digit boxes stay left-to-right', (t) async {
      await t.pumpWidget(app(otp(), locale: const Locale('ar')));
      await t.pump();
      expect(find.text('التحقق'), findsOneWidget);
      expect(find.text('تحقق من الرمز'), findsOneWidget);
      expect(find.text('إرسال الرمز برسالة نصية بدلاً من ذلك'), findsOneWidget);
      expect(find.textContaining('+962791234567'), findsOneWidget);
      final boxes = find.byType(TextField);
      expect(boxes, findsNWidgets(4));
      expect(Directionality.of(t.element(boxes.first)), TextDirection.ltr);
      // box 1 is left of box 4 even in an RTL screen
      expect(t.getTopLeft(boxes.first).dx, lessThan(t.getTopLeft(boxes.last).dx));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('the SMS fallback is still offered only for non-India numbers', (t) async {
      await t.pumpWidget(app(OtpScreen(phone: '+919999999999', reqId: 'R', onVerified: () async {}, countryIso: 'IN')));
      expect(find.byKey(const ValueKey('sms_fallback_link')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('country picker, language switch, profile', () {
    testWidgets('picker title is localized, country names and dial codes are untouched', (t) async {
      Widget open() => Builder(builder: (c) => TextButton(
            onPressed: () => showCountryPickerSheet(c, selected: kDefaultPhoneCountry), child: const Text('open')));
      await t.pumpWidget(app(Scaffold(body: open()), locale: const Locale('ar')));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('اختر الدولة'), findsOneWidget);
      expect(find.text('+966'), findsOneWidget);
    });

    testWidgets('the language sheet switches the whole app to Arabic and back', (t) async {
      await t.pumpWidget(liveApp(Scaffold(body: Builder(builder: (c) => Column(children: [
            Text(c.l10n.loginGuest),
            TextButton(onPressed: () => showLanguageSheet(c), child: const Text('lang')),
          ])))));
      expect(find.text('Continue as guest'), findsOneWidget);
      await t.tap(find.text('lang'));
      await t.pumpAndSettle();
      expect(find.text('Choose language'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('language_option_ar')));
      await t.pumpAndSettle();
      expect(find.text('المتابعة كضيف'), findsOneWidget);
      expect(LocaleController.instance.isRtl, isTrue);
      await t.tap(find.text('lang'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('language_option_en')));
      await t.pumpAndSettle();
      expect(find.text('Continue as guest'), findsOneWidget);
    });

    testWidgets('the compact language button names the OTHER language', (t) async {
      await t.pumpWidget(liveApp(const Scaffold(body: LanguageButton())));
      expect(find.text('العربية'), findsOneWidget);
      await LocaleController.instance.setLanguage('ar');
      await t.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('Profile has a Language row that opens the chooser; section titles follow the language', (t) async {
      ProfileEntry e(String l) => ProfileEntry(icon: OffroIcons.user, label: l, onTap: () {});
      Widget tab() => Scaffold(body: ProfileTab(
            token: '', name: 'Sam', phone: '', isGuest: true, savedCount: 2, points: 1500,
            activity: [e('A')], account: [e('B')], legal: [e('C')], sessionAction: e('D')));
      await t.pumpWidget(liveApp(tab()));
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.text('App language'), findsOneWidget);
      await t.tap(find.text('App language'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('language_option_ar')));
      await t.pumpAndSettle();
      expect(find.text('اللغة'), findsWidgets);
      expect(find.text('الملف الشخصي'), findsOneWidget);
    });
  });
}
