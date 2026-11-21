// Phase K: how remote overrides plug into the app's localization (delegate, offroNoContext), RTL, English, and the build-flag safety.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offro_user/core/l10n/l10n.dart';
import 'package:offro_user/core/l10n/locale_controller.dart';
import 'package:offro_user/core/l10n/remote/generated/app_localizations_ar_remote.dart';
import 'package:offro_user/core/l10n/remote/generated/remote_l10n_schema.dart';
import 'package:offro_user/core/l10n/remote/remote_localizations.dart';
import 'package:offro_user/core/l10n/remote/remote_overrides.dart';
import 'package:offro_user/core/l10n/remote/remote_template.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_config.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_service.dart';
import 'package:offro_user/l10n/gen/app_localizations_ar.dart';
import 'package:offro_user/l10n/gen/app_localizations_en.dart';

const String stagingUrl = 'https://offro-backend-staging-d375.up.railway.app';
const String productionLikeUrl =
    'https://offro-backend-production.up.railway.app';

RemoteOverrides ov(Map<String, String> m, {int version = 1}) => RemoteOverrides(
    lang: 'ar',
    version: version,
    hash: version.toString().padLeft(64, '0'),
    strings: m);

/// A MaterialApp wired like main.dart: it follows [locale] and the remote delegate.
Widget app(Widget home,
        {required Locale locale, required RemoteOverrides overrides}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        RemoteAwareLocalizationsDelegate(overrides),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

class Probe extends StatelessWidget {
  const Probe({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(context.l10n.otpEyebrow, key: const Key('plain')),
        Text(context.l10n.otpSentTo('+962791234567'), key: const Key('param')),
        Text(Directionality.of(context).name, key: const Key('dir')),
      ]);
}

String textOf(WidgetTester t, String key) =>
    (t.widget(find.byKey(Key(key))) as Text).data!;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocaleController.instance.resetForTest();
  });

  const plain = 'otpEyebrow'; // a getter
  const withParam =
      'otpSentTo'; // otpSentTo(String phone), bundled text has {phone}

  group('generated override layer', () {
    test(
        'plain key: remote text wins; missing key falls back to bundled Arabic',
        () {
      final l = AppLocalizationsArRemote({plain: 'REMOTE'});
      expect(l.otpEyebrow, 'REMOTE');
      expect(l.otpTitleLead, AppLocalizationsAr().otpTitleLead);
    });
    test(
        'placeholder text keeps its argument; without an override the bundled text is used',
        () {
      expect(
          AppLocalizationsArRemote({withParam: 'to {phone}!'}).otpSentTo('123'),
          'to 123!');
      expect(AppLocalizationsArRemote({}).otpSentTo('123'),
          AppLocalizationsAr().otpSentTo('123'));
    });
    test('an argument that looks like a placeholder is not expanded again', () {
      expect(fillRemoteTemplate('x {a} y', {'a': '{b}', 'b': 'NO'}), 'x {b} y');
      expect(fillRemoteTemplate('x {missing}', {}), 'x {missing}');
    });
    test('the locale stays Arabic',
        () => expect(AppLocalizationsArRemote({}).localeName, 'ar'));
  });

  group('buildAppLocalizations', () {
    test(
        'Arabic + overrides -> remote layer; no overrides -> exactly the bundled class',
        () {
      expect(
          buildAppLocalizations(const Locale('ar'), ov({plain: 'R'}))
              .otpEyebrow,
          'R');
      expect(buildAppLocalizations(const Locale('ar'), RemoteOverrides.empty),
          isA<AppLocalizationsAr>());
      expect(buildAppLocalizations(const Locale('ar'), RemoteOverrides.empty),
          isNot(isA<AppLocalizationsArRemote>()));
    });
    test('16. English is never affected, even if overrides are passed', () {
      final en = buildAppLocalizations(const Locale('en'), ov({plain: 'R'}));
      expect(en, isA<AppLocalizationsEn>());
      expect(en.otpEyebrow, AppLocalizationsEn().otpEyebrow);
      expect(en.otpSentTo('1'), AppLocalizationsEn().otpSentTo('1'));
    });
    test(
        'offroNoContext follows the language and, when the service is off, the bundled text',
        () {
      expect(offroNoContext.otpEyebrow, AppLocalizationsEn().otpEyebrow);
      LocaleController.instance.setLanguage('ar');
      expect(offroNoContext.otpEyebrow, AppLocalizationsAr().otpEyebrow);
    });
  });

  group('delegate', () {
    test('supports exactly the same locales as the generated delegate', () {
      const d = RemoteAwareLocalizationsDelegate(RemoteOverrides.empty);
      for (final l in [
        const Locale('en'),
        const Locale('ar'),
        const Locale('fr'),
        const Locale('ar', 'SA')
      ]) {
        expect(d.isSupported(l), AppLocalizations.delegate.isSupported(l),
            reason: '$l');
      }
    });
    test('reloads only when the override snapshot changes', () {
      final a = RemoteAwareLocalizationsDelegate(ov({plain: 'R'}));
      expect(a.shouldReload(RemoteAwareLocalizationsDelegate(ov({plain: 'R'}))),
          isFalse);
      expect(
          a.shouldReload(
              RemoteAwareLocalizationsDelegate(ov({plain: 'R'}, version: 2))),
          isTrue);
      expect(
          a.shouldReload(
              const RemoteAwareLocalizationsDelegate(RemoteOverrides.empty)),
          isTrue);
    });
    test(
        'the delegate type is the app localizations',
        () => expect(
            const RemoteAwareLocalizationsDelegate(RemoteOverrides.empty).type,
            AppLocalizations));
    test(
        'a build without remote translations installs the plain generated delegate (production unchanged)',
        () {
      final off = RemoteTranslationService(enabled: false);
      expect(
          identical(appLocalizationsDelegate(service: off, languageCode: 'ar'),
              AppLocalizations.delegate),
          isTrue);
      off.dispose();
      final on = RemoteTranslationService(enabled: true, baseUrl: stagingUrl);
      expect(appLocalizationsDelegate(service: on, languageCode: 'ar'),
          isA<RemoteAwareLocalizationsDelegate>());
      on.dispose();
    });
    test(
        'English gets an empty snapshot even when the service holds Arabic overrides',
        () {
      final on = RemoteTranslationService(enabled: true, baseUrl: stagingUrl);
      expect(
          (appLocalizationsDelegate(service: on, languageCode: 'en')
                  as RemoteAwareLocalizationsDelegate)
              .overrides
              .isEmpty,
          isTrue);
      on.dispose();
    });
  });

  group('widgets', () {
    testWidgets('2. Arabic shows remote text, keeps RTL, placeholders filled',
        (t) async {
      await t.pumpWidget(app(const Probe(),
          locale: const Locale('ar'),
          overrides: ov({plain: 'REMOTE', withParam: 'to {phone}!'})));
      await t.pump();
      expect(textOf(t, 'plain'), 'REMOTE');
      expect(textOf(t, 'param'), 'to +962791234567!');
      expect(textOf(t, 'dir'), 'rtl');
    });
    testWidgets('15. Arabic is right-to-left with and without overrides',
        (t) async {
      for (final o in [
        RemoteOverrides.empty,
        ov({plain: 'R'})
      ]) {
        await t.pumpWidget(
            app(const Probe(), locale: const Locale('ar'), overrides: o));
        await t.pump();
        expect(textOf(t, 'dir'), 'rtl');
      }
    });
    testWidgets('16. English stays left-to-right and unchanged', (t) async {
      await t.pumpWidget(app(const Probe(),
          locale: const Locale('en'), overrides: ov({plain: 'REMOTE'})));
      await t.pump();
      expect(textOf(t, 'plain'), AppLocalizationsEn().otpEyebrow);
      expect(textOf(t, 'dir'), 'ltr');
    });
    testWidgets('missing and rejected keys show the bundled Arabic', (t) async {
      await t.pumpWidget(app(const Probe(),
          locale: const Locale('ar'), overrides: ov({'otpTitleLead': 'X'})));
      await t.pump();
      expect(textOf(t, 'plain'), AppLocalizationsAr().otpEyebrow);
      expect(
          textOf(t, 'param'), AppLocalizationsAr().otpSentTo('+962791234567'));
    });
    testWidgets(
        '13. kill switch / new version swaps the text live, without a restart or an inconsistent state',
        (t) async {
      final notifier =
          ValueNotifier<RemoteOverrides>(ov({plain: 'V1'}, version: 1));
      await t.pumpWidget(ValueListenableBuilder<RemoteOverrides>(
        valueListenable: notifier,
        builder: (_, o, __) =>
            app(const Probe(), locale: const Locale('ar'), overrides: o),
      ));
      await t.pump();
      expect(textOf(t, 'plain'), 'V1');
      notifier.value = ov({plain: 'V2'}, version: 2);
      await t.pump();
      expect(textOf(t, 'plain'), 'V2');
      notifier.value = RemoteOverrides.empty; // kill switch
      await t.pump();
      expect(textOf(t, 'plain'), AppLocalizationsAr().otpEyebrow);
      expect(textOf(t, 'dir'), 'rtl');
      notifier.value = ov({plain: 'V3'}, version: 3); // kill switch off again
      await t.pump();
      expect(textOf(t, 'plain'), 'V3');
    });
  });

  group('17. production build flag safety', () {
    test('default is OFF in a build made without the flag (this test run)', () {
      expect(kEnableRemoteTranslations, isFalse);
      expect(remoteTranslationsAllowed(), isFalse);
      expect(RemoteTranslationService.instance.enabled, isFalse);
      expect(
          RemoteTranslationService.instance.overridesFor('ar').isEmpty, isTrue);
    });
    test(
        'the flag alone is not enough: only the exact staging backend activates it',
        () {
      expect(
          remoteTranslationsAllowed(flag: true, baseUrl: stagingUrl), isTrue);
      for (final url in [
        '',
        '   ',
        productionLikeUrl,
        'https://offro-backend-staging-d375.up.railway.app.evil.example',
        'http://offro-backend-staging-d375.up.railway.app',
        'https://user@offro-backend-staging-d375.up.railway.app',
        'https://offro-backend-staging-d375.up.railway.app:8443',
        'https://evil.example/offro-backend-staging-d375.up.railway.app',
        'not a url',
      ]) {
        expect(remoteTranslationsAllowed(flag: true, baseUrl: url), isFalse,
            reason: url);
      }
    });
    test('without the flag nothing activates, not even on the staging backend',
        () {
      expect(
          remoteTranslationsAllowed(flag: false, baseUrl: stagingUrl), isFalse);
      expect(remoteTranslationsAllowed(flag: false, baseUrl: productionLikeUrl),
          isFalse);
    });
  });

  group('generated files match the bundled localizations', () {
    final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    final keys = {
      for (final e in en.entries)
        if (!e.key.startsWith('@')) e.key: e.value as String
    };
    final ph = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');

    test('the schema has exactly the ARB keys with exactly their placeholders',
        () {
      expect(kRemoteL10nSchema.keys.toSet(), keys.keys.toSet());
      for (final e in keys.entries) {
        final found = ph.allMatches(e.value).map((m) => m.group(1)!).toSet();
        expect(kRemoteL10nSchema[e.key]!.toSet(), found, reason: e.key);
        expect(kRemoteL10nSchema[e.key]!.length, found.length,
            reason: '${e.key}: no duplicates');
      }
    });
    test(
        'the override class overrides every key (re-run tools/gen_remote_l10n.py if this fails)',
        () {
      final src = File(
              'lib/core/l10n/remote/generated/app_localizations_ar_remote.dart')
          .readAsStringSync();
      expect(RegExp(r'^  @override$', multiLine: true).allMatches(src).length,
          keys.length);
      for (final k in keys.keys) {
        expect(src.contains("_overrides['$k']"), isTrue, reason: k);
      }
    });
  });
}
