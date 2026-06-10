import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import '../line/simple_line_chart.dart';

typedef SimpleFrequencyPolygonValueFormatter = String Function(double value);

typedef SimpleFrequencyPolygonTapCallback =
    void Function(
      String binLabel,
      List<SimpleFrequencyPolygonTooltipItem> items,
      int binIndex,
    );

typedef SimpleFrequencyPolygonTooltipBuilder =
    Widget Function(
      BuildContext context,
      String binLabel,
      List<SimpleFrequencyPolygonTooltipItem> items,
    );

enum SimpleFrequencyPolygonScale { count, percent }

class SimpleFrequencyPolygonBin {
  final double start;
  final double end;
  final int count;
  final String? label;

  const SimpleFrequencyPolygonBin({
    required this.start,
    required this.end,
    required this.count,
    this.label,
  });

  double get midpoint => (start + end) / 2;
}

class SimpleFrequencyPolygonSeries {
  final String name;
  final List<double> values;
  final List<SimpleFrequencyPolygonBin> bins;
  final Color? color;
  final SimpleTrendLineStyle lineStyle;

  const SimpleFrequencyPolygonSeries({
    required this.name,
    this.values = const [],
    this.bins = const [],
    this.color,
    this.lineStyle = SimpleTrendLineStyle.solid,
  });
}

class SimpleFrequencyPolygonTooltipItem {
  final String seriesName;
  final int count;
  final double value;
  final Color color;

  const SimpleFrequencyPolygonTooltipItem({
    required this.seriesName,
    required this.count,
    required this.value,
    required this.color,
  });
}

