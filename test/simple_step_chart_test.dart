import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const committed = SimpleTrendSeries(
    name: 'Committed',
    points: [
      SimpleTrendPoint(label: 'Jan', value: 24),
      SimpleTrendPoint(label: 'Feb', value: 24),
      SimpleTrendPoint(label: 'Mar', value: 36),
      SimpleTrendPoint(label: 'Apr', value: 36),
      SimpleTrendPoint(label: 'May', value: 48),
      SimpleTrendPoint(label: 'Jun', value: 64),
    ],
  );

  const demand = SimpleTrendSeries(
    name: 'Demand',
    lineStyle: SimpleTrendLineStyle.dashed,
    points: [
      SimpleTrendPoint(label: 'Jan', value: 18),
      SimpleTrendPoint(label: 'Feb', value: 28),
      SimpleTrendPoint(label: 'Mar', value: 31),
      SimpleTrendPoint(label: 'Apr', value: 42),
      SimpleTrendPoint(label: 'May', value: 46),
      SimpleTrendPoint(label: 'Jun', value: 58),
    ],
  );

  testWidgets('renders step styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleStepChart(series: const [committed], style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleStepChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders step modes and area without throwing', (tester) async {
    for (final mode in SimpleStepChartMode.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleStepChart(
                series: const [committed, demand],
                mode: mode,
                showArea: true,
                referenceLines: const [
                  SimpleChartReferenceLine(value: 40, label: 'Commit'),
                ],
                referenceBands: const [
                  SimpleChartReferenceBand(from: 32, to: 52, label: 'Window'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleStepChart), findsOneWidget);
      expect(find.text('Committed'), findsOneWidget);
      expect(find.text('Demand'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows step tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleStepChart(series: [committed]),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(206, 112));
    await tester.pump();

    expect(find.text('Mar'), findsWidgets);
    expect(find.text('Committed'), findsWidgets);
    expect(find.text('36'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes step tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;
    List<SimpleTrendTooltipItem>? tappedItems;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleStepChart(
              series: const [committed],
              showTooltip: false,
              onPointTap: (label, items, index) {
                tappedLabel = label;
                tappedItems = items;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(206, 112));
    await tester.pump();

    expect(tappedLabel, 'Mar');
    expect(tappedIndex, 2);
    expect(tappedItems?.single.value, 36);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default step semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleStepChart(series: [committed]),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Step chart, 1 series\. Committed from Jan 24 to Jun 64'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
