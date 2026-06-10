import 'package:flutter/material.dart';

/// Adaptive threshold & viewport culling for massive datasets (>50k pts).
class AdaptiveCullingConfig {
  static const int minRenderThreshold = 500;
  static const int maxRenderThreshold = 50000;
  static const int ultraLargePointCount = 100000;

  static int getRenderThreshold(BuildContext context, int totalPoints) {
    if (totalPoints <= 0) return 0;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final safeDpr = dpr.isFinite && dpr > 0 ? dpr : 1.0;
    final base = (minRenderThreshold * safeDpr)
        .clamp(minRenderThreshold, maxRenderThreshold)
        .toInt();

    // For ultra-large datasets, use dynamic percentage while keeping a hard
    // upper bound so painters do not accidentally render every visible point.
    if (totalPoints > ultraLargePointCount) {
      return (totalPoints * 0.05)
          .clamp(base, maxRenderThreshold)
          .toInt()
          .clamp(0, totalPoints);
    }
    return base.clamp(0, totalPoints);
  }
}

/// Mixin for painters to skip off-screen points.
mixin ViewportCullingMixin {
  static const (int start, int end) emptyVisibleRange = (0, -1);

  (int start, int end) getVisibleIndices({
    required int totalPoints,
    required double dataMinX,
    required double dataMaxX,
    required double viewportMinX,
    required double viewportMaxX,
    required double leftPadding,
    required double rightPadding,
    required double canvasWidth,
  }) {
    if (totalPoints <= 0) return emptyVisibleRange;
    if (totalPoints == 1) return (0, 0);

    final inputsAreFinite =
        dataMinX.isFinite &&
        dataMaxX.isFinite &&
        viewportMinX.isFinite &&
        viewportMaxX.isFinite &&
        leftPadding.isFinite &&
        rightPadding.isFinite &&
        canvasWidth.isFinite;
    if (!inputsAreFinite) return _fullRange(totalPoints);

    final plotLeft = leftPadding.clamp(0.0, canvasWidth);
    final plotRight = (canvasWidth - rightPadding).clamp(0.0, canvasWidth);
    final plotMin = plotLeft < plotRight ? plotLeft : plotRight;
    final plotMax = plotLeft < plotRight ? plotRight : plotLeft;
    final plotWidth = plotMax - plotMin;
    if (plotWidth <= 0) return _fullRange(totalPoints);

    final dataMin = dataMinX < dataMaxX ? dataMinX : dataMaxX;
    final dataMax = dataMinX < dataMaxX ? dataMaxX : dataMinX;
    final dataWidth = dataMax - dataMin;
    if (dataWidth <= 0) return _fullRange(totalPoints);

    final viewportMin = viewportMinX < viewportMaxX
        ? viewportMinX
        : viewportMaxX;
    final viewportMax = viewportMinX < viewportMaxX
        ? viewportMaxX
        : viewportMinX;
    final clippedMin = viewportMin.clamp(plotMin, plotMax);
    final clippedMax = viewportMax.clamp(plotMin, plotMax);
    if (viewportMax < plotMin ||
        viewportMin > plotMax ||
        clippedMin > clippedMax) {
      return emptyVisibleRange;
    }

    final visibleDataMin =
        dataMin + (clippedMin - plotMin) / plotWidth * dataWidth;
    final visibleDataMax =
        dataMin + (clippedMax - plotMin) / plotWidth * dataWidth;
    final maxIndex = totalPoints - 1;
    final idxMin = ((visibleDataMin - dataMin) / dataWidth * maxIndex)
        .floor()
        .clamp(0, maxIndex);
    final idxMax = ((visibleDataMax - dataMin) / dataWidth * maxIndex)
        .ceil()
        .clamp(0, maxIndex);

    return (idxMin, idxMax);
  }

  bool isVisibleRangeEmpty((int start, int end) range) => range.$2 < range.$1;

  (int start, int end) _fullRange(int totalPoints) =>
      totalPoints <= 0 ? emptyVisibleRange : (0, totalPoints - 1);
}
