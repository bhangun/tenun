import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleForestPlotData(
      label: 'Onboarding',
      estimate: 0.18,
      lower: 0.08,
      upper: 0.28,
      weight: 28,
      group: 'Growth',
    ),
    SimpleForestPlotData(
      label: 'Learning',
      estimate: 0.11,
      lower: -0.03,
      upper: 0.25,
      weight: 18,
      group: 'Education',
    ),
    SimpleForestPlotData(
      label: 'Support',
      estimate: -0.07,
      lower: -0.22,
      upper: 0.06,
      weight: 12,
      group: 'Ops',
    ),
    SimpleForestPlotData(
      label: 'Automation',
      estimate: 0.24,
      lower: 0.12,
      upper: 0.36,
      weight: 22,
      group: 'Platform',
    ),
  ];

  testWidgets('renders forest plot styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 520,
              height: 300,
              child: SimpleForestPlotChart(
                data: data,
                minValue: -0.4,
                maxValue: 0.4,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleForestPlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders narrow forest plot without labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 220,
            child: SimpleForestPlotChart(
              data: data,
              minValue: -0.4,
              maxValue: 0.4,
              showLabels: false,
              showValues: false,
              showGrid: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleForestPlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows forest plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleForestPlotChart(
              data: data,
              minValue: -0.4,
              maxValue: 0.4,
              showWeights: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(382, 50));
    await tester.pump();

    expect(find.text('Onboarding'), findsWidgets);
    expect(find.text('0.18'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes forest plot callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleForestPlotChart(
              data: data,
              minValue: -0.4,
              maxValue: 0.4,
              showTooltip: false,
              onItemTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(382, 50));
    await tester.pump();

    expect(tappedLabel, 'Onboarding');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default forest plot semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleForestPlotChart(
              data: data,
              minValue: -0.4,
              maxValue: 0.4,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Forest plot, 4 intervals\. Onboarding 0\.18'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
