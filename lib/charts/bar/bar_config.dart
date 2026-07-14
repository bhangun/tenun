import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_axis_config.dart';
import 'package:tenun_core/core/chart_controller.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/xyaxis.dart';
import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/json_value.dart';
import 'bar_chart.dart';
import 'multi_bar.dart';

/// Alignment options for bar charts
enum BarChartAlignment {
  start,
  center,
  end,
  spaceAround,
  spaceBetween,
  spaceEvenly,
}

/// Configuration for bar charts with complete JSON support
class BarChartConfig extends BaseChartConfig {
  final XYAxis? xAxis;
  final XYAxis? yAxis;
  final double? maxY;
  final BarChartAlignment alignment;
  final double barWidth;
  final double? barBorderRadiusValue;
  final bool isStacked;
  final bool isHorizontal;
  final bool isMultiBar;

  BarChartConfig({
    required super.series,
    this.xAxis,
    this.yAxis,
    this.maxY,
    this.alignment = BarChartAlignment.spaceAround,
    this.barWidth = 16.0,
    this.barBorderRadiusValue = 0.0,
    this.isStacked = false,
    this.isHorizontal = false,
    this.isMultiBar = false,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
    super.theme,
    super.controller,
    super.xAxisConfig,
    super.yAxisConfig,
  }) : super(type: ChartType.bar);

  /// Create bar chart config from JSON
  ///
  /// Example JSON structure:
  /// ```json
  /// {
  ///   "type": "bar",
  ///   "title": { "text": "Chart Title" },
  ///   "tooltip": { "show": true },
  ///   "legend": { "show": true, "data": ["Series 1"] },
  ///   "xAxis": { "data": ["A", "B", "C"] },
  ///   "yAxis": { "name": "Value" },
  ///   "series": [
  ///     {
  ///       "name": "Series 1",
  ///       "data": [10, 20, 30],
  ///       "color": "#5470C6"
  ///     }
  ///   ],
  ///   "maxY": 100,
  ///   "barWidth": 16,
  ///   "barBorderRadius": 4,
  ///   "isStacked": false,
  ///   "isHorizontal": false,
  ///   "alignment": "center"
  /// }
  /// ```
  factory BarChartConfig.fromJson(Map<String, dynamic> json) {
    final series = (JsonValue.list(json['series']) ?? const [])
        .map(Series.fromJson)
        .toList();

    // Parse alignment
    final alignment = JsonValue.enumValue(
      BarChartAlignment.values,
      json['alignment'],
      fallback: BarChartAlignment.spaceAround,
    )!;

    // Parse border radius
    final borderRadiusValue = _barBorderRadiusValue(json['barBorderRadius']);

    return BarChartConfig(
      series: series,
      xAxis: json['xAxis'] != null ? XYAxis.fromJson(json['xAxis']) : null,
      yAxis: json['yAxis'] != null ? XYAxis.fromJson(json['yAxis']) : null,
      maxY: JsonValue.doubleOrNull(json['maxY']),
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      tooltip: json['tooltip'] != null
          ? ChartTooltip.fromJson(json['tooltip'])
          : null,
      legend: json['legend'] != null
          ? ChartLegend.fromJson(json['legend'])
          : null,
      toolbox: json['toolbox'] != null
          ? ChartToolbox.fromJson(json['toolbox'])
          : null,
      grid: json['grid'] != null ? GridData.fromJson(json['grid']) : null,
      theme: ChartTheme.fromJson(json['theme']),
      xAxisConfig: ChartAxisConfig.fromJson(json['xAxisConfig']),
      yAxisConfig: ChartAxisConfig.fromJson(json['yAxisConfig']),
      alignment: alignment,
      barWidth: JsonValue.doubleOrNull(json['barWidth']) ?? 16.0,
      barBorderRadiusValue: borderRadiusValue ?? 0.0,
      isStacked: JsonValue.boolOrNull(json['isStacked']) ?? false,
      isHorizontal: JsonValue.boolOrNull(json['isHorizontal']) ?? false,
      isMultiBar: JsonValue.boolOrNull(json['isMultiBar']) ?? false,
    );
  }

