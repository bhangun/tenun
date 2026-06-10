import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleQQPlotValueFormatter = String Function(double value);
typedef SimpleQQPlotPointTapCallback =
    void Function(
      SimpleQQPlotSeries series,
      SimpleQQPlotPoint point,
      int seriesIndex,
      int pointIndex,
    );
typedef SimpleQQPlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleQQPlotSeries series,
      SimpleQQPlotPoint point,
      int seriesIndex,
      int pointIndex,
      String formattedReference,
      String formattedSample,
      String formattedDeviation,
    );

enum SimpleQQPlotReferenceDistribution { normal, uniform }

class SimpleQQPlotSeries {
  final String name;
  final List<double> sampleValues;
  final List<double> referenceValues;
  final SimpleQQPlotReferenceDistribution referenceDistribution;
  final String? referenceName;
  final Color? color;

  const SimpleQQPlotSeries({
    required this.name,
    required this.sampleValues,
    this.referenceValues = const [],
    this.referenceDistribution = SimpleQQPlotReferenceDistribution.normal,
    this.referenceName,
    this.color,
  });
}

class SimpleQQPlotPoint {
  final double percentile;
  final double referenceQuantile;
  final double sampleQuantile;

  const SimpleQQPlotPoint({
    required this.percentile,
    required this.referenceQuantile,
    required this.sampleQuantile,
  });

  double get deviation => sampleQuantile - referenceQuantile;
}

