import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleContourValueFormatter = String Function(double value);
typedef SimpleContourTapCallback = void Function(SimpleContourSelection hit);
typedef SimpleContourTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleContourSelection hit,
      String formattedX,
      String formattedY,
      String formattedValue,
      String formattedRange,
    );

class SimpleContourPoint {
  final String label;
  final double x;
  final double y;
  final double value;
  final Color? color;

  const SimpleContourPoint({
    required this.label,
    required this.x,
    required this.y,
    required this.value,
    this.color,
  });
}

class SimpleContourSelection {
  final double x;
  final double y;
  final double value;
  final double lowerBound;
  final double upperBound;
  final int bandIndex;
  final SimpleContourPoint? nearestPoint;

  const SimpleContourSelection({
    required this.x,
    required this.y,
    required this.value,
    required this.lowerBound,
    required this.upperBound,
    required this.bandIndex,
    this.nearestPoint,
  });
}

/// A simple contour chart for risk surfaces, demand fields, performance
/// landscapes, geographic-like intensity, and scientific/education dashboards.
class SimpleContourChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 24, 42);

  final List<SimpleContourPoint> points;
  final SimpleBarChartStyle style;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color? lowColor;
  final Color? highColor;
  final Color? lineColor;
  final Color? pointColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showFilledBands;
  final bool showContourLines;
  final bool showSamplePoints;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSelection;
  final bool showAxisLabels;
  final int gridLineCount;
  final int gridResolution;
  final int levelCount;
  final double contourLineWidth;
  final double pointRadius;
  final double interpolationPower;
  final List<double> levels;
  final SimpleContourValueFormatter? xValueFormatter;
  final SimpleContourValueFormatter? yValueFormatter;
  final SimpleContourValueFormatter? valueFormatter;
  final SimpleContourTapCallback? onSelectionTap;
  final SimpleContourTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleContourChart({
    super.key,
    required this.points,
    this.style = SimpleBarChartStyle.elegant,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.xAxisLabel,
    this.yAxisLabel,
    this.lowColor,
    this.highColor,
    this.lineColor,
    this.pointColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showFilledBands = true,
    this.showContourLines = true,
    this.showSamplePoints = true,
    this.showLabels = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveSelection = true,
    this.showAxisLabels = true,
    this.gridLineCount = 4,
    this.gridResolution = 26,
    this.levelCount = 6,
    this.contourLineWidth = 1.2,
    this.pointRadius = 4,
    this.interpolationPower = 2,
    this.levels = const [],
    this.xValueFormatter,
    this.yValueFormatter,
    this.valueFormatter,
    this.onSelectionTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(gridResolution >= 8),
       assert(levelCount >= 2),
       assert(contourLineWidth > 0),
       assert(pointRadius >= 0),
       assert(interpolationPower > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleContourVisuals.resolve(style, colorScheme);
    final visiblePoints = points
        .where(
          (point) =>
              point.x.isFinite && point.y.isFinite && point.value.isFinite,
        )
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

        if (visiblePoints.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Contour chart, no data.',
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

        final geometry = _ContourGeometry.resolve(
          size: Size(width, chartHeight),
          points: visiblePoints,
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          minValue: minValue,
          maxValue: maxValue,
          padding: padding,
          showLegend: showLegend,
          gridResolution: gridResolution,
          levelCount: levelCount,
          levels: levels,
          interpolationPower: interpolationPower,
        );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visiblePoints,
            xFormatter,
            yFormatter,
            resolvedValueFormatter,
            xAxisLabel,
            yAxisLabel,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleContourView(
            width: width,
            height: chartHeight,
            points: visiblePoints,
            geometry: geometry,
            padding: padding,
            xAxisLabel: xAxisLabel,
            yAxisLabel: yAxisLabel,
            palette: palette ?? visuals.palette,
            lowColor: lowColor ?? visuals.lowColor,
            highColor: highColor ?? visuals.highColor,
            lineColor: lineColor ?? visuals.lineColor,
            pointColor: pointColor ?? visuals.pointColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showFilledBands: showFilledBands,
            showContourLines: showContourLines,
            showSamplePoints: showSamplePoints,
            showLabels: showLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveSelection: showActiveSelection,
            showAxisLabels: showAxisLabels,
            gridLineCount: gridLineCount,
            contourLineWidth: contourLineWidth,
            pointRadius: pointRadius,
            xValueFormatter: xFormatter,
            yValueFormatter: yFormatter,
            valueFormatter: resolvedValueFormatter,
            onSelectionTap: onSelectionTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleContourPoint> points,
    SimpleContourValueFormatter xFormatter,
    SimpleContourValueFormatter yFormatter,
    SimpleContourValueFormatter valueFormatter,
    String? xAxisLabel,
    String? yAxisLabel,
  ) {
    final xLabel = xAxisLabel ?? 'x';
    final yLabel = yAxisLabel ?? 'y';
    final sample = points
        .take(6)
        .map(
          (point) =>
              '${point.label} $xLabel ${xFormatter(point.x)}, '
              '$yLabel ${yFormatter(point.y)}, '
              'value ${valueFormatter(point.value)}',
        )
        .join(', ');
    final suffix = points.length > 6 ? ', and ${points.length - 6} more' : '';
    return 'Contour chart, ${points.length} samples. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleContourView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleContourPoint> points;
  final _ContourGeometry geometry;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final List<Color> palette;
  final Color lowColor;
  final Color highColor;
  final Color lineColor;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showFilledBands;
  final bool showContourLines;
  final bool showSamplePoints;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSelection;
  final bool showAxisLabels;
  final int gridLineCount;
  final double contourLineWidth;
  final double pointRadius;
  final SimpleContourValueFormatter xValueFormatter;
  final SimpleContourValueFormatter yValueFormatter;
  final SimpleContourValueFormatter valueFormatter;
  final SimpleContourTapCallback? onSelectionTap;
  final SimpleContourTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleContourView({
    required this.width,
    required this.height,
    required this.points,
    required this.geometry,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.palette,
    required this.lowColor,
    required this.highColor,
    required this.lineColor,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showFilledBands,
    required this.showContourLines,
    required this.showSamplePoints,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveSelection,
    required this.showAxisLabels,
    required this.gridLineCount,
    required this.contourLineWidth,
    required this.pointRadius,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.valueFormatter,
    required this.onSelectionTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleContourView> createState() => _SimpleContourViewState();
}

class _SimpleContourViewState extends State<_SimpleContourView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  SimpleContourSelection? _activeSelection;
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
  void didUpdateWidget(covariant _SimpleContourView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points ||
        oldWidget.geometry != widget.geometry ||
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
                _setActive(_selectionFor(event.localPosition));
              },
              onExit: (_) => _setActive(null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  _pointer = details.localPosition;
                  final hit = _selectionFor(details.localPosition);
                  _setActive(hit);
                  if (hit != null) {
                    widget.onSelectionTap?.call(hit);
                  }
                },
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _SimpleContourPainter(
                        geometry: widget.geometry,
                        points: widget.points,
                        xAxisLabel: widget.xAxisLabel,
                        yAxisLabel: widget.yAxisLabel,
                        palette: widget.palette,
                        lowColor: widget.lowColor,
                        highColor: widget.highColor,
                        lineColor: widget.lineColor,
                        pointColor: widget.pointColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showFilledBands: widget.showFilledBands,
                        showContourLines: widget.showContourLines,
                        showSamplePoints: widget.showSamplePoints,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showLegend: widget.showLegend,
                        showActiveSelection: widget.showActiveSelection,
                        showAxisLabels: widget.showAxisLabels,
                        gridLineCount: widget.gridLineCount,
                        contourLineWidth: widget.contourLineWidth,
                        pointRadius: widget.pointRadius,
                        valueFormatter: widget.valueFormatter,
                        activeSelection: _activeSelection,
                        progress: _animation.value,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (widget.showTooltip && _activeSelection != null)
            _buildTooltip(context, Size(widget.width, widget.height)),
        ],
      ),
    );
  }

  void _setActive(SimpleContourSelection? hit) {
    if (_activeSelection?.x == hit?.x &&
        _activeSelection?.y == hit?.y &&
        _activeSelection?.bandIndex == hit?.bandIndex) {
      return;
    }
    setState(() => _activeSelection = hit);
  }

  SimpleContourSelection? _selectionFor(Offset position) {
    final geometry = widget.geometry;
    if (!geometry.plotRect.contains(position)) {
      return null;
    }
    final xRatio =
        ((position.dx - geometry.plotRect.left) / geometry.plotRect.width)
            .clamp(0.0, 1.0)
            .toDouble();
    final yRatio =
        ((geometry.plotRect.bottom - position.dy) / geometry.plotRect.height)
            .clamp(0.0, 1.0)
            .toDouble();
    final x =
        geometry.scale.minX +
        (geometry.scale.maxX - geometry.scale.minX) * xRatio;
    final y =
        geometry.scale.minY +
        (geometry.scale.maxY - geometry.scale.minY) * yRatio;
    final value = geometry.interpolate(x, y);
    final bandIndex = geometry.bandIndexFor(value);
    final bounds = geometry.bandRange(bandIndex);
    return SimpleContourSelection(
      x: x,
      y: y,
      value: value,
      lowerBound: bounds.$1,
      upperBound: bounds.$2,
      bandIndex: bandIndex,
      nearestPoint: geometry.nearestPoint(position),
    );
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final hit = _activeSelection!;
    final formattedX = widget.xValueFormatter(hit.x);
    final formattedY = widget.yValueFormatter(hit.y);
    final formattedValue = widget.valueFormatter(hit.value);
    final formattedRange =
        '${widget.valueFormatter(hit.lowerBound)} - ${widget.valueFormatter(hit.upperBound)}';
    final child =
        widget.tooltipBuilder?.call(
          context,
          hit,
          formattedX,
          formattedY,
          formattedValue,
          formattedRange,
        ) ??
        _DefaultContourTooltip(
          hit: hit,
          xAxisLabel: widget.xAxisLabel ?? 'x',
          yAxisLabel: widget.yAxisLabel ?? 'y',
          formattedX: formattedX,
          formattedY: formattedY,
          formattedValue: formattedValue,
          formattedRange: formattedRange,
        );
    const tooltipWidth = 184.0;
    const tooltipHeight = 128.0;
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

class _SimpleContourPainter extends CustomPainter {
  final _ContourGeometry geometry;
  final List<SimpleContourPoint> points;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final List<Color> palette;
  final Color lowColor;
  final Color highColor;
  final Color lineColor;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showFilledBands;
  final bool showContourLines;
  final bool showSamplePoints;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActiveSelection;
  final bool showAxisLabels;
  final int gridLineCount;
  final double contourLineWidth;
  final double pointRadius;
  final SimpleContourValueFormatter valueFormatter;
  final SimpleContourSelection? activeSelection;
  final double progress;

  const _SimpleContourPainter({
    required this.geometry,
    required this.points,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.palette,
    required this.lowColor,
    required this.highColor,
    required this.lineColor,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showFilledBands,
    required this.showContourLines,
    required this.showSamplePoints,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActiveSelection,
    required this.showAxisLabels,
    required this.gridLineCount,
    required this.contourLineWidth,
    required this.pointRadius,
    required this.valueFormatter,
    required this.activeSelection,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      _drawGrid(canvas);
    }
    canvas.save();
    canvas.clipRect(geometry.plotRect);
    if (showFilledBands) {
      _drawFilledBands(canvas);
    }
    if (showContourLines) {
      _drawContourLines(canvas);
    }
    if (showActiveSelection && activeSelection != null) {
      _drawActiveSelection(canvas);
    }
    canvas.restore();
    _drawAxes(canvas);
    if (showSamplePoints) {
      _drawSamplePoints(canvas);
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
      ..color = gridColor.withValues(alpha: 0.84 * progress)
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

  void _drawFilledBands(Canvas canvas) {
    final xStep = geometry.plotRect.width / geometry.gridResolution;
    final yStep = geometry.plotRect.height / geometry.gridResolution;
    for (var row = 0; row < geometry.gridResolution; row++) {
      for (var col = 0; col < geometry.gridResolution; col++) {
        final average =
            (geometry.values[row][col] +
                geometry.values[row][col + 1] +
                geometry.values[row + 1][col] +
                geometry.values[row + 1][col + 1]) /
            4;
        final rect = Rect.fromLTWH(
          geometry.plotRect.left + col * xStep,
          geometry.plotRect.top + row * yStep,
          xStep + 0.7,
          yStep + 0.7,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = _colorFor(average).withValues(alpha: 0.72 * progress)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _drawContourLines(Canvas canvas) {
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.7 * progress)
      ..strokeWidth = contourLineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final level in geometry.lineLevels) {
      for (final segment in geometry.segmentsFor(level)) {
        canvas.drawLine(segment.start, segment.end, paint);
      }
    }
  }

  void _drawActiveSelection(Canvas canvas) {
    final hit = activeSelection!;
    final center = geometry.scale.toOffset(hit.x, hit.y, geometry.plotRect);
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..color = activeColor.withValues(alpha: 0.18 * progress)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      4,
      Paint()
        ..color = activeColor.withValues(alpha: progress)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawAxes(Canvas canvas) {
    canvas.drawRect(
      geometry.plotRect,
      Paint()
        ..color = axisColor.withValues(alpha: 0.74 * progress)
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

  void _drawSamplePoints(Canvas canvas) {
    for (final point in points) {
      final center = geometry.scale.toOffset(
        point.x,
        point.y,
        geometry.plotRect,
      );
      final active = activeSelection?.nearestPoint == point;
      canvas.drawCircle(
        center,
        pointRadius + (active ? 2 : 0),
        Paint()
          ..color = (point.color ?? pointColor).withValues(alpha: progress)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        center,
        pointRadius + (active ? 2 : 0),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.78 * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2 : 1.1,
      );
    }
  }

  void _drawLabels(Canvas canvas) {
    for (final point in points) {
      final center = geometry.scale.toOffset(
        point.x,
        point.y,
        geometry.plotRect,
      );
      final text = showValues
          ? '${point.label} ${valueFormatter(point.value)}'
          : point.label;
      _drawText(
        canvas,
        text,
        Offset(center.dx + 7, center.dy - 7),
        valueStyle.copyWith(
          color: (valueStyle.color ?? Colors.black).withValues(
            alpha: 0.9 * progress,
          ),
        ),
        maxWidth: 94,
      );
    }
  }

  void _drawLegend(Canvas canvas) {
    final y = geometry.plotRect.bottom + 13;
    final width = math.min(128.0, geometry.plotRect.width * 0.42);
    final height = 8.0;
    final rect = Rect.fromLTWH(
      geometry.plotRect.right - width,
      y,
      width,
      height,
    );
    final stops = _legendStops();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..shader = LinearGradient(colors: stops).createShader(rect)
        ..style = PaintingStyle.fill,
    );
    _drawText(
      canvas,
      valueFormatter(geometry.valueMin),
      Offset(rect.left, rect.bottom + 2),
      valueStyle.copyWith(
        color: (valueStyle.color ?? Colors.black).withValues(
          alpha: 0.76 * progress,
        ),
      ),
      maxWidth: 54,
    );
    _drawText(
      canvas,
      valueFormatter(geometry.valueMax),
      Offset(rect.right - 54, rect.bottom + 2),
      valueStyle.copyWith(
        color: (valueStyle.color ?? Colors.black).withValues(
          alpha: 0.76 * progress,
        ),
      ),
      maxWidth: 54,
      align: TextAlign.right,
    );
  }

  Color _colorFor(double value) {
    final ratio = geometry.valueRatio(value);
    final stops = _legendStops();
    if (stops.length == 1) {
      return stops.first;
    }
    final scaled = ratio * (stops.length - 1);
    final index = scaled.floor().clamp(0, stops.length - 2);
    final t = scaled - index;
    return Color.lerp(stops[index], stops[index + 1], t) ?? stops[index];
  }

  List<Color> _legendStops() {
    if (palette.isNotEmpty) {
      return palette;
    }
    return [lowColor, highColor];
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
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
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SimpleContourPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.points != points ||
        oldDelegate.xAxisLabel != xAxisLabel ||
        oldDelegate.yAxisLabel != yAxisLabel ||
        oldDelegate.palette != palette ||
        oldDelegate.lowColor != lowColor ||
        oldDelegate.highColor != highColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.pointColor != pointColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showFilledBands != showFilledBands ||
        oldDelegate.showContourLines != showContourLines ||
        oldDelegate.showSamplePoints != showSamplePoints ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveSelection != showActiveSelection ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.contourLineWidth != contourLineWidth ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.progress != progress;
  }
}

class _ContourGeometry {
  final Rect plotRect;
  final _ContourScale scale;
  final List<SimpleContourPoint> points;
  final List<List<double>> values;
  final List<double> bands;
  final List<double> lineLevels;
  final double valueMin;
  final double valueMax;
  final int gridResolution;
  final double interpolationPower;

  const _ContourGeometry({
    required this.plotRect,
    required this.scale,
    required this.points,
    required this.values,
    required this.bands,
    required this.lineLevels,
    required this.valueMin,
    required this.valueMax,
    required this.gridResolution,
    required this.interpolationPower,
  });

  factory _ContourGeometry.resolve({
    required Size size,
    required List<SimpleContourPoint> points,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required bool showLegend,
    required int gridResolution,
    required int levelCount,
    required List<double> levels,
    required double interpolationPower,
  }) {
    final legendHeight = showLegend ? 26.0 : 0.0;
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal),
      math.max(1, size.height - padding.vertical - legendHeight),
    );
    final scale = _ContourScale.resolve(
      points: points,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
    final rawValueMin =
        minValue ?? points.map((point) => point.value).reduce(math.min);
    final rawValueMax =
        maxValue ?? points.map((point) => point.value).reduce(math.max);
    final valueMin = rawValueMax <= rawValueMin ? rawValueMin - 1 : rawValueMin;
    final valueMax = rawValueMax <= rawValueMin ? rawValueMax + 1 : rawValueMax;
    final bands = _resolveBandBounds(valueMin, valueMax, levelCount, levels);
    final values = List.generate(
      gridResolution + 1,
      (row) => List.generate(gridResolution + 1, (col) {
        final x = scale.minX + (scale.maxX - scale.minX) * col / gridResolution;
        final y = scale.maxY - (scale.maxY - scale.minY) * row / gridResolution;
        return _interpolate(points, x, y, interpolationPower);
      }),
    );
    return _ContourGeometry(
      plotRect: plotRect,
      scale: scale,
      points: points,
      values: values,
      bands: bands,
      lineLevels: bands.skip(1).take(bands.length - 2).toList(),
      valueMin: valueMin,
      valueMax: valueMax,
      gridResolution: gridResolution,
      interpolationPower: interpolationPower,
    );
  }

  double interpolate(double x, double y) {
    return _interpolate(points, x, y, interpolationPower);
  }

  int bandIndexFor(double value) {
    for (var i = 0; i < bands.length - 1; i++) {
      if (value <= bands[i + 1]) {
        return i;
      }
    }
    return math.max(0, bands.length - 2);
  }

  (double, double) bandRange(int index) {
    final maxIndex = math.max(0, bands.length - 2);
    final safe = index.clamp(0, maxIndex).toInt();
    return (bands[safe], bands[safe + 1]);
  }

  double valueRatio(double value) {
    final span = valueMax - valueMin;
    if (span <= 0) {
      return 0;
    }
    return ((value - valueMin) / span).clamp(0.0, 1.0).toDouble();
  }

  SimpleContourPoint? nearestPoint(Offset position) {
    SimpleContourPoint? nearest;
    var bestDistance = double.infinity;
    for (final point in points) {
      final center = scale.toOffset(point.x, point.y, plotRect);
      final distance = (center - position).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        nearest = point;
      }
    }
    return bestDistance <= 18 ? nearest : null;
  }

  List<_ContourSegment> segmentsFor(double level) {
    final result = <_ContourSegment>[];
    for (var row = 0; row < gridResolution; row++) {
      for (var col = 0; col < gridResolution; col++) {
        result.addAll(_segmentsForCell(row, col, level));
      }
    }
    return result;
  }

  List<_ContourSegment> _segmentsForCell(int row, int col, double level) {
    final p0 = _gridOffset(row, col);
    final p1 = _gridOffset(row, col + 1);
    final p2 = _gridOffset(row + 1, col + 1);
    final p3 = _gridOffset(row + 1, col);
    final v0 = values[row][col];
    final v1 = values[row][col + 1];
    final v2 = values[row + 1][col + 1];
    final v3 = values[row + 1][col];
    final intersections = <Offset>[];
    _addEdgeIntersection(intersections, p0, p1, v0, v1, level);
    _addEdgeIntersection(intersections, p1, p2, v1, v2, level);
    _addEdgeIntersection(intersections, p2, p3, v2, v3, level);
    _addEdgeIntersection(intersections, p3, p0, v3, v0, level);
    if (intersections.length < 2) {
      return const [];
    }
    if (intersections.length == 2) {
      return [_ContourSegment(start: intersections[0], end: intersections[1])];
    }
    return [
      _ContourSegment(start: intersections[0], end: intersections[1]),
      _ContourSegment(start: intersections[2], end: intersections[3]),
    ];
  }

  Offset _gridOffset(int row, int col) {
    return Offset(
      plotRect.left + plotRect.width * col / gridResolution,
      plotRect.top + plotRect.height * row / gridResolution,
    );
  }

  static void _addEdgeIntersection(
    List<Offset> output,
    Offset start,
    Offset end,
    double startValue,
    double endValue,
    double level,
  ) {
    final delta = endValue - startValue;
    if (delta.abs() < 0.000001) {
      return;
    }
    final crosses =
        (startValue <= level && endValue > level) ||
        (startValue > level && endValue <= level);
    if (!crosses) {
      return;
    }
    final t = ((level - startValue) / delta).clamp(0.0, 1.0).toDouble();
    output.add(Offset.lerp(start, end, t)!);
  }

  static List<double> _resolveBandBounds(
    double valueMin,
    double valueMax,
    int levelCount,
    List<double> levels,
  ) {
    final custom =
        levels
            .where(
              (level) => level.isFinite && level > valueMin && level < valueMax,
            )
            .toSet()
            .toList()
          ..sort();
    if (custom.isNotEmpty) {
      return [valueMin, ...custom, valueMax];
    }
    return List.generate(
      levelCount + 1,
      (index) => valueMin + (valueMax - valueMin) * index / levelCount,
    );
  }

  static double _interpolate(
    List<SimpleContourPoint> points,
    double x,
    double y,
    double power,
  ) {
    var weighted = 0.0;
    var totalWeight = 0.0;
    for (final point in points) {
      final dx = x - point.x;
      final dy = y - point.y;
      final distanceSquared = dx * dx + dy * dy;
      if (distanceSquared < 0.000001) {
        return point.value;
      }
      final weight = (1 / math.pow(math.sqrt(distanceSquared), power))
          .toDouble();
      weighted += point.value * weight;
      totalWeight += weight;
    }
    return totalWeight <= 0 ? 0 : weighted / totalWeight;
  }
}

class _ContourScale {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _ContourScale({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  factory _ContourScale.resolve({
    required List<SimpleContourPoint> points,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
  }) {
    final rawMinX = minX ?? points.map((point) => point.x).reduce(math.min);
    final rawMaxX = maxX ?? points.map((point) => point.x).reduce(math.max);
    final rawMinY = minY ?? points.map((point) => point.y).reduce(math.min);
    final rawMaxY = maxY ?? points.map((point) => point.y).reduce(math.max);
    final xSpan = rawMaxX - rawMinX;
    final ySpan = rawMaxY - rawMinY;
    return _ContourScale(
      minX: xSpan.abs() < 0.000001 ? rawMinX - 1 : rawMinX,
      maxX: xSpan.abs() < 0.000001 ? rawMaxX + 1 : rawMaxX,
      minY: ySpan.abs() < 0.000001 ? rawMinY - 1 : rawMinY,
      maxY: ySpan.abs() < 0.000001 ? rawMaxY + 1 : rawMaxY,
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

class _ContourSegment {
  final Offset start;
  final Offset end;

  const _ContourSegment({required this.start, required this.end});
}

class _SimpleContourVisuals {
  final Color lowColor;
  final Color highColor;
  final Color lineColor;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color> palette;

  const _SimpleContourVisuals({
    required this.lowColor,
    required this.highColor,
    required this.lineColor,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
  });

  factory _SimpleContourVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleContourVisuals(
          lowColor: colorScheme.primaryContainer,
          highColor: colorScheme.primary,
          lineColor: colorScheme.primary,
          pointColor: colorScheme.primary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
          axisColor: colorScheme.outline.withValues(alpha: 0.64),
          activeColor: colorScheme.primary,
          palette: const [
            Color(0xFFE0F2FE),
            Color(0xFF7DD3FC),
            Color(0xFF22D3EE),
            Color(0xFF2563EB),
            Color(0xFF4338CA),
          ],
        );
      case SimpleBarChartStyle.professional:
        return const _SimpleContourVisuals(
          lowColor: Color(0xFFE2E8F0),
          highColor: Color(0xFF1D4ED8),
          lineColor: Color(0xFF334155),
          pointColor: Color(0xFF1D4ED8),
          gridColor: Color(0xFFE2E8F0),
          axisColor: Color(0xFF64748B),
          activeColor: Color(0xFF0F172A),
          palette: [
            Color(0xFFE2E8F0),
            Color(0xFFBAE6FD),
            Color(0xFF60A5FA),
            Color(0xFF2563EB),
            Color(0xFF1E3A8A),
          ],
        );
      case SimpleBarChartStyle.education:
        return const _SimpleContourVisuals(
          lowColor: Color(0xFFDCFCE7),
          highColor: Color(0xFF2563EB),
          lineColor: Color(0xFF2563EB),
          pointColor: Color(0xFF2563EB),
          gridColor: Color(0xFFE2E8F0),
          axisColor: Color(0xFF94A3B8),
          activeColor: Color(0xFFF97316),
          palette: [
            Color(0xFFDCFCE7),
            Color(0xFF86EFAC),
            Color(0xFFFDE68A),
            Color(0xFFF97316),
            Color(0xFF2563EB),
          ],
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleContourVisuals(
          lowColor: const Color(0xFFCCFBF1),
          highColor: const Color(0xFF8B5CF6),
          lineColor: const Color(0xFF7C3AED),
          pointColor: const Color(0xFF14B8A6),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
          axisColor: colorScheme.outline.withValues(alpha: 0.58),
          activeColor: const Color(0xFFF43F5E),
          palette: const [
            Color(0xFFCCFBF1),
            Color(0xFF14B8A6),
            Color(0xFF06B6D4),
            Color(0xFF8B5CF6),
            Color(0xFFF43F5E),
          ],
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleContourVisuals(
          lowColor: colorScheme.secondaryContainer,
          highColor: colorScheme.secondary,
          lineColor: colorScheme.secondary,
          pointColor: colorScheme.secondary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
          activeColor: colorScheme.secondary,
          palette: const [
            Color(0xFFE0F2FE),
            Color(0xFF99F6E4),
            Color(0xFF0F766E),
            Color(0xFF7C3AED),
            Color(0xFFE11D48),
          ],
        );
    }
  }
}

class _DefaultContourTooltip extends StatelessWidget {
  final SimpleContourSelection hit;
  final String xAxisLabel;
  final String yAxisLabel;
  final String formattedX;
  final String formattedY;
  final String formattedValue;
  final String formattedRange;

  const _DefaultContourTooltip({
    required this.hit,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.formattedX,
    required this.formattedY,
    required this.formattedValue,
    required this.formattedRange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = hit.nearestPoint?.label ?? 'Surface';
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
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              _TooltipRow(label: xAxisLabel, value: formattedX),
              _TooltipRow(label: yAxisLabel, value: formattedY),
              _TooltipRow(label: 'Value', value: formattedValue),
              _TooltipRow(label: 'Band', value: formattedRange),
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
