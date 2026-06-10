import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleEventStripDateFormatter = String Function(DateTime date);
typedef SimpleEventStripWeightFormatter = String Function(double weight);
typedef SimpleEventStripTapCallback =
    void Function(SimpleEventStripEvent event, int laneIndex, int eventIndex);
typedef SimpleEventStripTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleEventStripEvent event,
      int laneIndex,
      int eventIndex,
      String formattedDate,
      String formattedWeight,
    );

double _clampFinite(double value, double lowerLimit, double upperLimit) {
  final lower = lowerLimit.isFinite ? lowerLimit : 0.0;
  final upper = upperLimit.isFinite ? upperLimit : lower;
  if (upper < lower) return lower;
  if (!value.isFinite) return lower;
  return value.clamp(lower, upper).toDouble();
}

class SimpleEventStripLane {
  final String label;
  final List<SimpleEventStripEvent> events;
  final Color? color;

  const SimpleEventStripLane({
    required this.label,
    required this.events,
    this.color,
  });
}

class SimpleEventStripEvent {
  final DateTime date;
  final String label;
  final String? description;
  final String? tag;
  final double weight;
  final Color? color;

  const SimpleEventStripEvent({
    required this.date,
    required this.label,
    this.description,
    this.tag,
    this.weight = 1,
    this.color,
  });
}

