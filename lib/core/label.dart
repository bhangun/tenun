import 'text_style.dart';
import 'json_value.dart';

class Label {
  bool? show;
  String? position;
  ChartTextStyle? textStyle;

  Label({this.show, this.position, this.textStyle});

  factory Label.fromJson(Object? raw) {
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return Label(
      show: JsonValue.boolOrNull(json['show']),
      position: JsonValue.string(json['position']),
      textStyle: json['textStyle'] != null
          ? ChartTextStyle.fromJson(json['textStyle'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'show': show,
      'position': position,
      'textStyle': textStyle?.toJson(),
    };
  }
}

class ItemStyle {
  String color;
  String? borderColor;

  ItemStyle({this.color = 'black', this.borderColor = 'grey'});

  factory ItemStyle.fromJson(Object? raw) {
    if (raw is ItemStyle) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return ItemStyle(
      color: JsonValue.string(json['color']) ?? 'black',
      borderColor: JsonValue.string(json['borderColor']) ?? 'grey',
    );
  }

  Map<String, dynamic> toJson() {
    return {'color': color, 'borderColor': borderColor};
  }
}

class Emphasis {
  Label? label;
  ItemStyle? itemStyle;

  Emphasis({this.label, this.itemStyle});

  factory Emphasis.fromJson(Object? raw) {
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return Emphasis(
      label: json['label'] != null ? Label.fromJson(json['label']) : null,
      itemStyle: json['itemStyle'] != null
          ? ItemStyle.fromJson(json['itemStyle'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label?.toJson(), 'itemStyle': itemStyle?.toJson()};
  }
}
