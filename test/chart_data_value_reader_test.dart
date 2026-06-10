import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/bar/bar_chart.dart';
import 'package:tenun/charts/bar/bar_config.dart';
import 'package:tenun/charts/scatter/scatter_chart.dart';
import 'package:tenun/charts/scatter/scatter_config.dart';
import 'package:tenun/core/chart_data_processor.dart';
import 'package:tenun/core/chart_data_value_reader.dart';
import 'package:tenun/core/chart_type.dart';
import 'package:tenun/core/data_sampler.dart';
import 'package:tenun/core/legend.dart';
import 'package:tenun/core/series.dart';
import 'package:tenun/core/xyaxis.dart';

void main() {
  group('ChartDataValueReader', () {
    test('reads common scalar, tuple, and map payload shapes', () {
      final scalar = ChartDataValueReader.cartesian('42', 3)!;
      expect(scalar.x, 3);
      expect(scalar.y, 42);

      final categoryTuple = ChartDataValueReader.cartesian([
        'North',
        '12.5',
      ], 1)!;
      expect(categoryTuple.x, 1);
      expect(categoryTuple.y, 12.5);
      expect(categoryTuple.label, 'North');

      final numericTuple = ChartDataValueReader.cartesian(['2', '7'], 0)!;
      expect(numericTuple.x, 2);
      expect(numericTuple.y, 7);

      final mapPoint = ChartDataValueReader.cartesian({
        'x': '5',
        'y': '9',
        'label': 'Peak',
      }, 0)!;
      expect(mapPoint.x, 5);
      expect(mapPoint.y, 9);
      expect(mapPoint.label, 'Peak');

      expect(ChartDataValueReader.cartesian({'name': 'bad'}, 0), isNull);
    });

    test('reads close prices from OHLC tuple and map payloads', () {
      expect(
        ChartDataValueReader.ohlcCloseValueOrNull([100, 108, 96, 103, 1200]),
        103,
      );
      expect(
        ChartDataValueReader.ohlcCloseValueOrNull([
          '2025-01-01',
          100,
          108,
          96,
          104,
          1200,
        ]),
        104,
      );
      expect(
        ChartDataValueReader.ohlcCloseValueOrNull([
          '100',
          '108',
          '96',
          '106',
          '1200',
        ]),
        106,
      );
      expect(
        ChartDataValueReader.ohlcCloseValueOrNull([
          1704067200000,
          100,
          108,
          96,
          107,
        ]),
        107,
      );
      expect(
        ChartDataValueReader.ohlcCloseValueOrNull({
          'open': '100',
          'high': '108',
          'low': '96',
          'close': '105',
        }),
        105,
      );
      expect(ChartDataValueReader.ohlcCloseValueOrNull({'close': '105'}), 105);
      expect(
        ChartDataValueReader.ohlcCloseValueOrNull({
          'open': 100,
          'high': 99,
          'low': 96,
          'close': 98,
        }),
        isNull,
      );
      expect(
        ChartDataValueReader.ohlcCloseValueOrNull({
          'open': 100,
          'high': 108,
          'low': 101,
          'close': 104,
        }),
        isNull,
      );
      expect(
        ChartDataValueReader.ohlcCloseValueOrNull([100, 99, 96, 98]),
        isNull,
      );
    });

    test('computes non-zero bounds from mixed cartesian data', () {
      final bounds = ChartDataValueReader.bounds([
        [
          {'x': '1', 'y': '2'},
          ['A', '5'],
          [3, 4],
          '7',
          {'ignored': true},
        ],
      ])!.ensureNonZeroSpan();

      expect(bounds.minX, 1);
      expect(bounds.maxX, 3);
      expect(bounds.minY, 2);
      expect(bounds.maxY, 7);
    });
  });

  test('data processor and sampler accept structured numeric payloads', () {
    final result = ChartDataProcessor.process([
      Series(
        type: ChartType.line,
        data: const [
          {'value': '12'},
          ['Q2', '18'],
          [3, 24],
          'bad',
        ],
      ),
    ], renderThreshold: 300);

    expect(result.stats.globalMax, 24);
    expect(result.processed.single.stats.count, 3);

    final sampled = DataSampler.fromRaw(const [
      {'x': '2', 'y': '5'},
      ['A', '8'],
      'bad',
    ]);
    expect(sampled.map((point) => (point.x, point.y)), [
      (2.0, 5.0),
      (1.0, 8.0),
    ]);
  });

  test('sampler skips invalid complete OHLC maps', () {
    final sampled = DataSampler.fromRaw(const [
      {'open': 100, 'high': 108, 'low': 96, 'close': 105},
      {'open': 100, 'high': 99, 'low': 96, 'close': 98},
      {'open': 105, 'high': 110, 'low': 101, 'close': 108},
    ]);

    expect(sampled.map((point) => (point.x, point.y)), [
      (0.0, 105.0),
      (2.0, 108.0),
    ]);
  });

  testWidgets('bar chart tolerates mixed data shapes', (tester) async {
    final config = BarChartConfig(
      legend: ChartLegend(show: true),
      xAxis: XYAxis(data: const ['A', 'B', 'C', 'D']),
      series: [
        Series(
          type: ChartType.bar,
          name: 'Mixed',
          data: const [
            '12',
            ['B', '18'],
            {'value': '24'},
            {'ignored': true},
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 280,
          child: BarChartWidget(config: config),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mixed'), findsOneWidget);
  });

  testWidgets('scatter chart derives bounds and skips invalid points', (
    tester,
  ) async {
    final config = ScatterChartConfig.fromJson({
      'legend': {'show': true},
      'series': [
        {
          'type': 'scatter',
          'name': 'Mixed scatter',
          'data': [
            {'x': '1', 'y': '2'},
            ['North', '4'],
            [3, '6'],
            '8',
            {'ignored': true},
          ],
        },
      ],
    });

    expect(config.maxX, greaterThan(config.minX));
    expect(config.maxY, greaterThan(config.minY));

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 420,
          height: 460,
          child: ScatterBarChartWidget(config: config),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mixed scatter'), findsOneWidget);
  });

  testWidgets('scatter config buildChart delegates to the painter widget', (
    tester,
  ) async {
    final config = ScatterChartConfig.fromJson({
      'title': {'text': 'JSON scatter'},
      'legend': {'show': true},
      'series': [
        {
          'type': 'scatter',
          'name': 'JSON points',
          'data': [
            {'x': 10, 'y': 30},
            {'x': 20, 'y': 40},
          ],
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 420, height: 460, child: config.buildChart()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ScatterBarChartWidget), findsOneWidget);
    expect(find.text('JSON scatter'), findsOneWidget);
    expect(find.text('JSON points'), findsOneWidget);
  });

  testWidgets('scatter toolbox zooms and restores the viewport', (
    tester,
  ) async {
    final config = ScatterChartConfig.fromJson({
      'toolbox': {'show': true},
      'minX': 0,
      'maxX': 100,
      'minY': 0,
      'maxY': 100,
      'series': [
        {
          'type': 'scatter',
          'name': 'Zoomable',
          'data': [
            {'x': 10, 'y': 30},
            {'x': 50, 'y': 50},
            {'x': 90, 'y': 70},
          ],
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 420,
          height: 460,
          child: ScatterBarChartWidget(config: config),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0.0'), findsWidgets);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('0.0'), findsNothing);
    expect(find.text('20.0'), findsWidgets);

    await tester.tap(find.byTooltip('Reset zoom'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('0.0'), findsWidgets);
  });
}
