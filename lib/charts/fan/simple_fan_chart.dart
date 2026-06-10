import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import '../line/simple_line_chart.dart';

typedef SimpleFanValueFormatter = String Function(double value);
typedef SimpleFanPointTapCallback =
    void Function(SimpleFanChartPoint point, int index);
typedef SimpleFanTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleFanChartPoint point,
      int index,
      String formattedValue,
      List<SimpleFanTooltipBand> bands,
    );

class SimpleFanChartBand {
  final double lower;
  final double upper;
  final String label;
  final Color? color;

  const SimpleFanChartBand({
    required this.lower,
    required this.upper,
    required this.label,
    this.color,
  });

  double get low => math.min(lower, upper);
  double get high => math.max(lower, upper);
  double get span => high - low;
}

class SimpleFanChartPoint {
  final String label;
  final double value;
  final List<SimpleFanChartBand> bands;
  final Color? color;

  const SimpleFanChartPoint({
    required this.label,
    required this.value,
    this.bands = const [],
    this.color,
  });
}

class SimpleFanTooltipBand {
  final String label;
  final String formattedLower;
  final String formattedUpper;
  final Color color;

  const SimpleFanTooltipBand({
    required this.label,
    required this.formattedLower,
    required this.formattedUpper,
    required this.color,
  });
}

