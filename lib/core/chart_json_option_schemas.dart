import 'chart_diagnostic_fallback_fields.dart';
import 'chart_json_option_field_reference.dart';
import 'chart_json_option_paths.dart';
import 'chart_payload_normalization_fields.dart';
import 'chart_runtime_policy_fields.dart';
import 'json_value.dart';

class ChartJsonOptionSchema {
  final String name;
  final String description;
  final List<String> acceptedContainers;
  final List<Map<String, dynamic>> fields;
  final Map<String, dynamic> examplePayload;
  final Map<String, dynamic> exampleChartPayload;

  const ChartJsonOptionSchema({
    required this.name,
    required this.description,
    required this.acceptedContainers,
    required this.fields,
    this.examplePayload = const {},
    this.exampleChartPayload = const {},
  });

  bool acceptsContainer(String containerPath) {
    final normalized = ChartJsonOptionPaths.normalizeContainer(containerPath);
    return acceptedContainers.any(
      (container) =>
          ChartJsonOptionPaths.normalizeContainer(container) == normalized,
    );
  }

  bool matchesName(String value) {
    return _normalizeSchemaName(name) == _normalizeSchemaName(value);
  }

  List<String> get canonicalFields {
    return [
      for (final field in fields)
        if (field['canonicalField'] case final String canonicalField)
          canonicalField,
    ];
  }

  String? canonicalFieldFor(String fieldName) {
    final normalized = _normalizeSchemaName(fieldName);
    if (normalized.isEmpty) return null;

    for (final field in fields) {
      final canonical = field['canonicalField'];
      if (canonical is! String) continue;
      for (final candidate in _fieldCandidateNames(field)) {
        if (_normalizeSchemaName(candidate) == normalized) return canonical;
      }
    }
    return null;
  }

  Map<String, dynamic>? fieldJsonFor(String fieldName) {
    final field = fieldReferenceFor(fieldName)?.field;
    return field == null ? null : JsonValue.cloneMap(field);
  }

  ChartJsonOptionFieldReference? fieldReferenceFor(String fieldName) {
    final canonical = canonicalFieldFor(fieldName);
    if (canonical == null) return null;
    for (final field in fields) {
      if (field['canonicalField'] != canonical) continue;
      return ChartJsonOptionFieldReference(
        schemaName: name,
        schemaDescription: description,
        canonicalField: canonical,
        field: field,
        acceptedContainers: acceptedContainers,
      );
    }
    return null;
  }

  List<ChartJsonOptionFieldReference> get fieldReferences {
    return [
      for (final field in fields)
        if (field['canonicalField'] case final String canonicalField)
          ChartJsonOptionFieldReference(
            schemaName: name,
            schemaDescription: description,
            canonicalField: canonicalField,
            field: field,
            acceptedContainers: acceptedContainers,
          ),
    ];
  }

  bool supportsField(String fieldName) => canonicalFieldFor(fieldName) != null;

  Map<String, dynamic> toJson({
    bool includeExamplePayload = true,
    bool includeExampleChartPayload = true,
  }) => {
    'name': name,
    'description': description,
    'acceptedContainers': List<String>.from(acceptedContainers),
    'fieldCount': fields.length,
    'fields': fields.map(JsonValue.cloneMap).toList(growable: false),
    if (includeExamplePayload && examplePayload.isNotEmpty)
      'examplePayload': JsonValue.cloneMap(examplePayload),
    if (includeExampleChartPayload && exampleChartPayload.isNotEmpty)
      'exampleChartPayload': JsonValue.cloneMap(exampleChartPayload),
  };
}

/// Public schema registry for cross-cutting JSON option groups.
class ChartJsonOptionSchemas {
  static const runtimePerformancePolicyName = 'runtimePerformancePolicy';
  static const diagnosticFallbackName = 'diagnosticFallback';
  static const payloadNormalizationName = 'payloadNormalization';

  const ChartJsonOptionSchemas._();

