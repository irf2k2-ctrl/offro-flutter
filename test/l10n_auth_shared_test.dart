// Phase J, batch 4: Authentication, onboarding and shared UI in English and Arabic.
// Needs the generated localizations (lib/l10n/gen): run `flutter gen-l10n` first.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/design/offro_states.dart';
import 'package:offro_user/core/l10n/l10n.dart';
import 'package:offro_user/core/phone/phone_country.dart';
import 'package:offro_user/core/phone/phone_input.dart';
import 'package:offro_user/l10n/gen/app_localizations_ar.dart';
import 'package:offro_user/l10n/gen/app_localizations_en.dart';
import 'package:offro_user/core/services/location_service.dart';
import 'package:offro_user/screens/location/location_access_card.dart';

Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: home),
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

  final enArb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
  final arArb = jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync()) as Map<String, dynamic>;
  const prefixes = ['auth', 'phone', 'countryName', 'locGate', 'locCard', 'splash', 'stateError', 'commonBack'];
  Iterable<String> batchKeys() => enArb.keys.where((k) => !k.startsWith('@') && prefixes.any(k.startsWith));
  Set<String> ph(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

  group('ARB files (authentication and shared keys)', () {
    test('keys exist in both languages with the same placeholders and a description', () {
      expect(batchKeys().length, greaterThan(45));
      for (final k in batchKeys()) {
        expect(arArb.containsKey(k), isTrue, reason: k);
        expect(ph(arArb[k] as String), ph(enArb[k] as String), reason: k);
        expect((enArb['@$k'] as Map)['description'], isNotEmpty, reason: k);
      }
    });

    test('every Arabic value is translated and uses Western digits only', () {
      final letters = RegExp(r'[\u0600-\u06FF]');
      final arabicIndic = RegExp(r'[\u0660-\u0669\u06F0-\u06F9]');
      for (final k in batchKeys()) {
        final v = arArb[k] as String;
        expect(letters.hasMatch(v), isTrue, reason: '$k is not translated');
        expect(arabicIndic.hasMatch(v), isFalse, reason: k);
        expect(v, v.trim(), reason: '$k has leading/trailing spaces');
      }
    });
  });

  group('English is exactly what these screens showed before', () {
    test('plain texts', () {
      expect(en.authEnterOtp4, 'Enter 4-digit OTP');
      expect(en.authOtpIncorrect, 'Incorrect OTP. Please try again.');
      expect(en.authOtpVerifyFailed, 'Unable to verify OTP right now. Please try again.');
      expect(en.authCodeSentSms, 'Code sent by SMS.');
      expect(en.authOtpResent, 'OTP resent successfully.');
      expect(en.authResendFailed, 'Resend failed.');
      expect(en.authOtpResendFailed, 'Unable to resend OTP right now. Please try again.');
      expect(en.authSettingUpAccount, 'Setting up your account...');
      expect(en.authLoadingBusinessData, 'Loading stores, products and activity...');
      expect(en.authEnterYourName, 'Enter your name');
      expect(en.authAcceptTermsRequired, 'Please tick the box to accept the Terms & Conditions and Privacy Policy and consent to WhatsApp updates from OffrO, to continue');
      expect(en.authAlreadyRegistered, 'This number is already registered. Please login.');
      expect(en.authNotRegistered, 'Number not registered. Please register first.');
      expect(en.authOtpSendFailed, 'Unable to send OTP right now. Please try again.');
      expect(en.authLoginFailed, 'Login failed — please try again.');
      expect(en.authAgreeTo, 'I agree to the');
      expect(en.authAnd, 'and');
      expect(en.authConsentWhatsApp, 'and consent to receive updates and promotional messages from OffrO via WhatsApp.');
      expect(en.authMerchantTermsTitle, 'Merchant Terms & Conditions');
      expect(en.authMerchantTermsEmpty, 'Merchant terms and conditions will be posted here.');
      expect(en.authAgreeMerchantTerms, 'I agree to the Merchant Terms');
      expect(en.authAcceptContinue, 'Accept & Continue');
      expect(en.phoneEnterNumber, 'Enter your mobile number');
      expect(en.phoneInvalid10, 'Enter a valid 10-digit mobile number');
      expect(en.countryNameIN, 'India');
      expect(en.countryNameJO, 'Jordan');
      expect(en.countryNameNP, 'Nepal');
      expect(en.countryNamePH, 'Philippines');
      expect(en.countryNameSA, 'Saudi Arabia');
      expect(en.locGateTitle, 'Allow location access');
      expect(en.locGateBody, 'OffrO needs your location to show nearby and relevant content.');
      expect(en.locGateBlockedMsg, 'Location permission is turned off for OffrO. You can allow it in app settings, or choose your city manually.');
      expect(en.locGateServiceOffMsg, 'Your device\'s location services are off. Turn them on, or choose your city manually.');
      expect(en.locGateDeniedMsg, 'Location permission wasn\'t allowed. You can still choose your city manually.');
      expect(en.locGateOpenSettings, 'Open app settings');
      expect(en.locGateAllow, 'Allow location');
      expect(en.locGateChooseManually, 'Choose city manually');
      expect(en.locCardChecking, 'Checking location…');
      expect(en.locCardServicesOff, 'Location services are off');
      expect(en.locCardServicesOffSub, 'Turn on your device location to see places near you');
      expect(en.locCardEnablePerm, 'Enable location permissions');
      expect(en.locCardEnablePermSub, 'for more relevant suggestions near you');
      expect(en.locCardBlocked, 'Location permission is blocked');
      expect(en.locCardBlockedSub, 'Allow location for OffrO in app settings');
      expect(en.locCardDetecting, 'Detecting your location…');
      expect(en.splashTagline, 'Discover · Save · Earn');
      expect(en.commonBack, 'Back');
      expect(en.stateErrorTitle, 'Couldn\'t load this');
      expect(en.stateErrorMessage, 'Check your connection and try again.');
    });

    test('texts with placeholders', () {
      expect(en.authPreparingDashboard('...'), 'Preparing your business dashboard...');
      expect(en.phoneInvalidCountry('Jordan'), 'Enter a valid Jordan mobile number');
      expect(en.locCardTapRetry('Could not detect.'), 'Could not detect. Tap to retry.');
    });

    test('the consent sentence is rebuilt exactly as before', () {
      expect('${en.authAgreeTo} ', 'I agree to the ');
      expect(' ${en.authAnd} ', ' and ');
      expect(' ${en.authConsentWhatsApp}', ' and consent to receive updates and promotional messages from OffrO via WhatsApp.');
    });
  });

  group('Arabic text', () {
    test('placeholders are filled and brand names stay Latin', () {
      expect(arL.authPreparingDashboard('...'), endsWith('...'));
      expect(arL.phoneInvalidCountry('الأردن'), contains('الأردن'));
      expect(arL.authAcceptTermsRequired, contains('OffrO'));
      expect(arL.authAcceptTermsRequired, contains('WhatsApp'));
      expect(arL.locCardTapRetry('x'), startsWith('x'));
    });

    test('the location gate settings hint is separate from the message text', () {
      // The gate shows the "Open app settings" button from a flag, not by searching the (translated) message text.
      final src = File('lib/screens/location/location_access_gate.dart').readAsStringSync();
      expect(src.contains("_msg.contains('app settings')"), isFalse);
      expect(src.contains('_showSettings'), isTrue);
    });
  });

  group('helpers', () {
    testWidgets('country names: English unchanged, Arabic for all five countries', (t) async {
      for (final c in kPhoneCountries) {
        expect(await run(t, enL, (ctx) => localizedCountryName(ctx, c)), c.name);
        expect(await run(t, ar, (ctx) => localizedCountryName(ctx, c)), isNot(c.name));
      }
      expect(await run(t, ar, (ctx) => localizedCountryName(ctx, kPhoneCountries.firstWhere((c) => c.iso == 'SA'))), 'المملكة العربية السعودية');
    });

    testWidgets('phone errors: the English message inside the result is unchanged, display follows the language', (t) async {
      const india = kDefaultPhoneCountry;
      final jordan = kPhoneCountries.firstWhere((c) => c.iso == 'JO');
      final empty = checkPhoneInput(india, '');
      final short = checkPhoneInput(india, '123');
      final bad = checkPhoneInput(jordan, '12345');
      expect(empty.message, 'Enter your mobile number');
      expect(short.message, 'Enter a valid 10-digit mobile number');
      expect(bad.message, 'Enter a valid Jordan mobile number');
      expect(await run(t, enL, (c) => localizedPhoneInputError(c, india, empty)), empty.message);
      expect(await run(t, enL, (c) => localizedPhoneInputError(c, india, short)), short.message);
      expect(await run(t, enL, (c) => localizedPhoneInputError(c, jordan, bad)), bad.message);
      expect(await run(t, ar, (c) => localizedPhoneInputError(c, india, empty)), arL.phoneEnterNumber);
      expect(await run(t, ar, (c) => localizedPhoneInputError(c, india, short)), arL.phoneInvalid10);
      expect(await run(t, ar, (c) => localizedPhoneInputError(c, jordan, bad)), arL.phoneInvalidCountry('الأردن'));
      final ok = checkPhoneInput(india, '9876543210');
      expect(await run(t, ar, (c) => localizedPhoneInputError(c, india, ok)), ok.message);
    });
  });

  group('widgets', () {
    testWidgets('error state: default texts follow the language, explicit texts are kept', (t) async {
      await t.pumpWidget(app(OffroErrorState(onRetry: () {})));
      expect(find.text("Couldn't load this"), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await t.pumpWidget(app(OffroErrorState(onRetry: () {}), locale: ar));
      expect(find.text(arL.stateErrorTitle), findsOneWidget);
      expect(find.text(arL.stateErrorMessage), findsOneWidget);
      expect(find.text(arL.locTryAgain), findsOneWidget);
      await t.pumpWidget(app(const OffroErrorState(title: 'Custom', message: null)));
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsNothing);
    });

    testWidgets('location card: texts in English and Arabic', (t) async {
      Widget card() => LocationAccessCard(access: LocationAccess.serviceOff, detecting: false, detectError: '', detected: null, onTap: () {});
      await t.pumpWidget(app(card()));
      expect(find.text('Location services are off'), findsOneWidget);
      expect(find.text('Turn on your device location to see places near you'), findsOneWidget);
      await t.pumpWidget(app(card(), locale: ar));
      expect(find.text(arL.locCardServicesOff), findsOneWidget);
      expect(find.text(arL.locCardServicesOffSub), findsOneWidget);
    });
  });

  // Ratchet: sentences migrated in this batch must not come back as hard-coded literals in the same file.
  group('no hard-coded copies of migrated text', () {
    String strip(String s) {
      final noBlock = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      return noBlock.split('\n').map((l) => l.replaceAll(RegExp(r'''(?<![:'"])//.*$'''), '')).join('\n');
    }

    int count(String code, String v) {
      final lit = v.replaceAll('\n', r'\n');
      return "'$lit'".allMatches(code).length + '"$lit"'.allMatches(code).length;
    }

    final guard = <String, List<String>>{
    'lib/screens/auth/login_screen.dart': [
      en.authEnterOtp4,
      en.authOtpIncorrect,
      en.authOtpVerifyFailed,
      en.authCodeSentSms,
      en.authOtpResent,
      en.authResendFailed,
      en.authOtpResendFailed,
      en.authSettingUpAccount,
      en.authLoadingBusinessData,
      en.authEnterYourName,
      en.authAcceptTermsRequired,
      en.authAlreadyRegistered,
      en.authNotRegistered,
      en.authOtpSendFailed,
      en.authLoginFailed,
      en.authMerchantTermsTitle,
      en.authMerchantTermsEmpty,
      en.authAgreeMerchantTerms,
      en.authAcceptContinue,
    ],
    'lib/screens/location/location_access_gate.dart': [
      en.locGateTitle,
      en.locGateBody,
      en.locGateServiceOffMsg,
      en.locGateDeniedMsg,
      en.locGateOpenSettings,
      en.locGateAllow,
      en.locGateChooseManually,
    ],
    'lib/screens/location/location_access_card.dart': [
      en.locCardChecking,
      en.locCardServicesOff,
      en.locCardServicesOffSub,
      en.locCardEnablePerm,
      en.locCardEnablePermSub,
      en.locCardBlocked,
      en.locCardBlockedSub,
      en.locCardDetecting,
    ],
    'lib/screens/splash/splash_screen.dart': [
      en.splashTagline,
    ],
    'lib/core/design/offro_states.dart': [
      en.stateErrorTitle,
      en.stateErrorMessage,
    ],
    };

    for (final entry in guard.entries) {
      test('${entry.key} has no hard-coded copy of its migrated text', () {
        final code = strip(File(entry.key).readAsStringSync());
        final found = <String>[];
        for (final v in entry.value) {
          if (count(code, v) > 0) found.add(v);
        }
        expect(found, isEmpty);
      });
    }
  });
}
