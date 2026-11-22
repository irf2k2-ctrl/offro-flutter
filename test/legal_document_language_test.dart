// Legal / information documents are requested in the language the app is showing (Stage 2).
// English and unknown values keep the request exactly as before; other languages add ?lang=<code>.
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/services/api_service.dart';

void main() {
  group('Api.withDocLang', () {
    test('English keeps the existing URL unchanged', () {
      expect(Api.withDocLang('/policy/privacy', 'en'), '/policy/privacy');
      expect(Api.withDocLang('/terms/user', 'EN'), '/terms/user');
      expect(Api.withDocLang('/about', ''), '/about');
    });
    test('another language adds the language code', () {
      expect(Api.withDocLang('/policy/privacy', 'ar'), '/policy/privacy?lang=ar');
      expect(Api.withDocLang('/merchant/terms', ' AR '), '/merchant/terms?lang=ar');
      expect(Api.withDocLang('/about?x=1', 'ar'), '/about?x=1&lang=ar');
    });
    test('an unsafe or malformed code is never put in the URL', () {
      for (final bad in ['ar&x=1', 'ar/../x', 'a', 'arabic', '<script>', 'ar sa']) {
        expect(Api.withDocLang('/policy/kyc', bad), '/policy/kyc');
      }
    });
  });
}
