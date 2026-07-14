import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/registry/bundle_calendar.dart';
import 'package:tenun/registry/bundle_cartesian.dart';
import 'package:tenun/registry/bundle_common.dart';
import 'package:tenun/registry/bundle_financial.dart';
import 'package:tenun/registry/bundle_flow.dart';
import 'package:tenun/registry/bundle_geo.dart';
import 'package:tenun/registry/bundle_graph.dart';
import 'package:tenun/registry/bundle_hierarchical.dart';
import 'package:tenun/registry/bundle_matrix.dart';
import 'package:tenun/registry/bundle_pie.dart';
import 'package:tenun/registry/bundle_radial.dart';
import 'package:tenun/tenun.dart';

class _ProbeConfig extends BaseChartConfig {
  final Map<String, dynamic> rawJson;

  _ProbeConfig({
    required this.rawJson,
    required super.series,
    super.title,
    super.tooltip,
    super.legend,
    super.grid,
  }) : super(type: ChartType.line);

  factory _ProbeConfig.fromJson(Map<String, dynamic> json) {
    final rawSeries = (json['series'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => Series.fromJson(entry.cast<String, dynamic>()))
        .toList();

    return _ProbeConfig(
      rawJson: Map<String, dynamic>.from(json),
      series: rawSeries,
      title: json['title'] is Map
          ? TitlesData.fromJson((json['title'] as Map).cast<String, dynamic>())
          : null,
      tooltip: json['tooltip'] is Map
          ? ChartTooltip.fromJson(
              (json['tooltip'] as Map).cast<String, dynamic>(),
            )
          : null,
      legend: json['legend'] is Map
          ? ChartLegend.fromJson(
              (json['legend'] as Map).cast<String, dynamic>(),
            )
          : null,
      grid: json['grid'] is Map
          ? GridData.fromJson((json['grid'] as Map).cast<String, dynamic>())
          : null,
    );
  }

  @override
  Widget buildChart() => const SizedBox.shrink();
}

const _probeLineRegistration = ChartRegistration(
  type: ChartType.line,
  typeString: 'line',
  fromJson: _ProbeConfig.fromJson,
);

void main() {
  group('TenunOption', () {
    setUp(() {
      ChartRegistry.clear();
      allChartsBundle.register();
      cartesianChartsBundle.register();
      financialChartsBundle.register();
      flowChartsBundle.register();
      geoChartsBundle.register();
      radialChartsBundle.register();
      commonChartsBundle.register();
      calendarChartsBundle.register();
      graphChartsBundle.register();
      hierarchicalChartsBundle.register();
      matrixChartsBundle.register();
      pieChartsBundle.register();
      ChartRegistry.register(_probeLineRegistration);
    });

    test('build preserves global chart config fields', () {
      final option = TenunOption.fromJson(const {
        'type': 'line',
        'title': {'text': 'Revenue'},
        'tooltip': {'show': false},
        'legend': {'show': true, 'orient': 'horizontal'},
        'grid': {'show': true},
        'xAxis': {
          'data': ['A', 'B'],
        },
        'series': [
          {
            'name': 'Sales',
            'data': [10, 20],
          },
        ],
      });

      final config = option.build() as _ProbeConfig;

      expect(config.title?.text, 'Revenue');
      expect(config.tooltip?.show, isFalse);
      expect(config.legend?.show, isTrue);
      expect(config.grid, isNotNull);
      expect((config.rawJson['xAxis'] as Map)['data'], ['A', 'B']);
      expect(config.series.single.name, 'Sales');
    });

    test('tryBuild returns validation and config for render-safe payloads', () {
      final option = TenunOption.fromJson(const {
        'type': 'line',
        'title': {'text': 'Revenue'},
        'xAxis': {
          'data': ['A', 'B'],
        },
        'series': [
          {
            'name': 'Sales',
            'data': [10, 20],
          },
        ],
      });

      final result = option.tryBuild();

      expect(result.success, isTrue);
      expect(result.resolved, isTrue);
      expect(result.isRenderSafe, isTrue);
      expect(result.buildAttempted, isTrue);
      expect(result.validation.isValid, isTrue);
      expect(result.config, isA<_ProbeConfig>());
      expect(result.error, isNull);
      expect(result.toJson(), containsPair('success', true));
      final diagnosticJson = result.toJson(includePayload: true);
      expect(diagnosticJson, contains('payload'));
      ((((diagnosticJson['payload'] as Map)['series'] as List).single
                  as Map)['data']
              as List)
          .add(999);
      expect(
        (((result.payload['series'] as List).single as Map)['data'] as List),
        [10, 20],
      );
      expect(option.validate().isValid, isTrue);
      expect(option.toRenderJson()['type'], 'line');
    });

    test(
      'tryBuild skips config resolution for invalid payloads by default',
      () {
        final option = TenunOption.fromJson(const {
          'type': 'line',
          'sampling': {'enabled': 'yes'},
          'series': [
            {
              'data': [10, 20],
            },
          ],
        });

        final result = option.tryBuild();

        expect(result.success, isFalse);
        expect(result.resolved, isFalse);
        expect(result.isRenderSafe, isFalse);
        expect(result.buildAttempted, isFalse);
        expect(result.config, isNull);
        expect(result.error, isNull);
        expect(result.validation.isValid, isFalse);
        expect(
          result.validation.errors.map((issue) => issue.code),
          contains('INVALID_SAMPLING_ENABLED_TYPE'),
        );
        expect(result.message, contains('config build skipped'));
      },
    );

    test('tryBuild can capture parser failures without throwing', () {
      final option = TenunOption.fromJson(const {
        'type': 'unregistered_bar',
        'series': [
          {
            'data': [10, 20],
          },
        ],
      });

      final result = option.tryBuild(
        deep: false,
        requireRegisteredType: false,
        buildWhenInvalid: true,
      );

      expect(result.validation.isValid, isFalse);
      expect(result.buildAttempted, isTrue);
      expect(result.success, isFalse);
      expect(result.resolved, isFalse);
      expect(result.config, isNull);
      expect(result.error, isNotNull);
      expect(result.message, contains('config build failed'));
      expect(result.toJson(), contains('error'));
    });

    test('fromJson reads type from first series when root type is absent', () {
      final option = TenunOption.fromJson(const {
        'series': [
          {
            'type': 'area',
            'data': [1, 2, 3],
          },
        ],
      });

      expect(option.primaryType, ChartType.area);
      expect(option.series.single['type'], 'area');
    });

    test('fromJson tolerates malformed series and defaults safely', () {
      final option = TenunOption.fromJson(const {'series': 'not-a-list'});

      expect(option.primaryType, ChartType.bar);
      expect(option.series, isEmpty);
    });

    test('fromJson and inspectors deep-copy nested payload data', () {
      final payload = <String, dynamic>{
        'type': 'line',
        'tooltip': {'show': true},
        'xAxis': {
          'data': ['A', 'B'],
        },
        'series': [
          {
            'name': 'Sales',
            'data': [10, 20],
          },
        ],
      };

      final option = TenunOption.fromJson(payload);
      (((payload['series'] as List).single as Map)['data'] as List).add(99);
      ((payload['xAxis'] as Map)['data'] as List).add('C');
      (payload['tooltip'] as Map)['show'] = false;

      final renderJson = option.toRenderJson();
      final renderSeries = renderJson['series'] as List<dynamic>;
      expect((renderSeries.single as Map)['data'], [10, 20]);
      expect((renderJson['xAxis'] as Map)['data'], ['A', 'B']);
      expect((renderJson['tooltip'] as Map)['show'], isTrue);

      ((renderSeries.single as Map)['data'] as List).add(30);
      ((renderJson['xAxis'] as Map)['data'] as List).add('D');
      (renderJson['tooltip'] as Map)['show'] = false;

      final secondRenderJson = option.toRenderJson();
      final secondSeries = secondRenderJson['series'] as List<dynamic>;
      expect((secondSeries.single as Map)['data'], [10, 20]);
      expect((secondRenderJson['xAxis'] as Map)['data'], ['A', 'B']);
      expect((secondRenderJson['tooltip'] as Map)['show'], isTrue);

      final rawJson = option.toJson();
      (((rawJson['series'] as List).single as Map)['data'] as List).clear();
      expect(
        (((option.toJson()['series'] as List).single as Map)['data'] as List),
        [10, 20],
      );
    });

    test('fromJson can normalize shorthand collection payloads', () {
      final option = TenunOption.fromJson(const {
        'type': 'treemap',
        'showLabels': false,
        'nodes': [
          {'name': 'Tech', 'value': 10},
          {'name': 'Finance', 'value': 8},
        ],
      }, autoNormalizePayload: true);

      final renderJson = option.toRenderJson();
      final series = renderJson['series'] as List<dynamic>;

      expect(option.primaryType, ChartType.treemap);
      expect(option.autoNormalizePayload, isTrue);
      expect(renderJson['type'], 'treemap');
      expect(renderJson['showLabels'], isFalse);
      expect(renderJson['nodes'], isA<List<dynamic>>());
      expect(series, hasLength(1));
      expect(series.single, containsPair('type', 'treemap'));
      expect((series.single as Map)['data'], hasLength(2));
      expect(option.toJson(), isNot(contains('series')));
    });

    test('fromJson honors payload-level auto-normalization flags', () {
      final option = TenunOption.fromJson(const {
        'type': 'calendar',
        'normalization': {'autoNormalizePayload': true},
        'dateValues': {'2026-01-01': 10, '2026-01-02': 12},
      });

      final renderJson = option.toRenderJson();
      final series = renderJson['series'] as List<dynamic>;
      final data = (series.single as Map)['data'] as List<dynamic>;

      expect(option.primaryType, ChartType.calendar);
      expect(option.autoNormalizePayload, isTrue);
      expect(data, hasLength(2));
      expect(data.first, {'date': '2026-01-01', 'value': 10});
    });

    test('switch helpers use normalized render payload for shorthand data', () {
      const payload = {
        'type': 'calendar',
        'dateValues': {'2026-01-01': 10, '2026-01-02': 12},
      };
      final rawOption = TenunOption.fromJson(payload);
      final normalizedOption = TenunOption.fromJson(
        payload,
        autoNormalizePayload: true,
      );

      expect(
        rawOption
            .trySwitchType(ChartType.line, force: true, registeredOnly: false)
            .success,
        isFalse,
      );

      final switched = normalizedOption.trySwitchType(
        ChartType.line,
        force: true,
        registeredOnly: false,
      );
      final validated = normalizedOption.trySwitchTypeValidated(
        ChartType.line,
        force: true,
        registeredOnly: false,
        requireRegisteredType: false,
      );

      expect(switched.success, isTrue);
      expect(switched.payload, isNotNull);
      expect(switched.payload!['type'], 'line');
      expect(switched.changedTopLevelKeys, contains('series'));
      final series = switched.payload!['series'] as List<dynamic>;
      final data = (series.single as Map)['data'] as List<dynamic>;
      expect(data, [10.0, 12.0]);
      expect(validated.isRenderSafe, isTrue);

      final diagnosticJson = validated.toJson(includePayload: true);
      ((((diagnosticJson['payload'] as Map)['series'] as List).single
                  as Map)['data']
              as List)
          .add(99);
      ((((diagnosticJson['switch'] as Map)['payload'] as Map)['series'] as List)
                  .single
              as Map)['data']
          .add(100);
      expect(
        (((validated.payload!['series'] as List).single as Map)['data']
            as List),
        [10.0, 12.0],
      );
    });

    test('fromJson keeps shorthand payloads unchanged without opt-in', () {
      final option = TenunOption.fromJson(const {
        'type': 'treemap',
        'nodes': [
          {'name': 'Tech', 'value': 10},
        ],
      });

      final renderJson = option.toRenderJson();

      expect(option.autoNormalizePayload, isFalse);
      expect(renderJson['nodes'], isA<List<dynamic>>());
      expect(renderJson['series'], isEmpty);
    });
  });
}
