import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleErrorBarValueFormatter = String Function(double value);
typedef SimpleErrorBarTapCallback =
    void Function(SimpleErrorBarData data, int index);
typedef SimpleErrorBarTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleErrorBarData data,
      int index,
      String formattedValue,
      String formattedLower,
      String formattedUpper,
    );

class SimpleErrorBarData {
  final String label;
  final double value;
  final double lower;
  final double upper;
  final Color? color;

  const SimpleErrorBarData({
    required this.label,
    required this.value,
    required this.lower,
    required this.upper,
    this.color,
  });

  double get low => math.min(lower, upper);
  double get high => math.max(lower, upper);
}

/// A compact error-bar chart for confidence intervals, uncertainty ranges,
/// measurements, experiments, surveys, and forecasts.
class SimpleErrorBarChart extends StatelessWidget {
  static const EdgeInsets _verticalPadding = EdgeInsets.fromLTRB(
    48,
    18,
    18,
    42,
  );
  static const EdgeInsets _horizontalPadding = EdgeInsets.fromLTRB(
    92,
    18,
    44,
    34,
  );

  final List<SimpleErrorBarData> data;
  final SimpleBarChartOrientation orientation;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets? padding;
  final List<Color>? palette;
  final Color? markerColor;
  final Color? errorColor;
  final Color? capColor;
  final Color? lineColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showErrorLabels;
  final bool showCaps;
  final bool showLine;
  final bool showTooltip;
  final bool showActivePoint;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? strokeWidth;
  final double? capSize;
  final double? markerRadius;
  final SimpleErrorBarValueFormatter? valueFormatter;
  final SimpleErrorBarTapCallback? onPointTap;
  final SimpleErrorBarTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleErrorBarChart({
    super.key,
    required this.data,
    this.orientation = SimpleBarChartOrientation.vertical,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding,
    this.palette,
    this.markerColor,
    this.errorColor,
    this.capColor,
    this.lineColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.includeZero = false,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = true,
    this.showErrorLabels = false,
    this.showCaps = true,
    this.showLine = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.strokeWidth,
    this.capSize,
    this.markerRadius,
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
       assert(capSize == null || capSize >= 0),
       assert(markerRadius == null || markerRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleErrorBarVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where(
          (item) =>
              item.value.isFinite && item.lower.isFinite && item.upper.isFinite,
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
            emptySemanticLabel: 'Error bar chart, no data.',
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
          child: _SimpleErrorBarChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            orientation: orientation,
            minValue: minValue,
            maxValue: maxValue,
            padding: resolvedPadding,
            palette: palette,
            markerColor: markerColor ?? visuals.markerColor,
            errorColor: errorColor ?? visuals.errorColor,
            capColor: capColor ?? errorColor ?? visuals.errorColor,
            lineColor: lineColor ?? visuals.lineColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            includeZero: includeZero,
            showGrid: showGrid,
            showLabels: showLabels,
            showValues: showValues,
            showErrorLabels: showErrorLabels,
            showCaps: showCaps,
            showLine: showLine,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            capSize: capSize ?? visuals.capSize,
            markerRadius: markerRadius ?? visuals.markerRadius,
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

  static String _defaultSemanticLabel(
    List<SimpleErrorBarData> data,
    SimpleErrorBarValueFormatter formatter,
  ) {
    final sample = data
        .take(5)
        .map((item) {
          return '${item.label} value ${formatter(item.value)}, interval '
              '${formatter(item.low)} to ${formatter(item.high)}';
        })
        .join(', ');
    final suffix = data.length > 5 ? ', and ${data.length - 5} more' : '';
    return 'Error bar chart, ${data.length} points. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleErrorBarChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleErrorBarData> data;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color markerColor;
  final Color errorColor;
  final Color capColor;
  final Color lineColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showErrorLabels;
  final bool showCaps;
  final bool showLine;
  final bool showTooltip;
  final bool showActivePoint;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double capSize;
  final double markerRadius;
  final SimpleErrorBarValueFormatter valueFormatter;
  final SimpleErrorBarTapCallback? onPointTap;
  final SimpleErrorBarTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleErrorBarChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.markerColor,
    required this.errorColor,
    required this.capColor,
    required this.lineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showErrorLabels,
    required this.showCaps,
    required this.showLine,
    required this.showTooltip,
    required this.showActivePoint,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.capSize,
    required this.markerRadius,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleErrorBarChartView> createState() =>
      _SimpleErrorBarChartViewState();
}

class _SimpleErrorBarChartViewState extends State<_SimpleErrorBarChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _ErrorBarHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleErrorBarChartView oldWidget) {
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
                        widget.onPointTap?.call(hit.data, hit.index);
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleErrorBarPainter(
                        data: widget.data,
                        orientation: widget.orientation,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        markerColor: widget.markerColor,
                        errorColor: widget.errorColor,
                        capColor: widget.capColor,
                        lineColor: widget.lineColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        includeZero: widget.includeZero,
                        showGrid: widget.showGrid,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showErrorLabels: widget.showErrorLabels,
                        showCaps: widget.showCaps,
                        showLine: widget.showLine,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        gridLineCount: widget.gridLineCount,
                        strokeWidth: widget.strokeWidth,
                        capSize: widget.capSize,
                        markerRadius: widget.markerRadius,
                        valueFormatter: widget.valueFormatter,
                        activeIndex: widget.showActivePoint
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

  void _setActive(_ErrorBarHit? hit) {
    if (_activeHit?.index == hit?.index) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _ErrorBarHit? _hitTest(Offset position) {
    final geometry = _ErrorBarGeometry.resolve(
      data: widget.data,
      size: Size(widget.width, widget.height),
      orientation: widget.orientation,
      padding: widget.padding,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      includeZero: widget.includeZero,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
    for (final hit in geometry.hits) {
      if (hit.hitRect.inflate(8).contains(position) ||
          (position - hit.markerOffset).distance <= widget.markerRadius + 8) {
        return hit;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _ErrorBarHit hit) {
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          hit.data,
          hit.index,
          widget.valueFormatter(hit.data.value),
          widget.valueFormatter(hit.data.low),
          widget.valueFormatter(hit.data.high),
        ) ??
        _DefaultErrorBarTooltip(
          title: hit.data.label,
          rows: [
            _TooltipRow('Value', widget.valueFormatter(hit.data.value)),
            _TooltipRow('Lower', widget.valueFormatter(hit.data.low)),
            _TooltipRow('Upper', widget.valueFormatter(hit.data.high)),
          ],
        );
    final left = (hit.markerOffset.dx + 12).clamp(8.0, widget.width - 176);
    final top = (hit.markerOffset.dy - 50).clamp(8.0, widget.height - 108);

    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleErrorBarPainter extends CustomPainter {
  final List<SimpleErrorBarData> data;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color markerColor;
  final Color errorColor;
  final Color capColor;
  final Color lineColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool includeZero;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showErrorLabels;
  final bool showCaps;
  final bool showLine;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double strokeWidth;
  final double capSize;
  final double markerRadius;
  final SimpleErrorBarValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleErrorBarPainter({
    required this.data,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.markerColor,
    required this.errorColor,
    required this.capColor,
    required this.lineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.includeZero,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showErrorLabels,
    required this.showCaps,
    required this.showLine,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.capSize,
    required this.markerRadius,
    required this.valueFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _ErrorBarGeometry.resolve(
      data: data,
      size: size,
      orientation: orientation,
      padding: padding,
      minValue: minValue,
      maxValue: maxValue,
      includeZero: includeZero,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    if (geometry.hits.isEmpty ||
        geometry.plot.width <= 0 ||
        geometry.plot.height <= 0) {
      return;
    }

    _drawReferenceBands(canvas, geometry);
    _drawGridAndAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    if (showLine) {
      _drawMeanLine(canvas, geometry);
    }
    for (final hit in geometry.hits) {
      _drawPoint(canvas, geometry, hit);
    }
  }

  void _drawGridAndAxis(Canvas canvas, _ErrorBarGeometry geometry) {
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
      final value = geometry.minValue + ratio * geometry.valueSpan;
      if (orientation == SimpleBarChartOrientation.vertical) {
        final y = geometry.yForValue(value);
        if (showGrid) {
          canvas.drawLine(
            Offset(plot.left, y),
            Offset(plot.right, y),
            gridPaint,
          );
        }
        _drawText(
          canvas,
          valueFormatter(value),
          Rect.fromLTWH(0, y - 8, math.max(0, plot.left - 8), 16),
          labelStyle,
          align: TextAlign.right,
        );
      } else {
        final x = geometry.xForValue(value);
        if (showGrid) {
          canvas.drawLine(
            Offset(x, plot.top),
            Offset(x, plot.bottom),
            gridPaint,
          );
        }
        _drawText(
          canvas,
          valueFormatter(value),
          Rect.fromLTWH(x - 26, plot.bottom + 8, 52, 16),
          labelStyle,
          align: TextAlign.center,
        );
      }
    }

    if (orientation == SimpleBarChartOrientation.vertical) {
      canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
      canvas.drawLine(plot.bottomLeft, plot.topLeft, axisPaint);
    } else {
      canvas.drawLine(plot.bottomLeft, plot.bottomRight, axisPaint);
      canvas.drawLine(plot.bottomLeft, plot.topLeft, axisPaint);
    }
  }

  void _drawReferenceBands(Canvas canvas, _ErrorBarGeometry geometry) {
    for (final band in referenceBands) {
      final start = math.min(band.from, band.to);
      final end = math.max(band.from, band.to);
      final color = band.color ?? activeColor;
      final rect = orientation == SimpleBarChartOrientation.vertical
          ? Rect.fromLTRB(
              geometry.plot.left,
              geometry.yForValue(end),
              geometry.plot.right,
              geometry.yForValue(start),
            )
          : Rect.fromLTRB(
              geometry.xForValue(start),
              geometry.plot.top,
              geometry.xForValue(end),
              geometry.plot.bottom,
            );
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      if (band.showLabel && band.label != null) {
        _drawText(
          canvas,
          band.label!,
          Rect.fromLTWH(
            rect.left + 4,
            rect.top + 4,
            math.max(0, rect.width - 8),
            16,
          ),
          labelStyle.copyWith(color: color),
        );
      }
    }
  }

  void _drawReferenceLines(Canvas canvas, _ErrorBarGeometry geometry) {
    for (final line in referenceLines) {
      final color = line.color ?? activeColor;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = line.strokeWidth;
      final start = orientation == SimpleBarChartOrientation.vertical
          ? Offset(geometry.plot.left, geometry.yForValue(line.value))
          : Offset(geometry.xForValue(line.value), geometry.plot.top);
      final end = orientation == SimpleBarChartOrientation.vertical
          ? Offset(geometry.plot.right, geometry.yForValue(line.value))
          : Offset(geometry.xForValue(line.value), geometry.plot.bottom);
      switch (line.lineStyle) {
        case SimpleChartReferenceLineStyle.solid:
          canvas.drawLine(start, end, paint);
        case SimpleChartReferenceLineStyle.dashed:
          _drawDashedLine(canvas, start, end, paint, dash: 6, gap: 5);
        case SimpleChartReferenceLineStyle.dotted:
          _drawDashedLine(canvas, start, end, paint, dash: 1, gap: 4);
      }
      if (line.showLabel && line.label != null) {
        _drawText(
          canvas,
          line.label!,
          Rect.fromLTWH(start.dx + 4, start.dy - 18, 58, 16),
          labelStyle.copyWith(color: color),
        );
      }
    }
  }

  void _drawMeanLine(Canvas canvas, _ErrorBarGeometry geometry) {
    if (geometry.hits.length < 2) {
      return;
    }
    final path = Path();
    for (var i = 0; i < geometry.hits.length; i++) {
      final offset = _animatedMarker(geometry.hits[i]);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, strokeWidth)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawPoint(Canvas canvas, _ErrorBarGeometry geometry, _ErrorBarHit hit) {
    final color = _itemColor(hit.data, hit.index);
    final active = activeIndex == hit.index;
    final marker = _animatedMarker(hit);
    final low = _animatedEnd(hit.lowOffset, marker, geometry);
    final high = _animatedEnd(hit.highOffset, marker, geometry);
    final barPaint = Paint()
      ..color = (active ? activeColor : errorColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? strokeWidth + 0.8 : strokeWidth
      ..strokeCap = StrokeCap.round;
    final capPaint = Paint()
      ..color = (active ? activeColor : capColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? strokeWidth + 0.8 : strokeWidth
      ..strokeCap = StrokeCap.round;
    final markerPaint = Paint()
      ..color = active ? activeColor : color
      ..style = PaintingStyle.fill;
    final markerBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(low, high, barPaint);
    if (showCaps) {
      _drawCap(canvas, low, capPaint);
      _drawCap(canvas, high, capPaint);
    }
    canvas.drawCircle(
      marker,
      active ? markerRadius + 1.5 : markerRadius,
      markerPaint,
    );
    canvas.drawCircle(
      marker,
      active ? markerRadius + 1.5 : markerRadius,
      markerBorder,
    );

    if (showLabels) {
      _drawCategoryLabel(canvas, geometry, hit);
    }
    if (showValues) {
      _drawValueLabel(canvas, geometry, hit, marker);
    }
    if (showErrorLabels) {
      _drawErrorLabels(canvas, geometry, hit, low, high);
    }
  }

  Offset _animatedMarker(_ErrorBarHit hit) {
    if (orientation == SimpleBarChartOrientation.vertical) {
      return Offset(
        hit.markerOffset.dx,
        hit.zeroOffset.dy +
            (hit.markerOffset.dy - hit.zeroOffset.dy) * progress,
      );
    }
    return Offset(
      hit.zeroOffset.dx + (hit.markerOffset.dx - hit.zeroOffset.dx) * progress,
      hit.markerOffset.dy,
    );
  }

  Offset _animatedEnd(
    Offset target,
    Offset marker,
    _ErrorBarGeometry geometry,
  ) {
    if (orientation == SimpleBarChartOrientation.vertical) {
      return Offset(
        target.dx,
        marker.dy + (target.dy - hitAwareMarkerY(marker, geometry)) * progress,
      );
    }
    return Offset(
      marker.dx + (target.dx - hitAwareMarkerX(marker, geometry)) * progress,
      target.dy,
    );
  }

  double hitAwareMarkerY(Offset marker, _ErrorBarGeometry geometry) =>
      marker.dy;

  double hitAwareMarkerX(Offset marker, _ErrorBarGeometry geometry) =>
      marker.dx;

  void _drawCap(Canvas canvas, Offset center, Paint paint) {
    if (orientation == SimpleBarChartOrientation.vertical) {
      canvas.drawLine(
        Offset(center.dx - capSize / 2, center.dy),
        Offset(center.dx + capSize / 2, center.dy),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(center.dx, center.dy - capSize / 2),
        Offset(center.dx, center.dy + capSize / 2),
        paint,
      );
    }
  }

  void _drawCategoryLabel(
    Canvas canvas,
    _ErrorBarGeometry geometry,
    _ErrorBarHit hit,
  ) {
    if (orientation == SimpleBarChartOrientation.vertical) {
      _drawText(
        canvas,
        hit.data.label,
        Rect.fromLTWH(
          hit.markerOffset.dx - geometry.bandWidth / 2,
          geometry.plot.bottom + 8,
          geometry.bandWidth,
          18,
        ),
        labelStyle,
        align: TextAlign.center,
      );
    } else {
      _drawText(
        canvas,
        hit.data.label,
        Rect.fromLTWH(
          0,
          hit.markerOffset.dy - 8,
          math.max(0, geometry.plot.left - 8),
          16,
        ),
        labelStyle,
        align: TextAlign.right,
      );
    }
  }

  void _drawValueLabel(
    Canvas canvas,
    _ErrorBarGeometry geometry,
    _ErrorBarHit hit,
    Offset marker,
  ) {
    final label = valueFormatter(hit.data.value);
    if (orientation == SimpleBarChartOrientation.vertical) {
      _drawText(
        canvas,
        label,
        Rect.fromLTWH(
          marker.dx - 24,
          math.min(hit.lowOffset.dy, hit.highOffset.dy) - 20,
          48,
          16,
        ),
        valueStyle,
        align: TextAlign.center,
      );
    } else {
      _drawText(
        canvas,
        label,
        Rect.fromLTWH(
          math.max(hit.lowOffset.dx, hit.highOffset.dx) + 5,
          marker.dy - 8,
          42,
          16,
        ),
        valueStyle,
      );
    }
  }

  void _drawErrorLabels(
    Canvas canvas,
    _ErrorBarGeometry geometry,
    _ErrorBarHit hit,
    Offset low,
    Offset high,
  ) {
    if (orientation == SimpleBarChartOrientation.vertical) {
      _drawText(
        canvas,
        valueFormatter(hit.data.high),
        Rect.fromLTWH(high.dx + 5, high.dy - 8, 44, 16),
        labelStyle,
      );
      _drawText(
        canvas,
        valueFormatter(hit.data.low),
        Rect.fromLTWH(low.dx + 5, low.dy - 8, 44, 16),
        labelStyle,
      );
    } else {
      _drawText(
        canvas,
        valueFormatter(hit.data.low),
        Rect.fromLTWH(low.dx - 24, low.dy + 6, 48, 16),
        labelStyle,
        align: TextAlign.center,
      );
      _drawText(
        canvas,
        valueFormatter(hit.data.high),
        Rect.fromLTWH(high.dx - 24, high.dy + 6, 48, 16),
        labelStyle,
        align: TextAlign.center,
      );
    }
  }

  Color _itemColor(SimpleErrorBarData item, int index) {
    if (item.color != null) {
      return item.color!;
    }
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return markerColor;
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
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
  bool shouldRepaint(covariant _SimpleErrorBarPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.orientation != orientation ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.errorColor != errorColor ||
        oldDelegate.capColor != capColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.includeZero != includeZero ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showErrorLabels != showErrorLabels ||
        oldDelegate.showCaps != showCaps ||
        oldDelegate.showLine != showLine ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.capSize != capSize ||
        oldDelegate.markerRadius != markerRadius ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _ErrorBarGeometry {
  final Rect plot;
  final double minValue;
  final double maxValue;
  final double valueSpan;
  final double bandWidth;
  final List<_ErrorBarHit> hits;

  const _ErrorBarGeometry({
    required this.plot,
    required this.minValue,
    required this.maxValue,
    required this.valueSpan,
    required this.bandWidth,
    required this.hits,
  });

  factory _ErrorBarGeometry.resolve({
    required List<SimpleErrorBarData> data,
    required Size size,
    required SimpleBarChartOrientation orientation,
    required EdgeInsets padding,
    required double? minValue,
    required double? maxValue,
    required bool includeZero,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    var low = data.fold<double>(
      data.first.low,
      (value, item) => math.min(value, math.min(item.low, item.value)),
    );
    var high = data.fold<double>(
      data.first.high,
      (value, item) => math.max(value, math.max(item.high, item.value)),
    );
    for (final line in referenceLines) {
      low = math.min(low, line.value);
      high = math.max(high, line.value);
    }
    for (final band in referenceBands) {
      low = math.min(low, math.min(band.from, band.to));
      high = math.max(high, math.max(band.from, band.to));
    }
    if (includeZero) {
      low = math.min(low, 0);
      high = math.max(high, 0);
    }
    final span = math.max(1e-9, high - low);
    final resolvedMin = minValue ?? low - span * 0.08;
    final resolvedMax = math.max(
      maxValue ?? high + span * 0.08,
      resolvedMin + 1e-9,
    );
    final valueSpan = resolvedMax - resolvedMin;
    final bandWidth = data.isEmpty
        ? 0.0
        : (orientation == SimpleBarChartOrientation.vertical
                  ? plot.width
                  : plot.height) /
              data.length;
    final hits = <_ErrorBarHit>[];
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final center = orientation == SimpleBarChartOrientation.vertical
          ? Offset(
              plot.left + bandWidth * (index + 0.5),
              yFor(item.value, plot, resolvedMin, valueSpan),
            )
          : Offset(
              xFor(item.value, plot, resolvedMin, valueSpan),
              plot.top + bandWidth * (index + 0.5),
            );
      final lowOffset = orientation == SimpleBarChartOrientation.vertical
          ? Offset(center.dx, yFor(item.low, plot, resolvedMin, valueSpan))
          : Offset(xFor(item.low, plot, resolvedMin, valueSpan), center.dy);
      final highOffset = orientation == SimpleBarChartOrientation.vertical
          ? Offset(center.dx, yFor(item.high, plot, resolvedMin, valueSpan))
          : Offset(xFor(item.high, plot, resolvedMin, valueSpan), center.dy);
      final zeroValue = resolvedMin <= 0 && resolvedMax >= 0
          ? 0.0
          : resolvedMin;
      final zeroOffset = orientation == SimpleBarChartOrientation.vertical
          ? Offset(center.dx, yFor(zeroValue, plot, resolvedMin, valueSpan))
          : Offset(xFor(zeroValue, plot, resolvedMin, valueSpan), center.dy);
      hits.add(
        _ErrorBarHit(
          data: item,
          index: index,
          markerOffset: center,
          lowOffset: lowOffset,
          highOffset: highOffset,
          zeroOffset: zeroOffset,
          hitRect: Rect.fromPoints(
            lowOffset,
            highOffset,
          ).expandToInclude(Rect.fromCircle(center: center, radius: 12)),
        ),
      );
    }

    return _ErrorBarGeometry(
      plot: plot,
      minValue: resolvedMin,
      maxValue: resolvedMax,
      valueSpan: valueSpan,
      bandWidth: bandWidth,
      hits: hits,
    );
  }

  double yForValue(double value) => yFor(value, plot, minValue, valueSpan);

  double xForValue(double value) => xFor(value, plot, minValue, valueSpan);

  static double yFor(
    double value,
    Rect plot,
    double minValue,
    double valueSpan,
  ) {
    final t = ((value - minValue) / valueSpan).clamp(0.0, 1.0);
    return plot.bottom - t * plot.height;
  }

  static double xFor(
    double value,
    Rect plot,
    double minValue,
    double valueSpan,
  ) {
    final t = ((value - minValue) / valueSpan).clamp(0.0, 1.0);
    return plot.left + t * plot.width;
  }
}

class _ErrorBarHit {
  final SimpleErrorBarData data;
  final int index;
  final Offset markerOffset;
  final Offset lowOffset;
  final Offset highOffset;
  final Offset zeroOffset;
  final Rect hitRect;

  const _ErrorBarHit({
    required this.data,
    required this.index,
    required this.markerOffset,
    required this.lowOffset,
    required this.highOffset,
    required this.zeroOffset,
    required this.hitRect,
  });
}

class _SimpleErrorBarVisuals {
  final Color markerColor;
  final Color errorColor;
  final Color lineColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double strokeWidth;
  final double capSize;
  final double markerRadius;

  const _SimpleErrorBarVisuals({
    required this.markerColor,
    required this.errorColor,
    required this.lineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.strokeWidth,
    required this.capSize,
    required this.markerRadius,
  });

  factory _SimpleErrorBarVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleErrorBarVisuals(
          markerColor: colorScheme.primary,
          errorColor: colorScheme.primary.withValues(alpha: 0.72),
          lineColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          activeColor: colorScheme.tertiary,
          strokeWidth: 2.2,
          capSize: 18,
          markerRadius: 4.8,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleErrorBarVisuals(
          markerColor: colorScheme.primary,
          errorColor: colorScheme.onSurface.withValues(alpha: 0.68),
          lineColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          activeColor: colorScheme.onSurface,
          strokeWidth: 1.8,
          capSize: 16,
          markerRadius: 4.2,
        );
      case SimpleBarChartStyle.education:
        return _SimpleErrorBarVisuals(
          markerColor: colorScheme.secondary,
          errorColor: colorScheme.secondary.withValues(alpha: 0.74),
          lineColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          activeColor: colorScheme.primary,
          strokeWidth: 2,
          capSize: 18,
          markerRadius: 4.6,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleErrorBarVisuals(
          markerColor: colorScheme.tertiary,
          errorColor: colorScheme.tertiary.withValues(alpha: 0.72),
          lineColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          activeColor: colorScheme.primary,
          strokeWidth: 2.4,
          capSize: 20,
          markerRadius: 5,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleErrorBarVisuals(
          markerColor: colorScheme.primary,
          errorColor: colorScheme.primary.withValues(alpha: 0.7),
          lineColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: colorScheme.tertiary,
          strokeWidth: 2,
          capSize: 18,
          markerRadius: 4.6,
        );
    }
  }
}

class _DefaultErrorBarTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultErrorBarTooltip({required this.title, required this.rows});

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
              for (final row in rows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 48, child: Text(row.label)),
                    Text(
                      row.value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
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
