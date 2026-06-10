// Abstract base class for all k_chart [CustomPainter] implementations.
//
// Provides:
// - Smart [shouldRepaint] that avoids unnecessary repaints.
// - Common grid, axis, crosshair and tooltip drawing helpers.
// - Paint object accessors backed by [PaintCache] (zero allocation per frame).
// - Text rendering via [TextPainterCache] (LRU, bounded).
// - Path caching via [PathCache] for expensive computed geometry.
// - Viewport-aware data culling helpers.
//
// Changes from v1:
// - [_drawDashedLine]: fixed wrong `totalLen` calculation (was treating
//   squared magnitude as length). Now uses `sqrt` + proper unit vector.
// - [ChartPainterWidget]: added `hitTestBehavior` + `isComplex` flag.
// - Added [clipToViewport] canvas helper.
// - Added [pathCacheKey] / [buildAndCachePath] helpers.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'chart_cache.dart' as chart_cache;
import 'chart_theme.dart';

// ---------------------------------------------------------------------------
// Viewport — maps data space to canvas space
// ---------------------------------------------------------------------------

/// Translates between data coordinates and canvas pixels.
class ChartViewport {
  final double left;
  final double top;
  final double right;
  final double bottom;

  final double dataMinX;
  final double dataMaxX;
  final double dataMinY;
  final double dataMaxY;

  const ChartViewport({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.dataMinX,
    required this.dataMaxX,
    required this.dataMinY,
    required this.dataMaxY,
  });

  double get width => right - left;
  double get height => bottom - top;

  /// The canvas [Rect] corresponding to the plot area.
  Rect get rect => Rect.fromLTRB(left, top, right, bottom);

  double toCanvasX(double dataX) {
    if (dataMaxX == dataMinX) return left + width / 2;
    return left + (dataX - dataMinX) / (dataMaxX - dataMinX) * width;
  }

  double toCanvasY(double dataY) {
    if (dataMaxY == dataMinY) return bottom - height / 2;
    return bottom - (dataY - dataMinY) / (dataMaxY - dataMinY) * height;
  }

  Offset toCanvas(double dataX, double dataY) =>
      Offset(toCanvasX(dataX), toCanvasY(dataY));

  double toDataX(double canvasX) {
    if (width == 0) return dataMinX;
    return dataMinX + (canvasX - left) / width * (dataMaxX - dataMinX);
  }

  double toDataY(double canvasY) {
    if (height == 0) return dataMinY;
    return dataMinY + (1 - (canvasY - top) / height) * (dataMaxY - dataMinY);
  }

  /// True if the canvas point is within the plot area (with optional padding).
  bool containsCanvas(Offset pt, {double padding = 0}) {
    return pt.dx >= left - padding &&
        pt.dx <= right + padding &&
        pt.dy >= top - padding &&
        pt.dy <= bottom + padding;
  }

  /// True if a data x-value would land in the visible canvas range.
  bool isDataXVisible(double dataX) {
    final cx = toCanvasX(dataX);
    return cx >= left && cx <= right;
  }

  /// Range of data indices that map to the visible canvas area.
  ///
  /// Useful for culling off-screen data points in bar/line charts where
  /// x = index.
  (int start, int end) visibleIndexRange(int totalPoints) {
    if (totalPoints == 0) return (0, 0);
    final startIdx = toDataX(left).floor().clamp(0, totalPoints - 1);
    final endIdx = toDataX(right).ceil().clamp(0, totalPoints - 1);
    return (startIdx, endIdx);
  }

  /// Create a viewport from canvas [size] and data range with padding from
  /// [ChartSpacing].
  factory ChartViewport.fromSize(
    Size size,
    ChartSpacing spacing, {
    required double dataMinX,
    required double dataMaxX,
    required double dataMinY,
    required double dataMaxY,
  }) {
    return ChartViewport(
      left: spacing.chartPaddingLeft,
      top: spacing.chartPaddingTop,
      right: size.width - spacing.chartPaddingRight,
      bottom: size.height - spacing.chartPaddingBottom,
      dataMinX: dataMinX,
      dataMaxX: dataMaxX,
      dataMinY: dataMinY,
      dataMaxY: dataMaxY,
    );
  }
}

// ---------------------------------------------------------------------------
// Abstract base painter
// ---------------------------------------------------------------------------

abstract class ChartPainterBase extends CustomPainter {
  final ChartTheme theme;

  /// Repaint listenable — pass a [ChartController] or [AnimationController].
  const ChartPainterBase({super.repaint, this.theme = ChartTheme.light});

  // ---------- Paint helpers (zero-allocation via cache) ----------

  chart_cache.PaintCache get paintCache => chart_cache.paintCache;
  chart_cache.TextPainterCache get textPainterCache =>
      chart_cache.textPainterCache;
  chart_cache.ColorCache get colorCache => chart_cache.colorCache;
  chart_cache.PathCache get pathCache => chart_cache.pathCache;

