import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';
import 'package:tenun/charts/bar/bar_chart_variants.dart';
import 'package:tenun/charts/bar/rainfall_chart.dart';
import 'package:tenun/charts/bullet/bullet_chart.dart';
import 'package:tenun/charts/calendar/calendar_chart.dart';
import 'package:tenun/charts/choroplet/choropleth_chart.dart';
import 'package:tenun/charts/combo/combo_chart.dart';
import 'package:tenun/charts/histogram/histogram_chart.dart';
import 'package:tenun/charts/line/line_area_variants.dart';
import 'package:tenun/charts/lollipop/lollipop_chart.dart';
import 'package:tenun/charts/network/network_radial_timeline_wordcloud_charts.dart';
import 'package:tenun/charts/pararel/pararel_chart.dart';
import 'package:tenun/charts/pie/pie_chart_variants.dart';
import 'package:tenun/charts/rigeline/ridgeline_strip_error_bar_charts.dart';
import 'package:tenun/charts/slope/slope_dumbbell_areabump_charts.dart';
import 'package:tenun/charts/sparkline/sparkline_chart.dart';

import 'package:tenun/charts/bar/bar_chart_variants.dart';
import 'package:tenun/charts/bar/rainfall_chart.dart';
import 'package:tenun/charts/bullet/bullet_chart.dart';
import 'package:tenun/charts/calendar/calendar_chart.dart';
import 'package:tenun/charts/choroplet/choropleth_chart.dart';
import 'package:tenun/charts/combo/combo_chart.dart';
import 'package:tenun/charts/histogram/histogram_chart.dart';
import 'package:tenun/charts/line/line_area_variants.dart';
import 'package:tenun/charts/lollipop/lollipop_chart.dart';
import 'package:tenun/charts/network/network_radial_timeline_wordcloud_charts.dart';
import 'package:tenun/charts/pararel/pararel_chart.dart';
import 'package:tenun/charts/pie/pie_chart_variants.dart';
import 'package:tenun/charts/rigeline/ridgeline_strip_error_bar_charts.dart';
import 'package:tenun/charts/slope/slope_dumbbell_areabump_charts.dart';
import 'package:tenun/charts/sparkline/sparkline_chart.dart';
import 'package:tenun/charts/trading/trading_charts.dart';
import 'package:tenun/registry/bundle_cartesian.dart' hide lineRegistration, areaRegistration, barRegistration, scatterRegistration;
import 'package:tenun/registry/bundle_financial.dart';
import 'package:tenun/registry/bundle_flow.dart';
import 'package:tenun/registry/bundle_geo.dart';
import 'package:tenun/registry/bundle_radial.dart';
import 'package:tenun/registry/bundle_hierarchical.dart';
import 'package:tenun/registry/bundle_matrix.dart';
import 'package:tenun/registry/bundle_pie.dart';
import 'package:tenun/registry/bundle_calendar.dart';
import 'package:tenun/registry/bundle_graph.dart';
import 'package:tenun/registry/bundle_common.dart';

import 'package:tenun/charts/violin/violin_chart.dart';
import 'package:tenun/registry/bundle_cartesian.dart'
    hide lineRegistration, areaRegistration;
import 'package:tenun/registry/bundle_common.dart';


void _registerAllBundles() {
  allChartsBundle.register();
  cartesianChartsBundle.register();
  financialChartsBundle.register();
  flowChartsBundle.register();
  geoChartsBundle.register();
  radialChartsBundle.register();
  commonChartsBundle.register();
  hierarchicalChartsBundle.register();
  matrixChartsBundle.register();
  pieChartsBundle.register();
  calendarChartsBundle.register();
  graphChartsBundle.register();
}

