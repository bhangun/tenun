import 'package:intl/intl.dart';

/// Production-ready formatters for tooltips, axis labels, and legends.
class TenunFormatters {
  TenunFormatters._();

  static final Map<String, NumberFormat> _numCache = {};
  static final Map<String, DateFormat> _dateCache = {};

  /// Compact number: 1.2K, 1.5M, etc.
  static String compact(double value, {String? locale}) {
    final key = 'compact_${locale ?? 'en'}';
    final fmt = _numCache.putIfAbsent(
      key,
      () => NumberFormat.compact(locale: locale),
    );
    return fmt.format(value);
  }

  /// Fixed precision with thousand separators
  static String precise(double value, int decimals, {String? locale}) {
    final key = 'precise_${decimals}_${locale ?? 'en'}';
    final fmt = _numCache.putIfAbsent(
      key,
      () => NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: decimals,
      ),
    );
    return fmt.format(value);
  }

  /// Percentage formatter
  static String percent(double value, int decimals, {String? locale}) {
    final key = 'pct_${decimals}_${locale ?? 'en'}';
    final fmt = _numCache.putIfAbsent(
      key,
      () => NumberFormat.percentPattern(locale),
    );
    final raw = fmt.format(value / 100);
    return raw.replaceAll('%', ' %').trim(); // ECharts style spacing
  }

  /// Date axis formatter
  static String date(DateTime dt, String pattern, {String? locale}) {
    final key = 'date_${pattern}_$locale';
    final fmt = _dateCache.putIfAbsent(key, () => DateFormat(pattern, locale));
    return fmt.format(dt);
  }

  /// Clear caches when locale changes at runtime
  static void clearCache() {
    _numCache.clear();
    _dateCache.clear();
  }
}
