import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleRaincloudValueFormatter = String Function(double value);
typedef SimpleRaincloudTapCallback =
    void Function(
      SimpleRaincloudChartData data,
      int index,
      SimpleRaincloudStats stats,
    );
typedef SimpleRaincloudTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleRaincloudChartData data,
      int index,
      SimpleRaincloudStats stats,
      SimpleRaincloudValueFormatter valueFormatter,
    );

class SimpleRaincloudChartData {
  final String label;
  final List<double> values;
  final Color? color;

  const SimpleRaincloudChartData({
    required this.label,
    required this.values,
    this.color,
  });
}

class SimpleRaincloudStats {
  final int count;
  final double min;
  final double q1;
  final double median;
  final double q3;
  final double max;
  final double mean;
  final List<double> outliers;

  const SimpleRaincloudStats({
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

/// A compact raincloud chart combining half-density, box summary, and raw
/// observations for rich but readable distribution comparison.
class SimpleRaincloudChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 18, 42);

  final List<SimpleRaincloudChartData> data;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? cloudColor;
  final Color? outlineColor;
  final Color? boxColor;
  final Color? dotColor;
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
  final bool showCloud;
  final bool showBox;
  final bool showDots;
  final bool showMean;
  final bool showOutliers;
  final bool showTooltip;
  final bool showActiveGroup;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int densitySteps;
  final double? cloudWidthFactor;
  final double? dotRadius;
  final double dotOpacity;
  final double jitter;
  final int jitterSeed;
  final SimpleRaincloudValueFormatter? valueFormatter;
  final SimpleRaincloudTapCallback? onGroupTap;
  final SimpleRaincloudTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleRaincloudChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 280,
    this.padding = _defaultPadding,
    this.palette,
    this.cloudColor,
    this.outlineColor,
    this.boxColor,
    this.dotColor,
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
    this.showCloud = true,
    this.showBox = true,
    this.showDots = true,
    this.showMean = true,
    this.showOutliers = true,
    this.showTooltip = true,
    this.showActiveGroup = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.densitySteps = 36,
    this.cloudWidthFactor,
    this.dotRadius,
    this.dotOpacity = 0.72,
    this.jitter = 0.44,
    this.jitterSeed = 31,
    this.valueFormatter,
    this.onGroupTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(densitySteps >= 8),
       assert(
         cloudWidthFactor == null ||
             (cloudWidthFactor > 0 && cloudWidthFactor <= 1),
       ),
       assert(dotRadius == null || dotRadius >= 0),
       assert(dotOpacity >= 0 && dotOpacity <= 1),
       assert(jitter >= 0 && jitter <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleRaincloudVisuals.resolve(style, colorScheme);
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
            emptySemanticLabel: 'Raincloud chart, no data.',
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

        final chartData = resolvedData.map((item) => item.data).toList();
        final chartStats = resolvedData.map((item) => item.stats).toList();

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            chartData,
            chartStats,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleRaincloudChartView(
            width: width,
            height: chartHeight,
            data: chartData,
            stats: chartStats,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals),
            cloudColor: cloudColor ?? visuals.cloudColor,
            outlineColor: outlineColor ?? visuals.outlineColor,
            boxColor: boxColor ?? visuals.boxColor,
            dotColor: dotColor ?? visuals.dotColor,
            medianColor: medianColor ?? visuals.medianColor,
            meanColor: meanColor ?? visuals.meanColor,
            outlierColor: outlierColor ?? visuals.outlierColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showCloud: showCloud,
            showBox: showBox,
            showDots: showDots,
            showMean: showMean,
            showOutliers: showOutliers,
            showTooltip: showTooltip,
            showActiveGroup: showActiveGroup,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            densitySteps: densitySteps,
            cloudWidthFactor: cloudWidthFactor ?? visuals.cloudWidthFactor,
            dotRadius: dotRadius ?? visuals.dotRadius,
            dotOpacity: dotOpacity,
            jitter: jitter,
            jitterSeed: jitterSeed,
            valueFormatter: formatter,
            onGroupTap: onGroupTap,
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
    _SimpleRaincloudVisuals visuals,
  ) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return [
      cloudColor ?? visuals.cloudColor,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
  }

  List<_ResolvedRaincloudData> _resolveData(
    List<SimpleRaincloudChartData> source,
  ) {
    final resolved = <_ResolvedRaincloudData>[];
    for (final item in source) {
      final values = item.values.where((value) => value.isFinite).toList();
      if (item.label.trim().isEmpty || values.isEmpty) continue;
      final cleaned = SimpleRaincloudChartData(
        label: item.label,
        values: values,
        color: item.color,
      );
      resolved.add(
        _ResolvedRaincloudData(data: cleaned, stats: _statsFor(values)),
      );
    }
    return resolved;
  }

  String _defaultSemanticLabel(
    List<SimpleRaincloudChartData> data,
    List<SimpleRaincloudStats> stats,
    SimpleRaincloudValueFormatter formatter,
  ) {
    final limit = math.min(data.length, 4);
    final summaries = <String>[];
    for (var index = 0; index < limit; index++) {
      final item = data[index];
      final summary = stats[index];
      summaries.add(
        '${item.label} count ${summary.count}, median '
        '${formatter(summary.median)}, range ${formatter(summary.min)} to '
        '${formatter(summary.max)}',
      );
    }
    final suffix = data.length > limit
        ? '; and ${data.length - limit} more groups'
        : '';
    final groupLabel = data.length == 1 ? 'group' : 'groups';
    return 'Raincloud chart, ${data.length} $groupLabel. '
        '${summaries.join('; ')}$suffix.';
  }

  static SimpleRaincloudStats _statsFor(List<double> values) {
    final sorted = [...values]..sort();
    final q1 = _quantile(sorted, 0.25);
    final median = _quantile(sorted, 0.5);
    final q3 = _quantile(sorted, 0.75);
    final iqr = q3 - q1;
    final lowerFence = q1 - iqr * 1.5;
    final upperFence = q3 + iqr * 1.5;
    final outliers = sorted
        .where((value) => value < lowerFence || value > upperFence)
        .toList();
    final inliers = sorted
        .where((value) => value >= lowerFence && value <= upperFence)
        .toList();
    final sum = sorted.fold<double>(0, (total, value) => total + value);
    return SimpleRaincloudStats(
      count: sorted.length,
      min: inliers.isEmpty ? sorted.first : inliers.first,
      q1: q1,
      median: median,
      q3: q3,
      max: inliers.isEmpty ? sorted.last : inliers.last,
      mean: sum / sorted.length,
      outliers: outliers,
    );
  }

  static double _quantile(List<double> sorted, double percentile) {
    if (sorted.length == 1) return sorted.first;
    final position = (sorted.length - 1) * percentile;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower];
    final weight = position - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _ResolvedRaincloudData {
  final SimpleRaincloudChartData data;
  final SimpleRaincloudStats stats;

  const _ResolvedRaincloudData({required this.data, required this.stats});
}

class _SimpleRaincloudChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleRaincloudChartData> data;
  final List<SimpleRaincloudStats> stats;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color cloudColor;
  final Color outlineColor;
  final Color boxColor;
  final Color dotColor;
  final Color medianColor;
  final Color meanColor;
  final Color outlierColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showCloud;
  final bool showBox;
  final bool showDots;
  final bool showMean;
  final bool showOutliers;
  final bool showTooltip;
  final bool showActiveGroup;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int densitySteps;
  final double cloudWidthFactor;
  final double dotRadius;
  final double dotOpacity;
  final double jitter;
  final int jitterSeed;
  final SimpleRaincloudValueFormatter valueFormatter;
  final SimpleRaincloudTapCallback? onGroupTap;
  final SimpleRaincloudTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleRaincloudChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.stats,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.cloudColor,
    required this.outlineColor,
    required this.boxColor,
    required this.dotColor,
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
    required this.showCloud,
    required this.showBox,
    required this.showDots,
    required this.showMean,
    required this.showOutliers,
    required this.showTooltip,
    required this.showActiveGroup,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.densitySteps,
    required this.cloudWidthFactor,
    required this.dotRadius,
    required this.dotOpacity,
    required this.jitter,
    required this.jitterSeed,
    required this.valueFormatter,
    required this.onGroupTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleRaincloudChartView> createState() =>
      _SimpleRaincloudChartViewState();
}

class _SimpleRaincloudChartViewState extends State<_SimpleRaincloudChartView> {
  _RaincloudSelection? _active;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveGroup ||
        widget.onGroupTap != null;

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
                painter: _SimpleRaincloudPainter(
                  data: widget.data,
                  stats: widget.stats,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  palette: widget.palette,
                  cloudColor: widget.cloudColor,
                  outlineColor: widget.outlineColor,
                  boxColor: widget.boxColor,
                  dotColor: widget.dotColor,
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
                  showCloud: widget.showCloud,
                  showBox: widget.showBox,
                  showDots: widget.showDots,
                  showMean: widget.showMean,
                  showOutliers: widget.showOutliers,
                  showActiveGroup: widget.showActiveGroup,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  densitySteps: widget.densitySteps,
                  cloudWidthFactor: widget.cloudWidthFactor,
                  dotRadius: widget.dotRadius,
                  dotOpacity: widget.dotOpacity,
                  jitter: widget.jitter,
                  jitterSeed: widget.jitterSeed,
                  activeSelection: _active,
                  valueFormatter: widget.valueFormatter,
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
                      final selection = _hitTest(details.localPosition, size);
                      _setActive(selection);
                      if (selection == null) return;
                      widget.onGroupTap?.call(
                        widget.data[selection.index],
                        selection.index,
                        widget.stats[selection.index],
                      );
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _active != null)
                _buildTooltip(context, size, _active!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_RaincloudSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _RaincloudSelection? _hitTest(Offset position, Size size) {
    final geometry = _RaincloudGeometry.resolve(
      size: size,
      data: widget.data,
      stats: widget.stats,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
      densitySteps: widget.densitySteps,
      cloudWidthFactor: widget.cloudWidthFactor,
      jitter: widget.jitter,
      jitterSeed: widget.jitterSeed,
    );
    for (final layout in geometry.layouts) {
      if (layout.hitRect.inflate(6).contains(position)) {
        return _RaincloudSelection(layout.index, layout.hitRect.center);
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _RaincloudSelection selection,
  ) {
    final item = widget.data[selection.index];
    final stats = widget.stats[selection.index];
    const tooltipWidth = 192.0;
    const tooltipHeight = 96.0;
    final left = (selection.position.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (selection.position.dy - tooltipHeight - 8)
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
            selection.index,
            stats,
            widget.valueFormatter,
          ) ??
          _DefaultRaincloudTooltip(
            color: _itemColor(item, selection.index),
            title: item.label,
            count: stats.count,
            median: widget.valueFormatter(stats.median),
            mean: widget.valueFormatter(stats.mean),
            range:
                '${widget.valueFormatter(stats.min)} - ${widget.valueFormatter(stats.max)}',
          ),
    );
  }

  Color _itemColor(SimpleRaincloudChartData item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleRaincloudPainter extends CustomPainter {
  final List<SimpleRaincloudChartData> data;
  final List<SimpleRaincloudStats> stats;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color cloudColor;
  final Color outlineColor;
  final Color boxColor;
  final Color dotColor;
  final Color medianColor;
  final Color meanColor;
  final Color outlierColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showCloud;
  final bool showBox;
  final bool showDots;
  final bool showMean;
  final bool showOutliers;
  final bool showActiveGroup;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int densitySteps;
  final double cloudWidthFactor;
  final double dotRadius;
  final double dotOpacity;
  final double jitter;
  final int jitterSeed;
  final _RaincloudSelection? activeSelection;
  final SimpleRaincloudValueFormatter valueFormatter;
  final double progress;

  const _SimpleRaincloudPainter({
    required this.data,
    required this.stats,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.cloudColor,
    required this.outlineColor,
    required this.boxColor,
    required this.dotColor,
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
    required this.showCloud,
    required this.showBox,
    required this.showDots,
    required this.showMean,
    required this.showOutliers,
    required this.showActiveGroup,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.densitySteps,
    required this.cloudWidthFactor,
    required this.dotRadius,
    required this.dotOpacity,
    required this.jitter,
    required this.jitterSeed,
    required this.activeSelection,
    required this.valueFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _RaincloudGeometry.resolve(
      size: size,
      data: data,
      stats: stats,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
      densitySteps: densitySteps,
      cloudWidthFactor: cloudWidthFactor,
      jitter: jitter,
      jitterSeed: jitterSeed,
    );
    if (geometry.plot.isEmpty || geometry.layouts.isEmpty) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    for (final layout in geometry.layouts) {
      _drawGroup(canvas, geometry, layout);
    }
    _drawLabels(canvas, geometry);
  }

  void _drawReferenceBands(Canvas canvas, _RaincloudGeometry geometry) {
    final paint = Paint();
    for (final band in referenceBands) {
      final start = geometry.yForValue(band.from);
      final end = geometry.yForValue(band.to);
      paint.color = (band.color ?? palette.first).withValues(
        alpha: band.opacity,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          geometry.plot.left,
          math.min(start, end),
          geometry.plot.right,
          math.max(start, end),
        ),
        paint,
      );
    }
  }

  void _drawGrid(Canvas canvas, _RaincloudGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          geometry.range.min + geometry.range.span * (index / gridLineCount);
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
        math.max(0.0, padding.left - 12),
        centeredY: true,
      );
    }
  }

  void _drawAxis(Canvas canvas, _RaincloudGeometry geometry) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
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

  void _drawReferenceLines(Canvas canvas, _RaincloudGeometry geometry) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final y = geometry.yForValue(line.value);
      final paint = Paint()
        ..color = line.color ?? axisColor
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke;
      _drawStyledLine(
        canvas,
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
        line.lineStyle,
      );
    }
  }

