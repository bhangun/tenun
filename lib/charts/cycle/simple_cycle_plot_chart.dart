import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import '../line/simple_line_chart.dart';

typedef SimpleCyclePlotValueFormatter = String Function(double value);

typedef SimpleCyclePlotTapCallback =
    void Function(
      String cycleLabel,
      List<SimpleCyclePlotTooltipItem> items,
      int cycleIndex,
    );

typedef SimpleCyclePlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      String cycleLabel,
      List<SimpleCyclePlotTooltipItem> items,
    );

class SimpleCyclePlotPoint {
  final String periodLabel;
  final String cycleLabel;
  final double value;

  const SimpleCyclePlotPoint({
    required this.periodLabel,
    required this.cycleLabel,
    required this.value,
  });
}

class SimpleCyclePlotTooltipItem {
  final String periodLabel;
  final double value;
  final Color color;

  const SimpleCyclePlotTooltipItem({
    required this.periodLabel,
    required this.value,
    required this.color,
  });
}

/// A compact seasonality chart for comparing repeated periods across cycles.
class SimpleCyclePlotChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 18, 38);

  final List<SimpleCyclePlotPoint> points;
  final List<String> periodLabels;
  final List<String> cycleLabels;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? lineColor;
  final Color? averageLineColor;
  final Color? fillColor;
  final Color? gridColor;
  final Color? axisColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final bool showLegend;
  final bool showTooltip;
  final bool showAverageLine;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final bool? smooth;
  final double? strokeWidth;
  final double? dotRadius;
  final double? fillOpacity;
  final int gridLineCount;
  final String averageLabel;
  final SimpleCyclePlotValueFormatter? valueFormatter;
  final SimpleCyclePlotTapCallback? onPointTap;
  final SimpleCyclePlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleCyclePlotChart({
    super.key,
    required this.points,
    this.periodLabels = const [],
    this.cycleLabels = const [],
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 250,
    this.padding = _defaultPadding,
    this.palette,
    this.lineColor,
    this.averageLineColor,
    this.fillColor,
    this.gridColor,
    this.axisColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showDots = true,
    this.showValues = false,
    this.showArea = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showAverageLine = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.smooth = false,
    this.strokeWidth,
    this.dotRadius,
    this.fillOpacity,
    this.gridLineCount = 4,
    this.averageLabel = 'Avg',
    this.valueFormatter,
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
    final visiblePoints = points
        .where(
          (point) =>
              point.periodLabel.trim().isNotEmpty &&
              point.cycleLabel.trim().isNotEmpty &&
              point.value.isFinite,
        )
        .toList();
    final periods = _resolveLabels(
      preferred: periodLabels,
      fallback: visiblePoints.map((point) => point.periodLabel),
    );
    final cycles = _resolveLabels(
      preferred: cycleLabels,
      fallback: visiblePoints.map((point) => point.cycleLabel),
    );
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedPalette = _resolvePalette(context);
    final series = _buildSeries(
      visiblePoints,
      periods,
      cycles,
      resolvedPalette,
    );
    final references = _referenceLines(visiblePoints, context);

    return ChartApiSurface(
      semanticLabel: _defaultSemanticLabel(
        visiblePoints,
        periods,
        cycles,
        formatter,
      ),
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
        showArea: showArea,
        showLegend: showLegend,
        showTooltip: showTooltip,
        referenceLines: references,
        referenceBands: referenceBands,
        smooth: smooth,
        strokeWidth: strokeWidth,
        dotRadius: dotRadius,
        fillOpacity: fillOpacity,
        gridLineCount: gridLineCount,
        valueFormatter: formatter,
        onPointTap: onPointTap == null
            ? null
            : (label, items, index) {
                onPointTap!(label, _toCycleItems(items), index);
              },
        tooltipBuilder: tooltipBuilder == null
            ? null
            : (context, label, items) {
                return tooltipBuilder!(context, label, _toCycleItems(items));
              },
        emptyBuilder: emptyBuilder,
        excludeFromSemantics: true,
        animationDuration: animationDuration,
        animationCurve: animationCurve,
      ),
    );
  }

  List<SimpleTrendSeries> _buildSeries(
    List<SimpleCyclePlotPoint> visiblePoints,
    List<String> periods,
    List<String> cycles,
    List<Color> resolvedPalette,
  ) {
    final byPeriodCycle = <String, Map<String, SimpleCyclePlotPoint>>{};
    for (final point in visiblePoints) {
      byPeriodCycle.putIfAbsent(
        point.periodLabel,
        () => <String, SimpleCyclePlotPoint>{},
      )[point.cycleLabel] = point;
    }

    final series = <SimpleTrendSeries>[];
    for (var periodIndex = 0; periodIndex < periods.length; periodIndex++) {
      final period = periods[periodIndex];
      final pointByCycle = byPeriodCycle[period] ?? const {};
      final trendPoints = <SimpleTrendPoint>[];
      var hasFiniteValue = false;
      for (final cycle in cycles) {
        final value = pointByCycle[cycle]?.value ?? double.nan;
        hasFiniteValue = hasFiniteValue || value.isFinite;
        trendPoints.add(SimpleTrendPoint(label: cycle, value: value));
      }
      if (!hasFiniteValue) continue;
      series.add(
        SimpleTrendSeries(
          name: period,
          color: resolvedPalette[periodIndex % resolvedPalette.length],
          points: trendPoints,
        ),
      );
    }
    return series;
  }

  List<String> _resolveLabels({
    required List<String> preferred,
    required Iterable<String> fallback,
  }) {
    final labels = <String>[];
    for (final label in preferred.followedBy(fallback)) {
      final trimmed = label.trim();
      if (trimmed.isEmpty || labels.contains(trimmed)) continue;
      labels.add(trimmed);
    }
    return labels;
  }

  List<Color> _resolvePalette(BuildContext context) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    if (lineColor != null) {
      return [
        lineColor!,
        ..._defaultPalette(style, Theme.of(context).colorScheme).skip(1),
      ];
    }
    return _defaultPalette(style, Theme.of(context).colorScheme);
  }

  List<SimpleChartReferenceLine> _referenceLines(
    List<SimpleCyclePlotPoint> visiblePoints,
    BuildContext context,
  ) {
    if (!showAverageLine || visiblePoints.isEmpty) return referenceLines;
    final average =
        visiblePoints.fold<double>(0, (sum, point) => sum + point.value) /
        visiblePoints.length;
    return [
      ...referenceLines,
      SimpleChartReferenceLine(
        value: average,
        label: averageLabel,
        color: averageLineColor ?? Theme.of(context).colorScheme.secondary,
        lineStyle: SimpleChartReferenceLineStyle.dashed,
      ),
    ];
  }

  List<SimpleCyclePlotTooltipItem> _toCycleItems(
    List<SimpleTrendTooltipItem> items,
  ) {
    return [
      for (final item in items)
        SimpleCyclePlotTooltipItem(
          periodLabel: item.seriesName,
          value: item.value,
          color: item.color,
        ),
    ];
  }

  String _defaultSemanticLabel(
    List<SimpleCyclePlotPoint> visiblePoints,
    List<String> periods,
    List<String> cycles,
    SimpleCyclePlotValueFormatter formatter,
  ) {
    if (visiblePoints.isEmpty || periods.isEmpty || cycles.isEmpty) {
      return 'Cycle plot chart, no data.';
    }
    final summaries = periods
        .take(4)
        .map((period) {
          final values = visiblePoints
              .where((point) => point.periodLabel == period)
              .toList();
          if (values.isEmpty) return '$period no values';
          final average =
              values.fold<double>(0, (sum, point) => sum + point.value) /
              values.length;
          return '$period average ${formatter(average)}';
        })
        .join(', ');
    final remaining = periods.length - math.min(periods.length, 4);
    final suffix = remaining > 0 ? ', and $remaining more periods' : '';
    return 'Cycle plot chart, ${periods.length} periods across '
        '${cycles.length} cycles. $summaries$suffix.';
  }

  List<Color> _defaultPalette(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return const [
          Color(0xFF2563EB),
          Color(0xFF14B8A6),
          Color(0xFFF97316),
          Color(0xFF7C3AED),
          Color(0xFFDB2777),
        ];
      case SimpleTrendChartStyle.professional:
        return const [
          Color(0xFF0F766E),
          Color(0xFF475569),
          Color(0xFFB45309),
          Color(0xFF334155),
          Color(0xFF1D4ED8),
        ];
      case SimpleTrendChartStyle.education:
        return const [
          Color(0xFF22C55E),
          Color(0xFF3B82F6),
          Color(0xFFF59E0B),
          Color(0xFFEC4899),
          Color(0xFF8B5CF6),
        ];
      case SimpleTrendChartStyle.trendy:
        return const [
          Color(0xFF8B5CF6),
          Color(0xFF06B6D4),
          Color(0xFFF43F5E),
          Color(0xFF84CC16),
          Color(0xFFF97316),
        ];
      case SimpleTrendChartStyle.elegant:
        return [
          colorScheme.primary,
          const Color(0xFF0D9488),
          const Color(0xFF7C3AED),
          const Color(0xFFBE123C),
          const Color(0xFFB45309),
        ];
    }
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
