import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimplePopulationPyramidData(label: '18-24', leftValue: 42, rightValue: 38),
    SimplePopulationPyramidData(label: '25-34', leftValue: 48, rightValue: 45),
    SimplePopulationPyramidData(label: '35-44', leftValue: 36, rightValue: 40),
    SimplePopulationPyramidData(label: '45-54', leftValue: 24, rightValue: 29),
  ];

  testWidgets('renders population pyramid styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimplePopulationPyramidChart(
                data: data,
                leftLabel: 'Learners',
                rightLabel: 'Mentors',
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimplePopulationPyramidChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders population pyramid without legend or values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePopulationPyramidChart(
              data: data,
              showLegend: false,
              showValues: false,
              showCenterLabels: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimplePopulationPyramidChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows population pyramid tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePopulationPyramidChart(
              data: data,
              leftLabel: 'Learners',
              rightLabel: 'Mentors',
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(130, 72));
    await tester.pump();

    expect(find.text('18-24'), findsWidgets);
    expect(find.text('Learners'), findsWidgets);
    expect(find.text('42'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes population pyramid tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    SimplePopulationPyramidSide? tappedSide;
    int? tappedIndex;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePopulationPyramidChart(
              data: data,
              leftLabel: 'Learners',
              rightLabel: 'Mentors',
              showTooltip: false,
              onBarTap: (item, index, side, value) {
                tappedLabel = item.label;
                tappedSide = side;
                tappedIndex = index;
                tappedValue = value;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(130, 72));
    await tester.pump();

    expect(tappedLabel, '18-24');
    expect(tappedSide, SimplePopulationPyramidSide.left);
    expect(tappedIndex, 0);
    expect(tappedValue, 42);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default population pyramid semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePopulationPyramidChart(
              data: data,
              leftLabel: 'Learners',
              rightLabel: 'Mentors',
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Population pyramid chart, 4 groups\. 18-24 Learners 42, Mentors 38',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
