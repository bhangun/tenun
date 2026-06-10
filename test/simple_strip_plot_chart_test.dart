import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleStripPlotData(
      label: 'Control',
      values: [34, 42, 54, 58, 64, 68, 72, 74, 88, 96],
    ),
    SimpleStripPlotData(
      label: 'Program A',
      values: [48, 58, 62, 66, 70, 76, 82, 86, 94, 98],
    ),
    SimpleStripPlotData(
      label: 'Program B',
      values: [38, 46, 50, 54, 58, 60, 66, 68, 78, 86],
    ),
  ];

  testWidgets('renders strip plot styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleStripPlotChart(
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

      expect(find.byType(SimpleStripPlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders horizontal strip plot with references', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleStripPlotChart(
              data: data,
              orientation: SimpleBarChartOrientation.horizontal,
              minValue: 0,
              maxValue: 100,
              showValues: true,
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

    expect(find.byType(SimpleStripPlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows strip plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleStripPlotChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              jitter: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(114, 97));
    await tester.pump();

    expect(find.text('Control'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('64'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes strip plot tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedGroupIndex;
    int? tappedValueIndex;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleStripPlotChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              jitter: 0,
              showTooltip: false,
              onPointTap: (item, groupIndex, valueIndex, value) {
                tappedLabel = item.label;
                tappedGroupIndex = groupIndex;
                tappedValueIndex = valueIndex;
                tappedValue = value;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(114, 97));
    await tester.pump();

    expect(tappedLabel, 'Control');
    expect(tappedGroupIndex, 0);
    expect(tappedValueIndex, 4);
    expect(tappedValue, 64);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default strip plot semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleStripPlotChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Strip plot chart, 3 groups\. Control count 10, min 34, median 66, max 96',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
