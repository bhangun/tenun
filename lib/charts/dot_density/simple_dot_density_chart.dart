import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../pictogram/simple_pictogram_chart.dart';

typedef SimpleDotDensityValueFormatter = String Function(double value);

typedef SimpleDotDensityTapCallback =
    void Function(
      SimpleDotDensityChartData data,
      int index,
      double share,
      int dotCount,
    );

typedef SimpleDotDensityTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleDotDensityChartData data,
      int index,
      String formattedValue,
      String formattedShare,
      int dotCount,
    );

enum SimpleDotDensityFillDirection { bottomToTop, leftToRight, rightToLeft }

class SimpleDotDensityChartData {
  final String label;
  final double value;
  final Color? color;

  const SimpleDotDensityChartData({
    required this.label,
    required this.value,
    this.color,
  });
}

/// A compact unit-dot density chart for part-to-whole, count, capacity,
/// population, completion, and survey composition stories.
class SimpleDotDensityChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 18, 18, 18);

  final List<SimpleDotDensityChartData> data;
  final SimpleBarChartStyle style;
  final double? totalValue;
  final int rows;
  final int columns;
  final double height;
  final EdgeInsets padding;
  final SimpleDotDensityFillDirection fillDirection;
  final List<Color>? palette;
  final Color? dotColor;
  final Color? emptyDotColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLegend;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveDots;
  final bool showEmptyDots;
  final double dotGap;
  final double dotScale;
  final SimpleDotDensityValueFormatter? valueFormatter;
  final SimpleDotDensityValueFormatter? percentFormatter;
  final SimpleDotDensityTapCallback? onDotTap;
  final SimpleDotDensityTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleDotDensityChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.totalValue,
    this.rows = 5,
    this.columns = 10,
    this.height = 260,
    this.padding = _defaultPadding,
    this.fillDirection = SimpleDotDensityFillDirection.bottomToTop,
    this.palette,
    this.dotColor,
    this.emptyDotColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLegend = true,
    this.showValues = true,
    this.showTooltip = true,
    this.showActiveDots = true,
    this.showEmptyDots = true,
    this.dotGap = 5,
    this.dotScale = 0.7,
    this.valueFormatter,
    this.percentFormatter,
    this.onDotTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(rows > 0),
       assert(columns > 0),
       assert(totalValue == null || totalValue > 0),
       assert(dotGap >= 0),
       assert(dotScale > 0 && dotScale <= 1);

  @override
  Widget build(BuildContext context) {
    final visibleData = data
        .where((item) => item.value.isFinite && item.value >= 0)
        .toList();
    final dataTotal = visibleData.fold<double>(
      0,
      (current, item) => current + item.value,
    );
    final resolvedTotal = math.max(totalValue ?? dataTotal, dataTotal);
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedPercentFormatter =
        percentFormatter ?? _defaultPercentFormatter;

    final pictogramData = visibleData
        .map(
          (item) => SimplePictogramChartData(
            label: item.label,
            value: item.value,
            color: item.color,
          ),
        )
        .toList();

    return ChartApiSurface(
      semanticLabel: _defaultSemanticLabel(
        visibleData,
        resolvedTotal,
        formatter,
        resolvedPercentFormatter,
      ),
      accessibility: ChartAccessibilityOptions(
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      ),
      child: SimplePictogramChart(
        data: pictogramData,
        style: style,
        totalValue: totalValue,
        rows: rows,
        columns: columns,
        height: height,
        padding: padding,
        symbol: SimplePictogramSymbol.circle,
        fillDirection: _mapFillDirection(fillDirection),
        palette: palette,
        symbolColor: dotColor,
        emptyColor: emptyDotColor,
        activeColor: activeColor,
        labelStyle: labelStyle,
        valueStyle: valueStyle,
        showLegend: showLegend,
        showValues: showValues,
        showTooltip: showTooltip,
        showActiveUnits: showActiveDots,
        showEmptyUnits: showEmptyDots,
        unitGap: dotGap,
        symbolScale: dotScale,
        valueFormatter: formatter,
        percentFormatter: resolvedPercentFormatter,
        onUnitTap: onDotTap == null
            ? null
            : (item, index, share, dotCount) {
                onDotTap!(_toDotData(item), index, share, dotCount);
              },
        tooltipBuilder: tooltipBuilder == null
            ? null
            : (context, item, index, formattedValue, formattedShare, dotCount) {
                return tooltipBuilder!(
                  context,
                  _toDotData(item),
                  index,
                  formattedValue,
                  formattedShare,
                  dotCount,
                );
              },
        emptyBuilder: emptyBuilder,
        excludeFromSemantics: true,
        animationDuration: animationDuration,
        animationCurve: animationCurve,
      ),
    );
  }

  String _defaultSemanticLabel(
    List<SimpleDotDensityChartData> visibleData,
    double total,
    SimpleDotDensityValueFormatter formatter,
    SimpleDotDensityValueFormatter resolvedPercentFormatter,
  ) {
    if (visibleData.isEmpty || total <= 0) {
      return 'Dot density chart, no data.';
    }
    final summaries = visibleData
        .take(6)
        .map((item) {
          final share = total <= 0 ? 0.0 : item.value / total;
          return '${item.label} ${formatter(item.value)}, '
              '${resolvedPercentFormatter(share)}';
        })
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'category' : 'categories';
    return 'Dot density chart, ${visibleData.length} $countLabel. '
        '$summaries$suffix.';
  }

  static SimplePictogramFillDirection _mapFillDirection(
    SimpleDotDensityFillDirection direction,
  ) {
    switch (direction) {
      case SimpleDotDensityFillDirection.bottomToTop:
        return SimplePictogramFillDirection.bottomToTop;
      case SimpleDotDensityFillDirection.leftToRight:
        return SimplePictogramFillDirection.leftToRight;
      case SimpleDotDensityFillDirection.rightToLeft:
        return SimplePictogramFillDirection.rightToLeft;
    }
  }

  static SimpleDotDensityChartData _toDotData(SimplePictogramChartData item) {
    return SimpleDotDensityChartData(
      label: item.label,
      value: item.value,
      color: item.color,
    );
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) {
    final percent = value * 100;
    if (percent == percent.roundToDouble()) return '${percent.toInt()}%';
    return '${percent.toStringAsFixed(1)}%';
  }
}
