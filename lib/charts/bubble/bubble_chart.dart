import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/chart_data_processor.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'bubble_config.dart';

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class BubbleChartWidget extends StatefulWidget {
  final BubbleChartConfig config;
  const BubbleChartWidget({super.key, required this.config});

  @override
  State<BubbleChartWidget> createState() => _BubbleChartWidgetState();
}

class _BubbleChartWidgetState extends State<BubbleChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;
  BubblePoint? _hoveredPoint;
  Offset? _hoverPos;

  BubbleChartConfig get config => widget.config;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (config.title?.text != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                config.title!.text!,
                style: config.theme.typography.titleStyle,
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: [
                  MouseRegion(
                    onHover: (e) => _onHover(e.localPosition, size),
                    onExit: (_) => setState(() {
                      _hoveredPoint = null;
                    }),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _onHover(d.localPosition, size),
                      child: AnimatedBuilder(
                        animation: _anim,
                        builder: (context, child) => RepaintBoundary(
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _BubblePainter(
                              config: config,
                              animProgress: _anim.value,
                              hoveredPoint: _hoveredPoint,
                              theme: config.theme,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_hoveredPoint != null && _hoverPos != null)
                    _buildTooltip(size),
                ],
              );
            },
          ),
        ),
        if (config.legend?.show == true) _buildLegend(),
      ],
    );
  }

  void _onHover(Offset pos, Size size) {
    final sp = config.theme.spacing;
    if (!_hasPlotArea(size, sp)) {
      setState(() {
        _hoveredPoint = null;
        _hoverPos = pos;
      });
      return;
    }
    final vp = _makeViewport(size, sp);

    BubblePoint? closest;
    double closestDist = double.infinity;
    for (final s in config.bubbleSeries) {
      for (final p in s.data) {
        final cx = vp.toCanvasX(p.x);
        final cy = vp.toCanvasY(p.y);
        final d = (Offset(cx, cy) - pos).distance;
        if (d < closestDist) {
          closestDist = d;
          closest = p;
        }
      }
    }

    setState(() {
      _hoveredPoint = closestDist < 40 ? closest : null;
      _hoverPos = pos;
    });
  }

  Widget _buildTooltip(Size size) {
    final p = _hoveredPoint!;
    final theme = config.theme;
    double x = (_hoverPos!.dx + 12).clamp(0, size.width - 160);
    double y = (_hoverPos!.dy - 60).clamp(0, size.height - 80);
    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.tooltipBackgroundColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (p.label != null)
                Text(
                  p.label!,
                  style: theme.typography.tooltipStyle.copyWith(
                    color: theme.tooltipTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                'x: ${p.x.toStringAsFixed(2)}',
                style: theme.typography.tooltipStyle.copyWith(
                  color: theme.tooltipTextColor,
                ),
              ),
              Text(
                'y: ${p.y.toStringAsFixed(2)}',
                style: theme.typography.tooltipStyle.copyWith(
                  color: theme.tooltipTextColor,
                ),
              ),
              Text(
                'size: ${p.size.toStringAsFixed(1)}',
                style: theme.typography.tooltipStyle.copyWith(
                  color: theme.tooltipTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final theme = config.theme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 16,
        children: config.bubbleSeries.asMap().entries.map((e) {
          final color = theme.seriesColor(e.key, explicitColor: e.value.color);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                e.value.name,
                style: theme.typography.legendStyle.copyWith(
                  color: theme.legendTextColor,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  ChartViewport _makeViewport(Size size, ChartSpacing sp) {
    return ChartViewport(
      left: sp.chartPaddingLeft,
      top: sp.chartPaddingTop,
      right: size.width - sp.chartPaddingRight,
      bottom: size.height - sp.chartPaddingBottom,
      dataMinX: config.xMin,
      dataMaxX: config.xMax,
      dataMinY: config.yMin,
      dataMaxY: config.yMax,
    );
  }
}

bool _hasPlotArea(Size size, ChartSpacing spacing) {
  return size.width > spacing.chartPaddingLeft + spacing.chartPaddingRight &&
      size.height > spacing.chartPaddingTop + spacing.chartPaddingBottom;
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _BubblePainter extends ChartPainterBase {
  final BubbleChartConfig config;
  final double animProgress;
  final BubblePoint? hoveredPoint;

  _BubblePainter({
    required this.config,
    required this.animProgress,
    required this.hoveredPoint,
    required super.theme,
  });

  @override
  bool shouldRepaintChart(covariant _BubblePainter old) =>
      old.animProgress != animProgress ||
      old.hoveredPoint != hoveredPoint ||
      old.config != config;

  @override
  void paint(Canvas canvas, Size size) {
    final sp = theme.spacing;
    if (!_hasPlotArea(size, sp)) return;
    final vp = ChartViewport(
      left: sp.chartPaddingLeft,
      top: sp.chartPaddingTop,
      right: size.width - sp.chartPaddingRight,
      bottom: size.height - sp.chartPaddingBottom,
      dataMinX: config.xMin,
      dataMaxX: config.xMax,
      dataMinY: config.yMin,
      dataMaxY: config.yMax,
    );

    // Grid
    final yTicks = ChartDataProcessor.niceYTicks(config.yMin, config.yMax);
    final xTicks = ChartDataProcessor.niceYTicks(config.xMin, config.xMax);
    drawHorizontalGrid(canvas, vp, yTicks);
    drawYAxisLabels(canvas, vp, yTicks, (v) => v.toStringAsFixed(0));
    drawXAxisLabels(
      canvas,
      vp,
      xTicks.map((v) => v.toStringAsFixed(0)).toList(),
      xTicks.map((v) => vp.toCanvasX(v)).toList(),
    );

    // Axes
    canvas.drawLine(
      Offset(vp.left, vp.bottom),
      Offset(vp.right, vp.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(vp.left, vp.top),
      Offset(vp.left, vp.bottom),
      axisPaint,
    );

    // Size scale
    double maxSize = 1;
    for (final s in config.bubbleSeries) {
      for (final p in s.data) {
        if (p.size.isFinite && p.size > maxSize) maxSize = p.size;
      }
    }

    // Draw bubbles (back to front by size)
    for (int si = 0; si < config.bubbleSeries.length; si++) {
      final s = config.bubbleSeries[si];
      final color = theme.seriesColor(si, explicitColor: s.color);

      final sorted = [...s.data]..sort((a, b) => b.size.compareTo(a.size));
      for (final p in sorted) {
        final cx = vp.toCanvasX(p.x);
        final cy = vp.toCanvasY(p.y);
        final logicalSize = p.size.isFinite && p.size > 0 ? p.size : 1.0;
        final r =
            config.minBubbleRadius +
            (logicalSize / maxSize).clamp(0.0, 1.0) *
                (config.maxBubbleRadius - config.minBubbleRadius);
        final animR = r * animProgress;

        final isHovered = p == hoveredPoint;
        final opacity = (isHovered ? 0.9 : s.opacity)
            .clamp(0.0, 1.0)
            .toDouble();
        final fillColor = color.withValues(alpha: opacity);

        // Custom mutable paint for opacity
        final paint = Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;

        canvas.drawCircle(Offset(cx, cy), animR, paint);

        // Border
        canvas.drawCircle(
          Offset(cx, cy),
          animR,
          strokePaint(color.withValues(alpha: 0.8), 1.0),
        );

        if (config.showLabels && p.label != null && animR > 12) {
          final tp = textPainterCache.get(
            p.label!,
            theme.typography.axisLabelStyle.copyWith(
              color: Colors.white,
              fontSize: 9,
            ),
            maxWidth: animR * 2,
            align: TextAlign.center,
          );
          tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
        }
      }
    }
  }
}
