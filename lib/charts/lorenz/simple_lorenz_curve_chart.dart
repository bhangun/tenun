import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleLorenzValueFormatter = String Function(double value);
typedef SimpleLorenzPointTapCallback =
    void Function(
      SimpleLorenzSeries series,
      SimpleLorenzPoint point,
      SimpleLorenzStats stats,
      int seriesIndex,
      int pointIndex,
    );
typedef SimpleLorenzTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleLorenzSeries series,
      SimpleLorenzPoint point,
      SimpleLorenzStats stats,
      int seriesIndex,
      int pointIndex,
      String formattedPopulationShare,
      String formattedValueShare,
      String formattedCumulativeValue,
      String formattedGini,
    );

class SimpleLorenzSeries {
  final String name;
  final List<double> values;
  final List<double> weights;
  final Color? color;

  const SimpleLorenzSeries({
    required this.name,
    required this.values,
    this.weights = const [],
    this.color,
  });
}

class SimpleLorenzPoint {
  final double populationShare;
  final double valueShare;
  final double cumulativeValue;
  final double cumulativeWeight;

  const SimpleLorenzPoint({
    required this.populationShare,
    required this.valueShare,
    required this.cumulativeValue,
    required this.cumulativeWeight,
  });
}

class SimpleLorenzStats {
  final double gini;
  final double totalValue;
  final double totalWeight;
  final int count;

  const SimpleLorenzStats({
    required this.gini,
    required this.totalValue,
    required this.totalWeight,
    required this.count,
  });
}