/// A compact time-based event strip for incidents, releases, classes,
/// campaigns, orders, audits, experiments, and activity streams.
class SimpleEventStripChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(86, 20, 24, 38);

  final List<SimpleEventStripLane> lanes;
  final SimpleBarChartStyle style;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? markerDate;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? eventColor;
  final Color? laneColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? markerDateColor;
  final Color? activeColor;
  final Color? laneBackgroundColor;
  final TextStyle? laneLabelStyle;
  final TextStyle? dateStyle;
  final TextStyle? eventLabelStyle;
  final bool sortByDate;
  final bool showGrid;
  final bool showLaneLabels;
  final bool showDates;
  final bool showEventLabels;
  final bool showWeights;
  final bool showMarkerDate;
  final bool showTooltip;
  final bool showActiveEvent;
  final int tickCount;
  final double minEventRadius;
  final double maxEventRadius;
  final double eventOpacity;
  final SimpleEventStripDateFormatter? dateFormatter;
  final SimpleEventStripWeightFormatter? weightFormatter;
  final SimpleEventStripTapCallback? onEventTap;
  final SimpleEventStripTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleEventStripChart({
    super.key,
    required this.lanes,
    this.style = SimpleBarChartStyle.elegant,
    this.minDate,
    this.maxDate,
    this.markerDate,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.eventColor,
    this.laneColor,
    this.gridColor,
    this.axisColor,
    this.markerDateColor,
    this.activeColor,
    this.laneBackgroundColor,
    this.laneLabelStyle,
    this.dateStyle,
    this.eventLabelStyle,
    this.sortByDate = true,
    this.showGrid = true,
    this.showLaneLabels = true,
    this.showDates = true,
    this.showEventLabels = false,
    this.showWeights = true,
    this.showMarkerDate = true,
    this.showTooltip = true,
    this.showActiveEvent = true,
    this.tickCount = 4,
    this.minEventRadius = 3.5,
    this.maxEventRadius = 8,
    this.eventOpacity = 0.86,
    this.dateFormatter,
    this.weightFormatter,
    this.onEventTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(tickCount >= 2),
       assert(minEventRadius >= 0),
       assert(maxEventRadius >= minEventRadius),
       assert(eventOpacity >= 0 && eventOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleEventStripVisuals.resolve(style, colorScheme);
    final visibleLanes = lanes
        .where(
          (lane) =>
              lane.label.trim().isNotEmpty &&
              lane.events.any((event) => event.label.trim().isNotEmpty),
        )
        .map((lane) {
          final events = lane.events
              .where((event) => event.label.trim().isNotEmpty)
              .toList();
          if (sortByDate) {
            events.sort((a, b) {
              final dateCompare = a.date.compareTo(b.date);
              if (dateCompare != 0) return dateCompare;
              return a.label.compareTo(b.label);
            });
          }
          return SimpleEventStripLane(
            label: lane.label,
            events: events,
            color: lane.color,
          );
        })
        .toList();
    final formatter = dateFormatter ?? _defaultDateFormatter;
    final resolvedWeightFormatter = weightFormatter ?? _defaultWeightFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleLanes.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Event strip chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedLaneLabelStyle =
            laneLabelStyle ??
            theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
        final resolvedDateStyle =
            dateStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ) ??
            TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11);
        final resolvedEventLabelStyle =
            eventLabelStyle ??
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
            visibleLanes,
            formatter,
            resolvedWeightFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleEventStripChartView(
            width: width,
            height: chartHeight,
            lanes: visibleLanes,
            minDate: minDate,
            maxDate: maxDate,
            markerDate: markerDate,
            padding: padding,
            palette: palette,
            eventColor: eventColor ?? visuals.eventColor,
            laneColor: laneColor ?? visuals.laneColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            markerDateColor: markerDateColor ?? visuals.markerDateColor,
            activeColor: activeColor ?? visuals.activeColor,
            laneBackgroundColor:
                laneBackgroundColor ?? visuals.laneBackgroundColor,
            laneLabelStyle: resolvedLaneLabelStyle,
            dateStyle: resolvedDateStyle,
            eventLabelStyle: resolvedEventLabelStyle,
            showGrid: showGrid,
            showLaneLabels: showLaneLabels,
            showDates: showDates,
            showEventLabels: showEventLabels,
            showWeights: showWeights,
            showMarkerDate: showMarkerDate,
            showTooltip: showTooltip,
            showActiveEvent: showActiveEvent,
            tickCount: tickCount,
            minEventRadius: minEventRadius,
            maxEventRadius: maxEventRadius,
            eventOpacity: eventOpacity,
            dateFormatter: formatter,
            weightFormatter: resolvedWeightFormatter,
            onEventTap: onEventTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleEventStripLane> lanes,
    SimpleEventStripDateFormatter dateFormatter,
    SimpleEventStripWeightFormatter weightFormatter,
  ) {
    final eventCount = lanes.fold<int>(
      0,
      (total, lane) => total + lane.events.length,
    );
    final sample = lanes
        .expand(
          (lane) => lane.events
              .take(2)
              .map(
                (event) =>
                    '${lane.label}: ${dateFormatter(event.date)} ${event.label}'
                    ' (${weightFormatter(event.weight)})',
              ),
        )
        .take(5)
        .join(', ');
    final suffix = eventCount > 5 ? ', and ${eventCount - 5} more' : '';
    return 'Event strip chart, ${lanes.length} lanes, $eventCount events. '
        '$sample$suffix.';
  }

  static String _defaultDateFormatter(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _defaultWeightFormatter(double weight) {
    if (weight == weight.roundToDouble()) {
      return weight.toStringAsFixed(0);
    }
    return weight.toStringAsFixed(1);
  }
}

class _SimpleEventStripChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleEventStripLane> lanes;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? markerDate;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color eventColor;
  final Color laneColor;
  final Color gridColor;
  final Color axisColor;
  final Color markerDateColor;
  final Color activeColor;
  final Color laneBackgroundColor;
  final TextStyle laneLabelStyle;
  final TextStyle dateStyle;
  final TextStyle eventLabelStyle;
  final bool showGrid;
  final bool showLaneLabels;
  final bool showDates;
  final bool showEventLabels;
  final bool showWeights;
  final bool showMarkerDate;
  final bool showTooltip;
  final bool showActiveEvent;
  final int tickCount;
  final double minEventRadius;
  final double maxEventRadius;
  final double eventOpacity;
  final SimpleEventStripDateFormatter dateFormatter;
  final SimpleEventStripWeightFormatter weightFormatter;
  final SimpleEventStripTapCallback? onEventTap;
  final SimpleEventStripTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleEventStripChartView({
    required this.width,
    required this.height,
    required this.lanes,
    required this.minDate,
    required this.maxDate,
    required this.markerDate,
    required this.padding,
    required this.palette,
    required this.eventColor,
    required this.laneColor,
    required this.gridColor,
    required this.axisColor,
    required this.markerDateColor,
    required this.activeColor,
    required this.laneBackgroundColor,
    required this.laneLabelStyle,
    required this.dateStyle,
    required this.eventLabelStyle,
    required this.showGrid,
    required this.showLaneLabels,
    required this.showDates,
    required this.showEventLabels,
    required this.showWeights,
    required this.showMarkerDate,
    required this.showTooltip,
    required this.showActiveEvent,
    required this.tickCount,
    required this.minEventRadius,
    required this.maxEventRadius,
    required this.eventOpacity,
    required this.dateFormatter,
    required this.weightFormatter,
    required this.onEventTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleEventStripChartView> createState() =>
      _SimpleEventStripChartViewState();
}

class _SimpleEventStripChartViewState extends State<_SimpleEventStripChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _EventStripHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleEventStripChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lanes != widget.lanes ||
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
                    if (widget.showActiveEvent ||
                        widget.showTooltip ||
                        widget.onEventTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit != null) {
                        widget.onEventTap?.call(
                          hit.event,
                          hit.laneIndex,
                          hit.eventIndex,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleEventStripPainter(
                        lanes: widget.lanes,
                        minDate: widget.minDate,
                        maxDate: widget.maxDate,
                        markerDate: widget.markerDate,
                        padding: widget.padding,
                        palette: widget.palette,
                        eventColor: widget.eventColor,
                        laneColor: widget.laneColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        markerDateColor: widget.markerDateColor,
                        activeColor: widget.activeColor,
                        laneBackgroundColor: widget.laneBackgroundColor,
                        laneLabelStyle: widget.laneLabelStyle,
                        dateStyle: widget.dateStyle,
                        eventLabelStyle: widget.eventLabelStyle,
                        showGrid: widget.showGrid,
                        showLaneLabels: widget.showLaneLabels,
                        showDates: widget.showDates,
                        showEventLabels: widget.showEventLabels,
                        showWeights: widget.showWeights,
                        showMarkerDate: widget.showMarkerDate,
                        showActiveEvent: widget.showActiveEvent,
                        tickCount: widget.tickCount,
                        minEventRadius: widget.minEventRadius,
                        maxEventRadius: widget.maxEventRadius,
                        eventOpacity: widget.eventOpacity,
                        dateFormatter: widget.dateFormatter,
                        activeHit: _activeHit,
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

  void _setActive(_EventStripHit? hit) {
    if (_activeHit?.laneIndex == hit?.laneIndex &&
        _activeHit?.eventIndex == hit?.eventIndex) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _EventStripHit? _hitTest(Offset position) {
    final geometry = _EventStripGeometry.resolve(
      lanes: widget.lanes,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      minEventRadius: widget.minEventRadius,
      maxEventRadius: widget.maxEventRadius,
      showEventLabels: widget.showEventLabels,
    );
    for (final hit in geometry.hits.reversed) {
      if (hit.hitRect.inflate(5).contains(position) ||
          (position - hit.center).distance <= hit.radius + 9) {
        return hit;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _EventStripHit hit) {
    final formattedDate = widget.dateFormatter(hit.event.date);
    final formattedWeight = widget.weightFormatter(hit.event.weight);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          hit.event,
          hit.laneIndex,
          hit.eventIndex,
          formattedDate,
          formattedWeight,
        ) ??
        _DefaultEventStripTooltip(
          title: hit.event.label,
          rows: [
            _TooltipRow('Lane', widget.lanes[hit.laneIndex].label),
            _TooltipRow('Date', formattedDate),
            if (widget.showWeights) _TooltipRow('Weight', formattedWeight),
            if (hit.event.tag != null) _TooltipRow('Tag', hit.event.tag!),
            if (hit.event.description != null)
              _TooltipRow('Note', hit.event.description!),
          ],
        );
    final left = _clampFinite(hit.center.dx + 12, 8.0, widget.width - 214);
    final top = _clampFinite(hit.center.dy - 52, 8.0, widget.height - 132);

    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleEventStripPainter extends CustomPainter {
  final List<SimpleEventStripLane> lanes;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? markerDate;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color eventColor;
  final Color laneColor;
  final Color gridColor;
  final Color axisColor;
  final Color markerDateColor;
  final Color activeColor;
  final Color laneBackgroundColor;
  final TextStyle laneLabelStyle;
  final TextStyle dateStyle;
  final TextStyle eventLabelStyle;
  final bool showGrid;
  final bool showLaneLabels;
  final bool showDates;
  final bool showEventLabels;
  final bool showWeights;
  final bool showMarkerDate;
  final bool showActiveEvent;
  final int tickCount;
  final double minEventRadius;
  final double maxEventRadius;
  final double eventOpacity;
  final SimpleEventStripDateFormatter dateFormatter;
  final _EventStripHit? activeHit;
  final double progress;

  const _SimpleEventStripPainter({
    required this.lanes,
    required this.minDate,
    required this.maxDate,
    required this.markerDate,
    required this.padding,
    required this.palette,
    required this.eventColor,
    required this.laneColor,
    required this.gridColor,
    required this.axisColor,
    required this.markerDateColor,
    required this.activeColor,
    required this.laneBackgroundColor,
    required this.laneLabelStyle,
    required this.dateStyle,
    required this.eventLabelStyle,
    required this.showGrid,
    required this.showLaneLabels,
    required this.showDates,
    required this.showEventLabels,
    required this.showWeights,
    required this.showMarkerDate,
    required this.showActiveEvent,
    required this.tickCount,
    required this.minEventRadius,
    required this.maxEventRadius,
    required this.eventOpacity,
    required this.dateFormatter,
    required this.activeHit,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _EventStripGeometry.resolve(
      lanes: lanes,
      size: size,
      padding: padding,
      minDate: minDate,
      maxDate: maxDate,
      minEventRadius: minEventRadius,
      maxEventRadius: maxEventRadius,
      showEventLabels: showEventLabels,
    );
    if (geometry.hits.isEmpty) {
      return;
    }

    _drawLanes(canvas, geometry);
    if (showGrid) {
      _drawGrid(canvas, geometry);
    }
    if (showMarkerDate && markerDate != null) {
      _drawMarkerDate(canvas, geometry);
    }
    for (final hit in geometry.hits) {
      _drawEvent(canvas, hit);
    }
    if (showDates) {
      _drawDates(canvas, geometry);
    }
  }

  void _drawLanes(Canvas canvas, _EventStripGeometry geometry) {
    final lanePaint = Paint()
      ..color = axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..color = laneBackgroundColor
      ..style = PaintingStyle.fill;

    for (var index = 0; index < geometry.laneRects.length; index++) {
      final rect = geometry.laneRects[index];
      if (laneBackgroundColor.a > 0 && index.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          fillPaint,
        );
      }
      canvas.drawLine(
        Offset(geometry.plot.left, rect.center.dy),
        Offset(geometry.plot.right, rect.center.dy),
        lanePaint..color = axisColor.withValues(alpha: 0.22),
      );
      if (showLaneLabels) {
        _drawText(
          canvas,
          lanes[index].label,
          Rect.fromLTRB(
            padding.left > 12 ? 0 : geometry.plot.left,
            rect.top,
            geometry.plot.left - 10,
            rect.bottom,
          ),
          laneLabelStyle.copyWith(color: _laneColor(lanes[index], index)),
          align: TextAlign.right,
          maxLines: 1,
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, _EventStripGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var index = 0; index < tickCount; index++) {
      final ratio = tickCount == 1 ? 0.0 : index / (tickCount - 1);
      final x = geometry.plot.left + geometry.plot.width * ratio;
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
      );
    }
  }

  void _drawMarkerDate(Canvas canvas, _EventStripGeometry geometry) {
    final date = markerDate;
    if (date == null) {
      return;
    }
    final x =
        geometry.plot.left +
        geometry.dateRange.ratio(date, 0, 1) * geometry.plot.width;
    if (x < geometry.plot.left || x > geometry.plot.right) {
      return;
    }
    final paint = Paint()
      ..color = markerDateColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x, geometry.plot.top),
      Offset(x, geometry.plot.bottom),
      paint,
    );
  }

  void _drawEvent(Canvas canvas, _EventStripHit hit) {
    final visibleProgress = (progress * geometryEventCount - hit.globalIndex)
        .clamp(0.0, 1.0);
    if (visibleProgress <= 0) {
      return;
    }

    final event = hit.event;
    final active =
        showActiveEvent &&
        activeHit?.laneIndex == hit.laneIndex &&
        activeHit?.eventIndex == hit.eventIndex;
    final color = active ? activeColor : _eventColor(event, hit);
    final radius = hit.radius * visibleProgress;
    final stemPaint = Paint()
      ..color = color.withValues(alpha: 0.18 * visibleProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, radius * 0.34)
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(hit.center.dx, hit.center.dy - radius * 2.2),
      Offset(hit.center.dx, hit.center.dy + radius * 2.2),
      stemPaint,
    );

    canvas.drawCircle(
      hit.center,
      radius * 2.1,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      hit.center,
      radius,
      Paint()
        ..color = color.withValues(alpha: eventOpacity)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      hit.center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    if (showEventLabels) {
      _drawText(
        canvas,
        event.label,
        hit.labelRect,
        eventLabelStyle.copyWith(color: color),
        align: TextAlign.center,
        maxLines: 1,
      );
    }
  }

  int get geometryEventCount =>
      lanes.fold(0, (total, lane) => total + lane.events.length);

  void _drawDates(Canvas canvas, _EventStripGeometry geometry) {
    for (var index = 0; index < tickCount; index++) {
      final ratio = tickCount == 1 ? 0.0 : index / (tickCount - 1);
      final x = geometry.plot.left + geometry.plot.width * ratio;
      final date = geometry.dateRange.dateAt(ratio);
      final align = index == 0
          ? TextAlign.left
          : index == tickCount - 1
          ? TextAlign.right
          : TextAlign.center;
      final rect = Rect.fromLTWH(x - 54, geometry.plot.bottom + 8, 108, 16);
      _drawText(
        canvas,
        dateFormatter(date),
        rect,
        dateStyle,
        align: align,
        maxLines: 1,
      );
    }
  }

  Color _eventColor(SimpleEventStripEvent event, _EventStripHit hit) {
    if (event.color != null) {
      return event.color!;
    }
    final lane = lanes[hit.laneIndex];
    if (lane.color != null) {
      return lane.color!;
    }
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[hit.laneIndex % colors.length];
    }
    return eventColor;
  }

  Color _laneColor(SimpleEventStripLane lane, int index) {
    if (lane.color != null) {
      return lane.color!;
    }
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return laneColor;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style, {
    TextAlign align = TextAlign.left,
    int maxLines = 1,
  }) {
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: maxLines,
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
  bool shouldRepaint(covariant _SimpleEventStripPainter oldDelegate) {
    return oldDelegate.lanes != lanes ||
        oldDelegate.minDate != minDate ||
        oldDelegate.maxDate != maxDate ||
        oldDelegate.markerDate != markerDate ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.eventColor != eventColor ||
        oldDelegate.laneColor != laneColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.markerDateColor != markerDateColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.laneBackgroundColor != laneBackgroundColor ||
        oldDelegate.laneLabelStyle != laneLabelStyle ||
        oldDelegate.dateStyle != dateStyle ||
        oldDelegate.eventLabelStyle != eventLabelStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLaneLabels != showLaneLabels ||
        oldDelegate.showDates != showDates ||
        oldDelegate.showEventLabels != showEventLabels ||
        oldDelegate.showWeights != showWeights ||
        oldDelegate.showMarkerDate != showMarkerDate ||
        oldDelegate.showActiveEvent != showActiveEvent ||
        oldDelegate.tickCount != tickCount ||
        oldDelegate.minEventRadius != minEventRadius ||
        oldDelegate.maxEventRadius != maxEventRadius ||
        oldDelegate.eventOpacity != eventOpacity ||
        oldDelegate.activeHit != activeHit ||
        oldDelegate.progress != progress;
  }
}

class _EventStripGeometry {
  final Rect plot;
  final List<Rect> laneRects;
  final List<_EventStripHit> hits;
  final _EventDateRange dateRange;

  const _EventStripGeometry({
    required this.plot,
    required this.laneRects,
    required this.hits,
    required this.dateRange,
  });

  factory _EventStripGeometry.resolve({
    required List<SimpleEventStripLane> lanes,
    required Size size,
    required EdgeInsets padding,
    required DateTime? minDate,
    required DateTime? maxDate,
    required double minEventRadius,
    required double maxEventRadius,
    required bool showEventLabels,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final dateRange = _EventDateRange.resolve(lanes, minDate, maxDate);
    if (lanes.isEmpty || plot.width <= 0 || plot.height <= 0) {
      return _EventStripGeometry(
        plot: plot,
        laneRects: const [],
        hits: const [],
        dateRange: dateRange,
      );
    }

    final maxWeight = lanes
        .expand((lane) => lane.events)
        .map(
          (event) => event.weight.isFinite ? math.max(0.0, event.weight) : 0.0,
        )
        .fold<double>(0, (maxValue, weight) => math.max(maxValue, weight));
    final laneHeight = plot.height / lanes.length;
    final laneRects = <Rect>[];
    final hits = <_EventStripHit>[];
    var globalIndex = 0;

    for (var laneIndex = 0; laneIndex < lanes.length; laneIndex++) {
      final laneRect = Rect.fromLTWH(
        plot.left,
        plot.top + laneHeight * laneIndex,
        plot.width,
        laneHeight,
      );
      laneRects.add(laneRect);
      final lane = lanes[laneIndex];
      for (var eventIndex = 0; eventIndex < lane.events.length; eventIndex++) {
        final event = lane.events[eventIndex];
        final radius = _radiusFor(
          event.weight,
          maxWeight,
          minEventRadius,
          maxEventRadius,
        );
        final x =
            plot.left +
            dateRange.ratio(event.date, globalIndex, 1) * plot.width;
        final center = Offset(x, laneRect.center.dy);
        final labelWidth = math.min(88.0, math.max(0.0, plot.width));
        final labelLeft = _clampFinite(
          x - labelWidth / 2,
          plot.left,
          plot.right - labelWidth,
        );
        final labelRect = Rect.fromLTWH(
          labelLeft,
          center.dy + radius + 5,
          labelWidth,
          showEventLabels ? 15 : 0,
        );
        final markerRect = Rect.fromCircle(center: center, radius: radius + 8);
        hits.add(
          _EventStripHit(
            event: event,
            laneIndex: laneIndex,
            eventIndex: eventIndex,
            globalIndex: globalIndex,
            center: center,
            radius: radius,
            labelRect: labelRect,
            hitRect: showEventLabels
                ? markerRect.expandToInclude(labelRect)
                : markerRect,
          ),
        );
        globalIndex++;
      }
    }

    return _EventStripGeometry(
      plot: plot,
      laneRects: laneRects,
      hits: hits,
      dateRange: dateRange,
    );
  }

  static double _radiusFor(
    double weight,
    double maxWeight,
    double minEventRadius,
    double maxEventRadius,
  ) {
    if (!weight.isFinite ||
        maxWeight <= 0 ||
        maxEventRadius <= minEventRadius) {
      return minEventRadius;
    }
    final ratio = math.sqrt(math.max(0, weight) / maxWeight).clamp(0.0, 1.0);
    return minEventRadius + (maxEventRadius - minEventRadius) * ratio;
  }
}

class _EventDateRange {
  final double startMs;
  final double spanMs;
  final bool useIndexFallback;

  const _EventDateRange({
    required this.startMs,
    required this.spanMs,
    required this.useIndexFallback,
  });

  factory _EventDateRange.resolve(
    List<SimpleEventStripLane> lanes,
    DateTime? minDate,
    DateTime? maxDate,
  ) {
    final events = lanes.expand((lane) => lane.events).toList();
    var low = minDate ?? events.first.date;
    var high = maxDate ?? events.first.date;
    for (final event in events) {
      if (minDate == null && event.date.isBefore(low)) {
        low = event.date;
      }
      if (maxDate == null && event.date.isAfter(high)) {
        high = event.date;
      }
    }
    if (high.isBefore(low)) {
      final swap = low;
      low = high;
      high = swap;
    }
    final start = low.millisecondsSinceEpoch.toDouble();
    final span = high.millisecondsSinceEpoch.toDouble() - start;
    return _EventDateRange(
      startMs: start,
      spanMs: span,
      useIndexFallback: span <= 0,
    );
  }

  double ratio(DateTime date, int index, int count) {
    if (useIndexFallback) {
      return count <= 1 ? 0.5 : index / (count - 1);
    }
    final raw = (date.millisecondsSinceEpoch.toDouble() - startMs) / spanMs;
    return raw.clamp(0.0, 1.0);
  }

  DateTime dateAt(double ratio) {
    final ms = startMs + spanMs * ratio.clamp(0.0, 1.0);
    return DateTime.fromMillisecondsSinceEpoch(ms.round());
  }
}

class _EventStripHit {
  final SimpleEventStripEvent event;
  final int laneIndex;
  final int eventIndex;
  final int globalIndex;
  final Offset center;
  final double radius;
  final Rect labelRect;
  final Rect hitRect;

  const _EventStripHit({
    required this.event,
    required this.laneIndex,
    required this.eventIndex,
    required this.globalIndex,
    required this.center,
    required this.radius,
    required this.labelRect,
    required this.hitRect,
  });
}

class _SimpleEventStripVisuals {
  final Color eventColor;
  final Color laneColor;
  final Color gridColor;
  final Color axisColor;
  final Color markerDateColor;
  final Color activeColor;
  final Color laneBackgroundColor;

  const _SimpleEventStripVisuals({
    required this.eventColor,
    required this.laneColor,
    required this.gridColor,
    required this.axisColor,
    required this.markerDateColor,
    required this.activeColor,
    required this.laneBackgroundColor,
  });

  factory _SimpleEventStripVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleEventStripVisuals(
          eventColor: colorScheme.primary,
          laneColor: colorScheme.primary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.58),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          markerDateColor: colorScheme.tertiary.withValues(alpha: 0.82),
          activeColor: colorScheme.tertiary,
          laneBackgroundColor: colorScheme.primary.withValues(alpha: 0.04),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleEventStripVisuals(
          eventColor: colorScheme.primary,
          laneColor: colorScheme.onSurfaceVariant,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.7),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          markerDateColor: colorScheme.onSurface.withValues(alpha: 0.72),
          activeColor: colorScheme.onSurface,
          laneBackgroundColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.18,
          ),
        );
      case SimpleBarChartStyle.education:
        return _SimpleEventStripVisuals(
          eventColor: colorScheme.secondary,
          laneColor: colorScheme.secondary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.58),
          axisColor: colorScheme.outline.withValues(alpha: 0.44),
          markerDateColor: colorScheme.primary.withValues(alpha: 0.76),
          activeColor: colorScheme.primary,
          laneBackgroundColor: colorScheme.secondary.withValues(alpha: 0.05),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleEventStripVisuals(
          eventColor: colorScheme.tertiary,
          laneColor: colorScheme.tertiary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.54),
          axisColor: colorScheme.outline.withValues(alpha: 0.42),
          markerDateColor: colorScheme.primary.withValues(alpha: 0.78),
          activeColor: colorScheme.primary,
          laneBackgroundColor: colorScheme.tertiary.withValues(alpha: 0.05),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleEventStripVisuals(
          eventColor: colorScheme.primary,
          laneColor: colorScheme.primary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.58),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          markerDateColor: colorScheme.tertiary.withValues(alpha: 0.78),
          activeColor: colorScheme.tertiary,
          laneBackgroundColor: colorScheme.primary.withValues(alpha: 0.04),
        );
    }
  }
}

class _DefaultEventStripTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultEventStripTooltip({required this.title, required this.rows});

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
                        SizedBox(width: 46, child: Text(row.label)),
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
