import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_render_pipeline.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_data_processor.dart';
import 'package:tenun_core/core/data_sampler.dart';
import 'package:tenun_core/core/chart_cache.dart';

// ─── shared helpers ────────────────────────────────────────────────────────

Path _smoothLine(List<Offset> pts, {double t = 0.4}) {
  if (pts.isEmpty) return Path();
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (int i = 0; i < pts.length - 1; i++) {
    final p0 = pts[i], p1 = pts[i + 1];
    final cp = (p1.dx - p0.dx) * t;
    p.cubicTo(p0.dx + cp, p0.dy, p1.dx - cp, p1.dy, p1.dx, p1.dy);
  }
  return p;
}

void _yGrid(
  Canvas c,
  ChartViewport vp,
  List<double> ticks,
  ChartTheme theme,
  String Function(double) fmt,
) {
  for (final t in ticks) {
    final y = vp.toCanvasY(t);
    if (y < vp.top || y > vp.bottom) continue;
    c.drawLine(
      Offset(vp.left, y),
      Offset(vp.right, y),
      paintCache.stroke(theme.gridColor, 0.5),
    );
    final tp = textPainterCache.get(
      fmt(t),
      theme.typography.axisLabelStyle.copyWith(
        color: theme.axisLabelColor,
        fontSize: 9,
      ),
      align: TextAlign.right,
      maxWidth: 46,
    );
    tp.paint(c, Offset(vp.left - tp.width - 4, y - tp.height / 2));
  }
}

List<Offset> _downsampleOffsets(List<Offset> points, {int threshold = 1200}) {
  if (points.length <= threshold) return points;
  final sampled = LTTBSampler.sample(
    points.map((p) => DataPoint(p.dx, p.dy)).toList(),
    threshold,
  );
  return sampled.map((p) => Offset(p.x, p.y)).toList();
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. LINE STYLE & ITEM STYLE
// ═══════════════════════════════════════════════════════════════════════════
/// Line chart where each series has configurable dash pattern, line width,
/// dot shape (circle/square/diamond), dot size, and opacity.
class LineStyleSpec {
  final String type; // 'solid' | 'dashed' | 'dotted'
  final double width;
  final List<double> dash;
  const LineStyleSpec({
    this.type = 'solid',
    this.width = 2.0,
    this.dash = const [8, 4],
  });
  factory LineStyleSpec.fromJson(Map<String, dynamic> j) => LineStyleSpec(
    type: j['type']?.toString() ?? 'solid',
    width: _readDouble(j['width'], 2.0),
    dash: (j['dash'] as List? ?? [8, 4])
        .map<double>((v) => _readDouble(v))
        .toList(),
  );

  Map<String, dynamic> toJson() => {'type': type, 'width': width, 'dash': dash};
}

class ItemStyleSpec {
  final String shape; // 'circle' | 'square' | 'diamond'
  final double size;
  const ItemStyleSpec({this.shape = 'circle', this.size = 5.0});
  factory ItemStyleSpec.fromJson(Map<String, dynamic> j) => ItemStyleSpec(
    shape: j['shape']?.toString() ?? 'circle',
    size: _readDouble(j['size'], 5.0),
  );

  Map<String, dynamic> toJson() => {'shape': shape, 'size': size};
}

class LineStyleSeries {
  final String? name, color;
  final List<double> data;
  final LineStyleSpec lineStyle;
  final ItemStyleSpec itemStyle;
  const LineStyleSeries({
    this.name,
    this.color,
    required this.data,
    this.lineStyle = const LineStyleSpec(),
    this.itemStyle = const ItemStyleSpec(),
  });

  factory LineStyleSeries.fromJson(Map<String, dynamic> j) => LineStyleSeries(
    name: j['name']?.toString(),
    color: j['color']?.toString(),
    data: (j['data'] as List? ?? []).map<double>(_readDouble).toList(),
    lineStyle: j['lineStyle'] != null
        ? LineStyleSpec.fromJson(
            Map<String, dynamic>.from(j['lineStyle'] as Map),
          )
        : const LineStyleSpec(),
    itemStyle: j['itemStyle'] != null
        ? ItemStyleSpec.fromJson(
            Map<String, dynamic>.from(j['itemStyle'] as Map),
          )
        : const ItemStyleSpec(),
  );

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (color != null) 'color': color,
    'data': data,
    'lineStyle': lineStyle.toJson(),
    'itemStyle': itemStyle.toJson(),
  };
}

double _readDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

