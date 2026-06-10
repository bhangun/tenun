import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const xLabels = ['SMB', 'Mid', 'Enterprise'];
  const yLabels = ['Online', 'Partner', 'Field'];
  const cells = [
    SimpleMosaicPlotCell(xLabel: 'SMB', yLabel: 'Online', value: 32),
    SimpleMosaicPlotCell(xLabel: 'SMB', yLabel: 'Partner', value: 18),
    SimpleMosaicPlotCell(xLabel: 'SMB', yLabel: 'Field', value: 10),
    SimpleMosaicPlotCell(xLabel: 'Mid', yLabel: 'Online', value: 24),
    SimpleMosaicPlotCell(xLabel: 'Mid', yLabel: 'Partner', value: 28),
    SimpleMosaicPlotCell(xLabel: 'Mid', yLabel: 'Field', value: 22),
    SimpleMosaicPlotCell(xLabel: 'Enterprise', yLabel: 'Online', value: 18),
    SimpleMosaicPlotCell(xLabel: 'Enterprise', yLabel: 'Partner', value: 34),
    SimpleMosaicPlotCell(xLabel: 'Enterprise', yLabel: 'Field', value: 46),
  ];

  testWidgets('renders mosaic plot styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleMosaicPlotChart(
                xLabels: xLabels,
                yLabels: yLabels,
                cells: cells,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleMosaicPlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders mosaic plot without labels or legend', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMosaicPlotChart(
              xLabels: xLabels,
              yLabels: yLabels,
              cells: cells,
              showLegend: false,
              showValues: false,
              showPercentages: false,
              showCellLabels: false,
              showColumnTotals: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleMosaicPlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows mosaic plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMosaicPlotChart(
              xLabels: xLabels,
              yLabels: yLabels,
              cells: cells,
              showLegend: false,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(50, 200));
    await tester.pump();

    expect(find.text('SMB'), findsWidgets);
    expect(find.text('Online'), findsWidgets);
    expect(find.text('32'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes mosaic plot cell tap callback without tooltip', (
    tester,
  ) async {
    String? tappedX;
    String? tappedY;
    int? tappedXIndex;
    int? tappedYIndex;
    double? tappedValue;
    double? tappedShare;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMosaicPlotChart(
              xLabels: xLabels,
              yLabels: yLabels,
              cells: cells,
              showLegend: false,
              showTooltip: false,
              onCellTap: (cell, share, xIndex, yIndex) {
                tappedX = cell.xLabel;
                tappedY = cell.yLabel;
                tappedValue = cell.value;
                tappedShare = share;
                tappedXIndex = xIndex;
                tappedYIndex = yIndex;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(50, 200));
    await tester.pump();

    expect(tappedX, 'SMB');
    expect(tappedY, 'Online');
    expect(tappedValue, 32);
    expect(tappedShare, closeTo(32 / 60, 0.001));
    expect(tappedXIndex, 0);
    expect(tappedYIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default mosaic plot semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMosaicPlotChart(
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
        RegExp(r'Mosaic plot chart, 3 categories and 3 groups\. SMB total 60'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
