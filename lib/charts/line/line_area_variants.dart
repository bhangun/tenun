/// Line & Area chart variants — 21 specialized line/area chart types.
///
/// Charts in this file:
///   • [AreaPiecesChartConfig]        — area split into colour-coded threshold pieces
///   • [LineGradientChartConfig]      — line with gradient stroke and/or fill
///   • [LineConfidenceBandConfig]     — line with shaded confidence/error band
///   • [LineMarklineConfig]           — line with named reference mark-lines
///   • [LineRaceChartConfig]          — animated line race (rank by final value)
///   • [LogAxisChartConfig]           — line/area on a logarithmic Y-axis
///   • [FunctionPlotConfig]           — mathematical y = f(x) function plotter
///   • [SparklineMatrixConfig]        — grid of small sparklines (one per cell)
///   • [DynamicTimeSeriesConfig]      — live-updating time-series with sliding window
///   • [IntradayLineConfig]           — line with explicit data gaps (breaks)
///   • [MultiXAxesChartConfig]        — line chart with two independent X axes
///   • [LineClickAddConfig]           — interactive line: tap to add data points
///   • [PolarLineChartConfig]         — line on a polar (two-value-axis) coordinate system
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/base_config.dart';
import '../../core/chart_data_value_reader.dart';
import '../../core/chart_data_signature.dart';
import '../../core/chart_model.dart';
import '../../core/chart_type.dart';
import '../../core/chart_theme.dart';
import '../../core/grid.dart';
import '../../core/legend.dart';
import '../../core/series.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_data_processor.dart';
import '../../core/chart_cache.dart';
import '../../core/json_value.dart';

// ─── shared helpers ────────────────────────────────────────────────────────

/// Build a smooth cubic-bezier [Path] through [pts] with tension [t] (0=straight).
Path _smoothPath(List<Offset> pts, {double tension = 0.4}) {
  if (pts.isEmpty) return Path();
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (int i = 0; i < pts.length - 1; i++) {
    final p0 = pts[i], p1 = pts[i + 1];
    final cp = (p1.dx - p0.dx) * tension;
    p.cubicTo(p0.dx + cp, p0.dy, p1.dx - cp, p1.dy, p1.dx, p1.dy);
  }
  return p;
}

/// Draw Y-axis grid + labels for [ticks] inside [vp].
void _drawYGrid(
  Canvas canvas,
  ChartViewport vp,
  List<double> ticks,
  ChartPainterBase p,
  String Function(double) fmt,
) {
  for (final t in ticks) {
    final y = vp.toCanvasY(t);
    if (y < vp.top || y > vp.bottom) continue;
    canvas.drawLine(
      Offset(vp.left, y),
      Offset(vp.right, y),
      paintCache.stroke(p.theme.gridColor, 0.5),
    );
    final tp = textPainterCache.get(
      fmt(t),
      p.theme.typography.axisLabelStyle.copyWith(
        color: p.theme.axisLabelColor,
        fontSize: 9,
      ),
      align: TextAlign.right,
      maxWidth: 44,
    );
    tp.paint(canvas, Offset(vp.left - tp.width - 4, y - tp.height / 2));
  }
}

Map<String, dynamic> _lineVariantBaseJson(BaseChartConfig config) => {
  'type': chartTypeToString(config.type),
  if (config.title != null) 'title': config.title!.toJson(),
  if (config.tooltip != null) 'tooltip': config.tooltip!.toJson(),
  if (config.legend != null) 'legend': config.legend!.toJson(),
  if (config.toolbox != null) 'toolbox': config.toolbox!.toJson(),
  if (config.grid != null) 'grid': config.grid!.toJson(),
  if (config.series.isNotEmpty)
    'series': config.series.map((series) => series.toJson()).toList(),
};

// ═══════════════════════════════════════════════════════════════════════════
// 1. AREA PIECES (threshold-coloured area)
// ═══════════════════════════════════════════════════════════════════════════
/// The area fill is split at configurable thresholds, each piece rendered
/// in a different colour (e.g. green below target, red above).
///
/// JSON:
/// ```json
/// { "type": "areaPieces",
///   "thresholds": [
///     {"value": 0,   "color": "#EF5350"},
///     {"value": 50,  "color": "#FFA726"},
///     {"value": 100, "color": "#66BB6A"}
///   ],
///   "series": [{ "name":"Temperature","data":[30,-10,80,120,60,20,-5] }] }
/// ```
class AreaPieceThreshold {
  final double value;
  final String color;
  const AreaPieceThreshold({required this.value, required this.color});
  factory AreaPieceThreshold.fromJson(Map<String, dynamic> j) =>
      AreaPieceThreshold(
        value: _readDouble(j['value']),
        color: j['color']?.toString() ?? '#42A5F5',
      );

  Map<String, dynamic> toJson() => {'value': value, 'color': color};
}

double _readDouble(Object? value, [double fallback = 0]) {
  return JsonValue.doubleOrNull(value) ?? fallback;
}

List<Series> _lineVariantSeries(Object? raw) {
  return (JsonValue.mapList(raw) ?? const <Map<String, dynamic>>[])
      .map(Series.fromJson)
      .toList(growable: false);
}

List<double> _lineVariantValues(Object? raw) {
  final values = JsonValue.list(raw) ?? const <dynamic>[];
  return values
      .map(ChartDataValueReader.yValueOrNull)
      .whereType<double>()
      .toList(growable: false);
}

class AreaPiecesChartConfig extends BaseChartConfig {
  final List<AreaPieceThreshold> thresholds;
  final List<String> categories;
  final double fillOpacity;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  AreaPiecesChartConfig({
    required this.thresholds,
    this.categories = const [],
    required super.series,
    this.theme = ChartTheme.light,
    this.fillOpacity = 0.35,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.areaPieces);

  @override
  Widget buildChart() => _AreaPiecesWidget(config: this);

  factory AreaPiecesChartConfig.fromJson(Map<String, dynamic> j) {
    final thresh = (JsonValue.mapList(j['thresholds']) ?? const [])
        .map(AreaPieceThreshold.fromJson)
        .toList();
    final cats =
        JsonValue.stringList(j['categories']) ??
        JsonValue.stringList(j['xLabels']) ??
        const <String>[];
    return AreaPiecesChartConfig(
      thresholds: thresh,
      categories: cats,
      series: _lineVariantSeries(j['series']),
      fillOpacity: JsonValue.doubleOrNull(j['fillOpacity']) ?? 0.35,
      title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
      tooltip: j['tooltip'] != null
          ? ChartTooltip.fromJson(j['tooltip'])
          : null,
      legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
      toolbox: j['toolbox'] != null
          ? ChartToolbox.fromJson(j['toolbox'])
          : null,
      grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'thresholds': thresholds.map((threshold) => threshold.toJson()).toList(),
    'categories': categories,
    'fillOpacity': fillOpacity,
  };
}

class _AreaPiecesWidget extends StatefulWidget {
  final AreaPiecesChartConfig config;
  const _AreaPiecesWidget({required this.config});
  @override
  State<_AreaPiecesWidget> createState() => _AreaPiecesState();
}

class _AreaPiecesState extends State<_AreaPiecesWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  AreaPiecesChartConfig get cfg => widget.config;

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
  void didUpdateWidget(_AreaPiecesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
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
            painter: _AreaPiecesPainter(
              cfg: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
    ],
  );
}

class _AreaPiecesPainter extends ChartPainterBase {
  final AreaPiecesChartConfig cfg;
  final double progress;
  final String dataSignature;
  _AreaPiecesPainter({
    required this.cfg,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _AreaPiecesPainter o) =>
      o.progress != progress || o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.series.isEmpty) return;
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final vals = _lineVariantValues(cfg.series.first.data);
    if (vals.isEmpty) return;
    final n = vals.length;

