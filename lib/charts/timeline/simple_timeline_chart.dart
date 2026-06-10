import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleTimelineDateFormatter = String Function(DateTime date);
typedef SimpleTimelineTapCallback =
    void Function(SimpleTimelineEvent event, int index);
typedef SimpleTimelineTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleTimelineEvent event,
      int index,
      String formattedDate,
    );

enum SimpleTimelineOrientation { vertical, horizontal }

class SimpleTimelineEvent {
  final DateTime date;
  final String title;
  final String? description;
  final String? tag;
  final Color? color;

  const SimpleTimelineEvent({
    required this.date,
    required this.title,
    this.description,
    this.tag,
    this.color,
  });
}

/// A lightweight timeline for milestones, releases, incidents, audits, and
/// learning or project plans.
class SimpleTimelineChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 18, 18, 18);

  final List<SimpleTimelineEvent> events;
  final SimpleTimelineOrientation orientation;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? markerColor;
  final Color? connectorColor;
  final Color? activeColor;
  final Color? eventBackgroundColor;
  final TextStyle? dateStyle;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
  final bool sortByDate;
  final bool alternating;
  final bool showDates;
  final bool showDescriptions;
  final bool showTags;
  final bool showConnector;
  final bool showTooltip;
  final bool showActiveEvent;
  final double markerRadius;
  final double connectorWidth;
  final double eventSpacing;
  final SimpleTimelineDateFormatter? dateFormatter;
  final SimpleTimelineTapCallback? onEventTap;
  final SimpleTimelineTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleTimelineChart({
    super.key,
    required this.events,
    this.orientation = SimpleTimelineOrientation.vertical,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 280,
    this.padding = _defaultPadding,
    this.palette,
    this.markerColor,
    this.connectorColor,
    this.activeColor,
    this.eventBackgroundColor,
    this.dateStyle,
    this.titleStyle,
    this.descriptionStyle,
    this.sortByDate = true,
    this.alternating = false,
    this.showDates = true,
    this.showDescriptions = true,
    this.showTags = true,
    this.showConnector = true,
    this.showTooltip = true,
    this.showActiveEvent = true,
    this.markerRadius = 7,
    this.connectorWidth = 2,
    this.eventSpacing = 14,
    this.dateFormatter,
    this.onEventTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 680),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(markerRadius >= 0),
       assert(connectorWidth > 0),
       assert(eventSpacing >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleTimelineVisuals.resolve(style, colorScheme);
    final visibleEvents = events.toList();
    if (sortByDate) {
      visibleEvents.sort((a, b) => a.date.compareTo(b.date));
    }
    final formatter = dateFormatter ?? _defaultDateFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleEvents.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Timeline chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedDateStyle =
            dateStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
        final resolvedTitleStyle =
            titleStyle ??
            theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            );
        final resolvedDescriptionStyle =
            descriptionStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ) ??
            TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11);

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(visibleEvents, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleTimelineChartView(
            width: width,
            height: chartHeight,
            events: visibleEvents,
            orientation: orientation,
            padding: padding,
            palette: palette,
            markerColor: markerColor ?? visuals.markerColor,
            connectorColor: connectorColor ?? visuals.connectorColor,
            activeColor: activeColor ?? visuals.activeColor,
            eventBackgroundColor:
                eventBackgroundColor ?? visuals.eventBackgroundColor,
            dateStyle: resolvedDateStyle,
            titleStyle: resolvedTitleStyle,
            descriptionStyle: resolvedDescriptionStyle,
            alternating: alternating,
            showDates: showDates,
            showDescriptions: showDescriptions,
            showTags: showTags,
            showConnector: showConnector,
            showTooltip: showTooltip,
            showActiveEvent: showActiveEvent,
            markerRadius: markerRadius,
            connectorWidth: connectorWidth,
            eventSpacing: eventSpacing,
            dateFormatter: formatter,
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
    List<SimpleTimelineEvent> events,
    SimpleTimelineDateFormatter formatter,
  ) {
    final sample = events
        .take(5)
        .map((event) {
          final detail = event.description == null
              ? ''
              : ', ${event.description}';
          return '${formatter(event.date)} ${event.title}$detail';
        })
        .join(', ');
    final suffix = events.length > 5 ? ', and ${events.length - 5} more' : '';
    return 'Timeline chart, ${events.length} events. $sample$suffix.';
  }

  static String _defaultDateFormatter(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _SimpleTimelineChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleTimelineEvent> events;
  final SimpleTimelineOrientation orientation;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color markerColor;
  final Color connectorColor;
  final Color activeColor;
  final Color eventBackgroundColor;
  final TextStyle dateStyle;
  final TextStyle titleStyle;
  final TextStyle descriptionStyle;
  final bool alternating;
  final bool showDates;
  final bool showDescriptions;
  final bool showTags;
  final bool showConnector;
  final bool showTooltip;
  final bool showActiveEvent;
  final double markerRadius;
  final double connectorWidth;
  final double eventSpacing;
  final SimpleTimelineDateFormatter dateFormatter;
  final SimpleTimelineTapCallback? onEventTap;
  final SimpleTimelineTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleTimelineChartView({
    required this.width,
    required this.height,
    required this.events,
    required this.orientation,
    required this.padding,
    required this.palette,
    required this.markerColor,
    required this.connectorColor,
    required this.activeColor,
    required this.eventBackgroundColor,
    required this.dateStyle,
    required this.titleStyle,
    required this.descriptionStyle,
    required this.alternating,
    required this.showDates,
    required this.showDescriptions,
    required this.showTags,
    required this.showConnector,
    required this.showTooltip,
    required this.showActiveEvent,
    required this.markerRadius,
    required this.connectorWidth,
    required this.eventSpacing,
    required this.dateFormatter,
    required this.onEventTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleTimelineChartView> createState() =>
      _SimpleTimelineChartViewState();
}

class _SimpleTimelineChartViewState extends State<_SimpleTimelineChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _TimelineHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleTimelineChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events ||
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
                        widget.onEventTap?.call(hit.event, hit.index);
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleTimelinePainter(
                        events: widget.events,
                        orientation: widget.orientation,
                        padding: widget.padding,
                        palette: widget.palette,
                        markerColor: widget.markerColor,
                        connectorColor: widget.connectorColor,
                        activeColor: widget.activeColor,
                        eventBackgroundColor: widget.eventBackgroundColor,
                        dateStyle: widget.dateStyle,
                        titleStyle: widget.titleStyle,
                        descriptionStyle: widget.descriptionStyle,
                        alternating: widget.alternating,
                        showDates: widget.showDates,
                        showDescriptions: widget.showDescriptions,
                        showTags: widget.showTags,
                        showConnector: widget.showConnector,
                        showActiveEvent: widget.showActiveEvent,
                        markerRadius: widget.markerRadius,
                        connectorWidth: widget.connectorWidth,
                        eventSpacing: widget.eventSpacing,
                        dateFormatter: widget.dateFormatter,
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

  void _setActive(_TimelineHit? hit) {
    if (_activeHit?.index == hit?.index) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _TimelineHit? _hitTest(Offset position) {
    final geometry = _TimelineGeometry.resolve(
      events: widget.events,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      orientation: widget.orientation,
      alternating: widget.alternating,
      markerRadius: widget.markerRadius,
      eventSpacing: widget.eventSpacing,
    );
    for (final hit in geometry.hits) {
      if (hit.hitRect.inflate(6).contains(position) ||
          (position - hit.markerCenter).distance <= widget.markerRadius + 8) {
        return hit;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _TimelineHit hit) {
    final formattedDate = widget.dateFormatter(hit.event.date);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          hit.event,
          hit.index,
          formattedDate,
        ) ??
        _DefaultTimelineTooltip(
          title: hit.event.title,
          rows: [
            _TooltipRow('Date', formattedDate),
            if (hit.event.tag != null) _TooltipRow('Tag', hit.event.tag!),
            if (hit.event.description != null)
              _TooltipRow('Note', hit.event.description!),
          ],
        );
    final left = (hit.markerCenter.dx + 12).clamp(8.0, widget.width - 190);
    final top = (hit.markerCenter.dy - 48).clamp(8.0, widget.height - 116);

    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleTimelinePainter extends CustomPainter {
  final List<SimpleTimelineEvent> events;
  final SimpleTimelineOrientation orientation;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color markerColor;
  final Color connectorColor;
  final Color activeColor;
  final Color eventBackgroundColor;
  final TextStyle dateStyle;
  final TextStyle titleStyle;
  final TextStyle descriptionStyle;
  final bool alternating;
  final bool showDates;
  final bool showDescriptions;
  final bool showTags;
  final bool showConnector;
  final bool showActiveEvent;
  final double markerRadius;
  final double connectorWidth;
  final double eventSpacing;
  final SimpleTimelineDateFormatter dateFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleTimelinePainter({
    required this.events,
    required this.orientation,
    required this.padding,
    required this.palette,
    required this.markerColor,
    required this.connectorColor,
    required this.activeColor,
    required this.eventBackgroundColor,
    required this.dateStyle,
    required this.titleStyle,
    required this.descriptionStyle,
    required this.alternating,
    required this.showDates,
    required this.showDescriptions,
    required this.showTags,
    required this.showConnector,
    required this.showActiveEvent,
    required this.markerRadius,
    required this.connectorWidth,
    required this.eventSpacing,
    required this.dateFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _TimelineGeometry.resolve(
      events: events,
      size: size,
      padding: padding,
      orientation: orientation,
      alternating: alternating,
      markerRadius: markerRadius,
      eventSpacing: eventSpacing,
    );
    if (geometry.hits.isEmpty) {
      return;
    }

    if (showConnector) {
      _drawConnector(canvas, geometry);
    }
    for (final hit in geometry.hits) {
      _drawEvent(canvas, hit);
    }
  }

  void _drawConnector(Canvas canvas, _TimelineGeometry geometry) {
    final paint = Paint()
      ..color = connectorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = connectorWidth
      ..strokeCap = StrokeCap.round;
    if (orientation == SimpleTimelineOrientation.vertical) {
      final start = geometry.hits.first.markerCenter;
      final end = geometry.hits.last.markerCenter;
      final animatedEnd = Offset(
        start.dx,
        start.dy + (end.dy - start.dy) * progress,
      );
      canvas.drawLine(start, animatedEnd, paint);
    } else {
      final start = geometry.hits.first.markerCenter;
      final end = geometry.hits.last.markerCenter;
      final animatedEnd = Offset(
        start.dx + (end.dx - start.dx) * progress,
        start.dy,
      );
      canvas.drawLine(start, animatedEnd, paint);
    }
  }

  void _drawEvent(Canvas canvas, _TimelineHit hit) {
    final visibleProgress = (progress * events.length - hit.index).clamp(
      0.0,
      1.0,
    );
    if (visibleProgress <= 0) {
      return;
    }
    final color = _eventColor(hit.event, hit.index);
    final active = showActiveEvent && activeIndex == hit.index;
    final center = hit.markerCenter;
    final markerPaint = Paint()
      ..color = active ? activeColor : color
      ..style = PaintingStyle.fill;
    final haloPaint = Paint()
      ..color = (active ? activeColor : color).withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final eventRect = hit.contentRect;
    if (eventBackgroundColor.a > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(eventRect, const Radius.circular(8)),
        Paint()
          ..color = eventBackgroundColor.withValues(
            alpha: eventBackgroundColor.a * visibleProgress,
          )
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawCircle(center, markerRadius * 2.2 * visibleProgress, haloPaint);
    canvas.drawCircle(center, markerRadius * visibleProgress, markerPaint);
    canvas.drawCircle(center, markerRadius * visibleProgress, outlinePaint);

    _drawTextBlock(canvas, hit, color);
  }

  void _drawTextBlock(Canvas canvas, _TimelineHit hit, Color color) {
    final align = hit.textAlign;
    var y = hit.contentRect.top + 5;
    final contentWidth = hit.contentRect.width - 12;
    final left = hit.contentRect.left + 6;

    if (showDates) {
      _drawText(
        canvas,
        dateFormatter(hit.event.date),
        Rect.fromLTWH(left, y, contentWidth, 14),
        dateStyle.copyWith(color: color),
        align: align,
      );
      y += 15;
    }

    _drawText(
      canvas,
      hit.event.title,
      Rect.fromLTWH(left, y, contentWidth, 17),
      titleStyle,
      align: align,
    );
    y += 17;

    if (showDescriptions && hit.event.description != null) {
      _drawText(
        canvas,
        hit.event.description!,
        Rect.fromLTWH(left, y, contentWidth, 15),
        descriptionStyle,
        align: align,
      );
      y += 15;
    }

    if (showTags && hit.event.tag != null) {
      _drawText(
        canvas,
        hit.event.tag!,
        Rect.fromLTWH(left, y, contentWidth, 14),
        descriptionStyle.copyWith(color: color, fontWeight: FontWeight.w700),
        align: align,
      );
    }
  }

  Color _eventColor(SimpleTimelineEvent event, int index) {
    if (event.color != null) {
      return event.color!;
    }
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return markerColor;
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
  bool shouldRepaint(covariant _SimpleTimelinePainter oldDelegate) {
    return oldDelegate.events != events ||
        oldDelegate.orientation != orientation ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.connectorColor != connectorColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.eventBackgroundColor != eventBackgroundColor ||
        oldDelegate.dateStyle != dateStyle ||
        oldDelegate.titleStyle != titleStyle ||
        oldDelegate.descriptionStyle != descriptionStyle ||
        oldDelegate.alternating != alternating ||
        oldDelegate.showDates != showDates ||
        oldDelegate.showDescriptions != showDescriptions ||
        oldDelegate.showTags != showTags ||
        oldDelegate.showConnector != showConnector ||
        oldDelegate.showActiveEvent != showActiveEvent ||
        oldDelegate.markerRadius != markerRadius ||
        oldDelegate.connectorWidth != connectorWidth ||
        oldDelegate.eventSpacing != eventSpacing ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _TimelineGeometry {
  final Rect plot;
  final List<_TimelineHit> hits;

  const _TimelineGeometry({required this.plot, required this.hits});

  factory _TimelineGeometry.resolve({
    required List<SimpleTimelineEvent> events,
    required Size size,
    required EdgeInsets padding,
    required SimpleTimelineOrientation orientation,
    required bool alternating,
    required double markerRadius,
    required double eventSpacing,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    if (events.isEmpty || plot.width <= 0 || plot.height <= 0) {
      return _TimelineGeometry(plot: plot, hits: const []);
    }

    final hits = orientation == SimpleTimelineOrientation.vertical
        ? _verticalHits(events, plot, alternating, markerRadius, eventSpacing)
        : _horizontalHits(
            events,
            plot,
            alternating,
            markerRadius,
            eventSpacing,
          );
    return _TimelineGeometry(plot: plot, hits: hits);
  }

  static List<_TimelineHit> _verticalHits(
    List<SimpleTimelineEvent> events,
    Rect plot,
    bool alternating,
    double markerRadius,
    double eventSpacing,
  ) {
    final rowHeight = plot.height / events.length;
    final lineX = alternating
        ? plot.center.dx
        : math.min(plot.left + 92, plot.right - 90);
    final contentHeight = math.min(58.0, math.max(42.0, rowHeight - 8));
    final hits = <_TimelineHit>[];

    for (var index = 0; index < events.length; index++) {
      final center = Offset(lineX, plot.top + rowHeight * (index + 0.5));
      final side = alternating && index.isOdd ? -1 : 1;
      final left = side > 0
          ? center.dx + markerRadius + eventSpacing
          : plot.left;
      final right = side > 0
          ? plot.right
          : center.dx - markerRadius - eventSpacing;
      final rect = Rect.fromLTWH(
        left,
        center.dy - contentHeight / 2,
        math.max(0, right - left),
        contentHeight,
      );
      hits.add(
        _TimelineHit(
          event: events[index],
          index: index,
          markerCenter: center,
          contentRect: rect,
          hitRect: rect.expandToInclude(
            Rect.fromCircle(center: center, radius: markerRadius + 8),
          ),
          textAlign: side > 0 ? TextAlign.left : TextAlign.right,
        ),
      );
    }
    return hits;
  }

  static List<_TimelineHit> _horizontalHits(
    List<SimpleTimelineEvent> events,
    Rect plot,
    bool alternating,
    double markerRadius,
    double eventSpacing,
  ) {
    final step = events.length == 1 ? 0.0 : plot.width / (events.length - 1);
    final lineY = plot.center.dy;
    final contentWidth = math.min(
      126.0,
      math.max(74.0, plot.width / events.length - 8),
    );
    final contentHeight = math.min(
      64.0,
      plot.height / 2 - markerRadius - eventSpacing,
    );
    final hits = <_TimelineHit>[];

    for (var index = 0; index < events.length; index++) {
      final center = Offset(
        events.length == 1 ? plot.center.dx : plot.left + step * index,
        lineY,
      );
      final above = alternating ? index.isEven : true;
      final top = above
          ? lineY - markerRadius - eventSpacing - contentHeight
          : lineY + markerRadius + eventSpacing;
      final rect = Rect.fromLTWH(
        (center.dx - contentWidth / 2).clamp(
          plot.left,
          plot.right - contentWidth,
        ),
        top,
        contentWidth,
        math.max(0, contentHeight),
      );
      hits.add(
        _TimelineHit(
          event: events[index],
          index: index,
          markerCenter: center,
          contentRect: rect,
          hitRect: rect.expandToInclude(
            Rect.fromCircle(center: center, radius: markerRadius + 8),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return hits;
  }
}

class _TimelineHit {
  final SimpleTimelineEvent event;
  final int index;
  final Offset markerCenter;
  final Rect contentRect;
  final Rect hitRect;
  final TextAlign textAlign;

  const _TimelineHit({
    required this.event,
    required this.index,
    required this.markerCenter,
    required this.contentRect,
    required this.hitRect,
    required this.textAlign,
  });
}

class _SimpleTimelineVisuals {
  final Color markerColor;
  final Color connectorColor;
  final Color activeColor;
  final Color eventBackgroundColor;

  const _SimpleTimelineVisuals({
    required this.markerColor,
    required this.connectorColor,
    required this.activeColor,
    required this.eventBackgroundColor,
  });

  factory _SimpleTimelineVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleTimelineVisuals(
          markerColor: colorScheme.primary,
          connectorColor: colorScheme.primary.withValues(alpha: 0.24),
          activeColor: colorScheme.tertiary,
          eventBackgroundColor: colorScheme.primary.withValues(alpha: 0.05),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleTimelineVisuals(
          markerColor: colorScheme.primary,
          connectorColor: colorScheme.outline.withValues(alpha: 0.46),
          activeColor: colorScheme.onSurface,
          eventBackgroundColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.22,
          ),
        );
      case SimpleBarChartStyle.education:
        return _SimpleTimelineVisuals(
          markerColor: colorScheme.secondary,
          connectorColor: colorScheme.secondary.withValues(alpha: 0.25),
          activeColor: colorScheme.primary,
          eventBackgroundColor: colorScheme.secondary.withValues(alpha: 0.06),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleTimelineVisuals(
          markerColor: colorScheme.tertiary,
          connectorColor: colorScheme.tertiary.withValues(alpha: 0.22),
          activeColor: colorScheme.primary,
          eventBackgroundColor: colorScheme.tertiary.withValues(alpha: 0.06),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleTimelineVisuals(
          markerColor: colorScheme.primary,
          connectorColor: colorScheme.primary.withValues(alpha: 0.22),
          activeColor: colorScheme.tertiary,
          eventBackgroundColor: colorScheme.primary.withValues(alpha: 0.05),
        );
    }
  }
}

class _DefaultTimelineTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultTimelineTooltip({required this.title, required this.rows});

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
        constraints: const BoxConstraints(maxWidth: 210),
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
                        SizedBox(width: 38, child: Text(row.label)),
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
