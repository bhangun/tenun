import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../line/simple_line_chart.dart';

typedef SimpleSlopeValueFormatter = String Function(double value);
typedef SimpleSlopeTapCallback =
    void Function(SimpleSlopeChartData data, int index);
typedef SimpleSlopeTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleSlopeChartData data,
      int index,
      String formattedStart,
      String formattedEnd,
      String formattedDelta,
    );

class SimpleSlopeChartData {
  final String label;
  final double start;
  final double end;
  final Color? color;

  const SimpleSlopeChartData({
    required this.label,
    required this.start,
    required this.end,
    this.color,
  });

  double get delta => end - start;
}

/// A lightweight two-column slope chart for before/after movement.
class SimpleSlopeChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(88, 30, 88, 38);

  final List<SimpleSlopeChartData> data;
  final String startLabel;
  final String endLabel;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? lineColor;
  final Color? positiveColor;
  final Color? negativeColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool colorByDelta;
  final bool showGrid;
  final bool showValues;
  final bool showDelta;
  final bool showEndLabels;
  final bool showTooltip;
  final bool showActiveLine;
  final int gridLineCount;
  final double? strokeWidth;
  final double? dotRadius;
  final SimpleSlopeValueFormatter? valueFormatter;
  final SimpleSlopeValueFormatter? deltaFormatter;
  final SimpleSlopeTapCallback? onLineTap;
  final SimpleSlopeTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleSlopeChart({
    super.key,
    required this.data,
    this.startLabel = 'Start',
    this.endLabel = 'End',
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.lineColor,
    this.positiveColor,
    this.negativeColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.colorByDelta = true,
    this.showGrid = true,
    this.showValues = true,
    this.showDelta = true,
    this.showEndLabels = true,
    this.showTooltip = true,
    this.showActiveLine = true,
    this.gridLineCount = 4,
    this.strokeWidth,
    this.dotRadius,
    this.valueFormatter,
    this.deltaFormatter,
    this.onLineTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(dotRadius == null || dotRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleSlopeVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.start.isFinite && item.end.isFinite)
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedDeltaFormatter = deltaFormatter ?? _defaultDeltaFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Slope chart, no data.',
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
            visibleData,
            formatter,
            resolvedDeltaFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleSlopeChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            startLabel: startLabel,
            endLabel: endLabel,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals),
            lineColor: lineColor,
            positiveColor: positiveColor ?? visuals.positiveColor,
            negativeColor: negativeColor ?? visuals.negativeColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeZero: includeZero,
            colorByDelta: colorByDelta,
            showGrid: showGrid,
            showValues: showValues,
            showDelta: showDelta,
            showEndLabels: showEndLabels,
            showTooltip: showTooltip,
            showActiveLine: showActiveLine,
            gridLineCount: gridLineCount,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            dotRadius: dotRadius ?? visuals.dotRadius,
            valueFormatter: formatter,
            deltaFormatter: resolvedDeltaFormatter,
            onLineTap: onLineTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(
    ColorScheme colorScheme,
    _SimpleSlopeVisuals visuals,
  ) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return [
      lineColor ?? visuals.positiveColor,
      colorScheme.secondary,
      colorScheme.tertiary,
      visuals.negativeColor,
    ];
  }

  String _defaultSemanticLabel(
    List<SimpleSlopeChartData> visibleData,
    SimpleSlopeValueFormatter formatter,
    SimpleSlopeValueFormatter resolvedDeltaFormatter,
  ) {
    final visibleItems = visibleData
        .take(5)
        .map(
          (item) =>
              '${item.label} $startLabel ${formatter(item.start)}, '
              '$endLabel ${formatter(item.end)}, change '
              '${resolvedDeltaFormatter(item.delta)}',
        )
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 5);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'item' : 'items';
    return 'Slope chart, ${visibleData.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultDeltaFormatter(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${_defaultValueFormatter(value)}';
  }
}

