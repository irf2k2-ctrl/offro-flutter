// Phase 5 staging QA regressions that are pure Dart: category translation registry, payment outcome classification, money text in
// remote templates (currency symbol exactly once). No network, no widgets.
import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/l10n/category_names.dart';
import 'package:offro_user/core/l10n/remote/remote_template.dart';
import 'package:offro_user/core/services/payment_outcome.dart';

void main() {
  group('Issues 3+5: category names follow the app language', () {
    setUp(CategoryNames.debugClear);

    test('built-in glossary covers every category from the QA screenshots, Arabic only', () {
      const names = ['Restaurant', 'Grocery', 'Pharmacy', 'Electronics', 'Fashion', 'Bakery', 'Salon', 'Fitness', 'Hospital', 'Education', 'Automobile', 'Other'];
      for (final n in names) {
        final ar = CategoryNames.translate(n, 'ar');
        expect(ar, isNotNull, reason: n);
        expect(ar, isNot(n));
      }
      expect(CategoryNames.builtin('Electronics', 'ar'), 'إلكترونيات');
      expect(CategoryNames.builtin('Electronics', 'en'), isNull); // English keeps the stored English name
    });

    test('server names (any NEW category) are registered and win over the glossary', () {
      CategoryNames.register([
        {'name': 'Pet Care', 'names': {'ar': 'رعاية الحيوانات'}},
        {'name': 'Bakery', 'names': {'AR': 'مخبوزات', 'fr': 'Boulangerie'}},
        {'name': 'NoNames'},
        'junk',
      ]);
      expect(CategoryNames.translate('Pet Care', 'ar'), 'رعاية الحيوانات');
      expect(CategoryNames.translate('  pet care ', 'ar-SA'), 'رعاية الحيوانات'); // key is trimmed/lower-case, region falls back to base
      expect(CategoryNames.translate('Bakery', 'ar'), 'مخبوزات');
      expect(CategoryNames.translate('Bakery', 'fr'), 'Boulangerie');
      expect(CategoryNames.translate('Unknown Thing', 'ar'), isNull); // caller shows it exactly as the admin typed it
    });

    test('a list is translated name by name', () {
      expect(CategoryNames.joinTranslated(['Grocery', 'Restaurant'], 'ar'), 'بقالة, مطعم');
      expect(CategoryNames.joinTranslated(['Grocery', 'Zorb'], 'ar'), 'بقالة, Zorb');
    });
  });

  group('Issue 6: payment cancellation / failure classification', () {
    test('"undefined" and empty gateway text are not shown', () {
      expect(razorpayMessageText('undefined'), '');
      expect(razorpayMessageText(null), '');
      expect(razorpayMessageText('{"error":{"description":"undefined","code":"BAD_REQUEST_ERROR"}}'), '');
      expect(razorpayMessageText('{"error":{"description":"Card declined by your bank"}}'), 'Card declined by your bank');
      expect(razorpayMessageText('not json {'), 'not json {');
    });

    test('user cancelled', () {
      expect(classifyPaymentFailure(code: 2, message: 'undefined'), PaymentOutcome.cancelled);
      expect(classifyPaymentFailure(code: 0, message: 'undefined'), PaymentOutcome.cancelled); // Android dismissal
      expect(classifyPaymentFailure(code: 5, message: 'Payment Cancelled by user'), PaymentOutcome.cancelled);
    });

    test('network / pending / failed are told apart', () {
      expect(classifyPaymentFailure(code: 0, message: 'Network error, please check your internet'), PaymentOutcome.network);
      expect(classifyPaymentFailure(code: 3, message: ''), PaymentOutcome.network);
      expect(classifyPaymentFailure(code: 4, message: 'Payment is still pending'), PaymentOutcome.pending);
      expect(classifyPaymentFailure(code: 4, message: 'Your card was declined'), PaymentOutcome.failed);
      expect(classifyPaymentFailure(code: 4, message: ''), PaymentOutcome.failed);
    });

    test('an error while CONFIRMING an accepted payment is "pending", never failed or successful', () {
      expect(classifyPaymentFailure(message: 'SocketException', afterPayment: true), PaymentOutcome.pending);
    });
  });

  group('Issue 7: currency symbol exactly once', () {
    test('recognises money text', () {
      for (final v in ['₹10.0', '₹10.50', 'SAR 115.00', '-₹5.00', '−₹5.00', 'Rs. 10', '﷼10']) {
        expect(isMoneyText(v), isTrue, reason: v);
      }
      for (final v in ['10', '10.5', '{b}', '5 days', '+91', '', 'abc']) {
        expect(isMoneyText(v), isFalse, reason: v);
      }
    });

    test('a stale translation with its own symbol never doubles it', () {
      String f(String t, String a) => fillRemoteTemplate(t, {'amount': a}).replaceAll('⁦', '').replaceAll('⁩', '');
      expect(f('ادفع ₹{amount}', '₹10.0'), 'ادفع ₹10.0');
      expect(f('تجديد · {amount}₹', '₹10.50'), 'تجديد · ₹10.50');
      expect(f('Pay Rs. {amount}', '₹10.0'), 'Pay ₹10.0');
      expect(f('ادفع {amount} ر.س', 'SAR 115.00'), 'ادفع SAR 115.00');
      expect('₹'.allMatches(f('ادفع ₹{amount} ₹', '₹10.0')).length, 1);
    });

    test('plain templates, plain numbers and the injection guard are unchanged', () {
      expect(fillRemoteTemplate('x {a} y', {'a': '{b}', 'b': 'NO'}), 'x {b} y');
      expect(fillRemoteTemplate('x {missing}', {}), 'x {missing}');
      expect(fillRemoteTemplate('{n} days · ₹5 off', {'n': '3'}), '3 days · ₹5 off'); // ₹ not next to a money placeholder: kept
    });

    test('the money text is isolated left-to-right so the symbol stays on the left in Arabic', () {
      final out = fillRemoteTemplate('تجديد · {amount}', {'amount': '₹10.50'});
      expect(out, 'تجديد · ⁦₹10.50⁩');
    });
  });
}
