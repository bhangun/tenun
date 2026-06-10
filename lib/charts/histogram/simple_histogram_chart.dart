import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleHistogramValueFormatter = String Function(double value);
typedef SimpleHistogramTapCallback =
    void Function(SimpleHistogramBin bin, int index);
typedef SimpleHistogramTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleHistogramBin bin,
      int index,
      String formattedRange,
      String formattedCount,
      String formattedShare,
    );

enum SimpleHistogramScale { count, percent }

class SimpleHistogramBin {
  final double start;
  final double end;
  final int count;
  final String? label;
  final Color? color;

  const SimpleHistogramBin({
    required this.start,
    required this.end,
    required this.count,
    this.label,
    this.color,
  });

  double get midpoint => (start + end) / 2;
}

/// A lightweight distribution chart for scores, prices, latency, ages, and
/// other numeric samples.
class SimpleHistogramChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(48, 18, 18, 42);

  final List<double> values;
  final List<SimpleHistogramBin> bins;
  final int binCount;
  final SimpleHistogramScale scale;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? barColor;
  final Color? curveColor;
  final Color? meanColor;
  final Color? medianColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeBarColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showAxisLabels;
  final bool showMean;
  final bool showMedian;
  final bool showDistributionCurve;
  final bool showTooltip;
  final bool showActiveBin;
  final int gridLineCount;
  final double? barRadius;
  final double? gapRatio;
  final bool? useGradient;
  final SimpleHistogramValueFormatter? valueFormatter;
  final SimpleHistogramValueFormatter? countFormatter;
  final SimpleHistogramValueFormatter? percentFormatter;
  final SimpleHistogramTapCallback? onBinTap;
  final SimpleHistogramTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleHistogramChart({
    super.key,
    this.values = const [],
    this.bins = const [],
    this.binCount = 8,
    this.scale = SimpleHistogramScale.count,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.barColor,
    this.curveColor,
    this.meanColor,
    this.medianColor,
    this.gridColor,
    this.axisColor,
    this.activeBarColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showAxisLabels = true,
    this.showMean = true,
    this.showMedian = false,
    this.showDistributionCurve = false,
    this.showTooltip = true,
    this.showActiveBin = true,
    this.gridLineCount = 4,
    this.barRadius,
    this.gapRatio,
    this.useGradient,
    this.valueFormatter,
    this.countFormatter,
    this.percentFormatter,
    this.onBinTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 650),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(binCount > 0),
       assert(height > 0),
       assert(gridLineCount >= 2),
       assert(barRadius == null || barRadius >= 0),
       assert(gapRatio == null || (gapRatio >= 0 && gapRatio < 0.8));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleHistogramVisuals.resolve(style, colorScheme);
    final resolvedBins = _resolveBins();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedCountFormatter = countFormatter ?? _defaultCountFormatter;
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

        if (resolvedBins.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Histogram chart, no data.',
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
        final stats = _HistogramStats.resolve(
          values: values,
          bins: resolvedBins,
        );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            resolvedBins,
            formatter,
            resolvedCountFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleHistogramChartView(
            width: width,
            height: chartHeight,
            bins: resolvedBins,
            scale: scale,
            stats: stats,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals),
            barColor: barColor ?? visuals.barColor,
            curveColor: curveColor ?? visuals.curveColor,
            meanColor: meanColor ?? visuals.meanColor,
            medianColor: medianColor ?? visuals.medianColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeBarColor: activeBarColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showAxisLabels: showAxisLabels,
            showMean: showMean,
            showMedian: showMedian,
            showDistributionCurve: showDistributionCurve,
            showTooltip: showTooltip,
            showActiveBin: showActiveBin,
            gridLineCount: gridLineCount,
            barRadius: barRadius ?? visuals.barRadius,
            gapRatio: gapRatio ?? visuals.gapRatio,
            useGradient: useGradient ?? visuals.useGradient,
            valueFormatter: formatter,
            countFormatter: resolvedCountFormatter,
            percentFormatter: resolvedPercentFormatter,
            onBinTap: onBinTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<SimpleHistogramBin> _resolveBins() {
    final providedBins = bins
        .where(
          (bin) =>
              bin.start.isFinite &&
              bin.end.isFinite &&
              bin.count >= 0 &&
              bin.start != bin.end,
        )
        .map(
          (bin) => bin.start < bin.end
              ? bin
              : SimpleHistogramBin(
                  start: bin.end,
                  end: bin.start,
                  count: bin.count,
                  label: bin.label,
                  color: bin.color,
                ),
        )
        .toList();
    if (providedBins.isNotEmpty) return providedBins;

    final visibleValues = values.where((value) => value.isFinite).toList();
    if (visibleValues.isEmpty) return const [];

    var min = visibleValues.reduce(math.min);
    var max = visibleValues.reduce(math.max);
    if (minValue != null && minValue!.isFinite) min = minValue!;
    if (maxValue != null && maxValue!.isFinite) max = maxValue!;
    if (min > max) {
      final swap = min;
      min = max;
      max = swap;
    }
    if (min == max) {
      final spread = min == 0 ? 1.0 : min.abs() * 0.08;
      min -= spread;
      max += spread;
    }

    final width = (max - min) / binCount;
    final counts = List<int>.filled(binCount, 0);
    for (final value in visibleValues) {
      if (value < min || value > max) continue;
      final index = ((value - min) / width).floor().clamp(0, binCount - 1);
      counts[index]++;
    }

    return List.generate(binCount, (index) {
      final start = min + width * index;
      final end = index == binCount - 1 ? max : min + width * (index + 1);
      return SimpleHistogramBin(start: start, end: end, count: counts[index]);
    });
  }

  List<Color> _resolvePalette(
    ColorScheme colorScheme,
    _SimpleHistogramVisuals visuals,
  ) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return const [];
  }

  String _defaultSemanticLabel(
    List<SimpleHistogramBin> visibleBins,
    SimpleHistogramValueFormatter formatter,
    SimpleHistogramValueFormatter resolvedCountFormatter,
  ) {
    final summaries = visibleBins
        .take(5)
        .map(
          (bin) =>
              '${_rangeLabel(bin, formatter)}: '
              '${resolvedCountFormatter(bin.count.toDouble())}',
        )
        .join(', ');
    final remaining = visibleBins.length - math.min(visibleBins.length, 5);
    final suffix = remaining > 0 ? ', and $remaining more bins' : '';
    final countLabel = visibleBins.length == 1 ? 'bin' : 'bins';
    return 'Histogram chart, ${visibleBins.length} $countLabel. '
        '$summaries$suffix.';
  }

  static String _rangeLabel(
    SimpleHistogramBin bin,
    SimpleHistogramValueFormatter formatter,
  ) {
    if (bin.label != null && bin.label!.trim().isNotEmpty) return bin.label!;
    return '${formatter(bin.start)}-${formatter(bin.end)}';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultCountFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }
}

