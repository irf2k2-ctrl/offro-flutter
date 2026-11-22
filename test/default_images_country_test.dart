import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/services/api_service.dart';

void main() {
  tearDown(() => Api.customerCountry = null);

  test('unknown country keeps the original request (older behaviour)', () {
    Api.customerCountry = null;
    expect(Api.defaultImagesPath(), '/default-images');
    expect(Api.defaultImagesPath(''), '/default-images');
  });

  test('country is sent as an upper-case ISO code', () {
    expect(Api.defaultImagesPath('sa'), '/default-images?country=SA');
    Api.customerCountry = 'JO';
    expect(Api.defaultImagesPath(), '/default-images?country=JO');
  });

  test('country is derived from the stored account phone', () {
    Api.setCustomerCountryFromPhone('+966501234567');
    expect(Api.customerCountry, 'SA');
    Api.setCustomerCountryFromPhone('+9779812345678');
    expect(Api.customerCountry, 'NP');
    Api.setCustomerCountryFromPhone('9876543210');
    expect(Api.customerCountry, 'IN');
    Api.setCustomerCountryFromPhone(null);
    expect(Api.customerCountry, isNull);
    expect(Api.defaultImagesPath(), '/default-images');
  });
}
