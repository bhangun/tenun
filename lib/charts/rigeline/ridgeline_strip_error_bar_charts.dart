/// Three distribution / comparison charts:
///   1. `RidgelineChartConfig`  — offset density curves (joy plot)
///   2. `StripChartConfig`      — dot strip plot (all individual points)
///   3. `ErrorBarChartConfig`   — mean ± error bars / confidence intervals
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_data_processor.dart';
import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/json_value.dart';

// ─────────────────────────────────────────────────────────
// Shared KDE helper
// ─────────────────────────────────────────────────────────

List<({double x, double d})> _kde1d(
  List<double> data,
  double xMin,
  double xMax,
  int steps,
) {
  if (data.isEmpty) return [];
  final n = data.length;
  final mean = data.fold(0.0, (a, b) => a + b) / n;
  final std = math
      .sqrt(data.fold(0.0, (a, b) => a + (b - mean) * (b - mean)) / n)
      .clamp(0.01, 1e9);
  final bw = std * math.pow(n, -0.2) * 1.06;
  return List.generate(steps + 1, (i) {
    final x = xMin + i / steps * (xMax - xMin);
    double d = 0;
    for (final v in data) {
      final z = (x - v) / bw;
      d += math.exp(-0.5 * z * z);
    }
    return (x: x, d: d / (n * bw * math.sqrt(2 * math.pi)));
  });
}

List<String> _stringValues(Object? raw) =>
    JsonValue.stringList(raw) ?? const <String>[];

List<Series> _seriesValues(Object? raw) {
  final rawSeries = JsonValue.list(raw) ?? const <dynamic>[];
  return rawSeries
      .map(JsonValue.map)
      .whereType<Map<String, dynamic>>()
      .map(Series.fromJson)
      .toList(growable: false);
}

List<double> _numericRowValues(Object? row) {
  final rawList = JsonValue.list(row);
  if (rawList != null) {
    final values = <double>[];
    for (final item in rawList) {
      final parsed = JsonValue.doubleOrNull(item);
      if (parsed != null) values.add(parsed);
    }
    return values;
  }

  final scalar = JsonValue.doubleOrNull(row);
  return scalar == null ? const <double>[] : <double>[scalar];
}

// ═══════════════════════════════════════════════════════════
// 1. RIDGELINE (JOY PLOT)
// ═══════════════════════════════════════════════════════════

/// Overlapping density curves, one per category, offset vertically.
/// JSON:
/// ```json
/// { "type": "ridgeline",
///   "categories": ["2021","2022","2023","2024"],
///   "series": [{
///     "data": [
///       [55,62,68,72,75,80,58,61],
///       [60,65,70,73,78,82,67,71],
///       [58,66,72,76,80,85,64,69],
///       [63,70,74,79,83,88,70,74]
///     ]
///   }]
/// }
/// ```
class RidgelineChartConfig extends BaseChartConfig {
  final List<String> categories;
  final double overlap; // 0=no overlap, 1=full overlap
  final double fillOpacity;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  RidgelineChartConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.overlap = 0.5,
    this.fillOpacity = 0.7,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.ridgeline);

  @override
  Widget buildChart() => RidgelineChartWidget(config: this);

  factory RidgelineChartConfig.fromJson(Map<String, dynamic> json) {
    return RidgelineChartConfig(
      categories: _stringValues(json['categories']),
      series: _seriesValues(json['series']),
      overlap: JsonValue.doubleOrNull(json['overlap']) ?? 0.5,
      fillOpacity: JsonValue.doubleOrNull(json['fillOpacity']) ?? 0.7,
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      tooltip: json['tooltip'] != null
          ? ChartTooltip.fromJson(json['tooltip'])
          : null,
      legend: json['legend'] != null
          ? ChartLegend.fromJson(json['legend'])
          : null,
      toolbox: json['toolbox'] != null
          ? ChartToolbox.fromJson(json['toolbox'])
          : null,
      grid: json['grid'] != null ? GridData.fromJson(json['grid']) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'overlap': overlap,
    'fillOpacity': fillOpacity,
  };
}

