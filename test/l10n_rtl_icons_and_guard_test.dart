// Phase I follow-up tests (no generated localizations needed):
//  1. directional custom icons (OffroIcons.chevron / back / arrow) mirror in right-to-left layouts and nothing else changes
//  2. guard: the migrated English strings must not reappear as hard-coded literals in the pilot screens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/design/offro_icons.dart';

Widget host(TextDirection d, Widget child) => Directionality(textDirection: d, child: Center(child: child));

Finder flip() => find.descendant(of: find.byType(OffroIcon), matching: find.byType(Transform));

void main() {
  group('directional icons', () {
    final directional = <String, OffroIconData>{
      'chevron': OffroIcons.chevron,
      'back': OffroIcons.back,
      'arrow': OffroIcons.arrow,
    };

    test('exactly the three directional glyphs are marked for mirroring', () {
      for (final e in directional.entries) {
        expect(e.value.mirrorInRtl, isTrue, reason: e.key);
      }
      final others = <String, OffroIconData>{
        'user': OffroIcons.user, 'home': OffroIcons.home, 'search': OffroIcons.search, 'check': OffroIcons.check,
        'heart': OffroIcons.heart, 'store': OffroIcons.store, 'phone': OffroIcons.phone, 'pin': OffroIcons.pin,
        'play': OffroIcons.play, 'share': OffroIcons.share, 'compass': OffroIcons.compass, 'bell': OffroIcons.bell,
      };
      for (final e in others.entries) {
        expect(e.value.mirrorInRtl, isFalse, reason: e.key);
      }
    });

    for (final e in directional.entries) {
      testWidgets('${e.key}: unchanged in English, flipped horizontally in Arabic', (t) async {
        await t.pumpWidget(host(TextDirection.ltr, OffroIcon(e.value, size: 24)));
        expect(flip(), findsNothing, reason: 'English (LTR) must be exactly as before');

        await t.pumpWidget(host(TextDirection.rtl, OffroIcon(e.value, size: 24)));
        expect(flip(), findsOneWidget);
        final m = t.widget<Transform>(flip()).transform;
        expect(m.entry(0, 0), -1.0, reason: 'mirrored on the x axis');
        expect(m.entry(1, 1), 1.0, reason: 'not flipped vertically');
        expect(t.getSize(find.byType(OffroIcon)), const Size(24, 24), reason: 'size is unchanged');
      });
    }

    testWidgets('non-directional icons are never flipped, in either direction', (t) async {
      for (final d in TextDirection.values) {
        await t.pumpWidget(host(d, Row(mainAxisSize: MainAxisSize.min, children: [
          OffroIcon(OffroIcons.user), OffroIcon(OffroIcons.home), OffroIcon(OffroIcons.check), OffroIcon(OffroIcons.play),
        ])));
        expect(flip(), findsNothing, reason: '$d');
      }
    });

    testWidgets('the icon is still drawn by the same painter and keeps its semantics', (t) async {
      await t.pumpWidget(host(TextDirection.rtl, OffroIcon(OffroIcons.chevron, size: 14, semanticLabel: 'next')));
      expect(find.descendant(of: find.byType(OffroIcon), matching: find.byType(CustomPaint)), findsWidgets);
      expect(find.bySemanticsLabel('next'), findsOneWidget);
    });

    testWidgets('without any Directionality ancestor nothing is mirrored and nothing throws', (t) async {
      // No Directionality widget anywhere above the icon (Center/SizedBox/CustomPaint do not need one).
      bool? ancestorFound;
      await t.pumpWidget(Center(
        child: Builder(builder: (context) {
          ancestorFound = Directionality.maybeOf(context) != null;
          return OffroIcon(OffroIcons.chevron, size: 24);
        }),
      ));
      expect(ancestorFound, isFalse, reason: 'test setup must really have no Directionality ancestor');
      expect(t.takeException(), isNull);
      expect(find.byType(OffroIcon), findsOneWidget);
      expect(flip(), findsNothing, reason: 'no ancestor means left-to-right behaviour: not mirrored');
    });
  });

  group('pilot screens contain no hard-coded copies of the migrated English text', () {
    const pilotFiles = [
      'lib/screens/auth/login_screen.dart',
      'lib/screens/onboarding/onboarding_screen.dart',
      'lib/screens/home/profile_tab.dart',
      'lib/core/phone/country_picker_sheet.dart',
      'lib/core/l10n/language_sheet.dart',
    ];

    /// Known, intentional exceptions: file -> keys whose English text may still appear as a literal there.
    ///  * onboarding slide text is the fallback DATA used when a slide image fails; it is mapped to l10n at display time.
    ///  * profile_tab: "OffrO member" is the display-name fallback for a signed-in user without a name. It is a name placeholder,
    ///    not a label; migrating it is Phase J.
    const allowed = <String, Set<String>>{
      'lib/screens/onboarding/onboarding_screen.dart': {
        'onboardingSlide1Title', 'onboardingSlide1Subtitle', 'onboardingSlide2Title',
        'onboardingSlide2Subtitle', 'onboardingSlide3Title', 'onboardingSlide3Subtitle',
      },
      'lib/screens/home/profile_tab.dart': {'profileMemberBadge'},
    };

    String stripComments(String s) {
      final noBlock = s.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      return noBlock.split('\n').map((l) => l.replaceAll(RegExp(r'''(?<![:'"])//.*$'''), '')).join('\n');
    }

    /// Keys whose English value appears as a quoted literal in [source]. Values with {placeholders} are skipped (they are
    /// composed at run time); comments are ignored.
    List<String> hardCoded(String source, Map<String, String> en) {
      final code = stripComments(source);
      final hits = <String>[];
      en.forEach((k, v) {
        if (v.contains('{')) return;
        final lit = v.replaceAll('\n', r'\n');
        if (code.contains("'$lit'") || code.contains('"$lit"')) hits.add(k);
      });
      return hits;
    }

    final arb = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map<String, dynamic>;
    final en = {for (final e in arb.entries) if (!e.key.startsWith('@')) e.key: e.value as String};

    test('the guard itself detects a hard-coded literal and ignores comments', () {
      expect(hardCoded("Text('Verify OTP')", en), contains('otpVerifyButton'));
      expect(hardCoded('Text("Continue as guest")', en), contains('loginGuest'));
      expect(hardCoded("// Text('Verify OTP')\n/// 'Skip' and \"Skip\"", en), isEmpty);
      expect(hardCoded('Text(context.l10n.otpVerifyButton)', en), isEmpty);
    });

    for (final f in pilotFiles) {
      test(f, () {
        final hits = hardCoded(File(f).readAsStringSync(), en).where((k) => !(allowed[f] ?? {}).contains(k)).toList();
        expect(hits, isEmpty, reason: '$f still hard-codes the English text of: $hits - use context.l10n instead');
      });
    }
  });
}
