import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleDumbbellValueFormatter = String Function(double value);
typedef SimpleDumbbellTapCallback =
    void Function(SimpleDumbbellChartData data, int index);
typedef SimpleDumbbellTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleDumbbellChartData data,
      int index,
      String formattedStart,
      String formattedEnd,
      String formattedDelta,
    );

class SimpleDumbbellChartData {
  final String label;
  final double start;
  final double end;
  final String? startLabel;
  final String? endLabel;
  final Color? startColor;
  final Color? endColor;
  final Color? connectorColor;

  const SimpleDumbbellChartData({
    required this.label,
    required this.start,
    required this.end,
    this.startLabel,
    this.endLabel,
    this.startColor,
    this.endColor,
    this.connectorColor,
  });

  double get delta => end - start;
}

/// A lightweight two-point comparison chart for before/after or target/current
/// stories.
class SimpleDumbbellChart extends StatelessWidget {
  static const EdgeInsets _verticalPadding = EdgeInsets.fromLTRB(
    44,
    18,
    18,
    34,
  );
  static const EdgeInsets _horizontalPadding = EdgeInsets.fromLTRB(
    92,
    18,
    58,
    30,
  );

  final List<SimpleDumbbellChartData> data;
  final SimpleBarChartOrientation orientation;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets? padding;
  final Color? startColor;
  final Color? endColor;
  final Color? connectorColor;
  final Color? positiveColor;
  final Color? negativeColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showDelta;
  final bool showTooltip;
  final bool showActiveSegment;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? markerRadius;
  final double? connectorWidth;
  final SimpleDumbbellValueFormatter? valueFormatter;
  final SimpleDumbbellValueFormatter? deltaFormatter;
  final SimpleDumbbellTapCallback? onSegmentTap;
  final SimpleDumbbellTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleDumbbellChart({
    super.key,
    required this.data,
    this.orientation = SimpleBarChartOrientation.horizontal,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding,
    this.startColor,
    this.endColor,
    this.connectorColor,
    this.positiveColor,
    this.negativeColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showDelta = true,
    this.showTooltip = true,
    this.showActiveSegment = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.markerRadius,
    this.connectorWidth,
    this.valueFormatter,
    this.deltaFormatter,
    this.onSegmentTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(markerRadius == null || markerRadius >= 0),
       assert(connectorWidth == null || connectorWidth > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleDumbbellVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.start.isFinite && item.end.isFinite)
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedDeltaFormatter = deltaFormatter ?? _defaultDeltaFormatter;
    final resolvedPadding =
        padding ??
        (orientation == SimpleBarChartOrientation.vertical
            ? _verticalPadding
            : _horizontalPadding);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 380.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Dumbbell chart, no data.',
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
            visibleData,
            formatter,
            resolvedDeltaFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleDumbbellChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            orientation: orientation,
            minValue: minValue,
            maxValue: maxValue,
            padding: resolvedPadding,
            startColor: startColor ?? visuals.startColor,
            endColor: endColor ?? visuals.endColor,
            connectorColor: connectorColor ?? visuals.connectorColor,
            positiveColor: positiveColor ?? visuals.positiveColor,
            negativeColor: negativeColor ?? visuals.negativeColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showDelta: showDelta,
            showTooltip: showTooltip,
            showActiveSegment: showActiveSegment,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            markerRadius: markerRadius ?? visuals.markerRadius,
            connectorWidth: connectorWidth ?? visuals.connectorWidth,
            valueFormatter: formatter,
            deltaFormatter: resolvedDeltaFormatter,
            onSegmentTap: onSegmentTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(
    List<SimpleDumbbellChartData> visibleData,
    SimpleDumbbellValueFormatter formatter,
    SimpleDumbbellValueFormatter resolvedDeltaFormatter,
  ) {
    final visibleItems = visibleData
        .take(5)
        .map(
          (item) =>
              '${item.label} ${formatter(item.start)} to '
              '${formatter(item.end)}, change '
              '${resolvedDeltaFormatter(item.delta)}',
        )
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 5);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'item' : 'items';
    return 'Dumbbell chart, ${visibleData.length} $countLabel. '
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

class _SimpleDumbbellChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleDumbbellChartData> data;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color startColor;
  final Color endColor;
  final Color connectorColor;
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showDelta;
  final bool showTooltip;
  final bool showActiveSegment;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double markerRadius;
  final double connectorWidth;
  final SimpleDumbbellValueFormatter valueFormatter;
  final SimpleDumbbellValueFormatter deltaFormatter;
  final SimpleDumbbellTapCallback? onSegmentTap;
  final SimpleDumbbellTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleDumbbellChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.startColor,
    required this.endColor,
    required this.connectorColor,
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showDelta,
    required this.showTooltip,
    required this.showActiveSegment,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.markerRadius,
    required this.connectorWidth,
    required this.valueFormatter,
    required this.deltaFormatter,
    required this.onSegmentTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleDumbbellChartView> createState() =>
      _SimpleDumbbellChartViewState();
}

class _SimpleDumbbellChartViewState extends State<_SimpleDumbbellChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveSegment ||
        widget.onSegmentTap != null;

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
                painter: _SimpleDumbbellPainter(
                  data: widget.data,
                  orientation: widget.orientation,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  startColor: widget.startColor,
                  endColor: widget.endColor,
                  connectorColor: widget.connectorColor,
                  positiveColor: widget.positiveColor,
                  negativeColor: widget.negativeColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showDelta: widget.showDelta,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  markerRadius: widget.markerRadius,
                  connectorWidth: widget.connectorWidth,
                  valueFormatter: widget.valueFormatter,
                  deltaFormatter: widget.deltaFormatter,
                  activeIndex: widget.showActiveSegment ? _activeIndex : null,
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
                        widget.onSegmentTap?.call(widget.data[index], index);
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
    if (!plot.inflate(10).contains(position)) return null;
    if (widget.data.isEmpty) return null;

    if (widget.orientation == SimpleBarChartOrientation.horizontal) {
      final segmentHeight = plot.height / widget.data.length;
      final index = ((position.dy - plot.top) / segmentHeight).floor();
      return index >= 0 && index < widget.data.length ? index : null;
    }

    final segmentWidth = plot.width / widget.data.length;
    final index = ((position.dx - plot.left) / segmentWidth).floor();
    return index >= 0 && index < widget.data.length ? index : null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final item = widget.data[index];
    final formattedStart = widget.valueFormatter(item.start);
    final formattedEnd = widget.valueFormatter(item.end);
    final formattedDelta = widget.deltaFormatter(item.delta);
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 190.0;
    const tooltipHeight = 94.0;
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
            item,
            index,
            formattedStart,
            formattedEnd,
            formattedDelta,
          ) ??
          _DefaultDumbbellTooltip(
            startColor: _startColor(item),
            endColor: _endColor(item),
            deltaColor: _deltaColor(item),
            title: item.label,
            startLabel: item.startLabel ?? 'Start',
            endLabel: item.endLabel ?? 'End',
            startValue: formattedStart,
            endValue: formattedEnd,
            deltaValue: formattedDelta,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final plot = _plot(size);
    final range = _resolveRange();
    final item = widget.data[index];

    if (widget.orientation == SimpleBarChartOrientation.horizontal) {
      final segmentHeight = plot.height / widget.data.length;
      final y = plot.top + segmentHeight * index + segmentHeight / 2;
      final startX = _xForValue(item.start, plot, range);
      final endX = _xForValue(item.end, plot, range);
      return Offset(math.max(startX, endX), y);
    }

    final segmentWidth = plot.width / widget.data.length;
    final x = plot.left + segmentWidth * index + segmentWidth / 2;
    final startY = _yForValue(item.start, plot, range);
    final endY = _yForValue(item.end, plot, range);
    return Offset(x, math.min(startY, endY));
  }

  Rect _plot(Size size) {
    return Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }

  _DumbbellRange _resolveRange() {
    return _resolveDumbbellRange(
      data: widget.data,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
  }

  double _xForValue(double value, Rect plot, _DumbbellRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.left + normalized * plot.width;
  }

  double _yForValue(double value, Rect plot, _DumbbellRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  Color _startColor(SimpleDumbbellChartData item) {
    return item.startColor ?? widget.startColor;
  }

  Color _endColor(SimpleDumbbellChartData item) {
    return item.endColor ?? widget.endColor;
  }

  Color _deltaColor(SimpleDumbbellChartData item) {
    if (item.delta == 0) return widget.connectorColor;
    return item.delta > 0 ? widget.positiveColor : widget.negativeColor;
  }
}

class _SimpleDumbbellPainter extends CustomPainter {
  final List<SimpleDumbbellChartData> data;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color startColor;
  final Color endColor;
  final Color connectorColor;
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showDelta;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double markerRadius;
  final double connectorWidth;
  final SimpleDumbbellValueFormatter valueFormatter;
  final SimpleDumbbellValueFormatter deltaFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleDumbbellPainter({
    required this.data,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.startColor,
    required this.endColor,
    required this.connectorColor,
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showDelta,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.markerRadius,
    required this.connectorWidth,
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
    if (plot.width <= 0 || plot.height <= 0 || data.isEmpty) return;

    final range = _resolveRange();
    if (orientation == SimpleBarChartOrientation.horizontal) {
      _paintHorizontal(canvas, plot, range);
    } else {
      _paintVertical(canvas, plot, range);
    }
  }

  _DumbbellRange _resolveRange() {
    return _resolveDumbbellRange(
      data: data,
      minValue: minValue,
      maxValue: maxValue,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
  }

  void _paintHorizontal(Canvas canvas, Rect plot, _DumbbellRange range) {
    _drawHorizontalBands(canvas, plot, range);
    _drawHorizontalActiveCategory(canvas, plot);
    if (showGrid) {
      _drawHorizontalGrid(canvas, plot, range);
    }
    _drawHorizontalAxis(canvas, plot);
    _drawHorizontalReferenceLines(canvas, plot, range);
    _drawHorizontalDumbbells(canvas, plot, range);
    _drawHorizontalLabels(canvas, plot);
  }

  void _paintVertical(Canvas canvas, Rect plot, _DumbbellRange range) {
    _drawVerticalBands(canvas, plot, range);
    _drawVerticalActiveCategory(canvas, plot);
    if (showGrid) {
      _drawVerticalGrid(canvas, plot, range);
    }
    _drawVerticalAxis(canvas, plot);
    _drawVerticalReferenceLines(canvas, plot, range);
    _drawVerticalDumbbells(canvas, plot, range);
    _drawVerticalLabels(canvas, plot);
  }

  double _xForValue(double value, Rect plot, _DumbbellRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.left + normalized * plot.width;
  }

  double _yForValue(double value, Rect plot, _DumbbellRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  void _drawHorizontalGrid(Canvas canvas, Rect plot, _DumbbellRange range) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value = range.min + range.span * (index / gridLineCount);
      final x = _xForValue(value, plot, range);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);

      final painter = _textPainter(
        valueFormatter(value),
        labelStyle.copyWith(color: labelStyle.color?.withValues(alpha: 0.72)),
        textAlign: TextAlign.center,
      )..layout();
      painter.paint(canvas, Offset(x - painter.width / 2, plot.bottom + 8));
    }
  }

  void _drawVerticalGrid(Canvas canvas, Rect plot, _DumbbellRange range) {
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

  void _drawHorizontalAxis(Canvas canvas, Rect plot) {
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1.1,
    );
  }

  void _drawVerticalAxis(Canvas canvas, Rect plot) {
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1.1,
    );
  }

  void _drawHorizontalBands(Canvas canvas, Rect plot, _DumbbellRange range) {
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;
      final x1 = _xForValue(band.from, plot, range);
      final x2 = _xForValue(band.to, plot, range);
      final left = math.min(x1, x2);
      final right = math.max(x1, x2);
      if (right < plot.left || left > plot.right) continue;
      final rect = Rect.fromLTRB(
        math.max(plot.left, left),
        plot.top,
        math.min(plot.right, right),
        plot.bottom,
      );
      if (rect.width <= 0.5) continue;
      final color = band.color ?? endColor;
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      _drawBandLabel(canvas, band, rect.topLeft, Axis.vertical, plot, color);
    }
  }

  void _drawVerticalBands(Canvas canvas, Rect plot, _DumbbellRange range) {
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
      final color = band.color ?? endColor;
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      _drawBandLabel(canvas, band, rect.topRight, Axis.horizontal, plot, color);
    }
  }

