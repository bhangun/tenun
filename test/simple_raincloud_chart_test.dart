import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleRaincloudChartData(
      label: 'Control',
      values: [34, 42, 54, 58, 64, 68, 72, 74, 88, 96],
    ),
    SimpleRaincloudChartData(
      label: 'Program A',
      values: [48, 58, 62, 66, 70, 76, 82, 86, 94, 98],
    ),
    SimpleRaincloudChartData(
      label: 'Program B',
      values: [38, 46, 50, 54, 58, 60, 66, 68, 78, 86],
    ),
  ];

  testWidgets('renders raincloud chart styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleRaincloudChart(
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

      expect(find.byType(SimpleRaincloudChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders raincloud chart with references and layers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleRaincloudChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              showValues: true,
              showMean: true,
              showOutliers: true,
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

    expect(find.byType(SimpleRaincloudChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows raincloud tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRaincloudChart(data: data, minValue: 0, maxValue: 100),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 128));
    await tester.pump();

    expect(find.text('Control'), findsWidgets);
    expect(find.text('Median'), findsOneWidget);
    expect(find.text('66'), findsWidgets);
    expect(find.text('Count'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes raincloud tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedMedian;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRaincloudChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onGroupTap: (item, index, stats) {
                tappedLabel = item.label;
                tappedIndex = index;
                tappedMedian = stats.median;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 128));
    await tester.pump();

    expect(tappedLabel, 'Control');
    expect(tappedIndex, 0);
    expect(tappedMedian, 66);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default raincloud semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRaincloudChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Raincloud chart, 3 groups\. Control count 10, median 66, range 34 to 96',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
