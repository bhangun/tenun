import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

/// A light comparison chart with stems and value markers instead of bars.
class SimpleLollipopChart extends StatelessWidget {
  static const EdgeInsets _verticalPadding = EdgeInsets.fromLTRB(
    44,
    18,
    16,
    34,
  );
  static const EdgeInsets _horizontalPadding = EdgeInsets.fromLTRB(
    86,
    18,
    44,
    30,
  );

  final List<SimpleBarChartData> data;
  final SimpleBarChartOrientation orientation;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets? padding;
  final Color? markerColor;
  final Color? stemColor;
  final Color? negativeColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showStems;
  final bool showTooltip;
  final bool showActivePoint;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? markerRadius;
  final double? stemWidth;
  final SimpleBarValueFormatter? valueFormatter;
  final SimpleBarTapCallback? onPointTap;
  final SimpleBarTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleLollipopChart({
    super.key,
    required this.data,
    this.orientation = SimpleBarChartOrientation.vertical,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 240,
    this.padding,
    this.markerColor,
    this.stemColor,
    this.negativeColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showStems = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.markerRadius,
    this.stemWidth,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 650),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(markerRadius == null || markerRadius >= 0),
       assert(stemWidth == null || stemWidth > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleLollipopVisuals.resolve(style, colorScheme);
    final visibleData = data.where((item) => item.value.isFinite).toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedPadding =
        padding ??
        (orientation == SimpleBarChartOrientation.vertical
            ? _verticalPadding
            : _horizontalPadding);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Lollipop chart, no data.',
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
          semanticLabel: _defaultSemanticLabel(visibleData, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleLollipopChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            orientation: orientation,
            minValue: minValue,
            maxValue: maxValue,
            padding: resolvedPadding,
            markerColor: markerColor ?? visuals.markerColor,
            stemColor: stemColor ?? visuals.stemColor,
            negativeColor: negativeColor ?? visuals.negativeColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showStems: showStems,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            markerRadius: markerRadius ?? visuals.markerRadius,
            stemWidth: stemWidth ?? visuals.stemWidth,
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

  String _defaultSemanticLabel(
    List<SimpleBarChartData> visibleData,
    SimpleBarValueFormatter formatter,
  ) {
    final visibleItems = visibleData
        .take(6)
        .map((item) => '${item.label} ${formatter(item.value)}')
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'item' : 'items';
    return 'Lollipop chart, ${visibleData.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleLollipopChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleBarChartData> data;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color markerColor;
  final Color stemColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showStems;
  final bool showTooltip;
  final bool showActivePoint;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double markerRadius;
  final double stemWidth;
  final SimpleBarValueFormatter valueFormatter;
  final SimpleBarTapCallback? onPointTap;
  final SimpleBarTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleLollipopChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.markerColor,
    required this.stemColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showStems,
    required this.showTooltip,
    required this.showActivePoint,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.markerRadius,
    required this.stemWidth,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleLollipopChartView> createState() =>
      _SimpleLollipopChartViewState();
}

class _SimpleLollipopChartViewState extends State<_SimpleLollipopChartView> {
  int? _activeIndex;

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
                painter: _SimpleLollipopPainter(
                  data: widget.data,
                  orientation: widget.orientation,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  markerColor: widget.markerColor,
                  stemColor: widget.stemColor,
                  negativeColor: widget.negativeColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showStems: widget.showStems,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  markerRadius: widget.markerRadius,
                  stemWidth: widget.stemWidth,
                  valueFormatter: widget.valueFormatter,
                  activeIndex: widget.showActivePoint ? _activeIndex : null,
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
                        widget.onPointTap?.call(widget.data[index], index);
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
    final formattedValue = widget.valueFormatter(item.value);
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 164.0;
    const tooltipHeight = 58.0;
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
          widget.tooltipBuilder?.call(context, item, index, formattedValue) ??
          _DefaultLollipopTooltip(
            color: item.color ?? _itemColor(item),
            title: item.label,
            value: formattedValue,
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final plot = _plot(size);
    final range = _resolveRange();
    final zeroY = _yForValue(
      0,
      plot,
      range,
    ).clamp(plot.top, plot.bottom).toDouble();
    final zeroX = _xForValue(
      0,
      plot,
      range,
    ).clamp(plot.left, plot.right).toDouble();
    final item = widget.data[index];

    if (widget.orientation == SimpleBarChartOrientation.horizontal) {
      final segmentHeight = plot.height / widget.data.length;
      final y = plot.top + segmentHeight * index + segmentHeight / 2;
      final x = zeroX + (_xForValue(item.value, plot, range) - zeroX);
      return Offset(x, y);
    }

    final segmentWidth = plot.width / widget.data.length;
    final x = plot.left + segmentWidth * index + segmentWidth / 2;
    final y = zeroY + (_yForValue(item.value, plot, range) - zeroY);
    return Offset(x, y);
  }

  Rect _plot(Size size) {
    return Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }

  _ValueRange _resolveRange() {
    return _resolveLollipopRange(
      data: widget.data,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
  }

  double _xForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.left + normalized * plot.width;
  }

  double _yForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  Color _itemColor(SimpleBarChartData item) {
    return item.value < 0 ? widget.negativeColor : widget.markerColor;
  }
}

class _SimpleLollipopPainter extends CustomPainter {
  final List<SimpleBarChartData> data;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color markerColor;
  final Color stemColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showStems;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double markerRadius;
  final double stemWidth;
  final SimpleBarValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleLollipopPainter({
    required this.data,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.markerColor,
    required this.stemColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showStems,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.markerRadius,
    required this.stemWidth,
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
    if (plot.width <= 0 || plot.height <= 0 || data.isEmpty) return;

    final range = _resolveRange();
    if (orientation == SimpleBarChartOrientation.horizontal) {
      _paintHorizontal(canvas, plot, range);
    } else {
      _paintVertical(canvas, plot, range);
    }
  }

  _ValueRange _resolveRange() {
    return _resolveLollipopRange(
      data: data,
      minValue: minValue,
      maxValue: maxValue,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
  }

  void _paintVertical(Canvas canvas, Rect plot, _ValueRange range) {
    final zeroY = _yForValue(
      0,
      plot,
      range,
    ).clamp(plot.top, plot.bottom).toDouble();
    _drawVerticalBands(canvas, plot, range);
    _drawVerticalActiveCategory(canvas, plot);
    if (showGrid) {
      _drawVerticalGrid(canvas, plot, range);
    }
    _drawHorizontalAxis(canvas, plot, zeroY);
    _drawVerticalReferenceLines(canvas, plot, range);
    _drawVerticalLollipops(canvas, plot, range, zeroY);
    _drawVerticalLabels(canvas, plot);
  }

  void _paintHorizontal(Canvas canvas, Rect plot, _ValueRange range) {
    final zeroX = _xForValue(
      0,
      plot,
      range,
    ).clamp(plot.left, plot.right).toDouble();
    _drawHorizontalBands(canvas, plot, range);
    _drawHorizontalActiveCategory(canvas, plot);
    if (showGrid) {
      _drawHorizontalGrid(canvas, plot, range);
    }
    _drawVerticalAxis(canvas, plot, zeroX);
    _drawHorizontalReferenceLines(canvas, plot, range);
    _drawHorizontalLollipops(canvas, plot, range, zeroX);
    _drawHorizontalLabels(canvas, plot);
  }

  double _xForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.left + normalized * plot.width;
  }

  double _yForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  void _drawVerticalGrid(Canvas canvas, Rect plot, _ValueRange range) {
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

  void _drawHorizontalGrid(Canvas canvas, Rect plot, _ValueRange range) {
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

  void _drawHorizontalAxis(Canvas canvas, Rect plot, double zeroY) {
    canvas.drawLine(
      Offset(plot.left, zeroY),
      Offset(plot.right, zeroY),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1.2,
    );
  }

  void _drawVerticalAxis(Canvas canvas, Rect plot, double zeroX) {
    canvas.drawLine(
      Offset(zeroX, plot.top),
      Offset(zeroX, plot.bottom),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1.2,
    );
  }

  void _drawVerticalBands(Canvas canvas, Rect plot, _ValueRange range) {
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
      final color = band.color ?? markerColor;
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      _drawBandLabel(canvas, band, rect.topRight, Axis.horizontal, plot, color);
    }
  }

  void _drawHorizontalBands(Canvas canvas, Rect plot, _ValueRange range) {
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
      final color = band.color ?? markerColor;
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      _drawBandLabel(canvas, band, rect.topLeft, Axis.vertical, plot, color);
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

  void _drawVerticalReferenceLines(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
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

  void _drawHorizontalReferenceLines(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
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
    final color = activeColor ?? _itemColor(data[index]);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.055));
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
    final color = activeColor ?? _itemColor(data[index]);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.055));
  }

  void _drawVerticalLollipops(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
    double zeroY,
  ) {
    final segmentWidth = plot.width / data.length;
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final x = plot.left + segmentWidth * index + segmentWidth / 2;
      final targetY = _yForValue(item.value, plot, range);
      final y = zeroY + (targetY - zeroY) * progress;
      final color = _itemColor(item);

      if (showStems) {
        _drawStem(canvas, Offset(x, zeroY), Offset(x, y), color);
      }
      _drawMarker(canvas, Offset(x, y), color, index == activeIndex);
      if (showValues && segmentWidth >= 30) {
        _drawVerticalValue(canvas, item, Offset(x, y), plot);
      }
    }
  }

  void _drawHorizontalLollipops(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
    double zeroX,
  ) {
    final segmentHeight = plot.height / data.length;
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final y = plot.top + segmentHeight * index + segmentHeight / 2;
      final targetX = _xForValue(item.value, plot, range);
      final x = zeroX + (targetX - zeroX) * progress;
      final color = _itemColor(item);

      if (showStems) {
        _drawStem(canvas, Offset(zeroX, y), Offset(x, y), color);
      }
      _drawMarker(canvas, Offset(x, y), color, index == activeIndex);
      if (showValues && segmentHeight >= 22) {
        _drawHorizontalValue(canvas, item, Offset(x, y), plot);
      }
    }
  }

  void _drawStem(Canvas canvas, Offset start, Offset end, Color color) {
    if ((end - start).distance <= 0.5) return;
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color.withValues(alpha: 0.38)
        ..strokeWidth = stemWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawMarker(Canvas canvas, Offset center, Color color, bool active) {
    final radius = markerRadius * (0.35 + progress * 0.65);
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
          ..color = activeMarkerColor.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(
      center,
      radius + 1.5,
      Paint()..color = color.withValues(alpha: 0.18),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  void _drawVerticalValue(
    Canvas canvas,
    SimpleBarChartData item,
    Offset marker,
    Rect plot,
  ) {
    final painter = _textPainter(valueFormatter(item.value), valueStyle)
      ..layout();
    final preferredY = item.value >= 0
        ? marker.dy - markerRadius - painter.height - 5
        : marker.dy + markerRadius + 5;
    final x = _safeClamp(
      marker.dx - painter.width / 2,
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

  void _drawHorizontalValue(
    Canvas canvas,
    SimpleBarChartData item,
    Offset marker,
    Rect plot,
  ) {
    final painter = _textPainter(valueFormatter(item.value), valueStyle)
      ..layout();
    final preferredX = item.value >= 0
        ? marker.dx + markerRadius + 6
        : marker.dx - markerRadius - painter.width - 6;
    final x = _safeClamp(
      preferredX,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = marker.dy - painter.height / 2;
    painter.paint(canvas, Offset(x, y));
  }

  void _drawVerticalLabels(Canvas canvas, Rect plot) {
    final segmentWidth = plot.width / data.length;
    final maxLabelCount = math.max(1, plot.width / 48).floor();
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

  void _drawHorizontalLabels(Canvas canvas, Rect plot) {
    final segmentHeight = plot.height / data.length;
    final maxLabelCount = math.max(1, plot.height / 22).floor();
    final labelEvery = math.max(1, (data.length / maxLabelCount).ceil());
    final maxWidth = math.max(24.0, padding.left - 12);

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

  Color _itemColor(SimpleBarChartData item) {
    return item.color ?? (item.value < 0 ? negativeColor : markerColor);
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
  bool shouldRepaint(covariant _SimpleLollipopPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.orientation != orientation ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.stemColor != stemColor ||
        oldDelegate.negativeColor != negativeColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showStems != showStems ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.markerRadius != markerRadius ||
        oldDelegate.stemWidth != stemWidth ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

_ValueRange _resolveLollipopRange({
  required List<SimpleBarChartData> data,
  required double? minValue,
  required double? maxValue,
  required List<SimpleChartReferenceLine> referenceLines,
  required List<SimpleChartReferenceBand> referenceBands,
}) {
  var lower = double.infinity;
  var upper = double.negativeInfinity;

  for (final item in data) {
    if (!item.value.isFinite) continue;
    lower = math.min(lower, item.value);
    upper = math.max(upper, item.value);
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

  lower = minValue ?? math.min(0.0, lower);
  upper = maxValue ?? math.max(0.0, upper);

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
    final pad = (upper - lower).abs() * 0.06;
    lower -= pad;
    upper += pad;
  }

  return _ValueRange(lower, upper);
}

class _SimpleLollipopVisuals {
  final Color markerColor;
  final Color stemColor;
  final Color negativeColor;
  final Color gridColor;
  final Color axisColor;
  final double markerRadius;
  final double stemWidth;

  const _SimpleLollipopVisuals({
    required this.markerColor,
    required this.stemColor,
    required this.negativeColor,
    required this.gridColor,
    required this.axisColor,
    required this.markerRadius,
    required this.stemWidth,
  });

  factory _SimpleLollipopVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleLollipopVisuals(
          markerColor: colorScheme.primary,
          stemColor: colorScheme.primary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          markerRadius: 6.5,
          stemWidth: 2.3,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleLollipopVisuals(
          markerColor: colorScheme.primary,
          stemColor: colorScheme.outline,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          markerRadius: 5.2,
          stemWidth: 1.8,
        );
      case SimpleBarChartStyle.education:
        return _SimpleLollipopVisuals(
          markerColor: colorScheme.secondary,
          stemColor: colorScheme.secondary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.65),
          markerRadius: 6,
          stemWidth: 2,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleLollipopVisuals(
          markerColor: colorScheme.tertiary,
          stemColor: colorScheme.tertiary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          markerRadius: 7,
          stemWidth: 2.4,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleLollipopVisuals(
          markerColor: colorScheme.primary,
          stemColor: colorScheme.primary,
          negativeColor: colorScheme.error,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          markerRadius: 6,
          stemWidth: 2,
        );
    }
  }
}

class _DefaultLollipopTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;

  const _DefaultLollipopTooltip({
    required this.color,
    required this.title,
    required this.value,
  });

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
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onInverseSurface.withValues(alpha: 0.78),
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                color: colorScheme.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueRange {
  final double min;
  final double max;

  const _ValueRange(this.min, this.max);

  double get span => max - min;
}
