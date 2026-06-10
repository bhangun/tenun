import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const categories = ['Clarity', 'Quality', 'Speed', 'Reach'];
  const series = [
    SimpleDotPlotSeries(name: 'Score', values: [84, 78, 72, 66]),
  ];
  const comparisonSeries = [
    SimpleDotPlotSeries(name: 'Current', values: [84, 78, 72, 66]),
    SimpleDotPlotSeries(name: 'Target', values: [90, 86, 82, 78]),
  ];

  testWidgets('renders dot plot styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleDotPlotChart(
                categories: categories,
                series: series,
                minValue: 0,
                maxValue: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDotPlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders vertical multi-series dot plot with references', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleDotPlotChart(
              categories: categories,
              series: comparisonSeries,
              orientation: SimpleBarChartOrientation.vertical,
              minValue: 0,
              maxValue: 100,
              referenceLines: [
                SimpleChartReferenceLine(value: 80, label: 'Goal'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 75, to: 90, label: 'Strong'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDotPlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows dot plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDotPlotChart(
              categories: categories,
              series: series,
              minValue: 0,
              maxValue: 100,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(366, 47));
    await tester.pump();

    expect(find.text('Clarity'), findsWidgets);
    expect(find.text('Score'), findsWidgets);
    expect(find.text('84'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes dot plot tap callback without tooltip', (tester) async {
    String? tappedCategory;
    String? tappedSeries;
    int? tappedCategoryIndex;
    int? tappedSeriesIndex;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDotPlotChart(
              categories: categories,
              series: series,
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onPointTap:
                  (
                    category,
                    selectedSeries,
                    value,
                    categoryIndex,
                    seriesIndex,
                  ) {
                    tappedCategory = category;
                    tappedSeries = selectedSeries.name;
                    tappedValue = value;
                    tappedCategoryIndex = categoryIndex;
                    tappedSeriesIndex = seriesIndex;
                  },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(366, 47));
    await tester.pump();

    expect(tappedCategory, 'Clarity');
    expect(tappedSeries, 'Score');
    expect(tappedValue, 84);
    expect(tappedCategoryIndex, 0);
    expect(tappedSeriesIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default dot plot semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDotPlotChart(categories: categories, series: series),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Dot plot chart, 4 categories\. Clarity: Score 84'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
