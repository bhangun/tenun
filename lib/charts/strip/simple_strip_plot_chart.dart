import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleStripPlotValueFormatter = String Function(double value);
typedef SimpleStripPlotTapCallback =
    void Function(
      SimpleStripPlotData data,
      int groupIndex,
      int valueIndex,
      double value,
    );
typedef SimpleStripPlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleStripPlotData data,
      int groupIndex,
      int valueIndex,
      double value,
      SimpleStripPlotStats stats,
      String formattedValue,
    );

class SimpleStripPlotData {
  final String label;
  final List<double> values;
  final Color? color;

  const SimpleStripPlotData({
    required this.label,
    required this.values,
    this.color,
  });
}

class SimpleStripPlotStats {
  final int count;
  final double min;
  final double q1;
  final double median;
  final double mean;
  final double q3;
  final double max;

  const SimpleStripPlotStats({
    required this.count,
    required this.min,
    required this.q1,
    required this.median,
    required this.mean,
    required this.q3,
    required this.max,
  });
}

/// A simple strip plot for showing every observation in a group while keeping
/// mean, median, references, and dense categorical comparison readable.
class SimpleStripPlotChart extends StatelessWidget {
  static const EdgeInsets _verticalPadding = EdgeInsets.fromLTRB(
    48,
    18,
    18,
    42,
  );
  static const EdgeInsets _horizontalPadding = EdgeInsets.fromLTRB(
    92,
    18,
    44,
    34,
  );

