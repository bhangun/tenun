import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const series = [
    SimpleQQPlotSeries(
      name: 'Current',
      referenceName: 'Baseline',
      referenceValues: [10, 20, 30, 40, 50],
      sampleValues: [12, 22, 32, 42, 52],
    ),
  ];

  testWidgets('renders QQ plot styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleQQPlotChart(
                series: series,
                style: style,
                minX: 0,
                maxX: 60,
                minY: 0,
                maxY: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleQQPlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact normal QQ plot without labels or legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 220,
            child: SimpleQQPlotChart(
              series: [
                SimpleQQPlotSeries(
                  name: 'Residuals',
                  sampleValues: [-2, -1, 0, 1, 2, 3],
                ),
              ],
              showLegend: false,
              showAxisLabels: false,
              showValues: true,
              showReferenceLine: false,
              showFitLine: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleQQPlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows QQ plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleQQPlotChart(
              series: series,
              minX: 0,
              maxX: 60,
              minY: 0,
              maxY: 60,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(244, 121));
    await tester.pump();

    expect(find.text('Current p50'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes QQ plot tap callback without tooltip', (tester) async {
    String? tappedName;
    int? tappedSeriesIndex;
    int? tappedPointIndex;
    double? tappedPercentile;
    double? tappedReference;
    double? tappedSample;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleQQPlotChart(
              series: series,
              minX: 0,
              maxX: 60,
              minY: 0,
              maxY: 60,
              showTooltip: false,
              onPointTap: (series, point, seriesIndex, pointIndex) {
                tappedName = series.name;
                tappedSeriesIndex = seriesIndex;
                tappedPointIndex = pointIndex;
                tappedPercentile = point.percentile;
                tappedReference = point.referenceQuantile;
                tappedSample = point.sampleQuantile;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(244, 121));
    await tester.pump();

    expect(tappedName, 'Current');
    expect(tappedSeriesIndex, 0);
    expect(tappedPointIndex, 2);
    expect(tappedPercentile, closeTo(0.5, 0.001));
    expect(tappedReference, closeTo(30, 0.001));
    expect(tappedSample, closeTo(32, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default QQ plot semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleQQPlotChart(series: series),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'QQ plot, 1 series\. Current 5 quantiles, median deviation \+2',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
