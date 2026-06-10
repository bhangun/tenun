import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../common/simple_chart_reference_line.dart';
import 'simple_bar_chart.dart';

/// A compact stacked bar chart for composition, allocation, and contribution.
class SimpleStackedBarChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(44, 18, 16, 34);

  final List<String> categories;
  final List<SimpleGroupedBarSeries> series;
  final SimpleStackedBarMode mode;
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
  final SimpleBarValueFormatter? shareFormatter;
  final SimpleStackedBarTapCallback? onBarTap;
  final SimpleStackedBarTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleStackedBarChart({
    super.key,
    required this.categories,
    required this.series,
    this.mode = SimpleStackedBarMode.absolute,
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
    this.shareFormatter,
    this.onBarTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 750),
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
    final visuals = _SimpleStackedBarVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .where((item) => item.values.any((value) => value.isFinite))
        .toList();
    final resolvedValueFormatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedShareFormatter = shareFormatter ?? _defaultShareFormatter;
    final chartFormatter = mode == SimpleStackedBarMode.percent
        ? resolvedShareFormatter
        : resolvedValueFormatter;

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
            emptySemanticLabel: 'Stacked bar chart, no data.',
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
            visibleSeries,
            resolvedValueFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleStackedBarChartView(
            width: width,
            height: chartHeight,
            categories: categories,
            series: visibleSeries,
            mode: mode,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals.palette),
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
            shareFormatter: resolvedShareFormatter,
            chartValueFormatter: chartFormatter,
            onBarTap: onBarTap,
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
    if (barColor == null) return defaults;
    return [barColor!, ...defaults.skip(1)];
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
      var total = 0.0;
      for (final item in visibleSeries) {
        if (categoryIndex >= item.values.length) continue;
        final value = item.values[categoryIndex];
        if (value.isFinite) total += value;
      }
      summaries.add('${categories[categoryIndex]} total ${formatter(total)}');
    }
    final remainingCategories = categories.length - categoryLimit;
    final suffix = remainingCategories > 0
        ? '; and $remainingCategories more categories'
        : '';
    return 'Stacked bar chart, ${visibleSeries.length} series across '
        '${categories.length} categories. ${summaries.join('; ')}$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultShareFormatter(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}%';
    }
    return '${value.toStringAsFixed(1)}%';
  }
}

