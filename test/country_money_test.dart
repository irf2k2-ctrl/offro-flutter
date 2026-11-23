// Pure-Dart tests for the country money / error helpers (no widgets, no network).
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/pricing/country_money.dart';

void main() {
  group('CountryMoney.from', () {
    test('no currency fields -> India (unchanged GST, rupee sign)', () {
      final m = CountryMoney.from({'price': 499});
      expect(m.isIndia, isTrue);
      expect(m.symbol, '₹');
      expect(m.taxLabel, 'GST');
      expect(m.taxRowText(18), isNull); // India keeps its localized "GST (18%)" text
      expect(CountryMoney.from(null).isIndia, isTrue);
    });
    test('India response with explicit labels', () {
      final m = CountryMoney.from({'currency_code': 'INR', 'currency_symbol': '₹', 'tax_label': 'GST'});
      expect(m.isIndia, isTrue);
      expect(m.taxRowText(18), isNull);
      expect(m.raw(588.82), '₹588.82');
    });
    test('Saudi Arabia: SAR + VAT, never replaced by INR', () {
      final m = CountryMoney.from({'currency_code': 'SAR', 'currency_symbol': 'SAR', 'tax_label': 'VAT'});
      expect(m.isIndia, isFalse);
      expect(m.code, 'SAR');
      expect(m.fmt(115), 'SAR 115.00');
      expect(m.fmt(115, trimWhole: true), 'SAR 115');
      expect(m.taxRowText(15), 'VAT (15%)');
      expect(m.minus(10), '-SAR 10.00');
      expect(m.prefixed('10.00'), 'SAR 10.00');
      expect(m.raw(0), 'SAR 0');
      expect(CountryMoney.india.prefixed('10.00'), '₹10.00');
    });
    test('symbol-only and code-only responses', () {
      expect(CountryMoney.from({'currency_symbol': '£'}).code, '£');
      expect(CountryMoney.from({'currency': 'AED'}).symbol, 'AED');
    });
    test('fractional tax percent', () {
      final m = CountryMoney.from({'currency_code': 'GBP', 'currency_symbol': '£', 'tax_label': 'VAT'});
      expect(m.taxRowText(7.5), 'VAT (7.5%)');
    });
  });

  group('fixed-amount discount display', () {
    test('India shows the rupee amount; another currency its own (the server refuses fixed codes outside INR)', () {
      expect('- ${CountryMoney.india.prefixed('50')}', '- ₹50');
      expect('- ${CountryMoney.from({'currency_code': 'SAR', 'currency_symbol': 'SAR'}).prefixed('50')}', '- SAR 50');
    });
  });

  group('errors', () {
    test('apiDetailText never returns a raw map', () {
      expect(apiDetailText({'code': 'x', 'message': 'Hello'}), 'Hello');
      expect(apiDetailText({'code': 'x'}), 'Error');
      expect(apiDetailText('plain'), 'plain');
      expect(apiDetailText(null, fallback: 'F'), 'F');
      expect(apiDetailCode({'code': 'tax_not_configured'}), 'tax_not_configured');
      expect(apiDetailCode('plain'), isNull);
    });
    test('ApiException keeps the Exception: shape', () {
      expect(const ApiException('m', code: 'c').toString(), 'Exception: m');
    });
    test('pricingErrorText covers the server codes', () {
      for (final c in ['pricing_not_configured', 'country_inactive', 'tax_not_configured', 'price_not_configured']) {
        expect(pricingErrorText(c, 'server'), isNot('server'));
      }
      expect(pricingErrorText('other', 'server'), 'server');
    });
  });

  group('manual payment notice', () {
    test('currency not enabled names the currency and the manual path', () {
      final t = manualPaymentNotice({'manual_reason': 'currency_not_enabled', 'currency_code': 'SAR'});
      expect(t.contains('SAR'), isTrue);
      expect(t.contains('manually'), isTrue);
    });
    test('gateway not configured', () {
      expect(manualPaymentNotice({'manual_reason': 'payment_gateway_not_configured'}).isNotEmpty, isTrue);
    });
    test('India / online orders have no notice', () {
      expect(manualPaymentNotice({'amount': 1}), '');
      expect(manualPaymentNotice(null), '');
    });
  });
}
