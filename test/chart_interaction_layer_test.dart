import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/core/chart_interaction_layer.dart';
import 'package:tenun/core/zoom/chart_zoom_state.dart';

void main() {
  group('ChartInteractionLayer', () {
    testWidgets('double tap reports the pre-zoom data fraction', (
      tester,
    ) async {
      final controller = ChartZoomController();
      controller.setVisibleRange(0.2, 0.6);
      final emitted = <double>[];

      await tester.pumpWidget(
        _interactionHost(controller, width: 200, onDoubleTap: emitted.add),
      );

      final topLeft = tester.getTopLeft(find.byType(ChartInteractionLayer));
      final tapPoint = topLeft + const Offset(50, 40);
      await tester.tapAt(tapPoint);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(tapPoint);
      await tester.pump();

      expect(emitted, hasLength(1));
      expect(emitted.single, closeTo(0.3, 1e-9));
      expect(controller.value.windowSize, lessThan(0.4));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 50));

      controller.dispose();
    });

    testWidgets('stops active fling when zoom controller is replaced', (
      tester,
    ) async {
      final first = ChartZoomController();
      first.setVisibleRange(0.2, 0.6);
      final second = ChartZoomController();
      second.setVisibleRange(0.2, 0.6);

      await tester.pumpWidget(_interactionHost(first, width: 200));

      await tester.fling(
        find.byType(ChartInteractionLayer),
        const Offset(-140, 0),
        1800,
      );

      expect(first.hasMomentum, isTrue);
      final secondBefore = second.value;

      await tester.pumpWidget(_interactionHost(second, width: 200));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(second.value, secondBefore);
      expect(second.hasMomentum, isFalse);
      expect(tester.takeException(), isNull);

      first.dispose();
      second.dispose();
    });

    testWidgets('ends active crosshair when interaction layer is disposed', (
      tester,
    ) async {
      final controller = ChartZoomController();
      final moves = <double>[];
      var endCount = 0;

      await tester.pumpWidget(
        _interactionHost(
          controller,
          width: 200,
          onCrosshairMove: moves.add,
          onCrosshairEnd: () => endCount++,
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(ChartInteractionLayer));
      final gesture = await tester.startGesture(topLeft + const Offset(80, 40));
      await tester.pump(const Duration(milliseconds: 600));

      expect(moves, isNotEmpty);
      expect(moves.last, closeTo(0.4, 1e-9));
      expect(endCount, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await gesture.up();
      await tester.pump();

      expect(endCount, 1);
      expect(tester.takeException(), isNull);

      controller.dispose();
    });

    testWidgets('zero-width layout does not emit interaction callbacks', (
      tester,
    ) async {
      final controller = ChartZoomController();
      final taps = <double>[];
      final doubleTaps = <double>[];
      final crosshairMoves = <double>[];
      var crosshairEndCount = 0;

      await tester.pumpWidget(
        _interactionHost(
          controller,
          width: 0,
          onTap: taps.add,
          onDoubleTap: doubleTaps.add,
          onCrosshairMove: crosshairMoves.add,
          onCrosshairEnd: () => crosshairEndCount++,
        ),
      );

      final topLeft = tester.getTopLeft(find.byType(ChartInteractionLayer));
      final point = topLeft + const Offset(0, 40);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.longPressAt(point);
      await tester.pump(const Duration(milliseconds: 50));

      expect(taps, isEmpty);
      expect(doubleTaps, isEmpty);
      expect(crosshairMoves, isEmpty);
      expect(crosshairEndCount, 0);
      expect(tester.takeException(), isNull);

      controller.dispose();
    });
  });

  group('ZoomMinimap', () {
    testWidgets('tap recenters the visible zoom window', (tester) async {
      final controller = ChartZoomController();
      controller.setVisibleRange(0.2, 0.4);

      await tester.pumpWidget(_minimapHost(controller, width: 200));

      final topLeft = tester.getTopLeft(find.byType(ZoomMinimap));
      await tester.tapAt(topLeft + const Offset(150, 14));
      await tester.pump();

      expect(controller.value.xStart, closeTo(0.65, 1e-9));
      expect(controller.value.xEnd, closeTo(0.85, 1e-9));
    });

    testWidgets('drag moves the visible zoom window inside the minimap', (
      tester,
    ) async {
      final controller = ChartZoomController();
      controller.setVisibleRange(0.2, 0.4);

      await tester.pumpWidget(_minimapHost(controller, width: 200));

      final topLeft = tester.getTopLeft(find.byType(ZoomMinimap));
      await tester.dragFrom(
        topLeft + const Offset(100, 14),
        const Offset(60, 0),
      );
      await tester.pump();

      expect(controller.value.xStart, closeTo(0.4, 1e-9));
      expect(controller.value.xEnd, closeTo(0.6, 1e-9));
    });

    testWidgets('zero-width layout does not throw', (tester) async {
      final controller = ChartZoomController();
      controller.setVisibleRange(0.2, 0.4);

      await tester.pumpWidget(_minimapHost(controller, width: 0));

      expect(tester.takeException(), isNull);
      expect(controller.value.xStart, closeTo(0.2, 1e-9));
      expect(controller.value.xEnd, closeTo(0.4, 1e-9));
    });
  });
}

Widget _interactionHost(
  ChartZoomController controller, {
  required double width,
  void Function(double fraction)? onTap,
  void Function(double fraction)? onDoubleTap,
  void Function(double fraction)? onCrosshairMove,
  void Function()? onCrosshairEnd,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 120,
          child: ChartInteractionLayer(
            zoomController: controller,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onCrosshairMove: onCrosshairMove,
            onCrosshairEnd: onCrosshairEnd,
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    ),
  );
}

Widget _minimapHost(ChartZoomController controller, {required double width}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 28,
          child: ZoomMinimap(controller: controller),
        ),
      ),
    ),
  );
}
