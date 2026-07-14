import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleRadarValueFormatter = String Function(double value);
typedef SimpleRadarAxisTapCallback =
    void Function(
      String axisLabel,
      List<SimpleRadarTooltipItem> items,
      int axisIndex,
    );
typedef SimpleRadarTooltipBuilder =
    Widget Function(
      BuildContext context,
      String axisLabel,
      List<SimpleRadarTooltipItem> items,
      int axisIndex,
    );

class SimpleRadarAxis {
  final String label;
  final double minValue;
  final double maxValue;

  const SimpleRadarAxis({
    required this.label,
    this.minValue = 0,
    this.maxValue = 100,
  }) : assert(minValue != maxValue);
}

class SimpleRadarSeries {
  final String name;
  final List<double> values;
  final Color? color;

  const SimpleRadarSeries({
    required this.name,
    required this.values,
    this.color,
  });
}

class SimpleRadarTooltipItem {
  final String seriesName;
  final double value;
  final Color color;

  const SimpleRadarTooltipItem({
    required this.seriesName,
    required this.value,
    required this.color,
  });
}

/// A compact radar chart for comparing multi-dimensional scores and profiles.
class SimpleRadarChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(16, 14, 16, 14);

  final List<SimpleRadarAxis> axes;
  final List<SimpleRadarSeries> series;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showDots;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveAxis;
  final int gridLevels;
  final double? strokeWidth;
  final double? dotRadius;
  final double fillOpacity;
  final double startAngle;
  final SimpleRadarValueFormatter? valueFormatter;
  final SimpleRadarAxisTapCallback? onAxisTap;
  final SimpleRadarTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleRadarChart({
    super.key,
    required this.axes,
    required this.series,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = false,
    this.showDots = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveAxis = true,
    this.gridLevels = 4,
    this.strokeWidth,
    this.dotRadius,
    this.fillOpacity = 0.18,
    this.startAngle = -math.pi / 2,
    this.valueFormatter,
    this.onAxisTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 750),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLevels >= 2),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(dotRadius == null || dotRadius >= 0),
       assert(fillOpacity >= 0 && fillOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleRadarVisuals.resolve(style, colorScheme);
    final visibleAxes = axes
        .where(
          (axis) =>
              axis.minValue.isFinite &&
              axis.maxValue.isFinite &&
              axis.minValue != axis.maxValue,
        )
        .toList();
    final visibleSeries = series
        .where((item) => item.values.any((value) => value.isFinite))
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleAxes.length < 3 || visibleSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Radar chart, no data.',
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
            visibleAxes,
            visibleSeries,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleRadarChartView(
            width: width,
            height: chartHeight,
            axes: visibleAxes,
            series: visibleSeries,
            padding: padding,
            palette: _resolvePalette(visuals.palette),
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showLabels: showLabels,
            showValues: showValues,
            showDots: showDots,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveAxis: showActiveAxis,
            gridLevels: gridLevels,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            dotRadius: dotRadius ?? visuals.dotRadius,
            fillOpacity: fillOpacity,
            startAngle: startAngle,
            valueFormatter: formatter,
            onAxisTap: onAxisTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(List<Color> defaults) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return defaults;
  }

  String _defaultSemanticLabel(
    List<SimpleRadarAxis> visibleAxes,
    List<SimpleRadarSeries> visibleSeries,
    SimpleRadarValueFormatter formatter,
  ) {
    final summaries = visibleSeries
        .take(3)
        .map((item) {
          final values = visibleAxes
              .take(4)
              .map((axis) {
                final index = visibleAxes.indexOf(axis);
                final value = _valueAt(item, axis, index);
                return '${axis.label} ${formatter(value)}';
              })
              .join(', ');
          return '${item.name}: $values';
        })
        .join('; ');
    final remaining = visibleSeries.length - math.min(visibleSeries.length, 3);
    final suffix = remaining > 0 ? '; and $remaining more series' : '';
    final axisLabel = visibleAxes.length == 1 ? 'axis' : 'axes';
    final seriesLabel = visibleSeries.length == 1 ? 'series' : 'series';
    return 'Radar chart, ${visibleAxes.length} $axisLabel and '
        '${visibleSeries.length} $seriesLabel. $summaries$suffix.';
  }

  static double _valueAt(
    SimpleRadarSeries series,
    SimpleRadarAxis axis,
    int index,
  ) {
    if (index >= series.values.length || !series.values[index].isFinite) {
      return axis.minValue;
    }
    return series.values[index];
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleRadarChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleRadarAxis> axes;
  final List<SimpleRadarSeries> series;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showDots;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveAxis;
  final int gridLevels;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;
  final double startAngle;
  final SimpleRadarValueFormatter valueFormatter;
  final SimpleRadarAxisTapCallback? onAxisTap;
  final SimpleRadarTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleRadarChartView({
    required this.width,
    required this.height,
    required this.axes,
    required this.series,
    required this.padding,
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showDots,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveAxis,
    required this.gridLevels,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
    required this.startAngle,
    required this.valueFormatter,
    required this.onAxisTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleRadarChartView> createState() => _SimpleRadarChartViewState();
}

class _SimpleRadarChartViewState extends State<_SimpleRadarChartView> {
  int? _activeAxisIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveAxis || widget.onAxisTap != null;

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
                painter: _SimpleRadarPainter(
                  axes: widget.axes,
                  series: widget.series,
                  padding: widget.padding,
                  palette: widget.palette,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showLabels: widget.showLabels,
                  showValues: widget.showValues,
                  showDots: widget.showDots,
                  showLegend: widget.showLegend,
                  showActiveAxis: widget.showActiveAxis,
                  gridLevels: widget.gridLevels,
                  strokeWidth: widget.strokeWidth,
                  dotRadius: widget.dotRadius,
                  fillOpacity: widget.fillOpacity,
                  startAngle: widget.startAngle,
                  valueFormatter: widget.valueFormatter,
                  activeAxisIndex: widget.showActiveAxis
                      ? _activeAxisIndex
                      : null,
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
                        widget.onAxisTap?.call(
                          widget.axes[index].label,
                          _tooltipItems(index),
                          index,
                        );
                      }
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeAxisIndex != null)
                _buildTooltip(context, size, _activeAxisIndex!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(int? index) {
    if (_activeAxisIndex == index) return;
    setState(() => _activeAxisIndex = index);
  }

  int? _hitTest(Offset position, Size size) {
    final layout = _RadarLayout.resolve(
      size,
      widget.padding,
      widget.showLegend,
      widget.showLabels,
    );
    final distance = (position - layout.center).distance;
    if (distance > layout.radius + 42) return null;

    final angle = _normalizeAngle(
      math.atan2(
        position.dy - layout.center.dy,
        position.dx - layout.center.dx,
      ),
    );
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < widget.axes.length; index++) {
      final axisAngle = _normalizeAngle(
        widget.startAngle + index * math.pi * 2 / widget.axes.length,
      );
      final delta = _angleDistance(angle, axisAngle);
      if (delta < bestDistance) {
        bestDistance = delta;
        bestIndex = index;
      }
    }
    final halfSector = math.pi / widget.axes.length;
    return bestDistance <= halfSector + 0.06 ? bestIndex : null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final layout = _RadarLayout.resolve(
      size,
      widget.padding,
      widget.showLegend,
      widget.showLabels,
    );
    final angle = widget.startAngle + index * math.pi * 2 / widget.axes.length;
    final anchor = Offset(
      layout.center.dx + math.cos(angle) * (layout.radius + 16),
      layout.center.dy + math.sin(angle) * (layout.radius + 16),
    );
    const tooltipWidth = 190.0;
    const tooltipHeight = 86.0;
    final left = (anchor.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (anchor.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();
    final axisLabel = widget.axes[index].label;
    final items = _tooltipItems(index);

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(context, axisLabel, items, index) ??
          _DefaultRadarTooltip(
            title: axisLabel,
            items: items,
            valueFormatter: widget.valueFormatter,
          ),
    );
  }

  List<SimpleRadarTooltipItem> _tooltipItems(int axisIndex) {
    return List.generate(widget.series.length, (seriesIndex) {
      final item = widget.series[seriesIndex];
      final axis = widget.axes[axisIndex];
      final value =
          axisIndex < item.values.length && item.values[axisIndex].isFinite
          ? item.values[axisIndex]
          : axis.minValue;
      return SimpleRadarTooltipItem(
        seriesName: item.name,
        value: value,
        color: _seriesColor(item, seriesIndex),
      );
    });
  }

  Color _seriesColor(SimpleRadarSeries item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleRadarPainter extends CustomPainter {
  final List<SimpleRadarAxis> axes;
  final List<SimpleRadarSeries> series;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showDots;
  final bool showLegend;
  final bool showActiveAxis;
  final int gridLevels;
  final double strokeWidth;
  final double dotRadius;
  final double fillOpacity;
  final double startAngle;
  final SimpleRadarValueFormatter valueFormatter;
  final int? activeAxisIndex;
  final double progress;

  const _SimpleRadarPainter({
    required this.axes,
    required this.series,
    required this.padding,
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showDots,
    required this.showLegend,
    required this.showActiveAxis,
    required this.gridLevels,
    required this.strokeWidth,
    required this.dotRadius,
    required this.fillOpacity,
    required this.startAngle,
    required this.valueFormatter,
    required this.activeAxisIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _RadarLayout.resolve(size, padding, showLegend, showLabels);
    if (layout.radius <= 0 || axes.length < 3 || series.isEmpty) return;

    if (showGrid) {
      _drawWeb(canvas, layout);
    }
    _drawActiveAxis(canvas, layout);
    _drawSeries(canvas, layout);
    if (showLabels) {
      _drawAxisLabels(canvas, layout);
    }
    if (showLegend) {
      _drawLegend(canvas, layout);
    }
  }

  void _drawWeb(Canvas canvas, _RadarLayout layout) {
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var level = 1; level <= gridLevels; level++) {
      final fraction = level / gridLevels;
      final path = Path();
      for (var index = 0; index < axes.length; index++) {
        final point = _pointFor(index, fraction, layout);
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var index = 0; index < axes.length; index++) {
      final end = _pointFor(index, 1, layout);
      canvas.drawLine(layout.center, end, axisPaint);
    }
  }

  void _drawActiveAxis(Canvas canvas, _RadarLayout layout) {
    final index = activeAxisIndex;
    if (!showActiveAxis || index == null || index < 0 || index >= axes.length) {
      return;
    }
    final color = activeColor ?? axisColor;
    final end = _pointFor(index, 1, layout);
    canvas.drawLine(
      layout.center,
      end,
      Paint()
        ..color = color.withValues(alpha: 0.34)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final next = _pointFor((index + 1) % axes.length, 1, layout);
    final previous = _pointFor(
      (index - 1 + axes.length) % axes.length,
      1,
      layout,
    );
    final path = Path()
      ..moveTo(layout.center.dx, layout.center.dy)
      ..lineTo(
        end.dx + (previous.dx - end.dx) * 0.42,
        end.dy + (previous.dy - end.dy) * 0.42,
      )
      ..lineTo(
        end.dx + (next.dx - end.dx) * 0.42,
        end.dy + (next.dy - end.dy) * 0.42,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.06));
  }

  void _drawSeries(Canvas canvas, _RadarLayout layout) {
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final item = series[seriesIndex];
      final color = _seriesColor(item, seriesIndex);
      final points = List.generate(axes.length, (axisIndex) {
        final axis = axes[axisIndex];
        final value =
            axisIndex < item.values.length && item.values[axisIndex].isFinite
            ? item.values[axisIndex]
            : axis.minValue;
        final fraction = _normalize(value, axis) * progress;
        return _pointFor(axisIndex, fraction, layout);
      });
      final path = _pathFromPoints(points);

      if (fillOpacity > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: fillOpacity)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round,
      );

      if (showDots) {
        for (final point in points) {
          canvas.drawCircle(
            point,
            dotRadius + 1.2,
            Paint()..color = color.withValues(alpha: 0.16),
          );
          canvas.drawCircle(point, dotRadius, Paint()..color = color);
        }
      }

      if (showValues && series.length <= 2) {
        _drawValues(canvas, item, points, color, layout);
      }
    }
  }

  void _drawValues(
    Canvas canvas,
    SimpleRadarSeries item,
    List<Offset> points,
    Color color,
    _RadarLayout layout,
  ) {
    for (var index = 0; index < points.length; index++) {
      final axis = axes[index];
      final value = index < item.values.length && item.values[index].isFinite
          ? item.values[index]
          : axis.minValue;
      final angle = _axisAngle(index);
      final anchor =
          points[index] + Offset(math.cos(angle) * 8, math.sin(angle) * 8);
      final painter = _textPainter(
        valueFormatter(value),
        valueStyle.copyWith(
          color: color,
          fontSize: (valueStyle.fontSize ?? 11) * 0.92,
        ),
        maxWidth: 54,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 54);
      final x = _safeClamp(
        anchor.dx - painter.width / 2,
        layout.content.left + 2,
        layout.chartRight - painter.width - 2,
      );
      final y = _safeClamp(
        anchor.dy - painter.height / 2,
        layout.content.top + 2,
        layout.content.bottom - painter.height - 2,
      );
      painter.paint(canvas, Offset(x, y));
    }
  }

  void _drawAxisLabels(Canvas canvas, _RadarLayout layout) {
    for (var index = 0; index < axes.length; index++) {
      final angle = _axisAngle(index);
      final anchor = Offset(
        layout.center.dx + math.cos(angle) * (layout.radius + 22),
        layout.center.dy + math.sin(angle) * (layout.radius + 22),
      );
      final painter = _textPainter(
        axes[index].label,
        labelStyle,
        maxWidth: 88,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 88);
      final x = _safeClamp(
        anchor.dx - painter.width / 2,
        layout.content.left + 2,
        layout.chartRight - painter.width - 2,
      );
      final y = _safeClamp(
        anchor.dy - painter.height / 2,
        layout.content.top + 2,
        layout.content.bottom - painter.height - 2,
      );
      painter.paint(canvas, Offset(x, y));
    }
  }

  void _drawLegend(Canvas canvas, _RadarLayout layout) {
    if (layout.legendRect.width <= 0 || layout.legendRect.height <= 0) return;
    final rowHeight = math.max(22.0, layout.legendRect.height / series.length);
    final visibleRows = math.max(1, (layout.legendRect.height / 22).floor());
    final rowCount = math.min(series.length, visibleRows);

    for (var index = 0; index < rowCount; index++) {
      final item = series[index];
      final y = layout.legendRect.top + rowHeight * index + rowHeight / 2;
      final color = _seriesColor(item, index);
      canvas.drawCircle(
        Offset(layout.legendRect.left + 4, y),
        4,
        Paint()..color = color,
      );
      final painter = _textPainter(
        item.name,
        labelStyle,
        maxWidth: layout.legendRect.width - 16,
      )..layout(maxWidth: layout.legendRect.width - 16);
      painter.paint(
        canvas,
        Offset(layout.legendRect.left + 14, y - painter.height / 2),
      );
    }
  }

  Path _pathFromPoints(List<Offset> points) {
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Offset _pointFor(int axisIndex, double fraction, _RadarLayout layout) {
    final angle = _axisAngle(axisIndex);
    final distance = layout.radius * fraction;
    return Offset(
      layout.center.dx + math.cos(angle) * distance,
      layout.center.dy + math.sin(angle) * distance,
    );
  }

  double _axisAngle(int index) {
    return startAngle + index * math.pi * 2 / axes.length;
  }

  double _normalize(double value, SimpleRadarAxis axis) {
    final lower = math.min(axis.minValue, axis.maxValue);
    final upper = math.max(axis.minValue, axis.maxValue);
    return ((value - lower) / (upper - lower)).clamp(0.0, 1.0).toDouble();
  }

  Color _seriesColor(SimpleRadarSeries item, int index) {
    return item.color ?? palette[index % palette.length];
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
  bool shouldRepaint(covariant _SimpleRadarPainter oldDelegate) {
    return oldDelegate.axes != axes ||
        oldDelegate.series != series ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showDots != showDots ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveAxis != showActiveAxis ||
        oldDelegate.gridLevels != gridLevels ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeAxisIndex != activeAxisIndex ||
        oldDelegate.progress != progress;
  }
}

class _RadarLayout {
  final Rect content;
  final Offset center;
  final double radius;
  final Rect legendRect;
  final double chartRight;

  const _RadarLayout({
    required this.content,
    required this.center,
    required this.radius,
    required this.legendRect,
    required this.chartRight,
  });

  factory _RadarLayout.resolve(
    Size size,
    EdgeInsets padding,
    bool showLegend,
    bool showLabels,
  ) {
    final content = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    final compact = content.width < 390;
    final legendWidth = showLegend && !compact
        ? math.min(144.0, content.width * 0.32)
        : 0.0;
    final chartRect = Rect.fromLTRB(
      content.left,
      content.top,
      content.right - legendWidth - (legendWidth > 0 ? 14 : 0),
      content.bottom,
    );
    final labelInset = showLabels ? 32.0 : 12.0;
    final radius = math.max(
      0.0,
      math.min(chartRect.width, chartRect.height) / 2 - labelInset,
    );
    final center = chartRect.center;
    final legendRect = legendWidth <= 0
        ? Rect.zero
        : Rect.fromLTWH(
            chartRect.right + 14,
            content.top + 10,
            legendWidth,
            math.max(0.0, content.height - 20),
          );
    return _RadarLayout(
      content: content,
      center: center,
      radius: radius,
      legendRect: legendRect,
      chartRight: chartRect.right,
    );
  }
}

class _SimpleRadarVisuals {
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final double strokeWidth;
  final double dotRadius;

  const _SimpleRadarVisuals({
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.strokeWidth,
    required this.dotRadius,
  });

  factory _SimpleRadarVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleRadarVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF22C55E),
          ],
          gridColor: colorScheme.outline.withValues(alpha: 0.13),
          axisColor: colorScheme.outline.withValues(alpha: 0.42),
          strokeWidth: 2.6,
          dotRadius: 4.2,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleRadarVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.onSurfaceVariant,
            const Color(0xFF0F766E),
            const Color(0xFF64748B),
          ],
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          strokeWidth: 2,
          dotRadius: 3.4,
        );
      case SimpleBarChartStyle.education:
        return _SimpleRadarVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFFF59E0B),
          ],
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
          strokeWidth: 2.4,
          dotRadius: 4,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleRadarVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF14B8A6),
            const Color(0xFFEC4899),
          ],
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.4),
          strokeWidth: 2.8,
          dotRadius: 4.4,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleRadarVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF0F766E),
          ],
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          strokeWidth: 2.3,
          dotRadius: 3.8,
        );
    }
  }
}

class _DefaultRadarTooltip extends StatelessWidget {
  final String title;
  final List<SimpleRadarTooltipItem> items;
  final SimpleRadarValueFormatter valueFormatter;

  const _DefaultRadarTooltip({
    required this.title,
    required this.items,
    required this.valueFormatter,
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
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onInverseSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            for (final item in items.take(3)) ...[
              _RadarTooltipRow(item: item, valueFormatter: valueFormatter),
              if (item != items.take(3).last) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _RadarTooltipRow extends StatelessWidget {
  final SimpleRadarTooltipItem item;
  final SimpleRadarValueFormatter valueFormatter;

  const _RadarTooltipRow({required this.item, required this.valueFormatter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            item.seriesName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onInverseSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
        Text(
          valueFormatter(item.value),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onInverseSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

double _normalizeAngle(double angle) {
  var normalized = angle % (math.pi * 2);
  if (normalized < 0) normalized += math.pi * 2;
  return normalized;
}

double _angleDistance(double a, double b) {
  final diff = (a - b).abs() % (math.pi * 2);
  return diff > math.pi ? math.pi * 2 - diff : diff;
}
