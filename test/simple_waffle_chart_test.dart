import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleWaffleChartData(label: 'Completed', value: 42),
    SimpleWaffleChartData(label: 'In Progress', value: 28),
    SimpleWaffleChartData(label: 'Planned', value: 18),
    SimpleWaffleChartData(label: 'Open', value: 12),
  ];

  testWidgets('renders waffle styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleWaffleChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleWaffleChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders progress waffle with empty cells', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWaffleChart(
              data: [SimpleWaffleChartData(label: 'Readiness', value: 73)],
              totalValue: 100,
              showLegend: false,
              fillDirection: SimpleWaffleFillDirection.leftToRight,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleWaffleChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows waffle tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWaffleChart(data: data),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(38, 250));
    await tester.pump();

    expect(find.text('Completed'), findsWidgets);
    expect(find.text('42%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes waffle cell tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedShare;
    int? tappedCells;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWaffleChart(
              data: data,
              showTooltip: false,
              onCellTap: (item, index, share, cellCount) {
                tappedLabel = item.label;
                tappedIndex = index;
                tappedShare = share;
                tappedCells = cellCount;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(38, 250));
    await tester.pump();

    expect(tappedLabel, 'Completed');
    expect(tappedIndex, 0);
    expect(tappedShare, 0.42);
    expect(tappedCells, 42);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default waffle semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWaffleChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Waffle chart, 4 categories\. Completed 42, 42%'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
