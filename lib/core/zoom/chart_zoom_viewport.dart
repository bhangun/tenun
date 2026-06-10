// Zoom-aware viewport that maps between data space, zoom state, and canvas pixels.
//
// [ChartZoomViewport] extends the basic [ChartViewport] concept to be aware
// of the current [ChartZoomState]. All coordinate transforms automatically
// account for the current zoom window, so painters don't need to know about
// zoom at all — they just call [toCanvasX] / [toCanvasY] as normal.
//
// Key responsibilities:
//  1. Convert data indices to canvas pixels, respecting the current zoom window.
//  2. Provide [visibleRange] so painters can skip off-screen data points.
//  3. Rebuild efficiently — compare with [==] to skip unnecessary repaints.

import 'dart:math' as math;

import 'chart_zoom_state.dart';

// ---------------------------------------------------------------------------
// ChartZoomViewport
// ---------------------------------------------------------------------------

/// A viewport that integrates zoom state with canvas geometry.
///
/// Construct once per paint() call, or cache and compare with [==] to skip
/// rebuilding when nothing changed.
class ChartZoomViewport {
  // ---- Canvas geometry ----
  final double left;
  final double top;
  final double right;
  final double bottom;

  // ---- Full data range (unzoomed) ----
  final double dataMinY;
  final double dataMaxY;
  final int dataLength; // total number of data points on x-axis

  // ---- Zoom state ----
  final ChartZoomState zoomState;

  const ChartZoomViewport({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.dataMinY,
    required this.dataMaxY,
    required this.dataLength,
    this.zoomState = ChartZoomState.identity,
  });

  // ---- Geometry ----
  double get width => math.max(0, _finite(right) - _finite(left));
  double get height => math.max(0, _finite(bottom) - _finite(top));

  // ---- Zoom-aware visible index range ----

  /// First visible data index (inclusive).
  int get visibleStartIndex =>
      zoomState.startIndex(dataLength).clamp(0, math.max(0, dataLength - 1));

  /// Last visible data index (inclusive).
  int get visibleEndIndex =>
      zoomState.endIndex(dataLength).clamp(0, math.max(0, dataLength - 1));

  /// Number of visible data points.
  int get visibleCount {
    if (dataLength <= 0) return 0;
    return (visibleEndIndex - visibleStartIndex + 1).clamp(1, dataLength);
  }

  /// The fraction of the full dataset currently visible.
  double get visibleFraction => zoomState.windowSize;

  // ---- Coordinate transforms ----

  /// Convert a data index to canvas X pixel, respecting zoom state.
  ///
  /// Index [i] maps through the zoom window to the canvas range [left..right].
  double indexToCanvasX(int i) {
    if (dataLength <= 1) return _finite(left) + width / 2;
    final frac = i / (dataLength - 1);
    return _fracToCanvasX(frac);
  }

  /// Same as [indexToCanvasX] but accepts a fractional index.
  double fracIndexToCanvasX(double fi) {
    if (dataLength <= 1 || !fi.isFinite) return _finite(left) + width / 2;
    final frac = fi / (dataLength - 1);
    return _fracToCanvasX(frac);
  }

  /// Convert a data Y value to canvas Y pixel.
  double dataYToCanvasY(double dataY) {
    final minY = _finite(dataMinY);
    final maxY = _finite(dataMaxY, fallback: minY);
    final plotBottom = _finite(bottom);
    if (height <= 0 || maxY == minY || !dataY.isFinite) {
      return plotBottom - height / 2;
    }
    return plotBottom - (dataY - minY) / (maxY - minY) * height;
  }

  /// Convert canvas X pixel to data index (fractional).
  double canvasXToFracIndex(double cx) {
    if (width <= 0 || dataLength <= 1 || !cx.isFinite) return 0;
    final frac =
        zoomState.xStart +
        ((cx - _finite(left)) / width) * zoomState.windowSize;
    return frac * (dataLength - 1);
  }

  /// Convert canvas X pixel to data index (rounded).
  int canvasXToIndex(double cx) =>
      canvasXToFracIndex(cx).round().clamp(0, math.max(0, dataLength - 1));

  /// Convert canvas Y pixel to data Y value.
  double canvasYToDataY(double cy) {
    final minY = _finite(dataMinY);
    final maxY = _finite(dataMaxY, fallback: minY);
    if (height <= 0 || !cy.isFinite) return minY;
    return minY + (1 - (cy - _finite(top)) / height) * (maxY - minY);
  }

