import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  group('Chart type switching by series shape', () {
    setUp(() {
      ChartRegistry.clear();
      allChartsBundle.register();
    });

    test('suggests cartesian-compatible types for bar data', () {
      final json = <String, dynamic>{
        'type': 'bar',
        'xAxis': {
          'data': ['Jan', 'Feb', 'Mar'],
        },
        'series': [
          {
            'name': 'Revenue',
            'data': [10, 20, 30],
          },
        ],
      };

      final shape = inferSeriesDataShape(json);
      final compatible = compatibleChartTypesForJson(json);

      expect(shape, ChartSeriesDataShape.cartesian);
      expect(compatible, contains(ChartType.line));
      expect(compatible, contains(ChartType.area));
      expect(compatible, contains(ChartType.groupedBar));
    });

    test('exposes registered capabilities for cartesian charts', () {
      final line = chartCapabilitiesForType(ChartType.line);

      expect(line.typeString, 'line');
      expect(line.dataShape, ChartSeriesDataShape.cartesian);
      expect(line.isRegistered, isTrue);
      expect(line.supportsSampling, isTrue);
      expect(line.supportsZoom, isTrue);
      expect(line.supportsLegend, isTrue);
      expect(line.supportsTooltip, isTrue);
      expect(line.supportsRuntimeSwitching, isTrue);
      expect(line.tags, contains('line'));

      final json = line.toJson();
      (json['tags'] as List).add('mutated');
      (json['aliases'] as List).clear();
      expect(line.tags, contains('line'));
      expect(line.tags, isNot(contains('mutated')));
      expect(line.aliases, contains('sparkline'));
    });

    test('exposes hierarchical capabilities for drilldown charts', () {
      final treemap = chartCapabilitiesForType(ChartType.treemap);

      expect(treemap.dataShape, ChartSeriesDataShape.hierarchical);
      expect(treemap.supportsDrilldown, isTrue);
      expect(treemap.supportsSampling, isFalse);
      expect(treemap.supportsRuntimeSwitching, isTrue);
    });

    test('exposes payload contracts for shorthand collection payloads', () {
      final treemap = chartPayloadContractForType(ChartType.treemap);
      final sankey = chartPayloadContractForType(ChartType.sankey);
      final calendar = chartPayloadContractForType(ChartType.calendar);
      final nestedPie = chartPayloadContractForType(ChartType.nestedPie);
      final partitionPie = chartPayloadContractForType(ChartType.partitionPie);

      expect(treemap.dataShape, ChartSeriesDataShape.hierarchical);
      expect(treemap.seriesStrategy, ChartPayloadSeriesStrategy.dataFields);
      expect(treemap.dataFieldPriority, ['nodes', 'data']);
      expect(sankey.dataShape, ChartSeriesDataShape.flow);
      expect(sankey.seriesStrategy, ChartPayloadSeriesStrategy.nodeLink);
      expect(
        calendar.seriesStrategy,
        ChartPayloadSeriesStrategy.calendarDateValues,
      );
      expect(nestedPie.seriesStrategy, ChartPayloadSeriesStrategy.ringSlices);
      expect(
        partitionPie.seriesStrategy,
        ChartPayloadSeriesStrategy.partitionPie,
      );
      expect(treemap.supportsShorthandCollections, isTrue);
      final json = treemap.toJson();
      expect(json, containsPair('dataShape', 'hierarchical'));
      (json['dataFieldPriority'] as List).clear();
      expect(treemap.dataFieldPriority, ['nodes', 'data']);
    });

    test('payload contracts centralize series and external-model flags', () {
      final line = chartPayloadContractForType(ChartType.line);
      final gauge = chartPayloadContractForType(ChartType.gauge);
      final barRace = chartPayloadContractForType(ChartType.barRace);
      final indicator = chartPayloadContractForType(ChartType.indicator);
      final halfDonut = chartPayloadContractForType(ChartType.halfDonut);
      final treemap = chartPayloadContractForType(ChartType.treemap);

      expect(line.requiresSeries, isTrue);
      expect(line.usesExternalDataModel, isFalse);
      expect(gauge.requiresSeries, isFalse);
      expect(barRace.requiresSeries, isFalse);
      expect(indicator.requiresSeries, isFalse);
      expect(indicator.dataFieldPriority, ['value']);
      expect(halfDonut.requiresSeries, isFalse);
      expect(treemap.requiresSeries, isTrue);
      expect(treemap.usesExternalDataModel, isTrue);
    });

    test('classifies specialized registered chart shapes explicitly', () {
      final report = chartRegistryHealthReport(
        includeUnknownShapeWarnings: true,
      );

      expect(
        targetSeriesDataShape(ChartType.parallel),
        ChartSeriesDataShape.matrix,
      );
      expect(
        targetSeriesDataShape(ChartType.wordcloud),
        ChartSeriesDataShape.pieLike,
      );
      expect(
        targetSeriesDataShape(ChartType.indicator),
        ChartSeriesDataShape.radial,
      );
      expect(
        targetSeriesDataShape(ChartType.custom),
        ChartSeriesDataShape.unknown,
      );
      expect(
        report.audit.issues
            .where((issue) => issue.code == 'UNKNOWN_DATA_SHAPE')
            .map((issue) => issue.secondType),
        [ChartType.custom],
      );
    });

    test('infers declared specialized payload shapes', () {
      expect(
        inferSeriesDataShape(const {
          'type': 'parallel',
          'axes': ['Price', 'HP'],
          'series': [
            {
              'data': [
                [25000, 150],
              ],
            },
          ],
        }),
        ChartSeriesDataShape.matrix,
      );
      expect(
        inferSeriesDataShape(const {
          'type': 'wordcloud',
          'series': [
            {
              'data': [
                {'text': 'Flutter', 'weight': 95},
              ],
            },
          ],
        }),
        ChartSeriesDataShape.pieLike,
      );
      expect(
        inferSeriesDataShape(const {
          'type': 'indicator',
          'label': 'Revenue',
          'value': 42,
          'previousValue': 36,
          'unit': '%',
        }),
        ChartSeriesDataShape.radial,
      );
    });

    test('normalizes weighted wordcloud data when switching to pie', () {
      final switched = switchChartTypeForSeriesShape(const {
        'type': 'wordcloud',
        'series': [
          {
            'data': [
              {'text': 'Flutter', 'weight': 95},
              {'text': 'Dart', 'weight': 80},
            ],
          },
        ],
      }, targetType: ChartType.pie);
      final data = ((switched['series'] as List).first as Map)['data'] as List;

      expect(switched['type'], 'pie');
      expect(data.first, containsPair('name', 'Flutter'));
      expect(data.first, containsPair('value', 95));
      expect(data.last, containsPair('name', 'Dart'));
      expect(data.last, containsPair('value', 80));
    });

    test('allows scalar indicator payloads to switch within radial family', () {
      final result = trySwitchChartTypeForSeriesShape(const {
        'type': 'indicator',
        'label': 'Revenue',
        'value': 72,
        'previousValue': 60,
        'unit': '%',
      }, targetType: ChartType.gauge);

      expect(result.success, isTrue);
      expect(result.sourceShape, ChartSeriesDataShape.radial);
      expect(result.payload?['type'], 'gauge');
      expect(result.payload?['value'], 72);
    });

    test('suggests compatible types directly from a data shape', () {
      final compatible = compatibleChartTypesForShape(
        ChartSeriesDataShape.cartesian,
        registeredOnly: false,
      );

      expect(compatible, contains(ChartType.line));
      expect(compatible, contains(ChartType.area));
      expect(compatible, contains(ChartType.groupedBar));
      expect(compatible, contains(ChartType.sparkline));
      expect(compatible, isNot(contains(ChartType.treemap)));
    });

    test('legacy DataShapeAdapter delegates to registry-backed inference', () {
      final source = <String, dynamic>{
        'type': 'heatmap',
        'series': [
          {
            'data': [
              ['Mon', 'Morning', 4],
              ['Mon', 'Evening', 7],
            ],
          },
        ],
      };

      expect(inferSeriesDataShape(source), ChartSeriesDataShape.matrix);
      expect(DataShapeAdapter.inferShape(source), ChartSeriesDataShape.matrix);
      expect(
        DataShapeAdapter.compatibleTypes(source, registeredOnly: false),
        contains(ChartType.heatmap),
      );
    });

    test('infers shapes from nested JSON-like maps without dynamic values', () {
      final pointA = <String, Object?>{'x': 1, 'y': 2};
      final pointB = <String, Object?>{'x': 2, 'y': 4};
      final series = <String, Object?>{
        'name': 'Points',
        'data': [pointA, pointB],
      };
      final source = <String, dynamic>{
        'type': 'line',
        'series': [series],
      };

      expect(inferSeriesDataShape(source), ChartSeriesDataShape.cartesian);
      expect(compatibleChartTypesForJson(source), contains(ChartType.area));
    });

    test('infers pie label-value payloads as pie-like, not hierarchy', () {
      final source = <String, dynamic>{
        'type': 'pie',
        'series': [
          {
            'data': [
              {'name': 'A', 'value': 10},
              {'name': 'B', 'value': 20},
            ],
          },
        ],
      };

      final compatible = compatibleChartTypesForJson(source);

      expect(inferSeriesDataShape(source), ChartSeriesDataShape.pieLike);
      expect(compatible, contains(ChartType.donut));
      expect(compatible, isNot(contains(ChartType.treemap)));
    });

    test('infers leaf-only treemap payloads as hierarchy when declared', () {
      final source = <String, dynamic>{
        'type': 'treemap',
        'series': [
          {
            'data': [
              {'name': 'A', 'value': 10},
              {'name': 'B', 'value': 20},
            ],
          },
        ],
      };

      final compatible = compatibleChartTypesForJson(source);

      expect(inferSeriesDataShape(source), ChartSeriesDataShape.hierarchical);
      expect(compatible, contains(ChartType.sunburst));
      expect(compatible, isNot(contains(ChartType.pie)));
    });

    test('lists registered capabilities without duplicate chart types', () {
      final capabilities = registeredChartCapabilities();
      final types = capabilities.map((c) => c.type).toList();

      expect(capabilities.length, ChartRegistry.registeredEnums.length);
      expect(types.toSet().length, types.length);
      expect(types, contains(ChartType.line));
      expect(types, contains(ChartType.treemap));
    });

    test('registry exposes registration metadata by type and alias', () {
      final lineByType = ChartRegistry.registrationForType(ChartType.line);
      final groupedByAlias = ChartRegistry.registrationForString('grouped_bar');

      expect(lineByType?.typeString, 'line');
      expect(groupedByAlias?.type, ChartType.groupedBar);
    });

    test('switches bar json to line without losing series', () {
      final source = <String, dynamic>{
        'type': 'bar',
        'xAxis': {
          'data': ['Q1', 'Q2'],
        },
        'series': [
          {
            'name': 'Sales',
            'data': [30, 55],
          },
        ],
      };

      final switched = switchChartTypeForSeriesShape(
        source,
        targetType: ChartType.line,
      );

      expect(switched['type'], 'line');
      expect((switched['series'] as List).isNotEmpty, isTrue);
      expect((switched['series'] as List).first['data'], [30, 55]);
    });

    test('switches candlestick json to line using close prices', () {
      final source = <String, dynamic>{
        'type': 'candlestick',
        'series': [
          {
            'data': [
              {'date': 'D1', 'open': 10, 'high': 12, 'low': 9, 'close': 11},
              ['D2', 11, 14, 10, 13],
            ],
          },
        ],
      };

      final switched = TenunOption.fromJson(
        source,
      ).switchType(ChartType.line).toJson();

      expect(switched['type'], 'line');
      expect((switched['series'] as List).first['data'], [11.0, 13.0]);
      expect((switched['xAxis'] as Map)['data'], ['D1', 'D2']);
    });

    test(
      'switches cartesian json to candlestick with synthetic OHLC tuples',
      () {
        final source = <String, dynamic>{
          'type': 'line',
          'xAxis': {
            'data': ['D1', 'D2'],
          },
          'series': [
            {
              'name': 'Close',
              'data': [10, 20],
            },
          ],
        };

        final switched = DataShapeAdapter.adapt(source, ChartType.candlestick);

        expect(switched['type'], 'candlestick');
        final data = (switched['series'] as List).first['data'] as List;
        expect(data.first, [10.0, 10.2, 9.8, 10.0]);
        expect(data.last, [20.0, 20.4, 19.6, 20.0]);
        expect((switched['xAxis'] as Map)['data'], ['D1', 'D2']);
      },
    );

    test('switches flat cartesian data to treemap hierarchy', () {
      final source = <String, dynamic>{
        'type': 'bar',
        'xAxis': {
          'data': ['A', 'B', 'C'],
        },
        'series': [
          {
            'name': 'Volume',
            'data': [5, 7, 9],
          },
        ],
      };

      final switched = switchChartTypeForSeriesShape(
        source,
        targetType: ChartType.treemap,
        force: true,
      );

      expect(switched['type'], 'treemap');
      final series = switched['series'] as List;
      final data = (series.first as Map)['data'] as List;
      expect((data.first as Map)['name'], 'A');
      expect((data.first as Map)['value'], 5.0);
    });

    test('keeps hierarchy when switching treemap to sunburst', () {
      final source = <String, dynamic>{
        'type': 'treemap',
        'series': [
          {
            'data': [
              {
                'name': 'Tech',
                'value': 10,
                'children': [
                  {'name': 'A', 'value': 6},
                ],
              },
            ],
          },
        ],
      };

      final switched = switchChartTypeForSeriesShape(
        source,
        targetType: ChartType.sunburst,
      );

      expect(switched['type'], 'sunburst');
      final node =
          (((switched['series'] as List).first as Map)['data'] as List).first
              as Map;
      expect(node['children'], isNotNull);
    });

    test(
      'compatibleChartTypesForConfig infers shape from config series even when toJson is minimal',
      () {
        final cfg = SlopeChartConfig(
          columnLabels: const ['Before', 'After'],
          series: [
            Series(
              type: ChartType.line,
              name: 'Revenue',
              data: const [10.0, 15.0],
            ),
          ],
        );

        final compatible = compatibleChartTypesForConfig(
          cfg,
          registeredOnly: false,
        );

        expect(compatible, contains(ChartType.line));
        expect(compatible, contains(ChartType.groupedBar));
        expect(compatible, isNot(contains(ChartType.treemap)));
      },
    );

    test('ranks compatible switch targets using preferred order', () {
      final source = <String, dynamic>{
        'type': 'bar',
        'xAxis': {
          'data': ['Jan', 'Feb', 'Mar'],
        },
        'series': [
          {
            'name': 'Revenue',
            'data': [10, 20, 30],
          },
        ],
      };

      final ranked = rankedCompatibleChartTypesForJson(
        source,
        preferredOrder: const [ChartType.pie, ChartType.area, ChartType.line],
      );

      expect(ranked.first, ChartType.area);
      expect(ranked, isNot(contains(ChartType.bar)));
    });

    test('returns switch options with capabilities and preview payloads', () {
      final source = <String, dynamic>{
        'type': 'bar',
        'xAxis': {
          'data': ['Jan', 'Feb', 'Mar'],
        },
        'series': [
          {
            'name': 'Revenue',
            'data': [10, 20, 30],
          },
        ],
      };

      final options = chartSwitchOptionsForJson(
        source,
        preferredOrder: const [ChartType.area, ChartType.line],
      );

      expect(options.first.type, ChartType.area);
      expect(options.first.rank, 1);
      expect(options.first.isCurrentType, isFalse);
      expect(options.first.sourceShape, ChartSeriesDataShape.cartesian);
      expect(options.first.capabilities.supportsSampling, isTrue);
      expect(options.first.previewPayload['type'], 'area');
      expect(options.first.reason, contains('cartesian'));

      final json = options.first.toJson(includePreviewPayload: true);
      ((((json['previewPayload'] as Map)['series'] as List).single
                  as Map)['data']
              as List)
          .add(99);
      expect(
        (((options.first.previewPayload['series'] as List).single
                as Map)['data']
            as List),
        [10, 20, 30],
      );
    });

    test('checks direct switch compatibility without throwing', () {
      final source = <String, dynamic>{
        'type': 'bar',
        'series': [
          {
            'data': [10, 20, 30],
          },
        ],
      };

      final result = chartSwitchCompatibilityForJson(
        source,
        targetType: ChartType.line,
        registeredOnly: false,
      );

      expect(result.isCompatible, isTrue);
      expect(result.canSwitch, isTrue);
      expect(result.requiresForce, isFalse);
      expect(result.sourceShape, ChartSeriesDataShape.cartesian);
      expect(result.targetShape, ChartSeriesDataShape.cartesian);
      expect(result.reason, contains('directly'));
      expect(result.toJson(), containsPair('canSwitch', true));
      expect(
        DataShapeAdapter.compatibility(source, ChartType.line).canSwitch,
        isTrue,
      );
    });

    test('checks supported force conversion before switching', () {
      final source = <String, dynamic>{
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

      final result = chartSwitchCompatibilityForJson(
        source,
        targetType: ChartType.treemap,
        registeredOnly: false,
      );

      expect(result.isCompatible, isFalse);
      expect(result.forceConversionAvailable, isTrue);
      expect(result.canSwitch, isTrue);
      expect(result.requiresForce, isTrue);
      expect(result.reason, contains('requires force conversion'));
    });

    test('reports unsafe switch targets without throwing', () {
      final source = <String, dynamic>{'type': 'custom', 'value': 1};

      final result = chartSwitchCompatibilityForJson(
        source,
        targetType: ChartType.line,
        registeredOnly: false,
      );

      expect(result.isCompatible, isFalse);
      expect(result.forceConversionAvailable, isFalse);
      expect(result.canSwitch, isFalse);
      expect(result.sourceShape, ChartSeriesDataShape.unknown);
      expect(result.reason, contains('Cannot infer source data shape'));
    });

    test('switch options can include current type', () {
      final source = <String, dynamic>{
        'type': 'line',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      };

      final options = chartSwitchOptionsForJson(
        source,
        preferredOrder: const [ChartType.line, ChartType.area],
        includeCurrentType: true,
      );

      expect(options.first.type, ChartType.line);
      expect(options.first.isCurrentType, isTrue);
      expect(options.first.previewPayload['type'], 'line');
      expect(options.first.toJson(), containsPair('isCurrentType', true));
    });

    test('switch options are empty for unknown data shape', () {
      final options = chartSwitchOptionsForJson(const {
        'type': 'custom',
        'value': 1,
      }, registeredOnly: false);

      expect(options, isEmpty);
    });

    test('auto-switch chooses first ranked compatible target', () {
      final source = <String, dynamic>{
        'type': 'bar',
        'xAxis': {
          'data': ['Q1', 'Q2'],
        },
        'series': [
          {
            'name': 'Sales',
            'data': [30, 55],
          },
        ],
      };

      final switched = switchChartTypeForSeriesShapeAuto(
        source,
        preferredOrder: const [ChartType.pie, ChartType.area, ChartType.line],
      );

      expect(switched['type'], 'area');
      expect((switched['series'] as List).isNotEmpty, isTrue);
      expect((switched['series'] as List).first['data'], [30, 55]);
    });

    test('auto-switch throws when shape has no alternative target', () {
      final source = <String, dynamic>{
        'type': 'choropleth',
        'series': [
          {
            'data': [
              {'region': 'ID', 'score': 12},
            ],
          },
        ],
      };

      expect(
        () => switchChartTypeForSeriesShapeAuto(source),
        throwsA(isA<StateError>()),
      );

      final keepCurrent = switchChartTypeForSeriesShapeAuto(
        source,
        includeCurrentType: true,
      );
      expect(keepCurrent['type'], 'choropleth');
    });

    test(
      'try-switch preserves runtime controls for top-level data payloads',
      () {
        final source = <String, dynamic>{
          'type': 'bar',
          'categories': ['A', 'B', 'C'],
          'data': [10, 20, 30],
          'legend': {'show': true},
          'tooltip': {'show': true},
          'sampling': {'enabled': true, 'threshold': 500},
          'dataMode': 'large',
          'zoom': {'start': 0.2, 'end': 0.8},
          'dataZoom': {'enabled': true},
          'drilldown': {'enabled': true},
        };

        final result = trySwitchChartTypeForSeriesShape(
          source,
          targetType: ChartType.area,
        );

        expect(result.success, isTrue);
        expect(result.usedForceConversion, isFalse);
        expect(result.payload, isNotNull);
        expect(result.payload!['type'], 'area');
        expect((result.payload!['series'] as List).first['data'], [10, 20, 30]);
        expect((result.payload!['xAxis'] as Map)['data'], ['A', 'B', 'C']);
        expect(result.isLossless, isTrue);
        expect(result.requiresForce, isFalse);
        expect(result.sourceShape, ChartSeriesDataShape.cartesian);
        expect(result.targetShape, ChartSeriesDataShape.cartesian);
        expect(result.preservedRuntimeKeys, containsAll(['legend', 'tooltip']));
        expect(result.preservedRuntimeKeys, containsAll(['zoom', 'dataZoom']));
        expect(result.preservedRuntimeKeys, contains('drilldown'));
        expect(result.toJson(), containsPair('success', true));
        expect(result.toJson(), containsPair('isLossless', true));

        final diagnosticJson = result.toJson(includePayload: true);
        ((((diagnosticJson['payload'] as Map)['series'] as List).single
                    as Map)['data']
                as List)
            .add(99);
        expect(
          (((result.payload!['series'] as List).single as Map)['data'] as List),
          [10, 20, 30],
        );
      },
    );

    test(
      'try-switch reports force conversion requirements without throwing',
      () {
        final source = <String, dynamic>{
          'type': 'bar',
          'labels': ['North', 'South'],
          'data': ['12.5', '19.75'],
        };

        final blocked = trySwitchChartTypeForSeriesShape(
          source,
          targetType: ChartType.treemap,
        );

        expect(blocked.success, isFalse);
        expect(blocked.payload, isNull);
        expect(blocked.compatibility.requiresForce, isTrue);
        expect(blocked.requiresForce, isTrue);

        final forced = trySwitchChartTypeForSeriesShape(
          source,
          targetType: ChartType.treemap,
          force: true,
        );

        expect(forced.success, isTrue);
        expect(forced.usedForceConversion, isTrue);
        expect(forced.isLossless, isFalse);
        expect(forced.requiresForce, isTrue);
        expect(forced.payload!['type'], 'treemap');
        final data =
            ((forced.payload!['series'] as List).first as Map)['data'] as List;
        expect((data.first as Map)['name'], 'North');
        expect((data.first as Map)['value'], 12.5);
      },
    );

    test('force switching still rejects unsupported cross-shape targets', () {
      final source = <String, dynamic>{'type': 'custom', 'value': 1};

      expect(
        () => switchChartTypeForSeriesShape(
          source,
          targetType: ChartType.line,
          force: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Cannot infer source data shape'),
          ),
        ),
      );

      final result = DataShapeAdapter.tryAdapt(
        source,
        ChartType.line,
        force: true,
        registeredOnly: false,
      );

      expect(result.success, isFalse);
      expect(result.payload, isNull);
      expect(result.isLossless, isFalse);
      expect(result.usedForceConversion, isFalse);
    });

    test('infers top-level hierarchy shorthand for treemap and sunburst', () {
      final source = <String, dynamic>{
        'type': 'treemap',
        'data': [
          {
            'name': 'Cloud',
            'value': '42',
            'children': [
              {'name': 'Compute', 'value': 28},
            ],
          },
        ],
      };

      expect(inferSeriesDataShape(source), ChartSeriesDataShape.hierarchical);
      expect(compatibleChartTypesForJson(source), contains(ChartType.sunburst));

      final switched = switchChartTypeForSeriesShape(
        source,
        targetType: ChartType.sunburst,
      );

      expect(switched['type'], 'sunburst');
      final node =
          (((switched['series'] as List).first as Map)['data'] as List).first
              as Map;
      expect(node['name'], 'Cloud');
      expect(node['children'], isNotEmpty);
    });

    test(
      'try-auto-switch selects ranked target and preserves runtime controls',
      () {
        final source = <String, dynamic>{
          'type': 'bar',
          'categories': ['Q1', 'Q2'],
          'data': [30, 55],
          'legend': {'show': true},
          'tooltip': {'show': true},
          'viewport': {'start': 0.1, 'end': 0.9},
        };

        final result = trySwitchChartTypeForSeriesShapeAuto(
          source,
          preferredOrder: const [ChartType.pie, ChartType.area, ChartType.line],
        );

        expect(result.success, isTrue);
        expect(result.selectedType, ChartType.area);
        expect(result.selectedOption?.type, ChartType.area);
        expect(result.payload, isNotNull);
        expect(result.payload!['type'], 'area');
        expect(result.keptCurrentType, isFalse);
        expect(result.preservedRuntimeKeys, containsAll(['legend', 'tooltip']));
        expect(result.preservedRuntimeKeys, contains('viewport'));
        expect(
          result.options.map((option) => option.type),
          contains(ChartType.line),
        );
        expect(result.toJson(), containsPair('selectedType', 'area'));

        final diagnosticJson = result.toJson(includePayload: true);
        ((((diagnosticJson['payload'] as Map)['series'] as List).single
                    as Map)['data']
                as List)
            .add(99);
        expect(
          (((result.payload!['series'] as List).single as Map)['data'] as List),
          [30, 55],
        );

        final option = TenunOption.fromJson(source);
        expect(
          option
              .trySwitchAuto(
                preferredOrder: const [ChartType.area, ChartType.line],
              )
              .selectedType,
          ChartType.area,
        );
      },
    );

    test('try-auto-switch reports no target without throwing', () {
      final source = <String, dynamic>{
        'type': 'choropleth',
        'series': [
          {
            'data': [
              {'region': 'ID', 'score': 12},
            ],
          },
        ],
      };

      final blocked = trySwitchChartTypeForSeriesShapeAuto(source);

      expect(blocked.success, isFalse);
      expect(blocked.selectedType, isNull);
      expect(blocked.payload, isNull);
      expect(blocked.sourceShape, ChartSeriesDataShape.geospatial);
      expect(blocked.message, contains('geospatial'));

      final keepCurrent = trySwitchChartTypeForSeriesShapeAuto(
        source,
        includeCurrentType: true,
      );

      expect(keepCurrent.success, isTrue);
      expect(keepCurrent.selectedType, ChartType.choropleth);
      expect(keepCurrent.keptCurrentType, isTrue);
      expect(keepCurrent.payload!['type'], 'choropleth');
    });

    test('validated switching reports render-safe adapted payloads', () {
      final source = <String, dynamic>{
        'type': 'bar',
        'xAxis': {
          'data': ['Jan', 'Feb', 'Mar'],
        },
        'series': [
          {
            'name': 'Revenue',
            'data': [10, 20, 30],
          },
        ],
      };

      final result = DataShapeAdapter.tryAdaptValidated(source, ChartType.area);

      expect(result.success, isTrue);
      expect(result.isRenderSafe, isTrue);
      expect(result.validation, isNotNull);
      expect(result.validation!.isValid, isTrue);
      expect(result.validationErrors, isEmpty);
      expect(result.payload!['type'], 'area');
      expect(result.renderSafetyMessage, contains('validation passed'));
      expect(result.toJson(), containsPair('isRenderSafe', true));
      expect(result.toJson(), contains('validation'));

      final optionResult = TenunOption.fromJson(
        source,
      ).trySwitchTypeValidated(ChartType.line);

      expect(optionResult.success, isTrue);
      expect(optionResult.isRenderSafe, isTrue);
      expect(optionResult.payload!['type'], 'line');
    });

    test('validated switching keeps compatibility failures non-throwing', () {
      final source = <String, dynamic>{'type': 'custom', 'value': 1};

      final result = DataShapeAdapter.tryAdaptValidated(
        source,
        ChartType.line,
        force: true,
        registeredOnly: false,
      );

      expect(result.success, isFalse);
      expect(result.isRenderSafe, isFalse);
      expect(result.validation, isNull);
      expect(result.payload, isNull);
      expect(result.renderSafetyMessage, contains('Cannot infer source'));
      expect(result.toJson(), isNot(contains('validation')));
    });

    test('validated auto-switch validates selected payload', () {
      final source = <String, dynamic>{
        'type': 'bar',
        'categories': ['Q1', 'Q2', 'Q3'],
        'data': [30, 55, 42],
      };

      final result = DataShapeAdapter.tryAdaptAutoValidated(
        source,
        preferredOrder: const [ChartType.area, ChartType.line],
      );

      expect(result.success, isTrue);
      expect(result.selectedType, ChartType.area);
      expect(result.isRenderSafe, isTrue);
      expect(result.validation, isNotNull);
      expect(result.validation!.isValid, isTrue);
      expect(result.payload!['type'], 'area');

      final optionResult = TenunOption.fromJson(source).trySwitchAutoValidated(
        preferredOrder: const [ChartType.line, ChartType.area],
      );

      expect(optionResult.success, isTrue);
      expect(optionResult.selectedType, ChartType.line);
      expect(optionResult.isRenderSafe, isTrue);
    });
  });
}
