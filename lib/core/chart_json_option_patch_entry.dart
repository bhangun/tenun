import 'chart_json_option_paths.dart';
import 'chart_json_option_value_hint.dart';
import 'json_value.dart';

enum ChartJsonOptionPatchChangeKind { added, updated, unchanged }

class ChartJsonOptionPatchEntry {
  final String schemaName;
  final String canonicalField;
  final String jsonPath;
  final Object? value;
  final Object? previousValue;
  final bool usedOverride;
  final String? valueKey;
  final bool hasPreviousValue;
  final bool overwritesExistingValue;
  final ChartJsonOptionPatchChangeKind changeKind;
  final ChartJsonOptionValueValidation validation;

  const ChartJsonOptionPatchEntry({
    required this.schemaName,
    required this.canonicalField,
    required this.jsonPath,
    required this.value,
    required this.usedOverride,
    required this.overwritesExistingValue,
    required this.validation,
    this.previousValue,
    this.valueKey,
    this.hasPreviousValue = false,
    this.changeKind = ChartJsonOptionPatchChangeKind.added,
  });

  bool get isValid => validation.isValid;

  bool get changesValue {
    return changeKind != ChartJsonOptionPatchChangeKind.unchanged;
  }

  String get jsonPointer {
    return ChartJsonOptionPaths.jsonPointer(jsonPath);
  }

  Map<String, dynamic> toJson() => {
    'schemaName': schemaName,
    'canonicalField': canonicalField,
    'jsonPath': jsonPath,
    'jsonPointer': jsonPointer,
    'value': JsonValue.clone(value),
    'hasPreviousValue': hasPreviousValue,
    if (hasPreviousValue) 'previousValue': JsonValue.clone(previousValue),
    'usedOverride': usedOverride,
    if (valueKey != null) 'valueKey': valueKey,
    'overwritesExistingValue': overwritesExistingValue,
    'changeKind': changeKind.name,
    'changesValue': changesValue,
    'validation': validation.toJson(),
    'isValid': isValid,
  };
}
