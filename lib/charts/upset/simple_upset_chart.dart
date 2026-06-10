import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleUpsetValueFormatter = String Function(double value);
typedef SimpleUpsetIntersectionTapCallback =
    void Function(SimpleUpsetIntersection intersection, int index);
typedef SimpleUpsetTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleUpsetIntersection intersection,
      int index,
      String title,
      String formattedValue,
    );

class SimpleUpsetSet {
  final String id;
  final String label;
  final double? value;
  final Color? color;

  const SimpleUpsetSet({
    required this.id,
    required this.label,
    this.value,
    this.color,
  });
}

class SimpleUpsetIntersection {
  final List<String> setIds;
  final double value;
  final String? label;
  final Color? color;

  const SimpleUpsetIntersection({
    required this.setIds,
    required this.value,
    this.label,
    this.color,
  });
}

/// A compact UpSet chart for ranked set intersections when Venn diagrams become
/// too crowded for dashboards and reports.
class SimpleUpsetChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(88, 18, 18, 34);

  final List<SimpleUpsetSet> sets;
  final List<SimpleUpsetIntersection> intersections;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? barColor;
  final Color? dotColor;
  final Color? inactiveDotColor;
  final Color? connectorColor;
  final Color? activeColor;
  final Color? gridColor;
  final Color? axisColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool sortByValue;
  final bool showGrid;
  final bool showSetLabels;
  final bool showIntersectionLabels;
  final bool showValues;
  final bool showSetTotals;
  final bool showTooltip;
  final bool showActiveIntersection;
  final int? maxIntersections;
  final int gridLineCount;
  final double dotRadius;
  final double barRadius;
  final double matrixGap;
  final SimpleUpsetValueFormatter? valueFormatter;
  final SimpleUpsetIntersectionTapCallback? onIntersectionTap;
  final SimpleUpsetTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleUpsetChart({
    super.key,
    required this.sets,
    required this.intersections,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.barColor,
    this.dotColor,
    this.inactiveDotColor,
    this.connectorColor,
    this.activeColor,
    this.gridColor,
    this.axisColor,
    this.labelStyle,
    this.valueStyle,
    this.sortByValue = true,
    this.showGrid = true,
    this.showSetLabels = true,
    this.showIntersectionLabels = true,
    this.showValues = true,
    this.showSetTotals = true,
    this.showTooltip = true,
    this.showActiveIntersection = true,
    this.maxIntersections,
    this.gridLineCount = 4,
    this.dotRadius = 4.5,
    this.barRadius = 4,
    this.matrixGap = 12,
    this.valueFormatter,
    this.onIntersectionTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(dotRadius >= 0),
       assert(barRadius >= 0),
       assert(matrixGap >= 0),
       assert(maxIntersections == null || maxIntersections > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleUpsetVisuals.resolve(style, colorScheme);
    final visibleSets = sets
        .where((set) => set.id.trim().isNotEmpty && set.label.trim().isNotEmpty)
        .toList();
    final visibleIds = visibleSets.map((set) => set.id).toSet();
    var visibleIntersections = intersections.where((intersection) {
      final ids = _normalizedIds(intersection.setIds);
      return ids.isNotEmpty &&
          ids.every(visibleIds.contains) &&
          intersection.value.isFinite &&
          intersection.value > 0;
    }).toList();
    if (sortByValue) {
      visibleIntersections.sort((a, b) {
        final valueCompare = b.value.compareTo(a.value);
        if (valueCompare != 0) return valueCompare;
        return _intersectionTitle(
          a,
          visibleSets,
        ).compareTo(_intersectionTitle(b, visibleSets));
      });
    }
    final limit = maxIntersections;
    if (limit != null && visibleIntersections.length > limit) {
      visibleIntersections = visibleIntersections.take(limit).toList();
    }
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleSets.isEmpty || visibleIntersections.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'UpSet chart, no data.',
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

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleSets,
            visibleIntersections,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleUpsetChartView(
            width: width,
            height: chartHeight,
            sets: visibleSets,
            intersections: visibleIntersections,
            padding: padding,
            palette: palette,
            barColor: barColor ?? visuals.barColor,
            dotColor: dotColor ?? visuals.dotColor,
            inactiveDotColor: inactiveDotColor ?? visuals.inactiveDotColor,
            connectorColor: connectorColor ?? visuals.connectorColor,
            activeColor: activeColor ?? visuals.activeColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showSetLabels: showSetLabels,
            showIntersectionLabels: showIntersectionLabels,
            showValues: showValues,
            showSetTotals: showSetTotals,
            showTooltip: showTooltip,
            showActiveIntersection: showActiveIntersection,
            gridLineCount: gridLineCount,
            dotRadius: dotRadius,
            barRadius: barRadius,
            matrixGap: matrixGap,
            valueFormatter: formatter,
            onIntersectionTap: onIntersectionTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static List<String> _normalizedIds(List<String> ids) {
    final seen = <String>{};
    final result = <String>[];
    for (final id in ids) {
      final value = id.trim();
      if (value.isNotEmpty && seen.add(value)) {
        result.add(value);
      }
    }
    result.sort();
    return result;
  }

  static String _intersectionTitle(
    SimpleUpsetIntersection intersection,
    List<SimpleUpsetSet> sets,
  ) {
    if (intersection.label != null && intersection.label!.trim().isNotEmpty) {
      return intersection.label!;
    }
    final labelsById = {for (final set in sets) set.id: set.label};
    return _normalizedIds(
      intersection.setIds,
    ).map((id) => labelsById[id] ?? id).join(' + ');
  }

  static String _defaultSemanticLabel(
    List<SimpleUpsetSet> sets,
    List<SimpleUpsetIntersection> intersections,
    SimpleUpsetValueFormatter formatter,
  ) {
    final sample = intersections
        .take(5)
        .map((intersection) {
          final title = _intersectionTitle(intersection, sets);
          return '$title ${formatter(intersection.value)}';
        })
        .join(', ');
    final suffix = intersections.length > 5
        ? ', and ${intersections.length - 5} more'
        : '';
    return 'UpSet chart, ${sets.length} sets and ${intersections.length} '
        'intersections. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value >= 1000) {
      final precision = value >= 10000 ? 0 : 1;
      return '${(value / 1000).toStringAsFixed(precision)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleUpsetChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleUpsetSet> sets;
  final List<SimpleUpsetIntersection> intersections;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color barColor;
  final Color dotColor;
  final Color inactiveDotColor;
  final Color connectorColor;
  final Color activeColor;
  final Color gridColor;
  final Color axisColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showSetLabels;
  final bool showIntersectionLabels;
  final bool showValues;
  final bool showSetTotals;
  final bool showTooltip;
  final bool showActiveIntersection;
  final int gridLineCount;
  final double dotRadius;
  final double barRadius;
  final double matrixGap;
  final SimpleUpsetValueFormatter valueFormatter;
  final SimpleUpsetIntersectionTapCallback? onIntersectionTap;
  final SimpleUpsetTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleUpsetChartView({
    required this.width,
    required this.height,
    required this.sets,
    required this.intersections,
    required this.padding,
    required this.palette,
    required this.barColor,
    required this.dotColor,
    required this.inactiveDotColor,
    required this.connectorColor,
    required this.activeColor,
    required this.gridColor,
    required this.axisColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showSetLabels,
    required this.showIntersectionLabels,
    required this.showValues,
    required this.showSetTotals,
    required this.showTooltip,
    required this.showActiveIntersection,
    required this.gridLineCount,
    required this.dotRadius,
    required this.barRadius,
    required this.matrixGap,
    required this.valueFormatter,
    required this.onIntersectionTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleUpsetChartView> createState() => _SimpleUpsetChartViewState();
}

class _SimpleUpsetChartViewState extends State<_SimpleUpsetChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _UpsetHit? _activeHit;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _SimpleUpsetChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intersections != widget.intersections ||
        oldWidget.sets != widget.sets ||
        oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.animationCurve != widget.animationCurve) {
      _controller.duration = widget.animationDuration;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onExit: (_) => _setActive(null),
                  onHover: (event) {
                    if (widget.showActiveIntersection ||
                        widget.showTooltip ||
                        widget.onIntersectionTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit != null) {
                        widget.onIntersectionTap?.call(
                          hit.intersection,
                          hit.index,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleUpsetPainter(
                        sets: widget.sets,
                        intersections: widget.intersections,
                        padding: widget.padding,
                        palette: widget.palette,
                        barColor: widget.barColor,
                        dotColor: widget.dotColor,
                        inactiveDotColor: widget.inactiveDotColor,
                        connectorColor: widget.connectorColor,
                        activeColor: widget.activeColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showSetLabels: widget.showSetLabels,
                        showIntersectionLabels: widget.showIntersectionLabels,
                        showValues: widget.showValues,
                        showSetTotals: widget.showSetTotals,
                        showActiveIntersection: widget.showActiveIntersection,
                        gridLineCount: widget.gridLineCount,
                        dotRadius: widget.dotRadius,
                        barRadius: widget.barRadius,
                        matrixGap: widget.matrixGap,
                        valueFormatter: widget.valueFormatter,
                        activeIndex: _activeHit?.index,
                        progress: _animation.value,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeHit != null)
                _buildTooltip(context, _activeHit!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_UpsetHit? hit) {
    if (_activeHit?.index == hit?.index) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _UpsetHit? _hitTest(Offset position) {
    final geometry = _UpsetGeometry.resolve(
      sets: widget.sets,
      intersections: widget.intersections,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      matrixGap: widget.matrixGap,
    );
    for (final hit in geometry.hits) {
      if (hit.hitRect.contains(position)) {
        return hit;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _UpsetHit hit) {
    final title = SimpleUpsetChart._intersectionTitle(
      hit.intersection,
      widget.sets,
    );
    final formattedValue = widget.valueFormatter(hit.intersection.value);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          hit.intersection,
          hit.index,
          title,
          formattedValue,
        ) ??
        _DefaultUpsetTooltip(
          title: title,
          rows: [
            _TooltipRow('Sets', _setNames(hit.intersection)),
            _TooltipRow('Value', formattedValue),
          ],
        );
    final left = (hit.center.dx + 12).clamp(8.0, widget.width - 214);
    final top = (hit.center.dy - 50).clamp(8.0, widget.height - 116);
    return Positioned(left: left, top: top, child: tooltip);
  }

  String _setNames(SimpleUpsetIntersection intersection) {
    final labelsById = {for (final set in widget.sets) set.id: set.label};
    return SimpleUpsetChart._normalizedIds(
      intersection.setIds,
    ).map((id) => labelsById[id] ?? id).join(', ');
  }
}

class _SimpleUpsetPainter extends CustomPainter {
  final List<SimpleUpsetSet> sets;
  final List<SimpleUpsetIntersection> intersections;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color barColor;
  final Color dotColor;
  final Color inactiveDotColor;
  final Color connectorColor;
  final Color activeColor;
  final Color gridColor;
  final Color axisColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showSetLabels;
  final bool showIntersectionLabels;
  final bool showValues;
  final bool showSetTotals;
  final bool showActiveIntersection;
  final int gridLineCount;
  final double dotRadius;
  final double barRadius;
  final double matrixGap;
  final SimpleUpsetValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleUpsetPainter({
    required this.sets,
    required this.intersections,
    required this.padding,
    required this.palette,
    required this.barColor,
    required this.dotColor,
    required this.inactiveDotColor,
    required this.connectorColor,
    required this.activeColor,
    required this.gridColor,
    required this.axisColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showSetLabels,
    required this.showIntersectionLabels,
    required this.showValues,
    required this.showSetTotals,
    required this.showActiveIntersection,
    required this.gridLineCount,
    required this.dotRadius,
    required this.barRadius,
    required this.matrixGap,
    required this.valueFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _UpsetGeometry.resolve(
      sets: sets,
      intersections: intersections,
      size: size,
      padding: padding,
      matrixGap: matrixGap,
    );
    if (geometry.hits.isEmpty) {
      return;
    }

    if (showGrid) {
      _drawGrid(canvas, geometry);
    }
    if (showSetLabels) {
      _drawSetLabels(canvas, geometry);
    }
    for (final hit in geometry.hits) {
      _drawColumn(canvas, geometry, hit);
    }
    if (showIntersectionLabels) {
      _drawIntersectionLabels(canvas, geometry);
    }
  }

  void _drawGrid(Canvas canvas, _UpsetGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 0; index < gridLineCount; index++) {
      final ratio = gridLineCount == 1 ? 0.0 : index / (gridLineCount - 1);
      final y = geometry.barPlot.bottom - geometry.barPlot.height * ratio;
      canvas.drawLine(
        Offset(geometry.barPlot.left, y),
        Offset(geometry.barPlot.right, y),
        paint,
      );
    }
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.barPlot.bottom),
      Offset(geometry.plot.right, geometry.barPlot.bottom),
      Paint()
        ..color = axisColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    for (final row in geometry.setRows) {
      canvas.drawLine(
        Offset(geometry.plot.left, row.center.dy),
        Offset(geometry.plot.right, row.center.dy),
        Paint()
          ..color = gridColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _drawSetLabels(Canvas canvas, _UpsetGeometry geometry) {
    final totals = _setTotals();
    final maxTotal = totals.values.fold<double>(0, math.max);
    for (var index = 0; index < sets.length; index++) {
      final set = sets[index];
      final row = geometry.setRows[index];
      final color = _colorForSet(index);
      final labelRect = Rect.fromLTRB(
        0,
        row.top,
        math.max(0, geometry.plot.left - 10),
        row.bottom,
      );
      _drawText(
        canvas,
        set.label,
        labelRect,
        labelStyle.copyWith(color: color),
        align: TextAlign.right,
      );
      if (showSetTotals && geometry.plot.left > 68) {
        final total = set.value ?? totals[set.id] ?? 0;
        final width = maxTotal <= 0
            ? 0.0
            : (geometry.plot.left - 16) * (total / maxTotal).clamp(0.0, 1.0);
        final barRect = Rect.fromLTWH(
          math.max(0, geometry.plot.left - 8 - width),
          row.center.dy + 6,
          width,
          3,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, const Radius.circular(1.5)),
          Paint()
            ..color = color.withValues(alpha: 0.28)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _drawColumn(Canvas canvas, _UpsetGeometry geometry, _UpsetHit hit) {
    final active = showActiveIntersection && activeIndex == hit.index;
    final color = active
        ? activeColor
        : hit.intersection.color ?? _colorForIntersection(hit);
    final barHeight = hit.barRect.height * progress;
    final barRect = Rect.fromLTRB(
      hit.barRect.left,
      hit.barRect.bottom - barHeight,
      hit.barRect.right,
      hit.barRect.bottom,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, Radius.circular(barRadius)),
      Paint()
        ..color = color.withValues(alpha: active ? 1 : 0.86)
        ..style = PaintingStyle.fill,
    );

    if (showValues && geometry.columnWidth > 22 && barRect.height > 0) {
      _drawText(
        canvas,
        valueFormatter(hit.intersection.value),
        Rect.fromCenter(
          center: Offset(hit.center.dx, barRect.top - 8),
          width: math.min(48, geometry.columnWidth + 8),
          height: 14,
        ),
        valueStyle.copyWith(color: color),
        align: TextAlign.center,
      );
    }

    final memberRows = <double>[];
    for (var setIndex = 0; setIndex < sets.length; setIndex++) {
      final row = geometry.setRows[setIndex];
      final member = hit.setIds.contains(sets[setIndex].id);
      if (member) {
        memberRows.add(row.center.dy);
      }
      canvas.drawCircle(
        Offset(hit.center.dx, row.center.dy),
        dotRadius * progress,
        Paint()
          ..color = member
              ? color.withValues(alpha: active ? 1 : 0.9)
              : inactiveDotColor
          ..style = PaintingStyle.fill,
      );
    }
    if (memberRows.length >= 2) {
      canvas.drawLine(
        Offset(hit.center.dx, memberRows.first),
        Offset(hit.center.dx, memberRows.last),
        Paint()
          ..color = (active ? activeColor : connectorColor).withValues(
            alpha: active ? 0.78 : 0.48,
          )
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(1.8, dotRadius * 0.62) * progress,
      );
    }
  }

  void _drawIntersectionLabels(Canvas canvas, _UpsetGeometry geometry) {
    if (geometry.columnWidth < 28) {
      return;
    }
    for (final hit in geometry.hits) {
      final title = SimpleUpsetChart._intersectionTitle(hit.intersection, sets);
      _drawText(
        canvas,
        title,
        Rect.fromCenter(
          center: Offset(hit.center.dx, geometry.matrixPlot.bottom + 9),
          width: math.min(76, geometry.columnWidth + 16),
          height: 16,
        ),
        valueStyle.copyWith(color: axisColor),
        align: TextAlign.center,
      );
    }
  }

  Map<String, double> _setTotals() {
    final totals = <String, double>{for (final set in sets) set.id: 0};
    for (final intersection in intersections) {
      final ids = SimpleUpsetChart._normalizedIds(intersection.setIds);
      for (final id in ids) {
        totals[id] = (totals[id] ?? 0) + intersection.value;
      }
    }
    return totals;
  }

  Color _colorForIntersection(_UpsetHit hit) {
    if (hit.setIds.length == 1) {
      final setIndex = sets.indexWhere((set) => set.id == hit.setIds.first);
      if (setIndex >= 0) {
        return _colorForSet(setIndex);
      }
    }
    return barColor;
  }

  Color _colorForSet(int index) {
    if (sets[index].color != null) {
      return sets[index].color!;
    }
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return dotColor;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: rect.width);
    final dx = switch (align) {
      TextAlign.right => rect.right - painter.width,
      TextAlign.center => rect.left + (rect.width - painter.width) / 2,
      _ => rect.left,
    };
    final dy = rect.top + (rect.height - painter.height) / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _SimpleUpsetPainter oldDelegate) {
    return oldDelegate.sets != sets ||
        oldDelegate.intersections != intersections ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.barColor != barColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.inactiveDotColor != inactiveDotColor ||
        oldDelegate.connectorColor != connectorColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showSetLabels != showSetLabels ||
        oldDelegate.showIntersectionLabels != showIntersectionLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showSetTotals != showSetTotals ||
        oldDelegate.showActiveIntersection != showActiveIntersection ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.matrixGap != matrixGap ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _UpsetGeometry {
  final Rect plot;
  final Rect barPlot;
  final Rect matrixPlot;
  final List<Rect> setRows;
  final List<_UpsetHit> hits;
  final double columnWidth;

  const _UpsetGeometry({
    required this.plot,
    required this.barPlot,
    required this.matrixPlot,
    required this.setRows,
    required this.hits,
    required this.columnWidth,
  });

  factory _UpsetGeometry.resolve({
    required List<SimpleUpsetSet> sets,
    required List<SimpleUpsetIntersection> intersections,
    required Size size,
    required EdgeInsets padding,
    required double matrixGap,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    if (sets.isEmpty ||
        intersections.isEmpty ||
        plot.width <= 0 ||
        plot.height <= 0) {
      return _UpsetGeometry(
        plot: plot,
        barPlot: plot,
        matrixPlot: plot,
        setRows: const [],
        hits: const [],
        columnWidth: 0,
      );
    }

    final barHeight = math.max(44.0, plot.height * 0.52);
    final resolvedBarHeight = math.min(barHeight, plot.height - matrixGap - 28);
    final barPlot = Rect.fromLTWH(
      plot.left,
      plot.top,
      plot.width,
      math.max(24.0, resolvedBarHeight),
    );
    final matrixTop = math.min(plot.bottom, barPlot.bottom + matrixGap);
    final matrixPlot = Rect.fromLTRB(
      plot.left,
      matrixTop,
      plot.right,
      plot.bottom,
    );
    final rowHeight = matrixPlot.height / sets.length;
    final setRows = List<Rect>.generate(sets.length, (index) {
      return Rect.fromLTWH(
        matrixPlot.left,
        matrixPlot.top + rowHeight * index,
        matrixPlot.width,
        rowHeight,
      );
    });
    final columnWidth = plot.width / intersections.length;
    final maxValue = intersections.fold<double>(
      0,
      (maxValue, intersection) => math.max(maxValue, intersection.value),
    );
    final hits = <_UpsetHit>[];
    for (var index = 0; index < intersections.length; index++) {
      final intersection = intersections[index];
      final centerX = plot.left + columnWidth * (index + 0.5);
      final barWidth = math.max(3.0, math.min(columnWidth * 0.58, 34.0));
      final barHeight = maxValue <= 0
          ? 0.0
          : barPlot.height * (intersection.value / maxValue).clamp(0.0, 1.0);
      final barRect = Rect.fromLTWH(
        centerX - barWidth / 2,
        barPlot.bottom - barHeight,
        barWidth,
        barHeight,
      );
      final hitRect = Rect.fromLTRB(
        math.max(plot.left, centerX - columnWidth / 2),
        barPlot.top,
        math.min(plot.right, centerX + columnWidth / 2),
        matrixPlot.bottom,
      );
      hits.add(
        _UpsetHit(
          index: index,
          intersection: intersection,
          setIds: SimpleUpsetChart._normalizedIds(intersection.setIds).toSet(),
          center: Offset(centerX, (barPlot.bottom + matrixPlot.top) / 2),
          barRect: barRect,
          hitRect: hitRect,
        ),
      );
    }
    return _UpsetGeometry(
      plot: plot,
      barPlot: barPlot,
      matrixPlot: matrixPlot,
      setRows: setRows,
      hits: hits,
      columnWidth: columnWidth,
    );
  }
}

class _UpsetHit {
  final int index;
  final SimpleUpsetIntersection intersection;
  final Set<String> setIds;
  final Offset center;
  final Rect barRect;
  final Rect hitRect;

  const _UpsetHit({
    required this.index,
    required this.intersection,
    required this.setIds,
    required this.center,
    required this.barRect,
    required this.hitRect,
  });
}

class _SimpleUpsetVisuals {
  final Color barColor;
  final Color dotColor;
  final Color inactiveDotColor;
  final Color connectorColor;
  final Color activeColor;
  final Color gridColor;
  final Color axisColor;

  const _SimpleUpsetVisuals({
    required this.barColor,
    required this.dotColor,
    required this.inactiveDotColor,
    required this.connectorColor,
    required this.activeColor,
    required this.gridColor,
    required this.axisColor,
  });

  factory _SimpleUpsetVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleUpsetVisuals(
          barColor: colorScheme.primary,
          dotColor: colorScheme.primary,
          inactiveDotColor: colorScheme.outlineVariant,
          connectorColor: colorScheme.primary,
          activeColor: colorScheme.tertiary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.58),
          axisColor: colorScheme.outline.withValues(alpha: 0.52),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleUpsetVisuals(
          barColor: colorScheme.primary,
          dotColor: colorScheme.onSurfaceVariant,
          inactiveDotColor: colorScheme.outlineVariant,
          connectorColor: colorScheme.onSurfaceVariant,
          activeColor: colorScheme.onSurface,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.68),
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
        );
      case SimpleBarChartStyle.education:
        return _SimpleUpsetVisuals(
          barColor: colorScheme.secondary,
          dotColor: colorScheme.secondary,
          inactiveDotColor: colorScheme.outlineVariant,
          connectorColor: colorScheme.secondary,
          activeColor: colorScheme.primary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.56),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleUpsetVisuals(
          barColor: colorScheme.tertiary,
          dotColor: colorScheme.tertiary,
          inactiveDotColor: colorScheme.outlineVariant,
          connectorColor: colorScheme.tertiary,
          activeColor: colorScheme.primary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.52),
          axisColor: colorScheme.outline.withValues(alpha: 0.42),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleUpsetVisuals(
          barColor: colorScheme.primary,
          dotColor: colorScheme.primary,
          inactiveDotColor: colorScheme.outlineVariant,
          connectorColor: colorScheme.primary,
          activeColor: colorScheme.tertiary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.56),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
        );
    }
  }
}

class _DefaultUpsetTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultUpsetTooltip({required this.title, required this.rows});

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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 42, child: Text(row.label)),
                        Flexible(
                          child: Text(
                            row.value,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TooltipRow {
  final String label;
  final String value;

  const _TooltipRow(this.label, this.value);
}
