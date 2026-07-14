import 'package:flutter/material.dart';
import 'package:tenun_core/core/chart_controller.dart';
import 'package:tenun_core/core/chart_color_value.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/json_value.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/xyaxis.dart';
import 'package:tenun_core/core/base_config.dart';
import 'roc_curve_chart.dart';

/// Configuration for ROC (Receiver Operating Characteristic) curves.
class ROCCurveChartConfig extends BaseChartConfig {
  final XYAxis? xAxis;
  final XYAxis? yAxis;

  /// Whether to show the diagonal chance line (y = x)
  final bool showChanceLine;

  /// Color for the chance line
  final Color chanceLineColor;

  ROCCurveChartConfig({
    required super.series,
    this.xAxis,
    this.yAxis,
    this.showChanceLine = true,
    this.chanceLineColor = Colors.grey,
    super.title,
    super.theme = ChartTheme.light,
    super.controller,
  }) : super(type: ChartType.rocCurve);

  factory ROCCurveChartConfig.fromJson(Map<String, dynamic> json) {
    final series = (JsonValue.mapList(json['series']) ?? const [])
        .map(Series.fromJson)
        .toList();

    return ROCCurveChartConfig(
      series: series,
      xAxis: json['xAxis'] != null ? XYAxis.fromJson(json['xAxis']) : null,
      yAxis: json['yAxis'] != null ? XYAxis.fromJson(json['yAxis']) : null,
      showChanceLine: JsonValue.boolOrNull(json['showChanceLine']) ?? true,
      chanceLineColor: ChartColorValue.colorOrFallback(
        json['chanceLineColor'],
        Colors.grey,
      ),
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      theme: json['theme'] != null ? ChartTheme.fromJson(json['theme']) : null,
      controller: json['controller'],
    );
  }

  @override
  Widget buildChart() => ROCCurveChartWidget(config: this);

  @override
  BaseChartConfig withTheme(ChartTheme theme) {
    return ROCCurveChartConfig(
      series: series,
      xAxis: xAxis,
      yAxis: yAxis,
      showChanceLine: showChanceLine,
      chanceLineColor: chanceLineColor,
      title: title,
      theme: theme,
      controller: controller,
    );
  }

  @override
  BaseChartConfig withController(ChartController controller) {
    return ROCCurveChartConfig(
      series: series,
      xAxis: xAxis,
      yAxis: yAxis,
      showChanceLine: showChanceLine,
      chanceLineColor: chanceLineColor,
      title: title,
      theme: theme,
      controller: controller,
    );
  }
}
