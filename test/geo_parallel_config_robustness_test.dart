import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/choroplet/choropleth_chart.dart';
import 'package:tenun/charts/pararel/pararel_chart.dart';

void main() {
  group('geo and parallel config robustness', () {
    test('configs tolerate stringly typed map and parallel payloads', () {
      final choropleth = ChoroplethChartConfig.fromJson({
        'showLegend': 'yes',
        'showGraticule': '1',
        'showLabels': 'no',
        'minValue': '0',
        'maxValue': '100',
        'borderWidth': '1.5',
        'series': [
          {
            'regions': [
              {
                'id': 1,
                'name': 2026,
                'value': '42.5',
                'color': '#2563EB',
                'polygon': [
                  ['-125', '49'],
                  ['-95', '49'],
                  ['-95', '25'],
                  ['bad'],
                  ['-125', '25'],
                ],
              },
            ],
          },
        ],
      });
      expect(choropleth.showLegend, isTrue);
      expect(choropleth.showGraticule, isTrue);
      expect(choropleth.showLabels, isFalse);
      expect(choropleth.minValue, 0);
      expect(choropleth.maxValue, 100);
      expect(choropleth.borderWidth, 1.5);
      expect(choropleth.regions.single.id, '1');
      expect(choropleth.regions.single.name, '2026');
      expect(choropleth.regions.single.value, 42.5);
      expect(choropleth.regions.single.polygons.single, hasLength(4));

      final parallel = ParallelChartConfig.fromJson({
        'axes': ['Price', 2026, 'Score'],
        'lineOpacity': '0.35',
        'series': [
          {
            'name': 'Mixed',
            'data': [
              ['10', '20', '30'],
              [
                {'value': '12'},
                '22',
                '32',
              ],
              {
                'values': ['14', '24', '34'],
              },
            ],
          },
        ],
      });
      expect(parallel.axes, ['Price', '2026', 'Score']);
      expect(parallel.lineOpacity, 0.35);
      expect(parallel.series, hasLength(1));
    });

    testWidgets('choropleth and parallel render string payloads', (
      tester,
    ) async {
      final charts = [
        ChoroplethChartConfig.fromJson({
          'showLabels': 'true',
          'series': [
            {
              'regions': [
                {
                  'id': 'A',
                  'name': 'Region A',
                  'value': '64',
                  'polygon': [
                    ['-125', '49'],
                    ['-95', '49'],
                    ['-95', '25'],
                    ['-125', '25'],
                  ],
                },
              ],
            },
          ],
        }).buildChart(),
        ParallelChartConfig.fromJson({
          'axes': ['A', 'B', 'C'],
          'lineOpacity': '0.4',
          'series': [
            {
              'name': 'Rows',
              'data': [
                ['10', '30', '20'],
                [
                  {'value': '18'},
                  '36',
                  '25',
                ],
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
  });
}
