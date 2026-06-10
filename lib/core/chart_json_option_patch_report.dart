import 'chart_json_option_patch_entry.dart';
import 'chart_json_option_patch_issue.dart';
import 'chart_json_option_patch_operation.dart';
import 'chart_json_option_value_hint.dart';
import 'json_value.dart';

export 'chart_json_option_patch_entry.dart';
export 'chart_json_option_patch_issue.dart';
export 'chart_json_option_patch_operation.dart';

class ChartJsonOptionPayloadPatchReport {
  final List<ChartJsonOptionPatchEntry> entries;
  final List<String> ignoredValueKeys;
  final Map<String, Object?> ignoredValues;
  final Map<String, dynamic> payloadFragment;
  final Map<String, dynamic> resultPayload;
  final Map<String, dynamic> validPayloadFragment;
  final Map<String, dynamic> validResultPayload;

  const ChartJsonOptionPayloadPatchReport({
    required this.entries,
    required this.ignoredValueKeys,
    required this.payloadFragment,
    required this.resultPayload,
    this.ignoredValues = const <String, Object?>{},
    Map<String, dynamic>? validPayloadFragment,
    Map<String, dynamic>? validResultPayload,
  }) : validPayloadFragment = validPayloadFragment ?? payloadFragment,
       validResultPayload = validResultPayload ?? resultPayload;

  bool get hasIssues => issues.isNotEmpty;

  bool get hasErrors => errors.isNotEmpty;

  bool get canApplySafely => !hasErrors;

  bool get hasChanges => changedEntries.isNotEmpty;

  bool get hasInvalidValues {
    return entries.any((entry) => !entry.isValid);
  }

  List<ChartJsonOptionPatchEntry> get changedEntries {
    return [
      for (final entry in entries)
        if (entry.changesValue) entry,
    ];
  }

  List<ChartJsonOptionPatchEntry> get validEntries {
    return [
      for (final entry in entries)
        if (entry.isValid) entry,
    ];
  }

  List<ChartJsonOptionPatchEntry> get invalidEntries {
    return [
      for (final entry in entries)
        if (!entry.isValid) entry,
    ];
  }

  List<ChartJsonOptionPatchOperation> get operations {
    return [
      for (final entry in entries)
        ChartJsonOptionPatchOperation.fromEntry(entry),
    ];
  }

  List<ChartJsonOptionPatchOperation> get validOperations {
    return [
      for (final operation in operations)
        if (operation.isValid) operation,
    ];
  }

  List<ChartJsonOptionPatchOperation> get changedOperations {
    return [
      for (final operation in operations)
        if (operation.changesValue) operation,
    ];
  }

  List<Map<String, dynamic>> get jsonPatchOperations {
    return _jsonPatchOperationsFor(changedOperations);
  }

  List<Map<String, dynamic>> get validJsonPatchOperations {
    return _jsonPatchOperationsFor(validOperations);
  }

  List<String> get appliedFields {
    return [for (final entry in entries) entry.canonicalField];
  }

  List<String> get changedFields {
    return [for (final entry in changedEntries) entry.canonicalField];
  }

  List<String> get addedFields {
    return [
      for (final entry in entries)
        if (entry.changeKind == ChartJsonOptionPatchChangeKind.added)
          entry.canonicalField,
    ];
  }

  List<String> get updatedFields {
    return [
      for (final entry in entries)
        if (entry.changeKind == ChartJsonOptionPatchChangeKind.updated)
          entry.canonicalField,
    ];
  }

  List<String> get unchangedFields {
    return [
      for (final entry in entries)
        if (entry.changeKind == ChartJsonOptionPatchChangeKind.unchanged)
          entry.canonicalField,
    ];
  }

  List<String> get validAppliedFields {
    return [for (final entry in validEntries) entry.canonicalField];
  }

  List<String> get invalidFields {
    return [for (final entry in invalidEntries) entry.canonicalField];
  }

  List<String> get overwrittenFields {
    return [
      for (final entry in entries)
        if (entry.overwritesExistingValue) entry.canonicalField,
    ];
  }

  List<ChartJsonOptionValueValidation> get validations {
    return [for (final entry in entries) entry.validation];
  }

  List<ChartJsonOptionPatchIssue> get issues {
    return [
      for (final entry in entries)
        if (!entry.isValid) ChartJsonOptionPatchIssue.invalidValue(entry),
      for (final key in ignoredValueKeys)
        ChartJsonOptionPatchIssue.ignoredValueKey(
          key,
          value: ignoredValues[key],
          hasValue: ignoredValues.containsKey(key),
        ),
    ];
  }

  List<ChartJsonOptionPatchIssue> get warnings {
    return [
      for (final issue in issues)
        if (issue.severity == ChartJsonOptionPatchIssueSeverity.warning) issue,
    ];
  }

  List<ChartJsonOptionPatchIssue> get errors {
    return [
      for (final issue in issues)
        if (issue.severity == ChartJsonOptionPatchIssueSeverity.error) issue,
    ];
  }

  Map<String, dynamic> toJson() {
    final patchIssues = issues;
    return {
      'hasIssues': patchIssues.isNotEmpty,
      'hasErrors': patchIssues.any(
        (issue) => issue.severity == ChartJsonOptionPatchIssueSeverity.error,
      ),
      'canApplySafely': canApplySafely,
      'hasChanges': hasChanges,
      'hasInvalidValues': hasInvalidValues,
      'appliedFields': appliedFields,
      'changedFields': changedFields,
      'addedFields': addedFields,
      'updatedFields': updatedFields,
      'unchangedFields': unchangedFields,
      'validAppliedFields': validAppliedFields,
      'invalidFields': invalidFields,
      'overwrittenFields': overwrittenFields,
      'ignoredValueKeys': List<String>.from(ignoredValueKeys),
      'ignoredValues': JsonValue.cloneMap(ignoredValues),
      'issues': [for (final issue in patchIssues) issue.toJson()],
      'operations': [for (final operation in operations) operation.toJson()],
      'validOperations': [
        for (final operation in validOperations) operation.toJson(),
      ],
      'changedOperations': [
        for (final operation in changedOperations) operation.toJson(),
      ],
      'jsonPatchOperations': [
        for (final operation in jsonPatchOperations)
          JsonValue.cloneMap(operation),
      ],
      'validJsonPatchOperations': [
        for (final operation in validJsonPatchOperations)
          JsonValue.cloneMap(operation),
      ],
      'entries': [for (final entry in entries) entry.toJson()],
      'payloadFragment': JsonValue.cloneMap(payloadFragment),
      'resultPayload': JsonValue.cloneMap(resultPayload),
      'validPayloadFragment': JsonValue.cloneMap(validPayloadFragment),
      'validResultPayload': JsonValue.cloneMap(validResultPayload),
    };
  }
}

List<Map<String, dynamic>> _jsonPatchOperationsFor(
  Iterable<ChartJsonOptionPatchOperation> operations,
) {
  final patches = <Map<String, dynamic>>[];
  for (final operation in operations) {
    final patch = operation.toJsonPatchOperation();
    if (patch != null) patches.add(patch);
  }
  return patches;
}
