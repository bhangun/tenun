import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/core/chart_viewport_culling.dart';

void main() {
  group('AdaptiveCullingConfig', () {
    testWidgets('returns bounded thresholds for small and ultra-large inputs', (
      tester,
    ) async {
      late int negative;
      late int small;
      late int medium;
      late int huge;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Builder(
            builder: (context) {
              negative = AdaptiveCullingConfig.getRenderThreshold(context, -1);
              small = AdaptiveCullingConfig.getRenderThreshold(context, 1000);
              medium = AdaptiveCullingConfig.getRenderThreshold(context, 10000);
              huge = AdaptiveCullingConfig.getRenderThreshold(context, 2000000);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(negative, 0);
      expect(small, 1000);
      expect(medium, 1500);
      expect(huge, AdaptiveCullingConfig.maxRenderThreshold);
    });
  });

  group('ViewportCullingMixin', () {
    final culling = _CullingHarness();

    test('returns stable empty and singleton ranges', () {
      final empty = culling.visible(totalPoints: 0);
      expect(empty, ViewportCullingMixin.emptyVisibleRange);
      expect(culling.isVisibleRangeEmpty(empty), isTrue);

      expect(culling.visible(totalPoints: 1), (0, 0));
    });

    test('maps viewport pixels to ordered data indices', () {
      final visible = culling.visible(viewportMinX: 35, viewportMaxX: 85);

      expect(visible, (25, 75));
      expect(culling.isVisibleRangeEmpty(visible), isFalse);
    });

    test('normalizes reversed data and viewport bounds', () {
      final visible = culling.visible(
        dataMinX: 100,
        dataMaxX: 0,
        viewportMinX: 85,
        viewportMaxX: 35,
      );

      expect(visible, (25, 75));
    });

    test('returns an empty range when viewport is outside the plot area', () {
      expect(
        culling.visible(viewportMinX: -50, viewportMaxX: 0),
        ViewportCullingMixin.emptyVisibleRange,
      );
      expect(
        culling.visible(viewportMinX: 120, viewportMaxX: 160),
        ViewportCullingMixin.emptyVisibleRange,
      );
    });

    test('falls back to full range for malformed geometry', () {
      expect(culling.visible(dataMaxX: double.nan), (0, 100));
      expect(culling.visible(leftPadding: 80, rightPadding: 80), (0, 100));
      expect(culling.visible(dataMinX: 5, dataMaxX: 5), (0, 100));
    });
  });
}

class _CullingHarness with ViewportCullingMixin {
  (int start, int end) visible({
    int totalPoints = 101,
    double dataMinX = 0,
    double dataMaxX = 100,
    double viewportMinX = 10,
    double viewportMaxX = 110,
    double leftPadding = 10,
    double rightPadding = 10,
    double canvasWidth = 120,
  }) => getVisibleIndices(
    totalPoints: totalPoints,
    dataMinX: dataMinX,
    dataMaxX: dataMaxX,
    viewportMinX: viewportMinX,
    viewportMaxX: viewportMaxX,
    leftPadding: leftPadding,
    rightPadding: rightPadding,
    canvasWidth: canvasWidth,
  );
}
