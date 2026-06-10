// Radar chart (spider / web chart) — multi-axis radial comparison.
//
// Each axis radiates from the centre. Multiple series are drawn as filled
// polygons overlaid on the same web. Supports hover tooltip and entrance animation.
//
// JSON:
// ```json
// {
//   "type": "radar",
//   "axes": [
//     { "name": "Speed",    "max": 100 },
//     { "name": "Power",    "max": 100 },
//     { "name": "Range",    "max": 100 },
//     { "name": "Defense",  "max": 100 },
//     { "name": "Agility",  "max": 100 }
//   ],
//   "series": [
//     { "name": "Unit A", "data": [80, 65, 55, 70, 90] },
//     { "name": "Unit B", "data": [40, 85, 70, 50, 60] }
//   ]
// }
// ```

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/base_config.dart';
import '../../core/chart_type.dart';
import '../../core/series.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';
import '../../core/legend.dart';
import '../../core/grid.dart';
import '../../core/chart_model.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_cache.dart';
import '../../core/chart_data_signature.dart';
import '../../core/chart_data_value_reader.dart';
import '../../core/json_value.dart';

// ─────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────

class RadarAxis {
  final String name;
  final double max;
  final double min;

  const RadarAxis({required this.name, this.max = 100, this.min = 0});

  factory RadarAxis.fromJson(Object? raw) {
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    final min = JsonValue.doubleOrNull(json['min']) ?? 0;
    final rawMax = JsonValue.doubleOrNull(json['max']) ?? 100;
    return RadarAxis(
      name: JsonValue.string(json['name']) ?? '',
      min: min,
      max: rawMax > min ? rawMax : min + 1,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'max': max, 'min': min};
}

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

class RadarChartConfig extends BaseChartConfig {
  final List<RadarAxis> axes;
  final bool filled;
  final bool showLabels;
  final bool showDots;
  final int webLevels;
  final double fillOpacity;
  final double startAngleDeg;

