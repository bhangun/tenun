import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const points = [
    SimpleScatterPoint(
      label: 'Quick Win',
      x: 20,
      y: 82,
      size: 32,
      group: 'Growth',
    ),
    SimpleScatterPoint(label: 'Scale', x: 52, y: 74, size: 44, group: 'Growth'),
    SimpleScatterPoint(
      label: 'Platform',
      x: 72,
      y: 64,
      size: 36,
      group: 'Core',
    ),
    SimpleScatterPoint(label: 'Cleanup', x: 38, y: 36, size: 20, group: 'Core'),
  ];

  testWidgets('renders scatter styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleScatterChart(
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

      expect(find.byType(SimpleScatterChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders scatter with trend and references', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleScatterChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              showTrendLine: true,
              showValues: true,
              referenceLines: [
                SimpleScatterReferenceLine(
                  axis: SimpleScatterReferenceAxis.x,
                  value: 50,
                  label: 'Effort',
                ),
                SimpleScatterReferenceLine(
                  axis: SimpleScatterReferenceAxis.y,
                  value: 70,
                  label: 'Impact',
                ),
              ],
              referenceBands: [
                SimpleScatterReferenceBand(
                  axis: SimpleScatterReferenceAxis.y,
                  from: 70,
                  to: 100,
                  label: 'High',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleScatterChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows scatter tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleScatterChart(
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

    await tester.tapAt(const Offset(129, 62));
    await tester.pump();

    expect(find.text('Quick Win'), findsWidgets);
    expect(find.text('Effort'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes scatter point tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleScatterChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              showTooltip: false,
              onPointTap: (point, index) {
                tappedLabel = point.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(129, 62));
    await tester.pump();

    expect(tappedLabel, 'Quick Win');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default scatter semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleScatterChart(points: points),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Scatter chart, 4 points\. Quick Win x 20, y 82'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
