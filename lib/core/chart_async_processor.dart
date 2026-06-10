import 'package:flutter/foundation.dart';
import '../core/chart_data_processor.dart';
import '../core/data_sampler.dart';
import '../core/series.dart';

/// Moves heavy chart processing (LTTB, stats, binning) off the UI thread.
///
/// The isolate decision is based on effective data-point count, not series
/// count: one visible 100k-point series should be offloaded, while 10k empty
/// series or a tiny zoom window should not.
class AsyncChartProcessor {
  static Future<ChartProcessingResult> processAsync(
    List<Series> series, {
    int renderThreshold = 500,
    SamplingStrategy? samplingStrategy,
    int? startIndex,
    int? endIndex,
    bool? useCache,
    String? dataSignature,
    bool? useIsolate,
    int? isolatePointThreshold,
    void Function(AsyncChartProcessingReport report)? onReport,
  }) async {
    final output = await processAsyncWithReport(
      series,
      renderThreshold: renderThreshold,
      samplingStrategy: samplingStrategy,
      startIndex: startIndex,
      endIndex: endIndex,
      useCache: useCache,
      dataSignature: dataSignature,
      useIsolate: useIsolate,
      isolatePointThreshold: isolatePointThreshold,
    );
    onReport?.call(output.report);
    return output.result;
  }

  static Future<AsyncChartProcessingResult> processAsyncWithReport(
    List<Series> series, {
    int renderThreshold = 500,
    SamplingStrategy? samplingStrategy,
    int? startIndex,
    int? endIndex,
    bool? useCache,
    String? dataSignature,
    bool? useIsolate,
    int? isolatePointThreshold,
  }) async {
    final totalStopwatch = Stopwatch()..start();
    final dataPointCount = ChartDataProcessor.totalDataPoints(series);
    final threshold = _normalizedIsolatePointThreshold(
      isolatePointThreshold ?? AsyncChartProcessorConfig.isolatePointThreshold,
    );
    final isolateEligible = shouldUseIsolate(
      series,
      useIsolate: useIsolate,
      startIndex: startIndex,
      endIndex: endIndex,
      isolatePointThreshold: threshold,
    );

    if (isolateEligible &&
        ChartDataProcessor.shouldUseProcessingCache(
          series,
          startIndex: startIndex,
          endIndex: endIndex,
          useCache: useCache,
        )) {
      final cached = ChartDataProcessor.readProcessingCacheWithReport(
        series,
        renderThreshold: renderThreshold,
        samplingStrategy: samplingStrategy,
        startIndex: startIndex,
        endIndex: endIndex,
        useCache: useCache,
        dataSignature: dataSignature,
      );
      if (cached != null) {
        totalStopwatch.stop();
        return (
          result: cached.result,
          report: AsyncChartProcessingReport(
            usedIsolate: false,
            isolateEligible: true,
            isolatePointThreshold: threshold,
            dataPointCount: dataPointCount,
            totalDuration: totalStopwatch.elapsed,
            processingReport: cached.report,
          ),
        );
      }
    }

    if (isolateEligible) {
      final isolateOutput = await compute(
        _isolateEntry,
        _IsolatePayload(
          series: series,
          renderThreshold: renderThreshold,
          samplingStrategy: samplingStrategy,
          startIndex: startIndex,
          endIndex: endIndex,
          dataSignature: dataSignature,
        ),
      );
      final processingCacheWriteReport =
          ChartDataProcessor.writeProcessingCacheWithReport(
            series,
            isolateOutput.result,
            renderThreshold: renderThreshold,
            samplingStrategy: samplingStrategy,
            startIndex: startIndex,
            endIndex: endIndex,
            useCache: useCache,
            dataSignature: dataSignature,
          );
      totalStopwatch.stop();
      return (
        result: isolateOutput.result,
        report: AsyncChartProcessingReport(
          usedIsolate: true,
          isolateEligible: true,
          isolatePointThreshold: threshold,
          dataPointCount: dataPointCount,
          totalDuration: totalStopwatch.elapsed,
          processingReport: isolateOutput.report,
          processingCacheWritten: processingCacheWriteReport.written,
          processingCacheWriteReason: processingCacheWriteReport.reason,
          processingCacheWriteAdmissionReason:
              processingCacheWriteReport.admissionReason,
          processingCacheWriteEstimatedBytes:
              processingCacheWriteReport.estimatedBytes,
          processingCacheWriteMaxBytes: processingCacheWriteReport.maxBytes,
        ),
      );
    }

    final direct = ChartDataProcessor.processWithReport(
      series,
      renderThreshold: renderThreshold,
      samplingStrategy: samplingStrategy,
      startIndex: startIndex,
      endIndex: endIndex,
      useCache: useCache,
      dataSignature: dataSignature,
    );
    totalStopwatch.stop();
    return (
      result: direct.result,
      report: AsyncChartProcessingReport(
        usedIsolate: false,
        isolateEligible: false,
        isolatePointThreshold: threshold,
        dataPointCount: dataPointCount,
        totalDuration: totalStopwatch.elapsed,
        processingReport: direct.report,
      ),
    );
  }

