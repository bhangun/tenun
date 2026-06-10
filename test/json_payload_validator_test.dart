import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/core/chart_config_validator.dart';
import 'package:tenun/core/chart_payload_doctor.dart';
import 'package:tenun/core/base_config.dart';
import 'package:tenun/core/chart_registry.dart';
import 'package:tenun/core/chart_type.dart';
import 'package:tenun/registry/chart_registration_bundle.dart';
import 'package:tenun/registry/registry_tools.dart';

void main() {
  setUp(() {
    ChartRegistry.clear();
    allChartsBundle.register();
  });

  group('JSON payload validator', () {
    test('detects missing type', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.code == 'MISSING_TYPE'), isTrue);
    });

    test('detects invalid series type', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'bar',
        'series': {
          'data': [1, 2, 3],
        },
      }, deep: false);

      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.code == 'INVALID_SERIES_TYPE'), isTrue);
    });

    test('unknown chart type includes nearby registry suggestions', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'linne',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      final issue = result.errors.singleWhere(
        (error) => error.code == 'UNKNOWN_TYPE',
      );
      expect(issue.suggestion, contains('line'));
    });

    test('registered type validation accepts separator variants', () {
      final result = ChartConfigValidator.validateJsonPayload(
        const {
          'type': 'line-area',
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        },
        deep: false,
        requireRegisteredType: true,
      );

      expect(
        result.errors.any((error) => error.code == 'UNREGISTERED_TYPE'),
        isFalse,
      );
      expect(result.errors, isEmpty);
    });

    test('unregistered chart type reports registration guidance', () {
      ChartRegistry.clear();

      final result = ChartConfigValidator.validateJsonPayload(
        const {
          'type': 'line',
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        },
        deep: false,
        requireRegisteredType: true,
      );

      final issue = result.errors.singleWhere(
        (error) => error.code == 'UNREGISTERED_TYPE',
      );
      expect(issue.suggestion, contains('Register the type'));
    });

    test('passes valid bar payload', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'bar',
        'xAxis': {
          'data': ['A', 'B', 'C'],
        },
        'series': [
          {
            'name': 'S1',
            'data': [10, 20, 30],
          },
        ],
      }, deep: false);

      expect(result.errors, isEmpty);
    });

    test(
      'passes valid bar race shorthand payload with markers and controls',
      () {
        final result = ChartConfigValidator.validateJsonPayload(const {
          'type': 'barRace',
          'categories': ['Alpha', 'Beta'],
          'frameLabels': ['2025', '2026'],
          'frames': [
            [10, 20],
            [12, 24],
          ],
          'markers': {
            'Alpha': {
              'text': 'A',
              'backgroundColor': '#E6F4FF',
              'borderWidth': 1,
              'size': 28,
            },
          },
          'images': {'Beta': 'assets/beta.png'},
          'autoPlay': false,
          'loop': false,
          'showControls': true,
          'showStepControls': true,
          'showProgressIndicator': true,
          'showFrameLabel': true,
          'frameDuration': 900,
          'maxBars': 2,
        }, deep: false);

        expect(result.errors, isEmpty);
      },
    );

    test('detects invalid bar race frame and marker payloads', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'barRace',
        'categories': ['Alpha', 'Beta'],
        'frames': [
          [10],
          {
            'label': 'bad',
            'values': {'Alpha': 'nope'},
          },
        ],
        'markers': {
          'Alpha': {'size': 0, 'padding': -1},
          'Ghost': {'text': 'G'},
        },
        'images': {'Beta': ''},
        'showControls': 'yes',
        'frameDuration': 0,
        'maxBars': -1,
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'BAR_RACE_FRAME_CATEGORY_MISMATCH'),
        isTrue,
      );
      expect(
        result.errors.any((e) => e.code == 'BAR_RACE_NON_NUMERIC_VALUE'),
        isTrue,
      );
      expect(
        result.errors.any((e) => e.code == 'INVALID_BAR_RACE_MARKER_SIZE'),
        isTrue,
      );
      expect(
        result.errors.any((e) => e.code == 'INVALID_BAR_RACE_MARKER_METRIC'),
        isTrue,
      );
      expect(
        result.errors.any((e) => e.code == 'INVALID_BAR_RACE_MARKER_VALUE'),
        isTrue,
      );
      expect(
        result.errors.any((e) => e.code == 'INVALID_BAR_RACE_CONTROL_TYPE'),
        isTrue,
      );
      expect(
        result.errors.any((e) => e.code == 'INVALID_BAR_RACE_FRAME_DURATION'),
        isTrue,
      );
      expect(
        result.errors.any((e) => e.code == 'INVALID_BAR_RACE_MAX_BARS'),
        isTrue,
      );
      expect(
        result.warnings.any((e) => e.code == 'BAR_RACE_UNUSED_MARKER'),
        isTrue,
      );
    });

    test('rejects non-finite bar race values', () {
      final result = ChartConfigValidator.validateJsonPayload({
        'type': 'barRace',
        'categories': ['Alpha', 'Beta'],
        'frames': [
          [10, double.nan],
          {
            'values': {'Alpha': double.infinity, 'Beta': 20},
          },
        ],
      }, deep: false);

      expect(
        result.errors.where((e) => e.code == 'BAR_RACE_NON_NUMERIC_VALUE'),
        hasLength(2),
      );
    });

    test('warns when declared type conflicts with inferred data shape', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'series': [
          {
            'data': [
              {'name': 'A', 'value': 10},
              {'name': 'B', 'value': 20},
            ],
          },
        ],
      }, deep: false);

      final warning = result.warnings.singleWhere(
        (issue) => issue.code == 'DATA_SHAPE_TYPE_MISMATCH',
      );
      expect(warning.message, contains('pieLike'));
      expect(warning.suggestion, contains('pie'));
      expect(result.errors, isEmpty);
    });

    test('does not warn for valid pie label-value payload', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'pie',
        'series': [
          {
            'data': [
              {'name': 'A', 'value': 10},
              {'name': 'B', 'value': 20},
            ],
          },
        ],
      }, deep: false);

      expect(
        result.warnings.any((e) => e.code == 'DATA_SHAPE_TYPE_MISMATCH'),
        isFalse,
      );
      expect(result.errors, isEmpty);
    });

    test('does not warn for bubble x-y-value payload', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'bubble',
        'series': [
          {
            'data': [
              {'x': 1, 'y': 2, 'value': 10},
              {'x': 2, 'y': 4, 'value': 20},
            ],
          },
        ],
      }, deep: false);

      expect(
        result.warnings.any((e) => e.code == 'DATA_SHAPE_TYPE_MISMATCH'),
        isFalse,
      );
      expect(result.errors, isEmpty);
    });

    test('supports gauge payload without series', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'gauge',
        'value': 65,
        'min': 0,
        'max': 100,
      }, deep: false);

      expect(result.errors, isEmpty);
    });

    test('detects invalid dataMode value', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'dataMode': 'turbo',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'INVALID_DATA_MODE_VALUE'),
        isTrue,
      );
    });

    test('detects invalid sampling object shape', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'sampling': 'yes',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'INVALID_SAMPLING_TYPE'),
        isTrue,
      );
    });

    test('detects invalid sampling strategy', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'sampling': {'strategy': 'fastest'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'INVALID_SAMPLING_STRATEGY_VALUE'),
        isTrue,
      );
    });

    test('detects invalid sampling threshold value', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'sampling': {'threshold': 0},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'INVALID_SAMPLING_THRESHOLD_VALUE'),
        isTrue,
      );
    });

    test('regular mode with enabled sampling yields info', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'dataMode': 'regular',
        'sampling': {'enabled': true, 'threshold': 600, 'strategy': 'lttb'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      expect(
        result.infos.any((e) => e.code == 'REGULAR_MODE_SAMPLING_IGNORED'),
        isTrue,
      );
      expect(result.errors, isEmpty);
    });

    test('valid large mode + sampling payload passes', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'dataMode': 'large',
        'sampling': {'enabled': true, 'threshold': 600, 'strategy': 'minMax'},
        'series': [
          {
            'data': [1, 2, 3, 4],
          },
        ],
      }, deep: false);

      expect(result.errors, isEmpty);
    });

    test('warns when sampling is used on likely-unsupported type', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'pie',
        'sampling': {'enabled': true, 'threshold': 600, 'strategy': 'lttb'},
        'series': [
          {
            'data': [
              {'name': 'A', 'value': 10},
              {'name': 'B', 'value': 20},
            ],
          },
        ],
      }, deep: false);

      expect(
        result.warnings.any((e) => e.code == 'SAMPLING_LIKELY_IGNORED_BY_TYPE'),
        isTrue,
      );
    });

    test('does not warn for supported sampling type', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'sampling': {'enabled': true, 'threshold': 600, 'strategy': 'lttb'},
        'series': [
          {
            'data': [1, 2, 3, 4, 5],
          },
        ],
      }, deep: false);

      expect(
        result.warnings.any((e) => e.code == 'SAMPLING_LIKELY_IGNORED_BY_TYPE'),
        isFalse,
      );
      expect(result.errors, isEmpty);
    });

    test('accepts valid candlestick tuple payload', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'candlestick',
        'xAxis': {
          'data': ['D1', 'D2'],
        },
        'series': [
          {
            'data': [
              [100, 110, 95, 108],
              [108, 114, 104, 112],
            ],
          },
        ],
      }, deep: false);

      expect(result.errors, isEmpty);
    });

    test('accepts valid date-prefixed candlestick tuples', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'candlestick',
        'series': [
          {
            'data': [
              ['2025-01-01', 100, 110, 95, 108],
              ['2025-01-02', 108, 114, 104, 112],
            ],
          },
        ],
      }, deep: false);

      expect(result.errors, isEmpty);
    });

    test('accepts numeric-string and timestamp-prefixed OHLC tuples', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'candlestick',
        'series': [
          {
            'data': [
              ['100', '110', '95', '108'],
              [1704067200000, 108, 114, 104, 112],
            ],
          },
        ],
      }, deep: false);

      expect(result.errors, isEmpty);
    });

    test('rejects non-finite OHLC values', () {
      final result = ChartConfigValidator.validateJsonPayload({
        'type': 'ohlc',
        'series': [
          {
            'data': [
              {
                'date': '2025-01-01',
                'open': 100,
                'high': double.infinity,
                'low': 95,
                'close': 108,
              },
              [108, 114, double.nan, 112],
            ],
          },
        ],
      }, deep: false);

      expect(
        result.errors.where((e) => e.code == 'OHLC_NON_NUMERIC_VALUE'),
        hasLength(2),
      );
    });

    test('detects candlestick tuple with insufficient values', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'candlestick',
        'series': [
          {
            'data': [
              [100, 110, 95],
            ],
          },
        ],
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'OHLC_INSUFFICIENT_VALUES'),
        isTrue,
      );
    });

    test('detects candlestick map with missing keys', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'ohlc',
        'series': [
          {
            'data': [
              {'date': '2025-01-01', 'open': 100, 'high': 110, 'close': 108},
            ],
          },
        ],
      }, deep: false);

      expect(result.errors.any((e) => e.code == 'OHLC_MISSING_KEYS'), isTrue);
    });

    test('accepts nested JSON-like maps with non-dynamic value types', () {
      final firstBar = <String, Object?>{
        'date': '2025-01-01',
        'open': 100,
        'high': 110,
        'low': 95,
        'close': 108,
      };
      final secondBar = <String, Object?>{
        'date': '2025-01-02',
        'open': 108,
        'high': 114,
        'low': 104,
        'close': 112,
      };
      final series = <String, Object?>{
        'name': 'OHLC',
        'data': [firstBar, secondBar],
      };

      final result = ChartConfigValidator.validateJsonPayload({
        'type': 'ohlc',
        'series': [series],
      }, deep: false);

      expect(result.errors, isEmpty);
    });

    test('deep validation does not fail on valid candlestick payload', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'candlestick',
        'xAxis': {
          'data': ['D1', 'D2', 'D3'],
        },
        'series': [
          {
            'data': [
              [100, 110, 95, 108],
              [108, 114, 104, 112],
              [112, 118, 109, 115],
            ],
          },
        ],
      }, deep: true);

      expect(result.errors, isEmpty);
    });

    test('deep validation does not raise empty-series error for treemap', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'treemap',
        'series': [
          {
            'data': [
              {'name': 'A', 'value': 10},
              {'name': 'B', 'value': 15},
            ],
          },
        ],
      }, deep: true);

      expect(result.errors.any((e) => e.code == 'EMPTY_SERIES'), isFalse);
    });

    test('validates shorthand collection payloads without explicit series', () {
      final treemap = ChartConfigValidator.validateJsonPayload(const {
        'type': 'treemap',
        'nodes': [
          {'name': 'A', 'value': 10},
          {'name': 'B', 'value': 15},
        ],
      }, deep: true);
      final sankey = ChartConfigValidator.validateJsonPayload(const {
        'type': 'sankey',
        'nodes': [
          {'id': 'source', 'name': 'Source'},
          {'id': 'target', 'name': 'Target'},
        ],
        'links': [
          {'source': 'source', 'target': 'target', 'value': 8},
        ],
      }, deep: true);
      final calendar = ChartConfigValidator.validateJsonPayload(const {
        'type': 'calendar',
        'year': 2026,
        'dateValues': {'2026-01-01': 10, '2026-01-02': 12},
      }, deep: true);

      expect(treemap.errors, isEmpty);
      expect(sankey.errors, isEmpty);
      expect(calendar.errors, isEmpty);
      expect(treemap.issues.any((e) => e.code == 'MISSING_SERIES'), isFalse);
      expect(sankey.issues.any((e) => e.code == 'MISSING_SERIES'), isFalse);
      expect(calendar.issues.any((e) => e.code == 'MISSING_SERIES'), isFalse);
    });

    test('normalizes shorthand payloads from registry payload contracts', () {
      final sankeyContract = chartPayloadContractForType(ChartType.sankey);
      final nestedPieContract = chartPayloadContractForType(
        ChartType.nestedPie,
      );
      final sankey = ChartConfigValidator.normalizeDataCollectionPayload(const {
        'type': 'sankey',
        'nodes': [
          {'id': 'a'},
        ],
        'links': [
          {'source': 'a', 'target': 'b', 'value': 2},
        ],
      });
      final nestedPie = ChartConfigValidator.normalizeDataCollectionPayload(
        const {
          'type': 'nestedPie',
          'rings': [
            {
              'name': 'outer',
              'slices': [
                {'name': 'A', 'value': 10},
              ],
            },
          ],
        },
      );

      expect(
        sankeyContract.seriesStrategy,
        ChartPayloadSeriesStrategy.nodeLink,
      );
      expect(
        nestedPieContract.seriesStrategy,
        ChartPayloadSeriesStrategy.ringSlices,
      );
      expect((sankey['series'] as List).first['nodes'], isNotEmpty);
      expect((sankey['series'] as List).first['links'], isNotEmpty);
      expect((nestedPie['series'] as List).first['name'], 'outer');
      expect((nestedPie['series'] as List).first['data'], isNotEmpty);
    });

    test('detects invalid renko brickSize', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'renko',
        'brickSize': 0,
        'series': [
          {
            'data': [100, 101, 103],
          },
        ],
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'INVALID_RENKO_BRICK_SIZE_VALUE'),
        isTrue,
      );
    });

    test('detects invalid kagi reversalPct', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'kagi',
        'reversalPct': -1,
        'series': [
          {
            'data': [100, 98, 105],
          },
        ],
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'INVALID_KAGI_REVERSAL_VALUE'),
        isTrue,
      );
    });

    test('detects non-numeric trading price rows', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'macd',
        'series': [
          {
            'data': [100, 101, 'bad', 104],
          },
        ],
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'TRADING_NON_NUMERIC_PRICE'),
        isTrue,
      );
    });

    test('detects non-finite trading price rows', () {
      final result = ChartConfigValidator.validateJsonPayload({
        'type': 'macd',
        'series': [
          {
            'data': [100, double.nan, 104],
          },
        ],
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'TRADING_NON_NUMERIC_PRICE'),
        isTrue,
      );
    });

    test('accepts numeric-string trading price rows', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'renko',
        'series': [
          {
            'data': ['100', '101.5', 103],
          },
        ],
      }, deep: false);

      expect(
        result.errors.any((e) => e.code == 'TRADING_NON_NUMERIC_PRICE'),
        isFalse,
      );
    });

    test('detects non-finite trading parameters', () {
      final kagi = ChartConfigValidator.validateJsonPayload({
        'type': 'kagi',
        'reversalPct': double.nan,
        'series': [
          {
            'data': [100, 98, 105],
          },
        ],
      }, deep: false);
      final renko = ChartConfigValidator.validateJsonPayload({
        'type': 'renko',
        'brickSize': double.infinity,
        'series': [
          {
            'data': [100, 101, 103],
          },
        ],
      }, deep: false);
      final macd = ChartConfigValidator.validateJsonPayload({
        'type': 'macd',
        'fast': double.nan,
        'slow': double.infinity,
        'signal': double.nan,
        'series': [
          {'data': List.generate(40, (i) => 100 + i)},
        ],
      }, deep: false);

      expect(
        kagi.errors.any((e) => e.code == 'INVALID_KAGI_REVERSAL_VALUE'),
        isTrue,
      );
      expect(
        renko.errors.any((e) => e.code == 'INVALID_RENKO_BRICK_SIZE_VALUE'),
        isTrue,
      );
      expect(
        macd.errors.any((e) => e.code == 'INVALID_MACD_FAST_VALUE'),
        isTrue,
      );
      expect(
        macd.errors.any((e) => e.code == 'INVALID_MACD_SLOW_VALUE'),
        isTrue,
      );
      expect(
        macd.errors.any((e) => e.code == 'INVALID_MACD_SIGNAL_VALUE'),
        isTrue,
      );
    });

    test('warns when MACD fast period is not less than slow period', () {
      final result = ChartConfigValidator.validateJsonPayload({
        'type': 'macd',
        'fast': 26,
        'slow': 12,
        'series': [
          {'data': List.generate(40, (i) => 100 + i)},
        ],
      }, deep: false);

      expect(
        result.warnings.any((e) => e.code == 'MACD_FAST_SLOW_ORDER'),
        isTrue,
      );
    });

    test('warns when MACD data is shorter than recommended minimum', () {
      final result = ChartConfigValidator.validateJsonPayload({
        'type': 'macd',
        'fast': 12,
        'slow': 26,
        'signal': 9,
        'series': [
          {'data': List.generate(20, (i) => 100 + i)},
        ],
      }, deep: false);

      expect(
        result.warnings.any((e) => e.code == 'MACD_NOT_ENOUGH_DATA'),
        isTrue,
      );
    });
  });

  group('Sampling payload normalizer', () {
    test('normalizes mode aliases and invalid sampling fields', () {
      final out = ChartConfigValidator.normalizeSamplingPayload({
        'type': 'line',
        'datasetMode': 'performance',
        'sampling': {'enabled': 'yes', 'threshold': 0, 'strategy': 'min_max'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, defaultThreshold: 777);

      expect(out['datasetMode'], isNull);
      expect(out['dataMode'], 'large');
      expect(out['sampling']['enabled'], isTrue);
      expect(out['sampling']['threshold'], 777);
      expect(out['sampling']['strategy'], 'minMax');
    });

    test('normalizes low positive sampling threshold to render minimum', () {
      final out = ChartConfigValidator.normalizeSamplingPayload({
        'type': 'line',
        'dataMode': 'large',
        'sampling': {'threshold': 1, 'strategy': 'nth'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });

      expect(
        out['sampling']['threshold'],
        LargeDataSamplingConfig.minimumThreshold,
      );
      expect(out['sampling']['strategy'], 'nth');
    });

    test('normalizes unsafe global fallback threshold', () {
      final previous = LargeDataSamplingConfig.threshold;
      try {
        LargeDataSamplingConfig.threshold = -20;
        final out = ChartConfigValidator.normalizeSamplingPayload({
          'type': 'line',
          'dataMode': 'large',
          'sampling': {},
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        });

        expect(
          out['sampling']['threshold'],
          LargeDataSamplingConfig.minimumThreshold,
        );
      } finally {
        LargeDataSamplingConfig.threshold = previous;
      }
    });

    test('forces disabled sampling in regular mode', () {
      final out = ChartConfigValidator.normalizeSamplingPayload({
        'type': 'line',
        'dataMode': 'regular',
        'sampling': {'enabled': true, 'threshold': 500, 'strategy': 'lttb'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });

      expect(out['dataMode'], 'regular');
      expect(out['sampling']['enabled'], isFalse);
      expect(out['sampling']['threshold'], 500);
      expect(out['sampling']['strategy'], 'lttb');
    });

    test('drops unsupported sampling by default', () {
      final out = ChartConfigValidator.normalizeSamplingPayload({
        'type': 'pie',
        'dataMode': 'large',
        'sampling': {'enabled': true, 'threshold': 600, 'strategy': 'lttb'},
        'series': [
          {
            'data': [
              {'name': 'A', 'value': 10},
              {'name': 'B', 'value': 20},
            ],
          },
        ],
      });

      expect(out['dataMode'], 'regular');
      expect(out['sampling']['enabled'], isFalse);
    });

    test('can keep unsupported sampling when explicitly requested', () {
      final out = ChartConfigValidator.normalizeSamplingPayload({
        'type': 'pie',
        'dataMode': 'large',
        'sampling': {'enabled': true, 'threshold': 600, 'strategy': 'lttb'},
        'series': [
          {
            'data': [
              {'name': 'A', 'value': 10},
              {'name': 'B', 'value': 20},
            ],
          },
        ],
      }, dropUnsupportedSampling: false);

      expect(out['dataMode'], 'large');
      expect(out['sampling']['enabled'], isTrue);
      expect(out['sampling']['strategy'], 'lttb');
    });

    test('uses provided default mode and threshold for missing values', () {
      final out = ChartConfigValidator.normalizeSamplingPayload(
        {
          'type': 'line',
          'sampling': {},
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        },
        defaultMode: ChartDataMode.large,
        defaultThreshold: 888,
      );

      expect(out['dataMode'], 'large');
      expect(out['sampling']['enabled'], isTrue);
      expect(out['sampling']['threshold'], 888);
      expect(out['sampling']['strategy'], 'auto');
    });

    test('normalizePayload sanitizes renko mixed price rows and params', () {
      final out = ChartConfigValidator.normalizePayload({
        'type': 'renko',
        'dataMode': 'large',
        'sampling': {'enabled': true, 'threshold': 600, 'strategy': 'nth'},
        'brickSize': 0,
        'series': [
          {
            'data': [
              100,
              '101',
              'oops',
              {'close': 102},
              {'value': '103.5'},
              [1, 2, 3, 104],
              null,
            ],
          },
        ],
      });

      expect(out['dataMode'], 'large');
      expect(out['sampling']['strategy'], 'nth');
      expect(out['brickSize'], 1.0);
      expect((out['series'] as List).first['data'], [
        100.0,
        101.0,
        102.0,
        103.5,
        104.0,
      ]);
    });

    test('normalizePayload drops non-finite trading price rows', () {
      final out = ChartConfigValidator.normalizePayload({
        'type': 'renko',
        'series': [
          {
            'data': [
              100,
              double.nan,
              {'close': double.infinity},
              [1, 2, 3, 104],
            ],
          },
        ],
      });

      expect((out['series'] as List).first['data'], [100.0, 104.0]);
    });

    test('normalizePayload sanitizes macd periods and prices', () {
      final out = ChartConfigValidator.normalizePayload({
        'type': 'macd',
        'fast': 26,
        'slow': 12,
        'signal': '0',
        'series': [
          {
            'data': ['100', 'bad', 102],
          },
        ],
      });

      expect(out['fast'], 26);
      expect(out['slow'], 27);
      expect(out['signal'], 9);
      expect((out['series'] as List).first['data'], [100.0, 102.0]);
    });

    test('normalizePayload can skip trading sanitization', () {
      final out = ChartConfigValidator.normalizePayload({
        'type': 'renko',
        'brickSize': 0,
        'series': [
          {
            'data': [100, 'bad', 102],
          },
        ],
      }, sanitizeTradingPayload: false);

      expect(out['brickSize'], 0);
      expect((out['series'] as List).first['data'], [100, 'bad', 102]);
    });

    test('normalizes with reusable options object', () {
      const options = PayloadNormalizationOptions(
        defaultMode: ChartDataMode.large,
        defaultThreshold: 333,
        sanitizeTradingPayload: false,
        maxInlineLength: 12,
      );

      final report = ChartConfigValidator.normalizePayloadWithReport({
        'type': 'renko',
        'brickSize': 0,
        'sampling': {'threshold': 0},
        'series': [
          {
            'data': [100, 'bad', 102],
          },
        ],
      }, options: options);

      expect(report.normalizedPayload['dataMode'], 'large');
      expect(report.normalizedPayload['sampling']['threshold'], 333);
      expect(report.normalizedPayload['brickSize'], 0);
      expect((report.normalizedPayload['series'] as List).first['data'], [
        100,
        'bad',
        102,
      ]);
      expect(report.diffs.first.rawText.length, lessThanOrEqualTo(12));
    });

    test('normalizePayload derives series from shorthand collections', () {
      final treemap = ChartConfigValidator.normalizePayload({
        'type': 'treemap',
        'nodes': [
          {'name': 'A', 'value': 10},
          {'name': 'B', 'value': 15},
        ],
      });
      final sankey = ChartConfigValidator.normalizePayload({
        'type': 'sankey',
        'nodes': [
          {'id': 'source'},
          {'id': 'target'},
        ],
        'links': [
          {'source': 'source', 'target': 'target', 'value': 8},
        ],
      });
      final calendar = ChartConfigValidator.normalizePayload({
        'type': 'calendar',
        'dateValues': {'2026-01-01': 10, '2026-01-02': 12},
      });
      final nestedPie = ChartConfigValidator.normalizePayload({
        'type': 'nestedPie',
        'rings': [
          {
            'name': 'Outer',
            'slices': [
              {'name': 'A', 'value': 10},
            ],
          },
          {
            'name': 'Inner',
            'slices': [
              {'name': 'B', 'value': 5},
            ],
          },
        ],
      });
      final partitionPie = ChartConfigValidator.normalizePayload({
        'type': 'partitionPie',
        'mainSlices': [
          {'name': 'A', 'value': 10},
        ],
        'subSlices': [
          {'name': 'A1', 'value': 4},
        ],
      });
      final kagi = ChartConfigValidator.normalizePayload({
        'type': 'kagi',
        'prices': [
          100,
          '101',
          {'close': 102},
        ],
      });

      expect((treemap['series'] as List).first['data'], treemap['nodes']);
      expect((sankey['series'] as List).first['nodes'], sankey['nodes']);
      expect((sankey['series'] as List).first['links'], sankey['links']);
      expect(((calendar['series'] as List).first['data'] as List).first, {
        'date': '2026-01-01',
        'value': 10,
      });
      expect(nestedPie['series'], hasLength(2));
      expect(partitionPie['series'], hasLength(2));
      expect((kagi['series'] as List).first['data'], [100.0, 101.0, 102.0]);
    });

    test('serializes and copies normalization options', () {
      const options = PayloadNormalizationOptions(
        dropUnsupportedSampling: false,
        defaultThreshold: 500,
        defaultMode: ChartDataMode.large,
        sanitizeTradingPayload: false,
        maxInlineLength: 24,
      );
      final copied = options.copyWith(
        dropUnsupportedSampling: true,
        clearDefaultThreshold: true,
        sanitizeTradingPayload: true,
      );

      expect(options.toJson(), {
        'dropUnsupportedSampling': false,
        'defaultThreshold': 500,
        'defaultMode': 'large',
        'sanitizeTradingPayload': false,
        'maxInlineLength': 24,
      });
      expect(copied.dropUnsupportedSampling, isTrue);
      expect(copied.defaultThreshold, isNull);
      expect(copied.defaultMode, ChartDataMode.large);
      expect(copied.sanitizeTradingPayload, isTrue);
      expect(copied.maxInlineLength, 24);
    });
  });

  group('Payload diff', () {
    test('reports added removed and changed paths', () {
      final diffs = ChartConfigValidator.diffPayloads(
        {
          'sameNull': null,
          'toNull': 1,
          'removedNull': null,
          'removedValue': 'old',
          'nested': {'changed': 1},
          'list': [1, null, 3],
        },
        {
          'sameNull': null,
          'toNull': null,
          'addedNull': null,
          'addedValue': 'new',
          'nested': {'changed': 2},
          'list': [1, 2, null, 4],
        },
      );

      PayloadDiff byPath(String path) =>
          diffs.firstWhere((diff) => diff.path == path);

      expect(diffs.any((diff) => diff.path == r'$.sameNull'), isFalse);
      expect(byPath(r'$.toNull').kind, PayloadDiffKind.changed);
      expect(byPath(r'$.toNull').rawText, '1');
      expect(byPath(r'$.toNull').normalizedText, 'null');

      expect(byPath(r'$.removedNull').kind, PayloadDiffKind.removed);
      expect(byPath(r'$.removedNull').rawText, 'null');
      expect(byPath(r'$.removedNull').normalizedText, '<missing>');

      expect(byPath(r'$.addedNull').kind, PayloadDiffKind.added);
      expect(byPath(r'$.addedNull').rawText, '<missing>');
      expect(byPath(r'$.addedNull').normalizedText, 'null');

      expect(byPath(r'$.removedValue').kind, PayloadDiffKind.removed);
      expect(byPath(r'$.addedValue').kind, PayloadDiffKind.added);
      expect(byPath(r'$.nested.changed').kind, PayloadDiffKind.changed);
      expect(byPath(r'$.list[1]').kind, PayloadDiffKind.changed);
      expect(byPath(r'$.list[2]').kind, PayloadDiffKind.changed);
      expect(byPath(r'$.list[3]').kind, PayloadDiffKind.added);
    });

    test('truncates inline payload values', () {
      const diff = PayloadDiff(
        path: r'$.long',
        rawValue: {'value': 'abcdefghijklmnopqrstuvwxyz'},
        normalizedValue: 1,
        maxInlineLength: 14,
      );

      expect(diff.rawText.length, lessThanOrEqualTo(14));
      expect(diff.rawText.endsWith('...'), isTrue);
      expect(diff.normalizedText, '1');
    });

    test('serializes diff details with optional values', () {
      const diff = PayloadDiff(
        path: r'$.x',
        rawValue: null,
        normalizedValue: 12,
      );

      expect(diff.toJson(), {
        'path': r'$.x',
        'kind': 'changed',
        'hasRawValue': true,
        'hasNormalizedValue': true,
        'rawText': 'null',
        'normalizedText': '12',
      });
      expect(diff.toJson(includeValues: true), {
        'path': r'$.x',
        'kind': 'changed',
        'hasRawValue': true,
        'hasNormalizedValue': true,
        'rawText': 'null',
        'normalizedText': '12',
        'rawValue': null,
        'normalizedValue': 12,
      });
      expect(jsonDecode(jsonEncode(diff.toJson())), isA<Map>());
    });

    test('summarizes diff counts and paths', () {
      final diffs = ChartConfigValidator.diffPayloads(
        {'removed': 1, 'changed': 2},
        {'added': 3, 'changed': 4},
      );
      final summary = PayloadDiffSummary.fromDiffs(diffs);

      expect(summary.added, 1);
      expect(summary.removed, 1);
      expect(summary.changed, 1);
      expect(summary.total, 3);
      expect(summary.isNotEmpty, isTrue);
      expect(
        summary.compactLabel,
        '3 payload changes (1 added, 1 removed, 1 changed)',
      );
      expect(summary.toJson(), {
        'total': 3,
        'added': 1,
        'removed': 1,
        'changed': 1,
        'compactLabel': '3 payload changes (1 added, 1 removed, 1 changed)',
      });
    });
  });

  group('Payload normalization report', () {
    test('exposes summary helpers for normalized payloads', () {
      final report = ChartConfigValidator.normalizePayloadWithReport({
        'type': 'line',
        'dataMode': 'turbo',
        'sampling': {'enabled': 'yes', 'threshold': 0, 'strategy': 'fastest'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, defaultThreshold: 900);

      expect(report.wasNormalized, isTrue);
      expect(report.changed, isTrue);
      expect(report.effectivePayload, same(report.normalizedPayload));
      expect(report.summary.total, report.diffs.length);
      expect(report.summary.changed, greaterThan(0));
      expect(report.addedDiffs, isEmpty);
      expect(report.removedDiffs, isEmpty);
      expect(report.changedDiffs.length, report.diffs.length);
      expect(report.changedPaths, contains(r'$.dataMode'));
      expect(report.changedPaths, contains(r'$.sampling.threshold'));
      expect(report.summary.compactLabel, contains('payload changes'));

      final json = report.toJson();
      expect(json['wasNormalized'], isTrue);
      expect(json['changed'], isTrue);
      expect(json['summary'], isA<Map<String, dynamic>>());
      expect(json['changedPaths'], contains(r'$.dataMode'));
      expect(json['diffs'], isA<List>());
      expect(json.containsKey('rawPayload'), isFalse);
      expect(json.containsKey('normalizedPayload'), isFalse);
      expect(jsonDecode(jsonEncode(json)), isA<Map>());

      final jsonWithPayloads = report.toJson(
        includePayloads: true,
        includeDiffValues: true,
      );
      expect(jsonWithPayloads['rawPayload'], isA<Map<String, dynamic>>());
      expect(
        jsonWithPayloads['normalizedPayload'],
        isA<Map<String, dynamic>>(),
      );
      expect(
        (jsonWithPayloads['diffs'] as List).first,
        contains('normalizedValue'),
      );

      final rawPayloadJson = jsonWithPayloads['rawPayload'] as Map;
      final normalizedPayloadJson =
          jsonWithPayloads['normalizedPayload'] as Map;
      ((rawPayloadJson['series'] as List).single as Map)['data'] = [999];
      ((normalizedPayloadJson['series'] as List).single as Map)['data'] = [888];
      expect(((report.rawPayload['series'] as List).single as Map)['data'], [
        1,
        2,
        3,
      ]);
      expect(
        ((report.normalizedPayload['series'] as List).single as Map)['data'],
        [1, 2, 3],
      );

      final diff = PayloadDiff(
        path: r'$.series[0]',
        rawValue: {
          'data': [1, 2],
        },
        normalizedValue: {
          'data': [1, 2, 3],
        },
      );
      final diffJson = diff.toJson(includeValues: true);
      ((diffJson['rawValue'] as Map)['data'] as List).add(999);
      ((diffJson['normalizedValue'] as Map)['data'] as List).add(888);
      expect(diff.rawValue, {
        'data': [1, 2],
      });
      expect(diff.normalizedValue, {
        'data': [1, 2, 3],
      });
    });

    test('pass-through report uses separate payload copies', () {
      final payload = {
        'type': 'line',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };
      final report = PayloadNormalizationResult.passThrough(payload);

      expect(report.wasNormalized, isFalse);
      expect(report.changed, isFalse);
      expect(report.summary.isEmpty, isTrue);
      expect(report.summary.compactLabel, 'no payload changes');
      expect(identical(report.rawPayload, report.normalizedPayload), isFalse);

      (report.rawPayload['series'] as List).clear();
      expect((report.normalizedPayload['series'] as List), isNotEmpty);
      expect((payload['series'] as List), isNotEmpty);
    });
  });

  group('Validation JSON diagnostics', () {
    test('serializes validation issues and results', () {
      const issue = ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'TEST_CODE',
        message: 'Broken field.',
        field: 'series',
        suggestion: 'Fix series.',
      );
      final result = ValidationResult(
        issues: const [issue],
        type: ChartType.line,
      );

      expect(issue.toJson(), {
        'severity': 'error',
        'code': 'TEST_CODE',
        'message': 'Broken field.',
        'field': 'series',
        'suggestion': 'Fix series.',
      });

      final json = result.toJson();
      expect(json['type'], 'line');
      expect(json['isValid'], isFalse);
      expect(json['hasWarnings'], isFalse);
      expect(json['issueCount'], 1);
      expect(json['errorCount'], 1);
      expect(json['warningCount'], 0);
      expect(json['infoCount'], 0);
      expect(json['issues'], [issue.toJson()]);
      expect(jsonDecode(jsonEncode(json)), isA<Map>());
    });

    test('payload doctor explains contract-specific missing fields', () {
      final report = ChartPayloadDoctor.inspect(const {
        'type': 'sankey',
        'nodes': [
          {'id': 'a'},
          {'id': 'b'},
        ],
      });

      expect(report.status, ChartPayloadDoctorStatus.invalid);
      expect(report.expectedShape, ChartSeriesDataShape.flow);
      expect(
        report.payloadContract.seriesStrategy,
        ChartPayloadSeriesStrategy.nodeLink,
      );
      expect(
        report.findings.map((finding) => finding.code),
        contains('MISSING_NODE_LINK_FIELDS'),
      );
      expect(report.quickFixes.join(' '), contains('nodes'));
      expect(report.toJson()['payloadContract'], isA<Map<String, dynamic>>());
    });

    test(
      'payload doctor marks normalizable trading payloads as repairable',
      () {
        final report = ChartPayloadDoctor.inspect({
          'type': 'renko',
          'brickSize': -2,
          'series': [
            {
              'name': 'Price',
              'data': [100, '101', 'bad', 102],
            },
          ],
        });

        expect(report.normalization.changed, isTrue);
        expect(report.normalizedValidation.isValid, isTrue);
        expect(report.status, ChartPayloadDoctorStatus.repairable);
        expect(
          report.findings.map((finding) => finding.code),
          contains('NORMALIZATION_REPAIRS_ERRORS'),
        );
        expect(
          report.quickFixes,
          contains('Enable autoNormalizePayload or apply the normalized JSON.'),
        );
      },
    );

    test('payload doctor reports shorthand normalization without errors', () {
      final report = ChartPayloadDoctor.inspect(const {
        'type': 'treemap',
        'nodes': [
          {'name': 'Revenue', 'value': 42},
        ],
      });

      expect(report.status, ChartPayloadDoctorStatus.healthy);
      expect(report.rawValidation.isValid, isTrue);
      expect(report.normalization.changed, isTrue);
      expect(report.payloadContract.dataFieldPriority, contains('nodes'));
      expect(
        report.findings.map((finding) => finding.code),
        contains('NORMALIZATION_AVAILABLE'),
      );
    });
  });
}
