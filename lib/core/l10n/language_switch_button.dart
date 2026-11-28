// lib/core/l10n/language_switch_button.dart
//
// Compact language switch for the home header, shown next to the notification bell.
//   * English app  -> dark-green circle with a white Arabic letter  ع  ; tap switches to Arabic.
//   * Arabic app   -> dark-green circle with a white Latin letter   E  ; tap switches to English.
// It adds NO language logic of its own:
//   * whether Arabic is offered for the current country comes from the existing policy (allowedLanguageCodes: the published
//     country -> language mapping from the admin dashboard, active country = account, else device / login selection, else India);
//     no country is named here, and when Arabic is not allowed nothing at all is drawn;
//   * the switch itself is LocaleController.setLanguage, which updates the whole app (locale + RTL/LTR) at once and saves the choice.
import 'dart:async';

import 'package:flutter/material.dart';

import '../design/design.dart';
import 'language_policy.dart';
import 'locale_controller.dart';
import 'remote/remote_translation_service.dart';

/// Diameter of the round header buttons: the notification bell (customer home) and this language switch. One constant, so the two
/// can never drift apart.
const double kHeaderCircleSize = 40;

/// OffrO brand green used by the switch.
const Color kLanguageSwitchGreen = Color(0xFF3E5F55);

/// The language a tap on the switch moves to, or null when the switch must not be shown (Arabic is not allowed for the country).
/// Pure so it can be tested without a widget: [allowed] is the list from [allowedLanguageCodes].
String? languageSwitchTarget({required String current, required List<String> allowed}) {
  if (!allowed.contains('ar')) return null;
  return current == 'ar' ? 'en' : 'ar';
}

class LanguageSwitchButton extends StatefulWidget {
  const LanguageSwitchButton({super.key, this.size = kHeaderCircleSize, this.gapAfter = true});

  /// Whether to leave the 8 px gap on the trailing side. True next to the notification bell (customer home header); false where the
  /// button is the last item of the header (Merchant and Influencer home), so it sits flush with the screen gutter.
  final bool gapAfter;

  /// Diameter; the same as the header's notification bell ([kHeaderCircleSize]).
  final double size;

  @override
  State<LanguageSwitchButton> createState() => _LanguageSwitchButtonState();
}

class _LanguageSwitchButtonState extends State<LanguageSwitchButton> {
  @override
  void initState() {
    super.initState();
    // English users otherwise never contact the server, so look for the latest country -> language mapping (throttled, silent,
    // no-op when remote translations are off). The button appears / disappears by itself when the mapping changes.
    unawaited(RemoteTranslationService.instance.refreshCountries());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([LocaleController.instance, ActiveCountry.instance, RemoteTranslationService.instance]),
      builder: (context, _) {
        final current = LocaleController.instance.locale.languageCode;
        final target = languageSwitchTarget(current: current, allowed: allowedLanguageCodes());
        if (target == null) return const SizedBox.shrink();
        final toArabic = target == 'ar';
        return Padding(
          // the gap towards the bell (when there is one); directional, so it is correct in both LTR and RTL
          padding: EdgeInsetsDirectional.only(end: widget.gapAfter ? 8 : 0),
          child: Semantics(
            button: true,
            // language names are shown in their own language so they are understood whichever language is active
            label: toArabic ? 'العربية' : 'English',
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('language_switch'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(LocaleController.instance.setLanguage(target)),
              child: Container(
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: kLanguageSwitchGreen, shape: BoxShape.circle),
                child: Text(
                  toArabic ? 'ع' : 'E',
                  textScaler: TextScaler.noScaling, // a fixed-size glyph in a fixed-size circle: never overflows on large text settings
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: toArabic ? OffroFonts.arabic : OffroFonts.sans, // an Arabic-supporting font for ع
                    fontSize: toArabic ? 22 : 17,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
