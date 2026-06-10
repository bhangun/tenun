import 'dart:ui';

import 'text_style.dart';
import 'json_value.dart';

class TitlesData {
  String? text;
  String? link;
  String? target;
  String? subtext;
  String? sublink;
  String? subtarget;
  String? textAlign;
  String? textVerticalAlign;
  String? textBaseline;
  String? subtextAlign;
  String? subtextVerticalAlign;
  String? subtextBaseline;
  String? backgroundColor;
  String? borderColor;
  double? borderWidth;
  double? borderRadius;
  double? padding;
  double? itemGap;
  ChartTextStyle textStyle;
  ChartTextStyle subtextStyle;
  Color? color;
  double? fontSize;

  TitlesData({
    this.text,
    this.link,
    this.target,
    this.subtext,
    this.sublink,
    this.subtarget,
    this.textAlign,
    this.textVerticalAlign,
    this.textBaseline,
    this.subtextAlign,
    this.subtextVerticalAlign,
    this.subtextBaseline,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.itemGap,
    ChartTextStyle? textStyle,
    ChartTextStyle? subtextStyle,
    this.color,
    this.fontSize,
  }) : textStyle = textStyle ?? ChartTextStyle(),
       subtextStyle = subtextStyle ?? ChartTextStyle();

  factory TitlesData.fromJson(Object? raw) {
    if (raw is TitlesData) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return TitlesData(
      text: JsonValue.string(json['text']),
      link: JsonValue.string(json['link']),
      target: JsonValue.string(json['target']),
      subtext: JsonValue.string(json['subtext']),
      sublink: JsonValue.string(json['sublink']),
      subtarget: JsonValue.string(json['subtarget']),
      textAlign: JsonValue.string(json['textAlign']),
      textVerticalAlign: JsonValue.string(json['textVerticalAlign']),
      textBaseline: JsonValue.string(json['textBaseline']),
      subtextAlign: JsonValue.string(json['subtextAlign']),
      subtextVerticalAlign: JsonValue.string(json['subtextVerticalAlign']),
      subtextBaseline: JsonValue.string(json['subtextBaseline']),
      backgroundColor: JsonValue.string(json['backgroundColor']),
      borderColor: JsonValue.string(json['borderColor']),
      borderWidth: JsonValue.doubleOrNull(json['borderWidth']),
      borderRadius: JsonValue.doubleOrNull(json['borderRadius']),
      padding: JsonValue.doubleOrNull(json['padding']),
      itemGap: JsonValue.doubleOrNull(json['itemGap']),
      textStyle: json['textStyle'] != null
          ? ChartTextStyle.fromJson(json['textStyle'])
          : null,
      subtextStyle: json['subtextStyle'] != null
          ? ChartTextStyle.fromJson(json['subtextStyle'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'link': link,
      'target': target,
      'subtext': subtext,
      'sublink': sublink,
      'subtarget': subtarget,
      'textAlign': textAlign,
      'textVerticalAlign': textVerticalAlign,
      'textBaseline': textBaseline,
      'subtextAlign': subtextAlign,
      'subtextVerticalAlign': subtextVerticalAlign,
      'subtextBaseline': subtextBaseline,
      'backgroundColor': backgroundColor,
      'borderColor': borderColor,
      'borderWidth': borderWidth,
      'borderRadius': borderRadius,
      'padding': padding,
      'itemGap': itemGap,
      'textStyle': textStyle.toJson(),
      'subtextStyle': subtextStyle.toJson(),
    };
  }

  @override
  String toString() {
    return 'TitlesData('
        'text: $text, '
        'link: $link, '
        'target: $target, '
        'subtext: $subtext, '
        'sublink: $sublink, '
        'subtarget: $subtarget, '
        'textAlign: $textAlign, '
        'textVerticalAlign: $textVerticalAlign, '
        'textBaseline: $textBaseline, '
        'subtextAlign: $subtextAlign, '
        'subtextVerticalAlign: $subtextVerticalAlign, '
        'subtextBaseline: $subtextBaseline, '
        'backgroundColor: $backgroundColor, '
        'borderColor: $borderColor, '
        'borderWidth: $borderWidth, '
        'borderRadius: $borderRadius, '
        'padding: $padding, '
        'itemGap: $itemGap, '
        'textStyle: $textStyle, '
        'subtextStyle: $subtextStyle'
        ')';
  }
}
