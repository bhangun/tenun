import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleScatterValueFormatter = String Function(double value);
typedef SimpleScatterPointTapCallback =
    void Function(SimpleScatterPoint point, int index);
typedef SimpleScatterTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleScatterPoint point,
      int index,
      String formattedX,
      String formattedY,
      String? formattedSize,
    );

enum SimpleScatterReferenceAxis { x, y }

class SimpleScatterPoint {
  final String label;
  final double x;
  final double y;
  final double? size;
  final String? group;
  final Color? color;

  const SimpleScatterPoint({
    required this.label,
    required this.x,
    required this.y,
    this.size,
    this.group,
    this.color,
  });
}

class SimpleScatterReferenceLine {
  final SimpleScatterReferenceAxis axis;
  final double value;
  final String? label;
  final Color? color;
  final double strokeWidth;
  final SimpleChartReferenceLineStyle lineStyle;
  final bool showLabel;

  const SimpleScatterReferenceLine({
    required this.axis,
    required this.value,
    this.label,
    this.color,
    this.strokeWidth = 1.4,
    this.lineStyle = SimpleChartReferenceLineStyle.dashed,
    this.showLabel = true,
  }) : assert(strokeWidth > 0);
}

class SimpleScatterReferenceBand {
  final SimpleScatterReferenceAxis axis;
  final double from;
  final double to;
  final String? label;
  final Color? color;
  final double opacity;
  final bool showLabel;

  const SimpleScatterReferenceBand({
    required this.axis,
    required this.from,
    required this.to,
    this.label,
    this.color,
    this.opacity = 0.1,
    this.showLabel = true,
  }) : assert(opacity >= 0 && opacity <= 1);
}

