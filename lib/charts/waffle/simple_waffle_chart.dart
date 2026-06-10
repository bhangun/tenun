import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleWaffleValueFormatter = String Function(double value);
typedef SimpleWaffleTapCallback =
    void Function(
      SimpleWaffleChartData data,
      int index,
      double share,
      int cellCount,
    );
typedef SimpleWaffleTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleWaffleChartData data,
      int index,
      String formattedValue,
      String formattedShare,
      int cellCount,
    );

enum SimpleWaffleFillDirection { bottomToTop, leftToRight, rightToLeft }

class SimpleWaffleChartData {
  final String label;
  final double value;
  final Color? color;

  const SimpleWaffleChartData({
    required this.label,
    required this.value,
    this.color,
  });
}

/// A compact unit chart for showing part-to-whole composition as countable
/// cells.
class SimpleWaffleChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 18, 18, 18);

  final List<SimpleWaffleChartData> data;
  final SimpleBarChartStyle style;
  final double? totalValue;
  final int rows;
  final int columns;
  final double height;
  final EdgeInsets padding;
  final SimpleWaffleFillDirection fillDirection;
  final List<Color>? palette;
  final Color? cellColor;
  final Color? emptyColor;
  final Color? borderColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLegend;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveCells;
  final bool showEmptyCells;
  final double cellGap;
  final double cellRadius;
  final SimpleWaffleValueFormatter? valueFormatter;
  final SimpleWaffleValueFormatter? percentFormatter;
  final SimpleWaffleTapCallback? onCellTap;
  final SimpleWaffleTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleWaffleChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.totalValue,
    this.rows = 10,
    this.columns = 10,
    this.height = 260,
    this.padding = _defaultPadding,
    this.fillDirection = SimpleWaffleFillDirection.bottomToTop,
    this.palette,
    this.cellColor,
    this.emptyColor,
    this.borderColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLegend = true,
    this.showValues = true,
    this.showTooltip = true,
    this.showActiveCells = true,
    this.showEmptyCells = true,
    this.cellGap = 3,
    this.cellRadius = 4,
    this.valueFormatter,
    this.percentFormatter,
    this.onCellTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(rows > 0),
       assert(columns > 0),
       assert(totalValue == null || totalValue > 0),
       assert(cellGap >= 0),
       assert(cellRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleWaffleVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.value.isFinite && item.value >= 0)
        .toList();
    final dataTotal = visibleData.fold<double>(
      0,
      (current, item) => current + item.value,
    );
    final resolvedTotal = math.max(totalValue ?? dataTotal, dataTotal);
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedPercentFormatter =
        percentFormatter ?? _defaultPercentFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty || resolvedTotal <= 0) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Waffle chart, no data.',
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
        final resolvedPalette = _resolvePalette(colorScheme, visuals.palette);
        final allocation = _WaffleAllocation.resolve(
          data: visibleData,
          total: resolvedTotal,
          totalCells: rows * columns,
        );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleData,
            resolvedTotal,
            formatter,
            resolvedPercentFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleWaffleChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            total: resolvedTotal,
            allocation: allocation,
            rows: rows,
            columns: columns,
            padding: padding,
            fillDirection: fillDirection,
            palette: resolvedPalette,
            emptyColor: emptyColor ?? visuals.emptyColor,
            borderColor: borderColor ?? visuals.borderColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLegend: showLegend,
            showValues: showValues,
            showTooltip: showTooltip,
            showActiveCells: showActiveCells,
            showEmptyCells: showEmptyCells,
            cellGap: cellGap,
            cellRadius: cellRadius,
            valueFormatter: formatter,
            percentFormatter: resolvedPercentFormatter,
            onCellTap: onCellTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(ColorScheme colorScheme, List<Color> defaults) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    if (cellColor != null) {
      return [
        cellColor!,
        colorScheme.secondary,
        colorScheme.tertiary,
        colorScheme.error,
      ];
    }
    return defaults;
  }

  String _defaultSemanticLabel(
    List<SimpleWaffleChartData> visibleData,
    double total,
    SimpleWaffleValueFormatter formatter,
    SimpleWaffleValueFormatter resolvedPercentFormatter,
  ) {
    final summaries = visibleData
        .take(6)
        .map((item) {
          final share = total <= 0 ? 0.0 : item.value / total;
          return '${item.label} ${formatter(item.value)}, '
              '${resolvedPercentFormatter(share)}';
        })
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'category' : 'categories';
    return 'Waffle chart, ${visibleData.length} $countLabel. '
        '$summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) {
    final percent = value * 100;
    if (percent == percent.roundToDouble()) {
      return '${percent.toInt()}%';
    }
    return '${percent.toStringAsFixed(1)}%';
  }
}

