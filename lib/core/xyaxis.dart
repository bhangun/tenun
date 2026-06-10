import 'text_style.dart';
import 'json_value.dart';

enum AxisType { category, value }

class XYAxis {
  String? id;
  AxisType? type;
  String? name;
  String? position;
  bool? inverse;
  dynamic boundaryGap; // Can be a boolean or a list
  dynamic min; // Can be a number, "dataMin", or null
  dynamic max; // Can be a number, "dataMax", or null
  bool? scale;
  int? splitNumber;
  int? minInterval;
  int? interval;
  int? maxInterval;
  double? logBase;
  bool? silent;
  bool? triggerEvent;
  AxisLine? axisLine;
  AxisTick? axisTick;
  AxisLabel? axisLabel;
  SplitLine? splitLine;
  SplitArea? splitArea;
  List<dynamic>? data; // Can contain mixed types (string, number, etc.)
  XAxisPointer? axisPointer;
  String nameColor;
  double nameSize;
  double fontSize;
  String color;
  bool? show;
  Function? formatter;
  int? precision;

  XYAxis({
    this.id,
    this.type,
    this.name,
    this.position,
    this.inverse,
    this.boundaryGap,
    this.min,
    this.max,
    this.scale,
    this.splitNumber,
    this.minInterval,
    this.interval,
    this.maxInterval,
    this.logBase,
    this.silent,
    this.triggerEvent,
    this.axisLine,
    this.axisTick,
    this.axisLabel,
    this.splitLine,
    this.splitArea,
    this.data,
    this.axisPointer,
    this.nameColor = 'rgba(0, 0, 0, 0.1)',
    this.nameSize = 12,
    this.fontSize = 10,
    this.color = 'rgba(0, 0, 0, 0.1)',
    this.show,
    this.formatter,
    this.precision,
  });

  factory XYAxis.fromJson(Object? raw) {
    if (raw is XYAxis) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return XYAxis(
      id: JsonValue.string(json['id']),
      type: _parseAxisType(json['type']),
      name: JsonValue.string(json['name']),
      position: JsonValue.string(json['position']),
      inverse: JsonValue.boolOrNull(json['inverse']),
      boundaryGap: json['boundaryGap'],
      min: json['min'],
      max: json['max'],
      scale: JsonValue.boolOrNull(json['scale']),
      splitNumber: JsonValue.intOrNull(json['splitNumber']),
      minInterval: JsonValue.intOrNull(json['minInterval']),
      interval: JsonValue.intOrNull(json['interval']),
      maxInterval: JsonValue.intOrNull(json['maxInterval']),
      logBase: JsonValue.doubleOrNull(json['logBase']),
      silent: JsonValue.boolOrNull(json['silent']),
      triggerEvent: JsonValue.boolOrNull(json['triggerEvent']),
      axisLine: json['axisLine'] != null
          ? AxisLine.fromJson(json['axisLine'])
          : null,
      axisTick: json['axisTick'] != null
          ? AxisTick.fromJson(json['axisTick'])
          : null,
      axisLabel: json['axisLabel'] != null
          ? AxisLabel.fromJson(json['axisLabel'])
          : null,
      splitLine: json['splitLine'] != null
          ? SplitLine.fromJson(json['splitLine'])
          : null,
      splitArea: json['splitArea'] != null
          ? SplitArea.fromJson(json['splitArea'])
          : null,
      data: JsonValue.list(json['data']),
      axisPointer: json['axisPointer'] != null
          ? XAxisPointer.fromJson(json['axisPointer'])
          : null,
      nameColor: JsonValue.string(json['nameColor']) ?? 'rgba(0, 0, 0, 0.1)',
      nameSize: JsonValue.doubleOrNull(json['nameSize']) ?? 12,
      fontSize: JsonValue.doubleOrNull(json['fontSize']) ?? 10,
      color: JsonValue.string(json['color']) ?? 'rgba(0, 0, 0, 0.1)',
      show: JsonValue.boolOrNull(json['show']),
      precision: JsonValue.intOrNull(json['precision']),
    );
  }

