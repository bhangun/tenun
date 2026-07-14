import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleRadialBarValueFormatter = String Function(double value);
typedef SimpleRadialBarTapCallback =
    void Function(SimpleRadialBarChartData data, int index, double progress);
typedef SimpleRadialBarTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleRadialBarChartData data,
      int index,
      String formattedValue,
      String formattedTarget,
      String formattedProgress,
    );

class SimpleRadialBarChartData {
  final String label;
  final double value;
  final double maxValue;
  final double? targetValue;
  final Color? color;

  const SimpleRadialBarChartData({
    required this.label,
    required this.value,
    this.maxValue = 100,
    this.targetValue,
    this.color,
  });
}

/// A simple multi-ring radial bar chart for comparing progress, completion,
/// health, and target attainment across several metrics.
class SimpleRadialBarChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(14, 12, 14, 12);

  final List<SimpleRadialBarChartData> data;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? barColor;
  final Color? trackColor;
  final Color? targetColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final String? centerLabel;
  final String? centerValue;
  final bool showLabels;
  final bool showLegend;
  final bool showValues;
  final bool showTargets;
  final bool showTooltip;
  final bool showActiveRing;
  final double? trackWidth;
  final double ringGap;
  final double startAngle;
  final double sweepAngle;
  final SimpleRadialBarValueFormatter? valueFormatter;
  final SimpleRadialBarValueFormatter? percentFormatter;
  final SimpleRadialBarTapCallback? onRingTap;
  final SimpleRadialBarTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleRadialBarChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 250,
    this.padding = _defaultPadding,
    this.palette,
    this.barColor,
    this.trackColor,
    this.targetColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.centerLabel,
    this.centerValue,
    this.showLabels = true,
    this.showLegend = true,
    this.showValues = true,
    this.showTargets = true,
    this.showTooltip = true,
    this.showActiveRing = true,
    this.trackWidth,
    this.ringGap = 8,
    this.startAngle = -math.pi / 2,
    this.sweepAngle = math.pi * 2,
    this.valueFormatter,
    this.percentFormatter,
    this.onRingTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(trackWidth == null || trackWidth > 0),
       assert(ringGap >= 0),
       assert(sweepAngle > 0 && sweepAngle <= math.pi * 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleRadialBarVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where(
          (item) =>
              item.label.trim().isNotEmpty &&
              item.value.isFinite &&
              item.maxValue.isFinite &&
              item.maxValue > 0,
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedPercentFormatter =
        percentFormatter ?? _defaultPercentFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Radial bar chart, no data.',
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
            formatter,
            resolvedPercentFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleRadialBarChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            padding: padding,
            palette: resolvedPalette,
            barColor: barColor,
            trackColor: trackColor ?? visuals.trackColor,
            targetColor: targetColor ?? visuals.targetColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            centerLabel: centerLabel,
            centerValue:
                centerValue ??
                resolvedPercentFormatter(_averageProgress(visibleData)),
            showLabels: showLabels,
            showLegend: showLegend,
            showValues: showValues,
            showTargets: showTargets,
            showTooltip: showTooltip,
            showActiveRing: showActiveRing,
            trackWidth: trackWidth,
            ringGap: ringGap,
            startAngle: startAngle,
            sweepAngle: sweepAngle,
            valueFormatter: formatter,
            percentFormatter: resolvedPercentFormatter,
            onRingTap: onRingTap,
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
    if (barColor != null) return [barColor!];
    return defaults;
  }

  double _averageProgress(List<SimpleRadialBarChartData> visibleData) {
    final sum = visibleData.fold<double>(
      0,
      (total, item) => total + (item.value / item.maxValue).clamp(0.0, 1.0),
    );
    return sum / visibleData.length;
  }

  String _defaultSemanticLabel(
    List<SimpleRadialBarChartData> visibleData,
    SimpleRadialBarValueFormatter formatter,
    SimpleRadialBarValueFormatter resolvedPercentFormatter,
  ) {
    final visibleItems = visibleData
        .take(6)
        .map((item) {
          final progress = (item.value / item.maxValue).clamp(0.0, 1.0);
          final targetText = item.targetValue == null
              ? ''
              : ', target ${formatter(item.targetValue!)}';
          return '${item.label} ${formatter(item.value)} of '
              '${formatter(item.maxValue)}, '
              '${resolvedPercentFormatter(progress)}$targetText';
        })
        .join('; ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? '; and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'ring' : 'rings';
    return 'Radial bar chart, ${visibleData.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) {
    return '${(value * 100).toStringAsFixed(value < 0.1 ? 1 : 0)}%';
  }
}

class _SimpleRadialBarChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleRadialBarChartData> data;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? barColor;
  final Color trackColor;
  final Color targetColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final String? centerLabel;
  final String centerValue;
  final bool showLabels;
  final bool showLegend;
  final bool showValues;
  final bool showTargets;
  final bool showTooltip;
  final bool showActiveRing;
  final double? trackWidth;
  final double ringGap;
  final double startAngle;
  final double sweepAngle;
  final SimpleRadialBarValueFormatter valueFormatter;
  final SimpleRadialBarValueFormatter percentFormatter;
  final SimpleRadialBarTapCallback? onRingTap;
  final SimpleRadialBarTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleRadialBarChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.padding,
    required this.palette,
    required this.barColor,
    required this.trackColor,
    required this.targetColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.centerLabel,
    required this.centerValue,
    required this.showLabels,
    required this.showLegend,
    required this.showValues,
    required this.showTargets,
    required this.showTooltip,
    required this.showActiveRing,
    required this.trackWidth,
    required this.ringGap,
    required this.startAngle,
    required this.sweepAngle,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.onRingTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleRadialBarChartView> createState() =>
      _SimpleRadialBarChartViewState();
}

