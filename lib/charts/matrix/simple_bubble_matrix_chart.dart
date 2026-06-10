import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleBubbleMatrixValueFormatter = String Function(double value);

typedef SimpleBubbleMatrixCellTapCallback =
    void Function(SimpleBubbleMatrixCell cell, int rowIndex, int columnIndex);

typedef SimpleBubbleMatrixTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleBubbleMatrixCell cell,
      int rowIndex,
      int columnIndex,
      String formattedValue,
    );

class SimpleBubbleMatrixCell {
  final String xLabel;
  final String yLabel;
  final double value;
  final Color? color;
  final String? label;

  const SimpleBubbleMatrixCell({
    required this.xLabel,
    required this.yLabel,
    required this.value,
    this.color,
    this.label,
  });
}

/// A categorical matrix chart that encodes magnitude with circle size.
class SimpleBubbleMatrixChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(76, 24, 54, 40);

  final List<String> xLabels;
  final List<String> yLabels;
  final List<SimpleBubbleMatrixCell> cells;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? bubbleColor;
  final Color? lowColor;
  final Color? highColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool useColorScale;
  final bool showGrid;
  final bool showXLabels;
  final bool showYLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveBubble;
  final double bubbleOpacity;
  final double minBubbleRadius;
  final double maxBubbleRadiusFactor;
  final SimpleBubbleMatrixValueFormatter? valueFormatter;
  final SimpleBubbleMatrixCellTapCallback? onCellTap;
  final SimpleBubbleMatrixTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleBubbleMatrixChart({
    super.key,
    this.xLabels = const [],
    this.yLabels = const [],
    required this.cells,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 250,
    this.padding = _defaultPadding,
    this.bubbleColor,
    this.lowColor,
    this.highColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.useColorScale = true,
    this.showGrid = true,
    this.showXLabels = true,
    this.showYLabels = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveBubble = true,
    this.bubbleOpacity = 0.86,
    this.minBubbleRadius = 3,
    this.maxBubbleRadiusFactor = 0.42,
    this.valueFormatter,
    this.onCellTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 650),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(bubbleOpacity >= 0 && bubbleOpacity <= 1),
       assert(minBubbleRadius >= 0),
       assert(maxBubbleRadiusFactor > 0 && maxBubbleRadiusFactor <= 0.5);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleBubbleMatrixVisuals.resolve(style, colorScheme);
    final visibleCells = cells
        .where(
          (item) =>
              item.xLabel.trim().isNotEmpty &&
              item.yLabel.trim().isNotEmpty &&
              item.value.isFinite,
        )
        .toList();
    final grid = _BubbleMatrixGrid.from(
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

        if (grid.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Bubble matrix chart, no data.',
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
          semanticLabel: _defaultSemanticLabel(grid, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleBubbleMatrixChartView(
            width: width,
            height: chartHeight,
            grid: grid,
            padding: padding,
            bubbleColor: bubbleColor ?? visuals.bubbleColor,
            lowColor: lowColor ?? visuals.lowColor,
            highColor: highColor ?? visuals.highColor,
            gridColor: gridColor ?? visuals.gridColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            useColorScale: useColorScale,
            showGrid: showGrid,
            showXLabels: showXLabels,
            showYLabels: showYLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveBubble: showActiveBubble,
            bubbleOpacity: bubbleOpacity,
            minBubbleRadius: minBubbleRadius,
            maxBubbleRadiusFactor: maxBubbleRadiusFactor,
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
    _BubbleMatrixGrid grid,
    SimpleBubbleMatrixValueFormatter formatter,
  ) {
    final summaries = grid.cells
        .expand((row) => row)
        .whereType<SimpleBubbleMatrixCell>()
        .take(6)
        .map((item) => '${item.yLabel} ${item.xLabel} ${formatter(item.value)}')
        .join(', ');
    final totalCells = grid.cells
        .expand((row) => row)
        .whereType<SimpleBubbleMatrixCell>()
        .length;
    final remaining = totalCells - math.min(totalCells, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    return 'Bubble matrix chart, ${grid.yLabels.length} rows and '
        '${grid.xLabels.length} columns. $summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _SimpleBubbleMatrixChartView extends StatefulWidget {
  final double width;
  final double height;
  final _BubbleMatrixGrid grid;
  final EdgeInsets padding;
  final Color bubbleColor;
  final Color lowColor;
  final Color highColor;
  final Color gridColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool useColorScale;
  final bool showGrid;
  final bool showXLabels;
  final bool showYLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveBubble;
  final double bubbleOpacity;
  final double minBubbleRadius;
  final double maxBubbleRadiusFactor;
  final SimpleBubbleMatrixValueFormatter valueFormatter;
  final SimpleBubbleMatrixCellTapCallback? onCellTap;
  final SimpleBubbleMatrixTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleBubbleMatrixChartView({
    required this.width,
    required this.height,
    required this.grid,
    required this.padding,
    required this.bubbleColor,
    required this.lowColor,
    required this.highColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.useColorScale,
    required this.showGrid,
    required this.showXLabels,
    required this.showYLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveBubble,
    required this.bubbleOpacity,
    required this.minBubbleRadius,
    required this.maxBubbleRadiusFactor,
    required this.valueFormatter,
    required this.onCellTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleBubbleMatrixChartView> createState() =>
      _SimpleBubbleMatrixChartViewState();
}

class _SimpleBubbleMatrixChartViewState
    extends State<_SimpleBubbleMatrixChartView> {
  int? _activeRow;
  int? _activeColumn;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveBubble ||
        widget.onCellTap != null;

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
                painter: _SimpleBubbleMatrixPainter(
                  grid: widget.grid,
                  padding: widget.padding,
                  bubbleColor: widget.bubbleColor,
                  lowColor: widget.lowColor,
                  highColor: widget.highColor,
                  gridColor: widget.gridColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  useColorScale: widget.useColorScale,
                  showGrid: widget.showGrid,
                  showXLabels: widget.showXLabels,
                  showYLabels: widget.showYLabels,
                  showValues: widget.showValues,
                  showLegend: widget.showLegend,
                  showActiveBubble: widget.showActiveBubble,
                  bubbleOpacity: widget.bubbleOpacity,
                  minBubbleRadius: widget.minBubbleRadius,
                  maxBubbleRadiusFactor: widget.maxBubbleRadiusFactor,
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
                      if (hit == null) return;
                      final cell = widget.grid.cellAt(hit.row, hit.column);
                      if (cell != null) {
                        widget.onCellTap?.call(cell, hit.row, hit.column);
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

  void _setActive(_BubbleMatrixHit? hit) {
    if (_activeRow == hit?.row && _activeColumn == hit?.column) return;
    setState(() {
      _activeRow = hit?.row;
      _activeColumn = hit?.column;
    });
  }

  _BubbleMatrixHit? _hitTest(Offset position, Size size) {
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
    return _BubbleMatrixHit(row, column);
  }

  Widget _buildTooltip(BuildContext context, Size size, int row, int column) {
    final cell = widget.grid.cellAt(row, column);
    if (cell == null) return const SizedBox.shrink();
    final formattedValue = widget.valueFormatter(cell.value);
    final anchor = _anchorFor(size, row, column);
    const tooltipWidth = 178.0;
    const tooltipHeight = 70.0;
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
          _DefaultBubbleMatrixTooltip(
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

  Color _cellColor(SimpleBubbleMatrixCell cell) {
    if (cell.color != null) return cell.color!;
    if (!widget.useColorScale) return widget.bubbleColor;
    return Color.lerp(
          widget.lowColor,
          widget.highColor,
          widget.grid.normalize(cell.value),
        ) ??
        widget.highColor;
  }
}

class _SimpleBubbleMatrixPainter extends CustomPainter {
  final _BubbleMatrixGrid grid;
  final EdgeInsets padding;
  final Color bubbleColor;
  final Color lowColor;
  final Color highColor;
  final Color gridColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool useColorScale;
  final bool showGrid;
  final bool showXLabels;
  final bool showYLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActiveBubble;
  final double bubbleOpacity;
  final double minBubbleRadius;
  final double maxBubbleRadiusFactor;
  final SimpleBubbleMatrixValueFormatter valueFormatter;
  final int? activeRow;
  final int? activeColumn;
  final double progress;

  const _SimpleBubbleMatrixPainter({
    required this.grid,
    required this.padding,
    required this.bubbleColor,
    required this.lowColor,
    required this.highColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.useColorScale,
    required this.showGrid,
    required this.showXLabels,
    required this.showYLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActiveBubble,
    required this.bubbleOpacity,
    required this.minBubbleRadius,
    required this.maxBubbleRadiusFactor,
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

    if (showGrid) _drawGrid(canvas, plot);
    _drawBubbles(canvas, plot);
    if (showYLabels) _drawYLabels(canvas, plot);
    if (showXLabels) _drawXLabels(canvas, plot);
    if (showLegend) _drawLegend(canvas, plot, size);
  }

  void _drawBubbles(Canvas canvas, Rect plot) {
    final cellWidth = plot.width / grid.xLabels.length;
    final cellHeight = plot.height / grid.yLabels.length;
    final maxRadius = math.max(
      minBubbleRadius,
      math.min(cellWidth, cellHeight) * maxBubbleRadiusFactor,
    );

    for (var row = 0; row < grid.yLabels.length; row++) {
      for (var column = 0; column < grid.xLabels.length; column++) {
        final cell = grid.cellAt(row, column);
        if (cell == null) continue;
        final center = Offset(
          plot.left + column * cellWidth + cellWidth / 2,
          plot.top + row * cellHeight + cellHeight / 2,
        );
        final normalized = grid.normalize(cell.value);
        final radius =
            (minBubbleRadius +
                    (maxRadius - minBubbleRadius) * math.sqrt(normalized))
                .clamp(0.0, maxRadius)
                .toDouble() *
            progress;
        final color = _cellColor(cell);
        final active = row == activeRow && column == activeColumn;

        if (showActiveBubble && active) {
          canvas.drawCircle(
            center,
            radius + 5,
            Paint()..color = (activeColor ?? color).withValues(alpha: 0.16),
          );
          canvas.drawCircle(
            center,
            radius + 2,
            Paint()
              ..color = activeColor ?? color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }

        canvas.drawCircle(
          center,
          radius,
          Paint()..color = color.withValues(alpha: bubbleOpacity),
        );

        if (showValues && radius >= 12) {
          _paintText(
            canvas,
            valueFormatter(cell.value),
            valueStyle.copyWith(
              color: _foregroundFor(color),
              fontSize: (valueStyle.fontSize ?? 11) * 0.9,
            ),
            center,
            TextAlign.center,
            math.max(8, radius * 1.72),
            centeredY: true,
          );
        }
      }
    }
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
      _paintText(
        canvas,
        grid.yLabels[row],
        labelStyle,
        Offset(plot.left - 8, plot.top + row * cellHeight + cellHeight / 2),
        TextAlign.right,
        maxWidth,
        centeredY: true,
      );
    }
  }

  void _drawXLabels(Canvas canvas, Rect plot) {
    final cellWidth = plot.width / grid.xLabels.length;
    final maxLabelCount = math.max(1, plot.width / 42).floor();
    final labelEvery = math.max(
      1,
      (grid.xLabels.length / maxLabelCount).ceil(),
    );
    for (var column = 0; column < grid.xLabels.length; column++) {
      if (column % labelEvery != 0) continue;
      _paintText(
        canvas,
        grid.xLabels[column],
        labelStyle,
        Offset(plot.left + column * cellWidth + cellWidth / 2, plot.bottom + 8),
        TextAlign.center,
        math.max(18, cellWidth * 0.94),
      );
    }
  }

  void _drawLegend(Canvas canvas, Rect plot, Size size) {
    final legendLeft = plot.right + 12;
    final availableWidth = size.width - legendLeft - 8;
    if (availableWidth < 18) return;
    final maxRadius = math.min(8.0, availableWidth / 2);
    final values = [grid.min, (grid.min + grid.max) / 2, grid.max];
    final yPositions = [
      plot.bottom - maxRadius,
      plot.center.dy,
      plot.top + maxRadius,
    ];
    for (var index = 0; index < values.length; index++) {
      final normalized = grid.normalize(values[index]);
      final radius = math.max(
        2.5,
        maxRadius * math.sqrt(math.max(0.0, normalized)),
      );
      final color = useColorScale
          ? (Color.lerp(lowColor, highColor, normalized) ?? highColor)
          : bubbleColor;
      final center = Offset(legendLeft + maxRadius, yPositions[index]);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: bubbleOpacity),
      );
      _paintText(
        canvas,
        valueFormatter(values[index]),
        labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 12) * 0.84),
        Offset(legendLeft + maxRadius * 2 + 4, center.dy),
        TextAlign.left,
        math.max(20, availableWidth - maxRadius * 2 - 4),
        centeredY: true,
      );
    }
  }

  Color _cellColor(SimpleBubbleMatrixCell cell) {
    if (cell.color != null) return cell.color!;
    if (!useColorScale) return bubbleColor;
    return Color.lerp(lowColor, highColor, grid.normalize(cell.value)) ??
        highColor;
  }

  Color _foregroundFor(Color color) {
    return color.computeLuminance() < 0.42
        ? Colors.white
        : Colors.black.withValues(alpha: 0.78);
  }

  @override
  bool shouldRepaint(covariant _SimpleBubbleMatrixPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.padding != padding ||
        oldDelegate.bubbleColor != bubbleColor ||
        oldDelegate.lowColor != lowColor ||
        oldDelegate.highColor != highColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.useColorScale != useColorScale ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showXLabels != showXLabels ||
        oldDelegate.showYLabels != showYLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveBubble != showActiveBubble ||
        oldDelegate.bubbleOpacity != bubbleOpacity ||
        oldDelegate.minBubbleRadius != minBubbleRadius ||
        oldDelegate.maxBubbleRadiusFactor != maxBubbleRadiusFactor ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeRow != activeRow ||
        oldDelegate.activeColumn != activeColumn ||
        oldDelegate.progress != progress;
  }
}

class _BubbleMatrixGrid {
  final List<String> xLabels;
  final List<String> yLabels;
  final List<List<SimpleBubbleMatrixCell?>> cells;
  final double min;
  final double max;

  const _BubbleMatrixGrid({
    required this.xLabels,
    required this.yLabels,
    required this.cells,
    required this.min,
    required this.max,
  });

  bool get isEmpty => xLabels.isEmpty || yLabels.isEmpty || cells.isEmpty;

  SimpleBubbleMatrixCell? cellAt(int row, int column) {
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

  factory _BubbleMatrixGrid.from({
    required List<String> xLabels,
    required List<String> yLabels,
    required List<SimpleBubbleMatrixCell> cells,
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
      return const _BubbleMatrixGrid(
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
      (_) => List<SimpleBubbleMatrixCell?>.filled(resolvedX.length, null),
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
      return const _BubbleMatrixGrid(
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

    return _BubbleMatrixGrid(
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
      if (label.trim().isEmpty || result.contains(label)) continue;
      result.add(label);
    }
    return result;
  }
}

class _BubbleMatrixHit {
  final int row;
  final int column;

  const _BubbleMatrixHit(this.row, this.column);
}

class _SimpleBubbleMatrixVisuals {
  final Color bubbleColor;
  final Color lowColor;
  final Color highColor;
  final Color gridColor;

  const _SimpleBubbleMatrixVisuals({
    required this.bubbleColor,
    required this.lowColor,
    required this.highColor,
    required this.gridColor,
  });

  factory _SimpleBubbleMatrixVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleBubbleMatrixVisuals(
          bubbleColor: colorScheme.primary,
          lowColor: const Color(0xFFBFDBFE),
          highColor: const Color(0xFF2563EB),
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleBubbleMatrixVisuals(
          bubbleColor: const Color(0xFF0F766E),
          lowColor: const Color(0xFFCBD5E1),
          highColor: const Color(0xFF0F766E),
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
        );
      case SimpleBarChartStyle.education:
        return _SimpleBubbleMatrixVisuals(
          bubbleColor: colorScheme.secondary,
          lowColor: const Color(0xFFFEF3C7),
          highColor: const Color(0xFF22C55E),
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleBubbleMatrixVisuals(
          bubbleColor: colorScheme.tertiary,
          lowColor: const Color(0xFFE0F2FE),
          highColor: const Color(0xFF8B5CF6),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleBubbleMatrixVisuals(
          bubbleColor: colorScheme.primary,
          lowColor: colorScheme.secondary.withValues(alpha: 0.18),
          highColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
        );
    }
  }
}

class _DefaultBubbleMatrixTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String? label;
  final String value;

  const _DefaultBubbleMatrixTooltip({
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
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (label != null) ...[
              const SizedBox(height: 3),
              Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _paintText(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset offset,
  TextAlign align,
  double maxWidth, {
  bool centeredY = false,
}) {
  if (text.isEmpty || maxWidth <= 0) return;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  var dx = offset.dx;
  if (align == TextAlign.center) {
    dx -= painter.width / 2;
  } else if (align == TextAlign.right || align == TextAlign.end) {
    dx -= painter.width;
  }
  final dy = centeredY ? offset.dy - painter.height / 2 : offset.dy;
  painter.paint(canvas, Offset(dx, dy));
}
