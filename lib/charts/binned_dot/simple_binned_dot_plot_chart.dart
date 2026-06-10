import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleBinnedDotPlotValueFormatter = String Function(double value);

typedef SimpleBinnedDotPlotTapCallback =
    void Function(SimpleBinnedDotPlotBin bin, int index);

typedef SimpleBinnedDotPlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleBinnedDotPlotBin bin,
      int index,
      String formattedRange,
      String formattedCount,
      String formattedDots,
    );

class SimpleBinnedDotPlotBin {
  final double start;
  final double end;
  final int count;
  final String? label;
  final Color? color;

  const SimpleBinnedDotPlotBin({
    required this.start,
    required this.end,
    required this.count,
    this.label,
    this.color,
  });

  double get midpoint => (start + end) / 2;
}

/// A compact distribution chart that stacks one or more observations as dots
/// inside numeric bins.
class SimpleBinnedDotPlotChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(48, 18, 18, 42);

  final List<double> values;
  final List<SimpleBinnedDotPlotBin> bins;
  final int binCount;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? dotColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeDotColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showAxisLabels;
  final bool showTooltip;
  final bool showActiveBin;
  final int gridLineCount;
  final double? dotRadius;
  final double dotGap;
  final double dotOpacity;
  final double dotValue;
  final SimpleBinnedDotPlotValueFormatter? valueFormatter;
  final SimpleBinnedDotPlotValueFormatter? countFormatter;
  final SimpleBinnedDotPlotTapCallback? onBinTap;
  final SimpleBinnedDotPlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleBinnedDotPlotChart({
    super.key,
    this.values = const [],
    this.bins = const [],
    this.binCount = 8,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 250,
    this.padding = _defaultPadding,
    this.palette,
    this.dotColor,
    this.gridColor,
    this.axisColor,
    this.activeDotColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showAxisLabels = true,
    this.showTooltip = true,
    this.showActiveBin = true,
    this.gridLineCount = 4,
    this.dotRadius,
    this.dotGap = 2,
    this.dotOpacity = 0.84,
    this.dotValue = 1,
    this.valueFormatter,
    this.countFormatter,
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
       assert(dotRadius == null || dotRadius > 0),
       assert(dotGap >= 0),
       assert(dotOpacity >= 0 && dotOpacity <= 1),
       assert(dotValue > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleBinnedDotPlotVisuals.resolve(style, colorScheme);
    final resolvedBins = _resolveBins();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedCountFormatter = countFormatter ?? _defaultCountFormatter;

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
            emptySemanticLabel: 'Binned dot plot chart, no data.',
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
          semanticLabel: _defaultSemanticLabel(
            resolvedBins,
            formatter,
            resolvedCountFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleBinnedDotPlotChartView(
            width: width,
            height: chartHeight,
            bins: resolvedBins,
            padding: padding,
            palette: _resolvePalette(visuals.dotColor, colorScheme),
            dotColor: dotColor ?? visuals.dotColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeDotColor: activeDotColor ?? visuals.activeDotColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showAxisLabels: showAxisLabels,
            showTooltip: showTooltip,
            showActiveBin: showActiveBin,
            gridLineCount: gridLineCount,
            dotRadius: dotRadius ?? visuals.dotRadius,
            dotGap: dotGap,
            dotOpacity: dotOpacity,
            dotValue: dotValue,
            valueFormatter: formatter,
            countFormatter: resolvedCountFormatter,
            onBinTap: onBinTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(Color fallback, ColorScheme colorScheme) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return [
      dotColor ?? fallback,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
  }

  List<SimpleBinnedDotPlotBin> _resolveBins() {
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
              : SimpleBinnedDotPlotBin(
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
      min -= 0.5;
      max += 0.5;
    }

    final width = (max - min) / binCount;
    final counts = List<int>.filled(binCount, 0);
    for (final value in visibleValues) {
      if (value < min || value > max) continue;
      final rawIndex = ((value - min) / width).floor();
      final index = rawIndex.clamp(0, binCount - 1);
      counts[index]++;
    }

    return [
      for (var index = 0; index < binCount; index++)
        SimpleBinnedDotPlotBin(
          start: min + width * index,
          end: index == binCount - 1 ? max : min + width * (index + 1),
          count: counts[index],
        ),
    ].where((bin) => bin.count > 0).toList();
  }

  String _defaultSemanticLabel(
    List<SimpleBinnedDotPlotBin> resolvedBins,
    SimpleBinnedDotPlotValueFormatter formatter,
    SimpleBinnedDotPlotValueFormatter countFormatter,
  ) {
    final summaries = resolvedBins
        .take(5)
        .map((bin) {
          return '${_formatRange(bin, formatter)}: '
              '${countFormatter(bin.count.toDouble())}';
        })
        .join(', ');
    final remaining = resolvedBins.length - math.min(resolvedBins.length, 5);
    final suffix = remaining > 0 ? ', and $remaining more bins' : '';
    return 'Binned dot plot chart, ${resolvedBins.length} bins. '
        '$summaries$suffix.';
  }

  static String _formatRange(
    SimpleBinnedDotPlotBin bin,
    SimpleBinnedDotPlotValueFormatter formatter,
  ) {
    return bin.label ?? '${formatter(bin.start)}-${formatter(bin.end)}';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _defaultCountFormatter(double value) {
    return value.toStringAsFixed(0);
  }
}

class _SimpleBinnedDotPlotChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleBinnedDotPlotBin> bins;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color dotColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeDotColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showAxisLabels;
  final bool showTooltip;
  final bool showActiveBin;
  final int gridLineCount;
  final double dotRadius;
  final double dotGap;
  final double dotOpacity;
  final double dotValue;
  final SimpleBinnedDotPlotValueFormatter valueFormatter;
  final SimpleBinnedDotPlotValueFormatter countFormatter;
  final SimpleBinnedDotPlotTapCallback? onBinTap;
  final SimpleBinnedDotPlotTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleBinnedDotPlotChartView({
    required this.width,
    required this.height,
    required this.bins,
    required this.padding,
    required this.palette,
    required this.dotColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeDotColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showAxisLabels,
    required this.showTooltip,
    required this.showActiveBin,
    required this.gridLineCount,
    required this.dotRadius,
    required this.dotGap,
    required this.dotOpacity,
    required this.dotValue,
    required this.valueFormatter,
    required this.countFormatter,
    required this.onBinTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleBinnedDotPlotChartView> createState() =>
      _SimpleBinnedDotPlotChartViewState();
}

class _SimpleBinnedDotPlotChartViewState
    extends State<_SimpleBinnedDotPlotChartView> {
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
                painter: _SimpleBinnedDotPlotPainter(
                  bins: widget.bins,
                  padding: widget.padding,
                  palette: widget.palette,
                  dotColor: widget.dotColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeDotColor: widget.activeDotColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showAxisLabels: widget.showAxisLabels,
                  showActiveBin: widget.showActiveBin,
                  gridLineCount: widget.gridLineCount,
                  dotRadius: widget.dotRadius,
                  dotGap: widget.dotGap,
                  dotOpacity: widget.dotOpacity,
                  dotValue: widget.dotValue,
                  valueFormatter: widget.valueFormatter,
                  countFormatter: widget.countFormatter,
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
                      if (index == null) return;
                      widget.onBinTap?.call(widget.bins[index], index);
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
    final geometry = _BinnedDotGeometry.resolve(
      size: size,
      bins: widget.bins,
      padding: widget.padding,
      dotRadius: widget.dotRadius,
      dotGap: widget.dotGap,
      dotValue: widget.dotValue,
    );
    if (!geometry.plot.contains(position)) return null;
    final index = ((position.dx - geometry.plot.left) / geometry.binWidth)
        .floor();
    if (index < 0 || index >= widget.bins.length) return null;
    return index;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final geometry = _BinnedDotGeometry.resolve(
      size: size,
      bins: widget.bins,
      padding: widget.padding,
      dotRadius: widget.dotRadius,
      dotGap: widget.dotGap,
      dotValue: widget.dotValue,
    );
    final bin = widget.bins[index];
    final range = _formatRange(bin);
    final count = widget.countFormatter(bin.count.toDouble());
    final dotCount = geometry.dotCountFor(bin);
    final dots = widget.countFormatter(dotCount.toDouble());
    final anchor = Offset(
      geometry.plot.left + geometry.binWidth * index + geometry.binWidth / 2,
      geometry.plot.top + 10,
    );
    const tooltipWidth = 176.0;
    const tooltipHeight = 76.0;
    final left = (anchor.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (anchor.dy + 4)
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
            dots,
          ) ??
          _DefaultBinnedDotTooltip(
            color: _colorFor(bin, index),
            title: range,
            count: count,
            dots: dots,
          ),
    );
  }

  Color _colorFor(SimpleBinnedDotPlotBin bin, int index) {
    return bin.color ??
        (widget.palette.isEmpty
            ? widget.dotColor
            : widget.palette[index % widget.palette.length]);
  }

  String _formatRange(SimpleBinnedDotPlotBin bin) {
    return bin.label ??
        '${widget.valueFormatter(bin.start)}-${widget.valueFormatter(bin.end)}';
  }
}

class _SimpleBinnedDotPlotPainter extends CustomPainter {
  final List<SimpleBinnedDotPlotBin> bins;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color dotColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeDotColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showAxisLabels;
  final bool showActiveBin;
  final int gridLineCount;
  final double dotRadius;
  final double dotGap;
  final double dotOpacity;
  final double dotValue;
  final SimpleBinnedDotPlotValueFormatter valueFormatter;
  final SimpleBinnedDotPlotValueFormatter countFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleBinnedDotPlotPainter({
    required this.bins,
    required this.padding,
    required this.palette,
    required this.dotColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeDotColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showAxisLabels,
    required this.showActiveBin,
    required this.gridLineCount,
    required this.dotRadius,
    required this.dotGap,
    required this.dotOpacity,
    required this.dotValue,
    required this.valueFormatter,
    required this.countFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _BinnedDotGeometry.resolve(
      size: size,
      bins: bins,
      padding: padding,
      dotRadius: dotRadius,
      dotGap: dotGap,
      dotValue: dotValue,
    );
    if (geometry.plot.isEmpty || bins.isEmpty) return;

    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawDots(canvas, geometry);
    if (showAxisLabels) _drawAxisLabels(canvas, geometry);
    if (showValues) _drawValues(canvas, geometry);
  }

  void _drawGrid(Canvas canvas, _BinnedDotGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value = geometry.maxCount * index / gridLineCount;
      final y = geometry.yForCount(value);
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
      _paintText(
        canvas,
        countFormatter(value),
        labelStyle.copyWith(
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
        ),
        Offset(geometry.plot.left - 8, y),
        TextAlign.right,
        math.max(0, padding.left - 12),
        centeredY: true,
      );
    }
  }

  void _drawAxis(Canvas canvas, _BinnedDotGeometry geometry) {
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

  void _drawDots(Canvas canvas, _BinnedDotGeometry geometry) {
    for (var binIndex = 0; binIndex < bins.length; binIndex++) {
      final bin = bins[binIndex];
      final dotCount = geometry.dotCountFor(bin);
      final x =
          geometry.plot.left +
          geometry.binWidth * binIndex +
          geometry.binWidth / 2;
      final color = _colorFor(bin, binIndex);
      final active = activeIndex == binIndex;
      for (var row = 0; row < dotCount; row++) {
        final center = Offset(
          x,
          geometry.plot.bottom -
              geometry.radius -
              row * geometry.step * progress,
        );
        canvas.drawCircle(
          center,
          geometry.radius,
          Paint()..color = color.withValues(alpha: dotOpacity),
        );
      }
      if (showActiveBin && active && dotCount > 0) {
        final top =
            geometry.plot.bottom -
            geometry.radius -
            (dotCount - 1) * geometry.step * progress;
        final rect = Rect.fromLTRB(
          x - geometry.radius - 5,
          top - geometry.radius - 5,
          x + geometry.radius + 5,
          geometry.plot.bottom + 5,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(999)),
          Paint()..color = activeDotColor.withValues(alpha: 0.12),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(999)),
          Paint()
            ..color = activeDotColor.withValues(alpha: 0.72)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawAxisLabels(Canvas canvas, _BinnedDotGeometry geometry) {
    for (var index = 0; index < bins.length; index++) {
      final bin = bins[index];
      if (bins.length > 8 && index.isOdd) continue;
      final x =
          geometry.plot.left +
          geometry.binWidth * index +
          geometry.binWidth / 2;
      _paintText(
        canvas,
        _formatRange(bin),
        labelStyle,
        Offset(x, geometry.plot.bottom + 12),
        TextAlign.center,
        math.max(28, geometry.binWidth - 4),
      );
    }
  }

  void _drawValues(Canvas canvas, _BinnedDotGeometry geometry) {
    for (var index = 0; index < bins.length; index++) {
      final bin = bins[index];
      if (bin.count == 0) continue;
      final dotCount = geometry.dotCountFor(bin);
      final x =
          geometry.plot.left +
          geometry.binWidth * index +
          geometry.binWidth / 2;
      final y =
          geometry.plot.bottom -
          geometry.radius -
          (dotCount - 1) * geometry.step * progress -
          geometry.radius -
          14;
      _paintText(
        canvas,
        countFormatter(bin.count.toDouble()),
        valueStyle,
        Offset(x, y),
        TextAlign.center,
        math.max(24, geometry.binWidth),
      );
    }
  }

  Color _colorFor(SimpleBinnedDotPlotBin bin, int index) {
    return bin.color ??
        (palette.isEmpty ? dotColor : palette[index % palette.length]);
  }

  String _formatRange(SimpleBinnedDotPlotBin bin) {
    return bin.label ??
        '${valueFormatter(bin.start)}-${valueFormatter(bin.end)}';
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

  @override
  bool shouldRepaint(covariant _SimpleBinnedDotPlotPainter oldDelegate) {
    return oldDelegate.bins != bins ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeDotColor != activeDotColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.showActiveBin != showActiveBin ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.dotGap != dotGap ||
        oldDelegate.dotOpacity != dotOpacity ||
        oldDelegate.dotValue != dotValue ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.countFormatter != countFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _BinnedDotGeometry {
  final Rect plot;
  final double binWidth;
  final double maxCount;
  final double radius;
  final double step;
  final double dotValue;

  const _BinnedDotGeometry({
    required this.plot,
    required this.binWidth,
    required this.maxCount,
    required this.radius,
    required this.step,
    required this.dotValue,
  });

  factory _BinnedDotGeometry.resolve({
    required Size size,
    required List<SimpleBinnedDotPlotBin> bins,
    required EdgeInsets padding,
    required double dotRadius,
    required double dotGap,
    required double dotValue,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0 || bins.isEmpty) {
      return _BinnedDotGeometry(
        plot: plot,
        binWidth: 0,
        maxCount: 1,
        radius: dotRadius,
        step: dotRadius * 2 + dotGap,
        dotValue: dotValue,
      );
    }
    final maxDots = bins.fold<int>(
      1,
      (maxValue, bin) => math.max(maxValue, (bin.count / dotValue).ceil()),
    );
    final radiusFromHeight = math.max(
      1.5,
      (plot.height / maxDots - dotGap) / 2,
    );
    final radiusFromWidth = math.max(1.5, plot.width / bins.length * 0.34);
    final radius = math.min(
      dotRadius,
      math.min(radiusFromHeight, radiusFromWidth),
    );
    return _BinnedDotGeometry(
      plot: plot,
      binWidth: plot.width / bins.length,
      maxCount: bins
          .map((bin) => bin.count.toDouble())
          .fold<double>(1, math.max),
      radius: radius,
      step: radius * 2 + dotGap,
      dotValue: dotValue,
    );
  }

  int dotCountFor(SimpleBinnedDotPlotBin bin) {
    if (bin.count <= 0) return 0;
    return math.max(1, (bin.count / dotValue).ceil());
  }

  double yForCount(double count) {
    if (maxCount <= 0) return plot.bottom;
    final ratio = (count / maxCount).clamp(0.0, 1.0);
    return plot.bottom - ratio * plot.height;
  }
}

class _SimpleBinnedDotPlotVisuals {
  final Color dotColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeDotColor;
  final double dotRadius;

  const _SimpleBinnedDotPlotVisuals({
    required this.dotColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeDotColor,
    required this.dotRadius,
  });

  static _SimpleBinnedDotPlotVisuals resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    final grid = colorScheme.outlineVariant.withValues(alpha: 0.55);
    final axis = colorScheme.onSurfaceVariant.withValues(alpha: 0.65);
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleBinnedDotPlotVisuals(
          dotColor: const Color(0xFF2563EB),
          gridColor: grid,
          axisColor: axis,
          activeDotColor: const Color(0xFF2563EB),
          dotRadius: 4.7,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleBinnedDotPlotVisuals(
          dotColor: const Color(0xFF0F766E),
          gridColor: grid,
          axisColor: axis,
          activeDotColor: const Color(0xFF334155),
          dotRadius: 4.4,
        );
      case SimpleBarChartStyle.education:
        return _SimpleBinnedDotPlotVisuals(
          dotColor: const Color(0xFF22C55E),
          gridColor: grid,
          axisColor: axis,
          activeDotColor: const Color(0xFFF59E0B),
          dotRadius: 4.9,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleBinnedDotPlotVisuals(
          dotColor: const Color(0xFF8B5CF6),
          gridColor: grid,
          axisColor: axis,
          activeDotColor: const Color(0xFFF43F5E),
          dotRadius: 5,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleBinnedDotPlotVisuals(
          dotColor: colorScheme.primary,
          gridColor: grid,
          axisColor: axis,
          activeDotColor: colorScheme.primary,
          dotRadius: 4.6,
        );
    }
  }
}

class _DefaultBinnedDotTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String count;
  final String dots;

  const _DefaultBinnedDotTooltip({
    required this.color,
    required this.title,
    required this.count,
    required this.dots,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _BinnedDotTooltipRow(label: 'Count', value: count),
            _BinnedDotTooltipRow(label: 'Dots', value: dots),
          ],
        ),
      ),
    );
  }
}

class _BinnedDotTooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _BinnedDotTooltipRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
