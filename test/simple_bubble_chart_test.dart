import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleBubbleChartData(
      label: 'Quick Win',
      x: 20,
      y: 82,
      size: 32,
      group: 'Growth',
    ),
    SimpleBubbleChartData(
      label: 'Scale',
      x: 52,
      y: 74,
      size: 44,
      group: 'Growth',
    ),
    SimpleBubbleChartData(
      label: 'Platform',
      x: 72,
      y: 64,
      size: 36,
      group: 'Core',
    ),
    SimpleBubbleChartData(
      label: 'Cleanup',
      x: 38,
      y: 36,
      size: 20,
      group: 'Core',
    ),
  ];

  testWidgets('renders bubble styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleBubbleChart(
                data: data,
                minX: 0,
                maxX: 100,
                minY: 0,
                maxY: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleBubbleChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders bubble references and labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBubbleChart(
              data: data,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              showTrendLine: true,
              showLabels: true,
              referenceLines: [
                SimpleScatterReferenceLine(
                  axis: SimpleScatterReferenceAxis.x,
                  value: 50,
                  label: 'Effort',
                ),
                SimpleScatterReferenceLine(
                  axis: SimpleScatterReferenceAxis.y,
                  value: 70,
                  label: 'Impact',
                ),
              ],
              referenceBands: [
                SimpleScatterReferenceBand(
                  axis: SimpleScatterReferenceAxis.y,
                  from: 70,
                  to: 100,
                  label: 'High',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleBubbleChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core bubble config accepts flexible JSON values', (
    tester,
  ) async {
    final config = BubbleChartConfig.fromJson({
      'type': 'bubble',
      'title': {'text': 'Core bubble'},
      'showLabels': 'true',
      'minBubbleRadius': '-5',
      'maxBubbleRadius': '2',
      'legend': {'show': 'true'},
      'data': [
        {'x': '10', 'y': '20', 'size': '5', 'label': 'Alpha'},
        ['30', '40', '12', 'Beta'],
        {'value': '50', 'size': '0', 'name': 'Gamma'},
        '60',
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 460, height: 280, child: config.buildChart()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(config.bubbleSeries, hasLength(1));
    expect(config.bubbleSeries.single.data, hasLength(4));
    expect(config.bubbleSeries.single.data.first.label, 'Alpha');
    expect(config.bubbleSeries.single.data[1].x, 30);
    expect(config.bubbleSeries.single.data[1].size, 12);
    expect(config.bubbleSeries.single.data[2].size, 10);
    expect(config.showLabels, isTrue);
    expect(config.minBubbleRadius, 4);
    expect(config.maxBubbleRadius, 4);
    expect(find.byType(BubbleChartWidget), findsOneWidget);
    expect(find.text('Core bubble'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows bubble tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBubbleChart(
              data: data,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              xAxisLabel: 'Effort',
              yAxisLabel: 'Impact',
              sizeLabel: 'Budget',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(129, 62));
    await tester.pump();

    expect(find.text('Quick Win'), findsWidgets);
    expect(find.text('Effort'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes bubble tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBubbleChart(
              data: data,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              showTooltip: false,
              onBubbleTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(129, 62));
    await tester.pump();

    expect(tappedLabel, 'Quick Win');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default bubble semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBubbleChart(
              data: data,
              xAxisLabel: 'Effort',
              yAxisLabel: 'Impact',
              sizeLabel: 'Budget',
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Bubble chart, 4 bubbles\. Quick Win Effort 20, Impact 82, Budget 32',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
