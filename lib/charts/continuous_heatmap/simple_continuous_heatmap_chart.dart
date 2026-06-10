import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../heatmap/simple_heatmap_chart.dart';

typedef SimpleContinuousHeatmapValueFormatter = String Function(double value);

typedef SimpleContinuousHeatmapTapCallback =
    void Function(
      SimpleContinuousHeatmapBin bin,
      int rowIndex,
      int columnIndex,
    );

typedef SimpleContinuousHeatmapTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleContinuousHeatmapBin bin,
      int rowIndex,
      int columnIndex,
      String formattedValue,
      String formattedXRange,
      String formattedYRange,
    );

class SimpleContinuousHeatmapPoint {
  final String? label;
  final double x;
  final double y;
  final double weight;
  final String? group;
  final Color? color;

  const SimpleContinuousHeatmapPoint({
    this.label,
    required this.x,
    required this.y,
    this.weight = 1,
    this.group,
    this.color,
  });
}

class SimpleContinuousHeatmapBin {
  final int xIndex;
  final int yIndex;
  final double xStart;
  final double xEnd;
  final double yStart;
  final double yEnd;
  final double value;
  final int pointCount;
  final List<SimpleContinuousHeatmapPoint> points;
  final String? label;
  final Color? color;

  const SimpleContinuousHeatmapBin({
    required this.xIndex,
    required this.yIndex,
    required this.xStart,
    required this.xEnd,
    required this.yStart,
    required this.yEnd,
    required this.value,
    this.pointCount = 0,
    this.points = const [],
    this.label,
    this.color,
  });

  double get xCenter => (xStart + xEnd) / 2;
  double get yCenter => (yStart + yEnd) / 2;
}

/// A rectangular density grid for continuous x/y observations, operational
/// hotspots, spatial summaries, product telemetry, and learning analytics.
class SimpleContinuousHeatmapChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(70, 24, 52, 42);

  final List<SimpleContinuousHeatmapPoint> points;
  final List<SimpleContinuousHeatmapBin> bins;
  final int xBins;
  final int yBins;
  final SimpleBarChartStyle style;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? lowColor;
  final Color? highColor;
  final Color? emptyColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showXLabels;
  final bool showYLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final double cellGap;
  final double cellRadius;
  final SimpleContinuousHeatmapValueFormatter? valueFormatter;
  final SimpleContinuousHeatmapValueFormatter? rangeFormatter;
  final SimpleContinuousHeatmapTapCallback? onBinTap;
  final SimpleContinuousHeatmapTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleContinuousHeatmapChart({
    super.key,
    this.points = const [],
    this.bins = const [],
    this.xBins = 6,
    this.yBins = 5,
    this.style = SimpleBarChartStyle.elegant,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.lowColor,
    this.highColor,
    this.emptyColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showXLabels = true,
    this.showYLabels = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveCell = true,
    this.cellGap = 3,
    this.cellRadius = 5,
    this.valueFormatter,
    this.rangeFormatter,
    this.onBinTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 650),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(xBins > 0),
       assert(yBins > 0),
       assert(height > 0),
       assert(cellGap >= 0),
       assert(cellRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final axisFormatter = rangeFormatter ?? _defaultRangeValueFormatter;
    final model = _ContinuousHeatmapModel.resolve(
      points: points,
      bins: bins,
      xBins: xBins,
      yBins: yBins,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      rangeFormatter: axisFormatter,
    );

    final chart = SimpleHeatmapChart(
      xLabels: model.xLabels,
      yLabels: model.yLabels,
      cells: model.cells,
      style: style,
      minValue: minValue,
      maxValue: maxValue,
      height: height,
      padding: padding,
      lowColor: lowColor,
      highColor: highColor,
      emptyColor: emptyColor,
      gridColor: gridColor,
      activeColor: activeColor,
      labelStyle: labelStyle,
      valueStyle: valueStyle,
      showGrid: showGrid,
      showXLabels: showXLabels,
      showYLabels: showYLabels,
      showValues: showValues,
      showLegend: showLegend,
      showTooltip: showTooltip,
      showActiveCell: showActiveCell,
      cellGap: cellGap,
      cellRadius: cellRadius,
      valueFormatter: formatter,
      onCellTap: onBinTap == null
          ? null
          : (cell, rowIndex, columnIndex) {
              final bin = model.binAt(rowIndex, columnIndex);
              if (bin != null) {
                onBinTap!(bin, rowIndex, columnIndex);
              }
            },
      tooltipBuilder: tooltipBuilder == null
          ? null
          : (context, cell, rowIndex, columnIndex, formattedValue) {
              final bin = model.binAt(rowIndex, columnIndex);
              if (bin == null) return const SizedBox.shrink();
              return tooltipBuilder!(
                context,
                bin,
                rowIndex,
                columnIndex,
                formattedValue,
                cell.xLabel,
                cell.yLabel,
              );
            },
      emptyBuilder: emptyBuilder,
      excludeFromSemantics: true,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
    );

    return ChartApiSurface(
      semanticLabel: _defaultSemanticLabel(model, formatter),
      accessibility: ChartAccessibilityOptions(
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      ),
      child: chart,
    );
  }

  String _defaultSemanticLabel(
    _ContinuousHeatmapModel model,
    SimpleContinuousHeatmapValueFormatter formatter,
  ) {
    if (model.isEmpty) return 'Continuous heatmap chart, no data.';
    final peak = model.bins.reduce((a, b) => a.value >= b.value ? a : b);
    final xRange = model.xLabelFor(peak.xIndex);
    final yRange = model.yLabelFor(peak.yIndex);
    final pointSummary = peak.pointCount > 0
        ? ' from ${peak.pointCount} points'
        : '';
    return 'Continuous heatmap chart, ${model.yBinCount} rows and '
        '${model.xBinCount} columns. Peak $xRange by $yRange '
        '${formatter(peak.value)}$pointSummary.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _defaultRangeValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    final absolute = value.abs();
    if (absolute >= 10) return value.toStringAsFixed(0);
    if (absolute >= 1) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }
}

