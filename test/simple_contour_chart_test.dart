import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const points = [
    SimpleContourPoint(label: 'Quick Win', x: 20, y: 82, value: 78),
    SimpleContourPoint(label: 'Growth', x: 36, y: 72, value: 66),
    SimpleContourPoint(label: 'Platform', x: 58, y: 76, value: 88),
    SimpleContourPoint(label: 'Field Ops', x: 76, y: 54, value: 61),
    SimpleContourPoint(label: 'Cleanup', x: 30, y: 34, value: 38),
    SimpleContourPoint(label: 'Scale', x: 70, y: 32, value: 72),
  ];

  testWidgets('renders contour styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleContourChart(
                points: points,
                minX: 0,
                maxX: 100,
                minY: 0,
                maxY: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleContourChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders contour with custom levels and values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleContourChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              xAxisLabel: 'Reach',
              yAxisLabel: 'Demand',
              levels: [45, 60, 75],
              showValues: true,
              showContourLines: true,
              showSamplePoints: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleContourChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows contour tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleContourChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              xAxisLabel: 'Reach',
              yAxisLabel: 'Demand',
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(129, 53));
    await tester.pump();

    expect(find.text('Quick Win'), findsWidgets);
    expect(find.text('Reach'), findsOneWidget);
    expect(find.text('Demand'), findsOneWidget);
    expect(find.text('Value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes contour selection callback without tooltip', (
    tester,
  ) async {
    SimpleContourSelection? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleContourChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              showTooltip: false,
              onSelectionTap: (hit) => tapped = hit,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(129, 53));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped?.nearestPoint?.label, 'Quick Win');
    expect(tapped?.value, closeTo(78, 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default contour semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleContourChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Contour chart, 6 samples\. Quick Win x 20, y 82, value 78'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