  /// Width of a single data slot (bar width, line segment, etc.) in canvas pixels.
  double get slotWidth {
    if (visibleCount <= 1) return width;
    return width / visibleCount;
  }

  /// Canvas x-center for a given data index.
  double slotCenterX(int i) => indexToCanvasX(i) + slotWidth / 2;

  // ---- Culling helpers ----

  /// True when data index [i] is within the visible zoom window.
  bool isIndexVisible(int i) => i >= visibleStartIndex && i <= visibleEndIndex;

  /// True when canvas x [cx] is within the plot area.
  bool isCanvasXVisible(double cx) =>
      cx.isFinite && cx >= _finite(left) && cx <= _finite(right);

  // ---- Zoom helpers (delegate to ChartZoomController) ----

  /// Compute the x-range fraction [0..1] that corresponds to indices
  /// [startIdx..endIdx]. Use this when programmatically zooming to a
  /// selection.
  (double, double) indicesToFraction(int startIdx, int endIdx) {
    if (dataLength <= 1) return (0, 1);
    final s = (startIdx / (dataLength - 1)).clamp(0.0, 1.0);
    final e = (endIdx / (dataLength - 1)).clamp(0.0, 1.0);
    return s <= e ? (s, e) : (e, s);
  }

  // ---- Factory helpers ----

  /// Build from canvas [size], spacing, and zoom state.
  factory ChartZoomViewport.fromPadding({
    required double width,
    required double height,
    required double paddingLeft,
    required double paddingTop,
    required double paddingRight,
    required double paddingBottom,
    required double dataMinY,
    required double dataMaxY,
    required int dataLength,
    ChartZoomState zoomState = ChartZoomState.identity,
  }) {
    return ChartZoomViewport(
      left: paddingLeft,
      top: paddingTop,
      right: width - paddingRight,
      bottom: height - paddingBottom,
      dataMinY: dataMinY,
      dataMaxY: dataMaxY,
      dataLength: dataLength,
      zoomState: zoomState,
    );
  }

  // ---- Equality (cheap repaint check) ----

  @override
  bool operator ==(Object other) =>
      other is ChartZoomViewport &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.dataMinY == dataMinY &&
      other.dataMaxY == dataMaxY &&
      other.dataLength == dataLength &&
      other.zoomState == zoomState;

  @override
  int get hashCode => Object.hash(
    left,
    top,
    right,
    bottom,
    dataMinY,
    dataMaxY,
    dataLength,
    zoomState,
  );

  @override
  String toString() =>
      'ChartZoomViewport('
      'canvas=[${left.toStringAsFixed(0)},${top.toStringAsFixed(0)}'
      '..${right.toStringAsFixed(0)},${bottom.toStringAsFixed(0)}], '
      'y=[${dataMinY.toStringAsFixed(1)}..${dataMaxY.toStringAsFixed(1)}], '
      'zoom=${zoomState.toString()}'
      ')';

  // ---- Internal ----

  double _fracToCanvasX(double dataFrac) {
    final zs = zoomState;
    if (zs.windowSize <= 0 || !dataFrac.isFinite) return _finite(left);
    return _finite(left) + ((dataFrac - zs.xStart) / zs.windowSize) * width;
  }
}

double _finite(double value, {double fallback = 0}) =>
    value.isFinite ? value : fallback;

// ---------------------------------------------------------------------------
// ZoomViewportMixin — convenience mixin for painters
// ---------------------------------------------------------------------------

/// Mixin for [CustomPainter] subclasses that use [ChartZoomViewport].
///
/// Provides:
/// - [viewport] accessor (set via [setViewport]).
/// - [visiblePoints]: filtered subset of data within the zoom window.
/// - [buildZoomViewport]: factory to construct the viewport from painter params.
mixin ZoomViewportMixin {
  ChartZoomViewport? _viewport;

  ChartZoomViewport get viewport {
    assert(_viewport != null, 'Call setViewport() before using viewport');
    return _viewport!;
  }

  void setViewport(ChartZoomViewport vp) => _viewport = vp;

  bool get hasViewport => _viewport != null;

  /// Returns only the data indices that are visible in the current zoom window.
  ///
  /// Adds ±1 padding so partially visible items at the edges render correctly.
  (int start, int end) visibleRange(int dataLength) {
    if (_viewport == null) return (0, dataLength - 1);
    final s = math.max(0, _viewport!.visibleStartIndex - 1);
    final e = math.min(dataLength - 1, _viewport!.visibleEndIndex + 1);
    return (s, e);
  }
}
