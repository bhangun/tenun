import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../line/simple_line_chart.dart';

typedef SimpleBumpRankFormatter = String Function(int rank);
typedef SimpleBumpTapCallback =
    void Function(
      String period,
      SimpleBumpSeries series,
      int rank,
      int periodIndex,
      int seriesIndex,
    );
typedef SimpleBumpTooltipBuilder =
    Widget Function(
      BuildContext context,
      String period,
      SimpleBumpSeries series,
      int rank,
      int periodIndex,
      int seriesIndex,
      String formattedRank,
    );

class SimpleBumpSeries {
  final String name;
  final List<int> ranks;
  final Color? color;

  const SimpleBumpSeries({required this.name, required this.ranks, this.color});
}

/// A compact rank-over-time chart for leaderboards, priorities, cohorts, and
/// competitive movement.
class SimpleBumpChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(44, 20, 18, 38);

  final List<String> periods;
  final List<SimpleBumpSeries> series;
  final SimpleTrendChartStyle style;
  final int? maxRank;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? lineColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSeries;
  final bool smooth;
  final int gridLineCount;
  final double? strokeWidth;
  final double? dotRadius;
  final SimpleBumpRankFormatter? rankFormatter;
  final SimpleBumpTapCallback? onPointTap;
  final SimpleBumpTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleBumpChart({
    super.key,
    required this.periods,
    required this.series,
    this.style = SimpleTrendChartStyle.elegant,
    this.maxRank,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.lineColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showDots = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveSeries = true,
    this.smooth = true,
    this.gridLineCount = 5,
    this.strokeWidth,
    this.dotRadius,
    this.rankFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 750),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(maxRank == null || maxRank > 0),
       assert(gridLineCount >= 2),
       assert(strokeWidth == null || strokeWidth > 0),
       assert(dotRadius == null || dotRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleBumpVisuals.resolve(style, colorScheme);
    final visiblePeriods = periods
        .where((period) => period.trim().isNotEmpty)
        .toList();
    final visibleSeries = series
        .where((item) => item.ranks.any((rank) => rank > 0))
        .toList();
    final formatter = rankFormatter ?? _defaultRankFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visiblePeriods.isEmpty || visibleSeries.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Bump chart, no data.',
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
            visiblePeriods,
            visibleSeries,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleBumpChartView(
            width: width,
            height: chartHeight,
            periods: visiblePeriods,
            series: visibleSeries,
            maxRank: maxRank,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals.lineColor),
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showDots: showDots,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveSeries: showActiveSeries,
            smooth: smooth,
            gridLineCount: gridLineCount,
            strokeWidth: strokeWidth ?? visuals.strokeWidth,
            dotRadius: dotRadius ?? visuals.dotRadius,
            rankFormatter: formatter,
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
      lineColor ?? fallback,
      colorScheme.secondary,
      colorScheme.tertiary,
      colorScheme.error,
    ];
  }

  String _defaultSemanticLabel(
    List<String> visiblePeriods,
    List<SimpleBumpSeries> visibleSeries,
    SimpleBumpRankFormatter formatter,
  ) {
    final summaries = visibleSeries
        .take(3)
        .map((item) {
          final ranks = <String>[];
          final limit = math.min(visiblePeriods.length, item.ranks.length);
          for (var index = 0; index < math.min(limit, 4); index++) {
            final rank = item.ranks[index];
            if (rank <= 0) continue;
            ranks.add('${visiblePeriods[index]} ${formatter(rank)}');
          }
          return '${item.name}: ${ranks.join(', ')}';
        })
        .join('; ');
    final suffix = visibleSeries.length > 3
        ? '; and ${visibleSeries.length - 3} more series'
        : '';
    return 'Bump chart, ${visibleSeries.length} series across '
        '${visiblePeriods.length} periods. $summaries$suffix.';
  }

  static String _defaultRankFormatter(int rank) => '#$rank';
}