class _SimpleRadialBarChartViewState extends State<_SimpleRadialBarChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveRing || widget.onRingTap != null;

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
                painter: _SimpleRadialBarPainter(
                  data: widget.data,
                  padding: widget.padding,
                  palette: widget.palette,
                  barColor: widget.barColor,
                  trackColor: widget.trackColor,
                  targetColor: widget.targetColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  centerLabel: widget.centerLabel,
                  centerValue: widget.centerValue,
                  showLabels: widget.showLabels,
                  showLegend: widget.showLegend,
                  showValues: widget.showValues,
                  showTargets: widget.showTargets,
                  trackWidth: widget.trackWidth,
                  ringGap: widget.ringGap,
                  startAngle: widget.startAngle,
                  sweepAngle: widget.sweepAngle,
                  valueFormatter: widget.valueFormatter,
                  percentFormatter: widget.percentFormatter,
                  activeIndex: widget.showActiveRing ? _activeIndex : null,
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
                      final item = widget.data[index];
                      widget.onRingTap?.call(
                        item,
                        index,
                        (item.value / item.maxValue).clamp(0.0, 1.0),
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
    final layout = _RadialBarLayout.resolve(
      size,
      widget.padding,
      widget.showLegend,
      widget.showLabels,
      widget.data.length,
      widget.trackWidth,
      widget.ringGap,
    );
    if (layout.rings.isEmpty) return null;
    final delta = position - layout.center;
    final distance = delta.distance;
    final angle = _normalizeAngle(math.atan2(delta.dy, delta.dx));

    for (final ring in layout.rings) {
      final onRing =
          (distance - ring.radius).abs() <= layout.trackWidth / 2 + 8;
      if (!onRing) continue;
      if (_angleInSweep(angle, widget.startAngle, widget.sweepAngle)) {
        return ring.index;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final item = widget.data[index];
    final progress = (item.value / item.maxValue).clamp(0.0, 1.0);
    final formattedValue = widget.valueFormatter(item.value);
    final formattedTarget = item.targetValue == null
        ? widget.valueFormatter(item.maxValue)
        : widget.valueFormatter(item.targetValue!);
    final formattedProgress = widget.percentFormatter(progress);
    final anchor = _anchorFor(index, size, progress);
    const tooltipWidth = 174.0;
    const tooltipHeight = 76.0;
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
            formattedTarget,
            formattedProgress,
          ) ??
          _DefaultRadialBarTooltip(
            color: _ringColor(item, index),
            title: item.label,
            value: formattedValue,
            target: formattedTarget,
            progress: formattedProgress,
            targetLabel: item.targetValue == null ? 'Max' : 'Target',
          ),
    );
  }

  Offset _anchorFor(int index, Size size, double progress) {
    final layout = _RadialBarLayout.resolve(
      size,
      widget.padding,
      widget.showLegend,
      widget.showLabels,
      widget.data.length,
      widget.trackWidth,
      widget.ringGap,
    );
    final ring = layout.rings.firstWhere(
      (item) => item.index == index,
      orElse: () => layout.rings.first,
    );
    final angle = widget.startAngle + widget.sweepAngle * progress;
    return Offset(
      layout.center.dx + math.cos(angle) * ring.radius,
      layout.center.dy + math.sin(angle) * ring.radius,
    );
  }

  Color _ringColor(SimpleRadialBarChartData item, int index) {
    return item.color ??
        widget.barColor ??
        widget.palette[index % widget.palette.length];
  }
}

