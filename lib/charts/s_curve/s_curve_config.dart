import 'package:flutter/material.dart';
import 'package:tenun_core/core/chart_axis_config.dart';
import 'package:tenun_core/core/chart_controller.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/json_value.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/xyaxis.dart';
import 'package:tenun_core/core/base_config.dart';
import 's_curve_chart.dart';

/// Configuration for S-Curve charts, used extensively in project management
/// to track cumulative progress or cost over time.
class SCurveChartConfig extends BaseChartConfig {
  final XYAxis? xAxis;
  final XYAxis? yAxis;

  /// Whether to automatically calculate the cumulative sum of the data.
  /// If true, the chart will transform raw periodic data into cumulative data.
  final bool autoCumulative;

  /// The target value (e.g., 100% or total budget).
  final double? targetValue;

  SCurveChartConfig({
    required super.series,
    this.xAxis,
    this.yAxis,
    this.autoCumulative = true,
    this.targetValue,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
    super.theme,
    super.controller,
    super.xAxisConfig,
    super.yAxisConfig,
  }) : super(type: ChartType.sCurve);

  factory SCurveChartConfig.fromJson(Map<String, dynamic> json) {
    final series = (JsonValue.mapList(json['series']) ?? const [])
        .map(Series.fromJson)
        .toList();

    return SCurveChartConfig(
      series: series,
      xAxis: json['xAxis'] != null ? XYAxis.fromJson(json['xAxis']) : null,
      yAxis: json['yAxis'] != null ? XYAxis.fromJson(json['yAxis']) : null,
      autoCumulative: JsonValue.boolOrNull(json['autoCumulative']) ?? true,
      targetValue: JsonValue.doubleOrNull(json['targetValue']),
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
      theme: json['theme'] != null ? ChartTheme.fromJson(json['theme']) : null,
      xAxisConfig: json['xAxisConfig'] != null
          ? ChartAxisConfig.fromJson(json['xAxisConfig'])
          : null,
      yAxisConfig: json['yAxisConfig'] != null
          ? ChartAxisConfig.fromJson(json['yAxisConfig'])
          : null,
      controller: json['controller'],
    );
  }

  @override
  Widget buildChart() => SCurveChartWidget(config: this);

  @override
  Map<String, dynamic> toJson() {
    final base = super.toJson();
    return {
      ...base,
      if (xAxis != null) 'xAxis': xAxis!.toJson(),
      if (yAxis != null) 'yAxis': yAxis!.toJson(),
      'autoCumulative': autoCumulative,
      if (targetValue != null) 'targetValue': targetValue,
    };
  }

  @override
  BaseChartConfig withTheme(ChartTheme theme) {
    return SCurveChartConfig(
      series: series,
      xAxis: xAxis,
      yAxis: yAxis,
      autoCumulative: autoCumulative,
      targetValue: targetValue,
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
    return SCurveChartConfig(
      series: series,
      xAxis: xAxis,
      yAxis: yAxis,
      autoCumulative: autoCumulative,
      targetValue: targetValue,
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
