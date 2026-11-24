// Login screen: the social icons (and the "FOLLOW THE LOCAL STORY" heading) must never be clipped by the bottom edge or the system
// navigation inset, in English and Arabic, on small and tall screens. Needs the generated localizations (`flutter gen-l10n`).
// No network: the social links are supplied through LoginScreen.debugSocialLoader.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/l10n/l10n.dart';
import 'package:offro_user/screens/auth/login_screen.dart';

Widget _app(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LoginScreen(),
    );

const _icons = [Icons.chat_rounded, Icons.camera_alt_rounded, Icons.facebook_rounded, Icons.play_circle_fill_rounded];

Future<void> _pumpLogin(WidgetTester t, {required Size size, required Locale locale, double navInset = 0, double textScale = 1}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.viewPadding = FakeViewPadding(bottom: navInset);   // edge-to-edge: the gesture / 3-button bar the app draws under
  t.view.padding = FakeViewPadding(bottom: navInset);
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    t.view.reset();
    t.platformDispatcher.clearTextScaleFactorTestValue();
  });
  LoginScreen.debugSocialLoader = () async => {
        'whatsapp': '911234567890',
        'instagram': 'https://instagram.com/offro',
        'facebook': 'https://facebook.com/offro',
        'youtube': 'https://youtube.com/@offro',
      };
  addTearDown(() => LoginScreen.debugSocialLoader = null);
  await t.pumpWidget(_app(locale));
  await t.pump(const Duration(milliseconds: 700));      // slide / fade animations
  for (var i = 0; i < 8; i++) {                         // icons arrive, then the fit check tightens the hero step by step
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// No native SMS plugin in a test run (it would answer with a PlatformException channel-error).
class _NoopSmsNative implements SmsConsentNative {
  @override
  Future<void> removeListener() async {}
  @override
  Future<String?> waitForCode() async => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SmsConsentOtp.debugNative = _NoopSmsNative();
  });
  tearDown(() => SmsConsentOtp.debugNative = null);

  const sizes = <String, Size>{
    'small 320x568': Size(320, 568),
    'compact 360x640': Size(360, 640),
    'common 360x800': Size(360, 800),
    'tall 412x915': Size(412, 915),
    'tablet 800x1280': Size(800, 1280),
  };

  for (final lang in const ['en', 'ar']) {
    for (final e in sizes.entries) {
      testWidgets('[$lang] ${e.key}: all four social icons and the heading can be seen without clipping', (t) async {
        const inset = 24.0;
        await _pumpLogin(t, size: e.value, locale: Locale(lang), navInset: inset);
        final heading = find.text(AppLocalizations.of(t.element(find.byType(LoginScreen)))!.loginFollow);
        expect(heading, findsOneWidget);
        for (final ic in _icons) {
          expect(find.byIcon(ic), findsOneWidget, reason: 'icon $ic is missing');
        }
        // Whatever does not fit the first screen must be reachable by scrolling: scroll to the very end of the page.
        final scroll = find.byType(SingleChildScrollView).first;
        await t.drag(scroll, Offset(0, -e.value.height * 2));
        await t.pump(const Duration(milliseconds: 300));
        for (final ic in _icons) {
          final r = t.getRect(find.byIcon(ic));
          expect(r.top, greaterThanOrEqualTo(0), reason: '$ic above the top');
          expect(r.bottom, lessThanOrEqualTo(e.value.height - inset), reason: '$ic is under the navigation inset / below the screen');
        }
        expect(t.getRect(heading).bottom, lessThanOrEqualTo(t.getRect(find.byIcon(_icons.first)).top));
      });
    }
  }

  for (final lang in const ['en', 'ar']) {
    for (final e in const {'common 360x800': Size(360, 800), 'tall 412x915': Size(412, 915), 'tablet 800x1280': Size(800, 1280)}.entries) {
      testWidgets('[$lang] ${e.key}: the social row is visible on the FIRST screen (no scrolling needed)', (t) async {
        const inset = 24.0;
        await _pumpLogin(t, size: e.value, locale: Locale(lang), navInset: inset);
        for (final ic in _icons) {
          final r = t.getRect(find.byIcon(ic));
          expect(r.bottom, lessThanOrEqualTo(e.value.height - inset), reason: '$ic is clipped at the bottom without scrolling');
        }
      });
    }
  }

  testWidgets('the icons are not shrunk or removed to make room', (t) async {
    await _pumpLogin(t, size: const Size(360, 640), locale: const Locale('en'));
    for (final ic in _icons) {
      expect(t.getSize(find.byIcon(ic)).width, 22);
    }
  });

  testWidgets('the Register tab keeps its original hero spacing (it scrolls, as before)', (t) async {
    await _pumpLogin(t, size: const Size(360, 640), locale: const Locale('en'));
    final before = t.getTopLeft(find.byKey(const ValueKey('login_badge')));
    await t.tap(find.text(AppLocalizations.of(t.element(find.byType(LoginScreen)))!.loginTabRegister));
    await t.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 5; i++) { await t.pump(const Duration(milliseconds: 50)); }
    final after = t.getTopLeft(find.byKey(const ValueKey('login_badge')));
    expect(after.dy, greaterThanOrEqualTo(before.dy));      // not compacted further for the longer Register form
  });
}