class _SimpleStackedBarChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<String> categories;
  final List<SimpleGroupedBarSeries> series;
  final SimpleStackedBarMode mode;
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
  final SimpleBarValueFormatter shareFormatter;
  final SimpleBarValueFormatter chartValueFormatter;
  final SimpleStackedBarTapCallback? onBarTap;
  final SimpleStackedBarTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleStackedBarChartView({
    required this.width,
    required this.height,
    required this.categories,
    required this.series,
    required this.mode,
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
    required this.shareFormatter,
    required this.chartValueFormatter,
    required this.onBarTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleStackedBarChartView> createState() =>
      _SimpleStackedBarChartViewState();
}

class _SimpleStackedBarChartViewState
    extends State<_SimpleStackedBarChartView> {
  _StackedBarSelection? _active;

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
                      painter: _SimpleStackedBarChartPainter(
                        categories: widget.categories,
                        series: widget.series,
                        mode: widget.mode,
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
                        chartValueFormatter: widget.chartValueFormatter,
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

                            final segment = _segmentFor(selection, size);
                            if (segment == null) return;
                            widget.onBarTap?.call(
                              widget.categories[selection.categoryIndex],
                              widget.series[selection.seriesIndex],
                              segment.value,
                              segment.share,
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

  void _setActive(_StackedBarSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _StackedBarSelection? _hitTest(Offset position, Size size) {
    final plot = _plot(size);
    if (!plot.inflate(8).contains(position)) return null;

    final categoryWidth = plot.width / widget.categories.length;
    final categoryIndex = ((position.dx - plot.left) / categoryWidth).floor();
    if (categoryIndex < 0 || categoryIndex >= widget.categories.length) {
      return null;
    }

    final barWidth = _barWidth(plot);
    final barLeft =
        plot.left +
        categoryWidth * categoryIndex +
        (categoryWidth - barWidth) / 2;
    if (position.dx < barLeft - 4 || position.dx > barLeft + barWidth + 4) {
      return null;
    }

    final range = _resolveRange();
    final zeroY = _yForValue(
      0,
      plot,
      range,
    ).clamp(plot.top, plot.bottom).toDouble();
    final segments = _segmentsForCategory(categoryIndex, plot, range, zeroY, 1);
    for (final segment in segments.reversed) {
      if (segment.rect.inflate(2).contains(position)) {
        return _StackedBarSelection(categoryIndex, segment.seriesIndex);
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _StackedBarSelection selection,
  ) {
    final segment = _segmentFor(selection, size);
    if (segment == null) return const SizedBox.shrink();

    final category = widget.categories[selection.categoryIndex];
    final selectedSeries = widget.series[selection.seriesIndex];
    final formattedValue = widget.valueFormatter(segment.value);
    final formattedShare = widget.shareFormatter(segment.share);
    const tooltipWidth = 184.0;
    const tooltipHeight = 60.0;
    final left = (segment.rect.center.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (segment.rect.top - tooltipHeight - 8)
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
            segment.value,
            segment.share,
            selection.categoryIndex,
            selection.seriesIndex,
            formattedValue,
            formattedShare,
          ) ??
          _DefaultStackedBarTooltip(
            title: category,
            rows: [
              _StackedTooltipRow(
                color: segment.color,
                label: selectedSeries.name,
                value: widget.mode == SimpleStackedBarMode.percent
                    ? '$formattedValue / $formattedShare'
                    : formattedValue,
              ),
            ],
          ),
    );
  }

  _StackedBarSegment? _segmentFor(_StackedBarSelection selection, Size size) {
    final plot = _plot(size);
    final range = _resolveRange();
    final zeroY = _yForValue(
      0,
      plot,
      range,
    ).clamp(plot.top, plot.bottom).toDouble();
    final segments = _segmentsForCategory(
      selection.categoryIndex,
      plot,
      range,
      zeroY,
      1,
    );
    for (final segment in segments) {
      if (segment.seriesIndex == selection.seriesIndex) return segment;
    }
    return null;
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

  List<_StackedBarSegment> _segmentsForCategory(
    int categoryIndex,
    Rect plot,
    _StackedValueRange range,
    double zeroY,
    double progress,
  ) {
    final chartValues = <double>[];
    for (
      var seriesIndex = 0;
      seriesIndex < widget.series.length;
      seriesIndex++
    ) {
      final item = widget.series[seriesIndex];
      if (categoryIndex >= item.values.length) {
        chartValues.add(double.nan);
        continue;
      }
      final value = item.values[categoryIndex];
      chartValues.add(
        value.isFinite ? _chartValue(value, categoryIndex) : double.nan,
      );
    }

    final positiveLast = _lastIndexWhere(chartValues, (value) => value >= 0);
    final negativeLast = _lastIndexWhere(chartValues, (value) => value < 0);
    final categoryWidth = plot.width / widget.categories.length;
    final barWidth = _barWidth(plot);
    final x =
        plot.left +
        categoryWidth * categoryIndex +
        (categoryWidth - barWidth) / 2;
    var positiveBase = 0.0;
    var negativeBase = 0.0;
    final segments = <_StackedBarSegment>[];

    for (
      var seriesIndex = 0;
      seriesIndex < widget.series.length;
      seriesIndex++
    ) {
      final item = widget.series[seriesIndex];
      if (categoryIndex >= item.values.length) continue;
      final value = item.values[categoryIndex];
      final chartValue = chartValues[seriesIndex];
      if (!value.isFinite || !chartValue.isFinite || chartValue == 0) continue;

      final start = chartValue >= 0 ? positiveBase : negativeBase;
      final end = start + chartValue;
      if (chartValue >= 0) {
        positiveBase = end;
      } else {
        negativeBase = end;
      }

      final animatedStart = start * progress;
      final animatedEnd = end * progress;
      final startY = _yForValue(animatedStart, plot, range);
      final endY = _yForValue(animatedEnd, plot, range);
      final rect = Rect.fromLTRB(
        x,
        math.min(startY, endY),
        x + barWidth,
        math.max(startY, endY),
      );
      if (rect.height <= 0.5) continue;

      segments.add(
        _StackedBarSegment(
          categoryIndex: categoryIndex,
          seriesIndex: seriesIndex,
          value: value,
          chartValue: chartValue,
          share: _share(value, categoryIndex),
          rect: rect,
          color: _seriesColor(seriesIndex),
          roundTop: chartValue >= 0 && seriesIndex == positiveLast,
          roundBottom: chartValue < 0 && seriesIndex == negativeLast,
        ),
      );
    }

    return segments;
  }

  int _lastIndexWhere(List<double> values, bool Function(double value) test) {
    for (var index = values.length - 1; index >= 0; index--) {
      final value = values[index];
      if (value.isFinite && value != 0 && test(value)) return index;
    }
    return -1;
  }

  double _barWidth(Rect plot) {
    final categoryWidth = plot.width / widget.categories.length;
    return math.min(
      widget.maxBarWidth,
      math.max(4.0, categoryWidth * widget.barWidthFactor),
    );
  }

  double _categoryTotal(int categoryIndex) {
    var total = 0.0;
    for (final item in widget.series) {
      if (categoryIndex >= item.values.length) continue;
      final value = item.values[categoryIndex];
      if (value.isFinite) total += value.abs();
    }
    return total;
  }

  double _share(double value, int categoryIndex) {
    final total = _categoryTotal(categoryIndex);
    if (total <= 0) return 0;
    return value / total * 100;
  }

  double _chartValue(double value, int categoryIndex) {
    return widget.mode == SimpleStackedBarMode.percent
        ? _share(value, categoryIndex)
        : value;
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

  _StackedValueRange _resolveRange() {
    return _resolveStackedRange(
      categories: widget.categories,
      series: widget.series,
      mode: widget.mode,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
    );
  }

  double _yForValue(double value, Rect plot, _StackedValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }
}

class _SimpleStackedBarChartPainter extends CustomPainter {
  final List<String> categories;
  final List<SimpleGroupedBarSeries> series;
  final SimpleStackedBarMode mode;
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
  final _StackedBarSelection? activeSelection;
  final SimpleBarValueFormatter valueFormatter;
  final SimpleBarValueFormatter chartValueFormatter;
  final double progress;

  const _SimpleStackedBarChartPainter({
    required this.categories,
    required this.series,
    required this.mode,
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
    required this.chartValueFormatter,
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
    _drawStacks(canvas, plot, range, zeroY);
    _drawLabels(canvas, plot);
  }

  _StackedValueRange _resolveRange() {
    return _resolveStackedRange(
      categories: categories,
      series: series,
      mode: mode,
      minValue: minValue,
      maxValue: maxValue,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
  }

  double _yForValue(double value, Rect plot, _StackedValueRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.bottom - normalized * plot.height;
  }

  void _drawGrid(Canvas canvas, Rect plot, _StackedValueRange range) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var index = 0; index <= gridLineCount; index++) {
      final value = range.min + range.span * (index / gridLineCount);
      final y = _yForValue(value, plot, range);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);

      final painter = _textPainter(
        chartValueFormatter(value),
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

  void _drawReferenceBands(Canvas canvas, Rect plot, _StackedValueRange range) {
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
        '${chartValueFormatter(band.from)} - ${chartValueFormatter(band.to)}';
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
    const labelPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + labelPadding.horizontal;
    final height = painter.height + labelPadding.vertical;
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
    painter.paint(canvas, Offset(x + labelPadding.left, y + labelPadding.top));
  }

  void _drawReferenceLines(Canvas canvas, Rect plot, _StackedValueRange range) {
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
        chartValueFormatter(line.value),
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
    const labelPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final width = painter.width + labelPadding.horizontal;
    final height = painter.height + labelPadding.vertical;
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
    painter.paint(canvas, Offset(x + labelPadding.left, y + labelPadding.top));
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

  void _drawStacks(
    Canvas canvas,
    Rect plot,
    _StackedValueRange range,
    double zeroY,
  ) {
    for (
      var categoryIndex = 0;
      categoryIndex < categories.length;
      categoryIndex++
    ) {
      final segments = _segmentsForCategory(
        categoryIndex,
        plot,
        range,
        zeroY,
        progress,
      );

      for (final segment in segments) {
        canvas.drawRRect(
          _segmentRRect(segment),
          _barPaint(segment.color, segment.rect, segment.chartValue),
        );

        if (activeSelection ==
            _StackedBarSelection(categoryIndex, segment.seriesIndex)) {
          _drawActiveSegment(canvas, segment);
        }

        if (showValues) {
          _drawSegmentValue(canvas, segment, plot);
        }
      }
    }
  }

  List<_StackedBarSegment> _segmentsForCategory(
    int categoryIndex,
    Rect plot,
    _StackedValueRange range,
    double zeroY,
    double progress,
  ) {
    final chartValues = <double>[];
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final item = series[seriesIndex];
      if (categoryIndex >= item.values.length) {
        chartValues.add(double.nan);
        continue;
      }
      final value = item.values[categoryIndex];
      chartValues.add(
        value.isFinite ? _chartValue(value, categoryIndex) : double.nan,
      );
    }

    final positiveLast = _lastIndexWhere(chartValues, (value) => value >= 0);
    final negativeLast = _lastIndexWhere(chartValues, (value) => value < 0);
    final categoryWidth = plot.width / categories.length;
    final barWidth = _barWidth(plot);
    final x =
        plot.left +
        categoryWidth * categoryIndex +
        (categoryWidth - barWidth) / 2;
    var positiveBase = 0.0;
    var negativeBase = 0.0;
    final segments = <_StackedBarSegment>[];

    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final item = series[seriesIndex];
      if (categoryIndex >= item.values.length) continue;
      final value = item.values[categoryIndex];
      final chartValue = chartValues[seriesIndex];
      if (!value.isFinite || !chartValue.isFinite || chartValue == 0) continue;

      final start = chartValue >= 0 ? positiveBase : negativeBase;
      final end = start + chartValue;
      if (chartValue >= 0) {
        positiveBase = end;
      } else {
        negativeBase = end;
      }

      final animatedStart = start * progress;
      final animatedEnd = end * progress;
      final startY = _yForValue(animatedStart, plot, range);
      final endY = _yForValue(animatedEnd, plot, range);
      final rect = Rect.fromLTRB(
        x,
        math.min(startY, endY),
        x + barWidth,
        math.max(startY, endY),
      );
      if (rect.height <= 0.5) continue;

      segments.add(
        _StackedBarSegment(
          categoryIndex: categoryIndex,
          seriesIndex: seriesIndex,
          value: value,
          chartValue: chartValue,
          share: _share(value, categoryIndex),
          rect: rect,
          color: _seriesColor(seriesIndex),
          roundTop: chartValue >= 0 && seriesIndex == positiveLast,
          roundBottom: chartValue < 0 && seriesIndex == negativeLast,
        ),
      );
    }

    return segments;
  }

  int _lastIndexWhere(List<double> values, bool Function(double value) test) {
    for (var index = values.length - 1; index >= 0; index--) {
      final value = values[index];
      if (value.isFinite && value != 0 && test(value)) return index;
    }
    return -1;
  }

  double _barWidth(Rect plot) {
    final categoryWidth = plot.width / categories.length;
    return math.min(maxBarWidth, math.max(4.0, categoryWidth * barWidthFactor));
  }

  Paint _barPaint(Color color, Rect rect, double value) {
    if (!useGradient) return Paint()..color = color;

    return Paint()
      ..shader = LinearGradient(
        begin: value >= 0 ? Alignment.topCenter : Alignment.bottomCenter,
        end: value >= 0 ? Alignment.bottomCenter : Alignment.topCenter,
        colors: [color.withValues(alpha: 0.96), color.withValues(alpha: 0.76)],
      ).createShader(rect);
  }

  RRect _segmentRRect(_StackedBarSegment segment) {
    final rect = segment.rect;
    final radius = Radius.circular(
      math.min(barRadius, math.min(rect.width, rect.height) / 2),
    );
    return RRect.fromRectAndCorners(
      rect,
      topLeft: segment.roundTop ? radius : Radius.zero,
      topRight: segment.roundTop ? radius : Radius.zero,
      bottomLeft: segment.roundBottom ? radius : Radius.zero,
      bottomRight: segment.roundBottom ? radius : Radius.zero,
    );
  }

  void _drawActiveSegment(Canvas canvas, _StackedBarSegment segment) {
    final color = activeBarColor ?? segment.color;
    final inflated = segment.copyWith(rect: segment.rect.inflate(2.4));
    canvas.drawRRect(
      _segmentRRect(inflated),
      Paint()..color = color.withValues(alpha: 0.14),
    );
    canvas.drawRRect(
      _segmentRRect(segment.copyWith(rect: segment.rect.inflate(1.2))),
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawSegmentValue(Canvas canvas, _StackedBarSegment segment, Rect plot) {
    if (segment.rect.height < 18 || segment.rect.width < 22) return;

    final text = mode == SimpleStackedBarMode.percent
        ? chartValueFormatter(segment.share)
        : valueFormatter(segment.value);
    final textColor = segment.color.computeLuminance() > 0.58
        ? Colors.black.withValues(alpha: 0.76)
        : Colors.white.withValues(alpha: 0.92);
    final painter = _textPainter(
      text,
      valueStyle.copyWith(color: textColor),
      maxWidth: segment.rect.width - 4,
      textAlign: TextAlign.center,
    )..layout(maxWidth: segment.rect.width - 4);
    if (painter.height > segment.rect.height - 2) return;

    final x = _safeClamp(
      segment.rect.center.dx - painter.width / 2,
      plot.left + 2,
      plot.right - painter.width - 2,
    );
    final y = segment.rect.center.dy - painter.height / 2;
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

  double _categoryTotal(int categoryIndex) {
    var total = 0.0;
    for (final item in series) {
      if (categoryIndex >= item.values.length) continue;
      final value = item.values[categoryIndex];
      if (value.isFinite) total += value.abs();
    }
    return total;
  }

  double _share(double value, int categoryIndex) {
    final total = _categoryTotal(categoryIndex);
    if (total <= 0) return 0;
    return value / total * 100;
  }

  double _chartValue(double value, int categoryIndex) {
    return mode == SimpleStackedBarMode.percent
        ? _share(value, categoryIndex)
        : value;
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
  bool shouldRepaint(covariant _SimpleStackedBarChartPainter oldDelegate) {
    return oldDelegate.categories != categories ||
        oldDelegate.series != series ||
        oldDelegate.mode != mode ||
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
        oldDelegate.chartValueFormatter != chartValueFormatter ||
        oldDelegate.progress != progress;
  }
}

_StackedValueRange _resolveStackedRange({
  required List<String> categories,
  required List<SimpleGroupedBarSeries> series,
  required SimpleStackedBarMode mode,
  required double? minValue,
  required double? maxValue,
  required List<SimpleChartReferenceLine> referenceLines,
  required List<SimpleChartReferenceBand> referenceBands,
}) {
  var lower = double.infinity;
  var upper = double.negativeInfinity;

  if (mode == SimpleStackedBarMode.percent) {
    lower = 0;
    upper = 100;
    var hasNegative = false;
    for (
      var categoryIndex = 0;
      categoryIndex < categories.length;
      categoryIndex++
    ) {
      for (final item in series) {
        if (categoryIndex >= item.values.length) continue;
        final value = item.values[categoryIndex];
        if (value.isFinite && value < 0) hasNegative = true;
      }
    }
    if (hasNegative) lower = -100;
  } else {
    for (
      var categoryIndex = 0;
      categoryIndex < categories.length;
      categoryIndex++
    ) {
      var positive = 0.0;
      var negative = 0.0;
      for (final item in series) {
        if (categoryIndex >= item.values.length) continue;
        final value = item.values[categoryIndex];
        if (!value.isFinite) continue;
        if (value >= 0) {
          positive += value;
        } else {
          negative += value;
        }
      }
      lower = math.min(lower, negative);
      upper = math.max(upper, positive);
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
  } else if (mode == SimpleStackedBarMode.absolute) {
    final pad = (upper - lower).abs() * 0.06;
    lower -= pad;
    upper += pad;
  }

  return _StackedValueRange(lower, upper);
}

class _SimpleStackedBarVisuals {
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarWidth;
  final bool useGradient;

  const _SimpleStackedBarVisuals({
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarWidth,
    required this.useGradient,
  });

  factory _SimpleStackedBarVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    final palette = [
      colorScheme.primary,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];

    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleStackedBarVisuals(
          palette: palette,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          barRadius: 12,
          barWidthFactor: 0.62,
          maxBarWidth: 58,
          useGradient: true,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleStackedBarVisuals(
          palette: palette,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          barRadius: 4,
          barWidthFactor: 0.64,
          maxBarWidth: 48,
          useGradient: false,
        );
      case SimpleBarChartStyle.education:
        return _SimpleStackedBarVisuals(
          palette: [colorScheme.secondary, ...palette],
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.65),
          barRadius: 6,
          barWidthFactor: 0.66,
          maxBarWidth: 52,
          useGradient: false,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleStackedBarVisuals(
          palette: [colorScheme.tertiary, ...palette],
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.45),
          barRadius: 16,
          barWidthFactor: 0.6,
          maxBarWidth: 62,
          useGradient: true,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleStackedBarVisuals(
          palette: palette,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          barRadius: 8,
          barWidthFactor: 0.6,
          maxBarWidth: 54,
          useGradient: true,
        );
    }
  }
}

class _DefaultStackedBarTooltip extends StatelessWidget {
  final String title;
  final List<_StackedTooltipRow> rows;

  const _DefaultStackedBarTooltip({required this.title, required this.rows});

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
                        borderRadius: BorderRadius.circular(2),
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

class _StackedTooltipRow {
  final Color color;
  final String label;
  final String value;

  const _StackedTooltipRow({
    required this.color,
    required this.label,
    required this.value,
  });
}

class _StackedBarSelection {
  final int categoryIndex;
  final int seriesIndex;

  const _StackedBarSelection(this.categoryIndex, this.seriesIndex);

  @override
  bool operator ==(Object other) {
    return other is _StackedBarSelection &&
        other.categoryIndex == categoryIndex &&
        other.seriesIndex == seriesIndex;
  }

  @override
  int get hashCode => Object.hash(categoryIndex, seriesIndex);
}

class _StackedBarSegment {
  final int categoryIndex;
  final int seriesIndex;
  final double value;
  final double chartValue;
  final double share;
  final Rect rect;
  final Color color;
  final bool roundTop;
  final bool roundBottom;

  const _StackedBarSegment({
    required this.categoryIndex,
    required this.seriesIndex,
    required this.value,
    required this.chartValue,
    required this.share,
    required this.rect,
    required this.color,
    required this.roundTop,
    required this.roundBottom,
  });

  _StackedBarSegment copyWith({Rect? rect}) {
    return _StackedBarSegment(
      categoryIndex: categoryIndex,
      seriesIndex: seriesIndex,
      value: value,
      chartValue: chartValue,
      share: share,
      rect: rect ?? this.rect,
      color: color,
      roundTop: roundTop,
      roundBottom: roundBottom,
    );
  }
}

class _StackedValueRange {
  final double min;
  final double max;

  const _StackedValueRange(this.min, this.max);

  double get span => max - min;
}