class _ContinuousHeatmapModel {
  final List<String> xLabels;
  final List<String> yLabels;
  final List<SimpleHeatmapCell> cells;
  final List<SimpleContinuousHeatmapBin> bins;
  final List<List<SimpleContinuousHeatmapBin?>> matrix;
  final int xBinCount;
  final int yBinCount;

  const _ContinuousHeatmapModel({
    required this.xLabels,
    required this.yLabels,
    required this.cells,
    required this.bins,
    required this.matrix,
    required this.xBinCount,
    required this.yBinCount,
  });

  bool get isEmpty => cells.isEmpty || xLabels.isEmpty || yLabels.isEmpty;

  SimpleContinuousHeatmapBin? binAt(int rowIndex, int columnIndex) {
    if (rowIndex < 0 ||
        columnIndex < 0 ||
        rowIndex >= matrix.length ||
        columnIndex >= matrix[rowIndex].length) {
      return null;
    }
    return matrix[rowIndex][columnIndex];
  }

  String xLabelFor(int xIndex) {
    if (xIndex < 0 || xIndex >= xLabels.length) return '';
    return xLabels[xIndex];
  }

  String yLabelFor(int yIndex) {
    final rowIndex = yBinCount - 1 - yIndex;
    if (rowIndex < 0 || rowIndex >= yLabels.length) return '';
    return yLabels[rowIndex];
  }

  factory _ContinuousHeatmapModel.resolve({
    required List<SimpleContinuousHeatmapPoint> points,
    required List<SimpleContinuousHeatmapBin> bins,
    required int xBins,
    required int yBins,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
    required SimpleContinuousHeatmapValueFormatter rangeFormatter,
  }) {
    final validBins = bins
        .where(
          (bin) =>
              bin.xIndex >= 0 &&
              bin.yIndex >= 0 &&
              bin.xStart.isFinite &&
              bin.xEnd.isFinite &&
              bin.yStart.isFinite &&
              bin.yEnd.isFinite &&
              bin.value.isFinite &&
              bin.pointCount >= 0,
        )
        .toList();
    final validPoints = points
        .where(
          (point) =>
              point.x.isFinite &&
              point.y.isFinite &&
              point.weight.isFinite &&
              point.weight >= 0,
        )
        .toList();

    if (validBins.isNotEmpty) {
      return _fromProvidedBins(
        bins: validBins,
        fallbackXBins: xBins,
        fallbackYBins: yBins,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        rangeFormatter: rangeFormatter,
      );
    }
    if (validPoints.isEmpty) return _empty();

    final xRange = _resolveAxisRange(
      explicitMin: minX,
      explicitMax: maxX,
      values: validPoints.map((point) => point.x),
    );
    final yRange = _resolveAxisRange(
      explicitMin: minY,
      explicitMax: maxY,
      values: validPoints.map((point) => point.y),
    );
    if (xRange == null || yRange == null) return _empty();

    final xStep = xRange.width / xBins;
    final yStep = yRange.width / yBins;
    final xLabels = List.generate(
      xBins,
      (index) => _formatRange(
        xRange.min + xStep * index,
        xRange.min + xStep * (index + 1),
        rangeFormatter,
      ),
    );
    final yLabels = List.generate(yBins, (displayIndex) {
      final index = yBins - 1 - displayIndex;
      return _formatRange(
        yRange.min + yStep * index,
        yRange.min + yStep * (index + 1),
        rangeFormatter,
      );
    });

    final accumulators = <String, _BinAccumulator>{};
    for (final point in validPoints) {
      if (point.x < xRange.min ||
          point.x > xRange.max ||
          point.y < yRange.min ||
          point.y > yRange.max) {
        continue;
      }
      final xIndex = _binIndex(point.x, xRange.min, xStep, xBins);
      final yIndex = _binIndex(point.y, yRange.min, yStep, yBins);
      final key = _key(xIndex, yIndex);
      final accumulator = accumulators.putIfAbsent(
        key,
        () => _BinAccumulator(
          xIndex: xIndex,
          yIndex: yIndex,
          xStart: xRange.min + xStep * xIndex,
          xEnd: xRange.min + xStep * (xIndex + 1),
          yStart: yRange.min + yStep * yIndex,
          yEnd: yRange.min + yStep * (yIndex + 1),
        ),
      );
      accumulator.add(point);
    }

    final resolvedBins = accumulators.values
        .map((accumulator) => accumulator.toBin())
        .where((bin) => bin.value.isFinite)
        .toList();

    return _build(
      xLabels: xLabels,
      yLabels: yLabels,
      bins: resolvedBins,
      xBinCount: xBins,
      yBinCount: yBins,
    );
  }

