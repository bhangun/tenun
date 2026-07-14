import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_render_pipeline.dart';
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

// ═══════════════════════════════════════════════════════════════════════════
// 4. LARGE SCALE AREA CHART  (LTTB downsampled for performance)
// ═══════════════════════════════════════════════════════════════════════════
class LargeScaleAreaConfig extends BaseChartConfig {
  final List<double> xData;
  final List<double> yData;
  final int targetPoints; // LTTB target (default 500)
  final String? seriesName, seriesColor;
  final double fillOpacity;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  LargeScaleAreaConfig({
    required this.xData,
    required this.yData,
    this.targetPoints = 500,
    this.seriesName,
    this.seriesColor,
    this.fillOpacity = 0.25,
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.largeScaleArea, series: const []);

  @override
  Widget buildChart() => _LargeScaleWidget(config: this);

  factory LargeScaleAreaConfig.fromJson(Map<String, dynamic> j) {
    final rawSeriesData = ChartSeriesJson.firstSeriesRawData(j['series']);
    final xFromSeries = <double>[];
    final yFromSeries = <double>[];
    for (final item in rawSeriesData) {
      final tuple = JsonValue.list(item);
      final map = JsonValue.map(item);
      if (tuple != null && tuple.length >= 2) {
        xFromSeries.add(JsonValue.doubleOrNull(tuple[0]) ?? 0);
        yFromSeries.add(JsonValue.doubleOrNull(tuple[1]) ?? 0);
      } else if (map != null) {
        xFromSeries.add(JsonValue.doubleOrNull(map['x']) ?? 0);
        yFromSeries.add(JsonValue.doubleOrNull(map['y']) ?? 0);
      }
    }
    final x = JsonValue.doubleList(j['xData']) ?? xFromSeries;
    final y = JsonValue.doubleList(j['yData']) ?? yFromSeries;
    return LargeScaleAreaConfig(
      xData: x,
      yData: y,
      targetPoints: JsonValue.intOrNull(j['targetPoints']) ?? 500,
      seriesName: j['seriesName']?.toString(),
      seriesColor: j['seriesColor']?.toString(),
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
    'xData': xData,
    'yData': yData,
    'targetPoints': targetPoints,
    if (seriesName != null) 'seriesName': seriesName,
    if (seriesColor != null) 'seriesColor': seriesColor,
    'fillOpacity': fillOpacity,
  };
}

class _LargeScaleWidget extends StatefulWidget {
  final LargeScaleAreaConfig config;
  const _LargeScaleWidget({required this.config});
  @override
  State<_LargeScaleWidget> createState() => _LargeScaleState();
}

class _LargeScaleState extends State<_LargeScaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  late List<Offset> _downsampled;
  ChartRenderPipeline? _pipeline;
  LargeScaleAreaConfig get cfg => widget.config;

  double _xMin = 0, _xMax = 0, _yMin = 0, _yMax = 0;

  @override
  void initState() {
    super.initState();
    _updateCalculations();
    _initPipeline();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
    final raw = List.generate(
      math.min(cfg.xData.length, cfg.yData.length),
      (i) => Offset(cfg.xData[i], cfg.yData[i]),
    );
    final sampled = LTTBSampler.sample(
      raw.map((p) => DataPoint(p.dx, p.dy)).toList(),
      cfg.targetPoints,
    );
    _downsampled = sampled.map((p) => Offset(p.x, p.y)).toList();

    if (_downsampled.isEmpty) {
      _xMin = _xMax = _yMin = _yMax = 0;
    } else {
      _xMin = _downsampled.map((p) => p.dx).reduce(math.min);
      _xMax = _downsampled.map((p) => p.dx).reduce(math.max);
      _yMin = _downsampled.map((p) => p.dy).reduce(math.min);
      _yMax = _downsampled.map((p) => p.dy).reduce(math.max);
      final yPad = (_yMax - _yMin) * 0.1;
      _yMin -= yPad;
      _yMax += yPad;
    }
  }

  void _initPipeline() {
    _pipeline?.dispose();
    _pipeline = ChartRenderPipeline([
      BackgroundLayer(cfg.theme),
      _LargeScaleGridLayer(this),
      _LargeScaleDataLayer(this),
    ]);
  }

  @override
  void didUpdateWidget(_LargeScaleWidget oldWidget) {
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
            painter: _LargeScalePainter(
              pipeline: _pipeline!,
              progress: _anim.value,
              theme: cfg.theme,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '${cfg.xData.length} pts → ${_downsampled.length} rendered (LTTB)',
          style: cfg.theme.typography.axisLabelStyle.copyWith(
            color: cfg.theme.axisLabelColor.withValues(alpha: 0.5),
            fontSize: 8.5,
          ),
        ),
      ),
    ],
  );
}

class _LargeScalePainter extends ChartPainterBase {
  final ChartRenderPipeline pipeline;
  final double progress;
  final String dataSignature;

  _LargeScalePainter({
    required this.pipeline,
    required this.progress,
    required this.dataSignature,
    required super.theme,
  });

  @override
  bool shouldRepaintChart(covariant _LargeScalePainter o) =>
      o.progress != progress ||
      o.pipeline != pipeline ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    pipeline.paint(canvas, size);
  }
}

class _LargeScaleGridLayer extends BaseRenderLayer {
  final _LargeScaleState state;
  _LargeScaleGridLayer(this.state);

  @override
  String get name => 'large_scale_grid';

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 24.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    if (plotW <= 0 || plotH <= 0) return;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: state._xMin,
      dataMaxX: state._xMax,
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

class _LargeScaleDataLayer extends BaseRenderLayer {
  final _LargeScaleState state;
  _LargeScaleDataLayer(this.state);

  @override
  String get name => 'large_scale_data';

  @override
  bool get cacheable => false;

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final progress = state._anim.value;
    final pts = state._downsampled;
    if (pts.isEmpty) return;

    const padL = 52.0, padR = 12.0, padT = 16.0, padB = 24.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: state._xMin,
      dataMaxX: state._xMax,
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

    final visCount = (pts.length * progress).round().clamp(1, pts.length);
    final visPts = pts
        .take(visCount)
        .map((p) => vp.toCanvas(p.dx, p.dy))
        .toList();

    if (visPts.length < 2) return;

    final linePath = Path()..moveTo(visPts.first.dx, visPts.first.dy);
    for (int i = 1; i < visPts.length; i++) {
      linePath.lineTo(visPts[i].dx, visPts[i].dy);
    }

    final areaPath = Path.from(linePath)
      ..lineTo(visPts.last.dx, padT + plotH)
      ..lineTo(visPts.first.dx, padT + plotH)
      ..close();

    final fillAlpha = cfg.fillOpacity.clamp(0.0, 1.0).toDouble();
    canvas.drawPath(
      areaPath,
      Paint()
        ..color = color.withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      linePath,
      paintCache.stroke(color, 1.5)..isAntiAlias = true,
    );
    clearDirty();
  }
}
