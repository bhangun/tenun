import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const axes = [
    SimpleParallelAxis(label: 'Speed', min: 0, max: 100),
    SimpleParallelAxis(label: 'Quality', min: 0, max: 100),
    SimpleParallelAxis(label: 'Cost', min: 0, max: 100, inverted: true),
    SimpleParallelAxis(label: 'Risk', min: 0, max: 100, inverted: true),
    SimpleParallelAxis(label: 'Reach', min: 0, max: 100),
  ];

  const series = [
    SimpleParallelSeries(
      label: 'Current',
      values: [82, 76, 64, 58, 72],
      group: 'Baseline',
    ),
    SimpleParallelSeries(
      label: 'Target',
      values: [88, 84, 70, 45, 80],
      group: 'Plan',
    ),
    SimpleParallelSeries(
      label: 'Lean',
      values: [72, 70, 42, 36, 62],
      group: 'Option',
    ),
  ];

  testWidgets('renders parallel coordinates styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 520,
              height: 300,
              child: SimpleParallelCoordinatesChart(
                axes: axes,
                series: series,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleParallelCoordinatesChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders narrow parallel coordinates without labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 220,
            child: SimpleParallelCoordinatesChart(
              axes: axes,
              series: series,
              showLabels: false,
              showValues: false,
              showAxisRangeLabels: false,
              showLegend: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleParallelCoordinatesChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows parallel coordinates tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleParallelCoordinatesChart(axes: axes, series: series),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(108, 69));
    await tester.pump();

    expect(find.text('Current'), findsWidgets);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes parallel coordinates callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleParallelCoordinatesChart(
              axes: axes,
              series: series,
              showTooltip: false,
              onSeriesTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(108, 69));
    await tester.pump();

    expect(tappedLabel, 'Current');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default parallel coordinates semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleParallelCoordinatesChart(axes: axes, series: series),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Parallel coordinates chart, 5 axes and 3 series\. Current: Speed 82',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
