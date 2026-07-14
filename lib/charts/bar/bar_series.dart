import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/json_value.dart';
import 'package:tenun_core/core/series.dart';

class BarSeries extends Series {
  double? barWidth;
  double? barMaxWidth;

  BarSeries({
    super.type = ChartType.bar,
    super.name,
    super.data,
    super.stack,
    super.xAxisIndex,
    super.yAxisIndex,
    super.label,
    super.tooltip,
    super.itemStyle,
    super.emphasis,
    this.barWidth,
    this.barMaxWidth,
  });

  factory BarSeries.fromJson(Object? raw) {
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return BarSeries(
      name: JsonValue.string(json['name']),
      data: JsonValue.list(json['data']),
      barWidth: JsonValue.doubleOrNull(json['barWidth']),
      barMaxWidth: JsonValue.doubleOrNull(json['barMaxWidth']),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = super.toJson();
    map.addAll({'barWidth': barWidth, 'barMaxWidth': barMaxWidth});
    return map;
  }
}
