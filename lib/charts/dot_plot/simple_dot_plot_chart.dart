import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

typedef SimpleDotPlotValueFormatter = String Function(double value);
typedef SimpleDotPlotTapCallback =
    void Function(
      String category,
      SimpleDotPlotSeries series,
      double value,
      int categoryIndex,
      int seriesIndex,
    );
typedef SimpleDotPlotTooltipBuilder =
    Widget Function(
      BuildContext context,
      String category,
      SimpleDotPlotSeries series,
      double value,
      int categoryIndex,
      int seriesIndex,
      String formattedValue,
    );

class SimpleDotPlotSeries {
  final String name;
  final List<double> values;
  final Color? color;

  const SimpleDotPlotSeries({
    required this.name,
    required this.values,
    this.color,
  });
}

/// A compact Cleveland-style dot plot for ranking, benchmarking, survey
/// scores, and multi-series category comparisons.
class SimpleDotPlotChart extends StatelessWidget {
  static const EdgeInsets _horizontalPadding = EdgeInsets.fromLTRB(
    92,
    18,
    42,
    32,
  );
  static const EdgeInsets _verticalPadding = EdgeInsets.fromLTRB(
    48,
    18,
    18,
    42,
  );

  final List<String> categories;
  final List<SimpleDotPlotSeries> series;
  final SimpleBarChartOrientation orientation;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets? padding;
  final List<Color>? palette;
  final Color? dotColor;
  final Color? guideLineColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showGuideLines;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveDot;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double? dotRadius;
  final double? guideLineWidth;
  final SimpleDotPlotValueFormatter? valueFormatter;
  final SimpleDotPlotTapCallback? onPointTap;
  final SimpleDotPlotTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleDotPlotChart({
    super.key,
    required this.categories,
    required this.series,
    this.orientation = SimpleBarChartOrientation.horizontal,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding,
    this.palette,
    this.dotColor,
    this.guideLineColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showGuideLines = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveDot = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.dotRadius,
    this.guideLineWidth,
    this.valueFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 650),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(dotRadius == null || dotRadius >= 0),
       assert(guideLineWidth == null || guideLineWidth > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleDotPlotVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .where((item) => item.values.any((value) => value.isFinite))
        .toList();
    final visibleCategories = categories
        .where((category) => category.trim().isNotEmpty)
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedPadding =
        padding ??
        (orientation == SimpleBarChartOrientation.vertical
            ? _verticalPadding
            : _horizontalPadding);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleCategories.isEmpty || visibleSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Dot plot chart, no data.',
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
        final resolvedPalette = _resolvePalette(colorScheme, visuals.dotColor);

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleCategories,
            visibleSeries,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleDotPlotChartView(
            width: width,
            height: chartHeight,
            categories: visibleCategories,
            series: visibleSeries,
            orientation: orientation,
            minValue: minValue,
            maxValue: maxValue,
            padding: resolvedPadding,
            palette: resolvedPalette,
            guideLineColor: guideLineColor ?? visuals.guideLineColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showGuideLines: showGuideLines,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveDot: showActiveDot,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            dotRadius: dotRadius ?? visuals.dotRadius,
            guideLineWidth: guideLineWidth ?? visuals.guideLineWidth,
            valueFormatter: formatter,
            onPointTap: onPointTap,
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
      dotColor ?? fallback,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
  }

  String _defaultSemanticLabel(
    List<String> visibleCategories,
    List<SimpleDotPlotSeries> visibleSeries,
    SimpleDotPlotValueFormatter formatter,
  ) {
    final summaries = <String>[];
    final categoryLimit = math.min(visibleCategories.length, 4);
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
      summaries.add('${visibleCategories[categoryIndex]}: $values');
    }
    final suffix = visibleCategories.length > categoryLimit
        ? '; and ${visibleCategories.length - categoryLimit} more categories'
        : '';
    final countLabel = visibleCategories.length == 1
        ? 'category'
        : 'categories';
    return 'Dot plot chart, ${visibleCategories.length} $countLabel. '
        '${summaries.join('; ')}$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleDotPlotChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<String> categories;
  final List<SimpleDotPlotSeries> series;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color guideLineColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showGuideLines;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveDot;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double dotRadius;
  final double guideLineWidth;
  final SimpleDotPlotValueFormatter valueFormatter;
  final SimpleDotPlotTapCallback? onPointTap;
  final SimpleDotPlotTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleDotPlotChartView({
    required this.width,
    required this.height,
    required this.categories,
    required this.series,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.guideLineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showGuideLines,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveDot,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.dotRadius,
    required this.guideLineWidth,
    required this.valueFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleDotPlotChartView> createState() =>
      _SimpleDotPlotChartViewState();
}

class _SimpleDotPlotChartViewState extends State<_SimpleDotPlotChartView> {
  _DotPlotSelection? _active;

  @override
  Widget build(BuildContext context) {
    final hasLegend = widget.showLegend && widget.series.length > 1;
    final interactionEnabled =
        widget.showTooltip || widget.showActiveDot || widget.onPointTap != null;

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
                      painter: _SimpleDotPlotPainter(
                        categories: widget.categories,
                        series: widget.series,
                        orientation: widget.orientation,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        palette: widget.palette,
                        guideLineColor: widget.guideLineColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showGuideLines: widget.showGuideLines,
                        showValues: widget.showValues,
                        showActiveDot: widget.showActiveDot,
                        referenceLines: widget.referenceLines,
                        referenceBands: widget.referenceBands,
                        gridLineCount: widget.gridLineCount,
                        dotRadius: widget.dotRadius,
                        guideLineWidth: widget.guideLineWidth,
                        activeSelection: _active,
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

                            final selectedSeries =
                                widget.series[selection.seriesIndex];
                            final category =
                                widget.categories[selection.categoryIndex];
                            final value =
                                selectedSeries.values[selection.categoryIndex];
                            widget.onPointTap?.call(
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

  void _setActive(_DotPlotSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _DotPlotSelection? _hitTest(Offset position, Size size) {
    final geometry = _DotPlotGeometry.resolve(
      size: size,
      categories: widget.categories,
      series: widget.series,
      orientation: widget.orientation,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      referenceLines: widget.referenceLines,
      referenceBands: widget.referenceBands,
      dotRadius: widget.dotRadius,
    );
    for (final point in geometry.points) {
      if ((position - point.center).distance <= widget.dotRadius + 8) {
        return _DotPlotSelection(
          point.categoryIndex,
          point.seriesIndex,
          point.center,
        );
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _DotPlotSelection selection,
  ) {
    final selectedSeries = widget.series[selection.seriesIndex];
    final category = widget.categories[selection.categoryIndex];
    final value = selectedSeries.values[selection.categoryIndex];
    final formattedValue = widget.valueFormatter(value);
    const tooltipWidth = 174.0;
    const tooltipHeight = 64.0;
    final left = (selection.position.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (selection.position.dy - tooltipHeight - 8)
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
          _DefaultDotPlotTooltip(
            color: _seriesColor(selectedSeries, selection.seriesIndex),
            title: category,
            label: selectedSeries.name,
            value: formattedValue,
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
          for (var index = 0; index < widget.series.length; index++)
            _DotLegendItem(
              label: widget.series[index].name,
              color: _seriesColor(widget.series[index], index),
              textStyle: widget.labelStyle,
            ),
        ],
      ),
    );
  }

  Color _seriesColor(SimpleDotPlotSeries item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleDotPlotPainter extends CustomPainter {
  final List<String> categories;
  final List<SimpleDotPlotSeries> series;
  final SimpleBarChartOrientation orientation;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color guideLineColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showGuideLines;
  final bool showValues;
  final bool showActiveDot;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double dotRadius;
  final double guideLineWidth;
  final _DotPlotSelection? activeSelection;
  final SimpleDotPlotValueFormatter valueFormatter;
  final double progress;

  const _SimpleDotPlotPainter({
    required this.categories,
    required this.series,
    required this.orientation,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.palette,
    required this.guideLineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showGuideLines,
    required this.showValues,
    required this.showActiveDot,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.dotRadius,
    required this.guideLineWidth,
    required this.activeSelection,
    required this.valueFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _DotPlotGeometry.resolve(
      size: size,
      categories: categories,
      series: series,
      orientation: orientation,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
      dotRadius: dotRadius,
    );
    if (geometry.plot.isEmpty || geometry.points.isEmpty) return;

    _drawReferenceBands(canvas, geometry);
    if (showGrid) _drawGrid(canvas, geometry);
    if (showGuideLines) _drawGuideLines(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawReferenceLines(canvas, geometry);
    _drawDots(canvas, geometry);
    _drawCategoryLabels(canvas, geometry);
  }

  void _drawReferenceBands(Canvas canvas, _DotPlotGeometry geometry) {
    final paint = Paint();
    for (final band in referenceBands) {
      final from = band.from.isFinite ? band.from : geometry.range.min;
      final to = band.to.isFinite ? band.to : geometry.range.max;
      final start = geometry.positionForValue(from);
      final end = geometry.positionForValue(to);
      paint.color = (band.color ?? palette.first).withValues(
        alpha: band.opacity,
      );
      if (orientation == SimpleBarChartOrientation.horizontal) {
        canvas.drawRect(
          Rect.fromLTRB(
            math.min(start, end),
            geometry.plot.top,
            math.max(start, end),
            geometry.plot.bottom,
          ),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTRB(
            geometry.plot.left,
            math.min(start, end),
            geometry.plot.right,
            math.max(start, end),
          ),
          paint,
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, _DotPlotGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          geometry.range.min + geometry.range.span * (index / gridLineCount);
      final position = geometry.positionForValue(value);
      if (orientation == SimpleBarChartOrientation.horizontal) {
        canvas.drawLine(
          Offset(position, geometry.plot.top),
          Offset(position, geometry.plot.bottom),
          paint,
        );
        _drawAxisTickLabel(
          canvas,
          value,
          Offset(position, geometry.plot.bottom),
        );
      } else {
        canvas.drawLine(
          Offset(geometry.plot.left, position),
          Offset(geometry.plot.right, position),
          paint,
        );
        _drawAxisTickLabel(canvas, value, Offset(geometry.plot.left, position));
      }
    }
  }

  void _drawGuideLines(Canvas canvas, _DotPlotGeometry geometry) {
    final paint = Paint()
      ..color = guideLineColor
      ..strokeWidth = guideLineWidth
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < categories.length; index++) {
      final position = geometry.categoryCenter(index);
      if (orientation == SimpleBarChartOrientation.horizontal) {
        canvas.drawLine(
          Offset(geometry.plot.left, position),
          Offset(geometry.plot.right, position),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(position, geometry.plot.top),
          Offset(position, geometry.plot.bottom),
          paint,
        );
      }
    }
  }

  void _drawAxis(Canvas canvas, _DotPlotGeometry geometry) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    if (orientation == SimpleBarChartOrientation.horizontal) {
      canvas.drawLine(
        Offset(geometry.plot.left, geometry.plot.bottom),
        Offset(geometry.plot.right, geometry.plot.bottom),
        paint,
      );
    } else {
      canvas.drawLine(
        Offset(geometry.plot.left, geometry.plot.top),
        Offset(geometry.plot.left, geometry.plot.bottom),
        paint,
      );
    }
  }

  void _drawReferenceLines(Canvas canvas, _DotPlotGeometry geometry) {
    for (final line in referenceLines) {
      if (!line.value.isFinite) continue;
      final position = geometry.positionForValue(line.value);
      final paint = Paint()
        ..color = line.color ?? axisColor
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke;
      if (orientation == SimpleBarChartOrientation.horizontal) {
        _drawStyledLine(
          canvas,
          Offset(position, geometry.plot.top),
          Offset(position, geometry.plot.bottom),
          paint,
          line.lineStyle,
        );
      } else {
        _drawStyledLine(
          canvas,
          Offset(geometry.plot.left, position),
          Offset(geometry.plot.right, position),
          paint,
          line.lineStyle,
        );
      }
    }
  }

  void _drawDots(Canvas canvas, _DotPlotGeometry geometry) {
    for (final point in geometry.points) {
      final selected =
          activeSelection?.categoryIndex == point.categoryIndex &&
          activeSelection?.seriesIndex == point.seriesIndex;
      final seriesItem = series[point.seriesIndex];
      final color =
          seriesItem.color ?? palette[point.seriesIndex % palette.length];
      final center = _animatedCenter(point.center, geometry);
      final radius = dotRadius * (0.45 + progress * 0.55);

      canvas.drawCircle(
        center,
        radius + 1.4,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      canvas.drawCircle(center, radius, Paint()..color = color);

      if (showActiveDot && selected) {
        final highlight = activeColor ?? color;
        canvas.drawCircle(
          center,
          radius + 5,
          Paint()..color = highlight.withValues(alpha: 0.14),
        );
        canvas.drawCircle(
          center,
          radius + 3,
          Paint()
            ..color = highlight.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      if (showValues && progress > 0.6) {
        _drawPointValue(canvas, point, center);
      }
    }
  }

  Offset _animatedCenter(Offset center, _DotPlotGeometry geometry) {
    if (orientation == SimpleBarChartOrientation.horizontal) {
      final startX = geometry.positionForValue(math.max(0, geometry.range.min));
      return Offset(startX + (center.dx - startX) * progress, center.dy);
    }
    final startY = geometry.positionForValue(math.max(0, geometry.range.min));
    return Offset(center.dx, startY + (center.dy - startY) * progress);
  }

  void _drawPointValue(Canvas canvas, _DotPointLayout point, Offset center) {
    final value = series[point.seriesIndex].values[point.categoryIndex];
    final text = valueFormatter(value);
    if (orientation == SimpleBarChartOrientation.horizontal) {
      _paintText(
        canvas,
        text,
        valueStyle,
        Offset(center.dx + dotRadius + 5, center.dy),
        TextAlign.left,
        52,
        centeredY: true,
      );
    } else {
      _paintText(
        canvas,
        text,
        valueStyle,
        Offset(center.dx, center.dy - dotRadius - 17),
        TextAlign.center,
        52,
      );
    }
  }

  void _drawCategoryLabels(Canvas canvas, _DotPlotGeometry geometry) {
    for (var index = 0; index < categories.length; index++) {
      final position = geometry.categoryCenter(index);
      if (orientation == SimpleBarChartOrientation.horizontal) {
        _paintText(
          canvas,
          categories[index],
          labelStyle,
          Offset(padding.left - 10, position),
          TextAlign.right,
          math.max(0.0, padding.left - 16),
          centeredY: true,
        );
      } else {
        _paintText(
          canvas,
          categories[index],
          labelStyle,
          Offset(position, geometry.plot.bottom + 18),
          TextAlign.center,
          math.max(28.0, geometry.categorySize - 4),
        );
      }
    }
  }

  void _drawAxisTickLabel(Canvas canvas, double value, Offset anchor) {
    final style = labelStyle.copyWith(
      color: labelStyle.color?.withValues(alpha: 0.72),
      fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
    );
    if (orientation == SimpleBarChartOrientation.horizontal) {
      _paintText(
        canvas,
        valueFormatter(value),
        style,
        Offset(anchor.dx, anchor.dy + 6),
        TextAlign.center,
        56,
      );
    } else {
      _paintText(
        canvas,
        valueFormatter(value),
        style,
        Offset(anchor.dx - 8, anchor.dy),
        TextAlign.right,
        math.max(0.0, padding.left - 12),
        centeredY: true,
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset anchor,
    TextAlign align,
    double maxWidth, {
    bool centeredY = false,
  }) {
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
    final dy = centeredY ? anchor.dy - painter.height / 2 : anchor.dy;
    painter.paint(canvas, Offset(dx, dy));
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
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    var drawn = 0.0;
    final dash = style == SimpleChartReferenceLineStyle.dotted ? 1.5 : 6.0;
    final gap = style == SimpleChartReferenceLineStyle.dotted ? 5.0 : 4.0;
    while (drawn < total) {
      final segmentStart = start + direction * drawn;
      final segmentEnd = start + direction * math.min(total, drawn + dash);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleDotPlotPainter oldDelegate) {
    return oldDelegate.categories != categories ||
        oldDelegate.series != series ||
        oldDelegate.orientation != orientation ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.guideLineColor != guideLineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showGuideLines != showGuideLines ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showActiveDot != showActiveDot ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.guideLineWidth != guideLineWidth ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _DotPlotGeometry {
  final Rect plot;
  final _DotValueRange range;
  final List<_DotPointLayout> points;
  final SimpleBarChartOrientation orientation;
  final double categorySize;

  const _DotPlotGeometry({
    required this.plot,
    required this.range,
    required this.points,
    required this.orientation,
    required this.categorySize,
  });

  factory _DotPlotGeometry.resolve({
    required Size size,
    required List<String> categories,
    required List<SimpleDotPlotSeries> series,
    required SimpleBarChartOrientation orientation,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
    required double dotRadius,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 ||
        plot.height <= 0 ||
        categories.isEmpty ||
        series.isEmpty) {
      return _DotPlotGeometry(
        plot: plot,
        range: const _DotValueRange(0, 1),
        points: const [],
        orientation: orientation,
        categorySize: 0,
      );
    }

    final range = _DotValueRange.resolve(
      categories: categories,
      series: series,
      minValue: minValue,
      maxValue: maxValue,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    final categorySize =
        (orientation == SimpleBarChartOrientation.horizontal
            ? plot.height
            : plot.width) /
        categories.length;
    final seriesOffset = math.min(dotRadius * 2.4, categorySize * 0.22);
    final points = <_DotPointLayout>[];

    for (
      var categoryIndex = 0;
      categoryIndex < categories.length;
      categoryIndex++
    ) {
      final categoryCenter = orientation == SimpleBarChartOrientation.horizontal
          ? plot.top + categorySize * categoryIndex + categorySize / 2
          : plot.left + categorySize * categoryIndex + categorySize / 2;
      for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
        final item = series[seriesIndex];
        if (categoryIndex >= item.values.length) continue;
        final value = item.values[categoryIndex];
        if (!value.isFinite) continue;
        final offset = (seriesIndex - (series.length - 1) / 2) * seriesOffset;
        final valuePosition = _positionForValue(
          value,
          plot,
          range,
          orientation,
        );
        final center = orientation == SimpleBarChartOrientation.horizontal
            ? Offset(valuePosition, categoryCenter + offset)
            : Offset(categoryCenter + offset, valuePosition);
        points.add(
          _DotPointLayout(
            categoryIndex: categoryIndex,
            seriesIndex: seriesIndex,
            center: center,
          ),
        );
      }
    }

    return _DotPlotGeometry(
      plot: plot,
      range: range,
      points: points,
      orientation: orientation,
      categorySize: categorySize,
    );
  }

  double categoryCenter(int categoryIndex) {
    if (orientation == SimpleBarChartOrientation.horizontal) {
      return plot.top + categorySize * categoryIndex + categorySize / 2;
    }
    return plot.left + categorySize * categoryIndex + categorySize / 2;
  }

  double positionForValue(double value) {
    return _positionForValue(value, plot, range, orientation);
  }

  static double _positionForValue(
    double value,
    Rect plot,
    _DotValueRange range,
    SimpleBarChartOrientation orientation,
  ) {
    final normalized = ((value - range.min) / range.span).clamp(0.0, 1.0);
    if (orientation == SimpleBarChartOrientation.horizontal) {
      return plot.left + normalized * plot.width;
    }
    return plot.bottom - normalized * plot.height;
  }
}

class _DotPointLayout {
  final int categoryIndex;
  final int seriesIndex;
  final Offset center;

  const _DotPointLayout({
    required this.categoryIndex,
    required this.seriesIndex,
    required this.center,
  });
}

class _DotPlotSelection {
  final int categoryIndex;
  final int seriesIndex;
  final Offset position;

  const _DotPlotSelection(this.categoryIndex, this.seriesIndex, this.position);

  @override
  bool operator ==(Object other) {
    return other is _DotPlotSelection &&
        other.categoryIndex == categoryIndex &&
        other.seriesIndex == seriesIndex;
  }

  @override
  int get hashCode => Object.hash(categoryIndex, seriesIndex);
}

class _DotValueRange {
  final double min;
  final double max;

  const _DotValueRange(this.min, this.max);

  double get span => max - min;

  factory _DotValueRange.resolve({
    required List<String> categories,
    required List<SimpleDotPlotSeries> series,
    required double? minValue,
    required double? maxValue,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    var lower = double.infinity;
    var upper = double.negativeInfinity;
    for (final item in series) {
      for (
        var index = 0;
        index < math.min(categories.length, item.values.length);
        index++
      ) {
        final value = item.values[index];
        if (!value.isFinite) continue;
        lower = math.min(lower, value);
        upper = math.max(upper, value);
      }
    }
    for (final line in referenceLines) {
      if (line.value.isFinite) {
        lower = math.min(lower, line.value);
        upper = math.max(upper, line.value);
      }
    }
    for (final band in referenceBands) {
      if (band.from.isFinite) lower = math.min(lower, band.from);
      if (band.to.isFinite) upper = math.max(upper, band.to);
    }
    if (!lower.isFinite || !upper.isFinite) {
      lower = 0;
      upper = 1;
    }

    lower = minValue ?? math.min(0, lower);
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
    } else if (minValue == null && maxValue == null) {
      final pad = (upper - lower) * 0.08;
      upper += pad;
    }
    return _DotValueRange(lower, upper);
  }
}

class _SimpleDotPlotVisuals {
  final Color dotColor;
  final Color guideLineColor;
  final Color gridColor;
  final Color axisColor;
  final double dotRadius;
  final double guideLineWidth;

  const _SimpleDotPlotVisuals({
    required this.dotColor,
    required this.guideLineColor,
    required this.gridColor,
    required this.axisColor,
    required this.dotRadius,
    required this.guideLineWidth,
  });

  factory _SimpleDotPlotVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleDotPlotVisuals(
          dotColor: colorScheme.primary,
          guideLineColor: colorScheme.primary.withValues(alpha: 0.11),
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.52),
          dotRadius: 6,
          guideLineWidth: 1.2,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleDotPlotVisuals(
          dotColor: colorScheme.primary,
          guideLineColor: colorScheme.outline.withValues(alpha: 0.16),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          dotRadius: 5,
          guideLineWidth: 1,
        );
      case SimpleBarChartStyle.education:
        return _SimpleDotPlotVisuals(
          dotColor: colorScheme.secondary,
          guideLineColor: colorScheme.secondary.withValues(alpha: 0.12),
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          dotRadius: 5.5,
          guideLineWidth: 1.2,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleDotPlotVisuals(
          dotColor: colorScheme.tertiary,
          guideLineColor: colorScheme.tertiary.withValues(alpha: 0.12),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          dotRadius: 6.5,
          guideLineWidth: 1.4,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleDotPlotVisuals(
          dotColor: colorScheme.primary,
          guideLineColor: colorScheme.primary.withValues(alpha: 0.1),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          dotRadius: 5.5,
          guideLineWidth: 1.1,
        );
    }
  }
}

class _DotLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final TextStyle textStyle;

  const _DotLegendItem({
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
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: textStyle),
      ],
    );
  }
}

class _DefaultDotPlotTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String label;
  final String value;

  const _DefaultDotPlotTooltip({
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
          ],
        ),
      ),
    );
  }
}
