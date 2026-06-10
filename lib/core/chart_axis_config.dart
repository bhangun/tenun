// Axis scale configuration for chart rendering.
//
// Provides a strongly-typed config layer between JSON/config and the
// chart painters so that any chart type can request a specific scale
// without coupling to the painter implementation.
//
// Supported scales:
//  - [AxisScaleType.linear]   — default numeric axis
//  - [AxisScaleType.log]      — logarithmic (base configurable)
//  - [AxisScaleType.time]     — DateTime-based axis
//  - [AxisScaleType.category] — discrete string categories
//  - [AxisScaleType.percent]  — 0–100 normalised axis

import 'dart:math' as math;

import 'json_value.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum AxisScaleType { linear, log, time, category, percent }

enum AxisPosition { left, right, top, bottom }

// ---------------------------------------------------------------------------
// ChartAxisConfig
// ---------------------------------------------------------------------------

/// Describes one axis on a chart (X or Y).
class ChartAxisConfig {
  /// Axis scaling algorithm.
  final AxisScaleType scaleType;

  /// Where this axis is rendered.
  final AxisPosition position;

  /// Human-readable axis label (optional).
  final String? label;

  /// Override minimum value. If null, computed from data.
  final double? min;

  /// Override maximum value. If null, computed from data.
  final double? max;

  /// Number of tick marks. Ignored for [AxisScaleType.category].
  final int tickCount;

  /// If [scaleType] is [AxisScaleType.log], the logarithm base (default 10).
  final double logBase;

  /// Discrete category labels, ordered. Required when
  /// [scaleType] == [AxisScaleType.category].
  final List<String>? categories;

  /// Custom tick formatter. If null, a sensible default is used.
  final String Function(double value)? tickFormatter;

  /// Custom tick formatter for DateTime ticks (used with [AxisScaleType.time]).
  final String Function(DateTime dt)? timeFormatter;

  /// Whether to show the axis line.
  final bool showAxisLine;

  /// Whether to show tick marks.
  final bool showTicks;

  /// Whether to show grid lines projected from this axis.
  final bool showGrid;

  /// Whether to show axis label text.
  final bool showLabels;

  /// Whether to invert the axis direction.
  final bool inverted;

  const ChartAxisConfig({
    this.scaleType = AxisScaleType.linear,
    this.position = AxisPosition.left,
    this.label,
    this.min,
    this.max,
    this.tickCount = 5,
    this.logBase = 10,
    this.categories,
    this.tickFormatter,
    this.timeFormatter,
    this.showAxisLine = true,
    this.showTicks = true,
    this.showGrid = true,
    this.showLabels = true,
    this.inverted = false,
  });

  // ---------- Convenience factories ----------

  const ChartAxisConfig.linear({
    AxisPosition position = AxisPosition.left,
    double? min,
    double? max,
    int tickCount = 5,
    String? label,
    bool showGrid = true,
  }) : this(
         scaleType: AxisScaleType.linear,
         position: position,
         min: min,
         max: max,
         tickCount: tickCount,
         label: label,
         showGrid: showGrid,
       );

  const ChartAxisConfig.log({
    AxisPosition position = AxisPosition.left,
    double? min,
    double? max,
    double logBase = 10,
    String? label,
  }) : this(
         scaleType: AxisScaleType.log,
         position: position,
         min: min,
         max: max,
         logBase: logBase,
         label: label,
       );

  const ChartAxisConfig.category({
    AxisPosition position = AxisPosition.bottom,
    required List<String> categories,
    String? label,
    bool showGrid = false,
  }) : this(
         scaleType: AxisScaleType.category,
         position: position,
         categories: categories,
         label: label,
         showGrid: showGrid,
       );

  const ChartAxisConfig.time({
    AxisPosition position = AxisPosition.bottom,
    double? min,
    double? max,
    int tickCount = 6,
    String? label,
  }) : this(
         scaleType: AxisScaleType.time,
         position: position,
         min: min,
         max: max,
         tickCount: tickCount,
         label: label,
       );

