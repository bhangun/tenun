import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/bar/bar_chart_variants.dart';
import 'package:tenun/tenun.dart';

void main() {
  final stackedSeries = [
    Series(type: ChartType.bar, name: 'Base', data: const [12, 18, 14, 22]),
    Series(type: ChartType.bar, name: 'Growth', data: const [8, 10, 9, 12]),
  ];

  final singleSeries = [
    Series(type: ChartType.bar, name: 'Actual', data: const [16, 24, 19, 30]),
  ];

  Widget host(BaseChartConfig config) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 520,
          height: 340,
          child: TenunChart(config: config),
        ),
      ),
    );
  }

  Widget jsonHost(Map<String, dynamic> payload) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 520,
          height: 340,
          child: TenunChart(jsonConfig: payload),
        ),
      ),
    );
  }

  testWidgets('bar race renders custom markers and frame controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        BarRaceChartConfig(
          title: TitlesData(text: 'Race controls'),
          frames: const [
            BarRaceFrame(label: '2025', values: {'Alpha': 10, 'Beta': 20}),
            BarRaceFrame(label: '2026', values: {'Alpha': 14, 'Beta': 24}),
          ],
          markers: const {
            'Alpha': BarRaceMarkerStyle(text: 'A', backgroundColor: '#E6F4FF'),
            'Beta': BarRaceMarkerStyle(text: 'B'),
          },
          autoPlay: false,
          showControls: true,
          showStepControls: true,
          showProgressIndicator: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Race controls'), findsOneWidget);
    expect(find.byTooltip('Play race'), findsOneWidget);
    expect(find.byTooltip('Next frame'), findsOneWidget);
    expect(find.text('Frame: 2025'), findsOneWidget);

    await tester.tap(find.byTooltip('Next frame'));
    await tester.pump();

    expect(find.text('Frame: 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bar race renders shorthand JSON frames with markers', (
    tester,
  ) async {
    final snapshot = ChartRegistry.snapshot();
    ChartRegistry.clear();
    allChartsBundle.register();
    addTearDown(() => ChartRegistry.restore(snapshot));

    await tester.pumpWidget(
      jsonHost(const {
        'type': 'barRace',
        'title': {'text': 'JSON race controls'},
        'categories': ['Alpha', 'Beta'],
        'frameLabels': ['2025', '2026'],
        'frames': [
          [10, 20],
          [14, 24],
        ],
        'markers': {
          'Alpha': {'text': 'A', 'backgroundColor': '#E6F4FF'},
          'Beta': {'text': 'B'},
        },
        'autoPlay': false,
        'showControls': true,
        'showStepControls': true,
      }),
    );
    await tester.pump();

    expect(find.text('JSON race controls'), findsOneWidget);
    expect(find.text('Frame: 2025'), findsOneWidget);
    expect(find.byTooltip('Next frame'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remaining specialized bar variants render from config', (
    tester,
  ) async {
    final variants = <MapEntry<String, BaseChartConfig>>[
      MapEntry(
        'Rounded stacked bars',
        BarRoundedStackedConfig(
          title: TitlesData(text: 'Rounded stacked bars'),
          categories: const ['Q1', 'Q2', 'Q3', 'Q4'],
          showValues: true,
          series: stackedSeries,
        ),
      ),
      MapEntry(
        'Normalized stacked bars',
        BarNormalizedConfig(
          title: TitlesData(text: 'Normalized stacked bars'),
          categories: const ['Q1', 'Q2', 'Q3', 'Q4'],
          series: stackedSeries,
        ),
      ),
      MapEntry(
        'Negative diverging bars',
        NegativeBarConfig(
          title: TitlesData(text: 'Negative diverging bars'),
          categories: const ['Profit', 'Cost', 'Cash', 'Churn'],
          series: [
            Series(
              type: ChartType.bar,
              name: 'Movement',
              data: const [120, -80, 65, -24],
            ),
          ],
        ),
      ),
      MapEntry(
        'Tangential polar bars',
        TangentialPolarBarConfig(
          title: TitlesData(text: 'Tangential polar bars'),
          categories: const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
          series: [
            Series(
              type: ChartType.bar,
              name: 'Score',
              data: const [90, 140, 110, 170, 130, 160],
            ),
          ],
        ),
      ),
      MapEntry(
        'Brush selectable bars',
        BarBrushConfig(
          title: TitlesData(text: 'Brush selectable bars'),
          categories: const ['A', 'B', 'C', 'D'],
          series: singleSeries,
        ),
      ),
    ];

    for (final variant in variants) {
      await tester.pumpWidget(host(variant.value));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(variant.key), findsOneWidget);
      expect(tester.takeException(), isNull, reason: variant.key);
    }
  });

  testWidgets(
    'remaining specialized bar variants render from registered JSON',
    (tester) async {
      final snapshot = ChartRegistry.snapshot();
      ChartRegistry.clear();
      allChartsBundle.register();
      addTearDown(() => ChartRegistry.restore(snapshot));

      final payloads = <MapEntry<String, Map<String, dynamic>>>[
        const MapEntry('JSON rounded bars', {
          'type': 'barRounded',
          'title': {'text': 'JSON rounded bars'},
          'categories': ['Q1', 'Q2', 'Q3'],
          'series': [
            {
              'type': 'bar',
              'name': 'Base',
              'data': [12, 18, 14],
            },
            {
              'type': 'bar',
              'name': 'Growth',
              'data': [8, 10, 9],
            },
          ],
        }),
        const MapEntry('JSON normalized bars', {
          'type': 'barNormalized',
          'title': {'text': 'JSON normalized bars'},
          'categories': ['Q1', 'Q2', 'Q3'],
          'series': [
            {
              'type': 'bar',
              'name': 'Base',
              'data': [12, 18, 14],
            },
            {
              'type': 'bar',
              'name': 'Growth',
              'data': [8, 10, 9],
            },
          ],
        }),
        const MapEntry('JSON negative bars', {
          'type': 'negativeBar',
          'title': {'text': 'JSON negative bars'},
          'categories': ['Profit', 'Cost', 'Cash', 'Churn'],
          'series': [
            {
              'type': 'bar',
              'name': 'Movement',
              'data': [120, -80, 65, -24],
            },
          ],
        }),
        const MapEntry('JSON tangential polar bars', {
          'type': 'tangentialPolarBar',
          'title': {'text': 'JSON tangential polar bars'},
          'categories': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
          'series': [
            {
              'type': 'bar',
              'name': 'Score',
              'data': [90, 140, 110, 170, 130, 160],
            },
          ],
        }),
        const MapEntry('JSON brush bars', {
          'type': 'barBrush',
          'title': {'text': 'JSON brush bars'},
          'categories': ['A', 'B', 'C', 'D'],
          'series': [
            {
              'type': 'bar',
              'name': 'Actual',
              'data': [16, 24, 19, 30],
            },
          ],
        }),
      ];

      for (final payload in payloads) {
        await tester.pumpWidget(jsonHost(payload.value));
        await tester.pump(const Duration(seconds: 1));

        expect(find.text(payload.key), findsOneWidget);
        expect(tester.takeException(), isNull, reason: payload.key);
      }
    },
  );

  testWidgets('bar brush reports selected index range while dragging', (
    tester,
  ) async {
    int? startIndex;
    int? endIndex;

    await tester.pumpWidget(
      host(
        BarBrushConfig(
          title: TitlesData(text: 'Interactive brush bars'),
          categories: const ['A', 'B', 'C', 'D'],
          series: singleSeries,
          onBrushChange: (start, end) {
            startIndex = start;
            endIndex = end;
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.dragFrom(const Offset(90, 170), const Offset(250, 0));
    await tester.pump();

    expect(startIndex, isNotNull);
    expect(endIndex, isNotNull);
    expect(startIndex, lessThanOrEqualTo(endIndex!));
    expect(tester.takeException(), isNull);
  });
}