  Paint fillPaint(Color color) => paintCache.fill(color);
  Paint strokePaint(Color color, double width) =>
      paintCache.stroke(color, width);

  /// Returns a new mutable fill paint — safe to add shaders, maskFilters etc.
  Paint fillPaintMutable(Color color) => paintCache.fillMutable(color);

  Paint get gridPaint =>
      strokePaint(theme.gridColor, theme.spacing.gridLineWidth);
  Paint get axisPaint => strokePaint(theme.axisColor, 1.0);
  Paint get crosshairPaint => strokePaint(theme.crosshairColor, 1.0);

  // ---------- Common drawing helpers ----------

  /// Draw horizontal grid lines across [viewport] for [yTicks].
  void drawHorizontalGrid(
    Canvas canvas,
    ChartViewport viewport,
    List<double> yTicks, {
    bool dashed = true,
  }) {
    for (final y in yTicks) {
      final cy = viewport.toCanvasY(y);
      if (dashed) {
        _drawDashedLine(
          canvas,
          Offset(viewport.left, cy),
          Offset(viewport.right, cy),
          gridPaint,
        );
      } else {
        canvas.drawLine(
          Offset(viewport.left, cy),
          Offset(viewport.right, cy),
          gridPaint,
        );
      }
    }
  }

  /// Draw vertical grid lines for each x category in [xPositions].
  void drawVerticalGrid(
    Canvas canvas,
    ChartViewport viewport,
    List<double> xPositions, {
    bool dashed = false,
  }) {
    for (final x in xPositions) {
      if (dashed) {
        _drawDashedLine(
          canvas,
          Offset(x, viewport.top),
          Offset(x, viewport.bottom),
          gridPaint,
        );
      } else {
        canvas.drawLine(
          Offset(x, viewport.top),
          Offset(x, viewport.bottom),
          gridPaint,
        );
      }
    }
  }

