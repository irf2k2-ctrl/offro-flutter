// Phase E: tests for the phone input rules and device-country suggestion. Pure logic: no network, no platform channels, no OTP.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/phone/device_country.dart';
import 'package:offro_user/core/phone/phone_country.dart';
import 'package:offro_user/core/phone/phone_input.dart';

PhoneCountry c(String iso) => phoneCountryByIso(iso)!;

void main() {
  group('India keeps the existing rule', () {
    test('exactly 10 digits, sent as +91<digits>', () {
      final r = checkPhoneInput(c('IN'), '98765 43210');
      expect(r.ok, isTrue);
      expect(r.e164, '+919876543210');
    });
    test('wrong length keeps the existing message', () {
      for (final v in ['987654321', '98765432101', '12345']) {
        final r = checkPhoneInput(c('IN'), v);
        expect(r.ok, isFalse, reason: v);
        expect(r.message, 'Enter a valid 10-digit mobile number');
      }
    });
    test('empty keeps the existing message', () {
      final r = checkPhoneInput(c('IN'), '  ');
      expect(r.ok, isFalse);
      expect(r.error, PhoneInputError.empty);
      expect(r.message, 'Enter your mobile number');
    });
    test('lenient like before: any 10 digits pass (the server decides for Indian numbers)', () {
      expect(checkPhoneInput(c('IN'), '5551234567').ok, isTrue);
    });
    test('a leading 0 is NOT dropped for India (counts as typed, as before)', () {
      expect(checkPhoneInput(c('IN'), '09876543210').ok, isFalse);
    });
  });

  group('other countries use libphonenumber mobile rules', () {
    test('valid mobiles become E.164', () {
      expect(checkPhoneInput(c('JO'), '791234567').e164, '+962791234567');
      expect(checkPhoneInput(c('NP'), '9812345678').e164, '+9779812345678');
      expect(checkPhoneInput(c('PH'), '9171234567').e164, '+639171234567');
      expect(checkPhoneInput(c('SA'), '501234567').e164, '+966501234567');
    });
    test('a leading trunk 0 is accepted and removed', () {
      expect(checkPhoneInput(c('SA'), '0501234567').e164, '+966501234567');
      expect(checkPhoneInput(c('JO'), '0791234567').e164, '+962791234567');
      expect(checkPhoneInput(c('PH'), '09171234567').e164, '+639171234567');
      expect(checkPhoneInput(c('NP'), '09812345678').e164, '+9779812345678');
    });
    test('spaces and dashes are ignored; Arabic-Indic digits are converted', () {
      expect(checkPhoneInput(c('SA'), '50 123 4567').e164, '+966501234567');
      expect(checkPhoneInput(c('SA'), '٠٥٠١٢٣٤٥٦٧').e164, '+966501234567');
      expect(checkPhoneInput(c('SA'), '۰۵۰۱۲۳۴۵۶۷').e164, '+966501234567');
    });
    test('too short, landline and nonsense are rejected with a country-specific message', () {
      for (final t in [('SA', '123'), ('SA', '0112345678'), ('NP', '12345'), ('PH', '1234'), ('JO', '999')]) {
        final r = checkPhoneInput(c(t.$1), t.$2);
        expect(r.ok, isFalse, reason: '${t.$1} ${t.$2}');
        expect(r.error, PhoneInputError.invalid);
        expect(r.message, 'Enter a valid ${c(t.$1).name} mobile number');
      }
    });
    test('an Indian-looking number is not accepted for another country just because the digits fit', () {
      expect(checkPhoneInput(c('SA'), '9876543210').ok, isFalse);
    });
    test('empty gives the empty error', () {
      expect(checkPhoneInput(c('SA'), '').error, PhoneInputError.empty);
    });
  });

  test('input length limits: India stays 10, others allow the optional leading 0', () {
    expect(maxPhoneInputLength(c('IN')), 10);
    expect(maxPhoneInputLength(c('SA')), 10);
    expect(maxPhoneInputLength(c('JO')), 10);
    expect(maxPhoneInputLength(c('NP')), 11);
    expect(maxPhoneInputLength(c('PH')), 11);
  });

  test('hints exist for every country', () {
    expect(phoneInputHint(c('IN')), '98765 43210');
    for (final k in kPhoneCountries) {
      expect(phoneInputHint(k).isNotEmpty, isTrue);
    }
  });

  group('PhoneDigitsFormatter', () {
    TextEditingValue run(int max, String typed) =>
        PhoneDigitsFormatter(max).formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: typed, selection: TextSelection.collapsed(offset: typed.length)));
    test('drops non-digits, converts Arabic digits, caps the length', () {
      expect(run(10, '98a76-54 3210').text, '9876543210');
      expect(run(10, '٩٨٧٦٥٤٣٢١٠').text, '9876543210');
      expect(run(10, '98765432101234').text, '9876543210');
      expect(run(10, '98765').text, '98765');
    });
    test('the cursor stays inside the text', () {
      final v = run(5, '1234567890');
      expect(v.text, '12345');
      expect(v.selection.end, 5);
    });
  });

  group('splitE164 (prefilling a stored number)', () {
    test('splits each supported country', () {
      expect(splitE164('+966501234567')!.country.iso, 'SA');
      expect(splitE164('+966501234567')!.national, '501234567');
      expect(splitE164('+919876543210')!.country.iso, 'IN');
      expect(splitE164('+919876543210')!.national, '9876543210');
      expect(splitE164('+9779812345678')!.country.iso, 'NP');
      expect(splitE164('+962791234567')!.country.iso, 'JO');
      expect(splitE164('+639171234567')!.country.iso, 'PH');
    });
    test('plain 10-digit, empty, null and unsupported return null', () {
      expect(splitE164('9876543210'), isNull);
      expect(splitE164(''), isNull);
      expect(splitE164(null), isNull);
      expect(splitE164('+14155550123'), isNull);
    });
  });

  group('detectInitialCountry (no permission, SIM then locale then India)', () {
    Future<DeviceCountryCodes> Function() sim(String? s, [String? n]) => () async => DeviceCountryCodes(sim: s, network: n);
    test('SIM country wins', () async {
      final r = await detectInitialCountry(readNative: sim('sa'), localeRegion: () => 'IN');
      expect(r.country.iso, 'SA');
      expect(r.source, CountrySource.sim);
    });
    test('network country is next', () async {
      final r = await detectInitialCountry(readNative: sim(null, 'NP'), localeRegion: () => 'IN');
      expect(r.country.iso, 'NP');
      expect(r.source, CountrySource.network);
    });
    test('an unsupported SIM (tourist) falls through to the locale region', () async {
      final r = await detectInitialCountry(readNative: sim('US'), localeRegion: () => 'JO');
      expect(r.country.iso, 'JO');
      expect(r.source, CountrySource.locale);
    });
    test('nothing available gives India', () async {
      final r = await detectInitialCountry(readNative: sim(null), localeRegion: () => null);
      expect(r.country.iso, 'IN');
      expect(r.source, CountrySource.defaultIndia);
    });
    test('a failing native read or locale lookup never throws and gives India', () async {
      final r = await detectInitialCountry(
        readNative: () async => throw PlatformException(code: 'x'),
        localeRegion: () => throw StateError('x'),
      );
      expect(r.country.iso, 'IN');
    });
  });

  group('Saudi mobile numbering plan (QA issue 3)', () {
    test('every mobile prefix 50, 53-59 is accepted and sent as +966', () {
      for (final n in ['501234567', '531234567', '541234567', '551234567', '561234567', '571234567', '581234567', '591234567', '0501234567', '50 123 4567']) {
        final r = checkPhoneInput(c('SA'), n);
        expect(r.ok, isTrue, reason: n);
        expect(r.e164, startsWith('+966'), reason: n);
      }
    });
    test('numbers outside the numbering plan are rejected', () {
      for (final n in ['521234567', '5012345', '50123456789', '401234567', '579912345']) {
        expect(checkPhoneInput(c('SA'), n).ok, isFalse, reason: n);
      }
    });
    test('India is unchanged', () {
      expect(checkPhoneInput(c('IN'), '9876543210').e164, '+919876543210');
    });
  });
}
