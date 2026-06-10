import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleDonutChartData(label: 'Online', value: 42),
    SimpleDonutChartData(label: 'Partner', value: 28),
    SimpleDonutChartData(label: 'Field', value: 18),
    SimpleDonutChartData(label: 'Education', value: 12),
  ];

  testWidgets('renders donut styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleDonutChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDonutChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact donut without legend and labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            height: 220,
            child: SimpleDonutChart(
              data: data,
              showLegend: false,
              showLabels: false,
              centerLabel: 'Share',
              centerValue: '100%',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDonutChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows donut tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDonutChart(data: data),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(160, 55));
    await tester.pump();

    expect(find.text('Online'), findsWidgets);
    expect(find.textContaining('42'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes donut tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedShare;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDonutChart(
              data: data,
              showTooltip: false,
              onSegmentTap: (item, index, share) {
                tappedLabel = item.label;
                tappedIndex = index;
                tappedShare = share;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(160, 55));
    await tester.pump();

    expect(tappedLabel, 'Online');
    expect(tappedIndex, 0);
    expect(tappedShare, closeTo(0.42, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default donut semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDonutChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Donut chart, 4 segments\. Online 42, 42%'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('core pie config renders from JSON', (tester) async {
    final config = PieChartConfig.fromJson({
      'type': 'pie',
      'title': {'text': 'Core pie'},
      'series': [
        {
          'name': 'Share',
          'data': [
            {'name': 'Online', 'value': '42', 'color': '#2563EB'},
            {'name': 'Partner', 'value': 28},
            {'name': 'Field', 'value': 18},
          ],
        },
      ],
      'sectionsSpace': '2',
      'enableSections': 'true',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 460, height: 280, child: config.buildChart()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(config.type, ChartType.pie);
    expect(find.byType(PieChartWidget), findsOneWidget);
    expect(find.text('Core pie'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core donut JSON preserves donut type and renders', (
    tester,
  ) async {
    final config = PieChartConfig.fromJson({
      'type': 'donut',
      'title': {'text': 'Core donut', 'subtext': '100%'},
      'series': [
        {
          'name': 'Share',
          'data': [
            {'name': 'Online', 'value': 42},
            {'name': 'Partner', 'value': 28},
          ],
        },
      ],
      'centerSpaceRadius': '44',
      'sectionsSpace': '3',
      'enableSections': 'false',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 460, height: 280, child: config.buildChart()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(config.type, ChartType.donut);
    expect(config.donut, isTrue);
    expect(config.centerSpaceRadius, 44);
    expect(config.sectionsSpace, 3);
    expect(config.enableSections, isFalse);
    expect(find.byType(PieChartWidget), findsOneWidget);
    expect(find.text('Core donut'), findsOneWidget);
    expect(find.text('Partner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
