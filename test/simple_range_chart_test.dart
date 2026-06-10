import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleRangeChartData(label: 'North', min: 62, max: 88, value: 76),
    SimpleRangeChartData(label: 'South', min: 55, max: 82, value: 70),
    SimpleRangeChartData(label: 'East', min: 68, max: 92, value: 84),
    SimpleRangeChartData(label: 'West', min: 58, max: 78, value: 66),
  ];

  testWidgets('renders range styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleRangeChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleRangeChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders vertical range with references', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRangeChart(
              data: data,
              orientation: SimpleBarChartOrientation.vertical,
              showRangeLabels: false,
              referenceLines: [
                SimpleChartReferenceLine(value: 75, label: 'Goal'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 70, to: 90, label: 'Healthy'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleRangeChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows range tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRangeChart(data: data, minValue: 50, maxValue: 95),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(260, 47));
    await tester.pump();

    expect(find.text('North'), findsWidgets);
    expect(find.text('Min'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes range tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRangeChart(
              data: data,
              minValue: 50,
              maxValue: 95,
              showTooltip: false,
              onRangeTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(260, 47));
    await tester.pump();

    expect(tappedLabel, 'North');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default range semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRangeChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Range chart, 4 items\. North range 62 to 88, value 76'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
