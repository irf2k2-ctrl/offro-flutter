// lib/core/phone/country_picker_sheet.dart
// Phase C: reusable country selector widgets. NOT wired into any screen yet (login and registration are untouched).
//
// Shows flag, country name and international dialing code for the five supported countries, alphabetically.
// Layout uses start/end (directional) spacing so it mirrors correctly when Arabic RTL is added later, and the dialing
// code is kept left-to-right inside an RTL layout.

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'phone_country.dart';
import '../l10n/l10n.dart';

/// Opens a bottom sheet with the country list and returns the chosen country, or null when dismissed.
Future<PhoneCountry?> showCountryPickerSheet(
  BuildContext context, {
  PhoneCountry? selected,
  String? title,
  List<PhoneCountry> countries = kPhoneCountries,
}) {
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => CountryPickerSheet(selected: selected, title: title, countries: countries),
  );
}

class CountryPickerSheet extends StatelessWidget {
  const CountryPickerSheet({
    super.key,
    this.selected,
    this.title,
    this.countries = kPhoneCountries,
  });

  final PhoneCountry? selected;
  /// null = the localized default ("Select country").
  final String? title;
  final List<PhoneCountry> countries;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 20, end: 20, bottom: 8),
            child: Text(title ?? context.l10n.countryPickerTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in countries)
                  ListTile(
                    key: ValueKey('country_${c.iso}'),
                    leading: Text(c.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(localizedCountryName(context, c)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(c.dialLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        if (selected == c) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_rounded, size: 20),
                        ],
                      ],
                    ),
                    onTap: () => Navigator.of(context).pop(c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact "flag +code v" button to place in front of a phone field. Tapping it opens the picker.
class CountryCodeButton extends StatelessWidget {
  const CountryCodeButton({super.key, required this.country, required this.onChanged, this.enabled = true});

  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('country_code_button'),
      onTap: !enabled
          ? null
          : () async {
              final picked = await showCountryPickerSheet(context, selected: country);
              if (picked != null && picked != country) onChanged(picked);
            },
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 8, top: 12, bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(country.dialLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}
