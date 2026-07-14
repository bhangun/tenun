import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/json_value.dart';
import 'polar_line_chart.dart';

class PolarLineChartConfig extends BaseChartConfig {
  final List<String> categories; // angular labels
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  PolarLineChartConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.polarLine);

  @override
  Widget buildChart() => PolarLineWidget(config: this);

  factory PolarLineChartConfig.fromJson(Map<String, dynamic> j) {
    final cats = JsonValue.stringList(j['categories']) ?? const <String>[];
    final s = (JsonValue.mapList(j['series']) ?? const [])
        .map(Series.fromJson)
        .toList();
    return PolarLineChartConfig(
      categories: cats,
      series: s,
      title: j['title'] != null ? TitlesData.fromJson(j['title']) : null,
      tooltip: j['tooltip'] != null
          ? ChartTooltip.fromJson(j['tooltip'])
          : null,
      legend: j['legend'] != null ? ChartLegend.fromJson(j['legend']) : null,
      toolbox: j['toolbox'] != null
          ? ChartToolbox.fromJson(j['toolbox'])
          : null,
      grid: j['grid'] != null ? GridData.fromJson(j['grid']) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
  };
}
