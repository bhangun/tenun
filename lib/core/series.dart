import 'dart:ui';
import 'chart_type.dart';
import 'utils/helper.dart';
import 'label.dart';
import '../charts/pie/pie_series.dart';
import 'tooltip.dart';
import 'json_value.dart';

class Series {
  final ChartType type;
  final String? name;
  final List<dynamic>? data;
  final String? stack;
  final int? xAxisIndex;
  final int? yAxisIndex;
  final Label? label;
  final ChartTooltip? tooltip;
  final ItemStyle? itemStyle;
  final Emphasis? emphasis;
  final List<String>? dataLabels;
  final Color? color;
  final double? width;

  Series({
    required this.type,
    this.name,
    List<dynamic>? data,
    this.stack,
    this.xAxisIndex,
    this.yAxisIndex,
    this.label,
    this.tooltip,
    this.itemStyle,
    this.emphasis,
    List<String>? dataLabels,
    this.color,
    this.width,
  }) : data = data == null
           ? null
           : List<dynamic>.unmodifiable(data.map(JsonValue.clone)),
       dataLabels = dataLabels == null
           ? null
           : List<String>.unmodifiable(dataLabels);

  factory Series.fromJson(Object? raw) {
    if (raw is Series) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    final rawData = JsonValue.list(json['data']);
    final typeStr = json['type']?.toString() ?? 'line';
    final chartType = getChartType(typeStr);

    return Series(
      type: chartType,
      name: json['name']?.toString(),
      data: rawData?.map(_parseSeriesDataItem).toList(),
      stack: json['stack']?.toString(),
      xAxisIndex: JsonValue.intOrNull(json['xAxisIndex']),
      yAxisIndex: JsonValue.intOrNull(json['yAxisIndex']),
      label: json['label'] != null ? Label.fromJson(json['label']) : null,
      tooltip: json['tooltip'] != null
          ? ChartTooltip.fromJson(json['tooltip'])
          : null,
      itemStyle: json['itemStyle'] != null
          ? ItemStyle.fromJson(json['itemStyle'])
          : ItemStyle(color: getStringRandomColor()),
      emphasis: json['emphasis'] != null
          ? Emphasis.fromJson(json['emphasis'])
          : null,
      dataLabels: JsonValue.stringList(json['dataLabels']),
      color: _parseColor(json['color']),
      width: JsonValue.doubleOrNull(json['width']),
    );
  }

  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is Color) return value;
    if (value is int) return Color(value);
    if (value is num) return Color(value.toInt());
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;

      try {
        return stringToColor(text);
      } on FormatException {
        final normalized = text.toLowerCase().startsWith('0x')
            ? text.substring(2)
            : text;
        final parsed = int.tryParse(normalized, radix: 16);
        if (parsed != null) {
          return Color(normalized.length <= 6 ? 0xFF000000 | parsed : parsed);
        }
      }
    }

    return null;
  }

  static dynamic _parseSeriesDataItem(dynamic item) {
    if (item is num) {
      return item.toDouble();
    }

    if (item is Map) {
      final json = JsonValue.map(item)!;
      if (item.containsKey('value')) {
        return PieSeries.fromJson(json);
      }
      return json;
    }

    return item;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': chartTypeToString(type),
      'name': name,
      'data': data?.map(JsonValue.clone).toList(growable: false),
      'stack': stack,
      'xAxisIndex': xAxisIndex,
      'yAxisIndex': yAxisIndex,
      'label': label?.toJson(),
      'tooltip': tooltip?.toJson(),
      'itemStyle': itemStyle?.toJson(),
      'emphasis': emphasis?.toJson(),
      'dataLabels': dataLabels == null
          ? null
          : List<String>.from(dataLabels!, growable: false),
      'color': color?.toARGB32(),
      'width': width,
    };
  }

  @override
  String toString() {
    return 'Series('
        'type: $type, '
        'name: $name, '
        'data: $data, '
        'stack: $stack, '
        'xAxisIndex: $xAxisIndex, '
        'yAxisIndex: $yAxisIndex, '
        'label: $label, '
        'tooltip: $tooltip, '
        'itemStyle: $itemStyle, '
        'emphasis: $emphasis'
        ')';
  }
}
