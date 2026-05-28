import 'package:intl/intl.dart';

/// Formato monetario por defecto para Colombia.
class CurrencyUtils {
  static final _format = NumberFormat.currency(locale: 'es_CO', symbol: r'$ ', decimalDigits: 0);

  static String format(num? value) => value == null ? '-' : _format.format(value);
}
