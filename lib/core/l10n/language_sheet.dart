// lib/core/l10n/language_sheet.dart
//
// Language chooser used by Login/Onboarding (compact button) and Profile (row). Language names are always shown in their own
// language and script, so a user can find their language whichever language is active.
import 'package:flutter/material.dart';

import '../design/design.dart';
import 'l10n.dart';
import 'locale_controller.dart';

Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = LocaleController.instance.locale.languageCode;
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
        option('en', l.languageNameEn),
        option('ar', l.languageNameAr),
        const SizedBox(height: 8),
      ]),
    );
  }
}

/// Small pill for the login / onboarding screens: shows the OTHER language's name and opens the chooser.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isAr = LocaleController.instance.locale.languageCode == 'ar';
    final label = isAr ? l.languageNameEn : l.languageNameAr;
    final fg = onDark ? Colors.white : OffroColors.primary;
    return Semantics(
      button: true,
      label: l.languageButtonSemantics,
      child: GestureDetector(
        key: const ValueKey('language_button'),
        onTap: () => showLanguageSheet(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: fg.withValues(alpha: .12),
            borderRadius: OffroRadii.pillRadius,
            border: Border.all(color: fg.withValues(alpha: .25)),
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