  static ChartJsonOptionSchema
  get runtimePerformancePolicy => ChartJsonOptionSchema(
    name: runtimePerformancePolicyName,
    description:
        'Runtime performance thresholds used for diagnostics and recommendations.',
    acceptedContainers: const [
      r'$',
      'runtimePerformancePolicy',
      'performancePolicy',
      'diagnostics',
      'diagnostics.performancePolicy',
      'diagnostics.runtimePerformancePolicy',
      'runtimeDiagnostics',
      'runtimeDiagnostics.performancePolicy',
      'runtimeDiagnostics.runtimePerformancePolicy',
    ],
    fields: ChartRuntimePerformancePolicyFields.schemaJson(),
    examplePayload: const {
      'diagnostics': {
        'performancePolicy': {
          'largeDatasetPointThreshold': 10000,
          'cachePressureWarningThreshold': 0.9,
          'lowRenderCacheHitRateThreshold': 0.25,
          'lowRenderCacheMinRequests': 20,
        },
      },
    },
    exampleChartPayload: const {
      'type': 'line',
      'diagnostics': {
        'performancePolicy': {
          'largeDatasetPointThreshold': 10000,
          'cachePressureWarningThreshold': 0.9,
          'lowRenderCacheHitRateThreshold': 0.25,
          'lowRenderCacheMinRequests': 20,
        },
      },
      'series': [
        {
          'name': 'Revenue',
          'data': [12, 18, 11, 24],
        },
      ],
    },
  );

  static ChartJsonOptionSchema get diagnosticFallback => ChartJsonOptionSchema(
    name: diagnosticFallbackName,
    description:
        'Built-in fallback presentation options for invalid, blocked, or failed chart payloads.',
    acceptedContainers: const [
      'diagnosticFallbackOptions',
      'diagnosticFallback',
      'fallbackOptions',
      'diagnostics.diagnosticFallbackOptions',
      'diagnostics.diagnosticFallback',
      'diagnostics.fallbackOptions',
      'diagnostics.fallback',
    ],
    fields: ChartDiagnosticFallbackFields.schemaJson(),
    examplePayload: const {
      'diagnostics': {
        'fallbackOptions': {
          'preset': 'production',
          'title': 'Chart unavailable',
          'message': 'Review this payload before publishing.',
          'showErrorDetails': false,
        },
      },
    },
    exampleChartPayload: const {
      'type': 'line',
      'diagnostics': {
        'fallbackOptions': {
          'preset': 'production',
          'title': 'Chart unavailable',
          'message': 'Review this payload before publishing.',
          'showErrorDetails': false,
        },
      },
      'series': [
        {
          'name': 'Completion',
          'data': [42, 56, 61, 78],
        },
      ],
    },
  );

  static ChartJsonOptionSchema
  get payloadNormalization => ChartJsonOptionSchema(
    name: payloadNormalizationName,
    description:
        'Payload normalization controls for sampling, shorthand data, and trading data repair.',
    acceptedContainers: const [
      r'$',
      'normalizationOptions',
      'normalization',
      'payloadNormalization',
      'diagnostics.normalizationOptions',
      'diagnostics.normalization',
      'diagnostics.payloadNormalization',
    ],
    fields: ChartPayloadNormalizationFields.schemaJson(),
    examplePayload: const {
      'autoNormalizePayload': true,
      'diagnostics': {
        'normalizationOptions': {
          'defaultMode': 'large',
          'defaultThreshold': 1200,
          'dropUnsupportedSampling': true,
          'sanitizeTradingPayload': true,
        },
      },
    },
    exampleChartPayload: const {
      'type': 'line',
      'autoNormalizePayload': true,
      'dataMode': 'large',
      'sampling': {'enabled': true, 'threshold': 1200, 'strategy': 'minMax'},
      'diagnostics': {
        'normalizationOptions': {
          'defaultMode': 'large',
          'defaultThreshold': 1200,
          'dropUnsupportedSampling': true,
          'sanitizeTradingPayload': true,
        },
      },
      'series': [
        {
          'name': 'Traffic',
          'data': [120, 160, 144, 210],
        },
      ],
    },
  );

  static List<ChartJsonOptionSchema> get all => [
    runtimePerformancePolicy,
    diagnosticFallback,
    payloadNormalization,
  ];

  static ChartJsonOptionSchema? byName(String name) {
    final normalized = _normalizeSchemaName(name);
    if (normalized.isEmpty) return null;
    for (final schema in all) {
      if (schema.matchesName(normalized)) return schema;
    }
    return null;
  }

