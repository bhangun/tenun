import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const variables = ['Speed', 'Quality', 'Cost', 'Risk'];
  const correlations = [
    SimpleCorrelationCell(xLabel: 'Speed', yLabel: 'Quality', value: 0.62),
    SimpleCorrelationCell(xLabel: 'Speed', yLabel: 'Cost', value: -0.48),
    SimpleCorrelationCell(xLabel: 'Speed', yLabel: 'Risk', value: -0.36),
    SimpleCorrelationCell(xLabel: 'Quality', yLabel: 'Cost', value: -0.22),
    SimpleCorrelationCell(xLabel: 'Quality', yLabel: 'Risk', value: -0.58),
    SimpleCorrelationCell(xLabel: 'Cost', yLabel: 'Risk', value: 0.44),
  ];

  testWidgets('renders correlation matrix styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 300,
              child: SimpleCorrelationMatrixChart(
                variables: variables,
                correlations: correlations,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleCorrelationMatrixChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders upper triangle correlation matrix without values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 220,
            child: SimpleCorrelationMatrixChart(
              variables: variables,
              correlations: correlations,
              showUpperTriangleOnly: true,
              showDiagonal: false,
              showValues: false,
              showLegend: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleCorrelationMatrixChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows correlation tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleCorrelationMatrixChart(
              variables: variables,
              correlations: correlations,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 112));
    await tester.pump();

    expect(find.text('Quality vs Speed'), findsOneWidget);
    expect(find.text('0.62'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes correlation tap callback without tooltip', (
    tester,
  ) async {
    String? tappedX;
    String? tappedY;
    double? tappedValue;
    int? tappedRow;
    int? tappedColumn;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleCorrelationMatrixChart(
              variables: variables,
              correlations: correlations,
              showTooltip: false,
              onCellTap: (cell, rowIndex, columnIndex) {
                tappedX = cell.xLabel;
                tappedY = cell.yLabel;
                tappedValue = cell.value;
                tappedRow = rowIndex;
                tappedColumn = columnIndex;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(117, 112));
    await tester.pump();

    expect(tappedX, 'Speed');
    expect(tappedY, 'Quality');
    expect(tappedValue, 0.62);
    expect(tappedRow, 1);
    expect(tappedColumn, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default correlation semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleCorrelationMatrixChart(
              variables: variables,
              correlations: correlations,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Correlation matrix, 4 variables and \d+ correlations\.'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
