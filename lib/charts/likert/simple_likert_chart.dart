import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleLikertValueFormatter = String Function(double value);

typedef SimpleLikertSegmentTapCallback =
    void Function(
      SimpleLikertItem item,
      SimpleLikertCategory category,
      int itemIndex,
      int categoryIndex,
      double displayedValue,
      double share,
    );

typedef SimpleLikertTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleLikertItem item,
      SimpleLikertCategory category,
      int itemIndex,
      int categoryIndex,
      String formattedValue,
      String formattedShare,
    );

enum SimpleLikertSentiment { negative, neutral, positive }

class SimpleLikertCategory {
  final String label;
  final SimpleLikertSentiment sentiment;
  final Color? color;

  const SimpleLikertCategory({
    required this.label,
    required this.sentiment,
    this.color,
  });
}

class SimpleLikertItem {
  final String label;
  final List<double> values;
  final String? group;

  const SimpleLikertItem({
    required this.label,
    required this.values,
    this.group,
  });
}

/// A diverging stacked response chart for Likert, sentiment, and survey data.
class SimpleLikertChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(
    112,
    18,
    20,
    52,
  );

  final List<SimpleLikertCategory> categories;
  final List<SimpleLikertItem> items;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? negativePalette;
  final Color? neutralColor;
  final List<Color>? positivePalette;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final TextStyle? legendStyle;
  final bool stackAsPercent;
  final bool showGrid;
  final bool showValues;
  final bool showLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSegment;
  final bool showCenterLine;
  final bool showAxisLabels;
  final int gridLineCount;
  final double barHeight;
  final double barGap;
  final double barRadius;
  final SimpleLikertValueFormatter? valueFormatter;
  final SimpleLikertValueFormatter? shareFormatter;
  final SimpleLikertSegmentTapCallback? onSegmentTap;
  final SimpleLikertTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleLikertChart({
    super.key,
    required this.categories,
    required this.items,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 260,
    this.padding = _defaultPadding,
    this.negativePalette,
    this.neutralColor,
    this.positivePalette,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.legendStyle,
    this.stackAsPercent = true,
    this.showGrid = true,
    this.showValues = true,
    this.showLabels = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveSegment = true,
    this.showCenterLine = true,
    this.showAxisLabels = true,
    this.gridLineCount = 4,
    this.barHeight = 24,
    this.barGap = 12,
    this.barRadius = 5,
    this.valueFormatter,
    this.shareFormatter,
    this.onSegmentTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(barHeight > 0),
       assert(barGap >= 0),
       assert(barRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleLikertVisuals.resolve(style, colorScheme);
    final categoryEntries = _visibleCategories(categories);
    final itemEntries = _visibleItems(items, categoryEntries);
    final resolvedValueFormatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedShareFormatter = shareFormatter ?? _defaultShareFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (categoryEntries.isEmpty || itemEntries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Likert chart, no data.',
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
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
        final resolvedLegendStyle =
            legendStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            categoryEntries,
            itemEntries,
            resolvedShareFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleLikertChartView(
            width: width,
            height: chartHeight,
            categories: categoryEntries,
            items: itemEntries,
            padding: padding,
            negativePalette: negativePalette ?? visuals.negativePalette,
            neutralColor: neutralColor ?? visuals.neutralColor,
            positivePalette: positivePalette ?? visuals.positivePalette,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            legendStyle: resolvedLegendStyle,
            stackAsPercent: stackAsPercent,
            showGrid: showGrid,
            showValues: showValues,
            showLabels: showLabels,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveSegment: showActiveSegment,
            showCenterLine: showCenterLine,
            showAxisLabels: showAxisLabels,
            gridLineCount: gridLineCount,
            barHeight: barHeight,
            barGap: barGap,
            barRadius: barRadius,
            valueFormatter: resolvedValueFormatter,
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

  static List<_LikertCategoryEntry> _visibleCategories(
    List<SimpleLikertCategory> categories,
  ) {
    return [
      for (var index = 0; index < categories.length; index++)
        if (categories[index].label.trim().isNotEmpty)
          _LikertCategoryEntry(categories[index], index),
    ];
  }

  static List<_LikertItemEntry> _visibleItems(
    List<SimpleLikertItem> items,
    List<_LikertCategoryEntry> categories,
  ) {
    final entries = <_LikertItemEntry>[];
    for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
      final item = items[itemIndex];
      if (item.label.trim().isEmpty) continue;
      final values = [
        for (final category in categories)
          _safeValue(item.values, category.originalIndex),
      ];
      if (values.any((value) => value > 0)) {
        entries.add(_LikertItemEntry(item, itemIndex, values));
      }
    }
    return entries;
  }

  static double _safeValue(List<double> values, int index) {
    if (index < 0 || index >= values.length) return 0;
    final value = values[index];
    if (!value.isFinite || value <= 0) return 0;
    return value;
  }

  String _defaultSemanticLabel(
    List<_LikertCategoryEntry> visibleCategories,
    List<_LikertItemEntry> visibleItems,
    SimpleLikertValueFormatter formatter,
  ) {
    final summaries = <String>[];
    final itemLimit = math.min(visibleItems.length, 5);
    for (var itemIndex = 0; itemIndex < itemLimit; itemIndex++) {
      final item = visibleItems[itemIndex];
      final total = item.values.fold<double>(0, (sum, value) => sum + value);
      if (total <= 0) continue;
      var positive = 0.0;
      var negative = 0.0;
      for (
        var categoryIndex = 0;
        categoryIndex < visibleCategories.length;
        categoryIndex++
      ) {
        final value = item.values[categoryIndex];
        switch (visibleCategories[categoryIndex].category.sentiment) {
          case SimpleLikertSentiment.positive:
            positive += value;
          case SimpleLikertSentiment.negative:
            negative += value;
          case SimpleLikertSentiment.neutral:
            break;
        }
      }
      summaries.add(
        '${item.item.label} ${formatter(positive / total * 100)} positive, '
        '${formatter(negative / total * 100)} negative',
      );
    }
    final remaining = visibleItems.length - itemLimit;
    final suffix = remaining > 0 ? '; and $remaining more' : '';
    final countLabel = visibleItems.length == 1 ? 'item' : 'items';
    return 'Likert chart, ${visibleItems.length} $countLabel and '
        '${visibleCategories.length} response categories. '
        '${summaries.join('; ')}$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  static String _defaultShareFormatter(double value) {
    if (value == value.roundToDouble()) return '${value.toInt()}%';
    return '${value.toStringAsFixed(1)}%';
  }
}

class _SimpleLikertChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<_LikertCategoryEntry> categories;
  final List<_LikertItemEntry> items;
  final EdgeInsets padding;
  final List<Color> negativePalette;
  final Color neutralColor;
  final List<Color> positivePalette;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final TextStyle legendStyle;
  final bool stackAsPercent;
  final bool showGrid;
  final bool showValues;
  final bool showLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSegment;
  final bool showCenterLine;
  final bool showAxisLabels;
  final int gridLineCount;
  final double barHeight;
  final double barGap;
  final double barRadius;
  final SimpleLikertValueFormatter valueFormatter;
  final SimpleLikertValueFormatter shareFormatter;
  final SimpleLikertSegmentTapCallback? onSegmentTap;
  final SimpleLikertTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleLikertChartView({
    required this.width,
    required this.height,
    required this.categories,
    required this.items,
    required this.padding,
    required this.negativePalette,
    required this.neutralColor,
    required this.positivePalette,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.legendStyle,
    required this.stackAsPercent,
    required this.showGrid,
    required this.showValues,
    required this.showLabels,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveSegment,
    required this.showCenterLine,
    required this.showAxisLabels,
    required this.gridLineCount,
    required this.barHeight,
    required this.barGap,
    required this.barRadius,
    required this.valueFormatter,
    required this.shareFormatter,
    required this.onSegmentTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleLikertChartView> createState() => _SimpleLikertChartViewState();
}

class _SimpleLikertChartViewState extends State<_SimpleLikertChartView> {
  _LikertSelection? _active;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveSegment ||
        widget.onSegmentTap != null;

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
                painter: _SimpleLikertPainter(
                  categories: widget.categories,
                  items: widget.items,
                  padding: widget.padding,
                  negativePalette: widget.negativePalette,
                  neutralColor: widget.neutralColor,
                  positivePalette: widget.positivePalette,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  legendStyle: widget.legendStyle,
                  stackAsPercent: widget.stackAsPercent,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showLabels: widget.showLabels,
                  showLegend: widget.showLegend,
                  showActiveSegment: widget.showActiveSegment,
                  showCenterLine: widget.showCenterLine,
                  showAxisLabels: widget.showAxisLabels,
                  gridLineCount: widget.gridLineCount,
                  barHeight: widget.barHeight,
                  barGap: widget.barGap,
                  barRadius: widget.barRadius,
                  valueFormatter: widget.valueFormatter,
                  shareFormatter: widget.shareFormatter,
                  active: _active,
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
                      widget.onSegmentTap?.call(
                        selection.item.item,
                        selection.category.category,
                        selection.item.originalIndex,
                        selection.category.originalIndex,
                        selection.displayedValue,
                        selection.share,
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
    );
  }

  void _setActive(_LikertSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _LikertSelection? _hitTest(Offset position, Size size) {
    final geometry = _LikertGeometry.resolve(
      size: size,
      categories: widget.categories,
      items: widget.items,
      padding: widget.padding,
      stackAsPercent: widget.stackAsPercent,
      barHeight: widget.barHeight,
      barGap: widget.barGap,
    );
    for (final row in geometry.rows) {
      for (final segment in row.segments.reversed) {
        final hitRect = segment.rect.inflate(
          math.max(4, row.barRect.height / 5),
        );
        if (hitRect.contains(position)) {
          return _LikertSelection(
            item: segment.item,
            category: segment.category,
            itemIndex: segment.itemIndex,
            categoryIndex: segment.categoryIndex,
            position: segment.rect.center,
            displayedValue: segment.displayedValue,
            share: segment.share,
          );
        }
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _LikertSelection selection,
  ) {
    final formattedValue = widget.stackAsPercent
        ? widget.shareFormatter(selection.displayedValue)
        : widget.valueFormatter(selection.displayedValue);
    final formattedShare = widget.shareFormatter(selection.share * 100);
    const tooltipWidth = 190.0;
    const tooltipHeight = 96.0;
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
            selection.item.item,
            selection.category.category,
            selection.item.originalIndex,
            selection.category.originalIndex,
            formattedValue,
            formattedShare,
          ) ??
          _DefaultLikertTooltip(
            color: _colorFor(selection.categoryIndex),
            itemLabel: selection.item.item.label,
            categoryLabel: selection.category.category.label,
            formattedValue: formattedValue,
            formattedShare: formattedShare,
          ),
    );
  }

  Color _colorFor(int categoryIndex) {
    final category = widget.categories[categoryIndex];
    if (category.category.color != null) return category.category.color!;
    switch (category.category.sentiment) {
      case SimpleLikertSentiment.negative:
        final rank = widget.categories.take(categoryIndex + 1).where((entry) {
          return entry.category.sentiment == SimpleLikertSentiment.negative;
        }).length;
        return widget.negativePalette[math.min(
          rank - 1,
          widget.negativePalette.length - 1,
        )];
      case SimpleLikertSentiment.neutral:
        return widget.neutralColor;
      case SimpleLikertSentiment.positive:
        final rank = widget.categories.take(categoryIndex + 1).where((entry) {
          return entry.category.sentiment == SimpleLikertSentiment.positive;
        }).length;
        return widget.positivePalette[math.min(
          rank - 1,
          widget.positivePalette.length - 1,
        )];
    }
  }
}

class _SimpleLikertPainter extends CustomPainter {
  final List<_LikertCategoryEntry> categories;
  final List<_LikertItemEntry> items;
  final EdgeInsets padding;
  final List<Color> negativePalette;
  final Color neutralColor;
  final List<Color> positivePalette;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final TextStyle legendStyle;
  final bool stackAsPercent;
  final bool showGrid;
  final bool showValues;
  final bool showLabels;
  final bool showLegend;
  final bool showActiveSegment;
  final bool showCenterLine;
  final bool showAxisLabels;
  final int gridLineCount;
  final double barHeight;
  final double barGap;
  final double barRadius;
  final SimpleLikertValueFormatter valueFormatter;
  final SimpleLikertValueFormatter shareFormatter;
  final _LikertSelection? active;
  final double progress;

  const _SimpleLikertPainter({
    required this.categories,
    required this.items,
    required this.padding,
    required this.negativePalette,
    required this.neutralColor,
    required this.positivePalette,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.legendStyle,
    required this.stackAsPercent,
    required this.showGrid,
    required this.showValues,
    required this.showLabels,
    required this.showLegend,
    required this.showActiveSegment,
    required this.showCenterLine,
    required this.showAxisLabels,
    required this.gridLineCount,
    required this.barHeight,
    required this.barGap,
    required this.barRadius,
    required this.valueFormatter,
    required this.shareFormatter,
    required this.active,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _LikertGeometry.resolve(
      size: size,
      categories: categories,
      items: items,
      padding: padding,
      stackAsPercent: stackAsPercent,
      barHeight: barHeight,
      barGap: barGap,
    );
    if (geometry.rows.isEmpty || geometry.plot.isEmpty) return;

    if (showGrid) _drawGrid(canvas, geometry);
    if (showCenterLine) _drawCenterLine(canvas, geometry);
    _drawSegments(canvas, geometry);
    if (showLabels) _drawLabels(canvas, geometry);
    if (showLegend) _drawLegend(canvas, size, geometry);
  }

  void _drawGrid(Canvas canvas, _LikertGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          -geometry.maxSide + (geometry.maxSide * 2 * index / gridLineCount);
      final x = geometry.xForValue(value);
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
      );
      if (showAxisLabels) {
        final label = _formatAxisValue(value.abs());
        _paintText(
          canvas,
          label,
          legendStyle,
          Offset(x, geometry.plot.bottom + 5),
          TextAlign.center,
          56,
        );
      }
    }
  }

  void _drawCenterLine(Canvas canvas, _LikertGeometry geometry) {
    canvas.drawLine(
      Offset(geometry.centerX, geometry.plot.top - 2),
      Offset(geometry.centerX, geometry.plot.bottom + 2),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1.4,
    );
  }

  void _drawSegments(Canvas canvas, _LikertGeometry geometry) {
    final trackPaint = Paint()..color = gridColor.withValues(alpha: 0.28);
    for (final row in geometry.rows) {
      final track = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          geometry.plot.left,
          row.barRect.top,
          geometry.plot.right,
          row.barRect.bottom,
        ),
        Radius.circular(math.min(barRadius, row.barRect.height / 2)),
      );
      canvas.drawRRect(track, trackPaint);

      for (final segment in row.segments) {
        if (segment.rect.width <= 0.5 || segment.rect.height <= 0) continue;
        final color = _colorFor(segment.categoryIndex);
        final animatedRect = _animatedRect(segment);
        if (animatedRect.width <= 0.5) continue;
        final radius = Radius.circular(
          math.min(barRadius, animatedRect.height / 2),
        );
        final rrect = RRect.fromRectAndRadius(animatedRect, radius);
        final paint = Paint()..color = color;
        if (segment.rect.width > 12) {
          paint.shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [color.withValues(alpha: 0.78), color],
          ).createShader(animatedRect);
        }
        canvas.drawRRect(rrect, paint);

        final isActive =
            active?.itemIndex == segment.itemIndex &&
            active?.categoryIndex == segment.categoryIndex;
        if (showActiveSegment && isActive) {
          final highlight = activeColor ?? color;
          canvas.drawRRect(
            rrect.inflate(3),
            Paint()..color = highlight.withValues(alpha: 0.16),
          );
          canvas.drawRRect(
            rrect.inflate(1.5),
            Paint()
              ..color = highlight
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }

        if (showValues) {
          _drawSegmentValue(canvas, segment, animatedRect, color);
        }
      }
    }
  }

  Rect _animatedRect(_LikertSegmentLayout segment) {
    final rect = segment.rect;
    switch (segment.category.category.sentiment) {
      case SimpleLikertSentiment.negative:
        return Rect.fromLTRB(
          rect.right - rect.width * progress,
          rect.top,
          rect.right,
          rect.bottom,
        );
      case SimpleLikertSentiment.neutral:
        final halfWidth = rect.width * progress / 2;
        return Rect.fromLTRB(
          rect.center.dx - halfWidth,
          rect.top,
          rect.center.dx + halfWidth,
          rect.bottom,
        );
      case SimpleLikertSentiment.positive:
        return Rect.fromLTRB(
          rect.left,
          rect.top,
          rect.left + rect.width * progress,
          rect.bottom,
        );
    }
  }

  void _drawSegmentValue(
    Canvas canvas,
    _LikertSegmentLayout segment,
    Rect rect,
    Color color,
  ) {
    if (progress < 0.68 || rect.width < 26) return;
    final text = stackAsPercent
        ? shareFormatter(segment.displayedValue)
        : valueFormatter(segment.displayedValue);
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF0F172A);
    _paintText(
      canvas,
      text,
      valueStyle.copyWith(color: textColor),
      rect.center,
      TextAlign.center,
      math.max(8, rect.width - 4),
      centeredY: true,
    );
  }

  void _drawLabels(Canvas canvas, _LikertGeometry geometry) {
    final maxWidth = math.max(36.0, geometry.plot.left - 16);
    for (final row in geometry.rows) {
      _paintText(
        canvas,
        row.item.item.label,
        labelStyle,
        Offset(geometry.plot.left - 10, row.barRect.center.dy),
        TextAlign.right,
        maxWidth,
        centeredY: true,
      );
    }
  }

  void _drawLegend(Canvas canvas, Size size, _LikertGeometry geometry) {
    var cursor = Offset(geometry.plot.left, geometry.plot.bottom + 24);
    final maxY = size.height - 8;
    final rowHeight = 18.0;
    const markerSize = 8.0;
    for (var index = 0; index < categories.length; index++) {
      final category = categories[index];
      final labelWidth = _measureText(
        category.category.label,
        legendStyle,
        72,
      ).width;
      final itemWidth = markerSize + 5 + labelWidth + 12;
      if (cursor.dx + itemWidth > geometry.plot.right &&
          cursor.dx > geometry.plot.left) {
        cursor = Offset(geometry.plot.left, cursor.dy + rowHeight);
      }
      if (cursor.dy > maxY) break;
      final centerY = cursor.dy + rowHeight / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            cursor.dx,
            centerY - markerSize / 2,
            markerSize,
            markerSize,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = _colorFor(index),
      );
      _paintText(
        canvas,
        category.category.label,
        legendStyle,
        Offset(cursor.dx + markerSize + 5, centerY),
        TextAlign.left,
        72,
        centeredY: true,
      );
      cursor = Offset(cursor.dx + itemWidth, cursor.dy);
    }
  }

  String _formatAxisValue(double value) {
    if (stackAsPercent) return shareFormatter(value);
    return valueFormatter(value);
  }

  Color _colorFor(int categoryIndex) {
    final category = categories[categoryIndex];
    if (category.category.color != null) return category.category.color!;
    switch (category.category.sentiment) {
      case SimpleLikertSentiment.negative:
        final rank = categories.take(categoryIndex + 1).where((entry) {
          return entry.category.sentiment == SimpleLikertSentiment.negative;
        }).length;
        return negativePalette[math.min(rank - 1, negativePalette.length - 1)];
      case SimpleLikertSentiment.neutral:
        return neutralColor;
      case SimpleLikertSentiment.positive:
        final rank = categories.take(categoryIndex + 1).where((entry) {
          return entry.category.sentiment == SimpleLikertSentiment.positive;
        }).length;
        return positivePalette[math.min(rank - 1, positivePalette.length - 1)];
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleLikertPainter oldDelegate) {
    return oldDelegate.categories != categories ||
        oldDelegate.items != items ||
        oldDelegate.padding != padding ||
        oldDelegate.negativePalette != negativePalette ||
        oldDelegate.neutralColor != neutralColor ||
        oldDelegate.positivePalette != positivePalette ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.legendStyle != legendStyle ||
        oldDelegate.stackAsPercent != stackAsPercent ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveSegment != showActiveSegment ||
        oldDelegate.showCenterLine != showCenterLine ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.barGap != barGap ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.shareFormatter != shareFormatter ||
        oldDelegate.active != active ||
        oldDelegate.progress != progress;
  }
}

class _LikertGeometry {
  final Rect plot;
  final double centerX;
  final double maxSide;
  final List<_LikertRowLayout> rows;

  const _LikertGeometry({
    required this.plot,
    required this.centerX,
    required this.maxSide,
    required this.rows,
  });

  double get scale => plot.width <= 0 ? 0 : (plot.width / 2) / maxSide;

  double xForValue(double value) => centerX + value * scale;

  static _LikertGeometry resolve({
    required Size size,
    required List<_LikertCategoryEntry> categories,
    required List<_LikertItemEntry> items,
    required EdgeInsets padding,
    required bool stackAsPercent,
    required double barHeight,
    required double barGap,
  }) {
    final left = padding.left.clamp(0.0, size.width * 0.58).toDouble();
    final right = padding.right.clamp(0.0, size.width * 0.35).toDouble();
    final top = padding.top.clamp(0.0, size.height * 0.42).toDouble();
    final bottom = padding.bottom.clamp(0.0, size.height * 0.5).toDouble();
    final plot = Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, size.width - right),
      math.max(top + 1, size.height - bottom),
    );
    final centerX = plot.center.dx;
    var maxSide = stackAsPercent ? 100.0 : 0.0;
    final rowValues = <_LikertRowValues>[];

    for (final item in items) {
      final total = item.values.fold<double>(0, (sum, value) => sum + value);
      final values = <double>[
        for (final value in item.values)
          stackAsPercent && total > 0 ? value / total * 100 : value,
      ];
      var negative = 0.0;
      var neutral = 0.0;
      var positive = 0.0;
      for (var index = 0; index < categories.length; index++) {
        final value = values[index];
        switch (categories[index].category.sentiment) {
          case SimpleLikertSentiment.negative:
            negative += value;
          case SimpleLikertSentiment.neutral:
            neutral += value;
          case SimpleLikertSentiment.positive:
            positive += value;
        }
      }
      final rowMax = math.max(negative + neutral / 2, positive + neutral / 2);
      maxSide = math.max(maxSide, rowMax);
      rowValues.add(
        _LikertRowValues(
          values: values,
          total: total,
          negative: negative,
          neutral: neutral,
          positive: positive,
        ),
      );
    }
    if (!maxSide.isFinite || maxSide <= 0) maxSide = 1;
    if (!stackAsPercent) maxSide *= 1.08;

    final rows = <_LikertRowLayout>[];
    final rowHeight = plot.height / math.max(1, items.length);
    final resolvedBarHeight = math
        .min(barHeight, math.max(4, rowHeight - barGap))
        .clamp(4.0, math.max(4.0, rowHeight * 0.72))
        .toDouble();
    final scale = (plot.width / 2) / maxSide;

    for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
      final item = items[itemIndex];
      final values = rowValues[itemIndex];
      final centerY = plot.top + rowHeight * itemIndex + rowHeight / 2;
      final barRect = Rect.fromLTWH(
        plot.left,
        centerY - resolvedBarHeight / 2,
        plot.width,
        resolvedBarHeight,
      );
      final segments = <_LikertSegmentLayout>[];

      var negativeCursor =
          centerX - (values.negative + values.neutral / 2) * scale;
      for (
        var categoryIndex = 0;
        categoryIndex < categories.length;
        categoryIndex++
      ) {
        if (categories[categoryIndex].category.sentiment !=
            SimpleLikertSentiment.negative) {
          continue;
        }
        final displayedValue = values.values[categoryIndex];
        final width = displayedValue * scale;
        segments.add(
          _LikertSegmentLayout(
            item: item,
            category: categories[categoryIndex],
            itemIndex: itemIndex,
            categoryIndex: categoryIndex,
            rawValue: item.values[categoryIndex],
            displayedValue: displayedValue,
            share: values.total <= 0
                ? 0
                : item.values[categoryIndex] / values.total,
            rect: Rect.fromLTWH(
              negativeCursor,
              barRect.top,
              math.max(0, width),
              barRect.height,
            ),
          ),
        );
        negativeCursor += width;
      }

      var neutralCursor = centerX - values.neutral / 2 * scale;
      for (
        var categoryIndex = 0;
        categoryIndex < categories.length;
        categoryIndex++
      ) {
        if (categories[categoryIndex].category.sentiment !=
            SimpleLikertSentiment.neutral) {
          continue;
        }
        final displayedValue = values.values[categoryIndex];
        final width = displayedValue * scale;
        segments.add(
          _LikertSegmentLayout(
            item: item,
            category: categories[categoryIndex],
            itemIndex: itemIndex,
            categoryIndex: categoryIndex,
            rawValue: item.values[categoryIndex],
            displayedValue: displayedValue,
            share: values.total <= 0
                ? 0
                : item.values[categoryIndex] / values.total,
            rect: Rect.fromLTWH(
              neutralCursor,
              barRect.top,
              math.max(0, width),
              barRect.height,
            ),
          ),
        );
        neutralCursor += width;
      }

      var positiveCursor = centerX;
      for (
        var categoryIndex = 0;
        categoryIndex < categories.length;
        categoryIndex++
      ) {
        if (categories[categoryIndex].category.sentiment !=
            SimpleLikertSentiment.positive) {
          continue;
        }
        final displayedValue = values.values[categoryIndex];
        final width = displayedValue * scale;
        segments.add(
          _LikertSegmentLayout(
            item: item,
            category: categories[categoryIndex],
            itemIndex: itemIndex,
            categoryIndex: categoryIndex,
            rawValue: item.values[categoryIndex],
            displayedValue: displayedValue,
            share: values.total <= 0
                ? 0
                : item.values[categoryIndex] / values.total,
            rect: Rect.fromLTWH(
              positiveCursor,
              barRect.top,
              math.max(0, width),
              barRect.height,
            ),
          ),
        );
        positiveCursor += width;
      }

      rows.add(
        _LikertRowLayout(item: item, barRect: barRect, segments: segments),
      );
    }

    return _LikertGeometry(
      plot: plot,
      centerX: centerX,
      maxSide: maxSide,
      rows: rows,
    );
  }
}

