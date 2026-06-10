import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const points = [
    SimpleQuadrantPoint(
      label: 'Quick Win',
      x: 20,
      y: 82,
      size: 32,
      group: 'Growth',
    ),
    SimpleQuadrantPoint(
      label: 'Scale',
      x: 72,
      y: 74,
      size: 44,
      group: 'Growth',
    ),
    SimpleQuadrantPoint(
      label: 'Platform',
      x: 72,
      y: 34,
      size: 36,
      group: 'Core',
    ),
    SimpleQuadrantPoint(
      label: 'Cleanup',
      x: 38,
      y: 36,
      size: 20,
      group: 'Core',
    ),
  ];

  testWidgets('renders quadrant styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleQuadrantChart(
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

      expect(find.byType(SimpleQuadrantChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders quadrant labels, point labels, and references', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleQuadrantChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              xSplit: 50,
              ySplit: 50,
              showPointLabels: true,
              quadrantLabels: SimpleQuadrantLabels(
                topRight: 'Scale',
                topLeft: 'Strategic',
                bottomLeft: 'Hold',
                bottomRight: 'Automate',
              ),
              referenceLines: [
                SimpleChartReferenceLine(value: 70, label: 'High'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleQuadrantChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows quadrant tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleQuadrantChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              xAxisLabel: 'Effort',
              yAxisLabel: 'Impact',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(129, 59));
    await tester.pump();

    expect(find.text('Quick Win'), findsWidgets);
    expect(find.text('Zone'), findsOneWidget);
    expect(find.text('Strategic bets'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes quadrant point tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    String? tappedQuadrant;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleQuadrantChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              showTooltip: false,
              onPointTap: (point, index, quadrant) {
                tappedLabel = point.label;
                tappedIndex = index;
                tappedQuadrant = quadrant;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(129, 59));
    await tester.pump();

    expect(tappedLabel, 'Quick Win');
    expect(tappedIndex, 0);
    expect(tappedQuadrant, 'Strategic bets');
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default quadrant semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleQuadrantChart(
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
        RegExp(
          r'Quadrant chart, 4 points\. Quick Win x 20, y 82, Strategic bets',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
