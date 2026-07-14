import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleParallelValueFormatter = String Function(double value);
typedef SimpleParallelSeriesTapCallback =
    void Function(SimpleParallelSeries series, int index);
typedef SimpleParallelTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleParallelSeries series,
      int index,
      Map<String, String> formattedValues,
    );

class SimpleParallelAxis {
  final String label;
  final double? min;
  final double? max;
  final bool inverted;
  final Color? color;

  const SimpleParallelAxis({
    required this.label,
    this.min,
    this.max,
    this.inverted = false,
    this.color,
  });
}

class SimpleParallelSeries {
  final String label;
  final List<double> values;
  final String? group;
  final Color? color;

  const SimpleParallelSeries({
    required this.label,
    required this.values,
    this.group,
    this.color,
  });
}

/// A compact parallel coordinates chart for multivariate comparison across
/// products, cohorts, models, suppliers, schools, teams, or operational units.
class SimpleParallelCoordinatesChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(54, 20, 28, 46);

  final List<SimpleParallelAxis> axes;
  final List<SimpleParallelSeries> series;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? lineColor;
  final Color? axisColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showAxisRangeLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSeries;
  final int gridLineCount;
  final double strokeWidth;
  final double activeStrokeWidth;
  final double lineOpacity;
  final double pointRadius;
  final SimpleParallelValueFormatter? valueFormatter;
  final SimpleParallelSeriesTapCallback? onSeriesTap;
  final SimpleParallelTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleParallelCoordinatesChart({
    super.key,
    required this.axes,
    required this.series,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 280,
    this.padding = _defaultPadding,
    this.palette,
    this.lineColor,
    this.axisColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = false,
    this.showAxisRangeLabels = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveSeries = true,
    this.gridLineCount = 4,
    this.strokeWidth = 2,
    this.activeStrokeWidth = 3.4,
    this.lineOpacity = 0.42,
    this.pointRadius = 3.5,
    this.valueFormatter,
    this.onSeriesTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(strokeWidth >= 0),
       assert(activeStrokeWidth >= 0),
       assert(lineOpacity >= 0 && lineOpacity <= 1),
       assert(pointRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleParallelVisuals.resolve(style, colorScheme);
    final visibleAxes = axes
        .where((axis) => axis.label.trim().isNotEmpty)
        .toList();
    final axisCount = visibleAxes.length;
    final visibleSeries = series
        .where(
          (item) =>
              item.label.trim().isNotEmpty &&
              item.values.length >= axisCount &&
              item.values.take(axisCount).every((value) => value.isFinite),
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (axisCount < 2 || visibleSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Parallel coordinates chart, no data.',
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
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleAxes,
            visibleSeries,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleParallelCoordinatesChartView(
            width: width,
            height: chartHeight,
            axes: visibleAxes,
            series: visibleSeries,
            padding: padding,
            palette: palette ?? visuals.palette,
            lineColor: lineColor ?? visuals.lineColor,
            axisColor: axisColor ?? visuals.axisColor,
            gridColor: gridColor ?? visuals.gridColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showLabels: showLabels,
            showValues: showValues,
            showAxisRangeLabels: showAxisRangeLabels,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveSeries: showActiveSeries,
            gridLineCount: gridLineCount,
            strokeWidth: strokeWidth,
            activeStrokeWidth: activeStrokeWidth,
            lineOpacity: lineOpacity,
            pointRadius: pointRadius,
            valueFormatter: formatter,
            onSeriesTap: onSeriesTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleParallelAxis> axes,
    List<SimpleParallelSeries> series,
    SimpleParallelValueFormatter formatter,
  ) {
    final sample = series
        .take(3)
        .map((item) {
          final values = List.generate(
            axes.length,
            (index) => '${axes[index].label} ${formatter(item.values[index])}',
          ).join(', ');
          return '${item.label}: $values';
        })
        .join('; ');
    final suffix = series.length > 3 ? '; and ${series.length - 3} more' : '';
    return 'Parallel coordinates chart, ${axes.length} axes and '
        '${series.length} series. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value.abs() >= 1000) {
      final precision = value.abs() >= 10000 ? 0 : 1;
      return '${(value / 1000).toStringAsFixed(precision)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleParallelCoordinatesChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleParallelAxis> axes;
  final List<SimpleParallelSeries> series;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color lineColor;
  final Color axisColor;
  final Color gridColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showAxisRangeLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSeries;
  final int gridLineCount;
  final double strokeWidth;
  final double activeStrokeWidth;
  final double lineOpacity;
  final double pointRadius;
  final SimpleParallelValueFormatter valueFormatter;
  final SimpleParallelSeriesTapCallback? onSeriesTap;
  final SimpleParallelTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleParallelCoordinatesChartView({
    required this.width,
    required this.height,
    required this.axes,
    required this.series,
    required this.padding,
    required this.palette,
    required this.lineColor,
    required this.axisColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showAxisRangeLabels,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveSeries,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.activeStrokeWidth,
    required this.lineOpacity,
    required this.pointRadius,
    required this.valueFormatter,
    required this.onSeriesTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleParallelCoordinatesChartView> createState() =>
      _SimpleParallelCoordinatesChartViewState();
}

class _SimpleParallelCoordinatesChartViewState
    extends State<_SimpleParallelCoordinatesChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int? _activeIndex;

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
  void didUpdateWidget(
    covariant _SimpleParallelCoordinatesChartView oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.axes != widget.axes ||
        oldWidget.series != widget.series ||
        oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.animationCurve != widget.animationCurve) {
      _controller.duration = widget.animationDuration;
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
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onExit: (_) => _setActive(null),
                  onHover: (event) {
                    if (widget.showActiveSeries ||
                        widget.showTooltip ||
                        widget.onSeriesTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final index = _hitTest(details.localPosition);
                      _setActive(index);
                      if (index != null) {
                        widget.onSeriesTap?.call(widget.series[index], index);
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleParallelPainter(
                        axes: widget.axes,
                        series: widget.series,
                        padding: widget.padding,
                        palette: widget.palette,
                        lineColor: widget.lineColor,
                        axisColor: widget.axisColor,
                        gridColor: widget.gridColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showAxisRangeLabels: widget.showAxisRangeLabels,
                        showLegend: widget.showLegend,
                        showActiveSeries: widget.showActiveSeries,
                        gridLineCount: widget.gridLineCount,
                        strokeWidth: widget.strokeWidth,
                        activeStrokeWidth: widget.activeStrokeWidth,
                        lineOpacity: widget.lineOpacity,
                        pointRadius: widget.pointRadius,
                        valueFormatter: widget.valueFormatter,
                        activeIndex: _activeIndex,
                        progress: _animation.value,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeIndex != null)
                _buildTooltip(context, _activeIndex!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(int? index) {
    if (_activeIndex == index) {
      return;
    }
    setState(() => _activeIndex = index);
  }

  int? _hitTest(Offset position) {
    final geometry = _ParallelGeometry.resolve(
      axes: widget.axes,
      series: widget.series,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
    );
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (final line in geometry.lines) {
      final distance = line.distanceTo(position);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = line.index;
      }
    }
    if (bestIndex >= 0 && bestDistance <= 12) {
      return bestIndex;
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, int index) {
    final item = widget.series[index];
    final formattedValues = <String, String>{};
    for (var axisIndex = 0; axisIndex < widget.axes.length; axisIndex++) {
      formattedValues[widget.axes[axisIndex].label] = widget.valueFormatter(
        item.values[axisIndex],
      );
    }
    final tooltip =
        widget.tooltipBuilder?.call(context, item, index, formattedValues) ??
        _DefaultParallelTooltip(
          title: item.label,
          rows: formattedValues.entries
              .map((entry) => _TooltipRow(entry.key, entry.value))
              .toList(),
        );
    final geometry = _ParallelGeometry.resolve(
      axes: widget.axes,
      series: widget.series,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
    );
    final anchor = geometry.lines[index].points[geometry.axes.length ~/ 2];
    final maxLeft = math.max(8.0, widget.width - 226);
    final maxTop = math.max(8.0, widget.height - 160);
    final left = (anchor.dx + 12).clamp(8.0, maxLeft).toDouble();
    final top = (anchor.dy - 58).clamp(8.0, maxTop).toDouble();
    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleParallelPainter extends CustomPainter {
  final List<SimpleParallelAxis> axes;
  final List<SimpleParallelSeries> series;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color lineColor;
  final Color axisColor;
  final Color gridColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showAxisRangeLabels;
  final bool showLegend;
  final bool showActiveSeries;
  final int gridLineCount;
  final double strokeWidth;
  final double activeStrokeWidth;
  final double lineOpacity;
  final double pointRadius;
  final SimpleParallelValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleParallelPainter({
    required this.axes,
    required this.series,
    required this.padding,
    required this.palette,
    required this.lineColor,
    required this.axisColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showAxisRangeLabels,
    required this.showLegend,
    required this.showActiveSeries,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.activeStrokeWidth,
    required this.lineOpacity,
    required this.pointRadius,
    required this.valueFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _ParallelGeometry.resolve(
      axes: axes,
      series: series,
      size: size,
      padding: padding,
    );
    if (geometry.axes.length < 2 || geometry.lines.isEmpty) {
      return;
    }

    if (showGrid) {
      _drawGrid(canvas, geometry);
    }
    _drawAxes(canvas, geometry);
    for (final line in geometry.lines) {
      if (line.index != activeIndex) {
        _drawLine(canvas, line);
      }
    }
    if (showActiveSeries && activeIndex != null) {
      final active = geometry.lines.firstWhere(
        (line) => line.index == activeIndex,
        orElse: () => geometry.lines.first,
      );
      _drawLine(canvas, active, active: true);
    }
    if (showLegend) {
      _drawLegend(canvas, geometry);
    }
  }

  void _drawGrid(Canvas canvas, _ParallelGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 0; index < gridLineCount; index++) {
      final ratio = gridLineCount == 1 ? 0.0 : index / (gridLineCount - 1);
      final y = geometry.plot.bottom - geometry.plot.height * ratio;
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
    }
  }

  void _drawAxes(Canvas canvas, _ParallelGeometry geometry) {
    for (final axis in geometry.axes) {
      final color = axis.axis.color ?? axisColor;
      canvas.drawLine(
        Offset(axis.x, geometry.plot.top),
        Offset(axis.x, geometry.plot.bottom),
        Paint()
          ..color = color.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      if (showLabels) {
        _drawText(
          canvas,
          axis.axis.label,
          Rect.fromCenter(
            center: Offset(axis.x, geometry.plot.bottom + 16),
            width: math.min(90, math.max(44, geometry.axisGap + 18)),
            height: 16,
          ),
          labelStyle.copyWith(color: color),
          align: TextAlign.center,
        );
      }
      if (showAxisRangeLabels) {
        _drawText(
          canvas,
          valueFormatter(axis.axis.inverted ? axis.min : axis.max),
          Rect.fromCenter(
            center: Offset(axis.x, geometry.plot.top - 8),
            width: 54,
            height: 14,
          ),
          valueStyle.copyWith(color: color.withValues(alpha: 0.82)),
          align: TextAlign.center,
        );
        _drawText(
          canvas,
          valueFormatter(axis.axis.inverted ? axis.max : axis.min),
          Rect.fromCenter(
            center: Offset(axis.x, geometry.plot.bottom + 32),
            width: 54,
            height: 14,
          ),
          valueStyle.copyWith(color: color.withValues(alpha: 0.82)),
          align: TextAlign.center,
        );
      }
    }
  }

  void _drawLine(
    Canvas canvas,
    _ParallelLineLayout line, {
    bool active = false,
  }) {
    final color = active
        ? activeColor
        : line.series.color ?? _colorFor(line.index);
    final visiblePoints = _progressPoints(line.points);
    if (visiblePoints.length >= 2) {
      final path = Path()
        ..moveTo(visiblePoints.first.dx, visiblePoints.first.dy);
      for (final point in visiblePoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: active ? 0.95 : lineOpacity)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = active ? activeStrokeWidth : strokeWidth,
      );
    }
    for (var index = 0; index < visiblePoints.length; index++) {
      final point = visiblePoints[index];
      canvas.drawCircle(
        point,
        active ? pointRadius + 1.5 : pointRadius,
        Paint()
          ..color = color.withValues(alpha: active ? 1 : 0.78)
          ..style = PaintingStyle.fill,
      );
      if (showValues && active) {
        _drawText(
          canvas,
          valueFormatter(line.series.values[index]),
          Rect.fromCenter(
            center: point - const Offset(0, 12),
            width: 48,
            height: 14,
          ),
          valueStyle.copyWith(color: color, fontWeight: FontWeight.w800),
          align: TextAlign.center,
        );
      }
    }
  }

  List<Offset> _progressPoints(List<Offset> points) {
    if (points.isEmpty) {
      return const [];
    }
    if (points.length == 1) {
      return [points.first];
    }
    final segmentCount = points.length - 1;
    final scaled = progress * segmentCount;
    final complete = scaled.floor().clamp(0, segmentCount);
    final partial = (scaled - complete).clamp(0.0, 1.0);
    final result = <Offset>[];
    for (var index = 0; index <= complete; index++) {
      result.add(points[index]);
    }
    if (complete < segmentCount) {
      result.add(Offset.lerp(points[complete], points[complete + 1], partial)!);
    }
    return result;
  }

  void _drawLegend(Canvas canvas, _ParallelGeometry geometry) {
    if (geometry.plot.width < 180 || series.length > 6) {
      return;
    }
    var dx = geometry.plot.left;
    final y = geometry.plot.top - 20;
    for (var index = 0; index < series.length; index++) {
      final color = series[index].color ?? _colorFor(index);
      canvas.drawCircle(
        Offset(dx + 5, y + 8),
        4,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      final width = math.min(86.0, geometry.plot.right - dx - 10);
      if (width < 36) {
        return;
      }
      _drawText(
        canvas,
        series[index].label,
        Rect.fromLTWH(dx + 14, y, width, 16),
        valueStyle.copyWith(color: color),
      );
      dx += width + 18;
      if (dx > geometry.plot.right - 28) {
        return;
      }
    }
  }

  Color _colorFor(int index) {
    if (palette.isNotEmpty) {
      return palette[index % palette.length];
    }
    return lineColor;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: rect.width);
    final dx = switch (align) {
      TextAlign.right => rect.right - painter.width,
      TextAlign.center => rect.left + (rect.width - painter.width) / 2,
      _ => rect.left,
    };
    final dy = rect.top + (rect.height - painter.height) / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _SimpleParallelPainter oldDelegate) {
    return oldDelegate.axes != axes ||
        oldDelegate.series != series ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showAxisRangeLabels != showAxisRangeLabels ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveSeries != showActiveSeries ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.activeStrokeWidth != activeStrokeWidth ||
        oldDelegate.lineOpacity != lineOpacity ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _ParallelGeometry {
  final Rect plot;
  final List<_ParallelAxisLayout> axes;
  final List<_ParallelLineLayout> lines;
  final double axisGap;

  const _ParallelGeometry({
    required this.plot,
    required this.axes,
    required this.lines,
    required this.axisGap,
  });

  factory _ParallelGeometry.resolve({
    required List<SimpleParallelAxis> axes,
    required List<SimpleParallelSeries> series,
    required Size size,
    required EdgeInsets padding,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    if (axes.length < 2 ||
        series.isEmpty ||
        plot.width <= 0 ||
        plot.height <= 0) {
      return _ParallelGeometry(
        plot: plot,
        axes: const [],
        lines: const [],
        axisGap: 0,
      );
    }
    final axisGap = plot.width / (axes.length - 1);
    final axisLayouts = <_ParallelAxisLayout>[];
    for (var axisIndex = 0; axisIndex < axes.length; axisIndex++) {
      final values = series.map((item) => item.values[axisIndex]).toList();
      var min = axes[axisIndex].min ?? values.reduce(math.min);
      var max = axes[axisIndex].max ?? values.reduce(math.max);
      if (min == max) {
        min -= 1;
        max += 1;
      }
      if (min > max) {
        final temp = min;
        min = max;
        max = temp;
      }
      axisLayouts.add(
        _ParallelAxisLayout(
          index: axisIndex,
          axis: axes[axisIndex],
          x: plot.left + axisGap * axisIndex,
          min: min,
          max: max,
        ),
      );
    }
    final lines = <_ParallelLineLayout>[];
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final item = series[seriesIndex];
      final points = <Offset>[];
      for (final axis in axisLayouts) {
        final value = item.values[axis.index];
        var ratio = ((value - axis.min) / axis.range).clamp(0.0, 1.0);
        if (axis.axis.inverted) {
          ratio = 1 - ratio;
        }
        points.add(Offset(axis.x, plot.bottom - plot.height * ratio));
      }
      lines.add(
        _ParallelLineLayout(index: seriesIndex, series: item, points: points),
      );
    }
    return _ParallelGeometry(
      plot: plot,
      axes: axisLayouts,
      lines: lines,
      axisGap: axisGap,
    );
  }
}

class _ParallelAxisLayout {
  final int index;
  final SimpleParallelAxis axis;
  final double x;
  final double min;
  final double max;

  const _ParallelAxisLayout({
    required this.index,
    required this.axis,
    required this.x,
    required this.min,
    required this.max,
  });

  double get range => math.max(0.0001, max - min);
}

class _ParallelLineLayout {
  final int index;
  final SimpleParallelSeries series;
  final List<Offset> points;

  const _ParallelLineLayout({
    required this.index,
    required this.series,
    required this.points,
  });

  double distanceTo(Offset position) {
    var best = double.infinity;
    for (var index = 0; index < points.length - 1; index++) {
      best = math.min(
        best,
        _distanceToSegment(position, points[index], points[index + 1]),
      );
    }
    return best;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared <= 0) {
      return (p - a).distance;
    }
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projection).distance;
  }
}

class _SimpleParallelVisuals {
  final List<Color> palette;
  final Color lineColor;
  final Color axisColor;
  final Color gridColor;
  final Color activeColor;

  const _SimpleParallelVisuals({
    required this.palette,
    required this.lineColor,
    required this.axisColor,
    required this.gridColor,
    required this.activeColor,
  });

  factory _SimpleParallelVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleParallelVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFFF97316),
          ],
          lineColor: colorScheme.primary,
          axisColor: colorScheme.outline.withValues(alpha: 0.58),
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          activeColor: colorScheme.tertiary,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleParallelVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            const Color(0xFF0F766E),
            const Color(0xFF64748B),
            const Color(0xFF1D4ED8),
          ],
          lineColor: colorScheme.primary,
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          activeColor: colorScheme.onSurface,
        );
      case SimpleBarChartStyle.education:
        return _SimpleParallelVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFFF59E0B),
            const Color(0xFF22C55E),
          ],
          lineColor: colorScheme.secondary,
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleParallelVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFEC4899),
            const Color(0xFFF97316),
          ],
          lineColor: colorScheme.tertiary,
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleParallelVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
            const Color(0xFFF59E0B),
          ],
          lineColor: colorScheme.primary,
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          activeColor: colorScheme.tertiary,
        );
    }
  }
}

class _DefaultParallelTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultParallelTooltip({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: DefaultTextStyle(
            style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 58, child: Text(row.label)),
                        Flexible(
                          child: Text(
                            row.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TooltipRow {
  final String label;
  final String value;

  const _TooltipRow(this.label, this.value);
}
