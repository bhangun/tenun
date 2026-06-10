/// Histogram — frequency distribution chart with automatic or manual binning.
/// Optionally overlays a kernel density estimate (KDE) curve.
/// Shows mean/median/std lines and a statistics panel.
///
/// JSON:
/// ```json
/// {
///   "type": "histogram",
///   "bins": 15,
///   "showKDE": true,
///   "showStats": true,
///   "series": [{ "name": "Response Time (ms)",
///     "data": [120,145,98,210,175,132,88,156,201,134,167,99,143,188,120,155] }]
/// }
/// ```
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/base_config.dart';
import '../../core/chart_type.dart';
import '../../core/chart_theme.dart';
import '../../core/series.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';
import '../../core/legend.dart';
import '../../core/grid.dart';
import '../../core/chart_model.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_data_signature.dart';
import '../../core/chart_data_value_reader.dart';
import '../../core/chart_data_processor.dart';
import '../../core/chart_cache.dart';
import '../../core/json_value.dart';

// ─────────────────────────────────────────────────────────
// Stats helper
// ─────────────────────────────────────────────────────────

class _Stats {
  final double mean, median, stdDev, min, max;
  final List<int> counts;
  final List<double> edges; // bin edges, length = bins+1

  const _Stats({
    required this.mean,
    required this.median,
    required this.stdDev,
    required this.min,
    required this.max,
    required this.counts,
    required this.edges,
  });

  static _Stats compute(List<double> data, int bins) {
    if (data.isEmpty) {
      return _Stats(
        mean: 0,
        median: 0,
        stdDev: 0,
        min: 0,
        max: 0,
        counts: [],
        edges: [],
      );
    }
    final sorted = [...data]..sort();
    final n = data.length;
    final min = sorted.first;
    final max = sorted.last;
    final mean = data.fold(0.0, (s, v) => s + v) / n;
    final median = n % 2 == 0
        ? (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2
        : sorted[n ~/ 2].toDouble();
    final variance = data.fold(0.0, (s, v) => s + (v - mean) * (v - mean)) / n;
    final std = math.sqrt(variance);

    final binW = (max - min) / bins + 1e-9;
    final counts = List<int>.filled(bins, 0);
    for (final v in data) {
      final idx = ((v - min) / binW).floor().clamp(0, bins - 1);
      counts[idx]++;
    }
    final edges = List.generate(bins + 1, (i) => min + i * binW);

    return _Stats(
      mean: mean,
      median: median,
      stdDev: std,
      min: min,
      max: max,
      counts: counts,
      edges: edges,
    );
  }
}

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

class HistogramChartConfig extends BaseChartConfig {
  final int bins;
  final bool showKDE;
  final bool showMean;
  final bool showMedian;
  final bool showStats;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  HistogramChartConfig({
    required super.series,
    this.theme = ChartTheme.light,
    int bins = 10,
    this.showKDE = true,
    this.showMean = true,
    this.showMedian = true,
    this.showStats = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : bins = bins.clamp(1, 200).toInt(),
       super(type: ChartType.histogram);

  @override
  Widget buildChart() => HistogramChartWidget(config: this);

  factory HistogramChartConfig.fromJson(Map<String, dynamic> json) {
    final seriesList = _parseHistogramSeries(json);
    return HistogramChartConfig(
      series: seriesList,
      bins: JsonValue.intOrNull(json['bins']) ?? 10,
      showKDE: JsonValue.boolOrNull(json['showKDE']) ?? true,
      showMean: JsonValue.boolOrNull(json['showMean']) ?? true,
      showMedian: JsonValue.boolOrNull(json['showMedian']) ?? true,
      showStats: JsonValue.boolOrNull(json['showStats']) ?? true,
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
    'bins': bins,
    'showKDE': showKDE,
    'showMean': showMean,
    'showMedian': showMedian,
    'showStats': showStats,
  };
}

List<Series> _parseHistogramSeries(Map<String, dynamic> json) {
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
        type: ChartType.histogram,
        name: JsonValue.string(json['name']),
        data: rawSeries,
      ),
    ];
  }

