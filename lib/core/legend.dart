import 'text_style.dart';
import 'json_value.dart';

class ChartLegend {
  String? type;
  String? id;
  bool show;
  int? zlevel;
  int? z;
  String? left;
  String? top;
  String? right;
  String? bottom;
  String? orient;
  String? align;
  List<dynamic>? padding; // Can be a single value or array
  double? itemGap;
  double? itemWidth;
  double? itemHeight;
  dynamic formatter; // Can be a string or a function
  dynamic selectedMode; // Can be a string or boolean
  Map<String, bool>? selected;
  String? icon;
  ChartTextStyle? textStyle;
  String backgroundColor;
  String borderColor;
  double? borderWidth;
  double? borderRadius;
  double? shadowBlur;
  String? shadowColor;
  double? shadowOffsetX;
  double? shadowOffsetY;
  int? scrollDataIndex;
  String? pageButtonPosition;
  String pageIconsColor;
  String pageIconsInactiveColor;
  String textColor;
  double fontSize;
  double iconSize;

  ChartLegend({
    this.type,
    this.id,
    this.show = true,
    this.zlevel,
    this.z,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.orient,
    this.align,
    this.padding,
    this.itemGap,
    this.itemWidth,
    this.itemHeight,
    this.formatter,
    this.selectedMode,
    this.selected,
    this.icon,
    this.textStyle,
    this.backgroundColor = 'transparent',
    this.borderColor = 'black',
    this.borderWidth,
    this.borderRadius,
    this.shadowBlur,
    this.shadowColor,
    this.shadowOffsetX,
    this.shadowOffsetY,
    this.scrollDataIndex,
    this.pageButtonPosition,
    this.pageIconsColor = 'black',
    this.pageIconsInactiveColor = 'grey',
    this.textColor = 'black',
    this.fontSize = 12,
    this.iconSize = 10,
    List<String> data = const <String>[],
  });

  factory ChartLegend.fromJson(Object? raw) {
    if (raw is ChartLegend) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return ChartLegend(
      type: JsonValue.string(json['type']),
      id: JsonValue.string(json['id']),
      show: JsonValue.boolOrNull(json['show']) ?? true,
      zlevel: JsonValue.intOrNull(json['zlevel']),
      z: JsonValue.intOrNull(json['z']),
      left: JsonValue.string(json['left']),
      top: JsonValue.string(json['top']),
      right: JsonValue.string(json['right']),
      bottom: JsonValue.string(json['bottom']),
      orient: JsonValue.string(json['orient']),
      align: JsonValue.string(json['align']),
      padding: JsonValue.doubleList(json['padding']),
      itemGap: JsonValue.doubleOrNull(json['itemGap']),
      itemWidth: JsonValue.doubleOrNull(json['itemWidth']),
      itemHeight: JsonValue.doubleOrNull(json['itemHeight']),
      formatter: json['formatter'], // Assumes dynamic; handle as needed
      selectedMode: json['selectedMode'], // Assumes dynamic; handle as needed
      selected: JsonValue.boolMap(json['selected']),
      icon: JsonValue.string(json['icon']),
      textStyle: json['textStyle'] != null
          ? ChartTextStyle.fromJson(json['textStyle'])
          : null,
      backgroundColor:
          JsonValue.string(json['backgroundColor']) ?? 'transparent',
      borderColor: JsonValue.string(json['borderColor']) ?? 'black',
      borderWidth: JsonValue.doubleOrNull(json['borderWidth']),
      borderRadius: JsonValue.doubleOrNull(json['borderRadius']),
      shadowBlur: JsonValue.doubleOrNull(json['shadowBlur']),
      shadowColor: JsonValue.string(json['shadowColor']),
      shadowOffsetX: JsonValue.doubleOrNull(json['shadowOffsetX']),
      shadowOffsetY: JsonValue.doubleOrNull(json['shadowOffsetY']),
      scrollDataIndex: JsonValue.intOrNull(json['scrollDataIndex']),
      pageButtonPosition: JsonValue.string(json['pageButtonPosition']),
      pageIconsColor: JsonValue.string(json['pageIconsColor']) ?? 'black',
      pageIconsInactiveColor:
          JsonValue.string(json['pageIconsInactiveColor']) ?? 'grey',
      textColor: JsonValue.string(json['textColor']) ?? 'black',
      fontSize: JsonValue.doubleOrNull(json['fontSize']) ?? 12,
      iconSize: JsonValue.doubleOrNull(json['iconSize']) ?? 10,
      data: JsonValue.stringList(json['data']) ?? <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'show': show,
      'zlevel': zlevel,
      'z': z,
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
      'orient': orient,
      'align': align,
      'padding': padding,
      'itemGap': itemGap,
      'itemWidth': itemWidth,
      'itemHeight': itemHeight,
      'formatter': formatter,
      'selectedMode': selectedMode,
      'selected': selected,
      'icon': icon,
      'textStyle': textStyle?.toJson(),
      'backgroundColor': backgroundColor,
      'borderColor': borderColor,
      'borderWidth': borderWidth,
      'borderRadius': borderRadius,
      'shadowBlur': shadowBlur,
      'shadowColor': shadowColor,
      'shadowOffsetX': shadowOffsetX,
      'shadowOffsetY': shadowOffsetY,
      'scrollDataIndex': scrollDataIndex,
      'pageButtonPosition': pageButtonPosition,
      'pageIconsColor': pageIconsColor,
      'pageIconsInactiveColor': pageIconsInactiveColor,
    };
  }

  @override
  String toString() {
    return 'ChartLegend('
        'type: $type, '
        'id: $id, '
        'show: $show, '
        'zlevel: $zlevel, '
        'z: $z, '
        'left: $left, '
        'top: $top, '
        'right: $right, '
        'bottom: $bottom, '
        'orient: $orient, '
        'align: $align, '
        'padding: $padding, '
        'itemGap: $itemGap, '
        'itemWidth: $itemWidth, '
        'itemHeight: $itemHeight, '
        'formatter: $formatter, '
        'selectedMode: $selectedMode, '
        'selected: $selected, '
        'icon: $icon, '
        'textStyle: $textStyle, '
        'backgroundColor: $backgroundColor, '
        'borderColor: $borderColor, '
        'borderWidth: $borderWidth, '
        'borderRadius: $borderRadius, '
        'shadowBlur: $shadowBlur, '
        'shadowColor: $shadowColor, '
        'shadowOffsetX: $shadowOffsetX, '
        'shadowOffsetY: $shadowOffsetY, '
        'scrollDataIndex: $scrollDataIndex, '
        'pageButtonPosition: $pageButtonPosition, '
        'pageIconsColor: $pageIconsColor, '
        'pageIconsInactiveColor: $pageIconsInactiveColor'
        ')';
  }
}
