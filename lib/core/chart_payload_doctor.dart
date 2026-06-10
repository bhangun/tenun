import 'chart_api_contract.dart';
import 'chart_config_validator.dart';
import 'chart_type.dart';
import '../registry/chart_api_contract_mapping.dart';
import '../registry/registry_tools.dart';

enum ChartPayloadDoctorStatus { healthy, warning, repairable, invalid }

class ChartPayloadDoctorFinding {
  final ValidationSeverity severity;
  final String code;
  final String source;
  final String message;
  final String? field;
  final String? suggestion;

  const ChartPayloadDoctorFinding({
    required this.severity,
    required this.code,
    required this.source,
    required this.message,
    this.field,
    this.suggestion,
  });

  bool get isError => severity == ValidationSeverity.error;
  bool get isWarning => severity == ValidationSeverity.warning;

  Map<String, dynamic> toJson() => {
    'severity': severity.name,
    'code': code,
    'source': source,
    'message': message,
    if (field != null) 'field': field,
    if (suggestion != null) 'suggestion': suggestion,
  };
}

class ChartPayloadDoctorReport {
  final ChartType type;
  final ChartSeriesDataShape expectedShape;
  final ChartSeriesDataShape inferredShape;
  final ChartPayloadContract payloadContract;
  final ChartApiContract apiContract;
  final ValidationResult rawValidation;
  final ValidationResult normalizedValidation;
  final PayloadNormalizationResult normalization;
  final List<ChartPayloadDoctorFinding> findings;

  const ChartPayloadDoctorReport({
    required this.type,
    required this.expectedShape,
    required this.inferredShape,
    required this.payloadContract,
    required this.apiContract,
    required this.rawValidation,
    required this.normalizedValidation,
    required this.normalization,
    required this.findings,
  });

  String get typeString => chartTypeToString(type);

  bool get hasErrors => findings.any((finding) => finding.isError);
  bool get hasWarnings => findings.any((finding) => finding.isWarning);

  bool get canNormalizeToValid =>
      !rawValidation.isValid && normalizedValidation.isValid;

  ChartPayloadDoctorStatus get status {
    if (canNormalizeToValid) return ChartPayloadDoctorStatus.repairable;
    if (hasErrors) return ChartPayloadDoctorStatus.invalid;
    if (hasWarnings) return ChartPayloadDoctorStatus.warning;
    return ChartPayloadDoctorStatus.healthy;
  }

  String get summary {
    switch (status) {
      case ChartPayloadDoctorStatus.healthy:
        return 'Payload is ready for a $typeString chart.';
      case ChartPayloadDoctorStatus.warning:
        return 'Payload can render, but ${findings.length} issue(s) need review.';
      case ChartPayloadDoctorStatus.repairable:
        return 'Payload is not render-safe yet, but normalization can repair it.';
      case ChartPayloadDoctorStatus.invalid:
        return 'Payload is not render-safe for a $typeString chart.';
    }
  }

  List<String> get quickFixes {
    final seen = <String>{};
    final fixes = <String>[];
    for (final finding in findings) {
      final suggestion = finding.suggestion?.trim();
      if (suggestion != null && suggestion.isNotEmpty && seen.add(suggestion)) {
        fixes.add(suggestion);
      }
    }
    if (normalization.changed && seen.add(normalization.summary.compactLabel)) {
      fixes.add('Apply normalization: ${normalization.summary.compactLabel}.');
    }
    return fixes;
  }

  Map<String, dynamic> toJson({
    bool includePayloads = false,
    bool includeDiffValues = false,
  }) {
    return {
      'type': typeString,
      'status': status.name,
      'summary': summary,
      'expectedShape': expectedShape.name,
      'inferredShape': inferredShape.name,
      'payloadContract': payloadContract.toJson(),
      'apiContract': apiContract.name,
      'apiFamily': apiContract.family.name,
      'rawValidation': rawValidation.toJson(),
      'normalizedValidation': normalizedValidation.toJson(),
      'normalization': normalization.toJson(
        includePayloads: includePayloads,
        includeDiffValues: includeDiffValues,
      ),
      'findings': findings
          .map((finding) => finding.toJson())
          .toList(growable: false),
      'quickFixes': quickFixes,
    };
  }
}

class ChartPayloadDoctor {
  const ChartPayloadDoctor._();