class _SimpleSlopeChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleSlopeChartData> data;
  final String startLabel;
  final String endLabel;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? lineColor;
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool colorByDelta;
  final bool showGrid;
  final bool showValues;
  final bool showDelta;
  final bool showEndLabels;
  final bool showTooltip;
  final bool showActiveLine;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final SimpleSlopeValueFormatter valueFormatter;
  final SimpleSlopeValueFormatter deltaFormatter;
  final SimpleSlopeTapCallback? onLineTap;
  final SimpleSlopeTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleSlopeChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.startLabel,
    required this.endLabel,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.lineColor,
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.colorByDelta,
    required this.showGrid,
    required this.showValues,
    required this.showDelta,
    required this.showEndLabels,
    required this.showTooltip,
    required this.showActiveLine,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.valueFormatter,
    required this.deltaFormatter,
    required this.onLineTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleSlopeChartView> createState() => _SimpleSlopeChartViewState();
}

class _SimpleSlopeChartViewState extends State<_SimpleSlopeChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveLine || widget.onLineTap != null;

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
                painter: _SimpleSlopePainter(
                  data: widget.data,
                  startLabel: widget.startLabel,
                  endLabel: widget.endLabel,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  palette: widget.palette,
                  lineColor: widget.lineColor,
                  positiveColor: widget.positiveColor,
                  negativeColor: widget.negativeColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  includeZero: widget.includeZero,
                  colorByDelta: widget.colorByDelta,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showDelta: widget.showDelta,
                  showEndLabels: widget.showEndLabels,
                  showActiveLine: widget.showActiveLine,
                  gridLineCount: widget.gridLineCount,
                  strokeWidth: widget.strokeWidth,
                  dotRadius: widget.dotRadius,
                  valueFormatter: widget.valueFormatter,
                  deltaFormatter: widget.deltaFormatter,
                  activeIndex: widget.showActiveLine ? _activeIndex : null,
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
                        widget.onLineTap?.call(widget.data[index], index);
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
    final geometry = _SlopeGeometry.resolve(
      size: size,
      data: widget.data,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      includeZero: widget.includeZero,
      padding: widget.padding,
    );
    if (geometry.plot.isEmpty ||
        !geometry.plot.inflate(18).contains(position)) {
      return null;
    }

    var nearestIndex = -1;
    var nearestDistance = double.infinity;
    for (final segment in geometry.segments) {
      final distance = math.min(
        _distanceToSegment(position, segment.start, segment.end),
        math.min(
          (position - segment.start).distance,
          (position - segment.end).distance,
        ),
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = segment.index;
      }
    }

    final hitRadius = math.max(14.0, widget.strokeWidth + widget.dotRadius + 4);
    return nearestDistance <= hitRadius ? nearestIndex : null;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final lengthSquared = (end - start).distanceSquared;
    if (lengthSquared == 0) return (point - start).distance;
    final projection =
        ((point.dx - start.dx) * (end.dx - start.dx) +
            (point.dy - start.dy) * (end.dy - start.dy)) /
        lengthSquared;
    final t = projection.clamp(0.0, 1.0).toDouble();
    final closest = Offset(
      start.dx + (end.dx - start.dx) * t,
      start.dy + (end.dy - start.dy) * t,
    );
    return (point - closest).distance;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final item = widget.data[index];
    final formattedStart = widget.valueFormatter(item.start);
    final formattedEnd = widget.valueFormatter(item.end);
    final formattedDelta = widget.deltaFormatter(item.delta);
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 198.0;
    const tooltipHeight = 102.0;
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
            item,
            index,
            formattedStart,
            formattedEnd,
            formattedDelta,
          ) ??
          _DefaultSlopeTooltip(
            color: _lineColor(item, index),
            deltaColor: item.delta >= 0
                ? widget.positiveColor
                : widget.negativeColor,
            title: item.label,
            startLabel: widget.startLabel,
            endLabel: widget.endLabel,
            startValue: formattedStart,
            endValue: formattedEnd,
            deltaValue: formattedDelta,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final geometry = _SlopeGeometry.resolve(
      size: size,
      data: widget.data,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      includeZero: widget.includeZero,
      padding: widget.padding,
    );
    final segment = geometry.segments.firstWhere(
      (item) => item.index == index,
      orElse: () => geometry.segments.first,
    );
    return Offset(
      segment.start.dx + (segment.end.dx - segment.start.dx) * 0.72,
      segment.start.dy + (segment.end.dy - segment.start.dy) * 0.72,
    );
  }

  Color _lineColor(SimpleSlopeChartData item, int index) {
    if (item.color != null) return item.color!;
    if (widget.lineColor != null) return widget.lineColor!;
    if (widget.colorByDelta) {
      return item.delta >= 0 ? widget.positiveColor : widget.negativeColor;
    }
    return widget.palette[index % widget.palette.length];
  }
}