  static AxisType? _parseAxisType(dynamic type) {
    if (type is AxisType) return type;
    if (type is! String) return null;
    switch (type.toLowerCase()) {
      case 'category':
        return AxisType.category;
      case 'value':
        return AxisType.value;
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'position': position,
      'inverse': inverse,
      'boundaryGap': boundaryGap,
      'min': min,
      'max': max,
      'scale': scale,
      'splitNumber': splitNumber,
      'minInterval': minInterval,
      'interval': interval,
      'maxInterval': maxInterval,
      'logBase': logBase,
      'silent': silent,
      'triggerEvent': triggerEvent,
      'axisLine': axisLine?.toJson(),
      'axisTick': axisTick?.toJson(),
      'axisLabel': axisLabel?.toJson(),
      'splitLine': splitLine?.toJson(),
      'splitArea': splitArea?.toJson(),
      'data': data,
      'axisPointer': axisPointer?.toJson(),
    };
  }

  @override
  String toString() {
    return 'XYAxis('
        'id: $id, '
        'type: $type, '
        'name: $name, '
        'position: $position, '
        'inverse: $inverse, '
        'boundaryGap: $boundaryGap, '
        'min: $min, '
        'max: $max, '
        'scale: $scale, '
        'splitNumber: $splitNumber, '
        'minInterval: $minInterval, '
        'interval: $interval, '
        'maxInterval: $maxInterval, '
        'logBase: $logBase, '
        'silent: $silent, '
        'triggerEvent: $triggerEvent, '
        'axisLine: $axisLine, '
        'axisTick: $axisTick, '
        'axisLabel: $axisLabel, '
        'splitLine: $splitLine, '
        'splitArea: $splitArea, '
        'data: $data, '
        'axisPointer: $axisPointer'
        ')';
  }
}

class AxisLine {
  bool? show;
  ChartLineStyle? lineStyle;

  AxisLine({this.show, this.lineStyle});

  factory AxisLine.fromJson(Object? raw) {
    if (raw is AxisLine) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return AxisLine(
      show: JsonValue.boolOrNull(json['show']),
      lineStyle: json['lineStyle'] != null
          ? ChartLineStyle.fromJson(json['lineStyle'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'show': show, 'lineStyle': lineStyle};
  }
}

class AxisTick {
  bool? alignWithLabel;

  AxisTick({this.alignWithLabel});

  factory AxisTick.fromJson(Object? raw) {
    if (raw is AxisTick) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return AxisTick(
      alignWithLabel: JsonValue.boolOrNull(json['alignWithLabel']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'alignWithLabel': alignWithLabel};
  }
}

class AxisLabel {
  String? formatter;
  bool show;
  ChartTextStyle? textStyle;
  AxisLabel({this.formatter, this.show = true, this.textStyle});

  factory AxisLabel.fromJson(Object? raw) {
    if (raw is AxisLabel) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return AxisLabel(
      formatter: JsonValue.string(json['formatter']),
      show: JsonValue.boolOrNull(json['show']) ?? true,
      textStyle: json['textStyle'] != null
          ? ChartTextStyle.fromJson(json['textStyle'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'formatter': formatter, 'show': show, 'textStyle': textStyle};
  }
}

class ChartLineStyle {
  String color;
  double width;

  ChartLineStyle({this.color = 'grey', this.width = 1.0});

  factory ChartLineStyle.fromJson(Object? raw) {
    if (raw is ChartLineStyle) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return ChartLineStyle(
      color: JsonValue.string(json['color']) ?? 'grey',
      width: JsonValue.doubleOrNull(json['width']) ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'color': color, 'width': width};
  }
}

class SplitLine {
  bool? show;

  SplitLine({this.show});

  factory SplitLine.fromJson(Object? raw) {
    if (raw is SplitLine) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return SplitLine(show: JsonValue.boolOrNull(json['show']));
  }

  Map<String, dynamic> toJson() {
    return {'show': show};
  }
}

class SplitArea {
  bool? show;

  SplitArea({this.show});

  factory SplitArea.fromJson(Object? raw) {
    if (raw is SplitArea) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return SplitArea(show: JsonValue.boolOrNull(json['show']));
  }

  Map<String, dynamic> toJson() {
    return {'show': show};
  }
}

class XAxisPointer {
  String? type;

  XAxisPointer({this.type});

  factory XAxisPointer.fromJson(Object? raw) {
    if (raw is XAxisPointer) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return XAxisPointer(type: JsonValue.string(json['type']));
  }

  Map<String, dynamic> toJson() {
    return {'type': type};
  }
}