  const ChartAxisConfig.percent({
    AxisPosition position = AxisPosition.left,
    String? label,
  }) : this(
         scaleType: AxisScaleType.percent,
         position: position,
         min: 0,
         max: 100,
         label: label,
       );

  // ---------- Scale helpers ----------

  /// Convert a raw data value to [0..1] normalised.
  ///
  /// For [AxisScaleType.log], values ≤ 0 are clamped to a tiny positive.
  double normalize(double value, double dataMin, double dataMax) {
    final lo = _finite(min ?? dataMin, 0);
    final hi = _finite(max ?? dataMax, lo);
    if (!value.isFinite) return 0.5;
    if (hi == lo) return 0.5;

    switch (scaleType) {
      case AxisScaleType.linear:
      case AxisScaleType.time:
      case AxisScaleType.percent:
        return _unitInterval((value - lo) / (hi - lo));

      case AxisScaleType.log:
        final safeBase = _safeLogBase(logBase);
        final logLo =
            math.log(lo.clamp(1e-10, double.infinity)) / math.log(safeBase);
        final logHi =
            math.log(hi.clamp(1e-10, double.infinity)) / math.log(safeBase);
        final logV =
            math.log(value.clamp(1e-10, double.infinity)) / math.log(safeBase);
        if (logHi == logLo) return 0.5;
        return _unitInterval((logV - logLo) / (logHi - logLo));

      case AxisScaleType.category:
        final cats = categories ?? const [];
        if (cats.isEmpty) return 0;
        if (cats.length == 1) return 0.5;
        final idx = value.round().clamp(0, cats.length - 1);
        return idx / (cats.length - 1);
    }
  }

  /// Generate tick values in data space.
  List<double> computeTicks(double dataMin, double dataMax) {
    final lo = _finite(min ?? dataMin, 0);
    final hi = _finite(max ?? dataMax, lo);

    switch (scaleType) {
      case AxisScaleType.linear:
      case AxisScaleType.time:
      case AxisScaleType.percent:
        return _linearTicks(lo, hi, tickCount);

      case AxisScaleType.log:
        return _logTicks(lo, hi, _safeLogBase(logBase));

      case AxisScaleType.category:
        final cats = categories ?? const [];
        return List.generate(cats.length, (i) => i.toDouble());
    }
  }

  /// Format a tick value as a display string.
  String formatTick(double value) {
    if (tickFormatter != null) return tickFormatter!(value);
    switch (scaleType) {
      case AxisScaleType.percent:
        return '${value.toStringAsFixed(0)}%';
      case AxisScaleType.log:
        // Display as power: 10^n
        return _formatLogTick(value, logBase);
      case AxisScaleType.category:
        final cats = categories ?? const [];
        final idx = value.round();
        return (idx >= 0 && idx < cats.length) ? cats[idx] : '';
      case AxisScaleType.time:
        if (timeFormatter != null) {
          return timeFormatter!(
            DateTime.fromMillisecondsSinceEpoch(value.round()),
          );
        }
        return _formatTimeTick(value);
      default:
        return _formatNumber(value);
    }
  }

  // ---------- Internal ----------

  static List<double> _linearTicks(double lo, double hi, int count) {
    final safeCount = _safeTickCount(count);
    if (safeCount == 0) return const [];

    final safeLo = _finite(lo, 0);
    final safeHi = _finite(hi, safeLo);
    if (safeCount == 1) {
      return [safeLo == safeHi ? safeLo : (safeLo + safeHi) / 2];
    }
    if (safeLo == safeHi) return List.filled(safeCount, safeLo);

    final step = _niceStep((safeHi - safeLo).abs() / (safeCount - 1));
    if (step <= 0 || !step.isFinite) return List.filled(safeCount, safeLo);

    final niceMin = (math.min(safeLo, safeHi) / step).floor() * step;
    return List.generate(safeCount, (i) => niceMin + i * step);
  }

