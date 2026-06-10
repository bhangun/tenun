import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const points = [
    SimpleFanChartPoint(
      label: 'Jul',
      value: 78,
      bands: [
        SimpleFanChartBand(label: '80%', lower: 66, upper: 91),
        SimpleFanChartBand(label: '50%', lower: 72, upper: 84),
      ],
    ),
    SimpleFanChartPoint(
      label: 'Aug',
      value: 84,
      bands: [
        SimpleFanChartBand(label: '80%', lower: 68, upper: 101),
        SimpleFanChartBand(label: '50%', lower: 76, upper: 92),
      ],
    ),
    SimpleFanChartPoint(
      label: 'Sep',
      value: 91,
      bands: [
        SimpleFanChartBand(label: '80%', lower: 70, upper: 114),
        SimpleFanChartBand(label: '50%', lower: 81, upper: 101),
      ],
    ),
    SimpleFanChartPoint(
      label: 'Oct',
      value: 98,
      bands: [
        SimpleFanChartBand(label: '80%', lower: 73, upper: 126),
        SimpleFanChartBand(label: '50%', lower: 87, upper: 109),
      ],
    ),
  ];

  testWidgets('renders fan styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleFanChart(points: points, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleFanChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders fan with references and values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFanChart(
              points: points,
              valueLabel: 'Revenue',
              showValues: true,
              referenceLines: [
                SimpleChartReferenceLine(value: 100, label: 'Goal'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 90, to: 120, label: 'Plan'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleFanChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows fan tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFanChart(points: points, minValue: 60, maxValue: 130),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(48, 167));
    await tester.pump();

    expect(find.text('Jul'), findsWidgets);
    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes fan point tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFanChart(
              points: points,
              minValue: 60,
              maxValue: 130,
              showTooltip: false,
              onPointTap: (point, index) {
                tappedLabel = point.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(48, 167));
    await tester.pump();

    expect(tappedLabel, 'Jul');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default fan semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFanChart(points: points),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Fan chart, 4 points\. Jul forecast 78, 80% 66 to 91'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
