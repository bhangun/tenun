import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleBarChartData(label: 'Awareness', value: 42),
    SimpleBarChartData(label: 'Activation', value: 68),
    SimpleBarChartData(label: 'Retention', value: 55),
    SimpleBarChartData(label: 'Referral', value: 74),
  ];

  testWidgets('renders lollipop styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 260,
              child: SimpleLollipopChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleLollipopChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders horizontal lollipop with references', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleLollipopChart(
              data: data,
              orientation: SimpleBarChartOrientation.horizontal,
              style: SimpleBarChartStyle.professional,
              referenceLines: [
                SimpleChartReferenceLine(value: 60, label: 'Target'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 55, to: 75, label: 'Range'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleLollipopChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows lollipop tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleLollipopChart(data: data),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(95, 110));
    await tester.pump();

    expect(find.text('Awareness'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes lollipop tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleLollipopChart(
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

    await tester.tapAt(const Offset(95, 110));
    await tester.pump();

    expect(tappedLabel, 'Awareness');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default lollipop semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleLollipopChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Lollipop chart, 4 items\. Awareness 42, Activation 68'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
