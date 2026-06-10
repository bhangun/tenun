import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleRoseChartData(label: 'Online', value: 42),
    SimpleRoseChartData(label: 'Partner', value: 28),
    SimpleRoseChartData(label: 'Field', value: 18),
    SimpleRoseChartData(label: 'Education', value: 12),
  ];

  testWidgets('renders rose styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleRoseChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleRoseChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders rose radius scale without legend and labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 240,
            child: SimpleRoseChart(
              data: data,
              scale: SimpleRoseScale.radius,
              showLegend: false,
              showLabels: false,
              maxValue: 50,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleRoseChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows rose tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRoseChart(data: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(202, 86));
    await tester.pump();

    expect(find.text('Online'), findsWidgets);
    expect(find.textContaining('42'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes rose tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedNormalizedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRoseChart(
              data: data,
              showTooltip: false,
              onSegmentTap: (item, index, normalizedValue) {
                tappedLabel = item.label;
                tappedIndex = index;
                tappedNormalizedValue = normalizedValue;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(202, 86));
    await tester.pump();

    expect(tappedLabel, 'Online');
    expect(tappedIndex, 0);
    expect(tappedNormalizedValue, closeTo(1, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default rose semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRoseChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Rose chart, 4 petals\. Online 42, 100% of max'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
