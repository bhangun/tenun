import 'package:flutter/material.dart';

import 'base_config.dart';
import 'chart_config_validator.dart';
import 'chart_data_signature.dart';
import 'chart_runtime_diagnostics.dart';
import '../widget/chart_diagnostic_fallback.dart';

typedef ChartRenderErrorHandler =
    void Function(Object error, StackTrace stackTrace);
typedef ChartRenderErrorBuilder =
    Widget Function(BuildContext context, Object error, StackTrace stackTrace);

/// Main chart widget that can be configured with either a config object or JSON
class TenunChart extends StatefulWidget {
  /// Chart configuration object (optional if using jsonConfig)
  final BaseChartConfig? config;

  /// JSON configuration (optional if using config)
  final Map<String, dynamic>? jsonConfig;

  /// Optional width constraint
  final double? width;

  /// Optional height constraint
  final double? height;

  /// Optional padding
  final EdgeInsetsGeometry? padding;

  /// Run payload/config validation before rendering.
  final bool validatePayload;

  /// If true, invalid payload/config shows an error widget instead of rendering.
  final bool strictValidation;

  /// Maximum validation issues shown by the default strict-validation fallback.
  final int validationReportMaxIssues;

  /// Optional presentation options for the built-in diagnostic fallback widgets.
  final TenunDiagnosticFallbackOptions diagnosticFallbackOptions;

  /// Optional callback to receive validation result.
  final void Function(ValidationResult result)? onValidationResult;

  /// Optional callback to inspect the exact JSON payload used for rendering.
  final void Function(PayloadNormalizationResult result)?
  onPayloadNormalizationResult;

  /// Optional callback for lightweight runtime/build diagnostics.
  final void Function(ChartRuntimeDiagnostics diagnostics)?
  onRuntimeDiagnostics;

  /// Optional thresholds for runtime performance recommendations.
  final ChartRuntimePerformancePolicy runtimePerformancePolicy;

  /// Optional callback for render-time config/build failures.
  final ChartRenderErrorHandler? onRenderError;

  /// Optional custom builder for strict validation failure UI.
  final Widget Function(BuildContext context, ValidationResult result)?
  validationErrorBuilder;

  /// Optional custom builder for render-time config/build failures.
  final ChartRenderErrorBuilder? renderErrorBuilder;

  /// If true, config resolution/build errors render a fallback instead of
  /// bubbling through Flutter's widget error path.
  final bool catchRenderErrors;

  /// Normalize payload before validate/parse.
  ///
  /// Includes:
  /// - `dataMode` / `sampling` canonicalization
  /// - trading payload sanitation for `kagi` / `renko` / `macd`
  final bool autoNormalizePayload;

  /// If true, auto-normalization also repairs trading payloads by extracting
  /// numeric price rows and clamping invalid trading parameters.
  final bool sanitizeTradingPayload;

  /// If true, unsupported chart types are normalized to regular mode and
  /// sampling is disabled during auto-normalization.
  final bool dropUnsupportedSampling;

  /// Optional threshold override used by auto-normalization fallback.
  final int? normalizeDefaultThreshold;

  /// Default mode used by auto-normalization fallback.
  final ChartDataMode normalizeDefaultMode;

  /// Optional reusable normalization policy. When provided, it takes precedence
  /// over individual normalization parameters above.
  final PayloadNormalizationOptions? normalizationOptions;

  const TenunChart({
    super.key,
    this.config,
    this.jsonConfig,
    this.width,
    this.height,
    this.padding,
    this.validatePayload = false,
    this.strictValidation = false,
    this.validationReportMaxIssues = 3,
    this.diagnosticFallbackOptions = const TenunDiagnosticFallbackOptions(),
    this.onValidationResult,
    this.onPayloadNormalizationResult,
    this.onRuntimeDiagnostics,
    this.runtimePerformancePolicy = ChartRuntimePerformancePolicy.defaults,
    this.onRenderError,
    this.validationErrorBuilder,
    this.renderErrorBuilder,
    this.catchRenderErrors = false,
    this.autoNormalizePayload = false,
    this.sanitizeTradingPayload = true,
    this.dropUnsupportedSampling = true,
    this.normalizeDefaultThreshold,
    this.normalizeDefaultMode = ChartDataMode.auto,
    this.normalizationOptions,
  });

