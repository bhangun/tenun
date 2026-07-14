import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_axis_config.dart';
import 'package:tenun_core/core/chart_controller.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/xyaxis.dart';
import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/json_value.dart';
import 'scatter_chart.dart';

class ScatterChartConfig extends BaseChartConfig {
  final XYAxis? xAxis;
  final XYAxis? yAxis;
  final double maxX;
  final double maxY;
  final double minX;
  final double minY;
  final double dotSize;

  ScatterChartConfig({
    required super.series,
    this.xAxis,
    this.yAxis,
    double? maxX,
    double? maxY,
    double? minX,
    double? minY,
    this.dotSize = 6.0,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
    super.theme,
    super.controller,
    super.xAxisConfig,
    super.yAxisConfig,
  }) : maxX = maxX ?? 0.0,
       maxY = maxY ?? 0.0,
       minX = minX ?? 0.0,
       minY = minY ?? 0.0,
       super(type: ChartType.scatter);

  factory ScatterChartConfig.fromJson(Map<String, dynamic> json) {
    final series = (JsonValue.list(json['series']) ?? const [])
        .map(Series.fromJson)
        .toList();
    final bounds = ChartDataValueReader.bounds(
      series.map((series) => series.data),
    )?.ensureNonZeroSpan();
    final minX = JsonValue.doubleOrNull(json['minX']) ?? bounds?.minX ?? 0.0;
    final minY = JsonValue.doubleOrNull(json['minY']) ?? bounds?.minY ?? 0.0;
    final rawMaxX =
        JsonValue.doubleOrNull(json['maxX']) ?? bounds?.maxX ?? minX + 1;
    final rawMaxY =
        JsonValue.doubleOrNull(json['maxY']) ?? bounds?.maxY ?? minY + 1;

    return ScatterChartConfig(
      series: series,
      xAxis: json['xAxis'] != null ? XYAxis.fromJson(json['xAxis']) : null,
      yAxis: json['yAxis'] != null ? XYAxis.fromJson(json['yAxis']) : null,
      maxX: rawMaxX <= minX ? minX + 1 : rawMaxX,
      maxY: rawMaxY <= minY ? minY + 1 : rawMaxY,
      minX: minX,
      minY: minY,
      dotSize: JsonValue.doubleOrNull(json['dotSize']) ?? 6.0,
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
    );
  }

  @override
  Widget buildChart() {
    return ScatterChartWidget(config: this);
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
      'maxX': maxX,
      'maxY': maxY,
      'minX': minX,
      'minY': minY,
      'dotSize': dotSize,
    };
  }

  ScatterChartConfig copyWith({
    List<Series>? series,
    XYAxis? xAxis,
    XYAxis? yAxis,
    double? maxX,
    double? maxY,
    double? minX,
    double? minY,
    double? dotSize,
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
    return ScatterChartConfig(
      series: series ?? this.series,
      xAxis: xAxis ?? this.xAxis,
      yAxis: yAxis ?? this.yAxis,
      maxX: maxX ?? this.maxX,
      maxY: maxY ?? this.maxY,
      minX: minX ?? this.minX,
      minY: minY ?? this.minY,
      dotSize: dotSize ?? this.dotSize,
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
  ScatterChartConfig withTheme(ChartTheme theme) => copyWith(theme: theme);

  @override
  ScatterChartConfig withController(ChartController controller) =>
      copyWith(controller: controller);
}

class ScatterChartWidget extends StatelessWidget {
  final ScatterChartConfig config;

  const ScatterChartWidget({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return ScatterBarChartWidget(config: config);
  }
}
