import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/json_value.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/xyaxis.dart';

class LineSeries extends Series {
  bool? smooth;
  double? sampling;
  ChartLineStyle? lineStyle;

  LineSeries({
    super.type = ChartType.line,
    super.name,
    super.data,
    super.stack,
    super.xAxisIndex,
    super.yAxisIndex,
    super.label,
    super.tooltip,
    super.itemStyle,
    super.emphasis,
    this.smooth,
    this.sampling,
    this.lineStyle,
  });

  factory LineSeries.fromJson(Object? raw) {
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return LineSeries(
      name: JsonValue.string(json['name']),
      data: JsonValue.list(json['data']),
      smooth: JsonValue.boolOrNull(json['smooth']),
      sampling: JsonValue.doubleOrNull(json['sampling']),
      lineStyle: json['lineStyle'] != null
          ? ChartLineStyle.fromJson(json['lineStyle'])
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = super.toJson();
    map.addAll({
      'smooth': smooth,
      'sampling': sampling,
      'lineStyle': lineStyle?.toJson(),
    });
    return map;
  }
}
