import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleDumbbellChartData(label: 'Revenue', start: 42, end: 74),
    SimpleDumbbellChartData(label: 'Retention', start: 68, end: 81),
    SimpleDumbbellChartData(label: 'Costs', start: 54, end: 47),
    SimpleDumbbellChartData(label: 'Quality', start: 72, end: 86),
  ];

  testWidgets('renders dumbbell styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 440,
              height: 280,
              child: SimpleDumbbellChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDumbbellChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders vertical dumbbell with references', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 440,
            height: 280,
            child: SimpleDumbbellChart(
              data: data,
              orientation: SimpleBarChartOrientation.vertical,
              style: SimpleBarChartStyle.professional,
              referenceLines: [
                SimpleChartReferenceLine(value: 75, label: 'Goal'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 70, to: 85, label: 'Target'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDumbbellChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows dumbbell tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 440,
            height: 280,
            child: SimpleDumbbellChart(data: data),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(170, 50));
    await tester.pump();

    expect(find.text('Revenue'), findsWidgets);
    expect(find.text('+32'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes dumbbell tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 440,
            height: 280,
            child: SimpleDumbbellChart(
              data: data,
              showTooltip: false,
              onSegmentTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(170, 50));
    await tester.pump();

    expect(tappedLabel, 'Revenue');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default dumbbell semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 440,
            height: 280,
            child: SimpleDumbbellChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Dumbbell chart, 4 items\. Revenue 42 to 74, change \+32'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
