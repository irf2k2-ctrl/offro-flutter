// OffrO app smoke test: the real app shell (MyApp from lib/main.dart) builds and shows the splash screen, with the right language
// and direction, without any exception. It replaces the default Flutter "counter" template test, which does not apply to OffrO.
//
// No network or platform plugin is used: SharedPreferences is mocked, remote translations are OFF in test builds (no
// ENABLE_REMOTE_TRANSLATIONS), and the screen is closed before the splash's 2.5 s minimum-display delay ends, so the app never
// navigates onwards (no login, onboarding or API call).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/l10n/locale_controller.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_service.dart';
import 'package:offro_user/main.dart';
import 'package:offro_user/screens/splash/splash_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocaleController.instance.resetForTest();
  });
  tearDown(() => LocaleController.instance.resetForTest());

  /// Closes the app and lets the splash's pending 2.5 s delay fire. The screen is already unmounted, so it does nothing further.
  Future<void> shutDown(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }

  testWidgets('OffrO launches in English and shows the splash screen', (t) async {
    await t.pumpWidget(const MyApp());
    await t.pump(const Duration(milliseconds: 100));

    expect(t.takeException(), isNull, reason: 'the app must build without an exception');
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Discover · Save · Earn'), findsOneWidget); // bundled English splash tagline
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('en'));
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(Directionality.of(t.element(find.byType(SplashScreen))), TextDirection.ltr);
    expect(RemoteTranslationService.instance.enabled, isFalse, reason: 'remote translations are off unless a build enables them');

    await shutDown(t);
  });

  testWidgets('OffrO launches in Arabic (right-to-left) when Arabic was chosen, using the bundled translations', (t) async {
    SharedPreferences.setMockInitialValues({'app_language': 'ar'});
    await LocaleController.instance.load();
    await t.pumpWidget(const MyApp());
    await t.pump(const Duration(milliseconds: 100));

    expect(t.takeException(), isNull);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('اكتشف · وفّر · اكسب'), findsOneWidget);
    expect(t.widget<MaterialApp>(find.byType(MaterialApp)).locale, const Locale('ar'));
    expect(Directionality.of(t.element(find.byType(SplashScreen))), TextDirection.rtl);

    await shutDown(t);
  });
}
