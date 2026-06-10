import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleBoxPlotValueFormatter = String Function(double value);
typedef SimpleBoxPlotTapCallback =
    void Function(SimpleBoxPlotData data, int index);
typedef SimpleBoxPlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleBoxPlotData data,
      int index,
      SimpleBoxPlotSummary summary,
      SimpleBoxPlotValueFormatter valueFormatter,
    );

class SimpleBoxPlotData {
  final String label;
  final List<double> values;
  final double? min;
  final double? q1;
  final double? median;
  final double? q3;
  final double? max;
  final double? mean;
  final List<double> outliers;
  final Color? color;

  const SimpleBoxPlotData({
    required this.label,
    this.values = const [],
    this.min,
    this.q1,
    this.median,
    this.q3,
    this.max,
    this.mean,
    this.outliers = const [],
    this.color,
  });
}

/// A lightweight box-and-whisker chart for comparing spread, median, quartiles,
/// and outliers across categories.
class SimpleBoxPlotChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 18, 42);

  final List<SimpleBoxPlotData> data;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? boxColor;
  final Color? whiskerColor;
  final Color? medianColor;
  final Color? meanColor;
  final Color? outlierColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showMean;
  final bool showOutliers;
  final bool showTooltip;
  final bool showActiveBox;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? boxWidthFactor;
  final double? strokeWidth;
  final double? outlierRadius;
  final SimpleBoxPlotValueFormatter? valueFormatter;
  final SimpleBoxPlotTapCallback? onBoxTap;
  final SimpleBoxPlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleBoxPlotChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.boxColor,
    this.whiskerColor,
    this.medianColor,
    this.meanColor,
    this.outlierColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showMean = true,
    this.showOutliers = true,
    this.showTooltip = true,
    this.showActiveBox = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.boxWidthFactor,
    this.strokeWidth,
    this.outlierRadius,
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
       assert(
         boxWidthFactor == null || (boxWidthFactor > 0 && boxWidthFactor <= 1),
       ),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(outlierRadius == null || outlierRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleBoxPlotVisuals.resolve(style, colorScheme);
    final resolvedData = _resolveData(data);
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
            emptySemanticLabel: 'Box plot chart, no data.',
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
          child: _SimpleBoxPlotChartView(
            width: width,
            height: chartHeight,
            data: resolvedData.map((item) => item.data).toList(),
            summaries: resolvedData.map((item) => item.summary).toList(),
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals),
            boxColor: boxColor ?? visuals.boxColor,
            whiskerColor: whiskerColor ?? visuals.whiskerColor,
            medianColor: medianColor ?? visuals.medianColor,
            meanColor: meanColor ?? visuals.meanColor,
            outlierColor: outlierColor ?? visuals.outlierColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showMean: showMean,
            showOutliers: showOutliers,
            showTooltip: showTooltip,
            showActiveBox: showActiveBox,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            boxWidthFactor: boxWidthFactor ?? visuals.boxWidthFactor,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            outlierRadius: outlierRadius ?? visuals.outlierRadius,
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
    _SimpleBoxPlotVisuals visuals,
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
    List<_ResolvedBoxPlotData> visibleData,
    SimpleBoxPlotValueFormatter formatter,
  ) {
    final visibleItems = visibleData
        .take(5)
        .map(
          (item) =>
              '${item.data.label} min ${formatter(item.summary.min)}, '
              'q1 ${formatter(item.summary.q1)}, median '
              '${formatter(item.summary.median)}, q3 '
              '${formatter(item.summary.q3)}, max '
              '${formatter(item.summary.max)}',
        )
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 5);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'category' : 'categories';
    return 'Box plot chart, ${visibleData.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static List<_ResolvedBoxPlotData> _resolveData(List<SimpleBoxPlotData> data) {
    final resolved = <_ResolvedBoxPlotData>[];
    for (final item in data) {
      final summary = SimpleBoxPlotSummary.fromData(item);
      if (summary == null) continue;
      resolved.add(_ResolvedBoxPlotData(data: item, summary: summary));
    }
    return resolved;
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleBoxPlotChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleBoxPlotData> data;
  final List<SimpleBoxPlotSummary> summaries;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color boxColor;
  final Color whiskerColor;
  final Color medianColor;
  final Color meanColor;
  final Color outlierColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showMean;
  final bool showOutliers;
  final bool showTooltip;
  final bool showActiveBox;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double boxWidthFactor;
  final double strokeWidth;
  final double outlierRadius;
  final SimpleBoxPlotValueFormatter valueFormatter;
  final SimpleBoxPlotTapCallback? onBoxTap;
  final SimpleBoxPlotTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleBoxPlotChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.summaries,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.boxColor,
    required this.whiskerColor,
    required this.medianColor,
    required this.meanColor,
    required this.outlierColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showMean,
    required this.showOutliers,
    required this.showTooltip,
    required this.showActiveBox,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.boxWidthFactor,
    required this.strokeWidth,
    required this.outlierRadius,
    required this.valueFormatter,
    required this.onBoxTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleBoxPlotChartView> createState() =>
      _SimpleBoxPlotChartViewState();
}

