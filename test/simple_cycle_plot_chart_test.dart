import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const periods = ['Jan', 'Feb', 'Mar'];
  const cycles = ['2024', '2025', '2026'];
  const points = [
    SimpleCyclePlotPoint(periodLabel: 'Jan', cycleLabel: '2024', value: 38),
    SimpleCyclePlotPoint(periodLabel: 'Feb', cycleLabel: '2024', value: 44),
    SimpleCyclePlotPoint(periodLabel: 'Mar', cycleLabel: '2024', value: 51),
    SimpleCyclePlotPoint(periodLabel: 'Jan', cycleLabel: '2025', value: 42),
    SimpleCyclePlotPoint(periodLabel: 'Feb', cycleLabel: '2025', value: 49),
    SimpleCyclePlotPoint(periodLabel: 'Mar', cycleLabel: '2025', value: 56),
    SimpleCyclePlotPoint(periodLabel: 'Jan', cycleLabel: '2026', value: 47),
    SimpleCyclePlotPoint(periodLabel: 'Feb', cycleLabel: '2026', value: 54),
    SimpleCyclePlotPoint(periodLabel: 'Mar', cycleLabel: '2026', value: 61),
  ];

  testWidgets('renders cycle plot styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleCyclePlotChart(
                points: points,
                periodLabels: periods,
                cycleLabels: cycles,
                minValue: 0,
                maxValue: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleCyclePlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders cycle plot with average and reference band', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCyclePlotChart(
              points: points,
              periodLabels: periods,
              cycleLabels: cycles,
              minValue: 0,
              maxValue: 100,
              showValues: true,
              referenceBands: [
                SimpleChartReferenceBand(from: 50, to: 60, label: 'Target'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleCyclePlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows cycle plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCyclePlotChart(
              points: points,
              periodLabels: periods,
              cycleLabels: cycles,
              minValue: 0,
              maxValue: 100,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(247, 112));
    await tester.pump();

    expect(find.text('2025'), findsWidgets);
    expect(find.text('Jan'), findsWidgets);
    expect(find.text('42'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes cycle plot tap callback without tooltip', (
    tester,
  ) async {
    String? tappedCycle;
    int? tappedIndex;
    List<SimpleCyclePlotTooltipItem>? tappedItems;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCyclePlotChart(
              points: points,
              periodLabels: periods,
              cycleLabels: cycles,
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onPointTap: (cycleLabel, items, cycleIndex) {
                tappedCycle = cycleLabel;
                tappedItems = items;
                tappedIndex = cycleIndex;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(247, 112));
    await tester.pump();

    expect(tappedCycle, '2025');
    expect(tappedIndex, 1);
    expect(tappedItems?.first.periodLabel, 'Jan');
    expect(tappedItems?.first.value, 42);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default cycle plot semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCyclePlotChart(
              points: points,
              periodLabels: periods,
              cycleLabels: cycles,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Cycle plot chart, 3 periods across 3 cycles\. Jan average 42\.3',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