class _SimpleWaffleChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleWaffleChartData> data;
  final double total;
  final _WaffleAllocation allocation;
  final int rows;
  final int columns;
  final EdgeInsets padding;
  final SimpleWaffleFillDirection fillDirection;
  final List<Color> palette;
  final Color emptyColor;
  final Color borderColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLegend;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveCells;
  final bool showEmptyCells;
  final double cellGap;
  final double cellRadius;
  final SimpleWaffleValueFormatter valueFormatter;
  final SimpleWaffleValueFormatter percentFormatter;
  final SimpleWaffleTapCallback? onCellTap;
  final SimpleWaffleTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleWaffleChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.total,
    required this.allocation,
    required this.rows,
    required this.columns,
    required this.padding,
    required this.fillDirection,
    required this.palette,
    required this.emptyColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLegend,
    required this.showValues,
    required this.showTooltip,
    required this.showActiveCells,
    required this.showEmptyCells,
    required this.cellGap,
    required this.cellRadius,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.onCellTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleWaffleChartView> createState() => _SimpleWaffleChartViewState();
}

class _SimpleWaffleChartViewState extends State<_SimpleWaffleChartView> {
  int? _activeDataIndex;
  Offset _activePosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveCells ||
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
                painter: _SimpleWafflePainter(
                  data: widget.data,
                  total: widget.total,
                  allocation: widget.allocation,
                  rows: widget.rows,
                  columns: widget.columns,
                  padding: widget.padding,
                  fillDirection: widget.fillDirection,
                  palette: widget.palette,
                  emptyColor: widget.emptyColor,
                  borderColor: widget.borderColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showLegend: widget.showLegend,
                  showValues: widget.showValues,
                  showActiveCells: widget.showActiveCells,
                  showEmptyCells: widget.showEmptyCells,
                  cellGap: widget.cellGap,
                  cellRadius: widget.cellRadius,
                  activeDataIndex: _activeDataIndex,
                  valueFormatter: widget.valueFormatter,
                  percentFormatter: widget.percentFormatter,
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
                      final item = widget.data[selection.dataIndex];
                      widget.onCellTap?.call(
                        item,
                        selection.dataIndex,
                        item.value / widget.total,
                        widget.allocation.countFor(selection.dataIndex),
                      );
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeDataIndex != null)
                _buildTooltip(context, size, _activeDataIndex!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_WaffleSelection? selection) {
    if (_activeDataIndex == selection?.dataIndex &&
        _activePosition == (selection?.position ?? Offset.zero)) {
      return;
    }
    setState(() {
      _activeDataIndex = selection?.dataIndex;
      _activePosition = selection?.position ?? Offset.zero;
    });
  }

  _WaffleSelection? _hitTest(Offset position, Size size) {
    final layout = _WaffleLayout.resolve(
      size: size,
      padding: widget.padding,
      showLegend: widget.showLegend,
    );
    final geometry = _WaffleGeometry.resolve(
      layout: layout,
      allocation: widget.allocation,
      rows: widget.rows,
      columns: widget.columns,
      fillDirection: widget.fillDirection,
      cellGap: widget.cellGap,
    );
    for (final cell in geometry.cells) {
      if (cell.dataIndex == null) continue;
      if (cell.rect.inflate(math.max(2, widget.cellGap)).contains(position)) {
        return _WaffleSelection(cell.dataIndex!, cell.rect.center);
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int dataIndex) {
    final item = widget.data[dataIndex];
    final share = item.value / widget.total;
    final cellCount = widget.allocation.countFor(dataIndex);
    final formattedValue = widget.valueFormatter(item.value);
    final formattedShare = widget.percentFormatter(share);
    const tooltipWidth = 174.0;
    const tooltipHeight = 76.0;
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
            dataIndex,
            formattedValue,
            formattedShare,
            cellCount,
          ) ??
          _DefaultWaffleTooltip(
            color: _cellColor(item, dataIndex),
            title: item.label,
            rows: [
              _WaffleTooltipRow(label: 'Value', value: formattedValue),
              _WaffleTooltipRow(label: 'Share', value: formattedShare),
              _WaffleTooltipRow(label: 'Cells', value: cellCount.toString()),
            ],
          ),
    );
  }

