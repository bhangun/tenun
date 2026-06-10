import 'chart_json_option_field_reference.dart';
import 'chart_json_option_paths.dart';
import 'chart_json_option_value_hint.dart';
import 'json_value.dart';

class ChartJsonOptionCompletion {
  final String schemaName;
  final String canonicalField;
  final String containerPath;
  final String jsonPath;
  final String label;
  final String insertText;
  final List<String> aliases;
  final String? kind;
  final String? description;
  final bool preferred;
  final ChartJsonOptionValueHint? valueHint;

  const ChartJsonOptionCompletion({
    required this.schemaName,
    required this.canonicalField,
    required this.containerPath,
    required this.jsonPath,
    required this.label,
    required this.insertText,
    required this.aliases,
    required this.preferred,
    this.kind,
    this.description,
    this.valueHint,
  });

  factory ChartJsonOptionCompletion.fromReference(
    ChartJsonOptionFieldReference reference, {
    required String containerPath,
  }) {
    final normalizedContainer = ChartJsonOptionPaths.normalizeContainer(
      containerPath,
    );
    final jsonPath = ChartJsonOptionPaths.fieldPath(
      normalizedContainer,
      reference.canonicalField,
    );
    return ChartJsonOptionCompletion(
      schemaName: reference.schemaName,
      canonicalField: reference.canonicalField,
      containerPath: normalizedContainer,
      jsonPath: jsonPath,
      label: reference.canonicalField,
      insertText: reference.canonicalField,
      aliases: reference.aliases,
      kind: reference.kind,
      description: reference.description,
      valueHint: ChartJsonOptionValueHint.forKind(
        reference.kind,
        canonicalField: reference.canonicalField,
      ),
      preferred: ChartJsonOptionPaths.sameContainer(
        normalizedContainer,
        reference.preferredContainer,
      ),
    );
  }

  ChartJsonOptionValueHint get resolvedValueHint {
    return valueHint ??
        ChartJsonOptionValueHint.forKind(kind, canonicalField: canonicalField);
  }

  Object? get exampleValue => resolvedValueHint.value;

  String get valueSnippet => resolvedValueHint.jsonLiteral;

  String get entrySnippet => '"$canonicalField": $valueSnippet';

  Map<String, dynamic> get examplePayloadFragment => payloadFragment();

  Map<String, dynamic> payloadFragment({Object? value, bool hasValue = false}) {
    return ChartJsonOptionPaths.fragment(
      jsonPath,
      JsonValue.clone(hasValue ? value : value ?? exampleValue),
    );
  }

  Map<String, dynamic> applyToPayload(
    Map<String, dynamic> payload, {
    Object? value,
    bool hasValue = false,
  }) {
    return ChartJsonOptionPaths.mergeFragment(
      payload,
      payloadFragment(value: value, hasValue: hasValue),
    );
  }

  ChartJsonOptionValueValidation validateValue(Object? value) {
    return resolvedValueHint.validate(value, canonicalField: canonicalField);
  }

  Map<String, dynamic> toJson() => {
    'schemaName': schemaName,
    'canonicalField': canonicalField,
    'containerPath': containerPath,
    'jsonPath': jsonPath,
    'label': label,
    'insertText': insertText,
    'aliases': List<String>.from(aliases),
    if (kind != null) 'kind': kind,
    if (description != null) 'description': description,
    'exampleValue': JsonValue.clone(exampleValue),
    'valueSnippet': valueSnippet,
    'entrySnippet': entrySnippet,
    'valueHint': resolvedValueHint.toJson(),
    'examplePayloadFragment': examplePayloadFragment,
    'preferred': preferred,
  };
}
