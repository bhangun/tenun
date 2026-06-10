import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const xLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  const yLabels = ['Morning', 'Midday', 'Evening'];
  const cells = [
    SimplePunchCardCell(xLabel: 'Mon', yLabel: 'Morning', value: 32),
    SimplePunchCardCell(xLabel: 'Tue', yLabel: 'Morning', value: 46),
    SimplePunchCardCell(xLabel: 'Wed', yLabel: 'Morning', value: 39),
    SimplePunchCardCell(xLabel: 'Thu', yLabel: 'Morning', value: 52),
    SimplePunchCardCell(xLabel: 'Fri', yLabel: 'Morning', value: 58),
    SimplePunchCardCell(xLabel: 'Mon', yLabel: 'Midday', value: 41),
    SimplePunchCardCell(xLabel: 'Tue', yLabel: 'Midday', value: 63),
    SimplePunchCardCell(xLabel: 'Wed', yLabel: 'Midday', value: 71),
    SimplePunchCardCell(xLabel: 'Thu', yLabel: 'Midday', value: 66),
    SimplePunchCardCell(xLabel: 'Fri', yLabel: 'Midday', value: 76),
    SimplePunchCardCell(xLabel: 'Mon', yLabel: 'Evening', value: 28),
    SimplePunchCardCell(xLabel: 'Tue', yLabel: 'Evening', value: 36),
    SimplePunchCardCell(xLabel: 'Wed', yLabel: 'Evening', value: 44),
    SimplePunchCardCell(xLabel: 'Thu', yLabel: 'Evening', value: 38),
    SimplePunchCardCell(xLabel: 'Fri', yLabel: 'Evening', value: 49),
  ];

  testWidgets('renders punch card styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimplePunchCardChart(
                xLabels: xLabels,
                yLabels: yLabels,
                cells: cells,
                minValue: 0,
                maxValue: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimplePunchCardChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact punch card without labels or legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 220,
            child: SimplePunchCardChart(
              cells: cells,
              showXLabels: false,
              showYLabels: false,
              showLegend: false,
              useColorScale: false,
              minValue: 0,
              maxValue: 100,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimplePunchCardChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows punch card tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePunchCardChart(
              xLabels: xLabels,
              yLabels: yLabels,
              cells: cells,
              minValue: 0,
              maxValue: 100,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(109, 60));
    await tester.pump();

    expect(find.text('Morning / Mon'), findsOneWidget);
    expect(find.text('32'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes punch card tap callback without tooltip', (
    tester,
  ) async {
    String? tappedX;
    String? tappedY;
    int? tappedRow;
    int? tappedColumn;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePunchCardChart(
              xLabels: xLabels,
              yLabels: yLabels,
              cells: cells,
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onCellTap: (cell, rowIndex, columnIndex) {
                tappedX = cell.xLabel;
                tappedY = cell.yLabel;
                tappedRow = rowIndex;
                tappedColumn = columnIndex;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(109, 60));
    await tester.pump();

    expect(tappedX, 'Mon');
    expect(tappedY, 'Morning');
    expect(tappedRow, 0);
    expect(tappedColumn, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default punch card semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePunchCardChart(
              xLabels: xLabels,
              yLabels: yLabels,
              cells: cells,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Punch card chart, 3 rows and 5 columns\. Morning Mon 32'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