  static List<ChartJsonOptionSchema> forContainer(String containerPath) {
    return [
      for (final schema in all)
        if (schema.acceptsContainer(containerPath)) schema,
    ];
  }

  static List<ChartJsonOptionSchema> forField(
    String fieldName, {
    String? containerPath,
  }) {
    final schemas = containerPath == null ? all : forContainer(containerPath);
    return [
      for (final schema in schemas)
        if (schema.supportsField(fieldName)) schema,
    ];
  }

  static ChartJsonOptionSchema? schemaForField(
    String fieldName, {
    String? containerPath,
  }) {
    for (final schema in forField(fieldName, containerPath: containerPath)) {
      return schema;
    }
    return null;
  }

  static List<ChartJsonOptionFieldReference> fieldReferences({
    String? containerPath,
  }) {
    final schemas = containerPath == null ? all : forContainer(containerPath);
    return [for (final schema in schemas) ...schema.fieldReferences];
  }

  static String? canonicalFieldFor(
    String fieldName, {
    String? schemaName,
    String? containerPath,
  }) {
    if (schemaName != null) {
      return byName(schemaName)?.canonicalFieldFor(fieldName);
    }

    for (final schema in forField(fieldName, containerPath: containerPath)) {
      return schema.canonicalFieldFor(fieldName);
    }
    return null;
  }

  static ChartJsonOptionFieldReference? fieldReferenceFor(
    String fieldName, {
    String? schemaName,
    String? containerPath,
  }) {
    if (schemaName != null) {
      return byName(schemaName)?.fieldReferenceFor(fieldName);
    }

    for (final schema in forField(fieldName, containerPath: containerPath)) {
      return schema.fieldReferenceFor(fieldName);
    }
    return null;
  }

  static Map<String, dynamic>? fieldJsonFor(
    String fieldName, {
    String? schemaName,
    String? containerPath,
  }) {
    final field = fieldReferenceFor(
      fieldName,
      schemaName: schemaName,
      containerPath: containerPath,
    )?.field;
    return field == null ? null : JsonValue.cloneMap(field);
  }

  static Set<String> get acceptedContainers {
    return {
      for (final schema in all)
        for (final container in schema.acceptedContainers) container,
    };
  }

  static Map<String, Map<String, dynamic>> examplePayloads() {
    return {
      for (final schema in all)
        if (schema.examplePayload.isNotEmpty)
          schema.name: JsonValue.cloneMap(schema.examplePayload),
    };
  }

  static Map<String, dynamic>? examplePayloadFor(String name) {
    final payload = byName(name)?.examplePayload;
    return payload == null || payload.isEmpty
        ? null
        : JsonValue.cloneMap(payload);
  }

  static Map<String, Map<String, dynamic>> exampleChartPayloads() {
    return {
      for (final schema in all)
        if (schema.exampleChartPayload.isNotEmpty)
          schema.name: JsonValue.cloneMap(schema.exampleChartPayload),
    };
  }

  static Map<String, dynamic>? exampleChartPayloadFor(String name) {
    final payload = byName(name)?.exampleChartPayload;
    return payload == null || payload.isEmpty
        ? null
        : JsonValue.cloneMap(payload);
  }

  static List<Map<String, dynamic>> schemaJsonForContainer(
    String containerPath, {
    bool includeExamplePayload = true,
    bool includeExampleChartPayload = true,
  }) {
    return [
      for (final schema in forContainer(containerPath))
        schema.toJson(
          includeExamplePayload: includeExamplePayload,
          includeExampleChartPayload: includeExampleChartPayload,
        ),
    ];
  }

  static List<Map<String, dynamic>> schemaJson({
    bool includeExamplePayload = true,
    bool includeExampleChartPayload = true,
  }) {
    return [
      for (final schema in all)
        schema.toJson(
          includeExamplePayload: includeExamplePayload,
          includeExampleChartPayload: includeExampleChartPayload,
        ),
    ];
  }
}

Iterable<String> _fieldCandidateNames(Map<String, dynamic> field) sync* {
  final canonical = field['canonicalField'];
  if (canonical is String) yield canonical;

  final aliases = field['aliases'];
  if (aliases is Iterable) {
    for (final alias in aliases) {
      if (alias is String) yield alias;
    }
  }
}

String _normalizeSchemaName(String value) {
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
