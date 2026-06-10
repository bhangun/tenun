import 'json_value.dart';

enum FontStyle { normal, italic, oblique }

enum FontWeight {
  normal,
  bold,
  bolder,
  lighter,
  w100,
  w200,
  w300,
  w400,
  w500,
  w600,
  w700,
  w800,
  w900,
}

enum Align { top, middle, bottom }

class ChartTextStyle {
  final String color;
  final FontStyle? fontStyle;
  final FontWeight? fontWeight;
  final String? fontFamily;
  final double? fontSize;
  final Align? align;
  final Align? verticalAlign;
  final double? lineHeight;
  final String? backgroundColor;
  final String? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final double? padding;

  ChartTextStyle({
    this.color = 'black',
    this.fontStyle = FontStyle.normal,
    this.fontWeight = FontWeight.normal,
    this.fontFamily = 'sans-serif',
    this.fontSize = 12.0,
    this.align = Align.middle,
    this.verticalAlign = Align.middle,
    this.lineHeight = 1.2,
    this.backgroundColor = 'transparent',
    this.borderColor = 'black',
    this.borderWidth = 0.0,
    this.borderRadius = 0.0,
    this.padding = 0.0,
  });

  factory ChartTextStyle.fromJson(Object? raw) {
    if (raw is ChartTextStyle) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return ChartTextStyle(
      color: JsonValue.string(json['color']) ?? 'black',
      fontStyle: JsonValue.enumValue(FontStyle.values, json['fontStyle']),
      fontWeight: JsonValue.enumValue(FontWeight.values, json['fontWeight']),
      fontFamily: JsonValue.string(json['fontFamily']) ?? 'sans-serif',
      fontSize: JsonValue.doubleOrNull(json['fontSize']),
      align: JsonValue.enumValue(Align.values, json['align']),
      verticalAlign: JsonValue.enumValue(Align.values, json['verticalAlign']),
      lineHeight: JsonValue.doubleOrNull(json['lineHeight']),
      backgroundColor:
          JsonValue.string(json['backgroundColor']) ?? 'transparent',
      borderColor: JsonValue.string(json['borderColor']) ?? 'black',
      borderWidth: JsonValue.doubleOrNull(json['borderWidth']),
      borderRadius: JsonValue.doubleOrNull(json['borderRadius']),
      padding: JsonValue.doubleOrNull(json['padding']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color,
      'fontStyle': fontStyle,
      'fontWeight': fontWeight,
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'align': align,
      'verticalAlign': verticalAlign,
      'lineHeight': lineHeight,
      'backgroundColor': backgroundColor,
      'borderColor': borderColor,
      'borderWidth': borderWidth,
      'borderRadius': borderRadius,
      'padding': padding,
    };
  }

  @override
  String toString() {
    return 'ChartTextStyle('
        'color: $color, '
        'fontStyle: $fontStyle, '
        'fontWeight: $fontWeight, '
        'fontFamily: $fontFamily, '
        'fontSize: $fontSize, '
        'align: $align, '
        'verticalAlign: $verticalAlign, '
        'lineHeight: $lineHeight, '
        'backgroundColor: $backgroundColor, '
        'borderColor: $borderColor, '
        'borderWidth: $borderWidth, '
        'borderRadius: $borderRadius, '
        'padding: $padding'
        ')';
  }
}
