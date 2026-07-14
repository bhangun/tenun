// ═══════════════════════════════════════════════════════════
// 3. PARALLEL COORDINATES
// ═══════════════════════════════════════════════════════════

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/json_value.dart';

/// Parallel coordinates — each axis is one dimension, each line is one record.
/// JSON:
/// ```json
/// { "type": "parallel",
///   "axes": ["Price","Miles","HP","Weight","MPG"],
///   "series": [{
///     "name": "Sedan",
///     "data": [[25000,45000,150,3200,32],[32000,12000,180,3500,28]]
///   }]}
/// ```
class ParallelChartConfig extends BaseChartConfig {
  final List<String> axes;
  final double lineOpacity;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  ParallelChartConfig({
    required this.axes,
    required super.series,
    this.theme = ChartTheme.light,
    this.lineOpacity = 0.5,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.parallel);

  @override
  Widget buildChart() => ParallelChartWidget(config: this);

  factory ParallelChartConfig.fromJson(Map<String, dynamic> json) {
    final axes = JsonValue.stringList(json['axes']) ?? const <String>[];
    final s = (JsonValue.mapList(json['series']) ?? const [])
        .map(Series.fromJson)
        .toList();
    return ParallelChartConfig(
      axes: axes,
      series: s,
      lineOpacity: JsonValue.doubleOrNull(json['lineOpacity']) ?? 0.5,
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
    'axes': axes,
    'lineOpacity': lineOpacity,
  };
}

class ParallelChartWidget extends StatefulWidget {
  final ParallelChartConfig config;
  const ParallelChartWidget({super.key, required this.config});
  @override
  State<ParallelChartWidget> createState() => _ParallelState();
}

class _ParallelState extends State<ParallelChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  ParallelChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant ParallelChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature == _dataSignature) return;
    _dataSignature = nextSignature;
    _ctrl.forward(from: 0);
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
            painter: _ParallelPainter(
              config: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
      if (cfg.series.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 12,
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
        ),
    ],
  );
}

class _ParallelPainter extends ChartPainterBase {
  final ParallelChartConfig config;
  final double progress;
  final String dataSignature;

  _ParallelPainter({
    required this.config,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _ParallelPainter old) =>
      old.progress != progress || old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final nAxes = config.axes.length;
    if (nAxes < 2) return;
    const padL = 16.0, padR = 16.0, padT = 24.0, padB = 32.0;
    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;

    // Compute per-axis min/max
    final mins = List<double>.filled(nAxes, double.infinity);
    final maxs = List<double>.filled(nAxes, double.negativeInfinity);
    for (final s in config.series) {
      for (final row in s.data ?? []) {
        final vals = _parallelRowValues(row);
        for (int a = 0; a < math.min(nAxes, vals.length); a++) {
          final v = _parallelCellValue(vals[a]);
          if (v < mins[a]) mins[a] = v;
          if (v > maxs[a]) maxs[a] = v;
        }
      }
    }

    final axisXs = List.generate(nAxes, (i) => padL + i / (nAxes - 1) * chartW);

    // Draw axis lines
    for (int a = 0; a < nAxes; a++) {
      canvas.drawLine(
        Offset(axisXs[a], padT),
        Offset(axisXs[a], padT + chartH),
        axisPaint,
      );
      final tp = textPainterCache.get(
        config.axes[a],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 10,
        ),
        align: TextAlign.center,
        maxWidth: 60,
      );
      tp.paint(canvas, Offset(axisXs[a] - tp.width / 2, padT + chartH + 4));
      // Min/Max labels
      final minTp = textPainterCache.get(
        mins[a].toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 8,
        ),
      );
      final maxTp = textPainterCache.get(
        maxs[a].toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 8,
        ),
      );
      maxTp.paint(canvas, Offset(axisXs[a] - maxTp.width / 2, padT - 14));
      minTp.paint(
        canvas,
        Offset(axisXs[a] - minTp.width / 2, padT + chartH + 16),
      );
    }

    // Draw lines
    for (int si = 0; si < config.series.length; si++) {
      final s = config.series[si];
      final color = theme.seriesColor(si, explicitColor: s.itemStyle?.color);
      for (final row in s.data ?? []) {
        final vals = _parallelRowValues(row);
        final pts = <Offset>[];
        for (int a = 0; a < math.min(nAxes, vals.length); a++) {
          final v = _parallelCellValue(vals[a]);
          final range = (maxs[a] - mins[a]).clamp(1e-9, 1e18);
          final t = ((v - mins[a]) / range * progress).clamp(0.0, 1.0);
          pts.add(Offset(axisXs[a], padT + chartH - t * chartH));
        }
        if (pts.length < 2) continue;
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (int p = 1; p < pts.length; p++) {
          path.lineTo(pts[p].dx, pts[p].dy);
        }
        canvas.drawPath(
          path,
          paintCache.stroke(color.withValues(alpha: config.lineOpacity), 1.2),
        );
      }
    }
  }
}

List<dynamic> _parallelRowValues(Object? row) {
  final list = JsonValue.list(row);
  if (list != null) return list;

  final map = JsonValue.map(row);
  final values = JsonValue.list(map?['values']) ?? JsonValue.list(map?['data']);
  if (values != null) return values;

  return row == null ? const <dynamic>[] : <dynamic>[row];
}

double _parallelCellValue(Object? value) {
  return ChartDataValueReader.yValueOrNull(value) ?? 0;
}
