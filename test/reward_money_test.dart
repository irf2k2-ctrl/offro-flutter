// Reward redemption per country: RewardConfig (from GET /user/wallet) and the amount formatter. Pure unit tests.
// Run:  flutter test test/reward_money_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/pricing/reward_money.dart';

Map<String, dynamic> _wallet(Map<String, dynamic> reward) => {'visit_points': 250, 'pool_points': 0, 'reward': reward};

Map<String, dynamic> get _india => {
      'configured': true, 'active': true, 'country': 'IN', 'currency_code': 'INR', 'currency_symbol': '₹',
      'voucher_points': 200, 'voucher_value': 20.0, 'voucher_partners': ['Amazon', 'Flipkart'], 'redeemable': true,
    };
Map<String, dynamic> get _saudi => {
      'configured': true, 'active': true, 'country': 'SA', 'currency_code': 'SAR', 'currency_symbol': 'SAR',
      'voucher_points': 100, 'voucher_value': 5.0, 'voucher_partners': [], 'redeemable': true,
    };
Map<String, dynamic> get _saudiOff => {
      'configured': false, 'active': false, 'country': 'SA', 'currency_code': 'SAR', 'currency_symbol': 'SAR',
      'voucher_points': null, 'voucher_value': null, 'voucher_partners': [], 'redeemable': false,
    };

void main() {
  group('India is unchanged: 200 points = ₹20, Amazon / Flipkart', () {
    final r = RewardConfig.fromWallet(_wallet(_india));
    test('values', () {
      expect(r.redeemable, isTrue);
      expect(r.voucherPoints, 200);
      expect(r.voucherValue, 20.0);
      expect(r.amountLabel('en'), '₹20');
      expect(r.amountLabel('ar'), '₹20');
      expect(r.partnersLabel('en'), 'Amazon, Flipkart');
      expect(r.partnersLabel('ar'), 'Amazon، Flipkart');
    });
    test('an older server without the reward block is India', () {
      final old = RewardConfig.fromWallet({'visit_points': 10, 'pool_points': 0, 'conversion_rate': 0.1, 'min_withdraw_points': 200});
      expect(old.redeemable, isTrue);
      expect(old.voucherPoints, 200);
      expect(old.amountLabel('en'), '₹20');
    });
  });

  group('Saudi Arabia shows its own configuration, never ₹', () {
    final r = RewardConfig.fromWallet(_wallet(_saudi));
    test('configured: 100 points = SAR 5, English "SAR", Arabic "ر.س"', () {
      expect(r.redeemable, isTrue);
      expect(r.voucherPoints, 100);
      expect(r.amountLabel('en'), 'SAR 5');
      expect(r.amountLabel('ar'), '5 ر.س');
      expect(r.amountLabel('ar-SA'), '5 ر.س');
      expect(r.amountLabel('en')!.contains('₹'), isFalse);
      expect(r.amountLabel('ar')!.contains('₹'), isFalse);
      expect(r.partnersLabel('en'), '');                     // no partner names unless the admin sets them
    });
    test('fractions keep two digits, whole numbers none, thousands are grouped', () {
      expect(formatRewardAmount(7.5, 'SAR', 'SAR', 'en'), 'SAR 7.5');
      expect(formatRewardAmount(7.25, 'SAR', 'SAR', 'en'), 'SAR 7.25');
      expect(formatRewardAmount(1250, 'SAR', 'SAR', 'en'), 'SAR 1,250');
    });
    test('not configured: no amount, no points, not redeemable (no INR fallback)', () {
      final n = RewardConfig.fromWallet(_wallet(_saudiOff));
      expect(n.redeemable, isFalse);
      expect(n.voucherPoints, null);
      expect(n.voucherValue, null);
      expect(n.amountLabel('en'), null);
      expect(n.country, 'SA');
    });
    test('a server that says redeemable but sends no amount is treated as not redeemable', () {
      final bad = RewardConfig.fromWallet(_wallet({..._saudi, 'voucher_value': null}));
      expect(bad.redeemable, isFalse);
      expect(bad.amountLabel('en'), null);
    });
    test('partner names, when configured, are cleaned and joined', () {
      final p = RewardConfig.fromWallet(_wallet({..._saudi, 'voucher_partners': [' Noon ', '', 'Jarir']}));
      expect(p.partnersLabel('en'), 'Noon, Jarir');
      expect(p.partnersLabel('ar'), 'Noon، Jarir');
    });
  });

  group('other currencies and no data', () {
    test('Jordan Dinar uses its configured symbol, else the ISO code', () {
      expect(formatRewardAmount(3, 'JOD', 'JOD', 'en'), 'JOD 3');
      expect(formatRewardAmount(3, 'JOD', 'د.أ', 'ar'), '3 د.أ');
      expect(currencyLabel('NPR', '', 'en'), 'NPR');
    });
    test('INR is always ₹ and SAR is never drawn as a made-up symbol', () {
      expect(currencyLabel('INR', 'Rs', 'en'), '₹');
      expect(currencyLabel('SAR', '﷼', 'en'), 'SAR');
      expect(currencyLabel('SAR', '﷼', 'ar'), 'ر.س');
    });
    test('no response yet: nothing to show or redeem', () {
      expect(RewardConfig.fromWallet(null).redeemable, isFalse);
      expect(RewardConfig.fromWallet(const {}).redeemable, isFalse);
      expect(RewardConfig.unknown.country, '');
    });
  });
}
