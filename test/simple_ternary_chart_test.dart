import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const points = [
    SimpleTernaryPoint(
      label: 'Balanced',
      a: 34,
      b: 33,
      c: 33,
      size: 34,
      group: 'Core',
    ),
    SimpleTernaryPoint(
      label: 'Fast Track',
      a: 58,
      b: 26,
      c: 16,
      size: 42,
      group: 'Speed',
    ),
    SimpleTernaryPoint(
      label: 'Quality Led',
      a: 22,
      b: 60,
      c: 18,
      size: 36,
      group: 'Quality',
    ),
    SimpleTernaryPoint(
      label: 'Cost Guard',
      a: 20,
      b: 24,
      c: 56,
      size: 30,
      group: 'Efficiency',
    ),
  ];

  testWidgets('renders ternary styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleTernaryChart(points: points, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleTernaryChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders ternary with values and compact grid', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTernaryChart(
              points: points,
              aAxisLabel: 'Speed',
              bAxisLabel: 'Quality',
              cAxisLabel: 'Cost',
              showValues: true,
              showLegend: false,
              gridLineCount: 5,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleTernaryChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows ternary tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTernaryChart(
              points: points,
              aAxisLabel: 'Speed',
              bAxisLabel: 'Quality',
              cAxisLabel: 'Cost',
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(230, 129));
    await tester.pump();

    expect(find.text('Balanced'), findsWidgets);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('Cost'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes ternary point tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    SimpleTernaryShare? tappedShare;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTernaryChart(
              points: points,
              showTooltip: false,
              onPointTap: (point, index, share) {
                tappedLabel = point.label;
                tappedIndex = index;
                tappedShare = share;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(230, 129));
    await tester.pump();

    expect(tappedLabel, 'Balanced');
    expect(tappedIndex, 0);
    expect(tappedShare?.a, closeTo(0.34, 0.01));
    expect(tappedShare?.b, closeTo(0.33, 0.01));
    expect(tappedShare?.c, closeTo(0.33, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default ternary semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTernaryChart(points: points),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Ternary chart, 4 points\. Balanced A 34%, B 33%, C 33%'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
