import 'base_config.dart';
import 'chart_cache.dart';
import 'chart_config_validator.dart';
import 'chart_data_processor.dart';
import 'chart_data_signature.dart';
import 'chart_runtime_policy_fields.dart';
import 'chart_type.dart';
import 'json_value.dart';
import 'picture_cache.dart';

/// Tunable thresholds for runtime performance recommendations.
class ChartRuntimePerformancePolicy {
  static const int defaultLargeDatasetPointThreshold = 10000;
  static const double defaultCachePressureWarningThreshold = 0.9;
  static const double defaultLowRenderCacheHitRateThreshold = 0.25;
  static const int defaultLowRenderCacheMinRequests = 20;

  static const defaults = ChartRuntimePerformancePolicy();

  final int largeDatasetPointThreshold;
  final double cachePressureWarningThreshold;
  final double lowRenderCacheHitRateThreshold;
  final int lowRenderCacheMinRequests;

  const ChartRuntimePerformancePolicy({
    this.largeDatasetPointThreshold = defaultLargeDatasetPointThreshold,
    this.cachePressureWarningThreshold = defaultCachePressureWarningThreshold,
    this.lowRenderCacheHitRateThreshold = defaultLowRenderCacheHitRateThreshold,
    this.lowRenderCacheMinRequests = defaultLowRenderCacheMinRequests,
  });

  /// Resolve a policy from a JSON/config object.
  ///
  /// Accepted shapes:
  /// - `{ "runtimePerformancePolicy": { ... } }`
  /// - `{ "performancePolicy": { ... } }`
  /// - `{ "diagnostics": { "performancePolicy": { ... } } }`
  /// - direct policy maps, useful for tooling/tests
  factory ChartRuntimePerformancePolicy.fromJson(
    Object? json, {
    ChartRuntimePerformancePolicy fallback =
        ChartRuntimePerformancePolicy.defaults,
  }) {
    return resolve(json, fallback: fallback).policy;
  }

  static ChartRuntimePerformancePolicyResolution resolve(
    Object? json, {
    ChartRuntimePerformancePolicy fallback =
        ChartRuntimePerformancePolicy.defaults,
  }) {
    final match = _runtimePerformancePolicyMatch(json);
    if (match == null) {
      return ChartRuntimePerformancePolicyResolution.fallback(fallback);
    }

    final policy = fallback.copyWith(
      largeDatasetPointThreshold: ChartRuntimePerformancePolicyFields.readInt(
        match.map,
        ChartRuntimePerformancePolicyFields.largeDatasetPointThresholdAliases,
      ),
      cachePressureWarningThreshold:
          ChartRuntimePerformancePolicyFields.readRatio(
            match.map,
            ChartRuntimePerformancePolicyFields
                .cachePressureWarningThresholdAliases,
          ),
      lowRenderCacheHitRateThreshold:
          ChartRuntimePerformancePolicyFields.readRatio(
            match.map,
            ChartRuntimePerformancePolicyFields
                .lowRenderCacheHitRateThresholdAliases,
          ),
      lowRenderCacheMinRequests: ChartRuntimePerformancePolicyFields.readInt(
        match.map,
        ChartRuntimePerformancePolicyFields.lowRenderCacheMinRequestsAliases,
      ),
    );
    return ChartRuntimePerformancePolicyResolution.json(
      policy,
      sourcePath: match.path,
    );
  }

  int get normalizedLargeDatasetPointThreshold =>
      largeDatasetPointThreshold < 1 ? 1 : largeDatasetPointThreshold;

  double get normalizedCachePressureWarningThreshold =>
      _normalizedUnitRatio(cachePressureWarningThreshold);

  double get normalizedLowRenderCacheHitRateThreshold =>
      _normalizedUnitRatio(lowRenderCacheHitRateThreshold);

  int get normalizedLowRenderCacheMinRequests =>
      lowRenderCacheMinRequests < 1 ? 1 : lowRenderCacheMinRequests;