/// A line-based distribution chart that connects frequency counts per bin.
class SimpleFrequencyPolygonChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(48, 18, 18, 42);

  final List<double> values;
  final List<SimpleFrequencyPolygonSeries> series;
  final int binCount;
  final SimpleFrequencyPolygonScale scale;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double? minFrequency;
  final double? maxFrequency;
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
  final bool showArea;
  final bool showLegend;
  final bool showTooltip;
  final bool? smooth;
  final double? strokeWidth;
  final double? dotRadius;
  final double? fillOpacity;
  final int gridLineCount;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final SimpleFrequencyPolygonValueFormatter? valueFormatter;
  final SimpleFrequencyPolygonValueFormatter? frequencyFormatter;
  final SimpleFrequencyPolygonTapCallback? onBinTap;
  final SimpleFrequencyPolygonTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleFrequencyPolygonChart({
    super.key,
    this.values = const [],
    this.series = const [],
    this.binCount = 8,
    this.scale = SimpleFrequencyPolygonScale.count,
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.minFrequency,
    this.maxFrequency,
    this.height = 250,
    this.padding = _defaultPadding,
    this.lineColor,
    this.fillColor,
    this.gridColor,
    this.axisColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = true,
    this.showGrid = true,
    this.showDots = true,
    this.showValues = false,
    this.showArea = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.smooth = false,
    this.strokeWidth,
    this.dotRadius,
    this.fillOpacity,
    this.gridLineCount = 4,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.valueFormatter,
    this.frequencyFormatter,
    this.onBinTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(binCount > 0),
       assert(height > 0),
       assert(gridLineCount >= 2),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(dotRadius == null || dotRadius >= 0),
       assert(fillOpacity == null || (fillOpacity >= 0 && fillOpacity <= 1));

  @override
  Widget build(BuildContext context) {
    final dataFormatter = valueFormatter ?? _defaultValueFormatter;
    final yFormatter = frequencyFormatter ?? _defaultFrequencyFormatter;
    final model = _FrequencyPolygonModel.resolve(
      values: values,
      series: series,
      binCount: binCount,
      scale: scale,
      minValue: minValue,
      maxValue: maxValue,
      valueFormatter: dataFormatter,
    );

    return ChartApiSurface(
      semanticLabel: _defaultSemanticLabel(model, dataFormatter, yFormatter),
      accessibility: ChartAccessibilityOptions(
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      ),
      child: SimpleLineChart(
        series: model.trendSeries,
        style: style,
        minValue: minFrequency,
        maxValue: maxFrequency,
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
        referenceLines: referenceLines,
        referenceBands: referenceBands,
        smooth: smooth,
        strokeWidth: strokeWidth,
        dotRadius: dotRadius,
        fillOpacity: fillOpacity,
        gridLineCount: gridLineCount,
        valueFormatter: yFormatter,
        onPointTap: onBinTap == null
            ? null
            : (label, items, index) {
                onBinTap!(label, model.itemsFor(index, items), index);
              },
        tooltipBuilder: tooltipBuilder == null
            ? null
            : (context, label, items) {
                final index = model.indexForLabel(label);
                return tooltipBuilder!(
                  context,
                  label,
                  model.itemsFor(index, items),
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
    _FrequencyPolygonModel model,
    SimpleFrequencyPolygonValueFormatter dataFormatter,
    SimpleFrequencyPolygonValueFormatter yFormatter,
  ) {
    if (model.trendSeries.isEmpty || model.labels.isEmpty) {
      return 'Frequency polygon chart, no data.';
    }
    final summaries = model.sources
        .take(3)
        .map((source) {
          final peak = source.bins.reduce(
            (a, b) => source.scaledValue(a) >= source.scaledValue(b) ? a : b,
          );
          return '${source.name} peak ${_formatRange(peak, dataFormatter)} '
              '${yFormatter(source.scaledValue(peak))}';
        })
        .join('; ');
    final remaining = model.sources.length - math.min(model.sources.length, 3);
    final suffix = remaining > 0 ? '; and $remaining more series' : '';
    return 'Frequency polygon chart, ${model.sources.length} series and '
        '${model.labels.length} bins. $summaries$suffix.';
  }

  static String _formatRange(
    SimpleFrequencyPolygonBin bin,
    SimpleFrequencyPolygonValueFormatter formatter,
  ) {
    return bin.label ?? '${formatter(bin.start)}-${formatter(bin.end)}';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _defaultFrequencyFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _FrequencyPolygonModel {
  final List<String> labels;
  final List<_FrequencyPolygonSource> sources;
  final List<SimpleTrendSeries> trendSeries;

  const _FrequencyPolygonModel({
    required this.labels,
    required this.sources,
    required this.trendSeries,
  });

  static _FrequencyPolygonModel resolve({
    required List<double> values,
    required List<SimpleFrequencyPolygonSeries> series,
    required int binCount,
    required SimpleFrequencyPolygonScale scale,
    required double? minValue,
    required double? maxValue,
    required SimpleFrequencyPolygonValueFormatter valueFormatter,
  }) {
    final inputSeries =
        <SimpleFrequencyPolygonSeries>[
          if (values.any((value) => value.isFinite))
            SimpleFrequencyPolygonSeries(name: 'Frequency', values: values),
          ...series,
        ].where((item) {
          final hasValues = item.values.any((value) => value.isFinite);
          final hasBins = item.bins.any(
            (bin) =>
                bin.start.isFinite &&
                bin.end.isFinite &&
                bin.start != bin.end &&
                bin.count >= 0,
          );
          return item.name.trim().isNotEmpty && (hasValues || hasBins);
        }).toList();
    if (inputSeries.isEmpty) {
      return const _FrequencyPolygonModel(
        labels: [],
        sources: [],
        trendSeries: [],
      );
    }

    final range = _resolveRange(inputSeries, minValue, maxValue);
    final sources = <_FrequencyPolygonSource>[];
    for (final item in inputSeries) {
      final bins = item.bins.isNotEmpty
          ? _normalizeBins(item.bins)
          : _binsForValues(item.values, binCount, range.min, range.max);
      if (bins.isEmpty) continue;
      sources.add(_FrequencyPolygonSource(item, bins, scale));
    }
    if (sources.isEmpty) {
      return const _FrequencyPolygonModel(
        labels: [],
        sources: [],
        trendSeries: [],
      );
    }

    final labels = sources.first.bins
        .map((bin) => _formatRange(bin, valueFormatter))
        .toList();
    final trendSeries = <SimpleTrendSeries>[];
    for (final source in sources) {
      trendSeries.add(
        SimpleTrendSeries(
          name: source.name,
          color: source.color,
          lineStyle: source.lineStyle,
          points: [
            for (var index = 0; index < labels.length; index++)
              SimpleTrendPoint(
                label: labels[index],
                value: index < source.bins.length
                    ? source.scaledValue(source.bins[index])
                    : double.nan,
              ),
          ],
        ),
      );
    }

    return _FrequencyPolygonModel(
      labels: labels,
      sources: sources,
      trendSeries: trendSeries,
    );
  }

  int indexForLabel(String label) {
    final index = labels.indexOf(label);
    return index < 0 ? 0 : index;
  }

  List<SimpleFrequencyPolygonTooltipItem> itemsFor(
    int binIndex,
    List<SimpleTrendTooltipItem> fallbackItems,
  ) {
    if (binIndex < 0) return const [];
    final items = <SimpleFrequencyPolygonTooltipItem>[];
    for (var index = 0; index < sources.length; index++) {
      final source = sources[index];
      if (binIndex >= source.bins.length) continue;
      final bin = source.bins[binIndex];
      final fallback = index < fallbackItems.length
          ? fallbackItems[index]
          : null;
      items.add(
        SimpleFrequencyPolygonTooltipItem(
          seriesName: source.name,
          count: bin.count,
          value: source.scaledValue(bin),
          color: fallback?.color ?? source.color ?? Colors.blue,
        ),
      );
    }
    return items;
  }

  static _FrequencyPolygonRange _resolveRange(
    List<SimpleFrequencyPolygonSeries> inputSeries,
    double? minValue,
    double? maxValue,
  ) {
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (final item in inputSeries) {
      for (final value in item.values) {
        if (!value.isFinite) continue;
        min = math.min(min, value);
        max = math.max(max, value);
      }
      for (final bin in item.bins) {
        if (!bin.start.isFinite || !bin.end.isFinite) continue;
        min = math.min(min, math.min(bin.start, bin.end));
        max = math.max(max, math.max(bin.start, bin.end));
      }
    }
    if (minValue != null && minValue.isFinite) min = minValue;
    if (maxValue != null && maxValue.isFinite) max = maxValue;
    if (!min.isFinite || !max.isFinite) {
      return const _FrequencyPolygonRange(0, 1);
    }
    if (min > max) {
      final swap = min;
      min = max;
      max = swap;
    }
    if (min == max) {
      min -= 0.5;
      max += 0.5;
    }
    return _FrequencyPolygonRange(min, max);
  }

  static List<SimpleFrequencyPolygonBin> _normalizeBins(
    List<SimpleFrequencyPolygonBin> bins,
  ) {
    return bins
        .where(
          (bin) =>
              bin.start.isFinite &&
              bin.end.isFinite &&
              bin.start != bin.end &&
              bin.count >= 0,
        )
        .map(
          (bin) => bin.start < bin.end
              ? bin
              : SimpleFrequencyPolygonBin(
                  start: bin.end,
                  end: bin.start,
                  count: bin.count,
                  label: bin.label,
                ),
        )
        .toList();
  }

  static List<SimpleFrequencyPolygonBin> _binsForValues(
    List<double> values,
    int binCount,
    double min,
    double max,
  ) {
    final visibleValues = values.where((value) => value.isFinite).toList();
    if (visibleValues.isEmpty) return const [];
    final width = (max - min) / binCount;
    final counts = List<int>.filled(binCount, 0);
    for (final value in visibleValues) {
      if (value < min || value > max) continue;
      final rawIndex = ((value - min) / width).floor();
      final index = rawIndex.clamp(0, binCount - 1);
      counts[index]++;
    }
    return [
      for (var index = 0; index < binCount; index++)
        SimpleFrequencyPolygonBin(
          start: min + width * index,
          end: index == binCount - 1 ? max : min + width * (index + 1),
          count: counts[index],
        ),
    ];
  }

  static String _formatRange(
    SimpleFrequencyPolygonBin bin,
    SimpleFrequencyPolygonValueFormatter formatter,
  ) {
    return bin.label ?? '${formatter(bin.start)}-${formatter(bin.end)}';
  }
}

class _FrequencyPolygonSource {
  final SimpleFrequencyPolygonSeries series;
  final List<SimpleFrequencyPolygonBin> bins;
  final SimpleFrequencyPolygonScale scale;

  const _FrequencyPolygonSource(this.series, this.bins, this.scale);

  String get name => series.name;
  Color? get color => series.color;
  SimpleTrendLineStyle get lineStyle => series.lineStyle;
  int get total => bins.fold<int>(0, (sum, bin) => sum + bin.count);

  double scaledValue(SimpleFrequencyPolygonBin bin) {
    if (scale == SimpleFrequencyPolygonScale.count) return bin.count.toDouble();
    if (total <= 0) return 0;
    return bin.count / total * 100;
  }
}

class _FrequencyPolygonRange {
  final double min;
  final double max;

  const _FrequencyPolygonRange(this.min, this.max);
}
