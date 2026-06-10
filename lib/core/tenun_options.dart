import 'base_config.dart';
import 'chart_config_validator.dart';
import 'chart_registry.dart';
import 'chart_type.dart';
import 'data_shape_adapter.dart';
import 'json_value.dart';

/// Non-throwing result for direct [TenunOption] config building.
class TenunOptionBuildResult {
  final Map<String, dynamic> payload;
  final ValidationResult validation;
  final BaseChartConfig? config;
  final Object? error;
  final StackTrace? stackTrace;
  final bool buildAttempted;

  const TenunOptionBuildResult({
    required this.payload,
    required this.validation,
    required this.config,
    required this.error,
    required this.stackTrace,
    required this.buildAttempted,
  });

  bool get resolved => config != null && error == null;
  bool get isRenderSafe => resolved && validation.isValid;
  bool get success => isRenderSafe;
  bool get hasWarnings => validation.hasWarnings;
  bool get hasErrors => validation.errors.isNotEmpty;

  String get message {
    if (error != null) {
      return 'Payload validation passed, but config build failed: $error';
    }
    if (!validation.isValid) {
      return buildAttempted
          ? 'Payload failed validation, and config build was attempted.'
          : 'Payload failed validation; config build skipped.';
    }
    if (validation.hasWarnings) {
      return 'Payload validation passed with warnings and config built.';
    }
    return 'Payload validation passed and config built.';
  }

  Map<String, dynamic> toJson({
    bool includePayload = false,
    bool includeStackTrace = false,
  }) => {
    'success': success,
    'resolved': resolved,
    'isRenderSafe': isRenderSafe,
    'buildAttempted': buildAttempted,
    'message': message,
    'validation': validation.toJson(),
    if (error != null) 'error': error.toString(),
    if (includeStackTrace && stackTrace != null)
      'stackTrace': stackTrace.toString(),
    if (includePayload) 'payload': JsonValue.cloneMap(payload),
  };
}

/// Parses and manages a single unified JSON "option" object, similar to Apache ECharts.
/// Handles normalization, theme injection, and seamless type switching.
class TenunOption {
  final Map<String, dynamic> rawJson;
  final ChartType primaryType;
  final Map<String, dynamic> global;
  final Map<String, dynamic> xAxis;
  final Map<String, dynamic> yAxis;
  final List<Map<String, dynamic>> series;
  final bool autoNormalizePayload;
  final PayloadNormalizationOptions normalizationOptions;

  final Map<String, dynamic> _renderJson;

  TenunOption._({
    required this.rawJson,
    required Map<String, dynamic> renderJson,
    required this.primaryType,
    required this.global,
    required this.xAxis,
    required this.yAxis,
    required this.series,
    required this.autoNormalizePayload,
    required this.normalizationOptions,
  }) : _renderJson = renderJson;

  /// Creates an option from raw JSON.
  factory TenunOption.fromJson(
    Map<String, dynamic> json, {
    bool autoNormalizePayload = false,
    PayloadNormalizationOptions? normalizationOptions,
  }) {
    final rawJson = JsonValue.cloneMap(json);
    final effectiveNormalizationOptions = PayloadNormalizationOptions.resolve(
      rawJson,
      fallback: normalizationOptions ?? const PayloadNormalizationOptions(),
    );
    final shouldNormalizePayload =
        PayloadNormalizationOptions.shouldAutoNormalize(
          rawJson,
          fallback: autoNormalizePayload,
        );
    final normalizedRenderJson = shouldNormalizePayload
        ? ChartConfigValidator.normalizePayload(
            rawJson,
            options: effectiveNormalizationOptions,
          )
        : rawJson;
    final renderJson = JsonValue.cloneMap(normalizedRenderJson);

    final typeStr = _resolvePrimaryTypeString(renderJson);
    final primaryType = getChartType(typeStr);

    // Extract global shared configs
    final global = {
      'title': JsonValue.clone(renderJson['title']),
      'tooltip': JsonValue.clone(renderJson['tooltip']),
      'legend': JsonValue.clone(renderJson['legend']),
      'grid': JsonValue.clone(renderJson['grid']),
      'toolbox': JsonValue.clone(renderJson['toolbox']),
      'theme': JsonValue.clone(renderJson['theme']),
      'sampling': JsonValue.clone(renderJson['sampling']),
      'dataMode': JsonValue.clone(
        renderJson['dataMode'] ?? renderJson['datasetMode'],
      ),
    };

    // Normalize axes
    final xAxis = renderJson['xAxis'] is Map
        ? JsonValue.cloneMap(renderJson['xAxis'] as Map)
        : <String, dynamic>{};
    final yAxis = renderJson['yAxis'] is Map
        ? JsonValue.cloneMap(renderJson['yAxis'] as Map)
        : <String, dynamic>{};

    // Normalize series
    final seriesInput = renderJson['series'];
    final rawSeries = (seriesInput is List ? seriesInput : const [])
        .whereType<Map>()
        .map(JsonValue.cloneMap)
        .toList();
    final series = rawSeries
        .map(
          (s) => {
            'type': s['type']?.toString() ?? typeStr,
            'name': s['name'],
            'data': s['data'],
            ...s, // Merge overrides
          },
        )
        .toList();

    return TenunOption._(
      rawJson: rawJson,
      renderJson: renderJson,
      primaryType: primaryType,
      global: global,
      xAxis: xAxis,
      yAxis: yAxis,
      series: series,
      autoNormalizePayload: shouldNormalizePayload,
      normalizationOptions: effectiveNormalizationOptions,
    );
  }

