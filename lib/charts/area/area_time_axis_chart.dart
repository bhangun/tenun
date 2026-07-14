import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tenun_core/core/chart_render_pipeline.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_data_processor.dart';
import 'package:tenun_core/core/data_sampler.dart';
import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_series_json.dart';
import 'package:tenun_core/core/json_value.dart';

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
// 5. AREA CHART WITH TIME AXIS  (DateTime-based X)
// ═══════════════════════════════════════════════════════════════════════════
class TimePoint {
  final DateTime time;
  final double value;
  const TimePoint({required this.time, required this.value});
  factory TimePoint.fromJson(Map<String, dynamic> j) => TimePoint(
    time: _parseDateTime(j['time']),
    value: JsonValue.doubleOrNull(j['value']) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'value': value,
  };
}

class AreaTimeAxisConfig extends BaseChartConfig {
  final List<TimePoint> points;
  final String? seriesName, seriesColor;
  final double fillOpacity;
  final bool showLine;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  AreaTimeAxisConfig({
    required this.points,
    this.seriesName,
    this.seriesColor,
    this.fillOpacity = 0.3,
    this.showLine = true,
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.areaTimeAxis, series: const []);

  @override
  Widget buildChart() => _AreaTimeWidget(config: this);

  factory AreaTimeAxisConfig.fromJson(Map<String, dynamic> j) {
    final rawPoints = JsonValue.mapList(j['points']);
    final pts = (rawPoints ?? ChartSeriesJson.firstSeriesData(j['series']))
        .map(TimePoint.fromJson)
        .toList();
    return AreaTimeAxisConfig(
      points: pts,
      seriesName: j['seriesName']?.toString(),
      seriesColor: j['seriesColor']?.toString(),
      fillOpacity: JsonValue.doubleOrNull(j['fillOpacity']) ?? 0.3,
      showLine: JsonValue.boolOrNull(j['showLine']) ?? true,
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
    if (seriesName != null) 'seriesName': seriesName,
    if (seriesColor != null) 'seriesColor': seriesColor,
    'fillOpacity': fillOpacity,
    'showLine': showLine,
  };
}

DateTime _parseDateTime(Object? raw) {
  final text = raw?.toString();
  if (text == null || text.trim().isEmpty) return DateTime.now();
  return DateTime.tryParse(text) ?? DateTime.now();
}

class _AreaTimeWidget extends StatefulWidget {
  final AreaTimeAxisConfig config;
  const _AreaTimeWidget({required this.config});
  @override
  State<_AreaTimeWidget> createState() => _AreaTimeState();
}

class _AreaTimeState extends State<_AreaTimeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  ChartRenderPipeline? _pipeline;
  AreaTimeAxisConfig get cfg => widget.config;

  double _tMin = 0, _tMax = 0, _yMin = 0, _yMax = 0;
  Duration _span = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCalculations();
    _initPipeline();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() {
      _pipeline?.markAllDirty();
      setState(() {});
    });
    _dataSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _ctrl.forward();
  }

  void _updateCalculations() {
    if (cfg.points.isEmpty) {
      _tMin = _tMax = _yMin = _yMax = 0;
      _span = Duration.zero;
      return;
    }
    _tMin = cfg.points.first.time.millisecondsSinceEpoch.toDouble();
    _tMax = cfg.points.last.time.millisecondsSinceEpoch.toDouble();
    _span = cfg.points.last.time.difference(cfg.points.first.time);
    _yMin = cfg.points.map((p) => p.value).reduce(math.min);
    _yMax = cfg.points.map((p) => p.value).reduce(math.max);
    final yPad = (_yMax - _yMin) * 0.1;
    _yMin -= yPad;
    _yMax += yPad;
  }

  void _initPipeline() {
    _pipeline?.dispose();
    _pipeline = ChartRenderPipeline([
      BackgroundLayer(cfg.theme),
      _AreaTimeGridLayer(this),
      _AreaTimeDataLayer(this),
      _AreaTimeXAxisLayer(this),
    ]);
  }

  @override
  void didUpdateWidget(_AreaTimeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    final signatureChanged = nextSignature != _dataSignature;
    if (signatureChanged || widget.config != oldWidget.config) {
      _dataSignature = nextSignature;
      _updateCalculations();
      _initPipeline();
      if (signatureChanged) {
        _ctrl.forward(from: 0);
      }
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
            painter: _AreaTimePainter(
              pipeline: _pipeline!,
              progress: _anim.value,
              theme: cfg.theme,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
    ],
  );
}