  static _ContinuousHeatmapModel _fromProvidedBins({
    required List<SimpleContinuousHeatmapBin> bins,
    required int fallbackXBins,
    required int fallbackYBins,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
    required SimpleContinuousHeatmapValueFormatter rangeFormatter,
  }) {
    final xBinCount = math.max(
      fallbackXBins,
      bins.map((bin) => bin.xIndex).reduce(math.max) + 1,
    );
    final yBinCount = math.max(
      fallbackYBins,
      bins.map((bin) => bin.yIndex).reduce(math.max) + 1,
    );
    final xRange = _resolveAxisRange(
      explicitMin: minX,
      explicitMax: maxX,
      values: bins.expand((bin) => [bin.xStart, bin.xEnd]),
    );
    final yRange = _resolveAxisRange(
      explicitMin: minY,
      explicitMax: maxY,
      values: bins.expand((bin) => [bin.yStart, bin.yEnd]),
    );
    if (xRange == null || yRange == null) return _empty();

    final fallbackXStep = xRange.width / xBinCount;
    final fallbackYStep = yRange.width / yBinCount;
    final xRanges = List.generate(
      xBinCount,
      (index) => _Range(
        xRange.min + fallbackXStep * index,
        xRange.min + fallbackXStep * (index + 1),
      ),
    );
    final yRanges = List.generate(
      yBinCount,
      (index) => _Range(
        yRange.min + fallbackYStep * index,
        yRange.min + fallbackYStep * (index + 1),
      ),
    );
    final merged = <String, _ProvidedBinAccumulator>{};
    for (final bin in bins) {
      final xStart = math.min(bin.xStart, bin.xEnd);
      final xEnd = math.max(bin.xStart, bin.xEnd);
      final yStart = math.min(bin.yStart, bin.yEnd);
      final yEnd = math.max(bin.yStart, bin.yEnd);
      xRanges[bin.xIndex] = _Range(xStart, xEnd);
      yRanges[bin.yIndex] = _Range(yStart, yEnd);
      final key = _key(bin.xIndex, bin.yIndex);
      merged
          .putIfAbsent(
            key,
            () => _ProvidedBinAccumulator(
              xIndex: bin.xIndex,
              yIndex: bin.yIndex,
              xStart: xStart,
              xEnd: xEnd,
              yStart: yStart,
              yEnd: yEnd,
            ),
          )
          .add(bin);
    }

    final xLabels = xRanges
        .map((range) => _formatRange(range.min, range.max, rangeFormatter))
        .toList();
    final yLabels = List.generate(yBinCount, (displayIndex) {
      final index = yBinCount - 1 - displayIndex;
      final range = yRanges[index];
      return _formatRange(range.min, range.max, rangeFormatter);
    });
    final resolvedBins = merged.values
        .map((accumulator) => accumulator.toBin())
        .toList();

    return _build(
      xLabels: xLabels,
      yLabels: yLabels,
      bins: resolvedBins,
      xBinCount: xBinCount,
      yBinCount: yBinCount,
    );
  }

