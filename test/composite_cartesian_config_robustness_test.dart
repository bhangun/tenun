import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/bar/rainfall_chart.dart';
import 'package:tenun/charts/combo/combo_chart.dart';
import 'package:tenun/charts/line/multi_x_axes_chart.dart';

void main() {
  group('composite cartesian config robustness', () {
    test('configs tolerate stringly typed payloads', () {
      final combo = ComboChartConfig.fromJson({
        'categories': [1, 'Q2'],
        'showLegend': '0',
        'barGroupWidth': '0.6',
        'dotRadius': '5.5',
        'series': [
          {
            'name': 'Revenue',
            'seriesType': 'bar',
            'data': ['820', '930'],
          },
          {
            'name': 'Margin',
            'seriesType': 'line',
            'yAxis': '1',
            'data': ['27', '31'],
          },
          'bad-series',
        ],
      });
      expect(combo.categories, ['1', 'Q2']);
      expect(combo.comboSeries, hasLength(2));
      expect(combo.comboSeries.last.yAxis, 1);
      expect(combo.comboSeries.first.values, [820, 930]);
      expect(combo.showLegend, isFalse);
      expect(combo.barGroupWidthFraction, 0.6);
      expect(combo.dotRadius, 5.5);

      final rainfall = RainfallChartConfig.fromJson({
        'categories': ['Mon', 2],
        'barWidthRatio': '0.5',
        'showLine': 'yes',
        'series': [
          {
            'name': 'Rain',
            'type': 'bar',
            'data': ['4', '8'],
          },
          {
            'name': 'Average',
            'type': 'line',
            'data': ['5', '7'],
          },
          'bad-series',
        ],
      });
      expect(rainfall.categories, ['Mon', '2']);
      expect(rainfall.series, hasLength(2));
      expect(rainfall.barWidthRatio, 0.5);
      expect(rainfall.showLine, isTrue);

      final multiX = MultiXAxesChartConfig.fromJson({
        'xAxes': [
          {
            'label': 2026,
            'categories': ['Jan', 2],
          },
          'bad-axis',
        ],
        'series': [
          {
            'name': 'Users',
            'xAxisIndex': '0',
            'data': ['100', '1,200'],
          },
          'bad-series',
        ],
      });
      expect(multiX.xAxes.single.label, '2026');
      expect(multiX.xAxes.single.categories, ['Jan', '2']);
      expect(multiX.series, hasLength(1));
    });

    testWidgets('charts render string series data without throwing', (
      tester,
    ) async {
      final charts = [
        ComboChartConfig.fromJson({
          'categories': ['Q1', 'Q2'],
          'series': [
            {
              'name': 'Revenue',
              'seriesType': 'bar',
              'data': ['820', '930'],
            },
            {
              'name': 'Margin',
              'seriesType': 'line',
              'data': ['27', '31'],
            },
          ],
        }).buildChart(),
        RainfallChartConfig.fromJson({
          'categories': ['Mon', 'Tue'],
          'series': [
            {
              'name': 'Rain',
              'type': 'bar',
              'data': ['4', '8'],
            },
            {
              'name': 'Average',
              'type': 'line',
              'data': ['5', '7'],
            },
          ],
        }).buildChart(),
        MultiXAxesChartConfig.fromJson({
          'xAxes': [
            {
              'label': 'Months',
              'categories': ['Jan', 'Feb'],
            },
          ],
          'series': [
            {
              'name': 'Users',
              'data': ['100', '1,200'],
            },
          ],
        }).buildChart(),
      ];

      for (final chart in charts) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 320, height: 240, child: chart),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
