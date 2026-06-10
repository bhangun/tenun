import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleBarChartData(label: 'Search', value: 16),
    SimpleBarChartData(label: 'Documentation', value: 52),
    SimpleBarChartData(label: 'Billing', value: 24),
    SimpleBarChartData(label: 'Onboarding', value: 38),
    SimpleBarChartData(label: 'Localization', value: 10),
  ];

  testWidgets('renders pareto styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleParetoChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleParetoChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders pareto without sorting or target line', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleParetoChart(
              data: data,
              autoSort: false,
              showTargetLine: false,
              showCumulativeLabels: false,
              showPercentAxis: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleParetoChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows pareto tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleParetoChart(data: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(84, 100));
    await tester.pump();

    expect(find.text('Documentation'), findsWidgets);
    expect(find.text('52'), findsWidgets);
    expect(find.text('37%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes pareto tap callback without tooltip', (tester) async {
    String? tappedLabel;
    double? tappedCumulativeShare;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleParetoChart(
              data: data,
              showTooltip: false,
              onItemTap: (item, index, cumulativeValue, cumulativeShare) {
                tappedLabel = item.label;
                tappedCumulativeShare = cumulativeShare;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(84, 100));
    await tester.pump();

    expect(tappedLabel, 'Documentation');
    expect(tappedCumulativeShare, closeTo(52 / 140, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default pareto semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleParetoChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Pareto chart, 5 items\. Documentation 52, cumulative 37%'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