  void _drawGroup(
    Canvas canvas,
    _RaincloudGeometry geometry,
    _RaincloudLayout layout,
  ) {
    final item = data[layout.index];
    final summary = stats[layout.index];
    final color = _itemColor(item, layout.index);
    final selected = activeSelection?.index == layout.index;

    if (showActiveGroup && selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          layout.hitRect.inflate(2),
          const Radius.circular(8),
        ),
        Paint()..color = activeColor.withValues(alpha: 0.08),
      );
    }

    if (showCloud) {
      _drawCloud(canvas, layout, color, selected);
    }
    if (showBox) {
      _drawBox(canvas, geometry, layout, summary, selected);
    }
    if (showDots) {
      _drawDots(canvas, layout, item, summary);
    }
  }

  void _drawCloud(
    Canvas canvas,
    _RaincloudLayout layout,
    Color color,
    bool selected,
  ) {
    if (layout.density.isEmpty || layout.maxDensity <= 0) return;
    final path = Path();
    final outline = Path();
    for (var index = 0; index < layout.density.length; index++) {
      final point = layout.density[index];
      final width =
          (point.density / layout.maxDensity) * layout.maxCloudWidth * progress;
      final y = layout.yForValue(point.value);
      final boundary = Offset(layout.cloudAxisX - width, y);
      if (index == 0) {
        path
          ..moveTo(layout.cloudAxisX, y)
          ..lineTo(boundary.dx, boundary.dy);
        outline.moveTo(boundary.dx, boundary.dy);
      } else {
        final previous = layout.density[index - 1];
        final previousWidth =
            (previous.density / layout.maxDensity) *
            layout.maxCloudWidth *
            progress;
        final previousBoundary = Offset(
          layout.cloudAxisX - previousWidth,
          layout.yForValue(previous.value),
        );
        final midY = (previousBoundary.dy + boundary.dy) / 2;
        path.cubicTo(
          previousBoundary.dx,
          midY,
          boundary.dx,
          midY,
          boundary.dx,
          boundary.dy,
        );
        outline.cubicTo(
          previousBoundary.dx,
          midY,
          boundary.dx,
          midY,
          boundary.dx,
          boundary.dy,
        );
      }
    }
    path
      ..lineTo(layout.cloudAxisX, layout.yForValue(layout.density.last.value))
      ..lineTo(layout.cloudAxisX, layout.yForValue(layout.density.first.value))
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: selected ? 0.34 : 0.24)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      outline,
      Paint()
        ..color = outlineColor.withValues(alpha: selected ? 0.9 : 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.1 : 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawBox(
    Canvas canvas,
    _RaincloudGeometry geometry,
    _RaincloudLayout layout,
    SimpleRaincloudStats summary,
    bool selected,
  ) {
    final q1 = geometry.yForValue(summary.q1);
    final q3 = geometry.yForValue(summary.q3);
    final median = geometry.yForValue(summary.median);
    final low = geometry.yForValue(summary.min);
    final high = geometry.yForValue(summary.max);
    final boxWidth = math.max(10.0, layout.groupWidth * 0.16);
    final rect = Rect.fromLTRB(
      layout.boxX - boxWidth / 2,
      math.min(q1, q3),
      layout.boxX + boxWidth / 2,
      math.max(q1, q3),
    );
    final stroke = Paint()
      ..color = boxColor.withValues(alpha: selected ? 0.95 : 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 2.1 : 1.6;
    final fill = Paint()
      ..color = boxColor.withValues(alpha: selected ? 0.18 : 0.11)
      ..style = PaintingStyle.fill;
    final capWidth = boxWidth * 0.62;

    canvas.drawLine(
      Offset(layout.boxX, high),
      Offset(layout.boxX, low),
      stroke,
    );
    canvas.drawLine(
      Offset(layout.boxX - capWidth / 2, high),
      Offset(layout.boxX + capWidth / 2, high),
      stroke,
    );
    canvas.drawLine(
      Offset(layout.boxX - capWidth / 2, low),
      Offset(layout.boxX + capWidth / 2, low),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      stroke,
    );
    canvas.drawLine(
      Offset(rect.left, median),
      Offset(rect.right, median),
      Paint()
        ..color = medianColor
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    if (showMean) {
      _drawDiamond(
        canvas,
        Offset(layout.boxX, geometry.yForValue(summary.mean)),
        4.2,
        Paint()..color = meanColor.withValues(alpha: 0.95),
      );
    }
  }

  void _drawDots(
    Canvas canvas,
    _RaincloudLayout layout,
    SimpleRaincloudChartData item,
    SimpleRaincloudStats summary,
  ) {
    final color = item.color ?? dotColor;
    for (final dot in layout.dots) {
      final outlier = summary.outliers.contains(dot.value);
      if (outlier && !showOutliers) continue;
      final center = Offset(
        layout.dotAxisX + dot.offset * progress,
        dot.position.dy,
      );
      final radius = dotRadius * (0.45 + progress * 0.55);
      final paintColor = outlier ? outlierColor : color;
      canvas.drawCircle(
        center,
        radius + 1.1,
        Paint()..color = Colors.white.withValues(alpha: 0.82),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = paintColor.withValues(alpha: dotOpacity),
      );
    }
  }

  void _drawLabels(Canvas canvas, _RaincloudGeometry geometry) {
    for (final layout in geometry.layouts) {
      _paintText(
        canvas,
        data[layout.index].label,
        labelStyle,
        Offset(layout.centerX, geometry.plot.bottom + 18),
        TextAlign.center,
        math.max(32.0, layout.groupWidth - 6),
      );
      if (showValues) {
        _paintText(
          canvas,
          valueFormatter(stats[layout.index].median),
          valueStyle,
          Offset(
            layout.centerX,
            geometry.yForValue(stats[layout.index].median) - 18,
          ),
          TextAlign.center,
          math.max(34.0, layout.groupWidth * 0.52),
        );
      }
    }
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, paint);
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
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    var drawn = 0.0;
    final dash = style == SimpleChartReferenceLineStyle.dotted ? 1.5 : 6.0;
    final gap = style == SimpleChartReferenceLineStyle.dotted ? 5.0 : 4.0;
    while (drawn < total) {
      final segmentStart = start + direction * drawn;
      final segmentEnd = start + direction * math.min(total, drawn + dash);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      drawn += dash + gap;
    }
  }

  Color _itemColor(SimpleRaincloudChartData item, int index) {
    return item.color ?? palette[index % palette.length];
  }

  @override
  bool shouldRepaint(covariant _SimpleRaincloudPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.stats != stats ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.cloudColor != cloudColor ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.boxColor != boxColor ||
        oldDelegate.dotColor != dotColor ||
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
        oldDelegate.showCloud != showCloud ||
        oldDelegate.showBox != showBox ||
        oldDelegate.showDots != showDots ||
        oldDelegate.showMean != showMean ||
        oldDelegate.showOutliers != showOutliers ||
        oldDelegate.showActiveGroup != showActiveGroup ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.densitySteps != densitySteps ||
        oldDelegate.cloudWidthFactor != cloudWidthFactor ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.dotOpacity != dotOpacity ||
        oldDelegate.jitter != jitter ||
        oldDelegate.jitterSeed != jitterSeed ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _RaincloudGeometry {
  final Rect plot;
  final _RaincloudRange range;
  final List<_RaincloudLayout> layouts;

  const _RaincloudGeometry({
    required this.plot,
    required this.range,
    required this.layouts,
  });

  factory _RaincloudGeometry.resolve({
    required Size size,
    required List<SimpleRaincloudChartData> data,
    required List<SimpleRaincloudStats> stats,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
    required int densitySteps,
    required double cloudWidthFactor,
    required double jitter,
    required int jitterSeed,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0 || data.isEmpty) {
      return _RaincloudGeometry(
        plot: plot,
        range: const _RaincloudRange(0, 1),
        layouts: const [],
      );
    }

    final range = _RaincloudRange.resolve(
      data: data,
      minValue: minValue,
      maxValue: maxValue,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    final groupWidth = plot.width / data.length;
    final layouts = <_RaincloudLayout>[];
    for (var index = 0; index < data.length; index++) {
      final centerX = plot.left + groupWidth * index + groupWidth / 2;
      final cloudAxisX = centerX - groupWidth * 0.08;
      final boxX = centerX + groupWidth * 0.1;
      final dotAxisX = centerX + groupWidth * 0.27;
      final maxCloudWidth = groupWidth * 0.28 * cloudWidthFactor;
      final density = _kde(
        data[index].values,
        range.min,
        range.max,
        densitySteps,
      );
      var maxDensity = 0.0;
      for (final point in density) {
        maxDensity = math.max(maxDensity, point.density);
      }
      final dots = <_RaincloudDotLayout>[];
      final jitterSpan = math.min(groupWidth * jitter, groupWidth * 0.22);
      for (
        var valueIndex = 0;
        valueIndex < data[index].values.length;
        valueIndex++
      ) {
        final value = data[index].values[valueIndex];
        final offset = _jitterOffset(index, valueIndex, jitterSpan, jitterSeed);
        dots.add(
          _RaincloudDotLayout(
            value: value,
            offset: offset,
            position: Offset(dotAxisX + offset, _yForValue(value, plot, range)),
          ),
        );
      }
      layouts.add(
        _RaincloudLayout(
          index: index,
          centerX: centerX,
          groupWidth: groupWidth,
          cloudAxisX: cloudAxisX,
          boxX: boxX,
          dotAxisX: dotAxisX,
          maxCloudWidth: maxCloudWidth,
          density: density,
          maxDensity: maxDensity <= 0 ? 1 : maxDensity,
          dots: dots,
          plot: plot,
          range: range,
          hitRect: Rect.fromLTRB(
            centerX - groupWidth / 2,
            plot.top,
            centerX + groupWidth / 2,
            plot.bottom,
          ),
        ),
      );
    }
    return _RaincloudGeometry(plot: plot, range: range, layouts: layouts);
  }

  double yForValue(double value) => _yForValue(value, plot, range);

  static double _yForValue(double value, Rect plot, _RaincloudRange range) {
    final normalized = ((value - range.min) / range.span).clamp(0.0, 1.0);
    return plot.bottom - normalized * plot.height;
  }

  static double _jitterOffset(
    int groupIndex,
    int valueIndex,
    double span,
    int seed,
  ) {
    if (span <= 0) return 0;
    final raw =
        math.sin(
          (groupIndex + 1) * 87.13 +
              (valueIndex + 1) * 47.71 +
              (seed + 1) * 0.31,
        ) *
        43758.5453;
    final fraction = raw - raw.floorToDouble();
    return (fraction - 0.5) * span;
  }
}

class _RaincloudLayout {
  final int index;
  final double centerX;
  final double groupWidth;
  final double cloudAxisX;
  final double boxX;
  final double dotAxisX;
  final double maxCloudWidth;
  final List<_DensityPoint> density;
  final double maxDensity;
  final List<_RaincloudDotLayout> dots;
  final Rect plot;
  final _RaincloudRange range;
  final Rect hitRect;

  const _RaincloudLayout({
    required this.index,
    required this.centerX,
    required this.groupWidth,
    required this.cloudAxisX,
    required this.boxX,
    required this.dotAxisX,
    required this.maxCloudWidth,
    required this.density,
    required this.maxDensity,
    required this.dots,
    required this.plot,
    required this.range,
    required this.hitRect,
  });

  double yForValue(double value) {
    return _RaincloudGeometry._yForValue(value, plot, range);
  }
}

class _RaincloudDotLayout {
  final double value;
  final double offset;
  final Offset position;

  const _RaincloudDotLayout({
    required this.value,
    required this.offset,
    required this.position,
  });
}

class _RaincloudSelection {
  final int index;
  final Offset position;

  const _RaincloudSelection(this.index, this.position);

  @override
  bool operator ==(Object other) {
    return other is _RaincloudSelection && other.index == index;
  }

  @override
  int get hashCode => index.hashCode;
}

class _RaincloudRange {
  final double min;
  final double max;

  const _RaincloudRange(this.min, this.max);

  double get span => max - min;

  factory _RaincloudRange.resolve({
    required List<SimpleRaincloudChartData> data,
    required double? minValue,
    required double? maxValue,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    var lower = double.infinity;
    var upper = double.negativeInfinity;
    for (final item in data) {
      for (final value in item.values) {
        lower = math.min(lower, value);
        upper = math.max(upper, value);
      }
    }
    for (final line in referenceLines) {
      if (line.value.isFinite) {
        lower = math.min(lower, line.value);
        upper = math.max(upper, line.value);
      }
    }
    for (final band in referenceBands) {
      if (band.from.isFinite) lower = math.min(lower, band.from);
      if (band.to.isFinite) upper = math.max(upper, band.to);
    }
    lower = minValue ?? lower;
    upper = maxValue ?? upper;
    if (lower > upper) {
      final previousLower = lower;
      lower = upper;
      upper = previousLower;
    }
    if (lower == upper) {
      final pad = lower == 0 ? 1.0 : lower.abs() * 0.2;
      lower -= pad;
      upper += pad;
    } else if (minValue == null || maxValue == null) {
      final pad = (upper - lower) * 0.08;
      if (minValue == null) lower -= pad;
      if (maxValue == null) upper += pad;
    }
    return _RaincloudRange(lower, upper);
  }
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

class _SimpleRaincloudVisuals {
  final Color cloudColor;
  final Color outlineColor;
  final Color boxColor;
  final Color dotColor;
  final Color medianColor;
  final Color meanColor;
  final Color outlierColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double cloudWidthFactor;
  final double dotRadius;

  const _SimpleRaincloudVisuals({
    required this.cloudColor,
    required this.outlineColor,
    required this.boxColor,
    required this.dotColor,
    required this.medianColor,
    required this.meanColor,
    required this.outlierColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.cloudWidthFactor,
    required this.dotRadius,
  });

  factory _SimpleRaincloudVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleRaincloudVisuals(
          cloudColor: colorScheme.primary,
          outlineColor: colorScheme.primary,
          boxColor: colorScheme.onSurface,
          dotColor: colorScheme.primary,
          medianColor: colorScheme.primary,
          meanColor: colorScheme.tertiary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.52),
          activeColor: colorScheme.primary,
          cloudWidthFactor: 1,
          dotRadius: 3.8,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleRaincloudVisuals(
          cloudColor: colorScheme.primary,
          outlineColor: colorScheme.primary,
          boxColor: colorScheme.onSurface,
          dotColor: colorScheme.primary,
          medianColor: colorScheme.onSurface,
          meanColor: colorScheme.secondary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          activeColor: colorScheme.primary,
          cloudWidthFactor: 0.92,
          dotRadius: 3.2,
        );
      case SimpleBarChartStyle.education:
        return _SimpleRaincloudVisuals(
          cloudColor: colorScheme.secondary,
          outlineColor: colorScheme.secondary,
          boxColor: colorScheme.secondary,
          dotColor: colorScheme.secondary,
          medianColor: colorScheme.secondary,
          meanColor: colorScheme.tertiary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          activeColor: colorScheme.secondary,
          cloudWidthFactor: 1,
          dotRadius: 3.8,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleRaincloudVisuals(
          cloudColor: colorScheme.tertiary,
          outlineColor: colorScheme.tertiary,
          boxColor: colorScheme.tertiary,
          dotColor: colorScheme.tertiary,
          medianColor: colorScheme.tertiary,
          meanColor: colorScheme.primary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          activeColor: colorScheme.tertiary,
          cloudWidthFactor: 1.04,
          dotRadius: 4,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleRaincloudVisuals(
          cloudColor: colorScheme.primary,
          outlineColor: colorScheme.primary,
          boxColor: colorScheme.primary,
          dotColor: colorScheme.primary,
          medianColor: colorScheme.primary,
          meanColor: colorScheme.tertiary,
          outlierColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: colorScheme.primary,
          cloudWidthFactor: 0.98,
          dotRadius: 3.6,
        );
    }
  }
}

class _DefaultRaincloudTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final int count;
  final String median;
  final String mean;
  final String range;

  const _DefaultRaincloudTooltip({
    required this.color,
    required this.title,
    required this.count,
    required this.median,
    required this.mean,
    required this.range,
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
                  width: 10,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
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
            const SizedBox(height: 7),
            _TooltipMetric(label: 'Median', value: median),
            const SizedBox(height: 4),
            _TooltipMetric(label: 'Mean', value: mean),
            const SizedBox(height: 4),
            _TooltipMetric(label: 'Range', value: range),
            const SizedBox(height: 4),
            _TooltipMetric(label: 'Count', value: count.toString()),
          ],
        ),
      ),
    );
  }
}

class _TooltipMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TooltipMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.onInverseSurface.withValues(alpha: 0.74),
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: colorScheme.onInverseSurface,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
