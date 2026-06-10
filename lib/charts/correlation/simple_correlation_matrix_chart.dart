import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../heatmap/simple_heatmap_chart.dart';

typedef SimpleCorrelationValueFormatter = String Function(double value);
typedef SimpleCorrelationCellTapCallback =
    void Function(SimpleCorrelationCell cell, int rowIndex, int columnIndex);
typedef SimpleCorrelationTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleCorrelationCell cell,
      int rowIndex,
      int columnIndex,
      String formattedValue,
    );

class SimpleCorrelationCell {
  final String xLabel;
  final String yLabel;
  final double value;
  final String? label;
  final Color? color;

  const SimpleCorrelationCell({
    required this.xLabel,
    required this.yLabel,
    required this.value,
    this.label,
    this.color,
  });
}

/// A simple correlation matrix with diverging colors, symmetric lookup,
/// optional upper-triangle layout, diagonal handling, and compact tooltips.
class SimpleCorrelationMatrixChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(76, 24, 58, 42);

  final List<String> variables;
  final List<SimpleCorrelationCell> correlations;
  final SimpleBarChartStyle style;
  final double minValue;
  final double maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? negativeColor;
  final Color? neutralColor;
  final Color? positiveColor;
  final Color? diagonalColor;
  final Color? emptyColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final bool showDiagonal;
  final bool showUpperTriangleOnly;
  final double cellGap;
  final double cellRadius;
  final SimpleCorrelationValueFormatter? valueFormatter;
  final SimpleCorrelationCellTapCallback? onCellTap;
  final SimpleCorrelationTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleCorrelationMatrixChart({
    super.key,
    this.variables = const [],
    required this.correlations,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue = -1,
    this.maxValue = 1,
    this.height = 280,
    this.padding = _defaultPadding,
    this.negativeColor,
    this.neutralColor,
    this.positiveColor,
    this.diagonalColor,
    this.emptyColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveCell = true,
    this.showDiagonal = true,
    this.showUpperTriangleOnly = false,
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
       assert(minValue < maxValue),
       assert(cellGap >= 0),
       assert(cellRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleCorrelationVisuals.resolve(style, colorScheme);
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final matrix = _CorrelationMatrix.from(
      variables: variables,
      correlations: correlations,
      minValue: minValue,
      maxValue: maxValue,
      showDiagonal: showDiagonal,
      showUpperTriangleOnly: showUpperTriangleOnly,
      negativeColor: negativeColor ?? visuals.negativeColor,
      neutralColor: neutralColor ?? visuals.neutralColor,
      positiveColor: positiveColor ?? visuals.positiveColor,
      diagonalColor: diagonalColor ?? visuals.diagonalColor,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (matrix.variables.length < 2 || matrix.cells.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Correlation matrix, no data.',
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
        final child = SizedBox(
          width: width,
          height: chartHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: SimpleHeatmapChart(
                  xLabels: matrix.variables,
                  yLabels: matrix.variables,
                  cells: matrix.heatmapCells,
                  style: style,
                  minValue: minValue,
                  maxValue: maxValue,
                  height: chartHeight,
                  padding: padding,
                  lowColor: negativeColor ?? visuals.negativeColor,
                  highColor: positiveColor ?? visuals.positiveColor,
                  emptyColor: emptyColor ?? visuals.emptyColor,
                  gridColor: gridColor ?? visuals.gridColor,
                  activeColor: activeColor,
                  labelStyle: resolvedLabelStyle,
                  valueStyle: resolvedValueStyle,
                  showGrid: showGrid,
                  showXLabels: showLabels,
                  showYLabels: showLabels,
                  showValues: showValues,
                  showLegend: false,
                  showTooltip: showTooltip,
                  showActiveCell: showActiveCell,
                  cellGap: cellGap,
                  cellRadius: cellRadius,
                  valueFormatter: formatter,
                  onCellTap: (cell, rowIndex, columnIndex) {
                    final correlation = matrix.cellAt(rowIndex, columnIndex);
                    if (correlation != null) {
                      onCellTap?.call(correlation, rowIndex, columnIndex);
                    }
                  },
                  tooltipBuilder: (context, cell, rowIndex, columnIndex, value) {
                    final correlation = matrix.cellAt(rowIndex, columnIndex);
                    if (correlation == null) {
                      return const SizedBox.shrink();
                    }
                    return tooltipBuilder?.call(
                          context,
                          correlation,
                          rowIndex,
                          columnIndex,
                          value,
                        ) ??
                        _DefaultCorrelationTooltip(
                          color: cell.color ?? visuals.positiveColor,
                          title:
                              '${correlation.yLabel} vs ${correlation.xLabel}',
                          label: correlation.label,
                          value: value,
                        );
                  },
                  excludeFromSemantics: true,
                  animationDuration: animationDuration,
                  animationCurve: animationCurve,
                ),
              ),
              if (showLegend)
                Positioned(
                  top: padding.top,
                  right: math.max(6, padding.right - 44),
                  bottom: padding.bottom,
                  width: 42,
                  child: _CorrelationLegend(
                    negativeColor: negativeColor ?? visuals.negativeColor,
                    neutralColor: neutralColor ?? visuals.neutralColor,
                    positiveColor: positiveColor ?? visuals.positiveColor,
                    labelStyle: resolvedValueStyle.copyWith(
                      color: gridColor ?? visuals.gridColor,
                      fontSize: (resolvedValueStyle.fontSize ?? 11) * 0.9,
                    ),
                    minLabel: formatter(minValue),
                    midLabel: formatter(0),
                    maxLabel: formatter(maxValue),
                  ),
                ),
            ],
          ),
        );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(matrix, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: child,
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    _CorrelationMatrix matrix,
    SimpleCorrelationValueFormatter formatter,
  ) {
    final sample = matrix.cells
        .take(6)
        .map(
          (item) =>
              '${item.yLabel} and ${item.xLabel} ${formatter(item.value)}',
        )
        .join(', ');
    final suffix = matrix.cells.length > 6
        ? ', and ${matrix.cells.length - 6} more'
        : '';
    return 'Correlation matrix, ${matrix.variables.length} variables and '
        '${matrix.cells.length} correlations. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) =>
      value.toStringAsFixed(2);
}

class _CorrelationMatrix {
  final List<String> variables;
  final List<SimpleCorrelationCell> cells;
  final List<SimpleHeatmapCell> heatmapCells;
  final Map<String, SimpleCorrelationCell> _byPosition;

  const _CorrelationMatrix({
    required this.variables,
    required this.cells,
    required this.heatmapCells,
    required Map<String, SimpleCorrelationCell> byPosition,
  }) : _byPosition = byPosition;

  SimpleCorrelationCell? cellAt(int rowIndex, int columnIndex) {
    if (rowIndex < 0 ||
        columnIndex < 0 ||
        rowIndex >= variables.length ||
        columnIndex >= variables.length) {
      return null;
    }
    return _byPosition[_positionKey(rowIndex, columnIndex)];
  }

  factory _CorrelationMatrix.from({
    required List<String> variables,
    required List<SimpleCorrelationCell> correlations,
    required double minValue,
    required double maxValue,
    required bool showDiagonal,
    required bool showUpperTriangleOnly,
    required Color negativeColor,
    required Color neutralColor,
    required Color positiveColor,
    required Color diagonalColor,
  }) {
    final resolvedVariables = _resolveVariables(variables, correlations);
    final source = <String, SimpleCorrelationCell>{};
    for (final cell in correlations) {
      final x = cell.xLabel.trim();
      final y = cell.yLabel.trim();
      if (x.isEmpty || y.isEmpty || !cell.value.isFinite) {
        continue;
      }
      source[_labelKey(x, y)] = SimpleCorrelationCell(
        xLabel: x,
        yLabel: y,
        value: cell.value.clamp(minValue, maxValue).toDouble(),
        label: cell.label,
        color: cell.color,
      );
    }

    final cells = <SimpleCorrelationCell>[];
    final heatmapCells = <SimpleHeatmapCell>[];
    final byPosition = <String, SimpleCorrelationCell>{};
    for (var row = 0; row < resolvedVariables.length; row++) {
      for (var column = 0; column < resolvedVariables.length; column++) {
        if (showUpperTriangleOnly && row > column) {
          continue;
        }
        final x = resolvedVariables[column];
        final y = resolvedVariables[row];
        final diagonal = x == y;
        if (diagonal && !showDiagonal) {
          continue;
        }
        final explicit = source[_labelKey(x, y)] ?? source[_labelKey(y, x)];
        final correlation =
            explicit ??
            (diagonal
                ? SimpleCorrelationCell(
                    xLabel: x,
                    yLabel: y,
                    value: maxValue,
                    label: 'Self',
                  )
                : null);
        if (correlation == null) {
          continue;
        }
        final displayCell = SimpleCorrelationCell(
          xLabel: x,
          yLabel: y,
          value: correlation.value,
          label: correlation.label,
          color: correlation.color,
        );
        final color =
            displayCell.color ??
            (diagonal
                ? diagonalColor
                : _colorForValue(
                    displayCell.value,
                    minValue,
                    maxValue,
                    negativeColor,
                    neutralColor,
                    positiveColor,
                  ));
        cells.add(displayCell);
        byPosition[_positionKey(row, column)] = displayCell;
        heatmapCells.add(
          SimpleHeatmapCell(
            xLabel: x,
            yLabel: y,
            value: displayCell.value,
            color: color,
            label: displayCell.label,
          ),
        );
      }
    }
    return _CorrelationMatrix(
      variables: resolvedVariables,
      cells: cells,
      heatmapCells: heatmapCells,
      byPosition: byPosition,
    );
  }

  static List<String> _resolveVariables(
    List<String> variables,
    List<SimpleCorrelationCell> correlations,
  ) {
    final seen = <String>{};
    final result = <String>[];
    for (final variable in variables) {
      final value = variable.trim();
      if (value.isNotEmpty && seen.add(value)) {
        result.add(value);
      }
    }
    if (result.isNotEmpty) {
      return result;
    }
    for (final cell in correlations) {
      for (final label in [cell.xLabel, cell.yLabel]) {
        final value = label.trim();
        if (value.isNotEmpty && seen.add(value)) {
          result.add(value);
        }
      }
    }
    return result;
  }

  static String _labelKey(String x, String y) => '$x\u0000$y';
  static String _positionKey(int row, int column) => '$row:$column';

  static Color _colorForValue(
    double value,
    double minValue,
    double maxValue,
    Color negativeColor,
    Color neutralColor,
    Color positiveColor,
  ) {
    if (value < 0 && minValue < 0) {
      final t = (value / minValue).clamp(0.0, 1.0).toDouble();
      return Color.lerp(neutralColor, negativeColor, t) ?? negativeColor;
    }
    if (value > 0 && maxValue > 0) {
      final t = (value / maxValue).clamp(0.0, 1.0).toDouble();
      return Color.lerp(neutralColor, positiveColor, t) ?? positiveColor;
    }
    return neutralColor;
  }
}

class _SimpleCorrelationVisuals {
  final Color negativeColor;
  final Color neutralColor;
  final Color positiveColor;
  final Color diagonalColor;
  final Color emptyColor;
  final Color gridColor;

  const _SimpleCorrelationVisuals({
    required this.negativeColor,
    required this.neutralColor,
    required this.positiveColor,
    required this.diagonalColor,
    required this.emptyColor,
    required this.gridColor,
  });

  factory _SimpleCorrelationVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleCorrelationVisuals(
          negativeColor: colorScheme.error,
          neutralColor: colorScheme.surfaceContainerHighest,
          positiveColor: colorScheme.primary,
          diagonalColor: colorScheme.primary.withValues(alpha: 0.72),
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.28,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.34),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleCorrelationVisuals(
          negativeColor: const Color(0xFFB91C1C),
          neutralColor: colorScheme.surfaceContainerHighest,
          positiveColor: colorScheme.primary,
          diagonalColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.34,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.42),
        );
      case SimpleBarChartStyle.education:
        return _SimpleCorrelationVisuals(
          negativeColor: const Color(0xFFEA580C),
          neutralColor: colorScheme.surfaceContainerHighest,
          positiveColor: colorScheme.secondary,
          diagonalColor: colorScheme.secondary.withValues(alpha: 0.72),
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.32,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.34),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleCorrelationVisuals(
          negativeColor: const Color(0xFFEC4899),
          neutralColor: colorScheme.surfaceContainerHighest,
          positiveColor: const Color(0xFF14B8A6),
          diagonalColor: colorScheme.tertiary.withValues(alpha: 0.74),
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.26,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.28),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleCorrelationVisuals(
          negativeColor: colorScheme.error,
          neutralColor: colorScheme.surfaceContainerHighest,
          positiveColor: colorScheme.primary,
          diagonalColor: colorScheme.tertiary.withValues(alpha: 0.68),
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.34),
        );
    }
  }
}

class _CorrelationLegend extends StatelessWidget {
  final Color negativeColor;
  final Color neutralColor;
  final Color positiveColor;
  final TextStyle labelStyle;
  final String minLabel;
  final String midLabel;
  final String maxLabel;

  const _CorrelationLegend({
    required this.negativeColor,
    required this.neutralColor,
    required this.positiveColor,
    required this.labelStyle,
    required this.minLabel,
    required this.midLabel,
    required this.maxLabel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final legendWidth = math.min(14.0, constraints.maxWidth);
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: math.max(0, constraints.maxWidth - legendWidth - 4),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Text(maxLabel, style: labelStyle),
                  ),
                  Positioned(
                    top: math.max(0, constraints.maxHeight / 2 - 7),
                    right: 0,
                    child: Text(midLabel, style: labelStyle),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Text(minLabel, style: labelStyle),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: legendWidth,
              height: constraints.maxHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [negativeColor, neutralColor, positiveColor],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DefaultCorrelationTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String? label;
  final String value;

  const _DefaultCorrelationTooltip({
    required this.color,
    required this.title,
    required this.label,
    required this.value,
  });

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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: DefaultTextStyle(
            style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (label != null && label!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(label!),
                ],
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
