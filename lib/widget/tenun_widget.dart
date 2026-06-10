import 'package:flutter/material.dart';
import '../core/base_config.dart';
import '../core/chart_config_validator.dart';
import '../core/chart_data_signature.dart';
import '../core/chart_registry.dart';
import '../core/chart_theme.dart';
import '../core/chart_type.dart';
import '../core/chart_builder.dart';
import '../core/data_shape_adapter.dart';
import '../core/tenun_options.dart';
import 'chart_diagnostic_fallback.dart';

import '../core/chart_controller.dart';

typedef TenunChartJsonBuildResultHandler =
    void Function(TenunOptionBuildResult result);
typedef TenunChartJsonSwitchResultHandler =
    void Function(ValidatedChartTypeSwitchResult result);
typedef TenunChartJsonErrorBuilder =
    Widget Function(BuildContext context, TenunOptionBuildResult result);
typedef TenunChartJsonSwitchErrorBuilder =
    Widget Function(
      BuildContext context,
      ValidatedChartTypeSwitchResult result,
    );

/// A drop-in replacement for [TenunChart] that accepts raw JSON and
/// enables seamless chart-type switching without data loss.
class TenunChartJson extends StatefulWidget {
  /// Raw JSON configuration (ECharts style)
  final Map<String, dynamic> jsonConfig;

  /// Optional force-override for the chart type.
  /// Useful for UI toggles like "Bar / Line / Pie" buttons.
  final ChartType? forceType;

  /// Custom theme override
  final ChartTheme? theme;

  /// Controller for zoom/pan interactions
  final ChartController? controller;

  /// If true, build JSON through [TenunOption.tryBuild] and render a fallback
  /// instead of throwing when validation or config resolution fails.
  final bool safeBuild;

  /// If true, forced type switches may use supported cross-shape conversion.
  final bool forceCrossShapeSwitch;

  /// If true, run shared payload normalization before direct option parsing.
  ///
  /// Payload-level `autoNormalizePayload` flags still work when this is false.
  final bool autoNormalizePayload;

  /// Optional normalization policy used when [autoNormalizePayload] is true
  /// or the payload opts into normalization.
  final PayloadNormalizationOptions? normalizationOptions;

  /// If true, config resolution is attempted even when validation has errors.
  /// Useful for diagnostics; keep false for normal rendering.
  final bool buildWhenInvalid;

  /// Require the target type to be registered before rendering.
  final bool requireRegisteredType;

  /// Receives the non-throwing build result whenever the widget builds.
  final TenunChartJsonBuildResultHandler? onBuildResult;

  /// Receives the forced switch result when [forceType] is provided.
  final TenunChartJsonSwitchResultHandler? onSwitchResult;

  /// Optional custom fallback when [safeBuild] detects an unsafe payload.
  final TenunChartJsonErrorBuilder? errorBuilder;

  /// Optional custom fallback when a forced [forceType] switch is not render-safe.
  final TenunChartJsonSwitchErrorBuilder? switchErrorBuilder;

  /// Maximum validation issues shown by the default fallback.
  final int validationReportMaxIssues;

  /// Optional presentation options for the built-in diagnostic fallback widgets.
  final TenunDiagnosticFallbackOptions diagnosticFallbackOptions;

  const TenunChartJson({
    super.key,
    required this.jsonConfig,
    this.forceType,
    this.theme,
    this.controller,
    this.safeBuild = true,
    this.forceCrossShapeSwitch = true,
    this.autoNormalizePayload = false,
    this.normalizationOptions,
    this.buildWhenInvalid = false,
    this.requireRegisteredType = true,
    this.onBuildResult,
    this.onSwitchResult,
    this.errorBuilder,
    this.switchErrorBuilder,
    this.validationReportMaxIssues = 3,
    this.diagnosticFallbackOptions = const TenunDiagnosticFallbackOptions(),
  });

  @override
  State<TenunChartJson> createState() => _TenunChartJsonState();
}

class _TenunChartJsonState extends State<TenunChartJson> {
  late TenunOption _option;
  late String _jsonConfigSignature;
  ValidatedChartTypeSwitchResult? _forceSwitchResult;
  int? _forceSwitchRegistryGeneration;
  TenunOptionBuildResult? _cachedBuildResult;
  bool? _cachedBuildRequireRegisteredType;
  bool? _cachedBuildWhenInvalid;
  int? _cachedBuildRegistryGeneration;
  String? _lastBuildResultSignature;
  String? _lastSwitchResultSignature;