/// A lightweight scatter and bubble chart for relationships, opportunity maps,
/// and two-axis comparisons.
class SimpleScatterChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 24, 42);

  final List<SimpleScatterPoint> points;
  final SimpleBarChartStyle style;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final double height;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color? pointColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? trendLineColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showTrendLine;
  final bool showAxisLabels;
  final List<SimpleScatterReferenceLine> referenceLines;
  final List<SimpleScatterReferenceBand> referenceBands;
  final int gridLineCount;
  final double? pointRadius;
  final double? minPointRadius;
  final double? maxPointRadius;
  final SimpleScatterValueFormatter? xValueFormatter;
  final SimpleScatterValueFormatter? yValueFormatter;
  final SimpleScatterValueFormatter? sizeFormatter;
  final SimpleScatterPointTapCallback? onPointTap;
  final SimpleScatterTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleScatterChart({
    super.key,
    required this.points,
    this.style = SimpleBarChartStyle.elegant,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.height = 260,
    this.padding = _defaultPadding,
    this.xAxisLabel,
    this.yAxisLabel,
    this.pointColor,
    this.gridColor,
    this.axisColor,
    this.trendLineColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.showTrendLine = false,
    this.showAxisLabels = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.pointRadius,
    this.minPointRadius,
    this.maxPointRadius,
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
       assert(maxPointRadius == null || maxPointRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleScatterVisuals.resolve(style, colorScheme);
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
            emptySemanticLabel: 'Scatter chart, no data.',
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

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visiblePoints,
            xFormatter,
            yFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleScatterChartView(
            width: width,
            height: chartHeight,
            points: visiblePoints,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            padding: padding,
            xAxisLabel: xAxisLabel,
            yAxisLabel: yAxisLabel,
            palette: _resolvePalette(visuals.palette),
            pointColor: pointColor ?? visuals.pointColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            trendLineColor: trendLineColor ?? visuals.trendLineColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            showTrendLine: showTrendLine,
            showAxisLabels: showAxisLabels,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            pointRadius: pointRadius ?? visuals.pointRadius,
            minPointRadius: minPointRadius ?? visuals.minPointRadius,
            maxPointRadius: maxPointRadius ?? visuals.maxPointRadius,
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
    List<SimpleScatterPoint> visiblePoints,
    SimpleScatterValueFormatter xFormatter,
    SimpleScatterValueFormatter yFormatter,
  ) {
    final visibleItems = visiblePoints
        .take(6)
        .map(
          (point) =>
              '${point.label} x ${xFormatter(point.x)}, y ${yFormatter(point.y)}',
        )
        .join(', ');
    final remaining = visiblePoints.length - math.min(visiblePoints.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visiblePoints.length == 1 ? 'point' : 'points';
    return 'Scatter chart, ${visiblePoints.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleScatterChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleScatterPoint> points;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final List<Color> palette;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color trendLineColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showTrendLine;
  final bool showAxisLabels;
  final List<SimpleScatterReferenceLine> referenceLines;
  final List<SimpleScatterReferenceBand> referenceBands;
  final int gridLineCount;
  final double pointRadius;
  final double minPointRadius;
  final double maxPointRadius;
  final SimpleScatterValueFormatter xValueFormatter;
  final SimpleScatterValueFormatter yValueFormatter;
  final SimpleScatterValueFormatter sizeFormatter;
  final SimpleScatterPointTapCallback? onPointTap;
  final SimpleScatterTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleScatterChartView({
    required this.width,
    required this.height,
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.palette,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.trendLineColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.showTrendLine,
    required this.showAxisLabels,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.pointRadius,
    required this.minPointRadius,
    required this.maxPointRadius,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.sizeFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleScatterChartView> createState() =>
      _SimpleScatterChartViewState();
}

class _SimpleScatterChartViewState extends State<_SimpleScatterChartView> {
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
                painter: _SimpleScatterPainter(
                  points: widget.points,
                  minX: widget.minX,
                  maxX: widget.maxX,
                  minY: widget.minY,
                  maxY: widget.maxY,
                  padding: widget.padding,
                  xAxisLabel: widget.xAxisLabel,
                  yAxisLabel: widget.yAxisLabel,
                  palette: widget.palette,
                  pointColor: widget.pointColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  trendLineColor: widget.trendLineColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showLegend: widget.showLegend,
                  showActivePoint: widget.showActivePoint,
                  showTrendLine: widget.showTrendLine,
                  showAxisLabels: widget.showAxisLabels,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  pointRadius: widget.pointRadius,
                  minPointRadius: widget.minPointRadius,
                  maxPointRadius: widget.maxPointRadius,
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
                      if (index != null) {
                        widget.onPointTap?.call(widget.points[index], index);
                      }
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
    final plot = _plot(size);
    if (!plot.inflate(14).contains(position)) return null;
    final range = _resolveRange();
    final sizeRange = _resolveSizeRange(widget.points);
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var index = 0; index < widget.points.length; index++) {
      final point = widget.points[index];
      final radius = _radiusFor(point, sizeRange);
      final center = Offset(
        _xForValue(point.x, plot, range),
        _yForValue(point.y, plot, range),
      );
      final distance = (position - center).distance;
      if (distance <= radius + 10 && distance < bestDistance) {
        bestIndex = index;
        bestDistance = distance;
      }
    }
    return bestIndex >= 0 ? bestIndex : null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final point = widget.points[index];
    final formattedX = widget.xValueFormatter(point.x);
    final formattedY = widget.yValueFormatter(point.y);
    final formattedSize = point.size == null
        ? null
        : widget.sizeFormatter(point.size!);
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 188.0;
    const tooltipHeight = 86.0;
    final left = (anchor.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (anchor.dy - tooltipHeight - 8)
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
            formattedX,
            formattedY,
            formattedSize,
          ) ??
          _DefaultScatterTooltip(
            color: _pointColor(point, index),
            title: point.label,
            xLabel: widget.xAxisLabel ?? 'X',
            yLabel: widget.yAxisLabel ?? 'Y',
            xValue: formattedX,
            yValue: formattedY,
            sizeValue: formattedSize,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final plot = _plot(size);
    final range = _resolveRange();
    final point = widget.points[index];
    return Offset(
      _xForValue(point.x, plot, range),
      _yForValue(point.y, plot, range),
    );
  }

  Rect _plot(Size size) {
    return Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }

  _ScatterRange _resolveRange() {
    return _resolveScatterRange(
      points: widget.points,
      minX: widget.minX,
      maxX: widget.maxX,
      minY: widget.minY,
      maxY: widget.maxY,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
  }

  double _xForValue(double value, Rect plot, _ScatterRange range) {
    final normalized = (value - range.minX) / range.xSpan;
    return plot.left + normalized * plot.width;
  }

  double _yForValue(double value, Rect plot, _ScatterRange range) {
    final normalized = (value - range.minY) / range.ySpan;
    return plot.bottom - normalized * plot.height;
  }

  double _radiusFor(SimpleScatterPoint point, _SizeRange sizeRange) {
    if (point.size == null) return widget.pointRadius;
    final normalized = sizeRange.normalize(point.size!);
    return widget.minPointRadius +
        (widget.maxPointRadius - widget.minPointRadius) * normalized;
  }

  Color _pointColor(SimpleScatterPoint point, int index) {
    if (point.color != null) return point.color!;
    final group = point.group;
    if (group == null || group.isEmpty) return widget.pointColor;
    final groups = _groupsFor(widget.points);
    final groupIndex = math.max(0, groups.indexOf(group));
    return widget.palette[groupIndex % widget.palette.length];
  }
}

class _SimpleScatterPainter extends CustomPainter {
  final List<SimpleScatterPoint> points;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final List<Color> palette;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color trendLineColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showActivePoint;
  final bool showTrendLine;
  final bool showAxisLabels;
  final List<SimpleScatterReferenceLine> referenceLines;
  final List<SimpleScatterReferenceBand> referenceBands;
  final int gridLineCount;
  final double pointRadius;
  final double minPointRadius;
  final double maxPointRadius;
  final SimpleScatterValueFormatter xValueFormatter;
  final SimpleScatterValueFormatter yValueFormatter;
  final SimpleScatterValueFormatter sizeFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleScatterPainter({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.palette,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.trendLineColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showActivePoint,
    required this.showTrendLine,
    required this.showAxisLabels,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.pointRadius,
    required this.minPointRadius,
    required this.maxPointRadius,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.sizeFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0 || points.isEmpty) return;

    final range = _resolveRange();
    final sizeRange = _resolveSizeRange(points);
    _drawReferenceBands(canvas, plot, range);
    if (showGrid) {
      _drawGrid(canvas, plot, range);
    }
    _drawAxes(canvas, plot);
    _drawReferenceLines(canvas, plot, range);
    if (showTrendLine) {
      _drawTrendLine(canvas, plot, range);
    }
    _drawPoints(canvas, plot, range, sizeRange);
    if (showAxisLabels) {
      _drawAxisLabels(canvas, plot);
    }
    if (showLegend) {
      _drawLegend(canvas, plot);
    }
  }

  _ScatterRange _resolveRange() {
    return _resolveScatterRange(
      points: points,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
  }

  double _xForValue(double value, Rect plot, _ScatterRange range) {
    final normalized = (value - range.minX) / range.xSpan;
    return plot.left + normalized * plot.width;
  }

  double _yForValue(double value, Rect plot, _ScatterRange range) {
    final normalized = (value - range.minY) / range.ySpan;
    return plot.bottom - normalized * plot.height;
  }

  void _drawReferenceBands(Canvas canvas, Rect plot, _ScatterRange range) {
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;
      final color = band.color ?? pointColor;
      late Rect rect;
      if (band.axis == SimpleScatterReferenceAxis.x) {
        final x1 = _xForValue(band.from, plot, range);
        final x2 = _xForValue(band.to, plot, range);
        rect = Rect.fromLTRB(
          math.max(plot.left, math.min(x1, x2)),
          plot.top,
          math.min(plot.right, math.max(x1, x2)),
          plot.bottom,
        );
      } else {
        final y1 = _yForValue(band.from, plot, range);
        final y2 = _yForValue(band.to, plot, range);
        rect = Rect.fromLTRB(
          plot.left,
          math.max(plot.top, math.min(y1, y2)),
          plot.right,
          math.min(plot.bottom, math.max(y1, y2)),
        );
      }
      if (rect.width <= 0.5 || rect.height <= 0.5) continue;
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      _drawBandLabel(canvas, band, rect, plot, color);
    }
  }

  void _drawGrid(Canvas canvas, Rect plot, _ScatterRange range) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final xValue = range.minX + range.xSpan * index / gridLineCount;
      final yValue = range.minY + range.ySpan * index / gridLineCount;
      final x = _xForValue(xValue, plot, range);
      final y = _yForValue(yValue, plot, range);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), paint);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);

      final xPainter = _textPainter(
        xValueFormatter(xValue),
        labelStyle.copyWith(color: labelStyle.color?.withValues(alpha: 0.72)),
        textAlign: TextAlign.center,
      )..layout();
      xPainter.paint(canvas, Offset(x - xPainter.width / 2, plot.bottom + 8));

      final yPainter = _textPainter(
        yValueFormatter(yValue),
        labelStyle.copyWith(color: labelStyle.color?.withValues(alpha: 0.72)),
        maxWidth: padding.left - 10,
        textAlign: TextAlign.right,
      )..layout(maxWidth: padding.left - 10);
      yPainter.paint(
        canvas,
        Offset(plot.left - yPainter.width - 8, y - yPainter.height / 2),
      );
    }
  }

  void _drawAxes(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(plot.left, plot.bottom), plot.bottomRight, paint);
    canvas.drawLine(Offset(plot.left, plot.top), plot.bottomLeft, paint);
  }

  void _drawReferenceLines(Canvas canvas, Rect plot, _ScatterRange range) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final color = line.color ?? axisColor.withValues(alpha: 0.82);
      final paint = Paint()
        ..color = color
        ..strokeWidth = line.strokeWidth
        ..strokeCap = line.lineStyle == SimpleChartReferenceLineStyle.dotted
            ? StrokeCap.round
            : StrokeCap.butt;
      late Offset start;
      late Offset end;
      late Offset labelAnchor;
      if (line.axis == SimpleScatterReferenceAxis.x) {
        final x = _xForValue(line.value, plot, range);
        if (x < plot.left - 1 || x > plot.right + 1) continue;
        start = Offset(x, plot.top);
        end = Offset(x, plot.bottom);
        labelAnchor = Offset(x, plot.top);
      } else {
        final y = _yForValue(line.value, plot, range);
        if (y < plot.top - 1 || y > plot.bottom + 1) continue;
        start = Offset(plot.left, y);
        end = Offset(plot.right, y);
        labelAnchor = Offset(plot.right, y);
      }
      _drawStyledLine(canvas, start, end, paint, line.lineStyle);
      _drawReferenceLabel(canvas, line, labelAnchor, plot, color);
    }
  }

  void _drawTrendLine(Canvas canvas, Rect plot, _ScatterRange range) {
    if (points.length < 2) return;
    final regression = _linearRegression(points);
    if (regression == null) return;
    final startX = range.minX;
    final endX = range.maxX;
    final startY = regression.slope * startX + regression.intercept;
    final endY = regression.slope * endX + regression.intercept;
    _drawStyledLine(
      canvas,
      Offset(_xForValue(startX, plot, range), _yForValue(startY, plot, range)),
      Offset(_xForValue(endX, plot, range), _yForValue(endY, plot, range)),
      Paint()
        ..color = trendLineColor.withValues(alpha: 0.72)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
      SimpleChartReferenceLineStyle.dashed,
    );
  }

  void _drawPoints(
    Canvas canvas,
    Rect plot,
    _ScatterRange range,
    _SizeRange sizeRange,
  ) {
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final color = _pointColor(point, index);
      final radius = _radiusFor(point, sizeRange) * progress;
      final center = Offset(
        _xForValue(point.x, plot, range),
        _yForValue(point.y, plot, range),
      );
      final active = index == activeIndex;

      if (showActivePoint && active) {
        canvas.drawCircle(
          center,
          radius + 7,
          Paint()..color = (activeColor ?? color).withValues(alpha: 0.15),
        );
        canvas.drawCircle(
          center,
          radius + 3,
          Paint()
            ..color = (activeColor ?? color).withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      canvas.drawCircle(
        center,
        radius + 1.5,
        Paint()..color = color.withValues(alpha: 0.14),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: active ? 0.98 : 0.86),
      );

      if (showValues && points.length <= 12) {
        _drawPointLabel(canvas, point, center, plot, color, radius);
      }
    }
  }

  void _drawPointLabel(
    Canvas canvas,
    SimpleScatterPoint point,
    Offset center,
    Rect plot,
    Color color,
    double radius,
  ) {
    final painter = _textPainter(
      point.label,
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.9,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: 76,
    )..layout(maxWidth: 76);
    final x = _safeClamp(
      center.dx + radius + 5,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = _safeClamp(
      center.dy - painter.height / 2,
      plot.top + 2,
      plot.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
  }

  void _drawAxisLabels(Canvas canvas, Rect plot) {
    if (xAxisLabel != null) {
      final painter = _textPainter(
        xAxisLabel!,
        labelStyle.copyWith(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      )..layout(maxWidth: plot.width);
      painter.paint(
        canvas,
        Offset(plot.center.dx - painter.width / 2, plot.bottom + 25),
      );
    }
    if (yAxisLabel != null) {
      canvas.save();
      canvas.translate(plot.left - padding.left + 12, plot.center.dy);
      canvas.rotate(-math.pi / 2);
      final painter = _textPainter(
        yAxisLabel!,
        labelStyle.copyWith(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      )..layout(maxWidth: plot.height);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }
  }

  void _drawLegend(Canvas canvas, Rect plot) {
    final groups = _groupsFor(points);
    if (groups.length <= 1) return;
    final rowHeight = 20.0;
    final legendWidth = math.min(116.0, plot.width * 0.35);
    final left = plot.right - legendWidth - 6;
    var top = plot.top + 6;
    for (var index = 0; index < groups.length; index++) {
      if (top + rowHeight > plot.bottom) break;
      final color = palette[index % palette.length];
      canvas.drawCircle(Offset(left + 5, top + 9), 4, Paint()..color = color);
      final painter = _textPainter(
        groups[index],
        labelStyle,
        maxWidth: legendWidth - 16,
      )..layout(maxWidth: legendWidth - 16);
      painter.paint(canvas, Offset(left + 14, top + 9 - painter.height / 2));
      top += rowHeight;
    }
  }

  void _drawBandLabel(
    Canvas canvas,
    SimpleScatterReferenceBand band,
    Rect rect,
    Rect plot,
    Color color,
  ) {
    if (!band.showLabel) return;
    final text =
        band.label ??
        '${band.axis == SimpleScatterReferenceAxis.x ? xValueFormatter(band.from) : yValueFormatter(band.from)} - '
            '${band.axis == SimpleScatterReferenceAxis.x ? xValueFormatter(band.to) : yValueFormatter(band.to)}';
    final painter = _textPainter(
      text,
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.9,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: math.min(120.0, plot.width),
      textAlign: TextAlign.center,
    )..layout(maxWidth: math.min(120.0, plot.width));
    final x = _safeClamp(
      rect.left + 6,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = _safeClamp(
      rect.top + 5,
      plot.top + 2,
      plot.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
  }

  void _drawReferenceLabel(
    Canvas canvas,
    SimpleScatterReferenceLine line,
    Offset anchor,
    Rect plot,
    Color color,
  ) {
    if (!line.showLabel) return;
    final text =
        line.label ??
        (line.axis == SimpleScatterReferenceAxis.x
            ? xValueFormatter(line.value)
            : yValueFormatter(line.value));
    final painter = _textPainter(
      text,
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.92,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: math.min(112.0, plot.width),
      textAlign: TextAlign.center,
    )..layout(maxWidth: math.min(112.0, plot.width));
    final x = _safeClamp(
      anchor.dx + 6,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = _safeClamp(
      anchor.dy + 5,
      plot.top + 2,
      plot.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
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
    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) return;
    final direction = delta / distance;
    final dash = style == SimpleChartReferenceLineStyle.dotted ? 1.0 : 7.0;
    final gap = style == SimpleChartReferenceLineStyle.dotted ? 5.0 : 5.0;
    var traveled = 0.0;
    while (traveled < distance) {
      final next = math.min(traveled + dash, distance);
      canvas.drawLine(
        start + direction * traveled,
        start + direction * next,
        paint,
      );
      traveled = next + gap;
    }
  }

  double _radiusFor(SimpleScatterPoint point, _SizeRange sizeRange) {
    if (point.size == null) return pointRadius;
    final normalized = sizeRange.normalize(point.size!);
    return minPointRadius + (maxPointRadius - minPointRadius) * normalized;
  }

  Color _pointColor(SimpleScatterPoint point, int index) {
    if (point.color != null) return point.color!;
    final group = point.group;
    if (group == null || group.isEmpty) return pointColor;
    final groups = _groupsFor(points);
    final groupIndex = math.max(0, groups.indexOf(group));
    return palette[groupIndex % palette.length];
  }

  double _safeClamp(double value, double lower, double upper) {
    if (lower > upper) return lower;
    return value.clamp(lower, upper).toDouble();
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
  bool shouldRepaint(covariant _SimpleScatterPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.padding != padding ||
        oldDelegate.xAxisLabel != xAxisLabel ||
        oldDelegate.yAxisLabel != yAxisLabel ||
        oldDelegate.palette != palette ||
        oldDelegate.pointColor != pointColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.trendLineColor != trendLineColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.showTrendLine != showTrendLine ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.minPointRadius != minPointRadius ||
        oldDelegate.maxPointRadius != maxPointRadius ||
        oldDelegate.xValueFormatter != xValueFormatter ||
        oldDelegate.yValueFormatter != yValueFormatter ||
        oldDelegate.sizeFormatter != sizeFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

_ScatterRange _resolveScatterRange({
  required List<SimpleScatterPoint> points,
  required double? minX,
  required double? maxX,
  required double? minY,
  required double? maxY,
  required List<SimpleScatterReferenceLine> referenceLines,
  required List<SimpleScatterReferenceBand> referenceBands,
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
    if (line.axis == SimpleScatterReferenceAxis.x) {
      lowerX = math.min(lowerX, line.value);
      upperX = math.max(upperX, line.value);
    } else {
      lowerY = math.min(lowerY, line.value);
      upperY = math.max(upperY, line.value);
    }
  }
  for (final band in referenceBands) {
    if (!band.from.isFinite || !band.to.isFinite) continue;
    final lower = math.min(band.from, band.to);
    final upper = math.max(band.from, band.to);
    if (band.axis == SimpleScatterReferenceAxis.x) {
      lowerX = math.min(lowerX, lower);
      upperX = math.max(upperX, upper);
    } else {
      lowerY = math.min(lowerY, lower);
      upperY = math.max(upperY, upper);
    }
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
    final pad = lowerX == 0 ? 1.0 : lowerX.abs() * 0.2;
    lowerX -= pad;
    upperX += pad;
  } else {
    final pad = (upperX - lowerX).abs() * 0.06;
    if (minX == null) lowerX -= pad;
    if (maxX == null) upperX += pad;
  }
  if (lowerY == upperY) {
    final pad = lowerY == 0 ? 1.0 : lowerY.abs() * 0.2;
    lowerY -= pad;
    upperY += pad;
  } else {
    final pad = (upperY - lowerY).abs() * 0.06;
    if (minY == null) lowerY -= pad;
    if (maxY == null) upperY += pad;
  }

  return _ScatterRange(lowerX, upperX, lowerY, upperY);
}

_SizeRange _resolveSizeRange(List<SimpleScatterPoint> points) {
  var lower = double.infinity;
  var upper = double.negativeInfinity;
  for (final point in points) {
    if (point.size == null || !point.size!.isFinite) continue;
    lower = math.min(lower, point.size!);
    upper = math.max(upper, point.size!);
  }
  if (!lower.isFinite || !upper.isFinite || lower == upper) {
    return const _SizeRange(0, 1);
  }
  return _SizeRange(lower, upper);
}

List<String> _groupsFor(List<SimpleScatterPoint> points) {
  final groups = <String>[];
  for (final point in points) {
    final group = point.group;
    if (group == null || group.isEmpty || groups.contains(group)) continue;
    groups.add(group);
  }
  return groups;
}

_Regression? _linearRegression(List<SimpleScatterPoint> points) {
  final finite = points
      .where((point) => point.x.isFinite && point.y.isFinite)
      .toList();
  if (finite.length < 2) return null;
  final meanX = finite.fold(0.0, (sum, point) => sum + point.x) / finite.length;
  final meanY = finite.fold(0.0, (sum, point) => sum + point.y) / finite.length;
  var numerator = 0.0;
  var denominator = 0.0;
  for (final point in finite) {
    numerator += (point.x - meanX) * (point.y - meanY);
    denominator += math.pow(point.x - meanX, 2).toDouble();
  }
  if (denominator == 0) return null;
  final slope = numerator / denominator;
  return _Regression(slope, meanY - slope * meanX);
}

class _ScatterRange {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _ScatterRange(this.minX, this.maxX, this.minY, this.maxY);

  double get xSpan => math.max(0.000001, maxX - minX);
  double get ySpan => math.max(0.000001, maxY - minY);
}

class _SizeRange {
  final double min;
  final double max;

  const _SizeRange(this.min, this.max);

  double normalize(double value) {
    return ((value - min) / math.max(0.000001, max - min))
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

class _Regression {
  final double slope;
  final double intercept;

  const _Regression(this.slope, this.intercept);
}

class _SimpleScatterVisuals {
  final List<Color> palette;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color trendLineColor;
  final double pointRadius;
  final double minPointRadius;
  final double maxPointRadius;

  const _SimpleScatterVisuals({
    required this.palette,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.trendLineColor,
    required this.pointRadius,
    required this.minPointRadius,
    required this.maxPointRadius,
  });

  factory _SimpleScatterVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleScatterVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF22C55E),
          ],
          pointColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          trendLineColor: colorScheme.primary,
          pointRadius: 5.5,
          minPointRadius: 4,
          maxPointRadius: 12,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleScatterVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            const Color(0xFF0F766E),
            const Color(0xFF64748B),
          ],
          pointColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          trendLineColor: colorScheme.onSurfaceVariant,
          pointRadius: 4.8,
          minPointRadius: 3.6,
          maxPointRadius: 10,
        );
      case SimpleBarChartStyle.education:
        return _SimpleScatterVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFFF59E0B),
          ],
          pointColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          trendLineColor: colorScheme.secondary,
          pointRadius: 5.2,
          minPointRadius: 4,
          maxPointRadius: 12,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleScatterVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFEC4899),
          ],
          pointColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          trendLineColor: colorScheme.tertiary,
          pointRadius: 6,
          minPointRadius: 4.2,
          maxPointRadius: 13,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleScatterVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
          ],
          pointColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          trendLineColor: colorScheme.secondary,
          pointRadius: 5.2,
          minPointRadius: 4,
          maxPointRadius: 12,
        );
    }
  }
}

class _DefaultScatterTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String xLabel;
  final String yLabel;
  final String xValue;
  final String yValue;
  final String? sizeValue;

  const _DefaultScatterTooltip({
    required this.color,
    required this.title,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _ScatterTooltipRow(label: xLabel, value: xValue),
            const SizedBox(height: 4),
            _ScatterTooltipRow(label: yLabel, value: yValue),
            if (sizeValue != null) ...[
              const SizedBox(height: 4),
              _ScatterTooltipRow(label: 'Size', value: sizeValue!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScatterTooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _ScatterTooltipRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onInverseSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onInverseSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
