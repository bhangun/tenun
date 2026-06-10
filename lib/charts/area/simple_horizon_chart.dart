import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../line/simple_line_chart.dart';

typedef SimpleHorizonValueFormatter = String Function(double value);
typedef SimpleHorizonTapCallback =
    void Function(
      SimpleTrendSeries series,
      SimpleTrendPoint point,
      int seriesIndex,
      int pointIndex,
    );
typedef SimpleHorizonTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleTrendSeries series,
      SimpleTrendPoint point,
      int seriesIndex,
      int pointIndex,
      String formattedValue,
    );

/// A compact horizon chart for comparing many time-series signals in a small
/// vertical space while preserving positive and negative movement.
class SimpleHorizonChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(82, 18, 18, 36);

  final List<SimpleTrendSeries> series;
  final SimpleTrendChartStyle style;
  final double baseline;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? positiveColor;
  final Color? negativeColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final Color? rowBackgroundColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool smooth;
  final int bandCount;
  final double rowGap;
  final double fillOpacity;
  final int gridLineCount;
  final SimpleHorizonValueFormatter? valueFormatter;
  final SimpleHorizonTapCallback? onPointTap;
  final SimpleHorizonTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleHorizonChart({
    super.key,
    required this.series,
    this.style = SimpleTrendChartStyle.elegant,
    this.baseline = 0,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.positiveColor,
    this.negativeColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.rowBackgroundColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.smooth = true,
    this.bandCount = 3,
    this.rowGap = 8,
    this.fillOpacity = 0.78,
    this.gridLineCount = 3,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(bandCount >= 1),
       assert(rowGap >= 0),
       assert(fillOpacity >= 0 && fillOpacity <= 1),
       assert(gridLineCount >= 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleHorizonVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .where(
          (item) =>
              item.points.any((point) => point.value.isFinite) &&
              item.points.any((point) => point.label.trim().isNotEmpty),
        )
        .toList();
    final labels = _labelsFor(visibleSeries);
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleSeries.isEmpty || labels.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Horizon chart, no data.',
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
            labels,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleHorizonChartView(
            width: width,
            height: chartHeight,
            series: visibleSeries,
            labels: labels,
            baseline: baseline,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: palette ?? visuals.palette,
            positiveColor: positiveColor ?? visuals.positiveColor,
            negativeColor: negativeColor ?? visuals.negativeColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            rowBackgroundColor:
                rowBackgroundColor ?? visuals.rowBackgroundColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showLabels: showLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            smooth: smooth,
            bandCount: bandCount,
            rowGap: rowGap,
            fillOpacity: fillOpacity,
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

  static List<String> _labelsFor(List<SimpleTrendSeries> series) {
    final seen = <String>{};
    final labels = <String>[];
    for (final item in series) {
      for (final point in item.points) {
        final label = point.label.trim();
        if (label.isNotEmpty && seen.add(label)) {
          labels.add(label);
        }
      }
    }
    return labels;
  }

  static String _defaultSemanticLabel(
    List<SimpleTrendSeries> series,
    List<String> labels,
    SimpleHorizonValueFormatter formatter,
  ) {
    final data = _HorizonData.resolve(series, labels);
    final latestIndex = labels.length - 1;
    final sample = series
        .take(5)
        .map((item) {
          final seriesIndex = series.indexOf(item);
          final point = data.points[seriesIndex][latestIndex];
          final value = point?.value ?? 0;
          return '${item.name ?? 'Series'} ${formatter(value)}';
        })
        .join(', ');
    final suffix = series.length > 5 ? ', and ${series.length - 5} more' : '';
    return 'Horizon chart, ${series.length} series across ${labels.length} '
        'labels. Latest ${labels.last}: $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    final prefix = value > 0 ? '+' : '';
    if (value == value.roundToDouble()) {
      return '$prefix${value.toStringAsFixed(0)}';
    }
    return '$prefix${value.toStringAsFixed(1)}';
  }
}

class _SimpleHorizonChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleTrendSeries> series;
  final List<String> labels;
  final double baseline;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final Color rowBackgroundColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool smooth;
  final int bandCount;
  final double rowGap;
  final double fillOpacity;
  final int gridLineCount;
  final SimpleHorizonValueFormatter valueFormatter;
  final SimpleHorizonTapCallback? onPointTap;
  final SimpleHorizonTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleHorizonChartView({
    required this.width,
    required this.height,
    required this.series,
    required this.labels,
    required this.baseline,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.rowBackgroundColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.smooth,
    required this.bandCount,
    required this.rowGap,
    required this.fillOpacity,
    required this.gridLineCount,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleHorizonChartView> createState() =>
      _SimpleHorizonChartViewState();
}

class _SimpleHorizonChartViewState extends State<_SimpleHorizonChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _HorizonHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleHorizonChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series ||
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
                    if (widget.showActivePoint ||
                        widget.showTooltip ||
                        widget.onPointTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit != null) {
                        widget.onPointTap?.call(
                          widget.series[hit.seriesIndex],
                          hit.point,
                          hit.seriesIndex,
                          hit.pointIndex,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleHorizonPainter(
                        series: widget.series,
                        labels: widget.labels,
                        baseline: widget.baseline,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        positiveColor: widget.positiveColor,
                        negativeColor: widget.negativeColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        rowBackgroundColor: widget.rowBackgroundColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showLegend: widget.showLegend,
                        showActivePoint: widget.showActivePoint,
                        smooth: widget.smooth,
                        bandCount: widget.bandCount,
                        rowGap: widget.rowGap,
                        fillOpacity: widget.fillOpacity,
                        gridLineCount: widget.gridLineCount,
                        valueFormatter: widget.valueFormatter,
                        activeHit: _activeHit,
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

  void _setActive(_HorizonHit? hit) {
    if (_activeHit?.seriesIndex == hit?.seriesIndex &&
        _activeHit?.pointIndex == hit?.pointIndex) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _HorizonHit? _hitTest(Offset position) {
    final geometry = _HorizonGeometry.resolve(
      series: widget.series,
      labels: widget.labels,
      baseline: widget.baseline,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      rowGap: widget.rowGap,
    );
    for (final hit in geometry.hits.reversed) {
      if (hit.rect.contains(position)) {
        return hit;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _HorizonHit hit) {
    final series = widget.series[hit.seriesIndex];
    final formattedValue = widget.valueFormatter(hit.point.value);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          series,
          hit.point,
          hit.seriesIndex,
          hit.pointIndex,
          formattedValue,
        ) ??
        _DefaultHorizonTooltip(
          title: series.name ?? 'Series ${hit.seriesIndex + 1}',
          label: hit.point.label,
          value: formattedValue,
          color: _seriesColor(hit.seriesIndex, hit.point.value),
        );
    final left = (hit.center.dx + 12).clamp(8.0, widget.width - 196);
    final top = (hit.center.dy - 42).clamp(8.0, widget.height - 100);
    return Positioned(left: left, top: top, child: tooltip);
  }

  Color _seriesColor(int index, double value) {
    if (widget.series[index].color != null) {
      return widget.series[index].color!;
    }
    if (widget.palette.isNotEmpty) {
      return widget.palette[index % widget.palette.length];
    }
    return value >= widget.baseline
        ? widget.positiveColor
        : widget.negativeColor;
  }
}

class _SimpleHorizonPainter extends CustomPainter {
  final List<SimpleTrendSeries> series;
  final List<String> labels;
  final double baseline;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final Color rowBackgroundColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActivePoint;
  final bool smooth;
  final int bandCount;
  final double rowGap;
  final double fillOpacity;
  final int gridLineCount;
  final SimpleHorizonValueFormatter valueFormatter;
  final _HorizonHit? activeHit;
  final double progress;

  const _SimpleHorizonPainter({
    required this.series,
    required this.labels,
    required this.baseline,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.rowBackgroundColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActivePoint,
    required this.smooth,
    required this.bandCount,
    required this.rowGap,
    required this.fillOpacity,
    required this.gridLineCount,
    required this.valueFormatter,
    required this.activeHit,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _HorizonGeometry.resolve(
      series: series,
      labels: labels,
      baseline: baseline,
      minValue: minValue,
      maxValue: maxValue,
      size: size,
      padding: padding,
      rowGap: rowGap,
    );
    if (geometry.rows.isEmpty || geometry.plot.width <= 0) {
      return;
    }

    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final row = geometry.rows[seriesIndex];
      _drawRowBackground(canvas, geometry, row, seriesIndex);
      if (showGrid) {
        _drawGrid(canvas, geometry, row);
      }
      _drawSeries(canvas, geometry, row, seriesIndex);
      if (showValues) {
        _drawLatestValue(canvas, geometry, row, seriesIndex);
      }
      if (showLegend) {
        _drawSeriesLabel(canvas, geometry, row, seriesIndex);
      }
    }
    if (showLabels) {
      _drawLabels(canvas, geometry);
    }
  }

  void _drawRowBackground(
    Canvas canvas,
    _HorizonGeometry geometry,
    Rect row,
    int seriesIndex,
  ) {
    if (rowBackgroundColor.a > 0 && seriesIndex.isEven) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(row, const Radius.circular(6)),
        Paint()
          ..color = rowBackgroundColor
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawLine(
      Offset(geometry.plot.left, row.center.dy),
      Offset(geometry.plot.right, row.center.dy),
      Paint()
        ..color = axisColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  void _drawGrid(Canvas canvas, _HorizonGeometry geometry, Rect row) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 0; index < gridLineCount; index++) {
      final ratio = gridLineCount == 1 ? 0.0 : index / (gridLineCount - 1);
      final x = geometry.plot.left + geometry.plot.width * ratio;
      canvas.drawLine(Offset(x, row.top), Offset(x, row.bottom), paint);
    }
  }

  void _drawSeries(
    Canvas canvas,
    _HorizonGeometry geometry,
    Rect row,
    int seriesIndex,
  ) {
    final values = geometry.data.values[seriesIndex];
    final seriesColor = _seriesColor(seriesIndex);
    final clipRect = Rect.fromLTRB(row.left, row.top, row.right, row.bottom);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(clipRect, const Radius.circular(6)),
    );

    for (var band = 0; band < bandCount; band++) {
      final strength = (band + 1) / bandCount;
      final positivePath = _bandPath(
        geometry,
        row,
        values,
        band,
        positive: true,
      );
      final negativePath = _bandPath(
        geometry,
        row,
        values,
        band,
        positive: false,
      );
      final active = showActivePoint && activeHit?.seriesIndex == seriesIndex;
      canvas.drawPath(
        positivePath,
        Paint()
          ..color = (active ? activeColor : seriesColor).withValues(
            alpha: fillOpacity * (0.42 + strength * 0.44) * progress,
          )
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        negativePath,
        Paint()
          ..color = negativeColor.withValues(
            alpha: fillOpacity * (0.38 + strength * 0.44) * progress,
          )
          ..style = PaintingStyle.fill,
      );
    }
    canvas.restore();

    if (showActivePoint &&
        activeHit != null &&
        activeHit!.seriesIndex == seriesIndex) {
      _drawActivePoint(canvas, row, activeHit!);
    }
  }

  Path _bandPath(
    _HorizonGeometry geometry,
    Rect row,
    List<double> values,
    int band, {
    required bool positive,
  }) {
    final baselineY = row.center.dy;
    final halfHeight = math.max(1.0, row.height / 2 - 2);
    final bandSize = geometry.domainMax / bandCount;
    final points = <Offset>[];

    for (var index = 0; index < labels.length; index++) {
      final delta = values[index] - baseline;
      final magnitude = positive ? math.max(0.0, delta) : math.max(0.0, -delta);
      final bandValue = (magnitude - bandSize * band).clamp(0.0, bandSize);
      final ratio = bandSize <= 0 ? 0.0 : bandValue / bandSize;
      final yOffset = ratio * halfHeight * progress;
      final y = positive ? baselineY - yOffset : baselineY + yOffset;
      points.add(Offset(geometry.xFor(index), y));
    }

    final path = Path()..moveTo(points.first.dx, baselineY);
    _appendLine(path, points);
    path.lineTo(points.last.dx, baselineY);
    path.close();
    return path;
  }

  void _appendLine(Path path, List<Offset> points) {
    if (points.isEmpty) {
      return;
    }
    if (points.length == 1) {
      path.lineTo(points.first.dx, points.first.dy);
      return;
    }
    if (!smooth) {
      for (final point in points) {
        path.lineTo(point.dx, point.dy);
      }
      return;
    }
    path.lineTo(points.first.dx, points.first.dy);
    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(controlX, current.dy, controlX, next.dy, next.dx, next.dy);
    }
  }

  void _drawActivePoint(Canvas canvas, Rect row, _HorizonHit hit) {
    final color = hit.point.value >= baseline ? activeColor : negativeColor;
    canvas.drawLine(
      Offset(hit.center.dx, row.top),
      Offset(hit.center.dx, row.bottom),
      Paint()
        ..color = color.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      hit.center,
      4.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      hit.center,
      4.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _drawLatestValue(
    Canvas canvas,
    _HorizonGeometry geometry,
    Rect row,
    int seriesIndex,
  ) {
    if (labels.isEmpty || geometry.plot.width < 74) {
      return;
    }
    final point = geometry.data.points[seriesIndex].last;
    if (point == null) {
      return;
    }
    final color = point.value >= baseline
        ? _seriesColor(seriesIndex)
        : negativeColor;
    _drawText(
      canvas,
      valueFormatter(point.value),
      Rect.fromLTWH(geometry.plot.right - 54, row.center.dy - 8, 50, 16),
      valueStyle.copyWith(color: color),
      align: TextAlign.right,
    );
  }

  void _drawSeriesLabel(
    Canvas canvas,
    _HorizonGeometry geometry,
    Rect row,
    int seriesIndex,
  ) {
    final name = series[seriesIndex].name ?? 'Series ${seriesIndex + 1}';
    final color = _seriesColor(seriesIndex);
    final rect = Rect.fromLTRB(0, row.top, geometry.plot.left - 10, row.bottom);
    _drawText(
      canvas,
      name,
      rect,
      labelStyle.copyWith(color: color, fontWeight: FontWeight.w700),
      align: TextAlign.right,
    );
  }

  void _drawLabels(Canvas canvas, _HorizonGeometry geometry) {
    final labelEvery = geometry.plot.width < 220
        ? math.max(1, (labels.length / 3).ceil())
        : math.max(1, (labels.length / 5).ceil());
    for (var index = 0; index < labels.length; index++) {
      if (index != 0 && index != labels.length - 1 && index % labelEvery != 0) {
        continue;
      }
      final x = geometry.xFor(index);
      final align = index == 0
          ? TextAlign.left
          : index == labels.length - 1
          ? TextAlign.right
          : TextAlign.center;
      _drawText(
        canvas,
        labels[index],
        Rect.fromLTWH(x - 40, geometry.plot.bottom + 8, 80, 16),
        labelStyle,
        align: align,
      );
    }
  }

  Color _seriesColor(int index) {
    if (series[index].color != null) {
      return series[index].color!;
    }
    if (palette.isNotEmpty) {
      return palette[index % palette.length];
    }
    return positiveColor;
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
  bool shouldRepaint(covariant _SimpleHorizonPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.labels != labels ||
        oldDelegate.baseline != baseline ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.positiveColor != positiveColor ||
        oldDelegate.negativeColor != negativeColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.rowBackgroundColor != rowBackgroundColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.smooth != smooth ||
        oldDelegate.bandCount != bandCount ||
        oldDelegate.rowGap != rowGap ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.activeHit != activeHit ||
        oldDelegate.progress != progress;
  }
}

class _HorizonGeometry {
  final Rect plot;
  final _HorizonData data;
  final List<Rect> rows;
  final List<_HorizonHit> hits;
  final double domainMax;

  const _HorizonGeometry({
    required this.plot,
    required this.data,
    required this.rows,
    required this.hits,
    required this.domainMax,
  });

  factory _HorizonGeometry.resolve({
    required List<SimpleTrendSeries> series,
    required List<String> labels,
    required double baseline,
    required double? minValue,
    required double? maxValue,
    required Size size,
    required EdgeInsets padding,
    required double rowGap,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final data = _HorizonData.resolve(series, labels);
    if (series.isEmpty ||
        labels.isEmpty ||
        plot.width <= 0 ||
        plot.height <= 0) {
      return _HorizonGeometry(
        plot: plot,
        data: data,
        rows: const [],
        hits: const [],
        domainMax: 1,
      );
    }

    final bounds = _ValueBounds.resolve(
      data.values,
      baseline,
      minValue,
      maxValue,
    );
    final domainMax = math.max(
      1.0,
      math.max((bounds.max - baseline).abs(), (bounds.min - baseline).abs()),
    );
    final totalGap = rowGap * math.max(0, series.length - 1);
    final rowHeight = math.max(1.0, (plot.height - totalGap) / series.length);
    final rows = <Rect>[];
    final hits = <_HorizonHit>[];

    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final top = plot.top + seriesIndex * (rowHeight + rowGap);
      final row = Rect.fromLTWH(plot.left, top, plot.width, rowHeight);
      rows.add(row);
      final points = data.points[seriesIndex];
      for (var pointIndex = 0; pointIndex < labels.length; pointIndex++) {
        final point = points[pointIndex];
        if (point == null) {
          continue;
        }
        final x = _xFor(plot, labels.length, pointIndex);
        final columnHalf = labels.length == 1
            ? plot.width / 2
            : plot.width / (labels.length - 1) / 2;
        final delta = (point.value - baseline).clamp(-domainMax, domainMax);
        final centerY =
            row.center.dy -
            (delta / domainMax) * math.max(1.0, row.height / 2 - 2);
        hits.add(
          _HorizonHit(
            seriesIndex: seriesIndex,
            pointIndex: pointIndex,
            point: point,
            rect: Rect.fromLTRB(
              math.max(plot.left, x - columnHalf),
              row.top,
              math.min(plot.right, x + columnHalf),
              row.bottom,
            ),
            center: Offset(x, centerY),
          ),
        );
      }
    }

    return _HorizonGeometry(
      plot: plot,
      data: data,
      rows: rows,
      hits: hits,
      domainMax: domainMax,
    );
  }

  double xFor(int index) => _xFor(plot, data.labels.length, index);

  static double _xFor(Rect plot, int count, int index) {
    if (count <= 1) {
      return plot.center.dx;
    }
    return plot.left + plot.width * index / (count - 1);
  }
}

class _HorizonData {
  final List<String> labels;
  final List<List<SimpleTrendPoint?>> points;
  final List<List<double>> values;

  const _HorizonData({
    required this.labels,
    required this.points,
    required this.values,
  });

  factory _HorizonData.resolve(
    List<SimpleTrendSeries> series,
    List<String> labels,
  ) {
    final points = series.map((item) {
      return labels.map((label) {
        for (final point in item.points) {
          if (point.label.trim() == label && point.value.isFinite) {
            return point;
          }
        }
        return null;
      }).toList();
    }).toList();
    final values = points.map((itemPoints) {
      return itemPoints.map((point) => point?.value ?? 0.0).toList();
    }).toList();
    return _HorizonData(labels: labels, points: points, values: values);
  }
}

class _ValueBounds {
  final double min;
  final double max;

  const _ValueBounds({required this.min, required this.max});

  factory _ValueBounds.resolve(
    List<List<double>> values,
    double baseline,
    double? minValue,
    double? maxValue,
  ) {
    var min = minValue ?? baseline;
    var max = maxValue ?? baseline;
    if (minValue == null || maxValue == null) {
      for (final seriesValues in values) {
        for (final value in seriesValues) {
          if (minValue == null) {
            min = math.min(min, value);
          }
          if (maxValue == null) {
            max = math.max(max, value);
          }
        }
      }
    }
    if (max < min) {
      final swap = min;
      min = max;
      max = swap;
    }
    return _ValueBounds(min: min, max: max);
  }
}

class _HorizonHit {
  final int seriesIndex;
  final int pointIndex;
  final SimpleTrendPoint point;
  final Rect rect;
  final Offset center;

  const _HorizonHit({
    required this.seriesIndex,
    required this.pointIndex,
    required this.point,
    required this.rect,
    required this.center,
  });
}

class _SimpleHorizonVisuals {
  final List<Color> palette;
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final Color rowBackgroundColor;

  const _SimpleHorizonVisuals({
    required this.palette,
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.rowBackgroundColor,
  });

  factory _SimpleHorizonVisuals.resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleHorizonVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.tertiary,
            colorScheme.secondary,
          ],
          positiveColor: colorScheme.primary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.54),
          axisColor: colorScheme.outline.withValues(alpha: 0.48),
          activeColor: colorScheme.tertiary,
          rowBackgroundColor: colorScheme.primary.withValues(alpha: 0.04),
        );
      case SimpleTrendChartStyle.professional:
        return _SimpleHorizonVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            const Color(0xFF64748B),
          ],
          positiveColor: colorScheme.primary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.68),
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
          activeColor: colorScheme.onSurface,
          rowBackgroundColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.18,
          ),
        );
      case SimpleTrendChartStyle.education:
        return _SimpleHorizonVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.primary,
            colorScheme.tertiary,
          ],
          positiveColor: colorScheme.secondary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.56),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          activeColor: colorScheme.primary,
          rowBackgroundColor: colorScheme.secondary.withValues(alpha: 0.05),
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleHorizonVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF06B6D4),
          ],
          positiveColor: colorScheme.tertiary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.52),
          axisColor: colorScheme.outline.withValues(alpha: 0.42),
          activeColor: colorScheme.primary,
          rowBackgroundColor: colorScheme.tertiary.withValues(alpha: 0.05),
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleHorizonVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.tertiary,
            colorScheme.secondary,
          ],
          positiveColor: colorScheme.primary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.56),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          activeColor: colorScheme.tertiary,
          rowBackgroundColor: colorScheme.primary.withValues(alpha: 0.04),
        );
    }
  }
}

class _DefaultHorizonTooltip extends StatelessWidget {
  final String title;
  final String label;
  final String value;
  final Color color;

  const _DefaultHorizonTooltip({
    required this.title,
    required this.label,
    required this.value,
    required this.color,
  });

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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 210),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: DefaultTextStyle(
            style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                    Text(label),
                    const SizedBox(width: 10),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
