import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleTernaryValueFormatter = String Function(double value);
typedef SimpleTernaryPointTapCallback =
    void Function(
      SimpleTernaryPoint point,
      int index,
      SimpleTernaryShare share,
    );
typedef SimpleTernaryTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleTernaryPoint point,
      int index,
      SimpleTernaryShare share,
      String formattedA,
      String formattedB,
      String formattedC,
      String? formattedSize,
    );

class SimpleTernaryPoint {
  final String label;
  final double a;
  final double b;
  final double c;
  final double? size;
  final String? group;
  final Color? color;

  const SimpleTernaryPoint({
    required this.label,
    required this.a,
    required this.b,
    required this.c,
    this.size,
    this.group,
    this.color,
  });
}

class SimpleTernaryShare {
  final double a;
  final double b;
  final double c;

  const SimpleTernaryShare({required this.a, required this.b, required this.c});
}

/// A simple ternary plot for three-way mixes, tradeoffs, compositions, and
/// balance maps across business, education, product, and scientific domains.
class SimpleTernaryChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(36, 28, 36, 40);

  final List<SimpleTernaryPoint> points;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final String aAxisLabel;
  final String bAxisLabel;
  final String cAxisLabel;
  final Color? pointColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showAxisLabels;
  final bool showPointLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final int gridLineCount;
  final double? pointRadius;
  final double? minPointRadius;
  final double? maxPointRadius;
  final SimpleTernaryValueFormatter? valueFormatter;
  final SimpleTernaryValueFormatter? sizeFormatter;
  final SimpleTernaryPointTapCallback? onPointTap;
  final SimpleTernaryTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleTernaryChart({
    super.key,
    required this.points,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 280,
    this.padding = _defaultPadding,
    this.aAxisLabel = 'A',
    this.bAxisLabel = 'B',
    this.cAxisLabel = 'C',
    this.pointColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showAxisLabels = true,
    this.showPointLabels = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActivePoint = true,
    this.gridLineCount = 4,
    this.pointRadius,
    this.minPointRadius,
    this.maxPointRadius,
    this.valueFormatter,
    this.sizeFormatter,
    this.onPointTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(pointRadius == null || pointRadius >= 0),
       assert(minPointRadius == null || minPointRadius >= 0),
       assert(maxPointRadius == null || maxPointRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleTernaryVisuals.resolve(style, colorScheme);
    final visiblePoints = points.where(_isValidPoint).toList();
    final formatter = valueFormatter ?? _defaultPercentFormatter;
    final resolvedSizeFormatter = sizeFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visiblePoints.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Ternary chart, no data.',
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
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visiblePoints,
            formatter,
            aAxisLabel,
            bAxisLabel,
            cAxisLabel,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleTernaryView(
            width: width,
            height: chartHeight,
            points: visiblePoints,
            padding: padding,
            aAxisLabel: aAxisLabel,
            bAxisLabel: bAxisLabel,
            cAxisLabel: cAxisLabel,
            pointColor: pointColor ?? visuals.pointColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            palette: palette ?? visuals.palette,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showAxisLabels: showAxisLabels,
            showPointLabels: showPointLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActivePoint: showActivePoint,
            gridLineCount: gridLineCount,
            pointRadius: pointRadius,
            minPointRadius: minPointRadius ?? visuals.minPointRadius,
            maxPointRadius: maxPointRadius ?? visuals.maxPointRadius,
            valueFormatter: formatter,
            sizeFormatter: resolvedSizeFormatter,
            onPointTap: onPointTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static bool _isValidPoint(SimpleTernaryPoint point) {
    return point.a.isFinite &&
        point.b.isFinite &&
        point.c.isFinite &&
        point.a >= 0 &&
        point.b >= 0 &&
        point.c >= 0 &&
        point.a + point.b + point.c > 0 &&
        (point.size == null || point.size!.isFinite);
  }

  static SimpleTernaryShare shareFor(SimpleTernaryPoint point) {
    final total = point.a + point.b + point.c;
    if (total <= 0 || !total.isFinite) {
      return const SimpleTernaryShare(a: 0, b: 0, c: 0);
    }
    return SimpleTernaryShare(
      a: point.a / total,
      b: point.b / total,
      c: point.c / total,
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleTernaryPoint> points,
    SimpleTernaryValueFormatter formatter,
    String aAxisLabel,
    String bAxisLabel,
    String cAxisLabel,
  ) {
    final sample = points
        .take(6)
        .map((point) {
          final share = shareFor(point);
          return '${point.label} $aAxisLabel ${formatter(share.a * 100)}, '
              '$bAxisLabel ${formatter(share.b * 100)}, '
              '$cAxisLabel ${formatter(share.c * 100)}';
        })
        .join(', ');
    final suffix = points.length > 6 ? ', and ${points.length - 6} more' : '';
    return 'Ternary chart, ${points.length} points. $sample$suffix.';
  }

  static String _defaultPercentFormatter(double value) =>
      '${value.toStringAsFixed(0)}%';

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleTernaryView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleTernaryPoint> points;
  final EdgeInsets padding;
  final String aAxisLabel;
  final String bAxisLabel;
  final String cAxisLabel;
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color> palette;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showAxisLabels;
  final bool showPointLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActivePoint;
  final int gridLineCount;
  final double? pointRadius;
  final double minPointRadius;
  final double maxPointRadius;
  final SimpleTernaryValueFormatter valueFormatter;
  final SimpleTernaryValueFormatter sizeFormatter;
  final SimpleTernaryPointTapCallback? onPointTap;
  final SimpleTernaryTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleTernaryView({
    required this.width,
    required this.height,
    required this.points,
    required this.padding,
    required this.aAxisLabel,
    required this.bAxisLabel,
    required this.cAxisLabel,
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showAxisLabels,
    required this.showPointLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActivePoint,
    required this.gridLineCount,
    required this.pointRadius,
    required this.minPointRadius,
    required this.maxPointRadius,
    required this.valueFormatter,
    required this.sizeFormatter,
    required this.onPointTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleTernaryView> createState() => _SimpleTernaryViewState();
}

class _SimpleTernaryViewState extends State<_SimpleTernaryView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  _TernaryPointLayout? _activePoint;
  Offset _pointer = Offset.zero;

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
  void didUpdateWidget(covariant _SimpleTernaryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points ||
        oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.animationCurve != widget.animationCurve) {
      _controller.duration = widget.animationDuration;
      _animation = CurvedAnimation(
        parent: _controller,
        curve: widget.animationCurve,
      );
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final geometry = _TernaryGeometry.resolve(
            size: Size(widget.width, widget.height),
            points: widget.points,
            padding: widget.padding,
            palette: widget.palette,
            pointColor: widget.pointColor,
            pointRadius: widget.pointRadius,
            minPointRadius: widget.minPointRadius,
            maxPointRadius: widget.maxPointRadius,
            showLegend: widget.showLegend,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onHover: (event) {
                    _setActive(_hitTest(event.localPosition, geometry));
                    _pointer = event.localPosition;
                  },
                  onExit: (_) => _setActive(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final point = _hitTest(details.localPosition, geometry);
                      _setActive(point);
                      _pointer = details.localPosition;
                      if (point != null) {
                        widget.onPointTap?.call(
                          point.point,
                          point.index,
                          point.share,
                        );
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SimpleTernaryPainter(
                            geometry: geometry,
                            aAxisLabel: widget.aAxisLabel,
                            bAxisLabel: widget.bAxisLabel,
                            cAxisLabel: widget.cAxisLabel,
                            gridColor: widget.gridColor,
                            axisColor: widget.axisColor,
                            activeColor: widget.activeColor,
                            labelStyle: widget.labelStyle,
                            valueStyle: widget.valueStyle,
                            showGrid: widget.showGrid,
                            showAxisLabels: widget.showAxisLabels,
                            showPointLabels: widget.showPointLabels,
                            showValues: widget.showValues,
                            showLegend: widget.showLegend,
                            showActivePoint: widget.showActivePoint,
                            gridLineCount: widget.gridLineCount,
                            valueFormatter: widget.valueFormatter,
                            activePoint: _activePoint,
                            progress: _animation.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activePoint != null)
                _buildTooltip(context, Size(widget.width, widget.height)),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_TernaryPointLayout? point) {
    if (_activePoint?.index == point?.index) {
      return;
    }
    setState(() => _activePoint = point);
  }

  _TernaryPointLayout? _hitTest(Offset position, _TernaryGeometry geometry) {
    for (var i = geometry.points.length - 1; i >= 0; i--) {
      final point = geometry.points[i];
      if ((position - point.center).distance <= point.radius + 7) {
        return point;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final point = _activePoint!;
    final formattedA = widget.valueFormatter(point.share.a * 100);
    final formattedB = widget.valueFormatter(point.share.b * 100);
    final formattedC = widget.valueFormatter(point.share.c * 100);
    final formattedSize = point.point.size == null
        ? null
        : widget.sizeFormatter(point.point.size!);
    final child =
        widget.tooltipBuilder?.call(
          context,
          point.point,
          point.index,
          point.share,
          formattedA,
          formattedB,
          formattedC,
          formattedSize,
        ) ??
        _DefaultTernaryTooltip(
          point: point.point,
          aAxisLabel: widget.aAxisLabel,
          bAxisLabel: widget.bAxisLabel,
          cAxisLabel: widget.cAxisLabel,
          formattedA: formattedA,
          formattedB: formattedB,
          formattedC: formattedC,
          formattedSize: formattedSize,
        );
    const tooltipWidth = 188.0;
    const tooltipHeight = 132.0;
    final maxLeft = math.max(8.0, size.width - tooltipWidth - 8);
    final maxTop = math.max(8.0, size.height - tooltipHeight - 8);
    final left = (_pointer.dx + 12).clamp(8.0, maxLeft).toDouble();
    final top = (_pointer.dy - tooltipHeight - 8).clamp(8.0, maxTop).toDouble();
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(child: child),
    );
  }
}

class _SimpleTernaryPainter extends CustomPainter {
  final _TernaryGeometry geometry;
  final String aAxisLabel;
  final String bAxisLabel;
  final String cAxisLabel;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showAxisLabels;
  final bool showPointLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActivePoint;
  final int gridLineCount;
  final SimpleTernaryValueFormatter valueFormatter;
  final _TernaryPointLayout? activePoint;
  final double progress;

  const _SimpleTernaryPainter({
    required this.geometry,
    required this.aAxisLabel,
    required this.bAxisLabel,
    required this.cAxisLabel,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showAxisLabels,
    required this.showPointLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActivePoint,
    required this.gridLineCount,
    required this.valueFormatter,
    required this.activePoint,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawTriangle(canvas);
    if (showGrid) {
      _drawGrid(canvas);
    }
    if (showAxisLabels) {
      _drawAxisLabels(canvas);
    }
    _drawPoints(canvas);
    if (showLegend) {
      _drawLegend(canvas);
    }
  }

  void _drawTriangle(Canvas canvas) {
    final path = Path()
      ..moveTo(geometry.aVertex.dx, geometry.aVertex.dy)
      ..lineTo(geometry.cVertex.dx, geometry.cVertex.dy)
      ..lineTo(geometry.bVertex.dx, geometry.bVertex.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = axisColor.withValues(alpha: 0.08 * progress)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = axisColor.withValues(alpha: 0.74 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.86 * progress)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < gridLineCount; i++) {
      final t = i / gridLineCount;
      canvas.drawLine(
        Offset.lerp(geometry.bVertex, geometry.aVertex, t)!,
        Offset.lerp(geometry.cVertex, geometry.aVertex, t)!,
        paint,
      );
      canvas.drawLine(
        Offset.lerp(geometry.aVertex, geometry.bVertex, t)!,
        Offset.lerp(geometry.cVertex, geometry.bVertex, t)!,
        paint,
      );
      canvas.drawLine(
        Offset.lerp(geometry.aVertex, geometry.cVertex, t)!,
        Offset.lerp(geometry.bVertex, geometry.cVertex, t)!,
        paint,
      );
    }
  }

  void _drawAxisLabels(Canvas canvas) {
    _drawText(
      canvas,
      aAxisLabel,
      geometry.aVertex + const Offset(-46, -22),
      labelStyle.copyWith(fontWeight: FontWeight.w800),
      maxWidth: 92,
      align: TextAlign.center,
    );
    _drawText(
      canvas,
      bAxisLabel,
      geometry.bVertex + const Offset(-76, 10),
      labelStyle.copyWith(fontWeight: FontWeight.w800),
      maxWidth: 92,
      align: TextAlign.center,
    );
    _drawText(
      canvas,
      cAxisLabel,
      geometry.cVertex + const Offset(-16, 10),
      labelStyle.copyWith(fontWeight: FontWeight.w800),
      maxWidth: 92,
      align: TextAlign.center,
    );
  }

  void _drawPoints(Canvas canvas) {
    for (final point in geometry.points) {
      final active = activePoint?.index == point.index;
      final opacity = activePoint == null || active ? 1.0 : 0.38;
      final center = Offset.lerp(geometry.center, point.center, progress)!;
      final radius = point.radius * (0.48 + 0.52 * progress);
      if (showActivePoint && active) {
        canvas.drawCircle(
          center,
          radius + 7,
          Paint()
            ..color = activeColor.withValues(alpha: 0.18)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = point.color.withValues(alpha: opacity * progress)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.74 * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2.2 : 1.2,
      );
      if (showPointLabels) {
        _drawPointLabel(canvas, point, center, opacity);
      }
    }
  }

  void _drawPointLabel(
    Canvas canvas,
    _TernaryPointLayout point,
    Offset center,
    double opacity,
  ) {
    final label = showValues
        ? '${point.point.label} ${valueFormatter(point.share.a * 100)}'
        : point.point.label;
    _drawText(
      canvas,
      label,
      Offset(center.dx - 42, center.dy + point.radius + 4),
      valueStyle.copyWith(
        color: (valueStyle.color ?? Colors.black).withValues(
          alpha: opacity * progress,
        ),
      ),
      maxWidth: 84,
      align: TextAlign.center,
    );
  }

  void _drawLegend(Canvas canvas) {
    if (geometry.groupColors.isEmpty) {
      return;
    }
    final entries = geometry.groupColors.entries.take(4).toList();
    var dx = geometry.plotRect.left;
    final y = geometry.plotRect.bottom + 12;
    for (final entry in entries) {
      canvas.drawCircle(
        Offset(dx + 5, y + 5),
        4,
        Paint()
          ..color = entry.value.withValues(alpha: progress)
          ..style = PaintingStyle.fill,
      );
      final painter = _textPainter(
        entry.key,
        valueStyle.copyWith(
          color: (valueStyle.color ?? Colors.black).withValues(alpha: progress),
        ),
        maxWidth: 76,
      );
      painter.paint(canvas, Offset(dx + 13, y - 2));
      dx += math.min(98, painter.width + 28);
      if (dx > geometry.plotRect.right - 72) {
        break;
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double? maxWidth,
    TextAlign align = TextAlign.left,
  }) {
    final painter = _textPainter(text, style, maxWidth: maxWidth, align: align);
    painter.paint(canvas, offset);
  }

  TextPainter _textPainter(
    String text,
    TextStyle style, {
    double? maxWidth,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    return painter;
  }

  @override
  bool shouldRepaint(covariant _SimpleTernaryPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.aAxisLabel != aAxisLabel ||
        oldDelegate.bAxisLabel != bAxisLabel ||
        oldDelegate.cAxisLabel != cAxisLabel ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.showPointLabels != showPointLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActivePoint != showActivePoint ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.activePoint != activePoint ||
        oldDelegate.progress != progress;
  }
}

class _TernaryGeometry {
  final Rect plotRect;
  final Offset aVertex;
  final Offset bVertex;
  final Offset cVertex;
  final Offset center;
  final List<_TernaryPointLayout> points;
  final Map<String, Color> groupColors;

  const _TernaryGeometry({
    required this.plotRect,
    required this.aVertex,
    required this.bVertex,
    required this.cVertex,
    required this.center,
    required this.points,
    required this.groupColors,
  });

  factory _TernaryGeometry.resolve({
    required Size size,
    required List<SimpleTernaryPoint> points,
    required EdgeInsets padding,
    required List<Color> palette,
    required Color pointColor,
    required double? pointRadius,
    required double minPointRadius,
    required double maxPointRadius,
    required bool showLegend,
  }) {
    final legendHeight = showLegend ? 26.0 : 0.0;
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal),
      math.max(1, size.height - padding.vertical - legendHeight),
    );
    final side = math.min(
      plotRect.width * 0.76,
      plotRect.height * 0.82 / (math.sqrt(3) / 2),
    );
    final triangleHeight = side * math.sqrt(3) / 2;
    final center = Offset(plotRect.center.dx, plotRect.center.dy + side * 0.04);
    final aVertex = Offset(center.dx, center.dy - triangleHeight * 2 / 3);
    final bVertex = Offset(
      center.dx - side / 2,
      center.dy + triangleHeight / 3,
    );
    final cVertex = Offset(
      center.dx + side / 2,
      center.dy + triangleHeight / 3,
    );
    final groupColors = _resolveGroupColors(points, palette);
    final maxSize = points
        .where((point) => point.size != null)
        .map((point) => point.size!)
        .fold<double>(0, math.max);
    final layouts = <_TernaryPointLayout>[];
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final share = SimpleTernaryChart.shareFor(point);
      final center = Offset(
        aVertex.dx * share.a + bVertex.dx * share.b + cVertex.dx * share.c,
        aVertex.dy * share.a + bVertex.dy * share.b + cVertex.dy * share.c,
      );
      final radius =
          pointRadius ??
          (point.size == null || maxSize <= 0
              ? (minPointRadius + maxPointRadius) / 2
              : minPointRadius +
                    (maxPointRadius - minPointRadius) *
                        (point.size! / maxSize).clamp(0.0, 1.0).toDouble());
      final color =
          point.color ??
          (point.group == null || point.group!.isEmpty
              ? pointColor
              : groupColors[point.group!] ?? pointColor);
      layouts.add(
        _TernaryPointLayout(
          point: point,
          index: i,
          share: share,
          center: center,
          radius: radius,
          color: color,
        ),
      );
    }
    return _TernaryGeometry(
      plotRect: plotRect,
      aVertex: aVertex,
      bVertex: bVertex,
      cVertex: cVertex,
      center: center,
      points: layouts,
      groupColors: groupColors,
    );
  }

  static Map<String, Color> _resolveGroupColors(
    List<SimpleTernaryPoint> points,
    List<Color> palette,
  ) {
    if (palette.isEmpty) {
      return {};
    }
    final result = <String, Color>{};
    for (final point in points) {
      final group = point.group;
      if (group == null || group.isEmpty || result.containsKey(group)) {
        continue;
      }
      result[group] = palette[result.length % palette.length];
    }
    return result;
  }
}

class _TernaryPointLayout {
  final SimpleTernaryPoint point;
  final int index;
  final SimpleTernaryShare share;
  final Offset center;
  final double radius;
  final Color color;

  const _TernaryPointLayout({
    required this.point,
    required this.index,
    required this.share,
    required this.center,
    required this.radius,
    required this.color,
  });
}

class _SimpleTernaryVisuals {
  final Color pointColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color> palette;
  final double minPointRadius;
  final double maxPointRadius;

  const _SimpleTernaryVisuals({
    required this.pointColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
    required this.minPointRadius,
    required this.maxPointRadius,
  });

  factory _SimpleTernaryVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleTernaryVisuals(
          pointColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          activeColor: colorScheme.primary,
          palette: const [
            Color(0xFF2563EB),
            Color(0xFF10B981),
            Color(0xFFF59E0B),
            Color(0xFFEF4444),
            Color(0xFF8B5CF6),
          ],
          minPointRadius: 6,
          maxPointRadius: 16,
        );
      case SimpleBarChartStyle.professional:
        return const _SimpleTernaryVisuals(
          pointColor: Color(0xFF2563EB),
          gridColor: Color(0xFFE2E8F0),
          axisColor: Color(0xFF64748B),
          activeColor: Color(0xFF0F172A),
          palette: [
            Color(0xFF1D4ED8),
            Color(0xFF0F766E),
            Color(0xFF7C2D12),
            Color(0xFF6D28D9),
            Color(0xFFBE123C),
          ],
          minPointRadius: 6,
          maxPointRadius: 14,
        );
      case SimpleBarChartStyle.education:
        return const _SimpleTernaryVisuals(
          pointColor: Color(0xFF2563EB),
          gridColor: Color(0xFFE2E8F0),
          axisColor: Color(0xFF94A3B8),
          activeColor: Color(0xFF2563EB),
          palette: [
            Color(0xFF2563EB),
            Color(0xFFF97316),
            Color(0xFF16A34A),
            Color(0xFFDB2777),
            Color(0xFF9333EA),
          ],
          minPointRadius: 7,
          maxPointRadius: 17,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleTernaryVisuals(
          pointColor: const Color(0xFF14B8A6),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
          axisColor: colorScheme.outline.withValues(alpha: 0.58),
          activeColor: const Color(0xFF8B5CF6),
          palette: const [
            Color(0xFF14B8A6),
            Color(0xFFF43F5E),
            Color(0xFF8B5CF6),
            Color(0xFFF59E0B),
            Color(0xFF06B6D4),
          ],
          minPointRadius: 7,
          maxPointRadius: 18,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleTernaryVisuals(
          pointColor: colorScheme.secondary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.26),
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
          activeColor: colorScheme.secondary,
          palette: const [
            Color(0xFF0F766E),
            Color(0xFF7C3AED),
            Color(0xFF2563EB),
            Color(0xFFE11D48),
            Color(0xFFCA8A04),
          ],
          minPointRadius: 6,
          maxPointRadius: 16,
        );
    }
  }
}

class _DefaultTernaryTooltip extends StatelessWidget {
  final SimpleTernaryPoint point;
  final String aAxisLabel;
  final String bAxisLabel;
  final String cAxisLabel;
  final String formattedA;
  final String formattedB;
  final String formattedC;
  final String? formattedSize;

  const _DefaultTernaryTooltip({
    required this.point,
    required this.aAxisLabel,
    required this.bAxisLabel,
    required this.cAxisLabel,
    required this.formattedA,
    required this.formattedB,
    required this.formattedC,
    required this.formattedSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 188,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style:
              theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onInverseSurface,
                fontWeight: FontWeight.w600,
              ) ??
              TextStyle(
                color: colorScheme.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                point.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (point.group != null && point.group!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  point.group!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 7),
              _TooltipRow(label: aAxisLabel, value: formattedA),
              _TooltipRow(label: bAxisLabel, value: formattedB),
              _TooltipRow(label: cAxisLabel, value: formattedC),
              if (formattedSize != null)
                _TooltipRow(label: 'Size', value: formattedSize!),
            ],
          ),
        ),
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _TooltipRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
