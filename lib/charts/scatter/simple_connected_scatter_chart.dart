import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';
import 'simple_scatter_chart.dart';

typedef SimpleConnectedScatterValueFormatter = String Function(double value);
typedef SimpleConnectedScatterPointTapCallback =
    void Function(
      SimpleConnectedScatterSeries series,
      SimpleConnectedScatterPoint point,
      int seriesIndex,
      int pointIndex,
    );
typedef SimpleConnectedScatterTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleConnectedScatterSeries series,
      SimpleConnectedScatterPoint point,
      int seriesIndex,
      int pointIndex,
      String formattedX,
      String formattedY,
      String? formattedValue,
    );

class SimpleConnectedScatterPoint {
  final String label;
  final double x;
  final double y;
  final double? value;
  final Color? color;

  const SimpleConnectedScatterPoint({
    required this.label,
    required this.x,
    required this.y,
    this.value,
    this.color,
  });
}

class SimpleConnectedScatterSeries {
  final String name;
  final List<SimpleConnectedScatterPoint> points;
  final Color? color;
  final double? strokeWidth;

  const SimpleConnectedScatterSeries({
    required this.name,
    required this.points,
    this.color,
    this.strokeWidth,
  });
}

/// A connected scatter chart for trajectories through a two-metric space:
/// strategy movement, product maturity, education progress, and path analysis.
class SimpleConnectedScatterChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 24, 42);

  final List<SimpleConnectedScatterSeries> series;
  final SimpleBarChartStyle style;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final double height;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color? lineColor;
  final Color? pointColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLines;
  final bool showPoints;
  final bool showArrows;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showAxisLabels;
  final bool showEndpointLabels;
  final List<SimpleScatterReferenceLine> referenceLines;
  final List<SimpleScatterReferenceBand> referenceBands;
  final int gridLineCount;
  final double? strokeWidth;
  final double pointRadius;
  final double arrowSize;
  final SimpleConnectedScatterValueFormatter? xValueFormatter;
  final SimpleConnectedScatterValueFormatter? yValueFormatter;
  final SimpleConnectedScatterValueFormatter? valueFormatter;
  final SimpleConnectedScatterPointTapCallback? onPointTap;
  final SimpleConnectedScatterTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleConnectedScatterChart({
    super.key,
    required this.series,
    this.style = SimpleBarChartStyle.elegant,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.height = 260,
    this.padding = _defaultPadding,
    this.xAxisLabel,
    this.yAxisLabel,
    this.lineColor,
    this.pointColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLines = true,
    this.showPoints = true,
    this.showArrows = true,
    this.showLabels = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.showAxisLabels = true,
    this.showEndpointLabels = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.strokeWidth,
    this.pointRadius = 4.5,
    this.arrowSize = 8,
    this.xValueFormatter,
    this.yValueFormatter,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(pointRadius >= 0),
       assert(arrowSize >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleConnectedScatterVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .map(
          (item) => SimpleConnectedScatterSeries(
            name: item.name,
            color: item.color,
            strokeWidth: item.strokeWidth,
            points: item.points
                .where(
                  (point) =>
                      point.x.isFinite &&
                      point.y.isFinite &&
                      (point.value == null || point.value!.isFinite),
                )
                .toList(),
          ),
        )
        .where((item) => item.points.isNotEmpty)
        .toList();
    final xFormatter = xValueFormatter ?? _defaultValueFormatter;
    final yFormatter = yValueFormatter ?? _defaultValueFormatter;
    final resolvedValueFormatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Connected scatter chart, no data.',
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
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            );
        final geometry = _ConnectedScatterGeometry.resolve(
          size: Size(width, chartHeight),
          series: visibleSeries,
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          padding: padding,
          palette: palette ?? visuals.palette,
          lineColor: lineColor ?? visuals.lineColor,
          pointColor: pointColor ?? visuals.pointColor,
          showLegend: showLegend,
        );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleSeries,
            xFormatter,
            yFormatter,
            resolvedValueFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleConnectedScatterView(
            width: width,
            height: chartHeight,
            geometry: geometry,
            xAxisLabel: xAxisLabel,
            yAxisLabel: yAxisLabel,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showLines: showLines,
            showPoints: showPoints,
            showArrows: showArrows,
            showLabels: showLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            showAxisLabels: showAxisLabels,
            showEndpointLabels: showEndpointLabels,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            pointRadius: pointRadius,
            arrowSize: arrowSize,
            xValueFormatter: xFormatter,
            yValueFormatter: yFormatter,
            valueFormatter: resolvedValueFormatter,
            onPointTap: onPointTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleConnectedScatterSeries> series,
    SimpleConnectedScatterValueFormatter xFormatter,
    SimpleConnectedScatterValueFormatter yFormatter,
    SimpleConnectedScatterValueFormatter valueFormatter,
  ) {
    final sample = series
        .take(3)
        .map((item) {
          final points = item.points
              .take(4)
              .map((point) {
                final value = point.value == null
                    ? ''
                    : ', value ${valueFormatter(point.value!)}';
                return '${point.label} x ${xFormatter(point.x)}, '
                    'y ${yFormatter(point.y)}$value';
              })
              .join('; ');
          return '${item.name}: $points';
        })
        .join('. ');
    final suffix = series.length > 3 ? ' and ${series.length - 3} more.' : '';
    return 'Connected scatter chart, ${series.length} series. $sample$suffix';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleConnectedScatterView extends StatefulWidget {
  final double width;
  final double height;
  final _ConnectedScatterGeometry geometry;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLines;
  final bool showPoints;
  final bool showArrows;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showAxisLabels;
  final bool showEndpointLabels;
  final List<SimpleScatterReferenceLine> referenceLines;
  final List<SimpleScatterReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double pointRadius;
  final double arrowSize;
  final SimpleConnectedScatterValueFormatter xValueFormatter;
  final SimpleConnectedScatterValueFormatter yValueFormatter;
  final SimpleConnectedScatterValueFormatter valueFormatter;
  final SimpleConnectedScatterPointTapCallback? onPointTap;
  final SimpleConnectedScatterTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleConnectedScatterView({
    required this.width,
    required this.height,
    required this.geometry,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLines,
    required this.showPoints,
    required this.showArrows,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.showAxisLabels,
    required this.showEndpointLabels,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.pointRadius,
    required this.arrowSize,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleConnectedScatterView> createState() =>
      _SimpleConnectedScatterViewState();
}

class _SimpleConnectedScatterViewState
    extends State<_SimpleConnectedScatterView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  _ConnectedScatterPointLayout? _activePoint;
  Offset _pointer = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _SimpleConnectedScatterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geometry != widget.geometry ||
        oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.animationCurve != widget.animationCurve) {
      _controller.duration = widget.animationDuration;
      _animation = CurvedAnimation(
        parent: _controller,
        curve: widget.animationCurve,
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: MouseRegion(
              onHover: (event) {
                _pointer = event.localPosition;
                _setActive(_hitTest(event.localPosition));
              },
              onExit: (_) => _setActive(null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  _pointer = details.localPosition;
                  final point = _hitTest(details.localPosition);
                  _setActive(point);
                  if (point != null) {
                    widget.onPointTap?.call(
                      point.series!.series,
                      point.point,
                      point.seriesIndex,
                      point.pointIndex,
                    );
                  }
                },
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _SimpleConnectedScatterPainter(
                        geometry: widget.geometry,
                        xAxisLabel: widget.xAxisLabel,
                        yAxisLabel: widget.yAxisLabel,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showLines: widget.showLines,
                        showPoints: widget.showPoints,
                        showArrows: widget.showArrows,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showLegend: widget.showLegend,
                        showActivePoint: widget.showActivePoint,
                        showAxisLabels: widget.showAxisLabels,
                        showEndpointLabels: widget.showEndpointLabels,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        gridLineCount: widget.gridLineCount,
                        strokeWidth: widget.strokeWidth,
                        pointRadius: widget.pointRadius,
                        arrowSize: widget.arrowSize,
                        valueFormatter: widget.valueFormatter,
                        activePoint: _activePoint,
                        progress: _animation.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (widget.showTooltip && _activePoint != null)
            _buildTooltip(context, Size(widget.width, widget.height)),
        ],
      ),
    );
  }

  void _setActive(_ConnectedScatterPointLayout? point) {
    if (_activePoint?.seriesIndex == point?.seriesIndex &&
        _activePoint?.pointIndex == point?.pointIndex) {
      return;
    }
    setState(() => _activePoint = point);
  }

  _ConnectedScatterPointLayout? _hitTest(Offset position) {
    _ConnectedScatterPointLayout? nearest;
    var bestDistance = double.infinity;
    for (final series in widget.geometry.series) {
      for (final point in series.points) {
        final distance = (point.center - position).distance;
        if (distance <= widget.pointRadius + 8 && distance < bestDistance) {
          nearest = point;
          bestDistance = distance;
        }
      }
    }
    return nearest;
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final active = _activePoint!;
    final formattedValue = active.point.value == null
        ? null
        : widget.valueFormatter(active.point.value!);
    final child =
        widget.tooltipBuilder?.call(
          context,
          active.series!.series,
          active.point,
          active.seriesIndex,
          active.pointIndex,
          widget.xValueFormatter(active.point.x),
          widget.yValueFormatter(active.point.y),
          formattedValue,
        ) ??
        _DefaultConnectedScatterTooltip(
          series: active.series!.series,
          point: active.point,
          xAxisLabel: widget.xAxisLabel ?? 'x',
          yAxisLabel: widget.yAxisLabel ?? 'y',
          formattedX: widget.xValueFormatter(active.point.x),
          formattedY: widget.yValueFormatter(active.point.y),
          formattedValue: formattedValue,
        );
    const tooltipWidth = 184.0;
    const tooltipHeight = 120.0;
    final maxLeft = math.max(8.0, size.width - tooltipWidth - 8);
    final maxTop = math.max(8.0, size.height - tooltipHeight - 8);
    final left = (_pointer.dx + 12).clamp(8.0, maxLeft).toDouble();
    final top = (_pointer.dy - tooltipHeight - 8).clamp(8.0, maxTop).toDouble();
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(child: child),
    );
  }
}

class _SimpleConnectedScatterPainter extends CustomPainter {
  final _ConnectedScatterGeometry geometry;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLines;
  final bool showPoints;
  final bool showArrows;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActivePoint;
  final bool showAxisLabels;
  final bool showEndpointLabels;
  final List<SimpleScatterReferenceLine> referenceLines;
  final List<SimpleScatterReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double pointRadius;
  final double arrowSize;
  final SimpleConnectedScatterValueFormatter valueFormatter;
  final _ConnectedScatterPointLayout? activePoint;
  final double progress;

  const _SimpleConnectedScatterPainter({
    required this.geometry,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLines,
    required this.showPoints,
    required this.showArrows,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActivePoint,
    required this.showAxisLabels,
    required this.showEndpointLabels,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.pointRadius,
    required this.arrowSize,
    required this.valueFormatter,
    required this.activePoint,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawReferenceBands(canvas);
    if (showGrid) {
      _drawGrid(canvas);
    }
    _drawReferenceLines(canvas);
    _drawAxes(canvas);
    if (showLines) {
      _drawLines(canvas);
    }
    if (showPoints) {
      _drawPoints(canvas);
    }
    if (showLabels) {
      _drawLabels(canvas);
    }
    if (showLegend) {
      _drawLegend(canvas);
    }
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.88 * progress)
      ..strokeWidth = 1;
    for (var i = 0; i <= gridLineCount; i++) {
      final t = i / gridLineCount;
      final x = geometry.plotRect.left + geometry.plotRect.width * t;
      final y = geometry.plotRect.top + geometry.plotRect.height * t;
      canvas.drawLine(
        Offset(x, geometry.plotRect.top),
        Offset(x, geometry.plotRect.bottom),
        paint,
      );
      canvas.drawLine(
        Offset(geometry.plotRect.left, y),
        Offset(geometry.plotRect.right, y),
        paint,
      );
    }
  }

  void _drawReferenceBands(Canvas canvas) {
    for (final band in referenceBands) {
      final from = band.axis == SimpleScatterReferenceAxis.x
          ? geometry.xFor(band.from)
          : geometry.yFor(band.from);
      final to = band.axis == SimpleScatterReferenceAxis.x
          ? geometry.xFor(band.to)
          : geometry.yFor(band.to);
      final rect = band.axis == SimpleScatterReferenceAxis.x
          ? Rect.fromLTRB(
              math.min(from, to),
              geometry.plotRect.top,
              math.max(from, to),
              geometry.plotRect.bottom,
            )
          : Rect.fromLTRB(
              geometry.plotRect.left,
              math.min(from, to),
              geometry.plotRect.right,
              math.max(from, to),
            );
      canvas.drawRect(
        rect,
        Paint()
          ..color = (band.color ?? activeColor).withValues(
            alpha: band.opacity * progress,
          )
          ..style = PaintingStyle.fill,
      );
      if (band.showLabel && band.label != null) {
        _drawText(
          canvas,
          band.label!,
          rect.topLeft + const Offset(6, 5),
          labelStyle.copyWith(
            color: (labelStyle.color ?? Colors.black).withValues(
              alpha: 0.74 * progress,
            ),
          ),
          maxWidth: 96,
        );
      }
    }
  }

  void _drawReferenceLines(Canvas canvas) {
    for (final reference in referenceLines) {
      final color = (reference.color ?? activeColor).withValues(
        alpha: 0.78 * progress,
      );
      final paint = Paint()
        ..color = color
        ..strokeWidth = reference.strokeWidth
        ..style = PaintingStyle.stroke;
      final start = reference.axis == SimpleScatterReferenceAxis.x
          ? Offset(geometry.xFor(reference.value), geometry.plotRect.top)
          : Offset(geometry.plotRect.left, geometry.yFor(reference.value));
      final end = reference.axis == SimpleScatterReferenceAxis.x
          ? Offset(geometry.xFor(reference.value), geometry.plotRect.bottom)
          : Offset(geometry.plotRect.right, geometry.yFor(reference.value));
      _drawStyledLine(canvas, start, end, paint, reference.lineStyle);
      if (reference.showLabel && reference.label != null) {
        _drawText(
          canvas,
          reference.label!,
          start + const Offset(6, 5),
          labelStyle.copyWith(color: color),
          maxWidth: 90,
        );
      }
    }
  }

  void _drawAxes(Canvas canvas) {
    canvas.drawRect(
      geometry.plotRect,
      Paint()
        ..color = axisColor.withValues(alpha: 0.76 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    if (!showAxisLabels) {
      return;
    }
    if (xAxisLabel != null && xAxisLabel!.isNotEmpty) {
      _drawText(
        canvas,
        xAxisLabel!,
        Offset(geometry.plotRect.center.dx - 56, geometry.plotRect.bottom + 22),
        labelStyle,
        maxWidth: 112,
        align: TextAlign.center,
      );
    }
    if (yAxisLabel != null && yAxisLabel!.isNotEmpty) {
      _drawText(
        canvas,
        yAxisLabel!,
        Offset(geometry.plotRect.left - 46, geometry.plotRect.top - 2),
        labelStyle,
        maxWidth: 88,
      );
    }
  }

  void _drawLines(Canvas canvas) {
    for (final series in geometry.series) {
      if (series.points.length < 2) {
        continue;
      }
      final fade =
          activePoint == null || activePoint?.seriesIndex == series.index
          ? 1.0
          : 0.28;
      final paint = Paint()
        ..color = series.color.withValues(alpha: fade * progress)
        ..strokeWidth = series.strokeWidth ?? strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (var i = 0; i < series.points.length - 1; i++) {
        final start = series.points[i].center;
        final end = Offset.lerp(start, series.points[i + 1].center, progress)!;
        canvas.drawLine(start, end, paint);
        if (showArrows) {
          _drawArrow(canvas, start, end, series.color.withValues(alpha: fade));
        }
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Color color) {
    if ((end - start).distance < 10 || arrowSize <= 0) {
      return;
    }
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final back = end - Offset(math.cos(angle), math.sin(angle)) * 8;
    final left =
        back -
        Offset(math.cos(angle - math.pi / 6), math.sin(angle - math.pi / 6)) *
            arrowSize;
    final right =
        back -
        Offset(math.cos(angle + math.pi / 6), math.sin(angle + math.pi / 6)) *
            arrowSize;
    canvas.drawPath(
      Path()
        ..moveTo(back.dx, back.dy)
        ..lineTo(left.dx, left.dy)
        ..moveTo(back.dx, back.dy)
        ..lineTo(right.dx, right.dy),
      Paint()
        ..color = color.withValues(alpha: progress)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawPoints(Canvas canvas) {
    for (final series in geometry.series) {
      for (final point in series.points) {
        final active =
            activePoint?.seriesIndex == point.seriesIndex &&
            activePoint?.pointIndex == point.pointIndex;
        final opacity = activePoint == null || active ? 1.0 : 0.38;
        if (showActivePoint && active) {
          canvas.drawCircle(
            point.center,
            pointRadius + 7,
            Paint()
              ..color = activeColor.withValues(alpha: 0.18 * progress)
              ..style = PaintingStyle.fill,
          );
        }
        canvas.drawCircle(
          point.center,
          pointRadius + (active ? 1.5 : 0),
          Paint()
            ..color = point.color.withValues(alpha: opacity * progress)
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        canvas.drawCircle(
          point.center,
          pointRadius + (active ? 1.5 : 0),
          Paint()
            ..color = Colors.white.withValues(alpha: opacity * 0.78 * progress)
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 2 : 1.1,
        );
      }
    }
  }

  void _drawLabels(Canvas canvas) {
    for (final series in geometry.series) {
      for (final point in series.points) {
        final shouldShow = showEndpointLabels
            ? point.pointIndex == 0 ||
                  point.pointIndex == series.points.length - 1
            : true;
        if (!shouldShow) {
          continue;
        }
        final text = showValues && point.point.value != null
            ? '${point.point.label} ${valueFormatter(point.point.value!)}'
            : point.point.label;
        _drawText(
          canvas,
          text,
          Offset(point.center.dx + 7, point.center.dy - 8),
          valueStyle.copyWith(
            color: (valueStyle.color ?? Colors.black).withValues(
              alpha: 0.88 * progress,
            ),
          ),
          maxWidth: 96,
        );
      }
    }
  }

  void _drawLegend(Canvas canvas) {
    var dx = geometry.plotRect.left;
    final y = geometry.plotRect.bottom + 13;
    for (final series in geometry.series.take(4)) {
      canvas.drawCircle(
        Offset(dx + 5, y + 5),
        4,
        Paint()
          ..color = series.color.withValues(alpha: progress)
          ..style = PaintingStyle.fill,
      );
      final painter = _textPainter(
        series.series.name,
        valueStyle.copyWith(
          color: (valueStyle.color ?? Colors.black).withValues(alpha: progress),
        ),
        maxWidth: 82,
      );
      painter.paint(canvas, Offset(dx + 13, y - 2));
      dx += math.min(104, painter.width + 28);
      if (dx > geometry.plotRect.right - 72) {
        break;
      }
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
    final distance = (end - start).distance;
    if (distance <= 0) {
      return;
    }
    final direction = (end - start) / distance;
    final dash = style == SimpleChartReferenceLineStyle.dotted ? 1.5 : 6.0;
    final gap = style == SimpleChartReferenceLineStyle.dotted ? 5.0 : 4.0;
    var current = 0.0;
    while (current < distance) {
      final segmentEnd = math.min(current + dash, distance);
      canvas.drawLine(
        start + direction * current,
        start + direction * segmentEnd,
        paint,
      );
      current += dash + gap;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double? maxWidth,
    TextAlign align = TextAlign.left,
  }) {
    final painter = _textPainter(text, style, maxWidth: maxWidth, align: align);
    painter.paint(canvas, offset);
  }

  TextPainter _textPainter(
    String text,
    TextStyle style, {
    double? maxWidth,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    return painter;
  }

  @override
  bool shouldRepaint(covariant _SimpleConnectedScatterPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.xAxisLabel != xAxisLabel ||
        oldDelegate.yAxisLabel != yAxisLabel ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLines != showLines ||
        oldDelegate.showPoints != showPoints ||
        oldDelegate.showArrows != showArrows ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.showEndpointLabels != showEndpointLabels ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.arrowSize != arrowSize ||
        oldDelegate.activePoint != activePoint ||
        oldDelegate.progress != progress;
  }
}

class _ConnectedScatterGeometry {
  final Rect plotRect;
  final _ConnectedScatterScale scale;
  final List<_ConnectedScatterSeriesLayout> series;

  const _ConnectedScatterGeometry({
    required this.plotRect,
    required this.scale,
    required this.series,
  });

  factory _ConnectedScatterGeometry.resolve({
    required Size size,
    required List<SimpleConnectedScatterSeries> series,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
    required EdgeInsets padding,
    required List<Color> palette,
    required Color lineColor,
    required Color pointColor,
    required bool showLegend,
  }) {
    final legendHeight = showLegend ? 26.0 : 0.0;
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal),
      math.max(1, size.height - padding.vertical - legendHeight),
    );
    final scale = _ConnectedScatterScale.resolve(
      series: series,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
    final layouts = <_ConnectedScatterSeriesLayout>[];
    for (var i = 0; i < series.length; i++) {
      final item = series[i];
      final color =
          item.color ??
          (palette.isEmpty ? lineColor : palette[i % palette.length]);
      final points = <_ConnectedScatterPointLayout>[];
      for (var j = 0; j < item.points.length; j++) {
        final point = item.points[j];
        points.add(
          _ConnectedScatterPointLayout(
            seriesIndex: i,
            pointIndex: j,
            series: null,
            point: point,
            center: scale.toOffset(point.x, point.y, plotRect),
            color: point.color ?? item.color ?? color,
          ),
        );
      }
      final seriesLayout = _ConnectedScatterSeriesLayout(
        index: i,
        series: item,
        color: color,
        strokeWidth: item.strokeWidth,
        points: const [],
      );
      layouts.add(
        _ConnectedScatterSeriesLayout(
          index: i,
          series: item,
          color: color,
          strokeWidth: item.strokeWidth,
          points: points
              .map((point) => point.copyWith(series: seriesLayout))
              .toList(),
        ),
      );
    }
    return _ConnectedScatterGeometry(
      plotRect: plotRect,
      scale: scale,
      series: layouts,
    );
  }

  double xFor(double value) => scale.toOffset(value, scale.minY, plotRect).dx;

  double yFor(double value) => scale.toOffset(scale.minX, value, plotRect).dy;
}

class _ConnectedScatterScale {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _ConnectedScatterScale({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  factory _ConnectedScatterScale.resolve({
    required List<SimpleConnectedScatterSeries> series,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
  }) {
    final points = series.expand((item) => item.points).toList();
    var rawMinX = minX ?? points.map((point) => point.x).reduce(math.min);
    var rawMaxX = maxX ?? points.map((point) => point.x).reduce(math.max);
    var rawMinY = minY ?? points.map((point) => point.y).reduce(math.min);
    var rawMaxY = maxY ?? points.map((point) => point.y).reduce(math.max);
    if (rawMaxX <= rawMinX) {
      rawMinX -= 1;
      rawMaxX += 1;
    }
    if (rawMaxY <= rawMinY) {
      rawMinY -= 1;
      rawMaxY += 1;
    }
    return _ConnectedScatterScale(
      minX: rawMinX,
      maxX: rawMaxX,
      minY: rawMinY,
      maxY: rawMaxY,
    );
  }

  Offset toOffset(double x, double y, Rect plotRect) {
    final xRatio = ((x - minX) / (maxX - minX)).clamp(0.0, 1.0).toDouble();
    final yRatio = ((y - minY) / (maxY - minY)).clamp(0.0, 1.0).toDouble();
    return Offset(
      plotRect.left + plotRect.width * xRatio,
      plotRect.bottom - plotRect.height * yRatio,
    );
  }
}

class _ConnectedScatterSeriesLayout {
  final int index;
  final SimpleConnectedScatterSeries series;
  final Color color;
  final double? strokeWidth;
  final List<_ConnectedScatterPointLayout> points;

  const _ConnectedScatterSeriesLayout({
    required this.index,
    required this.series,
    required this.color,
    required this.strokeWidth,
    required this.points,
  });
}

class _ConnectedScatterPointLayout {
  final int seriesIndex;
  final int pointIndex;
  final _ConnectedScatterSeriesLayout? series;
  final SimpleConnectedScatterPoint point;
  final Offset center;
  final Color color;

  const _ConnectedScatterPointLayout({
    required this.seriesIndex,
    required this.pointIndex,
    required this.series,
    required this.point,
    required this.center,
    required this.color,
  });

  _ConnectedScatterPointLayout copyWith({
    _ConnectedScatterSeriesLayout? series,
  }) {
    return _ConnectedScatterPointLayout(
      seriesIndex: seriesIndex,
      pointIndex: pointIndex,
      series: series ?? this.series,
      point: point,
      center: center,
      color: color,
    );
  }
}

class _SimpleConnectedScatterVisuals {
  final Color lineColor;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color> palette;
  final double strokeWidth;

  const _SimpleConnectedScatterVisuals({
    required this.lineColor,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
    required this.strokeWidth,
  });

  factory _SimpleConnectedScatterVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleConnectedScatterVisuals(
          lineColor: colorScheme.primary,
          pointColor: colorScheme.primary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
          axisColor: colorScheme.outline.withValues(alpha: 0.64),
          activeColor: colorScheme.primary,
          palette: const [
            Color(0xFF2563EB),
            Color(0xFF10B981),
            Color(0xFFF59E0B),
            Color(0xFFEF4444),
          ],
          strokeWidth: 2.6,
        );
      case SimpleBarChartStyle.professional:
        return const _SimpleConnectedScatterVisuals(
          lineColor: Color(0xFF1D4ED8),
          pointColor: Color(0xFF1D4ED8),
          gridColor: Color(0xFFE2E8F0),
          axisColor: Color(0xFF64748B),
          activeColor: Color(0xFF0F172A),
          palette: [
            Color(0xFF1D4ED8),
            Color(0xFF0F766E),
            Color(0xFF7C2D12),
            Color(0xFF6D28D9),
          ],
          strokeWidth: 2.2,
        );
      case SimpleBarChartStyle.education:
        return const _SimpleConnectedScatterVisuals(
          lineColor: Color(0xFF2563EB),
          pointColor: Color(0xFF2563EB),
          gridColor: Color(0xFFE2E8F0),
          axisColor: Color(0xFF94A3B8),
          activeColor: Color(0xFFF97316),
          palette: [
            Color(0xFF2563EB),
            Color(0xFFF97316),
            Color(0xFF16A34A),
            Color(0xFFDB2777),
          ],
          strokeWidth: 2.6,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleConnectedScatterVisuals(
          lineColor: const Color(0xFF14B8A6),
          pointColor: const Color(0xFF14B8A6),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
          axisColor: colorScheme.outline.withValues(alpha: 0.58),
          activeColor: const Color(0xFFF43F5E),
          palette: const [
            Color(0xFF14B8A6),
            Color(0xFFF43F5E),
            Color(0xFF8B5CF6),
            Color(0xFFF59E0B),
          ],
          strokeWidth: 2.8,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleConnectedScatterVisuals(
          lineColor: colorScheme.secondary,
          pointColor: colorScheme.secondary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
          activeColor: colorScheme.secondary,
          palette: const [
            Color(0xFF0F766E),
            Color(0xFF7C3AED),
            Color(0xFF2563EB),
            Color(0xFFE11D48),
          ],
          strokeWidth: 2.4,
        );
    }
  }
}

class _DefaultConnectedScatterTooltip extends StatelessWidget {
  final SimpleConnectedScatterSeries series;
  final SimpleConnectedScatterPoint point;
  final String xAxisLabel;
  final String yAxisLabel;
  final String formattedX;
  final String formattedY;
  final String? formattedValue;

  const _DefaultConnectedScatterTooltip({
    required this.series,
    required this.point,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.formattedX,
    required this.formattedY,
    required this.formattedValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 184,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style:
              theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onInverseSurface,
                fontWeight: FontWeight.w600,
              ) ??
              TextStyle(
                color: colorScheme.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                point.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(series.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 7),
              _TooltipRow(label: xAxisLabel, value: formattedX),
              _TooltipRow(label: yAxisLabel, value: formattedY),
              if (formattedValue != null)
                _TooltipRow(label: 'Value', value: formattedValue!),
            ],
          ),
        ),
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _TooltipRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
