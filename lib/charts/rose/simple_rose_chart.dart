import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleRoseValueFormatter = String Function(double value);
typedef SimpleRoseTapCallback =
    void Function(SimpleRoseChartData data, int index, double normalizedValue);
typedef SimpleRoseTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleRoseChartData data,
      int index,
      String formattedValue,
      String formattedNormalizedValue,
    );

enum SimpleRoseScale { area, radius }

class SimpleRoseChartData {
  final String label;
  final double value;
  final Color? color;

  const SimpleRoseChartData({
    required this.label,
    required this.value,
    this.color,
  });
}

/// A simple Nightingale rose chart for radial category comparison with equal
/// angles and value-driven petal length.
class SimpleRoseChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(14, 12, 14, 12);

  final List<SimpleRoseChartData> data;
  final SimpleBarChartStyle style;
  final SimpleRoseScale scale;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? trackColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showLegend;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveSegment;
  final int gridRingCount;
  final double innerRadiusFactor;
  final double segmentSpacing;
  final double startAngle;
  final SimpleRoseValueFormatter? valueFormatter;
  final SimpleRoseValueFormatter? normalizedFormatter;
  final SimpleRoseTapCallback? onSegmentTap;
  final SimpleRoseTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleRoseChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.scale = SimpleRoseScale.area,
    this.maxValue,
    this.height = 250,
    this.padding = _defaultPadding,
    this.palette,
    this.trackColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLabels = true,
    this.showLegend = true,
    this.showValues = true,
    this.showTooltip = true,
    this.showActiveSegment = true,
    this.gridRingCount = 4,
    this.innerRadiusFactor = 0.08,
    this.segmentSpacing = 0.018,
    this.startAngle = -math.pi / 2,
    this.valueFormatter,
    this.normalizedFormatter,
    this.onSegmentTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(maxValue == null || maxValue > 0),
       assert(gridRingCount >= 2),
       assert(innerRadiusFactor >= 0 && innerRadiusFactor < 0.8),
       assert(segmentSpacing >= 0 && segmentSpacing <= 0.12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleRoseVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.label.trim().isNotEmpty && item.value > 0)
        .toList();
    final dataMax = visibleData.fold<double>(
      0,
      (current, item) => math.max(current, item.value),
    );
    final resolvedMax = math.max(maxValue ?? dataMax, dataMax);
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedNormalizedFormatter =
        normalizedFormatter ?? _defaultNormalizedFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty || resolvedMax <= 0) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Rose chart, no data.',
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
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
        final resolvedPalette = _resolvePalette(colorScheme, visuals.palette);

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleData,
            resolvedMax,
            formatter,
            resolvedNormalizedFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleRoseChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            maxValue: resolvedMax,
            padding: padding,
            palette: resolvedPalette,
            trackColor: trackColor ?? visuals.trackColor,
            gridColor: gridColor ?? visuals.gridColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            scale: scale,
            showGrid: showGrid,
            showLabels: showLabels,
            showLegend: showLegend,
            showValues: showValues,
            showTooltip: showTooltip,
            showActiveSegment: showActiveSegment,
            gridRingCount: gridRingCount,
            innerRadiusFactor: innerRadiusFactor,
            segmentSpacing: segmentSpacing,
            startAngle: startAngle,
            valueFormatter: formatter,
            normalizedFormatter: resolvedNormalizedFormatter,
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
    return defaults;
  }

  String _defaultSemanticLabel(
    List<SimpleRoseChartData> visibleData,
    double resolvedMax,
    SimpleRoseValueFormatter formatter,
    SimpleRoseValueFormatter resolvedNormalizedFormatter,
  ) {
    final visibleItems = visibleData
        .take(6)
        .map((item) {
          final normalized = item.value / resolvedMax;
          return '${item.label} ${formatter(item.value)}, '
              '${resolvedNormalizedFormatter(normalized)} of max';
        })
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'petal' : 'petals';
    return 'Rose chart, ${visibleData.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultNormalizedFormatter(double value) {
    return '${(value * 100).toStringAsFixed(value < 0.1 ? 1 : 0)}%';
  }
}

