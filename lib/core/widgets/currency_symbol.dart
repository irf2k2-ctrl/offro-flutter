// lib/core/widgets/currency_symbol.dart
// The ONE place a currency is drawn next to a reward amount. Today it is text: "₹" for INR, "SAR" / "ر.س" for the Saudi Riyal.
// When the official Saudi Riyal symbol asset is attached to the project, only this widget changes (render the asset for SAR);
// no screen formats a currency on its own. The symbol is never drawn or approximated here.
import 'package:flutter/widgets.dart';
import '../pricing/reward_money.dart';

class CurrencySymbol extends StatelessWidget {
  final String code;
  final String symbol;
  final TextStyle? style;
  const CurrencySymbol({super.key, required this.code, this.symbol = '', this.style});

  @override
  Widget build(BuildContext context) =>
      Text(currencyLabel(code, symbol, Localizations.localeOf(context).languageCode), style: style);
}
