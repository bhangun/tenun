import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleFunnelChartData(label: 'Visitors', value: 10000),
    SimpleFunnelChartData(label: 'Leads', value: 6400),
    SimpleFunnelChartData(label: 'Trials', value: 3100),
    SimpleFunnelChartData(label: 'Qualified', value: 1400),
    SimpleFunnelChartData(label: 'Closed', value: 420),
  ];

  testWidgets('renders funnel styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleFunnelChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleFunnelChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders pyramid with conversion rates', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFunnelChart(
              data: data,
              mode: SimpleFunnelMode.pyramid,
              showConversionRates: true,
              showTrack: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleFunnelChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows funnel tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFunnelChart(data: data, showConversionRates: true),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(230, 38));
    await tester.pump();

    expect(find.text('Visitors'), findsWidgets);
    expect(find.text('100%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes funnel stage tap callback without tooltip', (
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
            child: SimpleFunnelChart(
              data: data,
              showTooltip: false,
              onStageTap: (stage, index, share, conversionRate) {
                tappedLabel = stage.label;
                tappedIndex = index;
                tappedShare = share;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(230, 38));
    await tester.pump();

    expect(tappedLabel, 'Visitors');
    expect(tappedIndex, 0);
    expect(tappedShare, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default funnel semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleFunnelChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Funnel chart, 5 stages\. Visitors 10000, 100%'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
