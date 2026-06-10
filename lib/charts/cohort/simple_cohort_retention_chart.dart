import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleCohortRetentionValueFormatter = String Function(double value);

typedef SimpleCohortRetentionCellTapCallback =
    void Function(
      SimpleCohortRetentionRow row,
      int rowIndex,
      int periodIndex,
      double value,
    );

typedef SimpleCohortRetentionTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleCohortRetentionRow row,
      int rowIndex,
      int periodIndex,
      String periodLabel,
      String formattedValue,
      String? formattedSize,
    );

class SimpleCohortRetentionRow {
  final String label;
  final List<double?> values;
  final double? size;
  final Color? color;

  const SimpleCohortRetentionRow({
    required this.label,
    required this.values,
    this.size,
    this.color,
  });
}

/// A cohort heatmap for retention, completion, adoption, or survival curves.
class SimpleCohortRetentionChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(86, 28, 52, 40);

  final List<SimpleCohortRetentionRow> rows;
  final List<String> periodLabels;
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
  final bool showPeriodLabels;
  final bool showCohortLabels;
  final bool showCohortSize;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final bool showEmptyCells;
  final double cellGap;
  final double cellRadius;
  final SimpleCohortRetentionValueFormatter? valueFormatter;
  final SimpleCohortRetentionValueFormatter? sizeFormatter;
  final SimpleCohortRetentionCellTapCallback? onCellTap;
  final SimpleCohortRetentionTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleCohortRetentionChart({
    super.key,
    required this.rows,
    this.periodLabels = const [],
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
    this.showPeriodLabels = true,
    this.showCohortLabels = true,
    this.showCohortSize = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveCell = true,
    this.showEmptyCells = true,
    this.cellGap = 3,
    this.cellRadius = 5,
    this.valueFormatter,
    this.sizeFormatter,
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
    final visuals = _SimpleCohortRetentionVisuals.resolve(style, colorScheme);
    final visibleRows = rows
        .where(
          (row) =>
              row.label.trim().isNotEmpty &&
              row.values.any((value) => value != null && value.isFinite),
        )
        .toList();
    final grid = _CohortRetentionGrid.from(
      rows: visibleRows,
      periodLabels: periodLabels,
      minValue: minValue,
      maxValue: maxValue,
    );
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedSizeFormatter = sizeFormatter ?? _defaultSizeFormatter;

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
            emptySemanticLabel: 'Cohort retention chart, no data.',
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
          child: _SimpleCohortRetentionChartView(
            width: width,
            height: chartHeight,
            grid: grid,
            padding: padding,
            lowColor: lowColor ?? visuals.lowColor,
            highColor: highColor ?? visuals.highColor,
            emptyColor: emptyColor ?? visuals.emptyColor,
            gridColor: gridColor ?? visuals.gridColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showPeriodLabels: showPeriodLabels,
            showCohortLabels: showCohortLabels,
            showCohortSize: showCohortSize,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveCell: showActiveCell,
            showEmptyCells: showEmptyCells,
            cellGap: cellGap,
            cellRadius: cellRadius,
            valueFormatter: formatter,
            sizeFormatter: resolvedSizeFormatter,
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
    _CohortRetentionGrid grid,
    SimpleCohortRetentionValueFormatter formatter,
  ) {
    final summaries = <String>[];
    for (
      var rowIndex = 0;
      rowIndex < math.min(grid.rows.length, 5);
      rowIndex++
    ) {
      final row = grid.rows[rowIndex];
      final first = row.values.firstWhere(
        (value) => value != null && value.isFinite,
        orElse: () => null,
      );
      final last = row.values.reversed.firstWhere(
        (value) => value != null && value.isFinite,
        orElse: () => null,
      );
      if (first == null || last == null) continue;
      summaries.add('${row.label} ${formatter(first)} to ${formatter(last)}');
    }
    final remaining = grid.rows.length - math.min(grid.rows.length, 5);
    final suffix = remaining > 0 ? '; and $remaining more cohorts' : '';
    return 'Cohort retention chart, ${grid.rows.length} cohorts and '
        '${grid.periodLabels.length} periods. ${summaries.join('; ')}$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value.abs() <= 1) {
      final percent = value * 100;
      if (percent == percent.roundToDouble()) return '${percent.toInt()}%';
      return '${percent.toStringAsFixed(1)}%';
    }
    if (value == value.roundToDouble()) return '${value.toInt()}%';
    return '${value.toStringAsFixed(1)}%';
  }

  static String _defaultSizeFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _SimpleCohortRetentionChartView extends StatefulWidget {
  final double width;
  final double height;
  final _CohortRetentionGrid grid;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showPeriodLabels;
  final bool showCohortLabels;
  final bool showCohortSize;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final bool showEmptyCells;
  final double cellGap;
  final double cellRadius;
  final SimpleCohortRetentionValueFormatter valueFormatter;
  final SimpleCohortRetentionValueFormatter sizeFormatter;
  final SimpleCohortRetentionCellTapCallback? onCellTap;
  final SimpleCohortRetentionTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleCohortRetentionChartView({
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
    required this.showPeriodLabels,
    required this.showCohortLabels,
    required this.showCohortSize,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveCell,
    required this.showEmptyCells,
    required this.cellGap,
    required this.cellRadius,
    required this.valueFormatter,
    required this.sizeFormatter,
    required this.onCellTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleCohortRetentionChartView> createState() =>
      _SimpleCohortRetentionChartViewState();
}

class _SimpleCohortRetentionChartViewState
    extends State<_SimpleCohortRetentionChartView> {
  int? _activeRow;
  int? _activePeriod;

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
                painter: _SimpleCohortRetentionPainter(
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
                  showPeriodLabels: widget.showPeriodLabels,
                  showCohortLabels: widget.showCohortLabels,
                  showCohortSize: widget.showCohortSize,
                  showValues: widget.showValues,
                  showLegend: widget.showLegend,
                  showActiveCell: widget.showActiveCell,
                  showEmptyCells: widget.showEmptyCells,
                  cellGap: widget.cellGap,
                  cellRadius: widget.cellRadius,
                  valueFormatter: widget.valueFormatter,
                  sizeFormatter: widget.sizeFormatter,
                  activeRow: _activeRow,
                  activePeriod: _activePeriod,
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
                      final value = widget.grid.valueAt(hit.row, hit.period);
                      if (value != null) {
                        widget.onCellTap?.call(
                          widget.grid.rows[hit.row],
                          hit.row,
                          hit.period,
                          value,
                        );
                      }
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip &&
                  _activeRow != null &&
                  _activePeriod != null)
                _buildTooltip(context, size, _activeRow!, _activePeriod!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_CohortRetentionHit? hit) {
    if (_activeRow == hit?.row && _activePeriod == hit?.period) return;
    setState(() {
      _activeRow = hit?.row;
      _activePeriod = hit?.period;
    });
  }

  _CohortRetentionHit? _hitTest(Offset position, Size size) {
    final plot = _plot(size);
    if (!plot.contains(position)) return null;
    final cellWidth = plot.width / widget.grid.periodLabels.length;
    final cellHeight = plot.height / widget.grid.rows.length;
    final period = ((position.dx - plot.left) / cellWidth).floor();
    final row = ((position.dy - plot.top) / cellHeight).floor();
    if (row < 0 ||
        period < 0 ||
        row >= widget.grid.rows.length ||
        period >= widget.grid.periodLabels.length) {
      return null;
    }
    if (widget.grid.valueAt(row, period) == null) return null;
    return _CohortRetentionHit(row, period);
  }

  Widget _buildTooltip(BuildContext context, Size size, int row, int period) {
    final value = widget.grid.valueAt(row, period);
    if (value == null) return const SizedBox.shrink();
    final cohort = widget.grid.rows[row];
    final formattedValue = widget.valueFormatter(value);
    final formattedSize = cohort.size == null
        ? null
        : widget.sizeFormatter(cohort.size!);
    final anchor = _anchorFor(size, row, period);
    const tooltipWidth = 186.0;
    const tooltipHeight = 86.0;
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
            cohort,
            row,
            period,
            widget.grid.periodLabels[period],
            formattedValue,
            formattedSize,
          ) ??
          _DefaultCohortRetentionTooltip(
            color: _cellColor(cohort, value),
            cohortLabel: cohort.label,
            periodLabel: widget.grid.periodLabels[period],
            value: formattedValue,
            size: formattedSize,
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

  Offset _anchorFor(Size size, int row, int period) {
    final plot = _plot(size);
    final cellWidth = plot.width / widget.grid.periodLabels.length;
    final cellHeight = plot.height / widget.grid.rows.length;
    return Offset(
      plot.left + cellWidth * period + cellWidth / 2,
      plot.top + cellHeight * row + cellHeight / 2,
    );
  }

  Color _cellColor(SimpleCohortRetentionRow row, double value) {
    if (row.color != null) return row.color!;
    return Color.lerp(
          widget.lowColor,
          widget.highColor,
          widget.grid.normalize(value),
        ) ??
        widget.highColor;
  }
}

class _SimpleCohortRetentionPainter extends CustomPainter {
  final _CohortRetentionGrid grid;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showPeriodLabels;
  final bool showCohortLabels;
  final bool showCohortSize;
  final bool showValues;
  final bool showLegend;
  final bool showActiveCell;
  final bool showEmptyCells;
  final double cellGap;
  final double cellRadius;
  final SimpleCohortRetentionValueFormatter valueFormatter;
  final SimpleCohortRetentionValueFormatter sizeFormatter;
  final int? activeRow;
  final int? activePeriod;
  final double progress;

  const _SimpleCohortRetentionPainter({
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
    required this.showPeriodLabels,
    required this.showCohortLabels,
    required this.showCohortSize,
    required this.showValues,
    required this.showLegend,
    required this.showActiveCell,
    required this.showEmptyCells,
    required this.cellGap,
    required this.cellRadius,
    required this.valueFormatter,
    required this.sizeFormatter,
    required this.activeRow,
    required this.activePeriod,
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
    if (showGrid) _drawGrid(canvas, plot);
    if (showCohortLabels) _drawCohortLabels(canvas, plot);
    if (showPeriodLabels) _drawPeriodLabels(canvas, plot);
    if (showLegend) _drawLegend(canvas, plot, size);
  }

  void _drawCells(Canvas canvas, Rect plot) {
    final cellWidth = plot.width / grid.periodLabels.length;
    final cellHeight = plot.height / grid.rows.length;
    final gap = math.min(cellGap, math.min(cellWidth, cellHeight) / 3);

    for (var rowIndex = 0; rowIndex < grid.rows.length; rowIndex++) {
      final row = grid.rows[rowIndex];
      for (var period = 0; period < grid.periodLabels.length; period++) {
        final value = grid.valueAt(rowIndex, period);
        if (value == null && !showEmptyCells) continue;
        final rect = Rect.fromLTWH(
          plot.left + period * cellWidth + gap / 2,
          plot.top + rowIndex * cellHeight + gap / 2,
          math.max(0.0, cellWidth - gap),
          math.max(0.0, cellHeight - gap),
        );
        final scale = 0.72 + progress * 0.28;
        final animatedRect = Rect.fromCenter(
          center: rect.center,
          width: rect.width * scale,
          height: rect.height * scale,
        );
        final color = value == null ? emptyColor : _cellColor(row, value);
        final radius = Radius.circular(
          math.min(cellRadius, math.min(rect.width, rect.height) / 2),
        );
        final active = rowIndex == activeRow && period == activePeriod;

        if (showActiveCell && active && value != null) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.inflate(3), radius),
            Paint()..color = (activeColor ?? color).withValues(alpha: 0.16),
          );
        }

        canvas.drawRRect(
          RRect.fromRectAndRadius(animatedRect, radius),
          Paint()..color = color.withValues(alpha: value == null ? 0.26 : 0.94),
        );

        if (showValues &&
            value != null &&
            cellWidth >= 34 &&
            cellHeight >= 22) {
          _drawCellValue(canvas, value, animatedRect, color);
        }
      }
    }
  }

  void _drawCellValue(Canvas canvas, double value, Rect rect, Color color) {
    final foreground = color.computeLuminance() < 0.42
        ? Colors.white
        : Colors.black.withValues(alpha: 0.78);
    _paintText(
      canvas,
      valueFormatter(value),
      valueStyle.copyWith(
        color: foreground,
        fontSize: (valueStyle.fontSize ?? 11) * 0.9,
      ),
      rect.center,
      TextAlign.center,
      math.max(8, rect.width - 4),
      centeredY: true,
    );
  }

  void _drawGrid(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final cellWidth = plot.width / grid.periodLabels.length;
    final cellHeight = plot.height / grid.rows.length;
    for (var period = 0; period <= grid.periodLabels.length; period++) {
      final x = plot.left + period * cellWidth;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), paint);
    }
    for (var row = 0; row <= grid.rows.length; row++) {
      final y = plot.top + row * cellHeight;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
    }
  }

  void _drawCohortLabels(Canvas canvas, Rect plot) {
    final cellHeight = plot.height / grid.rows.length;
    final maxWidth = math.max(28.0, padding.left - 14);
    for (var rowIndex = 0; rowIndex < grid.rows.length; rowIndex++) {
      final row = grid.rows[rowIndex];
      final y = plot.top + rowIndex * cellHeight + cellHeight / 2;
      final text = showCohortSize && row.size != null
          ? '${row.label} (${sizeFormatter(row.size!)})'
          : row.label;
      _paintText(
        canvas,
        text,
        labelStyle,
        Offset(plot.left - 8, y),
        TextAlign.right,
        maxWidth,
        centeredY: true,
      );
    }
  }

  void _drawPeriodLabels(Canvas canvas, Rect plot) {
    final cellWidth = plot.width / grid.periodLabels.length;
    final maxLabelCount = math.max(1, plot.width / 38).floor();
    final labelEvery = math.max(
      1,
      (grid.periodLabels.length / maxLabelCount).ceil(),
    );
    for (var period = 0; period < grid.periodLabels.length; period++) {
      if (period % labelEvery != 0) continue;
      _paintText(
        canvas,
        grid.periodLabels[period],
        labelStyle,
        Offset(plot.left + period * cellWidth + cellWidth / 2, plot.bottom + 8),
        TextAlign.center,
        math.max(18, cellWidth * 0.94),
      );
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
    _paintText(
      canvas,
      valueFormatter(grid.min),
      labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 12) * 0.86),
      Offset(legendLeft - 2, plot.bottom),
      TextAlign.left,
      42,
    );
    _paintText(
      canvas,
      valueFormatter(grid.max),
      labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 12) * 0.86),
      Offset(legendLeft - 2, plot.top),
      TextAlign.left,
      42,
    );
  }

  Color _cellColor(SimpleCohortRetentionRow row, double value) {
    if (row.color != null) return row.color!;
    return Color.lerp(lowColor, highColor, grid.normalize(value)) ?? highColor;
  }

  @override
  bool shouldRepaint(covariant _SimpleCohortRetentionPainter oldDelegate) {
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
        oldDelegate.showPeriodLabels != showPeriodLabels ||
        oldDelegate.showCohortLabels != showCohortLabels ||
        oldDelegate.showCohortSize != showCohortSize ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveCell != showActiveCell ||
        oldDelegate.showEmptyCells != showEmptyCells ||
        oldDelegate.cellGap != cellGap ||
        oldDelegate.cellRadius != cellRadius ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.sizeFormatter != sizeFormatter ||
        oldDelegate.activeRow != activeRow ||
        oldDelegate.activePeriod != activePeriod ||
        oldDelegate.progress != progress;
  }
}

