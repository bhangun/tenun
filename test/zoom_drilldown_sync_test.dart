import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/indicator/indicator_chart.dart';
import 'package:tenun_core/core/chart_interaction_layer.dart';
import 'package:tenun/tenun.dart';
import 'package:tenun_core/core/zoom/chart_drilldown_controller.dart';
import 'package:tenun_core/tenun_core.dart';

IndicatorChartConfig _indicator(String label, double value) =>
    IndicatorChartConfig(value: value, label: label);

Widget _zoomableHost({
  ChartZoomController? zoomController,
  ZoomConstraints zoomConstraints = const ZoomConstraints(),
  void Function(double fraction, ChartZoomController zoom)? onDoubleTap,
}) {
  return MaterialApp(
    home: SizedBox(
      width: 240,
      height: 180,
      child: ZoomableTenunChart(
        config: _indicator('root', 1),
        zoomController: zoomController,
        zoomConstraints: zoomConstraints,
        showResetButton: false,
        onDoubleTap: onDoubleTap,
      ),
    ),
  );
}

Future<void> _doubleTapInteractionLayer(WidgetTester tester) async {
  final point = tester.getCenter(find.byType(ChartInteractionLayer));
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(point);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('ZoomableTenunChart lifecycle', () {
    testWidgets('uses replacement external zoom controller for interactions', (
      tester,
    ) async {
      final first = ChartZoomController();
      final second = ChartZoomController();
      final emittedControllers = <ChartZoomController>[];

      await tester.pumpWidget(
        _zoomableHost(
          zoomController: first,
          onDoubleTap: (_, zoom) => emittedControllers.add(zoom),
        ),
      );

      await tester.pumpWidget(
        _zoomableHost(
          zoomController: second,
          onDoubleTap: (_, zoom) => emittedControllers.add(zoom),
        ),
      );
      await tester.pumpAndSettle();

      await _doubleTapInteractionLayer(tester);

      expect(emittedControllers, hasLength(1));
      expect(emittedControllers.single, same(second));
      expect(first.isDisposed, isFalse);
      expect(second.isDisposed, isFalse);
      expect(tester.takeException(), isNull);

      first.dispose();
      second.dispose();
    });

    testWidgets('recreates owned controller when constraints change', (
      tester,
    ) async {
      final emittedControllers = <ChartZoomController>[];

      await tester.pumpWidget(
        _zoomableHost(
          zoomConstraints: const ZoomConstraints(minWindowFraction: 0.05),
          onDoubleTap: (_, zoom) => emittedControllers.add(zoom),
        ),
      );
      await tester.pumpAndSettle();

      await _doubleTapInteractionLayer(tester);

      final firstOwned = emittedControllers.single;
      firstOwned.setVisibleRange(0.4, 0.5);

      await tester.pumpWidget(
        _zoomableHost(
          zoomConstraints: const ZoomConstraints(minWindowFraction: 0.3),
          onDoubleTap: (_, zoom) => emittedControllers.add(zoom),
        ),
      );
      await tester.pumpAndSettle();

      expect(firstOwned.isDisposed, isTrue);

      await _doubleTapInteractionLayer(tester);

      final secondOwned = emittedControllers.last;
      expect(secondOwned, isNot(same(firstOwned)));
      expect(secondOwned.constraints.minWindowFraction, 0.3);
      expect(secondOwned.value.windowSize, greaterThanOrEqualTo(0.3));
      expect(tester.takeException(), isNull);
    });
  });

  group('ChartDrillDownController', () {
    test(
      'push/pop/popTo/replace/popAll keeps stack and breadcrumbs correct',
      () {
        final root = DrillDownLevel(
          id: 'root',
          label: 'Root',
          config: _indicator('root', 1),
        );
        final ctrl = ChartDrillDownController(root: root);

        expect(ctrl.depth, 0);
        expect(ctrl.canPop, isFalse);
        expect(ctrl.breadcrumbs, ['Root']);

        ctrl.push(
          DrillDownLevel(
            id: 'childA',
            label: 'Child A',
            config: _indicator('child-a', 2),
            parentXStart: 0.2,
            parentXEnd: 0.4,
          ),
        );
        expect(ctrl.depth, 1);
        expect(ctrl.canPop, isTrue);
        expect(ctrl.breadcrumbs, ['Root', 'Child A']);
        expect(ctrl.currentXRange, (0.2, 0.4));

        ctrl.push(
          DrillDownLevel(
            id: 'childB',
            label: 'Child B',
            buildConfig: (_) => _indicator('child-b', 3),
          ),
        );
        expect(ctrl.depth, 2);
        expect(ctrl.breadcrumbs, ['Root', 'Child A', 'Child B']);

        ctrl.replace(
          DrillDownLevel(
            id: 'childB2',
            label: 'Child B2',
            config: _indicator('child-b2', 4),
          ),
        );
        expect(ctrl.currentLevel.id, 'childB2');
        expect(ctrl.breadcrumbs, ['Root', 'Child A', 'Child B2']);

        ctrl.popTo('childA');
        expect(ctrl.depth, 1);
        expect(ctrl.currentLevel.id, 'childA');

        ctrl.pop();
        expect(ctrl.depth, 0);
        expect(ctrl.currentLevel.id, 'root');

        ctrl.push(
          DrillDownLevel(
            id: 'childC',
            label: 'Child C',
            config: _indicator('child-c', 5),
          ),
        );
        expect(ctrl.depth, 1);
        ctrl.popAll();
        expect(ctrl.depth, 0);
        expect(ctrl.currentLevel.id, 'root');
        expect(ctrl.breadcrumbs, ['Root']);
      },
    );

    test('root and current-level no-op navigation does not notify', () {
      final root = DrillDownLevel(
        id: 'root',
        label: 'Root',
        config: _indicator('root', 1),
      );
      final child = DrillDownLevel(
        id: 'child',
        label: 'Child',
        config: _indicator('child', 2),
      );
      final ctrl = ChartDrillDownController(root: root);
      var notificationCount = 0;
      ctrl.addListener(() => notificationCount++);

      ctrl.pop();
      ctrl.popAll();
      ctrl.popTo('root');
      ctrl.popTo('missing');

      expect(notificationCount, 0);
      expect(ctrl.currentLevel.id, 'root');

      ctrl.push(child);
      expect(notificationCount, 1);

      ctrl.popTo('child');
      expect(notificationCount, 1);
      expect(ctrl.currentLevel.id, 'child');

      ctrl.dispose();
    });

    test('current x-range normalizes reversed and non-finite level input', () {
      final root = DrillDownLevel(
        id: 'root',
        label: 'Root',
        config: _indicator('root', 1),
        parentXStart: double.nan,
        parentXEnd: 0.4,
      );
      final ctrl = ChartDrillDownController(root: root);

      expect(root.parentXRange, (0.0, 0.4));
      expect(ctrl.currentXRange, (0.0, 0.4));

      ctrl.push(
        DrillDownLevel(
          id: 'child',
          label: 'Child',
          config: _indicator('child', 2),
          parentXStart: 1.2,
          parentXEnd: -0.3,
        ),
      );

      expect(ctrl.currentXRange, (0.0, 1.0));

      ctrl.replace(
        DrillDownLevel(
          id: 'child2',
          label: 'Child 2',
          config: _indicator('child2', 3),
          parentXStart: 0.8,
          parentXEnd: double.infinity,
        ),
      );

      expect(ctrl.currentXRange, (0.8, 1.0));
      ctrl.dispose();
    });

    test('disposed controller ignores late navigation safely', () {
      final root = DrillDownLevel(
        id: 'root',
        label: 'Root',
        config: _indicator('root', 1),
      );
      final child = DrillDownLevel(
        id: 'child',
        label: 'Child',
        config: _indicator('child', 2),
      );
      final late = DrillDownLevel(
        id: 'late',
        label: 'Late',
        config: _indicator('late', 3),
      );
      final ctrl = ChartDrillDownController(root: root);
      ctrl.push(child);
      final before = ctrl.value;

      ctrl.dispose();

      expect(ctrl.isDisposed, isTrue);
      expect(() {
        ctrl.value = DrillDownState(stack: [root, late]);
        ctrl.push(late);
        ctrl.pop();
        ctrl.popAll();
        ctrl.popTo('root');
        ctrl.replace(late);
        ctrl.dispose();
      }, returnsNormally);
      expect(ctrl.value, same(before));
      expect(ctrl.currentLevel.id, 'child');
    });

    test('level metadata is an immutable snapshot', () {
      final metadata = {
        'category': 'A',
        'value': 42,
        'nested': {
          'tags': ['alpha'],
        },
      };
      final level = DrillDownLevel(
        id: 'child',
        label: 'Child',
        config: _indicator('child', 1),
        metadata: metadata,
      );

      metadata['category'] = 'B';
      metadata['extra'] = true;
      ((metadata['nested'] as Map)['tags'] as List).add('source-mutated');

      expect(level.metadata, {
        'category': 'A',
        'value': 42,
        'nested': {
          'tags': ['alpha'],
        },
      });
      expect(
        () => level.metadata['category'] = 'C',
        throwsA(isA<UnsupportedError>()),
      );

      final snapshot = level.metadata;
      ((snapshot['nested'] as Map)['tags'] as List).add('snapshot-mutated');
      expect(level.metadata, {
        'category': 'A',
        'value': 42,
        'nested': {
          'tags': ['alpha'],
        },
      });
    });

    test('drilldown state exposes an immutable stack snapshot', () {
      final root = DrillDownLevel(
        id: 'root',
        label: 'Root',
        config: _indicator('root', 1),
      );
      final child = DrillDownLevel(
        id: 'child',
        label: 'Child',
        config: _indicator('child', 2),
      );
      final sourceStack = [root];
      final state = DrillDownState(stack: sourceStack);

      sourceStack.add(child);

      expect(state.stack, [root]);
      expect(() => state.stack.add(child), throwsA(isA<UnsupportedError>()));
    });

    testWidgets('DrillDownChartView emits level changes once outside build', (
      tester,
    ) async {
      final root = DrillDownLevel(
        id: 'root',
        label: 'Root',
        config: _indicator('root', 1),
      );
      final child = DrillDownLevel(
        id: 'child',
        label: 'Child',
        config: _indicator('child', 2),
      );
      final ctrl = ChartDrillDownController(root: root);
      final emitted = <String>[];

      void onLevelChanged(DrillDownLevel level) {
        emitted.add(level.id);
      }

      Widget buildView() {
        return MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: DrillDownChartView(
              controller: ctrl,
              onLevelChanged: onLevelChanged,
              builder: (_) => const Text('chart'),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildView());
      await tester.pump();
      expect(emitted, ['root']);

      await tester.pumpWidget(buildView());
      await tester.pump();
      expect(emitted, ['root']);

      ctrl.push(child);
      await tester.pump();
      expect(emitted, ['root', 'child']);

      await tester.pump();
      expect(emitted, ['root', 'child']);

      ctrl.pop();
      await tester.pump();
      expect(emitted, ['root', 'child', 'root']);

      await tester.pumpWidget(const SizedBox.shrink());
      ctrl.dispose();
    });
  });

  group('ChartZoomState and ChartZoomController', () {
    test('zoom history, pop, pan clamping, and min window are applied', () {
      final z = ChartZoomState(minWindowFraction: 0.2);
      final z1 = z.zoomToRange(0.2, 0.6, label: 'Q2');
      expect(z1.canPop, isTrue);
      expect(z1.depth, 1);
      expect(z1.breadcrumbs, ['Q2']);
      expect(z1.xStart, closeTo(0.2, 1e-9));
      expect(z1.xEnd, closeTo(0.6, 1e-9));

      final z2 = z1.panBy(1.0);
      expect(z2.xStart, closeTo(0.6, 1e-9));
      expect(z2.xEnd, closeTo(1.0, 1e-9));

      final z3 = z.zoomAroundFraction(0.5, 1000);
      expect(z3.windowSize, greaterThanOrEqualTo(0.2));

      final z4 = z1.pop();
      expect(z4.isIdentity, isTrue);
      expect(z4.depth, 0);
    });

    test('drilldown metadata is an immutable snapshot', () {
      final metadata = {
        'id': 'q2',
        'value': 12,
        'nested': {
          'segments': ['direct'],
        },
      };
      final state = ChartZoomState.identity.drillDown(
        0.2,
        0.4,
        label: 'Q2',
        metadata: metadata,
      );

      metadata['value'] = 99;
      metadata['late'] = true;
      ((metadata['nested'] as Map)['segments'] as List).add('source-mutated');

      expect(state.currentMetadata, {
        'id': 'q2',
        'value': 12,
        'nested': {
          'segments': ['direct'],
        },
      });
      expect(
        () => state.currentMetadata['value'] = 13,
        throwsA(isA<UnsupportedError>()),
      );

      final snapshot = state.currentMetadata;
      ((snapshot['nested'] as Map)['segments'] as List).add('snapshot-mutated');
      expect(state.currentMetadata, {
        'id': 'q2',
        'value': 12,
        'nested': {
          'segments': ['direct'],
        },
      });
      expect(state.pop().currentMetadata, isEmpty);
    });

    test('state equality uses deep metadata values', () {
      final a = ChartZoomState.identity.drillDown(
        0.2,
        0.4,
        label: 'Q2',
        metadata: {
          'id': 'q2',
          'nested': {
            'segments': ['direct'],
          },
        },
      );
      final b = ChartZoomState.identity.drillDown(
        0.2,
        0.4,
        label: 'Q2',
        metadata: {
          'nested': {
            'segments': ['direct'],
          },
          'id': 'q2',
        },
      );
      final changed = ChartZoomState.identity.drillDown(
        0.2,
        0.4,
        label: 'Q2',
        metadata: {
          'id': 'q2',
          'nested': {
            'segments': ['other'],
          },
        },
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(changed));
    });

    test('gesture entry points respect constraints and clamp zoom', () {
      final ctrl = ChartZoomController(
        constraints: const ZoomConstraints(
          minWindowFraction: 0.2,
          enablePan: false,
          enableDoubleTapZoom: false,
        ),
      );

      final before = ctrl.value;
      ctrl.pan(0.1);
      expect(ctrl.value, equals(before));

      ctrl.onPanDelta(20, 200);
      expect(ctrl.value, equals(before));

      ctrl.onDoubleTap(100, 200);
      expect(ctrl.value, equals(before));

      ctrl.zoomToRange(0.49, 0.51, label: 'Tiny');
      expect(ctrl.value.windowSize, closeTo(0.2, 1e-9));
    });

    test('scroll zoom and fling momentum update state', () {
      final ctrl = ChartZoomController();
      expect(ctrl.value.windowSize, 1.0);

      ctrl.onScrollWheel(-10, 50, 100); // zoom in
      expect(ctrl.value.windowSize, lessThan(1.0));

      ctrl.zoomToRange(0.2, 0.8, label: 'Mid');
      ctrl.onFlingStart(800, 400);
      expect(ctrl.hasMomentum, isTrue);
      final beforeStart = ctrl.value.xStart;
      final beforeVelocity = ctrl.value.velocityX.abs();
      ctrl.advanceFling();
      expect(ctrl.value.xStart, lessThan(beforeStart));
      expect(ctrl.value.velocityX.abs(), lessThan(beforeVelocity));
    });

    test('fling friction is sanitized to avoid non-finite momentum', () {
      final invalid = ChartZoomState(
        xStart: 0.2,
        xEnd: 0.8,
        velocityX: 0.05,
      ).advanceFling(friction: double.nan);

      expect(invalid.velocityX, 0);
      expect(invalid.hasMomentum, isFalse);
      expect(invalid.xStart, closeTo(0.25, 1e-9));
      expect(invalid.xEnd, closeTo(0.85, 1e-9));

      final accelerating = ChartZoomState(
        xStart: 0.2,
        xEnd: 0.8,
        velocityX: 0.05,
      ).advanceFling(friction: 5);

      expect(accelerating.velocityX, greaterThan(0));
      expect(accelerating.velocityX, lessThan(0.05));
    });

    test('normalizes reversed and non-finite zoom inputs', () {
      final reversed = ChartZoomState(
        xStart: 0.8,
        xEnd: 0.2,
        velocityX: double.infinity,
      );
      expect(reversed.xStart, closeTo(0.2, 1e-9));
      expect(reversed.xEnd, closeTo(0.8, 1e-9));
      expect(reversed.velocityX, 0);

      final z = ChartZoomState(minWindowFraction: 0.1);
      final zoomed = z.zoomToRange(0.9, 0.1, label: 'Reverse');
      expect(zoomed.xStart, closeTo(0.1, 1e-9));
      expect(zoomed.xEnd, closeTo(0.9, 1e-9));

      final drilled = z.drillDown(0.7, 0.2, label: 'Reverse Drilldown');
      expect(drilled.xStart, closeTo(0.2, 1e-9));
      expect(drilled.xEnd, closeTo(0.7, 1e-9));

      expect(z.zoomAroundFraction(double.nan, 2), same(z));
      expect(z.zoomAroundFraction(0.5, 0), same(z));
    });

    test(
      'controller ignores invalid canvas inputs and enforces max window',
      () {
        final ctrl = ChartZoomController(
          constraints: const ZoomConstraints(maxWindowFraction: 0.5),
        );
        expect(ctrl.value.windowSize, closeTo(0.5, 1e-9));

        final before = ctrl.value;
        ctrl.onPanDelta(20, 0);
        ctrl.onFlingStart(800, 0);
        ctrl.onDoubleTap(100, 0);
        ctrl.onScaleUpdate(100, 0, 2);
        ctrl.onScrollWheel(-10, 100, 0);
        ctrl.onScrollWheel(double.nan, 100, 200);
        ctrl.onScrollWheel(-10, double.infinity, 200);
        expect(ctrl.value, equals(before));
        expect(ctrl.hasMomentum, isFalse);

        ctrl.zoomIn(0.5, factor: 10);
        expect(ctrl.value.windowSize, lessThan(0.5));
        ctrl.zoomOut(factor: 100);
        expect(ctrl.value.windowSize, closeTo(0.5, 1e-9));
      },
    );

    test(
      'controller keeps state aligned with constraints on every entrypoint',
      () {
        final ctrl = ChartZoomController(
          constraints: const ZoomConstraints(
            minWindowFraction: 0.2,
            maxWindowFraction: 0.6,
          ),
        );

        expect(ctrl.value.minWindowFraction, closeTo(0.2, 1e-9));
        expect(ctrl.value.windowSize, closeTo(0.6, 1e-9));
        expect(ctrl.value.xStart, closeTo(0.2, 1e-9));
        expect(ctrl.value.xEnd, closeTo(0.8, 1e-9));

        ctrl.value = ChartZoomState(
          xStart: -10,
          xEnd: 10,
          velocityX: 0.02,
          minWindowFraction: 0.01,
        );
        expect(ctrl.value.minWindowFraction, closeTo(0.2, 1e-9));
        expect(ctrl.value.windowSize, closeTo(0.6, 1e-9));
        expect(ctrl.value.velocityX, closeTo(0.02, 1e-9));

        ctrl.zoomToRange(0.45, 0.46, label: 'Tiny');
        expect(ctrl.value.windowSize, closeTo(0.2, 1e-9));

        ctrl.reset();
        expect(ctrl.value.windowSize, closeTo(0.6, 1e-9));
        expect(ctrl.value.minWindowFraction, closeTo(0.2, 1e-9));

        ctrl.zoomToRange(0.3, 0.5, label: 'Child');
        expect(ctrl.canPop, isTrue);
        ctrl.pop();
        expect(ctrl.canPop, isFalse);
        expect(ctrl.value.windowSize, closeTo(0.6, 1e-9));

        ctrl.dispose();
      },
    );

    test('setVisibleRange syncs without adding zoom history', () {
      final ctrl = ChartZoomController(
        constraints: const ZoomConstraints(minWindowFraction: 0.2),
      );

      ctrl.setVisibleRange(0.4, 0.45);

      expect(ctrl.canPop, isFalse);
      expect(ctrl.value.windowSize, closeTo(0.2, 1e-9));
      expect(ctrl.value.xStart, closeTo(0.325, 1e-9));
      expect(ctrl.value.xEnd, closeTo(0.525, 1e-9));
    });

    test('same-window zoom operations do not notify or push history', () {
      final ctrl = ChartZoomController(
        initial: ChartZoomState(xStart: 0.2, xEnd: 0.8),
      );
      var notificationCount = 0;
      ctrl.addListener(() => notificationCount++);

      ctrl.value = ChartZoomState(xStart: 0.2, xEnd: 0.8, velocityX: 0.05);
      expect(notificationCount, 1);

      ctrl.pan(0);
      expect(notificationCount, 2);
      expect(ctrl.value.velocityX, 0);
      final stable = ctrl.value;

      ctrl.pan(0);
      ctrl.setVisibleRange(0.2, 0.8);
      ctrl.zoomToRange(0.2, 0.8, label: 'Same');
      expect(notificationCount, 2);
      expect(ctrl.value, stable);
      expect(ctrl.canPop, isFalse);

      ctrl.zoomToRange(0.3, 0.7, label: 'Changed');
      expect(notificationCount, 3);
      expect(ctrl.canPop, isTrue);

      ctrl.setVisibleRange(0.3, 0.7);
      expect(notificationCount, 3);

      ctrl.dispose();
    });

    test('disposed zoom controller ignores late mutations safely', () {
      final ctrl = ChartZoomController();
      ctrl.zoomToRange(0.2, 0.8, label: 'Mid');
      ctrl.onFlingStart(500, 200);
      final before = ctrl.value;

      expect(ctrl.hasMomentum, isTrue);

      ctrl.dispose();

      expect(ctrl.isDisposed, isTrue);
      expect(ctrl.hasMomentum, isFalse);
      expect(() {
        ctrl.value = ChartZoomState(xStart: 0.0, xEnd: 0.1);
        ctrl.zoomIn(0.5, factor: 2);
        ctrl.zoomOut(factor: 2);
        ctrl.pan(0.1);
        ctrl.reset();
        ctrl.onScaleUpdate(50, 100, 2);
        ctrl.onPanDelta(20, 100);
        ctrl.onDoubleTap(50, 100);
        ctrl.onFlingStart(800, 300);
        ctrl.advanceFling();
        ctrl.onScrollWheel(-10, 50, 100);
        ctrl.drillDown(0.2, 0.4, label: 'Late');
        ctrl.pop();
        ctrl.popAll();
        ctrl.zoomToRange(0.1, 0.2, label: 'Late');
        ctrl.setVisibleRange(0.3, 0.5);
        ctrl.zoomToIndexRange(2, 4, 10);
        ctrl.dispose();
      }, returnsNormally);
      expect(ctrl.value, before);
    });

    test('constraints parse JSON-like values without type casts', () {
      final constraints = ZoomConstraints.fromJson({
        'minWindowFraction': '0.1',
        'maxWindowFraction': '0.7',
        'minVisiblePoints': '9',
        'enablePinchZoom': 'false',
        'enableScrollZoom': 'yes',
        'enableDoubleTapZoom': 0,
        'enablePan': 1,
        'doubleTapZoomFactor': '3.5',
        'enableFling': 'no',
        'flingFriction': '0.75',
      });

      expect(constraints.minWindowFraction, 0.1);
      expect(constraints.maxWindowFraction, 0.7);
      expect(constraints.minVisiblePoints, 9);
      expect(constraints.enablePinchZoom, isFalse);
      expect(constraints.enableScrollZoom, isTrue);
      expect(constraints.enableDoubleTapZoom, isFalse);
      expect(constraints.enablePan, isTrue);
      expect(constraints.doubleTapZoomFactor, 3.5);
      expect(constraints.enableFling, isFalse);
      expect(constraints.flingFriction, 0.75);
    });

    test(
      'state visible count and canvas conversions tolerate invalid input',
      () {
        const state = ChartZoomState.identity;

        expect(state.fractionToIndex(double.nan, 10), 0);
        expect(state.fractionToIndex(double.infinity, 10), 0);
        expect(state.fractionToIndex(-10, 10), 0);
        expect(state.fractionToIndex(10, 10), 9);
        expect(state.visibleCount(0), 0);
        expect(state.canvasToFraction(double.nan, 100), 0);
        expect(state.canvasToFraction(50, double.infinity), 0);
        expect(state.fractionToCanvas(double.nan, 100), 0);
        expect(state.fractionToCanvas(0.5, double.infinity), 0);
      },
    );
  });

  group('ChartController lifecycle', () {
    test('batchUpdate coalesces listener notifications', () async {
      final ctrl = ChartController();
      var notificationCount = 0;
      ctrl.addListener(() => notificationCount++);

      const selection = ChartSelection(seriesIndex: 1, dataIndex: 3, value: 7);
      final selectionEmitted = expectLater(
        ctrl.onSelectionChanged,
        emits(selection),
      );

      ctrl.batchUpdate(() {
        expect(ctrl.isBatchingNotifications, isTrue);
        ctrl.zoomTo(start: 2, end: 9, factor: 2);
        ctrl.pan(4);
        ctrl.setFilter('region', 'A');
        ctrl.selectIndex(
          selection.dataIndex,
          seriesIndex: selection.seriesIndex,
          value: selection.value,
        );
        expect(notificationCount, 0);
      });

      await selectionEmitted;
      expect(ctrl.isBatchingNotifications, isFalse);
      expect(notificationCount, 1);
      expect(ctrl.zoom, const ZoomRange(start: 2, end: 9, factor: 2));
      expect(ctrl.panOffset, 4);
      expect(ctrl.filters, {'region': 'A'});
      expect(ctrl.selection, selection);

      ctrl.dispose();
    });

    test('nested batchUpdate flushes once after the outer batch', () {
      final ctrl = ChartController();
      var notificationCount = 0;
      ctrl.addListener(() => notificationCount++);

      ctrl.batchUpdate(() {
        ctrl.pan(1);
        ctrl.batchUpdate(() {
          ctrl.pan(2);
          ctrl.setFilter('mode', 'nested');
        });
        expect(notificationCount, 0);
        expect(ctrl.isBatchingNotifications, isTrue);
      });

      expect(ctrl.isBatchingNotifications, isFalse);
      expect(notificationCount, 1);
      expect(ctrl.panOffset, 3);
      expect(ctrl.filters, {'mode': 'nested'});

      ctrl.dispose();
    });

    test('sanitizes invalid zoom, pan, animation, and y-range input', () async {
      final ctrl = ChartController();
      final zoomCallbacks = <(double start, double end)>[];
      ctrl.onZoomChanged = (start, end) => zoomCallbacks.add((start, end));

      ctrl.zoomTo(start: 8, end: 2, factor: double.nan);
      expect(ctrl.zoom, const ZoomRange(start: 2, end: 8, factor: 1));
      expect(zoomCallbacks.last, (2.0, 8.0));

      ctrl.syncViewport(
        const ZoomRange(start: -3, end: 1, factor: double.infinity),
        double.nan,
      );
      expect(ctrl.zoom, const ZoomRange(start: 0, end: 1, factor: 1));
      expect(ctrl.panOffset, 0);

      ctrl.pan(5);
      ctrl.pan(double.infinity);
      ctrl.pan(double.nan);
      expect(ctrl.panOffset, 5);

      ctrl.setYRange(20, 10);
      expect(ctrl.yMin, 10);
      expect(ctrl.yMax, 20);

      ctrl.setYRange(double.nan, 100);
      ctrl.setYRange(3, 3);
      expect(ctrl.yMin, 10);
      expect(ctrl.yMax, 20);

      final beforeInvalidAnimation = ctrl.zoom;
      await ctrl.animateToRange(double.nan, 0.5);
      await ctrl.animateToRange(0.25, double.infinity);
      expect(ctrl.zoom, beforeInvalidAnimation);

      await ctrl.animateToRange(0.9, 0.1);
      expect(ctrl.zoom, const ZoomRange(start: 10, end: 89, factor: 1));

      ctrl.dispose();
    });

    test('normalizes visible index ranges for chart viewport consumers', () {
      expect(ZoomRange.full.visibleIndexRange(0), ChartIndexRange.empty);
      expect(
        ZoomRange.full.visibleIndexRange(1),
        const ChartIndexRange(start: 0, end: 0),
      );
      expect(
        ZoomRange.full.visibleIndexRange(5),
        const ChartIndexRange(start: 0, end: 4),
      );

      expect(
        const ZoomRange(
          start: -10,
          end: 99,
          factor: double.nan,
        ).visibleIndexRange(5),
        const ChartIndexRange(start: 0, end: 4),
      );
      expect(
        const ZoomRange(start: 8, end: 2, factor: 2).visibleIndexRange(10),
        const ChartIndexRange(start: 2, end: 8),
      );
      expect(
        const ZoomRange(start: 3, end: -1, factor: 4).visibleIndexRange(10),
        const ChartIndexRange(start: 3, end: 9),
      );

      final empty = const ChartIndexRange(start: 3, end: 2);
      expect(empty.isEmpty, isTrue);
      expect(empty.count, 0);
      expect(const ChartIndexRange(start: 2, end: 4).count, 3);
    });

    test('viewport, y-range, and selection no-op updates do not notify', () {
      final ctrl = ChartController();
      var notificationCount = 0;
      var zoomCallbackCount = 0;
      ctrl
        ..addListener(() => notificationCount++)
        ..onZoomChanged = (_, _) => zoomCallbackCount++;

      ctrl.clearSelection();
      ctrl.resetZoom();
      ctrl.pan(0);
      ctrl.syncViewport(ZoomRange.full, 0);
      ctrl.zoomTo();
      ctrl.clearYRange();
      expect(notificationCount, 0);
      expect(zoomCallbackCount, 0);

      ctrl.zoomTo(start: 2, end: 8, factor: 2);
      ctrl.zoomTo(start: 2, end: 8, factor: 2);
      expect(notificationCount, 1);
      expect(zoomCallbackCount, 1);

      ctrl.syncViewport(const ZoomRange(start: 2, end: 8, factor: 2), 0);
      expect(notificationCount, 1);

      ctrl.syncViewport(const ZoomRange(start: 2, end: 8, factor: 2), 3);
      ctrl.syncViewport(const ZoomRange(start: 2, end: 8, factor: 2), 3);
      expect(notificationCount, 2);

      ctrl.pan(0);
      ctrl.pan(2);
      expect(notificationCount, 3);
      expect(ctrl.panOffset, 5);

      ctrl.setYRange(10, 20);
      ctrl.setYRange(10, 20);
      ctrl.setYRange(20, 10);
      expect(notificationCount, 4);

      ctrl.clearYRange();
      ctrl.clearYRange();
      expect(notificationCount, 5);

      ctrl.resetZoom();
      ctrl.resetZoom();
      expect(notificationCount, 6);
      expect(ctrl.zoom, ZoomRange.full);
      expect(ctrl.panOffset, 0);

      ctrl.dispose();
    });

    test('filter state snapshots nested JSON-like values', () {
      final ctrl = ChartController();
      final filter = {
        'range': [1, 2],
        'meta': {'region': 'A'},
      };

      ctrl.setFilter('scope', filter);
      (filter['range'] as List).clear();
      (filter['meta'] as Map)['region'] = 'B';

      expect(ctrl.filters, {
        'scope': {
          'range': [1, 2],
          'meta': {'region': 'A'},
        },
      });

      final snapshot = ctrl.filters;
      (((snapshot['scope'] as Map)['range']) as List).add(3);
      (((snapshot['scope'] as Map)['meta']) as Map)['region'] = 'C';

      expect(ctrl.filters, {
        'scope': {
          'range': [1, 2],
          'meta': {'region': 'A'},
        },
      });

      ctrl.dispose();
    });

    test('selection compares and hashes structured values by content', () {
      final left = ChartSelection(
        seriesIndex: 1,
        dataIndex: 2,
        value: {
          'label': 'North',
          'values': [1, 2],
        },
      );
      final right = ChartSelection(
        seriesIndex: 1,
        dataIndex: 2,
        value: {
          'values': [1, 2],
          'label': 'North',
        },
      );
      final changed = ChartSelection(
        seriesIndex: 1,
        dataIndex: 2,
        value: {
          'label': 'North',
          'values': [1, 3],
        },
      );

      expect(left, right);
      expect(left.hashCode, right.hashCode);
      expect(left, isNot(changed));
    });

    test('selection state snapshots nested JSON-like values', () {
      final ctrl = ChartController();
      final value = {
        'label': 'North',
        'values': [1, 2],
      };

      ctrl.selectIndex(4, seriesIndex: 1, value: value);
      (value['values'] as List).add(3);
      value['label'] = 'South';

      expect(
        ctrl.selection,
        ChartSelection(
          seriesIndex: 1,
          dataIndex: 4,
          value: {
            'label': 'North',
            'values': [1, 2],
          },
        ),
      );

      ctrl.dispose();
    });

    test('syncSelection suppresses structurally equal selection updates', () {
      final ctrl = ChartController();
      var notificationCount = 0;
      ctrl.addListener(() => notificationCount++);

      ctrl.syncSelection(
        ChartSelection(
          seriesIndex: 1,
          dataIndex: 2,
          value: {
            'label': 'North',
            'values': [1, 2],
          },
        ),
      );
      ctrl.syncSelection(
        ChartSelection(
          seriesIndex: 1,
          dataIndex: 2,
          value: {
            'values': [1, 2],
            'label': 'North',
          },
        ),
      );

      expect(notificationCount, 1);
      expect(
        ctrl.selection,
        ChartSelection(
          seriesIndex: 1,
          dataIndex: 2,
          value: {
            'label': 'North',
            'values': [1, 2],
          },
        ),
      );

      ctrl.dispose();
    });

    test('legend and filter no-op updates do not notify listeners', () {
      final ctrl = ChartController();
      var notificationCount = 0;
      ctrl.addListener(() => notificationCount++);

      ctrl.highlightSeries(1);
      ctrl.highlightSeries(1);
      ctrl.unhighlightSeries(2);
      expect(notificationCount, 1);
      expect(ctrl.highlightedSeries, {1});

      ctrl.unhighlightSeries(1);
      expect(notificationCount, 2);
      expect(ctrl.highlightedSeries, isEmpty);

      ctrl.setFilter('scope', {
        'range': [1, 2],
      });
      ctrl.setFilter('scope', {
        'range': [1, 2],
      });
      ctrl.removeFilter('missing');
      expect(notificationCount, 3);

      ctrl.setFilter('nullable', null);
      ctrl.removeFilter('nullable');
      expect(notificationCount, 5);

      ctrl.clearFilters();
      ctrl.clearFilters();
      expect(notificationCount, 6);

      ctrl.dispose();
    });

    test(
      'sync helpers copy series and filter state without duplicate work',
      () {
        final ctrl = ChartController();
        var notificationCount = 0;
        ctrl.addListener(() => notificationCount++);

        ctrl.syncSeriesState(highlightedSeries: {1, 3}, hiddenSeries: {2});
        expect(notificationCount, 1);
        expect(ctrl.highlightedSeries, {1, 3});
        expect(ctrl.hiddenSeries, {2});

        ctrl.syncSeriesState(highlightedSeries: {1, 3}, hiddenSeries: {2});
        expect(notificationCount, 1);

        final filters = {
          'region': 'A',
          'meta': {
            'tags': ['north'],
          },
        };
        ctrl.syncFilters(filters);
        expect(notificationCount, 2);
        filters['region'] = 'B';
        ((filters['meta'] as Map)['tags'] as List).add('mutated');
        expect(ctrl.filters, {
          'region': 'A',
          'meta': {
            'tags': ['north'],
          },
        });

        ctrl.syncFilters({
          'meta': {
            'tags': ['north'],
          },
          'region': 'A',
        });
        expect(notificationCount, 2);

        ctrl.dispose();
      },
    );

    test('disposed controller ignores late mutations safely', () async {
      final ctrl = ChartController();
      var tapCount = 0;
      var zoomCount = 0;
      ctrl.onDataPointTap = (_, _, _) => tapCount++;
      ctrl.onZoomChanged = (_, _) => zoomCount++;

      ctrl.selectIndex(1, seriesIndex: 2, value: 3);
      ctrl.zoomTo(start: 4, end: 8, factor: 2);
      ctrl.pan(5);
      ctrl.highlightSeries(1);
      ctrl.toggleSeriesVisibility(2);
      ctrl.setYRange(10, 20);
      ctrl.incrementDataVersion();
      ctrl.replay();
      ctrl.setFilter('region', 'A');

      final selection = ctrl.selection;
      final zoom = ctrl.zoom;
      final panOffset = ctrl.panOffset;
      final dataVersion = ctrl.dataVersion;
      final animationTrigger = ctrl.animationTrigger;
      final exportDone = expectLater(ctrl.onExportRequested, emitsDone);

      ctrl.dispose();
      await exportDone;

      expect(ctrl.isDisposed, isTrue);
      expect(() {
        ctrl.selectIndex(9, seriesIndex: 9, value: 9);
        ctrl.syncSelection(
          const ChartSelection(seriesIndex: 9, dataIndex: 9, value: 9),
        );
        ctrl.clearSelection();
        ctrl.highlightSeries(9);
        ctrl.unhighlightSeries(1);
        ctrl.toggleSeriesHighlight(3);
        ctrl.toggleSeriesVisibility(2);
        ctrl.syncViewport(const ZoomRange(start: 9, end: 10, factor: 3), 9);
        ctrl.zoomTo(start: 9, end: 10, factor: 3);
        ctrl.resetZoom();
        ctrl.pan(9);
        ctrl.setYRange(30, 40);
        ctrl.clearYRange();
        ctrl.incrementDataVersion();
        ctrl.updateData(const []);
        ctrl.replay();
        ctrl.setFilter('region', 'B');
        ctrl.removeFilter('region');
        ctrl.clearFilters();
        ctrl.requestExport();
      }, returnsNormally);

      expect(ctrl.selection, selection);
      expect(ctrl.zoom, zoom);
      expect(ctrl.panOffset, panOffset);
      expect(ctrl.highlightedSeries, contains(1));
      expect(ctrl.hiddenSeries, contains(2));
      expect(ctrl.yMin, 10);
      expect(ctrl.yMax, 20);
      expect(ctrl.dataVersion, dataVersion);
      expect(ctrl.animationTrigger, animationTrigger);
      expect(ctrl.filters, {'region': 'A'});
      expect(tapCount, 1);
      expect(zoomCount, 1);
    });
  });

  group('ChartSyncGroup', () {
    test('propagates zoom/selection and stops after removal', () {
      final group = ChartSyncGroup();
      final a = group.add(ChartController());
      final b = group.add(ChartController());
      var aTapCount = 0;
      var bTapCount = 0;

      a.onDataPointTap = (_, _, _) => aTapCount++;
      b.onDataPointTap = (_, _, _) => bTapCount++;

      a.zoomTo(start: 10, end: 40, factor: 2);
      expect(b.zoom.start, 10);
      expect(b.zoom.end, 40);
      expect(b.zoom.factor, 2);

      a.pan(5);
      expect(b.panOffset, 5);

      a.selectIndex(7, seriesIndex: 1, value: 123.0);
      expect(
        b.selection,
        const ChartSelection(seriesIndex: 1, dataIndex: 7, value: 123.0),
      );
      expect(aTapCount, 1);
      expect(bTapCount, 0);

      group.remove(b);

      a.zoomTo(start: 20, end: 60, factor: 3);
      expect(b.zoom.start, 10);
      expect(b.zoom.end, 40);
      expect(b.zoom.factor, 2);

      a.clearSelection();
      expect(b.selection, isNotNull);

      group.dispose();
      a.dispose();
      b.dispose();
    });

    test('batches peer notifications while syncing viewport and selection', () {
      final group = ChartSyncGroup();
      final a = group.add(ChartController());
      final b = group.add(ChartController());
      var bNotificationCount = 0;
      b.addListener(() => bNotificationCount++);

      a.batchUpdate(() {
        a.zoomTo(start: 12, end: 30, factor: 2);
        a.pan(6);
        a.selectIndex(5, seriesIndex: 1, value: 55);
        a.highlightSeries(2);
        a.toggleSeriesVisibility(3);
        a.setFilter('region', {
          'name': 'North',
          'ids': [1, 2],
        });
      });

      expect(bNotificationCount, 1);
      expect(b.zoom, const ZoomRange(start: 12, end: 30, factor: 2));
      expect(b.panOffset, 6);
      expect(
        b.selection,
        const ChartSelection(seriesIndex: 1, dataIndex: 5, value: 55),
      );
      expect(b.highlightedSeries, {2});
      expect(b.hiddenSeries, {3});
      expect(b.filters, {
        'region': {
          'name': 'North',
          'ids': [1, 2],
        },
      });

      a.batchUpdate(() {
        a.unhighlightSeries(2);
        a.toggleSeriesVisibility(3);
        a.clearFilters();
      });

      expect(bNotificationCount, 2);
      expect(b.highlightedSeries, isEmpty);
      expect(b.hiddenSeries, isEmpty);
      expect(b.filters, isEmpty);

      group.dispose();
      a.dispose();
      b.dispose();
    });

    test('detaches disposed peers during propagation', () {
      final group = ChartSyncGroup();
      final a = group.add(ChartController());
      final b = group.add(ChartController());

      expect(group.controllerCount, 2);

      b.dispose();
      a.zoomTo(start: 4, end: 12, factor: 2);

      expect(group.controllerCount, 1);
      expect(a.zoom, const ZoomRange(start: 4, end: 12, factor: 2));

      group.dispose();
      a.dispose();
    });

    test('dispose is idempotent and add/remove after dispose are no-ops', () {
      final group = ChartSyncGroup();
      final a = group.add(ChartController());
      final b = ChartController();
      final c = ChartController();

      expect(group.controllerCount, 1);

      group.dispose();
      group.dispose();

      expect(group.isDisposed, isTrue);
      expect(group.controllerCount, 0);
      expect(() {
        group.remove(a);
        group.add(b);
        group.add(c);
        b.zoomTo(start: 3, end: 6, factor: 2);
      }, returnsNormally);
      expect(c.zoom, ZoomRange.full);
      expect(group.controllerCount, 0);

      a.dispose();
      b.dispose();
      c.dispose();
    });

    test('syncSelection emits state changes without tap callbacks', () async {
      final ctrl = ChartController();
      var tapCount = 0;
      ctrl.onDataPointTap = (_, _, _) => tapCount++;
      const selection = ChartSelection(seriesIndex: 2, dataIndex: 4, value: 42);
      final emitted = expectLater(ctrl.onSelectionChanged, emits(selection));

      ctrl.syncSelection(selection);

      await emitted;
      expect(ctrl.selection, selection);
      expect(tapCount, 0);

      ctrl.dispose();
    });
  });

  group('ChartZoomViewport and ChartZoomBridge', () {
    test('viewport computes visible indices and coordinate mapping', () {
      final vp = ChartZoomViewport(
        left: 10,
        top: 10,
        right: 210,
        bottom: 110,
        dataMinY: 0,
        dataMaxY: 100,
        dataLength: 100,
        zoomState: ChartZoomState(xStart: 0.2, xEnd: 0.6),
      );

      expect(vp.visibleStartIndex, 20);
      expect(vp.visibleEndIndex, 59);
      expect(vp.visibleCount, 40);

      final xFor20 = vp.indexToCanvasX(20);
      final expectedXFor20 = 10 + (((20 / 99) - 0.2) / 0.4) * 200;
      expect(xFor20, closeTo(expectedXFor20, 1e-6));
      expect(vp.canvasXToIndex(10), inInclusiveRange(19, 20));

      final idx = vp.canvasXToIndex(110);
      expect(idx, inInclusiveRange(39, 41));
    });

    test('bridge syncs ChartController and ChartZoomController both ways', () {
      final chartCtrl = ChartController();
      final zoomCtrl = ChartZoomController();
      final bridge = ChartZoomBridge(
        chartController: chartCtrl,
        zoomController: zoomCtrl,
        totalDataPoints: 101,
      );
      expect(bridge.isAttached, isTrue);

      chartCtrl.zoomTo(start: 10, end: 50, factor: 2);
      expect(zoomCtrl.value.xStart, closeTo(0.1, 1e-9));
      expect(zoomCtrl.value.xEnd, closeTo(0.5, 1e-9));

      zoomCtrl.zoomToRange(0.2, 0.4, label: 'range');
      expect(chartCtrl.zoom.start, 20);
      expect(chartCtrl.zoom.end, 40);

      bridge.dispose();
      chartCtrl.dispose();
      zoomCtrl.dispose();
    });

    test('bridge dispose is idempotent and stops later synchronization', () {
      final chartCtrl = ChartController();
      final zoomCtrl = ChartZoomController();
      final bridge = ChartZoomBridge(
        chartController: chartCtrl,
        zoomController: zoomCtrl,
        totalDataPoints: 101,
      );

      bridge.dispose();
      bridge.dispose();

      expect(bridge.isDisposed, isTrue);
      expect(bridge.isAttached, isFalse);

      chartCtrl.zoomTo(start: 10, end: 40, factor: 2);
      expect(zoomCtrl.value, ChartZoomState.identity);

      zoomCtrl.zoomToRange(0.2, 0.4, label: 'late');
      expect(chartCtrl.zoom, const ZoomRange(start: 10, end: 40, factor: 2));

      chartCtrl.dispose();
      zoomCtrl.dispose();
    });

    test('bridge tolerates disposed controllers and detaches live peer', () {
      final disposedChart = ChartController();
      final liveZoom = ChartZoomController();
      disposedChart.dispose();

      final unattachedFromChart = ChartZoomBridge(
        chartController: disposedChart,
        zoomController: liveZoom,
        totalDataPoints: 101,
      );
      expect(unattachedFromChart.isAttached, isFalse);

      final liveChart = ChartController();
      final disposedZoom = ChartZoomController();
      disposedZoom.dispose();

      final unattachedFromZoom = ChartZoomBridge(
        chartController: liveChart,
        zoomController: disposedZoom,
        totalDataPoints: 101,
      );
      expect(unattachedFromZoom.isAttached, isFalse);

      final chartCtrl = ChartController();
      final zoomCtrl = ChartZoomController();
      final bridge = ChartZoomBridge(
        chartController: chartCtrl,
        zoomController: zoomCtrl,
        totalDataPoints: 101,
      );

      chartCtrl.dispose();

      expect(() {
        zoomCtrl.zoomToRange(0.2, 0.4, label: 'late peer');
      }, returnsNormally);
      expect(bridge.isDisposed, isTrue);
      expect(bridge.isAttached, isFalse);

      unattachedFromChart.dispose();
      unattachedFromZoom.dispose();
      liveChart.dispose();
      liveZoom.dispose();
      zoomCtrl.dispose();
    });

    test('bridge clamps chart ranges and does not create zoom history', () {
      final chartCtrl = ChartController();
      final zoomCtrl = ChartZoomController(
        constraints: const ZoomConstraints(minWindowFraction: 0.2),
      );
      final bridge = ChartZoomBridge(
        chartController: chartCtrl,
        zoomController: zoomCtrl,
        totalDataPoints: 101,
      );

      chartCtrl.zoomTo(start: 10, end: 11, factor: 10);
      expect(zoomCtrl.canPop, isFalse);
      expect(zoomCtrl.value.windowSize, closeTo(0.2, 1e-9));

      chartCtrl.zoomTo(start: -100, end: 500, factor: 10);
      expect(zoomCtrl.value.xStart, closeTo(0, 1e-9));
      expect(zoomCtrl.value.xEnd, closeTo(1, 1e-9));

      chartCtrl.zoomTo(start: 80, end: 20, factor: 10);
      expect(zoomCtrl.value.xStart, closeTo(0.2, 1e-9));
      expect(zoomCtrl.value.xEnd, closeTo(0.8, 1e-9));

      bridge.dispose();
      chartCtrl.dispose();
      zoomCtrl.dispose();
    });

    test('bridge ignores single-point data without invalid zoom factor', () {
      final chartCtrl = ChartController();
      final zoomCtrl = ChartZoomController();
      final bridge = ChartZoomBridge(
        chartController: chartCtrl,
        zoomController: zoomCtrl,
        totalDataPoints: 1,
      );

      chartCtrl.zoomTo(start: 0, end: 0, factor: 1);
      expect(zoomCtrl.value.isIdentity, isTrue);

      zoomCtrl.setVisibleRange(0.5, 0.5);
      expect(chartCtrl.zoom, const ZoomRange(start: 0, end: 0, factor: 1));
      expect(chartCtrl.zoom.factor.isFinite, isTrue);

      bridge.dispose();
      chartCtrl.dispose();
      zoomCtrl.dispose();
    });

    test('viewport tolerates zero data length and invalid geometry', () {
      const vp = ChartZoomViewport(
        left: double.nan,
        top: 10,
        right: 5,
        bottom: double.infinity,
        dataMinY: double.nan,
        dataMaxY: double.infinity,
        dataLength: 0,
      );

      expect(vp.width, 5);
      expect(vp.height, 0);
      expect(vp.visibleStartIndex, 0);
      expect(vp.visibleEndIndex, 0);
      expect(vp.visibleCount, 0);
      expect(vp.indexToCanvasX(0), 2.5);
      expect(vp.fracIndexToCanvasX(double.nan), 2.5);
      expect(vp.canvasXToFracIndex(double.nan), 0);
      expect(vp.canvasXToIndex(double.nan), 0);
      expect(vp.dataYToCanvasY(double.nan), 0);
      expect(vp.canvasYToDataY(double.nan), 0);
      expect(vp.isCanvasXVisible(double.nan), isFalse);
    });

    test('viewport normalizes reversed index ranges', () {
      const vp = ChartZoomViewport(
        left: 0,
        top: 0,
        right: 100,
        bottom: 100,
        dataMinY: 0,
        dataMaxY: 1,
        dataLength: 11,
      );

      expect(vp.indicesToFraction(8, 2), (0.2, 0.8));
    });
  });
}
