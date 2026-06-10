// Pre-processes chart series data once so painters receive ready-to-use stats.
//
// Design goals:
// - Compute **once** at config construction, not during paint().
// - Support large datasets via [DataSampler] / [DoubleListSampler] integration.
// - Avoid heap waste: uses [DoubleListSampler] directly on [List<double>]
//   so data is never re-boxed back into dynamic for sampling.
// - Provide typed results for every common chart calculation.
// - Async entry-point [processAsync] offloads heavy work to an isolate.

import 'dart:collection';
import 'dart:math' as math;
import 'chart_data_value_reader.dart';
import 'chart_data_signature.dart';
import 'chart_type.dart';
import 'data_sampler.dart';
import 'series.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Pre-computed statistics for a single numeric series.
class SeriesStats {
  final double min;
  final double max;
  final double sum;
  final double avg;
  final int count;

  /// Cleaned values — no NaN / null. This is the **full** list (pre-sampling)
  /// so statistical helpers (percentiles etc.) have complete data.
  final List<double> values;

  const SeriesStats({
    required this.min,
    required this.max,
    required this.sum,
    required this.avg,
    required this.count,
    required this.values,
  });

  static const SeriesStats empty = SeriesStats(
    min: 0,
    max: 0,
    sum: 0,
    avg: 0,
    count: 0,
    values: [],
  );

  // ---------- Statistical helpers ----------

  /// Value at [p]-th percentile (0–100). Uses linear interpolation.
  double percentile(double p) {
    final sorted = _finiteValuesCopy()..sort();
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first;
    final normalizedP = _normalizePercentile(p);
    final pos = (normalizedP / 100) * (sorted.length - 1);
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) return sorted[lo];
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
  }

  double get q1 => percentile(25);
  double get median => percentile(50);
  double get q3 => percentile(75);
  double get iqr => q3 - q1;

  /// Standard deviation (population).
  double get stdDev {
    final finiteValues = _finiteValuesCopy();
    if (finiteValues.length < 2) return 0;
    final mean = finiteValues.reduce((a, b) => a + b) / finiteValues.length;
    double variance = 0;
    for (final v in finiteValues) {
      final diff = v - mean;
      variance += diff * diff;
    }
    final result = math.sqrt(variance / finiteValues.length);
    return result.isFinite ? result : 0;
  }

  List<double> _finiteValuesCopy() {
    for (var i = 0; i < values.length; i++) {
      if (values[i].isFinite) continue;
      final output = <double>[for (var j = 0; j < i; j++) values[j]];
      for (var j = i + 1; j < values.length; j++) {
        final value = values[j];
        if (value.isFinite) output.add(value);
      }
      return output;
    }
    return List<double>.of(values);
  }

  static double _normalizePercentile(double p) {
    if (p.isNaN) return 50;
    if (p == double.infinity) return 100;
    if (p == double.negativeInfinity) return 0;
    return p.clamp(0.0, 100.0);
  }
}

/// Pre-computed stats across all series in a chart.
class ChartStats {
  final double globalMin;
  final double globalMax;
  final double globalSum;
  final List<SeriesStats> perSeries;

  const ChartStats({
    required this.globalMin,
    required this.globalMax,
    required this.globalSum,
    required this.perSeries,
  });

  static const ChartStats empty = ChartStats(
    globalMin: 0,
    globalMax: 100,
    globalSum: 0,
    perSeries: [],
  );
}

/// Sampled version of a series ready for rendering.
class ProcessedSeries {
  /// Original series metadata.
  final Series series;

  /// Sampled (or full) data points — x = original source index.
  final List<DataPoint> points;

  /// Sampled raw doubles — avoids re-extraction from points.
  final List<double> sampledValues;

  /// Source indices for sampled values. This preserves viewport/source
  /// positions after downsampling.
  final List<int> sourceIndices;

  /// Pre-computed stats (on full dataset, before sampling).
  final SeriesStats stats;

  /// Whether this series was downsampled.
  bool get wasDownsampled => sampledValues.length < stats.count;

  const ProcessedSeries({
    required this.series,
    required this.points,
    required this.sampledValues,
    required this.stats,
    this.sourceIndices = const [],
  });
}

typedef ChartProcessingResult = ({
  ChartStats stats,
  List<ProcessedSeries> processed,
});

typedef ChartProcessingResultWithReport = ({
  ChartProcessingResult result,
  ChartDataProcessingReport report,
});

/// Global memoization policy for [ChartDataProcessor].
///
/// The cache is intentionally disabled for small datasets by default. For
/// large or zoomed charts, it avoids re-extracting, re-computing stats, and
/// re-sampling equivalent series across rebuilds.
class ChartDataProcessingCacheConfig {
  static bool enabled = true;
  static int maxEntries = 32;
  static int maxBytes = 32 * 1024 * 1024;
  static int minPointCount = 1000;
  static bool extractionCacheEnabled = true;
  static int maxExtractionEntries = 128;
  static int maxExtractionBytes = 32 * 1024 * 1024;
  static int minExtractionPointCount = 1000;
}

/// Immutable cache-policy values captured for a single processing run.
class ChartDataProcessingCachePolicySnapshot {
  final bool enabled;
  final int maxEntries;
  final int maxBytes;
  final int minPointCount;
  final bool extractionCacheEnabled;
  final int maxExtractionEntries;
  final int maxExtractionBytes;
  final int minExtractionPointCount;

  const ChartDataProcessingCachePolicySnapshot({
    this.enabled = true,
    this.maxEntries = 32,
    this.maxBytes = 32 * 1024 * 1024,
    this.minPointCount = 1000,
    this.extractionCacheEnabled = true,
    this.maxExtractionEntries = 128,
    this.maxExtractionBytes = 32 * 1024 * 1024,
    this.minExtractionPointCount = 1000,
  });

  factory ChartDataProcessingCachePolicySnapshot.fromCurrentConfig() =>
      ChartDataProcessingCachePolicySnapshot(
        enabled: ChartDataProcessingCacheConfig.enabled,
        maxEntries: ChartDataProcessingCacheConfig.maxEntries,
        maxBytes: ChartDataProcessingCacheConfig.maxBytes,
        minPointCount: ChartDataProcessingCacheConfig.minPointCount,
        extractionCacheEnabled:
            ChartDataProcessingCacheConfig.extractionCacheEnabled,
        maxExtractionEntries:
            ChartDataProcessingCacheConfig.maxExtractionEntries,
        maxExtractionBytes: ChartDataProcessingCacheConfig.maxExtractionBytes,
        minExtractionPointCount:
            ChartDataProcessingCacheConfig.minExtractionPointCount,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'maxEntries': maxEntries,
    'maxBytes': maxBytes,
    'minPointCount': minPointCount,
    'extraction': {
      'enabled': extractionCacheEnabled,
      'maxEntries': maxExtractionEntries,
      'maxBytes': maxExtractionBytes,
      'minPointCount': minExtractionPointCount,
    },
  };
}

/// Runtime diagnostics for the chart data processing cache.
class ChartDataProcessingCacheStats {
  final bool enabled;
  final int size;
  final int maxEntries;
  final int currentBytes;
  final int maxBytes;
  final int largestEntryBytes;
  final int minPointCount;
  final int hits;
  final int misses;
  final int writes;
  final int evictions;
  final int evictedBytes;
  final int skippedWrites;
  final bool extractionCacheEnabled;
  final int extractionSize;
  final int maxExtractionEntries;
  final int extractionCurrentBytes;
  final int maxExtractionBytes;
  final int extractionLargestEntryBytes;
  final int minExtractionPointCount;
  final int extractionHits;
  final int extractionMisses;
  final int extractionWrites;
  final int extractionEvictions;
  final int extractionEvictedBytes;
  final int extractionSkippedWrites;

  const ChartDataProcessingCacheStats({
    required this.enabled,
    required this.size,
    required this.maxEntries,
    required this.minPointCount,
    required this.hits,
    required this.misses,
    required this.writes,
    required this.evictions,
    this.currentBytes = 0,
    this.maxBytes = 0,
    this.largestEntryBytes = 0,
    this.evictedBytes = 0,
    this.skippedWrites = 0,
    this.extractionCacheEnabled = false,
    this.extractionSize = 0,
    this.maxExtractionEntries = 0,
    this.extractionCurrentBytes = 0,
    this.maxExtractionBytes = 0,
    this.extractionLargestEntryBytes = 0,
    this.minExtractionPointCount = 0,
    this.extractionHits = 0,
    this.extractionMisses = 0,
    this.extractionWrites = 0,
    this.extractionEvictions = 0,
    this.extractionEvictedBytes = 0,
    this.extractionSkippedWrites = 0,
  });

  int get lookups => hits + misses;

  double get hitRate => lookups == 0 ? 0 : hits / lookups;

  int get extractionLookups => extractionHits + extractionMisses;

  double get extractionHitRate =>
      extractionLookups == 0 ? 0 : extractionHits / extractionLookups;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'size': size,
    'maxEntries': maxEntries,
    'currentBytes': currentBytes,
    'maxBytes': maxBytes,
    'largestEntryBytes': largestEntryBytes,
    'minPointCount': minPointCount,
    'hits': hits,
    'misses': misses,
    'writes': writes,
    'evictions': evictions,
    'evictedBytes': evictedBytes,
    'skippedWrites': skippedWrites,
    'lookups': lookups,
    'hitRate': hitRate,
    'extraction': {
      'enabled': extractionCacheEnabled,
      'size': extractionSize,
      'maxEntries': maxExtractionEntries,
      'currentBytes': extractionCurrentBytes,
      'maxBytes': maxExtractionBytes,
      'largestEntryBytes': extractionLargestEntryBytes,
      'minPointCount': minExtractionPointCount,
      'hits': extractionHits,
      'misses': extractionMisses,
      'writes': extractionWrites,
      'evictions': extractionEvictions,
      'evictedBytes': extractionEvictedBytes,
      'skippedWrites': extractionSkippedWrites,
      'lookups': extractionLookups,
      'hitRate': extractionHitRate,
    },
  };
}

enum ChartDataProcessingPath { direct, cacheHit, cacheMiss }

/// Strategy actually used by the sampler after `auto`, thresholds, and
/// visible-window sizes are resolved.
enum ChartResolvedSamplingStrategy { none, edge, lttb, minMax, nth, mixed }

/// Explains why a cache path was admitted or skipped for a processing run.
enum ChartDataCacheAdmissionReason {
  eligible,
  forcedOn,
  forcedOff,
  disabled,
  noEntryCapacity,
  noByteCapacity,
  emptyEffectiveWindow,
  belowEffectivePointThreshold,
  extractionDisabled,
  noExtractionEntryCapacity,
  noExtractionByteCapacity,
  belowExtractionPointThreshold,
}

enum ChartDataCacheWriteReason {
  written,
  admissionRejected,
  entryExceedsByteCapacity,
}

class ChartDataProcessingCacheWriteReport {
  final bool written;
  final ChartDataCacheWriteReason reason;
  final ChartDataCacheAdmissionReason admissionReason;
  final int estimatedBytes;
  final int maxBytes;

  const ChartDataProcessingCacheWriteReport({
    required this.written,
    required this.reason,
    required this.admissionReason,
    this.estimatedBytes = 0,
    this.maxBytes = 0,
  });

  Map<String, dynamic> toJson() => {
    'written': written,
    'reason': reason.name,
    'admissionReason': admissionReason.name,
    'estimatedBytes': estimatedBytes,
    'maxBytes': maxBytes,
  };
}

/// Structured remediation action for cache admission diagnostics.
enum ChartDataCacheRecommendedAction {
  none,
  reviewCacheOverride,
  enableCache,
  enableExtractionCache,
  increaseResultCacheEntries,
  increaseResultCacheBytes,
  lowerResultCachePointThreshold,
  increaseExtractionCacheEntries,
  increaseExtractionCacheBytes,
  lowerExtractionCachePointThreshold,
}