  @override
  State<TenunChart> createState() => _TenunChartState();
}

class _TenunChartState extends State<TenunChart> {
  String? _lastPayloadNormalizationSignature;
  String? _lastRuntimeDiagnosticsSignature;
  String? _lastRenderErrorSignature;
  String? _pendingPayloadNormalizationKey;
  String? _pendingRuntimeDiagnosticsKey;
  String? _pendingRenderErrorKey;
  int _callbackGeneration = 0;
  final Map<String, String> _lastValidationSignaturesByStage =
      <String, String>{};
  final Map<String, String> _pendingValidationKeysByStage = <String, String>{};

  @override
  void didUpdateWidget(covariant TenunChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _callbackGeneration++;
    _pendingPayloadNormalizationKey = null;
    _pendingValidationKeysByStage.clear();
    _pendingRuntimeDiagnosticsKey = null;
    _pendingRenderErrorKey = null;
    if (oldWidget.onPayloadNormalizationResult != null &&
        widget.onPayloadNormalizationResult == null) {
      _lastPayloadNormalizationSignature = null;
    }
    if (oldWidget.onValidationResult != null &&
        widget.onValidationResult == null) {
      _lastValidationSignaturesByStage.clear();
    }
    if (oldWidget.onRuntimeDiagnostics != null &&
        widget.onRuntimeDiagnostics == null) {
      _lastRuntimeDiagnosticsSignature = null;
    }
    if (oldWidget.onRenderError != null && widget.onRenderError == null) {
      _lastRenderErrorSignature = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldCatchRenderErrors) {
      try {
        return _buildChartContent(context);
      } catch (error, stackTrace) {
        _dispatchRenderError(error, stackTrace);
        return _applyFrame(_buildRenderError(context, error, stackTrace));
      }
    }
    return _buildChartContent(context);
  }

  bool get _shouldCatchRenderErrors =>
      widget.catchRenderErrors ||
      widget.onRenderError != null ||
      widget.renderErrorBuilder != null;

  Widget _buildChartContent(BuildContext context) {
    final buildStopwatch = Stopwatch()..start();
    if (widget.config == null && widget.jsonConfig == null) {
      return const SizedBox.shrink();
    }

    final shouldNormalizePayload = _shouldNormalizePayload;
    final PayloadNormalizationResult? normalizationResult =
        widget.jsonConfig != null
        ? (shouldNormalizePayload
              ? ChartConfigValidator.normalizePayloadWithReport(
                  widget.jsonConfig!,
                  options: _normalizationOptions,
                )
              : PayloadNormalizationResult.passThrough(widget.jsonConfig!))
        : null;
    if (normalizationResult != null) {
      _dispatchPayloadNormalizationResult(normalizationResult);
    }

    final effectiveJson = normalizationResult?.normalizedPayload;

    if (effectiveJson != null && widget.validatePayload) {
      final rawValidation = ChartConfigValidator.validateJsonPayload(
        effectiveJson,
        deep: false,
      );
      _dispatchValidationResult('json', rawValidation);
      if (widget.strictValidation && !rawValidation.isValid) {
        return _buildValidationError(
          context,
          rawValidation,
          rawPayload: effectiveJson,
        );
      }
    }

    final configResolveStopwatch = Stopwatch()..start();
    final effectiveConfig = widget.config ?? _resolveJsonConfig(effectiveJson!);
    configResolveStopwatch.stop();

    if (widget.validatePayload) {
      final cfgValidation = ChartConfigValidator.validate(effectiveConfig);
      _dispatchValidationResult('config', cfgValidation);
      if (widget.strictValidation && !cfgValidation.isValid) {
        return _buildValidationError(
          context,
          cfgValidation,
          rawPayload: effectiveJson,
        );
      }
    }

    final chartBuildStopwatch = Stopwatch()..start();
    final chart = ChartFactory.createChart(effectiveConfig);
    chartBuildStopwatch.stop();
    buildStopwatch.stop();

    _dispatchRuntimeDiagnostics(
      ChartRuntimeDiagnostics.fromResolvedConfig(
        config: effectiveConfig,
        jsonDriven: widget.jsonConfig != null,
        effectiveJson: effectiveJson,
        normalizationResult: normalizationResult,
        configResolveDuration: configResolveStopwatch.elapsed,
        chartBuildDuration: chartBuildStopwatch.elapsed,
        totalBuildDuration: buildStopwatch.elapsed,
        performancePolicyResolution: _runtimePerformancePolicyResolution(
          effectiveJson,
        ),
      ),
    );

    Widget result = chart;

    return _applyFrame(result);
  }

