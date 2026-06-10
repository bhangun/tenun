import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/line/line_area_variants.dart';

void main() {
  group('line area variant config robustness', () {
    test('area pieces and line gradient tolerate stringly typed payloads', () {
      final areaPieces = AreaPiecesChartConfig.fromJson({
        'xLabels': [1, 'Q2', 3],
        'fillOpacity': '0.42',
        'thresholds': [
          {'value': '0', 'color': '#EF5350'},
          {'value': '50', 'color': '#FFA726'},
        ],
        'series': [
          {
            'name': 'Temperature',
            'data': [
              '8',
              {'value': '24'},
              ['2', '36'],
            ],
          },
        ],
      });
      expect(areaPieces.categories, ['1', 'Q2', '3']);
      expect(areaPieces.fillOpacity, 0.42);
      expect(areaPieces.thresholds.map((item) => item.value), [0, 50]);
      expect(areaPieces.series, hasLength(1));

      final lineGradient = LineGradientChartConfig.fromJson({
        'xLabels': ['Mon', 2, 'Wed'],
        'fillArea': 'no',
        'fillOpacity': '0.18',
        'gradientStart': '#2563EB',
        'gradientEnd': '#14B8A6',
        'series': [
          {
            'name': 'Usage',
            'data': [
              '12',
              {'value': '18'},
              ['2', '24'],
            ],
          },
        ],
      });
      expect(lineGradient.categories, ['Mon', '2', 'Wed']);
      expect(lineGradient.fillArea, isFalse);
      expect(lineGradient.fillOpacity, 0.18);
      expect(lineGradient.series, hasLength(1));
    });

    testWidgets('area pieces and line gradient render string values', (
      tester,
    ) async {
      final charts = [
        AreaPiecesChartConfig.fromJson({
          'categories': ['A', 'B', 'C'],
          'thresholds': [
            {'value': '0', 'color': '#EF5350'},
            {'value': '50', 'color': '#66BB6A'},
          ],
          'series': [
            {
              'name': 'Score',
              'data': ['8', '24', '36'],
            },
          ],
        }).buildChart(),
        LineGradientChartConfig.fromJson({
          'xLabels': ['A', 'B', 'C'],
          'fillArea': 'yes',
          'series': [
            {
              'name': 'Trend',
              'data': [
                '12',
                {'value': '18'},
                ['2', '24'],
              ],
            },
          ],
        }).buildChart(),
      ];

      for (final chart in charts) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 360, height: 260, child: chart),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull);
      }
    });

    test('markline and log axis tolerate stringly typed payloads', () {
      final markline = LineMarklineConfig.fromJson({
        'xLabels': ['Jan', 2, 'Mar'],
        'series': [
          {
            'name': 'Revenue',
            'data': [
              '12',
              {'value': '18'},
              ['2', '24'],
            ],
          },
        ],
        'marklines': [
          {'label': 2026, 'value': '18', 'type': 'fixed', 'dashed': 'no'},
          {'label': 'Average', 'type': 'average', 'dashed': 'yes'},
        ],
      });
      expect(markline.categories, ['Jan', '2', 'Mar']);
      expect(markline.marklines.first.label, '2026');
      expect(markline.marklines.first.value, 18);
      expect(markline.marklines.first.dashed, isFalse);
      expect(markline.marklines.last.dashed, isTrue);

      final logAxis = LogAxisChartConfig.fromJson({
        'xLabels': ['A', 2, 'C'],
        'logBase': '2',
        'series': [
          {
            'name': 'Scale',
            'data': [
              '4',
              {'value': '16'},
              ['2', '64'],
            ],
          },
        ],
      });
      expect(logAxis.categories, ['A', '2', 'C']);
      expect(logAxis.logBase, 2);
      expect(logAxis.series, hasLength(1));
    });

    testWidgets('markline and log axis render string values', (tester) async {
      final charts = [
        LineMarklineConfig.fromJson({
          'xLabels': ['A', 'B', 'C'],
          'series': [
            {
              'name': 'Revenue',
              'data': [
                '12',
                {'value': '18'},
                ['2', '24'],
              ],
            },
          ],
          'marklines': [
            {'label': 'Target', 'value': '20', 'dashed': 'false'},
            {'label': 'Average', 'type': 'average'},
          ],
        }).buildChart(),
        LogAxisChartConfig.fromJson({
          'xLabels': ['A', 'B', 'C'],
          'logBase': '10',
          'series': [
            {
              'name': 'Scale',
              'data': [
                '10',
                {'value': '100'},
                ['2', '1000'],
              ],
            },
          ],
        }).buildChart(),
      ];

      for (final chart in charts) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 360, height: 260, child: chart),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull);
      }
    });

    test(
      'confidence function and sparkline matrix tolerate string payloads',
      () {
        final confidence = LineConfidenceBandConfig.fromJson({
          'bandOpacity': '0.3',
          'bandColor': '#60A5FA',
          'points': [
            {'x': '0', 'y': '10', 'lower': '8', 'upper': '12'},
            {'x': '1', 'y': '15'},
          ],
        });
        expect(confidence.bandOpacity, 0.3);
        expect(confidence.bandColor, '#60A5FA');
        expect(confidence.points.last.lower, 5);
        expect(confidence.points.last.upper, 25);

        final functionPlot = FunctionPlotConfig.fromJson({
          'xMin': '-3.14',
          'xMax': '3.14',
          'yMin': '-1',
          'yMax': '1',
          'resolution': '80',
          'functions': [
            {'label': 'sin(x)', 'color': '#2563EB'},
            {'label': 2026, 'color': '#14B8A6'},
          ],
        });
        expect(functionPlot.xMin, -3.14);
        expect(functionPlot.xMax, 3.14);
        expect(functionPlot.yMin, -1);
        expect(functionPlot.yMax, 1);
        expect(functionPlot.resolution, 80);
        expect(functionPlot.functions.last.label, '2026');

        final matrix = SparklineMatrixConfig.fromJson({
          'columns': '2',
          'sparklineHeight': '44',
          'showTrend': 'no',
          'cells': [
            {
              'label': 2026,
              'values': [
                '8',
                {'value': '12'},
                ['2', '16'],
              ],
            },
          ],
        });
        expect(matrix.columns, 2);
        expect(matrix.sparklineHeight, 44);
        expect(matrix.showTrend, isFalse);
        expect(matrix.cells.single.label, '2026');
        expect(matrix.cells.single.values, [8, 12, 16]);
      },
    );

    testWidgets(
      'confidence function and sparkline matrix render string values',
      (tester) async {
        final charts = [
          LineConfidenceBandConfig.fromJson({
            'bandOpacity': '0.25',
            'points': [
              {'x': '0', 'y': '10', 'lower': '8', 'upper': '12'},
              {'x': '1', 'y': '15', 'lower': '12', 'upper': '18'},
              {'x': '2', 'y': '13', 'lower': '10', 'upper': '16'},
            ],
          }).buildChart(),
          FunctionPlotConfig.fromJson({
            'xMin': '-3.14',
            'xMax': '3.14',
            'yMin': '-1.2',
            'yMax': '1.2',
            'resolution': '60',
            'functions': [
              {'label': 'sin(x)', 'color': '#2563EB'},
              {'label': 'cos(x)', 'color': '#14B8A6'},
            ],
          }).buildChart(),
          SparklineMatrixConfig.fromJson({
            'columns': '2',
            'showTrend': 'yes',
            'cells': [
              {
                'label': 'Sales',
                'values': ['8', '12', '16'],
              },
              {
                'label': 'Costs',
                'values': [
                  {'value': '9'},
                  ['2', '7'],
                  '6',
                ],
              },
            ],
          }).buildChart(),
        ];

        for (final chart in charts) {
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(width: 380, height: 280, child: chart),
            ),
          );
          await tester.pump(const Duration(milliseconds: 1000));
          expect(tester.takeException(), isNull);
        }
      },
    );

    test('intraday and click-add tolerate string payloads', () {
      final intraday = IntradayLineConfig.fromJson({
        'xLabel': 2026,
        'yLabel': 'Price',
        'points': [
          {'x': '0', 'y': '10'},
          {'x': '1'},
          ['2', '12'],
          {'x': 'bad', 'y': '99'},
        ],
      });
      expect(intraday.xLabel, '2026');
      expect(intraday.yLabel, 'Price');
      expect(intraday.points, hasLength(3));
      expect(intraday.points[0].x, 0);
      expect(intraday.points[0].y, 10);
      expect(intraday.points[1].y, isNull);
      expect(intraday.points[2].x, 2);
      expect(intraday.points[2].y, 12);

      final clickAdd = LineClickAddConfig.fromJson({
        'seriesName': 2026,
        'initialX': ['0', '1.5', '3'],
        'initialY': ['8', '13', '21'],
      });
      expect(clickAdd.seriesName, '2026');
      expect(clickAdd.initialX, [0, 1.5, 3]);
      expect(clickAdd.initialY, [8, 13, 21]);
    });

    testWidgets('intraday and click-add render string values', (tester) async {
      final charts = [
        IntradayLineConfig.fromJson({
          'xLabel': 'Minute',
          'yLabel': 'Price',
          'points': [
            {'x': '0', 'y': '10'},
            {'x': '1'},
            ['2', '12'],
            ['3', '11'],
          ],
        }).buildChart(),
        LineClickAddConfig.fromJson({
          'seriesName': 'Editable',
          'initialX': ['0', '1', '2'],
          'initialY': ['8', '13', '21'],
        }).buildChart(),
      ];

      for (final chart in charts) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 380, height: 280, child: chart),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull);
      }
    });

    test('dynamic time series tolerates string timing payloads', () {
      final config = DynamicTimeSeriesConfig.fromJson({
        'windowSize': '12',
        'updateIntervalMs': '25',
      });
      expect(config.windowSize, 12);
      expect(config.updateInterval.inMilliseconds, 25);

      final clamped = DynamicTimeSeriesConfig.fromJson({
        'windowSize': '0',
        'updateIntervalMs': '0',
      });
      expect(clamped.windowSize, 1);
      expect(clamped.updateInterval.inMilliseconds, 1);
    });

    testWidgets('dynamic time series renders string timing payloads', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 380,
            height: 280,
            child: DynamicTimeSeriesConfig.fromJson({
              'windowSize': '4',
              'updateIntervalMs': '25',
            }).buildChart(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