    double yMin = vals.reduce(math.min), yMax = vals.reduce(math.max);
    final yPad = (yMax - yMin) * 0.1 + 1;
    yMin -= yPad;
    yMax += yPad;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: 0,
      dataMaxX: n.toDouble() - 1,
      dataMinY: yMin,
      dataMaxY: yMax,
    );

    final ticks = ChartDataProcessor.niceYTicks(yMin, yMax);
    _drawYGrid(canvas, vp, ticks, this, (t) => t.toStringAsFixed(0));

    // Build points
    final pts = List.generate(
      n,
      (i) => Offset(
        vp.toCanvasX(i.toDouble()),
        vp.toCanvasY(yMin + (vals[i] - yMin) * progress),
      ),
    );

    // Sort thresholds ascending
    final sorted = [...cfg.thresholds]
      ..sort((a, b) => a.value.compareTo(b.value));

    // Clip + fill each threshold band
    for (int ti = 0; ti < sorted.length; ti++) {
      final lower = ti == 0 ? -1e18 : sorted[ti - 1].value;
      final upper = sorted[ti].value;
      Color c;
      try {
        c = colorCache.resolve(sorted[ti].color);
      } catch (_) {
        c = Colors.blue;
      }

      // Fill band: clip canvas to [lower, upper] Y band
      final clipTop = vp.toCanvasY(math.min(yMax, upper));
      final clipBot = vp.toCanvasY(math.max(yMin, lower));
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(padL, clipTop, padL + plotW, clipBot));

      final areaPath = _smoothPath(pts)
        ..lineTo(pts.last.dx, padT + plotH)
        ..lineTo(pts.first.dx, padT + plotH)
        ..close();
      canvas.drawPath(
        areaPath,
        Paint()
          ..color = c.withValues(alpha: cfg.fillOpacity)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.restore();
    }

    // Line stroke on top
    canvas.drawPath(
      _smoothPath(pts),
      paintCache.stroke(theme.seriesColor(0), 1.8)..isAntiAlias = true,
    );

    // X labels
    for (int i = 0; i < n; i++) {
      if (cfg.categories.isNotEmpty && i < cfg.categories.length) {
        final tp = textPainterCache.get(
          cfg.categories[i],
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 9,
          ),
        );
        tp.paint(canvas, Offset(pts[i].dx - tp.width / 2, padT + plotH + 4));
      }
    }
    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. LINE WITH GRADIENT STROKE / FILL
// ═══════════════════════════════════════════════════════════════════════════
class LineGradientChartConfig extends BaseChartConfig {
  final List<String> categories;
  final String gradientStart, gradientEnd;
  final bool fillArea;
  final double fillOpacity;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  LineGradientChartConfig({
    this.categories = const [],
    required super.series,
    this.theme = ChartTheme.light,
    this.gradientStart = '#42A5F5',
    this.gradientEnd = '#26C6DA',
    this.fillArea = true,
    this.fillOpacity = 0.25,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.lineGradient);

  @override
  Widget buildChart() => _LineGradientWidget(config: this);

  factory LineGradientChartConfig.fromJson(Map<String, dynamic> j) {
    final cats =
        JsonValue.stringList(j['categories']) ??
        JsonValue.stringList(j['xLabels']) ??
        const <String>[];
    return LineGradientChartConfig(
      categories: cats,
      series: _lineVariantSeries(j['series']),
      gradientStart: JsonValue.string(j['gradientStart']) ?? '#42A5F5',
      gradientEnd: JsonValue.string(j['gradientEnd']) ?? '#26C6DA',
      fillArea: JsonValue.boolOrNull(j['fillArea']) ?? true,
      fillOpacity: JsonValue.doubleOrNull(j['fillOpacity']) ?? 0.25,
      title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
      tooltip: j['tooltip'] != null
          ? ChartTooltip.fromJson(j['tooltip'])
          : null,
      legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
      toolbox: j['toolbox'] != null
          ? ChartToolbox.fromJson(j['toolbox'])
          : null,
      grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'gradientStart': gradientStart,
    'gradientEnd': gradientEnd,
    'fillArea': fillArea,
    'fillOpacity': fillOpacity,
  };
}

class _LineGradientWidget extends StatefulWidget {
  final LineGradientChartConfig config;
  const _LineGradientWidget({required this.config});
  @override
  State<_LineGradientWidget> createState() => _LineGradState();
}

class _LineGradState extends State<_LineGradientWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  LineGradientChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_LineGradientWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
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
            painter: _LineGradPainter(
              cfg: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
    ],
  );
}

class _LineGradPainter extends ChartPainterBase {
  final LineGradientChartConfig cfg;
  final double progress;
  final String dataSignature;
  _LineGradPainter({
    required this.cfg,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _LineGradPainter o) =>
      o.progress != progress || o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.series.isEmpty) return;
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    Color cStart, cEnd;
    try {
      cStart = colorCache.resolve(cfg.gradientStart);
    } catch (_) {
      cStart = Colors.blue.shade300;
    }
    try {
      cEnd = colorCache.resolve(cfg.gradientEnd);
    } catch (_) {
      cEnd = Colors.cyan.shade300;
    }

