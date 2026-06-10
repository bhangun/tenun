/// Combo chart — bar and line series sharing the same axis.
///
/// Each series declares its render type via `"seriesType": "bar"` or `"line"`.
/// Optionally a secondary Y-axis can be assigned to specific series
/// via `"yAxis": 1`.
///
/// JSON:
/// ```json
/// {
///   "type": "combo",
///   "categories": ["Q1","Q2","Q3","Q4"],
///   "series": [
///     { "name": "Revenue",  "seriesType": "bar",  "data": [820, 930, 1140, 1300] },
///     { "name": "Costs",    "seriesType": "bar",  "data": [600, 680, 790,  960]  },
///     { "name": "Margin %", "seriesType": "line", "data": [27,  27,  31,   26],  "yAxis": 1 }
///   ]
/// }
/// ```
library;

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
import '../../core/chart_data_processor.dart';
import '../../core/chart_data_value_reader.dart';
import '../../core/chart_cache.dart';
import '../../core/chart_data_signature.dart';
import '../../core/json_value.dart';

// ─────────────────────────────────────────────────────────
// Extended series model
// ─────────────────────────────────────────────────────────

enum ComboSeriesType { bar, line }

class ComboSeries {
  final Series base;
  final ComboSeriesType seriesType;
  final int yAxis; // 0 = left, 1 = right

  const ComboSeries({
    required this.base,
    this.seriesType = ComboSeriesType.bar,
    this.yAxis = 0,
  });

  factory ComboSeries.fromJson(Map<String, dynamic> j) {
    final t = j['seriesType']?.toString().toLowerCase() == 'line'
        ? ComboSeriesType.line
        : ComboSeriesType.bar;
    return ComboSeries(
      base: Series.fromJson(j),
      seriesType: t,
      yAxis: JsonValue.intOrNull(j['yAxis']) ?? 0,
    );
  }

  List<double> get values =>
      (base.data ?? []).map(ChartDataValueReader.yValue).toList();

  Map<String, dynamic> toJson() => {
    ...base.toJson(),
    'seriesType': seriesType.name,
    'yAxis': yAxis,
  };
}

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

class ComboChartConfig extends BaseChartConfig {
  final List<String> categories;
  final List<ComboSeries> comboSeries;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;
  final bool showLegend;
  final double barGroupWidthFraction;
  final double dotRadius;

