import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import '../line/simple_line_chart.dart';

typedef SimpleSmallMultiplesValueFormatter = String Function(double value);

typedef SimpleSmallMultiplesPointTapCallback =
    void Function(
      SimpleSmallMultiplePanel panel,
      int panelIndex,
      String label,
      List<SimpleTrendTooltipItem> items,
      int pointIndex,
    );

typedef SimpleSmallMultiplesTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleSmallMultiplePanel panel,
      int panelIndex,
      String label,
      List<SimpleTrendTooltipItem> items,
    );

class SimpleSmallMultiplePanel {
  final String label;
  final String? subtitle;
  final List<SimpleTrendSeries> series;
  final Color? color;

  const SimpleSmallMultiplePanel({
    required this.label,
    this.subtitle,
    required this.series,
    this.color,
  });
}

/// Repeated mini trend charts for comparing many categories on the same scale.
class SimpleSmallMultiplesChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.zero;
  static const EdgeInsets _innerChartPadding = EdgeInsets.fromLTRB(
    30,
    8,
    8,
    18,
  );

  final List<SimpleSmallMultiplePanel> panels;
  final SimpleTrendChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final EdgeInsets chartPadding;
  final int? columns;
  final double minPanelWidth;
  final double panelGap;
  final Color? lineColor;
  final Color? fillColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? dividerColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final TextStyle? subtitleStyle;
  final bool sharedYAxis;
  final bool includeZero;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showArea;
  final bool showLegend;
  final bool showTooltip;
  final bool showPanelDividers;
  final bool? smooth;
  final double? strokeWidth;
  final double? dotRadius;
  final double? fillOpacity;
  final int gridLineCount;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final SimpleSmallMultiplesValueFormatter? valueFormatter;
  final SimpleSmallMultiplesPointTapCallback? onPointTap;
  final SimpleSmallMultiplesTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleSmallMultiplesChart({
    super.key,
    required this.panels,
    this.style = SimpleTrendChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 300,
    this.padding = _defaultPadding,
    this.chartPadding = _innerChartPadding,
    this.columns,
    this.minPanelWidth = 170,
    this.panelGap = 12,
    this.lineColor,
    this.fillColor,
    this.gridColor,
    this.axisColor,
    this.dividerColor,
    this.labelStyle,
    this.valueStyle,
    this.subtitleStyle,
    this.sharedYAxis = true,
    this.includeZero = false,
    this.showGrid = true,
    this.showDots = true,
    this.showValues = false,
    this.showArea = false,
    this.showLegend = false,
    this.showTooltip = true,
    this.showPanelDividers = true,
    this.smooth,
    this.strokeWidth,
    this.dotRadius,
    this.fillOpacity,
    this.gridLineCount = 3,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 680),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(columns == null || columns > 0),
       assert(minPanelWidth > 0),
       assert(panelGap >= 0),
       assert(gridLineCount >= 2),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(dotRadius == null || dotRadius >= 0),
       assert(fillOpacity == null || (fillOpacity >= 0 && fillOpacity <= 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visiblePanels = panels
        .where(
          (panel) =>
              panel.label.trim().isNotEmpty &&
              panel.series.any(
                (series) => series.points.any((point) => point.value.isFinite),
              ),
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final range = sharedYAxis
        ? _resolveSharedRange(visiblePanels)
        : const _SmallMultiplesRange(null, null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visiblePanels.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Small multiples chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedLabelStyle =
            labelStyle ??
            theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
        final resolvedSubtitleStyle =
            subtitleStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ) ??
            TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11);
        final resolvedValueStyle = valueStyle ?? theme.textTheme.labelSmall;
        final resolvedColumns = _resolveColumns(width, visiblePanels.length);

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(visiblePanels, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: SizedBox(
            width: width,
            height: chartHeight,
            child: Padding(
              padding: padding,
              child: _buildGrid(
                context,
                visiblePanels,
                resolvedColumns,
                range,
                formatter,
                resolvedLabelStyle,
                resolvedSubtitleStyle,
                resolvedValueStyle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<SimpleSmallMultiplePanel> visiblePanels,
    int columnCount,
    _SmallMultiplesRange range,
    SimpleSmallMultiplesValueFormatter formatter,
    TextStyle resolvedLabelStyle,
    TextStyle resolvedSubtitleStyle,
    TextStyle? resolvedValueStyle,
  ) {
    final rowCount = (visiblePanels.length / columnCount).ceil();
    return Column(
      children: [
        for (var row = 0; row < rowCount; row++) ...[
          if (row > 0) SizedBox(height: panelGap),
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < columnCount; column++) ...[
                  if (column > 0) SizedBox(width: panelGap),
                  Expanded(
                    child:
                        _panelAt(visiblePanels, row, column, columnCount) ==
                            null
                        ? const SizedBox.shrink()
                        : _buildPanel(
                            context,
                            _panelAt(visiblePanels, row, column, columnCount)!,
                            row * columnCount + column,
                            range,
                            formatter,
                            resolvedLabelStyle,
                            resolvedSubtitleStyle,
                            resolvedValueStyle,
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  SimpleSmallMultiplePanel? _panelAt(
    List<SimpleSmallMultiplePanel> visiblePanels,
    int row,
    int column,
    int columnCount,
  ) {
    final index = row * columnCount + column;
    if (index >= visiblePanels.length) return null;
    return visiblePanels[index];
  }

  Widget _buildPanel(
    BuildContext context,
    SimpleSmallMultiplePanel panel,
    int panelIndex,
    _SmallMultiplesRange range,
    SimpleSmallMultiplesValueFormatter formatter,
    TextStyle resolvedLabelStyle,
    TextStyle resolvedSubtitleStyle,
    TextStyle? resolvedValueStyle,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                panel.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolvedLabelStyle,
              ),
            ),
            if (panel.subtitle != null && panel.subtitle!.trim().isNotEmpty)
              Text(
                panel.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolvedSubtitleStyle,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SimpleLineChart(
            series: _seriesForPanel(panel),
            style: style,
            minValue: range.min,
            maxValue: range.max,
            height: 120,
            padding: chartPadding,
            lineColor: lineColor ?? panel.color,
            fillColor: fillColor,
            gridColor: gridColor,
            axisColor: axisColor,
            labelStyle: resolvedSubtitleStyle,
            valueStyle: resolvedValueStyle,
            includeZero: includeZero,
            showGrid: showGrid,
            showDots: showDots,
            showValues: showValues,
            showArea: showArea,
            showLegend: showLegend,
            showTooltip: showTooltip,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            smooth: smooth,
            strokeWidth: strokeWidth,
            dotRadius: dotRadius,
            fillOpacity: fillOpacity,
            gridLineCount: gridLineCount,
            valueFormatter: formatter,
            onPointTap: onPointTap == null
                ? null
                : (label, items, pointIndex) {
                    onPointTap!(panel, panelIndex, label, items, pointIndex);
                  },
            tooltipBuilder: tooltipBuilder == null
                ? null
                : (context, label, items) {
                    return tooltipBuilder!(
                      context,
                      panel,
                      panelIndex,
                      label,
                      items,
                    );
                  },
            excludeFromSemantics: true,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        ),
      ],
    );

    if (!showPanelDividers) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color:
              dividerColor ?? colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(padding: const EdgeInsets.all(8), child: child),
    );
  }

  List<SimpleTrendSeries> _seriesForPanel(SimpleSmallMultiplePanel panel) {
    return [
      for (var index = 0; index < panel.series.length; index++)
        SimpleTrendSeries(
          name: panel.series[index].name,
          points: panel.series[index].points,
          color: panel.series[index].color ?? (index == 0 ? panel.color : null),
          strokeWidth: panel.series[index].strokeWidth,
          lineStyle: panel.series[index].lineStyle,
        ),
    ];
  }

  int _resolveColumns(double width, int panelCount) {
    if (columns != null) return math.min(columns!, panelCount);
    final available = math.max(1.0, width - padding.horizontal);
    final resolved = math.max(1, (available / minPanelWidth).floor());
    return math.min(panelCount, resolved);
  }

  _SmallMultiplesRange _resolveSharedRange(
    List<SimpleSmallMultiplePanel> visiblePanels,
  ) {
    var lower = double.infinity;
    var upper = double.negativeInfinity;

    for (final panel in visiblePanels) {
      for (final series in panel.series) {
        for (final point in series.points) {
          if (!point.value.isFinite) continue;
          lower = math.min(lower, point.value);
          upper = math.max(upper, point.value);
        }
      }
    }
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      lower = math.min(lower, line.value);
      upper = math.max(upper, line.value);
    }
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;
      lower = math.min(lower, math.min(band.from, band.to));
      upper = math.max(upper, math.max(band.from, band.to));
    }
    if (!lower.isFinite || !upper.isFinite) {
      return _SmallMultiplesRange(minValue, maxValue);
    }
    if (includeZero) {
      lower = math.min(lower, 0);
      upper = math.max(upper, 0);
    }
    lower = minValue ?? lower;
    upper = maxValue ?? upper;
    if (lower == upper) {
      lower -= 1;
      upper += 1;
    } else if (minValue == null || maxValue == null) {
      final pad = (upper - lower) * 0.06;
      lower = minValue ?? lower - pad;
      upper = maxValue ?? upper + pad;
    }
    return _SmallMultiplesRange(lower, upper);
  }

  String _defaultSemanticLabel(
    List<SimpleSmallMultiplePanel> visiblePanels,
    SimpleSmallMultiplesValueFormatter formatter,
  ) {
    final summaries = visiblePanels
        .take(4)
        .map((panel) {
          final firstSeries = panel.series.firstWhere(
            (series) => series.points.any((point) => point.value.isFinite),
          );
          final finitePoints = firstSeries.points
              .where((point) => point.value.isFinite)
              .toList();
          final first = finitePoints.first;
          final last = finitePoints.last;
          return '${panel.label} from ${first.label} ${formatter(first.value)} '
              'to ${last.label} ${formatter(last.value)}';
        })
        .join('; ');
    final remaining = visiblePanels.length - math.min(visiblePanels.length, 4);
    final suffix = remaining > 0 ? '; and $remaining more panels' : '';
    return 'Small multiples chart, ${visiblePanels.length} panels. '
        '$summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _SmallMultiplesRange {
  final double? min;
  final double? max;

  const _SmallMultiplesRange(this.min, this.max);
}
