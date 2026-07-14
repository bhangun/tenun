// Funnel chart — tapering stages showing conversion or flow.
//
// Supports funnel (top-to-bottom taper) and pyramid (bottom-to-top) modes.
// Each stage shows its label, value, and optional percentage.
//
// JSON:
// ```json
// {
//   "type": "funnel",
//   "funnelMode": "funnel",
//   "showPercentage": true,
//   "series": [{
//     "data": [
//       { "name": "Visits",    "value": 10000 },
//       { "name": "Leads",     "value": 6200  },
//       { "name": "Prospects", "value": 3100  },
//       { "name": "Qualified", "value": 1400  },
//       { "name": "Closed",    "value": 420   }
//     ]
//   }]
// }
// ```

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_type.dart';

import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/json_value.dart';
import 'package:tenun_core/core/chart_series_json.dart';

// ─────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────

class FunnelItem {
  final String name;
  final double value;
  final String? color;

  const FunnelItem({required this.name, required this.value, this.color});

  factory FunnelItem.fromJson(Map<String, dynamic> j) => FunnelItem(
    name: j['name']?.toString() ?? '',
    value: JsonValue.doubleOrNull(j['value']) ?? 0,
    color: j['color']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    if (color != null) 'color': color,
  };
}

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

enum FunnelMode { funnel, pyramid }

class FunnelChartConfig extends BaseChartConfig {
  final List<FunnelItem> items;
  final FunnelMode funnelMode;
  final bool showLabels;
  final bool showValues;
  final bool showPercentage;
  final bool showConversionRate;
  final double neckWidthFraction; // minimum width as fraction of max
  final double gapFraction; // gap between stages

