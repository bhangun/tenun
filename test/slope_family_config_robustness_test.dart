import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/slope/slope_dumbbell_areabump_charts.dart';

void main() {
  group('slope comparison family config robustness', () {
    test('slope config tolerates stringly typed payloads', () {
      final config = SlopeChartConfig.fromJson({
        'categories': ['Before', 2026],
        'showDelta': 'no',
        'showEndLabels': '1',
        'lineWidth': '-3',
        'title': {'text': 42},
        'series': [
          {
            'name': 'Activation',
            'data': [
              '54',
              ['after', '76'],
            ],
          },
        ],
      });

      expect(config.columnLabels, ['Before', '2026']);
      expect(config.showDelta, isFalse);
      expect(config.showEndLabels, isTrue);
      expect(config.lineWidth, 0);
      expect(config.title?.text, '42');
      expect(config.series, hasLength(1));
    });

    test('dumbbell config tolerates aliases and numeric strings', () {
      final config = DumbbellChartConfig.fromJson({
        'labels': ['Engineering', 2026],
        'showValues': 'false',
        'dotRadius': '-5',
        'tooltip': {'show': 'yes'},
        'series': [
          {
            'name': 'Min',
            'data': ['65', '55'],
          },
          {
            'name': 'Max',
            'data': [
              ['Engineering', '120'],
              '95',
            ],
          },
        ],
      });

      expect(config.categories, ['Engineering', '2026']);
      expect(config.showValues, isFalse);
      expect(config.dotRadius, 0);
      expect(config.tooltip?.show, isTrue);
      expect(config.series, hasLength(2));
    });

    test('area bump config tolerates aliases and clamps ratios', () {
      final config = AreaBumpChartConfig.fromJson({
        'categories': [2024, '2025', '2026'],
        'bandOpacity': '2',
        'smoothing': '-0.5',
        'bumps': [
          {
            'name': 7,
            'data': ['1', '2', 'bad', '0', '3'],
            'color': '#2563EB',
          },
        ],
      });

      expect(config.periods, ['2024', '2025', '2026']);
      expect(config.bandOpacity, 1);
      expect(config.smoothing, 0);
      expect(config.bumps.single.name, '7');
      expect(config.bumps.single.ranks, [1, 2, 3]);
    });

    testWidgets('slope family charts render mixed JSON values', (tester) async {
      final charts = [
        SlopeChartConfig.fromJson({
          'xLabels': ['Start', 'End'],
          'series': [
            {
              'name': 'Retention',
              'data': [
                '70',
                ['end', '84'],
              ],
            },
            {
              'name': 'Risk',
              'data': ['48', '32'],
            },
          ],
        }).buildChart(),
        DumbbellChartConfig.fromJson({
          'categories': ['Engineering', 'Sales'],
          'series': [
            {
              'name': 'Min',
              'data': ['65', '55'],
            },
            {
              'name': 'Max',
              'data': [
                ['Engineering', '120'],
                '95',
              ],
            },
          ],
        }).buildChart(),
        AreaBumpChartConfig.fromJson({
          'periods': ['Q1', 'Q2', 'Q3'],
          'series': [
            {
              'name': 'Product A',
              'ranks': ['1', '2', '1'],
            },
            {
              'name': 'Product B',
              'ranks': ['2', '1', '2'],
            },
          ],
        }).buildChart(),
      ];

      for (final chart in charts) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 420, height: 280, child: chart),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
