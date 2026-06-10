import 'chart_json_option_patch_entry.dart';
import 'chart_json_option_paths.dart';
import 'chart_json_option_value_hint.dart';
import 'json_value.dart';

enum ChartJsonOptionPatchIssueSeverity { warning, error }

class ChartJsonOptionPatchIssue {
  final String code;
  final ChartJsonOptionPatchIssueSeverity severity;
  final String message;
  final String? schemaName;
  final String? canonicalField;
  final String? jsonPath;
  final String? valueKey;
  final Object? value;
  final bool hasValue;
  final ChartJsonOptionValueValidation? validation;

  const ChartJsonOptionPatchIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.schemaName,
    this.canonicalField,
    this.jsonPath,
    this.valueKey,
    this.value,
    this.hasValue = false,
    this.validation,
  });

  String? get jsonPointer {
    final path = jsonPath;
    return path == null ? null : ChartJsonOptionPaths.jsonPointer(path);
  }

  factory ChartJsonOptionPatchIssue.invalidValue(
    ChartJsonOptionPatchEntry entry,
  ) {
    return ChartJsonOptionPatchIssue(
      code: 'invalidValue',
      severity: ChartJsonOptionPatchIssueSeverity.error,
      message:
          entry.validation.message ??
          'Value for "${entry.canonicalField}" is invalid.',
      schemaName: entry.schemaName,
      canonicalField: entry.canonicalField,
      jsonPath: entry.jsonPath,
      valueKey: entry.valueKey,
      value: entry.value,
      hasValue: true,
      validation: entry.validation,
    );
  }

  factory ChartJsonOptionPatchIssue.ignoredValueKey(
    String valueKey, {
    Object? value,
    bool hasValue = false,
  }) {
    return ChartJsonOptionPatchIssue(
      code: 'ignoredValueKey',
      severity: ChartJsonOptionPatchIssueSeverity.warning,
      message: 'Value key "$valueKey" did not match any chart JSON option.',
      valueKey: valueKey,
      value: value,
      hasValue: hasValue,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'severity': severity.name,
    'message': message,
    if (schemaName != null) 'schemaName': schemaName,
    if (canonicalField != null) 'canonicalField': canonicalField,
    if (jsonPath != null) 'jsonPath': jsonPath,
    if (jsonPointer != null) 'jsonPointer': jsonPointer,
    if (valueKey != null) 'valueKey': valueKey,
    if (hasValue) 'value': JsonValue.clone(value),
    if (validation != null) 'validation': validation!.toJson(),
  };
}