/// A simple fan chart for forecast uncertainty, confidence intervals, scenario
/// ranges, projections, and planning dashboards.
class SimpleFanChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(48, 18, 18, 38);

  final List<SimpleFanChartPoint> points;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final String? valueLabel;
  final Color? lineColor;
  final Color? bandColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showBands;
  final bool showLine;
  final bool showDots;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showAxisLabels;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final double bandOpacity;
  final SimpleFanValueFormatter? valueFormatter;
  final SimpleFanPointTapCallback? onPointTap;
  final SimpleFanTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleFanChart({
    super.key,
    required this.points,
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 250,
    this.padding = _defaultPadding,
    this.valueLabel,
    this.lineColor,
    this.bandColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showBands = true,
    this.showLine = true,
    this.showDots = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.showAxisLabels = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.strokeWidth = 2.4,
    this.dotRadius = 3.6,
    this.bandOpacity = 0.34,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 750),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(strokeWidth > 0),
       assert(dotRadius >= 0),
       assert(bandOpacity >= 0 && bandOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleFanVisuals.resolve(style, colorScheme);
    final visiblePoints = points
        .where(
          (point) =>
              point.value.isFinite &&
              point.bands.every(
                (band) => band.lower.isFinite && band.upper.isFinite,
              ),
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;

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
            emptySemanticLabel: 'Fan chart, no data.',
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
        final geometry = _FanGeometry.resolve(
          size: Size(width, chartHeight),
          points: visiblePoints,
          minValue: minValue,
          maxValue: maxValue,
          includeZero: includeZero,
          padding: padding,
          showLegend: showLegend,
          referenceLines: referenceLines,
          referenceBands: referenceBands,
        );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(visiblePoints, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleFanView(
            width: width,
            height: chartHeight,
            points: visiblePoints,
            geometry: geometry,
            valueLabel: valueLabel,
            lineColor: lineColor ?? visuals.lineColor,
            bandColor: bandColor ?? visuals.bandColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            palette: palette ?? visuals.palette,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showBands: showBands,
            showLine: showLine,
            showDots: showDots,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            showAxisLabels: showAxisLabels,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            strokeWidth: strokeWidth,
            dotRadius: dotRadius,
            bandOpacity: bandOpacity,
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

  static String _defaultSemanticLabel(
    List<SimpleFanChartPoint> points,
    SimpleFanValueFormatter formatter,
  ) {
    final sample = points
        .take(6)
        .map((point) {
          final band = point.bands.isEmpty
              ? ''
              : ', ${point.bands.first.label} ${formatter(point.bands.first.low)} to ${formatter(point.bands.first.high)}';
          return '${point.label} forecast ${formatter(point.value)}$band';
        })
        .join(', ');
    final suffix = points.length > 6 ? ', and ${points.length - 6} more' : '';
    return 'Fan chart, ${points.length} points. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleFanView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleFanChartPoint> points;
  final _FanGeometry geometry;
  final String? valueLabel;
  final Color lineColor;
  final Color bandColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color> palette;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showBands;
  final bool showLine;
  final bool showDots;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showAxisLabels;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final double bandOpacity;
  final SimpleFanValueFormatter valueFormatter;
  final SimpleFanPointTapCallback? onPointTap;
  final SimpleFanTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleFanView({
    required this.width,
    required this.height,
    required this.points,
    required this.geometry,
    required this.valueLabel,
    required this.lineColor,
    required this.bandColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showBands,
    required this.showLine,
    required this.showDots,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.showAxisLabels,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.bandOpacity,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleFanView> createState() => _SimpleFanViewState();
}

class _SimpleFanViewState extends State<_SimpleFanView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  _FanPointLayout? _activePoint;
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
  void didUpdateWidget(covariant _SimpleFanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points ||
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
                    widget.onPointTap?.call(point.point, point.index);
                  }
                },
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _SimpleFanPainter(
                        geometry: widget.geometry,
                        valueLabel: widget.valueLabel,
                        lineColor: widget.lineColor,
                        bandColor: widget.bandColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        palette: widget.palette,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showBands: widget.showBands,
                        showLine: widget.showLine,
                        showDots: widget.showDots,
                        showValues: widget.showValues,
                        showLegend: widget.showLegend,
                        showActivePoint: widget.showActivePoint,
                        showAxisLabels: widget.showAxisLabels,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        gridLineCount: widget.gridLineCount,
                        strokeWidth: widget.strokeWidth,
                        dotRadius: widget.dotRadius,
                        bandOpacity: widget.bandOpacity,
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

  void _setActive(_FanPointLayout? point) {
    if (_activePoint?.index == point?.index) {
      return;
    }
    setState(() => _activePoint = point);
  }

  _FanPointLayout? _hitTest(Offset position) {
    _FanPointLayout? nearest;
    var bestDistance = double.infinity;
    for (final point in widget.geometry.points) {
      final distance = (point.center - position).distance;
      if (distance <= math.max(14, widget.dotRadius + 8) &&
          distance < bestDistance) {
        nearest = point;
        bestDistance = distance;
      }
    }
    return nearest;
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final active = _activePoint!;
    final bands = active.point.bands
        .map(
          (band) => SimpleFanTooltipBand(
            label: band.label,
            formattedLower: widget.valueFormatter(band.low),
            formattedUpper: widget.valueFormatter(band.high),
            color: band.color ?? widget.bandColor,
          ),
        )
        .toList();
    final child =
        widget.tooltipBuilder?.call(
          context,
          active.point,
          active.index,
          widget.valueFormatter(active.point.value),
          bands,
        ) ??
        _DefaultFanTooltip(
          point: active.point,
          formattedValue: widget.valueFormatter(active.point.value),
          bands: bands,
        );
    const tooltipWidth = 188.0;
    final tooltipHeight = 92.0 + 20.0 * math.min(3, bands.length);
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

class _SimpleFanPainter extends CustomPainter {
  final _FanGeometry geometry;
  final String? valueLabel;
  final Color lineColor;
  final Color bandColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color> palette;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showBands;
  final bool showLine;
  final bool showDots;
  final bool showValues;
  final bool showLegend;
  final bool showActivePoint;
  final bool showAxisLabels;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final double bandOpacity;
  final SimpleFanValueFormatter valueFormatter;
  final _FanPointLayout? activePoint;
  final double progress;

  const _SimpleFanPainter({
    required this.geometry,
    required this.valueLabel,
    required this.lineColor,
    required this.bandColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showBands,
    required this.showLine,
    required this.showDots,
    required this.showValues,
    required this.showLegend,
    required this.showActivePoint,
    required this.showAxisLabels,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.bandOpacity,
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
    if (showBands) {
      _drawBands(canvas);
    }
    if (showLine) {
      _drawLine(canvas);
    }
    _drawAxes(canvas);
    if (showDots) {
      _drawDots(canvas);
    }
    if (showValues) {
      _drawValues(canvas);
    }
    if (showLegend) {
      _drawLegend(canvas);
    }
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.9 * progress)
      ..strokeWidth = 1;
    for (var i = 0; i <= gridLineCount; i++) {
      final y =
          geometry.plotRect.top + geometry.plotRect.height * i / gridLineCount;
      canvas.drawLine(
        Offset(geometry.plotRect.left, y),
        Offset(geometry.plotRect.right, y),
        paint,
      );
    }
    for (final point in geometry.points) {
      canvas.drawLine(
        Offset(point.center.dx, geometry.plotRect.top),
        Offset(point.center.dx, geometry.plotRect.bottom),
        paint..color = gridColor.withValues(alpha: 0.42 * progress),
      );
    }
  }

  void _drawReferenceBands(Canvas canvas) {
    for (final band in referenceBands) {
      final y1 = geometry.yFor(band.from);
      final y2 = geometry.yFor(band.to);
      final rect = Rect.fromLTRB(
        geometry.plotRect.left,
        math.min(y1, y2),
        geometry.plotRect.right,
        math.max(y1, y2),
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
          labelStyle,
          maxWidth: 96,
        );
      }
    }
  }

  void _drawReferenceLines(Canvas canvas) {
    for (final reference in referenceLines) {
      final y = geometry.yFor(reference.value);
      final paint = Paint()
        ..color = (reference.color ?? activeColor).withValues(
          alpha: 0.78 * progress,
        )
        ..strokeWidth = reference.strokeWidth
        ..style = PaintingStyle.stroke;
      final start = Offset(geometry.plotRect.left, y);
      final end = Offset(geometry.plotRect.right, y);
      _drawStyledLine(canvas, start, end, paint, reference.lineStyle);
      if (reference.showLabel && reference.label != null) {
        _drawText(
          canvas,
          reference.label!,
          start + const Offset(6, 5),
          labelStyle,
          maxWidth: 90,
        );
      }
    }
  }

  void _drawBands(Canvas canvas) {
    for (var bandIndex = 0; bandIndex < geometry.maxBandCount; bandIndex++) {
      final path = Path();
      var started = false;
      for (final point in geometry.points) {
        if (point.bands.length <= bandIndex) {
          continue;
        }
        final upper = Offset(
          point.center.dx,
          geometry.yFor(point.bands[bandIndex].high),
        );
        if (!started) {
          path.moveTo(upper.dx, upper.dy);
          started = true;
        } else {
          path.lineTo(upper.dx, upper.dy);
        }
      }
      for (final point in geometry.points.reversed) {
        if (point.bands.length <= bandIndex) {
          continue;
        }
        final lower = Offset(
          point.center.dx,
          geometry.yFor(point.bands[bandIndex].low),
        );
        path.lineTo(lower.dx, lower.dy);
      }
      if (!started) {
        continue;
      }
      final color = _bandColorFor(bandIndex);
      final opacity =
          bandOpacity *
          (geometry.maxBandCount <= 1
              ? 1
              : 0.52 + 0.48 * (bandIndex + 1) / geometry.maxBandCount);
      canvas.drawPath(
        path..close(),
        Paint()
          ..color = color.withValues(alpha: opacity * progress)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
  }

  void _drawLine(Canvas canvas) {
    if (geometry.points.length < 2) {
      return;
    }
    final path = Path();
    for (var i = 0; i < geometry.points.length; i++) {
      final point = geometry.points[i];
      final animated = Offset(
        point.center.dx,
        geometry.yFor(
          geometry.valueMin +
              (point.point.value - geometry.valueMin) * progress,
        ),
      );
      if (i == 0) {
        path.moveTo(animated.dx, animated.dy);
      } else {
        path.lineTo(animated.dx, animated.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor.withValues(alpha: progress)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  void _drawAxes(Canvas canvas) {
    canvas.drawRect(
      geometry.plotRect,
      Paint()
        ..color = axisColor.withValues(alpha: 0.72 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    if (!showAxisLabels) {
      return;
    }
    for (final point in geometry.points) {
      _drawText(
        canvas,
        point.point.label,
        Offset(point.center.dx - 26, geometry.plotRect.bottom + 8),
        labelStyle.copyWith(
          color: (labelStyle.color ?? Colors.black).withValues(
            alpha: 0.82 * progress,
          ),
        ),
        maxWidth: 52,
        align: TextAlign.center,
      );
    }
    if (valueLabel != null && valueLabel!.isNotEmpty) {
      _drawText(
        canvas,
        valueLabel!,
        Offset(geometry.plotRect.left - 44, geometry.plotRect.top - 2),
        labelStyle,
        maxWidth: 86,
      );
    }
  }

  void _drawDots(Canvas canvas) {
    for (final point in geometry.points) {
      final active = activePoint?.index == point.index;
      final opacity = activePoint == null || active ? 1.0 : 0.42;
      if (showActivePoint && active) {
        canvas.drawCircle(
          point.center,
          dotRadius + 7,
          Paint()
            ..color = activeColor.withValues(alpha: 0.18 * progress)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(
        point.center,
        dotRadius + (active ? 1.5 : 0),
        Paint()
          ..color = (point.point.color ?? lineColor).withValues(
            alpha: opacity * progress,
          )
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point.center,
        dotRadius + (active ? 1.5 : 0),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.78 * opacity * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2 : 1.1,
      );
    }
  }

  void _drawValues(Canvas canvas) {
    for (final point in geometry.points) {
      _drawText(
        canvas,
        valueFormatter(point.point.value),
        Offset(point.center.dx - 25, point.center.dy - 20),
        valueStyle.copyWith(
          color: (valueStyle.color ?? Colors.black).withValues(
            alpha: 0.88 * progress,
          ),
        ),
        maxWidth: 50,
        align: TextAlign.center,
      );
    }
  }

  void _drawLegend(Canvas canvas) {
    final y = geometry.plotRect.bottom + 14;
    var dx = geometry.plotRect.left;
    canvas.drawLine(
      Offset(dx, y + 5),
      Offset(dx + 18, y + 5),
      Paint()
        ..color = lineColor.withValues(alpha: progress)
        ..strokeWidth = 2,
    );
    _textPainter(
      'Forecast',
      valueStyle.copyWith(
        color: (valueStyle.color ?? Colors.black).withValues(alpha: progress),
      ),
      maxWidth: 70,
    ).paint(canvas, Offset(dx + 24, y - 2));
    dx += 100;
    final labels = geometry.bandLabels.take(3).toList();
    for (var i = 0; i < labels.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(dx, y + 2, 16, 8),
          const Radius.circular(4),
        ),
        Paint()
          ..color = _bandColorFor(i).withValues(alpha: bandOpacity * progress)
          ..style = PaintingStyle.fill,
      );
      final painter = _textPainter(
        labels[i],
        valueStyle.copyWith(
          color: (valueStyle.color ?? Colors.black).withValues(alpha: progress),
        ),
        maxWidth: 58,
      );
      painter.paint(canvas, Offset(dx + 22, y - 2));
      dx += math.min(82, painter.width + 34);
      if (dx > geometry.plotRect.right - 44) {
        break;
      }
    }
  }

  Color _bandColorFor(int index) {
    if (palette.isNotEmpty) {
      return palette[index % palette.length];
    }
    return bandColor;
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
  bool shouldRepaint(covariant _SimpleFanPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.valueLabel != valueLabel ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.bandColor != bandColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.palette != palette ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showBands != showBands ||
        oldDelegate.showLine != showLine ||
        oldDelegate.showDots != showDots ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.bandOpacity != bandOpacity ||
        oldDelegate.activePoint != activePoint ||
        oldDelegate.progress != progress;
  }
}

class _FanGeometry {
  final Rect plotRect;
  final List<_FanPointLayout> points;
  final double valueMin;
  final double valueMax;
  final int maxBandCount;
  final List<String> bandLabels;

  const _FanGeometry({
    required this.plotRect,
    required this.points,
    required this.valueMin,
    required this.valueMax,
    required this.maxBandCount,
    required this.bandLabels,
  });

  factory _FanGeometry.resolve({
    required Size size,
    required List<SimpleFanChartPoint> points,
    required double? minValue,
    required double? maxValue,
    required bool includeZero,
    required EdgeInsets padding,
    required bool showLegend,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    final legendHeight = showLegend ? 28.0 : 0.0;
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal),
      math.max(1, size.height - padding.vertical - legendHeight),
    );
    var lower =
        minValue ??
        points
            .expand(
              (point) => [
                point.value,
                ...point.bands.expand((band) => [band.low, band.high]),
                ...referenceLines.map((line) => line.value),
                ...referenceBands.expand((band) => [band.from, band.to]),
              ],
            )
            .reduce(math.min);
    var upper =
        maxValue ??
        points
            .expand(
              (point) => [
                point.value,
                ...point.bands.expand((band) => [band.low, band.high]),
                ...referenceLines.map((line) => line.value),
                ...referenceBands.expand((band) => [band.from, band.to]),
              ],
            )
            .reduce(math.max);
    if (includeZero) {
      lower = math.min(0, lower);
      upper = math.max(0, upper);
    }
    if (upper <= lower) {
      lower -= 1;
      upper += 1;
    }
    final span = upper - lower;
    final valueMin = lower - span * 0.08;
    final valueMax = upper + span * 0.08;
    final xStep = points.length <= 1
        ? 0.0
        : plotRect.width / (points.length - 1);
    final maxBandCount = points.fold<int>(
      0,
      (count, point) => math.max(count, point.bands.length),
    );
    final layouts = <_FanPointLayout>[];
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final bands = [...point.bands]..sort((a, b) => b.span.compareTo(a.span));
      final x = points.length <= 1
          ? plotRect.center.dx
          : plotRect.left + xStep * i;
      layouts.add(
        _FanPointLayout(
          index: i,
          point: point,
          bands: bands,
          center: Offset(x, _yFor(point.value, plotRect, valueMin, valueMax)),
        ),
      );
    }
    final bandLabels = <String>[];
    for (final point in layouts) {
      for (var i = 0; i < point.bands.length; i++) {
        if (bandLabels.length <= i) {
          bandLabels.add(point.bands[i].label);
        }
      }
    }
    return _FanGeometry(
      plotRect: plotRect,
      points: layouts,
      valueMin: valueMin,
      valueMax: valueMax,
      maxBandCount: maxBandCount,
      bandLabels: bandLabels,
    );
  }

  double yFor(double value) => _yFor(value, plotRect, valueMin, valueMax);

  static double _yFor(
    double value,
    Rect plotRect,
    double valueMin,
    double valueMax,
  ) {
    final ratio = ((value - valueMin) / (valueMax - valueMin))
        .clamp(0.0, 1.0)
        .toDouble();
    return plotRect.bottom - plotRect.height * ratio;
  }
}

class _FanPointLayout {
  final int index;
  final SimpleFanChartPoint point;
  final List<SimpleFanChartBand> bands;
  final Offset center;

  const _FanPointLayout({
    required this.index,
    required this.point,
    required this.bands,
    required this.center,
  });
}

class _SimpleFanVisuals {
  final Color lineColor;
  final Color bandColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color> palette;

  const _SimpleFanVisuals({
    required this.lineColor,
    required this.bandColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
  });

  factory _SimpleFanVisuals.resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleFanVisuals(
          lineColor: colorScheme.primary,
          bandColor: colorScheme.primary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.28),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          activeColor: colorScheme.primary,
          palette: const [
            Color(0xFF93C5FD),
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        );
      case SimpleTrendChartStyle.professional:
        return const _SimpleFanVisuals(
          lineColor: Color(0xFF1D4ED8),
          bandColor: Color(0xFF2563EB),
          gridColor: Color(0xFFE2E8F0),
          axisColor: Color(0xFF64748B),
          activeColor: Color(0xFF0F172A),
          palette: [Color(0xFFBFDBFE), Color(0xFF60A5FA), Color(0xFF2563EB)],
        );
      case SimpleTrendChartStyle.education:
        return const _SimpleFanVisuals(
          lineColor: Color(0xFF2563EB),
          bandColor: Color(0xFF2563EB),
          gridColor: Color(0xFFE2E8F0),
          axisColor: Color(0xFF94A3B8),
          activeColor: Color(0xFFF97316),
          palette: [Color(0xFFBBF7D0), Color(0xFF60A5FA), Color(0xFFF97316)],
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleFanVisuals(
          lineColor: const Color(0xFF14B8A6),
          bandColor: const Color(0xFF14B8A6),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.26),
          axisColor: colorScheme.outline.withValues(alpha: 0.58),
          activeColor: const Color(0xFFF43F5E),
          palette: const [
            Color(0xFF99F6E4),
            Color(0xFF22D3EE),
            Color(0xFF8B5CF6),
          ],
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleFanVisuals(
          lineColor: colorScheme.secondary,
          bandColor: colorScheme.secondary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.28),
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
          activeColor: colorScheme.secondary,
          palette: const [
            Color(0xFF99F6E4),
            Color(0xFF0F766E),
            Color(0xFF7C3AED),
          ],
        );
    }
  }
}

class _DefaultFanTooltip extends StatelessWidget {
  final SimpleFanChartPoint point;
  final String formattedValue;
  final List<SimpleFanTooltipBand> bands;

  const _DefaultFanTooltip({
    required this.point,
    required this.formattedValue,
    required this.bands,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 188,
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
              const SizedBox(height: 7),
              _TooltipRow(label: 'Forecast', value: formattedValue),
              for (final band in bands.take(3))
                _TooltipRow(
                  label: band.label,
                  value: '${band.formattedLower} - ${band.formattedUpper}',
                ),
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
