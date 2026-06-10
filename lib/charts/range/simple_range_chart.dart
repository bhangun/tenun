import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleRangeValueFormatter = String Function(double value);
typedef SimpleRangeTapCallback =
    void Function(SimpleRangeChartData data, int index);
typedef SimpleRangeTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleRangeChartData data,
      int index,
      String formattedMin,
      String formattedMax,
      String? formattedValue,
    );

class SimpleRangeChartData {
  final String label;
  final double min;
  final double max;
  final double? value;
  final Color? color;
  final Color? markerColor;

  const SimpleRangeChartData({
    required this.label,
    required this.min,
    required this.max,
    this.value,
    this.color,
    this.markerColor,
  });

  double get low => math.min(min, max);
  double get high => math.max(min, max);
  double get span => high - low;
}

/// A compact interval chart for min/max ranges, estimates, confidence windows,
/// target bands, and bounded comparisons.
class SimpleRangeChart extends StatelessWidget {
  static const EdgeInsets _horizontalPadding = EdgeInsets.fromLTRB(
    92,
    18,
    42,
    32,
  );
  static const EdgeInsets _verticalPadding = EdgeInsets.fromLTRB(
    48,
    18,
    18,
    42,
  );

  final List<SimpleRangeChartData> data;
  final SimpleBarChartOrientation orientation;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets? padding;
  final Color? rangeColor;
  final Color? markerColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showRangeLabels;
  final bool showMarkers;
  final bool showTooltip;
  final bool showActiveRange;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? rangeThickness;
  final double? rangeRadius;
  final double? markerRadius;
  final SimpleRangeValueFormatter? valueFormatter;
  final SimpleRangeTapCallback? onRangeTap;
  final SimpleRangeTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleRangeChart({
    super.key,
    required this.data,
    this.orientation = SimpleBarChartOrientation.horizontal,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding,
    this.rangeColor,
    this.markerColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = true,
    this.showRangeLabels = true,
    this.showMarkers = true,
    this.showTooltip = true,
    this.showActiveRange = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.rangeThickness,
    this.rangeRadius,
    this.markerRadius,
    this.valueFormatter,
    this.onRangeTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(rangeThickness == null || rangeThickness > 0),
       assert(rangeRadius == null || rangeRadius >= 0),
       assert(markerRadius == null || markerRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleRangeVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where(
          (item) =>
              item.min.isFinite &&
              item.max.isFinite &&
              (item.value == null || item.value!.isFinite),
        )
        .toList();
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
            emptySemanticLabel: 'Range chart, no data.',
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
          child: _SimpleRangeChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            orientation: orientation,
            minValue: minValue,
            maxValue: maxValue,
            padding: resolvedPadding,
            rangeColor: rangeColor ?? visuals.rangeColor,
            markerColor: markerColor ?? visuals.markerColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showLabels: showLabels,
            showValues: showValues,
            showRangeLabels: showRangeLabels,
            showMarkers: showMarkers,
            showTooltip: showTooltip,
            showActiveRange: showActiveRange,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            rangeThickness: rangeThickness ?? visuals.rangeThickness,
            rangeRadius: rangeRadius ?? visuals.rangeRadius,
            markerRadius: markerRadius ?? visuals.markerRadius,
            valueFormatter: formatter,
            onRangeTap: onRangeTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(
    List<SimpleRangeChartData> visibleData,
    SimpleRangeValueFormatter formatter,
  ) {
    final summaries = visibleData
        .take(6)
        .map((item) {
          final value = item.value == null
              ? ''
              : ', value ${formatter(item.value!)}';
          return '${item.label} range ${formatter(item.low)} to '
              '${formatter(item.high)}$value';
        })
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'item' : 'items';
    return 'Range chart, ${visibleData.length} $countLabel. '
        '$summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleRangeChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleRangeChartData> data;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color rangeColor;
  final Color markerColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showRangeLabels;
  final bool showMarkers;
  final bool showTooltip;
  final bool showActiveRange;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double rangeThickness;
  final double rangeRadius;
  final double markerRadius;
  final SimpleRangeValueFormatter valueFormatter;
  final SimpleRangeTapCallback? onRangeTap;
  final SimpleRangeTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleRangeChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.rangeColor,
    required this.markerColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showRangeLabels,
    required this.showMarkers,
    required this.showTooltip,
    required this.showActiveRange,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.rangeThickness,
    required this.rangeRadius,
    required this.markerRadius,
    required this.valueFormatter,
    required this.onRangeTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleRangeChartView> createState() => _SimpleRangeChartViewState();
}

class _SimpleRangeChartViewState extends State<_SimpleRangeChartView> {
  int? _activeIndex;
  Offset _activePosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveRange ||
        widget.onRangeTap != null;

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
                painter: _SimpleRangePainter(
                  data: widget.data,
                  orientation: widget.orientation,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  rangeColor: widget.rangeColor,
                  markerColor: widget.markerColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showLabels: widget.showLabels,
                  showValues: widget.showValues,
                  showRangeLabels: widget.showRangeLabels,
                  showMarkers: widget.showMarkers,
                  showActiveRange: widget.showActiveRange,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  rangeThickness: widget.rangeThickness,
                  rangeRadius: widget.rangeRadius,
                  markerRadius: widget.markerRadius,
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
                      final selection = _hitTest(details.localPosition, size);
                      _setActive(selection);
                      if (selection == null) return;
                      widget.onRangeTap?.call(
                        widget.data[selection.index],
                        selection.index,
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
    );
  }

  void _setActive(_RangeSelection? selection) {
    if (_activeIndex == selection?.index &&
        _activePosition == (selection?.position ?? Offset.zero)) {
      return;
    }
    setState(() {
      _activeIndex = selection?.index;
      _activePosition = selection?.position ?? Offset.zero;
    });
  }

  _RangeSelection? _hitTest(Offset position, Size size) {
    final geometry = _RangeGeometry.resolve(
      size: size,
      data: widget.data,
      orientation: widget.orientation,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      rangeThickness: widget.rangeThickness,
      markerRadius: widget.markerRadius,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
    for (var index = 0; index < geometry.items.length; index++) {
      final item = geometry.items[index];
      final hitRect = item.rect.inflate(math.max(8, widget.markerRadius + 4));
      if (hitRect.contains(position)) {
        return _RangeSelection(index, item.rect.center);
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final item = widget.data[index];
    final formattedMin = widget.valueFormatter(item.low);
    final formattedMax = widget.valueFormatter(item.high);
    final formattedValue = item.value == null
        ? null
        : widget.valueFormatter(item.value!);
    const tooltipWidth = 184.0;
    final tooltipHeight = item.value == null ? 70.0 : 88.0;
    final left = (_activePosition.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (_activePosition.dy - tooltipHeight - 8)
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
            formattedMin,
            formattedMax,
            formattedValue,
          ) ??
          _DefaultRangeTooltip(
            color: _rangeColor(item),
            title: item.label,
            rows: [
              _RangeTooltipRow(label: 'Min', value: formattedMin),
              _RangeTooltipRow(label: 'Max', value: formattedMax),
              if (formattedValue != null)
                _RangeTooltipRow(label: 'Value', value: formattedValue),
            ],
          ),
    );
  }

  Color _rangeColor(SimpleRangeChartData item) {
    return item.color ?? widget.rangeColor;
  }
}

class _SimpleRangePainter extends CustomPainter {
  final List<SimpleRangeChartData> data;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color rangeColor;
  final Color markerColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showRangeLabels;
  final bool showMarkers;
  final bool showActiveRange;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double rangeThickness;
  final double rangeRadius;
  final double markerRadius;
  final int? activeIndex;
  final SimpleRangeValueFormatter valueFormatter;
  final double progress;

  const _SimpleRangePainter({
    required this.data,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.rangeColor,
    required this.markerColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showRangeLabels,
    required this.showMarkers,
    required this.showActiveRange,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.rangeThickness,
    required this.rangeRadius,
    required this.markerRadius,
    required this.activeIndex,
    required this.valueFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _RangeGeometry.resolve(
      size: size,
      data: data,
      orientation: orientation,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      rangeThickness: rangeThickness,
      markerRadius: markerRadius,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    if (geometry.items.isEmpty || geometry.plot.isEmpty) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    _drawRanges(canvas, geometry);
    if (showLabels) _drawLabels(canvas, geometry);
  }

  void _drawReferenceBands(Canvas canvas, _RangeGeometry geometry) {
    final paint = Paint();
    for (final band in referenceBands) {
      final from = band.from.isFinite ? band.from : geometry.range.min;
      final to = band.to.isFinite ? band.to : geometry.range.max;
      final start = geometry.positionForValue(from);
      final end = geometry.positionForValue(to);
      paint.color = (band.color ?? rangeColor).withValues(alpha: band.opacity);
      if (orientation == SimpleBarChartOrientation.horizontal) {
        canvas.drawRect(
          Rect.fromLTRB(
            math.min(start, end),
            geometry.plot.top,
            math.max(start, end),
            geometry.plot.bottom,
          ),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTRB(
            geometry.plot.left,
            math.min(start, end),
            geometry.plot.right,
            math.max(start, end),
          ),
          paint,
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, _RangeGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          geometry.range.min + geometry.range.span * (index / gridLineCount);
      final position = geometry.positionForValue(value);
      if (orientation == SimpleBarChartOrientation.horizontal) {
        canvas.drawLine(
          Offset(position, geometry.plot.top),
          Offset(position, geometry.plot.bottom),
          paint,
        );
        _drawAxisTickLabel(
          canvas,
          value,
          Offset(position, geometry.plot.bottom),
        );
      } else {
        canvas.drawLine(
          Offset(geometry.plot.left, position),
          Offset(geometry.plot.right, position),
          paint,
        );
        _drawAxisTickLabel(canvas, value, Offset(geometry.plot.left, position));
      }
    }
  }

  void _drawAxis(Canvas canvas, _RangeGeometry geometry) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    if (orientation == SimpleBarChartOrientation.horizontal) {
      canvas.drawLine(
        Offset(geometry.plot.left, geometry.plot.bottom),
        Offset(geometry.plot.right, geometry.plot.bottom),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(geometry.plot.left, geometry.plot.top),
        Offset(geometry.plot.left, geometry.plot.bottom),
        paint,
      );
    }
  }

  void _drawReferenceLines(Canvas canvas, _RangeGeometry geometry) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final position = geometry.positionForValue(line.value);
      final paint = Paint()
        ..color = line.color ?? axisColor
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke;
      if (orientation == SimpleBarChartOrientation.horizontal) {
        _drawStyledLine(
          canvas,
          Offset(position, geometry.plot.top),
          Offset(position, geometry.plot.bottom),
          paint,
          line.lineStyle,
        );
      } else {
        _drawStyledLine(
          canvas,
          Offset(geometry.plot.left, position),
          Offset(geometry.plot.right, position),
          paint,
          line.lineStyle,
        );
      }
    }
  }

  void _drawRanges(Canvas canvas, _RangeGeometry geometry) {
    for (var index = 0; index < geometry.items.length; index++) {
      final layout = geometry.items[index];
      final item = data[index];
      final color = item.color ?? rangeColor;
      final animatedRect = _animatedRect(layout.rect);
      final rrect = RRect.fromRectAndRadius(
        animatedRect,
        Radius.circular(math.min(rangeRadius, rangeThickness / 2)),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: orientation == SimpleBarChartOrientation.horizontal
                ? Alignment.centerLeft
                : Alignment.bottomCenter,
            end: orientation == SimpleBarChartOrientation.horizontal
                ? Alignment.centerRight
                : Alignment.topCenter,
            colors: [color.withValues(alpha: 0.68), color],
          ).createShader(animatedRect),
      );

      if (showActiveRange && activeIndex == index) {
        final highlight = activeColor ?? color;
        canvas.drawRRect(
          rrect.inflate(3),
          Paint()..color = highlight.withValues(alpha: 0.14),
        );
        canvas.drawRRect(
          rrect.inflate(1.4),
          Paint()
            ..color = highlight.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      if (showMarkers && item.value != null) {
        final center = geometry.markerCenterFor(index);
        final markerPaint = Paint()
          ..color = item.markerColor ?? markerColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, markerRadius + 1.5, Paint()..color = color);
        canvas.drawCircle(center, markerRadius, markerPaint);
      }

      if (showValues) _drawRangeValues(canvas, layout, item);
    }
  }

  Rect _animatedRect(Rect rect) {
    if (orientation == SimpleBarChartOrientation.horizontal) {
      final width = rect.width * progress;
      return Rect.fromLTWH(rect.left, rect.top, width, rect.height);
    }
    final height = rect.height * progress;
    return Rect.fromLTRB(
      rect.left,
      rect.bottom - height,
      rect.right,
      rect.bottom,
    );
  }

  void _drawRangeValues(
    Canvas canvas,
    _RangeItemLayout layout,
    SimpleRangeChartData item,
  ) {
    if (progress < 0.55) return;
    if (showRangeLabels) {
      final minText = valueFormatter(item.low);
      final maxText = valueFormatter(item.high);
      if (orientation == SimpleBarChartOrientation.horizontal) {
        _paintText(
          canvas,
          minText,
          valueStyle,
          Offset(layout.rect.left - 4, layout.rect.center.dy),
          TextAlign.right,
          48,
          centeredY: true,
        );
        _paintText(
          canvas,
          maxText,
          valueStyle,
          Offset(layout.rect.right + 4, layout.rect.center.dy),
          TextAlign.left,
          48,
          centeredY: true,
        );
      } else {
        _paintText(
          canvas,
          maxText,
          valueStyle,
          Offset(layout.rect.center.dx, layout.rect.top - 6),
          TextAlign.center,
          56,
        );
        _paintText(
          canvas,
          minText,
          valueStyle,
          Offset(layout.rect.center.dx, layout.rect.bottom + 4),
          TextAlign.center,
          56,
        );
      }
    }

    if (!showMarkers || item.value == null) return;
    final markerText = valueFormatter(item.value!);
    if (orientation == SimpleBarChartOrientation.horizontal) {
      _paintText(
        canvas,
        markerText,
        valueStyle,
        Offset(layout.markerCenter.dx, layout.markerCenter.dy - 20),
        TextAlign.center,
        64,
      );
    }
  }

  void _drawLabels(Canvas canvas, _RangeGeometry geometry) {
    for (var index = 0; index < geometry.items.length; index++) {
      final layout = geometry.items[index];
      final item = data[index];
      if (orientation == SimpleBarChartOrientation.horizontal) {
        _paintText(
          canvas,
          item.label,
          labelStyle,
          Offset(padding.left - 10, layout.rect.center.dy),
          TextAlign.right,
          math.max(0.0, padding.left - 16),
          centeredY: true,
        );
      } else {
        _paintText(
          canvas,
          item.label,
          labelStyle,
          Offset(layout.rect.center.dx, geometry.plot.bottom + 18),
          TextAlign.center,
          math.max(28.0, geometry.categorySize - 4),
        );
      }
    }
  }

  void _drawAxisTickLabel(Canvas canvas, double value, Offset anchor) {
    final style = labelStyle.copyWith(
      color: labelStyle.color?.withValues(alpha: 0.72),
      fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
    );
    if (orientation == SimpleBarChartOrientation.horizontal) {
      _paintText(
        canvas,
        valueFormatter(value),
        style,
        Offset(anchor.dx, anchor.dy + 6),
        TextAlign.center,
        56,
      );
    } else {
      _paintText(
        canvas,
        valueFormatter(value),
        style,
        Offset(anchor.dx - 8, anchor.dy),
        TextAlign.right,
        math.max(0.0, padding.left - 12),
        centeredY: true,
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset anchor,
    TextAlign align,
    double maxWidth, {
    bool centeredY = false,
  }) {
    if (maxWidth <= 0) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);

    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.center => anchor.dx - painter.width / 2,
      _ => anchor.dx,
    };
    final dy = centeredY ? anchor.dy - painter.height / 2 : anchor.dy;
    painter.paint(canvas, Offset(dx, dy));
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
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    var drawn = 0.0;
    final dash = style == SimpleChartReferenceLineStyle.dotted ? 1.5 : 6.0;
    final gap = style == SimpleChartReferenceLineStyle.dotted ? 5.0 : 4.0;
    while (drawn < total) {
      final segmentStart = start + direction * drawn;
      final segmentEnd = start + direction * math.min(total, drawn + dash);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleRangePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.orientation != orientation ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.rangeColor != rangeColor ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showRangeLabels != showRangeLabels ||
        oldDelegate.showMarkers != showMarkers ||
        oldDelegate.showActiveRange != showActiveRange ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.rangeThickness != rangeThickness ||
        oldDelegate.rangeRadius != rangeRadius ||
        oldDelegate.markerRadius != markerRadius ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _RangeGeometry {
  final Rect plot;
  final _ValueRange range;
  final List<_RangeItemLayout> items;
  final SimpleBarChartOrientation orientation;
  final double categorySize;

  const _RangeGeometry({
    required this.plot,
    required this.range,
    required this.items,
    required this.orientation,
    required this.categorySize,
  });

  factory _RangeGeometry.resolve({
    required Size size,
    required List<SimpleRangeChartData> data,
    required SimpleBarChartOrientation orientation,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required double rangeThickness,
    required double markerRadius,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0 || data.isEmpty) {
      return _RangeGeometry(
        plot: plot,
        range: const _ValueRange(0, 1),
        items: const [],
        orientation: orientation,
        categorySize: 0,
      );
    }

    final range = _ValueRange.resolve(
      data: data,
      minValue: minValue,
      maxValue: maxValue,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    final categorySize =
        (orientation == SimpleBarChartOrientation.horizontal
            ? plot.height
            : plot.width) /
        data.length;
    final thickness = math.min(
      rangeThickness,
      math.max(4.0, categorySize * 0.42),
    );
    final items = <_RangeItemLayout>[];

    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final lowPos = _positionForValue(item.low, plot, range, orientation);
      final highPos = _positionForValue(item.high, plot, range, orientation);
      final markerValue = item.value?.clamp(range.min, range.max).toDouble();
      final markerPos = markerValue == null
          ? (lowPos + highPos) / 2
          : _positionForValue(markerValue, plot, range, orientation);

      if (orientation == SimpleBarChartOrientation.horizontal) {
        final y = plot.top + categorySize * index + categorySize / 2;
        final rect = Rect.fromLTRB(
          math.min(lowPos, highPos),
          y - thickness / 2,
          math.max(lowPos, highPos),
          y + thickness / 2,
        );
        items.add(
          _RangeItemLayout(rect: rect, markerCenter: Offset(markerPos, y)),
        );
      } else {
        final x = plot.left + categorySize * index + categorySize / 2;
        final rect = Rect.fromLTRB(
          x - thickness / 2,
          math.min(lowPos, highPos),
          x + thickness / 2,
          math.max(lowPos, highPos),
        );
        items.add(
          _RangeItemLayout(rect: rect, markerCenter: Offset(x, markerPos)),
        );
      }
    }

    return _RangeGeometry(
      plot: plot,
      range: range,
      items: items,
      orientation: orientation,
      categorySize: categorySize,
    );
  }

  double positionForValue(double value) {
    return _positionForValue(value, plot, range, orientation);
  }

  Offset markerCenterFor(int index) => items[index].markerCenter;

  static double _positionForValue(
    double value,
    Rect plot,
    _ValueRange range,
    SimpleBarChartOrientation orientation,
  ) {
    final normalized = ((value - range.min) / range.span).clamp(0.0, 1.0);
    if (orientation == SimpleBarChartOrientation.horizontal) {
      return plot.left + normalized * plot.width;
    }
    return plot.bottom - normalized * plot.height;
  }
}

class _RangeItemLayout {
  final Rect rect;
  final Offset markerCenter;

  const _RangeItemLayout({required this.rect, required this.markerCenter});
}

class _RangeSelection {
  final int index;
  final Offset position;

  const _RangeSelection(this.index, this.position);
}

class _ValueRange {
  final double min;
  final double max;

  const _ValueRange(this.min, this.max);

  double get span => max - min;

  factory _ValueRange.resolve({
    required List<SimpleRangeChartData> data,
    required double? minValue,
    required double? maxValue,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    var lower = data.fold<double>(
      double.infinity,
      (current, item) => math.min(current, item.low),
    );
    var upper = data.fold<double>(
      double.negativeInfinity,
      (current, item) => math.max(current, item.high),
    );
    for (final item in data) {
      if (item.value != null) {
        lower = math.min(lower, item.value!);
        upper = math.max(upper, item.value!);
      }
    }
    for (final line in referenceLines) {
      if (line.value.isFinite) {
        lower = math.min(lower, line.value);
        upper = math.max(upper, line.value);
      }
    }
    for (final band in referenceBands) {
      if (band.from.isFinite) lower = math.min(lower, band.from);
      if (band.to.isFinite) upper = math.max(upper, band.to);
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
      final pad = (upper - lower) * 0.08;
      if (minValue == null) lower -= pad;
      if (maxValue == null) upper += pad;
    }
    return _ValueRange(lower, upper);
  }
}

class _SimpleRangeVisuals {
  final Color rangeColor;
  final Color markerColor;
  final Color gridColor;
  final Color axisColor;
  final double rangeThickness;
  final double rangeRadius;
  final double markerRadius;

  const _SimpleRangeVisuals({
    required this.rangeColor,
    required this.markerColor,
    required this.gridColor,
    required this.axisColor,
    required this.rangeThickness,
    required this.rangeRadius,
    required this.markerRadius,
  });

  factory _SimpleRangeVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleRangeVisuals(
          rangeColor: colorScheme.primary,
          markerColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.52),
          rangeThickness: 12,
          rangeRadius: 8,
          markerRadius: 5,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleRangeVisuals(
          rangeColor: colorScheme.primary,
          markerColor: colorScheme.onSurface,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          rangeThickness: 9,
          rangeRadius: 4,
          markerRadius: 4,
        );
      case SimpleBarChartStyle.education:
        return _SimpleRangeVisuals(
          rangeColor: colorScheme.secondary,
          markerColor: const Color(0xFFF59E0B),
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          rangeThickness: 11,
          rangeRadius: 6,
          markerRadius: 5,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleRangeVisuals(
          rangeColor: colorScheme.tertiary,
          markerColor: const Color(0xFFEC4899),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          rangeThickness: 13,
          rangeRadius: 10,
          markerRadius: 5.5,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleRangeVisuals(
          rangeColor: colorScheme.primary,
          markerColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          rangeThickness: 10,
          rangeRadius: 7,
          markerRadius: 5,
        );
    }
  }
}

class _DefaultRangeTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final List<_RangeTooltipRow> rows;

  const _DefaultRangeTooltip({
    required this.color,
    required this.title,
    required this.rows,
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
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: TextStyle(
                          color: colorScheme.onInverseSurface.withValues(
                            alpha: 0.72,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ),
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

class _RangeTooltipRow {
  final String label;
  final String value;

  const _RangeTooltipRow({required this.label, required this.value});
}
