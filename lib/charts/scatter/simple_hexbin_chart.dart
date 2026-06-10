import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleHexbinValueFormatter = String Function(double value);
typedef SimpleHexbinBinTapCallback = void Function(SimpleHexbinBin bin);
typedef SimpleHexbinTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleHexbinBin bin,
      String formattedValue,
      String formattedX,
      String formattedY,
    );

class SimpleHexbinPoint {
  final String? label;
  final double x;
  final double y;
  final double weight;
  final String? group;
  final Color? color;

  const SimpleHexbinPoint({
    this.label,
    required this.x,
    required this.y,
    this.weight = 1,
    this.group,
    this.color,
  });
}

class SimpleHexbinBin {
  final int column;
  final int row;
  final double centerX;
  final double centerY;
  final double value;
  final int pointCount;
  final List<SimpleHexbinPoint> points;
  final Color? color;

  const SimpleHexbinBin({
    required this.column,
    required this.row,
    required this.centerX,
    required this.centerY,
    required this.value,
    required this.pointCount,
    required this.points,
    this.color,
  });
}

/// A compact hexbin chart for dense scatter, location-like density,
/// clickstream concentration, cohorts, and operational hotspots.
class SimpleHexbinChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 24, 42);

  final List<SimpleHexbinPoint> points;
  final SimpleBarChartStyle style;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final double height;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color? binColor;
  final Color? emptyBinColor;
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
  final bool showActiveBin;
  final bool showAxisLabels;
  final bool showOutlines;
  final bool showEmptyBins;
  final bool useLogScale;
  final int gridLineCount;
  final double? cellRadius;
  final double minOpacity;
  final double maxOpacity;
  final SimpleHexbinValueFormatter? valueFormatter;
  final SimpleHexbinValueFormatter? xValueFormatter;
  final SimpleHexbinValueFormatter? yValueFormatter;
  final SimpleHexbinBinTapCallback? onBinTap;
  final SimpleHexbinTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleHexbinChart({
    super.key,
    required this.points,
    this.style = SimpleBarChartStyle.elegant,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.height = 260,
    this.padding = _defaultPadding,
    this.xAxisLabel,
    this.yAxisLabel,
    this.binColor,
    this.emptyBinColor,
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
    this.showActiveBin = true,
    this.showAxisLabels = true,
    this.showOutlines = true,
    this.showEmptyBins = false,
    this.useLogScale = false,
    this.gridLineCount = 4,
    this.cellRadius,
    this.minOpacity = 0.28,
    this.maxOpacity = 0.92,
    this.valueFormatter,
    this.xValueFormatter,
    this.yValueFormatter,
    this.onBinTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(cellRadius == null || cellRadius > 0),
       assert(minOpacity >= 0 && minOpacity <= 1),
       assert(maxOpacity >= 0 && maxOpacity <= 1),
       assert(minOpacity <= maxOpacity);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleHexbinVisuals.resolve(style, colorScheme);
    final visiblePoints = points
        .where(
          (point) =>
              point.x.isFinite &&
              point.y.isFinite &&
              point.weight.isFinite &&
              point.weight >= 0,
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final xFormatter = xValueFormatter ?? _defaultValueFormatter;
    final yFormatter = yValueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;
        final resolvedCellRadius = cellRadius ?? visuals.cellRadius;

        if (visiblePoints.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Hexbin chart, no data.',
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
              fontWeight: FontWeight.w800,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            );
        final semanticGeometry = _HexbinGeometry.resolve(
          points: visiblePoints,
          size: Size(width, chartHeight),
          padding: padding,
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          cellRadius: resolvedCellRadius,
        );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visiblePoints,
            semanticGeometry.bins,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleHexbinChartView(
            width: width,
            height: chartHeight,
            points: visiblePoints,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            padding: padding,
            xAxisLabel: xAxisLabel,
            yAxisLabel: yAxisLabel,
            cellRadius: resolvedCellRadius,
            palette: palette ?? visuals.palette,
            binColor: binColor ?? visuals.binColor,
            emptyBinColor: emptyBinColor ?? visuals.emptyBinColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveBin: showActiveBin,
            showAxisLabels: showAxisLabels,
            showOutlines: showOutlines,
            showEmptyBins: showEmptyBins,
            useLogScale: useLogScale,
            gridLineCount: gridLineCount,
            minOpacity: minOpacity,
            maxOpacity: maxOpacity,
            valueFormatter: formatter,
            xValueFormatter: xFormatter,
            yValueFormatter: yFormatter,
            onBinTap: onBinTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleHexbinPoint> points,
    List<_HexbinBinLayout> bins,
    SimpleHexbinValueFormatter formatter,
  ) {
    if (bins.isEmpty) {
      return 'Hexbin chart, ${points.length} points and no visible bins.';
    }
    final strongest = bins.reduce((a, b) {
      final compare = _metricFor(b.bin).compareTo(_metricFor(a.bin));
      if (compare > 0) return b;
      return a;
    });
    return 'Hexbin chart, ${points.length} points across ${bins.length} bins. '
        'Strongest bin ${formatter(_metricFor(strongest.bin))} near x '
        '${_defaultValueFormatter(strongest.bin.centerX)}, y '
        '${_defaultValueFormatter(strongest.bin.centerY)}.';
  }

  static double _metricFor(SimpleHexbinBin bin) {
    if (bin.value > 0) {
      return bin.value;
    }
    return bin.pointCount.toDouble();
  }

  static String _defaultValueFormatter(double value) {
    if (value.abs() >= 1000) {
      final precision = value.abs() >= 10000 ? 0 : 1;
      return '${(value / 1000).toStringAsFixed(precision)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleHexbinChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleHexbinPoint> points;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final double cellRadius;
  final List<Color> palette;
  final Color binColor;
  final Color emptyBinColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveBin;
  final bool showAxisLabels;
  final bool showOutlines;
  final bool showEmptyBins;
  final bool useLogScale;
  final int gridLineCount;
  final double minOpacity;
  final double maxOpacity;
  final SimpleHexbinValueFormatter valueFormatter;
  final SimpleHexbinValueFormatter xValueFormatter;
  final SimpleHexbinValueFormatter yValueFormatter;
  final SimpleHexbinBinTapCallback? onBinTap;
  final SimpleHexbinTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleHexbinChartView({
    required this.width,
    required this.height,
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.cellRadius,
    required this.palette,
    required this.binColor,
    required this.emptyBinColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveBin,
    required this.showAxisLabels,
    required this.showOutlines,
    required this.showEmptyBins,
    required this.useLogScale,
    required this.gridLineCount,
    required this.minOpacity,
    required this.maxOpacity,
    required this.valueFormatter,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.onBinTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleHexbinChartView> createState() => _SimpleHexbinChartViewState();
}

class _SimpleHexbinChartViewState extends State<_SimpleHexbinChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _HexbinBinLayout? _activeBin;

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
  void didUpdateWidget(covariant _SimpleHexbinChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points ||
        oldWidget.cellRadius != widget.cellRadius ||
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
                    if (widget.showActiveBin ||
                        widget.showTooltip ||
                        widget.onBinTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit != null) {
                        widget.onBinTap?.call(hit.bin);
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleHexbinPainter(
                        points: widget.points,
                        minX: widget.minX,
                        maxX: widget.maxX,
                        minY: widget.minY,
                        maxY: widget.maxY,
                        padding: widget.padding,
                        xAxisLabel: widget.xAxisLabel,
                        yAxisLabel: widget.yAxisLabel,
                        cellRadius: widget.cellRadius,
                        palette: widget.palette,
                        binColor: widget.binColor,
                        emptyBinColor: widget.emptyBinColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showValues: widget.showValues,
                        showLegend: widget.showLegend,
                        showActiveBin: widget.showActiveBin,
                        showAxisLabels: widget.showAxisLabels,
                        showOutlines: widget.showOutlines,
                        showEmptyBins: widget.showEmptyBins,
                        useLogScale: widget.useLogScale,
                        gridLineCount: widget.gridLineCount,
                        minOpacity: widget.minOpacity,
                        maxOpacity: widget.maxOpacity,
                        valueFormatter: widget.valueFormatter,
                        xValueFormatter: widget.xValueFormatter,
                        yValueFormatter: widget.yValueFormatter,
                        activeKey: _activeBin?.key,
                        progress: _animation.value,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeBin != null)
                _buildTooltip(context, _activeBin!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_HexbinBinLayout? hit) {
    if (_activeBin?.key == hit?.key) {
      return;
    }
    setState(() => _activeBin = hit);
  }

  _HexbinBinLayout? _hitTest(Offset position) {
    final geometry = _HexbinGeometry.resolve(
      points: widget.points,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      minX: widget.minX,
      maxX: widget.maxX,
      minY: widget.minY,
      maxY: widget.maxY,
      cellRadius: widget.cellRadius,
    );
    for (final bin in geometry.bins.reversed) {
      if (bin.path.contains(position)) {
        return bin;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _HexbinBinLayout hit) {
    final bin = hit.bin;
    final formattedValue = widget.valueFormatter(
      SimpleHexbinChart._metricFor(bin),
    );
    final formattedX = widget.xValueFormatter(bin.centerX);
    final formattedY = widget.yValueFormatter(bin.centerY);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          bin,
          formattedValue,
          formattedX,
          formattedY,
        ) ??
        _DefaultHexbinTooltip(
          color: _colorForBin(bin),
          title: _titleFor(bin),
          rows: [
            _HexbinTooltipRow('Value', formattedValue),
            _HexbinTooltipRow('Points', bin.pointCount.toString()),
            _HexbinTooltipRow(widget.xAxisLabel ?? 'X', formattedX),
            _HexbinTooltipRow(widget.yAxisLabel ?? 'Y', formattedY),
          ],
        );
    final maxLeft = math.max(8.0, widget.width - 214);
    final maxTop = math.max(8.0, widget.height - 132);
    final left = (hit.center.dx + 12).clamp(8.0, maxLeft).toDouble();
    final top = (hit.center.dy - 58).clamp(8.0, maxTop).toDouble();
    return Positioned(left: left, top: top, child: tooltip);
  }

  String _titleFor(SimpleHexbinBin bin) {
    if (bin.pointCount == 1) {
      final label = bin.points.first.label?.trim();
      if (label != null && label.isNotEmpty) {
        return label;
      }
    }
    return '${bin.pointCount} points';
  }

  Color _colorForBin(SimpleHexbinBin bin) {
    if (bin.color != null) {
      return bin.color!;
    }
    final group = bin.points.isEmpty ? null : bin.points.first.group;
    if (group != null && group.trim().isNotEmpty) {
      final groups = widget.points
          .map((point) => point.group)
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .toSet()
          .toList();
      final index = groups.indexOf(group);
      if (index >= 0 && widget.palette.isNotEmpty) {
        return widget.palette[index % widget.palette.length];
      }
    }
    return widget.binColor;
  }
}

class _SimpleHexbinPainter extends CustomPainter {
  final List<SimpleHexbinPoint> points;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final double cellRadius;
  final List<Color> palette;
  final Color binColor;
  final Color emptyBinColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showActiveBin;
  final bool showAxisLabels;
  final bool showOutlines;
  final bool showEmptyBins;
  final bool useLogScale;
  final int gridLineCount;
  final double minOpacity;
  final double maxOpacity;
  final SimpleHexbinValueFormatter valueFormatter;
  final SimpleHexbinValueFormatter xValueFormatter;
  final SimpleHexbinValueFormatter yValueFormatter;
  final String? activeKey;
  final double progress;

  const _SimpleHexbinPainter({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.cellRadius,
    required this.palette,
    required this.binColor,
    required this.emptyBinColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showActiveBin,
    required this.showAxisLabels,
    required this.showOutlines,
    required this.showEmptyBins,
    required this.useLogScale,
    required this.gridLineCount,
    required this.minOpacity,
    required this.maxOpacity,
    required this.valueFormatter,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.activeKey,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _HexbinGeometry.resolve(
      points: points,
      size: size,
      padding: padding,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      cellRadius: cellRadius,
    );
    if (geometry.plot.width <= 0 || geometry.plot.height <= 0) {
      return;
    }

    if (showGrid) {
      _drawGrid(canvas, geometry);
    }
    canvas.save();
    canvas.clipRect(geometry.plot.inflate(1));
    if (showEmptyBins) {
      _drawEmptyBins(canvas, geometry);
    }
    final bins = List<_HexbinBinLayout>.of(geometry.bins)
      ..sort(
        (a, b) => SimpleHexbinChart._metricFor(
          a.bin,
        ).compareTo(SimpleHexbinChart._metricFor(b.bin)),
      );
    for (final bin in bins) {
      _drawBin(canvas, geometry, bin);
    }
    canvas.restore();
    if (showAxisLabels) {
      _drawAxisLabels(canvas, geometry);
    }
    if (showLegend) {
      _drawLegend(canvas, geometry);
    }
  }

  void _drawGrid(Canvas canvas, _HexbinGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 0; index < gridLineCount; index++) {
      final ratio = gridLineCount == 1 ? 0.0 : index / (gridLineCount - 1);
      final x = geometry.plot.left + geometry.plot.width * ratio;
      final y = geometry.plot.bottom - geometry.plot.height * ratio;
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
      );
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
    }
    final axisPaint = Paint()
      ..color = axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.bottom),
      Offset(geometry.plot.right, geometry.plot.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.top),
      Offset(geometry.plot.left, geometry.plot.bottom),
      axisPaint,
    );
  }

  void _drawEmptyBins(Canvas canvas, _HexbinGeometry geometry) {
    final paint = Paint()
      ..color = emptyBinColor
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = axisColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final cell in geometry.emptyCells) {
      canvas.drawPath(cell.path, paint);
      if (showOutlines) {
        canvas.drawPath(cell.path, outlinePaint);
      }
    }
  }

  void _drawBin(Canvas canvas, _HexbinGeometry geometry, _HexbinBinLayout bin) {
    final active = showActiveBin && activeKey == bin.key;
    final color = active ? activeColor : _colorForBin(bin.bin);
    final normalized = _normalizedMetric(bin.bin, geometry);
    final alpha =
        (minOpacity + (maxOpacity - minOpacity) * normalized) * progress;
    canvas.drawPath(
      bin.path,
      Paint()
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill,
    );
    if (showOutlines || active) {
      canvas.drawPath(
        bin.path,
        Paint()
          ..color = (active ? activeColor : axisColor).withValues(
            alpha: active ? 0.86 : 0.28,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 1.8 : 0.9,
      );
    }
    if (showValues && geometry.radius >= 12 && normalized > 0.35) {
      _drawText(
        canvas,
        valueFormatter(SimpleHexbinChart._metricFor(bin.bin)),
        Rect.fromCenter(
          center: bin.center,
          width: geometry.radius * 1.7,
          height: 15,
        ),
        valueStyle.copyWith(color: _labelColorFor(normalized)),
        align: TextAlign.center,
      );
    }
  }

  void _drawAxisLabels(Canvas canvas, _HexbinGeometry geometry) {
    final bounds = geometry.bounds;
    _drawText(
      canvas,
      xValueFormatter(bounds.minX),
      Rect.fromLTWH(geometry.plot.left - 8, geometry.plot.bottom + 4, 48, 14),
      labelStyle.copyWith(color: axisColor),
    );
    _drawText(
      canvas,
      xValueFormatter(bounds.maxX),
      Rect.fromLTWH(geometry.plot.right - 40, geometry.plot.bottom + 4, 48, 14),
      labelStyle.copyWith(color: axisColor),
      align: TextAlign.right,
    );
    _drawText(
      canvas,
      yValueFormatter(bounds.maxY),
      Rect.fromLTWH(2, geometry.plot.top - 7, geometry.plot.left - 8, 14),
      labelStyle.copyWith(color: axisColor),
      align: TextAlign.right,
    );
    _drawText(
      canvas,
      yValueFormatter(bounds.minY),
      Rect.fromLTWH(2, geometry.plot.bottom - 7, geometry.plot.left - 8, 14),
      labelStyle.copyWith(color: axisColor),
      align: TextAlign.right,
    );
    if (xAxisLabel != null && xAxisLabel!.trim().isNotEmpty) {
      _drawText(
        canvas,
        xAxisLabel!,
        Rect.fromLTWH(
          geometry.plot.left + 42,
          geometry.plot.bottom + 20,
          math.max(0, geometry.plot.width - 84),
          16,
        ),
        labelStyle.copyWith(color: axisColor),
        align: TextAlign.center,
      );
    }
    if (yAxisLabel != null && yAxisLabel!.trim().isNotEmpty) {
      _drawText(
        canvas,
        yAxisLabel!,
        Rect.fromLTWH(2, geometry.plot.top + 8, geometry.plot.left - 10, 16),
        labelStyle.copyWith(color: axisColor),
        align: TextAlign.right,
      );
    }
  }

  void _drawLegend(Canvas canvas, _HexbinGeometry geometry) {
    if (geometry.plot.width < 150 || geometry.bins.isEmpty) {
      return;
    }
    const swatchCount = 5;
    const swatchWidth = 13.0;
    const swatchHeight = 7.0;
    final left = geometry.plot.right - swatchCount * swatchWidth - 48;
    final top = geometry.plot.top + 4;
    if (left < geometry.plot.left + 12) {
      return;
    }
    for (var index = 0; index < swatchCount; index++) {
      final t = (index + 1) / swatchCount;
      final alpha = minOpacity + (maxOpacity - minOpacity) * t;
      final rect = Rect.fromLTWH(
        left + index * swatchWidth,
        top,
        swatchWidth - 1,
        swatchHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..color = binColor.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
    }
    _drawText(
      canvas,
      valueFormatter(geometry.maxMetric),
      Rect.fromLTWH(left + swatchCount * swatchWidth + 5, top - 4, 42, 14),
      labelStyle.copyWith(color: axisColor),
    );
  }

  double _normalizedMetric(SimpleHexbinBin bin, _HexbinGeometry geometry) {
    final metric = SimpleHexbinChart._metricFor(bin);
    if (geometry.maxMetric <= 0) {
      return 0;
    }
    if (useLogScale) {
      return (math.log(1 + metric) / math.log(1 + geometry.maxMetric)).clamp(
        0.0,
        1.0,
      );
    }
    return (metric / geometry.maxMetric).clamp(0.0, 1.0);
  }

  Color _colorForBin(SimpleHexbinBin bin) {
    if (bin.color != null) {
      return bin.color!;
    }
    final group = bin.points.isEmpty ? null : bin.points.first.group;
    if (group != null && group.trim().isNotEmpty) {
      final groups = points
          .map((point) => point.group)
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .toSet()
          .toList();
      final index = groups.indexOf(group);
      if (index >= 0 && palette.isNotEmpty) {
        return palette[index % palette.length];
      }
    }
    return binColor;
  }

  Color _labelColorFor(double normalized) {
    if (normalized > 0.7) {
      return Colors.white;
    }
    return valueStyle.color ?? Colors.black;
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
  bool shouldRepaint(covariant _SimpleHexbinPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.padding != padding ||
        oldDelegate.xAxisLabel != xAxisLabel ||
        oldDelegate.yAxisLabel != yAxisLabel ||
        oldDelegate.cellRadius != cellRadius ||
        oldDelegate.palette != palette ||
        oldDelegate.binColor != binColor ||
        oldDelegate.emptyBinColor != emptyBinColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveBin != showActiveBin ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.showOutlines != showOutlines ||
        oldDelegate.showEmptyBins != showEmptyBins ||
        oldDelegate.useLogScale != useLogScale ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.minOpacity != minOpacity ||
        oldDelegate.maxOpacity != maxOpacity ||
        oldDelegate.activeKey != activeKey ||
        oldDelegate.progress != progress;
  }
}

class _HexbinGeometry {
  final Rect plot;
  final _HexbinBounds bounds;
  final List<_HexbinCellLayout> emptyCells;
  final List<_HexbinBinLayout> bins;
  final double radius;
  final double maxMetric;

  const _HexbinGeometry({
    required this.plot,
    required this.bounds,
    required this.emptyCells,
    required this.bins,
    required this.radius,
    required this.maxMetric,
  });

  factory _HexbinGeometry.resolve({
    required List<SimpleHexbinPoint> points,
    required Size size,
    required EdgeInsets padding,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
    required double cellRadius,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final bounds = _HexbinBounds.resolve(
      points: points,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
    if (points.isEmpty || plot.width <= 0 || plot.height <= 0) {
      return _HexbinGeometry(
        plot: plot,
        bounds: bounds,
        emptyCells: const [],
        bins: const [],
        radius: 0,
        maxMetric: 0,
      );
    }

    final radius = math.max(
      4.0,
      math.min(cellRadius, math.min(plot.width, plot.height) / 3),
    );
    final hexHalfHeight = math.sqrt(3) * radius / 2;
    final rowStep = hexHalfHeight * 2;
    final columnStep = radius * 1.5;
    final maxColumn = math.max(
      0,
      ((plot.width - radius * 2) / columnStep).floor(),
    );

    final accumulators = <String, _HexbinAccumulator>{};
    final allCells = <_HexbinCellLayout>[];
    for (var column = 0; column <= maxColumn; column++) {
      final offsetY = column.isOdd ? rowStep / 2 : 0.0;
      final maxRow = math.max(
        0,
        ((plot.height - hexHalfHeight * 2 - offsetY) / rowStep).floor(),
      );
      for (var row = 0; row <= maxRow; row++) {
        final center = _centerFor(
          plot: plot,
          radius: radius,
          rowStep: rowStep,
          columnStep: columnStep,
          column: column,
          row: row,
        );
        allCells.add(
          _HexbinCellLayout(
            key: '$column:$row',
            center: center,
            path: _hexPath(center, radius),
          ),
        );
      }
    }

    for (final point in points) {
      final offset = Offset(
        plot.left + ((point.x - bounds.minX) / bounds.xRange) * plot.width,
        plot.bottom - ((point.y - bounds.minY) / bounds.yRange) * plot.height,
      );
      var column = ((offset.dx - (plot.left + radius)) / columnStep).round();
      column = column.clamp(0, maxColumn).toInt();
      final offsetY = column.isOdd ? rowStep / 2 : 0.0;
      final maxRow = math.max(
        0,
        ((plot.height - hexHalfHeight * 2 - offsetY) / rowStep).floor(),
      );
      var row = ((offset.dy - (plot.top + hexHalfHeight + offsetY)) / rowStep)
          .round();
      row = row.clamp(0, maxRow).toInt();
      final key = '$column:$row';
      final center = _centerFor(
        plot: plot,
        radius: radius,
        rowStep: rowStep,
        columnStep: columnStep,
        column: column,
        row: row,
      );
      final accumulator = accumulators.putIfAbsent(
        key,
        () => _HexbinAccumulator(column: column, row: row, center: center),
      );
      accumulator.add(point);
    }

    final bins = <_HexbinBinLayout>[];
    var maxMetric = 0.0;
    for (final entry in accumulators.entries) {
      final accumulator = entry.value;
      final centerX =
          bounds.minX +
          ((accumulator.center.dx - plot.left) / plot.width) * bounds.xRange;
      final centerY =
          bounds.minY +
          ((plot.bottom - accumulator.center.dy) / plot.height) * bounds.yRange;
      final bin = SimpleHexbinBin(
        column: accumulator.column,
        row: accumulator.row,
        centerX: centerX,
        centerY: centerY,
        value: accumulator.value,
        pointCount: accumulator.points.length,
        points: List.unmodifiable(accumulator.points),
        color: _sharedColor(accumulator.points),
      );
      maxMetric = math.max(maxMetric, SimpleHexbinChart._metricFor(bin));
      bins.add(
        _HexbinBinLayout(
          key: entry.key,
          bin: bin,
          center: accumulator.center,
          path: _hexPath(accumulator.center, radius),
        ),
      );
    }
    bins.sort((a, b) {
      final valueCompare = SimpleHexbinChart._metricFor(
        b.bin,
      ).compareTo(SimpleHexbinChart._metricFor(a.bin));
      if (valueCompare != 0) return valueCompare;
      return a.key.compareTo(b.key);
    });

    return _HexbinGeometry(
      plot: plot,
      bounds: bounds,
      emptyCells: allCells
          .where((cell) => !accumulators.containsKey(cell.key))
          .toList(),
      bins: bins,
      radius: radius,
      maxMetric: maxMetric,
    );
  }

  static Offset _centerFor({
    required Rect plot,
    required double radius,
    required double rowStep,
    required double columnStep,
    required int column,
    required int row,
  }) {
    final hexHalfHeight = rowStep / 2;
    return Offset(
      plot.left + radius + columnStep * column,
      plot.top +
          hexHalfHeight +
          rowStep * row +
          (column.isOdd ? rowStep / 2 : 0),
    );
  }

  static Path _hexPath(Offset center, double radius) {
    final path = Path();
    for (var index = 0; index < 6; index++) {
      final angle = math.pi / 3 * index;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  static Color? _sharedColor(List<SimpleHexbinPoint> points) {
    Color? color;
    for (final point in points) {
      if (point.color == null) {
        continue;
      }
      color ??= point.color;
      if (color != point.color) {
        return null;
      }
    }
    return color;
  }
}

class _HexbinBounds {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _HexbinBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  double get xRange => math.max(0.0001, maxX - minX);
  double get yRange => math.max(0.0001, maxY - minY);

  factory _HexbinBounds.resolve({
    required List<SimpleHexbinPoint> points,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
  }) {
    var resolvedMinX = minX ?? points.map((point) => point.x).reduce(math.min);
    var resolvedMaxX = maxX ?? points.map((point) => point.x).reduce(math.max);
    var resolvedMinY = minY ?? points.map((point) => point.y).reduce(math.min);
    var resolvedMaxY = maxY ?? points.map((point) => point.y).reduce(math.max);
    if (resolvedMinX == resolvedMaxX) {
      resolvedMinX -= 1;
      resolvedMaxX += 1;
    }
    if (resolvedMinY == resolvedMaxY) {
      resolvedMinY -= 1;
      resolvedMaxY += 1;
    }
    if (resolvedMinX > resolvedMaxX) {
      final temp = resolvedMinX;
      resolvedMinX = resolvedMaxX;
      resolvedMaxX = temp;
    }
    if (resolvedMinY > resolvedMaxY) {
      final temp = resolvedMinY;
      resolvedMinY = resolvedMaxY;
      resolvedMaxY = temp;
    }
    return _HexbinBounds(
      minX: resolvedMinX,
      maxX: resolvedMaxX,
      minY: resolvedMinY,
      maxY: resolvedMaxY,
    );
  }
}

class _HexbinAccumulator {
  final int column;
  final int row;
  final Offset center;
  final List<SimpleHexbinPoint> points = [];
  double value = 0;

  _HexbinAccumulator({
    required this.column,
    required this.row,
    required this.center,
  });

  void add(SimpleHexbinPoint point) {
    points.add(point);
    value += point.weight;
  }
}

class _HexbinCellLayout {
  final String key;
  final Offset center;
  final Path path;

  const _HexbinCellLayout({
    required this.key,
    required this.center,
    required this.path,
  });
}

class _HexbinBinLayout {
  final String key;
  final SimpleHexbinBin bin;
  final Offset center;
  final Path path;

  const _HexbinBinLayout({
    required this.key,
    required this.bin,
    required this.center,
    required this.path,
  });
}

class _SimpleHexbinVisuals {
  final List<Color> palette;
  final Color binColor;
  final Color emptyBinColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double cellRadius;

  const _SimpleHexbinVisuals({
    required this.palette,
    required this.binColor,
    required this.emptyBinColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.cellRadius,
  });

  factory _SimpleHexbinVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleHexbinVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
          ],
          binColor: colorScheme.primary,
          emptyBinColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.38,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          activeColor: colorScheme.tertiary,
          cellRadius: 14,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleHexbinVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            const Color(0xFF0F766E),
            const Color(0xFF64748B),
          ],
          binColor: colorScheme.primary,
          emptyBinColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          activeColor: colorScheme.onSurface,
          cellRadius: 13,
        );
      case SimpleBarChartStyle.education:
        return _SimpleHexbinVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFFF59E0B),
          ],
          binColor: colorScheme.secondary,
          emptyBinColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.42,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          activeColor: colorScheme.primary,
          cellRadius: 14,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleHexbinVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFEC4899),
          ],
          binColor: colorScheme.tertiary,
          emptyBinColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.34,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          activeColor: colorScheme.primary,
          cellRadius: 15,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleHexbinVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
          ],
          binColor: colorScheme.primary,
          emptyBinColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: colorScheme.tertiary,
          cellRadius: 14,
        );
    }
  }
}

class _DefaultHexbinTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final List<_HexbinTooltipRow> rows;

  const _DefaultHexbinTooltip({
    required this.color,
    required this.title,
    required this.rows,
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
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
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _HexbinTooltipRowWidget(row: row),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HexbinTooltipRowWidget extends StatelessWidget {
  final _HexbinTooltipRow row;

  const _HexbinTooltipRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            row.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onInverseSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
        Flexible(
          child: Text(
            row.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onInverseSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HexbinTooltipRow {
  final String label;
  final String value;

  const _HexbinTooltipRow(this.label, this.value);
}
