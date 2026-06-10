import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import '../line/simple_line_chart.dart';

typedef SimpleControlValueFormatter = String Function(double value);
typedef SimpleControlPointTapCallback =
    void Function(
      SimpleControlChartPoint point,
      int index,
      SimpleControlChartStats stats,
      bool isSignal,
    );
typedef SimpleControlTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleControlChartPoint point,
      int index,
      SimpleControlChartStats stats,
      bool isSignal,
      String formattedValue,
      String formattedCenter,
      String formattedLower,
      String formattedUpper,
    );

class SimpleControlChartPoint {
  final String label;
  final double value;
  final Color? color;

  const SimpleControlChartPoint({
    required this.label,
    required this.value,
    this.color,
  });
}

class SimpleControlChartStats {
  final double center;
  final double lowerControlLimit;
  final double upperControlLimit;
  final double lowerWarningLimit;
  final double upperWarningLimit;
  final double standardDeviation;
  final int count;
  final int signalCount;

  const SimpleControlChartStats({
    required this.center,
    required this.lowerControlLimit,
    required this.upperControlLimit,
    required this.lowerWarningLimit,
    required this.upperWarningLimit,
    required this.standardDeviation,
    required this.count,
    required this.signalCount,
  });

  bool isSignal(double value) {
    return value < lowerControlLimit || value > upperControlLimit;
  }
}