class _LikertCategoryEntry {
  final SimpleLikertCategory category;
  final int originalIndex;

  const _LikertCategoryEntry(this.category, this.originalIndex);
}

class _LikertItemEntry {
  final SimpleLikertItem item;
  final int originalIndex;
  final List<double> values;

  const _LikertItemEntry(this.item, this.originalIndex, this.values);
}

class _LikertRowValues {
  final List<double> values;
  final double total;
  final double negative;
  final double neutral;
  final double positive;

  const _LikertRowValues({
    required this.values,
    required this.total,
    required this.negative,
    required this.neutral,
    required this.positive,
  });
}

class _LikertRowLayout {
  final _LikertItemEntry item;
  final Rect barRect;
  final List<_LikertSegmentLayout> segments;

  const _LikertRowLayout({
    required this.item,
    required this.barRect,
    required this.segments,
  });
}

class _LikertSegmentLayout {
  final _LikertItemEntry item;
  final _LikertCategoryEntry category;
  final int itemIndex;
  final int categoryIndex;
  final double rawValue;
  final double displayedValue;
  final double share;
  final Rect rect;

  const _LikertSegmentLayout({
    required this.item,
    required this.category,
    required this.itemIndex,
    required this.categoryIndex,
    required this.rawValue,
    required this.displayedValue,
    required this.share,
    required this.rect,
  });
}