class _CohortRetentionGrid {
  final List<SimpleCohortRetentionRow> rows;
  final List<String> periodLabels;
  final double min;
  final double max;

  const _CohortRetentionGrid({
    required this.rows,
    required this.periodLabels,
    required this.min,
    required this.max,
  });

  bool get isEmpty => rows.isEmpty || periodLabels.isEmpty;

  double? valueAt(int row, int period) {
    if (row < 0 || period < 0 || row >= rows.length) return null;
    if (period >= rows[row].values.length) return null;
    final value = rows[row].values[period];
    if (value == null || !value.isFinite) return null;
    return value;
  }

  double normalize(double value) {
    return ((value - min) / math.max(0.000001, max - min))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  factory _CohortRetentionGrid.from({
    required List<SimpleCohortRetentionRow> rows,
    required List<String> periodLabels,
    required double? minValue,
    required double? maxValue,
  }) {
    if (rows.isEmpty) {
      return const _CohortRetentionGrid(
        rows: [],
        periodLabels: [],
        min: 0,
        max: 1,
      );
    }
    final maxPeriods = rows.fold<int>(
      0,
      (max, row) => math.max(max, row.values.length),
    );
    final resolvedPeriods = periodLabels.isNotEmpty
        ? periodLabels
        : [for (var index = 0; index < maxPeriods; index++) 'P$index'];
    final visibleRows = <SimpleCohortRetentionRow>[];
    var lower = double.infinity;
    var upper = double.negativeInfinity;
    for (final row in rows) {
      final values = row.values
          .map((value) => value != null && value.isFinite ? value : null)
          .toList();
      if (!values.any((value) => value != null)) continue;
      visibleRows.add(
        SimpleCohortRetentionRow(
          label: row.label,
          values: values,
          size: row.size,
          color: row.color,
        ),
      );
      for (final value in values.whereType<double>()) {
        lower = math.min(lower, value);
        upper = math.max(upper, value);
      }
    }
    if (visibleRows.isEmpty || !lower.isFinite || !upper.isFinite) {
      return const _CohortRetentionGrid(
        rows: [],
        periodLabels: [],
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
    return _CohortRetentionGrid(
      rows: visibleRows,
      periodLabels: resolvedPeriods,
      min: lower,
      max: upper,
    );
  }
}

class _CohortRetentionHit {
  final int row;
  final int period;

  const _CohortRetentionHit(this.row, this.period);
}

class _SimpleCohortRetentionVisuals {
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;

  const _SimpleCohortRetentionVisuals({
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.gridColor,
  });

  factory _SimpleCohortRetentionVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleCohortRetentionVisuals(
          lowColor: const Color(0xFFE0F2FE),
          highColor: const Color(0xFF2563EB),
          emptyColor: colorScheme.surfaceContainerHighest,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleCohortRetentionVisuals(
          lowColor: const Color(0xFFE2E8F0),
          highColor: const Color(0xFF0F766E),
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.64,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
        );
      case SimpleBarChartStyle.education:
        return _SimpleCohortRetentionVisuals(
          lowColor: const Color(0xFFFEF3C7),
          highColor: const Color(0xFF22C55E),
          emptyColor: colorScheme.surfaceContainerHighest,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleCohortRetentionVisuals(
          lowColor: const Color(0xFFE0F2FE),
          highColor: const Color(0xFF8B5CF6),
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.7,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleCohortRetentionVisuals(
          lowColor: colorScheme.secondary.withValues(alpha: 0.12),
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
        );
    }
  }
}

class _DefaultCohortRetentionTooltip extends StatelessWidget {
  final Color color;
  final String cohortLabel;
  final String periodLabel;
  final String value;
  final String? size;

  const _DefaultCohortRetentionTooltip({
    required this.color,
    required this.cohortLabel,
    required this.periodLabel,
    required this.value,
    required this.size,
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cohortLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              periodLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            _TooltipRow(label: 'Retention', value: value),
            if (size != null) _TooltipRow(label: 'Cohort', value: size!),
          ],
        ),
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _TooltipRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
