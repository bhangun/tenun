import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const points = [
    SimpleContinuousHeatmapPoint(label: 'Onboard A', x: 12, y: 82),
    SimpleContinuousHeatmapPoint(label: 'Onboard B', x: 18, y: 76),
    SimpleContinuousHeatmapPoint(label: 'Explore', x: 32, y: 64),
    SimpleContinuousHeatmapPoint(label: 'Adopt', x: 48, y: 52),
    SimpleContinuousHeatmapPoint(label: 'Support', x: 66, y: 44),
    SimpleContinuousHeatmapPoint(label: 'Renew A', x: 84, y: 28),
    SimpleContinuousHeatmapPoint(label: 'Renew B', x: 88, y: 22),
  ];

  testWidgets('renders continuous heatmap styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleContinuousHeatmapChart(
                points: points,
                xBins: 4,
                yBins: 4,
                minX: 0,
                maxX: 100,
                minY: 0,
                maxY: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleContinuousHeatmapChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders provided bins in compact mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 220,
            child: SimpleContinuousHeatmapChart(
              bins: [
                SimpleContinuousHeatmapBin(
                  xIndex: 0,
                  yIndex: 0,
                  xStart: 0,
                  xEnd: 10,
                  yStart: 0,
                  yEnd: 10,
                  value: 4,
                  pointCount: 4,
                  label: 'Low left',
                ),
                SimpleContinuousHeatmapBin(
                  xIndex: 1,
                  yIndex: 1,
                  xStart: 10,
                  xEnd: 20,
                  yStart: 10,
                  yEnd: 20,
                  value: 8,
                  pointCount: 8,
                  label: 'High right',
                ),
              ],
              xBins: 2,
              yBins: 2,
              showXLabels: false,
              showYLabels: false,
              showLegend: false,
              showValues: false,
              minValue: 0,
              maxValue: 10,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleContinuousHeatmapChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows continuous heatmap tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleContinuousHeatmapChart(
              points: points,
              xBins: 4,
              yBins: 4,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(112, 52));
    await tester.pump();

    expect(find.text('75-100 / 0-25'), findsOneWidget);
    expect(find.text('Onboard A / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes continuous heatmap tap callback without tooltip', (
    tester,
  ) async {
    SimpleContinuousHeatmapBin? tappedBin;
    int? tappedRow;
    int? tappedColumn;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleContinuousHeatmapChart(
              points: points,
              xBins: 4,
              yBins: 4,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              showTooltip: false,
              onBinTap: (bin, rowIndex, columnIndex) {
                tappedBin = bin;
                tappedRow = rowIndex;
                tappedColumn = columnIndex;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(112, 52));
    await tester.pump();

    expect(tappedBin?.xIndex, 0);
    expect(tappedBin?.yIndex, 3);
    expect(tappedBin?.pointCount, 2);
    expect(tappedBin?.value, 2);
    expect(tappedRow, 0);
    expect(tappedColumn, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default continuous heatmap semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleContinuousHeatmapChart(
              points: points,
              xBins: 4,
              yBins: 4,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Continuous heatmap chart, 4 rows and 4 columns\. '
          r'Peak 0-25 by 75-100 2 from 2 points\.',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
