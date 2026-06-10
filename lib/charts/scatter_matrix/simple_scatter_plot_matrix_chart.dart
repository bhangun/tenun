import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleScatterPlotMatrixValueFormatter = String Function(double value);
typedef SimpleScatterPlotMatrixTapCallback =
    void Function(
      SimpleScatterPlotMatrixPoint point,
      int pointIndex,
      String xVariable,
      String yVariable,
    );
typedef SimpleScatterPlotMatrixTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleScatterPlotMatrixPoint point,
      int pointIndex,
      String xVariable,
      String yVariable,
      String formattedX,
      String formattedY,
    );

class SimpleScatterPlotMatrixPoint {
  final String? label;
  final List<double> values;
  final String? group;
  final Color? color;

  const SimpleScatterPlotMatrixPoint({
    this.label,
    required this.values,
    this.group,
    this.color,
  });
}

/// A compact scatter plot matrix for exploratory analysis across multiple
/// numeric dimensions, with pairwise scatter cells and diagonal histograms.
class SimpleScatterPlotMatrixChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(56, 24, 22, 48);

  final List<String> variableLabels;
  final List<SimpleScatterPlotMatrixPoint> points;
  final SimpleBarChartStyle style;
  final List<double> minValues;
  final List<double> maxValues;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? pointColor;
  final Color? histogramColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showDiagonalHistograms;
  final bool showVariableLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final int histogramBinCount;
  final double pointRadius;
  final double pointOpacity;
  final SimpleScatterPlotMatrixValueFormatter? valueFormatter;
  final SimpleScatterPlotMatrixTapCallback? onPointTap;
  final SimpleScatterPlotMatrixTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleScatterPlotMatrixChart({
    super.key,
    this.variableLabels = const [],
    required this.points,
    this.style = SimpleBarChartStyle.elegant,
    this.minValues = const [],
    this.maxValues = const [],
    this.height = 320,
    this.padding = _defaultPadding,
    this.palette,
    this.pointColor,
    this.histogramColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showDiagonalHistograms = true,
    this.showVariableLabels = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.histogramBinCount = 6,
    this.pointRadius = 3.2,
    this.pointOpacity = 0.78,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(histogramBinCount > 0),
       assert(pointRadius >= 0),
       assert(pointOpacity >= 0 && pointOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleScatterMatrixVisuals.resolve(style, colorScheme);
    final model = _ScatterMatrixModel.resolve(
      variableLabels: variableLabels,
      points: points,
      minValues: minValues,
      maxValues: maxValues,
    );
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (model.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Scatter plot matrix chart, no data.',
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
          semanticLabel: _defaultSemanticLabel(model, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleScatterPlotMatrixView(
            width: width,
            height: chartHeight,
            model: model,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals),
            pointColor: pointColor ?? visuals.pointColor,
            histogramColor: histogramColor ?? visuals.histogramColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showDiagonalHistograms: showDiagonalHistograms,
            showVariableLabels: showVariableLabels,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            histogramBinCount: histogramBinCount,
            pointRadius: pointRadius,
            pointOpacity: pointOpacity,
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

  List<Color> _resolvePalette(
    ColorScheme colorScheme,
    _SimpleScatterMatrixVisuals visuals,
  ) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    if (pointColor != null) {
      return [
        pointColor!,
        colorScheme.secondary,
        colorScheme.tertiary,
        colorScheme.error,
      ];
    }
    return visuals.palette;
  }

  String _defaultSemanticLabel(
    _ScatterMatrixModel model,
    SimpleScatterPlotMatrixValueFormatter formatter,
  ) {
    if (model.isEmpty) return 'Scatter plot matrix chart, no data.';
    final variables = model.labels.take(5).join(', ');
    final first = model.points.first;
    final firstSummary = model.labels
        .take(math.min(3, model.variableCount))
        .toList()
        .asMap()
        .entries
        .map((entry) => '${entry.value} ${formatter(first.values[entry.key])}')
        .join(', ');
    final suffix = model.variableCount > 5
        ? ', and ${model.variableCount - 5} more variables'
        : '';
    return 'Scatter plot matrix chart, ${model.variableCount} variables '
        '($variables$suffix) and ${model.points.length} points. '
        '${first.label ?? 'First point'} $firstSummary.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    final absolute = value.abs();
    if (absolute >= 10) return value.toStringAsFixed(0);
    if (absolute >= 1) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }
}

class _SimpleScatterPlotMatrixView extends StatefulWidget {
  final double width;
  final double height;
  final _ScatterMatrixModel model;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color pointColor;
  final Color histogramColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showDiagonalHistograms;
  final bool showVariableLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final int histogramBinCount;
  final double pointRadius;
  final double pointOpacity;
  final SimpleScatterPlotMatrixValueFormatter valueFormatter;
  final SimpleScatterPlotMatrixTapCallback? onPointTap;
  final SimpleScatterPlotMatrixTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleScatterPlotMatrixView({
    required this.width,
    required this.height,
    required this.model,
    required this.padding,
    required this.palette,
    required this.pointColor,
    required this.histogramColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showDiagonalHistograms,
    required this.showVariableLabels,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.histogramBinCount,
    required this.pointRadius,
    required this.pointOpacity,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleScatterPlotMatrixView> createState() =>
      _SimpleScatterPlotMatrixViewState();
}

class _SimpleScatterPlotMatrixViewState
    extends State<_SimpleScatterPlotMatrixView> {
  _ScatterMatrixHit? _activeHit;

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
                painter: _SimpleScatterPlotMatrixPainter(
                  model: widget.model,
                  padding: widget.padding,
                  palette: widget.palette,
                  pointColor: widget.pointColor,
                  histogramColor: widget.histogramColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showDiagonalHistograms: widget.showDiagonalHistograms,
                  showVariableLabels: widget.showVariableLabels,
                  showLegend: widget.showLegend,
                  showActivePoint: widget.showActivePoint,
                  histogramBinCount: widget.histogramBinCount,
                  pointRadius: widget.pointRadius,
                  pointOpacity: widget.pointOpacity,
                  valueFormatter: widget.valueFormatter,
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
                      if (hit != null) {
                        final point = widget.model.points[hit.pointIndex];
                        widget.onPointTap?.call(
                          point,
                          hit.pointIndex,
                          widget.model.labels[hit.xVariableIndex],
                          widget.model.labels[hit.yVariableIndex],
                        );
                      }
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

  void _setActive(_ScatterMatrixHit? hit) {
    if (_activeHit == hit) return;
    setState(() => _activeHit = hit);
  }

  _ScatterMatrixHit? _hitTest(Offset position, Size size) {
    final geometry = _ScatterMatrixGeometry.resolve(
      size: size,
      padding: widget.padding,
      model: widget.model,
    );
    if (!geometry.matrixRect.contains(position)) return null;
    var bestDistance = double.infinity;
    _ScatterMatrixHit? bestHit;
    for (var row = 0; row < widget.model.variableCount; row++) {
      for (var column = 0; column < widget.model.variableCount; column++) {
        if (row == column) continue;
        final cell = geometry.cell(row, column);
        if (!cell.contains(position)) continue;
        for (var index = 0; index < widget.model.points.length; index++) {
          final pointPosition = geometry.pointOffset(
            row: row,
            column: column,
            point: widget.model.points[index],
          );
          final distance = (pointPosition - position).distance;
          final threshold = math.max(8.0, widget.pointRadius + 5);
          if (distance <= threshold && distance < bestDistance) {
            bestDistance = distance;
            bestHit = _ScatterMatrixHit(
              pointIndex: index,
              xVariableIndex: column,
              yVariableIndex: row,
              position: pointPosition,
            );
          }
        }
      }
    }
    return bestHit;
  }

  Widget _buildTooltip(BuildContext context, Size size, _ScatterMatrixHit hit) {
    final point = widget.model.points[hit.pointIndex];
    final xVariable = widget.model.labels[hit.xVariableIndex];
    final yVariable = widget.model.labels[hit.yVariableIndex];
    final formattedX = widget.valueFormatter(point.values[hit.xVariableIndex]);
    final formattedY = widget.valueFormatter(point.values[hit.yVariableIndex]);
    const tooltipWidth = 180.0;
    const tooltipHeight = 80.0;
    final left = (hit.position.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (hit.position.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            point,
            hit.pointIndex,
            xVariable,
            yVariable,
            formattedX,
            formattedY,
          ) ??
          _DefaultScatterMatrixTooltip(
            color: _pointColor(point, hit.pointIndex),
            title: point.label ?? 'Point ${hit.pointIndex + 1}',
            rows: [
              _ScatterMatrixTooltipRow(label: xVariable, value: formattedX),
              _ScatterMatrixTooltipRow(label: yVariable, value: formattedY),
              if (point.group != null)
                _ScatterMatrixTooltipRow(label: 'Group', value: point.group!),
            ],
          ),
    );
  }

  Color _pointColor(SimpleScatterPlotMatrixPoint point, int index) {
    if (point.color != null) return point.color!;
    final groupIndex = widget.model.groupIndex(point.group, index);
    return point.group == null
        ? widget.pointColor
        : widget.palette[groupIndex % widget.palette.length];
  }
}

class _SimpleScatterPlotMatrixPainter extends CustomPainter {
  final _ScatterMatrixModel model;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color pointColor;
  final Color histogramColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showDiagonalHistograms;
  final bool showVariableLabels;
  final bool showLegend;
  final bool showActivePoint;
  final int histogramBinCount;
  final double pointRadius;
  final double pointOpacity;
  final SimpleScatterPlotMatrixValueFormatter valueFormatter;
  final _ScatterMatrixHit? activeHit;
  final double progress;

  const _SimpleScatterPlotMatrixPainter({
    required this.model,
    required this.padding,
    required this.palette,
    required this.pointColor,
    required this.histogramColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showDiagonalHistograms,
    required this.showVariableLabels,
    required this.showLegend,
    required this.showActivePoint,
    required this.histogramBinCount,
    required this.pointRadius,
    required this.pointOpacity,
    required this.valueFormatter,
    required this.activeHit,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _ScatterMatrixGeometry.resolve(
      size: size,
      padding: padding,
      model: model,
    );
    if (geometry.matrixRect.width <= 0 || geometry.matrixRect.height <= 0) {
      return;
    }

    _drawCells(canvas, geometry);
    if (showVariableLabels) _drawVariableLabels(canvas, geometry);
    if (showLegend) _drawLegend(canvas, geometry);
  }

  void _drawCells(Canvas canvas, _ScatterMatrixGeometry geometry) {
    for (var row = 0; row < model.variableCount; row++) {
      for (var column = 0; column < model.variableCount; column++) {
        final rect = geometry.cell(row, column);
        canvas.drawRect(
          rect,
          Paint()..color = axisColor.withValues(alpha: 0.035),
        );
        if (showGrid) _drawCellGrid(canvas, rect);
        if (row == column && showDiagonalHistograms) {
          _drawHistogram(canvas, rect, row);
        } else if (row != column) {
          _drawScatter(canvas, geometry, row, column);
        }
        canvas.drawRect(
          rect,
          Paint()
            ..color = axisColor.withValues(alpha: 0.34)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  void _drawCellGrid(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8;
    for (var index = 1; index < 4; index++) {
      final t = index / 4;
      final x = rect.left + rect.width * t;
      final y = rect.top + rect.height * t;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
  }

  void _drawHistogram(Canvas canvas, Rect rect, int variableIndex) {
    final counts = List<int>.filled(histogramBinCount, 0);
    final range = model.ranges[variableIndex];
    for (final point in model.points) {
      final raw = ((point.values[variableIndex] - range.min) / range.span)
          .clamp(0.0, 0.999999);
      final index = (raw * histogramBinCount).floor();
      counts[index] += 1;
    }
    final maxCount = counts.fold<int>(1, math.max);
    final barWidth = rect.width / histogramBinCount;
    for (var index = 0; index < counts.length; index++) {
      final height = rect.height * 0.72 * counts[index] / maxCount * progress;
      final barRect = Rect.fromLTWH(
        rect.left + index * barWidth + 2,
        rect.bottom - height - 3,
        math.max(1.0, barWidth - 4),
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
        Paint()..color = histogramColor.withValues(alpha: 0.68),
      );
    }
    _drawCenteredText(
      canvas,
      model.labels[variableIndex],
      valueStyle.copyWith(color: valueStyle.color?.withValues(alpha: 0.82)),
      rect.deflate(4),
    );
  }

  void _drawScatter(
    Canvas canvas,
    _ScatterMatrixGeometry geometry,
    int row,
    int column,
  ) {
    for (var index = 0; index < model.points.length; index++) {
      final point = model.points[index];
      final offset = geometry.pointOffset(
        row: row,
        column: column,
        point: point,
      );
      final active =
          activeHit?.pointIndex == index &&
          activeHit?.xVariableIndex == column &&
          activeHit?.yVariableIndex == row;
      final color = _pointColor(point, index);
      final radius = pointRadius * (active ? 1.65 : 1) * progress;
      if (showActivePoint && active) {
        canvas.drawCircle(
          offset,
          math.max(pointRadius + 4, radius + 4),
          Paint()..color = activeColor.withValues(alpha: 0.18),
        );
      }
      canvas.drawCircle(
        offset,
        radius,
        Paint()..color = color.withValues(alpha: pointOpacity),
      );
      canvas.drawCircle(
        offset,
        radius,
        Paint()
          ..color = color.withValues(alpha: active ? 0.95 : 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 1.6 : 0.8,
      );
    }
  }

  void _drawVariableLabels(Canvas canvas, _ScatterMatrixGeometry geometry) {
    for (var index = 0; index < model.variableCount; index++) {
      final bottomRect = geometry.cell(model.variableCount - 1, index);
      _drawCenteredText(
        canvas,
        model.labels[index],
        labelStyle,
        Rect.fromLTWH(
          bottomRect.left,
          geometry.matrixRect.bottom + 8,
          bottomRect.width,
          padding.bottom - 10,
        ),
      );

      final leftRect = geometry.cell(index, 0);
      final painter = TextPainter(
        text: TextSpan(text: model.labels[index], style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: math.max(0.0, padding.left - 10));
      painter.paint(canvas, Offset(4, leftRect.center.dy - painter.height / 2));
    }
  }

  void _drawLegend(Canvas canvas, _ScatterMatrixGeometry geometry) {
    if (model.groups.isEmpty || model.groups.length <= 1) return;
    final startX = geometry.matrixRect.right - 8;
    var y = geometry.matrixRect.top + 6;
    for (var index = 0; index < model.groups.length; index++) {
      final group = model.groups[index];
      final color = palette[index % palette.length];
      final labelPainter = TextPainter(
        text: TextSpan(
          text: group,
          style: labelStyle.copyWith(color: axisColor),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: 84);
      final width = labelPainter.width + 22;
      final rect = Rect.fromLTWH(
        startX - width,
        y - 4,
        width,
        math.max(18, labelPainter.height + 6),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.78),
      );
      canvas.drawCircle(
        Offset(rect.left + 8, rect.center.dy),
        4,
        Paint()..color = color,
      );
      labelPainter.paint(canvas, Offset(rect.left + 16, rect.top + 3));
      y += rect.height + 4;
      if (y > geometry.matrixRect.bottom - 16) break;
    }
  }

  Color _pointColor(SimpleScatterPlotMatrixPoint point, int index) {
    if (point.color != null) return point.color!;
    if (point.group == null) return pointColor;
    final groupIndex = model.groupIndex(point.group, index);
    return palette[groupIndex % palette.length];
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    TextStyle style,
    Rect rect,
  ) {
    if (rect.width <= 0 || rect.height <= 0) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: rect.width);
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _SimpleScatterPlotMatrixPainter oldDelegate) {
    return oldDelegate.model != model ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.pointColor != pointColor ||
        oldDelegate.histogramColor != histogramColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showDiagonalHistograms != showDiagonalHistograms ||
        oldDelegate.showVariableLabels != showVariableLabels ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.histogramBinCount != histogramBinCount ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.pointOpacity != pointOpacity ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeHit != activeHit ||
        oldDelegate.progress != progress;
  }
}

class _ScatterMatrixModel {
  final List<String> labels;
  final List<SimpleScatterPlotMatrixPoint> points;
  final List<_VariableRange> ranges;
  final List<String> groups;

  const _ScatterMatrixModel({
    required this.labels,
    required this.points,
    required this.ranges,
    required this.groups,
  });

  bool get isEmpty => variableCount < 2 || points.isEmpty;
  int get variableCount => labels.length;

  int groupIndex(String? group, int fallbackIndex) {
    if (group == null) return fallbackIndex;
    final index = groups.indexOf(group);
    return index < 0 ? fallbackIndex : index;
  }

  factory _ScatterMatrixModel.resolve({
    required List<String> variableLabels,
    required List<SimpleScatterPlotMatrixPoint> points,
    required List<double> minValues,
    required List<double> maxValues,
  }) {
    final detectedCount = variableLabels.isNotEmpty
        ? variableLabels.length
        : points.isEmpty
        ? 0
        : points.map((point) => point.values.length).reduce(math.max);
    if (detectedCount < 2) {
      return const _ScatterMatrixModel(
        labels: [],
        points: [],
        ranges: [],
        groups: [],
      );
    }
    final labels = variableLabels.isNotEmpty
        ? variableLabels.take(detectedCount).toList()
        : List.generate(detectedCount, (index) => 'Var ${index + 1}');
    final visiblePoints = points
        .where(
          (point) =>
              point.values.length >= detectedCount &&
              point.values.take(detectedCount).every((value) => value.isFinite),
        )
        .map(
          (point) => SimpleScatterPlotMatrixPoint(
            label: point.label,
            values: point.values.take(detectedCount).toList(),
            group: point.group,
            color: point.color,
          ),
        )
        .toList();
    if (visiblePoints.isEmpty) {
      return const _ScatterMatrixModel(
        labels: [],
        points: [],
        ranges: [],
        groups: [],
      );
    }

    final ranges = List.generate(detectedCount, (index) {
      var lower = index < minValues.length && minValues[index].isFinite
          ? minValues[index]
          : double.infinity;
      var upper = index < maxValues.length && maxValues[index].isFinite
          ? maxValues[index]
          : double.negativeInfinity;
      for (final point in visiblePoints) {
        if (index >= minValues.length) {
          lower = math.min(lower, point.values[index]);
        }
        if (index >= maxValues.length) {
          upper = math.max(upper, point.values[index]);
        }
      }
      if (lower > upper) {
        final previousLower = lower;
        lower = upper;
        upper = previousLower;
      }
      if (lower == upper) {
        final pad = lower == 0 ? 1.0 : lower.abs() * 0.2;
        lower -= pad;
        upper += pad;
      }
      return _VariableRange(lower, upper);
    });

    final groups = <String>[];
    for (final point in visiblePoints) {
      final group = point.group;
      if (group == null || groups.contains(group)) continue;
      groups.add(group);
    }
    return _ScatterMatrixModel(
      labels: labels,
      points: visiblePoints,
      ranges: ranges,
      groups: groups,
    );
  }
}

class _ScatterMatrixGeometry {
  final Rect matrixRect;
  final double cellSize;
  final _ScatterMatrixModel model;

  const _ScatterMatrixGeometry({
    required this.matrixRect,
    required this.cellSize,
    required this.model,
  });

  Rect cell(int row, int column) {
    return Rect.fromLTWH(
      matrixRect.left + column * cellSize,
      matrixRect.top + row * cellSize,
      cellSize,
      cellSize,
    ).deflate(2);
  }

  Offset pointOffset({
    required int row,
    required int column,
    required SimpleScatterPlotMatrixPoint point,
  }) {
    final rect = cell(row, column).deflate(5);
    final xRange = model.ranges[column];
    final yRange = model.ranges[row];
    final x = rect.left + rect.width * xRange.normalize(point.values[column]);
    final y = rect.bottom - rect.height * yRange.normalize(point.values[row]);
    return Offset(x, y);
  }

  factory _ScatterMatrixGeometry.resolve({
    required Size size,
    required EdgeInsets padding,
    required _ScatterMatrixModel model,
  }) {
    final content = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    final cellSize =
        math.min(content.width, content.height) /
        math.max(1, model.variableCount);
    final matrixWidth = cellSize * model.variableCount;
    final matrixHeight = cellSize * model.variableCount;
    final rect = Rect.fromLTWH(
      content.left + (content.width - matrixWidth) / 2,
      content.top + (content.height - matrixHeight) / 2,
      matrixWidth,
      matrixHeight,
    );
    return _ScatterMatrixGeometry(
      matrixRect: rect,
      cellSize: cellSize,
      model: model,
    );
  }
}

class _VariableRange {
  final double min;
  final double max;

  const _VariableRange(this.min, this.max);

  double get span => math.max(0.000001, max - min);

  double normalize(double value) {
    return ((value - min) / span).clamp(0.0, 1.0).toDouble();
  }
}

class _ScatterMatrixHit {
  final int pointIndex;
  final int xVariableIndex;
  final int yVariableIndex;
  final Offset position;

  const _ScatterMatrixHit({
    required this.pointIndex,
    required this.xVariableIndex,
    required this.yVariableIndex,
    required this.position,
  });

  @override
  bool operator ==(Object other) {
    return other is _ScatterMatrixHit &&
        other.pointIndex == pointIndex &&
        other.xVariableIndex == xVariableIndex &&
        other.yVariableIndex == yVariableIndex &&
        other.position == position;
  }

  @override
  int get hashCode =>
      Object.hash(pointIndex, xVariableIndex, yVariableIndex, position);
}

class _SimpleScatterMatrixVisuals {
  final List<Color> palette;
  final Color pointColor;
  final Color histogramColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;

  const _SimpleScatterMatrixVisuals({
    required this.palette,
    required this.pointColor,
    required this.histogramColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
  });

  factory _SimpleScatterMatrixVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleScatterMatrixVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFFF97316),
          ],
          pointColor: colorScheme.primary,
          histogramColor: colorScheme.secondary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.42),
          axisColor: colorScheme.outline,
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleScatterMatrixVisuals(
          palette: [
            const Color(0xFF2563EB),
            const Color(0xFF475569),
            const Color(0xFF0F766E),
            const Color(0xFF7C3AED),
            const Color(0xFFB45309),
          ],
          pointColor: const Color(0xFF2563EB),
          histogramColor: const Color(0xFF64748B),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.48),
          axisColor: colorScheme.outline,
          activeColor: const Color(0xFF2563EB),
        );
      case SimpleBarChartStyle.education:
        return _SimpleScatterMatrixVisuals(
          palette: [
            const Color(0xFF10B981),
            const Color(0xFF3B82F6),
            const Color(0xFFF59E0B),
            const Color(0xFF8B5CF6),
            const Color(0xFFEF4444),
          ],
          pointColor: const Color(0xFF10B981),
          histogramColor: const Color(0xFF3B82F6),
          gridColor: colorScheme.secondary.withValues(alpha: 0.16),
          axisColor: colorScheme.secondary.withValues(alpha: 0.72),
          activeColor: const Color(0xFFF59E0B),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleScatterMatrixVisuals(
          palette: [
            colorScheme.tertiary,
            const Color(0xFF06B6D4),
            const Color(0xFF22C55E),
            const Color(0xFFEC4899),
            const Color(0xFFF97316),
          ],
          pointColor: colorScheme.tertiary,
          histogramColor: const Color(0xFF06B6D4),
          gridColor: colorScheme.tertiary.withValues(alpha: 0.14),
          axisColor: colorScheme.outline,
          activeColor: const Color(0xFFEC4899),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleScatterMatrixVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFFF59E0B),
          ],
          pointColor: colorScheme.primary,
          histogramColor: colorScheme.secondary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.38),
          axisColor: colorScheme.outline,
          activeColor: colorScheme.secondary,
        );
    }
  }
}

class _DefaultScatterMatrixTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final List<_ScatterMatrixTooltipRow> rows;

  const _DefaultScatterMatrixTooltip({
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

class _ScatterMatrixTooltipRow {
  final String label;
  final String value;

  const _ScatterMatrixTooltipRow({required this.label, required this.value});
}
