import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/area/simple_area_chart.dart';
import 'package:tenun/charts/common/simple_chart_reference_line.dart';
import 'package:tenun/charts/line/simple_line_chart.dart';
import 'package:tenun/charts/line/simple_sparkline_chart.dart';

void main() {
  const revenue = SimpleTrendSeries(
    name: 'Revenue',
    points: [
      SimpleTrendPoint(label: 'Jan', value: 42),
      SimpleTrendPoint(label: 'Feb', value: 58),
      SimpleTrendPoint(label: 'Mar', value: 51),
      SimpleTrendPoint(label: 'Apr', value: 74),
      SimpleTrendPoint(label: 'May', value: 69),
    ],
  );

  const expenses = SimpleTrendSeries(
    name: 'Expenses',
    points: [
      SimpleTrendPoint(label: 'Jan', value: 24),
      SimpleTrendPoint(label: 'Feb', value: 31),
      SimpleTrendPoint(label: 'Mar', value: 29),
      SimpleTrendPoint(label: 'Apr', value: 36),
      SimpleTrendPoint(label: 'May', value: 34),
    ],
  );
  const sparklinePoints = [
    SimpleTrendPoint(label: 'Mon', value: 12),
    SimpleTrendPoint(label: 'Tue', value: 18),
    SimpleTrendPoint(label: 'Wed', value: 15),
    SimpleTrendPoint(label: 'Thu', value: 24),
    SimpleTrendPoint(label: 'Fri', value: 22),
  ];

  testWidgets('renders line styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 260,
              child: SimpleLineChart(series: const [revenue], style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleLineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders dashed and dotted series without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleLineChart(
              series: [
                SimpleTrendSeries(
                  name: 'Forecast',
                  lineStyle: SimpleTrendLineStyle.dashed,
                  points: [
                    SimpleTrendPoint(label: 'Jan', value: 38),
                    SimpleTrendPoint(label: 'Feb', value: 45),
                    SimpleTrendPoint(label: 'Mar', value: 54),
                    SimpleTrendPoint(label: 'Apr', value: 63),
                  ],
                ),
                SimpleTrendSeries(
                  name: 'Prior',
                  lineStyle: SimpleTrendLineStyle.dotted,
                  points: [
                    SimpleTrendPoint(label: 'Jan', value: 32),
                    SimpleTrendPoint(label: 'Feb', value: 39),
                    SimpleTrendPoint(label: 'Mar', value: 42),
                    SimpleTrendPoint(label: 'Apr', value: 47),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('Prior'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders sparkline variants without throwing', (tester) async {
    for (final type in SimpleSparklineType.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 72,
              child: SimpleSparklineChart(
                points: sparklinePoints,
                type: type,
                style: SimpleTrendChartStyle.modern,
                referenceLines: const [
                  SimpleChartReferenceLine(value: 20, label: 'Target'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleSparklineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('invokes sparkline tap callback without tooltip', (tester) async {
    SimpleTrendPoint? tappedPoint;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 72,
            child: SimpleSparklineChart(
              points: sparklinePoints,
              showTooltip: false,
              onPointTap: (point, index) {
                tappedPoint = point;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(10, 36));
    await tester.pump();

    expect(tappedPoint?.label, 'Mon');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders multi-series area chart without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleAreaChart(
              series: [revenue, expenses],
              style: SimpleTrendChartStyle.modern,
              showDots: true,
              referenceLines: [
                SimpleChartReferenceLine(value: 50, label: 'Target'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 45, to: 60, label: 'Range'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleAreaChart), findsOneWidget);
    expect(find.byType(SimpleLineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders empty line state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: SimpleLineChart(series: []),
          ),
        ),
      ),
    );

    expect(find.text('No data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows legend and tooltip for multi-series line chart', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleLineChart(series: [revenue, expenses]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);

    await tester.tapAt(const Offset(55, 110));
    await tester.pumpAndSettle();

    expect(find.text('Jan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes point tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;
    List<SimpleTrendTooltipItem>? tappedItems;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleLineChart(
              series: const [revenue, expenses],
              showTooltip: false,
              onPointTap: (label, items, index) {
                tappedLabel = label;
                tappedItems = items;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(55, 110));
    await tester.pump();

    expect(tappedLabel, 'Jan');
    expect(tappedIndex, 0);
    expect(tappedItems, hasLength(2));
    expect(find.text('Jan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleLineChart(series: [revenue, expenses]),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Line chart, 2 series\. Revenue: Jan 42, Feb 58'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes sparkline semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 72,
            child: SimpleSparklineChart(points: sparklinePoints),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Sparkline chart, 5 points\. Mon 12, Fri 22\.'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
