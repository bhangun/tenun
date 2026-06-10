import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleErrorBarData(label: 'North', value: 72, lower: 66, upper: 78),
    SimpleErrorBarData(label: 'South', value: 68, lower: 62, upper: 74),
    SimpleErrorBarData(label: 'East', value: 84, lower: 77, upper: 91),
    SimpleErrorBarData(label: 'West', value: 76, lower: 70, upper: 83),
  ];

  testWidgets('renders error bar styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleErrorBarChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleErrorBarChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders horizontal error bars with references', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleErrorBarChart(
              data: data,
              orientation: SimpleBarChartOrientation.horizontal,
              minValue: 50,
              maxValue: 100,
              showErrorLabels: true,
              referenceLines: [
                SimpleChartReferenceLine(value: 75, label: 'Plan'),
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

    expect(find.byType(SimpleErrorBarChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows error bar tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleErrorBarChart(data: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(97, 157));
    await tester.pump();

    expect(find.text('North'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('72'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes error bar tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleErrorBarChart(
              data: data,
              showTooltip: false,
              onPointTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(97, 157));
    await tester.pump();

    expect(tappedLabel, 'North');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default error bar semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleErrorBarChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Error bar chart, 4 points\. North value 72, interval 66 to 78',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