class _SimpleRadialBarPainter extends CustomPainter {
  final List<SimpleRadialBarChartData> data;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? barColor;
  final Color trackColor;
  final Color targetColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final String? centerLabel;
  final String centerValue;
  final bool showLabels;
  final bool showLegend;
  final bool showValues;
  final bool showTargets;
  final double? trackWidth;
  final double ringGap;
  final double startAngle;
  final double sweepAngle;
  final SimpleRadialBarValueFormatter valueFormatter;
  final SimpleRadialBarValueFormatter percentFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleRadialBarPainter({
    required this.data,
    required this.padding,
    required this.palette,
    required this.barColor,
    required this.trackColor,
    required this.targetColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.centerLabel,
    required this.centerValue,
    required this.showLabels,
    required this.showLegend,
    required this.showValues,
    required this.showTargets,
    required this.trackWidth,
    required this.ringGap,
    required this.startAngle,
    required this.sweepAngle,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _RadialBarLayout.resolve(
      size,
      padding,
      showLegend,
      showLabels,
      data.length,
      trackWidth,
      ringGap,
    );
    if (layout.rings.isEmpty) return;

    _drawRings(canvas, layout);
    _drawCenterText(canvas, layout);
    if (showLegend) _drawLegend(canvas, layout);
  }

  void _drawRings(Canvas canvas, _RadialBarLayout layout) {
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = layout.trackWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final ring in layout.rings) {
      final item = data[ring.index];
      final pct = (item.value / item.maxValue).clamp(0.0, 1.0);
      final color = _ringColor(item, ring.index);
      final active = activeIndex == ring.index;
      final rect = Rect.fromCircle(center: layout.center, radius: ring.radius);
      final width = active ? layout.trackWidth + 4 : layout.trackWidth;

      canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * pct * progress,
        false,
        Paint()
          ..color = (active ? activeColor ?? color : color).withValues(
            alpha: active ? 0.98 : 0.88,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );

      if (showTargets && item.targetValue != null) {
        _drawTargetMarker(canvas, layout, ring, item);
      }

      if (showLabels && !layout.compact) {
        _drawRingLabel(canvas, layout, ring, item, pct, color);
      }
    }
  }

