/// Violin chart — KDE distribution shape with optional box-plot overlay.
/// Shows the full distribution shape (wider = more data) per category.
/// Supports split violins for two-group comparison.
///
/// JSON:
/// ```json
/// { "type": "violin", "showBoxPlot": true,
///   "categories": ["Control","Treatment A","Treatment B"],
///   "series": [{
///     "name": "Score",
///     "data": [[72,68,75,80,71,69,74],[85,88,79,91,87,83,90],[60,65,58,62,70,55,63]]
///   }]}
/// ```
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
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_data_processor.dart';
import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/json_value.dart';

// ─────────────────────────────────────────────────────────
// KDE helper
// ─────────────────────────────────────────────────────────

List<({double y, double density})> _kde(
  List<double> data,
  double yMin,
  double yMax,
  int steps,
) {
  if (data.isEmpty) return [];
  final n = data.length;
  final std = () {
    final mean = data.fold(0.0, (a, b) => a + b) / n;
    final v = data.fold(0.0, (a, b) => a + (b - mean) * (b - mean)) / n;
    return math.sqrt(v);
  }();
  final bw = std * math.pow(n, -0.2) * 1.06 + 0.1;
  final result = <({double y, double density})>[];
  for (int i = 0; i <= steps; i++) {
    final y = yMin + i / steps * (yMax - yMin);
    double d = 0;
    for (final v in data) {
      final z = (y - v) / bw;
      d += math.exp(-0.5 * z * z);
    }
    result.add((y: y, density: d / (n * bw * math.sqrt(2 * math.pi))));
  }
  return result;
}

List<String> _stringValues(Object? raw) =>
    JsonValue.stringList(raw) ?? const <String>[];

List<double> _numericRowValues(Object? raw) {
  final rawList = JsonValue.list(raw);
  if (rawList != null) {
    final values = <double>[];
    for (final item in rawList) {
      final value = JsonValue.doubleOrNull(item);
      if (value != null) values.add(value);
    }
    return values;
  }

  final scalar = JsonValue.doubleOrNull(raw);
  return scalar == null ? const <double>[] : <double>[scalar];
}

List<Series> _parseViolinSeries(Map<String, dynamic> json) {
  final rawSeries = JsonValue.list(json['series']);
  if (rawSeries != null && rawSeries.isNotEmpty) {
    final firstAsMap = JsonValue.map(rawSeries.first);
    if (firstAsMap != null) {
      return rawSeries
          .map(JsonValue.map)
          .whereType<Map<String, dynamic>>()
          .map(Series.fromJson)
          .toList(growable: false);
    }
    return [
      Series(
        type: ChartType.violin,
        name: JsonValue.string(json['name']),
        data: rawSeries,
      ),
    ];
  }

  final data = JsonValue.list(json['data']);
  if (data == null) return const <Series>[];
  return [
    Series(
      type: ChartType.violin,
      name: JsonValue.string(json['name']),
      data: data,
    ),
  ];
}

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

class ViolinChartConfig extends BaseChartConfig {
  final List<String> categories;
  final bool showBoxPlot;
  final bool showMean;
  final double widthFraction;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  ViolinChartConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.showBoxPlot = true,
    this.showMean = true,
    this.widthFraction = 0.7,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.violin);

  @override
  Widget buildChart() => ViolinChartWidget(config: this);

  factory ViolinChartConfig.fromJson(Map<String, dynamic> json) {
    return ViolinChartConfig(
      categories: _stringValues(json['categories']),
      series: _parseViolinSeries(json),
      showBoxPlot: JsonValue.boolOrNull(json['showBoxPlot']) ?? true,
      showMean: JsonValue.boolOrNull(json['showMean']) ?? true,
      widthFraction: JsonValue.doubleOrNull(json['widthFraction']) ?? 0.7,
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
    'showBoxPlot': showBoxPlot,
    'showMean': showMean,
    'widthFraction': widthFraction,
  };
}

// ─────────────────────────────────────────────────────────
// Widget + Painter
// ─────────────────────────────────────────────────────────

class ViolinChartWidget extends StatefulWidget {
  final ViolinChartConfig config;
  const ViolinChartWidget({super.key, required this.config});
  @override
  State<ViolinChartWidget> createState() => _ViolinState();
}

