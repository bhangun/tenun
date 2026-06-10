import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const baseline = SimpleEcdfSeries(
    name: 'Baseline',
    values: [20, 40, 60, 80, 100],
  );
  const improved = SimpleEcdfSeries(
    name: 'Improved',
    values: [12, 24, 42, 58, 76],
  );

  testWidgets('renders ECDF styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleEcdfChart(
                series: const [baseline],
                minValue: 0,
                maxValue: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleEcdfChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders multi-series ECDF with references and area', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleEcdfChart(
              series: [baseline, improved],
              minValue: 0,
              maxValue: 120,
              showArea: true,
              showP90Line: true,
              referenceLines: [
                SimpleChartReferenceLine(value: 80, label: 'Target'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 0, to: 60, label: 'Fast'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleEcdfChart), findsOneWidget);
    expect(find.text('Baseline'), findsOneWidget);
    expect(find.text('Improved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows ECDF tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleEcdfChart(
              series: [baseline],
              minValue: 0,
              maxValue: 100,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(288, 106));
    await tester.pump();

    expect(find.text('Baseline'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('60'), findsWidgets);
    expect(find.text('60%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes ECDF tap callback without tooltip', (tester) async {
    String? tappedSeries;
    int? tappedValueIndex;
    int? tappedSeriesIndex;
    double? tappedValue;
    double? tappedPercentile;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleEcdfChart(
              series: const [baseline],
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onPointTap: (series, value, percentile, valueIndex, seriesIndex) {
                tappedSeries = series.name;
                tappedValue = value;
                tappedPercentile = percentile;
                tappedValueIndex = valueIndex;
                tappedSeriesIndex = seriesIndex;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(288, 106));
    await tester.pump();

    expect(tappedSeries, 'Baseline');
    expect(tappedValue, 60);
    expect(tappedPercentile, 0.6);
    expect(tappedValueIndex, 2);
    expect(tappedSeriesIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default ECDF semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleEcdfChart(series: [baseline, improved]),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'ECDF chart, 2 series\. Baseline 5 samples, median 60, p90 92'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
