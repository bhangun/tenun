import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleDonutValueFormatter = String Function(double value);
typedef SimpleDonutTapCallback =
    void Function(SimpleDonutChartData data, int index, double share);
typedef SimpleDonutTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleDonutChartData data,
      int index,
      String formattedValue,
      String formattedShare,
    );

class SimpleDonutChartData {
  final String label;
  final double value;
  final Color? color;

  const SimpleDonutChartData({
    required this.label,
    required this.value,
    this.color,
  });
}

/// A polished composition chart for showing proportions with a compact center
/// summary and optional legend.
class SimpleDonutChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(14, 12, 14, 12);

  final List<SimpleDonutChartData> data;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? trackColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final String? centerLabel;
  final String? centerValue;
  final bool showLabels;
  final bool showLegend;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveSegment;
  final double innerRadiusFactor;
  final double segmentSpacing;
  final double startAngle;
  final SimpleDonutValueFormatter? valueFormatter;
  final SimpleDonutValueFormatter? shareFormatter;
  final SimpleDonutTapCallback? onSegmentTap;
  final SimpleDonutTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleDonutChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 250,
    this.padding = _defaultPadding,
    this.palette,
    this.trackColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.centerLabel,
    this.centerValue,
    this.showLabels = true,
    this.showLegend = true,
    this.showValues = true,
    this.showTooltip = true,
    this.showActiveSegment = true,
    this.innerRadiusFactor = 0.62,
    this.segmentSpacing = 0.018,
    this.startAngle = -math.pi / 2,
    this.valueFormatter,
    this.shareFormatter,
    this.onSegmentTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(innerRadiusFactor > 0 && innerRadiusFactor < 0.92),
       assert(segmentSpacing >= 0 && segmentSpacing <= 0.12);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleDonutVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.value.isFinite && item.value > 0)
        .toList();
    final total = visibleData.fold(0.0, (sum, item) => sum + item.value);
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedShareFormatter = shareFormatter ?? _defaultShareFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty || total <= 0) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Donut chart, no data.',
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
            total,
            formatter,
            resolvedShareFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleDonutChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            total: total,
            padding: padding,
            palette: resolvedPalette,
            trackColor: trackColor ?? visuals.trackColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            centerLabel: centerLabel,
            centerValue: centerValue ?? formatter(total),
            showLabels: showLabels,
            showLegend: showLegend,
            showValues: showValues,
            showTooltip: showTooltip,
            showActiveSegment: showActiveSegment,
            innerRadiusFactor: innerRadiusFactor,
            segmentSpacing: segmentSpacing,
            startAngle: startAngle,
            valueFormatter: formatter,
            shareFormatter: resolvedShareFormatter,
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
    List<SimpleDonutChartData> visibleData,
    double total,
    SimpleDonutValueFormatter formatter,
    SimpleDonutValueFormatter resolvedShareFormatter,
  ) {
    final visibleItems = visibleData
        .take(6)
        .map((item) {
          final share = item.value / total;
          return '${item.label} ${formatter(item.value)}, '
              '${resolvedShareFormatter(share)}';
        })
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'segment' : 'segments';
    return 'Donut chart, ${visibleData.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultShareFormatter(double value) {
    return '${(value * 100).toStringAsFixed(value < 0.1 ? 1 : 0)}%';
  }
}

class _SimpleDonutChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleDonutChartData> data;
  final double total;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color trackColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final String? centerLabel;
  final String centerValue;
  final bool showLabels;
  final bool showLegend;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveSegment;
  final double innerRadiusFactor;
  final double segmentSpacing;
  final double startAngle;
  final SimpleDonutValueFormatter valueFormatter;
  final SimpleDonutValueFormatter shareFormatter;
  final SimpleDonutTapCallback? onSegmentTap;
  final SimpleDonutTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleDonutChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.total,
    required this.padding,
    required this.palette,
    required this.trackColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.centerLabel,
    required this.centerValue,
    required this.showLabels,
    required this.showLegend,
    required this.showValues,
    required this.showTooltip,
    required this.showActiveSegment,
    required this.innerRadiusFactor,
    required this.segmentSpacing,
    required this.startAngle,
    required this.valueFormatter,
    required this.shareFormatter,
    required this.onSegmentTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleDonutChartView> createState() => _SimpleDonutChartViewState();
}