  static bool shouldUseIsolate(
    List<Series> series, {
    bool? useIsolate,
    int? startIndex,
    int? endIndex,
    int? isolatePointThreshold,
  }) {
    if (kIsWeb) return false;
    final effectivePointCount = ChartDataProcessor.effectiveDataPointCount(
      series,
      startIndex: startIndex,
      endIndex: endIndex,
    );
    if (effectivePointCount == 0) return false;
    if (useIsolate != null) return useIsolate;
    if (!AsyncChartProcessorConfig.enabled) return false;
    final threshold = _normalizedIsolatePointThreshold(
      isolatePointThreshold ?? AsyncChartProcessorConfig.isolatePointThreshold,
    );
    return effectivePointCount >= threshold;
  }

  static ChartProcessingResultWithReport _isolateEntry(
    _IsolatePayload payload,
  ) {
    final output = ChartDataProcessor.processWithReport(
      payload.series,
      renderThreshold: payload.renderThreshold,
      samplingStrategy: payload.samplingStrategy,
      startIndex: payload.startIndex,
      endIndex: payload.endIndex,
      useCache: false,
      dataSignature: payload.dataSignature,
    );
    return (result: output.result, report: output.report);
  }

  static int _normalizedIsolatePointThreshold(int threshold) =>
      threshold < 1 ? 1 : threshold;
}

/// Guards async chart-processing calls so stale results cannot overwrite newer
/// UI state.
///
/// The underlying isolate work cannot be force-cancelled, but this controller
/// gives widgets a cheap request-generation check before applying results.
class AsyncChartProcessingController {
  int _generation = 0;
  bool _disposed = false;

  int get generation => _generation;

  bool get isDisposed => _disposed;

  int beginRequest() {
    if (_disposed) {
      throw StateError('AsyncChartProcessingController has been disposed.');
    }
    return ++_generation;
  }

  bool isCurrent(int generation) => !_disposed && generation == _generation;

  void cancelPending() {
    if (_disposed) return;
    _generation++;
  }

