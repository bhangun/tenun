import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

main() {
  runApp(MaterialApp(home: WaterfallChart(data: [])));
}

class WaterfallChart extends StatefulWidget {
  final List<WaterfallData> data;
  final double width;
  final double height;
  final Color positiveColor;
  final Color negativeColor;
  final Color totalColor;
  final Color backgroundColor;
  final Color gridColor;
  final Color axisColor;
  final TextStyle? labelTextStyle;
  final TextStyle? valueTextStyle;
  final TextStyle? axisTextStyle;
  final TextStyle? tooltipTextStyle;
  final bool showValues;
  final bool showConnectors;
  final bool showGrid;
  final bool showAxis;
  final bool enableInteraction;
  final bool enableTooltips;
  final bool enableAnimation;
  final Duration animationDuration;
  final Function(WaterfallData, int)? onBarTap;
  final Function(WaterfallData, int)? onBarHover;
  final String? title;
  final String? subtitle;
  final String yAxisLabel;
  final String xAxisLabel;
  final double borderRadius;
  final double barSpacingRatio;
  final int gridLineCount;
  final bool showLegend;
  final bool exportable;

  const WaterfallChart({
    Key? key,
    required this.data,
    this.width = 400,
    this.height = 300,
    this.positiveColor = const Color(0xFF10B981),
    this.negativeColor = const Color(0xFFEF4444),
    this.totalColor = const Color(0xFF3B82F6),
    this.backgroundColor = Colors.transparent,
    this.gridColor = const Color(0xFFE5E7EB),
    this.axisColor = const Color(0xFF6B7280),
    this.labelTextStyle,
    this.valueTextStyle,
    this.axisTextStyle,
    this.tooltipTextStyle,
    this.showValues = true,
    this.showConnectors = true,
    this.showGrid = true,
    this.showAxis = true,
    this.enableInteraction = true,
    this.enableTooltips = true,
    this.enableAnimation = true,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.onBarTap,
    this.onBarHover,
    this.title,
    this.subtitle,
    this.yAxisLabel = 'Value',
    this.xAxisLabel = 'Categories',
    this.borderRadius = 4.0,
    this.barSpacingRatio = 0.3,
    this.gridLineCount = 5,
    this.showLegend = true,
    this.exportable = false,
  }) : super(key: key);

  @override
  _WaterfallChartState createState() => _WaterfallChartState();
}