class _SimpleHistogramChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleHistogramBin> bins;
  final SimpleHistogramScale scale;
  final _HistogramStats stats;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color barColor;
  final Color curveColor;
  final Color meanColor;
  final Color medianColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeBarColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showAxisLabels;
  final bool showMean;
  final bool showMedian;
  final bool showDistributionCurve;
  final bool showTooltip;
  final bool showActiveBin;
  final int gridLineCount;
  final double barRadius;
  final double gapRatio;
  final bool useGradient;
  final SimpleHistogramValueFormatter valueFormatter;
  final SimpleHistogramValueFormatter countFormatter;
  final SimpleHistogramValueFormatter percentFormatter;
  final SimpleHistogramTapCallback? onBinTap;
  final SimpleHistogramTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleHistogramChartView({
    required this.width,
    required this.height,
    required this.bins,
    required this.scale,
    required this.stats,
    required this.padding,
    required this.palette,
    required this.barColor,
    required this.curveColor,
    required this.meanColor,
    required this.medianColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeBarColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showAxisLabels,
    required this.showMean,
    required this.showMedian,
    required this.showDistributionCurve,
    required this.showTooltip,
    required this.showActiveBin,
    required this.gridLineCount,
    required this.barRadius,
    required this.gapRatio,
    required this.useGradient,
    required this.valueFormatter,
    required this.countFormatter,
    required this.percentFormatter,
    required this.onBinTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleHistogramChartView> createState() =>
      _SimpleHistogramChartViewState();
}

class _SimpleHistogramChartViewState extends State<_SimpleHistogramChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveBin || widget.onBinTap != null;

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
                painter: _SimpleHistogramPainter(
                  bins: widget.bins,
                  scale: widget.scale,
                  stats: widget.stats,
                  padding: widget.padding,
                  palette: widget.palette,
                  barColor: widget.barColor,
                  curveColor: widget.curveColor,
                  meanColor: widget.meanColor,
                  medianColor: widget.medianColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeBarColor: widget.activeBarColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showAxisLabels: widget.showAxisLabels,
                  showMean: widget.showMean,
                  showMedian: widget.showMedian,
                  showDistributionCurve: widget.showDistributionCurve,
                  showActiveBin: widget.showActiveBin,
                  gridLineCount: widget.gridLineCount,
                  barRadius: widget.barRadius,
                  gapRatio: widget.gapRatio,
                  useGradient: widget.useGradient,
                  valueFormatter: widget.valueFormatter,
                  countFormatter: widget.countFormatter,
                  percentFormatter: widget.percentFormatter,
                  activeIndex: widget.showActiveBin ? _activeIndex : null,
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
                        widget.onBinTap?.call(widget.bins[index], index);
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
    final geometry = _HistogramGeometry.resolve(
      size: size,
      bins: widget.bins,
      scale: widget.scale,
      padding: widget.padding,
      gapRatio: widget.gapRatio,
    );
    if (geometry.plot.isEmpty ||
        !geometry.plot.inflate(10).contains(position)) {
      return null;
    }

    for (final bin in geometry.bins) {
      if (bin.rect.inflate(3).contains(position)) return bin.index;
    }

    final relativeX = position.dx - geometry.plot.left;
    final index = (relativeX / geometry.slotWidth).floor();
    return index >= 0 && index < widget.bins.length ? index : null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final bin = widget.bins[index];
    final total = widget.bins.fold<int>(0, (sum, item) => sum + item.count);
    final share = total == 0 ? 0.0 : bin.count / total;
    final range = _rangeLabel(bin);
    final count = widget.countFormatter(bin.count.toDouble());
    final percent = widget.percentFormatter(share);
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 190.0;
    const tooltipHeight = 92.0;
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
            bin,
            index,
            range,
            count,
            percent,
          ) ??
          _DefaultHistogramTooltip(
            color: _binColor(bin, index),
            title: range,
            countValue: count,
            shareValue: percent,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final geometry = _HistogramGeometry.resolve(
      size: size,
      bins: widget.bins,
      scale: widget.scale,
      padding: widget.padding,
      gapRatio: widget.gapRatio,
    );
    final layout = geometry.bins.firstWhere(
      (item) => item.index == index,
      orElse: () => geometry.bins.first,
    );
    return Offset(layout.rect.center.dx, layout.rect.top);
  }

  Color _binColor(SimpleHistogramBin bin, int index) {
    if (bin.color != null) return bin.color!;
    if (widget.palette.isNotEmpty && index < widget.palette.length) {
      return widget.palette[index];
    }
    return widget.barColor;
  }

  String _rangeLabel(SimpleHistogramBin bin) {
    if (bin.label != null && bin.label!.trim().isNotEmpty) return bin.label!;
    return '${widget.valueFormatter(bin.start)}-${widget.valueFormatter(bin.end)}';
  }
}

