import '../registry/registry_tools.dart' as registry;
import 'chart_config_validator.dart';
import 'chart_type.dart';
import 'json_value.dart';

export '../registry/registry_tools.dart'
    show
        ChartSeriesDataShape,
        ChartSwitchCompatibility,
        ChartTypeSwitchResult,
        ChartAutoSwitchResult;

/// Switch result plus post-switch payload validation.
///
/// [switchResult] answers whether the data-shape switch was possible.
/// [validation] answers whether the adapted payload is safe to parse/render
/// with the currently registered chart types.
class ValidatedChartTypeSwitchResult {
  final registry.ChartTypeSwitchResult switchResult;
  final ValidationResult? validation;

  const ValidatedChartTypeSwitchResult({
    required this.switchResult,
    required this.validation,
  });

  bool get success => switchResult.success;
  bool get isRenderSafe => success && (validation?.isValid ?? false);
  bool get hasWarnings => validation?.hasWarnings ?? false;
  ChartType get targetType => switchResult.targetType;
  String get targetTypeString => switchResult.targetTypeString;
  Map<String, dynamic>? get payload => switchResult.payload;
  String get message => switchResult.message;
  String get renderSafetyMessage {
    if (!switchResult.success) return switchResult.message;
    final result = validation;
    if (result == null) return 'Switch succeeded, but validation was not run.';
    if (result.isValid && result.hasWarnings) {
      return 'Switch succeeded with validation warnings.';
    }
    if (result.isValid) return 'Switch succeeded and validation passed.';
    return 'Switch succeeded, but adapted payload failed validation.';
  }

  List<ValidationIssue> get validationErrors =>
      validation?.errors ?? const <ValidationIssue>[];
  List<ValidationIssue> get validationWarnings =>
      validation?.warnings ?? const <ValidationIssue>[];

  Map<String, dynamic> toJson({bool includePayload = false}) => {
    'success': success,
    'isRenderSafe': isRenderSafe,
    'hasWarnings': hasWarnings,
    'targetType': targetTypeString,
    'message': message,
    'renderSafetyMessage': renderSafetyMessage,
    'switch': switchResult.toJson(includePayload: includePayload),
    if (validation != null) 'validation': validation!.toJson(),
    if (includePayload && payload != null)
      'payload': JsonValue.cloneMap(payload!),
  };
}

/// Auto-switch result plus post-switch payload validation.
class ValidatedChartAutoSwitchResult {
  final registry.ChartAutoSwitchResult switchResult;
  final ValidationResult? validation;

  const ValidatedChartAutoSwitchResult({
    required this.switchResult,
    required this.validation,
  });

  bool get success => switchResult.success;
  bool get isRenderSafe => success && (validation?.isValid ?? false);
  bool get hasWarnings => validation?.hasWarnings ?? false;
  ChartType? get selectedType => switchResult.selectedType;
  String? get selectedTypeString => switchResult.selectedTypeString;
  Map<String, dynamic>? get payload => switchResult.payload;
  String get message => switchResult.message;
  String get renderSafetyMessage {
    if (!switchResult.success) return switchResult.message;
    final result = validation;
    if (result == null) return 'Switch succeeded, but validation was not run.';
    if (result.isValid && result.hasWarnings) {
      return 'Auto-switch succeeded with validation warnings.';
    }
    if (result.isValid) return 'Auto-switch succeeded and validation passed.';
    return 'Auto-switch succeeded, but adapted payload failed validation.';
  }

  List<ValidationIssue> get validationErrors =>
      validation?.errors ?? const <ValidationIssue>[];
  List<ValidationIssue> get validationWarnings =>
      validation?.warnings ?? const <ValidationIssue>[];

  Map<String, dynamic> toJson({bool includePayload = false}) => {
    'success': success,
    'isRenderSafe': isRenderSafe,
    'hasWarnings': hasWarnings,
    if (selectedTypeString != null) 'selectedType': selectedTypeString,
    'message': message,
    'renderSafetyMessage': renderSafetyMessage,
    'switch': switchResult.toJson(includePayload: includePayload),
    if (validation != null) 'validation': validation!.toJson(),
    if (includePayload && payload != null)
      'payload': JsonValue.cloneMap(payload!),
  };
}

/// Backward-compatible facade over the registry-backed data-shape tools.
///
/// The canonical shape inference and switching rules live in
/// `registry_tools.dart` so validation, registry diagnostics, and runtime
/// switching all make the same decision for the same payload.
class DataShapeAdapter {
  /// Infers the dominant data shape from a JSON chart config.
  static registry.ChartSeriesDataShape inferShape(Map<String, dynamic> json) =>
      registry.inferSeriesDataShape(json);