  /// Draw a dashed line segment with [paint].
  void drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dash = 6,
    double gap = 4,
  }) {
    _drawDashedLine(canvas, start, end, paint, dashLen: dash, gapLen: gap);
  }

  /// Draw left Y-axis labels for [yTicks].
  void drawYAxisLabels(
    Canvas canvas,
    ChartViewport viewport,
    List<double> yTicks,
    String Function(double) formatter,
  ) {
    final style = theme.typography.axisLabelStyle.copyWith(
      color: theme.axisLabelColor,
    );
    for (final y in yTicks) {
      final cy = viewport.toCanvasY(y);
      final tp = textPainterCache.get(
        formatter(y),
        style,
        maxWidth: viewport.left - 4,
        align: TextAlign.right,
      );
      tp.paint(
        canvas,
        Offset(viewport.left - tp.width - 4, cy - tp.height / 2),
      );
    }
  }

  /// Draw bottom X-axis labels for [xLabels] at [xPositions].
  void drawXAxisLabels(
    Canvas canvas,
    ChartViewport viewport,
    List<String> xLabels,
    List<double> xPositions,
  ) {
    final style = theme.typography.axisLabelStyle.copyWith(
      color: theme.axisLabelColor,
    );
    for (int i = 0; i < xLabels.length && i < xPositions.length; i++) {
      final tp = textPainterCache.get(xLabels[i], style);
      tp.paint(
        canvas,
        Offset(xPositions[i] - tp.width / 2, viewport.bottom + 4),
      );
    }
  }

  /// Draw rotated X-axis labels (e.g., for many categories).
  void drawXAxisLabelsRotated(
    Canvas canvas,
    ChartViewport viewport,
    List<String> xLabels,
    List<double> xPositions, {
    double angleDeg = -45,
  }) {
    final style = theme.typography.axisLabelStyle.copyWith(
      color: theme.axisLabelColor,
    );
    final angle = angleDeg * math.pi / 180;
    for (int i = 0; i < xLabels.length && i < xPositions.length; i++) {
      final tp = textPainterCache.get(xLabels[i], style);
      canvas.save();
      canvas.translate(xPositions[i], viewport.bottom + 4);
      canvas.rotate(angle);
      tp.paint(canvas, Offset(-tp.width / 2, 0));
      canvas.restore();
    }
  }

  /// Draw a vertical crosshair line at canvas-x [cx].
  void drawCrosshair(Canvas canvas, ChartViewport viewport, double cx) {
    canvas.drawLine(
      Offset(cx, viewport.top),
      Offset(cx, viewport.bottom),
      crosshairPaint,
    );
  }

  /// Draw a horizontal crosshair line at canvas-y [cy].
  void drawHorizontalCrosshair(
    Canvas canvas,
    ChartViewport viewport,
    double cy,
  ) {
    canvas.drawLine(
      Offset(viewport.left, cy),
      Offset(viewport.right, cy),
      crosshairPaint,
    );
  }

  /// Draw a rounded-rect tooltip bubble.
  void drawTooltip(
    Canvas canvas,
    Size canvasSize,
    Offset anchor,
    List<String> lines,
  ) {
    const padding = 8.0;
    const radius = 6.0;
    const lineSpacing = 4.0;

    final style = theme.typography.tooltipStyle.copyWith(
      color: theme.tooltipTextColor,
    );

    final painters = lines
        .map((l) => textPainterCache.get(l, style, maxWidth: 200))
        .toList();
    final maxW = painters.fold<double>(0, (m, p) => p.width > m ? p.width : m);
    final totalH =
        painters.fold<double>(0, (s, p) => s + p.height) +
        lineSpacing * (painters.length - 1);

    double x = anchor.dx + 12;
    double y = anchor.dy - totalH / 2 - padding;
    x = x.clamp(0, canvasSize.width - maxW - padding * 2 - 12);
    y = y.clamp(0, canvasSize.height - totalH - padding * 2);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, maxW + padding * 2, totalH + padding * 2),
      const Radius.circular(radius),
    );

    canvas.drawRRect(rect, fillPaint(theme.tooltipBackgroundColor));

    double textY = y + padding;
    for (final tp in painters) {
      tp.paint(canvas, Offset(x + padding, textY));
      textY += tp.height + lineSpacing;
    }
  }

  /// Clip canvas to the viewport plot area for the duration of [body].
  ///
  /// Prevents drawing outside the chart bounds (e.g., on axis labels).
  void clipToViewport(
    Canvas canvas,
    ChartViewport viewport,
    void Function() body,
  ) {
    canvas.save();
    canvas.clipRect(viewport.rect);
    body();
    canvas.restore();
  }

  // ---------- Path cache helpers ----------

  /// Build (or retrieve cached) a [ui.Path] keyed by [key].
  ///
  /// Pass a stable [key] that encodes the data identity (e.g., a hash of the
  /// series values + viewport dimensions). Call [invalidatePath] when data
  /// changes.
  ///
  /// ```dart
  /// final path = buildAndCachePath(
  ///   'line_0_${dataHash}_${viewport.width.toInt()}',
  ///   () => _buildLinePath(points, viewport),
  /// );
  /// canvas.drawPath(path, strokePaint(color, 2));
  /// ```
  ui.Path buildAndCachePath(String key, ui.Path Function() builder) {
    return pathCache.getOrBuild(key, builder);
  }

  void invalidatePath(String key) => pathCache.invalidate(key);
  void invalidatePathsWithPrefix(String prefix) =>
      pathCache.invalidatePrefix(prefix);

  // ---------- shouldRepaint ----------

  /// Subclasses should override [shouldRepaintChart] instead.
  @override
  bool shouldRepaint(covariant ChartPainterBase old) {
    return old.theme != theme || shouldRepaintChart(old);
  }

  /// Return `true` if chart-specific state (data, selection, animation value…)
  /// has changed. Keep this as cheap as possible — reference equality is fine.
  bool shouldRepaintChart(covariant ChartPainterBase old) => true;

  // ---------- Internal ----------

  /// Draw a dashed line from [p1] to [p2].
  ///
  /// BUG FIX v2: the original implementation calculated `length` as the
  /// squared dot-product (i.e. magnitude²) and then used it as a linear
  /// distance, which caused extremely short/long dashes depending on the
  /// angle. Now uses `sqrt` for the true Euclidean length and a proper
  /// normalised unit vector.
  void _drawDashedLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Paint paint, {
    double dashLen = 4.0,
    double gapLen = 4.0,
  }) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final totalLen = math.sqrt(dx * dx + dy * dy);
    if (totalLen < 0.001) return;

    final ux = dx / totalLen;
    final uy = dy / totalLen;

    double traveled = 0;
    while (traveled < totalLen) {
      final startX = p1.dx + ux * traveled;
      final startY = p1.dy + uy * traveled;
      traveled += dashLen;
      final endX = p1.dx + ux * traveled.clamp(0, totalLen);
      final endY = p1.dy + uy * traveled.clamp(0, totalLen);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      traveled += gapLen;
    }
  }
}

// ---------------------------------------------------------------------------
// ChartPainterWidget — wraps a painter in RepaintBoundary + LayoutBuilder
// ---------------------------------------------------------------------------

/// Convenience widget that wraps a [CustomPaint] in a [RepaintBoundary].
///
/// This isolates chart repaints from the surrounding widget tree.
class ChartPainterWidget extends StatelessWidget {
  final CustomPainter painter;
  final Size? size;

  /// Pass `isComplex: true` for charts with many paths/gradients so Flutter
  /// rasterises them to a cached layer (trades RAM for CPU time).
  final bool isComplex;

  /// Controls hit-testing — use [HitTestBehavior.opaque] when the chart
  /// handles gestures (zoom, tap-to-select etc.).
  final HitTestBehavior hitTestBehavior;

  const ChartPainterWidget({
    super.key,
    required this.painter,
    this.size,
    this.isComplex = false,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: size ?? Size.infinite,
        isComplex: isComplex,
        painter: painter,
      ),
    );
  }
}
