import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleTrendSeries(
      name: 'Revenue',
      points: [
        SimpleTrendPoint(label: 'W1', value: -8),
        SimpleTrendPoint(label: 'W2', value: -2),
        SimpleTrendPoint(label: 'W3', value: 5),
        SimpleTrendPoint(label: 'W4', value: 12),
        SimpleTrendPoint(label: 'W5', value: 8),
        SimpleTrendPoint(label: 'W6', value: 18),
      ],
    ),
    SimpleTrendSeries(
      name: 'Quality',
      points: [
        SimpleTrendPoint(label: 'W1', value: -4),
        SimpleTrendPoint(label: 'W2', value: 3),
        SimpleTrendPoint(label: 'W3', value: 8),
        SimpleTrendPoint(label: 'W4', value: 6),
        SimpleTrendPoint(label: 'W5', value: -3),
        SimpleTrendPoint(label: 'W6', value: 10),
      ],
    ),
    SimpleTrendSeries(
      name: 'Risk',
      points: [
        SimpleTrendPoint(label: 'W1', value: 12),
        SimpleTrendPoint(label: 'W2', value: 8),
        SimpleTrendPoint(label: 'W3', value: 4),
        SimpleTrendPoint(label: 'W4', value: -2),
        SimpleTrendPoint(label: 'W5', value: -8),
        SimpleTrendPoint(label: 'W6', value: -12),
      ],
    ),
  ];

  testWidgets('renders horizon styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleHorizonChart(series: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleHorizonChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders narrow horizon chart without labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 240,
            child: SimpleHorizonChart(
              series: data,
              showValues: false,
              showLegend: false,
              bandCount: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleHorizonChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows horizon tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHorizonChart(series: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(226, 131));
    await tester.pump();

    expect(find.text('Quality'), findsWidgets);
    expect(find.text('W3'), findsOneWidget);
    expect(find.text('+8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes horizon tap callback without tooltip', (tester) async {
    String? tappedSeries;
    String? tappedLabel;
    double? tappedValue;
    int? tappedSeriesIndex;
    int? tappedPointIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHorizonChart(
              series: data,
              showTooltip: false,
              onPointTap: (series, point, seriesIndex, pointIndex) {
                tappedSeries = series.name;
                tappedLabel = point.label;
                tappedValue = point.value;
                tappedSeriesIndex = seriesIndex;
                tappedPointIndex = pointIndex;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(226, 131));
    await tester.pump();

    expect(tappedSeries, 'Quality');
    expect(tappedLabel, 'W3');
    expect(tappedValue, 8);
    expect(tappedSeriesIndex, 1);
    expect(tappedPointIndex, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default horizon semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHorizonChart(series: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Horizon chart, 3 series across 6 labels\. Latest W6: Revenue \+18',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
