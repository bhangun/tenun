// Configuration validation for chart configs.
//
// Validates a [BaseChartConfig] before rendering and returns a [ValidationResult]
// with structured errors, warnings, and auto-fix suggestions.
//
// Usage:
// ```dart
// final result = ChartConfigValidator.validate(myConfig);
// if (!result.isValid) {
//   for (final e in result.errors) debugPrint('[ERROR] ${e.message}');
// }
// for (final w in result.warnings) debugPrint('[WARN] ${w.message}');
// final fixed = result.applyFixes(myConfig);
// ```

import 'dart:convert';

import 'base_config.dart';
import 'chart_diagnostic_fallback_fields.dart';
import 'chart_payload_normalization_fields.dart';
import 'chart_registry.dart';
import 'chart_runtime_policy_fields.dart';
import 'chart_type.dart';
import 'json_value.dart';
import '../registry/registry_tools.dart';

// ---------------------------------------------------------------------------
// ValidationIssue
// ---------------------------------------------------------------------------

enum ValidationSeverity { error, warning, info }

class ValidationIssue {
  final ValidationSeverity severity;
  final String code;
  final String message;
  final String? field;
  final String? suggestion;

  const ValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.field,
    this.suggestion,
  });

  bool get isError => severity == ValidationSeverity.error;
  bool get isWarning => severity == ValidationSeverity.warning;

  Map<String, dynamic> toJson() {
    return {
      'severity': severity.name,
      'code': code,
      'message': message,
      if (field != null) 'field': field,
      if (suggestion != null) 'suggestion': suggestion,
    };
  }

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] $code: $message'
      '${field != null ? ' (field: $field)' : ''}'
      '${suggestion != null ? '\n  → $suggestion' : ''}';
}

// ---------------------------------------------------------------------------
// ValidationResult
// ---------------------------------------------------------------------------

class ValidationResult {
  final List<ValidationIssue> issues;
  final ChartType type;

  const ValidationResult({required this.issues, required this.type});

  List<ValidationIssue> get errors => issues.where((i) => i.isError).toList();
  List<ValidationIssue> get warnings =>
      issues.where((i) => i.isWarning).toList();
  List<ValidationIssue> get infos =>
      issues.where((i) => i.severity == ValidationSeverity.info).toList();

  bool get isValid => errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  ValidationReport toReport({int maxIssues = 8}) {
    return ValidationReport.fromResult(this, maxIssues: maxIssues);
  }

  Map<String, dynamic> toJson() {
    return {
      'type': chartTypeToString(type),
      'isValid': isValid,
      'hasWarnings': hasWarnings,
      'issueCount': issues.length,
      'errorCount': errors.length,
      'warningCount': warnings.length,
      'infoCount': infos.length,
      'issues': issues.map((issue) => issue.toJson()).toList(growable: false),
    };
  }

  @override
  String toString() {
    if (issues.isEmpty) return 'ValidationResult: OK';
    return 'ValidationResult(${errors.length} errors, '
        '${warnings.length} warnings):\n'
        '${issues.map((i) => '  $i').join('\n')}';
  }
}

// ---------------------------------------------------------------------------
// ValidationReport
// ---------------------------------------------------------------------------

class ValidationReportIssue {
  final ValidationIssue issue;
  final int index;

  const ValidationReportIssue({required this.issue, required this.index});

  String get fieldPath => issue.field ?? r'$';

  bool get hasSuggestion =>
      issue.suggestion != null && issue.suggestion!.trim().isNotEmpty;

  String get displayText {
    final prefix = issue.field == null
        ? issue.code
        : '$fieldPath: ${issue.code}';
    return '$prefix - ${issue.message}';
  }

  String get suggestionText {
    if (hasSuggestion) return issue.suggestion!;
    switch (issue.severity) {
      case ValidationSeverity.error:
        return 'Fix this payload field before rendering in strict mode.';
      case ValidationSeverity.warning:
        return 'Review this field; rendering can continue but output may differ.';
      case ValidationSeverity.info:
        return 'No action required unless this behavior is unexpected.';
    }
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'severity': issue.severity.name,
    'code': issue.code,
    'fieldPath': fieldPath,
    'message': issue.message,
    'displayText': displayText,
    'suggestion': suggestionText,
    'hasExplicitSuggestion': hasSuggestion,
  };
}

class ValidationReport {
  final ChartType type;
  final List<ValidationIssue> issues;
  final int maxIssues;

  const ValidationReport({
    required this.type,
    required this.issues,
    this.maxIssues = 8,
  });

  factory ValidationReport.fromResult(
    ValidationResult result, {
    int maxIssues = 8,
  }) {
    return ValidationReport(
      type: result.type,
      issues: result.issues,
      maxIssues: maxIssues,
    );
  }

  List<ValidationIssue> get errors =>
      issues.where((issue) => issue.isError).toList(growable: false);

  List<ValidationIssue> get warnings =>
      issues.where((issue) => issue.isWarning).toList(growable: false);

  List<ValidationIssue> get infos => issues
      .where((issue) => issue.severity == ValidationSeverity.info)
      .toList(growable: false);

  bool get isValid => errors.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasIssues => issues.isNotEmpty;
  bool get hasMoreIssues => issues.length > normalizedMaxIssues;

  int get normalizedMaxIssues => maxIssues < 1 ? 1 : maxIssues;

  Iterable<ValidationIssue> get visibleIssues =>
      issues.take(normalizedMaxIssues);

  String get status {
    if (!isValid) return 'invalid';
    if (hasWarnings) return 'warning';
    return 'valid';
  }

  String get title {
    final typeName = chartTypeToString(type);
    switch (status) {
      case 'invalid':
        return 'Invalid $typeName chart payload';
      case 'warning':
        return '$typeName chart payload has warnings';
      default:
        return 'Valid $typeName chart payload';
    }
  }

  String get compactMessage {
    if (issues.isEmpty) return '$title.';
    final total = issues.length;
    final parts = <String>[];
    if (errors.isNotEmpty) {
      parts.add('${errors.length} error${errors.length == 1 ? '' : 's'}');
    }
    if (warnings.isNotEmpty) {
      parts.add('${warnings.length} warning${warnings.length == 1 ? '' : 's'}');
    }
    if (infos.isNotEmpty) {
      parts.add('${infos.length} info');
    }
    return '$title: ${parts.join(', ')} across $total issue${total == 1 ? '' : 's'}.';
  }

  Map<String, int> get counts => {
    'total': issues.length,
    'errors': errors.length,
    'warnings': warnings.length,
    'infos': infos.length,
    'visible': visibleIssues.length,
    'hidden': issues.length - visibleIssues.length,
  };

  List<String> get suggestions {
    final seen = <String>{};
    final output = <String>[];
    for (final issue in issues) {
      final text = ValidationReportIssue(
        issue: issue,
        index: output.length,
      ).suggestionText;
      if (seen.add(text)) output.add(text);
    }
    return output;
  }

  List<ValidationReportIssue> get visibleReportIssues {
    var index = 0;
    return [
      for (final issue in visibleIssues)
        ValidationReportIssue(issue: issue, index: index++),
    ];
  }

  String toPlainText({bool includeSuggestions = true}) {
    final lines = <String>[compactMessage];
    for (final issue in visibleReportIssues) {
      lines.add('- ${issue.displayText}');
      if (includeSuggestions) {
        lines.add('  Suggestion: ${issue.suggestionText}');
      }
    }
    if (hasMoreIssues) {
      lines.add(
        '- ${issues.length - normalizedMaxIssues} more issue${issues.length - normalizedMaxIssues == 1 ? '' : 's'} hidden.',
      );
    }
    return lines.join('\n');
  }

  Map<String, dynamic> toJson() => {
    'type': chartTypeToString(type),
    'status': status,
    'isValid': isValid,
    'title': title,
    'compactMessage': compactMessage,
    'counts': counts,
    'maxIssues': normalizedMaxIssues,
    'hasMoreIssues': hasMoreIssues,
    'issues': visibleReportIssues
        .map((issue) => issue.toJson())
        .toList(growable: false),
    'suggestions': suggestions,
  };
}

// ---------------------------------------------------------------------------
// PayloadDiff
// ---------------------------------------------------------------------------

enum PayloadDiffKind { added, removed, changed }

class PayloadDiff {
  final String path;
  final Object? rawValue;
  final Object? normalizedValue;
  final bool hasRawValue;
  final bool hasNormalizedValue;
  final int maxInlineLength;

  const PayloadDiff({
    required this.path,
    required this.rawValue,
    required this.normalizedValue,
    this.hasRawValue = true,
    this.hasNormalizedValue = true,
    this.maxInlineLength = 56,
  });

  PayloadDiffKind get kind {
    if (!hasRawValue) return PayloadDiffKind.added;
    if (!hasNormalizedValue) return PayloadDiffKind.removed;
    return PayloadDiffKind.changed;
  }

  String get rawText => hasRawValue
      ? valueToInline(rawValue, maxLength: maxInlineLength)
      : '<missing>';

  String get normalizedText => hasNormalizedValue
      ? valueToInline(normalizedValue, maxLength: maxInlineLength)
      : '<missing>';

  Map<String, dynamic> toJson({bool includeValues = false}) {
    return {
      'path': path,
      'kind': kind.name,
      'hasRawValue': hasRawValue,
      'hasNormalizedValue': hasNormalizedValue,
      'rawText': rawText,
      'normalizedText': normalizedText,
      if (includeValues && hasRawValue) 'rawValue': JsonValue.clone(rawValue),
      if (includeValues && hasNormalizedValue)
        'normalizedValue': JsonValue.clone(normalizedValue),
    };
  }

  static String valueToInline(Object? value, {int maxLength = 56}) {
    final safeLength = maxLength < 4 ? 4 : maxLength;
    String encoded;
    try {
      encoded = const JsonEncoder().convert(value);
    } catch (_) {
      encoded = value.toString();
    }
    if (encoded.length <= safeLength) return encoded;
    return '${encoded.substring(0, safeLength - 3)}...';
  }
}

class PayloadDiffSummary {
  final int added;
  final int removed;
  final int changed;

  const PayloadDiffSummary({
    required this.added,
    required this.removed,
    required this.changed,
  });

  factory PayloadDiffSummary.fromDiffs(Iterable<PayloadDiff> diffs) {
    var added = 0;
    var removed = 0;
    var changed = 0;
    for (final diff in diffs) {
      switch (diff.kind) {
        case PayloadDiffKind.added:
          added++;
          break;
        case PayloadDiffKind.removed:
          removed++;
          break;
        case PayloadDiffKind.changed:
          changed++;
          break;
      }
    }
    return PayloadDiffSummary(added: added, removed: removed, changed: changed);
  }

  int get total => added + removed + changed;
  bool get isEmpty => total == 0;
  bool get isNotEmpty => total > 0;

  String get compactLabel {
    if (isEmpty) return 'no payload changes';
    return '$total payload change${total == 1 ? '' : 's'} '
        '($added added, $removed removed, $changed changed)';
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'added': added,
      'removed': removed,
      'changed': changed,
      'compactLabel': compactLabel,
    };
  }
}

class PayloadNormalizationOptions {
  final bool dropUnsupportedSampling;
  final int? defaultThreshold;
  final ChartDataMode defaultMode;
  final bool sanitizeTradingPayload;
  final int maxInlineLength;

  const PayloadNormalizationOptions({
    this.dropUnsupportedSampling = true,
    this.defaultThreshold,
    this.defaultMode = ChartDataMode.auto,
    this.sanitizeTradingPayload = true,
    this.maxInlineLength = 56,
  });

