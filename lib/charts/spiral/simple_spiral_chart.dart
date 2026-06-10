import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../line/simple_line_chart.dart';

typedef SimpleSpiralValueFormatter = String Function(double value);
typedef SimpleSpiralPointTapCallback =
    void Function(SimpleSpiralChartPoint point, int index, double normalized);
typedef SimpleSpiralTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleSpiralChartPoint point,
      int index,
      String formattedValue,
      String formattedNormalized,
    );

class SimpleSpiralChartPoint {
  final String label;
  final double value;
  final Color? color;

  const SimpleSpiralChartPoint({
    required this.label,
    required this.value,
    this.color,
  });
}

/// A simple spiral chart for cyclical trends, seasonality, recurring cadence,
/// long-running progress, and periodic activity patterns.
class SimpleSpiralChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 12, 18, 34);

  final List<SimpleSpiralChartPoint> points;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final String? centerLabel;
  final Color? lineColor;
  final Color? lowColor;
  final Color? highColor;
  final Color? gridColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLine;
  final bool showDots;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showCycleGuides;
  final int? cycleLength;
  final int gridRingCount;
  final double strokeWidth;
  final double dotRadius;
  final double startAngle;
  final double innerRadiusFactor;
  final double maxDotBoost;
  final SimpleSpiralValueFormatter? valueFormatter;
  final SimpleSpiralValueFormatter? normalizedFormatter;
  final SimpleSpiralPointTapCallback? onPointTap;
  final SimpleSpiralTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleSpiralChart({
    super.key,
    required this.points,
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.centerLabel,
    this.lineColor,
    this.lowColor,
    this.highColor,
    this.gridColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLine = true,
    this.showDots = true,
    this.showLabels = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.showCycleGuides = true,
    this.cycleLength,
    this.gridRingCount = 4,
    this.strokeWidth = 2.2,
    this.dotRadius = 3.8,
    this.startAngle = -math.pi / 2,
    this.innerRadiusFactor = 0.18,
    this.maxDotBoost = 5,
    this.valueFormatter,
    this.normalizedFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(cycleLength == null || cycleLength > 0),
       assert(gridRingCount >= 2),
       assert(strokeWidth > 0),
       assert(dotRadius >= 0),
       assert(innerRadiusFactor >= 0 && innerRadiusFactor < 0.8),
       assert(maxDotBoost >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleSpiralVisuals.resolve(style, colorScheme);
    final visiblePoints = points
        .where((point) => point.label.trim().isNotEmpty && point.value.isFinite)
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedNormalizedFormatter =
        normalizedFormatter ?? _defaultNormalizedFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visiblePoints.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Spiral chart, no data.',
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
        final geometry = _SpiralGeometry.resolve(
          size: Size(width, chartHeight),
          points: visiblePoints,
          minValue: minValue,
          maxValue: maxValue,
          padding: padding,
          showLegend: showLegend,
          cycleLength: cycleLength,
          startAngle: startAngle,
          innerRadiusFactor: innerRadiusFactor,
        );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visiblePoints,
            formatter,
            resolvedNormalizedFormatter,
            geometry,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleSpiralView(
            width: width,
            height: chartHeight,
            geometry: geometry,
            centerLabel: centerLabel,
            lineColor: lineColor ?? visuals.lineColor,
            lowColor: lowColor ?? visuals.lowColor,
            highColor: highColor ?? visuals.highColor,
            gridColor: gridColor ?? visuals.gridColor,
            activeColor: activeColor ?? visuals.activeColor,
            palette: palette ?? visuals.palette,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showLine: showLine,
            showDots: showDots,
            showLabels: showLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            showCycleGuides: showCycleGuides,
            gridRingCount: gridRingCount,
            strokeWidth: strokeWidth,
            dotRadius: dotRadius,
            maxDotBoost: maxDotBoost,
            valueFormatter: formatter,
            normalizedFormatter: resolvedNormalizedFormatter,
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
    List<SimpleSpiralChartPoint> points,
    SimpleSpiralValueFormatter formatter,
    SimpleSpiralValueFormatter normalizedFormatter,
    _SpiralGeometry geometry,
  ) {
    final sample = geometry.points
        .take(6)
        .map(
          (point) =>
              '${point.point.label} ${formatter(point.point.value)}, '
              '${normalizedFormatter(point.normalized * 100)} of range',
        )
        .join(', ');
    final suffix = points.length > 6 ? ', and ${points.length - 6} more' : '';
    return 'Spiral chart, ${points.length} points. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultNormalizedFormatter(double value) =>
      '${value.toStringAsFixed(0)}%';
}

class _SimpleSpiralView extends StatefulWidget {
  final double width;
  final double height;
  final _SpiralGeometry geometry;
  final String? centerLabel;
  final Color lineColor;
  final Color lowColor;
  final Color highColor;
  final Color gridColor;
  final Color activeColor;
  final List<Color> palette;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLine;
  final bool showDots;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showCycleGuides;
  final int gridRingCount;
  final double strokeWidth;
  final double dotRadius;
  final double maxDotBoost;
  final SimpleSpiralValueFormatter valueFormatter;
  final SimpleSpiralValueFormatter normalizedFormatter;
  final SimpleSpiralPointTapCallback? onPointTap;
  final SimpleSpiralTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleSpiralView({
    required this.width,
    required this.height,
    required this.geometry,
    required this.centerLabel,
    required this.lineColor,
    required this.lowColor,
    required this.highColor,
    required this.gridColor,
    required this.activeColor,
    required this.palette,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLine,
    required this.showDots,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.showCycleGuides,
    required this.gridRingCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.maxDotBoost,
    required this.valueFormatter,
    required this.normalizedFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleSpiralView> createState() => _SimpleSpiralViewState();
}

class _SimpleSpiralViewState extends State<_SimpleSpiralView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  _SpiralPointLayout? _activePoint;
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
  void didUpdateWidget(covariant _SimpleSpiralView oldWidget) {
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
                      point.point,
                      point.index,
                      point.normalized,
                    );
                  }
                },
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _SimpleSpiralPainter(
                        geometry: widget.geometry,
                        centerLabel: widget.centerLabel,
                        lineColor: widget.lineColor,
                        lowColor: widget.lowColor,
                        highColor: widget.highColor,
                        gridColor: widget.gridColor,
                        activeColor: widget.activeColor,
                        palette: widget.palette,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showLine: widget.showLine,
                        showDots: widget.showDots,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showLegend: widget.showLegend,
                        showActivePoint: widget.showActivePoint,
                        showCycleGuides: widget.showCycleGuides,
                        gridRingCount: widget.gridRingCount,
                        strokeWidth: widget.strokeWidth,
                        dotRadius: widget.dotRadius,
                        maxDotBoost: widget.maxDotBoost,
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

  void _setActive(_SpiralPointLayout? point) {
    if (_activePoint?.index == point?.index) {
      return;
    }
    setState(() => _activePoint = point);
  }

  _SpiralPointLayout? _hitTest(Offset position) {
    _SpiralPointLayout? nearest;
    var bestDistance = double.infinity;
    for (final point in widget.geometry.points) {
      final distance = (point.center - position).distance;
      final radius = widget.dotRadius + widget.maxDotBoost * point.normalized;
      if (distance <= radius + 8 && distance < bestDistance) {
        nearest = point;
        bestDistance = distance;
      }
    }
    return nearest;
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final active = _activePoint!;
    final child =
        widget.tooltipBuilder?.call(
          context,
          active.point,
          active.index,
          widget.valueFormatter(active.point.value),
          widget.normalizedFormatter(active.normalized * 100),
        ) ??
        _DefaultSpiralTooltip(
          point: active.point,
          formattedValue: widget.valueFormatter(active.point.value),
          formattedNormalized: widget.normalizedFormatter(
            active.normalized * 100,
          ),
        );
    const tooltipWidth = 174.0;
    const tooltipHeight = 94.0;
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

class _SimpleSpiralPainter extends CustomPainter {
  final _SpiralGeometry geometry;
  final String? centerLabel;
  final Color lineColor;
  final Color lowColor;
  final Color highColor;
  final Color gridColor;
  final Color activeColor;
  final List<Color> palette;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLine;
  final bool showDots;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActivePoint;
  final bool showCycleGuides;
  final int gridRingCount;
  final double strokeWidth;
  final double dotRadius;
  final double maxDotBoost;
  final SimpleSpiralValueFormatter valueFormatter;
  final _SpiralPointLayout? activePoint;
  final double progress;

  const _SimpleSpiralPainter({
    required this.geometry,
    required this.centerLabel,
    required this.lineColor,
    required this.lowColor,
    required this.highColor,
    required this.gridColor,
    required this.activeColor,
    required this.palette,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLine,
    required this.showDots,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActivePoint,
    required this.showCycleGuides,
    required this.gridRingCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.maxDotBoost,
    required this.valueFormatter,
    required this.activePoint,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      _drawGrid(canvas);
    }
    if (showLine) {
      _drawLine(canvas);
    }
    if (showDots) {
      _drawDots(canvas);
    }
    if (showLabels) {
      _drawLabels(canvas);
    }
    _drawCenterLabel(canvas);
    if (showLegend) {
      _drawLegend(canvas);
    }
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.72 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= gridRingCount; i++) {
      final radius = geometry.outerRadius * i / gridRingCount;
      canvas.drawCircle(geometry.center, radius, paint);
    }
    canvas.drawPath(
      _spiralPath(progress: 1),
      Paint()
        ..color = gridColor.withValues(alpha: 0.9 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    if (showCycleGuides && geometry.cycleLength > 1) {
      for (var i = 0; i < geometry.points.length; i += geometry.cycleLength) {
        final point = geometry.points[i];
        canvas.drawLine(
          geometry.center,
          point.center,
          Paint()
            ..color = gridColor.withValues(alpha: 0.34 * progress)
            ..strokeWidth = 1,
        );
      }
    }
  }

  void _drawLine(Canvas canvas) {
    if (geometry.points.length < 2) {
      return;
    }
    final path = Path();
    for (var i = 0; i < geometry.points.length; i++) {
      final point = geometry.points[i];
      final animated = Offset.lerp(geometry.center, point.center, progress)!;
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
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  void _drawDots(Canvas canvas) {
    for (final point in geometry.points) {
      final active = activePoint?.index == point.index;
      final opacity = activePoint == null || active ? 1.0 : 0.38;
      final center = Offset.lerp(geometry.center, point.center, progress)!;
      final radius = dotRadius + maxDotBoost * point.normalized;
      if (showActivePoint && active) {
        canvas.drawCircle(
          center,
          radius + 7,
          Paint()
            ..color = activeColor.withValues(alpha: 0.18 * progress)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = _colorFor(point).withValues(alpha: opacity * progress)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.78 * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2 : 1.1,
      );
    }
  }

  void _drawLabels(Canvas canvas) {
    for (final point in geometry.points) {
      final isCycleStart = point.index % geometry.cycleLength == 0;
      final isLast = point.index == geometry.points.length - 1;
      if (!isCycleStart && !isLast && !showValues) {
        continue;
      }
      final center = Offset.lerp(geometry.center, point.center, progress)!;
      final text = showValues
          ? '${point.point.label} ${valueFormatter(point.point.value)}'
          : point.point.label;
      final offset = Offset(
        center.dx + math.cos(point.angle) * 10 - 36,
        center.dy + math.sin(point.angle) * 10 - 7,
      );
      _drawText(
        canvas,
        text,
        offset,
        valueStyle.copyWith(
          color: (valueStyle.color ?? Colors.black).withValues(
            alpha: 0.86 * progress,
          ),
        ),
        maxWidth: 72,
        align: TextAlign.center,
      );
    }
  }

  void _drawCenterLabel(Canvas canvas) {
    if (centerLabel == null || centerLabel!.isEmpty) {
      return;
    }
    _drawText(
      canvas,
      centerLabel!,
      Offset(geometry.center.dx - 42, geometry.center.dy - 8),
      labelStyle.copyWith(
        color: (labelStyle.color ?? Colors.black).withValues(
          alpha: 0.8 * progress,
        ),
      ),
      maxWidth: 84,
      align: TextAlign.center,
    );
  }

  void _drawLegend(Canvas canvas) {
    final y = geometry.plotRect.bottom + 12;
    final width = math.min(126.0, geometry.plotRect.width * 0.46);
    final rect = Rect.fromLTWH(geometry.plotRect.right - width, y, width, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..shader = LinearGradient(colors: _legendStops()).createShader(rect)
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

  Path _spiralPath({required double progress}) {
    final path = Path();
    final steps = math.max(32, geometry.points.length * 10);
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * progress;
      final angle = geometry.startAngle + t * 2 * math.pi * geometry.turns;
      final radius =
          geometry.innerRadius +
          (geometry.outerRadius - geometry.innerRadius) * t;
      final point = Offset(
        geometry.center.dx + math.cos(angle) * radius,
        geometry.center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  Color _colorFor(_SpiralPointLayout point) {
    final stops = _legendStops();
    if (stops.length == 1) {
      return point.point.color ?? stops.first;
    }
    final scaled = point.normalized * (stops.length - 1);
    final index = scaled.floor().clamp(0, stops.length - 2);
    final t = scaled - index;
    return point.point.color ??
        Color.lerp(stops[index], stops[index + 1], t) ??
        stops[index];
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
  bool shouldRepaint(covariant _SimpleSpiralPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.centerLabel != centerLabel ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.lowColor != lowColor ||
        oldDelegate.highColor != highColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.palette != palette ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLine != showLine ||
        oldDelegate.showDots != showDots ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.showCycleGuides != showCycleGuides ||
        oldDelegate.gridRingCount != gridRingCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.maxDotBoost != maxDotBoost ||
        oldDelegate.activePoint != activePoint ||
        oldDelegate.progress != progress;
  }
}

class _SpiralGeometry {
  final Rect plotRect;
  final Offset center;
  final double innerRadius;
  final double outerRadius;
  final double startAngle;
  final double turns;
  final int cycleLength;
  final double valueMin;
  final double valueMax;
  final List<_SpiralPointLayout> points;

  const _SpiralGeometry({
    required this.plotRect,
    required this.center,
    required this.innerRadius,
    required this.outerRadius,
    required this.startAngle,
    required this.turns,
    required this.cycleLength,
    required this.valueMin,
    required this.valueMax,
    required this.points,
  });

  factory _SpiralGeometry.resolve({
    required Size size,
    required List<SimpleSpiralChartPoint> points,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required bool showLegend,
    required int? cycleLength,
    required double startAngle,
    required double innerRadiusFactor,
  }) {
    final legendHeight = showLegend ? 28.0 : 0.0;
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal),
      math.max(1, size.height - padding.vertical - legendHeight),
    );
    final side = math.min(plotRect.width, plotRect.height);
    final center = plotRect.center;
    final outerRadius = side / 2;
    final innerRadius = outerRadius * innerRadiusFactor;
    final resolvedCycleLength =
        cycleLength ?? math.min(12, math.max(1, points.length));
    final turns = math.max(1.0, (points.length - 1) / resolvedCycleLength);
    var valueMin =
        minValue ?? points.map((point) => point.value).reduce(math.min);
    var valueMax =
        maxValue ?? points.map((point) => point.value).reduce(math.max);
    if (valueMax <= valueMin) {
      valueMin -= 1;
      valueMax += 1;
    }
    final layouts = <_SpiralPointLayout>[];
    for (var i = 0; i < points.length; i++) {
      final t = points.length <= 1 ? 0.0 : i / (points.length - 1);
      final angle = startAngle + t * 2 * math.pi * turns;
      final radius = innerRadius + (outerRadius - innerRadius) * t;
      final normalized = ((points[i].value - valueMin) / (valueMax - valueMin))
          .clamp(0.0, 1.0)
          .toDouble();
      layouts.add(
        _SpiralPointLayout(
          index: i,
          point: points[i],
          angle: angle,
          radius: radius,
          normalized: normalized,
          center: Offset(
            center.dx + math.cos(angle) * radius,
            center.dy + math.sin(angle) * radius,
          ),
        ),
      );
    }
    return _SpiralGeometry(
      plotRect: plotRect,
      center: center,
      innerRadius: innerRadius,
      outerRadius: outerRadius,
      startAngle: startAngle,
      turns: turns,
      cycleLength: resolvedCycleLength,
      valueMin: valueMin,
      valueMax: valueMax,
      points: layouts,
    );
  }
}

class _SpiralPointLayout {
  final int index;
  final SimpleSpiralChartPoint point;
  final double angle;
  final double radius;
  final double normalized;
  final Offset center;

  const _SpiralPointLayout({
    required this.index,
    required this.point,
    required this.angle,
    required this.radius,
    required this.normalized,
    required this.center,
  });
}

class _SimpleSpiralVisuals {
  final Color lineColor;
  final Color lowColor;
  final Color highColor;
  final Color gridColor;
  final Color activeColor;
  final List<Color> palette;

  const _SimpleSpiralVisuals({
    required this.lineColor,
    required this.lowColor,
    required this.highColor,
    required this.gridColor,
    required this.activeColor,
    required this.palette,
  });

  factory _SimpleSpiralVisuals.resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleSpiralVisuals(
          lineColor: colorScheme.primary,
          lowColor: colorScheme.primaryContainer,
          highColor: colorScheme.primary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.28),
          activeColor: colorScheme.primary,
          palette: const [
            Color(0xFFE0F2FE),
            Color(0xFF22D3EE),
            Color(0xFF2563EB),
          ],
        );
      case SimpleTrendChartStyle.professional:
        return const _SimpleSpiralVisuals(
          lineColor: Color(0xFF1D4ED8),
          lowColor: Color(0xFFE2E8F0),
          highColor: Color(0xFF1D4ED8),
          gridColor: Color(0xFFE2E8F0),
          activeColor: Color(0xFF0F172A),
          palette: [Color(0xFFE2E8F0), Color(0xFF60A5FA), Color(0xFF1D4ED8)],
        );
      case SimpleTrendChartStyle.education:
        return const _SimpleSpiralVisuals(
          lineColor: Color(0xFF2563EB),
          lowColor: Color(0xFFDCFCE7),
          highColor: Color(0xFFF97316),
          gridColor: Color(0xFFE2E8F0),
          activeColor: Color(0xFFF97316),
          palette: [Color(0xFFDCFCE7), Color(0xFF60A5FA), Color(0xFFF97316)],
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleSpiralVisuals(
          lineColor: const Color(0xFF14B8A6),
          lowColor: const Color(0xFFCCFBF1),
          highColor: const Color(0xFFF43F5E),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.26),
          activeColor: const Color(0xFFF43F5E),
          palette: const [
            Color(0xFFCCFBF1),
            Color(0xFF14B8A6),
            Color(0xFF8B5CF6),
            Color(0xFFF43F5E),
          ],
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleSpiralVisuals(
          lineColor: colorScheme.secondary,
          lowColor: colorScheme.secondaryContainer,
          highColor: colorScheme.secondary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.28),
          activeColor: colorScheme.secondary,
          palette: const [
            Color(0xFFE0F2FE),
            Color(0xFF99F6E4),
            Color(0xFF0F766E),
            Color(0xFF7C3AED),
          ],
        );
    }
  }
}

class _DefaultSpiralTooltip extends StatelessWidget {
  final SimpleSpiralChartPoint point;
  final String formattedValue;
  final String formattedNormalized;

  const _DefaultSpiralTooltip({
    required this.point,
    required this.formattedValue,
    required this.formattedNormalized,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 174,
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
              _TooltipRow(label: 'Value', value: formattedValue),
              _TooltipRow(label: 'Range', value: formattedNormalized),
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
