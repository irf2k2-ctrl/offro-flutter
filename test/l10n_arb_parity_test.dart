// Phase I: English/Arabic ARB parity, with no Flutter assets needed (reads lib/l10n/*.arb directly).
// Same rules as tools/check_l10n.py, so CI without Python is covered too.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> load(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

Map<String, String> strings(Map<String, dynamic> d) =>
    {for (final e in d.entries) if (!e.key.startsWith('@')) e.key: e.value as String};

final ph = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');
Set<String> placeholdersOf(String s) => ph.allMatches(s).map((m) => m.group(1)!).toSet();

void main() {
  final en = load('en'), ar = load('ar');
  final enS = strings(en), arS = strings(ar);

  test('Arabic has exactly the English keys', () {
    expect(arS.keys.toSet().difference(enS.keys.toSet()), isEmpty, reason: 'extra Arabic keys');
    expect(enS.keys.toSet().difference(arS.keys.toSet()), isEmpty, reason: 'missing Arabic keys');
  });

  test('placeholders match and are declared String (Western digits only)', () {
    for (final k in enS.keys) {
      expect(placeholdersOf(arS[k]!), placeholdersOf(enS[k]!), reason: k);
      final meta = (en['@$k'] as Map?) ?? const {};
      final declared = (meta['placeholders'] as Map?) ?? const {};
      expect(declared.keys.toSet(), placeholdersOf(enS[k]!), reason: '$k declared placeholders');
      for (final p in declared.entries) {
        expect((p.value as Map)['type'], 'String', reason: '${k}.${p.key} must be String');
      }
    }
  });

  test('no plural/select, no HTML, no edge whitespace, no bidi/control characters', () {
    final icu = RegExp(r'\{\s*\w+\s*,\s*(plural|select|selectordinal)\s*,');
    final html = RegExp(r'</?[A-Za-z][^>]*>|&[#A-Za-z0-9]+;');
    final hidden = RegExp('[​-‏‪-‮⁦-⁩؜﻿]');
    for (final m in [enS, arS]) {
      for (final e in m.entries) {
        expect(icu.hasMatch(e.value), isFalse, reason: e.key);
        expect(html.hasMatch(e.value), isFalse, reason: e.key);
        expect(e.value, e.value.trim(), reason: '${e.key} has edge whitespace');
        expect(hidden.hasMatch(e.value), isFalse, reason: e.key);
      }
    }
  });

  test('Arabic values contain Arabic letters (unless intentionally identical to English)', () {
    final arabic = RegExp(r'[؀-ۿ]');
    for (final k in enS.keys) {
      expect(arabic.hasMatch(arS[k]!) || arS[k] == enS[k], isTrue, reason: k);
    }
  });

  test('the Arabic file is marked as a draft that needs native review', () {
    expect((ar['@@x-translation-status'] as String).toLowerCase(), contains('native'));
  });
}
