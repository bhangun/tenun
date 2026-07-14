import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/ai_ml/confusion_matrix_config.dart';
import 'package:tenun/charts/ai_ml/roc_curve_config.dart';
import 'package:tenun/charts/bar/bar_config.dart';
import 'package:tenun/charts/bar/bar_series.dart';
import 'package:tenun/charts/bullet/bullet_chart.dart';
import 'package:tenun/charts/calendar/calendar_chart.dart';
import 'package:tenun/charts/funnel/funnel_config.dart';
import 'package:tenun/charts/gantt/gantt_chart.dart';
import 'package:tenun/charts/indicator/indicator_chart.dart';
import 'package:tenun/charts/line/line_config.dart';
import 'package:tenun/charts/line/line_series.dart';
import 'package:tenun/charts/network/network_radial_timeline_wordcloud_charts.dart';
import 'package:tenun/charts/pareto/pareto_config.dart';
import 'package:tenun/charts/s_curve/s_curve_config.dart';
import 'package:tenun/charts/sankey/sankey.dart';
import 'package:tenun/charts/sunburst/sunburst.dart';
import 'package:tenun/charts/treemap/treemap_chart.dart';
import 'package:tenun/charts/waterfall/waterfall_chart.dart';
import 'package:tenun_core/core/chart_axis_config.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/label.dart';
import 'package:tenun_core/core/series.dart';