    for (int si = 0; si < cfg.series.length; si++) {
      final s = cfg.series[si];
      final vals = _lineVariantValues(s.data);
      if (vals.isEmpty) continue;
      final n = vals.length;

      double yMin = vals.reduce(math.min), yMax = vals.reduce(math.max);
      final yPad = (yMax - yMin) * 0.1 + 1;
      yMin -= yPad;
      yMax += yPad;
      final vp = ChartViewport(
        left: padL,
        top: padT,
        right: padL + plotW,
        bottom: padT + plotH,
        dataMinX: 0,
        dataMaxX: (n - 1).toDouble(),
        dataMinY: yMin,
        dataMaxY: yMax,
      );

      if (si == 0) {
        final ticks = ChartDataProcessor.niceYTicks(yMin, yMax);
        _drawYGrid(canvas, vp, ticks, this, (t) => t.toStringAsFixed(0));
      }

      final pts = List.generate(n, (i) {
        final animVal = yMin + (vals[i] - yMin) * progress;
        return Offset(vp.toCanvasX(i.toDouble()), vp.toCanvasY(animVal));
      });

      final linePath = _smoothPath(pts);
      final plotRect = Rect.fromLTWH(padL, padT, plotW, plotH);

      // Gradient stroke
      final gradShader = LinearGradient(
        colors: [cStart, cEnd],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(plotRect);
      canvas.drawPath(
        linePath,
        Paint()
          ..shader = gradShader
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round,
      );

      // Gradient fill
      if (cfg.fillArea) {
        final areaPath = Path.from(linePath)
          ..lineTo(pts.last.dx, padT + plotH)
          ..lineTo(pts.first.dx, padT + plotH)
          ..close();
        final fillShader = LinearGradient(
          colors: [
            cStart.withValues(alpha: cfg.fillOpacity),
            cEnd.withValues(alpha: 0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(plotRect);
        canvas.drawPath(
          areaPath,
          Paint()
            ..shader = fillShader
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
      }

      // X labels
      for (int i = 0; i < n; i++) {
        if (cfg.categories.isNotEmpty && i < cfg.categories.length) {
          final tp = textPainterCache.get(
            cfg.categories[i],
            theme.typography.axisLabelStyle.copyWith(
              color: theme.axisLabelColor,
              fontSize: 9,
            ),
          );
          if (i % math.max(1, (n / 8).round()) == 0 || i == n - 1) {
            tp.paint(
              canvas,
              Offset(pts[i].dx - tp.width / 2, padT + plotH + 4),
            );
          }
        }
      }
    }
    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. LINE WITH CONFIDENCE BAND
// ═══════════════════════════════════════════════════════════════════════════
class ConfidenceBandPoint {
  final double x, y, lower, upper;
  const ConfidenceBandPoint({
    required this.x,
    required this.y,
    required this.lower,
    required this.upper,
  });
  factory ConfidenceBandPoint.fromJson(Map<String, dynamic> j) =>
      ConfidenceBandPoint(
        x: _readDouble(j['x']),
        y: _readDouble(j['y']),
        lower: _readDouble(j['lower'], _readDouble(j['y']) - 10),
        upper: _readDouble(j['upper'], _readDouble(j['y']) + 10),
      );

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'lower': lower,
    'upper': upper,
  };
}

class LineConfidenceBandConfig extends BaseChartConfig {
  final List<ConfidenceBandPoint> points;
  final String? bandColor;
  final double bandOpacity;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  LineConfidenceBandConfig({
    required this.points,
    this.theme = ChartTheme.light,
    this.bandColor,
    this.bandOpacity = 0.22,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.lineConfidenceBand, series: const []);

  @override
  Widget buildChart() => _ConfBandWidget(config: this);

  factory LineConfidenceBandConfig.fromJson(Map<String, dynamic> j) {
    final pts = (JsonValue.mapList(j['points']) ?? const [])
        .map(ConfidenceBandPoint.fromJson)
        .toList();
    return LineConfidenceBandConfig(
      points: pts,
      bandColor: JsonValue.string(j['bandColor']),
      bandOpacity: JsonValue.doubleOrNull(j['bandOpacity']) ?? 0.22,
      title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
      tooltip: j['tooltip'] != null
          ? ChartTooltip.fromJson(j['tooltip'])
          : null,
      legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
      toolbox: j['toolbox'] != null
          ? ChartToolbox.fromJson(j['toolbox'])
          : null,
      grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'points': points.map((point) => point.toJson()).toList(),
    if (bandColor != null) 'bandColor': bandColor,
    'bandOpacity': bandOpacity,
  };
}

class _ConfBandWidget extends StatefulWidget {
  final LineConfidenceBandConfig config;
  const _ConfBandWidget({required this.config});
  @override
  State<_ConfBandWidget> createState() => _ConfBandState();
}

class _ConfBandState extends State<_ConfBandWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  LineConfidenceBandConfig get cfg => widget.config;

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
  void didUpdateWidget(_ConfBandWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
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
            painter: _ConfBandPainter(
              cfg: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
    ],
  );
}

class _ConfBandPainter extends ChartPainterBase {
  final LineConfidenceBandConfig cfg;
  final double progress;
  final String dataSignature;
  _ConfBandPainter({
    required this.cfg,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _ConfBandPainter o) =>
      o.progress != progress || o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.points.isEmpty) return;
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 24.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final pts = cfg.points;
    final xMin = pts.map((p) => p.x).reduce(math.min);
    final xMax = pts.map((p) => p.x).reduce(math.max);
    final allY = pts.expand((p) => [p.lower, p.upper]);
    double yMin = allY.reduce(math.min), yMax = allY.reduce(math.max);
    final yPad = (yMax - yMin) * 0.1;
    yMin -= yPad;
    yMax += yPad;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: xMin,
      dataMaxX: xMax,
      dataMinY: yMin,
      dataMaxY: yMax,
    );

    final ticks = ChartDataProcessor.niceYTicks(yMin, yMax);
    _drawYGrid(canvas, vp, ticks, this, (t) => t.toStringAsFixed(1));

    final mainColor = theme.seriesColor(0);
    Color bandC;
    try {
      bandC = cfg.bandColor != null
          ? colorCache.resolve(cfg.bandColor!)
          : mainColor;
    } catch (_) {
      bandC = mainColor;
    }

    // Interpolate bounds toward y (animate from centre)
    Offset toUpper(int i) {
      final p = pts[i];
      return Offset(
        vp.toCanvasX(p.x),
        vp.toCanvasY(p.y + (p.upper - p.y) * progress),
      );
    }

    Offset toLower(int i) {
      final p = pts[i];
      return Offset(
        vp.toCanvasX(p.x),
        vp.toCanvasY(p.y - (p.y - p.lower) * progress),
      );
    }

    Offset toMid(int i) =>
        Offset(vp.toCanvasX(pts[i].x), vp.toCanvasY(pts[i].y));

    final upperPts = List.generate(pts.length, toUpper);
    final lowerPts = List.generate(pts.length, toLower);
    final midPts = List.generate(pts.length, toMid);

    // Band fill
    final bandPath = _smoothPath(upperPts);
    for (int i = lowerPts.length - 1; i >= 0; i--) {
      if (i == lowerPts.length - 1) {
        bandPath.lineTo(lowerPts[i].dx, lowerPts[i].dy);
      } else {
        final p0 = lowerPts[i + 1], p1 = lowerPts[i];
        final cp = (p1.dx - p0.dx) * 0.4;
        bandPath.cubicTo(p0.dx - cp, p0.dy, p1.dx + cp, p1.dy, p1.dx, p1.dy);
      }
    }
    bandPath.close();
    canvas.drawPath(
      bandPath,
      Paint()
        ..color = bandC.withValues(alpha: cfg.bandOpacity)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Upper / lower dashed borders
    canvas.drawPath(
      _smoothPath(upperPts),
      paintCache.stroke(bandC.withValues(alpha: 0.5), 1.0)..isAntiAlias = true,
    );
    canvas.drawPath(
      _smoothPath(lowerPts),
      paintCache.stroke(bandC.withValues(alpha: 0.5), 1.0)..isAntiAlias = true,
    );

    // Main line
    canvas.drawPath(
      _smoothPath(midPts),
      paintCache.stroke(mainColor, 2.2)..isAntiAlias = true,
    );

    // Dots
    for (final p in midPts) {
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = mainColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        p,
        3.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..isAntiAlias = true,
      );
    }

    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. LINE WITH MARK-LINES
// ═══════════════════════════════════════════════════════════════════════════
class MarkLine {
  final String label;
  final double? value; // fixed Y value; null = auto (mean/min/max)
  final String type; // 'average' | 'min' | 'max' | 'fixed'
  final String? color;
  final bool dashed;
  const MarkLine({
    required this.label,
    this.value,
    this.type = 'fixed',
    this.color,
    this.dashed = true,
  });
  factory MarkLine.fromJson(Map<String, dynamic> j) => MarkLine(
    label: JsonValue.string(j['label']) ?? '',
    value: JsonValue.doubleOrNull(j['value']),
    type: JsonValue.string(j['type']) ?? 'fixed',
    color: JsonValue.string(j['color']),
    dashed: JsonValue.boolOrNull(j['dashed']) ?? true,
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    if (value != null) 'value': value,
    'type': type,
    if (color != null) 'color': color,
    'dashed': dashed,
  };
}

class LineMarklineConfig extends BaseChartConfig {
  final List<String> categories;
  final List<MarkLine> marklines;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  LineMarklineConfig({
    this.categories = const [],
    required super.series,
    this.marklines = const [],
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.lineMarkline);

  @override
  Widget buildChart() => _LineMarklineWidget(config: this);

  factory LineMarklineConfig.fromJson(Map<String, dynamic> j) {
    final cats =
        JsonValue.stringList(j['categories']) ??
        JsonValue.stringList(j['xLabels']) ??
        const <String>[];
    final ml = (JsonValue.mapList(j['marklines']) ?? const [])
        .map(MarkLine.fromJson)
        .toList();
    return LineMarklineConfig(
      categories: cats,
      series: _lineVariantSeries(j['series']),
      marklines: ml,
      title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
      tooltip: j['tooltip'] != null
          ? ChartTooltip.fromJson(j['tooltip'])
          : null,
      legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
      toolbox: j['toolbox'] != null
          ? ChartToolbox.fromJson(j['toolbox'])
          : null,
      grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ..._lineVariantBaseJson(this),
    'categories': categories,
    'marklines': marklines.map((markline) => markline.toJson()).toList(),
  };
}

class _LineMarklineWidget extends StatefulWidget {
  final LineMarklineConfig config;
  const _LineMarklineWidget({required this.config});
  @override
  State<_LineMarklineWidget> createState() => _LineMLState();
}

class _LineMLState extends State<_LineMarklineWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  LineMarklineConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
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
            painter: _LineMLPainter(cfg: cfg, progress: _anim.value),
          ),
        ),
      ),
    ],
  );
}

class _LineMLPainter extends ChartPainterBase {
  final LineMarklineConfig cfg;
  final double progress;
  _LineMLPainter({required this.cfg, required this.progress})
    : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _LineMLPainter o) => o.progress != progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.series.isEmpty) return;
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final allVals = cfg.series
        .expand((s) => _lineVariantValues(s.data))
        .toList();
    if (allVals.isEmpty) return;
    double yMin = allVals.reduce(math.min), yMax = allVals.reduce(math.max);
    final yPad = (yMax - yMin) * 0.12;
    yMin -= yPad;
    yMax += yPad;