class _SimpleSlopePainter extends CustomPainter {
  final List<SimpleSlopeChartData> data;
  final String startLabel;
  final String endLabel;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? lineColor;
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool colorByDelta;
  final bool showGrid;
  final bool showValues;
  final bool showDelta;
  final bool showEndLabels;
  final bool showActiveLine;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final SimpleSlopeValueFormatter valueFormatter;
  final SimpleSlopeValueFormatter deltaFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleSlopePainter({
    required this.data,
    required this.startLabel,
    required this.endLabel,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.lineColor,
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.colorByDelta,
    required this.showGrid,
    required this.showValues,
    required this.showDelta,
    required this.showEndLabels,
    required this.showActiveLine,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.valueFormatter,
    required this.deltaFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _SlopeGeometry.resolve(
      size: size,
      data: data,
      minValue: minValue,
      maxValue: maxValue,
      includeZero: includeZero,
      padding: padding,
    );
    if (geometry.plot.isEmpty || geometry.segments.isEmpty) return;

    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxes(canvas, geometry);
    _drawColumnLabels(canvas, geometry);
    _drawSlopes(canvas, geometry);
  }

  void _drawGrid(Canvas canvas, _SlopeGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value = geometry.min + geometry.span * (index / gridLineCount);
      final y = geometry.yForValue(value);
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
      _paintText(
        canvas,
        valueFormatter(value),
        labelStyle.copyWith(
          color: labelStyle.color?.withValues(alpha: 0.72),
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
        ),
        Offset(geometry.plot.left - 8, y),
        TextAlign.right,
        math.max(0.0, padding.left - 14),
        centeredY: true,
      );
    }
  }

