import 'package:flutter/material.dart';

import '../../core/chart_data_value_reader.dart';
import '../../core/utils/helper.dart';
import 'bar_config.dart';

class StackedBarChartWidget extends StatefulWidget {
  final BarChartConfig config;

  const StackedBarChartWidget({super.key, required this.config});

  @override
  State<StackedBarChartWidget> createState() => _StackedBarChartWidgetState();
}

class _StackedBarChartWidgetState extends State<StackedBarChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  String? _tooltipText;
  Offset? _tooltipPosition;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(StackedBarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          if (widget.config.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.config.title!.text!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ),

          // Legend
          if (widget.config.legend != null)
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
            child: Stack(
              children: [
                // Chart container
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: StackedBarChartPainter(
                        config: widget.config,
                        animationValue: _animation.value,
                        onTooltipChanged: _handleTooltipChanged,
                      ),
                    );
                  },
                ),

                // Tooltip
                if (_tooltipText != null && _tooltipPosition != null)
                  Positioned(
                    left: _tooltipPosition!.dx,
                    top: _tooltipPosition!.dy,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _tooltipText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLegendItems(BuildContext context) {
    List<Widget> items = [];

    for (int i = 0; i < widget.config.series.length; i++) {
      final series = widget.config.series[i];
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getSeriesColor(i),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              series.name ?? 'Series ${i + 1}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      );
    }

    return items;
  }

  Color _getSeriesColor(int index) {
    final fallback = _defaultSeriesColor(index);
    if (index < widget.config.series.length) {
      return widget.config.series[index].color ??
          safeStringToColor(
            widget.config.series[index].itemStyle?.color,
            fallback,
          );
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

  void _handleTooltipChanged(String? text, Offset? position) {
    setState(() {
      _tooltipText = text;
      _tooltipPosition = position;
    });
  }
}

class StackedBarChartPainter extends CustomPainter {
  final BarChartConfig config;
  final double animationValue;
  final Function(String?, Offset?)? onTooltipChanged;

  // Chart layout constants
  final double _axisLabelFontSize = 12;
  //final double _axisMargin = 10;
  final double _axisLabelPadding = 5;

  StackedBarChartPainter({
    required this.config,
    required this.animationValue,
    this.onTooltipChanged,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartArea = _calculateChartArea(size);
    final barGroups = _generateBarGroups();

    _drawGrid(canvas, chartArea);
    _drawAxes(canvas, chartArea);
    _drawBars(canvas, chartArea, barGroups);
  }

  @override
  bool shouldRepaint(covariant StackedBarChartPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.animationValue != animationValue;
  }

  // Calculate the area available for the chart after accounting for axes and labels
  Rect _calculateChartArea(Size size) {
    double leftPadding = 50; // Space for Y-axis labels
    double bottomPadding = 40; // Space for X-axis labels
    double topPadding = 20; // Space at the top
    double rightPadding = 20; // Space at the right

    return Rect.fromLTRB(
      leftPadding,
      topPadding,
      size.width - rightPadding,
      size.height - bottomPadding,
    );
  }

  // Generate bar groups from series data
  List<BarGroup> _generateBarGroups() {
    // First, organize data by x-axis position
    Map<int, List<BarSegment>> groupedData = {};

    for (int i = 0; i < config.series.length; i++) {
      final series = config.series[i];
      final data = series.data;
      if (data == null) continue;

      for (int j = 0; j < data.length; j++) {
        final point = ChartDataValueReader.cartesian(data[j], j);
        if (point == null) continue;

        final x = point.x.round();
        if (!groupedData.containsKey(x)) {
          groupedData[x] = [];
        }

        groupedData[x]!.add(
          BarSegment(
            value: point.y,
            color: _getSeriesColor(i),
            seriesIndex: i,
            seriesName: series.name ?? 'Series ${i + 1}',
          ),
        );
      }
    }

    // Convert to list of BarGroup objects
    List<BarGroup> barGroups = [];
    groupedData.forEach((x, segments) {
      barGroups.add(BarGroup(x: x, segments: segments));
    });

    // Sort by x value
    barGroups.sort((a, b) => a.x.compareTo(b.x));

    return barGroups;
  }

  Color _getSeriesColor(int index) {
    final fallback = _defaultSeriesColor(index);
    if (index < config.series.length) {
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

  // Draw grid lines
  void _drawGrid(Canvas canvas, Rect chartArea) {
    if (config.grid == null) return;

    final paint = Paint()
      ..color = safeStringToColor(
        config.grid!.lineStyle.color,
        Colors.grey.shade300,
      )
      ..strokeWidth = config.grid!.lineStyle.width
      ..style = PaintingStyle.stroke;

    // Draw horizontal grid lines
    if (config.grid!.showHorizontalLines) {
      int divisions = 5; // Number of horizontal grid lines
      double step = chartArea.height / divisions;

      for (int i = 0; i <= divisions; i++) {
        double y = chartArea.top + i * step;
        canvas.drawLine(
          Offset(chartArea.left, y),
          Offset(chartArea.right, y),
          paint,
        );
      }
    }

    // Draw vertical grid lines
    if (config.grid!.showVerticalLines) {
      final categories = config.xAxis?.data ?? [];
      int divisions = categories.isEmpty ? 5 : categories.length;
      double step = chartArea.width / divisions;

      for (int i = 0; i <= divisions; i++) {
        double x = chartArea.left + i * step;
        canvas.drawLine(
          Offset(x, chartArea.top),
          Offset(x, chartArea.bottom),
          paint,
        );
      }
    }
  }

  // Draw X and Y axes
  void _drawAxes(Canvas canvas, Rect chartArea) {
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw X-axis line
    canvas.drawLine(
      Offset(chartArea.left, chartArea.bottom),
      Offset(chartArea.right, chartArea.bottom),
      axisPaint,
    );

    // Draw Y-axis line
    canvas.drawLine(
      Offset(chartArea.left, chartArea.top),
      Offset(chartArea.left, chartArea.bottom),
      axisPaint,
    );

    // Draw X-axis labels
    if (config.xAxis != null && config.xAxis!.data != null) {
      final categories = config.xAxis!.data!;
      final barGroups = _generateBarGroups();

      if (categories.isNotEmpty && barGroups.isNotEmpty) {
        double step = chartArea.width / categories.length;

        for (int i = 0; i < categories.length; i++) {
          final textSpan = TextSpan(
            text: categories[i],
            style: TextStyle(
              color: Colors.black87,
              fontSize: _axisLabelFontSize,
            ),
          );

          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          );

          textPainter.layout();

          final xPosition =
              chartArea.left + (i + 0.5) * step - textPainter.width / 2;
          final yPosition = chartArea.bottom + _axisLabelPadding;

          textPainter.paint(canvas, Offset(xPosition, yPosition));
        }
      }
    }

    // Draw Y-axis labels
    final maxY = config.maxY ?? 100;
    final divisions = 5; // Number of Y-axis labels
    final step = maxY / divisions;

    for (int i = 0; i <= divisions; i++) {
      final value = (i * step).toStringAsFixed(0);
      final textSpan = TextSpan(
        text: value,
        style: TextStyle(color: Colors.black87, fontSize: _axisLabelFontSize),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      );

      textPainter.layout();

      final xPosition = chartArea.left - textPainter.width - _axisLabelPadding;
      final yPosition =
          chartArea.bottom -
          (i / divisions) * chartArea.height -
          textPainter.height / 2;

      textPainter.paint(canvas, Offset(xPosition, yPosition));
    }
  }

  // Draw the stacked bars
  void _drawBars(Canvas canvas, Rect chartArea, List<BarGroup> barGroups) {
    if (barGroups.isEmpty) return;

    final barWidth = config.barWidth;

    // Calculate bar width and spacing
    final availableWidth = chartArea.width;
    final groupWidth = availableWidth / barGroups.length;

    for (int groupIndex = 0; groupIndex < barGroups.length; groupIndex++) {
      final group = barGroups[groupIndex];
      final xCenter = chartArea.left + groupWidth * (groupIndex + 0.5);

      double currentY = 0;
      double offsetX = xCenter - barWidth / 2;

      // Draw each segment in the stack
      for (
        int segmentIndex = 0;
        segmentIndex < group.segments.length;
        segmentIndex++
      ) {
        final segment = group.segments[segmentIndex];

        // Calculate segment height with animation
        final value = segment.value * animationValue;
        final heightRatio = value / (config.maxY ?? 100);
        final segmentHeight = chartArea.height * heightRatio;

        // Create bar rectangle
        final rect = Rect.fromLTWH(
          offsetX,
          chartArea.bottom - segmentHeight - currentY,
          barWidth,
          segmentHeight,
        );

        // Apply border radius to top segments
        RRect? roundedRect;
        if (segmentIndex == group.segments.length - 1 || segmentHeight == 0) {
          roundedRect = RRect.fromRectAndCorners(
            rect,
            topLeft: config.barBorderRadius.topLeft,
            topRight: config.barBorderRadius.topRight,
          );
        }

        // Draw the bar segment
        final paint = Paint()
          ..color = segment.color
          ..style = PaintingStyle.fill;

        if (roundedRect != null) {
          canvas.drawRRect(roundedRect, paint);
        } else {
          canvas.drawRect(rect, paint);
        }

        // Update the current Y position for the next segment
        currentY += segmentHeight;
      }
    }
  }
}

// Helper classes to organize chart data
class BarGroup {
  final int x;
  final List<BarSegment> segments;

  BarGroup({required this.x, required this.segments});
}

class BarSegment {
  final double value;
  final Color color;
  final int seriesIndex;
  final String seriesName;

  BarSegment({
    required this.value,
    required this.color,
    required this.seriesIndex,
    required this.seriesName,
  });
}
