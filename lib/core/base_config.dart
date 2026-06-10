import 'package:flutter/material.dart';

import 'chart_axis_config.dart';
import 'chart_api_contract.dart';
import 'chart_controller.dart';
import 'chart_data_value_reader.dart';
import 'chart_registry.dart';
import 'chart_theme.dart';
import 'chart_type.dart';
import 'chart_model.dart';
import 'data_sampler.dart';
import 'grid.dart';
import 'json_value.dart';
import 'legend.dart';
import 'series.dart';
import 'title.dart';
import 'tooltip.dart';

abstract class BaseChartConfig {
  final TitlesData? title;
  final ChartTooltip? tooltip;
  final ChartLegend? legend;
  final ChartToolbox? toolbox;
  final GridData? grid;
  final List<Series> series;
  final ChartType type;
  final ChartTheme theme;
  final ChartController? controller;
  final ChartAxisConfig? xAxisConfig;
  final ChartAxisConfig? yAxisConfig;

  BaseChartConfig({
    required this.type,
    this.title,
    this.tooltip,
    this.legend,
    this.toolbox,
    this.grid,
    required List<Series> series,
    ChartTheme? theme,
    this.controller,
    this.xAxisConfig,
    this.yAxisConfig,
  }) : theme = theme ?? ChartTheme.light,
       series = List<Series>.unmodifiable(
         _maybeSampleLargeSeries(series, type),
       );

  /// Factory method to create chart config from JSON
  factory BaseChartConfig.fromJson(Map<String, dynamic> json) {
    final normalized = json['type'] == null ? {...json, 'type': 'line'} : json;
    final override = _parseSamplingPolicyOverride(normalized);
    if (override == null) {
      return ChartRegistry.resolve(normalized);
    }
    return _withSamplingPolicyOverride(
      override,
      () => ChartRegistry.resolve(normalized),
    );
  }

  /// Safe maximum value with 10% headroom.
  double getMaxSeriesValue() {
    if (series.isEmpty) return 100;
    double max = double.negativeInfinity;
    for (final s in series) {
      for (final item in s.data ?? const []) {
        final value = ChartDataValueReader.yValueOrNull(item);
        if (value != null && value > max) {
          max = value;
        }
      }
    }
    if (!max.isFinite) return 100;
    return max + (max.abs() * 0.1).clamp(1.0, 1e6);
  }

  /// Override in concrete configs to return a themed copy.
  BaseChartConfig withTheme(ChartTheme theme) => this;

  /// Override in concrete configs to return a controller-attached copy.
  BaseChartConfig withController(ChartController controller) => this;

  /// Shared API contract for all config-driven chart families.
  ChartApiContract get apiContract => ChartApiContracts.optionConfig;

  bool supportsApiField(String field) => apiContract.supports(field);

  /// Method to create the appropriate chart widget
  Widget buildChart();

