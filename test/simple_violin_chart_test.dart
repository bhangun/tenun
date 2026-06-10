import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleViolinChartData(
      label: 'Control',
      values: [34, 42, 54, 58, 64, 68, 72, 74, 88, 96],
    ),
    SimpleViolinChartData(
      label: 'Program A',
      values: [48, 58, 62, 66, 70, 76, 82, 86, 94, 98],
    ),
    SimpleViolinChartData(
      label: 'Program B',
      values: [38, 46, 50, 54, 58, 60, 66, 68, 78, 86],
    ),
  ];

  testWidgets('renders violin styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleViolinChart(
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

      expect(find.byType(SimpleViolinChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders violin with references and no box overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleViolinChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              showBoxPlot: false,
              showMean: false,
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

    expect(find.byType(SimpleViolinChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows violin tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleViolinChart(data: data, minValue: 0, maxValue: 100),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 98));
    await tester.pump();

    expect(find.text('Control'), findsWidgets);
    expect(find.text('Median'), findsOneWidget);
    expect(find.text('66'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes violin tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleViolinChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onViolinTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default violin semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleViolinChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Violin chart, 3 categories\. Control count 10, min 34, median 66, max 96',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
