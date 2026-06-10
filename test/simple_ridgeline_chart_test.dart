import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleRidgelineChartData(
      label: 'Control',
      values: [34, 42, 54, 58, 64, 68, 72, 74, 88, 96],
    ),
    SimpleRidgelineChartData(
      label: 'Program A',
      values: [48, 58, 62, 66, 70, 76, 82, 86, 94, 98],
    ),
    SimpleRidgelineChartData(
      label: 'Program B',
      values: [38, 46, 50, 54, 58, 60, 66, 68, 78, 86],
    ),
  ];

  testWidgets('renders ridgeline styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleRidgelineChart(
                data: data,
                minValue: 0,
                maxValue: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleRidgelineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders ridgeline with references and mean markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRidgelineChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              showMean: true,
              showValues: false,
              referenceLines: [
                SimpleChartReferenceLine(value: 75, label: 'Goal'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 70, to: 90, label: 'Target'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleRidgelineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows ridgeline tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRidgelineChart(data: data, minValue: 0, maxValue: 100),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 70));
    await tester.pump();

    expect(find.text('Control'), findsWidgets);
    expect(find.text('Median'), findsOneWidget);
    expect(find.text('66'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes ridgeline tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRidgelineChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onRidgeTap: (item, index, stats) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 70));
    await tester.pump();

    expect(tappedLabel, 'Control');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default ridgeline semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRidgelineChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Ridgeline chart, 3 distributions\. Control count 10, min 34, median 66, max 96',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