/// Rankable severity for cache recommendation dashboards.
enum ChartDataCacheRecommendationSeverity { healthy, info, warning }

/// Per-run processing diagnostics for performance dashboards and tests.
class ChartDataProcessingReport {
  final ChartDataProcessingPath path;
  final int seriesCount;
  final int dataPointCount;
  final int effectiveDataPointCount;
  final int sampleInputPointCount;
  final int outputPointCount;
  final int renderThreshold;
  final SamplingStrategy? samplingStrategy;
  final ChartResolvedSamplingStrategy resolvedSamplingStrategy;
  final List<ChartResolvedSamplingStrategy> resolvedSamplingStrategies;
  final int? startIndex;
  final int? endIndex;
  final bool cacheEligible;
  final bool extractionCacheEligible;
  final ChartDataCacheAdmissionReason cacheAdmissionReason;
  final ChartDataCacheAdmissionReason extractionCacheAdmissionReason;
  final ChartDataProcessingCachePolicySnapshot cachePolicy;
  final bool cacheHit;
  final String? dataSignature;
  final Duration totalDuration;
  final Duration extractionDuration;
  final Duration windowDuration;
  final Duration statsDuration;
  final Duration samplingDuration;
  final Duration pointBuildDuration;

  const ChartDataProcessingReport({
    required this.path,
    required this.seriesCount,
    required this.dataPointCount,
    this.effectiveDataPointCount = 0,
    this.sampleInputPointCount = 0,
    required this.outputPointCount,
    required this.renderThreshold,
    required this.samplingStrategy,
    this.resolvedSamplingStrategy = ChartResolvedSamplingStrategy.none,
    this.resolvedSamplingStrategies = const [],
    required this.startIndex,
    required this.endIndex,
    required this.cacheEligible,
    this.extractionCacheEligible = false,
    this.cacheAdmissionReason =
        ChartDataCacheAdmissionReason.belowEffectivePointThreshold,
    this.extractionCacheAdmissionReason =
        ChartDataCacheAdmissionReason.belowExtractionPointThreshold,
    this.cachePolicy = const ChartDataProcessingCachePolicySnapshot(),
    required this.cacheHit,
    required this.totalDuration,
    required this.extractionDuration,
    required this.windowDuration,
    required this.statsDuration,
    required this.samplingDuration,
    required this.pointBuildDuration,
    this.dataSignature,
  });

  bool get wasDownsampled => reducedPointCount > 0;

  bool get isViewportReduced =>
      dataPointCount > 0 && effectiveDataPointCount < dataPointCount;

  double get effectiveDataPointRatio {
    if (dataPointCount <= 0) return 0;
    return (effectiveDataPointCount / dataPointCount).clamp(0, 1).toDouble();
  }

  double get viewportReductionRatio {
    if (dataPointCount <= 0) return 0;
    return (1 - effectiveDataPointRatio).clamp(0, 1).toDouble();
  }

  int get reducedPointCount =>
      math.max(0, sampleInputPointCount - outputPointCount);

  double get samplingOutputRatio {
    if (sampleInputPointCount <= 0) return 0;
    return (outputPointCount / sampleInputPointCount).clamp(0, 1).toDouble();
  }

  double get samplingReductionRatio {
    if (sampleInputPointCount <= 0) return 0;
    return (reducedPointCount / sampleInputPointCount).clamp(0, 1).toDouble();
  }

  String get cacheAdmissionHint => _cacheAdmissionHint(
    cacheAdmissionReason,
    pointCount: effectiveDataPointCount,
    threshold: cachePolicy.minPointCount,
  );

  ChartDataCacheRecommendedAction get cacheRecommendedAction =>
      _cacheRecommendedAction(cacheAdmissionReason);

  ChartDataCacheRecommendationSeverity get cacheRecommendationSeverity =>
      _cacheRecommendationSeverity(cacheAdmissionReason);

  String get extractionCacheAdmissionHint => _cacheAdmissionHint(
    extractionCacheAdmissionReason,
    pointCount: dataPointCount,
    threshold: cachePolicy.minExtractionPointCount,
  );

  ChartDataCacheRecommendedAction get extractionCacheRecommendedAction =>
      _cacheRecommendedAction(extractionCacheAdmissionReason);

  ChartDataCacheRecommendationSeverity
  get extractionCacheRecommendationSeverity =>
      _cacheRecommendationSeverity(extractionCacheAdmissionReason);

  ChartPerformanceSummary get performanceSummary =>
      ChartPerformanceSummary.fromProcessingReport(this);

  Map<String, dynamic> toJson() => {
    'path': path.name,
    'seriesCount': seriesCount,
    'dataPointCount': dataPointCount,
    'effectiveDataPointCount': effectiveDataPointCount,
    'sampleInputPointCount': sampleInputPointCount,
    'isViewportReduced': isViewportReduced,
    'effectiveDataPointRatio': effectiveDataPointRatio,
    'viewportReductionRatio': viewportReductionRatio,
    'outputPointCount': outputPointCount,
    'wasDownsampled': wasDownsampled,
    'reducedPointCount': reducedPointCount,
    'samplingOutputRatio': samplingOutputRatio,
    'samplingReductionRatio': samplingReductionRatio,
    'renderThreshold': renderThreshold,
    'samplingStrategy': samplingStrategy?.name ?? 'auto',
    'resolvedSamplingStrategy': resolvedSamplingStrategy.name,
    'resolvedSamplingStrategies': [
      for (final strategy in resolvedSamplingStrategies) strategy.name,
    ],
    'startIndex': startIndex,
    'endIndex': endIndex,
    'cacheEligible': cacheEligible,
    'extractionCacheEligible': extractionCacheEligible,
    'cacheAdmissionReason': cacheAdmissionReason.name,
    'extractionCacheAdmissionReason': extractionCacheAdmissionReason.name,
    'cacheAdmissionHint': cacheAdmissionHint,
    'extractionCacheAdmissionHint': extractionCacheAdmissionHint,
    'cacheRecommendedAction': cacheRecommendedAction.name,
    'extractionCacheRecommendedAction': extractionCacheRecommendedAction.name,
    'cacheRecommendationSeverity': cacheRecommendationSeverity.name,
    'extractionCacheRecommendationSeverity':
        extractionCacheRecommendationSeverity.name,
    'cachePolicy': cachePolicy.toJson(),
    'cacheHit': cacheHit,
    if (dataSignature != null) 'dataSignature': dataSignature,
    'performanceSummary': performanceSummary.toJson(),
    'durationsMicros': {
      'total': totalDuration.inMicroseconds,
      'extraction': extractionDuration.inMicroseconds,
      'window': windowDuration.inMicroseconds,
      'stats': statsDuration.inMicroseconds,
      'sampling': samplingDuration.inMicroseconds,
      'pointBuild': pointBuildDuration.inMicroseconds,
    },
  };
}

/// Compact roll-up of one processing pass for dashboards and logs.
class ChartPerformanceSummary {
  final ChartDataProcessingPath path;
  final int seriesCount;
  final int dataPointCount;
  final int effectiveDataPointCount;
  final int sampleInputPointCount;
  final int outputPointCount;
  final int renderThreshold;
  final SamplingStrategy? samplingStrategy;
  final ChartResolvedSamplingStrategy resolvedSamplingStrategy;
  final List<ChartResolvedSamplingStrategy> resolvedSamplingStrategies;
  final bool wasDownsampled;
  final int reducedPointCount;
  final double samplingOutputRatio;
  final double samplingReductionRatio;
  final bool cacheHit;
  final bool cacheEligible;
  final bool extractionCacheEligible;
  final ChartDataCacheRecommendedAction cacheRecommendedAction;
  final ChartDataCacheRecommendedAction extractionCacheRecommendedAction;
  final ChartDataCacheRecommendationSeverity cacheRecommendationSeverity;
  final ChartDataCacheRecommendationSeverity
  extractionCacheRecommendationSeverity;
  final ChartDataCacheRecommendationSeverity overallCacheSeverity;
  final Duration processingDuration;
  final Duration extractionDuration;
  final Duration windowDuration;
  final Duration statsDuration;
  final Duration samplingDuration;
  final Duration pointBuildDuration;
  final bool? usedIsolate;
  final bool? isolateEligible;
  final int? isolatePointThreshold;
  final Duration? endToEndDuration;

  const ChartPerformanceSummary({
    required this.path,
    required this.seriesCount,
    required this.dataPointCount,
    required this.effectiveDataPointCount,
    required this.sampleInputPointCount,
    required this.outputPointCount,
    required this.renderThreshold,
    required this.samplingStrategy,
    required this.resolvedSamplingStrategy,
    required this.resolvedSamplingStrategies,
    required this.wasDownsampled,
    required this.reducedPointCount,
    required this.samplingOutputRatio,
    required this.samplingReductionRatio,
    required this.cacheHit,
    required this.cacheEligible,
    required this.extractionCacheEligible,
    required this.cacheRecommendedAction,
    required this.extractionCacheRecommendedAction,
    required this.cacheRecommendationSeverity,
    required this.extractionCacheRecommendationSeverity,
    required this.overallCacheSeverity,
    required this.processingDuration,
    required this.extractionDuration,
    required this.windowDuration,
    required this.statsDuration,
    required this.samplingDuration,
    required this.pointBuildDuration,
    this.usedIsolate,
    this.isolateEligible,
    this.isolatePointThreshold,
    this.endToEndDuration,
  });

  factory ChartPerformanceSummary.fromProcessingReport(
    ChartDataProcessingReport report, {
    bool? usedIsolate,
    bool? isolateEligible,
    int? isolatePointThreshold,
    Duration? endToEndDuration,
  }) {
    final cacheSeverity = report.cacheRecommendationSeverity;
    final extractionSeverity = report.extractionCacheRecommendationSeverity;

    return ChartPerformanceSummary(
      path: report.path,
      seriesCount: report.seriesCount,
      dataPointCount: report.dataPointCount,
      effectiveDataPointCount: report.effectiveDataPointCount,
      sampleInputPointCount: report.sampleInputPointCount,
      outputPointCount: report.outputPointCount,
      renderThreshold: report.renderThreshold,
      samplingStrategy: report.samplingStrategy,
      resolvedSamplingStrategy: report.resolvedSamplingStrategy,
      resolvedSamplingStrategies: report.resolvedSamplingStrategies,
      wasDownsampled: report.wasDownsampled,
      reducedPointCount: report.reducedPointCount,
      samplingOutputRatio: report.samplingOutputRatio,
      samplingReductionRatio: report.samplingReductionRatio,
      cacheHit: report.cacheHit,
      cacheEligible: report.cacheEligible,
      extractionCacheEligible: report.extractionCacheEligible,
      cacheRecommendedAction: report.cacheRecommendedAction,
      extractionCacheRecommendedAction: report.extractionCacheRecommendedAction,
      cacheRecommendationSeverity: cacheSeverity,
      extractionCacheRecommendationSeverity: extractionSeverity,
      overallCacheSeverity: _maxCacheSeverity(
        cacheSeverity,
        extractionSeverity,
      ),
      processingDuration: report.totalDuration,
      extractionDuration: report.extractionDuration,
      windowDuration: report.windowDuration,
      statsDuration: report.statsDuration,
      samplingDuration: report.samplingDuration,
      pointBuildDuration: report.pointBuildDuration,
      usedIsolate: usedIsolate,
      isolateEligible: isolateEligible,
      isolatePointThreshold: isolatePointThreshold,
      endToEndDuration: endToEndDuration,
    );
  }

  bool get isViewportReduced =>
      dataPointCount > 0 && effectiveDataPointCount < dataPointCount;

