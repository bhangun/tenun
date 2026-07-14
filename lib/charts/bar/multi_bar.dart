import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/utils/helper.dart';
import 'bar_config.dart';

class MultiBarChartWidget extends StatelessWidget {
  final BarChartConfig config;

  const MultiBarChartWidget({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          if (config.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                config.title!.text!,
                style: TextStyle(
                  fontSize: config.title!.fontSize ?? 16,
                  fontWeight: FontWeight.bold,
                  color: config.title!.color,
                ),
              ),
            ),

          // Legend
          if (config.legend != null && config.legend!.show)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: _buildLegendItems(context),
              ),
            ),

          // Chart
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: MultiBarChartPainter(config: config),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLegendItems(BuildContext context) {
    List<Widget> items = [];

    for (int i = 0; i < config.series.length; i++) {
      final series = config.series[i];
      final color =
          series.color ??
          safeStringToColor(series.itemStyle?.color, _getSeriesColor(i));

      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              series.name ?? 'Series ${i + 1}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }

    return items;
  }

  Color _getSeriesColor(int index) {
    final defaultColors = [
      const Color(0xFF5470C6),
      const Color(0xFF91CC75),
      const Color(0xFFFAC858),
      const Color(0xFFEE6666),
      const Color(0xFF73C0DE),
      const Color(0xFF3BA272),
      const Color(0xFFFC8452),
      const Color(0xFF9A60B4),
      const Color(0xFFEA7CCC),
    ];

    return defaultColors[index % defaultColors.length];
  }
}

class MultiBarChartPainter extends CustomPainter {
  final BarChartConfig config;
  final String _configSignature;

  MultiBarChartPainter({required this.config})
    : _configSignature = ChartDataSignature.fromConfig(config).hash;

  @override
  void paint(Canvas canvas, Size size) {
    if (config.series.isEmpty) return;

    final double chartWidth = size.width - 60;
    final double chartHeight = size.height - 40;
    final double maxY = config.maxY ?? _calculateMaxY();

    // Group data by x-axis value
    Map<int, List<MapEntry<int, double>>> groupedData = {};

    for (
      int seriesIndex = 0;
      seriesIndex < config.series.length;
      seriesIndex++
    ) {
      final series = config.series[seriesIndex];
      if (series.data == null) continue;

      for (int i = 0; i < series.data!.length; i++) {
        final point = ChartDataValueReader.cartesian(series.data![i], i);
        if (point == null) continue;

        final xValue = point.x.round();
        groupedData.putIfAbsent(xValue, () => []);
        groupedData[xValue]!.add(MapEntry(seriesIndex, point.y));
      }
    }

    // Draw grid
    _drawGrid(canvas, size, maxY);

    // Draw axes
    _drawAxes(canvas, size);

    final sortedXValues = groupedData.keys.toList()..sort();
    if (sortedXValues.isEmpty) {
      _drawYAxisLabels(canvas, size, maxY);
      return;
    }

    final groupWidth = chartWidth / sortedXValues.length;
    final barsSpace = 4.0;
    final availableBarWidth =
        (groupWidth - barsSpace * (config.series.length - 1)) /
        config.series.length;

    // Draw bars
    for (int i = 0; i < sortedXValues.length; i++) {
      final xValue = sortedXValues[i];
      final xPosition = 50 + i * groupWidth + barsSpace / 2;
      final bars = groupedData[xValue]!;

      for (int seriesIndex = 0; seriesIndex < bars.length; seriesIndex++) {
        final barEntry = bars[seriesIndex];
        final barHeight = (barEntry.value / maxY) * chartHeight;
        final color = _getSeriesColor(barEntry.key);

        final barX = xPosition + seriesIndex * (availableBarWidth + barsSpace);
        final barY = size.height - 20 - barHeight;

        final barPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;

        final barRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, availableBarWidth, barHeight),
          config.barBorderRadiusValue != null &&
                  config.barBorderRadiusValue! > 0
              ? Radius.circular(config.barBorderRadiusValue!)
              : Radius.zero,
        );

        canvas.drawRRect(barRect, barPaint);
      }
    }

    // Draw axis labels
    _drawXAxisLabels(canvas, size, sortedXValues, groupWidth);
    _drawYAxisLabels(canvas, size, maxY);
  }

  double _calculateMaxY() {
    double max = 0;
    for (final series in config.series) {
      if (series.data != null) {
        for (final item in series.data!) {
          final value = ChartDataValueReader.yValueOrNull(item);
          if (value != null && value > max) max = value;
        }
      }
    }
    return max <= 0 ? 100 : max * 1.2;
  }

  Color _getSeriesColor(int index) {
    final fallback = _defaultSeriesColor(index);
    if (index < config.series.length &&
        config.series[index].itemStyle != null) {
      return config.series[index].color ??
          safeStringToColor(config.series[index].itemStyle?.color, fallback);
    }

    return fallback;
  }

  Color _defaultSeriesColor(int index) {
    final defaultColors = [
      const Color(0xFF5470C6),
      const Color(0xFF91CC75),
      const Color(0xFFFAC858),
      const Color(0xFFEE6666),
      const Color(0xFF73C0DE),
      const Color(0xFF3BA272),
      const Color(0xFFFC8452),
      const Color(0xFF9A60B4),
      const Color(0xFFEA7CCC),
    ];

    return defaultColors[index % defaultColors.length];
  }

  void _drawGrid(Canvas canvas, Size size, double maxY) {
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
    List<int> xValues,
    double groupWidth,
  ) {
    for (int i = 0; i < xValues.length; i++) {
      final label = xValues[i].toString();

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      final x = 50 + i * groupWidth + groupWidth / 2 - textPainter.width / 2;
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
  bool shouldRepaint(covariant MultiBarChartPainter oldDelegate) {
    return oldDelegate._configSignature != _configSignature;
  }
}