class _SimpleHistogramPainter extends CustomPainter {
  final List<SimpleHistogramBin> bins;
  final SimpleHistogramScale scale;
  final _HistogramStats stats;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color barColor;
  final Color curveColor;
  final Color meanColor;
  final Color medianColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeBarColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showAxisLabels;
  final bool showMean;
  final bool showMedian;
  final bool showDistributionCurve;
  final bool showActiveBin;
  final int gridLineCount;
  final double barRadius;
  final double gapRatio;
  final bool useGradient;
  final SimpleHistogramValueFormatter valueFormatter;
  final SimpleHistogramValueFormatter countFormatter;
  final SimpleHistogramValueFormatter percentFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleHistogramPainter({
    required this.bins,
    required this.scale,
    required this.stats,
    required this.padding,
    required this.palette,
    required this.barColor,
    required this.curveColor,
    required this.meanColor,
    required this.medianColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeBarColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showAxisLabels,
    required this.showMean,
    required this.showMedian,
    required this.showDistributionCurve,
    required this.showActiveBin,
    required this.gridLineCount,
    required this.barRadius,
    required this.gapRatio,
    required this.useGradient,
    required this.valueFormatter,
    required this.countFormatter,
    required this.percentFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _HistogramGeometry.resolve(
      size: size,
      bins: bins,
      scale: scale,
      padding: padding,
      gapRatio: gapRatio,
    );
    if (geometry.plot.isEmpty || geometry.bins.isEmpty) return;

    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawBars(canvas, geometry);
    if (showDistributionCurve) _drawDistributionCurve(canvas, geometry);
    if (showMean && stats.mean != null) {
      _drawMarker(canvas, geometry, stats.mean!, meanColor, 'Mean');
    }
    if (showMedian && stats.median != null) {
      _drawMarker(canvas, geometry, stats.median!, medianColor, 'Median');
    }
    if (showAxisLabels) _drawAxisLabels(canvas, geometry);
  }

  void _drawGrid(Canvas canvas, _HistogramGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value = geometry.maxScaledValue * (index / gridLineCount);
      final y = geometry.yForScaledValue(value);
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
      _paintText(
        canvas,
        _formatScaleValue(value),
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

  void _drawAxis(Canvas canvas, _HistogramGeometry geometry) {
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

  void _drawBars(Canvas canvas, _HistogramGeometry geometry) {
    for (final layout in geometry.bins) {
      final bin = bins[layout.index];
      final color = _binColor(bin, layout.index);
      final selected = activeIndex == layout.index;
      final activeExists = activeIndex != null;
      final opacity = activeExists && !selected ? 0.36 : 1.0;
      final animatedRect = Rect.fromLTRB(
        layout.rect.left,
        layout.rect.bottom - layout.rect.height * progress,
        layout.rect.right,
        layout.rect.bottom,
      );
      final radius = Radius.circular(
        math.min(barRadius, animatedRect.width / 2),
      );
      final rrect = RRect.fromRectAndCorners(
        animatedRect,
        topLeft: radius,
        topRight: radius,
      );
      final paint = Paint()..color = color.withValues(alpha: opacity);
      if (useGradient && animatedRect.height > 0) {
        paint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color.withValues(alpha: opacity * 0.72),
            color.withValues(alpha: opacity),
          ],
        ).createShader(animatedRect);
      }
      canvas.drawRRect(rrect, paint);

      if (showActiveBin && selected) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = (activeBarColor ?? color).withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }

      if (showValues && progress > 0.68 && layout.scaledValue > 0) {
        _paintText(
          canvas,
          _formatScaleValue(layout.scaledValue),
          valueStyle,
          Offset(animatedRect.center.dx, animatedRect.top - 18),
          TextAlign.center,
          math.max(24.0, layout.rect.width + 12),
        );
      }
    }
  }

  void _drawDistributionCurve(Canvas canvas, _HistogramGeometry geometry) {
    final points = geometry.bins
        .map((bin) => Offset(bin.rect.center.dx, bin.rect.top))
        .toList();
    if (points.length < 2) return;
    final animatedPoints = points
        .map(
          (point) => Offset(
            point.dx,
            geometry.plot.bottom - (geometry.plot.bottom - point.dy) * progress,
          ),
        )
        .toList();
    final path = Path()
      ..moveTo(animatedPoints.first.dx, animatedPoints.first.dy);
    for (var index = 0; index < animatedPoints.length - 1; index++) {
      final current = animatedPoints[index];
      final next = animatedPoints[index + 1];
      final midX = (current.dx + next.dx) / 2;
      path.cubicTo(midX, current.dy, midX, next.dy, next.dx, next.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = curveColor.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawMarker(
    Canvas canvas,
    _HistogramGeometry geometry,
    double value,
    Color color,
    String label,
  ) {
    final x = geometry.xForValue(value);
    if (x < geometry.plot.left - 1 || x > geometry.plot.right + 1) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    _drawDashedLine(
      canvas,
      Offset(x, geometry.plot.top),
      Offset(x, geometry.plot.bottom),
      paint,
    );
    final text = '$label ${valueFormatter(value)}';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: valueStyle.copyWith(
          color: color,
          fontSize: math.max(9, (valueStyle.fontSize ?? 11) - 1),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: 92);
    const insets = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + insets.horizontal;
    final height = painter.height + insets.vertical;
    final left = _safeClamp(
      x + 6,
      geometry.plot.left + 2,
      geometry.plot.right - width - 2,
    );
    final top = geometry.plot.top + 4;
    final rect = Rect.fromLTWH(left, top, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = color.withValues(alpha: 0.12),
    );
    painter.paint(canvas, Offset(left + insets.left, top + insets.top));
  }

  void _drawAxisLabels(Canvas canvas, _HistogramGeometry geometry) {
    final maxLabels = math.min(6, bins.length + 1);
    final step = math.max(1, (bins.length / (maxLabels - 1)).ceil());
    for (var index = 0; index <= bins.length; index += step) {
      final value = index == bins.length ? bins.last.end : bins[index].start;
      final x = geometry.xForValue(value);
      _paintText(
        canvas,
        valueFormatter(value),
        labelStyle,
        Offset(x, geometry.plot.bottom + 8),
        TextAlign.center,
        math.max(34.0, geometry.slotWidth * 1.25),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    var distance = 0.0;
    while (distance < total) {
      final next = math.min(distance + dash, total);
      canvas.drawLine(
        start + direction * distance,
        start + direction * next,
        paint,
      );
      distance = next + gap;
    }
  }

  Color _binColor(SimpleHistogramBin bin, int index) {
    if (bin.color != null) return bin.color!;
    if (palette.isNotEmpty && index < palette.length) return palette[index];
    return barColor;
  }

  String _formatScaleValue(double value) {
    return switch (scale) {
      SimpleHistogramScale.count => countFormatter(value),
      SimpleHistogramScale.percent => percentFormatter(value),
    };
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
  bool shouldRepaint(covariant _SimpleHistogramPainter oldDelegate) {
    return oldDelegate.bins != bins ||
        oldDelegate.scale != scale ||
        oldDelegate.stats != stats ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.barColor != barColor ||
        oldDelegate.curveColor != curveColor ||
        oldDelegate.meanColor != meanColor ||
        oldDelegate.medianColor != medianColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeBarColor != activeBarColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.showMean != showMean ||
        oldDelegate.showMedian != showMedian ||
        oldDelegate.showDistributionCurve != showDistributionCurve ||
        oldDelegate.showActiveBin != showActiveBin ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.gapRatio != gapRatio ||
        oldDelegate.useGradient != useGradient ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.countFormatter != countFormatter ||
        oldDelegate.percentFormatter != percentFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _HistogramGeometry {
  final Rect plot;
  final List<_HistogramBinLayout> bins;
  final double minValue;
  final double maxValue;
  final double maxScaledValue;
  final double slotWidth;

  const _HistogramGeometry({
    required this.plot,
    required this.bins,
    required this.minValue,
    required this.maxValue,
    required this.maxScaledValue,
    required this.slotWidth,
  });

  factory _HistogramGeometry.resolve({
    required Size size,
    required List<SimpleHistogramBin> bins,
    required SimpleHistogramScale scale,
    required EdgeInsets padding,
    required double gapRatio,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (bins.isEmpty) {
      return _HistogramGeometry(
        plot: plot,
        bins: const [],
        minValue: 0,
        maxValue: 1,
        maxScaledValue: 1,
        slotWidth: 0,
      );
    }

    final minValue = bins.map((bin) => bin.start).reduce(math.min);
    final maxValue = bins.map((bin) => bin.end).reduce(math.max);
    final total = bins.fold<int>(0, (sum, bin) => sum + bin.count);
    final rawMaxCount = bins
        .map((bin) => bin.count)
        .fold<int>(0, (max, count) => math.max(max, count));
    final maxScaledValue = switch (scale) {
      SimpleHistogramScale.count => math.max(1.0, rawMaxCount.toDouble()),
      SimpleHistogramScale.percent =>
        total == 0 ? 1.0 : math.max(0.01, rawMaxCount / total),
    };
    final slotWidth = plot.width / bins.length;
    final gap = slotWidth * gapRatio;
    final layouts = <_HistogramBinLayout>[];
    for (var index = 0; index < bins.length; index++) {
      final bin = bins[index];
      final scaledValue = switch (scale) {
        SimpleHistogramScale.count => bin.count.toDouble(),
        SimpleHistogramScale.percent => total == 0 ? 0.0 : bin.count / total,
      };
      final left = plot.left + slotWidth * index + gap / 2;
      final right = plot.left + slotWidth * (index + 1) - gap / 2;
      final top =
          plot.bottom -
          (scaledValue / maxScaledValue).clamp(0.0, 1.0) * plot.height;
      layouts.add(
        _HistogramBinLayout(
          index: index,
          rect: Rect.fromLTRB(left, top, right, plot.bottom),
          scaledValue: scaledValue,
        ),
      );
    }

    return _HistogramGeometry(
      plot: plot,
      bins: layouts,
      minValue: minValue,
      maxValue: maxValue,
      maxScaledValue: maxScaledValue,
      slotWidth: slotWidth,
    );
  }

  double yForScaledValue(double value) {
    final normalized = (value / maxScaledValue).clamp(0.0, 1.0).toDouble();
    return plot.bottom - normalized * plot.height;
  }

  double xForValue(double value) {
    final span = math.max(1e-9, maxValue - minValue);
    final normalized = ((value - minValue) / span).clamp(0.0, 1.0).toDouble();
    return plot.left + normalized * plot.width;
  }
}

class _HistogramBinLayout {
  final int index;
  final Rect rect;
  final double scaledValue;

  const _HistogramBinLayout({
    required this.index,
    required this.rect,
    required this.scaledValue,
  });
}

class _HistogramStats {
  final double? mean;
  final double? median;

  const _HistogramStats({required this.mean, required this.median});

  factory _HistogramStats.resolve({
    required List<double> values,
    required List<SimpleHistogramBin> bins,
  }) {
    final visibleValues = values.where((value) => value.isFinite).toList()
      ..sort();
    if (visibleValues.isNotEmpty) {
      final mean =
          visibleValues.fold(0.0, (sum, value) => sum + value) /
          visibleValues.length;
      final middle = visibleValues.length ~/ 2;
      final median = visibleValues.length.isOdd
          ? visibleValues[middle]
          : (visibleValues[middle - 1] + visibleValues[middle]) / 2;
      return _HistogramStats(mean: mean, median: median);
    }

    final total = bins.fold<int>(0, (sum, bin) => sum + bin.count);
    if (total == 0) return const _HistogramStats(mean: null, median: null);
    final mean =
        bins.fold<double>(0, (sum, bin) => sum + bin.midpoint * bin.count) /
        total;
    var cumulative = 0;
    final halfway = total / 2;
    double? median;
    for (final bin in bins) {
      cumulative += bin.count;
      if (cumulative >= halfway) {
        median = bin.midpoint;
        break;
      }
    }
    return _HistogramStats(mean: mean, median: median);
  }
}

class _SimpleHistogramVisuals {
  final Color barColor;
  final Color curveColor;
  final Color meanColor;
  final Color medianColor;
  final Color gridColor;
  final Color axisColor;
  final double barRadius;
  final double gapRatio;
  final bool useGradient;

  const _SimpleHistogramVisuals({
    required this.barColor,
    required this.curveColor,
    required this.meanColor,
    required this.medianColor,
    required this.gridColor,
    required this.axisColor,
    required this.barRadius,
    required this.gapRatio,
    required this.useGradient,
  });

  factory _SimpleHistogramVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleHistogramVisuals(
          barColor: colorScheme.primary,
          curveColor: colorScheme.secondary,
          meanColor: colorScheme.tertiary,
          medianColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          barRadius: 7,
          gapRatio: 0.14,
          useGradient: true,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleHistogramVisuals(
          barColor: colorScheme.primary,
          curveColor: colorScheme.primary,
          meanColor: colorScheme.secondary,
          medianColor: colorScheme.error.withValues(alpha: 0.88),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          barRadius: 3,
          gapRatio: 0.08,
          useGradient: false,
        );
      case SimpleBarChartStyle.education:
        return _SimpleHistogramVisuals(
          barColor: colorScheme.secondary,
          curveColor: colorScheme.tertiary,
          meanColor: colorScheme.primary,
          medianColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          barRadius: 6,
          gapRatio: 0.16,
          useGradient: false,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleHistogramVisuals(
          barColor: colorScheme.tertiary,
          curveColor: colorScheme.primary,
          meanColor: colorScheme.secondary,
          medianColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          barRadius: 8,
          gapRatio: 0.18,
          useGradient: true,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleHistogramVisuals(
          barColor: colorScheme.primary,
          curveColor: colorScheme.secondary,
          meanColor: colorScheme.tertiary,
          medianColor: colorScheme.error.withValues(alpha: 0.88),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          barRadius: 5,
          gapRatio: 0.12,
          useGradient: true,
        );
    }
  }
}

class _DefaultHistogramTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String countValue;
  final String shareValue;

  const _DefaultHistogramTooltip({
    required this.color,
    required this.title,
    required this.countValue,
    required this.shareValue,
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
              value: countValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: 'Share',
              value: shareValue,
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
