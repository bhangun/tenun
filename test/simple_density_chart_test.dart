import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const baseline = SimpleDensitySeries(
    name: 'Baseline',
    values: [20, 30, 40, 50, 60, 70, 80],
  );
  const improved = SimpleDensitySeries(
    name: 'Improved',
    values: [32, 42, 48, 56, 62, 70, 78],
  );

  testWidgets('renders density chart styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleDensityChart(
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

      expect(find.byType(SimpleDensityChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders density chart with references and rug', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleDensityChart(
              series: [baseline, improved],
              minValue: 0,
              maxValue: 100,
              showRug: true,
              showMean: true,
              showMedian: true,
              showValues: true,
              referenceLines: [
                SimpleChartReferenceLine(value: 60, label: 'Goal'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 45, to: 70, label: 'Target'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDensityChart), findsOneWidget);
    expect(find.text('Baseline'), findsOneWidget);
    expect(find.text('Improved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows density chart tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDensityChart(
              series: [baseline],
              minValue: 0,
              maxValue: 100,
              sampleCount: 100,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(249, 50));
    await tester.pump();

    expect(find.text('Baseline'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('50'), findsWidgets);
    expect(find.text('Density'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes density chart tap callback without tooltip', (
    tester,
  ) async {
    String? tappedSeries;
    double? tappedValue;
    double? tappedDensity;
    int? tappedSeriesIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDensityChart(
              series: const [baseline],
              minValue: 0,
              maxValue: 100,
              sampleCount: 100,
              showTooltip: false,
              onSeriesTap: (series, value, density, seriesIndex) {
                tappedSeries = series.name;
                tappedValue = value;
                tappedDensity = density;
                tappedSeriesIndex = seriesIndex;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(249, 50));
    await tester.pump();

    expect(tappedSeries, 'Baseline');
    expect(tappedValue, closeTo(50, 1.2));
    expect(tappedDensity, greaterThan(0));
    expect(tappedSeriesIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default density chart semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDensityChart(series: [baseline, improved]),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Density chart, 2 series\. Baseline 7 samples, median 50'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
