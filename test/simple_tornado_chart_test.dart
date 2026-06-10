import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleTornadoChartData(label: 'Demand', low: 58, high: 90),
    SimpleTornadoChartData(label: 'Pricing', low: 62, high: 86),
    SimpleTornadoChartData(label: 'Delivery', low: 66, high: 82),
    SimpleTornadoChartData(label: 'Support', low: 68, high: 79),
  ];

  testWidgets('renders tornado styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 280,
              child: SimpleTornadoChart(data: data, baseline: 72, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleTornadoChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows tornado tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 280,
            child: SimpleTornadoChart(
              data: data,
              baseline: 72,
              lowLabel: 'Low case',
              highLabel: 'High case',
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(360, 56));
    await tester.pump();

    expect(find.text('Demand'), findsWidgets);
    expect(find.text('High case'), findsWidgets);
    expect(find.text('90'), findsWidgets);
    expect(find.text('+18'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes tornado tap callback without tooltip', (tester) async {
    String? tappedLabel;
    SimpleTornadoSide? tappedSide;
    int? tappedIndex;
    double? tappedValue;
    double? tappedDelta;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 280,
            child: SimpleTornadoChart(
              data: data,
              baseline: 72,
              showTooltip: false,
              onBarTap: (item, index, side, value, delta) {
                tappedLabel = item.label;
                tappedSide = side;
                tappedIndex = index;
                tappedValue = value;
                tappedDelta = delta;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(360, 56));
    await tester.pump();

    expect(tappedLabel, 'Demand');
    expect(tappedSide, SimpleTornadoSide.high);
    expect(tappedIndex, 0);
    expect(tappedValue, 90);
    expect(tappedDelta, 18);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders compact unsorted tornado chart', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 440,
            height: 240,
            child: SimpleTornadoChart(
              data: data,
              baseline: 72,
              sortByImpact: false,
              showValues: false,
              showLegend: false,
              showBaseline: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleTornadoChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default tornado semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 280,
            child: SimpleTornadoChart(data: data, baseline: 72),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Tornado chart, 4 drivers around baseline 72\. '
          r'Demand 58 to 90, impact 32',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
