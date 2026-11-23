// lib/core/pricing/country_money.dart
// OffrO platform charges (store plans, banners, product day price, influencer subscription) are priced per country by the server.
// This file only FORMATS what the server returns: currency symbol / code and the tax label (GST for India, VAT or the configured label
// elsewhere). It never converts a price between currencies and never computes a tax rate of its own.
//
// Pure Dart (no Flutter imports) so it can be unit-tested with `dart test`.

/// An error from the OffrO API that carries the server's stable error code (e.g. `pricing_not_configured`).
/// toString() keeps the "Exception: <message>" shape every existing catch site already expects (friendlyError, etc.).
class ApiException implements Exception {
  final String message;
  final String? code;
  final int? status;
  const ApiException(this.message, {this.code, this.status});
  @override
  String toString() => 'Exception: $message';
}

/// Turns the `detail` of an error response into text. The pricing endpoints send {"code": "...", "message": "..."}; older endpoints
/// send a plain string. Never returns a Map's raw toString().
String apiDetailText(dynamic detail, {String fallback = 'Error'}) {
  if (detail == null) return fallback;
  if (detail is Map) {
    final m = detail['message'];
    if (m != null && m.toString().trim().isNotEmpty) return m.toString();
    return fallback;
  }
  final s = detail.toString();
  return s.isEmpty ? fallback : s;
}

String? apiDetailCode(dynamic detail) => (detail is Map && detail['code'] != null) ? detail['code'].toString() : null;

/// Currency symbol, ISO code and tax label for ONE order / plan / pricing response.
class CountryMoney {
  final String symbol;
  final String code;
  final String taxLabel;
  const CountryMoney({this.symbol = '₹', this.code = 'INR', this.taxLabel = 'GST'});

  /// India's existing values. Used only for a response that carries no currency fields at all (the pre-country API shape, i.e. an
  /// India response from an older server). A response that carries a currency is always taken as it is - never replaced by INR.
  static const india = CountryMoney();

  factory CountryMoney.from(Map? m) {
    if (m == null) return india;
    final sym = m['currency_symbol']?.toString().trim() ?? '';
    final code = m['currency_code']?.toString().trim() ?? (m['currency']?.toString().trim() ?? '');
    if (sym.isEmpty && code.isEmpty) return india;
    final label = m['tax_label']?.toString().trim() ?? '';
    return CountryMoney(
      symbol: sym.isNotEmpty ? sym : code,
      code: code.isNotEmpty ? code : sym,
      taxLabel: label.isNotEmpty ? label : 'GST',
    );
  }

  bool get isIndia => code == 'INR';

  /// "₹499" for a symbol like ₹, "SAR 115" for a letter-code symbol (a space keeps the code readable).
  String _prefix() {
    final letters = RegExp(r'^[A-Za-z]+$').hasMatch(symbol);
    return letters ? '$symbol ' : symbol;
  }

  static double _n(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// Amount as the server sent it, 2 decimals ("₹588.82"). [trimWhole] shows "₹499" for whole numbers.
  String fmt(dynamic v, {bool trimWhole = false}) {
    final d = _n(v);
    final body = (trimWhole && d == d.truncateToDouble()) ? d.toInt().toString() : d.toStringAsFixed(2);
    return '${_prefix()}$body';
  }

  /// Raw interpolation like the old `"₹${order['base_price']}"` (no forced decimals) - keeps India screens looking exactly as before.
  String raw(dynamic v) => '${_prefix()}${v ?? 0}';

  /// "−₹10.00"-style negative amount.
  String minus(dynamic v, {String sign = '-'}) => '$sign${_prefix()}${_n(v).toStringAsFixed(2)}';

  /// Label of the tax row: null for India / GST (callers then use their existing localized "GST (18%)" text unchanged); otherwise "VAT (15%)".
  String? taxRowText(dynamic percent) {
    if (taxLabel.toUpperCase() == 'GST') return null;
    final p = _n(percent);
    final ps = p == p.truncateToDouble() ? p.toInt().toString() : p.toString();
    return '$taxLabel ($ps%)';
  }

  String get taxName => taxLabel;

  // Sentences that the localized strings build with a hard-coded rupee sign. India keeps its localized text; other countries use these.
  String perDay(dynamic v) => '${raw(v)}/day';
  String payAmount(dynamic v) => 'Pay ${raw(v)}';
  String pricePerDayTimesDays(dynamic price, dynamic days) => '${fmt(price, trimWhole: true)}/day × $days days';
  String discountTotalPct(double amount, double pct, double total) =>
      '−${_prefix()}${amount.toStringAsFixed(2)} (${pct.toStringAsFixed(0)}%) off  →  Total: ${_prefix()}${total.toStringAsFixed(2)}';
  String discountTotalAmt(double amount, double total) =>
      '−${_prefix()}${amount.toStringAsFixed(0)} off  →  Total: ${_prefix()}${total.toStringAsFixed(2)}';
  String appliedAmount(double v) => '✅ ${_prefix()}${v.toStringAsFixed(0)} discount applied!';
  String codeAppliedAmount(double v) => '✅ Code applied — ${_prefix()}${v.toStringAsFixed(0)} off!';
  String pricePlusTax(dynamic price, dynamic percent) => '${raw(price)} + $percent% $taxLabel';
  String baseTaxLine(dynamic base, dynamic tax) => 'Base: ${raw(base)}  $taxLabel: ${raw(tax)}';
  String discountCodeLine(String code, double amount) => 'Discount ($code): −${_prefix()}${amount.toStringAsFixed(2)}';
  String fixedDiscount(double v) => '- ${_prefix()}${v.toStringAsFixed(0)}';
}

/// Why a paid order went to the manual (admin-confirmed) path instead of online checkout. Empty for India and for online orders.
String manualPaymentNotice(Map? order) {
  final reason = order?['manual_reason']?.toString();
  if (reason == null || reason.isEmpty) return '';
  final cur = CountryMoney.from(order).code;
  if (reason == 'currency_not_enabled') {
    return 'Online payment in $cur is not available yet. Your request has been recorded and our team will confirm your payment and activate it manually.';
  }
  if (reason == 'payment_gateway_not_configured') {
    return 'Online payment is not available right now. Your request has been recorded and our team will confirm your payment and activate it manually.';
  }
  return 'Online payment is not available. Our team will confirm your payment and activate it manually.';
}

/// Friendly text for the pricing error codes the server returns (HTTP 409). Falls back to the server's own message.
String pricingErrorText(String? code, String serverMessage) {
  switch (code) {
    case 'pricing_not_configured':
    case 'country_inactive':
      return 'Pricing is not available for your country yet. Please contact OffrO support.';
    case 'tax_not_configured':
      return 'Tax is not set up for your country yet, so a total cannot be shown. Please contact OffrO support.';
    case 'price_not_configured':
      return 'This price is not set up for your country yet. Please contact OffrO support.';
  }
  return serverMessage;
}
