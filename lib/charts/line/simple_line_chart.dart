import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleTrendValueFormatter = String Function(double value);
typedef SimpleTrendTooltipBuilder =
    Widget Function(
      BuildContext context,
      String label,
      List<SimpleTrendTooltipItem> items,
    );
typedef SimpleTrendPointTapCallback =
    void Function(String label, List<SimpleTrendTooltipItem> items, int index);

enum SimpleTrendChartStyle { elegant, modern, professional, education, trendy }

enum SimpleTrendLineStyle { solid, dashed, dotted }

class SimpleTrendPoint {
  final String label;
  final double value;

  const SimpleTrendPoint({required this.label, required this.value});
}

class SimpleTrendSeries {
  final String? name;
  final List<SimpleTrendPoint> points;
  final Color? color;
  final double? strokeWidth;
  final SimpleTrendLineStyle lineStyle;

  const SimpleTrendSeries({
    this.name,
    required this.points,
    this.color,
    this.strokeWidth,
    this.lineStyle = SimpleTrendLineStyle.solid,
  });
}

class SimpleTrendTooltipItem {
  final String seriesName;
  final double value;
  final Color color;

  const SimpleTrendTooltipItem({
    required this.seriesName,
    required this.value,
    required this.color,
  });
}

/// A compact line chart for product UI, dashboards, lessons, and reports.
class SimpleLineChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(48, 18, 18, 34);

  final List<SimpleTrendSeries> series;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? lineColor;
  final Color? fillColor;
  final Color? gridColor;
  final Color? axisColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final bool showLegend;
  final bool showTooltip;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final bool? smooth;
  final double? strokeWidth;
  final double? dotRadius;
  final double? fillOpacity;
  final int gridLineCount;
  final SimpleTrendValueFormatter? valueFormatter;
  final SimpleTrendPointTapCallback? onPointTap;
  final SimpleTrendTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleLineChart({
    super.key,
    required this.series,
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 240,
    this.padding = _defaultPadding,
    this.lineColor,
    this.fillColor,
    this.gridColor,
    this.axisColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showDots = true,
    this.showValues = true,
    this.showArea = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.smooth,
    this.strokeWidth,
    this.dotRadius,
    this.fillOpacity,
    this.gridLineCount = 4,
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
       assert(strokeWidth == null || strokeWidth > 0),
       assert(dotRadius == null || dotRadius >= 0),
       assert(fillOpacity == null || (fillOpacity >= 0 && fillOpacity <= 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleTrendVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .where((item) => item.points.any((point) => point.value.isFinite))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;
        final resolvedValueFormatter = valueFormatter ?? _defaultValueFormatter;

        if (visibleSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: '${showArea ? 'Area' : 'Line'} chart, no data.',
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
            visibleSeries,
            resolvedValueFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleTrendChartView(
            width: width,
            height: chartHeight,
            series: visibleSeries,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(visuals.palette),
            fillColor: fillColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeZero: includeZero,
            showGrid: showGrid,
            showDots: showDots,
            showValues: showValues,
            showArea: showArea,
            showLegend: showLegend,
            showTooltip: showTooltip,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            smooth: smooth ?? visuals.smooth,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            dotRadius: dotRadius ?? visuals.dotRadius,
            fillOpacity: fillOpacity ?? visuals.fillOpacity,
            useGradient: visuals.useGradient,
            gridLineCount: gridLineCount,
            valueFormatter: resolvedValueFormatter,
            onPointTap: onPointTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(
    List<SimpleTrendSeries> visibleSeries,
    SimpleTrendValueFormatter formatter,
  ) {
    final chartKind = showArea ? 'Area chart' : 'Line chart';
    final seriesCount = visibleSeries.length;
    final seriesLabel = seriesCount == 1 ? 'series' : 'series';
    final summaries = visibleSeries
        .take(3)
        .map((item) {
          final name = item.name ?? 'Series ${visibleSeries.indexOf(item) + 1}';
          final finitePoints = item.points
              .where((point) => point.value.isFinite)
              .toList();
          final points = finitePoints
              .take(4)
              .map((point) {
                return '${point.label} ${formatter(point.value)}';
              })
              .join(', ');
          final remaining =
              finitePoints.length - math.min(finitePoints.length, 4);
          final suffix = remaining > 0 ? ', and $remaining more' : '';
          return '$name: $points$suffix';
        })
        .join('; ');
    final remainingSeries =
        visibleSeries.length - math.min(visibleSeries.length, 3);
    final suffix = remainingSeries > 0
        ? '; and $remainingSeries more series'
        : '';
    return '$chartKind, $seriesCount $seriesLabel. $summaries$suffix.';
  }

  List<Color> _resolvePalette(List<Color> defaults) {
    if (lineColor == null) return defaults;
    return [lineColor!, ...defaults.skip(1)];
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleTrendChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleTrendSeries> series;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? fillColor;
  final Color gridColor;
  final Color axisColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final bool showLegend;
  final bool showTooltip;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final bool smooth;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;
  final bool useGradient;
  final int gridLineCount;
  final SimpleTrendValueFormatter valueFormatter;
  final SimpleTrendPointTapCallback? onPointTap;
  final SimpleTrendTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleTrendChartView({
    required this.width,
    required this.height,
    required this.series,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.fillColor,
    required this.gridColor,
    required this.axisColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showDots,
    required this.showValues,
    required this.showArea,
    required this.showLegend,
    required this.showTooltip,
    required this.referenceLines,
    required this.referenceBands,
    required this.smooth,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
    required this.useGradient,
    required this.gridLineCount,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleTrendChartView> createState() => _SimpleTrendChartViewState();
}

class _SimpleTrendChartViewState extends State<_SimpleTrendChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final hasLegend = widget.showLegend && widget.series.length > 1;
    final interactionEnabled = widget.showTooltip || widget.onPointTap != null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final chart = TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: widget.animationDuration,
                  curve: widget.animationCurve,
                  builder: (context, progress, child) {
                    return CustomPaint(
                      painter: _SimpleTrendChartPainter(
                        series: widget.series,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        fillColor: widget.fillColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        includeZero: widget.includeZero,
                        showGrid: widget.showGrid,
                        showDots: widget.showDots,
                        showValues: widget.showValues,
                        showArea: widget.showArea,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        smooth: widget.smooth,
                        strokeWidth: widget.strokeWidth,
                        dotRadius: widget.dotRadius,
                        fillOpacity: widget.fillOpacity,
                        useGradient: widget.useGradient,
                        gridLineCount: widget.gridLineCount,
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
                        onHover: (event) =>
                            _setActive(_hitTest(event.localPosition, size)),
                        onExit: (_) => _setActive(null),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            final index = _hitTest(details.localPosition, size);
                            _setActive(index);
                            if (index == null) return;

                            final rows = _tooltipItems(index);
                            if (rows.isEmpty) return;
                            widget.onPointTap?.call(
                              _labelFor(index),
                              rows,
                              index,
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
          ),
          if (hasLegend) _buildLegend(context),
        ],
      ),
    );
  }

  void _setActive(int? index) {
    if (_activeIndex == index) return;
    setState(() => _activeIndex = index);
  }

  int? _hitTest(Offset position, Size size) {
    final plot = _plot(size);
    if (!plot.inflate(8).contains(position)) return null;
    final count = _maxPointCount();
    if (count == 0) return null;
    if (count == 1) return 0;

    final relative = ((position.dx - plot.left) / plot.width).clamp(0.0, 1.0);
    return (relative * (count - 1)).round();
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final label = _labelFor(index);
    final rows = _tooltipItems(index);
    if (rows.isEmpty) return const SizedBox.shrink();

    final plot = _plot(size);
    final count = _maxPointCount();
    final x = count <= 1
        ? plot.center.dx
        : plot.left + (index / (count - 1)) * plot.width;
    const tooltipWidth = 184.0;
    final top = widget.padding.top + 6;
    final left = (x + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(context, label, rows) ??
          _DefaultTrendTooltip(
            title: label,
            rows: rows
                .map(
                  (item) => _TrendTooltipRow(
                    color: item.color,
                    label: item.seriesName,
                    value: widget.valueFormatter(item.value),
                  ),
                )
                .toList(),
          ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: [
          for (var index = 0; index < widget.series.length; index++)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 12,
                    child: CustomPaint(
                      painter: _TrendLegendSwatchPainter(
                        color: _seriesColor(index),
                        lineStyle: widget.series[index].lineStyle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.series[index].name ?? 'Series ${index + 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.labelStyle.copyWith(
                        color:
                            widget.labelStyle.color ??
                            colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<SimpleTrendTooltipItem> _tooltipItems(int pointIndex) {
    final items = <SimpleTrendTooltipItem>[];
    for (var index = 0; index < widget.series.length; index++) {
      final series = widget.series[index];
      if (pointIndex >= series.points.length) continue;
      final point = series.points[pointIndex];
      if (!point.value.isFinite) continue;
      items.add(
        SimpleTrendTooltipItem(
          seriesName: series.name ?? 'Series ${index + 1}',
          value: point.value,
          color: _seriesColor(index),
        ),
      );
    }
    return items;
  }

  String _labelFor(int index) {
    for (final series in widget.series) {
      if (index < series.points.length) {
        return series.points[index].label;
      }
    }
    return 'Point ${index + 1}';
  }

  int _maxPointCount() {
    return widget.series.fold<int>(
      0,
      (count, series) => math.max(count, series.points.length),
    );
  }

  Color _seriesColor(int index) {
    return widget.series[index].color ??
        widget.palette[index % widget.palette.length];
  }

  Rect _plot(Size size) {
    return Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }
}

class _SimpleTrendChartPainter extends CustomPainter {
  final List<SimpleTrendSeries> series;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? fillColor;
  final Color gridColor;
  final Color axisColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final bool smooth;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;
  final bool useGradient;
  final int gridLineCount;
  final SimpleTrendValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleTrendChartPainter({
    required this.series,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.fillColor,
    required this.gridColor,
    required this.axisColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showDots,
    required this.showValues,
    required this.showArea,
    required this.referenceLines,
    required this.referenceBands,
    required this.smooth,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
    required this.useGradient,
    required this.gridLineCount,
    required this.valueFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final range = _resolveRange();
    final baselineY = includeZero
        ? _yForValue(0, plot, range).clamp(plot.top, plot.bottom).toDouble()
        : plot.bottom;

    _drawReferenceBands(canvas, plot, range);
    if (showGrid) {
      _drawGrid(canvas, plot, range);
    }
    _drawAxis(canvas, plot, baselineY);
    _drawReferenceLines(canvas, plot, range);
    _drawActiveGuide(canvas, plot);
    _drawLabels(canvas, plot);

    for (var index = 0; index < series.length; index++) {
      _drawSeries(canvas, plot, range, baselineY, series[index], index);
    }
  }

  _ValueRange _resolveRange() {
    var lower = double.infinity;
    var upper = double.negativeInfinity;

    for (final item in series) {
      for (final point in item.points) {
        if (!point.value.isFinite) continue;
        lower = math.min(lower, point.value);
        upper = math.max(upper, point.value);
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

    if (includeZero) {
      lower = math.min(0.0, lower);
      upper = math.max(0.0, upper);
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
    } else {
      final pad = (upper - lower).abs() * 0.08;
      lower -= pad;
      upper += pad;
    }

    return _ValueRange(lower, upper);
  }

  double _xForIndex(int index, int count, Rect plot) {
    if (count <= 1) return plot.center.dx;
    return plot.left + (index / (count - 1)) * plot.width;
  }

  double _yForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  void _drawGrid(Canvas canvas, Rect plot, _ValueRange range) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index <= gridLineCount; index++) {
      final value = range.min + range.span * (index / gridLineCount);
      final y = _yForValue(value, plot, range);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);

      final painter = _textPainter(
        valueFormatter(value),
        labelStyle.copyWith(color: labelStyle.color?.withValues(alpha: 0.72)),
        maxWidth: padding.left - 10,
        textAlign: TextAlign.right,
      )..layout(maxWidth: padding.left - 10);
      painter.paint(
        canvas,
        Offset(plot.left - painter.width - 8, y - painter.height / 2),
      );
    }
  }

  void _drawAxis(Canvas canvas, Rect plot, double baselineY) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(plot.left, baselineY),
      Offset(plot.right, baselineY),
      axisPaint,
    );
  }

  void _drawReferenceBands(Canvas canvas, Rect plot, _ValueRange range) {
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;

      final y1 = _yForValue(band.from, plot, range);
      final y2 = _yForValue(band.to, plot, range);
      final top = math.min(y1, y2);
      final bottom = math.max(y1, y2);
      if (bottom < plot.top || top > plot.bottom) continue;

      final rect = Rect.fromLTRB(
        plot.left,
        math.max(plot.top, top),
        plot.right,
        math.min(plot.bottom, bottom),
      );
      if (rect.height <= 0.5) continue;

      final color = band.color ?? palette.first;
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      _drawBandLabel(canvas, band, rect.topRight, plot, color);
    }
  }

  void _drawBandLabel(
    Canvas canvas,
    SimpleChartReferenceBand band,
    Offset anchor,
    Rect plot,
    Color color,
  ) {
    if (!band.showLabel) return;

    final text = band.label ?? _bandFallbackLabel(band);
    final maxWidth = math.min(128.0, plot.width);
    final painter = _textPainter(
      text,
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.9,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: maxWidth,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + padding.horizontal;
    final height = painter.height + padding.vertical;
    final x = _safeClamp(
      anchor.dx - width - 6,
      plot.left + 2,
      plot.right - width - 2,
    );
    final y = _safeClamp(anchor.dy + 4, plot.top + 2, plot.bottom - height - 2);
    final rect = Rect.fromLTWH(x, y, width, height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = color.withValues(alpha: 0.14),
    );
    painter.paint(canvas, Offset(x + padding.left, y + padding.top));
  }

  String _bandFallbackLabel(SimpleChartReferenceBand band) {
    return '${valueFormatter(band.from)} - ${valueFormatter(band.to)}';
  }

  void _drawReferenceLines(Canvas canvas, Rect plot, _ValueRange range) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final y = _yForValue(line.value, plot, range);
      if (y < plot.top - 1 || y > plot.bottom + 1) continue;

      final color = line.color ?? axisColor.withValues(alpha: 0.82);
      _drawStyledLine(
        canvas,
        Offset(plot.left, y),
        Offset(plot.right, y),
        _referencePaint(line, color),
        line.lineStyle,
      );
      _drawReferenceLabel(
        canvas,
        line,
        valueFormatter(line.value),
        Offset(plot.right, y),
        plot,
        color,
      );
    }
  }

  Paint _referencePaint(SimpleChartReferenceLine line, Color color) {
    return Paint()
      ..color = color
      ..strokeWidth = line.strokeWidth
      ..strokeCap = line.lineStyle == SimpleChartReferenceLineStyle.dotted
          ? StrokeCap.round
          : StrokeCap.butt;
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
    final gap = style == SimpleChartReferenceLineStyle.dotted ? 5.0 : 5.0;
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

  void _drawReferenceLabel(
    Canvas canvas,
    SimpleChartReferenceLine line,
    String fallbackLabel,
    Offset anchor,
    Rect plot,
    Color color,
  ) {
    if (!line.showLabel) return;

    final text = line.label ?? fallbackLabel;
    final painter = _textPainter(
      text,
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.92,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: math.min(112.0, plot.width),
      textAlign: TextAlign.center,
    )..layout(maxWidth: math.min(112.0, plot.width));
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + padding.horizontal;
    final height = painter.height + padding.vertical;
    final x = _safeClamp(
      anchor.dx - width - 6,
      plot.left + 2,
      plot.right - width - 2,
    );
    final y = _safeClamp(
      anchor.dy - height - 4,
      plot.top + 2,
      plot.bottom - height - 2,
    );
    final rect = Rect.fromLTWH(x, y, width, height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = color.withValues(alpha: 0.1),
    );
    painter.paint(canvas, Offset(x + padding.left, y + padding.top));
  }

  double _safeClamp(double value, double lower, double upper) {
    if (lower > upper) return lower;
    return value.clamp(lower, upper).toDouble();
  }

  void _drawLabels(Canvas canvas, Rect plot) {
    final labels = _labels();
    if (labels.isEmpty) return;

    final maxLabelCount = math.max(1, plot.width / 54).floor();
    final labelEvery = math.max(1, (labels.length / maxLabelCount).ceil());

    for (var index = 0; index < labels.length; index++) {
      if (index % labelEvery != 0) continue;

      final x = _xForIndex(index, labels.length, plot);
      final maxWidth = labels.length <= 1
          ? plot.width
          : math.max(24.0, plot.width / (labels.length - 1) * 0.9);
      final painter = _textPainter(
        labels[index],
        labelStyle,
        maxWidth: maxWidth,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x - painter.width / 2, plot.bottom + 8));
    }
  }

  void _drawSeries(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
    double baselineY,
    SimpleTrendSeries item,
    int seriesIndex,
  ) {
    final points = <Offset>[];
    final source = item.points;
    if (source.isEmpty) return;

    for (var index = 0; index < source.length; index++) {
      final point = source[index];
      if (!point.value.isFinite) continue;

      final x = _xForIndex(index, source.length, plot);
      final targetY = _yForValue(point.value, plot, range);
      final y = baselineY + (targetY - baselineY) * progress;
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    final color = item.color ?? palette[seriesIndex % palette.length];
    final linePath = _linePath(points);

    if (showArea) {
      _drawArea(canvas, linePath, points, plot, baselineY, color);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = item.strokeWidth ?? strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _drawStyledPath(canvas, linePath, paint, item.lineStyle);

    if (showDots) {
      _drawDots(canvas, points, color);
    }
    _drawActivePoint(canvas, plot, range, baselineY, source, color);
    if (showValues) {
      _drawEndValue(canvas, source, points, color, plot);
    }
  }

  void _drawActiveGuide(Canvas canvas, Rect plot) {
    final index = activeIndex;
    final count = _labels().length;
    if (index == null || index < 0 || index >= count) return;

    final x = _xForIndex(index, count, plot);
    canvas.drawLine(
      Offset(x, plot.top),
      Offset(x, plot.bottom),
      Paint()
        ..color = axisColor.withValues(alpha: 0.38)
        ..strokeWidth = 1,
    );
  }

  Path _linePath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (smooth && points.length > 1) {
      for (var index = 0; index < points.length - 1; index++) {
        final current = points[index];
        final next = points[index + 1];
        final distance = (next.dx - current.dx) * 0.42;
        path.cubicTo(
          current.dx + distance,
          current.dy,
          next.dx - distance,
          next.dy,
          next.dx,
          next.dy,
        );
      }
    } else {
      for (var index = 1; index < points.length; index++) {
        path.lineTo(points[index].dx, points[index].dy);
      }
    }
    return path;
  }

  void _drawStyledPath(
    Canvas canvas,
    Path path,
    Paint paint,
    SimpleTrendLineStyle style,
  ) {
    if (style == SimpleTrendLineStyle.solid) {
      canvas.drawPath(path, paint);
      return;
    }

    final dash = style == SimpleTrendLineStyle.dotted ? 1.0 : 8.0;
    final gap = style == SimpleTrendLineStyle.dotted ? 6.0 : 6.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  void _drawArea(
    Canvas canvas,
    Path linePath,
    List<Offset> points,
    Rect plot,
    double baselineY,
    Color seriesColor,
  ) {
    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, baselineY)
      ..lineTo(points.first.dx, baselineY)
      ..close();
    final color = fillColor ?? seriesColor;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: useGradient
            ? [
                color.withValues(alpha: fillOpacity),
                color.withValues(alpha: fillOpacity * 0.16),
              ]
            : [
                color.withValues(alpha: fillOpacity),
                color.withValues(alpha: fillOpacity),
              ],
      ).createShader(plot);
    canvas.drawPath(areaPath, paint);
  }

  void _drawDots(Canvas canvas, List<Offset> points, Color color) {
    if (dotRadius <= 0) return;
    if (points.length > 24) {
      canvas.drawCircle(points.last, dotRadius + 1.5, Paint()..color = color);
      canvas.drawCircle(points.last, dotRadius, Paint()..color = Colors.white);
      return;
    }

    for (final point in points) {
      canvas.drawCircle(
        point,
        dotRadius + 1.5,
        Paint()..color = color.withValues(alpha: 0.24),
      );
      canvas.drawCircle(point, dotRadius, Paint()..color = color);
    }
  }

  void _drawActivePoint(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
    double baselineY,
    List<SimpleTrendPoint> source,
    Color color,
  ) {
    final index = activeIndex;
    if (index == null || index < 0 || index >= source.length) return;
    final value = source[index].value;
    if (!value.isFinite) return;

    final x = _xForIndex(index, source.length, plot);
    final targetY = _yForValue(value, plot, range);
    final y = baselineY + (targetY - baselineY) * progress;
    final point = Offset(x, y);
    canvas.drawCircle(
      point,
      dotRadius + 4,
      Paint()..color = color.withValues(alpha: 0.18),
    );
    canvas.drawCircle(point, dotRadius + 1.5, Paint()..color = color);
    canvas.drawCircle(point, dotRadius, Paint()..color = Colors.white);
  }

  void _drawEndValue(
    Canvas canvas,
    List<SimpleTrendPoint> source,
    List<Offset> points,
    Color color,
    Rect plot,
  ) {
    final lastValue = source.lastWhere((point) => point.value.isFinite).value;
    final painter = _textPainter(
      valueFormatter(lastValue),
      valueStyle.copyWith(color: valueStyle.color ?? color),
    )..layout();
    final anchor = points.last;
    final x = _safeClamp(
      anchor.dx + 8,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = _safeClamp(
      anchor.dy - painter.height / 2,
      plot.top + 2,
      plot.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
  }

  List<String> _labels() {
    SimpleTrendSeries? longest;
    for (final item in series) {
      if (longest == null || item.points.length > longest.points.length) {
        longest = item;
      }
    }
    return longest?.points.map((point) => point.label).toList() ?? const [];
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
  bool shouldRepaint(covariant _SimpleTrendChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeZero != includeZero ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showDots != showDots ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showArea != showArea ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.smooth != smooth ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.useGradient != useGradient ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _SimpleTrendVisuals {
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;
  final bool smooth;
  final bool useGradient;

  const _SimpleTrendVisuals({
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
    required this.smooth,
    required this.useGradient,
  });

  factory _SimpleTrendVisuals.resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    final palette = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];

    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleTrendVisuals(
          palette: palette,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          strokeWidth: 3,
          dotRadius: 3.5,
          fillOpacity: 0.22,
          smooth: true,
          useGradient: true,
        );
      case SimpleTrendChartStyle.professional:
        return _SimpleTrendVisuals(
          palette: palette,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.72),
          strokeWidth: 2.2,
          dotRadius: 2.5,
          fillOpacity: 0.14,
          smooth: false,
          useGradient: false,
        );
      case SimpleTrendChartStyle.education:
        return _SimpleTrendVisuals(
          palette: [colorScheme.secondary, ...palette],
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.65),
          strokeWidth: 2.6,
          dotRadius: 4,
          fillOpacity: 0.18,
          smooth: false,
          useGradient: false,
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleTrendVisuals(
          palette: [colorScheme.tertiary, ...palette],
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          strokeWidth: 3.4,
          dotRadius: 3.5,
          fillOpacity: 0.26,
          smooth: true,
          useGradient: true,
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleTrendVisuals(
          palette: palette,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          strokeWidth: 2.6,
          dotRadius: 3,
          fillOpacity: 0.2,
          smooth: true,
          useGradient: true,
        );
    }
  }
}

class _DefaultTrendTooltip extends StatelessWidget {
  final String title;
  final List<_TrendTooltipRow> rows;

  const _DefaultTrendTooltip({required this.title, required this.rows});

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
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onInverseSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: row.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onInverseSurface.withValues(
                            alpha: 0.78,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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

class _TrendLegendSwatchPainter extends CustomPainter {
  final Color color;
  final SimpleTrendLineStyle lineStyle;

  const _TrendLegendSwatchPainter({
    required this.color,
    required this.lineStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    if (lineStyle == SimpleTrendLineStyle.solid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }

    final dash = lineStyle == SimpleTrendLineStyle.dotted ? 1.0 : 6.0;
    final gap = lineStyle == SimpleTrendLineStyle.dotted ? 5.0 : 4.0;
    var x = 0.0;
    while (x < size.width) {
      final next = math.min(x + dash, size.width);
      canvas.drawLine(Offset(x, y), Offset(next, y), paint);
      x = next + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLegendSwatchPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.lineStyle != lineStyle;
  }
}

class _TrendTooltipRow {
  final Color color;
  final String label;
  final String value;

  const _TrendTooltipRow({
    required this.color,
    required this.label,
    required this.value,
  });
}

class _ValueRange {
  final double min;
  final double max;

  const _ValueRange(this.min, this.max);

  double get span => max - min;
}
