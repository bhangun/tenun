import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const xLabels = ['Mon', 'Tue', 'Wed', 'Thu'];
  const yLabels = ['Morning', 'Afternoon', 'Evening'];
  const cells = [
    SimpleHeatmapCell(xLabel: 'Mon', yLabel: 'Morning', value: 12),
    SimpleHeatmapCell(xLabel: 'Tue', yLabel: 'Morning', value: 18),
    SimpleHeatmapCell(xLabel: 'Wed', yLabel: 'Morning', value: 9),
    SimpleHeatmapCell(xLabel: 'Thu', yLabel: 'Morning', value: 15),
    SimpleHeatmapCell(xLabel: 'Mon', yLabel: 'Afternoon', value: 8),
    SimpleHeatmapCell(xLabel: 'Tue', yLabel: 'Afternoon', value: 14),
    SimpleHeatmapCell(xLabel: 'Wed', yLabel: 'Afternoon', value: 20),
    SimpleHeatmapCell(xLabel: 'Thu', yLabel: 'Afternoon', value: 11),
    SimpleHeatmapCell(xLabel: 'Mon', yLabel: 'Evening', value: 5),
    SimpleHeatmapCell(xLabel: 'Tue', yLabel: 'Evening', value: 10),
    SimpleHeatmapCell(xLabel: 'Wed', yLabel: 'Evening', value: 16),
    SimpleHeatmapCell(xLabel: 'Thu', yLabel: 'Evening', value: 8),
  ];

  testWidgets('renders heatmap styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleHeatmapChart(
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

      expect(find.byType(SimpleHeatmapChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact heatmap without labels or legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 220,
            child: SimpleHeatmapChart(
              cells: cells,
              showXLabels: false,
              showYLabels: false,
              showLegend: false,
              showValues: false,
              minValue: 0,
              maxValue: 25,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleHeatmapChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core heatmap config accepts flexible JSON values', (
    tester,
  ) async {
    final config = HeatmapChartConfig.fromJson({
      'type': 'heatmap',
      'title': {'text': 'Core heatmap'},
      'showValues': 'false',
      'lowColor': 'bad-color',
      'highColor': '#ff005f73',
      'data': [
        [
          '1',
          {'value': '2.5'},
          [0, '3'],
        ],
        [
          {'y': '4'},
          null,
          '6',
        ],
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 460, height: 280, child: config.buildChart()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(config.xLabels, ['Column 1', 'Column 2', 'Column 3']);
    expect(config.yLabels, ['Row 1', 'Row 2']);
    expect(config.data[0], [1, 2.5, 3]);
    expect(config.data[1], [4, 0, 6]);
    expect(config.showValues, isFalse);
    expect(find.byType(HeatmapChartWidget), findsOneWidget);
    expect(find.text('Core heatmap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows heatmap tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHeatmapChart(
              xLabels: xLabels,
              yLabels: yLabels,
              cells: cells,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(112, 60));
    await tester.pump();

    expect(find.text('Morning / Mon'), findsOneWidget);
    expect(find.text('12'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes heatmap tap callback without tooltip', (tester) async {
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
            child: SimpleHeatmapChart(
              xLabels: xLabels,
              yLabels: yLabels,
              cells: cells,
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

    await tester.tapAt(const Offset(112, 60));
    await tester.pump();

    expect(tappedX, 'Mon');
    expect(tappedY, 'Morning');
    expect(tappedRow, 0);
    expect(tappedColumn, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default heatmap semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHeatmapChart(
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
        RegExp(r'Heatmap chart, 3 rows and 4 columns\. Morning Mon 12'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