  /// Returns the expected data shape for a chart type.
  static registry.ChartSeriesDataShape targetShape(ChartType type) =>
      registry.targetSeriesDataShape(type);

  /// Returns chart types that can consume this payload without reshaping.
  static List<ChartType> compatibleTypes(
    Map<String, dynamic> json, {
    bool registeredOnly = true,
  }) => registry.compatibleChartTypesForJson(
    json,
    registeredOnly: registeredOnly,
  );

  /// True when [targetType] can consume the payload's inferred shape directly.
  static bool isCompatible(
    Map<String, dynamic> json,
    ChartType targetType, {
    bool registeredOnly = true,
  }) => compatibleTypes(
    json,
    registeredOnly: registeredOnly,
  ).contains(targetType);

  /// Returns a non-throwing explanation for whether [targetType] can consume
  /// this payload directly or via a supported force conversion.
  static registry.ChartSwitchCompatibility compatibility(
    Map<String, dynamic> json,
    ChartType targetType, {
    bool registeredOnly = true,
  }) => registry.chartSwitchCompatibilityForJson(
    json,
    targetType: targetType,
    registeredOnly: registeredOnly,
  );

  /// Adapts the [json] payload to be compatible with [targetType].
  ///
  /// `force` defaults to true for backward compatibility with the old adapter:
  /// lossy-but-useful conversions such as cartesian -> pie/hierarchy/financial
  /// are allowed. Pass `force: false` to permit only same-shape targets.
  static Map<String, dynamic> adapt(
    Map<String, dynamic> json,
    ChartType targetType, {
    bool force = true,
  }) => registry.switchChartTypeForSeriesShape(
    json,
    targetType: targetType,
    force: force,
  );

  /// Non-throwing variant of [adapt] for UI/runtime chart switching.
  static registry.ChartTypeSwitchResult tryAdapt(
    Map<String, dynamic> json,
    ChartType targetType, {
    bool force = false,
    bool registeredOnly = true,
  }) => registry.trySwitchChartTypeForSeriesShape(
    json,
    targetType: targetType,
    force: force,
    registeredOnly: registeredOnly,
  );

  /// Non-throwing switch plus post-switch validation.
  ///
  /// Use this before building a runtime-selected chart when invalid payloads
  /// should be reported instead of surfacing from `KChart.build`.
  static ValidatedChartTypeSwitchResult tryAdaptValidated(
    Map<String, dynamic> json,
    ChartType targetType, {
    bool force = false,
    bool registeredOnly = true,
    bool deep = true,
    bool requireRegisteredType = true,
  }) {
    final result = tryAdapt(
      json,
      targetType,
      force: force,
      registeredOnly: registeredOnly,
    );
    return ValidatedChartTypeSwitchResult(
      switchResult: result,
      validation: _validateSwitchedPayload(
        result.payload,
        deep: deep,
        requireRegisteredType: requireRegisteredType,
      ),
    );
  }

  /// Non-throwing auto-switch variant for UI/runtime chart switching.
  static registry.ChartAutoSwitchResult tryAdaptAuto(
    Map<String, dynamic> json, {
    List<ChartType>? preferredOrder,
    bool includeCurrentType = false,
    bool registeredOnly = true,
  }) => registry.trySwitchChartTypeForSeriesShapeAuto(
    json,
    preferredOrder: preferredOrder,
    includeCurrentType: includeCurrentType,
    registeredOnly: registeredOnly,
  );

  /// Non-throwing auto-switch plus post-switch validation.
  static ValidatedChartAutoSwitchResult tryAdaptAutoValidated(
    Map<String, dynamic> json, {
    List<ChartType>? preferredOrder,
    bool includeCurrentType = false,
    bool registeredOnly = true,
    bool deep = true,
    bool requireRegisteredType = true,
  }) {
    final result = tryAdaptAuto(
      json,
      preferredOrder: preferredOrder,
      includeCurrentType: includeCurrentType,
      registeredOnly: registeredOnly,
    );
    return ValidatedChartAutoSwitchResult(
      switchResult: result,
      validation: _validateSwitchedPayload(
        result.payload,
        deep: deep,
        requireRegisteredType: requireRegisteredType,
      ),
    );
  }
}

ValidationResult? _validateSwitchedPayload(
  Map<String, dynamic>? payload, {
  required bool deep,
  required bool requireRegisteredType,
}) {
  if (payload == null) return null;
  return ChartConfigValidator.validateJsonPayload(
    payload,
    deep: deep,
    requireRegisteredType: requireRegisteredType,
  );
}