  Color _cellColor(SimpleWaffleChartData item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleWafflePainter extends CustomPainter {
  final List<SimpleWaffleChartData> data;
  final double total;
  final _WaffleAllocation allocation;
  final int rows;
  final int columns;
  final EdgeInsets padding;
  final SimpleWaffleFillDirection fillDirection;
  final List<Color> palette;
  final Color emptyColor;
  final Color borderColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLegend;
  final bool showValues;
  final bool showActiveCells;
  final bool showEmptyCells;
  final double cellGap;
  final double cellRadius;
  final int? activeDataIndex;
  final SimpleWaffleValueFormatter valueFormatter;
  final SimpleWaffleValueFormatter percentFormatter;
  final double progress;

  const _SimpleWafflePainter({
    required this.data,
    required this.total,
    required this.allocation,
    required this.rows,
    required this.columns,
    required this.padding,
    required this.fillDirection,
    required this.palette,
    required this.emptyColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLegend,
    required this.showValues,
    required this.showActiveCells,
    required this.showEmptyCells,
    required this.cellGap,
    required this.cellRadius,
    required this.activeDataIndex,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _WaffleLayout.resolve(
      size: size,
      padding: padding,
      showLegend: showLegend,
    );
    final geometry = _WaffleGeometry.resolve(
      layout: layout,
      allocation: allocation,
      rows: rows,
      columns: columns,
      fillDirection: fillDirection,
      cellGap: cellGap,
    );
    if (geometry.cells.isEmpty) return;

    final animatedFilledCount = (allocation.assignedCellCount * progress)
        .ceil();
    var filledSeen = 0;

    for (final cell in geometry.cells) {
      final dataIndex = cell.dataIndex;
      if (dataIndex == null) {
        if (showEmptyCells) _drawCell(canvas, cell.rect, emptyColor, false);
        continue;
      }

      filledSeen += 1;
      if (filledSeen > animatedFilledCount) {
        if (showEmptyCells) _drawCell(canvas, cell.rect, emptyColor, false);
        continue;
      }

      final item = data[dataIndex];
      final color = item.color ?? palette[dataIndex % palette.length];
      final active = activeDataIndex == dataIndex;
      _drawCell(canvas, cell.rect, color, active);
    }

    if (showLegend) {
      _drawLegend(canvas, layout.legendRect);
    }
  }

  void _drawCell(Canvas canvas, Rect rect, Color color, bool active) {
    final radius = Radius.circular(math.min(cellRadius, rect.shortestSide / 2));
    final rrect = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(rrect, Paint()..color = color);
    if (borderColor.a > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
    if (!showActiveCells || !active) return;
    final highlight = activeColor ?? color;
    canvas.drawRRect(
      rrect.inflate(1.4),
      Paint()
        ..color = highlight.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawLegend(Canvas canvas, Rect rect) {
    if (rect.width <= 0 || rect.height <= 0) return;
    final rowHeight = math.max(22.0, math.min(30.0, rect.height / data.length));
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final y = rect.top + index * rowHeight;
      if (y > rect.bottom - 10) break;
      final color = item.color ?? palette[index % palette.length];
      final marker = RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, y + 6, 9, 9),
        const Radius.circular(3),
      );
      canvas.drawRRect(marker, Paint()..color = color);

      final share = total <= 0 ? 0.0 : item.value / total;
      final text = showValues
          ? '${item.label}  ${percentFormatter(share)}'
          : item.label;
      final painter = _textPainter(
        text,
        index == activeDataIndex
            ? valueStyle.copyWith(color: valueStyle.color)
            : labelStyle,
        maxWidth: math.max(0.0, rect.width - 16),
      );
      painter.paint(canvas, Offset(rect.left + 16, y + 1));
    }
  }

  TextPainter _textPainter(
    String text,
    TextStyle style, {
    required double maxWidth,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
  }

  @override
  bool shouldRepaint(covariant _SimpleWafflePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.total != total ||
        oldDelegate.allocation != allocation ||
        oldDelegate.rows != rows ||
        oldDelegate.columns != columns ||
        oldDelegate.padding != padding ||
        oldDelegate.fillDirection != fillDirection ||
        oldDelegate.palette != palette ||
        oldDelegate.emptyColor != emptyColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showActiveCells != showActiveCells ||
        oldDelegate.showEmptyCells != showEmptyCells ||
        oldDelegate.cellGap != cellGap ||
        oldDelegate.cellRadius != cellRadius ||
        oldDelegate.activeDataIndex != activeDataIndex ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.percentFormatter != percentFormatter ||
        oldDelegate.progress != progress;
  }
}

class _WaffleAllocation {
  final List<int?> cells;
  final List<int> counts;

  const _WaffleAllocation({required this.cells, required this.counts});

  int get assignedCellCount => cells.whereType<int>().length;

  int countFor(int dataIndex) {
    if (dataIndex < 0 || dataIndex >= counts.length) return 0;
    return counts[dataIndex];
  }

  factory _WaffleAllocation.resolve({
    required List<SimpleWaffleChartData> data,
    required double total,
    required int totalCells,
  }) {
    final raw = data
        .map((item) => total <= 0 ? 0.0 : item.value / total * totalCells)
        .toList();
    final counts = raw.map((value) => value.floor()).toList();
    var assigned = counts.fold<int>(0, (current, value) => current + value);
    var remaining = math.max(0, totalCells - assigned);

    final remainders = List<int>.generate(data.length, (index) => index)
      ..sort((a, b) {
        final byRemainder = (raw[b] - raw[b].floor()).compareTo(
          raw[a] - raw[a].floor(),
        );
        if (byRemainder != 0) return byRemainder;
        return data[b].value.compareTo(data[a].value);
      });

    for (final index in remainders) {
      if (remaining <= 0) break;
      if (data[index].value <= 0) continue;
      counts[index] += 1;
      remaining -= 1;
    }

    assigned = counts.fold<int>(0, (current, value) => current + value);
    if (assigned > totalCells) {
      for (var index = counts.length - 1; index >= 0; index--) {
        while (assigned > totalCells && counts[index] > 0) {
          counts[index] -= 1;
          assigned -= 1;
        }
      }
    }

    final cells = <int?>[];
    for (var index = 0; index < counts.length; index++) {
      cells.addAll(List<int?>.filled(counts[index], index));
    }
    while (cells.length < totalCells) {
      cells.add(null);
    }
    if (cells.length > totalCells) {
      cells.removeRange(totalCells, cells.length);
    }
    return _WaffleAllocation(cells: cells, counts: counts);
  }
}

class _WaffleLayout {
  final Rect gridRect;
  final Rect legendRect;

  const _WaffleLayout({required this.gridRect, required this.legendRect});

  factory _WaffleLayout.resolve({
    required Size size,
    required EdgeInsets padding,
    required bool showLegend,
  }) {
    final content = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (!showLegend) {
      final grid = _largestSquareInside(content);
      return _WaffleLayout(gridRect: grid, legendRect: Rect.zero);
    }

    final compact = content.width < 420;
    if (compact) {
      final legendHeight = math.min(64.0, content.height * 0.28);
      final gridArea = Rect.fromLTRB(
        content.left,
        content.top,
        content.right,
        math.max(content.top, content.bottom - legendHeight - 12),
      );
      return _WaffleLayout(
        gridRect: _largestSquareInside(gridArea),
        legendRect: Rect.fromLTRB(
          content.left,
          gridArea.bottom + 12,
          content.right,
          content.bottom,
        ),
      );
    }

    final legendWidth = math.min(168.0, content.width * 0.36);
    final gridArea = Rect.fromLTRB(
      content.left,
      content.top,
      math.max(content.left, content.right - legendWidth - 16),
      content.bottom,
    );
    return _WaffleLayout(
      gridRect: _largestSquareInside(gridArea),
      legendRect: Rect.fromLTRB(
        gridArea.right + 16,
        content.top,
        content.right,
        content.bottom,
      ),
    );
  }

  static Rect _largestSquareInside(Rect rect) {
    final size = math.max(0.0, math.min(rect.width, rect.height));
    return Rect.fromLTWH(
      rect.left + (rect.width - size) / 2,
      rect.top + (rect.height - size) / 2,
      size,
      size,
    );
  }
}

class _WaffleGeometry {
  final List<_WaffleCell> cells;

  const _WaffleGeometry({required this.cells});

  factory _WaffleGeometry.resolve({
    required _WaffleLayout layout,
    required _WaffleAllocation allocation,
    required int rows,
    required int columns,
    required SimpleWaffleFillDirection fillDirection,
    required double cellGap,
  }) {
    final totalGapX = cellGap * math.max(0, columns - 1);
    final totalGapY = cellGap * math.max(0, rows - 1);
    final cellSize = math.max(
      0.0,
      math.min(
        (layout.gridRect.width - totalGapX) / columns,
        (layout.gridRect.height - totalGapY) / rows,
      ),
    );
    if (cellSize <= 0) return const _WaffleGeometry(cells: []);

    final actualWidth = cellSize * columns + totalGapX;
    final actualHeight = cellSize * rows + totalGapY;
    final left =
        layout.gridRect.left + (layout.gridRect.width - actualWidth) / 2;
    final top =
        layout.gridRect.top + (layout.gridRect.height - actualHeight) / 2;
    final cells = <_WaffleCell>[];

    for (var index = 0; index < rows * columns; index++) {
      final gridPosition = _positionFor(index, rows, columns, fillDirection);
      final rect = Rect.fromLTWH(
        left + gridPosition.column * (cellSize + cellGap),
        top + gridPosition.row * (cellSize + cellGap),
        cellSize,
        cellSize,
      );
      cells.add(
        _WaffleCell(
          rect: rect,
          dataIndex: index < allocation.cells.length
              ? allocation.cells[index]
              : null,
        ),
      );
    }
    return _WaffleGeometry(cells: cells);
  }

  static _GridPosition _positionFor(
    int index,
    int rows,
    int columns,
    SimpleWaffleFillDirection direction,
  ) {
    final row = index ~/ columns;
    final column = index % columns;
    switch (direction) {
      case SimpleWaffleFillDirection.leftToRight:
        return _GridPosition(row, column);
      case SimpleWaffleFillDirection.rightToLeft:
        return _GridPosition(row, columns - 1 - column);
      case SimpleWaffleFillDirection.bottomToTop:
        return _GridPosition(rows - 1 - row, column);
    }
  }
}

class _WaffleCell {
  final Rect rect;
  final int? dataIndex;

  const _WaffleCell({required this.rect, required this.dataIndex});
}

class _GridPosition {
  final int row;
  final int column;

  const _GridPosition(this.row, this.column);
}

class _WaffleSelection {
  final int dataIndex;
  final Offset position;

  const _WaffleSelection(this.dataIndex, this.position);
}

class _SimpleWaffleVisuals {
  final List<Color> palette;
  final Color emptyColor;
  final Color borderColor;

  const _SimpleWaffleVisuals({
    required this.palette,
    required this.emptyColor,
    required this.borderColor,
  });

  factory _SimpleWaffleVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleWaffleVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFFF97316),
          ],
          emptyColor: colorScheme.primary.withValues(alpha: 0.08),
          borderColor: colorScheme.surface.withValues(alpha: 0.62),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleWaffleVisuals(
          palette: [
            colorScheme.primary,
            const Color(0xFF475569),
            const Color(0xFF0F766E),
            const Color(0xFF1D4ED8),
            const Color(0xFF64748B),
          ],
          emptyColor: colorScheme.outline.withValues(alpha: 0.1),
          borderColor: colorScheme.surface.withValues(alpha: 0.72),
        );
      case SimpleBarChartStyle.education:
        return _SimpleWaffleVisuals(
          palette: [
            colorScheme.secondary,
            const Color(0xFF3B82F6),
            const Color(0xFFF59E0B),
            const Color(0xFF10B981),
            const Color(0xFF8B5CF6),
          ],
          emptyColor: colorScheme.secondary.withValues(alpha: 0.09),
          borderColor: colorScheme.surface.withValues(alpha: 0.68),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleWaffleVisuals(
          palette: [
            colorScheme.tertiary,
            const Color(0xFF06B6D4),
            const Color(0xFF22C55E),
            const Color(0xFFEC4899),
            const Color(0xFFF97316),
          ],
          emptyColor: colorScheme.tertiary.withValues(alpha: 0.08),
          borderColor: colorScheme.surface.withValues(alpha: 0.56),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleWaffleVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFFF59E0B),
          ],
          emptyColor: colorScheme.primary.withValues(alpha: 0.07),
          borderColor: colorScheme.surface.withValues(alpha: 0.62),
        );
    }
  }
}

class _DefaultWaffleTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final List<_WaffleTooltipRow> rows;

  const _DefaultWaffleTooltip({
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

class _WaffleTooltipRow {
  final String label;
  final String value;

  const _WaffleTooltipRow({required this.label, required this.value});
}