  void _drawBandLabel(
    Canvas canvas,
    SimpleChartReferenceBand band,
    Offset anchor,
    Axis axis,
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
    final preferredX = axis == Axis.horizontal
        ? anchor.dx - width - 6
        : anchor.dx + 6;
    final preferredY = axis == Axis.horizontal ? anchor.dy + 4 : anchor.dy + 6;
    final x = _safeClamp(preferredX, plot.left + 2, plot.right - width - 2);
    final y = _safeClamp(preferredY, plot.top + 2, plot.bottom - height - 2);
    final rect = Rect.fromLTWH(x, y, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = color.withValues(alpha: 0.14),
    );
    painter.paint(canvas, Offset(x + labelPadding.left, y + labelPadding.top));
  }

  void _drawHorizontalReferenceLines(
    Canvas canvas,
    Rect plot,
    _DumbbellRange range,
  ) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final x = _xForValue(line.value, plot, range);
      if (x < plot.left - 1 || x > plot.right + 1) continue;
      final color = line.color ?? axisColor.withValues(alpha: 0.82);
      _drawStyledLine(
        canvas,
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        _referencePaint(line, color),
        line.lineStyle,
      );
      _drawReferenceLabel(
        canvas,
        line,
        valueFormatter(line.value),
        Offset(x, plot.top),
        Axis.vertical,
        plot,
        color,
      );
    }
  }

  void _drawVerticalReferenceLines(
    Canvas canvas,
    Rect plot,
    _DumbbellRange range,
  ) {
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
        Axis.horizontal,
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
    Axis lineAxis,
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
    final preferredX = lineAxis == Axis.horizontal
        ? anchor.dx - width - 6
        : anchor.dx + 6;
    final preferredY = lineAxis == Axis.horizontal
        ? anchor.dy - height - 4
        : anchor.dy + 4;
    final x = _safeClamp(preferredX, plot.left + 2, plot.right - width - 2);
    final y = _safeClamp(preferredY, plot.top + 2, plot.bottom - height - 2);
    final rect = Rect.fromLTWH(x, y, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = color.withValues(alpha: 0.1),
    );
    painter.paint(canvas, Offset(x + labelPadding.left, y + labelPadding.top));
  }

  void _drawHorizontalActiveCategory(Canvas canvas, Rect plot) {
    final index = activeIndex;
    if (index == null || index < 0 || index >= data.length) return;
    final segmentHeight = plot.height / data.length;
    final rect = Rect.fromLTWH(
      plot.left,
      plot.top + segmentHeight * index,
      plot.width,
      segmentHeight,
    );
    final color = activeColor ?? _deltaColor(data[index]);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.06));
  }

  void _drawVerticalActiveCategory(Canvas canvas, Rect plot) {
    final index = activeIndex;
    if (index == null || index < 0 || index >= data.length) return;
    final segmentWidth = plot.width / data.length;
    final rect = Rect.fromLTWH(
      plot.left + segmentWidth * index,
      plot.top,
      segmentWidth,
      plot.height,
    );
    final color = activeColor ?? _deltaColor(data[index]);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.06));
  }

  void _drawHorizontalDumbbells(
    Canvas canvas,
    Rect plot,
    _DumbbellRange range,
  ) {
    final segmentHeight = plot.height / data.length;
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final y = plot.top + segmentHeight * index + segmentHeight / 2;
      final startX = _xForValue(item.start, plot, range);
      final targetEndX = _xForValue(item.end, plot, range);
      final endX = startX + (targetEndX - startX) * progress;
      final start = Offset(startX, y);
      final end = Offset(endX, y);
      final connector = _connectorColor(item);
      final isActive = index == activeIndex;

      _drawConnector(canvas, start, end, connector, isActive);
      _drawMarker(canvas, start, _startColor(item), isActive, hollow: true);
      _drawMarker(canvas, end, _endColor(item), isActive);

      if (showValues && segmentHeight >= 24) {
        _drawHorizontalValues(canvas, item, start, end, plot);
      }
    }
  }

  void _drawVerticalDumbbells(Canvas canvas, Rect plot, _DumbbellRange range) {
    final segmentWidth = plot.width / data.length;
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final x = plot.left + segmentWidth * index + segmentWidth / 2;
      final startY = _yForValue(item.start, plot, range);
      final targetEndY = _yForValue(item.end, plot, range);
      final endY = startY + (targetEndY - startY) * progress;
      final start = Offset(x, startY);
      final end = Offset(x, endY);
      final connector = _connectorColor(item);
      final isActive = index == activeIndex;

      _drawConnector(canvas, start, end, connector, isActive);
      _drawMarker(canvas, start, _startColor(item), isActive, hollow: true);
      _drawMarker(canvas, end, _endColor(item), isActive);

      if (showValues && segmentWidth >= 34) {
        _drawVerticalValues(canvas, item, start, end, plot);
      }
    }
  }

  void _drawConnector(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    bool active,
  ) {
    if ((end - start).distance <= 0.5) return;
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color.withValues(alpha: active ? 0.86 : 0.52)
        ..strokeWidth = active ? connectorWidth + 1.2 : connectorWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawMarker(
    Canvas canvas,
    Offset center,
    Color color,
    bool active, {
    bool hollow = false,
  }) {
    final radius = markerRadius * (0.38 + progress * 0.62);
    if (active) {
      final activeMarkerColor = activeColor ?? color;
      canvas.drawCircle(
        center,
        radius + 5,
        Paint()..color = activeMarkerColor.withValues(alpha: 0.14),
      );
      canvas.drawCircle(
        center,
        radius + 2,
        Paint()
          ..color = activeMarkerColor.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (hollow) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(
        center,
        math.max(1, radius - 2.5),
        Paint()..color = color.withValues(alpha: 0.1),
      );
      return;
    }

    canvas.drawCircle(
      center,
      radius + 1.6,
      Paint()..color = color.withValues(alpha: 0.18),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  void _drawHorizontalValues(
    Canvas canvas,
    SimpleDumbbellChartData item,
    Offset start,
    Offset end,
    Rect plot,
  ) {
    final startPainter = _textPainter(valueFormatter(item.start), valueStyle)
      ..layout();
    final endPainter = _textPainter(valueFormatter(item.end), valueStyle)
      ..layout();
    final startLeft = _safeClamp(
      start.dx - startPainter.width / 2,
      plot.left + 2,
      plot.right - startPainter.width - 2,
    );
    final endLeft = _safeClamp(
      end.dx - endPainter.width / 2,
      plot.left + 2,
      plot.right - endPainter.width - 2,
    );
    final valueTop = _safeClamp(
      start.dy - markerRadius - startPainter.height - 5,
      plot.top + 2,
      plot.bottom - startPainter.height - 2,
    );
    startPainter.paint(canvas, Offset(startLeft, valueTop));
    endPainter.paint(canvas, Offset(endLeft, valueTop));

    if (!showDelta) return;
    final deltaColor = _deltaColor(item);
    final painter = _textPainter(
      deltaFormatter(item.delta),
      valueStyle.copyWith(color: deltaColor),
    )..layout();
    final preferredX = item.delta >= 0
        ? math.max(start.dx, end.dx) + markerRadius + 7
        : math.min(start.dx, end.dx) - markerRadius - painter.width - 7;
    final x = _safeClamp(
      preferredX,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = _safeClamp(
      start.dy - painter.height / 2,
      plot.top + 2,
      plot.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
  }

  void _drawVerticalValues(
    Canvas canvas,
    SimpleDumbbellChartData item,
    Offset start,
    Offset end,
    Rect plot,
  ) {
    final topPoint = start.dy < end.dy ? start : end;
    final value = start.dy < end.dy ? item.start : item.end;
    final painter = _textPainter(valueFormatter(value), valueStyle)..layout();
    final x = _safeClamp(
      topPoint.dx - painter.width / 2,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = _safeClamp(
      topPoint.dy - markerRadius - painter.height - 5,
      plot.top + 2,
      plot.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));

    if (!showDelta) return;
    final deltaPainter = _textPainter(
      deltaFormatter(item.delta),
      valueStyle.copyWith(color: _deltaColor(item)),
    )..layout();
    final midY = (start.dy + end.dy) / 2;
    final deltaX = _safeClamp(
      start.dx + markerRadius + 7,
      plot.left + 2,
      plot.right - deltaPainter.width - 2,
    );
    final deltaY = _safeClamp(
      midY - deltaPainter.height / 2,
      plot.top + 2,
      plot.bottom - deltaPainter.height - 2,
    );
    deltaPainter.paint(canvas, Offset(deltaX, deltaY));
  }

  void _drawHorizontalLabels(Canvas canvas, Rect plot) {
    final segmentHeight = plot.height / data.length;
    final maxLabelCount = math.max(1, plot.height / 24).floor();
    final labelEvery = math.max(1, (data.length / maxLabelCount).ceil());
    final maxWidth = math.max(28.0, padding.left - 14);

    for (var index = 0; index < data.length; index++) {
      if (index % labelEvery != 0) continue;
      final y = plot.top + segmentHeight * index + segmentHeight / 2;
      final painter = _textPainter(
        data[index].label,
        labelStyle,
        maxWidth: maxWidth,
        textAlign: TextAlign.right,
      )..layout(maxWidth: maxWidth);
      painter.paint(
        canvas,
        Offset(plot.left - painter.width - 8, y - painter.height / 2),
      );
    }
  }

  void _drawVerticalLabels(Canvas canvas, Rect plot) {
    final segmentWidth = plot.width / data.length;
    final maxLabelCount = math.max(1, plot.width / 50).floor();
    final labelEvery = math.max(1, (data.length / maxLabelCount).ceil());

    for (var index = 0; index < data.length; index++) {
      if (index % labelEvery != 0) continue;
      final x = plot.left + segmentWidth * index + segmentWidth / 2;
      final maxWidth = math.max(18.0, segmentWidth * 0.92);
      final painter = _textPainter(
        data[index].label,
        labelStyle,
        maxWidth: maxWidth,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x - painter.width / 2, plot.bottom + 8));
    }
  }

  Color _startColor(SimpleDumbbellChartData item) {
    return item.startColor ?? startColor;
  }

  Color _endColor(SimpleDumbbellChartData item) {
    return item.endColor ?? endColor;
  }

  Color _connectorColor(SimpleDumbbellChartData item) {
    return item.connectorColor ?? _deltaColor(item).withValues(alpha: 0.9);
  }

  Color _deltaColor(SimpleDumbbellChartData item) {
    if (item.delta == 0) return connectorColor;
    return item.delta > 0 ? positiveColor : negativeColor;
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
  bool shouldRepaint(covariant _SimpleDumbbellPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.orientation != orientation ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor ||
        oldDelegate.connectorColor != connectorColor ||
        oldDelegate.positiveColor != positiveColor ||
        oldDelegate.negativeColor != negativeColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showDelta != showDelta ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.markerRadius != markerRadius ||
        oldDelegate.connectorWidth != connectorWidth ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.deltaFormatter != deltaFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

_DumbbellRange _resolveDumbbellRange({
  required List<SimpleDumbbellChartData> data,
  required double? minValue,
  required double? maxValue,
  required List<SimpleChartReferenceLine> referenceLines,
  required List<SimpleChartReferenceBand> referenceBands,
}) {
  var lower = double.infinity;
  var upper = double.negativeInfinity;

  for (final item in data) {
    if (!item.start.isFinite || !item.end.isFinite) continue;
    lower = math.min(lower, math.min(item.start, item.end));
    upper = math.max(upper, math.max(item.start, item.end));
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
    final pad = (upper - lower).abs() * 0.06;
    if (!hasExplicitMin) lower -= pad;
    if (!hasExplicitMax) upper += pad;
  }

  if (lower == upper) {
    upper = lower + 1;
  }

  return _DumbbellRange(lower, upper);
}

class _DumbbellRange {
  final double min;
  final double max;

  const _DumbbellRange(this.min, this.max);

  double get span => math.max(0.000001, max - min);
}

class _SimpleDumbbellVisuals {
  final Color startColor;
  final Color endColor;
  final Color connectorColor;
  final Color positiveColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final double markerRadius;
  final double connectorWidth;

  const _SimpleDumbbellVisuals({
    required this.startColor,
    required this.endColor,
    required this.connectorColor,
    required this.positiveColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.markerRadius,
    required this.connectorWidth,
  });

  factory _SimpleDumbbellVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleDumbbellVisuals(
          startColor: colorScheme.secondary,
          endColor: colorScheme.primary,
          connectorColor: colorScheme.outline,
          positiveColor: colorScheme.primary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.48),
          markerRadius: 6.5,
          connectorWidth: 3.2,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleDumbbellVisuals(
          startColor: colorScheme.outline,
          endColor: colorScheme.primary,
          connectorColor: colorScheme.outline,
          positiveColor: colorScheme.primary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.68),
          markerRadius: 5.4,
          connectorWidth: 2.4,
        );
      case SimpleBarChartStyle.education:
        return _SimpleDumbbellVisuals(
          startColor: colorScheme.secondary,
          endColor: colorScheme.tertiary,
          connectorColor: colorScheme.secondary,
          positiveColor: colorScheme.tertiary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          markerRadius: 6.2,
          connectorWidth: 2.8,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleDumbbellVisuals(
          startColor: colorScheme.secondary,
          endColor: colorScheme.tertiary,
          connectorColor: colorScheme.tertiary,
          positiveColor: colorScheme.tertiary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          markerRadius: 7,
          connectorWidth: 3.4,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleDumbbellVisuals(
          startColor: colorScheme.secondary,
          endColor: colorScheme.primary,
          connectorColor: colorScheme.outline,
          positiveColor: colorScheme.primary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          markerRadius: 6,
          connectorWidth: 2.8,
        );
    }
  }
}

class _DefaultDumbbellTooltip extends StatelessWidget {
  final Color startColor;
  final Color endColor;
  final Color deltaColor;
  final String title;
  final String startLabel;
  final String endLabel;
  final String startValue;
  final String endValue;
  final String deltaValue;

  const _DefaultDumbbellTooltip({
    required this.startColor,
    required this.endColor,
    required this.deltaColor,
    required this.title,
    required this.startLabel,
    required this.endLabel,
    required this.startValue,
    required this.endValue,
    required this.deltaValue,
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
                Text(
                  deltaValue,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: deltaColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TooltipValueRow(
              color: startColor,
              label: startLabel,
              value: startValue,
            ),
            const SizedBox(height: 4),
            _TooltipValueRow(color: endColor, label: endLabel, value: endValue),
          ],
        ),
      ),
    );
  }
}

class _TooltipValueRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _TooltipValueRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
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