  double get effectiveDataPointRatio {
    if (dataPointCount <= 0) return 0;
    return (effectiveDataPointCount / dataPointCount).clamp(0, 1).toDouble();
  }

  double get viewportReductionRatio {
    if (dataPointCount <= 0) return 0;
    return (1 - effectiveDataPointRatio).clamp(0, 1).toDouble();
  }

  Map<String, dynamic> toJson() => {
    'path': path.name,
    'seriesCount': seriesCount,
    'dataPointCount': dataPointCount,
    'effectiveDataPointCount': effectiveDataPointCount,
    'sampleInputPointCount': sampleInputPointCount,
    'isViewportReduced': isViewportReduced,
    'effectiveDataPointRatio': effectiveDataPointRatio,
    'viewportReductionRatio': viewportReductionRatio,
    'outputPointCount': outputPointCount,
    'renderThreshold': renderThreshold,
    'samplingStrategy': samplingStrategy?.name ?? 'auto',
    'resolvedSamplingStrategy': resolvedSamplingStrategy.name,
    'resolvedSamplingStrategies': [
      for (final strategy in resolvedSamplingStrategies) strategy.name,
    ],
    'wasDownsampled': wasDownsampled,
    'reducedPointCount': reducedPointCount,
    'samplingOutputRatio': samplingOutputRatio,
    'samplingReductionRatio': samplingReductionRatio,
    'cacheHit': cacheHit,
    'cacheEligible': cacheEligible,
    'extractionCacheEligible': extractionCacheEligible,
    'cacheRecommendedAction': cacheRecommendedAction.name,
    'extractionCacheRecommendedAction': extractionCacheRecommendedAction.name,
    'cacheRecommendationSeverity': cacheRecommendationSeverity.name,
    'extractionCacheRecommendationSeverity':
        extractionCacheRecommendationSeverity.name,
    'overallCacheSeverity': overallCacheSeverity.name,
    if (usedIsolate != null) 'usedIsolate': usedIsolate,
    if (isolateEligible != null) 'isolateEligible': isolateEligible,
    if (isolatePointThreshold != null)
      'isolatePointThreshold': isolatePointThreshold,
    'durationsMicros': {
      if (endToEndDuration != null)
        'endToEnd': endToEndDuration!.inMicroseconds,
      'processing': processingDuration.inMicroseconds,
      'extraction': extractionDuration.inMicroseconds,
      'window': windowDuration.inMicroseconds,
      'stats': statsDuration.inMicroseconds,
      'sampling': samplingDuration.inMicroseconds,
      'pointBuild': pointBuildDuration.inMicroseconds,
    },
  };
}

ChartDataCacheRecommendationSeverity _maxCacheSeverity(
  ChartDataCacheRecommendationSeverity a,
  ChartDataCacheRecommendationSeverity b,
) {
  if (a.index >= b.index) return a;
  return b;
}

({
  ChartResolvedSamplingStrategy aggregate,
  List<ChartResolvedSamplingStrategy> perSeries,
})
_resolvedSamplingDiagnostics(
  List<ProcessedSeries> processed, {
  required int renderThreshold,
  required SamplingStrategy? requestedStrategy,
}) {
  if (processed.isEmpty) {
    return (
      aggregate: ChartResolvedSamplingStrategy.none,
      perSeries: const <ChartResolvedSamplingStrategy>[],
    );
  }

  final perSeries = _immutableList([
    for (final item in processed)
      _resolveSamplingStrategyForCount(
        item.stats.count,
        renderThreshold: renderThreshold,
        requestedStrategy: requestedStrategy,
      ),
  ]);
  return (
    aggregate: _aggregateResolvedSamplingStrategy(perSeries),
    perSeries: perSeries,
  );
}

ChartResolvedSamplingStrategy _resolveSamplingStrategyForCount(
  int count, {
  required int renderThreshold,
  required SamplingStrategy? requestedStrategy,
}) {
  if (count <= 0 || count <= renderThreshold) {
    return ChartResolvedSamplingStrategy.none;
  }
  if (renderThreshold <= 2) {
    return ChartResolvedSamplingStrategy.edge;
  }
  final strategy = DoubleListSampler.resolveStrategyForLength(
    count,
    forceStrategy: requestedStrategy,
  );
  switch (strategy) {
    case SamplingStrategy.lttb:
      return ChartResolvedSamplingStrategy.lttb;
    case SamplingStrategy.minMax:
      return ChartResolvedSamplingStrategy.minMax;
    case SamplingStrategy.nth:
      return ChartResolvedSamplingStrategy.nth;
  }
}

ChartResolvedSamplingStrategy _aggregateResolvedSamplingStrategy(
  List<ChartResolvedSamplingStrategy> strategies,
) {
  if (strategies.isEmpty) return ChartResolvedSamplingStrategy.none;
  final first = strategies.first;
  for (var i = 1; i < strategies.length; i++) {
    if (strategies[i] != first) return ChartResolvedSamplingStrategy.mixed;
  }
  return first;
}

String _cacheAdmissionHint(
  ChartDataCacheAdmissionReason reason, {
  required int pointCount,
  required int threshold,
}) {
  switch (reason) {
    case ChartDataCacheAdmissionReason.eligible:
      return 'Cache is eligible for this run.';
    case ChartDataCacheAdmissionReason.forcedOn:
      return 'Caching was forced on for this call; omit useCache to return to automatic admission.';
    case ChartDataCacheAdmissionReason.forcedOff:
      return 'Caching was forced off for this call; omit useCache or set it to true to allow reuse.';
    case ChartDataCacheAdmissionReason.disabled:
      return 'Enable configureProcessingCache(enabled: true) to allow cache reuse.';
    case ChartDataCacheAdmissionReason.noEntryCapacity:
      return 'Increase maxEntries above 0 to allow result cache writes.';
    case ChartDataCacheAdmissionReason.noByteCapacity:
      return 'Increase maxBytes above 0 or reduce cached output size.';
    case ChartDataCacheAdmissionReason.emptyEffectiveWindow:
      return 'No effective points are visible in this viewport; cache work is skipped until the viewport contains data.';
    case ChartDataCacheAdmissionReason.belowEffectivePointThreshold:
      return 'Effective points ($pointCount) are below minPointCount ($threshold); lower minPointCount or keep direct processing for this viewport.';
    case ChartDataCacheAdmissionReason.extractionDisabled:
      return 'Enable extractionCacheEnabled to reuse extracted raw series.';
    case ChartDataCacheAdmissionReason.noExtractionEntryCapacity:
      return 'Increase maxExtractionEntries above 0 to allow extracted-series cache writes.';
    case ChartDataCacheAdmissionReason.noExtractionByteCapacity:
      return 'Increase maxExtractionBytes above 0 or reduce source series size.';
    case ChartDataCacheAdmissionReason.belowExtractionPointThreshold:
      return 'Raw points ($pointCount) are below minExtractionPointCount ($threshold); lower minExtractionPointCount or skip extraction caching for small data.';
  }
}

ChartDataCacheRecommendedAction _cacheRecommendedAction(
  ChartDataCacheAdmissionReason reason,
) {
  switch (reason) {
    case ChartDataCacheAdmissionReason.eligible:
      return ChartDataCacheRecommendedAction.none;
    case ChartDataCacheAdmissionReason.forcedOn:
    case ChartDataCacheAdmissionReason.forcedOff:
      return ChartDataCacheRecommendedAction.reviewCacheOverride;
    case ChartDataCacheAdmissionReason.disabled:
      return ChartDataCacheRecommendedAction.enableCache;
    case ChartDataCacheAdmissionReason.noEntryCapacity:
      return ChartDataCacheRecommendedAction.increaseResultCacheEntries;
    case ChartDataCacheAdmissionReason.noByteCapacity:
      return ChartDataCacheRecommendedAction.increaseResultCacheBytes;
    case ChartDataCacheAdmissionReason.emptyEffectiveWindow:
      return ChartDataCacheRecommendedAction.none;
    case ChartDataCacheAdmissionReason.belowEffectivePointThreshold:
      return ChartDataCacheRecommendedAction.lowerResultCachePointThreshold;
    case ChartDataCacheAdmissionReason.extractionDisabled:
      return ChartDataCacheRecommendedAction.enableExtractionCache;
    case ChartDataCacheAdmissionReason.noExtractionEntryCapacity:
      return ChartDataCacheRecommendedAction.increaseExtractionCacheEntries;
    case ChartDataCacheAdmissionReason.noExtractionByteCapacity:
      return ChartDataCacheRecommendedAction.increaseExtractionCacheBytes;
    case ChartDataCacheAdmissionReason.belowExtractionPointThreshold:
      return ChartDataCacheRecommendedAction.lowerExtractionCachePointThreshold;
  }
}

ChartDataCacheRecommendationSeverity _cacheRecommendationSeverity(
  ChartDataCacheAdmissionReason reason,
) {
  switch (reason) {
    case ChartDataCacheAdmissionReason.eligible:
      return ChartDataCacheRecommendationSeverity.healthy;
    case ChartDataCacheAdmissionReason.forcedOn:
    case ChartDataCacheAdmissionReason.forcedOff:
    case ChartDataCacheAdmissionReason.emptyEffectiveWindow:
    case ChartDataCacheAdmissionReason.belowEffectivePointThreshold:
    case ChartDataCacheAdmissionReason.belowExtractionPointThreshold:
      return ChartDataCacheRecommendationSeverity.info;
    case ChartDataCacheAdmissionReason.disabled:
    case ChartDataCacheAdmissionReason.noEntryCapacity:
    case ChartDataCacheAdmissionReason.noByteCapacity:
    case ChartDataCacheAdmissionReason.extractionDisabled:
    case ChartDataCacheAdmissionReason.noExtractionEntryCapacity:
    case ChartDataCacheAdmissionReason.noExtractionByteCapacity:
      return ChartDataCacheRecommendationSeverity.warning;
  }
}

class _ChartDataProcessingCache {
  final Map<String, _CachedProcessingResult> _entries = {};
  int currentBytes = 0;
  int hits = 0;
  int misses = 0;
  int writes = 0;
  int evictions = 0;
  int evictedBytes = 0;
  int skippedWrites = 0;

  _CachedProcessingResult? get(String key) {
    final entry = _entries.remove(key);
    if (entry == null) {
      misses++;
      return null;
    }
    _entries[key] = entry;
    hits++;
    return entry;
  }

  bool put(
    String key,
    ChartProcessingResult result, {
    required int maxEntries,
    required int maxBytes,
  }) => putEntry(
    key,
    _CachedProcessingResult.from(result),
    maxEntries: maxEntries,
    maxBytes: maxBytes,
  );

  bool putEntry(
    String key,
    _CachedProcessingResult entry, {
    required int maxEntries,
    required int maxBytes,
  }) {
    if (maxEntries <= 0 || maxBytes <= 0) return false;
    final previous = _entries.remove(key);
    if (previous != null) {
      currentBytes -= previous.estimatedBytes;
    }

    if (entry.estimatedBytes > maxBytes) {
      skippedWrites++;
      return false;
    }

    _entries[key] = entry;
    currentBytes += entry.estimatedBytes;
    writes++;
    pruneTo(maxEntries: maxEntries, maxBytes: maxBytes);
    return true;
  }

  void pruneTo({required int maxEntries, required int maxBytes}) {
    while (_entries.isNotEmpty &&
        (_entries.length > maxEntries || currentBytes > maxBytes)) {
      final entry = _entries.remove(_entries.keys.first);
      if (entry != null) {
        currentBytes -= entry.estimatedBytes;
        evictedBytes += entry.estimatedBytes;
        evictions++;
      }
    }
  }

  void clear({bool resetMetrics = true}) {
    _entries.clear();
    currentBytes = 0;
    if (resetMetrics) {
      hits = 0;
      misses = 0;
      writes = 0;
      evictions = 0;
      evictedBytes = 0;
      skippedWrites = 0;
    }
  }

