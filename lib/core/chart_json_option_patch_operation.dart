import 'chart_json_option_patch_entry.dart';
import 'chart_json_option_paths.dart';
import 'json_value.dart';

enum ChartJsonOptionPatchOperationKind { add, replace, noop }

class ChartJsonOptionPatchOperation {
  final ChartJsonOptionPatchOperationKind kind;
  final String schemaName;
  final String canonicalField;
  final String jsonPath;
  final Object? value;
  final Object? previousValue;
  final bool hasPreviousValue;
  final bool isValid;
  final String? valueKey;

  const ChartJsonOptionPatchOperation({
    required this.kind,
    required this.schemaName,
    required this.canonicalField,
    required this.jsonPath,
    required this.value,
    required this.hasPreviousValue,
    required this.isValid,
    this.previousValue,
    this.valueKey,
  });

  factory ChartJsonOptionPatchOperation.fromEntry(
    ChartJsonOptionPatchEntry entry,
  ) {
    return ChartJsonOptionPatchOperation(
      kind: _operationKind(entry.changeKind),
      schemaName: entry.schemaName,
      canonicalField: entry.canonicalField,
      jsonPath: entry.jsonPath,
      value: entry.value,
      previousValue: entry.previousValue,
      hasPreviousValue: entry.hasPreviousValue,
      isValid: entry.isValid,
      valueKey: entry.valueKey,
    );
  }

  bool get changesValue {
    return kind != ChartJsonOptionPatchOperationKind.noop;
  }

  String get jsonPointer {
    return ChartJsonOptionPaths.jsonPointer(jsonPath);
  }

  Map<String, dynamic>? toJsonPatchOperation() {
    if (!changesValue) return null;
    return {
      'op': kind.name,
      'path': jsonPointer,
      'value': JsonValue.clone(value),
    };
  }

  Map<String, dynamic> toJson() => {
    'op': kind.name,
    'schemaName': schemaName,
    'canonicalField': canonicalField,
    'jsonPath': jsonPath,
    'jsonPointer': jsonPointer,
    'value': JsonValue.clone(value),
    'hasPreviousValue': hasPreviousValue,
    if (hasPreviousValue) 'previousValue': JsonValue.clone(previousValue),
    'changesValue': changesValue,
    'isValid': isValid,
    if (valueKey != null) 'valueKey': valueKey,
  };
}

ChartJsonOptionPatchOperationKind _operationKind(
  ChartJsonOptionPatchChangeKind changeKind,
) {
  return switch (changeKind) {
    ChartJsonOptionPatchChangeKind.added =>
      ChartJsonOptionPatchOperationKind.add,
    ChartJsonOptionPatchChangeKind.updated =>
      ChartJsonOptionPatchOperationKind.replace,
    ChartJsonOptionPatchChangeKind.unchanged =>
      ChartJsonOptionPatchOperationKind.noop,
  };
}
