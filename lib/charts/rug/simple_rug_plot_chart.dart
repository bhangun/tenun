import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleRugPlotValueFormatter = String Function(double value);

typedef SimpleRugPlotTapCallback =
    void Function(
      SimpleRugPlotSeries series,
      int seriesIndex,
      int valueIndex,
      double value,
    );

typedef SimpleRugPlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleRugPlotSeries series,
      int seriesIndex,
      int valueIndex,
      double value,
      SimpleRugPlotStats stats,
      String formattedValue,
    );

class SimpleRugPlotSeries {
  final String name;
  final List<double> values;
  final Color? color;

  const SimpleRugPlotSeries({
    required this.name,
    required this.values,
    this.color,
  });
}

class SimpleRugPlotStats {
  final int count;
  final double min;
  final double median;
  final double mean;
  final double max;

  const SimpleRugPlotStats({
    required this.count,
    required this.min,
    required this.median,
    required this.mean,
    required this.max,
  });
}

/// A compact rug plot for showing raw observations along a numeric axis.
class SimpleRugPlotChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(56, 22, 20, 42);

  final List<SimpleRugPlotSeries> series;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? tickColor;
  final Color? baselineColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveTick;
  final bool showBaseline;
  final bool showMedian;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? tickLength;
  final double? tickWidth;
  final double tickOpacity;
  final SimpleRugPlotValueFormatter? valueFormatter;
  final SimpleRugPlotTapCallback? onTickTap;
  final SimpleRugPlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleRugPlotChart({
    super.key,
    required this.series,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 220,
    this.padding = _defaultPadding,
    this.palette,
    this.tickColor,
    this.baselineColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveTick = true,
    this.showBaseline = true,
    this.showMedian = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.tickLength,
    this.tickWidth,
    this.tickOpacity = 0.78,
    this.valueFormatter,
    this.onTickTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 620),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(tickLength == null || tickLength > 0),
       assert(tickWidth == null || tickWidth > 0),
       assert(tickOpacity >= 0 && tickOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleRugPlotVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .where(
          (item) =>
              item.name.trim().isNotEmpty &&
              item.values.any((value) => value.isFinite),
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

        if (visibleSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Rug plot chart, no data.',
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
          semanticLabel: _defaultSemanticLabel(visibleSeries, stats, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleRugPlotChartView(
            width: width,
            height: chartHeight,
            series: visibleSeries,
            stats: stats,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(visuals.palette),
            tickColor: tickColor ?? visuals.tickColor,
            baselineColor: baselineColor ?? visuals.baselineColor,
            gridColor: gridColor ?? visuals.gridColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeZero: includeZero,
            showGrid: showGrid,
            showLabels: showLabels,
            showValues: showValues,
            showLegend: showLegend,
            showActiveTick: showActiveTick,
            showTooltip: showTooltip,
            showBaseline: showBaseline,
            showMedian: showMedian,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            tickLength: tickLength ?? visuals.tickLength,
            tickWidth: tickWidth ?? visuals.tickWidth,
            tickOpacity: tickOpacity,
            valueFormatter: formatter,
            onTickTap: onTickTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  SimpleRugPlotStats _statsFor(SimpleRugPlotSeries item) {
    final values = item.values.where((value) => value.isFinite).toList()
      ..sort();
    final count = values.length;
    final mean = values.fold<double>(0, (sum, value) => sum + value) / count;
    return SimpleRugPlotStats(
      count: count,
      min: values.first,
      median: _quantile(values, 0.5),
      mean: mean,
      max: values.last,
    );
  }

  double _quantile(List<double> sorted, double p) {
    if (sorted.length == 1) return sorted.first;
    final position = (sorted.length - 1) * p;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final fraction = position - lower;
    return sorted[lower] * (1 - fraction) + sorted[upper] * fraction;
  }

  String _defaultSemanticLabel(
    List<SimpleRugPlotSeries> visibleSeries,
    List<SimpleRugPlotStats> stats,
    SimpleRugPlotValueFormatter formatter,
  ) {
    final summaries = <String>[];
    for (var index = 0; index < math.min(visibleSeries.length, 4); index++) {
      summaries.add(
        '${visibleSeries[index].name} count ${stats[index].count}, '
        'min ${formatter(stats[index].min)}, '
        'median ${formatter(stats[index].median)}, '
        'max ${formatter(stats[index].max)}',
      );
    }
    final remaining = visibleSeries.length - math.min(visibleSeries.length, 4);
    final suffix = remaining > 0 ? '; and $remaining more series' : '';
    return 'Rug plot chart, ${visibleSeries.length} series. '
        '${summaries.join('; ')}$suffix.';
  }

  List<Color> _resolvePalette(List<Color> defaults) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    if (tickColor == null) return defaults;
    return [tickColor!, ...defaults.skip(1)];
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _SimpleRugPlotChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleRugPlotSeries> series;
  final List<SimpleRugPlotStats> stats;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color tickColor;
  final Color baselineColor;
  final Color gridColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActiveTick;
  final bool showTooltip;
  final bool showBaseline;
  final bool showMedian;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double tickLength;
  final double tickWidth;
  final double tickOpacity;
  final SimpleRugPlotValueFormatter valueFormatter;
  final SimpleRugPlotTapCallback? onTickTap;
  final SimpleRugPlotTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleRugPlotChartView({
    required this.width,
    required this.height,
    required this.series,
    required this.stats,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.tickColor,
    required this.baselineColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActiveTick,
    required this.showTooltip,
    required this.showBaseline,
    required this.showMedian,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.tickLength,
    required this.tickWidth,
    required this.tickOpacity,
    required this.valueFormatter,
    required this.onTickTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleRugPlotChartView> createState() =>
      _SimpleRugPlotChartViewState();
}

class _SimpleRugPlotChartViewState extends State<_SimpleRugPlotChartView> {
  _RugPlotSelection? _active;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveTick || widget.onTickTap != null;
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
                      painter: _SimpleRugPlotPainter(
                        series: widget.series,
                        stats: widget.stats,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        tickColor: widget.tickColor,
                        baselineColor: widget.baselineColor,
                        gridColor: widget.gridColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        includeZero: widget.includeZero,
                        showGrid: widget.showGrid,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showBaseline: widget.showBaseline,
                        showMedian: widget.showMedian,
                        showActiveTick: widget.showActiveTick,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        gridLineCount: widget.gridLineCount,
                        tickLength: widget.tickLength,
                        tickWidth: widget.tickWidth,
                        tickOpacity: widget.tickOpacity,
                        active: _active,
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
                            final selection = _hitTest(
                              details.localPosition,
                              size,
                            );
                            _setActive(selection);
                            if (selection == null) return;
                            widget.onTickTap?.call(
                              selection.series,
                              selection.seriesIndex,
                              selection.valueIndex,
                              selection.value,
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
          if (widget.showLegend && widget.series.length > 1)
            _buildLegend(context),
        ],
      ),
    );
  }

  void _setActive(_RugPlotSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _RugPlotSelection? _hitTest(Offset position, Size size) {
    final geometry = _RugPlotGeometry.resolve(
      size: size,
      series: widget.series,
      stats: widget.stats,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      includeZero: widget.includeZero,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
    for (final tick in geometry.ticks) {
      if (tick.hitRect.inflate(5).contains(position)) {
        return _RugPlotSelection(
          series: widget.series[tick.seriesIndex],
          seriesIndex: tick.seriesIndex,
          valueIndex: tick.valueIndex,
          value: tick.value,
          position: tick.center,
        );
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _RugPlotSelection selection,
  ) {
    final formattedValue = widget.valueFormatter(selection.value);
    final stats = widget.stats[selection.seriesIndex];
    const tooltipWidth = 176.0;
    const tooltipHeight = 92.0;
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
            selection.series,
            selection.seriesIndex,
            selection.valueIndex,
            selection.value,
            stats,
            formattedValue,
          ) ??
          _DefaultRugPlotTooltip(
            color: _colorFor(selection.seriesIndex),
            title: selection.series.name,
            value: formattedValue,
            median: widget.valueFormatter(stats.median),
            count: stats.count,
          ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          for (var index = 0; index < widget.series.length; index++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _colorFor(index),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.series[index].name,
                  style: widget.labelStyle.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _colorFor(int index) {
    final itemColor = widget.series[index].color;
    if (itemColor != null) return itemColor;
    return widget.palette[index % widget.palette.length];
  }
}

class _SimpleRugPlotPainter extends CustomPainter {
  final List<SimpleRugPlotSeries> series;
  final List<SimpleRugPlotStats> stats;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color tickColor;
  final Color baselineColor;
  final Color gridColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showBaseline;
  final bool showMedian;
  final bool showActiveTick;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double tickLength;
  final double tickWidth;
  final double tickOpacity;
  final _RugPlotSelection? active;
  final SimpleRugPlotValueFormatter valueFormatter;
  final double progress;

  const _SimpleRugPlotPainter({
    required this.series,
    required this.stats,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.tickColor,
    required this.baselineColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showBaseline,
    required this.showMedian,
    required this.showActiveTick,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.tickLength,
    required this.tickWidth,
    required this.tickOpacity,
    required this.active,
    required this.valueFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _RugPlotGeometry.resolve(
      size: size,
      series: series,
      stats: stats,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    if (geometry.plot.isEmpty || geometry.ticks.isEmpty) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    if (showBaseline) _drawBaselines(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    if (showMedian) _drawMedians(canvas, geometry);
    _drawTicks(canvas, geometry);
    if (showLabels) _drawLabels(canvas, geometry);
  }

  void _drawReferenceBands(Canvas canvas, _RugPlotGeometry geometry) {
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;
      final from = geometry.xForValue(band.from);
      final to = geometry.xForValue(band.to);
      final rect = Rect.fromLTRB(
        math.min(from, to),
        geometry.plot.top,
        math.max(from, to),
        geometry.plot.bottom,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = (band.color ?? baselineColor).withValues(
            alpha: band.opacity,
          ),
      );
      if (band.showLabel && band.label != null) {
        _paintText(
          canvas,
          band.label!,
          valueStyle.copyWith(color: band.color ?? baselineColor),
          Offset(rect.right - 4, geometry.plot.top + 4),
          TextAlign.right,
          92,
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, _RugPlotGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          geometry.min + geometry.span * (index / gridLineCount).toDouble();
      final x = geometry.xForValue(value);
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
      );
      _paintText(
        canvas,
        valueFormatter(value),
        valueStyle.copyWith(fontWeight: FontWeight.w500),
        Offset(x, geometry.plot.bottom + 8),
        TextAlign.center,
        60,
      );
    }
  }

  void _drawBaselines(Canvas canvas, _RugPlotGeometry geometry) {
    final paint = Paint()
      ..color = baselineColor
      ..strokeWidth = 1.2;
    for (final lane in geometry.lanes) {
      canvas.drawLine(
        Offset(geometry.plot.left, lane.centerY),
        Offset(geometry.plot.right, lane.centerY),
        paint,
      );
    }
  }

  void _drawReferenceLines(Canvas canvas, _RugPlotGeometry geometry) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final x = geometry.xForValue(line.value);
      final paint = Paint()
        ..color = line.color ?? baselineColor
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
          valueStyle.copyWith(color: line.color ?? baselineColor),
          Offset(x + 4, geometry.plot.top + 4),
          TextAlign.left,
          76,
        );
      }
    }
  }

  void _drawMedians(Canvas canvas, _RugPlotGeometry geometry) {
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final lane = geometry.lanes[seriesIndex];
      final x = geometry.xForValue(stats[seriesIndex].median);
      final color = _colorFor(seriesIndex);
      canvas.drawLine(
        Offset(x, lane.centerY - tickLength * 0.68),
        Offset(x, lane.centerY + tickLength * 0.68),
        Paint()
          ..color = color
          ..strokeWidth = tickWidth + 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawTicks(Canvas canvas, _RugPlotGeometry geometry) {
    for (final tick in geometry.ticks) {
      final color = _colorFor(tick.seriesIndex);
      final isActive =
          active?.seriesIndex == tick.seriesIndex &&
          active?.valueIndex == tick.valueIndex;
      final length = tickLength * progress * (isActive ? 1.2 : 1);
      final top = tick.center.dy - length / 2;
      final bottom = tick.center.dy + length / 2;
      if (showActiveTick && isActive) {
        canvas.drawLine(
          Offset(tick.center.dx, top - 4),
          Offset(tick.center.dx, bottom + 4),
          Paint()
            ..color = activeColor.withValues(alpha: 0.2)
            ..strokeWidth = tickWidth + 7
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawLine(
        Offset(tick.center.dx, top),
        Offset(tick.center.dx, bottom),
        Paint()
          ..color = color.withValues(alpha: isActive ? 1 : tickOpacity)
          ..strokeWidth = isActive ? tickWidth + 1 : tickWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawLabels(Canvas canvas, _RugPlotGeometry geometry) {
    final maxWidth = math.max(32.0, padding.left - 12);
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final lane = geometry.lanes[seriesIndex];
      _paintText(
        canvas,
        series[seriesIndex].name,
        labelStyle,
        Offset(geometry.plot.left - 8, lane.centerY),
        TextAlign.right,
        maxWidth,
        centeredY: true,
      );
      if (showValues) {
        _paintText(
          canvas,
          'n=${stats[seriesIndex].count}',
          valueStyle.copyWith(fontSize: (valueStyle.fontSize ?? 11) * 0.9),
          Offset(geometry.plot.right + 4, lane.centerY),
          TextAlign.left,
          math.max(20, padding.right - 4),
          centeredY: true,
        );
      }
    }
  }

  Color _colorFor(int index) {
    final itemColor = series[index].color;
    if (itemColor != null) return itemColor;
    if (tickColor != palette.first) {
      return index == 0 ? tickColor : palette[index % palette.length];
    }
    return palette[index % palette.length];
  }

  @override
  bool shouldRepaint(covariant _SimpleRugPlotPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.stats != stats ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.baselineColor != baselineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeZero != includeZero ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showBaseline != showBaseline ||
        oldDelegate.showMedian != showMedian ||
        oldDelegate.showActiveTick != showActiveTick ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.tickLength != tickLength ||
        oldDelegate.tickWidth != tickWidth ||
        oldDelegate.tickOpacity != tickOpacity ||
        oldDelegate.active != active ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _RugPlotGeometry {
  final Rect plot;
  final double min;
  final double max;
  final List<_RugPlotLane> lanes;
  final List<_RugPlotTick> ticks;

  const _RugPlotGeometry({
    required this.plot,
    required this.min,
    required this.max,
    required this.lanes,
    required this.ticks,
  });

  double get span => max - min;

  double xForValue(double value) {
    if (span <= 0) return plot.left;
    return plot.left + (value - min) / span * plot.width;
  }

  static _RugPlotGeometry resolve({
    required Size size,
    required List<SimpleRugPlotSeries> series,
    required List<SimpleRugPlotStats> stats,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required bool includeZero,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    final left = padding.left.clamp(0.0, size.width * 0.5).toDouble();
    final right = padding.right.clamp(0.0, size.width * 0.35).toDouble();
    final top = padding.top.clamp(0.0, size.height * 0.38).toDouble();
    final bottom = padding.bottom.clamp(0.0, size.height * 0.42).toDouble();
    final plot = Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, size.width - right),
      math.max(top + 1, size.height - bottom),
    );

    var min = minValue ?? double.infinity;
    var max = maxValue ?? -double.infinity;
    for (final stat in stats) {
      min = math.min(min, stat.min);
      max = math.max(max, stat.max);
    }
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      min = math.min(min, line.value);
      max = math.max(max, line.value);
    }
    for (final band in referenceBands) {
      if (band.from.isFinite) {
        min = math.min(min, band.from);
        max = math.max(max, band.from);
      }
      if (band.to.isFinite) {
        min = math.min(min, band.to);
        max = math.max(max, band.to);
      }
    }
    if (includeZero) {
      min = math.min(min, 0);
      max = math.max(max, 0);
    }
    if (!min.isFinite || !max.isFinite) {
      min = 0;
      max = 1;
    }
    if (min == max) {
      min -= 1;
      max += 1;
    } else {
      final pad = (max - min) * 0.06;
      min = minValue ?? (min - pad);
      max = maxValue ?? (max + pad);
    }

    final rowHeight = plot.height / math.max(1, series.length);
    final lanes = <_RugPlotLane>[];
    final ticks = <_RugPlotTick>[];
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final centerY = plot.top + rowHeight * seriesIndex + rowHeight / 2;
      lanes.add(_RugPlotLane(centerY: centerY));
      var valueIndex = 0;
      for (final value in series[seriesIndex].values) {
        if (!value.isFinite) {
          valueIndex++;
          continue;
        }
        final x =
            plot.left +
            (value - min) / math.max(0.000001, max - min) * plot.width;
        final hitRect = Rect.fromCenter(
          center: Offset(x, centerY),
          width: 8,
          height: math.max(16, rowHeight * 0.7),
        );
        ticks.add(
          _RugPlotTick(
            seriesIndex: seriesIndex,
            valueIndex: valueIndex,
            value: value,
            center: Offset(x, centerY),
            hitRect: hitRect,
          ),
        );
        valueIndex++;
      }
    }

    return _RugPlotGeometry(
      plot: plot,
      min: min,
      max: max,
      lanes: lanes,
      ticks: ticks,
    );
  }
}

class _RugPlotLane {
  final double centerY;

  const _RugPlotLane({required this.centerY});
}

class _RugPlotTick {
  final int seriesIndex;
  final int valueIndex;
  final double value;
  final Offset center;
  final Rect hitRect;

  const _RugPlotTick({
    required this.seriesIndex,
    required this.valueIndex,
    required this.value,
    required this.center,
    required this.hitRect,
  });
}

class _RugPlotSelection {
  final SimpleRugPlotSeries series;
  final int seriesIndex;
  final int valueIndex;
  final double value;
  final Offset position;

  const _RugPlotSelection({
    required this.series,
    required this.seriesIndex,
    required this.valueIndex,
    required this.value,
    required this.position,
  });

  @override
  bool operator ==(Object other) {
    return other is _RugPlotSelection &&
        other.seriesIndex == seriesIndex &&
        other.valueIndex == valueIndex &&
        other.position == position;
  }

  @override
  int get hashCode => Object.hash(seriesIndex, valueIndex, position);
}

class _SimpleRugPlotVisuals {
  final List<Color> palette;
  final Color tickColor;
  final Color baselineColor;
  final Color gridColor;
  final Color activeColor;
  final double tickLength;
  final double tickWidth;

  const _SimpleRugPlotVisuals({
    required this.palette,
    required this.tickColor,
    required this.baselineColor,
    required this.gridColor,
    required this.activeColor,
    required this.tickLength,
    required this.tickWidth,
  });

  static _SimpleRugPlotVisuals resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    final grid = colorScheme.outlineVariant.withValues(alpha: 0.55);
    final baseline = colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleRugPlotVisuals(
          palette: const [
            Color(0xFF2563EB),
            Color(0xFF14B8A6),
            Color(0xFFF97316),
          ],
          tickColor: const Color(0xFF2563EB),
          baselineColor: baseline,
          gridColor: grid,
          activeColor: colorScheme.primary,
          tickLength: 26,
          tickWidth: 2,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleRugPlotVisuals(
          palette: const [
            Color(0xFF0F766E),
            Color(0xFF475569),
            Color(0xFFB45309),
          ],
          tickColor: const Color(0xFF0F766E),
          baselineColor: baseline,
          gridColor: grid,
          activeColor: const Color(0xFF334155),
          tickLength: 24,
          tickWidth: 1.7,
        );
      case SimpleBarChartStyle.education:
        return _SimpleRugPlotVisuals(
          palette: const [
            Color(0xFF22C55E),
            Color(0xFF3B82F6),
            Color(0xFFF59E0B),
          ],
          tickColor: const Color(0xFF22C55E),
          baselineColor: baseline,
          gridColor: grid,
          activeColor: const Color(0xFFF59E0B),
          tickLength: 27,
          tickWidth: 2.1,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleRugPlotVisuals(
          palette: const [
            Color(0xFF8B5CF6),
            Color(0xFF06B6D4),
            Color(0xFFF43F5E),
          ],
          tickColor: const Color(0xFF8B5CF6),
          baselineColor: baseline,
          gridColor: grid,
          activeColor: const Color(0xFFF43F5E),
          tickLength: 28,
          tickWidth: 2.2,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleRugPlotVisuals(
          palette: const [
            Color(0xFF0D9488),
            Color(0xFF7C3AED),
            Color(0xFFBE123C),
          ],
          tickColor: colorScheme.primary,
          baselineColor: baseline,
          gridColor: grid,
          activeColor: colorScheme.primary,
          tickLength: 25,
          tickWidth: 1.9,
        );
    }
  }
}

class _DefaultRugPlotTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String median;
  final int count;

  const _DefaultRugPlotTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.median,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _RugTooltipRow(label: 'Value', value: value),
            _RugTooltipRow(label: 'Median', value: median),
            _RugTooltipRow(label: 'Count', value: count.toString()),
          ],
        ),
      ),
    );
  }
}

class _RugTooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _RugTooltipRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

void _drawStyledLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint,
  SimpleChartReferenceLineStyle style,
) {
  switch (style) {
    case SimpleChartReferenceLineStyle.solid:
      canvas.drawLine(start, end, paint);
    case SimpleChartReferenceLineStyle.dashed:
      _drawDashedLine(canvas, start, end, paint, const [8, 5]);
    case SimpleChartReferenceLineStyle.dotted:
      _drawDashedLine(canvas, start, end, paint, const [1, 6]);
  }
}

void _drawDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint,
  List<double> pattern,
) {
  final vector = end - start;
  final distance = vector.distance;
  if (distance <= 0) return;
  final direction = vector / distance;
  var drawn = 0.0;
  var patternIndex = 0;
  while (drawn < distance) {
    final length = pattern[patternIndex % pattern.length];
    final next = math.min(distance, drawn + length);
    if (patternIndex.isEven) {
      canvas.drawLine(
        start + direction * drawn,
        start + direction * next,
        paint,
      );
    }
    drawn = next;
    patternIndex++;
  }
}

void _paintText(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset offset,
  TextAlign align,
  double maxWidth, {
  bool centeredY = false,
}) {
  if (text.isEmpty || maxWidth <= 0) return;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  var dx = offset.dx;
  if (align == TextAlign.center) {
    dx -= painter.width / 2;
  } else if (align == TextAlign.right || align == TextAlign.end) {
    dx -= painter.width;
  }
  final dy = centeredY ? offset.dy - painter.height / 2 : offset.dy;
  painter.paint(canvas, Offset(dx, dy));
}
