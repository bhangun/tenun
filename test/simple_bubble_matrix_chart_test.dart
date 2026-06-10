import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const xLabels = ['Speed', 'Quality', 'Reach', 'Risk'];
  const yLabels = ['Core', 'Growth', 'Learning'];
  const cells = [
    SimpleBubbleMatrixCell(xLabel: 'Speed', yLabel: 'Core', value: 82),
    SimpleBubbleMatrixCell(xLabel: 'Quality', yLabel: 'Core', value: 76),
    SimpleBubbleMatrixCell(xLabel: 'Reach', yLabel: 'Core', value: 68),
    SimpleBubbleMatrixCell(xLabel: 'Risk', yLabel: 'Core', value: 42),
    SimpleBubbleMatrixCell(xLabel: 'Speed', yLabel: 'Growth', value: 74),
    SimpleBubbleMatrixCell(xLabel: 'Quality', yLabel: 'Growth', value: 70),
    SimpleBubbleMatrixCell(xLabel: 'Reach', yLabel: 'Growth', value: 86),
    SimpleBubbleMatrixCell(xLabel: 'Risk', yLabel: 'Growth', value: 54),
    SimpleBubbleMatrixCell(xLabel: 'Speed', yLabel: 'Learning', value: 66),
    SimpleBubbleMatrixCell(xLabel: 'Quality', yLabel: 'Learning', value: 84),
    SimpleBubbleMatrixCell(xLabel: 'Reach', yLabel: 'Learning', value: 58),
    SimpleBubbleMatrixCell(xLabel: 'Risk', yLabel: 'Learning', value: 34),
  ];

  testWidgets('renders bubble matrix styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleBubbleMatrixChart(
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

      expect(find.byType(SimpleBubbleMatrixChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact bubble matrix without labels or legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 220,
            child: SimpleBubbleMatrixChart(
              cells: cells,
              showXLabels: false,
              showYLabels: false,
              showLegend: false,
              showValues: false,
              useColorScale: false,
              minValue: 0,
              maxValue: 100,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleBubbleMatrixChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows bubble matrix tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBubbleMatrixChart(
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

    await tester.tapAt(const Offset(118, 59));
    await tester.pump();

    expect(find.text('Core / Speed'), findsOneWidget);
    expect(find.text('82'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes bubble matrix tap callback without tooltip', (
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
            child: SimpleBubbleMatrixChart(
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

    await tester.tapAt(const Offset(118, 59));
    await tester.pump();

    expect(tappedX, 'Speed');
    expect(tappedY, 'Core');
    expect(tappedRow, 0);
    expect(tappedColumn, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default bubble matrix semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBubbleMatrixChart(
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
        RegExp(r'Bubble matrix chart, 3 rows and 4 columns\. Core Speed 82'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
