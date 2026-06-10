import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const sets = [
    SimpleVennSet(id: 'growth', label: 'Growth', value: 72),
    SimpleVennSet(id: 'product', label: 'Product', value: 64),
    SimpleVennSet(id: 'learning', label: 'Learning', value: 52),
  ];

  const intersections = [
    SimpleVennIntersection(
      setIds: ['growth', 'product'],
      value: 34,
      label: 'Growth + Product',
    ),
    SimpleVennIntersection(
      setIds: ['growth', 'learning'],
      value: 22,
      label: 'Growth + Learning',
    ),
    SimpleVennIntersection(
      setIds: ['product', 'learning'],
      value: 18,
      label: 'Product + Learning',
    ),
    SimpleVennIntersection(
      setIds: ['growth', 'product', 'learning'],
      value: 12,
      label: 'All three',
    ),
  ];

  testWidgets('renders venn styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 300,
              child: SimpleVennChart(
                sets: sets,
                intersections: intersections,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleVennChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders two-set narrow venn without labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 220,
            child: SimpleVennChart(
              sets: [
                SimpleVennSet(id: 'a', label: 'A', value: 40),
                SimpleVennSet(id: 'b', label: 'B', value: 36),
              ],
              intersections: [
                SimpleVennIntersection(setIds: ['a', 'b'], value: 18),
              ],
              showLabels: false,
              showValues: false,
              showLegend: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleVennChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows venn intersection tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleVennChart(sets: sets, intersections: intersections),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(230, 152));
    await tester.pump();

    expect(find.text('All three'), findsWidgets);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Growth, Learning, Product'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes venn intersection callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleVennChart(
              sets: sets,
              intersections: intersections,
              showTooltip: false,
              onIntersectionTap: (intersection) {
                tappedLabel = intersection.label;
                tappedValue = intersection.value;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(230, 152));
    await tester.pump();

    expect(tappedLabel, 'All three');
    expect(tappedValue, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default venn semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleVennChart(sets: sets, intersections: intersections),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Venn chart, 3 sets and 4 intersections\. Growth 72'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
