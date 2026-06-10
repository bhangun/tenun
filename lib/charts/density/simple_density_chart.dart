import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import '../line/simple_line_chart.dart';

typedef SimpleDensityValueFormatter = String Function(double value);
typedef SimpleDensityTapCallback =
    void Function(
      SimpleDensitySeries series,
      double value,
      double density,
      int seriesIndex,
    );
typedef SimpleDensityTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleDensitySeries series,
      SimpleDensityStats stats,
      double value,
      double density,
      int seriesIndex,
      String formattedValue,
      String formattedDensity,
    );

class SimpleDensitySeries {
  final String name;
  final List<double> values;
  final Color? color;

  const SimpleDensitySeries({
    required this.name,
    required this.values,
    this.color,
  });
}

class SimpleDensityStats {
  final int count;
  final double min;
  final double mean;
  final double median;
  final double max;
  final double peakValue;
  final double peakDensity;

  const SimpleDensityStats({
    required this.count,
    required this.min,
    required this.mean,
    required this.median,
    required this.max,
    required this.peakValue,
    required this.peakDensity,
  });
}

/// A simple kernel density chart for comparing smooth distributions across
/// samples, cohorts, latency, scores, prices, and measurements.
class SimpleDensityChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(56, 18, 18, 42);

  final List<SimpleDensitySeries> series;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? lineColor;
  final Color? fillColor;
  final Color? meanColor;
  final Color? medianColor;
  final Color? rugColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLine;
  final bool showArea;
  final bool showRug;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSeries;
  final bool showMean;
  final bool showMedian;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int sampleCount;
  final double? strokeWidth;
  final double? fillOpacity;
  final double? rugHeight;
  final SimpleDensityValueFormatter? valueFormatter;
  final SimpleDensityValueFormatter? densityFormatter;
  final SimpleDensityTapCallback? onSeriesTap;
  final SimpleDensityTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleDensityChart({
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
    this.meanColor,
    this.medianColor,
    this.rugColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showLine = true,
    this.showArea = true,
    this.showRug = false,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveSeries = true,
    this.showMean = false,
    this.showMedian = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.sampleCount = 96,
    this.strokeWidth,
    this.fillOpacity,
    this.rugHeight,
    this.valueFormatter,
    this.densityFormatter,
    this.onSeriesTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(sampleCount >= 12),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(fillOpacity == null || (fillOpacity >= 0 && fillOpacity <= 1)),
       assert(rugHeight == null || rugHeight >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleDensityVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .where(
          (item) =>
              item.name.trim().isNotEmpty &&
              item.values.any((value) => value.isFinite),
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedDensityFormatter =
        densityFormatter ?? _defaultDensityFormatter;

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
            emptySemanticLabel: 'Density chart, no data.',
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
          semanticLabel: _defaultSemanticLabel(visibleSeries, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleDensityChartView(
            width: width,
            height: chartHeight,
            series: visibleSeries,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(visuals.palette),
            lineColor: lineColor,
            fillColor: fillColor,
            meanColor: meanColor ?? visuals.meanColor,
            medianColor: medianColor ?? visuals.medianColor,
            rugColor: rugColor ?? visuals.rugColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeZero: includeZero,
            showGrid: showGrid,
            showLine: showLine,
            showArea: showArea,
            showRug: showRug,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveSeries: showActiveSeries,
            showMean: showMean,
            showMedian: showMedian,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            sampleCount: sampleCount,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            fillOpacity: fillOpacity ?? visuals.fillOpacity,
            rugHeight: rugHeight ?? visuals.rugHeight,
            valueFormatter: formatter,
            densityFormatter: resolvedDensityFormatter,
            onSeriesTap: onSeriesTap,
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
    List<SimpleDensitySeries> visibleSeries,
    SimpleDensityValueFormatter formatter,
  ) {
    final summaries = <String>[];
    final limit = math.min(visibleSeries.length, 3);
    for (var index = 0; index < limit; index++) {
      final stats = _statsFor(visibleSeries[index], minValue, maxValue);
      summaries.add(
        '${visibleSeries[index].name} ${stats.count} samples, median '
        '${formatter(stats.median)}, peak near ${formatter(stats.peakValue)}',
      );
    }
    final suffix = visibleSeries.length > limit
        ? '; and ${visibleSeries.length - limit} more series'
        : '';
    final seriesLabel = visibleSeries.length == 1 ? 'series' : 'series';
    return 'Density chart, ${visibleSeries.length} $seriesLabel. '
        '${summaries.join('; ')}$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _defaultDensityFormatter(double value) {
    if (value >= 1) return value.toStringAsFixed(1);
    return value.toStringAsFixed(3);
  }
}

class _SimpleDensityChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleDensitySeries> series;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? lineColor;
  final Color? fillColor;
  final Color meanColor;
  final Color medianColor;
  final Color rugColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLine;
  final bool showArea;
  final bool showRug;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSeries;
  final bool showMean;
  final bool showMedian;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int sampleCount;
  final double strokeWidth;
  final double fillOpacity;
  final double rugHeight;
  final SimpleDensityValueFormatter valueFormatter;
  final SimpleDensityValueFormatter densityFormatter;
  final SimpleDensityTapCallback? onSeriesTap;
  final SimpleDensityTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleDensityChartView({
    required this.width,
    required this.height,
    required this.series,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.lineColor,
    required this.fillColor,
    required this.meanColor,
    required this.medianColor,
    required this.rugColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showLine,
    required this.showArea,
    required this.showRug,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveSeries,
    required this.showMean,
    required this.showMedian,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.sampleCount,
    required this.strokeWidth,
    required this.fillOpacity,
    required this.rugHeight,
    required this.valueFormatter,
    required this.densityFormatter,
    required this.onSeriesTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleDensityChartView> createState() =>
      _SimpleDensityChartViewState();
}

class _SimpleDensityChartViewState extends State<_SimpleDensityChartView> {
  _DensitySelection? _active;

  @override
  Widget build(BuildContext context) {
    final hasLegend = widget.showLegend && widget.series.length > 1;
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveSeries ||
        widget.onSeriesTap != null;

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
                      painter: _SimpleDensityPainter(
                        series: widget.series,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        lineColor: widget.lineColor,
                        fillColor: widget.fillColor,
                        meanColor: widget.meanColor,
                        medianColor: widget.medianColor,
                        rugColor: widget.rugColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        includeZero: widget.includeZero,
                        showGrid: widget.showGrid,
                        showLine: widget.showLine,
                        showArea: widget.showArea,
                        showRug: widget.showRug,
                        showValues: widget.showValues,
                        showActiveSeries: widget.showActiveSeries,
                        showMean: widget.showMean,
                        showMedian: widget.showMedian,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        gridLineCount: widget.gridLineCount,
                        sampleCount: widget.sampleCount,
                        strokeWidth: widget.strokeWidth,
                        fillOpacity: widget.fillOpacity,
                        rugHeight: widget.rugHeight,
                        activeSelection: _active,
                        valueFormatter: widget.valueFormatter,
                        densityFormatter: widget.densityFormatter,
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
                            widget.onSeriesTap?.call(
                              widget.series[selection.seriesIndex],
                              selection.value,
                              selection.density,
                              selection.seriesIndex,
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

  void _setActive(_DensitySelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _DensitySelection? _hitTest(Offset position, Size size) {
    final geometry = _DensityGeometry.resolve(
      size: size,
      series: widget.series,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      includeZero: widget.includeZero,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
      sampleCount: widget.sampleCount,
    );
    if (!geometry.plot.inflate(10).contains(position)) return null;

    _DensitySelection? best;
    var bestScore = double.infinity;
    for (final line in geometry.series) {
      for (final point in line.points) {
        final dx = (position.dx - point.center.dx).abs();
        final dy = (position.dy - point.center.dy).abs();
        final score = dx + dy * 0.28;
        if (score < bestScore) {
          bestScore = score;
          best = _DensitySelection(
            line.seriesIndex,
            point.value,
            point.density,
            point.center,
          );
        }
      }
    }
    return bestScore <= 34 ? best : null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _DensitySelection selection,
  ) {
    final densitySeries = widget.series[selection.seriesIndex];
    final stats = _statsFor(densitySeries, widget.minValue, widget.maxValue);
    final formattedValue = widget.valueFormatter(selection.value);
    final formattedDensity = widget.densityFormatter(selection.density);
    const tooltipWidth = 190.0;
    const tooltipHeight = 90.0;
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
            densitySeries,
            stats,
            selection.value,
            selection.density,
            selection.seriesIndex,
            formattedValue,
            formattedDensity,
          ) ??
          _DefaultDensityTooltip(
            color: _seriesColor(densitySeries, selection.seriesIndex),
            title: densitySeries.name,
            value: formattedValue,
            density: formattedDensity,
            median: widget.valueFormatter(stats.median),
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
            _DensityLegendItem(
              label: widget.series[index].name,
              color: _seriesColor(widget.series[index], index),
              textStyle: widget.labelStyle,
            ),
        ],
      ),
    );
  }

  Color _seriesColor(SimpleDensitySeries item, int index) {
    return item.color ??
        widget.lineColor ??
        widget.palette[index % widget.palette.length];
  }
}

class _SimpleDensityPainter extends CustomPainter {
  final List<SimpleDensitySeries> series;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? lineColor;
  final Color? fillColor;
  final Color meanColor;
  final Color medianColor;
  final Color rugColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLine;
  final bool showArea;
  final bool showRug;
  final bool showValues;
  final bool showActiveSeries;
  final bool showMean;
  final bool showMedian;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int sampleCount;
  final double strokeWidth;
  final double fillOpacity;
  final double rugHeight;
  final _DensitySelection? activeSelection;
  final SimpleDensityValueFormatter valueFormatter;
  final SimpleDensityValueFormatter densityFormatter;
  final double progress;

  const _SimpleDensityPainter({
    required this.series,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.lineColor,
    required this.fillColor,
    required this.meanColor,
    required this.medianColor,
    required this.rugColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showLine,
    required this.showArea,
    required this.showRug,
    required this.showValues,
    required this.showActiveSeries,
    required this.showMean,
    required this.showMedian,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.sampleCount,
    required this.strokeWidth,
    required this.fillOpacity,
    required this.rugHeight,
    required this.activeSelection,
    required this.valueFormatter,
    required this.densityFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _DensityGeometry.resolve(
      size: size,
      series: series,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
      sampleCount: sampleCount,
    );
    if (geometry.plot.isEmpty || geometry.series.isEmpty) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    _drawDensitySeries(canvas, geometry);
    if (showRug) _drawRug(canvas, geometry);
    _drawMarkers(canvas, geometry);
  }

  void _drawReferenceBands(Canvas canvas, _DensityGeometry geometry) {
    final paint = Paint();
    for (final band in referenceBands) {
      final start = geometry.xForValue(band.from);
      final end = geometry.xForValue(band.to);
      paint.color = (band.color ?? palette.first).withValues(
        alpha: band.opacity,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          math.min(start, end),
          geometry.plot.top,
          math.max(start, end),
          geometry.plot.bottom,
        ),
        paint,
      );
    }
  }

  void _drawGrid(Canvas canvas, _DensityGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          geometry.range.min + geometry.range.span * (index / gridLineCount);
      final x = geometry.xForValue(value);
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
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

    for (var index = 1; index <= gridLineCount; index++) {
      final density = geometry.maxDensity * (index / gridLineCount);
      final y = geometry.yForDensity(density);
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint..color = gridColor.withValues(alpha: 0.62),
      );
    }
  }

  void _drawAxis(Canvas canvas, _DensityGeometry geometry) {
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

  void _drawReferenceLines(Canvas canvas, _DensityGeometry geometry) {
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

  void _drawDensitySeries(Canvas canvas, _DensityGeometry geometry) {
    for (final layout in geometry.series) {
      final item = series[layout.seriesIndex];
      final color = _seriesColor(item, layout.seriesIndex);
      final selected = activeSelection?.seriesIndex == layout.seriesIndex;
      final path = _pathFor(layout, geometry, closeArea: false);
      final areaPath = _pathFor(layout, geometry, closeArea: true);

      if (showArea) {
        canvas.drawPath(
          areaPath,
          Paint()
            ..color = (fillColor ?? color).withValues(
              alpha: selected && showActiveSeries
                  ? math.min(1.0, fillOpacity + 0.08)
                  : fillOpacity,
            )
            ..style = PaintingStyle.fill,
        );
      }

      if (showLine) {
        canvas.drawPath(
          path,
          Paint()
            ..color = selected && showActiveSeries ? activeColor : color
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected && showActiveSeries
                ? strokeWidth + 1.2
                : strokeWidth
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }

      if (showValues && layout.peak != null && progress > 0.7) {
        _paintText(
          canvas,
          valueFormatter(layout.peak!.value),
          valueStyle.copyWith(color: color),
          Offset(layout.peak!.center.dx, layout.peak!.center.dy - 18),
          TextAlign.center,
          64,
        );
      }
    }
  }

  Path _pathFor(
    _DensitySeriesLayout layout,
    _DensityGeometry geometry, {
    required bool closeArea,
  }) {
    final baseline = geometry.plot.bottom;
    final path = Path();
    if (layout.points.isEmpty) return path;
    for (var index = 0; index < layout.points.length; index++) {
      final point = layout.points[index];
      final animated = Offset(
        point.center.dx,
        baseline - (baseline - point.center.dy) * progress,
      );
      if (index == 0) {
        path.moveTo(animated.dx, animated.dy);
      } else {
        final previous = layout.points[index - 1];
        final previousAnimated = Offset(
          previous.center.dx,
          baseline - (baseline - previous.center.dy) * progress,
        );
        final midX = (previousAnimated.dx + animated.dx) / 2;
        path.cubicTo(
          midX,
          previousAnimated.dy,
          midX,
          animated.dy,
          animated.dx,
          animated.dy,
        );
      }
    }
    if (closeArea) {
      path
        ..lineTo(layout.points.last.center.dx, baseline)
        ..lineTo(layout.points.first.center.dx, baseline)
        ..close();
    }
    return path;
  }

  void _drawRug(Canvas canvas, _DensityGeometry geometry) {
    final paint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final item = series[seriesIndex];
      paint.color =
          (rugColor == Colors.transparent
                  ? _seriesColor(item, seriesIndex)
                  : rugColor)
              .withValues(alpha: 0.55);
      for (final value in item.values.where((value) => value.isFinite)) {
        final x = geometry.xForValue(value);
        canvas.drawLine(
          Offset(x, geometry.plot.bottom),
          Offset(x, geometry.plot.bottom - rugHeight),
          paint,
        );
      }
    }
  }

  void _drawMarkers(Canvas canvas, _DensityGeometry geometry) {
    if (!showMean && !showMedian) return;
    for (var index = 0; index < series.length; index++) {
      final stats = _statsFor(series[index], minValue, maxValue);
      if (showMean) {
        _drawMarker(canvas, geometry, stats.mean, meanColor, 'Mean');
      }
      if (showMedian) {
        _drawMarker(canvas, geometry, stats.median, medianColor, 'Median');
      }
    }
  }

  void _drawMarker(
    Canvas canvas,
    _DensityGeometry geometry,
    double value,
    Color color,
    String label,
  ) {
    final x = geometry.xForValue(value);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    _drawStyledLine(
      canvas,
      Offset(x, geometry.plot.top),
      Offset(x, geometry.plot.bottom),
      paint,
      SimpleChartReferenceLineStyle.dotted,
    );
    if (showValues) {
      _paintText(
        canvas,
        '$label ${valueFormatter(value)}',
        valueStyle.copyWith(color: color),
        Offset(x + 5, geometry.plot.top + 6),
        TextAlign.left,
        90,
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

  Color _seriesColor(SimpleDensitySeries item, int index) {
    return item.color ?? lineColor ?? palette[index % palette.length];
  }

  @override
  bool shouldRepaint(covariant _SimpleDensityPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.meanColor != meanColor ||
        oldDelegate.medianColor != medianColor ||
        oldDelegate.rugColor != rugColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeZero != includeZero ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLine != showLine ||
        oldDelegate.showArea != showArea ||
        oldDelegate.showRug != showRug ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showActiveSeries != showActiveSeries ||
        oldDelegate.showMean != showMean ||
        oldDelegate.showMedian != showMedian ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.sampleCount != sampleCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.rugHeight != rugHeight ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.densityFormatter != densityFormatter ||
        oldDelegate.progress != progress;
  }
}

class _DensityGeometry {
  final Rect plot;
  final _DensityRange range;
  final List<_DensitySeriesLayout> series;
  final double maxDensity;

  const _DensityGeometry({
    required this.plot,
    required this.range,
    required this.series,
    required this.maxDensity,
  });

  factory _DensityGeometry.resolve({
    required Size size,
    required List<SimpleDensitySeries> series,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required bool includeZero,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
    required int sampleCount,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0 || series.isEmpty) {
      return _DensityGeometry(
        plot: plot,
        range: const _DensityRange(0, 1),
        series: const [],
        maxDensity: 1,
      );
    }

    final range = _DensityRange.resolve(
      series: series,
      minValue: minValue,
      maxValue: maxValue,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    final raw = <List<_DensityPoint>>[];
    var maxDensityValue = 0.0;
    for (final item in series) {
      final values = item.values.where((value) => value.isFinite).toList();
      final density = _kde(values, range.min, range.max, sampleCount);
      raw.add(density);
      for (final point in density) {
        maxDensityValue = math.max(maxDensityValue, point.density);
      }
    }
    if (maxDensityValue <= 0) maxDensityValue = 1;

    final layouts = <_DensitySeriesLayout>[];
    for (var seriesIndex = 0; seriesIndex < raw.length; seriesIndex++) {
      final points = raw[seriesIndex]
          .map(
            (point) => _DensityPointLayout(
              value: point.value,
              density: point.density,
              center: Offset(
                _xForValue(point.value, plot, range),
                _yForDensity(point.density, plot, maxDensityValue),
              ),
            ),
          )
          .toList();
      _DensityPointLayout? peak;
      for (final point in points) {
        if (peak == null || point.density > peak.density) {
          peak = point;
        }
      }
      layouts.add(
        _DensitySeriesLayout(
          seriesIndex: seriesIndex,
          points: points,
          peak: peak,
        ),
      );
    }

    return _DensityGeometry(
      plot: plot,
      range: range,
      series: layouts,
      maxDensity: maxDensityValue,
    );
  }

  double xForValue(double value) => _xForValue(value, plot, range);

  double yForDensity(double density) {
    return _yForDensity(density, plot, maxDensity);
  }

  static double _xForValue(double value, Rect plot, _DensityRange range) {
    final normalized = ((value - range.min) / range.span).clamp(0.0, 1.0);
    return plot.left + normalized * plot.width;
  }

  static double _yForDensity(double density, Rect plot, double maxDensity) {
    final normalized = (density / maxDensity).clamp(0.0, 1.0);
    return plot.bottom - normalized * plot.height;
  }
}

class _DensitySeriesLayout {
  final int seriesIndex;
  final List<_DensityPointLayout> points;
  final _DensityPointLayout? peak;

  const _DensitySeriesLayout({
    required this.seriesIndex,
    required this.points,
    required this.peak,
  });
}

class _DensityPointLayout {
  final double value;
  final double density;
  final Offset center;

  const _DensityPointLayout({
    required this.value,
    required this.density,
    required this.center,
  });
}

class _DensityPoint {
  final double value;
  final double density;

  const _DensityPoint({required this.value, required this.density});
}

class _DensitySelection {
  final int seriesIndex;
  final double value;
  final double density;
  final Offset position;

  const _DensitySelection(
    this.seriesIndex,
    this.value,
    this.density,
    this.position,
  );

  @override
  bool operator ==(Object other) {
    return other is _DensitySelection &&
        other.seriesIndex == seriesIndex &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(seriesIndex, value);
}

class _DensityRange {
  final double min;
  final double max;

  const _DensityRange(this.min, this.max);

  double get span => max - min;

  factory _DensityRange.resolve({
    required List<SimpleDensitySeries> series,
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
    return _DensityRange(lower, upper);
  }
}

List<_DensityPoint> _kde(
  List<double> values,
  double min,
  double max,
  int steps,
) {
  final sorted = values.where((value) => value.isFinite).toList();
  if (sorted.isEmpty) return const [];
  final n = sorted.length;
  final mean = sorted.fold(0.0, (sum, value) => sum + value) / n;
  final variance =
      sorted.fold(
        0.0,
        (sum, value) => sum + math.pow(value - mean, 2).toDouble(),
      ) /
      n;
  final std = math.sqrt(variance);
  final span = math.max(1e-9, max - min);
  final bandwidth = math.max(
    span * 0.035,
    1.06 * std * math.pow(n, -0.2).toDouble(),
  );
  final safeBandwidth = bandwidth <= 0 ? span * 0.08 : bandwidth;
  final result = <_DensityPoint>[];
  for (var index = 0; index <= steps; index++) {
    final value = min + span * (index / steps);
    var density = 0.0;
    for (final sample in sorted) {
      final z = (value - sample) / safeBandwidth;
      density += math.exp(-0.5 * z * z);
    }
    result.add(
      _DensityPoint(
        value: value,
        density: density / (n * safeBandwidth * math.sqrt(2 * math.pi)),
      ),
    );
  }
  return result;
}

SimpleDensityStats _statsFor(
  SimpleDensitySeries series,
  double? minValue,
  double? maxValue,
) {
  final values = series.values.where((value) => value.isFinite).toList()
    ..sort();
  final sum = values.fold<double>(0, (total, value) => total + value);
  final density = _kde(
    values,
    minValue ?? values.first,
    maxValue ?? values.last,
    96,
  );
  _DensityPoint? peak;
  for (final point in density) {
    if (peak == null || point.density > peak.density) peak = point;
  }
  return SimpleDensityStats(
    count: values.length,
    min: values.first,
    mean: sum / values.length,
    median: _quantile(values, 0.5),
    max: values.last,
    peakValue: peak?.value ?? values.first,
    peakDensity: peak?.density ?? 0,
  );
}

double _quantile(List<double> sorted, double percentile) {
  if (sorted.length == 1) return sorted.first;
  final position = (sorted.length - 1) * percentile;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sorted[lower];
  final weight = position - lower;
  return sorted[lower] * (1 - weight) + sorted[upper] * weight;
}

class _SimpleDensityVisuals {
  final List<Color> palette;
  final Color meanColor;
  final Color medianColor;
  final Color rugColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double strokeWidth;
  final double fillOpacity;
  final double rugHeight;

  const _SimpleDensityVisuals({
    required this.palette,
    required this.meanColor,
    required this.medianColor,
    required this.rugColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.strokeWidth,
    required this.fillOpacity,
    required this.rugHeight,
  });

  factory _SimpleDensityVisuals.resolve(
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
        return _SimpleDensityVisuals(
          palette: palette,
          meanColor: colorScheme.tertiary,
          medianColor: colorScheme.primary,
          rugColor: Colors.transparent,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          activeColor: colorScheme.primary,
          strokeWidth: 2.8,
          fillOpacity: 0.2,
          rugHeight: 14,
        );
      case SimpleTrendChartStyle.professional:
        return _SimpleDensityVisuals(
          palette: palette,
          meanColor: colorScheme.secondary,
          medianColor: colorScheme.onSurface,
          rugColor: Colors.transparent,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.72),
          activeColor: colorScheme.primary,
          strokeWidth: 2.2,
          fillOpacity: 0.12,
          rugHeight: 12,
        );
      case SimpleTrendChartStyle.education:
        return _SimpleDensityVisuals(
          palette: [colorScheme.secondary, ...palette],
          meanColor: colorScheme.tertiary,
          medianColor: colorScheme.secondary,
          rugColor: Colors.transparent,
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.65),
          activeColor: colorScheme.secondary,
          strokeWidth: 2.6,
          fillOpacity: 0.16,
          rugHeight: 14,
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleDensityVisuals(
          palette: [colorScheme.tertiary, ...palette],
          meanColor: colorScheme.primary,
          medianColor: colorScheme.tertiary,
          rugColor: Colors.transparent,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          activeColor: colorScheme.tertiary,
          strokeWidth: 3.1,
          fillOpacity: 0.24,
          rugHeight: 15,
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleDensityVisuals(
          palette: palette,
          meanColor: colorScheme.tertiary,
          medianColor: colorScheme.primary,
          rugColor: Colors.transparent,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: colorScheme.primary,
          strokeWidth: 2.6,
          fillOpacity: 0.18,
          rugHeight: 13,
        );
    }
  }
}

class _DensityLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final TextStyle textStyle;

  const _DensityLegendItem({
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

class _DefaultDensityTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String density;
  final String median;

  const _DefaultDensityTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.density,
    required this.median,
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
            _TooltipMetric(label: 'Density', value: density),
            const SizedBox(height: 4),
            _TooltipMetric(label: 'Median', value: median),
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
