import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart' show ChartType, Series;
import 'package:tenun/charts/bar/bar_chart_variants.dart';

void main() {
  Widget host(Widget chart) {
    return MaterialApp(
      home: Scaffold(body: SizedBox(width: 520, height: 340, child: chart)),
    );
  }

  group('bar variant family config robustness', () {
    test('background bar config tolerates stringly typed payloads', () {
      final config = BarBackgroundChartConfig.fromJson({
        'xLabels': ['Mon', 2, 'Wed'],
        'trackOpacity': '2',
        'barWidthRatio': '-1',
        'showValues': 'no',
        'title': {'text': 2026},
        'series': [
          {
            'name': 'Actual',
            'data': [
              '12',
              ['Tue', '18'],
              {'value': '24'},
            ],
          },
        ],
      });

      expect(config.categories, ['Mon', '2', 'Wed']);
      expect(config.trackOpacity, 1);
      expect(config.barWidthRatio, 0);
      expect(config.showValues, isFalse);
      expect(config.title?.text, '2026');
      expect(config.series, hasLength(1));
    });

    test('bar race config accepts map frames and string options', () {
      final config = BarRaceChartConfig.fromJson({
        'frameDuration': '0',
        'autoPlay': '0',
        'loop': 'no',
        'showControls': 'yes',
        'showStepControls': 'false',
        'showProgressIndicator': '1',
        'showFrameLabel': 'true',
        'maxBars': '-3',
        'frames': {
          '2025': {'Alpha': '10', 'Beta': '20'},
          '2026': {
            'values': {
              'Alpha': '14',
              'Beta': ['ignored', '24'],
            },
          },
        },
        'markers': {
          'Alpha': {'text': 7, 'size': '-4', 'borderWidth': '2'},
        },
      });

      expect(config.frameDuration, 1);
      expect(config.autoPlay, isFalse);
      expect(config.loop, isFalse);
      expect(config.showControls, isTrue);
      expect(config.showStepControls, isFalse);
      expect(config.showProgressIndicator, isTrue);
      expect(config.showFrameLabel, isTrue);
      expect(config.maxBars, 1);
      expect(config.frames.map((frame) => frame.label), ['2025', '2026']);
      expect(config.frames.first.values, {'Alpha': 10, 'Beta': 20});
      expect(config.frames.last.values, {'Alpha': 14, 'Beta': 24});
      expect(config.markers['Alpha']?.text, '7');
      expect(config.markers['Alpha']?.size, 0);
      expect(config.markers['Alpha']?.borderWidth, 2);
    });

    test('gradient and rotated label configs tolerate flexible payloads', () {
      final gradient = BarGradientChartConfig.fromJson({
        'labels': ['Q1', 2, 'Q3'],
        'gradientStart': 42,
        'gradientEnd': '#0D47A1',
        'barWidthRatio': '2',
        'showValues': 'no',
        'series': [
          {
            'name': 'Pipeline',
            'data': [
              '120',
              ['Q2', '200'],
              {'value': '150'},
            ],
          },
        ],
      });
      expect(gradient.categories, ['Q1', '2', 'Q3']);
      expect(gradient.gradientStart, '42');
      expect(gradient.barWidthRatio, 1);
      expect(gradient.showValues, isFalse);

      final rotated = BarLabelRotationConfig.fromJson({
        'xLabels': ['January', 2, 'March'],
        'labelRotation': '180',
        'barWidthRatio': '-1',
        'showValues': 'yes',
        'series': [
          {
            'name': 'Revenue',
            'data': [
              '820',
              ['Feb', '932'],
              {'value': '901'},
            ],
          },
        ],
      });
      expect(rotated.categories, ['January', '2', 'March']);
      expect(rotated.labelRotation, 90);
      expect(rotated.barWidthRatio, 0);
      expect(rotated.showValues, isTrue);
    });

    test(
      'rounded and normalized stacked configs tolerate flexible payloads',
      () {
        final rounded = BarRoundedStackedConfig.fromJson({
          'labels': ['Q1', 2, 'Q3'],
          'cornerRadius': '-8',
          'showValues': 'yes',
          'series': _stackedPayload(),
        });
        expect(rounded.categories, ['Q1', '2', 'Q3']);
        expect(rounded.cornerRadius, 0);
        expect(rounded.showValues, isTrue);
        expect(rounded.series, hasLength(2));

        final normalized = BarNormalizedConfig.fromJson({
          'xLabels': ['Q1', 2, 'Q3'],
          'showPercentLabels': '0',
          'series': _stackedPayload(),
        });
        expect(normalized.categories, ['Q1', '2', 'Q3']);
        expect(normalized.showPercentLabels, isFalse);
        expect(normalized.series, hasLength(2));
      },
    );

    test('diverging, brush, and polar configs tolerate flexible payloads', () {
      final diverging = NegativeBarConfig.fromJson({
        'xLabels': ['Profit', 2, 'Costs'],
        'showValues': 'false',
        'series': [
          {
            'name': 'Delta',
            'data': [
              '120',
              ['Revenue', '-80'],
              {'value': '45'},
            ],
          },
        ],
      });
      expect(diverging.categories, ['Profit', '2', 'Costs']);
      expect(diverging.showValues, isFalse);
      expect(diverging.series, hasLength(1));

      final brush = BarBrushConfig.fromJson({
        'labels': ['Jan', 2, 'Mar'],
        'showValues': 'yes',
        'series': _mixedPayload(),
      });
      expect(brush.categories, ['Jan', '2', 'Mar']);
      expect(brush.showValues, isTrue);

      final polar = TangentialPolarBarConfig.fromJson({
        'xLabels': ['North', 2, 'South'],
        'showValues': '0',
        'innerRadius': '2',
        'series': _mixedPayload(),
      });
      expect(polar.categories, ['North', '2', 'South']);
      expect(polar.showValues, isFalse);
      expect(polar.innerRadius, 0.85);
    });

    testWidgets('background bar and race render mixed JSON values', (
      tester,
    ) async {
      double? tappedGradientValue;
      final charts = [
        BarBackgroundChartConfig.fromJson({
          'categories': ['A', 'B', 'C'],
          'series': [
            {
              'name': 'Score',
              'data': [
                '12',
                ['B', '18'],
                {'value': '24'},
              ],
            },
          ],
        }).buildChart(),
        BarGradientChartConfig(
          categories: const ['A', 'B', 'C'],
          series: _mixedSeries(),
          onBarTap: (_, value) => tappedGradientValue = value,
        ).buildChart(),
        BarLabelRotationConfig.fromJson({
          'xLabels': ['January', 'February', 'March'],
          'labelRotation': '75',
          'series': [
            {
              'name': 'Revenue',
              'data': [
                '820',
                ['Feb', '932'],
                {'value': '901'},
              ],
            },
          ],
        }).buildChart(),
        BarRoundedStackedConfig.fromJson({
          'categories': ['Q1', 'Q2', 'Q3'],
          'showValues': 'true',
          'series': _stackedPayload(),
        }).buildChart(),
        BarNormalizedConfig.fromJson({
          'categories': ['Q1', 'Q2', 'Q3'],
          'series': _stackedPayload(),
        }).buildChart(),
        NegativeBarConfig.fromJson({
          'xLabels': ['Profit', 'Costs', 'Growth'],
          'series': [
            {
              'name': 'Delta',
              'data': [
                '120',
                ['Costs', '-80'],
                {'value': '45'},
              ],
            },
          ],
        }).buildChart(),
        TangentialPolarBarConfig.fromJson({
          'labels': ['North', 'East', 'South'],
          'innerRadius': '0.25',
          'series': _mixedPayload(),
        }).buildChart(),
        BarBrushConfig.fromJson({
          'categories': ['Jan', 'Feb', 'Mar'],
          'series': _mixedPayload(),
        }).buildChart(),
        BarRaceChartConfig.fromJson({
          'autoPlay': 'false',
          'showControls': 'true',
          'categories': ['Alpha', 'Beta'],
          'frameLabels': [2025, 2026],
          'frames': [
            ['10', '20'],
            [
              '14',
              ['Beta', '24'],
            ],
          ],
          'markers': {
            'Alpha': {'text': 'A'},
            'Beta': 'B',
          },
        }).buildChart(),
      ];

      for (final chart in charts) {
        await tester.pumpWidget(host(chart));
        await tester.pump(const Duration(milliseconds: 1000));
        if (chart is BarGradientWidget) {
          await tester.tapAt(const Offset(240, 220));
          await tester.pump();
          expect(tappedGradientValue, isNotNull);
        }
        expect(tester.takeException(), isNull);
      }
    });
  });
}

List<Series> _mixedSeries() {
  return [
    Series(
      type: ChartType.bar,
      name: 'Pipeline',
      data: const [
        '120',
        ['Q2', '200'],
        {'value': '150'},
      ],
    ),
  ];
}

List<Map<String, Object?>> _mixedPayload() {
  return [
    {
      'name': 'Actual',
      'data': [
        '120',
        ['Q2', '200'],
        {'value': '150'},
      ],
    },
  ];
}

List<Map<String, Object?>> _stackedPayload() {
  return [
    {
      'name': 'Base',
      'data': [
        '12',
        ['Q2', '18'],
        {'value': '14'},
      ],
    },
    {
      'name': 'Growth',
      'data': [
        '8',
        ['Q2', '10'],
        {'value': '9'},
      ],
    },
  ];
}