class _WaterfallChartState extends State<WaterfallChart>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _hoverAnimationController;
  late Animation<double> _animation;
  late Animation<double> _hoverAnimation;

  int? _hoveredIndex;
  int? _selectedIndex;
  Offset? _tooltipPosition;
  OverlayEntry? _tooltipOverlay;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _hoverAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverAnimationController,
      curve: Curves.easeOut,
    );

    if (widget.enableAnimation) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _removeTooltip();
    _animationController.dispose();
    _hoverAnimationController.dispose();
    super.dispose();
  }

  void _showTooltip(Offset position, WaterfallData data, int index) {
    if (!widget.enableTooltips) return;

    _removeTooltip();

    _tooltipOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx - 60,
        top: position.dy - 80,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style:
                      widget.tooltipTextStyle?.copyWith(color: Colors.white) ??
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatValue(data.value),
                  style:
                      widget.tooltipTextStyle?.copyWith(
                        color: Colors.white70,
                      ) ??
                      const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                if (data.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    data.description!,
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_tooltipOverlay!);
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  void _handleTapDown(TapDownDetails details, int index) {
    if (!widget.enableInteraction) return;

    setState(() {
      _selectedIndex = index;
    });

    if (widget.onBarTap != null) {
      widget.onBarTap!(widget.data[index], index);
    }

    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _handleHover(Offset position, int index, bool isHovering) {
    if (!widget.enableInteraction) return;

    setState(() {
      _hoveredIndex = isHovering ? index : null;
    });

    if (isHovering) {
      _showTooltip(position, widget.data[index], index);
      _hoverAnimationController.forward();
      if (widget.onBarHover != null) {
        widget.onBarHover!(widget.data[index], index);
      }
    } else {
      _removeTooltip();
      _hoverAnimationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null || widget.subtitle != null) _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_animation, _hoverAnimation]),
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(widget.width, widget.height),
                        painter: EnhancedWaterfallPainter(
                          data: widget.data,
                          positiveColor: widget.positiveColor,
                          negativeColor: widget.negativeColor,
                          totalColor: widget.totalColor,
                          gridColor: widget.gridColor,
                          axisColor: widget.axisColor,
                          labelTextStyle:
                              widget.labelTextStyle ??
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                          valueTextStyle:
                              widget.valueTextStyle ??
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[800],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                          axisTextStyle:
                              widget.axisTextStyle ??
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                          showValues: widget.showValues,
                          showConnectors: widget.showConnectors,
                          showGrid: widget.showGrid,
                          showAxis: widget.showAxis,
                          animationProgress: _animation.value,
                          hoveredIndex: _hoveredIndex,
                          selectedIndex: _selectedIndex,
                          hoverProgress: _hoverAnimation.value,
                          yAxisLabel: widget.yAxisLabel,
                          xAxisLabel: widget.xAxisLabel,
                          borderRadius: widget.borderRadius,
                          barSpacingRatio: widget.barSpacingRatio,
                          gridLineCount: widget.gridLineCount,
                          hasHeader:
                              widget.title != null || widget.subtitle != null,
                          hasLegend: widget.showLegend,
                        ),
                      );
                    },
                  ),
                  if (widget.enableInteraction) _buildInteractionLayer(),
                ],
              ),
            ),
            if (widget.showLegend) _buildLegend(),
            if (widget.exportable) _buildExportButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null)
            Text(
              widget.title!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractionLayer() {
    return Positioned.fill(
      child: MouseRegion(
        onHover: (event) {
          // Calculate which bar is being hovered
          final barIndex = _getBarIndexFromPosition(event.localPosition);
          if (barIndex != null && barIndex != _hoveredIndex) {
            _handleHover(event.position, barIndex, true);
          } else if (barIndex == null && _hoveredIndex != null) {
            _handleHover(event.position, _hoveredIndex!, false);
          }
        },
        onExit: (event) {
          if (_hoveredIndex != null) {
            _handleHover(event.position, _hoveredIndex!, false);
          }
        },
        child: GestureDetector(
          onTapDown: (details) {
            final barIndex = _getBarIndexFromPosition(details.localPosition);
            if (barIndex != null) {
              _handleTapDown(details, barIndex);
            }
          },
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  int? _getBarIndexFromPosition(Offset position) {
    if (widget.data.isEmpty) return null;

    const padding = EdgeInsets.fromLTRB(60, 40, 40, 80);
    final chartWidth = widget.width - padding.horizontal;
    final totalSpacing = chartWidth / widget.data.length;
    final barWidth = totalSpacing * (1 - widget.barSpacingRatio);

    final x = position.dx - padding.left;
    if (x < 0 || x > chartWidth) return null;

    final index = (x / totalSpacing).floor();
    if (index >= 0 && index < widget.data.length) {
      final barStart =
          index * totalSpacing + totalSpacing * widget.barSpacingRatio / 2;
      final barEnd = barStart + barWidth;

      if (x >= barStart && x <= barEnd) {
        return index;
      }
    }

    return null;
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('Positive', widget.positiveColor),
          const SizedBox(width: 20),
          _buildLegendItem('Negative', widget.negativeColor),
          const SizedBox(width: 20),
          _buildLegendItem('Total', widget.totalColor),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // Export functionality would be implemented here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export feature coming soon!')),
              );
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[100],
              foregroundColor: Colors.grey[700],
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}

class WaterfallData {
  final String label;
  final double value;
  final bool isTotal;
  final String? description;
  final Color? customColor;
  final IconData? icon;

  WaterfallData({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.description,
    this.customColor,
    this.icon,
  });
}

class EnhancedWaterfallPainter extends CustomPainter {
  final List<WaterfallData> data;
  final Color positiveColor;
  final Color negativeColor;
  final Color totalColor;
  final Color gridColor;
  final Color axisColor;
  final TextStyle? labelTextStyle;
  final TextStyle? valueTextStyle;
  final TextStyle? axisTextStyle;
  final bool showValues;
  final bool showConnectors;
  final bool showGrid;
  final bool showAxis;
  final double animationProgress;
  final int? hoveredIndex;
  final int? selectedIndex;
  final double hoverProgress;
  final String yAxisLabel;
  final String xAxisLabel;
  final double borderRadius;
  final double barSpacingRatio;
  final int gridLineCount;
  final bool hasHeader;
  final bool hasLegend;

  EnhancedWaterfallPainter({
    required this.data,
    required this.positiveColor,
    required this.negativeColor,
    required this.totalColor,
    required this.gridColor,
    required this.axisColor,
    this.labelTextStyle,
    this.valueTextStyle,
    this.axisTextStyle,
    required this.showValues,
    required this.showConnectors,
    required this.showGrid,
    required this.showAxis,
    required this.animationProgress,
    this.hoveredIndex,
    this.selectedIndex,
    required this.hoverProgress,
    required this.yAxisLabel,
    required this.xAxisLabel,
    required this.borderRadius,
    required this.barSpacingRatio,
    required this.gridLineCount,
    required this.hasHeader,
    required this.hasLegend,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final padding = EdgeInsets.fromLTRB(
      60,
      hasHeader ? 20 : 40,
      40,
      hasLegend ? 60 : 80,
    );
    final chartWidth = size.width - padding.horizontal;
    final chartHeight = size.height - padding.vertical;
    final totalSpacing = chartWidth / data.length;
    final barWidth = totalSpacing * (1 - barSpacingRatio);

    // Calculate running total and find min/max values
    double runningTotal = 0;
    double minValue = 0;
    double maxValue = 0;
    List<double> runningTotals = [];

    for (int i = 0; i < data.length; i++) {
      if (data[i].isTotal) {
        runningTotal = data[i].value;
      } else {
        runningTotal += data[i].value;
      }
      runningTotals.add(runningTotal);

      if (data[i].value > 0) {
        maxValue = math.max(maxValue, runningTotal);
        minValue = math.min(minValue, runningTotal - data[i].value);
      } else {
        maxValue = math.max(maxValue, runningTotal - data[i].value);
        minValue = math.min(minValue, runningTotal);
      }
    }

    final valueRange = maxValue - minValue;
    if (valueRange == 0) return;

    // Add padding to value range for better visualization
    final paddedMin = minValue - valueRange * 0.1;
    final paddedMax = maxValue + valueRange * 0.1;
    final paddedRange = paddedMax - paddedMin;

    // Draw grid lines
    if (showGrid) {
      _drawGridLines(canvas, size, padding, chartHeight, paddedMin, paddedMax);
    }

    // Draw axes
    if (showAxis) {
      _drawAxes(canvas, size, padding, chartHeight, paddedMin, paddedMax);
    }

    // Paint bars
    for (int i = 0; i < data.length; i++) {
      final barLeft =
          padding.left + i * totalSpacing + totalSpacing * barSpacingRatio / 2;
      final currentValue = data[i].value * animationProgress;
      final currentRunningTotal = i > 0
          ? runningTotals[i - 1] + currentValue
          : currentValue;

      Color barColor =
          data[i].customColor ??
          (data[i].isTotal
              ? totalColor
              : (currentValue >= 0 ? positiveColor : negativeColor));

      // Apply hover/selection effects
      if (i == hoveredIndex) {
        barColor =
            Color.lerp(barColor, Colors.white, 0.2 * hoverProgress) ?? barColor;
      }
      if (i == selectedIndex) {
        barColor = Color.lerp(barColor, Colors.black, 0.1) ?? barColor;
      }

      double barTop, barBottom;
      if (data[i].isTotal) {
        barTop =
            padding.top +
            (paddedMax - currentRunningTotal) / paddedRange * chartHeight;
        barBottom =
            padding.top + (paddedMax - paddedMin) / paddedRange * chartHeight;
      } else if (currentValue >= 0) {
        final prevTotal = i > 0 ? runningTotals[i - 1] : paddedMin;
        barTop =
            padding.top +
            (paddedMax - currentRunningTotal) / paddedRange * chartHeight;
        barBottom =
            padding.top + (paddedMax - prevTotal) / paddedRange * chartHeight;
      } else {
        final prevTotal = i > 0 ? runningTotals[i - 1] : paddedMin;
        barTop =
            padding.top + (paddedMax - prevTotal) / paddedRange * chartHeight;
        barBottom =
            padding.top +
            (paddedMax - currentRunningTotal) / paddedRange * chartHeight;
      }

      // Add hover scaling effect
      double hoverScale = 1.0;
      if (i == hoveredIndex) {
        hoverScale = 1.0 + (0.05 * hoverProgress);
      }

      final scaledBarWidth = barWidth * hoverScale;
      final barCenterX = barLeft + barWidth / 2;
      final scaledBarLeft = barCenterX - scaledBarWidth / 2;

      // Draw bar with enhanced styling
      final barRect = RRect.fromLTRBR(
        scaledBarLeft,
        barTop,
        scaledBarLeft + scaledBarWidth,
        barBottom,
        Radius.circular(borderRadius),
      );

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [barColor, barColor.withValues(alpha: 0.8)],
      );

      final barPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTRB(
            scaledBarLeft,
            barTop,
            scaledBarLeft + scaledBarWidth,
            barBottom,
          ),
        );

      canvas.drawRRect(barRect, barPaint);

      // Draw bar border with glow effect for hovered/selected bars
      final borderPaint = Paint()
        ..color = i == hoveredIndex || i == selectedIndex
            ? barColor.withValues(alpha: 0.8)
            : barColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == hoveredIndex || i == selectedIndex ? 2 : 1;

      canvas.drawRRect(barRect, borderPaint);

      // Draw connectors with enhanced styling
      if (showConnectors && i > 0 && !data[i].isTotal) {
        _drawConnector(
          canvas,
          i,
          barLeft,
          runningTotals,
          padding,
          chartHeight,
          paddedMin,
          paddedMax,
          paddedRange,
        );
      }

      // Draw value labels
      if (showValues) {
        _drawValueLabel(canvas, data[i].value, barLeft, barWidth, barTop);
      }

      // Draw category labels
      _drawCategoryLabel(
        canvas,
        data[i].label,
        barLeft,
        barWidth,
        size.height - padding.bottom,
      );

      // Draw icons if available
      if (data[i].icon != null) {
        _drawIcon(
          canvas,
          data[i].icon!,
          barLeft,
          barWidth,
          barTop - 30,
          barColor,
        );
      }
    }

    // Draw baseline
    final baselineY =
        padding.top + (paddedMax - paddedMin) / paddedRange * chartHeight;
    final baselinePaint = Paint()
      ..color = axisColor.withValues(alpha: 0.8 * animationProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(padding.left, baselineY),
      Offset(size.width - padding.right, baselineY),
      baselinePaint,
    );
  }

  void _drawGridLines(
    Canvas canvas,
    Size size,
    EdgeInsets padding,
    double chartHeight,
    double paddedMin,
    double paddedMax,
  ) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5 * animationProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i <= gridLineCount; i++) {
      final y = padding.top + (i / gridLineCount) * chartHeight;
      canvas.drawLine(
        Offset(padding.left, y),
        Offset(size.width - padding.right, y),
        gridPaint,
      );
    }
  }

  void _drawAxes(
    Canvas canvas,
    Size size,
    EdgeInsets padding,
    double chartHeight,
    double paddedMin,
    double paddedMax,
  ) {
    final axisPaint = Paint()
      ..color = axisColor.withValues(alpha: animationProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Y-axis
    canvas.drawLine(
      Offset(padding.left, padding.top),
      Offset(padding.left, size.height - padding.bottom),
      axisPaint,
    );

    // X-axis
    canvas.drawLine(
      Offset(padding.left, size.height - padding.bottom),
      Offset(size.width - padding.right, size.height - padding.bottom),
      axisPaint,
    );

    // Y-axis labels
    final paddedRange = paddedMax - paddedMin;
    for (int i = 0; i <= gridLineCount; i++) {
      final value = paddedMax - (i / gridLineCount) * paddedRange;
      final y = padding.top + (i / gridLineCount) * chartHeight;

      final textPainter = TextPainter(
        text: TextSpan(text: _formatValue(value), style: axisTextStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          padding.left - textPainter.width - 8,
          y - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawConnector(
    Canvas canvas,
    int index,
    double barLeft,
    List<double> runningTotals,
    EdgeInsets padding,
    double chartHeight,
    double paddedMin,
    double paddedMax,
    double paddedRange,
  ) {
    final connectorPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4 * animationProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final prevBarRight =
        barLeft -
        (barLeft -
            padding.left -
            (index - 1) * (barLeft - padding.left) / index);
    final prevTotal = runningTotals[index - 1];
    final prevBarY =
        padding.top + (paddedMax - prevTotal) / paddedRange * chartHeight;

    // Create dashed line effect
    final path = Path();
    path.moveTo(prevBarRight, prevBarY);
    path.lineTo(barLeft, prevBarY);

    canvas.drawPath(_createDashedPath(path, 5, 3), connectorPaint);
  }

  void _drawValueLabel(
    Canvas canvas,
    double value,
    double barLeft,
    double barWidth,
    double barTop,
  ) {
    final valueText = _formatValue(value);
    final textPainter = TextPainter(
      text: TextSpan(text: valueText, style: valueTextStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final textX = barLeft + barWidth / 2 - textPainter.width / 2;
    final textY = barTop - textPainter.height - 8;

    // Draw background for better readability
    final backgroundRect = RRect.fromLTRBR(
      textX - 4,
      textY - 2,
      textX + textPainter.width + 4,
      textY + textPainter.height + 2,
      const Radius.circular(4),
    );

    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * animationProgress);

    canvas.drawRRect(backgroundRect, backgroundPaint);
    textPainter.paint(canvas, Offset(textX, textY));
  }

  void _drawCategoryLabel(
    Canvas canvas,
    String label,
    double barLeft,
    double barWidth,
    double yPosition,
  ) {
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: labelTextStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    );
    labelPainter.layout(maxWidth: barWidth * 1.5);

    final labelX = barLeft + barWidth / 2 - labelPainter.width / 2;
    labelPainter.paint(canvas, Offset(labelX, yPosition + 10));
  }

  void _drawIcon(
    Canvas canvas,
    IconData icon,
    double barLeft,
    double barWidth,
    double yPosition,
    Color color,
  ) {
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          color: color.withValues(alpha: 0.7),
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();

    final iconX = barLeft + barWidth / 2 - iconPainter.width / 2;
    iconPainter.paint(canvas, Offset(iconX, yPosition));
  }

  Path _createDashedPath(
    Path originalPath,
    double dashWidth,
    double dashSpace,
  ) {
    final dashedPath = Path();
    final pathMetrics = originalPath.computeMetrics();

    for (final pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final nextDistance = math.min(distance + dashWidth, pathMetric.length);
        final extractPath = pathMetric.extractPath(distance, nextDistance);
        dashedPath.addPath(extractPath, Offset.zero);
        distance = nextDistance + dashSpace;
      }
    }
    return dashedPath;
  }

  String _formatValue(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }

  @override
  bool shouldRepaint(EnhancedWaterfallPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.hoverProgress != hoverProgress ||
        oldDelegate.data != data;
  }
}

// Enhanced example usage widget with advanced features
class EnhancedWaterfallChartExample extends StatefulWidget {
  @override
  _EnhancedWaterfallChartExampleState createState() =>
      _EnhancedWaterfallChartExampleState();
}

class _EnhancedWaterfallChartExampleState
    extends State<EnhancedWaterfallChartExample> {
  String? _selectedInfo;
  bool _showGrid = true;
  bool _showValues = true;
  bool _enableAnimation = true;
  bool _showTooltips = true;

  final List<WaterfallData> _sampleData = [
    WaterfallData(
      label: 'Starting\nBalance',
      value: 10000,
      isTotal: true,
      description: 'Initial capital investment',
      icon: Icons.account_balance,
    ),
    WaterfallData(
      label: 'Q1\nRevenue',
      value: 5000,
      description: 'First quarter sales revenue',
      icon: Icons.trending_up,
    ),
    WaterfallData(
      label: 'Q1\nExpenses',
      value: -2000,
      description: 'Operating expenses for Q1',
      icon: Icons.trending_down,
    ),
    WaterfallData(
      label: 'Q2\nRevenue',
      value: 6000,
      description: 'Second quarter sales revenue',
      icon: Icons.trending_up,
    ),
    WaterfallData(
      label: 'Q2\nExpenses',
      value: -2500,
      description: 'Operating expenses for Q2',
      icon: Icons.trending_down,
    ),
    WaterfallData(
      label: 'Marketing\nBoost',
      value: 3000,
      description: 'Marketing campaign ROI',
      customColor: const Color(0xFFFF9800),
      icon: Icons.campaign,
    ),
    WaterfallData(
      label: 'Q3\nRevenue',
      value: 4500,
      description: 'Third quarter sales revenue',
      icon: Icons.trending_up,
    ),
    WaterfallData(
      label: 'Q3\nExpenses',
      value: -1800,
      description: 'Operating expenses for Q3',
      icon: Icons.trending_down,
    ),
    WaterfallData(
      label: 'Final\nBalance',
      value: 22200,
      isTotal: true,
      description: 'Year-end financial position',
      icon: Icons.account_balance_wallet,
    ),
  ];

  final List<WaterfallData> _alternativeData = [
    WaterfallData(
      label: 'Revenue',
      value: 15000,
      isTotal: true,
      icon: Icons.monetization_on,
    ),
    WaterfallData(label: 'COGS', value: -6000, icon: Icons.inventory),
    WaterfallData(label: 'Marketing', value: -2000, icon: Icons.campaign),
    WaterfallData(label: 'R&D', value: -1500, icon: Icons.science),
    WaterfallData(label: 'Admin', value: -1000, icon: Icons.business_center),
    WaterfallData(label: 'Tax', value: -800, icon: Icons.receipt_long),
    WaterfallData(
      label: 'Net Profit',
      value: 3700,
      isTotal: true,
      icon: Icons.savings,
    ),
  ];

  List<WaterfallData> _currentData = [];
  String _currentTitle = 'Financial Performance Overview';
  String _currentSubtitle = 'Quarterly breakdown of revenue and expenses';

  @override
  void initState() {
    super.initState();
    _currentData = _sampleData;
  }

  void _switchDataSet() {
    setState(() {
      if (_currentData == _sampleData) {
        _currentData = _alternativeData;
        _currentTitle = 'Profit & Loss Breakdown';
        _currentSubtitle = 'Annual P&L waterfall analysis';
      } else {
        _currentData = _sampleData;
        _currentTitle = 'Financial Performance Overview';
        _currentSubtitle = 'Quarterly breakdown of revenue and expenses';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Enhanced Waterfall Chart'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _switchDataSet,
            tooltip: 'Switch Dataset',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Chart Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Main Chart
            Card(
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              child: WaterfallChart(
                data: _currentData,
                width: 800,
                height: 500,
                title: _currentTitle,
                subtitle: _currentSubtitle,
                positiveColor: const Color(0xFF10B981),
                negativeColor: const Color(0xFFEF4444),
                totalColor: const Color(0xFF3B82F6),
                showGrid: _showGrid,
                showValues: _showValues,
                enableAnimation: _enableAnimation,
                enableTooltips: _showTooltips,
                showLegend: true,
                exportable: true,
                yAxisLabel: 'Amount (\$)',
                xAxisLabel: 'Categories',
                onBarTap: (data, index) {
                  setState(() {
                    _selectedInfo =
                        '${data.label}: \${data.value.toStringAsFixed(0)}';
                  });
                },
                onBarHover: (data, index) {
                  // Handle hover events if needed
                },
              ),
            ),

            const SizedBox(height: 20),

            // Selection Info
            if (_selectedInfo != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Selected: $_selectedInfo',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _selectedInfo = null),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Feature showcase cards
            _buildFeatureShowcase(),

            const SizedBox(height: 20),

            // Compact version example
            const Text(
              'Compact Version',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: WaterfallChart(
                data: _alternativeData.take(5).toList(),
                width: 400,
                height: 200,
                title: 'Mini Dashboard',
                showGrid: false,
                showValues: false,
                borderRadius: 2,
                barSpacingRatio: 0.2,
                enableTooltips: true,
                showLegend: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureShowcase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enhanced Features',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildFeatureCard(
              'Interactive Tooltips',
              'Hover over bars to see detailed information',
              Icons.touch_app,
              Colors.blue,
            ),
            _buildFeatureCard(
              'Smooth Animations',
              'Configurable entrance and interaction animations',
              Icons.animation,
              Colors.green,
            ),
            _buildFeatureCard(
              'Custom Styling',
              'Customizable colors, borders, and spacing',
              Icons.palette,
              Colors.orange,
            ),
            _buildFeatureCard(
              'Grid & Axes',
              'Professional grid lines and labeled axes',
              Icons.grid_on,
              Colors.purple,
            ),
            _buildFeatureCard(
              'Data Export',
              'Export capabilities for reports and analysis',
              Icons.download,
              Colors.teal,
            ),
            _buildFeatureCard(
              'Responsive Design',
              'Adapts to different screen sizes and orientations',
              Icons.devices,
              Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chart Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Show Grid'),
              value: _showGrid,
              onChanged: (value) => setState(() => _showGrid = value),
            ),
            SwitchListTile(
              title: const Text('Show Values'),
              value: _showValues,
              onChanged: (value) => setState(() => _showValues = value),
            ),
            SwitchListTile(
              title: const Text('Enable Animation'),
              value: _enableAnimation,
              onChanged: (value) => setState(() => _enableAnimation = value),
            ),
            SwitchListTile(
              title: const Text('Show Tooltips'),
              value: _showTooltips,
              onChanged: (value) => setState(() => _showTooltips = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
