// lib/core/l10n/locale_controller.dart
//
// Holds the app language (Phase I). Rules:
//   * English until the user MANUALLY picks another language. The device language is never used.
//   * The choice is stored locally (SharedPreferences key `app_language`) and nothing else: it is not sent to any server.
//   * Unknown / corrupted stored values fall back to English.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  static const String prefsKey = 'app_language';
  static const String defaultCode = 'en';
  static const List<String> supportedCodes = ['en', 'ar'];

  Locale _locale = const Locale(defaultCode);
  Locale get locale => _locale;
  bool get isRtl => _locale.languageCode == 'ar';

  /// Returns [code] when it is a supported language code, otherwise English.
  static String normalize(String? code) {
    final c = (code ?? '').trim().toLowerCase();
    return supportedCodes.contains(c) ? c : defaultCode;
  }

  /// Reads the saved choice. Never throws: any failure leaves English.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _locale = Locale(normalize(prefs.getString(prefsKey)));
    } catch (_) {
      _locale = const Locale(defaultCode);
    }
  }

  /// Changes the language and remembers it. The UI updates immediately even when saving fails.
  Future<void> setLanguage(String code) async {
    final next = normalize(code);
    if (next == _locale.languageCode) return;
    _locale = Locale(next);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, next);
    } catch (_) {/* the choice simply will not survive a restart */}
  }

  @visibleForTesting
  void resetForTest() {
    _locale = const Locale(defaultCode);
  }
}
