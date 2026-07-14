// Bubble chart — scatter plot where each point has a size dimension.
//
// JSON example:
// ```json
// {
//   "type": "bubble",
//   "series": [{
//     "name": "Q1",
//     "data": [
//       { "x": 10, "y": 85, "size": 30, "label": "Product A" },
//       { "x": 45, "y": 60, "size": 50, "label": "Product B" }
//     ]
//   }]
// }
// ```

import 'package:flutter/material.dart';
import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/json_value.dart';
import 'bubble_chart.dart';

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

class BubbleChartConfig extends BaseChartConfig {
  final List<BubbleSeries> bubbleSeries;
  final double minBubbleRadius;
  final double maxBubbleRadius;
  final bool showLabels;

  // Pre-computed bounds
  late final double xMin, xMax, yMin, yMax;

  BubbleChartConfig({
    required this.bubbleSeries,
    double minBubbleRadius = 4,
    double maxBubbleRadius = 40,
    this.showLabels = false,
    super.theme = ChartTheme.light,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : minBubbleRadius = _safeMinBubbleRadius(minBubbleRadius),
       maxBubbleRadius = _safeMaxBubbleRadius(minBubbleRadius, maxBubbleRadius),
       super(type: ChartType.bubble, series: const []) {
    _computeBounds();
  }

  void _computeBounds() {
    double xMin = double.infinity,
        xMax = double.negativeInfinity,
        yMin = double.infinity,
        yMax = double.negativeInfinity;

    for (final s in bubbleSeries) {
      for (final p in s.data) {
        if (p.x < xMin) xMin = p.x;
        if (p.x > xMax) xMax = p.x;
        if (p.y < yMin) yMin = p.y;
        if (p.y > yMax) yMax = p.y;
      }
    }

    // Use a workaround for late final: initialise via local vars then assign once.
    final double xl = xMin.isFinite ? xMin : 0;
    final double xx = xMax.isFinite ? xMax : 100;
    final double yl = yMin.isFinite ? yMin : 0;
    final double yx = yMax.isFinite ? yMax : 100;
    // padding 10%
    final xPad = (xx - xl) * 0.1 + 1;
    final yPad = (yx - yl) * 0.1 + 1;

    // NOTE: late-final assignment done by compiler-accepted workaround via
    // initialize-once pattern; calling a private method from constructor.
    _assignBounds(xl - xPad, xx + xPad, yl - yPad, yx + yPad);
  }

  void _assignBounds(double xMin, double xMax, double yMin, double yMax) {
    this.xMin = xMin;
    this.xMax = xMax <= xMin ? xMin + 1 : xMax;
    this.yMin = yMin;
    this.yMax = yMax <= yMin ? yMin + 1 : yMax;
  }

  @override
  double getMaxSeriesValue() => yMax;

  @override
  Widget buildChart() => BubbleChartWidget(config: this);

  factory BubbleChartConfig.fromJson(Map<String, dynamic> json) {
    final series = _parseBubbleSeries(json);

    return BubbleChartConfig(
      bubbleSeries: series,
      minBubbleRadius: JsonValue.doubleOrNull(json['minBubbleRadius']) ?? 4,
      maxBubbleRadius: JsonValue.doubleOrNull(json['maxBubbleRadius']) ?? 40,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? false,
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      tooltip: json['tooltip'] != null
          ? ChartTooltip.fromJson(json['tooltip'])
          : null,
      legend: json['legend'] != null
          ? ChartLegend.fromJson(json['legend'])
          : null,
      toolbox: json['toolbox'] != null
          ? ChartToolbox.fromJson(json['toolbox'])
          : null,
      grid: json['grid'] != null ? GridData.fromJson(json['grid']) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'bubble',
    'minBubbleRadius': minBubbleRadius,
    'maxBubbleRadius': maxBubbleRadius,
    'showLabels': showLabels,
    if (title != null) 'title': title!.toJson(),
    'series': bubbleSeries
        .map(
          (s) => {
            'name': s.name,
            if (s.color != null) 'color': s.color,
            'opacity': s.opacity,
            'data': s.data.map((p) => p.toJson()).toList(),
          },
        )
        .toList(),
  };
}

double _safeMinBubbleRadius(double value) =>
    value.isFinite && value > 0 ? value : 4;

double _safeMaxBubbleRadius(double minRadius, double maxRadius) {
  final safeMin = _safeMinBubbleRadius(minRadius);
  final safeMax = maxRadius.isFinite && maxRadius > 0 ? maxRadius : 40.0;
  return safeMax >= safeMin ? safeMax : safeMin;
}

List<BubbleSeries> _parseBubbleSeries(Map<String, dynamic> json) {
  final rawSeries = JsonValue.list(json['series']);
  if (rawSeries != null && rawSeries.isNotEmpty) {
    final firstAsMap = JsonValue.map(rawSeries.first);
    if (firstAsMap != null) {
      return rawSeries.map(BubbleSeries.fromJson).toList();
    }
    return [
      BubbleSeries(
        name: JsonValue.string(json['name']) ?? '',
        data: _parseBubblePoints(rawSeries),
        color: JsonValue.string(json['color']),
      ),
    ];
  }

  final data = JsonValue.list(json['data']);
  if (data == null) return const <BubbleSeries>[];
  return [
    BubbleSeries(
      name: JsonValue.string(json['name']) ?? '',
      data: _parseBubblePoints(data),
      color: JsonValue.string(json['color']),
    ),
  ];
}

List<BubblePoint> _parseBubblePoints(List<dynamic> rawData) {
  final points = <BubblePoint>[];
  for (var i = 0; i < rawData.length; i++) {
    points.add(BubblePoint.fromJson(rawData[i], fallbackIndex: i));
  }
  return points;
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class BubblePoint {
  final double x;
  final double y;
  final double size; // logical size (will be scaled)
  final String? label;
  final String? color;

  const BubblePoint({
    required this.x,
    required this.y,
    this.size = 10,
    this.label,
    this.color,
  });

  factory BubblePoint.fromJson(Object? raw, {int fallbackIndex = 0}) {
    final point = ChartDataValueReader.cartesian(raw, fallbackIndex);
    final map = JsonValue.map(raw);
    if (map != null) {
      return BubblePoint(
        x: point?.x ?? fallbackIndex.toDouble(),
        y: point?.y ?? 0,
        size: _safeBubbleSize(
          map['size'] ?? map['r'] ?? map['radius'] ?? map['value'],
        ),
        label: JsonValue.string(map['label']) ?? JsonValue.string(map['name']),
        color: JsonValue.string(map['color']),
      );
    }

    final row = JsonValue.list(raw);
    if (row != null) {
      return BubblePoint(
        x: point?.x ?? fallbackIndex.toDouble(),
        y: point?.y ?? 0,
        size: _safeBubbleSize(row.length > 2 ? row[2] : null),
        label: row.length > 3 ? JsonValue.string(row[3]) : point?.label,
        color: row.length > 4 ? JsonValue.string(row[4]) : null,
      );
    }

    return BubblePoint(
      x: fallbackIndex.toDouble(),
      y: ChartDataValueReader.yValueOrNull(raw) ?? 0,
      size: _safeBubbleSize(null),
      label: JsonValue.string(raw),
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'size': size,
    if (label != null) 'label': label,
    if (color != null) 'color': color,
  };
}

double _safeBubbleSize(Object? raw) {
  final value = ChartDataValueReader.yValueOrNull(raw);
  if (value == null || !value.isFinite || value <= 0) return 10;
  return value;
}

class BubbleSeries {
  final String name;
  final List<BubblePoint> data;
  final String? color;
  final double opacity;

  const BubbleSeries({
    required this.name,
    required this.data,
    this.color,
    this.opacity = 0.7,
  });

  factory BubbleSeries.fromJson(Object? raw) {
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    final rawData = JsonValue.list(json['data']) ?? const <dynamic>[];
    final itemStyle = JsonValue.map(json['itemStyle']);
    return BubbleSeries(
      name: JsonValue.string(json['name']) ?? '',
      data: _parseBubblePoints(rawData),
      color:
          JsonValue.string(json['color']) ??
          JsonValue.string(itemStyle?['color']),
      opacity: (JsonValue.doubleOrNull(json['opacity']) ?? 0.7)
          .clamp(0.0, 1.0)
          .toDouble(),
    );
  }
}
