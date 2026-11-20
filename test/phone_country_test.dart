// Phase C: tests for the reusable country foundation (pure logic plus the picker widgets). No network, no platform channels.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/phone/country_picker_sheet.dart';
import 'package:offro_user/core/phone/phone_country.dart';

void main() {
  test('exactly five countries, alphabetical, with the right flags and calling codes', () {
    expect(kPhoneCountries.map((c) => c.name).toList(), ['India', 'Jordan', 'Nepal', 'Philippines', 'Saudi Arabia']);
    final names = kPhoneCountries.map((c) => c.name).toList();
    expect(names, [...names]..sort());
    expect(kPhoneCountries.map((c) => c.dialLabel).toList(), ['+91', '+962', '+977', '+63', '+966']);
    expect(kPhoneCountries.map((c) => c.iso).toList(), ['IN', 'JO', 'NP', 'PH', 'SA']);
    for (final c in kPhoneCountries) {
      expect(c.flag.isNotEmpty, isTrue);
    }
    expect(kDefaultPhoneCountry, kPhoneCountries.first); // India
  });

  test('lookup by ISO code and by calling code', () {
    expect(phoneCountryByIso('sa')?.dial, '966');
    expect(phoneCountryByIso(' NP ')?.name, 'Nepal');
    expect(phoneCountryByIso('US'), isNull);
    expect(phoneCountryByIso(null), isNull);
    expect(phoneCountryByDial('+962')?.iso, 'JO');
    expect(phoneCountryByDial('63')?.iso, 'PH');
    expect(phoneCountryByDial('1'), isNull);
  });

  test('suggestion order is SIM, network, IP, locale, then India', () {
    expect(suggestCountry(simIso: 'sa', networkIso: 'np', ipIso: 'jo', localeRegion: 'ph').country.iso, 'SA');
    expect(suggestCountry(simIso: 'sa').source, CountrySource.sim);
    expect(suggestCountry(networkIso: 'np', ipIso: 'jo').country.iso, 'NP');
    expect(suggestCountry(networkIso: 'np').source, CountrySource.network);
    expect(suggestCountry(ipIso: 'jo', localeRegion: 'ph').country.iso, 'JO');
    expect(suggestCountry(ipIso: 'jo').source, CountrySource.ip);
    expect(suggestCountry(localeRegion: 'ph').country.iso, 'PH');
    expect(suggestCountry(localeRegion: 'ph').source, CountrySource.locale);
    final none = suggestCountry();
    expect(none.country.iso, 'IN');
    expect(none.source, CountrySource.defaultIndia);
  });

  test('unsupported or empty sources are skipped, and the next usable source wins', () {
    expect(suggestCountry(simIso: 'US', networkIso: '', ipIso: 'SA').country.iso, 'SA'); // a tourist SIM does not force India
    expect(suggestCountry(simIso: 'US', networkIso: 'GB', ipIso: 'FR', localeRegion: 'DE').country.iso, 'IN');
    expect(suggestCountry(simIso: 'US').source, CountrySource.defaultIndia);
  });

  test('national digits: digits only, Arabic digits converted, one leading zero removed, nothing truncated', () {
    expect(nationalDigits('05 0123-4567'), '501234567');
    expect(nationalDigits('9876543210'), '9876543210');
    expect(nationalDigits('٥٠١٢٣٤٥٦٧'), '501234567'); // Arabic-Indic digits
    expect(nationalDigits('۵۰۱'), '501'); // Extended Arabic-Indic digits
    expect(nationalDigits('0'), '');
    expect(nationalDigits('12345678901234567890').length, 20); // no fixed-length assumption
  });

  test('E.164 formatting uses the country calling code, not a fixed +91', () {
    final sa = phoneCountryByIso('SA')!;
    final np = phoneCountryByIso('NP')!;
    final inn = phoneCountryByIso('IN')!;
    expect(toE164(sa, '0501234567'), '+966501234567');
    expect(toE164(np, '9812345678'), '+9779812345678');
    expect(toE164(inn, '9812345678'), '+919812345678');
    expect(toE164(np, '9812345678') == toE164(inn, '9812345678'), isFalse); // same digits, different countries
  });

  testWidgets('picker lists the countries alphabetically and returns the tapped one', (tester) async {
    PhoneCountry? chosen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await showCountryPickerSheet(context, selected: kDefaultPhoneCountry),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final order = [for (final c in kPhoneCountries) tester.getTopLeft(find.byKey(ValueKey('country_${c.iso}'))).dy];
    expect(order, [...order]..sort());
    expect(find.text('Saudi Arabia'), findsOneWidget);
    expect(find.text('+966'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget); // India is marked as selected

    await tester.tap(find.byKey(const ValueKey('country_JO')));
    await tester.pumpAndSettle();
    expect(chosen?.iso, 'JO');
  });

  testWidgets('country code button shows flag and code and reports a change', (tester) async {
    var current = kDefaultPhoneCountry;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => CountryCodeButton(
            country: current,
            onChanged: (c) => setState(() => current = c),
          ),
        ),
      ),
    ));
    expect(find.text('+91'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('country_code_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('country_SA')));
    await tester.pumpAndSettle();
    expect(current.iso, 'SA');
    expect(find.text('+966'), findsOneWidget);
  });
}
