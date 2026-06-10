import 'json_value.dart';

/// A normalized 2D point read from flexible chart JSON data.
class ChartPointValue {
  final double x;
  final double y;
  final String? label;
  final Object? raw;

  const ChartPointValue({
    required this.x,
    required this.y,
    this.label,
    this.raw,
  });
}

class ChartCartesianBounds {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const ChartCartesianBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  ChartCartesianBounds ensureNonZeroSpan() {
    final nextMaxX = maxX <= minX ? minX + 1 : maxX;
    final nextMaxY = maxY <= minY ? minY + 1 : maxY;
    return ChartCartesianBounds(
      minX: minX,
      maxX: nextMaxX,
      minY: minY,
      maxY: nextMaxY,
    );
  }
}

/// Defensive helpers for chart data payloads that can arrive as decoded JSON,
/// typed Dart maps, or hand-written object literals.
class ChartDataValueReader {
  const ChartDataValueReader._();

  static double? numeric(Object? value) {
    final parsed = JsonValue.doubleOrNull(value);
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  static double yValue(Object? item, {double fallback = 0}) {
    return yValueOrNull(item) ?? fallback;
  }

  static double? yValueOrNull(Object? item) {
    if (item == null) return null;

    final scalar = numeric(item);
    if (scalar != null) return scalar;

    if (item is List) {
      if (item.length > 1) {
        final y = numeric(item[1]);
        if (y != null) return y;
      }
      if (item.isNotEmpty) {
        final first = numeric(item.first);
        if (first != null) return first;
      }
      if (item.isNotEmpty) {
        final last = numeric(item.last);
        if (last != null) return last;
      }
      return null;
    }

    final map = JsonValue.map(item);
    if (map != null) {
      if (_hasCompleteOhlcMap(map)) {
        return _ohlcCloseFromMap(map);
      }
      for (final key in const [
        'y',
        'value',
        'close',
        'mean',
        'amount',
        'count',
        'size',
      ]) {
        final value = numeric(map[key]);
        if (value != null) return value;
      }
      return null;
    }

    try {
      final dynamic dynamicItem = item;
      return numeric(dynamicItem.value);
    } catch (_) {
      return null;
    }
  }

  /// Reads the close price from an OHLC/candlestick row.
  ///
  /// Supported row shapes mirror the candlestick parser:
  /// - `[open, high, low, close, volume?]`
  /// - `[date, open, high, low, close, volume?]`
  /// - `{open, high, low, close, volume?}`
  static double? ohlcCloseValueOrNull(Object? item) {
    if (item == null) return null;

    final map = JsonValue.map(item);
    if (map != null) {
      final validatedClose = _ohlcCloseFromMap(map);
      if (validatedClose != null) return validatedClose;
      if (_hasCompleteOhlcMap(map)) return null;
      return numeric(map['close']) ?? yValueOrNull(item);
    }

    if (item is List) {
      final close = _ohlcCloseFromList(item);
      if (close != null) return close;
      if (_hasCompleteOhlcList(item)) return null;
      return yValueOrNull(item);
    }

    return yValueOrNull(item);
  }

  static double? _ohlcCloseFromList(List<dynamic> row) {
    return _ohlcCloseAtBase(row, 0) ?? _ohlcCloseAtBase(row, 1);
  }

  static double? _ohlcCloseAtBase(List<dynamic> row, int base) {
    if (row.length < base + 4) return null;
    final open = numeric(row[base]);
    final high = numeric(row[base + 1]);
    final low = numeric(row[base + 2]);
    final close = numeric(row[base + 3]);
    if (open == null || high == null || low == null || close == null) {
      return null;
    }
    if (!_isValidOhlc(open: open, high: high, low: low, close: close)) {
      return null;
    }
    return close;
  }

  static bool _hasCompleteOhlcList(List<dynamic> row) {
    return _hasCompleteOhlcListAtBase(row, 0) ||
        _hasCompleteOhlcListAtBase(row, 1);
  }

  static bool _hasCompleteOhlcListAtBase(List<dynamic> row, int base) {
    if (row.length < base + 4) return false;
    return numeric(row[base]) != null &&
        numeric(row[base + 1]) != null &&
        numeric(row[base + 2]) != null &&
        numeric(row[base + 3]) != null;
  }

  static double? _ohlcCloseFromMap(Map<String, dynamic> map) {
    final open = numeric(map['open']);
    final high = numeric(map['high']);
    final low = numeric(map['low']);
    final close = numeric(map['close']);
    if (open == null || high == null || low == null || close == null) {
      return null;
    }
    if (!_isValidOhlc(open: open, high: high, low: low, close: close)) {
      return null;
    }
    return close;
  }

  static bool _hasCompleteOhlcMap(Map<String, dynamic> map) {
    return map.containsKey('open') &&
        map.containsKey('high') &&
        map.containsKey('low') &&
        map.containsKey('close');
  }

  static bool _isValidOhlc({
    required double open,
    required double high,
    required double low,
    required double close,
  }) {
    if (high < low) return false;
    if (high < open || high < close) return false;
    if (low > open || low > close) return false;
    return true;
  }

  static ChartPointValue? cartesian(Object? item, int fallbackIndex) {
    if (item == null) return null;

    final scalar = numeric(item);
    if (scalar != null) {
      return ChartPointValue(x: fallbackIndex.toDouble(), y: scalar, raw: item);
    }

    if (item is List) {
      return _cartesianFromList(item, fallbackIndex);
    }

    final map = JsonValue.map(item);
    if (map != null) {
      return _cartesianFromMap(map, fallbackIndex, item);
    }

    final value = yValueOrNull(item);
    if (value == null) return null;
    return ChartPointValue(x: fallbackIndex.toDouble(), y: value, raw: item);
  }

  static ChartCartesianBounds? bounds(Iterable<List<dynamic>?> dataSets) {
    double? minX;
    double? maxX;
    double? minY;
    double? maxY;

    for (final data in dataSets) {
      if (data == null) continue;
      for (var i = 0; i < data.length; i++) {
        final point = cartesian(data[i], i);
        if (point == null) continue;
        minX = minX == null || point.x < minX ? point.x : minX;
        maxX = maxX == null || point.x > maxX ? point.x : maxX;
        minY = minY == null || point.y < minY ? point.y : minY;
        maxY = maxY == null || point.y > maxY ? point.y : maxY;
      }
    }

    if (minX == null || maxX == null || minY == null || maxY == null) {
      return null;
    }

    return ChartCartesianBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY);
  }

  static ChartPointValue? _cartesianFromList(
    List<dynamic> row,
    int fallbackIndex,
  ) {
    if (row.isEmpty) return null;

    if (row.length == 1) {
      final y = numeric(row.first);
      if (y == null) return null;
      return ChartPointValue(x: fallbackIndex.toDouble(), y: y, raw: row);
    }

    final explicitX = numeric(row[0]);
    final y = numeric(row[1]) ?? numeric(row.last);
    if (y == null) return null;

    return ChartPointValue(
      x: explicitX ?? fallbackIndex.toDouble(),
      y: y,
      label: explicitX == null ? row[0]?.toString() : null,
      raw: row,
    );
  }

  static ChartPointValue? _cartesianFromMap(
    Map<String, dynamic> map,
    int fallbackIndex,
    Object raw,
  ) {
    final y = yValueOrNull(map);
    if (y == null) return null;

    final x =
        numeric(map['x']) ??
        numeric(map['time']) ??
        numeric(map['timestamp']) ??
        fallbackIndex.toDouble();

    return ChartPointValue(
      x: x,
      y: y,
      label: JsonValue.string(map['label']) ?? JsonValue.string(map['name']),
      raw: raw,
    );
  }
}
