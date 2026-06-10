import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleBlandAltmanValueFormatter = String Function(double value);
typedef SimpleBlandAltmanPointTapCallback =
    void Function(
      SimpleBlandAltmanPoint point,
      int index,
      SimpleBlandAltmanStats stats,
      bool outsideLimits,
    );
typedef SimpleBlandAltmanTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleBlandAltmanPoint point,
      int index,
      SimpleBlandAltmanStats stats,
      bool outsideLimits,
      String formattedMean,
      String formattedDifference,
      String formattedBias,
    );

class SimpleBlandAltmanPoint {
  final String label;
  final double measurementA;
  final double measurementB;
  final String? group;
  final Color? color;

  const SimpleBlandAltmanPoint({
    required this.label,
    required this.measurementA,
    required this.measurementB,
    this.group,
    this.color,
  });

  double get mean => (measurementA + measurementB) / 2;

  double get difference => measurementB - measurementA;
}

class SimpleBlandAltmanStats {
  final double bias;
  final double standardDeviation;
  final double lowerAgreementLimit;
  final double upperAgreementLimit;
  final int count;
  final int outsideLimitCount;

  const SimpleBlandAltmanStats({
    required this.bias,
    required this.standardDeviation,
    required this.lowerAgreementLimit,
    required this.upperAgreementLimit,
    required this.count,
    required this.outsideLimitCount,
  });

  bool isOutsideLimits(double difference) {
    return difference < lowerAgreementLimit || difference > upperAgreementLimit;
  }
}