  RadarChartConfig({
    required this.axes,
    required super.series,
    super.theme,
    this.filled = true,
    this.showLabels = true,
    this.showDots = true,
    this.webLevels = 4,
    this.fillOpacity = 0.22,
    this.startAngleDeg = -90,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.radar);

  @override
  Widget buildChart() => RadarChartWidget(config: this);

  factory RadarChartConfig.fromJson(Map<String, dynamic> json) {
    final seriesList = (JsonValue.list(json['series']) ?? const [])
        .map(Series.fromJson)
        .toList();
    final parsedAxes = (JsonValue.list(json['axes']) ?? const [])
        .map(RadarAxis.fromJson)
        .toList();
    final axes = parsedAxes.isEmpty ? _inferRadarAxes(seriesList) : parsedAxes;

    return RadarChartConfig(
      axes: axes,
      series: seriesList,
      filled: JsonValue.boolOrNull(json['filled']) ?? true,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? true,
      showDots: JsonValue.boolOrNull(json['showDots']) ?? true,
      webLevels: (JsonValue.intOrNull(json['webLevels']) ?? 4)
          .clamp(1, 20)
          .toInt(),
      fillOpacity: (JsonValue.doubleOrNull(json['fillOpacity']) ?? 0.22)
          .clamp(0.0, 1.0)
          .toDouble(),
      startAngleDeg: JsonValue.doubleOrNull(json['startAngle']) ?? -90,
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
    'axes': axes.map((axis) => axis.toJson()).toList(),
    'filled': filled,
    'showLabels': showLabels,
    'showDots': showDots,
    'webLevels': webLevels,
    'fillOpacity': fillOpacity,
    'startAngle': startAngleDeg,
  };
}

List<RadarAxis> _inferRadarAxes(List<Series> seriesList) {
  var axisCount = 0;
  for (final series in seriesList) {
    axisCount = math.max(axisCount, series.data?.length ?? 0);
  }

  return List.generate(axisCount, (index) {
    var maxValue = 0.0;
    for (final series in seriesList) {
      final data = series.data;
      if (data == null || index >= data.length) continue;
      final value = _radarValueAt(data, index);
      if (value > maxValue) maxValue = value;
    }
    final max = maxValue <= 100 ? 100.0 : maxValue * 1.1;
    return RadarAxis(name: 'Axis ${index + 1}', max: max);
  });
}

double _radarValueAt(List<dynamic> data, int index) {
  if (index < 0 || index >= data.length) return 0;
  return ChartDataValueReader.yValueOrNull(data[index]) ?? 0;
}

String _radarValueLabel(Object? raw) {
  final value = ChartDataValueReader.yValueOrNull(raw);
  if (value == null) return raw?.toString() ?? '0';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

class RadarChartWidget extends StatefulWidget {
  final RadarChartConfig config;
  const RadarChartWidget({super.key, required this.config});

  @override
  State<RadarChartWidget> createState() => _RadarState();
}

class _RadarState extends State<RadarChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  int _hovSeries = -1;
  Offset _hoverPos = Offset.zero;

  RadarChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _dataSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(RadarChartWidget oldWidget) {
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

  int _hitTest(Offset pos, double cx, double cy, double r) {
    for (int s = 0; s < cfg.series.length; s++) {
      final pts = _seriesPoints(s, cx, cy, r);
      if (_inPolygon(pos, pts)) return s;
    }
    return -1;
  }

  List<Offset> _seriesPoints(int s, double cx, double cy, double r) {
    final data = cfg.series[s].data ?? [];
    return List.generate(cfg.axes.length, (i) {
      final val = _radarValueAt(data, i);
      final axis = cfg.axes[i];
      final axisSpan = axis.max - axis.min;
      final frac = axisSpan == 0
          ? 0.0
          : ((val - axis.min) / axisSpan).clamp(0.0, 1.0);
      final angle =
          cfg.startAngleDeg * math.pi / 180 + i * 2 * math.pi / cfg.axes.length;
      return Offset(
        cx + r * frac * math.cos(angle),
        cy + r * frac * math.sin(angle),
      );
    });
  }

  bool _inPolygon(Offset pt, List<Offset> poly) {
    bool inside = false;
    int j = poly.length - 1;
    for (int i = 0; i < poly.length; j = i++) {
      final xi = poly[i].dx, yi = poly[i].dy;
      final xj = poly[j].dx, yj = poly[j].dy;
      if (((yi > pt.dy) != (yj > pt.dy)) &&
          (pt.dx < (xj - xi) * (pt.dy - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
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
              final cx = sz.width / 2, cy = (sz.height - 32) / 2;
              final r = math.min(cx, cy) * 0.72;
              return Stack(
                children: [
                  MouseRegion(
                    onHover: (e) => setState(() {
                      _hovSeries = _hitTest(e.localPosition, cx, cy, r);
                      _hoverPos = e.localPosition;
                    }),
                    onExit: (_) => setState(() => _hovSeries = -1),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _RadarPainter(
                          config: cfg,
                          progress: _anim.value,
                          hovSeries: _hovSeries,
                          dataSignature: _dataSignature,
                        ),
                      ),
                    ),
                  ),
                  if (_hovSeries >= 0) _buildTooltip(sz, r, cx, cy),
                ],
              );
            },
          ),
        ),
        if (cfg.legend?.show != false && cfg.series.length > 1) _buildLegend(),
      ],
    );
  }

