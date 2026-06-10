import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleQuadrantValueFormatter = String Function(double value);
typedef SimpleQuadrantPointTapCallback =
    void Function(SimpleQuadrantPoint point, int index, String quadrant);
typedef SimpleQuadrantTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleQuadrantPoint point,
      int index,
      String quadrant,
      String formattedX,
      String formattedY,
      String? formattedSize,
    );

class SimpleQuadrantPoint {
  final String label;
  final double x;
  final double y;
  final double? size;
  final String? group;
  final Color? color;

  const SimpleQuadrantPoint({
    required this.label,
    required this.x,
    required this.y,
    this.size,
    this.group,
    this.color,
  });
}

class SimpleQuadrantLabels {
  final String topRight;
  final String topLeft;
  final String bottomLeft;
  final String bottomRight;

  const SimpleQuadrantLabels({
    this.topRight = 'High impact',
    this.topLeft = 'Strategic bets',
    this.bottomLeft = 'Defer',
    this.bottomRight = 'Quick wins',
  });

  String labelFor({required bool right, required bool top}) {
    if (right && top) return topRight;
    if (!right && top) return topLeft;
    if (!right && !top) return bottomLeft;
    return bottomRight;
  }
}

/// A simple 2x2 decision matrix for effort/value, risk/impact, maturity,
/// prioritization, portfolio maps, and learning assessments.
class SimpleQuadrantChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 20, 24, 44);

  final List<SimpleQuadrantPoint> points;
  final SimpleBarChartStyle style;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final double? xSplit;
  final double? ySplit;
  final double height;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final SimpleQuadrantLabels quadrantLabels;
  final List<Color>? palette;
  final List<Color>? quadrantColors;
  final Color? pointColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? splitLineColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showAxisLabels;
  final bool showQuadrantLabels;
  final bool showPointLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final List<SimpleChartReferenceLine> referenceLines;
  final int gridLineCount;
  final double? pointRadius;
  final double? minPointRadius;
  final double? maxPointRadius;
  final double quadrantOpacity;
  final SimpleQuadrantValueFormatter? xValueFormatter;
  final SimpleQuadrantValueFormatter? yValueFormatter;
  final SimpleQuadrantValueFormatter? sizeFormatter;
  final SimpleQuadrantPointTapCallback? onPointTap;
  final SimpleQuadrantTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleQuadrantChart({
    super.key,
    required this.points,
    this.style = SimpleBarChartStyle.elegant,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.xSplit,
    this.ySplit,
    this.height = 260,
    this.padding = _defaultPadding,
    this.xAxisLabel,
    this.yAxisLabel,
    this.quadrantLabels = const SimpleQuadrantLabels(),
    this.palette,
    this.quadrantColors,
    this.pointColor,
    this.gridColor,
    this.axisColor,
    this.splitLineColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showAxisLabels = true,
    this.showQuadrantLabels = true,
    this.showPointLabels = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.referenceLines = const [],
    this.gridLineCount = 4,
    this.pointRadius,
    this.minPointRadius,
    this.maxPointRadius,
    this.quadrantOpacity = 0.08,
    this.xValueFormatter,
    this.yValueFormatter,
    this.sizeFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(pointRadius == null || pointRadius >= 0),
       assert(minPointRadius == null || minPointRadius >= 0),
       assert(maxPointRadius == null || maxPointRadius >= 0),
       assert(quadrantOpacity >= 0 && quadrantOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleQuadrantVisuals.resolve(style, colorScheme);
    final visiblePoints = points
        .where((point) => point.x.isFinite && point.y.isFinite)
        .toList();
    final xFormatter = xValueFormatter ?? _defaultValueFormatter;
    final yFormatter = yValueFormatter ?? _defaultValueFormatter;
    final resolvedSizeFormatter = sizeFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visiblePoints.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Quadrant chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedLabelStyle =
            labelStyle ??
            theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ) ??
            TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12);
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
        final resolvedPalette = _resolvePalette(visuals.palette);
        final resolvedQuadrantColors =
            quadrantColors != null && quadrantColors!.isNotEmpty
            ? quadrantColors!
            : visuals.quadrantColors;

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visiblePoints,
            xFormatter,
            yFormatter,
            resolvedSizeFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleQuadrantChartView(
            width: width,
            height: chartHeight,
            points: visiblePoints,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            xSplit: xSplit,
            ySplit: ySplit,
            padding: padding,
            xAxisLabel: xAxisLabel,
            yAxisLabel: yAxisLabel,
            quadrantLabels: quadrantLabels,
            palette: resolvedPalette,
            quadrantColors: resolvedQuadrantColors,
            pointColor: pointColor ?? visuals.pointColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            splitLineColor: splitLineColor ?? visuals.splitLineColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showAxisLabels: showAxisLabels,
            showQuadrantLabels: showQuadrantLabels,
            showPointLabels: showPointLabels,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            referenceLines: referenceLines,
            gridLineCount: gridLineCount,
            pointRadius: pointRadius ?? visuals.pointRadius,
            minPointRadius: minPointRadius ?? visuals.minPointRadius,
            maxPointRadius: maxPointRadius ?? visuals.maxPointRadius,
            quadrantOpacity: quadrantOpacity,
            xValueFormatter: xFormatter,
            yValueFormatter: yFormatter,
            sizeFormatter: resolvedSizeFormatter,
            onPointTap: onPointTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(List<Color> defaults) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return defaults;
  }

  String _defaultSemanticLabel(
    List<SimpleQuadrantPoint> visiblePoints,
    SimpleQuadrantValueFormatter xFormatter,
    SimpleQuadrantValueFormatter yFormatter,
    SimpleQuadrantValueFormatter resolvedSizeFormatter,
  ) {
    final range = _QuadrantRange.resolve(
      points: visiblePoints,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      xSplit: xSplit,
      ySplit: ySplit,
      referenceLines: referenceLines,
    );
    final visibleItems = visiblePoints
        .take(6)
        .map((point) {
          final quadrant = quadrantLabels.labelFor(
            right: point.x >= range.xSplit,
            top: point.y >= range.ySplit,
          );
          final size = point.size == null
              ? ''
              : ', size ${resolvedSizeFormatter(point.size!)}';
          return '${point.label} ${xAxisLabel ?? 'x'} ${xFormatter(point.x)}, '
              '${yAxisLabel ?? 'y'} ${yFormatter(point.y)}, '
              '$quadrant$size';
        })
        .join('; ');
    final remaining = visiblePoints.length - math.min(visiblePoints.length, 6);
    final suffix = remaining > 0 ? '; and $remaining more' : '';
    final countLabel = visiblePoints.length == 1 ? 'point' : 'points';
    return 'Quadrant chart, ${visiblePoints.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleQuadrantChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleQuadrantPoint> points;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final double? xSplit;
  final double? ySplit;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final SimpleQuadrantLabels quadrantLabels;
  final List<Color> palette;
  final List<Color> quadrantColors;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color splitLineColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showAxisLabels;
  final bool showQuadrantLabels;
  final bool showPointLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final List<SimpleChartReferenceLine> referenceLines;
  final int gridLineCount;
  final double pointRadius;
  final double minPointRadius;
  final double maxPointRadius;
  final double quadrantOpacity;
  final SimpleQuadrantValueFormatter xValueFormatter;
  final SimpleQuadrantValueFormatter yValueFormatter;
  final SimpleQuadrantValueFormatter sizeFormatter;
  final SimpleQuadrantPointTapCallback? onPointTap;
  final SimpleQuadrantTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleQuadrantChartView({
    required this.width,
    required this.height,
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xSplit,
    required this.ySplit,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.quadrantLabels,
    required this.palette,
    required this.quadrantColors,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.splitLineColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showAxisLabels,
    required this.showQuadrantLabels,
    required this.showPointLabels,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.referenceLines,
    required this.gridLineCount,
    required this.pointRadius,
    required this.minPointRadius,
    required this.maxPointRadius,
    required this.quadrantOpacity,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.sizeFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleQuadrantChartView> createState() =>
      _SimpleQuadrantChartViewState();
}

class _SimpleQuadrantChartViewState extends State<_SimpleQuadrantChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActivePoint ||
        widget.onPointTap != null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final chart = TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: widget.animationDuration,
            curve: widget.animationCurve,
            builder: (context, progress, child) {
              return CustomPaint(
                painter: _SimpleQuadrantPainter(
                  points: widget.points,
                  minX: widget.minX,
                  maxX: widget.maxX,
                  minY: widget.minY,
                  maxY: widget.maxY,
                  xSplit: widget.xSplit,
                  ySplit: widget.ySplit,
                  padding: widget.padding,
                  xAxisLabel: widget.xAxisLabel,
                  yAxisLabel: widget.yAxisLabel,
                  quadrantLabels: widget.quadrantLabels,
                  palette: widget.palette,
                  quadrantColors: widget.quadrantColors,
                  pointColor: widget.pointColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  splitLineColor: widget.splitLineColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showAxisLabels: widget.showAxisLabels,
                  showQuadrantLabels: widget.showQuadrantLabels,
                  showPointLabels: widget.showPointLabels,
                  showLegend: widget.showLegend,
                  showActivePoint: widget.showActivePoint,
                  referenceLines: widget.referenceLines,
                  gridLineCount: widget.gridLineCount,
                  pointRadius: widget.pointRadius,
                  minPointRadius: widget.minPointRadius,
                  maxPointRadius: widget.maxPointRadius,
                  quadrantOpacity: widget.quadrantOpacity,
                  xValueFormatter: widget.xValueFormatter,
                  yValueFormatter: widget.yValueFormatter,
                  sizeFormatter: widget.sizeFormatter,
                  activeIndex: _activeIndex,
                  progress: progress,
                ),
              );
            },
          );

          if (!interactionEnabled) return chart;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (event) =>
                      _setActive(_hitTest(event.localPosition, size)),
                  onExit: (_) => _setActive(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final index = _hitTest(details.localPosition, size);
                      _setActive(index);
                      if (index == null) return;
                      final point = widget.points[index];
                      final range = _rangeFor(size);
                      widget.onPointTap?.call(
                        point,
                        index,
                        widget.quadrantLabels.labelFor(
                          right: point.x >= range.xSplit,
                          top: point.y >= range.ySplit,
                        ),
                      );
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeIndex != null)
                _buildTooltip(context, size, _activeIndex!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(int? index) {
    if (_activeIndex == index) return;
    setState(() => _activeIndex = index);
  }

  int? _hitTest(Offset position, Size size) {
    final geometry = _QuadrantGeometry.resolve(
      size: size,
      points: widget.points,
      minX: widget.minX,
      maxX: widget.maxX,
      minY: widget.minY,
      maxY: widget.maxY,
      xSplit: widget.xSplit,
      ySplit: widget.ySplit,
      padding: widget.padding,
      referenceLines: widget.referenceLines,
      minPointRadius: widget.minPointRadius,
      maxPointRadius: widget.maxPointRadius,
    );
    for (final point in geometry.points.reversed) {
      if ((position - point.center).distance <= point.radius + 8) {
        return point.index;
      }
    }
    return null;
  }

  _QuadrantRange _rangeFor(Size size) {
    return _QuadrantGeometry.resolve(
      size: size,
      points: widget.points,
      minX: widget.minX,
      maxX: widget.maxX,
      minY: widget.minY,
      maxY: widget.maxY,
      xSplit: widget.xSplit,
      ySplit: widget.ySplit,
      padding: widget.padding,
      referenceLines: widget.referenceLines,
      minPointRadius: widget.minPointRadius,
      maxPointRadius: widget.maxPointRadius,
    ).range;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final point = widget.points[index];
    final range = _rangeFor(size);
    final quadrant = widget.quadrantLabels.labelFor(
      right: point.x >= range.xSplit,
      top: point.y >= range.ySplit,
    );
    final formattedX = widget.xValueFormatter(point.x);
    final formattedY = widget.yValueFormatter(point.y);
    final formattedSize = point.size == null
        ? null
        : widget.sizeFormatter(point.size!);
    final geometry = _QuadrantGeometry.resolve(
      size: size,
      points: widget.points,
      minX: widget.minX,
      maxX: widget.maxX,
      minY: widget.minY,
      maxY: widget.maxY,
      xSplit: widget.xSplit,
      ySplit: widget.ySplit,
      padding: widget.padding,
      referenceLines: widget.referenceLines,
      minPointRadius: widget.minPointRadius,
      maxPointRadius: widget.maxPointRadius,
    );
    final layout = geometry.points.firstWhere((item) => item.index == index);
    const tooltipWidth = 190.0;
    const tooltipHeight = 96.0;
    final left = (layout.center.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (layout.center.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            point,
            index,
            quadrant,
            formattedX,
            formattedY,
            formattedSize,
          ) ??
          _DefaultQuadrantTooltip(
            color: _pointColor(point, index),
            title: point.label,
            quadrant: quadrant,
            xLabel: widget.xAxisLabel ?? 'X',
            yLabel: widget.yAxisLabel ?? 'Y',
            xValue: formattedX,
            yValue: formattedY,
            sizeValue: formattedSize,
          ),
    );
  }

  Color _pointColor(SimpleQuadrantPoint point, int index) {
    if (point.color != null) return point.color!;
    if (point.group != null) {
      final groups = _groupsFor(widget.points);
      final groupIndex = groups.indexOf(point.group!);
      if (groupIndex >= 0) {
        return widget.palette[groupIndex % widget.palette.length];
      }
    }
    return widget.pointColor;
  }
}

class _SimpleQuadrantPainter extends CustomPainter {
  final List<SimpleQuadrantPoint> points;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final double? xSplit;
  final double? ySplit;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final SimpleQuadrantLabels quadrantLabels;
  final List<Color> palette;
  final List<Color> quadrantColors;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color splitLineColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showAxisLabels;
  final bool showQuadrantLabels;
  final bool showPointLabels;
  final bool showLegend;
  final bool showActivePoint;
  final List<SimpleChartReferenceLine> referenceLines;
  final int gridLineCount;
  final double pointRadius;
  final double minPointRadius;
  final double maxPointRadius;
  final double quadrantOpacity;
  final SimpleQuadrantValueFormatter xValueFormatter;
  final SimpleQuadrantValueFormatter yValueFormatter;
  final SimpleQuadrantValueFormatter sizeFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleQuadrantPainter({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xSplit,
    required this.ySplit,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.quadrantLabels,
    required this.palette,
    required this.quadrantColors,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.splitLineColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showAxisLabels,
    required this.showQuadrantLabels,
    required this.showPointLabels,
    required this.showLegend,
    required this.showActivePoint,
    required this.referenceLines,
    required this.gridLineCount,
    required this.pointRadius,
    required this.minPointRadius,
    required this.maxPointRadius,
    required this.quadrantOpacity,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.sizeFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _QuadrantGeometry.resolve(
      size: size,
      points: points,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      xSplit: xSplit,
      ySplit: ySplit,
      padding: padding,
      referenceLines: referenceLines,
      minPointRadius: minPointRadius,
      maxPointRadius: maxPointRadius,
    );
    if (geometry.plot.isEmpty || geometry.points.isEmpty) return;

    _drawQuadrants(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawSplitLines(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    if (showQuadrantLabels) _drawQuadrantLabels(canvas, geometry);
    _drawPoints(canvas, geometry);
    if (showAxisLabels) _drawAxisLabels(canvas, geometry);
    if (showLegend) _drawLegend(canvas, geometry);
  }

  void _drawQuadrants(Canvas canvas, _QuadrantGeometry geometry) {
    final splitX = geometry.xForValue(geometry.range.xSplit);
    final splitY = geometry.yForValue(geometry.range.ySplit);
    final rects = [
      Rect.fromLTRB(splitX, geometry.plot.top, geometry.plot.right, splitY),
      Rect.fromLTRB(geometry.plot.left, geometry.plot.top, splitX, splitY),
      Rect.fromLTRB(geometry.plot.left, splitY, splitX, geometry.plot.bottom),
      Rect.fromLTRB(splitX, splitY, geometry.plot.right, geometry.plot.bottom),
    ];
    for (var index = 0; index < rects.length; index++) {
      canvas.drawRect(
        rects[index],
        Paint()
          ..color = quadrantColors[index % quadrantColors.length].withValues(
            alpha: quadrantOpacity,
          ),
      );
    }
  }

  void _drawGrid(Canvas canvas, _QuadrantGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final t = index / gridLineCount;
      final x = geometry.plot.left + geometry.plot.width * t;
      final y = geometry.plot.bottom - geometry.plot.height * t;
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
      );
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
      _paintText(
        canvas,
        xValueFormatter(geometry.range.minX + geometry.range.xSpan * t),
        labelStyle.copyWith(
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
          color: labelStyle.color?.withValues(alpha: 0.72),
        ),
        Offset(x, geometry.plot.bottom + 8),
        TextAlign.center,
        54,
      );
      _paintText(
        canvas,
        yValueFormatter(geometry.range.minY + geometry.range.ySpan * t),
        labelStyle.copyWith(
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
          color: labelStyle.color?.withValues(alpha: 0.72),
        ),
        Offset(geometry.plot.left - 8, y),
        TextAlign.right,
        math.max(0.0, padding.left - 12),
        centeredY: true,
      );
    }
  }

  void _drawAxis(Canvas canvas, _QuadrantGeometry geometry) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.bottom),
      Offset(geometry.plot.right, geometry.plot.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.top),
      Offset(geometry.plot.left, geometry.plot.bottom),
      paint,
    );
  }

  void _drawSplitLines(Canvas canvas, _QuadrantGeometry geometry) {
    final paint = Paint()
      ..color = splitLineColor
      ..strokeWidth = 1.6;
    final x = geometry.xForValue(geometry.range.xSplit);
    final y = geometry.yForValue(geometry.range.ySplit);
    _drawStyledLine(
      canvas,
      Offset(x, geometry.plot.top),
      Offset(x, geometry.plot.bottom),
      paint,
      SimpleChartReferenceLineStyle.dashed,
    );
    _drawStyledLine(
      canvas,
      Offset(geometry.plot.left, y),
      Offset(geometry.plot.right, y),
      paint,
      SimpleChartReferenceLineStyle.dashed,
    );
  }

  void _drawReferenceLines(Canvas canvas, _QuadrantGeometry geometry) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final paint = Paint()
        ..color = line.color ?? axisColor
        ..strokeWidth = line.strokeWidth;
      if (line.label != null && line.showLabel) {
        final position = line.value;
        if (position.isFinite) {
          final anchor = line.label!.isEmpty ? null : line.label;
          if (anchor != null) {
            final offset = Offset(
              geometry.plot.left + 6,
              geometry.yForValue(line.value) + 4,
            );
            _paintText(canvas, anchor, labelStyle, offset, TextAlign.left, 90);
          }
        }
      }
      final y = geometry.yForValue(line.value);
      _drawStyledLine(
        canvas,
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
        line.lineStyle,
      );
    }
  }

  void _drawQuadrantLabels(Canvas canvas, _QuadrantGeometry geometry) {
    final splitX = geometry.xForValue(geometry.range.xSplit);
    final splitY = geometry.yForValue(geometry.range.ySplit);
    final entries = [
      (
        quadrantLabels.topRight,
        Rect.fromLTRB(splitX, geometry.plot.top, geometry.plot.right, splitY),
      ),
      (
        quadrantLabels.topLeft,
        Rect.fromLTRB(geometry.plot.left, geometry.plot.top, splitX, splitY),
      ),
      (
        quadrantLabels.bottomLeft,
        Rect.fromLTRB(geometry.plot.left, splitY, splitX, geometry.plot.bottom),
      ),
      (
        quadrantLabels.bottomRight,
        Rect.fromLTRB(
          splitX,
          splitY,
          geometry.plot.right,
          geometry.plot.bottom,
        ),
      ),
    ];
    final style = valueStyle.copyWith(
      color: valueStyle.color?.withValues(alpha: 0.62),
      fontWeight: FontWeight.w800,
    );
    for (final entry in entries) {
      final label = entry.$1;
      final rect = entry.$2.deflate(8);
      _paintText(
        canvas,
        label,
        style,
        Offset(rect.left + 2, rect.top + 2),
        TextAlign.left,
        math.max(0.0, rect.width - 4),
      );
    }
  }

  void _drawPoints(Canvas canvas, _QuadrantGeometry geometry) {
    for (final layout in geometry.points) {
      final point = points[layout.index];
      final selected = activeIndex == layout.index;
      final color = _pointColor(point, layout.index);
      final center = Offset(
        layout.center.dx,
        geometry.plot.bottom -
            (geometry.plot.bottom - layout.center.dy) * progress,
      );
      final radius =
          (point.size == null ? pointRadius : layout.radius) *
          (0.48 + progress * 0.52);
      canvas.drawCircle(
        center,
        radius + 1.5,
        Paint()..color = Colors.white.withValues(alpha: 0.86),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: selected ? 0.98 : 0.84),
      );
      if (showActivePoint && selected) {
        canvas.drawCircle(
          center,
          radius + 6,
          Paint()..color = (activeColor ?? color).withValues(alpha: 0.14),
        );
        canvas.drawCircle(
          center,
          radius + 3,
          Paint()
            ..color = (activeColor ?? color).withValues(alpha: 0.92)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      if (showPointLabels) {
        _paintText(
          canvas,
          point.label,
          labelStyle.copyWith(color: color, fontWeight: FontWeight.w700),
          Offset(center.dx + radius + 4, center.dy),
          TextAlign.left,
          82,
          centeredY: true,
        );
      }
    }
  }

  void _drawAxisLabels(Canvas canvas, _QuadrantGeometry geometry) {
    if (xAxisLabel != null) {
      _paintText(
        canvas,
        xAxisLabel!,
        valueStyle,
        Offset(geometry.plot.center.dx, geometry.plot.bottom + 24),
        TextAlign.center,
        geometry.plot.width,
      );
    }
    if (yAxisLabel != null) {
      canvas.save();
      canvas.translate(padding.left * 0.22, geometry.plot.center.dy);
      canvas.rotate(-math.pi / 2);
      _paintText(
        canvas,
        yAxisLabel!,
        valueStyle,
        Offset.zero,
        TextAlign.center,
        geometry.plot.height,
        centeredY: true,
      );
      canvas.restore();
    }
  }

  void _drawLegend(Canvas canvas, _QuadrantGeometry geometry) {
    final groups = _groupsFor(points);
    if (groups.length <= 1) return;
    final maxRows = math.min(groups.length, 4);
    var x = geometry.plot.left;
    final y = math.max(0.0, geometry.plot.top - 18);
    for (var index = 0; index < maxRows; index++) {
      final group = groups[index];
      final color = palette[index % palette.length];
      canvas.drawCircle(Offset(x + 4, y + 7), 4, Paint()..color = color);
      final painter = _textPainter(
        group,
        labelStyle.copyWith(
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
        ),
        maxWidth: 86,
      )..layout(maxWidth: 86);
      painter.paint(canvas, Offset(x + 12, y));
      x += painter.width + 28;
      if (x > geometry.plot.right - 40) break;
    }
  }

  void _drawStyledLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    SimpleChartReferenceLineStyle style,
  ) {
    if (style == SimpleChartReferenceLineStyle.solid) {
      canvas.drawLine(start, end, paint);
      return;
    }
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    var drawn = 0.0;
    final dash = style == SimpleChartReferenceLineStyle.dotted ? 1.5 : 6.0;
    final gap = style == SimpleChartReferenceLineStyle.dotted ? 5.0 : 4.0;
    while (drawn < total) {
      final segmentStart = start + direction * drawn;
      final segmentEnd = start + direction * math.min(total, drawn + dash);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      drawn += dash + gap;
    }
  }

  Color _pointColor(SimpleQuadrantPoint point, int index) {
    if (point.color != null) return point.color!;
    if (point.group != null) {
      final groups = _groupsFor(points);
      final groupIndex = groups.indexOf(point.group!);
      if (groupIndex >= 0) return palette[groupIndex % palette.length];
    }
    return pointColor;
  }

  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset anchor,
    TextAlign align,
    double maxWidth, {
    bool centeredY = false,
  }) {
    if (maxWidth <= 0) return;
    final painter = _textPainter(
      text,
      style,
      maxWidth: maxWidth,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.center => anchor.dx - painter.width / 2,
      _ => anchor.dx,
    };
    final dy = centeredY ? anchor.dy - painter.height / 2 : anchor.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  TextPainter _textPainter(
    String text,
    TextStyle style, {
    double? maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
      ellipsis: maxWidth == null ? null : '...',
    );
  }

  @override
  bool shouldRepaint(covariant _SimpleQuadrantPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.xSplit != xSplit ||
        oldDelegate.ySplit != ySplit ||
        oldDelegate.padding != padding ||
        oldDelegate.xAxisLabel != xAxisLabel ||
        oldDelegate.yAxisLabel != yAxisLabel ||
        oldDelegate.quadrantLabels != quadrantLabels ||
        oldDelegate.palette != palette ||
        oldDelegate.quadrantColors != quadrantColors ||
        oldDelegate.pointColor != pointColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.splitLineColor != splitLineColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.showQuadrantLabels != showQuadrantLabels ||
        oldDelegate.showPointLabels != showPointLabels ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.minPointRadius != minPointRadius ||
        oldDelegate.maxPointRadius != maxPointRadius ||
        oldDelegate.quadrantOpacity != quadrantOpacity ||
        oldDelegate.xValueFormatter != xValueFormatter ||
        oldDelegate.yValueFormatter != yValueFormatter ||
        oldDelegate.sizeFormatter != sizeFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _QuadrantGeometry {
  final Rect plot;
  final _QuadrantRange range;
  final List<_QuadrantPointLayout> points;

  const _QuadrantGeometry({
    required this.plot,
    required this.range,
    required this.points,
  });

  factory _QuadrantGeometry.resolve({
    required Size size,
    required List<SimpleQuadrantPoint> points,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
    required double? xSplit,
    required double? ySplit,
    required EdgeInsets padding,
    required List<SimpleChartReferenceLine> referenceLines,
    required double minPointRadius,
    required double maxPointRadius,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    final range = _QuadrantRange.resolve(
      points: points,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      xSplit: xSplit,
      ySplit: ySplit,
      referenceLines: referenceLines,
    );
    if (plot.width <= 0 || plot.height <= 0 || points.isEmpty) {
      return _QuadrantGeometry(plot: plot, range: range, points: const []);
    }
    final sizeRange = _resolveSizeRange(points);
    final layouts = <_QuadrantPointLayout>[];
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final center = Offset(
        _xForValue(point.x, plot, range),
        _yForValue(point.y, plot, range),
      );
      final radius = point.size == null
          ? minPointRadius
          : _radiusFor(point.size!, sizeRange, minPointRadius, maxPointRadius);
      layouts.add(
        _QuadrantPointLayout(index: index, center: center, radius: radius),
      );
    }
    return _QuadrantGeometry(plot: plot, range: range, points: layouts);
  }

  double xForValue(double value) => _xForValue(value, plot, range);
  double yForValue(double value) => _yForValue(value, plot, range);

  static double _xForValue(double value, Rect plot, _QuadrantRange range) {
    final t = ((value - range.minX) / range.xSpan).clamp(0.0, 1.0);
    return plot.left + plot.width * t;
  }

  static double _yForValue(double value, Rect plot, _QuadrantRange range) {
    final t = ((value - range.minY) / range.ySpan).clamp(0.0, 1.0);
    return plot.bottom - plot.height * t;
  }
}

class _QuadrantRange {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double xSplit;
  final double ySplit;

  const _QuadrantRange({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xSplit,
    required this.ySplit,
  });

  double get xSpan => maxX - minX;
  double get ySpan => maxY - minY;

  factory _QuadrantRange.resolve({
    required List<SimpleQuadrantPoint> points,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
    required double? xSplit,
    required double? ySplit,
    required List<SimpleChartReferenceLine> referenceLines,
  }) {
    var lowerX = double.infinity;
    var upperX = double.negativeInfinity;
    var lowerY = double.infinity;
    var upperY = double.negativeInfinity;
    for (final point in points) {
      lowerX = math.min(lowerX, point.x);
      upperX = math.max(upperX, point.x);
      lowerY = math.min(lowerY, point.y);
      upperY = math.max(upperY, point.y);
    }
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      lowerY = math.min(lowerY, line.value);
      upperY = math.max(upperY, line.value);
    }
    if (!lowerX.isFinite || !upperX.isFinite) {
      lowerX = 0;
      upperX = 1;
    }
    if (!lowerY.isFinite || !upperY.isFinite) {
      lowerY = 0;
      upperY = 1;
    }
    lowerX = minX ?? lowerX;
    upperX = maxX ?? upperX;
    lowerY = minY ?? lowerY;
    upperY = maxY ?? upperY;
    if (lowerX > upperX) {
      final previous = lowerX;
      lowerX = upperX;
      upperX = previous;
    }
    if (lowerY > upperY) {
      final previous = lowerY;
      lowerY = upperY;
      upperY = previous;
    }
    if (lowerX == upperX) {
      lowerX -= 1;
      upperX += 1;
    } else if (minX == null || maxX == null) {
      final pad = (upperX - lowerX) * 0.08;
      if (minX == null) lowerX -= pad;
      if (maxX == null) upperX += pad;
    }
    if (lowerY == upperY) {
      lowerY -= 1;
      upperY += 1;
    } else if (minY == null || maxY == null) {
      final pad = (upperY - lowerY) * 0.08;
      if (minY == null) lowerY -= pad;
      if (maxY == null) upperY += pad;
    }
    final resolvedXSplit = (xSplit ?? (lowerX + upperX) / 2)
        .clamp(lowerX, upperX)
        .toDouble();
    final resolvedYSplit = (ySplit ?? (lowerY + upperY) / 2)
        .clamp(lowerY, upperY)
        .toDouble();
    return _QuadrantRange(
      minX: lowerX,
      maxX: upperX,
      minY: lowerY,
      maxY: upperY,
      xSplit: resolvedXSplit,
      ySplit: resolvedYSplit,
    );
  }
}

class _QuadrantPointLayout {
  final int index;
  final Offset center;
  final double radius;

  const _QuadrantPointLayout({
    required this.index,
    required this.center,
    required this.radius,
  });
}

class _SizeRange {
  final double min;
  final double max;

  const _SizeRange(this.min, this.max);
}

_SizeRange _resolveSizeRange(List<SimpleQuadrantPoint> points) {
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (final point in points) {
    final size = point.size;
    if (size == null || !size.isFinite) continue;
    min = math.min(min, size);
    max = math.max(max, size);
  }
  if (!min.isFinite || !max.isFinite) return const _SizeRange(1, 1);
  return _SizeRange(min, max);
}

double _radiusFor(
  double size,
  _SizeRange sizeRange,
  double minRadius,
  double maxRadius,
) {
  if (sizeRange.min == sizeRange.max) return (minRadius + maxRadius) / 2;
  final t = ((size - sizeRange.min) / (sizeRange.max - sizeRange.min)).clamp(
    0.0,
    1.0,
  );
  return minRadius + (maxRadius - minRadius) * math.sqrt(t);
}

List<String> _groupsFor(List<SimpleQuadrantPoint> points) {
  final groups = <String>[];
  for (final point in points) {
    final group = point.group;
    if (group == null || groups.contains(group)) continue;
    groups.add(group);
  }
  return groups;
}

class _SimpleQuadrantVisuals {
  final Color pointColor;
  final List<Color> palette;
  final List<Color> quadrantColors;
  final Color gridColor;
  final Color axisColor;
  final Color splitLineColor;
  final double pointRadius;
  final double minPointRadius;
  final double maxPointRadius;

  const _SimpleQuadrantVisuals({
    required this.pointColor,
    required this.palette,
    required this.quadrantColors,
    required this.gridColor,
    required this.axisColor,
    required this.splitLineColor,
    required this.pointRadius,
    required this.minPointRadius,
    required this.maxPointRadius,
  });

  factory _SimpleQuadrantVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleQuadrantVisuals(
          pointColor: colorScheme.primary,
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.error,
          ],
          quadrantColors: [
            colorScheme.primary,
            colorScheme.tertiary,
            colorScheme.outline,
            colorScheme.secondary,
          ],
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.52),
          splitLineColor: colorScheme.onSurface.withValues(alpha: 0.5),
          pointRadius: 6,
          minPointRadius: 5,
          maxPointRadius: 14,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleQuadrantVisuals(
          pointColor: colorScheme.primary,
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            colorScheme.secondary,
            const Color(0xFF64748B),
          ],
          quadrantColors: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.outline,
            colorScheme.tertiary,
          ],
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.68),
          splitLineColor: colorScheme.onSurface.withValues(alpha: 0.54),
          pointRadius: 5.6,
          minPointRadius: 5,
          maxPointRadius: 13,
        );
      case SimpleBarChartStyle.education:
        return _SimpleQuadrantVisuals(
          pointColor: colorScheme.secondary,
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            colorScheme.error,
          ],
          quadrantColors: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.outline,
            colorScheme.primary,
          ],
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          splitLineColor: colorScheme.onSurface.withValues(alpha: 0.5),
          pointRadius: 6.2,
          minPointRadius: 5,
          maxPointRadius: 14,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleQuadrantVisuals(
          pointColor: colorScheme.tertiary,
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFF97316),
          ],
          quadrantColors: [
            colorScheme.tertiary,
            colorScheme.primary,
            colorScheme.outline,
            colorScheme.secondary,
          ],
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          splitLineColor: colorScheme.onSurface.withValues(alpha: 0.46),
          pointRadius: 6.4,
          minPointRadius: 5.2,
          maxPointRadius: 15,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleQuadrantVisuals(
          pointColor: colorScheme.primary,
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
          ],
          quadrantColors: [
            colorScheme.primary,
            colorScheme.tertiary,
            colorScheme.outline,
            colorScheme.secondary,
          ],
          gridColor: colorScheme.outline.withValues(alpha: 0.14),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          splitLineColor: colorScheme.onSurface.withValues(alpha: 0.48),
          pointRadius: 5.8,
          minPointRadius: 5,
          maxPointRadius: 14,
        );
    }
  }
}

class _DefaultQuadrantTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String quadrant;
  final String xLabel;
  final String yLabel;
  final String xValue;
  final String yValue;
  final String? sizeValue;

  const _DefaultQuadrantTooltip({
    required this.color,
    required this.title,
    required this.quadrant,
    required this.xLabel,
    required this.yLabel,
    required this.xValue,
    required this.yValue,
    required this.sizeValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TooltipRow(
              label: 'Zone',
              value: quadrant,
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: color),
            ),
            _TooltipRow(
              label: xLabel,
              value: xValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: yLabel,
              value: yValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            if (sizeValue != null)
              _TooltipRow(
                label: 'Size',
                value: sizeValue!,
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
          ],
        ),
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _TooltipRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
