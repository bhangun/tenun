import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../matrix/simple_bubble_matrix_chart.dart';

typedef SimplePunchCardValueFormatter = String Function(double value);

typedef SimplePunchCardCellTapCallback =
    void Function(SimplePunchCardCell cell, int rowIndex, int columnIndex);

typedef SimplePunchCardTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimplePunchCardCell cell,
      int rowIndex,
      int columnIndex,
      String formattedValue,
    );

class SimplePunchCardCell {
  final String xLabel;
  final String yLabel;
  final double value;
  final Color? color;
  final String? label;

  const SimplePunchCardCell({
    required this.xLabel,
    required this.yLabel,
    required this.value,
    this.color,
    this.label,
  });
}

/// A dot-grid chart for comparing activity intensity across two categories.
class SimplePunchCardChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(76, 24, 52, 40);

  final List<String> xLabels;
  final List<String> yLabels;
  final List<SimplePunchCardCell> cells;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? dotColor;
  final Color? lowColor;
  final Color? highColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool useColorScale;
  final bool showGrid;
  final bool showXLabels;
  final bool showYLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveDot;
  final double dotOpacity;
  final double minDotRadius;
  final double maxDotRadiusFactor;
  final SimplePunchCardValueFormatter? valueFormatter;
  final SimplePunchCardCellTapCallback? onCellTap;
  final SimplePunchCardTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimplePunchCardChart({
    super.key,
    this.xLabels = const [],
    this.yLabels = const [],
    required this.cells,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 250,
    this.padding = _defaultPadding,
    this.dotColor,
    this.lowColor,
    this.highColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.useColorScale = true,
    this.showGrid = true,
    this.showXLabels = true,
    this.showYLabels = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveDot = true,
    this.dotOpacity = 0.86,
    this.minDotRadius = 2.5,
    this.maxDotRadiusFactor = 0.38,
    this.valueFormatter,
    this.onCellTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 650),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(dotOpacity >= 0 && dotOpacity <= 1),
       assert(minDotRadius >= 0),
       assert(maxDotRadiusFactor > 0 && maxDotRadiusFactor <= 0.5);

  @override
  Widget build(BuildContext context) {
    final visibleCells = cells
        .where(
          (item) =>
              item.xLabel.trim().isNotEmpty &&
              item.yLabel.trim().isNotEmpty &&
              item.value.isFinite,
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final matrixCells = visibleCells
        .map(
          (item) => SimpleBubbleMatrixCell(
            xLabel: item.xLabel,
            yLabel: item.yLabel,
            value: item.value,
            color: item.color,
            label: item.label,
          ),
        )
        .toList();

    final chart = SimpleBubbleMatrixChart(
      xLabels: xLabels,
      yLabels: yLabels,
      cells: matrixCells,
      style: style,
      minValue: minValue,
      maxValue: maxValue,
      height: height,
      padding: padding,
      bubbleColor: dotColor,
      lowColor: lowColor,
      highColor: highColor,
      gridColor: gridColor,
      activeColor: activeColor,
      labelStyle: labelStyle,
      valueStyle: valueStyle,
      useColorScale: useColorScale,
      showGrid: showGrid,
      showXLabels: showXLabels,
      showYLabels: showYLabels,
      showValues: showValues,
      showLegend: showLegend,
      showTooltip: showTooltip,
      showActiveBubble: showActiveDot,
      bubbleOpacity: dotOpacity,
      minBubbleRadius: minDotRadius,
      maxBubbleRadiusFactor: maxDotRadiusFactor,
      valueFormatter: formatter,
      onCellTap: onCellTap == null
          ? null
          : (cell, rowIndex, columnIndex) {
              onCellTap!(
                _toPunchCell(visibleCells, cell),
                rowIndex,
                columnIndex,
              );
            },
      tooltipBuilder: tooltipBuilder == null
          ? null
          : (context, cell, rowIndex, columnIndex, formattedValue) {
              return tooltipBuilder!(
                context,
                _toPunchCell(visibleCells, cell),
                rowIndex,
                columnIndex,
                formattedValue,
              );
            },
      emptyBuilder: emptyBuilder,
      excludeFromSemantics: true,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
    );

    return ChartApiSurface(
      semanticLabel: _defaultSemanticLabel(visibleCells, formatter),
      accessibility: ChartAccessibilityOptions(
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      ),
      child: chart,
    );
  }

  SimplePunchCardCell _toPunchCell(
    List<SimplePunchCardCell> visibleCells,
    SimpleBubbleMatrixCell cell,
  ) {
    for (final item in visibleCells) {
      if (item.xLabel == cell.xLabel &&
          item.yLabel == cell.yLabel &&
          item.value == cell.value) {
        return item;
      }
    }
    return SimplePunchCardCell(
      xLabel: cell.xLabel,
      yLabel: cell.yLabel,
      value: cell.value,
      color: cell.color,
      label: cell.label,
    );
  }

  String _defaultSemanticLabel(
    List<SimplePunchCardCell> visibleCells,
    SimplePunchCardValueFormatter formatter,
  ) {
    if (visibleCells.isEmpty) return 'Punch card chart, no data.';
    final xCount = xLabels.isNotEmpty
        ? xLabels.length
        : visibleCells.map((item) => item.xLabel).toSet().length;
    final yCount = yLabels.isNotEmpty
        ? yLabels.length
        : visibleCells.map((item) => item.yLabel).toSet().length;
    final summaries = visibleCells
        .take(6)
        .map((item) => '${item.yLabel} ${item.xLabel} ${formatter(item.value)}')
        .join(', ');
    final remaining = visibleCells.length - math.min(visibleCells.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    return 'Punch card chart, $yCount rows and $xCount columns. '
        '$summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
