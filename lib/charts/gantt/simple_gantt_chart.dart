import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleGanttDateFormatter = String Function(DateTime date);
typedef SimpleGanttProgressFormatter = String Function(double progress);
typedef SimpleGanttTapCallback = void Function(SimpleGanttTask task, int index);
typedef SimpleGanttTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleGanttTask task,
      int index,
      String formattedStart,
      String formattedEnd,
      String formattedProgress,
    );

class SimpleGanttTask {
  final String id;
  final String label;
  final DateTime start;
  final DateTime end;
  final double progress;
  final String? group;
  final List<String> dependencies;
  final bool isMilestone;
  final Color? color;

  const SimpleGanttTask({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    this.progress = 0,
    this.group,
    this.dependencies = const [],
    this.isMilestone = false,
    this.color,
  });

  DateTime get low => start.isBefore(end) ? start : end;
  DateTime get high => start.isBefore(end) ? end : start;
}

/// A simple Gantt chart for project plans, roadmaps, curriculum schedules, and
/// operational timelines.
class SimpleGanttChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(
    112,
    22,
    22,
    38,
  );

  final List<SimpleGanttTask> tasks;
  final SimpleBarChartStyle style;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? today;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? barColor;
  final Color? progressColor;
  final Color? milestoneColor;
  final Color? dependencyColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? todayColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool sortByStart;
  final bool showGrid;
  final bool showLabels;
  final bool showDates;
  final bool showProgress;
  final bool showDependencies;
  final bool showToday;
  final bool showTooltip;
  final bool showActiveTask;
  final int tickCount;
  final double rowHeight;
  final double? barHeight;
  final double barRadius;
  final SimpleGanttDateFormatter? dateFormatter;
  final SimpleGanttProgressFormatter? progressFormatter;
  final SimpleGanttTapCallback? onTaskTap;
  final SimpleGanttTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleGanttChart({
    super.key,
    required this.tasks,
    this.style = SimpleBarChartStyle.elegant,
    this.minDate,
    this.maxDate,
    this.today,
    this.height = 280,
    this.padding = _defaultPadding,
    this.palette,
    this.barColor,
    this.progressColor,
    this.milestoneColor,
    this.dependencyColor,
    this.gridColor,
    this.axisColor,
    this.todayColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.sortByStart = true,
    this.showGrid = true,
    this.showLabels = true,
    this.showDates = true,
    this.showProgress = true,
    this.showDependencies = true,
    this.showToday = true,
    this.showTooltip = true,
    this.showActiveTask = true,
    this.tickCount = 4,
    this.rowHeight = 34,
    this.barHeight,
    this.barRadius = 5,
    this.dateFormatter,
    this.progressFormatter,
    this.onTaskTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(tickCount >= 2),
       assert(rowHeight > 0),
       assert(barHeight == null || barHeight > 0),
       assert(barRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleGanttVisuals.resolve(style, colorScheme);
    final visibleTasks = tasks
        .where(
          (task) => task.id.trim().isNotEmpty && task.label.trim().isNotEmpty,
        )
        .toList();
    if (sortByStart) {
      visibleTasks.sort((a, b) {
        final dateCompare = a.low.compareTo(b.low);
        if (dateCompare != 0) return dateCompare;
        return a.label.compareTo(b.label);
      });
    }
    final resolvedDateFormatter = dateFormatter ?? _defaultDateFormatter;
    final resolvedProgressFormatter =
        progressFormatter ?? _defaultProgressFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleTasks.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Gantt chart, no data.',
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
        final resolvedPalette = _resolvePalette(colorScheme, visuals.barColor);

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleTasks,
            resolvedDateFormatter,
            resolvedProgressFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleGanttChartView(
            width: width,
            height: chartHeight,
            tasks: visibleTasks,
            minDate: minDate,
            maxDate: maxDate,
            today: today,
            padding: padding,
            palette: resolvedPalette,
            barColor: barColor ?? visuals.barColor,
            progressColor: progressColor ?? visuals.progressColor,
            milestoneColor: milestoneColor ?? visuals.milestoneColor,
            dependencyColor: dependencyColor ?? visuals.dependencyColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            todayColor: todayColor ?? visuals.todayColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showLabels: showLabels,
            showDates: showDates,
            showProgress: showProgress,
            showDependencies: showDependencies,
            showToday: showToday,
            showTooltip: showTooltip,
            showActiveTask: showActiveTask,
            tickCount: tickCount,
            rowHeight: rowHeight,
            barHeight: barHeight,
            barRadius: barRadius,
            dateFormatter: resolvedDateFormatter,
            progressFormatter: resolvedProgressFormatter,
            onTaskTap: onTaskTap,
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
    List<SimpleGanttTask> visibleTasks,
    SimpleGanttDateFormatter resolvedDateFormatter,
    SimpleGanttProgressFormatter resolvedProgressFormatter,
  ) {
    final visibleItems = visibleTasks
        .take(6)
        .map((task) {
          final milestone = task.isMilestone ? ', milestone' : '';
          return '${task.label} ${resolvedDateFormatter(task.low)} to '
              '${resolvedDateFormatter(task.high)}, '
              '${resolvedProgressFormatter(_normalizedProgress(task.progress))}'
              '$milestone';
        })
        .join('; ');
    final remaining = visibleTasks.length - math.min(visibleTasks.length, 6);
    final suffix = remaining > 0 ? '; and $remaining more' : '';
    final countLabel = visibleTasks.length == 1 ? 'task' : 'tasks';
    return 'Gantt chart, ${visibleTasks.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultDateFormatter(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _defaultProgressFormatter(double progress) {
    return '${(progress * 100).round()}%';
  }
}

class _SimpleGanttChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleGanttTask> tasks;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? today;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color barColor;
  final Color progressColor;
  final Color milestoneColor;
  final Color dependencyColor;
  final Color gridColor;
  final Color axisColor;
  final Color todayColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showDates;
  final bool showProgress;
  final bool showDependencies;
  final bool showToday;
  final bool showTooltip;
  final bool showActiveTask;
  final int tickCount;
  final double rowHeight;
  final double? barHeight;
  final double barRadius;
  final SimpleGanttDateFormatter dateFormatter;
  final SimpleGanttProgressFormatter progressFormatter;
  final SimpleGanttTapCallback? onTaskTap;
  final SimpleGanttTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleGanttChartView({
    required this.width,
    required this.height,
    required this.tasks,
    required this.minDate,
    required this.maxDate,
    required this.today,
    required this.padding,
    required this.palette,
    required this.barColor,
    required this.progressColor,
    required this.milestoneColor,
    required this.dependencyColor,
    required this.gridColor,
    required this.axisColor,
    required this.todayColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showDates,
    required this.showProgress,
    required this.showDependencies,
    required this.showToday,
    required this.showTooltip,
    required this.showActiveTask,
    required this.tickCount,
    required this.rowHeight,
    required this.barHeight,
    required this.barRadius,
    required this.dateFormatter,
    required this.progressFormatter,
    required this.onTaskTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleGanttChartView> createState() => _SimpleGanttChartViewState();
}

class _SimpleGanttChartViewState extends State<_SimpleGanttChartView> {
  _GanttHit? _activeHit;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveTask || widget.onTaskTap != null;

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
                painter: _SimpleGanttPainter(
                  tasks: widget.tasks,
                  minDate: widget.minDate,
                  maxDate: widget.maxDate,
                  today: widget.today,
                  padding: widget.padding,
                  palette: widget.palette,
                  barColor: widget.barColor,
                  progressColor: widget.progressColor,
                  milestoneColor: widget.milestoneColor,
                  dependencyColor: widget.dependencyColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  todayColor: widget.todayColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showLabels: widget.showLabels,
                  showDates: widget.showDates,
                  showProgress: widget.showProgress,
                  showDependencies: widget.showDependencies,
                  showToday: widget.showToday,
                  showActiveTask: widget.showActiveTask,
                  tickCount: widget.tickCount,
                  rowHeight: widget.rowHeight,
                  barHeight: widget.barHeight,
                  barRadius: widget.barRadius,
                  dateFormatter: widget.dateFormatter,
                  progressFormatter: widget.progressFormatter,
                  activeIndex: _activeHit?.index,
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
                      widget.onTaskTap?.call(
                        widget.tasks[hit.index],
                        hit.index,
                      );
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeHit != null)
                _buildTooltip(context, size, _activeHit!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_GanttHit? hit) {
    if (_activeHit == hit) return;
    setState(() => _activeHit = hit);
  }

  _GanttHit? _hitTest(Offset position, Size size) {
    final geometry = _GanttGeometry.resolve(
      size: size,
      tasks: widget.tasks,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      today: widget.today,
      padding: widget.padding,
      rowHeight: widget.rowHeight,
      barHeight: widget.barHeight,
      tickCount: widget.tickCount,
      showToday: widget.showToday,
    );
    for (final hit in geometry.hits.reversed) {
      if (hit.bounds.inflate(8).contains(position)) return hit;
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size, _GanttHit hit) {
    final task = widget.tasks[hit.index];
    final formattedStart = widget.dateFormatter(task.low);
    final formattedEnd = widget.dateFormatter(task.high);
    final formattedProgress = widget.progressFormatter(
      _normalizedProgress(task.progress),
    );
    const tooltipWidth = 198.0;
    const tooltipHeight = 92.0;
    final left = (hit.anchor.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (hit.anchor.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            task,
            hit.index,
            formattedStart,
            formattedEnd,
            formattedProgress,
          ) ??
          _DefaultGanttTooltip(
            color: _taskColor(task, hit.index),
            title: task.label,
            start: formattedStart,
            end: formattedEnd,
            progress: formattedProgress,
            group: task.group,
            milestone: task.isMilestone,
          ),
    );
  }

  Color _taskColor(SimpleGanttTask task, int index) {
    return task.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleGanttPainter extends CustomPainter {
  final List<SimpleGanttTask> tasks;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? today;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color barColor;
  final Color progressColor;
  final Color milestoneColor;
  final Color dependencyColor;
  final Color gridColor;
  final Color axisColor;
  final Color todayColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showDates;
  final bool showProgress;
  final bool showDependencies;
  final bool showToday;
  final bool showActiveTask;
  final int tickCount;
  final double rowHeight;
  final double? barHeight;
  final double barRadius;
  final SimpleGanttDateFormatter dateFormatter;
  final SimpleGanttProgressFormatter progressFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleGanttPainter({
    required this.tasks,
    required this.minDate,
    required this.maxDate,
    required this.today,
    required this.padding,
    required this.palette,
    required this.barColor,
    required this.progressColor,
    required this.milestoneColor,
    required this.dependencyColor,
    required this.gridColor,
    required this.axisColor,
    required this.todayColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showDates,
    required this.showProgress,
    required this.showDependencies,
    required this.showToday,
    required this.showActiveTask,
    required this.tickCount,
    required this.rowHeight,
    required this.barHeight,
    required this.barRadius,
    required this.dateFormatter,
    required this.progressFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _GanttGeometry.resolve(
      size: size,
      tasks: tasks,
      minDate: minDate,
      maxDate: maxDate,
      today: today,
      padding: padding,
      rowHeight: rowHeight,
      barHeight: barHeight,
      tickCount: tickCount,
      showToday: showToday,
    );
    if (geometry.plot.isEmpty || geometry.hits.isEmpty) return;

    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    if (showToday && geometry.todayX != null) _drawToday(canvas, geometry);
    if (showDependencies) _drawDependencies(canvas, geometry);
    _drawTasks(canvas, geometry);
    if (showLabels) _drawLabels(canvas, geometry);
  }

  void _drawGrid(Canvas canvas, _GanttGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= tickCount; index++) {
      final t = index / tickCount;
      final x = geometry.plot.left + geometry.plot.width * t;
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
      );
      if (showDates) {
        final date = geometry.dateAt(t);
        _paintText(
          canvas,
          dateFormatter(date),
          labelStyle.copyWith(
            fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
            color: labelStyle.color?.withValues(alpha: 0.72),
          ),
          Offset(x, geometry.plot.bottom + 8),
          TextAlign.center,
          66,
        );
      }
    }

    for (final hit in geometry.hits) {
      final y = hit.rowCenter;
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        Paint()
          ..color = gridColor.withValues(alpha: 0.42)
          ..strokeWidth = 1,
      );
    }
  }

  void _drawAxis(Canvas canvas, _GanttGeometry geometry) {
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.bottom),
      Offset(geometry.plot.right, geometry.plot.bottom),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );
  }

  void _drawToday(Canvas canvas, _GanttGeometry geometry) {
    final x = geometry.todayX;
    if (x == null) return;
    final paint = Paint()
      ..color = todayColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    _drawDashedLine(
      canvas,
      Offset(x, geometry.plot.top),
      Offset(x, geometry.plot.bottom),
      paint,
    );
  }

  void _drawDependencies(Canvas canvas, _GanttGeometry geometry) {
    final byId = <String, _GanttHit>{};
    for (final hit in geometry.hits) {
      byId[tasks[hit.index].id] = hit;
    }
    final paint = Paint()
      ..color = dependencyColor
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final target in geometry.hits) {
      final targetTask = tasks[target.index];
      for (final dependencyId in targetTask.dependencies) {
        final source = byId[dependencyId];
        if (source == null) continue;
        final start = Offset(source.bounds.right + 4, source.rowCenter);
        final end = Offset(target.bounds.left - 4, target.rowCenter);
        final midX = math.max(start.dx + 8, (start.dx + end.dx) / 2);
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(midX, start.dy)
          ..lineTo(midX, end.dy)
          ..lineTo(end.dx, end.dy);
        canvas.drawPath(path, paint);
        _drawArrow(canvas, end, paint.color);
      }
    }
  }

  void _drawTasks(Canvas canvas, _GanttGeometry geometry) {
    for (final hit in geometry.hits) {
      final task = tasks[hit.index];
      final selected = activeIndex == hit.index;
      final color = _taskColor(task, hit.index);
      final fillColor = selected ? activeColor ?? color : color;
      if (task.isMilestone) {
        _drawMilestone(canvas, hit, fillColor, selected);
      } else {
        _drawBar(canvas, hit, task, fillColor, selected);
      }
    }
  }

  void _drawBar(
    Canvas canvas,
    _GanttHit hit,
    SimpleGanttTask task,
    Color color,
    bool selected,
  ) {
    final animatedRight =
        hit.bounds.left + hit.bounds.width * progress.clamp(0.0, 1.0);
    final animatedRect = Rect.fromLTRB(
      hit.bounds.left,
      hit.bounds.top,
      animatedRight,
      hit.bounds.bottom,
    );
    final radius = Radius.circular(barRadius);
    final baseRRect = RRect.fromRectAndRadius(animatedRect, radius);
    canvas.drawRRect(
      baseRRect,
      Paint()..color = color.withValues(alpha: selected ? 0.96 : 0.78),
    );

    if (showProgress) {
      final pct = _normalizedProgress(task.progress);
      final progressRight = hit.bounds.left + hit.bounds.width * pct * progress;
      final progressRect = Rect.fromLTRB(
        hit.bounds.left,
        hit.bounds.top,
        progressRight,
        hit.bounds.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(progressRect, radius),
        Paint()
          ..color = progressColor.withValues(alpha: selected ? 0.94 : 0.82),
      );
    }

    canvas.drawRRect(
      baseRRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.6 : 0.9,
    );
  }

  void _drawMilestone(
    Canvas canvas,
    _GanttHit hit,
    Color color,
    bool selected,
  ) {
    final radius = hit.bounds.width / 2;
    final center = hit.bounds.center;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = (selected ? activeColor ?? color : milestoneColor).withValues(
          alpha: selected ? 0.98 : 0.88,
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.7 : 1,
    );
  }

  void _drawLabels(Canvas canvas, _GanttGeometry geometry) {
    for (final hit in geometry.hits) {
      final task = tasks[hit.index];
      final selected = activeIndex == hit.index;
      _paintText(
        canvas,
        task.label,
        labelStyle.copyWith(
          color: selected ? valueStyle.color : labelStyle.color,
          fontWeight: selected ? FontWeight.w700 : labelStyle.fontWeight,
        ),
        Offset(padding.left - 10, hit.rowCenter),
        TextAlign.right,
        math.max(0.0, padding.left - 16),
        centeredY: true,
      );
      if (showProgress && !task.isMilestone && hit.bounds.width > 34) {
        _paintText(
          canvas,
          progressFormatter(_normalizedProgress(task.progress)),
          valueStyle.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: math.max(9, (valueStyle.fontSize ?? 11) - 1),
          ),
          hit.bounds.center,
          TextAlign.center,
          hit.bounds.width - 8,
          centeredY: true,
        );
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset tip, Color color) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 5, tip.dy - 3)
      ..lineTo(tip.dx - 5, tip.dy + 3)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final total = (end - start).distance;
    if (total <= 0) return;
    final direction = (end - start) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segmentStart = start + direction * drawn;
      final segmentEnd = start + direction * math.min(total, drawn + 5);
      canvas.drawLine(segmentStart, segmentEnd, paint);
      drawn += 9;
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

  Color _taskColor(SimpleGanttTask task, int index) {
    return task.color ?? palette[index % palette.length];
  }

  @override
  bool shouldRepaint(covariant _SimpleGanttPainter oldDelegate) {
    return oldDelegate.tasks != tasks ||
        oldDelegate.minDate != minDate ||
        oldDelegate.maxDate != maxDate ||
        oldDelegate.today != today ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.barColor != barColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.milestoneColor != milestoneColor ||
        oldDelegate.dependencyColor != dependencyColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.todayColor != todayColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showDates != showDates ||
        oldDelegate.showProgress != showProgress ||
        oldDelegate.showDependencies != showDependencies ||
        oldDelegate.showToday != showToday ||
        oldDelegate.showActiveTask != showActiveTask ||
        oldDelegate.tickCount != tickCount ||
        oldDelegate.rowHeight != rowHeight ||
        oldDelegate.barHeight != barHeight ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.dateFormatter != dateFormatter ||
        oldDelegate.progressFormatter != progressFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _GanttGeometry {
  final Rect plot;
  final DateTime minDate;
  final DateTime maxDate;
  final List<_GanttHit> hits;
  final double? todayX;

  const _GanttGeometry({
    required this.plot,
    required this.minDate,
    required this.maxDate,
    required this.hits,
    required this.todayX,
  });

  factory _GanttGeometry.resolve({
    required Size size,
    required List<SimpleGanttTask> tasks,
    required DateTime? minDate,
    required DateTime? maxDate,
    required DateTime? today,
    required EdgeInsets padding,
    required double rowHeight,
    required double? barHeight,
    required int tickCount,
    required bool showToday,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0 || tasks.isEmpty) {
      final now = DateTime.now();
      return _GanttGeometry(
        plot: plot,
        minDate: minDate ?? now,
        maxDate: maxDate ?? now.add(const Duration(days: 1)),
        hits: const [],
        todayX: null,
      );
    }

    final range = _resolveRange(tasks, minDate, maxDate, today, showToday);
    final effectiveRowHeight = math.min(rowHeight, plot.height / tasks.length);
    final effectiveBarHeight =
        barHeight ?? math.min(18.0, effectiveRowHeight * 0.46);
    final hits = <_GanttHit>[];
    for (var index = 0; index < tasks.length; index++) {
      final task = tasks[index];
      final rowCenter =
          plot.top + effectiveRowHeight * index + effectiveRowHeight / 2;
      final startX = _xForDate(task.low, plot, range.min, range.max);
      final endX = _xForDate(task.high, plot, range.min, range.max);
      final milestone =
          task.isMilestone || task.low.isAtSameMomentAs(task.high);
      final bounds = milestone
          ? Rect.fromCircle(
              center: Offset(startX, rowCenter),
              radius: math.max(6.0, effectiveBarHeight * 0.48),
            )
          : Rect.fromLTRB(
              math.min(startX, endX),
              rowCenter - effectiveBarHeight / 2,
              math.max(startX, endX),
              rowCenter + effectiveBarHeight / 2,
            );
      hits.add(
        _GanttHit(
          index: index,
          bounds: bounds,
          rowCenter: rowCenter,
          anchor: Offset(bounds.right, rowCenter),
        ),
      );
    }
    final todayX = showToday && today != null
        ? _xForDate(today, plot, range.min, range.max)
        : null;
    return _GanttGeometry(
      plot: plot,
      minDate: range.min,
      maxDate: range.max,
      hits: hits,
      todayX: todayX,
    );
  }

  DateTime dateAt(double t) {
    final span = maxDate.difference(minDate).inMilliseconds;
    return minDate.add(Duration(milliseconds: (span * t).round()));
  }

  static _GanttDateRange _resolveRange(
    List<SimpleGanttTask> tasks,
    DateTime? minDate,
    DateTime? maxDate,
    DateTime? today,
    bool showToday,
  ) {
    var lower = tasks.first.low;
    var upper = tasks.first.high;
    for (final task in tasks) {
      if (task.low.isBefore(lower)) lower = task.low;
      if (task.high.isAfter(upper)) upper = task.high;
    }
    if (showToday && today != null) {
      if (today.isBefore(lower)) lower = today;
      if (today.isAfter(upper)) upper = today;
    }
    lower = minDate ?? lower.subtract(const Duration(days: 2));
    upper = maxDate ?? upper.add(const Duration(days: 3));
    if (!upper.isAfter(lower)) {
      upper = lower.add(const Duration(days: 1));
    }
    return _GanttDateRange(lower, upper);
  }

  static double _xForDate(
    DateTime date,
    Rect plot,
    DateTime minDate,
    DateTime maxDate,
  ) {
    final span = maxDate.difference(minDate).inMilliseconds;
    if (span <= 0) return plot.left;
    final offset = date.difference(minDate).inMilliseconds;
    final t = (offset / span).clamp(0.0, 1.0);
    return plot.left + plot.width * t;
  }
}

class _GanttDateRange {
  final DateTime min;
  final DateTime max;

  const _GanttDateRange(this.min, this.max);
}

class _GanttHit {
  final int index;
  final Rect bounds;
  final double rowCenter;
  final Offset anchor;

  const _GanttHit({
    required this.index,
    required this.bounds,
    required this.rowCenter,
    required this.anchor,
  });

  @override
  bool operator ==(Object other) {
    return other is _GanttHit && other.index == index;
  }

  @override
  int get hashCode => index.hashCode;
}

double _normalizedProgress(double value) {
  if (!value.isFinite) return 0;
  if (value > 1 && value <= 100) return (value / 100).clamp(0.0, 1.0);
  return value.clamp(0.0, 1.0).toDouble();
}

class _SimpleGanttVisuals {
  final Color barColor;
  final Color progressColor;
  final Color milestoneColor;
  final Color dependencyColor;
  final Color gridColor;
  final Color axisColor;
  final Color todayColor;

  const _SimpleGanttVisuals({
    required this.barColor,
    required this.progressColor,
    required this.milestoneColor,
    required this.dependencyColor,
    required this.gridColor,
    required this.axisColor,
    required this.todayColor,
  });

  factory _SimpleGanttVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleGanttVisuals(
          barColor: colorScheme.primary,
          progressColor: colorScheme.primaryContainer,
          milestoneColor: colorScheme.tertiary,
          dependencyColor: colorScheme.outline.withValues(alpha: 0.56),
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.52),
          todayColor: colorScheme.error,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleGanttVisuals(
          barColor: colorScheme.primary,
          progressColor: colorScheme.secondary,
          milestoneColor: colorScheme.onSurfaceVariant,
          dependencyColor: colorScheme.outline.withValues(alpha: 0.64),
          gridColor: colorScheme.outline.withValues(alpha: 0.2),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          todayColor: colorScheme.error,
        );
      case SimpleBarChartStyle.education:
        return _SimpleGanttVisuals(
          barColor: colorScheme.secondary,
          progressColor: colorScheme.tertiary,
          milestoneColor: colorScheme.primary,
          dependencyColor: colorScheme.outline.withValues(alpha: 0.52),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          todayColor: colorScheme.error,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleGanttVisuals(
          barColor: colorScheme.tertiary,
          progressColor: colorScheme.primary,
          milestoneColor: colorScheme.secondary,
          dependencyColor: colorScheme.outline.withValues(alpha: 0.5),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          todayColor: colorScheme.error,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleGanttVisuals(
          barColor: colorScheme.primary,
          progressColor: colorScheme.tertiary,
          milestoneColor: colorScheme.secondary,
          dependencyColor: colorScheme.outline.withValues(alpha: 0.54),
          gridColor: colorScheme.outline.withValues(alpha: 0.14),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          todayColor: colorScheme.error,
        );
    }
  }
}

class _DefaultGanttTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String start;
  final String end;
  final String progress;
  final String? group;
  final bool milestone;

  const _DefaultGanttTooltip({
    required this.color,
    required this.title,
    required this.start,
    required this.end,
    required this.progress,
    required this.group,
    required this.milestone,
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
              label: milestone ? 'Date' : 'Start',
              value: start,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            if (!milestone)
              _TooltipRow(
                label: 'End',
                value: end,
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            _TooltipRow(
              label: 'Progress',
              value: progress,
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: color),
            ),
            if (group != null)
              _TooltipRow(
                label: 'Group',
                value: group!,
                labelStyle: labelStyle,
                valueStyle: valueStyle,
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
