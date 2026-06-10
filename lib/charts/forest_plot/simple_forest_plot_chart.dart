import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleForestPlotValueFormatter = String Function(double value);
typedef SimpleForestPlotTapCallback =
    void Function(SimpleForestPlotData data, int index);
typedef SimpleForestPlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleForestPlotData data,
      int index,
      String formattedEstimate,
      String formattedLower,
      String formattedUpper,
      String? formattedWeight,
    );

class SimpleForestPlotData {
  final String label;
  final double estimate;
  final double lower;
  final double upper;
  final double? weight;
  final String? group;
  final Color? color;

  const SimpleForestPlotData({
    required this.label,
    required this.estimate,
    required this.lower,
    required this.upper,
    this.weight,
    this.group,
    this.color,
  });

  double get low => math.min(lower, upper);
  double get high => math.max(lower, upper);
}

/// A compact forest plot for treatment effects, experiment lift, risk ratios,
/// research summaries, policy comparisons, and confidence intervals.
class SimpleForestPlotChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(
    136,
    20,
    44,
    38,
  );

  final List<SimpleForestPlotData> data;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double referenceValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? intervalColor;
  final Color? markerColor;
  final Color? referenceColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeReference;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showIntervalLabels;
  final bool showWeights;
  final bool showReferenceLine;
  final bool showTooltip;
  final bool showActiveItem;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? intervalStrokeWidth;
  final double? markerSize;
  final double? minMarkerSize;
  final double? maxMarkerSize;
  final SimpleForestPlotValueFormatter? valueFormatter;
  final SimpleForestPlotValueFormatter? weightFormatter;
  final SimpleForestPlotTapCallback? onItemTap;
  final SimpleForestPlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleForestPlotChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.referenceValue = 0,
    this.height = 280,
    this.padding = _defaultPadding,
    this.palette,
    this.intervalColor,
    this.markerColor,
    this.referenceColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.includeReference = true,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = true,
    this.showIntervalLabels = false,
    this.showWeights = false,
    this.showReferenceLine = true,
    this.showTooltip = true,
    this.showActiveItem = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.intervalStrokeWidth,
    this.markerSize,
    this.minMarkerSize,
    this.maxMarkerSize,
    this.valueFormatter,
    this.weightFormatter,
    this.onItemTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(intervalStrokeWidth == null || intervalStrokeWidth > 0),
       assert(markerSize == null || markerSize >= 0),
       assert(minMarkerSize == null || minMarkerSize >= 0),
       assert(maxMarkerSize == null || maxMarkerSize >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleForestPlotVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where(
          (item) =>
              item.label.trim().isNotEmpty &&
              item.estimate.isFinite &&
              item.lower.isFinite &&
              item.upper.isFinite &&
              (item.weight == null || item.weight!.isFinite),
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedWeightFormatter = weightFormatter ?? _defaultWeightFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Forest plot, no data.',
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
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
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
          semanticLabel: _defaultSemanticLabel(visibleData, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleForestPlotChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            minValue: minValue,
            maxValue: maxValue,
            referenceValue: referenceValue,
            padding: padding,
            palette: palette,
            intervalColor: intervalColor ?? visuals.intervalColor,
            markerColor: markerColor ?? visuals.markerColor,
            referenceColor: referenceColor ?? visuals.referenceColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeReference: includeReference,
            showGrid: showGrid,
            showLabels: showLabels,
            showValues: showValues,
            showIntervalLabels: showIntervalLabels,
            showWeights: showWeights,
            showReferenceLine: showReferenceLine,
            showTooltip: showTooltip,
            showActiveItem: showActiveItem,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            intervalStrokeWidth: intervalStrokeWidth ?? visuals.strokeWidth,
            markerSize: markerSize ?? visuals.markerSize,
            minMarkerSize: minMarkerSize ?? visuals.minMarkerSize,
            maxMarkerSize: maxMarkerSize ?? visuals.maxMarkerSize,
            valueFormatter: formatter,
            weightFormatter: resolvedWeightFormatter,
            onItemTap: onItemTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleForestPlotData> data,
    SimpleForestPlotValueFormatter formatter,
  ) {
    final sample = data
        .take(4)
        .map(
          (item) =>
              '${item.label} ${formatter(item.estimate)} confidence interval '
              '${formatter(item.low)} to ${formatter(item.high)}',
        )
        .join(', ');
    final suffix = data.length > 4 ? ', and ${data.length - 4} more' : '';
    return 'Forest plot, ${data.length} intervals. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value.abs() >= 1000) {
      final precision = value.abs() >= 10000 ? 0 : 1;
      return '${(value / 1000).toStringAsFixed(precision)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static String _defaultWeightFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleForestPlotChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleForestPlotData> data;
  final double? minValue;
  final double? maxValue;
  final double referenceValue;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color intervalColor;
  final Color markerColor;
  final Color referenceColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeReference;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showIntervalLabels;
  final bool showWeights;
  final bool showReferenceLine;
  final bool showTooltip;
  final bool showActiveItem;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double intervalStrokeWidth;
  final double markerSize;
  final double minMarkerSize;
  final double maxMarkerSize;
  final SimpleForestPlotValueFormatter valueFormatter;
  final SimpleForestPlotValueFormatter weightFormatter;
  final SimpleForestPlotTapCallback? onItemTap;
  final SimpleForestPlotTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleForestPlotChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.minValue,
    required this.maxValue,
    required this.referenceValue,
    required this.padding,
    required this.palette,
    required this.intervalColor,
    required this.markerColor,
    required this.referenceColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeReference,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showIntervalLabels,
    required this.showWeights,
    required this.showReferenceLine,
    required this.showTooltip,
    required this.showActiveItem,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.intervalStrokeWidth,
    required this.markerSize,
    required this.minMarkerSize,
    required this.maxMarkerSize,
    required this.valueFormatter,
    required this.weightFormatter,
    required this.onItemTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleForestPlotChartView> createState() =>
      _SimpleForestPlotChartViewState();
}

class _SimpleForestPlotChartViewState extends State<_SimpleForestPlotChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int? _activeIndex;

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
  void didUpdateWidget(covariant _SimpleForestPlotChartView oldWidget) {
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
                      final index = _hitTest(details.localPosition);
                      _setActive(index);
                      if (index != null) {
                        widget.onItemTap?.call(widget.data[index], index);
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleForestPlotPainter(
                        data: widget.data,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        referenceValue: widget.referenceValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        intervalColor: widget.intervalColor,
                        markerColor: widget.markerColor,
                        referenceColor: widget.referenceColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        includeReference: widget.includeReference,
                        showGrid: widget.showGrid,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showIntervalLabels: widget.showIntervalLabels,
                        showWeights: widget.showWeights,
                        showReferenceLine: widget.showReferenceLine,
                        showActiveItem: widget.showActiveItem,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        gridLineCount: widget.gridLineCount,
                        intervalStrokeWidth: widget.intervalStrokeWidth,
                        markerSize: widget.markerSize,
                        minMarkerSize: widget.minMarkerSize,
                        maxMarkerSize: widget.maxMarkerSize,
                        valueFormatter: widget.valueFormatter,
                        weightFormatter: widget.weightFormatter,
                        activeIndex: _activeIndex,
                        progress: _animation.value,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeIndex != null)
                _buildTooltip(context, _activeIndex!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(int? index) {
    if (_activeIndex == index) {
      return;
    }
    setState(() => _activeIndex = index);
  }

  int? _hitTest(Offset position) {
    final geometry = _ForestGeometry.resolve(
      data: widget.data,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      referenceValue: widget.referenceValue,
      includeReference: widget.includeReference,
      markerSize: widget.markerSize,
      minMarkerSize: widget.minMarkerSize,
      maxMarkerSize: widget.maxMarkerSize,
    );
    for (final item in geometry.items) {
      if (item.hitRect.contains(position)) {
        return item.index;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, int index) {
    final item = widget.data[index];
    final formattedEstimate = widget.valueFormatter(item.estimate);
    final formattedLower = widget.valueFormatter(item.low);
    final formattedUpper = widget.valueFormatter(item.high);
    final formattedWeight = item.weight == null
        ? null
        : widget.weightFormatter(item.weight!);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          item,
          index,
          formattedEstimate,
          formattedLower,
          formattedUpper,
          formattedWeight,
        ) ??
        _DefaultForestPlotTooltip(
          title: item.label,
          rows: [
            _TooltipRow('Effect', formattedEstimate),
            _TooltipRow('Lower', formattedLower),
            _TooltipRow('Upper', formattedUpper),
            if (formattedWeight != null) _TooltipRow('Weight', formattedWeight),
            if (item.group != null) _TooltipRow('Group', item.group!),
          ],
        );
    final geometry = _ForestGeometry.resolve(
      data: widget.data,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      referenceValue: widget.referenceValue,
      includeReference: widget.includeReference,
      markerSize: widget.markerSize,
      minMarkerSize: widget.minMarkerSize,
      maxMarkerSize: widget.maxMarkerSize,
    );
    final anchor = geometry.items[index].markerCenter;
    final maxLeft = math.max(8.0, widget.width - 226);
    final maxTop = math.max(8.0, widget.height - 138);
    final left = (anchor.dx + 12).clamp(8.0, maxLeft).toDouble();
    final top = (anchor.dy - 56).clamp(8.0, maxTop).toDouble();
    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleForestPlotPainter extends CustomPainter {
  final List<SimpleForestPlotData> data;
  final double? minValue;
  final double? maxValue;
  final double referenceValue;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color intervalColor;
  final Color markerColor;
  final Color referenceColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeReference;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showIntervalLabels;
  final bool showWeights;
  final bool showReferenceLine;
  final bool showActiveItem;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double intervalStrokeWidth;
  final double markerSize;
  final double minMarkerSize;
  final double maxMarkerSize;
  final SimpleForestPlotValueFormatter valueFormatter;
  final SimpleForestPlotValueFormatter weightFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleForestPlotPainter({
    required this.data,
    required this.minValue,
    required this.maxValue,
    required this.referenceValue,
    required this.padding,
    required this.palette,
    required this.intervalColor,
    required this.markerColor,
    required this.referenceColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeReference,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showIntervalLabels,
    required this.showWeights,
    required this.showReferenceLine,
    required this.showActiveItem,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.intervalStrokeWidth,
    required this.markerSize,
    required this.minMarkerSize,
    required this.maxMarkerSize,
    required this.valueFormatter,
    required this.weightFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _ForestGeometry.resolve(
      data: data,
      size: size,
      padding: padding,
      minValue: minValue,
      maxValue: maxValue,
      referenceValue: referenceValue,
      includeReference: includeReference,
      markerSize: markerSize,
      minMarkerSize: minMarkerSize,
      maxMarkerSize: maxMarkerSize,
    );
    if (geometry.items.isEmpty) {
      return;
    }

    _drawReferenceBands(canvas, geometry);
    if (showGrid) {
      _drawGrid(canvas, geometry);
    }
    if (showReferenceLine) {
      _drawReferenceLine(
        canvas,
        geometry,
        referenceValue,
        'Ref',
        referenceColor,
      );
    }
    for (final line in referenceLines) {
      _drawReferenceLine(
        canvas,
        geometry,
        line.value,
        line.label,
        line.color ?? axisColor,
        strokeWidth: line.strokeWidth,
        dashed: line.lineStyle == SimpleChartReferenceLineStyle.dashed,
        showLabel: line.showLabel,
      );
    }
    for (final item in geometry.items) {
      _drawItem(canvas, geometry, item);
    }
  }

  void _drawReferenceBands(Canvas canvas, _ForestGeometry geometry) {
    for (final band in referenceBands) {
      final left = geometry.xFor(band.from);
      final right = geometry.xFor(band.to);
      final rect = Rect.fromLTRB(
        math.min(left, right),
        geometry.plot.top,
        math.max(left, right),
        geometry.plot.bottom,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = (band.color ?? referenceColor).withValues(
            alpha: band.opacity,
          )
          ..style = PaintingStyle.fill,
      );
      if (band.showLabel && band.label != null) {
        _drawText(
          canvas,
          band.label!,
          Rect.fromLTWH(rect.left + 4, rect.top + 3, rect.width - 8, 14),
          valueStyle.copyWith(color: axisColor),
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, _ForestGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 0; index < gridLineCount; index++) {
      final ratio = gridLineCount == 1 ? 0.0 : index / (gridLineCount - 1);
      final x = geometry.plot.left + geometry.plot.width * ratio;
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
      );
      final value = geometry.minValue + geometry.valueRange * ratio;
      _drawText(
        canvas,
        valueFormatter(value),
        Rect.fromCenter(
          center: Offset(x, geometry.plot.bottom + 12),
          width: 54,
          height: 14,
        ),
        valueStyle.copyWith(color: axisColor),
        align: TextAlign.center,
      );
    }
    for (final item in geometry.items) {
      canvas.drawLine(
        Offset(geometry.plot.left, item.centerY),
        Offset(geometry.plot.right, item.centerY),
        Paint()
          ..color = gridColor.withValues(alpha: 0.36)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _drawReferenceLine(
    Canvas canvas,
    _ForestGeometry geometry,
    double value,
    String? label,
    Color color, {
    double strokeWidth = 1.5,
    bool dashed = true,
    bool showLabel = true,
  }) {
    if (value < geometry.minValue || value > geometry.maxValue) {
      return;
    }
    final x = geometry.xFor(value);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    if (dashed) {
      _drawDashedLine(
        canvas,
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
      );
    }
    if (showLabel && label != null && label.trim().isNotEmpty) {
      _drawText(
        canvas,
        label,
        Rect.fromCenter(
          center: Offset(x, geometry.plot.top - 8),
          width: 54,
          height: 14,
        ),
        valueStyle.copyWith(color: color, fontWeight: FontWeight.w800),
        align: TextAlign.center,
      );
    }
  }

  void _drawItem(
    Canvas canvas,
    _ForestGeometry geometry,
    _ForestItemLayout item,
  ) {
    final active = showActiveItem && activeIndex == item.index;
    final color = active
        ? activeColor
        : data[item.index].color ?? _colorFor(item.index);
    final start = Offset(item.intervalStart, item.centerY);
    final end = Offset(
      item.intervalStart + (item.intervalEnd - item.intervalStart) * progress,
      item.centerY,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color.withValues(alpha: active ? 0.92 : 0.72)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = active
            ? intervalStrokeWidth + 1.2
            : intervalStrokeWidth,
    );
    for (final x in [item.intervalStart, end.dx]) {
      canvas.drawLine(
        Offset(x, item.centerY - 5),
        Offset(x, item.centerY + 5),
        Paint()
          ..color = color.withValues(alpha: active ? 0.92 : 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active
              ? intervalStrokeWidth + 0.8
              : intervalStrokeWidth,
      );
    }
    final markerCenter = Offset(
      geometry.xFor(data[item.index].estimate) * progress +
          item.intervalStart * (1 - progress),
      item.centerY,
    );
    final markerRect = Rect.fromCenter(
      center: markerCenter,
      width: item.markerSize + (active ? 3 : 0),
      height: item.markerSize + (active ? 3 : 0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(markerRect, const Radius.circular(3)),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(markerRect, const Radius.circular(3)),
      Paint()
        ..color = axisColor.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (showLabels) {
      _drawText(
        canvas,
        data[item.index].label,
        Rect.fromLTRB(
          0,
          item.centerY - 9,
          geometry.plot.left - 10,
          item.centerY + 9,
        ),
        labelStyle.copyWith(color: color),
        align: TextAlign.right,
      );
    }
    if (showValues) {
      final intervalText = showIntervalLabels
          ? '${valueFormatter(data[item.index].estimate)} '
                '[${valueFormatter(data[item.index].low)}, '
                '${valueFormatter(data[item.index].high)}]'
          : valueFormatter(data[item.index].estimate);
      _drawText(
        canvas,
        intervalText,
        Rect.fromLTWH(
          geometry.plot.right + 8,
          item.centerY - 8,
          math.max(0, geometry.size.width - geometry.plot.right - 10),
          16,
        ),
        valueStyle.copyWith(color: color),
      );
    }
    if (showWeights &&
        data[item.index].weight != null &&
        geometry.plot.left > 112) {
      _drawText(
        canvas,
        weightFormatter(data[item.index].weight!),
        Rect.fromLTWH(4, item.centerY + 7, geometry.plot.left - 14, 14),
        valueStyle.copyWith(color: axisColor),
        align: TextAlign.right,
      );
    }
  }

  Color _colorFor(int index) {
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return markerColor;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (end - start).distance;
    if (total <= 0) {
      return;
    }
    final direction = (end - start) / total;
    var distance = 0.0;
    while (distance < total) {
      final from = start + direction * distance;
      final to = start + direction * math.min(distance + dash, total);
      canvas.drawLine(from, to, paint);
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
  bool shouldRepaint(covariant _SimpleForestPlotPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.referenceValue != referenceValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.intervalColor != intervalColor ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.referenceColor != referenceColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeReference != includeReference ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showIntervalLabels != showIntervalLabels ||
        oldDelegate.showWeights != showWeights ||
        oldDelegate.showReferenceLine != showReferenceLine ||
        oldDelegate.showActiveItem != showActiveItem ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.intervalStrokeWidth != intervalStrokeWidth ||
        oldDelegate.markerSize != markerSize ||
        oldDelegate.minMarkerSize != minMarkerSize ||
        oldDelegate.maxMarkerSize != maxMarkerSize ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _ForestGeometry {
  final Size size;
  final Rect plot;
  final double minValue;
  final double maxValue;
  final List<_ForestItemLayout> items;

  const _ForestGeometry({
    required this.size,
    required this.plot,
    required this.minValue,
    required this.maxValue,
    required this.items,
  });

  double get valueRange => math.max(0.0001, maxValue - minValue);

  double xFor(double value) {
    final ratio = ((value - minValue) / valueRange).clamp(0.0, 1.0);
    return plot.left + plot.width * ratio;
  }

  factory _ForestGeometry.resolve({
    required List<SimpleForestPlotData> data,
    required Size size,
    required EdgeInsets padding,
    required double? minValue,
    required double? maxValue,
    required double referenceValue,
    required bool includeReference,
    required double markerSize,
    required double minMarkerSize,
    required double maxMarkerSize,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    if (data.isEmpty || plot.width <= 0 || plot.height <= 0) {
      return _ForestGeometry(
        size: size,
        plot: plot,
        minValue: 0,
        maxValue: 1,
        items: const [],
      );
    }
    var low = minValue ?? data.map((item) => item.low).reduce(math.min);
    var high = maxValue ?? data.map((item) => item.high).reduce(math.max);
    if (includeReference) {
      low = math.min(low, referenceValue);
      high = math.max(high, referenceValue);
    }
    if (low == high) {
      low -= 1;
      high += 1;
    }
    final paddingValue = (high - low) * 0.06;
    if (minValue == null) low -= paddingValue;
    if (maxValue == null) high += paddingValue;
    final geometry = _ForestGeometry(
      size: size,
      plot: plot,
      minValue: low,
      maxValue: high,
      items: const [],
    );
    final maxWeight = data.fold<double>(
      0,
      (maxWeight, item) => math.max(maxWeight, item.weight ?? 0),
    );
    final rowHeight = plot.height / data.length;
    final items = <_ForestItemLayout>[];
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final centerY = plot.top + rowHeight * (index + 0.5);
      final weightRatio = item.weight == null || maxWeight <= 0
          ? 0.5
          : (item.weight! / maxWeight).clamp(0.0, 1.0);
      final resolvedMarkerSize = item.weight == null
          ? markerSize
          : minMarkerSize +
                (maxMarkerSize - minMarkerSize) * math.sqrt(weightRatio);
      final intervalStart = geometry.xFor(item.low);
      final intervalEnd = geometry.xFor(item.high);
      items.add(
        _ForestItemLayout(
          index: index,
          centerY: centerY,
          intervalStart: intervalStart,
          intervalEnd: intervalEnd,
          markerCenter: Offset(geometry.xFor(item.estimate), centerY),
          markerSize: resolvedMarkerSize,
          hitRect: Rect.fromLTRB(
            math.min(intervalStart, intervalEnd) - 12,
            centerY - math.max(16, rowHeight / 2),
            math.max(intervalStart, intervalEnd) + 12,
            centerY + math.max(16, rowHeight / 2),
          ),
        ),
      );
    }
    return _ForestGeometry(
      size: size,
      plot: plot,
      minValue: low,
      maxValue: high,
      items: items,
    );
  }
}

class _ForestItemLayout {
  final int index;
  final double centerY;
  final double intervalStart;
  final double intervalEnd;
  final Offset markerCenter;
  final double markerSize;
  final Rect hitRect;

  const _ForestItemLayout({
    required this.index,
    required this.centerY,
    required this.intervalStart,
    required this.intervalEnd,
    required this.markerCenter,
    required this.markerSize,
    required this.hitRect,
  });
}

class _SimpleForestPlotVisuals {
  final Color intervalColor;
  final Color markerColor;
  final Color referenceColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double strokeWidth;
  final double markerSize;
  final double minMarkerSize;
  final double maxMarkerSize;

  const _SimpleForestPlotVisuals({
    required this.intervalColor,
    required this.markerColor,
    required this.referenceColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.strokeWidth,
    required this.markerSize,
    required this.minMarkerSize,
    required this.maxMarkerSize,
  });

  factory _SimpleForestPlotVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleForestPlotVisuals(
          intervalColor: colorScheme.primary,
          markerColor: colorScheme.primary,
          referenceColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          activeColor: colorScheme.tertiary,
          strokeWidth: 2.4,
          markerSize: 10,
          minMarkerSize: 7,
          maxMarkerSize: 17,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleForestPlotVisuals(
          intervalColor: colorScheme.primary,
          markerColor: colorScheme.primary,
          referenceColor: colorScheme.onSurface,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          activeColor: colorScheme.onSurface,
          strokeWidth: 2,
          markerSize: 9,
          minMarkerSize: 6,
          maxMarkerSize: 15,
        );
      case SimpleBarChartStyle.education:
        return _SimpleForestPlotVisuals(
          intervalColor: colorScheme.secondary,
          markerColor: colorScheme.secondary,
          referenceColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          activeColor: colorScheme.primary,
          strokeWidth: 2.2,
          markerSize: 10,
          minMarkerSize: 7,
          maxMarkerSize: 17,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleForestPlotVisuals(
          intervalColor: colorScheme.tertiary,
          markerColor: colorScheme.tertiary,
          referenceColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          activeColor: colorScheme.primary,
          strokeWidth: 2.6,
          markerSize: 11,
          minMarkerSize: 7,
          maxMarkerSize: 18,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleForestPlotVisuals(
          intervalColor: colorScheme.primary,
          markerColor: colorScheme.primary,
          referenceColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: colorScheme.tertiary,
          strokeWidth: 2.2,
          markerSize: 10,
          minMarkerSize: 7,
          maxMarkerSize: 17,
        );
    }
  }
}

class _DefaultForestPlotTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultForestPlotTooltip({required this.title, required this.rows});

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
        constraints: const BoxConstraints(maxWidth: 240),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 50, child: Text(row.label)),
                        Flexible(
                          child: Text(
                            row.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