  Widget _buildTooltip(Size sz, double r, double cx, double cy) {
    final s = cfg.series[_hovSeries];
    final data = s.data ?? [];
    double x = (_hoverPos.dx + 14).clamp(0, sz.width - 180.0);
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
                Text(
                  s.name ?? 'Series ${_hovSeries + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ...List.generate(
                  math.min(cfg.axes.length, data.length),
                  (i) =>
                      Text('${cfg.axes[i].name}: ${_radarValueLabel(data[i])}'),
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
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: cfg.series.asMap().entries.map((e) {
          final color = cfg.theme.seriesColor(
            e.key,
            explicitColor: e.value.itemStyle?.color,
          );
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
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

// ─────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────

class _RadarPainter extends ChartPainterBase {
  final RadarChartConfig config;
  final double progress;
  final int hovSeries;
  final String dataSignature;

  _RadarPainter({
    required this.config,
    required this.progress,
    required this.hovSeries,
    required this.dataSignature,
  }) : super(theme: config.theme);

  @override
  bool shouldRepaintChart(covariant _RadarPainter old) =>
      old.progress != progress ||
      old.hovSeries != hovSeries ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    if (config.axes.isEmpty) return;
    final n = config.axes.length;
    final cx = size.width / 2, cy = (size.height - 32) / 2;
    final r = math.min(cx, cy) * 0.72;
    final startRad = config.startAngleDeg * math.pi / 180;
    final webLevels = math.max(1, config.webLevels);

    // ── web background ──
    for (int level = webLevels; level >= 1; level--) {
      final frac = level / webLevels;
      final pts = List.generate(n, (i) {
        final angle = startRad + i * 2 * math.pi / n;
        return Offset(
          cx + r * frac * math.cos(angle),
          cy + r * frac * math.sin(angle),
        );
      });
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < n; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      canvas.drawPath(path, paintCache.fill(theme.gridColor));
      canvas.drawPath(
        path,
        paintCache.stroke(theme.gridColor.withValues(alpha: 2), 0.8),
      );
    }

    // ── axis lines ──
    for (int i = 0; i < n; i++) {
      final angle = startRad + i * 2 * math.pi / n;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
        paintCache.stroke(theme.gridColor.withValues(alpha: 1.5), 1),
      );
    }

    // ── series ──
    for (int s = config.series.length - 1; s >= 0; s--) {
      _drawSeries(canvas, s, cx, cy, r, startRad, n);
    }

    // ── axis labels ──
    if (config.showLabels) {
      for (int i = 0; i < n; i++) {
        final angle = startRad + i * 2 * math.pi / n;
        final labelR = r + 18;
        final lx = cx + labelR * math.cos(angle);
        final ly = cy + labelR * math.sin(angle);
        final tp = textPainterCache.get(
          config.axes[i].name,
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 10,
          ),
          maxWidth: 80,
          align: TextAlign.center,
        );
        tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      }
    }
  }

  void _drawSeries(
    Canvas canvas,
    int s,
    double cx,
    double cy,
    double r,
    double startRad,
    int n,
  ) {
    final series = config.series[s];
    final data = series.data ?? [];
    final color = theme.seriesColor(s, explicitColor: series.itemStyle?.color);
    final isHov = s == hovSeries;

    final pts = List.generate(n, (i) {
      final val = _radarValueAt(data, i);
      final axis = config.axes[i];
      final axisSpan = axis.max - axis.min;
      final frac = axisSpan == 0
          ? 0.0
          : ((val - axis.min) / axisSpan).clamp(0.0, 1.0) * progress;
      final angle = startRad + i * 2 * math.pi / n;
      return Offset(
        cx + r * frac * math.cos(angle),
        cy + r * frac * math.sin(angle),
      );
    });

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();

    if (config.filled) {
      final opacity = (isHov ? config.fillOpacity * 2 : config.fillOpacity)
          .clamp(0.0, 1.0)
          .toDouble();
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }

    canvas.drawPath(
      path,
      paintCache.stroke(
        color.withValues(alpha: isHov ? 1 : 0.85),
        isHov ? 2.5 : 1.8,
      ),
    );

    if (config.showDots) {
      for (final pt in pts) {
        canvas.drawCircle(
          pt,
          isHov ? 5 : 3.5,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          pt,
          isHov ? 5 : 3.5,
          paintCache.stroke(Colors.white, 1.2),
        );
      }
    }
  }
}
