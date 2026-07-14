import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_axis_config.dart';
import 'package:tenun_core/core/chart_controller.dart';
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
import 'line_chart.dart';

class LineChartConfig extends BaseChartConfig {
  final XYAxis? xAxis;
  final XYAxis? yAxis;
  final double maxY;
  final bool showBelowArea;
  final double curveSmoothness;
  final bool showDots;
  final double dotSize;

  LineChartConfig({
    required super.series,
    this.xAxis,
    this.yAxis,
    double? maxY,
    this.showBelowArea = false,
    this.curveSmoothness = 0.2,
    this.showDots = true,
    this.dotSize = 4.0,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
    super.theme,
    super.controller,
    super.xAxisConfig,
    super.yAxisConfig,
  }) : maxY = maxY ?? 0.0,
       super(type: ChartType.line);

  factory LineChartConfig.fromJson(Map<String, dynamic> json) {
    final series = (JsonValue.list(json['series']) ?? const [])
        .map(Series.fromJson)
        .toList();

    return LineChartConfig(
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
      showBelowArea: JsonValue.boolOrNull(json['showBelowArea']) ?? false,
      curveSmoothness: JsonValue.doubleOrNull(json['curveSmoothness']) ?? 0.2,
      showDots: JsonValue.boolOrNull(json['showDots']) ?? true,
      dotSize: JsonValue.doubleOrNull(json['dotSize']) ?? 4.0,
    );
  }

  @override
  Widget buildChart() {
    return LineChartWidget(config: this);
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
      'showBelowArea': showBelowArea,
      'curveSmoothness': curveSmoothness,
      'showDots': showDots,
      'dotSize': dotSize,
    };
  }

  LineChartConfig copyWith({
    List<Series>? series,
    XYAxis? xAxis,
    XYAxis? yAxis,
    double? maxY,
    bool? showBelowArea,
    double? curveSmoothness,
    bool? showDots,
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
    return LineChartConfig(
      series: series ?? this.series,
      xAxis: xAxis ?? this.xAxis,
      yAxis: yAxis ?? this.yAxis,
      maxY: maxY ?? this.maxY,
      showBelowArea: showBelowArea ?? this.showBelowArea,
      curveSmoothness: curveSmoothness ?? this.curveSmoothness,
      showDots: showDots ?? this.showDots,
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
  LineChartConfig withTheme(ChartTheme theme) => copyWith(theme: theme);

  @override
  LineChartConfig withController(ChartController controller) =>
      copyWith(controller: controller);
}
