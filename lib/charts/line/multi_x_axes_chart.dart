import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_data_processor.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/data_sampler.dart';
import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/chart_render_pipeline.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
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

List<Offset> _downsampleOffsets(List<Offset> points, {int threshold = 1200}) {
  if (points.length <= threshold) return points;
  final sampled = LTTBSampler.sample(
    points.map((p) => DataPoint(p.dx, p.dy)).toList(),
    threshold,
  );
  return sampled.map((p) => Offset(p.x, p.y)).toList();
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. MULTIPLE X AXES
// ═══════════════════════════════════════════════════════════════════════════
class XAxisDef {
  final String label;
  final List<String> categories;
  const XAxisDef({required this.label, required this.categories});

  factory XAxisDef.fromJson(Map<String, dynamic> j) => XAxisDef(
    label: j['label']?.toString() ?? '',
    categories: JsonValue.stringList(j['categories']) ?? const <String>[],
  );

  Map<String, dynamic> toJson() => {'label': label, 'categories': categories};
}

class MultiXAxesChartConfig extends BaseChartConfig {
  final List<XAxisDef> xAxes;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  MultiXAxesChartConfig({
    required this.xAxes,
    required super.series,
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.multiXAxes);

  @override
  Widget buildChart() => _MultiXWidget(config: this);

  factory MultiXAxesChartConfig.fromJson(Map<String, dynamic> j) {
    final axes = (JsonValue.mapList(j['xAxes']) ?? const [])
        .map(XAxisDef.fromJson)
        .toList();
    final s = (JsonValue.mapList(j['series']) ?? const [])
        .map(Series.fromJson)
        .toList();
    return MultiXAxesChartConfig(
      xAxes: axes,
      series: s,
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
    'xAxes': xAxes.map((axis) => axis.toJson()).toList(),
  };
}

class _MultiXWidget extends StatefulWidget {
  final MultiXAxesChartConfig config;
  const _MultiXWidget({required this.config});
  @override
  State<_MultiXWidget> createState() => _MultiXState();
}

class _MultiXState extends State<_MultiXWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  ChartRenderPipeline? _pipeline;

  double _yMin = 0;
  double _yMax = 100;
  List<double> _yTicks = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() {
      _pipeline?.markAllDirty();
      setState(() {});
    });
    _dataSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _updateCalculations();
    _initPipeline();
    _ctrl.forward();
  }

  void _updateCalculations() {
    final cfg = widget.config;
    final allVals = cfg.series
        .expand((s) => (s.data ?? []).map(ChartDataValueReader.yValue))
        .toList();
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
    _yTicks = ChartDataProcessor.niceYTicks(_yMin, _yMax);
  }

  void _initPipeline() {
    _pipeline?.dispose();
    _pipeline = ChartRenderPipeline([
      BackgroundLayer(widget.config.theme),
      _MultiXGridLayer(this),
      _MultiXSeriesLayer(this),
      _MultiXAxisLabelsLayer(this),
    ]);
  }

  @override
  void didUpdateWidget(_MultiXWidget oldWidget) {
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
  Widget build(BuildContext context) {
    final cfg = widget.config;
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
              painter: _MultiXPainter(
                pipeline: _pipeline!,
                progress: _anim.value,
                theme: cfg.theme,
                dataSignature: _dataSignature,
              ),
            ),
          ),
        ),
        _buildLegend(),
      ],
    );
  }

  Widget _buildLegend() {
    final cfg = widget.config;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 12,
        alignment: WrapAlignment.center,
        children: cfg.series.asMap().entries.map((e) {
          final color = cfg.theme.seriesColor(
            e.key,
            explicitColor: e.value.color,
          );
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 2, color: color),
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
}

class _MultiXPainter extends ChartPainterBase {
  final ChartRenderPipeline pipeline;
  final double progress;
  final String dataSignature;

  _MultiXPainter({
    required this.pipeline,
    required this.progress,
    required this.dataSignature,
    required super.theme,
  });

  @override
  bool shouldRepaintChart(covariant _MultiXPainter o) =>
      o.progress != progress ||
      o.pipeline != pipeline ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    pipeline.paint(canvas, size);
  }
}

class _MultiXGridLayer extends BaseRenderLayer {
  final _MultiXState state;
  _MultiXGridLayer(this.state);