class _SimpleBoxPlotChartViewState extends State<_SimpleBoxPlotChartView> {
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
                painter: _SimpleBoxPlotPainter(
                  data: widget.data,
                  summaries: widget.summaries,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  palette: widget.palette,
                  boxColor: widget.boxColor,
                  whiskerColor: widget.whiskerColor,
                  medianColor: widget.medianColor,
                  meanColor: widget.meanColor,
                  outlierColor: widget.outlierColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showMean: widget.showMean,
                  showOutliers: widget.showOutliers,
                  showActiveBox: widget.showActiveBox,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  boxWidthFactor: widget.boxWidthFactor,
                  strokeWidth: widget.strokeWidth,
                  outlierRadius: widget.outlierRadius,
                  valueFormatter: widget.valueFormatter,
                  activeIndex: widget.showActiveBox ? _activeIndex : null,
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
                        widget.onBoxTap?.call(widget.data[index], index);
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
    final geometry = _BoxPlotGeometry.resolve(
      size: size,
      summaries: widget.summaries,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      boxWidthFactor: widget.boxWidthFactor,
      showOutliers: widget.showOutliers,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
    if (geometry.plot.isEmpty ||
        !geometry.plot.inflate(12).contains(position)) {
      return null;
    }
    for (final layout in geometry.layouts) {
      if (layout.slot.inflate(5).contains(position)) return layout.index;
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final summary = widget.summaries[index];
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 208.0;
    const tooltipHeight = 154.0;
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
            widget.data[index],
            index,
            summary,
            widget.valueFormatter,
          ) ??
          _DefaultBoxPlotTooltip(
            color: _boxColor(widget.data[index], index),
            title: widget.data[index].label,
            summary: summary,
            valueFormatter: widget.valueFormatter,
            showMean: widget.showMean,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final geometry = _BoxPlotGeometry.resolve(
      size: size,
      summaries: widget.summaries,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      boxWidthFactor: widget.boxWidthFactor,
      showOutliers: widget.showOutliers,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
    final layout = geometry.layouts.firstWhere(
      (item) => item.index == index,
      orElse: () => geometry.layouts.first,
    );
    return Offset(layout.centerX, layout.boxRect.top);
  }

  Color _boxColor(SimpleBoxPlotData item, int index) {
    if (item.color != null) return item.color!;
    if (widget.palette.isEmpty) return widget.boxColor;
    return widget.palette[index % widget.palette.length];
  }
}

class _SimpleBoxPlotPainter extends CustomPainter {
  final List<SimpleBoxPlotData> data;
  final List<SimpleBoxPlotSummary> summaries;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color boxColor;
  final Color whiskerColor;
  final Color medianColor;
  final Color meanColor;
  final Color outlierColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showMean;
  final bool showOutliers;
  final bool showActiveBox;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double boxWidthFactor;
  final double strokeWidth;
  final double outlierRadius;
  final SimpleBoxPlotValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleBoxPlotPainter({
    required this.data,
    required this.summaries,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.boxColor,
    required this.whiskerColor,
    required this.medianColor,
    required this.meanColor,
    required this.outlierColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showMean,
    required this.showOutliers,
    required this.showActiveBox,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.boxWidthFactor,
    required this.strokeWidth,
    required this.outlierRadius,
    required this.valueFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _BoxPlotGeometry.resolve(
      size: size,
      summaries: summaries,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      boxWidthFactor: boxWidthFactor,
      showOutliers: showOutliers,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    if (geometry.plot.isEmpty || geometry.layouts.isEmpty) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    _drawBoxes(canvas, geometry);
    _drawLabels(canvas, geometry);
  }

  void _drawGrid(Canvas canvas, _BoxPlotGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value = geometry.min + geometry.span * (index / gridLineCount);
      final y = geometry.yForValue(value);
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
      _paintText(
        canvas,
        valueFormatter(value),
        labelStyle.copyWith(
          color: labelStyle.color?.withValues(alpha: 0.72),
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
        ),
        Offset(geometry.plot.left - 8, y),
        TextAlign.right,
        math.max(0.0, padding.left - 14),
        centeredY: true,
      );
    }
  }

  void _drawAxis(Canvas canvas, _BoxPlotGeometry geometry) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.1;
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

  void _drawReferenceBands(Canvas canvas, _BoxPlotGeometry geometry) {
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;
      final y1 = geometry.yForValue(band.from);
      final y2 = geometry.yForValue(band.to);
      final top = math.min(y1, y2);
      final bottom = math.max(y1, y2);
      if (bottom < geometry.plot.top || top > geometry.plot.bottom) continue;
      final rect = Rect.fromLTRB(
        geometry.plot.left,
        math.max(geometry.plot.top, top),
        geometry.plot.right,
        math.min(geometry.plot.bottom, bottom),
      );
      if (rect.height <= 0.5) continue;
      final color = band.color ?? boxColor;
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      if (band.showLabel) {
        _drawBadge(
          canvas,
          band.label ??
              '${valueFormatter(band.from)}-${valueFormatter(band.to)}',
          rect.topRight + const Offset(-6, 5),
          geometry.plot,
          color,
          alignRight: true,
        );
      }
    }
  }

  void _drawReferenceLines(Canvas canvas, _BoxPlotGeometry geometry) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final y = geometry.yForValue(line.value);
      if (y < geometry.plot.top - 1 || y > geometry.plot.bottom + 1) continue;
      final color = line.color ?? axisColor.withValues(alpha: 0.82);
      _drawStyledLine(
        canvas,
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        Paint()
          ..color = color
          ..strokeWidth = line.strokeWidth
          ..strokeCap = line.lineStyle == SimpleChartReferenceLineStyle.dotted
              ? StrokeCap.round
              : StrokeCap.butt,
        line.lineStyle,
      );
      if (line.showLabel) {
        _drawBadge(
          canvas,
          line.label ?? valueFormatter(line.value),
          Offset(geometry.plot.right - 6, y + 5),
          geometry.plot,
          color,
          alignRight: true,
        );
      }
    }
  }

  void _drawBoxes(Canvas canvas, _BoxPlotGeometry geometry) {
    for (final layout in geometry.layouts) {
      final item = data[layout.index];
      final summary = summaries[layout.index];
      final color = _boxColor(item, layout.index);
      final selected = activeIndex == layout.index;
      final activeExists = activeIndex != null;
      final opacity = activeExists && !selected ? 0.36 : 1.0;
      final animated = layout.animate(progress, geometry.plot.bottom);
      final linePaint = Paint()
        ..color = whiskerColor.withValues(alpha: opacity)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final fillPaint = Paint()..color = color.withValues(alpha: 0.2 * opacity);
      final outlinePaint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawLine(
        Offset(layout.centerX, animated.minY),
        Offset(layout.centerX, animated.maxY),
        linePaint,
      );
      canvas.drawLine(
        Offset(layout.centerX - layout.capHalfWidth, animated.minY),
        Offset(layout.centerX + layout.capHalfWidth, animated.minY),
        linePaint,
      );
      canvas.drawLine(
        Offset(layout.centerX - layout.capHalfWidth, animated.maxY),
        Offset(layout.centerX + layout.capHalfWidth, animated.maxY),
        linePaint,
      );

      final radius = Radius.circular(math.min(6, animated.boxRect.width / 4));
      final rrect = RRect.fromRectAndRadius(animated.boxRect, radius);
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, outlinePaint);
      if (showActiveBox && selected) {
        canvas.drawRRect(
          rrect.inflate(3),
          Paint()
            ..color = (activeColor ?? color).withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }

      canvas.drawLine(
        Offset(animated.boxRect.left, animated.medianY),
        Offset(animated.boxRect.right, animated.medianY),
        Paint()
          ..color = medianColor.withValues(alpha: opacity)
          ..strokeWidth = strokeWidth + 0.8
          ..strokeCap = StrokeCap.round,
      );

      if (showMean && summary.mean != null) {
        _drawMean(canvas, layout.centerX, animated.meanY!, opacity);
      }
      if (showOutliers) {
        _drawOutliers(canvas, summary, layout, geometry, opacity);
      }
      if (showValues && progress > 0.7) {
        _paintText(
          canvas,
          valueFormatter(summary.median),
          valueStyle,
          Offset(layout.centerX, animated.boxRect.top - 18),
          TextAlign.center,
          math.max(36.0, layout.boxRect.width + 16),
        );
      }
    }
  }

  void _drawMean(Canvas canvas, double x, double y, double opacity) {
    const radius = 5.0;
    final path = Path()
      ..moveTo(x, y - radius)
      ..lineTo(x + radius, y)
      ..lineTo(x, y + radius)
      ..lineTo(x - radius, y)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = meanColor.withValues(alpha: 0.9 * opacity)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.82 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawOutliers(
    Canvas canvas,
    SimpleBoxPlotSummary summary,
    _BoxLayout layout,
    _BoxPlotGeometry geometry,
    double opacity,
  ) {
    for (var index = 0; index < summary.outliers.length; index++) {
      final value = summary.outliers[index];
      if (!value.isFinite) continue;
      final y = geometry.yForValue(value);
      final animatedY =
          geometry.plot.bottom - (geometry.plot.bottom - y) * progress;
      final jitter =
          ((index % 5) - 2) * math.min(3.0, layout.boxRect.width / 18);
      canvas.drawCircle(
        Offset(layout.centerX + jitter, animatedY),
        outlierRadius + 1,
        Paint()..color = Colors.white.withValues(alpha: 0.86 * opacity),
      );
      canvas.drawCircle(
        Offset(layout.centerX + jitter, animatedY),
        outlierRadius,
        Paint()..color = outlierColor.withValues(alpha: 0.92 * opacity),
      );
    }
  }

  void _drawLabels(Canvas canvas, _BoxPlotGeometry geometry) {
    for (final layout in geometry.layouts) {
      _paintText(
        canvas,
        data[layout.index].label,
        labelStyle,
        Offset(layout.centerX, geometry.plot.bottom + 8),
        TextAlign.center,
        math.max(34.0, geometry.slotWidth - 6),
      );
    }
  }

  void _drawBadge(
    Canvas canvas,
    String text,
    Offset anchor,
    Rect plot,
    Color color, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(
          color: color,
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 112);
    const insets = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + insets.horizontal;
    final height = painter.height + insets.vertical;
    final left = _safeClamp(
      alignRight ? anchor.dx - width : anchor.dx,
      plot.left + 2,
      plot.right - width - 2,
    );
    final top = _safeClamp(anchor.dy, plot.top + 2, plot.bottom - height - 2);
    final rect = Rect.fromLTWH(left, top, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = color.withValues(alpha: 0.12),
    );
    painter.paint(canvas, Offset(left + insets.left, top + insets.top));
  }

  void _drawStyledLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    SimpleChartReferenceLineStyle style,
  ) {
    if (style == SimpleChartReferenceLineStyle.solid) {
      canvas.drawLine(start, end, paint);
      return;
    }
    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) return;
    final direction = delta / distance;
    final dash = style == SimpleChartReferenceLineStyle.dotted ? 1.0 : 7.0;
    final gap = 5.0;
    var traveled = 0.0;
    while (traveled < distance) {
      final next = math.min(traveled + dash, distance);
      canvas.drawLine(
        start + direction * traveled,
        start + direction * next,
        paint,
      );
      traveled = next + gap;
    }
  }

