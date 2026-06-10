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
    SimpleBinnedDotPlotBin(start: 0, end: 20, count: 4),
    SimpleBinnedDotPlotBin(start: 20, end: 40, count: 8),
    SimpleBinnedDotPlotBin(start: 40, end: 60, count: 5),
    SimpleBinnedDotPlotBin(start: 60, end: 80, count: 2),
  ];

  testWidgets('renders binned dot plot styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleBinnedDotPlotChart(values: values, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleBinnedDotPlotChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders pre-binned dot plot with grouped dots', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBinnedDotPlotChart(
              bins: bins,
              dotValue: 2,
              showValues: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleBinnedDotPlotChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows binned dot plot tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBinnedDotPlotChart(bins: bins),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(100, 180));
    await tester.pump();

    expect(find.text('0-20'), findsOneWidget);
    expect(find.text('Count'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes binned dot plot tap callback without tooltip', (
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
            child: SimpleBinnedDotPlotChart(
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

  testWidgets('exposes default binned dot plot semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBinnedDotPlotChart(bins: bins),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Binned dot plot chart, 4 bins\. 0-20: 4, 20-40: 8'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