  final data = JsonValue.list(json['data']);
  if (data == null) return const <Series>[];
  return [
    Series(
      type: ChartType.histogram,
      name: JsonValue.string(json['name']),
      data: data,
    ),
  ];
}

List<double> _histogramValues(List<dynamic>? data) {
  if (data == null) return const <double>[];
  final values = <double>[];
  for (final item in data) {
    final value = ChartDataValueReader.yValueOrNull(item);
    if (value != null) values.add(value);
  }
  return values;
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

class HistogramChartWidget extends StatefulWidget {
  final HistogramChartConfig config;
  const HistogramChartWidget({super.key, required this.config});
  @override
  State<HistogramChartWidget> createState() => _HistState();
}

class _HistState extends State<HistogramChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  int _hovBin = -1;
  Offset _hoverPos = Offset.zero;

  HistogramChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant HistogramChartWidget oldWidget) {
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

  List<double> _getData(int s) => _histogramValues(cfg.series[s].data);

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
              final stats = cfg.series.isNotEmpty
                  ? _Stats.compute(_getData(0), cfg.bins)
                  : null;
              return Stack(
                children: [
                  MouseRegion(
                    onHover: (e) => setState(() {
                      if (stats != null) {
                        final sp = cfg.theme.spacing;
                        final plotWidth =
                            sz.width -
                            sp.chartPaddingLeft -
                            sp.chartPaddingRight;
                        if (plotWidth <= 0) return;
                        final binW = plotWidth / cfg.bins;
                        _hovBin =
                            ((e.localPosition.dx - sp.chartPaddingLeft) / binW)
                                .floor()
                                .clamp(0, cfg.bins - 1);
                      }
                      _hoverPos = e.localPosition;
                    }),
                    onExit: (_) => setState(() => _hovBin = -1),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _HistPainter(
                          config: cfg,
                          progress: _anim.value,
                          hovBin: _hovBin,
                          stats: stats,
                          dataSignature: _dataSignature,
                        ),
                      ),
                    ),
                  ),
                  if (_hovBin >= 0 && stats != null) _buildTooltip(sz, stats),
                  if (cfg.showStats && stats != null) _buildStatsPanel(stats),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTooltip(Size sz, _Stats stats) {
    if (_hovBin >= stats.counts.length) return const SizedBox();
    final lo = stats.edges[_hovBin], hi = stats.edges[_hovBin + 1];
    final count = stats.counts[_hovBin];
    final pct = (count / stats.counts.fold(0, (s, v) => s + v) * 100)
        .toStringAsFixed(1);
    double x = (_hoverPos.dx + 12).clamp(0, sz.width - 180.0);
    double y = (_hoverPos.dy - 60).clamp(0, sz.height - 80.0);
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
                  '[${lo.toStringAsFixed(1)}, ${hi.toStringAsFixed(1)})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Count: $count'),
                Text('Frequency: $pct%'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsPanel(_Stats s) => Positioned(
    top: 8,
    right: 8,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cfg.theme.tooltipBackgroundColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DefaultTextStyle(
        style: cfg.theme.typography.tooltipStyle.copyWith(
          color: cfg.theme.tooltipTextColor,
          fontSize: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('μ = ${s.mean.toStringAsFixed(2)}'),
            Text('Med = ${s.median.toStringAsFixed(2)}'),
            Text('σ = ${s.stdDev.toStringAsFixed(2)}'),
            Text('n = ${s.counts.fold(0, (a, b) => a + b)}'),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────

class _HistPainter extends ChartPainterBase {
  final HistogramChartConfig config;
  final double progress;
  final int hovBin;
  final _Stats? stats;
  final String dataSignature;

  _HistPainter({
    required this.config,
    required this.progress,
    required this.hovBin,
    required this.dataSignature,
    this.stats,
  }) : super(theme: config.theme);

  @override
  bool shouldRepaintChart(covariant _HistPainter old) =>
      old.progress != progress ||
      old.hovBin != hovBin ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final s = stats;
    if (s == null || s.counts.isEmpty) return;
    final sp = theme.spacing;
    if (size.width <= sp.chartPaddingLeft + sp.chartPaddingRight ||
        size.height <= sp.chartPaddingTop + sp.chartPaddingBottom) {
      return;
    }

    final maxCount = s.counts.reduce(math.max);
    final dataMaxX = s.max <= s.min ? s.min + 1 : s.max;
    final vp = ChartViewport(
      left: sp.chartPaddingLeft,
      top: sp.chartPaddingTop,
      right: size.width - sp.chartPaddingRight,
      bottom: size.height - sp.chartPaddingBottom,
      dataMinX: s.min,
      dataMaxX: dataMaxX,
      dataMinY: 0,
      dataMaxY: maxCount * 1.15,
    );

    final yTicks = ChartDataProcessor.niceYTicks(0, maxCount.toDouble());
    drawHorizontalGrid(canvas, vp, yTicks);
    drawYAxisLabels(canvas, vp, yTicks, (v) => v.toStringAsFixed(0));

    final color = theme.palette.colorObjectAt(0);
    final binW = vp.width / config.bins;

    // Bars
    for (int i = 0; i < s.counts.length; i++) {
      final x = vp.left + i * binW;
      final h = (s.counts[i] / maxCount * vp.height * progress).clamp(
        0.0,
        vp.height,
      );
      final isHov = i == hovBin;
      canvas.drawRect(
        Rect.fromLTWH(x + 1, vp.bottom - h, binW - 2, h),
        Paint()
          ..color = isHov
              ? Color.lerp(color, Colors.white, 0.2)!
              : color.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 1, vp.bottom - h, binW - 2, h),
        paintCache.stroke(Colors.white.withValues(alpha: 0.4), 0.8),
      );
    }

    // X axis labels (bin edges)
    final edgeCount = math.min(8, config.bins + 1);
    for (int i = 0; i <= edgeCount; i++) {
      final idx = (i / edgeCount * config.bins).round().clamp(0, config.bins);
      final x = vp.left + idx * binW;
      if (idx < s.edges.length) {
        final tp = textPainterCache.get(
          s.edges[idx].toStringAsFixed(0),
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 9,
          ),
        );
        tp.paint(canvas, Offset(x - tp.width / 2, vp.bottom + 4));
      }
    }

    // KDE overlay
    if (config.showKDE) {
      final total = s.counts.fold(0, (a, b) => a + b);
      final values = config.series.isNotEmpty
          ? _histogramValues(config.series.first.data)
          : const <double>[];
      if (total > 1 && s.stdDev > 0 && s.max > s.min && values.isNotEmpty) {
        final bw =
            s.stdDev * math.pow(total, -1 / 5) * 1.06; // Silverman's rule
        Path? kdePath;
        const kdeSteps = 100;
        for (int step = 0; step <= kdeSteps; step++) {
          final x = s.min + step / kdeSteps * (s.max - s.min);
          double density = 0;
          for (final v in values) {
            final z = (x - v) / bw;
            density += math.exp(-0.5 * z * z) / (bw * math.sqrt(2 * math.pi));
          }
          density /= total;
          // Scale KDE to match histogram
          final binArea = (s.max - s.min) / config.bins;
          final scaledDensity = density * total * binArea;
          final cx = vp.toCanvasX(x);
          final cy = vp.toCanvasY(scaledDensity * progress);
          if (kdePath == null) {
            kdePath = Path()..moveTo(cx, cy);
          } else {
            kdePath.lineTo(cx, cy);
          }
        }
        if (kdePath != null) {
          canvas.drawPath(
            kdePath,
            paintCache.stroke(const Color(0xFFE53935), 2),
          );
        }
      }
    }

    // Mean / median lines
    if (config.showMean) {
      final mx = vp.toCanvasX(s.mean);
      canvas.drawLine(
        Offset(mx, vp.top),
        Offset(mx, vp.bottom),
        paintCache.stroke(const Color(0xFF1565C0), 1.5),
      );
      final tp = textPainterCache.get(
        'μ',
        theme.typography.axisLabelStyle.copyWith(
          color: const Color(0xFF1565C0),
          fontSize: 9,
        ),
      );
      tp.paint(canvas, Offset(mx + 2, vp.top + 2));
    }
    if (config.showMedian) {
      final mx = vp.toCanvasX(s.median);
      canvas.drawLine(
        Offset(mx, vp.top),
        Offset(mx, vp.bottom),
        paintCache.stroke(const Color(0xFF2E7D32), 1.5),
      );
      final tp = textPainterCache.get(
        'M',
        theme.typography.axisLabelStyle.copyWith(
          color: const Color(0xFF2E7D32),
          fontSize: 9,
        ),
      );
      tp.paint(canvas, Offset(mx + 2, vp.top + 14));
    }

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
