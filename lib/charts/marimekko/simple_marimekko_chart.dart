import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleMarimekkoValueFormatter = String Function(double value);
typedef SimpleMarimekkoTapCallback =
    void Function(
      String category,
      SimpleMarimekkoSeries series,
      double value,
      double share,
      int categoryIndex,
      int seriesIndex,
    );
typedef SimpleMarimekkoTooltipBuilder =
    Widget Function(
      BuildContext context,
      String category,
      SimpleMarimekkoSeries series,
      double value,
      double share,
      int categoryIndex,
      int seriesIndex,
      String formattedValue,
      String formattedShare,
    );

class SimpleMarimekkoSeries {
  final String name;
  final List<double> values;
  final Color? color;

  const SimpleMarimekkoSeries({
    required this.name,
    required this.values,
    this.color,
  });
}

/// A compact Marimekko chart for showing both category size and composition.
class SimpleMarimekkoChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 18, 18, 42);

  final List<String> categories;
  final List<SimpleMarimekkoSeries> series;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? segmentColor;
  final Color? borderColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showPercentages;
  final bool showSegmentLabels;
  final bool showCategoryLabels;
  final bool showColumnTotals;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSegment;
  final double columnGap;
  final double segmentGap;
  final double segmentRadius;
  final SimpleMarimekkoValueFormatter? valueFormatter;
  final SimpleMarimekkoValueFormatter? shareFormatter;
  final SimpleMarimekkoTapCallback? onSegmentTap;
  final SimpleMarimekkoTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleMarimekkoChart({
    super.key,
    required this.categories,
    required this.series,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.segmentColor,
    this.borderColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showPercentages = true,
    this.showSegmentLabels = true,
    this.showCategoryLabels = true,
    this.showColumnTotals = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveSegment = true,
    this.columnGap = 5,
    this.segmentGap = 2,
    this.segmentRadius = 4,
    this.valueFormatter,
    this.shareFormatter,
    this.onSegmentTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 750),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(columnGap >= 0),
       assert(segmentGap >= 0),
       assert(segmentRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleMarimekkoVisuals.resolve(style, colorScheme);
    final visibleCategories = categories
        .where((category) => category.trim().isNotEmpty)
        .toList();
    final visibleSeries = series
        .where(
          (item) => item.values.any((value) => value.isFinite && value >= 0),
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedShareFormatter = shareFormatter ?? _defaultShareFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        final model = _MarimekkoModel.resolve(
          categories: visibleCategories,
          series: visibleSeries,
        );
        if (model.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Marimekko chart, no data.',
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
          child: _SimpleMarimekkoChartView(
            width: width,
            height: chartHeight,
            model: model,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals.palette),
            borderColor: borderColor ?? visuals.borderColor,
            gridColor: gridColor ?? visuals.gridColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showPercentages: showPercentages,
            showSegmentLabels: showSegmentLabels,
            showCategoryLabels: showCategoryLabels,
            showColumnTotals: showColumnTotals,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveSegment: showActiveSegment,
            columnGap: columnGap,
            segmentGap: segmentGap,
            segmentRadius: segmentRadius,
            valueFormatter: formatter,
            shareFormatter: resolvedShareFormatter,
            onSegmentTap: onSegmentTap,
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
    if (segmentColor == null) return defaults;
    return [
      segmentColor!,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
  }

  String _defaultSemanticLabel(
    _MarimekkoModel model,
    SimpleMarimekkoValueFormatter formatter,
  ) {
    final summaries = <String>[];
    final categoryLimit = math.min(model.categories.length, 4);
    for (
      var categoryIndex = 0;
      categoryIndex < categoryLimit;
      categoryIndex++
    ) {
      summaries.add(
        '${model.categories[categoryIndex]} total '
        '${formatter(model.categoryTotals[categoryIndex])}',
      );
    }
    final suffix = model.categories.length > categoryLimit
        ? '; and ${model.categories.length - categoryLimit} more categories'
        : '';
    return 'Marimekko chart, ${model.categories.length} categories and '
        '${model.series.length} series. ${summaries.join('; ')}$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultShareFormatter(double value) {
    final percent = value * 100;
    if (percent == percent.roundToDouble()) {
      return '${percent.toInt()}%';
    }
    return '${percent.toStringAsFixed(1)}%';
  }
}

class _SimpleMarimekkoChartView extends StatefulWidget {
  final double width;
  final double height;
  final _MarimekkoModel model;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color borderColor;
  final Color gridColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showPercentages;
  final bool showSegmentLabels;
  final bool showCategoryLabels;
  final bool showColumnTotals;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSegment;
  final double columnGap;
  final double segmentGap;
  final double segmentRadius;
  final SimpleMarimekkoValueFormatter valueFormatter;
  final SimpleMarimekkoValueFormatter shareFormatter;
  final SimpleMarimekkoTapCallback? onSegmentTap;
  final SimpleMarimekkoTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleMarimekkoChartView({
    required this.width,
    required this.height,
    required this.model,
    required this.padding,
    required this.palette,
    required this.borderColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showPercentages,
    required this.showSegmentLabels,
    required this.showCategoryLabels,
    required this.showColumnTotals,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveSegment,
    required this.columnGap,
    required this.segmentGap,
    required this.segmentRadius,
    required this.valueFormatter,
    required this.shareFormatter,
    required this.onSegmentTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleMarimekkoChartView> createState() =>
      _SimpleMarimekkoChartViewState();
}

class _SimpleMarimekkoChartViewState extends State<_SimpleMarimekkoChartView> {
  _MarimekkoSelection? _active;

  @override
  Widget build(BuildContext context) {
    final hasLegend = widget.showLegend && widget.model.series.length > 1;
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveSegment ||
        widget.onSegmentTap != null;

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
                      painter: _SimpleMarimekkoPainter(
                        model: widget.model,
                        padding: widget.padding,
                        palette: widget.palette,
                        borderColor: widget.borderColor,
                        gridColor: widget.gridColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showValues: widget.showValues,
                        showPercentages: widget.showPercentages,
                        showSegmentLabels: widget.showSegmentLabels,
                        showCategoryLabels: widget.showCategoryLabels,
                        showColumnTotals: widget.showColumnTotals,
                        showActiveSegment: widget.showActiveSegment,
                        columnGap: widget.columnGap,
                        segmentGap: widget.segmentGap,
                        segmentRadius: widget.segmentRadius,
                        activeSelection: _active,
                        valueFormatter: widget.valueFormatter,
                        shareFormatter: widget.shareFormatter,
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
                            final series =
                                widget.model.series[selection.seriesIndex];
                            final category = widget
                                .model
                                .categories[selection.categoryIndex];
                            final value = widget.model.valueAt(
                              selection.categoryIndex,
                              selection.seriesIndex,
                            );
                            final share = widget.model.shareAt(
                              selection.categoryIndex,
                              selection.seriesIndex,
                            );
                            widget.onSegmentTap?.call(
                              category,
                              series,
                              value,
                              share,
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

  void _setActive(_MarimekkoSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _MarimekkoSelection? _hitTest(Offset position, Size size) {
    final layout = _MarimekkoLayout.resolve(
      size: size,
      model: widget.model,
      padding: widget.padding,
      columnGap: widget.columnGap,
      segmentGap: widget.segmentGap,
    );
    for (final segment in layout.segments) {
      if (segment.rect
          .inflate(math.max(2, widget.segmentGap))
          .contains(position)) {
        return _MarimekkoSelection(segment.categoryIndex, segment.seriesIndex);
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _MarimekkoSelection selection,
  ) {
    final layout = _MarimekkoLayout.resolve(
      size: size,
      model: widget.model,
      padding: widget.padding,
      columnGap: widget.columnGap,
      segmentGap: widget.segmentGap,
    );
    final segment = layout.segmentFor(selection);
    final category = widget.model.categories[selection.categoryIndex];
    final series = widget.model.series[selection.seriesIndex];
    final value = widget.model.valueAt(
      selection.categoryIndex,
      selection.seriesIndex,
    );
    final share = widget.model.shareAt(
      selection.categoryIndex,
      selection.seriesIndex,
    );
    final formattedValue = widget.valueFormatter(value);
    final formattedShare = widget.shareFormatter(share);
    final anchor =
        segment?.rect.center ?? Offset(size.width / 2, size.height / 2);
    const tooltipWidth = 184.0;
    const tooltipHeight = 76.0;
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
            series,
            value,
            share,
            selection.categoryIndex,
            selection.seriesIndex,
            formattedValue,
            formattedShare,
          ) ??
          _DefaultMarimekkoTooltip(
            color: _seriesColor(series, selection.seriesIndex),
            title: category,
            label: series.name,
            value: formattedValue,
            share: formattedShare,
          ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          for (var index = 0; index < widget.model.series.length; index++)
            _MarimekkoLegendItem(
              label: widget.model.series[index].name,
              color: _seriesColor(widget.model.series[index], index),
              textStyle: widget.labelStyle,
            ),
        ],
      ),
    );
  }

  Color _seriesColor(SimpleMarimekkoSeries item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleMarimekkoPainter extends CustomPainter {
  final _MarimekkoModel model;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color borderColor;
  final Color gridColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showPercentages;
  final bool showSegmentLabels;
  final bool showCategoryLabels;
  final bool showColumnTotals;
  final bool showActiveSegment;
  final double columnGap;
  final double segmentGap;
  final double segmentRadius;
  final _MarimekkoSelection? activeSelection;
  final SimpleMarimekkoValueFormatter valueFormatter;
  final SimpleMarimekkoValueFormatter shareFormatter;
  final double progress;

  const _SimpleMarimekkoPainter({
    required this.model,
    required this.padding,
    required this.palette,
    required this.borderColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showPercentages,
    required this.showSegmentLabels,
    required this.showCategoryLabels,
    required this.showColumnTotals,
    required this.showActiveSegment,
    required this.columnGap,
    required this.segmentGap,
    required this.segmentRadius,
    required this.activeSelection,
    required this.valueFormatter,
    required this.shareFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _MarimekkoLayout.resolve(
      size: size,
      model: model,
      padding: padding,
      columnGap: columnGap,
      segmentGap: segmentGap,
    );
    if (layout.plot.isEmpty || layout.segments.isEmpty) return;

    if (showGrid) _drawGrid(canvas, layout);
    _drawSegments(canvas, layout);
    if (showCategoryLabels) _drawCategoryLabels(canvas, layout);
    if (showColumnTotals) _drawColumnTotals(canvas, layout);
  }

  void _drawGrid(Canvas canvas, _MarimekkoLayout layout) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawRect(layout.plot, paint..style = PaintingStyle.stroke);
    for (final column in layout.columns) {
      canvas.drawLine(
        Offset(column.rect.left, layout.plot.top),
        Offset(column.rect.left, layout.plot.bottom),
        paint,
      );
      canvas.drawLine(
        Offset(column.rect.right, layout.plot.top),
        Offset(column.rect.right, layout.plot.bottom),
        paint,
      );
    }
  }

  void _drawSegments(Canvas canvas, _MarimekkoLayout layout) {
    for (final segment in layout.segments) {
      final series = model.series[segment.seriesIndex];
      final color =
          series.color ?? palette[segment.seriesIndex % palette.length];
      final rect = _animatedRect(segment.rect);
      if (rect.width <= 0.5 || rect.height <= 0.5) continue;
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(math.min(segmentRadius, rect.shortestSide / 2)),
      );
      canvas.drawRRect(rrect, Paint()..color = color);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      if (showActiveSegment &&
          activeSelection?.categoryIndex == segment.categoryIndex &&
          activeSelection?.seriesIndex == segment.seriesIndex) {
        final highlight = activeColor ?? color;
        canvas.drawRRect(
          rrect.inflate(3),
          Paint()..color = highlight.withValues(alpha: 0.14),
        );
        canvas.drawRRect(
          rrect.inflate(1.4),
          Paint()
            ..color = highlight.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      _drawSegmentText(canvas, rect, segment, color);
    }
  }

  Rect _animatedRect(Rect rect) {
    final height = rect.height * progress;
    return Rect.fromLTRB(
      rect.left,
      rect.bottom - height,
      rect.right,
      rect.bottom,
    );
  }

  void _drawSegmentText(
    Canvas canvas,
    Rect rect,
    _MarimekkoSegmentLayout segment,
    Color color,
  ) {
    if (progress < 0.65) return;
    if (!showValues && !showPercentages && !showSegmentLabels) return;
    if (rect.width < 42 || rect.height < 22) return;

    final textColor = color.computeLuminance() > 0.54
        ? Colors.black.withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.94);
    final value = model.valueAt(segment.categoryIndex, segment.seriesIndex);
    final share = model.shareAt(segment.categoryIndex, segment.seriesIndex);
    final parts = <String>[
      if (showSegmentLabels) model.series[segment.seriesIndex].name,
      if (showValues) valueFormatter(value),
      if (showPercentages) shareFormatter(share),
    ];
    final painter = TextPainter(
      text: TextSpan(
        text: parts.join('  '),
        style: valueStyle.copyWith(color: textColor),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: rect.height > 40 ? 2 : 1,
      ellipsis: '...',
    )..layout(maxWidth: math.max(0.0, rect.width - 10));

    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  void _drawCategoryLabels(Canvas canvas, _MarimekkoLayout layout) {
    for (final column in layout.columns) {
      _paintText(
        canvas,
        model.categories[column.categoryIndex],
        labelStyle,
        Offset(column.rect.center.dx, layout.plot.bottom + 8),
        TextAlign.center,
        math.max(0.0, column.rect.width - 4),
      );
    }
  }

  void _drawColumnTotals(Canvas canvas, _MarimekkoLayout layout) {
    for (final column in layout.columns) {
      _paintText(
        canvas,
        valueFormatter(model.categoryTotals[column.categoryIndex]),
        valueStyle,
        Offset(column.rect.center.dx, layout.plot.top - 16),
        TextAlign.center,
        math.max(0.0, column.rect.width - 4),
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset anchor,
    TextAlign align,
    double maxWidth,
  ) {
    if (maxWidth <= 0) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.center => anchor.dx - painter.width / 2,
      _ => anchor.dx,
    };
    painter.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _SimpleMarimekkoPainter oldDelegate) {
    return oldDelegate.model != model ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showPercentages != showPercentages ||
        oldDelegate.showSegmentLabels != showSegmentLabels ||
        oldDelegate.showCategoryLabels != showCategoryLabels ||
        oldDelegate.showColumnTotals != showColumnTotals ||
        oldDelegate.showActiveSegment != showActiveSegment ||
        oldDelegate.columnGap != columnGap ||
        oldDelegate.segmentGap != segmentGap ||
        oldDelegate.segmentRadius != segmentRadius ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.shareFormatter != shareFormatter ||
        oldDelegate.progress != progress;
  }
}

class _MarimekkoModel {
  final List<String> categories;
  final List<SimpleMarimekkoSeries> series;
  final List<double> categoryTotals;
  final double total;

  const _MarimekkoModel({
    required this.categories,
    required this.series,
    required this.categoryTotals,
    required this.total,
  });

  bool get isEmpty => categories.isEmpty || series.isEmpty || total <= 0;

  double valueAt(int categoryIndex, int seriesIndex) {
    final item = series[seriesIndex];
    if (categoryIndex >= item.values.length) return 0;
    final value = item.values[categoryIndex];
    if (!value.isFinite || value < 0) return 0;
    return value;
  }

  double shareAt(int categoryIndex, int seriesIndex) {
    final total = categoryTotals[categoryIndex];
    if (total <= 0) return 0;
    return valueAt(categoryIndex, seriesIndex) / total;
  }

  factory _MarimekkoModel.resolve({
    required List<String> categories,
    required List<SimpleMarimekkoSeries> series,
  }) {
    final totals = <double>[];
    for (
      var categoryIndex = 0;
      categoryIndex < categories.length;
      categoryIndex++
    ) {
      var total = 0.0;
      for (final item in series) {
        if (categoryIndex >= item.values.length) continue;
        final value = item.values[categoryIndex];
        if (value.isFinite && value >= 0) total += value;
      }
      totals.add(total);
    }
    final grandTotal = totals.fold<double>(
      0,
      (current, value) => current + value,
    );
    return _MarimekkoModel(
      categories: categories,
      series: series,
      categoryTotals: totals,
      total: grandTotal,
    );
  }
}

class _MarimekkoLayout {
  final Rect plot;
  final List<_MarimekkoColumnLayout> columns;
  final List<_MarimekkoSegmentLayout> segments;

  const _MarimekkoLayout({
    required this.plot,
    required this.columns,
    required this.segments,
  });

  factory _MarimekkoLayout.resolve({
    required Size size,
    required _MarimekkoModel model,
    required EdgeInsets padding,
    required double columnGap,
    required double segmentGap,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0 || model.isEmpty) {
      return _MarimekkoLayout(
        plot: plot,
        columns: const [],
        segments: const [],
      );
    }

    final positiveCategories = model.categoryTotals
        .where((value) => value > 0)
        .length;
    final availableWidth = math.max(
      0.0,
      plot.width - math.max(0, positiveCategories - 1) * columnGap,
    );
    var cursorX = plot.left;
    final columns = <_MarimekkoColumnLayout>[];
    final segments = <_MarimekkoSegmentLayout>[];

    for (
      var categoryIndex = 0;
      categoryIndex < model.categories.length;
      categoryIndex++
    ) {
      final categoryTotal = model.categoryTotals[categoryIndex];
      if (categoryTotal <= 0) continue;
      final columnWidth = availableWidth * (categoryTotal / model.total);
      final columnRect = Rect.fromLTWH(
        cursorX,
        plot.top,
        columnWidth,
        plot.height,
      );
      columns.add(
        _MarimekkoColumnLayout(categoryIndex: categoryIndex, rect: columnRect),
      );

      var cursorY = plot.bottom;
      for (
        var seriesIndex = 0;
        seriesIndex < model.series.length;
        seriesIndex++
      ) {
        final value = model.valueAt(categoryIndex, seriesIndex);
        if (value <= 0) continue;
        final height = columnRect.height * (value / categoryTotal);
        final rawRect = Rect.fromLTRB(
          columnRect.left,
          cursorY - height,
          columnRect.right,
          cursorY,
        );
        final rect = rawRect.deflate(
          math.min(segmentGap / 2, rawRect.shortestSide / 3),
        );
        segments.add(
          _MarimekkoSegmentLayout(
            categoryIndex: categoryIndex,
            seriesIndex: seriesIndex,
            rect: rect,
          ),
        );
        cursorY -= height;
      }
      cursorX += columnWidth + columnGap;
    }
    return _MarimekkoLayout(plot: plot, columns: columns, segments: segments);
  }

  _MarimekkoSegmentLayout? segmentFor(_MarimekkoSelection selection) {
    for (final segment in segments) {
      if (segment.categoryIndex == selection.categoryIndex &&
          segment.seriesIndex == selection.seriesIndex) {
        return segment;
      }
    }
    return null;
  }
}

class _MarimekkoColumnLayout {
  final int categoryIndex;
  final Rect rect;

  const _MarimekkoColumnLayout({
    required this.categoryIndex,
    required this.rect,
  });
}

class _MarimekkoSegmentLayout {
  final int categoryIndex;
  final int seriesIndex;
  final Rect rect;

  const _MarimekkoSegmentLayout({
    required this.categoryIndex,
    required this.seriesIndex,
    required this.rect,
  });
}

class _MarimekkoSelection {
  final int categoryIndex;
  final int seriesIndex;

  const _MarimekkoSelection(this.categoryIndex, this.seriesIndex);

  @override
  bool operator ==(Object other) {
    return other is _MarimekkoSelection &&
        other.categoryIndex == categoryIndex &&
        other.seriesIndex == seriesIndex;
  }

  @override
  int get hashCode => Object.hash(categoryIndex, seriesIndex);
}

class _SimpleMarimekkoVisuals {
  final List<Color> palette;
  final Color borderColor;
  final Color gridColor;

  const _SimpleMarimekkoVisuals({
    required this.palette,
    required this.borderColor,
    required this.gridColor,
  });

  factory _SimpleMarimekkoVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleMarimekkoVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFFF97316),
          ],
          borderColor: colorScheme.surface.withValues(alpha: 0.58),
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleMarimekkoVisuals(
          palette: [
            colorScheme.primary,
            const Color(0xFF475569),
            const Color(0xFF0F766E),
            const Color(0xFF1D4ED8),
            const Color(0xFF64748B),
          ],
          borderColor: colorScheme.surface.withValues(alpha: 0.7),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
        );
      case SimpleBarChartStyle.education:
        return _SimpleMarimekkoVisuals(
          palette: [
            colorScheme.secondary,
            const Color(0xFF3B82F6),
            const Color(0xFFF59E0B),
            const Color(0xFF10B981),
            const Color(0xFF8B5CF6),
          ],
          borderColor: colorScheme.surface.withValues(alpha: 0.66),
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleMarimekkoVisuals(
          palette: [
            colorScheme.tertiary,
            const Color(0xFF06B6D4),
            const Color(0xFF22C55E),
            const Color(0xFFEC4899),
            const Color(0xFFF97316),
          ],
          borderColor: colorScheme.surface.withValues(alpha: 0.54),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleMarimekkoVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFFF59E0B),
          ],
          borderColor: colorScheme.surface.withValues(alpha: 0.62),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
        );
    }
  }
}

class _MarimekkoLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final TextStyle textStyle;

  const _MarimekkoLegendItem({
    required this.label,
    required this.color,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: textStyle),
      ],
    );
  }
}

class _DefaultMarimekkoTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String label;
  final String value;
  final String share;

  const _DefaultMarimekkoTooltip({
    required this.color,
    required this.title,
    required this.label,
    required this.value,
    required this.share,
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
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onInverseSurface.withValues(
                        alpha: 0.76,
                      ),
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              share,
              style: TextStyle(
                color: colorScheme.onInverseSurface.withValues(alpha: 0.76),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
