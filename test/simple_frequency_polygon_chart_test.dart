import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const values = [
    58.0,
    61.0,
    62.0,
    65.0,
    68.0,
    70.0,
    72.0,
    72.0,
    75.0,
    78.0,
    80.0,
    82.0,
    84.0,
    86.0,
    88.0,
    90.0,
    92.0,
    95.0,
  ];

  const binnedSeries = [
    SimpleFrequencyPolygonSeries(
      name: 'Responses',
      bins: [
        SimpleFrequencyPolygonBin(start: 0, end: 20, count: 4),
        SimpleFrequencyPolygonBin(start: 20, end: 40, count: 8),
        SimpleFrequencyPolygonBin(start: 40, end: 60, count: 5),
        SimpleFrequencyPolygonBin(start: 60, end: 80, count: 2),
      ],
    ),
  ];

  testWidgets('renders frequency polygon styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleFrequencyPolygonChart(
                values: values,
                minValue: 0,
                maxValue: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleFrequencyPolygonChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders pre-binned frequency polygon in percent mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFrequencyPolygonChart(
              series: binnedSeries,
              scale: SimpleFrequencyPolygonScale.percent,
              showArea: true,
              showValues: true,
              referenceLines: [
                SimpleChartReferenceLine(value: 40, label: 'High'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleFrequencyPolygonChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows frequency polygon tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFrequencyPolygonChart(series: binnedSeries),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(100, 180));
    await tester.pump();

    expect(find.text('0-20'), findsOneWidget);
    expect(find.text('Responses'), findsWidgets);
    expect(find.text('4'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes frequency polygon tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    int? tappedCount;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFrequencyPolygonChart(
              series: binnedSeries,
              showTooltip: false,
              onBinTap: (label, items, index) {
                tappedLabel = label;
                tappedIndex = index;
                tappedCount = items.single.count;
                tappedValue = items.single.value;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(100, 180));
    await tester.pump();

    expect(tappedLabel, '0-20');
    expect(tappedIndex, 0);
    expect(tappedCount, 4);
    expect(tappedValue, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default frequency polygon semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFrequencyPolygonChart(series: binnedSeries),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Frequency polygon chart, 1 series and 4 bins\. Responses peak 20-40 8',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
