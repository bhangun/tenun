import 'package:flutter/material.dart';

enum SimpleChartReferenceLineStyle { solid, dashed, dotted }

class SimpleChartReferenceLine {
  final double value;
  final String? label;
  final Color? color;
  final double strokeWidth;
  final SimpleChartReferenceLineStyle lineStyle;
  final bool showLabel;

  const SimpleChartReferenceLine({
    required this.value,
    this.label,
    this.color,
    this.strokeWidth = 1.4,
    this.lineStyle = SimpleChartReferenceLineStyle.dashed,
    this.showLabel = true,
  }) : assert(strokeWidth > 0);
}

class SimpleChartReferenceBand {
  final double from;
  final double to;
  final String? label;
  final Color? color;
  final double opacity;
  final bool showLabel;

  const SimpleChartReferenceBand({
    required this.from,
    required this.to,
    this.label,
    this.color,
    this.opacity = 0.1,
    this.showLabel = true,
  }) : assert(opacity >= 0 && opacity <= 1);
}