class LineStyleItemConfig extends BaseChartConfig {
  final List<String> categories;
  final List<LineStyleSeries> styledSeries;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  LineStyleItemConfig({
    required this.categories,
    required this.styledSeries,
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.lineStyleItem, series: const []);

  @override
  Widget buildChart() => _LineStyleWidget(config: this);

  factory LineStyleItemConfig.fromJson(Map<String, dynamic> j) {
    final cats = (j['categories'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final s = (j['series'] as List? ?? [])
        .whereType<Map>()
        .map(
          (series) =>
              LineStyleSeries.fromJson(Map<String, dynamic>.from(series)),
        )
        .toList();
    return LineStyleItemConfig(
      categories: cats,
      styledSeries: s,
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
    'series': styledSeries.map((series) => series.toJson()).toList(),
  };
}

class _LineStyleWidget extends StatefulWidget {
  final LineStyleItemConfig config;
  const _LineStyleWidget({required this.config});
  @override
  State<_LineStyleWidget> createState() => _LineStyleState();
}

class _LineStyleState extends State<_LineStyleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  ChartRenderPipeline? _pipeline;
  late String _dataSignature;
  LineStyleItemConfig get cfg => widget.config;

  double _yMin = 0;
  double _yMax = 100;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() {
      _pipeline?.markAllDirty();
      setState(() {});
    });
    _updateCalculations();
    _initPipeline();
    _ctrl.forward();
  }

  void _updateCalculations() {
    final allVals = cfg.styledSeries.expand((s) => s.data).toList();
    if (allVals.isEmpty) {
      _yMin = 0;
      _yMax = 100;
    } else {
      _yMin = allVals.reduce(math.min);
      _yMax = allVals.reduce(math.max);
      final yPad = (_yMax - _yMin) * 0.12;
      _yMin -= yPad;
      _yMax += yPad;
    }
  }

  void _initPipeline() {
    _pipeline?.dispose();
    _pipeline = ChartRenderPipeline([
      BackgroundLayer(cfg.theme),
      _LineStyleGridLayer(this),
      _LineStyleDataLayer(this),
      _LineStyleXAxisLayer(this),
    ]);
  }

  @override
  void didUpdateWidget(_LineStyleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    final dataChanged = nextSignature != _dataSignature;
    if (widget.config != oldWidget.config || dataChanged) {
      _dataSignature = nextSignature;
      _updateCalculations();
      _initPipeline();
      if (dataChanged) _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pipeline?.dispose();
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
            painter: _LineStylePainter(
              pipeline: _pipeline!,
              progress: _anim.value,
              dataSignature: _dataSignature,
              theme: cfg.theme,
            ),
          ),
        ),
      ),
      _buildLegend(),
    ],
  );

  Widget _buildLegend() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      spacing: 14,
      alignment: WrapAlignment.center,
      children: cfg.styledSeries.asMap().entries.map((e) {
        final color = cfg.theme.seriesColor(
          e.key,
          explicitColor: e.value.color,
        );
        final ls = e.value.lineStyle;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 14,
              child: CustomPaint(
                painter: _LegendLinePainter(color: color, ls: ls),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              e.value.name ?? 'S${e.key + 1}',
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

class _LegendLinePainter extends CustomPainter {
  final Color color;
  final LineStyleSpec ls;
  _LegendLinePainter({required this.color, required this.ls});
  @override
  bool shouldRepaint(_) => false;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = ls.width
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    if (ls.type == 'dashed') {
      double x = 0;
      bool on = true;
      while (x < size.width) {
        final segLen = on ? ls.dash[0] : ls.dash[1];
        if (on) {
          canvas.drawLine(
            Offset(x, size.height / 2),
            Offset(math.min(x + segLen, size.width), size.height / 2),
            paint,
          );
        }
        x += segLen;
        on = !on;
      }
    } else if (ls.type == 'dotted') {
      double x = 0;
      while (x < size.width) {
        canvas.drawCircle(
          Offset(x, size.height / 2),
          ls.width / 2,
          paint..style = PaintingStyle.fill,
        );
        x += ls.width * 3;
      }
    } else {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    }
  }
}

class _LineStylePainter extends ChartPainterBase {
  final ChartRenderPipeline pipeline;
  final double progress;
  final String dataSignature;

  _LineStylePainter({
    required this.pipeline,
    required this.progress,
    required this.dataSignature,
    required super.theme,
  });

  @override
  bool shouldRepaintChart(covariant _LineStylePainter o) =>
      o.progress != progress ||
      o.pipeline != pipeline ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    pipeline.paint(canvas, size);
  }
}

class _LineStyleGridLayer extends BaseRenderLayer {
  final _LineStyleState state;
  _LineStyleGridLayer(this.state);

  @override
  String get name => 'line_style_grid';

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    if (plotW <= 0 || plotH <= 0) return;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: 0,
      dataMaxX: (cfg.categories.length - 1).toDouble(),
      dataMinY: state._yMin,
      dataMaxY: state._yMax,
    );

    final ticks = ChartDataProcessor.niceYTicks(state._yMin, state._yMax);
    _yGrid(canvas, vp, ticks, theme, (t) => t.toStringAsFixed(0));

    final axisPaint = paintCache.stroke(theme.axisColor, 1.0);
    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);

    clearDirty();
  }
}

