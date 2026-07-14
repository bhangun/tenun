// Custom painter for the scatter chart
import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/utils/helper.dart';
import 'scatter_config.dart';

class ScatterChartPainter extends CustomPainter {
  final ScatterChartConfig config;
  final int selectedPointIndex;

  ScatterChartPainter({required this.config, required this.selectedPointIndex});

  @override
  void paint(Canvas canvas, Size size) {
    int pointIndex = 0;

    for (
      int seriesIndex = 0;
      seriesIndex < config.series.length;
      seriesIndex++
    ) {
      final series = config.series[seriesIndex];
      final data = series.data;
      if (data != null) {
        for (int dataIndex = 0; dataIndex < data.length; dataIndex++) {
          final point = ChartDataValueReader.cartesian(
            data[dataIndex],
            dataIndex,
          );
          if (point == null) continue;

          // Map data coordinates to pixel coordinates
          final pixelX = _mapX(point.x, size.width);
          final pixelY = _mapY(point.y, size.height);

          // Draw point
          final color =
              series.color ??
              safeStringToColor(
                series.itemStyle?.color,
                getDefaultSeriesColor(seriesIndex),
              );
          final Paint paint = Paint()
            ..color = pointIndex == selectedPointIndex ? Colors.white : color
            ..style = PaintingStyle.fill;

          final Paint borderPaint = Paint()
            ..color = pointIndex == selectedPointIndex
                ? color
                : color.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = pointIndex == selectedPointIndex ? 2 : 1;

          final radius = pointIndex == selectedPointIndex
              ? config.dotSize * 1.5
              : config.dotSize;

          canvas.drawCircle(Offset(pixelX, pixelY), radius, paint);
          canvas.drawCircle(Offset(pixelX, pixelY), radius, borderPaint);

          pointIndex++;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScatterChartPainter oldDelegate) {
    return oldDelegate.selectedPointIndex != selectedPointIndex ||
        oldDelegate.config.minX != config.minX ||
        oldDelegate.config.maxX != config.maxX ||
        oldDelegate.config.minY != config.minY ||
        oldDelegate.config.maxY != config.maxY ||
        oldDelegate.config.dotSize != config.dotSize ||
        oldDelegate.config.series != config.series;
  }

  double _mapX(double value, double width) {
    final span = config.maxX - config.minX;
    if (!span.isFinite || span <= 0) return width / 2;
    return (((value - config.minX) / span).clamp(0.0, 1.0) * width).toDouble();
  }

  double _mapY(double value, double height) {
    final span = config.maxY - config.minY;
    if (!span.isFinite || span <= 0) return height / 2;
    return (height - (((value - config.minY) / span).clamp(0.0, 1.0) * height))
        .toDouble();
  }
}