  Widget _applyFrame(Widget result) {
    if (widget.padding != null) {
      result = Padding(padding: widget.padding!, child: result);
    }

    if (widget.width != null || widget.height != null) {
      result = SizedBox(
        width: widget.width,
        height: widget.height,
        child: result,
      );
    }

    return result;
  }

  BaseChartConfig _resolveJsonConfig(Map<String, dynamic> effectiveJson) {
    return ChartFactory.fromJson(
      effectiveJson,
      validatePayload: widget.validatePayload,
      strictValidation: widget.strictValidation,
      validationReportMaxIssues: widget.validationReportMaxIssues,
      // Widget callbacks are dispatched post-frame by this state object.
      onValidationResult: null,
      autoNormalizePayload: false,
      normalizationOptions: _normalizationOptions,
    );
  }

  void _dispatchPayloadNormalizationResult(PayloadNormalizationResult result) {
    final callback = widget.onPayloadNormalizationResult;
    if (callback == null) return;

    final signature = _payloadNormalizationSignature(result);
    if (_lastPayloadNormalizationSignature == signature) return;
    final pendingKey = _pendingCallbackKey(signature);
    if (_pendingPayloadNormalizationKey == pendingKey) return;
    _pendingPayloadNormalizationKey = pendingKey;

    _dispatchPostFrameIfCurrent(
      pendingKey: pendingKey,
      clearPending: (key) {
        if (_pendingPayloadNormalizationKey == key) {
          _pendingPayloadNormalizationKey = null;
        }
      },
      callback: () {
        _lastPayloadNormalizationSignature = signature;
        callback(result);
      },
    );
  }

  void _dispatchValidationResult(String stage, ValidationResult result) {
    final callback = widget.onValidationResult;
    if (callback == null) return;

    final signature = _validationSignature(stage, result);
    if (_lastValidationSignaturesByStage[stage] == signature) return;
    final pendingKey = _pendingCallbackKey(signature);
    if (_pendingValidationKeysByStage[stage] == pendingKey) return;
    _pendingValidationKeysByStage[stage] = pendingKey;

    _dispatchPostFrameIfCurrent(
      pendingKey: pendingKey,
      clearPending: (key) {
        if (_pendingValidationKeysByStage[stage] == key) {
          _pendingValidationKeysByStage.remove(stage);
        }
      },
      callback: () {
        _lastValidationSignaturesByStage[stage] = signature;
        callback(result);
      },
    );
  }

  void _dispatchRuntimeDiagnostics(ChartRuntimeDiagnostics diagnostics) {
    final callback = widget.onRuntimeDiagnostics;
    if (callback == null) return;

    final signature = diagnostics.stableSignature;
    if (_lastRuntimeDiagnosticsSignature == signature) return;
    final pendingKey = _pendingCallbackKey(signature);
    if (_pendingRuntimeDiagnosticsKey == pendingKey) return;
    _pendingRuntimeDiagnosticsKey = pendingKey;

    _dispatchPostFrameIfCurrent(
      pendingKey: pendingKey,
      clearPending: (key) {
        if (_pendingRuntimeDiagnosticsKey == key) {
          _pendingRuntimeDiagnosticsKey = null;
        }
      },
      callback: () {
        _lastRuntimeDiagnosticsSignature = signature;
        callback(diagnostics);
      },
    );
  }