  ChartRuntimePerformancePolicy copyWith({
    int? largeDatasetPointThreshold,
    double? cachePressureWarningThreshold,
    double? lowRenderCacheHitRateThreshold,
    int? lowRenderCacheMinRequests,
  }) {
    return ChartRuntimePerformancePolicy(
      largeDatasetPointThreshold:
          largeDatasetPointThreshold ?? this.largeDatasetPointThreshold,
      cachePressureWarningThreshold:
          cachePressureWarningThreshold ?? this.cachePressureWarningThreshold,
      lowRenderCacheHitRateThreshold:
          lowRenderCacheHitRateThreshold ?? this.lowRenderCacheHitRateThreshold,
      lowRenderCacheMinRequests:
          lowRenderCacheMinRequests ?? this.lowRenderCacheMinRequests,
    );
  }

  String get stableSignature => [
    normalizedLargeDatasetPointThreshold,
    normalizedCachePressureWarningThreshold,
    normalizedLowRenderCacheHitRateThreshold,
    normalizedLowRenderCacheMinRequests,
  ].join(':');

  Map<String, dynamic> toJson() => {
    'largeDatasetPointThreshold': normalizedLargeDatasetPointThreshold,
    'cachePressureWarningThreshold': normalizedCachePressureWarningThreshold,
    'lowRenderCacheHitRateThreshold': normalizedLowRenderCacheHitRateThreshold,
    'lowRenderCacheMinRequests': normalizedLowRenderCacheMinRequests,
  };
}

enum ChartRuntimePerformancePolicySource { fallback, json }

class ChartRuntimePerformancePolicyResolution {
  final ChartRuntimePerformancePolicy policy;
  final ChartRuntimePerformancePolicySource source;
  final String? sourcePath;

  const ChartRuntimePerformancePolicyResolution({
    required this.policy,
    required this.source,
    this.sourcePath,
  });

  const ChartRuntimePerformancePolicyResolution.fallback(
    ChartRuntimePerformancePolicy policy,
  ) : this(
        policy: policy,
        source: ChartRuntimePerformancePolicySource.fallback,
      );

  const ChartRuntimePerformancePolicyResolution.json(
    ChartRuntimePerformancePolicy policy, {
    String? sourcePath,
  }) : this(
         policy: policy,
         source: ChartRuntimePerformancePolicySource.json,
         sourcePath: sourcePath,
       );

  bool get fromJson => source == ChartRuntimePerformancePolicySource.json;

  String get sourceLabel {
    if (source == ChartRuntimePerformancePolicySource.fallback) {
      return source.name;
    }
    final path = sourcePath?.trim();
    return path == null || path.isEmpty ? 'json' : path;
  }

  String get stableSignature =>
      [source.name, sourcePath ?? '', policy.stableSignature].join(':');

  Map<String, dynamic> toJson() => {
    'source': source.name,
    'fromJson': fromJson,
    'sourceLabel': sourceLabel,
    if (sourcePath != null && sourcePath!.isNotEmpty) 'sourcePath': sourcePath,
    'policy': policy.toJson(),
  };
}

/// Lightweight runtime report emitted by [TenunChart].
///
/// This intentionally summarizes render inputs and runtime policy decisions
/// without re-processing data or touching painter internals.
class ChartRuntimeDiagnostics {
  final ChartType type;
  final String typeString;
  final bool jsonDriven;
  final ChartDataSignature inputSignature;
  final ChartDataSignature configSignature;
  final int sourceDataPointCount;
  final int? effectiveDataPointCount;
  final int? sampleInputPointCount;
  final int renderedDataPointCount;
  final int seriesCount;
  final bool configSampledData;
  final ChartDataSignature? rawInputSignature;
  final bool payloadWasNormalized;
  final bool payloadChanged;
  final int payloadDiffCount;
  final List<String> payloadChangedPaths;
  final String? dataMode;
  final Object? sampling;
  final Duration configResolveDuration;
  final Duration chartBuildDuration;
  final Duration totalBuildDuration;
  final ChartDataProcessingCacheStats processingCacheStats;
  final ChartRenderCacheStats? renderCacheStats;
  final PictureCacheStats? pictureCacheStats;
  final ChartRuntimePerformanceSummary performanceSummary;
  final ChartRuntimePerformancePolicyResolution performancePolicyResolution;

