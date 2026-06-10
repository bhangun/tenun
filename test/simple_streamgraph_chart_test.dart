import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleTrendSeries(
      name: 'Search',
      points: [
        SimpleTrendPoint(label: 'Q1', value: 28),
        SimpleTrendPoint(label: 'Q2', value: 34),
        SimpleTrendPoint(label: 'Q3', value: 39),
        SimpleTrendPoint(label: 'Q4', value: 46),
      ],
    ),
    SimpleTrendSeries(
      name: 'Partner',
      points: [
        SimpleTrendPoint(label: 'Q1', value: 18),
        SimpleTrendPoint(label: 'Q2', value: 26),
        SimpleTrendPoint(label: 'Q3', value: 32),
        SimpleTrendPoint(label: 'Q4', value: 38),
      ],
    ),
    SimpleTrendSeries(
      name: 'Academy',
      points: [
        SimpleTrendPoint(label: 'Q1', value: 12),
        SimpleTrendPoint(label: 'Q2', value: 18),
        SimpleTrendPoint(label: 'Q3', value: 24),
        SimpleTrendPoint(label: 'Q4', value: 30),
      ],
    ),
    SimpleTrendSeries(
      name: 'Support',
      points: [
        SimpleTrendPoint(label: 'Q1', value: 8),
        SimpleTrendPoint(label: 'Q2', value: 10),
        SimpleTrendPoint(label: 'Q3', value: 14),
        SimpleTrendPoint(label: 'Q4', value: 18),
      ],
    ),
  ];

  testWidgets('renders streamgraph styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleStreamgraphChart(series: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleStreamgraphChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders percent streamgraph at narrow width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 240,
            child: SimpleStreamgraphChart(
              series: data,
              mode: SimpleStreamgraphMode.percent,
              showValues: false,
              showLegend: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleStreamgraphChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows streamgraph tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleStreamgraphChart(series: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(178, 130));
    await tester.pump();

    expect(find.text('Q2'), findsWidgets);
    expect(find.text('Partner'), findsOneWidget);
    expect(find.text('26'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes streamgraph tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    String? tappedSeries;
    double? tappedValue;
    int? tappedLabelIndex;
    int? tappedSeriesIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleStreamgraphChart(
              series: data,
              showTooltip: false,
              onLayerTap:
                  (label, series, value, share, labelIndex, seriesIndex) {
                    tappedLabel = label;
                    tappedSeries = series.name;
                    tappedValue = value;
                    tappedLabelIndex = labelIndex;
                    tappedSeriesIndex = seriesIndex;
                  },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(178, 130));
    await tester.pump();

    expect(tappedLabel, 'Q2');
    expect(tappedSeries, 'Partner');
    expect(tappedValue, 26);
    expect(tappedLabelIndex, 1);
    expect(tappedSeriesIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default streamgraph semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleStreamgraphChart(series: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Streamgraph chart, 4 series across 4 labels\. Latest Q4: Search 46',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