class _ViolinState extends State<ViolinChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  ViolinChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant ViolinChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature == _dataSignature) return;
    _dataSignature = nextSignature;
    _ctrl.forward(from: 0);
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
            painter: _ViolinPainter(
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

class _ViolinPainter extends ChartPainterBase {
  final ViolinChartConfig config;
  final double progress;
  final String dataSignature;

  _ViolinPainter({
    required this.config,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _ViolinPainter old) =>
      old.progress != progress || old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = config.categories.length;
    if (n == 0 || config.series.isEmpty) return;
    final sp = theme.spacing;

    // Flatten all data to get global Y range
    final allVals = <double>[];
    for (final s in config.series) {
      for (final row in s.data ?? []) {
        allVals.addAll(_numericRowValues(row));
      }
    }
    if (allVals.isEmpty) return;
    final yMin = allVals.reduce(math.min);
    final yMax = allVals.reduce(math.max);
    final pad = (yMax - yMin) * 0.1 + 1;

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
    final ns = config.series.length;

    for (int si = 0; si < ns; si++) {
      final s = config.series[si];
      final color = theme.seriesColor(si, explicitColor: s.itemStyle?.color);
      final rawData = s.data ?? [];

      for (int ci = 0; ci < math.min(n, rawData.length); ci++) {
        final row = rawData[ci];
        final vals = _numericRowValues(row);
        if (vals.isEmpty) continue;

        final cx =
            vp.left +
            (ci + 0.5) * slotW +
            (si - (ns - 1) / 2) * slotW * config.widthFraction / ns;
        final halfW = slotW * config.widthFraction / ns / 2;

        final kdePts = _kde(vals, vp.dataMinY, vp.dataMaxY, 80);
        if (kdePts.isEmpty) continue;
        final maxD = kdePts
            .map((p) => p.density)
            .reduce(math.max)
            .clamp(1e-9, 1e18);

        // Build violin path
        final leftPts = <Offset>[], rightPts = <Offset>[];
        for (final p in kdePts) {
          final py = vp.toCanvasY(p.y);
          final dx = (p.density / maxD) * halfW * progress;
          leftPts.add(Offset(cx - dx, py));
          rightPts.add(Offset(cx + dx, py));
        }

        final path = Path()..moveTo(leftPts.first.dx, leftPts.first.dy);
        for (final pt in leftPts) {
          path.lineTo(pt.dx, pt.dy);
        }
        for (final pt in rightPts.reversed) {
          path.lineTo(pt.dx, pt.dy);
        }
        path.close();

        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: 0.45)
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        canvas.drawPath(path, paintCache.stroke(color, 1.2));

        // Box plot overlay
        if (config.showBoxPlot && vals.length >= 4) {
          final sorted = [...vals]..sort();
          final nv = sorted.length;
          double q(double p) {
            final i = p * (nv - 1);
            final lo = i.floor(), hi = i.ceil();
            return lo == hi
                ? sorted[lo]
                : sorted[lo] + (sorted[hi] - sorted[lo]) * (i - lo);
          }

          final q1 = q(0.25), median = q(0.5), q3 = q(0.75);
          final iqr = q3 - q1;
          final wlo = sorted.where((v) => v >= q1 - 1.5 * iqr).first;
          final whi = sorted.lastWhere((v) => v <= q3 + 1.5 * iqr);
          final boxW = halfW * 0.3;

          canvas.drawLine(
            Offset(cx, vp.toCanvasY(whi)),
            Offset(cx, vp.toCanvasY(wlo)),
            paintCache.stroke(Colors.white.withValues(alpha: 0.8), 1.5),
          );
          canvas.drawRect(
            Rect.fromLTRB(
              cx - boxW,
              vp.toCanvasY(q3),
              cx + boxW,
              vp.toCanvasY(q1),
            ),
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill,
          );
          canvas.drawRect(
            Rect.fromLTRB(
              cx - boxW,
              vp.toCanvasY(q3),
              cx + boxW,
              vp.toCanvasY(q1),
            ),
            paintCache.stroke(color, 1),
          );
          canvas.drawLine(
            Offset(cx - boxW, vp.toCanvasY(median)),
            Offset(cx + boxW, vp.toCanvasY(median)),
            paintCache.stroke(color, 2),
          );
        }
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