void main() {
  group('config factory robustness', () {
    test(
      'bar config accepts JSON-like strings and malformed optional styles',
      () {
        final config = BarChartConfig.fromJson({
          'type': 'bar',
          'maxY': '120',
          'barWidth': '18',
          'barBorderRadius': {'topLeft': '7'},
          'alignment': 'space_between',
          'isStacked': 'yes',
          'isHorizontal': '0',
          'isMultiBar': 1,
          'theme': 'not-a-theme-map',
          'series': [
            {
              'name': 123,
              'itemStyle': 'not-a-map',
              'data': [
                '4',
                ['B', '8'],
                {'value': '12'},
              ],
            },
          ],
        });

        expect(config.maxY, 120);
        expect(config.barWidth, 18);
        expect(config.barBorderRadiusValue, 7);
        expect(config.alignment, BarChartAlignment.spaceBetween);
        expect(config.isStacked, isTrue);
        expect(config.isHorizontal, isFalse);
        expect(config.isMultiBar, isTrue);
        expect(config.series.single.name, '123');
        expect(config.series.single.itemStyle?.color, 'black');
        expect(config.getMaxSeriesValue(), closeTo(14.4, 0.0001));
      },
    );

    test('line config tolerates typed strings and bad series container', () {
      final config = LineChartConfig.fromJson({
        'maxY': '80',
        'showBelowArea': 'yes',
        'showDots': 'false',
        'curveSmoothness': '0.35',
        'dotSize': '6',
        'legend': 'not-a-map',
        'series': 'not-a-list',
      });

      expect(config.maxY, 80);
      expect(config.showBelowArea, isTrue);
      expect(config.showDots, isFalse);
      expect(config.curveSmoothness, 0.35);
      expect(config.dotSize, 6);
      expect(config.series, isEmpty);
      expect(config.legend, isNotNull);
    });

    test('series and style factories default malformed optional fields', () {
      final itemStyle = ItemStyle.fromJson('bad-style');
      expect(itemStyle.color, 'black');
      expect(itemStyle.borderColor, 'grey');

      final barSeries = BarSeries.fromJson({
        'name': 7,
        'data': 'not-a-list',
        'barWidth': '10',
        'barMaxWidth': '22',
      });
      expect(barSeries.name, '7');
      expect(barSeries.data, isNull);
      expect(barSeries.barWidth, 10);
      expect(barSeries.barMaxWidth, 22);

      final lineSeries = LineSeries.fromJson({
        'name': 'Trend',
        'data': [1, 2],
        'smooth': 'true',
        'sampling': '2.5',
        'lineStyle': 'bad-line-style',
      });
      expect(lineSeries.smooth, isTrue);
      expect(lineSeries.sampling, 2.5);
      expect(lineSeries.lineStyle, isNotNull);
    });

    test(
      'theme and legacy chart config ignore malformed structural fields',
      () {
        final theme = ChartTheme.fromJson({
          'backgroundColor': 'not-a-color',
          'palette': ['#112233', 'not-a-color', null, '#445566'],
        });
        expect(theme.palette.colors, ['#112233', '#445566']);

        final toolbox = ChartToolbox.fromJson({
          'show': 'yes',
          'feature': 'bad',
        });
        expect(toolbox.show, isTrue);
        expect(toolbox.feature, isNull);

        final config = ChartConfig.fromJson({
          'type': 'bar',
          'series': 'not-a-list',
          'toolbox': {'show': 'true'},
        });
        expect(config.series, isEmpty);
        expect(config.toolbox?.show, isTrue);
        expect(config.getMax(), 0);
      },
    );

    test('series defensively copies data and toJson collections', () {
      final sourceData = [
        {
          'x': 1,
          'items': [1, 2],
        },
      ];
      final sourceLabels = ['A', 'B'];

      final series = Series(
        type: ChartType.line,
        data: sourceData,
        dataLabels: sourceLabels,
      );

      (sourceData.first['items'] as List).clear();
      sourceLabels.clear();

      expect((series.data!.single as Map)['items'], [1, 2]);
      expect(series.dataLabels, ['A', 'B']);
      expect(() => series.data!.add(3), throwsUnsupportedError);
      expect(() => series.dataLabels!.add('C'), throwsUnsupportedError);

      final json = series.toJson();
      (((json['data'] as List).single as Map)['items'] as List).clear();
      (json['dataLabels'] as List)[0] = 'Changed';

      expect((series.data!.single as Map)['items'], [1, 2]);
      expect(series.dataLabels, ['A', 'B']);
    });

    test('config constructors defensively copy series lists', () {
      final series = Series(type: ChartType.line, data: const [1, 2]);
      final sourceSeries = [series];

      final lineConfig = LineChartConfig(series: sourceSeries);
      final legacyConfig = ChartConfig(series: sourceSeries);
      sourceSeries.clear();

      expect(lineConfig.series, [series]);
      expect(legacyConfig.series, [series]);
      expect(() => lineConfig.series.add(series), throwsUnsupportedError);
      expect(() => legacyConfig.series.add(series), throwsUnsupportedError);
    });

    test('axis toJson returns detached category lists', () {
      final axis = ChartAxisConfig.category(categories: ['A', 'B']);
      final json = axis.toJson();

      (json['categories'] as List)[0] = 'Changed';

      expect(axis.categories, ['A', 'B']);
    });

    test('ai and business configs tolerate stringly typed payloads', () {
      final roc = ROCCurveChartConfig.fromJson({
        'series': [
          {
            'name': 42,
            'data': [
              [0, 0],
              [0.2, 0.7],
            ],
          },
          'bad-series',
        ],
        'showChanceLine': 'false',
        'chanceLineColor': 'bad-color',
      });
      expect(roc.series, hasLength(1));
      expect(roc.series.single.name, '42');
      expect(roc.showChanceLine, isFalse);
      expect(roc.chanceLineColor, Colors.grey);

      final confusion = ConfusionMatrixChartConfig.fromJson({
        'labels': [1, 'B'],
        'data': [
          ['24', '3'],
          [4.0, 19],
          'bad-row',
        ],
        'baseColor': 'bad-color',
        'showPercentages': 'no',
      });
      expect(confusion.labels, ['1', 'B']);
      expect(confusion.data, [
        [24, 3],
        [4, 19],
      ]);
      expect(confusion.baseColor, Colors.blue);
      expect(confusion.showPercentages, isFalse);

      final sCurve = SCurveChartConfig.fromJson({
        'series': [
          {
            'name': 'Actual',
            'data': [8, 22],
          },
          'bad-series',
        ],
        'autoCumulative': 'no',
        'targetValue': '1,250.5',
      });
      expect(sCurve.series, hasLength(1));
      expect(sCurve.autoCumulative, isFalse);
      expect(sCurve.targetValue, 1250.5);
    });

    test('flow and kpi configs tolerate stringly typed payloads', () {
      final funnel = FunnelChartConfig.fromJson({
        'funnelMode': 'pyramid',
        'showLabels': '0',
        'showValues': 1,
        'showPercentage': 'yes',
        'showConversionRate': 'no',
        'neckWidthFraction': '0.22',
        'gapFraction': '0.03',
        'series': [
          {
            'data': [
              {'name': 100, 'value': '1,200'},
              {'name': 'Lead', 'value': '720'},
            ],
          },
          'bad-series',
        ],
      });
      expect(funnel.funnelMode, FunnelMode.pyramid);
      expect(funnel.items.map((item) => item.value), [1200, 720]);
      expect(funnel.showLabels, isFalse);
      expect(funnel.showValues, isTrue);
      expect(funnel.showPercentage, isTrue);
      expect(funnel.showConversionRate, isFalse);
      expect(funnel.neckWidthFraction, 0.22);
      expect(funnel.gapFraction, 0.03);

      final waterfall = WaterfallChartConfig.fromJson({
        'showConnectors': 'no',
        'showRunningTotal': 'yes',
        'barWidthFraction': '0.7',
        'increaseColor': '0xFF00AA88',
        'decreaseColor': '#F44336',
        'totalColor': 'blue',
        'series': [
          {
            'data': [
              {'name': 'Opening', 'value': '500', 'type': 'total'},
              {'name': 'Cost', 'value': '-25'},
            ],
          },
        ],
      });
      expect(waterfall.items, hasLength(2));
      expect(waterfall.items.last.itemType, WaterfallItemType.decrease);
      expect(waterfall.showConnectors, isFalse);
      expect(waterfall.showRunningTotal, isTrue);
      expect(waterfall.increaseColor, const Color(0xFF00AA88));
      expect(waterfall.barWidthFraction, 0.7);

      final sankey = SankeyChartConfig.fromJson({
        'showLabels': 'false',
        'showValues': 'true',
        'series': [
          {
            'nodes': [
              {'id': 'a', 'name': 'A', 'column': '0'},
              {'id': 'b', 'name': 'B', 'column': '1'},
            ],
            'links': [
              {'source': 'a', 'target': 'b', 'value': '2,500'},
            ],
          },
        ],
      });
      expect(sankey.nodes.map((node) => node.column), [0, 1]);
      expect(sankey.links.single.value, 2500);
      expect(sankey.showLabels, isFalse);
      expect(sankey.showValues, isTrue);

      final treemap = TreemapChartConfig.fromJson({
        'showLabels': 'no',
        'showValues': 'yes',
        'borderWidth': '3.5',
        'series': [
          {
            'data': [
              {
                'name': 'Tech',
                'value': '45',
                'children': [
                  {'name': 'AAPL', 'value': '20'},
                ],
              },
            ],
          },
        ],
      });
      expect(treemap.nodes.single.value, 45);
      expect(treemap.nodes.single.children.single.value, 20);
      expect(treemap.showLabels, isFalse);
      expect(treemap.showValues, isTrue);
      expect(treemap.borderWidth, 3.5);

      final indicator = IndicatorChartConfig.fromJson({
        'value': '1,234.56',
        'previousValue': '1000',
        'precision': '2',
        'label': 42,
      });
      expect(indicator.value, 1234.56);
      expect(indicator.previousValue, 1000);
      expect(indicator.precision, 2);
      expect(indicator.label, '42');

      final pareto = ParetoChartConfig.fromJson({
        'autoSort': 'no',
        'lineIndicatorColor': 'bad-color',
        'series': [
          {
            'name': 'Causes',
            'type': 'bar',
            'data': [4, '3'],
          },
          'bad-series',
        ],
      });
      expect(pareto.series, hasLength(1));
      expect(pareto.autoSort, isFalse);
      expect(pareto.lineIndicatorColor, Colors.orange);
    });

    test(
      'structured single-series configs tolerate stringly typed payloads',
      () {
        final bullet = BulletChartConfig.fromJson({
          'showLabels': 'false',
          'showValues': 'yes',
          'barHeightFraction': '0.42',
          'series': [
            {
              'data': [
                {
                  'label': 7,
                  'value': '270',
                  'target': '300',
                  'max': '400',
                  'bands': [
                    {'from': '0', 'to': '200', 'color': 'bad-color'},
                  ],
                },
              ],
            },
          ],
        });
        expect(bullet.items.single.label, '7');
        expect(bullet.items.single.value, 270);
        expect(bullet.items.single.bands.single.to, 200);
        expect(bullet.items.single.bands.single.color, const Color(0xFFCCCCCC));
        expect(bullet.showLabels, isFalse);
        expect(bullet.showValues, isTrue);
        expect(bullet.barHeightFraction, 0.42);

        final sunburst = SunburstChartConfig.fromJson({
          'showLabels': 'no',
          'showValues': 'yes',
          'innerFraction': '0.24',
          'startAngle': '-120',
          'series': [
            {
              'data': [
                {
                  'name': 'Root',
                  'value': '60',
                  'children': [
                    {'name': 'Child', 'value': '25'},
                  ],
                },
              ],
            },
          ],
        });
        expect(sunburst.nodes.single.value, 60);
        expect(sunburst.nodes.single.children.single.value, 25);
        expect(sunburst.showLabels, isFalse);
        expect(sunburst.showValues, isTrue);
        expect(sunburst.innerFraction, 0.24);
        expect(sunburst.startAngleDeg, -120);

        final calendar = CalendarChartConfig.fromJson({
          'year': '2026',
          'emptyColor': 'bad-color',
          'maxColor': '#00AA88',
          'series': [
            {
              'data': [
                {'date': '2026-01-01', 'value': '4.5'},
              ],
            },
          ],
        });
        expect(calendar.year, 2026);
        expect(calendar.dateValues['2026-01-01'], 4.5);
        expect(calendar.emptyColor, const Color(0xFFEEEEEE));
        expect(calendar.maxColor, const Color(0xFF00AA88));

        final gantt = GanttChartConfig.fromJson({
          'showDependencies': 'no',
          'showProgress': 'yes',
          'showToday': '0',
          'showGroups': '1',
          'rowHeight': '44',
          'series': [
            {
              'data': [
                {
                  'id': 't1',
                  'name': 'Build',
                  'start': '2026-01-01',
                  'duration': '3',
                  'progress': '55.5',
                  'milestone': 'false',
                  'deps': [1, 't0'],
                },
              ],
            },
          ],
        });
        expect(gantt.tasks.single.progress, 55.5);
        expect(gantt.tasks.single.end, DateTime(2026, 1, 4));
        expect(gantt.tasks.single.deps, ['1', 't0']);
        expect(gantt.showDependencies, isFalse);
        expect(gantt.showToday, isFalse);
        expect(gantt.showGroups, isTrue);
        expect(gantt.rowHeight, 44);

        final network = NetworkChartConfig.fromJson({
          'showLabels': 'false',
          'iterations': '24',
          'series': [
            {
              'nodes': [
                {'id': 'a', 'name': 'A', 'size': '20'},
                {'id': 'b', 'name': 'B', 'size': '16'},
              ],
              'links': [
                {'source': 'a', 'target': 'b', 'value': '5.5'},
              ],
            },
          ],
        });
        expect(network.nodes.map((node) => node.size), [20, 16]);
        expect(network.links.single.value, 5.5);
        expect(network.showLabels, isFalse);
        expect(network.iterations, 24);

        final radial = RadialChartConfig.fromJson({
          'showLabels': 'no',
          'startAngle': '-135',
          'trackOpacity': '0.25',
          'series': [
            {
              'data': [
                {'label': 'Revenue', 'value': '78', 'max': '100'},
              ],
            },
          ],
        });
        expect(radial.rings.single.value, 78);
        expect(radial.showLabels, isFalse);
        expect(radial.startAngleDeg, -135);
        expect(radial.trackOpacity, 0.25);

        final timeline = TimelineChartConfig.fromJson({
          'alternating': 'yes',
          'series': [
            {
              'data': [
                {'date': 2026, 'label': 1, 'detail': 2},
              ],
            },
          ],
        });
        expect(timeline.events.single.date, '2026');
        expect(timeline.events.single.label, '1');
        expect(timeline.events.single.detail, '2');
        expect(timeline.alternating, isTrue);

        final wordcloud = WordcloudChartConfig.fromJson({
          'minFontSize': '12',
          'maxFontSize': '48',
          'layoutSeed': '7',
          'series': [
            {
              'data': [
                {'text': 42, 'weight': '95'},
              ],
            },
          ],
        });
        expect(wordcloud.words.single.text, '42');
        expect(wordcloud.words.single.weight, 95);
        expect(wordcloud.minFontSize, 12);
        expect(wordcloud.maxFontSize, 48);
        expect(wordcloud.layoutSeed, 7);
      },
    );
  });
}