  static ChartPayloadDoctorReport inspect(
    Map<String, dynamic> payload, {
    bool deep = false,
    bool requireRegisteredType = false,
    PayloadNormalizationOptions? normalizationOptions,
  }) {
    final type = _payloadType(payload);
    final expectedShape = targetSeriesDataShape(type);
    final inferredShape = inferSeriesDataShape(payload);
    final contract = chartPayloadContractForType(type);
    final apiContract = chartApiContractForType(type);
    final rawValidation = ChartConfigValidator.validateJsonPayload(
      payload,
      deep: deep,
      requireRegisteredType: requireRegisteredType,
    );
    final normalization = ChartConfigValidator.normalizePayloadWithReport(
      payload,
      options: normalizationOptions,
    );
    final normalizedValidation = ChartConfigValidator.validateJsonPayload(
      normalization.normalizedPayload,
      deep: deep,
      requireRegisteredType: requireRegisteredType,
    );
    final findings = <ChartPayloadDoctorFinding>[
      ..._validationFindings(rawValidation),
      ..._contractFindings(payload, contract),
      ..._shapeFindings(
        type: type,
        expectedShape: expectedShape,
        inferredShape: inferredShape,
        rawValidation: rawValidation,
      ),
      ..._normalizationFindings(
        rawValidation: rawValidation,
        normalizedValidation: normalizedValidation,
        normalization: normalization,
      ),
    ];

    return ChartPayloadDoctorReport(
      type: type,
      expectedShape: expectedShape,
      inferredShape: inferredShape,
      payloadContract: contract,
      apiContract: apiContract,
      rawValidation: rawValidation,
      normalizedValidation: normalizedValidation,
      normalization: normalization,
      findings: findings,
    );
  }

  static ChartType _payloadType(Map<String, dynamic> payload) {
    final rawType = (payload['type'] ?? '').toString().trim();
    return rawType.isEmpty ? ChartType.line : getChartType(rawType);
  }

  static List<ChartPayloadDoctorFinding> _validationFindings(
    ValidationResult validation,
  ) {
    return [
      for (final issue in validation.issues)
        ChartPayloadDoctorFinding(
          severity: issue.severity,
          code: issue.code,
          source: 'validation',
          message: issue.message,
          field: issue.field,
          suggestion: issue.suggestion,
        ),
    ];
  }

  static List<ChartPayloadDoctorFinding> _contractFindings(
    Map<String, dynamic> payload,
    ChartPayloadContract contract,
  ) {
    if (_hasUsableSeries(payload)) return const [];

    switch (contract.seriesStrategy) {
      case ChartPayloadSeriesStrategy.dataFields:
        return _dataFieldContractFindings(payload, contract);
      case ChartPayloadSeriesStrategy.namedCollection:
        final field = contract.namedCollectionField;
        if (field == null || _hasNonEmptyList(payload[field])) return const [];
        return [
          ChartPayloadDoctorFinding(
            severity: ValidationSeverity.error,
            code: 'MISSING_NAMED_COLLECTION_FIELD',
            source: 'payloadContract',
            message:
                '${contract.typeString} expects a "$field" collection or a non-empty series list.',
            field: field,
            suggestion:
                'Provide "$field": [...] or series: [{"$field": [...]}].',
          ),
        ];
      case ChartPayloadSeriesStrategy.nodeLink:
        if (_hasNonEmptyList(payload['nodes']) &&
            _hasNonEmptyList(payload['links'])) {
          return const [];
        }
        return [
          ChartPayloadDoctorFinding(
            severity: ValidationSeverity.error,
            code: 'MISSING_NODE_LINK_FIELDS',
            source: 'payloadContract',
            message:
                '${contract.typeString} expects both "nodes" and "links" collections.',
            field: 'nodes|links',
            suggestion:
                'Provide nodes: [...] and links: [...], or series: [{"nodes": [...], "links": [...]}].',
          ),
        ];
      case ChartPayloadSeriesStrategy.calendarDateValues:
        if (_hasNonEmptyList(payload['data']) || payload['dateValues'] is Map) {
          return const [];
        }
        return [
          ChartPayloadDoctorFinding(
            severity: ValidationSeverity.error,
            code: 'MISSING_CALENDAR_VALUES',
            source: 'payloadContract',
            message:
                '${contract.typeString} expects "data" rows or a "dateValues" map.',
            field: 'data|dateValues',
            suggestion:
                'Provide data: [{"date": "2026-01-01", "value": 10}] or dateValues: {"2026-01-01": 10}.',
          ),
        ];
      case ChartPayloadSeriesStrategy.ringSlices:
        if (_hasNonEmptyList(payload['rings']) ||
            _hasNonEmptyList(payload['data'])) {
          return const [];
        }
        return [
          ChartPayloadDoctorFinding(
            severity: ValidationSeverity.error,
            code: 'MISSING_RING_SLICES',
            source: 'payloadContract',
            message:
                '${contract.typeString} expects rings with slices or a data collection.',
            field: 'rings|data',
            suggestion: 'Provide rings: [{"slices": [...]}] or data: [...].',
          ),
        ];
      case ChartPayloadSeriesStrategy.partitionPie:
        if (_hasNonEmptyList(payload['mainSlices']) ||
            _hasNonEmptyList(payload['data'])) {
          return const [];
        }
        return [
          ChartPayloadDoctorFinding(
            severity: ValidationSeverity.error,
            code: 'MISSING_PARTITION_PIE_SLICES',
            source: 'payloadContract',
            message:
                '${contract.typeString} expects mainSlices/subSlices or a data collection.',
            field: 'mainSlices|subSlices|data',
            suggestion:
                'Provide mainSlices: [...], optional subSlices: [...], or data: [...].',
          ),
        ];
    }
  }

