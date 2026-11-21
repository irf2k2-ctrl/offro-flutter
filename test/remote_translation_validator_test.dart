// Phase K: every rule that decides whether remote translation data may be used (pure Dart, no network, no storage).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/l10n/remote/generated/remote_l10n_schema.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_validator.dart';

final String h64 = 'a' * 64;

/// Bundled keys without placeholders / with one placeholder, taken from the real schema.
List<String> plainKeys(int n) => kRemoteL10nSchema.entries
    .where((e) => e.value.isEmpty)
    .map((e) => e.key)
    .take(n)
    .toList();
String oneParamKey() =>
    kRemoteL10nSchema.entries.firstWhere((e) => e.value.length == 1).key;

Map<String, Object?> file(Map<String, Object?> strings,
        {int version = 1, String lang = 'ar', Object? direction = 'rtl'}) =>
    {
      'schema': 1,
      'lang': lang,
      'track': 'app',
      'version': version,
      'direction': direction,
      'hash': h64,
      'strings': strings,
    };

RemotePayloadResult parse(Object? d, {int minVersion = 1}) =>
    RemoteTranslationValidator.parseLanguageFile(d,
        lang: 'ar', schema: kRemoteL10nSchema, minVersion: minVersion);

void main() {
  group('language code / key names', () {
    test('language code', () {
      expect(RemoteTranslationValidator.isValidLanguageCode('ar'), isTrue);
      for (final bad in ['', 'AR', 'a', 'arab', 'ar-SA', '../ar', 'ar?x=1']) {
        expect(RemoteTranslationValidator.isValidLanguageCode(bad), isFalse,
            reason: bad);
      }
    });
    test('English is never accepted as a remote language', () {
      expect(
          RemoteTranslationValidator.parseLanguageFile(file({}, lang: 'en'),
                  lang: 'en', schema: kRemoteL10nSchema)
              .payload,
          isNull);
    });
    test('key names', () {
      expect(RemoteTranslationValidator.isValidKey('otpEyebrow'), isTrue);
      for (final bad in ['', '1abc', 'a-b', 'a b', 'a.b', 'a\$b', 'x' * 101]) {
        expect(RemoteTranslationValidator.isValidKey(bad), isFalse,
            reason: bad);
      }
    });
    test('a key that this app does not have is skipped, not accepted', () {
      final keys = plainKeys(10);
      final res = parse(
          file({for (final k in keys) k: 'text $k', 'someFutureKey': 'x'}));
      expect(res.payload!.strings.containsKey('someFutureKey'), isFalse);
      expect(res.payload!.rejected, 1);
    });
  });

  group('values', () {
    final k = plainKeys(1).single;
    final p = oneParamKey();
    final p0 = kRemoteL10nSchema[p]!.single;
    String? check(String key, Object? v) =>
        RemoteTranslationValidator.checkValue(key, v, kRemoteL10nSchema);

    test('normal text is accepted and trimmed',
        () => expect(check(k, '  hello  '), 'hello'));
    test(
        'Arabic text survives',
        () => expect(check(k, '\u0645\u0631\u062d\u0628\u0627'),
            '\u0645\u0631\u062d\u0628\u0627'));
    test(
        'empty / blank / non-text values are rejected (never blank a bundled label)',
        () {
      for (final v in [
        '',
        '   ',
        '\n',
        null,
        5,
        true,
        <String>['x'],
        <String, String>{}
      ]) {
        expect(check(k, v), isNull, reason: '$v');
      }
    });
    test('too long', () => expect(check(k, 'x' * 2001), isNull));
    test('control and hidden characters', () {
      for (final v in [
        'a\u0000b',
        'a\u0007b',
        'a‮b',
        'a​b',
        'a⁦b',
        'a﻿b',
        'a­b',
        'a b'
      ]) {
        expect(check(k, v), isNull, reason: v.codeUnits.toString());
      }
      expect(check(k, 'a\nb'), 'a\nb', reason: 'a newline is allowed');
      expect(check(k, 'a‌b‍c‎d‏e'), isNotNull,
          reason: 'ZWNJ ZWJ LRM RLM are legitimate in Arabic');
    });
    test('HTML is rejected', () {
      for (final v in ['<b>x</b>', 'a <script>', 'x &amp; y', 'x &#39; y']) {
        expect(check(k, v), isNull, reason: v);
      }
      expect(check(k, '5 < 6'), '5 < 6',
          reason: 'a plain comparison sign is not a tag');
    });
    test('placeholders must match the bundled definition exactly', () {
      expect(check(p, 'x {$p0} y'), 'x {$p0} y');
      expect(check(p, 'x {$p0} {$p0} y'), isNotNull,
          reason: 'repeating the same placeholder is fine');
      expect(check(p, 'no placeholder'), isNull, reason: 'missing placeholder');
      expect(check(p, 'x {other} y'), isNull, reason: 'renamed placeholder');
      expect(check(p, 'x {$p0} {extra} y'), isNull,
          reason: 'extra placeholder');
      expect(check(p, 'x {$p0 y'), isNull, reason: 'unbalanced brace');
      expect(check(p, 'x {$p0}} y'), isNull, reason: 'stray brace');
      expect(check(k, 'text {surprise}'), isNull,
          reason: 'placeholder where the bundled text has none');
    });
  });

  group('language file', () {
    test('valid file', () {
      final keys = plainKeys(4);
      final res = parse(file({for (final k in keys) k: 'v $k'}, version: 3));
      expect(res.error, isNull);
      expect(res.payload!.version, 3);
      expect(res.payload!.hash, h64);
      expect(res.payload!.strings.length, 4);
    });
    test('an empty published set is valid (nothing overridden)',
        () => expect(parse(file({})).payload!.strings, isEmpty));
    test('structural problems reject the whole file', () {
      final ok = plainKeys(2);
      Map<String, Object?> f() => file({for (final k in ok) k: 'v'});
      expect(parse(null).payload, isNull);
      expect(parse('text').payload, isNull);
      expect(parse(<Object?>[]).payload, isNull);
      expect(parse(f()..['schema'] = 2).error, 'unsupported_schema');
      expect(parse(f()..['lang'] = 'fr').error, 'language_mismatch');
      expect(parse(f()..['track'] = 'legal').error, 'track_mismatch');
      expect(parse(f()..['version'] = 0).error, 'bad_version');
      expect(parse(f()..['version'] = '2').error, 'bad_version');
      expect(parse(f()..['hash'] = 'zz').error, 'bad_hash');
      expect(parse(f()..['direction'] = 'ltr').error, 'direction_mismatch');
      expect(parse(f()..['strings'] = ['a']).error, 'strings_not_an_object');
      expect(parse(f()..remove('strings')).error, 'strings_not_an_object');
    });
    test(
        'a file older than the manifest is stale',
        () => expect(
            parse(file({}, version: 2), minVersion: 3).error, 'stale_version'));
    test('one bad entry is skipped; a mostly-bad file is rejected', () {
      final keys = plainKeys(8);
      final one = parse(file({for (final k in keys) k: 'v', keys.first: ''}));
      expect(one.payload!.rejected, 1);
      expect(one.payload!.strings.containsKey(keys.first), isFalse);
      final many = parse(file({for (final k in keys) k: ''}));
      expect(many.error, 'too_many_invalid_entries');
    });
    test('invalid JSON text decodes to null (never throws)', () {
      expect(RemoteTranslationValidator.decodeBytes(utf8.encode('{not json')),
          isNull);
      expect(RemoteTranslationValidator.decodeBytes(<int>[0xff, 0xfe, 0x00]),
          isNull);
      expect(
          RemoteTranslationValidator.decodeBytes(utf8.encode('{"a":"\u0645"}')),
          {'a': '\u0645'});
    });
  });

  group('manifest', () {
    Map<String, Object?> m(
            {bool kill = false, bool enabled = true, List<Object?>? langs}) =>
        {
          'schema': 1,
          'kill_switch': kill,
          'overrides_enabled': enabled,
          'languages': langs ??
              [
                {
                  'code': 'ar',
                  'name_en': 'Arabic',
                  'direction': 'rtl',
                  'tracks': {
                    'app': {'version': 4, 'hash': h64},
                  },
                },
              ],
        };
    test('published Arabic', () {
      final x = RemoteTranslationValidator.parseManifest(m())!;
      expect(x.active, isTrue);
      expect(x.appTracks['ar']!.version, 4);
    });
    test('kill switch / overrides disabled make it inactive', () {
      expect(RemoteTranslationValidator.parseManifest(m(kill: true))!.active,
          isFalse);
      expect(
          RemoteTranslationValidator.parseManifest(m(enabled: false))!.active,
          isFalse);
    });
    test(
        'no languages = nothing published',
        () => expect(
            RemoteTranslationValidator.parseManifest(m(langs: []))!.appTracks,
            isEmpty));
    test('a language without a published App track or with bad data is ignored',
        () {
      final x = RemoteTranslationValidator.parseManifest(m(langs: [
        {'code': 'ar', 'tracks': <String, Object?>{}},
        {
          'code': 'fr',
          'tracks': {
            'app': {'version': 'x', 'hash': h64}
          }
        },
        'junk',
      ]))!;
      expect(x.appTracks, isEmpty);
    });
    test('malformed manifests are rejected', () {
      for (final bad in [
        null,
        'x',
        <Object?>[],
        {'schema': 2},
        {'schema': 1},
        {
          'schema': 1,
          'kill_switch': 'no',
          'overrides_enabled': true,
          'languages': []
        }
      ]) {
        expect(RemoteTranslationValidator.parseManifest(bad), isNull,
            reason: '$bad');
      }
    });
  });
}
