import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleBarChartData(label: 'North', value: 12),
    SimpleBarChartData(label: 'South', value: -4),
    SimpleBarChartData(label: 'East', value: 18),
  ];
  const groupedCategories = ['Q1', 'Q2', 'Q3'];
  const groupedSeries = [
    SimpleGroupedBarSeries(name: 'Direct', values: [18, 22, 27]),
    SimpleGroupedBarSeries(name: 'Partner', values: [12, 15, 19]),
  ];
  const stackedCategories = ['Plan', 'Build', 'Launch'];
  const stackedSeries = [
    SimpleGroupedBarSeries(name: 'People', values: [28, 34, 39]),
    SimpleGroupedBarSeries(name: 'Tools', values: [12, 14, 16]),
    SimpleGroupedBarSeries(name: 'Programs', values: [18, 20, 24]),
  ];

  testWidgets('renders vertical styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 260,
              child: SimpleBarChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleBarChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders horizontal track variant without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleBarChart(
              data: data,
              orientation: SimpleBarChartOrientation.horizontal,
              style: SimpleBarChartStyle.professional,
              showTrack: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleBarChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders grouped bar chart without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 280,
            child: SimpleGroupedBarChart(
              categories: groupedCategories,
              series: groupedSeries,
              style: SimpleBarChartStyle.modern,
              referenceLines: [
                SimpleChartReferenceLine(value: 24, label: 'Target'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 18, to: 26, label: 'Range'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleGroupedBarChart), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes grouped bar tap callback without tooltip', (
    tester,
  ) async {
    String? tappedCategory;
    String? tappedSeries;
    double? tappedValue;
    int? tappedCategoryIndex;
    int? tappedSeriesIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 280,
            child: SimpleGroupedBarChart(
              categories: groupedCategories,
              series: groupedSeries,
              showTooltip: false,
              onBarTap: (category, series, value, categoryIndex, seriesIndex) {
                tappedCategory = category;
                tappedSeries = series.name;
                tappedValue = value;
                tappedCategoryIndex = categoryIndex;
                tappedSeriesIndex = seriesIndex;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(86, 110));
    await tester.pump();

    expect(tappedCategory, 'Q1');
    expect(tappedSeries, 'Direct');
    expect(tappedValue, 18);
    expect(tappedCategoryIndex, 0);
    expect(tappedSeriesIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders stacked bar chart without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 280,
            child: SimpleStackedBarChart(
              categories: stackedCategories,
              series: stackedSeries,
              style: SimpleBarChartStyle.elegant,
              referenceLines: [
                SimpleChartReferenceLine(value: 70, label: 'Budget'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 60, to: 80, label: 'Range'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleStackedBarChart), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Programs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders percent stacked bar chart without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 280,
            child: SimpleStackedBarChart(
              categories: stackedCategories,
              series: stackedSeries,
              mode: SimpleStackedBarMode.percent,
              style: SimpleBarChartStyle.professional,
              referenceLines: [
                SimpleChartReferenceLine(value: 75, label: 'Share'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleStackedBarChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes stacked bar segment tap callback without tooltip', (
    tester,
  ) async {
    String? tappedCategory;
    String? tappedSeries;
    double? tappedValue;
    double? tappedShare;
    int? tappedCategoryIndex;
    int? tappedSeriesIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 280,
            child: SimpleStackedBarChart(
              categories: stackedCategories,
              series: stackedSeries,
              showTooltip: false,
              onBarTap:
                  (category, series, value, share, categoryIndex, seriesIndex) {
                    tappedCategory = category;
                    tappedSeries = series.name;
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

    await tester.tapAt(const Offset(92, 178));
    await tester.pump();

    expect(tappedCategory, 'Plan');
    expect(tappedSeries, 'People');
    expect(tappedValue, 28);
    expect(tappedShare, closeTo(48.27, 0.1));
    expect(tappedCategoryIndex, 0);
    expect(tappedSeriesIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders reference line and band without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 260,
            child: SimpleBarChart(
              data: data,
              referenceLines: [
                SimpleChartReferenceLine(value: 10, label: 'Goal'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 8, to: 14, label: 'Range'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleBarChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders default empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: SimpleBarChart(data: []),
          ),
        ),
      ),
    );

    expect(find.text('No data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 260,
            child: SimpleBarChart(data: data),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(80, 100));
    await tester.pump();

    expect(find.text('North'), findsOneWidget);
    expect(find.text('Value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('highlights active bar and invokes tap callback', (tester) async {
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 260,
            child: SimpleBarChart(
              data: data,
              showTooltip: false,
              onBarTap: (item, index) {
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(80, 100));
    await tester.pump();

    expect(tappedIndex, 0);
    expect(find.text('North'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 260,
            child: SimpleBarChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Bar chart, 3 items\. North 12, South -4, East 18\.'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
