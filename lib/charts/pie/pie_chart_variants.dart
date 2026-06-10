/// Pie chart variants — 11 specialized pie/donut/rose chart types.
///
/// Charts in this file:
///   • [DonutChartConfig]         — standard donut with centre label
///   • [HalfDonutChartConfig]     — 180° semicircle donut
///   • [PaddedPieChartConfig]     — pie with configurable pad angle between slices
///   • [NightingaleChartConfig]   — rose / nightingale (polar bar arcs)
///   • [NestedPieChartConfig]     — concentric ring charts (multi-level)
///   • [PartitionPieChartConfig]  — one slice subdivided into sub-slices
///   • [CalendarPieChartConfig]   — mini-pie rendered per calendar day cell
///   • [PieLabelLineConfig]       — pie with configurable label-line adjust
///   • [PieSpecialLabelConfig]    — pie with custom per-slice label styling
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/base_config.dart';
import '../../core/chart_type.dart';
import '../../core/chart_theme.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_cache.dart';
import 'pie_json_helpers.dart';

// ─── shared helpers ────────────────────────────────────────────────────────

/// Resolve a color string from a [PieSlice], falling back to theme palette.
Color _sliceColor(PieSlice s, int idx, ChartTheme theme) {
  if (s.color != null) {
    try {
      return colorCache.resolve(s.color!);
    } catch (_) {}
  }
  return theme.palette.colorObjectAt(idx);
}

/// Basic pie/donut slice data.
class PieSlice {
  final String name;
  final double value;
  final String? color;
  const PieSlice({required this.name, required this.value, this.color});
  factory PieSlice.fromJson(Map<String, dynamic> j) => PieSlice(
    name: PieJson.string(j['name']) ?? '',
    value: PieJson.nonNegativeDouble(j['value'], 0),
    color: PieJson.string(j['color']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    if (color != null) 'color': color,
  };
}

Map<String, dynamic> _pieConfigJson(BaseChartConfig config) => {
  if (config.title != null) 'title': config.title!.toJson(),
  if (config.tooltip != null) 'tooltip': config.tooltip!.toJson(),
  if (config.legend != null) 'legend': config.legend!.toJson(),
  if (config.toolbox != null) 'toolbox': config.toolbox!.toJson(),
  if (config.grid != null) 'grid': config.grid!.toJson(),
};

Map<String, dynamic> _sliceSeries(List<PieSlice> slices, {String? name}) {
  final json = <String, dynamic>{
    'data': slices.map((slice) => slice.toJson()).toList(),
  };
  if (name != null) json['name'] = name;
  return json;
}

List<PieSlice> _pieSlices(
  Map<String, dynamic> json, {
  List<String> directKeys = const ['slices'],
}) {
  return PieJson.sliceMaps(
    json,
    directKeys: directKeys,
  ).map(PieSlice.fromJson).toList(growable: false);
}

List<PieSlice> _pieSliceMaps(List<Map<String, dynamic>> maps) {
  return maps.map(PieSlice.fromJson).toList(growable: false);
}

int _clampedInt(Object? raw, int fallback, int min, int max) {
  return PieJson.intOr(raw, fallback).clamp(min, max).toInt();
}

int _month(Object? raw) => _clampedInt(raw, 1, 1, 12);

int _partitionIndex(Object? raw, int sliceCount) {
  if (sliceCount <= 0) return 0;
  return _clampedInt(raw, 0, 0, sliceCount - 1);
}

List<PieSlice> _partitionSeriesSlices(
  Map<String, dynamic> json, {
  required bool subSlices,
}) {
  final series = PieJson.seriesMaps(json['series']);
  if (series.isEmpty) return const <PieSlice>[];
  final index = subSlices ? 1 : 0;
  if (index >= series.length) return const <PieSlice>[];
  return _pieSliceMaps(PieJson.mapList(series[index]['data']));
}

/// Draw a wedge arc with optional rounded tips.
Path _wedgePath({
  required Offset center,
  required double innerR,
  required double outerR,
  required double startAngle,
  required double sweepAngle,
  double cornerR = 0,
}) {
  if (sweepAngle.abs() < 0.001) return Path();
  final midStart = startAngle;
  final midEnd = startAngle + sweepAngle;
  final path = Path();
  if (cornerR > 0 && outerR - innerR > cornerR * 2) {
    path.addArc(
      Rect.fromCircle(center: center, radius: outerR),
      midStart,
      sweepAngle,
    );
    path.arcTo(
      Rect.fromCircle(center: center, radius: innerR),
      midEnd,
      -sweepAngle,
      false,
    );
    path.close();
  } else {
    path
      ..moveTo(
        center.dx + innerR * math.cos(midStart),
        center.dy + innerR * math.sin(midStart),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: outerR),
        midStart,
        sweepAngle,
        false,
      )
      ..lineTo(
        center.dx + innerR * math.cos(midEnd),
        center.dy + innerR * math.sin(midEnd),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerR),
        midEnd,
        -sweepAngle,
        false,
      )
      ..close();
  }
  return path;
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED PIE STATE MIXIN
// ═══════════════════════════════════════════════════════════════════════════