/// A Lorenz curve for concentration, inequality, workload balance,
/// customer/revenue share, fairness checks, and distribution diagnostics.
class SimpleLorenzCurveChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(54, 18, 26, 42);

  final List<SimpleLorenzSeries> series;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color? lineColor;
  final Color? areaColor;
  final Color? equalityLineColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showEqualityLine;
  final bool showArea;
  final bool showGini;
  final bool showAxisLabels;
  final int gridLineCount;
  final double strokeWidth;
  final double pointRadius;
  final double areaOpacity;
  final SimpleLorenzValueFormatter? shareFormatter;
  final SimpleLorenzValueFormatter? valueFormatter;
  final SimpleLorenzValueFormatter? giniFormatter;
  final SimpleLorenzPointTapCallback? onPointTap;
  final SimpleLorenzTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleLorenzCurveChart({
    super.key,
    required this.series,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 260,
    this.padding = _defaultPadding,
    this.xAxisLabel,
    this.yAxisLabel,
    this.lineColor,
    this.areaColor,
    this.equalityLineColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.showEqualityLine = true,
    this.showArea = true,
    this.showGini = true,
    this.showAxisLabels = true,
    this.gridLineCount = 4,
    this.strokeWidth = 2.4,
    this.pointRadius = 4.6,
    this.areaOpacity = 0.12,
    this.shareFormatter,
    this.valueFormatter,
    this.giniFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(strokeWidth > 0),
       assert(pointRadius >= 0),
       assert(areaOpacity >= 0 && areaOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleLorenzVisuals.resolve(style, colorScheme);
    final resolvedSeries = _resolveLorenzSeries(series);
    final resolvedShareFormatter = shareFormatter ?? _defaultShareFormatter;
    final resolvedValueFormatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedGiniFormatter = giniFormatter ?? _defaultGiniFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (resolvedSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Lorenz curve chart, no data.',
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
            resolvedSeries,
            resolvedGiniFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleLorenzCurveChartView(
            width: width,
            height: chartHeight,
            series: resolvedSeries,
            padding: padding,
            xAxisLabel: xAxisLabel ?? 'Cumulative population share',
            yAxisLabel: yAxisLabel ?? 'Cumulative value share',
            palette: _resolvePalette(visuals.palette),
            lineColor: lineColor ?? visuals.lineColor,
            areaColor: areaColor,
            equalityLineColor: equalityLineColor ?? visuals.equalityLineColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            showEqualityLine: showEqualityLine,
            showArea: showArea,
            showGini: showGini,
            showAxisLabels: showAxisLabels,
            gridLineCount: gridLineCount,
            strokeWidth: strokeWidth,
            pointRadius: pointRadius,
            areaOpacity: areaOpacity,
            shareFormatter: resolvedShareFormatter,
            valueFormatter: resolvedValueFormatter,
            giniFormatter: resolvedGiniFormatter,
            onPointTap: onPointTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(List<Color> fallback) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return fallback;
  }

  String _defaultSemanticLabel(
    List<_LorenzSeriesData> resolvedSeries,
    SimpleLorenzValueFormatter resolvedGiniFormatter,
  ) {
    final summaries = resolvedSeries
        .take(4)
        .map((item) {
          return '${item.series.name} ${item.stats.count} values, '
              'Gini ${resolvedGiniFormatter(item.stats.gini)}';
        })
        .join('; ');
    final suffix = resolvedSeries.length > 4
        ? '; and ${resolvedSeries.length - 4} more series'
        : '';
    final seriesLabel = resolvedSeries.length == 1 ? 'series' : 'series';
    return 'Lorenz curve chart, ${resolvedSeries.length} $seriesLabel. '
        '$summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _defaultShareFormatter(double value) {
    return '${(value * 100).round()}%';
  }

  static String _defaultGiniFormatter(double value) {
    return value.toStringAsFixed(2);
  }
}

class _SimpleLorenzCurveChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<_LorenzSeriesData> series;
  final EdgeInsets padding;
  final String xAxisLabel;
  final String yAxisLabel;
  final List<Color> palette;
  final Color lineColor;
  final Color? areaColor;
  final Color equalityLineColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final bool showEqualityLine;
  final bool showArea;
  final bool showGini;
  final bool showAxisLabels;
  final int gridLineCount;
  final double strokeWidth;
  final double pointRadius;
  final double areaOpacity;
  final SimpleLorenzValueFormatter shareFormatter;
  final SimpleLorenzValueFormatter valueFormatter;
  final SimpleLorenzValueFormatter giniFormatter;
  final SimpleLorenzPointTapCallback? onPointTap;
  final SimpleLorenzTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleLorenzCurveChartView({
    required this.width,
    required this.height,
    required this.series,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.palette,
    required this.lineColor,
    required this.areaColor,
    required this.equalityLineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.showEqualityLine,
    required this.showArea,
    required this.showGini,
    required this.showAxisLabels,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.pointRadius,
    required this.areaOpacity,
    required this.shareFormatter,
    required this.valueFormatter,
    required this.giniFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleLorenzCurveChartView> createState() =>
      _SimpleLorenzCurveChartViewState();
}

class _SimpleLorenzCurveChartViewState
    extends State<_SimpleLorenzCurveChartView> {
  _LorenzHit? _activeHit;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActivePoint ||
        widget.onPointTap != null;

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
                painter: _SimpleLorenzCurvePainter(
                  series: widget.series,
                  padding: widget.padding,
                  xAxisLabel: widget.xAxisLabel,
                  yAxisLabel: widget.yAxisLabel,
                  palette: widget.palette,
                  lineColor: widget.lineColor,
                  areaColor: widget.areaColor,
                  equalityLineColor: widget.equalityLineColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showLegend: widget.showLegend,
                  showActivePoint: widget.showActivePoint,
                  showEqualityLine: widget.showEqualityLine,
                  showArea: widget.showArea,
                  showGini: widget.showGini,
                  showAxisLabels: widget.showAxisLabels,
                  gridLineCount: widget.gridLineCount,
                  strokeWidth: widget.strokeWidth,
                  pointRadius: widget.pointRadius,
                  areaOpacity: widget.areaOpacity,
                  shareFormatter: widget.shareFormatter,
                  valueFormatter: widget.valueFormatter,
                  giniFormatter: widget.giniFormatter,
                  activeHit: _activeHit,
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
                      final hit = _hitTest(details.localPosition, size);
                      _setActive(hit);
                      if (hit == null) return;
                      final item = widget.series[hit.seriesIndex];
                      widget.onPointTap?.call(
                        item.series,
                        item.points[hit.pointIndex],
                        item.stats,
                        hit.seriesIndex,
                        hit.pointIndex,
                      );
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeHit != null)
                _buildTooltip(context, size, _activeHit!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_LorenzHit? hit) {
    if (_activeHit?.seriesIndex == hit?.seriesIndex &&
        _activeHit?.pointIndex == hit?.pointIndex) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _LorenzHit? _hitTest(Offset position, Size size) {
    final plot = _plot(size);
    if (!plot.inflate(14).contains(position)) return null;
    var bestHit = const _LorenzHit(-1, -1);
    var bestDistance = double.infinity;

    for (
      var seriesIndex = 0;
      seriesIndex < widget.series.length;
      seriesIndex++
    ) {
      final item = widget.series[seriesIndex];
      for (var pointIndex = 1; pointIndex < item.points.length; pointIndex++) {
        final point = item.points[pointIndex];
        final center = _pointOffset(point, plot);
        final distance = (position - center).distance;
        if (distance <= widget.pointRadius + 10 && distance < bestDistance) {
          bestHit = _LorenzHit(seriesIndex, pointIndex);
          bestDistance = distance;
        }
      }
    }
    return bestHit.seriesIndex >= 0 ? bestHit : null;
  }

  Widget _buildTooltip(BuildContext context, Size size, _LorenzHit hit) {
    final item = widget.series[hit.seriesIndex];
    final point = item.points[hit.pointIndex];
    final anchor = _pointOffset(point, _plot(size));
    const tooltipWidth = 198.0;
    const tooltipHeight = 106.0;
    final left = (anchor.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (anchor.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();
    final formattedPopulation = widget.shareFormatter(point.populationShare);
    final formattedValue = widget.shareFormatter(point.valueShare);
    final formattedCumulativeValue = widget.valueFormatter(
      point.cumulativeValue,
    );
    final formattedGini = widget.giniFormatter(item.stats.gini);

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            item.series,
            point,
            item.stats,
            hit.seriesIndex,
            hit.pointIndex,
            formattedPopulation,
            formattedValue,
            formattedCumulativeValue,
            formattedGini,
          ) ??
          _DefaultLorenzTooltip(
            color: _seriesColor(item, hit.seriesIndex),
            title:
                '${item.series.name} p${(point.populationShare * 100).round()}',
            populationShare: formattedPopulation,
            valueShare: formattedValue,
            cumulativeValue: formattedCumulativeValue,
            gini: formattedGini,
          ),
    );
  }

  Rect _plot(Size size) {
    return Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }

  Offset _pointOffset(SimpleLorenzPoint point, Rect plot) {
    return Offset(
      plot.left + point.populationShare * plot.width,
      plot.bottom - point.valueShare * plot.height,
    );
  }

  Color _seriesColor(_LorenzSeriesData item, int index) {
    return item.series.color ??
        (widget.series.length == 1
            ? widget.lineColor
            : widget.palette[index % widget.palette.length]);
  }
}

class _SimpleLorenzCurvePainter extends CustomPainter {
  final List<_LorenzSeriesData> series;
  final EdgeInsets padding;
  final String xAxisLabel;
  final String yAxisLabel;
  final List<Color> palette;
  final Color lineColor;
  final Color? areaColor;
  final Color equalityLineColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showActivePoint;
  final bool showEqualityLine;
  final bool showArea;
  final bool showGini;
  final bool showAxisLabels;
  final int gridLineCount;
  final double strokeWidth;
  final double pointRadius;
  final double areaOpacity;
  final SimpleLorenzValueFormatter shareFormatter;
  final SimpleLorenzValueFormatter valueFormatter;
  final SimpleLorenzValueFormatter giniFormatter;
  final _LorenzHit? activeHit;
  final double progress;

  const _SimpleLorenzCurvePainter({
    required this.series,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.palette,
    required this.lineColor,
    required this.areaColor,
    required this.equalityLineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showActivePoint,
    required this.showEqualityLine,
    required this.showArea,
    required this.showGini,
    required this.showAxisLabels,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.pointRadius,
    required this.areaOpacity,
    required this.shareFormatter,
    required this.valueFormatter,
    required this.giniFormatter,
    required this.activeHit,
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
    if (plot.width <= 0 || plot.height <= 0 || series.isEmpty) return;

    if (showGrid) _drawGrid(canvas, plot);
    _drawAxes(canvas, plot);
    if (showEqualityLine) _drawEqualityLine(canvas, plot);
    _drawSeries(canvas, plot);
    if (showAxisLabels) _drawAxisLabels(canvas, plot);
    if (showLegend) _drawLegend(canvas, plot);
    if (showGini) _drawGiniBadge(canvas, plot);
  }

  Offset _pointOffset(SimpleLorenzPoint point, Rect plot) {
    return Offset(
      plot.left + point.populationShare * plot.width,
      plot.bottom - point.valueShare * plot.height,
    );
  }

  void _drawGrid(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final share = index / gridLineCount;
      final x = plot.left + share * plot.width;
      final y = plot.bottom - share * plot.height;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), paint);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);

      final xPainter = _textPainter(
        shareFormatter(share),
        labelStyle.copyWith(color: labelStyle.color?.withValues(alpha: 0.72)),
        textAlign: TextAlign.center,
      )..layout();
      xPainter.paint(canvas, Offset(x - xPainter.width / 2, plot.bottom + 8));

      final yPainter = _textPainter(
        shareFormatter(share),
        labelStyle.copyWith(color: labelStyle.color?.withValues(alpha: 0.72)),
        maxWidth: padding.left - 10,
        textAlign: TextAlign.right,
      )..layout(maxWidth: padding.left - 10);
      yPainter.paint(
        canvas,
        Offset(plot.left - yPainter.width - 8, y - yPainter.height / 2),
      );
    }
  }

  void _drawAxes(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(plot.left, plot.bottom), plot.bottomRight, paint);
    canvas.drawLine(Offset(plot.left, plot.top), plot.bottomLeft, paint);
  }

  void _drawEqualityLine(Canvas canvas, Rect plot) {
    _drawStyledLine(
      canvas,
      plot.bottomLeft,
      plot.topRight,
      Paint()
        ..color = equalityLineColor.withValues(alpha: 0.72)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawSeries(Canvas canvas, Rect plot) {
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final item = series[seriesIndex];
      final color = _seriesColor(item, seriesIndex);
      final path = Path();
      final areaPath = Path()..moveTo(plot.left, plot.bottom);
      for (var pointIndex = 0; pointIndex < item.points.length; pointIndex++) {
        final point = item.points[pointIndex];
        final animatedPoint = SimpleLorenzPoint(
          populationShare: point.populationShare,
          valueShare: point.valueShare * progress,
          cumulativeValue: point.cumulativeValue * progress,
          cumulativeWeight: point.cumulativeWeight,
        );
        final offset = _pointOffset(animatedPoint, plot);
        if (pointIndex == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
        areaPath.lineTo(offset.dx, offset.dy);
      }
      areaPath
        ..lineTo(plot.right, plot.bottom)
        ..close();

      if (showArea) {
        canvas.drawPath(
          areaPath,
          Paint()
            ..color = (areaColor ?? color).withValues(alpha: areaOpacity)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      _drawPoints(canvas, plot, item, seriesIndex, color);
    }
  }

  void _drawPoints(
    Canvas canvas,
    Rect plot,
    _LorenzSeriesData item,
    int seriesIndex,
    Color color,
  ) {
    for (var pointIndex = 1; pointIndex < item.points.length; pointIndex++) {
      final point = item.points[pointIndex];
      final center = _pointOffset(point, plot);
      final active =
          activeHit?.seriesIndex == seriesIndex &&
          activeHit?.pointIndex == pointIndex;

      if (showActivePoint && active) {
        canvas.drawCircle(
          center,
          pointRadius + 7,
          Paint()..color = (activeColor ?? color).withValues(alpha: 0.15),
        );
        canvas.drawCircle(
          center,
          pointRadius + 3,
          Paint()
            ..color = (activeColor ?? color).withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      canvas.drawCircle(
        center,
        pointRadius + 1.4,
        Paint()..color = color.withValues(alpha: 0.12),
      );
      canvas.drawCircle(
        center,
        pointRadius,
        Paint()..color = color.withValues(alpha: active ? 0.98 : 0.84),
      );

      if (showValues && _totalPointCount <= 16) {
        _drawPointLabel(canvas, point, center, plot, color);
      }
    }
  }

  void _drawPointLabel(
    Canvas canvas,
    SimpleLorenzPoint point,
    Offset center,
    Rect plot,
    Color color,
  ) {
    final painter = _textPainter(
      shareFormatter(point.valueShare),
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.88,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: 54,
    )..layout(maxWidth: 54);
    final x = _safeClamp(
      center.dx + pointRadius + 5,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = _safeClamp(
      center.dy - painter.height / 2,
      plot.top + 2,
      plot.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
  }

  void _drawAxisLabels(Canvas canvas, Rect plot) {
    final xPainter = _textPainter(
      xAxisLabel,
      labelStyle.copyWith(fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    )..layout(maxWidth: plot.width);
    xPainter.paint(
      canvas,
      Offset(plot.center.dx - xPainter.width / 2, plot.bottom + 25),
    );

    canvas.save();
    canvas.translate(plot.left - padding.left + 12, plot.center.dy);
    canvas.rotate(-math.pi / 2);
    final yPainter = _textPainter(
      yAxisLabel,
      labelStyle.copyWith(fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    )..layout(maxWidth: plot.height);
    yPainter.paint(canvas, Offset(-yPainter.width / 2, -yPainter.height / 2));
    canvas.restore();
  }

  void _drawLegend(Canvas canvas, Rect plot) {
    if (series.length <= 1) return;
    final rowHeight = 20.0;
    final legendWidth = math.min(132.0, plot.width * 0.38);
    final left = plot.right - legendWidth - 6;
    var top = plot.top + 6;
    for (var index = 0; index < series.length; index++) {
      if (top + rowHeight > plot.bottom) break;
      final item = series[index];
      final color = _seriesColor(item, index);
      canvas.drawCircle(Offset(left + 5, top + 9), 4, Paint()..color = color);
      final painter = _textPainter(
        '${item.series.name} ${giniFormatter(item.stats.gini)}',
        labelStyle,
        maxWidth: legendWidth - 16,
      )..layout(maxWidth: legendWidth - 16);
      painter.paint(canvas, Offset(left + 14, top + 9 - painter.height / 2));
      top += rowHeight;
    }
  }

  void _drawGiniBadge(Canvas canvas, Rect plot) {
    if (series.length != 1) return;
    final item = series.first;
    final color = _seriesColor(item, 0);
    final label = 'Gini ${giniFormatter(item.stats.gini)}';
    final painter = _textPainter(
      label,
      valueStyle.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: (valueStyle.fontSize ?? 11) * 1.05,
      ),
    )..layout(maxWidth: 96);
    painter.paint(canvas, Offset(plot.right - painter.width - 4, plot.top + 4));
  }

  void _drawStyledLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) return;
    final direction = delta / distance;
    const dash = 7.0;
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

  int get _totalPointCount {
    return series.fold(0, (sum, item) => sum + item.points.length - 1);
  }

  Color _seriesColor(_LorenzSeriesData item, int index) {
    return item.series.color ??
        (series.length == 1 ? lineColor : palette[index % palette.length]);
  }

  double _safeClamp(double value, double lower, double upper) {
    if (lower > upper) return lower;
    return value.clamp(lower, upper).toDouble();
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
  bool shouldRepaint(covariant _SimpleLorenzCurvePainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.padding != padding ||
        oldDelegate.xAxisLabel != xAxisLabel ||
        oldDelegate.yAxisLabel != yAxisLabel ||
        oldDelegate.palette != palette ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.areaColor != areaColor ||
        oldDelegate.equalityLineColor != equalityLineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.showEqualityLine != showEqualityLine ||
        oldDelegate.showArea != showArea ||
        oldDelegate.showGini != showGini ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.areaOpacity != areaOpacity ||
        oldDelegate.shareFormatter != shareFormatter ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.giniFormatter != giniFormatter ||
        oldDelegate.activeHit != activeHit ||
        oldDelegate.progress != progress;
  }
}

List<_LorenzSeriesData> _resolveLorenzSeries(List<SimpleLorenzSeries> series) {
  final result = <_LorenzSeriesData>[];
  for (final item in series) {
    if (item.name.trim().isEmpty) continue;
    final pairs = <_LorenzPair>[];
    for (var index = 0; index < item.values.length; index++) {
      final value = item.values[index];
      final weight = index < item.weights.length ? item.weights[index] : 1.0;
      if (!value.isFinite || value < 0 || !weight.isFinite || weight <= 0) {
        continue;
      }
      pairs.add(_LorenzPair(value, weight));
    }
    if (pairs.length < 2) continue;
    pairs.sort((a, b) => a.value.compareTo(b.value));

    final totalWeight = pairs.fold(0.0, (sum, item) => sum + item.weight);
    final totalValue = pairs.fold(
      0.0,
      (sum, item) => sum + item.value * item.weight,
    );
    if (totalWeight <= 0 || totalValue <= 0) continue;

    var cumulativeWeight = 0.0;
    var cumulativeValue = 0.0;
    final points = <SimpleLorenzPoint>[
      const SimpleLorenzPoint(
        populationShare: 0,
        valueShare: 0,
        cumulativeValue: 0,
        cumulativeWeight: 0,
      ),
    ];
    for (final pair in pairs) {
      cumulativeWeight += pair.weight;
      cumulativeValue += pair.value * pair.weight;
      points.add(
        SimpleLorenzPoint(
          populationShare: (cumulativeWeight / totalWeight)
              .clamp(0.0, 1.0)
              .toDouble(),
          valueShare: (cumulativeValue / totalValue).clamp(0.0, 1.0).toDouble(),
          cumulativeValue: cumulativeValue,
          cumulativeWeight: cumulativeWeight,
        ),
      );
    }

    final area = _areaUnderCurve(points);
    final gini = (1 - 2 * area).clamp(0.0, 1.0).toDouble();
    result.add(
      _LorenzSeriesData(
        series: item,
        points: points,
        stats: SimpleLorenzStats(
          gini: gini,
          totalValue: totalValue,
          totalWeight: totalWeight,
          count: pairs.length,
        ),
      ),
    );
  }
  return result;
}

double _areaUnderCurve(List<SimpleLorenzPoint> points) {
  var area = 0.0;
  for (var index = 1; index < points.length; index++) {
    final previous = points[index - 1];
    final current = points[index];
    final width = current.populationShare - previous.populationShare;
    area += width * (previous.valueShare + current.valueShare) / 2;
  }
  return area.clamp(0.0, 0.5).toDouble();
}

class _LorenzPair {
  final double value;
  final double weight;

  const _LorenzPair(this.value, this.weight);
}

class _LorenzSeriesData {
  final SimpleLorenzSeries series;
  final List<SimpleLorenzPoint> points;
  final SimpleLorenzStats stats;

  const _LorenzSeriesData({
    required this.series,
    required this.points,
    required this.stats,
  });
}

class _LorenzHit {
  final int seriesIndex;
  final int pointIndex;

  const _LorenzHit(this.seriesIndex, this.pointIndex);
}

class _SimpleLorenzVisuals {
  final List<Color> palette;
  final Color lineColor;
  final Color equalityLineColor;
  final Color gridColor;
  final Color axisColor;

  const _SimpleLorenzVisuals({
    required this.palette,
    required this.lineColor,
    required this.equalityLineColor,
    required this.gridColor,
    required this.axisColor,
  });

  factory _SimpleLorenzVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleLorenzVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF22C55E),
          ],
          lineColor: colorScheme.primary,
          equalityLineColor: colorScheme.onSurfaceVariant,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleLorenzVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            const Color(0xFF0F766E),
            const Color(0xFF64748B),
          ],
          lineColor: colorScheme.primary,
          equalityLineColor: colorScheme.outline,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
        );
      case SimpleBarChartStyle.education:
        return _SimpleLorenzVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFFF59E0B),
          ],
          lineColor: colorScheme.secondary,
          equalityLineColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleLorenzVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFEC4899),
          ],
          lineColor: colorScheme.tertiary,
          equalityLineColor: colorScheme.onSurfaceVariant,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleLorenzVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
          ],
          lineColor: colorScheme.primary,
          equalityLineColor: colorScheme.onSurfaceVariant,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
        );
    }
  }
}

class _DefaultLorenzTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String populationShare;
  final String valueShare;
  final String cumulativeValue;
  final String gini;

  const _DefaultLorenzTooltip({
    required this.color,
    required this.title,
    required this.populationShare,
    required this.valueShare,
    required this.cumulativeValue,
    required this.gini,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _LorenzTooltipRow(label: 'Population', value: populationShare),
            const SizedBox(height: 4),
            _LorenzTooltipRow(label: 'Value', value: valueShare),
            const SizedBox(height: 4),
            _LorenzTooltipRow(label: 'Cumulative', value: cumulativeValue),
            const SizedBox(height: 4),
            _LorenzTooltipRow(label: 'Gini', value: gini),
          ],
        ),
      ),
    );
  }
}

class _LorenzTooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _LorenzTooltipRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onInverseSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onInverseSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