class _SimpleRoseChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleRoseChartData> data;
  final double maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color trackColor;
  final Color gridColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final SimpleRoseScale scale;
  final bool showGrid;
  final bool showLabels;
  final bool showLegend;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveSegment;
  final int gridRingCount;
  final double innerRadiusFactor;
  final double segmentSpacing;
  final double startAngle;
  final SimpleRoseValueFormatter valueFormatter;
  final SimpleRoseValueFormatter normalizedFormatter;
  final SimpleRoseTapCallback? onSegmentTap;
  final SimpleRoseTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleRoseChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.trackColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.scale,
    required this.showGrid,
    required this.showLabels,
    required this.showLegend,
    required this.showValues,
    required this.showTooltip,
    required this.showActiveSegment,
    required this.gridRingCount,
    required this.innerRadiusFactor,
    required this.segmentSpacing,
    required this.startAngle,
    required this.valueFormatter,
    required this.normalizedFormatter,
    required this.onSegmentTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleRoseChartView> createState() => _SimpleRoseChartViewState();
}

class _SimpleRoseChartViewState extends State<_SimpleRoseChartView> {
  int? _activeIndex;

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
                painter: _SimpleRosePainter(
                  data: widget.data,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  palette: widget.palette,
                  trackColor: widget.trackColor,
                  gridColor: widget.gridColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  scale: widget.scale,
                  showGrid: widget.showGrid,
                  showLabels: widget.showLabels,
                  showLegend: widget.showLegend,
                  showValues: widget.showValues,
                  gridRingCount: widget.gridRingCount,
                  innerRadiusFactor: widget.innerRadiusFactor,
                  segmentSpacing: widget.segmentSpacing,
                  startAngle: widget.startAngle,
                  valueFormatter: widget.valueFormatter,
                  normalizedFormatter: widget.normalizedFormatter,
                  activeIndex: widget.showActiveSegment ? _activeIndex : null,
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
                      final index = _hitTest(details.localPosition, size);
                      _setActive(index);
                      if (index == null) return;
                      widget.onSegmentTap?.call(
                        widget.data[index],
                        index,
                        widget.data[index].value / widget.maxValue,
                      );
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeIndex != null)
                _buildTooltip(context, size, _activeIndex!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(int? index) {
    if (_activeIndex == index) return;
    setState(() => _activeIndex = index);
  }

  int? _hitTest(Offset position, Size size) {
    final layout = _RoseLayout.resolve(
      size,
      widget.padding,
      widget.showLegend,
      widget.showLabels,
    );
    final delta = position - layout.center;
    final distance = delta.distance;
    if (distance < layout.innerRadius(widget.innerRadiusFactor) - 8 ||
        distance > layout.outerRadius + 10) {
      return null;
    }

    final angle = _normalizeAngle(math.atan2(delta.dy, delta.dx));
    final segments = _computeRoseSegments(
      widget.data,
      widget.maxValue,
      widget.startAngle,
      widget.scale,
    );
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (!_angleInRoseSegment(angle, segment)) continue;
      final outerRadius = layout.radiusFor(
        widget.innerRadiusFactor,
        segment.radiusFactor,
      );
      if (distance <= outerRadius + 10) return index;
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final item = widget.data[index];
    final normalized = item.value / widget.maxValue;
    final formattedValue = widget.valueFormatter(item.value);
    final formattedNormalized = widget.normalizedFormatter(normalized);
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 164.0;
    const tooltipHeight = 62.0;
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
            item,
            index,
            formattedValue,
            formattedNormalized,
          ) ??
          _DefaultRoseTooltip(
            color: _segmentColor(item, index),
            title: item.label,
            value: formattedValue,
            normalizedValue: formattedNormalized,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final layout = _RoseLayout.resolve(
      size,
      widget.padding,
      widget.showLegend,
      widget.showLabels,
    );
    final segments = _computeRoseSegments(
      widget.data,
      widget.maxValue,
      widget.startAngle,
      widget.scale,
    );
    final segment = segments[index];
    final angle = segment.start + segment.sweep / 2;
    final radius =
        layout.radiusFor(widget.innerRadiusFactor, segment.radiusFactor) + 8;
    return Offset(
      layout.center.dx + math.cos(angle) * radius,
      layout.center.dy + math.sin(angle) * radius,
    );
  }

  Color _segmentColor(SimpleRoseChartData item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleRosePainter extends CustomPainter {
  final List<SimpleRoseChartData> data;
  final double maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color trackColor;
  final Color gridColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final SimpleRoseScale scale;
  final bool showGrid;
  final bool showLabels;
  final bool showLegend;
  final bool showValues;
  final int gridRingCount;
  final double innerRadiusFactor;
  final double segmentSpacing;
  final double startAngle;
  final SimpleRoseValueFormatter valueFormatter;
  final SimpleRoseValueFormatter normalizedFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleRosePainter({
    required this.data,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.trackColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.scale,
    required this.showGrid,
    required this.showLabels,
    required this.showLegend,
    required this.showValues,
    required this.gridRingCount,
    required this.innerRadiusFactor,
    required this.segmentSpacing,
    required this.startAngle,
    required this.valueFormatter,
    required this.normalizedFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _RoseLayout.resolve(size, padding, showLegend, showLabels);
    if (layout.outerRadius <= 0 || data.isEmpty || maxValue <= 0) return;

    final innerRadius = layout.innerRadius(innerRadiusFactor);
    final segments = _computeRoseSegments(data, maxValue, startAngle, scale);

    _drawTrack(canvas, layout, innerRadius);
    if (showGrid) _drawGrid(canvas, layout, innerRadius);
    _drawSegments(canvas, layout, innerRadius, segments);
    if (showLabels) _drawSliceLabels(canvas, layout, segments);
    if (showLegend) _drawLegend(canvas, layout, segments);
  }

  void _drawTrack(Canvas canvas, _RoseLayout layout, double innerRadius) {
    canvas.drawCircle(
      layout.center,
      layout.outerRadius,
      Paint()..color = trackColor,
    );
    if (innerRadius > 0) {
      canvas.drawCircle(
        layout.center,
        innerRadius,
        Paint()..color = Colors.white.withValues(alpha: 0.02),
      );
    }
  }

  void _drawGrid(Canvas canvas, _RoseLayout layout, double innerRadius) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 1; index <= gridRingCount; index++) {
      final t = index / gridRingCount;
      final radius = innerRadius + (layout.outerRadius - innerRadius) * t;
      canvas.drawCircle(layout.center, radius, paint);
    }
    final spokeCount = data.length;
    for (var index = 0; index < spokeCount; index++) {
      final angle = startAngle + index * math.pi * 2 / spokeCount;
      canvas.drawLine(
        Offset(
          layout.center.dx + math.cos(angle) * innerRadius,
          layout.center.dy + math.sin(angle) * innerRadius,
        ),
        Offset(
          layout.center.dx + math.cos(angle) * layout.outerRadius,
          layout.center.dy + math.sin(angle) * layout.outerRadius,
        ),
        paint,
      );
    }
  }

  void _drawSegments(
    Canvas canvas,
    _RoseLayout layout,
    double innerRadius,
    List<_RoseSegment> segments,
  ) {
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final active = index == activeIndex;
      final color = activeColor ?? _segmentColor(segment.data, index);
      final segmentColor = _segmentColor(segment.data, index);
      final outerRadius =
          layout.radiusFor(innerRadiusFactor, segment.radiusFactor) * progress;
      if (outerRadius <= innerRadius) continue;
      final visibleSweep = math.max(0.0, segment.sweep - segmentSpacing);
      if (visibleSweep <= 0) continue;
      final start = segment.start + segmentSpacing / 2;
      final path = _petalPath(
        center: layout.center,
        innerRadius: innerRadius,
        outerRadius: outerRadius,
        start: start,
        sweep: visibleSweep,
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = (active ? color : segmentColor).withValues(
            alpha: active ? 0.96 : 0.84,
          )
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 1.6 : 0.9,
      );
    }
  }

  Path _petalPath({
    required Offset center,
    required double innerRadius,
    required double outerRadius,
    required double start,
    required double sweep,
  }) {
    final end = start + sweep;
    final innerStart = _polar(center, innerRadius, start);
    final outerStart = _polar(center, outerRadius, start);
    final innerEnd = _polar(center, innerRadius, end);
    final path = Path()
      ..moveTo(innerStart.dx, innerStart.dy)
      ..lineTo(outerStart.dx, outerStart.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: outerRadius),
        start,
        sweep,
        false,
      )
      ..lineTo(innerEnd.dx, innerEnd.dy);
    if (innerRadius > 0.5) {
      path.arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        end,
        -sweep,
        false,
      );
    }
    return path..close();
  }

  void _drawSliceLabels(
    Canvas canvas,
    _RoseLayout layout,
    List<_RoseSegment> segments,
  ) {
    if (layout.compact) return;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final angle = segment.start + segment.sweep / 2;
      final radius =
          layout.radiusFor(innerRadiusFactor, segment.radiusFactor) + 12;
      final anchor = Offset(
        layout.center.dx + math.cos(angle) * radius,
        layout.center.dy + math.sin(angle) * radius,
      );
      final label = showValues
          ? valueFormatter(segment.data.value)
          : segment.data.label;
      final painter = _textPainter(
        label,
        valueStyle.copyWith(
          color: _segmentColor(segment.data, index),
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      )..layout();
      final x = _safeClamp(
        anchor.dx - painter.width / 2,
        padding.left + 2,
        layout.chartRight - painter.width - 2,
      );
      final y = _safeClamp(
        anchor.dy - painter.height / 2,
        padding.top + 2,
        layout.bottom - painter.height - 2,
      );
      painter.paint(canvas, Offset(x, y));
    }
  }

  void _drawLegend(
    Canvas canvas,
    _RoseLayout layout,
    List<_RoseSegment> segments,
  ) {
    if (layout.legendRect.width <= 0 || layout.legendRect.height <= 0) return;
    final rowHeight = math.max(22.0, layout.legendRect.height / data.length);
    final visibleRows = math.max(1, (layout.legendRect.height / 22).floor());
    final rowCount = math.min(data.length, visibleRows);

    for (var index = 0; index < rowCount; index++) {
      final segment = segments[index];
      final y = layout.legendRect.top + rowHeight * index + rowHeight / 2;
      final color = _segmentColor(segment.data, index);
      final active = index == activeIndex;
      final markerRect = Rect.fromLTWH(layout.legendRect.left, y - 4, 8, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(markerRect, const Radius.circular(2)),
        Paint()..color = color.withValues(alpha: active ? 1 : 0.88),
      );

      final value = showValues
          ? ' ${normalizedFormatter(segment.normalizedValue)}'
          : '';
      final painter = _textPainter(
        '${segment.data.label}$value',
        labelStyle.copyWith(
          color: active ? valueStyle.color : labelStyle.color,
          fontWeight: active ? FontWeight.w700 : labelStyle.fontWeight,
        ),
        maxWidth: layout.legendRect.width - 14,
      )..layout(maxWidth: layout.legendRect.width - 14);
      painter.paint(
        canvas,
        Offset(layout.legendRect.left + 14, y - painter.height / 2),
      );
    }

    if (data.length > rowCount) {
      final painter = _textPainter(
        '+${data.length - rowCount} more',
        labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 12) * 0.9),
      )..layout(maxWidth: layout.legendRect.width);
      painter.paint(
        canvas,
        Offset(
          layout.legendRect.left,
          layout.legendRect.bottom - painter.height,
        ),
      );
    }
  }

  Offset _polar(Offset center, double radius, double angle) {
    return Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }

  Color _segmentColor(SimpleRoseChartData item, int index) {
    return item.color ?? palette[index % palette.length];
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
  bool shouldRepaint(covariant _SimpleRosePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.scale != scale ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showValues != showValues ||
        oldDelegate.gridRingCount != gridRingCount ||
        oldDelegate.innerRadiusFactor != innerRadiusFactor ||
        oldDelegate.segmentSpacing != segmentSpacing ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.normalizedFormatter != normalizedFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

List<_RoseSegment> _computeRoseSegments(
  List<SimpleRoseChartData> data,
  double maxValue,
  double startAngle,
  SimpleRoseScale scale,
) {
  final segments = <_RoseSegment>[];
  final sweep = math.pi * 2 / data.length;
  for (var index = 0; index < data.length; index++) {
    final item = data[index];
    final normalized = (item.value / maxValue).clamp(0.0, 1.0).toDouble();
    final radiusFactor = scale == SimpleRoseScale.area
        ? math.sqrt(normalized)
        : normalized;
    segments.add(
      _RoseSegment(
        data: item,
        start: startAngle + sweep * index,
        sweep: sweep,
        normalizedValue: normalized,
        radiusFactor: radiusFactor,
      ),
    );
  }
  return segments;
}

bool _angleInRoseSegment(double normalizedAngle, _RoseSegment segment) {
  final start = _normalizeAngle(segment.start);
  final end = _normalizeAngle(segment.start + segment.sweep);
  if (segment.sweep >= math.pi * 2 - 0.0001) return true;
  if (start <= end) {
    return normalizedAngle >= start && normalizedAngle <= end;
  }
  return normalizedAngle >= start || normalizedAngle <= end;
}

double _normalizeAngle(double angle) {
  var normalized = angle % (math.pi * 2);
  if (normalized < 0) normalized += math.pi * 2;
  return normalized;
}

class _RoseSegment {
  final SimpleRoseChartData data;
  final double start;
  final double sweep;
  final double normalizedValue;
  final double radiusFactor;

  const _RoseSegment({
    required this.data,
    required this.start,
    required this.sweep,
    required this.normalizedValue,
    required this.radiusFactor,
  });
}

class _RoseLayout {
  final Offset center;
  final double outerRadius;
  final Rect legendRect;
  final double chartRight;
  final double bottom;
  final bool compact;

  const _RoseLayout({
    required this.center,
    required this.outerRadius,
    required this.legendRect,
    required this.chartRight,
    required this.bottom,
    required this.compact,
  });

  factory _RoseLayout.resolve(
    Size size,
    EdgeInsets padding,
    bool showLegend,
    bool showLabels,
  ) {
    final content = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    final compact = content.width < 360;
    final legendWidth = showLegend && !compact
        ? math.min(156.0, content.width * 0.36)
        : 0.0;
    final chartRect = Rect.fromLTRB(
      content.left,
      content.top,
      content.right - legendWidth - (legendWidth > 0 ? 14 : 0),
      content.bottom,
    );
    final labelInset = showLabels && !compact ? 22.0 : 6.0;
    final outerRadius = math.max(
      0.0,
      math.min(chartRect.width, chartRect.height) / 2 - labelInset,
    );
    final center = Offset(chartRect.center.dx, chartRect.center.dy - 2);
    final legendRect = legendWidth <= 0
        ? Rect.zero
        : Rect.fromLTWH(
            chartRect.right + 14,
            content.top + 8,
            legendWidth,
            math.max(0.0, content.height - 16),
          );
    return _RoseLayout(
      center: center,
      outerRadius: outerRadius,
      legendRect: legendRect,
      chartRight: chartRect.right,
      bottom: content.bottom,
      compact: compact,
    );
  }

  double innerRadius(double factor) {
    return outerRadius * factor;
  }

  double radiusFor(double innerRadiusFactor, double valueFactor) {
    final inner = innerRadius(innerRadiusFactor);
    return inner + (outerRadius - inner) * valueFactor;
  }
}

class _SimpleRoseVisuals {
  final List<Color> palette;
  final Color trackColor;
  final Color gridColor;

  const _SimpleRoseVisuals({
    required this.palette,
    required this.trackColor,
    required this.gridColor,
  });

  factory _SimpleRoseVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleRoseVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF22C55E),
            const Color(0xFFF59E0B),
            const Color(0xFF06B6D4),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.07),
          gridColor: colorScheme.outline.withValues(alpha: 0.14),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleRoseVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            colorScheme.secondary,
            const Color(0xFF64748B),
            const Color(0xFF0F766E),
            const Color(0xFF475569),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.08),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
        );
      case SimpleBarChartStyle.education:
        return _SimpleRoseVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFFF59E0B),
            const Color(0xFF22C55E),
            const Color(0xFFEF4444),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.08),
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleRoseVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFF97316),
            const Color(0xFFEC4899),
            const Color(0xFF84CC16),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.06),
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleRoseVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
            const Color(0xFFA16207),
            const Color(0xFFBE123C),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.07),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
        );
    }
  }
}

class _DefaultRoseTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String normalizedValue;

  const _DefaultRoseTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.normalizedValue,
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
                    '$value / $normalizedValue',
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
