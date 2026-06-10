import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleMilestoneDateFormatter = String Function(DateTime date);
typedef SimpleMilestoneTapCallback =
    void Function(SimpleMilestoneData milestone, int index);
typedef SimpleMilestoneTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleMilestoneData milestone,
      int index,
      String formattedDate,
    );

enum SimpleMilestoneOrientation { horizontal, vertical }

enum SimpleMilestoneStatus { planned, active, done, blocked }

class SimpleMilestoneData {
  final DateTime date;
  final String label;
  final String? description;
  final String? tag;
  final SimpleMilestoneStatus status;
  final Color? color;

  const SimpleMilestoneData({
    required this.date,
    required this.label,
    this.description,
    this.tag,
    this.status = SimpleMilestoneStatus.planned,
    this.color,
  });
}

/// A compact milestone roadmap for launches, curriculum checkpoints, audits,
/// funding stages, release gates, and operations plans.
class SimpleMilestoneChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(28, 22, 28, 38);

  final List<SimpleMilestoneData> milestones;
  final SimpleMilestoneOrientation orientation;
  final SimpleBarChartStyle style;
  final DateTime? minDate;
  final DateTime? maxDate;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? markerColor;
  final Color? doneColor;
  final Color? activeColor;
  final Color? blockedColor;
  final Color? connectorColor;
  final Color? trackColor;
  final Color? milestoneBackgroundColor;
  final TextStyle? dateStyle;
  final TextStyle? labelStyle;
  final TextStyle? descriptionStyle;
  final bool sortByDate;
  final bool alternating;
  final bool showDates;
  final bool showDescriptions;
  final bool showTags;
  final bool showConnector;
  final bool showStatusMarks;
  final bool showTooltip;
  final bool showActiveMilestone;
  final double markerRadius;
  final double connectorWidth;
  final double milestoneSpacing;
  final SimpleMilestoneDateFormatter? dateFormatter;
  final SimpleMilestoneTapCallback? onMilestoneTap;
  final SimpleMilestoneTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleMilestoneChart({
    super.key,
    required this.milestones,
    this.orientation = SimpleMilestoneOrientation.horizontal,
    this.style = SimpleBarChartStyle.elegant,
    this.minDate,
    this.maxDate,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.markerColor,
    this.doneColor,
    this.activeColor,
    this.blockedColor,
    this.connectorColor,
    this.trackColor,
    this.milestoneBackgroundColor,
    this.dateStyle,
    this.labelStyle,
    this.descriptionStyle,
    this.sortByDate = true,
    this.alternating = true,
    this.showDates = true,
    this.showDescriptions = true,
    this.showTags = true,
    this.showConnector = true,
    this.showStatusMarks = true,
    this.showTooltip = true,
    this.showActiveMilestone = true,
    this.markerRadius = 8,
    this.connectorWidth = 3,
    this.milestoneSpacing = 14,
    this.dateFormatter,
    this.onMilestoneTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(markerRadius >= 0),
       assert(connectorWidth > 0),
       assert(milestoneSpacing >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleMilestoneVisuals.resolve(style, colorScheme);
    final visibleMilestones = milestones
        .where((milestone) => milestone.label.trim().isNotEmpty)
        .toList();
    if (sortByDate) {
      visibleMilestones.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.label.compareTo(b.label);
      });
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

        if (visibleMilestones.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Milestone chart, no data.',
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
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );
        final resolvedLabelStyle =
            labelStyle ??
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
          semanticLabel: _defaultSemanticLabel(visibleMilestones, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleMilestoneChartView(
            width: width,
            height: chartHeight,
            milestones: visibleMilestones,
            orientation: orientation,
            minDate: minDate,
            maxDate: maxDate,
            padding: padding,
            palette: palette,
            markerColor: markerColor ?? visuals.markerColor,
            doneColor: doneColor ?? visuals.doneColor,
            activeColor: activeColor ?? visuals.activeColor,
            blockedColor: blockedColor ?? visuals.blockedColor,
            connectorColor: connectorColor ?? visuals.connectorColor,
            trackColor: trackColor ?? visuals.trackColor,
            milestoneBackgroundColor:
                milestoneBackgroundColor ?? visuals.milestoneBackgroundColor,
            dateStyle: resolvedDateStyle,
            labelStyle: resolvedLabelStyle,
            descriptionStyle: resolvedDescriptionStyle,
            alternating: alternating,
            showDates: showDates,
            showDescriptions: showDescriptions,
            showTags: showTags,
            showConnector: showConnector,
            showStatusMarks: showStatusMarks,
            showTooltip: showTooltip,
            showActiveMilestone: showActiveMilestone,
            markerRadius: markerRadius,
            connectorWidth: connectorWidth,
            milestoneSpacing: milestoneSpacing,
            dateFormatter: formatter,
            onMilestoneTap: onMilestoneTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleMilestoneData> milestones,
    SimpleMilestoneDateFormatter formatter,
  ) {
    final sample = milestones
        .take(5)
        .map((milestone) {
          final detail = milestone.description == null
              ? ''
              : ', ${milestone.description}';
          return '${formatter(milestone.date)} ${milestone.label}, '
              '${_statusLabel(milestone.status)}$detail';
        })
        .join(', ');
    final suffix = milestones.length > 5
        ? ', and ${milestones.length - 5} more'
        : '';
    return 'Milestone chart, ${milestones.length} milestones. $sample$suffix.';
  }

  static String _defaultDateFormatter(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _statusLabel(SimpleMilestoneStatus status) {
    return switch (status) {
      SimpleMilestoneStatus.planned => 'planned',
      SimpleMilestoneStatus.active => 'active',
      SimpleMilestoneStatus.done => 'done',
      SimpleMilestoneStatus.blocked => 'blocked',
    };
  }
}

class _SimpleMilestoneChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleMilestoneData> milestones;
  final SimpleMilestoneOrientation orientation;
  final DateTime? minDate;
  final DateTime? maxDate;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color markerColor;
  final Color doneColor;
  final Color activeColor;
  final Color blockedColor;
  final Color connectorColor;
  final Color trackColor;
  final Color milestoneBackgroundColor;
  final TextStyle dateStyle;
  final TextStyle labelStyle;
  final TextStyle descriptionStyle;
  final bool alternating;
  final bool showDates;
  final bool showDescriptions;
  final bool showTags;
  final bool showConnector;
  final bool showStatusMarks;
  final bool showTooltip;
  final bool showActiveMilestone;
  final double markerRadius;
  final double connectorWidth;
  final double milestoneSpacing;
  final SimpleMilestoneDateFormatter dateFormatter;
  final SimpleMilestoneTapCallback? onMilestoneTap;
  final SimpleMilestoneTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleMilestoneChartView({
    required this.width,
    required this.height,
    required this.milestones,
    required this.orientation,
    required this.minDate,
    required this.maxDate,
    required this.padding,
    required this.palette,
    required this.markerColor,
    required this.doneColor,
    required this.activeColor,
    required this.blockedColor,
    required this.connectorColor,
    required this.trackColor,
    required this.milestoneBackgroundColor,
    required this.dateStyle,
    required this.labelStyle,
    required this.descriptionStyle,
    required this.alternating,
    required this.showDates,
    required this.showDescriptions,
    required this.showTags,
    required this.showConnector,
    required this.showStatusMarks,
    required this.showTooltip,
    required this.showActiveMilestone,
    required this.markerRadius,
    required this.connectorWidth,
    required this.milestoneSpacing,
    required this.dateFormatter,
    required this.onMilestoneTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleMilestoneChartView> createState() =>
      _SimpleMilestoneChartViewState();
}

class _SimpleMilestoneChartViewState extends State<_SimpleMilestoneChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _MilestoneHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleMilestoneChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.milestones != widget.milestones ||
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
                    if (widget.showActiveMilestone ||
                        widget.showTooltip ||
                        widget.onMilestoneTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit != null) {
                        widget.onMilestoneTap?.call(hit.milestone, hit.index);
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleMilestonePainter(
                        milestones: widget.milestones,
                        orientation: widget.orientation,
                        minDate: widget.minDate,
                        maxDate: widget.maxDate,
                        padding: widget.padding,
                        palette: widget.palette,
                        markerColor: widget.markerColor,
                        doneColor: widget.doneColor,
                        activeColor: widget.activeColor,
                        blockedColor: widget.blockedColor,
                        connectorColor: widget.connectorColor,
                        trackColor: widget.trackColor,
                        milestoneBackgroundColor:
                            widget.milestoneBackgroundColor,
                        dateStyle: widget.dateStyle,
                        labelStyle: widget.labelStyle,
                        descriptionStyle: widget.descriptionStyle,
                        alternating: widget.alternating,
                        showDates: widget.showDates,
                        showDescriptions: widget.showDescriptions,
                        showTags: widget.showTags,
                        showConnector: widget.showConnector,
                        showStatusMarks: widget.showStatusMarks,
                        showActiveMilestone: widget.showActiveMilestone,
                        markerRadius: widget.markerRadius,
                        connectorWidth: widget.connectorWidth,
                        milestoneSpacing: widget.milestoneSpacing,
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

  void _setActive(_MilestoneHit? hit) {
    if (_activeHit?.index == hit?.index) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _MilestoneHit? _hitTest(Offset position) {
    final geometry = _MilestoneGeometry.resolve(
      milestones: widget.milestones,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      orientation: widget.orientation,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
      alternating: widget.alternating,
      markerRadius: widget.markerRadius,
      milestoneSpacing: widget.milestoneSpacing,
      showDates: widget.showDates,
      showDescriptions: widget.showDescriptions,
      showTags: widget.showTags,
    );
    for (final hit in geometry.hits) {
      if (hit.hitRect.inflate(6).contains(position) ||
          (position - hit.markerCenter).distance <= widget.markerRadius + 10) {
        return hit;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _MilestoneHit hit) {
    final formattedDate = widget.dateFormatter(hit.milestone.date);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          hit.milestone,
          hit.index,
          formattedDate,
        ) ??
        _DefaultMilestoneTooltip(
          title: hit.milestone.label,
          rows: [
            _TooltipRow('Date', formattedDate),
            _TooltipRow(
              'Status',
              SimpleMilestoneChart._statusLabel(hit.milestone.status),
            ),
            if (hit.milestone.tag != null)
              _TooltipRow('Tag', hit.milestone.tag!),
            if (hit.milestone.description != null)
              _TooltipRow('Note', hit.milestone.description!),
          ],
        );
    final left = (hit.markerCenter.dx + 12).clamp(8.0, widget.width - 204);
    final top = (hit.markerCenter.dy - 50).clamp(8.0, widget.height - 128);

    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleMilestonePainter extends CustomPainter {
  final List<SimpleMilestoneData> milestones;
  final SimpleMilestoneOrientation orientation;
  final DateTime? minDate;
  final DateTime? maxDate;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color markerColor;
  final Color doneColor;
  final Color activeColor;
  final Color blockedColor;
  final Color connectorColor;
  final Color trackColor;
  final Color milestoneBackgroundColor;
  final TextStyle dateStyle;
  final TextStyle labelStyle;
  final TextStyle descriptionStyle;
  final bool alternating;
  final bool showDates;
  final bool showDescriptions;
  final bool showTags;
  final bool showConnector;
  final bool showStatusMarks;
  final bool showActiveMilestone;
  final double markerRadius;
  final double connectorWidth;
  final double milestoneSpacing;
  final SimpleMilestoneDateFormatter dateFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleMilestonePainter({
    required this.milestones,
    required this.orientation,
    required this.minDate,
    required this.maxDate,
    required this.padding,
    required this.palette,
    required this.markerColor,
    required this.doneColor,
    required this.activeColor,
    required this.blockedColor,
    required this.connectorColor,
    required this.trackColor,
    required this.milestoneBackgroundColor,
    required this.dateStyle,
    required this.labelStyle,
    required this.descriptionStyle,
    required this.alternating,
    required this.showDates,
    required this.showDescriptions,
    required this.showTags,
    required this.showConnector,
    required this.showStatusMarks,
    required this.showActiveMilestone,
    required this.markerRadius,
    required this.connectorWidth,
    required this.milestoneSpacing,
    required this.dateFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _MilestoneGeometry.resolve(
      milestones: milestones,
      size: size,
      padding: padding,
      orientation: orientation,
      minDate: minDate,
      maxDate: maxDate,
      alternating: alternating,
      markerRadius: markerRadius,
      milestoneSpacing: milestoneSpacing,
      showDates: showDates,
      showDescriptions: showDescriptions,
      showTags: showTags,
    );
    if (geometry.hits.isEmpty) {
      return;
    }

    if (showConnector) {
      _drawConnector(canvas, geometry);
    }
    for (final hit in geometry.hits) {
      _drawMilestone(canvas, hit);
    }
  }

  void _drawConnector(Canvas canvas, _MilestoneGeometry geometry) {
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = connectorWidth
      ..strokeCap = StrokeCap.round;
    final connectorPaint = Paint()
      ..color = connectorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = connectorWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(geometry.axisStart, geometry.axisEnd, trackPaint);
    final animatedEnd = Offset.lerp(
      geometry.axisStart,
      geometry.axisEnd,
      progress,
    )!;
    canvas.drawLine(geometry.axisStart, animatedEnd, connectorPaint);
  }

  void _drawMilestone(Canvas canvas, _MilestoneHit hit) {
    final visibleProgress = (progress * milestones.length - hit.index).clamp(
      0.0,
      1.0,
    );
    if (visibleProgress <= 0) {
      return;
    }

    final color = _milestoneColor(hit.milestone, hit.index);
    final active = showActiveMilestone && activeIndex == hit.index;
    final effectiveColor = active ? activeColor : color;
    final center = hit.markerCenter;

    if (milestoneBackgroundColor.a > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hit.contentRect, const Radius.circular(8)),
        Paint()
          ..color = milestoneBackgroundColor.withValues(
            alpha: milestoneBackgroundColor.a * visibleProgress,
          )
          ..style = PaintingStyle.fill,
      );
    }

    final tickPaint = Paint()
      ..color = effectiveColor.withValues(alpha: 0.22 * visibleProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = connectorWidth
      ..strokeCap = StrokeCap.round;
    if (orientation == SimpleMilestoneOrientation.horizontal) {
      canvas.drawLine(
        Offset(center.dx, center.dy - markerRadius * 1.8),
        Offset(center.dx, center.dy + markerRadius * 1.8),
        tickPaint,
      );
    } else {
      canvas.drawLine(
        Offset(center.dx - markerRadius * 1.8, center.dy),
        Offset(center.dx + markerRadius * 1.8, center.dy),
        tickPaint,
      );
    }

    _drawMarker(canvas, hit, effectiveColor, visibleProgress);
    _drawTextBlock(canvas, hit, color);
  }

  void _drawMarker(
    Canvas canvas,
    _MilestoneHit hit,
    Color color,
    double visibleProgress,
  ) {
    final center = hit.markerCenter;
    final radius = markerRadius * visibleProgress;
    final haloPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, markerRadius * 2.2 * visibleProgress, haloPaint);

    if (hit.milestone.status == SimpleMilestoneStatus.active) {
      final diamond = Path()
        ..moveTo(center.dx, center.dy - radius * 1.08)
        ..lineTo(center.dx + radius * 1.08, center.dy)
        ..lineTo(center.dx, center.dy + radius * 1.08)
        ..lineTo(center.dx - radius * 1.08, center.dy)
        ..close();
      canvas.drawPath(diamond, fillPaint);
      canvas.drawPath(diamond, outlinePaint);
    } else {
      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, outlinePaint);
    }

    if (!showStatusMarks || radius < 4) {
      return;
    }

    final markPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, markerRadius * 0.22)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (hit.milestone.status) {
      case SimpleMilestoneStatus.done:
        final check = Path()
          ..moveTo(center.dx - radius * 0.42, center.dy)
          ..lineTo(center.dx - radius * 0.12, center.dy + radius * 0.32)
          ..lineTo(center.dx + radius * 0.46, center.dy - radius * 0.34);
        canvas.drawPath(check, markPaint);
      case SimpleMilestoneStatus.blocked:
        canvas.drawLine(
          Offset(center.dx - radius * 0.42, center.dy - radius * 0.42),
          Offset(center.dx + radius * 0.42, center.dy + radius * 0.42),
          markPaint,
        );
      case SimpleMilestoneStatus.active:
        canvas.drawCircle(
          center,
          radius * 0.34,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.95)
            ..style = PaintingStyle.fill,
        );
      case SimpleMilestoneStatus.planned:
        canvas.drawCircle(
          center,
          radius * 0.34,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.2, markerRadius * 0.18),
        );
    }
  }

  void _drawTextBlock(Canvas canvas, _MilestoneHit hit, Color color) {
    final contentWidth = hit.contentRect.width - 12;
    var y = hit.contentRect.top + 6;
    final left = hit.contentRect.left + 6;

    if (showDates) {
      _drawText(
        canvas,
        dateFormatter(hit.milestone.date),
        Rect.fromLTWH(left, y, contentWidth, 14),
        dateStyle.copyWith(color: color),
        align: hit.textAlign,
      );
      y += 15;
    }

    _drawText(
      canvas,
      hit.milestone.label,
      Rect.fromLTWH(left, y, contentWidth, 17),
      labelStyle,
      align: hit.textAlign,
    );
    y += 17;

    if (showDescriptions && hit.milestone.description != null) {
      _drawText(
        canvas,
        hit.milestone.description!,
        Rect.fromLTWH(left, y, contentWidth, 15),
        descriptionStyle,
        align: hit.textAlign,
      );
      y += 16;
    }

    if (showTags && hit.milestone.tag != null) {
      _drawTag(canvas, hit, Rect.fromLTWH(left, y, contentWidth, 15), color);
    }
  }

  void _drawTag(Canvas canvas, _MilestoneHit hit, Rect rect, Color color) {
    final tagStyle = descriptionStyle.copyWith(
      color: color,
      fontWeight: FontWeight.w800,
      fontSize: descriptionStyle.fontSize == null
          ? null
          : math.max(9, descriptionStyle.fontSize! - 1),
    );
    final painter = TextPainter(
      text: TextSpan(text: hit.milestone.tag!, style: tagStyle),
      textDirection: TextDirection.ltr,
      textAlign: hit.textAlign,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: math.min(rect.width, 82));
    final pillWidth = math.min(rect.width, painter.width + 14);
    final left = switch (hit.textAlign) {
      TextAlign.right => rect.right - pillWidth,
      TextAlign.center => rect.left + (rect.width - pillWidth) / 2,
      _ => rect.left,
    };
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, rect.top, pillWidth, 15),
      const Radius.circular(7.5),
    );
    canvas.drawRRect(
      pill,
      Paint()
        ..color = color.withValues(alpha: 0.10)
        ..style = PaintingStyle.fill,
    );
    painter.paint(
      canvas,
      Offset(left + (pillWidth - painter.width) / 2, rect.top),
    );
  }

  Color _milestoneColor(SimpleMilestoneData milestone, int index) {
    if (milestone.color != null) {
      return milestone.color!;
    }
    switch (milestone.status) {
      case SimpleMilestoneStatus.done:
        return doneColor;
      case SimpleMilestoneStatus.active:
        return activeColor;
      case SimpleMilestoneStatus.blocked:
        return blockedColor;
      case SimpleMilestoneStatus.planned:
        final colors = palette;
        if (colors != null && colors.isNotEmpty) {
          return colors[index % colors.length];
        }
        return markerColor;
    }
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
  bool shouldRepaint(covariant _SimpleMilestonePainter oldDelegate) {
    return oldDelegate.milestones != milestones ||
        oldDelegate.orientation != orientation ||
        oldDelegate.minDate != minDate ||
        oldDelegate.maxDate != maxDate ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.doneColor != doneColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.blockedColor != blockedColor ||
        oldDelegate.connectorColor != connectorColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.milestoneBackgroundColor != milestoneBackgroundColor ||
        oldDelegate.dateStyle != dateStyle ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.descriptionStyle != descriptionStyle ||
        oldDelegate.alternating != alternating ||
        oldDelegate.showDates != showDates ||
        oldDelegate.showDescriptions != showDescriptions ||
        oldDelegate.showTags != showTags ||
        oldDelegate.showConnector != showConnector ||
        oldDelegate.showStatusMarks != showStatusMarks ||
        oldDelegate.showActiveMilestone != showActiveMilestone ||
        oldDelegate.markerRadius != markerRadius ||
        oldDelegate.connectorWidth != connectorWidth ||
        oldDelegate.milestoneSpacing != milestoneSpacing ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _MilestoneGeometry {
  final Rect plot;
  final Offset axisStart;
  final Offset axisEnd;
  final List<_MilestoneHit> hits;

  const _MilestoneGeometry({
    required this.plot,
    required this.axisStart,
    required this.axisEnd,
    required this.hits,
  });

  factory _MilestoneGeometry.resolve({
    required List<SimpleMilestoneData> milestones,
    required Size size,
    required EdgeInsets padding,
    required SimpleMilestoneOrientation orientation,
    required DateTime? minDate,
    required DateTime? maxDate,
    required bool alternating,
    required double markerRadius,
    required double milestoneSpacing,
    required bool showDates,
    required bool showDescriptions,
    required bool showTags,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final emptyAxis = Offset(plot.left, plot.center.dy);
    if (milestones.isEmpty || plot.width <= 0 || plot.height <= 0) {
      return _MilestoneGeometry(
        plot: plot,
        axisStart: emptyAxis,
        axisEnd: emptyAxis,
        hits: const [],
      );
    }

    final range = _DateRange.resolve(milestones, minDate, maxDate);
    return orientation == SimpleMilestoneOrientation.vertical
        ? _vertical(
            milestones,
            plot,
            range,
            alternating,
            markerRadius,
            milestoneSpacing,
            showDates,
            showDescriptions,
            showTags,
          )
        : _horizontal(
            milestones,
            plot,
            range,
            alternating,
            markerRadius,
            milestoneSpacing,
            showDates,
            showDescriptions,
            showTags,
          );
  }

  static _MilestoneGeometry _horizontal(
    List<SimpleMilestoneData> milestones,
    Rect plot,
    _DateRange range,
    bool alternating,
    double markerRadius,
    double milestoneSpacing,
    bool showDates,
    bool showDescriptions,
    bool showTags,
  ) {
    final lineY = plot.center.dy;
    final contentHeight = _contentHeight(
      plot.height,
      showDates,
      showDescriptions,
      showTags,
      horizontal: true,
    );
    final contentWidth = math.min(
      132.0,
      math.max(78.0, plot.width / math.max(1, milestones.length) - 4),
    );
    final hits = <_MilestoneHit>[];

    for (var index = 0; index < milestones.length; index++) {
      final milestone = milestones[index];
      final center = Offset(
        plot.left +
            range.ratio(milestone.date, index, milestones.length) * plot.width,
        lineY,
      );
      final above = alternating ? index.isEven : true;
      final top = above
          ? lineY - markerRadius - milestoneSpacing - contentHeight
          : lineY + markerRadius + milestoneSpacing;
      final rect = Rect.fromLTWH(
        (center.dx - contentWidth / 2).clamp(
          plot.left,
          plot.right - contentWidth,
        ),
        top.clamp(plot.top, plot.bottom - contentHeight),
        contentWidth,
        contentHeight,
      );
      hits.add(
        _MilestoneHit(
          milestone: milestone,
          index: index,
          markerCenter: center,
          contentRect: rect,
          hitRect: rect.expandToInclude(
            Rect.fromCircle(center: center, radius: markerRadius + 10),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return _MilestoneGeometry(
      plot: plot,
      axisStart: Offset(plot.left, lineY),
      axisEnd: Offset(plot.right, lineY),
      hits: hits,
    );
  }

  static _MilestoneGeometry _vertical(
    List<SimpleMilestoneData> milestones,
    Rect plot,
    _DateRange range,
    bool alternating,
    double markerRadius,
    double milestoneSpacing,
    bool showDates,
    bool showDescriptions,
    bool showTags,
  ) {
    final lineX = alternating
        ? plot.center.dx
        : math.min(plot.left + 104, plot.right - 92);
    final contentHeight = _contentHeight(
      plot.height,
      showDates,
      showDescriptions,
      showTags,
      horizontal: false,
    );
    final hits = <_MilestoneHit>[];

    for (var index = 0; index < milestones.length; index++) {
      final milestone = milestones[index];
      final center = Offset(
        lineX,
        plot.top +
            range.ratio(milestone.date, index, milestones.length) * plot.height,
      );
      final side = alternating && index.isOdd ? -1 : 1;
      final left = side > 0
          ? center.dx + markerRadius + milestoneSpacing
          : plot.left;
      final right = side > 0
          ? plot.right
          : center.dx - markerRadius - milestoneSpacing;
      final width = math.max(0.0, right - left);
      final rect = Rect.fromLTWH(
        left,
        (center.dy - contentHeight / 2).clamp(
          plot.top,
          plot.bottom - contentHeight,
        ),
        width,
        contentHeight,
      );
      hits.add(
        _MilestoneHit(
          milestone: milestone,
          index: index,
          markerCenter: center,
          contentRect: rect,
          hitRect: rect.expandToInclude(
            Rect.fromCircle(center: center, radius: markerRadius + 10),
          ),
          textAlign: side > 0 ? TextAlign.left : TextAlign.right,
        ),
      );
    }

    return _MilestoneGeometry(
      plot: plot,
      axisStart: Offset(lineX, plot.top),
      axisEnd: Offset(lineX, plot.bottom),
      hits: hits,
    );
  }

  static double _contentHeight(
    double plotHeight,
    bool showDates,
    bool showDescriptions,
    bool showTags, {
    required bool horizontal,
  }) {
    final target =
        25.0 +
        (showDates ? 15.0 : 0) +
        (showDescriptions ? 16.0 : 0) +
        (showTags ? 18.0 : 0);
    final maxHeight = horizontal ? plotHeight / 2 - 10 : 70.0;
    return math.max(36.0, math.min(target, math.max(36.0, maxHeight)));
  }
}

class _DateRange {
  final double startMs;
  final double spanMs;
  final bool useIndexFallback;

  const _DateRange({
    required this.startMs,
    required this.spanMs,
    required this.useIndexFallback,
  });

  factory _DateRange.resolve(
    List<SimpleMilestoneData> milestones,
    DateTime? minDate,
    DateTime? maxDate,
  ) {
    var low = minDate ?? milestones.first.date;
    var high = maxDate ?? milestones.first.date;
    for (final milestone in milestones) {
      if (minDate == null && milestone.date.isBefore(low)) {
        low = milestone.date;
      }
      if (maxDate == null && milestone.date.isAfter(high)) {
        high = milestone.date;
      }
    }
    if (high.isBefore(low)) {
      final swap = low;
      low = high;
      high = swap;
    }
    final start = low.millisecondsSinceEpoch.toDouble();
    final span = high.millisecondsSinceEpoch.toDouble() - start;
    return _DateRange(
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
}

class _MilestoneHit {
  final SimpleMilestoneData milestone;
  final int index;
  final Offset markerCenter;
  final Rect contentRect;
  final Rect hitRect;
  final TextAlign textAlign;

  const _MilestoneHit({
    required this.milestone,
    required this.index,
    required this.markerCenter,
    required this.contentRect,
    required this.hitRect,
    required this.textAlign,
  });
}

class _SimpleMilestoneVisuals {
  final Color markerColor;
  final Color doneColor;
  final Color activeColor;
  final Color blockedColor;
  final Color connectorColor;
  final Color trackColor;
  final Color milestoneBackgroundColor;

  const _SimpleMilestoneVisuals({
    required this.markerColor,
    required this.doneColor,
    required this.activeColor,
    required this.blockedColor,
    required this.connectorColor,
    required this.trackColor,
    required this.milestoneBackgroundColor,
  });

  factory _SimpleMilestoneVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleMilestoneVisuals(
          markerColor: colorScheme.primary,
          doneColor: const Color(0xFF16A34A),
          activeColor: colorScheme.tertiary,
          blockedColor: colorScheme.error,
          connectorColor: colorScheme.primary.withValues(alpha: 0.45),
          trackColor: colorScheme.outlineVariant.withValues(alpha: 0.62),
          milestoneBackgroundColor: colorScheme.primary.withValues(alpha: 0.05),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleMilestoneVisuals(
          markerColor: colorScheme.primary,
          doneColor: colorScheme.primary,
          activeColor: colorScheme.onSurface,
          blockedColor: colorScheme.error,
          connectorColor: colorScheme.outline.withValues(alpha: 0.55),
          trackColor: colorScheme.outlineVariant.withValues(alpha: 0.72),
          milestoneBackgroundColor: colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.22),
        );
      case SimpleBarChartStyle.education:
        return _SimpleMilestoneVisuals(
          markerColor: colorScheme.secondary,
          doneColor: const Color(0xFF059669),
          activeColor: colorScheme.primary,
          blockedColor: colorScheme.error,
          connectorColor: colorScheme.secondary.withValues(alpha: 0.42),
          trackColor: colorScheme.outlineVariant.withValues(alpha: 0.62),
          milestoneBackgroundColor: colorScheme.secondary.withValues(
            alpha: 0.06,
          ),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleMilestoneVisuals(
          markerColor: colorScheme.tertiary,
          doneColor: const Color(0xFF10B981),
          activeColor: colorScheme.primary,
          blockedColor: colorScheme.error,
          connectorColor: colorScheme.tertiary.withValues(alpha: 0.42),
          trackColor: colorScheme.outlineVariant.withValues(alpha: 0.58),
          milestoneBackgroundColor: colorScheme.tertiary.withValues(
            alpha: 0.06,
          ),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleMilestoneVisuals(
          markerColor: colorScheme.primary,
          doneColor: const Color(0xFF0F9F6E),
          activeColor: colorScheme.tertiary,
          blockedColor: colorScheme.error,
          connectorColor: colorScheme.primary.withValues(alpha: 0.42),
          trackColor: colorScheme.outlineVariant.withValues(alpha: 0.62),
          milestoneBackgroundColor: colorScheme.primary.withValues(alpha: 0.05),
        );
    }
  }
}

class _DefaultMilestoneTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultMilestoneTooltip({required this.title, required this.rows});

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
        constraints: const BoxConstraints(maxWidth: 220),
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
                        SizedBox(width: 44, child: Text(row.label)),
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
