import 'xyaxis.dart';
import 'json_value.dart';

class GridData {
  bool? show;
  String? id;
  double? left;
  double? top;
  double? right;
  double? bottom;
  double? width;
  double? height;
  bool? containLabel;
  String? backgroundColor;
  String? borderColor;
  double? borderWidth;
  double horizontalInterval;
  String horizontalColor;
  double horizontalWidth;
  List<int> horizontalDashArray;
  String verticalColor;
  double verticalWidth;
  List<int> verticalDashArray;
  bool showHorizontalLines;
  bool showVerticalLines;
  String color;
  ChartLineStyle lineStyle;

  GridData({
    this.show,
    this.id,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    this.containLabel,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.horizontalInterval = 0.5,
    this.horizontalColor = 'rgba(0, 0, 0, 0.1)',
    this.horizontalWidth = 0.5,
    this.horizontalDashArray = const [5, 5],
    this.verticalColor = 'rgba(0, 0, 0, 0.1)',
    this.verticalWidth = 0.5,
    this.verticalDashArray = const [5, 5],
    this.showHorizontalLines = true,
    this.showVerticalLines = true,
    this.color = 'rgba(0, 0, 0, 0.1)',
    ChartLineStyle? lineStyle,
  }) : lineStyle = lineStyle ?? ChartLineStyle();

  factory GridData.fromJson(Object? raw) {
    if (raw is GridData) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return GridData(
      show: JsonValue.boolOrNull(json['show']),
      id: JsonValue.string(json['id']),
      left: JsonValue.doubleOrNull(json['left']),
      top: JsonValue.doubleOrNull(json['top']),
      right: JsonValue.doubleOrNull(json['right']),
      bottom: JsonValue.doubleOrNull(json['bottom']),
      width: JsonValue.doubleOrNull(json['width']),
      height: JsonValue.doubleOrNull(json['height']),
      containLabel: JsonValue.boolOrNull(json['containLabel']),
      backgroundColor: JsonValue.string(json['backgroundColor']),
      borderColor: JsonValue.string(json['borderColor']),
      borderWidth: JsonValue.doubleOrNull(json['borderWidth']),
      horizontalInterval:
          JsonValue.doubleOrNull(json['horizontalInterval']) ?? 0.5,
      horizontalColor:
          JsonValue.string(json['horizontalColor']) ?? 'rgba(0, 0, 0, 0.1)',
      horizontalWidth: JsonValue.doubleOrNull(json['horizontalWidth']) ?? 0.5,
      horizontalDashArray:
          JsonValue.list(json['horizontalDashArray'])
              ?.map(JsonValue.intOrNull)
              .whereType<int>()
              .toList(growable: false) ??
          const [5, 5],
      verticalColor:
          JsonValue.string(json['verticalColor']) ?? 'rgba(0, 0, 0, 0.1)',
      verticalWidth: JsonValue.doubleOrNull(json['verticalWidth']) ?? 0.5,
      verticalDashArray:
          JsonValue.list(json['verticalDashArray'])
              ?.map(JsonValue.intOrNull)
              .whereType<int>()
              .toList(growable: false) ??
          const [5, 5],
      showHorizontalLines:
          JsonValue.boolOrNull(json['showHorizontalLines']) ?? true,
      showVerticalLines:
          JsonValue.boolOrNull(json['showVerticalLines']) ?? true,
      color: JsonValue.string(json['color']) ?? 'rgba(0, 0, 0, 0.1)',
      lineStyle: ChartLineStyle.fromJson(json['lineStyle']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'show': show,
      'id': id,
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
      'width': width,
      'height': height,
      'containLabel': containLabel,
      'backgroundColor': backgroundColor,
      'borderColor': borderColor,
      'borderWidth': borderWidth,
    };
  }

  @override
  String toString() {
    return 'Grid('
        'show: $show, '
        'id: $id, '
        'left: $left, '
        'top: $top, '
        'right: $right, '
        'bottom: $bottom, '
        'width: $width, '
        'height: $height, '
        'containLabel: $containLabel, '
        'backgroundColor: $backgroundColor, '
        'borderColor: $borderColor, '
        'borderWidth: $borderWidth'
        ')';
  }
}
