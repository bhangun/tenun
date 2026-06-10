import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  test('JSON option schemas aggregate cross-cutting payload options', () {
    expect(ChartJsonOptionSchemas.all, hasLength(3));
    expect(
      ChartJsonOptionSchemas.byName('runtimePerformancePolicy'),
      isNotNull,
    );
    expect(
      ChartJsonOptionSchemas.byName('runtime performance policy')!.name,
      'runtimePerformancePolicy',
    );
    expect(
      ChartJsonOptionSchemas.byName('payload-normalization')!.name,
      'payloadNormalization',
    );
    expect(
      ChartJsonOptionSchemas.byName('diagnosticFallback')!.acceptedContainers,
      contains('diagnostics.fallbackOptions'),
    );
    expect(
      ChartJsonOptionSchemas.byName('payloadNormalization')!.acceptedContainers,
      contains('diagnostics.normalizationOptions'),
    );
    expect(
      ChartJsonOptionPaths.normalizeContainer(r'$.diagnostics.fallbackOptions'),
      'diagnostics.fallbackOptions',
    );
    expect(
      ChartJsonOptionPaths.sameContainer(
        r'$.diagnostics.fallbackOptions',
        'diagnostics.fallbackOptions',
      ),
      true,
    );
    expect(
      ChartJsonOptionPaths.fieldPath(
        r'$.diagnostics.fallbackOptions',
        'showErrorDetails',
      ),
      'diagnostics.fallbackOptions.showErrorDetails',
    );
    expect(
      ChartJsonOptionPaths.fieldPath(r'$', 'autoNormalizePayload'),
      'autoNormalizePayload',
    );
    expect(
      ChartJsonOptionPaths.segments(
        r'$.diagnostics.fallbackOptions.showErrorDetails',
      ),
      ['diagnostics', 'fallbackOptions', 'showErrorDetails'],
    );
    expect(
      ChartJsonOptionPaths.jsonPointer(
        r'$.diagnostics.fallbackOptions.showErrorDetails',
      ),
      '/diagnostics/fallbackOptions/showErrorDetails',
    );
    expect(ChartJsonOptionPaths.jsonPointer(r'$'), '');
    expect(
      ChartJsonOptionPaths.jsonPointer(r'$.diagnostics.fallback/options.a~b'),
      '/diagnostics/fallback~1options/a~0b',
    );
    expect(
      ChartJsonOptionPaths.fragment(
        r'$.diagnostics.fallbackOptions.showErrorDetails',
        true,
      ),
      {
        'diagnostics': {
          'fallbackOptions': {'showErrorDetails': true},
        },
      },
    );
    expect(
      ChartJsonOptionPaths.mergeFragments([
        {
          'diagnostics': {
            'fallbackOptions': {'showErrorDetails': true},
          },
        },
        {
          'diagnostics': {
            'fallbackOptions': {'maxQuickFixes': 3},
          },
        },
      ]),
      {
        'diagnostics': {
          'fallbackOptions': {'showErrorDetails': true, 'maxQuickFixes': 3},
        },
      },
    );
    expect(
      ChartJsonOptionSchemas.runtimePerformancePolicy.fields
          .expand((field) => field['aliases'] as List<dynamic>)
          .cast<String>(),
      contains('largeDataPointThreshold'),
    );
    expect(
      ChartJsonOptionSchemas.payloadNormalization.fields.map(
        (field) => field['canonicalField'],
      ),
      contains('autoNormalizePayload'),
    );
    expect(
      ChartJsonOptionSchemas.runtimePerformancePolicy.canonicalFields,
      contains('largeDatasetPointThreshold'),
    );
    expect(
      ChartJsonOptionSchemas.runtimePerformancePolicy.canonicalFieldFor(
        'large-data-point-threshold',
      ),
      'largeDatasetPointThreshold',
    );
    expect(
      ChartJsonOptionSchemas.runtimePerformancePolicy.fieldJsonFor(
        'large data point threshold',
      ),
      containsPair('canonicalField', 'largeDatasetPointThreshold'),
    );
    final runtimeFieldReference = ChartJsonOptionSchemas
        .runtimePerformancePolicy
        .fieldReferenceFor('large data point threshold')!;
    expect(runtimeFieldReference.schemaName, 'runtimePerformancePolicy');
    expect(runtimeFieldReference.canonicalField, 'largeDatasetPointThreshold');
    expect(runtimeFieldReference.aliases, contains('largeDataPointThreshold'));
    expect(
      runtimeFieldReference.preferredContainer,
      'runtimePerformancePolicy',
    );
    expect(
      runtimeFieldReference.toJson(),
      containsPair('schemaName', 'runtimePerformancePolicy'),
    );
    expect(
      ChartJsonOptionSchemas.diagnosticFallback.supportsField(
        'show-error-details',
      ),
      true,
    );
    expect(
      ChartJsonOptionSchemas.forField(
        'default threshold',
        containerPath: r'$.diagnostics.normalizationOptions',
      ).single.name,
      'payloadNormalization',
    );
    expect(
      ChartJsonOptionSchemas.schemaForField('showErrorDetails')!.name,
      'diagnosticFallback',
    );
    expect(
      ChartJsonOptionSchemas.canonicalFieldFor(
        'largeDataPointThreshold',
        schemaName: 'runtime performance policy',
      ),
      'largeDatasetPointThreshold',
    );
    expect(
      ChartJsonOptionSchemas.fieldJsonFor('default-threshold')!,
      containsPair('canonicalField', 'defaultThreshold'),
    );
    expect(
      ChartJsonOptionSchemas.fieldReferenceFor(
        'show-error-details',
      )!.schemaName,
      'diagnosticFallback',
    );
    expect(
      ChartJsonOptionSchemas.fieldReferences(
        containerPath: r'$.diagnostics.normalizationOptions',
      ).map((field) => field.canonicalField),
      containsAll([
        'autoNormalizePayload',
        'dropUnsupportedSampling',
        'defaultThreshold',
      ]),
    );
    final fallbackCompletion = ChartJsonOptionCompletions.first(
      fieldName: 'show-error-details',
      containerPath: r'$.diagnostics.fallbackOptions',
    )!;
    expect(fallbackCompletion.schemaName, 'diagnosticFallback');
    expect(
      fallbackCompletion.jsonPath,
      'diagnostics.fallbackOptions.showErrorDetails',
    );
    expect(fallbackCompletion.insertText, 'showErrorDetails');
    expect(fallbackCompletion.exampleValue, true);
    expect(fallbackCompletion.valueSnippet, 'true');
    expect(fallbackCompletion.entrySnippet, '"showErrorDetails": true');
    expect(fallbackCompletion.validateValue(false).isValid, true);
    final invalidFallbackValue = fallbackCompletion.validateValue('yes');
    expect(invalidFallbackValue.isValid, false);
    expect(
      invalidFallbackValue.toJson(),
      containsPair('canonicalField', 'showErrorDetails'),
    );
    expect(fallbackCompletion.examplePayloadFragment, {
      'diagnostics': {
        'fallbackOptions': {'showErrorDetails': true},
      },
    });
    expect(fallbackCompletion.payloadFragment(value: false), {
      'diagnostics': {
        'fallbackOptions': {'showErrorDetails': false},
      },
    });
    expect(fallbackCompletion.payloadFragment(value: null, hasValue: true), {
      'diagnostics': {
        'fallbackOptions': {'showErrorDetails': null},
      },
    });
    final basePayload = {
      'type': 'line',
      'series': [
        {
          'data': [1, 2, 3],
        },
      ],
      'diagnostics': {
        'fallbackOptions': {'title': 'Existing fallback'},
      },
    };
    expect(fallbackCompletion.applyToPayload(basePayload), {
      'type': 'line',
      'series': [
        {
          'data': [1, 2, 3],
        },
      ],
      'diagnostics': {
        'fallbackOptions': {
          'title': 'Existing fallback',
          'showErrorDetails': true,
        },
      },
    });
    expect(basePayload['diagnostics'], {
      'fallbackOptions': {'title': 'Existing fallback'},
    });
    expect(
      ChartJsonOptionCompletions.payloadFragment(
        containerPath: r'$.diagnostics.fallbackOptions',
        fieldName: 'show-error-details',
        values: {'show-error-details': false},
      ),
      {
        'diagnostics': {
          'fallbackOptions': {'showErrorDetails': false},
        },
      },
    );
    expect(
      ChartJsonOptionCompletions.validateValues(
        containerPath: r'$.diagnostics.fallbackOptions',
        fieldName: 'show-error-details',
        values: {'show-error-details': false},
      ).single.isValid,
      true,
    );
    final invalidThreshold = ChartJsonOptionCompletions.validateValues(
      schemaName: 'payload normalization',
      fieldName: 'default-threshold',
      preferredOnly: true,
      values: {'defaultThreshold': -1},
    ).single;
    expect(invalidThreshold.isValid, false);
    expect(
      invalidThreshold.toJson(),
      containsPair('canonicalField', 'defaultThreshold'),
    );
    expect(
      ChartJsonOptionCompletions.payloadFragment(
        schemaName: 'runtime performance policy',
        fieldName: 'largeDataPointThreshold',
        preferredOnly: true,
        values: {'largeDataPointThreshold': 24000},
      ),
      {
        'runtimePerformancePolicy': {'largeDatasetPointThreshold': 24000},
      },
    );
    expect(
      ChartJsonOptionCompletions.payloadFragment(
        containerPath: r'$.diagnostics.fallbackOptions',
        fieldName: 'show-error-details',
      ),
      {
        'diagnostics': {
          'fallbackOptions': {'showErrorDetails': true},
        },
      },
    );
    expect(
      ChartJsonOptionCompletions.applyToPayload(
        basePayload,
        containerPath: r'$.diagnostics.fallbackOptions',
        fieldName: 'show-error-details',
        values: {'diagnostics.fallbackOptions.showErrorDetails': false},
      ),
      {
        'type': 'line',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
        'diagnostics': {
          'fallbackOptions': {
            'title': 'Existing fallback',
            'showErrorDetails': false,
          },
        },
      },
    );
    final patchReport = ChartJsonOptionCompletions.patchReport(
      basePayload,
      containerPath: r'$.diagnostics.fallbackOptions',
      fieldName: 'show-error-details',
      values: {
        'diagnostics.fallbackOptions.showErrorDetails': false,
        'unusedOption': 10,
      },
    );
    expect(patchReport.resultPayload, {
      'type': 'line',
      'series': [
        {
          'data': [1, 2, 3],
        },
      ],
      'diagnostics': {
        'fallbackOptions': {
          'title': 'Existing fallback',
          'showErrorDetails': false,
        },
      },
    });
    expect(patchReport.payloadFragment, {
      'diagnostics': {
        'fallbackOptions': {'showErrorDetails': false},
      },
    });
    expect(patchReport.validPayloadFragment, patchReport.payloadFragment);
    expect(patchReport.validResultPayload, patchReport.resultPayload);
    expect(patchReport.entries.single.canonicalField, 'showErrorDetails');
    expect(
      patchReport.entries.single.jsonPointer,
      '/diagnostics/fallbackOptions/showErrorDetails',
    );
    expect(patchReport.entries.single.hasPreviousValue, false);
    expect(patchReport.entries.single.previousValue, isNull);
    expect(
      patchReport.entries.single.changeKind,
      ChartJsonOptionPatchChangeKind.added,
    );
    expect(patchReport.entries.single.changesValue, true);
    expect(patchReport.validEntries.single.canonicalField, 'showErrorDetails');
    expect(patchReport.invalidEntries, isEmpty);
    expect(patchReport.hasChanges, true);
    expect(patchReport.changedFields, ['showErrorDetails']);
    expect(patchReport.addedFields, ['showErrorDetails']);
    expect(patchReport.updatedFields, isEmpty);
    expect(patchReport.unchangedFields, isEmpty);
    expect(
      patchReport.operations.single.kind,
      ChartJsonOptionPatchOperationKind.add,
    );
    expect(
      patchReport.operations.single.jsonPointer,
      '/diagnostics/fallbackOptions/showErrorDetails',
    );
    expect(patchReport.operations.single.toJsonPatchOperation(), {
      'op': 'add',
      'path': '/diagnostics/fallbackOptions/showErrorDetails',
      'value': false,
    });
    expect(patchReport.jsonPatchOperations, [
      {
        'op': 'add',
        'path': '/diagnostics/fallbackOptions/showErrorDetails',
        'value': false,
      },
    ]);
    expect(
      patchReport.validJsonPatchOperations,
      patchReport.jsonPatchOperations,
    );
    expect(patchReport.operations.single.changesValue, true);
    expect(patchReport.operations.single.isValid, true);
    expect(
      patchReport.validOperations.single.canonicalField,
      'showErrorDetails',
    );
    expect(
      patchReport.changedOperations.single.jsonPath,
      'diagnostics.fallbackOptions.showErrorDetails',
    );
    expect(patchReport.validAppliedFields, ['showErrorDetails']);
    expect(patchReport.invalidFields, isEmpty);
    expect(patchReport.entries.single.usedOverride, true);
    expect(
      patchReport.entries.single.valueKey,
      'diagnostics.fallbackOptions.showErrorDetails',
    );
    expect(patchReport.entries.single.overwritesExistingValue, false);
    expect(patchReport.ignoredValueKeys, ['unusedOption']);
    expect(patchReport.ignoredValues, {'unusedOption': 10});
    expect(patchReport.hasIssues, true);
    expect(patchReport.hasErrors, false);
    expect(patchReport.canApplySafely, true);
    expect(patchReport.hasInvalidValues, false);
    expect(patchReport.warnings.single.code, 'ignoredValueKey');
    expect(
      patchReport.warnings.single.severity,
      ChartJsonOptionPatchIssueSeverity.warning,
    );
    expect(patchReport.warnings.single.valueKey, 'unusedOption');
    expect(patchReport.warnings.single.toJson(), containsPair('value', 10));
    expect(
      patchReport.toJson(),
      containsPair('appliedFields', ['showErrorDetails']),
    );
    expect(
      patchReport.toJson(),
      containsPair('ignoredValues', {'unusedOption': 10}),
    );
    expect(
      patchReport.toJson()['operations'],
      contains(containsPair('op', ChartJsonOptionPatchOperationKind.add.name)),
    );
    expect(
      patchReport.toJson()['operations'],
      contains(
        containsPair(
          'jsonPointer',
          '/diagnostics/fallbackOptions/showErrorDetails',
        ),
      ),
    );
    expect(
      patchReport.toJson(),
      containsPair('jsonPatchOperations', patchReport.jsonPatchOperations),
    );
    expect(
      ChartJsonOptionCompletions.validPayloadFragment(
        containerPath: r'$.diagnostics.fallbackOptions',
        fieldName: 'show-error-details',
        values: {'diagnostics.fallbackOptions.showErrorDetails': false},
      ),
      patchReport.validPayloadFragment,
    );

    final overwriteReport = ChartJsonOptionCompletions.patchReport(
      basePayload,
      containerPath: r'$.diagnostics.fallbackOptions',
      fieldName: 'title',
      values: {'title': 'Updated fallback'},
    );
    expect(overwriteReport.entries.single.overwritesExistingValue, true);
    expect(overwriteReport.entries.single.hasPreviousValue, true);
    expect(overwriteReport.entries.single.previousValue, 'Existing fallback');
    expect(
      overwriteReport.entries.single.changeKind,
      ChartJsonOptionPatchChangeKind.updated,
    );
    expect(overwriteReport.entries.single.changesValue, true);
    expect(overwriteReport.overwrittenFields, ['title']);
    expect(overwriteReport.changedFields, ['title']);
    expect(overwriteReport.updatedFields, ['title']);
    expect(
      overwriteReport.operations.single.kind,
      ChartJsonOptionPatchOperationKind.replace,
    );
    expect(
      overwriteReport.operations.single.previousValue,
      'Existing fallback',
    );
    expect(overwriteReport.operations.single.toJsonPatchOperation(), {
      'op': 'replace',
      'path': '/diagnostics/fallbackOptions/title',
      'value': 'Updated fallback',
    });
    expect(overwriteReport.hasIssues, false);
    expect(
      overwriteReport.toJson()['entries'],
      contains(
        containsPair('changeKind', ChartJsonOptionPatchChangeKind.updated.name),
      ),
    );

    final unchangedReport = ChartJsonOptionCompletions.patchReport(
      basePayload,
      containerPath: r'$.diagnostics.fallbackOptions',
      fieldName: 'title',
      values: {'title': 'Existing fallback'},
    );
    expect(unchangedReport.entries.single.overwritesExistingValue, true);
    expect(unchangedReport.entries.single.hasPreviousValue, true);
    expect(unchangedReport.entries.single.previousValue, 'Existing fallback');
    expect(
      unchangedReport.entries.single.changeKind,
      ChartJsonOptionPatchChangeKind.unchanged,
    );
    expect(unchangedReport.entries.single.changesValue, false);
    expect(unchangedReport.hasChanges, false);
    expect(unchangedReport.changedFields, isEmpty);
    expect(unchangedReport.unchangedFields, ['title']);
    expect(
      unchangedReport.operations.single.kind,
      ChartJsonOptionPatchOperationKind.noop,
    );
    expect(unchangedReport.operations.single.changesValue, false);
    expect(unchangedReport.operations.single.toJsonPatchOperation(), isNull);
    expect(unchangedReport.changedOperations, isEmpty);
    expect(unchangedReport.jsonPatchOperations, isEmpty);
    expect(unchangedReport.resultPayload, basePayload);

    final invalidPatchReport = ChartJsonOptionCompletions.patchReport(
      basePayload,
      schemaName: 'payload normalization',
      fieldName: 'default-threshold',
      preferredOnly: true,
      values: {'defaultThreshold': -1},
    );
    expect(invalidPatchReport.hasInvalidValues, true);
    expect(invalidPatchReport.hasErrors, true);
    expect(invalidPatchReport.canApplySafely, false);
    expect(invalidPatchReport.validations.single.isValid, false);
    expect(invalidPatchReport.validEntries, isEmpty);
    expect(invalidPatchReport.operations.single.isValid, false);
    expect(
      invalidPatchReport.operations.single.kind,
      ChartJsonOptionPatchOperationKind.add,
    );
    expect(invalidPatchReport.validOperations, isEmpty);
    expect(invalidPatchReport.jsonPatchOperations, [
      {
        'op': 'add',
        'path': '/normalizationOptions/defaultThreshold',
        'value': -1,
      },
    ]);
    expect(invalidPatchReport.validJsonPatchOperations, isEmpty);
    expect(invalidPatchReport.changedOperations.single.isValid, false);
    expect(
      invalidPatchReport.invalidEntries.single.canonicalField,
      'defaultThreshold',
    );
    expect(invalidPatchReport.validAppliedFields, isEmpty);
    expect(invalidPatchReport.invalidFields, ['defaultThreshold']);
    expect(invalidPatchReport.addedFields, ['defaultThreshold']);
    expect(invalidPatchReport.payloadFragment, {
      'normalizationOptions': {'defaultThreshold': -1},
    });
    expect(invalidPatchReport.validPayloadFragment, isEmpty);
    expect(invalidPatchReport.resultPayload, {
      'type': 'line',
      'series': [
        {
          'data': [1, 2, 3],
        },
      ],
      'diagnostics': {
        'fallbackOptions': {'title': 'Existing fallback'},
      },
      'normalizationOptions': {'defaultThreshold': -1},
    });
    expect(invalidPatchReport.validResultPayload, basePayload);
    expect(
      ChartJsonOptionCompletions.applyValidToPayload(
        basePayload,
        schemaName: 'payload normalization',
        fieldName: 'default-threshold',
        preferredOnly: true,
        values: {'defaultThreshold': -1},
      ),
      basePayload,
    );
    expect(invalidPatchReport.errors.single.code, 'invalidValue');
    expect(
      invalidPatchReport.errors.single.jsonPointer,
      '/normalizationOptions/defaultThreshold',
    );
    expect(
      invalidPatchReport.errors.single.severity,
      ChartJsonOptionPatchIssueSeverity.error,
    );
    expect(
      invalidPatchReport.errors.single.toJson(),
      containsPair('canonicalField', 'defaultThreshold'),
    );
    expect(
      invalidPatchReport.errors.single.toJson(),
      containsPair('jsonPointer', '/normalizationOptions/defaultThreshold'),
    );
    expect(fallbackCompletion.preferred, false);
    expect(
      ChartJsonOptionCompletions.all(
        schemaName: 'runtime performance policy',
        fieldName: 'largeDataPointThreshold',
        preferredOnly: true,
      ).single.jsonPath,
      'runtimePerformancePolicy.largeDatasetPointThreshold',
    );
    expect(
      ChartJsonOptionCompletions.all(
        schemaName: 'runtime performance policy',
        fieldName: 'largeDataPointThreshold',
        preferredOnly: true,
      ).single.valueSnippet,
      '10000',
    );
    expect(
      ChartJsonOptionCompletions.json(
        containerPath: r'$.diagnostics.normalizationOptions',
        fieldName: 'default-threshold',
      ).single,
      containsPair(
        'jsonPath',
        'diagnostics.normalizationOptions.defaultThreshold',
      ),
    );
    expect(
      ChartJsonOptionCompletions.first(
        schemaName: 'diagnostic fallback',
        fieldName: 'preset',
        preferredOnly: true,
      )!.valueSnippet,
      '"production"',
    );
    expect(
      ChartJsonOptionValueHint.forKind('dataMode').toJson(),
      containsPair('jsonLiteral', '"auto"'),
    );
    expect(
      ChartJsonOptionSchemas.schemaJson().first,
      containsPair('name', 'runtimePerformancePolicy'),
    );
    expect(
      ChartJsonOptionSchemas.schemaJson().first,
      containsPair('examplePayload', isA<Map<String, dynamic>>()),
    );
    expect(
      ChartJsonOptionSchemas.schemaJson().first,
      containsPair('exampleChartPayload', isA<Map<String, dynamic>>()),
    );
    final schemaJson = ChartJsonOptionSchemas.runtimePerformancePolicy.toJson();
    (schemaJson['acceptedContainers'] as List).clear();
    (((schemaJson['fields'] as List).first as Map)['aliases'] as List).clear();
    ((schemaJson['examplePayload'] as Map)['diagnostics'] as Map).clear();
    ((schemaJson['exampleChartPayload'] as Map)['diagnostics'] as Map).clear();
    expect(
      ChartJsonOptionSchemas.runtimePerformancePolicy.acceptedContainers,
      contains('runtimePerformancePolicy'),
    );
    expect(
      ChartJsonOptionSchemas.runtimePerformancePolicy.fields
          .expand((field) => field['aliases'] as List<dynamic>)
          .cast<String>(),
      contains('largeDataPointThreshold'),
    );
    expect(
      ChartJsonOptionSchemas
          .runtimePerformancePolicy
          .examplePayload['diagnostics'],
      contains('performancePolicy'),
    );
    expect(
      ChartJsonOptionSchemas
          .runtimePerformancePolicy
          .exampleChartPayload['diagnostics'],
      contains('performancePolicy'),
    );

    final fieldJson = ChartJsonOptionSchemas.runtimePerformancePolicy
        .fieldJsonFor('largeDataPointThreshold')!;
    (fieldJson['aliases'] as List).clear();
    expect(
      ChartJsonOptionSchemas.runtimePerformancePolicy.fieldJsonFor(
        'largeDataPointThreshold',
      )!['aliases'],
      contains('largeDataPointThreshold'),
    );
    final staticFieldJson = ChartJsonOptionSchemas.fieldJsonFor(
      'largeDataPointThreshold',
      schemaName: 'runtimePerformancePolicy',
    )!;
    (staticFieldJson['aliases'] as List).clear();
    expect(
      ChartJsonOptionSchemas.fieldJsonFor(
        'largeDataPointThreshold',
        schemaName: 'runtimePerformancePolicy',
      )!['aliases'],
      contains('largeDataPointThreshold'),
    );

    final referenceJson = runtimeFieldReference.toJson();
    (referenceJson['acceptedContainers'] as List).clear();
    ((referenceJson['field'] as Map)['aliases'] as List).clear();
    expect(runtimeFieldReference.acceptedContainers, contains(r'$'));
    expect(runtimeFieldReference.aliases, contains('largeDataPointThreshold'));

    final completionJson = fallbackCompletion.toJson();
    (completionJson['aliases'] as List).clear();
    ((completionJson['examplePayloadFragment'] as Map)['diagnostics'] as Map)
        .clear();
    expect(fallbackCompletion.aliases, contains('showErrorDetails'));
    expect(
      fallbackCompletion.examplePayloadFragment['diagnostics'],
      contains('fallbackOptions'),
    );

    final dataModeHintJson = ChartJsonOptionValueHint.forKind(
      'dataMode',
    ).toJson();
    (dataModeHintJson['examples'] as List).clear();
    expect(
      ChartJsonOptionValueHint.forKind('dataMode').toJson()['examples'],
      contains('large'),
    );

    final runtimePolicyAliases = ChartRuntimePerformancePolicyFields.aliasesFor(
      'largeDatasetPointThreshold',
    );
    runtimePolicyAliases.clear();
    expect(
      ChartRuntimePerformancePolicyFields.aliasesFor(
        'largeDatasetPointThreshold',
      ),
      contains('largeDataPointThreshold'),
    );
    final runtimePolicySchemaJson =
        ChartRuntimePerformancePolicyFields.schemaJson().first;
    (runtimePolicySchemaJson['aliases'] as List).clear();
    expect(
      ChartRuntimePerformancePolicyFields.schemaJson().first['aliases'],
      contains('largeDataPointThreshold'),
    );
    expect(
      ChartJsonOptionSchemas.forContainer(
        'diagnostics.fallbackOptions',
      ).map((schema) => schema.name),
      contains('diagnosticFallback'),
    );
    expect(
      ChartJsonOptionSchemas.forContainer(
        r'$.diagnostics.normalizationOptions',
      ).map((schema) => schema.name),
      contains('payloadNormalization'),
    );
    expect(
      ChartJsonOptionSchemas.forContainer(r'$').map((schema) => schema.name),
      containsAll(['runtimePerformancePolicy', 'payloadNormalization']),
    );
    expect(
      ChartJsonOptionSchemas.acceptedContainers,
      contains('runtimeDiagnostics.performancePolicy'),
    );
    expect(
      ChartJsonOptionSchemas.examplePayloads()['diagnosticFallback']!,
      containsPair('diagnostics', isA<Map<String, dynamic>>()),
    );
    final examplePayloads = ChartJsonOptionSchemas.examplePayloads();
    ((examplePayloads['diagnosticFallback']!['diagnostics']
                as Map)['fallbackOptions']
            as Map)
        .clear();
    expect(
      (ChartJsonOptionSchemas.examplePayloads()['diagnosticFallback']!['diagnostics']
          as Map)['fallbackOptions'],
      containsPair('preset', 'production'),
    );
    expect(
      ChartJsonOptionSchemas.examplePayloadFor('diagnostic fallback')!,
      containsPair('diagnostics', isA<Map<String, dynamic>>()),
    );
    final examplePayload = ChartJsonOptionSchemas.examplePayloadFor(
      'diagnostic fallback',
    )!;
    (examplePayload['diagnostics'] as Map).clear();
    expect(
      ChartJsonOptionSchemas.examplePayloadFor(
        'diagnostic fallback',
      )!['diagnostics'],
      contains('fallbackOptions'),
    );
    expect(
      ChartJsonOptionSchemas.exampleChartPayloads()['payloadNormalization']!,
      containsPair('autoNormalizePayload', true),
    );
    final exampleChartPayloads = ChartJsonOptionSchemas.exampleChartPayloads();
    ((exampleChartPayloads['payloadNormalization']!['series'] as List).single
            as Map)
        .clear();
    expect(
      ((ChartJsonOptionSchemas.exampleChartPayloads()['payloadNormalization']!['series']
                  as List)
              .single
          as Map),
      containsPair('name', 'Traffic'),
    );
    expect(
      ChartJsonOptionSchemas.exampleChartPayloadFor('payload-normalization')!,
      containsPair('type', 'line'),
    );
    final exampleChartPayload = ChartJsonOptionSchemas.exampleChartPayloadFor(
      'payload-normalization',
    )!;
    ((exampleChartPayload['series'] as List).single as Map).clear();
    expect(
      ((ChartJsonOptionSchemas.exampleChartPayloadFor(
                    'payload-normalization',
                  )!['series']
                  as List)
              .single
          as Map),
      containsPair('name', 'Traffic'),
    );
    final sourceFragmentValue = {
      'items': [1, 2],
    };
    final fragment = ChartJsonOptionPaths.fragment(
      'diagnostics.extra',
      sourceFragmentValue,
    );
    (((fragment['diagnostics'] as Map)['extra'] as Map)['items'] as List).add(
      3,
    );
    expect(sourceFragmentValue['items'], [1, 2]);
    final emptyFragment = ChartJsonOptionPaths.fragment(r'$', {'x': 1});
    emptyFragment['mutated'] = true;
    expect(emptyFragment, containsPair('mutated', true));
    expect(
      ChartJsonOptionSchemas.schemaJsonForContainer(
        r'$.diagnostics.fallbackOptions',
      ).single,
      containsPair('name', 'diagnosticFallback'),
    );
    final schemaJsonWithoutExamples = ChartJsonOptionSchemas.schemaJson(
      includeExamplePayload: false,
      includeExampleChartPayload: false,
    );
    expect(
      schemaJsonWithoutExamples.first.containsKey('examplePayload'),
      false,
    );
    expect(
      schemaJsonWithoutExamples.first.containsKey('exampleChartPayload'),
      false,
    );

    final names = <String>{};
    ChartRegistry.withRegistrations(coreChartsBundle.registrations, () {
      for (final schema in ChartJsonOptionSchemas.all) {
        expect(names.add(schema.name), isTrue);
        expect(schema.fields, isNotEmpty);
        expect(schema.toJson()['fieldCount'], schema.fields.length);
        expect(schema.examplePayload, isNotEmpty);
        expect(schema.exampleChartPayload, isNotEmpty);

        final validation = ChartConfigValidator.validateJsonPayload(
          schema.exampleChartPayload,
        );
        expect(
          validation.isValid,
          isTrue,
          reason:
              '${schema.name} example chart payload should validate: '
              '${validation.errors.map((issue) => issue.toString()).join(', ')}',
        );
      }
    }, clearBefore: true);
  });
}