  const ChartRuntimeDiagnostics({
    required this.type,
    required this.typeString,
    required this.jsonDriven,
    required this.inputSignature,
    required this.configSignature,
    required this.sourceDataPointCount,
    this.effectiveDataPointCount,
    this.sampleInputPointCount,
    required this.renderedDataPointCount,
    required this.seriesCount,
    required this.configSampledData,
    this.rawInputSignature,
    this.payloadWasNormalized = false,
    this.payloadChanged = false,
    this.payloadDiffCount = 0,
    this.payloadChangedPaths = const [],
    required this.configResolveDuration,
    required this.chartBuildDuration,
    required this.totalBuildDuration,
    required this.processingCacheStats,
    required this.performanceSummary,
    ChartRuntimePerformancePolicyResolution? performancePolicyResolution,
    this.renderCacheStats,
    this.pictureCacheStats,
    this.dataMode,
    this.sampling,
  }) : performancePolicyResolution =
           performancePolicyResolution ??
           const ChartRuntimePerformancePolicyResolution.fallback(
             ChartRuntimePerformancePolicy.defaults,
           );

  factory ChartRuntimeDiagnostics.fromResolvedConfig({
    required BaseChartConfig config,
    required bool jsonDriven,
    required Duration configResolveDuration,
    required Duration chartBuildDuration,
    required Duration totalBuildDuration,
    Map<String, dynamic>? effectiveJson,
    PayloadNormalizationResult? normalizationResult,
    ChartDataProcessingReport? processingReport,
    ChartRuntimePerformancePolicy performancePolicy =
        ChartRuntimePerformancePolicy.defaults,
    ChartRuntimePerformancePolicyResolution? performancePolicyResolution,
  }) {
    final resolvedPerformancePolicy =
        performancePolicyResolution ??
        ChartRuntimePerformancePolicyResolution.fallback(performancePolicy);
    final configSignature = ChartDataSignature.fromConfig(config);
    final inputSignature = effectiveJson != null
        ? ChartDataSignature.fromJson(effectiveJson)
        : configSignature;
    final rawInputSignature = normalizationResult != null
        ? ChartDataSignature.fromJson(normalizationResult.rawPayload)
        : null;
    final sourceCount = inputSignature.dataPointCount;
    final renderedCount =
        processingReport?.outputPointCount ?? configSignature.dataPointCount;
    final effectiveCount = processingReport?.effectiveDataPointCount;
    final sampleInputCount = processingReport?.sampleInputPointCount;
    final processingCacheStats = ChartDataProcessor.processingCacheStats;
    final renderCacheStats = chartRenderCacheStats;
    final pictureCacheStats = pictureCache.stats;

    return ChartRuntimeDiagnostics(
      type: config.type,
      typeString: chartTypeToString(config.type),
      jsonDriven: jsonDriven,
      inputSignature: inputSignature,
      configSignature: configSignature,
      sourceDataPointCount: sourceCount,
      effectiveDataPointCount: effectiveCount,
      sampleInputPointCount: sampleInputCount,
      renderedDataPointCount: renderedCount,
      seriesCount: configSignature.seriesCount,
      configSampledData: renderedCount < sourceCount,
      rawInputSignature: rawInputSignature,
      payloadWasNormalized: normalizationResult?.wasNormalized ?? false,
      payloadChanged: normalizationResult?.changed ?? false,
      payloadDiffCount: normalizationResult?.summary.total ?? 0,
      payloadChangedPaths: normalizationResult?.changedPaths ?? const [],
      dataMode: effectiveJson?['dataMode']?.toString(),
      sampling: effectiveJson?['sampling'],
      configResolveDuration: configResolveDuration,
      chartBuildDuration: chartBuildDuration,
      totalBuildDuration: totalBuildDuration,
      processingCacheStats: processingCacheStats,
      renderCacheStats: renderCacheStats,
      pictureCacheStats: pictureCacheStats,
      performanceSummary: ChartRuntimePerformanceSummary.fromRuntimeInputs(
        sourceDataPointCount: sourceCount,
        effectiveDataPointCount: effectiveCount,
        sampleInputPointCount: sampleInputCount,
        renderedDataPointCount: renderedCount,
        seriesCount: configSignature.seriesCount,
        configSampledData: renderedCount < sourceCount,
        payloadWasNormalized: normalizationResult?.wasNormalized ?? false,
        payloadChanged: normalizationResult?.changed ?? false,
        processingCacheStats: processingCacheStats,
        renderCacheStats: renderCacheStats,
        pictureCacheStats: pictureCacheStats,
        policy: resolvedPerformancePolicy.policy,
      ),
      performancePolicyResolution: resolvedPerformancePolicy,
    );
  }

