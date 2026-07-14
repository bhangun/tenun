import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleHeatmapValueFormatter = String Function(double value);
typedef SimpleHeatmapCellTapCallback =
    void Function(SimpleHeatmapCell cell, int rowIndex, int columnIndex);
typedef SimpleHeatmapTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleHeatmapCell cell,
      int rowIndex,
      int columnIndex,
      String formattedValue,
    );

class SimpleHeatmapCell {
  final String xLabel;
  final String yLabel;
  final double value;
  final Color? color;
  final String? label;

  const SimpleHeatmapCell({
    required this.xLabel,
    required this.yLabel,
    required this.value,
    this.color,
    this.label,
  });
}

/// A compact matrix chart for intensity, workload, activity, mastery, and
/// risk-style grids.
class SimpleHeatmapChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(72, 24, 54, 38);

  final List<String> xLabels;
  final List<String> yLabels;
  final List<SimpleHeatmapCell> cells;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? lowColor;
  final Color? highColor;
  final Color? emptyColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showXLabels;
  final bool showYLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final double cellGap;
  final double cellRadius;
  final SimpleHeatmapValueFormatter? valueFormatter;
  final SimpleHeatmapCellTapCallback? onCellTap;
  final SimpleHeatmapTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleHeatmapChart({
    super.key,
    this.xLabels = const [],
    this.yLabels = const [],
    required this.cells,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 250,
    this.padding = _defaultPadding,
    this.lowColor,
    this.highColor,
    this.emptyColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showXLabels = true,
    this.showYLabels = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveCell = true,
    this.cellGap = 3,
    this.cellRadius = 5,
    this.valueFormatter,
    this.onCellTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 650),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(cellGap >= 0),
       assert(cellRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleHeatmapVisuals.resolve(style, colorScheme);
    final visibleCells = cells.where((item) => item.value.isFinite).toList();
    final resolvedGrid = _HeatmapGrid.from(
      xLabels: xLabels,
      yLabels: yLabels,
      cells: visibleCells,
      minValue: minValue,
      maxValue: maxValue,
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

        if (resolvedGrid.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Heatmap chart, no data.',
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
          semanticLabel: _defaultSemanticLabel(resolvedGrid, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleHeatmapChartView(
            width: width,
            height: chartHeight,
            grid: resolvedGrid,
            padding: padding,
            lowColor: lowColor ?? visuals.lowColor,
            highColor: highColor ?? visuals.highColor,
            emptyColor: emptyColor ?? visuals.emptyColor,
            gridColor: gridColor ?? visuals.gridColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showXLabels: showXLabels,
            showYLabels: showYLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveCell: showActiveCell,
            cellGap: cellGap,
            cellRadius: cellRadius,
            valueFormatter: formatter,
            onCellTap: onCellTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(
    _HeatmapGrid grid,
    SimpleHeatmapValueFormatter formatter,
  ) {
    final summaries = grid.cells
        .expand((row) => row)
        .whereType<SimpleHeatmapCell>()
        .take(6)
        .map((item) => '${item.yLabel} ${item.xLabel} ${formatter(item.value)}')
        .join(', ');
    final totalCells = grid.cells
        .expand((row) => row)
        .whereType<SimpleHeatmapCell>()
        .length;
    final remaining = totalCells - math.min(totalCells, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    return 'Heatmap chart, ${grid.yLabels.length} rows and '
        '${grid.xLabels.length} columns. $summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleHeatmapChartView extends StatefulWidget {
  final double width;
  final double height;
  final _HeatmapGrid grid;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showXLabels;
  final bool showYLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final double cellGap;
  final double cellRadius;
  final SimpleHeatmapValueFormatter valueFormatter;
  final SimpleHeatmapCellTapCallback? onCellTap;
  final SimpleHeatmapTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleHeatmapChartView({
    required this.width,
    required this.height,
    required this.grid,
    required this.padding,
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showXLabels,
    required this.showYLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveCell,
    required this.cellGap,
    required this.cellRadius,
    required this.valueFormatter,
    required this.onCellTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleHeatmapChartView> createState() =>
      _SimpleHeatmapChartViewState();
}

class _SimpleHeatmapChartViewState extends State<_SimpleHeatmapChartView> {
  int? _activeRow;
  int? _activeColumn;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveCell || widget.onCellTap != null;

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
                painter: _SimpleHeatmapPainter(
                  grid: widget.grid,
                  padding: widget.padding,
                  lowColor: widget.lowColor,
                  highColor: widget.highColor,
                  emptyColor: widget.emptyColor,
                  gridColor: widget.gridColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showXLabels: widget.showXLabels,
                  showYLabels: widget.showYLabels,
                  showValues: widget.showValues,
                  showLegend: widget.showLegend,
                  showActiveCell: widget.showActiveCell,
                  cellGap: widget.cellGap,
                  cellRadius: widget.cellRadius,
                  valueFormatter: widget.valueFormatter,
                  activeRow: _activeRow,
                  activeColumn: _activeColumn,
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
                        final cell = widget.grid.cellAt(hit.row, hit.column);
                        if (cell != null) {
                          widget.onCellTap?.call(cell, hit.row, hit.column);
                        }
                      }
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip &&
                  _activeRow != null &&
                  _activeColumn != null)
                _buildTooltip(context, size, _activeRow!, _activeColumn!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_HeatmapHit? hit) {
    if (_activeRow == hit?.row && _activeColumn == hit?.column) return;
    setState(() {
      _activeRow = hit?.row;
      _activeColumn = hit?.column;
    });
  }

  _HeatmapHit? _hitTest(Offset position, Size size) {
    final plot = _plot(size);
    if (!plot.contains(position)) return null;
    final cellWidth = plot.width / widget.grid.xLabels.length;
    final cellHeight = plot.height / widget.grid.yLabels.length;
    final column = ((position.dx - plot.left) / cellWidth).floor();
    final row = ((position.dy - plot.top) / cellHeight).floor();
    if (row < 0 ||
        column < 0 ||
        row >= widget.grid.yLabels.length ||
        column >= widget.grid.xLabels.length) {
      return null;
    }
    if (widget.grid.cellAt(row, column) == null) return null;
    return _HeatmapHit(row, column);
  }

  Widget _buildTooltip(BuildContext context, Size size, int row, int column) {
    final cell = widget.grid.cellAt(row, column);
    if (cell == null) return const SizedBox.shrink();
    final formattedValue = widget.valueFormatter(cell.value);
    final anchor = _anchorFor(size, row, column);
    const tooltipWidth = 176.0;
    const tooltipHeight = 66.0;
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
            cell,
            row,
            column,
            formattedValue,
          ) ??
          _DefaultHeatmapTooltip(
            color: _cellColor(cell),
            title: '${cell.yLabel} / ${cell.xLabel}',
            label: cell.label,
            value: formattedValue,
          ),
    );
  }

  Rect _plot(Size size) {
    return Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }

  Offset _anchorFor(Size size, int row, int column) {
    final plot = _plot(size);
    final cellWidth = plot.width / widget.grid.xLabels.length;
    final cellHeight = plot.height / widget.grid.yLabels.length;
    return Offset(
      plot.left + cellWidth * column + cellWidth / 2,
      plot.top + cellHeight * row + cellHeight / 2,
    );
  }

  Color _cellColor(SimpleHeatmapCell cell) {
    if (cell.color != null) return cell.color!;
    final normalized = widget.grid.normalize(cell.value);
    return Color.lerp(widget.lowColor, widget.highColor, normalized) ??
        widget.highColor;
  }
}

class _SimpleHeatmapPainter extends CustomPainter {
  final _HeatmapGrid grid;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showXLabels;
  final bool showYLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActiveCell;
  final double cellGap;
  final double cellRadius;
  final SimpleHeatmapValueFormatter valueFormatter;
  final int? activeRow;
  final int? activeColumn;
  final double progress;

  const _SimpleHeatmapPainter({
    required this.grid,
    required this.padding,
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showXLabels,
    required this.showYLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActiveCell,
    required this.cellGap,
    required this.cellRadius,
    required this.valueFormatter,
    required this.activeRow,
    required this.activeColumn,
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
    if (plot.width <= 0 || plot.height <= 0 || grid.isEmpty) return;

    _drawCells(canvas, plot);
    if (showGrid) {
      _drawGrid(canvas, plot);
    }
    if (showYLabels) {
      _drawYLabels(canvas, plot);
    }
    if (showXLabels) {
      _drawXLabels(canvas, plot);
    }
    if (showLegend) {
      _drawLegend(canvas, plot, size);
    }
  }

  void _drawCells(Canvas canvas, Rect plot) {
    final cellWidth = plot.width / grid.xLabels.length;
    final cellHeight = plot.height / grid.yLabels.length;
    final gap = math.min(cellGap, math.min(cellWidth, cellHeight) / 3);

    for (var row = 0; row < grid.yLabels.length; row++) {
      for (var column = 0; column < grid.xLabels.length; column++) {
        final cell = grid.cellAt(row, column);
        final color = cell == null ? emptyColor : _cellColor(cell);
        final rect = Rect.fromLTWH(
          plot.left + column * cellWidth + gap / 2,
          plot.top + row * cellHeight + gap / 2,
          math.max(0.0, cellWidth - gap),
          math.max(0.0, cellHeight - gap),
        );
        final scale = 0.72 + progress * 0.28;
        final animatedRect = Rect.fromCenter(
          center: rect.center,
          width: rect.width * scale,
          height: rect.height * scale,
        );
        final radius = Radius.circular(
          math.min(cellRadius, math.min(rect.width, rect.height) / 2),
        );
        final active = row == activeRow && column == activeColumn;

        if (showActiveCell && active && cell != null) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.inflate(3), radius),
            Paint()..color = (activeColor ?? color).withValues(alpha: 0.16),
          );
        }

        canvas.drawRRect(
          RRect.fromRectAndRadius(animatedRect, radius),
          Paint()..color = color.withValues(alpha: cell == null ? 0.35 : 0.92),
        );

        if (showValues && cell != null && cellWidth >= 28 && cellHeight >= 22) {
          _drawCellValue(canvas, cell, animatedRect, color);
        }
      }
    }
  }

  void _drawCellValue(
    Canvas canvas,
    SimpleHeatmapCell cell,
    Rect rect,
    Color color,
  ) {
    final foreground = color.computeLuminance() < 0.42
        ? Colors.white
        : Colors.black.withValues(alpha: 0.78);
    final painter = _textPainter(
      valueFormatter(cell.value),
      valueStyle.copyWith(
        color: foreground,
        fontSize: (valueStyle.fontSize ?? 11) * 0.92,
      ),
      maxWidth: rect.width - 4,
      textAlign: TextAlign.center,
    )..layout(maxWidth: math.max(4.0, rect.width - 4));
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  void _drawGrid(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final cellWidth = plot.width / grid.xLabels.length;
    final cellHeight = plot.height / grid.yLabels.length;
    for (var column = 0; column <= grid.xLabels.length; column++) {
      final x = plot.left + column * cellWidth;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), paint);
    }
    for (var row = 0; row <= grid.yLabels.length; row++) {
      final y = plot.top + row * cellHeight;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
    }
  }

  void _drawYLabels(Canvas canvas, Rect plot) {
    final cellHeight = plot.height / grid.yLabels.length;
    final maxWidth = math.max(24.0, padding.left - 12);
    for (var row = 0; row < grid.yLabels.length; row++) {
      final y = plot.top + row * cellHeight + cellHeight / 2;
      final painter = _textPainter(
        grid.yLabels[row],
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

  void _drawXLabels(Canvas canvas, Rect plot) {
    final cellWidth = plot.width / grid.xLabels.length;
    final maxLabelCount = math.max(1, plot.width / 40).floor();
    final labelEvery = math.max(
      1,
      (grid.xLabels.length / maxLabelCount).ceil(),
    );
    for (var column = 0; column < grid.xLabels.length; column++) {
      if (column % labelEvery != 0) continue;
      final x = plot.left + column * cellWidth + cellWidth / 2;
      final maxWidth = math.max(18.0, cellWidth * 0.94);
      final painter = _textPainter(
        grid.xLabels[column],
        labelStyle,
        maxWidth: maxWidth,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x - painter.width / 2, plot.bottom + 8));
    }
  }

  void _drawLegend(Canvas canvas, Rect plot, Size size) {
    final legendLeft = plot.right + 14;
    final legendWidth = math.min(
      14.0,
      math.max(0.0, size.width - legendLeft - 8),
    );
    if (legendWidth <= 2) return;
    final rect = Rect.fromLTWH(legendLeft, plot.top, legendWidth, plot.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [lowColor, highColor],
        ).createShader(rect),
    );
    final minPainter = _textPainter(
      valueFormatter(grid.min),
      labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 12) * 0.86),
      maxWidth: 42,
    )..layout(maxWidth: 42);
    minPainter.paint(
      canvas,
      Offset(legendLeft - 2, plot.bottom - minPainter.height),
    );
    final maxPainter = _textPainter(
      valueFormatter(grid.max),
      labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 12) * 0.86),
      maxWidth: 42,
    )..layout(maxWidth: 42);
    maxPainter.paint(canvas, Offset(legendLeft - 2, plot.top));
  }

  Color _cellColor(SimpleHeatmapCell cell) {
    if (cell.color != null) return cell.color!;
    return Color.lerp(lowColor, highColor, grid.normalize(cell.value)) ??
        highColor;
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
  bool shouldRepaint(covariant _SimpleHeatmapPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.padding != padding ||
        oldDelegate.lowColor != lowColor ||
        oldDelegate.highColor != highColor ||
        oldDelegate.emptyColor != emptyColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showXLabels != showXLabels ||
        oldDelegate.showYLabels != showYLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveCell != showActiveCell ||
        oldDelegate.cellGap != cellGap ||
        oldDelegate.cellRadius != cellRadius ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeRow != activeRow ||
        oldDelegate.activeColumn != activeColumn ||
        oldDelegate.progress != progress;
  }
}

class _HeatmapGrid {
  final List<String> xLabels;
  final List<String> yLabels;
  final List<List<SimpleHeatmapCell?>> cells;
  final double min;
  final double max;

  const _HeatmapGrid({
    required this.xLabels,
    required this.yLabels,
    required this.cells,
    required this.min,
    required this.max,
  });

  bool get isEmpty => xLabels.isEmpty || yLabels.isEmpty || cells.isEmpty;

  SimpleHeatmapCell? cellAt(int row, int column) {
    if (row < 0 ||
        column < 0 ||
        row >= cells.length ||
        column >= cells[row].length) {
      return null;
    }
    return cells[row][column];
  }

  double normalize(double value) {
    return ((value - min) / math.max(0.000001, max - min))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  factory _HeatmapGrid.from({
    required List<String> xLabels,
    required List<String> yLabels,
    required List<SimpleHeatmapCell> cells,
    required double? minValue,
    required double? maxValue,
  }) {
    final resolvedX = xLabels.isNotEmpty
        ? xLabels
        : _uniqueLabels(cells.map((item) => item.xLabel));
    final resolvedY = yLabels.isNotEmpty
        ? yLabels
        : _uniqueLabels(cells.map((item) => item.yLabel));
    if (resolvedX.isEmpty || resolvedY.isEmpty) {
      return const _HeatmapGrid(
        xLabels: [],
        yLabels: [],
        cells: [],
        min: 0,
        max: 1,
      );
    }

    final columns = {
      for (var index = 0; index < resolvedX.length; index++)
        resolvedX[index]: index,
    };
    final rows = {
      for (var index = 0; index < resolvedY.length; index++)
        resolvedY[index]: index,
    };
    final matrix = List.generate(
      resolvedY.length,
      (_) => List<SimpleHeatmapCell?>.filled(resolvedX.length, null),
    );
    var lower = double.infinity;
    var upper = double.negativeInfinity;
    for (final cell in cells) {
      final row = rows[cell.yLabel];
      final column = columns[cell.xLabel];
      if (row == null || column == null || !cell.value.isFinite) continue;
      matrix[row][column] = cell;
      lower = math.min(lower, cell.value);
      upper = math.max(upper, cell.value);
    }

    if (!lower.isFinite || !upper.isFinite) {
      return const _HeatmapGrid(
        xLabels: [],
        yLabels: [],
        cells: [],
        min: 0,
        max: 1,
      );
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
    }

    return _HeatmapGrid(
      xLabels: resolvedX,
      yLabels: resolvedY,
      cells: matrix,
      min: lower,
      max: upper,
    );
  }

  static List<String> _uniqueLabels(Iterable<String> labels) {
    final result = <String>[];
    for (final label in labels) {
      if (label.isEmpty || result.contains(label)) continue;
      result.add(label);
    }
    return result;
  }
}

class _HeatmapHit {
  final int row;
  final int column;

  const _HeatmapHit(this.row, this.column);
}

class _SimpleHeatmapVisuals {
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;

  const _SimpleHeatmapVisuals({
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.gridColor,
  });

  factory _SimpleHeatmapVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleHeatmapVisuals(
          lowColor: colorScheme.primary.withValues(alpha: 0.12),
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleHeatmapVisuals(
          lowColor: colorScheme.surfaceContainerHighest,
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.65,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
        );
      case SimpleBarChartStyle.education:
        return _SimpleHeatmapVisuals(
          lowColor: const Color(0xFFFEF3C7),
          highColor: colorScheme.secondary,
          emptyColor: colorScheme.surfaceContainerHighest,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleHeatmapVisuals(
          lowColor: const Color(0xFFE0F2FE),
          highColor: colorScheme.tertiary,
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.7,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleHeatmapVisuals(
          lowColor: colorScheme.secondary.withValues(alpha: 0.12),
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
        );
    }
  }
}

class _DefaultHeatmapTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String? label;
  final String value;

  const _DefaultHeatmapTooltip({
    required this.color,
    required this.title,
    required this.label,
    required this.value,
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
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onInverseSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label == null ? value : '$label / $value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