  /// Resolves the final [BaseChartConfig] ready for rendering.
  BaseChartConfig build() {
    return ChartRegistry.resolve(toRenderJson());
  }

  /// Returns the normalized JSON payload used by [build].
  Map<String, dynamic> toRenderJson() {
    final out = JsonValue.cloneMap(_renderJson);
    out
      ..['type'] = chartTypeToString(primaryType)
      ..remove('datasetMode');

    for (final entry in global.entries) {
      if (entry.value == null) {
        out.remove(entry.key);
      } else {
        out[entry.key] = JsonValue.clone(entry.value);
      }
    }

    if (xAxis.isNotEmpty) {
      out['xAxis'] = JsonValue.cloneMap(xAxis);
    } else {
      out.remove('xAxis');
    }
    if (yAxis.isNotEmpty) {
      out['yAxis'] = JsonValue.cloneMap(yAxis);
    } else {
      out.remove('yAxis');
    }
    out['series'] = series.map(JsonValue.cloneMap).toList(growable: false);

    return _withoutNullValues(out);
  }

  /// Returns a compact normalized payload containing only shared chart fields.
  Map<String, dynamic> toSharedRenderJson() {
    return _withoutNullValues({
      'type': chartTypeToString(primaryType),
      for (final entry in global.entries)
        entry.key: JsonValue.clone(entry.value),
      if (xAxis.isNotEmpty) 'xAxis': JsonValue.cloneMap(xAxis),
      if (yAxis.isNotEmpty) 'yAxis': JsonValue.cloneMap(yAxis),
      'series': series.map(JsonValue.cloneMap).toList(growable: false),
    });
  }

  /// Validates the normalized payload used by [build].
  ValidationResult validate({
    bool deep = true,
    bool requireRegisteredType = true,
  }) {
    return ChartConfigValidator.validateJsonPayload(
      toRenderJson(),
      deep: deep,
      requireRegisteredType: requireRegisteredType,
    );
  }

  /// Non-throwing variant of [build] for developer tools and JSON-driven UIs.
  ///
  /// By default, config resolution is skipped when validation has errors.
  /// Set [buildWhenInvalid] to true when you need to collect parser failures
  /// as well, for example in diagnostics tooling.
  TenunOptionBuildResult tryBuild({
    bool deep = true,
    bool requireRegisteredType = true,
    bool buildWhenInvalid = false,
  }) {
    final payload = toRenderJson();
    final validation = ChartConfigValidator.validateJsonPayload(
      payload,
      deep: deep,
      requireRegisteredType: requireRegisteredType,
    );

    if (!validation.isValid && !buildWhenInvalid) {
      return TenunOptionBuildResult(
        payload: payload,
        validation: validation,
        config: null,
        error: null,
        stackTrace: null,
        buildAttempted: false,
      );
    }

    try {
      final config = ChartRegistry.resolve(payload);
      return TenunOptionBuildResult(
        payload: payload,
        validation: validation,
        config: config,
        error: null,
        stackTrace: null,
        buildAttempted: true,
      );
    } catch (error, stackTrace) {
      return TenunOptionBuildResult(
        payload: payload,
        validation: validation,
        config: null,
        error: error,
        stackTrace: stackTrace,
        buildAttempted: true,
      );
    }
  }

