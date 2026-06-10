import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleBarValueFormatter = String Function(double value);
typedef SimpleBarTapCallback =
    void Function(SimpleBarChartData data, int index);
typedef SimpleBarTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleBarChartData data,
      int index,
      String formattedValue,
    );
typedef SimpleGroupedBarTapCallback =
    void Function(
      String category,
      SimpleGroupedBarSeries series,
      double value,
      int categoryIndex,
      int seriesIndex,
    );
typedef SimpleGroupedBarTooltipBuilder =
    Widget Function(
      BuildContext context,
      String category,
      SimpleGroupedBarSeries series,
      double value,
      int categoryIndex,
      int seriesIndex,
      String formattedValue,
    );
typedef SimpleStackedBarTapCallback =
    void Function(
      String category,
      SimpleGroupedBarSeries series,
      double value,
      double share,
      int categoryIndex,
      int seriesIndex,
    );
typedef SimpleStackedBarTooltipBuilder =
    Widget Function(
      BuildContext context,
      String category,
      SimpleGroupedBarSeries series,
      double value,
      double share,
      int categoryIndex,
      int seriesIndex,
      String formattedValue,
      String formattedShare,
    );

enum SimpleBarChartOrientation { vertical, horizontal }

enum SimpleBarChartStyle { elegant, modern, professional, education, trendy }

enum SimpleStackedBarMode { absolute, percent }

class SimpleBarChartData {
  final String label;
  final double value;
  final Color? color;

  const SimpleBarChartData({
    required this.label,
    required this.value,
    this.color,
  });
}

class SimpleGroupedBarSeries {
  final String name;
  final List<double> values;
  final Color? color;

  const SimpleGroupedBarSeries({
    required this.name,
    required this.values,
    this.color,
  });
}

/// A lightweight, polished bar chart for small comparison datasets.
class SimpleBarChart extends StatelessWidget {
  static const EdgeInsets _verticalPadding = EdgeInsets.fromLTRB(
    44,
    18,
    16,
    34,
  );
  static const EdgeInsets _horizontalPadding = EdgeInsets.fromLTRB(
    76,
    18,
    18,
    30,
  );

