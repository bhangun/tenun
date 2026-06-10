import 'package:intl/intl.dart';

/// Locale-aware formatters for tooltips & axis labels.
class ChartFormatters {
  static String compact(double value, {String? locale}) {
    final fmt = NumberFormat.compact(locale: locale);
    return fmt.format(value);
  }

  static String precise(double value, int decimals, {String? locale}) {
    final fmt = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimals,
    );
    return fmt.format(value);
  }

  static String percent(double value, {String? locale}) {
    final fmt = NumberFormat.percentPattern(locale);
    return fmt.format(value / 100);
  }

  static String date(DateTime dt, String pattern, {String? locale}) {
    final fmt = DateFormat(pattern, locale);
    return fmt.format(dt);
  }
}
