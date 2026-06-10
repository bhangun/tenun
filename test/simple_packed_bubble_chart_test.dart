import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimplePackedBubbleData(label: 'Core', value: 42),
    SimplePackedBubbleData(label: 'Growth', value: 28),
    SimplePackedBubbleData(label: 'Education', value: 18),
    SimplePackedBubbleData(label: 'Support', value: 12),
  ];

  testWidgets('renders packed bubble styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimplePackedBubbleChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimplePackedBubbleChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders packed bubble without legend and with labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 260,
            child: SimplePackedBubbleChart(
              data: data,
              totalValue: 120,
              showLegend: false,
              showLabels: true,
              showValues: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimplePackedBubbleChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows packed bubble tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePackedBubbleChart(data: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(163, 140));
    await tester.pump();

    expect(find.text('Core'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes packed bubble tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedShare;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePackedBubbleChart(
              data: data,
              showTooltip: false,
              onBubbleTap: (item, index, share) {
                tappedLabel = item.label;
                tappedIndex = index;
                tappedShare = share;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(163, 140));
    await tester.pump();

    expect(tappedLabel, 'Core');
    expect(tappedIndex, 0);
    expect(tappedShare, closeTo(0.42, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default packed bubble semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePackedBubbleChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Packed bubble chart, 4 bubbles\. Core 42, 42%'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
