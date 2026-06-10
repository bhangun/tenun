import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

int _probeParseCount = 0;

class _ProbeConfig extends BaseChartConfig {
  _ProbeConfig({required super.series}) : super(type: ChartType.line);

  factory _ProbeConfig.fromJson(Map<String, dynamic> json) {
    _probeParseCount++;
    final series = (json['series'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((entry) => Series.fromJson(entry.cast<String, dynamic>()))
        .toList();
    return _ProbeConfig(series: series);
  }

  @override
  Widget buildChart() => Text('probe:${series.length}');
}

const _probeRegistration = ChartRegistration(
  type: ChartType.line,
  typeString: 'line',
  fromJson: _ProbeConfig.fromJson,
);

class _ProbeTreemapConfig extends BaseChartConfig {
  final int nodeCount;

  _ProbeTreemapConfig({required super.series, required this.nodeCount})
    : super(type: ChartType.treemap);

  factory _ProbeTreemapConfig.fromJson(Map<String, dynamic> json) {
    final series = (json['series'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((entry) => Series.fromJson(entry.cast<String, dynamic>()))
        .toList();
    final firstData = series.isEmpty
        ? const <dynamic>[]
        : (series.first.data ?? const <dynamic>[]);
    return _ProbeTreemapConfig(series: series, nodeCount: firstData.length);
  }

  @override
  Widget buildChart() => Text('probe-treemap:$nodeCount');
}

const _probeTreemapRegistration = ChartRegistration(
  type: ChartType.treemap,
  typeString: 'treemap',
  fromJson: _ProbeTreemapConfig.fromJson,
);

class _ProbeSunburstConfig extends BaseChartConfig {
  final int nodeCount;

  _ProbeSunburstConfig({required super.series, required this.nodeCount})
    : super(type: ChartType.sunburst);

  factory _ProbeSunburstConfig.fromJson(Map<String, dynamic> json) {
    final series = (json['series'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((entry) => Series.fromJson(entry.cast<String, dynamic>()))
        .toList();
    final firstData = series.isEmpty
        ? const <dynamic>[]
        : (series.first.data ?? const <dynamic>[]);
    return _ProbeSunburstConfig(series: series, nodeCount: firstData.length);
  }

  @override
  Widget buildChart() => Text('probe-sunburst:$nodeCount');
}

const _probeSunburstRegistration = ChartRegistration(
  type: ChartType.sunburst,
  typeString: 'sunburst',
  fromJson: _ProbeSunburstConfig.fromJson,
);

void main() {
  group('TenunChartJson safe build', () {
    setUp(() {
      ChartRegistry.clear();
      ChartRegistry.register(_probeRegistration);
      _probeParseCount = 0;
    });

    testWidgets('renders valid JSON and reports build result once', (
      WidgetTester tester,
    ) async {
      final results = <TenunOptionBuildResult>[];

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: const {
              'type': 'line',
              'series': [
                {
                  'name': 'Sales',
                  'data': [10, 20, 30],
                },
              ],
            },
            onBuildResult: results.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('probe:1'), findsOneWidget);
      expect(results, hasLength(1));
      expect(results.single.isRenderSafe, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dedupes build callback for equivalent rebuilt payloads', (
      WidgetTester tester,
    ) async {
      final results = <TenunOptionBuildResult>[];
      void collect(TenunOptionBuildResult result) => results.add(result);

      Map<String, dynamic> payload(List<int> data) => {
        'type': 'line',
        'series': [
          {'name': 'Sales', 'data': data},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: payload([10, 20, 30]),
            onBuildResult: collect,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: payload([10, 20, 30]),
            onBuildResult: collect,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: payload([10, 25, 30]),
            onBuildResult: collect,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(results, hasLength(2));
      expect(results.last.payload['series'], isA<List<dynamic>>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('reuses cached config build for equivalent payloads', (
      WidgetTester tester,
    ) async {
      const chartKey = ValueKey('cached-json-chart');
      final payload = <String, dynamic>{
        'type': 'line',
        'series': [
          {
            'name': 'Sales',
            'data': [10, 20, 30],
          },
        ],
      };

      Widget chart(Map<String, dynamic> json) => MaterialApp(
        home: TenunChartJson(key: chartKey, jsonConfig: json),
      );

      await tester.pumpWidget(chart(payload));
      await tester.pumpAndSettle();
      expect(find.text('probe:1'), findsOneWidget);
      final countAfterFirstBuild = _probeParseCount;
      final generationAfterFirstBuild = ChartRegistry.generation;
      expect(countAfterFirstBuild, greaterThanOrEqualTo(1));

      await tester.pumpWidget(
        chart({
          'type': 'line',
          'series': [
            {
              'name': 'Sales',
              'data': [10, 20, 30],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();
      if (ChartRegistry.generation == generationAfterFirstBuild) {
        expect(_probeParseCount, countAfterFirstBuild);
      }

      final countBeforeMutation = _probeParseCount;
      (payload['series'] as List<dynamic>)[0] = {
        'name': 'Sales',
        'data': [10, 25, 30],
      };
      await tester.pumpWidget(chart(payload));
      await tester.pumpAndSettle();
      expect(_probeParseCount, greaterThan(countBeforeMutation));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders fallback for invalid JSON without throwing', (
      WidgetTester tester,
    ) async {
      final results = <TenunOptionBuildResult>[];

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: const {
              'type': 'line',
              'sampling': {'enabled': 'yes'},
              'series': [
                {
                  'data': [10, 20, 30],
                },
              ],
            },
            onBuildResult: results.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invalid chart payload'), findsOneWidget);
      expect(find.textContaining('Doctor: repairable'), findsOneWidget);
      expect(find.textContaining('expected cartesian'), findsOneWidget);
      expect(find.text('Quick fixes:'), findsOneWidget);
      expect(
        find.textContaining('Enable autoNormalizePayload'),
        findsOneWidget,
      );
      expect(find.textContaining('Apply normalization'), findsOneWidget);
      expect(find.text('probe:1'), findsNothing);
      expect(results, hasLength(1));
      expect(results.single.isRenderSafe, isFalse);
      expect(results.single.buildAttempted, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto-normalizes shorthand JSON before safe build', (
      WidgetTester tester,
    ) async {
      ChartRegistry.register(_probeTreemapRegistration);
      final results = <TenunOptionBuildResult>[];

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: const {
              'type': 'treemap',
              'showLabels': false,
              'nodes': [
                {'name': 'Tech', 'value': 10},
                {'name': 'Finance', 'value': 8},
              ],
            },
            autoNormalizePayload: true,
            onBuildResult: results.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('probe-treemap:2'), findsOneWidget);
      expect(results, hasLength(1));
      expect(results.single.isRenderSafe, isTrue);
      expect(results.single.payload['showLabels'], isFalse);
      expect(results.single.payload['nodes'], isA<List<dynamic>>());
      expect(results.single.payload['series'], isA<List<dynamic>>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('forceType switches auto-normalized shorthand JSON', (
      WidgetTester tester,
    ) async {
      final switches = <ValidatedChartTypeSwitchResult>[];
      final builds = <TenunOptionBuildResult>[];
      ChartRegistry.register(_probeTreemapRegistration);
      ChartRegistry.register(_probeSunburstRegistration);

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: const {
              'type': 'treemap',
              'nodes': [
                {'name': 'Tech', 'value': 10},
                {'name': 'Finance', 'value': 8},
              ],
            },
            autoNormalizePayload: true,
            forceType: ChartType.sunburst,
            onSwitchResult: switches.add,
            onBuildResult: builds.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('probe-sunburst:2'), findsOneWidget);
      expect(switches, hasLength(1));
      expect(switches.single.isRenderSafe, isTrue);
      expect(switches.single.payload!['type'], 'sunburst');
      expect(builds, hasLength(1));
      expect(builds.single.isRenderSafe, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('passes diagnostic fallback options to invalid JSON fallback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TenunChartJson(
            jsonConfig: {
              'type': 'line',
              'sampling': {'enabled': 'yes'},
              'series': [
                {
                  'data': [10, 20, 30],
                },
              ],
            },
            diagnosticFallbackOptions: TenunDiagnosticFallbackOptions(
              title: 'Chart needs review',
              message: 'Fix this payload before sharing.',
              showQuickFixes: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chart needs review'), findsOneWidget);
      expect(find.text('Fix this payload before sharing.'), findsOneWidget);
      expect(find.textContaining('Doctor: repairable'), findsOneWidget);
      expect(find.text('Quick fixes:'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reads diagnostic fallback options from JSON payload', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TenunChartJson(
            jsonConfig: {
              'type': 'line',
              'diagnosticFallbackOptions': {
                'preset': 'production',
                'title': 'Chart hidden',
                'message': 'Review this payload in diagnostics.',
              },
              'sampling': {'enabled': 'yes'},
              'series': [
                {
                  'data': [10, 20, 30],
                },
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chart hidden'), findsOneWidget);
      expect(find.text('Review this payload in diagnostics.'), findsOneWidget);
      expect(find.textContaining('Doctor:'), findsNothing);
      expect(find.textContaining('sampling.enabled'), findsNothing);
      expect(find.text('Quick fixes:'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('updates fallback when diagnostic options change', (
      WidgetTester tester,
    ) async {
      const chartKey = ValueKey('diagnostic-options-json-chart');
      const payload = {
        'type': 'line',
        'sampling': {'enabled': 'yes'},
        'series': [
          {
            'data': [10, 20, 30],
          },
        ],
      };

      Widget chart(TenunDiagnosticFallbackOptions options) => MaterialApp(
        home: TenunChartJson(
          key: chartKey,
          jsonConfig: payload,
          diagnosticFallbackOptions: options,
        ),
      );

      await tester.pumpWidget(
        chart(
          const TenunDiagnosticFallbackOptions(title: 'First diagnostic title'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First diagnostic title'), findsOneWidget);
      expect(find.text('Second diagnostic title'), findsNothing);

      await tester.pumpWidget(
        chart(
          const TenunDiagnosticFallbackOptions(
            title: 'Second diagnostic title',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First diagnostic title'), findsNothing);
      expect(find.text('Second diagnostic title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('forceType uses validated switching before rendering', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TenunChartJson(
            jsonConfig: {
              'type': 'bar',
              'xAxis': {
                'data': ['A', 'B'],
              },
              'series': [
                {
                  'data': [10, 20],
                },
              ],
            },
            forceType: ChartType.line,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('probe:1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('forceType recomputes after registry generation changes', (
      WidgetTester tester,
    ) async {
      ChartRegistry.clear();

      const chartKey = ValueKey('force-registry-json-chart');
      Map<String, dynamic> payload() => {
        'type': 'bar',
        'xAxis': {
          'data': ['A', 'B'],
        },
        'series': [
          {
            'data': [10, 20],
          },
        ],
      };
      Widget chart() => MaterialApp(
        home: TenunChartJson(
          key: chartKey,
          jsonConfig: payload(),
          forceType: ChartType.line,
        ),
      );

      await tester.pumpWidget(chart());
      await tester.pumpAndSettle();
      expect(find.text('probe:1'), findsNothing);

      ChartRegistry.register(_probeRegistration);
      await tester.pumpWidget(chart());
      await tester.pumpAndSettle();

      expect(find.text('probe:1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders switch fallback when forceType is not render-safe', (
      WidgetTester tester,
    ) async {
      final results = <ValidatedChartTypeSwitchResult>[];

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: const {
              'type': 'line',
              'series': [
                {
                  'data': [10, 20],
                },
              ],
            },
            forceType: ChartType.treemap,
            onSwitchResult: results.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chart type switch blocked'), findsOneWidget);
      expect(find.textContaining('Switch Doctor:'), findsOneWidget);
      expect(
        find.textContaining('source cartesian -> target hierarchy'),
        findsOneWidget,
      );
      expect(find.text('Quick fixes:'), findsOneWidget);
      expect(find.text('probe:1'), findsNothing);
      expect(results, hasLength(1));
      expect(results.single.isRenderSafe, isFalse);
      expect(results.single.payload, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dedupes switch callback for equivalent rebuilt payloads', (
      WidgetTester tester,
    ) async {
      final results = <ValidatedChartTypeSwitchResult>[];
      void collect(ValidatedChartTypeSwitchResult result) =>
          results.add(result);

      Map<String, dynamic> payload() => {
        'type': 'line',
        'series': [
          {
            'data': [10, 20],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: payload(),
            forceType: ChartType.treemap,
            onSwitchResult: collect,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: payload(),
            forceType: ChartType.treemap,
            onSwitchResult: collect,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: payload(),
            forceType: ChartType.line,
            onSwitchResult: collect,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(results, hasLength(2));
      expect(results.first.isRenderSafe, isFalse);
      expect(results.last.isRenderSafe, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses custom switch fallback builder', (
      WidgetTester tester,
    ) async {
      ValidatedChartTypeSwitchResult? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: TenunChartJson(
            jsonConfig: const {
              'type': 'line',
              'series': [
                {
                  'data': [10, 20],
                },
              ],
            },
            forceType: ChartType.treemap,
            switchErrorBuilder: (context, result) {
              captured = result;
              return Text(
                'custom-switch:${result.targetTypeString}:${result.isRenderSafe}',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('custom-switch:treemap:false'), findsOneWidget);
      expect(find.text('Chart type switch blocked'), findsNothing);
      expect(captured, isNotNull);
      expect(captured!.payload, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