  void _drawAxes(Canvas canvas, _SlopeGeometry geometry) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.1;
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.top),
      Offset(geometry.plot.left, geometry.plot.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(geometry.plot.right, geometry.plot.top),
      Offset(geometry.plot.right, geometry.plot.bottom),
      paint,
    );
  }

  void _drawColumnLabels(Canvas canvas, _SlopeGeometry geometry) {
    final style = valueStyle.copyWith(
      color: valueStyle.color?.withValues(alpha: 0.86),
      fontSize: math.max(10, (valueStyle.fontSize ?? 12) + 1),
    );
    _paintText(
      canvas,
      startLabel,
      style,
      Offset(geometry.plot.left, geometry.plot.top - 22),
      TextAlign.center,
      math.max(44.0, padding.left),
    );
    _paintText(
      canvas,
      endLabel,
      style,
      Offset(geometry.plot.right, geometry.plot.top - 22),
      TextAlign.center,
      math.max(44.0, padding.right),
    );
  }

  void _drawSlopes(Canvas canvas, _SlopeGeometry geometry) {
    for (final segment in geometry.segments) {
      final item = data[segment.index];
      final color = _lineColor(item, segment.index);
      final isActive = activeIndex == segment.index;
      final activeExists = activeIndex != null;
      final opacity = activeExists && !isActive ? 0.28 : 1.0;
      final animatedEnd = Offset(
        segment.start.dx + (segment.end.dx - segment.start.dx) * progress,
        segment.start.dy + (segment.end.dy - segment.start.dy) * progress,
      );
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = isActive ? strokeWidth + 1.4 : strokeWidth
        ..strokeCap = StrokeCap.round;

      if (showActiveLine && isActive) {
        canvas.drawLine(
          segment.start,
          animatedEnd,
          Paint()
            ..color = (activeColor ?? color).withValues(alpha: 0.16)
            ..strokeWidth = strokeWidth + 8
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawLine(segment.start, animatedEnd, paint);
      _drawDot(canvas, segment.start, color.withValues(alpha: opacity), false);
      _drawDot(canvas, animatedEnd, color.withValues(alpha: opacity), isActive);

      if ((showEndLabels || showValues) && progress > 0.72) {
        _drawEndpointLabels(canvas, segment, animatedEnd);
      }
      if (showDelta && progress > 0.74) {
        _drawDeltaLabel(canvas, geometry, segment, animatedEnd, color);
      }
    }
  }

  void _drawDot(Canvas canvas, Offset center, Color color, bool selected) {
    final radius = dotRadius * (0.55 + progress * 0.45);
    canvas.drawCircle(
      center,
      radius + 1.4,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
    if (!selected) return;
    final highlight = activeColor ?? color;
    canvas.drawCircle(
      center,
      radius + 5,
      Paint()..color = highlight.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      center,
      radius + 3,
      Paint()
        ..color = highlight.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawEndpointLabels(
    Canvas canvas,
    _SlopeSegmentLayout segment,
    Offset animatedEnd,
  ) {
    final item = data[segment.index];
    final startText = _endpointText(item.label, item.start, leadingValue: true);
    final endText = _endpointText(item.label, item.end, leadingValue: false);
    final textStyle = showValues ? valueStyle : labelStyle;

    if (showEndLabels || showValues) {
      _paintText(
        canvas,
        startText,
        textStyle,
        Offset(segment.start.dx - 10, segment.start.dy),
        TextAlign.right,
        math.max(0.0, padding.left - 16),
        centeredY: true,
      );
      _paintText(
        canvas,
        endText,
        textStyle,
        Offset(animatedEnd.dx + 10, animatedEnd.dy),
        TextAlign.left,
        math.max(0.0, padding.right - 16),
        centeredY: true,
      );
    }
  }

  String _endpointText(
    String label,
    double value, {
    required bool leadingValue,
  }) {
    if (showEndLabels && showValues) {
      return leadingValue
          ? '${valueFormatter(value)} $label'
          : '$label ${valueFormatter(value)}';
    }
    if (showEndLabels) return label;
    return valueFormatter(value);
  }

  void _drawDeltaLabel(
    Canvas canvas,
    _SlopeGeometry geometry,
    _SlopeSegmentLayout segment,
    Offset animatedEnd,
    Color color,
  ) {
    final item = data[segment.index];
    final text = deltaFormatter(item.delta);
    final midpoint = Offset(
      segment.start.dx + (animatedEnd.dx - segment.start.dx) * 0.5,
      segment.start.dy + (animatedEnd.dy - segment.start.dy) * 0.5,
    );
    final textColor = item.delta >= 0 ? positiveColor : negativeColor;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: valueStyle.copyWith(
          color: textColor,
          fontSize: math.max(9, (valueStyle.fontSize ?? 11) - 1),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 56);
    const insets = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + insets.horizontal;
    final height = painter.height + insets.vertical;
    final x = _safeClamp(
      midpoint.dx - width / 2,
      geometry.plot.left + 2,
      geometry.plot.right - width - 2,
    );
    final y = _safeClamp(
      midpoint.dy - height / 2,
      geometry.plot.top + 2,
      geometry.plot.bottom - height - 2,
    );
    final rect = Rect.fromLTWH(x, y, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = color.withValues(alpha: 0.12),
    );
    painter.paint(canvas, Offset(x + insets.left, y + insets.top));
  }

  Color _lineColor(SimpleSlopeChartData item, int index) {
    if (item.color != null) return item.color!;
    if (lineColor != null) return lineColor!;
    if (colorByDelta) {
      return item.delta >= 0 ? positiveColor : negativeColor;
    }
    return palette[index % palette.length];
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
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);

    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.center => anchor.dx - painter.width / 2,
      _ => anchor.dx,
    };
    final dy = centeredY ? anchor.dy - painter.height / 2 : anchor.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  double _safeClamp(double value, double min, double max) {
    if (max < min) return min;
    return value.clamp(min, max).toDouble();
  }

  @override
  bool shouldRepaint(covariant _SimpleSlopePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.startLabel != startLabel ||
        oldDelegate.endLabel != endLabel ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.positiveColor != positiveColor ||
        oldDelegate.negativeColor != negativeColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeZero != includeZero ||
        oldDelegate.colorByDelta != colorByDelta ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showDelta != showDelta ||
        oldDelegate.showEndLabels != showEndLabels ||
        oldDelegate.showActiveLine != showActiveLine ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.deltaFormatter != deltaFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _SlopeGeometry {
  final Rect plot;
  final double min;
  final double span;
  final List<_SlopeSegmentLayout> segments;

  const _SlopeGeometry({
    required this.plot,
    required this.min,
    required this.span,
    required this.segments,
  });

  factory _SlopeGeometry.resolve({
    required Size size,
    required List<SimpleSlopeChartData> data,
    required double? minValue,
    required double? maxValue,
    required bool includeZero,
    required EdgeInsets padding,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );

    var resolvedMin = double.infinity;
    var resolvedMax = double.negativeInfinity;
    for (final item in data) {
      resolvedMin = math.min(resolvedMin, math.min(item.start, item.end));
      resolvedMax = math.max(resolvedMax, math.max(item.start, item.end));
    }

    if (!resolvedMin.isFinite || !resolvedMax.isFinite) {
      resolvedMin = 0;
      resolvedMax = 1;
    }
    if (includeZero) {
      resolvedMin = math.min(0, resolvedMin);
      resolvedMax = math.max(0, resolvedMax);
    }
    if (minValue != null && minValue.isFinite) resolvedMin = minValue;
    if (maxValue != null && maxValue.isFinite) resolvedMax = maxValue;

    if (resolvedMin > resolvedMax) {
      final swap = resolvedMin;
      resolvedMin = resolvedMax;
      resolvedMax = swap;
    }
    if (resolvedMin == resolvedMax) {
      final spread = resolvedMin == 0 ? 1.0 : resolvedMin.abs() * 0.08;
      resolvedMin -= spread;
      resolvedMax += spread;
    }

    final span = math.max(1e-9, resolvedMax - resolvedMin);
    double yForValue(double value) {
      final normalized = ((value - resolvedMin) / span)
          .clamp(0.0, 1.0)
          .toDouble();
      return plot.bottom - normalized * plot.height;
    }

    final segments = <_SlopeSegmentLayout>[];
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      segments.add(
        _SlopeSegmentLayout(
          index: index,
          start: Offset(plot.left, yForValue(item.start)),
          end: Offset(plot.right, yForValue(item.end)),
        ),
      );
    }

    return _SlopeGeometry(
      plot: plot,
      min: resolvedMin,
      span: span,
      segments: segments,
    );
  }

  double yForValue(double value) {
    final normalized = ((value - min) / span).clamp(0.0, 1.0).toDouble();
    return plot.bottom - normalized * plot.height;
  }
}

class _SlopeSegmentLayout {
  final int index;
  final Offset start;
  final Offset end;

  const _SlopeSegmentLayout({
    required this.index,
    required this.start,
    required this.end,
  });
}

class _SimpleSlopeVisuals {
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final double strokeWidth;
  final double dotRadius;

  const _SimpleSlopeVisuals({
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.strokeWidth,
    required this.dotRadius,
  });

  factory _SimpleSlopeVisuals.resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleSlopeVisuals(
          positiveColor: colorScheme.primary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          strokeWidth: 2.8,
          dotRadius: 5.2,
        );
      case SimpleTrendChartStyle.professional:
        return _SimpleSlopeVisuals(
          positiveColor: colorScheme.primary,
          negativeColor: colorScheme.error.withValues(alpha: 0.9),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          strokeWidth: 2.2,
          dotRadius: 4.6,
        );
      case SimpleTrendChartStyle.education:
        return _SimpleSlopeVisuals(
          positiveColor: colorScheme.secondary,
          negativeColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          strokeWidth: 2.7,
          dotRadius: 5.3,
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleSlopeVisuals(
          positiveColor: colorScheme.tertiary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          strokeWidth: 3.2,
          dotRadius: 5.8,
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleSlopeVisuals(
          positiveColor: colorScheme.primary,
          negativeColor: colorScheme.error.withValues(alpha: 0.88),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          strokeWidth: 2.6,
          dotRadius: 5.0,
        );
    }
  }
}

class _DefaultSlopeTooltip extends StatelessWidget {
  final Color color;
  final Color deltaColor;
  final String title;
  final String startLabel;
  final String endLabel;
  final String startValue;
  final String endValue;
  final String deltaValue;

  const _DefaultSlopeTooltip({
    required this.color,
    required this.deltaColor,
    required this.title,
    required this.startLabel,
    required this.endLabel,
    required this.startValue,
    required this.endValue,
    required this.deltaValue,
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
                  width: 8,
                  height: 8,
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
              label: startLabel,
              value: startValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: endLabel,
              value: endValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: 'Change',
              value: deltaValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: deltaColor),
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
