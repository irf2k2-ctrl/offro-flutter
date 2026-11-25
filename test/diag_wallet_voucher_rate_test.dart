// TEMPORARY diagnostic - delete after use. Prints, layer by layer, what the app does with the walletVoucherRate remote text, so the
// failing assertion in remote_translation_service_test.dart can be explained from facts. It changes nothing and asserts only the
// layers that must hold. Run:  flutter test test/diag_wallet_voucher_rate_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:offro_user/core/l10n/remote/generated/app_localizations_ar_remote.dart';
import 'package:offro_user/core/l10n/remote/generated/remote_l10n_schema.dart';
import 'package:offro_user/core/l10n/remote/remote_template.dart';
import 'package:offro_user/core/l10n/remote/remote_translation_validator.dart';
import 'package:offro_user/l10n/gen/app_localizations_ar.dart';

String cu(String s) => s.runes.map((r) => r < 128 ? String.fromCharCode(r) : '<U+${r.toRadixString(16).toUpperCase()}>').join();

void main() {
  const key = 'walletVoucherRate';
  const oldText = '{points} نقطة = قسيمة {amount}';
  const expected = '1500 نقطة = قسيمة ⁦₹20⁩';

  test('layer by layer', () {
    // ignore: avoid_print
    void p(String s) => print('DIAG $s');
    p('schema[$key] = ${kRemoteL10nSchema[key]}   (expected [amount, points])');
    p('isMoneyText("₹20") = ${isMoneyText('₹20')}');
    p('checkValue(oldText) = ${RemoteTranslationValidator.checkValue(key, oldText, kRemoteL10nSchema) == null ? 'REJECTED' : 'accepted'}');
    p('bundled ar          = ${cu(AppLocalizationsAr().walletVoucherRate('1500', '₹20'))}');
    p('fillRemoteTemplate  = ${cu(fillRemoteTemplate(oldText, {'points': '1500', 'amount': '₹20'}))}');
    final actual = AppLocalizationsArRemote({key: oldText}).walletVoucherRate('1500', '₹20');
    p('remote class actual = ${cu(actual)}');
    p('test expects        = ${cu(expected)}');
    p('equal = ${actual == expected}');
    expect(kRemoteL10nSchema[key], ['amount', 'points']);
    expect(RemoteTranslationValidator.checkValue(key, oldText, kRemoteL10nSchema), isNotNull);
    expect(actual, expected);
  });
}
