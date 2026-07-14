import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleWaterfallValueFormatter = String Function(double value);
typedef SimpleWaterfallTapCallback =
    void Function(
      SimpleWaterfallChartData data,
      int index,
      double start,
      double end,
      double runningTotal,
    );
typedef SimpleWaterfallTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleWaterfallChartData data,
      int index,
      String formattedValue,
      String formattedTotal,
    );

class SimpleWaterfallChartData {
  final String label;
  final double value;
  final bool isTotal;
  final Color? color;

  const SimpleWaterfallChartData({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.color,
  });
}

/// A compact bridge chart for explaining how positive and negative movements
/// build toward a final total.
class SimpleWaterfallChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(48, 18, 16, 38);

  final List<SimpleWaterfallChartData> data;
  final SimpleBarChartStyle style;
  final double initialValue;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? increaseColor;
  final Color? decreaseColor;
  final Color? totalColor;
  final Color? connectorColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeBarColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showConnectors;
  final bool showTooltip;
  final bool showActiveBar;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? barRadius;
  final double? barWidthFactor;
  final double? maxBarWidth;
  final bool? useGradient;
  final SimpleWaterfallValueFormatter? valueFormatter;
  final SimpleWaterfallValueFormatter? deltaFormatter;
  final SimpleWaterfallTapCallback? onBarTap;
  final SimpleWaterfallTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleWaterfallChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.initialValue = 0,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.increaseColor,
    this.decreaseColor,
    this.totalColor,
    this.connectorColor,
    this.gridColor,
    this.axisColor,
    this.activeBarColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showConnectors = true,
    this.showTooltip = true,
    this.showActiveBar = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.barRadius,
    this.barWidthFactor,
    this.maxBarWidth,
    this.useGradient,
    this.valueFormatter,
    this.deltaFormatter,
    this.onBarTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 750),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(
         initialValue > double.negativeInfinity &&
             initialValue < double.infinity,
       ),
       assert(gridLineCount >= 2),
       assert(barRadius == null || barRadius >= 0),
       assert(
         barWidthFactor == null || (barWidthFactor > 0 && barWidthFactor <= 1),
       ),
       assert(maxBarWidth == null || maxBarWidth > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleWaterfallVisuals.resolve(style, colorScheme);
    final visibleData = data.where((item) => item.value.isFinite).toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedDeltaFormatter = deltaFormatter ?? _defaultDeltaFormatter;

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
            emptySemanticLabel: 'Waterfall chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final computed = _computeWaterfall(visibleData, initialValue);
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
            computed,
            formatter,
            resolvedDeltaFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleWaterfallChartView(
            width: width,
            height: chartHeight,
            items: computed,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            increaseColor: increaseColor ?? visuals.increaseColor,
            decreaseColor: decreaseColor ?? visuals.decreaseColor,
            totalColor: totalColor ?? visuals.totalColor,
            connectorColor: connectorColor ?? visuals.connectorColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeBarColor: activeBarColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showConnectors: showConnectors,
            showTooltip: showTooltip,
            showActiveBar: showActiveBar,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            barRadius: barRadius ?? visuals.barRadius,
            barWidthFactor: barWidthFactor ?? visuals.barWidthFactor,
            maxBarWidth: maxBarWidth ?? visuals.maxBarWidth,
            useGradient: useGradient ?? visuals.useGradient,
            valueFormatter: formatter,
            deltaFormatter: resolvedDeltaFormatter,
            onBarTap: onBarTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(
    List<_WaterfallItem> computed,
    SimpleWaterfallValueFormatter formatter,
    SimpleWaterfallValueFormatter resolvedDeltaFormatter,
  ) {
    final visibleItems = computed
        .take(6)
        .map((item) {
          if (item.data.isTotal) {
            return '${item.data.label} total ${formatter(item.end)}';
          }
          return '${item.data.label} change '
              '${resolvedDeltaFormatter(item.delta)}, total '
              '${formatter(item.runningTotal)}';
        })
        .join(', ');
    final remaining = computed.length - math.min(computed.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = computed.length == 1 ? 'item' : 'items';
    return 'Waterfall chart, ${computed.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultDeltaFormatter(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${_defaultValueFormatter(value)}';
  }
}

class _SimpleWaterfallChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<_WaterfallItem> items;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color increaseColor;
  final Color decreaseColor;
  final Color totalColor;
  final Color connectorColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeBarColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showConnectors;
  final bool showTooltip;
  final bool showActiveBar;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;
  final SimpleWaterfallValueFormatter valueFormatter;
  final SimpleWaterfallValueFormatter deltaFormatter;
  final SimpleWaterfallTapCallback? onBarTap;
  final SimpleWaterfallTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleWaterfallChartView({
    required this.width,
    required this.height,
    required this.items,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.increaseColor,
    required this.decreaseColor,
    required this.totalColor,
    required this.connectorColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeBarColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showConnectors,
    required this.showTooltip,
    required this.showActiveBar,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
    required this.valueFormatter,
    required this.deltaFormatter,
    required this.onBarTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleWaterfallChartView> createState() =>
      _SimpleWaterfallChartViewState();
}

class _SimpleWaterfallChartViewState extends State<_SimpleWaterfallChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveBar || widget.onBarTap != null;

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
                painter: _SimpleWaterfallPainter(
                  items: widget.items,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  increaseColor: widget.increaseColor,
                  decreaseColor: widget.decreaseColor,
                  totalColor: widget.totalColor,
                  connectorColor: widget.connectorColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeBarColor: widget.activeBarColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showConnectors: widget.showConnectors,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  barRadius: widget.barRadius,
                  barWidthFactor: widget.barWidthFactor,
                  maxBarWidth: widget.maxBarWidth,
                  useGradient: widget.useGradient,
                  valueFormatter: widget.valueFormatter,
                  deltaFormatter: widget.deltaFormatter,
                  activeIndex: widget.showActiveBar ? _activeIndex : null,
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
                        final item = widget.items[index];
                        widget.onBarTap?.call(
                          item.data,
                          index,
                          item.start,
                          item.end,
                          item.runningTotal,
                        );
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
    final plot = _plot(size);
    if (!plot.inflate(8).contains(position)) return null;
    if (widget.items.isEmpty) return null;

    final segmentWidth = plot.width / widget.items.length;
    final index = ((position.dx - plot.left) / segmentWidth).floor();
    return index >= 0 && index < widget.items.length ? index : null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final item = widget.items[index];
    final formattedValue = item.data.isTotal
        ? widget.valueFormatter(item.end)
        : widget.deltaFormatter(item.delta);
    final formattedTotal = widget.valueFormatter(item.runningTotal);
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 178.0;
    const tooltipHeight = 74.0;
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
            item.data,
            index,
            formattedValue,
            formattedTotal,
          ) ??
          _DefaultWaterfallTooltip(
            color: _itemColor(item),
            title: item.data.label,
            valueLabel: item.data.isTotal ? 'Total' : 'Change',
            value: formattedValue,
            total: formattedTotal,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final plot = _plot(size);
    final range = _resolveRange();
    final segmentWidth = plot.width / widget.items.length;
    final item = widget.items[index];
    final x = plot.left + segmentWidth * index + segmentWidth / 2;
    final topY = _yForValue(item.high, plot, range);
    return Offset(x, topY);
  }

  Rect _plot(Size size) {
    return Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }

  _WaterfallRange _resolveRange() {
    return _resolveWaterfallRange(
      items: widget.items,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
  }

  double _yForValue(double value, Rect plot, _WaterfallRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  Color _itemColor(_WaterfallItem item) {
    if (item.data.color != null) return item.data.color!;
    if (item.data.isTotal) return widget.totalColor;
    return item.delta >= 0 ? widget.increaseColor : widget.decreaseColor;
  }
}

class _SimpleWaterfallPainter extends CustomPainter {
  final List<_WaterfallItem> items;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color increaseColor;
  final Color decreaseColor;
  final Color totalColor;
  final Color connectorColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeBarColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showConnectors;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;
  final SimpleWaterfallValueFormatter valueFormatter;
  final SimpleWaterfallValueFormatter deltaFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleWaterfallPainter({
    required this.items,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.increaseColor,
    required this.decreaseColor,
    required this.totalColor,
    required this.connectorColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeBarColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showConnectors,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
    required this.valueFormatter,
    required this.deltaFormatter,
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
    if (plot.width <= 0 || plot.height <= 0 || items.isEmpty) return;

    final range = _resolveRange();
    _drawBands(canvas, plot, range);
    _drawActiveCategory(canvas, plot);
    if (showGrid) {
      _drawGrid(canvas, plot, range);
    }
    _drawZeroAxis(canvas, plot, range);
    _drawReferenceLines(canvas, plot, range);
    if (showConnectors) {
      _drawConnectors(canvas, plot, range);
    }
    _drawBars(canvas, plot, range);
    _drawLabels(canvas, plot);
  }

  _WaterfallRange _resolveRange() {
    return _resolveWaterfallRange(
      items: items,
      minValue: minValue,
      maxValue: maxValue,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
  }

  double _yForValue(double value, Rect plot, _WaterfallRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  void _drawGrid(Canvas canvas, Rect plot, _WaterfallRange range) {
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

  void _drawZeroAxis(Canvas canvas, Rect plot, _WaterfallRange range) {
    final zeroY = _yForValue(
      0,
      plot,
      range,
    ).clamp(plot.top, plot.bottom).toDouble();
    canvas.drawLine(
      Offset(plot.left, zeroY),
      Offset(plot.right, zeroY),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1.2,
    );
  }

  void _drawBands(Canvas canvas, Rect plot, _WaterfallRange range) {
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
      final color = band.color ?? totalColor;
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
    final text =
        band.label ??
        '${valueFormatter(band.from)} - ${valueFormatter(band.to)}';
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
    const labelPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + labelPadding.horizontal;
    final height = painter.height + labelPadding.vertical;
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
    painter.paint(canvas, Offset(x + labelPadding.left, y + labelPadding.top));
  }

  void _drawReferenceLines(Canvas canvas, Rect plot, _WaterfallRange range) {
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
    const labelPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + labelPadding.horizontal;
    final height = painter.height + labelPadding.vertical;
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
    painter.paint(canvas, Offset(x + labelPadding.left, y + labelPadding.top));
  }

  void _drawActiveCategory(Canvas canvas, Rect plot) {
    final index = activeIndex;
    if (index == null || index < 0 || index >= items.length) return;
    final segmentWidth = plot.width / items.length;
    final rect = Rect.fromLTWH(
      plot.left + segmentWidth * index,
      plot.top,
      segmentWidth,
      plot.height,
    );
    final color = activeBarColor ?? _itemColor(items[index]);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.06));
  }

  void _drawConnectors(Canvas canvas, Rect plot, _WaterfallRange range) {
    if (items.length < 2) return;
    final segmentWidth = plot.width / items.length;
    final barWidth = _barWidth(segmentWidth);
    final paint = Paint()
      ..color = connectorColor.withValues(alpha: 0.58)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < items.length - 1; index++) {
      final current = items[index];
      final x1 =
          plot.left + segmentWidth * index + segmentWidth / 2 + barWidth / 2;
      final x2 =
          plot.left +
          segmentWidth * (index + 1) +
          segmentWidth / 2 -
          barWidth / 2;
      final y = _yForValue(current.runningTotal, plot, range);
      if (y < plot.top - 1 || y > plot.bottom + 1) continue;
      _drawDashedConnector(canvas, Offset(x1, y), Offset(x2, y), paint);
    }
  }

  void _drawDashedConnector(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    final distance = (end - start).distance;
    if (distance <= 0) return;
    const dash = 5.0;
    const gap = 4.0;
    var traveled = 0.0;
    while (traveled < distance) {
      final x1 = start.dx + traveled;
      final x2 = start.dx + math.min(traveled + dash, distance);
      canvas.drawLine(Offset(x1, start.dy), Offset(x2, end.dy), paint);
      traveled += dash + gap;
    }
  }

  void _drawBars(Canvas canvas, Rect plot, _WaterfallRange range) {
    final segmentWidth = plot.width / items.length;
    final barWidth = _barWidth(segmentWidth);

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final centerX = plot.left + segmentWidth * index + segmentWidth / 2;
      final baseY = _yForValue(item.start, plot, range);
      final targetEndY = _yForValue(item.end, plot, range);
      final animatedEndY = baseY + (targetEndY - baseY) * progress;
      final top = math.min(baseY, animatedEndY);
      final bottom = math.max(baseY, animatedEndY);
      final rect = Rect.fromLTRB(
        centerX - barWidth / 2,
        top,
        centerX + barWidth / 2,
        math.max(top + 1.5, bottom),
      );
      final color = _itemColor(item);
      final active = index == activeIndex;

      if (active) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.inflate(4),
            Radius.circular(barRadius + 4),
          ),
          Paint()..color = color.withValues(alpha: 0.13),
        );
      }

      final radius = Radius.circular(math.min(barRadius, barWidth / 2));
      final rrect = RRect.fromRectAndRadius(rect, radius);
      if (useGradient && rect.height > 2) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.88),
                color.withValues(alpha: 0.68),
              ],
            ).createShader(rect),
        );
      } else {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = color.withValues(alpha: item.data.isTotal ? 0.9 : 0.82),
        );
      }

      if (showValues && segmentWidth >= 34) {
        _drawValue(canvas, item, rect, plot);
      }
    }
  }

  void _drawValue(Canvas canvas, _WaterfallItem item, Rect rect, Rect plot) {
    final label = item.data.isTotal
        ? valueFormatter(item.end)
        : deltaFormatter(item.delta);
    final color = item.data.isTotal ? _itemColor(item) : _itemColor(item);
    final painter = _textPainter(
      label,
      valueStyle.copyWith(color: color),
      textAlign: TextAlign.center,
    )..layout();
    final above = item.delta >= 0 || item.data.isTotal;
    final preferredY = above ? rect.top - painter.height - 5 : rect.bottom + 5;
    final x = _safeClamp(
      rect.center.dx - painter.width / 2,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = _safeClamp(
      preferredY,
      plot.top + 2,
      plot.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
  }

  void _drawLabels(Canvas canvas, Rect plot) {
    final segmentWidth = plot.width / items.length;
    final maxLabelCount = math.max(1, plot.width / 54).floor();
    final labelEvery = math.max(1, (items.length / maxLabelCount).ceil());

    for (var index = 0; index < items.length; index++) {
      if (index % labelEvery != 0) continue;
      final x = plot.left + segmentWidth * index + segmentWidth / 2;
      final maxWidth = math.max(18.0, segmentWidth * 0.94);
      final painter = _textPainter(
        items[index].data.label,
        labelStyle,
        maxWidth: maxWidth,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x - painter.width / 2, plot.bottom + 9));
    }
  }

  double _barWidth(double segmentWidth) {
    return math.min(maxBarWidth, math.max(2.0, segmentWidth * barWidthFactor));
  }

  Color _itemColor(_WaterfallItem item) {
    if (item.data.color != null) return item.data.color!;
    if (item.data.isTotal) return totalColor;
    return item.delta >= 0 ? increaseColor : decreaseColor;
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
  bool shouldRepaint(covariant _SimpleWaterfallPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.increaseColor != increaseColor ||
        oldDelegate.decreaseColor != decreaseColor ||
        oldDelegate.totalColor != totalColor ||
        oldDelegate.connectorColor != connectorColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeBarColor != activeBarColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showConnectors != showConnectors ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.barWidthFactor != barWidthFactor ||
        oldDelegate.maxBarWidth != maxBarWidth ||
        oldDelegate.useGradient != useGradient ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.deltaFormatter != deltaFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

List<_WaterfallItem> _computeWaterfall(
  List<SimpleWaterfallChartData> data,
  double initialValue,
) {
  final result = <_WaterfallItem>[];
  var running = initialValue;
  for (final item in data) {
    if (item.isTotal) {
      result.add(
        _WaterfallItem(
          data: item,
          start: 0,
          end: item.value,
          delta: item.value - running,
          runningTotal: item.value,
        ),
      );
      running = item.value;
      continue;
    }

    final start = running;
    running += item.value;
    result.add(
      _WaterfallItem(
        data: item,
        start: start,
        end: running,
        delta: item.value,
        runningTotal: running,
      ),
    );
  }
  return result;
}

_WaterfallRange _resolveWaterfallRange({
  required List<_WaterfallItem> items,
  required double? minValue,
  required double? maxValue,
  required List<SimpleChartReferenceLine> referenceLines,
  required List<SimpleChartReferenceBand> referenceBands,
}) {
  var lower = 0.0;
  var upper = 0.0;

  for (final item in items) {
    lower = math.min(lower, item.low);
    upper = math.max(upper, item.high);
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

  final hasExplicitMin = minValue != null && minValue.isFinite;
  final hasExplicitMax = maxValue != null && maxValue.isFinite;
  lower = hasExplicitMin ? minValue : lower;
  upper = hasExplicitMax ? maxValue : upper;

  if (lower > upper) {
    final previousLower = lower;
    lower = upper;
    upper = previousLower;
  }

  if (lower == upper) {
    final pad = lower == 0 ? 1.0 : lower.abs() * 0.2;
    if (!hasExplicitMin) lower -= pad;
    if (!hasExplicitMax) upper += pad;
  } else {
    final pad = (upper - lower).abs() * 0.08;
    if (!hasExplicitMin) lower -= pad;
    if (!hasExplicitMax) upper += pad;
  }

  if (lower == upper) upper = lower + 1;
  return _WaterfallRange(lower, upper);
}

class _WaterfallItem {
  final SimpleWaterfallChartData data;
  final double start;
  final double end;
  final double delta;
  final double runningTotal;

  const _WaterfallItem({
    required this.data,
    required this.start,
    required this.end,
    required this.delta,
    required this.runningTotal,
  });

  double get low => math.min(start, end);
  double get high => math.max(start, end);
}

class _WaterfallRange {
  final double min;
  final double max;

  const _WaterfallRange(this.min, this.max);

  double get span => math.max(0.000001, max - min);
}

class _SimpleWaterfallVisuals {
  final Color increaseColor;
  final Color decreaseColor;
  final Color totalColor;
  final Color connectorColor;
  final Color gridColor;
  final Color axisColor;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;

  const _SimpleWaterfallVisuals({
    required this.increaseColor,
    required this.decreaseColor,
    required this.totalColor,
    required this.connectorColor,
    required this.gridColor,
    required this.axisColor,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
  });

  factory _SimpleWaterfallVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleWaterfallVisuals(
          increaseColor: colorScheme.primary,
          decreaseColor: colorScheme.error,
          totalColor: colorScheme.secondary,
          connectorColor: colorScheme.outline,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.48),
          barRadius: 7,
          barWidthFactor: 0.58,
          maxBarWidth: 48,
          useGradient: true,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleWaterfallVisuals(
          increaseColor: colorScheme.primary,
          decreaseColor: colorScheme.error,
          totalColor: colorScheme.onSurfaceVariant,
          connectorColor: colorScheme.outline,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.68),
          barRadius: 4,
          barWidthFactor: 0.56,
          maxBarWidth: 42,
          useGradient: false,
        );
      case SimpleBarChartStyle.education:
        return _SimpleWaterfallVisuals(
          increaseColor: colorScheme.secondary,
          decreaseColor: colorScheme.error,
          totalColor: colorScheme.tertiary,
          connectorColor: colorScheme.outline,
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          barRadius: 6,
          barWidthFactor: 0.6,
          maxBarWidth: 48,
          useGradient: false,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleWaterfallVisuals(
          increaseColor: colorScheme.tertiary,
          decreaseColor: colorScheme.error,
          totalColor: colorScheme.primary,
          connectorColor: colorScheme.outline,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          barRadius: 8,
          barWidthFactor: 0.62,
          maxBarWidth: 50,
          useGradient: true,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleWaterfallVisuals(
          increaseColor: colorScheme.primary,
          decreaseColor: colorScheme.error,
          totalColor: colorScheme.secondary,
          connectorColor: colorScheme.outline,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          barRadius: 6,
          barWidthFactor: 0.58,
          maxBarWidth: 46,
          useGradient: true,
        );
    }
  }
}

class _DefaultWaterfallTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String valueLabel;
  final String value;
  final String total;

  const _DefaultWaterfallTooltip({
    required this.color,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.total,
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 7),
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
            const SizedBox(height: 8),
            _TooltipValueRow(label: valueLabel, value: value),
            const SizedBox(height: 4),
            _TooltipValueRow(label: 'Running total', value: total),
          ],
        ),
      ),
    );
  }
}

class _TooltipValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _TooltipValueRow({required this.label, required this.value});

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
              color: colorScheme.onInverseSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
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