  /// Get border radius from value
  BorderRadius get barBorderRadius {
    if (barBorderRadiusValue == null || barBorderRadiusValue == 0) {
      return BorderRadius.zero;
    }
    return BorderRadius.circular(barBorderRadiusValue!);
  }

  @override
  Widget buildChart() {
    if (isMultiBar) {
      return MultiBarChartWidget(config: this);
    }
    return BarChartWidget(config: this);
  }

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    return {
      ...baseJson,
      'xAxis': xAxis?.toJson(),
      'yAxis': yAxis?.toJson(),
      if (xAxisConfig != null) 'xAxisConfig': xAxisConfig!.toJson(),
      if (yAxisConfig != null) 'yAxisConfig': yAxisConfig!.toJson(),
      'maxY': maxY,
      'alignment': alignment.name,
      'barWidth': barWidth,
      'barBorderRadius': barBorderRadiusValue,
      'isStacked': isStacked,
      'isHorizontal': isHorizontal,
      'isMultiBar': isMultiBar,
    };
  }

  /// Calculate maximum value from series data with buffer
  @override
  double getMaxSeriesValue() {
    if (series.isEmpty ||
        series.any((s) => s.data == null || s.data!.isEmpty)) {
      return 100.0;
    }

    var maxValue = double.negativeInfinity;
    for (final seriesItem in series) {
      for (final item in seriesItem.data ?? const []) {
        final value = ChartDataValueReader.yValueOrNull(item);
        if (value != null && value > maxValue) maxValue = value;
      }
    }

    if (!maxValue.isFinite || maxValue <= 0) return 100.0;

    // Add 20% buffer for better visualization
    return maxValue * 1.2;
  }

  BarChartConfig copyWith({
    List<Series>? series,
    XYAxis? xAxis,
    XYAxis? yAxis,
    double? maxY,
    BarChartAlignment? alignment,
    double? barWidth,
    double? barBorderRadiusValue,
    bool? isStacked,
    bool? isHorizontal,
    bool? isMultiBar,
    TitlesData? title,
    ChartTooltip? tooltip,
    ChartLegend? legend,
    ChartToolbox? toolbox,
    GridData? grid,
    ChartTheme? theme,
    ChartController? controller,
    ChartAxisConfig? xAxisConfig,
    ChartAxisConfig? yAxisConfig,
  }) {
    return BarChartConfig(
      series: series ?? this.series,
      xAxis: xAxis ?? this.xAxis,
      yAxis: yAxis ?? this.yAxis,
      maxY: maxY ?? this.maxY,
      alignment: alignment ?? this.alignment,
      barWidth: barWidth ?? this.barWidth,
      barBorderRadiusValue: barBorderRadiusValue ?? this.barBorderRadiusValue,
      isStacked: isStacked ?? this.isStacked,
      isHorizontal: isHorizontal ?? this.isHorizontal,
      isMultiBar: isMultiBar ?? this.isMultiBar,
      title: title ?? this.title,
      tooltip: tooltip ?? this.tooltip,
      legend: legend ?? this.legend,
      toolbox: toolbox ?? this.toolbox,
      grid: grid ?? this.grid,
      theme: theme ?? this.theme,
      controller: controller ?? this.controller,
      xAxisConfig: xAxisConfig ?? this.xAxisConfig,
      yAxisConfig: yAxisConfig ?? this.yAxisConfig,
    );
  }

  @override
  BarChartConfig withTheme(ChartTheme theme) => copyWith(theme: theme);

  @override
  BarChartConfig withController(ChartController controller) =>
      copyWith(controller: controller);
}

double? _barBorderRadiusValue(Object? raw) {
  final direct = JsonValue.doubleOrNull(raw);
  if (direct != null) return direct;

  final json = JsonValue.map(raw);
  if (json == null) return null;

  for (final key in const [
    'topLeft',
    'topRight',
    'bottomLeft',
    'bottomRight',
  ]) {
    final value = JsonValue.doubleOrNull(json[key]);
    if (value != null) return value;
  }

  return null;
}
