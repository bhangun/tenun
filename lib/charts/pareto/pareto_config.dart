import 'package:flutter/material.dart';
import 'package:tenun_core/core/chart_color_value.dart';
import 'package:tenun_core/core/chart_controller.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/json_value.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/xyaxis.dart';
import 'package:tenun_core/core/base_config.dart';
import 'pareto_chart.dart';

/// Configuration for Pareto charts, which combine bars and a line to show
/// individual values and the cumulative total (80/20 rule).
class ParetoChartConfig extends BaseChartConfig {
  final XYAxis? xAxis;
  final XYAxis? yAxis;

  /// Color for the cumulative percentage line.
  final Color lineIndicatorColor;

  /// Whether to automatically sort data descending by value.
  final bool autoSort;

  ParetoChartConfig({
    required super.series,
    this.xAxis,
    this.yAxis,
    this.lineIndicatorColor = Colors.orange,
    this.autoSort = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
    super.theme,
    super.controller,
    super.xAxisConfig,
    super.yAxisConfig,
  }) : super(type: ChartType.pareto);

  factory ParetoChartConfig.fromJson(Map<String, dynamic> json) {
    final series = (JsonValue.mapList(json['series']) ?? const [])
        .map(Series.fromJson)
        .toList();

    return ParetoChartConfig(
      series: series,
      xAxis: json['xAxis'] != null ? XYAxis.fromJson(json['xAxis']) : null,
      yAxis: json['yAxis'] != null ? XYAxis.fromJson(json['yAxis']) : null,
      lineIndicatorColor: ChartColorValue.colorOrFallback(
        json['lineIndicatorColor'],
        Colors.orange,
      ),
      autoSort: JsonValue.boolOrNull(json['autoSort']) ?? true,
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      tooltip: json['tooltip'] != null
          ? ChartTooltip.fromJson(json['tooltip'])
          : null,
      legend: json['legend'] != null
          ? ChartLegend.fromJson(json['legend'])
          : null,
      theme: json['theme'] != null ? ChartTheme.fromJson(json['theme']) : null,
      controller: json['controller'],
    );
  }

  @override
  Widget buildChart() => ParetoChartWidget(config: this);

  @override
  BaseChartConfig withTheme(ChartTheme theme) {
    return ParetoChartConfig(
      series: series,
      xAxis: xAxis,
      yAxis: yAxis,
      lineIndicatorColor: lineIndicatorColor,
      autoSort: autoSort,
      title: title,
      tooltip: tooltip,
      legend: legend,
      toolbox: toolbox,
      grid: grid,
      theme: theme,
      controller: controller,
      xAxisConfig: xAxisConfig,
      yAxisConfig: yAxisConfig,
    );
  }

  @override
  BaseChartConfig withController(ChartController controller) {
    return ParetoChartConfig(
      series: series,
      xAxis: xAxis,
      yAxis: yAxis,
      lineIndicatorColor: lineIndicatorColor,
      autoSort: autoSort,
      title: title,
      tooltip: tooltip,
      legend: legend,
      toolbox: toolbox,
      grid: grid,
      theme: theme,
      controller: controller,
      xAxisConfig: xAxisConfig,
      yAxisConfig: yAxisConfig,
    );
  }
}