  ComboChartConfig({
    required this.categories,
    required this.comboSeries,
    this.theme = ChartTheme.light,
    this.showLegend = true,
    this.barGroupWidthFraction = 0.7,
    this.dotRadius = 4.0,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(
         type: ChartType.combo,
         series: comboSeries.map((s) => s.base).toList(),
       );

  @override
  Widget buildChart() => ComboChartWidget(config: this);

  factory ComboChartConfig.fromJson(Map<String, dynamic> json) {
    final cats = JsonValue.stringList(json['categories']) ?? const <String>[];
    final comboSeries = (JsonValue.mapList(json['series']) ?? const [])
        .map(ComboSeries.fromJson)
        .toList();
    return ComboChartConfig(
      categories: cats,
      comboSeries: comboSeries,
      showLegend: JsonValue.boolOrNull(json['showLegend']) ?? true,
      barGroupWidthFraction:
          JsonValue.doubleOrNull(json['barGroupWidth']) ?? 0.7,
      dotRadius: JsonValue.doubleOrNull(json['dotRadius']) ?? 4.0,
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
    'series': comboSeries.map((s) => s.toJson()).toList(),
    'showLegend': showLegend,
    'barGroupWidth': barGroupWidthFraction,
    'dotRadius': dotRadius,
  };
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

class ComboChartWidget extends StatefulWidget {
  final ComboChartConfig config;
  const ComboChartWidget({super.key, required this.config});
  @override
  State<ComboChartWidget> createState() => _ComboState();
}

class _ComboState extends State<ComboChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  int _hovIdx = -1;
  Offset _hoverPos = Offset.zero;

  ComboChartConfig get cfg => widget.config;

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
  void didUpdateWidget(ComboChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _hovIdx = -1;
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
                    onHover: (e) => setState(() {
                      _hovIdx = _hitTest(e.localPosition, sz);
                      _hoverPos = e.localPosition;
                    }),
                    onExit: (_) => setState(() => _hovIdx = -1),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _ComboPainter(
                          config: cfg,
                          progress: _anim.value,
                          hovIdx: _hovIdx,
                          dataSignature: _dataSignature,
                        ),
                      ),
                    ),
                  ),
                  if (_hovIdx >= 0) _buildTooltip(sz),
                ],
              );
            },
          ),
        ),
        if (cfg.showLegend) _buildLegend(),
      ],
    );
  }

  int _hitTest(Offset pos, Size sz) {
    final sp = cfg.theme.spacing;
    final n = cfg.categories.length;
    if (n == 0) return -1;
    final slotW = (sz.width - sp.chartPaddingLeft - sp.chartPaddingRight) / n;
    final idx = ((pos.dx - sp.chartPaddingLeft) / slotW).floor();
    return idx.clamp(0, n - 1);
  }

  Widget _buildTooltip(Size sz) {
    final cat = _hovIdx < cfg.categories.length ? cfg.categories[_hovIdx] : '';
    double x = (_hoverPos.dx + 12).clamp(0, sz.width - 180.0);
    double y = (_hoverPos.dy - 60).clamp(0, sz.height - 100.0);
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
                Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                ...cfg.comboSeries.asMap().entries.map((e) {
                  final v = _hovIdx < e.value.values.length
                      ? e.value.values[_hovIdx]
                      : 0.0;
                  return Text(
                    '${e.value.base.name ?? "S${e.key + 1}"}: ${v.toStringAsFixed(1)}',
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
      children: cfg.comboSeries.asMap().entries.map((e) {
        final color = cfg.theme.seriesColor(
          e.key,
          explicitColor: e.value.base.itemStyle?.color,
        );
        final isLine = e.value.seriesType == ComboSeriesType.line;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLine)
              Container(width: 16, height: 3, color: color)
            else
              Container(width: 10, height: 10, color: color),
            const SizedBox(width: 4),
            Text(
              e.value.base.name ?? 'S${e.key + 1}',
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

// ─────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────

class _ComboPainter extends ChartPainterBase {
  final ComboChartConfig config;
  final double progress;
  final int hovIdx;
  final String dataSignature;

  _ComboPainter({
    required this.config,
    required this.progress,
    required this.hovIdx,
    required this.dataSignature,
  }) : super(theme: config.theme);

  @override
  bool shouldRepaintChart(covariant _ComboPainter old) =>
      old.progress != progress ||
      old.hovIdx != hovIdx ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = config.categories.length;
    if (n == 0) return;
    final sp = theme.spacing;

    // Compute Y bounds for each axis
    double y0Min = 0, y0Max = 0, y1Min = 0, y1Max = 0;
    for (final s in config.comboSeries) {
      for (final v in s.values) {
        if (s.yAxis == 0) {
          if (v < y0Min) y0Min = v;
          if (v > y0Max) y0Max = v;
        } else {
          if (v < y1Min) y1Min = v;
          if (v > y1Max) y1Max = v;
        }
      }
    }
    final hasRight = config.comboSeries.any((s) => s.yAxis == 1);
    final rightPad = hasRight ? 48.0 : sp.chartPaddingRight;
    final y0Upper = y0Max <= 0 ? 1.0 : y0Max * 1.12;
    final y1Upper = y1Max <= 0 ? 1.0 : y1Max * 1.12;

    final vp0 = ChartViewport(
      left: sp.chartPaddingLeft,
      top: sp.chartPaddingTop,
      right: size.width - rightPad,
      bottom: size.height - sp.chartPaddingBottom,
      dataMinX: 0,
      dataMaxX: n.toDouble(),
      dataMinY: 0,
      dataMaxY: y0Upper,
    );

    final yTicks = ChartDataProcessor.niceYTicks(0, y0Max);
    drawHorizontalGrid(canvas, vp0, yTicks);
    drawYAxisLabels(canvas, vp0, yTicks, (v) => v.toStringAsFixed(0));

    if (hasRight) {
      final vp1 = ChartViewport(
        left: vp0.left,
        top: vp0.top,
        right: vp0.right,
        bottom: vp0.bottom,
        dataMinX: 0,
        dataMaxX: n.toDouble(),
        dataMinY: 0,
        dataMaxY: y1Upper,
      );
      final y1Ticks = ChartDataProcessor.niceYTicks(0, y1Max);
      for (final t in y1Ticks) {
        final cy = vp1.toCanvasY(t);
        final tp = textPainterCache.get(
          t.toStringAsFixed(0),
          theme.typography.axisLabelStyle.copyWith(color: theme.axisLabelColor),
          maxWidth: 44,
          align: TextAlign.left,
        );
        tp.paint(canvas, Offset(vp0.right + 4, cy - tp.height / 2));
      }
    }

    // Count bar series for grouping
    final barSeries = config.comboSeries
        .where((s) => s.seriesType == ComboSeriesType.bar)
        .toList();
    final slotW = vp0.width / n;
    final groupW = slotW * config.barGroupWidthFraction;
    final barW = barSeries.isEmpty ? 0.0 : groupW / barSeries.length;
    int barIdx = 0;

    for (int si = 0; si < config.comboSeries.length; si++) {
      final s = config.comboSeries[si];
      final color = theme.seriesColor(
        si,
        explicitColor: s.base.itemStyle?.color,
      );
      final vp = s.yAxis == 0
          ? vp0
          : ChartViewport(
              left: vp0.left,
              top: vp0.top,
              right: vp0.right,
              bottom: vp0.bottom,
              dataMinX: 0,
              dataMaxX: n.toDouble(),
              dataMinY: 0,
              dataMaxY: y1Upper,
            );

      if (s.seriesType == ComboSeriesType.bar) {
        for (int i = 0; i < s.values.length; i++) {
          final v = s.values[i];
          final cx = vp.left + (i + 0.5) * slotW;
          final bx = cx - groupW / 2 + barIdx * barW;
          final by = vp.toCanvasY(v * progress);
          final h = (vp.bottom - by).clamp(0.0, vp.height);
          final isHov = i == hovIdx;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(bx, vp.bottom - h, barW - 2, h),
              const Radius.circular(3),
            ),
            Paint()
              ..color = isHov ? Color.lerp(color, Colors.white, 0.2)! : color
              ..style = PaintingStyle.fill
              ..isAntiAlias = true,
          );
        }
        barIdx++;
      } else {
        // Line
        Path? linePath;
        for (int i = 0; i < s.values.length; i++) {
          final cx = vp.left + (i + 0.5) * slotW;
          final cy = vp.toCanvasY(s.values[i] * progress);
          if (linePath == null) {
            linePath = Path()..moveTo(cx, cy);
          } else {
            linePath.lineTo(cx, cy);
          }
        }
        if (linePath != null) {
          canvas.drawPath(linePath, paintCache.stroke(color, 2.5));
        }
        for (int i = 0; i < s.values.length; i++) {
          final cx = vp.left + (i + 0.5) * slotW;
          final cy = vp.toCanvasY(s.values[i] * progress);
          canvas.drawCircle(
            Offset(cx, cy),
            i == hovIdx ? config.dotRadius + 2 : config.dotRadius,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill,
          );
          canvas.drawCircle(
            Offset(cx, cy),
            i == hovIdx ? config.dotRadius + 2 : config.dotRadius,
            paintCache.stroke(Colors.white, 1.5),
          );
        }
      }
    }

    // X labels
    drawXAxisLabels(
      canvas,
      vp0,
      config.categories,
      List.generate(n, (i) => vp0.left + (i + 0.5) * slotW),
    );
    canvas.drawLine(
      Offset(vp0.left, vp0.bottom),
      Offset(vp0.right, vp0.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(vp0.left, vp0.top),
      Offset(vp0.left, vp0.bottom),
      axisPaint,
    );
  }
}