  ChartRuntimePerformancePolicySource get performancePolicySource =>
      performancePolicyResolution.source;

  String? get performancePolicySourcePath =>
      performancePolicyResolution.sourcePath;

  String get performancePolicySourceLabel =>
      performancePolicyResolution.sourceLabel;

  bool get performancePolicyFromJson => performancePolicyResolution.fromJson;

  String get stableSignature {
    return [
      typeString,
      jsonDriven,
      inputSignature.hash,
      rawInputSignature?.hash,
      sourceDataPointCount,
      effectiveDataPointCount,
      sampleInputPointCount,
      renderedDataPointCount,
      seriesCount,
      configSampledData,
      payloadWasNormalized,
      payloadChanged,
      payloadDiffCount,
      payloadChangedPaths.join('|'),
      dataMode,
      canonicalizeChartData(sampling),
      performancePolicyResolution.stableSignature,
    ].join(':');
  }

  Map<String, dynamic> toJson() => {
    'type': typeString,
    'jsonDriven': jsonDriven,
    'inputSignature': inputSignature.toJson(),
    if (rawInputSignature != null)
      'rawInputSignature': rawInputSignature!.toJson(),
    'configSignature': configSignature.toJson(),
    'sourceDataPointCount': sourceDataPointCount,
    if (effectiveDataPointCount != null)
      'effectiveDataPointCount': effectiveDataPointCount,
    if (sampleInputPointCount != null)
      'sampleInputPointCount': sampleInputPointCount,
    'renderedDataPointCount': renderedDataPointCount,
    'seriesCount': seriesCount,
    'configSampledData': configSampledData,
    'payloadNormalization': {
      'wasNormalized': payloadWasNormalized,
      'changed': payloadChanged,
      'diffCount': payloadDiffCount,
      if (payloadChangedPaths.isNotEmpty)
        'changedPaths': List<String>.from(payloadChangedPaths),
    },
    if (dataMode != null) 'dataMode': dataMode,
    if (sampling != null) 'sampling': JsonValue.clone(sampling),
    'durationsMicros': {
      'configResolve': configResolveDuration.inMicroseconds,
      'chartBuild': chartBuildDuration.inMicroseconds,
      'totalBuild': totalBuildDuration.inMicroseconds,
    },
    'performancePolicyResolution': performancePolicyResolution.toJson(),
    'performanceSummary': performanceSummary.toJson(),
    'processingCache': processingCacheStats.toJson(),
    if (renderCacheStats != null) 'renderCaches': renderCacheStats!.toJson(),
    if (pictureCacheStats != null) 'pictureCache': pictureCacheStats!.toJson(),
  };
}

enum ChartRuntimePerformanceSeverity { healthy, info, warning }

enum ChartRuntimePerformanceRecommendation {
  none,
  enableSampling,
  enableProcessingCache,
  reviewProcessingCacheBudget,
  reviewPictureCacheBudget,
  improveRenderCacheReuse,
}