  factory PayloadNormalizationOptions.fromJson(
    Object? raw, {
    PayloadNormalizationOptions fallback = const PayloadNormalizationOptions(),
  }) {
    if (raw is! Map) return fallback;
    final json = Map<Object?, Object?>.from(raw);
    return fallback.copyWith(
      dropUnsupportedSampling: ChartPayloadNormalizationFields.parseBool(
        json[ChartPayloadNormalizationFields.dropUnsupportedSampling],
      ),
      defaultThreshold: ChartPayloadNormalizationFields.parsePositiveInt(
        json[ChartPayloadNormalizationFields.defaultThreshold],
      ),
      defaultMode: _parseDataModeOption(
        json[ChartPayloadNormalizationFields.defaultMode],
      ),
      sanitizeTradingPayload: ChartPayloadNormalizationFields.parseBool(
        json[ChartPayloadNormalizationFields.sanitizeTradingPayload],
      ),
      maxInlineLength: ChartPayloadNormalizationFields.parsePositiveInt(
        json[ChartPayloadNormalizationFields.maxInlineLength],
      ),
    );
  }

  static PayloadNormalizationOptions resolve(
    Object? raw, {
    PayloadNormalizationOptions fallback = const PayloadNormalizationOptions(),
  }) {
    final match = _normalizationOptionsMatch(raw);
    if (match != null) {
      return PayloadNormalizationOptions.fromJson(match, fallback: fallback);
    }
    return PayloadNormalizationOptions.fromJson(raw, fallback: fallback);
  }

  static bool shouldAutoNormalize(Object? raw, {bool fallback = false}) {
    final direct = _autoNormalizeValue(raw);
    if (direct != null) return direct;
    final match = _normalizationOptionsMatch(raw);
    if (match is Map) {
      final map = Map<Object?, Object?>.from(match);
      return ChartPayloadNormalizationFields.parseBool(
            map[ChartPayloadNormalizationFields.autoNormalizePayload],
          ) ??
          fallback;
    }
    return fallback;
  }

  PayloadNormalizationOptions copyWith({
    bool? dropUnsupportedSampling,
    int? defaultThreshold,
    bool clearDefaultThreshold = false,
    ChartDataMode? defaultMode,
    bool? sanitizeTradingPayload,
    int? maxInlineLength,
  }) {
    return PayloadNormalizationOptions(
      dropUnsupportedSampling:
          dropUnsupportedSampling ?? this.dropUnsupportedSampling,
      defaultThreshold: clearDefaultThreshold
          ? null
          : (defaultThreshold ?? this.defaultThreshold),
      defaultMode: defaultMode ?? this.defaultMode,
      sanitizeTradingPayload:
          sanitizeTradingPayload ?? this.sanitizeTradingPayload,
      maxInlineLength: maxInlineLength ?? this.maxInlineLength,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ChartPayloadNormalizationFields.dropUnsupportedSampling:
          dropUnsupportedSampling,
      ChartPayloadNormalizationFields.defaultThreshold: defaultThreshold,
      ChartPayloadNormalizationFields.defaultMode: defaultMode.name,
      ChartPayloadNormalizationFields.sanitizeTradingPayload:
          sanitizeTradingPayload,
      ChartPayloadNormalizationFields.maxInlineLength: maxInlineLength,
    };
  }
}

Object? _normalizationOptionsMatch(Object? raw) {
  if (raw is! Map) return null;
  final json = Map<Object?, Object?>.from(raw);
  for (final key in ChartPayloadNormalizationFields.topLevelContainerFields) {
    if (json.containsKey(key)) return json[key];
  }

  final diagnostics = json[ChartPayloadNormalizationFields.diagnostics];
  if (diagnostics is! Map) return null;
  final diagnosticsJson = Map<Object?, Object?>.from(diagnostics);
  for (final key
      in ChartPayloadNormalizationFields.diagnosticsContainerFields) {
    if (diagnosticsJson.containsKey(key)) return diagnosticsJson[key];
  }
  return null;
}

bool? _autoNormalizeValue(Object? raw) {
  if (raw is! Map) return null;
  final json = Map<Object?, Object?>.from(raw);
  return ChartPayloadNormalizationFields.parseBool(
    json[ChartPayloadNormalizationFields.autoNormalizePayload],
  );
}

ChartDataMode? _parseDataModeOption(Object? raw) {
  if (raw is! String) return null;
  switch (raw.trim().toLowerCase()) {
    case 'regular':
    case 'simple':
      return ChartDataMode.regular;
    case 'large':
    case 'largedataset':
    case 'performance':
      return ChartDataMode.large;
    case 'auto':
      return ChartDataMode.auto;
    default:
      return null;
  }
}

class PayloadNormalizationResult {
  final Map<String, dynamic> rawPayload;
  final Map<String, dynamic> normalizedPayload;
  final bool wasNormalized;
  final List<PayloadDiff> diffs;

  const PayloadNormalizationResult({
    required this.rawPayload,
    required this.normalizedPayload,
    required this.wasNormalized,
    required this.diffs,
  });

  factory PayloadNormalizationResult.passThrough(Map<String, dynamic> payload) {
    return PayloadNormalizationResult(
      rawPayload: ChartConfigValidator._cloneJsonMap(payload),
      normalizedPayload: ChartConfigValidator._cloneJsonMap(payload),
      wasNormalized: false,
      diffs: const [],
    );
  }

  bool get changed => diffs.isNotEmpty;

  Map<String, dynamic> get effectivePayload => normalizedPayload;

  PayloadDiffSummary get summary => PayloadDiffSummary.fromDiffs(diffs);

  List<PayloadDiff> get addedDiffs => diffs
      .where((diff) => diff.kind == PayloadDiffKind.added)
      .toList(growable: false);

  List<PayloadDiff> get removedDiffs => diffs
      .where((diff) => diff.kind == PayloadDiffKind.removed)
      .toList(growable: false);

  List<PayloadDiff> get changedDiffs => diffs
      .where((diff) => diff.kind == PayloadDiffKind.changed)
      .toList(growable: false);

  List<String> get changedPaths =>
      diffs.map((diff) => diff.path).toList(growable: false);

  Map<String, dynamic> toJson({
    bool includePayloads = false,
    bool includeDiffValues = false,
  }) {
    return {
      'wasNormalized': wasNormalized,
      'changed': changed,
      'summary': summary.toJson(),
      'changedPaths': changedPaths,
      'diffs': diffs
          .map((diff) => diff.toJson(includeValues: includeDiffValues))
          .toList(growable: false),
      if (includePayloads) 'rawPayload': JsonValue.cloneMap(rawPayload),
      if (includePayloads)
        'normalizedPayload': JsonValue.cloneMap(normalizedPayload),
    };
  }
}

// ---------------------------------------------------------------------------
// ChartConfigValidator
// ---------------------------------------------------------------------------

class ChartConfigValidator {
  /// Validate [config] and return a [ValidationResult].
  static ValidationResult validate(BaseChartConfig config) {
    final issues = <ValidationIssue>[];
    final v = _Validator(config, issues);
    final usesSeriesData = !_typeUsesExternalDataModel(config.type);

    if (usesSeriesData) {
      v.checkSeriesNotEmpty();
      v.checkSeriesDataNotNull();
      v.checkDataLengthConsistency();
      v.checkNoNullValues();
      v.checkColorStrings();
    }
    v.checkTypeSpecificRules();
    v.checkAxisConfig();
    v.checkLegendConfig();

    return ValidationResult(issues: issues, type: config.type);
  }

