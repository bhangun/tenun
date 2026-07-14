import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleSunburstValueFormatter = String Function(double value);
typedef SimpleSunburstTapCallback =
    void Function(
      SimpleSunburstData data,
      List<SimpleSunburstData> path,
      double value,
      double share,
    );
typedef SimpleSunburstTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleSunburstData data,
      List<SimpleSunburstData> path,
      String formattedValue,
      String formattedShare,
    );

class SimpleSunburstData {
  final String label;
  final double value;
  final List<SimpleSunburstData> children;
  final Color? color;

  const SimpleSunburstData({
    required this.label,
    this.value = 0,
    this.children = const [],
    this.color,
  });
}

/// A lightweight radial hierarchy chart for nested part-to-whole breakdowns.
class SimpleSunburstChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.all(12);

  final List<SimpleSunburstData> data;
  final SimpleBarChartStyle style;
  final double? totalValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? segmentColor;
  final Color? borderColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final String? centerLabel;
  final bool showLabels;
  final bool showValues;
  final bool showParentLabels;
  final bool showTooltip;
  final bool showActiveSegment;
  final int maxDepth;
  final double innerRadiusFactor;
  final double segmentGap;
  final double minLabelSweep;
  final double startAngleDegrees;
  final SimpleSunburstValueFormatter? valueFormatter;
  final SimpleSunburstValueFormatter? percentFormatter;
  final SimpleSunburstTapCallback? onSegmentTap;
  final SimpleSunburstTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleSunburstChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.totalValue,
    this.height = 280,
    this.padding = _defaultPadding,
    this.palette,
    this.segmentColor,
    this.borderColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.centerLabel,
    this.showLabels = true,
    this.showValues = true,
    this.showParentLabels = true,
    this.showTooltip = true,
    this.showActiveSegment = true,
    this.maxDepth = 3,
    this.innerRadiusFactor = 0.2,
    this.segmentGap = 1.4,
    this.minLabelSweep = 12,
    this.startAngleDegrees = -90,
    this.valueFormatter,
    this.percentFormatter,
    this.onSegmentTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(totalValue == null || totalValue > 0),
       assert(maxDepth >= 1),
       assert(innerRadiusFactor >= 0 && innerRadiusFactor < 0.9),
       assert(segmentGap >= 0),
       assert(minLabelSweep >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleSunburstVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => _nodeValue(item).isFinite && _nodeValue(item) > 0)
        .toList();
    final dataTotal = visibleData.fold<double>(
      0,
      (sum, item) => sum + _nodeValue(item),
    );
    final resolvedTotal = math.max(totalValue ?? dataTotal, dataTotal);
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedPercentFormatter =
        percentFormatter ?? _defaultPercentFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty || resolvedTotal <= 0) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Sunburst chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedLabelStyle =
            labelStyle ??
            theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface) ??
            TextStyle(color: colorScheme.onSurface, fontSize: 12);
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleData,
            resolvedTotal,
            formatter,
            resolvedPercentFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleSunburstChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            total: resolvedTotal,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals.palette),
            segmentColor: segmentColor ?? visuals.segmentColor,
            borderColor: borderColor ?? visuals.borderColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            centerLabel: centerLabel,
            showLabels: showLabels,
            showValues: showValues,
            showParentLabels: showParentLabels,
            showTooltip: showTooltip,
            showActiveSegment: showActiveSegment,
            maxDepth: maxDepth,
            innerRadiusFactor: innerRadiusFactor,
            segmentGap: segmentGap,
            minLabelSweep: minLabelSweep,
            startAngleDegrees: startAngleDegrees,
            valueFormatter: formatter,
            percentFormatter: resolvedPercentFormatter,
            onSegmentTap: onSegmentTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(ColorScheme colorScheme, List<Color> defaults) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    if (segmentColor != null) return [segmentColor!];
    return defaults;
  }

  String _defaultSemanticLabel(
    List<SimpleSunburstData> visibleData,
    double resolvedTotal,
    SimpleSunburstValueFormatter formatter,
    SimpleSunburstValueFormatter resolvedPercentFormatter,
  ) {
    final leaves = _leafNodes(visibleData);
    final visibleItems = leaves
        .take(6)
        .map((item) {
          final value = _nodeValue(item);
          final share = resolvedTotal == 0 ? 0.0 : value / resolvedTotal;
          return '${item.label} ${formatter(value)}, '
              '${resolvedPercentFormatter(share)}';
        })
        .join(', ');
    final remaining = leaves.length - math.min(leaves.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = leaves.length == 1 ? 'segment' : 'segments';
    return 'Sunburst chart, ${leaves.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static List<SimpleSunburstData> _leafNodes(List<SimpleSunburstData> nodes) {
    final result = <SimpleSunburstData>[];
    for (final node in nodes) {
      final children = node.children
          .where((child) => _nodeValue(child).isFinite && _nodeValue(child) > 0)
          .toList();
      if (children.isEmpty) {
        result.add(node);
      } else {
        result.addAll(_leafNodes(children));
      }
    }
    return result;
  }

  static double _nodeValue(SimpleSunburstData item) {
    final childTotal = item.children.fold<double>(
      0,
      (sum, child) => sum + math.max(0.0, _nodeValue(child)),
    );
    final own = item.value.isFinite ? math.max(0.0, item.value) : 0.0;
    return childTotal > 0 ? math.max(own, childTotal) : own;
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }
}

