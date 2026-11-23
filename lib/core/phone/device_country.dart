// lib/core/phone/device_country.dart
// Phase E: picks the country to PRE-SELECT on the phone screens. The user can always change it.
//
// Order: SIM country, network country (both read natively on Android through TelephonyManager, which needs NO permission),
// then the device locale region, then India. IP-based detection is deliberately not part of this phase.
// Nothing here is sent anywhere and nothing asks for READ_PHONE_STATE or any other permission.

import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:flutter/services.dart';

import 'phone_country.dart';

const MethodChannel _kChannel = MethodChannel('com.offro.app/device_country');

/// Raw ISO codes from the device. Either may be null (no SIM, tablet, unsupported platform, error).
class DeviceCountryCodes {
  const DeviceCountryCodes({this.sim, this.network});
  final String? sim;
  final String? network;
}

Future<DeviceCountryCodes> _readNative() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return const DeviceCountryCodes();
  try {
    final m = await _kChannel
        .invokeMapMethod<String, String?>('getCountryIsos')
        .timeout(const Duration(seconds: 1));
    String? clean(String? v) {
      final s = (v ?? '').trim();
      return s.length == 2 ? s : null;
    }
    return DeviceCountryCodes(sim: clean(m?['sim']), network: clean(m?['network']));
  } catch (_) {
    return const DeviceCountryCodes(); // channel missing, timeout or any error: fall back silently
  }
}

/// The region of the device locale. The device can list several locales (for example English (United States) first and Hindi (India)
/// second): the first one whose region is a supported country wins, otherwise the primary locale's region (which then simply is not
/// a supported country, so the next source / India is used). This is the only source iOS has (no SIM / network channel there).
@visibleForTesting
String? regionFromLocales(List<Locale> locales, Locale primary) {
  for (final l in locales) {
    if (phoneCountryByIso(l.countryCode) != null) return l.countryCode;
  }
  return primary.countryCode;
}

String? _localeRegion() {
  try {
    final d = PlatformDispatcher.instance;
    return regionFromLocales(d.locales, d.locale);
  } catch (_) {
    return null;
  }
}

/// The country to pre-select. Never throws. [readNative] and [localeRegion] exist so tests can supply fakes.
Future<CountrySuggestion> detectInitialCountry({
  Future<DeviceCountryCodes> Function()? readNative,
  String? Function()? localeRegion,
}) async {
  DeviceCountryCodes codes;
  try {
    codes = await (readNative ?? _readNative)();
  } catch (_) {
    codes = const DeviceCountryCodes();
  }
  String? region;
  try {
    region = (localeRegion ?? _localeRegion)();
  } catch (_) {
    region = null;
  }
  return suggestCountry(simIso: codes.sim, networkIso: codes.network, localeRegion: region);
}
