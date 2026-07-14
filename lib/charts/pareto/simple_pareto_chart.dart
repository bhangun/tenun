import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleParetoValueFormatter = String Function(double value);
typedef SimpleParetoTapCallback =
    void Function(
      SimpleBarChartData data,
      int index,
      double cumulativeValue,
      double cumulativeShare,
    );
typedef SimpleParetoTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleBarChartData data,
      int index,
      String formattedValue,
      String formattedCumulativeValue,
      String formattedCumulativeShare,
    );

/// A compact Pareto chart that pairs ranked bars with a cumulative share line.
class SimpleParetoChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(48, 20, 48, 38);

  final List<SimpleBarChartData> data;
  final SimpleBarChartStyle style;
  final bool autoSort;
  final double? totalValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? barColor;
  final Color? lineColor;
  final Color? markerColor;
  final Color? targetLineColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final TextStyle? percentStyle;
  final bool showGrid;
  final bool showValues;
  final bool showCumulativeLine;
  final bool showCumulativeLabels;
  final bool showTargetLine;
  final bool showPercentAxis;
  final bool showTooltip;
  final bool showActiveItem;
  final int gridLineCount;
  final double targetShare;
  final String? targetLabel;
  final double? barRadius;
  final double? barWidthFactor;
  final double? maxBarWidth;
  final bool? useGradient;
  final SimpleParetoValueFormatter? valueFormatter;
  final SimpleParetoValueFormatter? percentFormatter;
  final SimpleParetoTapCallback? onItemTap;
  final SimpleParetoTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleParetoChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.autoSort = true,
    this.totalValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.barColor,
    this.lineColor,
    this.markerColor,
    this.targetLineColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.percentStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showCumulativeLine = true,
    this.showCumulativeLabels = true,
    this.showTargetLine = true,
    this.showPercentAxis = true,
    this.showTooltip = true,
    this.showActiveItem = true,
    this.gridLineCount = 4,
    this.targetShare = 0.8,
    this.targetLabel,
    this.barRadius,
    this.barWidthFactor,
    this.maxBarWidth,
    this.useGradient,
    this.valueFormatter,
    this.percentFormatter,
    this.onItemTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(totalValue == null || totalValue > 0),
       assert(maxValue == null || maxValue > 0),
       assert(gridLineCount >= 2),
       assert(targetShare >= 0 && targetShare <= 1),
       assert(barRadius == null || barRadius >= 0),
       assert(
         barWidthFactor == null || (barWidthFactor > 0 && barWidthFactor <= 1),
       ),
       assert(maxBarWidth == null || maxBarWidth > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleParetoVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.value.isFinite && item.value > 0)
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
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

        if (visibleData.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Pareto chart, no data.',
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
        final resolvedPercentStyle =
            percentStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: lineColor ?? visuals.lineColor,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: lineColor ?? visuals.lineColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );

        final resolvedItems = _resolveItems(visibleData, autoSort, totalValue);

        return ChartApiSurface(
          semanticLabel: _buildSemantics(
            resolvedItems,
            formatter,
            resolvedPercentFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleParetoChartView(
            width: width,
            height: chartHeight,
            data: resolvedItems,
            maxValue: maxValue,
            padding: padding,
            barColor: barColor ?? visuals.barColor,
            lineColor: lineColor ?? visuals.lineColor,
            markerColor: markerColor ?? lineColor ?? visuals.lineColor,
            targetLineColor: targetLineColor ?? visuals.targetLineColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            palette: palette,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            percentStyle: resolvedPercentStyle,
            showGrid: showGrid,
            showValues: showValues,
            showCumulativeLine: showCumulativeLine,
            showCumulativeLabels: showCumulativeLabels,
            showTargetLine: showTargetLine,
            showPercentAxis: showPercentAxis,
            showTooltip: showTooltip,
            showActiveItem: showActiveItem,
            gridLineCount: gridLineCount,
            targetShare: targetShare,
            targetLabel: targetLabel,
            barRadius: barRadius ?? visuals.barRadius,
            barWidthFactor: barWidthFactor ?? visuals.barWidthFactor,
            maxBarWidth: maxBarWidth ?? visuals.maxBarWidth,
            useGradient: useGradient ?? visuals.useGradient,
            valueFormatter: formatter,
            percentFormatter: resolvedPercentFormatter,
            onItemTap: onItemTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static List<_ParetoItem> _resolveItems(
    List<SimpleBarChartData> data,
    bool autoSort,
    double? totalValue,
  ) {
    final sorted = <_ParetoItem>[];
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      sorted.add(
        _ParetoItem(
          data: item,
          displayIndex: index,
          cumulativeValue: 0,
          cumulativeShare: 0,
        ),
      );
    }
    if (autoSort) {
      sorted.sort((a, b) => b.data.value.compareTo(a.data.value));
    }

    final dataTotal = sorted.fold<double>(
      0,
      (sum, item) => sum + item.data.value,
    );
    final resolvedTotal = math.max(totalValue ?? dataTotal, dataTotal);
    var running = 0.0;

    return [
      for (var index = 0; index < sorted.length; index++)
        () {
          final item = sorted[index];
          running += item.data.value;
          return _ParetoItem(
            data: item.data,
            displayIndex: index,
            cumulativeValue: running,
            cumulativeShare: resolvedTotal > 0
                ? (running / resolvedTotal).clamp(0.0, 1.0)
                : 0,
          );
        }(),
    ];
  }

  static String _buildSemantics(
    List<_ParetoItem> items,
    SimpleParetoValueFormatter formatter,
    SimpleParetoValueFormatter percentFormatter,
  ) {
    final sample = items
        .take(5)
        .map((item) {
          return '${item.data.label} ${formatter(item.data.value)}, cumulative '
              '${percentFormatter(item.cumulativeShare)}';
        })
        .join(', ');
    final suffix = items.length > 5 ? ', and ${items.length - 5} more' : '';
    return 'Pareto chart, ${items.length} items. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}m';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }
}

class _SimpleParetoChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<_ParetoItem> data;
  final double? maxValue;
  final EdgeInsets padding;
  final Color barColor;
  final Color lineColor;
  final Color markerColor;
  final Color targetLineColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color>? palette;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final TextStyle percentStyle;
  final bool showGrid;
  final bool showValues;
  final bool showCumulativeLine;
  final bool showCumulativeLabels;
  final bool showTargetLine;
  final bool showPercentAxis;
  final bool showTooltip;
  final bool showActiveItem;
  final int gridLineCount;
  final double targetShare;
  final String? targetLabel;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;
  final SimpleParetoValueFormatter valueFormatter;
  final SimpleParetoValueFormatter percentFormatter;
  final SimpleParetoTapCallback? onItemTap;
  final SimpleParetoTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleParetoChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.maxValue,
    required this.padding,
    required this.barColor,
    required this.lineColor,
    required this.markerColor,
    required this.targetLineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
    required this.labelStyle,
    required this.valueStyle,
    required this.percentStyle,
    required this.showGrid,
    required this.showValues,
    required this.showCumulativeLine,
    required this.showCumulativeLabels,
    required this.showTargetLine,
    required this.showPercentAxis,
    required this.showTooltip,
    required this.showActiveItem,
    required this.gridLineCount,
    required this.targetShare,
    required this.targetLabel,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.onItemTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleParetoChartView> createState() => _SimpleParetoChartViewState();
}