class RidgelineChartWidget extends StatefulWidget {
  final RidgelineChartConfig config;
  const RidgelineChartWidget({super.key, required this.config});
  @override
  State<RidgelineChartWidget> createState() => _RidgeState();
}

class _RidgeState extends State<RidgelineChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  RidgelineChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _dataSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(RidgelineChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (cfg.title?.text != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Text(
            cfg.title!.text!,
            style: cfg.theme.typography.titleStyle.copyWith(
              color: cfg.theme.titleColor,
            ),
          ),
        ),
      Expanded(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _RidgePainter(
              config: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
    ],
  );
}

class _RidgePainter extends ChartPainterBase {
  final RidgelineChartConfig config;
  final double progress;
  final String dataSignature;

  _RidgePainter({
    required this.config,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _RidgePainter old) =>
      old.progress != progress || old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = config.categories.length;
    if (n == 0 || config.series.isEmpty) return;
    final sp = theme.spacing;

    // collect all values for global X range
    final allVals = <double>[];
    for (final s in config.series) {
      for (final row in s.data ?? []) {
        allVals.addAll(_numericRowValues(row));
      }
    }
    if (allVals.isEmpty) return;
    var xMin = allVals.reduce(math.min);
    var xMax = allVals.reduce(math.max);
    if (xMin == xMax) {
      xMin -= 0.5;
      xMax += 0.5;
    }

    final plotL = sp.chartPaddingLeft + 60.0;
    final plotR = size.width - sp.chartPaddingRight;
    final plotT = sp.chartPaddingTop;
    final plotB = size.height - sp.chartPaddingBottom;
    final plotW = plotR - plotL;
    final rowH = (plotB - plotT) / (n - config.overlap * (n - 1));

    // Draw back-to-front (bottom cat first so upper ones paint over)
    final seriesData = config.series.first.data ?? [];
    for (int ci = n - 1; ci >= 0; ci--) {
      final color = theme.palette.colorObjectAt(ci);
      final baseY = plotT + ci * rowH * (1 - config.overlap);
      final vals = ci < seriesData.length
          ? _numericRowValues(seriesData[ci])
          : <double>[];

      if (vals.isEmpty) continue;
      final kdePts = _kde1d(vals, xMin, xMax, 80);
      final maxD = kdePts.map((p) => p.d).reduce(math.max).clamp(1e-9, 1e18);

      // Build path
      final path = Path()..moveTo(plotL, baseY + rowH);
      for (final p in kdePts) {
        final x = plotL + (p.x - xMin) / (xMax - xMin) * plotW;
        final h = (p.d / maxD) * rowH * progress;
        path.lineTo(x, baseY + rowH - h);
      }
      path.lineTo(plotR, baseY + rowH);
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: config.fillOpacity)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawPath(path, paintCache.stroke(color, 1.5));

      // Category label
      final tp = textPainterCache.get(
        config.categories[ci],
        theme.typography.axisLabelStyle.copyWith(color: theme.axisLabelColor),
        maxWidth: 55,
        align: TextAlign.right,
      );
      tp.paint(
        canvas,
        Offset(plotL - tp.width - 6, baseY + rowH - tp.height - 4),
      );
    }

