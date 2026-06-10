import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleWaterfallChartData(label: 'Opening', value: 120, isTotal: true),
    SimpleWaterfallChartData(label: 'Sales', value: 48),
    SimpleWaterfallChartData(label: 'Churn', value: -18),
    SimpleWaterfallChartData(label: 'Expansion', value: 28),
    SimpleWaterfallChartData(label: 'Closing', value: 178, isTotal: true),
  ];

  testWidgets('renders waterfall styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleWaterfallChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleWaterfallChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders waterfall with references and custom range', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWaterfallChart(
              data: data,
              style: SimpleBarChartStyle.professional,
              minValue: 80,
              maxValue: 200,
              referenceLines: [
                SimpleChartReferenceLine(value: 170, label: 'Plan'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 160, to: 190, label: 'Target'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleWaterfallChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows waterfall tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWaterfallChart(data: data),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(86, 120));
    await tester.pump();

    expect(find.text('Opening'), findsWidgets);
    expect(find.text('Running total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes waterfall tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedTotal;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWaterfallChart(
              data: data,
              showTooltip: false,
              onBarTap: (item, index, start, end, runningTotal) {
                tappedLabel = item.label;
                tappedIndex = index;
                tappedTotal = runningTotal;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(86, 120));
    await tester.pump();

    expect(tappedLabel, 'Opening');
    expect(tappedIndex, 0);
    expect(tappedTotal, 120);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default waterfall semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWaterfallChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Waterfall chart, 5 items\. Opening total 120, Sales change \+48',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
