import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/pie/customized_pie_chart.dart';
import 'package:tenun/charts/pie/pie_chart_variants.dart';
import 'package:tenun/charts/pie/pie_label_align_chart.dart';
import 'package:tenun/charts/pie/pie_special_label_chart.dart';

void main() {
  group('pie family config robustness', () {
    test('core pie variants tolerate stringly typed payloads', () {
      final donut = DonutChartConfig.fromJson({
        'innerRadiusRatio': '2',
        'showLabels': 'no',
        'showPercentage': 'yes',
        'padAngle': '99',
        'legend': {'show': '1'},
        'series': [
          {
            'data': [
              {'name': 2026, 'value': '12'},
              {'name': 'Invalid', 'value': '-4'},
            ],
          },
        ],
      });
      expect(donut.innerRadiusRatio, 1);
      expect(donut.showLabels, isFalse);
      expect(donut.showPercentage, isTrue);
      expect(donut.padAngle, lessThanOrEqualTo(1.5707963267948966));
      expect(donut.legend?.show, isTrue);
      expect(donut.slices.map((slice) => slice.name), ['2026', 'Invalid']);
      expect(donut.slices.map((slice) => slice.value), [12, 0]);

      final nested = NestedPieChartConfig.fromJson({
        'ringGap': '-8',
        'series': [
          {
            'name': 2025,
            'data': [
              {'name': 'A', 'value': '10'},
            ],
          },
        ],
      });
      expect(nested.ringGap, 0);
      expect(nested.rings.single.name, '2025');
      expect(nested.rings.single.slices.single.value, 10);

      final partition = PartitionPieChartConfig.fromJson({
        'partitionIndex': '99',
        'series': [
          {
            'name': 'main',
            'data': [
              {'name': 'Total', 'value': '80'},
              {'name': 'Other', 'value': '20'},
            ],
          },
          {
            'name': 'partition',
            'data': [
              {'name': 'Online', 'value': '45'},
            ],
          },
        ],
      });
      expect(partition.partitionIndex, 1);
      expect(partition.mainSlices, hasLength(2));
      expect(partition.subSlices.single.value, 45);

      final calendar = CalendarPieChartConfig.fromJson({
        'year': '2026',
        'month': '20',
        'series': [
          {
            'data': [
              {
                'day': '2',
                'data': [
                  {'name': 'Win', 'value': '3'},
                ],
              },
            ],
          },
        ],
      });
      expect(calendar.year, 2026);
      expect(calendar.month, 12);
      expect(calendar.days.single.day, 2);
      expect(calendar.days.single.slices.single.value, 3);
    });

    test('standalone pie variants use the shared defensive reader', () {
      final custom = CustomizedPieConfig.fromJson({
        'showLabels': '0',
        'padAngle': '99',
        'series': [
          {
            'data': [
              {
                'name': 'A',
                'value': '12',
                'selected': 'yes',
                'explode': '999',
                'borderWidth': '2',
              },
            ],
          },
        ],
      });
      expect(custom.showLabels, isFalse);
      expect(custom.padAngle, lessThanOrEqualTo(1.5707963267948966));
      expect(custom.slices.single.selected, isTrue);
      expect(custom.slices.single.explode, 48);

      final labelAlign = PieLabelAlignConfig.fromJson({
        'slices': [
          {'name': 42, 'value': '7'},
        ],
      });
      expect(labelAlign.slices.single.name, '42');
      expect(labelAlign.slices.single.value, 7);

      final special = PieSpecialLabelConfig.fromJson({
        'innerRadiusRatio': '-1',
        'series': [
          {
            'data': [
              {'name': 'A', 'value': '9', 'subLabel': 2026},
            ],
          },
        ],
      });
      expect(special.innerRadiusRatio, 0);
      expect(special.slices.single.subLabel, '2026');
    });

    testWidgets('pie family renders mixed JSON values', (tester) async {
      final basicSeries = [
        {
          'data': [
            {'name': 'A', 'value': '30'},
            {'name': 'B', 'value': '20'},
            {'name': 'C', 'value': '10'},
          ],
        },
      ];
      final charts = [
        DonutChartConfig.fromJson({'series': basicSeries}).buildChart(),
        HalfDonutChartConfig.fromJson({'series': basicSeries}).buildChart(),
        PaddedPieChartConfig.fromJson({'series': basicSeries}).buildChart(),
        NightingaleChartConfig.fromJson({'series': basicSeries}).buildChart(),
        NestedPieChartConfig.fromJson({
          'series': [
            {'name': 'Outer', 'data': basicSeries.first['data']},
          ],
        }).buildChart(),
        PartitionPieChartConfig.fromJson({
          'series': [
            {'data': basicSeries.first['data']},
            {
              'data': [
                {'name': 'A1', 'value': '18'},
                {'name': 'A2', 'value': '12'},
              ],
            },
          ],
        }).buildChart(),
        CalendarPieChartConfig.fromJson({
          'year': '2026',
          'month': '6',
          'series': [
            {
              'data': [
                {'day': '1', 'data': basicSeries.first['data']},
              ],
            },
          ],
        }).buildChart(),
        PieLabelLineConfig.fromJson({'series': basicSeries}).buildChart(),
        CustomizedPieConfig.fromJson({'series': basicSeries}).buildChart(),
        PieLabelAlignConfig.fromJson({'series': basicSeries}).buildChart(),
        PieSpecialLabelConfig.fromJson({'series': basicSeries}).buildChart(),
      ];

      for (final chart in charts) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 420, height: 300, child: chart),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