mixin _PieAnimMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  late AnimationController pieCtrl;
  late Animation<double> pieAnim;
  int hovSlice = -1;
  Offset hovPos = Offset.zero;

  void initPieAnim({Duration duration = const Duration(milliseconds: 800)}) {
    pieCtrl = AnimationController(vsync: this, duration: duration);
    pieAnim = CurvedAnimation(parent: pieCtrl, curve: Curves.easeOutBack);
    pieCtrl.addListener(() => setState(() {}));
    pieCtrl.forward();
  }

  void disposePieAnim() => pieCtrl.dispose();
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. DONUT CHART
// ═══════════════════════════════════════════════════════════════════════════
class DonutChartConfig extends BaseChartConfig {
  final List<PieSlice> slices;
  final double innerRadiusRatio;
  final String? centreLabel, centreSubLabel;
  final bool showLabels, showPercentage;
  final double padAngle;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  DonutChartConfig({
    required this.slices,
    this.theme = ChartTheme.light,
    this.innerRadiusRatio = 0.52,
    this.centreLabel,
    this.centreSubLabel,
    this.showLabels = true,
    this.showPercentage = true,
    this.padAngle = 0.02,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.donut, series: const []);

  @override
  Widget buildChart() => _DonutWidget(config: this);

  factory DonutChartConfig.fromJson(Map<String, dynamic> j) {
    return DonutChartConfig(
      slices: _pieSlices(j),
      innerRadiusRatio: PieJson.ratio(j['innerRadiusRatio'], 0.52),
      centreLabel: PieJson.string(j['centreLabel']),
      centreSubLabel: PieJson.string(j['centreSubLabel']),
      showLabels: PieJson.boolOr(j['showLabels'], true),
      showPercentage: PieJson.boolOr(j['showPercentage'], true),
      padAngle: PieJson.angleGap(j['padAngle'], 0.02),
      title: PieJson.title(j['title']),
      tooltip: PieJson.tooltip(j['tooltip']),
      legend: PieJson.legend(j['legend']),
      toolbox: PieJson.toolbox(j['toolbox']),
      grid: PieJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'type': 'donut',
    ..._pieConfigJson(this),
    'series': [_sliceSeries(slices)],
    'innerRadiusRatio': innerRadiusRatio,
    if (centreLabel != null) 'centreLabel': centreLabel,
    if (centreSubLabel != null) 'centreSubLabel': centreSubLabel,
    'showLabels': showLabels,
    'showPercentage': showPercentage,
    'padAngle': padAngle,
  };
}

class _DonutWidget extends StatefulWidget {
  final DonutChartConfig config;
  const _DonutWidget({required this.config});
  @override
  State<_DonutWidget> createState() => _DonutState();
}

class _DonutState extends State<_DonutWidget>
    with SingleTickerProviderStateMixin, _PieAnimMixin {
  DonutChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    initPieAnim();
  }

  @override
  void dispose() {
    disposePieAnim();
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
                      // Basic hit-test: find which slice the pointer is over
                      final cx = sz.width / 2, cy = sz.height / 2;
                      final r = math.min(cx, cy) * 0.82;
                      final innerR = r * cfg.innerRadiusRatio;
                      final dx = e.localPosition.dx - cx,
                          dy = e.localPosition.dy - cy;
                      final dist = math.sqrt(dx * dx + dy * dy);
                      if (dist < innerR || dist > r) {
                        setState(() => hovSlice = -1);
                        return;
                      }
                      double angle = math.atan2(dy, dx);
                      if (angle < -math.pi / 2) angle += 2 * math.pi;
                      final total = cfg.slices.fold(0.0, (a, s) => a + s.value);
                      double start = -math.pi / 2;
                      for (int i = 0; i < cfg.slices.length; i++) {
                        final sweep = cfg.slices[i].value / total * 2 * math.pi;
                        if (angle >= start && angle < start + sweep) {
                          setState(() {
                            hovSlice = i;
                            hovPos = e.localPosition;
                          });
                          return;
                        }
                        start += sweep;
                      }
                      setState(() => hovSlice = -1);
                    },
                    onExit: (_) => setState(() => hovSlice = -1),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _DonutPainter(
                          cfg: cfg,
                          progress: pieAnim.value,
                          hovSlice: hovSlice,
                        ),
                      ),
                    ),
                  ),
                  if (hovSlice >= 0) _tooltip(sz),
                ],
              );
            },
          ),
        ),
        _buildLegend(),
      ],
    );
  }

  Widget _tooltip(Size sz) {
    final s = cfg.slices[hovSlice];
    final total = cfg.slices.fold(0.0, (a, sl) => a + sl.value);
    final pct = (s.value / total * 100).toStringAsFixed(1);
    double x = (hovPos.dx + 12).clamp(0.0, sz.width - 170.0);
    double y = (hovPos.dy - 56).clamp(0.0, sz.height - 70.0);
    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: cfg.theme.tooltipBackgroundColor,
            borderRadius: BorderRadius.circular(7),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
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
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${s.value.toStringAsFixed(1)}  ($pct%)'),
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
      spacing: 10,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: cfg.slices.asMap().entries.map((e) {
        final color = _sliceColor(e.value, e.key, cfg.theme);
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

class _DonutPainter extends ChartPainterBase {
  final DonutChartConfig cfg;
  final double progress;
  final int hovSlice;
  _DonutPainter({
    required this.cfg,
    required this.progress,
    required this.hovSlice,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _DonutPainter o) =>
      o.progress != progress || o.hovSlice != hovSlice;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.slices.isEmpty) return;
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) * 0.82;
    final innerR = r * cfg.innerRadiusRatio;
    final total = cfg.slices.fold(0.0, (a, s) => a + s.value);
    if (total == 0) return;

    double start = -math.pi / 2;
    for (int i = 0; i < cfg.slices.length; i++) {
      final s = cfg.slices[i];
      final sweep = s.value / total * 2 * math.pi * progress;
      final isHov = i == hovSlice;
      final color = _sliceColor(s, i, theme);
      final explode = isHov ? 6.0 : 0.0;
      final midAngle = start + sweep / 2;
      final oc = Offset(
        cx + explode * math.cos(midAngle),
        cy + explode * math.sin(midAngle),
      );

      final path = _wedgePath(
        center: oc,
        innerR: innerR,
        outerR: r,
        startAngle: start + cfg.padAngle / 2,
        sweepAngle: sweep - cfg.padAngle,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = isHov ? Color.lerp(color, Colors.white, 0.18)! : color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..isAntiAlias = true,
      );

      // Label
      if (cfg.showLabels && sweep > 0.2) {
        final labelR = (innerR + r) / 2;
        final lx = oc.dx + labelR * math.cos(midAngle);
        final ly = oc.dy + labelR * math.sin(midAngle);
        final pctStr = cfg.showPercentage
            ? '${(s.value / total * 100).toStringAsFixed(0)}%'
            : s.name;
        final tp = textPainterCache.get(
          pctStr,
          (theme.typography.dataLabelStyle ?? theme.typography.axisLabelStyle)
              .copyWith(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
        );
        tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      }
      start += sweep;
    }

    // Centre label
    if (cfg.centreLabel != null) {
      final tp = textPainterCache.get(
        cfg.centreLabel!,
        theme.typography.titleStyle.copyWith(
          color: theme.titleColor,
          fontSize: 16,
        ),
      );
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 - 8));
    }
    if (cfg.centreSubLabel != null) {
      final tp = textPainterCache.get(
        cfg.centreSubLabel!,
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 10,
        ),
      );
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + 8));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. HALF DONUT  (180° semicircle)
// ═══════════════════════════════════════════════════════════════════════════
class HalfDonutChartConfig extends BaseChartConfig {
  final List<PieSlice> slices;
  final double innerRadiusRatio;
  final String? centreLabel;
  final double padAngle;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  HalfDonutChartConfig({
    required this.slices,
    this.theme = ChartTheme.light,
    this.innerRadiusRatio = 0.55,
    this.centreLabel,
    this.padAngle = 0.03,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.halfDonut, series: const []);

  @override
  Widget buildChart() => _HalfDonutWidget(config: this);

  factory HalfDonutChartConfig.fromJson(Map<String, dynamic> j) {
    return HalfDonutChartConfig(
      slices: _pieSlices(j),
      innerRadiusRatio: PieJson.ratio(j['innerRadiusRatio'], 0.55),
      centreLabel: PieJson.string(j['centreLabel']),
      padAngle: PieJson.angleGap(j['padAngle'], 0.03),
      title: PieJson.title(j['title']),
      tooltip: PieJson.tooltip(j['tooltip']),
      legend: PieJson.legend(j['legend']),
      toolbox: PieJson.toolbox(j['toolbox']),
      grid: PieJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'type': 'halfDonut',
    ..._pieConfigJson(this),
    'series': [_sliceSeries(slices)],
    'innerRadiusRatio': innerRadiusRatio,
    if (centreLabel != null) 'centreLabel': centreLabel,
    'padAngle': padAngle,
  };
}

class _HalfDonutWidget extends StatefulWidget {
  final HalfDonutChartConfig config;
  const _HalfDonutWidget({required this.config});
  @override
  State<_HalfDonutWidget> createState() => _HalfDonutState();
}

class _HalfDonutState extends State<_HalfDonutWidget>
    with SingleTickerProviderStateMixin, _PieAnimMixin {
  HalfDonutChartConfig get cfg => widget.config;
  @override
  void initState() {
    super.initState();
    initPieAnim();
  }

  @override
  void dispose() {
    disposePieAnim();
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
            painter: _HalfDonutPainter(
              cfg: cfg,
              progress: pieAnim.value,
              hovSlice: hovSlice,
            ),
          ),
        ),
      ),
      _buildLegend(),
    ],
  );

  Widget _buildLegend() => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Wrap(
      spacing: 10,
      alignment: WrapAlignment.center,
      children: cfg.slices.asMap().entries.map((e) {
        final color = _sliceColor(e.value, e.key, cfg.theme);
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

class _HalfDonutPainter extends ChartPainterBase {
  final HalfDonutChartConfig cfg;
  final double progress;
  final int hovSlice;
  _HalfDonutPainter({
    required this.cfg,
    required this.progress,
    required this.hovSlice,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _HalfDonutPainter o) =>
      o.progress != progress || o.hovSlice != hovSlice;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.slices.isEmpty) return;
    final cx = size.width / 2;
    // Position the centre near the bottom 2/3 of the canvas for half-circle
    final cy = size.height * 0.72;
    final r = math.min(cx * 0.9, cy * 0.88);
    final innerR = r * cfg.innerRadiusRatio;
    final total = cfg.slices.fold(0.0, (a, s) => a + s.value);
    if (total == 0) return;

    // Half donut: spans from π (left) to 0 (right), i.e. the top half
    double start = math.pi; // start at 9 o'clock (left)
    for (int i = 0; i < cfg.slices.length; i++) {
      final s = cfg.slices[i];
      final sweep =
          -(s.value /
              total *
              math.pi *
              progress); // negative = counter-clockwise
      final isHov = i == hovSlice;
      final color = _sliceColor(s, i, theme);
      final midAngle = start + sweep / 2;
      final explode = isHov ? 5.0 : 0.0;
      final oc = Offset(
        cx + explode * math.cos(midAngle),
        cy + explode * math.sin(midAngle),
      );

      final path = _wedgePath(
        center: oc,
        innerR: innerR,
        outerR: r,
        startAngle: start - cfg.padAngle / 2,
        sweepAngle: sweep + cfg.padAngle,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = isHov ? Color.lerp(color, Colors.white, 0.18)! : color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..isAntiAlias = true,
      );

      // Label outside
      if (sweep.abs() > 0.15) {
        final labelR = r + 16;
        final lx = oc.dx + labelR * math.cos(midAngle);
        final ly = oc.dy + labelR * math.sin(midAngle);
        final pct = '${(s.value / total * 100).toStringAsFixed(0)}%';
        final tp = textPainterCache.get(
          pct,
          theme.typography.axisLabelStyle.copyWith(
            color: color,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        );
        tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      }
      start += sweep;
    }

    // Centre label at the flat edge
    if (cfg.centreLabel != null) {
      final tp = textPainterCache.get(
        cfg.centreLabel!,
        theme.typography.titleStyle.copyWith(
          color: theme.titleColor,
          fontSize: 15,
        ),
      );
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + innerR / 2 - tp.height));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. PIE WITH PAD ANGLE  (configurable gap between slices)
// ═══════════════════════════════════════════════════════════════════════════
class PaddedPieChartConfig extends BaseChartConfig {
  final List<PieSlice> slices;
  final double padAngle; // radians between slices (try 0.04–0.12)
  final bool showLabels, showPercentage;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  PaddedPieChartConfig({
    required this.slices,
    this.theme = ChartTheme.light,
    this.padAngle = 0.06,
    this.showLabels = true,
    this.showPercentage = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.paddedPie, series: const []);

  @override
  Widget buildChart() => _PaddedPieWidget(config: this);

  factory PaddedPieChartConfig.fromJson(Map<String, dynamic> j) {
    return PaddedPieChartConfig(
      slices: _pieSlices(j),
      padAngle: PieJson.angleGap(j['padAngle'], 0.06),
      showLabels: PieJson.boolOr(j['showLabels'], true),
      showPercentage: PieJson.boolOr(j['showPercentage'], true),
      title: PieJson.title(j['title']),
      tooltip: PieJson.tooltip(j['tooltip']),
      legend: PieJson.legend(j['legend']),
      toolbox: PieJson.toolbox(j['toolbox']),
      grid: PieJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'type': 'paddedPie',
    ..._pieConfigJson(this),
    'series': [_sliceSeries(slices)],
    'padAngle': padAngle,
    'showLabels': showLabels,
    'showPercentage': showPercentage,
  };
}

class _PaddedPieWidget extends StatefulWidget {
  final PaddedPieChartConfig config;
  const _PaddedPieWidget({required this.config});
  @override
  State<_PaddedPieWidget> createState() => _PaddedPieState();
}

class _PaddedPieState extends State<_PaddedPieWidget>
    with SingleTickerProviderStateMixin, _PieAnimMixin {
  PaddedPieChartConfig get cfg => widget.config;
  @override
  void initState() {
    super.initState();
    initPieAnim();
  }

  @override
  void dispose() {
    disposePieAnim();
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
            painter: _PaddedPiePainter(cfg: cfg, progress: pieAnim.value),
          ),
        ),
      ),
    ],
  );
}

class _PaddedPiePainter extends ChartPainterBase {
  final PaddedPieChartConfig cfg;
  final double progress;
  _PaddedPiePainter({required this.cfg, required this.progress})
    : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _PaddedPiePainter o) =>
      o.progress != progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.slices.isEmpty) return;
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) * 0.78;
    final total = cfg.slices.fold(0.0, (a, s) => a + s.value);
    if (total == 0) return;

    double start = -math.pi / 2;
    for (int i = 0; i < cfg.slices.length; i++) {
      final s = cfg.slices[i];
      final sweep = s.value / total * 2 * math.pi * progress;
      final color = _sliceColor(s, i, theme);
      final midAngle = start + sweep / 2;

      final path = _wedgePath(
        center: Offset(cx, cy),
        innerR: 0,
        outerR: r,
        startAngle: start + cfg.padAngle / 2,
        sweepAngle: sweep - cfg.padAngle,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      if (cfg.showLabels && sweep > 0.25) {
        final labelR = r * 0.65;
        final lx = cx + labelR * math.cos(midAngle);
        final ly = cy + labelR * math.sin(midAngle);
        final pct = cfg.showPercentage
            ? '${(s.value / total * 100).toStringAsFixed(0)}%'
            : s.name;
        final tp = textPainterCache.get(
          pct,
          (theme.typography.dataLabelStyle ?? theme.typography.axisLabelStyle)
              .copyWith(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
        );
        tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      }
      start += sweep;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. NIGHTINGALE / ROSE CHART
// ═══════════════════════════════════════════════════════════════════════════
/// Each slice has equal angle; radius encodes value (like a polar bar chart).
/// Two modes: 'radius' (proportional radius) and 'area' (proportional area).
class NightingaleChartConfig extends BaseChartConfig {
  final List<PieSlice> slices;
  final String mode; // 'radius' | 'area'
  final double innerRadiusRatio;
  final double padAngle;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  NightingaleChartConfig({
    required this.slices,
    this.theme = ChartTheme.light,
    this.mode = 'radius',
    this.innerRadiusRatio = 0.15,
    this.padAngle = 0.03,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.nightingale, series: const []);

  @override
  Widget buildChart() => _NightingaleWidget(config: this);

  factory NightingaleChartConfig.fromJson(Map<String, dynamic> j) {
    return NightingaleChartConfig(
      slices: _pieSlices(j),
      mode: PieJson.string(j['mode']) ?? 'radius',
      innerRadiusRatio: PieJson.ratio(j['innerRadiusRatio'], 0.15),
      padAngle: PieJson.angleGap(j['padAngle'], 0.03),
      title: PieJson.title(j['title']),
      tooltip: PieJson.tooltip(j['tooltip']),
      legend: PieJson.legend(j['legend']),
      toolbox: PieJson.toolbox(j['toolbox']),
      grid: PieJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'type': 'nightingale',
    ..._pieConfigJson(this),
    'series': [_sliceSeries(slices)],
    'mode': mode,
    'innerRadiusRatio': innerRadiusRatio,
    'padAngle': padAngle,
  };
}

class _NightingaleWidget extends StatefulWidget {
  final NightingaleChartConfig config;
  const _NightingaleWidget({required this.config});
  @override
  State<_NightingaleWidget> createState() => _NightState();
}

class _NightState extends State<_NightingaleWidget>
    with SingleTickerProviderStateMixin, _PieAnimMixin {
  NightingaleChartConfig get cfg => widget.config;
  @override
  void initState() {
    super.initState();
    initPieAnim();
  }

  @override
  void dispose() {
    disposePieAnim();
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
            painter: _NightPainter(
              cfg: cfg,
              progress: pieAnim.value,
              hovSlice: hovSlice,
            ),
          ),
        ),
      ),
      _buildLegend(),
    ],
  );

  Widget _buildLegend() => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Wrap(
      spacing: 10,
      alignment: WrapAlignment.center,
      children: cfg.slices.asMap().entries.map((e) {
        final color = _sliceColor(e.value, e.key, cfg.theme);
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

class _NightPainter extends ChartPainterBase {
  final NightingaleChartConfig cfg;
  final double progress;
  final int hovSlice;
  _NightPainter({
    required this.cfg,
    required this.progress,
    required this.hovSlice,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _NightPainter o) =>
      o.progress != progress || o.hovSlice != hovSlice;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.slices.isEmpty) return;
    final cx = size.width / 2, cy = size.height / 2;
    final maxR = math.min(cx, cy) * 0.82;
    final innerR = maxR * cfg.innerRadiusRatio;
    final n = cfg.slices.length;
    final sliceAngle = 2 * math.pi / n;
    final maxVal = cfg.slices.map((s) => s.value).reduce(math.max);
    if (maxVal == 0) return;

    for (int i = 0; i < n; i++) {
      final s = cfg.slices[i];
      final isHov = i == hovSlice;
      final color = _sliceColor(s, i, theme);
      final normVal = s.value / maxVal;
      final outerR = cfg.mode == 'area'
          ? innerR + (maxR - innerR) * math.sqrt(normVal) * progress
          : innerR + (maxR - innerR) * normVal * progress;
      final startAngle = -math.pi / 2 + i * sliceAngle + cfg.padAngle / 2;
      final sweep = sliceAngle - cfg.padAngle;

      final path = _wedgePath(
        center: Offset(cx, cy),
        innerR: innerR,
        outerR: outerR,
        startAngle: startAngle,
        sweepAngle: sweep,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = isHov ? Color.lerp(color, Colors.white, 0.2)! : color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      // Name label at outer tip
      final midAngle = startAngle + sweep / 2;
      final lr = outerR + 12;
      final lx = cx + lr * math.cos(midAngle);
      final ly = cy + lr * math.sin(midAngle);
      final tp = textPainterCache.get(
        s.name,
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 8.5,
        ),
      );
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. NESTED PIE  (concentric rings)
// ═══════════════════════════════════════════════════════════════════════════
class PieRing {
  final String name;
  final List<PieSlice> slices;
  const PieRing({required this.name, required this.slices});
  factory PieRing.fromJson(Map<String, dynamic> j) => PieRing(
    name: PieJson.string(j['name']) ?? '',
    slices: _pieSlices(j, directKeys: const ['slices', 'data']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'slices': slices.map((slice) => slice.toJson()).toList(),
  };
}

class NestedPieChartConfig extends BaseChartConfig {
  final List<PieRing> rings;
  final double ringGap;
  final double padAngle;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  NestedPieChartConfig({
    required this.rings,
    this.theme = ChartTheme.light,
    this.ringGap = 8.0,
    this.padAngle = 0.02,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.nestedPie, series: const []);

  @override
  Widget buildChart() => _NestedPieWidget(config: this);

  factory NestedPieChartConfig.fromJson(Map<String, dynamic> j) {
    final rings = PieJson.mapList(
      j['rings'] ?? j['series'],
    ).map(PieRing.fromJson).toList(growable: false);
    return NestedPieChartConfig(
      rings: rings,
      ringGap: PieJson.nonNegativeDouble(j['ringGap'], 8.0),
      padAngle: PieJson.angleGap(j['padAngle'], 0.02),
      title: PieJson.title(j['title']),
      tooltip: PieJson.tooltip(j['tooltip']),
      legend: PieJson.legend(j['legend']),
      toolbox: PieJson.toolbox(j['toolbox']),
      grid: PieJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'type': 'nestedPie',
    ..._pieConfigJson(this),
    'rings': rings.map((ring) => ring.toJson()).toList(),
    'series': [
      for (final ring in rings) _sliceSeries(ring.slices, name: ring.name),
    ],
    'ringGap': ringGap,
    'padAngle': padAngle,
  };
}

class _NestedPieWidget extends StatefulWidget {
  final NestedPieChartConfig config;
  const _NestedPieWidget({required this.config});
  @override
  State<_NestedPieWidget> createState() => _NestedPieState();
}

class _NestedPieState extends State<_NestedPieWidget>
    with SingleTickerProviderStateMixin, _PieAnimMixin {
  NestedPieChartConfig get cfg => widget.config;
  @override
  void initState() {
    super.initState();
    initPieAnim();
  }

  @override
  void dispose() {
    disposePieAnim();
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
            painter: _NestedPiePainter(cfg: cfg, progress: pieAnim.value),
          ),
        ),
      ),
    ],
  );
}

class _NestedPiePainter extends ChartPainterBase {
  final NestedPieChartConfig cfg;
  final double progress;
  _NestedPiePainter({required this.cfg, required this.progress})
    : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _NestedPiePainter o) =>
      o.progress != progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.rings.isEmpty) return;
    final cx = size.width / 2, cy = size.height / 2;
    final maxR = math.min(cx, cy) * 0.9;
    final n = cfg.rings.length;
    final ringW = (maxR - cfg.ringGap * n) / n;
    if (ringW <= 0) return;

    for (int ri = 0; ri < n; ri++) {
      final ring = cfg.rings[ri];
      final innerR = ri * (ringW + cfg.ringGap) + 4;
      final outerR = innerR + ringW;
      final total = ring.slices.fold(0.0, (a, s) => a + s.value);
      if (total == 0) continue;

      // Each ring uses a shifted palette so rings look distinct
      double start = -math.pi / 2;
      for (int si = 0; si < ring.slices.length; si++) {
        final s = ring.slices[si];
        final sweep = s.value / total * 2 * math.pi * progress;
        Color color;
        if (s.color != null) {
          try {
            color = colorCache.resolve(s.color!);
          } catch (_) {
            color = theme.palette.colorObjectAt(ri * 3 + si);
          }
        } else {
          color = theme.palette.colorObjectAt(ri * 3 + si);
        }
        final path = _wedgePath(
          center: Offset(cx, cy),
          innerR: innerR,
          outerR: outerR,
          startAngle: start + cfg.padAngle / 2,
          sweepAngle: sweep - cfg.padAngle,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = theme.backgroundColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..isAntiAlias = true,
        );
        start += sweep;
      }

      // Ring label
      final tp = textPainterCache.get(
        ring.name,
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
      );
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - outerR - tp.height - 2));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. PARTITION PIE  (one slice subdivided)
// ═══════════════════════════════════════════════════════════════════════════
class PartitionPieChartConfig extends BaseChartConfig {
  final List<PieSlice> mainSlices;
  final int partitionIndex;
  final List<PieSlice> subSlices;
  final double padAngle;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  PartitionPieChartConfig({
    required this.mainSlices,
    required this.partitionIndex,
    required this.subSlices,
    this.theme = ChartTheme.light,
    this.padAngle = 0.02,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.partitionPie, series: const []);

  @override
  Widget buildChart() => _PartitionPieWidget(config: this);

  factory PartitionPieChartConfig.fromJson(Map<String, dynamic> j) {
    final directMain = _pieSliceMaps(PieJson.mapList(j['mainSlices']));
    final directSub = _pieSliceMaps(PieJson.mapList(j['subSlices']));
    final main = directMain.isNotEmpty
        ? directMain
        : _partitionSeriesSlices(j, subSlices: false);
    final sub = directSub.isNotEmpty
        ? directSub
        : _partitionSeriesSlices(j, subSlices: true);
    return PartitionPieChartConfig(
      mainSlices: main,
      partitionIndex: _partitionIndex(j['partitionIndex'], main.length),
      subSlices: sub,
      padAngle: PieJson.angleGap(j['padAngle'], 0.02),
      title: PieJson.title(j['title']),
      tooltip: PieJson.tooltip(j['tooltip']),
      legend: PieJson.legend(j['legend']),
      toolbox: PieJson.toolbox(j['toolbox']),
      grid: PieJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'type': 'partitionPie',
    ..._pieConfigJson(this),
    'mainSlices': mainSlices.map((slice) => slice.toJson()).toList(),
    'partitionIndex': partitionIndex,
    'subSlices': subSlices.map((slice) => slice.toJson()).toList(),
    'series': [
      _sliceSeries(mainSlices, name: 'main'),
      _sliceSeries(subSlices, name: 'partition'),
    ],
    'padAngle': padAngle,
  };
}

class _PartitionPieWidget extends StatefulWidget {
  final PartitionPieChartConfig config;
  const _PartitionPieWidget({required this.config});
  @override
  State<_PartitionPieWidget> createState() => _PartPieState();
}

class _PartPieState extends State<_PartitionPieWidget>
    with SingleTickerProviderStateMixin, _PieAnimMixin {
  PartitionPieChartConfig get cfg => widget.config;
  @override
  void initState() {
    super.initState();
    initPieAnim();
  }

  @override
  void dispose() {
    disposePieAnim();
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
            painter: _PartPiePainter(cfg: cfg, progress: pieAnim.value),
          ),
        ),
      ),
    ],
  );
}

class _PartPiePainter extends ChartPainterBase {
  final PartitionPieChartConfig cfg;
  final double progress;
  _PartPiePainter({required this.cfg, required this.progress})
    : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _PartPiePainter o) =>
      o.progress != progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.mainSlices.isEmpty) return;
    final cx = size.width / 2, cy = size.height / 2;
    final outerR = math.min(cx, cy) * 0.80;
    final innerR = 0.0;
    final total = cfg.mainSlices.fold(0.0, (a, s) => a + s.value);
    if (total == 0) return;

    double start = -math.pi / 2;
    for (int i = 0; i < cfg.mainSlices.length; i++) {
      final s = cfg.mainSlices[i];
      final sweep = s.value / total * 2 * math.pi * progress;
      final color = _sliceColor(s, i, theme);

      if (i == cfg.partitionIndex && cfg.subSlices.isNotEmpty) {
        // Draw sub-slices within this slice's angular range
        final subTotal = cfg.subSlices.fold(0.0, (a, ss) => a + ss.value);
        if (subTotal > 0) {
          double subStart = start + cfg.padAngle / 2;
          for (int si = 0; si < cfg.subSlices.length; si++) {
            final ss = cfg.subSlices[si];
            final subSweep = ss.value / subTotal * (sweep - cfg.padAngle);
            Color subColor;
            if (ss.color != null) {
              try {
                subColor = colorCache.resolve(ss.color!);
              } catch (_) {
                subColor = Color.lerp(color, Colors.white, 0.3 + si * 0.15)!;
              }
            } else {
              subColor = Color.lerp(color, Colors.white, 0.3 + si * 0.15)!;
            }
            final path = _wedgePath(
              center: Offset(cx, cy),
              innerR: innerR,
              outerR: outerR,
              startAngle: subStart + cfg.padAngle * 0.3,
              sweepAngle: subSweep - cfg.padAngle * 0.3,
            );
            canvas.drawPath(
              path,
              Paint()
                ..color = subColor
                ..style = PaintingStyle.fill
                ..isAntiAlias = true,
            );
            // Sub label
            if (subSweep > 0.15) {
              final mid = subStart + subSweep / 2;
              final lr = outerR * 0.65;
              final tp = textPainterCache.get(
                ss.name,
                (theme.typography.dataLabelStyle ??
                        theme.typography.axisLabelStyle)
                    .copyWith(color: Colors.white, fontSize: 8),
              );
              tp.paint(
                canvas,
                Offset(
                  cx + lr * math.cos(mid) - tp.width / 2,
                  cy + lr * math.sin(mid) - tp.height / 2,
                ),
              );
            }
            subStart += subSweep;
          }
        }
      } else {
        final path = _wedgePath(
          center: Offset(cx, cy),
          innerR: innerR,
          outerR: outerR,
          startAngle: start + cfg.padAngle / 2,
          sweepAngle: sweep - cfg.padAngle,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        // Label
        if (sweep > 0.2) {
          final mid = start + sweep / 2;
          final tp = textPainterCache.get(
            s.name,
            (theme.typography.dataLabelStyle ?? theme.typography.axisLabelStyle)
                .copyWith(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
          );
          tp.paint(
            canvas,
            Offset(
              cx + outerR * 0.6 * math.cos(mid) - tp.width / 2,
              cy + outerR * 0.6 * math.sin(mid) - tp.height / 2,
            ),
          );
        }
      }
      start += sweep;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 7. CALENDAR PIE — mini pies rendered inside a month-grid calendar
// ═══════════════════════════════════════════════════════════════════════════
class CalendarPieDay {
  final int day;
  final List<PieSlice> slices;
  const CalendarPieDay({required this.day, required this.slices});
  factory CalendarPieDay.fromJson(Map<String, dynamic> j) => CalendarPieDay(
    day: _clampedInt(j['day'], 1, 1, 31),
    slices: _pieSlices(j, directKeys: const ['slices', 'data']),
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'slices': slices.map((slice) => slice.toJson()).toList(),
  };
}

class CalendarPieChartConfig extends BaseChartConfig {
  final List<CalendarPieDay> days;
  final int year, month;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  CalendarPieChartConfig({
    required this.days,
    this.year = 2024,
    this.month = 1,
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.calendarPie, series: const []);

  @override
  Widget buildChart() => _CalendarPieWidget(config: this);

  factory CalendarPieChartConfig.fromJson(Map<String, dynamic> j) {
    final dayMaps = PieJson.mapList(j['days']);
    final days =
        (dayMaps.isNotEmpty ? dayMaps : PieJson.seriesSliceMaps(j['series']))
            .map(CalendarPieDay.fromJson)
            .toList(growable: false);
    return CalendarPieChartConfig(
      days: days,
      year: PieJson.intOr(j['year'], 2024),
      month: _month(j['month']),
      title: PieJson.title(j['title']),
      tooltip: PieJson.tooltip(j['tooltip']),
      legend: PieJson.legend(j['legend']),
      toolbox: PieJson.toolbox(j['toolbox']),
      grid: PieJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'type': 'calendarPie',
    ..._pieConfigJson(this),
    'year': year,
    'month': month,
    'days': days.map((day) => day.toJson()).toList(),
    'series': [
      {'data': days.map((day) => day.toJson()).toList()},
    ],
  };
}

class _CalendarPieWidget extends StatefulWidget {
  final CalendarPieChartConfig config;
  const _CalendarPieWidget({required this.config});
  @override
  State<_CalendarPieWidget> createState() => _CalPieState();
}

class _CalPieState extends State<_CalendarPieWidget>
    with SingleTickerProviderStateMixin, _PieAnimMixin {
  CalendarPieChartConfig get cfg => widget.config;
  @override
  void initState() {
    super.initState();
    initPieAnim();
  }

  @override
  void dispose() {
    disposePieAnim();
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
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _CalPiePainter(cfg: cfg, progress: pieAnim.value),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalPiePainter extends ChartPainterBase {
  final CalendarPieChartConfig cfg;
  final double progress;
  _CalPiePainter({required this.cfg, required this.progress})
    : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _CalPiePainter o) => o.progress != progress;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 8.0, padT = 32.0, padR = 8.0, padB = 8.0;
    final cellW = (size.width - padL - padR) / 7;
    final rows = 6;
    final cellH = (size.height - padT - padB) / rows;
    final pieR = math.min(cellW, cellH) * 0.38;

    // Day-of-week headers
    const dow = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    for (int d = 0; d < 7; d++) {
      final tp = textPainterCache.get(
        dow[d],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
      );
      tp.paint(canvas, Offset(padL + d * cellW + cellW / 2 - tp.width / 2, 10));
    }

    // First day of month (0=Sun)
    final firstDay = DateTime(cfg.year, cfg.month, 1).weekday % 7;
    final daysInMonth = DateTime(cfg.year, cfg.month + 1, 0).day;
    final dayData = {for (final d in cfg.days) d.day: d};

    for (int day = 1; day <= daysInMonth; day++) {
      final slot = day - 1 + firstDay;
      final col = slot % 7;
      final row = slot ~/ 7;
      final cx = padL + col * cellW + cellW / 2;
      final cy = padT + row * cellH + cellH / 2;

      // Cell background
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            padL + col * cellW + 1,
            padT + row * cellH + 1,
            cellW - 2,
            cellH - 2,
          ),
          const Radius.circular(4),
        ),
        Paint()
          ..color = theme.gridColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );

      // Day number
      final tp = textPainterCache.get(
        day.toString(),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 8,
        ),
      );
      tp.paint(canvas, Offset(padL + col * cellW + 4, padT + row * cellH + 3));

      // Mini pie
      final dd = dayData[day];
      if (dd != null && dd.slices.isNotEmpty) {
        final total = dd.slices.fold(0.0, (a, s) => a + s.value);
        if (total > 0) {
          double start = -math.pi / 2;
          for (int si = 0; si < dd.slices.length; si++) {
            final s = dd.slices[si];
            final sweep = s.value / total * 2 * math.pi * progress;
            final color = _sliceColor(s, si, theme);
            canvas.drawArc(
              Rect.fromCircle(center: Offset(cx, cy + 4), radius: pieR),
              start,
              sweep,
              true,
              Paint()
                ..color = color
                ..style = PaintingStyle.fill
                ..isAntiAlias = true,
            );
            start += sweep;
          }
        }
      } else {
        // Empty circle outline
        canvas.drawCircle(
          Offset(cx, cy + 4),
          pieR * 0.5,
          Paint()
            ..color = theme.gridColor.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 8. PIE WITH LABEL-LINE ADJUST
// ═══════════════════════════════════════════════════════════════════════════
/// Pie chart with leader lines from slices to external labels.
/// The label-line length and angle offset are configurable per-slice.
class PieLabelLineConfig extends BaseChartConfig {
  final List<PieSlice> slices;
  final double labelLineLength;
  final double labelLineAngleOffset; // extra rotation applied to leader line
  final double padAngle;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  PieLabelLineConfig({
    required this.slices,
    this.theme = ChartTheme.light,
    this.labelLineLength = 28.0,
    this.labelLineAngleOffset = 0.0,
    this.padAngle = 0.02,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.pie, series: const []);

  @override
  Widget buildChart() => _PieLabelLineWidget(config: this);

  factory PieLabelLineConfig.fromJson(Map<String, dynamic> j) {
    return PieLabelLineConfig(
      slices: _pieSlices(j),
      labelLineLength: PieJson.nonNegativeDouble(j['labelLineLength'], 28.0),
      labelLineAngleOffset: PieJson.doubleOr(j['labelLineAngleOffset'], 0.0),
      padAngle: PieJson.angleGap(j['padAngle'], 0.02),
      title: PieJson.title(j['title']),
      tooltip: PieJson.tooltip(j['tooltip']),
      legend: PieJson.legend(j['legend']),
      toolbox: PieJson.toolbox(j['toolbox']),
      grid: PieJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'type': 'pieLabelLine',
    ..._pieConfigJson(this),
    'series': [_sliceSeries(slices)],
    'labelLineLength': labelLineLength,
    'labelLineAngleOffset': labelLineAngleOffset,
    'padAngle': padAngle,
  };
}

class _PieLabelLineWidget extends StatefulWidget {
  final PieLabelLineConfig config;
  const _PieLabelLineWidget({required this.config});
  @override
  State<_PieLabelLineWidget> createState() => _PieLLState();
}

class _PieLLState extends State<_PieLabelLineWidget>
    with SingleTickerProviderStateMixin, _PieAnimMixin {
  PieLabelLineConfig get cfg => widget.config;
  @override
  void initState() {
    super.initState();
    initPieAnim();
  }

  @override
  void dispose() {
    disposePieAnim();
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
            painter: _PieLLPainter(cfg: cfg, progress: pieAnim.value),
          ),
        ),
      ),
    ],
  );
}

class _PieLLPainter extends ChartPainterBase {
  final PieLabelLineConfig cfg;
  final double progress;
  _PieLLPainter({required this.cfg, required this.progress})
    : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _PieLLPainter o) => o.progress != progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (cfg.slices.isEmpty) return;
    final cx = size.width / 2, cy = size.height / 2;
    // Shrink pie to leave room for labels
    final r = math.min(cx, cy) * 0.58;
    final total = cfg.slices.fold(0.0, (a, s) => a + s.value);
    if (total == 0) return;

    double start = -math.pi / 2;
    for (int i = 0; i < cfg.slices.length; i++) {
      final s = cfg.slices[i];
      final sweep = s.value / total * 2 * math.pi * progress;
      final color = _sliceColor(s, i, theme);
      final midAngle = start + sweep / 2 + cfg.labelLineAngleOffset;

      // Slice
      final path = _wedgePath(
        center: Offset(cx, cy),
        innerR: 0,
        outerR: r,
        startAngle: start + cfg.padAngle / 2,
        sweepAngle: sweep - cfg.padAngle,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      // Leader line + label
      if (sweep > 0.05) {
        final p1 = Offset(
          cx + r * math.cos(midAngle),
          cy + r * math.sin(midAngle),
        );
        final p2 = Offset(
          cx + (r + cfg.labelLineLength) * math.cos(midAngle),
          cy + (r + cfg.labelLineLength) * math.sin(midAngle),
        );
        // Short elbow
        final elbowX = midAngle > 0 && midAngle < math.pi
            ? p2.dx + 12
            : p2.dx - 12;
        final p3 = Offset(elbowX, p2.dy);

        canvas.drawLine(
          p1,
          p2,
          paintCache.stroke(color, 1.2)..isAntiAlias = true,
        );
        canvas.drawLine(
          p2,
          p3,
          paintCache.stroke(color, 1.2)..isAntiAlias = true,
        );
        canvas.drawCircle(
          p1,
          2,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );

        final pct = '${(s.value / total * 100).toStringAsFixed(0)}%';
        final lblStr = '${s.name}\n$pct';
        final align = elbowX > cx ? TextAlign.left : TextAlign.right;
        final tp = textPainterCache.get(
          lblStr,
          theme.typography.axisLabelStyle.copyWith(
            color: theme.titleColor,
            fontSize: 9,
          ),
          align: align,
          maxWidth: 80,
        );
        final lx = align == TextAlign.left ? p3.dx + 3 : p3.dx - tp.width - 3;
        tp.paint(canvas, Offset(lx, p3.dy - tp.height / 2));
      }
      start += sweep;
    }
  }
}