  /// Convert configuration to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': chartTypeToString(type),
      'title': title?.toJson(),
      'tooltip': tooltip?.toJson(),
      'legend': legend?.toJson(),
      'toolbox': toolbox?.toJson(),
      'grid': grid?.toJson(),
      'series': series.map((s) => s.toJson()).toList(),
      if (xAxisConfig != null) 'xAxis': xAxisConfig!.toJson(),
      if (yAxisConfig != null) 'yAxis': yAxisConfig!.toJson(),
    };
  }

  static List<Series> _maybeSampleLargeSeries(
    List<Series> input,
    ChartType type,
  ) {
    final effectiveMode = _samplingModeOverride ?? LargeDataSamplingConfig.mode;
    final effectiveEnabled =
        _samplingEnabledOverride ?? LargeDataSamplingConfig.enabled;
    final effectiveThreshold = LargeDataSamplingConfig.normalizeThreshold(
      _samplingThresholdOverride ?? LargeDataSamplingConfig.threshold,
    );
    final effectiveStrategy =
        _samplingStrategyOverride ?? LargeDataSamplingConfig.strategy;

    if (effectiveMode == ChartDataMode.regular) return input;
    if (effectiveMode == ChartDataMode.auto && !effectiveEnabled) return input;
    if (!_supportsAutoSampling(type)) return input;

    List<Series>? output;
    for (var index = 0; index < input.length; index++) {
      final s = input[index];
      final sampledData = _sampleSeriesData(
        s.data,
        chartType: _samplingTypeForSeries(parentType: type, seriesType: s.type),
        threshold: effectiveThreshold,
        strategy: effectiveStrategy,
      );
      if (identical(sampledData, s.data)) {
        output?.add(s);
        continue;
      }

      output ??= <Series>[...input.take(index)];
      output.add(_copySeriesWithData(s, sampledData));
    }
    return output ?? input;
  }

  static Series _copySeriesWithData(Series s, List<dynamic>? data) {
    return Series(
      type: s.type,
      name: s.name,
      data: data,
      stack: s.stack,
      xAxisIndex: s.xAxisIndex,
      yAxisIndex: s.yAxisIndex,
      label: s.label,
      tooltip: s.tooltip,
      itemStyle: s.itemStyle,
      emphasis: s.emphasis,
      dataLabels: s.dataLabels,
      color: s.color,
      width: s.width,
    );
  }

  static List<dynamic>? _sampleSeriesData(
    List<dynamic>? data, {
    required ChartType chartType,
    required int threshold,
    required SamplingStrategy? strategy,
  }) {
    if (data == null) return null;
    if (data.length <= threshold) return data;

    final numericValues = _extractNumericValues(data);
    if (numericValues != null) {
      final sampled = DoubleListSampler.auto(
        numericValues,
        threshold,
        forceStrategy: strategy,
      );
      return sampled.cast<dynamic>();
    }

    // Structured or mixed rows keep their original payload shape. Invalid rows
    // are ignored so one malformed point does not disable large-data sampling.
    final extracted = _extractSparseSamplingValues(data, chartType);
    if (extracted != null) {
      if (extracted.values.length <= threshold) {
        return extracted.sourceIndices.length == data.length
            ? data
            : [for (final i in extracted.sourceIndices) data[i]];
      }
      final keep = DoubleListSampler.autoIndices(
        extracted.values,
        threshold,
        forceStrategy: strategy,
      );
      return [
        for (final localIndex in keep)
          data[extracted.sourceIndices[localIndex]],
      ];
    }

    return data;
  }

  static List<double>? _extractNumericValues(List<dynamic> data) {
    final values = List<double>.filled(data.length, 0, growable: false);
    for (var index = 0; index < data.length; index++) {
      final value = ChartDataValueReader.numeric(data[index]);
      if (value == null) return null;
      values[index] = value;
    }
    return values;
  }

  static ChartType _samplingTypeForSeries({
    required ChartType parentType,
    required ChartType seriesType,
  }) {
    if (parentType == ChartType.combo) return seriesType;
    if (seriesType == ChartType.candlestick || seriesType == ChartType.ohlc) {
      return seriesType;
    }
    return parentType;
  }

  static _SamplingExtraction? _extractSparseSamplingValues(
    List<dynamic> data,
    ChartType chartType,
  ) {
    final values = List<double>.filled(data.length, 0, growable: false);
    final sourceIndices = List<int>.filled(data.length, 0, growable: false);
    var writeIndex = 0;
    for (var index = 0; index < data.length; index++) {
      final value = _samplingValueForChartType(data[index], chartType);
      if (value == null) continue;
      values[writeIndex] = value;
      sourceIndices[writeIndex] = index;
      writeIndex++;
    }
    if (writeIndex == 0) return null;
    return _SamplingExtraction(
      values: writeIndex == data.length
          ? values
          : values.sublist(0, writeIndex),
      sourceIndices: writeIndex == data.length
          ? sourceIndices
          : sourceIndices.sublist(0, writeIndex),
    );
  }

  static double? _samplingValueForChartType(Object? row, ChartType chartType) {
    if (chartType == ChartType.candlestick || chartType == ChartType.ohlc) {
      return ChartDataValueReader.ohlcCloseValueOrNull(row);
    }
    return ChartDataValueReader.yValueOrNull(row);
  }

  static T _withSamplingPolicyOverride<T>(
    _SamplingPolicyOverride override,
    T Function() body,
  ) {
    final prevEnabled = _samplingEnabledOverride;
    final prevThreshold = _samplingThresholdOverride;
    final prevStrategy = _samplingStrategyOverride;
    final prevMode = _samplingModeOverride;
    _samplingEnabledOverride = override.enabled;
    _samplingThresholdOverride = override.threshold;
    _samplingStrategyOverride = override.strategy;
    _samplingModeOverride = override.mode;
    try {
      return body();
    } finally {
      _samplingEnabledOverride = prevEnabled;
      _samplingThresholdOverride = prevThreshold;
      _samplingStrategyOverride = prevStrategy;
      _samplingModeOverride = prevMode;
    }
  }

  static _SamplingPolicyOverride? _parseSamplingPolicyOverride(
    Map<String, dynamic> json,
  ) {
    final mode = _parseChartDataMode(json['dataMode'] ?? json['datasetMode']);
    final sampling = json['sampling'];

    bool hasOverride = mode != null;
    bool? enabled;
    int? threshold;
    SamplingStrategy? strategy;

    final samplingJson = JsonValue.map(sampling);
    if (samplingJson != null) {
      if (samplingJson.containsKey('enabled')) {
        enabled = JsonValue.boolOrNull(samplingJson['enabled']);
        hasOverride = true;
      }
      if (samplingJson.containsKey('threshold')) {
        threshold = JsonValue.intOrNull(samplingJson['threshold']);
        hasOverride = true;
      }
      final strategyRaw = samplingJson['strategy'];
      if (strategyRaw != null) {
        strategy = _parseSamplingStrategy(strategyRaw.toString());
        hasOverride = true;
      } else if (samplingJson.containsKey('strategy')) {
        // Explicit null means "auto".
        strategy = null;
        hasOverride = true;
      }
    }

    if (!hasOverride) return null;
    return _SamplingPolicyOverride(
      mode: mode,
      enabled: enabled,
      threshold: threshold,
      strategy: strategy,
    );
  }

  static ChartDataMode? _parseChartDataMode(dynamic raw) {
    if (raw == null) return null;
    switch (raw.toString().toLowerCase()) {
      case 'regular':
      case 'simple':
        return ChartDataMode.regular;
      case 'large':
      case 'largedataset':
      case 'performance':
        return ChartDataMode.large;
      case 'auto':
      default:
        return ChartDataMode.auto;
    }
  }

  static SamplingStrategy? _parseSamplingStrategy(String raw) {
    switch (raw.toLowerCase()) {
      case 'lttb':
        return SamplingStrategy.lttb;
      case 'minmax':
      case 'min_max':
        return SamplingStrategy.minMax;
      case 'nth':
      case 'every_n':
        return SamplingStrategy.nth;
      case 'auto':
      default:
        return null;
    }
  }

  static bool? _samplingEnabledOverride;
  static int? _samplingThresholdOverride;
  static SamplingStrategy? _samplingStrategyOverride;
  static ChartDataMode? _samplingModeOverride;

  static bool _supportsAutoSampling(ChartType type) {
    switch (type) {
      case ChartType.bar:
      case ChartType.stackedBar:
      case ChartType.groupedBar:
      case ChartType.horizontalBar:
      case ChartType.stackedHorizontalBar:
      case ChartType.line:
      case ChartType.lineArea:
      case ChartType.area:
      case ChartType.stackedArea:
      case ChartType.scatter:
      case ChartType.bubble:
      case ChartType.strip:
      case ChartType.combo:
      case ChartType.histogram:
      case ChartType.lollipop:
      case ChartType.sparkline:
      case ChartType.ridgeline:
      case ChartType.errorBar:
      case ChartType.candlestick:
      case ChartType.ohlc:
      case ChartType.kagi:
      case ChartType.renko:
      case ChartType.macd:
      case ChartType.barBackground:
      case ChartType.barRace:
      case ChartType.barGradient:
      case ChartType.barLabelRotation:
      case ChartType.barRounded:
      case ChartType.barNormalized:
      case ChartType.negativeBar:
      case ChartType.barBrush:
      case ChartType.areaPieces:
      case ChartType.lineGradient:
      case ChartType.lineConfidenceBand:
      case ChartType.lineMarkline:
      case ChartType.logAxis:
      case ChartType.dynamicTimeSeries:
      case ChartType.intradayLine:
      case ChartType.lineClickAdd:
      case ChartType.rainfall:
      case ChartType.multiXAxes:
      case ChartType.lineStyleItem:
      case ChartType.largeScaleArea:
      case ChartType.areaTimeAxis:
      case ChartType.polarLine:
      case ChartType.slope:
      case ChartType.dumbbell:
      case ChartType.areaBump:
        return true;
      default:
        return false;
    }
  }
}