  int get largestEntryBytes {
    var largest = 0;
    for (final entry in _entries.values) {
      if (entry.estimatedBytes > largest) largest = entry.estimatedBytes;
    }
    return largest;
  }

  ChartDataProcessingCacheStats stats({
    required bool enabled,
    required int maxEntries,
    required int maxBytes,
    required int minPointCount,
    required _ExtractedSeriesCache extractedCache,
    required bool extractionCacheEnabled,
    required int maxExtractionEntries,
    required int maxExtractionBytes,
    required int minExtractionPointCount,
  }) {
    return ChartDataProcessingCacheStats(
      enabled: enabled,
      size: _entries.length,
      maxEntries: maxEntries,
      currentBytes: currentBytes,
      maxBytes: maxBytes,
      largestEntryBytes: largestEntryBytes,
      minPointCount: minPointCount,
      hits: hits,
      misses: misses,
      writes: writes,
      evictions: evictions,
      evictedBytes: evictedBytes,
      skippedWrites: skippedWrites,
      extractionCacheEnabled: extractionCacheEnabled,
      extractionSize: extractedCache.size,
      maxExtractionEntries: maxExtractionEntries,
      extractionCurrentBytes: extractedCache.currentBytes,
      maxExtractionBytes: maxExtractionBytes,
      extractionLargestEntryBytes: extractedCache.largestEntryBytes,
      minExtractionPointCount: minExtractionPointCount,
      extractionHits: extractedCache.hits,
      extractionMisses: extractedCache.misses,
      extractionWrites: extractedCache.writes,
      extractionEvictions: extractedCache.evictions,
      extractionEvictedBytes: extractedCache.evictedBytes,
      extractionSkippedWrites: extractedCache.skippedWrites,
    );
  }
}

class _ExtractedSeriesCache {
  final Map<String, _CachedExtractedSeriesData> _entries = {};
  int currentBytes = 0;
  int hits = 0;
  int misses = 0;
  int writes = 0;
  int evictions = 0;
  int evictedBytes = 0;
  int skippedWrites = 0;

  int get size => _entries.length;

  _ExtractedSeriesData? get(String key) {
    final entry = _entries.remove(key);
    if (entry == null) {
      misses++;
      return null;
    }
    _entries[key] = entry;
    hits++;
    return entry.data;
  }

  void put(
    String key,
    _ExtractedSeriesData data, {
    required int maxEntries,
    required int maxBytes,
  }) {
    if (maxEntries <= 0 || maxBytes <= 0) return;
    final previous = _entries.remove(key);
    if (previous != null) {
      currentBytes -= previous.estimatedBytes;
    }

    final entry = _CachedExtractedSeriesData.from(data);
    if (entry.estimatedBytes > maxBytes) {
      skippedWrites++;
      return;
    }

    _entries[key] = entry;
    currentBytes += entry.estimatedBytes;
    writes++;
    pruneTo(maxEntries: maxEntries, maxBytes: maxBytes);
  }

  void pruneTo({required int maxEntries, required int maxBytes}) {
    while (_entries.isNotEmpty &&
        (_entries.length > maxEntries || currentBytes > maxBytes)) {
      _evict(_entries.keys.first);
    }
  }

  void pruneMinSourceLength(int minSourceLength) {
    final keysToRemove = <String>[];
    for (final entry in _entries.entries) {
      if (entry.value.data.sourceLength < minSourceLength) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _evict(key);
    }
  }

  void _evict(String key) {
    final entry = _entries.remove(key);
    if (entry != null) {
      currentBytes -= entry.estimatedBytes;
      evictedBytes += entry.estimatedBytes;
      evictions++;
    }
  }

  void clear({bool resetMetrics = true}) {
    _entries.clear();
    currentBytes = 0;
    if (resetMetrics) {
      hits = 0;
      misses = 0;
      writes = 0;
      evictions = 0;
      evictedBytes = 0;
      skippedWrites = 0;
    }
  }

  int get largestEntryBytes {
    var largest = 0;
    for (final entry in _entries.values) {
      if (entry.estimatedBytes > largest) largest = entry.estimatedBytes;
    }
    return largest;
  }
}

class _CachedExtractedSeriesData {
  final _ExtractedSeriesData data;
  final int estimatedBytes;

  const _CachedExtractedSeriesData({
    required this.data,
    required this.estimatedBytes,
  });

  factory _CachedExtractedSeriesData.from(_ExtractedSeriesData data) {
    final values = List<double>.unmodifiable(data.values);
    final sourceIndices = List<int>.unmodifiable(data.sourceIndices);
    return _CachedExtractedSeriesData(
      data: _ExtractedSeriesData(
        values: values,
        sourceIndices: sourceIndices,
        sourceLength: data.sourceLength,
        shared: true,
      ),
      estimatedBytes:
          _fixedCacheObjectOverhead +
          _doubleEstimatedBytes * values.length +
          _intEstimatedBytes * sourceIndices.length,
    );
  }
}

class _CachedProcessingResult {
  final ChartStats stats;
  final List<_CachedProcessedSeries> processed;
  final int estimatedBytes;

  const _CachedProcessingResult({
    required this.stats,
    required this.processed,
    required this.estimatedBytes,
  });

  factory _CachedProcessingResult.from(ChartProcessingResult result) {
    final processed = List<_CachedProcessedSeries>.unmodifiable([
      for (final item in result.processed) _CachedProcessedSeries.from(item),
    ]);
    return _CachedProcessingResult(
      stats: ChartStats(
        globalMin: result.stats.globalMin,
        globalMax: result.stats.globalMax,
        globalSum: result.stats.globalSum,
        perSeries: List<SeriesStats>.unmodifiable([
          for (final item in processed) item.stats,
        ]),
      ),
      processed: processed,
      estimatedBytes:
          _chartStatsEstimatedBytes(result.stats) +
          processed.fold<int>(0, (total, item) => total + item.estimatedBytes),
    );
  }

  ChartProcessingResult rehydrate(List<Series> series) {
    return (
      stats: stats,
      processed: _immutableList([
        for (var i = 0; i < processed.length; i++)
          ProcessedSeries(
            series: i < series.length ? series[i] : processed[i].series,
            points: processed[i].points,
            sampledValues: processed[i].sampledValues,
            sourceIndices: processed[i].sourceIndices,
            stats: processed[i].stats,
          ),
      ]),
    );
  }
}

class _CachedProcessedSeries {
  final Series series;
  final List<DataPoint> points;
  final List<double> sampledValues;
  final List<int> sourceIndices;
  final SeriesStats stats;
  final int estimatedBytes;

  const _CachedProcessedSeries({
    required this.series,
    required this.points,
    required this.sampledValues,
    required this.sourceIndices,
    required this.stats,
    required this.estimatedBytes,
  });

  factory _CachedProcessedSeries.from(ProcessedSeries series) {
    final points = List<DataPoint>.unmodifiable(series.points);
    final sampledValues = List<double>.unmodifiable(series.sampledValues);
    final sourceIndices = List<int>.unmodifiable(
      series.sourceIndices.isEmpty
          ? series.points.map((point) => point.x.round())
          : series.sourceIndices,
    );
    final statsValues = List<double>.unmodifiable(series.stats.values);
    return _CachedProcessedSeries(
      series: series.series,
      points: points,
      sampledValues: sampledValues,
      sourceIndices: sourceIndices,
      stats: SeriesStats(
        min: series.stats.min,
        max: series.stats.max,
        sum: series.stats.sum,
        avg: series.stats.avg,
        count: series.stats.count,
        values: statsValues,
      ),
      estimatedBytes:
          _fixedCacheObjectOverhead +
          _dataPointEstimatedBytes * points.length +
          _doubleEstimatedBytes * sampledValues.length +
          _intEstimatedBytes * sourceIndices.length +
          _seriesStatsEstimatedBytes(statsValues.length),
    );
  }
}

const int _doubleEstimatedBytes = 8;
const int _intEstimatedBytes = 8;
const int _dataPointEstimatedBytes = 32;
const int _fixedCacheObjectOverhead = 96;

int _seriesStatsEstimatedBytes(int valueCount) {
  return _fixedCacheObjectOverhead + _doubleEstimatedBytes * valueCount;
}

int _chartStatsEstimatedBytes(ChartStats stats) {
  return _fixedCacheObjectOverhead +
      _fixedCacheObjectOverhead * stats.perSeries.length;
}

enum _TimingBucket { extraction, window, stats, sampling, pointBuild }

class _ProcessingDurations {
  Duration extraction = Duration.zero;
  Duration window = Duration.zero;
  Duration stats = Duration.zero;
  Duration sampling = Duration.zero;
  Duration pointBuild = Duration.zero;

  void add(_TimingBucket bucket, Duration elapsed) {
    switch (bucket) {
      case _TimingBucket.extraction:
        extraction += elapsed;
      case _TimingBucket.window:
        window += elapsed;
      case _TimingBucket.stats:
        stats += elapsed;
      case _TimingBucket.sampling:
        sampling += elapsed;
      case _TimingBucket.pointBuild:
        pointBuild += elapsed;
    }
  }
}

T _measure<T>(
  _ProcessingDurations? timings,
  _TimingBucket bucket,
  T Function() body,
) {
  if (timings == null) return body();
  final stopwatch = Stopwatch()..start();
  try {
    return body();
  } finally {
    stopwatch.stop();
    timings.add(bucket, stopwatch.elapsed);
  }
}

List<T> _immutableList<T>(List<T> values) => UnmodifiableListView<T>(values);

class _ProcessingCacheIdentity {
  final String resultKey;
  final String seriesSignature;

  const _ProcessingCacheIdentity({
    required this.resultKey,
    required this.seriesSignature,
  });
}

// ---------------------------------------------------------------------------
// ChartDataProcessor
// ---------------------------------------------------------------------------

class ChartDataProcessor {
  /// Default render threshold — above this the dataset is sampled.
  static const int defaultRenderThreshold = 500;

  static final _ChartDataProcessingCache _processingCache =
      _ChartDataProcessingCache();
  static final _ExtractedSeriesCache _extractedSeriesCache =
      _ExtractedSeriesCache();

  /// Current data-processing cache diagnostics.
  static ChartDataProcessingCacheStats get processingCacheStats =>
      _processingCache.stats(
        enabled: ChartDataProcessingCacheConfig.enabled,
        maxEntries: ChartDataProcessingCacheConfig.maxEntries,
        maxBytes: ChartDataProcessingCacheConfig.maxBytes,
        minPointCount: ChartDataProcessingCacheConfig.minPointCount,
        extractedCache: _extractedSeriesCache,
        extractionCacheEnabled:
            ChartDataProcessingCacheConfig.extractionCacheEnabled,
        maxExtractionEntries:
            ChartDataProcessingCacheConfig.maxExtractionEntries,
        maxExtractionBytes: ChartDataProcessingCacheConfig.maxExtractionBytes,
        minExtractionPointCount:
            ChartDataProcessingCacheConfig.minExtractionPointCount,
      );

