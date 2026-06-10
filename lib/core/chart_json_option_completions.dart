import 'chart_json_option_completion.dart';
import 'chart_json_option_field_reference.dart';
import 'chart_json_option_patch_report.dart';
import 'chart_json_option_paths.dart';
import 'chart_json_option_schemas.dart';
import 'chart_json_option_value_hint.dart';
import 'json_value.dart';

class ChartJsonOptionCompletions {
  const ChartJsonOptionCompletions._();

  static List<ChartJsonOptionCompletion> all({
    String? schemaName,
    String? containerPath,
    String? fieldName,
    bool preferredOnly = false,
  }) {
    final List<ChartJsonOptionSchema> schemas;
    if (schemaName != null) {
      final schema = ChartJsonOptionSchemas.byName(schemaName);
      if (schema == null) return const <ChartJsonOptionCompletion>[];
      schemas = [schema];
    } else {
      schemas = containerPath == null
          ? ChartJsonOptionSchemas.all
          : ChartJsonOptionSchemas.forContainer(containerPath);
    }

    return [
      for (final schema in schemas)
        if (containerPath == null || schema.acceptsContainer(containerPath))
          for (final reference in _referencesFor(schema, fieldName))
            for (final container in _containersFor(schema, containerPath))
              if (!preferredOnly ||
                  ChartJsonOptionPaths.sameContainer(
                    container,
                    reference.preferredContainer,
                  ))
                ChartJsonOptionCompletion.fromReference(
                  reference,
                  containerPath: container,
                ),
    ];
  }

  static List<Map<String, dynamic>> json({
    String? schemaName,
    String? containerPath,
    String? fieldName,
    bool preferredOnly = false,
  }) {
    return [
      for (final completion in all(
        schemaName: schemaName,
        containerPath: containerPath,
        fieldName: fieldName,
        preferredOnly: preferredOnly,
      ))
        completion.toJson(),
    ];
  }

  static Map<String, dynamic> payloadFragment({
    String? schemaName,
    String? containerPath,
    String? fieldName,
    bool preferredOnly = false,
    Map<String, Object?> values = const <String, Object?>{},
  }) {
    return ChartJsonOptionPaths.mergeFragments([
      for (final completion in all(
        schemaName: schemaName,
        containerPath: containerPath,
        fieldName: fieldName,
        preferredOnly: preferredOnly,
      ))
        _payloadFragmentFor(completion, values),
    ]);
  }

  static Map<String, dynamic> applyToPayload(
    Map<String, dynamic> payload, {
    String? schemaName,
    String? containerPath,
    String? fieldName,
    bool preferredOnly = false,
    Map<String, Object?> values = const <String, Object?>{},
  }) {
    return patchReport(
      payload,
      schemaName: schemaName,
      containerPath: containerPath,
      fieldName: fieldName,
      preferredOnly: preferredOnly,
      values: values,
    ).resultPayload;
  }

  static Map<String, dynamic> validPayloadFragment({
    String? schemaName,
    String? containerPath,
    String? fieldName,
    bool preferredOnly = false,
    Map<String, Object?> values = const <String, Object?>{},
  }) {
    return patchReport(
      const <String, dynamic>{},
      schemaName: schemaName,
      containerPath: containerPath,
      fieldName: fieldName,
      preferredOnly: preferredOnly,
      values: values,
    ).validPayloadFragment;
  }

  static Map<String, dynamic> applyValidToPayload(
    Map<String, dynamic> payload, {
    String? schemaName,
    String? containerPath,
    String? fieldName,
    bool preferredOnly = false,
    Map<String, Object?> values = const <String, Object?>{},
  }) {
    return patchReport(
      payload,
      schemaName: schemaName,
      containerPath: containerPath,
      fieldName: fieldName,
      preferredOnly: preferredOnly,
      values: values,
    ).validResultPayload;
  }

  static ChartJsonOptionPayloadPatchReport patchReport(
    Map<String, dynamic> payload, {
    String? schemaName,
    String? containerPath,
    String? fieldName,
    bool preferredOnly = false,
    Map<String, Object?> values = const <String, Object?>{},
  }) {
    final fragments = <Map<String, dynamic>>[];
    final validFragments = <Map<String, dynamic>>[];
    final entries = <ChartJsonOptionPatchEntry>[];
    final usedValueKeys = <String>{};

    for (final completion in all(
      schemaName: schemaName,
      containerPath: containerPath,
      fieldName: fieldName,
      preferredOnly: preferredOnly,
    )) {
      final override = _valueOverrideFor(completion, values);
      if (override.sourceKey != null) usedValueKeys.add(override.sourceKey!);

      final effectiveValue = override.hasValue
          ? override.value
          : completion.exampleValue;
      final fragment = completion.payloadFragment(
        value: override.value,
        hasValue: override.hasValue,
      );
      final validation = completion.validateValue(effectiveValue);
      final previousValue = _payloadValueAtPath(payload, completion.jsonPath);
      fragments.add(fragment);
      if (validation.isValid) validFragments.add(fragment);
      entries.add(
        ChartJsonOptionPatchEntry(
          schemaName: completion.schemaName,
          canonicalField: completion.canonicalField,
          jsonPath: completion.jsonPath,
          value: JsonValue.clone(effectiveValue),
          previousValue: previousValue.hasValue
              ? JsonValue.clone(previousValue.value)
              : null,
          usedOverride: override.hasValue,
          valueKey: override.sourceKey,
          hasPreviousValue: previousValue.hasValue,
          overwritesExistingValue: previousValue.hasValue,
          changeKind: _patchChangeKind(
            previousValue: previousValue,
            nextValue: effectiveValue,
          ),
          validation: validation,
        ),
      );
    }

    final ignoredValueKeys = [
      for (final key in values.keys)
        if (!usedValueKeys.contains(key)) key,
    ];
    final payloadFragment = ChartJsonOptionPaths.mergeFragments(fragments);
    final validPayloadFragment = ChartJsonOptionPaths.mergeFragments(
      validFragments,
    );
    return ChartJsonOptionPayloadPatchReport(
      entries: entries,
      ignoredValueKeys: ignoredValueKeys,
      ignoredValues: {
        for (final key in ignoredValueKeys) key: JsonValue.clone(values[key]),
      },
      payloadFragment: payloadFragment,
      resultPayload: ChartJsonOptionPaths.mergeFragment(
        payload,
        payloadFragment,
      ),
      validPayloadFragment: validPayloadFragment,
      validResultPayload: ChartJsonOptionPaths.mergeFragment(
        payload,
        validPayloadFragment,
      ),
    );
  }

