enum ChartPayloadNormalizationFieldKind { boolean, positiveInteger, dataMode }

class ChartPayloadNormalizationFieldSpec {
  final String canonicalField;
  final ChartPayloadNormalizationFieldKind kind;
  final String description;

  const ChartPayloadNormalizationFieldSpec({
    required this.canonicalField,
    required this.kind,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'canonicalField': canonicalField,
    'kind': kind.name,
    'description': description,
  };
}

/// Shared payload normalization field names and parsing helpers.
class ChartPayloadNormalizationFields {
  static const String autoNormalizePayload = 'autoNormalizePayload';
  static const String dropUnsupportedSampling = 'dropUnsupportedSampling';
  static const String defaultThreshold = 'defaultThreshold';
  static const String defaultMode = 'defaultMode';
  static const String sanitizeTradingPayload = 'sanitizeTradingPayload';
  static const String maxInlineLength = 'maxInlineLength';

  static const String normalizationOptions = 'normalizationOptions';
  static const String normalization = 'normalization';
  static const String payloadNormalization = 'payloadNormalization';
  static const String diagnostics = 'diagnostics';

  static const List<String> topLevelContainerFields = [
    normalizationOptions,
    normalization,
    payloadNormalization,
  ];

  static const List<String> diagnosticsContainerFields = [
    normalizationOptions,
    normalization,
    payloadNormalization,
  ];

  static const autoNormalizePayloadSpec = ChartPayloadNormalizationFieldSpec(
    canonicalField: autoNormalizePayload,
    kind: ChartPayloadNormalizationFieldKind.boolean,
    description: 'Whether JSON payload normalization should run before parse.',
  );

  static const dropUnsupportedSamplingSpec = ChartPayloadNormalizationFieldSpec(
    canonicalField: dropUnsupportedSampling,
    kind: ChartPayloadNormalizationFieldKind.boolean,
    description:
        'Whether unsupported chart types should downgrade sampling to regular mode.',
  );

  static const defaultThresholdSpec = ChartPayloadNormalizationFieldSpec(
    canonicalField: defaultThreshold,
    kind: ChartPayloadNormalizationFieldKind.positiveInteger,
    description:
        'Fallback sampling threshold used when payload threshold is invalid.',
  );

  static const defaultModeSpec = ChartPayloadNormalizationFieldSpec(
    canonicalField: defaultMode,
    kind: ChartPayloadNormalizationFieldKind.dataMode,
    description: 'Fallback data mode: regular, auto, or large.',
  );

  static const sanitizeTradingPayloadSpec = ChartPayloadNormalizationFieldSpec(
    canonicalField: sanitizeTradingPayload,
    kind: ChartPayloadNormalizationFieldKind.boolean,
    description:
        'Whether trading payload rows and parameters should be repaired.',
  );

  static const maxInlineLengthSpec = ChartPayloadNormalizationFieldSpec(
    canonicalField: maxInlineLength,
    kind: ChartPayloadNormalizationFieldKind.positiveInteger,
    description: 'Maximum inline value length in normalization diffs.',
  );

  static const List<ChartPayloadNormalizationFieldSpec> fieldSpecs = [
    autoNormalizePayloadSpec,
    dropUnsupportedSamplingSpec,
    defaultThresholdSpec,
    defaultModeSpec,
    sanitizeTradingPayloadSpec,
    maxInlineLengthSpec,
  ];

  static const List<String> canonicalFields = [
    autoNormalizePayload,
    dropUnsupportedSampling,
    defaultThreshold,
    defaultMode,
    sanitizeTradingPayload,
    maxInlineLength,
  ];

  static const Set<String> allFields = {...canonicalFields};

  static const Set<String> dataModeValues = {
    'regular',
    'simple',
    'auto',
    'large',
    'largedataset',
    'performance',
  };

  static String get suggestion =>
      'Use ${canonicalFields.take(canonicalFields.length - 1).join(', ')}, '
      'or ${canonicalFields.last}.';

  const ChartPayloadNormalizationFields._();

  static List<Map<String, dynamic>> schemaJson() {
    return [for (final spec in fieldSpecs) spec.toJson()];
  }

  static bool isBooleanLike(Object? raw) => parseBool(raw) != null;

  static bool isPositiveIntegerLike(Object? raw) {
    return parsePositiveInt(raw) != null;
  }

  static bool isDataMode(Object? raw) {
    return raw is String && dataModeValues.contains(raw.trim().toLowerCase());
  }

  static bool? parseBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) {
      if (raw == 0) return false;
      if (raw == 1) return true;
      return null;
    }
    if (raw is String) {
      switch (raw.trim().toLowerCase()) {
        case 'true':
        case 'yes':
        case '1':
          return true;
        case 'false':
        case 'no':
        case '0':
          return false;
      }
    }
    return null;
  }

  static int? parsePositiveInt(Object? raw) {
    final value = switch (raw) {
      int() => raw,
      num() when raw.isFinite => raw.toInt(),
      String() => int.tryParse(raw.trim()),
      _ => null,
    };
    if (value == null || value <= 0) return null;
    return value;
  }

  static String path(String prefix, String field) {
    return prefix.isEmpty ? field : '$prefix.$field';
  }
}
