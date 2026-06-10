import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleCandlestickData(
      label: 'Jan',
      open: 101,
      high: 108,
      low: 98,
      close: 106,
      volume: 1200000,
    ),
    SimpleCandlestickData(
      label: 'Feb',
      open: 106,
      high: 112,
      low: 102,
      close: 104,
      volume: 1400000,
    ),
    SimpleCandlestickData(
      label: 'Mar',
      open: 104,
      high: 116,
      low: 103,
      close: 113,
      volume: 1800000,
    ),
    SimpleCandlestickData(
      label: 'Apr',
      open: 113,
      high: 118,
      low: 109,
      close: 111,
      volume: 1500000,
    ),
    SimpleCandlestickData(
      label: 'May',
      open: 111,
      high: 123,
      low: 110,
      close: 121,
      volume: 2200000,
    ),
    SimpleCandlestickData(
      label: 'Jun',
      open: 121,
      high: 126,
      low: 117,
      close: 124,
      volume: 1900000,
    ),
  ];

  testWidgets('renders candlestick styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleCandlestickChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleCandlestickChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders ohlc mode with references without volume', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCandlestickChart(
              data: data,
              mode: SimpleCandlestickChartMode.ohlc,
              showVolume: false,
              showValues: true,
              minValue: 95,
              maxValue: 130,
              referenceLines: [
                SimpleChartReferenceLine(value: 120, label: 'Resistance'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 100, to: 110, label: 'Support'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleCandlestickChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows candlestick tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCandlestickChart(data: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(76, 90));
    await tester.pump();

    expect(find.text('Jan'), findsWidgets);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes candlestick tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCandlestickChart(
              data: data,
              showTooltip: false,
              onCandleTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(76, 90));
    await tester.pump();

    expect(tappedLabel, 'Jan');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default candlestick semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCandlestickChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Candlestick chart, 6 candles\. Jan open 101\.00, close 106\.00',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