    final n = cfg.series.fold<int>(
      0,
      (maxLength, series) =>
          math.max(maxLength, _lineVariantValues(series.data).length),
    );
    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: 0,
      dataMaxX: math.max(1, n - 1).toDouble(),
      dataMinY: yMin,
      dataMaxY: yMax,
    );

    final ticks = ChartDataProcessor.niceYTicks(yMin, yMax);
    _drawYGrid(canvas, vp, ticks, this, (t) => t.toStringAsFixed(0));

    // Series lines
    for (int si = 0; si < cfg.series.length; si++) {
      final s = cfg.series[si];
      final vals = _lineVariantValues(s.data);
      final color = theme.seriesColor(si, explicitColor: s.color);
      final pts = List.generate(
        vals.length,
        (i) => Offset(
          vp.toCanvasX(i.toDouble()),
          vp.toCanvasY(yMin + (vals[i] - yMin) * progress),
        ),
      );
      canvas.drawPath(
        _smoothPath(pts),
        paintCache.stroke(color, 2.2)..isAntiAlias = true,
      );
      for (final p in pts) {
        canvas.drawCircle(
          p,
          3,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
      }
    }

    // Mark-lines
    final seriesVals = cfg.series.isNotEmpty
        ? _lineVariantValues(cfg.series.first.data)
        : <double>[];

    for (final ml in cfg.marklines) {
      double mlVal;
      switch (ml.type) {
        case 'average':
          mlVal = seriesVals.isEmpty
              ? 0
              : seriesVals.reduce((a, b) => a + b) / seriesVals.length;
        case 'min':
          mlVal = seriesVals.isEmpty ? 0 : seriesVals.reduce(math.min);
        case 'max':
          mlVal = seriesVals.isEmpty ? 0 : seriesVals.reduce(math.max);
        default:
          mlVal = ml.value ?? 0;
      }
      final mlY = vp.toCanvasY(mlVal);
      if (mlY < padT || mlY > padT + plotH) continue;

      Color mlColor;
      try {
        mlColor = ml.color != null ? colorCache.resolve(ml.color!) : Colors.red;
      } catch (_) {
        mlColor = Colors.red;
      }

      if (ml.dashed) {
        drawDashedLine(
          canvas,
          Offset(padL, mlY),
          Offset(padL + plotW, mlY),
          paintCache.stroke(mlColor, 1.5),
        );
      } else {
        canvas.drawLine(
          Offset(padL, mlY),
          Offset(padL + plotW, mlY),
          paintCache.stroke(mlColor, 1.5),
        );
      }

      final tp = textPainterCache.get(
        '${ml.label}: ${mlVal.toStringAsFixed(1)}',
        theme.typography.axisLabelStyle.copyWith(
          color: mlColor,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
      tp.paint(
        canvas,
        Offset(padL + plotW - tp.width - 4, mlY - tp.height - 2),
      );
    }

    // X labels
    for (int i = 0; i < n; i++) {
      if (cfg.categories.isNotEmpty &&
          i < cfg.categories.length &&
          (i % math.max(1, (n / 8).round()) == 0 || i == n - 1)) {
        final tp = textPainterCache.get(
          cfg.categories[i],
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 9,
          ),
        );
        tp.paint(
          canvas,
          Offset(vp.toCanvasX(i.toDouble()) - tp.width / 2, padT + plotH + 4),
        );
      }
    }
    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. LOG AXIS CHART
// ═══════════════════════════════════════════════════════════════════════════
class LogAxisChartConfig extends BaseChartConfig {
  final List<String> categories;
  final double logBase;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  LogAxisChartConfig({
    this.categories = const [],
    required super.series,
    this.theme = ChartTheme.light,
    this.logBase = 10,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.logAxis);

  @override
  Widget buildChart() => _LogAxisWidget(config: this);

  factory LogAxisChartConfig.fromJson(Map<String, dynamic> j) {
    final cats =
        JsonValue.stringList(j['categories']) ??
        JsonValue.stringList(j['xLabels']) ??
        const <String>[];
    return LogAxisChartConfig(
      categories: cats,
      series: _lineVariantSeries(j['series']),
      logBase: JsonValue.doubleOrNull(j['logBase']) ?? 10,
      title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
      tooltip: j['tooltip'] != null
          ? ChartTooltip.fromJson(j['tooltip'])
          : null,
      legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
      toolbox: j['toolbox'] != null
          ? ChartToolbox.fromJson(j['toolbox'])
          : null,
      grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ..._lineVariantBaseJson(this),
    'categories': categories,
    'logBase': logBase,
  };
}

class _LogAxisWidget extends StatefulWidget {
  final LogAxisChartConfig config;
  const _LogAxisWidget({required this.config});
  @override
  State<_LogAxisWidget> createState() => _LogAxisState();
}

class _LogAxisState extends State<_LogAxisWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  LogAxisChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
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
            painter: _LogAxisPainter(cfg: cfg, progress: _anim.value),
          ),
        ),
      ),
    ],
  );
}

