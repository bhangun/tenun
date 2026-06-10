import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleRidgelineValueFormatter = String Function(double value);
typedef SimpleRidgelineTapCallback =
    void Function(
      SimpleRidgelineChartData data,
      int index,
      SimpleRidgelineStats stats,
    );
typedef SimpleRidgelineTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleRidgelineChartData data,
      int index,
      SimpleRidgelineStats stats,
      SimpleRidgelineValueFormatter valueFormatter,
    );

class SimpleRidgelineChartData {
  final String label;
  final List<double> values;
  final Color? color;

  const SimpleRidgelineChartData({
    required this.label,
    required this.values,
    this.color,
  });
}

class SimpleRidgelineStats {
  final int count;
  final double min;
  final double median;
  final double mean;
  final double max;

  const SimpleRidgelineStats({
    required this.count,
    required this.min,
    required this.median,
    required this.mean,
    required this.max,
  });
}

/// A lightweight ridgeline chart for comparing distribution shape across
/// cohorts, periods, segments, or scenarios.
class SimpleRidgelineChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(58, 20, 18, 38);

  final List<SimpleRidgelineChartData> data;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? fillColor;
  final Color? strokeColor;
  final Color? medianColor;
  final Color? meanColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showBaseline;
  final bool showMedian;
  final bool showMean;
  final bool showTooltip;
  final bool showActiveRidge;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int densitySteps;
  final double overlap;
  final double fillOpacity;
  final double? strokeWidth;
  final SimpleRidgelineValueFormatter? valueFormatter;
  final SimpleRidgelineTapCallback? onRidgeTap;
  final SimpleRidgelineTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleRidgelineChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 270,
    this.padding = _defaultPadding,
    this.palette,
    this.fillColor,
    this.strokeColor,
    this.medianColor,
    this.meanColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showBaseline = true,
    this.showMedian = true,
    this.showMean = false,
    this.showTooltip = true,
    this.showActiveRidge = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.densitySteps = 56,
    this.overlap = 0.45,
    this.fillOpacity = 0.64,
    this.strokeWidth,
    this.valueFormatter,
    this.onRidgeTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(densitySteps >= 12),
       assert(overlap >= 0 && overlap <= 1),
       assert(fillOpacity >= 0 && fillOpacity <= 1),
       assert(strokeWidth == null || strokeWidth > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleRidgelineVisuals.resolve(style, colorScheme);
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
            emptySemanticLabel: 'Ridgeline chart, no data.',
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
          child: _SimpleRidgelineChartView(
            width: width,
            height: chartHeight,
            data: resolvedData,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: palette,
            fillColor: fillColor ?? visuals.fillColor,
            strokeColor: strokeColor ?? visuals.strokeColor,
            medianColor: medianColor ?? visuals.medianColor,
            meanColor: meanColor ?? visuals.meanColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showBaseline: showBaseline,
            showMedian: showMedian,
            showMean: showMean,
            showTooltip: showTooltip,
            showActiveRidge: showActiveRidge,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            densitySteps: densitySteps,
            overlap: overlap,
            fillOpacity: fillOpacity,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            valueFormatter: formatter,
            onRidgeTap: onRidgeTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static List<_ResolvedRidgelineData> _resolveData(
    List<SimpleRidgelineChartData> data,
  ) {
    final resolved = <_ResolvedRidgelineData>[];
    for (final item in data) {
      final values = item.values.where((value) => value.isFinite).toList()
        ..sort();
      if (values.isEmpty) {
        continue;
      }
      final mean =
          values.fold<double>(0, (sum, value) => sum + value) / values.length;
      final stats = SimpleRidgelineStats(
        count: values.length,
        min: values.first,
        median: _percentile(values, 0.5),
        mean: mean,
        max: values.last,
      );
      resolved.add(
        _ResolvedRidgelineData(source: item, values: values, stats: stats),
      );
    }
    return resolved;
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.length == 1) {
      return sorted.first;
    }
    final position = (sorted.length - 1) * p;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) {
      return sorted[lower];
    }
    final t = position - lower;
    return sorted[lower] * (1 - t) + sorted[upper] * t;
  }

  static String _defaultSemanticLabel(
    List<_ResolvedRidgelineData> data,
    SimpleRidgelineValueFormatter formatter,
  ) {
    final sample = data
        .take(4)
        .map((item) {
          final stats = item.stats;
          return '${item.source.label} count ${stats.count}, min '
              '${formatter(stats.min)}, median ${formatter(stats.median)}, max '
              '${formatter(stats.max)}';
        })
        .join(', ');
    final suffix = data.length > 4 ? ', and ${data.length - 4} more' : '';
    return 'Ridgeline chart, ${data.length} distributions. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleRidgelineChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<_ResolvedRidgelineData> data;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color fillColor;
  final Color strokeColor;
  final Color medianColor;
  final Color meanColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showBaseline;
  final bool showMedian;
  final bool showMean;
  final bool showTooltip;
  final bool showActiveRidge;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int densitySteps;
  final double overlap;
  final double fillOpacity;
  final double strokeWidth;
  final SimpleRidgelineValueFormatter valueFormatter;
  final SimpleRidgelineTapCallback? onRidgeTap;
  final SimpleRidgelineTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleRidgelineChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.fillColor,
    required this.strokeColor,
    required this.medianColor,
    required this.meanColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showBaseline,
    required this.showMedian,
    required this.showMean,
    required this.showTooltip,
    required this.showActiveRidge,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.densitySteps,
    required this.overlap,
    required this.fillOpacity,
    required this.strokeWidth,
    required this.valueFormatter,
    required this.onRidgeTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleRidgelineChartView> createState() =>
      _SimpleRidgelineChartViewState();
}