/// Global large-data sampling policy used by [BaseChartConfig].
///
/// You can tune this at app startup:
/// ```dart
/// LargeDataSamplingConfig.enabled = true;
/// LargeDataSamplingConfig.threshold = 1500;
/// LargeDataSamplingConfig.strategy = null; // auto
/// ```
class LargeDataSamplingConfig {
  static const int minimumThreshold = 2;

  static bool enabled = true;
  static int threshold = 1200;
  static SamplingStrategy? strategy;
  static ChartDataMode mode = ChartDataMode.auto;

  /// Minimum-safe sampling threshold shared by config parsing and rendering.
  static int normalizeThreshold(int threshold) =>
      threshold < minimumThreshold ? minimumThreshold : threshold;
}

/// Data handling mode for chart series rendering.
///
/// - [regular]: disable sampling, render as-is.
/// - [auto]: use [LargeDataSamplingConfig.enabled] and threshold rules.
/// - [large]: force sampling path for supported chart types.
enum ChartDataMode { regular, auto, large }

class _SamplingPolicyOverride {
  final ChartDataMode? mode;
  final bool? enabled;
  final int? threshold;
  final SamplingStrategy? strategy;

  const _SamplingPolicyOverride({
    this.mode,
    this.enabled,
    this.threshold,
    this.strategy,
  });
}

class _SamplingExtraction {
  final List<double> values;
  final List<int> sourceIndices;

  const _SamplingExtraction({
    required this.values,
    required this.sourceIndices,
  });
}