class _LikertSelection {
  final _LikertItemEntry item;
  final _LikertCategoryEntry category;
  final int itemIndex;
  final int categoryIndex;
  final Offset position;
  final double displayedValue;
  final double share;

  const _LikertSelection({
    required this.item,
    required this.category,
    required this.itemIndex,
    required this.categoryIndex,
    required this.position,
    required this.displayedValue,
    required this.share,
  });

  @override
  bool operator ==(Object other) {
    return other is _LikertSelection &&
        other.itemIndex == itemIndex &&
        other.categoryIndex == categoryIndex &&
        other.position == position;
  }

  @override
  int get hashCode => Object.hash(itemIndex, categoryIndex, position);
}

class _SimpleLikertVisuals {
  final List<Color> negativePalette;
  final Color neutralColor;
  final List<Color> positivePalette;
  final Color gridColor;
  final Color axisColor;

  const _SimpleLikertVisuals({
    required this.negativePalette,
    required this.neutralColor,
    required this.positivePalette,
    required this.gridColor,
    required this.axisColor,
  });

  static _SimpleLikertVisuals resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    final grid = colorScheme.outlineVariant.withValues(alpha: 0.54);
    final axis = colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleLikertVisuals(
          negativePalette: const [Color(0xFFDC2626), Color(0xFFF97316)],
          neutralColor: const Color(0xFF94A3B8),
          positivePalette: const [Color(0xFF14B8A6), Color(0xFF2563EB)],
          gridColor: grid,
          axisColor: axis,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleLikertVisuals(
          negativePalette: const [Color(0xFFB91C1C), Color(0xFFD97706)],
          neutralColor: const Color(0xFF94A3B8),
          positivePalette: const [Color(0xFF059669), Color(0xFF0F766E)],
          gridColor: grid,
          axisColor: axis,
        );
      case SimpleBarChartStyle.education:
        return _SimpleLikertVisuals(
          negativePalette: const [Color(0xFFEA580C), Color(0xFFFACC15)],
          neutralColor: const Color(0xFFA8A29E),
          positivePalette: const [Color(0xFF22C55E), Color(0xFF3B82F6)],
          gridColor: grid,
          axisColor: axis,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleLikertVisuals(
          negativePalette: const [Color(0xFFF43F5E), Color(0xFFF97316)],
          neutralColor: const Color(0xFFA78BFA),
          positivePalette: const [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
          gridColor: grid,
          axisColor: axis,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleLikertVisuals(
          negativePalette: const [Color(0xFFBE123C), Color(0xFFF59E0B)],
          neutralColor: const Color(0xFFCBD5E1),
          positivePalette: const [Color(0xFF059669), Color(0xFF0D9488)],
          gridColor: grid,
          axisColor: axis,
        );
    }
  }
}

class _DefaultLikertTooltip extends StatelessWidget {
  final Color color;
  final String itemLabel;
  final String categoryLabel;
  final String formattedValue;
  final String formattedShare;

  const _DefaultLikertTooltip({
    required this.color,
    required this.itemLabel,
    required this.categoryLabel,
    required this.formattedValue,
    required this.formattedShare,
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
                    itemLabel,
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
              categoryLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _LikertTooltipRow(label: 'Value', value: formattedValue),
            _LikertTooltipRow(label: 'Share', value: formattedShare),
          ],
        ),
      ),
    );
  }
}

class _LikertTooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _LikertTooltipRow({required this.label, required this.value});

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

Size _measureText(String text, TextStyle style, double maxWidth) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  return painter.size;
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
