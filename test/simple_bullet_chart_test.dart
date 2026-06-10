import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleBulletChartData(
      label: 'Revenue',
      value: 74,
      target: 82,
      maxValue: 100,
      ranges: [
        SimpleBulletRange(from: 0, to: 60, color: Color(0xFFE2E8F0)),
        SimpleBulletRange(from: 60, to: 82, color: Color(0xFFCBD5E1)),
        SimpleBulletRange(from: 82, to: 100, color: Color(0xFF94A3B8)),
      ],
    ),
    SimpleBulletChartData(
      label: 'Retention',
      value: 91,
      target: 88,
      maxValue: 100,
    ),
  ];

  testWidgets('renders bullet styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 220,
              child: SimpleBulletChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleBulletChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows bullet tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: SimpleBulletChart(data: data),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(150, 60));
    await tester.pump();

    expect(find.text('Revenue'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes bullet tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: SimpleBulletChart(
              data: data,
              showTooltip: false,
              onBulletTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(150, 60));
    await tester.pump();

    expect(tappedLabel, 'Revenue');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default bullet semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 220,
            child: SimpleBulletChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Bullet chart, 2 items\. Revenue 74 of target 82'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
