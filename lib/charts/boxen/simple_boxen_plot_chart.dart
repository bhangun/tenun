import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleBoxenPlotValueFormatter = String Function(double value);
typedef SimpleBoxenPlotTapCallback =
    void Function(
      SimpleBoxenPlotData data,
      int index,
      SimpleBoxenPlotSummary summary,
    );
typedef SimpleBoxenPlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleBoxenPlotData data,
      int index,
      SimpleBoxenPlotSummary summary,
      SimpleBoxenPlotValueFormatter valueFormatter,
    );

class SimpleBoxenPlotData {
  final String label;
  final List<double> values;
  final Color? color;

  const SimpleBoxenPlotData({
    required this.label,
    required this.values,
    this.color,
  });
}

class SimpleBoxenPlotInterval {
  final double lower;
  final double upper;
  final int level;

  const SimpleBoxenPlotInterval({
    required this.lower,
    required this.upper,
    required this.level,
  });
}

class SimpleBoxenPlotSummary {
  final double min;
  final double median;
  final double max;
  final double mean;
  final int sampleCount;
  final List<SimpleBoxenPlotInterval> intervals;

  const SimpleBoxenPlotSummary({
    required this.min,
    required this.median,
    required this.max,
    required this.mean,
    required this.sampleCount,
    required this.intervals,
  });

  SimpleBoxenPlotInterval? get centralInterval =>
      intervals.isEmpty ? null : intervals.first;
}

