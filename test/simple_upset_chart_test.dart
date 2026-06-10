import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const sets = [
    SimpleUpsetSet(id: 'growth', label: 'Growth', value: 72),
    SimpleUpsetSet(id: 'product', label: 'Product', value: 64),
    SimpleUpsetSet(id: 'learning', label: 'Learning', value: 52),
  ];

  const intersections = [
    SimpleUpsetIntersection(
      setIds: ['growth'],
      value: 38,
      label: 'Growth only',
    ),
    SimpleUpsetIntersection(
      setIds: ['product'],
      value: 30,
      label: 'Product only',
    ),
    SimpleUpsetIntersection(
      setIds: ['learning'],
      value: 22,
      label: 'Learning only',
    ),
    SimpleUpsetIntersection(
      setIds: ['growth', 'product'],
      value: 34,
      label: 'Growth + Product',
    ),
    SimpleUpsetIntersection(
      setIds: ['growth', 'learning'],
      value: 22,
      label: 'Growth + Learning',
    ),
    SimpleUpsetIntersection(
      setIds: ['product', 'learning'],
      value: 18,
      label: 'Product + Learning',
    ),
    SimpleUpsetIntersection(
      setIds: ['growth', 'product', 'learning'],
      value: 12,
      label: 'All three',
    ),
  ];

  testWidgets('renders upset styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 480,
              height: 300,
              child: SimpleUpsetChart(
                sets: sets,
                intersections: intersections,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleUpsetChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders narrow upset without labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 170,
            height: 220,
            child: SimpleUpsetChart(
              sets: sets,
              intersections: intersections,
              showSetLabels: false,
              showIntersectionLabels: false,
              showValues: false,
              maxIntersections: 4,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleUpsetChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows upset intersection tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 300,
            child: SimpleUpsetChart(sets: sets, intersections: intersections),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(164, 210));
    await tester.pump();

    expect(find.text('Growth + Product'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('Growth, Product'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes upset callback without tooltip', (tester) async {
    String? tappedLabel;
    double? tappedValue;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 300,
            child: SimpleUpsetChart(
              sets: sets,
              intersections: intersections,
              showTooltip: false,
              onIntersectionTap: (intersection, index) {
                tappedLabel = intersection.label;
                tappedValue = intersection.value;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(164, 210));
    await tester.pump();

    expect(tappedLabel, 'Growth + Product');
    expect(tappedValue, 34);
    expect(tappedIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default upset semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 300,
            child: SimpleUpsetChart(sets: sets, intersections: intersections),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'UpSet chart, 3 sets and 7 intersections\. Growth only 38'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
