import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import '../line/simple_line_chart.dart';

/// A compact area chart that uses the same data model as [SimpleLineChart].
class SimpleAreaChart extends StatelessWidget {
  final List<SimpleTrendSeries> series;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? lineColor;
  final Color? fillColor;
  final Color? gridColor;
  final Color? axisColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final bool? smooth;
  final double? strokeWidth;
  final double? dotRadius;
  final double? fillOpacity;
  final int gridLineCount;
  final SimpleTrendValueFormatter? valueFormatter;
  final SimpleTrendPointTapCallback? onPointTap;
  final SimpleTrendTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleAreaChart({
    super.key,
    required this.series,
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 240,
    this.padding = const EdgeInsets.fromLTRB(48, 18, 18, 34),
    this.lineColor,
    this.fillColor,
    this.gridColor,
    this.axisColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = true,
    this.showGrid = true,
    this.showDots = false,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.smooth,
    this.strokeWidth,
    this.dotRadius,
    this.fillOpacity,
    this.gridLineCount = 4,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 750),
    this.animationCurve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSeries = series
        .where((item) => item.points.any((point) => point.value.isFinite))
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return ChartApiSurface(
      semanticLabel: visibleSeries.isEmpty
          ? 'Area chart, no data.'
          : _defaultSemanticLabel(visibleSeries, formatter),
      accessibility: ChartAccessibilityOptions(
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      ),
      child: SimpleLineChart(
        series: series,
        style: style,
        minValue: minValue,
        maxValue: maxValue,
        height: height,
        padding: padding,
        lineColor: lineColor,
        fillColor: fillColor,
        gridColor: gridColor,
        axisColor: axisColor,
        labelStyle: labelStyle,
        valueStyle: valueStyle,
        includeZero: includeZero,
        showGrid: showGrid,
        showDots: showDots,
        showValues: showValues,
        showArea: true,
        showLegend: showLegend,
        showTooltip: showTooltip,
        referenceLines: referenceLines,
        referenceBands: referenceBands,
        smooth: smooth,
        strokeWidth: strokeWidth,
        dotRadius: dotRadius,
        fillOpacity: fillOpacity,
        gridLineCount: gridLineCount,
        valueFormatter: formatter,
        onPointTap: onPointTap,
        tooltipBuilder: tooltipBuilder,
        emptyBuilder: emptyBuilder,
        excludeFromSemantics: true,
        animationDuration: animationDuration,
        animationCurve: animationCurve,
      ),
    );
  }

  String _defaultSemanticLabel(
    List<SimpleTrendSeries> visibleSeries,
    SimpleTrendValueFormatter formatter,
  ) {
    final summaries = visibleSeries
        .take(3)
        .map((item) {
          final name = item.name ?? 'Series ${visibleSeries.indexOf(item) + 1}';
          final finitePoints = item.points
              .where((point) => point.value.isFinite)
              .toList();
          final points = finitePoints
              .take(4)
              .map((point) => '${point.label} ${formatter(point.value)}')
              .join(', ');
          final remaining =
              finitePoints.length - math.min(finitePoints.length, 4);
          final suffix = remaining > 0 ? ', and $remaining more' : '';
          return '$name: $points$suffix';
        })
        .join('; ');
    final remainingSeries =
        visibleSeries.length - math.min(visibleSeries.length, 3);
    final suffix = remainingSeries > 0
        ? '; and $remainingSeries more series'
        : '';
    return 'Area chart, ${visibleSeries.length} series. $summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