  /// Returns a copy of the underlying JSON for external inspection.
  Map<String, dynamic> toJson() => JsonValue.cloneMap(rawJson);
}

String _resolvePrimaryTypeString(Map<String, dynamic> json) {
  final rawType = json['type'];
  if (rawType != null) return rawType.toString().trim().toLowerCase();

  final rawSeries = json['series'];
  if (rawSeries is List && rawSeries.isNotEmpty) {
    final first = rawSeries.first;
    if (first is Map && first['type'] != null) {
      return first['type'].toString().trim().toLowerCase();
    }
  }

  return 'bar';
}

Map<String, dynamic> _withoutNullValues(Map<String, dynamic> input) {
  return {
    for (final entry in input.entries)
      if (entry.value != null) entry.key: entry.value,
  };
}

/// Extension for dynamic chart type switching.
extension TenunOptionTypeSwitching on TenunOption {
  Map<String, dynamic> get _switchSourceJson =>
      autoNormalizePayload ? toRenderJson() : rawJson;

  /// Switch chart type while automatically adapting the data structure.
  TenunOption switchType(ChartType newType) {
    final adaptedJson = DataShapeAdapter.adapt(_switchSourceJson, newType);
    return TenunOption.fromJson(
      adaptedJson,
      autoNormalizePayload: autoNormalizePayload,
      normalizationOptions: normalizationOptions,
    );
  }

  /// Attempts to switch chart type without throwing on incompatible targets.
  ChartTypeSwitchResult trySwitchType(
    ChartType newType, {
    bool force = false,
    bool registeredOnly = true,
  }) {
    return DataShapeAdapter.tryAdapt(
      _switchSourceJson,
      newType,
      force: force,
      registeredOnly: registeredOnly,
    );
  }

  /// Attempts to switch chart type and validates the adapted payload.
  ValidatedChartTypeSwitchResult trySwitchTypeValidated(
    ChartType newType, {
    bool force = false,
    bool registeredOnly = true,
    bool deep = true,
    bool requireRegisteredType = true,
  }) {
    return DataShapeAdapter.tryAdaptValidated(
      _switchSourceJson,
      newType,
      force: force,
      registeredOnly: registeredOnly,
      deep: deep,
      requireRegisteredType: requireRegisteredType,
    );
  }

  /// Attempts to switch to the best compatible chart type without throwing.
  ChartAutoSwitchResult trySwitchAuto({
    List<ChartType>? preferredOrder,
    bool includeCurrentType = false,
    bool registeredOnly = true,
  }) {
    return DataShapeAdapter.tryAdaptAuto(
      _switchSourceJson,
      preferredOrder: preferredOrder,
      includeCurrentType: includeCurrentType,
      registeredOnly: registeredOnly,
    );
  }

  /// Attempts to auto-switch chart type and validates the adapted payload.
  ValidatedChartAutoSwitchResult trySwitchAutoValidated({
    List<ChartType>? preferredOrder,
    bool includeCurrentType = false,
    bool registeredOnly = true,
    bool deep = true,
    bool requireRegisteredType = true,
  }) {
    return DataShapeAdapter.tryAdaptAutoValidated(
      _switchSourceJson,
      preferredOrder: preferredOrder,
      includeCurrentType: includeCurrentType,
      registeredOnly: registeredOnly,
      deep: deep,
      requireRegisteredType: requireRegisteredType,
    );
  }

  /// Checks if switching to [newType] is lossless (data shapes match).
  bool isCompatibleWith(ChartType newType) {
    return DataShapeAdapter.isCompatible(
      _switchSourceJson,
      newType,
      registeredOnly: false,
    );
  }

  /// Deep lossless check.
  bool isLosslessSwitch(ChartType newType) {
    final current = DataShapeAdapter.inferShape(_switchSourceJson);
    return current != ChartSeriesDataShape.unknown &&
        current == DataShapeAdapter.targetShape(newType);
  }
}
