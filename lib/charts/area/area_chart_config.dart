import 'package:flutter/material.dart';

import '../../core/chart_axis_config.dart';
import '../../core/chart_controller.dart';
import '../../core/chart_theme.dart';
import '../../core/chart_model.dart';
import '../../core/grid.dart';
import '../../core/legend.dart';
import '../../core/series.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';
import '../../core/xyaxis.dart';
import '../line/line_config.dart';
import 'area_chart.dart';

class AreaChartConfig extends LineChartConfig {
  final String areaColor;
  final double areaOpacity;
  final bool gradientArea;

  AreaChartConfig({
    required super.series,
    super.xAxis,
    super.yAxis,
    super.maxY,
    super.curveSmoothness,
    super.showDots,
    super.dotSize,
    this.areaColor = 'red',
    this.areaOpacity = 0.2,
    this.gradientArea = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
    super.theme,
    super.controller,
    super.xAxisConfig,
    super.yAxisConfig,
  }) : super(showBelowArea: true);

  factory AreaChartConfig.fromJson(Map<String, dynamic> json) {
    final series = json['series'] != null
        ? (json['series'] as List).map((s) => Series.fromJson(s)).toList()
        : <Series>[];

    /*   String? areaColor;
    if (json['areaColor'] != null) {
      final color = ;
      if (color is String && color.startsWith('#')) {
        areaColor = Color(int.parse('0xFF${color.substring(1)}'));
      }
    } */

    return AreaChartConfig(
      series: series,
      xAxis: json['xAxis'] != null ? XYAxis.fromJson(json['xAxis']) : null,
      yAxis: json['yAxis'] != null ? XYAxis.fromJson(json['yAxis']) : null,
      maxY: json['maxY']?.toDouble(),
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
      curveSmoothness: json['curveSmoothness']?.toDouble() ?? 0.2,
      showDots: json['showDots'] ?? true,
      dotSize: json['dotSize']?.toDouble() ?? 4.0,
      areaColor: json['areaColor']?.toString() ?? 'red',
      areaOpacity: json['areaOpacity']?.toDouble() ?? 0.2,
      gradientArea: json['gradientArea'] ?? true,
    );
  }

  @override
  Widget buildChart() {
    return AreaChartWidget(config: this);
  }

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson['type'] = 'area'; // Override type
    return {
      ...baseJson,
      'areaColor': areaColor,
      'areaOpacity': areaOpacity,
      'gradientArea': gradientArea,
      if (xAxisConfig != null) 'xAxisConfig': xAxisConfig!.toJson(),
      if (yAxisConfig != null) 'yAxisConfig': yAxisConfig!.toJson(),
    };
  }

  @override
  AreaChartConfig copyWith({
    List<Series>? series,
    XYAxis? xAxis,
    XYAxis? yAxis,
    double? maxY,
    bool? showBelowArea,
    double? curveSmoothness,
    bool? showDots,
    double? dotSize,
    String? areaColor,
    double? areaOpacity,
    bool? gradientArea,
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
    return AreaChartConfig(
      series: series ?? this.series,
      xAxis: xAxis ?? this.xAxis,
      yAxis: yAxis ?? this.yAxis,
      maxY: maxY ?? this.maxY,
      curveSmoothness: curveSmoothness ?? this.curveSmoothness,
      showDots: showDots ?? this.showDots,
      dotSize: dotSize ?? this.dotSize,
      areaColor: areaColor ?? this.areaColor,
      areaOpacity: areaOpacity ?? this.areaOpacity,
      gradientArea: gradientArea ?? this.gradientArea,
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
  AreaChartConfig withTheme(ChartTheme theme) => copyWith(theme: theme);

  @override
  AreaChartConfig withController(ChartController controller) =>
      copyWith(controller: controller);
}
