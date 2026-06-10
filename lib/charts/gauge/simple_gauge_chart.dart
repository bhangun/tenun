import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleGaugeValueFormatter = String Function(double value);
typedef SimpleGaugeTapCallback =
    void Function(double value, double? targetValue);
typedef SimpleGaugeTooltipBuilder =
    Widget Function(
      BuildContext context,
      double value,
      double? targetValue,
      String formattedValue,
      String? formattedTarget,
    );

class SimpleGaugeRange {
  final double from;
  final double to;
  final Color? color;
  final String? label;

  const SimpleGaugeRange({
    required this.from,
    required this.to,
    this.color,
    this.label,
  });
}

/// A compact radial KPI gauge for status, progress, readiness, and target
/// tracking.
class SimpleGaugeChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(16, 12, 16, 16);

  final String label;
  final double value;
  final double minValue;
  final double maxValue;
  final double? targetValue;
  final String? unit;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<SimpleGaugeRange> ranges;
  final Color? valueColor;
  final Color? targetColor;
  final Color? rangeColor;
  final Color? trackColor;
  final Color? needleColor;
  final Color? tickColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showRanges;
  final bool showTicks;
  final bool showNeedle;
  final bool showTarget;
  final bool showValue;
  final bool showTooltip;
  final bool showActiveGauge;
  final double startAngle;
  final double sweepAngle;
  final double? trackWidth;
  final SimpleGaugeValueFormatter? valueFormatter;
  final SimpleGaugeTapCallback? onGaugeTap;
  final SimpleGaugeTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleGaugeChart({
    super.key,
    required this.label,
    required this.value,
    this.minValue = 0,
    this.maxValue = 100,
    this.targetValue,
    this.unit,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 240,
    this.padding = _defaultPadding,
    this.ranges = const [],
    this.valueColor,
    this.targetColor,
    this.rangeColor,
    this.trackColor,
    this.needleColor,
    this.tickColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showRanges = true,
    this.showTicks = true,
    this.showNeedle = true,
    this.showTarget = true,
    this.showValue = true,
    this.showTooltip = true,
    this.showActiveGauge = true,
    this.startAngle = math.pi * 0.78,
    this.sweepAngle = math.pi * 1.44,
    this.trackWidth,
    this.valueFormatter,
    this.onGaugeTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 800),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(minValue != maxValue),
       assert(trackWidth == null || trackWidth > 0),
       assert(sweepAngle > 0 && sweepAngle <= math.pi * 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleGaugeVisuals.resolve(style, colorScheme);
    final validValue = value.isFinite;
    final formatter =
        valueFormatter ??
        (item) => '${_defaultValueFormatter(item)}${unit ?? ''}';
    final formattedTarget = targetValue != null && targetValue!.isFinite
        ? formatter(targetValue!)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (!validValue) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Gauge chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedLabelStyle =
            labelStyle ??
            theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ) ??
            TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12);
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(formatter, formattedTarget),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleGaugeChartView(
            width: width,
            height: chartHeight,
            label: label,
            value: value,
            minValue: minValue,
            maxValue: maxValue,
            targetValue: targetValue,
            padding: padding,
            ranges: ranges,
            valueColor: valueColor ?? visuals.valueColor,
            targetColor: targetColor ?? visuals.targetColor,
            rangeColor: rangeColor ?? visuals.rangeColor,
            trackColor: trackColor ?? visuals.trackColor,
            needleColor: needleColor ?? visuals.needleColor,
            tickColor: tickColor ?? visuals.tickColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showRanges: showRanges,
            showTicks: showTicks,
            showNeedle: showNeedle,
            showTarget: showTarget,
            showValue: showValue,
            showTooltip: showTooltip,
            showActiveGauge: showActiveGauge,
            startAngle: startAngle,
            sweepAngle: sweepAngle,
            trackWidth: trackWidth ?? visuals.trackWidth,
            valueFormatter: formatter,
            onGaugeTap: onGaugeTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(
    SimpleGaugeValueFormatter formatter,
    String? formattedTarget,
  ) {
    final rangeText = 'from ${formatter(minValue)} to ${formatter(maxValue)}';
    final targetText = formattedTarget == null
        ? ''
        : ', target $formattedTarget';
    return 'Gauge chart. $label ${formatter(value)} $rangeText$targetText.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleGaugeChartView extends StatefulWidget {
  final double width;
  final double height;
  final String label;
  final double value;
  final double minValue;
  final double maxValue;
  final double? targetValue;
  final EdgeInsets padding;
  final List<SimpleGaugeRange> ranges;
  final Color valueColor;
  final Color targetColor;
  final Color rangeColor;
  final Color trackColor;
  final Color needleColor;
  final Color tickColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showRanges;
  final bool showTicks;
  final bool showNeedle;
  final bool showTarget;
  final bool showValue;
  final bool showTooltip;
  final bool showActiveGauge;
  final double startAngle;
  final double sweepAngle;
  final double trackWidth;
  final SimpleGaugeValueFormatter valueFormatter;
  final SimpleGaugeTapCallback? onGaugeTap;
  final SimpleGaugeTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleGaugeChartView({
    required this.width,
    required this.height,
    required this.label,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.targetValue,
    required this.padding,
    required this.ranges,
    required this.valueColor,
    required this.targetColor,
    required this.rangeColor,
    required this.trackColor,
    required this.needleColor,
    required this.tickColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showRanges,
    required this.showTicks,
    required this.showNeedle,
    required this.showTarget,
    required this.showValue,
    required this.showTooltip,
    required this.showActiveGauge,
    required this.startAngle,
    required this.sweepAngle,
    required this.trackWidth,
    required this.valueFormatter,
    required this.onGaugeTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleGaugeChartView> createState() => _SimpleGaugeChartViewState();
}

class _SimpleGaugeChartViewState extends State<_SimpleGaugeChartView> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveGauge ||
        widget.onGaugeTap != null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final chart = TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: widget.animationDuration,
            curve: widget.animationCurve,
            builder: (context, progress, child) {
              return CustomPaint(
                painter: _SimpleGaugePainter(
                  label: widget.label,
                  value: widget.value,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  targetValue: widget.targetValue,
                  padding: widget.padding,
                  ranges: widget.ranges,
                  valueColor: widget.valueColor,
                  targetColor: widget.targetColor,
                  rangeColor: widget.rangeColor,
                  trackColor: widget.trackColor,
                  needleColor: widget.needleColor,
                  tickColor: widget.tickColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showRanges: widget.showRanges,
                  showTicks: widget.showTicks,
                  showNeedle: widget.showNeedle,
                  showTarget: widget.showTarget,
                  showValue: widget.showValue,
                  startAngle: widget.startAngle,
                  sweepAngle: widget.sweepAngle,
                  trackWidth: widget.trackWidth,
                  valueFormatter: widget.valueFormatter,
                  active: widget.showActiveGauge && _active,
                  progress: progress,
                ),
              );
            },
          );

          if (!interactionEnabled) return chart;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (event) =>
                      _setActive(_hitTest(event.localPosition, size)),
                  onExit: (_) => _setActive(false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition, size);
                      _setActive(hit);
                      if (hit) {
                        widget.onGaugeTap?.call(
                          widget.value,
                          widget.targetValue,
                        );
                      }
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _active) _buildTooltip(context, size),
            ],
          );
        },
      ),
    );
  }

  void _setActive(bool active) {
    if (_active == active) return;
    setState(() => _active = active);
  }

  bool _hitTest(Offset position, Size size) {
    final layout = _GaugeLayout.resolve(size, widget.padding);
    if (!layout.content.inflate(8).contains(position)) return false;
    final distance = (position - layout.center).distance;
    return distance <= layout.radius + widget.trackWidth * 1.8 ||
        layout.centerTextRect.inflate(16).contains(position);
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final layout = _GaugeLayout.resolve(size, widget.padding);
    final formattedValue = widget.valueFormatter(widget.value);
    final formattedTarget =
        widget.targetValue != null && widget.targetValue!.isFinite
        ? widget.valueFormatter(widget.targetValue!)
        : null;
    const tooltipWidth = 172.0;
    const tooltipHeight = 72.0;
    final left = (layout.center.dx + 16)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (layout.center.dy - tooltipHeight - 12)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            widget.value,
            widget.targetValue,
            formattedValue,
            formattedTarget,
          ) ??
          _DefaultGaugeTooltip(
            color: widget.valueColor,
            title: widget.label,
            value: formattedValue,
            target: formattedTarget,
          ),
    );
  }
}