  @override
  void initState() {
    super.initState();
    _jsonConfigSignature = _jsonSignature(widget.jsonConfig);
    _option = _createOption(widget.jsonConfig);
    _applyForceType();
  }

  @override
  void didUpdateWidget(covariant TenunChartJson oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onBuildResult != widget.onBuildResult) {
      _lastBuildResultSignature = null;
    }
    if (oldWidget.onSwitchResult != widget.onSwitchResult) {
      _lastSwitchResultSignature = null;
    }
    final nextJsonConfigSignature = _jsonSignature(widget.jsonConfig);
    final payloadChanged = nextJsonConfigSignature != _jsonConfigSignature;
    final normalizationPolicyChanged =
        oldWidget.autoNormalizePayload != widget.autoNormalizePayload ||
        _normalizationOptionsSignature(oldWidget.normalizationOptions) !=
            _normalizationOptionsSignature(widget.normalizationOptions);
    final forceInputsChanged =
        payloadChanged ||
        normalizationPolicyChanged ||
        oldWidget.forceType != widget.forceType ||
        oldWidget.safeBuild != widget.safeBuild ||
        oldWidget.forceCrossShapeSwitch != widget.forceCrossShapeSwitch ||
        oldWidget.requireRegisteredType != widget.requireRegisteredType;
    final buildPolicyChanged =
        oldWidget.requireRegisteredType != widget.requireRegisteredType ||
        oldWidget.buildWhenInvalid != widget.buildWhenInvalid;

