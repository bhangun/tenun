import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';
import '../rug/simple_rug_plot_chart.dart';

typedef SimpleBarcodePlotValueFormatter = String Function(double value);

typedef SimpleBarcodePlotTapCallback =
    void Function(
      SimpleBarcodePlotSeries series,
      int seriesIndex,
      int valueIndex,
      double value,
    );

typedef SimpleBarcodePlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleBarcodePlotSeries series,
      int seriesIndex,
      int valueIndex,
      double value,
      SimpleBarcodePlotStats stats,
      String formattedValue,
    );

class SimpleBarcodePlotSeries {
  final String name;
  final List<double> values;
  final Color? color;

  const SimpleBarcodePlotSeries({
    required this.name,
    required this.values,
    this.color,
  });
}

class SimpleBarcodePlotStats {
  final int count;
  final double min;
  final double median;
  final double mean;
  final double max;

  const SimpleBarcodePlotStats({
    required this.count,
    required this.min,
    required this.median,
    required this.mean,
    required this.max,
  });
}

/// A compact barcode plot for event density and raw observation positions.
class SimpleBarcodePlotChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(58, 18, 20, 38);

  final List<SimpleBarcodePlotSeries> series;
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
  final SimpleBarcodePlotValueFormatter? valueFormatter;
  final SimpleBarcodePlotTapCallback? onTickTap;
  final SimpleBarcodePlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleBarcodePlotChart({
    super.key,
    required this.series,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 190,
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
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveTick = true,
    this.showBaseline = true,
    this.showMedian = false,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.tickLength,
    this.tickWidth,
    this.tickOpacity = 0.72,
    this.valueFormatter,
    this.onTickTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 580),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(tickLength == null || tickLength > 0),
       assert(tickWidth == null || tickWidth > 0),
       assert(tickOpacity >= 0 && tickOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final visibleSeries = series
        .where(
          (item) =>
              item.name.trim().isNotEmpty &&
              item.values.any((value) => value.isFinite),
        )
        .toList();
    final stats = visibleSeries.map(_statsFor).toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final rugSeries = [
      for (final item in visibleSeries)
        SimpleRugPlotSeries(
          name: item.name,
          values: item.values,
          color: item.color,
        ),
    ];

    final child = SimpleRugPlotChart(
      series: rugSeries,
      style: style,
      minValue: minValue,
      maxValue: maxValue,
      height: height,
      padding: padding,
      palette: palette,
      tickColor: tickColor,
      baselineColor: baselineColor,
      gridColor: gridColor,
      activeColor: activeColor,
      labelStyle: labelStyle,
      valueStyle: valueStyle,
      includeZero: includeZero,
      showGrid: showGrid,
      showLabels: showLabels,
      showValues: showValues,
      showLegend: showLegend,
      showTooltip: showTooltip,
      showActiveTick: showActiveTick,
      showBaseline: showBaseline,
      showMedian: showMedian,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
      gridLineCount: gridLineCount,
      tickLength: tickLength,
      tickWidth: tickWidth,
      tickOpacity: tickOpacity,
      valueFormatter: formatter,
      onTickTap: onTickTap == null
          ? null
          : (item, seriesIndex, valueIndex, value) {
              onTickTap!(
                visibleSeries[seriesIndex],
                seriesIndex,
                valueIndex,
                value,
              );
            },
      tooltipBuilder: tooltipBuilder == null
          ? null
          : (context, item, seriesIndex, valueIndex, value, _, formattedValue) {
              return tooltipBuilder!(
                context,
                visibleSeries[seriesIndex],
                seriesIndex,
                valueIndex,
                value,
                stats[seriesIndex],
                formattedValue,
              );
            },
      emptyBuilder: emptyBuilder,
      excludeFromSemantics: true,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
    );

    return ChartApiSurface(
      semanticLabel: _defaultSemanticLabel(visibleSeries, stats, formatter),
      accessibility: ChartAccessibilityOptions(
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      ),
      child: child,
    );
  }

  String _defaultSemanticLabel(
    List<SimpleBarcodePlotSeries> visibleSeries,
    List<SimpleBarcodePlotStats> stats,
    SimpleBarcodePlotValueFormatter formatter,
  ) {
    if (visibleSeries.isEmpty) return 'Barcode plot chart, no data.';
    final limit = math.min(visibleSeries.length, 4);
    final summaries = <String>[];
    for (var index = 0; index < limit; index++) {
      final item = visibleSeries[index];
      final summary = stats[index];
      summaries.add(
        '${item.name} count ${summary.count}, min ${formatter(summary.min)}, '
        'median ${formatter(summary.median)}, max ${formatter(summary.max)}',
      );
    }
    final suffix = visibleSeries.length > limit
        ? '; and ${visibleSeries.length - limit} more series'
        : '';
    final seriesLabel = visibleSeries.length == 1 ? 'series' : 'series';
    return 'Barcode plot chart, ${visibleSeries.length} $seriesLabel. '
        '${summaries.join('; ')}$suffix.';
  }

  static SimpleBarcodePlotStats _statsFor(SimpleBarcodePlotSeries item) {
    final values = item.values.where((value) => value.isFinite).toList()
      ..sort();
    final sum = values.fold<double>(0, (total, value) => total + value);
    return SimpleBarcodePlotStats(
      count: values.length,
      min: values.first,
      median: _quantile(values, 0.5),
      mean: sum / values.length,
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
}
