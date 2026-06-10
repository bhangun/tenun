import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const controlSeries = SimpleBarcodePlotSeries(
    name: 'Control',
    values: [34, 42, 54, 58, 64, 68, 72, 74, 88, 96],
  );

  const series = [
    controlSeries,
    SimpleBarcodePlotSeries(
      name: 'Program A',
      values: [48, 58, 62, 66, 70, 76, 82, 86, 94, 98],
    ),
    SimpleBarcodePlotSeries(
      name: 'Program B',
      values: [38, 46, 50, 54, 58, 60, 66, 68, 78, 86],
    ),
  ];

  testWidgets('renders barcode plot styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 260,
              child: SimpleBarcodePlotChart(
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

      expect(find.byType(SimpleBarcodePlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders barcode plot with references', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 260,
            child: SimpleBarcodePlotChart(
              series: series,
              minValue: 0,
              maxValue: 100,
              showValues: true,
              showMedian: true,
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

    expect(find.byType(SimpleBarcodePlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows barcode plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 260,
            child: SimpleBarcodePlotChart(
              series: [controlSeries],
              minValue: 0,
              maxValue: 100,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(302, 120));
    await tester.pump();

    expect(find.text('Control'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('64'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes barcode plot tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedSeriesIndex;
    int? tappedValueIndex;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 260,
            child: SimpleBarcodePlotChart(
              series: const [controlSeries],
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onTickTap: (item, seriesIndex, valueIndex, value) {
                tappedLabel = item.name;
                tappedSeriesIndex = seriesIndex;
                tappedValueIndex = valueIndex;
                tappedValue = value;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(302, 120));
    await tester.pump();

    expect(tappedLabel, 'Control');
    expect(tappedSeriesIndex, 0);
    expect(tappedValueIndex, 4);
    expect(tappedValue, 64);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default barcode plot semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 260,
            child: SimpleBarcodePlotChart(series: series),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Barcode plot chart, 3 series\. Control count 10, min 34, median 66, max 96',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
