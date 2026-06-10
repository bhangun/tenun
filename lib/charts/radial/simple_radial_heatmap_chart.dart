import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleRadialHeatmapValueFormatter = String Function(double value);
typedef SimpleRadialHeatmapCellTapCallback =
    void Function(
      SimpleRadialHeatmapCell cell,
      int ringIndex,
      int segmentIndex,
    );
typedef SimpleRadialHeatmapTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleRadialHeatmapCell cell,
      int ringIndex,
      int segmentIndex,
      String formattedValue,
    );

class SimpleRadialHeatmapCell {
  final String ringLabel;
  final String segmentLabel;
  final double value;
  final Color? color;
  final String? label;

  const SimpleRadialHeatmapCell({
    required this.ringLabel,
    required this.segmentLabel,
    required this.value,
    this.color,
    this.label,
  });
}

/// A circular heatmap for cyclical intensity, time-of-day bands, maturity
/// rings, curriculum coverage, and other ring-by-segment comparisons.
class SimpleRadialHeatmapChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 14, 18, 28);

  final List<String> ringLabels;
  final List<String> segmentLabels;
  final List<SimpleRadialHeatmapCell> cells;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? lowColor;
  final Color? highColor;
  final Color? emptyColor;
  final Color? gridColor;
  final Color? activeColor;
  final Color? centerColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showRingLabels;
  final bool showSegmentLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final bool showCenterHole;
  final bool showEmptyCells;
  final double innerRadiusFactor;
  final double ringGap;
  final double segmentGap;
  final double startAngle;
  final SimpleRadialHeatmapValueFormatter? valueFormatter;
  final SimpleRadialHeatmapCellTapCallback? onCellTap;
  final SimpleRadialHeatmapTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleRadialHeatmapChart({
    super.key,
    this.ringLabels = const [],
    this.segmentLabels = const [],
    required this.cells,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 250,
    this.padding = _defaultPadding,
    this.lowColor,
    this.highColor,
    this.emptyColor,
    this.gridColor,
    this.activeColor,
    this.centerColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showRingLabels = true,
    this.showSegmentLabels = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveCell = true,
    this.showCenterHole = true,
    this.showEmptyCells = true,
    this.innerRadiusFactor = 0.22,
    this.ringGap = 2.5,
    this.segmentGap = 0.018,
    this.startAngle = -math.pi / 2,
    this.valueFormatter,
    this.onCellTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(innerRadiusFactor >= 0 && innerRadiusFactor < 0.8),
       assert(ringGap >= 0),
       assert(segmentGap >= 0 && segmentGap <= 0.2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleRadialHeatmapVisuals.resolve(style, colorScheme);
    final visibleCells = cells
        .where(
          (item) =>
              item.ringLabel.trim().isNotEmpty &&
              item.segmentLabel.trim().isNotEmpty &&
              item.value.isFinite,
        )
        .toList();
    final grid = _RadialHeatmapGrid.from(
      ringLabels: ringLabels,
      segmentLabels: segmentLabels,
      cells: visibleCells,
      minValue: minValue,
      maxValue: maxValue,
    );
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 380.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (grid.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Radial heatmap chart, no data.',
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
          semanticLabel: _defaultSemanticLabel(grid, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleRadialHeatmapChartView(
            width: width,
            height: chartHeight,
            grid: grid,
            padding: padding,
            lowColor: lowColor ?? visuals.lowColor,
            highColor: highColor ?? visuals.highColor,
            emptyColor: emptyColor ?? visuals.emptyColor,
            gridColor: gridColor ?? visuals.gridColor,
            activeColor: activeColor,
            centerColor: centerColor ?? colorScheme.surface,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showRingLabels: showRingLabels,
            showSegmentLabels: showSegmentLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveCell: showActiveCell,
            showCenterHole: showCenterHole,
            showEmptyCells: showEmptyCells,
            innerRadiusFactor: innerRadiusFactor,
            ringGap: ringGap,
            segmentGap: segmentGap,
            startAngle: startAngle,
            valueFormatter: formatter,
            onCellTap: onCellTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(
    _RadialHeatmapGrid grid,
    SimpleRadialHeatmapValueFormatter formatter,
  ) {
    final summaries = grid.cells
        .expand((ring) => ring)
        .whereType<SimpleRadialHeatmapCell>()
        .take(6)
        .map(
          (item) =>
              '${item.ringLabel} ${item.segmentLabel} ${formatter(item.value)}',
        )
        .join(', ');
    final totalCells = grid.cells
        .expand((ring) => ring)
        .whereType<SimpleRadialHeatmapCell>()
        .length;
    final remaining = totalCells - math.min(totalCells, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    return 'Radial heatmap chart, ${grid.ringLabels.length} rings and '
        '${grid.segmentLabels.length} segments. $summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleRadialHeatmapChartView extends StatefulWidget {
  final double width;
  final double height;
  final _RadialHeatmapGrid grid;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;
  final Color? activeColor;
  final Color centerColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showRingLabels;
  final bool showSegmentLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveCell;
  final bool showCenterHole;
  final bool showEmptyCells;
  final double innerRadiusFactor;
  final double ringGap;
  final double segmentGap;
  final double startAngle;
  final SimpleRadialHeatmapValueFormatter valueFormatter;
  final SimpleRadialHeatmapCellTapCallback? onCellTap;
  final SimpleRadialHeatmapTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleRadialHeatmapChartView({
    required this.width,
    required this.height,
    required this.grid,
    required this.padding,
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.gridColor,
    required this.activeColor,
    required this.centerColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showRingLabels,
    required this.showSegmentLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveCell,
    required this.showCenterHole,
    required this.showEmptyCells,
    required this.innerRadiusFactor,
    required this.ringGap,
    required this.segmentGap,
    required this.startAngle,
    required this.valueFormatter,
    required this.onCellTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleRadialHeatmapChartView> createState() =>
      _SimpleRadialHeatmapChartViewState();
}

class _SimpleRadialHeatmapChartViewState
    extends State<_SimpleRadialHeatmapChartView> {
  int? _activeRing;
  int? _activeSegment;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveCell || widget.onCellTap != null;

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
                painter: _SimpleRadialHeatmapPainter(
                  grid: widget.grid,
                  padding: widget.padding,
                  lowColor: widget.lowColor,
                  highColor: widget.highColor,
                  emptyColor: widget.emptyColor,
                  gridColor: widget.gridColor,
                  activeColor: widget.activeColor,
                  centerColor: widget.centerColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showRingLabels: widget.showRingLabels,
                  showSegmentLabels: widget.showSegmentLabels,
                  showValues: widget.showValues,
                  showLegend: widget.showLegend,
                  showActiveCell: widget.showActiveCell,
                  showCenterHole: widget.showCenterHole,
                  showEmptyCells: widget.showEmptyCells,
                  innerRadiusFactor: widget.innerRadiusFactor,
                  ringGap: widget.ringGap,
                  segmentGap: widget.segmentGap,
                  startAngle: widget.startAngle,
                  valueFormatter: widget.valueFormatter,
                  activeRing: _activeRing,
                  activeSegment: _activeSegment,
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
                      final cell = widget.grid.cellAt(hit.ring, hit.segment);
                      if (cell == null) return;
                      widget.onCellTap?.call(cell, hit.ring, hit.segment);
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip &&
                  _activeRing != null &&
                  _activeSegment != null)
                _buildTooltip(context, size, _activeRing!, _activeSegment!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_RadialHeatmapHit? hit) {
    if (_activeRing == hit?.ring && _activeSegment == hit?.segment) return;
    setState(() {
      _activeRing = hit?.ring;
      _activeSegment = hit?.segment;
    });
  }

  _RadialHeatmapHit? _hitTest(Offset position, Size size) {
    final layout = _RadialHeatmapLayout.resolve(
      size,
      widget.padding,
      widget.showLegend,
      widget.showRingLabels,
      widget.showSegmentLabels,
    );
    if (layout.outerRadius <= 0) return null;
    final delta = position - layout.center;
    final distance = delta.distance;
    final innerRadius = layout.innerRadius(widget.innerRadiusFactor);
    if (distance < innerRadius || distance > layout.outerRadius + 6) {
      return null;
    }
    final ringStep =
        (layout.outerRadius - innerRadius) / widget.grid.ringLabels.length;
    if (ringStep <= 0) return null;

    final ring = ((distance - innerRadius) / ringStep).floor();
    if (ring < 0 || ring >= widget.grid.ringLabels.length) return null;

    final segmentStep = math.pi * 2 / widget.grid.segmentLabels.length;
    final angle = _normalizeAngle(
      math.atan2(delta.dy, delta.dx) - widget.startAngle,
    );
    final segment = (angle / segmentStep).floor().clamp(
      0,
      widget.grid.segmentLabels.length - 1,
    );

    if (widget.grid.cellAt(ring, segment) == null) return null;
    return _RadialHeatmapHit(ring, segment);
  }

  Widget _buildTooltip(BuildContext context, Size size, int ring, int segment) {
    final cell = widget.grid.cellAt(ring, segment);
    if (cell == null) return const SizedBox.shrink();
    final formattedValue = widget.valueFormatter(cell.value);
    final anchor = _anchorFor(size, ring, segment);
    const tooltipWidth = 186.0;
    const tooltipHeight = 68.0;
    final left = (anchor.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (anchor.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            cell,
            ring,
            segment,
            formattedValue,
          ) ??
          _DefaultRadialHeatmapTooltip(
            color: _cellColor(cell),
            title: cell.label ?? '${cell.ringLabel} / ${cell.segmentLabel}',
            value: formattedValue,
          ),
    );
  }

  Offset _anchorFor(Size size, int ring, int segment) {
    final layout = _RadialHeatmapLayout.resolve(
      size,
      widget.padding,
      widget.showLegend,
      widget.showRingLabels,
      widget.showSegmentLabels,
    );
    final innerRadius = layout.innerRadius(widget.innerRadiusFactor);
    final ringStep =
        (layout.outerRadius - innerRadius) / widget.grid.ringLabels.length;
    final segmentStep = math.pi * 2 / widget.grid.segmentLabels.length;
    final radius = innerRadius + ringStep * ring + ringStep / 2;
    final angle = widget.startAngle + segmentStep * segment + segmentStep / 2;
    return _polar(layout.center, radius, angle);
  }

  Color _cellColor(SimpleRadialHeatmapCell cell) {
    if (cell.color != null) return cell.color!;
    return Color.lerp(
          widget.lowColor,
          widget.highColor,
          widget.grid.normalize(cell.value),
        ) ??
        widget.highColor;
  }
}

class _SimpleRadialHeatmapPainter extends CustomPainter {
  final _RadialHeatmapGrid grid;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;
  final Color? activeColor;
  final Color centerColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showRingLabels;
  final bool showSegmentLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActiveCell;
  final bool showCenterHole;
  final bool showEmptyCells;
  final double innerRadiusFactor;
  final double ringGap;
  final double segmentGap;
  final double startAngle;
  final SimpleRadialHeatmapValueFormatter valueFormatter;
  final int? activeRing;
  final int? activeSegment;
  final double progress;

  const _SimpleRadialHeatmapPainter({
    required this.grid,
    required this.padding,
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.gridColor,
    required this.activeColor,
    required this.centerColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showRingLabels,
    required this.showSegmentLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActiveCell,
    required this.showCenterHole,
    required this.showEmptyCells,
    required this.innerRadiusFactor,
    required this.ringGap,
    required this.segmentGap,
    required this.startAngle,
    required this.valueFormatter,
    required this.activeRing,
    required this.activeSegment,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _RadialHeatmapLayout.resolve(
      size,
      padding,
      showLegend,
      showRingLabels,
      showSegmentLabels,
    );
    if (layout.outerRadius <= 0 || grid.isEmpty) return;

    _drawCells(canvas, layout);
    if (showGrid) _drawGrid(canvas, layout);
    if (showCenterHole) _drawCenterHole(canvas, layout);
    if (showRingLabels) _drawRingLabels(canvas, layout);
    if (showSegmentLabels) _drawSegmentLabels(canvas, layout);
    if (showLegend) _drawLegend(canvas, layout);
  }

  void _drawCells(Canvas canvas, _RadialHeatmapLayout layout) {
    final ringCount = grid.ringLabels.length;
    final segmentCount = grid.segmentLabels.length;
    final innerRadius = layout.innerRadius(innerRadiusFactor);
    final ringStep = (layout.outerRadius - innerRadius) / ringCount;
    if (ringStep <= 0) return;
    final segmentStep = math.pi * 2 / segmentCount;
    final angularGap = math.min(segmentGap, segmentStep * 0.7);
    final radialGap = math.min(ringGap, ringStep * 0.5);

    for (var ring = 0; ring < ringCount; ring++) {
      final baseInner = innerRadius + ring * ringStep;
      final baseOuter = innerRadius + (ring + 1) * ringStep;
      final cellInner = math.max(0.0, baseInner + radialGap / 2);
      final targetOuter = math.max(cellInner + 0.01, baseOuter - radialGap / 2);
      final cellOuter = cellInner + (targetOuter - cellInner) * progress;
      if (cellOuter <= cellInner) continue;

      for (var segment = 0; segment < segmentCount; segment++) {
        final cell = grid.cellAt(ring, segment);
        if (cell == null && !showEmptyCells) continue;
        final start = startAngle + segment * segmentStep + angularGap / 2;
        final sweep = math.max(0.001, segmentStep - angularGap);
        final color = cell == null ? emptyColor : _cellColor(cell);
        final path = _annularSegmentPath(
          center: layout.center,
          innerRadius: cellInner,
          outerRadius: cellOuter,
          start: start,
          sweep: sweep,
        );
        final active = ring == activeRing && segment == activeSegment;

        if (showActiveCell && active && cell != null) {
          final highlight = _annularSegmentPath(
            center: layout.center,
            innerRadius: math.max(0.0, cellInner - 2),
            outerRadius: math.min(layout.outerRadius + 3, cellOuter + 3),
            start: start - angularGap / 2,
            sweep: math.min(segmentStep, sweep + angularGap),
          );
          canvas.drawPath(
            highlight,
            Paint()
              ..color = (activeColor ?? color).withValues(alpha: 0.16)
              ..style = PaintingStyle.fill,
          );
        }

        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: cell == null ? 0.28 : 0.9)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.36)
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 1.4 : 0.7,
        );

        if (showValues &&
            cell != null &&
            ringStep >= 22 &&
            segmentStep >= 0.4) {
          _drawCellValue(
            canvas,
            cell,
            layout,
            cellInner,
            cellOuter,
            start + sweep / 2,
            color,
          );
        }
      }
    }
  }

  void _drawCellValue(
    Canvas canvas,
    SimpleRadialHeatmapCell cell,
    _RadialHeatmapLayout layout,
    double innerRadius,
    double outerRadius,
    double angle,
    Color color,
  ) {
    final radius = (innerRadius + outerRadius) / 2;
    final anchor = _polar(layout.center, radius, angle);
    final foreground = color.computeLuminance() < 0.42
        ? Colors.white
        : Colors.black.withValues(alpha: 0.78);
    final painter = _textPainter(
      valueFormatter(cell.value),
      valueStyle.copyWith(
        color: foreground,
        fontSize: (valueStyle.fontSize ?? 11) * 0.9,
      ),
      textAlign: TextAlign.center,
    )..layout(maxWidth: 42);
    painter.paint(
      canvas,
      Offset(anchor.dx - painter.width / 2, anchor.dy - painter.height / 2),
    );
  }

  void _drawGrid(Canvas canvas, _RadialHeatmapLayout layout) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final ringCount = grid.ringLabels.length;
    final segmentCount = grid.segmentLabels.length;
    final innerRadius = layout.innerRadius(innerRadiusFactor);
    final ringStep = (layout.outerRadius - innerRadius) / ringCount;
    if (ringStep <= 0) return;

    for (var ring = 0; ring <= ringCount; ring++) {
      canvas.drawCircle(layout.center, innerRadius + ring * ringStep, paint);
    }
    for (var segment = 0; segment < segmentCount; segment++) {
      final angle = startAngle + segment * math.pi * 2 / segmentCount;
      canvas.drawLine(
        _polar(layout.center, innerRadius, angle),
        _polar(layout.center, layout.outerRadius, angle),
        paint,
      );
    }
  }

  void _drawCenterHole(Canvas canvas, _RadialHeatmapLayout layout) {
    final radius = layout.innerRadius(innerRadiusFactor);
    if (radius <= 0.5) return;
    canvas.drawCircle(
      layout.center,
      radius,
      Paint()..color = centerColor.withValues(alpha: 0.96),
    );
    canvas.drawCircle(
      layout.center,
      radius,
      Paint()
        ..color = gridColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawRingLabels(Canvas canvas, _RadialHeatmapLayout layout) {
    if (layout.compact) return;
    final innerRadius = layout.innerRadius(innerRadiusFactor);
    final ringStep =
        (layout.outerRadius - innerRadius) / grid.ringLabels.length;
    if (ringStep <= 0) return;
    final angle = startAngle - 0.2;
    final maxWidth = math.max(42.0, padding.left + 54);

    for (var ring = 0; ring < grid.ringLabels.length; ring++) {
      final radius = innerRadius + ringStep * ring + ringStep / 2;
      final anchor = _polar(layout.center, radius, angle);
      final painter = _textPainter(
        grid.ringLabels[ring],
        labelStyle,
        maxWidth: maxWidth,
        textAlign: TextAlign.right,
      )..layout(maxWidth: maxWidth);
      final x = _safeClamp(
        anchor.dx - painter.width - 6,
        padding.left,
        layout.chartRight - painter.width,
      );
      final y = _safeClamp(
        anchor.dy - painter.height / 2,
        padding.top,
        layout.bottom - painter.height,
      );
      painter.paint(canvas, Offset(x, y));
    }
  }

  void _drawSegmentLabels(Canvas canvas, _RadialHeatmapLayout layout) {
    if (layout.compact) return;
    final step = math.pi * 2 / grid.segmentLabels.length;
    final maxLabelCount = math.max(1, layout.outerRadius / 16).floor();
    final labelEvery = math.max(
      1,
      (grid.segmentLabels.length / maxLabelCount).ceil(),
    );
    for (var segment = 0; segment < grid.segmentLabels.length; segment++) {
      if (segment % labelEvery != 0) continue;
      final angle = startAngle + step * segment + step / 2;
      final anchor = _polar(layout.center, layout.outerRadius + 14, angle);
      final painter = _textPainter(
        grid.segmentLabels[segment],
        labelStyle,
        maxWidth: 58,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 58);
      final x = _safeClamp(
        anchor.dx - painter.width / 2,
        padding.left,
        layout.chartRight - painter.width,
      );
      final y = _safeClamp(
        anchor.dy - painter.height / 2,
        padding.top,
        layout.bottom - painter.height,
      );
      painter.paint(canvas, Offset(x, y));
    }
  }

  void _drawLegend(Canvas canvas, _RadialHeatmapLayout layout) {
    if (layout.legendRect.width <= 2 || layout.legendRect.height <= 2) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(layout.legendRect, const Radius.circular(5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [lowColor, highColor],
        ).createShader(layout.legendRect),
    );

    final labelStyleSmall = labelStyle.copyWith(
      fontSize: (labelStyle.fontSize ?? 12) * 0.86,
    );
    final minPainter = _textPainter(
      valueFormatter(grid.min),
      labelStyleSmall,
      maxWidth: 42,
    )..layout(maxWidth: 42);
    minPainter.paint(
      canvas,
      Offset(
        layout.legendRect.right + 6,
        layout.legendRect.bottom - minPainter.height,
      ),
    );
    final maxPainter = _textPainter(
      valueFormatter(grid.max),
      labelStyleSmall,
      maxWidth: 42,
    )..layout(maxWidth: 42);
    maxPainter.paint(
      canvas,
      Offset(layout.legendRect.right + 6, layout.legendRect.top),
    );
  }

  Path _annularSegmentPath({
    required Offset center,
    required double innerRadius,
    required double outerRadius,
    required double start,
    required double sweep,
  }) {
    final safeInner = math.max(0.0, innerRadius);
    final safeOuter = math.max(safeInner + 0.01, outerRadius);
    final end = start + sweep;
    final path = Path()
      ..moveTo(
        center.dx + math.cos(start) * safeOuter,
        center.dy + math.sin(start) * safeOuter,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: safeOuter),
        start,
        sweep,
        false,
      )
      ..lineTo(
        center.dx + math.cos(end) * safeInner,
        center.dy + math.sin(end) * safeInner,
      );
    if (safeInner > 0.5) {
      path.arcTo(
        Rect.fromCircle(center: center, radius: safeInner),
        end,
        -sweep,
        false,
      );
    } else {
      path.lineTo(center.dx, center.dy);
    }
    return path..close();
  }

  Color _cellColor(SimpleRadialHeatmapCell cell) {
    if (cell.color != null) return cell.color!;
    return Color.lerp(lowColor, highColor, grid.normalize(cell.value)) ??
        highColor;
  }

  double _safeClamp(double value, double lower, double upper) {
    if (lower > upper) return lower;
    return value.clamp(lower, upper).toDouble();
  }

  TextPainter _textPainter(
    String text,
    TextStyle style, {
    double? maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
      ellipsis: maxWidth == null ? null : '...',
    );
  }

  @override
  bool shouldRepaint(covariant _SimpleRadialHeatmapPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.padding != padding ||
        oldDelegate.lowColor != lowColor ||
        oldDelegate.highColor != highColor ||
        oldDelegate.emptyColor != emptyColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.centerColor != centerColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showRingLabels != showRingLabels ||
        oldDelegate.showSegmentLabels != showSegmentLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveCell != showActiveCell ||
        oldDelegate.showCenterHole != showCenterHole ||
        oldDelegate.showEmptyCells != showEmptyCells ||
        oldDelegate.innerRadiusFactor != innerRadiusFactor ||
        oldDelegate.ringGap != ringGap ||
        oldDelegate.segmentGap != segmentGap ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeRing != activeRing ||
        oldDelegate.activeSegment != activeSegment ||
        oldDelegate.progress != progress;
  }
}

class _RadialHeatmapGrid {
  final List<String> ringLabels;
  final List<String> segmentLabels;
  final List<List<SimpleRadialHeatmapCell?>> cells;
  final double min;
  final double max;

  const _RadialHeatmapGrid({
    required this.ringLabels,
    required this.segmentLabels,
    required this.cells,
    required this.min,
    required this.max,
  });

  bool get isEmpty =>
      ringLabels.isEmpty || segmentLabels.isEmpty || cells.isEmpty;

  SimpleRadialHeatmapCell? cellAt(int ring, int segment) {
    if (ring < 0 ||
        segment < 0 ||
        ring >= cells.length ||
        segment >= cells[ring].length) {
      return null;
    }
    return cells[ring][segment];
  }

  double normalize(double value) {
    return ((value - min) / math.max(0.000001, max - min))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  factory _RadialHeatmapGrid.from({
    required List<String> ringLabels,
    required List<String> segmentLabels,
    required List<SimpleRadialHeatmapCell> cells,
    required double? minValue,
    required double? maxValue,
  }) {
    final resolvedRings = ringLabels.isNotEmpty
        ? ringLabels
        : _uniqueLabels(cells.map((item) => item.ringLabel));
    final resolvedSegments = segmentLabels.isNotEmpty
        ? segmentLabels
        : _uniqueLabels(cells.map((item) => item.segmentLabel));
    if (resolvedRings.isEmpty || resolvedSegments.isEmpty) {
      return const _RadialHeatmapGrid(
        ringLabels: [],
        segmentLabels: [],
        cells: [],
        min: 0,
        max: 1,
      );
    }

    final rings = {
      for (var index = 0; index < resolvedRings.length; index++)
        resolvedRings[index]: index,
    };
    final segments = {
      for (var index = 0; index < resolvedSegments.length; index++)
        resolvedSegments[index]: index,
    };
    final matrix = List.generate(
      resolvedRings.length,
      (_) =>
          List<SimpleRadialHeatmapCell?>.filled(resolvedSegments.length, null),
    );
    var lower = double.infinity;
    var upper = double.negativeInfinity;

    for (final cell in cells) {
      final ring = rings[cell.ringLabel];
      final segment = segments[cell.segmentLabel];
      if (ring == null || segment == null || !cell.value.isFinite) continue;
      matrix[ring][segment] = cell;
      lower = math.min(lower, cell.value);
      upper = math.max(upper, cell.value);
    }

    if (!lower.isFinite || !upper.isFinite) {
      return const _RadialHeatmapGrid(
        ringLabels: [],
        segmentLabels: [],
        cells: [],
        min: 0,
        max: 1,
      );
    }

    lower = minValue ?? lower;
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
    }

    return _RadialHeatmapGrid(
      ringLabels: resolvedRings,
      segmentLabels: resolvedSegments,
      cells: matrix,
      min: lower,
      max: upper,
    );
  }

  static List<String> _uniqueLabels(Iterable<String> labels) {
    final result = <String>[];
    for (final label in labels) {
      if (label.isEmpty || result.contains(label)) continue;
      result.add(label);
    }
    return result;
  }
}

class _RadialHeatmapHit {
  final int ring;
  final int segment;

  const _RadialHeatmapHit(this.ring, this.segment);
}

class _RadialHeatmapLayout {
  final Offset center;
  final double outerRadius;
  final Rect legendRect;
  final double chartRight;
  final double bottom;
  final bool compact;

  const _RadialHeatmapLayout({
    required this.center,
    required this.outerRadius,
    required this.legendRect,
    required this.chartRight,
    required this.bottom,
    required this.compact,
  });

  factory _RadialHeatmapLayout.resolve(
    Size size,
    EdgeInsets padding,
    bool showLegend,
    bool showRingLabels,
    bool showSegmentLabels,
  ) {
    final content = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    final compact = content.width < 360 || content.height < 220;
    final legendWidth = showLegend && !compact
        ? math.min(64.0, content.width * 0.16)
        : 0.0;
    final chartRect = Rect.fromLTRB(
      content.left,
      content.top,
      content.right - legendWidth - (legendWidth > 0 ? 14 : 0),
      content.bottom,
    );
    final labelInset = !compact && (showRingLabels || showSegmentLabels)
        ? 24.0
        : 8.0;
    final outerRadius = math.max(
      0.0,
      math.min(chartRect.width, chartRect.height) / 2 - labelInset,
    );
    final center = Offset(chartRect.center.dx, chartRect.center.dy - 2);
    final legendRect = legendWidth <= 0
        ? Rect.zero
        : Rect.fromLTWH(
            chartRect.right + 14,
            content.top + math.max(8.0, content.height * 0.18),
            14,
            math.max(44.0, content.height * 0.64),
          );

    return _RadialHeatmapLayout(
      center: center,
      outerRadius: outerRadius,
      legendRect: legendRect,
      chartRight: chartRect.right,
      bottom: content.bottom,
      compact: compact,
    );
  }

  double innerRadius(double factor) {
    if (outerRadius <= 1) return 0;
    return (outerRadius * factor).clamp(0.0, outerRadius - 1).toDouble();
  }
}

class _SimpleRadialHeatmapVisuals {
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;

  const _SimpleRadialHeatmapVisuals({
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.gridColor,
  });

  factory _SimpleRadialHeatmapVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleRadialHeatmapVisuals(
          lowColor: colorScheme.primary.withValues(alpha: 0.14),
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
        );
      case SimpleBarChartStyle.professional:
        return _SimpleRadialHeatmapVisuals(
          lowColor: colorScheme.surfaceContainerHighest,
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.65,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
        );
      case SimpleBarChartStyle.education:
        return _SimpleRadialHeatmapVisuals(
          lowColor: const Color(0xFFFEF3C7),
          highColor: colorScheme.secondary,
          emptyColor: colorScheme.surfaceContainerHighest,
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleRadialHeatmapVisuals(
          lowColor: const Color(0xFFE0F2FE),
          highColor: colorScheme.tertiary,
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.7,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleRadialHeatmapVisuals(
          lowColor: colorScheme.secondary.withValues(alpha: 0.14),
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
        );
    }
  }
}

class _DefaultRadialHeatmapTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;

  const _DefaultRadialHeatmapTooltip({
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onInverseSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Offset _polar(Offset center, double radius, double angle) {
  return Offset(
    center.dx + math.cos(angle) * radius,
    center.dy + math.sin(angle) * radius,
  );
}

double _normalizeAngle(double angle) {
  var normalized = angle % (math.pi * 2);
  if (normalized < 0) normalized += math.pi * 2;
  return normalized;
}