  void _dispatchRenderError(Object error, StackTrace stackTrace) {
    final callback = widget.onRenderError;
    if (callback == null) return;

    final signature = _renderErrorSignature(error);
    if (_lastRenderErrorSignature == signature) return;
    final pendingKey = _pendingCallbackKey(signature);
    if (_pendingRenderErrorKey == pendingKey) return;
    _pendingRenderErrorKey = pendingKey;

    _dispatchPostFrameIfCurrent(
      pendingKey: pendingKey,
      clearPending: (key) {
        if (_pendingRenderErrorKey == key) {
          _pendingRenderErrorKey = null;
        }
      },
      callback: () {
        _lastRenderErrorSignature = signature;
        callback(error, stackTrace);
      },
    );
  }

  String _pendingCallbackKey(String signature) {
    return '$_callbackGeneration:$signature';
  }

  void _dispatchPostFrameIfCurrent({
    required String pendingKey,
    required void Function(String key) clearPending,
    required VoidCallback callback,
  }) {
    final generation = _callbackGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _callbackGeneration) {
        clearPending(pendingKey);
        return;
      }
      clearPending(pendingKey);
      callback();
    });
  }

  String _renderErrorSignature(Object error) {
    final inputHash = widget.jsonConfig != null
        ? ChartDataSignature.fromJson(widget.jsonConfig!).hash
        : widget.config != null
        ? ChartDataSignature.fromConfig(widget.config!).hash
        : 'empty';
    return [
      inputHash,
      widget.catchRenderErrors,
      widget.renderErrorBuilder != null,
      error.runtimeType,
      error.toString(),
    ].join(':');
  }

  String _payloadNormalizationSignature(PayloadNormalizationResult result) {
    final rawSignature = ChartDataSignature.fromJson(result.rawPayload);
    final normalizedSignature = ChartDataSignature.fromJson(
      result.normalizedPayload,
    );
    return [
      rawSignature.hash,
      normalizedSignature.hash,
      _shouldNormalizePayload,
      _normalizationOptions.toJson(),
      result.summary.total,
      result.changedPaths.join('|'),
    ].join(':');
  }

  bool get _shouldNormalizePayload {
    return PayloadNormalizationOptions.shouldAutoNormalize(
      widget.jsonConfig,
      fallback: widget.autoNormalizePayload,
    );
  }

  PayloadNormalizationOptions get _normalizationOptions {
    final fallback =
        widget.normalizationOptions ??
        PayloadNormalizationOptions(
          dropUnsupportedSampling: widget.dropUnsupportedSampling,
          defaultThreshold: widget.normalizeDefaultThreshold,
          defaultMode: widget.normalizeDefaultMode,
          sanitizeTradingPayload: widget.sanitizeTradingPayload,
        );
    return PayloadNormalizationOptions.resolve(
      widget.jsonConfig,
      fallback: fallback,
    );
  }

  ChartRuntimePerformancePolicyResolution _runtimePerformancePolicyResolution(
    Map<String, dynamic>? effectiveJson,
  ) {
    return ChartRuntimePerformancePolicy.resolve(
      effectiveJson,
      fallback: widget.runtimePerformancePolicy,
    );
  }

  String _validationSignature(String stage, ValidationResult result) {
    final inputHash = widget.jsonConfig != null
        ? ChartDataSignature.fromJson(widget.jsonConfig!).hash
        : ChartDataSignature.fromConfig(widget.config!).hash;
    return [
      stage,
      inputHash,
      widget.validatePayload,
      widget.strictValidation,
      widget.validationReportMaxIssues,
      result.type.name,
      result.isValid,
      result.issues.map((issue) => issue.toString()).join('|'),
    ].join(':');
  }

  Widget _buildValidationError(
    BuildContext context,
    ValidationResult result, {
    Map<String, dynamic>? rawPayload,
  }) {
    if (widget.validationErrorBuilder != null) {
      return widget.validationErrorBuilder!(context, result);
    }
    return TenunValidationReportFallback(
      result: result,
      rawPayload: rawPayload,
      validationReportMaxIssues: widget.validationReportMaxIssues,
      options: _diagnosticFallbackOptions(rawPayload),
    );
  }

  Widget _buildRenderError(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (widget.renderErrorBuilder != null) {
      return widget.renderErrorBuilder!(context, error, stackTrace);
    }
    return TenunRenderErrorFallback(
      error: error,
      stackTrace: stackTrace,
      rawPayload: widget.jsonConfig,
      requireRegisteredType: true,
      validationReportMaxIssues: widget.validationReportMaxIssues,
      options: _diagnosticFallbackOptions(widget.jsonConfig),
    );
  }

  TenunDiagnosticFallbackOptions _diagnosticFallbackOptions(
    Map<String, dynamic>? json,
  ) {
    return TenunDiagnosticFallbackOptions.resolve(
      json,
      fallback: widget.diagnosticFallbackOptions,
    );
  }
}