  final List<SimpleStripPlotData> data;
  final SimpleBarChartOrientation orientation;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets? padding;
  final List<Color>? palette;
  final Color? dotColor;
  final Color? meanColor;
  final Color? medianColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showMean;
  final bool showMedian;
  final bool showTooltip;
  final bool showActiveDot;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? dotRadius;
  final double dotOpacity;
  final double jitter;
  final int jitterSeed;
  final SimpleStripPlotValueFormatter? valueFormatter;
  final SimpleStripPlotTapCallback? onPointTap;
  final SimpleStripPlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleStripPlotChart({
    super.key,
    required this.data,
    this.orientation = SimpleBarChartOrientation.vertical,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding,
    this.palette,
    this.dotColor,
    this.meanColor,
    this.medianColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = false,
    this.showMean = true,
    this.showMedian = true,
    this.showTooltip = true,
    this.showActiveDot = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.dotRadius,
    this.dotOpacity = 0.78,
    this.jitter = 0.42,
    this.jitterSeed = 17,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(dotRadius == null || dotRadius >= 0),
       assert(dotOpacity >= 0 && dotOpacity <= 1),
       assert(jitter >= 0 && jitter <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleStripPlotVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where(
          (item) =>
              item.label.trim().isNotEmpty &&
              item.values.any((value) => value.isFinite),
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedPadding =
        padding ??
        (orientation == SimpleBarChartOrientation.vertical
            ? _verticalPadding
            : _horizontalPadding);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Strip plot chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final stats = visibleData.map(_statsFor).toList();
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
        final resolvedPalette = _resolvePalette(colorScheme, visuals.dotColor);

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(visibleData, stats, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleStripPlotChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            stats: stats,
            orientation: orientation,
            minValue: minValue,
            maxValue: maxValue,
            padding: resolvedPadding,
            palette: resolvedPalette,
            dotColor: dotColor ?? visuals.dotColor,
            meanColor: meanColor ?? visuals.meanColor,
            medianColor: medianColor ?? visuals.medianColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeZero: includeZero,
            showGrid: showGrid,
            showLabels: showLabels,
            showValues: showValues,
            showMean: showMean,
            showMedian: showMedian,
            showTooltip: showTooltip,
            showActiveDot: showActiveDot,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            dotRadius: dotRadius ?? visuals.dotRadius,
            dotOpacity: dotOpacity,
            jitter: jitter,
            jitterSeed: jitterSeed,
            valueFormatter: formatter,
            onPointTap: onPointTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(ColorScheme colorScheme, Color fallback) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return [
      dotColor ?? fallback,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
  }

  String _defaultSemanticLabel(
    List<SimpleStripPlotData> visibleData,
    List<SimpleStripPlotStats> stats,
    SimpleStripPlotValueFormatter formatter,
  ) {
    final limit = math.min(visibleData.length, 4);
    final summaries = <String>[];
    for (var index = 0; index < limit; index++) {
      final item = visibleData[index];
      final summary = stats[index];
      summaries.add(
        '${item.label} count ${summary.count}, min ${formatter(summary.min)}, '
        'median ${formatter(summary.median)}, max ${formatter(summary.max)}',
      );
    }
    final suffix = visibleData.length > limit
        ? '; and ${visibleData.length - limit} more groups'
        : '';
    final groupLabel = visibleData.length == 1 ? 'group' : 'groups';
    return 'Strip plot chart, ${visibleData.length} $groupLabel. '
        '${summaries.join('; ')}$suffix.';
  }

  static SimpleStripPlotStats _statsFor(SimpleStripPlotData item) {
    final values = item.values.where((value) => value.isFinite).toList()
      ..sort();
    final sum = values.fold<double>(0, (total, value) => total + value);
    return SimpleStripPlotStats(
      count: values.length,
      min: values.first,
      q1: _quantile(values, 0.25),
      median: _quantile(values, 0.5),
      mean: sum / values.length,
      q3: _quantile(values, 0.75),
      max: values.last,
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
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleStripPlotChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleStripPlotData> data;
  final List<SimpleStripPlotStats> stats;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color dotColor;
  final Color meanColor;
  final Color medianColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showMean;
  final bool showMedian;
  final bool showTooltip;
  final bool showActiveDot;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double dotRadius;
  final double dotOpacity;
  final double jitter;
  final int jitterSeed;
  final SimpleStripPlotValueFormatter valueFormatter;
  final SimpleStripPlotTapCallback? onPointTap;
  final SimpleStripPlotTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleStripPlotChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.stats,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.dotColor,
    required this.meanColor,
    required this.medianColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showMean,
    required this.showMedian,
    required this.showTooltip,
    required this.showActiveDot,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.dotRadius,
    required this.dotOpacity,
    required this.jitter,
    required this.jitterSeed,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleStripPlotChartView> createState() =>
      _SimpleStripPlotChartViewState();
}

class _SimpleStripPlotChartViewState extends State<_SimpleStripPlotChartView> {
  _StripPlotSelection? _active;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveDot || widget.onPointTap != null;

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
                painter: _SimpleStripPlotPainter(
                  data: widget.data,
                  stats: widget.stats,
                  orientation: widget.orientation,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  palette: widget.palette,
                  dotColor: widget.dotColor,
                  meanColor: widget.meanColor,
                  medianColor: widget.medianColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  includeZero: widget.includeZero,
                  showGrid: widget.showGrid,
                  showLabels: widget.showLabels,
                  showValues: widget.showValues,
                  showMean: widget.showMean,
                  showMedian: widget.showMedian,
                  showActiveDot: widget.showActiveDot,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
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

                      final item = widget.data[selection.groupIndex];
                      final value = item.values[selection.valueIndex];
                      widget.onPointTap?.call(
                        item,
                        selection.groupIndex,
                        selection.valueIndex,
                        value,
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

  void _setActive(_StripPlotSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _StripPlotSelection? _hitTest(Offset position, Size size) {
    final geometry = _StripPlotGeometry.resolve(
      size: size,
      data: widget.data,
      orientation: widget.orientation,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      includeZero: widget.includeZero,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
      jitter: widget.jitter,
      jitterSeed: widget.jitterSeed,
    );
    for (final point in geometry.points) {
      if ((position - point.center).distance <= widget.dotRadius + 8) {
        return _StripPlotSelection(
          point.groupIndex,
          point.valueIndex,
          point.center,
        );
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _StripPlotSelection selection,
  ) {
    final item = widget.data[selection.groupIndex];
    final stats = widget.stats[selection.groupIndex];
    final value = item.values[selection.valueIndex];
    final formattedValue = widget.valueFormatter(value);
    const tooltipWidth = 188.0;
    const tooltipHeight = 86.0;
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
            selection.groupIndex,
            selection.valueIndex,
            value,
            stats,
            formattedValue,
          ) ??
          _DefaultStripPlotTooltip(
            color: _itemColor(item, selection.groupIndex),
            title: item.label,
            value: formattedValue,
            median: widget.valueFormatter(stats.median),
            count: stats.count,
          ),
    );
  }

  Color _itemColor(SimpleStripPlotData item, int index) {
    return item.color ??
        (widget.palette.isEmpty
            ? widget.dotColor
            : widget.palette[index % widget.palette.length]);
  }
}

class _SimpleStripPlotPainter extends CustomPainter {
  final List<SimpleStripPlotData> data;
  final List<SimpleStripPlotStats> stats;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color dotColor;
  final Color meanColor;
  final Color medianColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showMean;
  final bool showMedian;
  final bool showActiveDot;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double dotRadius;
  final double dotOpacity;
  final double jitter;
  final int jitterSeed;
  final _StripPlotSelection? activeSelection;
  final SimpleStripPlotValueFormatter valueFormatter;
  final double progress;

  const _SimpleStripPlotPainter({
    required this.data,
    required this.stats,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.dotColor,
    required this.meanColor,
    required this.medianColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showMean,
    required this.showMedian,
    required this.showActiveDot,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
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
    final geometry = _StripPlotGeometry.resolve(
      size: size,
      data: data,
      orientation: orientation,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
      jitter: jitter,
      jitterSeed: jitterSeed,
    );
    if (geometry.plot.isEmpty || geometry.points.isEmpty) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    _drawSummaryMarkers(canvas, geometry);
    _drawDots(canvas, geometry);
    if (showLabels) _drawGroupLabels(canvas, geometry);
  }

  void _drawReferenceBands(Canvas canvas, _StripPlotGeometry geometry) {
    final paint = Paint();
    for (final band in referenceBands) {
      final from = band.from.isFinite ? band.from : geometry.range.min;
      final to = band.to.isFinite ? band.to : geometry.range.max;
      final start = geometry.positionForValue(from);
      final end = geometry.positionForValue(to);
      paint.color = (band.color ?? palette.first).withValues(
        alpha: band.opacity,
      );
      if (orientation == SimpleBarChartOrientation.horizontal) {
        canvas.drawRect(
          Rect.fromLTRB(
            math.min(start, end),
            geometry.plot.top,
            math.max(start, end),
            geometry.plot.bottom,
          ),
          paint,
        );
      } else {
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
  }

  void _drawGrid(Canvas canvas, _StripPlotGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          geometry.range.min + geometry.range.span * (index / gridLineCount);
      final position = geometry.positionForValue(value);
      if (orientation == SimpleBarChartOrientation.horizontal) {
        canvas.drawLine(
          Offset(position, geometry.plot.top),
          Offset(position, geometry.plot.bottom),
          paint,
        );
        _drawAxisTickLabel(
          canvas,
          value,
          Offset(position, geometry.plot.bottom),
        );
      } else {
        canvas.drawLine(
          Offset(geometry.plot.left, position),
          Offset(geometry.plot.right, position),
          paint,
        );
        _drawAxisTickLabel(canvas, value, Offset(geometry.plot.left, position));
      }
    }
  }

  void _drawAxis(Canvas canvas, _StripPlotGeometry geometry) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    if (orientation == SimpleBarChartOrientation.horizontal) {
      canvas.drawLine(
        Offset(geometry.plot.left, geometry.plot.bottom),
        Offset(geometry.plot.right, geometry.plot.bottom),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(geometry.plot.left, geometry.plot.top),
        Offset(geometry.plot.left, geometry.plot.bottom),
        paint,
      );
    }
  }

  void _drawReferenceLines(Canvas canvas, _StripPlotGeometry geometry) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final position = geometry.positionForValue(line.value);
      final paint = Paint()
        ..color = line.color ?? axisColor
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke;
      if (orientation == SimpleBarChartOrientation.horizontal) {
        _drawStyledLine(
          canvas,
          Offset(position, geometry.plot.top),
          Offset(position, geometry.plot.bottom),
          paint,
          line.lineStyle,
        );
      } else {
        _drawStyledLine(
          canvas,
          Offset(geometry.plot.left, position),
          Offset(geometry.plot.right, position),
          paint,
          line.lineStyle,
        );
      }
    }
  }

  void _drawSummaryMarkers(Canvas canvas, _StripPlotGeometry geometry) {
    for (var index = 0; index < data.length; index++) {
      final groupStats = stats[index];
      final groupCenter = geometry.groupCenter(index);
      final markerLength = math.min(28.0, geometry.groupSize * 0.38);

      if (showMedian) {
        final medianPosition = geometry.positionForValue(groupStats.median);
        final medianPaint = Paint()
          ..color = medianColor.withValues(alpha: 0.92)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        if (orientation == SimpleBarChartOrientation.horizontal) {
          canvas.drawLine(
            Offset(medianPosition, groupCenter - markerLength / 2),
            Offset(medianPosition, groupCenter + markerLength / 2),
            medianPaint,
          );
        } else {
          canvas.drawLine(
            Offset(groupCenter - markerLength / 2, medianPosition),
            Offset(groupCenter + markerLength / 2, medianPosition),
            medianPaint,
          );
        }
      }

      if (showMean) {
        final meanPosition = geometry.positionForValue(groupStats.mean);
        final meanCenter = orientation == SimpleBarChartOrientation.horizontal
            ? Offset(meanPosition, groupCenter)
            : Offset(groupCenter, meanPosition);
        _drawDiamond(
          canvas,
          meanCenter,
          4.3,
          Paint()..color = meanColor.withValues(alpha: 0.96),
        );
      }

      if (showValues && progress > 0.7) {
        _drawGroupValue(canvas, geometry, index, groupStats);
      }
    }
  }

  void _drawDots(Canvas canvas, _StripPlotGeometry geometry) {
    final haloPaint = Paint()..color = Colors.white.withValues(alpha: 0.84);
    for (final point in geometry.points) {
      final selected =
          activeSelection?.groupIndex == point.groupIndex &&
          activeSelection?.valueIndex == point.valueIndex;
      final item = data[point.groupIndex];
      final baseColor = _itemColor(item, point.groupIndex);
      final center = _animatedCenter(point.center, geometry);
      final radius = dotRadius * (0.45 + progress * 0.55);

      canvas.drawCircle(center, radius + 1.2, haloPaint);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = baseColor.withValues(alpha: dotOpacity),
      );

      if (showActiveDot && selected) {
        canvas.drawCircle(
          center,
          radius + 5,
          Paint()..color = activeColor.withValues(alpha: 0.16),
        );
        canvas.drawCircle(
          center,
          radius + 3,
          Paint()
            ..color = activeColor.withValues(alpha: 0.94)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  Offset _animatedCenter(Offset center, _StripPlotGeometry geometry) {
    final baseline = math.min(
      geometry.range.max,
      math.max(geometry.range.min, 0.0),
    );
    final start = geometry.positionForValue(baseline);
    if (orientation == SimpleBarChartOrientation.horizontal) {
      return Offset(start + (center.dx - start) * progress, center.dy);
    }
    return Offset(center.dx, start + (center.dy - start) * progress);
  }

  void _drawGroupValue(
    Canvas canvas,
    _StripPlotGeometry geometry,
    int index,
    SimpleStripPlotStats groupStats,
  ) {
    final text = valueFormatter(groupStats.median);
    final position = geometry.positionForValue(groupStats.median);
    final groupCenter = geometry.groupCenter(index);
    if (orientation == SimpleBarChartOrientation.horizontal) {
      _paintText(
        canvas,
        text,
        valueStyle,
        Offset(position + dotRadius + 8, groupCenter),
        TextAlign.left,
        58,
        centeredY: true,
      );
    } else {
      _paintText(
        canvas,
        text,
        valueStyle,
        Offset(groupCenter, position - dotRadius - 18),
        TextAlign.center,
        math.max(34.0, geometry.groupSize - 6),
      );
    }
  }

  void _drawGroupLabels(Canvas canvas, _StripPlotGeometry geometry) {
    for (var index = 0; index < data.length; index++) {
      final position = geometry.groupCenter(index);
      if (orientation == SimpleBarChartOrientation.horizontal) {
        _paintText(
          canvas,
          data[index].label,
          labelStyle,
          Offset(padding.left - 10, position),
          TextAlign.right,
          math.max(0.0, padding.left - 16),
          centeredY: true,
        );
      } else {
        _paintText(
          canvas,
          data[index].label,
          labelStyle,
          Offset(position, geometry.plot.bottom + 18),
          TextAlign.center,
          math.max(28.0, geometry.groupSize - 4),
        );
      }
    }
  }

  void _drawAxisTickLabel(Canvas canvas, double value, Offset anchor) {
    final style = labelStyle.copyWith(
      color: labelStyle.color?.withValues(alpha: 0.72),
      fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
    );
    if (orientation == SimpleBarChartOrientation.horizontal) {
      _paintText(
        canvas,
        valueFormatter(value),
        style,
        Offset(anchor.dx, anchor.dy + 6),
        TextAlign.center,
        56,
      );
    } else {
      _paintText(
        canvas,
        valueFormatter(value),
        style,
        Offset(anchor.dx - 8, anchor.dy),
        TextAlign.right,
        math.max(0.0, padding.left - 12),
        centeredY: true,
      );
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

  Color _itemColor(SimpleStripPlotData item, int index) {
    return item.color ??
        (palette.isEmpty ? dotColor : palette[index % palette.length]);
  }

  @override
  bool shouldRepaint(covariant _SimpleStripPlotPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.stats != stats ||
        oldDelegate.orientation != orientation ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.meanColor != meanColor ||
        oldDelegate.medianColor != medianColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeZero != includeZero ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showMean != showMean ||
        oldDelegate.showMedian != showMedian ||
        oldDelegate.showActiveDot != showActiveDot ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.dotOpacity != dotOpacity ||
        oldDelegate.jitter != jitter ||
        oldDelegate.jitterSeed != jitterSeed ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _StripPlotGeometry {
  final Rect plot;
  final _StripValueRange range;
  final List<_StripPointLayout> points;
  final SimpleBarChartOrientation orientation;
  final double groupSize;

  const _StripPlotGeometry({
    required this.plot,
    required this.range,
    required this.points,
    required this.orientation,
    required this.groupSize,
  });

  factory _StripPlotGeometry.resolve({
    required Size size,
    required List<SimpleStripPlotData> data,
    required SimpleBarChartOrientation orientation,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required bool includeZero,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
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
      return _StripPlotGeometry(
        plot: plot,
        range: const _StripValueRange(0, 1),
        points: const [],
        orientation: orientation,
        groupSize: 0,
      );
    }

    final range = _StripValueRange.resolve(
      data: data,
      minValue: minValue,
      maxValue: maxValue,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    final groupSize =
        (orientation == SimpleBarChartOrientation.horizontal
            ? plot.height
            : plot.width) /
        data.length;
    final jitterSpan = math.min(groupSize * jitter, groupSize * 0.48);
    final points = <_StripPointLayout>[];

    for (var groupIndex = 0; groupIndex < data.length; groupIndex++) {
      final groupCenter = orientation == SimpleBarChartOrientation.horizontal
          ? plot.top + groupSize * groupIndex + groupSize / 2
          : plot.left + groupSize * groupIndex + groupSize / 2;
      final item = data[groupIndex];
      for (var valueIndex = 0; valueIndex < item.values.length; valueIndex++) {
        final value = item.values[valueIndex];
        if (!value.isFinite) continue;
        final valuePosition = _positionForValue(
          value,
          plot,
          range,
          orientation,
        );
        final offset = _jitterOffset(
          groupIndex,
          valueIndex,
          jitterSpan,
          jitterSeed,
        );
        final center = orientation == SimpleBarChartOrientation.horizontal
            ? Offset(valuePosition, groupCenter + offset)
            : Offset(groupCenter + offset, valuePosition);
        points.add(
          _StripPointLayout(
            groupIndex: groupIndex,
            valueIndex: valueIndex,
            center: center,
          ),
        );
      }
    }

    return _StripPlotGeometry(
      plot: plot,
      range: range,
      points: points,
      orientation: orientation,
      groupSize: groupSize,
    );
  }

  double groupCenter(int groupIndex) {
    if (orientation == SimpleBarChartOrientation.horizontal) {
      return plot.top + groupSize * groupIndex + groupSize / 2;
    }
    return plot.left + groupSize * groupIndex + groupSize / 2;
  }

  double positionForValue(double value) {
    return _positionForValue(value, plot, range, orientation);
  }

  static double _positionForValue(
    double value,
    Rect plot,
    _StripValueRange range,
    SimpleBarChartOrientation orientation,
  ) {
    final normalized = ((value - range.min) / range.span).clamp(0.0, 1.0);
    if (orientation == SimpleBarChartOrientation.horizontal) {
      return plot.left + normalized * plot.width;
    }
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
          (groupIndex + 1) * 91.73 +
              (valueIndex + 1) * 53.17 +
              (seed + 1) * 0.37,
        ) *
        43758.5453;
    final fraction = raw - raw.floorToDouble();
    return (fraction - 0.5) * span;
  }
}

class _StripPointLayout {
  final int groupIndex;
  final int valueIndex;
  final Offset center;

  const _StripPointLayout({
    required this.groupIndex,
    required this.valueIndex,
    required this.center,
  });
}

class _StripPlotSelection {
  final int groupIndex;
  final int valueIndex;
  final Offset position;

  const _StripPlotSelection(this.groupIndex, this.valueIndex, this.position);

  @override
  bool operator ==(Object other) {
    return other is _StripPlotSelection &&
        other.groupIndex == groupIndex &&
        other.valueIndex == valueIndex;
  }

  @override
  int get hashCode => Object.hash(groupIndex, valueIndex);
}

class _StripValueRange {
  final double min;
  final double max;

  const _StripValueRange(this.min, this.max);

  double get span => max - min;

  factory _StripValueRange.resolve({
    required List<SimpleStripPlotData> data,
    required double? minValue,
    required double? maxValue,
    required bool includeZero,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    var lower = double.infinity;
    var upper = double.negativeInfinity;
    for (final item in data) {
      for (final value in item.values) {
        if (!value.isFinite) continue;
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
    if (!lower.isFinite || !upper.isFinite) {
      lower = 0;
      upper = 1;
    }

    if (includeZero) {
      lower = math.min(lower, 0.0);
      upper = math.max(upper, 0.0);
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
    return _StripValueRange(lower, upper);
  }
}

class _SimpleStripPlotVisuals {
  final Color dotColor;
  final Color meanColor;
  final Color medianColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double dotRadius;

  const _SimpleStripPlotVisuals({
    required this.dotColor,
    required this.meanColor,
    required this.medianColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.dotRadius,
  });

  factory _SimpleStripPlotVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleStripPlotVisuals(
          dotColor: colorScheme.primary,
          meanColor: colorScheme.tertiary,
          medianColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.52),
          activeColor: colorScheme.primary,
          dotRadius: 4.8,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleStripPlotVisuals(
          dotColor: colorScheme.primary,
          meanColor: colorScheme.secondary,
          medianColor: colorScheme.onSurface,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          activeColor: colorScheme.primary,
          dotRadius: 4.4,
        );
      case SimpleBarChartStyle.education:
        return _SimpleStripPlotVisuals(
          dotColor: colorScheme.secondary,
          meanColor: colorScheme.tertiary,
          medianColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          activeColor: colorScheme.secondary,
          dotRadius: 4.9,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleStripPlotVisuals(
          dotColor: colorScheme.tertiary,
          meanColor: colorScheme.primary,
          medianColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          activeColor: colorScheme.tertiary,
          dotRadius: 5.2,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleStripPlotVisuals(
          dotColor: colorScheme.primary,
          meanColor: colorScheme.tertiary,
          medianColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: colorScheme.primary,
          dotRadius: 4.7,
        );
    }
  }
}

class _DefaultStripPlotTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String median;
  final int count;

  const _DefaultStripPlotTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.median,
    required this.count,
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
                    shape: BoxShape.circle,
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
            _TooltipMetric(label: 'Value', value: value),
            const SizedBox(height: 4),
            _TooltipMetric(label: 'Median', value: median),
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
