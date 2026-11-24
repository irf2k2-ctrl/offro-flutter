// lib/core/l10n/remote/remote_template.dart
// Fills `{name}` placeholders of a remote text with the call's arguments.

final RegExp _placeholder = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');

// A money argument is text such as "₹10.0" / "SAR 115.00" / "-₹5.00": it ALREADY carries its currency symbol (the app formats the amount
// with the currency of the order). A translation that also writes a currency symbol next to the placeholder ("ادفع ₹{amount}",
// "{amount}₹" - texts published before prices became per-country) would show the symbol twice, or on the wrong side in RTL.
final RegExp _moneyArg = RegExp(r'^\s*[-−]?\s*(?:[^\s\d.,٠-٩\p{L}+\-−{}]|\p{Lu}{3}\s?|Rs\.?\s?)\s*[-−]?\d', unicode: true);
const String _cur = r'(?:₹|\$|€|£|¥|﷼|Rs\.?|INR|SAR|AED|USD|EUR|GBP|ر\.\s?س\.?|ريال(?:\s+سعودي)?|روبية(?:\s+هندية)?)';

/// True when [value] is an amount that already includes its currency symbol/code.
bool isMoneyText(String value) => _moneyArg.hasMatch(value);

/// Replaces every `{name}` in [template] with `args[name]`. One pass over the template, so an argument that itself contains
/// `{something}` is never expanded again. A name without an argument is left as written (the validator guarantees the template's
/// placeholder names equal the bundled ones, so this only protects against misuse).
///
/// A currency symbol/code written in the template right next to a placeholder whose argument is already money text is dropped, so the
/// symbol is shown exactly once; that money text is wrapped in a left-to-right isolate so "₹10.50" keeps its symbol on the left inside
/// Arabic (RTL) text.
String fillRemoteTemplate(String template, Map<String, String> args) {
  var t = template;
  for (final e in args.entries) {
    if (!isMoneyText(e.value)) continue;
    final n = RegExp.escape(e.key);
    t = t.replaceAll(RegExp('$_cur\\s*\\{$n\\}'), '{${e.key}}').replaceAll(RegExp('\\{$n\\}\\s*$_cur'), '{${e.key}}');
  }
  return t.replaceAllMapped(_placeholder, (m) {
    final v = args[m.group(1)];
    if (v == null) return m.group(0)!;
    return isMoneyText(v) ? '⁦$v⁩' : v;
  });
}