  /// Validate raw JSON payload before/after parsing.
  ///
  /// When [deep] is true, validator also parses JSON into [BaseChartConfig]
  /// and runs type-specific config validation.
  static ValidationResult validateJsonPayload(
    Map<String, dynamic> json, {
    bool deep = true,
    bool requireRegisteredType = false,
  }) {
    final issues = <ValidationIssue>[];
    final rawType = (json['type'] ?? '').toString().trim();
    final parsedType = rawType.isEmpty ? ChartType.line : getChartType(rawType);

    if (rawType.isEmpty) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'MISSING_TYPE',
          message: 'Missing required field: "type".',
          field: 'type',
          suggestion: 'Provide chart type, e.g. "bar", "line", "pie".',
        ),
      );
    } else if (_isLikelyUnknownType(rawType, parsedType)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'UNKNOWN_TYPE',
          message: 'Unknown chart type "$rawType".',
          field: 'type',
          suggestion: _typeSuggestion(
            rawType,
            fallback: 'Use a supported chart type or register a custom type.',
          ),
        ),
      );
    }

    if (requireRegisteredType &&
        rawType.isNotEmpty &&
        !ChartRegistry.isRegisteredString(rawType)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'UNREGISTERED_TYPE',
          message: 'Chart type "$rawType" is not registered in ChartRegistry.',
          field: 'type',
          suggestion: _typeSuggestion(
            rawType,
            fallback: 'Register the type (or relevant bundle) before parsing.',
          ),
        ),
      );
    }

    final rawMode = json['dataMode'] ?? json['datasetMode'];
    final normalizedMode = rawMode is String
        ? rawMode.trim().toLowerCase()
        : null;
    if (rawMode != null) {
      if (rawMode is! String) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_DATA_MODE_TYPE',
            message: '"dataMode" must be a string.',
            field: 'dataMode',
            suggestion: 'Use one of: regular, auto, large.',
          ),
        );
      } else {
        const allowed = {
          'regular',
          'simple',
          'auto',
          'large',
          'largedataset',
          'performance',
        };
        if (!allowed.contains(normalizedMode)) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'INVALID_DATA_MODE_VALUE',
              message: 'Unsupported dataMode "$rawMode".',
              field: 'dataMode',
              suggestion: 'Use one of: regular, auto, large.',
            ),
          );
        }
      }
    }

    final rawSampling = json['sampling'];
    if (rawSampling != null) {
      if (rawSampling is! Map) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_SAMPLING_TYPE',
            message: '"sampling" must be an object.',
            field: 'sampling',
          ),
        );
      } else {
        final enabled = rawSampling['enabled'];
        if (enabled != null && enabled is! bool) {
          issues.add(
            const ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'INVALID_SAMPLING_ENABLED_TYPE',
              message: '"sampling.enabled" must be a boolean.',
              field: 'sampling.enabled',
            ),
          );
        }

        final threshold = rawSampling['threshold'];
        if (threshold != null) {
          if (threshold is! num) {
            issues.add(
              const ValidationIssue(
                severity: ValidationSeverity.error,
                code: 'INVALID_SAMPLING_THRESHOLD_TYPE',
                message: '"sampling.threshold" must be a number.',
                field: 'sampling.threshold',
              ),
            );
          } else {
            final t = _toPositiveInt(threshold);
            if (t == null) {
              issues.add(
                ValidationIssue(
                  severity: ValidationSeverity.error,
                  code: 'INVALID_SAMPLING_THRESHOLD_VALUE',
                  message:
                      '"sampling.threshold" must be a finite number greater than 0, got $threshold.',
                  field: 'sampling.threshold',
                  suggestion: 'Use 200-1500 for most cartesian charts.',
                ),
              );
            } else if (t < 10) {
              issues.add(
                ValidationIssue(
                  severity: ValidationSeverity.warning,
                  code: 'LOW_SAMPLING_THRESHOLD',
                  message:
                      '"sampling.threshold" is very low ($t) and may distort the chart.',
                  field: 'sampling.threshold',
                ),
              );
            }
          }
        }

        final strategy = rawSampling['strategy'];
        if (strategy != null) {
          if (strategy is! String) {
            issues.add(
              const ValidationIssue(
                severity: ValidationSeverity.error,
                code: 'INVALID_SAMPLING_STRATEGY_TYPE',
                message: '"sampling.strategy" must be a string.',
                field: 'sampling.strategy',
              ),
            );
          } else {
            final normalized = strategy.trim().toLowerCase();
            const allowed = {
              'auto',
              'lttb',
              'minmax',
              'min_max',
              'nth',
              'every_n',
            };
            if (!allowed.contains(normalized)) {
              issues.add(
                ValidationIssue(
                  severity: ValidationSeverity.error,
                  code: 'INVALID_SAMPLING_STRATEGY_VALUE',
                  message: 'Unsupported sampling strategy "$strategy".',
                  field: 'sampling.strategy',
                  suggestion: 'Use auto, lttb, minMax, or nth.',
                ),
              );
            }
          }
        }

        if (normalizedMode == 'regular') {
          if (enabled == true) {
            issues.add(
              const ValidationIssue(
                severity: ValidationSeverity.info,
                code: 'REGULAR_MODE_SAMPLING_IGNORED',
                message:
                    'dataMode "regular" ignores sampling settings for rendering.',
                field: 'sampling',
              ),
            );
          }
        }
      }
    }

    final samplingRequestedByMode =
        normalizedMode == 'large' ||
        normalizedMode == 'largedataset' ||
        normalizedMode == 'performance';
    final samplingRequestedByConfig =
        rawSampling != null &&
        (rawSampling is! Map ||
            rawSampling['enabled'] == true ||
            rawSampling.containsKey('threshold') ||
            rawSampling.containsKey('strategy'));
    final hasTypeError = issues.any(
      (i) => i.code == 'MISSING_TYPE' || i.code == 'UNKNOWN_TYPE',
    );
    if (!hasTypeError &&
        (samplingRequestedByMode || samplingRequestedByConfig) &&
        !_typeSupportsLargeDataSampling(parsedType)) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'SAMPLING_LIKELY_IGNORED_BY_TYPE',
          message:
              'Sampling/dataMode may be ignored for chart type "${chartTypeToString(parsedType)}".',
          field: 'sampling',
          suggestion:
              'Use this mainly on cartesian/trend/trading chart types, or keep dataMode as "regular".',
        ),
      );
    }

    _validateRuntimePerformancePolicyPayload(issues, json);
    _validateDiagnosticFallbackOptionsPayload(issues, json);
    _validatePayloadNormalizationOptionsPayload(issues, json);

    final structuralJson = normalizeDataCollectionPayload(json);
    final requiresSeries = _typeRequiresSeries(parsedType);
    final seriesRaw = structuralJson['series'];

    if (requiresSeries && seriesRaw == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'MISSING_SERIES',
          message: 'Missing required field: "series".',
          field: 'series',
          suggestion: 'Provide a non-empty series list.',
        ),
      );
    } else if (seriesRaw != null && seriesRaw is! List) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'INVALID_SERIES_TYPE',
          message: '"series" must be a List.',
          field: 'series',
        ),
      );
    } else if (seriesRaw is List) {
      if (requiresSeries && seriesRaw.isEmpty) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'EMPTY_SERIES',
            message: '"series" is empty.',
            field: 'series',
            suggestion: 'Add at least one series with data.',
          ),
        );
      }

      for (int i = 0; i < seriesRaw.length; i++) {
        final item = seriesRaw[i];
        if (item is! Map) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'INVALID_SERIES_ITEM',
              message: 'series[$i] must be a JSON object.',
              field: 'series[$i]',
            ),
          );
          continue;
        }
        if (item['data'] != null && item['data'] is! List) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'INVALID_DATA_TYPE',
              message: 'series[$i].data must be a List.',
              field: 'series[$i].data',
            ),
          );
        }
      }
    }

    final hasPayloadShapeError = issues.any(
      (issue) =>
          issue.code == 'MISSING_TYPE' ||
          issue.code == 'UNKNOWN_TYPE' ||
          issue.code == 'MISSING_SERIES' ||
          issue.code == 'INVALID_SERIES_TYPE' ||
          issue.code == 'INVALID_SERIES_ITEM' ||
          issue.code == 'INVALID_DATA_TYPE',
    );
    if (!hasPayloadShapeError) {
      _validateSeriesShapeCompatibility(issues, structuralJson, parsedType);
    }

    _validateBarRacePayload(issues, parsedType, json);
    _validateFinancialSeriesPayload(issues, parsedType, seriesRaw);
    _validateTradingSeriesPayload(
      issues,
      parsedType,
      structuralJson,
      seriesRaw,
    );

    if (deep && issues.where((e) => e.isError).isEmpty) {
      try {
        final config = BaseChartConfig.fromJson(structuralJson);
        final deepResult = validate(config);
        issues.addAll(deepResult.issues);
      } catch (e) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'PAYLOAD_PARSE_FAILED',
            message: 'Payload parsing failed: $e',
            suggestion:
                'Check JSON structure for this chart type and field names.',
          ),
        );
      }
    }

    return ValidationResult(issues: issues, type: parsedType);
  }

  /// Backward-compatible raw JSON validation helper.
  ///
  /// Prefer [validateJsonPayload] for structured result and deep checks.
  static List<String> validateJson(Map<String, dynamic> json) {
    final result = validateJsonPayload(json, deep: false);
    return result.errors.map((e) => e.message).toList(growable: false);
  }

  /// Normalize payload sampling/data mode into canonical and safe values.
  ///
  /// Canonical output:
  /// - `dataMode`: `regular` | `auto` | `large`
  /// - `sampling.strategy`: `auto` | `lttb` | `minMax` | `nth`
  ///
  /// Behavior:
  /// - Accepts aliases (`simple`, `largedataset`, `performance`, `min_max`,
  ///   `every_n`) and rewrites to canonical values.
  /// - Invalid/missing fields are replaced by safe defaults.
  /// - If [dropUnsupportedSampling] is true and chart type is likely not
  ///   sampling-capable, mode is downgraded to `regular` and sampling is
  ///   disabled.
  static Map<String, dynamic> normalizeSamplingPayload(
    Map<String, dynamic> json, {
    bool dropUnsupportedSampling = true,
    int? defaultThreshold,
    ChartDataMode defaultMode = ChartDataMode.auto,
    PayloadNormalizationOptions? options,
  }) {
    final effectiveOptions =
        options ??
        PayloadNormalizationOptions(
          dropUnsupportedSampling: dropUnsupportedSampling,
          defaultThreshold: defaultThreshold,
          defaultMode: defaultMode,
        );
    final out = Map<String, dynamic>.from(json);
    final rawType = (out['type'] ?? '').toString().trim();
    final parsedType = rawType.isEmpty ? ChartType.line : getChartType(rawType);

    final hasModeKey =
        out.containsKey('dataMode') || out.containsKey('datasetMode');
    final hasSamplingKey = out.containsKey('sampling');
    if (!hasModeKey && !hasSamplingKey) return out;

    final requestedMode = _canonicalDataModeString(
      out['dataMode'] ?? out['datasetMode'],
      fallback: effectiveOptions.defaultMode.name,
    );
    out.remove('datasetMode');

    final supportsSampling = _typeSupportsLargeDataSampling(parsedType);
    final effectiveMode =
        effectiveOptions.dropUnsupportedSampling && !supportsSampling
        ? 'regular'
        : requestedMode;
    out['dataMode'] = effectiveMode;

    final rawSampling = out['sampling'];
    final sampling = rawSampling is Map
        ? Map<String, dynamic>.from(rawSampling)
        : <String, dynamic>{};

    final thresholdBase = LargeDataSamplingConfig.normalizeThreshold(
      effectiveOptions.defaultThreshold ?? LargeDataSamplingConfig.threshold,
    );
    final thresholdRaw = sampling['threshold'];
    final thresholdCandidate = thresholdRaw is num
        ? _toPositiveInt(thresholdRaw)
        : null;
    final threshold = thresholdCandidate != null
        ? LargeDataSamplingConfig.normalizeThreshold(thresholdCandidate)
        : thresholdBase;
    final strategy = _canonicalSamplingStrategyString(sampling['strategy']);
    final enabledRaw = sampling['enabled'];
    final enabledCandidate = enabledRaw is bool
        ? enabledRaw
        : effectiveMode != 'regular';
    final enabled = effectiveMode == 'regular' ? false : enabledCandidate;

    sampling['enabled'] = enabled;
    sampling['threshold'] = threshold;
    sampling['strategy'] = strategy;
    out['sampling'] = sampling;

    return out;
  }

  /// Normalize both sampling/data-mode and trading payload shapes.
  ///
  /// This is the recommended normalizer before JSON parsing:
  /// - Calls [normalizeSamplingPayload]
  /// - Adds derived `series` for supported shorthand collection payloads
  /// - Optionally sanitizes trading payloads (`kagi`/`renko`/`macd`)
  static Map<String, dynamic> normalizePayload(
    Map<String, dynamic> json, {
    bool dropUnsupportedSampling = true,
    int? defaultThreshold,
    ChartDataMode defaultMode = ChartDataMode.auto,
    bool sanitizeTradingPayload = true,
    PayloadNormalizationOptions? options,
  }) {
    final effectiveOptions =
        options ??
        PayloadNormalizationOptions(
          dropUnsupportedSampling: dropUnsupportedSampling,
          defaultThreshold: defaultThreshold,
          defaultMode: defaultMode,
          sanitizeTradingPayload: sanitizeTradingPayload,
        );
    final sampled = normalizeSamplingPayload(json, options: effectiveOptions);
    final out = normalizeDataCollectionPayload(sampled);
    if (!effectiveOptions.sanitizeTradingPayload) return out;
    return normalizeTradingPayload(out);
  }

  /// Normalize shorthand collection payloads into the `series` shape expected
  /// by chart config factories, without removing the original shorthand fields.
  ///
  /// Examples:
  /// - `{type: "treemap", nodes: [...]}` -> `series: [{data: nodes}]`
  /// - `{type: "sankey", nodes: [...], links: [...]}` -> series node/link map
  /// - `{type: "calendar", dateValues: {"2026-01-01": 10}}` -> date rows
  static Map<String, dynamic> normalizeDataCollectionPayload(
    Map<String, dynamic> json,
  ) {
    final out = Map<String, dynamic>.from(json);
    final rawSeries = out['series'];
    if (rawSeries != null && (rawSeries is! List || rawSeries.isNotEmpty)) {
      return out;
    }

    final rawType = (out['type'] ?? '').toString().trim();
    final type = rawType.isEmpty ? ChartType.line : getChartType(rawType);
    final contract = chartPayloadContractForType(type);

    final normalizedSeries = _seriesFromPayloadContract(out, contract);

    if (normalizedSeries == null || normalizedSeries.isEmpty) return out;
    out['series'] = normalizedSeries;
    return out;
  }

  /// Normalize payload and include a diff report for diagnostics/tooling.
  static PayloadNormalizationResult normalizePayloadWithReport(
    Map<String, dynamic> json, {
    bool dropUnsupportedSampling = true,
    int? defaultThreshold,
    ChartDataMode defaultMode = ChartDataMode.auto,
    bool sanitizeTradingPayload = true,
    int maxInlineLength = 56,
    PayloadNormalizationOptions? options,
  }) {
    final effectiveOptions =
        options ??
        PayloadNormalizationOptions(
          dropUnsupportedSampling: dropUnsupportedSampling,
          defaultThreshold: defaultThreshold,
          defaultMode: defaultMode,
          sanitizeTradingPayload: sanitizeTradingPayload,
          maxInlineLength: maxInlineLength,
        );
    final raw = _cloneJsonMap(json);
    final normalized = normalizePayload(raw, options: effectiveOptions);
    final normalizedCopy = _cloneJsonMap(normalized);
    return PayloadNormalizationResult(
      rawPayload: raw,
      normalizedPayload: normalizedCopy,
      wasNormalized: true,
      diffs: diffPayloads(
        raw,
        normalizedCopy,
        maxInlineLength: effectiveOptions.maxInlineLength,
      ),
    );
  }

  /// Return changed JSON paths between [raw] and [normalized].
  ///
  /// This is useful for developer tooling and previews that need to explain
  /// what [normalizePayload] changed before rendering.
  static List<PayloadDiff> diffPayloads(
    Object? raw,
    Object? normalized, {
    int maxInlineLength = 56,
  }) {
    final out = <PayloadDiff>[];
    _collectPayloadDiffsRecursive(raw, normalized, r'$', out, maxInlineLength);
    return out;
  }

  /// Normalize trading payloads used by `kagi`, `renko`, and `macd`.
  ///
  /// - Converts mixed rows into numeric price series where possible.
  /// - Enforces positive parameters:
  ///   - `kagi.reversalPct > 0` (fallback: 4)
  ///   - `renko.brickSize > 0` (fallback: 1)
  ///   - `macd.fast/slow/signal > 0` (fallbacks: 12/26/9)
  /// - Ensures `macd.fast < macd.slow` by shifting `slow` when needed.
  static Map<String, dynamic> normalizeTradingPayload(
    Map<String, dynamic> json,
  ) {
    final out = Map<String, dynamic>.from(json);
    final rawType = (out['type'] ?? '').toString().trim();
    if (rawType.isEmpty) return out;
    final type = getChartType(rawType);
    if (type != ChartType.kagi &&
        type != ChartType.renko &&
        type != ChartType.macd) {
      return out;
    }

    final mutableSeries = _mutableSeriesList(out['series']);
    if (mutableSeries != null && mutableSeries.isNotEmpty) {
      final first = mutableSeries.first;
      final rawData = first['data'];
      if (rawData is List) {
        first['data'] = _normalizeTradingPriceSeries(rawData);
        out['series'] = mutableSeries;
      }
    }

    switch (type) {
      case ChartType.kagi:
        out['reversalPct'] = _toPositiveDouble(out['reversalPct']) ?? 4.0;
        break;
      case ChartType.renko:
        out['brickSize'] = _toPositiveDouble(out['brickSize']) ?? 1.0;
        break;
      case ChartType.macd:
        final fast = _toPositiveInt(out['fast']) ?? 12;
        final signal = _toPositiveInt(out['signal']) ?? 9;
        var slow = _toPositiveInt(out['slow']) ?? 26;
        if (fast >= slow) {
          slow = fast + 1;
        }
        out['fast'] = fast;
        out['slow'] = slow;
        out['signal'] = signal;
        break;
      default:
        break;
    }

    return out;
  }

  static List<Map<String, dynamic>>? _seriesFromPayloadContract(
    Map<String, dynamic> json,
    ChartPayloadContract contract,
  ) {
    switch (contract.seriesStrategy) {
      case ChartPayloadSeriesStrategy.dataFields:
        return _singleDataSeriesFromAny(json, contract.dataFieldPriority);
      case ChartPayloadSeriesStrategy.namedCollection:
        final field = contract.namedCollectionField;
        return field == null ? null : _singleNamedCollectionSeries(json, field);
      case ChartPayloadSeriesStrategy.nodeLink:
        return _nodeLinkSeries(json);
      case ChartPayloadSeriesStrategy.calendarDateValues:
        return _calendarSeries(json);
      case ChartPayloadSeriesStrategy.ringSlices:
        return _ringSeries(json);
      case ChartPayloadSeriesStrategy.partitionPie:
        return _partitionPieSeries(json);
    }
  }

  static List<Map<String, dynamic>>? _singleDataSeriesFromAny(
    Map<String, dynamic> json,
    List<String> fieldPriority,
  ) {
    for (final field in fieldPriority) {
      final value = json[field];
      if (value is List) {
        return [
          {'data': _cloneJsonValue(value)},
        ];
      }
    }
    return null;
  }

  static List<Map<String, dynamic>>? _singleNamedCollectionSeries(
    Map<String, dynamic> json,
    String field,
  ) {
    final value = json[field];
    if (value is! List) return null;
    return [
      {field: _cloneJsonValue(value)},
    ];
  }

  static List<Map<String, dynamic>>? _nodeLinkSeries(
    Map<String, dynamic> json,
  ) {
    final nodes = json['nodes'];
    final links = json['links'];
    if (nodes is! List && links is! List) return null;
    return [
      {
        if (nodes is List) 'nodes': _cloneJsonValue(nodes),
        if (links is List) 'links': _cloneJsonValue(links),
      },
    ];
  }

  static List<Map<String, dynamic>>? _calendarSeries(
    Map<String, dynamic> json,
  ) {
    final dataSeries = _singleDataSeriesFromAny(json, const ['data']);
    if (dataSeries != null) return dataSeries;

    final dateValues = json['dateValues'];
    if (dateValues is! Map) return null;
    return [
      {
        'data': [
          for (final entry in dateValues.entries)
            {
              'date': entry.key.toString(),
              'value': _cloneJsonValue(entry.value),
            },
        ],
      },
    ];
  }

  static List<Map<String, dynamic>>? _ringSeries(Map<String, dynamic> json) {
    final rings = json['rings'];
    if (rings is! List) return null;
    final out = <Map<String, dynamic>>[];
    for (final ring in rings) {
      if (ring is Map) {
        final slices = ring['slices'];
        if (slices is List) {
          out.add({
            if (ring['name'] != null) 'name': ring['name'].toString(),
            'data': _cloneJsonValue(slices),
          });
        }
      }
    }
    return out.isEmpty ? null : out;
  }

  static List<Map<String, dynamic>>? _partitionPieSeries(
    Map<String, dynamic> json,
  ) {
    final mainSlices = json['mainSlices'];
    final subSlices = json['subSlices'];
    final out = <Map<String, dynamic>>[];
    if (mainSlices is List) {
      out.add({'name': 'main', 'data': _cloneJsonValue(mainSlices)});
    }
    if (subSlices is List) {
      out.add({'name': 'partition', 'data': _cloneJsonValue(subSlices)});
    }
    return out.isEmpty ? null : out;
  }

  static List<Map<String, dynamic>>? _mutableSeriesList(Object? rawSeries) {
    if (rawSeries is! List || rawSeries.isEmpty) return null;
    final out = <Map<String, dynamic>>[];
    for (final item in rawSeries) {
      if (item is Map) {
        out.add(Map<String, dynamic>.from(item));
      }
    }
    if (out.isEmpty) return null;
    return out;
  }

  static List<double> _normalizeTradingPriceSeries(List rawData) {
    final prices = <double>[];
    for (final row in rawData) {
      final direct = _toDouble(row);
      if (direct != null) {
        prices.add(direct);
        continue;
      }

      if (row is Map) {
        final mapped =
            _toDouble(row['price']) ??
            _toDouble(row['close']) ??
            _toDouble(row['value']) ??
            _toDouble(row['y']);
        if (mapped != null) {
          prices.add(mapped);
        }
        continue;
      }

      if (row is List && row.isNotEmpty) {
        final tuple = row.length >= 4 ? _toDouble(row[3]) : _toDouble(row.last);
        if (tuple != null) {
          prices.add(tuple);
        }
      }
    }
    return prices;
  }

  static void _collectPayloadDiffsRecursive(
    Object? raw,
    Object? normalized,
    String path,
    List<PayloadDiff> out,
    int maxInlineLength,
  ) {
    if (raw is Map && normalized is Map) {
      final keys = <String>{
        ...raw.keys.map((k) => k.toString()),
        ...normalized.keys.map((k) => k.toString()),
      }.toList()..sort();

      for (final key in keys) {
        final hasRaw = raw.containsKey(key);
        final hasNormalized = normalized.containsKey(key);
        final childPath = '$path.$key';
        if (!hasRaw) {
          out.add(
            PayloadDiff(
              path: childPath,
              rawValue: null,
              normalizedValue: normalized[key],
              hasRawValue: false,
              maxInlineLength: maxInlineLength,
            ),
          );
          continue;
        }
        if (!hasNormalized) {
          out.add(
            PayloadDiff(
              path: childPath,
              rawValue: raw[key],
              normalizedValue: null,
              hasNormalizedValue: false,
              maxInlineLength: maxInlineLength,
            ),
          );
          continue;
        }
        _collectPayloadDiffsRecursive(
          raw[key],
          normalized[key],
          childPath,
          out,
          maxInlineLength,
        );
      }
      return;
    }

    if (raw is List && normalized is List) {
      final maxLen = raw.length > normalized.length
          ? raw.length
          : normalized.length;
      for (var i = 0; i < maxLen; i++) {
        final childPath = '$path[$i]';
        if (i >= raw.length) {
          out.add(
            PayloadDiff(
              path: childPath,
              rawValue: null,
              normalizedValue: normalized[i],
              hasRawValue: false,
              maxInlineLength: maxInlineLength,
            ),
          );
          continue;
        }
        if (i >= normalized.length) {
          out.add(
            PayloadDiff(
              path: childPath,
              rawValue: raw[i],
              normalizedValue: null,
              hasNormalizedValue: false,
              maxInlineLength: maxInlineLength,
            ),
          );
          continue;
        }
        _collectPayloadDiffsRecursive(
          raw[i],
          normalized[i],
          childPath,
          out,
          maxInlineLength,
        );
      }
      return;
    }

    if (!_jsonValueEquals(raw, normalized)) {
      out.add(
        PayloadDiff(
          path: path,
          rawValue: raw,
          normalizedValue: normalized,
          maxInlineLength: maxInlineLength,
        ),
      );
    }
  }

  static bool _jsonValueEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key)) return false;
        if (!_jsonValueEquals(entry.value, b[entry.key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_jsonValueEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  static Map<String, dynamic> _cloneJsonMap(Map<String, dynamic> value) {
    return JsonValue.cloneMap(value);
  }

  static Object? _cloneJsonValue(Object? value) => JsonValue.clone(value);

  static double? _toDouble(Object? raw) {
    final parsed = raw is num
        ? raw.toDouble()
        : raw is String
        ? double.tryParse(raw.trim())
        : null;
    return parsed != null && parsed.isFinite ? parsed : null;
  }

  static int? _toPositiveInt(Object? raw) {
    if (raw is num) {
      if (!raw.toDouble().isFinite) return null;
      final v = raw.toInt();
      if (v > 0) return v;
    }
    if (raw is String) {
      final v = int.tryParse(raw.trim());
      if (v != null && v > 0) return v;
    }
    return null;
  }

  static double? _toPositiveDouble(Object? raw) {
    final v = _toDouble(raw);
    if (v == null || v <= 0) return null;
    return v;
  }

  static void _validateRuntimePerformancePolicyPayload(
    List<ValidationIssue> issues,
    Map<String, dynamic> json,
  ) {
    if (_containsRuntimePolicyField(json)) {
      _validateRuntimePerformancePolicyMap(issues, json, '');
    }

    _validateRuntimePerformancePolicyContainer(
      issues,
      json['runtimePerformancePolicy'],
      'runtimePerformancePolicy',
    );
    _validateRuntimePerformancePolicyContainer(
      issues,
      json['performancePolicy'],
      'performancePolicy',
    );
    _validateRuntimePerformancePolicyEnvelope(
      issues,
      json['diagnostics'],
      'diagnostics',
    );
    _validateRuntimePerformancePolicyEnvelope(
      issues,
      json['runtimeDiagnostics'],
      'runtimeDiagnostics',
    );
  }

  static void _validateRuntimePerformancePolicyEnvelope(
    List<ValidationIssue> issues,
    Object? raw,
    String field,
  ) {
    if (raw == null) return;
    if (raw is! Map) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'INVALID_RUNTIME_DIAGNOSTICS_TYPE',
          message: '"$field" must be an object when configuring diagnostics.',
          field: field,
        ),
      );
      return;
    }

    final map = Map<Object?, Object?>.from(raw);
    if (_containsRuntimePolicyField(map)) {
      _validateRuntimePerformancePolicyMap(issues, map, field);
    }
    _validateRuntimePerformancePolicyContainer(
      issues,
      map['performancePolicy'],
      '$field.performancePolicy',
    );
    _validateRuntimePerformancePolicyContainer(
      issues,
      map['runtimePerformancePolicy'],
      '$field.runtimePerformancePolicy',
    );
  }

  static void _validateRuntimePerformancePolicyContainer(
    List<ValidationIssue> issues,
    Object? raw,
    String field,
  ) {
    if (raw == null) return;
    if (raw is! Map) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'INVALID_RUNTIME_PERFORMANCE_POLICY_TYPE',
          message: '"$field" must be an object.',
          field: field,
        ),
      );
      return;
    }
    final map = Map<Object?, Object?>.from(raw);
    _warnUnknownRuntimePolicyFields(issues, map, field);
    _validateRuntimePerformancePolicyMap(issues, map, field);
  }

  static void _validateRuntimePerformancePolicyMap(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
  ) {
    for (final spec in ChartRuntimePerformancePolicyFields.fieldSpecs) {
      switch (spec.kind) {
        case ChartRuntimePerformancePolicyFieldKind.positiveInteger:
          _validateRuntimePolicyPositiveInt(
            issues,
            map,
            fieldPrefix,
            spec.aliases,
          );
          break;
        case ChartRuntimePerformancePolicyFieldKind.unitRatio:
          _validateRuntimePolicyRatio(issues, map, fieldPrefix, spec.aliases);
          break;
      }
    }
  }

  static void _validateRuntimePolicyPositiveInt(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
    List<String> aliases,
  ) {
    final field = ChartRuntimePerformancePolicyFields.firstField(map, aliases);
    if (field == null) return;
    final raw = map[field];
    final value = _toPositiveInt(raw);
    if (value != null) return;

    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'INVALID_RUNTIME_POLICY_INTEGER',
        message:
            '"${ChartRuntimePerformancePolicyFields.path(fieldPrefix, field)}" must be a positive integer.',
        field: ChartRuntimePerformancePolicyFields.path(fieldPrefix, field),
      ),
    );
  }

  static void _validateRuntimePolicyRatio(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
    List<String> aliases,
  ) {
    final field = ChartRuntimePerformancePolicyFields.firstField(map, aliases);
    if (field == null) return;
    final raw = map[field];
    final value = ChartRuntimePerformancePolicyFields.parseRatio(raw);
    if (value != null && value >= 0 && value <= 1) return;

    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'INVALID_RUNTIME_POLICY_RATIO',
        message:
            '"${ChartRuntimePerformancePolicyFields.path(fieldPrefix, field)}" must be a ratio between 0 and 1, or a percent string like "85%".',
        field: ChartRuntimePerformancePolicyFields.path(fieldPrefix, field),
      ),
    );
  }

  static bool _containsRuntimePolicyField(Map<Object?, Object?> map) {
    return ChartRuntimePerformancePolicyFields.containsAny(map);
  }

  static void _warnUnknownRuntimePolicyFields(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
  ) {
    for (final key in map.keys) {
      final field = key.toString();
      if (ChartRuntimePerformancePolicyFields.allAliases.contains(field)) {
        continue;
      }
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'UNKNOWN_RUNTIME_POLICY_FIELD',
          message:
              '"${ChartRuntimePerformancePolicyFields.path(fieldPrefix, field)}" is not a recognized runtime performance policy field.',
          field: ChartRuntimePerformancePolicyFields.path(fieldPrefix, field),
          suggestion: ChartRuntimePerformancePolicyFields.suggestion,
        ),
      );
    }
  }

  static void _validateDiagnosticFallbackOptionsPayload(
    List<ValidationIssue> issues,
    Map<String, dynamic> json,
  ) {
    for (final field in ChartDiagnosticFallbackFields.topLevelContainerFields) {
      _validateDiagnosticFallbackOptionsContainer(issues, json[field], field);
    }

    final diagnostics = json[ChartDiagnosticFallbackFields.diagnostics];
    if (diagnostics is! Map) return;

    final diagnosticsJson = Map<Object?, Object?>.from(diagnostics);
    for (final field
        in ChartDiagnosticFallbackFields.diagnosticsContainerFields) {
      _validateDiagnosticFallbackOptionsContainer(
        issues,
        diagnosticsJson[field],
        ChartDiagnosticFallbackFields.path(
          ChartDiagnosticFallbackFields.diagnostics,
          field,
        ),
      );
    }
  }

  static void _validateDiagnosticFallbackOptionsContainer(
    List<ValidationIssue> issues,
    Object? raw,
    String field,
  ) {
    if (raw == null) return;
    if (raw is String) {
      _validateDiagnosticFallbackPresetValue(issues, raw, field);
      return;
    }
    if (raw is! Map) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'INVALID_DIAGNOSTIC_FALLBACK_TYPE',
          message:
              '"$field" must be an object or one of the supported preset names.',
          field: field,
          suggestion:
              'Use "compact", "quiet", "production", or a fallback options object.',
        ),
      );
      return;
    }

    final map = Map<Object?, Object?>.from(raw);
    _warnUnknownDiagnosticFallbackFields(issues, map, field);
    _validateDiagnosticFallbackMap(issues, map, field);
  }

  static void _validateDiagnosticFallbackMap(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
  ) {
    _validateDiagnosticFallbackPreset(
      issues,
      map,
      fieldPrefix,
      ChartDiagnosticFallbackFields.preset,
    );
    _validateDiagnosticFallbackString(
      issues,
      map,
      fieldPrefix,
      ChartDiagnosticFallbackFields.title,
    );
    _validateDiagnosticFallbackString(
      issues,
      map,
      fieldPrefix,
      ChartDiagnosticFallbackFields.message,
    );
    _validateDiagnosticFallbackString(
      issues,
      map,
      fieldPrefix,
      ChartDiagnosticFallbackFields.detailMessage,
    );
    _validateDiagnosticFallbackBool(
      issues,
      map,
      fieldPrefix,
      ChartDiagnosticFallbackFields.showDoctorSummary,
    );
    _validateDiagnosticFallbackBool(
      issues,
      map,
      fieldPrefix,
      ChartDiagnosticFallbackFields.showValidationDetails,
    );
    _validateDiagnosticFallbackBool(
      issues,
      map,
      fieldPrefix,
      ChartDiagnosticFallbackFields.showErrorDetails,
    );
    _validateDiagnosticFallbackBool(
      issues,
      map,
      fieldPrefix,
      ChartDiagnosticFallbackFields.showQuickFixes,
    );
    _validateDiagnosticFallbackMaxQuickFixes(
      issues,
      map,
      fieldPrefix,
      ChartDiagnosticFallbackFields.maxQuickFixes,
    );
  }

  static void _validateDiagnosticFallbackPreset(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
    String field,
  ) {
    if (!map.containsKey(field)) return;
    final raw = map[field];
    final path = ChartDiagnosticFallbackFields.path(fieldPrefix, field);
    if (raw is! String) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'INVALID_DIAGNOSTIC_FALLBACK_PRESET_TYPE',
          message: '"$path" must be a string preset name.',
          field: path,
          suggestion: 'Use compact, quiet, production, or defaults.',
        ),
      );
      return;
    }
    _validateDiagnosticFallbackPresetValue(issues, raw, path);
  }

  static void _validateDiagnosticFallbackPresetValue(
    List<ValidationIssue> issues,
    String raw,
    String field,
  ) {
    if (ChartDiagnosticFallbackFields.isPreset(raw)) return;
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.warning,
        code: 'UNKNOWN_DIAGNOSTIC_FALLBACK_PRESET',
        message: '"$field" uses an unknown diagnostic fallback preset "$raw".',
        field: field,
        suggestion: 'Use compact, quiet, production, or defaults.',
      ),
    );
  }

  static void _validateDiagnosticFallbackString(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
    String field,
  ) {
    if (!map.containsKey(field) || map[field] is String) return;
    final path = ChartDiagnosticFallbackFields.path(fieldPrefix, field);
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'INVALID_DIAGNOSTIC_FALLBACK_STRING',
        message: '"$path" must be a string.',
        field: path,
      ),
    );
  }

  static void _validateDiagnosticFallbackBool(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
    String field,
  ) {
    if (!map.containsKey(field) ||
        ChartDiagnosticFallbackFields.isBooleanLike(map[field])) {
      return;
    }
    final path = ChartDiagnosticFallbackFields.path(fieldPrefix, field);
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'INVALID_DIAGNOSTIC_FALLBACK_BOOLEAN',
        message: '"$path" must be a boolean or boolean-like value.',
        field: path,
        suggestion: 'Use true/false, yes/no, or 1/0.',
      ),
    );
  }

  static void _validateDiagnosticFallbackMaxQuickFixes(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
    String field,
  ) {
    if (!map.containsKey(field) ||
        ChartDiagnosticFallbackFields.isNonNegativeIntegerLike(map[field])) {
      return;
    }
    final path = ChartDiagnosticFallbackFields.path(fieldPrefix, field);
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'INVALID_DIAGNOSTIC_FALLBACK_MAX_QUICK_FIXES',
        message: '"$path" must be a non-negative integer.',
        field: path,
      ),
    );
  }

  static void _warnUnknownDiagnosticFallbackFields(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
  ) {
    for (final key in map.keys) {
      final field = key.toString();
      if (ChartDiagnosticFallbackFields.allFields.contains(field)) continue;
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'UNKNOWN_DIAGNOSTIC_FALLBACK_FIELD',
          message:
              '"${ChartDiagnosticFallbackFields.path(fieldPrefix, field)}" is not a recognized diagnostic fallback option.',
          field: ChartDiagnosticFallbackFields.path(fieldPrefix, field),
          suggestion: ChartDiagnosticFallbackFields.suggestion,
        ),
      );
    }
  }

  static void _validatePayloadNormalizationOptionsPayload(
    List<ValidationIssue> issues,
    Map<String, dynamic> json,
  ) {
    _validatePayloadNormalizationBool(
      issues,
      json,
      '',
      ChartPayloadNormalizationFields.autoNormalizePayload,
    );

    for (final field
        in ChartPayloadNormalizationFields.topLevelContainerFields) {
      _validatePayloadNormalizationContainer(issues, json[field], field);
    }

    final diagnostics = json[ChartPayloadNormalizationFields.diagnostics];
    if (diagnostics is! Map) return;

    final diagnosticsJson = Map<Object?, Object?>.from(diagnostics);
    for (final field
        in ChartPayloadNormalizationFields.diagnosticsContainerFields) {
      _validatePayloadNormalizationContainer(
        issues,
        diagnosticsJson[field],
        ChartPayloadNormalizationFields.path(
          ChartPayloadNormalizationFields.diagnostics,
          field,
        ),
      );
    }
  }

  static void _validatePayloadNormalizationContainer(
    List<ValidationIssue> issues,
    Object? raw,
    String field,
  ) {
    if (raw == null) return;
    if (raw is! Map) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'INVALID_PAYLOAD_NORMALIZATION_TYPE',
          message: '"$field" must be an object.',
          field: field,
          suggestion: 'Use a payload normalization options object.',
        ),
      );
      return;
    }

    final map = Map<Object?, Object?>.from(raw);
    _warnUnknownPayloadNormalizationFields(issues, map, field);
    _validatePayloadNormalizationMap(issues, map, field);
  }

  static void _validatePayloadNormalizationMap(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
  ) {
    _validatePayloadNormalizationBool(
      issues,
      map,
      fieldPrefix,
      ChartPayloadNormalizationFields.autoNormalizePayload,
    );
    _validatePayloadNormalizationBool(
      issues,
      map,
      fieldPrefix,
      ChartPayloadNormalizationFields.dropUnsupportedSampling,
    );
    _validatePayloadNormalizationPositiveInt(
      issues,
      map,
      fieldPrefix,
      ChartPayloadNormalizationFields.defaultThreshold,
    );
    _validatePayloadNormalizationDataMode(
      issues,
      map,
      fieldPrefix,
      ChartPayloadNormalizationFields.defaultMode,
    );
    _validatePayloadNormalizationBool(
      issues,
      map,
      fieldPrefix,
      ChartPayloadNormalizationFields.sanitizeTradingPayload,
    );
    _validatePayloadNormalizationPositiveInt(
      issues,
      map,
      fieldPrefix,
      ChartPayloadNormalizationFields.maxInlineLength,
    );
  }

  static void _validatePayloadNormalizationBool(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
    String field,
  ) {
    if (!map.containsKey(field) ||
        ChartPayloadNormalizationFields.isBooleanLike(map[field])) {
      return;
    }
    final path = ChartPayloadNormalizationFields.path(fieldPrefix, field);
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'INVALID_PAYLOAD_NORMALIZATION_BOOLEAN',
        message: '"$path" must be a boolean or boolean-like value.',
        field: path,
        suggestion: 'Use true/false, yes/no, or 1/0.',
      ),
    );
  }

  static void _validatePayloadNormalizationPositiveInt(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
    String field,
  ) {
    if (!map.containsKey(field) ||
        ChartPayloadNormalizationFields.isPositiveIntegerLike(map[field])) {
      return;
    }
    final path = ChartPayloadNormalizationFields.path(fieldPrefix, field);
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'INVALID_PAYLOAD_NORMALIZATION_INTEGER',
        message: '"$path" must be a positive integer.',
        field: path,
      ),
    );
  }

  static void _validatePayloadNormalizationDataMode(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
    String field,
  ) {
    if (!map.containsKey(field) ||
        ChartPayloadNormalizationFields.isDataMode(map[field])) {
      return;
    }
    final path = ChartPayloadNormalizationFields.path(fieldPrefix, field);
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'INVALID_PAYLOAD_NORMALIZATION_DATA_MODE',
        message: '"$path" must be one of regular, auto, or large.',
        field: path,
      ),
    );
  }

  static void _warnUnknownPayloadNormalizationFields(
    List<ValidationIssue> issues,
    Map<Object?, Object?> map,
    String fieldPrefix,
  ) {
    for (final key in map.keys) {
      final field = key.toString();
      if (ChartPayloadNormalizationFields.allFields.contains(field)) continue;
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'UNKNOWN_PAYLOAD_NORMALIZATION_FIELD',
          message:
              '"${ChartPayloadNormalizationFields.path(fieldPrefix, field)}" is not a recognized payload normalization option.',
          field: ChartPayloadNormalizationFields.path(fieldPrefix, field),
          suggestion: ChartPayloadNormalizationFields.suggestion,
        ),
      );
    }
  }

  static bool _typeRequiresSeries(ChartType type) {
    return chartPayloadContractForType(type).requiresSeries;
  }

  static bool _typeUsesExternalDataModel(ChartType type) {
    return chartPayloadContractForType(type).usesExternalDataModel;
  }

  static void _validateBarRacePayload(
    List<ValidationIssue> issues,
    ChartType type,
    Map<String, dynamic> json,
  ) {
    if (type != ChartType.barRace) return;

    final labels = <String>{};
    final rawCategories = json['categories'];
    final categories = <String>[];
    if (rawCategories != null) {
      if (rawCategories is! List) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_BAR_RACE_CATEGORIES_TYPE',
            message:
                '"categories" must be a List for shorthand bar race frames.',
            field: 'categories',
          ),
        );
      } else {
        for (final category in rawCategories) {
          final label = category.toString();
          categories.add(label);
          labels.add(label);
        }
      }
    }

    final rawFrames = json['frames'];
    if (rawFrames == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'MISSING_BAR_RACE_FRAMES',
          message: 'Bar race payload requires a non-empty "frames" list.',
          field: 'frames',
          suggestion:
              'Use frames as [{label, values:{name:value}}] or shorthand lists with categories.',
        ),
      );
    } else if (rawFrames is! List) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'INVALID_BAR_RACE_FRAMES_TYPE',
          message: '"frames" must be a List.',
          field: 'frames',
        ),
      );
    } else if (rawFrames.isEmpty) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'EMPTY_BAR_RACE_FRAMES',
          message: '"frames" is empty; the bar race chart will render blank.',
          field: 'frames',
        ),
      );
    } else {
      for (int i = 0; i < rawFrames.length; i++) {
        final frame = rawFrames[i];
        if (frame is List) {
          if (categories.isEmpty) {
            issues.add(
              ValidationIssue(
                severity: ValidationSeverity.error,
                code: 'MISSING_BAR_RACE_CATEGORIES',
                message:
                    'frames[$i] uses shorthand list values, so "categories" is required.',
                field: 'categories',
              ),
            );
            continue;
          }
          if (frame.length != categories.length) {
            issues.add(
              ValidationIssue(
                severity: ValidationSeverity.error,
                code: 'BAR_RACE_FRAME_CATEGORY_MISMATCH',
                message:
                    'frames[$i] has ${frame.length} value(s), but categories has ${categories.length}.',
                field: 'frames[$i]',
                suggestion:
                    'Keep every shorthand frame length equal to categories.length.',
              ),
            );
          }
          _validateNumericListValues(issues, frame, 'frames[$i]');
          continue;
        }

        if (frame is Map) {
          final frameMap = Map<Object?, Object?>.from(frame);
          final values = frameMap.containsKey('values')
              ? frameMap['values']
              : frameMap;
          if (values is! Map) {
            issues.add(
              ValidationIssue(
                severity: ValidationSeverity.error,
                code: 'INVALID_BAR_RACE_VALUES_TYPE',
                message:
                    'frames[$i].values must be an object mapping labels to numeric values.',
                field: 'frames[$i].values',
              ),
            );
            continue;
          }

          var numericValueCount = 0;
          values.forEach((key, value) {
            if (key == 'label') return;
            labels.add(key.toString());
            numericValueCount++;
            if (_toDouble(value) == null) {
              issues.add(
                ValidationIssue(
                  severity: ValidationSeverity.error,
                  code: 'BAR_RACE_NON_NUMERIC_VALUE',
                  message:
                      'frames[$i].values["$key"] must be numeric or a numeric string.',
                  field: 'frames[$i].values.$key',
                ),
              );
            }
          });

          if (numericValueCount == 0) {
            issues.add(
              ValidationIssue(
                severity: ValidationSeverity.warning,
                code: 'EMPTY_BAR_RACE_FRAME_VALUES',
                message: 'frames[$i] has no bar values.',
                field: 'frames[$i]',
              ),
            );
          }
          continue;
        }

        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_BAR_RACE_FRAME_TYPE',
            message:
                'frames[$i] must be a shorthand value List or a frame object.',
            field: 'frames[$i]',
          ),
        );
      }
    }

    for (final field in const [
      'autoPlay',
      'loop',
      'showControls',
      'showStepControls',
      'showProgressIndicator',
      'showFrameLabel',
    ]) {
      final value = json[field];
      if (value != null && value is! bool) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_BAR_RACE_CONTROL_TYPE',
            message: '"$field" must be a boolean.',
            field: field,
          ),
        );
      }
    }

    final frameDuration = json['frameDuration'];
    if (frameDuration != null && _toPositiveInt(frameDuration) == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'INVALID_BAR_RACE_FRAME_DURATION',
          message: '"frameDuration" must be a positive integer.',
          field: 'frameDuration',
        ),
      );
    }

    final maxBars = json['maxBars'];
    if (maxBars != null && _toPositiveInt(maxBars) == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'INVALID_BAR_RACE_MAX_BARS',
          message: '"maxBars" must be a positive integer.',
          field: 'maxBars',
        ),
      );
    }

    _validateBarRaceMarkerMap(
      issues,
      json['markers'],
      labels,
      field: 'markers',
      styleObject: true,
    );
    _validateBarRaceMarkerMap(
      issues,
      json['icons'],
      labels,
      field: 'icons',
      styleObject: false,
    );
    _validateBarRaceMarkerMap(
      issues,
      json['images'],
      labels,
      field: 'images',
      styleObject: false,
      requireImageLikeString: true,
    );

    if (json['autoPlay'] == true && rawFrames is List && rawFrames.length < 2) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.info,
          code: 'BAR_RACE_AUTOPLAY_NEEDS_MULTIPLE_FRAMES',
          message: 'autoPlay has no visible effect with fewer than 2 frames.',
          field: 'autoPlay',
        ),
      );
    }
  }

  static void _validateNumericListValues(
    List<ValidationIssue> issues,
    List values,
    String field,
  ) {
    for (int i = 0; i < values.length; i++) {
      if (_toDouble(values[i]) == null) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'BAR_RACE_NON_NUMERIC_VALUE',
            message: '$field[$i] must be numeric or a numeric string.',
            field: '$field[$i]',
          ),
        );
      }
    }
  }

  static void _validateBarRaceMarkerMap(
    List<ValidationIssue> issues,
    Object? rawMarkers,
    Set<String> knownLabels, {
    required String field,
    required bool styleObject,
    bool requireImageLikeString = false,
  }) {
    if (rawMarkers == null) return;
    if (rawMarkers is! Map) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'INVALID_BAR_RACE_MARKERS_TYPE',
          message: '"$field" must be an object keyed by bar label.',
          field: field,
        ),
      );
      return;
    }

    rawMarkers.forEach((key, value) {
      final label = key.toString();
      if (knownLabels.isNotEmpty && !knownLabels.contains(label)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'BAR_RACE_UNUSED_MARKER',
            message:
                '$field["$label"] does not match any known bar label in categories or frames.',
            field: '$field.$label',
          ),
        );
      }

      if (!styleObject) {
        if (value != null && value is! String) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'INVALID_BAR_RACE_MARKER_VALUE',
              message: '$field["$label"] must be a string.',
              field: '$field.$label',
            ),
          );
        } else if (requireImageLikeString &&
            value is String &&
            value.trim().isEmpty) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'INVALID_BAR_RACE_MARKER_VALUE',
              message: '$field["$label"] must not be empty.',
              field: '$field.$label',
            ),
          );
        }
        return;
      }

      if (value is String) return;
      if (value is! Map) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_BAR_RACE_MARKER_VALUE',
            message:
                'markers["$label"] must be a string or marker style object.',
            field: 'markers.$label',
          ),
        );
        return;
      }

      final marker = Map<Object?, Object?>.from(value);
      for (final textField in const [
        'text',
        'icon',
        'fallbackText',
        'image',
        'src',
        'asset',
        'imageAsset',
        'imageUrl',
        'backgroundColor',
        'background',
        'borderColor',
      ]) {
        final fieldValue = marker[textField];
        if (fieldValue != null && fieldValue is! String) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'INVALID_BAR_RACE_MARKER_FIELD_TYPE',
              message: 'markers["$label"].$textField must be a string.',
              field: 'markers.$label.$textField',
            ),
          );
        }
      }

      final markerSize = marker['size'];
      if (markerSize != null && _toPositiveDouble(markerSize) == null) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_BAR_RACE_MARKER_SIZE',
            message: 'markers["$label"].size must be greater than 0.',
            field: 'markers.$label.size',
          ),
        );
      }

      for (final nonNegativeField in const [
        'borderWidth',
        'borderRadius',
        'padding',
      ]) {
        final fieldValue = marker[nonNegativeField];
        final parsed = _toDouble(fieldValue);
        if (fieldValue != null && (parsed == null || parsed < 0)) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'INVALID_BAR_RACE_MARKER_METRIC',
              message:
                  'markers["$label"].$nonNegativeField must be a non-negative number.',
              field: 'markers.$label.$nonNegativeField',
            ),
          );
        }
      }
    });
  }

  static void _validateFinancialSeriesPayload(
    List<ValidationIssue> issues,
    ChartType type,
    Object? seriesRaw,
  ) {
    if (type != ChartType.candlestick && type != ChartType.ohlc) return;
    if (seriesRaw is! List || seriesRaw.isEmpty) return;

    final firstSeries = seriesRaw.first;
    if (firstSeries is! Map) return;
    final data = firstSeries['data'];
    if (data == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'MISSING_OHLC_DATA',
          message: 'Candlestick/OHLC payload requires series[0].data.',
          field: 'series[0].data',
        ),
      );
      return;
    }
    if (data is! List) return;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      if (item is Map) {
        final missing = <String>[];
        for (final key in const ['open', 'high', 'low', 'close']) {
          if (!item.containsKey(key)) missing.add(key);
        }
        if (missing.isNotEmpty) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'OHLC_MISSING_KEYS',
              message:
                  'series[0].data[$i] is missing required key(s): ${missing.join(', ')}.',
              field: 'series[0].data[$i]',
              suggestion:
                  'Provide map entries: date?, open, high, low, close, volume?.',
            ),
          );
          continue;
        }

        final open = _toDouble(item['open']);
        final high = _toDouble(item['high']);
        final low = _toDouble(item['low']);
        final close = _toDouble(item['close']);
        if (open == null || high == null || low == null || close == null) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'OHLC_NON_NUMERIC_VALUE',
              message:
                  'series[0].data[$i] must have numeric open/high/low/close values.',
              field: 'series[0].data[$i]',
            ),
          );
          continue;
        }

        _validateFinancialPriceOrder(
          issues,
          index: i,
          open: open,
          high: high,
          low: low,
          close: close,
        );
        continue;
      }

      if (item is List) {
        if (item.length < 4) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'OHLC_INSUFFICIENT_VALUES',
              message:
                  'series[0].data[$i] needs [open, high, low, close] or [date, open, high, low, close], got ${item.length} value(s).',
              field: 'series[0].data[$i]',
            ),
          );
          continue;
        }

        if (_toDouble(item.first) == null && item.length < 5) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'OHLC_INSUFFICIENT_VALUES',
              message:
                  'series[0].data[$i] needs [open, high, low, close] or [date, open, high, low, close], got ${item.length} value(s).',
              field: 'series[0].data[$i]',
            ),
          );
          continue;
        }

        final values = _readFinancialTupleValues(item);
        if (values == null) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'OHLC_NON_NUMERIC_VALUE',
              message:
                  'series[0].data[$i] tuple must contain numeric open/high/low/close values.',
              field: 'series[0].data[$i]',
            ),
          );
          continue;
        }

        _validateFinancialPriceOrder(
          issues,
          index: i,
          open: values.open,
          high: values.high,
          low: values.low,
          close: values.close,
        );
        continue;
      }

      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'OHLC_INVALID_ITEM_TYPE',
          message:
              'series[0].data[$i] must be an object or tuple list for candlestick/OHLC.',
          field: 'series[0].data[$i]',
        ),
      );
    }
  }

  static void _validateFinancialPriceOrder(
    List<ValidationIssue> issues, {
    required int index,
    required double open,
    required double high,
    required double low,
    required double close,
  }) {
    if (high < low) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'OHLC_INVALID_PRICE_RANGE',
          message:
              'series[0].data[$index] has high < low ($high < $low), which is invalid.',
          field: 'series[0].data[$index]',
        ),
      );
      return;
    }

    if (high < open || high < close || low > open || low > close) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'OHLC_SUSPICIOUS_PRICE_ORDER',
          message:
              'series[0].data[$index] has unusual OHLC ordering (expected high >= open/close and low <= open/close).',
          field: 'series[0].data[$index]',
        ),
      );
    }
  }

  static ({double open, double high, double low, double close})?
  _readFinancialTupleValues(List item) {
    final base0 = _readFinancialTupleValuesAtBase(item, 0);
    final base1 = _readFinancialTupleValuesAtBase(item, 1);
    if (_hasValidFinancialPriceOrder(base0)) return base0;
    if (_hasValidFinancialPriceOrder(base1)) return base1;
    return base0 ?? base1;
  }

  static ({double open, double high, double low, double close})?
  _readFinancialTupleValuesAtBase(List item, int base) {
    if (item.length < base + 4) return null;
    final open = _toDouble(item[base]);
    final high = _toDouble(item[base + 1]);
    final low = _toDouble(item[base + 2]);
    final close = _toDouble(item[base + 3]);
    if (open == null || high == null || low == null || close == null) {
      return null;
    }
    return (open: open, high: high, low: low, close: close);
  }

  static bool _hasValidFinancialPriceOrder(
    ({double open, double high, double low, double close})? values,
  ) {
    if (values == null) return false;
    return values.high >= values.low &&
        values.high >= values.open &&
        values.high >= values.close &&
        values.low <= values.open &&
        values.low <= values.close;
  }

  static void _validateTradingSeriesPayload(
    List<ValidationIssue> issues,
    ChartType type,
    Map<String, dynamic> json,
    Object? seriesRaw,
  ) {
    if (type != ChartType.kagi &&
        type != ChartType.renko &&
        type != ChartType.macd) {
      return;
    }
    if (seriesRaw is! List || seriesRaw.isEmpty) return;
    final firstSeries = seriesRaw.first;
    if (firstSeries is! Map) return;
    final data = firstSeries['data'];
    if (data is! List) return;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      if (_toDouble(item) == null) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'TRADING_NON_NUMERIC_PRICE',
            message:
                'series[0].data[$i] must be a finite numeric value or numeric string for ${chartTypeToString(type)}.',
            field: 'series[0].data[$i]',
          ),
        );
        break;
      }
    }

    if (data.length < 2) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'TRADING_PRICE_SERIES_TOO_SHORT',
          message:
              '${chartTypeToString(type)} typically needs at least 2 price points.',
          field: 'series[0].data',
        ),
      );
    }

    if (type == ChartType.kagi) {
      final reversalPctRaw = json['reversalPct'];
      if (reversalPctRaw != null && reversalPctRaw is! num) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_KAGI_REVERSAL_TYPE',
            message: '"reversalPct" must be a number.',
            field: 'reversalPct',
          ),
        );
      } else if (reversalPctRaw is num &&
          _toPositiveDouble(reversalPctRaw) == null) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_KAGI_REVERSAL_VALUE',
            message: '"reversalPct" must be a finite number greater than 0.',
            field: 'reversalPct',
          ),
        );
      }
      return;
    }

    if (type == ChartType.renko) {
      final brickSizeRaw = json['brickSize'];
      if (brickSizeRaw != null && brickSizeRaw is! num) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_RENKO_BRICK_SIZE_TYPE',
            message: '"brickSize" must be a number.',
            field: 'brickSize',
          ),
        );
      } else if (brickSizeRaw is num &&
          _toPositiveDouble(brickSizeRaw) == null) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_RENKO_BRICK_SIZE_VALUE',
            message: '"brickSize" must be a finite number greater than 0.',
            field: 'brickSize',
            suggestion: 'Use values like 0.5, 1, or 2 depending on volatility.',
          ),
        );
      }
      return;
    }

    if (type == ChartType.macd) {
      final fast = _parsePositiveMacdPeriod(json['fast'], fallback: 12);
      final slow = _parsePositiveMacdPeriod(json['slow'], fallback: 26);
      final signal = _parsePositiveMacdPeriod(json['signal'], fallback: 9);

      if (json['fast'] != null && json['fast'] is! num) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_MACD_FAST_TYPE',
            message: '"fast" must be a number.',
            field: 'fast',
          ),
        );
      }
      if (json['slow'] != null && json['slow'] is! num) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_MACD_SLOW_TYPE',
            message: '"slow" must be a number.',
            field: 'slow',
          ),
        );
      }
      if (json['signal'] != null && json['signal'] is! num) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_MACD_SIGNAL_TYPE',
            message: '"signal" must be a number.',
            field: 'signal',
          ),
        );
      }

      if (json['fast'] is num && _toPositiveInt(json['fast']) == null) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_MACD_FAST_VALUE',
            message: '"fast" must be a finite integer greater than 0.',
            field: 'fast',
          ),
        );
      }
      if (json['slow'] is num && _toPositiveInt(json['slow']) == null) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_MACD_SLOW_VALUE',
            message: '"slow" must be a finite integer greater than 0.',
            field: 'slow',
          ),
        );
      }
      if (json['signal'] is num && _toPositiveInt(json['signal']) == null) {
        issues.add(
          const ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'INVALID_MACD_SIGNAL_VALUE',
            message: '"signal" must be a finite integer greater than 0.',
            field: 'signal',
          ),
        );
      }

      if (fast >= slow) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'MACD_FAST_SLOW_ORDER',
            message:
                'MACD usually expects fast < slow, got fast=$fast and slow=$slow.',
            field: 'fast',
            suggestion: 'Use common values like fast=12 and slow=26.',
          ),
        );
      }

      final minRequired = slow + signal - 1;
      if (data.length < minRequired) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'MACD_NOT_ENOUGH_DATA',
            message:
                'MACD may not render indicator lines well: data length is ${data.length}, recommended minimum is $minRequired (slow + signal - 1).',
            field: 'series[0].data',
          ),
        );
      }
    }
  }

  static int _parsePositiveMacdPeriod(dynamic raw, {required int fallback}) {
    return _toPositiveInt(raw) ?? fallback;
  }

  static bool _isLikelyUnknownType(String rawType, ChartType parsedType) {
    if (parsedType != ChartType.line) return false;
    final normalized = rawType.toLowerCase();
    const knownLineAliases = {'line', 'linechart', 'basicline'};
    return !knownLineAliases.contains(normalized);
  }

  static String _typeSuggestion(String rawType, {required String fallback}) {
    final suggestions = ChartRegistry.suggestTypeStrings(rawType);
    if (suggestions.isEmpty) return fallback;
    return 'Did you mean ${suggestions.join(', ')}? $fallback';
  }

  static String _canonicalDataModeString(
    dynamic raw, {
    String fallback = 'auto',
  }) {
    if (raw is! String) return fallback;
    switch (raw.trim().toLowerCase()) {
      case 'regular':
      case 'simple':
        return 'regular';
      case 'large':
      case 'largedataset':
      case 'performance':
        return 'large';
      case 'auto':
        return 'auto';
      default:
        return fallback;
    }
  }

  static String _canonicalSamplingStrategyString(dynamic raw) {
    if (raw is! String) return 'auto';
    switch (raw.trim().toLowerCase()) {
      case 'lttb':
        return 'lttb';
      case 'minmax':
      case 'min_max':
        return 'minMax';
      case 'nth':
      case 'every_n':
        return 'nth';
      case 'auto':
      default:
        return 'auto';
    }
  }

  static bool _typeSupportsLargeDataSampling(ChartType type) {
    return chartCapabilitiesForType(type).supportsSampling;
  }

  static void _validateSeriesShapeCompatibility(
    List<ValidationIssue> issues,
    Map<String, dynamic> json,
    ChartType parsedType,
  ) {
    final inferredShape = inferSeriesDataShape(json);
    final expectedShape = targetSeriesDataShape(parsedType);
    if (inferredShape == ChartSeriesDataShape.unknown ||
        expectedShape == ChartSeriesDataShape.unknown ||
        inferredShape == expectedShape) {
      return;
    }

    // Matrix-like `{x, y, value}` tuples are common for heatmaps and bubbles;
    // keep this advisory quiet because both families can legitimately use it.
    final isCartesianMatrixBoundary =
        (expectedShape == ChartSeriesDataShape.cartesian &&
            inferredShape == ChartSeriesDataShape.matrix) ||
        (expectedShape == ChartSeriesDataShape.matrix &&
            inferredShape == ChartSeriesDataShape.cartesian);
    if (isCartesianMatrixBoundary) return;

    final compatible =
        compatibleChartTypesForShape(inferredShape, registeredOnly: false)
            .where((type) => type != parsedType)
            .map(chartTypeToString)
            .take(8)
            .toList();
    final suggestion = compatible.isEmpty
        ? 'Transform series data to ${expectedShape.name} shape for ${chartTypeToString(parsedType)}.'
        : 'Use one of: ${compatible.join(', ')}, or transform series data to ${expectedShape.name} shape.';

    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.warning,
        code: 'DATA_SHAPE_TYPE_MISMATCH',
        message:
            'Chart type "${chartTypeToString(parsedType)}" expects ${expectedShape.name} data, '
            'but the payload looks ${inferredShape.name}.',
        field: 'series',
        suggestion: suggestion,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal validator
// ---------------------------------------------------------------------------

class _Validator {
  final BaseChartConfig config;
  final List<ValidationIssue> issues;

  _Validator(this.config, this.issues);

  void _error(
    String code,
    String message, {
    String? field,
    String? suggestion,
  }) => issues.add(
    ValidationIssue(
      severity: ValidationSeverity.error,
      code: code,
      message: message,
      field: field,
      suggestion: suggestion,
    ),
  );

  void _warn(
    String code,
    String message, {
    String? field,
    String? suggestion,
  }) => issues.add(
    ValidationIssue(
      severity: ValidationSeverity.warning,
      code: code,
      message: message,
      field: field,
      suggestion: suggestion,
    ),
  );

  void _info(String code, String message, {String? field}) => issues.add(
    ValidationIssue(
      severity: ValidationSeverity.info,
      code: code,
      message: message,
      field: field,
    ),
  );

  void checkSeriesNotEmpty() {
    if (config.series.isEmpty) {
      _error(
        'EMPTY_SERIES',
        'Chart has no series data.',
        field: 'series',
        suggestion: 'Add at least one Series with data.',
      );
    }
  }

  void checkSeriesDataNotNull() {
    for (int i = 0; i < config.series.length; i++) {
      final s = config.series[i];
      if (s.data == null) {
        _error(
          'NULL_SERIES_DATA',
          'Series[$i] "${s.name ?? i}" has null data.',
          field: 'series[$i].data',
          suggestion: 'Set data to an empty list [] instead of null.',
        );
      } else if (s.data!.isEmpty) {
        _warn(
          'EMPTY_SERIES_DATA',
          'Series[$i] "${s.name ?? i}" has an empty data list.',
          field: 'series[$i].data',
        );
      }
    }
  }

  void checkDataLengthConsistency() {
    if (config.series.length < 2) return;
    final lengths = config.series
        .where((s) => s.data != null)
        .map((s) => s.data!.length)
        .toSet();
    if (lengths.length > 1) {
      _warn(
        'INCONSISTENT_DATA_LENGTH',
        'Series have different data lengths: ${lengths.join(', ')}. '
            'Shorter series will show as missing values.',
        field: 'series[*].data.length',
        suggestion: 'Pad shorter series with nulls or 0.',
      );
    }
  }

  void checkNoNullValues() {
    for (int i = 0; i < config.series.length; i++) {
      final data = config.series[i].data ?? [];
      int nullCount = 0;
      for (final v in data) {
        if (v == null) nullCount++;
      }
      if (nullCount > 0) {
        _warn(
          'NULL_DATA_VALUES',
          'Series[$i] contains $nullCount null value(s) — '
              'they will be skipped during rendering.',
          field: 'series[$i].data',
          suggestion:
              'Replace nulls with 0, or use a chart type that '
              'supports gaps (line with connectNulls: false).',
        );
      }
    }
  }

  void checkColorStrings() {
    for (int i = 0; i < config.series.length; i++) {
      final color = config.series[i].itemStyle?.color;
      if (color != null && color.isNotEmpty) {
        final valid = _isValidColor(color);
        if (!valid) {
          _warn(
            'INVALID_COLOR',
            'Series[$i] itemStyle.color "$color" is not a valid color string.',
            field: 'series[$i].itemStyle.color',
            suggestion:
                'Use hex (#RRGGBB), rgb(r,g,b), rgba(r,g,b,a) or a named color.',
          );
        }
      }
    }
  }

  void checkTypeSpecificRules() {
    switch (config.type) {
      case ChartType.pie:
      case ChartType.donut:
        _checkPie();
      case ChartType.candlestick:
      case ChartType.ohlc:
        _checkOhlc();
      case ChartType.sankey:
        _checkSankey();
      case ChartType.scatter:
        _checkScatter();
      case ChartType.bubble:
        _checkBubble();
      default:
        break;
    }
  }

  void _checkPie() {
    if (config.series.length > 1) {
      _warn(
        'PIE_MULTIPLE_SERIES',
        'Pie/donut charts only render the first series. '
            '${config.series.length} series provided.',
        suggestion: 'Use a grouped bar chart for multiple series comparison.',
      );
    }
    final data = config.series.firstOrNull?.data ?? [];
    bool hasNegative = data.any((v) => v is num && v < 0);
    if (hasNegative) {
      _error(
        'PIE_NEGATIVE_VALUES',
        'Pie/donut charts cannot render negative values.',
        field: 'series[0].data',
        suggestion: 'Use absolute values or a bar chart with diverging axis.',
      );
    }
  }

  void _checkOhlc() {
    for (int i = 0; i < config.series.length; i++) {
      final data = config.series[i].data ?? [];
      for (int j = 0; j < data.length; j++) {
        final item = data[j];
        if (item is List && item.length < 4) {
          _error(
            'OHLC_INSUFFICIENT_VALUES',
            'Candlestick/OHLC series[$i] item[$j] needs 4 values '
                '[open, high, low, close], got ${item.length}.',
            field: 'series[$i].data[$j]',
          );
          break;
        }
      }
    }
  }

  void _checkSankey() {
    // Sankey expects links with source/target/value.
    final data = config.series.firstOrNull?.data ?? [];
    if (data.isNotEmpty && data.first is Map) {
      final first = data.first as Map;
      if (!first.containsKey('source') || !first.containsKey('target')) {
        _error(
          'SANKEY_MISSING_LINKS',
          'Sankey data items must have "source", "target", and "value" keys.',
          field: 'series[0].data',
        );
      }
    }
  }

  void _checkScatter() {
    for (int i = 0; i < config.series.length; i++) {
      final data = config.series[i].data ?? [];
      for (int j = 0; j < data.length; j++) {
        final item = data[j];
        if (item is List && item.length < 2) {
          _error(
            'SCATTER_INSUFFICIENT_VALUES',
            'Scatter series[$i] item[$j] needs at least [x, y], got ${item.length}.',
            field: 'series[$i].data[$j]',
          );
          break;
        }
      }
    }
  }

  void _checkBubble() {
    for (int i = 0; i < config.series.length; i++) {
      final data = config.series[i].data ?? [];
      for (int j = 0; j < data.length; j++) {
        final item = data[j];
        if (item is List && item.length < 3) {
          _warn(
            'BUBBLE_MISSING_SIZE',
            'Bubble series[$i] item[$j] should be [x, y, size], got ${item.length}. '
                'Default size will be used.',
            field: 'series[$i].data[$j]',
          );
          break;
        }
      }
    }
  }

  void checkAxisConfig() {
    // Warn on suspiciously large Y ranges (potential unit mismatch).
    if (config.series.isNotEmpty) {
      double max = double.negativeInfinity;
      double min = double.infinity;
      for (final s in config.series) {
        for (final v in s.data ?? []) {
          final d = v is num ? v.toDouble() : null;
          if (d != null) {
            if (d > max) max = d;
            if (d < min) min = d;
          }
        }
      }
      if (max.isFinite && min.isFinite && (max - min) > 1e9) {
        _warn(
          'LARGE_Y_RANGE',
          'Data range is very large (${min.toStringAsExponential(2)} to '
              '${max.toStringAsExponential(2)}). Consider a log scale.',
          suggestion: 'Set yAxisConfig: ChartAxisConfig.log()',
        );
      }
    }
  }

  void checkLegendConfig() {
    if (config.series.length > 1) {
      final unnamed = config.series
          .where((s) => s.name == null || s.name!.isEmpty)
          .length;
      if (unnamed > 0) {
        _info(
          'UNNAMED_SERIES',
          '$unnamed series have no name. Legend items will show as empty.',
          field: 'series[*].name',
        );
      }
    }
  }

  // ---- Helpers ----

  static bool _isValidColor(String s) {
    if (s.startsWith('#')) {
      return s.length == 4 || s.length == 7 || s.length == 9;
    }
    if (s.toLowerCase().startsWith('rgb(') ||
        s.toLowerCase().startsWith('rgba(')) {
      return true;
    }
    const named = {
      'black',
      'white',
      'red',
      'green',
      'blue',
      'yellow',
      'orange',
      'purple',
      'pink',
      'grey',
      'gray',
      'cyan',
      'teal',
      'indigo',
      'transparent',
      'amber',
      'lime',
      'brown',
      'navy',
      'maroon',
      'gold',
      'silver',
      'olive',
    };
    return named.contains(s.toLowerCase());
  }
}