  /// Tune processing cache behavior at runtime.
  static void configureProcessingCache({
    bool? enabled,
    int? maxEntries,
    int? maxBytes,
    int? minPointCount,
    bool? extractionCacheEnabled,
    int? maxExtractionEntries,
    int? maxExtractionBytes,
    int? minExtractionPointCount,
  }) {
    if (enabled != null) {
      ChartDataProcessingCacheConfig.enabled = enabled;
    }
    if (maxEntries != null) {
      ChartDataProcessingCacheConfig.maxEntries = math.max(0, maxEntries);
      _processingCache.pruneTo(
        maxEntries: ChartDataProcessingCacheConfig.maxEntries,
        maxBytes: ChartDataProcessingCacheConfig.maxBytes,
      );
    }
    if (maxBytes != null) {
      ChartDataProcessingCacheConfig.maxBytes = math.max(0, maxBytes);
      _processingCache.pruneTo(
        maxEntries: ChartDataProcessingCacheConfig.maxEntries,
        maxBytes: ChartDataProcessingCacheConfig.maxBytes,
      );
    }
    if (minPointCount != null) {
      ChartDataProcessingCacheConfig.minPointCount = math.max(0, minPointCount);
    }
    if (extractionCacheEnabled != null) {
      ChartDataProcessingCacheConfig.extractionCacheEnabled =
          extractionCacheEnabled;
      if (!extractionCacheEnabled) {
        _extractedSeriesCache.clear(resetMetrics: false);
      }
    }
    if (maxExtractionEntries != null) {
      ChartDataProcessingCacheConfig.maxExtractionEntries = math.max(
        0,
        maxExtractionEntries,
      );
      _extractedSeriesCache.pruneTo(
        maxEntries: ChartDataProcessingCacheConfig.maxExtractionEntries,
        maxBytes: ChartDataProcessingCacheConfig.maxExtractionBytes,
      );
    }
    if (maxExtractionBytes != null) {
      ChartDataProcessingCacheConfig.maxExtractionBytes = math.max(
        0,
        maxExtractionBytes,
      );
      _extractedSeriesCache.pruneTo(
        maxEntries: ChartDataProcessingCacheConfig.maxExtractionEntries,
        maxBytes: ChartDataProcessingCacheConfig.maxExtractionBytes,
      );
    }
    if (minExtractionPointCount != null) {
      ChartDataProcessingCacheConfig.minExtractionPointCount = math.max(
        0,
        minExtractionPointCount,
      );
      _extractedSeriesCache.pruneMinSourceLength(
        ChartDataProcessingCacheConfig.minExtractionPointCount,
      );
    }
  }

  /// Clears memoized processing and extracted-series results.
  static void clearProcessingCache({bool resetMetrics = true}) {
    _processingCache.clear(resetMetrics: resetMetrics);
    _extractedSeriesCache.clear(resetMetrics: resetMetrics);
  }

  // ---------------------------------------------------------------------------
  // Main synchronous entry-point
  // ---------------------------------------------------------------------------

  /// Process all series in a chart, returning [ChartStats] and per-series
  /// [ProcessedSeries] list.
  ///
  /// **Performance fix**: previously this called `_extractDoubles` then
  /// `DataSampler.fromRaw(raw.cast<dynamic>())` which re-boxed the already
  /// extracted doubles back to `dynamic`. Now we use [DoubleListSampler]
  /// directly on `List<double>` and only build [DataPoint] objects once,
  /// for the sampled subset.
  ///
  /// [renderThreshold]: max points to send to the painter per series.
  static ChartProcessingResult process(
    List<Series> series, {
    int renderThreshold = defaultRenderThreshold,
    SamplingStrategy? samplingStrategy,
    // Optional viewport culling — only process indices in [startIndex..endIndex].
    int? startIndex,
    int? endIndex,
    // `null` means auto: cache only when the dataset is large enough.
    bool? useCache,
    // Optional precomputed content hash from [ChartDataSignature].
    String? dataSignature,
    void Function(ChartDataProcessingReport report)? onReport,
  }) {
    final effectiveRenderThreshold = _normalizeRenderThreshold(renderThreshold);
    final cachePolicy =
        ChartDataProcessingCachePolicySnapshot.fromCurrentConfig();
    final effectiveWindow = _normalizeWindow(
      series,
      startIndex: startIndex,
      endIndex: endIndex,
    );
    final cacheAdmissionReason = processingCacheAdmissionReason(
      series,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      useCache: useCache,
      policy: cachePolicy,
    );
    final cacheEligible = _isCacheAdmissionEligible(cacheAdmissionReason);

    if (onReport != null) {
      final output = processWithReport(
        series,
        renderThreshold: effectiveRenderThreshold,
        samplingStrategy: samplingStrategy,
        startIndex: effectiveWindow.startIndex,
        endIndex: effectiveWindow.endIndex,
        useCache: useCache,
        dataSignature: dataSignature,
      );
      onReport(output.report);
      return output.result;
    }

    if (series.isEmpty) {
      return (stats: ChartStats.empty, processed: const []);
    }

    if (cacheEligible) {
      final identity = _processingCacheIdentity(
        series,
        renderThreshold: effectiveRenderThreshold,
        samplingStrategy: samplingStrategy,
        startIndex: effectiveWindow.startIndex,
        endIndex: effectiveWindow.endIndex,
        dataSignature: dataSignature,
      );
      final cached = _processingCache.get(identity.resultKey);
      if (cached != null) {
        return cached.rehydrate(series);
      }
      final result = _processUncached(
        series,
        renderThreshold: effectiveRenderThreshold,
        samplingStrategy: samplingStrategy,
        startIndex: effectiveWindow.startIndex,
        endIndex: effectiveWindow.endIndex,
        extractionSignature: identity.seriesSignature,
        useExtractionCache: true,
      );
      _processingCache.put(
        identity.resultKey,
        result,
        maxEntries: ChartDataProcessingCacheConfig.maxEntries,
        maxBytes: ChartDataProcessingCacheConfig.maxBytes,
      );
      return result;
    }

    final extractionCacheEligible = shouldUseExtractionCache(
      series,
      useCache: useCache,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      policy: cachePolicy,
    );
    return _processUncached(
      series,
      renderThreshold: effectiveRenderThreshold,
      samplingStrategy: samplingStrategy,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      extractionSignature: extractionCacheEligible
          ? _seriesDataSignature(series, dataSignature)
          : null,
      useExtractionCache: extractionCacheEligible,
    );
  }

  /// Process data and return detailed timing/cache diagnostics.
  static ChartProcessingResultWithReport processWithReport(
    List<Series> series, {
    int renderThreshold = defaultRenderThreshold,
    SamplingStrategy? samplingStrategy,
    int? startIndex,
    int? endIndex,
    bool? useCache,
    String? dataSignature,
  }) {
    final effectiveRenderThreshold = _normalizeRenderThreshold(renderThreshold);
    final cachePolicy =
        ChartDataProcessingCachePolicySnapshot.fromCurrentConfig();
    final effectiveWindow = _normalizeWindow(
      series,
      startIndex: startIndex,
      endIndex: endIndex,
    );
    final totalStopwatch = Stopwatch()..start();
    final dataPointCount = totalDataPoints(series);
    final effectivePointCount = effectiveDataPointCount(
      series,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
    );
    final cacheAdmissionReason = processingCacheAdmissionReason(
      series,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      useCache: useCache,
      policy: cachePolicy,
    );
    final cacheEligible = _isCacheAdmissionEligible(cacheAdmissionReason);
    final extractionCacheAdmissionReason = extractionCacheAdmissionReasonFor(
      series,
      useCache: useCache,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      policy: cachePolicy,
    );
    final extractionCacheEligible = _isCacheAdmissionEligible(
      extractionCacheAdmissionReason,
    );

    if (series.isEmpty) {
      totalStopwatch.stop();
      final result = (
        stats: ChartStats.empty,
        processed: const <ProcessedSeries>[],
      );
      return (
        result: result,
        report: ChartDataProcessingReport(
          path: ChartDataProcessingPath.direct,
          seriesCount: 0,
          dataPointCount: 0,
          effectiveDataPointCount: 0,
          sampleInputPointCount: 0,
          outputPointCount: 0,
          renderThreshold: effectiveRenderThreshold,
          samplingStrategy: samplingStrategy,
          startIndex: effectiveWindow.startIndex,
          endIndex: effectiveWindow.endIndex,
          cacheEligible: false,
          extractionCacheEligible: false,
          cacheAdmissionReason: cacheAdmissionReason,
          extractionCacheAdmissionReason: extractionCacheAdmissionReason,
          cachePolicy: cachePolicy,
          cacheHit: false,
          dataSignature: dataSignature,
          totalDuration: totalStopwatch.elapsed,
          extractionDuration: Duration.zero,
          windowDuration: Duration.zero,
          statsDuration: Duration.zero,
          samplingDuration: Duration.zero,
          pointBuildDuration: Duration.zero,
        ),
      );
    }

    if (cacheEligible) {
      final identity = _processingCacheIdentity(
        series,
        renderThreshold: effectiveRenderThreshold,
        samplingStrategy: samplingStrategy,
        startIndex: effectiveWindow.startIndex,
        endIndex: effectiveWindow.endIndex,
        dataSignature: dataSignature,
      );
      final cached = _processingCache.get(identity.resultKey);
      if (cached != null) {
        final result = cached.rehydrate(series);
        final samplingDiagnostics = _resolvedSamplingDiagnostics(
          result.processed,
          renderThreshold: effectiveRenderThreshold,
          requestedStrategy: samplingStrategy,
        );
        totalStopwatch.stop();
        return (
          result: result,
          report: ChartDataProcessingReport(
            path: ChartDataProcessingPath.cacheHit,
            seriesCount: series.length,
            dataPointCount: dataPointCount,
            effectiveDataPointCount: effectivePointCount,
            sampleInputPointCount: sampleInputPointCount(result.processed),
            outputPointCount: outputPointCount(result.processed),
            renderThreshold: effectiveRenderThreshold,
            samplingStrategy: samplingStrategy,
            resolvedSamplingStrategy: samplingDiagnostics.aggregate,
            resolvedSamplingStrategies: samplingDiagnostics.perSeries,
            startIndex: effectiveWindow.startIndex,
            endIndex: effectiveWindow.endIndex,
            cacheEligible: true,
            extractionCacheEligible: extractionCacheEligible,
            cacheAdmissionReason: cacheAdmissionReason,
            extractionCacheAdmissionReason: extractionCacheAdmissionReason,
            cachePolicy: cachePolicy,
            cacheHit: true,
            dataSignature: dataSignature,
            totalDuration: totalStopwatch.elapsed,
            extractionDuration: Duration.zero,
            windowDuration: Duration.zero,
            statsDuration: Duration.zero,
            samplingDuration: Duration.zero,
            pointBuildDuration: Duration.zero,
          ),
        );
      }

      final timings = _ProcessingDurations();
      final result = _processUncached(
        series,
        renderThreshold: effectiveRenderThreshold,
        samplingStrategy: samplingStrategy,
        startIndex: effectiveWindow.startIndex,
        endIndex: effectiveWindow.endIndex,
        timings: timings,
        extractionSignature: identity.seriesSignature,
        useExtractionCache: true,
      );
      _processingCache.put(
        identity.resultKey,
        result,
        maxEntries: ChartDataProcessingCacheConfig.maxEntries,
        maxBytes: ChartDataProcessingCacheConfig.maxBytes,
      );
      final samplingDiagnostics = _resolvedSamplingDiagnostics(
        result.processed,
        renderThreshold: effectiveRenderThreshold,
        requestedStrategy: samplingStrategy,
      );
      totalStopwatch.stop();
      return (
        result: result,
        report: ChartDataProcessingReport(
          path: ChartDataProcessingPath.cacheMiss,
          seriesCount: series.length,
          dataPointCount: dataPointCount,
          effectiveDataPointCount: effectivePointCount,
          sampleInputPointCount: sampleInputPointCount(result.processed),
          outputPointCount: outputPointCount(result.processed),
          renderThreshold: effectiveRenderThreshold,
          samplingStrategy: samplingStrategy,
          resolvedSamplingStrategy: samplingDiagnostics.aggregate,
          resolvedSamplingStrategies: samplingDiagnostics.perSeries,
          startIndex: effectiveWindow.startIndex,
          endIndex: effectiveWindow.endIndex,
          cacheEligible: true,
          extractionCacheEligible: extractionCacheEligible,
          cacheAdmissionReason: cacheAdmissionReason,
          extractionCacheAdmissionReason: extractionCacheAdmissionReason,
          cachePolicy: cachePolicy,
          cacheHit: false,
          dataSignature: dataSignature,
          totalDuration: totalStopwatch.elapsed,
          extractionDuration: timings.extraction,
          windowDuration: timings.window,
          statsDuration: timings.stats,
          samplingDuration: timings.sampling,
          pointBuildDuration: timings.pointBuild,
        ),
      );
    }

    final timings = _ProcessingDurations();
    final result = _processUncached(
      series,
      renderThreshold: effectiveRenderThreshold,
      samplingStrategy: samplingStrategy,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      timings: timings,
      extractionSignature: extractionCacheEligible
          ? _seriesDataSignature(series, dataSignature)
          : null,
      useExtractionCache: extractionCacheEligible,
    );
    final samplingDiagnostics = _resolvedSamplingDiagnostics(
      result.processed,
      renderThreshold: effectiveRenderThreshold,
      requestedStrategy: samplingStrategy,
    );
    totalStopwatch.stop();
    return (
      result: result,
      report: ChartDataProcessingReport(
        path: ChartDataProcessingPath.direct,
        seriesCount: series.length,
        dataPointCount: dataPointCount,
        effectiveDataPointCount: effectivePointCount,
        sampleInputPointCount: sampleInputPointCount(result.processed),
        outputPointCount: outputPointCount(result.processed),
        renderThreshold: effectiveRenderThreshold,
        samplingStrategy: samplingStrategy,
        resolvedSamplingStrategy: samplingDiagnostics.aggregate,
        resolvedSamplingStrategies: samplingDiagnostics.perSeries,
        startIndex: effectiveWindow.startIndex,
        endIndex: effectiveWindow.endIndex,
        cacheEligible: false,
        extractionCacheEligible: extractionCacheEligible,
        cacheAdmissionReason: cacheAdmissionReason,
        extractionCacheAdmissionReason: extractionCacheAdmissionReason,
        cachePolicy: cachePolicy,
        cacheHit: false,
        dataSignature: dataSignature,
        totalDuration: totalStopwatch.elapsed,
        extractionDuration: timings.extraction,
        windowDuration: timings.window,
        statsDuration: timings.stats,
        samplingDuration: timings.sampling,
        pointBuildDuration: timings.pointBuild,
      ),
    );
  }