/// Actionable runtime roll-up for JSON/config-driven chart rendering.
class ChartRuntimePerformanceSummary {
  static const int largeDatasetPointThreshold =
      ChartRuntimePerformancePolicy.defaultLargeDatasetPointThreshold;
  static const double cachePressureWarningThreshold =
      ChartRuntimePerformancePolicy.defaultCachePressureWarningThreshold;
  static const double lowRenderCacheHitRateThreshold =
      ChartRuntimePerformancePolicy.defaultLowRenderCacheHitRateThreshold;
  static const int lowRenderCacheMinRequests =
      ChartRuntimePerformancePolicy.defaultLowRenderCacheMinRequests;

  final int sourceDataPointCount;
  final int? effectiveDataPointCount;
  final int? sampleInputPointCount;
  final int renderedDataPointCount;
  final int seriesCount;
  final bool configSampledData;
  final bool payloadWasNormalized;
  final bool payloadChanged;
  final bool largeUnsampled;
  final double renderedOutputRatio;
  final double renderedReductionRatio;
  final double? samplingOutputRatio;
  final double? samplingReductionRatio;
  final double processingCacheHitRate;
  final double extractionCacheHitRate;
  final double? processingCacheMemoryPressure;
  final double? renderCacheHitRate;
  final int? renderCacheRequests;
  final double? pictureCacheMemoryPressure;
  final ChartRuntimePerformanceSeverity severity;
  final ChartRuntimePerformanceRecommendation recommendation;
  final ChartRuntimePerformancePolicy policy;

  const ChartRuntimePerformanceSummary({
    required this.sourceDataPointCount,
    this.effectiveDataPointCount,
    this.sampleInputPointCount,
    required this.renderedDataPointCount,
    required this.seriesCount,
    required this.configSampledData,
    required this.payloadWasNormalized,
    required this.payloadChanged,
    required this.largeUnsampled,
    required this.renderedOutputRatio,
    required this.renderedReductionRatio,
    this.samplingOutputRatio,
    this.samplingReductionRatio,
    required this.processingCacheHitRate,
    required this.extractionCacheHitRate,
    required this.processingCacheMemoryPressure,
    required this.renderCacheHitRate,
    required this.renderCacheRequests,
    required this.pictureCacheMemoryPressure,
    required this.severity,
    required this.recommendation,
    this.policy = ChartRuntimePerformancePolicy.defaults,
  });