  static _ContinuousHeatmapModel _build({
    required List<String> xLabels,
    required List<String> yLabels,
    required List<SimpleContinuousHeatmapBin> bins,
    required int xBinCount,
    required int yBinCount,
  }) {
    final matrix = List.generate(
      yBinCount,
      (_) => List<SimpleContinuousHeatmapBin?>.filled(xBinCount, null),
    );
    final cells = <SimpleHeatmapCell>[];
    for (final bin in bins) {
      if (bin.xIndex < 0 ||
          bin.xIndex >= xBinCount ||
          bin.yIndex < 0 ||
          bin.yIndex >= yBinCount ||
          !bin.value.isFinite) {
        continue;
      }
      final rowIndex = yBinCount - 1 - bin.yIndex;
      final columnIndex = bin.xIndex;
      matrix[rowIndex][columnIndex] = bin;
      cells.add(
        SimpleHeatmapCell(
          xLabel: xLabels[columnIndex],
          yLabel: yLabels[rowIndex],
          value: bin.value,
          color: bin.color,
          label: bin.label,
        ),
      );
    }
    return _ContinuousHeatmapModel(
      xLabels: xLabels,
      yLabels: yLabels,
      cells: cells,
      bins: bins,
      matrix: matrix,
      xBinCount: xBinCount,
      yBinCount: yBinCount,
    );
  }

  static _ContinuousHeatmapModel _empty() {
    return const _ContinuousHeatmapModel(
      xLabels: [],
      yLabels: [],
      cells: [],
      bins: [],
      matrix: [],
      xBinCount: 0,
      yBinCount: 0,
    );
  }

  static int _binIndex(double value, double lower, double step, int count) {
    if (step <= 0) return 0;
    final raw = ((value - lower) / step).floor();
    return raw.clamp(0, count - 1).toInt();
  }

  static _Range? _resolveAxisRange({
    required double? explicitMin,
    required double? explicitMax,
    required Iterable<double> values,
  }) {
    final hasExplicitMin = explicitMin?.isFinite == true;
    final hasExplicitMax = explicitMax?.isFinite == true;
    final finiteValues = values.where((value) => value.isFinite).toList();
    var lower = hasExplicitMin ? explicitMin! : double.infinity;
    var upper = hasExplicitMax ? explicitMax! : double.negativeInfinity;
    for (final value in finiteValues) {
      if (!hasExplicitMin) lower = math.min(lower, value);
      if (!hasExplicitMax) upper = math.max(upper, value);
    }
    if (!lower.isFinite || !upper.isFinite) return null;
    if (lower > upper) {
      final previousLower = lower;
      lower = upper;
      upper = previousLower;
    }
    if (lower == upper) {
      final pad = lower == 0 ? 1.0 : lower.abs() * 0.2;
      lower -= pad;
      upper += pad;
    }
    return _Range(lower, upper);
  }

  static String _formatRange(
    double start,
    double end,
    SimpleContinuousHeatmapValueFormatter formatter,
  ) {
    if (start == end) return formatter(start);
    return '${formatter(start)}-${formatter(end)}';
  }

  static String _key(int xIndex, int yIndex) => '$xIndex:$yIndex';
}

class _Range {
  final double min;
  final double max;

  const _Range(this.min, this.max);

  double get width => math.max(0.000001, max - min);
}

class _BinAccumulator {
  final int xIndex;
  final int yIndex;
  final double xStart;
  final double xEnd;
  final double yStart;
  final double yEnd;
  final List<SimpleContinuousHeatmapPoint> points = [];
  double value = 0;
  Color? color;

  _BinAccumulator({
    required this.xIndex,
    required this.yIndex,
    required this.xStart,
    required this.xEnd,
    required this.yStart,
    required this.yEnd,
  });

  void add(SimpleContinuousHeatmapPoint point) {
    points.add(point);
    value += point.weight;
    color ??= point.color;
  }

  SimpleContinuousHeatmapBin toBin() {
    return SimpleContinuousHeatmapBin(
      xIndex: xIndex,
      yIndex: yIndex,
      xStart: xStart,
      xEnd: xEnd,
      yStart: yStart,
      yEnd: yEnd,
      value: value,
      pointCount: points.length,
      points: List.unmodifiable(points),
      label: points.isEmpty ? null : points.first.label,
      color: color,
    );
  }
}

class _ProvidedBinAccumulator {
  final int xIndex;
  final int yIndex;
  final double xStart;
  final double xEnd;
  final double yStart;
  final double yEnd;
  final List<SimpleContinuousHeatmapPoint> points = [];
  double value = 0;
  int pointCount = 0;
  String? label;
  Color? color;

  _ProvidedBinAccumulator({
    required this.xIndex,
    required this.yIndex,
    required this.xStart,
    required this.xEnd,
    required this.yStart,
    required this.yEnd,
  });

  void add(SimpleContinuousHeatmapBin bin) {
    value += bin.value;
    pointCount += bin.pointCount;
    points.addAll(bin.points);
    label ??= bin.label;
    color ??= bin.color;
  }

  SimpleContinuousHeatmapBin toBin() {
    return SimpleContinuousHeatmapBin(
      xIndex: xIndex,
      yIndex: yIndex,
      xStart: xStart,
      xEnd: xEnd,
      yStart: yStart,
      yEnd: yEnd,
      value: value,
      pointCount: pointCount,
      points: List.unmodifiable(points),
      label: label,
      color: color,
    );
  }
}