void main() {
  group('Chart registry for new charts', () {
    setUp(() {
      ChartRegistry.clear();
    });

    test('all bundle registers new chart types', () {
      _registerAllBundles();

      const expected = <String>[
        'combo',
        'bullet',
        'histogram',
        'lollipop',
        'sparkline',
        'kagi',
        'renko',
        'macd',
        'ridgeline',
        'strip',
        'errorbar',
        'network',
        'radial',
        'timeline',
        'wordcloud',
        'calendar',
        'parallel',
        'violin',
        'barbackground',
        'linegradient',
        'halfdonut',
        'choropleth',
        'slope',
        'dumbbell',
        'areabump',
        'rainfall',
      ];

      for (final type in expected) {
        expect(
          ChartRegistry.isRegisteredString(type),
          isTrue,
          reason: '$type should be registered by allChartsBundle',
        );
      }
    });

    test('all bundle has no duplicate registration errors', () {
      final audit = auditRegistrationBundle(allChartsBundle);

      expect(
        audit.errors.map((issue) => issue.code),
        isNot(anyOf(contains('DUPLICATE_TYPE'), contains('DUPLICATE_KEY'))),
      );
      expect(audit.errors, isEmpty, reason: audit.toJson().toString());
    });

    test('registry health report summarizes audit and capabilities', () {
      _registerAllBundles();

      final report = chartRegistryHealthReport(registeredOnly: true);
      final json = report.toJson();

      expect(report.isHealthy, isTrue);
      expect(report.audit.errors, isEmpty);
      expect(report.capabilityCount, ChartRegistry.registeredEnums.length);
      expect(report.payloadContractCount, report.capabilityCount);
      expect(report.apiContractCount, ChartApiContracts.all.length);
      expect(report.switchGroups, isNotEmpty);
      expect(
        report.shapeCounts[ChartSeriesDataShape.cartesian],
        greaterThan(0),
      );
      expect(report.featureCounts['tooltip'], greaterThan(0));
      expect(report.payloadStrategyCounts['dataFields'], greaterThan(0));
      expect(
        report.payloadFeatureCounts['shorthandCollections'],
        greaterThan(0),
      );
      expect(report.apiContractUsageCounts['cartesian'], greaterThan(0));
      expect(report.apiContractUsageCounts['statistical'], greaterThan(0));
      expect(report.apiFieldCategoryCounts['display'], greaterThan(0));
      expect(report.apiFieldCategoryCounts['interaction'], greaterThan(0));
      expect(json['isHealthy'], isTrue);
      expect(json['shapeCounts'], isA<Map<String, dynamic>>());
      expect(json['capabilities'], isA<List>());
      expect(json['payloadContracts'], isA<List>());
      expect(json['apiContracts'], isA<List>());
      expect(json['switchGroups'], isA<List>());
      expect(json['apiContractCount'], ChartApiContracts.all.length);
      expect(json['payloadStrategyCounts'], isA<Map<String, dynamic>>());
      expect(json['apiContractUsageCounts'], isA<Map<String, dynamic>>());
      expect(json['apiFieldCategoryCounts'], isA<Map<String, dynamic>>());

      (json['featureCounts'] as Map)['tooltip'] = -1;
      (json['payloadStrategyCounts'] as Map)['dataFields'] = -1;
      (json['payloadFeatureCounts'] as Map)['shorthandCollections'] = -1;
      (json['apiContractUsageCounts'] as Map)['cartesian'] = -1;
      (json['apiFieldCategoryCounts'] as Map)['display'] = -1;
      expect(report.featureCounts['tooltip'], greaterThan(0));
      expect(report.payloadStrategyCounts['dataFields'], greaterThan(0));
      expect(
        report.payloadFeatureCounts['shorthandCollections'],
        greaterThan(0),
      );
      expect(report.apiContractUsageCounts['cartesian'], greaterThan(0));
      expect(report.apiFieldCategoryCounts['display'], greaterThan(0));
    });

    test('capability metadata can be built from a concrete registration', () {
      final line = chartCapabilitiesForRegistration(lineRegistration);

      expect(line.isRegistered, isFalse);
      expect(line.description, 'Line chart family');
      expect(line.aliases, contains('sparkline'));
      expect(line.tags, contains('line'));
    });

    test('registry generation changes when registrations change', () {
      final start = ChartRegistry.generation;

      ChartRegistry.register(lineRegistration);
      final afterRegister = ChartRegistry.generation;
      expect(afterRegister, greaterThan(start));

      ChartRegistry.register(lineRegistration);
      expect(ChartRegistry.generation, afterRegister);

      ChartRegistry.registerAll([sparklineRegistration]);
      final afterRegisterAll = ChartRegistry.generation;
      expect(afterRegisterAll, greaterThan(afterRegister));

      ChartRegistry.registerAll([sparklineRegistration]);
      expect(ChartRegistry.generation, afterRegisterAll);

      ChartRegistry.unregister(ChartType.sparkline);
      final afterUnregister = ChartRegistry.generation;
      expect(afterUnregister, greaterThan(afterRegisterAll));

      final snapshot = ChartRegistry.snapshot();
      ChartRegistry.restore(snapshot);
      expect(ChartRegistry.generation, greaterThan(afterUnregister));
    });

    test('capability metadata can be built from a concrete registration', () {
      final capability = chartCapabilitiesForRegistration(
        sparklineRegistration,
      );

      expect(capability.type, ChartType.sparkline);
      expect(capability.typeString, 'sparkline');
      expect(capability.apiContract, ChartApiContracts.cartesian);
      expect(capability.toJson(), containsPair('apiContract', 'cartesian'));
      expect(capability.toJson(), containsPair('apiFamily', 'cartesian'));
      expect(capability.description, 'Sparkline chart');
      expect(capability.tags, contains('trend'));
      expect(capability.isRegistered, isFalse);
    });

    test('chart types map to stable API contract families', () {
      expect(
        chartApiContractForType(ChartType.bar),
        ChartApiContracts.cartesian,
      );
      expect(
        chartApiContractForType(ChartType.timeline),
        ChartApiContracts.temporal,
      );
      expect(
        chartApiContractForType(ChartType.candlestick),
        ChartApiContracts.financial,
      );
      expect(
        chartApiContractForType(ChartType.treemap),
        ChartApiContracts.hierarchyFlow,
      );
      expect(
        chartApiContractForType(ChartType.heatmap),
        ChartApiContracts.densitySpatial,
      );
      expect(chartApiContractForType(ChartType.radar), ChartApiContracts.polar);
      expect(
        chartApiContractForType(ChartType.rocCurve),
        ChartApiContracts.statistical,
      );
      expect(
        chartApiContractForType(ChartType.custom),
        ChartApiContracts.optionConfig,
      );

      final unresolved = [
        for (final capability in availableChartCapabilities(
          registeredOnly: false,
        ))
          if (capability.type != ChartType.custom &&
              capability.apiContract == ChartApiContracts.optionConfig)
            capability.typeString,
      ];
      expect(unresolved, isEmpty);
    });

    test('registration audit detects duplicate types and keys', () {
      final bundle = RegistrationBundle(
        name: 'duplicate_test',
        description: 'Intentional duplicate registrations for audit coverage',
        registrations: [lineRegistration, lineRegistration],
      );

      final audit = auditRegistrationBundle(bundle);

      expect(audit.hasErrors, isTrue);
      expect(
        audit.errors.any((issue) => issue.code == 'DUPLICATE_TYPE'),
        isTrue,
      );
      expect(
        audit.errors.any((issue) => issue.code == 'DUPLICATE_KEY'),
        isTrue,
      );
    });

    test('registration audit detects normalized key collisions', () {
      final bundle = RegistrationBundle(
        name: 'normalized_key_collision_test',
        description: 'Intentional normalized alias collision coverage',
        registrations: [
          ChartRegistration(
            type: ChartType.line,
            typeString: 'line',
            aliases: const ['foo-bar'],
            fromJson: lineRegistration.fromJson,
          ),
          ChartRegistration(
            type: ChartType.area,
            typeString: 'area',
            aliases: const ['foo_bar'],
            fromJson: areaRegistration.fromJson,
          ),
        ],
      );

      final audit = auditRegistrationBundle(bundle);

      expect(audit.hasErrors, isFalse);
      expect(
        audit.warnings.any((issue) => issue.code == 'NORMALIZED_KEY_COLLISION'),
        isTrue,
      );
    });

    test('registration audit detects legacy enum registration drift', () {
      final bundle = RegistrationBundle(
        name: 'legacy_registration_test',
        description: 'Intentional legacy registration coverage',
        registrations: [
          largeScaleAreaRegistration,
          ChartRegistration(
            type: ChartType.bigdata,
            typeString: 'bigdata',
            fromJson: largeScaleAreaRegistration.fromJson,
          ),
        ],
      );

      final audit = auditRegistrationBundle(bundle);
      final errorCodes = audit.errors.map((issue) => issue.code).toSet();

      expect(errorCodes, contains('LEGACY_REGISTRATION_TYPE'));
      expect(errorCodes, contains('DUPLICATE_CANONICAL_TYPE'));
      expect(errorCodes, contains('TYPE_STRING_MISMATCH'));
    });

    test('canonical type strings win over aliases regardless of order', () {
      ChartRegistry.register(sparklineRegistration);
      ChartRegistry.register(lineRegistration);

      var resolved = ChartRegistry.resolve(const {
        'type': 'sparkline',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });
      expect(resolved, isA<SparklineChartConfig>());

      ChartRegistry.clear();
      ChartRegistry.register(lineRegistration);
      ChartRegistry.register(sparklineRegistration);

      resolved = ChartRegistry.resolve(const {
        'type': 'sparkline',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });
      expect(resolved, isA<SparklineChartConfig>());
    });

    test('normalized type strings resolve aliases and canonical keys', () {
      _registerAllBundles();

      final lineArea = ChartRegistry.resolve(const {
        'type': 'line-area',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });
      expect(lineArea.series.single.data, [1, 2, 3]);
      expect(
        ChartRegistry.registrationForString('line-area')?.type,
        ChartType.lineArea,
      );
      expect(
        ChartRegistry.registrationForString('line area')?.type,
        ChartType.lineArea,
      );
      expect(
        ChartRegistry.isRegisteredString('stacked-horizontal-bar'),
        isTrue,
      );

      final horizontal = ChartRegistry.resolve(const {
        'type': 'horizontal-bar',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });
      expect(horizontal.series.single.data, [1, 2, 3]);
      expect(
        ChartRegistry.registrationForString('horizontal-bar')?.type,
        ChartType.horizontalBar,
      );
    });

    test('legacy enum aliases resolve through active registrations', () {
      _registerAllBundles();

      expect(ChartRegistry.isRegistered(ChartType.bigdata), isTrue);
      expect(
        ChartRegistry.registrationForType(ChartType.bigdata)?.type,
        ChartType.largeScaleArea,
      );
      expect(
        ChartRegistry.registrationForType(ChartType.spiderline)?.type,
        ChartType.polarLine,
      );
      expect(
        ChartRegistry.registrationForType(ChartType.alignedlabels)?.type,
        ChartType.pieLabelAlign,
      );
      expect(
        ChartRegistry.registrationForType(ChartType.richlabelpie)?.type,
        ChartType.pieSpecialLabel,
      );
      expect(
        ChartRegistry.registrationForType(ChartType.dualaxes)?.type,
        ChartType.multiXAxes,
      );
      expect(
        ChartRegistry.registrationForType(ChartType.lineStyleItem)?.typeString,
        chartTypeToString(ChartType.lineStyleItem),
      );

      final resolved = ChartRegistry.resolveByType(ChartType.bigdata, const {
        'type': 'bigdata',
        'series': [
          {
            'data': [
              [0, 1],
              [1, 2],
            ],
          },
        ],
      });
      expect(resolved.type, ChartType.largeScaleArea);
    });

    test('unregister does not remove another chart canonical key', () {
      ChartRegistry.register(sparklineRegistration);
      ChartRegistry.register(lineRegistration);
      ChartRegistry.unregister(ChartType.line);

      expect(ChartRegistry.isRegistered(ChartType.line), isFalse);
      expect(ChartRegistry.isRegisteredString('sparkline'), isTrue);
      final resolved = ChartRegistry.resolve(const {
        'type': 'sparkline',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });
      expect(resolved, isA<SparklineChartConfig>());
    });

    test('unregister restores alias owner when canonical chart is removed', () {
      ChartRegistry.register(lineRegistration);
      ChartRegistry.register(sparklineRegistration);

      expect(
        ChartRegistry.registrationForString('sparkline')?.type,
        ChartType.sparkline,
      );
      expect(
        ChartRegistry.resolve(const {
          'type': 'sparkline',
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        }),
        isA<SparklineChartConfig>(),
      );

      ChartRegistry.unregister(ChartType.sparkline);

      expect(ChartRegistry.isRegistered(ChartType.sparkline), isFalse);
      expect(
        ChartRegistry.registrationForString('sparkline')?.type,
        ChartType.line,
      );
      final resolved = ChartRegistry.resolve(const {
        'type': 'sparkline',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });
      expect(resolved.type, ChartType.line);
    });

    test('snapshot and restore isolate temporary registrations', () {
      ChartRegistry.register(lineRegistration);
      final snapshot = ChartRegistry.snapshot();

      ChartRegistry.register(sparklineRegistration);
      expect(ChartRegistry.isRegistered(ChartType.sparkline), isTrue);
      expect(
        ChartRegistry.registrationForString('sparkline')?.type,
        ChartType.sparkline,
      );

      ChartRegistry.restore(snapshot);

      expect(snapshot.count, 1);
      expect(ChartRegistry.isRegistered(ChartType.line), isTrue);
      expect(ChartRegistry.isRegistered(ChartType.sparkline), isFalse);
      expect(
        ChartRegistry.registrationForString('sparkline')?.type,
        ChartType.line,
      );
    });

    test('withRegistrations restores after sync and async scopes', () async {
      ChartRegistry.register(lineRegistration);

      final resolved = ChartRegistry.withRegistrations(
        [sparklineRegistration],
        () {
          expect(ChartRegistry.isRegistered(ChartType.sparkline), isTrue);
          return ChartRegistry.resolve(const {
            'type': 'sparkline',
            'series': [
              {
                'data': [1, 2, 3],
              },
            ],
          });
        },
      );

      expect(resolved, isA<SparklineChartConfig>());
      expect(ChartRegistry.isRegistered(ChartType.sparkline), isFalse);
      expect(
        ChartRegistry.registrationForString('sparkline')?.type,
        ChartType.line,
      );

      final count = await ChartRegistry.withRegistrationsAsync([
        sparklineRegistration,
      ], () async => ChartRegistry.count);

      expect(count, 2);
      expect(ChartRegistry.count, 1);
      expect(ChartRegistry.isRegistered(ChartType.sparkline), isFalse);
    });

    test('withRegistrations restores after thrown errors', () {
      ChartRegistry.register(lineRegistration);

      expect(
        () => ChartRegistry.withRegistrations([sparklineRegistration], () {
          expect(ChartRegistry.isRegistered(ChartType.sparkline), isTrue);
          throw StateError('boom');
        }),
        throwsStateError,
      );

      expect(ChartRegistry.count, 1);
      expect(ChartRegistry.isRegistered(ChartType.line), isTrue);
      expect(ChartRegistry.isRegistered(ChartType.sparkline), isFalse);
    });

    test('withRegistrations rejects Future-returning bodies', () {
      ChartRegistry.register(lineRegistration);

      expect(
        () => ChartRegistry.withRegistrations([
          sparklineRegistration,
        ], () => Future<int>.value(ChartRegistry.count)),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('withRegistrationsAsync'),
          ),
        ),
      );

      expect(ChartRegistry.count, 1);
      expect(ChartRegistry.isRegistered(ChartType.line), isTrue);
      expect(ChartRegistry.isRegistered(ChartType.sparkline), isFalse);
    });

    test('resolves new chart configs from JSON', () {
      _registerAllBundles();

      final cases = <MapEntry<Map<String, dynamic>, Type>>[
        MapEntry(const {
          'type': 'combo',
          'categories': ['Q1', 'Q2'],
          'series': [
            {
              'name': 'Revenue',
              'seriesType': 'bar',
              'data': [10, 20],
            },
          ],
        }, ComboChartConfig),
        MapEntry(const {
          'type': 'bullet',
          'series': [
            {
              'data': [
                {'label': 'A', 'value': 10, 'target': 12, 'max': 20},
              ],
            },
          ],
        }, BulletChartConfig),
        MapEntry(const {
          'type': 'histogram',
          'series': [
            {
              'data': [10, 20, 30],
            },
          ],
        }, HistogramChartConfig),
        MapEntry(const {
          'type': 'lollipop',
          'categories': ['A'],
          'series': [
            {
              'data': [10],
            },
          ],
        }, LollipopChartConfig),
        MapEntry(const {
          'type': 'sparkline',
          'series': [
            {
              'data': [1, 2, 3],
            },
          ],
        }, SparklineChartConfig),
        MapEntry(const {
          'type': 'kagi',
          'series': [
            {
              'data': [100, 101, 102],
            },
          ],
        }, KagiChartConfig),
        MapEntry(const {
          'type': 'renko',
          'series': [
            {
              'data': [100, 101, 102],
            },
          ],
        }, RenkoChartConfig),
        MapEntry(const {
          'type': 'macd',
          'series': [
            {
              'data': [
                100,
                101,
                102,
                103,
                104,
                105,
                106,
                107,
                108,
                109,
                110,
                111,
                112,
                113,
                114,
                115,
                116,
                117,
                118,
                119,
                120,
                121,
                122,
                123,
                124,
                125,
                126,
                127,
                128,
                129,
              ],
            },
          ],
        }, MacdChartConfig),
        MapEntry(const {
          'type': 'ridgeline',
          'categories': ['G1'],
          'series': [
            {
              'data': [
                [1, 2, 3],
              ],
            },
          ],
        }, RidgelineChartConfig),
        MapEntry(const {
          'type': 'strip',
          'categories': ['G1'],
          'series': [
            {
              'data': [
                [1, 2, 3],
              ],
            },
          ],
        }, StripChartConfig),
        MapEntry(const {
          'type': 'errorbar',
          'categories': ['A'],
          'series': [
            {
              'data': [
                {'mean': 0.5, 'lower': 0.4, 'upper': 0.6},
              ],
            },
          ],
        }, ErrorBarChartConfig),
        MapEntry(const {
          'type': 'network',
          'series': [
            {
              'nodes': [
                {'id': 'A', 'name': 'A'},
              ],
              'links': [],
            },
          ],
        }, NetworkChartConfig),
        MapEntry(const {
          'type': 'radial',
          'series': [
            {
              'data': [
                {'label': 'KPI', 'value': 60, 'max': 100},
              ],
            },
          ],
        }, RadialChartConfig),
        MapEntry(const {
          'type': 'timeline',
          'series': [
            {
              'data': [
                {'date': '2026-03-03', 'label': 'Start'},
              ],
            },
          ],
        }, TimelineChartConfig),
        MapEntry(const {
          'type': 'wordcloud',
          'series': [
            {
              'data': [
                {'text': 'Flutter', 'weight': 10},
              ],
            },
          ],
        }, WordcloudChartConfig),
        MapEntry(const {
          'type': 'calendar',
          'year': 2026,
          'series': [
            {
              'data': [
                {'date': '2026-03-03', 'value': 1},
              ],
            },
          ],
        }, CalendarChartConfig),
        MapEntry(const {
          'type': 'parallel',
          'axes': ['A', 'B'],
          'series': [
            {
              'data': [
                [1, 2],
              ],
            },
          ],
        }, ParallelChartConfig),
        MapEntry(const {
          'type': 'violin',
          'categories': ['G1'],
          'series': [
            {
              'data': [
                [1, 2, 3],
              ],
            },
          ],
        }, ViolinChartConfig),
        MapEntry(const {
          'type': 'barbackground',
          'categories': ['A'],
          'series': [
            {
              'name': 'S',
              'data': [10],
            },
          ],
        }, BarBackgroundChartConfig),
        MapEntry(const {
          'type': 'linegradient',
          'xLabels': ['A', 'B'],
          'series': [
            {
              'name': 'S',
              'data': [1, 2],
            },
          ],
        }, LineGradientChartConfig),
        MapEntry(const {
          'type': 'halfdonut',
          'value': 40,
          'max': 100,
        }, HalfDonutChartConfig),
        MapEntry(const {
          'type': 'choropleth',
          'series': [
            {
              'regions': [
                {
                  'id': 'A',
                  'name': 'A',
                  'value': 10,
                  'polygon': [
                    [-125, 49],
                    [-95, 49],
                    [-95, 25],
                    [-125, 25],
                  ],
                },
              ],
            },
          ],
        }, ChoroplethChartConfig),
        MapEntry(const {
          'type': 'slope',
          'categories': ['A', 'B'],
          'series': [
            {
              'name': 'Before',
              'data': [10, 20],
            },
            {
              'name': 'After',
              'data': [12, 18],
            },
          ],
        }, SlopeChartConfig),
        MapEntry(const {
          'type': 'dumbbell',
          'categories': ['A', 'B'],
          'series': [
            {
              'name': 'Min',
              'data': [10, 20],
            },
            {
              'name': 'Max',
              'data': [18, 30],
            },
          ],
        }, DumbbellChartConfig),
        MapEntry(const {
          'type': 'areabump',
          'xLabels': ['Q1', 'Q2'],
          'series': [
            {
              'name': 'Alpha',
              'ranks': [1, 2],
            },
            {
              'name': 'Beta',
              'ranks': [2, 1],
            },
          ],
        }, AreaBumpChartConfig),
        MapEntry(const {
          'type': 'rainfall',
          'categories': ['Jan', 'Feb'],
          'series': [
            {
              'name': 'Rain',
              'data': [10, 12],
            },
          ],
        }, RainfallChartConfig),
      ];

      for (final entry in cases) {
        final config = BaseChartConfig.fromJson(entry.key);
        expect(config.runtimeType, entry.value);
      }
    });

    test('resolves aliases for new chart types', () {
      _registerAllBundles();

      expect(
        BaseChartConfig.fromJson(const {'type': 'mixed'}).type,
        ChartType.combo,
      );
      expect(
        BaseChartConfig.fromJson(const {'type': 'ridge'}).type,
        ChartType.ridgeline,
      );
      expect(
        BaseChartConfig.fromJson(const {'type': 'dotplot'}).type,
        ChartType.strip,
      );
      expect(
        BaseChartConfig.fromJson(const {'type': 'error_bar'}).type,
        ChartType.errorBar,
      );
      expect(
        BaseChartConfig.fromJson(const {'type': 'dotrange'}).type,
        ChartType.dumbbell,
      );
      expect(
        BaseChartConfig.fromJson(const {'type': 'bump'}).type,
        ChartType.areaBump,
      );
    });

    test('graph and radial configs preserve payloads for signatures', () {
      _registerAllBundles();

      final networkA =
          BaseChartConfig.fromJson(const {
                'type': 'network',
                'series': [
                  {
                    'nodes': [
                      {'id': 'A', 'name': 'API', 'size': 12},
                    ],
                    'links': [],
                  },
                ],
              })
              as NetworkChartConfig;
      final networkB =
          BaseChartConfig.fromJson(const {
                'type': 'network',
                'series': [
                  {
                    'nodes': [
                      {'id': 'A', 'name': 'API', 'size': 18},
                    ],
                    'links': [],
                  },
                ],
              })
              as NetworkChartConfig;

      expect((networkA.toJson()['series'] as List).first['nodes'], isNotEmpty);
      expect(
        ChartDataSignature.fromConfig(networkA).hash,
        isNot(ChartDataSignature.fromConfig(networkB).hash),
      );

      final radialA =
          BaseChartConfig.fromJson(const {
                'type': 'radial',
                'series': [
                  {
                    'data': [
                      {'label': 'KPI', 'value': 60, 'max': 100},
                    ],
                  },
                ],
              })
              as RadialChartConfig;
      final radialB =
          BaseChartConfig.fromJson(const {
                'type': 'radial',
                'series': [
                  {
                    'data': [
                      {'label': 'KPI', 'value': 61, 'max': 100},
                    ],
                  },
                ],
              })
              as RadialChartConfig;

      expect((radialA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect(
        ChartDataSignature.fromConfig(radialA).hash,
        isNot(ChartDataSignature.fromConfig(radialB).hash),
      );
    });

    test('timeline and wordcloud configs preserve payloads for signatures', () {
      _registerAllBundles();

      final timelineA =
          BaseChartConfig.fromJson(const {
                'type': 'timeline',
                'series': [
                  {
                    'data': [
                      {'date': '2026-Q1', 'label': 'Start'},
                    ],
                  },
                ],
              })
              as TimelineChartConfig;
      final timelineB =
          BaseChartConfig.fromJson(const {
                'type': 'timeline',
                'series': [
                  {
                    'data': [
                      {
                        'date': '2026-Q1',
                        'label': 'Start',
                        'detail': 'Updated',
                      },
                    ],
                  },
                ],
              })
              as TimelineChartConfig;

      expect((timelineA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect(
        ChartDataSignature.fromConfig(timelineA).hash,
        isNot(ChartDataSignature.fromConfig(timelineB).hash),
      );

      final wordcloudA =
          BaseChartConfig.fromJson(const {
                'type': 'wordcloud',
                'series': [
                  {
                    'data': [
                      {'text': 'Flutter', 'weight': 10},
                    ],
                  },
                ],
              })
              as WordcloudChartConfig;
      final wordcloudB =
          BaseChartConfig.fromJson(const {
                'type': 'wordcloud',
                'series': [
                  {
                    'data': [
                      {'text': 'Flutter', 'weight': 11},
                    ],
                  },
                ],
              })
              as WordcloudChartConfig;

      expect((wordcloudA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect(
        ChartDataSignature.fromConfig(wordcloudA).hash,
        isNot(ChartDataSignature.fromConfig(wordcloudB).hash),
      );
    });

    test('trading configs normalize unsafe numeric settings', () {
      _registerAllBundles();

      final renko =
          BaseChartConfig.fromJson({
                'type': 'renko',
                'brickSize': 0,
                'series': [
                  {
                    'data': [100, 101, 102],
                  },
                ],
              })
              as RenkoChartConfig;
      expect(renko.brickSize, 1);

      final kagi =
          BaseChartConfig.fromJson({
                'type': 'kagi',
                'reversalPct': -4,
                'series': [
                  {
                    'data': [100, 101, 98, 105],
                  },
                ],
              })
              as KagiChartConfig;
      expect(kagi.reversalPct, 4);

      final macd =
          BaseChartConfig.fromJson({
                'type': 'macd',
                'fast': 26,
                'slow': 12,
                'signal': 0,
                'series': [
                  {'data': List.generate(40, (i) => 100 + i)},
                ],
              })
              as MacdChartConfig;
      expect(macd.fast, 26);
      expect(macd.slow, 27);
      expect(macd.signal, 9);
    });

    test('ChartFactory autoNormalizePayload sanitizes trading JSON', () {
      _registerAllBundles();

      final cfg =
          ChartFactory.fromJson({
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
              }, autoNormalizePayload: true)
              as RenkoChartConfig;

      expect(cfg.brickSize, 1);
      expect(cfg.prices, [100, 101, 102, 103]);
    });

    test('ChartFactory autoNormalizePayload accepts shorthand flow JSON', () {
      _registerAllBundles();

      final cfg = ChartFactory.fromJson({
        'type': 'sankey',
        'nodes': [
          {'id': 'source', 'name': 'Source'},
          {'id': 'target', 'name': 'Target'},
        ],
        'links': [
          {'source': 'source', 'target': 'target', 'value': 8},
        ],
      }, autoNormalizePayload: true);
      final series = cfg.toJson()['series'] as List;
      final firstSeries = series.first as Map;

      expect(firstSeries['nodes'], hasLength(2));
      expect(firstSeries['links'], hasLength(1));
    });

    test('ChartFactory can opt out of trading payload sanitation', () {
      _registerAllBundles();

      final cfg =
          ChartFactory.fromJson(
                {
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
                sanitizeTradingPayload: false,
              )
              as RenkoChartConfig;

      expect(cfg.brickSize, 1);
      expect(cfg.prices, [100, 103]);
    });

    test('throws when chart type is not registered', () {
      ChartRegistry.clear();

      expect(
        () => BaseChartConfig.fromJson(const {'type': 'combo'}),
        throwsA(isA<UnregisteredChartTypeException>()),
      );
    });

    test('unregistered chart type error suggests nearby registered types', () {
      _registerAllBundles();

      expect(
        () => BaseChartConfig.fromJson(const {'type': 'linne'}),
        throwsA(
          isA<UnregisteredChartTypeException>().having(
            (error) => error.suggestions,
            'suggestions',
            contains('line'),
          ),
        ),
      );
    });

    test(
      'non-string chart type fails with registry exception, not TypeError',
      () {
        _registerAllBundles();

        expect(
          () => BaseChartConfig.fromJson(const {'type': 123}),
          throwsA(
            isA<UnregisteredChartTypeException>().having(
              (error) => error.requestedType,
              'requestedType',
              '123',
            ),
          ),
        );
      },
    );
  });
}