class _SimpleDonutChartViewState extends State<_SimpleDonutChartView> {
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
                painter: _SimpleDonutPainter(
                  data: widget.data,
                  total: widget.total,
                  padding: widget.padding,
                  palette: widget.palette,
                  trackColor: widget.trackColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  centerLabel: widget.centerLabel,
                  centerValue: widget.centerValue,
                  showLabels: widget.showLabels,
                  showLegend: widget.showLegend,
                  showValues: widget.showValues,
                  innerRadiusFactor: widget.innerRadiusFactor,
                  segmentSpacing: widget.segmentSpacing,
                  startAngle: widget.startAngle,
                  valueFormatter: widget.valueFormatter,
                  shareFormatter: widget.shareFormatter,
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
                      if (index != null) {
                        widget.onSegmentTap?.call(
                          widget.data[index],
                          index,
                          widget.data[index].value / widget.total,
                        );
                      }
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
    final layout = _DonutLayout.resolve(
      size,
      widget.padding,
      widget.showLegend,
      widget.showLabels,
    );
    final center = layout.center;
    final delta = position - center;
    final distance = delta.distance;
    final innerRadius = layout.outerRadius * widget.innerRadiusFactor;
    if (distance < innerRadius - 10 || distance > layout.outerRadius + 10) {
      return null;
    }

    final angle = _normalizeAngle(math.atan2(delta.dy, delta.dx));
    final segments = _computeSegments(
      widget.data,
      widget.total,
      widget.startAngle,
    );
    for (var index = 0; index < segments.length; index++) {
      if (_angleInSegment(angle, segments[index])) return index;
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final item = widget.data[index];
    final share = item.value / widget.total;
    final formattedValue = widget.valueFormatter(item.value);
    final formattedShare = widget.shareFormatter(share);
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
            formattedShare,
          ) ??
          _DefaultDonutTooltip(
            color: _segmentColor(item, index),
            title: item.label,
            value: formattedValue,
            share: formattedShare,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final layout = _DonutLayout.resolve(
      size,
      widget.padding,
      widget.showLegend,
      widget.showLabels,
    );
    final segments = _computeSegments(
      widget.data,
      widget.total,
      widget.startAngle,
    );
    final segment = segments[index];
    final angle = segment.start + segment.sweep / 2;
    final radius = layout.outerRadius + 8;
    return Offset(
      layout.center.dx + math.cos(angle) * radius,
      layout.center.dy + math.sin(angle) * radius,
    );
  }

  Color _segmentColor(SimpleDonutChartData item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleDonutPainter extends CustomPainter {
  final List<SimpleDonutChartData> data;
  final double total;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color trackColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final String? centerLabel;
  final String centerValue;
  final bool showLabels;
  final bool showLegend;
  final bool showValues;
  final double innerRadiusFactor;
  final double segmentSpacing;
  final double startAngle;
  final SimpleDonutValueFormatter valueFormatter;
  final SimpleDonutValueFormatter shareFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleDonutPainter({
    required this.data,
    required this.total,
    required this.padding,
    required this.palette,
    required this.trackColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.centerLabel,
    required this.centerValue,
    required this.showLabels,
    required this.showLegend,
    required this.showValues,
    required this.innerRadiusFactor,
    required this.segmentSpacing,
    required this.startAngle,
    required this.valueFormatter,
    required this.shareFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _DonutLayout.resolve(size, padding, showLegend, showLabels);
    if (layout.outerRadius <= 0 || data.isEmpty || total <= 0) return;

    final innerRadius = layout.outerRadius * innerRadiusFactor;
    final strokeWidth = math.max(1.0, layout.outerRadius - innerRadius);
    final ringRadius = innerRadius + strokeWidth / 2;
    final ringRect = Rect.fromCircle(center: layout.center, radius: ringRadius);
    final segments = _computeSegments(data, total, startAngle);

    _drawTrack(canvas, ringRect, strokeWidth);
    _drawSegments(canvas, ringRect, strokeWidth, segments);
    _drawCenterText(canvas, layout, innerRadius);
    if (showLabels) {
      _drawSliceLabels(canvas, layout, segments);
    }
    if (showLegend) {
      _drawLegend(canvas, layout, segments);
    }
  }

  void _drawTrack(Canvas canvas, Rect ringRect, double strokeWidth) {
    canvas.drawArc(
      ringRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );
  }

  void _drawSegments(
    Canvas canvas,
    Rect ringRect,
    double strokeWidth,
    List<_DonutSegment> segments,
  ) {
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final active = index == activeIndex;
      final color = activeColor ?? _segmentColor(segment.data, index);
      final segmentColor = _segmentColor(segment.data, index);
      final visibleSweep = math.max(
        0.0,
        segment.sweep * progress - segmentSpacing,
      );
      if (visibleSweep <= 0) continue;

      final activeStroke = active ? strokeWidth + 4 : strokeWidth;
      canvas.drawArc(
        ringRect,
        segment.start + segmentSpacing / 2,
        visibleSweep,
        false,
        Paint()
          ..color = (active ? color : segmentColor).withValues(
            alpha: active ? 0.96 : 0.88,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = activeStroke
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  void _drawCenterText(Canvas canvas, _DonutLayout layout, double innerRadius) {
    final valuePainter = _textPainter(
      centerValue,
      valueStyle.copyWith(
        fontSize: math.min(24, (valueStyle.fontSize ?? 12) * 1.55),
        fontWeight: FontWeight.w800,
      ),
      maxWidth: innerRadius * 1.5,
      textAlign: TextAlign.center,
    )..layout(maxWidth: innerRadius * 1.5);
    final labelText = centerLabel ?? 'Total';
    final labelPainter = _textPainter(
      labelText,
      labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 12) * 0.92),
      maxWidth: innerRadius * 1.45,
      textAlign: TextAlign.center,
    )..layout(maxWidth: innerRadius * 1.45);
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

  void _drawSliceLabels(
    Canvas canvas,
    _DonutLayout layout,
    List<_DonutSegment> segments,
  ) {
    if (layout.compact) return;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (segment.share < 0.055) continue;
      final angle = segment.start + segment.sweep / 2;
      final anchor = Offset(
        layout.center.dx + math.cos(angle) * (layout.outerRadius + 12),
        layout.center.dy + math.sin(angle) * (layout.outerRadius + 12),
      );
      final label = shareFormatter(segment.share);
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
    _DonutLayout layout,
    List<_DonutSegment> segments,
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

      final value = showValues ? ' ${shareFormatter(segment.share)}' : '';
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

  Color _segmentColor(SimpleDonutChartData item, int index) {
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
  bool shouldRepaint(covariant _SimpleDonutPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.total != total ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.centerLabel != centerLabel ||
        oldDelegate.centerValue != centerValue ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showValues != showValues ||
        oldDelegate.innerRadiusFactor != innerRadiusFactor ||
        oldDelegate.segmentSpacing != segmentSpacing ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.shareFormatter != shareFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

List<_DonutSegment> _computeSegments(
  List<SimpleDonutChartData> data,
  double total,
  double startAngle,
) {
  final segments = <_DonutSegment>[];
  var cursor = startAngle;
  for (final item in data) {
    final share = item.value / total;
    final sweep = share * math.pi * 2;
    segments.add(
      _DonutSegment(data: item, start: cursor, sweep: sweep, share: share),
    );
    cursor += sweep;
  }
  return segments;
}

bool _angleInSegment(double normalizedAngle, _DonutSegment segment) {
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

class _DonutSegment {
  final SimpleDonutChartData data;
  final double start;
  final double sweep;
  final double share;

  const _DonutSegment({
    required this.data,
    required this.start,
    required this.sweep,
    required this.share,
  });
}

class _DonutLayout {
  final Offset center;
  final double outerRadius;
  final Rect legendRect;
  final double chartRight;
  final double bottom;
  final bool compact;

  const _DonutLayout({
    required this.center,
    required this.outerRadius,
    required this.legendRect,
    required this.chartRight,
    required this.bottom,
    required this.compact,
  });

  factory _DonutLayout.resolve(
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
    final labelInset = showLabels && !compact ? 18.0 : 4.0;
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
    return _DonutLayout(
      center: center,
      outerRadius: outerRadius,
      legendRect: legendRect,
      chartRight: chartRect.right,
      bottom: content.bottom,
      compact: compact,
    );
  }
}

class _SimpleDonutVisuals {
  final List<Color> palette;
  final Color trackColor;

  const _SimpleDonutVisuals({required this.palette, required this.trackColor});

  factory _SimpleDonutVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleDonutVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF22C55E),
            const Color(0xFFF59E0B),
            const Color(0xFF06B6D4),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.12),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleDonutVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            colorScheme.secondary,
            const Color(0xFF64748B),
            const Color(0xFF0F766E),
            const Color(0xFF475569),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.18),
        );
      case SimpleBarChartStyle.education:
        return _SimpleDonutVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFFF59E0B),
            const Color(0xFF22C55E),
            const Color(0xFFEF4444),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.16),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleDonutVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFF97316),
            const Color(0xFFEC4899),
            const Color(0xFF84CC16),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.1),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleDonutVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
            const Color(0xFFA16207),
            const Color(0xFFBE123C),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.14),
        );
    }
  }
}

class _DefaultDonutTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String share;

  const _DefaultDonutTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.share,
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
                    '$value / $share',
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
