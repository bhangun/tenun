enum ChartRuntimePerformancePolicyFieldKind { positiveInteger, unitRatio }

class ChartRuntimePerformancePolicyFieldSpec {
  final String canonicalField;
  final List<String> aliases;
  final ChartRuntimePerformancePolicyFieldKind kind;
  final String description;

  const ChartRuntimePerformancePolicyFieldSpec({
    required this.canonicalField,
    required this.aliases,
    required this.kind,
    required this.description,
  });

  bool matches(String field) => aliases.contains(field);

  Map<String, dynamic> toJson() => {
    'canonicalField': canonicalField,
    'aliases': List<String>.from(aliases),
    'kind': kind.name,
    'description': description,
  };
}

/// Shared runtime performance policy field names and parsing helpers.
///
/// Kept dependency-free so both diagnostics and payload validation can use the
/// same aliases without creating import cycles.
class ChartRuntimePerformancePolicyFields {
  static const String largeDatasetPointThreshold = 'largeDatasetPointThreshold';
  static const String cachePressureWarningThreshold =
      'cachePressureWarningThreshold';
  static const String lowRenderCacheHitRateThreshold =
      'lowRenderCacheHitRateThreshold';
  static const String lowRenderCacheMinRequests = 'lowRenderCacheMinRequests';

  static const List<String> largeDatasetPointThresholdAliases = [
    largeDatasetPointThreshold,
    'largeDataPointThreshold',
    'largeDatasetThreshold',
  ];

  static const List<String> cachePressureWarningThresholdAliases = [
    cachePressureWarningThreshold,
    'cachePressureThreshold',
  ];

  static const List<String> lowRenderCacheHitRateThresholdAliases = [
    lowRenderCacheHitRateThreshold,
    'renderCacheHitRateThreshold',
    'minRenderCacheHitRate',
  ];

  static const List<String> lowRenderCacheMinRequestsAliases = [
    lowRenderCacheMinRequests,
    'renderCacheMinRequests',
    'minRenderCacheRequests',
  ];

  static const largeDatasetPointThresholdSpec =
      ChartRuntimePerformancePolicyFieldSpec(
        canonicalField: largeDatasetPointThreshold,
        aliases: largeDatasetPointThresholdAliases,
        kind: ChartRuntimePerformancePolicyFieldKind.positiveInteger,
        description:
            'Source data point count that triggers large-dataset recommendations.',
      );

  static const cachePressureWarningThresholdSpec =
      ChartRuntimePerformancePolicyFieldSpec(
        canonicalField: cachePressureWarningThreshold,
        aliases: cachePressureWarningThresholdAliases,
        kind: ChartRuntimePerformancePolicyFieldKind.unitRatio,
        description: 'Cache memory pressure ratio that triggers budget review.',
      );

  static const lowRenderCacheHitRateThresholdSpec =
      ChartRuntimePerformancePolicyFieldSpec(
        canonicalField: lowRenderCacheHitRateThreshold,
        aliases: lowRenderCacheHitRateThresholdAliases,
        kind: ChartRuntimePerformancePolicyFieldKind.unitRatio,
        description:
            'Render cache hit-rate ratio below which reuse should be reviewed.',
      );

  static const lowRenderCacheMinRequestsSpec =
      ChartRuntimePerformancePolicyFieldSpec(
        canonicalField: lowRenderCacheMinRequests,
        aliases: lowRenderCacheMinRequestsAliases,
        kind: ChartRuntimePerformancePolicyFieldKind.positiveInteger,
        description:
            'Minimum render cache requests before low hit-rate checks apply.',
      );

  static const List<ChartRuntimePerformancePolicyFieldSpec> fieldSpecs = [
    largeDatasetPointThresholdSpec,
    cachePressureWarningThresholdSpec,
    lowRenderCacheHitRateThresholdSpec,
    lowRenderCacheMinRequestsSpec,
  ];

  static const List<String> canonicalFields = [
    largeDatasetPointThreshold,
    cachePressureWarningThreshold,
    lowRenderCacheHitRateThreshold,
    lowRenderCacheMinRequests,
  ];

  static const Set<String> allAliases = {
    ...largeDatasetPointThresholdAliases,
    ...cachePressureWarningThresholdAliases,
    ...lowRenderCacheHitRateThresholdAliases,
    ...lowRenderCacheMinRequestsAliases,
  };

  static String get suggestion =>
      'Use ${canonicalFields.take(canonicalFields.length - 1).join(', ')}, '
      'or ${canonicalFields.last}.';

  const ChartRuntimePerformancePolicyFields._();

  static String? canonicalFieldFor(String field) {
    for (final spec in fieldSpecs) {
      if (spec.matches(field)) return spec.canonicalField;
    }
    return null;
  }

  static ChartRuntimePerformancePolicyFieldKind? kindFor(String field) {
    for (final spec in fieldSpecs) {
      if (spec.matches(field)) return spec.kind;
    }
    return null;
  }

  static List<String> aliasesFor(String canonicalField) {
    for (final spec in fieldSpecs) {
      if (spec.canonicalField == canonicalField) {
        return List<String>.from(spec.aliases);
      }
    }
    return const <String>[];
  }

  static List<Map<String, dynamic>> schemaJson() {
    return [for (final spec in fieldSpecs) spec.toJson()];
  }

  static bool containsAny(Map<Object?, Object?> map) {
    return allAliases.any(map.containsKey);
  }

  static String? firstField(
    Map<Object?, Object?> map,
    Iterable<String> aliases,
  ) {
    for (final alias in aliases) {
      if (map.containsKey(alias)) return alias;
    }
    return null;
  }

  static Object? readValue(
    Map<Object?, Object?> map,
    Iterable<String> aliases,
  ) {
    final field = firstField(map, aliases);
    return field == null ? null : map[field];
  }

  static int? readInt(Map<Object?, Object?> map, Iterable<String> aliases) {
    return parseInt(readValue(map, aliases));
  }

  static int? parseInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  static int? parsePositiveInt(Object? raw) {
    final value = parseInt(raw);
    return value != null && value > 0 ? value : null;
  }

  static double? readRatio(
    Map<Object?, Object?> map,
    Iterable<String> aliases,
  ) {
    return parseRatio(readValue(map, aliases));
  }

  static double? parseRatio(Object? raw) {
    double? parsed;
    var fromPercentString = false;
    if (raw is num) {
      parsed = raw.toDouble();
    } else if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.endsWith('%')) {
        fromPercentString = true;
        final percent = double.tryParse(
          trimmed.substring(0, trimmed.length - 1).trim(),
        );
        parsed = percent == null ? null : percent / 100;
      } else {
        parsed = double.tryParse(trimmed);
      }
    }
    if (parsed == null || !parsed.isFinite) return null;
    if (!fromPercentString && parsed > 1 && parsed <= 100) return parsed / 100;
    return parsed;
  }

  static String path(String prefix, String field) {
    return prefix.isEmpty ? field : '$prefix.$field';
  }
}
