import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleSinaPlotData(
      label: 'Control',
      values: [34, 42, 54, 58, 64, 68, 72, 74, 88, 96],
    ),
    SimpleSinaPlotData(
      label: 'Program A',
      values: [48, 58, 62, 66, 70, 76, 82, 86, 94, 98],
    ),
    SimpleSinaPlotData(
      label: 'Program B',
      values: [38, 46, 50, 54, 58, 60, 66, 68, 78, 86],
    ),
  ];

  testWidgets('renders sina plot styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleSinaPlotChart(
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

      expect(find.byType(SimpleSinaPlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders sina plot references and values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSinaPlotChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              showValues: true,
              densitySpreadFactor: 0.88,
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

    expect(find.byType(SimpleSinaPlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows sina plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSinaPlotChart(data: data, minValue: 0, maxValue: 100),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 97));
    await tester.pump();

    expect(find.text('Control'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('64'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes sina plot tap callback without tooltip', (tester) async {
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
            child: SimpleSinaPlotChart(
              data: data,
              minValue: 0,
              maxValue: 100,
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

    await tester.tapAt(const Offset(117, 97));
    await tester.pump();

    expect(tappedLabel, 'Control');
    expect(tappedGroupIndex, 0);
    expect(tappedValueIndex, 4);
    expect(tappedValue, 64);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default sina plot semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSinaPlotChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Sina plot chart, 3 groups\. Control count 10, min 34, median 66, max 96',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
