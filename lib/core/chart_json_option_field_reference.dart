import 'json_value.dart';

class ChartJsonOptionFieldReference {
  final String schemaName;
  final String schemaDescription;
  final String canonicalField;
  final Map<String, dynamic> field;
  final List<String> acceptedContainers;

  const ChartJsonOptionFieldReference({
    required this.schemaName,
    required this.schemaDescription,
    required this.canonicalField,
    required this.field,
    required this.acceptedContainers,
  });

  String? get kind {
    final value = field['kind'];
    return value is String ? value : null;
  }

  String? get description {
    final value = field['description'];
    return value is String ? value : null;
  }

  List<String> get aliases {
    final rawAliases = field['aliases'];
    final aliases = rawAliases is Iterable
        ? [
            for (final alias in rawAliases)
              if (alias is String) alias,
          ]
        : const <String>[];

    if (aliases.isEmpty) return [canonicalField];
    if (aliases.contains(canonicalField)) return aliases;
    return [canonicalField, ...aliases];
  }

  String get preferredContainer {
    for (final container in acceptedContainers) {
      if (container != r'$') return container;
    }
    return acceptedContainers.isEmpty ? r'$' : acceptedContainers.first;
  }

  Map<String, dynamic> toJson() => {
    'schemaName': schemaName,
    'schemaDescription': schemaDescription,
    'canonicalField': canonicalField,
    'aliases': aliases,
    if (kind != null) 'kind': kind,
    if (description != null) 'description': description,
    'acceptedContainers': List<String>.from(acceptedContainers),
    'preferredContainer': preferredContainer,
    'field': JsonValue.cloneMap(field),
  };
}
