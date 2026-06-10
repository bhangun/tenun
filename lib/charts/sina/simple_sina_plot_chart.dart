import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../beeswarm/simple_beeswarm_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleSinaPlotValueFormatter = String Function(double value);

typedef SimpleSinaPlotTapCallback =
    void Function(
      SimpleSinaPlotData data,
      int groupIndex,
      int valueIndex,
      double value,
    );

typedef SimpleSinaPlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleSinaPlotData data,
      int groupIndex,
      int valueIndex,
      double value,
      SimpleSinaPlotStats stats,
      String formattedValue,
    );

class SimpleSinaPlotData {
  final String label;
  final List<double> values;
  final Color? color;

  const SimpleSinaPlotData({
    required this.label,
    required this.values,
    this.color,
  });
}

class SimpleSinaPlotStats {
  final int count;
  final double min;
  final double q1;
  final double median;
  final double mean;
  final double q3;
  final double max;

  const SimpleSinaPlotStats({
    required this.count,
    required this.min,
    required this.q1,
    required this.median,
    required this.mean,
    required this.q3,
    required this.max,
  });
}

/// A Sina-style distribution plot that shows every observation with
/// density-aware lateral spread, plus optional mean and median markers.
class SimpleSinaPlotChart extends StatelessWidget {
  final List<SimpleSinaPlotData> data;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets? padding;
  final List<Color>? palette;
  final Color? dotColor;
  final Color? meanColor;
  final Color? medianColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showMean;
  final bool showMedian;
  final bool showTooltip;
  final bool showActiveDot;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? dotRadius;
  final double dotOpacity;
  final double densitySpreadFactor;
  final double collisionGap;
  final SimpleSinaPlotValueFormatter? valueFormatter;
  final SimpleSinaPlotTapCallback? onPointTap;
  final SimpleSinaPlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleSinaPlotChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding,
    this.palette,
    this.dotColor,
    this.meanColor,
    this.medianColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = false,
    this.showMean = true,
    this.showMedian = true,
    this.showTooltip = true,
    this.showActiveDot = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.dotRadius,
    this.dotOpacity = 0.76,
    this.densitySpreadFactor = 0.82,
    this.collisionGap = 1.05,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(dotRadius == null || dotRadius >= 0),
       assert(dotOpacity >= 0 && dotOpacity <= 1),
       assert(densitySpreadFactor >= 0 && densitySpreadFactor <= 1),
       assert(collisionGap > 0);

  @override
  Widget build(BuildContext context) {
    final visibleData = data
        .where(
          (item) =>
              item.label.trim().isNotEmpty &&
              item.values.any((value) => value.isFinite),
        )
        .toList();
    final stats = visibleData.map(_statsFor).toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final beeswarmData = [
      for (final item in visibleData)
        SimpleBeeswarmData(
          label: item.label,
          values: item.values,
          color: item.color,
        ),
    ];

    final child = SimpleBeeswarmChart(
      data: beeswarmData,
      style: style,
      minValue: minValue,
      maxValue: maxValue,
      height: height,
      padding: padding,
      palette: palette,
      dotColor: dotColor,
      meanColor: meanColor,
      medianColor: medianColor,
      gridColor: gridColor,
      axisColor: axisColor,
      activeColor: activeColor,
      labelStyle: labelStyle,
      valueStyle: valueStyle,
      includeZero: includeZero,
      showGrid: showGrid,
      showLabels: showLabels,
      showValues: showValues,
      showMean: showMean,
      showMedian: showMedian,
      showTooltip: showTooltip,
      showActiveDot: showActiveDot,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
      gridLineCount: gridLineCount,
      dotRadius: dotRadius,
      dotOpacity: dotOpacity,
      collisionGap: collisionGap,
      swarmWidthFactor: densitySpreadFactor,
      valueFormatter: formatter,
      onPointTap: onPointTap == null
          ? null
          : (item, groupIndex, valueIndex, value) {
              onPointTap!(
                visibleData[groupIndex],
                groupIndex,
                valueIndex,
                value,
              );
            },
      tooltipBuilder: tooltipBuilder == null
          ? null
          : (context, item, groupIndex, valueIndex, value, _, formattedValue) {
              return tooltipBuilder!(
                context,
                visibleData[groupIndex],
                groupIndex,
                valueIndex,
                value,
                stats[groupIndex],
                formattedValue,
              );
            },
      emptyBuilder: emptyBuilder,
      excludeFromSemantics: true,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
    );

    return ChartApiSurface(
      semanticLabel: _defaultSemanticLabel(visibleData, stats, formatter),
      accessibility: ChartAccessibilityOptions(
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      ),
      child: child,
    );
  }

  String _defaultSemanticLabel(
    List<SimpleSinaPlotData> visibleData,
    List<SimpleSinaPlotStats> stats,
    SimpleSinaPlotValueFormatter formatter,
  ) {
    if (visibleData.isEmpty) return 'Sina plot chart, no data.';
    final limit = math.min(visibleData.length, 4);
    final summaries = <String>[];
    for (var index = 0; index < limit; index++) {
      final item = visibleData[index];
      final summary = stats[index];
      summaries.add(
        '${item.label} count ${summary.count}, min ${formatter(summary.min)}, '
        'median ${formatter(summary.median)}, max ${formatter(summary.max)}',
      );
    }
    final suffix = visibleData.length > limit
        ? '; and ${visibleData.length - limit} more groups'
        : '';
    final groupLabel = visibleData.length == 1 ? 'group' : 'groups';
    return 'Sina plot chart, ${visibleData.length} $groupLabel. '
        '${summaries.join('; ')}$suffix.';
  }

  static SimpleSinaPlotStats _statsFor(SimpleSinaPlotData item) {
    final values = item.values.where((value) => value.isFinite).toList()
      ..sort();
    final sum = values.fold<double>(0, (total, value) => total + value);
    return SimpleSinaPlotStats(
      count: values.length,
      min: values.first,
      q1: _quantile(values, 0.25),
      median: _quantile(values, 0.5),
      mean: sum / values.length,
      q3: _quantile(values, 0.75),
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