class _SimpleBumpChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<String> periods;
  final List<SimpleBumpSeries> series;
  final int? maxRank;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveSeries;
  final bool smooth;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final SimpleBumpRankFormatter rankFormatter;
  final SimpleBumpTapCallback? onPointTap;
  final SimpleBumpTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleBumpChartView({
    required this.width,
    required this.height,
    required this.periods,
    required this.series,
    required this.maxRank,
    required this.padding,
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showDots,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveSeries,
    required this.smooth,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.rankFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleBumpChartView> createState() => _SimpleBumpChartViewState();
}

class _SimpleBumpChartViewState extends State<_SimpleBumpChartView> {
  _BumpSelection? _active;

  @override
  Widget build(BuildContext context) {
    final hasLegend = widget.showLegend && widget.series.length > 1;
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveSeries ||
        widget.onPointTap != null;

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
                      painter: _SimpleBumpPainter(
                        periods: widget.periods,
                        series: widget.series,
                        maxRank: widget.maxRank,
                        padding: widget.padding,
                        palette: widget.palette,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showDots: widget.showDots,
                        showValues: widget.showValues,
                        showActiveSeries: widget.showActiveSeries,
                        smooth: widget.smooth,
                        gridLineCount: widget.gridLineCount,
                        strokeWidth: widget.strokeWidth,
                        dotRadius: widget.dotRadius,
                        activeSelection: _active,
                        rankFormatter: widget.rankFormatter,
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
                            final rank =
                                selectedSeries.ranks[selection.periodIndex];
                            widget.onPointTap?.call(
                              widget.periods[selection.periodIndex],
                              selectedSeries,
                              rank,
                              selection.periodIndex,
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

  void _setActive(_BumpSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _BumpSelection? _hitTest(Offset position, Size size) {
    final geometry = _BumpGeometry.resolve(
      size: size,
      periods: widget.periods,
      series: widget.series,
      maxRank: widget.maxRank,
      padding: widget.padding,
    );
    for (final point in geometry.points) {
      if ((position - point.center).distance <= widget.dotRadius + 10) {
        return _BumpSelection(
          point.periodIndex,
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
    _BumpSelection selection,
  ) {
    final selectedSeries = widget.series[selection.seriesIndex];
    final period = widget.periods[selection.periodIndex];
    final rank = selectedSeries.ranks[selection.periodIndex];
    final formattedRank = widget.rankFormatter(rank);
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
            period,
            selectedSeries,
            rank,
            selection.periodIndex,
            selection.seriesIndex,
            formattedRank,
          ) ??
          _DefaultBumpTooltip(
            color: _seriesColor(selectedSeries, selection.seriesIndex),
            title: period,
            label: selectedSeries.name,
            value: formattedRank,
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
            _BumpLegendItem(
              label: widget.series[index].name,
              color: _seriesColor(widget.series[index], index),
              textStyle: widget.labelStyle,
            ),
        ],
      ),
    );
  }

  Color _seriesColor(SimpleBumpSeries item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleBumpPainter extends CustomPainter {
  final List<String> periods;
  final List<SimpleBumpSeries> series;
  final int? maxRank;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showDots;
  final bool showValues;
  final bool showActiveSeries;
  final bool smooth;
  final int gridLineCount;
  final double strokeWidth;
  final double dotRadius;
  final _BumpSelection? activeSelection;
  final SimpleBumpRankFormatter rankFormatter;
  final double progress;

  const _SimpleBumpPainter({
    required this.periods,
    required this.series,
    required this.maxRank,
    required this.padding,
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showDots,
    required this.showValues,
    required this.showActiveSeries,
    required this.smooth,
    required this.gridLineCount,
    required this.strokeWidth,
    required this.dotRadius,
    required this.activeSelection,
    required this.rankFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _BumpGeometry.resolve(
      size: size,
      periods: periods,
      series: series,
      maxRank: maxRank,
      padding: padding,
    );
    if (geometry.plot.isEmpty || geometry.points.isEmpty) return;

    if (showGrid) _drawGrid(canvas, geometry);
    _drawAxis(canvas, geometry);
    _drawLines(canvas, geometry);
    _drawPeriodLabels(canvas, geometry);
  }

  void _drawGrid(Canvas canvas, _BumpGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final rankStep = math.max(1, (geometry.maxRank / gridLineCount).ceil());
    for (var rank = 1; rank <= geometry.maxRank; rank += rankStep) {
      final y = geometry.yForRank(rank);
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
      _paintText(
        canvas,
        rankFormatter(rank),
        labelStyle.copyWith(
          color: labelStyle.color?.withValues(alpha: 0.72),
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
        ),
        Offset(geometry.plot.left - 8, y),
        TextAlign.right,
        math.max(0.0, padding.left - 12),
        centeredY: true,
      );
    }
  }

  void _drawAxis(Canvas canvas, _BumpGeometry geometry) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.bottom),
      Offset(geometry.plot.right, geometry.plot.bottom),
      paint,
    );
  }

  void _drawLines(Canvas canvas, _BumpGeometry geometry) {
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final item = series[seriesIndex];
      final points = geometry.pointsForSeries(seriesIndex);
      if (points.isEmpty) continue;
      final color = item.color ?? palette[seriesIndex % palette.length];
      final isActive = activeSelection?.seriesIndex == seriesIndex;
      final activeExists = activeSelection != null;
      final opacity = activeExists && !isActive ? 0.32 : 1.0;
      final path = _seriesPath(points, geometry);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isActive ? strokeWidth + 1.6 : strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);

      if (showActiveSeries && isActive) {
        canvas.drawPath(
          path,
          Paint()
            ..color = (activeColor ?? color).withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 7
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(path, paint);
      }

      if (showDots) {
        for (final point in points) {
          final selected =
              activeSelection?.seriesIndex == point.seriesIndex &&
              activeSelection?.periodIndex == point.periodIndex;
          _drawDot(canvas, point, color.withValues(alpha: opacity), selected);
        }
      }

      if (showValues && progress > 0.65) {
        for (final point in points) {
          _drawRankValue(canvas, point);
        }
      }
    }
  }

  Path _seriesPath(List<_BumpPointLayout> points, _BumpGeometry geometry) {
    final visiblePoints = points.map((point) {
      final startY = geometry.yForRank(geometry.maxRank);
      return Offset(
        point.center.dx,
        startY + (point.center.dy - startY) * progress,
      );
    }).toList();
    final path = Path()..moveTo(visiblePoints.first.dx, visiblePoints.first.dy);
    if (!smooth || visiblePoints.length < 3) {
      for (final point in visiblePoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      return path;
    }

    for (var index = 0; index < visiblePoints.length - 1; index++) {
      final current = visiblePoints[index];
      final next = visiblePoints[index + 1];
      final midX = (current.dx + next.dx) / 2;
      path.cubicTo(midX, current.dy, midX, next.dy, next.dx, next.dy);
    }
    return path;
  }

  void _drawDot(
    Canvas canvas,
    _BumpPointLayout point,
    Color color,
    bool selected,
  ) {
    final startY = point.geometry.yForRank(point.geometry.maxRank);
    final center = Offset(
      point.center.dx,
      startY + (point.center.dy - startY) * progress,
    );
    final radius = dotRadius * (0.5 + progress * 0.5);
    canvas.drawCircle(
      center,
      radius + 1.4,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawCircle(center, radius, Paint()..color = color);
    if (!showActiveSeries || !selected) return;
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

  void _drawRankValue(Canvas canvas, _BumpPointLayout point) {
    final rank = series[point.seriesIndex].ranks[point.periodIndex];
    _paintText(
      canvas,
      rankFormatter(rank),
      valueStyle,
      Offset(point.center.dx, point.center.dy - dotRadius - 18),
      TextAlign.center,
      46,
    );
  }

  void _drawPeriodLabels(Canvas canvas, _BumpGeometry geometry) {
    for (var index = 0; index < periods.length; index++) {
      _paintText(
        canvas,
        periods[index],
        labelStyle,
        Offset(geometry.xForPeriod(index), geometry.plot.bottom + 8),
        TextAlign.center,
        math.max(34.0, geometry.periodWidth - 4),
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

  @override
  bool shouldRepaint(covariant _SimpleBumpPainter oldDelegate) {
    return oldDelegate.periods != periods ||
        oldDelegate.series != series ||
        oldDelegate.maxRank != maxRank ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showDots != showDots ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showActiveSeries != showActiveSeries ||
        oldDelegate.smooth != smooth ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dotRadius != dotRadius ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.rankFormatter != rankFormatter ||
        oldDelegate.progress != progress;
  }
}

class _BumpGeometry {
  final Rect plot;
  final List<_BumpPointLayout> points;
  final int maxRank;
  final double periodWidth;

  const _BumpGeometry({
    required this.plot,
    required this.points,
    required this.maxRank,
    required this.periodWidth,
  });

  factory _BumpGeometry.resolve({
    required Size size,
    required List<String> periods,
    required List<SimpleBumpSeries> series,
    required int? maxRank,
    required EdgeInsets padding,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 ||
        plot.height <= 0 ||
        periods.isEmpty ||
        series.isEmpty) {
      return _BumpGeometry(
        plot: plot,
        points: const [],
        maxRank: 1,
        periodWidth: 0,
      );
    }

    final detectedMax = series.fold<int>(1, (current, item) {
      final localMax = item.ranks
          .where((rank) => rank > 0)
          .fold<int>(1, (rankMax, rank) => math.max(rankMax, rank));
      return math.max(current, localMax);
    });
    final resolvedMaxRank = math.max(1, maxRank ?? detectedMax);
    final periodWidth = periods.length <= 1
        ? plot.width
        : plot.width / (periods.length - 1);
    final geometry = _BumpGeometry(
      plot: plot,
      points: const [],
      maxRank: resolvedMaxRank,
      periodWidth: periodWidth,
    );
    final points = <_BumpPointLayout>[];
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final item = series[seriesIndex];
      final count = math.min(periods.length, item.ranks.length);
      for (var periodIndex = 0; periodIndex < count; periodIndex++) {
        final rank = item.ranks[periodIndex];
        if (rank <= 0) continue;
        points.add(
          _BumpPointLayout(
            periodIndex: periodIndex,
            seriesIndex: seriesIndex,
            center: Offset(
              geometry.xForPeriod(periodIndex),
              geometry.yForRank(rank),
            ),
            geometry: geometry,
          ),
        );
      }
    }
    return _BumpGeometry(
      plot: plot,
      points: points,
      maxRank: resolvedMaxRank,
      periodWidth: periodWidth,
    );
  }

  double xForPeriod(int periodIndex) {
    if (periodWidth == 0) return plot.center.dx;
    return plot.left + periodWidth * periodIndex;
  }

  double yForRank(int rank) {
    if (maxRank <= 1) return plot.center.dy;
    final normalized = ((rank - 1) / (maxRank - 1)).clamp(0.0, 1.0);
    return plot.top + normalized * plot.height;
  }

  List<_BumpPointLayout> pointsForSeries(int seriesIndex) {
    final result =
        points.where((point) => point.seriesIndex == seriesIndex).toList()
          ..sort((a, b) => a.periodIndex.compareTo(b.periodIndex));
    return result;
  }
}

class _BumpPointLayout {
  final int periodIndex;
  final int seriesIndex;
  final Offset center;
  final _BumpGeometry geometry;

  const _BumpPointLayout({
    required this.periodIndex,
    required this.seriesIndex,
    required this.center,
    required this.geometry,
  });
}

class _BumpSelection {
  final int periodIndex;
  final int seriesIndex;
  final Offset position;

  const _BumpSelection(this.periodIndex, this.seriesIndex, this.position);

  @override
  bool operator ==(Object other) {
    return other is _BumpSelection &&
        other.periodIndex == periodIndex &&
        other.seriesIndex == seriesIndex;
  }

  @override
  int get hashCode => Object.hash(periodIndex, seriesIndex);
}

class _SimpleBumpVisuals {
  final Color lineColor;
  final Color gridColor;
  final Color axisColor;
  final double strokeWidth;
  final double dotRadius;

  const _SimpleBumpVisuals({
    required this.lineColor,
    required this.gridColor,
    required this.axisColor,
    required this.strokeWidth,
    required this.dotRadius,
  });

  factory _SimpleBumpVisuals.resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleBumpVisuals(
          lineColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.5),
          strokeWidth: 3,
          dotRadius: 5.5,
        );
      case SimpleTrendChartStyle.professional:
        return _SimpleBumpVisuals(
          lineColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          strokeWidth: 2.4,
          dotRadius: 4.8,
        );
      case SimpleTrendChartStyle.education:
        return _SimpleBumpVisuals(
          lineColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          strokeWidth: 2.8,
          dotRadius: 5.2,
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleBumpVisuals(
          lineColor: colorScheme.tertiary,
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          strokeWidth: 3.2,
          dotRadius: 5.8,
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleBumpVisuals(
          lineColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          strokeWidth: 2.8,
          dotRadius: 5.2,
        );
    }
  }
}

class _BumpLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final TextStyle textStyle;

  const _BumpLegendItem({
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
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: textStyle),
      ],
    );
  }
}

class _DefaultBumpTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String label;
  final String value;

  const _DefaultBumpTooltip({
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
                  width: 12,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
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
