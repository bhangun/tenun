import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const points = [
    SimpleControlChartPoint(label: 'W1', value: 50),
    SimpleControlChartPoint(label: 'W2', value: 52),
    SimpleControlChartPoint(label: 'W3', value: 49),
    SimpleControlChartPoint(label: 'W4', value: 55),
    SimpleControlChartPoint(label: 'W5', value: 61),
    SimpleControlChartPoint(label: 'W6', value: 48),
  ];

  testWidgets('renders control chart styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleControlChart(
                points: points,
                style: style,
                minValue: 40,
                maxValue: 65,
                centerValue: 50,
                lowerControlLimit: 45,
                upperControlLimit: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleControlChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders control chart with references and values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleControlChart(
              points: points,
              minValue: 40,
              maxValue: 65,
              centerValue: 50,
              lowerControlLimit: 45,
              upperControlLimit: 60,
              showValues: true,
              referenceLines: [
                SimpleChartReferenceLine(value: 55, label: 'Goal'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 48, to: 55, label: 'Normal'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleControlChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows control chart tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleControlChart(
              points: points,
              minValue: 40,
              maxValue: 65,
              centerValue: 50,
              lowerControlLimit: 45,
              upperControlLimit: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(207, 159));
    await tester.pump();

    expect(find.text('W3'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('49'), findsWidgets);
    expect(find.text('Stable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes control chart tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    bool? tappedSignal;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleControlChart(
              points: points,
              minValue: 40,
              maxValue: 65,
              centerValue: 50,
              lowerControlLimit: 45,
              upperControlLimit: 60,
              showTooltip: false,
              onPointTap: (point, index, stats, isSignal) {
                tappedLabel = point.label;
                tappedIndex = index;
                tappedSignal = isSignal;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(207, 159));
    await tester.pump();

    expect(tappedLabel, 'W3');
    expect(tappedIndex, 2);
    expect(tappedSignal, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default control chart semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleControlChart(
              points: points,
              centerValue: 50,
              lowerControlLimit: 45,
              upperControlLimit: 60,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Control chart, 6 points\. Center 50, limits 45 to 60\. W1 50, W2 52, W3 49, W4 55; and 2 more points; 1 signal\.',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
