import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const periods = ['Q1', 'Q2', 'Q3', 'Q4'];
  const series = [
    SimpleBumpSeries(name: 'Search', ranks: [2, 1, 1, 2]),
    SimpleBumpSeries(name: 'Academy', ranks: [1, 2, 3, 1]),
    SimpleBumpSeries(name: 'Support', ranks: [3, 3, 2, 3]),
  ];

  testWidgets('renders bump styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleBumpChart(
                periods: periods,
                series: series,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleBumpChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders bump without dots or legend', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBumpChart(
              periods: periods,
              series: series,
              showDots: false,
              showLegend: false,
              smooth: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleBumpChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows bump tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBumpChart(
              periods: periods,
              series: series,
              showLegend: false,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(46, 131));
    await tester.pump();

    expect(find.text('Q1'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('#2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes bump point tap callback without tooltip', (
    tester,
  ) async {
    String? tappedPeriod;
    String? tappedSeries;
    int? tappedRank;
    int? tappedPeriodIndex;
    int? tappedSeriesIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBumpChart(
              periods: periods,
              series: series,
              showLegend: false,
              showTooltip: false,
              onPointTap:
                  (period, selectedSeries, rank, periodIndex, seriesIndex) {
                    tappedPeriod = period;
                    tappedSeries = selectedSeries.name;
                    tappedRank = rank;
                    tappedPeriodIndex = periodIndex;
                    tappedSeriesIndex = seriesIndex;
                  },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(46, 131));
    await tester.pump();

    expect(tappedPeriod, 'Q1');
    expect(tappedSeries, 'Search');
    expect(tappedRank, 2);
    expect(tappedPeriodIndex, 0);
    expect(tappedSeriesIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default bump semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBumpChart(periods: periods, series: series),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Bump chart, 3 series across 4 periods\. Search: Q1 #2'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
