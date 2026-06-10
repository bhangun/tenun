import 'package:flutter/material.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_cache.dart';
import 'confusion_matrix_config.dart';

class ConfusionMatrixChartWidget extends StatelessWidget {
  final ConfusionMatrixChartConfig config;

  const ConfusionMatrixChartWidget({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
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
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Predicted',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              const RotatedBox(
                quarterTurns: 3,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Actual',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: ConfusionMatrixPainter(config: config),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ConfusionMatrixPainter extends ChartPainterBase {
  final ConfusionMatrixChartConfig config;

  ConfusionMatrixPainter({required this.config}) : super(theme: config.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final n = config.labels.length;
    if (n == 0) return;

    final cellW = size.width / n;
    final cellH = size.height / n;

    // 1. Calculate max value for color normalization
    int maxVal = 0;
    for (final row in config.data) {
      for (final val in row) {
        if (val > maxVal) maxVal = val;
      }
    }

    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: (cellH * 0.15).clamp(8.0, 14.0),
      fontWeight: FontWeight.bold,
    );

    for (int i = 0; i < n; i++) {
      // Rows (Actual)
      for (int j = 0; j < n; j++) {
        // Columns (Predicted)
        final val = config.data[i][j];
        final rect = Rect.fromLTWH(j * cellW, i * cellH, cellW, cellH);

        // Use opacity based on value relative to max
        final opacity = maxVal > 0 ? (val / maxVal).clamp(0.05, 1.0) : 0.05;
        final paint = fillPaintMutable(
          config.baseColor.withValues(alpha: opacity),
        );

        canvas.drawRect(rect, paint);
        canvas.drawRect(rect, strokePaint(Colors.white24, 1.0));

        // Draw Value Text
        final textPainter = textPainterCache.get(
          '$val',
          textStyle.copyWith(
            color: opacity > 0.5 ? Colors.white : Colors.black87,
          ),
        );

        textPainter.paint(
          canvas,
          Offset(
            rect.center.dx - textPainter.width / 2,
            rect.center.dy - textPainter.height / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaintChart(covariant ConfusionMatrixPainter old) =>
      old.config != config;
}
