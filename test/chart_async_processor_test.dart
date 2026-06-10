import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  group('AsyncChartProcessor', () {
    setUp(() {
      AsyncChartProcessorConfig.enabled = true;
      AsyncChartProcessorConfig.isolatePointThreshold = 10000;
      ChartDataProcessor.configureProcessingCache(
        enabled: true,
        maxEntries: 8,
        maxBytes: 32 * 1024 * 1024,
        minPointCount: 0,
      );
      ChartDataProcessor.clearProcessingCache();
    });

    tearDown(() {
      AsyncChartProcessorConfig.enabled = true;
      AsyncChartProcessorConfig.isolatePointThreshold = 10000;
      ChartDataProcessor.configureProcessingCache(
        enabled: true,
        maxEntries: 32,
        maxBytes: 32 * 1024 * 1024,
        minPointCount: 1000,
      );
      ChartDataProcessor.clearProcessingCache();
    });

    test('uses effective data-point count for isolate eligibility', () {
      final oneLargeSeries = [
        Series(
          type: ChartType.line,
          data: List.generate(6000, (i) => i.toDouble()),
        ),
      ];
      final manyEmptySeries = List.generate(
        6000,
        (_) => Series(type: ChartType.line, data: const []),
      );

      expect(
        AsyncChartProcessor.shouldUseIsolate(
          oneLargeSeries,
          isolatePointThreshold: 5000,
        ),
        !kIsWeb,
      );
      expect(
        AsyncChartProcessor.shouldUseIsolate(
          oneLargeSeries,
          startIndex: 10,
          endIndex: 20,
          isolatePointThreshold: 5000,
        ),
        isFalse,
      );
      expect(
        AsyncChartProcessor.shouldUseIsolate(
          oneLargeSeries,
          startIndex: 5000,
          endIndex: 100,
          useIsolate: true,
        ),
        isFalse,
      );
      expect(
        AsyncChartProcessor.shouldUseIsolate(
          manyEmptySeries,
          isolatePointThreshold: 5000,
        ),
        isFalse,
      );
      expect(
        AsyncChartProcessor.shouldUseIsolate([
          Series(type: ChartType.line, data: const []),
        ], useIsolate: true),
        isFalse,
      );
      expect(
        AsyncChartProcessor.shouldUseIsolate([
          Series(type: ChartType.line, data: const [1]),
        ], isolatePointThreshold: -10),
        !kIsWeb,
      );
    });

    test('reports direct processing timings and cache hit state', () async {
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => (i % 100).toDouble()),
        ),
      ];

      final first = await AsyncChartProcessor.processAsyncWithReport(
        series,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        useIsolate: false,
        useCache: true,
      );
      final secondSeries = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => (i % 100).toDouble()),
        ),
      ];
      final second = await AsyncChartProcessor.processAsyncWithReport(
        secondSeries,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        useIsolate: false,
        useCache: true,
      );

      expect(first.report.usedIsolate, isFalse);
      expect(
        first.report.processingReport.path,
        ChartDataProcessingPath.cacheMiss,
      );
      expect(
        first.report.processingReport.samplingDuration.inMicroseconds >= 0,
        isTrue,
      );
      expect(first.report.sampleInputPointCount, 1000);
      expect(first.report.outputPointCount, 100);
      expect(first.report.wasDownsampled, isTrue);
      expect(first.report.reducedPointCount, 900);
      expect(first.report.samplingOutputRatio, closeTo(0.1, 1e-9));
      expect(first.report.samplingReductionRatio, closeTo(0.9, 1e-9));
      expect(first.report.toJson()['sampleInputPointCount'], 1000);
      expect(first.report.toJson()['outputPointCount'], 100);
      expect(first.report.toJson()['wasDownsampled'], isTrue);
      expect(first.report.toJson()['reducedPointCount'], 900);
      expect(second.report.usedIsolate, isFalse);
      expect(second.report.cacheHit, isTrue);
      expect(
        second.report.processingReport.path,
        ChartDataProcessingPath.cacheHit,
      );
      expect(second.result.processed.first.series, same(secondSeries.first));
    });

    test(
      'forced isolate processes by point count and primes main cache',
      () async {
        if (kIsWeb) return;

        final series = [
          Series(
            type: ChartType.line,
            data: List.generate(1200, (i) => (i % 300).toDouble()),
          ),
        ];

        final first = await AsyncChartProcessor.processAsyncWithReport(
          series,
          renderThreshold: 100,
          samplingStrategy: SamplingStrategy.nth,
          useIsolate: true,
          useCache: true,
        );
        final second = await AsyncChartProcessor.processAsyncWithReport(
          [
            Series(
              type: ChartType.line,
              data: List.generate(1200, (i) => (i % 300).toDouble()),
            ),
          ],
          renderThreshold: 100,
          samplingStrategy: SamplingStrategy.nth,
          useIsolate: true,
          useCache: true,
        );

        expect(first.report.usedIsolate, isTrue);
        expect(first.report.processingCacheWritten, isTrue);
        expect(
          first.report.processingCacheWriteReason,
          ChartDataCacheWriteReason.written,
        );
        expect(
          first.report.processingCacheWriteAdmissionReason,
          ChartDataCacheAdmissionReason.forcedOn,
        );
        expect(first.report.processingCacheWriteEstimatedBytes, greaterThan(0));
        expect(
          first.report.processingCacheWriteMaxBytes,
          ChartDataProcessor.processingCacheStats.maxBytes,
        );
        expect(first.report.toJson()['processingCacheWritten'], isTrue);
        expect(first.report.toJson()['processingCacheWriteReason'], 'written');
        expect(
          first.report.toJson()['processingCacheWriteAdmissionReason'],
          'forcedOn',
        );
        expect(
          first.result.processed.first.sampledValues.length,
          lessThan(1200),
        );
        expect(
          ChartDataProcessor.processingCacheStats.writes,
          greaterThanOrEqualTo(1),
        );
        expect(second.report.usedIsolate, isFalse);
        expect(second.report.cacheHit, isTrue);
        expect(second.report.processingCacheWritten, isFalse);
        expect(second.report.processingCacheWriteReason, isNull);
      },
    );

    test('forced isolate preserves data signature in report', () async {
      if (kIsWeb) return;

      const dataSignature = 'manual-data-signature';
      final output = await AsyncChartProcessor.processAsyncWithReport(
        [
          Series(
            type: ChartType.line,
            data: List.generate(1200, (i) => (i % 300).toDouble()),
          ),
        ],
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        dataSignature: dataSignature,
        useIsolate: true,
        useCache: false,
      );

      expect(output.report.usedIsolate, isTrue);
      expect(output.report.processingCacheWritten, isFalse);
      expect(
        output.report.processingCacheWriteReason,
        ChartDataCacheWriteReason.admissionRejected,
      );
      expect(
        output.report.processingCacheWriteAdmissionReason,
        ChartDataCacheAdmissionReason.forcedOff,
      );
      expect(output.report.toJson()['processingCacheWritten'], isFalse);
      expect(
        output.report.toJson()['processingCacheWriteReason'],
        'admissionRejected',
      );
      expect(
        output.report.toJson()['processingCacheWriteAdmissionReason'],
        'forcedOff',
      );
      expect(output.report.processingReport.dataSignature, dataSignature);
    });

    test(
      'forced isolate reports cache write entries over byte budget',
      () async {
        if (kIsWeb) return;

        ChartDataProcessor.configureProcessingCache(maxBytes: 1);

        final output = await AsyncChartProcessor.processAsyncWithReport(
          [
            Series(
              type: ChartType.line,
              data: List.generate(1200, (i) => (i % 300).toDouble()),
            ),
          ],
          renderThreshold: 100,
          samplingStrategy: SamplingStrategy.nth,
          useIsolate: true,
          useCache: true,
        );

        expect(output.report.usedIsolate, isTrue);
        expect(output.report.processingCacheWritten, isFalse);
        expect(
          output.report.processingCacheWriteReason,
          ChartDataCacheWriteReason.entryExceedsByteCapacity,
        );
        expect(
          output.report.processingCacheWriteAdmissionReason,
          ChartDataCacheAdmissionReason.forcedOn,
        );
        expect(
          output.report.processingCacheWriteEstimatedBytes,
          greaterThan(1),
        );
        expect(output.report.processingCacheWriteMaxBytes, 1);
        expect(ChartDataProcessor.processingCacheStats.skippedWrites, 1);
        expect(ChartDataProcessor.processingCacheStats.writes, 0);
        expect(
          output.report.toJson()['processingCacheWriteReason'],
          'entryExceedsByteCapacity',
        );
      },
    );

    test('isolate cache-hit report uses normalized processor inputs', () async {
      if (kIsWeb) return;

      List<Series> makeSeries() => [
        Series(type: ChartType.line, data: List.generate(1200, (i) => i)),
      ];

      await AsyncChartProcessor.processAsyncWithReport(
        makeSeries(),
        renderThreshold: 0,
        samplingStrategy: SamplingStrategy.nth,
        startIndex: 5,
        endIndex: 5,
        useIsolate: true,
        useCache: true,
      );
      final second = await AsyncChartProcessor.processAsyncWithReport(
        makeSeries(),
        renderThreshold: 1,
        samplingStrategy: SamplingStrategy.nth,
        startIndex: 5,
        endIndex: 5,
        useIsolate: true,
        useCache: true,
      );

      expect(second.report.usedIsolate, isFalse);
      expect(second.report.cacheHit, isTrue);
      expect(second.report.processingReport.renderThreshold, 2);
      expect(second.report.processingReport.startIndex, 5);
      expect(second.report.processingReport.endIndex, 5);
      expect(second.report.processingReport.outputPointCount, 1);
      expect(second.result.processed.single.sampledValues, [5]);
    });

    test('small viewport on large data stays on direct path', () async {
      final series = [
        Series(type: ChartType.line, data: List.generate(12000, (i) => i)),
      ];

      final output = await AsyncChartProcessor.processAsyncWithReport(
        series,
        renderThreshold: 100,
        startIndex: 100,
        endIndex: 109,
        isolatePointThreshold: 5000,
        useCache: false,
      );

      expect(output.report.usedIsolate, isFalse);
      expect(output.report.isolateEligible, isFalse);
      expect(output.report.dataPointCount, 12000);
      expect(output.report.effectiveDataPointCount, 10);
      expect(output.report.sampleInputPointCount, 10);
      expect(output.report.outputPointCount, 10);
      expect(output.report.wasDownsampled, isFalse);
      expect(output.report.reducedPointCount, 0);
      expect(output.report.isViewportReduced, isTrue);
      expect(output.report.effectiveDataPointRatio, closeTo(10 / 12000, 1e-9));
      expect(
        output.report.viewportReductionRatio,
        closeTo(1 - (10 / 12000), 1e-9),
      );
      expect(output.report.processingReport.effectiveDataPointCount, 10);
      expect(output.report.processingReport.sampleInputPointCount, 10);
      expect(output.report.processingReport.outputPointCount, 10);
      expect(output.report.toJson()['effectiveDataPointCount'], 10);
      expect(output.report.toJson()['sampleInputPointCount'], 10);
      expect(output.report.toJson()['outputPointCount'], 10);
      expect(output.report.toJson()['wasDownsampled'], isFalse);
      expect(output.report.toJson()['reducedPointCount'], 0);
      expect(output.report.toJson()['isViewportReduced'], isTrue);
      expect(
        output.report.toJson()['effectiveDataPointRatio'],
        closeTo(10 / 12000, 1e-9),
      );
      expect(
        output.report.toJson()['viewportReductionRatio'],
        closeTo(1 - (10 / 12000), 1e-9),
      );
      expect(output.result.processed.single.sampledValues, [
        100,
        101,
        102,
        103,
        104,
        105,
        106,
        107,
        108,
        109,
      ]);
    });

    test(
      'top-level sampler diagnostics ignore invalid-value cleanup',
      () async {
        final output = await AsyncChartProcessor.processAsyncWithReport(
          [
            Series(
              type: ChartType.line,
              data: [double.nan, 1, double.infinity, 2, 3],
            ),
          ],
          renderThreshold: 10,
          useIsolate: false,
          useCache: false,
        );

        final json = output.report.toJson();
        final processingJson = json['processing'] as Map<String, dynamic>;

        expect(output.report.effectiveDataPointCount, 5);
        expect(output.report.sampleInputPointCount, 3);
        expect(output.report.outputPointCount, 3);
        expect(output.report.wasDownsampled, isFalse);
        expect(output.report.reducedPointCount, 0);
        expect(output.report.samplingOutputRatio, 1);
        expect(output.report.samplingReductionRatio, 0);
        expect(json['sampleInputPointCount'], 3);
        expect(json['wasDownsampled'], isFalse);
        expect(processingJson['sampleInputPointCount'], 3);
        expect(output.result.processed.single.sampledValues, [1, 2, 3]);
        expect(output.result.processed.single.sourceIndices, [1, 3, 4]);
      },
    );

    test('forced isolate is ignored for empty data', () async {
      final output = await AsyncChartProcessor.processAsyncWithReport([
        Series(type: ChartType.line, data: const []),
      ], useIsolate: true);

      expect(output.report.usedIsolate, isFalse);
      expect(output.report.isolateEligible, isFalse);
      expect(output.result.processed.single.sampledValues, isEmpty);
    });

    test('forced isolate is ignored for empty viewport', () async {
      final output = await AsyncChartProcessor.processAsyncWithReport(
        [
          Series(
            type: ChartType.line,
            data: List.generate(12000, (i) => i.toDouble()),
          ),
        ],
        startIndex: 9000,
        endIndex: 1000,
        useIsolate: true,
        useCache: false,
      );

      expect(output.report.usedIsolate, isFalse);
      expect(output.report.isolateEligible, isFalse);
      expect(output.report.processingReport.effectiveDataPointCount, 0);
      expect(output.result.processed.single.sampledValues, isEmpty);
    });

    test('processAsync forwards report callback', () async {
      AsyncChartProcessingReport? report;

      final result = await AsyncChartProcessor.processAsync(
        [
          Series(type: ChartType.line, data: [1, 2, 3, 4]),
        ],
        useIsolate: false,
        onReport: (value) => report = value,
      );

      expect(result.stats.globalMax, 4);
      expect(report, isNotNull);
      expect(report!.dataPointCount, 4);
      expect(report!.usedIsolate, isFalse);
      expect(report!.performanceSummary.usedIsolate, isFalse);
      expect(report!.performanceSummary.isolateEligible, isFalse);
      expect(
        report!.toJson()['performanceSummary'],
        containsPair('usedIsolate', false),
      );
    });

    test(
      'controller drops stale operations after a newer request starts',
      () async {
        final controller = AsyncChartProcessingController();
        final firstCompleter = Completer<int>();
        final secondCompleter = Completer<int>();
        int? staleValue;

        final first = controller.runLatest(
          (_) => firstCompleter.future,
          onStale: (value) => staleValue = value,
        );
        final second = controller.runLatest((_) => secondCompleter.future);

        firstCompleter.complete(1);
        secondCompleter.complete(2);

        expect(await first, isNull);
        expect(await second, 2);
        expect(staleValue, 1);
        expect(controller.generation, 2);

        controller.dispose();
      },
    );

    test('controller drops pending results after dispose', () async {
      final controller = AsyncChartProcessingController();
      final completer = Completer<int>();

      final future = controller.runLatest((_) => completer.future);
      controller.dispose();
      completer.complete(7);

      expect(await future, isNull);
      expect(controller.isDisposed, isTrue);
      expect(() => controller.beginRequest(), throwsStateError);
    });

    test(
      'controller processLatestWithReport returns latest processor result',
      () async {
        final controller = AsyncChartProcessingController();

        final output = await controller.processLatestWithReport(
          [
            Series(type: ChartType.line, data: [1, 2, 3, 4]),
          ],
          renderThreshold: 100,
          useIsolate: false,
          useCache: false,
        );

        expect(output, isNotNull);
        expect(output!.report.usedIsolate, isFalse);
        expect(output.report.processingReport.outputPointCount, 4);
        expect(output.result.stats.globalMax, 4);

        controller.dispose();
      },
    );
  });
}
