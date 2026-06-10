import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleBoxenPlotData(
      label: 'Control',
      values: [34, 42, 54, 58, 64, 68, 72, 74, 88],
    ),
    SimpleBoxenPlotData(
      label: 'Program A',
      values: [48, 58, 62, 66, 70, 76, 82, 86, 94],
    ),
    SimpleBoxenPlotData(
      label: 'Program B',
      values: [38, 44, 50, 54, 58, 60, 66, 68, 86],
    ),
  ];

  testWidgets('renders boxen plot styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleBoxenPlotChart(
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

      expect(find.byType(SimpleBoxenPlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders boxen plot references and compact bands', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBoxenPlotChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              maxDepth: 3,
              showValues: false,
              showWhiskers: false,
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

    expect(find.byType(SimpleBoxenPlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows boxen plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBoxenPlotChart(data: data, minValue: 0, maxValue: 100),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 98));
    await tester.pump();

    expect(find.text('Control'), findsWidgets);
    expect(find.text('Median'), findsOneWidget);
    expect(find.text('64'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes boxen tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;
    int? tappedSamples;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBoxenPlotChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onBoxTap: (item, index, summary) {
                tappedLabel = item.label;
                tappedIndex = index;
                tappedSamples = summary.sampleCount;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 98));
    await tester.pump();

    expect(tappedLabel, 'Control');
    expect(tappedIndex, 0);
    expect(tappedSamples, 9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default boxen plot semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBoxenPlotChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Boxen plot chart, 3 categories\. Control median 64, range 34-88, 9 samples',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
