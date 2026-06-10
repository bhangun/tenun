import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleRadialBarChartData(label: 'Revenue', value: 74, targetValue: 82),
    SimpleRadialBarChartData(label: 'Retention', value: 91, targetValue: 88),
    SimpleRadialBarChartData(label: 'Quality', value: 86, targetValue: 90),
    SimpleRadialBarChartData(label: 'Delivery', value: 68, targetValue: 75),
  ];

  testWidgets('renders radial bar styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleRadialBarChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleRadialBarChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact radial bar without legend or targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 240,
            child: SimpleRadialBarChart(
              data: data,
              showLegend: false,
              showLabels: false,
              showTargets: false,
              centerLabel: 'Health',
              centerValue: '80%',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleRadialBarChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows radial bar tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRadialBarChart(data: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(145, 38));
    await tester.pump();

    expect(find.text('Revenue'), findsWidgets);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.textContaining('74'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes radial bar tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedProgress;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRadialBarChart(
              data: data,
              showTooltip: false,
              onRingTap: (item, index, progress) {
                tappedLabel = item.label;
                tappedIndex = index;
                tappedProgress = progress;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(145, 38));
    await tester.pump();

    expect(tappedLabel, 'Revenue');
    expect(tappedIndex, 0);
    expect(tappedProgress, closeTo(0.74, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default radial bar semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRadialBarChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Radial bar chart, 4 rings\. Revenue 74 of 100, 74%, target 82',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
