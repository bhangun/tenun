enum ChartDiagnosticFallbackFieldKind {
  preset,
  string,
  boolean,
  nonNegativeInteger,
}

class ChartDiagnosticFallbackFieldSpec {
  final String canonicalField;
  final ChartDiagnosticFallbackFieldKind kind;
  final String description;

  const ChartDiagnosticFallbackFieldSpec({
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

/// Shared diagnostic fallback field names and parsing helpers.
///
/// Kept dependency-free so widget options and payload validation can stay in
/// sync without introducing a core-to-widget import.
class ChartDiagnosticFallbackFields {
  static const String preset = 'preset';
  static const String title = 'title';
  static const String message = 'message';
  static const String detailMessage = 'detailMessage';
  static const String showDoctorSummary = 'showDoctorSummary';
  static const String showValidationDetails = 'showValidationDetails';
  static const String showErrorDetails = 'showErrorDetails';
  static const String showQuickFixes = 'showQuickFixes';
  static const String maxQuickFixes = 'maxQuickFixes';

  static const String diagnosticFallbackOptions = 'diagnosticFallbackOptions';
  static const String diagnosticFallback = 'diagnosticFallback';
  static const String fallbackOptions = 'fallbackOptions';
  static const String fallback = 'fallback';
  static const String diagnostics = 'diagnostics';

  static const List<String> topLevelContainerFields = [
    diagnosticFallbackOptions,
    diagnosticFallback,
    fallbackOptions,
  ];

  static const List<String> diagnosticsContainerFields = [
    diagnosticFallbackOptions,
    diagnosticFallback,
    fallbackOptions,
    fallback,
  ];

  static const Set<String> presetValues = {
    'default',
    'defaults',
    'compact',
    'quiet',
    'production',
  };

  static const titleSpec = ChartDiagnosticFallbackFieldSpec(
    canonicalField: title,
    kind: ChartDiagnosticFallbackFieldKind.string,
    description: 'Fallback panel title.',
  );

  static const messageSpec = ChartDiagnosticFallbackFieldSpec(
    canonicalField: message,
    kind: ChartDiagnosticFallbackFieldKind.string,
    description: 'Primary fallback message.',
  );

  static const detailMessageSpec = ChartDiagnosticFallbackFieldSpec(
    canonicalField: detailMessage,
    kind: ChartDiagnosticFallbackFieldKind.string,
    description: 'Secondary detail text, often used for render errors.',
  );

  static const presetSpec = ChartDiagnosticFallbackFieldSpec(
    canonicalField: preset,
    kind: ChartDiagnosticFallbackFieldKind.preset,
    description: 'Named fallback option preset.',
  );

  static const showDoctorSummarySpec = ChartDiagnosticFallbackFieldSpec(
    canonicalField: showDoctorSummary,
    kind: ChartDiagnosticFallbackFieldKind.boolean,
    description: 'Whether to show payload doctor summary text.',
  );

  static const showValidationDetailsSpec = ChartDiagnosticFallbackFieldSpec(
    canonicalField: showValidationDetails,
    kind: ChartDiagnosticFallbackFieldKind.boolean,
    description: 'Whether to show validation report issue details.',
  );

  static const showErrorDetailsSpec = ChartDiagnosticFallbackFieldSpec(
    canonicalField: showErrorDetails,
    kind: ChartDiagnosticFallbackFieldKind.boolean,
    description: 'Whether to show raw render/build error text.',
  );

  static const showQuickFixesSpec = ChartDiagnosticFallbackFieldSpec(
    canonicalField: showQuickFixes,
    kind: ChartDiagnosticFallbackFieldKind.boolean,
    description: 'Whether to show payload quick-fix suggestions.',
  );

  static const maxQuickFixesSpec = ChartDiagnosticFallbackFieldSpec(
    canonicalField: maxQuickFixes,
    kind: ChartDiagnosticFallbackFieldKind.nonNegativeInteger,
    description: 'Maximum number of quick-fix suggestions to show.',
  );

  static const List<ChartDiagnosticFallbackFieldSpec> fieldSpecs = [
    presetSpec,
    titleSpec,
    messageSpec,
    detailMessageSpec,
    showDoctorSummarySpec,
    showValidationDetailsSpec,
    showErrorDetailsSpec,
    showQuickFixesSpec,
    maxQuickFixesSpec,
  ];

  static const List<String> canonicalFields = [
    preset,
    title,
    message,
    detailMessage,
    showDoctorSummary,
    showValidationDetails,
    showErrorDetails,
    showQuickFixes,
    maxQuickFixes,
  ];

  static const Set<String> allFields = {...canonicalFields};

  static String get suggestion =>
      'Use ${canonicalFields.take(canonicalFields.length - 1).join(', ')}, '
      'or ${canonicalFields.last}.';

  const ChartDiagnosticFallbackFields._();

  static List<Map<String, dynamic>> schemaJson() {
    return [for (final spec in fieldSpecs) spec.toJson()];
  }

  static bool isPreset(String value) {
    return presetValues.contains(value.trim().toLowerCase());
  }

  static bool isBooleanLike(Object? raw) => parseBool(raw) != null;

  static bool isNonNegativeIntegerLike(Object? raw) {
    return parseNonNegativeInt(raw) != null;
  }

  static bool containsAny(Map<Object?, Object?> map) {
    return allFields.any(map.containsKey);
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

  static int? parseNonNegativeInt(Object? raw) {
    final value = switch (raw) {
      int() => raw,
      num() when raw.isFinite => raw.toInt(),
      String() => int.tryParse(raw.trim()),
      _ => null,
    };
    if (value == null || value < 0) return null;
    return value;
  }

  static String path(String prefix, String field) {
    return prefix.isEmpty ? field : '$prefix.$field';
  }
}
