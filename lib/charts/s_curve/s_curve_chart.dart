import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tenun_core/core/chart_animation_system.dart';
import 'package:tenun_core/core/chart_data_processor.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/series.dart';
import 's_curve_config.dart';

class SCurveChartWidget extends StatefulWidget {
  final SCurveChartConfig config;

  const SCurveChartWidget({super.key, required this.config});

  @override
  State<SCurveChartWidget> createState() => _SCurveChartWidgetState();
}

class _SCurveChartWidgetState extends State<SCurveChartWidget>
    with SingleTickerProviderStateMixin {
  late final ChartAnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = ChartAnimationController(
      vsync: this,
      preset: ChartAnimationPreset.draw,
    );
    _anim.addListener(() => setState(() {}));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;

    // 1. Prepare data (Cumulative transformation if needed)
    final List<Series> processedSeries = [];
    for (final s in config.series) {
      if (config.autoCumulative) {
        final List<double> cumulativeData = [];
        double sum = 0;
        for (final item in (s.data ?? [])) {
          final val = _toDouble(item) ?? 0;
          sum += val;
          cumulativeData.add(sum);
        }
        processedSeries.add(
          Series(
            type: s.type,
            name: s.name,
            data: cumulativeData,
            color: s.color,
            width: s.width,
            itemStyle: s.itemStyle,
          ),
        );
      } else {
        processedSeries.add(s);
      }
    }

    final processed = ChartDataProcessor.process(processedSeries);
    final double maxY =
        config.targetValue ??
        (processed.stats.globalMax <= 0
            ? 100.0
            : processed.stats.globalMax * 1.1);

    return Column(
      children: [
        if (config.title != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              config.title!.text ?? '',
              style: TextStyle(
                fontSize: config.title!.fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: SCurveChartPainter(
              config: config,
              processed: processed.processed,
              maxY: maxY,
              progress: _anim.progress,
            ),
          ),
        ),
      ],
    );
  }

  double? _toDouble(dynamic v) {
    return ChartDataValueReader.yValueOrNull(v);
  }
}

class SCurveChartPainter extends ChartPainterBase {
  final SCurveChartConfig config;
  final List<ProcessedSeries> processed;
  final double maxY;
  final double progress;

  SCurveChartPainter({
    required this.config,
    required this.processed,
    required this.maxY,
    required this.progress,
  }) : super(theme: config.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final int maxPoints = processed.fold(
      0,
      (m, s) => math.max(m, s.points.length),
    );
    if (maxPoints == 0) return;

    final viewport = ChartViewport.fromSize(
      size,
      theme.spacing,
      dataMinX: 0,
      dataMaxX: (maxPoints - 1).toDouble(),
      dataMinY: 0,
      dataMaxY: maxY,
    );

    final yTicks = ChartDataProcessor.niceYTicks(0, maxY, tickCount: 5);
    drawHorizontalGrid(canvas, viewport, yTicks);
    drawYAxisLabels(canvas, viewport, yTicks, (v) => v.toStringAsFixed(0));

    for (var i = 0; i < processed.length; i++) {
      final s = processed[i];
      final points = s.points;
      if (points.isEmpty) continue;

      final paint = strokePaint(
        s.series.color ?? Colors.blue,
        s.series.width ?? 2.5,
      );

      final path = Path();
      for (var j = 0; j < points.length; j++) {
        final p = points[j];
        final cp = viewport.toCanvas(j.toDouble(), p.y * progress);

        if (j == 0) {
          path.moveTo(cp.dx, cp.dy);
        } else {
          path.lineTo(cp.dx, cp.dy);
        }
      }

      canvas.drawPath(path, paint);

      // Draw end-point circle (standard for S-curves)
      if (progress >= 0.95) {
        final lastP = points.last;
        final cp = viewport.toCanvas((points.length - 1).toDouble(), lastP.y);
        canvas.drawCircle(cp, 4, fillPaint(s.series.color ?? Colors.blue));
      }
    }
  }

  @override
  bool shouldRepaintChart(covariant SCurveChartPainter old) =>
      old.progress != progress || old.config != config;
}
