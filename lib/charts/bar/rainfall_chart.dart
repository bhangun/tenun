import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/chart_render_pipeline.dart';

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

// ═══════════════════════════════════════════════════════════════════════════
// 1. RAINFALL CHART
// ═══════════════════════════════════════════════════════════════════════════

class RainfallChartConfig extends BaseChartConfig {
  final List<String> categories;
  final double barWidthRatio;
  final bool showLine;

  RainfallChartConfig({
    required this.categories,
    required super.series,
    super.theme = ChartTheme.light,
    this.barWidthRatio = 0.45,
    this.showLine = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.rainfall);

  @override
  Widget buildChart() => _RainfallWidget(config: this);

  factory RainfallChartConfig.fromJson(Map<String, dynamic> j) {
    final cats = JsonValue.stringList(j['categories']) ?? const <String>[];
    final s = (JsonValue.mapList(j['series']) ?? const [])
        .map(Series.fromJson)
        .toList();
    return RainfallChartConfig(
      categories: cats,
      series: s,
      barWidthRatio: JsonValue.doubleOrNull(j['barWidthRatio']) ?? 0.45,
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
    'categories': categories,
    'barWidthRatio': barWidthRatio,
    'showLine': showLine,
  };
}

class _RainfallWidget extends StatefulWidget {
  final RainfallChartConfig config;
  const _RainfallWidget({required this.config});
  @override
  State<_RainfallWidget> createState() => _RainfallState();
}

class _RainfallState extends State<_RainfallWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  ChartRenderPipeline? _pipeline;

  double _barMax = 0;
  double _lineMin = 0;
  double _lineMax = 100;
  List<Series> _barSeries = [];
  List<Series> _lineSeries = [];

  @override
  void initState() {
    super.initState();
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
    _updateCalculations();
    _initPipeline();
    _ctrl.forward();
  }

  void _updateCalculations() {
    final cfg = widget.config;
    _barSeries = cfg.series.where((s) => s.type != ChartType.line).toList();
    _lineSeries = cfg.showLine
        ? cfg.series.where((s) => s.type == ChartType.line).toList()
        : <Series>[];

    _barMax = 0;
    for (final s in _barSeries) {
      for (final v in s.data ?? []) {
        final d = ChartDataValueReader.yValue(v);
        if (d > _barMax) _barMax = d;
      }
    }
    _barMax = _barMax * 1.15 + 1;

    _lineMin = double.infinity;
    _lineMax = double.negativeInfinity;
    for (final s in _lineSeries) {
      for (final v in s.data ?? []) {
        final d = ChartDataValueReader.yValue(v);
        if (d < _lineMin) _lineMin = d;
        if (d > _lineMax) _lineMax = d;
      }
    }
    if (_lineMin == double.infinity) {
      _lineMin = 0;
      _lineMax = 100;
    }
    final linePad = (_lineMax - _lineMin) * 0.15;
    _lineMin -= linePad;
    _lineMax += linePad;
  }

  void _initPipeline() {
    _pipeline?.dispose();
    _pipeline = ChartRenderPipeline([
      BackgroundLayer(widget.config.theme),
      _RainfallGridLayer(this),
      _RainfallBarLayer(this),
      _RainfallLineLayer(this),
      _RainfallXAxisLayer(this),
    ]);
  }

  @override
  void didUpdateWidget(_RainfallWidget oldWidget) {
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
              painter: _RainfallPainter(
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
          final isLine = e.value.type == ChartType.line;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLine
                  ? Container(width: 16, height: 2, color: color)
                  : Container(width: 10, height: 10, color: color),
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

class _RainfallPainter extends ChartPainterBase {
  final ChartRenderPipeline pipeline;
  final double progress;
  final String dataSignature;

  _RainfallPainter({
    required this.pipeline,
    required this.progress,
    required this.dataSignature,
    required super.theme,
  });

  @override
  bool shouldRepaintChart(covariant _RainfallPainter o) =>
      o.progress != progress ||
      o.pipeline != pipeline ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    pipeline.paint(canvas, size);
  }
}

class _RainfallGridLayer extends BaseRenderLayer {
  final _RainfallState state;
  _RainfallGridLayer(this.state);

  @override
  String get name => 'rainfall_grid';

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    const padL = 52.0, padR = 48.0, padT = 24.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    if (plotW <= 0 || plotH <= 0) return;

    // Grid + left axis (bar)
    final barTicks = ChartDataProcessor.niceYTicks(0, state._barMax);
    for (final t in barTicks) {
      final y = padT + plotH * (1 - t / state._barMax);
      canvas.drawLine(
        Offset(padL, y),
        Offset(padL + plotW, y),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final tp = textPainterCache.get(
        t.toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
        align: TextAlign.right,
        maxWidth: 46,
      );
      tp.paint(canvas, Offset(padL - tp.width - 4, y - tp.height / 2));
    }

    // Right axis (line)
    if (state._lineSeries.isNotEmpty) {
      final lineTicks = ChartDataProcessor.niceYTicks(
        state._lineMin,
        state._lineMax,
      );
      for (final t in lineTicks) {
        final y =
            padT +
            plotH *
                (1 - (t - state._lineMin) / (state._lineMax - state._lineMin));
        final tp = textPainterCache.get(
          t.toStringAsFixed(0),
          theme.typography.axisLabelStyle.copyWith(
            color: theme.seriesColor(state._barSeries.length),
            fontSize: 9,
          ),
        );
        tp.paint(canvas, Offset(padL + plotW + 6, y - tp.height / 2));
      }
    }

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

class _RainfallBarLayer extends BaseRenderLayer {
  final _RainfallState state;
  _RainfallBarLayer(this.state);

  @override
  String get name => 'rainfall_bars';

  @override
  bool get cacheable => false; // Animating

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final progress = state._anim.value;
    final n = cfg.categories.length;
    if (n == 0) return;

    const padL = 52.0, padR = 48.0, padT = 24.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final slotW = plotW / n;

    final barSeries = state._barSeries;

    for (int si = 0; si < barSeries.length; si++) {
      final s = barSeries[si];
      final color = theme.seriesColor(si, explicitColor: s.color);
      final barW = slotW * cfg.barWidthRatio / barSeries.length;

      for (int ci = 0; ci < n; ci++) {
        final d = s.data;
        if (d == null || ci >= d.length) continue;
        final val = ChartDataValueReader.yValue(d[ci]);
        final barH = (val / state._barMax) * plotH * progress;
        final cx = padL + (ci + 0.5) * slotW;
        final barX = cx - (slotW * cfg.barWidthRatio) / 2 + si * barW;
        final barTop = padT + plotH - barH;

        // Bar body
        canvas.drawRect(
          Rect.fromLTWH(barX, barTop, barW - 2, barH),
          paintCache.fillMutable(color.withValues(alpha: 0.75)),
        );

        // Wave top (sinusoidal bump)
        if (barH > 8) {
          final waveH = math.min(barH * 0.12, 6.0);
          final wavePath = Path();
          wavePath.moveTo(barX, barTop);
          for (int wi = 0; wi <= 20; wi++) {
            final wx = barX + (barW - 2) * wi / 20;
            final wy = barTop - waveH * math.sin(wi / 20 * math.pi * 2);
            if (wi == 0) {
              wavePath.moveTo(wx, wy);
            } else {
              wavePath.lineTo(wx, wy);
            }
          }
          wavePath.lineTo(barX + barW - 2, barTop);
          wavePath.close();
          canvas.drawPath(wavePath, paintCache.fill(color));
        }
      }
    }
    clearDirty();
  }
}

class _RainfallLineLayer extends BaseRenderLayer {
  final _RainfallState state;
  _RainfallLineLayer(this.state);

  @override
  String get name => 'rainfall_lines';

  @override
  bool get cacheable => false; // Animating

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final progress = state._anim.value;
    final n = cfg.categories.length;
    if (n == 0) return;

    const padL = 52.0, padR = 48.0, padT = 24.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final slotW = plotW / n;

    final lineSeries = state._lineSeries;
    final barSeriesCount = state._barSeries.length;

    for (int si = 0; si < lineSeries.length; si++) {
      final s = lineSeries[si];
      final color = theme.seriesColor(
        barSeriesCount + si,
        explicitColor: s.color,
      );
      final pts = <Offset>[];
      final lineSpan = state._lineMax - state._lineMin;
      for (int ci = 0; ci < n; ci++) {
        final d = s.data;
        if (d == null || ci >= d.length) continue;
        final val = ChartDataValueReader.yValue(d[ci]);
        final normalized = lineSpan == 0
            ? 0.5
            : (val - state._lineMin) / lineSpan;
        final y = padT + plotH * (1 - normalized * progress);
        pts.add(Offset(padL + (ci + 0.5) * slotW, y));
      }
      if (pts.length >= 2) {
        canvas.drawPath(_smoothLine(pts), paintCache.stroke(color, 2.2));
        for (final p in pts) {
          canvas.drawCircle(p, 4, paintCache.fill(color));
          canvas.drawCircle(p, 4, paintCache.stroke(Colors.white, 1.5));
        }
      }
    }
    clearDirty();
  }
}

class _RainfallXAxisLayer extends BaseRenderLayer {
  final _RainfallState state;
  _RainfallXAxisLayer(this.state);

  @override
  String get name => 'rainfall_xaxis';

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final n = cfg.categories.length;
    if (n == 0) return;

    const padL = 52.0, padR = 48.0, padT = 24.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final slotW = plotW / n;

    for (int i = 0; i < n; i++) {
      final tp = textPainterCache.get(
        cfg.categories[i],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9.5,
        ),
      );
      tp.paint(
        canvas,
        Offset(padL + (i + 0.5) * slotW - tp.width / 2, padT + plotH + 4),
      );
    }
    clearDirty();
  }
}