/// An agreement plot for comparing two measurement methods, model outputs,
/// graders, quality checks, and repeated business-process readings.
class SimpleBlandAltmanChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(56, 18, 24, 42);

  final List<SimpleBlandAltmanPoint> points;
  final SimpleBarChartStyle style;
  final double? minMean;
  final double? maxMean;
  final double? minDifference;
  final double? maxDifference;
  final double agreementMultiplier;
  final double height;
  final EdgeInsets padding;
  final String methodALabel;
  final String methodBLabel;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color? pointColor;
  final Color? outlierColor;
  final Color? biasLineColor;
  final Color? agreementLineColor;
  final Color? agreementBandColor;
  final Color? zeroLineColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZeroDifference;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showBiasLine;
  final bool showAgreementLimits;
  final bool showAgreementBand;
  final bool showZeroLine;
  final bool showAxisLabels;
  final bool highlightOutliers;
  final int gridLineCount;
  final double pointRadius;
  final SimpleBlandAltmanValueFormatter? meanFormatter;
  final SimpleBlandAltmanValueFormatter? differenceFormatter;
  final SimpleBlandAltmanPointTapCallback? onPointTap;
  final SimpleBlandAltmanTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleBlandAltmanChart({
    super.key,
    required this.points,
    this.style = SimpleBarChartStyle.elegant,
    this.minMean,
    this.maxMean,
    this.minDifference,
    this.maxDifference,
    this.agreementMultiplier = 1.96,
    this.height = 260,
    this.padding = _defaultPadding,
    this.methodALabel = 'Method A',
    this.methodBLabel = 'Method B',
    this.xAxisLabel,
    this.yAxisLabel,
    this.pointColor,
    this.outlierColor,
    this.biasLineColor,
    this.agreementLineColor,
    this.agreementBandColor,
    this.zeroLineColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.includeZeroDifference = true,
    this.showGrid = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.showBiasLine = true,
    this.showAgreementLimits = true,
    this.showAgreementBand = true,
    this.showZeroLine = true,
    this.showAxisLabels = true,
    this.highlightOutliers = true,
    this.gridLineCount = 4,
    this.pointRadius = 5,
    this.meanFormatter,
    this.differenceFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(agreementMultiplier > 0),
       assert(gridLineCount >= 2),
       assert(pointRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleBlandAltmanVisuals.resolve(style, colorScheme);
    final visiblePoints = points
        .where(
          (point) =>
              point.label.trim().isNotEmpty &&
              point.measurementA.isFinite &&
              point.measurementB.isFinite,
        )
        .toList();
    final resolvedMeanFormatter = meanFormatter ?? _defaultValueFormatter;
    final resolvedDifferenceFormatter =
        differenceFormatter ?? _defaultSignedValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visiblePoints.length < 2) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Bland-Altman chart, no data.',
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
          semanticLabel: _defaultSemanticLabel(
            visiblePoints,
            stats,
            resolvedDifferenceFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleBlandAltmanChartView(
            width: width,
            height: chartHeight,
            points: visiblePoints,
            stats: stats,
            minMean: minMean,
            maxMean: maxMean,
            minDifference: minDifference,
            maxDifference: maxDifference,
            padding: padding,
            xAxisLabel: xAxisLabel ?? 'Mean of $methodALabel and $methodBLabel',
            yAxisLabel: yAxisLabel ?? '$methodBLabel - $methodALabel',
            palette: _resolvePalette(visuals.palette),
            pointColor: pointColor ?? visuals.pointColor,
            outlierColor: outlierColor ?? visuals.outlierColor,
            biasLineColor: biasLineColor ?? visuals.biasLineColor,
            agreementLineColor:
                agreementLineColor ?? visuals.agreementLineColor,
            agreementBandColor:
                agreementBandColor ?? visuals.agreementBandColor,
            zeroLineColor: zeroLineColor ?? visuals.zeroLineColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeZeroDifference: includeZeroDifference,
            showGrid: showGrid,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            showBiasLine: showBiasLine,
            showAgreementLimits: showAgreementLimits,
            showAgreementBand: showAgreementBand,
            showZeroLine: showZeroLine,
            showAxisLabels: showAxisLabels,
            highlightOutliers: highlightOutliers,
            gridLineCount: gridLineCount,
            pointRadius: pointRadius,
            meanFormatter: resolvedMeanFormatter,
            differenceFormatter: resolvedDifferenceFormatter,
            onPointTap: onPointTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(List<Color> fallback) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return fallback;
  }

  SimpleBlandAltmanStats _resolveStats(
    List<SimpleBlandAltmanPoint> visiblePoints,
  ) {
    final differences = visiblePoints.map((point) => point.difference).toList();
    final bias =
        differences.fold(0.0, (sum, value) => sum + value) / differences.length;
    final variance = differences.length < 2
        ? 0.0
        : differences.fold(
                0.0,
                (sum, value) => sum + math.pow(value - bias, 2).toDouble(),
              ) /
              (differences.length - 1);
    final standardDeviation = math.sqrt(math.max(0.0, variance));
    final lower = bias - agreementMultiplier * standardDeviation;
    final upper = bias + agreementMultiplier * standardDeviation;
    final outsideCount = differences
        .where((value) => value < lower || value > upper)
        .length;
    return SimpleBlandAltmanStats(
      bias: bias,
      standardDeviation: standardDeviation,
      lowerAgreementLimit: lower,
      upperAgreementLimit: upper,
      count: visiblePoints.length,
      outsideLimitCount: outsideCount,
    );
  }

  String _defaultSemanticLabel(
    List<SimpleBlandAltmanPoint> visiblePoints,
    SimpleBlandAltmanStats stats,
    SimpleBlandAltmanValueFormatter formatter,
  ) {
    final outsideLabel = stats.outsideLimitCount == 1 ? 'point' : 'points';
    final countLabel = visiblePoints.length == 1 ? 'pair' : 'pairs';
    return 'Bland-Altman chart, ${visiblePoints.length} $countLabel. '
        'Bias ${formatter(stats.bias)}, lower agreement limit '
        '${formatter(stats.lowerAgreementLimit)}, upper agreement limit '
        '${formatter(stats.upperAgreementLimit)}, '
        '${stats.outsideLimitCount} $outsideLabel outside limits.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _defaultSignedValueFormatter(double value) {
    final prefix = value > 0 ? '+' : '';
    if (value == value.roundToDouble()) return '$prefix${value.toInt()}';
    return '$prefix${value.toStringAsFixed(1)}';
  }
}

class _SimpleBlandAltmanChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleBlandAltmanPoint> points;
  final SimpleBlandAltmanStats stats;
  final double? minMean;
  final double? maxMean;
  final double? minDifference;
  final double? maxDifference;
  final EdgeInsets padding;
  final String xAxisLabel;
  final String yAxisLabel;
  final List<Color> palette;
  final Color pointColor;
  final Color outlierColor;
  final Color biasLineColor;
  final Color agreementLineColor;
  final Color agreementBandColor;
  final Color zeroLineColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZeroDifference;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showBiasLine;
  final bool showAgreementLimits;
  final bool showAgreementBand;
  final bool showZeroLine;
  final bool showAxisLabels;
  final bool highlightOutliers;
  final int gridLineCount;
  final double pointRadius;
  final SimpleBlandAltmanValueFormatter meanFormatter;
  final SimpleBlandAltmanValueFormatter differenceFormatter;
  final SimpleBlandAltmanPointTapCallback? onPointTap;
  final SimpleBlandAltmanTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleBlandAltmanChartView({
    required this.width,
    required this.height,
    required this.points,
    required this.stats,
    required this.minMean,
    required this.maxMean,
    required this.minDifference,
    required this.maxDifference,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.palette,
    required this.pointColor,
    required this.outlierColor,
    required this.biasLineColor,
    required this.agreementLineColor,
    required this.agreementBandColor,
    required this.zeroLineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZeroDifference,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.showBiasLine,
    required this.showAgreementLimits,
    required this.showAgreementBand,
    required this.showZeroLine,
    required this.showAxisLabels,
    required this.highlightOutliers,
    required this.gridLineCount,
    required this.pointRadius,
    required this.meanFormatter,
    required this.differenceFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleBlandAltmanChartView> createState() =>
      _SimpleBlandAltmanChartViewState();
}

class _SimpleBlandAltmanChartViewState
    extends State<_SimpleBlandAltmanChartView> {
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
                painter: _SimpleBlandAltmanPainter(
                  points: widget.points,
                  stats: widget.stats,
                  minMean: widget.minMean,
                  maxMean: widget.maxMean,
                  minDifference: widget.minDifference,
                  maxDifference: widget.maxDifference,
                  padding: widget.padding,
                  xAxisLabel: widget.xAxisLabel,
                  yAxisLabel: widget.yAxisLabel,
                  palette: widget.palette,
                  pointColor: widget.pointColor,
                  outlierColor: widget.outlierColor,
                  biasLineColor: widget.biasLineColor,
                  agreementLineColor: widget.agreementLineColor,
                  agreementBandColor: widget.agreementBandColor,
                  zeroLineColor: widget.zeroLineColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  includeZeroDifference: widget.includeZeroDifference,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showLegend: widget.showLegend,
                  showActivePoint: widget.showActivePoint,
                  showBiasLine: widget.showBiasLine,
                  showAgreementLimits: widget.showAgreementLimits,
                  showAgreementBand: widget.showAgreementBand,
                  showZeroLine: widget.showZeroLine,
                  showAxisLabels: widget.showAxisLabels,
                  highlightOutliers: widget.highlightOutliers,
                  gridLineCount: widget.gridLineCount,
                  pointRadius: widget.pointRadius,
                  meanFormatter: widget.meanFormatter,
                  differenceFormatter: widget.differenceFormatter,
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
                      widget.onPointTap?.call(
                        point,
                        index,
                        widget.stats,
                        widget.stats.isOutsideLimits(point.difference),
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
    final plot = _plot(size);
    if (!plot.inflate(14).contains(position)) return null;
    final range = _resolveRange();
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var index = 0; index < widget.points.length; index++) {
      final point = widget.points[index];
      final center = Offset(
        _xForValue(point.mean, plot, range),
        _yForValue(point.difference, plot, range),
      );
      final distance = (position - center).distance;
      if (distance <= widget.pointRadius + 10 && distance < bestDistance) {
        bestIndex = index;
        bestDistance = distance;
      }
    }
    return bestIndex >= 0 ? bestIndex : null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final point = widget.points[index];
    final outsideLimits = widget.stats.isOutsideLimits(point.difference);
    final formattedMean = widget.meanFormatter(point.mean);
    final formattedDifference = widget.differenceFormatter(point.difference);
    final formattedBias = widget.differenceFormatter(widget.stats.bias);
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 198.0;
    const tooltipHeight = 110.0;
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
            widget.stats,
            outsideLimits,
            formattedMean,
            formattedDifference,
            formattedBias,
          ) ??
          _DefaultBlandAltmanTooltip(
            color: _pointColor(point, index, outsideLimits),
            title: point.label,
            meanValue: formattedMean,
            differenceValue: formattedDifference,
            biasValue: formattedBias,
            status: outsideLimits ? 'Outside limits' : 'Within limits',
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final plot = _plot(size);
    final range = _resolveRange();
    final point = widget.points[index];
    return Offset(
      _xForValue(point.mean, plot, range),
      _yForValue(point.difference, plot, range),
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

  _BlandAltmanRange _resolveRange() {
    return _resolveBlandAltmanRange(
      points: widget.points,
      stats: widget.stats,
      minMean: widget.minMean,
      maxMean: widget.maxMean,
      minDifference: widget.minDifference,
      maxDifference: widget.maxDifference,
      includeZeroDifference: widget.includeZeroDifference,
    );
  }

  double _xForValue(double value, Rect plot, _BlandAltmanRange range) {
    final normalized = (value - range.minMean) / range.meanSpan;
    return plot.left + normalized * plot.width;
  }

  double _yForValue(double value, Rect plot, _BlandAltmanRange range) {
    final normalized = (value - range.minDifference) / range.differenceSpan;
    return plot.bottom - normalized * plot.height;
  }

  Color _pointColor(
    SimpleBlandAltmanPoint point,
    int index,
    bool outsideLimits,
  ) {
    if (outsideLimits && widget.highlightOutliers) return widget.outlierColor;
    if (point.color != null) return point.color!;
    final group = point.group;
    if (group == null || group.isEmpty) return widget.pointColor;
    final groups = _groupsFor(widget.points);
    final groupIndex = math.max(0, groups.indexOf(group));
    return widget.palette[groupIndex % widget.palette.length];
  }
}

class _SimpleBlandAltmanPainter extends CustomPainter {
  final List<SimpleBlandAltmanPoint> points;
  final SimpleBlandAltmanStats stats;
  final double? minMean;
  final double? maxMean;
  final double? minDifference;
  final double? maxDifference;
  final EdgeInsets padding;
  final String xAxisLabel;
  final String yAxisLabel;
  final List<Color> palette;
  final Color pointColor;
  final Color outlierColor;
  final Color biasLineColor;
  final Color agreementLineColor;
  final Color agreementBandColor;
  final Color zeroLineColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZeroDifference;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showActivePoint;
  final bool showBiasLine;
  final bool showAgreementLimits;
  final bool showAgreementBand;
  final bool showZeroLine;
  final bool showAxisLabels;
  final bool highlightOutliers;
  final int gridLineCount;
  final double pointRadius;
  final SimpleBlandAltmanValueFormatter meanFormatter;
  final SimpleBlandAltmanValueFormatter differenceFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleBlandAltmanPainter({
    required this.points,
    required this.stats,
    required this.minMean,
    required this.maxMean,
    required this.minDifference,
    required this.maxDifference,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.palette,
    required this.pointColor,
    required this.outlierColor,
    required this.biasLineColor,
    required this.agreementLineColor,
    required this.agreementBandColor,
    required this.zeroLineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZeroDifference,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showActivePoint,
    required this.showBiasLine,
    required this.showAgreementLimits,
    required this.showAgreementBand,
    required this.showZeroLine,
    required this.showAxisLabels,
    required this.highlightOutliers,
    required this.gridLineCount,
    required this.pointRadius,
    required this.meanFormatter,
    required this.differenceFormatter,
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
    if (showAgreementBand) _drawAgreementBand(canvas, plot, range);
    if (showGrid) _drawGrid(canvas, plot, range);
    _drawAxes(canvas, plot);
    if (showZeroLine) {
      _drawHorizontalLine(canvas, plot, range, 0, zeroLineColor);
    }
    if (showBiasLine) {
      _drawHorizontalLine(canvas, plot, range, stats.bias, biasLineColor);
    }
    if (showAgreementLimits) _drawAgreementLines(canvas, plot, range);
    _drawPoints(canvas, plot, range);
    if (showAxisLabels) _drawAxisLabels(canvas, plot);
    if (showLegend) _drawLegend(canvas, plot);
  }

  _BlandAltmanRange _resolveRange() {
    return _resolveBlandAltmanRange(
      points: points,
      stats: stats,
      minMean: minMean,
      maxMean: maxMean,
      minDifference: minDifference,
      maxDifference: maxDifference,
      includeZeroDifference: includeZeroDifference,
    );
  }

  double _xForValue(double value, Rect plot, _BlandAltmanRange range) {
    final normalized = (value - range.minMean) / range.meanSpan;
    return plot.left + normalized * plot.width;
  }

  double _yForValue(double value, Rect plot, _BlandAltmanRange range) {
    final normalized = (value - range.minDifference) / range.differenceSpan;
    return plot.bottom - normalized * plot.height;
  }

  void _drawAgreementBand(Canvas canvas, Rect plot, _BlandAltmanRange range) {
    final lowerY = _yForValue(stats.lowerAgreementLimit, plot, range);
    final upperY = _yForValue(stats.upperAgreementLimit, plot, range);
    final rect = Rect.fromLTRB(
      plot.left,
      math.max(plot.top, math.min(lowerY, upperY)),
      plot.right,
      math.min(plot.bottom, math.max(lowerY, upperY)),
    );
    if (rect.height <= 0) return;
    canvas.drawRect(rect, Paint()..color = agreementBandColor);
  }

  void _drawGrid(Canvas canvas, Rect plot, _BlandAltmanRange range) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final meanValue = range.minMean + range.meanSpan * index / gridLineCount;
      final differenceValue =
          range.minDifference + range.differenceSpan * index / gridLineCount;
      final x = _xForValue(meanValue, plot, range);
      final y = _yForValue(differenceValue, plot, range);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), paint);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);

      final xPainter = _textPainter(
        meanFormatter(meanValue),
        labelStyle.copyWith(color: labelStyle.color?.withValues(alpha: 0.72)),
        textAlign: TextAlign.center,
      )..layout();
      xPainter.paint(canvas, Offset(x - xPainter.width / 2, plot.bottom + 8));

      final yPainter = _textPainter(
        differenceFormatter(differenceValue),
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

  void _drawAgreementLines(Canvas canvas, Rect plot, _BlandAltmanRange range) {
    _drawHorizontalLine(
      canvas,
      plot,
      range,
      stats.lowerAgreementLimit,
      agreementLineColor,
      label: 'LoA',
    );
    _drawHorizontalLine(
      canvas,
      plot,
      range,
      stats.upperAgreementLimit,
      agreementLineColor,
      label: 'LoA',
    );
  }

  void _drawHorizontalLine(
    Canvas canvas,
    Rect plot,
    _BlandAltmanRange range,
    double value,
    Color color, {
    String? label,
  }) {
    if (value < range.minDifference || value > range.maxDifference) return;
    final y = _yForValue(value, plot, range);
    _drawStyledLine(
      canvas,
      Offset(plot.left, y),
      Offset(plot.right, y),
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
      label == null ? _LineStyle.solid : _LineStyle.dashed,
    );

    if (label != null) {
      final painter = _textPainter(
        '$label ${differenceFormatter(value)}',
        labelStyle.copyWith(
          color: color,
          fontSize: (labelStyle.fontSize ?? 12) * 0.9,
          fontWeight: FontWeight.w700,
        ),
        maxWidth: 88,
      )..layout(maxWidth: 88);
      final x = plot.right - painter.width - 4;
      final textY = _safeClamp(
        y - painter.height - 3,
        plot.top + 2,
        plot.bottom - painter.height - 2,
      );
      painter.paint(canvas, Offset(x, textY));
    }
  }

  void _drawPoints(Canvas canvas, Rect plot, _BlandAltmanRange range) {
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final outsideLimits = stats.isOutsideLimits(point.difference);
      final color = _pointColor(point, index, outsideLimits);
      final center = Offset(
        _xForValue(point.mean, plot, range),
        _yForValue(point.difference, plot, range),
      );
      final radius = pointRadius * progress;
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

      if (highlightOutliers && outsideLimits) {
        canvas.drawCircle(
          center,
          radius + 3,
          Paint()
            ..color = outlierColor.withValues(alpha: 0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }

      if (showValues && points.length <= 16) {
        _drawPointLabel(canvas, point, center, plot, color, radius);
      }
    }
  }

  void _drawPointLabel(
    Canvas canvas,
    SimpleBlandAltmanPoint point,
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
      maxWidth: 70,
    )..layout(maxWidth: 70);
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
    final xPainter = _textPainter(
      xAxisLabel,
      labelStyle.copyWith(fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    )..layout(maxWidth: plot.width);
    xPainter.paint(
      canvas,
      Offset(plot.center.dx - xPainter.width / 2, plot.bottom + 25),
    );

    canvas.save();
    canvas.translate(plot.left - padding.left + 12, plot.center.dy);
    canvas.rotate(-math.pi / 2);
    final yPainter = _textPainter(
      yAxisLabel,
      labelStyle.copyWith(fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    )..layout(maxWidth: plot.height);
    yPainter.paint(canvas, Offset(-yPainter.width / 2, -yPainter.height / 2));
    canvas.restore();
  }

  void _drawLegend(Canvas canvas, Rect plot) {
    final groups = _groupsFor(points);
    if (groups.length <= 1 && stats.outsideLimitCount == 0) return;
    final rowHeight = 20.0;
    final legendWidth = math.min(124.0, plot.width * 0.36);
    final left = plot.right - legendWidth - 6;
    var top = plot.top + 6;
    final legendItems = <_LegendItem>[
      for (var index = 0; index < groups.length; index++)
        _LegendItem(groups[index], palette[index % palette.length]),
      if (stats.outsideLimitCount > 0 && highlightOutliers)
        _LegendItem('Outside limits', outlierColor),
    ];

    for (final item in legendItems) {
      if (top + rowHeight > plot.bottom) break;
      canvas.drawCircle(
        Offset(left + 5, top + 9),
        4,
        Paint()..color = item.color,
      );
      final painter = _textPainter(
        item.label,
        labelStyle,
        maxWidth: legendWidth - 16,
      )..layout(maxWidth: legendWidth - 16);
      painter.paint(canvas, Offset(left + 14, top + 9 - painter.height / 2));
      top += rowHeight;
    }
  }

  void _drawStyledLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    _LineStyle style,
  ) {
    if (style == _LineStyle.solid) {
      canvas.drawLine(start, end, paint);
      return;
    }
    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) return;
    final direction = delta / distance;
    const dash = 7.0;
    const gap = 5.0;
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

  Color _pointColor(
    SimpleBlandAltmanPoint point,
    int index,
    bool outsideLimits,
  ) {
    if (outsideLimits && highlightOutliers) return outlierColor;
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
  bool shouldRepaint(covariant _SimpleBlandAltmanPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.stats != stats ||
        oldDelegate.minMean != minMean ||
        oldDelegate.maxMean != maxMean ||
        oldDelegate.minDifference != minDifference ||
        oldDelegate.maxDifference != maxDifference ||
        oldDelegate.padding != padding ||
        oldDelegate.xAxisLabel != xAxisLabel ||
        oldDelegate.yAxisLabel != yAxisLabel ||
        oldDelegate.palette != palette ||
        oldDelegate.pointColor != pointColor ||
        oldDelegate.outlierColor != outlierColor ||
        oldDelegate.biasLineColor != biasLineColor ||
        oldDelegate.agreementLineColor != agreementLineColor ||
        oldDelegate.agreementBandColor != agreementBandColor ||
        oldDelegate.zeroLineColor != zeroLineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeZeroDifference != includeZeroDifference ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.showBiasLine != showBiasLine ||
        oldDelegate.showAgreementLimits != showAgreementLimits ||
        oldDelegate.showAgreementBand != showAgreementBand ||
        oldDelegate.showZeroLine != showZeroLine ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.highlightOutliers != highlightOutliers ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.meanFormatter != meanFormatter ||
        oldDelegate.differenceFormatter != differenceFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

_BlandAltmanRange _resolveBlandAltmanRange({
  required List<SimpleBlandAltmanPoint> points,
  required SimpleBlandAltmanStats stats,
  required double? minMean,
  required double? maxMean,
  required double? minDifference,
  required double? maxDifference,
  required bool includeZeroDifference,
}) {
  var lowerMean = double.infinity;
  var upperMean = double.negativeInfinity;
  var lowerDifference = double.infinity;
  var upperDifference = double.negativeInfinity;

  for (final point in points) {
    lowerMean = math.min(lowerMean, point.mean);
    upperMean = math.max(upperMean, point.mean);
    lowerDifference = math.min(lowerDifference, point.difference);
    upperDifference = math.max(upperDifference, point.difference);
  }
  lowerDifference = math.min(lowerDifference, stats.lowerAgreementLimit);
  upperDifference = math.max(upperDifference, stats.upperAgreementLimit);
  if (includeZeroDifference) {
    lowerDifference = math.min(lowerDifference, 0);
    upperDifference = math.max(upperDifference, 0);
  }

  lowerMean = minMean ?? lowerMean;
  upperMean = maxMean ?? upperMean;
  lowerDifference = minDifference ?? lowerDifference;
  upperDifference = maxDifference ?? upperDifference;

  if (lowerMean > upperMean) {
    final previous = lowerMean;
    lowerMean = upperMean;
    upperMean = previous;
  }
  if (lowerDifference > upperDifference) {
    final previous = lowerDifference;
    lowerDifference = upperDifference;
    upperDifference = previous;
  }

  if (lowerMean == upperMean) {
    final pad = lowerMean == 0 ? 1.0 : lowerMean.abs() * 0.2;
    lowerMean -= pad;
    upperMean += pad;
  } else {
    final pad = (upperMean - lowerMean).abs() * 0.07;
    if (minMean == null) lowerMean -= pad;
    if (maxMean == null) upperMean += pad;
  }
  if (lowerDifference == upperDifference) {
    final pad = lowerDifference == 0 ? 1.0 : lowerDifference.abs() * 0.2;
    lowerDifference -= pad;
    upperDifference += pad;
  } else {
    final pad = (upperDifference - lowerDifference).abs() * 0.09;
    if (minDifference == null) lowerDifference -= pad;
    if (maxDifference == null) upperDifference += pad;
  }

  return _BlandAltmanRange(
    lowerMean,
    upperMean,
    lowerDifference,
    upperDifference,
  );
}

List<String> _groupsFor(List<SimpleBlandAltmanPoint> points) {
  final groups = <String>[];
  for (final point in points) {
    final group = point.group;
    if (group == null || group.isEmpty || groups.contains(group)) continue;
    groups.add(group);
  }
  return groups;
}

class _BlandAltmanRange {
  final double minMean;
  final double maxMean;
  final double minDifference;
  final double maxDifference;

  const _BlandAltmanRange(
    this.minMean,
    this.maxMean,
    this.minDifference,
    this.maxDifference,
  );

  double get meanSpan => math.max(0.000001, maxMean - minMean);
  double get differenceSpan =>
      math.max(0.000001, maxDifference - minDifference);
}

class _LegendItem {
  final String label;
  final Color color;

  const _LegendItem(this.label, this.color);
}

enum _LineStyle { solid, dashed }

class _SimpleBlandAltmanVisuals {
  final List<Color> palette;
  final Color pointColor;
  final Color outlierColor;
  final Color biasLineColor;
  final Color agreementLineColor;
  final Color agreementBandColor;
  final Color zeroLineColor;
  final Color gridColor;
  final Color axisColor;

  const _SimpleBlandAltmanVisuals({
    required this.palette,
    required this.pointColor,
    required this.outlierColor,
    required this.biasLineColor,
    required this.agreementLineColor,
    required this.agreementBandColor,
    required this.zeroLineColor,
    required this.gridColor,
    required this.axisColor,
  });

  factory _SimpleBlandAltmanVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleBlandAltmanVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF22C55E),
          ],
          pointColor: colorScheme.primary,
          outlierColor: const Color(0xFFEF4444),
          biasLineColor: colorScheme.primary,
          agreementLineColor: colorScheme.onSurfaceVariant,
          agreementBandColor: colorScheme.primary.withValues(alpha: 0.08),
          zeroLineColor: colorScheme.outline.withValues(alpha: 0.55),
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleBlandAltmanVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            const Color(0xFF0F766E),
            const Color(0xFF64748B),
          ],
          pointColor: colorScheme.primary,
          outlierColor: const Color(0xFFB91C1C),
          biasLineColor: colorScheme.onSurfaceVariant,
          agreementLineColor: colorScheme.outline,
          agreementBandColor: colorScheme.outline.withValues(alpha: 0.08),
          zeroLineColor: colorScheme.outline.withValues(alpha: 0.62),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
        );
      case SimpleBarChartStyle.education:
        return _SimpleBlandAltmanVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFFF59E0B),
          ],
          pointColor: colorScheme.secondary,
          outlierColor: const Color(0xFFDC2626),
          biasLineColor: colorScheme.secondary,
          agreementLineColor: colorScheme.primary,
          agreementBandColor: colorScheme.secondary.withValues(alpha: 0.09),
          zeroLineColor: colorScheme.outline.withValues(alpha: 0.6),
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleBlandAltmanVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFEC4899),
          ],
          pointColor: colorScheme.tertiary,
          outlierColor: const Color(0xFFEC4899),
          biasLineColor: colorScheme.tertiary,
          agreementLineColor: colorScheme.onSurfaceVariant,
          agreementBandColor: colorScheme.tertiary.withValues(alpha: 0.08),
          zeroLineColor: colorScheme.outline.withValues(alpha: 0.5),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleBlandAltmanVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
          ],
          pointColor: colorScheme.primary,
          outlierColor: const Color(0xFFBE123C),
          biasLineColor: colorScheme.secondary,
          agreementLineColor: colorScheme.onSurfaceVariant,
          agreementBandColor: colorScheme.secondary.withValues(alpha: 0.08),
          zeroLineColor: colorScheme.outline.withValues(alpha: 0.55),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
        );
    }
  }
}

class _DefaultBlandAltmanTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String meanValue;
  final String differenceValue;
  final String biasValue;
  final String status;

  const _DefaultBlandAltmanTooltip({
    required this.color,
    required this.title,
    required this.meanValue,
    required this.differenceValue,
    required this.biasValue,
    required this.status,
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
            _BlandAltmanTooltipRow(label: 'Mean', value: meanValue),
            const SizedBox(height: 4),
            _BlandAltmanTooltipRow(label: 'Difference', value: differenceValue),
            const SizedBox(height: 4),
            _BlandAltmanTooltipRow(label: 'Bias', value: biasValue),
            const SizedBox(height: 4),
            _BlandAltmanTooltipRow(label: 'Status', value: status),
          ],
        ),
      ),
    );
  }
}

class _BlandAltmanTooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _BlandAltmanTooltipRow({required this.label, required this.value});

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
              color: colorScheme.onInverseSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: 8),
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
