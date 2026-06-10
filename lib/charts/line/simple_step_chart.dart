import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import 'simple_line_chart.dart';

enum SimpleStepChartMode { before, after, middle }

/// A stepped trend chart for values that hold until a change point.
class SimpleStepChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(48, 18, 18, 34);

  final List<SimpleTrendSeries> series;
  final SimpleTrendChartStyle style;
  final SimpleStepChartMode mode;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? lineColor;
  final Color? fillColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveStep;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
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

  const SimpleStepChart({
    super.key,
    required this.series,
    this.style = SimpleTrendChartStyle.elegant,
    this.mode = SimpleStepChartMode.after,
    this.minValue,
    this.maxValue,
    this.height = 240,
    this.padding = _defaultPadding,
    this.lineColor,
    this.fillColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showDots = true,
    this.showValues = true,
    this.showArea = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveStep = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
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
    final visuals = _SimpleStepVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .map(_finiteSeries)
        .where((item) => item.points.isNotEmpty)
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Step chart, no data.',
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
          semanticLabel: _defaultSemanticLabel(visibleSeries, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleStepChartView(
            width: width,
            height: chartHeight,
            series: visibleSeries,
            mode: mode,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(visuals.palette),
            fillColor: fillColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeZero: includeZero,
            showGrid: showGrid,
            showDots: showDots,
            showValues: showValues,
            showArea: showArea,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveStep: showActiveStep,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            dotRadius: dotRadius ?? visuals.dotRadius,
            fillOpacity: fillOpacity ?? visuals.fillOpacity,
            gridLineCount: gridLineCount,
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

  static SimpleTrendSeries _finiteSeries(SimpleTrendSeries item) {
    return SimpleTrendSeries(
      name: item.name,
      color: item.color,
      strokeWidth: item.strokeWidth,
      lineStyle: item.lineStyle,
      points: item.points.where((point) => point.value.isFinite).toList(),
    );
  }

  String _defaultSemanticLabel(
    List<SimpleTrendSeries> visibleSeries,
    SimpleTrendValueFormatter formatter,
  ) {
    final summaries = visibleSeries
        .take(3)
        .map((item) {
          final name = item.name ?? 'Series ${visibleSeries.indexOf(item) + 1}';
          final first = item.points.first;
          final last = item.points.last;
          return '$name from ${first.label} ${formatter(first.value)} to '
              '${last.label} ${formatter(last.value)}';
        })
        .join('; ');
    final remaining = visibleSeries.length - math.min(visibleSeries.length, 3);
    final suffix = remaining > 0 ? '; and $remaining more series' : '';
    final seriesLabel = visibleSeries.length == 1 ? 'series' : 'series';
    return 'Step chart, ${visibleSeries.length} $seriesLabel. '
        '$summaries$suffix.';
  }

  List<Color> _resolvePalette(List<Color> defaults) {
    if (lineColor == null) return defaults;
    return [lineColor!, ...defaults.skip(1)];
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _SimpleStepChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleTrendSeries> series;
  final SimpleStepChartMode mode;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? fillColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveStep;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;
  final int gridLineCount;
  final SimpleTrendValueFormatter valueFormatter;
  final SimpleTrendPointTapCallback? onPointTap;
  final SimpleTrendTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleStepChartView({
    required this.width,
    required this.height,
    required this.series,
    required this.mode,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.fillColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showDots,
    required this.showValues,
    required this.showArea,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveStep,
    required this.referenceLines,
    required this.referenceBands,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
    required this.gridLineCount,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleStepChartView> createState() => _SimpleStepChartViewState();
}

class _SimpleStepChartViewState extends State<_SimpleStepChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final hasLegend = widget.showLegend && widget.series.length > 1;
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveStep ||
        widget.onPointTap != null;

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
                      painter: _SimpleStepPainter(
                        series: widget.series,
                        mode: widget.mode,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        fillColor: widget.fillColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        includeZero: widget.includeZero,
                        showGrid: widget.showGrid,
                        showDots: widget.showDots,
                        showValues: widget.showValues,
                        showArea: widget.showArea,
                        showActiveStep: widget.showActiveStep,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        strokeWidth: widget.strokeWidth,
                        dotRadius: widget.dotRadius,
                        fillOpacity: widget.fillOpacity,
                        gridLineCount: widget.gridLineCount,
                        activeIndex: _activeIndex,
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
    final plot = _StepGeometry.resolvePlot(size, widget.padding);
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

    final plot = _StepGeometry.resolvePlot(size, widget.padding);
    final count = _maxPointCount();
    final x = count <= 1
        ? plot.center.dx
        : plot.left + (index / (count - 1)) * plot.width;
    const tooltipWidth = 184.0;
    final left = (x + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (widget.padding.top + 6)
        .clamp(4.0, math.max(4.0, size.height - 104))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(context, label, rows) ??
          _DefaultStepTooltip(
            title: label,
            rows: rows
                .map(
                  (item) => _StepTooltipRow(
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
        spacing: 12,
        runSpacing: 4,
        children: [
          for (var index = 0; index < widget.series.length; index++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _colorFor(index),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.series[index].name ?? 'Series ${index + 1}',
                  style: widget.labelStyle.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<SimpleTrendTooltipItem> _tooltipItems(int pointIndex) {
    final rows = <SimpleTrendTooltipItem>[];
    for (
      var seriesIndex = 0;
      seriesIndex < widget.series.length;
      seriesIndex++
    ) {
      final item = widget.series[seriesIndex];
      if (pointIndex >= item.points.length) continue;
      rows.add(
        SimpleTrendTooltipItem(
          seriesName: item.name ?? 'Series ${seriesIndex + 1}',
          value: item.points[pointIndex].value,
          color: _colorFor(seriesIndex),
        ),
      );
    }
    return rows;
  }

  String _labelFor(int pointIndex) {
    for (final item in widget.series) {
      if (pointIndex < item.points.length) return item.points[pointIndex].label;
    }
    return 'Point ${pointIndex + 1}';
  }

  int _maxPointCount() {
    return widget.series.fold<int>(
      0,
      (max, item) => math.max(max, item.points.length),
    );
  }

  Color _colorFor(int index) {
    final itemColor = widget.series[index].color;
    if (itemColor != null) return itemColor;
    return widget.palette[index % widget.palette.length];
  }
}

class _SimpleStepPainter extends CustomPainter {
  final List<SimpleTrendSeries> series;
  final SimpleStepChartMode mode;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? fillColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final bool showActiveStep;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;
  final int gridLineCount;
  final int? activeIndex;
  final SimpleTrendValueFormatter valueFormatter;
  final double progress;

  const _SimpleStepPainter({
    required this.series,
    required this.mode,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.fillColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showDots,
    required this.showValues,
    required this.showArea,
    required this.showActiveStep,
    required this.referenceLines,
    required this.referenceBands,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
    required this.gridLineCount,
    required this.activeIndex,
    required this.valueFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _StepGeometry.resolve(
      size: size,
      series: series,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    if (geometry.plot.isEmpty || geometry.pointCount == 0) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    if (showActiveStep && activeIndex != null) {
      _drawActiveGuide(canvas, geometry, activeIndex!);
    }
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      _drawSeries(canvas, geometry, seriesIndex);
    }
    _drawLabels(canvas, geometry);
  }

  void _drawReferenceBands(Canvas canvas, _StepGeometry geometry) {
    final paint = Paint();
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;
      final top = geometry.yForValue(math.max(band.from, band.to));
      final bottom = geometry.yForValue(math.min(band.from, band.to));
      paint.color = (band.color ?? axisColor).withValues(alpha: band.opacity);
      canvas.drawRect(
        Rect.fromLTRB(geometry.plot.left, top, geometry.plot.right, bottom),
        paint,
      );
      if (band.showLabel && band.label != null) {
        _paintText(
          canvas,
          band.label!,
          valueStyle.copyWith(color: band.color ?? axisColor),
          Offset(geometry.plot.right - 4, top + 4),
          TextAlign.right,
          92,
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, _StepGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          geometry.min + geometry.span * (index / gridLineCount).toDouble();
      final y = geometry.yForValue(value);
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
      _paintText(
        canvas,
        valueFormatter(value),
        valueStyle.copyWith(fontWeight: FontWeight.w500),
        Offset(geometry.plot.left - 8, y),
        TextAlign.right,
        math.max(30, padding.left - 14),
        centeredY: true,
      );
    }
  }

  void _drawAxis(Canvas canvas, _StepGeometry geometry) {
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.bottom),
      Offset(geometry.plot.right, geometry.plot.bottom),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );
  }

  void _drawReferenceLines(Canvas canvas, _StepGeometry geometry) {
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
      if (line.showLabel && line.label != null) {
        _paintText(
          canvas,
          line.label!,
          valueStyle.copyWith(color: line.color ?? axisColor),
          Offset(geometry.plot.right - 4, y - 16),
          TextAlign.right,
          92,
        );
      }
    }
  }

  void _drawActiveGuide(Canvas canvas, _StepGeometry geometry, int index) {
    if (index < 0 || index >= geometry.pointCount) return;
    final x = geometry.xForIndex(index);
    canvas.drawLine(
      Offset(x, geometry.plot.top),
      Offset(x, geometry.plot.bottom),
      Paint()
        ..color = activeColor.withValues(alpha: 0.34)
        ..strokeWidth = 1.2,
    );
  }

  void _drawSeries(Canvas canvas, _StepGeometry geometry, int seriesIndex) {
    final item = series[seriesIndex];
    if (item.points.isEmpty) return;
    final color = _colorFor(seriesIndex);
    final path = _stepPath(item.points, geometry);
    final animatedClip = Rect.fromLTRB(
      geometry.plot.left,
      geometry.plot.top - 8,
      geometry.plot.left + geometry.plot.width * progress,
      geometry.plot.bottom + 8,
    );

    canvas.save();
    canvas.clipRect(animatedClip);

    if (showArea) {
      final areaPath = _stepAreaPath(item.points, geometry);
      final areaColor = fillColor ?? color;
      canvas.drawPath(
        areaPath,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              areaColor.withValues(alpha: fillOpacity),
              areaColor.withValues(alpha: 0.02),
            ],
          ).createShader(geometry.plot),
      );
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = item.strokeWidth ?? strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _drawSeriesLine(canvas, path, paint, item.lineStyle);

    if (showDots || showValues || activeIndex != null) {
      _drawPoints(canvas, geometry, item, seriesIndex, color);
    }
    canvas.restore();
  }

  Path _stepPath(List<SimpleTrendPoint> points, _StepGeometry geometry) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(geometry.xForIndex(0), geometry.yForValue(points.first.value));
    for (var index = 1; index < points.length; index++) {
      final previousX = geometry.xForIndex(index - 1);
      final previousY = geometry.yForValue(points[index - 1].value);
      final x = geometry.xForIndex(index);
      final y = geometry.yForValue(points[index].value);
      switch (mode) {
        case SimpleStepChartMode.before:
          path.lineTo(previousX, y);
          path.lineTo(x, y);
        case SimpleStepChartMode.after:
          path.lineTo(x, previousY);
          path.lineTo(x, y);
        case SimpleStepChartMode.middle:
          final mid = (previousX + x) / 2;
          path.lineTo(mid, previousY);
          path.lineTo(mid, y);
          path.lineTo(x, y);
      }
    }
    return path;
  }

  Path _stepAreaPath(List<SimpleTrendPoint> points, _StepGeometry geometry) {
    final path = _stepPath(points, geometry);
    if (points.isEmpty) return path;
    final lastX = geometry.xForIndex(points.length - 1);
    final firstX = geometry.xForIndex(0);
    final baselineY = geometry.baselineY;
    path.lineTo(lastX, baselineY);
    path.lineTo(firstX, baselineY);
    path.close();
    return path;
  }

  void _drawSeriesLine(
    Canvas canvas,
    Path path,
    Paint paint,
    SimpleTrendLineStyle lineStyle,
  ) {
    switch (lineStyle) {
      case SimpleTrendLineStyle.solid:
        canvas.drawPath(path, paint);
      case SimpleTrendLineStyle.dashed:
        _drawDashedPath(canvas, path, paint, const [8, 5]);
      case SimpleTrendLineStyle.dotted:
        _drawDashedPath(canvas, path, paint, const [1, 6]);
    }
  }

  void _drawPoints(
    Canvas canvas,
    _StepGeometry geometry,
    SimpleTrendSeries item,
    int seriesIndex,
    Color color,
  ) {
    for (var index = 0; index < item.points.length; index++) {
      final point = item.points[index];
      final center = Offset(
        geometry.xForIndex(index),
        geometry.yForValue(point.value),
      );
      final isActive = activeIndex == index;
      if (showDots || isActive) {
        final radius = isActive ? dotRadius + 2 : dotRadius;
        canvas.drawCircle(
          center,
          radius + 2,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.drawCircle(center, radius, Paint()..color = color);
      }
      if (showValues && progress > 0.64) {
        _paintText(
          canvas,
          valueFormatter(point.value),
          valueStyle.copyWith(color: color),
          Offset(center.dx, center.dy - 20),
          TextAlign.center,
          54,
        );
      }
    }
  }

  void _drawLabels(Canvas canvas, _StepGeometry geometry) {
    final labels = <int, String>{};
    for (final item in series) {
      for (var index = 0; index < item.points.length; index++) {
        labels.putIfAbsent(index, () => item.points[index].label);
      }
    }
    for (final entry in labels.entries) {
      if (geometry.pointCount > 5 && entry.key.isOdd) continue;
      _paintText(
        canvas,
        entry.value,
        labelStyle,
        Offset(geometry.xForIndex(entry.key), geometry.plot.bottom + 8),
        TextAlign.center,
        58,
      );
    }
  }

  Color _colorFor(int index) {
    final itemColor = series[index].color;
    if (itemColor != null) return itemColor;
    return palette[index % palette.length];
  }

  @override
  bool shouldRepaint(covariant _SimpleStepPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.mode != mode ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeZero != includeZero ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showDots != showDots ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showArea != showArea ||
        oldDelegate.showActiveStep != showActiveStep ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _StepGeometry {
  final Rect plot;
  final double min;
  final double max;
  final int pointCount;

  const _StepGeometry({
    required this.plot,
    required this.min,
    required this.max,
    required this.pointCount,
  });

  double get span => max - min;

  double get baselineY {
    final zero = 0.clamp(min, max).toDouble();
    return yForValue(zero);
  }

  double xForIndex(int index) {
    if (pointCount <= 1) return plot.center.dx;
    return plot.left + (index / (pointCount - 1)) * plot.width;
  }

  double yForValue(double value) {
    if (span <= 0) return plot.center.dy;
    return plot.bottom - ((value - min) / span) * plot.height;
  }

  static Rect resolvePlot(Size size, EdgeInsets padding) {
    final left = padding.left.clamp(0.0, size.width * 0.55).toDouble();
    final right = padding.right.clamp(0.0, size.width * 0.32).toDouble();
    final top = padding.top.clamp(0.0, size.height * 0.42).toDouble();
    final bottom = padding.bottom.clamp(0.0, size.height * 0.46).toDouble();
    return Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, size.width - right),
      math.max(top + 1, size.height - bottom),
    );
  }

  static _StepGeometry resolve({
    required Size size,
    required List<SimpleTrendSeries> series,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required bool includeZero,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    final chartPlot = resolvePlot(size, padding);
    var min = minValue ?? double.infinity;
    var max = maxValue ?? -double.infinity;
    var pointCount = 0;
    for (final item in series) {
      pointCount = math.max(pointCount, item.points.length);
      for (final point in item.points) {
        min = math.min(min, point.value);
        max = math.max(max, point.value);
      }
    }
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      min = math.min(min, line.value);
      max = math.max(max, line.value);
    }
    for (final band in referenceBands) {
      if (band.from.isFinite) {
        min = math.min(min, band.from);
        max = math.max(max, band.from);
      }
      if (band.to.isFinite) {
        min = math.min(min, band.to);
        max = math.max(max, band.to);
      }
    }
    if (includeZero) {
      min = math.min(min, 0);
      max = math.max(max, 0);
    }
    if (!min.isFinite || !max.isFinite) {
      min = 0;
      max = 1;
    }
    if (min == max) {
      min -= 1;
      max += 1;
    } else {
      final pad = (max - min) * 0.08;
      min = minValue ?? (min - pad);
      max = maxValue ?? (max + pad);
    }
    return _StepGeometry(
      plot: chartPlot,
      min: min,
      max: max,
      pointCount: pointCount,
    );
  }
}

class _SimpleStepVisuals {
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;

  const _SimpleStepVisuals({
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
  });

  static _SimpleStepVisuals resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    final grid = colorScheme.outlineVariant.withValues(alpha: 0.56);
    final axis = colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleStepVisuals(
          palette: const [Color(0xFF2563EB), Color(0xFF14B8A6)],
          gridColor: grid,
          axisColor: axis,
          activeColor: colorScheme.primary,
          strokeWidth: 3,
          dotRadius: 4,
          fillOpacity: 0.22,
        );
      case SimpleTrendChartStyle.professional:
        return _SimpleStepVisuals(
          palette: const [Color(0xFF0F766E), Color(0xFF475569)],
          gridColor: grid,
          axisColor: axis,
          activeColor: const Color(0xFF334155),
          strokeWidth: 2.4,
          dotRadius: 3.5,
          fillOpacity: 0.16,
        );
      case SimpleTrendChartStyle.education:
        return _SimpleStepVisuals(
          palette: const [Color(0xFF22C55E), Color(0xFF3B82F6)],
          gridColor: grid,
          axisColor: axis,
          activeColor: const Color(0xFFF59E0B),
          strokeWidth: 3,
          dotRadius: 4.2,
          fillOpacity: 0.2,
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleStepVisuals(
          palette: const [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          gridColor: grid,
          axisColor: axis,
          activeColor: const Color(0xFFF43F5E),
          strokeWidth: 3.2,
          dotRadius: 4.3,
          fillOpacity: 0.24,
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleStepVisuals(
          palette: const [Color(0xFF0D9488), Color(0xFF7C3AED)],
          gridColor: grid,
          axisColor: axis,
          activeColor: colorScheme.primary,
          strokeWidth: 2.8,
          dotRadius: 3.8,
          fillOpacity: 0.18,
        );
    }
  }
}

class _DefaultStepTooltip extends StatelessWidget {
  final String title;
  final List<_StepTooltipRow> rows;

  const _DefaultStepTooltip({required this.title, required this.rows});

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
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            for (final row in rows) row,
          ],
        ),
      ),
    );
  }
}

class _StepTooltipRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _StepTooltipRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
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
      _drawDashedLine(canvas, start, end, paint, const [8, 5]);
    case SimpleChartReferenceLineStyle.dotted:
      _drawDashedLine(canvas, start, end, paint, const [1, 6]);
  }
}

void _drawDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint,
  List<double> pattern,
) {
  final vector = end - start;
  final distance = vector.distance;
  if (distance <= 0) return;
  final direction = vector / distance;
  var drawn = 0.0;
  var patternIndex = 0;
  while (drawn < distance) {
    final length = pattern[patternIndex % pattern.length];
    final next = math.min(distance, drawn + length);
    if (patternIndex.isEven) {
      canvas.drawLine(
        start + direction * drawn,
        start + direction * next,
        paint,
      );
    }
    drawn = next;
    patternIndex++;
  }
}

void _drawDashedPath(
  Canvas canvas,
  Path path,
  Paint paint,
  List<double> pattern,
) {
  for (final metric in path.computeMetrics()) {
    var drawn = 0.0;
    var patternIndex = 0;
    while (drawn < metric.length) {
      final length = pattern[patternIndex % pattern.length];
      final next = math.min(metric.length, drawn + length);
      if (patternIndex.isEven) {
        canvas.drawPath(metric.extractPath(drawn, next), paint);
      }
      drawn = next;
      patternIndex++;
    }
  }
}

void _paintText(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset offset,
  TextAlign align,
  double maxWidth, {
  bool centeredY = false,
}) {
  if (text.isEmpty || maxWidth <= 0) return;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  var dx = offset.dx;
  if (align == TextAlign.center) {
    dx -= painter.width / 2;
  } else if (align == TextAlign.right || align == TextAlign.end) {
    dx -= painter.width;
  }
  final dy = centeredY ? offset.dy - painter.height / 2 : offset.dy;
  painter.paint(canvas, Offset(dx, dy));
}
