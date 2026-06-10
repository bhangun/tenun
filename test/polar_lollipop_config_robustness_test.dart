import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/lollipop/lollipop_chart.dart';
import 'package:tenun/charts/polar_bar/polar_bar_chart.dart';
import 'package:tenun/charts/polar_line/polar_line_config.dart';

void main() {
  group('polar and lollipop config robustness', () {
    test('configs tolerate stringly typed payloads', () {
      final polarBar = PolarBarChartConfig.fromJson({
        'categories': [1, 'Feb'],
        'showLabels': 'no',
        'stacked': 'yes',
        'innerRadius': '0.35',
        'startAngle': '-120',
        'series': [
          {
            'name': 'Revenue',
            'data': ['100', '1,200'],
          },
          'bad-series',
        ],
      });
      expect(polarBar.categories, ['1', 'Feb']);
      expect(polarBar.series, hasLength(1));
      expect(polarBar.showLabels, isFalse);
      expect(polarBar.stacked, isTrue);
      expect(polarBar.innerRadiusFraction, 0.35);
      expect(polarBar.startAngleDeg, -120);

      final polarLine = PolarLineChartConfig.fromJson({
        'categories': ['North', 2],
        'series': [
          {
            'name': 'Score',
            'data': ['25', '50'],
          },
          'bad-series',
        ],
      });
      expect(polarLine.categories, ['North', '2']);
      expect(polarLine.series, hasLength(1));

      final lollipop = LollipopChartConfig.fromJson({
        'categories': ['A', 2],
        'horizontal': '1',
        'dotRadius': '8.5',
        'stemWidth': '2.5',
        'series': [
          {
            'name': 'Actual',
            'data': ['42', '68'],
          },
          'bad-series',
        ],
      });
      expect(lollipop.categories, ['A', '2']);
      expect(lollipop.series, hasLength(1));
      expect(lollipop.horizontal, isTrue);
      expect(lollipop.dotRadius, 8.5);
      expect(lollipop.stemWidth, 2.5);
    });

    testWidgets('charts render string series data without throwing', (
      tester,
    ) async {
      final configs = [
        PolarBarChartConfig.fromJson({
          'categories': ['A', 'B'],
          'series': [
            {
              'name': 'Revenue',
              'data': ['100', '1,200'],
            },
          ],
        }).buildChart(),
        PolarLineChartConfig.fromJson({
          'categories': ['North', 'South'],
          'series': [
            {
              'name': 'Score',
              'data': ['25', '50'],
            },
          ],
        }).buildChart(),
        LollipopChartConfig.fromJson({
          'categories': ['A', 'B'],
          'series': [
            {
              'name': 'Actual',
              'data': ['42', '68'],
            },
          ],
        }).buildChart(),
      ];

      for (final chart in configs) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 260, height: 220, child: chart),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