    // X axis tick labels
    const ticks = 5;
    for (int i = 0; i <= ticks; i++) {
      final x = plotL + i / ticks * plotW;
      final val = xMin + i / ticks * (xMax - xMin);
      final tp = textPainterCache.get(
        val.toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
      );
      tp.paint(canvas, Offset(x - tp.width / 2, plotB + 2));
    }
    canvas.drawLine(Offset(plotL, plotB), Offset(plotR, plotB), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════
// 2. STRIP / DOT PLOT
// ═══════════════════════════════════════════════════════════

/// Every individual data point plotted as a dot on a strip per category.
/// Jitter added horizontally to avoid overplotting.
/// JSON:
/// ```json
/// { "type": "strip",
///   "categories": ["Group A","Group B","Group C"],
///   "series": [{
///     "data": [[55,60,58,72,45,68],[78,82,75,88,71,80],[40,52,48,61,44,56]]
///   }]}
/// ```
class StripChartConfig extends BaseChartConfig {
  final List<String> categories;
  final double dotRadius;
  final double dotOpacity;
  final bool showMean;
  final bool showMedian;
  final int jitterSeed;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  StripChartConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.dotRadius = 4.0,
    this.dotOpacity = 0.65,
    this.showMean = true,
    this.showMedian = false,
    this.jitterSeed = 42,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.strip);

  @override
  Widget buildChart() => StripChartWidget(config: this);

  factory StripChartConfig.fromJson(Map<String, dynamic> json) {
    return StripChartConfig(
      categories: _stringValues(json['categories']),
      series: _seriesValues(json['series']),
      dotRadius: JsonValue.doubleOrNull(json['dotRadius']) ?? 4.0,
      dotOpacity: JsonValue.doubleOrNull(json['dotOpacity']) ?? 0.65,
      showMean: JsonValue.boolOrNull(json['showMean']) ?? true,
      showMedian: JsonValue.boolOrNull(json['showMedian']) ?? false,
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      tooltip: json['tooltip'] != null
          ? ChartTooltip.fromJson(json['tooltip'])
          : null,
      legend: json['legend'] != null
          ? ChartLegend.fromJson(json['legend'])
          : null,
      toolbox: json['toolbox'] != null
          ? ChartToolbox.fromJson(json['toolbox'])
          : null,
      grid: json['grid'] != null ? GridData.fromJson(json['grid']) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'dotRadius': dotRadius,
    'dotOpacity': dotOpacity,
    'showMean': showMean,
    'showMedian': showMedian,
    'jitterSeed': jitterSeed,
  };
}

class StripChartWidget extends StatefulWidget {
  final StripChartConfig config;
  const StripChartWidget({super.key, required this.config});
  @override
  State<StripChartWidget> createState() => _StripState();
}

class _StripState extends State<StripChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  StripChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _dataSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(StripChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (cfg.title?.text != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Text(
            cfg.title!.text!,
            style: cfg.theme.typography.titleStyle.copyWith(
              color: cfg.theme.titleColor,
            ),
          ),
        ),
      Expanded(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _StripPainter(
              config: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
    ],
  );
}

class _StripPainter extends ChartPainterBase {
  final StripChartConfig config;
  final double progress;
  final String dataSignature;

  _StripPainter({
    required this.config,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _StripPainter old) =>
      old.progress != progress || old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = config.categories.length;
    if (n == 0 || config.series.isEmpty) return;
    final sp = theme.spacing;

    final seriesData = config.series.first.data ?? [];
    final allVals = <double>[];
    for (final row in seriesData) {
      allVals.addAll(_numericRowValues(row));
    }
    if (allVals.isEmpty) return;

    final yMin = allVals.reduce(math.min);
    final yMax = allVals.reduce(math.max);
    final ySpan = (yMax - yMin).abs();
    final pad = ySpan == 0 ? 1.0 : ySpan * 0.1;
    final vp = ChartViewport(
      left: sp.chartPaddingLeft,
      top: sp.chartPaddingTop,
      right: size.width - sp.chartPaddingRight,
      bottom: size.height - sp.chartPaddingBottom,
      dataMinX: 0,
      dataMaxX: n.toDouble(),
      dataMinY: yMin - pad,
      dataMaxY: yMax + pad,
    );

    final yTicks = ChartDataProcessor.niceYTicks(vp.dataMinY, vp.dataMaxY);
    drawHorizontalGrid(canvas, vp, yTicks);
    drawYAxisLabels(canvas, vp, yTicks, (v) => v.toStringAsFixed(1));

    final slotW = vp.width / n;
    final jitterW = slotW * 0.35;
    final rng = math.Random(config.jitterSeed);

    for (int ci = 0; ci < n; ci++) {
      final row = ci < seriesData.length ? seriesData[ci] : null;
      if (row == null) continue;
      final vals = _numericRowValues(row);
      if (vals.isEmpty) continue;

      final cx = vp.left + (ci + 0.5) * slotW;
      final color = theme.palette.colorObjectAt(ci);

      for (final v in vals) {
        final cy = vp.toCanvasY(vp.dataMinY + (v - vp.dataMinY) * progress);
        final jx = cx + (rng.nextDouble() - 0.5) * jitterW;
        canvas.drawCircle(
          Offset(jx, cy),
          config.dotRadius,
          Paint()
            ..color = color.withValues(alpha: config.dotOpacity)
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
      }

      // Mean line
      if (config.showMean) {
        final mean = vals.fold(0.0, (a, b) => a + b) / vals.length;
        final my = vp.toCanvasY(mean);
        canvas.drawLine(
          Offset(cx - slotW * 0.3, my),
          Offset(cx + slotW * 0.3, my),
          paintCache.stroke(color, 2.5),
        );
      }

      // Median line
      if (config.showMedian) {
        final sorted = [...vals]..sort();
        final nm = sorted.length;
        final med = nm % 2 == 0
            ? (sorted[nm ~/ 2 - 1] + sorted[nm ~/ 2]) / 2
            : sorted[nm ~/ 2].toDouble();
        final medy = vp.toCanvasY(med);
        canvas.drawLine(
          Offset(cx - slotW * 0.25, medy),
          Offset(cx + slotW * 0.25, medy),
          paintCache.stroke(Colors.black54, 1.5),
        );
      }
    }

    drawXAxisLabels(
      canvas,
      vp,
      config.categories,
      List.generate(n, (i) => vp.left + (i + 0.5) * slotW),
    );
    canvas.drawLine(
      Offset(vp.left, vp.bottom),
      Offset(vp.right, vp.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(vp.left, vp.top),
      Offset(vp.left, vp.bottom),
      axisPaint,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 3. ERROR BAR CHART
// ═══════════════════════════════════════════════════════════

/// Mean value bars/lines with ± error whiskers.
/// Supports asymmetric errors, CI ranges, and multiple series.
/// JSON:
/// ```json
/// { "type": "errorBar",
///   "categories": ["Method A","Method B","Method C"],
///   "series": [{
///     "name": "Accuracy",
///     "data": [
///       { "mean": 0.82, "lower": 0.76, "upper": 0.88 },
///       { "mean": 0.79, "lower": 0.74, "upper": 0.84 },
///       { "mean": 0.91, "lower": 0.87, "upper": 0.95 }
///     ]
///   }]}
/// ```
class ErrorBarPoint {
  final double mean;
  final double lower; // absolute lower bound
  final double upper; // absolute upper bound
  const ErrorBarPoint({
    required this.mean,
    required this.lower,
    required this.upper,
  });

  factory ErrorBarPoint.fromJson(Map<String, dynamic> j) {
    final mean =
        JsonValue.doubleOrNull(j['mean']) ??
        JsonValue.doubleOrNull(j['value']) ??
        0.0;
    final err = JsonValue.doubleOrNull(j['error']);
    return ErrorBarPoint(
      mean: mean,
      lower: err != null
          ? mean - err
          : JsonValue.doubleOrNull(j['lower']) ?? mean,
      upper: err != null
          ? mean + err
          : JsonValue.doubleOrNull(j['upper']) ?? mean,
    );
  }

  Map<String, dynamic> toJson() => {
    'mean': mean,
    'lower': lower,
    'upper': upper,
  };
}

ErrorBarPoint? _errorBarPointOrNull(Object? item) {
  final json = JsonValue.map(item);
  if (json != null) return ErrorBarPoint.fromJson(json);

  final value = JsonValue.doubleOrNull(item);
  if (value == null) return null;
  return ErrorBarPoint(mean: value, lower: value, upper: value);
}

class ErrorBarChartConfig extends BaseChartConfig {
  final List<String> categories;
  final List<List<ErrorBarPoint>> errorData; // [series][category]
  final bool horizontal;
  final bool showLine; // connect means with a line
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  ErrorBarChartConfig({
    required this.categories,
    required this.errorData,
    this.theme = ChartTheme.light,
    this.horizontal = false,
    this.showLine = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.errorBar, series: const []);

  @override
  Widget buildChart() => ErrorBarChartWidget(config: this);

  factory ErrorBarChartConfig.fromJson(Map<String, dynamic> json) {
    final rawS = JsonValue.list(json['series']) ?? const <dynamic>[];
    final errorData = rawS
        .map(JsonValue.map)
        .whereType<Map<String, dynamic>>()
        .map((s) {
          final data = JsonValue.list(s['data']) ?? const <dynamic>[];
          final points = <ErrorBarPoint>[];
          for (final item in data) {
            final point = _errorBarPointOrNull(item);
            if (point != null) points.add(point);
          }
          return points;
        })
        .toList(growable: false);
    return ErrorBarChartConfig(
      categories: _stringValues(json['categories']),
      errorData: errorData,
      horizontal: JsonValue.boolOrNull(json['horizontal']) ?? false,
      showLine: JsonValue.boolOrNull(json['showLine']) ?? true,
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      tooltip: json['tooltip'] != null
          ? ChartTooltip.fromJson(json['tooltip'])
          : null,
      legend: json['legend'] != null
          ? ChartLegend.fromJson(json['legend'])
          : null,
      toolbox: json['toolbox'] != null
          ? ChartToolbox.fromJson(json['toolbox'])
          : null,
      grid: json['grid'] != null ? GridData.fromJson(json['grid']) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'series': errorData
        .map(
          (series) => {'data': series.map((point) => point.toJson()).toList()},
        )
        .toList(),
    'horizontal': horizontal,
    'showLine': showLine,
  };
}

class ErrorBarChartWidget extends StatefulWidget {
  final ErrorBarChartConfig config;
  const ErrorBarChartWidget({super.key, required this.config});
  @override
  State<ErrorBarChartWidget> createState() => _ErrorBarState();
}

class _ErrorBarState extends State<ErrorBarChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  int _hovCat = -1;
  Offset _hoverPos = Offset.zero;
  ErrorBarChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _dataSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(ErrorBarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _hovCat = -1;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (cfg.title?.text != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(
              cfg.title!.text!,
              style: cfg.theme.typography.titleStyle.copyWith(
                color: cfg.theme.titleColor,
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, con) {
              final sz = Size(con.maxWidth, con.maxHeight);
              return Stack(
                children: [
                  MouseRegion(
                    onHover: (e) {
                      final sp = cfg.theme.spacing;
                      final n = cfg.categories.length;
                      if (n == 0) return;
                      final slotW =
                          (sz.width -
                              sp.chartPaddingLeft -
                              sp.chartPaddingRight) /
                          n;
                      setState(() {
                        _hovCat =
                            ((e.localPosition.dx - sp.chartPaddingLeft) / slotW)
                                .floor()
                                .clamp(0, n - 1);
                        _hoverPos = e.localPosition;
                      });
                    },
                    onExit: (_) => setState(() => _hovCat = -1),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _ErrorBarPainter(
                          config: cfg,
                          progress: _anim.value,
                          hovCat: _hovCat,
                          dataSignature: _dataSignature,
                        ),
                      ),
                    ),
                  ),
                  if (_hovCat >= 0) _buildTooltip(sz),
                ],
              );
            },
          ),
        ),
        if (cfg.errorData.length > 1) _buildLegend(),
      ],
    );
  }

  Widget _buildTooltip(Size sz) {
    double x = (_hoverPos.dx + 12).clamp(0, sz.width - 180.0);
    double y = (_hoverPos.dy - 70).clamp(0, sz.height - 100.0);
    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: cfg.theme.tooltipBackgroundColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: DefaultTextStyle(
            style: cfg.theme.typography.tooltipStyle.copyWith(
              color: cfg.theme.tooltipTextColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _hovCat < cfg.categories.length
                      ? cfg.categories[_hovCat]
                      : '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ...cfg.errorData.asMap().entries.map((e) {
                  if (_hovCat >= e.value.length) return const SizedBox();
                  final p = e.value[_hovCat];
                  return Text(
                    'Mean: ${p.mean.toStringAsFixed(3)}  [${p.lower.toStringAsFixed(3)}, ${p.upper.toStringAsFixed(3)}]',
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 6),
    child: Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: List.generate(cfg.errorData.length, (i) {
        final color = cfg.theme.palette.colorObjectAt(i);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              'Series ${i + 1}',
              style: cfg.theme.typography.legendStyle.copyWith(
                color: cfg.theme.legendTextColor,
              ),
            ),
          ],
        );
      }),
    ),
  );
}

class _ErrorBarPainter extends ChartPainterBase {
  final ErrorBarChartConfig config;
  final double progress;
  final int hovCat;
  final String dataSignature;

  _ErrorBarPainter({
    required this.config,
    required this.progress,
    required this.hovCat,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _ErrorBarPainter old) =>
      old.progress != progress ||
      old.hovCat != hovCat ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = config.categories.length;
    if (n == 0 || config.errorData.isEmpty) return;
    final sp = theme.spacing;

    double yMin = double.infinity, yMax = double.negativeInfinity;
    for (final s in config.errorData) {
      for (final p in s) {
        if (p.lower < yMin) yMin = p.lower;
        if (p.upper > yMax) yMax = p.upper;
      }
    }
    final pad = (yMax - yMin) * 0.12 + 0.001;
    final vp = ChartViewport(
      left: sp.chartPaddingLeft,
      top: sp.chartPaddingTop,
      right: size.width - sp.chartPaddingRight,
      bottom: size.height - sp.chartPaddingBottom,
      dataMinX: 0,
      dataMaxX: n.toDouble(),
      dataMinY: yMin - pad,
      dataMaxY: yMax + pad,
    );

    final yTicks = ChartDataProcessor.niceYTicks(vp.dataMinY, vp.dataMaxY);
    drawHorizontalGrid(canvas, vp, yTicks);
    drawYAxisLabels(canvas, vp, yTicks, (v) => v.toStringAsFixed(2));

    final slotW = vp.width / n;
    final ns = config.errorData.length;

    for (int si = 0; si < ns; si++) {
      final color = theme.palette.colorObjectAt(si);
      final pts = config.errorData[si];

      // Line connecting means
      if (config.showLine && pts.length > 1) {
        Path? path;
        for (int ci = 0; ci < math.min(n, pts.length); ci++) {
          final cx =
              vp.left + (ci + 0.5) * slotW + (si - (ns - 1) / 2) * slotW * 0.3;
          final cy = vp.toCanvasY(
            pts[ci].mean * progress + vp.dataMinY * (1 - progress),
          );
          if (path == null) {
            path = Path()..moveTo(cx, cy);
          } else {
            path.lineTo(cx, cy);
          }
        }
        if (path != null) {
          canvas.drawPath(
            path,
            paintCache.stroke(color.withValues(alpha: 0.5), 1),
          );
        }
      }

      for (int ci = 0; ci < math.min(n, pts.length); ci++) {
        final p = pts[ci];
        final isHov = ci == hovCat;
        final cx =
            vp.left + (ci + 0.5) * slotW + (si - (ns - 1) / 2) * slotW * 0.3;
        final capW = slotW * 0.12;

        final meanY = vp.toCanvasY(p.mean);
        final loY = vp.toCanvasY(p.lower * progress + p.mean * (1 - progress));
        final hiY = vp.toCanvasY(p.upper * progress + p.mean * (1 - progress));

        // Whisker line
        canvas.drawLine(
          Offset(cx, loY),
          Offset(cx, hiY),
          paintCache.stroke(color, 1.5),
        );
        // Caps
        canvas.drawLine(
          Offset(cx - capW, loY),
          Offset(cx + capW, loY),
          paintCache.stroke(color, 1.5),
        );
        canvas.drawLine(
          Offset(cx - capW, hiY),
          Offset(cx + capW, hiY),
          paintCache.stroke(color, 1.5),
        );
        // Mean dot
        final r = isHov ? 6.0 : 4.5;
        canvas.drawCircle(
          Offset(cx, meanY),
          r,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        canvas.drawCircle(
          Offset(cx, meanY),
          r,
          paintCache.stroke(Colors.white, 1.5),
        );
      }
    }

    drawXAxisLabels(
      canvas,
      vp,
      config.categories,
      List.generate(n, (i) => vp.left + (i + 0.5) * slotW),
    );
    canvas.drawLine(
      Offset(vp.left, vp.bottom),
      Offset(vp.right, vp.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(vp.left, vp.top),
      Offset(vp.left, vp.bottom),
      axisPaint,
    );
  }
}
