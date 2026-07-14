import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_animation_system.dart';
import 'package:tenun_core/core/chart_controller.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_data_processor.dart';
import 'package:tenun_core/core/zoom/chart_zoom_viewport.dart';
import 'package:tenun_core/core/utils/helper.dart';
import 'line_config.dart';

class LineChartWidget extends StatefulWidget {
  final LineChartConfig config;

  const LineChartWidget({super.key, required this.config});

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget>
    with SingleTickerProviderStateMixin {
  late final ChartAnimationController _anim;
  late String _configSignature;

  @override
  void initState() {
    super.initState();
    _configSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _anim = ChartAnimationController(
      vsync: this,
      preset: ChartAnimationPreset.draw,
    );
    _anim.addListener(() => setState(() {}));
    _anim.forward();
  }

  @override
  void didUpdateWidget(covariant LineChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    if (nextSignature != _configSignature) {
      _configSignature = nextSignature;
      _anim.replay();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final totalLength = config.series.fold<int>(
      0,
      (max, s) => (s.data?.length ?? 0) > max ? (s.data?.length ?? 0) : max,
    );
    final visibleRange = (config.controller?.zoom ?? ZoomRange.full)
        .visibleIndexRange(totalLength);
    final startIndex = visibleRange.start;
    final endIndex = visibleRange.end;
    final processed = ChartDataProcessor.process(
      config.series,
      startIndex: startIndex,
      endIndex: endIndex,
      renderThreshold: 300,
    );
    final double maxY = config.maxY > 0
        ? config.maxY
        : (processed.stats.globalMax <= 0
              ? 100.0
              : processed.stats.globalMax * 1.2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.title != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              config.title!.text!,
              style: TextStyle(
                fontSize: config.title!.fontSize,
                fontWeight: FontWeight.bold,
                color: config.title!.color,
              ),
            ),
          ),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: LineChartPainter(
              config: config,
              maxY: maxY,
              startIndex: startIndex,
              endIndex: endIndex,
              progress: _anim.progress,
              configSignature: _configSignature,
            ),
          ),
        ),
        if (config.legend != null)
          Padding(padding: const EdgeInsets.all(8.0), child: _createLegend()),
      ],
    );
  }

  Widget _createLegend() {
    final config = widget.config;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: config.series.map((series) {
        final color =
            series.color ??
            getDefaultSeriesColor(config.series.indexOf(series));
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              series.name ?? '',
              style: TextStyle(
                color: safeStringToColor(
                  config.legend?.textColor ?? '#000000',
                  Colors.black,
                ),
                fontSize: config.legend?.fontSize ?? 12,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final LineChartConfig config;
  final double maxY;
  final int startIndex;
  final int endIndex;
  final double progress;
  final String _configSignature;

  LineChartPainter({
    required this.config,
    required this.maxY,
    required this.startIndex,
    required this.endIndex,
    required this.progress,
    String? configSignature,
  }) : _configSignature =
           configSignature ?? ChartDataSignature.fromConfig(config).hash;

  @override
  void paint(Canvas canvas, Size size) {
    if (config.series.isEmpty) return;

    final int visibleCount = (endIndex - startIndex + 1).clamp(1, 1 << 20);
    final viewport = ChartZoomViewport(
      left: 50,
      top: 0,
      right: size.width - 10,
      bottom: size.height - 20,
      dataMinY: 0,
      dataMaxY: maxY,
      dataLength: visibleCount,
    );

    // Draw grid
    _drawGrid(canvas, size, viewport);

    // Draw axes
    _drawAxes(canvas, size);

    // Draw each series
    for (int i = 0; i < config.series.length; i++) {
      final series = config.series[i];
      if (series.data == null || series.data!.isEmpty) continue;

      final color = series.color ?? getDefaultSeriesColor(i);

      // Create path for the line
      final path = Path();
      final List<Offset> points = [];

      for (int j = startIndex; j <= endIndex && j < series.data!.length; j++) {
        final value = ChartDataValueReader.yValue(series.data![j]);
        final x = viewport.indexToCanvasX(j - startIndex);
        final y = viewport.dataYToCanvasY(value * progress);
        points.add(Offset(x, y));
      }

      if (points.isNotEmpty) {
        path.moveTo(points.first.dx, points.first.dy);

        if (config.curveSmoothness > 0 && points.length > 1) {
          // Draw curved line
          for (int j = 0; j < points.length - 1; j++) {
            final current = points[j];
            final next = points[j + 1];
            final distance = (next.dx - current.dx) * config.curveSmoothness;

            final cp1 = Offset(current.dx + distance, current.dy);
            final cp2 = Offset(next.dx - distance, next.dy);

            path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
          }
        } else {
          // Draw straight line
          for (int j = 1; j < points.length; j++) {
            path.lineTo(points[j].dx, points[j].dy);
          }
        }

        // Draw the line
        final linePaint = Paint()
          ..color = color
          ..strokeWidth = series.width ?? 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawPath(path, linePaint);

        // Draw area below line if enabled
        if (config.showBelowArea) {
          final areaPath = Path();
          areaPath.moveTo(points.first.dx, size.height - 20);
          areaPath.lineTo(points.first.dx, points.first.dy);

          // Follow the line path
          areaPath.addPath(path, Offset.zero);

          areaPath.lineTo(points.last.dx, size.height - 20);
          areaPath.close();

          final areaPaint = Paint()
            ..color = color.withValues(alpha: 0.2)
            ..style = PaintingStyle.fill;

          canvas.drawPath(areaPath, areaPaint);
        }

        // Draw dots if enabled
        if (config.showDots) {
          for (final point in points) {
            final dotPaint = Paint()
              ..color = color
              ..style = PaintingStyle.fill;

            canvas.drawCircle(point, config.dotSize / 2, dotPaint);

            // White outline
            final outlinePaint = Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1;

            canvas.drawCircle(point, config.dotSize / 2, outlinePaint);
          }
        }
      }
    }

    // Draw axis labels
    _drawXAxisLabels(canvas, size, startIndex, endIndex, viewport);
    _drawYAxisLabels(canvas, size, maxY);
  }

  void _drawGrid(Canvas canvas, Size size, ChartZoomViewport viewport) {
    if (config.grid?.show != true) return;

    final gridPaint = Paint()
      ..color = safeStringToColor(
        config.grid?.horizontalColor ?? '#e0e0e0',
        Colors.grey.shade300,
      )
      ..strokeWidth = config.grid?.horizontalWidth ?? 0.5
      ..style = PaintingStyle.stroke;

    if (config.grid?.showHorizontalLines ?? true) {
      const divisions = 5;
      for (int i = 0; i <= divisions; i++) {
        final y = (i / divisions) * (size.height - 40);
        canvas.drawLine(Offset(50, y), Offset(size.width - 10, y), gridPaint);
      }
    }

    if (config.grid?.showVerticalLines ?? false) {
      final visibleCount = (endIndex - startIndex + 1).clamp(1, 1 << 20);
      if (visibleCount > 0) {
        for (int i = startIndex; i <= endIndex; i++) {
          final x = viewport.indexToCanvasX(i - startIndex);
          canvas.drawLine(Offset(x, 0), Offset(x, size.height - 20), gridPaint);
        }
      }
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(50, size.height - 20),
      Offset(size.width - 10, size.height - 20),
      axisPaint,
    );
    canvas.drawLine(Offset(50, 0), Offset(50, size.height - 20), axisPaint);
  }

  void _drawXAxisLabels(
    Canvas canvas,
    Size size,
    int startIndex,
    int endIndex,
    ChartZoomViewport viewport,
  ) {
    if (config.series.isEmpty || config.series.first.data == null) return;

    final dataLength = config.series.first.data!.length;
    if (dataLength == 0) return;
    final visibleCount = (endIndex - startIndex + 1).clamp(1, dataLength);
    final step = visibleCount > 8 ? (visibleCount / 8).ceil() : 1;

    for (int i = startIndex; i <= endIndex; i += step) {
      String label;

      if (config.xAxis?.data != null && i < config.xAxis!.data!.length) {
        label = config.xAxis!.data![i].toString();
      } else if (config.series.first.dataLabels != null &&
          i < config.series.first.dataLabels!.length) {
        label = config.series.first.dataLabels![i].toString();
      } else {
        label = i.toString();
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: safeStringToColor(
              config.xAxis?.color ?? '#000000',
              Colors.black,
            ),
            fontSize: config.xAxis?.fontSize ?? 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      final x = viewport.indexToCanvasX(i - startIndex) - textPainter.width / 2;
      textPainter.paint(canvas, Offset(x, size.height - 15));
    }
  }

  void _drawYAxisLabels(Canvas canvas, Size size, double maxY) {
    const divisions = 5;
    for (int i = 0; i <= divisions; i++) {
      final value = (maxY * i / divisions).toStringAsFixed(0);
      final y = (size.height - 20) - (i / divisions) * (size.height - 40);

      final textPainter = TextPainter(
        text: TextSpan(
          text: value,
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(5 - textPainter.width, y - 6));
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate._configSignature != _configSignature ||
        oldDelegate.maxY != maxY ||
        oldDelegate.startIndex != startIndex ||
        oldDelegate.endIndex != endIndex ||
        oldDelegate.progress != progress;
  }
}
