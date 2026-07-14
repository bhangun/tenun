import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../scatter/simple_scatter_chart.dart';

typedef SimpleBubbleValueFormatter = String Function(double value);
typedef SimpleBubbleTapCallback =
    void Function(SimpleBubbleChartData data, int index);
typedef SimpleBubbleTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleBubbleChartData data,
      int index,
      String formattedX,
      String formattedY,
      String formattedSize,
    );

class SimpleBubbleChartData {
  final String label;
  final double x;
  final double y;
  final double size;
  final String? group;
  final Color? color;

  const SimpleBubbleChartData({
    required this.label,
    required this.x,
    required this.y,
    required this.size,
    this.group,
    this.color,
  });
}

/// A lightweight bubble chart for comparing two numeric dimensions plus a
/// third magnitude dimension.
class SimpleBubbleChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 24, 42);

  final List<SimpleBubbleChartData> data;
  final SimpleBarChartStyle style;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final double height;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final String sizeLabel;
  final Color? bubbleColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? trendLineColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveBubble;
  final bool showTrendLine;
  final bool showAxisLabels;
  final List<SimpleScatterReferenceLine> referenceLines;
  final List<SimpleScatterReferenceBand> referenceBands;
  final int gridLineCount;
  final double? minBubbleRadius;
  final double? maxBubbleRadius;
  final SimpleBubbleValueFormatter? xValueFormatter;
  final SimpleBubbleValueFormatter? yValueFormatter;
  final SimpleBubbleValueFormatter? sizeFormatter;
  final SimpleBubbleTapCallback? onBubbleTap;
  final SimpleBubbleTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleBubbleChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.height = 260,
    this.padding = _defaultPadding,
    this.xAxisLabel,
    this.yAxisLabel,
    this.sizeLabel = 'Size',
    this.bubbleColor,
    this.gridColor,
    this.axisColor,
    this.trendLineColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLabels = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveBubble = true,
    this.showTrendLine = false,
    this.showAxisLabels = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.minBubbleRadius,
    this.maxBubbleRadius,
    this.xValueFormatter,
    this.yValueFormatter,
    this.sizeFormatter,
    this.onBubbleTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(minBubbleRadius == null || minBubbleRadius >= 0),
       assert(maxBubbleRadius == null || maxBubbleRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleData = data
        .where(
          (item) =>
              item.x.isFinite &&
              item.y.isFinite &&
              item.size.isFinite &&
              item.size >= 0,
        )
        .toList();
    final xFormatter = xValueFormatter ?? _defaultValueFormatter;
    final yFormatter = yValueFormatter ?? _defaultValueFormatter;
    final resolvedSizeFormatter = sizeFormatter ?? _defaultValueFormatter;

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
            emptySemanticLabel: 'Bubble chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final points = visibleData
            .map(
              (item) => SimpleScatterPoint(
                label: item.label,
                x: item.x,
                y: item.y,
                size: item.size,
                group: item.group,
                color: item.color,
              ),
            )
            .toList();

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleData,
            xFormatter,
            yFormatter,
            resolvedSizeFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: SimpleScatterChart(
            points: points,
            style: style,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            height: chartHeight,
            padding: padding,
            xAxisLabel: xAxisLabel,
            yAxisLabel: yAxisLabel,
            pointColor: bubbleColor,
            gridColor: gridColor,
            axisColor: axisColor,
            trendLineColor: trendLineColor,
            activeColor: activeColor,
            palette: palette,
            labelStyle: labelStyle,
            valueStyle: valueStyle,
            showGrid: showGrid,
            showValues: showLabels,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActiveBubble,
            showTrendLine: showTrendLine,
            showAxisLabels: showAxisLabels,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            minPointRadius: minBubbleRadius,
            maxPointRadius: maxBubbleRadius,
            xValueFormatter: xFormatter,
            yValueFormatter: yFormatter,
            sizeFormatter: resolvedSizeFormatter,
            onPointTap: (point, index) {
              onBubbleTap?.call(visibleData[index], index);
            },
            tooltipBuilder: (context, point, index, formattedX, formattedY, _) {
              final item = visibleData[index];
              final formattedSize = resolvedSizeFormatter(item.size);
              return tooltipBuilder?.call(
                    context,
                    item,
                    index,
                    formattedX,
                    formattedY,
                    formattedSize,
                  ) ??
                  _DefaultBubbleTooltip(
                    color: item.color ?? _fallbackColor(colorScheme, index),
                    title: item.label,
                    xLabel: xAxisLabel ?? 'X',
                    yLabel: yAxisLabel ?? 'Y',
                    sizeLabel: sizeLabel,
                    xValue: formattedX,
                    yValue: formattedY,
                    sizeValue: formattedSize,
                  );
            },
            excludeFromSemantics: true,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  Color _fallbackColor(ColorScheme colorScheme, int index) {
    if (bubbleColor != null) return bubbleColor!;
    if (palette != null && palette!.isNotEmpty) {
      return palette![index % palette!.length];
    }
    return switch (style) {
      SimpleBarChartStyle.modern => colorScheme.primary,
      SimpleBarChartStyle.professional => colorScheme.primary,
      SimpleBarChartStyle.education => colorScheme.secondary,
      SimpleBarChartStyle.trendy => colorScheme.tertiary,
      SimpleBarChartStyle.elegant => colorScheme.primary,
    };
  }

  String _defaultSemanticLabel(
    List<SimpleBubbleChartData> visibleData,
    SimpleBubbleValueFormatter xFormatter,
    SimpleBubbleValueFormatter yFormatter,
    SimpleBubbleValueFormatter resolvedSizeFormatter,
  ) {
    final xLabel = xAxisLabel ?? 'x';
    final yLabel = yAxisLabel ?? 'y';
    final visibleItems = visibleData
        .take(6)
        .map(
          (item) =>
              '${item.label} $xLabel ${xFormatter(item.x)}, '
              '$yLabel ${yFormatter(item.y)}, '
              '$sizeLabel ${resolvedSizeFormatter(item.size)}',
        )
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'bubble' : 'bubbles';
    return 'Bubble chart, ${visibleData.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _DefaultBubbleTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String xLabel;
  final String yLabel;
  final String sizeLabel;
  final String xValue;
  final String yValue;
  final String sizeValue;

  const _DefaultBubbleTooltip({
    required this.color,
    required this.title,
    required this.xLabel,
    required this.yLabel,
    required this.sizeLabel,
    required this.xValue,
    required this.yValue,
    required this.sizeValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
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
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TooltipRow(
              label: xLabel,
              value: xValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: yLabel,
              value: yValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: sizeLabel,
              value: sizeValue,
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _TooltipRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