class _SimpleGaugePainter extends CustomPainter {
  final String label;
  final double value;
  final double minValue;
  final double maxValue;
  final double? targetValue;
  final EdgeInsets padding;
  final List<SimpleGaugeRange> ranges;
  final Color valueColor;
  final Color targetColor;
  final Color rangeColor;
  final Color trackColor;
  final Color needleColor;
  final Color tickColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showRanges;
  final bool showTicks;
  final bool showNeedle;
  final bool showTarget;
  final bool showValue;
  final double startAngle;
  final double sweepAngle;
  final double trackWidth;
  final SimpleGaugeValueFormatter valueFormatter;
  final bool active;
  final double progress;

  const _SimpleGaugePainter({
    required this.label,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.targetValue,
    required this.padding,
    required this.ranges,
    required this.valueColor,
    required this.targetColor,
    required this.rangeColor,
    required this.trackColor,
    required this.needleColor,
    required this.tickColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showRanges,
    required this.showTicks,
    required this.showNeedle,
    required this.showTarget,
    required this.showValue,
    required this.startAngle,
    required this.sweepAngle,
    required this.trackWidth,
    required this.valueFormatter,
    required this.active,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _GaugeLayout.resolve(size, padding);
    if (layout.radius <= 0) return;

    final width = math.min(trackWidth, layout.radius * 0.38);
    final rect = Rect.fromCircle(center: layout.center, radius: layout.radius);
    final animatedValue = minValue + (value - minValue) * progress;
    final valueT = _normalize(animatedValue);
    final gaugeColor = _resolvedValueColor(animatedValue);

    _drawTrack(canvas, rect, width);
    if (showRanges && ranges.isNotEmpty) {
      _drawRanges(canvas, rect, width);
    }
    _drawValueArc(canvas, rect, width, valueT, gaugeColor);
    if (showTicks) {
      _drawTicks(canvas, layout, width);
    }
    if (showTarget && targetValue != null && targetValue!.isFinite) {
      _drawTarget(canvas, layout, width, targetValue!);
    }
    if (showNeedle) {
      _drawNeedle(canvas, layout, valueT);
    }
    if (showValue) {
      _drawCenterText(canvas, layout, gaugeColor);
    }
  }

  void _drawTrack(Canvas canvas, Rect rect, double width) {
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawRanges(Canvas canvas, Rect rect, double width) {
    for (var index = 0; index < ranges.length; index++) {
      final range = ranges[index];
      if (!range.from.isFinite || !range.to.isFinite) continue;
      final from = _normalize(math.min(range.from, range.to));
      final to = _normalize(math.max(range.from, range.to));
      final sweep = math.max(0.0, (to - from) * sweepAngle);
      if (sweep <= 0) continue;
      final color = range.color ?? rangeColor;
      canvas.drawArc(
        rect,
        startAngle + from * sweepAngle,
        sweep,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  void _drawValueArc(
    Canvas canvas,
    Rect rect,
    double width,
    double valueT,
    Color color,
  ) {
    if (valueT <= 0) return;
    if (active) {
      canvas.drawArc(
        rect.inflate(2),
        startAngle,
        valueT * sweepAngle,
        false,
        Paint()
          ..color = (activeColor ?? color).withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 8
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawArc(
      rect,
      startAngle,
      valueT * sweepAngle,
      false,
      Paint()
        ..color = color.withValues(alpha: active ? 1 : 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? width + 2 : width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawTicks(Canvas canvas, _GaugeLayout layout, double width) {
    final paint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const tickCount = 6;
    for (var index = 0; index <= tickCount; index++) {
      final t = index / tickCount;
      final angle = startAngle + t * sweepAngle;
      final outer = _point(layout.center, layout.radius + width / 2 + 5, angle);
      final inner = _point(layout.center, layout.radius + width / 2 - 4, angle);
      canvas.drawLine(inner, outer, paint);
    }

    _drawEdgeLabel(canvas, layout, minValue, startAngle, TextAlign.left);
    _drawEdgeLabel(
      canvas,
      layout,
      maxValue,
      startAngle + sweepAngle,
      TextAlign.right,
    );
  }

  void _drawEdgeLabel(
    Canvas canvas,
    _GaugeLayout layout,
    double item,
    double angle,
    TextAlign align,
  ) {
    final anchor = _point(
      layout.center,
      layout.radius + trackWidth + 14,
      angle,
    );
    final painter = _textPainter(
      valueFormatter(item),
      labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 12) * 0.88),
      maxWidth: 64,
      textAlign: align,
    )..layout(maxWidth: 64);
    final x = _safeClamp(
      anchor.dx - painter.width / 2,
      layout.content.left + 2,
      layout.content.right - painter.width - 2,
    );
    final y = _safeClamp(
      anchor.dy - painter.height / 2,
      layout.content.top + 2,
      layout.content.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
  }

  void _drawTarget(
    Canvas canvas,
    _GaugeLayout layout,
    double width,
    double item,
  ) {
    final angle = startAngle + _normalize(item) * sweepAngle;
    final outer = _point(layout.center, layout.radius + width / 2 + 7, angle);
    final inner = _point(layout.center, layout.radius - width / 2 - 7, angle);
    canvas.drawLine(
      inner,
      outer,
      Paint()
        ..color = targetColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    final labelPoint = _point(layout.center, layout.radius + width + 18, angle);
    final painter = _textPainter(
      valueFormatter(item),
      labelStyle.copyWith(
        color: targetColor,
        fontSize: (labelStyle.fontSize ?? 12) * 0.9,
        fontWeight: FontWeight.w800,
      ),
      maxWidth: 72,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 72);
    final x = _safeClamp(
      labelPoint.dx - painter.width / 2,
      layout.content.left + 2,
      layout.content.right - painter.width - 2,
    );
    final y = _safeClamp(
      labelPoint.dy - painter.height / 2,
      layout.content.top + 2,
      layout.content.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
  }

  void _drawNeedle(Canvas canvas, _GaugeLayout layout, double valueT) {
    final angle = startAngle + valueT * sweepAngle;
    final tip = _point(layout.center, layout.radius * 0.72, angle);
    canvas.drawLine(
      layout.center,
      tip,
      Paint()
        ..color = needleColor.withValues(alpha: 0.82)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      layout.center,
      5.5,
      Paint()..color = needleColor.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      layout.center,
      2.2,
      Paint()..color = Colors.white.withValues(alpha: 0.86),
    );
  }

  void _drawCenterText(Canvas canvas, _GaugeLayout layout, Color color) {
    final valuePainter = _textPainter(
      valueFormatter(value),
      valueStyle.copyWith(color: color),
      maxWidth: layout.radius * 1.35,
      textAlign: TextAlign.center,
    )..layout(maxWidth: layout.radius * 1.35);
    final labelPainter = _textPainter(
      label,
      labelStyle,
      maxWidth: layout.radius * 1.45,
      textAlign: TextAlign.center,
    )..layout(maxWidth: layout.radius * 1.45);
    final top =
        layout.center.dy - (valuePainter.height + labelPainter.height + 3) / 2;
    valuePainter.paint(
      canvas,
      Offset(layout.center.dx - valuePainter.width / 2, top),
    );
    labelPainter.paint(
      canvas,
      Offset(
        layout.center.dx - labelPainter.width / 2,
        top + valuePainter.height + 3,
      ),
    );
  }

  Color _resolvedValueColor(double item) {
    if (showRanges && ranges.isNotEmpty) {
      for (final range in ranges) {
        final lower = math.min(range.from, range.to);
        final upper = math.max(range.from, range.to);
        if (item >= lower && item <= upper && range.color != null) {
          return range.color!;
        }
      }
    }
    return valueColor;
  }

  double _normalize(double item) {
    final lower = math.min(minValue, maxValue);
    final upper = math.max(minValue, maxValue);
    return ((item - lower) / (upper - lower)).clamp(0.0, 1.0).toDouble();
  }

  Offset _point(Offset center, double radius, double angle) {
    return Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }

  double _safeClamp(double value, double lower, double upper) {
    if (lower > upper) return lower;
    return value.clamp(lower, upper).toDouble();
  }

  TextPainter _textPainter(
    String text,
    TextStyle style, {
    double? maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
      ellipsis: maxWidth == null ? null : '...',
    );
  }

  @override
  bool shouldRepaint(covariant _SimpleGaugePainter oldDelegate) {
    return oldDelegate.label != label ||
        oldDelegate.value != value ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.targetValue != targetValue ||
        oldDelegate.padding != padding ||
        oldDelegate.ranges != ranges ||
        oldDelegate.valueColor != valueColor ||
        oldDelegate.targetColor != targetColor ||
        oldDelegate.rangeColor != rangeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.needleColor != needleColor ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showRanges != showRanges ||
        oldDelegate.showTicks != showTicks ||
        oldDelegate.showNeedle != showNeedle ||
        oldDelegate.showTarget != showTarget ||
        oldDelegate.showValue != showValue ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.trackWidth != trackWidth ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.active != active ||
        oldDelegate.progress != progress;
  }
}

class _GaugeLayout {
  final Rect content;
  final Offset center;
  final double radius;
  final Rect centerTextRect;

  const _GaugeLayout({
    required this.content,
    required this.center,
    required this.radius,
    required this.centerTextRect,
  });

  factory _GaugeLayout.resolve(Size size, EdgeInsets padding) {
    final content = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    final radius = math.max(
      0.0,
      math.min(content.width * 0.42, content.height * 0.48),
    );
    final center = Offset(
      content.center.dx,
      content.top + content.height * 0.6,
    );
    return _GaugeLayout(
      content: content,
      center: center,
      radius: radius,
      centerTextRect: Rect.fromCenter(
        center: center,
        width: radius * 1.45,
        height: radius * 0.72,
      ),
    );
  }
}

class _SimpleGaugeVisuals {
  final Color valueColor;
  final Color targetColor;
  final Color rangeColor;
  final Color trackColor;
  final Color needleColor;
  final Color tickColor;
  final double trackWidth;

  const _SimpleGaugeVisuals({
    required this.valueColor,
    required this.targetColor,
    required this.rangeColor,
    required this.trackColor,
    required this.needleColor,
    required this.tickColor,
    required this.trackWidth,
  });

  factory _SimpleGaugeVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleGaugeVisuals(
          valueColor: colorScheme.primary,
          targetColor: colorScheme.secondary,
          rangeColor: colorScheme.primary,
          trackColor: colorScheme.outline.withValues(alpha: 0.12),
          needleColor: colorScheme.onSurface,
          tickColor: colorScheme.outline.withValues(alpha: 0.56),
          trackWidth: 18,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleGaugeVisuals(
          valueColor: colorScheme.primary,
          targetColor: colorScheme.onSurfaceVariant,
          rangeColor: colorScheme.primary,
          trackColor: colorScheme.outline.withValues(alpha: 0.18),
          needleColor: colorScheme.onSurfaceVariant,
          tickColor: colorScheme.outline.withValues(alpha: 0.7),
          trackWidth: 15,
        );
      case SimpleBarChartStyle.education:
        return _SimpleGaugeVisuals(
          valueColor: colorScheme.secondary,
          targetColor: colorScheme.tertiary,
          rangeColor: colorScheme.secondary,
          trackColor: colorScheme.outline.withValues(alpha: 0.16),
          needleColor: colorScheme.onSurface,
          tickColor: colorScheme.outline.withValues(alpha: 0.62),
          trackWidth: 17,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleGaugeVisuals(
          valueColor: colorScheme.tertiary,
          targetColor: colorScheme.primary,
          rangeColor: colorScheme.tertiary,
          trackColor: colorScheme.outline.withValues(alpha: 0.1),
          needleColor: colorScheme.onSurface,
          tickColor: colorScheme.outline.withValues(alpha: 0.5),
          trackWidth: 20,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleGaugeVisuals(
          valueColor: colorScheme.primary,
          targetColor: colorScheme.secondary,
          rangeColor: colorScheme.primary,
          trackColor: colorScheme.outline.withValues(alpha: 0.14),
          needleColor: colorScheme.onSurface,
          tickColor: colorScheme.outline.withValues(alpha: 0.58),
          trackWidth: 17,
        );
    }
  }
}

class _DefaultGaugeTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String? target;

  const _DefaultGaugeTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onInverseSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    target == null ? value : '$value / target $target',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
