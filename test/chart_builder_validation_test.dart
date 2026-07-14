import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
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

class _FakeLineConfig extends BaseChartConfig {
  _FakeLineConfig({required super.series}) : super(type: ChartType.line);

  factory _FakeLineConfig.fromJson(Map<String, dynamic> json) {
    final series = (json['series'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Series.fromJson)
        .toList();
    return _FakeLineConfig(series: series);
  }

  @override
  Widget buildChart() => const SizedBox.shrink();
}

const _lineRegistration = ChartRegistration(
  type: ChartType.line,
  typeString: 'line',
  fromJson: _FakeLineConfig.fromJson,
);

void main() {
  group('ChartFactory validation integration', () {
    setUp(() {
      ChartRegistry.clear();
      ChartRegistry.register(_lineRegistration);
    });

    test('throws in strict validation mode for invalid payload', () {
      expect(
        () => ChartFactory.fromJson(
          const {
            'series': [
              {
                'data': [1, 2, 3],
              },
            ],
          },
          validatePayload: true,
          strictValidation: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('strict validation exception uses report text', () {
      expect(
        () => ChartFactory.fromJson(
          const {
            'series': [
              {
                'data': [1, 2, 3],
              },
            ],
          },
          validatePayload: true,
          strictValidation: true,
        ),
        throwsA(
          isA<FormatException>()
              .having(
                (error) => error.message,
                'message',
                contains('Invalid line chart payload'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('Suggestion: Provide chart type'),
              ),
        ),
      );
    });

    test('strict validation exception respects report issue limit', () {
      expect(
        () => ChartFactory.fromJson(
          const {
            'sampling': {
              'enabled': 'yes',
              'threshold': 0,
              'strategy': 'fastest',
            },
            'series': {
              'data': [1, 2, 3],
            },
          },
          validatePayload: true,
          strictValidation: true,
          validationReportMaxIssues: 1,
        ),
        throwsA(
          isA<FormatException>()
              .having(
                (error) => error.message,
                'message',
                contains('Invalid line chart payload'),
              )
              .having(
                (error) => error.message,
                'message',
                contains('more issues hidden'),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('sampling.threshold')),
              ),
        ),
      );
    });

    test('fromJsonToChart supports strict validation and callbacks', () {
      final results = <ValidationResult>[];

      expect(
        () => ChartFactory.fromJsonToChart(
          const {
            'sampling': {
              'enabled': 'yes',
              'threshold': 0,
              'strategy': 'fastest',
            },
            'series': {
              'data': [1, 2, 3],
            },
          },
          validatePayload: true,
          strictValidation: true,
          validationReportMaxIssues: 1,
          onValidationResult: results.add,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('more issues hidden'),
          ),
        ),
      );
      expect(results, hasLength(1));
      expect(results.single.isValid, isFalse);
    });

    test('parses valid payload in strict validation mode', () {
      final config = ChartFactory.fromJson(
        const {
          'type': 'line',
          'xAxis': {
            'data': ['A', 'B', 'C'],
          },
          'series': [
            {
              'name': 'S1',
              'data': [10, 20, 30],
            },
          ],
        },
        validatePayload: true,
        strictValidation: true,
      );

      expect(config.series.length, 1);
    });

    test('dispatches factory validation callback once', () {
      final results = <ValidationResult>[];

      final config = ChartFactory.fromJson(
        const {
          'type': 'line',
          'xAxis': {
            'data': ['A', 'B', 'C'],
          },
          'series': [
            {
              'name': 'S1',
              'data': [10, 20, 30],
            },
          ],
        },
        validatePayload: true,
        onValidationResult: results.add,
      );

      expect(config.series.length, 1);
      expect(results, hasLength(1));
      expect(results.single.isValid, isTrue);
    });

    test('throws on invalid sampling payload in strict mode by default', () {
      expect(
        () => ChartFactory.fromJson(
          const {
            'type': 'line',
            'dataMode': 'turbo',
            'sampling': {
              'enabled': 'yes',
              'threshold': 0,
              'strategy': 'fastest',
            },
            'series': [
              {
                'data': [1, 2, 3],
              },
            ],
          },
          validatePayload: true,
          strictValidation: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts valid runtime performance policy payload', () {
      const payload = {
        'type': 'line',
        'diagnostics': {
          'performancePolicy': {
            'largeDatasetPointThreshold': '3',
            'cachePressureWarningThreshold': '85%',
            'lowRenderCacheHitRateThreshold': 20,
            'lowRenderCacheMinRequests': '4',
          },
        },
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };

      final result = ChartConfigValidator.validateJsonPayload(
        payload,
        deep: false,
      );
      expect(result.isValid, isTrue);
      expect(
        result.issues.where(
          (issue) => issue.code.startsWith('INVALID_RUNTIME_POLICY'),
        ),
        isEmpty,
      );

      final config = ChartFactory.fromJson(
        payload,
        validatePayload: true,
        strictValidation: true,
      );
      expect(config.series.length, 1);
    });

    test('keeps runtime performance policy aliases aligned', () {
      const payload = {
        'type': 'line',
        'performancePolicy': {
          'largeDataPointThreshold': '3',
          'cachePressureThreshold': 85,
          'minRenderCacheHitRate': '20%',
          'renderCacheMinRequests': '4',
        },
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };

      final validation = ChartConfigValidator.validateJsonPayload(
        payload,
        deep: false,
      );
      expect(validation.isValid, isTrue);
      expect(
        validation.issues.where(
          (issue) => issue.code.startsWith('INVALID_RUNTIME_POLICY'),
        ),
        isEmpty,
      );

      final resolution = ChartRuntimePerformancePolicy.resolve(payload);
      expect(resolution.sourcePath, 'performancePolicy');
      expect(resolution.policy.normalizedLargeDatasetPointThreshold, 3);
      expect(resolution.policy.normalizedCachePressureWarningThreshold, 0.85);
      expect(resolution.policy.normalizedLowRenderCacheHitRateThreshold, 0.2);
      expect(resolution.policy.normalizedLowRenderCacheMinRequests, 4);
    });

    test('exposes runtime performance policy field schema for tooling', () {
      expect(
        ChartRuntimePerformancePolicyFields.canonicalFields,
        containsAll([
          'largeDatasetPointThreshold',
          'cachePressureWarningThreshold',
          'lowRenderCacheHitRateThreshold',
          'lowRenderCacheMinRequests',
        ]),
      );
      expect(
        ChartRuntimePerformancePolicyFields.canonicalFieldFor(
          'largeDataPointThreshold',
        ),
        'largeDatasetPointThreshold',
      );
      expect(
        ChartRuntimePerformancePolicyFields.kindFor('cachePressureThreshold'),
        ChartRuntimePerformancePolicyFieldKind.unitRatio,
      );
      expect(
        ChartRuntimePerformancePolicyFields.aliasesFor(
          'lowRenderCacheMinRequests',
        ),
        contains('renderCacheMinRequests'),
      );
      expect(
        ChartRuntimePerformancePolicyFields.schemaJson(),
        hasLength(ChartRuntimePerformancePolicyFields.fieldSpecs.length),
      );
      expect(
        ChartRuntimePerformancePolicyFields.schemaJson().first,
        containsPair('kind', 'positiveInteger'),
      );
      expect(
        ChartRuntimePerformancePolicyFields.suggestion,
        contains('cachePressureWarningThreshold'),
      );
      expect(ChartRuntimePerformancePolicyFields.parseRatio(20), 0.2);
      expect(ChartRuntimePerformancePolicyFields.parseRatio('20%'), 0.2);
      expect(ChartRuntimePerformancePolicyFields.parseRatio('120%'), 1.2);
    });

    test('reports invalid runtime performance policy payload', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'diagnostics': {
          'performancePolicy': {
            'largeDatasetPointThreshold': 0,
            'cachePressureWarningThreshold': 'high',
            'lowRenderCacheHitRateThreshold': '120%',
            'lowRenderCacheMinRequests': false,
          },
        },
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      expect(result.isValid, isFalse);
      final codes = result.errors.map((issue) => issue.code);
      expect(codes, contains('INVALID_RUNTIME_POLICY_INTEGER'));
      expect(codes, contains('INVALID_RUNTIME_POLICY_RATIO'));
      expect(
        result.errors.map((issue) => issue.field),
        contains('diagnostics.performancePolicy.largeDatasetPointThreshold'),
      );
      expect(
        result.errors.map((issue) => issue.field),
        contains('diagnostics.performancePolicy.cachePressureWarningThreshold'),
      );
    });

    test('formats validation reports for UI and tooling', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'diagnostics': {
          'performancePolicy': {
            'largeDatasetPointThreshold': 0,
            'cachePressureWarningThreshold': 'high',
            'lowRenderCacheHitRateThreshold': '120%',
            'lowRenderCacheMinRequests': false,
          },
        },
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      final report = result.toReport(maxIssues: 2);
      expect(report.status, 'invalid');
      expect(report.title, 'Invalid line chart payload');
      expect(report.compactMessage, contains('4 errors'));
      expect(report.counts, containsPair('visible', 2));
      expect(report.counts, containsPair('hidden', 2));
      expect(report.hasMoreIssues, isTrue);
      expect(report.visibleReportIssues, hasLength(2));
      expect(
        report.visibleReportIssues.first.fieldPath,
        contains('diagnostics'),
      );
      expect(report.toJson()['issues'], hasLength(2));
      expect(
        report.toJson()['suggestions'],
        contains('Fix this payload field before rendering in strict mode.'),
      );
      expect(report.toPlainText(), contains('Suggestion:'));
      expect(report.toPlainText(), contains('2 more issues hidden'));
    });

    test('warns on unknown runtime performance policy fields', () {
      final payload = const {
        'type': 'line',
        'performancePolicy': {
          'largeDatasetPointThreshold': 10,
          'largeDatasetPointsThreshold': 10,
        },
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };
      final result = ChartConfigValidator.validateJsonPayload(
        payload,
        deep: false,
      );

      expect(result.isValid, isTrue);
      final warning = result.warnings.singleWhere(
        (issue) => issue.code == 'UNKNOWN_RUNTIME_POLICY_FIELD',
      );
      expect(warning.field, 'performancePolicy.largeDatasetPointsThreshold');
      expect(warning.suggestion, contains('largeDatasetPointThreshold'));

      final config = ChartFactory.fromJson(
        payload,
        validatePayload: true,
        strictValidation: true,
      );
      expect(config.series.length, 1);
    });

    test('accepts diagnostic fallback option payload fields', () {
      final payload = const {
        'type': 'line',
        'diagnosticFallbackOptions': {
          'preset': 'compact',
          'title': 'Review chart',
          'message': 'Fix this payload before sharing.',
          'detailMessage': 'Strict validation blocked the chart.',
          'showDoctorSummary': 'false',
          'showValidationDetails': false,
          'showErrorDetails': 0,
          'showQuickFixes': 'no',
          'maxQuickFixes': '2',
        },
        'diagnostics': {
          'fallbackOptions': 'production',
          'performancePolicy': {'largeDatasetPointThreshold': 10},
        },
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };

      final result = ChartConfigValidator.validateJsonPayload(
        payload,
        deep: false,
      );

      expect(result.isValid, isTrue);
      expect(
        result.issues.where(
          (issue) => issue.code.startsWith('INVALID_DIAGNOSTIC_FALLBACK'),
        ),
        isEmpty,
      );
      expect(
        result.issues.where(
          (issue) => issue.code.startsWith('UNKNOWN_DIAGNOSTIC_FALLBACK'),
        ),
        isEmpty,
      );

      final config = ChartFactory.fromJson(
        payload,
        validatePayload: true,
        strictValidation: true,
      );
      expect(config.series.length, 1);
    });

    test('reports invalid diagnostic fallback option payload fields', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'diagnosticFallbackOptions': {
          'preset': 42,
          'title': false,
          'showDoctorSummary': 'maybe',
          'maxQuickFixes': -1,
          'extra': true,
        },
        'diagnostics': {'fallbackOptions': 'studio'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      final codes = result.issues.map((issue) => issue.code);
      expect(codes, contains('INVALID_DIAGNOSTIC_FALLBACK_PRESET_TYPE'));
      expect(codes, contains('INVALID_DIAGNOSTIC_FALLBACK_STRING'));
      expect(codes, contains('INVALID_DIAGNOSTIC_FALLBACK_BOOLEAN'));
      expect(codes, contains('INVALID_DIAGNOSTIC_FALLBACK_MAX_QUICK_FIXES'));
      expect(codes, contains('UNKNOWN_DIAGNOSTIC_FALLBACK_FIELD'));
      expect(codes, contains('UNKNOWN_DIAGNOSTIC_FALLBACK_PRESET'));
      expect(
        result.errors.map((issue) => issue.field),
        contains('diagnosticFallbackOptions.maxQuickFixes'),
      );
      expect(
        result.warnings.map((issue) => issue.field),
        contains('diagnostics.fallbackOptions'),
      );
    });

    test('accepts payload normalization option fields', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'autoNormalizePayload': 'true',
        'normalizationOptions': {
          'dropUnsupportedSampling': 'false',
          'defaultThreshold': '700',
          'defaultMode': 'large',
          'sanitizeTradingPayload': 'yes',
          'maxInlineLength': 72,
        },
        'diagnostics': {
          'normalizationOptions': {'defaultMode': 'auto'},
        },
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      expect(result.isValid, isTrue);
      expect(
        result.issues.where(
          (issue) => issue.code.startsWith('INVALID_PAYLOAD_NORMALIZATION'),
        ),
        isEmpty,
      );
      expect(
        result.issues.where(
          (issue) => issue.code.startsWith('UNKNOWN_PAYLOAD_NORMALIZATION'),
        ),
        isEmpty,
      );
    });

    test('reports invalid payload normalization option fields', () {
      final result = ChartConfigValidator.validateJsonPayload(const {
        'type': 'line',
        'autoNormalizePayload': 'sometimes',
        'normalizationOptions': {
          'dropUnsupportedSampling': 'maybe',
          'defaultThreshold': 0,
          'defaultMode': 'turbo',
          'sanitizeTradingPayload': 2,
          'maxInlineLength': -1,
          'extra': true,
        },
        'diagnostics': {'payloadNormalization': 'enabled'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, deep: false);

      final codes = result.issues.map((issue) => issue.code);
      expect(codes, contains('INVALID_PAYLOAD_NORMALIZATION_BOOLEAN'));
      expect(codes, contains('INVALID_PAYLOAD_NORMALIZATION_INTEGER'));
      expect(codes, contains('INVALID_PAYLOAD_NORMALIZATION_DATA_MODE'));
      expect(codes, contains('UNKNOWN_PAYLOAD_NORMALIZATION_FIELD'));
      expect(codes, contains('INVALID_PAYLOAD_NORMALIZATION_TYPE'));
      expect(
        result.errors.map((issue) => issue.field),
        contains('normalizationOptions.defaultThreshold'),
      );
      expect(
        result.errors.map((issue) => issue.field),
        contains('diagnostics.payloadNormalization'),
      );
    });

    test('throws on invalid runtime performance policy in strict mode', () {
      expect(
        () => ChartFactory.fromJson(
          const {
            'type': 'line',
            'runtimePerformancePolicy': {'largeDatasetPointThreshold': -1},
            'series': [
              {
                'data': [1, 2, 3],
              },
            ],
          },
          validatePayload: true,
          strictValidation: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('auto-normalizes invalid sampling payload in strict mode', () {
      final config = ChartFactory.fromJson(
        const {
          'type': 'line',
          'dataMode': 'turbo',
          'sampling': {'enabled': 'yes', 'threshold': 0, 'strategy': 'fastest'},
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        },
        validatePayload: true,
        strictValidation: true,
        autoNormalizePayload: true,
        normalizeDefaultThreshold: 700,
      );

      expect(config.series.length, 1);
    });

    test('reports normalization result when parsing JSON', () {
      PayloadNormalizationResult? report;

      final config = ChartFactory.fromJson(
        const {
          'type': 'line',
          'dataMode': 'turbo',
          'sampling': {'enabled': 'yes', 'threshold': 0, 'strategy': 'fastest'},
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        },
        validatePayload: true,
        strictValidation: true,
        autoNormalizePayload: true,
        normalizeDefaultThreshold: 700,
        onPayloadNormalizationResult: (result) => report = result,
      );

      expect(config.series.length, 1);
      expect(report, isNotNull);
      expect(report!.wasNormalized, isTrue);
      expect(report!.changed, isTrue);
      expect(report!.summary.total, report!.diffs.length);
      expect(report!.changedPaths, contains(r'$.dataMode'));
      expect(report!.normalizedPayload['dataMode'], 'auto');
      expect(report!.normalizedPayload['sampling']['threshold'], 700);
      expect(report!.diffs.map((diff) => diff.path), contains(r'$.dataMode'));
      expect(
        report!.diffs.map((diff) => diff.path),
        contains(r'$.sampling.threshold'),
      );
    });

    test('reports pass-through payload when normalization is disabled', () {
      PayloadNormalizationResult? report;

      ChartFactory.fromJson(const {
        'type': 'line',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      }, onPayloadNormalizationResult: (result) => report = result);

      expect(report, isNotNull);
      expect(report!.wasNormalized, isFalse);
      expect(report!.changed, isFalse);
      expect(report!.diffs, isEmpty);
      expect(report!.normalizedPayload['type'], 'line');
    });

    test('uses normalization options object when parsing JSON', () {
      PayloadNormalizationResult? report;

      final config = ChartFactory.fromJson(
        const {
          'type': 'line',
          'sampling': {'threshold': 0},
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        },
        autoNormalizePayload: true,
        normalizationOptions: const PayloadNormalizationOptions(
          defaultMode: ChartDataMode.large,
          defaultThreshold: 333,
        ),
        onPayloadNormalizationResult: (result) => report = result,
      );

      expect(config.series.length, 1);
      expect(report, isNotNull);
      expect(report!.normalizedPayload['dataMode'], 'large');
      expect(report!.normalizedPayload['sampling']['threshold'], 333);
    });

    test('reads payload normalization options from JSON payload', () {
      PayloadNormalizationResult? report;

      final config = ChartFactory.fromJson(
        const {
          'type': 'line',
          'autoNormalizePayload': true,
          'normalizationOptions': {
            'defaultMode': 'large',
            'defaultThreshold': '444',
            'dropUnsupportedSampling': false,
            'maxInlineLength': 24,
          },
          'sampling': {'threshold': 0},
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        },
        validatePayload: true,
        strictValidation: true,
        onPayloadNormalizationResult: (result) => report = result,
      );

      expect(config.series.length, 1);
      expect(report, isNotNull);
      expect(report!.wasNormalized, isTrue);
      expect(report!.normalizedPayload['dataMode'], 'large');
      expect(report!.normalizedPayload['sampling']['threshold'], 444);
    });
  });

  group('TenunChart normalization options', () {
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
    });

    testWidgets('sanitizes trading payload before strict render validation', (
      tester,
    ) async {
      final validationResults = <ValidationResult>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: {
                'type': 'renko',
                'brickSize': -2,
                'series': [
                  {
                    'data': [
                      100,
                      '101',
                      {'close': 102},
                      'bad',
                      103,
                    ],
                  },
                ],
              },
              validatePayload: true,
              strictValidation: true,
              autoNormalizePayload: true,
              sanitizeTradingPayload: true,
              onValidationResult: validationResults.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        validationResults.any(
          (r) => r.errors.any((e) => e.code == 'TRADING_NON_NUMERIC_PRICE'),
        ),
        isFalse,
      );
      expect(find.textContaining('Invalid chart payload'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('passes sanitizeTradingPayload to chart factory', (
      tester,
    ) async {
      final validationResults = <ValidationResult>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: {
                'type': 'renko',
                'brickSize': -2,
                'series': [
                  {
                    'data': [
                      100,
                      '101',
                      {'close': 102},
                      'bad',
                      103,
                    ],
                  },
                ],
              },
              validatePayload: true,
              strictValidation: true,
              autoNormalizePayload: true,
              sanitizeTradingPayload: false,
              onValidationResult: validationResults.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        validationResults.any(
          (r) => r.errors.any((e) => e.code == 'TRADING_NON_NUMERIC_PRICE'),
        ),
        isTrue,
      );
      expect(find.textContaining('Invalid chart payload'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('default validation fallback is compact and overflow safe', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 180,
            height: 48,
            child: TenunChartFromJson(
              jsonConfig: {
                'sampling': {
                  'enabled': 'yes',
                  'threshold': 0,
                  'strategy': 'fastest',
                },
                'series': {
                  'data': [1, 2, 3],
                },
              },
              validatePayload: true,
              strictValidation: true,
              validationReportMaxIssues: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invalid chart payload'), findsOneWidget);
      expect(find.textContaining('Doctor:'), findsOneWidget);
      expect(find.textContaining('more issue(s) hidden'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('passes diagnostic fallback options to validation fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 260,
            height: 160,
            child: TenunChartFromJson(
              jsonConfig: {
                'type': 'line',
                'sampling': {'enabled': 'yes'},
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              validatePayload: true,
              strictValidation: true,
              diagnosticFallbackOptions: TenunDiagnosticFallbackOptions(
                title: 'Strict validation blocked',
                message: 'Resolve this payload before release.',
                maxQuickFixes: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Strict validation blocked'), findsOneWidget);
      expect(find.text('Resolve this payload before release.'), findsOneWidget);
      expect(find.text('Quick fixes:'), findsOneWidget);
      expect(
        find.textContaining('Enable autoNormalizePayload'),
        findsOneWidget,
      );
      expect(find.textContaining('Apply normalization'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reads diagnostic fallback options from JSON payload', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 260,
            height: 160,
            child: TenunChartFromJson(
              jsonConfig: {
                'type': 'line',
                'diagnostics': {
                  'fallbackOptions': {
                    'preset': 'production',
                    'title': 'Payload blocked',
                    'message': 'Use a clean dataset before publishing.',
                  },
                },
                'sampling': {'enabled': 'yes'},
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              validatePayload: true,
              strictValidation: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Payload blocked'), findsOneWidget);
      expect(
        find.text('Use a clean dataset before publishing.'),
        findsOneWidget,
      );
      expect(find.textContaining('Doctor:'), findsNothing);
      expect(find.textContaining('sampling.enabled'), findsNothing);
      expect(find.text('Quick fixes:'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits effective payload normalization report', (tester) async {
      final reports = <PayloadNormalizationResult>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'renko',
                'brickSize': -2,
                'series': [
                  {
                    'data': [
                      100,
                      '101',
                      {'close': 102},
                      'bad',
                      103,
                    ],
                  },
                ],
              },
              autoNormalizePayload: true,
              sanitizeTradingPayload: true,
              onPayloadNormalizationResult: reports.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(reports, isNotEmpty);
      final report = reports.last;
      expect(report.wasNormalized, isTrue);
      expect(report.changed, isTrue);
      expect(report.normalizedPayload['brickSize'], 1.0);
      expect((report.normalizedPayload['series'] as List).first['data'], [
        100.0,
        101.0,
        102.0,
        103.0,
      ]);
      expect(report.diffs.map((diff) => diff.path), contains(r'$.brickSize'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('passes normalization options object to widget rendering', (
      tester,
    ) async {
      final reports = <PayloadNormalizationResult>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'line',
                'sampling': {'threshold': 0},
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              autoNormalizePayload: true,
              normalizationOptions: const PayloadNormalizationOptions(
                defaultMode: ChartDataMode.large,
                defaultThreshold: 444,
              ),
              onPayloadNormalizationResult: reports.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(reports, hasLength(1));
      expect(reports.single.normalizedPayload['dataMode'], 'large');
      expect(reports.single.normalizedPayload['sampling']['threshold'], 444);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reads payload normalization options from widget JSON', (
      tester,
    ) async {
      final reports = <PayloadNormalizationResult>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'line',
                'autoNormalizePayload': true,
                'diagnostics': {
                  'normalizationOptions': {
                    'defaultMode': 'large',
                    'defaultThreshold': '555',
                  },
                },
                'sampling': {'threshold': 0},
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              onPayloadNormalizationResult: reports.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(reports, hasLength(1));
      expect(reports.single.normalizedPayload['dataMode'], 'large');
      expect(reports.single.normalizedPayload['sampling']['threshold'], 555);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispatches widget callbacks after build safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: _CallbackSafetyProbe(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('payload: 1 validation: 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dedupes identical widget callback emissions across rebuilds', (
      tester,
    ) async {
      final payload = {
        'type': 'line',
        'dataMode': 'turbo',
        'sampling': {'enabled': 'yes', 'threshold': 0, 'strategy': 'fastest'},
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };
      final reports = <PayloadNormalizationResult>[];
      final validations = <ValidationResult>[];

      Widget buildHarness() {
        return MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: payload,
              validatePayload: true,
              autoNormalizePayload: true,
              normalizeDefaultThreshold: 700,
              onPayloadNormalizationResult: reports.add,
              onValidationResult: validations.add,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(reports.length, 1);
      expect(validations.length, 2);

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(reports.length, 1);
      expect(validations.length, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dedupes callbacks for equivalent rebuilt payload maps', (
      tester,
    ) async {
      final reports = <PayloadNormalizationResult>[];
      final validations = <ValidationResult>[];

      Map<String, dynamic> payload() => {
        'type': 'line',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };

      Widget buildHarness(Map<String, dynamic> json) {
        return MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: json,
              validatePayload: true,
              onPayloadNormalizationResult: reports.add,
              onValidationResult: validations.add,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness(payload()));
      await tester.pumpAndSettle();

      expect(reports.length, 1);
      expect(validations.length, 2);

      await tester.pumpWidget(buildHarness(payload()));
      await tester.pumpAndSettle();

      expect(reports.length, 1);
      expect(validations.length, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits callbacks when reused payload map content changes', (
      tester,
    ) async {
      final Map<String, dynamic> payload = {
        'type': 'line',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };
      final reports = <PayloadNormalizationResult>[];
      final validations = <ValidationResult>[];

      Widget buildHarness() {
        return MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: payload,
              validatePayload: true,
              onPayloadNormalizationResult: reports.add,
              onValidationResult: validations.add,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(reports.length, 1);
      expect(validations.length, 2);

      final series = payload['series'] as List;
      final firstSeries = series.first as Map<String, dynamic>;
      firstSeries['data'] = [1, 2, 4];
      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(reports.length, 2);
      expect(validations.length, 4);
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits runtime diagnostics after rendering JSON', (
      tester,
    ) async {
      final diagnostics = <ChartRuntimeDiagnostics>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'line',
                'sampling': {'enabled': true, 'threshold': 500},
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              onRuntimeDiagnostics: diagnostics.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(diagnostics.length, 1);
      final report = diagnostics.single;
      expect(report.type, ChartType.line);
      expect(report.jsonDriven, isTrue);
      expect(report.seriesCount, 1);
      expect(report.sourceDataPointCount, 3);
      expect(report.renderedDataPointCount, 3);
      expect(report.configSampledData, isFalse);
      expect(report.performanceSummary.renderedOutputRatio, 1);
      expect(report.performanceSummary.renderedReductionRatio, 0);
      expect(
        report.performancePolicySource,
        ChartRuntimePerformancePolicySource.fallback,
      );
      expect(report.performancePolicySourcePath, isNull);
      expect(report.performancePolicyFromJson, isFalse);
      expect(
        report.performanceSummary.severity,
        isA<ChartRuntimePerformanceSeverity>(),
      );
      expect(report.toJson()['type'], 'line');
      expect(report.renderCacheStats, isNotNull);
      expect(report.pictureCacheStats, isNotNull);
      final json = report.toJson();
      final samplingJson = json['sampling'] as Map<String, dynamic>;
      samplingJson['threshold'] = 999;
      expect((report.sampling as Map)['threshold'], 500);
      expect(json['performanceSummary'], isA<Map<String, dynamic>>());
      expect(
        (json['performanceSummary'] as Map<String, dynamic>)['policy'],
        isA<Map<String, dynamic>>(),
      );
      expect(
        (json['performanceSummary']
            as Map<String, dynamic>)['recommendationHint'],
        isA<String>(),
      );
      expect(
        (json['performancePolicyResolution'] as Map<String, dynamic>)['source'],
        'fallback',
      );
      expect(json['renderCaches'], isA<Map<String, dynamic>>());
      expect(json['pictureCache'], isA<Map<String, dynamic>>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports payload normalization in runtime diagnostics', (
      tester,
    ) async {
      final diagnostics = <ChartRuntimeDiagnostics>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'sankey',
                'nodes': [
                  {'id': 'source', 'name': 'Source'},
                  {'id': 'target', 'name': 'Target'},
                ],
                'links': [
                  {'source': 'source', 'target': 'target', 'value': 8},
                ],
              },
              autoNormalizePayload: true,
              onRuntimeDiagnostics: diagnostics.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(diagnostics.length, 1);
      final report = diagnostics.single;
      expect(report.type, ChartType.sankey);
      expect(report.payloadWasNormalized, isTrue);
      expect(report.payloadChanged, isTrue);
      expect(report.payloadDiffCount, greaterThan(0));
      expect(report.payloadChangedPaths, contains(r'$.series'));
      expect(report.rawInputSignature, isNotNull);
      expect(report.rawInputSignature!.dataPointCount, 3);
      expect(report.sourceDataPointCount, 3);
      expect(report.renderedDataPointCount, 3);
      final json = report.toJson();
      expect(json['rawInputSignature'], isA<Map<String, dynamic>>());
      expect(json['payloadNormalization'], {
        'wasNormalized': true,
        'changed': true,
        'diffCount': report.payloadDiffCount,
        'changedPaths': report.payloadChangedPaths,
      });
      ((json['payloadNormalization'] as Map)['changedPaths'] as List).add(
        r'$.mutated',
      );
      expect(report.payloadChangedPaths, isNot(contains(r'$.mutated')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports runtime diagnostics for bar race shorthand frames', (
      tester,
    ) async {
      final diagnostics = <ChartRuntimeDiagnostics>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'barRace',
                'categories': ['Alpha', 'Beta'],
                'frameLabels': ['2025', '2026'],
                'frames': [
                  [10, 20],
                  [12, 24],
                ],
                'autoPlay': false,
                'showControls': false,
              },
              onRuntimeDiagnostics: diagnostics.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(diagnostics.length, 1);
      final report = diagnostics.single;
      expect(report.type, ChartType.barRace);
      expect(report.jsonDriven, isTrue);
      expect(report.seriesCount, 1);
      expect(report.sourceDataPointCount, 4);
      expect(report.renderedDataPointCount, 4);
      expect(report.configSampledData, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports sampled runtime diagnostics for candlestick JSON', (
      tester,
    ) async {
      final diagnostics = <ChartRuntimeDiagnostics>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'candlestick',
                'dataMode': 'large',
                'sampling': {'threshold': 3, 'strategy': 'nth'},
                'showVolume': false,
                'series': [
                  {
                    'data': [
                      {
                        'date': 'D1',
                        'open': 100,
                        'high': 110,
                        'low': 95,
                        'close': 108,
                      },
                      {
                        'date': 'D2',
                        'open': 108,
                        'high': 114,
                        'low': 104,
                        'close': 112,
                      },
                      {
                        'date': 'D3',
                        'open': 112,
                        'high': 118,
                        'low': 109,
                        'close': 115,
                      },
                      {
                        'date': 'D4',
                        'open': 115,
                        'high': 120,
                        'low': 111,
                        'close': 113,
                      },
                      {
                        'date': 'D5',
                        'open': 113,
                        'high': 122,
                        'low': 112,
                        'close': 121,
                      },
                    ],
                  },
                ],
              },
              onRuntimeDiagnostics: diagnostics.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(diagnostics.length, 1);
      final report = diagnostics.single;
      expect(report.type, ChartType.candlestick);
      expect(report.sourceDataPointCount, 5);
      expect(report.effectiveDataPointCount, isNull);
      expect(report.sampleInputPointCount, isNull);
      expect(report.renderedDataPointCount, 3);
      expect(report.seriesCount, 1);
      expect(report.configSampledData, isTrue);
      expect(report.performanceSummary.configSampledData, isTrue);
      expect(report.performanceSummary.samplingOutputRatio, isNull);
      expect(report.performanceSummary.samplingReductionRatio, isNull);
      expect(
        report.performanceSummary.renderedOutputRatio,
        closeTo(0.6, 0.001),
      );
      expect(
        report.performanceSummary.renderedReductionRatio,
        closeTo(0.4, 0.001),
      );
      final json = report.toJson();
      expect(json.containsKey('effectiveDataPointCount'), isFalse);
      expect(json.containsKey('sampleInputPointCount'), isFalse);
      expect(tester.takeException(), isNull);
    });

    test('runtime diagnostics can include processing report sample inputs', () {
      final series = [
        Series(
          type: ChartType.line,
          data: [double.nan, 1, double.infinity, 2, 3, 4, 5],
        ),
      ];
      final processing = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 3,
        samplingStrategy: SamplingStrategy.nth,
        useCache: false,
      );
      final report = ChartRuntimeDiagnostics.fromResolvedConfig(
        config: _FakeLineConfig(series: series),
        jsonDriven: false,
        configResolveDuration: Duration.zero,
        chartBuildDuration: Duration.zero,
        totalBuildDuration: Duration.zero,
        processingReport: processing.report,
      );

      expect(report.sourceDataPointCount, 7);
      expect(report.effectiveDataPointCount, 7);
      expect(report.sampleInputPointCount, 5);
      expect(report.renderedDataPointCount, 3);
      expect(report.configSampledData, isTrue);
      expect(report.performanceSummary.effectiveDataPointCount, 7);
      expect(report.performanceSummary.sampleInputPointCount, 5);
      expect(
        report.performanceSummary.samplingOutputRatio,
        closeTo(3 / 5, 1e-9),
      );
      expect(
        report.performanceSummary.samplingReductionRatio,
        closeTo(2 / 5, 1e-9),
      );
      final json = report.toJson();
      expect(json['effectiveDataPointCount'], 7);
      expect(json['sampleInputPointCount'], 5);
      expect(
        (json['performanceSummary']
            as Map<String, dynamic>)['sampleInputPointCount'],
        5,
      );
    });

    test('flags large unsampled runtime inputs', () {
      final summary = ChartRuntimePerformanceSummary.fromRuntimeInputs(
        sourceDataPointCount: 500,
        renderedDataPointCount: 500,
        seriesCount: 1,
        configSampledData: false,
        payloadWasNormalized: false,
        payloadChanged: false,
        processingCacheStats: const ChartDataProcessingCacheStats(
          enabled: true,
          size: 0,
          maxEntries: 32,
          minPointCount: 1000,
          hits: 0,
          misses: 0,
          writes: 0,
          evictions: 0,
        ),
        policy: const ChartRuntimePerformancePolicy(
          largeDatasetPointThreshold: 500,
        ),
      );

      expect(summary.largeUnsampled, isTrue);
      expect(summary.hasRecommendation, isTrue);
      expect(summary.requiresAction, isTrue);
      expect(summary.severity, ChartRuntimePerformanceSeverity.warning);
      expect(
        summary.recommendation,
        ChartRuntimePerformanceRecommendation.enableSampling,
      );
      expect(summary.recommendationHint, contains('sampling'));
      expect(
        summary.toJson(),
        containsPair('recommendation', 'enableSampling'),
      );
      expect(summary.toJson(), containsPair('requiresAction', true));
      expect(
        summary.toJson()['policy'],
        containsPair('largeDatasetPointThreshold', 500),
      );
    });

    test('resolves runtime performance policy source labels', () {
      final cases =
          <
            ({
              Map<String, dynamic> payload,
              String? sourcePath,
              String sourceLabel,
              int threshold,
            })
          >[
            (
              payload: {'largeDatasetPointThreshold': 3},
              sourcePath: null,
              sourceLabel: 'json',
              threshold: 3,
            ),
            (
              payload: {
                'runtimePerformancePolicy': {'largeDatasetPointThreshold': 4},
              },
              sourcePath: 'runtimePerformancePolicy',
              sourceLabel: 'runtimePerformancePolicy',
              threshold: 4,
            ),
            (
              payload: {
                'performancePolicy': {'largeDatasetPointThreshold': 5},
              },
              sourcePath: 'performancePolicy',
              sourceLabel: 'performancePolicy',
              threshold: 5,
            ),
            (
              payload: {
                'diagnostics': {'largeDatasetPointThreshold': 6},
              },
              sourcePath: 'diagnostics',
              sourceLabel: 'diagnostics',
              threshold: 6,
            ),
            (
              payload: {
                'diagnostics': {
                  'performancePolicy': {'largeDatasetPointThreshold': 7},
                },
              },
              sourcePath: 'diagnostics.performancePolicy',
              sourceLabel: 'diagnostics.performancePolicy',
              threshold: 7,
            ),
            (
              payload: {
                'runtimeDiagnostics': {
                  'runtimePerformancePolicy': {'largeDatasetPointThreshold': 8},
                },
              },
              sourcePath: 'runtimeDiagnostics.runtimePerformancePolicy',
              sourceLabel: 'runtimeDiagnostics.runtimePerformancePolicy',
              threshold: 8,
            ),
          ];

      for (final testCase in cases) {
        final resolution = ChartRuntimePerformancePolicy.resolve(
          testCase.payload,
        );

        expect(
          resolution.source,
          ChartRuntimePerformancePolicySource.json,
          reason: testCase.sourceLabel,
        );
        expect(
          resolution.sourcePath,
          testCase.sourcePath,
          reason: testCase.sourceLabel,
        );
        expect(resolution.sourceLabel, testCase.sourceLabel);
        expect(
          resolution.policy.normalizedLargeDatasetPointThreshold,
          testCase.threshold,
          reason: testCase.sourceLabel,
        );
      }

      final fallback = ChartRuntimePerformancePolicy.resolve(null);
      expect(fallback.source, ChartRuntimePerformancePolicySource.fallback);
      expect(fallback.sourcePath, isNull);
      expect(fallback.sourceLabel, 'fallback');
      expect(fallback.toJson(), containsPair('sourceLabel', 'fallback'));
      expect(fallback.toJson().containsKey('sourcePath'), isFalse);

      final direct = ChartRuntimePerformancePolicy.resolve(const {
        'largeDatasetPointThreshold': 3,
      });
      expect(direct.toJson(), containsPair('sourceLabel', 'json'));
      expect(direct.toJson().containsKey('sourcePath'), isFalse);
    });

    testWidgets('dedupes equivalent runtime diagnostics across rebuilds', (
      tester,
    ) async {
      final diagnostics = <ChartRuntimeDiagnostics>[];

      Map<String, dynamic> payload() => {
        'type': 'line',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };

      Widget buildHarness(Map<String, dynamic> json) {
        return MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: json,
              onRuntimeDiagnostics: diagnostics.add,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHarness(payload()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(buildHarness(payload()));
      await tester.pumpAndSettle();

      expect(diagnostics.length, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits diagnostics when runtime performance policy changes', (
      tester,
    ) async {
      final diagnostics = <ChartRuntimeDiagnostics>[];

      Widget buildHarness(ChartRuntimePerformancePolicy policy) {
        return MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'line',
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              runtimePerformancePolicy: policy,
              onRuntimeDiagnostics: diagnostics.add,
            ),
          ),
        );
      }

      await tester.pumpWidget(
        buildHarness(ChartRuntimePerformancePolicy.defaults),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        buildHarness(
          const ChartRuntimePerformancePolicy(largeDatasetPointThreshold: 3),
        ),
      );
      await tester.pumpAndSettle();

      expect(diagnostics.length, 2);
      expect(
        diagnostics.last.performanceSummary.recommendation,
        ChartRuntimePerformanceRecommendation.enableSampling,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reads runtime performance policy from JSON payload', (
      tester,
    ) async {
      final diagnostics = <ChartRuntimeDiagnostics>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'line',
                'diagnostics': {
                  'performancePolicy': {
                    'largeDatasetPointThreshold': 3,
                    'cachePressureWarningThreshold': '85%',
                    'lowRenderCacheHitRateThreshold': 20,
                    'lowRenderCacheMinRequests': '4',
                  },
                },
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              onRuntimeDiagnostics: diagnostics.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(diagnostics.length, 1);
      final summary = diagnostics.single.performanceSummary;
      expect(
        diagnostics.single.performancePolicySource,
        ChartRuntimePerformancePolicySource.json,
      );
      expect(
        diagnostics.single.performancePolicySourcePath,
        'diagnostics.performancePolicy',
      );
      expect(diagnostics.single.performancePolicyFromJson, isTrue);
      expect(summary.policy.normalizedLargeDatasetPointThreshold, 3);
      expect(summary.policy.normalizedCachePressureWarningThreshold, 0.85);
      expect(summary.policy.normalizedLowRenderCacheHitRateThreshold, 0.2);
      expect(summary.policy.normalizedLowRenderCacheMinRequests, 4);
      expect(
        summary.recommendation,
        ChartRuntimePerformanceRecommendation.enableSampling,
      );
      expect(summary.requiresAction, isTrue);
      expect(
        summary.toJson()['policy'],
        containsPair('largeDatasetPointThreshold', 3),
      );
      expect(
        diagnostics.single.toJson()['performancePolicyResolution'],
        containsPair('sourcePath', 'diagnostics.performancePolicy'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders fallback and reports render errors when enabled', (
      tester,
    ) async {
      ChartRegistry.clear();
      final errors = <Object>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'line',
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              catchRenderErrors: true,
              onRenderError: (error, stackTrace) => errors.add(error),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Chart render error'), findsOneWidget);
      expect(errors, hasLength(1));
      expect(errors.single, isA<UnregisteredChartTypeException>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('TenunChartFromJson renders render fallback by default', (
      tester,
    ) async {
      ChartRegistry.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: {
                'type': 'line',
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Chart render error'), findsOneWidget);
      expect(find.textContaining('Render Doctor:'), findsOneWidget);
      expect(find.textContaining('UNREGISTERED_TYPE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TenunChartFromJson can opt into raw render exceptions', (
      tester,
    ) async {
      ChartRegistry.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: {
                'type': 'line',
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              catchRenderErrors: false,
            ),
          ),
        ),
      );

      expect(find.textContaining('Chart render error'), findsNothing);
      expect(tester.takeException(), isA<UnregisteredChartTypeException>());
    });

    testWidgets('passes diagnostic fallback options to render fallback', (
      tester,
    ) async {
      ChartRegistry.clear();

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: {
                'type': 'line',
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              catchRenderErrors: true,
              diagnosticFallbackOptions: TenunDiagnosticFallbackOptions(
                title: 'Render blocked',
                message: 'Use a registered chart bundle.',
                showErrorDetails: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Render blocked'), findsOneWidget);
      expect(find.text('Use a registered chart bundle.'), findsOneWidget);
      expect(
        find.textContaining('UnregisteredChartTypeException'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports render errors again for changed failing payloads', (
      tester,
    ) async {
      ChartRegistry.clear();
      final errors = <Object>[];

      Widget buildHarness(Map<String, dynamic> payload) {
        return MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: payload,
              catchRenderErrors: true,
              onRenderError: (error, stackTrace) => errors.add(error),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        buildHarness(const {
          'type': 'line',
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        buildHarness(const {
          'type': 'line',
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        buildHarness(const {
          'type': 'line',
          'series': [
            {
              'data': [10, 20, 30, 40],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Chart render error'), findsOneWidget);
      expect(errors, hasLength(2));
      expect(errors, everyElement(isA<UnregisteredChartTypeException>()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses custom render error builder', (tester) async {
      ChartRegistry.clear();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: const {
                'type': 'line',
                'series': [
                  {
                    'data': [1, 2, 3],
                  },
                ],
              },
              renderErrorBuilder: (context, error, stackTrace) {
                return Text('custom fallback: ${error.runtimeType}');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('custom fallback: UnregisteredChartTypeException'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Series JSON parsing', () {
    test('accepts hex string colors', () {
      final series = Series.fromJson(const {
        'type': 'line',
        'name': 'ROC',
        'color': '#2196F3',
        'data': [
          [0.0, 0.0],
          [1.0, 1.0],
        ],
      });

      expect(series.color, const Color(0xFF2196F3));
    });
  });
}

class _CallbackSafetyProbe extends StatefulWidget {
  const _CallbackSafetyProbe();

  @override
  State<_CallbackSafetyProbe> createState() => _CallbackSafetyProbeState();
}

class _CallbackSafetyProbeState extends State<_CallbackSafetyProbe> {
  int payloadCallbacks = 0;
  int validationCallbacks = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('payload: $payloadCallbacks validation: $validationCallbacks'),
        Expanded(
          child: TenunChartFromJson(
            jsonConfig: const {
              'type': 'line',
              'dataMode': 'turbo',
              'sampling': {
                'enabled': 'yes',
                'threshold': 0,
                'strategy': 'fastest',
              },
              'series': [
                {
                  'data': [1, 2, 3],
                },
              ],
            },
            validatePayload: true,
            autoNormalizePayload: true,
            normalizeDefaultThreshold: 700,
            onPayloadNormalizationResult: (_) {
              setState(() => payloadCallbacks++);
            },
            onValidationResult: (_) {
              setState(() => validationCallbacks++);
            },
          ),
        ),
      ],
    );
  }
}
