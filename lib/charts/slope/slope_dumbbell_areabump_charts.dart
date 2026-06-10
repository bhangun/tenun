// Three advanced comparison charts:
//   1. `SlopeChartConfig`     - before/after slope chart (two-column comparison)
//   2. `DumbbellChartConfig`  - connected dot pairs (range / change per row)
//   3. `AreaBumpChartConfig`  - ranking area bump chart (rank over time)

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/base_config.dart';
import '../../core/chart_data_value_reader.dart';
import '../../core/chart_type.dart';
import '../../core/chart_theme.dart';
import '../../core/series.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';
import '../../core/legend.dart';
import '../../core/grid.dart';
import '../../core/chart_model.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_data_processor.dart';
import '../../core/chart_cache.dart';
import '../../core/chart_data_signature.dart';
import '../../core/chart_series_json.dart';
import '../../core/json_value.dart';

List<Series> _comparisonSeries(Object? raw) =>
    ChartSeriesJson.mapList(raw).map(Series.fromJson).toList(growable: false);

double? _seriesValueAt(Series series, int index) {
  final data = series.data;
  if (data == null || index < 0 || index >= data.length) return null;
  return ChartDataValueReader.yValueOrNull(data[index]);
}

List<String> _stringList(Object? raw) =>
    JsonValue.stringList(raw) ?? const <String>[];

double _nonNegativeDouble(Object? raw, double fallback) {
  final value = JsonValue.doubleOrNull(raw) ?? fallback;
  return math.max(0, value);
}

double _unitDouble(Object? raw, double fallback) {
  final value = JsonValue.doubleOrNull(raw) ?? fallback;
  return value.clamp(0.0, 1.0).toDouble();
}

TitlesData? _title(Object? raw) {
  final json = JsonValue.map(raw);
  return json == null ? null : TitlesData.fromJson(json);
}

ChartTooltip? _tooltip(Object? raw) {
  final json = JsonValue.map(raw);
  return json == null ? null : ChartTooltip.fromJson(json);
}

ChartLegend? _legend(Object? raw) {
  final json = JsonValue.map(raw);
  return json == null ? null : ChartLegend.fromJson(json);
}

ChartToolbox? _toolbox(Object? raw) {
  final json = JsonValue.map(raw);
  return json == null ? null : ChartToolbox.fromJson(json);
}

GridData? _grid(Object? raw) {
  final json = JsonValue.map(raw);
  return json == null ? null : GridData.fromJson(json);
}

