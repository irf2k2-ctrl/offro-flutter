// lib/core/pricing/reward_money.dart
// Reward redemption for ONE country, as the server describes it (GET /user/wallet -> "reward").
// This file only READS and FORMATS what the server returns: the voucher points, value, currency and partner names are admin-configured
// per country (Admin -> Pricing & Plans -> Reward Redemption Points). Nothing is converted between currencies and no amount is assumed.
//
// Pure Dart (no Flutter imports) so it can be unit-tested with `dart test`.

/// The reward settings of the signed-in account's country.
class RewardConfig {
  final bool configured;
  final bool active;
  final bool redeemable;
  final String country;
  final String currencyCode;
  final String currencySymbol;
  final int? voucherPoints;
  final double? voucherValue;
  final List<String> partners;
  const RewardConfig({
    required this.configured,
    required this.active,
    required this.redeemable,
    required this.country,
    required this.currencyCode,
    required this.currencySymbol,
    required this.voucherPoints,
    required this.voucherValue,
    required this.partners,
  });

  /// India's long-standing reward (200 points = INR 20, Amazon / Flipkart). Used ONLY when the server answered without a `reward`
  /// block at all (an older server, which was India-only) - never for a country the server says is not configured.
  static const india = RewardConfig(
    configured: true, active: true, redeemable: true, country: 'IN', currencyCode: 'INR', currencySymbol: '₹',
    voucherPoints: 200, voucherValue: 20, partners: ['Amazon', 'Flipkart'],
  );

  /// Nothing known yet (before the first response) or the request failed: nothing can be shown or redeemed.
  static const unknown = RewardConfig(
    configured: false, active: false, redeemable: false, country: '', currencyCode: '', currencySymbol: '',
    voucherPoints: null, voucherValue: null, partners: [],
  );

  factory RewardConfig.fromWallet(Map? wallet) {
    if (wallet == null || wallet.isEmpty) return unknown;
    final r = wallet['reward'];
    if (r is! Map) return india;                                   // older, India-only server
    final pts = r['voucher_points'];
    final val = r['voucher_value'];
    final partners = <String>[];
    final raw = r['voucher_partners'];
    if (raw is List) {
      for (final p in raw) {
        final t = p?.toString().trim() ?? '';
        if (t.isNotEmpty) partners.add(t);
      }
    }
    final redeemable = r['redeemable'] == true && pts is num && val is num && pts > 0;
    return RewardConfig(
      configured: r['configured'] == true,
      active: r['active'] == true,
      redeemable: redeemable,
      country: (r['country'] ?? '').toString(),
      currencyCode: (r['currency_code'] ?? '').toString().trim().toUpperCase(),
      currencySymbol: (r['currency_symbol'] ?? '').toString().trim(),
      voucherPoints: redeemable ? pts.toInt() : null,
      voucherValue: redeemable ? val.toDouble() : null,
      partners: partners,
    );
  }

  /// The formatted voucher value for app language [lang] ("₹20", "SAR 5", "5 ر.س"), or null when there is none.
  String? amountLabel(String? lang) => voucherValue == null ? null : formatRewardAmount(voucherValue!, currencyCode, currencySymbol, lang);

  /// "Amazon, Flipkart" (Arabic comma in Arabic), or '' when the country has no partner names.
  String partnersLabel(String? lang) => joinPartners(partners, lang);
}

bool _isArabic(String? lang) => (lang ?? '').trim().toLowerCase().startsWith('ar');

/// The text shown for a currency: ₹ for INR, the code "SAR" in English / "ر.س" in Arabic for the Saudi Riyal (a placeholder until the
/// official symbol asset is attached - see CurrencySymbol), the configured symbol when it is a real symbol, otherwise the ISO code.
String currencyLabel(String code, String symbol, String? lang) {
  final c = code.trim().toUpperCase();
  if (c == 'INR') return '₹';
  if (c == 'SAR') return _isArabic(lang) ? 'ر.س' : 'SAR';
  final s = symbol.trim();
  if (s.isNotEmpty) return s;
  return c;
}

String _number(double v) {
  final fixed = v.toStringAsFixed(2);
  final t = fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : (fixed.endsWith('0') ? fixed.substring(0, fixed.length - 1) : fixed);
  final parts = t.split('.');
  final grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
}

/// A reward amount with its currency: "₹20", "SAR 5", Arabic "5 ر.س". A currency label made of letters gets a space; a symbol does not.
String formatRewardAmount(double value, String code, String symbol, String? lang) {
  final label = currencyLabel(code, symbol, lang);
  final n = _number(value);
  final lettersOnly = RegExp(r'^[A-Za-z؀-ۿ.\s]+$').hasMatch(label);
  if (_isArabic(lang) && lettersOnly) return '$n $label';
  return lettersOnly ? '$label $n' : '$label$n';
}

String joinPartners(List<String> partners, String? lang) =>
    partners.map((p) => p.trim()).where((p) => p.isNotEmpty).join(_isArabic(lang) ? '، ' : ', ');