class _LogAxisPainter extends ChartPainterBase {
  final LogAxisChartConfig cfg;
  final double progress;
  _LogAxisPainter({required this.cfg, required this.progress})
    : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _LogAxisPainter o) =>
      o.progress != progress;

  double get _safeLogBase => cfg.logBase > 1 ? cfg.logBase : 10;

  double _log(double v) => v <= 0 ? 0 : math.log(v) / math.log(_safeLogBase);

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.series.isEmpty) return;
    const padL = 58.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final allVals = cfg.series
        .expand((s) => _lineVariantValues(s.data))
        .where((v) => v > 0)
        .toList();
    if (allVals.isEmpty) return;
    final logMin = _log(allVals.reduce(math.min) * 0.8);
    final logMax = _log(allVals.reduce(math.max) * 1.2);

    // Log ticks at powers of logBase
    final minPow = logMin.floor(), maxPow = logMax.ceil();
    final ticks = List.generate(
      maxPow - minPow + 1,
      (i) => math.pow(_safeLogBase, minPow + i).toDouble(),
    );

    for (final t in ticks) {
      final ly = _log(t);
      final y = padT + plotH * (1 - (ly - logMin) / (logMax - logMin));
      if (y < padT || y > padT + plotH) continue;
      canvas.drawLine(
        Offset(padL, y),
        Offset(padL + plotW, y),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final lbl = t >= 1e9
          ? '${(t / 1e9).toStringAsFixed(0)}B'
          : t >= 1e6
          ? '${(t / 1e6).toStringAsFixed(0)}M'
          : t >= 1e3
          ? '${(t / 1e3).toStringAsFixed(0)}K'
          : t.toStringAsFixed(0);
      final tp = textPainterCache.get(
        lbl,
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 8.5,
        ),
        align: TextAlign.right,
        maxWidth: 52,
      );
      tp.paint(canvas, Offset(padL - tp.width - 4, y - tp.height / 2));
    }

    for (int si = 0; si < cfg.series.length; si++) {
      final s = cfg.series[si];
      final vals = _lineVariantValues(s.data);
      final n = vals.length;
      final color = theme.seriesColor(si, explicitColor: s.color);
      final denominator = math.max(1, n - 1);

      final pts = <Offset>[];
      for (int i = 0; i < n; i++) {
        if (vals[i] <= 0) continue;
        final logY = _log(vals[i]);
        final animLogY = logMin + (logY - logMin) * progress;
        final y = padT + plotH * (1 - (animLogY - logMin) / (logMax - logMin));
        pts.add(Offset(padL + i / denominator * plotW, y));
      }
      canvas.drawPath(
        _smoothPath(pts),
        paintCache.stroke(color, 2.2)..isAntiAlias = true,
      );
    }

    // X labels
    final n = _lineVariantValues(cfg.series.first.data).length;
    final denominator = math.max(1, n - 1);
    for (int i = 0; i < n; i++) {
      if (cfg.categories.isNotEmpty &&
          i < cfg.categories.length &&
          (i % math.max(1, (n / 8).round()) == 0 || i == n - 1)) {
        final tp = textPainterCache.get(
          cfg.categories[i],
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 9,
          ),
        );
        tp.paint(
          canvas,
          Offset(
            padL + i / denominator * plotW - tp.width / 2,
            padT + plotH + 4,
          ),
        );
      }
    }
    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. FUNCTION PLOT  (y = f(x))
// ═══════════════════════════════════════════════════════════════════════════
/// Plot mathematical expressions. [expressions] is a list of Dart function
/// strings evaluated at runtime — or supply [functions] directly for type safety.
///
/// JSON:
/// ```json
/// { "type": "functionPlot",
///   "xMin": -6.28, "xMax": 6.28, "yMin": -1.2, "yMax": 1.2,
///   "functions": [
///     {"label": "sin(x)",  "color": "#42A5F5"},
///     {"label": "cos(x)",  "color": "#EF5350"},
///     {"label": "sin(2x)", "color": "#66BB6A"}
///   ]}
/// ```
/// (Provide [functions] callbacks programmatically for full power.)
class FunctionSeries {
  final String label;
  final String? color;
  final double Function(double x)? fn;
  const FunctionSeries({required this.label, this.color, this.fn});

  factory FunctionSeries.fromJson(Map<String, dynamic> j) => FunctionSeries(
    label: JsonValue.string(j['label']) ?? '',
    color: JsonValue.string(j['color']),
    // JSON-driven: parse common math expressions
    fn: _parseExpr(JsonValue.string(j['label']) ?? ''),
  );

  static double Function(double)? _parseExpr(String expr) {
    final e = expr.toLowerCase().replaceAll(' ', '');
    if (e.contains('sin(2x)')) return (x) => math.sin(2 * x);
    if (e.contains('cos(2x)')) return (x) => math.cos(2 * x);
    if (e.contains('sin(x)')) return (x) => math.sin(x);
    if (e.contains('cos(x)')) return (x) => math.cos(x);
    if (e.contains('tan(x)')) return (x) => math.tan(x).clamp(-10, 10);
    if (e.contains('x^2') || e.contains('x²')) return (x) => x * x;
    if (e.contains('x^3') || e.contains('x³')) return (x) => x * x * x;
    if (e.contains('sqrt(x)') || e.contains('√x')) {
      return (x) => x >= 0 ? math.sqrt(x) : double.nan;
    }
    if (e.contains('exp(x)') || e.contains('e^x')) {
      return (x) => math.exp(x).clamp(-1e6, 1e6);
    }
    if (e.contains('abs(x)') || e.contains('|x|')) return (x) => x.abs();
    return (x) => x; // fallback: f(x) = x
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    if (color != null) 'color': color,
  };
}

class FunctionPlotConfig extends BaseChartConfig {
  final List<FunctionSeries> functions;
  final double xMin, xMax, yMin, yMax;
  final int resolution;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  FunctionPlotConfig({
    required this.functions,
    this.xMin = -10,
    this.xMax = 10,
    this.yMin = -10,
    this.yMax = 10,
    this.resolution = 400,
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.functionPlot, series: const []);

  @override
  Widget buildChart() => _FuncPlotWidget(config: this);

  factory FunctionPlotConfig.fromJson(Map<String, dynamic> j) {
    final fns = (JsonValue.mapList(j['functions']) ?? const [])
        .map(FunctionSeries.fromJson)
        .toList();
    return FunctionPlotConfig(
      functions: fns,
      xMin: JsonValue.doubleOrNull(j['xMin']) ?? -10,
      xMax: JsonValue.doubleOrNull(j['xMax']) ?? 10,
      yMin: JsonValue.doubleOrNull(j['yMin']) ?? -10,
      yMax: JsonValue.doubleOrNull(j['yMax']) ?? 10,
      resolution: math.max(1, JsonValue.intOrNull(j['resolution']) ?? 400),
      title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
      tooltip: j['tooltip'] != null
          ? ChartTooltip.fromJson(j['tooltip'])
          : null,
      legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
      toolbox: j['toolbox'] != null
          ? ChartToolbox.fromJson(j['toolbox'])
          : null,
      grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ..._lineVariantBaseJson(this),
    'functions': functions.map((function) => function.toJson()).toList(),
    'xMin': xMin,
    'xMax': xMax,
    'yMin': yMin,
    'yMax': yMax,
    'resolution': resolution,
    'series': [
      for (final function in functions)
        {
          'name': function.label,
          if (function.color != null) 'color': function.color,
          'data': _sampleFunction(function),
        },
    ],
  };

  List<List<Object?>> _sampleFunction(FunctionSeries function) {
    final fn = function.fn;
    if (fn == null) return const [];
    final sampleCount = resolution < 1 ? 1 : resolution + 1;
    final step = resolution <= 0 ? 0 : (xMax - xMin) / resolution;
    return [
      for (var i = 0; i < sampleCount; i++)
        _functionPointJson(xMin + (i * step), fn),
    ];
  }

  List<Object?> _functionPointJson(
    double x,
    double Function(double x) function,
  ) {
    final y = function(x);
    return [x, y.isFinite ? y : null];
  }
}

class _FuncPlotWidget extends StatefulWidget {
  final FunctionPlotConfig config;
  const _FuncPlotWidget({required this.config});
  @override
  State<_FuncPlotWidget> createState() => _FuncPlotState();
}

class _FuncPlotState extends State<_FuncPlotWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  FunctionPlotConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
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
            painter: _FuncPlotPainter(cfg: cfg, progress: _anim.value),
          ),
        ),
      ),
    ],
  );
}