class _SimpleRidgelineChartViewState extends State<_SimpleRidgelineChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _RidgelineHit? _activeHit;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _SimpleRidgelineChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.animationCurve != widget.animationCurve) {
      _controller.duration = widget.animationDuration;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onExit: (_) => _setActive(null),
                  onHover: (event) {
                    if (widget.showActiveRidge ||
                        widget.showTooltip ||
                        widget.onRidgeTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit != null) {
                        widget.onRidgeTap?.call(
                          hit.data.source,
                          hit.index,
                          hit.data.stats,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleRidgelinePainter(
                        data: widget.data,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        fillColor: widget.fillColor,
                        strokeColor: widget.strokeColor,
                        medianColor: widget.medianColor,
                        meanColor: widget.meanColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showValues: widget.showValues,
                        showBaseline: widget.showBaseline,
                        showMedian: widget.showMedian,
                        showMean: widget.showMean,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        gridLineCount: widget.gridLineCount,
                        densitySteps: widget.densitySteps,
                        overlap: widget.overlap,
                        fillOpacity: widget.fillOpacity,
                        strokeWidth: widget.strokeWidth,
                        valueFormatter: widget.valueFormatter,
                        activeIndex: widget.showActiveRidge
                            ? _activeHit?.index
                            : null,
                        progress: _animation.value,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeHit != null)
                _buildTooltip(context, _activeHit!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_RidgelineHit? hit) {
    if (_activeHit?.index == hit?.index) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _RidgelineHit? _hitTest(Offset position) {
    final geometry = _RidgelineGeometry.resolve(
      data: widget.data,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      densitySteps: widget.densitySteps,
      overlap: widget.overlap,
    );
    for (final hit in geometry.hits) {
      if (hit.band.inflate(4).contains(position)) {
        return hit;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _RidgelineHit hit) {
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          hit.data.source,
          hit.index,
          hit.data.stats,
          widget.valueFormatter,
        ) ??
        _DefaultRidgelineTooltip(
          title: hit.data.source.label,
          rows: [
            _TooltipRow('Count', hit.data.stats.count.toString()),
            _TooltipRow('Min', widget.valueFormatter(hit.data.stats.min)),
            _TooltipRow('Median', widget.valueFormatter(hit.data.stats.median)),
            _TooltipRow('Mean', widget.valueFormatter(hit.data.stats.mean)),
            _TooltipRow('Max', widget.valueFormatter(hit.data.stats.max)),
          ],
        );
    final left = (hit.band.right - 164).clamp(8.0, widget.width - 176);
    final top = (hit.baselineY - 62).clamp(8.0, widget.height - 140);

    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleRidgelinePainter extends CustomPainter {
  final List<_ResolvedRidgelineData> data;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color fillColor;
  final Color strokeColor;
  final Color medianColor;
  final Color meanColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showBaseline;
  final bool showMedian;
  final bool showMean;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final int densitySteps;
  final double overlap;
  final double fillOpacity;
  final double strokeWidth;
  final SimpleRidgelineValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleRidgelinePainter({
    required this.data,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.fillColor,
    required this.strokeColor,
    required this.medianColor,
    required this.meanColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showBaseline,
    required this.showMedian,
    required this.showMean,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.densitySteps,
    required this.overlap,
    required this.fillOpacity,
    required this.strokeWidth,
    required this.valueFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }
    final geometry = _RidgelineGeometry.resolve(
      data: data,
      size: size,
      padding: padding,
      minValue: minValue,
      maxValue: maxValue,
      densitySteps: densitySteps,
      overlap: overlap,
    );
    if (geometry.plot.width <= 0 || geometry.plot.height <= 0) {
      return;
    }

    _drawReferenceBands(canvas, geometry);
    _drawGridAndAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    for (var i = geometry.hits.length - 1; i >= 0; i--) {
      _drawRidge(canvas, geometry, geometry.hits[i]);
    }
  }

  void _drawGridAndAxis(Canvas canvas, _RidgelineGeometry geometry) {
    final plot = geometry.plot;
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (var i = 0; i <= gridLineCount; i++) {
      final ratio = i / gridLineCount;
      final x = plot.left + ratio * plot.width;
      final value = geometry.minValue + ratio * geometry.valueSpan;
      if (showGrid) {
        canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      }
      _drawText(
        canvas,
        valueFormatter(value),
        Rect.fromLTWH(x - 26, plot.bottom + 8, 52, 16),
        labelStyle,
        align: TextAlign.center,
      );
    }
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
  }

  void _drawReferenceBands(Canvas canvas, _RidgelineGeometry geometry) {
    for (final band in referenceBands) {
      final left = geometry.xForValue(math.min(band.from, band.to));
      final right = geometry.xForValue(math.max(band.from, band.to));
      final color = band.color ?? activeColor;
      final rect = Rect.fromLTRB(
        left.clamp(geometry.plot.left, geometry.plot.right),
        geometry.plot.top,
        right.clamp(geometry.plot.left, geometry.plot.right),
        geometry.plot.bottom,
      );
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      if (band.showLabel && band.label != null) {
        _drawText(
          canvas,
          band.label!,
          Rect.fromLTWH(rect.left + 4, geometry.plot.top + 4, rect.width, 16),
          labelStyle.copyWith(color: color),
        );
      }
    }
  }

  void _drawReferenceLines(Canvas canvas, _RidgelineGeometry geometry) {
    for (final line in referenceLines) {
      final x = geometry.xForValue(line.value);
      final color = line.color ?? activeColor;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = line.strokeWidth;
      final start = Offset(x, geometry.plot.top);
      final end = Offset(x, geometry.plot.bottom);
      switch (line.lineStyle) {
        case SimpleChartReferenceLineStyle.solid:
          canvas.drawLine(start, end, paint);
        case SimpleChartReferenceLineStyle.dashed:
          _drawDashedLine(canvas, start, end, paint, dash: 6, gap: 5);
        case SimpleChartReferenceLineStyle.dotted:
          _drawDashedLine(canvas, start, end, paint, dash: 1, gap: 4);
      }
      if (line.showLabel && line.label != null) {
        _drawText(
          canvas,
          line.label!,
          Rect.fromLTWH(x + 4, geometry.plot.top + 4, 58, 16),
          labelStyle.copyWith(color: color),
        );
      }
    }
  }

  void _drawRidge(
    Canvas canvas,
    _RidgelineGeometry geometry,
    _RidgelineHit hit,
  ) {
    final color = _ridgeColor(hit.data.source, hit.index);
    final active = activeIndex == hit.index;
    final fillPaint = Paint()
      ..color = (active ? activeColor : color).withValues(alpha: fillOpacity)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = active ? activeColor : strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? strokeWidth + 0.8 : strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final baselinePaint = Paint()
      ..color = axisColor.withValues(alpha: 0.44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(geometry.plot.left, hit.baselineY)
      ..lineTo(geometry.plot.left, hit.baselineY);
    for (final point in hit.density) {
      path.lineTo(
        geometry.xForValue(point.x),
        hit.baselineY - point.normalized * hit.amplitude * progress,
      );
    }
    path.lineTo(geometry.plot.right, hit.baselineY);
    path.close();

    if (showBaseline) {
      canvas.drawLine(
        Offset(geometry.plot.left, hit.baselineY),
        Offset(geometry.plot.right, hit.baselineY),
        baselinePaint,
      );
    }
    canvas.drawPath(path, fillPaint);

    final linePath = Path();
    for (var i = 0; i < hit.density.length; i++) {
      final point = hit.density[i];
      final offset = Offset(
        geometry.xForValue(point.x),
        hit.baselineY - point.normalized * hit.amplitude * progress,
      );
      if (i == 0) {
        linePath.moveTo(offset.dx, offset.dy);
      } else {
        linePath.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(linePath, strokePaint);

    _drawText(
      canvas,
      hit.data.source.label,
      Rect.fromLTWH(padding.left - 54, hit.baselineY - 12, 48, 18),
      labelStyle,
      align: TextAlign.right,
    );

    if (showMedian) {
      _drawStatisticMarker(
        canvas,
        geometry,
        hit,
        hit.data.stats.median,
        medianColor,
      );
    }
    if (showMean) {
      _drawStatisticMarker(
        canvas,
        geometry,
        hit,
        hit.data.stats.mean,
        meanColor,
        dashed: true,
      );
    }
    if (showValues) {
      _drawText(
        canvas,
        valueFormatter(hit.data.stats.median),
        Rect.fromLTWH(
          geometry.xForValue(hit.data.stats.median) - 24,
          hit.baselineY + 4,
          48,
          16,
        ),
        valueStyle,
        align: TextAlign.center,
      );
    }
  }

  void _drawStatisticMarker(
    Canvas canvas,
    _RidgelineGeometry geometry,
    _RidgelineHit hit,
    double value,
    Color color, {
    bool dashed = false,
  }) {
    final x = geometry.xForValue(value);
    final top = hit.baselineY - hit.amplitude * 0.82;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (dashed) {
      _drawDashedLine(
        canvas,
        Offset(x, top),
        Offset(x, hit.baselineY),
        paint,
        dash: 4,
        gap: 4,
      );
    } else {
      canvas.drawLine(Offset(x, top), Offset(x, hit.baselineY), paint);
    }
  }

  Color _ridgeColor(SimpleRidgelineChartData item, int index) {
    if (item.color != null) {
      return item.color!;
    }
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return fillColor;
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final total = (end - start).distance;
    if (total <= 0) {
      return;
    }
    final direction = (end - start) / total;
    var distance = 0.0;
    while (distance < total) {
      final segmentStart = start + direction * distance;
      final segmentEnd = start + direction * math.min(distance + dash, total);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      distance += dash + gap;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: rect.width);
    final dx = switch (align) {
      TextAlign.right => rect.right - painter.width,
      TextAlign.center => rect.left + (rect.width - painter.width) / 2,
      _ => rect.left,
    };
    final dy = rect.top + (rect.height - painter.height) / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _SimpleRidgelinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.medianColor != medianColor ||
        oldDelegate.meanColor != meanColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showBaseline != showBaseline ||
        oldDelegate.showMedian != showMedian ||
        oldDelegate.showMean != showMean ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.densitySteps != densitySteps ||
        oldDelegate.overlap != overlap ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _RidgelineGeometry {
  final Rect plot;
  final double minValue;
  final double maxValue;
  final double valueSpan;
  final List<_RidgelineHit> hits;

  const _RidgelineGeometry({
    required this.plot,
    required this.minValue,
    required this.maxValue,
    required this.valueSpan,
    required this.hits,
  });

  factory _RidgelineGeometry.resolve({
    required List<_ResolvedRidgelineData> data,
    required Size size,
    required EdgeInsets padding,
    required double? minValue,
    required double? maxValue,
    required int densitySteps,
    required double overlap,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final allValues = data.expand((item) => item.values).toList();
    final dataMin = allValues.reduce(math.min);
    final dataMax = allValues.reduce(math.max);
    final span = math.max(1e-9, dataMax - dataMin);
    final resolvedMin = minValue ?? dataMin - span * 0.04;
    final resolvedMax = math.max(
      maxValue ?? dataMax + span * 0.04,
      resolvedMin + 1e-9,
    );
    final valueSpan = resolvedMax - resolvedMin;
    final rowHeight = plot.height / data.length;
    final amplitude = rowHeight * (0.58 + overlap * 0.34);
    final hits = <_RidgelineHit>[];

    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final baselineY = plot.top + rowHeight * (index + 0.82);
      final density = _densityFor(
        values: item.values,
        minValue: resolvedMin,
        maxValue: resolvedMax,
        steps: densitySteps,
      );
      final band = Rect.fromLTRB(
        plot.left,
        math.max(plot.top, baselineY - amplitude - 8),
        plot.right,
        math.min(plot.bottom, baselineY + 20),
      );
      hits.add(
        _RidgelineHit(
          data: item,
          index: index,
          density: density,
          baselineY: baselineY,
          amplitude: amplitude,
          band: band,
        ),
      );
    }

    return _RidgelineGeometry(
      plot: plot,
      minValue: resolvedMin,
      maxValue: resolvedMax,
      valueSpan: valueSpan,
      hits: hits,
    );
  }

  double xForValue(double value) {
    final normalized = ((value - minValue) / valueSpan).clamp(0.0, 1.0);
    return plot.left + normalized * plot.width;
  }

  static List<_DensityPoint> _densityFor({
    required List<double> values,
    required double minValue,
    required double maxValue,
    required int steps,
  }) {
    if (values.isEmpty) {
      return const [];
    }
    final mean =
        values.fold<double>(0, (sum, value) => sum + value) / values.length;
    final variance =
        values.fold<double>(
          0,
          (sum, value) => sum + math.pow(value - mean, 2).toDouble(),
        ) /
        values.length;
    final stdDev = math.sqrt(variance).clamp(0.01, double.infinity);
    final bandwidth = math.max(
      stdDev * math.pow(values.length, -0.2) * 1.06,
      (maxValue - minValue).abs() / math.max(steps, 1) * 1.5,
    );
    final points = <_DensityPoint>[];
    var maxDensity = 0.0;

    for (var i = 0; i <= steps; i++) {
      final x = minValue + (i / steps) * (maxValue - minValue);
      var density = 0.0;
      for (final value in values) {
        final z = (x - value) / bandwidth;
        density += math.exp(-0.5 * z * z);
      }
      density = density / (values.length * bandwidth * math.sqrt(2 * math.pi));
      maxDensity = math.max(maxDensity, density);
      points.add(_DensityPoint(x: x, density: density, normalized: 0));
    }

    if (maxDensity <= 0) {
      return points;
    }
    return [
      for (final point in points)
        _DensityPoint(
          x: point.x,
          density: point.density,
          normalized: point.density / maxDensity,
        ),
    ];
  }
}

class _ResolvedRidgelineData {
  final SimpleRidgelineChartData source;
  final List<double> values;
  final SimpleRidgelineStats stats;

  const _ResolvedRidgelineData({
    required this.source,
    required this.values,
    required this.stats,
  });
}

class _DensityPoint {
  final double x;
  final double density;
  final double normalized;

  const _DensityPoint({
    required this.x,
    required this.density,
    required this.normalized,
  });
}

class _RidgelineHit {
  final _ResolvedRidgelineData data;
  final int index;
  final List<_DensityPoint> density;
  final double baselineY;
  final double amplitude;
  final Rect band;

  const _RidgelineHit({
    required this.data,
    required this.index,
    required this.density,
    required this.baselineY,
    required this.amplitude,
    required this.band,
  });
}

class _SimpleRidgelineVisuals {
  final Color fillColor;
  final Color strokeColor;
  final Color medianColor;
  final Color meanColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double strokeWidth;

  const _SimpleRidgelineVisuals({
    required this.fillColor,
    required this.strokeColor,
    required this.medianColor,
    required this.meanColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.strokeWidth,
  });

  factory _SimpleRidgelineVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleRidgelineVisuals(
          fillColor: colorScheme.primary,
          strokeColor: colorScheme.primary,
          medianColor: colorScheme.tertiary,
          meanColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          activeColor: colorScheme.tertiary,
          strokeWidth: 2.2,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleRidgelineVisuals(
          fillColor: colorScheme.primary,
          strokeColor: colorScheme.primary,
          medianColor: colorScheme.error,
          meanColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          activeColor: colorScheme.onSurface,
          strokeWidth: 1.8,
        );
      case SimpleBarChartStyle.education:
        return _SimpleRidgelineVisuals(
          fillColor: colorScheme.secondary,
          strokeColor: colorScheme.secondary,
          medianColor: colorScheme.primary,
          meanColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          activeColor: colorScheme.primary,
          strokeWidth: 2,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleRidgelineVisuals(
          fillColor: colorScheme.tertiary,
          strokeColor: colorScheme.tertiary,
          medianColor: colorScheme.primary,
          meanColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          activeColor: colorScheme.primary,
          strokeWidth: 2.4,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleRidgelineVisuals(
          fillColor: colorScheme.primary,
          strokeColor: colorScheme.primary,
          medianColor: colorScheme.tertiary,
          meanColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: colorScheme.tertiary,
          strokeWidth: 2,
        );
    }
  }
}

class _DefaultRidgelineTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultRidgelineTooltip({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: DefaultTextStyle(
          style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final row in rows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 56, child: Text(row.label)),
                    Text(
                      row.value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TooltipRow {
  final String label;
  final String value;

  const _TooltipRow(this.label, this.value);
}
