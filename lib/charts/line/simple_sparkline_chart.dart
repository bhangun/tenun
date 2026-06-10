import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import 'simple_line_chart.dart';

typedef SimpleSparklineTapCallback =
    void Function(SimpleTrendPoint point, int index);
typedef SimpleSparklineTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleTrendPoint point,
      int index,
      String formattedValue,
    );

enum SimpleSparklineType { line, area, bar }

/// A tiny trend chart for KPI cards, tables, and dense dashboards.
class SimpleSparklineChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(4, 4, 4, 4);

  final List<SimpleTrendPoint> points;
  final SimpleSparklineType type;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? color;
  final Color? fillColor;
  final Color? negativeColor;
  final Color? referenceColor;
  final bool includeZero;
  final bool showDots;
  final bool showLastDot;
  final bool showTooltip;
  final bool smooth;
  final bool useGradient;
  final List<SimpleChartReferenceLine> referenceLines;
  final double? strokeWidth;
  final double? dotRadius;
  final double? barRadius;
  final double? barWidthFactor;
  final double? maxBarWidth;
  final double fillOpacity;
  final SimpleTrendValueFormatter? valueFormatter;
  final SimpleSparklineTapCallback? onPointTap;
  final SimpleSparklineTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleSparklineChart({
    super.key,
    required this.points,
    this.type = SimpleSparklineType.line,
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 56,
    this.padding = _defaultPadding,
    this.color,
    this.fillColor,
    this.negativeColor,
    this.referenceColor,
    this.includeZero = false,
    this.showDots = false,
    this.showLastDot = true,
    this.showTooltip = true,
    this.smooth = true,
    this.useGradient = true,
    this.referenceLines = const [],
    this.strokeWidth,
    this.dotRadius,
    this.barRadius,
    this.barWidthFactor,
    this.maxBarWidth,
    this.fillOpacity = 0.22,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 550),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(dotRadius == null || dotRadius >= 0),
       assert(barRadius == null || barRadius >= 0),
       assert(
         barWidthFactor == null || (barWidthFactor > 0 && barWidthFactor <= 1),
       ),
       assert(maxBarWidth == null || maxBarWidth > 0),
       assert(fillOpacity >= 0 && fillOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleSparklineVisuals.resolve(style, colorScheme);
    final visiblePoints = points
        .where((point) => point.value.isFinite)
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 140.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visiblePoints.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder:
                emptyBuilder ??
                (context) => Center(
                  child: Container(
                    width: math.min(32, width * 0.32),
                    height: 2,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            emptySemanticLabel: 'Sparkline chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(visiblePoints, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleSparklineChartView(
            width: width,
            height: chartHeight,
            points: visiblePoints,
            type: type,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            color: color ?? visuals.color,
            fillColor: fillColor,
            negativeColor: negativeColor ?? visuals.negativeColor,
            referenceColor: referenceColor ?? visuals.referenceColor,
            includeZero: includeZero || type == SimpleSparklineType.bar,
            showDots: showDots,
            showLastDot: showLastDot,
            showTooltip: showTooltip,
            smooth: smooth,
            useGradient: useGradient,
            referenceLines: referenceLines,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            dotRadius: dotRadius ?? visuals.dotRadius,
            barRadius: barRadius ?? visuals.barRadius,
            barWidthFactor: barWidthFactor ?? visuals.barWidthFactor,
            maxBarWidth: maxBarWidth ?? visuals.maxBarWidth,
            fillOpacity: fillOpacity,
            valueFormatter: formatter,
            onPointTap: onPointTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(
    List<SimpleTrendPoint> visiblePoints,
    SimpleTrendValueFormatter formatter,
  ) {
    var minPoint = visiblePoints.first;
    var maxPoint = visiblePoints.first;
    for (final point in visiblePoints.skip(1)) {
      if (point.value < minPoint.value) minPoint = point;
      if (point.value > maxPoint.value) maxPoint = point;
    }
    final first = visiblePoints.first;
    final last = visiblePoints.last;
    return 'Sparkline chart, ${visiblePoints.length} points. '
        '${first.label} ${formatter(first.value)}, '
        '${last.label} ${formatter(last.value)}. '
        'Low ${formatter(minPoint.value)}, high ${formatter(maxPoint.value)}.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleSparklineChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleTrendPoint> points;
  final SimpleSparklineType type;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color color;
  final Color? fillColor;
  final Color negativeColor;
  final Color referenceColor;
  final bool includeZero;
  final bool showDots;
  final bool showLastDot;
  final bool showTooltip;
  final bool smooth;
  final bool useGradient;
  final List<SimpleChartReferenceLine> referenceLines;
  final double strokeWidth;
  final double dotRadius;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final double fillOpacity;
  final SimpleTrendValueFormatter valueFormatter;
  final SimpleSparklineTapCallback? onPointTap;
  final SimpleSparklineTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleSparklineChartView({
    required this.width,
    required this.height,
    required this.points,
    required this.type,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.color,
    required this.fillColor,
    required this.negativeColor,
    required this.referenceColor,
    required this.includeZero,
    required this.showDots,
    required this.showLastDot,
    required this.showTooltip,
    required this.smooth,
    required this.useGradient,
    required this.referenceLines,
    required this.strokeWidth,
    required this.dotRadius,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.fillOpacity,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleSparklineChartView> createState() =>
      _SimpleSparklineChartViewState();
}

class _SimpleSparklineChartViewState extends State<_SimpleSparklineChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled = widget.showTooltip || widget.onPointTap != null;

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
                painter: _SimpleSparklinePainter(
                  points: widget.points,
                  type: widget.type,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  color: widget.color,
                  fillColor: widget.fillColor,
                  negativeColor: widget.negativeColor,
                  referenceColor: widget.referenceColor,
                  includeZero: widget.includeZero,
                  showDots: widget.showDots,
                  showLastDot: widget.showLastDot,
                  smooth: widget.smooth,
                  useGradient: widget.useGradient,
                  referenceLines: widget.referenceLines,
                  strokeWidth: widget.strokeWidth,
                  dotRadius: widget.dotRadius,
                  barRadius: widget.barRadius,
                  barWidthFactor: widget.barWidthFactor,
                  maxBarWidth: widget.maxBarWidth,
                  fillOpacity: widget.fillOpacity,
                  valueFormatter: widget.valueFormatter,
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
                      widget.onPointTap?.call(widget.points[index], index);
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
    if (!plot.inflate(8).contains(position)) return null;
    if (widget.points.isEmpty) return null;
    if (widget.points.length == 1) return 0;

    final relative = ((position.dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (relative * (widget.points.length - 1)).round();
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final point = widget.points[index];
    final formattedValue = widget.valueFormatter(point.value);
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 132.0;
    const tooltipHeight = 54.0;
    final left = (anchor.dx + 8)
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
          widget.tooltipBuilder?.call(context, point, index, formattedValue) ??
          _DefaultSparklineTooltip(
            color: widget.color,
            label: point.label,
            value: formattedValue,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final plot = _plot(size);
    final range = _resolveRange();
    final x = _xForIndex(index, widget.points.length, plot);
    final y = _yForValue(widget.points[index].value, plot, range);
    return Offset(x, y);
  }

  Rect _plot(Size size) {
    return Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }

  _SparklineRange _resolveRange() {
    return _resolveSparklineRange(
      points: widget.points,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      includeZero: widget.includeZero,
      referenceLines: widget.referenceLines,
    );
  }

  double _xForIndex(int index, int count, Rect plot) {
    if (count <= 1) return plot.center.dx;
    return plot.left + (index / (count - 1)) * plot.width;
  }

  double _yForValue(double value, Rect plot, _SparklineRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }
}

class _SimpleSparklinePainter extends CustomPainter {
  final List<SimpleTrendPoint> points;
  final SimpleSparklineType type;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color color;
  final Color? fillColor;
  final Color negativeColor;
  final Color referenceColor;
  final bool includeZero;
  final bool showDots;
  final bool showLastDot;
  final bool smooth;
  final bool useGradient;
  final List<SimpleChartReferenceLine> referenceLines;
  final double strokeWidth;
  final double dotRadius;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final double fillOpacity;
  final SimpleTrendValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleSparklinePainter({
    required this.points,
    required this.type,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.color,
    required this.fillColor,
    required this.negativeColor,
    required this.referenceColor,
    required this.includeZero,
    required this.showDots,
    required this.showLastDot,
    required this.smooth,
    required this.useGradient,
    required this.referenceLines,
    required this.strokeWidth,
    required this.dotRadius,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.fillOpacity,
    required this.valueFormatter,
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
    final zeroY = _yForValue(
      0,
      plot,
      range,
    ).clamp(plot.top, plot.bottom).toDouble();

    _drawReferenceLines(canvas, plot, range);
    if (type == SimpleSparklineType.bar) {
      _drawBars(canvas, plot, range, zeroY);
    } else {
      _drawTrend(canvas, plot, range, zeroY);
    }
    _drawActiveGuide(canvas, plot, range, zeroY);
  }

  _SparklineRange _resolveRange() {
    return _resolveSparklineRange(
      points: points,
      minValue: minValue,
      maxValue: maxValue,
      includeZero: includeZero,
      referenceLines: referenceLines,
    );
  }

  double _xForIndex(int index, int count, Rect plot) {
    if (count <= 1) return plot.center.dx;
    return plot.left + (index / (count - 1)) * plot.width;
  }

  double _yForValue(double value, Rect plot, _SparklineRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  void _drawReferenceLines(Canvas canvas, Rect plot, _SparklineRange range) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final y = _yForValue(line.value, plot, range);
      if (y < plot.top - 1 || y > plot.bottom + 1) continue;

      final lineColor = line.color ?? referenceColor;
      _drawStyledLine(
        canvas,
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()
          ..color = lineColor.withValues(alpha: 0.7)
          ..strokeWidth = line.strokeWidth,
        line.lineStyle,
      );
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

  void _drawTrend(
    Canvas canvas,
    Rect plot,
    _SparklineRange range,
    double zeroY,
  ) {
    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = _xForIndex(index, points.length, plot);
      final targetY = _yForValue(point.value, plot, range);
      final baselineY = includeZero ? zeroY : plot.bottom;
      final y = baselineY + (targetY - baselineY) * progress;
      offsets.add(Offset(x, y));
    }

    if (offsets.isEmpty) return;
    final path = _linePath(offsets);
    final trendColor = _trendColor();

    if (type == SimpleSparklineType.area) {
      final baselineY = includeZero ? zeroY : plot.bottom;
      final areaPath = Path.from(path)
        ..lineTo(offsets.last.dx, baselineY)
        ..lineTo(offsets.first.dx, baselineY)
        ..close();
      final areaColor = fillColor ?? trendColor;
      final areaPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: useGradient
              ? [
                  areaColor.withValues(alpha: fillOpacity),
                  areaColor.withValues(alpha: fillOpacity * 0.12),
                ]
              : [
                  areaColor.withValues(alpha: fillOpacity),
                  areaColor.withValues(alpha: fillOpacity),
                ],
        ).createShader(plot);
      canvas.drawPath(areaPath, areaPaint);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = trendColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (showDots) {
      for (final offset in offsets) {
        _drawDot(canvas, offset, trendColor, dotRadius);
      }
    } else if (showLastDot) {
      _drawDot(canvas, offsets.last, trendColor, dotRadius);
    }
  }

  Path _linePath(List<Offset> offsets) {
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    if (smooth && offsets.length > 1) {
      for (var index = 0; index < offsets.length - 1; index++) {
        final current = offsets[index];
        final next = offsets[index + 1];
        final distance = (next.dx - current.dx) * 0.42;
        path.cubicTo(
          current.dx + distance,
          current.dy,
          next.dx - distance,
          next.dy,
          next.dx,
          next.dy,
        );
      }
    } else {
      for (var index = 1; index < offsets.length; index++) {
        path.lineTo(offsets[index].dx, offsets[index].dy);
      }
    }
    return path;
  }

  void _drawBars(
    Canvas canvas,
    Rect plot,
    _SparklineRange range,
    double zeroY,
  ) {
    final segmentWidth = plot.width / points.length;
    final barWidth = math.min(
      maxBarWidth,
      math.max(2.0, segmentWidth * barWidthFactor),
    );

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x =
          plot.left + segmentWidth * index + (segmentWidth - barWidth) / 2;
      final targetY = _yForValue(point.value, plot, range);
      final animatedY = zeroY + (targetY - zeroY) * progress;
      final top = math.min(zeroY, animatedY);
      final bottom = math.max(zeroY, animatedY);
      final rect = Rect.fromLTRB(x, top, x + barWidth, bottom);
      if (rect.height <= 0.5) continue;

      final barColor = point.value < 0 ? negativeColor : color;
      canvas.drawRRect(
        _barRRect(rect, point.value),
        _barPaint(barColor, rect, point.value),
      );
    }
  }

  Paint _barPaint(Color barColor, Rect rect, double value) {
    if (!useGradient) return Paint()..color = barColor;
    return Paint()
      ..shader = LinearGradient(
        begin: value >= 0 ? Alignment.topCenter : Alignment.bottomCenter,
        end: value >= 0 ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [
          barColor.withValues(alpha: 0.96),
          barColor.withValues(alpha: 0.72),
        ],
      ).createShader(rect);
  }

  RRect _barRRect(Rect rect, double value) {
    final radius = Radius.circular(math.min(barRadius, rect.height / 2));
    if (value < 0) {
      return RRect.fromRectAndCorners(
        rect,
        bottomLeft: radius,
        bottomRight: radius,
      );
    }
    return RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius);
  }

  void _drawActiveGuide(
    Canvas canvas,
    Rect plot,
    _SparklineRange range,
    double zeroY,
  ) {
    final index = activeIndex;
    if (index == null || index < 0 || index >= points.length) return;
    final point = points[index];
    final x = _xForIndex(index, points.length, plot);

    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..color = referenceColor.withValues(alpha: 0.36)
        ..strokeWidth = 1,
    );

    final y = type == SimpleSparklineType.bar
        ? _yForValue(point.value, plot, range)
        : (includeZero
              ? zeroY +
                    (_yForValue(point.value, plot, range) - zeroY) * progress
              : plot.bottom +
                    (_yForValue(point.value, plot, range) - plot.bottom) *
                        progress);
    _drawDot(
      canvas,
      Offset(x, y),
      point.value < 0 ? negativeColor : color,
      dotRadius + 1,
    );
  }

  void _drawDot(Canvas canvas, Offset offset, Color dotColor, double radius) {
    if (radius <= 0) return;
    canvas.drawCircle(
      offset,
      radius + 1.5,
      Paint()..color = dotColor.withValues(alpha: 0.18),
    );
    canvas.drawCircle(offset, radius, Paint()..color = dotColor);
  }

  Color _trendColor() {
    if (points.length < 2) return color;
    return points.last.value >= points.first.value ? color : negativeColor;
  }

  @override
  bool shouldRepaint(covariant _SimpleSparklinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.type != type ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.color != color ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.negativeColor != negativeColor ||
        oldDelegate.referenceColor != referenceColor ||
        oldDelegate.includeZero != includeZero ||
        oldDelegate.showDots != showDots ||
        oldDelegate.showLastDot != showLastDot ||
        oldDelegate.smooth != smooth ||
        oldDelegate.useGradient != useGradient ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.barWidthFactor != barWidthFactor ||
        oldDelegate.maxBarWidth != maxBarWidth ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

_SparklineRange _resolveSparklineRange({
  required List<SimpleTrendPoint> points,
  required double? minValue,
  required double? maxValue,
  required bool includeZero,
  required List<SimpleChartReferenceLine> referenceLines,
}) {
  var lower = double.infinity;
  var upper = double.negativeInfinity;

  for (final point in points) {
    if (!point.value.isFinite) continue;
    lower = math.min(lower, point.value);
    upper = math.max(upper, point.value);
  }
  for (final line in referenceLines) {
    if (!line.value.isFinite) continue;
    lower = math.min(lower, line.value);
    upper = math.max(upper, line.value);
  }

  if (!lower.isFinite || !upper.isFinite) {
    lower = 0;
    upper = 1;
  }

  if (includeZero) {
    lower = math.min(0.0, lower);
    upper = math.max(0.0, upper);
  }

  lower = minValue ?? lower;
  upper = maxValue ?? upper;

  if (lower > upper) {
    final previousLower = lower;
    lower = upper;
    upper = previousLower;
  }

  if (lower == upper) {
    final pad = lower == 0 ? 1.0 : lower.abs() * 0.2;
    lower -= pad;
    upper += pad;
  } else {
    final pad = (upper - lower).abs() * 0.06;
    lower -= pad;
    upper += pad;
  }

  return _SparklineRange(lower, upper);
}

class _SimpleSparklineVisuals {
  final Color color;
  final Color negativeColor;
  final Color referenceColor;
  final double strokeWidth;
  final double dotRadius;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;

  const _SimpleSparklineVisuals({
    required this.color,
    required this.negativeColor,
    required this.referenceColor,
    required this.strokeWidth,
    required this.dotRadius,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
  });

  factory _SimpleSparklineVisuals.resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleSparklineVisuals(
          color: colorScheme.primary,
          negativeColor: colorScheme.error,
          referenceColor: colorScheme.outline,
          strokeWidth: 2.6,
          dotRadius: 2.8,
          barRadius: 5,
          barWidthFactor: 0.62,
          maxBarWidth: 10,
        );
      case SimpleTrendChartStyle.professional:
        return _SimpleSparklineVisuals(
          color: colorScheme.primary,
          negativeColor: colorScheme.error,
          referenceColor: colorScheme.outline,
          strokeWidth: 2,
          dotRadius: 2.4,
          barRadius: 3,
          barWidthFactor: 0.58,
          maxBarWidth: 8,
        );
      case SimpleTrendChartStyle.education:
        return _SimpleSparklineVisuals(
          color: colorScheme.secondary,
          negativeColor: colorScheme.error,
          referenceColor: colorScheme.outline,
          strokeWidth: 2.3,
          dotRadius: 3,
          barRadius: 4,
          barWidthFactor: 0.64,
          maxBarWidth: 9,
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleSparklineVisuals(
          color: colorScheme.tertiary,
          negativeColor: colorScheme.error,
          referenceColor: colorScheme.outline,
          strokeWidth: 2.8,
          dotRadius: 2.8,
          barRadius: 6,
          barWidthFactor: 0.6,
          maxBarWidth: 10,
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleSparklineVisuals(
          color: colorScheme.primary,
          negativeColor: colorScheme.error,
          referenceColor: colorScheme.outline,
          strokeWidth: 2.3,
          dotRadius: 2.6,
          barRadius: 4,
          barWidthFactor: 0.58,
          maxBarWidth: 9,
        );
    }
  }
}

class _DefaultSparklineTooltip extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _DefaultSparklineTooltip({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onInverseSurface.withValues(alpha: 0.78),
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                color: colorScheme.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklineRange {
  final double min;
  final double max;

  const _SparklineRange(this.min, this.max);

  double get span => max - min;
}
