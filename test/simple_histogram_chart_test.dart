import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const values = [
    58.0,
    61.0,
    62.0,
    65.0,
    68.0,
    70.0,
    72.0,
    72.0,
    75.0,
    78.0,
    80.0,
    82.0,
    84.0,
    86.0,
    88.0,
    90.0,
    92.0,
    95.0,
  ];

  const bins = [
    SimpleHistogramBin(start: 0, end: 20, count: 4),
    SimpleHistogramBin(start: 20, end: 40, count: 8),
    SimpleHistogramBin(start: 40, end: 60, count: 5),
    SimpleHistogramBin(start: 60, end: 80, count: 2),
  ];

  testWidgets('renders histogram styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleHistogramChart(values: values, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleHistogramChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders pre-binned histogram in percent mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHistogramChart(
              bins: bins,
              scale: SimpleHistogramScale.percent,
              showDistributionCurve: true,
              showMean: true,
              showMedian: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleHistogramChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core histogram config accepts flexible JSON values', (
    tester,
  ) async {
    final config = HistogramChartConfig.fromJson({
      'type': 'histogram',
      'title': {'text': 'Core histogram'},
      'bins': '0',
      'showKDE': 'true',
      'showMean': 'false',
      'showMedian': 'false',
      'showStats': 'false',
      'data': [
        '1',
        {'value': '2.5'},
        [0, '3'],
        {'y': '4'},
        {'name': 'Missing value'},
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

    expect(config.bins, 1);
    expect(config.showMean, isFalse);
    expect(config.showMedian, isFalse);
    expect(config.showStats, isFalse);
    expect(config.series, hasLength(1));
    expect(find.byType(HistogramChartWidget), findsOneWidget);
    expect(find.text('Core histogram'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows histogram tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHistogramChart(bins: bins),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(100, 180));
    await tester.pump();

    expect(find.text('0-20'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('21%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes histogram bin tap callback without tooltip', (
    tester,
  ) async {
    int? tappedIndex;
    int? tappedCount;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHistogramChart(
              bins: bins,
              showTooltip: false,
              onBinTap: (bin, index) {
                tappedIndex = index;
                tappedCount = bin.count;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(100, 180));
    await tester.pump();

    expect(tappedIndex, 0);
    expect(tappedCount, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default histogram semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleHistogramChart(bins: bins),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Histogram chart, 4 bins\. 0-20: 4, 20-40: 8'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