class _SimpleSunburstChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleSunburstData> data;
  final double total;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color segmentColor;
  final Color borderColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final String? centerLabel;
  final bool showLabels;
  final bool showValues;
  final bool showParentLabels;
  final bool showTooltip;
  final bool showActiveSegment;
  final int maxDepth;
  final double innerRadiusFactor;
  final double segmentGap;
  final double minLabelSweep;
  final double startAngleDegrees;
  final SimpleSunburstValueFormatter valueFormatter;
  final SimpleSunburstValueFormatter percentFormatter;
  final SimpleSunburstTapCallback? onSegmentTap;
  final SimpleSunburstTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleSunburstChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.total,
    required this.padding,
    required this.palette,
    required this.segmentColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.centerLabel,
    required this.showLabels,
    required this.showValues,
    required this.showParentLabels,
    required this.showTooltip,
    required this.showActiveSegment,
    required this.maxDepth,
    required this.innerRadiusFactor,
    required this.segmentGap,
    required this.minLabelSweep,
    required this.startAngleDegrees,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.onSegmentTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleSunburstChartView> createState() =>
      _SimpleSunburstChartViewState();
}

class _SimpleSunburstChartViewState extends State<_SimpleSunburstChartView> {
  _SunburstSegment? _activeSegment;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveSegment ||
        widget.onSegmentTap != null;

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
                painter: _SimpleSunburstPainter(
                  data: widget.data,
                  total: widget.total,
                  padding: widget.padding,
                  palette: widget.palette,
                  segmentColor: widget.segmentColor,
                  borderColor: widget.borderColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  centerLabel: widget.centerLabel,
                  showLabels: widget.showLabels,
                  showValues: widget.showValues,
                  showParentLabels: widget.showParentLabels,
                  showActiveSegment: widget.showActiveSegment,
                  maxDepth: widget.maxDepth,
                  innerRadiusFactor: widget.innerRadiusFactor,
                  segmentGap: widget.segmentGap,
                  minLabelSweep: widget.minLabelSweep,
                  startAngleDegrees: widget.startAngleDegrees,
                  valueFormatter: widget.valueFormatter,
                  percentFormatter: widget.percentFormatter,
                  activeSegment: _activeSegment,
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
                  onExit: (_) => _setActive(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final segment = _hitTest(details.localPosition, size);
                      _setActive(segment);
                      if (segment != null) {
                        widget.onSegmentTap?.call(
                          segment.data,
                          segment.path,
                          segment.value,
                          segment.share,
                        );
                      }
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeSegment != null)
                _buildTooltip(context, size, _activeSegment!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_SunburstSegment? segment) {
    if (_activeSegment == segment) return;
    setState(() => _activeSegment = segment);
  }

  _SunburstSegment? _hitTest(Offset position, Size size) {
    final geometry = _SunburstGeometry.resolve(
      size: size,
      data: widget.data,
      total: widget.total,
      padding: widget.padding,
      maxDepth: widget.maxDepth,
      innerRadiusFactor: widget.innerRadiusFactor,
      startAngleDegrees: widget.startAngleDegrees,
    );
    final delta = position - geometry.center;
    final radius = delta.distance;
    if (radius < geometry.innerRadius || radius > geometry.outerRadius) {
      return null;
    }
    final angle = math.atan2(delta.dy, delta.dx);
    for (final segment in geometry.segments.reversed) {
      if (radius < segment.innerRadius || radius > segment.outerRadius) {
        continue;
      }
      if (_angleInSegment(angle, segment.startAngle, segment.sweepAngle)) {
        return segment;
      }
    }
    return null;
  }

  bool _angleInSegment(double angle, double start, double sweep) {
    final normalized = _normalizeAngle(angle);
    final normalizedStart = _normalizeAngle(start);
    final normalizedEnd = _normalizeAngle(start + sweep);
    if (sweep >= math.pi * 2 - 1e-6) return true;
    if (normalizedStart <= normalizedEnd) {
      return normalized >= normalizedStart && normalized <= normalizedEnd;
    }
    return normalized >= normalizedStart || normalized <= normalizedEnd;
  }

  double _normalizeAngle(double angle) {
    final full = math.pi * 2;
    var value = angle % full;
    if (value < 0) value += full;
    return value;
  }

  Widget _buildTooltip(BuildContext context, Size size, _SunburstSegment item) {
    final formattedValue = widget.valueFormatter(item.value);
    final formattedShare = widget.percentFormatter(item.share);
    const tooltipWidth = 198.0;
    const tooltipHeight = 86.0;
    final anchor = item.centerPoint;
    final left = (anchor.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (anchor.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            item.data,
            item.path,
            formattedValue,
            formattedShare,
          ) ??
          _DefaultSunburstTooltip(
            color: _segmentColor(item),
            title: item.path.map((node) => node.label).join(' / '),
            value: formattedValue,
            share: formattedShare,
          ),
    );
  }

  Color _segmentColor(_SunburstSegment segment) {
    if (segment.data.color != null) return segment.data.color!;
    if (widget.palette.isEmpty) return widget.segmentColor;
    return widget.palette[segment.rootIndex % widget.palette.length];
  }
}

class _SimpleSunburstPainter extends CustomPainter {
  final List<SimpleSunburstData> data;
  final double total;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color segmentColor;
  final Color borderColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final String? centerLabel;
  final bool showLabels;
  final bool showValues;
  final bool showParentLabels;
  final bool showActiveSegment;
  final int maxDepth;
  final double innerRadiusFactor;
  final double segmentGap;
  final double minLabelSweep;
  final double startAngleDegrees;
  final SimpleSunburstValueFormatter valueFormatter;
  final SimpleSunburstValueFormatter percentFormatter;
  final _SunburstSegment? activeSegment;
  final double progress;