  static ChartProcessingResult _processUncached(
    List<Series> series, {
    required int renderThreshold,
    required SamplingStrategy? samplingStrategy,
    required int? startIndex,
    required int? endIndex,
    _ProcessingDurations? timings,
    String? extractionSignature,
    bool useExtractionCache = false,
  }) {
    if (series.isEmpty) {
      return (stats: ChartStats.empty, processed: const []);
    }
    if (_hasEmptyEffectiveWindow(
      series,
      startIndex: startIndex,
      endIndex: endIndex,
    )) {
      return _emptyProcessingResult(series);
    }

    final List<ProcessedSeries> processed = [];
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;
    double globalSum = 0;

    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final s = series[seriesIndex];
      // 1. Extract clean doubles and their source indices once — O(n).
      final extracted = _measure(
        timings,
        _TimingBucket.extraction,
        () => _extractSeriesDataCached(
          s.data ?? const [],
          seriesType: s.type,
          extractionSignature: extractionSignature,
          seriesIndex: seriesIndex,
          useExtractionCache: useExtractionCache,
        ),
      );

      // 2. Optionally cull to visible viewport window.
      final windowed = _measure(
        timings,
        _TimingBucket.window,
        () => _applyWindow(extracted, startIndex, endIndex),
      );

      // 3. Compute stats on the full (windowed) data — O(n).
      final stats = _measure(
        timings,
        _TimingBucket.stats,
        () => _computeStats(windowed.values),
      );

      if (stats.min < globalMin) globalMin = stats.min;
      if (stats.max > globalMax) globalMax = stats.max;
      globalSum += stats.sum;

      // 4. If the visible data already fits the render budget, avoid
      // allocating a full [0, 1, 2, ...] index list before building points.
      final sampledData = windowed.values.length <= renderThreshold
          ? _measure(
              timings,
              _TimingBucket.pointBuild,
              () => _buildFullWindowSampledData(windowed),
            )
          : _buildDownsampledData(
              windowed,
              renderThreshold: renderThreshold,
              samplingStrategy: samplingStrategy,
              timings: timings,
            );

      processed.add(
        ProcessedSeries(
          series: s,
          points: sampledData.points,
          sampledValues: sampledData.values,
          sourceIndices: sampledData.sourceIndices,
          stats: stats,
        ),
      );
    }

    final chartStats = ChartStats(
      globalMin: globalMin.isFinite ? globalMin : 0,
      globalMax: globalMax.isFinite ? globalMax : 100,
      globalSum: globalSum,
      perSeries: _immutableList([for (final p in processed) p.stats]),
    );