void _drawDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint, {
  double dashLen = 4,
  double gapLen = 4,
}) {
  final dx = end.dx - start.dx;
  final dy = end.dy - start.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  final ux = dx / len;
  final uy = dy / len;
  double cur = 0;
  while (cur < len) {
    final next = math.min(cur + dashLen, len);
    canvas.drawLine(
      Offset(start.dx + ux * cur, start.dy + uy * cur),
      Offset(start.dx + ux * next, start.dy + uy * next),
      paint,
    );
    cur += dashLen + gapLen;
  }
}

class _LineStyleDataLayer extends BaseRenderLayer {
  final _LineStyleState state;
  _LineStyleDataLayer(this.state);

  @override
  String get name => 'line_style_data';

  @override
  bool get cacheable => false;

  void _drawItem(Canvas canvas, Offset p, ItemStyleSpec is_, Color color) {
    final r = is_.size / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    switch (is_.shape) {
      case 'square':
        canvas.drawRect(
          Rect.fromCenter(center: p, width: is_.size, height: is_.size),
          paint,
        );
      case 'diamond':
        final path = Path()
          ..moveTo(p.dx, p.dy - r)
          ..lineTo(p.dx + r, p.dy)
          ..lineTo(p.dx, p.dy + r)
          ..lineTo(p.dx - r, p.dy)
          ..close();
        canvas.drawPath(path, paint);
      default:
        canvas.drawCircle(p, r, paint);
        canvas.drawCircle(
          p,
          r,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..isAntiAlias = true,
        );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final progress = state._anim.value;
    final n = cfg.categories.length;
    if (n == 0 || cfg.styledSeries.isEmpty) return;

    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: 0,
      dataMaxX: (n - 1).toDouble(),
      dataMinY: state._yMin,
      dataMaxY: state._yMax,
    );

    for (int si = 0; si < cfg.styledSeries.length; si++) {
      final s = cfg.styledSeries[si];
      final color = theme.seriesColor(si, explicitColor: s.color);
      final ptsRaw = List.generate(math.min(s.data.length, n), (i) {
        final animY = state._yMin + (s.data[i] - state._yMin) * progress;
        return Offset(vp.toCanvasX(i.toDouble()), vp.toCanvasY(animY));
      });
      final pts = _downsampleOffsets(ptsRaw);
      if (pts.length < 2) continue;

      final linePaint = Paint()
        ..color = color
        ..strokeWidth = s.lineStyle.width
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round;

      if (s.lineStyle.type == 'dashed') {
        _drawDashedLine(canvas, pts.first, pts.last, linePaint);
        for (int i = 0; i < pts.length - 1; i++) {
          _drawDashedLine(canvas, pts[i], pts[i + 1], linePaint);
        }
      } else if (s.lineStyle.type == 'dotted') {
        for (int i = 0; i < pts.length - 1; i++) {
          _drawDashedLine(
            canvas,
            pts[i],
            pts[i + 1],
            Paint()
              ..color = color
              ..strokeWidth = s.lineStyle.width
              ..style = PaintingStyle.stroke
              ..isAntiAlias = true,
          );
        }
      } else {
        canvas.drawPath(_smoothLine(pts), linePaint);
      }

      for (final p in pts) {
        _drawItem(canvas, p, s.itemStyle, color);
      }
    }
    clearDirty();
  }
}

class _LineStyleXAxisLayer extends BaseRenderLayer {
  final _LineStyleState state;
  _LineStyleXAxisLayer(this.state);

  @override
  String get name => 'line_style_xaxis';

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final n = cfg.categories.length;
    if (n == 0) return;

    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: 0,
      dataMaxX: (n - 1).toDouble(),
      dataMinY: state._yMin,
      dataMaxY: state._yMax,
    );

    for (int i = 0; i < n; i++) {
      if (i % math.max(1, (n / 8).round()) == 0 || i == n - 1) {
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
    clearDirty();
  }
}