/// A letter-value, or boxen, plot for showing deeper distribution tails than a
/// classic box plot while staying compact across categories.
class SimpleBoxenPlotChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 18, 42);

  final List<SimpleBoxenPlotData> data;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? boxColor;
  final Color? medianColor;
  final Color? whiskerColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showMedian;
  final bool showWhiskers;
  final bool showTooltip;
  final bool showActiveBox;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int maxDepth;
  final double? boxWidthFactor;
  final double? strokeWidth;
  final SimpleBoxenPlotValueFormatter? valueFormatter;
  final SimpleBoxenPlotTapCallback? onBoxTap;
  final SimpleBoxenPlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleBoxenPlotChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.boxColor,
    this.medianColor,
    this.whiskerColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showMedian = true,
    this.showWhiskers = true,
    this.showTooltip = true,
    this.showActiveBox = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.maxDepth = 4,
    this.boxWidthFactor,
    this.strokeWidth,
    this.valueFormatter,
    this.onBoxTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(maxDepth > 0),
       assert(
         boxWidthFactor == null || (boxWidthFactor > 0 && boxWidthFactor <= 1),
       ),
       assert(strokeWidth == null || strokeWidth > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleBoxenPlotVisuals.resolve(style, colorScheme);
    final resolvedData = _resolveData(data, maxDepth);
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (resolvedData.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Boxen plot chart, no data.',
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

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(resolvedData, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleBoxenPlotChartView(
            width: width,
            height: chartHeight,
            data: resolvedData.map((item) => item.data).toList(),
            summaries: resolvedData.map((item) => item.summary).toList(),
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals),
            boxColor: boxColor ?? visuals.boxColor,
            medianColor: medianColor ?? visuals.medianColor,
            whiskerColor: whiskerColor ?? visuals.whiskerColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showMedian: showMedian,
            showWhiskers: showWhiskers,
            showTooltip: showTooltip,
            showActiveBox: showActiveBox,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            boxWidthFactor: boxWidthFactor ?? visuals.boxWidthFactor,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            valueFormatter: formatter,
            onBoxTap: onBoxTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(
    ColorScheme colorScheme,
    _SimpleBoxenPlotVisuals visuals,
  ) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return [
      boxColor ?? visuals.boxColor,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
  }

  String _defaultSemanticLabel(
    List<_ResolvedBoxenPlotData> visibleData,
    SimpleBoxenPlotValueFormatter formatter,
  ) {
    final summaries = visibleData
        .take(4)
        .map((item) {
          final summary = item.summary;
          return '${item.data.label} median ${formatter(summary.median)}, '
              'range ${formatter(summary.min)}-${formatter(summary.max)}, '
              '${summary.sampleCount} samples';
        })
        .join('; ');
    final remaining = visibleData.length - math.min(visibleData.length, 4);
    final suffix = remaining > 0 ? '; and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'category' : 'categories';
    return 'Boxen plot chart, ${visibleData.length} $countLabel. '
        '$summaries$suffix.';
  }

  static List<_ResolvedBoxenPlotData> _resolveData(
    List<SimpleBoxenPlotData> data,
    int maxDepth,
  ) {
    final result = <_ResolvedBoxenPlotData>[];
    for (final item in data) {
      final summary = _summaryFrom(item, maxDepth);
      if (summary == null) continue;
      result.add(_ResolvedBoxenPlotData(data: item, summary: summary));
    }
    return result;
  }

  static SimpleBoxenPlotSummary? _summaryFrom(
    SimpleBoxenPlotData data,
    int maxDepth,
  ) {
    final values = data.values.where((value) => value.isFinite).toList()
      ..sort();
    if (values.isEmpty) return null;
    final mean = values.fold(0.0, (sum, value) => sum + value) / values.length;
    final intervals = <SimpleBoxenPlotInterval>[];
    for (var level = 0; level < maxDepth; level++) {
      final tail = 0.25 / math.pow(2, level);
      final lower = _quantile(values, tail);
      final upper = _quantile(values, 1 - tail);
      if (!lower.isFinite || !upper.isFinite || lower == upper) continue;
      intervals.add(
        SimpleBoxenPlotInterval(lower: lower, upper: upper, level: level),
      );
    }
    if (intervals.isEmpty) {
      intervals.add(
        SimpleBoxenPlotInterval(
          lower: values.first,
          upper: values.last,
          level: 0,
        ),
      );
    }
    return SimpleBoxenPlotSummary(
      min: values.first,
      median: _quantile(values, 0.5),
      max: values.last,
      mean: mean,
      sampleCount: values.length,
      intervals: intervals,
    );
  }

  static double _quantile(List<double> sorted, double p) {
    if (sorted.length == 1) return sorted.first;
    final position = p.clamp(0.0, 1.0) * (sorted.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _SimpleBoxenPlotChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleBoxenPlotData> data;
  final List<SimpleBoxenPlotSummary> summaries;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color boxColor;
  final Color medianColor;
  final Color whiskerColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showMedian;
  final bool showWhiskers;
  final bool showTooltip;
  final bool showActiveBox;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double boxWidthFactor;
  final double strokeWidth;
  final SimpleBoxenPlotValueFormatter valueFormatter;
  final SimpleBoxenPlotTapCallback? onBoxTap;
  final SimpleBoxenPlotTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleBoxenPlotChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.summaries,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.boxColor,
    required this.medianColor,
    required this.whiskerColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showMedian,
    required this.showWhiskers,
    required this.showTooltip,
    required this.showActiveBox,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.boxWidthFactor,
    required this.strokeWidth,
    required this.valueFormatter,
    required this.onBoxTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleBoxenPlotChartView> createState() =>
      _SimpleBoxenPlotChartViewState();
}

class _SimpleBoxenPlotChartViewState extends State<_SimpleBoxenPlotChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveBox || widget.onBoxTap != null;

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
                painter: _SimpleBoxenPlotPainter(
                  data: widget.data,
                  summaries: widget.summaries,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  palette: widget.palette,
                  boxColor: widget.boxColor,
                  medianColor: widget.medianColor,
                  whiskerColor: widget.whiskerColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showMedian: widget.showMedian,
                  showWhiskers: widget.showWhiskers,
                  showActiveBox: widget.showActiveBox,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  boxWidthFactor: widget.boxWidthFactor,
                  strokeWidth: widget.strokeWidth,
                  valueFormatter: widget.valueFormatter,
                  activeIndex: _activeIndex,
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
                        widget.onBoxTap?.call(
                          widget.data[index],
                          index,
                          widget.summaries[index],
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
    final geometry = _BoxenPlotGeometry.resolve(
      size: size,
      padding: widget.padding,
      summaries: widget.summaries,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
    );
    if (!geometry.plot.contains(position)) return null;
    for (var index = 0; index < geometry.layouts.length; index++) {
      final layout = geometry.layouts[index];
      final hitRect = Rect.fromLTRB(
        layout.centerX - geometry.slotWidth / 2,
        geometry.plot.top,
        layout.centerX + geometry.slotWidth / 2,
        geometry.plot.bottom,
      );
      if (hitRect.contains(position)) return index;
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final data = widget.data[index];
    final summary = widget.summaries[index];
    final geometry = _BoxenPlotGeometry.resolve(
      size: size,
      padding: widget.padding,
      summaries: widget.summaries,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
    );
    final anchor = geometry.layouts[index].anchorFor(summary.median);
    const tooltipWidth = 188.0;
    const tooltipHeight = 104.0;
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
            data,
            index,
            summary,
            widget.valueFormatter,
          ) ??
          _DefaultBoxenPlotTooltip(
            color: _boxColor(data, index),
            title: data.label,
            rows: [
              _BoxenTooltipRow(
                label: 'Median',
                value: widget.valueFormatter(summary.median),
              ),
              _BoxenTooltipRow(
                label: 'Range',
                value:
                    '${widget.valueFormatter(summary.min)}-${widget.valueFormatter(summary.max)}',
              ),
              _BoxenTooltipRow(
                label: 'Mean',
                value: widget.valueFormatter(summary.mean),
              ),
              _BoxenTooltipRow(
                label: 'Samples',
                value: summary.sampleCount.toString(),
              ),
            ],
          ),
    );
  }

  Color _boxColor(SimpleBoxenPlotData item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleBoxenPlotPainter extends CustomPainter {
  final List<SimpleBoxenPlotData> data;
  final List<SimpleBoxenPlotSummary> summaries;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color boxColor;
  final Color medianColor;
  final Color whiskerColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showMedian;
  final bool showWhiskers;
  final bool showActiveBox;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double boxWidthFactor;
  final double strokeWidth;
  final SimpleBoxenPlotValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleBoxenPlotPainter({
    required this.data,
    required this.summaries,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.boxColor,
    required this.medianColor,
    required this.whiskerColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showMedian,
    required this.showWhiskers,
    required this.showActiveBox,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.boxWidthFactor,
    required this.strokeWidth,
    required this.valueFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _BoxenPlotGeometry.resolve(
      size: size,
      padding: padding,
      summaries: summaries,
      minValue: minValue,
      maxValue: maxValue,
    );
    if (geometry.plot.width <= 0 || geometry.plot.height <= 0) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    _drawAxis(canvas, geometry);
    for (var index = 0; index < data.length; index++) {
      _drawBoxen(canvas, geometry.layouts[index], data[index], index);
    }
    _drawLabels(canvas, geometry);
  }

  void _drawReferenceBands(Canvas canvas, _BoxenPlotGeometry geometry) {
    for (final band in referenceBands) {
      final lower = math.min(band.from, band.to);
      final upper = math.max(band.from, band.to);
      if (upper < geometry.min || lower > geometry.max) continue;
      final top = geometry.yFor(upper);
      final bottom = geometry.yFor(lower);
      final color = band.color ?? axisColor;
      canvas.drawRect(
        Rect.fromLTRB(geometry.plot.left, top, geometry.plot.right, bottom),
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      if (band.label != null && band.showLabel) {
        _drawText(
          canvas,
          band.label!,
          labelStyle.copyWith(color: color),
          Offset(geometry.plot.left + 6, top + 3),
          maxWidth: geometry.plot.width - 12,
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, _BoxenPlotGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final t = index / gridLineCount;
      final y = geometry.plot.bottom - geometry.plot.height * t;
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
      final value = geometry.min + geometry.span * t;
      _drawText(
        canvas,
        valueFormatter(value),
        labelStyle,
        Offset(4, y - 8),
        maxWidth: math.max(0, padding.left - 10),
      );
    }
  }

  void _drawReferenceLines(Canvas canvas, _BoxenPlotGeometry geometry) {
    for (final line in referenceLines) {
      if (line.value < geometry.min || line.value > geometry.max) continue;
      final y = geometry.yFor(line.value);
      final paint = Paint()
        ..color = line.color ?? axisColor
        ..strokeWidth = line.strokeWidth;
      _drawStyledLine(
        canvas,
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
        line.lineStyle,
      );
      if (line.label != null && line.showLabel) {
        _drawText(
          canvas,
          line.label!,
          labelStyle.copyWith(color: line.color ?? axisColor),
          Offset(geometry.plot.right - 72, y - 18),
          maxWidth: 68,
          textAlign: TextAlign.right,
        );
      }
    }
  }

  void _drawAxis(Canvas canvas, _BoxenPlotGeometry geometry) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.bottom),
      Offset(geometry.plot.right, geometry.plot.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.top),
      Offset(geometry.plot.left, geometry.plot.bottom),
      paint,
    );
  }

  void _drawBoxen(
    Canvas canvas,
    _BoxenLayout layout,
    SimpleBoxenPlotData item,
    int index,
  ) {
    final summary = layout.summary;
    final color = item.color ?? palette[index % palette.length];
    final maxWidth = geometrySafeWidth(layout, boxWidthFactor);
    final active = index == activeIndex;

    if (showWhiskers) {
      final whiskerPaint = Paint()
        ..color = whiskerColor.withValues(alpha: 0.76)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final top = layout.yFor(summary.max);
      final bottom = layout.yFor(summary.min);
      canvas.drawLine(
        Offset(layout.centerX, top),
        Offset(layout.centerX, bottom),
        whiskerPaint,
      );
      final capWidth = maxWidth * 0.26;
      canvas.drawLine(
        Offset(layout.centerX - capWidth / 2, top),
        Offset(layout.centerX + capWidth / 2, top),
        whiskerPaint,
      );
      canvas.drawLine(
        Offset(layout.centerX - capWidth / 2, bottom),
        Offset(layout.centerX + capWidth / 2, bottom),
        whiskerPaint,
      );
    }

    for (final interval in summary.intervals.reversed) {
      final width = maxWidth * math.max(0.22, 1 - interval.level * 0.18);
      final lowerY = layout.yFor(interval.lower);
      final upperY = layout.yFor(interval.upper);
      final centerY = (lowerY + upperY) / 2;
      final animatedHeight = (lowerY - upperY).abs() * progress;
      final rect = Rect.fromCenter(
        center: Offset(layout.centerX, centerY),
        width: width,
        height: math.max(1.5, animatedHeight),
      );
      final alpha = (0.28 + (1 - interval.level / 6) * 0.42).clamp(0.24, 0.82);
      final radius = Radius.circular(math.min(8, rect.width / 4));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = color.withValues(alpha: alpha.toDouble()),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..color = color.withValues(alpha: active ? 0.9 : 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? strokeWidth + 0.8 : strokeWidth,
      );
    }

    if (showActiveBox && active) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              layout.centerX,
              (layout.yFor(summary.max) + layout.yFor(summary.min)) / 2,
            ),
            width: maxWidth + 10,
            height: (layout.yFor(summary.min) - layout.yFor(summary.max)).abs(),
          ).inflate(4),
          const Radius.circular(12),
        ),
        Paint()
          ..color = (activeColor ?? color).withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (showMedian) {
      final y = layout.yFor(summary.median);
      canvas.drawLine(
        Offset(layout.centerX - maxWidth * 0.42, y),
        Offset(layout.centerX + maxWidth * 0.42, y),
        Paint()
          ..color = medianColor
          ..strokeWidth = strokeWidth + 0.8
          ..strokeCap = StrokeCap.round,
      );
    }

    if (showValues) {
      _drawValue(canvas, layout, summary);
    }
  }

  double geometrySafeWidth(_BoxenLayout layout, double factor) {
    return math.max(8.0, layout.slotWidth * factor);
  }

  void _drawValue(
    Canvas canvas,
    _BoxenLayout layout,
    SimpleBoxenPlotSummary summary,
  ) {
    final text = valueFormatter(summary.median);
    final painter = TextPainter(
      text: TextSpan(text: text, style: valueStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: math.max(24.0, layout.slotWidth - 8));
    painter.paint(
      canvas,
      Offset(
        layout.centerX - painter.width / 2,
        layout.yFor(summary.max) - painter.height - 4,
      ),
    );
  }

  void _drawLabels(Canvas canvas, _BoxenPlotGeometry geometry) {
    for (var index = 0; index < data.length; index++) {
      final layout = geometry.layouts[index];
      final item = data[index];
      final style = index == activeIndex
          ? valueStyle.copyWith(color: valueStyle.color)
          : labelStyle;
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: math.max(16.0, geometry.slotWidth - 8));
      painter.paint(
        canvas,
        Offset(layout.centerX - painter.width / 2, geometry.plot.bottom + 8),
      );
    }
  }

  void _drawStyledLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    SimpleChartReferenceLineStyle style,
  ) {
    switch (style) {
      case SimpleChartReferenceLineStyle.solid:
        canvas.drawLine(start, end, paint);
      case SimpleChartReferenceLineStyle.dashed:
        _drawDashedLine(canvas, start, end, paint, 8, 5);
      case SimpleChartReferenceLineStyle.dotted:
        _drawDashedLine(canvas, start, end, paint, 2, 5);
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dash,
    double gap,
  ) {
    final distance = (end - start).distance;
    if (distance == 0) return;
    final direction = (end - start) / distance;
    var current = 0.0;
    while (current < distance) {
      final next = math.min(current + dash, distance);
      canvas.drawLine(
        start + direction * current,
        start + direction * next,
        paint,
      );
      current += dash + gap;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset offset, {
    required double maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    if (maxWidth <= 0) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SimpleBoxenPlotPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.summaries != summaries ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.boxColor != boxColor ||
        oldDelegate.medianColor != medianColor ||
        oldDelegate.whiskerColor != whiskerColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showMedian != showMedian ||
        oldDelegate.showWhiskers != showWhiskers ||
        oldDelegate.showActiveBox != showActiveBox ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.boxWidthFactor != boxWidthFactor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _ResolvedBoxenPlotData {
  final SimpleBoxenPlotData data;
  final SimpleBoxenPlotSummary summary;

  const _ResolvedBoxenPlotData({required this.data, required this.summary});
}

class _BoxenPlotGeometry {
  final Rect plot;
  final List<_BoxenLayout> layouts;
  final double min;
  final double max;
  final double span;
  final double slotWidth;

  const _BoxenPlotGeometry({
    required this.plot,
    required this.layouts,
    required this.min,
    required this.max,
    required this.span,
    required this.slotWidth,
  });

  double yFor(double value) {
    final t = ((value - min) / span).clamp(0.0, 1.0).toDouble();
    return plot.bottom - plot.height * t;
  }

  factory _BoxenPlotGeometry.resolve({
    required Size size,
    required EdgeInsets padding,
    required List<SimpleBoxenPlotSummary> summaries,
    required double? minValue,
    required double? maxValue,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    var lower = minValue ?? double.infinity;
    var upper = maxValue ?? double.negativeInfinity;
    for (final summary in summaries) {
      if (minValue == null) lower = math.min(lower, summary.min);
      if (maxValue == null) upper = math.max(upper, summary.max);
    }
    if (!lower.isFinite || !upper.isFinite) {
      lower = 0;
      upper = 1;
    }
    if (lower > upper) {
      final previousLower = lower;
      lower = upper;
      upper = previousLower;
    }
    if (lower == upper) {
      final pad = lower == 0 ? 1.0 : lower.abs() * 0.2;
      lower -= pad;
      upper += pad;
    }
    final span = math.max(0.000001, upper - lower);
    final slotWidth = plot.width / math.max(1, summaries.length);
    final layouts = List.generate(summaries.length, (index) {
      final centerX = plot.left + slotWidth * index + slotWidth / 2;
      return _BoxenLayout(
        plot: plot,
        summary: summaries[index],
        centerX: centerX,
        min: lower,
        span: span,
        slotWidth: slotWidth,
      );
    });
    return _BoxenPlotGeometry(
      plot: plot,
      layouts: layouts,
      min: lower,
      max: upper,
      span: span,
      slotWidth: slotWidth,
    );
  }
}

class _BoxenLayout {
  final Rect plot;
  final SimpleBoxenPlotSummary summary;
  final double centerX;
  final double min;
  final double span;
  final double slotWidth;

  const _BoxenLayout({
    required this.plot,
    required this.summary,
    required this.centerX,
    required this.min,
    required this.span,
    required this.slotWidth,
  });

  double yFor(double value) {
    final t = ((value - min) / span).clamp(0.0, 1.0).toDouble();
    return plot.bottom - plot.height * t;
  }

  Offset anchorFor(double value) => Offset(centerX, yFor(value));
}

class _SimpleBoxenPlotVisuals {
  final Color boxColor;
  final Color medianColor;
  final Color whiskerColor;
  final Color gridColor;
  final Color axisColor;
  final double boxWidthFactor;
  final double strokeWidth;

  const _SimpleBoxenPlotVisuals({
    required this.boxColor,
    required this.medianColor,
    required this.whiskerColor,
    required this.gridColor,
    required this.axisColor,
    required this.boxWidthFactor,
    required this.strokeWidth,
  });

  factory _SimpleBoxenPlotVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleBoxenPlotVisuals(
          boxColor: colorScheme.primary,
          medianColor: colorScheme.onSurface,
          whiskerColor: colorScheme.primary.withValues(alpha: 0.72),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.55),
          axisColor: colorScheme.outline,
          boxWidthFactor: 0.62,
          strokeWidth: 1.3,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleBoxenPlotVisuals(
          boxColor: const Color(0xFF2563EB),
          medianColor: const Color(0xFF0F172A),
          whiskerColor: const Color(0xFF475569),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.5),
          axisColor: colorScheme.outline,
          boxWidthFactor: 0.58,
          strokeWidth: 1.2,
        );
      case SimpleBarChartStyle.education:
        return _SimpleBoxenPlotVisuals(
          boxColor: const Color(0xFF10B981),
          medianColor: const Color(0xFF92400E),
          whiskerColor: const Color(0xFF047857),
          gridColor: colorScheme.secondary.withValues(alpha: 0.18),
          axisColor: colorScheme.secondary.withValues(alpha: 0.72),
          boxWidthFactor: 0.64,
          strokeWidth: 1.35,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleBoxenPlotVisuals(
          boxColor: colorScheme.tertiary,
          medianColor: colorScheme.primary,
          whiskerColor: colorScheme.tertiary.withValues(alpha: 0.76),
          gridColor: colorScheme.tertiary.withValues(alpha: 0.14),
          axisColor: colorScheme.outline,
          boxWidthFactor: 0.68,
          strokeWidth: 1.45,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleBoxenPlotVisuals(
          boxColor: colorScheme.primary,
          medianColor: colorScheme.secondary,
          whiskerColor: colorScheme.primary.withValues(alpha: 0.72),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.45),
          axisColor: colorScheme.outline,
          boxWidthFactor: 0.6,
          strokeWidth: 1.25,
        );
    }
  }
}

class _DefaultBoxenPlotTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final List<_BoxenTooltipRow> rows;

  const _DefaultBoxenPlotTooltip({
    required this.color,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: TextStyle(
                          color: colorScheme.onInverseSurface.withValues(
                            alpha: 0.72,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      row.value,
                      style: TextStyle(
                        color: colorScheme.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoxenTooltipRow {
  final String label;
  final String value;

  const _BoxenTooltipRow({required this.label, required this.value});
}
