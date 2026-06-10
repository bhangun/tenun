import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const series = [
    SimpleLorenzSeries(name: 'Concentration', values: [1, 2, 3, 4, 10]),
  ];

  testWidgets('renders Lorenz curve styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleLorenzCurveChart(series: series, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleLorenzCurveChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact Lorenz curve without labels or area', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 220,
            child: SimpleLorenzCurveChart(
              series: series,
              showAxisLabels: false,
              showLegend: false,
              showValues: true,
              showArea: false,
              showEqualityLine: false,
              showGini: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleLorenzCurveChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Lorenz curve tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleLorenzCurveChart(series: series),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(282, 172));
    await tester.pump();

    expect(find.text('Concentration p60'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('0.40'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes Lorenz curve tap callback without tooltip', (
    tester,
  ) async {
    String? tappedName;
    int? tappedSeriesIndex;
    int? tappedPointIndex;
    double? tappedPopulationShare;
    double? tappedValueShare;
    double? tappedGini;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleLorenzCurveChart(
              series: series,
              showTooltip: false,
              onPointTap: (series, point, stats, seriesIndex, pointIndex) {
                tappedName = series.name;
                tappedSeriesIndex = seriesIndex;
                tappedPointIndex = pointIndex;
                tappedPopulationShare = point.populationShare;
                tappedValueShare = point.valueShare;
                tappedGini = stats.gini;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(282, 172));
    await tester.pump();

    expect(tappedName, 'Concentration');
    expect(tappedSeriesIndex, 0);
    expect(tappedPointIndex, 3);
    expect(tappedPopulationShare, closeTo(0.6, 0.001));
    expect(tappedValueShare, closeTo(0.3, 0.001));
    expect(tappedGini, closeTo(0.4, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default Lorenz curve semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleLorenzCurveChart(series: series),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Lorenz curve chart, 1 series\. Concentration 5 values, Gini 0\.40',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