  factory ChartRuntimePerformanceSummary.fromRuntimeInputs({
    required int sourceDataPointCount,
    int? effectiveDataPointCount,
    int? sampleInputPointCount,
    required int renderedDataPointCount,
    required int seriesCount,
    required bool configSampledData,
    required bool payloadWasNormalized,
    required bool payloadChanged,
    required ChartDataProcessingCacheStats processingCacheStats,
    ChartRenderCacheStats? renderCacheStats,
    PictureCacheStats? pictureCacheStats,
    ChartRuntimePerformancePolicy policy =
        ChartRuntimePerformancePolicy.defaults,
  }) {
    final renderedOutputRatio = _safeRatio(
      renderedDataPointCount,
      sourceDataPointCount,
    );
    final renderedReductionRatio = sourceDataPointCount <= 0
        ? 0.0
        : (1 - renderedOutputRatio).clamp(0.0, 1.0).toDouble();
    final samplingOutputRatio = sampleInputPointCount == null
        ? null
        : _safeRatio(renderedDataPointCount, sampleInputPointCount);
    final samplingReductionRatio = sampleInputPointCount == null
        ? null
        : (1 - samplingOutputRatio!).clamp(0.0, 1.0).toDouble();
    final largeUnsampled =
        sourceDataPointCount >= policy.normalizedLargeDatasetPointThreshold &&
        !configSampledData;
    final processingCacheMemoryPressure = _safeRatioOrNull(
      processingCacheStats.currentBytes,
      processingCacheStats.maxBytes,
    );
    final pictureCacheMemoryPressure = pictureCacheStats == null
        ? null
        : _safeRatioOrNull(
            pictureCacheStats.currentMemoryBytes,
            pictureCacheStats.maxMemoryBytes,
          );
    final renderCacheHitRate = renderCacheStats == null
        ? null
        : _renderCacheHitRate(renderCacheStats);
    final renderCacheRequests = renderCacheStats == null
        ? null
        : _renderCacheRequests(renderCacheStats);
    final recommendation = _runtimePerformanceRecommendation(
      sourceDataPointCount: sourceDataPointCount,
      largeUnsampled: largeUnsampled,
      processingCacheStats: processingCacheStats,
      processingCacheMemoryPressure: processingCacheMemoryPressure,
      pictureCacheMemoryPressure: pictureCacheMemoryPressure,
      renderCacheHitRate: renderCacheHitRate,
      renderCacheRequests: renderCacheRequests,
      policy: policy,
    );
    final severity = _runtimePerformanceSeverity(
      recommendation,
      payloadChanged: payloadChanged,
    );

    return ChartRuntimePerformanceSummary(
      sourceDataPointCount: sourceDataPointCount,
      effectiveDataPointCount: effectiveDataPointCount,
      sampleInputPointCount: sampleInputPointCount,
      renderedDataPointCount: renderedDataPointCount,
      seriesCount: seriesCount,
      configSampledData: configSampledData,
      payloadWasNormalized: payloadWasNormalized,
      payloadChanged: payloadChanged,
      largeUnsampled: largeUnsampled,
      renderedOutputRatio: renderedOutputRatio,
      renderedReductionRatio: renderedReductionRatio,
      samplingOutputRatio: samplingOutputRatio,
      samplingReductionRatio: samplingReductionRatio,
      processingCacheHitRate: processingCacheStats.hitRate,
      extractionCacheHitRate: processingCacheStats.extractionHitRate,
      processingCacheMemoryPressure: processingCacheMemoryPressure,
      renderCacheHitRate: renderCacheHitRate,
      renderCacheRequests: renderCacheRequests,
      pictureCacheMemoryPressure: pictureCacheMemoryPressure,
      severity: severity,
      recommendation: recommendation,
      policy: policy,
    );
  }

  bool get hasRecommendation =>
      recommendation != ChartRuntimePerformanceRecommendation.none;

  bool get requiresAction =>
      severity == ChartRuntimePerformanceSeverity.warning;

  String get recommendationHint => _runtimePerformanceRecommendationHint(this);

  Map<String, dynamic> toJson() => {
    'severity': severity.name,
    'recommendation': recommendation.name,
    'hasRecommendation': hasRecommendation,
    'requiresAction': requiresAction,
    'recommendationHint': recommendationHint,
    'sourceDataPointCount': sourceDataPointCount,
    if (effectiveDataPointCount != null)
      'effectiveDataPointCount': effectiveDataPointCount,
    if (sampleInputPointCount != null)
      'sampleInputPointCount': sampleInputPointCount,
    'renderedDataPointCount': renderedDataPointCount,
    'seriesCount': seriesCount,
    'configSampledData': configSampledData,
    'payloadWasNormalized': payloadWasNormalized,
    'payloadChanged': payloadChanged,
    'largeUnsampled': largeUnsampled,
    'renderedOutputRatio': renderedOutputRatio,
    'renderedReductionRatio': renderedReductionRatio,
    if (samplingOutputRatio != null) 'samplingOutputRatio': samplingOutputRatio,
    if (samplingReductionRatio != null)
      'samplingReductionRatio': samplingReductionRatio,
    'processingCacheHitRate': processingCacheHitRate,
    'extractionCacheHitRate': extractionCacheHitRate,
    if (processingCacheMemoryPressure != null)
      'processingCacheMemoryPressure': processingCacheMemoryPressure,
    if (renderCacheHitRate != null) 'renderCacheHitRate': renderCacheHitRate,
    if (renderCacheRequests != null) 'renderCacheRequests': renderCacheRequests,
    if (pictureCacheMemoryPressure != null)
      'pictureCacheMemoryPressure': pictureCacheMemoryPressure,
    'policy': policy.toJson(),
  };
}

