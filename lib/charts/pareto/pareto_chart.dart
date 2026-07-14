import 'package:flutter/material.dart';
import 'package:tenun_core/core/chart_animation_system.dart';
import 'package:tenun_core/core/chart_data_processor.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'pareto_config.dart';

class ParetoChartWidget extends StatefulWidget {
  final ParetoChartConfig config;

  const ParetoChartWidget({super.key, required this.config});

  @override
  State<ParetoChartWidget> createState() => _ParetoChartWidgetState();
}

class _ParetoChartWidgetState extends State<ParetoChartWidget>
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

    if (config.series.isEmpty) return const SizedBox.shrink();

    // 1. Process Data (Sort & Cumulative %)
    final mainSeries = config.series.first;
    final List<({String label, double value})> items = [];
    final labels = config.xAxis?.data ?? [];

    for (int i = 0; i < (mainSeries.data?.length ?? 0); i++) {
      items.add((
        label: i < labels.length ? labels[i].toString() : 'Item $i',
        value: _toDouble(mainSeries.data![i]) ?? 0,
      ));
    }

    if (config.autoSort) {
      items.sort((a, b) => b.value.compareTo(a.value));
    }

    final double totalSum = items.fold(0, (sum, item) => sum + item.value);
    double runningSum = 0;
    final List<double> values = [];
    final List<double> percentages = [];
    final List<String> sortedLabels = [];

    for (final item in items) {
      values.add(item.value);
      runningSum += item.value;
      percentages.add(totalSum > 0 ? (runningSum / totalSum) : 0);
      sortedLabels.add(item.label);
    }

    final double maxVal = values.isEmpty ? 100 : values.first * 1.1;

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
            painter: ParetoChartPainter(
              config: config,
              values: values,
              percentages: percentages,
              labels: sortedLabels,
              maxVal: maxVal,
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

class ParetoChartPainter extends ChartPainterBase {
  final ParetoChartConfig config;
  final List<double> values;
  final List<double> percentages;
  final List<String> labels;
  final double maxVal;
  final double progress;

  ParetoChartPainter({
    required this.config,
    required this.values,
    required this.percentages,
    required this.labels,
    required this.maxVal,
    required this.progress,
  }) : super(theme: config.theme);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final viewport = ChartViewport.fromSize(
      size,
      theme.spacing,
      dataMinX: 0,
      dataMaxX: values.length.toDouble(),
      dataMinY: 0,
      dataMaxY: maxVal,
    );

    final yTicks = ChartDataProcessor.niceYTicks(0, maxVal, tickCount: 5);
    drawHorizontalGrid(canvas, viewport, yTicks);
    drawYAxisLabels(canvas, viewport, yTicks, (v) => v.toStringAsFixed(0));

    // Draw Bars
    final barPaint = fillPaint(config.series.first.color ?? Colors.blue);
    final double stepX = viewport.width / values.length;
    final double barWidth = stepX * 0.7;

    for (int i = 0; i < values.length; i++) {
      final double val = values[i];
      final double x = viewport.left + i * stepX + (stepX - barWidth) / 2;
      final double h = (val / maxVal) * viewport.height * progress;
      final double y = viewport.bottom - h;

      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, h), barPaint);
    }

    // Draw Cumulative Percentage Line (0-100%)
    final linePaint = strokePaint(config.lineIndicatorColor, 2.0);
    final dotPaint = fillPaint(config.lineIndicatorColor);
    final path = Path();

    for (int i = 0; i < percentages.length; i++) {
      final double x = viewport.left + i * stepX + stepX / 2;
      // Percentages are 0..1, map to height
      final double y =
          viewport.bottom - (percentages[i] * viewport.height * progress);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      if (progress >= 0.8) {
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaintChart(covariant ParetoChartPainter old) =>
      old.progress != progress || old.config != config;
}