  static List<ChartJsonOptionValueValidation> validateValues({
    String? schemaName,
    String? containerPath,
    String? fieldName,
    bool preferredOnly = false,
    required Map<String, Object?> values,
  }) {
    return [
      for (final completion in all(
        schemaName: schemaName,
        containerPath: containerPath,
        fieldName: fieldName,
        preferredOnly: preferredOnly,
      ))
        if (_valueOverrideFor(completion, values) case final override
            when override.hasValue)
          completion.validateValue(override.value),
    ];
  }

  static ChartJsonOptionCompletion? first({
    String? schemaName,
    String? containerPath,
    String? fieldName,
    bool preferredOnly = false,
  }) {
    for (final completion in all(
      schemaName: schemaName,
      containerPath: containerPath,
      fieldName: fieldName,
      preferredOnly: preferredOnly,
    )) {
      return completion;
    }
    return null;
  }
}

Iterable<ChartJsonOptionFieldReference> _referencesFor(
  ChartJsonOptionSchema schema,
  String? fieldName,
) sync* {
  if (fieldName == null) {
    yield* schema.fieldReferences;
    return;
  }

  final reference = schema.fieldReferenceFor(fieldName);
  if (reference != null) yield reference;
}

Iterable<String> _containersFor(
  ChartJsonOptionSchema schema,
  String? containerPath,
) sync* {
  if (containerPath != null) {
    yield containerPath;
    return;
  }

  yield* schema.acceptedContainers;
}

Map<String, dynamic> _payloadFragmentFor(
  ChartJsonOptionCompletion completion,
  Map<String, Object?> values,
) {
  final override = _valueOverrideFor(completion, values);
  return completion.payloadFragment(
    value: override.value,
    hasValue: override.hasValue,
  );
}

_ValueOverride _valueOverrideFor(
  ChartJsonOptionCompletion completion,
  Map<String, Object?> values,
) {
  if (values.isEmpty) return const _ValueOverride.none();

  for (final key in _valueKeysFor(completion)) {
    if (values.containsKey(key)) {
      return _ValueOverride(values[key], sourceKey: key);
    }
  }

  final normalizedValues = {
    for (final key in values.keys) _normalizeValueKey(key): key,
  };
  for (final key in _valueKeysFor(completion)) {
    final sourceKey = normalizedValues[_normalizeValueKey(key)];
    if (sourceKey != null) {
      return _ValueOverride(values[sourceKey], sourceKey: sourceKey);
    }
  }
  return const _ValueOverride.none();
}

_PayloadPathValue _payloadValueAtPath(
  Map<String, dynamic> payload,
  String jsonPath,
) {
  final segments = ChartJsonOptionPaths.segments(jsonPath);
  if (segments.isEmpty) return const _PayloadPathValue.missing();

  Object? cursor = payload;
  for (var i = 0; i < segments.length; i++) {
    final map = JsonValue.map(cursor);
    final segment = segments[i];
    if (map == null || !map.containsKey(segment)) {
      return const _PayloadPathValue.missing();
    }
    if (i == segments.length - 1) {
      return _PayloadPathValue(map[segment]);
    }
    cursor = map[segment];
  }
  return const _PayloadPathValue.missing();
}

ChartJsonOptionPatchChangeKind _patchChangeKind({
  required _PayloadPathValue previousValue,
  required Object? nextValue,
}) {
  if (!previousValue.hasValue) return ChartJsonOptionPatchChangeKind.added;
  if (JsonValue.deepEquals(previousValue.value, nextValue)) {
    return ChartJsonOptionPatchChangeKind.unchanged;
  }
  return ChartJsonOptionPatchChangeKind.updated;
}

Iterable<String> _valueKeysFor(ChartJsonOptionCompletion completion) sync* {
  yield completion.jsonPath;
  yield completion.canonicalField;
  yield completion.label;
  yield completion.insertText;
  for (final alias in completion.aliases) {
    yield alias;
  }
}

String _normalizeValueKey(String value) {
  final buffer = StringBuffer();
  for (final unit in value.trim().codeUnits) {
    if (unit >= 65 && unit <= 90) {
      buffer.writeCharCode(unit + 32);
    } else if ((unit >= 97 && unit <= 122) || (unit >= 48 && unit <= 57)) {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

class _ValueOverride {
  final bool hasValue;
  final Object? value;
  final String? sourceKey;

  const _ValueOverride(this.value, {this.sourceKey}) : hasValue = true;

  const _ValueOverride.none()
    : hasValue = false,
      value = null,
      sourceKey = null;
}

class _PayloadPathValue {
  final bool hasValue;
  final Object? value;

  const _PayloadPathValue(this.value) : hasValue = true;

  const _PayloadPathValue.missing() : hasValue = false, value = null;
}
