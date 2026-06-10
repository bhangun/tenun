import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleVoronoiValueFormatter = String Function(double value);
typedef SimpleVoronoiSiteTapCallback =
    void Function(SimpleVoronoiSite site, int index);
typedef SimpleVoronoiTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleVoronoiSite site,
      int index,
      String formattedX,
      String formattedY,
      String? formattedValue,
    );

class SimpleVoronoiSite {
  final String label;
  final double x;
  final double y;
  final double? value;
  final String? group;
  final Color? color;

  const SimpleVoronoiSite({
    required this.label,
    required this.x,
    required this.y,
    this.value,
    this.group,
    this.color,
  });
}

/// A simple Voronoi diagram for nearest-site territories, clusters, coverage,
/// service zones, and proximity maps across business and learning dashboards.
class SimpleVoronoiChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(52, 18, 24, 42);

  final List<SimpleVoronoiSite> sites;
  final SimpleBarChartStyle style;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final double height;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color? regionColor;
  final Color? pointColor;
  final Color? boundaryColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final List<Color>? palette;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showRegions;
  final bool showBoundaries;
  final bool showSites;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final bool showAxisLabels;
  final int gridLineCount;
  final double pointRadius;
  final double regionOpacity;
  final double inactiveRegionOpacity;
  final SimpleVoronoiValueFormatter? xValueFormatter;
  final SimpleVoronoiValueFormatter? yValueFormatter;
  final SimpleVoronoiValueFormatter? valueFormatter;
  final SimpleVoronoiSiteTapCallback? onSiteTap;
  final SimpleVoronoiTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleVoronoiChart({
    super.key,
    required this.sites,
    this.style = SimpleBarChartStyle.elegant,
    this.minX,
    this.maxX,
    this.minY,
    this.maxY,
    this.height = 260,
    this.padding = _defaultPadding,
    this.xAxisLabel,
    this.yAxisLabel,
    this.regionColor,
    this.pointColor,
    this.boundaryColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.palette,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showRegions = true,
    this.showBoundaries = true,
    this.showSites = true,
    this.showLabels = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveCell = true,
    this.showAxisLabels = true,
    this.gridLineCount = 4,
    this.pointRadius = 4.5,
    this.regionOpacity = 0.26,
    this.inactiveRegionOpacity = 0.1,
    this.xValueFormatter,
    this.yValueFormatter,
    this.valueFormatter,
    this.onSiteTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(pointRadius >= 0),
       assert(regionOpacity >= 0 && regionOpacity <= 1),
       assert(inactiveRegionOpacity >= 0 && inactiveRegionOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleVoronoiVisuals.resolve(style, colorScheme);
    final visibleSites = sites
        .where(
          (site) =>
              site.x.isFinite &&
              site.y.isFinite &&
              (site.value == null || site.value!.isFinite),
        )
        .toList();
    final xFormatter = xValueFormatter ?? _defaultValueFormatter;
    final yFormatter = yValueFormatter ?? _defaultValueFormatter;
    final resolvedValueFormatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleSites.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Voronoi chart, no data.',
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
            visibleSites,
            xFormatter,
            yFormatter,
            resolvedValueFormatter,
            xAxisLabel,
            yAxisLabel,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleVoronoiView(
            width: width,
            height: chartHeight,
            sites: visibleSites,
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            padding: padding,
            xAxisLabel: xAxisLabel,
            yAxisLabel: yAxisLabel,
            regionColor: regionColor ?? visuals.regionColor,
            pointColor: pointColor ?? visuals.pointColor,
            boundaryColor: boundaryColor ?? visuals.boundaryColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            palette: palette ?? visuals.palette,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showRegions: showRegions,
            showBoundaries: showBoundaries,
            showSites: showSites,
            showLabels: showLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveCell: showActiveCell,
            showAxisLabels: showAxisLabels,
            gridLineCount: gridLineCount,
            pointRadius: pointRadius,
            regionOpacity: regionOpacity,
            inactiveRegionOpacity: inactiveRegionOpacity,
            xValueFormatter: xFormatter,
            yValueFormatter: yFormatter,
            valueFormatter: resolvedValueFormatter,
            onSiteTap: onSiteTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleVoronoiSite> sites,
    SimpleVoronoiValueFormatter xFormatter,
    SimpleVoronoiValueFormatter yFormatter,
    SimpleVoronoiValueFormatter valueFormatter,
    String? xAxisLabel,
    String? yAxisLabel,
  ) {
    final xLabel = xAxisLabel ?? 'x';
    final yLabel = yAxisLabel ?? 'y';
    final sample = sites
        .take(6)
        .map((site) {
          final value = site.value == null
              ? ''
              : ', value ${valueFormatter(site.value!)}';
          return '${site.label} $xLabel ${xFormatter(site.x)}, '
              '$yLabel ${yFormatter(site.y)}$value';
        })
        .join(', ');
    final suffix = sites.length > 6 ? ', and ${sites.length - 6} more' : '';
    return 'Voronoi chart, ${sites.length} sites. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleVoronoiView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleVoronoiSite> sites;
  final double? minX;
  final double? maxX;
  final double? minY;
  final double? maxY;
  final EdgeInsets padding;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color regionColor;
  final Color pointColor;
  final Color boundaryColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color> palette;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showRegions;
  final bool showBoundaries;
  final bool showSites;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final bool showAxisLabels;
  final int gridLineCount;
  final double pointRadius;
  final double regionOpacity;
  final double inactiveRegionOpacity;
  final SimpleVoronoiValueFormatter xValueFormatter;
  final SimpleVoronoiValueFormatter yValueFormatter;
  final SimpleVoronoiValueFormatter valueFormatter;
  final SimpleVoronoiSiteTapCallback? onSiteTap;
  final SimpleVoronoiTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleVoronoiView({
    required this.width,
    required this.height,
    required this.sites,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.padding,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.regionColor,
    required this.pointColor,
    required this.boundaryColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showRegions,
    required this.showBoundaries,
    required this.showSites,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveCell,
    required this.showAxisLabels,
    required this.gridLineCount,
    required this.pointRadius,
    required this.regionOpacity,
    required this.inactiveRegionOpacity,
    required this.xValueFormatter,
    required this.yValueFormatter,
    required this.valueFormatter,
    required this.onSiteTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleVoronoiView> createState() => _SimpleVoronoiViewState();
}

class _SimpleVoronoiViewState extends State<_SimpleVoronoiView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  _VoronoiCellLayout? _activeCell;
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
  void didUpdateWidget(covariant _SimpleVoronoiView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sites != widget.sites ||
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
          final geometry = _VoronoiGeometry.resolve(
            size: Size(widget.width, widget.height),
            sites: widget.sites,
            minX: widget.minX,
            maxX: widget.maxX,
            minY: widget.minY,
            maxY: widget.maxY,
            padding: widget.padding,
            palette: widget.palette,
            regionColor: widget.regionColor,
            pointColor: widget.pointColor,
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
                      final cell = _hitTest(details.localPosition, geometry);
                      _setActive(cell);
                      _pointer = details.localPosition;
                      if (cell != null) {
                        widget.onSiteTap?.call(cell.site, cell.index);
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SimpleVoronoiPainter(
                            geometry: geometry,
                            xAxisLabel: widget.xAxisLabel,
                            yAxisLabel: widget.yAxisLabel,
                            boundaryColor: widget.boundaryColor,
                            gridColor: widget.gridColor,
                            axisColor: widget.axisColor,
                            activeColor: widget.activeColor,
                            labelStyle: widget.labelStyle,
                            valueStyle: widget.valueStyle,
                            showGrid: widget.showGrid,
                            showRegions: widget.showRegions,
                            showBoundaries: widget.showBoundaries,
                            showSites: widget.showSites,
                            showLabels: widget.showLabels,
                            showValues: widget.showValues,
                            showLegend: widget.showLegend,
                            showActiveCell: widget.showActiveCell,
                            showAxisLabels: widget.showAxisLabels,
                            gridLineCount: widget.gridLineCount,
                            pointRadius: widget.pointRadius,
                            regionOpacity: widget.regionOpacity,
                            inactiveRegionOpacity: widget.inactiveRegionOpacity,
                            valueFormatter: widget.valueFormatter,
                            activeCell: _activeCell,
                            progress: _animation.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeCell != null)
                _buildTooltip(context, Size(widget.width, widget.height)),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_VoronoiCellLayout? cell) {
    if (_activeCell?.index == cell?.index) {
      return;
    }
    setState(() => _activeCell = cell);
  }

  _VoronoiCellLayout? _hitTest(Offset position, _VoronoiGeometry geometry) {
    for (var i = geometry.cells.length - 1; i >= 0; i--) {
      final cell = geometry.cells[i];
      if (_containsPoint(cell.polygon, position) ||
          (position - cell.center).distance <= widget.pointRadius + 7) {
        return cell;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final cell = _activeCell!;
    final formattedValue = cell.site.value == null
        ? null
        : widget.valueFormatter(cell.site.value!);
    final child =
        widget.tooltipBuilder?.call(
          context,
          cell.site,
          cell.index,
          widget.xValueFormatter(cell.site.x),
          widget.yValueFormatter(cell.site.y),
          formattedValue,
        ) ??
        _DefaultVoronoiTooltip(
          site: cell.site,
          xAxisLabel: widget.xAxisLabel ?? 'x',
          yAxisLabel: widget.yAxisLabel ?? 'y',
          formattedX: widget.xValueFormatter(cell.site.x),
          formattedY: widget.yValueFormatter(cell.site.y),
          formattedValue: formattedValue,
        );
    const tooltipWidth = 176.0;
    const tooltipHeight = 118.0;
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

  static bool _containsPoint(List<Offset> polygon, Offset point) {
    if (polygon.length < 3) {
      return false;
    }
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final crosses =
          (a.dy > point.dy) != (b.dy > point.dy) &&
          point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx;
      if (crosses) {
        inside = !inside;
      }
    }
    return inside;
  }
}

class _SimpleVoronoiPainter extends CustomPainter {
  final _VoronoiGeometry geometry;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final Color boundaryColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showRegions;
  final bool showBoundaries;
  final bool showSites;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActiveCell;
  final bool showAxisLabels;
  final int gridLineCount;
  final double pointRadius;
  final double regionOpacity;
  final double inactiveRegionOpacity;
  final SimpleVoronoiValueFormatter valueFormatter;
  final _VoronoiCellLayout? activeCell;
  final double progress;

  const _SimpleVoronoiPainter({
    required this.geometry,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.boundaryColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showRegions,
    required this.showBoundaries,
    required this.showSites,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActiveCell,
    required this.showAxisLabels,
    required this.gridLineCount,
    required this.pointRadius,
    required this.regionOpacity,
    required this.inactiveRegionOpacity,
    required this.valueFormatter,
    required this.activeCell,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      _drawGrid(canvas);
    }
    if (showRegions) {
      _drawRegions(canvas);
    }
    if (showBoundaries) {
      _drawBoundaries(canvas);
    }
    _drawAxes(canvas);
    if (showSites) {
      _drawSites(canvas);
    }
    if (showLabels) {
      _drawLabels(canvas);
    }
    if (showLegend) {
      _drawLegend(canvas);
    }
  }

  void _drawGrid(Canvas canvas) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.9 * progress)
      ..strokeWidth = 1;
    for (var i = 0; i <= gridLineCount; i++) {
      final t = i / gridLineCount;
      final x = geometry.plotRect.left + geometry.plotRect.width * t;
      final y = geometry.plotRect.top + geometry.plotRect.height * t;
      canvas.drawLine(
        Offset(x, geometry.plotRect.top),
        Offset(x, geometry.plotRect.bottom),
        paint,
      );
      canvas.drawLine(
        Offset(geometry.plotRect.left, y),
        Offset(geometry.plotRect.right, y),
        paint,
      );
    }
  }

  void _drawRegions(Canvas canvas) {
    for (final cell in geometry.cells) {
      if (cell.polygon.length < 3) {
        continue;
      }
      final active = activeCell?.index == cell.index;
      final opacity = activeCell == null
          ? regionOpacity
          : active
          ? math.min(1.0, regionOpacity + 0.16)
          : inactiveRegionOpacity;
      canvas.drawPath(
        _pathFor(cell.polygon),
        Paint()
          ..color = cell.regionColor.withValues(alpha: opacity * progress)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      if (showActiveCell && active) {
        canvas.drawPath(
          _pathFor(cell.polygon),
          Paint()
            ..color = activeColor.withValues(alpha: 0.16 * progress)
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
      }
    }
  }

  void _drawBoundaries(Canvas canvas) {
    for (final cell in geometry.cells) {
      if (cell.polygon.length < 3) {
        continue;
      }
      final active = activeCell?.index == cell.index;
      canvas.drawPath(
        _pathFor(cell.polygon),
        Paint()
          ..color = (active ? activeColor : boundaryColor).withValues(
            alpha: (active ? 0.88 : 0.42) * progress,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 1.8 : 1.0
          ..isAntiAlias = true,
      );
    }
  }

  void _drawAxes(Canvas canvas) {
    canvas.drawRect(
      geometry.plotRect,
      Paint()
        ..color = axisColor.withValues(alpha: 0.74 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    if (!showAxisLabels) {
      return;
    }
    if (xAxisLabel != null && xAxisLabel!.isNotEmpty) {
      _drawText(
        canvas,
        xAxisLabel!,
        Offset(geometry.plotRect.center.dx - 56, geometry.plotRect.bottom + 22),
        labelStyle,
        maxWidth: 112,
        align: TextAlign.center,
      );
    }
    if (yAxisLabel != null && yAxisLabel!.isNotEmpty) {
      _drawText(
        canvas,
        yAxisLabel!,
        Offset(geometry.plotRect.left - 46, geometry.plotRect.top - 2),
        labelStyle,
        maxWidth: 88,
      );
    }
  }

  void _drawSites(Canvas canvas) {
    for (final cell in geometry.cells) {
      final active = activeCell?.index == cell.index;
      final opacity = activeCell == null || active ? 1.0 : 0.42;
      if (showActiveCell && active) {
        canvas.drawCircle(
          cell.center,
          pointRadius + 7,
          Paint()
            ..color = activeColor.withValues(alpha: 0.18 * progress)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(
        cell.center,
        pointRadius + (active ? 1.5 : 0),
        Paint()
          ..color = cell.pointColor.withValues(alpha: opacity * progress)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        cell.center,
        pointRadius + (active ? 1.5 : 0),
        Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.82 * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2 : 1.1,
      );
    }
  }

  void _drawLabels(Canvas canvas) {
    for (final cell in geometry.cells) {
      final active = activeCell?.index == cell.index;
      final opacity = activeCell == null || active ? 1.0 : 0.38;
      final text = showValues && cell.site.value != null
          ? '${cell.site.label} ${valueFormatter(cell.site.value!)}'
          : cell.site.label;
      _drawText(
        canvas,
        text,
        Offset(cell.center.dx + 7, cell.center.dy - 7),
        valueStyle.copyWith(
          color: (valueStyle.color ?? Colors.black).withValues(
            alpha: opacity * progress,
          ),
        ),
        maxWidth: 92,
      );
    }
  }

  void _drawLegend(Canvas canvas) {
    if (geometry.groupColors.isEmpty) {
      return;
    }
    final entries = geometry.groupColors.entries.take(4).toList();
    var dx = geometry.plotRect.left;
    final y = geometry.plotRect.bottom + 13;
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
        maxWidth: 74,
      );
      painter.paint(canvas, Offset(dx + 13, y - 2));
      dx += math.min(96, painter.width + 28);
      if (dx > geometry.plotRect.right - 72) {
        break;
      }
    }
  }

  Path _pathFor(List<Offset> polygon) {
    final path = Path()..moveTo(polygon.first.dx, polygon.first.dy);
    for (final point in polygon.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
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
  bool shouldRepaint(covariant _SimpleVoronoiPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.xAxisLabel != xAxisLabel ||
        oldDelegate.yAxisLabel != yAxisLabel ||
        oldDelegate.boundaryColor != boundaryColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showRegions != showRegions ||
        oldDelegate.showBoundaries != showBoundaries ||
        oldDelegate.showSites != showSites ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveCell != showActiveCell ||
        oldDelegate.showAxisLabels != showAxisLabels ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.pointRadius != pointRadius ||
        oldDelegate.regionOpacity != regionOpacity ||
        oldDelegate.inactiveRegionOpacity != inactiveRegionOpacity ||
        oldDelegate.activeCell?.index != activeCell?.index ||
        oldDelegate.progress != progress;
  }
}

class _VoronoiGeometry {
  final Rect plotRect;
  final _ChartScale scale;
  final List<_VoronoiCellLayout> cells;
  final Map<String, Color> groupColors;

  const _VoronoiGeometry({
    required this.plotRect,
    required this.scale,
    required this.cells,
    required this.groupColors,
  });

  factory _VoronoiGeometry.resolve({
    required Size size,
    required List<SimpleVoronoiSite> sites,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
    required EdgeInsets padding,
    required List<Color> palette,
    required Color regionColor,
    required Color pointColor,
    required bool showLegend,
  }) {
    final legendHeight = showLegend ? 26.0 : 0.0;
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal),
      math.max(1, size.height - padding.vertical - legendHeight),
    );
    final scale = _ChartScale.resolve(
      sites: sites,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
    final groupColors = _resolveGroupColors(sites, palette);
    final positioned = <_PositionedSite>[];
    for (var i = 0; i < sites.length; i++) {
      final site = sites[i];
      final groupColor = site.group == null || site.group!.isEmpty
          ? null
          : groupColors[site.group!];
      positioned.add(
        _PositionedSite(
          site: site,
          index: i,
          center: scale.toOffset(site.x, site.y, plotRect),
          regionColor: site.color ?? groupColor ?? regionColor,
          pointColor: site.color ?? groupColor ?? pointColor,
        ),
      );
    }
    final cells = positioned
        .map(
          (site) => _VoronoiCellLayout(
            site: site.site,
            index: site.index,
            center: site.center,
            polygon: _cellPolygon(site, positioned, plotRect),
            regionColor: site.regionColor,
            pointColor: site.pointColor,
          ),
        )
        .toList();
    return _VoronoiGeometry(
      plotRect: plotRect,
      scale: scale,
      cells: cells,
      groupColors: groupColors,
    );
  }

  static List<Offset> _cellPolygon(
    _PositionedSite site,
    List<_PositionedSite> sites,
    Rect plotRect,
  ) {
    var polygon = [
      plotRect.topLeft,
      plotRect.topRight,
      plotRect.bottomRight,
      plotRect.bottomLeft,
    ];
    for (final other in sites) {
      if (other.index == site.index) {
        continue;
      }
      polygon = _clipToCloserHalfPlane(polygon, site.center, other.center);
      if (polygon.length < 3) {
        return const [];
      }
    }
    return polygon;
  }

  static List<Offset> _clipToCloserHalfPlane(
    List<Offset> polygon,
    Offset site,
    Offset other,
  ) {
    if ((site - other).distanceSquared <= 0.000001 || polygon.isEmpty) {
      return polygon;
    }
    final output = <Offset>[];
    var previous = polygon.last;
    var previousInside = _inside(previous, site, other);
    for (final current in polygon) {
      final currentInside = _inside(current, site, other);
      if (currentInside) {
        if (!previousInside) {
          output.add(_intersection(previous, current, site, other));
        }
        output.add(current);
      } else if (previousInside) {
        output.add(_intersection(previous, current, site, other));
      }
      previous = current;
      previousInside = currentInside;
    }
    return output;
  }

  static bool _inside(Offset point, Offset site, Offset other) {
    return _distanceDelta(point, site, other) >= -0.001;
  }

  static Offset _intersection(
    Offset start,
    Offset end,
    Offset site,
    Offset other,
  ) {
    final startDelta = _distanceDelta(start, site, other);
    final endDelta = _distanceDelta(end, site, other);
    final denominator = startDelta - endDelta;
    if (denominator.abs() < 0.000001) {
      return end;
    }
    final t = (startDelta / denominator).clamp(0.0, 1.0).toDouble();
    return Offset.lerp(start, end, t)!;
  }

  static double _distanceDelta(Offset point, Offset site, Offset other) {
    final otherDistance = (point - other).distanceSquared;
    final siteDistance = (point - site).distanceSquared;
    return otherDistance - siteDistance;
  }

  static Map<String, Color> _resolveGroupColors(
    List<SimpleVoronoiSite> sites,
    List<Color> palette,
  ) {
    if (palette.isEmpty) {
      return {};
    }
    final result = <String, Color>{};
    for (final site in sites) {
      final group = site.group;
      if (group == null || group.isEmpty || result.containsKey(group)) {
        continue;
      }
      result[group] = palette[result.length % palette.length];
    }
    return result;
  }
}

class _ChartScale {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _ChartScale({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  factory _ChartScale.resolve({
    required List<SimpleVoronoiSite> sites,
    required double? minX,
    required double? maxX,
    required double? minY,
    required double? maxY,
  }) {
    final rawMinX = minX ?? sites.map((site) => site.x).reduce(math.min);
    final rawMaxX = maxX ?? sites.map((site) => site.x).reduce(math.max);
    final rawMinY = minY ?? sites.map((site) => site.y).reduce(math.min);
    final rawMaxY = maxY ?? sites.map((site) => site.y).reduce(math.max);
    final xSpan = rawMaxX - rawMinX;
    final ySpan = rawMaxY - rawMinY;
    return _ChartScale(
      minX: xSpan.abs() < 0.000001 ? rawMinX - 1 : rawMinX,
      maxX: xSpan.abs() < 0.000001 ? rawMaxX + 1 : rawMaxX,
      minY: ySpan.abs() < 0.000001 ? rawMinY - 1 : rawMinY,
      maxY: ySpan.abs() < 0.000001 ? rawMaxY + 1 : rawMaxY,
    );
  }

  Offset toOffset(double x, double y, Rect plotRect) {
    final xSpan = maxX - minX;
    final ySpan = maxY - minY;
    final xRatio = ((x - minX) / xSpan).clamp(0.0, 1.0).toDouble();
    final yRatio = ((y - minY) / ySpan).clamp(0.0, 1.0).toDouble();
    return Offset(
      plotRect.left + plotRect.width * xRatio,
      plotRect.bottom - plotRect.height * yRatio,
    );
  }
}

class _PositionedSite {
  final SimpleVoronoiSite site;
  final int index;
  final Offset center;
  final Color regionColor;
  final Color pointColor;

  const _PositionedSite({
    required this.site,
    required this.index,
    required this.center,
    required this.regionColor,
    required this.pointColor,
  });
}

class _VoronoiCellLayout {
  final SimpleVoronoiSite site;
  final int index;
  final Offset center;
  final List<Offset> polygon;
  final Color regionColor;
  final Color pointColor;

  const _VoronoiCellLayout({
    required this.site,
    required this.index,
    required this.center,
    required this.polygon,
    required this.regionColor,
    required this.pointColor,
  });
}

class _SimpleVoronoiVisuals {
  final Color regionColor;
  final Color pointColor;
  final Color boundaryColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final List<Color> palette;

  const _SimpleVoronoiVisuals({
    required this.regionColor,
    required this.pointColor,
    required this.boundaryColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.palette,
  });

  factory _SimpleVoronoiVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleVoronoiVisuals(
          regionColor: colorScheme.primary,
          pointColor: colorScheme.primary,
          boundaryColor: colorScheme.outline.withValues(alpha: 0.72),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
          axisColor: colorScheme.outline.withValues(alpha: 0.64),
          activeColor: colorScheme.primary,
          palette: const [
            Color(0xFF2563EB),
            Color(0xFF10B981),
            Color(0xFFF59E0B),
            Color(0xFFEF4444),
            Color(0xFF8B5CF6),
          ],
        );
      case SimpleBarChartStyle.professional:
        return const _SimpleVoronoiVisuals(
          regionColor: Color(0xFF2563EB),
          pointColor: Color(0xFF1D4ED8),
          boundaryColor: Color(0xFF94A3B8),
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
        );
      case SimpleBarChartStyle.education:
        return const _SimpleVoronoiVisuals(
          regionColor: Color(0xFF2563EB),
          pointColor: Color(0xFF2563EB),
          boundaryColor: Color(0xFF94A3B8),
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
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleVoronoiVisuals(
          regionColor: const Color(0xFF14B8A6),
          pointColor: const Color(0xFF14B8A6),
          boundaryColor: colorScheme.outline.withValues(alpha: 0.58),
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
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleVoronoiVisuals(
          regionColor: colorScheme.secondary,
          pointColor: colorScheme.secondary,
          boundaryColor: colorScheme.outline.withValues(alpha: 0.54),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
          activeColor: colorScheme.secondary,
          palette: const [
            Color(0xFF0F766E),
            Color(0xFF7C3AED),
            Color(0xFF2563EB),
            Color(0xFFE11D48),
            Color(0xFFCA8A04),
          ],
        );
    }
  }
}

class _DefaultVoronoiTooltip extends StatelessWidget {
  final SimpleVoronoiSite site;
  final String xAxisLabel;
  final String yAxisLabel;
  final String formattedX;
  final String formattedY;
  final String? formattedValue;

  const _DefaultVoronoiTooltip({
    required this.site,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.formattedX,
    required this.formattedY,
    required this.formattedValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 176,
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
                site.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (site.group != null && site.group!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(site.group!, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 7),
              _TooltipRow(label: xAxisLabel, value: formattedX),
              _TooltipRow(label: yAxisLabel, value: formattedY),
              if (formattedValue != null)
                _TooltipRow(label: 'Value', value: formattedValue!),
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
