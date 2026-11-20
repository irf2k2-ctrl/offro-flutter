// lib/core/phone/phone_input.dart
// Phase E: client-side phone input rules for the login / registration / influencer screens.
//
// India keeps the app's existing rule exactly (any 10 digits; the server stays lenient for Indian numbers).
// Every other supported country is validated with libphonenumber metadata (package phone_numbers_parser): the number must be a
// valid MOBILE number of that country. The server validates again; this only gives instant, specific feedback.

import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import 'phone_country.dart';

enum PhoneInputError { empty, invalid }

class PhoneInputResult {
  const PhoneInputResult.ok(this.e164)
      : error = null,
        message = '';
  const PhoneInputResult.fail(this.error, this.message) : e164 = '';

  final String e164; // '+<dial><national>' when ok
  final PhoneInputError? error;
  final String message; // user-facing text when not ok

  bool get ok => error == null;
}

/// 0-9 only. Arabic-Indic and Extended Arabic-Indic digits become Western digits; everything else is dropped. Unlike
/// [nationalDigits] a leading 0 is KEPT (India's existing rule counts exactly what was typed).
String westernDigits(String raw) {
  final b = StringBuffer();
  for (final r in raw.runes) {
    if (r >= 0x30 && r <= 0x39) {
      b.writeCharCode(r);
    } else if (r >= 0x0660 && r <= 0x0669) {
      b.writeCharCode(0x30 + (r - 0x0660));
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      b.writeCharCode(0x30 + (r - 0x06F0));
    }
  }
  return b.toString();
}

/// Most characters worth allowing in the field. India: exactly the existing 10. Others: the longest national number
/// plus the optional leading 0 people type (05xxxxxxxx).
int maxPhoneInputLength(PhoneCountry c) {
  switch (c.iso) {
    case 'IN':
      return 10;
    case 'JO':
      return 10;
    case 'NP':
      return 11;
    case 'PH':
      return 11;
    case 'SA':
      return 10;
    default:
      return 15;
  }
}

/// Placeholder text for the field.
String phoneInputHint(PhoneCountry c) {
  switch (c.iso) {
    case 'JO':
      return '79 123 4567';
    case 'NP':
      return '98 1234 5678';
    case 'PH':
      return '917 123 4567';
    case 'SA':
      return '50 123 4567';
    default:
      return '98765 43210';
  }
}

/// Validates what the user typed for [country].
PhoneInputResult checkPhoneInput(PhoneCountry country, String raw) {
  if (westernDigits(raw).isEmpty) {
    return const PhoneInputResult.fail(PhoneInputError.empty, 'Enter your mobile number');
  }
  if (country.iso == 'IN') {
    // Existing Indian rule, unchanged: exactly 10 digits, sent as +91<digits>.
    final d = westernDigits(raw);
    if (d.length != 10) {
      return const PhoneInputResult.fail(PhoneInputError.invalid, 'Enter a valid 10-digit mobile number');
    }
    return PhoneInputResult.ok('+91$d');
  }
  final e164 = toE164(country, raw);
  var valid = false;
  try {
    final p = PhoneNumber.parse(e164);
    valid = p.countryCode.toString() == country.dial && p.isValid(type: PhoneNumberType.mobile);
  } catch (_) {
    valid = false;
  }
  if (!valid) {
    return PhoneInputResult.fail(PhoneInputError.invalid, 'Enter a valid ${country.name} mobile number');
  }
  return PhoneInputResult.ok(e164);
}

/// A stored '+<dial><national>' split back into its supported country and national digits, or null.
class SplitPhone {
  const SplitPhone(this.country, this.national);
  final PhoneCountry country;
  final String national;
}

SplitPhone? splitE164(String? stored) {
  final s = (stored ?? '').trim();
  if (!s.startsWith('+')) return null;
  final d = westernDigits(s);
  PhoneCountry? best;
  for (final c in kPhoneCountries) {
    if (d.startsWith(c.dial) && (best == null || c.dial.length > best.dial.length)) best = c;
  }
  if (best == null) return null;
  return SplitPhone(best, d.substring(best.dial.length));
}

/// Keeps only digits (Arabic digits are converted to 0-9) and caps the length. Used for every phone field.
class PhoneDigitsFormatter extends TextInputFormatter {
  PhoneDigitsFormatter(this.maxLength);
  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var t = westernDigits(newValue.text);
    if (t.length > maxLength) t = t.substring(0, maxLength);
    if (t == newValue.text) return newValue;
    final end = newValue.selection.end;
    final offset = (end < 0 || end > t.length) ? t.length : end;
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: offset));
  }
}