  final List<SimpleBarChartData> data;
  final SimpleBarChartOrientation orientation;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets? padding;
  final Color? barColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? trackColor;
  final Color? activeBarColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showTrack;
  final bool showTooltip;
  final bool showActiveBar;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? barRadius;
  final double? barWidthFactor;
  final double? maxBarWidth;
  final bool? useGradient;
  final SimpleBarValueFormatter? valueFormatter;
  final SimpleBarTapCallback? onBarTap;
  final SimpleBarTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleBarChart({
    super.key,
    required this.data,
    this.orientation = SimpleBarChartOrientation.vertical,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 240,
    this.padding,
    this.barColor,
    this.gridColor,
    this.axisColor,
    this.trackColor,
    this.activeBarColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showTrack = false,
    this.showTooltip = true,
    this.showActiveBar = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.barRadius,
    this.barWidthFactor,
    this.maxBarWidth,
    this.useGradient,
    this.valueFormatter,
    this.onBarTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 650),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(gridLineCount >= 2),
       assert(barRadius == null || barRadius >= 0),
       assert(
         barWidthFactor == null || (barWidthFactor > 0 && barWidthFactor <= 1),
       ),
       assert(maxBarWidth == null || maxBarWidth > 0),
       assert(height > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 360.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;
        final visuals = _SimpleBarChartVisuals.resolve(style, colorScheme);
        final resolvedValueFormatter = valueFormatter ?? _defaultValueFormatter;
        final resolvedPadding =
            padding ??
            (orientation == SimpleBarChartOrientation.vertical
                ? _verticalPadding
                : _horizontalPadding);

        if (data.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Bar chart, no data.',
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
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(resolvedValueFormatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleBarChartView(
            width: width,
            height: chartHeight,
            data: data,
            orientation: orientation,
            minValue: minValue,
            maxValue: maxValue,
            padding: resolvedPadding,
            barColor: barColor ?? visuals.barColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            trackColor: trackColor ?? visuals.trackColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showTrack: showTrack,
            showTooltip: showTooltip,
            showActiveBar: showActiveBar,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            barRadius: barRadius ?? visuals.barRadius,
            barWidthFactor: barWidthFactor ?? visuals.barWidthFactor,
            maxBarWidth: maxBarWidth ?? visuals.maxBarWidth,
            useGradient: useGradient ?? visuals.useGradient,
            activeBarColor: activeBarColor,
            valueFormatter: resolvedValueFormatter,
            onBarTap: onBarTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(SimpleBarValueFormatter formatter) {
    final visibleItems = data
        .take(6)
        .map((item) {
          return '${item.label} ${formatter(item.value)}';
        })
        .join(', ');
    final remaining = data.length - math.min(data.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = data.length == 1 ? 'item' : 'items';
    return 'Bar chart, ${data.length} $countLabel. $visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

/// A compact grouped bar chart for comparing multiple series per category.
class SimpleGroupedBarChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(44, 18, 16, 34);

  final List<String> categories;
  final List<SimpleGroupedBarSeries> series;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? barColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeBarColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveBar;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? barRadius;
  final double? barWidthFactor;
  final double? maxBarWidth;
  final bool? useGradient;
  final SimpleBarValueFormatter? valueFormatter;
  final SimpleGroupedBarTapCallback? onBarTap;
  final SimpleGroupedBarTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleGroupedBarChart({
    super.key,
    required this.categories,
    required this.series,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.barColor,
    this.gridColor,
    this.axisColor,
    this.activeBarColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveBar = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.barRadius,
    this.barWidthFactor,
    this.maxBarWidth,
    this.useGradient,
    this.valueFormatter,
    this.onBarTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(gridLineCount >= 2),
       assert(barRadius == null || barRadius >= 0),
       assert(
         barWidthFactor == null || (barWidthFactor > 0 && barWidthFactor <= 1),
       ),
       assert(maxBarWidth == null || maxBarWidth > 0),
       assert(height > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleBarChartVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .where((item) => item.values.any((value) => value.isFinite))
        .toList();
    final resolvedValueFormatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (categories.isEmpty || visibleSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Grouped bar chart, no data.',
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
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleSeries,
            resolvedValueFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleGroupedBarChartView(
            width: width,
            height: chartHeight,
            categories: categories,
            series: visibleSeries,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals.barColor),
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveBar: showActiveBar,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            barRadius: barRadius ?? visuals.barRadius,
            barWidthFactor: barWidthFactor ?? visuals.barWidthFactor,
            maxBarWidth: maxBarWidth ?? visuals.maxBarWidth,
            useGradient: useGradient ?? visuals.useGradient,
            activeBarColor: activeBarColor,
            valueFormatter: resolvedValueFormatter,
            onBarTap: onBarTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(ColorScheme colorScheme, Color fallback) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    return [
      barColor ?? fallback,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
  }

  String _defaultSemanticLabel(
    List<SimpleGroupedBarSeries> visibleSeries,
    SimpleBarValueFormatter formatter,
  ) {
    final summaries = <String>[];
    final categoryLimit = math.min(categories.length, 4);
    for (
      var categoryIndex = 0;
      categoryIndex < categoryLimit;
      categoryIndex++
    ) {
      final values = visibleSeries
          .take(3)
          .where((item) => categoryIndex < item.values.length)
          .where((item) => item.values[categoryIndex].isFinite)
          .map((item) {
            return '${item.name} ${formatter(item.values[categoryIndex])}';
          })
          .join(', ');
      summaries.add('${categories[categoryIndex]}: $values');
    }
    final categorySummaries = summaries.join('; ');
    final remainingCategories =
        categories.length - math.min(categories.length, 4);
    final suffix = remainingCategories > 0
        ? '; and $remainingCategories more categories'
        : '';
    return 'Grouped bar chart, ${visibleSeries.length} series across '
        '${categories.length} categories. $categorySummaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleGroupedBarChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<String> categories;
  final List<SimpleGroupedBarSeries> series;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveBar;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;
  final Color? activeBarColor;
  final SimpleBarValueFormatter valueFormatter;
  final SimpleGroupedBarTapCallback? onBarTap;
  final SimpleGroupedBarTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleGroupedBarChartView({
    required this.width,
    required this.height,
    required this.categories,
    required this.series,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveBar,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
    required this.activeBarColor,
    required this.valueFormatter,
    required this.onBarTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleGroupedBarChartView> createState() =>
      _SimpleGroupedBarChartViewState();
}

class _SimpleGroupedBarChartViewState
    extends State<_SimpleGroupedBarChartView> {
  _GroupedBarSelection? _active;

  @override
  Widget build(BuildContext context) {
    final hasLegend = widget.showLegend && widget.series.length > 1;
    final interactionEnabled =
        widget.showTooltip || widget.showActiveBar || widget.onBarTap != null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final chart = TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: widget.animationDuration,
                  curve: widget.animationCurve,
                  builder: (context, progress, child) {
                    return CustomPaint(
                      painter: _SimpleGroupedBarChartPainter(
                        categories: widget.categories,
                        series: widget.series,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showValues: widget.showValues,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        gridLineCount: widget.gridLineCount,
                        barRadius: widget.barRadius,
                        barWidthFactor: widget.barWidthFactor,
                        maxBarWidth: widget.maxBarWidth,
                        useGradient: widget.useGradient,
                        activeBarColor: widget.activeBarColor,
                        activeSelection: widget.showActiveBar ? _active : null,
                        valueFormatter: widget.valueFormatter,
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
                            final selection = _hitTest(
                              details.localPosition,
                              size,
                            );
                            _setActive(selection);
                            if (selection == null) return;

                            final category =
                                widget.categories[selection.categoryIndex];
                            final selectedSeries =
                                widget.series[selection.seriesIndex];
                            final value =
                                selectedSeries.values[selection.categoryIndex];
                            widget.onBarTap?.call(
                              category,
                              selectedSeries,
                              value,
                              selection.categoryIndex,
                              selection.seriesIndex,
                            );
                          },
                          child: chart,
                        ),
                      ),
                    ),
                    if (widget.showTooltip && _active != null)
                      _buildTooltip(context, size, _active!),
                  ],
                );
              },
            ),
          ),
          if (hasLegend) _buildLegend(context),
        ],
      ),
    );
  }

  void _setActive(_GroupedBarSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _GroupedBarSelection? _hitTest(Offset position, Size size) {
    final plot = _plot(size);
    if (!plot.inflate(8).contains(position)) return null;
    if (widget.categories.isEmpty || widget.series.isEmpty) return null;

    final categoryWidth = plot.width / widget.categories.length;
    final categoryIndex = ((position.dx - plot.left) / categoryWidth).floor();
    if (categoryIndex < 0 || categoryIndex >= widget.categories.length) {
      return null;
    }

    final geometry = _groupGeometry(plot, categoryIndex);
    if (position.dx < geometry.groupLeft - 4 ||
        position.dx > geometry.groupRight + 4) {
      return null;
    }

    final relative = position.dx - geometry.groupLeft;
    final stride = geometry.barWidth + geometry.gap;
    final seriesIndex = (relative / stride).floor();
    if (seriesIndex < 0 || seriesIndex >= widget.series.length) return null;
    final series = widget.series[seriesIndex];
    if (categoryIndex >= series.values.length) return null;
    if (!series.values[categoryIndex].isFinite) return null;

    return _GroupedBarSelection(categoryIndex, seriesIndex);
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _GroupedBarSelection selection,
  ) {
    final category = widget.categories[selection.categoryIndex];
    final selectedSeries = widget.series[selection.seriesIndex];
    final value = selectedSeries.values[selection.categoryIndex];
    final formattedValue = widget.valueFormatter(value);
    final anchor = _anchorFor(selection, size);
    const tooltipWidth = 176.0;
    const tooltipHeight = 58.0;
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
            category,
            selectedSeries,
            value,
            selection.categoryIndex,
            selection.seriesIndex,
            formattedValue,
          ) ??
          _DefaultChartTooltip(
            title: category,
            rows: [
              _TooltipRow(
                color: _seriesColor(selection.seriesIndex),
                label: selectedSeries.name,
                value: formattedValue,
              ),
            ],
          ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: [
          for (var index = 0; index < widget.series.length; index++)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _seriesColor(index),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.series[index].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.labelStyle.copyWith(
                        color:
                            widget.labelStyle.color ??
                            colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Offset _anchorFor(_GroupedBarSelection selection, Size size) {
    final plot = _plot(size);
    final range = _resolveRange();
    final zeroY = _yForValue(
      0,
      plot,
      range,
    ).clamp(plot.top, plot.bottom).toDouble();
    final geometry = _groupGeometry(plot, selection.categoryIndex);
    final x =
        geometry.groupLeft +
        geometry.barWidth * (selection.seriesIndex + 0.5) +
        geometry.gap * selection.seriesIndex;
    final value =
        widget.series[selection.seriesIndex].values[selection.categoryIndex];
    final valueY = _yForValue(value, plot, range);
    final y = value >= 0 ? math.min(zeroY, valueY) : math.max(zeroY, valueY);
    return Offset(x, y);
  }

  _GroupedBarGeometry _groupGeometry(Rect plot, int categoryIndex) {
    const gap = 3.0;
    final categoryWidth = plot.width / widget.categories.length;
    final maxGroupWidth =
        widget.maxBarWidth * widget.series.length +
        gap * (widget.series.length - 1);
    final groupWidth = math.min(
      categoryWidth * widget.barWidthFactor,
      maxGroupWidth,
    );
    final rawBarWidth =
        (groupWidth - gap * (widget.series.length - 1)) / widget.series.length;
    final barWidth = math.max(2.0, math.min(widget.maxBarWidth, rawBarWidth));
    final actualGroupWidth =
        barWidth * widget.series.length + gap * (widget.series.length - 1);
    final groupLeft =
        plot.left +
        categoryWidth * categoryIndex +
        (categoryWidth - actualGroupWidth) / 2;
    return _GroupedBarGeometry(groupLeft, actualGroupWidth, barWidth, gap);
  }

  Color _seriesColor(int index) {
    return widget.series[index].color ??
        widget.palette[index % widget.palette.length];
  }

  Rect _plot(Size size) {
    return Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }

  _ValueRange _resolveRange() {
    var lower = double.infinity;
    var upper = double.negativeInfinity;

    for (final item in widget.series) {
      final limit = math.min(widget.categories.length, item.values.length);
      for (var index = 0; index < limit; index++) {
        final value = item.values[index];
        if (!value.isFinite) continue;
        lower = math.min(lower, value);
        upper = math.max(upper, value);
      }
    }
    for (final line in widget.referenceLines) {
      if (!line.value.isFinite) continue;
      lower = math.min(lower, line.value);
      upper = math.max(upper, line.value);
    }
    for (final band in widget.referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;
      lower = math.min(lower, math.min(band.from, band.to));
      upper = math.max(upper, math.max(band.from, band.to));
    }

    if (!lower.isFinite || !upper.isFinite) {
      lower = 0;
      upper = 1;
    }

    lower = widget.minValue ?? math.min(0.0, lower);
    upper = widget.maxValue ?? math.max(0.0, upper);

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

    return _ValueRange(lower, upper);
  }

  double _yForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }
}

class _SimpleGroupedBarChartPainter extends CustomPainter {
  final List<String> categories;
  final List<SimpleGroupedBarSeries> series;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;
  final Color? activeBarColor;
  final _GroupedBarSelection? activeSelection;
  final SimpleBarValueFormatter valueFormatter;
  final double progress;

  const _SimpleGroupedBarChartPainter({
    required this.categories,
    required this.series,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
    required this.activeBarColor,
    required this.activeSelection,
    required this.valueFormatter,
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
    if (plot.width <= 0 || plot.height <= 0) return;

    final range = _resolveRange();
    final zeroY = _yForValue(
      0,
      plot,
      range,
    ).clamp(plot.top, plot.bottom).toDouble();

    _drawReferenceBands(canvas, plot, range);
    _drawActiveCategory(canvas, plot);
    if (showGrid) {
      _drawGrid(canvas, plot, range);
    }
    _drawAxis(canvas, plot, zeroY);
    _drawReferenceLines(canvas, plot, range);
    _drawBars(canvas, plot, range, zeroY);
    _drawLabels(canvas, plot);
  }

  _ValueRange _resolveRange() {
    var lower = double.infinity;
    var upper = double.negativeInfinity;

    for (final item in series) {
      final limit = math.min(categories.length, item.values.length);
      for (var index = 0; index < limit; index++) {
        final value = item.values[index];
        if (!value.isFinite) continue;
        lower = math.min(lower, value);
        upper = math.max(upper, value);
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
      lower = 0;
      upper = 1;
    }

    lower = minValue ?? math.min(0.0, lower);
    upper = maxValue ?? math.max(0.0, upper);

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

    return _ValueRange(lower, upper);
  }

  double _yForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  void _drawGrid(Canvas canvas, Rect plot, _ValueRange range) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index <= gridLineCount; index++) {
      final value = range.min + range.span * (index / gridLineCount);
      final y = _yForValue(value, plot, range);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);

      final painter = _textPainter(
        valueFormatter(value),
        labelStyle.copyWith(color: labelStyle.color?.withValues(alpha: 0.72)),
        maxWidth: padding.left - 10,
        textAlign: TextAlign.right,
      )..layout(maxWidth: padding.left - 10);
      painter.paint(
        canvas,
        Offset(plot.left - painter.width - 8, y - painter.height / 2),
      );
    }
  }

  void _drawAxis(Canvas canvas, Rect plot, double zeroY) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(plot.left, zeroY),
      Offset(plot.right, zeroY),
      axisPaint,
    );
  }

  void _drawReferenceBands(Canvas canvas, Rect plot, _ValueRange range) {
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;

      final y1 = _yForValue(band.from, plot, range);
      final y2 = _yForValue(band.to, plot, range);
      final top = math.min(y1, y2);
      final bottom = math.max(y1, y2);
      if (bottom < plot.top || top > plot.bottom) continue;

      final rect = Rect.fromLTRB(
        plot.left,
        math.max(plot.top, top),
        plot.right,
        math.min(plot.bottom, bottom),
      );
      if (rect.height <= 0.5) continue;

      final color = band.color ?? palette.first;
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      _drawBandLabel(canvas, band, rect.topRight, plot, color);
    }
  }

  void _drawBandLabel(
    Canvas canvas,
    SimpleChartReferenceBand band,
    Offset anchor,
    Rect plot,
    Color color,
  ) {
    if (!band.showLabel) return;

    final text =
        band.label ??
        '${valueFormatter(band.from)} - ${valueFormatter(band.to)}';
    final maxWidth = math.min(128.0, plot.width);
    final painter = _textPainter(
      text,
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.9,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: maxWidth,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + padding.horizontal;
    final height = painter.height + padding.vertical;
    final x = _safeClamp(
      anchor.dx - width - 6,
      plot.left + 2,
      plot.right - width - 2,
    );
    final y = _safeClamp(anchor.dy + 4, plot.top + 2, plot.bottom - height - 2);
    final rect = Rect.fromLTWH(x, y, width, height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = color.withValues(alpha: 0.14),
    );
    painter.paint(canvas, Offset(x + padding.left, y + padding.top));
  }

  void _drawReferenceLines(Canvas canvas, Rect plot, _ValueRange range) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final y = _yForValue(line.value, plot, range);
      if (y < plot.top - 1 || y > plot.bottom + 1) continue;

      final color = line.color ?? axisColor.withValues(alpha: 0.82);
      _drawStyledLine(
        canvas,
        Offset(plot.left, y),
        Offset(plot.right, y),
        _referencePaint(line, color),
        line.lineStyle,
      );
      _drawReferenceLabel(
        canvas,
        line,
        valueFormatter(line.value),
        Offset(plot.right, y),
        plot,
        color,
      );
    }
  }

  Paint _referencePaint(SimpleChartReferenceLine line, Color color) {
    return Paint()
      ..color = color
      ..strokeWidth = line.strokeWidth
      ..strokeCap = line.lineStyle == SimpleChartReferenceLineStyle.dotted
          ? StrokeCap.round
          : StrokeCap.butt;
  }

  void _drawStyledLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    SimpleChartReferenceLineStyle style,
  ) {
    if (style == SimpleChartReferenceLineStyle.solid) {
      canvas.drawLine(start, end, paint);
      return;
    }

    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) return;

    final direction = delta / distance;
    final dash = style == SimpleChartReferenceLineStyle.dotted ? 1.0 : 7.0;
    final gap = style == SimpleChartReferenceLineStyle.dotted ? 5.0 : 5.0;
    var traveled = 0.0;

    while (traveled < distance) {
      final next = math.min(traveled + dash, distance);
      canvas.drawLine(
        start + direction * traveled,
        start + direction * next,
        paint,
      );
      traveled = next + gap;
    }
  }

  void _drawReferenceLabel(
    Canvas canvas,
    SimpleChartReferenceLine line,
    String fallbackLabel,
    Offset anchor,
    Rect plot,
    Color color,
  ) {
    if (!line.showLabel) return;

    final text = line.label ?? fallbackLabel;
    final painter = _textPainter(
      text,
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.92,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: math.min(112.0, plot.width),
      textAlign: TextAlign.center,
    )..layout(maxWidth: math.min(112.0, plot.width));
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + padding.horizontal;
    final height = painter.height + padding.vertical;
    final x = _safeClamp(
      anchor.dx - width - 6,
      plot.left + 2,
      plot.right - width - 2,
    );
    final y = _safeClamp(
      anchor.dy - height - 4,
      plot.top + 2,
      plot.bottom - height - 2,
    );
    final rect = Rect.fromLTWH(x, y, width, height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = color.withValues(alpha: 0.1),
    );
    painter.paint(canvas, Offset(x + padding.left, y + padding.top));
  }

  void _drawActiveCategory(Canvas canvas, Rect plot) {
    final selection = activeSelection;
    if (selection == null ||
        selection.categoryIndex < 0 ||
        selection.categoryIndex >= categories.length) {
      return;
    }

    final categoryWidth = plot.width / categories.length;
    final rect = Rect.fromLTWH(
      plot.left + categoryWidth * selection.categoryIndex,
      plot.top,
      categoryWidth,
      plot.height,
    );
    final color = activeBarColor ?? _seriesColor(selection.seriesIndex);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.055));
  }

  void _drawBars(Canvas canvas, Rect plot, _ValueRange range, double zeroY) {
    if (categories.isEmpty || series.isEmpty) return;

    final categoryWidth = plot.width / categories.length;
    for (
      var categoryIndex = 0;
      categoryIndex < categories.length;
      categoryIndex++
    ) {
      final geometry = _groupGeometry(plot, categoryIndex);

      for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
        final item = series[seriesIndex];
        if (categoryIndex >= item.values.length) continue;
        final value = item.values[categoryIndex];
        if (!value.isFinite) continue;

        final x =
            geometry.groupLeft +
            (geometry.barWidth + geometry.gap) * seriesIndex;
        final targetY = _yForValue(value, plot, range);
        final animatedY = zeroY + (targetY - zeroY) * progress;
        final top = math.min(zeroY, animatedY);
        final bottom = math.max(zeroY, animatedY);
        final rect = Rect.fromLTRB(x, top, x + geometry.barWidth, bottom);
        if (rect.height <= 0.5) continue;

        final color = _seriesColor(seriesIndex);
        canvas.drawRRect(_barRRect(rect, value), _barPaint(color, rect, value));

        if (activeSelection ==
            _GroupedBarSelection(categoryIndex, seriesIndex)) {
          _drawActiveBarIndicator(canvas, rect, value, color);
        }

        if (showValues && categoryWidth >= 58 && geometry.barWidth >= 10) {
          _drawValue(canvas, value, rect, plot);
        }
      }
    }
  }

  _GroupedBarGeometry _groupGeometry(Rect plot, int categoryIndex) {
    const gap = 3.0;
    final categoryWidth = plot.width / categories.length;
    final maxGroupWidth =
        maxBarWidth * series.length + gap * (series.length - 1);
    final groupWidth = math.min(categoryWidth * barWidthFactor, maxGroupWidth);
    final rawBarWidth =
        (groupWidth - gap * (series.length - 1)) / series.length;
    final barWidth = math.max(2.0, math.min(maxBarWidth, rawBarWidth));
    final actualGroupWidth =
        barWidth * series.length + gap * (series.length - 1);
    final groupLeft =
        plot.left +
        categoryWidth * categoryIndex +
        (categoryWidth - actualGroupWidth) / 2;
    return _GroupedBarGeometry(groupLeft, actualGroupWidth, barWidth, gap);
  }

  Paint _barPaint(Color color, Rect rect, double value) {
    if (!useGradient) return Paint()..color = color;

    return Paint()
      ..shader = LinearGradient(
        begin: value >= 0 ? Alignment.topCenter : Alignment.bottomCenter,
        end: value >= 0 ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.72)],
      ).createShader(rect);
  }

  RRect _barRRect(Rect rect, double value) {
    final radius = Radius.circular(math.min(barRadius, rect.height / 2));
    if (value < 0) {
      return RRect.fromRectAndCorners(
        rect,
        bottomLeft: radius,
        bottomRight: radius,
      );
    }
    return RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius);
  }

  void _drawActiveBarIndicator(
    Canvas canvas,
    Rect rect,
    double value,
    Color baseColor,
  ) {
    final color = activeBarColor ?? baseColor;
    canvas.drawRRect(
      _barRRect(rect.inflate(3), value),
      Paint()..color = color.withValues(alpha: 0.14),
    );
    canvas.drawRRect(
      _barRRect(rect.inflate(1.4), value),
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawValue(Canvas canvas, double value, Rect bar, Rect plot) {
    final painter = _textPainter(valueFormatter(value), valueStyle)..layout();
    final x = _safeClamp(
      bar.center.dx - painter.width / 2,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final preferredY = value >= 0
        ? bar.top - painter.height - 6
        : bar.bottom + 6;
    final y = _safeClamp(
      preferredY,
      plot.top + 2,
      plot.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
  }

  void _drawLabels(Canvas canvas, Rect plot) {
    final categoryWidth = plot.width / categories.length;
    final maxLabelCount = math.max(1, plot.width / 58).floor();
    final labelEvery = math.max(1, (categories.length / maxLabelCount).ceil());

    for (var index = 0; index < categories.length; index++) {
      if (index % labelEvery != 0) continue;

      final x = plot.left + categoryWidth * index + categoryWidth / 2;
      final maxWidth = math.max(18.0, categoryWidth * 0.92);
      final painter = _textPainter(
        categories[index],
        labelStyle,
        maxWidth: maxWidth,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x - painter.width / 2, plot.bottom + 8));
    }
  }

  Color _seriesColor(int index) {
    return series[index].color ?? palette[index % palette.length];
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
  bool shouldRepaint(covariant _SimpleGroupedBarChartPainter oldDelegate) {
    return oldDelegate.categories != categories ||
        oldDelegate.series != series ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.barWidthFactor != barWidthFactor ||
        oldDelegate.maxBarWidth != maxBarWidth ||
        oldDelegate.useGradient != useGradient ||
        oldDelegate.activeBarColor != activeBarColor ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _GroupedBarSelection {
  final int categoryIndex;
  final int seriesIndex;

  const _GroupedBarSelection(this.categoryIndex, this.seriesIndex);

  @override
  bool operator ==(Object other) {
    return other is _GroupedBarSelection &&
        other.categoryIndex == categoryIndex &&
        other.seriesIndex == seriesIndex;
  }

  @override
  int get hashCode => Object.hash(categoryIndex, seriesIndex);
}

class _GroupedBarGeometry {
  final double groupLeft;
  final double groupWidth;
  final double barWidth;
  final double gap;

  const _GroupedBarGeometry(
    this.groupLeft,
    this.groupWidth,
    this.barWidth,
    this.gap,
  );

  double get groupRight => groupLeft + groupWidth;
}

class _SimpleBarChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleBarChartData> data;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color barColor;
  final Color gridColor;
  final Color axisColor;
  final Color trackColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showTrack;
  final bool showTooltip;
  final bool showActiveBar;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;
  final Color? activeBarColor;
  final SimpleBarValueFormatter valueFormatter;
  final SimpleBarTapCallback? onBarTap;
  final SimpleBarTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleBarChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.barColor,
    required this.gridColor,
    required this.axisColor,
    required this.trackColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showTrack,
    required this.showTooltip,
    required this.showActiveBar,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
    required this.activeBarColor,
    required this.valueFormatter,
    required this.onBarTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleBarChartView> createState() => _SimpleBarChartViewState();
}

class _SimpleBarChartViewState extends State<_SimpleBarChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveBar || widget.onBarTap != null;

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
                painter: _SimpleBarChartPainter(
                  data: widget.data,
                  orientation: widget.orientation,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  padding: widget.padding,
                  barColor: widget.barColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  trackColor: widget.trackColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showTrack: widget.showTrack,
                  referenceLines: widget.referenceLines,
                  referenceBands: widget.referenceBands,
                  gridLineCount: widget.gridLineCount,
                  barRadius: widget.barRadius,
                  barWidthFactor: widget.barWidthFactor,
                  maxBarWidth: widget.maxBarWidth,
                  useGradient: widget.useGradient,
                  activeBarColor: widget.activeBarColor,
                  activeIndex: widget.showActiveBar ? _activeIndex : null,
                  valueFormatter: widget.valueFormatter,
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
                        widget.onBarTap?.call(widget.data[index], index);
                      }
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeIndex != null)
                _buildTooltip(context, size, _activeIndex!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(int? index) {
    if (_activeIndex == index) return;
    setState(() => _activeIndex = index);
  }

  int? _hitTest(Offset position, Size size) {
    final plot = _plot(size);
    if (!plot.inflate(8).contains(position)) return null;

    if (widget.orientation == SimpleBarChartOrientation.horizontal) {
      final segmentHeight = plot.height / widget.data.length;
      final index = ((position.dy - plot.top) / segmentHeight).floor();
      return index >= 0 && index < widget.data.length ? index : null;
    }

    final segmentWidth = plot.width / widget.data.length;
    final index = ((position.dx - plot.left) / segmentWidth).floor();
    return index >= 0 && index < widget.data.length ? index : null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final item = widget.data[index];
    final formattedValue = widget.valueFormatter(item.value);
    final anchor = _anchorFor(index, size);
    const tooltipWidth = 164.0;
    const tooltipHeight = 58.0;
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
          widget.tooltipBuilder?.call(context, item, index, formattedValue) ??
          _DefaultChartTooltip(
            title: item.label,
            rows: [
              _TooltipRow(
                color: item.color ?? widget.barColor,
                label: 'Value',
                value: formattedValue,
              ),
            ],
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final plot = _plot(size);
    final range = _resolveRange();
    final zeroY = _yForValue(
      0,
      plot,
      range,
    ).clamp(plot.top, plot.bottom).toDouble();
    final zeroX = _xForValue(
      0,
      plot,
      range,
    ).clamp(plot.left, plot.right).toDouble();

    if (widget.orientation == SimpleBarChartOrientation.horizontal) {
      final segmentHeight = plot.height / widget.data.length;
      final y = plot.top + segmentHeight * index + segmentHeight / 2;
      final valueX = _xForValue(widget.data[index].value, plot, range);
      final x = widget.data[index].value >= 0
          ? math.max(zeroX, valueX)
          : math.min(zeroX, valueX);
      return Offset(x, y);
    }

    final segmentWidth = plot.width / widget.data.length;
    final x = plot.left + segmentWidth * index + segmentWidth / 2;
    final valueY = _yForValue(widget.data[index].value, plot, range);
    final y = widget.data[index].value >= 0
        ? math.min(zeroY, valueY)
        : math.max(zeroY, valueY);
    return Offset(x, y);
  }

  Rect _plot(Size size) {
    return Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }

  _ValueRange _resolveRange() {
    final minData = widget.data.fold<double>(
      double.infinity,
      (current, item) => math.min(current, item.value),
    );
    final maxData = widget.data.fold<double>(
      double.negativeInfinity,
      (current, item) => math.max(current, item.value),
    );
    final minReference = widget.referenceLines.fold<double>(
      double.infinity,
      (current, item) =>
          item.value.isFinite ? math.min(current, item.value) : current,
    );
    final maxReference = widget.referenceLines.fold<double>(
      double.negativeInfinity,
      (current, item) =>
          item.value.isFinite ? math.max(current, item.value) : current,
    );
    final minBand = widget.referenceBands.fold<double>(
      double.infinity,
      (current, item) => math.min(
        current,
        math.min(
          item.from.isFinite ? item.from : double.infinity,
          item.to.isFinite ? item.to : double.infinity,
        ),
      ),
    );
    final maxBand = widget.referenceBands.fold<double>(
      double.negativeInfinity,
      (current, item) => math.max(
        current,
        math.max(
          item.from.isFinite ? item.from : double.negativeInfinity,
          item.to.isFinite ? item.to : double.negativeInfinity,
        ),
      ),
    );
    var lower =
        widget.minValue ??
        math.min(0.0, math.min(math.min(minData, minReference), minBand));
    var upper =
        widget.maxValue ??
        math.max(0.0, math.max(math.max(maxData, maxReference), maxBand));

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

    return _ValueRange(lower, upper);
  }

  double _yForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  double _xForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.left + normalized * plot.width;
  }
}

class _SimpleBarChartPainter extends CustomPainter {
  final List<SimpleBarChartData> data;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color barColor;
  final Color gridColor;
  final Color axisColor;
  final Color trackColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showTrack;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;
  final Color? activeBarColor;
  final int? activeIndex;
  final SimpleBarValueFormatter valueFormatter;
  final double progress;

  const _SimpleBarChartPainter({
    required this.data,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.barColor,
    required this.gridColor,
    required this.axisColor,
    required this.trackColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showTrack,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
    required this.activeBarColor,
    required this.activeIndex,
    required this.valueFormatter,
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

    if (plot.width <= 0 || plot.height <= 0) return;

    final range = _resolveRange();
    if (orientation == SimpleBarChartOrientation.horizontal) {
      _paintHorizontal(canvas, plot, range);
    } else {
      _paintVertical(canvas, plot, range);
    }
  }

  void _paintVertical(Canvas canvas, Rect plot, _ValueRange range) {
    final zeroY = _yForValue(
      0,
      plot,
      range,
    ).clamp(plot.top, plot.bottom).toDouble();

    _drawVerticalReferenceBands(canvas, plot, range);
    _drawVerticalActiveCategory(canvas, plot);
    if (showGrid) {
      _drawVerticalGrid(canvas, plot, range);
    }
    _drawHorizontalAxis(canvas, plot, zeroY);
    _drawVerticalReferenceLines(canvas, plot, range);
    _drawVerticalBars(canvas, plot, range, zeroY);
    _drawVerticalLabels(canvas, plot);
  }

  void _paintHorizontal(Canvas canvas, Rect plot, _ValueRange range) {
    final zeroX = _xForValue(
      0,
      plot,
      range,
    ).clamp(plot.left, plot.right).toDouble();

    _drawHorizontalReferenceBands(canvas, plot, range);
    _drawHorizontalActiveCategory(canvas, plot);
    if (showGrid) {
      _drawHorizontalGrid(canvas, plot, range);
    }
    _drawVerticalAxis(canvas, plot, zeroX);
    _drawHorizontalReferenceLines(canvas, plot, range);
    _drawHorizontalBars(canvas, plot, range, zeroX);
    _drawHorizontalLabels(canvas, plot);
  }

  _ValueRange _resolveRange() {
    final minData = data.fold<double>(
      double.infinity,
      (current, item) => math.min(current, item.value),
    );
    final maxData = data.fold<double>(
      double.negativeInfinity,
      (current, item) => math.max(current, item.value),
    );
    final minReference = referenceLines.fold<double>(
      double.infinity,
      (current, item) =>
          item.value.isFinite ? math.min(current, item.value) : current,
    );
    final maxReference = referenceLines.fold<double>(
      double.negativeInfinity,
      (current, item) =>
          item.value.isFinite ? math.max(current, item.value) : current,
    );
    final minBand = referenceBands.fold<double>(
      double.infinity,
      (current, item) => math.min(
        current,
        math.min(
          item.from.isFinite ? item.from : double.infinity,
          item.to.isFinite ? item.to : double.infinity,
        ),
      ),
    );
    final maxBand = referenceBands.fold<double>(
      double.negativeInfinity,
      (current, item) => math.max(
        current,
        math.max(
          item.from.isFinite ? item.from : double.negativeInfinity,
          item.to.isFinite ? item.to : double.negativeInfinity,
        ),
      ),
    );
    var lower =
        minValue ??
        math.min(0.0, math.min(math.min(minData, minReference), minBand));
    var upper =
        maxValue ??
        math.max(0.0, math.max(math.max(maxData, maxReference), maxBand));

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

    return _ValueRange(lower, upper);
  }

  double _yForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  double _xForValue(double value, Rect plot, _ValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.left + normalized * plot.width;
  }

  void _drawVerticalGrid(Canvas canvas, Rect plot, _ValueRange range) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index <= gridLineCount; index++) {
      final value = range.min + range.span * (index / gridLineCount);
      final y = _yForValue(value, plot, range);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);

      final painter = _textPainter(
        valueFormatter(value),
        labelStyle.copyWith(color: labelStyle.color?.withValues(alpha: 0.72)),
        maxWidth: padding.left - 10,
        textAlign: TextAlign.right,
      )..layout(maxWidth: padding.left - 10);
      painter.paint(
        canvas,
        Offset(plot.left - painter.width - 8, y - painter.height / 2),
      );
    }
  }

  void _drawHorizontalGrid(Canvas canvas, Rect plot, _ValueRange range) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index <= gridLineCount; index++) {
      final value = range.min + range.span * (index / gridLineCount);
      final x = _xForValue(value, plot, range);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);

      final painter = _textPainter(
        valueFormatter(value),
        labelStyle.copyWith(color: labelStyle.color?.withValues(alpha: 0.72)),
        textAlign: TextAlign.center,
      )..layout();
      painter.paint(canvas, Offset(x - painter.width / 2, plot.bottom + 8));
    }
  }

  void _drawHorizontalAxis(Canvas canvas, Rect plot, double zeroY) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(plot.left, zeroY),
      Offset(plot.right, zeroY),
      axisPaint,
    );
  }

  void _drawVerticalAxis(Canvas canvas, Rect plot, double zeroX) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(zeroX, plot.top),
      Offset(zeroX, plot.bottom),
      axisPaint,
    );
  }

  void _drawVerticalActiveCategory(Canvas canvas, Rect plot) {
    final index = activeIndex;
    if (index == null || index < 0 || index >= data.length) return;

    final segmentWidth = plot.width / data.length;
    final rect = Rect.fromLTWH(
      plot.left + segmentWidth * index,
      plot.top,
      segmentWidth,
      plot.height,
    );
    canvas.drawRect(
      rect,
      Paint()..color = (activeBarColor ?? barColor).withValues(alpha: 0.055),
    );
  }

  void _drawHorizontalActiveCategory(Canvas canvas, Rect plot) {
    final index = activeIndex;
    if (index == null || index < 0 || index >= data.length) return;

    final segmentHeight = plot.height / data.length;
    final rect = Rect.fromLTWH(
      plot.left,
      plot.top + segmentHeight * index,
      plot.width,
      segmentHeight,
    );
    canvas.drawRect(
      rect,
      Paint()..color = (activeBarColor ?? barColor).withValues(alpha: 0.055),
    );
  }

  void _drawVerticalReferenceBands(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
  ) {
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;

      final y1 = _yForValue(band.from, plot, range);
      final y2 = _yForValue(band.to, plot, range);
      final top = math.min(y1, y2);
      final bottom = math.max(y1, y2);
      if (bottom < plot.top || top > plot.bottom) continue;

      final rect = Rect.fromLTRB(
        plot.left,
        math.max(plot.top, top),
        plot.right,
        math.min(plot.bottom, bottom),
      );
      if (rect.height <= 0.5) continue;

      final color = band.color ?? barColor;
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      _drawBandLabel(canvas, band, rect.topRight, Axis.horizontal, plot, color);
    }
  }

  void _drawHorizontalReferenceBands(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
  ) {
    for (final band in referenceBands) {
      if (!band.from.isFinite || !band.to.isFinite) continue;

      final x1 = _xForValue(band.from, plot, range);
      final x2 = _xForValue(band.to, plot, range);
      final left = math.min(x1, x2);
      final right = math.max(x1, x2);
      if (right < plot.left || left > plot.right) continue;

      final rect = Rect.fromLTRB(
        math.max(plot.left, left),
        plot.top,
        math.min(plot.right, right),
        plot.bottom,
      );
      if (rect.width <= 0.5) continue;

      final color = band.color ?? barColor;
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: band.opacity),
      );
      _drawBandLabel(canvas, band, rect.topLeft, Axis.vertical, plot, color);
    }
  }

  void _drawBandLabel(
    Canvas canvas,
    SimpleChartReferenceBand band,
    Offset anchor,
    Axis axis,
    Rect plot,
    Color color,
  ) {
    if (!band.showLabel) return;

    final text = band.label ?? _bandFallbackLabel(band);
    final maxWidth = math.min(128.0, plot.width);
    final painter = _textPainter(
      text,
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.9,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: maxWidth,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + padding.horizontal;
    final height = painter.height + padding.vertical;
    final preferredX = axis == Axis.horizontal
        ? anchor.dx - width - 6
        : anchor.dx + 6;
    final preferredY = axis == Axis.horizontal ? anchor.dy + 4 : anchor.dy + 6;
    final x = _safeClamp(preferredX, plot.left + 2, plot.right - width - 2);
    final y = _safeClamp(preferredY, plot.top + 2, plot.bottom - height - 2);
    final rect = Rect.fromLTWH(x, y, width, height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = color.withValues(alpha: 0.14),
    );
    painter.paint(canvas, Offset(x + padding.left, y + padding.top));
  }

  String _bandFallbackLabel(SimpleChartReferenceBand band) {
    return '${valueFormatter(band.from)} - ${valueFormatter(band.to)}';
  }

  void _drawVerticalReferenceLines(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
  ) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final y = _yForValue(line.value, plot, range);
      if (y < plot.top - 1 || y > plot.bottom + 1) continue;

      final color = line.color ?? axisColor.withValues(alpha: 0.82);
      _drawStyledLine(
        canvas,
        Offset(plot.left, y),
        Offset(plot.right, y),
        _referencePaint(line, color),
        line.lineStyle,
      );
      _drawReferenceLabel(
        canvas,
        line,
        valueFormatter(line.value),
        Offset(plot.right, y),
        Axis.horizontal,
        plot,
        color,
      );
    }
  }

  void _drawHorizontalReferenceLines(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
  ) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final x = _xForValue(line.value, plot, range);
      if (x < plot.left - 1 || x > plot.right + 1) continue;

      final color = line.color ?? axisColor.withValues(alpha: 0.82);
      _drawStyledLine(
        canvas,
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        _referencePaint(line, color),
        line.lineStyle,
      );
      _drawReferenceLabel(
        canvas,
        line,
        valueFormatter(line.value),
        Offset(x, plot.top),
        Axis.vertical,
        plot,
        color,
      );
    }
  }

  Paint _referencePaint(SimpleChartReferenceLine line, Color color) {
    return Paint()
      ..color = color
      ..strokeWidth = line.strokeWidth
      ..strokeCap = line.lineStyle == SimpleChartReferenceLineStyle.dotted
          ? StrokeCap.round
          : StrokeCap.butt;
  }

  void _drawStyledLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    SimpleChartReferenceLineStyle style,
  ) {
    if (style == SimpleChartReferenceLineStyle.solid) {
      canvas.drawLine(start, end, paint);
      return;
    }

    final delta = end - start;
    final distance = delta.distance;
    if (distance <= 0) return;

    final direction = delta / distance;
    final dash = style == SimpleChartReferenceLineStyle.dotted ? 1.0 : 7.0;
    final gap = style == SimpleChartReferenceLineStyle.dotted ? 5.0 : 5.0;
    var traveled = 0.0;

    while (traveled < distance) {
      final next = math.min(traveled + dash, distance);
      canvas.drawLine(
        start + direction * traveled,
        start + direction * next,
        paint,
      );
      traveled = next + gap;
    }
  }

  void _drawReferenceLabel(
    Canvas canvas,
    SimpleChartReferenceLine line,
    String fallbackLabel,
    Offset anchor,
    Axis lineAxis,
    Rect plot,
    Color color,
  ) {
    if (!line.showLabel) return;

    final text = line.label ?? fallbackLabel;
    final painter = _textPainter(
      text,
      labelStyle.copyWith(
        color: color,
        fontSize: (labelStyle.fontSize ?? 12) * 0.92,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: math.min(112.0, plot.width),
      textAlign: TextAlign.center,
    )..layout(maxWidth: math.min(112.0, plot.width));
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + padding.horizontal;
    final height = painter.height + padding.vertical;
    final preferredX = lineAxis == Axis.horizontal
        ? anchor.dx - width - 6
        : anchor.dx + 6;
    final preferredY = lineAxis == Axis.horizontal
        ? anchor.dy - height - 4
        : anchor.dy + 4;
    final x = _safeClamp(preferredX, plot.left + 2, plot.right - width - 2);
    final y = _safeClamp(preferredY, plot.top + 2, plot.bottom - height - 2);
    final rect = Rect.fromLTWH(x, y, width, height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = color.withValues(alpha: 0.1),
    );
    painter.paint(canvas, Offset(x + padding.left, y + padding.top));
  }

  double _safeClamp(double value, double lower, double upper) {
    if (lower > upper) return lower;
    return value.clamp(lower, upper).toDouble();
  }

  void _drawVerticalBars(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
    double zeroY,
  ) {
    final segmentWidth = plot.width / data.length;
    final desiredBarWidth = math.max(4.0, segmentWidth * barWidthFactor);
    final barWidth = math.min(maxBarWidth, desiredBarWidth);

    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final x =
          plot.left + segmentWidth * index + (segmentWidth - barWidth) / 2;
      final targetY = _yForValue(item.value, plot, range);
      final animatedY = zeroY + (targetY - zeroY) * progress;
      final top = math.min(zeroY, animatedY);
      final bottom = math.max(zeroY, animatedY);
      final rect = Rect.fromLTRB(x, top, x + barWidth, bottom);

      if (showTrack) {
        _drawTrack(
          canvas,
          Rect.fromLTWH(x, plot.top, barWidth, plot.height),
          barWidth,
        );
      }

      if (rect.height <= 0.5) continue;

      canvas.drawRRect(
        _barRRect(rect, item.value, Axis.vertical),
        _barPaint(item.color ?? barColor, rect, item.value, Axis.vertical),
      );

      if (index == activeIndex) {
        _drawActiveBarIndicator(
          canvas,
          rect,
          item.value,
          Axis.vertical,
          item.color ?? barColor,
        );
      }

      if (showValues && segmentWidth >= 30) {
        _drawVerticalValue(canvas, item, rect, plot);
      }
    }
  }

  void _drawHorizontalBars(
    Canvas canvas,
    Rect plot,
    _ValueRange range,
    double zeroX,
  ) {
    final segmentHeight = plot.height / data.length;
    final desiredBarHeight = math.max(4.0, segmentHeight * barWidthFactor);
    final barHeight = math.min(maxBarWidth, desiredBarHeight);

    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final y =
          plot.top + segmentHeight * index + (segmentHeight - barHeight) / 2;
      final targetX = _xForValue(item.value, plot, range);
      final animatedX = zeroX + (targetX - zeroX) * progress;
      final left = math.min(zeroX, animatedX);
      final right = math.max(zeroX, animatedX);
      final rect = Rect.fromLTRB(left, y, right, y + barHeight);

      if (showTrack) {
        _drawTrack(
          canvas,
          Rect.fromLTWH(plot.left, y, plot.width, barHeight),
          barHeight,
        );
      }

      if (rect.width <= 0.5) continue;

      canvas.drawRRect(
        _barRRect(rect, item.value, Axis.horizontal),
        _barPaint(item.color ?? barColor, rect, item.value, Axis.horizontal),
      );

      if (index == activeIndex) {
        _drawActiveBarIndicator(
          canvas,
          rect,
          item.value,
          Axis.horizontal,
          item.color ?? barColor,
        );
      }

      if (showValues && segmentHeight >= 22) {
        _drawHorizontalValue(canvas, item, rect, plot);
      }
    }
  }

  void _drawActiveBarIndicator(
    Canvas canvas,
    Rect rect,
    double value,
    Axis axis,
    Color baseColor,
  ) {
    final color = activeBarColor ?? baseColor;
    canvas.drawRRect(
      _barRRect(rect.inflate(3), value, axis),
      Paint()..color = color.withValues(alpha: 0.14),
    );
    canvas.drawRRect(
      _barRRect(rect.inflate(1.4), value, axis),
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawTrack(Canvas canvas, Rect rect, double barThickness) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(math.min(barRadius, barThickness / 2)),
      ),
      Paint()..color = trackColor,
    );
  }

  Paint _barPaint(Color color, Rect rect, double value, Axis axis) {
    if (!useGradient) {
      return Paint()..color = color;
    }

    final vertical = axis == Axis.vertical;
    return Paint()
      ..shader = LinearGradient(
        begin: vertical
            ? (value >= 0 ? Alignment.topCenter : Alignment.bottomCenter)
            : (value >= 0 ? Alignment.centerRight : Alignment.centerLeft),
        end: vertical
            ? (value >= 0 ? Alignment.bottomCenter : Alignment.topCenter)
            : (value >= 0 ? Alignment.centerLeft : Alignment.centerRight),
        colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.72)],
      ).createShader(rect);
  }

  RRect _barRRect(Rect rect, double value, Axis axis) {
    final radius = Radius.circular(
      math.min(
        barRadius,
        axis == Axis.vertical ? rect.height / 2 : rect.width / 2,
      ),
    );

    if (axis == Axis.vertical) {
      if (value < 0) {
        return RRect.fromRectAndCorners(
          rect,
          bottomLeft: radius,
          bottomRight: radius,
        );
      }
      return RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius);
    }

    if (value < 0) {
      return RRect.fromRectAndCorners(
        rect,
        topLeft: radius,
        bottomLeft: radius,
      );
    }
    return RRect.fromRectAndCorners(
      rect,
      topRight: radius,
      bottomRight: radius,
    );
  }

  void _drawVerticalValue(
    Canvas canvas,
    SimpleBarChartData item,
    Rect bar,
    Rect plot,
  ) {
    final painter = _textPainter(valueFormatter(item.value), valueStyle)
      ..layout();
    final x = bar.center.dx - painter.width / 2;
    final preferredY = item.value >= 0
        ? bar.top - painter.height - 6
        : bar.bottom + 6;
    final y = _safeClamp(
      preferredY,
      plot.top + 2,
      plot.bottom - painter.height - 2,
    );
    painter.paint(canvas, Offset(x, y));
  }

  void _drawHorizontalValue(
    Canvas canvas,
    SimpleBarChartData item,
    Rect bar,
    Rect plot,
  ) {
    final painter = _textPainter(valueFormatter(item.value), valueStyle)
      ..layout();
    final preferredX = item.value >= 0
        ? bar.right + 6
        : bar.left - painter.width - 6;
    final x = _safeClamp(
      preferredX,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = bar.center.dy - painter.height / 2;
    painter.paint(canvas, Offset(x, y));
  }

  void _drawVerticalLabels(Canvas canvas, Rect plot) {
    final segmentWidth = plot.width / data.length;
    final maxLabelCount = math.max(1, plot.width / 48).floor();
    final labelEvery = math.max(1, (data.length / maxLabelCount).ceil());

    for (var index = 0; index < data.length; index++) {
      if (index % labelEvery != 0) continue;

      final item = data[index];
      final x = plot.left + segmentWidth * index + segmentWidth / 2;
      final maxWidth = math.max(18.0, segmentWidth * 0.92);
      final painter = _textPainter(
        item.label,
        labelStyle,
        maxWidth: maxWidth,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x - painter.width / 2, plot.bottom + 8));
    }
  }

  void _drawHorizontalLabels(Canvas canvas, Rect plot) {
    final segmentHeight = plot.height / data.length;
    final maxLabelCount = math.max(1, plot.height / 22).floor();
    final labelEvery = math.max(1, (data.length / maxLabelCount).ceil());
    final maxWidth = math.max(24.0, padding.left - 12);

    for (var index = 0; index < data.length; index++) {
      if (index % labelEvery != 0) continue;

      final item = data[index];
      final y = plot.top + segmentHeight * index + segmentHeight / 2;
      final painter = _textPainter(
        item.label,
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
  bool shouldRepaint(covariant _SimpleBarChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.orientation != orientation ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.barColor != barColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showTrack != showTrack ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.barWidthFactor != barWidthFactor ||
        oldDelegate.maxBarWidth != maxBarWidth ||
        oldDelegate.useGradient != useGradient ||
        oldDelegate.activeBarColor != activeBarColor ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _SimpleBarChartVisuals {
  final Color barColor;
  final Color gridColor;
  final Color axisColor;
  final Color trackColor;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;

  const _SimpleBarChartVisuals({
    required this.barColor,
    required this.gridColor,
    required this.axisColor,
    required this.trackColor,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
  });

  factory _SimpleBarChartVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleBarChartVisuals(
          barColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          trackColor: colorScheme.primary.withValues(alpha: 0.08),
          barRadius: 12,
          barWidthFactor: 0.6,
          maxBarWidth: 48,
          useGradient: true,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleBarChartVisuals(
          barColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          trackColor: colorScheme.outline.withValues(alpha: 0.08),
          barRadius: 4,
          barWidthFactor: 0.62,
          maxBarWidth: 40,
          useGradient: false,
        );
      case SimpleBarChartStyle.education:
        return _SimpleBarChartVisuals(
          barColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.65),
          trackColor: colorScheme.secondary.withValues(alpha: 0.09),
          barRadius: 6,
          barWidthFactor: 0.64,
          maxBarWidth: 44,
          useGradient: false,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleBarChartVisuals(
          barColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          trackColor: colorScheme.tertiary.withValues(alpha: 0.08),
          barRadius: 16,
          barWidthFactor: 0.58,
          maxBarWidth: 52,
          useGradient: true,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleBarChartVisuals(
          barColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          trackColor: colorScheme.primary.withValues(alpha: 0.07),
          barRadius: 8,
          barWidthFactor: 0.58,
          maxBarWidth: 44,
          useGradient: true,
        );
    }
  }
}

class _DefaultChartTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultChartTooltip({required this.title, required this.rows});

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
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onInverseSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: row.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        row.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onInverseSurface.withValues(
                            alpha: 0.78,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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

class _TooltipRow {
  final Color color;
  final String label;
  final String value;

  const _TooltipRow({
    required this.color,
    required this.label,
    required this.value,
  });
}

class _ValueRange {
  final double min;
  final double max;

  const _ValueRange(this.min, this.max);

  double get span => max - min;
}