class _SimpleParetoChartViewState extends State<_SimpleParetoChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _ParetoHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleParetoChartView oldWidget) {
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
                    if (widget.showActiveItem ||
                        widget.showTooltip ||
                        widget.onItemTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit != null) {
                        widget.onItemTap?.call(
                          hit.item.data,
                          hit.index,
                          hit.item.cumulativeValue,
                          hit.item.cumulativeShare,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleParetoPainter(
                        data: widget.data,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        barColor: widget.barColor,
                        lineColor: widget.lineColor,
                        markerColor: widget.markerColor,
                        targetLineColor: widget.targetLineColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        palette: widget.palette,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        percentStyle: widget.percentStyle,
                        showGrid: widget.showGrid,
                        showValues: widget.showValues,
                        showCumulativeLine: widget.showCumulativeLine,
                        showCumulativeLabels: widget.showCumulativeLabels,
                        showTargetLine: widget.showTargetLine,
                        showPercentAxis: widget.showPercentAxis,
                        gridLineCount: widget.gridLineCount,
                        targetShare: widget.targetShare,
                        targetLabel: widget.targetLabel,
                        barRadius: widget.barRadius,
                        barWidthFactor: widget.barWidthFactor,
                        maxBarWidth: widget.maxBarWidth,
                        useGradient: widget.useGradient,
                        valueFormatter: widget.valueFormatter,
                        percentFormatter: widget.percentFormatter,
                        activeIndex: widget.showActiveItem
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

  void _setActive(_ParetoHit? hit) {
    if (_activeHit?.index == hit?.index) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _ParetoHit? _hitTest(Offset position) {
    final geometry = _ParetoGeometry.resolve(
      data: widget.data,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      maxValue: widget.maxValue,
      barWidthFactor: widget.barWidthFactor,
      maxBarWidth: widget.maxBarWidth,
    );
    for (final hit in geometry.hits) {
      if (hit.barRect.inflate(6).contains(position) ||
          (position - hit.markerOffset).distance <= 12) {
        return hit;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _ParetoHit hit) {
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          hit.item.data,
          hit.index,
          widget.valueFormatter(hit.item.data.value),
          widget.valueFormatter(hit.item.cumulativeValue),
          widget.percentFormatter(hit.item.cumulativeShare),
        ) ??
        _DefaultParetoTooltip(
          title: hit.item.data.label,
          rows: [
            _TooltipRow('Value', widget.valueFormatter(hit.item.data.value)),
            _TooltipRow(
              'Cumulative',
              widget.valueFormatter(hit.item.cumulativeValue),
            ),
            _TooltipRow(
              'Share',
              widget.percentFormatter(hit.item.cumulativeShare),
            ),
          ],
        );
    final left = (hit.markerOffset.dx + 12).clamp(8.0, widget.width - 176);
    final top = (hit.markerOffset.dy - 56).clamp(8.0, widget.height - 118);

    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleParetoPainter extends CustomPainter {
  final List<_ParetoItem> data;
  final double? maxValue;
  final EdgeInsets padding;
  final Color barColor;
  final Color lineColor;
  final Color markerColor;
  final Color targetLineColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color>? palette;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final TextStyle percentStyle;
  final bool showGrid;
  final bool showValues;
  final bool showCumulativeLine;
  final bool showCumulativeLabels;
  final bool showTargetLine;
  final bool showPercentAxis;
  final int gridLineCount;
  final double targetShare;
  final String? targetLabel;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;
  final SimpleParetoValueFormatter valueFormatter;
  final SimpleParetoValueFormatter percentFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleParetoPainter({
    required this.data,
    required this.maxValue,
    required this.padding,
    required this.barColor,
    required this.lineColor,
    required this.markerColor,
    required this.targetLineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
    required this.labelStyle,
    required this.valueStyle,
    required this.percentStyle,
    required this.showGrid,
    required this.showValues,
    required this.showCumulativeLine,
    required this.showCumulativeLabels,
    required this.showTargetLine,
    required this.showPercentAxis,
    required this.gridLineCount,
    required this.targetShare,
    required this.targetLabel,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }

    final geometry = _ParetoGeometry.resolve(
      data: data,
      size: size,
      padding: padding,
      maxValue: maxValue,
      barWidthFactor: barWidthFactor,
      maxBarWidth: maxBarWidth,
    );
    final plot = geometry.plot;
    if (plot.width <= 0 || plot.height <= 0) {
      return;
    }

    _drawGridAndAxes(canvas, geometry);
    if (showTargetLine) {
      _drawTargetLine(canvas, geometry);
    }
    _drawBars(canvas, geometry);
    if (showCumulativeLine) {
      _drawCumulativeLine(canvas, geometry);
    }
    _drawCategoryLabels(canvas, geometry);
  }

  void _drawGridAndAxes(Canvas canvas, _ParetoGeometry geometry) {
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
      final y = plot.bottom - ratio * plot.height;
      if (showGrid) {
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      }

      final value = geometry.resolvedMax * ratio;
      _drawText(
        canvas,
        valueFormatter(value),
        Rect.fromLTWH(0, y - 8, math.max(0, plot.left - 8), 16),
        labelStyle,
        align: TextAlign.right,
      );

      if (showPercentAxis) {
        _drawText(
          canvas,
          percentFormatter(ratio),
          Rect.fromLTWH(
            plot.right + 8,
            y - 8,
            math.max(0, geometry.size.width - plot.right - 8),
            16,
          ),
          labelStyle,
        );
      }
    }

    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axisPaint);
    if (showPercentAxis) {
      canvas.drawLine(plot.bottomRight, plot.topRight, axisPaint);
    }
  }

  void _drawTargetLine(Canvas canvas, _ParetoGeometry geometry) {
    final plot = geometry.plot;
    final y = geometry.yForShare(targetShare);
    final paint = Paint()
      ..color = targetLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    _drawDashedLine(canvas, Offset(plot.left, y), Offset(plot.right, y), paint);

    _drawText(
      canvas,
      targetLabel ?? percentFormatter(targetShare),
      Rect.fromLTWH(plot.right - 48, y - 18, 48, 16),
      percentStyle.copyWith(color: targetLineColor),
      align: TextAlign.right,
    );
  }

  void _drawBars(Canvas canvas, _ParetoGeometry geometry) {
    final zeroY = geometry.plot.bottom;
    for (final hit in geometry.hits) {
      final item = hit.item;
      final displayRect = Rect.fromLTRB(
        hit.barRect.left,
        zeroY - hit.barRect.height * progress,
        hit.barRect.right,
        zeroY,
      );
      final color = _barColor(item, hit.index);
      final active = activeIndex == hit.index;
      final radius = Radius.circular(barRadius);
      final rrect = RRect.fromRectAndRadius(displayRect, radius);
      final paint = Paint()
        ..color = active ? activeColor : color
        ..style = PaintingStyle.fill;

      if (useGradient && displayRect.height > 0) {
        paint.shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            (active ? activeColor : color),
            (active ? activeColor : color).withValues(alpha: 0.66),
          ],
        ).createShader(displayRect);
      }

      canvas.drawRRect(rrect, paint);

      if (active) {
        final outline = Paint()
          ..color = activeColor.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawRRect(rrect.inflate(2), outline);
      }

      if (showValues && displayRect.height > 12) {
        _drawText(
          canvas,
          valueFormatter(item.data.value),
          Rect.fromLTWH(
            displayRect.left - 8,
            displayRect.top - 18,
            displayRect.width + 16,
            16,
          ),
          valueStyle,
          align: TextAlign.center,
        );
      }
    }
  }

  void _drawCumulativeLine(Canvas canvas, _ParetoGeometry geometry) {
    final path = Path();
    final animatedPoints = <Offset>[];

    for (final hit in geometry.hits) {
      final point = Offset(
        hit.markerOffset.dx,
        geometry.plot.bottom -
            hit.item.cumulativeShare * geometry.plot.height * progress,
      );
      animatedPoints.add(point);
      if (animatedPoints.length == 1) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = markerColor
      ..style = PaintingStyle.fill;
    final dotBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var i = 0; i < animatedPoints.length; i++) {
      final point = animatedPoints[i];
      final active = activeIndex == i;
      canvas.drawCircle(point, active ? 5.8 : 4.4, dotPaint);
      canvas.drawCircle(point, active ? 5.8 : 4.4, dotBorder);

      if (showCumulativeLabels && geometry.bandWidth >= 44) {
        _drawText(
          canvas,
          percentFormatter(data[i].cumulativeShare),
          Rect.fromLTWH(point.dx - 24, point.dy - 24, 48, 16),
          percentStyle,
          align: TextAlign.center,
        );
      }
    }
  }

  void _drawCategoryLabels(Canvas canvas, _ParetoGeometry geometry) {
    for (final hit in geometry.hits) {
      final maxWidth = geometry.bandWidth * 0.92;
      _drawText(
        canvas,
        hit.item.data.label,
        Rect.fromLTWH(
          hit.markerOffset.dx - maxWidth / 2,
          geometry.plot.bottom + 8,
          maxWidth,
          24,
        ),
        labelStyle,
        align: TextAlign.center,
        maxLines: 1,
      );
    }
  }

  Color _barColor(_ParetoItem item, int index) {
    if (item.data.color != null) {
      return item.data.color!;
    }
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return barColor;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 6.0;
    const gap = 5.0;
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
    int maxLines = 1,
  }) {
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
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
  bool shouldRepaint(covariant _SimpleParetoPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.barColor != barColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.targetLineColor != targetLineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.palette != palette ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.percentStyle != percentStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showCumulativeLine != showCumulativeLine ||
        oldDelegate.showCumulativeLabels != showCumulativeLabels ||
        oldDelegate.showTargetLine != showTargetLine ||
        oldDelegate.showPercentAxis != showPercentAxis ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.targetShare != targetShare ||
        oldDelegate.targetLabel != targetLabel ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.barWidthFactor != barWidthFactor ||
        oldDelegate.maxBarWidth != maxBarWidth ||
        oldDelegate.useGradient != useGradient ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _ParetoGeometry {
  final Size size;
  final Rect plot;
  final double resolvedMax;
  final double bandWidth;
  final List<_ParetoHit> hits;

  const _ParetoGeometry({
    required this.size,
    required this.plot,
    required this.resolvedMax,
    required this.bandWidth,
    required this.hits,
  });

  factory _ParetoGeometry.resolve({
    required List<_ParetoItem> data,
    required Size size,
    required EdgeInsets padding,
    required double? maxValue,
    required double barWidthFactor,
    required double maxBarWidth,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final maxData = data.fold<double>(
      0,
      (max, item) => math.max(max, item.data.value),
    );
    final resolvedMax = math.max(maxValue ?? maxData * 1.14, maxData);
    final safeMax = resolvedMax <= 0 ? 1.0 : resolvedMax;
    final bandWidth = data.isEmpty ? plot.width : plot.width / data.length;
    final barWidth = math.min(maxBarWidth, bandWidth * barWidthFactor);

    final hits = <_ParetoHit>[];
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final centerX = plot.left + bandWidth * index + bandWidth / 2;
      final barLeft = centerX - barWidth / 2;
      final barRight = centerX + barWidth / 2;
      final barTop = plot.bottom - (item.data.value / safeMax) * plot.height;
      final markerY = plot.bottom - item.cumulativeShare * plot.height;
      hits.add(
        _ParetoHit(
          item: item,
          index: index,
          barRect: Rect.fromLTRB(barLeft, barTop, barRight, plot.bottom),
          markerOffset: Offset(centerX, markerY),
        ),
      );
    }

    return _ParetoGeometry(
      size: size,
      plot: plot,
      resolvedMax: safeMax,
      bandWidth: bandWidth,
      hits: hits,
    );
  }

  double yForShare(double share) {
    return plot.bottom - share.clamp(0.0, 1.0) * plot.height;
  }
}

class _ParetoHit {
  final _ParetoItem item;
  final int index;
  final Rect barRect;
  final Offset markerOffset;

  const _ParetoHit({
    required this.item,
    required this.index,
    required this.barRect,
    required this.markerOffset,
  });
}

class _ParetoItem {
  final SimpleBarChartData data;
  final int displayIndex;
  final double cumulativeValue;
  final double cumulativeShare;

  const _ParetoItem({
    required this.data,
    required this.displayIndex,
    required this.cumulativeValue,
    required this.cumulativeShare,
  });
}

class _SimpleParetoVisuals {
  final Color barColor;
  final Color lineColor;
  final Color targetLineColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;

  const _SimpleParetoVisuals({
    required this.barColor,
    required this.lineColor,
    required this.targetLineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
  });

  factory _SimpleParetoVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleParetoVisuals(
          barColor: colorScheme.primary,
          lineColor: colorScheme.tertiary,
          targetLineColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          activeColor: colorScheme.primaryContainer,
          barRadius: 10,
          barWidthFactor: 0.58,
          maxBarWidth: 46,
          useGradient: true,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleParetoVisuals(
          barColor: colorScheme.primary,
          lineColor: colorScheme.error,
          targetLineColor: colorScheme.outline,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          activeColor: colorScheme.primary.withValues(alpha: 0.74),
          barRadius: 4,
          barWidthFactor: 0.62,
          maxBarWidth: 40,
          useGradient: false,
        );
      case SimpleBarChartStyle.education:
        return _SimpleParetoVisuals(
          barColor: colorScheme.secondary,
          lineColor: colorScheme.primary,
          targetLineColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          activeColor: colorScheme.secondaryContainer,
          barRadius: 6,
          barWidthFactor: 0.64,
          maxBarWidth: 44,
          useGradient: false,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleParetoVisuals(
          barColor: colorScheme.tertiary,
          lineColor: colorScheme.primary,
          targetLineColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          activeColor: colorScheme.tertiaryContainer,
          barRadius: 16,
          barWidthFactor: 0.56,
          maxBarWidth: 52,
          useGradient: true,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleParetoVisuals(
          barColor: colorScheme.primary,
          lineColor: colorScheme.tertiary,
          targetLineColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: colorScheme.primaryContainer,
          barRadius: 8,
          barWidthFactor: 0.58,
          maxBarWidth: 44,
          useGradient: true,
        );
    }
  }
}

class _DefaultParetoTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultParetoTooltip({required this.title, required this.rows});

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
              for (final row in rows) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 82, child: Text(row.label)),
                    Text(
                      row.value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
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