/// Factory class for creating charts from configurations or JSON
class ChartFactory {
  /// Create a chart from a configuration object
  static Widget createChart(BaseChartConfig config) {
    return config.buildChart();
  }

  /// Create a chart configuration from JSON
  static BaseChartConfig fromJson(
    Map<String, dynamic> json, {
    bool validatePayload = false,
    bool strictValidation = false,
    void Function(ValidationResult result)? onValidationResult,
    void Function(PayloadNormalizationResult result)?
    onPayloadNormalizationResult,
    bool autoNormalizePayload = false,
    bool sanitizeTradingPayload = true,
    bool dropUnsupportedSampling = true,
    int? normalizeDefaultThreshold,
    ChartDataMode normalizeDefaultMode = ChartDataMode.auto,
    PayloadNormalizationOptions? normalizationOptions,
    int validationReportMaxIssues = 5,
  }) {
    final fallbackNormalizationOptions =
        normalizationOptions ??
        PayloadNormalizationOptions(
          dropUnsupportedSampling: dropUnsupportedSampling,
          defaultThreshold: normalizeDefaultThreshold,
          defaultMode: normalizeDefaultMode,
          sanitizeTradingPayload: sanitizeTradingPayload,
        );
    final effectiveNormalizationOptions = PayloadNormalizationOptions.resolve(
      json,
      fallback: fallbackNormalizationOptions,
    );
    final shouldNormalizePayload =
        PayloadNormalizationOptions.shouldAutoNormalize(
          json,
          fallback: autoNormalizePayload,
        );
    final normalizationResult = shouldNormalizePayload
        ? ChartConfigValidator.normalizePayloadWithReport(
            json,
            options: effectiveNormalizationOptions,
          )
        : PayloadNormalizationResult.passThrough(json);
    onPayloadNormalizationResult?.call(normalizationResult);
    final effectiveJson = normalizationResult.normalizedPayload;

    if (validatePayload) {
      final result = ChartConfigValidator.validateJsonPayload(
        effectiveJson,
        deep: true,
      );
      onValidationResult?.call(result);
      if (strictValidation && !result.isValid) {
        throw FormatException(
          result.toReport(maxIssues: validationReportMaxIssues).toPlainText(),
        );
      }
    }
    return BaseChartConfig.fromJson(effectiveJson);
  }

  /// Create and build a chart directly from JSON
  static Widget fromJsonToChart(
    Map<String, dynamic> json, {
    bool autoNormalizePayload = false,
    bool sanitizeTradingPayload = true,
    bool dropUnsupportedSampling = true,
    int? normalizeDefaultThreshold,
    ChartDataMode normalizeDefaultMode = ChartDataMode.auto,
    PayloadNormalizationOptions? normalizationOptions,
    void Function(PayloadNormalizationResult result)?
    onPayloadNormalizationResult,
    bool validatePayload = false,
    bool strictValidation = false,
    void Function(ValidationResult result)? onValidationResult,
    int validationReportMaxIssues = 5,
  }) {
    final config = fromJson(
      json,
      validatePayload: validatePayload,
      strictValidation: strictValidation,
      autoNormalizePayload: autoNormalizePayload,
      sanitizeTradingPayload: sanitizeTradingPayload,
      dropUnsupportedSampling: dropUnsupportedSampling,
      normalizeDefaultThreshold: normalizeDefaultThreshold,
      normalizeDefaultMode: normalizeDefaultMode,
      normalizationOptions: normalizationOptions,
      onValidationResult: onValidationResult,
      onPayloadNormalizationResult: onPayloadNormalizationResult,
      validationReportMaxIssues: validationReportMaxIssues,
    );
    return config.buildChart();
  }
}

