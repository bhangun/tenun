import 'chart_type.dart';
import 'grid.dart';
import 'title.dart';
import 'legend.dart';
import 'series.dart';
import 'toolbox_feature.dart';
import 'tooltip.dart';
import 'json_value.dart';
import 'chart_data_value_reader.dart';
import 'utils/helper.dart';
import 'xyaxis.dart';

class ChartConfig {
  final TitlesData? title;
  final ChartTooltip? tooltip;
  final ChartLegend? legend;
  final ChartToolbox? toolbox;
  final GridData? grid;
  final List<Series> series;
  final ChartType? type;
  final XYAxis? xAxis;
  final XYAxis? yAxis;
  final double? maxValueY;
  final double? maxY;

  ChartConfig({
    ChartType? type,
    this.maxValueY,
    double? maxY,
    this.title,
    this.tooltip,
    this.legend,
    this.toolbox,
    this.grid,
    this.xAxis,
    this.yAxis,
    List<Series> series = const [],
  }) : maxY = (type != getChartType('pie')) && maxY != null
           ? getMaxSeriesValue(series)
           : 100,
       series = List<Series>.unmodifiable(series),
       type = type ?? ChartType.bar;

  factory ChartConfig.fromJson(Map<String, dynamic> json) {
    final series = (JsonValue.list(json['series']) ?? const [])
        .map(Series.fromJson)
        .toList();
    return ChartConfig(
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      tooltip: json['tooltip'] != null
          ? ChartTooltip.fromJson(json['tooltip'])
          : null,
      type: json['type'] != null
          ? getChartType(json['type'])
          : getChartType("line"),
      legend: json['legend'] != null
          ? ChartLegend.fromJson(json['legend'])
          : null,
      toolbox: json['toolbox'] != null
          ? ChartToolbox.fromJson(json['toolbox'])
          : null,
      grid: json['grid'] != null ? GridData.fromJson(json['grid']) : null,
      xAxis: json['xAxis'] != null ? XYAxis.fromJson(json['xAxis']) : null,
      yAxis: json['yAxis'] != null ? XYAxis.fromJson(json['yAxis']) : null,
      series: series,
    );
  }

  double getMax() {
    var max = double.negativeInfinity;
    for (final seriesItem in series) {
      for (final item in seriesItem.data ?? const []) {
        final value = ChartDataValueReader.yValueOrNull(item);
        if (value != null && value > max) max = value;
      }
    }
    return max.isFinite ? max : 0;
  }

  @override
  String toString() {
    return 'ChartConfig('
        'title: $title, '
        'tooltip: $tooltip, '
        'legend: $legend, '
        'toolbox: $toolbox, '
        'grid: $grid, '
        'series: $series, '
        'type: $type, '
        'xAxis: $xAxis, '
        'yAxis: $yAxis, '
        'maxValueY: $maxValueY, '
        'maxY: $maxY'
        ')';
  }
}

class ChartToolbox {
  final ToolboxFeature? feature;
  final bool show;

  ChartToolbox({this.feature, this.show = false});

  factory ChartToolbox.fromJson(Object? raw) {
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return ChartToolbox(
      feature: json['feature'] is ToolboxFeature
          ? json['feature'] as ToolboxFeature
          : null,
      show: JsonValue.boolOrNull(json['show']) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'feature': feature, 'show': show};
  }
}
