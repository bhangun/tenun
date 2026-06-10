import 'text_style.dart';
import 'json_value.dart';

enum TooltipTrigger { item, axis, none }

enum TooltipRenderMode { html, richText }

class ChartTooltip {
  bool show;
  TooltipTrigger? trigger; // 'item', 'axis', or 'none'
  AxisPointer? axisPointer;
  String? formatter; // Can be a string or function
  double? showDelay;
  double? hideDelay;
  double? transitionDuration;
  bool? enterable;
  bool? confine;
  TooltipRenderMode? renderMode; // 'html' or 'richText'
  String? backgroundColor;
  String? borderColor;
  double? borderWidth;
  double? borderRadius;
  double? padding;
  ChartTextStyle? textStyle;
  String? extraCssText;
  bool numberFormat;
  String textColor;
  int? precision;
  double? fontSize;

  ChartTooltip({
    this.show = true,
    this.trigger = TooltipTrigger.item,
    this.axisPointer,
    this.formatter,
    this.showDelay,
    this.hideDelay,
    this.transitionDuration,
    this.enterable,
    this.confine,
    this.renderMode = TooltipRenderMode.html,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.textStyle,
    this.extraCssText,
    this.numberFormat = false,
    this.textColor = 'black',
    this.precision,
    this.fontSize,
  });

  factory ChartTooltip.fromJson(Object? raw) {
    if (raw is ChartTooltip) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return ChartTooltip(
      show: JsonValue.boolOrNull(json['show']) ?? true,
      trigger: _parseTooltipTrigger(json['trigger']),
      axisPointer: json['axisPointer'] != null
          ? AxisPointer.fromJson(json['axisPointer'])
          : null,
      formatter: JsonValue.string(json['formatter']),
      showDelay: JsonValue.doubleOrNull(json['showDelay']),
      hideDelay: JsonValue.doubleOrNull(json['hideDelay']),
      transitionDuration: JsonValue.doubleOrNull(json['transitionDuration']),
      enterable: JsonValue.boolOrNull(json['enterable']),
      confine: JsonValue.boolOrNull(json['confine']),
      renderMode: _parseTooltipRenderMode(json['renderMode']),
      backgroundColor: JsonValue.string(json['backgroundColor']),
      borderColor: JsonValue.string(json['borderColor']),
      borderWidth: JsonValue.doubleOrNull(json['borderWidth']),
      borderRadius: JsonValue.doubleOrNull(json['borderRadius']),
      padding: JsonValue.doubleOrNull(json['padding']),
      textStyle: json['textStyle'] != null
          ? ChartTextStyle.fromJson(json['textStyle'])
          : null,
      extraCssText: JsonValue.string(json['extraCssText']),
      textColor: JsonValue.string(json['textColor']) ?? 'black',
      precision: JsonValue.intOrNull(json['precision']),
      fontSize: JsonValue.doubleOrNull(json['fontSize']),
    );
  }

  dynamic get valueFormatter => null;

  static TooltipTrigger? _parseTooltipTrigger(dynamic trigger) {
    if (trigger is TooltipTrigger) return trigger;
    if (trigger is! String) return TooltipTrigger.item;
    switch (trigger.toLowerCase()) {
      case 'item':
        return TooltipTrigger.item;
      case 'axis':
        return TooltipTrigger.axis;
      case 'none':
        return TooltipTrigger.none;
      default:
        return TooltipTrigger.item;
    }
  }

  static TooltipRenderMode? _parseTooltipRenderMode(dynamic renderMode) {
    if (renderMode is TooltipRenderMode) return renderMode;
    if (renderMode is! String) return TooltipRenderMode.html;
    switch (renderMode.toLowerCase()) {
      case 'html':
        return TooltipRenderMode.html;
      case 'richtext':
      case 'rich_text':
        return TooltipRenderMode.richText;
      default:
        return TooltipRenderMode.html;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'show': show,
      'trigger': trigger,
      'axisPointer': axisPointer?.toJson(),
      'formatter': formatter,
      'showDelay': showDelay,
      'hideDelay': hideDelay,
      'transitionDuration': transitionDuration,
      'enterable': enterable,
      'confine': confine,
      'renderMode': renderMode,
      'backgroundColor': backgroundColor,
      'borderColor': borderColor,
      'borderWidth': borderWidth,
      'borderRadius': borderRadius,
      'padding': padding,
      'textStyle': textStyle,
      'extraCssText': extraCssText,
    };
  }

  @override
  String toString() {
    return 'ChartTooltip('
        'show: $show, '
        'trigger: $trigger, '
        'axisPointer: $axisPointer, '
        'formatter: $formatter, '
        'showDelay: $showDelay, '
        'hideDelay: $hideDelay, '
        'transitionDuration: $transitionDuration, '
        'enterable: $enterable, '
        'confine: $confine, '
        'renderMode: $renderMode, '
        'backgroundColor: $backgroundColor, '
        'borderColor: $borderColor, '
        'borderWidth: $borderWidth, '
        'borderRadius: $borderRadius, '
        'padding: $padding, '
        'textStyle: $textStyle, '
        'extraCssText: $extraCssText'
        ')';
  }
}

class AxisPointer {
  String? type; // 'line', 'shadow', 'cross', or 'none'
  LineStyle? lineStyle;
  ShadowStyle? shadowStyle;

  AxisPointer({this.type, this.lineStyle, this.shadowStyle});

  factory AxisPointer.fromJson(Object? raw) {
    if (raw is AxisPointer) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return AxisPointer(
      type: JsonValue.string(json['type']),
      lineStyle: json['lineStyle'] != null
          ? LineStyle.fromJson(json['lineStyle'])
          : null,
      shadowStyle: json['shadowStyle'] != null
          ? ShadowStyle.fromJson(json['shadowStyle'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'lineStyle': lineStyle?.toJson(),
      'shadowStyle': shadowStyle?.toJson(),
    };
  }
}

class LineStyle {
  String? color;
  double? width;
  String? type; // 'solid', 'dashed', or 'dotted'

  LineStyle({this.color, this.width, this.type});

  factory LineStyle.fromJson(Object? raw) {
    if (raw is LineStyle) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return LineStyle(
      color: JsonValue.string(json['color']),
      width: JsonValue.doubleOrNull(json['width']),
      type: JsonValue.string(json['type']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'color': color, 'width': width, 'type': type};
  }
}

class ShadowStyle {
  String? color;
  double? shadowBlur;
  double? shadowOffsetX;
  double? shadowOffsetY;

  ShadowStyle({
    this.color,
    this.shadowBlur,
    this.shadowOffsetX,
    this.shadowOffsetY,
  });

  factory ShadowStyle.fromJson(Object? raw) {
    if (raw is ShadowStyle) return raw;
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return ShadowStyle(
      color: JsonValue.string(json['color']),
      shadowBlur: JsonValue.doubleOrNull(json['shadowBlur']),
      shadowOffsetX: JsonValue.doubleOrNull(json['shadowOffsetX']),
      shadowOffsetY: JsonValue.doubleOrNull(json['shadowOffsetY']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color,
      'shadowBlur': shadowBlur,
      'shadowOffsetX': shadowOffsetX,
      'shadowOffsetY': shadowOffsetY,
    };
  }
}