/// A quantile-quantile plot for distribution fit, cohort comparison, model
/// residual checks, grading diagnostics, and quality-control validation.
class SimpleQQPlotChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(54, 18, 26, 42);

  final List<SimpleQQPlotSeries> series;
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
  final Color? referenceLineColor;
  final Color? fitLineColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showReferenceLine;
  final bool showFitLine;
  final bool showAxisLabels;
  final int gridLineCount;
  final double pointRadius;
  final SimpleQQPlotValueFormatter? xValueFormatter;
  final SimpleQQPlotValueFormatter? yValueFormatter;
  final SimpleQQPlotValueFormatter? deviationFormatter;
  final SimpleQQPlotPointTapCallback? onPointTap;
  final SimpleQQPlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleQQPlotChart({
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
    this.pointColor,
    this.gridColor,
    this.axisColor,
    this.referenceLineColor,
    this.fitLineColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.showReferenceLine = true,
    this.showFitLine = false,
    this.showAxisLabels = true,
    this.gridLineCount = 4,
    this.pointRadius = 5,
    this.xValueFormatter,
    this.yValueFormatter,
    this.deviationFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(pointRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleQQPlotVisuals.resolve(style, colorScheme);
    final resolvedSeries = _resolveQQSeries(series);
    final xFormatter = xValueFormatter ?? _defaultValueFormatter;
    final yFormatter = yValueFormatter ?? _defaultValueFormatter;
    final resolvedDeviationFormatter =
        deviationFormatter ?? _defaultSignedValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (resolvedSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'QQ plot, no data.',
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
        final resolvedPalette = _resolvePalette(visuals.palette);

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            resolvedSeries,
            resolvedDeviationFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleQQPlotChartView(
            width: width,
            height: chartHeight,
            series: resolvedSeries,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            padding: padding,
            xAxisLabel: xAxisLabel ?? _defaultXAxisLabel(resolvedSeries),
            yAxisLabel: yAxisLabel ?? 'Sample quantile',
            palette: resolvedPalette,
            pointColor: pointColor ?? visuals.pointColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            referenceLineColor:
                referenceLineColor ?? visuals.referenceLineColor,
            fitLineColor: fitLineColor ?? visuals.fitLineColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            showReferenceLine: showReferenceLine,
            showFitLine: showFitLine,
            showAxisLabels: showAxisLabels,
            gridLineCount: gridLineCount,
            pointRadius: pointRadius,
            xValueFormatter: xFormatter,
            yValueFormatter: yFormatter,
            deviationFormatter: resolvedDeviationFormatter,
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

  String _defaultXAxisLabel(List<_QQPlotSeriesData> resolvedSeries) {
    final first = resolvedSeries.first.series;
    if (first.referenceValues.any((value) => value.isFinite)) {
      return first.referenceName == null
          ? 'Reference quantile'
          : '${first.referenceName} quantile';
    }
    switch (first.referenceDistribution) {
      case SimpleQQPlotReferenceDistribution.normal:
        return 'Normal quantile';
      case SimpleQQPlotReferenceDistribution.uniform:
        return 'Uniform quantile';
    }
  }

  String _defaultSemanticLabel(
    List<_QQPlotSeriesData> resolvedSeries,
    SimpleQQPlotValueFormatter formatter,
  ) {
    final summaries = resolvedSeries
        .take(4)
        .map((item) {
          final deviations =
              item.points.map((point) => point.deviation).toList()..sort();
          final medianDeviation = _quantile(deviations, 0.5);
          final maxDeviation = item.points.fold<double>(
            0,
            (maxValue, point) => math.max(maxValue, point.deviation.abs()),
          );
          return '${item.series.name} ${item.points.length} quantiles, '
              'median deviation ${formatter(medianDeviation)}, '
              'max deviation ${formatter(maxDeviation)}';
        })
        .join('; ');
    final suffix = resolvedSeries.length > 4
        ? '; and ${resolvedSeries.length - 4} more series'
        : '';
    final seriesLabel = resolvedSeries.length == 1 ? 'series' : 'series';
    return 'QQ plot, ${resolvedSeries.length} $seriesLabel. '
        '$summaries$suffix.';
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

class _SimpleQQPlotChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<_QQPlotSeriesData> series;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final EdgeInsets padding;
  final String xAxisLabel;
  final String yAxisLabel;
  final List<Color> palette;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color referenceLineColor;
  final Color fitLineColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showReferenceLine;
  final bool showFitLine;
  final bool showAxisLabels;
  final int gridLineCount;
  final double pointRadius;
  final SimpleQQPlotValueFormatter xValueFormatter;
  final SimpleQQPlotValueFormatter yValueFormatter;
  final SimpleQQPlotValueFormatter deviationFormatter;
  final SimpleQQPlotPointTapCallback? onPointTap;
  final SimpleQQPlotTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleQQPlotChartView({
    required this.width,
    required this.height,
    required this.series,
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
    required this.referenceLineColor,
    required this.fitLineColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.showReferenceLine,
    required this.showFitLine,
    required this.showAxisLabels,
    required this.gridLineCount,
    required this.pointRadius,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.deviationFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleQQPlotChartView> createState() => _SimpleQQPlotChartViewState();
}

class _SimpleQQPlotChartViewState extends State<_SimpleQQPlotChartView> {
  _QQHit? _activeHit;

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
                painter: _SimpleQQPlotPainter(
                  series: widget.series,
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
                  referenceLineColor: widget.referenceLineColor,
                  fitLineColor: widget.fitLineColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showLegend: widget.showLegend,
                  showActivePoint: widget.showActivePoint,
                  showReferenceLine: widget.showReferenceLine,
                  showFitLine: widget.showFitLine,
                  showAxisLabels: widget.showAxisLabels,
                  gridLineCount: widget.gridLineCount,
                  pointRadius: widget.pointRadius,
                  xValueFormatter: widget.xValueFormatter,
                  yValueFormatter: widget.yValueFormatter,
                  deviationFormatter: widget.deviationFormatter,
                  activeHit: _activeHit,
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
                      final hit = _hitTest(details.localPosition, size);
                      _setActive(hit);
                      if (hit == null) return;
                      final series = widget.series[hit.seriesIndex];
                      final point = series.points[hit.pointIndex];
                      widget.onPointTap?.call(
                        series.series,
                        point,
                        hit.seriesIndex,
                        hit.pointIndex,
                      );
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeHit != null)
                _buildTooltip(context, size, _activeHit!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_QQHit? hit) {
    if (_activeHit?.seriesIndex == hit?.seriesIndex &&
        _activeHit?.pointIndex == hit?.pointIndex) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _QQHit? _hitTest(Offset position, Size size) {
    final plot = _plot(size);
    if (!plot.inflate(14).contains(position)) return null;
    final range = _resolveRange();
    var bestHit = const _QQHit(-1, -1);
    var bestDistance = double.infinity;
    for (
      var seriesIndex = 0;
      seriesIndex < widget.series.length;
      seriesIndex++
    ) {
      final item = widget.series[seriesIndex];
      for (var pointIndex = 0; pointIndex < item.points.length; pointIndex++) {
        final point = item.points[pointIndex];
        final center = Offset(
          _xForValue(point.referenceQuantile, plot, range),
          _yForValue(point.sampleQuantile, plot, range),
        );
        final distance = (position - center).distance;
        if (distance <= widget.pointRadius + 10 && distance < bestDistance) {
          bestHit = _QQHit(seriesIndex, pointIndex);
          bestDistance = distance;
        }
      }
    }
    return bestHit.seriesIndex >= 0 ? bestHit : null;
  }

  Widget _buildTooltip(BuildContext context, Size size, _QQHit hit) {
    final item = widget.series[hit.seriesIndex];
    final point = item.points[hit.pointIndex];
    final anchor = _anchorFor(hit, size);
    const tooltipWidth = 194.0;
    const tooltipHeight = 108.0;
    final left = (anchor.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (anchor.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();
    final formattedReference = widget.xValueFormatter(point.referenceQuantile);
    final formattedSample = widget.yValueFormatter(point.sampleQuantile);
    final formattedDeviation = widget.deviationFormatter(point.deviation);

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            item.series,
            point,
            hit.seriesIndex,
            hit.pointIndex,
            formattedReference,
            formattedSample,
            formattedDeviation,
          ) ??
          _DefaultQQPlotTooltip(
            color: _seriesColor(item, hit.seriesIndex),
            title: '${item.series.name} p${(point.percentile * 100).round()}',
            referenceLabel: widget.xAxisLabel,
            sampleLabel: widget.yAxisLabel,
            referenceValue: formattedReference,
            sampleValue: formattedSample,
            deviationValue: formattedDeviation,
          ),
    );
  }

  Offset _anchorFor(_QQHit hit, Size size) {
    final plot = _plot(size);
    final range = _resolveRange();
    final point = widget.series[hit.seriesIndex].points[hit.pointIndex];
    return Offset(
      _xForValue(point.referenceQuantile, plot, range),
      _yForValue(point.sampleQuantile, plot, range),
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

  _QQRange _resolveRange() {
    return _resolveQQRange(
      series: widget.series,
      minX: widget.minX,
      maxX: widget.maxX,
      minY: widget.minY,
      maxY: widget.maxY,
    );
  }

  double _xForValue(double value, Rect plot, _QQRange range) {
    final normalized = (value - range.minX) / range.xSpan;
    return plot.left + normalized * plot.width;
  }

  double _yForValue(double value, Rect plot, _QQRange range) {
    final normalized = (value - range.minY) / range.ySpan;
    return plot.bottom - normalized * plot.height;
  }

  Color _seriesColor(_QQPlotSeriesData item, int index) {
    return item.series.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleQQPlotPainter extends CustomPainter {
  final List<_QQPlotSeriesData> series;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final EdgeInsets padding;
  final String xAxisLabel;
  final String yAxisLabel;
  final List<Color> palette;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color referenceLineColor;
  final Color fitLineColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showActivePoint;
  final bool showReferenceLine;
  final bool showFitLine;
  final bool showAxisLabels;
  final int gridLineCount;
  final double pointRadius;
  final SimpleQQPlotValueFormatter xValueFormatter;
  final SimpleQQPlotValueFormatter yValueFormatter;
  final SimpleQQPlotValueFormatter deviationFormatter;
  final _QQHit? activeHit;
  final double progress;

  const _SimpleQQPlotPainter({
    required this.series,
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
    required this.referenceLineColor,
    required this.fitLineColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showActivePoint,
    required this.showReferenceLine,
    required this.showFitLine,
    required this.showAxisLabels,
    required this.gridLineCount,
    required this.pointRadius,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.deviationFormatter,
    required this.activeHit,
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
    if (plot.width <= 0 || plot.height <= 0 || series.isEmpty) return;

    final range = _resolveRange();
    if (showGrid) _drawGrid(canvas, plot, range);
    _drawAxes(canvas, plot);
    if (showReferenceLine) _drawReferenceLine(canvas, plot, range);
    if (showFitLine) _drawFitLines(canvas, plot, range);
    _drawPoints(canvas, plot, range);
    if (showAxisLabels) _drawAxisLabels(canvas, plot);
    if (showLegend) _drawLegend(canvas, plot);
  }

  _QQRange _resolveRange() {
    return _resolveQQRange(
      series: series,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
  }

  double _xForValue(double value, Rect plot, _QQRange range) {
    final normalized = (value - range.minX) / range.xSpan;
    return plot.left + normalized * plot.width;
  }

  double _yForValue(double value, Rect plot, _QQRange range) {
    final normalized = (value - range.minY) / range.ySpan;
    return plot.bottom - normalized * plot.height;
  }

  void _drawGrid(Canvas canvas, Rect plot, _QQRange range) {
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

  void _drawReferenceLine(Canvas canvas, Rect plot, _QQRange range) {
    final start = math.max(range.minX, range.minY);
    final end = math.min(range.maxX, range.maxY);
    if (start >= end) return;
    _drawStyledLine(
      canvas,
      Offset(_xForValue(start, plot, range), _yForValue(start, plot, range)),
      Offset(_xForValue(end, plot, range), _yForValue(end, plot, range)),
      Paint()
        ..color = referenceLineColor.withValues(alpha: 0.72)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
      _LineStyle.dashed,
    );
  }

  void _drawFitLines(Canvas canvas, Rect plot, _QQRange range) {
    for (var index = 0; index < series.length; index++) {
      final regression = _linearRegression(series[index].points);
      if (regression == null) continue;
      final startX = range.minX;
      final endX = range.maxX;
      final startY = regression.slope * startX + regression.intercept;
      final endY = regression.slope * endX + regression.intercept;
      _drawStyledLine(
        canvas,
        Offset(
          _xForValue(startX, plot, range),
          _yForValue(startY, plot, range),
        ),
        Offset(_xForValue(endX, plot, range), _yForValue(endY, plot, range)),
        Paint()
          ..color = _seriesColor(
            series[index],
            index,
            fitLineColor,
          ).withValues(alpha: 0.5)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
        _LineStyle.solid,
      );
    }
  }

  void _drawPoints(Canvas canvas, Rect plot, _QQRange range) {
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final item = series[seriesIndex];
      final color = _seriesColor(item, seriesIndex, pointColor);
      for (var pointIndex = 0; pointIndex < item.points.length; pointIndex++) {
        final point = item.points[pointIndex];
        final center = Offset(
          _xForValue(point.referenceQuantile, plot, range),
          _yForValue(point.sampleQuantile, plot, range),
        );
        final radius = pointRadius * progress;
        final active =
            activeHit?.seriesIndex == seriesIndex &&
            activeHit?.pointIndex == pointIndex;

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
          Paint()..color = color.withValues(alpha: 0.13),
        );
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = color.withValues(alpha: active ? 0.98 : 0.84),
        );

        if (showValues && _totalPointCount <= 18) {
          _drawPointLabel(canvas, point, center, plot, color, radius);
        }
      }
    }
  }

  void _drawPointLabel(
    Canvas canvas,
    SimpleQQPlotPoint point,
    Offset center,
    Rect plot,
    Color color,
    double radius,
  ) {
    final painter = _textPainter(
      '${(point.percentile * 100).round()}%',
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.9,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: 54,
    )..layout(maxWidth: 54);
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
    if (series.length <= 1) return;
    final rowHeight = 20.0;
    final legendWidth = math.min(128.0, plot.width * 0.36);
    final left = plot.right - legendWidth - 6;
    var top = plot.top + 6;
    for (var index = 0; index < series.length; index++) {
      if (top + rowHeight > plot.bottom) break;
      final color = _seriesColor(series[index], index, pointColor);
      canvas.drawCircle(Offset(left + 5, top + 9), 4, Paint()..color = color);
      final painter = _textPainter(
        series[index].series.name,
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

  int get _totalPointCount {
    return series.fold(0, (sum, item) => sum + item.points.length);
  }

  Color _seriesColor(_QQPlotSeriesData item, int index, Color fallback) {
    return item.series.color ??
        (series.length == 1 ? fallback : palette[index % palette.length]);
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
  bool shouldRepaint(covariant _SimpleQQPlotPainter oldDelegate) {
    return oldDelegate.series != series ||
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
        oldDelegate.referenceLineColor != referenceLineColor ||
        oldDelegate.fitLineColor != fitLineColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.showReferenceLine != showReferenceLine ||
        oldDelegate.showFitLine != showFitLine ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.xValueFormatter != xValueFormatter ||
        oldDelegate.yValueFormatter != yValueFormatter ||
        oldDelegate.deviationFormatter != deviationFormatter ||
        oldDelegate.activeHit != activeHit ||
        oldDelegate.progress != progress;
  }
}

List<_QQPlotSeriesData> _resolveQQSeries(List<SimpleQQPlotSeries> series) {
  final result = <_QQPlotSeriesData>[];
  for (final item in series) {
    final sample = item.sampleValues.where((value) => value.isFinite).toList()
      ..sort();
    if (item.name.trim().isEmpty || sample.length < 2) continue;
    final reference =
        item.referenceValues.where((value) => value.isFinite).toList()..sort();
    if (reference.isNotEmpty && reference.length < 2) continue;
    final count = reference.isEmpty
        ? sample.length
        : math.min(sample.length, reference.length);
    if (count < 2) continue;
    final points = <SimpleQQPlotPoint>[];
    final mean = _mean(sample);
    final deviation = _standardDeviation(sample, mean);
    for (var index = 0; index < count; index++) {
      final percentile = (index + 0.5) / count;
      final sampleQuantile = _quantile(sample, percentile);
      final referenceQuantile = reference.isNotEmpty
          ? _quantile(reference, percentile)
          : _theoreticalQuantile(
              item.referenceDistribution,
              percentile,
              sample.first,
              sample.last,
              mean,
              deviation,
            );
      if (!referenceQuantile.isFinite || !sampleQuantile.isFinite) continue;
      points.add(
        SimpleQQPlotPoint(
          percentile: percentile,
          referenceQuantile: referenceQuantile,
          sampleQuantile: sampleQuantile,
        ),
      );
    }
    if (points.length >= 2) {
      result.add(_QQPlotSeriesData(series: item, points: points));
    }
  }
  return result;
}

double _theoreticalQuantile(
  SimpleQQPlotReferenceDistribution distribution,
  double percentile,
  double min,
  double max,
  double mean,
  double standardDeviation,
) {
  switch (distribution) {
    case SimpleQQPlotReferenceDistribution.normal:
      final spread = standardDeviation <= 0
          ? math.max(1.0, (max - min) / 6)
          : standardDeviation;
      return mean + spread * _inverseStandardNormal(percentile);
    case SimpleQQPlotReferenceDistribution.uniform:
      return min + (max - min) * percentile;
  }
}

_QQRange _resolveQQRange({
  required List<_QQPlotSeriesData> series,
  required double? minX,
  required double? maxX,
  required double? minY,
  required double? maxY,
}) {
  var lowerX = double.infinity;
  var upperX = double.negativeInfinity;
  var lowerY = double.infinity;
  var upperY = double.negativeInfinity;

  for (final item in series) {
    for (final point in item.points) {
      lowerX = math.min(lowerX, point.referenceQuantile);
      upperX = math.max(upperX, point.referenceQuantile);
      lowerY = math.min(lowerY, point.sampleQuantile);
      upperY = math.max(upperY, point.sampleQuantile);
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
    final pad = (upperX - lowerX).abs() * 0.07;
    if (minX == null) lowerX -= pad;
    if (maxX == null) upperX += pad;
  }
  if (lowerY == upperY) {
    final pad = lowerY == 0 ? 1.0 : lowerY.abs() * 0.2;
    lowerY -= pad;
    upperY += pad;
  } else {
    final pad = (upperY - lowerY).abs() * 0.07;
    if (minY == null) lowerY -= pad;
    if (maxY == null) upperY += pad;
  }

  return _QQRange(lowerX, upperX, lowerY, upperY);
}

double _quantile(List<double> sorted, double percentile) {
  if (sorted.isEmpty) return 0;
  if (sorted.length == 1) return sorted.first;
  final position = (sorted.length - 1) * percentile.clamp(0.0, 1.0);
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sorted[lower];
  final weight = position - lower;
  return sorted[lower] * (1 - weight) + sorted[upper] * weight;
}

double _mean(List<double> values) {
  return values.fold(0.0, (sum, value) => sum + value) / values.length;
}

double _standardDeviation(List<double> values, double mean) {
  if (values.length < 2) return 0;
  final variance =
      values.fold(
        0.0,
        (sum, value) => sum + math.pow(value - mean, 2).toDouble(),
      ) /
      (values.length - 1);
  return math.sqrt(math.max(0.0, variance));
}

double _inverseStandardNormal(double probability) {
  final p = probability.clamp(0.000001, 0.999999).toDouble();
  const a = [
    -39.69683028665376,
    220.9460984245205,
    -275.9285104469687,
    138.357751867269,
    -30.66479806614716,
    2.506628277459239,
  ];
  const b = [
    -54.47609879822406,
    161.5858368580409,
    -155.6989798598866,
    66.80131188771972,
    -13.28068155288572,
  ];
  const c = [
    -0.007784894002430293,
    -0.3223964580411365,
    -2.400758277161838,
    -2.549732539343734,
    4.374664141464968,
    2.938163982698783,
  ];
  const d = [
    0.007784695709041462,
    0.3224671290700398,
    2.445134137142996,
    3.754408661907416,
  ];
  const low = 0.02425;
  const high = 1 - low;

  if (p < low) {
    final q = math.sqrt(-2 * math.log(p));
    return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
            c[5]) /
        ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  if (p > high) {
    final q = math.sqrt(-2 * math.log(1 - p));
    return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q +
            c[5]) /
        ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
  }
  final q = p - 0.5;
  final r = q * q;
  return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) *
      q /
      (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
}

_Regression? _linearRegression(List<SimpleQQPlotPoint> points) {
  if (points.length < 2) return null;
  final meanX =
      points.fold(0.0, (sum, point) => sum + point.referenceQuantile) /
      points.length;
  final meanY =
      points.fold(0.0, (sum, point) => sum + point.sampleQuantile) /
      points.length;
  var numerator = 0.0;
  var denominator = 0.0;
  for (final point in points) {
    numerator +=
        (point.referenceQuantile - meanX) * (point.sampleQuantile - meanY);
    denominator += math.pow(point.referenceQuantile - meanX, 2).toDouble();
  }
  if (denominator == 0) return null;
  final slope = numerator / denominator;
  return _Regression(slope, meanY - slope * meanX);
}

class _QQPlotSeriesData {
  final SimpleQQPlotSeries series;
  final List<SimpleQQPlotPoint> points;

  const _QQPlotSeriesData({required this.series, required this.points});
}

class _QQHit {
  final int seriesIndex;
  final int pointIndex;

  const _QQHit(this.seriesIndex, this.pointIndex);
}

class _QQRange {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _QQRange(this.minX, this.maxX, this.minY, this.maxY);

  double get xSpan => math.max(0.000001, maxX - minX);
  double get ySpan => math.max(0.000001, maxY - minY);
}

class _Regression {
  final double slope;
  final double intercept;

  const _Regression(this.slope, this.intercept);
}

enum _LineStyle { solid, dashed }

class _SimpleQQPlotVisuals {
  final List<Color> palette;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color referenceLineColor;
  final Color fitLineColor;

  const _SimpleQQPlotVisuals({
    required this.palette,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.referenceLineColor,
    required this.fitLineColor,
  });

  factory _SimpleQQPlotVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleQQPlotVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF22C55E),
          ],
          pointColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          referenceLineColor: colorScheme.onSurfaceVariant,
          fitLineColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleQQPlotVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            const Color(0xFF0F766E),
            const Color(0xFF64748B),
          ],
          pointColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          referenceLineColor: colorScheme.onSurfaceVariant,
          fitLineColor: colorScheme.onSurfaceVariant,
        );
      case SimpleBarChartStyle.education:
        return _SimpleQQPlotVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFFF59E0B),
          ],
          pointColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          referenceLineColor: colorScheme.primary,
          fitLineColor: colorScheme.secondary,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleQQPlotVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFEC4899),
          ],
          pointColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          referenceLineColor: colorScheme.onSurfaceVariant,
          fitLineColor: colorScheme.tertiary,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleQQPlotVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
          ],
          pointColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          referenceLineColor: colorScheme.onSurfaceVariant,
          fitLineColor: colorScheme.secondary,
        );
    }
  }
}

class _DefaultQQPlotTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String referenceLabel;
  final String sampleLabel;
  final String referenceValue;
  final String sampleValue;
  final String deviationValue;

  const _DefaultQQPlotTooltip({
    required this.color,
    required this.title,
    required this.referenceLabel,
    required this.sampleLabel,
    required this.referenceValue,
    required this.sampleValue,
    required this.deviationValue,
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
            _QQPlotTooltipRow(label: referenceLabel, value: referenceValue),
            const SizedBox(height: 4),
            _QQPlotTooltipRow(label: sampleLabel, value: sampleValue),
            const SizedBox(height: 4),
            _QQPlotTooltipRow(label: 'Deviation', value: deviationValue),
          ],
        ),
      ),
    );
  }
}

class _QQPlotTooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _QQPlotTooltipRow({required this.label, required this.value});

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