  Color _boxColor(SimpleBoxPlotData item, int index) {
    if (item.color != null) return item.color!;
    if (palette.isEmpty) return boxColor;
    return palette[index % palette.length];
  }

  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset anchor,
    TextAlign align,
    double maxWidth, {
    bool centeredY = false,
  }) {
    if (maxWidth <= 0) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);

    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.center => anchor.dx - painter.width / 2,
      _ => anchor.dx,
    };
    final dy = centeredY ? anchor.dy - painter.height / 2 : anchor.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  double _safeClamp(double value, double min, double max) {
    if (max < min) return min;
    return value.clamp(min, max).toDouble();
  }

  @override
  bool shouldRepaint(covariant _SimpleBoxPlotPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.summaries != summaries ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.boxColor != boxColor ||
        oldDelegate.whiskerColor != whiskerColor ||
        oldDelegate.medianColor != medianColor ||
        oldDelegate.meanColor != meanColor ||
        oldDelegate.outlierColor != outlierColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showMean != showMean ||
        oldDelegate.showOutliers != showOutliers ||
        oldDelegate.showActiveBox != showActiveBox ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.boxWidthFactor != boxWidthFactor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.outlierRadius != outlierRadius ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _ResolvedBoxPlotData {
  final SimpleBoxPlotData data;
  final SimpleBoxPlotSummary summary;

  const _ResolvedBoxPlotData({required this.data, required this.summary});
}

class SimpleBoxPlotSummary {
  final double min;
  final double q1;
  final double median;
  final double q3;
  final double max;
  final double? mean;
  final List<double> outliers;

  const SimpleBoxPlotSummary({
    required this.min,
    required this.q1,
    required this.median,
    required this.q3,
    required this.max,
    required this.mean,
    required this.outliers,
  });

  static SimpleBoxPlotSummary? fromData(SimpleBoxPlotData data) {
    final hasSummary =
        data.min != null &&
        data.q1 != null &&
        data.median != null &&
        data.q3 != null &&
        data.max != null;
    if (hasSummary) {
      final values = [data.min!, data.q1!, data.median!, data.q3!, data.max!];
      if (values.any((value) => !value.isFinite)) return null;
      values.sort();
      return SimpleBoxPlotSummary(
        min: values[0],
        q1: values[1],
        median: values[2],
        q3: values[3],
        max: values[4],
        mean: data.mean?.isFinite == true ? data.mean : null,
        outliers: data.outliers.where((value) => value.isFinite).toList(),
      );
    }

    final values = data.values.where((value) => value.isFinite).toList()
      ..sort();
    if (values.isEmpty) return null;
    final q1 = _quantile(values, 0.25);
    final median = _quantile(values, 0.5);
    final q3 = _quantile(values, 0.75);
    final iqr = q3 - q1;
    final lowFence = q1 - 1.5 * iqr;
    final highFence = q3 + 1.5 * iqr;
    final inliers = values
        .where((value) => value >= lowFence && value <= highFence)
        .toList();
    final outliers = values
        .where((value) => value < lowFence || value > highFence)
        .toList();
    final mean = values.fold(0.0, (sum, value) => sum + value) / values.length;
    return SimpleBoxPlotSummary(
      min: inliers.isEmpty ? values.first : inliers.first,
      q1: q1,
      median: median,
      q3: q3,
      max: inliers.isEmpty ? values.last : inliers.last,
      mean: mean,
      outliers: outliers,
    );
  }

  static double _quantile(List<double> sorted, double p) {
    if (sorted.length == 1) return sorted.first;
    final position = p * (sorted.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
  }
}

class _BoxPlotGeometry {
  final Rect plot;
  final List<_BoxLayout> layouts;
  final double min;
  final double span;
  final double slotWidth;

  const _BoxPlotGeometry({
    required this.plot,
    required this.layouts,
    required this.min,
    required this.span,
    required this.slotWidth,
  });

  factory _BoxPlotGeometry.resolve({
    required Size size,
    required List<SimpleBoxPlotSummary> summaries,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required double boxWidthFactor,
    required bool showOutliers,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    var lower = double.infinity;
    var upper = double.negativeInfinity;
    for (final summary in summaries) {
      lower = math.min(lower, summary.min);
      upper = math.max(upper, summary.max);
      if (summary.mean != null) {
        lower = math.min(lower, summary.mean!);
        upper = math.max(upper, summary.mean!);
      }
      if (showOutliers) {
        for (final value in summary.outliers) {
          lower = math.min(lower, value);
          upper = math.max(upper, value);
        }
      }
    }
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      lower = math.min(lower, line.value);
      upper = math.max(upper, line.value);
    }
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;
      lower = math.min(lower, math.min(band.from, band.to));
      upper = math.max(upper, math.max(band.from, band.to));
    }
    if (!lower.isFinite || !upper.isFinite) {
      lower = 0;
      upper = 1;
    }
    if (minValue != null && minValue.isFinite) lower = minValue;
    if (maxValue != null && maxValue.isFinite) upper = maxValue;
    if (lower > upper) {
      final swap = lower;
      lower = upper;
      upper = swap;
    }
    if (lower == upper) {
      final spread = lower == 0 ? 1.0 : lower.abs() * 0.08;
      lower -= spread;
      upper += spread;
    }

    final span = math.max(1e-9, upper - lower);
    double yForValue(double value) {
      final normalized = ((value - lower) / span).clamp(0.0, 1.0).toDouble();
      return plot.bottom - normalized * plot.height;
    }

    final slotWidth = summaries.isEmpty ? 0.0 : plot.width / summaries.length;
    final layouts = <_BoxLayout>[];
    for (var index = 0; index < summaries.length; index++) {
      final summary = summaries[index];
      final centerX = plot.left + slotWidth * index + slotWidth / 2;
      final boxWidth = math.max(8.0, slotWidth * boxWidthFactor);
      final left = centerX - boxWidth / 2;
      final right = centerX + boxWidth / 2;
      final q3Y = yForValue(summary.q3);
      final q1Y = yForValue(summary.q1);
      layouts.add(
        _BoxLayout(
          index: index,
          centerX: centerX,
          slot: Rect.fromLTWH(
            plot.left + slotWidth * index,
            plot.top,
            slotWidth,
            plot.height,
          ),
          boxRect: Rect.fromLTRB(left, q3Y, right, q1Y),
          minY: yForValue(summary.min),
          maxY: yForValue(summary.max),
          medianY: yForValue(summary.median),
          meanY: summary.mean == null ? null : yForValue(summary.mean!),
          capHalfWidth: boxWidth * 0.36,
        ),
      );
    }

    return _BoxPlotGeometry(
      plot: plot,
      layouts: layouts,
      min: lower,
      span: span,
      slotWidth: slotWidth,
    );
  }

  double yForValue(double value) {
    final normalized = ((value - min) / span).clamp(0.0, 1.0).toDouble();
    return plot.bottom - normalized * plot.height;
  }
}

class _BoxLayout {
  final int index;
  final double centerX;
  final Rect slot;
  final Rect boxRect;
  final double minY;
  final double maxY;
  final double medianY;
  final double? meanY;
  final double capHalfWidth;

  const _BoxLayout({
    required this.index,
    required this.centerX,
    required this.slot,
    required this.boxRect,
    required this.minY,
    required this.maxY,
    required this.medianY,
    required this.meanY,
    required this.capHalfWidth,
  });

  _AnimatedBoxLayout animate(double progress, double baseline) {
    double animateY(double y) => baseline - (baseline - y) * progress;
    final top = animateY(boxRect.top);
    final bottom = animateY(boxRect.bottom);
    return _AnimatedBoxLayout(
      boxRect: Rect.fromLTRB(boxRect.left, top, boxRect.right, bottom),
      minY: animateY(minY),
      maxY: animateY(maxY),
      medianY: animateY(medianY),
      meanY: meanY == null ? null : animateY(meanY!),
    );
  }
}

class _AnimatedBoxLayout {
  final Rect boxRect;
  final double minY;
  final double maxY;
  final double medianY;
  final double? meanY;

  const _AnimatedBoxLayout({
    required this.boxRect,
    required this.minY,
    required this.maxY,
    required this.medianY,
    required this.meanY,
  });
}

class _SimpleBoxPlotVisuals {
  final Color boxColor;
  final Color whiskerColor;
  final Color medianColor;
  final Color meanColor;
  final Color outlierColor;
  final Color gridColor;
  final Color axisColor;
  final double boxWidthFactor;
  final double strokeWidth;
  final double outlierRadius;

  const _SimpleBoxPlotVisuals({
    required this.boxColor,
    required this.whiskerColor,
    required this.medianColor,
    required this.meanColor,
    required this.outlierColor,
    required this.gridColor,
    required this.axisColor,
    required this.boxWidthFactor,
    required this.strokeWidth,
    required this.outlierRadius,
  });

  factory _SimpleBoxPlotVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleBoxPlotVisuals(
          boxColor: colorScheme.primary,
          whiskerColor: colorScheme.outline,
          medianColor: colorScheme.onSurface,
          meanColor: colorScheme.tertiary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          boxWidthFactor: 0.48,
          strokeWidth: 2,
          outlierRadius: 3.3,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleBoxPlotVisuals(
          boxColor: colorScheme.primary,
          whiskerColor: colorScheme.outline.withValues(alpha: 0.9),
          medianColor: colorScheme.onSurface,
          meanColor: colorScheme.secondary,
          outlierColor: colorScheme.error.withValues(alpha: 0.86),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          boxWidthFactor: 0.42,
          strokeWidth: 1.7,
          outlierRadius: 3,
        );
      case SimpleBarChartStyle.education:
        return _SimpleBoxPlotVisuals(
          boxColor: colorScheme.secondary,
          whiskerColor: colorScheme.outline,
          medianColor: colorScheme.primary,
          meanColor: colorScheme.tertiary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          boxWidthFactor: 0.5,
          strokeWidth: 2,
          outlierRadius: 3.4,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleBoxPlotVisuals(
          boxColor: colorScheme.tertiary,
          whiskerColor: colorScheme.outline,
          medianColor: colorScheme.onSurface,
          meanColor: colorScheme.primary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          boxWidthFactor: 0.54,
          strokeWidth: 2.2,
          outlierRadius: 3.5,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleBoxPlotVisuals(
          boxColor: colorScheme.primary,
          whiskerColor: colorScheme.outline,
          medianColor: colorScheme.onSurface,
          meanColor: colorScheme.tertiary,
          outlierColor: colorScheme.error.withValues(alpha: 0.88),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          boxWidthFactor: 0.46,
          strokeWidth: 1.9,
          outlierRadius: 3.2,
        );
    }
  }
}

class _DefaultBoxPlotTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final SimpleBoxPlotSummary summary;
  final SimpleBoxPlotValueFormatter valueFormatter;
  final bool showMean;

  const _DefaultBoxPlotTooltip({
    required this.color,
    required this.title,
    required this.summary,
    required this.valueFormatter,
    required this.showMean,
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
                    borderRadius: BorderRadius.circular(2),
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
              label: 'Min',
              value: valueFormatter(summary.min),
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: 'Q1',
              value: valueFormatter(summary.q1),
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: 'Median',
              value: valueFormatter(summary.median),
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: color),
            ),
            _TooltipRow(
              label: 'Q3',
              value: valueFormatter(summary.q3),
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: 'Max',
              value: valueFormatter(summary.max),
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            if (showMean && summary.mean != null)
              _TooltipRow(
                label: 'Mean',
                value: valueFormatter(summary.mean!),
                labelStyle: labelStyle,
                valueStyle: valueStyle,
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