class _AreaTimePainter extends ChartPainterBase {
  final ChartRenderPipeline pipeline;
  final double progress;
  final String dataSignature;

  _AreaTimePainter({
    required this.pipeline,
    required this.progress,
    required this.dataSignature,
    required super.theme,
  });

  @override
  bool shouldRepaintChart(covariant _AreaTimePainter o) =>
      o.progress != progress ||
      o.pipeline != pipeline ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    pipeline.paint(canvas, size);
  }
}

class _AreaTimeGridLayer extends BaseRenderLayer {
  final _AreaTimeState state;
  _AreaTimeGridLayer(this.state);

  @override
  String get name => 'area_time_grid';

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    if (plotW <= 0 || plotH <= 0) return;
    if (plotW <= 0 || plotH <= 0) return;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: state._tMin,
      dataMaxX: state._tMax,
      dataMinY: state._yMin,
      dataMaxY: state._yMax,
    );

    final ticks = ChartDataProcessor.niceYTicks(state._yMin, state._yMax);
    _yGrid(canvas, vp, ticks, theme, (t) => t.toStringAsFixed(1));

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

class _AreaTimeDataLayer extends BaseRenderLayer {
  final _AreaTimeState state;
  _AreaTimeDataLayer(this.state);

  @override
  String get name => 'area_time_data';

  @override
  bool get cacheable => false;

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final progress = state._anim.value;
    if (cfg.points.isEmpty) return;

    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: state._tMin,
      dataMaxX: state._tMax,
      dataMinY: state._yMin,
      dataMaxY: state._yMax,
    );

    Color color;
    try {
      color = cfg.seriesColor != null
          ? colorCache.resolve(cfg.seriesColor!)
          : theme.seriesColor(0);
    } catch (_) {
      color = theme.seriesColor(0);
    }

    final visPtsRaw = cfg.points
        .map(
          (p) => Offset(
            vp.toCanvasX(p.time.millisecondsSinceEpoch.toDouble()),
            vp.toCanvasY(state._yMin + (p.value - state._yMin) * progress),
          ),
        )
        .toList();
    final visPts = _downsampleOffsets(visPtsRaw);

    final linePath = _smoothLine(visPts);
    final areaPath = Path.from(linePath)
      ..lineTo(visPts.last.dx, padT + plotH)
      ..lineTo(visPts.first.dx, padT + plotH)
      ..close();

    final fillAlpha = cfg.fillOpacity.clamp(0.0, 1.0).toDouble();
    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: fillAlpha),
            color.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(padL, padT, plotW, plotH))
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    if (cfg.showLine) {
      canvas.drawPath(
        linePath,
        paintCache.stroke(color, 1.8)..isAntiAlias = true,
      );
    }
    clearDirty();
  }
}

class _AreaTimeXAxisLayer extends BaseRenderLayer {
  final _AreaTimeState state;
  _AreaTimeXAxisLayer(this.state);

  @override
  String get name => 'area_time_xaxis';

  String _fmtTime(DateTime t, Duration span) {
    if (span.inDays > 365) return '${t.year}';
    if (span.inDays > 30) return '${t.month}/${t.year.toString().substring(2)}';
    if (span.inDays > 1) return '${t.month}/${t.day}';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    if (cfg.points.isEmpty) return;

    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: state._tMin,
      dataMaxX: state._tMax,
      dataMinY: state._yMin,
      dataMaxY: state._yMax,
    );

    final nLabels = 6;
    for (int i = 0; i <= nLabels; i++) {
      final tickMillis = (state._span.inMilliseconds * i / nLabels).round();
      final t = cfg.points.first.time.add(Duration(milliseconds: tickMillis));
      final x = vp.toCanvasX(t.millisecondsSinceEpoch.toDouble());
      final tp = textPainterCache.get(
        _fmtTime(t, state._span),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 8.5,
        ),
      );
      tp.paint(canvas, Offset(x - tp.width / 2, padT + plotH + 4));
    }
    clearDirty();
  }
}