class _FuncPlotPainter extends ChartPainterBase {
  final FunctionPlotConfig cfg;
  final double progress;
  _FuncPlotPainter({required this.cfg, required this.progress})
    : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _FuncPlotPainter o) =>
      o.progress != progress;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: cfg.xMin,
      dataMaxX: cfg.xMax,
      dataMinY: cfg.yMin,
      dataMaxY: cfg.yMax,
    );

    // Grid
    final yTicks = ChartDataProcessor.niceYTicks(cfg.yMin, cfg.yMax);
    _drawYGrid(canvas, vp, yTicks, this, (t) => t.toStringAsFixed(0));

    // X axis ticks
    final xTicks = ChartDataProcessor.niceYTicks(cfg.xMin, cfg.xMax);
    for (final t in xTicks) {
      final x = vp.toCanvasX(t);
      canvas.drawLine(
        Offset(x, padT),
        Offset(x, padT + plotH),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final tp = textPainterCache.get(
        t.toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
      );
      tp.paint(canvas, Offset(x - tp.width / 2, padT + plotH + 4));
    }

    // Zero lines
    final zeroY = vp.toCanvasY(0);
    if (zeroY >= padT && zeroY <= padT + plotH) {
      canvas.drawLine(
        Offset(padL, zeroY),
        Offset(padL + plotW, zeroY),
        paintCache.stroke(theme.axisColor.withValues(alpha: 0.4), 1.0),
      );
    }
    final zeroX = vp.toCanvasX(0);
    if (zeroX >= padL && zeroX <= padL + plotW) {
      canvas.drawLine(
        Offset(zeroX, padT),
        Offset(zeroX, padT + plotH),
        paintCache.stroke(theme.axisColor.withValues(alpha: 0.4), 1.0),
      );
    }

    // Each function
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(padL, padT, plotW, plotH));
    final step = (cfg.xMax - cfg.xMin) / cfg.resolution;

    for (int fi = 0; fi < cfg.functions.length; fi++) {
      final fn = cfg.functions[fi];
      if (fn.fn == null) continue;
      final color = theme.seriesColor(fi, explicitColor: fn.color);
      final countVisible = (cfg.resolution * progress).toInt().clamp(
        1,
        cfg.resolution,
      );

      final path = Path();
      bool moved = false;
      for (int ri = 0; ri <= countVisible; ri++) {
        final x = cfg.xMin + ri * step;
        final y = fn.fn!(x);
        if (y.isNaN || y.isInfinite || y < cfg.yMin || y > cfg.yMax) {
          moved = false;
          continue;
        }
        final cx = vp.toCanvasX(x);
        final cy = vp.toCanvasY(y);
        if (!moved) {
          path.moveTo(cx, cy);
          moved = true;
        } else {
          path.lineTo(cx, cy);
        }
      }
      canvas.drawPath(path, paintCache.stroke(color, 2.0)..isAntiAlias = true);
    }
    canvas.restore();

    // Legend
    for (int fi = 0; fi < cfg.functions.length; fi++) {
      final fn = cfg.functions[fi];
      final color = theme.seriesColor(fi, explicitColor: fn.color);
      final tp = textPainterCache.get(
        fn.label,
        theme.typography.axisLabelStyle.copyWith(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      );
      tp.paint(
        canvas,
        Offset(padL + fi * (plotW / cfg.functions.length) + 4, padT + 4),
      );
    }
    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 7. SPARKLINE MATRIX
// ═══════════════════════════════════════════════════════════════════════════
class SparklineMatrixCell {
  final String label;
  final List<double> values;
  final String? color;
  const SparklineMatrixCell({
    required this.label,
    required this.values,
    this.color,
  });
  factory SparklineMatrixCell.fromJson(Map<String, dynamic> j) =>
      SparklineMatrixCell(
        label: JsonValue.string(j['label']) ?? '',
        values: _lineVariantValues(j['values']),
        color: JsonValue.string(j['color']),
      );

  Map<String, dynamic> toJson() => {
    'label': label,
    'values': values,
    if (color != null) 'color': color,
  };
}

class SparklineMatrixConfig extends BaseChartConfig {
  final List<SparklineMatrixCell> cells;
  final int columns;
  final double sparklineHeight;
  final bool showTrend;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  SparklineMatrixConfig({
    required this.cells,
    this.columns = 3,
    this.sparklineHeight = 50,
    this.showTrend = true,
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.sparklineMatrix, series: const []);

  @override
  Widget buildChart() => _SparklineMatrixWidget(config: this);

  factory SparklineMatrixConfig.fromJson(Map<String, dynamic> j) {
    final cells = (JsonValue.mapList(j['cells']) ?? const [])
        .map(SparklineMatrixCell.fromJson)
        .toList();
    return SparklineMatrixConfig(
      cells: cells,
      columns: math.max(1, JsonValue.intOrNull(j['columns']) ?? 3),
      sparklineHeight: JsonValue.doubleOrNull(j['sparklineHeight']) ?? 50,
      showTrend: JsonValue.boolOrNull(j['showTrend']) ?? true,
      title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
      tooltip: j['tooltip'] != null
          ? ChartTooltip.fromJson(j['tooltip'])
          : null,
      legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
      toolbox: j['toolbox'] != null
          ? ChartToolbox.fromJson(j['toolbox'])
          : null,
      grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ..._lineVariantBaseJson(this),
    'cells': cells.map((cell) => cell.toJson()).toList(),
    'series': [
      for (final cell in cells)
        {
          'name': cell.label,
          if (cell.color != null) 'color': cell.color,
          'data': cell.values,
        },
    ],
    'columns': columns,
    'sparklineHeight': sparklineHeight,
    'showTrend': showTrend,
  };
}

class _SparklineMatrixWidget extends StatefulWidget {
  final SparklineMatrixConfig config;
  const _SparklineMatrixWidget({required this.config});
  @override
  State<_SparklineMatrixWidget> createState() => _SpkMatState();
}

class _SpkMatState extends State<_SparklineMatrixWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  SparklineMatrixConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cfg.columns,
              childAspectRatio: 2.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: cfg.cells.length,
            itemBuilder: (ctx, i) {
              final cell = cfg.cells[i];
              final vals = cell.values;
              Color color;
              try {
                color = cell.color != null
                    ? colorCache.resolve(cell.color!)
                    : cfg.theme.seriesColor(i);
              } catch (_) {
                color = cfg.theme.seriesColor(i);
              }
              final trend = vals.length >= 2 ? vals.last - vals.first : 0.0;
              return Container(
                decoration: BoxDecoration(
                  color: cfg.theme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cfg.theme.gridColor, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cell.label,
                              style: cfg.theme.typography.axisLabelStyle
                                  .copyWith(
                                    color: cfg.theme.titleColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (cfg.showTrend)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  trend >= 0
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  size: 13,
                                  color: trend >= 0 ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}',
                                  style: cfg.theme.typography.axisLabelStyle
                                      .copyWith(
                                        color: trend >= 0
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 9,
                                      ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _MiniSparkPainter(
                            vals: vals,
                            color: color,
                            progress: _anim.value,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniSparkPainter extends CustomPainter {
  final List<double> vals;
  final Color color;
  final double progress;
  _MiniSparkPainter({
    required this.vals,
    required this.color,
    required this.progress,
  });

  @override
  bool shouldRepaint(covariant _MiniSparkPainter o) =>
      o.progress != progress || o.vals != vals;

  @override
  void paint(Canvas canvas, Size size) {
    if (vals.length < 2) return;
    const pad = 4.0;
    final w = size.width - pad * 2, h = size.height - pad * 2;
    final minV = vals.reduce(math.min), maxV = vals.reduce(math.max);
    final range = (maxV - minV).clamp(1e-9, 1e18);
    final n = vals.length;
    final pts = List.generate(
      n,
      (i) => Offset(
        pad + i / (n - 1) * w,
        pad + h * (1 - (vals[i] - minV) / range * progress),
      ),
    );

    final path = _smoothPath(pts);
    final areaPath = Path.from(path)
      ..lineTo(pts.last.dx, pad + h)
      ..lineTo(pts.first.dx, pad + h)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..isAntiAlias = true,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 8. INTRADAY LINE WITH BREAKS
// ═══════════════════════════════════════════════════════════════════════════
class IntradayPoint {
  final double x; // time as numeric (e.g. seconds since midnight)
  final double? y; // null = break (no-data gap)
  const IntradayPoint({required this.x, this.y});
  factory IntradayPoint.fromJson(Map<String, dynamic> j) => IntradayPoint(
    x: JsonValue.doubleOrNull(j['x']) ?? 0,
    y: JsonValue.doubleOrNull(j['y']),
  );

  Map<String, dynamic> toJson() => {'x': x, if (y != null) 'y': y};
}

List<IntradayPoint> _intradayPoints(Object? raw) {
  final points = JsonValue.list(raw) ?? const <dynamic>[];
  return points
      .map(_intradayPointOrNull)
      .whereType<IntradayPoint>()
      .toList(growable: false);
}

IntradayPoint? _intradayPointOrNull(Object? raw) {
  final map = JsonValue.map(raw);
  if (map != null) {
    final x = JsonValue.doubleOrNull(map['x']);
    if (x == null) return null;
    return IntradayPoint(x: x, y: JsonValue.doubleOrNull(map['y']));
  }

  final row = JsonValue.list(raw);
  if (row == null || row.isEmpty) return null;
  final x = JsonValue.doubleOrNull(row[0]);
  if (x == null) return null;
  return IntradayPoint(
    x: x,
    y: row.length > 1 ? JsonValue.doubleOrNull(row[1]) : null,
  );
}

class IntradayLineConfig extends BaseChartConfig {
  final List<IntradayPoint> points;
  final String xLabel, yLabel;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  IntradayLineConfig({
    required this.points,
    this.xLabel = 'Time',
    this.yLabel = 'Price',
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.intradayLine, series: const []);

  @override
  Widget buildChart() => _IntradayWidget(config: this);

  factory IntradayLineConfig.fromJson(Map<String, dynamic> j) {
    final pts = _intradayPoints(j['points']);
    return IntradayLineConfig(
      points: pts,
      xLabel: JsonValue.string(j['xLabel']) ?? 'Time',
      yLabel: JsonValue.string(j['yLabel']) ?? 'Price',
      title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
      tooltip: j['tooltip'] != null
          ? ChartTooltip.fromJson(j['tooltip'])
          : null,
      legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
      toolbox: j['toolbox'] != null
          ? ChartToolbox.fromJson(j['toolbox'])
          : null,
      grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ..._lineVariantBaseJson(this),
    'points': points.map((point) => point.toJson()).toList(),
    'series': [
      {
        'data': [
          for (final point in points) [point.x, point.y],
        ],
      },
    ],
    'xLabel': xLabel,
    'yLabel': yLabel,
  };
}

class _IntradayWidget extends StatefulWidget {
  final IntradayLineConfig config;
  const _IntradayWidget({required this.config});
  @override
  State<_IntradayWidget> createState() => _IntradayState();
}

class _IntradayState extends State<_IntradayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  IntradayLineConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
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
            painter: _IntradayPainter(cfg: cfg, progress: _anim.value),
          ),
        ),
      ),
    ],
  );
}

class _IntradayPainter extends ChartPainterBase {
  final IntradayLineConfig cfg;
  final double progress;
  _IntradayPainter({required this.cfg, required this.progress})
    : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _IntradayPainter o) =>
      o.progress != progress;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = cfg.points.where((p) => p.y != null).toList();
    if (pts.isEmpty) return;
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 24.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final xMin = cfg.points.map((p) => p.x).reduce(math.min);
    var xMax = cfg.points.map((p) => p.x).reduce(math.max);
    if (xMax <= xMin) xMax = xMin + 1;
    final yVals = pts.map((p) => p.y!);
    double yMin = yVals.reduce(math.min), yMax = yVals.reduce(math.max);
    final yPad = (yMax - yMin) * 0.1 + 1;
    yMin -= yPad;
    yMax += yPad;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: xMin,
      dataMaxX: xMax,
      dataMinY: yMin,
      dataMaxY: yMax,
    );

    final ticks = ChartDataProcessor.niceYTicks(yMin, yMax);
    _drawYGrid(canvas, vp, ticks, this, (t) => t.toStringAsFixed(1));

    // Count visible points based on progress
    final allPts = cfg.points;
    final visible = (allPts.length * progress).round().clamp(0, allPts.length);
    final color = theme.seriesColor(0);

    // Draw segments, breaking at null y
    final path = Path();
    bool drawing = false;
    for (int i = 0; i < visible; i++) {
      final p = allPts[i];
      if (p.y == null) {
        drawing = false;
        continue;
      }
      final cx = vp.toCanvasX(p.x);
      final cy = vp.toCanvasY(p.y!);
      if (!drawing) {
        path.moveTo(cx, cy);
        drawing = true;
      } else {
        path.lineTo(cx, cy);
      }
    }
    canvas.drawPath(path, paintCache.stroke(color, 1.8)..isAntiAlias = true);

    // Break indicators
    for (int i = 1; i < visible; i++) {
      if (allPts[i].y == null && allPts[i - 1].y != null) {
        final cx = vp.toCanvasX(allPts[i].x);
        canvas.drawLine(
          Offset(cx, padT),
          Offset(cx, padT + plotH),
          paintCache.stroke(theme.gridColor.withValues(alpha: 0.5), 1.0)
            ..strokeWidth = 1.0,
        );
      }
    }

    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 9. LINE CLICK TO ADD POINTS
// ═══════════════════════════════════════════════════════════════════════════
class LineClickAddConfig extends BaseChartConfig {
  final List<double> initialX, initialY;
  final String? seriesName;
  final void Function(double x, double y)? onPointAdded;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  LineClickAddConfig({
    this.initialX = const [],
    this.initialY = const [],
    this.seriesName,
    this.onPointAdded,
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.lineClickAdd, series: const []);

  @override
  Widget buildChart() => LineClickAddWidget(config: this);

  factory LineClickAddConfig.fromJson(
    Map<String, dynamic> j,
  ) => LineClickAddConfig(
    initialX: JsonValue.doubleList(j['initialX']) ?? const <double>[],
    initialY: JsonValue.doubleList(j['initialY']) ?? const <double>[],
    seriesName: JsonValue.string(j['seriesName']),
    title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
    tooltip: j['tooltip'] != null ? ChartTooltip.fromJson(j['tooltip']) : null,
    legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
    toolbox: j['toolbox'] != null ? ChartToolbox.fromJson(j['toolbox']) : null,
    grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
  );
  @override
  Map<String, dynamic> toJson() {
    final count = math.min(initialX.length, initialY.length);
    return {
      ..._lineVariantBaseJson(this),
      'initialX': initialX,
      'initialY': initialY,
      if (seriesName != null) 'seriesName': seriesName,
      'series': [
        {
          if (seriesName != null) 'name': seriesName,
          'data': [
            for (var i = 0; i < count; i++) [initialX[i], initialY[i]],
          ],
        },
      ],
    };
  }
}

class LineClickAddWidget extends StatefulWidget {
  final LineClickAddConfig config;
  const LineClickAddWidget({super.key, required this.config});
  @override
  State<LineClickAddWidget> createState() => _LineClickState();
}

class _LineClickState extends State<LineClickAddWidget> {
  late List<Offset> _points;
  LineClickAddConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    final n = math.min(cfg.initialX.length, cfg.initialY.length);
    _points = List.generate(n, (i) => Offset(cfg.initialX[i], cfg.initialY[i]));
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
              const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
              final sz = Size(con.maxWidth, con.maxHeight);
              final plotW = sz.width - padL - padR;
              final plotH = sz.height - padT - padB;

              double xMin = 0, xMax = 10, yMin = 0, yMax = 10;
              if (_points.length >= 2) {
                xMin = _points.map((p) => p.dx).reduce(math.min);
                xMax = _points.map((p) => p.dx).reduce(math.max);
                yMin = _points.map((p) => p.dy).reduce(math.min);
                yMax = _points.map((p) => p.dy).reduce(math.max);
                final xPad = (xMax - xMin) * 0.15 + 1;
                final yPad = (yMax - yMin) * 0.15 + 1;
                xMin -= xPad;
                xMax += xPad;
                yMin -= yPad;
                yMax += yPad;
              }

              return GestureDetector(
                onTapDown: (d) {
                  final tx = (d.localPosition.dx - padL) / plotW;
                  final ty = 1 - (d.localPosition.dy - padT) / plotH;
                  if (tx < 0 || tx > 1 || ty < 0 || ty > 1) return;
                  final dataX = xMin + tx * (xMax - xMin);
                  final dataY = yMin + ty * (yMax - yMin);
                  setState(() {
                    _points.add(Offset(dataX, dataY));
                    _points.sort((a, b) => a.dx.compareTo(b.dx));
                  });
                  cfg.onPointAdded?.call(dataX, dataY);
                },
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _LineClickPainter(
                          cfg: cfg,
                          points: _points,
                          xMin: xMin,
                          xMax: xMax,
                          yMin: yMin,
                          yMax: yMax,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => setState(() => _points.clear()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cfg.theme.tooltipBackgroundColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Clear',
                            style: cfg.theme.typography.tooltipStyle.copyWith(
                              color: cfg.theme.tooltipTextColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: padL + 6,
                      child: Text(
                        'Tap to add points (${_points.length})',
                        style: cfg.theme.typography.axisLabelStyle.copyWith(
                          color: cfg.theme.axisLabelColor.withValues(
                            alpha: 0.5,
                          ),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LineClickPainter extends ChartPainterBase {
  final LineClickAddConfig cfg;
  final List<Offset> points;
  final double xMin, xMax, yMin, yMax;
  _LineClickPainter({
    required this.cfg,
    required this.points,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _LineClickPainter o) =>
      o.points.length != points.length;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: xMin,
      dataMaxX: xMax,
      dataMinY: yMin,
      dataMaxY: yMax,
    );

    final ticks = ChartDataProcessor.niceYTicks(yMin, yMax);
    _drawYGrid(canvas, vp, ticks, this, (t) => t.toStringAsFixed(1));

    final xTicks = ChartDataProcessor.niceYTicks(xMin, xMax);
    for (final t in xTicks) {
      final x = vp.toCanvasX(t);
      final tp = textPainterCache.get(
        t.toStringAsFixed(1),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
      );
      tp.paint(canvas, Offset(x - tp.width / 2, padT + plotH + 4));
    }

    final color = theme.seriesColor(0);
    final canvasPts = points.map((p) => vp.toCanvas(p.dx, p.dy)).toList();

    if (canvasPts.length >= 2) {
      canvas.drawPath(
        _smoothPath(canvasPts),
        paintCache.stroke(color, 2.2)..isAntiAlias = true,
      );
    }
    for (final cp in canvasPts) {
      canvas.drawCircle(
        cp,
        5,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        cp,
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..isAntiAlias = true,
      );
    }

    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 10. DYNAMIC TIME SERIES (live-updating sliding window)
// ═══════════════════════════════════════════════════════════════════════════
class DynamicTimeSeriesConfig extends BaseChartConfig {
  final int windowSize;
  final Duration updateInterval;
  final double Function()? dataGenerator;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  DynamicTimeSeriesConfig({
    this.windowSize = 60,
    this.updateInterval = const Duration(milliseconds: 500),
    this.dataGenerator,
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.dynamicTimeSeries, series: const []);

  @override
  Widget buildChart() => DynamicTimeSeriesWidget(config: this);

  factory DynamicTimeSeriesConfig.fromJson(
    Map<String, dynamic> j,
  ) => DynamicTimeSeriesConfig(
    windowSize: math.max(1, JsonValue.intOrNull(j['windowSize']) ?? 60),
    updateInterval: Duration(
      milliseconds: math.max(
        1,
        JsonValue.intOrNull(j['updateIntervalMs']) ?? 500,
      ),
    ),
    title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
    tooltip: j['tooltip'] != null ? ChartTooltip.fromJson(j['tooltip']) : null,
    legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
    toolbox: j['toolbox'] != null ? ChartToolbox.fromJson(j['toolbox']) : null,
    grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
  );
  @override
  Map<String, dynamic> toJson() => {
    ..._lineVariantBaseJson(this),
    'windowSize': windowSize,
    'updateIntervalMs': updateInterval.inMilliseconds,
    'hasDataGenerator': dataGenerator != null,
  };
}

class DynamicTimeSeriesWidget extends StatefulWidget {
  final DynamicTimeSeriesConfig config;
  const DynamicTimeSeriesWidget({super.key, required this.config});
  @override
  State<DynamicTimeSeriesWidget> createState() => _DynTSState();
}

class _DynTSState extends State<DynamicTimeSeriesWidget> {
  final List<double> _data = [];
  final _rand = math.Random();
  double _last = 50.0;
  late dynamic _timer; // Timer

  DynamicTimeSeriesConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    // Pre-fill with initial data
    for (int i = 0; i < cfg.windowSize; i++) {
      _addPoint();
    }
    _timer = Stream.periodic(cfg.updateInterval).listen((_) {
      if (mounted) setState(() => _addPoint());
    });
  }

  void _addPoint() {
    final newVal = cfg.dataGenerator != null
        ? cfg.dataGenerator!()
        : _last + (_rand.nextDouble() - 0.48) * 4;
    _last = newVal.clamp(0.0, 100.0);
    _data.add(_last);
    if (_data.length > cfg.windowSize) _data.removeAt(0);
  }

  @override
  void dispose() {
    (_timer as dynamic).cancel();
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
            painter: _DynTSPainter(cfg: cfg, data: List.from(_data)),
          ),
        ),
      ),
    ],
  );
}

class _DynTSPainter extends ChartPainterBase {
  final DynamicTimeSeriesConfig cfg;
  final List<double> data;
  _DynTSPainter({required this.cfg, required this.data})
    : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _DynTSPainter o) =>
      o.data.length != data.length ||
      (data.isNotEmpty && o.data.last != data.last);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 24.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    double yMin = data.reduce(math.min) - 2;
    double yMax = data.reduce(math.max) + 2;
    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: 0,
      dataMaxX: (data.length - 1).toDouble(),
      dataMinY: yMin,
      dataMaxY: yMax,
    );

    final ticks = ChartDataProcessor.niceYTicks(yMin, yMax);
    _drawYGrid(canvas, vp, ticks, this, (t) => t.toStringAsFixed(0));

    final color = theme.seriesColor(0);
    final pts = List.generate(
      data.length,
      (i) => Offset(vp.toCanvasX(i.toDouble()), vp.toCanvasY(data[i])),
    );

    // Area
    final areaPath = Path.from(_smoothPath(pts))
      ..lineTo(pts.last.dx, padT + plotH)
      ..lineTo(pts.first.dx, padT + plotH)
      ..close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Line
    canvas.drawPath(
      _smoothPath(pts),
      paintCache.stroke(color, 1.8)..isAntiAlias = true,
    );

    // Latest value dot
    canvas.drawCircle(
      pts.last,
      4,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Latest value label
    final tp = textPainterCache.get(
      data.last.toStringAsFixed(1),
      theme.typography.axisLabelStyle.copyWith(
        color: color,
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
      ),
    );
    tp.paint(canvas, Offset(pts.last.dx + 5, pts.last.dy - tp.height / 2));

    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}