  @override
  String get name => 'multix_grid';

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    const padL = 52.0, padR = 12.0, padT = 28.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    if (plotW <= 0 || plotH <= 0) return;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: 0,
      dataMaxX: 1,
      dataMinY: state._yMin,
      dataMaxY: state._yMax,
    );

    final gridPaint = paintCache.stroke(theme.gridColor, 0.5);
    final labelStyle = theme.typography.axisLabelStyle.copyWith(
      color: theme.axisLabelColor,
      fontSize: 9,
    );

    for (final t in state._yTicks) {
      final y = vp.toCanvasY(t);
      if (y < vp.top || y > vp.bottom) continue;
      canvas.drawLine(Offset(vp.left, y), Offset(vp.right, y), gridPaint);
      final tp = textPainterCache.get(
        t.toStringAsFixed(0),
        labelStyle,
        align: TextAlign.right,
        maxWidth: 46,
      );
      tp.paint(canvas, Offset(vp.left - tp.width - 4, y - tp.height / 2));
    }

    final axisPaint = paintCache.stroke(theme.axisColor, 1.0);
    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
    canvas.drawLine(Offset(padL, padT), Offset(padL + plotW, padT), axisPaint);

    clearDirty();
  }
}

class _MultiXSeriesLayer extends BaseRenderLayer {
  final _MultiXState state;
  _MultiXSeriesLayer(this.state);

  @override
  String get name => 'multix_series';

  @override
  bool get cacheable => false; // Animating

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final progress = state._anim.value;

    const padL = 52.0, padR = 12.0, padT = 28.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    if (plotW <= 0 || plotH <= 0) return;

    final vp = ChartViewport(
      left: padL,
      top: padT,
      right: padL + plotW,
      bottom: padT + plotH,
      dataMinX: 0,
      dataMaxX: 1,
      dataMinY: state._yMin,
      dataMaxY: state._yMax,
    );

    if (cfg.xAxes.isEmpty) return;

    for (int si = 0; si < cfg.series.length; si++) {
      final s = cfg.series[si];
      final axisIdx = (s.xAxisIndex ?? 0).clamp(0, cfg.xAxes.length - 1);
      final axis = cfg.xAxes[axisIdx];
      final n = axis.categories.length;
      if (n == 0) continue;
      final color = theme.seriesColor(si, explicitColor: s.color);
      final vals = (s.data ?? []).map(ChartDataValueReader.yValue).toList();
      final ptsRaw = List.generate(math.min(vals.length, n), (i) {
        final animY = state._yMin + (vals[i] - state._yMin) * progress;
        final x = n == 1 ? padL + plotW / 2 : padL + i / (n - 1) * plotW;
        return Offset(x, vp.toCanvasY(animY));
      });
      final pts = _downsampleOffsets(ptsRaw);
      if (pts.length >= 2) {
        canvas.drawPath(_smoothLine(pts), paintCache.stroke(color, 2.0));
        for (final p in pts) {
          canvas.drawCircle(p, 3, paintCache.fill(color));
        }
      }
    }
    clearDirty();
  }
}

class _MultiXAxisLabelsLayer extends BaseRenderLayer {
  final _MultiXState state;
  _MultiXAxisLabelsLayer(this.state);

  @override
  String get name => 'multix_labels';

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;

    const padL = 52.0, padR = 12.0, padT = 28.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    if (plotW <= 0 || plotH <= 0) return;
    if (cfg.xAxes.isEmpty) return;

    for (int si = 0; si < cfg.series.length; si++) {
      final s = cfg.series[si];
      final axisIdx = (s.xAxisIndex ?? 0).clamp(0, cfg.xAxes.length - 1);
      final axis = cfg.xAxes[axisIdx];
      final n = axis.categories.length;
      if (n == 0) continue;
      final color = theme.seriesColor(si, explicitColor: s.color);

      // Axis labels (bottom for axis 0, top for axis 1)
      final isTop = axisIdx == 1;
      for (int i = 0; i < n; i++) {
        if (i % math.max(1, (n / 8).round()) != 0 && i != n - 1) continue;
        final x = n == 1 ? padL + plotW / 2 : padL + i / (n - 1) * plotW;
        final tp = textPainterCache.get(
          axis.categories[i],
          theme.typography.axisLabelStyle.copyWith(
            color: color.withValues(alpha: 0.8),
            fontSize: 8.5,
          ),
        );
        final y = isTop ? padT - tp.height - 2 : padT + plotH + 4;
        tp.paint(canvas, Offset(x - tp.width / 2, y));
      }

      // Axis label text
      final axLbl = textPainterCache.get(
        axis.label,
        theme.typography.axisLabelStyle.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
      final lblY = isTop ? 2.0 : size.height - axLbl.height - 1;
      axLbl.paint(canvas, Offset(padL, lblY));
    }
    clearDirty();
  }
}