  void _drawTargetMarker(
    Canvas canvas,
    _RadialBarLayout layout,
    _RadialBarRing ring,
    SimpleRadialBarChartData item,
  ) {
    final target = (item.targetValue! / item.maxValue).clamp(0.0, 1.0);
    final angle = startAngle + sweepAngle * target;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final center = layout.center + direction * ring.radius;
    final half = layout.trackWidth / 2 + 2;
    canvas.drawLine(
      center - normal * half,
      center + normal * half,
      Paint()
        ..color = targetColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawRingLabel(
    Canvas canvas,
    _RadialBarLayout layout,
    _RadialBarRing ring,
    SimpleRadialBarChartData item,
    double pct,
    Color color,
  ) {
    final angle = startAngle + sweepAngle * pct * progress;
    final radius = ring.radius + layout.trackWidth / 2 + 10;
    final anchor = Offset(
      layout.center.dx + math.cos(angle) * radius,
      layout.center.dy + math.sin(angle) * radius,
    );
    final label = showValues ? percentFormatter(pct) : item.label;
    final painter = _textPainter(
      label,
      valueStyle.copyWith(color: color, fontWeight: FontWeight.w800),
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

  void _drawCenterText(Canvas canvas, _RadialBarLayout layout) {
    final label = centerLabel ?? 'Average';
    final valuePainter = _textPainter(
      centerValue,
      valueStyle.copyWith(
        fontSize: math.min(24, (valueStyle.fontSize ?? 12) * 1.55),
        fontWeight: FontWeight.w800,
      ),
      textAlign: TextAlign.center,
    )..layout(maxWidth: layout.centerTextWidth);
    final labelPainter = _textPainter(
      label,
      labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 12) * 0.92),
      textAlign: TextAlign.center,
    )..layout(maxWidth: layout.centerTextWidth);
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

  void _drawLegend(Canvas canvas, _RadialBarLayout layout) {
    if (layout.legendRect.width <= 0 || layout.legendRect.height <= 0) return;
    final rowHeight = math.max(22.0, layout.legendRect.height / data.length);
    final visibleRows = math.max(1, (layout.legendRect.height / 22).floor());
    final rowCount = math.min(data.length, visibleRows);

    for (var index = 0; index < rowCount; index++) {
      final item = data[index];
      final pct = (item.value / item.maxValue).clamp(0.0, 1.0);
      final y = layout.legendRect.top + rowHeight * index + rowHeight / 2;
      final color = _ringColor(item, index);
      final active = index == activeIndex;
      final markerRect = Rect.fromLTWH(layout.legendRect.left, y - 4, 8, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(markerRect, const Radius.circular(4)),
        Paint()..color = color.withValues(alpha: active ? 1 : 0.88),
      );

      final value = showValues ? ' ${percentFormatter(pct)}' : '';
      final painter = _textPainter(
        '${item.label}$value',
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

  Color _ringColor(SimpleRadialBarChartData item, int index) {
    return item.color ?? barColor ?? palette[index % palette.length];
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
  bool shouldRepaint(covariant _SimpleRadialBarPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.barColor != barColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.targetColor != targetColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.centerLabel != centerLabel ||
        oldDelegate.centerValue != centerValue ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showTargets != showTargets ||
        oldDelegate.trackWidth != trackWidth ||
        oldDelegate.ringGap != ringGap ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.percentFormatter != percentFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _RadialBarLayout {
  final Offset center;
  final double trackWidth;
  final Rect legendRect;
  final double chartRight;
  final double bottom;
  final double centerTextWidth;
  final bool compact;
  final List<_RadialBarRing> rings;

  const _RadialBarLayout({
    required this.center,
    required this.trackWidth,
    required this.legendRect,
    required this.chartRight,
    required this.bottom,
    required this.centerTextWidth,
    required this.compact,
    required this.rings,
  });

  factory _RadialBarLayout.resolve(
    Size size,
    EdgeInsets padding,
    bool showLegend,
    bool showLabels,
    int count,
    double? explicitTrackWidth,
    double ringGap,
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
    final labelInset = showLabels && !compact ? 20.0 : 6.0;
    final outerRadius = math.max(
      0.0,
      math.min(chartRect.width, chartRect.height) / 2 - labelInset,
    );
    final computedTrackWidth =
        explicitTrackWidth ?? _autoTrackWidth(outerRadius, count, ringGap);
    final center = Offset(chartRect.center.dx, chartRect.center.dy - 2);
    final rings = <_RadialBarRing>[];
    for (var index = 0; index < count; index++) {
      final radius =
          outerRadius -
          computedTrackWidth / 2 -
          index * (computedTrackWidth + ringGap);
      if (radius <= computedTrackWidth / 2) break;
      rings.add(_RadialBarRing(index: index, radius: radius));
    }
    final innermost = rings.isEmpty
        ? 0.0
        : math.max(20.0, rings.last.radius - computedTrackWidth / 2 - 2);
    final legendRect = legendWidth <= 0
        ? Rect.zero
        : Rect.fromLTWH(
            chartRect.right + 14,
            content.top + 8,
            legendWidth,
            math.max(0.0, content.height - 16),
          );

    return _RadialBarLayout(
      center: center,
      trackWidth: computedTrackWidth,
      legendRect: legendRect,
      chartRight: chartRect.right,
      bottom: content.bottom,
      centerTextWidth: innermost * 1.45,
      compact: compact,
      rings: rings,
    );
  }

  static double _autoTrackWidth(double outerRadius, int count, double gap) {
    if (count <= 0 || outerRadius <= 0) return 8;
    final available = outerRadius * 0.72 - gap * math.max(0, count - 1);
    return math.max(7.0, math.min(18.0, available / count));
  }
}

class _RadialBarRing {
  final int index;
  final double radius;

  const _RadialBarRing({required this.index, required this.radius});
}

bool _angleInSweep(double angle, double startAngle, double sweepAngle) {
  if (sweepAngle >= math.pi * 2 - 0.0001) return true;
  final start = _normalizeAngle(startAngle);
  final end = _normalizeAngle(startAngle + sweepAngle);
  if (start <= end) {
    return angle >= start && angle <= end;
  }
  return angle >= start || angle <= end;
}

double _normalizeAngle(double angle) {
  var normalized = angle % (math.pi * 2);
  if (normalized < 0) normalized += math.pi * 2;
  return normalized;
}

class _SimpleRadialBarVisuals {
  final List<Color> palette;
  final Color trackColor;
  final Color targetColor;

  const _SimpleRadialBarVisuals({
    required this.palette,
    required this.trackColor,
    required this.targetColor,
  });

  factory _SimpleRadialBarVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleRadialBarVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF22C55E),
            const Color(0xFFF59E0B),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.12),
          targetColor: colorScheme.onSurface.withValues(alpha: 0.7),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleRadialBarVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            colorScheme.secondary,
            const Color(0xFF64748B),
            const Color(0xFF0F766E),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.18),
          targetColor: colorScheme.onSurface.withValues(alpha: 0.72),
        );
      case SimpleBarChartStyle.education:
        return _SimpleRadialBarVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFFF59E0B),
            const Color(0xFF22C55E),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.15),
          targetColor: colorScheme.onSurface.withValues(alpha: 0.68),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleRadialBarVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFF97316),
            const Color(0xFFEC4899),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.1),
          targetColor: colorScheme.onSurface.withValues(alpha: 0.66),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleRadialBarVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
            const Color(0xFFA16207),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.14),
          targetColor: colorScheme.onSurface.withValues(alpha: 0.7),
        );
    }
  }
}

class _DefaultRadialBarTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String target;
  final String progress;
  final String targetLabel;

  const _DefaultRadialBarTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.target,
    required this.progress,
    required this.targetLabel,
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
              label: targetLabel,
              value: target,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: 'Progress',
              value: progress,
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
