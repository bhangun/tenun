import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const axes = [
    SimpleRadarAxis(label: 'Speed'),
    SimpleRadarAxis(label: 'Quality'),
    SimpleRadarAxis(label: 'Cost'),
    SimpleRadarAxis(label: 'Risk'),
    SimpleRadarAxis(label: 'Reach'),
  ];

  const series = [
    SimpleRadarSeries(name: 'Current', values: [82, 76, 64, 58, 72]),
    SimpleRadarSeries(name: 'Target', values: [88, 84, 70, 45, 80]),
  ];

  testWidgets('renders radar styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleRadarChart(axes: axes, series: series, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleRadarChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact radar without legend or fills', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 240,
            child: SimpleRadarChart(
              axes: axes,
              series: series,
              showLegend: false,
              showValues: true,
              showDots: false,
              fillOpacity: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleRadarChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core radar config accepts flexible JSON values', (tester) async {
    final config = RadarChartConfig.fromJson({
      'type': 'radar',
      'title': {'text': 'Core radar'},
      'filled': 'false',
      'showLabels': 'true',
      'showDots': 'false',
      'webLevels': '999',
      'fillOpacity': '2',
      'startAngle': '-80',
      'series': [
        {
          'name': 'Mixed',
          'data': [
            '80',
            {'value': '65'},
            [0, '55'],
            {'name': 'Missing value'},
          ],
        },
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

    expect(config.axes, hasLength(4));
    expect(config.axes.first.name, 'Axis 1');
    expect(config.filled, isFalse);
    expect(config.showDots, isFalse);
    expect(config.webLevels, 20);
    expect(config.fillOpacity, 1);
    expect(config.startAngleDeg, -80);
    expect(find.byType(RadarChartWidget), findsOneWidget);
    expect(find.text('Core radar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows radar tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRadarChart(axes: axes, series: series),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(150, 48));
    await tester.pump();

    expect(find.text('Speed'), findsWidgets);
    expect(find.text('Current'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes radar axis tap callback without tooltip', (
    tester,
  ) async {
    String? tappedAxis;
    int? tappedIndex;
    List<SimpleRadarTooltipItem>? tappedItems;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRadarChart(
              axes: axes,
              series: series,
              showTooltip: false,
              onAxisTap: (axisLabel, items, axisIndex) {
                tappedAxis = axisLabel;
                tappedItems = items;
                tappedIndex = axisIndex;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(150, 48));
    await tester.pump();

    expect(tappedAxis, 'Speed');
    expect(tappedIndex, 0);
    expect(tappedItems?.first.value, 82);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default radar semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleRadarChart(axes: axes, series: series),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Radar chart, 5 axes and 2 series\. Current: Speed 82, Quality 76',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