  FunnelChartConfig({
    required this.items,
    super.theme = ChartTheme.light,
    this.funnelMode = FunnelMode.funnel,
    this.showLabels = true,
    this.showValues = true,
    this.showPercentage = false,
    this.showConversionRate = false,
    this.neckWidthFraction = 0.18,
    this.gapFraction = 0.015,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.funnel, series: const []);

  @override
  Widget buildChart() => FunnelChartWidget(config: this);

  factory FunnelChartConfig.fromJson(Map<String, dynamic> json) {
    final items = ChartSeriesJson.firstSeriesData(
      json['series'],
    ).map(FunnelItem.fromJson).toList();

    final modeStr = json['funnelMode']?.toString().toLowerCase() ?? 'funnel';
    return FunnelChartConfig(
      items: items,
      funnelMode: modeStr == 'pyramid' ? FunnelMode.pyramid : FunnelMode.funnel,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? true,
      showValues: JsonValue.boolOrNull(json['showValues']) ?? true,
      showPercentage: JsonValue.boolOrNull(json['showPercentage']) ?? false,
      showConversionRate:
          JsonValue.boolOrNull(json['showConversionRate']) ?? false,
      neckWidthFraction:
          JsonValue.doubleOrNull(json['neckWidthFraction']) ?? 0.18,
      gapFraction: JsonValue.doubleOrNull(json['gapFraction']) ?? 0.015,
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
    'type': 'funnel',
    'funnelMode': funnelMode == FunnelMode.pyramid ? 'pyramid' : 'funnel',
    'showLabels': showLabels,
    'showValues': showValues,
    'showPercentage': showPercentage,
    'showConversionRate': showConversionRate,
    'neckWidthFraction': neckWidthFraction,
    'series': [
      {'data': items.map((i) => i.toJson()).toList()},
    ],
  };
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

class FunnelChartWidget extends StatefulWidget {
  final FunnelChartConfig config;
  const FunnelChartWidget({super.key, required this.config});

  @override
  State<FunnelChartWidget> createState() => _FunnelState();
}

class _FunnelState extends State<FunnelChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _hoveredIndex = -1;
  Offset _hoverPos = Offset.zero;

  FunnelChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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

  int _hitTest(Offset pos, Size sz) {
    if (cfg.items.isEmpty) return -1;
    const padH = 16.0, padV = 8.0;
    final w = sz.width - padH * 2;
    final totalH = sz.height - padV * 2;
    if (w <= 0 || totalH <= 0) return -1;

    final gap = totalH * math.max(0.0, cfg.gapFraction);
    final stageH = (totalH - gap * (cfg.items.length - 1)) / cfg.items.length;
    if (!stageH.isFinite || stageH <= 0) return -1;

    final maxVal = cfg.items.map((i) => i.value).reduce(math.max);
    if (!maxVal.isFinite || maxVal <= 0) return -1;

    final neck = cfg.neckWidthFraction.clamp(0.0, 1.0).toDouble();

    for (int i = 0; i < cfg.items.length; i++) {
      final y = padV + i * (stageH + gap);
      final frac = cfg.items[i].value / maxVal;
      final nextFrac = i + 1 < cfg.items.length
          ? cfg.items[i + 1].value / maxVal
          : neck;

      final topW = (neck + (frac - neck) * 1.0).clamp(neck, 1.0) * w;
      final botW = (neck + (nextFrac - neck) * 1.0).clamp(neck, 1.0) * w;

      final topX1 = padH + (w - topW) / 2;
      final topX2 = topX1 + topW;
      final botX1 = padH + (w - botW) / 2;
      final botX2 = botX1 + botW;

      // Point-in-trapezoid test using y interpolation
      if (pos.dy >= y && pos.dy <= y + stageH) {
        final t = (pos.dy - y) / stageH;
        final xl = topX1 + (botX1 - topX1) * t;
        final xr = topX2 + (botX2 - topX2) * t;
        if (pos.dx >= xl && pos.dx <= xr) return i;
      }
    }
    return -1;
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
                      _hoveredIndex = _hitTest(e.localPosition, sz);
                      _hoverPos = e.localPosition;
                    }),
                    onExit: (_) => setState(() => _hoveredIndex = -1),
                    child: GestureDetector(
                      onTapDown: (d) => setState(() {
                        _hoveredIndex = _hitTest(d.localPosition, sz);
                        _hoverPos = d.localPosition;
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _FunnelPainter(
                            config: cfg,
                            progress: _anim.value,
                            hoveredIndex: _hoveredIndex,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_hoveredIndex >= 0) _buildTooltip(sz),
                ],
              );
            },
          ),
        ),
        if (cfg.legend?.show == true) _buildLegend(),
      ],
    );
  }

  Widget _buildTooltip(Size sz) {
    final item = cfg.items[_hoveredIndex];
    final maxVal = cfg.items.map((i) => i.value).reduce(math.max);
    final pct = (item.value / maxVal * 100).toStringAsFixed(1);
    final conv = _hoveredIndex > 0
        ? (item.value / cfg.items[_hoveredIndex - 1].value * 100)
              .toStringAsFixed(1)
        : null;
    double x = (_hoverPos.dx + 14).clamp(0, sz.width - 180.0);
    double y = (_hoverPos.dy - 55).clamp(0, sz.height - 100.0);
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
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Value: ${_fmt(item.value)}'),
                Text('Share: $pct%'),
                if (conv != null)
                  Text(
                    'Conversion: $conv%',
                    style: TextStyle(
                      color: cfg.theme.tooltipTextColor.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: cfg.items.asMap().entries.map((e) {
          final color = cfg.theme.seriesColor(
            e.key,
            explicitColor: e.value.color,
          );
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, color: color),
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

  String _fmt(double v) => v >= 1000000
      ? '${(v / 1000000).toStringAsFixed(1)}M'
      : v >= 1000
      ? '${(v / 1000).toStringAsFixed(1)}K'
      : v.toStringAsFixed(0);
}

// ─────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────

class _FunnelPainter extends ChartPainterBase {
  final FunnelChartConfig config;
  final double progress;
  final int hoveredIndex;

  _FunnelPainter({
    required this.config,
    required this.progress,
    required this.hoveredIndex,
  }) : super(theme: config.theme);

  @override
  bool shouldRepaintChart(covariant _FunnelPainter old) =>
      old.progress != progress || old.hoveredIndex != hoveredIndex;

  String _fmt(double v) => v >= 1e6
      ? '${(v / 1e6).toStringAsFixed(1)}M'
      : v >= 1e3
      ? '${(v / 1e3).toStringAsFixed(1)}K'
      : v.toStringAsFixed(0);

  @override
  void paint(Canvas canvas, Size size) {
    if (config.items.isEmpty) return;

    const padH = 16.0, padV = 8.0;
    final areaW = size.width - padH * 2;
    final totalH = size.height - padV * 2;
    if (areaW <= 0 || totalH <= 0) return;

    final gap = totalH * math.max(0.0, config.gapFraction);
    final n = config.items.length;
    final stageH = (totalH - gap * (n - 1)) / n;
    if (!stageH.isFinite || stageH <= 0) return;

    final maxVal = config.items.map((i) => i.value).reduce(math.max);
    if (!maxVal.isFinite || maxVal <= 0) return;

    final neck = config.neckWidthFraction.clamp(0.0, 1.0).toDouble();
    final isPyramid = config.funnelMode == FunnelMode.pyramid;
    final drawProgress = progress.isFinite
        ? progress.clamp(0.0, 1.0).toDouble()
        : 0.0;

    for (int i = 0; i < n; i++) {
      final idx = isPyramid ? (n - 1 - i) : i;
      final item = config.items[idx];
      final y = padV + i * (stageH + gap);

      final nextIdx = isPyramid ? (n - 2 - i) : (i + 1);
      final nextFrac = nextIdx >= 0 && nextIdx < n
          ? config.items[nextIdx].value / maxVal
          : neck;

      final frac = item.value / maxVal;
      final topW =
          (neck + (frac - neck)).clamp(neck, 1.0) * areaW * drawProgress;
      final botW =
          (neck + (nextFrac - neck)).clamp(neck, 1.0) * areaW * drawProgress;

      final topX1 = padH + (areaW - topW) / 2;
      final topX2 = topX1 + topW;
      final botX1 = padH + (areaW - botW) / 2;
      final botX2 = botX1 + botW;

      final isHovered = idx == hoveredIndex;
      final color = theme.seriesColor(idx, explicitColor: item.color);
      final fillColor = isHovered
          ? Color.lerp(color, Colors.white, 0.2)!
          : color;

      final path = Path()
        ..moveTo(topX1, y)
        ..lineTo(topX2, y)
        ..lineTo(botX2, y + stageH)
        ..lineTo(botX1, y + stageH)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        path,
        paintCache.stroke(Colors.white.withValues(alpha: 0.4), 1),
      );

      // Labels
      final labelMaxWidth = math.min(math.max(topW, botW), areaW) - 8;
      if (config.showLabels && stageH > 16 && labelMaxWidth >= 24) {
        final cx = padH + areaW / 2;
        final cy = y + stageH / 2;
        final lines = <String>[];
        lines.add(item.name);
        if (config.showValues) lines.add(_fmt(item.value));
        if (config.showPercentage) {
          lines.add('${(item.value / maxVal * 100).toStringAsFixed(1)}%');
        }

        double textY = cy - (lines.length * 14) / 2;
        for (final line in lines) {
          final tp = textPainterCache.get(
            line,
            theme.typography.axisLabelStyle.copyWith(
              color: Colors.white,
              fontSize: line == item.name ? 11 : 10,
              fontWeight: line == item.name ? FontWeight.w600 : FontWeight.w400,
            ),
            maxWidth: labelMaxWidth,
            align: TextAlign.center,
          );
          tp.paint(canvas, Offset(cx - tp.width / 2, textY));
          textY += 14;
        }
      }

      // Conversion rate connector
      if (config.showConversionRate && i < n - 1) {
        final nextItem = config.items[isPyramid ? n - 2 - i : i + 1];
        final rate = (nextItem.value / item.value * 100).toStringAsFixed(0);
        final tp = textPainterCache.get(
          '↓ $rate%',
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 9,
          ),
        );
        tp.paint(
          canvas,
          Offset(topX2 + 6, y + stageH + gap / 2 - tp.height / 2),
        );
      }
    }
  }
}
