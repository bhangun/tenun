import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../marimekko/simple_marimekko_chart.dart';

typedef SimpleMosaicPlotValueFormatter = String Function(double value);

typedef SimpleMosaicPlotTapCallback =
    void Function(
      SimpleMosaicPlotCell cell,
      double share,
      int xIndex,
      int yIndex,
    );

typedef SimpleMosaicPlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleMosaicPlotCell cell,
      double share,
      int xIndex,
      int yIndex,
      String formattedValue,
      String formattedShare,
    );

class SimpleMosaicPlotCell {
  final String xLabel;
  final String yLabel;
  final double value;
  final Color? color;
  final String? label;

  const SimpleMosaicPlotCell({
    required this.xLabel,
    required this.yLabel,
    required this.value,
    this.color,
    this.label,
  });
}

/// A categorical mosaic plot for showing size and composition together.
class SimpleMosaicPlotChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 18, 18, 42);

  final List<String> xLabels;
  final List<String> yLabels;
  final List<SimpleMosaicPlotCell> cells;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? cellColor;
  final Color? borderColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showPercentages;
  final bool showCellLabels;
  final bool showXLabels;
  final bool showColumnTotals;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final double columnGap;
  final double cellGap;
  final double cellRadius;
  final SimpleMosaicPlotValueFormatter? valueFormatter;
  final SimpleMosaicPlotValueFormatter? shareFormatter;
  final SimpleMosaicPlotTapCallback? onCellTap;
  final SimpleMosaicPlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleMosaicPlotChart({
    super.key,
    this.xLabels = const [],
    this.yLabels = const [],
    required this.cells,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.cellColor,
    this.borderColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showPercentages = true,
    this.showCellLabels = true,
    this.showXLabels = true,
    this.showColumnTotals = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveCell = true,
    this.columnGap = 5,
    this.cellGap = 2,
    this.cellRadius = 4,
    this.valueFormatter,
    this.shareFormatter,
    this.onCellTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 750),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(columnGap >= 0),
       assert(cellGap >= 0),
       assert(cellRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final visibleCells = cells
        .where(
          (cell) =>
              cell.xLabel.trim().isNotEmpty &&
              cell.yLabel.trim().isNotEmpty &&
              cell.value.isFinite &&
              cell.value >= 0,
        )
        .toList();
    final resolvedXLabels = _resolveLabels(
      preferred: xLabels,
      fallback: visibleCells.map((cell) => cell.xLabel),
    );
    final resolvedYLabels = _resolveLabels(
      preferred: yLabels,
      fallback: visibleCells.map((cell) => cell.yLabel),
    );
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedShareFormatter = shareFormatter ?? _defaultShareFormatter;
    final series = _buildSeries(visibleCells, resolvedXLabels, resolvedYLabels);

    return ChartApiSurface(
      semanticLabel: _defaultSemanticLabel(
        visibleCells,
        resolvedXLabels,
        resolvedYLabels,
        formatter,
      ),
      accessibility: ChartAccessibilityOptions(
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      ),
      child: SimpleMarimekkoChart(
        categories: resolvedXLabels,
        series: series,
        style: style,
        height: height,
        padding: padding,
        palette: palette,
        segmentColor: cellColor,
        borderColor: borderColor,
        gridColor: gridColor,
        activeColor: activeColor,
        labelStyle: labelStyle,
        valueStyle: valueStyle,
        showGrid: showGrid,
        showValues: showValues,
        showPercentages: showPercentages,
        showSegmentLabels: showCellLabels,
        showCategoryLabels: showXLabels,
        showColumnTotals: showColumnTotals,
        showLegend: showLegend,
        showTooltip: showTooltip,
        showActiveSegment: showActiveCell,
        columnGap: columnGap,
        segmentGap: cellGap,
        segmentRadius: cellRadius,
        valueFormatter: formatter,
        shareFormatter: resolvedShareFormatter,
        onSegmentTap: onCellTap == null
            ? null
            : (category, selectedSeries, value, share, xIndex, yIndex) {
                onCellTap!(
                  _cellFor(visibleCells, category, selectedSeries.name, value),
                  share,
                  xIndex,
                  yIndex,
                );
              },
        tooltipBuilder: tooltipBuilder == null
            ? null
            : (
                context,
                category,
                selectedSeries,
                value,
                share,
                xIndex,
                yIndex,
                formattedValue,
                formattedShare,
              ) {
                return tooltipBuilder!(
                  context,
                  _cellFor(visibleCells, category, selectedSeries.name, value),
                  share,
                  xIndex,
                  yIndex,
                  formattedValue,
                  formattedShare,
                );
              },
        emptyBuilder: emptyBuilder,
        excludeFromSemantics: true,
        animationDuration: animationDuration,
        animationCurve: animationCurve,
      ),
    );
  }

  List<SimpleMarimekkoSeries> _buildSeries(
    List<SimpleMosaicPlotCell> visibleCells,
    List<String> resolvedXLabels,
    List<String> resolvedYLabels,
  ) {
    final byYThenX = <String, Map<String, SimpleMosaicPlotCell>>{};
    for (final cell in visibleCells) {
      byYThenX.putIfAbsent(
        cell.yLabel,
        () => <String, SimpleMosaicPlotCell>{},
      )[cell.xLabel] = cell;
    }

    return [
      for (final yLabel in resolvedYLabels)
        SimpleMarimekkoSeries(
          name: yLabel,
          color: byYThenX[yLabel]?.values.firstOrNull?.color,
          values: [
            for (final xLabel in resolvedXLabels)
              byYThenX[yLabel]?[xLabel]?.value ?? 0,
          ],
        ),
    ];
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

  SimpleMosaicPlotCell _cellFor(
    List<SimpleMosaicPlotCell> visibleCells,
    String xLabel,
    String yLabel,
    double value,
  ) {
    for (final cell in visibleCells) {
      if (cell.xLabel == xLabel &&
          cell.yLabel == yLabel &&
          cell.value == value) {
        return cell;
      }
    }
    return SimpleMosaicPlotCell(xLabel: xLabel, yLabel: yLabel, value: value);
  }

  String _defaultSemanticLabel(
    List<SimpleMosaicPlotCell> visibleCells,
    List<String> resolvedXLabels,
    List<String> resolvedYLabels,
    SimpleMosaicPlotValueFormatter formatter,
  ) {
    if (visibleCells.isEmpty ||
        resolvedXLabels.isEmpty ||
        resolvedYLabels.isEmpty) {
      return 'Mosaic plot chart, no data.';
    }
    final summaries = <String>[];
    final limit = math.min(resolvedXLabels.length, 4);
    for (var index = 0; index < limit; index++) {
      final xLabel = resolvedXLabels[index];
      final total = visibleCells
          .where((cell) => cell.xLabel == xLabel)
          .fold<double>(0, (sum, cell) => sum + cell.value);
      summaries.add('$xLabel total ${formatter(total)}');
    }
    final remaining = resolvedXLabels.length - limit;
    final suffix = remaining > 0 ? '; and $remaining more categories' : '';
    return 'Mosaic plot chart, ${resolvedXLabels.length} categories and '
        '${resolvedYLabels.length} groups. ${summaries.join('; ')}$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _defaultShareFormatter(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }
}