  const _SimpleSunburstPainter({
    required this.data,
    required this.total,
    required this.padding,
    required this.palette,
    required this.segmentColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.centerLabel,
    required this.showLabels,
    required this.showValues,
    required this.showParentLabels,
    required this.showActiveSegment,
    required this.maxDepth,
    required this.innerRadiusFactor,
    required this.segmentGap,
    required this.minLabelSweep,
    required this.startAngleDegrees,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.activeSegment,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _SunburstGeometry.resolve(
      size: size,
      data: data,
      total: total,
      padding: padding,
      maxDepth: maxDepth,
      innerRadiusFactor: innerRadiusFactor,
      startAngleDegrees: startAngleDegrees,
    );
    if (geometry.outerRadius <= 0 || geometry.segments.isEmpty) return;

    for (final segment in geometry.segments) {
      _drawSegment(canvas, segment);
    }
    _drawCenter(canvas, geometry);
  }

  void _drawSegment(Canvas canvas, _SunburstSegment segment) {
    final color = _segmentColor(segment);
    final selected = activeSegment == segment;
    final activeExists = activeSegment != null;
    final opacity = activeExists && !selected ? 0.36 : 1.0;
    final averageRadius = (segment.innerRadius + segment.outerRadius) / 2;
    final gapAngle = averageRadius <= 0 ? 0.0 : segmentGap / averageRadius;
    final start = segment.startAngle + gapAngle / 2;
    final sweep = math.max(0.0, segment.sweepAngle * progress - gapAngle);
    if (sweep <= 0.001) return;
    final path = _segmentPath(
      segment.center,
      segment.innerRadius,
      segment.outerRadius,
      start,
      sweep,
    );
    final baseAlpha = segment.hasChildren ? 0.58 : 0.86;
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: baseAlpha * opacity)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    if (showActiveSegment && selected) {
      canvas.drawPath(
        path,
        Paint()
          ..color = (activeColor ?? color).withValues(alpha: 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }
    final labelAllowed = segment.hasChildren ? showParentLabels : showLabels;
    final sweepDegrees = sweep * 180 / math.pi;
    if (labelAllowed && sweepDegrees >= minLabelSweep) {
      _drawLabel(canvas, segment, color, sweep);
    }
  }

  Path _segmentPath(
    Offset center,
    double innerRadius,
    double outerRadius,
    double start,
    double sweep,
  ) {
    final path = Path();
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final outerStart = Offset(
      center.dx + math.cos(start) * outerRadius,
      center.dy + math.sin(start) * outerRadius,
    );
    path.moveTo(outerStart.dx, outerStart.dy);
    path.arcTo(outerRect, start, sweep, false);
    final innerEnd = Offset(
      center.dx + math.cos(start + sweep) * innerRadius,
      center.dy + math.sin(start + sweep) * innerRadius,
    );
    path.lineTo(innerEnd.dx, innerEnd.dy);
    path.arcTo(innerRect, start + sweep, -sweep, false);
    path.close();
    return path;
  }

  void _drawLabel(
    Canvas canvas,
    _SunburstSegment segment,
    Color color,
    double visibleSweep,
  ) {
    final radius = (segment.innerRadius + segment.outerRadius) / 2;
    final angle = segment.startAngle + visibleSweep / 2;
    final anchor = Offset(
      segment.center.dx + math.cos(angle) * radius,
      segment.center.dy + math.sin(angle) * radius,
    );
    final textColor = _textColorFor(color);
    final maxWidth = math.max(
      28.0,
      math.min(96.0, radius * visibleSweep * 0.78),
    );
    final labelPainter = TextPainter(
      text: TextSpan(
        text: segment.data.label,
        style: labelStyle.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: math.max(9, math.min(labelStyle.fontSize ?? 12, 12)),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    final labelOffset = Offset(
      anchor.dx - labelPainter.width / 2,
      anchor.dy - labelPainter.height / 2,
    );
    labelPainter.paint(canvas, labelOffset);

    if (!showValues || visibleSweep * radius < 42) return;
    final valuePainter = TextPainter(
      text: TextSpan(
        text: percentFormatter(segment.share),
        style: valueStyle.copyWith(
          color: textColor.withValues(alpha: 0.86),
          fontSize: math.max(8, (valueStyle.fontSize ?? 11) - 2),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    valuePainter.paint(
      canvas,
      Offset(
        anchor.dx - valuePainter.width / 2,
        labelOffset.dy + labelPainter.height + 2,
      ),
    );
  }

  void _drawCenter(Canvas canvas, _SunburstGeometry geometry) {
    if (geometry.innerRadius <= 3) return;
    final fill = Paint()..color = borderColor.withValues(alpha: 0.96);
    canvas.drawCircle(geometry.center, geometry.innerRadius - 1, fill);
    final label = centerLabel;
    if (label == null || label.trim().isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: valueStyle.copyWith(
          color: valueStyle.color,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: math.max(12.0, geometry.innerRadius * 1.55));
    painter.paint(
      canvas,
      Offset(
        geometry.center.dx - painter.width / 2,
        geometry.center.dy - painter.height / 2,
      ),
    );
  }

  Color _segmentColor(_SunburstSegment segment) {
    if (segment.data.color != null) return segment.data.color!;
    final base = palette.isEmpty
        ? segmentColor
        : palette[segment.rootIndex % palette.length];
    if (segment.depth == 0) return base;
    final blend = segment.depth.isOdd ? Colors.white : Colors.black;
    final amount = segment.depth.isOdd ? 0.12 : 0.08;
    return Color.lerp(base, blend, amount) ?? base;
  }

  Color _textColorFor(Color color) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.dark ? Colors.white : Colors.black87;
  }

  @override
  bool shouldRepaint(covariant _SimpleSunburstPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.total != total ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.segmentColor != segmentColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.centerLabel != centerLabel ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showParentLabels != showParentLabels ||
        oldDelegate.showActiveSegment != showActiveSegment ||
        oldDelegate.maxDepth != maxDepth ||
        oldDelegate.innerRadiusFactor != innerRadiusFactor ||
        oldDelegate.segmentGap != segmentGap ||
        oldDelegate.minLabelSweep != minLabelSweep ||
        oldDelegate.startAngleDegrees != startAngleDegrees ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.percentFormatter != percentFormatter ||
        oldDelegate.activeSegment != activeSegment ||
        oldDelegate.progress != progress;
  }
}

class _SunburstGeometry {
  final Offset center;
  final double innerRadius;
  final double outerRadius;
  final List<_SunburstSegment> segments;

  const _SunburstGeometry({
    required this.center,
    required this.innerRadius,
    required this.outerRadius,
    required this.segments,
  });

  factory _SunburstGeometry.resolve({
    required Size size,
    required List<SimpleSunburstData> data,
    required double total,
    required EdgeInsets padding,
    required int maxDepth,
    required double innerRadiusFactor,
    required double startAngleDegrees,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    final center = plot.center;
    final outerRadius = math.max(0.0, math.min(plot.width, plot.height) / 2);
    final innerRadius = outerRadius * innerRadiusFactor;
    final ringCount = math.max(1, maxDepth);
    final ringWidth = outerRadius <= innerRadius
        ? 0.0
        : (outerRadius - innerRadius) / ringCount;
    final segments = <_SunburstSegment>[];
    final start = startAngleDegrees * math.pi / 180;
    _layoutLevel(
      data: data,
      total: total,
      parentTotal: total,
      startAngle: start,
      sweepAngle: math.pi * 2,
      depth: 0,
      path: const [],
      rootIndex: 0,
      maxDepth: maxDepth,
      center: center,
      innerRadius: innerRadius,
      ringWidth: ringWidth,
      segments: segments,
    );
    return _SunburstGeometry(
      center: center,
      innerRadius: innerRadius,
      outerRadius: outerRadius,
      segments: segments,
    );
  }

  static void _layoutLevel({
    required List<SimpleSunburstData> data,
    required double total,
    required double parentTotal,
    required double startAngle,
    required double sweepAngle,
    required int depth,
    required List<SimpleSunburstData> path,
    required int rootIndex,
    required int maxDepth,
    required Offset center,
    required double innerRadius,
    required double ringWidth,
    required List<_SunburstSegment> segments,
  }) {
    if (data.isEmpty || parentTotal <= 0 || depth >= maxDepth) return;
    var cursor = startAngle;
    for (var index = 0; index < data.length; index++) {
      final node = data[index];
      final value = SimpleSunburstChart._nodeValue(node);
      if (value <= 0) continue;
      final sweep = sweepAngle * (value / parentTotal);
      final segmentPath = [...path, node];
      final currentRoot = depth == 0 ? index : rootIndex;
      final children = node.children
          .where((child) => SimpleSunburstChart._nodeValue(child) > 0)
          .toList();
      final segment = _SunburstSegment(
        data: node,
        path: segmentPath,
        center: center,
        startAngle: cursor,
        sweepAngle: sweep,
        innerRadius: innerRadius + ringWidth * depth,
        outerRadius: innerRadius + ringWidth * (depth + 1),
        depth: depth,
        rootIndex: currentRoot,
        value: value,
        share: total == 0 ? 0 : value / total,
        hasChildren: children.isNotEmpty,
      );
      segments.add(segment);
      if (children.isNotEmpty && depth + 1 < maxDepth) {
        _layoutLevel(
          data: children,
          total: total,
          parentTotal: value,
          startAngle: cursor,
          sweepAngle: sweep,
          depth: depth + 1,
          path: segmentPath,
          rootIndex: currentRoot,
          maxDepth: maxDepth,
          center: center,
          innerRadius: innerRadius,
          ringWidth: ringWidth,
          segments: segments,
        );
      }
      cursor += sweep;
    }
  }
}

class _SunburstSegment {
  final SimpleSunburstData data;
  final List<SimpleSunburstData> path;
  final Offset center;
  final double startAngle;
  final double sweepAngle;
  final double innerRadius;
  final double outerRadius;
  final int depth;
  final int rootIndex;
  final double value;
  final double share;
  final bool hasChildren;

  const _SunburstSegment({
    required this.data,
    required this.path,
    required this.center,
    required this.startAngle,
    required this.sweepAngle,
    required this.innerRadius,
    required this.outerRadius,
    required this.depth,
    required this.rootIndex,
    required this.value,
    required this.share,
    required this.hasChildren,
  });

  Offset get centerPoint {
    final angle = startAngle + sweepAngle / 2;
    final radius = (innerRadius + outerRadius) / 2;
    return Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }
}

class _SimpleSunburstVisuals {
  final List<Color> palette;
  final Color segmentColor;
  final Color borderColor;

  const _SimpleSunburstVisuals({
    required this.palette,
    required this.segmentColor,
    required this.borderColor,
  });

  factory _SimpleSunburstVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleSunburstVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.error,
          ],
          segmentColor: colorScheme.primary,
          borderColor: colorScheme.surface,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleSunburstVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.outline,
            colorScheme.tertiary,
          ],
          segmentColor: colorScheme.primary,
          borderColor: colorScheme.surface,
        );
      case SimpleBarChartStyle.education:
        return _SimpleSunburstVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            colorScheme.error,
          ],
          segmentColor: colorScheme.secondary,
          borderColor: colorScheme.surface,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleSunburstVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.error,
          ],
          segmentColor: colorScheme.tertiary,
          borderColor: colorScheme.surface,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleSunburstVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.error,
          ],
          segmentColor: colorScheme.primary,
          borderColor: colorScheme.surface,
        );
    }
  }
}

class _DefaultSunburstTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String share;

  const _DefaultSunburstTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TooltipRow(
              label: 'Value',
              value: value,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: 'Share',
              value: share,
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _TooltipRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
