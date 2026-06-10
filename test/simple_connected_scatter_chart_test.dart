import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const series = [
    SimpleConnectedScatterSeries(
      name: 'Current',
      points: [
        SimpleConnectedScatterPoint(label: 'Q1', x: 20, y: 82, value: 32),
        SimpleConnectedScatterPoint(label: 'Q2', x: 34, y: 76, value: 42),
        SimpleConnectedScatterPoint(label: 'Q3', x: 48, y: 68, value: 55),
        SimpleConnectedScatterPoint(label: 'Q4', x: 64, y: 72, value: 68),
      ],
    ),
    SimpleConnectedScatterSeries(
      name: 'Target',
      points: [
        SimpleConnectedScatterPoint(label: 'Q1', x: 24, y: 70, value: 36),
        SimpleConnectedScatterPoint(label: 'Q2', x: 40, y: 74, value: 48),
        SimpleConnectedScatterPoint(label: 'Q3', x: 56, y: 78, value: 62),
      ],
    ),
  ];

  testWidgets('renders connected scatter styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleConnectedScatterChart(
                series: series,
                minX: 0,
                maxX: 100,
                minY: 0,
                maxY: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleConnectedScatterChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders connected scatter with references and values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleConnectedScatterChart(
              series: series,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              xAxisLabel: 'Reach',
              yAxisLabel: 'Quality',
              showValues: true,
              showEndpointLabels: false,
              referenceLines: [
                SimpleScatterReferenceLine(
                  axis: SimpleScatterReferenceAxis.x,
                  value: 50,
                  label: 'Reach',
                ),
              ],
              referenceBands: [
                SimpleScatterReferenceBand(
                  axis: SimpleScatterReferenceAxis.y,
                  from: 75,
                  to: 100,
                  label: 'Healthy',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleConnectedScatterChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows connected scatter tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleConnectedScatterChart(
              series: series,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              xAxisLabel: 'Reach',
              yAxisLabel: 'Quality',
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(129, 53));
    await tester.pump();

    expect(find.text('Q1'), findsWidgets);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Reach'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes connected scatter point tap callback without tooltip', (
    tester,
  ) async {
    String? tappedSeries;
    String? tappedLabel;
    int? tappedSeriesIndex;
    int? tappedPointIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleConnectedScatterChart(
              series: series,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              showTooltip: false,
              onPointTap: (series, point, seriesIndex, pointIndex) {
                tappedSeries = series.name;
                tappedLabel = point.label;
                tappedSeriesIndex = seriesIndex;
                tappedPointIndex = pointIndex;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(129, 53));
    await tester.pump();

    expect(tappedSeries, 'Current');
    expect(tappedLabel, 'Q1');
    expect(tappedSeriesIndex, 0);
    expect(tappedPointIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default connected scatter semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleConnectedScatterChart(
              series: series,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Connected scatter chart, 2 series\. Current: Q1 x 20, y 82'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
