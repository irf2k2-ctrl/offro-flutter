// Customer-facing product / store prices: drawn in the currency of the merchant's country, India unchanged, nothing converted.
// Pure unit tests. Run:  flutter test test/product_money_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/pricing/product_money.dart';

void main() {
  const lri = '⁦', pdi = '⁩';

  group('India stays exactly as before', () {
    test('a payload with no currency fields (older server) is India', () {
      final m = ProductMoney.from({'title': 'x', 'price': '499'});
      expect(m.isIndia, isTrue);
      expect(m.whole(499), '₹499');
      expect(m.whole(499.6), '₹500');
      expect(m.raw('499'), '₹499');
      expect(ProductMoney.from(null).raw(10), '₹10');
    });
    test('an explicit INR payload is India', () {
      final m = ProductMoney.from({'currency_code': 'INR', 'currency_symbol': '₹'});
      expect(m.isIndia, isTrue);
      expect(m.whole(1299), '₹1299');
    });
    test('the Indian digit grouping of the share card is unchanged', () {
      const m = ProductMoney.india;
      expect(m.grouped(499), '₹499');
      expect(m.grouped(1299), '₹1,299');
      expect(m.grouped(123456), '₹1,23,456');
      expect(m.grouped(1234567), '₹12,34,567');
      expect(m.grouped(99.5), '₹99.50');
      expect(m.grouped(1500.5), '₹1,500.50');
    });
  });

  group('another country', () {
    test('letters are written before the number with a space, inside a left-to-right isolate', () {
      final m = ProductMoney.from({'currency_code': 'SAR', 'currency_symbol': 'SAR', 'country': 'SA'});
      expect(m.isIndia, isFalse);
      expect(m.whole(115), '${lri}SAR 115$pdi');
      expect(m.raw('115'), '${lri}SAR 115$pdi');
      expect(m.whole(115).contains('₹'), isFalse);
    });
    test('thousands grouping, not the Indian lakh grouping', () {
      final m = ProductMoney.from({'currency_code': 'JOD', 'currency_symbol': 'JOD'});
      expect(m.grouped(1234567), '${lri}JOD 1,234,567$pdi');
      expect(m.grouped(1299), '${lri}JOD 1,299$pdi');
      expect(m.grouped(99.5), '${lri}JOD 99.50$pdi');
      expect(m.grouped(12), '${lri}JOD 12$pdi');
    });
    test('a non-letter symbol is written directly; a missing symbol falls back to the code', () {
      expect(ProductMoney.from({'currency_code': 'USD', 'currency_symbol': r'$'}).raw('5'), '$lri\$5$pdi');
      expect(ProductMoney.from({'currency_code': 'NPR', 'currency_symbol': ''}).whole(300), '${lri}NPR 300$pdi');
    });
    test('the currency keys with EMPTY values draw the bare number - never rupees', () {
      final m = ProductMoney.from({'currency_code': '', 'currency_symbol': ''});
      expect(m.isIndia, isFalse);
      expect(m.hasCurrency, isFalse);
      expect(m.whole(300), '${lri}300$pdi');
      expect(m.whole(300).contains('₹'), isFalse);
    });
  });

  group('fromAny', () {
    test('uses the product first, then the store, else India', () {
      final product = {'currency_code': 'SAR', 'currency_symbol': 'SAR'};
      final store = {'currency_code': 'JOD', 'currency_symbol': 'JOD'};
      expect(ProductMoney.fromAny([product, store]).code, 'SAR');
      expect(ProductMoney.fromAny([<String, dynamic>{}, store]).code, 'JOD');
      expect(ProductMoney.fromAny([null, <String, dynamic>{'price': '1'}]).isIndia, isTrue);
    });
  });
}
