// lib/core/l10n/category_names.dart
//
// ONE mechanism for showing admin-managed category names in the app language. Pure Dart (no Flutter, no network).
//
// Category names are DATA (the Category Master). The server sends each category with `names` ({language: name}, admin-entered, plus its
// built-in glossary for the well-known ones). Api.fetchCategories() registers every list it receives here, so a category added later
// is translated as soon as the admin gives it a name - with no app update and no per-screen code. The English `name` stays the value
// used for storing, filtering and API requests; only the text shown to the user changes.

class CategoryNames {
  CategoryNames._();

  static final Map<String, Map<String, String>> _byKey = {};

  /// Same key rule as the category filters elsewhere: trimmed, lower-case.
  static String keyOf(String name) => name.trim().toLowerCase();

  /// Remember the translations of a /categories payload (a list of maps; anything else is ignored). Safe to call repeatedly.
  static void register(Iterable<dynamic> categories) {
    for (final c in categories) {
      if (c is! Map) continue;
      final name = (c['name'] ?? '').toString();
      final names = c['names'];
      if (name.trim().isEmpty || names is! Map) continue;
      final clean = <String, String>{};
      names.forEach((k, v) {
        final code = k.toString().trim().toLowerCase().replaceAll('_', '-');
        final text = v is String ? v.trim() : '';
        if (code.isNotEmpty && text.isNotEmpty) clean[code] = text;
      });
      if (clean.isNotEmpty) _byKey[keyOf(name)] = clean;
    }
  }

  /// The category's name in [languageCode] ('ar', 'ar-SA'), or null when none is known (the caller then uses its own fallback).
  static String? lookup(String name, String languageCode) {
    final code = languageCode.trim().toLowerCase().replaceAll('_', '-');
    final names = _byKey[keyOf(name)];
    if (names == null || code.isEmpty) return null;
    return names[code] ?? names[code.split('-').first];
  }

  /// Last-resort glossary for the built-in categories, used before the first /categories response (or when it fails) so the
  /// well-known names are never shown in English in Arabic. A server translation always wins over these.
  static const Map<String, Map<String, String>> _builtin = {
    'ar': {
      'restaurant': 'مطعم', 'restaurants': 'مطاعم', 'grocery': 'بقالة', 'pharmacy': 'صيدلية', 'electronics': 'إلكترونيات',
      'fashion': 'أزياء', 'bakery': 'مخبز', 'salon': 'صالون', 'fitness': 'لياقة بدنية', 'hospital': 'مستشفى',
      'education': 'تعليم', 'automobile': 'سيارات', 'other': 'أخرى', 'cafe': 'مقهى', 'beauty': 'جمال',
      'jewelry': 'مجوهرات', 'jewellery': 'مجوهرات', 'stationery': 'قرطاسية',
    },
  };

  static String? builtin(String name, String languageCode) {
    final code = languageCode.trim().toLowerCase().split(RegExp('[-_]')).first;
    return _builtin[code]?[keyOf(name)];
  }

  /// Display text: server translation, else built-in glossary, else null.
  static String? translate(String name, String languageCode) =>
      lookup(name, languageCode) ?? builtin(name, languageCode);

  /// A list of names for display, e.g. "Grocery, Restaurant" -> "بقالة, مطعم" (each translated on its own).
  static String joinTranslated(Iterable<String> names, String languageCode, {String separator = ', '}) =>
      names.map((n) => translate(n, languageCode) ?? n).join(separator);

  static void debugClear() => _byKey.clear();
}
