import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const labels = ['Speed', 'Quality', 'Risk'];
  const points = [
    SimpleScatterPlotMatrixPoint(
      label: 'Alpha',
      values: [20, 80, 40],
      group: 'Core',
    ),
    SimpleScatterPlotMatrixPoint(
      label: 'Beta',
      values: [45, 66, 52],
      group: 'Core',
    ),
    SimpleScatterPlotMatrixPoint(
      label: 'Gamma',
      values: [72, 58, 68],
      group: 'Growth',
    ),
    SimpleScatterPlotMatrixPoint(
      label: 'Delta',
      values: [88, 86, 35],
      group: 'Growth',
    ),
  ];

  testWidgets('renders scatter plot matrix styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 320,
              child: SimpleScatterPlotMatrixChart(
                variableLabels: labels,
                points: points,
                minValues: [0, 0, 0],
                maxValues: [100, 100, 100],
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleScatterPlotMatrixChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact matrix without labels or legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 240,
            child: SimpleScatterPlotMatrixChart(
              variableLabels: labels,
              points: points,
              minValues: [0, 0, 0],
              maxValues: [100, 100, 100],
              showVariableLabels: false,
              showLegend: false,
              showDiagonalHistograms: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleScatterPlotMatrixChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows scatter plot matrix tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 300,
            child: SimpleScatterPlotMatrixChart(
              variableLabels: labels,
              points: points,
              minValues: [0, 0, 0],
              maxValues: [100, 100, 100],
              showLegend: false,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(216, 81));
    await tester.pump();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('80'), findsWidgets);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('20'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes scatter plot matrix tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    String? tappedX;
    String? tappedY;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 300,
            child: SimpleScatterPlotMatrixChart(
              variableLabels: labels,
              points: points,
              minValues: const [0, 0, 0],
              maxValues: const [100, 100, 100],
              showLegend: false,
              showTooltip: false,
              onPointTap: (point, index, xVariable, yVariable) {
                tappedLabel = point.label;
                tappedIndex = index;
                tappedX = xVariable;
                tappedY = yVariable;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(216, 81));
    await tester.pump();

    expect(tappedLabel, 'Alpha');
    expect(tappedIndex, 0);
    expect(tappedX, 'Quality');
    expect(tappedY, 'Speed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default scatter plot matrix semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: SimpleScatterPlotMatrixChart(
              variableLabels: labels,
              points: points,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Scatter plot matrix chart, 3 variables \(Speed, Quality, Risk\) and 4 points\. Alpha Speed 20, Quality 80, Risk 40',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