ChartRuntimePerformanceRecommendation _runtimePerformanceRecommendation({
  required int sourceDataPointCount,
  required bool largeUnsampled,
  required ChartDataProcessingCacheStats processingCacheStats,
  required double? processingCacheMemoryPressure,
  required double? pictureCacheMemoryPressure,
  required double? renderCacheHitRate,
  required int? renderCacheRequests,
  required ChartRuntimePerformancePolicy policy,
}) {
  if (largeUnsampled) {
    return ChartRuntimePerformanceRecommendation.enableSampling;
  }
  if (!processingCacheStats.enabled &&
      sourceDataPointCount >= processingCacheStats.minPointCount &&
      sourceDataPointCount > 0) {
    return ChartRuntimePerformanceRecommendation.enableProcessingCache;
  }
  if (processingCacheMemoryPressure != null &&
      processingCacheMemoryPressure >=
          policy.normalizedCachePressureWarningThreshold) {
    return ChartRuntimePerformanceRecommendation.reviewProcessingCacheBudget;
  }
  if (pictureCacheMemoryPressure != null &&
      pictureCacheMemoryPressure >=
          policy.normalizedCachePressureWarningThreshold) {
    return ChartRuntimePerformanceRecommendation.reviewPictureCacheBudget;
  }
  if (renderCacheRequests != null &&
      renderCacheHitRate != null &&
      renderCacheRequests >= policy.normalizedLowRenderCacheMinRequests &&
      renderCacheHitRate < policy.normalizedLowRenderCacheHitRateThreshold) {
    return ChartRuntimePerformanceRecommendation.improveRenderCacheReuse;
  }
  return ChartRuntimePerformanceRecommendation.none;
}

String _runtimePerformanceRecommendationHint(
  ChartRuntimePerformanceSummary summary,
) {
  switch (summary.recommendation) {
    case ChartRuntimePerformanceRecommendation.enableSampling:
      return 'Source data has ${summary.sourceDataPointCount} points and is at or above the large-data threshold (${summary.policy.normalizedLargeDatasetPointThreshold}); enable dataMode large/auto with sampling for smoother rendering.';
    case ChartRuntimePerformanceRecommendation.enableProcessingCache:
      return 'Processing cache is disabled for a reusable data size; enable ChartDataProcessor.configureProcessingCache(enabled: true) when this chart rerenders often.';
    case ChartRuntimePerformanceRecommendation.reviewProcessingCacheBudget:
      return 'Processing cache memory pressure is ${_ratioLabel(summary.processingCacheMemoryPressure)}; increase the cache budget or reduce cached output size.';
    case ChartRuntimePerformanceRecommendation.reviewPictureCacheBudget:
      return 'Picture cache memory pressure is ${_ratioLabel(summary.pictureCacheMemoryPressure)}; increase the picture cache budget or reduce retained chart layers.';
    case ChartRuntimePerformanceRecommendation.improveRenderCacheReuse:
      return 'Render cache hit rate is ${_ratioLabel(summary.renderCacheHitRate)} across ${summary.renderCacheRequests ?? 0} requests; keep style, label, and path inputs stable across frames.';
    case ChartRuntimePerformanceRecommendation.none:
      if (summary.payloadChanged) {
        return 'Payload normalization changed the input before rendering; inspect normalization diagnostics if output differs from the raw payload.';
      }
      return 'Runtime metrics are within the configured performance policy.';
  }
}

ChartRuntimePerformanceSeverity _runtimePerformanceSeverity(
  ChartRuntimePerformanceRecommendation recommendation, {
  required bool payloadChanged,
}) {
  switch (recommendation) {
    case ChartRuntimePerformanceRecommendation.enableSampling:
    case ChartRuntimePerformanceRecommendation.enableProcessingCache:
    case ChartRuntimePerformanceRecommendation.reviewProcessingCacheBudget:
    case ChartRuntimePerformanceRecommendation.reviewPictureCacheBudget:
      return ChartRuntimePerformanceSeverity.warning;
    case ChartRuntimePerformanceRecommendation.improveRenderCacheReuse:
      return ChartRuntimePerformanceSeverity.info;
    case ChartRuntimePerformanceRecommendation.none:
      return payloadChanged
          ? ChartRuntimePerformanceSeverity.info
          : ChartRuntimePerformanceSeverity.healthy;
  }
}

