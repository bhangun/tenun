import 'package:flutter/material.dart';
import 'package:tenun_core/core/chart_animation_system.dart';
import 'package:tenun_core/core/chart_data_processor.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'roc_curve_config.dart';

class ROCCurveChartWidget extends StatefulWidget {
  final ROCCurveChartConfig config;

  const ROCCurveChartWidget({super.key, required this.config});

  @override
  State<ROCCurveChartWidget> createState() => _ROCCurveChartWidgetState();
}

class _ROCCurveChartWidgetState extends State<ROCCurveChartWidget>
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
    final processed = ChartDataProcessor.process(config.series);

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
            painter: ROCCurveChartPainter(
              config: config,
              processed: processed.processed,
              progress: _anim.progress,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'False Positive Rate',
            style: TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}

class ROCCurveChartPainter extends ChartPainterBase {
  final ROCCurveChartConfig config;
  final List<ProcessedSeries> processed;
  final double progress;

  ROCCurveChartPainter({
    required this.config,
    required this.processed,
    required this.progress,
  }) : super(theme: config.theme);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Setup Viewport
    final viewport = ChartViewport.fromSize(
      size,
      theme.spacing,
      dataMinX: 0,
      dataMaxX: 1.0,
      dataMinY: 0,
      dataMaxY: 1.0,
    );

    // 2. Draw Grid & Axes
    final yTicks = ChartDataProcessor.niceYTicks(0, 1.0, tickCount: 5);
    drawHorizontalGrid(canvas, viewport, yTicks);
    drawYAxisLabels(canvas, viewport, yTicks, (v) => v.toStringAsFixed(1));

    // 3. Draw Chance Line (Diagonal)
    if (config.showChanceLine) {
      final p1 = viewport.toCanvas(0, 0);
      final p2 = viewport.toCanvas(1, 1);
      canvas.drawLine(p1, p2, strokePaint(config.chanceLineColor, 1.0));
    }

    // 4. Draw ROC Curves
    for (final s in processed) {
      final points = s.points;
      if (points.isEmpty) continue;

      final paint = strokePaint(
        s.series.color ?? Colors.blue,
        s.series.width ?? 2.0,
      );

      final path = Path();
      var hasPoint = false;
      final rawData = s.series.data ?? const <dynamic>[];
      for (int i = 0; i < points.length; i++) {
        // data expected as [FPR, TPR] or just TPR with implicit FPR index
        final raw = i < rawData.length ? rawData[i] : points[i].y;
        final point = _readRocPoint(raw, i, points.length);
        if (point == null) continue;

        final cp = viewport.toCanvas(point.fpr, point.tpr * progress);

        if (!hasPoint) {
          path.moveTo(cp.dx, cp.dy);
          hasPoint = true;
        } else {
          path.lineTo(cp.dx, cp.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaintChart(covariant ROCCurveChartPainter old) =>
      old.progress != progress || old.config != config;
}

({double fpr, double tpr})? _readRocPoint(Object? raw, int index, int count) {
  if (raw is List && raw.length >= 2) {
    final fpr = ChartDataValueReader.numeric(raw[0]);
    final tpr = ChartDataValueReader.numeric(raw[1]);
    if (fpr != null && tpr != null) return (fpr: fpr, tpr: tpr);
  }

  final tpr = ChartDataValueReader.yValueOrNull(raw);
  if (tpr == null) return null;
  final fpr = count <= 1 ? 0.0 : index / (count - 1);
  return (fpr: fpr, tpr: tpr);
}
