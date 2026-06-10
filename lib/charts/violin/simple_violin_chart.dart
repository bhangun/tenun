import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleViolinValueFormatter = String Function(double value);
typedef SimpleViolinTapCallback =
    void Function(SimpleViolinChartData data, int index);
typedef SimpleViolinTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleViolinChartData data,
      int index,
      SimpleViolinStats stats,
      SimpleViolinValueFormatter valueFormatter,
    );

class SimpleViolinChartData {
  final String label;
  final List<double> values;
  final Color? color;

  const SimpleViolinChartData({
    required this.label,
    required this.values,
    this.color,
  });
}

class SimpleViolinStats {
  final int count;
  final double min;
  final double q1;
  final double median;
  final double q3;
  final double max;
  final double mean;
  final List<double> outliers;

  const SimpleViolinStats({
    required this.count,
    required this.min,
    required this.q1,
    required this.median,
    required this.q3,
    required this.max,
    required this.mean,
    this.outliers = const [],
  });
}

/// A lightweight violin chart for comparing distribution shape across
/// categories, cohorts, segments, or experiments.
class SimpleViolinChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 18, 42);

  final List<SimpleViolinChartData> data;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? violinColor;
  final Color? outlineColor;
  final Color? boxColor;
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
  final bool showBoxPlot;
  final bool showMean;
  final bool showOutliers;
  final bool showTooltip;
  final bool showActiveViolin;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int densitySteps;
  final double? widthFactor;
  final double? strokeWidth;
  final double? outlierRadius;
  final SimpleViolinValueFormatter? valueFormatter;
  final SimpleViolinTapCallback? onViolinTap;
  final SimpleViolinTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleViolinChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.violinColor,
    this.outlineColor,
    this.boxColor,
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
    this.showBoxPlot = true,
    this.showMean = true,
    this.showOutliers = true,
    this.showTooltip = true,
    this.showActiveViolin = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.densitySteps = 36,
    this.widthFactor,
    this.strokeWidth,
    this.outlierRadius,
    this.valueFormatter,
    this.onViolinTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(densitySteps >= 8),
       assert(widthFactor == null || (widthFactor > 0 && widthFactor <= 1)),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(outlierRadius == null || outlierRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleViolinVisuals.resolve(style, colorScheme);
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
            emptySemanticLabel: 'Violin chart, no data.',
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
          child: _SimpleViolinChartView(
            width: width,
            height: chartHeight,
            data: resolvedData.map((item) => item.data).toList(),
            stats: resolvedData.map((item) => item.stats).toList(),
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals),
            violinColor: violinColor ?? visuals.violinColor,
            outlineColor: outlineColor ?? visuals.outlineColor,
            boxColor: boxColor ?? visuals.boxColor,
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
            showBoxPlot: showBoxPlot,
            showMean: showMean,
            showOutliers: showOutliers,
            showTooltip: showTooltip,
            showActiveViolin: showActiveViolin,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            densitySteps: densitySteps,
            widthFactor: widthFactor ?? visuals.widthFactor,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            outlierRadius: outlierRadius ?? visuals.outlierRadius,
            valueFormatter: formatter,
            onViolinTap: onViolinTap,
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
    _SimpleViolinVisuals visuals,
  ) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return [
      violinColor ?? visuals.violinColor,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
  }

  String _defaultSemanticLabel(
    List<_ResolvedViolinData> visibleData,
    SimpleViolinValueFormatter formatter,
  ) {
    final visibleItems = visibleData
        .take(5)
        .map(
          (item) =>
              '${item.data.label} count ${item.stats.count}, min '
              '${formatter(item.stats.min)}, median '
              '${formatter(item.stats.median)}, max '
              '${formatter(item.stats.max)}',
        )
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 5);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'category' : 'categories';
    return 'Violin chart, ${visibleData.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static List<_ResolvedViolinData> _resolveData(
    List<SimpleViolinChartData> data,
  ) {
    final resolved = <_ResolvedViolinData>[];
    for (final item in data) {
      final values = item.values.where((value) => value.isFinite).toList()
        ..sort();
      if (values.isEmpty) continue;
      resolved.add(_ResolvedViolinData(data: item, stats: _statsFor(values)));
    }
    return resolved;
  }

  static SimpleViolinStats _statsFor(List<double> values) {
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
    return SimpleViolinStats(
      count: values.length,
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

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleViolinChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleViolinChartData> data;
  final List<SimpleViolinStats> stats;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color violinColor;
  final Color outlineColor;
  final Color boxColor;
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
  final bool showBoxPlot;
  final bool showMean;
  final bool showOutliers;
  final bool showTooltip;
  final bool showActiveViolin;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int densitySteps;
  final double widthFactor;
  final double strokeWidth;
  final double outlierRadius;
  final SimpleViolinValueFormatter valueFormatter;
  final SimpleViolinTapCallback? onViolinTap;
  final SimpleViolinTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleViolinChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.stats,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.violinColor,
    required this.outlineColor,
    required this.boxColor,
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
    required this.showBoxPlot,
    required this.showMean,
    required this.showOutliers,
    required this.showTooltip,
    required this.showActiveViolin,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.densitySteps,
    required this.widthFactor,
    required this.strokeWidth,
    required this.outlierRadius,
    required this.valueFormatter,
    required this.onViolinTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleViolinChartView> createState() => _SimpleViolinChartViewState();
}

class _SimpleViolinChartViewState extends State<_SimpleViolinChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveViolin ||
        widget.onViolinTap != null;

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
                painter: _SimpleViolinPainter(
                  data: widget.data,
                  stats: widget.stats,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  palette: widget.palette,
                  violinColor: widget.violinColor,
                  outlineColor: widget.outlineColor,
                  boxColor: widget.boxColor,
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
                  showBoxPlot: widget.showBoxPlot,
                  showMean: widget.showMean,
                  showOutliers: widget.showOutliers,
                  showActiveViolin: widget.showActiveViolin,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  densitySteps: widget.densitySteps,
                  widthFactor: widget.widthFactor,
                  strokeWidth: widget.strokeWidth,
                  outlierRadius: widget.outlierRadius,
                  valueFormatter: widget.valueFormatter,
                  activeIndex: widget.showActiveViolin ? _activeIndex : null,
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
                        widget.onViolinTap?.call(widget.data[index], index);
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
    final geometry = _ViolinGeometry.resolve(
      size: size,
      data: widget.data,
      stats: widget.stats,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      widthFactor: widget.widthFactor,
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
    final stats = widget.stats[index];
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
            stats,
            widget.valueFormatter,
          ) ??
          _DefaultViolinTooltip(
            color: _violinColor(widget.data[index], index),
            title: widget.data[index].label,
            stats: stats,
            valueFormatter: widget.valueFormatter,
            showMean: widget.showMean,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final geometry = _ViolinGeometry.resolve(
      size: size,
      data: widget.data,
      stats: widget.stats,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      widthFactor: widget.widthFactor,
      showOutliers: widget.showOutliers,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
    final layout = geometry.layouts.firstWhere(
      (item) => item.index == index,
      orElse: () => geometry.layouts.first,
    );
    return Offset(layout.centerX, geometry.yForValue(widget.stats[index].q3));
  }

  Color _violinColor(SimpleViolinChartData item, int index) {
    if (item.color != null) return item.color!;
    if (widget.palette.isEmpty) return widget.violinColor;
    return widget.palette[index % widget.palette.length];
  }
}

class _SimpleViolinPainter extends CustomPainter {
  final List<SimpleViolinChartData> data;
  final List<SimpleViolinStats> stats;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color violinColor;
  final Color outlineColor;
  final Color boxColor;
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
  final bool showBoxPlot;
  final bool showMean;
  final bool showOutliers;
  final bool showActiveViolin;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int densitySteps;
  final double widthFactor;
  final double strokeWidth;
  final double outlierRadius;
  final SimpleViolinValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleViolinPainter({
    required this.data,
    required this.stats,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.violinColor,
    required this.outlineColor,
    required this.boxColor,
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
    required this.showBoxPlot,
    required this.showMean,
    required this.showOutliers,
    required this.showActiveViolin,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.densitySteps,
    required this.widthFactor,
    required this.strokeWidth,
    required this.outlierRadius,
    required this.valueFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _ViolinGeometry.resolve(
      size: size,
      data: data,
      stats: stats,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      widthFactor: widthFactor,
      showOutliers: showOutliers,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    if (geometry.plot.isEmpty || geometry.layouts.isEmpty) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    _drawViolins(canvas, geometry);
    _drawLabels(canvas, geometry);
  }

  void _drawGrid(Canvas canvas, _ViolinGeometry geometry) {
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

  void _drawAxis(Canvas canvas, _ViolinGeometry geometry) {
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

  void _drawReferenceBands(Canvas canvas, _ViolinGeometry geometry) {
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
      final color = band.color ?? violinColor;
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

  void _drawReferenceLines(Canvas canvas, _ViolinGeometry geometry) {
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

  void _drawViolins(Canvas canvas, _ViolinGeometry geometry) {
    for (final layout in geometry.layouts) {
      final item = data[layout.index];
      final itemStats = stats[layout.index];
      final color = _violinColor(item, layout.index);
      final selected = activeIndex == layout.index;
      final activeExists = activeIndex != null;
      final opacity = activeExists && !selected ? 0.36 : 1.0;
      final densities = _kde(
        item.values.where((value) => value.isFinite).toList(),
        geometry.min,
        geometry.max,
        densitySteps,
      );
      if (densities.isEmpty) continue;
      final maxDensity = densities
          .map((entry) => entry.density)
          .fold<double>(0, math.max);
      if (maxDensity <= 0) continue;
      final path = Path();
      final rightPoints = <Offset>[];
      final leftPoints = <Offset>[];
      for (final entry in densities) {
        final y = geometry.yForValue(entry.value);
        final halfWidth =
            layout.maxHalfWidth * (entry.density / maxDensity) * progress;
        rightPoints.add(Offset(layout.centerX + halfWidth, y));
        leftPoints.add(Offset(layout.centerX - halfWidth, y));
      }
      path.moveTo(rightPoints.first.dx, rightPoints.first.dy);
      for (final point in rightPoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      for (final point in leftPoints.reversed) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.24 * opacity)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.92 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      if (showActiveViolin && selected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = (activeColor ?? color).withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 5,
        );
      }
      if (showBoxPlot) {
        _drawBoxOverlay(canvas, itemStats, layout, geometry, opacity, color);
      }
      if (showValues && progress > 0.7) {
        _paintText(
          canvas,
          valueFormatter(itemStats.median),
          valueStyle,
          Offset(layout.centerX, geometry.yForValue(itemStats.q3) - 18),
          TextAlign.center,
          math.max(36.0, layout.maxHalfWidth * 2),
        );
      }
    }
  }

  void _drawBoxOverlay(
    Canvas canvas,
    SimpleViolinStats stats,
    _ViolinLayout layout,
    _ViolinGeometry geometry,
    double opacity,
    Color color,
  ) {
    final centerX = layout.centerX;
    final boxHalfWidth = math.max(4.0, layout.maxHalfWidth * 0.24);
    final minY = _animatedY(geometry.yForValue(stats.min), geometry);
    final maxY = _animatedY(geometry.yForValue(stats.max), geometry);
    final q1Y = _animatedY(geometry.yForValue(stats.q1), geometry);
    final q3Y = _animatedY(geometry.yForValue(stats.q3), geometry);
    final medianY = _animatedY(geometry.yForValue(stats.median), geometry);
    final linePaint = Paint()
      ..color = outlineColor.withValues(alpha: opacity)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(centerX, minY), Offset(centerX, maxY), linePaint);
    canvas.drawLine(
      Offset(centerX - boxHalfWidth, minY),
      Offset(centerX + boxHalfWidth, minY),
      linePaint,
    );
    canvas.drawLine(
      Offset(centerX - boxHalfWidth, maxY),
      Offset(centerX + boxHalfWidth, maxY),
      linePaint,
    );
    final rect = Rect.fromLTRB(
      centerX - boxHalfWidth,
      q3Y,
      centerX + boxHalfWidth,
      q1Y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(
      rrect,
      Paint()..color = boxColor.withValues(alpha: 0.62 * opacity),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    canvas.drawLine(
      Offset(rect.left, medianY),
      Offset(rect.right, medianY),
      Paint()
        ..color = medianColor.withValues(alpha: opacity)
        ..strokeWidth = strokeWidth + 0.8
        ..strokeCap = StrokeCap.round,
    );
    if (showMean) {
      _drawMean(
        canvas,
        centerX,
        _animatedY(geometry.yForValue(stats.mean), geometry),
        opacity,
      );
    }
    if (showOutliers) {
      _drawOutliers(canvas, stats, layout, geometry, opacity);
    }
  }

  double _animatedY(double y, _ViolinGeometry geometry) {
    return geometry.plot.bottom - (geometry.plot.bottom - y) * progress;
  }

  void _drawMean(Canvas canvas, double x, double y, double opacity) {
    const radius = 4.8;
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
    SimpleViolinStats stats,
    _ViolinLayout layout,
    _ViolinGeometry geometry,
    double opacity,
  ) {
    for (var index = 0; index < stats.outliers.length; index++) {
      final value = stats.outliers[index];
      final y = _animatedY(geometry.yForValue(value), geometry);
      final jitter =
          ((index % 5) - 2) * math.min(3.0, layout.maxHalfWidth / 14);
      canvas.drawCircle(
        Offset(layout.centerX + jitter, y),
        outlierRadius + 1,
        Paint()..color = Colors.white.withValues(alpha: 0.86 * opacity),
      );
      canvas.drawCircle(
        Offset(layout.centerX + jitter, y),
        outlierRadius,
        Paint()..color = outlierColor.withValues(alpha: 0.92 * opacity),
      );
    }
  }

  void _drawLabels(Canvas canvas, _ViolinGeometry geometry) {
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
    const gap = 5.0;
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

  Color _violinColor(SimpleViolinChartData item, int index) {
    if (item.color != null) return item.color!;
    if (palette.isEmpty) return violinColor;
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
  bool shouldRepaint(covariant _SimpleViolinPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.stats != stats ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.violinColor != violinColor ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.boxColor != boxColor ||
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
        oldDelegate.showBoxPlot != showBoxPlot ||
        oldDelegate.showMean != showMean ||
        oldDelegate.showOutliers != showOutliers ||
        oldDelegate.showActiveViolin != showActiveViolin ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.densitySteps != densitySteps ||
        oldDelegate.widthFactor != widthFactor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.outlierRadius != outlierRadius ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _ResolvedViolinData {
  final SimpleViolinChartData data;
  final SimpleViolinStats stats;

  const _ResolvedViolinData({required this.data, required this.stats});
}

class _DensityPoint {
  final double value;
  final double density;

  const _DensityPoint({required this.value, required this.density});
}

List<_DensityPoint> _kde(
  List<double> values,
  double min,
  double max,
  int steps,
) {
  if (values.isEmpty) return const [];
  final sorted = values.where((value) => value.isFinite).toList();
  if (sorted.isEmpty) return const [];
  final n = sorted.length;
  final mean = sorted.fold(0.0, (sum, value) => sum + value) / n;
  final variance =
      sorted.fold(
        0.0,
        (sum, value) => sum + math.pow(value - mean, 2).toDouble(),
      ) /
      n;
  final std = math.sqrt(variance);
  final span = math.max(1e-9, max - min);
  final bandwidth = math.max(
    span * 0.035,
    1.06 * std * math.pow(n, -0.2).toDouble(),
  );
  final safeBandwidth = bandwidth <= 0 ? span * 0.08 : bandwidth;
  final result = <_DensityPoint>[];
  for (var index = 0; index <= steps; index++) {
    final value = min + span * (index / steps);
    var density = 0.0;
    for (final sample in sorted) {
      final z = (value - sample) / safeBandwidth;
      density += math.exp(-0.5 * z * z);
    }
    result.add(
      _DensityPoint(
        value: value,
        density: density / (n * safeBandwidth * math.sqrt(2 * math.pi)),
      ),
    );
  }
  return result;
}

class _ViolinGeometry {
  final Rect plot;
  final List<_ViolinLayout> layouts;
  final double min;
  final double max;
  final double span;
  final double slotWidth;

  const _ViolinGeometry({
    required this.plot,
    required this.layouts,
    required this.min,
    required this.max,
    required this.span,
    required this.slotWidth,
  });

  factory _ViolinGeometry.resolve({
    required Size size,
    required List<SimpleViolinChartData> data,
    required List<SimpleViolinStats> stats,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required double widthFactor,
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
    for (var index = 0; index < data.length; index++) {
      final stat = stats[index];
      lower = math.min(lower, stat.min);
      upper = math.max(upper, stat.max);
      lower = math.min(lower, stat.mean);
      upper = math.max(upper, stat.mean);
      if (showOutliers) {
        for (final value in stat.outliers) {
          lower = math.min(lower, value);
          upper = math.max(upper, value);
        }
      }
      for (final value in data[index].values) {
        if (!value.isFinite) continue;
        lower = math.min(lower, value);
        upper = math.max(upper, value);
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
    final slotWidth = data.isEmpty ? 0.0 : plot.width / data.length;
    final layouts = <_ViolinLayout>[];
    for (var index = 0; index < data.length; index++) {
      final centerX = plot.left + slotWidth * index + slotWidth / 2;
      layouts.add(
        _ViolinLayout(
          index: index,
          centerX: centerX,
          slot: Rect.fromLTWH(
            plot.left + slotWidth * index,
            plot.top,
            slotWidth,
            plot.height,
          ),
          maxHalfWidth: math.max(4.0, slotWidth * widthFactor / 2),
        ),
      );
    }
    return _ViolinGeometry(
      plot: plot,
      layouts: layouts,
      min: lower,
      max: upper,
      span: span,
      slotWidth: slotWidth,
    );
  }

  double yForValue(double value) {
    final normalized = ((value - min) / span).clamp(0.0, 1.0).toDouble();
    return plot.bottom - normalized * plot.height;
  }
}

class _ViolinLayout {
  final int index;
  final double centerX;
  final Rect slot;
  final double maxHalfWidth;

  const _ViolinLayout({
    required this.index,
    required this.centerX,
    required this.slot,
    required this.maxHalfWidth,
  });
}

class _SimpleViolinVisuals {
  final Color violinColor;
  final Color outlineColor;
  final Color boxColor;
  final Color medianColor;
  final Color meanColor;
  final Color outlierColor;
  final Color gridColor;
  final Color axisColor;
  final double widthFactor;
  final double strokeWidth;
  final double outlierRadius;

  const _SimpleViolinVisuals({
    required this.violinColor,
    required this.outlineColor,
    required this.boxColor,
    required this.medianColor,
    required this.meanColor,
    required this.outlierColor,
    required this.gridColor,
    required this.axisColor,
    required this.widthFactor,
    required this.strokeWidth,
    required this.outlierRadius,
  });

  factory _SimpleViolinVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleViolinVisuals(
          violinColor: colorScheme.primary,
          outlineColor: colorScheme.primary,
          boxColor: colorScheme.surface,
          medianColor: colorScheme.onSurface,
          meanColor: colorScheme.tertiary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          widthFactor: 0.72,
          strokeWidth: 2,
          outlierRadius: 3.2,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleViolinVisuals(
          violinColor: colorScheme.primary,
          outlineColor: colorScheme.primary,
          boxColor: colorScheme.surface,
          medianColor: colorScheme.onSurface,
          meanColor: colorScheme.secondary,
          outlierColor: colorScheme.error.withValues(alpha: 0.88),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          widthFactor: 0.64,
          strokeWidth: 1.7,
          outlierRadius: 2.9,
        );
      case SimpleBarChartStyle.education:
        return _SimpleViolinVisuals(
          violinColor: colorScheme.secondary,
          outlineColor: colorScheme.secondary,
          boxColor: colorScheme.surface,
          medianColor: colorScheme.primary,
          meanColor: colorScheme.tertiary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          widthFactor: 0.72,
          strokeWidth: 2,
          outlierRadius: 3.3,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleViolinVisuals(
          violinColor: colorScheme.tertiary,
          outlineColor: colorScheme.tertiary,
          boxColor: colorScheme.surface,
          medianColor: colorScheme.onSurface,
          meanColor: colorScheme.primary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          widthFactor: 0.78,
          strokeWidth: 2.2,
          outlierRadius: 3.4,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleViolinVisuals(
          violinColor: colorScheme.primary,
          outlineColor: colorScheme.primary,
          boxColor: colorScheme.surface,
          medianColor: colorScheme.onSurface,
          meanColor: colorScheme.tertiary,
          outlierColor: colorScheme.error.withValues(alpha: 0.88),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          widthFactor: 0.7,
          strokeWidth: 1.9,
          outlierRadius: 3.1,
        );
    }
  }
}

class _DefaultViolinTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final SimpleViolinStats stats;
  final SimpleViolinValueFormatter valueFormatter;
  final bool showMean;

  const _DefaultViolinTooltip({
    required this.color,
    required this.title,
    required this.stats,
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
              label: 'Count',
              value: stats.count.toString(),
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: 'Median',
              value: valueFormatter(stats.median),
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: color),
            ),
            _TooltipRow(
              label: 'Q1 - Q3',
              value:
                  '${valueFormatter(stats.q1)} - ${valueFormatter(stats.q3)}',
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: 'Min - Max',
              value:
                  '${valueFormatter(stats.min)} - ${valueFormatter(stats.max)}',
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            if (showMean)
              _TooltipRow(
                label: 'Mean',
                value: valueFormatter(stats.mean),
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