/// Convenience widget for creating charts directly from JSON
class TenunChartFromJson extends StatelessWidget {
  final Map<String, dynamic> jsonConfig;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool validatePayload;
  final bool strictValidation;
  final int validationReportMaxIssues;
  final TenunDiagnosticFallbackOptions diagnosticFallbackOptions;
  final void Function(ValidationResult result)? onValidationResult;
  final void Function(PayloadNormalizationResult result)?
  onPayloadNormalizationResult;
  final void Function(ChartRuntimeDiagnostics diagnostics)?
  onRuntimeDiagnostics;
  final ChartRuntimePerformancePolicy runtimePerformancePolicy;
  final ChartRenderErrorHandler? onRenderError;
  final Widget Function(BuildContext context, ValidationResult result)?
  validationErrorBuilder;
  final ChartRenderErrorBuilder? renderErrorBuilder;

  /// Render JSON payload failures as a diagnostic fallback by default.
  ///
  /// Set this to false when tests or developer tools should observe the raw
  /// chart parsing/render exception.
  final bool catchRenderErrors;
  final bool autoNormalizePayload;
  final bool sanitizeTradingPayload;
  final bool dropUnsupportedSampling;
  final int? normalizeDefaultThreshold;
  final ChartDataMode normalizeDefaultMode;
  final PayloadNormalizationOptions? normalizationOptions;

  const TenunChartFromJson({
    super.key,
    required this.jsonConfig,
    this.width,
    this.height,
    this.padding,
    this.validatePayload = false,
    this.strictValidation = false,
    this.validationReportMaxIssues = 3,
    this.diagnosticFallbackOptions = const TenunDiagnosticFallbackOptions(),
    this.onValidationResult,
    this.onPayloadNormalizationResult,
    this.onRuntimeDiagnostics,
    this.runtimePerformancePolicy = ChartRuntimePerformancePolicy.defaults,
    this.onRenderError,
    this.validationErrorBuilder,
    this.renderErrorBuilder,
    this.catchRenderErrors = true,
    this.autoNormalizePayload = false,
    this.sanitizeTradingPayload = true,
    this.dropUnsupportedSampling = true,
    this.normalizeDefaultThreshold,
    this.normalizeDefaultMode = ChartDataMode.auto,
    this.normalizationOptions,
  });

  @override
  Widget build(BuildContext context) {
    return TenunChart(
      jsonConfig: jsonConfig,
      width: width,
      height: height,
      padding: padding,
      validatePayload: validatePayload,
      strictValidation: strictValidation,
      validationReportMaxIssues: validationReportMaxIssues,
      diagnosticFallbackOptions: diagnosticFallbackOptions,
      onValidationResult: onValidationResult,
      onPayloadNormalizationResult: onPayloadNormalizationResult,
      onRuntimeDiagnostics: onRuntimeDiagnostics,
      runtimePerformancePolicy: runtimePerformancePolicy,
      onRenderError: onRenderError,
      validationErrorBuilder: validationErrorBuilder,
      renderErrorBuilder: renderErrorBuilder,
      catchRenderErrors: catchRenderErrors,
      autoNormalizePayload: autoNormalizePayload,
      sanitizeTradingPayload: sanitizeTradingPayload,
      dropUnsupportedSampling: dropUnsupportedSampling,
      normalizeDefaultThreshold: normalizeDefaultThreshold,
      normalizeDefaultMode: normalizeDefaultMode,
      normalizationOptions: normalizationOptions,
    );
  }
}