  static List<double> _logTicks(double lo, double hi, double base) {
    final safeBase = _safeLogBase(base);
    final safeLo = _positiveFinite(lo, 1e-10);
    final safeHi = _positiveFinite(hi, safeLo);
    final lower = math.min(safeLo, safeHi);
    final upper = math.max(safeLo, safeHi);
    if (lower == upper) return [lower];

    final logLo = (math.log(lower) / math.log(safeBase)).ceil();
    final logHi = (math.log(upper) / math.log(safeBase)).ceil();
    return List.generate(
      (logHi - logLo + 1).clamp(1, 20).toInt(),
      (i) => math.pow(safeBase, logLo + i).toDouble(),
    );
  }

  static double _niceStep(double rough) {
    if (rough <= 0) return 1;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final norm = rough / mag;
    if (norm <= 1) return mag;
    if (norm <= 2) return 2 * mag;
    if (norm <= 5) return 5 * mag;
    return 10 * mag;
  }

  static String _formatLogTick(double value, double base) {
    if (value <= 0 || !value.isFinite) return _formatNumber(value);
    final safeBase = _safeLogBase(base);
    if (safeBase == 10) {
      final exp = math.log(value) / math.ln10;
      if ((exp - exp.roundToDouble()).abs() < 0.001) {
        return '10^${exp.round()}';
      }
    }
    return _formatNumber(value);
  }

  static String _formatTimeTick(double ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms.round());
    return '${dt.month}/${dt.day}';
  }

  static String _formatNumber(double v) {
    if (!v.isFinite) return '';
    if (v.abs() >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  static double _finite(double value, double fallback) =>
      value.isFinite ? value : fallback;

  static double _positiveFinite(double value, double fallback) =>
      value.isFinite && value > 0 ? value : fallback;

  static double _safeLogBase(double base) =>
      base.isFinite && base > 0 && base != 1 ? base : 10;

  static int _safeTickCount(int count) => count.clamp(0, 1000).toInt();

  static double _unitInterval(double value) =>
      value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.5;

  // ---------- JSON ----------

  factory ChartAxisConfig.fromJson(Object? raw) {
    final json = JsonValue.map(raw);
    if (json == null) return const ChartAxisConfig();
    final scaleStr = json['scale']?.toString().toLowerCase() ?? 'linear';
    final scale = switch (scaleStr) {
      'log' => AxisScaleType.log,
      'time' => AxisScaleType.time,
      'category' => AxisScaleType.category,
      'percent' => AxisScaleType.percent,
      _ => AxisScaleType.linear,
    };
    final posStr = json['position']?.toString().toLowerCase() ?? 'left';
    final pos = switch (posStr) {
      'right' => AxisPosition.right,
      'top' => AxisPosition.top,
      'bottom' => AxisPosition.bottom,
      _ => AxisPosition.left,
    };
    return ChartAxisConfig(
      scaleType: scale,
      position: pos,
      label: json['label']?.toString(),
      min: JsonValue.doubleOrNull(json['min']),
      max: JsonValue.doubleOrNull(json['max']),
      tickCount: JsonValue.intOrNull(json['tickCount']) ?? 5,
      logBase: JsonValue.doubleOrNull(json['logBase']) ?? 10,
      categories: JsonValue.stringList(json['categories']),
      showAxisLine: JsonValue.boolOrNull(json['showAxisLine']) ?? true,
      showTicks: JsonValue.boolOrNull(json['showTicks']) ?? true,
      showGrid: JsonValue.boolOrNull(json['showGrid']) ?? true,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? true,
      inverted: JsonValue.boolOrNull(json['inverted']) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'scale': scaleType.name,
    'position': position.name,
    if (label != null) 'label': label,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    'tickCount': tickCount,
    'logBase': logBase,
    if (categories != null)
      'categories': List<String>.from(categories!, growable: false),
    'showAxisLine': showAxisLine,
    'showTicks': showTicks,
    'showGrid': showGrid,
    'showLabels': showLabels,
    'inverted': inverted,
  };
}