  static List<ChartPayloadDoctorFinding> _dataFieldContractFindings(
    Map<String, dynamic> payload,
    ChartPayloadContract contract,
  ) {
    for (final field in contract.dataFieldPriority) {
      if (_hasNonEmptyList(payload[field])) return const [];
    }
    if (!contract.requiresSeries) return const [];

    final fields = contract.dataFieldPriority.isEmpty
        ? 'data'
        : contract.dataFieldPriority.join(', ');
    return [
      ChartPayloadDoctorFinding(
        severity: ValidationSeverity.error,
        code: 'MISSING_DATA_COLLECTION_FIELD',
        source: 'payloadContract',
        message:
            '${contract.typeString} expects series data or one of these collection fields: $fields.',
        field: 'series|$fields',
        suggestion:
            'Provide series: [{"data": [...]}] or a shorthand collection field such as ${contract.dataFieldPriority.isEmpty ? '"data"' : '"${contract.dataFieldPriority.first}"'}.',
      ),
    ];
  }

  static List<ChartPayloadDoctorFinding> _shapeFindings({
    required ChartType type,
    required ChartSeriesDataShape expectedShape,
    required ChartSeriesDataShape inferredShape,
    required ValidationResult rawValidation,
  }) {
    if (_hasValidationCode(rawValidation, 'DATA_SHAPE_TYPE_MISMATCH')) {
      return const [];
    }
    if (expectedShape == ChartSeriesDataShape.unknown ||
        inferredShape == ChartSeriesDataShape.unknown ||
        expectedShape == inferredShape) {
      return const [];
    }

    final compatible =
        compatibleChartTypesForShape(inferredShape, registeredOnly: false)
            .where((candidate) => candidate != type)
            .map(chartTypeToString)
            .take(8)
            .toList();
    return [
      ChartPayloadDoctorFinding(
        severity: ValidationSeverity.warning,
        code: 'DATA_SHAPE_TYPE_MISMATCH',
        source: 'shape',
        message:
            '${chartTypeToString(type)} expects ${expectedShape.name} data, but this payload looks ${inferredShape.name}.',
        field: 'series',
        suggestion: compatible.isEmpty
            ? 'Transform the payload to ${expectedShape.name} shape.'
            : 'Use one of: ${compatible.join(', ')}, or transform the payload to ${expectedShape.name} shape.',
      ),
    ];
  }

  static List<ChartPayloadDoctorFinding> _normalizationFindings({
    required ValidationResult rawValidation,
    required ValidationResult normalizedValidation,
    required PayloadNormalizationResult normalization,
  }) {
    if (!normalization.changed) return const [];

    final findings = <ChartPayloadDoctorFinding>[
      ChartPayloadDoctorFinding(
        severity: ValidationSeverity.info,
        code: 'NORMALIZATION_AVAILABLE',
        source: 'normalization',
        message:
            'Normalization can rewrite ${normalization.summary.compactLabel}.',
        suggestion:
            'Review changed paths: ${normalization.changedPaths.take(6).join(', ')}.',
      ),
    ];
    if (!rawValidation.isValid && normalizedValidation.isValid) {
      findings.add(
        const ChartPayloadDoctorFinding(
          severity: ValidationSeverity.info,
          code: 'NORMALIZATION_REPAIRS_ERRORS',
          source: 'normalization',
          message:
              'The normalized payload passes validation while the raw payload does not.',
          suggestion:
              'Enable autoNormalizePayload or apply the normalized JSON.',
        ),
      );
    }
    return findings;
  }

  static bool _hasValidationCode(ValidationResult result, String code) {
    return result.issues.any((issue) => issue.code == code);
  }

  static bool _hasUsableSeries(Map<String, dynamic> payload) {
    final series = payload['series'];
    return series is List && series.isNotEmpty;
  }

  static bool _hasNonEmptyList(Object? value) {
    return value is List && value.isNotEmpty;
  }
}
