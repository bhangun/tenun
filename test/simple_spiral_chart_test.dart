import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const points = [
    SimpleSpiralChartPoint(label: 'Jan', value: 42),
    SimpleSpiralChartPoint(label: 'Feb', value: 48),
    SimpleSpiralChartPoint(label: 'Mar', value: 52),
    SimpleSpiralChartPoint(label: 'Apr', value: 61),
    SimpleSpiralChartPoint(label: 'May', value: 67),
    SimpleSpiralChartPoint(label: 'Jun', value: 74),
    SimpleSpiralChartPoint(label: 'Jul', value: 82),
    SimpleSpiralChartPoint(label: 'Aug', value: 79),
  ];

  testWidgets('renders spiral styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleSpiralChart(
                points: points,
                style: style,
                cycleLength: 6,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleSpiralChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders spiral with values and cycle guides', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSpiralChart(
              points: points,
              centerLabel: 'Demand',
              cycleLength: 4,
              showValues: true,
              showCycleGuides: true,
              showLegend: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleSpiralChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows spiral tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSpiralChart(
              points: points,
              minValue: 40,
              maxValue: 90,
              cycleLength: 6,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(230, 97));
    await tester.pump();

    expect(find.text('Jan'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('Range'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes spiral point tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedNormalized;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSpiralChart(
              points: points,
              minValue: 40,
              maxValue: 90,
              cycleLength: 6,
              showTooltip: false,
              onPointTap: (point, index, normalized) {
                tappedLabel = point.label;
                tappedIndex = index;
                tappedNormalized = normalized;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(230, 97));
    await tester.pump();

    expect(tappedLabel, 'Jan');
    expect(tappedIndex, 0);
    expect(tappedNormalized, closeTo(0.04, 0.02));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default spiral semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSpiralChart(
              points: points,
              minValue: 40,
              maxValue: 90,
              cycleLength: 6,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Spiral chart, 8 points\. Jan 42, 4% of range'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
