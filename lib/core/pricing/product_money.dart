// lib/core/pricing/product_money.dart
// How a PRODUCT / STORE price is drawn for the customer: in the currency of the merchant's COUNTRY, exactly as the server sends it
// (`currency_code` / `currency_symbol` on the product / store payload). OffrO never converts a price between currencies and never changes a
// stored price - this only chooses the symbol or code written next to the number the merchant typed.
//
//   * India (INR / the rupee sign): the output is byte-for-byte what the app always drew ("₹499", Indian digit grouping on the share card).
//   * A payload with NO currency fields at all (an older server, an old cached list) is an India payload: INR.
//   * Another country: its configured code or symbol, letters followed by a space ("SAR 115"); the whole amount is wrapped in a
//     left-to-right isolate so it reads the same inside Arabic (RTL) text. The Saudi Riyal sign is never drawn - the code is used.
//   * A payload that carries the currency keys but EMPTY values (the country has no configured currency) draws the bare number.
//
// Pure Dart (no Flutter imports) so it can be unit-tested.

class ProductMoney {
  final String symbol;
  final String code;
  const ProductMoney({this.symbol = '₹', this.code = 'INR'});

  /// India's currency: used for a payload without currency fields.
  static const india = ProductMoney();

  factory ProductMoney.from(Map? m) {
    if (m == null) return india;
    if (!m.containsKey('currency_code') && !m.containsKey('currency_symbol')) return india;
    final code = (m['currency_code'] ?? '').toString().trim().toUpperCase();
    final sym = (m['currency_symbol'] ?? '').toString().trim();
    return ProductMoney(symbol: sym.isNotEmpty ? sym : code, code: code);
  }

  /// The first map that carries currency fields (a product, then its store), else India.
  factory ProductMoney.fromAny(Iterable<Map?> maps) {
    for (final m in maps) {
      if (m != null && (m.containsKey('currency_code') || m.containsKey('currency_symbol'))) return ProductMoney.from(m);
    }
    return india;
  }

  bool get isIndia => code == 'INR';
  bool get hasCurrency => symbol.isNotEmpty;

  String _prefix() {
    if (symbol.isEmpty) return '';
    return RegExp(r'^[A-Za-z]+$').hasMatch(symbol) ? '$symbol ' : symbol;
  }

  String _wrap(String s) => isIndia ? s : '⁦$s⁩';

  /// "₹499" - the amount rounded to a whole number (what product cards always showed).
  String whole(num v) => _wrap('${_prefix()}${v.toStringAsFixed(0)}');

  /// "₹499" from the price text as the merchant saved it (no re-formatting of the number).
  String raw(Object? v) => _wrap('${_prefix()}${v ?? ''}');

  /// Share-card amount: whole numbers without decimals, otherwise 2 decimals, with digit grouping - Indian (12,34,567) for INR (unchanged),
  /// thousands (1,234,567) for every other currency.
  String grouped(num v) {
    final whole = v == v.roundToDouble();
    final str = whole ? v.round().toString() : v.toStringAsFixed(2);
    final parts = str.split('.');
    var ip = parts[0];
    final neg = ip.startsWith('-');
    if (neg) ip = ip.substring(1);
    if (ip.length > 3) {
      if (isIndia) {
        final last3 = ip.substring(ip.length - 3);
        var rest = ip.substring(0, ip.length - 3);
        final groups = <String>[];
        while (rest.length > 2) {
          groups.insert(0, rest.substring(rest.length - 2));
          rest = rest.substring(0, rest.length - 2);
        }
        if (rest.isNotEmpty) groups.insert(0, rest);
        ip = '${groups.join(',')},$last3';
      } else {
        final groups = <String>[];
        var rest = ip;
        while (rest.length > 3) {
          groups.insert(0, rest.substring(rest.length - 3));
          rest = rest.substring(0, rest.length - 3);
        }
        if (rest.isNotEmpty) groups.insert(0, rest);
        ip = groups.join(',');
      }
    }
    return _wrap('${_prefix()}${neg ? '-' : ''}$ip${parts.length > 1 ? '.${parts[1]}' : ''}');
  }
}