  Future<T?> runLatest<T>(
    Future<T> Function(int generation) operation, {
    void Function(T value)? onStale,
  }) async {
    final requestGeneration = beginRequest();
    try {
      final value = await operation(requestGeneration);
      if (!isCurrent(requestGeneration)) {
        onStale?.call(value);
        return null;
      }
      return value;
    } catch (error, stackTrace) {
      if (!isCurrent(requestGeneration)) return null;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<ChartProcessingResult?> processLatest(
    List<Series> series, {
    int renderThreshold = 500,
    SamplingStrategy? samplingStrategy,
    int? startIndex,
    int? endIndex,
    bool? useCache,
    String? dataSignature,
    bool? useIsolate,
    int? isolatePointThreshold,
    void Function(AsyncChartProcessingReport report)? onReport,
    void Function(AsyncChartProcessingReport report)? onStaleReport,
  }) async {
    final output = await processLatestWithReport(
      series,
      renderThreshold: renderThreshold,
      samplingStrategy: samplingStrategy,
      startIndex: startIndex,
      endIndex: endIndex,
      useCache: useCache,
      dataSignature: dataSignature,
      useIsolate: useIsolate,
      isolatePointThreshold: isolatePointThreshold,
      onStaleReport: onStaleReport,
    );
    if (output == null) return null;
    onReport?.call(output.report);
    return output.result;
  }

  Future<AsyncChartProcessingResult?> processLatestWithReport(
    List<Series> series, {
    int renderThreshold = 500,
    SamplingStrategy? samplingStrategy,
    int? startIndex,
    int? endIndex,
    bool? useCache,
    String? dataSignature,
    bool? useIsolate,
    int? isolatePointThreshold,
    void Function(AsyncChartProcessingReport report)? onStaleReport,
  }) {
    return runLatest(
      (_) => AsyncChartProcessor.processAsyncWithReport(
        series,
        renderThreshold: renderThreshold,
        samplingStrategy: samplingStrategy,
        startIndex: startIndex,
        endIndex: endIndex,
        useCache: useCache,
        dataSignature: dataSignature,
        useIsolate: useIsolate,
        isolatePointThreshold: isolatePointThreshold,
      ),
      onStale: (value) => onStaleReport?.call(value.report),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
  }
}

class AsyncChartProcessorConfig {
  static bool enabled = true;
  static int isolatePointThreshold = 10000;
}

typedef AsyncChartProcessingResult = ({
  ChartProcessingResult result,
  AsyncChartProcessingReport report,
});

class AsyncChartProcessingReport {
  final bool usedIsolate;
  final bool isolateEligible;
  final int isolatePointThreshold;
  final int dataPointCount;
  final Duration totalDuration;
  final ChartDataProcessingReport processingReport;
  final bool processingCacheWritten;
  final ChartDataCacheWriteReason? processingCacheWriteReason;
  final ChartDataCacheAdmissionReason? processingCacheWriteAdmissionReason;
  final int? processingCacheWriteEstimatedBytes;
  final int? processingCacheWriteMaxBytes;

  const AsyncChartProcessingReport({
    required this.usedIsolate,
    required this.isolateEligible,
    required this.isolatePointThreshold,
    required this.dataPointCount,
    required this.totalDuration,
    required this.processingReport,
    this.processingCacheWritten = false,
    this.processingCacheWriteReason,
    this.processingCacheWriteAdmissionReason,
    this.processingCacheWriteEstimatedBytes,
    this.processingCacheWriteMaxBytes,
  });

  bool get cacheHit => processingReport.cacheHit;

  int get effectiveDataPointCount => processingReport.effectiveDataPointCount;

  int get sampleInputPointCount => processingReport.sampleInputPointCount;

  int get outputPointCount => processingReport.outputPointCount;

  bool get wasDownsampled => processingReport.wasDownsampled;

  int get reducedPointCount => processingReport.reducedPointCount;

  bool get isViewportReduced => processingReport.isViewportReduced;

  double get effectiveDataPointRatio =>
      processingReport.effectiveDataPointRatio;

  double get viewportReductionRatio => processingReport.viewportReductionRatio;

  double get samplingOutputRatio => processingReport.samplingOutputRatio;

  double get samplingReductionRatio => processingReport.samplingReductionRatio;

  ChartPerformanceSummary get performanceSummary =>
      ChartPerformanceSummary.fromProcessingReport(
        processingReport,
        usedIsolate: usedIsolate,
        isolateEligible: isolateEligible,
        isolatePointThreshold: isolatePointThreshold,
        endToEndDuration: totalDuration,
      );

  Map<String, dynamic> toJson() => {
    'usedIsolate': usedIsolate,
    'isolateEligible': isolateEligible,
    'isolatePointThreshold': isolatePointThreshold,
    'dataPointCount': dataPointCount,
    'processingCacheWritten': processingCacheWritten,
    if (processingCacheWriteReason != null)
      'processingCacheWriteReason': processingCacheWriteReason!.name,
    if (processingCacheWriteAdmissionReason != null)
      'processingCacheWriteAdmissionReason':
          processingCacheWriteAdmissionReason!.name,
    if (processingCacheWriteEstimatedBytes != null)
      'processingCacheWriteEstimatedBytes': processingCacheWriteEstimatedBytes,
    if (processingCacheWriteMaxBytes != null)
      'processingCacheWriteMaxBytes': processingCacheWriteMaxBytes,
    'effectiveDataPointCount': effectiveDataPointCount,
    'sampleInputPointCount': sampleInputPointCount,
    'outputPointCount': outputPointCount,
    'wasDownsampled': wasDownsampled,
    'reducedPointCount': reducedPointCount,
    'isViewportReduced': isViewportReduced,
    'effectiveDataPointRatio': effectiveDataPointRatio,
    'viewportReductionRatio': viewportReductionRatio,
    'samplingOutputRatio': samplingOutputRatio,
    'samplingReductionRatio': samplingReductionRatio,
    'totalDurationMicros': totalDuration.inMicroseconds,
    'performanceSummary': performanceSummary.toJson(),
    'processing': processingReport.toJson(),
  };
}

class _IsolatePayload {
  final List<Series> series;
  final int renderThreshold;
  final SamplingStrategy? samplingStrategy;
  final int? startIndex;
  final int? endIndex;
  final String? dataSignature;

  const _IsolatePayload({
    required this.series,
    required this.renderThreshold,
    required this.samplingStrategy,
    required this.startIndex,
    required this.endIndex,
    required this.dataSignature,
  });
}
