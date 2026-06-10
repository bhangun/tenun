import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const points = [
    SimpleHexbinPoint(label: 'Quick Win', x: 20, y: 82, group: 'Growth'),
    SimpleHexbinPoint(label: 'Sprint', x: 22, y: 80, group: 'Growth'),
    SimpleHexbinPoint(label: 'Scale', x: 52, y: 74, group: 'Growth'),
    SimpleHexbinPoint(label: 'Platform', x: 72, y: 64, group: 'Core'),
    SimpleHexbinPoint(label: 'Cleanup', x: 38, y: 36, group: 'Core'),
    SimpleHexbinPoint(label: 'Support', x: 36, y: 34, group: 'Core'),
  ];

  testWidgets('renders hexbin styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleHexbinChart(
                points: points,
                minX: 0,
                maxX: 100,
                minY: 0,
                maxY: 100,
                style: style,
                cellRadius: 14,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleHexbinChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders narrow hexbin with empty cells and labels off', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 170,
            height: 220,
            child: SimpleHexbinChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              cellRadius: 10,
              showAxisLabels: false,
              showLegend: false,
              showValues: false,
              showEmptyBins: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleHexbinChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows hexbin tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHexbinChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              cellRadius: 14,
              xAxisLabel: 'Effort',
              yAxisLabel: 'Impact',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(129, 66));
    await tester.pump();

    expect(find.text('2 points'), findsOneWidget);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('Effort'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes hexbin bin tap callback without tooltip', (
    tester,
  ) async {
    int? tappedCount;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHexbinChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              cellRadius: 14,
              showTooltip: false,
              onBinTap: (bin) {
                tappedCount = bin.pointCount;
                tappedValue = bin.value;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(129, 66));
    await tester.pump();

    expect(tappedCount, 2);
    expect(tappedValue, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default hexbin semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHexbinChart(
              points: points,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              cellRadius: 14,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Hexbin chart, 6 points across \d+ bins\. Strongest bin 2'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
