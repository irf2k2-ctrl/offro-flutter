// lib/core/l10n/language_sheet.dart
//
// Language chooser used by Login/Onboarding (compact button) and Profile (row). Language names are always shown in their own
// language and script, so a user can find their language whichever language is active.
import 'dart:async';

import 'package:flutter/material.dart';

import '../design/design.dart';
import 'l10n.dart';
import 'language_policy.dart';
import 'locale_controller.dart';
import 'remote/remote_translation_service.dart';

/// The languages to list for [countryIso] (null = the active country: account, else device / login selection, else India). Strict
/// policy, see language_availability.dart: only languages the published mapping lists for the country, English always; English only
/// when the country or the mapping is unknown.
List<String> languageCodesForCountry(String? countryIso) => allowedLanguageCodes(countryIso: countryIso);

/// [countryIso] is the country the user is in or has selected; null uses the active country (see language_policy.dart).
Future<void> showLanguageSheet(BuildContext context, {String? countryIso}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _LanguageSheet(countryIso: countryIso),
  );
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet({this.countryIso});
  final String? countryIso;

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  @override
  void initState() {
    super.initState();
    final s = RemoteTranslationService.instance;
    s.addListener(_changed);
    // English users otherwise never contact the server, so look for the latest country mapping now (throttled, silent, no-op when
    // remote translations are off). The list below updates by itself if it changed.
    unawaited(s.refreshCountries());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RemoteTranslationService.instance.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = LocaleController.instance.locale.languageCode;
    final codes = languageCodesForCountry(widget.countryIso);
    String nameOf(String code) => code == 'ar' ? l.languageNameAr : l.languageNameEn;
    Widget option(String code, String name) => ListTile(
          key: ValueKey('language_option_$code'),
          title: Text(name, style: OffroText.cardTitle.copyWith(fontSize: 15)),
          trailing: current == code ? const Icon(Icons.check_rounded, color: OffroColors.primary) : null,
          onTap: () async {
            Navigator.of(context).pop();
            await LocaleController.instance.setLanguage(code);
          },
        );
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
          child: Text(l.languageSheetTitle, style: OffroText.cardTitle.copyWith(fontSize: 16)),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
          child: Text(l.languageSheetNote,
              style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: OffroColors.textMuted)),
        ),
        for (final code in codes) option(code, nameOf(code)),
        const SizedBox(height: 8),
      ]),
    );
  }
}

/// Small pill for the login / onboarding screens: shows the OTHER language's name and opens the chooser.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.onDark = false, this.countryIso, this.filled = false});
  final bool onDark;

  /// Login screen: the pill is filled with the same tan/brown (OffroColors.beige) as the Login | Register buttons. Behaviour is identical;
  /// only the colours differ, and the default (false) keeps every other screen exactly as it was.
  final bool filled;

  /// The selected country, when the screen has one (the login screen does); it narrows the languages the chooser offers.
  final String? countryIso;

  @override
  Widget build(BuildContext context) {
    // Rebuilds if the published country mapping arrives while the screen is open; hidden only when there is nothing to choose.
    return AnimatedBuilder(
      animation: Listenable.merge([RemoteTranslationService.instance, ActiveCountry.instance]),
      builder: (context, _) =>
          languageCodesForCountry(countryIso).length < 2 ? const SizedBox.shrink() : _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l = context.l10n;
    final isAr = LocaleController.instance.locale.languageCode == 'ar';
    final label = isAr ? l.languageNameEn : l.languageNameAr;
    final fg = onDark ? Colors.white : OffroColors.primary;
    return Semantics(
      button: true,
      label: l.languageButtonSemantics,
      child: GestureDetector(
        key: const ValueKey('language_button'),
        onTap: () => showLanguageSheet(context, countryIso: countryIso),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: filled ? OffroColors.beige : fg.withValues(alpha: .12),
            borderRadius: OffroRadii.pillRadius,
            border: Border.all(color: filled ? OffroColors.beige : fg.withValues(alpha: .25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.language_rounded, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