    if (forceInputsChanged) {
      _jsonConfigSignature = nextJsonConfigSignature;
      _option = _createOption(widget.jsonConfig);
      _invalidateBuildCache();
      _applyForceType();
    } else if (buildPolicyChanged) {
      _invalidateBuildCache();
    }
  }

  void _applyForceType() {
    _forceSwitchResult = null;
    _forceSwitchRegistryGeneration = null;
    if (widget.forceType != null) {
      if (!widget.safeBuild) {
        _option = _option.switchType(widget.forceType!);
        return;
      }

      final result = _option.trySwitchTypeValidated(
        widget.forceType!,
        force: widget.forceCrossShapeSwitch,
        registeredOnly: widget.requireRegisteredType,
      );
      _forceSwitchResult = result;
      _forceSwitchRegistryGeneration = ChartRegistry.generation;
      if (result.isRenderSafe && result.payload != null) {
        _option = _createOption(result.payload!);
        _invalidateBuildCache();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.safeBuild) {
      final config = _applyRuntimeOverrides(_option.build());
      return TenunChart(config: config);
    }

    final diagnosticFallbackOptions = _diagnosticFallbackOptions;
    _ensureForceSwitchCurrent();
    final switchResult = _forceSwitchResult;
    if (switchResult != null) {
      _dispatchSwitchResult(switchResult);
      if (!switchResult.isRenderSafe || switchResult.payload == null) {
        return widget.switchErrorBuilder?.call(context, switchResult) ??
            TenunSwitchBlockedFallback(
              result: switchResult,
              rawPayload: widget.jsonConfig,
              requireRegisteredType: widget.requireRegisteredType,
              validationReportMaxIssues: widget.validationReportMaxIssues,
              options: diagnosticFallbackOptions,
            );
      }
    }

    final result = _resolveBuildResult();
    _dispatchBuildResult(result);

    if (!result.isRenderSafe || result.config == null) {
      return widget.errorBuilder?.call(context, result) ??
          TenunInvalidPayloadFallback(
            result: result,
            rawPayload: widget.jsonConfig,
            requireRegisteredType: widget.requireRegisteredType,
            validationReportMaxIssues: widget.validationReportMaxIssues,
            options: diagnosticFallbackOptions,
          );
    }

    final config = _applyRuntimeOverrides(result.config!);
    return TenunChart(config: config);
  }

  void _ensureForceSwitchCurrent() {
    if (widget.forceType == null ||
        _forceSwitchRegistryGeneration == ChartRegistry.generation) {
      return;
    }

    _option = _createOption(widget.jsonConfig);
    _invalidateBuildCache();
    _applyForceType();
  }

  TenunOption _createOption(Map<String, dynamic> json) {
    return TenunOption.fromJson(
      json,
      autoNormalizePayload: widget.autoNormalizePayload,
      normalizationOptions: widget.normalizationOptions,
    );
  }

  TenunOptionBuildResult _resolveBuildResult() {
    final cached = _cachedBuildResult;
    if (cached != null &&
        _cachedBuildRequireRegisteredType == widget.requireRegisteredType &&
        _cachedBuildWhenInvalid == widget.buildWhenInvalid &&
        _cachedBuildRegistryGeneration == ChartRegistry.generation) {
      return cached;
    }

    final result = _option.tryBuild(
      requireRegisteredType: widget.requireRegisteredType,
      buildWhenInvalid: widget.buildWhenInvalid,
    );
    _cachedBuildResult = result;
    _cachedBuildRequireRegisteredType = widget.requireRegisteredType;
    _cachedBuildWhenInvalid = widget.buildWhenInvalid;
    _cachedBuildRegistryGeneration = ChartRegistry.generation;
    return result;
  }

  void _invalidateBuildCache() {
    _cachedBuildResult = null;
    _cachedBuildRequireRegisteredType = null;
    _cachedBuildWhenInvalid = null;
    _cachedBuildRegistryGeneration = null;
  }

  TenunDiagnosticFallbackOptions get _diagnosticFallbackOptions {
    return TenunDiagnosticFallbackOptions.resolve(
      widget.jsonConfig,
      fallback: widget.diagnosticFallbackOptions,
    );
  }

  void _dispatchBuildResult(TenunOptionBuildResult result) {
    final callback = widget.onBuildResult;
    if (callback == null) return;

    final signature = _buildResultSignature(result);
    if (_lastBuildResultSignature == signature) return;
    _lastBuildResultSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback(result);
    });
  }

  String _jsonSignature(Map<String, dynamic> json) {
    return ChartDataSignature.fromJson(json).hash;
  }

  String _normalizationOptionsSignature(PayloadNormalizationOptions? options) {
    return options?.toJson().toString() ?? 'default';
  }

  void _dispatchSwitchResult(ValidatedChartTypeSwitchResult result) {
    final callback = widget.onSwitchResult;
    if (callback == null) return;

    final signature = _switchResultSignature(result);
    if (_lastSwitchResultSignature == signature) return;
    _lastSwitchResultSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback(result);
    });
  }

  String _buildResultSignature(TenunOptionBuildResult result) {
    final payloadSignature = ChartDataSignature.fromJson(result.payload);
    return [
      payloadSignature.hash,
      payloadSignature.seriesCount,
      payloadSignature.dataPointCount,
      result.resolved,
      result.isRenderSafe,
      result.buildAttempted,
      result.error?.runtimeType,
      result.error?.toString(),
      _validationResultSignature(result.validation),
    ].join(':');
  }

  String _switchResultSignature(ValidatedChartTypeSwitchResult result) {
    final payload = result.payload;
    final payloadSignature = payload == null
        ? null
        : ChartDataSignature.fromJson(payload);
    return [
      result.targetTypeString,
      result.success,
      result.isRenderSafe,
      result.hasWarnings,
      result.switchResult.usedForceConversion,
      result.message,
      result.renderSafetyMessage,
      payloadSignature?.hash ?? 'payload:null',
      payloadSignature?.seriesCount ?? 0,
      payloadSignature?.dataPointCount ?? 0,
      _validationResultSignature(result.validation),
    ].join(':');
  }

  String _validationResultSignature(ValidationResult? result) {
    if (result == null) return 'validation:null';
    return [
      result.type.name,
      result.isValid,
      result.hasWarnings,
      result.issues.length,
      result.issues.map((issue) => issue.toString()).join('|'),
    ].join(':');
  }

  BaseChartConfig _applyRuntimeOverrides(BaseChartConfig config) {
    // Apply theme if provided
    if (widget.theme != null) {
      config = config.withTheme(widget.theme!);
    }

    // Apply controller if supported
    if (widget.controller != null) {
      config = config.withController(widget.controller!);
    }

    return config;
  }
}
