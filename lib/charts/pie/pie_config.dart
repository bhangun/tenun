import 'package:flutter/material.dart';

import '../../core/chart_axis_config.dart';
import '../../core/chart_controller.dart';
import '../../core/chart_theme.dart';
import '../../core/chart_model.dart';
import '../../core/chart_type.dart';
import '../../core/grid.dart';
import '../../core/json_value.dart';
import '../../core/legend.dart';
import '../../core/series.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';
import '../../core/base_config.dart';
import 'pie_chart_variants.dart';
import 'pie_series.dart';

class PieChartConfig extends BaseChartConfig {
  final double centerSpaceRadius;
  final double sectionsSpace;
  final bool enableSections;
  final double startDegreeOffset;
  final bool donut;

  PieChartConfig({
    required super.series,
    ChartType? chartType,
    this.centerSpaceRadius = 40.0,
    this.sectionsSpace = 2.0,
    this.enableSections = true,
    this.startDegreeOffset = 0,
    this.donut = false,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
    super.theme,
    super.controller,
    super.xAxisConfig,
    super.yAxisConfig,
  }) : super(type: chartType ?? (donut ? ChartType.donut : ChartType.pie));

  factory PieChartConfig.fromJson(Map<String, dynamic> json) {
    final series = (JsonValue.list(json['series']) ?? const [])
        .map(Series.fromJson)
        .toList();
    final rawType = getChartType(json['type']?.toString() ?? 'pie');
    final donut =
        JsonValue.boolOrNull(json['donut']) ?? rawType == ChartType.donut;

    return PieChartConfig(
      series: series,
      chartType: donut ? ChartType.donut : ChartType.pie,
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
      centerSpaceRadius:
          JsonValue.doubleOrNull(json['centerSpaceRadius']) ?? 40.0,
      sectionsSpace: JsonValue.doubleOrNull(json['sectionsSpace']) ?? 2.0,
      enableSections: JsonValue.boolOrNull(json['enableSections']) ?? true,
      startDegreeOffset:
          JsonValue.doubleOrNull(json['startDegreeOffset']) ?? 0.0,
      donut: donut,
    );
  }

  @override
  Widget buildChart() {
    return PieChartWidget(config: this);
  }

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    return {
      ...baseJson,
      if (xAxisConfig != null) 'xAxisConfig': xAxisConfig!.toJson(),
      if (yAxisConfig != null) 'yAxisConfig': yAxisConfig!.toJson(),
      'centerSpaceRadius': centerSpaceRadius,
      'sectionsSpace': sectionsSpace,
      'enableSections': enableSections,
      'startDegreeOffset': startDegreeOffset,
      'donut': donut,
    };
  }

  PieChartConfig copyWith({
    List<Series>? series,
    ChartType? chartType,
    double? centerSpaceRadius,
    double? sectionsSpace,
    bool? enableSections,
    double? startDegreeOffset,
    bool? donut,
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
    return PieChartConfig(
      series: series ?? this.series,
      chartType: chartType ?? type,
      centerSpaceRadius: centerSpaceRadius ?? this.centerSpaceRadius,
      sectionsSpace: sectionsSpace ?? this.sectionsSpace,
      enableSections: enableSections ?? this.enableSections,
      startDegreeOffset: startDegreeOffset ?? this.startDegreeOffset,
      donut: donut ?? this.donut,
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
  PieChartConfig withTheme(ChartTheme theme) => copyWith(theme: theme);

  @override
  PieChartConfig withController(ChartController controller) =>
      copyWith(controller: controller);
}

class PieChartWidget extends StatelessWidget {
  final PieChartConfig config;

  const PieChartWidget({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final slices = _slicesFromConfig(config);
    return DonutChartConfig(
      slices: slices,
      innerRadiusRatio: _innerRadiusRatio,
      centreLabel: config.donut ? config.title?.subtext : null,
      showLabels: config.enableSections,
      showPercentage: true,
      padAngle: _padAngle,
      title: config.title,
      tooltip: config.tooltip,
      legend: config.legend,
      toolbox: config.toolbox,
      grid: config.grid,
      theme: config.theme,
    ).buildChart();
  }

  double get _innerRadiusRatio {
    if (!config.donut && config.type != ChartType.donut) return 0;
    return (config.centerSpaceRadius / 90).clamp(0.2, 0.75).toDouble();
  }

  double get _padAngle =>
      (config.sectionsSpace / 100).clamp(0.0, 0.2).toDouble();

  List<PieSlice> _slicesFromConfig(PieChartConfig config) {
    final slices = <PieSlice>[];
    for (final series in config.series) {
      for (final item in series.data ?? const []) {
        final slice = _sliceFromDataItem(item);
        if (slice != null) slices.add(slice);
      }
    }
    return slices;
  }

  PieSlice? _sliceFromDataItem(Object? item) {
    if (item is PieSeries) {
      final value = item.value;
      if (value == null || !value.isFinite) return null;
      return PieSlice(name: item.name ?? '', value: value, color: item.color);
    }

    final json = JsonValue.map(item);
    if (json != null) {
      final value = JsonValue.doubleOrNull(json['value']);
      if (value == null || !value.isFinite) return null;
      return PieSlice(
        name: JsonValue.string(json['name']) ?? '',
        value: value,
        color: JsonValue.string(json['color']),
      );
    }

    final value = JsonValue.doubleOrNull(item);
    if (value == null || !value.isFinite) return null;
    return PieSlice(name: '', value: value);
  }
}