/// A simple process-control chart for stability, quality, SLA, learning,
/// measurement, and operational monitoring workflows.
class SimpleControlChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 20, 42);

  final List<SimpleControlChartPoint> points;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double? centerValue;
  final double? lowerControlLimit;
  final double? upperControlLimit;
  final double? lowerWarningLimit;
  final double? upperWarningLimit;
  final double sigmaMultiplier;
  final double warningSigmaMultiplier;
  final double height;
  final EdgeInsets padding;
  final Color? lineColor;
  final Color? dotColor;
  final Color? centerLineColor;
  final Color? controlLimitColor;
  final Color? warningBandColor;
  final Color? signalColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLine;
  final bool showDots;
  final bool showValues;
  final bool showLabels;
  final bool showCenterLine;
  final bool showControlLimits;
  final bool showWarningBand;
  final bool highlightSignals;
  final bool showTooltip;
  final bool showActivePoint;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? strokeWidth;
  final double? dotRadius;
  final SimpleControlValueFormatter? valueFormatter;
  final SimpleControlPointTapCallback? onPointTap;
  final SimpleControlTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleControlChart({
    super.key,
    required this.points,
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.centerValue,
    this.lowerControlLimit,
    this.upperControlLimit,
    this.lowerWarningLimit,
    this.upperWarningLimit,
    this.sigmaMultiplier = 3,
    this.warningSigmaMultiplier = 2,
    this.height = 260,
    this.padding = _defaultPadding,
    this.lineColor,
    this.dotColor,
    this.centerLineColor,
    this.controlLimitColor,
    this.warningBandColor,
    this.signalColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showLine = true,
    this.showDots = true,
    this.showValues = false,
    this.showLabels = true,
    this.showCenterLine = true,
    this.showControlLimits = true,
    this.showWarningBand = true,
    this.highlightSignals = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.strokeWidth,
    this.dotRadius,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(sigmaMultiplier > 0),
       assert(warningSigmaMultiplier > 0),
       assert(gridLineCount >= 2),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(dotRadius == null || dotRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleControlVisuals.resolve(style, colorScheme);
    final visiblePoints = points
        .where((point) => point.label.trim().isNotEmpty && point.value.isFinite)
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
            emptySemanticLabel: 'Control chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final stats = _resolveStats(visiblePoints);
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
          semanticLabel: _defaultSemanticLabel(visiblePoints, stats, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleControlChartView(
            width: width,
            height: chartHeight,
            points: visiblePoints,
            stats: stats,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            lineColor: lineColor ?? visuals.lineColor,
            dotColor: dotColor ?? visuals.dotColor,
            centerLineColor: centerLineColor ?? visuals.centerLineColor,
            controlLimitColor: controlLimitColor ?? visuals.controlLimitColor,
            warningBandColor: warningBandColor ?? visuals.warningBandColor,
            signalColor: signalColor ?? visuals.signalColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeZero: includeZero,
            showGrid: showGrid,
            showLine: showLine,
            showDots: showDots,
            showValues: showValues,
            showLabels: showLabels,
            showCenterLine: showCenterLine,
            showControlLimits: showControlLimits,
            showWarningBand: showWarningBand,
            highlightSignals: highlightSignals,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            dotRadius: dotRadius ?? visuals.dotRadius,
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

  SimpleControlChartStats _resolveStats(List<SimpleControlChartPoint> data) {
    final values = data.map((point) => point.value).toList();
    final mean =
        values.fold<double>(0, (sum, value) => sum + value) / values.length;
    final variance =
        values.fold<double>(0, (sum, value) {
          final delta = value - mean;
          return sum + delta * delta;
        }) /
        values.length;
    final sigma = math.sqrt(variance);
    final center = centerValue ?? mean;
    var lower = lowerControlLimit ?? center - sigma * sigmaMultiplier;
    var upper = upperControlLimit ?? center + sigma * sigmaMultiplier;
    if (lower > upper) {
      final previousLower = lower;
      lower = upper;
      upper = previousLower;
    }

    var warningLower =
        lowerWarningLimit ?? center - sigma * warningSigmaMultiplier;
    var warningUpper =
        upperWarningLimit ?? center + sigma * warningSigmaMultiplier;
    warningLower = warningLower.clamp(lower, upper).toDouble();
    warningUpper = warningUpper.clamp(lower, upper).toDouble();
    if (warningLower > warningUpper) {
      final previousLower = warningLower;
      warningLower = warningUpper;
      warningUpper = previousLower;
    }

    final signalCount = values
        .where((value) => value < lower || value > upper)
        .length;
    return SimpleControlChartStats(
      center: center,
      lowerControlLimit: lower,
      upperControlLimit: upper,
      lowerWarningLimit: warningLower,
      upperWarningLimit: warningUpper,
      standardDeviation: sigma,
      count: values.length,
      signalCount: signalCount,
    );
  }

  String _defaultSemanticLabel(
    List<SimpleControlChartPoint> visiblePoints,
    SimpleControlChartStats stats,
    SimpleControlValueFormatter formatter,
  ) {
    final summaries = visiblePoints
        .take(4)
        .map((point) => '${point.label} ${formatter(point.value)}')
        .join(', ');
    final suffix = visiblePoints.length > 4
        ? '; and ${visiblePoints.length - 4} more points'
        : '';
    final pointLabel = visiblePoints.length == 1 ? 'point' : 'points';
    final signalLabel = stats.signalCount == 1 ? 'signal' : 'signals';
    return 'Control chart, ${visiblePoints.length} $pointLabel. '
        'Center ${formatter(stats.center)}, limits '
        '${formatter(stats.lowerControlLimit)} to '
        '${formatter(stats.upperControlLimit)}. '
        '$summaries$suffix; ${stats.signalCount} $signalLabel.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _SimpleControlChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleControlChartPoint> points;
  final SimpleControlChartStats stats;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color lineColor;
  final Color dotColor;
  final Color centerLineColor;
  final Color controlLimitColor;
  final Color warningBandColor;
  final Color signalColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLine;
  final bool showDots;
  final bool showValues;
  final bool showLabels;
  final bool showCenterLine;
  final bool showControlLimits;
  final bool showWarningBand;
  final bool highlightSignals;
  final bool showTooltip;
  final bool showActivePoint;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final SimpleControlValueFormatter valueFormatter;
  final SimpleControlPointTapCallback? onPointTap;
  final SimpleControlTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleControlChartView({
    required this.width,
    required this.height,
    required this.points,
    required this.stats,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.lineColor,
    required this.dotColor,
    required this.centerLineColor,
    required this.controlLimitColor,
    required this.warningBandColor,
    required this.signalColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showLine,
    required this.showDots,
    required this.showValues,
    required this.showLabels,
    required this.showCenterLine,
    required this.showControlLimits,
    required this.showWarningBand,
    required this.highlightSignals,
    required this.showTooltip,
    required this.showActivePoint,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleControlChartView> createState() =>
      _SimpleControlChartViewState();
}

class _SimpleControlChartViewState extends State<_SimpleControlChartView> {
  _ControlSelection? _active;

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
                painter: _SimpleControlPainter(
                  points: widget.points,
                  stats: widget.stats,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  lineColor: widget.lineColor,
                  dotColor: widget.dotColor,
                  centerLineColor: widget.centerLineColor,
                  controlLimitColor: widget.controlLimitColor,
                  warningBandColor: widget.warningBandColor,
                  signalColor: widget.signalColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  includeZero: widget.includeZero,
                  showGrid: widget.showGrid,
                  showLine: widget.showLine,
                  showDots: widget.showDots,
                  showValues: widget.showValues,
                  showLabels: widget.showLabels,
                  showCenterLine: widget.showCenterLine,
                  showControlLimits: widget.showControlLimits,
                  showWarningBand: widget.showWarningBand,
                  highlightSignals: widget.highlightSignals,
                  showActivePoint: widget.showActivePoint,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  strokeWidth: widget.strokeWidth,
                  dotRadius: widget.dotRadius,
                  activeSelection: _active,
                  valueFormatter: widget.valueFormatter,
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
                      final selection = _hitTest(details.localPosition, size);
                      _setActive(selection);
                      if (selection == null) return;
                      final point = widget.points[selection.index];
                      final signal = widget.stats.isSignal(point.value);
                      widget.onPointTap?.call(
                        point,
                        selection.index,
                        widget.stats,
                        signal,
                      );
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _active != null)
                _buildTooltip(context, size, _active!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_ControlSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _ControlSelection? _hitTest(Offset position, Size size) {
    final geometry = _ControlGeometry.resolve(
      size: size,
      points: widget.points,
      stats: widget.stats,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      includeZero: widget.includeZero,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
    for (final point in geometry.points) {
      if ((position - point.center).distance <= widget.dotRadius + 8) {
        return _ControlSelection(point.index, point.center);
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _ControlSelection selection,
  ) {
    final point = widget.points[selection.index];
    final signal = widget.stats.isSignal(point.value);
    final formattedValue = widget.valueFormatter(point.value);
    final formattedCenter = widget.valueFormatter(widget.stats.center);
    final formattedLower = widget.valueFormatter(
      widget.stats.lowerControlLimit,
    );
    final formattedUpper = widget.valueFormatter(
      widget.stats.upperControlLimit,
    );
    const tooltipWidth = 196.0;
    const tooltipHeight = 100.0;
    final left = (selection.position.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (selection.position.dy - tooltipHeight - 8)
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
            selection.index,
            widget.stats,
            signal,
            formattedValue,
            formattedCenter,
            formattedLower,
            formattedUpper,
          ) ??
          _DefaultControlTooltip(
            color: signal ? widget.signalColor : widget.dotColor,
            title: point.label,
            value: formattedValue,
            center: formattedCenter,
            limits: '$formattedLower - $formattedUpper',
            status: signal ? 'Signal' : 'Stable',
          ),
    );
  }
}

class _SimpleControlPainter extends CustomPainter {
  final List<SimpleControlChartPoint> points;
  final SimpleControlChartStats stats;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color lineColor;
  final Color dotColor;
  final Color centerLineColor;
  final Color controlLimitColor;
  final Color warningBandColor;
  final Color signalColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLine;
  final bool showDots;
  final bool showValues;
  final bool showLabels;
  final bool showCenterLine;
  final bool showControlLimits;
  final bool showWarningBand;
  final bool highlightSignals;
  final bool showActivePoint;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final _ControlSelection? activeSelection;
  final SimpleControlValueFormatter valueFormatter;
  final double progress;

  const _SimpleControlPainter({
    required this.points,
    required this.stats,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.lineColor,
    required this.dotColor,
    required this.centerLineColor,
    required this.controlLimitColor,
    required this.warningBandColor,
    required this.signalColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showLine,
    required this.showDots,
    required this.showValues,
    required this.showLabels,
    required this.showCenterLine,
    required this.showControlLimits,
    required this.showWarningBand,
    required this.highlightSignals,
    required this.showActivePoint,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.activeSelection,
    required this.valueFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _ControlGeometry.resolve(
      size: size,
      points: points,
      stats: stats,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    if (geometry.plot.isEmpty || geometry.points.isEmpty) return;

    _drawReferenceBands(canvas, geometry);
    if (showWarningBand) _drawWarningBand(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    _drawControlLines(canvas, geometry);
    if (showLine) _drawLine(canvas, geometry);
    if (showDots) _drawDots(canvas, geometry);
    if (showLabels) _drawLabels(canvas, geometry);
  }

  void _drawReferenceBands(Canvas canvas, _ControlGeometry geometry) {
    final paint = Paint();
    for (final band in referenceBands) {
      final start = geometry.yForValue(band.from);
      final end = geometry.yForValue(band.to);
      paint.color = (band.color ?? lineColor).withValues(alpha: band.opacity);
      final rect = Rect.fromLTRB(
        geometry.plot.left,
        math.min(start, end),
        geometry.plot.right,
        math.max(start, end),
      );
      canvas.drawRect(rect, paint);
      if (band.showLabel && band.label != null) {
        _paintText(
          canvas,
          band.label!,
          labelStyle.copyWith(color: paint.color.withValues(alpha: 0.9)),
          Offset(geometry.plot.right - 4, rect.center.dy),
          TextAlign.right,
          86,
          centeredY: true,
        );
      }
    }
  }

  void _drawWarningBand(Canvas canvas, _ControlGeometry geometry) {
    final start = geometry.yForValue(stats.lowerWarningLimit);
    final end = geometry.yForValue(stats.upperWarningLimit);
    canvas.drawRect(
      Rect.fromLTRB(
        geometry.plot.left,
        math.min(start, end),
        geometry.plot.right,
        math.max(start, end),
      ),
      Paint()..color = warningBandColor.withValues(alpha: 0.1),
    );
  }

  void _drawGrid(Canvas canvas, _ControlGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          geometry.range.min + geometry.range.span * (index / gridLineCount);
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
        math.max(0.0, padding.left - 12),
        centeredY: true,
      );
    }
  }

  void _drawAxis(Canvas canvas, _ControlGeometry geometry) {
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

  void _drawReferenceLines(Canvas canvas, _ControlGeometry geometry) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      _drawHorizontalRule(
        canvas,
        geometry,
        line.value,
        line.color ?? axisColor,
        line.strokeWidth,
        line.lineStyle,
        line.showLabel ? line.label : null,
      );
    }
  }

  void _drawControlLines(Canvas canvas, _ControlGeometry geometry) {
    if (showControlLimits) {
      _drawHorizontalRule(
        canvas,
        geometry,
        stats.upperControlLimit,
        controlLimitColor,
        1.4,
        SimpleChartReferenceLineStyle.dashed,
        'UCL',
      );
      _drawHorizontalRule(
        canvas,
        geometry,
        stats.lowerControlLimit,
        controlLimitColor,
        1.4,
        SimpleChartReferenceLineStyle.dashed,
        'LCL',
      );
    }
    if (showCenterLine) {
      _drawHorizontalRule(
        canvas,
        geometry,
        stats.center,
        centerLineColor,
        1.5,
        SimpleChartReferenceLineStyle.solid,
        'Mean',
      );
    }
  }

  void _drawHorizontalRule(
    Canvas canvas,
    _ControlGeometry geometry,
    double value,
    Color color,
    double width,
    SimpleChartReferenceLineStyle style,
    String? label,
  ) {
    final y = geometry.yForValue(value);
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    _drawStyledLine(
      canvas,
      Offset(geometry.plot.left, y),
      Offset(geometry.plot.right, y),
      paint,
      style,
    );
    if (label != null) {
      _paintText(
        canvas,
        label,
        labelStyle.copyWith(color: color),
        Offset(geometry.plot.right - 4, y - 4),
        TextAlign.right,
        54,
      );
    }
  }

  void _drawLine(Canvas canvas, _ControlGeometry geometry) {
    final path = Path();
    final baseline = geometry.yForValue(stats.center);
    for (var index = 0; index < geometry.points.length; index++) {
      final point = geometry.points[index];
      final y = baseline + (point.center.dy - baseline) * progress;
      final animated = Offset(point.center.dx, y);
      if (index == 0) {
        path.moveTo(animated.dx, animated.dy);
      } else {
        path.lineTo(animated.dx, animated.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawDots(Canvas canvas, _ControlGeometry geometry) {
    final radius = dotRadius * (0.45 + progress * 0.55);
    final baseline = geometry.yForValue(stats.center);
    for (final point in geometry.points) {
      final source = points[point.index];
      final signal = stats.isSignal(source.value);
      final color =
          source.color ?? (highlightSignals && signal ? signalColor : dotColor);
      final center = Offset(
        point.center.dx,
        baseline + (point.center.dy - baseline) * progress,
      );
      final selected = activeSelection?.index == point.index;

      canvas.drawCircle(
        center,
        radius + 1.4,
        Paint()..color = Colors.white.withValues(alpha: 0.86),
      );
      canvas.drawCircle(center, radius, Paint()..color = color);

      if (highlightSignals && signal) {
        canvas.drawCircle(
          center,
          radius + 4.2,
          Paint()
            ..color = signalColor.withValues(alpha: 0.88)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }

      if (showActivePoint && selected) {
        canvas.drawCircle(
          center,
          radius + 6,
          Paint()..color = activeColor.withValues(alpha: 0.16),
        );
        canvas.drawCircle(
          center,
          radius + 3,
          Paint()
            ..color = activeColor.withValues(alpha: 0.94)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      if (showValues && progress > 0.7) {
        _paintText(
          canvas,
          valueFormatter(source.value),
          valueStyle.copyWith(color: color),
          Offset(center.dx, center.dy - radius - 17),
          TextAlign.center,
          54,
        );
      }
    }
  }

  void _drawLabels(Canvas canvas, _ControlGeometry geometry) {
    for (final point in geometry.points) {
      _paintText(
        canvas,
        points[point.index].label,
        labelStyle,
        Offset(point.center.dx, geometry.plot.bottom + 18),
        TextAlign.center,
        58,
      );
    }
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

  @override
  bool shouldRepaint(covariant _SimpleControlPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.stats != stats ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.centerLineColor != centerLineColor ||
        oldDelegate.controlLimitColor != controlLimitColor ||
        oldDelegate.warningBandColor != warningBandColor ||
        oldDelegate.signalColor != signalColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeZero != includeZero ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLine != showLine ||
        oldDelegate.showDots != showDots ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showCenterLine != showCenterLine ||
        oldDelegate.showControlLimits != showControlLimits ||
        oldDelegate.showWarningBand != showWarningBand ||
        oldDelegate.highlightSignals != highlightSignals ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _ControlGeometry {
  final Rect plot;
  final _ControlValueRange range;
  final List<_ControlPointLayout> points;

  const _ControlGeometry({
    required this.plot,
    required this.range,
    required this.points,
  });

  factory _ControlGeometry.resolve({
    required Size size,
    required List<SimpleControlChartPoint> points,
    required SimpleControlChartStats stats,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required bool includeZero,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0 || points.isEmpty) {
      return _ControlGeometry(
        plot: plot,
        range: const _ControlValueRange(0, 1),
        points: const [],
      );
    }

    final range = _ControlValueRange.resolve(
      points: points,
      stats: stats,
      minValue: minValue,
      maxValue: maxValue,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    final step = points.length == 1 ? 0.0 : plot.width / (points.length - 1);
    final layouts = <_ControlPointLayout>[];
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1 ? plot.center.dx : plot.left + step * index;
      layouts.add(
        _ControlPointLayout(
          index: index,
          center: Offset(x, _yForValue(points[index].value, plot, range)),
        ),
      );
    }

    return _ControlGeometry(plot: plot, range: range, points: layouts);
  }

  double yForValue(double value) => _yForValue(value, plot, range);

  static double _yForValue(double value, Rect plot, _ControlValueRange range) {
    final normalized = ((value - range.min) / range.span).clamp(0.0, 1.0);
    return plot.bottom - normalized * plot.height;
  }
}

class _ControlPointLayout {
  final int index;
  final Offset center;

  const _ControlPointLayout({required this.index, required this.center});
}

class _ControlSelection {
  final int index;
  final Offset position;

  const _ControlSelection(this.index, this.position);

  @override
  bool operator ==(Object other) {
    return other is _ControlSelection && other.index == index;
  }

  @override
  int get hashCode => index.hashCode;
}

class _ControlValueRange {
  final double min;
  final double max;

  const _ControlValueRange(this.min, this.max);

  double get span => max - min;

  factory _ControlValueRange.resolve({
    required List<SimpleControlChartPoint> points,
    required SimpleControlChartStats stats,
    required double? minValue,
    required double? maxValue,
    required bool includeZero,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    var lower = double.infinity;
    var upper = double.negativeInfinity;
    for (final point in points) {
      lower = math.min(lower, point.value);
      upper = math.max(upper, point.value);
    }
    for (final value in [
      stats.center,
      stats.lowerControlLimit,
      stats.upperControlLimit,
      stats.lowerWarningLimit,
      stats.upperWarningLimit,
    ]) {
      lower = math.min(lower, value);
      upper = math.max(upper, value);
    }
    for (final line in referenceLines) {
      if (line.value.isFinite) {
        lower = math.min(lower, line.value);
        upper = math.max(upper, line.value);
      }
    }
    for (final band in referenceBands) {
      if (band.from.isFinite) lower = math.min(lower, band.from);
      if (band.to.isFinite) upper = math.max(upper, band.to);
    }
    if (includeZero) {
      lower = math.min(lower, 0.0);
      upper = math.max(upper, 0.0);
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
    } else if (minValue == null || maxValue == null) {
      final pad = (upper - lower) * 0.08;
      if (minValue == null) lower -= pad;
      if (maxValue == null) upper += pad;
    }
    return _ControlValueRange(lower, upper);
  }
}

class _SimpleControlVisuals {
  final Color lineColor;
  final Color dotColor;
  final Color centerLineColor;
  final Color controlLimitColor;
  final Color warningBandColor;
  final Color signalColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double strokeWidth;
  final double dotRadius;

  const _SimpleControlVisuals({
    required this.lineColor,
    required this.dotColor,
    required this.centerLineColor,
    required this.controlLimitColor,
    required this.warningBandColor,
    required this.signalColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.strokeWidth,
    required this.dotRadius,
  });

  factory _SimpleControlVisuals.resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleControlVisuals(
          lineColor: colorScheme.primary,
          dotColor: colorScheme.primary,
          centerLineColor: colorScheme.tertiary,
          controlLimitColor: colorScheme.error,
          warningBandColor: colorScheme.secondary,
          signalColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          activeColor: colorScheme.primary,
          strokeWidth: 2.8,
          dotRadius: 4,
        );
      case SimpleTrendChartStyle.professional:
        return _SimpleControlVisuals(
          lineColor: colorScheme.primary,
          dotColor: colorScheme.primary,
          centerLineColor: colorScheme.onSurface,
          controlLimitColor: colorScheme.error,
          warningBandColor: colorScheme.primary,
          signalColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.72),
          activeColor: colorScheme.primary,
          strokeWidth: 2.2,
          dotRadius: 3.3,
        );
      case SimpleTrendChartStyle.education:
        return _SimpleControlVisuals(
          lineColor: colorScheme.secondary,
          dotColor: colorScheme.secondary,
          centerLineColor: colorScheme.primary,
          controlLimitColor: colorScheme.error,
          warningBandColor: colorScheme.tertiary,
          signalColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.65),
          activeColor: colorScheme.secondary,
          strokeWidth: 2.5,
          dotRadius: 4.2,
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleControlVisuals(
          lineColor: colorScheme.tertiary,
          dotColor: colorScheme.tertiary,
          centerLineColor: colorScheme.primary,
          controlLimitColor: colorScheme.error,
          warningBandColor: colorScheme.secondary,
          signalColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          activeColor: colorScheme.tertiary,
          strokeWidth: 3,
          dotRadius: 4.2,
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleControlVisuals(
          lineColor: colorScheme.primary,
          dotColor: colorScheme.primary,
          centerLineColor: colorScheme.tertiary,
          controlLimitColor: colorScheme.error,
          warningBandColor: colorScheme.secondary,
          signalColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: colorScheme.primary,
          strokeWidth: 2.6,
          dotRadius: 3.8,
        );
    }
  }
}

class _DefaultControlTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String center;
  final String limits;
  final String status;

  const _DefaultControlTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.center,
    required this.limits,
    required this.status,
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
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _TooltipMetric(label: 'Value', value: value),
            const SizedBox(height: 4),
            _TooltipMetric(label: 'Center', value: center),
            const SizedBox(height: 4),
            _TooltipMetric(label: 'Limits', value: limits),
            const SizedBox(height: 4),
            _TooltipMetric(label: 'Status', value: status),
          ],
        ),
      ),
    );
  }
}

class _TooltipMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TooltipMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onInverseSurface.withValues(alpha: 0.74),
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
    );
  }
}