// ═══════════════════════════════════════════════════════════
// 1. SLOPE CHART
// ═══════════════════════════════════════════════════════════
///
/// Shows change between exactly two time-points / conditions as
/// sloped lines.  Each series produces one line from column-A to
/// column-B, labelled on both ends.
///
/// JSON:
/// ```json
/// { "type":"slope",
///   "columnLabels":["2020","2024"],
///   "series":[
///     {"name":"Revenue",  "data":[42, 78]},
///     {"name":"Costs",    "data":[55, 61]},
///     {"name":"Headcount","data":[120,95]}
///   ]}
/// ```
class SlopeChartConfig extends BaseChartConfig {
  final List<String> columnLabels;
  final bool showDelta; // show % change label on the line
  final bool showEndLabels;
  final double lineWidth;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  SlopeChartConfig({
    required this.columnLabels,
    required super.series,
    this.theme = ChartTheme.light,
    this.showDelta = true,
    this.showEndLabels = true,
    this.lineWidth = 2.0,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.slope);

  @override
  Widget buildChart() => SlopeChartWidget(config: this);

  factory SlopeChartConfig.fromJson(Map<String, dynamic> json) {
    final cols = _stringList(
      json['columnLabels'] ?? json['categories'] ?? json['xLabels'],
    );
    final s = _comparisonSeries(json['series']);
    return SlopeChartConfig(
      columnLabels: cols,
      series: s,
      showDelta: JsonValue.boolOrNull(json['showDelta']) ?? true,
      showEndLabels: JsonValue.boolOrNull(json['showEndLabels']) ?? true,
      lineWidth: _nonNegativeDouble(json['lineWidth'], 2.0),
      title: _title(json['title']),
      tooltip: _tooltip(json['tooltip']),
      legend: _legend(json['legend']),
      toolbox: _toolbox(json['toolbox']),
      grid: _grid(json['grid']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'columnLabels': columnLabels,
    'showDelta': showDelta,
    'showEndLabels': showEndLabels,
    'lineWidth': lineWidth,
  };
}

class SlopeChartWidget extends StatefulWidget {
  final SlopeChartConfig config;
  const SlopeChartWidget({super.key, required this.config});
  @override
  State<SlopeChartWidget> createState() => _SlopeState();
}

class _SlopeState extends State<SlopeChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  SlopeChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _dataSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(SlopeChartWidget oldWidget) {
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
            painter: _SlopePainter(
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

class _SlopePainter extends ChartPainterBase {
  final SlopeChartConfig config;
  final double progress;
  final String dataSignature;

  _SlopePainter({
    required this.config,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _SlopePainter old) =>
      old.progress != progress || old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    if (config.series.isEmpty) return;
    const labelW = 72.0, dotR = 5.0, padV = 32.0;
    final plotL = labelW, plotR = size.width - labelW;
    final plotT = padV + 20, plotB = size.height - padV;

    // Collect all values to determine Y range
    final allVals = <double>[];
    for (final s in config.series) {
      final d = s.data;
      if (d != null && d.length >= 2) {
        final v0 = _seriesValueAt(s, 0);
        final v1 = _seriesValueAt(s, 1);
        if (v0 != null) allVals.add(v0);
        if (v1 != null) allVals.add(v1);
      }
    }
    if (allVals.isEmpty) return;
    final yMin = allVals.reduce(math.min);
    final yMax = allVals.reduce(math.max);
    final yPad = (yMax - yMin) * 0.1 + 0.001;
    final yRange = (yMax - yMin + yPad * 2);

    double toY(double v) =>
        plotB - ((v - yMin + yPad) / yRange) * (plotB - plotT);

    // Column header labels
    final cols = config.columnLabels.length >= 2
        ? config.columnLabels
        : ['Before', 'After'];
    for (int ci = 0; ci < 2; ci++) {
      final x = ci == 0 ? plotL : plotR;
      final tp = textPainterCache.get(
        cols[ci],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.titleColor,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      );
      tp.paint(canvas, Offset(x - tp.width / 2, padV - tp.height - 4));
    }

    // Grid lines for Y ticks
    final yTicks = ChartDataProcessor.niceYTicks(yMin, yMax);
    final vp = ChartViewport(
      left: plotL,
      top: plotT,
      right: plotR,
      bottom: plotB,
      dataMinX: 0,
      dataMaxX: 1,
      dataMinY: yMin - yPad,
      dataMaxY: yMax + yPad,
    );
    drawHorizontalGrid(canvas, vp, yTicks);
    drawYAxisLabels(canvas, vp, yTicks, (v) => v.toStringAsFixed(0));

    // Lines
    for (int si = 0; si < config.series.length; si++) {
      final s = config.series[si];
      final d = s.data;
      if (d == null || d.length < 2) continue;
      final v0 = _seriesValueAt(s, 0);
      final v1 = _seriesValueAt(s, 1);
      if (v0 == null || v1 == null) continue;
      final color = theme.seriesColor(si, explicitColor: s.color);

      final y0 = toY(v0);
      final y1raw = toY(v1);
      // Animate y1 toward its final position from y0
      final y1 = y0 + (y1raw - y0) * progress;

      // Line
      canvas.drawLine(
        Offset(plotL, y0),
        Offset(plotR, y1),
        paintCache.stroke(color, config.lineWidth),
      );

      // Dots
      canvas.drawCircle(
        Offset(plotL, y0),
        dotR,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        Offset(plotR, y1),
        dotR,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      if (config.showEndLabels) {
        // Left label: "Name: value"
        final lbl0 = '${s.name ?? ''}: ${v0.toStringAsFixed(1)}';
        final tp0 = textPainterCache.get(
          lbl0,
          theme.typography.axisLabelStyle.copyWith(color: color, fontSize: 9.5),
          maxWidth: labelW - 8,
          align: TextAlign.right,
        );
        tp0.paint(canvas, Offset(plotL - tp0.width - 8, y0 - tp0.height / 2));

        // Right label: value (+ delta)
        final delta = v1 - v0;
        final deltaStr = config.showDelta
            ? ' (${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)})'
            : '';
        final lbl1 = '${v1.toStringAsFixed(1)}$deltaStr';
        final tp1 = textPainterCache.get(
          lbl1,
          theme.typography.axisLabelStyle.copyWith(color: color, fontSize: 9.5),
          maxWidth: labelW - 8,
        );
        tp1.paint(canvas, Offset(plotR + 8, y1 - tp1.height / 2));
      }
    }

    // Column axis lines
    canvas.drawLine(Offset(plotL, plotT - 4), Offset(plotL, plotB), axisPaint);
    canvas.drawLine(Offset(plotR, plotT - 4), Offset(plotR, plotB), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════
// 2. DUMBBELL CHART
// ═══════════════════════════════════════════════════════════
///
/// Horizontal dot-pair chart. Each category has two values connected
/// by a line, showing range or change.
///
/// JSON:
/// ```json
/// { "type":"dumbbell",
///   "categories":["Engineering","Sales","Marketing","Design"],
///   "series":[
///     {"name":"Min Salary","data":[65,55,50,60],"color":"#90CAF9"},
///     {"name":"Max Salary","data":[120,95,85,105],"color":"#1565C0"}
///   ]}
/// ```
class DumbbellChartConfig extends BaseChartConfig {
  final List<String> categories;
  final bool showValues;
  final double dotRadius;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  DumbbellChartConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.showValues = true,
    this.dotRadius = 7.0,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.dumbbell);

  @override
  Widget buildChart() => DumbbellChartWidget(config: this);

  factory DumbbellChartConfig.fromJson(Map<String, dynamic> json) {
    final cats = _stringList(json['categories'] ?? json['labels']);
    final s = _comparisonSeries(json['series']);
    return DumbbellChartConfig(
      categories: cats,
      series: s,
      showValues: JsonValue.boolOrNull(json['showValues']) ?? true,
      dotRadius: _nonNegativeDouble(json['dotRadius'], 7.0),
      title: _title(json['title']),
      tooltip: _tooltip(json['tooltip']),
      legend: _legend(json['legend']),
      toolbox: _toolbox(json['toolbox']),
      grid: _grid(json['grid']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'showValues': showValues,
    'dotRadius': dotRadius,
  };
}

class DumbbellChartWidget extends StatefulWidget {
  final DumbbellChartConfig config;
  const DumbbellChartWidget({super.key, required this.config});
  @override
  State<DumbbellChartWidget> createState() => _DumbbellState();
}

class _DumbbellState extends State<DumbbellChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  int _hovCat = -1;
  Offset _hoverPos = Offset.zero;
  DumbbellChartConfig get cfg => widget.config;

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
  void didUpdateWidget(DumbbellChartWidget oldWidget) {
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
                      final rowH =
                          (sz.height -
                              sp.chartPaddingTop -
                              sp.chartPaddingBottom) /
                          n;
                      final ci =
                          ((e.localPosition.dy - sp.chartPaddingTop) / rowH)
                              .floor()
                              .clamp(0, n - 1);
                      setState(() {
                        _hovCat = ci;
                        _hoverPos = e.localPosition;
                      });
                    },
                    onExit: (_) => setState(() => _hovCat = -1),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _DumbbellPainter(
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
        _buildLegend(),
      ],
    );
  }

  Widget _buildTooltip(Size sz) {
    double x = (_hoverPos.dx + 12).clamp(0, sz.width - 200.0);
    double y = (_hoverPos.dy - 70).clamp(0, sz.height - 90.0);
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
                ...cfg.series.asMap().entries.map((e) {
                  final v = _seriesValueAt(e.value, _hovCat);
                  if (v == null) return const SizedBox();
                  return Text(
                    '${e.value.name ?? 'Series ${e.key + 1}'}: ${v.toStringAsFixed(1)}',
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    if (cfg.series.length < 2) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 14,
        alignment: WrapAlignment.center,
        children: cfg.series.asMap().entries.map((e) {
          final color = cfg.theme.seriesColor(
            e.key,
            explicitColor: e.value.color,
          );
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
                e.value.name ?? 'Series ${e.key + 1}',
                style: cfg.theme.typography.legendStyle.copyWith(
                  color: cfg.theme.legendTextColor,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DumbbellPainter extends ChartPainterBase {
  final DumbbellChartConfig config;
  final double progress;
  final int hovCat;
  final String dataSignature;
  _DumbbellPainter({
    required this.config,
    required this.progress,
    required this.hovCat,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _DumbbellPainter old) =>
      old.progress != progress ||
      old.hovCat != hovCat ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = config.categories.length;
    if (n == 0 || config.series.length < 2) return;
    final sp = theme.spacing;

    // X range from all series combined
    final allVals = <double>[];
    for (final s in config.series) {
      final data = s.data ?? const <dynamic>[];
      for (var index = 0; index < data.length; index++) {
        final value = _seriesValueAt(s, index);
        if (value != null) allVals.add(value);
      }
    }
    if (allVals.isEmpty) return;
    final xMin = allVals.reduce(math.min);
    final xMax = allVals.reduce(math.max);
    final xPad = (xMax - xMin) * 0.08 + 0.001;

    const catLabelW = 90.0;
    final plotL = sp.chartPaddingLeft + catLabelW;
    final plotR = size.width - sp.chartPaddingRight - 40;
    final plotT = sp.chartPaddingTop;
    final plotB = size.height - sp.chartPaddingBottom;
    final rowH = (plotB - plotT) / n;

    double toX(double v) =>
        plotL +
        ((v - (xMin - xPad)) / ((xMax + xPad) - (xMin - xPad))) *
            (plotR - plotL) *
            progress;

    // X axis ticks
    final xTicks = ChartDataProcessor.niceYTicks(xMin, xMax);
    for (final t in xTicks) {
      final x =
          plotL +
          ((t - (xMin - xPad)) / ((xMax + xPad) - (xMin - xPad))) *
              (plotR - plotL);
      canvas.drawLine(
        Offset(x, plotT),
        Offset(x, plotB),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final tp = textPainterCache.get(
        t.toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
      );
      tp.paint(canvas, Offset(x - tp.width / 2, plotB + 2));
    }

    for (int ci = 0; ci < n; ci++) {
      final cy = plotT + (ci + 0.5) * rowH;
      final isHov = ci == hovCat;

      // Category label
      final lbl = textPainterCache.get(
        config.categories[ci],
        theme.typography.axisLabelStyle.copyWith(
          color: isHov ? theme.titleColor : theme.axisLabelColor,
          fontSize: 10,
          fontWeight: isHov ? FontWeight.w600 : FontWeight.normal,
        ),
        maxWidth: catLabelW - 8,
        align: TextAlign.right,
      );
      lbl.paint(canvas, Offset(plotL - lbl.width - 10, cy - lbl.height / 2));

      // Values from all series for this category
      final vals = <({double v, Color color, String name})>[];
      for (int si = 0; si < config.series.length; si++) {
        final value = _seriesValueAt(config.series[si], ci);
        if (value != null) {
          vals.add((
            v: value,
            color: theme.seriesColor(
              si,
              explicitColor: config.series[si].color,
            ),
            name: config.series[si].name ?? 'S${si + 1}',
          ));
        }
      }
      if (vals.length < 2) continue;

      // Sort by value so the connecting line is always low→high
      vals.sort((a, b) => a.v.compareTo(b.v));
      final x0 = toX(vals.first.v);
      final x1 = toX(vals.last.v);

      // Connector line
      canvas.drawLine(
        Offset(x0, cy),
        Offset(x1, cy),
        paintCache.stroke(
          theme.gridColor.withValues(alpha: 0.6),
          isHov ? 2.5 : 1.5,
        ),
      );

      // Dots and labels
      for (final item in vals) {
        final x = toX(item.v);
        final r = isHov ? config.dotRadius + 2 : config.dotRadius;
        canvas.drawCircle(
          Offset(x, cy),
          r,
          Paint()
            ..color = item.color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        canvas.drawCircle(
          Offset(x, cy),
          r,
          paintCache.stroke(Colors.white, 1.5),
        );

        if (config.showValues && isHov) {
          final vtp = textPainterCache.get(
            item.v.toStringAsFixed(1),
            theme.typography.axisLabelStyle.copyWith(
              color: item.color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          );
          vtp.paint(canvas, Offset(x - vtp.width / 2, cy - r - vtp.height - 1));
        }
      }
    }
    canvas.drawLine(Offset(plotL, plotT), Offset(plotL, plotB), axisPaint);
    canvas.drawLine(Offset(plotL, plotB), Offset(plotR, plotB), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════
// 3. AREA BUMP CHART  (ranking over time)
// ═══════════════════════════════════════════════════════════
///
/// Visualises how series rankings change over time using smooth
/// filled bands. Lower rank number = higher position on chart.
///
/// JSON:
/// ```json
/// { "type":"areaBump",
///   "periods":["Q1","Q2","Q3","Q4"],
///   "series":[
///     {"name":"Product A","ranks":[1,2,1,1]},
///     {"name":"Product B","ranks":[2,1,3,2]},
///     {"name":"Product C","ranks":[3,3,2,3]}
///   ]}
/// ```
class AreaBumpSeries {
  final String name;
  final List<int> ranks; // rank at each period (1 = top)
  final String? color;
  const AreaBumpSeries({required this.name, required this.ranks, this.color});

  factory AreaBumpSeries.fromJson(Map<String, dynamic> j) => AreaBumpSeries(
    name: JsonValue.string(j['name']) ?? '',
    ranks: (JsonValue.intList(j['ranks'] ?? j['data']) ?? const <int>[])
        .where((rank) => rank > 0)
        .toList(growable: false),
    color: JsonValue.string(j['color']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'ranks': ranks,
    if (color != null) 'color': color,
  };
}

class AreaBumpChartConfig extends BaseChartConfig {
  final List<String> periods;
  final List<AreaBumpSeries> bumps;
  final double bandOpacity;
  final double smoothing; // 0=straight, 1=fully smooth
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  AreaBumpChartConfig({
    required this.periods,
    required this.bumps,
    this.theme = ChartTheme.light,
    this.bandOpacity = 0.72,
    this.smoothing = 0.4,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.areaBump, series: const []);

  @override
  Widget buildChart() => AreaBumpChartWidget(config: this);

  factory AreaBumpChartConfig.fromJson(Map<String, dynamic> json) {
    final periods = _stringList(json['periods'] ?? json['categories']);
    final bumps = ChartSeriesJson.mapList(
      json['series'] ?? json['bumps'],
    ).map(AreaBumpSeries.fromJson).toList(growable: false);
    return AreaBumpChartConfig(
      periods: periods,
      bumps: bumps,
      bandOpacity: _unitDouble(json['bandOpacity'], 0.72),
      smoothing: _unitDouble(json['smoothing'], 0.4),
      title: _title(json['title']),
      tooltip: _tooltip(json['tooltip']),
      legend: _legend(json['legend']),
      toolbox: _toolbox(json['toolbox']),
      grid: _grid(json['grid']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'periods': periods,
    'series': bumps.map((bump) => bump.toJson()).toList(),
    'bandOpacity': bandOpacity,
    'smoothing': smoothing,
  };
}

class AreaBumpChartWidget extends StatefulWidget {
  final AreaBumpChartConfig config;
  const AreaBumpChartWidget({super.key, required this.config});
  @override
  State<AreaBumpChartWidget> createState() => _AreaBumpState();
}

class _AreaBumpState extends State<AreaBumpChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  int _hovSeries = -1;
  Offset _hoverPos = Offset.zero;
  AreaBumpChartConfig get cfg => widget.config;

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
  void didUpdateWidget(AreaBumpChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _hovSeries = -1;
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
                      final np = cfg.periods.length;
                      if (np < 2) return;
                      final plotL = sp.chartPaddingLeft + 8.0;
                      final plotR = sz.width - sp.chartPaddingRight - 8.0;
                      final colW = (plotR - plotL) / (np - 1);
                      final ci = ((e.localPosition.dx - plotL) / colW)
                          .round()
                          .clamp(0, np - 1);
                      // Find which band the y is in
                      final maxRank = cfg.bumps
                          .map(
                            (b) => b.ranks.isNotEmpty
                                ? b.ranks.reduce(math.max)
                                : 0,
                          )
                          .fold(0, math.max);
                      if (maxRank == 0) return;
                      final plotT = sp.chartPaddingTop.toDouble();
                      final plotB = sz.height - sp.chartPaddingBottom;
                      final rowH = (plotB - plotT) / (maxRank + 1);
                      final rankAtX = ci < e.localPosition.dx
                          ? ((e.localPosition.dy - plotT) / rowH).round().clamp(
                              1,
                              maxRank,
                            )
                          : 1;
                      // Find series whose rank at ci matches
                      int hov = -1;
                      for (int si = 0; si < cfg.bumps.length; si++) {
                        final b = cfg.bumps[si];
                        if (ci < b.ranks.length && b.ranks[ci] == rankAtX) {
                          hov = si;
                          break;
                        }
                      }
                      setState(() {
                        _hovSeries = hov;
                        _hoverPos = e.localPosition;
                      });
                    },
                    onExit: (_) => setState(() => _hovSeries = -1),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _AreaBumpPainter(
                          config: cfg,
                          progress: _anim.value,
                          hovSeries: _hovSeries,
                          dataSignature: _dataSignature,
                        ),
                      ),
                    ),
                  ),
                  if (_hovSeries >= 0) _buildTooltip(sz),
                ],
              );
            },
          ),
        ),
        _buildLegend(),
      ],
    );
  }

  Widget _buildTooltip(Size sz) {
    final b = cfg.bumps[_hovSeries];
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
                  b.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Ranks: ${b.ranks.join(' → ')}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      spacing: 12,
      alignment: WrapAlignment.center,
      children: cfg.bumps.asMap().entries.map((e) {
        final color = cfg.theme.seriesColor(
          e.key,
          explicitColor: e.value.color,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 8,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              e.value.name,
              style: cfg.theme.typography.legendStyle.copyWith(
                color: cfg.theme.legendTextColor,
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );
}

class _AreaBumpPainter extends ChartPainterBase {
  final AreaBumpChartConfig config;
  final double progress;
  final int hovSeries;
  final String dataSignature;
  _AreaBumpPainter({
    required this.config,
    required this.progress,
    required this.hovSeries,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _AreaBumpPainter old) =>
      old.progress != progress ||
      old.hovSeries != hovSeries ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final np = config.periods.length;
    if (np < 2 || config.bumps.isEmpty) return;
    final sp = theme.spacing;

    final maxRank = config.bumps
        .expand((b) => b.ranks)
        .fold(0, (a, b) => a > b ? a : b);
    if (maxRank == 0) return;

    const labelW = 8.0;
    final plotL = sp.chartPaddingLeft + labelW;
    final plotR = size.width - sp.chartPaddingRight - labelW;
    final plotT = sp.chartPaddingTop.toDouble();
    final plotB = size.height - sp.chartPaddingBottom;
    final colW = (plotR - plotL) / (np - 1);
    // row height: divide plot into (maxRank+1) slots with padding
    final rowH = (plotB - plotT) / (maxRank + 1);
    final bandH = rowH * 0.65;

    // rankY: centre Y for a given rank
    double rankY(int rank) => plotT + rank * rowH;

    // Period labels along x
    for (int pi = 0; pi < np; pi++) {
      final x = plotL + pi * colW;
      final tp = textPainterCache.get(
        config.periods[pi],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9.5,
        ),
      );
      tp.paint(canvas, Offset(x - tp.width / 2, plotB + 3));
      canvas.drawLine(
        Offset(x, plotT),
        Offset(x, plotB),
        paintCache.stroke(theme.gridColor.withValues(alpha: 0.4), 0.5),
      );
    }

    // Draw series bands back-to-front (hovered last)
    final order = List.generate(config.bumps.length, (i) => i)
      ..sort(
        (a, b) => a == hovSeries
            ? 1
            : b == hovSeries
            ? -1
            : 0,
      );

    for (final si in order) {
      final b = config.bumps[si];
      if (b.ranks.length < np) continue;
      final isHov = si == hovSeries;
      final color = theme.seriesColor(si, explicitColor: b.color);
      final alpha = isHov ? 1.0 : (hovSeries >= 0 ? 0.35 : 1.0);

      // Build cubic bezier band path through ranks
      // Upper edge (rank - bandH/2 animated) and lower edge (rank + bandH/2)
      final topPts = <Offset>[];
      final botPts = <Offset>[];
      for (int pi = 0; pi < np; pi++) {
        final x = plotL + pi * colW;
        final rank = b.ranks[pi];
        final ry = rankY(rank);
        final actualY = plotT + (ry - plotT) * progress;
        topPts.add(Offset(x, actualY - bandH / 2 * progress));
        botPts.add(Offset(x, actualY + bandH / 2 * progress));
      }

      // Build smooth path
      Path buildSmooth(List<Offset> pts, {bool reverse = false}) {
        final path = Path();
        if (pts.isEmpty) return path;
        path.moveTo(pts.first.dx, pts.first.dy);
        for (int i = 0; i < pts.length - 1; i++) {
          final p0 = pts[i], p1 = pts[i + 1];
          final ctrl = colW * config.smoothing;
          path.cubicTo(p0.dx + ctrl, p0.dy, p1.dx - ctrl, p1.dy, p1.dx, p1.dy);
        }
        return path;
      }

      final topPath = buildSmooth(topPts);

      // Band = top path forward + bottom path backward, closed
      final bandPath = Path()..addPath(topPath, Offset.zero);
      for (int i = botPts.length - 1; i >= 0; i--) {
        if (i == botPts.length - 1) {
          bandPath.lineTo(botPts[i].dx, botPts[i].dy);
        } else {
          final p0 = botPts[i + 1], p1 = botPts[i];
          final ctrl = colW * config.smoothing;
          bandPath.cubicTo(
            p0.dx - ctrl,
            p0.dy,
            p1.dx + ctrl,
            p1.dy,
            p1.dx,
            p1.dy,
          );
        }
      }
      bandPath.close();

      canvas.drawPath(
        bandPath,
        Paint()
          ..color = color.withValues(
            alpha: (config.bandOpacity * alpha).clamp(0.0, 1.0),
          )
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      // Stroke centre line
      final centrePath = buildSmooth(
        List.generate(np, (pi) {
          final x = plotL + pi * colW;
          final ry = plotT + rankY(b.ranks[pi]) * progress;
          return Offset(x, ry * progress + plotT * (1 - progress));
        }),
      );
      canvas.drawPath(
        centrePath,
        paintCache.stroke(
          color.withValues(alpha: alpha.clamp(0.0, 1.0)),
          isHov ? 2.5 : 1.5,
        ),
      );

      // Rank dots
      for (int pi = 0; pi < np; pi++) {
        canvas.drawCircle(
          topPts[pi].translate(0, bandH / 2 * progress),
          isHov ? 5.0 : 3.5,
          Paint()
            ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
      }

      // Series name label at last column
      if (isHov || hovSeries < 0) {
        final lastX = plotL + (np - 1) * colW;
        final lastY =
            plotT + rankY(b.ranks[np - 1]) * progress + plotT * (1 - progress);
        final tp = textPainterCache.get(
          b.name,
          theme.typography.axisLabelStyle.copyWith(
            color: color,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
          maxWidth: labelW + 60,
        );
        tp.paint(canvas, Offset(lastX + 8, lastY - tp.height / 2));
      }
    }
  }
}
