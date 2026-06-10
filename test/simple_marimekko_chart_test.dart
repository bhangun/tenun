import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const categories = ['SMB', 'Mid', 'Enterprise'];
  const series = [
    SimpleMarimekkoSeries(name: 'Online', values: [32, 24, 18]),
    SimpleMarimekkoSeries(name: 'Partner', values: [18, 28, 34]),
    SimpleMarimekkoSeries(name: 'Field', values: [10, 22, 46]),
  ];

  testWidgets('renders marimekko styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleMarimekkoChart(
                categories: categories,
                series: series,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleMarimekkoChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders marimekko without labels or legend', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMarimekkoChart(
              categories: categories,
              series: series,
              showLegend: false,
              showValues: false,
              showPercentages: false,
              showSegmentLabels: false,
              showColumnTotals: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleMarimekkoChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows marimekko tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMarimekkoChart(
              categories: categories,
              series: series,
              showLegend: false,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(50, 200));
    await tester.pump();

    expect(find.text('SMB'), findsWidgets);
    expect(find.text('Online'), findsWidgets);
    expect(find.text('32'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes marimekko segment tap callback without tooltip', (
    tester,
  ) async {
    String? tappedCategory;
    String? tappedSeries;
    int? tappedCategoryIndex;
    int? tappedSeriesIndex;
    double? tappedValue;
    double? tappedShare;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMarimekkoChart(
              categories: categories,
              series: series,
              showLegend: false,
              showTooltip: false,
              onSegmentTap:
                  (
                    category,
                    selectedSeries,
                    value,
                    share,
                    categoryIndex,
                    seriesIndex,
                  ) {
                    tappedCategory = category;
                    tappedSeries = selectedSeries.name;
                    tappedValue = value;
                    tappedShare = share;
                    tappedCategoryIndex = categoryIndex;
                    tappedSeriesIndex = seriesIndex;
                  },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(50, 200));
    await tester.pump();

    expect(tappedCategory, 'SMB');
    expect(tappedSeries, 'Online');
    expect(tappedValue, 32);
    expect(tappedShare, closeTo(32 / 60, 0.001));
    expect(tappedCategoryIndex, 0);
    expect(tappedSeriesIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default marimekko semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMarimekkoChart(categories: categories, series: series),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Marimekko chart, 3 categories and 3 series\. SMB total 60'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