    return (stats: chartStats, processed: _immutableList(processed));
  }

  static bool shouldUseProcessingCache(
    List<Series> series, {
    bool? useCache,
    int? startIndex,
    int? endIndex,
    ChartDataProcessingCachePolicySnapshot? policy,
  }) => _isCacheAdmissionEligible(
    processingCacheAdmissionReason(
      series,
      useCache: useCache,
      startIndex: startIndex,
      endIndex: endIndex,
      policy: policy,
    ),
  );

  static ChartDataCacheAdmissionReason processingCacheAdmissionReason(
    List<Series> series, {
    bool? useCache,
    int? startIndex,
    int? endIndex,
    ChartDataProcessingCachePolicySnapshot? policy,
  }) {
    final cachePolicy =
        policy ?? ChartDataProcessingCachePolicySnapshot.fromCurrentConfig();
    if (useCache != null) {
      if (!useCache) return ChartDataCacheAdmissionReason.forcedOff;
      if (cachePolicy.maxEntries <= 0) {
        return ChartDataCacheAdmissionReason.noEntryCapacity;
      }
      if (cachePolicy.maxBytes <= 0) {
        return ChartDataCacheAdmissionReason.noByteCapacity;
      }
      return ChartDataCacheAdmissionReason.forcedOn;
    }
    if (!cachePolicy.enabled) {
      return ChartDataCacheAdmissionReason.disabled;
    }
    if (cachePolicy.maxEntries <= 0) {
      return ChartDataCacheAdmissionReason.noEntryCapacity;
    }
    if (cachePolicy.maxBytes <= 0) {
      return ChartDataCacheAdmissionReason.noByteCapacity;
    }
    final effectivePointCount = effectiveDataPointCount(
      series,
      startIndex: startIndex,
      endIndex: endIndex,
    );
    if (effectivePointCount <= 0) {
      return ChartDataCacheAdmissionReason.emptyEffectiveWindow;
    }
    if (effectivePointCount < cachePolicy.minPointCount) {
      return ChartDataCacheAdmissionReason.belowEffectivePointThreshold;
    }
    return ChartDataCacheAdmissionReason.eligible;
  }

  static bool shouldUseExtractionCache(
    List<Series> series, {
    bool? useCache,
    int? startIndex,
    int? endIndex,
    ChartDataProcessingCachePolicySnapshot? policy,
  }) => _isCacheAdmissionEligible(
    extractionCacheAdmissionReasonFor(
      series,
      useCache: useCache,
      startIndex: startIndex,
      endIndex: endIndex,
      policy: policy,
    ),
  );

  static ChartDataCacheAdmissionReason extractionCacheAdmissionReasonFor(
    List<Series> series, {
    bool? useCache,
    int? startIndex,
    int? endIndex,
    ChartDataProcessingCachePolicySnapshot? policy,
  }) {
    final cachePolicy =
        policy ?? ChartDataProcessingCachePolicySnapshot.fromCurrentConfig();
    if (useCache == false) return ChartDataCacheAdmissionReason.forcedOff;
    if (effectiveDataPointCount(
          series,
          startIndex: startIndex,
          endIndex: endIndex,
        ) <=
        0) {
      return ChartDataCacheAdmissionReason.emptyEffectiveWindow;
    }
    if (useCache == null && !cachePolicy.enabled) {
      return ChartDataCacheAdmissionReason.disabled;
    }
    if (!cachePolicy.extractionCacheEnabled) {
      return ChartDataCacheAdmissionReason.extractionDisabled;
    }
    if (cachePolicy.maxExtractionEntries <= 0) {
      return ChartDataCacheAdmissionReason.noExtractionEntryCapacity;
    }
    if (cachePolicy.maxExtractionBytes <= 0) {
      return ChartDataCacheAdmissionReason.noExtractionByteCapacity;
    }
    for (final s in series) {
      if ((s.data?.length ?? 0) >= cachePolicy.minExtractionPointCount) {
        return ChartDataCacheAdmissionReason.eligible;
      }
    }
    return ChartDataCacheAdmissionReason.belowExtractionPointThreshold;
  }

  static bool _isCacheAdmissionEligible(ChartDataCacheAdmissionReason reason) =>
      reason == ChartDataCacheAdmissionReason.eligible ||
      reason == ChartDataCacheAdmissionReason.forcedOn;

  static ChartProcessingResult? readProcessingCache(
    List<Series> series, {
    int renderThreshold = defaultRenderThreshold,
    SamplingStrategy? samplingStrategy,
    int? startIndex,
    int? endIndex,
    bool? useCache,
    String? dataSignature,
  }) {
    return readProcessingCacheWithReport(
      series,
      renderThreshold: renderThreshold,
      samplingStrategy: samplingStrategy,
      startIndex: startIndex,
      endIndex: endIndex,
      useCache: useCache,
      dataSignature: dataSignature,
    )?.result;
  }

  /// Reads a cached processing result and returns a normalized cache-hit report.
  ///
  /// This is used by async/off-main-thread processing to avoid rebuilding cache
  /// diagnostics separately from the synchronous processing path.
  static ChartProcessingResultWithReport? readProcessingCacheWithReport(
    List<Series> series, {
    int renderThreshold = defaultRenderThreshold,
    SamplingStrategy? samplingStrategy,
    int? startIndex,
    int? endIndex,
    bool? useCache,
    String? dataSignature,
  }) {
    final effectiveRenderThreshold = _normalizeRenderThreshold(renderThreshold);
    final cachePolicy =
        ChartDataProcessingCachePolicySnapshot.fromCurrentConfig();
    final effectiveWindow = _normalizeWindow(
      series,
      startIndex: startIndex,
      endIndex: endIndex,
    );
    final cacheAdmissionReason = processingCacheAdmissionReason(
      series,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      useCache: useCache,
      policy: cachePolicy,
    );
    if (!_isCacheAdmissionEligible(cacheAdmissionReason)) {
      return null;
    }
    final extractionCacheAdmissionReason = extractionCacheAdmissionReasonFor(
      series,
      useCache: useCache,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      policy: cachePolicy,
    );
    final stopwatch = Stopwatch()..start();
    final identity = _processingCacheIdentity(
      series,
      renderThreshold: effectiveRenderThreshold,
      samplingStrategy: samplingStrategy,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      dataSignature: dataSignature,
    );
    final cached = _processingCache.get(identity.resultKey);
    if (cached == null) {
      stopwatch.stop();
      return null;
    }

    final result = cached.rehydrate(series);
    final samplingDiagnostics = _resolvedSamplingDiagnostics(
      result.processed,
      renderThreshold: effectiveRenderThreshold,
      requestedStrategy: samplingStrategy,
    );
    stopwatch.stop();
    return (
      result: result,
      report: ChartDataProcessingReport(
        path: ChartDataProcessingPath.cacheHit,
        seriesCount: series.length,
        dataPointCount: totalDataPoints(series),
        effectiveDataPointCount: effectiveDataPointCount(
          series,
          startIndex: effectiveWindow.startIndex,
          endIndex: effectiveWindow.endIndex,
        ),
        sampleInputPointCount: sampleInputPointCount(result.processed),
        outputPointCount: outputPointCount(result.processed),
        renderThreshold: effectiveRenderThreshold,
        samplingStrategy: samplingStrategy,
        resolvedSamplingStrategy: samplingDiagnostics.aggregate,
        resolvedSamplingStrategies: samplingDiagnostics.perSeries,
        startIndex: effectiveWindow.startIndex,
        endIndex: effectiveWindow.endIndex,
        cacheEligible: true,
        extractionCacheEligible: _isCacheAdmissionEligible(
          extractionCacheAdmissionReason,
        ),
        cacheAdmissionReason: cacheAdmissionReason,
        extractionCacheAdmissionReason: extractionCacheAdmissionReason,
        cachePolicy: cachePolicy,
        cacheHit: true,
        dataSignature: dataSignature,
        totalDuration: stopwatch.elapsed,
        extractionDuration: Duration.zero,
        windowDuration: Duration.zero,
        statsDuration: Duration.zero,
        samplingDuration: Duration.zero,
        pointBuildDuration: Duration.zero,
      ),
    );
  }

  static bool writeProcessingCache(
    List<Series> series,
    ChartProcessingResult result, {
    int renderThreshold = defaultRenderThreshold,
    SamplingStrategy? samplingStrategy,
    int? startIndex,
    int? endIndex,
    bool? useCache,
    String? dataSignature,
  }) => writeProcessingCacheWithReport(
    series,
    result,
    renderThreshold: renderThreshold,
    samplingStrategy: samplingStrategy,
    startIndex: startIndex,
    endIndex: endIndex,
    useCache: useCache,
    dataSignature: dataSignature,
  ).written;

  static ChartDataProcessingCacheWriteReport writeProcessingCacheWithReport(
    List<Series> series,
    ChartProcessingResult result, {
    int renderThreshold = defaultRenderThreshold,
    SamplingStrategy? samplingStrategy,
    int? startIndex,
    int? endIndex,
    bool? useCache,
    String? dataSignature,
  }) {
    final effectiveWindow = _normalizeWindow(
      series,
      startIndex: startIndex,
      endIndex: endIndex,
    );
    final admissionReason = processingCacheAdmissionReason(
      series,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      useCache: useCache,
    );
    if (!_isCacheAdmissionEligible(admissionReason)) {
      return ChartDataProcessingCacheWriteReport(
        written: false,
        reason: ChartDataCacheWriteReason.admissionRejected,
        admissionReason: admissionReason,
        maxBytes: ChartDataProcessingCacheConfig.maxBytes,
      );
    }
    final identity = _processingCacheIdentity(
      series,
      renderThreshold: _normalizeRenderThreshold(renderThreshold),
      samplingStrategy: samplingStrategy,
      startIndex: effectiveWindow.startIndex,
      endIndex: effectiveWindow.endIndex,
      dataSignature: dataSignature,
    );
    final entry = _CachedProcessingResult.from(result);
    final written = _processingCache.putEntry(
      identity.resultKey,
      entry,
      maxEntries: ChartDataProcessingCacheConfig.maxEntries,
      maxBytes: ChartDataProcessingCacheConfig.maxBytes,
    );
    return ChartDataProcessingCacheWriteReport(
      written: written,
      reason: written
          ? ChartDataCacheWriteReason.written
          : ChartDataCacheWriteReason.entryExceedsByteCapacity,
      admissionReason: admissionReason,
      estimatedBytes: entry.estimatedBytes,
      maxBytes: ChartDataProcessingCacheConfig.maxBytes,
    );
  }

  static String processingCacheKey(
    List<Series> series, {
    required int renderThreshold,
    required SamplingStrategy? samplingStrategy,
    required int? startIndex,
    required int? endIndex,
    required String? dataSignature,
  }) => _processingCacheIdentity(
    series,
    renderThreshold: renderThreshold,
    samplingStrategy: samplingStrategy,
    startIndex: startIndex,
    endIndex: endIndex,
    dataSignature: dataSignature,
  ).resultKey;

  static _ProcessingCacheIdentity _processingCacheIdentity(
    List<Series> series, {
    required int renderThreshold,
    required SamplingStrategy? samplingStrategy,
    required int? startIndex,
    required int? endIndex,
    required String? dataSignature,
  }) {
    final effectiveRenderThreshold = _normalizeRenderThreshold(renderThreshold);
    final effectiveWindow = _normalizeWindow(
      series,
      startIndex: startIndex,
      endIndex: endIndex,
    );
    final seriesSignature = _seriesDataSignature(series, dataSignature);
    return _ProcessingCacheIdentity(
      resultKey: stableChartDataHash({
        'processorVersion': 4,
        'series': seriesSignature,
        'seriesTypes': [for (final s in series) s.type.name],
        'renderThreshold': effectiveRenderThreshold,
        'samplingStrategy': samplingStrategy?.name ?? 'auto',
        'startIndex': effectiveWindow.startIndex,
        'endIndex': effectiveWindow.endIndex,
      }),
      seriesSignature: seriesSignature,
    );
  }

  static String _seriesDataSignature(
    List<Series> series,
    String? dataSignature,
  ) =>
      dataSignature ??
      stableChartDataHash({
        'seriesData': [for (final s in series) s.data],
      });

  static int totalDataPoints(List<Series> series) {
    var total = 0;
    for (final s in series) {
      total += s.data?.length ?? 0;
    }
    return total;
  }

  static int effectiveDataPointCount(
    List<Series> series, {
    int? startIndex,
    int? endIndex,
  }) {
    if (startIndex == null && endIndex == null) {
      return totalDataPoints(series);
    }

    var total = 0;
    for (final s in series) {
      total += _effectiveDataPointCountForLength(
        s.data?.length ?? 0,
        startIndex: startIndex,
        endIndex: endIndex,
      );
    }
    return total;
  }

  static int _effectiveDataPointCountForLength(
    int length, {
    required int? startIndex,
    required int? endIndex,
  }) {
    if (length <= 0) return 0;
    final maxIndex = length - 1;
    final start = math.max(0, math.min(startIndex ?? 0, maxIndex));
    final end = math.max(0, math.min(endIndex ?? maxIndex, maxIndex));
    return end < start ? 0 : end - start + 1;
  }

  static bool _hasEmptyEffectiveWindow(
    List<Series> series, {
    required int? startIndex,
    required int? endIndex,
  }) {
    if (startIndex == null && endIndex == null) {
      return totalDataPoints(series) == 0;
    }
    return effectiveDataPointCount(
          series,
          startIndex: startIndex,
          endIndex: endIndex,
        ) ==
        0;
  }

  static ChartProcessingResult _emptyProcessingResult(List<Series> series) {
    final perSeries = _immutableList(<SeriesStats>[
      for (var i = 0; i < series.length; i++) SeriesStats.empty,
    ]);
    return (
      stats: ChartStats(
        globalMin: 0,
        globalMax: 100,
        globalSum: 0,
        perSeries: perSeries,
      ),
      processed: _immutableList(<ProcessedSeries>[
        for (final item in series)
          ProcessedSeries(
            series: item,
            points: const <DataPoint>[],
            sampledValues: const <double>[],
            sourceIndices: const <int>[],
            stats: SeriesStats.empty,
          ),
      ]),
    );
  }

  static int outputPointCount(List<ProcessedSeries> processed) {
    var total = 0;
    for (final s in processed) {
      total += s.points.length;
    }
    return total;
  }

  static int sampleInputPointCount(List<ProcessedSeries> processed) {
    var total = 0;
    for (final s in processed) {
      total += s.stats.count;
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // Stacked series helpers
  // ---------------------------------------------------------------------------

  /// Compute cumulative (stacked) values per category index.
  ///
  /// Returns `result[seriesIdx][dataIdx]` = stacked value.
  static List<List<double>> computeStackedValues(List<Series> series) {
    if (series.isEmpty) return const [];

    int len = 0;
    for (final s in series) {
      final l = s.data?.length ?? 0;
      if (l > len) len = l;
    }

    final List<double> posAccum = List.filled(len, 0.0);
    final List<double> negAccum = List.filled(len, 0.0);
    final List<List<double>> result = [];

    for (final s in series) {
      final data = s.data;
      final row = List<double>.filled(len, 0.0);
      for (int i = 0; i < len; i++) {
        final v =
            ChartDataValueReader.yValueOrNull(
              data != null && i < data.length ? data[i] : null,
            ) ??
            0;
        if (v >= 0) {
          row[i] = posAccum[i] + v;
          posAccum[i] += v;
        } else {
          row[i] = negAccum[i] + v;
          negAccum[i] += v;
        }
      }
      result.add(row);
    }
    return result;
  }

  /// Max stacked value across all categories.
  static double maxStackedValue(List<Series> series) {
    if (series.isEmpty) return 100;
    final stacked = computeStackedValues(series);
    double max = double.negativeInfinity;
    for (final row in stacked) {
      for (final v in row) {
        if (v > max) max = v;
      }
    }
    return max.isFinite ? max : 100;
  }

  // ---------------------------------------------------------------------------
  // Normalisation helpers
  // ---------------------------------------------------------------------------

  /// Map [value] from [srcMin..srcMax] to [dstMin..dstMax].
  static double normalize(
    double value,
    double srcMin,
    double srcMax,
    double dstMin,
    double dstMax,
  ) {
    final safeDstMin = dstMin.isFinite ? dstMin : 0.0;
    final safeDstMax = dstMax.isFinite ? dstMax : safeDstMin;
    if (srcMax == srcMin) return safeDstMin;
    final fallback = (safeDstMin + safeDstMax) / 2;
    if (!value.isFinite || !srcMin.isFinite || !srcMax.isFinite) {
      return fallback.isFinite ? fallback : 0.0;
    }

    final result =
        safeDstMin +
        (value - srcMin) / (srcMax - srcMin) * (safeDstMax - safeDstMin);
    return result.isFinite ? result : fallback;
  }

  /// Generate evenly-spaced Y-axis ticks for a [min..max] range.
  ///
  /// Returns exactly [tickCount] values including min and max, rounded to
  /// a "nice" step using `log10`-based magnitude (no string tricks).
  static List<double> niceYTicks(double min, double max, {int tickCount = 5}) {
    final count = _normalizeGeneratedCount(tickCount);
    if (count <= 0) return const [];
    if (!min.isFinite || !max.isFinite) return List<double>.filled(count, 0.0);

    final lower = math.min(min, max);
    final upper = math.max(min, max);
    if (count == 1) return <double>[(lower + upper) / 2];
    if (lower == upper) return List<double>.filled(count, lower);

    final step = _niceStep((upper - lower) / (count - 1));
    if (!step.isFinite || step <= 0) return List<double>.filled(count, lower);
    final niceMin = (lower / step).floor() * step;
    return List.generate(count, (i) => niceMin + i * step);
  }

  /// Compute a "nice" round step value for axis ticks.
  ///
  /// FIX: replaced the original broken string-length magnitude heuristic
  /// with a proper log10 calculation from `dart:math`.
  static double _niceStep(double roughStep) {
    if (!roughStep.isFinite || roughStep <= 0) return 1;
    final double mag = math
        .pow(10, (math.log(roughStep) / math.ln10).floor())
        .toDouble();
    if (!mag.isFinite || mag <= 0) return 1;
    final double norm = roughStep / mag;
    final double nice;
    if (norm <= 1.0) {
      nice = 1;
    } else if (norm <= 2.0) {
      nice = 2;
    } else if (norm <= 5.0) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * mag;
  }

  // ---------------------------------------------------------------------------
  // Percentile helpers (for box-plot, violin, etc.)
  // ---------------------------------------------------------------------------

  /// Compute standard five-number summary for [values].
  static ({double min, double q1, double median, double q3, double max})
  fiveNumberSummary(List<double> values) {
    final sorted = _finiteValues(values)..sort();
    if (sorted.isEmpty) return (min: 0, q1: 0, median: 0, q3: 0, max: 0);
    return (
      min: sorted.first,
      q1: _percentileFromSorted(sorted, 25),
      median: _percentileFromSorted(sorted, 50),
      q3: _percentileFromSorted(sorted, 75),
      max: sorted.last,
    );
  }

  static double _percentileFromSorted(List<double> sorted, double p) {
    if (sorted.length == 1) return sorted.first;
    final pos = (p / 100) * (sorted.length - 1);
    final lo = pos.floor();
    final hi = pos.ceil();
    if (lo == hi) return sorted[lo];
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
  }

  // ---------------------------------------------------------------------------
  // Histogram binning
  // ---------------------------------------------------------------------------

  /// Compute histogram bins for [values] into [binCount] equal-width buckets.
  ///
  /// Returns list of (binStart, binEnd, count) records.
  static List<({double start, double end, int count})> histogram(
    List<double> values, {
    int binCount = 10,
    double? forcedMin,
    double? forcedMax,
  }) {
    final count = _normalizeGeneratedCount(binCount);
    if (count <= 0) return const [];

    final visibleValues = _finiteValues(values);
    if (visibleValues.isEmpty) return const [];

    final dataMin = visibleValues.reduce((a, b) => a < b ? a : b);
    final dataMax = visibleValues.reduce((a, b) => a > b ? a : b);
    final rawMin = forcedMin != null && forcedMin.isFinite
        ? forcedMin
        : dataMin;
    final rawMax = forcedMax != null && forcedMax.isFinite
        ? forcedMax
        : dataMax;
    double min = math.min(rawMin, rawMax);
    double max = math.max(rawMin, rawMax);
    if (min == max) {
      max = min + 1;
    }
    final double width = (max - min) / count;
    if (!width.isFinite || width <= 0) return const [];

    final counts = List<int>.filled(count, 0);
    for (final v in visibleValues) {
      int bin = ((v - min) / width).floor();
      if (bin >= count) bin = count - 1;
      if (bin < 0) bin = 0;
      counts[bin]++;
    }
    return List.generate(
      count,
      (i) => (
        start: min + i * width,
        end: min + (i + 1) * width,
        count: counts[i],
      ),
    );
  }

  static const int _maxGeneratedBucketCount = 1000;

  static int _normalizeGeneratedCount(int count) {
    if (count <= 0) return 0;
    return math.min(count, _maxGeneratedBucketCount);
  }

  static List<double> _finiteValues(List<double> values) {
    for (var i = 0; i < values.length; i++) {
      if (values[i].isFinite) continue;
      final output = <double>[for (var j = 0; j < i; j++) values[j]];
      for (var j = i + 1; j < values.length; j++) {
        final value = values[j];
        if (value.isFinite) output.add(value);
      }
      return output;
    }
    return List<double>.of(values);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static _ExtractedSeriesData _applyWindow(
    _ExtractedSeriesData data,
    int? startIndex,
    int? endIndex,
  ) {
    if (startIndex == null && endIndex == null) return data.detachedIfShared();
    if (data.values.isEmpty) return _ExtractedSeriesData.empty;
    if (data.sourceLength <= 0) return _ExtractedSeriesData.empty;
    final maxIndex = data.sourceLength - 1;
    final start = (startIndex ?? 0).clamp(0, maxIndex);
    final end = (endIndex ?? maxIndex).clamp(0, maxIndex);
    if (end < start) return _ExtractedSeriesData.empty;

    final from = _lowerBoundSourceIndex(data.sourceIndices, start);
    final to = _upperBoundSourceIndex(data.sourceIndices, end);
    if (from >= to) return _ExtractedSeriesData.empty;
    if (from == 0 && to == data.values.length) return data.detachedIfShared();

    return _ExtractedSeriesData(
      values: data.values.sublist(from, to),
      sourceIndices: data.sourceIndices.sublist(from, to),
      sourceLength: data.sourceLength,
    );
  }

  static _ExtractedSeriesData _extractSeriesDataCached(
    List<dynamic> raw, {
    required ChartType seriesType,
    required String? extractionSignature,
    required int seriesIndex,
    required bool useExtractionCache,
  }) {
    if (!_shouldUseExtractionCache(raw, useExtractionCache)) {
      return _extractSeriesData(raw, seriesType: seriesType);
    }

    final cacheKey = _extractedSeriesCacheKey(
      extractionSignature ?? stableChartDataHash({'seriesData': raw}),
      seriesIndex,
      seriesType,
    );
    final cached = _extractedSeriesCache.get(cacheKey);
    if (cached != null) return cached;

    final extracted = _extractSeriesData(raw, seriesType: seriesType);
    _extractedSeriesCache.put(
      cacheKey,
      extracted,
      maxEntries: ChartDataProcessingCacheConfig.maxExtractionEntries,
      maxBytes: ChartDataProcessingCacheConfig.maxExtractionBytes,
    );
    return extracted;
  }

  static bool _shouldUseExtractionCache(
    List<dynamic> raw,
    bool useExtractionCache,
  ) {
    if (!useExtractionCache) return false;
    if (!ChartDataProcessingCacheConfig.extractionCacheEnabled) return false;
    if (ChartDataProcessingCacheConfig.maxExtractionEntries <= 0) return false;
    if (ChartDataProcessingCacheConfig.maxExtractionBytes <= 0) return false;
    return raw.length >= ChartDataProcessingCacheConfig.minExtractionPointCount;
  }

  static String _extractedSeriesCacheKey(
    String extractionSignature,
    int seriesIndex,
    ChartType seriesType,
  ) => 'extracted:v2:$extractionSignature:$seriesIndex:${seriesType.name}';

  static int _lowerBoundSourceIndex(List<int> indices, int target) {
    var low = 0;
    var high = indices.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (indices[mid] < target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  static int _upperBoundSourceIndex(List<int> indices, int target) {
    var low = 0;
    var high = indices.length;
    while (low < high) {
      final mid = low + ((high - low) >> 1);
      if (indices[mid] <= target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  static int _normalizeRenderThreshold(int renderThreshold) =>
      math.max(2, renderThreshold);

  static ({int? startIndex, int? endIndex}) _normalizeWindow(
    List<Series> series, {
    required int? startIndex,
    required int? endIndex,
  }) {
    if (startIndex == null && endIndex == null) {
      return (startIndex: null, endIndex: null);
    }

    final length = _maxSeriesLength(series);
    if (length <= 0) {
      return (startIndex: 0, endIndex: -1);
    }

    return (
      startIndex: (startIndex ?? 0).clamp(0, length - 1),
      endIndex: (endIndex ?? length - 1).clamp(0, length - 1),
    );
  }

  static int _maxSeriesLength(List<Series> series) {
    var maxLength = 0;
    for (final s in series) {
      final length = s.data?.length ?? 0;
      if (length > maxLength) maxLength = length;
    }
    return maxLength;
  }

  static SeriesStats _computeStats(List<double> values) {
    if (values.isEmpty) return SeriesStats.empty;
    double min = values.first, max = values.first, sum = 0;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
      sum += v;
    }
    return SeriesStats(
      min: min,
      max: max,
      sum: sum,
      avg: sum / values.length,
      count: values.length,
      values: _immutableList(values),
    );
  }

  static _SampledSeriesData _buildSampledData(
    _ExtractedSeriesData data,
    List<int> localIndices,
  ) {
    if (data.values.isEmpty || localIndices.isEmpty) {
      return _SampledSeriesData.empty;
    }

    final values = List<double>.filled(localIndices.length, 0, growable: false);
    final sourceIndices = List<int>.filled(
      localIndices.length,
      0,
      growable: false,
    );
    final points = List<DataPoint>.filled(
      localIndices.length,
      const DataPoint(0, 0),
      growable: false,
    );

    for (var i = 0; i < localIndices.length; i++) {
      final localIndex = localIndices[i].clamp(0, data.values.length - 1);
      final sourceIndex = data.sourceIndices[localIndex];
      final value = data.values[localIndex];
      values[i] = value;
      sourceIndices[i] = sourceIndex;
      points[i] = DataPoint(sourceIndex.toDouble(), value);
    }

    return _SampledSeriesData(
      values: _immutableList(values),
      sourceIndices: _immutableList(sourceIndices),
      points: _immutableList(points),
    );
  }

  static _SampledSeriesData _buildDownsampledData(
    _ExtractedSeriesData data, {
    required int renderThreshold,
    required SamplingStrategy? samplingStrategy,
    required _ProcessingDurations? timings,
  }) {
    final List<int> sampledLocalIndices = _measure(
      timings,
      _TimingBucket.sampling,
      () => DoubleListSampler.autoIndices(
        data.values,
        renderThreshold,
        forceStrategy: samplingStrategy,
      ),
    );
    return _measure(
      timings,
      _TimingBucket.pointBuild,
      () => _buildSampledData(data, sampledLocalIndices),
    );
  }

  static _SampledSeriesData _buildFullWindowSampledData(
    _ExtractedSeriesData data,
  ) {
    if (data.values.isEmpty) return _SampledSeriesData.empty;

    final points = List<DataPoint>.filled(
      data.values.length,
      const DataPoint(0, 0),
      growable: false,
    );
    for (var i = 0; i < data.values.length; i++) {
      points[i] = DataPoint(data.sourceIndices[i].toDouble(), data.values[i]);
    }

    return _SampledSeriesData(
      values: _immutableList(data.values),
      sourceIndices: _immutableList(data.sourceIndices),
      points: _immutableList(points),
    );
  }

  static _ExtractedSeriesData _extractSeriesData(
    List<dynamic> raw, {
    required ChartType seriesType,
  }) {
    final values = List<double>.filled(raw.length, 0.0, growable: false);
    final indices = List<int>.filled(raw.length, 0, growable: false);
    int writeIdx = 0;
    for (var i = 0; i < raw.length; i++) {
      final v = _seriesYValue(raw[i], seriesType);
      if (v == null) continue;
      values[writeIdx] = v;
      indices[writeIdx] = i;
      writeIdx++;
    }
    if (writeIdx == 0) {
      return _ExtractedSeriesData(
        values: const [],
        sourceIndices: const [],
        sourceLength: raw.length,
      );
    }
    return _ExtractedSeriesData(
      values: writeIdx == raw.length ? values : values.sublist(0, writeIdx),
      sourceIndices: writeIdx == raw.length
          ? indices
          : indices.sublist(0, writeIdx),
      sourceLength: raw.length,
    );
  }

  static double? _seriesYValue(Object? item, ChartType seriesType) {
    switch (seriesType) {
      case ChartType.candlestick:
      case ChartType.ohlc:
        return ChartDataValueReader.ohlcCloseValueOrNull(item);
      default:
        return ChartDataValueReader.yValueOrNull(item);
    }
  }
}

class _ExtractedSeriesData {
  final List<double> values;
  final List<int> sourceIndices;
  final int sourceLength;
  final bool shared;

  const _ExtractedSeriesData({
    required this.values,
    required this.sourceIndices,
    required this.sourceLength,
    this.shared = false,
  });

  static const empty = _ExtractedSeriesData(
    values: [],
    sourceIndices: [],
    sourceLength: 0,
  );

  _ExtractedSeriesData detachedIfShared() {
    if (!shared) return this;
    return _ExtractedSeriesData(
      values: List<double>.of(values),
      sourceIndices: List<int>.of(sourceIndices),
      sourceLength: sourceLength,
    );
  }
}

class _SampledSeriesData {
  final List<double> values;
  final List<int> sourceIndices;
  final List<DataPoint> points;

  const _SampledSeriesData({
    required this.values,
    required this.sourceIndices,
    required this.points,
  });

  static const empty = _SampledSeriesData(
    values: [],
    sourceIndices: [],
    points: [],
  );
}
