import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import '../line/simple_line_chart.dart';

typedef SimpleEcdfValueFormatter = String Function(double value);
typedef SimpleEcdfTapCallback =
    void Function(
      SimpleEcdfSeries series,
      double value,
      double percentile,
      int valueIndex,
      int seriesIndex,
    );
typedef SimpleEcdfTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleEcdfSeries series,
      double value,
      double percentile,
      SimpleEcdfStats stats,
      int valueIndex,
      int seriesIndex,
      String formattedValue,
      String formattedPercentile,
    );

class SimpleEcdfSeries {
  final String name;
  final List<double> values;
  final Color? color;

  const SimpleEcdfSeries({
    required this.name,
    required this.values,
    this.color,
  });
}

class SimpleEcdfStats {
  final int count;
  final double min;
  final double median;
  final double p90;
  final double max;

  const SimpleEcdfStats({
    required this.count,
    required this.min,
    required this.median,
    required this.p90,
    required this.max,
  });
}

/// A compact empirical cumulative distribution function chart for thresholds,
/// samples, latency, scores, measurements, and model error distributions.
class SimpleEcdfChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(56, 18, 18, 42);

  final List<SimpleEcdfSeries> series;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? lineColor;
  final Color? fillColor;
  final Color? medianColor;
  final Color? p90Color;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showMedianLine;
  final bool showP90Line;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? strokeWidth;
  final double? dotRadius;
  final double? fillOpacity;
  final SimpleEcdfValueFormatter? valueFormatter;
  final SimpleEcdfValueFormatter? percentileFormatter;
  final SimpleEcdfTapCallback? onPointTap;
  final SimpleEcdfTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleEcdfChart({
    super.key,
    required this.series,
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.lineColor,
    this.fillColor,
    this.medianColor,
    this.p90Color,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showDots = true,
    this.showValues = false,
    this.showArea = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.showMedianLine = true,
    this.showP90Line = false,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.strokeWidth,
    this.dotRadius,
    this.fillOpacity,
    this.valueFormatter,
    this.percentileFormatter,
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
       assert(dotRadius == null || dotRadius >= 0),
       assert(fillOpacity == null || (fillOpacity >= 0 && fillOpacity <= 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleEcdfVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .where(
          (item) =>
              item.name.trim().isNotEmpty &&
              item.values.any((value) => value.isFinite),
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final percentFormatter = percentileFormatter ?? _defaultPercentileFormatter;

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
            emptySemanticLabel: 'ECDF chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final stats = visibleSeries.map(_statsFor).toList();
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
            visibleSeries,
            stats,
            formatter,
            percentFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleEcdfChartView(
            width: width,
            height: chartHeight,
            series: visibleSeries,
            stats: stats,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(visuals.palette),
            lineColor: lineColor,
            fillColor: fillColor,
            medianColor: medianColor ?? visuals.medianColor,
            p90Color: p90Color ?? visuals.p90Color,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeZero: includeZero,
            showGrid: showGrid,
            showDots: showDots,
            showValues: showValues,
            showArea: showArea,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            showMedianLine: showMedianLine,
            showP90Line: showP90Line,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            dotRadius: dotRadius ?? visuals.dotRadius,
            fillOpacity: fillOpacity ?? visuals.fillOpacity,
            valueFormatter: formatter,
            percentileFormatter: percentFormatter,
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

  String _defaultSemanticLabel(
    List<SimpleEcdfSeries> visibleSeries,
    List<SimpleEcdfStats> stats,
    SimpleEcdfValueFormatter formatter,
    SimpleEcdfValueFormatter percentFormatter,
  ) {
    final summaries = <String>[];
    final limit = math.min(visibleSeries.length, 3);
    for (var index = 0; index < limit; index++) {
      final item = visibleSeries[index];
      final summary = stats[index];
      summaries.add(
        '${item.name} ${summary.count} samples, median '
        '${formatter(summary.median)}, p90 ${formatter(summary.p90)}',
      );
    }
    final suffix = visibleSeries.length > limit
        ? '; and ${visibleSeries.length - limit} more series'
        : '';
    final seriesLabel = visibleSeries.length == 1 ? 'series' : 'series';
    return 'ECDF chart, ${visibleSeries.length} $seriesLabel. '
        '${summaries.join('; ')}$suffix. '
        'Y axis reaches ${percentFormatter(1)}.';
  }

  static SimpleEcdfStats _statsFor(SimpleEcdfSeries series) {
    final values = series.values.where((value) => value.isFinite).toList()
      ..sort();
    return SimpleEcdfStats(
      count: values.length,
      min: values.first,
      median: _quantile(values, 0.5),
      p90: _quantile(values, 0.9),
      max: values.last,
    );
  }

  static double _quantile(List<double> sorted, double percentile) {
    if (sorted.length == 1) return sorted.first;
    final position = (sorted.length - 1) * percentile;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final weight = position - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentileFormatter(double value) {
    return '${(value * 100).round()}%';
  }
}

class _SimpleEcdfChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleEcdfSeries> series;
  final List<SimpleEcdfStats> stats;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? lineColor;
  final Color? fillColor;
  final Color medianColor;
  final Color p90Color;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showMedianLine;
  final bool showP90Line;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;
  final SimpleEcdfValueFormatter valueFormatter;
  final SimpleEcdfValueFormatter percentileFormatter;
  final SimpleEcdfTapCallback? onPointTap;
  final SimpleEcdfTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleEcdfChartView({
    required this.width,
    required this.height,
    required this.series,
    required this.stats,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.lineColor,
    required this.fillColor,
    required this.medianColor,
    required this.p90Color,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showDots,
    required this.showValues,
    required this.showArea,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.showMedianLine,
    required this.showP90Line,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
    required this.valueFormatter,
    required this.percentileFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleEcdfChartView> createState() => _SimpleEcdfChartViewState();
}

class _SimpleEcdfChartViewState extends State<_SimpleEcdfChartView> {
  _EcdfSelection? _active;

  @override
  Widget build(BuildContext context) {
    final hasLegend = widget.showLegend && widget.series.length > 1;
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActivePoint ||
        widget.onPointTap != null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final chart = TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: widget.animationDuration,
                  curve: widget.animationCurve,
                  builder: (context, progress, child) {
                    return CustomPaint(
                      painter: _SimpleEcdfPainter(
                        series: widget.series,
                        stats: widget.stats,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        lineColor: widget.lineColor,
                        fillColor: widget.fillColor,
                        medianColor: widget.medianColor,
                        p90Color: widget.p90Color,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        includeZero: widget.includeZero,
                        showGrid: widget.showGrid,
                        showDots: widget.showDots,
                        showValues: widget.showValues,
                        showArea: widget.showArea,
                        showActivePoint: widget.showActivePoint,
                        showMedianLine: widget.showMedianLine,
                        showP90Line: widget.showP90Line,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        gridLineCount: widget.gridLineCount,
                        strokeWidth: widget.strokeWidth,
                        dotRadius: widget.dotRadius,
                        fillOpacity: widget.fillOpacity,
                        activeSelection: _active,
                        valueFormatter: widget.valueFormatter,
                        percentileFormatter: widget.percentileFormatter,
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
                            final selection = _hitTest(
                              details.localPosition,
                              size,
                            );
                            _setActive(selection);
                            if (selection == null) return;
                            final point = selection.point;
                            widget.onPointTap?.call(
                              widget.series[point.seriesIndex],
                              point.value,
                              point.percentile,
                              point.valueIndex,
                              point.seriesIndex,
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
          ),
          if (hasLegend) _buildLegend(),
        ],
      ),
    );
  }

  void _setActive(_EcdfSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _EcdfSelection? _hitTest(Offset position, Size size) {
    final geometry = _EcdfGeometry.resolve(
      size: size,
      series: widget.series,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      includeZero: widget.includeZero,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
    for (final point in geometry.points) {
      if ((position - point.center).distance <= widget.dotRadius + 8) {
        return _EcdfSelection(point);
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _EcdfSelection selection,
  ) {
    final point = selection.point;
    final series = widget.series[point.seriesIndex];
    final stats = widget.stats[point.seriesIndex];
    final formattedValue = widget.valueFormatter(point.value);
    final formattedPercentile = widget.percentileFormatter(point.percentile);
    const tooltipWidth = 190.0;
    const tooltipHeight = 88.0;
    final left = (point.center.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (point.center.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            series,
            point.value,
            point.percentile,
            stats,
            point.valueIndex,
            point.seriesIndex,
            formattedValue,
            formattedPercentile,
          ) ??
          _DefaultEcdfTooltip(
            color: _seriesColor(series, point.seriesIndex),
            title: series.name,
            value: formattedValue,
            percentile: formattedPercentile,
            count: stats.count,
          ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          for (var index = 0; index < widget.series.length; index++)
            _EcdfLegendItem(
              label: widget.series[index].name,
              color: _seriesColor(widget.series[index], index),
              textStyle: widget.labelStyle,
            ),
        ],
      ),
    );
  }

  Color _seriesColor(SimpleEcdfSeries series, int index) {
    return series.color ??
        widget.lineColor ??
        widget.palette[index % widget.palette.length];
  }
}

class _SimpleEcdfPainter extends CustomPainter {
  final List<SimpleEcdfSeries> series;
  final List<SimpleEcdfStats> stats;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? lineColor;
  final Color? fillColor;
  final Color medianColor;
  final Color p90Color;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final bool showActivePoint;
  final bool showMedianLine;
  final bool showP90Line;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;
  final _EcdfSelection? activeSelection;
  final SimpleEcdfValueFormatter valueFormatter;
  final SimpleEcdfValueFormatter percentileFormatter;
  final double progress;

  const _SimpleEcdfPainter({
    required this.series,
    required this.stats,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.lineColor,
    required this.fillColor,
    required this.medianColor,
    required this.p90Color,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showDots,
    required this.showValues,
    required this.showArea,
    required this.showActivePoint,
    required this.showMedianLine,
    required this.showP90Line,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
    required this.activeSelection,
    required this.valueFormatter,
    required this.percentileFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _EcdfGeometry.resolve(
      size: size,
      series: series,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    if (geometry.plot.isEmpty || geometry.points.isEmpty) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    _drawCurves(canvas, geometry);
    _drawPercentileMarkers(canvas, geometry);
  }

  void _drawReferenceBands(Canvas canvas, _EcdfGeometry geometry) {
    final paint = Paint();
    for (final band in referenceBands) {
      final start = geometry.xForValue(band.from);
      final end = geometry.xForValue(band.to);
      paint.color = (band.color ?? palette.first).withValues(
        alpha: band.opacity,
      );
      final rect = Rect.fromLTRB(
        math.min(start, end),
        geometry.plot.top,
        math.max(start, end),
        geometry.plot.bottom,
      );
      canvas.drawRect(rect, paint);
      if (band.showLabel && band.label != null) {
        _paintText(
          canvas,
          band.label!,
          labelStyle.copyWith(color: paint.color.withValues(alpha: 0.9)),
          Offset(rect.center.dx, geometry.plot.top + 6),
          TextAlign.center,
          math.max(36.0, rect.width - 4),
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, _EcdfGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index <= gridLineCount; index++) {
      final percent = index / gridLineCount;
      final y = geometry.yForPercent(percent);
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
      _paintText(
        canvas,
        percentileFormatter(percent),
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

    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          geometry.range.min + geometry.range.span * (index / gridLineCount);
      final x = geometry.xForValue(value);
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint..color = gridColor.withValues(alpha: 0.62),
      );
      _paintText(
        canvas,
        valueFormatter(value),
        labelStyle.copyWith(
          color: labelStyle.color?.withValues(alpha: 0.72),
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
        ),
        Offset(x, geometry.plot.bottom + 6),
        TextAlign.center,
        58,
      );
    }
  }

  void _drawAxis(Canvas canvas, _EcdfGeometry geometry) {
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

  void _drawReferenceLines(Canvas canvas, _EcdfGeometry geometry) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final x = geometry.xForValue(line.value);
      final paint = Paint()
        ..color = line.color ?? axisColor
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke;
      _drawStyledLine(
        canvas,
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
        line.lineStyle,
      );
      if (line.showLabel && line.label != null) {
        _paintText(
          canvas,
          line.label!,
          labelStyle.copyWith(color: paint.color),
          Offset(x + 4, geometry.plot.top + 4),
          TextAlign.left,
          72,
        );
      }
    }
  }

  void _drawCurves(Canvas canvas, _EcdfGeometry geometry) {
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final points = geometry.points
          .where((point) => point.seriesIndex == seriesIndex)
          .toList();
      if (points.isEmpty) continue;
      final color = _seriesColor(series[seriesIndex], seriesIndex);
      final linePath = _stepPath(geometry, points, closeArea: false);
      final areaPath = _stepPath(geometry, points, closeArea: true);

      if (showArea) {
        canvas.drawPath(
          areaPath,
          Paint()
            ..color = (fillColor ?? color).withValues(alpha: fillOpacity)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      if (showDots) {
        _drawDots(canvas, geometry, points, color);
      }

      if (showValues) {
        _drawSeriesValue(canvas, geometry, points.last, color);
      }
    }
  }

  Path _stepPath(
    _EcdfGeometry geometry,
    List<_EcdfPointLayout> points, {
    required bool closeArea,
  }) {
    final baselineY = geometry.yForPercent(0);
    final startX = geometry.xForValue(geometry.range.min);
    final path = Path()..moveTo(startX, baselineY);
    var currentY = baselineY;
    final easedProgress = progress.clamp(0.0, 1.0).toDouble();
    for (final point in points) {
      final animatedY =
          baselineY + (point.center.dy - baselineY) * easedProgress;
      path
        ..lineTo(point.center.dx, currentY)
        ..lineTo(point.center.dx, animatedY);
      currentY = animatedY;
    }
    if (closeArea) {
      path
        ..lineTo(points.last.center.dx, baselineY)
        ..close();
    }
    return path;
  }

  void _drawDots(
    Canvas canvas,
    _EcdfGeometry geometry,
    List<_EcdfPointLayout> points,
    Color color,
  ) {
    final radius = dotRadius * (0.45 + progress * 0.55);
    for (final point in points) {
      final selected =
          activeSelection?.point.seriesIndex == point.seriesIndex &&
          activeSelection?.point.valueIndex == point.valueIndex;
      final center = Offset(
        point.center.dx,
        geometry.plot.bottom +
            (point.center.dy - geometry.plot.bottom) * progress,
      );
      canvas.drawCircle(
        center,
        radius + 1.2,
        Paint()..color = Colors.white.withValues(alpha: 0.86),
      );
      canvas.drawCircle(center, radius, Paint()..color = color);

      if (showActivePoint && selected) {
        canvas.drawCircle(
          center,
          radius + 5,
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
    }
  }

  void _drawSeriesValue(
    Canvas canvas,
    _EcdfGeometry geometry,
    _EcdfPointLayout point,
    Color color,
  ) {
    _paintText(
      canvas,
      percentileFormatter(point.percentile),
      valueStyle.copyWith(color: color),
      Offset(point.center.dx + 6, point.center.dy - 16),
      TextAlign.left,
      58,
    );
  }

  void _drawPercentileMarkers(Canvas canvas, _EcdfGeometry geometry) {
    if (!showMedianLine && !showP90Line) return;
    for (var index = 0; index < stats.length; index++) {
      final color = _seriesColor(series[index], index);
      if (showMedianLine) {
        _drawPercentileMarker(
          canvas,
          geometry,
          stats[index].median,
          0.5,
          medianColor.withValues(alpha: 0.9),
          color,
        );
      }
      if (showP90Line) {
        _drawPercentileMarker(
          canvas,
          geometry,
          stats[index].p90,
          0.9,
          p90Color.withValues(alpha: 0.9),
          color,
        );
      }
    }
  }

  void _drawPercentileMarker(
    Canvas canvas,
    _EcdfGeometry geometry,
    double value,
    double percentile,
    Color markerColor,
    Color seriesColor,
  ) {
    final x = geometry.xForValue(value);
    final y = geometry.yForPercent(percentile);
    final paint = Paint()
      ..color = markerColor
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    _drawStyledLine(
      canvas,
      Offset(x, y),
      Offset(x, geometry.plot.bottom),
      paint,
      SimpleChartReferenceLineStyle.dotted,
    );
    canvas.drawCircle(
      Offset(x, y),
      dotRadius + 1.5,
      Paint()..color = seriesColor.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      Offset(x, y),
      math.max(3, dotRadius - 0.5),
      Paint()..color = markerColor,
    );
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

  Color _seriesColor(SimpleEcdfSeries item, int index) {
    return item.color ?? lineColor ?? palette[index % palette.length];
  }

  @override
  bool shouldRepaint(covariant _SimpleEcdfPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.stats != stats ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.medianColor != medianColor ||
        oldDelegate.p90Color != p90Color ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeZero != includeZero ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showDots != showDots ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showArea != showArea ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.showMedianLine != showMedianLine ||
        oldDelegate.showP90Line != showP90Line ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.percentileFormatter != percentileFormatter ||
        oldDelegate.progress != progress;
  }
}

class _EcdfGeometry {
  final Rect plot;
  final _EcdfValueRange range;
  final List<_EcdfPointLayout> points;

  const _EcdfGeometry({
    required this.plot,
    required this.range,
    required this.points,
  });

  factory _EcdfGeometry.resolve({
    required Size size,
    required List<SimpleEcdfSeries> series,
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
    if (plot.width <= 0 || plot.height <= 0 || series.isEmpty) {
      return _EcdfGeometry(
        plot: plot,
        range: const _EcdfValueRange(0, 1),
        points: const [],
      );
    }

    final range = _EcdfValueRange.resolve(
      series: series,
      minValue: minValue,
      maxValue: maxValue,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    final points = <_EcdfPointLayout>[];

    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final values =
          series[seriesIndex].values.where((value) => value.isFinite).toList()
            ..sort();
      final total = values.length;
      for (var valueIndex = 0; valueIndex < total; valueIndex++) {
        final value = values[valueIndex];
        final percentile = (valueIndex + 1) / total;
        points.add(
          _EcdfPointLayout(
            seriesIndex: seriesIndex,
            valueIndex: valueIndex,
            value: value,
            percentile: percentile,
            center: Offset(
              _xForValue(value, plot, range),
              _yForPercent(percentile, plot),
            ),
          ),
        );
      }
    }

    return _EcdfGeometry(plot: plot, range: range, points: points);
  }

  double xForValue(double value) => _xForValue(value, plot, range);

  double yForPercent(double percent) => _yForPercent(percent, plot);

  static double _xForValue(double value, Rect plot, _EcdfValueRange range) {
    final normalized = ((value - range.min) / range.span).clamp(0.0, 1.0);
    return plot.left + normalized * plot.width;
  }

  static double _yForPercent(double percent, Rect plot) {
    final normalized = percent.clamp(0.0, 1.0);
    return plot.bottom - normalized * plot.height;
  }
}

class _EcdfPointLayout {
  final int seriesIndex;
  final int valueIndex;
  final double value;
  final double percentile;
  final Offset center;

  const _EcdfPointLayout({
    required this.seriesIndex,
    required this.valueIndex,
    required this.value,
    required this.percentile,
    required this.center,
  });
}

class _EcdfSelection {
  final _EcdfPointLayout point;

  const _EcdfSelection(this.point);

  @override
  bool operator ==(Object other) {
    return other is _EcdfSelection &&
        other.point.seriesIndex == point.seriesIndex &&
        other.point.valueIndex == point.valueIndex;
  }

  @override
  int get hashCode => Object.hash(point.seriesIndex, point.valueIndex);
}

class _EcdfValueRange {
  final double min;
  final double max;

  const _EcdfValueRange(this.min, this.max);

  double get span => max - min;

  factory _EcdfValueRange.resolve({
    required List<SimpleEcdfSeries> series,
    required double? minValue,
    required double? maxValue,
    required bool includeZero,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    var lower = double.infinity;
    var upper = double.negativeInfinity;
    for (final item in series) {
      for (final value in item.values) {
        if (!value.isFinite) continue;
        lower = math.min(lower, value);
        upper = math.max(upper, value);
      }
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
    if (!lower.isFinite || !upper.isFinite) {
      lower = 0;
      upper = 1;
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
    return _EcdfValueRange(lower, upper);
  }
}

class _SimpleEcdfVisuals {
  final List<Color> palette;
  final Color medianColor;
  final Color p90Color;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;

  const _SimpleEcdfVisuals({
    required this.palette,
    required this.medianColor,
    required this.p90Color,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
  });

  factory _SimpleEcdfVisuals.resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    final palette = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleEcdfVisuals(
          palette: palette,
          medianColor: colorScheme.primary,
          p90Color: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          activeColor: colorScheme.primary,
          strokeWidth: 2.8,
          dotRadius: 3.5,
          fillOpacity: 0.18,
        );
      case SimpleTrendChartStyle.professional:
        return _SimpleEcdfVisuals(
          palette: palette,
          medianColor: colorScheme.onSurface,
          p90Color: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.72),
          activeColor: colorScheme.primary,
          strokeWidth: 2.2,
          dotRadius: 2.8,
          fillOpacity: 0.12,
        );
      case SimpleTrendChartStyle.education:
        return _SimpleEcdfVisuals(
          palette: [colorScheme.secondary, ...palette],
          medianColor: colorScheme.secondary,
          p90Color: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.65),
          activeColor: colorScheme.secondary,
          strokeWidth: 2.6,
          dotRadius: 3.8,
          fillOpacity: 0.16,
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleEcdfVisuals(
          palette: [colorScheme.tertiary, ...palette],
          medianColor: colorScheme.tertiary,
          p90Color: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          activeColor: colorScheme.tertiary,
          strokeWidth: 3.2,
          dotRadius: 3.7,
          fillOpacity: 0.22,
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleEcdfVisuals(
          palette: palette,
          medianColor: colorScheme.primary,
          p90Color: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: colorScheme.primary,
          strokeWidth: 2.6,
          dotRadius: 3.2,
          fillOpacity: 0.18,
        );
    }
  }
}

class _EcdfLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final TextStyle textStyle;

  const _EcdfLegendItem({
    required this.label,
    required this.color,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: textStyle),
      ],
    );
  }
}

class _DefaultEcdfTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String percentile;
  final int count;

  const _DefaultEcdfTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.percentile,
    required this.count,
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
                  width: 10,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
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
            _TooltipMetric(label: 'Percentile', value: percentile),
            const SizedBox(height: 4),
            _TooltipMetric(label: 'Samples', value: count.toString()),
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
