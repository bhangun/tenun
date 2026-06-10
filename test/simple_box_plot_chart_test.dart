import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleBoxPlotData(
      label: 'Control',
      min: 42,
      q1: 54,
      median: 64,
      q3: 74,
      max: 88,
      mean: 65,
      outliers: [34, 96],
    ),
    SimpleBoxPlotData(
      label: 'Program A',
      min: 48,
      q1: 62,
      median: 70,
      q3: 82,
      max: 94,
      mean: 71,
    ),
    SimpleBoxPlotData(
      label: 'Program B',
      min: 38,
      q1: 50,
      median: 58,
      q3: 68,
      max: 86,
      mean: 60,
    ),
  ];

  testWidgets('renders box plot styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleBoxPlotChart(
                data: data,
                minValue: 0,
                maxValue: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleBoxPlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders box plot from raw values with references', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBoxPlotChart(
              data: [
                SimpleBoxPlotData(
                  label: 'Class A',
                  values: [42, 54, 61, 65, 68, 72, 76, 81, 88, 96],
                ),
                SimpleBoxPlotData(
                  label: 'Class B',
                  values: [38, 44, 48, 55, 58, 62, 66, 71, 79, 84],
                ),
              ],
              minValue: 0,
              maxValue: 100,
              showMean: true,
              showOutliers: true,
              referenceLines: [
                SimpleChartReferenceLine(value: 75, label: 'Goal'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 70, to: 90, label: 'Target'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleBoxPlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows box plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBoxPlotChart(data: data, minValue: 0, maxValue: 100),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 98));
    await tester.pump();

    expect(find.text('Control'), findsWidgets);
    expect(find.text('Median'), findsOneWidget);
    expect(find.text('64'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes box tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBoxPlotChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onBoxTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 98));
    await tester.pump();

    expect(tappedLabel, 'Control');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default box plot semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBoxPlotChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Box plot chart, 3 categories\. Control min 42, q1 54, median 64, q3 74, max 88',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
