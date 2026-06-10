import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const ranges = [
    SimpleGaugeRange(from: 0, to: 60, color: Color(0xFFEF4444)),
    SimpleGaugeRange(from: 60, to: 82, color: Color(0xFFF59E0B)),
    SimpleGaugeRange(from: 82, to: 100, color: Color(0xFF22C55E)),
  ];

  testWidgets('renders gauge styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 260,
              child: SimpleGaugeChart(
                label: 'Health',
                value: 86,
                targetValue: 90,
                unit: '%',
                ranges: ranges,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleGaugeChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders gauge without needle, ticks, target, or ranges', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: SimpleGaugeChart(
              label: 'Completion',
              value: 72,
              unit: '%',
              showNeedle: false,
              showTicks: false,
              showTarget: false,
              showRanges: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleGaugeChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows gauge tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleGaugeChart(
              label: 'Health',
              value: 86,
              targetValue: 90,
              unit: '%',
              ranges: ranges,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(210, 140));
    await tester.pump();

    expect(find.text('Health'), findsWidgets);
    expect(find.textContaining('target'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes gauge tap callback without tooltip', (tester) async {
    double? tappedValue;
    double? tappedTarget;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleGaugeChart(
              label: 'Health',
              value: 86,
              targetValue: 90,
              unit: '%',
              showTooltip: false,
              onGaugeTap: (value, targetValue) {
                tappedValue = value;
                tappedTarget = targetValue;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(210, 140));
    await tester.pump();

    expect(tappedValue, 86);
    expect(tappedTarget, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core gauge config accepts flexible JSON values', (tester) async {
    final config = GaugeChartConfig.fromJson({
      'type': 'gauge',
      'title': {'text': 'Core gauge'},
      'value': '10',
      'min': '0',
      'max': '100',
      'label': 'Quality',
      'unit': '%',
      'startAngle': '210',
      'endAngle': '-30',
      'trackWidth': '0.9',
      'showNeedle': 'false',
      'showTicks': 'true',
      'showValue': 'true',
      'valueColor': '#2563EB',
      'bands': [
        {'from': '0', 'to': '40', 'color': '#EF4444'},
        {'from': '40', 'to': '80', 'color': 'not-a-color'},
      ],
      'pointers': [
        {'value': '88', 'label': 'Target', 'color': '#111827'},
      ],
      'series': [
        {
          'data': [
            {'value': '72'},
          ],
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 420, height: 260, child: config.buildChart()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(config.value, 72);
    expect(config.min, 0);
    expect(config.max, 100);
    expect(config.startAngleDeg, 210);
    expect(config.endAngleDeg, -30);
    expect(config.trackWidth, 0.6);
    expect(config.showNeedle, isFalse);
    expect(config.bands, hasLength(2));
    expect(config.pointers.single.value, 88);
    expect(find.byType(GaugeChartWidget), findsOneWidget);
    expect(find.text('Core gauge'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default gauge semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleGaugeChart(
              label: 'Health',
              value: 86,
              targetValue: 90,
              unit: '%',
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Gauge chart\. Health 86% from 0% to 100%, target 90%\.'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
