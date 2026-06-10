import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const ringLabels = ['Morning', 'Midday', 'Evening'];
  const segmentLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  const cells = [
    SimpleRadialHeatmapCell(
      ringLabel: 'Morning',
      segmentLabel: 'Mon',
      value: 32,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Morning',
      segmentLabel: 'Tue',
      value: 46,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Morning',
      segmentLabel: 'Wed',
      value: 39,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Morning',
      segmentLabel: 'Thu',
      value: 52,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Morning',
      segmentLabel: 'Fri',
      value: 58,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Midday',
      segmentLabel: 'Mon',
      value: 41,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Midday',
      segmentLabel: 'Tue',
      value: 63,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Midday',
      segmentLabel: 'Wed',
      value: 71,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Midday',
      segmentLabel: 'Thu',
      value: 66,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Midday',
      segmentLabel: 'Fri',
      value: 76,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Evening',
      segmentLabel: 'Mon',
      value: 28,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Evening',
      segmentLabel: 'Tue',
      value: 36,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Evening',
      segmentLabel: 'Wed',
      value: 44,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Evening',
      segmentLabel: 'Thu',
      value: 38,
    ),
    SimpleRadialHeatmapCell(
      ringLabel: 'Evening',
      segmentLabel: 'Fri',
      value: 49,
    ),
  ];

  testWidgets('renders radial heatmap styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleRadialHeatmapChart(
                ringLabels: ringLabels,
                segmentLabels: segmentLabels,
                cells: cells,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleRadialHeatmapChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact radial heatmap without labels or legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 220,
            child: SimpleRadialHeatmapChart(
              cells: cells,
              showRingLabels: false,
              showSegmentLabels: false,
              showLegend: false,
              showValues: true,
              showCenterHole: false,
              minValue: 0,
              maxValue: 100,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleRadialHeatmapChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows radial heatmap tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRadialHeatmapChart(
              ringLabels: ringLabels,
              segmentLabels: segmentLabels,
              cells: cells,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(211, 104));
    await tester.pump();

    expect(find.text('Morning / Mon'), findsOneWidget);
    expect(find.text('32'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes radial heatmap tap callback without tooltip', (
    tester,
  ) async {
    String? tappedRing;
    String? tappedSegment;
    int? tappedRingIndex;
    int? tappedSegmentIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRadialHeatmapChart(
              ringLabels: ringLabels,
              segmentLabels: segmentLabels,
              cells: cells,
              showTooltip: false,
              onCellTap: (cell, ringIndex, segmentIndex) {
                tappedRing = cell.ringLabel;
                tappedSegment = cell.segmentLabel;
                tappedRingIndex = ringIndex;
                tappedSegmentIndex = segmentIndex;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(211, 104));
    await tester.pump();

    expect(tappedRing, 'Morning');
    expect(tappedSegment, 'Mon');
    expect(tappedRingIndex, 0);
    expect(tappedSegmentIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default radial heatmap semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRadialHeatmapChart(
              ringLabels: ringLabels,
              segmentLabels: segmentLabels,
              cells: cells,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Radial heatmap chart, 3 rings and 5 segments\. Morning Mon 32',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