double _safeRatio(int numerator, int denominator) {
  if (denominator <= 0) return 0;
  return (numerator / denominator).clamp(0.0, 1.0).toDouble();
}

double? _safeRatioOrNull(int numerator, int denominator) {
  if (denominator <= 0) return null;
  return _safeRatio(numerator, denominator);
}

double _normalizedUnitRatio(double value) {
  if (!value.isFinite) return 1;
  return value.clamp(0.0, 1.0).toDouble();
}

_RuntimePolicyMatch? _runtimePerformancePolicyMatch(Object? json) {
  if (json is! Map) return null;
  final map = Map<Object?, Object?>.from(json);

  if (ChartRuntimePerformancePolicyFields.containsAny(map)) {
    return _RuntimePolicyMatch(map);
  }

  final runtimePerformancePolicy = _nestedPolicyMap(
    map['runtimePerformancePolicy'],
  );
  if (runtimePerformancePolicy != null) {
    return _RuntimePolicyMatch(
      runtimePerformancePolicy,
      'runtimePerformancePolicy',
    );
  }

  final performancePolicy = _nestedPolicyMap(map['performancePolicy']);
  if (performancePolicy != null) {
    return _RuntimePolicyMatch(performancePolicy, 'performancePolicy');
  }

  final diagnostics = _nestedPolicyMap(map['diagnostics']);
  final diagnosticsMatch = _runtimePerformancePolicyEnvelopeMatch(
    diagnostics,
    'diagnostics',
  );
  if (diagnosticsMatch != null) return diagnosticsMatch;

  final runtimeDiagnostics = _nestedPolicyMap(map['runtimeDiagnostics']);
  return _runtimePerformancePolicyEnvelopeMatch(
    runtimeDiagnostics,
    'runtimeDiagnostics',
  );
}

_RuntimePolicyMatch? _runtimePerformancePolicyEnvelopeMatch(
  Map<Object?, Object?>? map,
  String path,
) {
  if (map == null) return null;

  final performancePolicy = _nestedPolicyMap(map['performancePolicy']);
  if (performancePolicy != null) {
    return _RuntimePolicyMatch(performancePolicy, '$path.performancePolicy');
  }

  final runtimePerformancePolicy = _nestedPolicyMap(
    map['runtimePerformancePolicy'],
  );
  if (runtimePerformancePolicy != null) {
    return _RuntimePolicyMatch(
      runtimePerformancePolicy,
      '$path.runtimePerformancePolicy',
    );
  }

  return ChartRuntimePerformancePolicyFields.containsAny(map)
      ? _RuntimePolicyMatch(map, path)
      : null;
}

Map<Object?, Object?>? _nestedPolicyMap(Object? value) {
  return value is Map ? Map<Object?, Object?>.from(value) : null;
}

class _RuntimePolicyMatch {
  final Map<Object?, Object?> map;
  final String? path;

  const _RuntimePolicyMatch(this.map, [this.path]);
}

String _ratioLabel(double? ratio) {
  if (ratio == null) return 'unknown';
  return '${(ratio * 100).toStringAsFixed(1)}%';
}

int _renderCacheRequests(ChartRenderCacheStats stats) {
  return stats.colors.requests +
      stats.paints.requests +
      stats.textPainters.requests +
      stats.paths.requests;
}

double _renderCacheHitRate(ChartRenderCacheStats stats) {
  final requests = _renderCacheRequests(stats);
  if (requests == 0) return 0;
  final hits =
      stats.colors.hits +
      stats.paints.hits +
      stats.textPainters.hits +
      stats.paths.hits;
  return hits / requests;
}
