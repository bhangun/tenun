import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  group('ChartDataProcessor processing cache', () {
    setUp(() {
      ChartDataProcessor.configureProcessingCache(
        enabled: true,
        maxEntries: 4,
        maxBytes: 32 * 1024 * 1024,
        minPointCount: 0,
        extractionCacheEnabled: true,
        maxExtractionEntries: 16,
        maxExtractionBytes: 32 * 1024 * 1024,
        minExtractionPointCount: 0,
      );
      ChartDataProcessor.clearProcessingCache();
    });

    tearDown(() {
      ChartDataProcessor.configureProcessingCache(
        enabled: true,
        maxEntries: 32,
        maxBytes: 32 * 1024 * 1024,
        minPointCount: 1000,
        extractionCacheEnabled: true,
        maxExtractionEntries: 128,
        maxExtractionBytes: 32 * 1024 * 1024,
        minExtractionPointCount: 1000,
      );
      ChartDataProcessor.clearProcessingCache();
    });

    test('caches repeated equivalent large processing by content', () {
      final firstSeries = [
        Series(
          type: ChartType.line,
          name: 'Revenue',
          data: List.generate(1000, (i) => (i % 100).toDouble()),
        ),
      ];
      final secondSeries = [
        Series(
          type: ChartType.line,
          name: 'Revenue',
          data: List.generate(1000, (i) => (i % 100).toDouble()),
        ),
      ];

      final first = ChartDataProcessor.process(
        firstSeries,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
      );
      final second = ChartDataProcessor.process(
        secondSeries,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
      );
      final third = ChartDataProcessor.process(
        secondSeries,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
      );

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.misses, 1);
      expect(stats.hits, 2);
      expect(stats.size, 1);
      expect(second.stats.globalMax, first.stats.globalMax);
      expect(
        identical(
          second.processed.first.sampledValues,
          third.processed.first.sampledValues,
        ),
        isTrue,
      );
      expect(second.processed.first.series, same(secondSeries.first));
    });

    test('returns immutable direct results and cached snapshots', () {
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => i.toDouble()),
        ),
      ];

      final first = ChartDataProcessor.process(
        series,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        useCache: true,
      );

      expect(first.stats.globalMin, 0);
      expect(
        () => first.processed.add(
          ProcessedSeries(
            series: series.single,
            points: const [],
            sampledValues: const [],
            stats: SeriesStats.empty,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => first.processed.single.sampledValues[0] = -999,
        throwsUnsupportedError,
      );
      expect(
        () => first.processed.single.points[0] = const DataPoint(0, -999),
        throwsUnsupportedError,
      );
      expect(
        () => first.processed.single.sourceIndices[0] = -999,
        throwsUnsupportedError,
      );
      expect(
        () => first.processed.single.stats.values[0] = -999,
        throwsUnsupportedError,
      );
      expect(
        () => first.stats.perSeries.add(SeriesStats.empty),
        throwsUnsupportedError,
      );

      final cached = ChartDataProcessor.process(
        series,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        useCache: true,
      );

      expect(cached.stats.globalMin, 0);
      expect(cached.processed.single.sampledValues.first, 0);
      expect(cached.processed.single.points.first.y, 0);
      expect(cached.processed.single.sourceIndices.first, 0);
      expect(cached.processed.single.stats.values.first, 0);
      expect(
        () => cached.processed.add(
          ProcessedSeries(
            series: series.single,
            points: const [],
            sampledValues: const [],
            stats: SeriesStats.empty,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => cached.processed.single.sampledValues[0] = 42,
        throwsUnsupportedError,
      );
      expect(
        () => cached.processed.single.points.add(const DataPoint(1, 42)),
        throwsUnsupportedError,
      );
      expect(
        () => cached.processed.single.sourceIndices[0] = 42,
        throwsUnsupportedError,
      );
      expect(
        () => cached.processed.single.stats.values[0] = 42,
        throwsUnsupportedError,
      );
      expect(
        () => cached.stats.perSeries.add(SeriesStats.empty),
        throwsUnsupportedError,
      );
    });

    test('invalidates when equivalent series data content changes', () {
      final data = List<dynamic>.generate(1000, (i) => i.toDouble());
      final firstSeries = [
        Series(type: ChartType.line, name: 'Mutable', data: data),
      ];

      final first = ChartDataProcessor.process(
        firstSeries,
        renderThreshold: 100,
      );
      data[500] = 10000.0;
      final secondSeries = [
        Series(type: ChartType.line, name: 'Mutable', data: data),
      ];
      final second = ChartDataProcessor.process(
        secondSeries,
        renderThreshold: 100,
      );

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.misses, 2);
      expect(stats.hits, 0);
      expect(first.stats.globalMax, 999);
      expect(second.stats.globalMax, 10000);
    });

    test('skips simple data by default but can be forced per call', () {
      ChartDataProcessor.configureProcessingCache(minPointCount: 1000);
      final series = [
        Series(type: ChartType.line, data: [1, 2, 3]),
      ];

      ChartDataProcessor.process(series);
      ChartDataProcessor.process(series);
      expect(ChartDataProcessor.processingCacheStats.lookups, 0);
      expect(ChartDataProcessor.processingCacheStats.size, 0);

      ChartDataProcessor.process(series, useCache: true);
      ChartDataProcessor.process(series, useCache: true);
      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.misses, 1);
      expect(stats.hits, 1);
      expect(stats.size, 1);
    });

    test('keeps viewport and sampling options in the cache key', () {
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => i.toDouble()),
        ),
      ];

      final firstWindow = ChartDataProcessor.process(
        series,
        renderThreshold: 50,
        startIndex: 0,
        endIndex: 100,
      );
      final secondWindow = ChartDataProcessor.process(
        series,
        renderThreshold: 50,
        startIndex: 100,
        endIndex: 200,
      );
      final firstWindowAgain = ChartDataProcessor.process(
        series,
        renderThreshold: 50,
        startIndex: 0,
        endIndex: 100,
      );

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.misses, 2);
      expect(stats.hits, 1);
      expect(firstWindow.stats.globalMin, 0);
      expect(secondWindow.stats.globalMin, 100);
      expect(firstWindowAgain.stats.globalMin, firstWindow.stats.globalMin);
      expect(
        firstWindowAgain.processed.single.sampledValues,
        firstWindow.processed.single.sampledValues,
      );
    });

    test('reuses extracted series across different viewport cache misses', () {
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => i.toDouble()),
        ),
      ];

      final firstWindow = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 50,
        startIndex: 0,
        endIndex: 99,
        useCache: true,
        dataSignature: 'stable-series',
      );
      final secondWindow = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 50,
        startIndex: 100,
        endIndex: 199,
        useCache: true,
        dataSignature: 'stable-series',
      );

      final stats = ChartDataProcessor.processingCacheStats;
      expect(firstWindow.report.cacheHit, isFalse);
      expect(secondWindow.report.cacheHit, isFalse);
      expect(stats.misses, 2);
      expect(stats.extractionMisses, 1);
      expect(stats.extractionHits, 1);
      expect(stats.extractionWrites, 1);
      expect(stats.extractionSize, 1);
      expect(stats.extractionCurrentBytes, greaterThan(0));
      expect(stats.toJson()['extraction']['hits'], 1);
    });

    test(
      'uses effective viewport size for automatic result cache admission',
      () {
        ChartDataProcessor.configureProcessingCache(
          minPointCount: 1000,
          minExtractionPointCount: 1000,
        );
        final series = [
          Series(
            type: ChartType.line,
            data: List.generate(10000, (i) => i.toDouble()),
          ),
        ];

        final firstWindow = ChartDataProcessor.processWithReport(
          series,
          renderThreshold: 50,
          startIndex: 10,
          endIndex: 19,
        );
        final secondWindow = ChartDataProcessor.processWithReport(
          series,
          renderThreshold: 50,
          startIndex: 10,
          endIndex: 19,
        );

        final stats = ChartDataProcessor.processingCacheStats;
        expect(firstWindow.report.path, ChartDataProcessingPath.direct);
        expect(firstWindow.report.dataPointCount, 10000);
        expect(firstWindow.report.effectiveDataPointCount, 10);
        expect(firstWindow.report.isViewportReduced, isTrue);
        expect(
          firstWindow.report.effectiveDataPointRatio,
          closeTo(0.001, 1e-9),
        );
        expect(firstWindow.report.viewportReductionRatio, closeTo(0.999, 1e-9));
        expect(firstWindow.report.outputPointCount, 10);
        expect(firstWindow.report.wasDownsampled, isFalse);
        expect(firstWindow.report.reducedPointCount, 0);
        expect(firstWindow.report.samplingOutputRatio, 1);
        expect(firstWindow.report.samplingReductionRatio, 0);
        expect(firstWindow.report.cacheEligible, isFalse);
        expect(firstWindow.report.extractionCacheEligible, isTrue);
        expect(
          firstWindow.report.cacheAdmissionReason,
          ChartDataCacheAdmissionReason.belowEffectivePointThreshold,
        );
        expect(
          firstWindow.report.extractionCacheAdmissionReason,
          ChartDataCacheAdmissionReason.eligible,
        );
        expect(
          firstWindow.report.cacheAdmissionHint,
          contains('Effective points (10)'),
        );
        expect(
          firstWindow.report.extractionCacheAdmissionHint,
          'Cache is eligible for this run.',
        );
        expect(
          firstWindow.report.cacheRecommendedAction,
          ChartDataCacheRecommendedAction.lowerResultCachePointThreshold,
        );
        expect(
          firstWindow.report.extractionCacheRecommendedAction,
          ChartDataCacheRecommendedAction.none,
        );
        expect(
          firstWindow.report.cacheRecommendationSeverity,
          ChartDataCacheRecommendationSeverity.info,
        );
        expect(
          firstWindow.report.extractionCacheRecommendationSeverity,
          ChartDataCacheRecommendationSeverity.healthy,
        );
        expect(
          firstWindow.report.performanceSummary.overallCacheSeverity,
          ChartDataCacheRecommendationSeverity.info,
        );
        expect(
          firstWindow.report.performanceSummary.cacheRecommendedAction,
          ChartDataCacheRecommendedAction.lowerResultCachePointThreshold,
        );
        expect(firstWindow.report.performanceSummary.isViewportReduced, isTrue);
        expect(
          firstWindow.report.performanceSummary.effectiveDataPointRatio,
          closeTo(0.001, 1e-9),
        );
        expect(
          firstWindow.report.performanceSummary.viewportReductionRatio,
          closeTo(0.999, 1e-9),
        );
        expect(firstWindow.report.toJson()['effectiveDataPointCount'], 10);
        expect(firstWindow.report.toJson()['isViewportReduced'], isTrue);
        expect(
          firstWindow.report.toJson()['effectiveDataPointRatio'],
          closeTo(0.001, 1e-9),
        );
        expect(
          firstWindow.report.toJson()['viewportReductionRatio'],
          closeTo(0.999, 1e-9),
        );
        expect(firstWindow.report.toJson()['outputPointCount'], 10);
        expect(firstWindow.report.toJson()['wasDownsampled'], isFalse);
        expect(firstWindow.report.toJson()['reducedPointCount'], 0);
        expect(firstWindow.report.toJson()['samplingOutputRatio'], 1);
        expect(firstWindow.report.toJson()['samplingReductionRatio'], 0);
        expect(firstWindow.report.toJson()['extractionCacheEligible'], isTrue);
        expect(
          firstWindow.report.toJson()['cacheAdmissionReason'],
          'belowEffectivePointThreshold',
        );
        expect(
          firstWindow.report.toJson()['cacheAdmissionHint'],
          contains('minPointCount (1000)'),
        );
        expect(
          firstWindow.report.toJson()['extractionCacheAdmissionReason'],
          'eligible',
        );
        expect(
          firstWindow.report.toJson()['extractionCacheAdmissionHint'],
          'Cache is eligible for this run.',
        );
        expect(
          firstWindow.report.toJson()['cacheRecommendedAction'],
          'lowerResultCachePointThreshold',
        );
        expect(
          firstWindow.report.toJson()['extractionCacheRecommendedAction'],
          'none',
        );
        expect(
          firstWindow.report.toJson()['cacheRecommendationSeverity'],
          'info',
        );
        expect(
          firstWindow.report.toJson()['extractionCacheRecommendationSeverity'],
          'healthy',
        );
        final summaryJson =
            firstWindow.report.toJson()['performanceSummary']
                as Map<String, dynamic>;
        expect(summaryJson['overallCacheSeverity'], 'info');
        expect(summaryJson['isViewportReduced'], isTrue);
        expect(summaryJson['effectiveDataPointRatio'], closeTo(0.001, 1e-9));
        expect(summaryJson['viewportReductionRatio'], closeTo(0.999, 1e-9));
        expect(
          summaryJson['cacheRecommendedAction'],
          'lowerResultCachePointThreshold',
        );
        expect(summaryJson['extractionCacheRecommendedAction'], 'none');
        expect(secondWindow.report.path, ChartDataProcessingPath.direct);
        expect(stats.lookups, 0);
        expect(stats.size, 0);
        expect(stats.extractionMisses, 1);
        expect(stats.extractionHits, 1);
        expect(stats.extractionWrites, 1);
        expect(stats.extractionSize, 1);
      },
    );

    test('reports cache admission reasons for skipped and forced paths', () {
      final smallSeries = [
        Series(type: ChartType.line, data: [1, 2, 3]),
      ];
      final largeSeries = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => i.toDouble()),
        ),
      ];

      ChartDataProcessor.configureProcessingCache(
        minPointCount: 1000,
        minExtractionPointCount: 1000,
      );
      final belowThreshold = ChartDataProcessor.processWithReport(smallSeries);
      expect(
        belowThreshold.report.cacheAdmissionReason,
        ChartDataCacheAdmissionReason.belowEffectivePointThreshold,
      );
      expect(
        belowThreshold.report.extractionCacheAdmissionReason,
        ChartDataCacheAdmissionReason.belowExtractionPointThreshold,
      );
      expect(
        belowThreshold.report.cacheAdmissionHint,
        contains('lower minPointCount'),
      );
      expect(
        belowThreshold.report.extractionCacheAdmissionHint,
        contains('lower minExtractionPointCount'),
      );
      expect(
        belowThreshold.report.cacheRecommendedAction,
        ChartDataCacheRecommendedAction.lowerResultCachePointThreshold,
      );
      expect(
        belowThreshold.report.extractionCacheRecommendedAction,
        ChartDataCacheRecommendedAction.lowerExtractionCachePointThreshold,
      );
      expect(
        belowThreshold.report.cacheRecommendationSeverity,
        ChartDataCacheRecommendationSeverity.info,
      );
      expect(
        belowThreshold.report.extractionCacheRecommendationSeverity,
        ChartDataCacheRecommendationSeverity.info,
      );

      ChartDataProcessor.configureProcessingCache(enabled: false);
      final disabled = ChartDataProcessor.processWithReport(largeSeries);
      expect(
        disabled.report.cacheAdmissionReason,
        ChartDataCacheAdmissionReason.disabled,
      );
      expect(
        disabled.report.extractionCacheAdmissionReason,
        ChartDataCacheAdmissionReason.disabled,
      );
      expect(
        disabled.report.cacheAdmissionHint,
        contains('configureProcessingCache(enabled: true)'),
      );
      expect(
        disabled.report.cacheRecommendedAction,
        ChartDataCacheRecommendedAction.enableCache,
      );
      expect(
        disabled.report.extractionCacheRecommendedAction,
        ChartDataCacheRecommendedAction.enableCache,
      );
      expect(
        disabled.report.cacheRecommendationSeverity,
        ChartDataCacheRecommendationSeverity.warning,
      );
      expect(
        disabled.report.extractionCacheRecommendationSeverity,
        ChartDataCacheRecommendationSeverity.warning,
      );

      final forcedOff = ChartDataProcessor.processWithReport(
        largeSeries,
        useCache: false,
      );
      expect(
        forcedOff.report.cacheAdmissionReason,
        ChartDataCacheAdmissionReason.forcedOff,
      );
      expect(
        forcedOff.report.extractionCacheAdmissionReason,
        ChartDataCacheAdmissionReason.forcedOff,
      );
      expect(forcedOff.report.cacheAdmissionHint, contains('forced off'));
      expect(
        forcedOff.report.cacheRecommendedAction,
        ChartDataCacheRecommendedAction.reviewCacheOverride,
      );
      expect(
        forcedOff.report.extractionCacheRecommendedAction,
        ChartDataCacheRecommendedAction.reviewCacheOverride,
      );
      expect(
        forcedOff.report.cacheRecommendationSeverity,
        ChartDataCacheRecommendationSeverity.info,
      );
      expect(
        forcedOff.report.extractionCacheRecommendationSeverity,
        ChartDataCacheRecommendationSeverity.info,
      );

      ChartDataProcessor.configureProcessingCache(enabled: true);
      final forcedOn = ChartDataProcessor.processWithReport(
        smallSeries,
        useCache: true,
      );
      expect(forcedOn.report.cacheEligible, isTrue);
      expect(
        forcedOn.report.cacheAdmissionReason,
        ChartDataCacheAdmissionReason.forcedOn,
      );
      expect(forcedOn.report.cacheAdmissionHint, contains('forced on'));
      expect(
        forcedOn.report.cacheRecommendedAction,
        ChartDataCacheRecommendedAction.reviewCacheOverride,
      );
      expect(
        forcedOn.report.cacheRecommendationSeverity,
        ChartDataCacheRecommendationSeverity.info,
      );

      ChartDataProcessor.configureProcessingCache(
        maxEntries: 0,
        maxExtractionEntries: 0,
      );
      final noCapacity = ChartDataProcessor.processWithReport(largeSeries);
      expect(
        noCapacity.report.cacheAdmissionReason,
        ChartDataCacheAdmissionReason.noEntryCapacity,
      );
      expect(
        noCapacity.report.extractionCacheAdmissionReason,
        ChartDataCacheAdmissionReason.noExtractionEntryCapacity,
      );
      expect(
        noCapacity.report.cacheAdmissionHint,
        contains('Increase maxEntries'),
      );
      expect(
        noCapacity.report.extractionCacheAdmissionHint,
        contains('Increase maxExtractionEntries'),
      );
      expect(
        noCapacity.report.cacheRecommendedAction,
        ChartDataCacheRecommendedAction.increaseResultCacheEntries,
      );
      expect(
        noCapacity.report.extractionCacheRecommendedAction,
        ChartDataCacheRecommendedAction.increaseExtractionCacheEntries,
      );
      expect(
        noCapacity.report.cacheRecommendationSeverity,
        ChartDataCacheRecommendationSeverity.warning,
      );
      expect(
        noCapacity.report.extractionCacheRecommendationSeverity,
        ChartDataCacheRecommendationSeverity.warning,
      );
    });

    test('snapshots cache policy inside processing reports', () {
      final series = [
        Series(type: ChartType.line, data: [1, 2, 3]),
      ];

      ChartDataProcessor.configureProcessingCache(
        minPointCount: 1000,
        minExtractionPointCount: 1000,
      );
      final report = ChartDataProcessor.processWithReport(series).report;

      ChartDataProcessor.configureProcessingCache(
        minPointCount: 5,
        minExtractionPointCount: 5,
      );

      expect(report.cachePolicy.minPointCount, 1000);
      expect(report.cachePolicy.minExtractionPointCount, 1000);
      expect(report.cacheAdmissionHint, contains('minPointCount (1000)'));
      expect(
        report.extractionCacheAdmissionHint,
        contains('minExtractionPointCount (1000)'),
      );

      final json = report.toJson();
      expect(json['cachePolicy']['minPointCount'], 1000);
      expect(json['cachePolicy']['extraction']['minPointCount'], 1000);
      expect(json['cacheAdmissionHint'], contains('minPointCount (1000)'));
      expect(
        json['extractionCacheAdmissionHint'],
        contains('minExtractionPointCount (1000)'),
      );
    });

    test('invalidates extracted series when raw content signature changes', () {
      final data = List<dynamic>.generate(1000, (i) => i.toDouble());
      final firstSeries = [Series(type: ChartType.line, data: data)];

      ChartDataProcessor.process(
        firstSeries,
        renderThreshold: 50,
        startIndex: 0,
        endIndex: 99,
        useCache: true,
      );
      data[150] = 10000.0;
      final secondSeries = [Series(type: ChartType.line, data: data)];
      final changedWindow = ChartDataProcessor.process(
        secondSeries,
        renderThreshold: 50,
        startIndex: 100,
        endIndex: 199,
        useCache: true,
      );

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.extractionMisses, 2);
      expect(stats.extractionHits, 0);
      expect(changedWindow.processed.single.stats.max, 10000);
    });

    test('keeps series type in result and extraction cache keys', () {
      final ohlc = List.generate(1000, (i) {
        final open = 100 + i.toDouble();
        return [open, open + 20, open - 10, open + 5, 1000 + i];
      });
      final lineSeries = [Series(type: ChartType.line, data: ohlc)];
      final candleSeries = [Series(type: ChartType.candlestick, data: ohlc)];

      final lineWindow = ChartDataProcessor.processWithReport(
        lineSeries,
        renderThreshold: 1000,
        startIndex: 0,
        endIndex: 99,
        useCache: true,
        dataSignature: 'shared-ohlc-data',
      );
      final candleWindow = ChartDataProcessor.processWithReport(
        candleSeries,
        renderThreshold: 1000,
        startIndex: 0,
        endIndex: 99,
        useCache: true,
        dataSignature: 'shared-ohlc-data',
      );
      final nextCandleWindow = ChartDataProcessor.processWithReport(
        candleSeries,
        renderThreshold: 1000,
        startIndex: 100,
        endIndex: 199,
        useCache: true,
        dataSignature: 'shared-ohlc-data',
      );

      expect(lineWindow.report.cacheHit, isFalse);
      expect(candleWindow.report.cacheHit, isFalse);
      expect(nextCandleWindow.report.cacheHit, isFalse);
      expect(lineWindow.result.processed.single.sampledValues.first, 120);
      expect(candleWindow.result.processed.single.sampledValues.first, 105);
      expect(nextCandleWindow.result.processed.single.sampledValues.first, 205);
      expect(lineWindow.result.stats.globalMax, 219);
      expect(candleWindow.result.stats.globalMax, 204);

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.misses, 3);
      expect(stats.hits, 0);
      expect(stats.extractionMisses, 2);
      expect(stats.extractionHits, 1);
    });

    test('treats viewport endIndex as inclusive', () {
      final series = [
        Series(type: ChartType.line, data: List.generate(10, (i) => i)),
      ];

      final result = ChartDataProcessor.process(
        series,
        renderThreshold: 100,
        startIndex: 2,
        endIndex: 4,
        useCache: false,
      );

      expect(result.processed.single.sampledValues, [2, 3, 4]);
      expect(result.processed.single.sourceIndices, [2, 3, 4]);
      expect(result.processed.single.points.map((point) => point.x), [2, 3, 4]);
      expect(result.processed.single.stats.count, 3);
      expect(result.stats.globalMin, 2);
      expect(result.stats.globalMax, 4);
    });

    test(
      'skips sampler allocation when visible data fits render threshold',
      () {
        final series = [
          Series(
            type: ChartType.line,
            data: [double.nan, 1, 2, double.infinity, 3],
          ),
        ];

        final output = ChartDataProcessor.processWithReport(
          series,
          renderThreshold: 10,
          useCache: false,
        );
        final processed = output.result.processed.single;

        expect(processed.sampledValues, [1, 2, 3]);
        expect(processed.sourceIndices, [1, 2, 4]);
        expect(processed.points.map((point) => point.x), [1, 2, 4]);
        expect(processed.points.map((point) => point.y), [1, 2, 3]);
        expect(processed.stats.values, [1, 2, 3]);
        expect(output.report.effectiveDataPointCount, 5);
        expect(output.report.sampleInputPointCount, 3);
        expect(output.report.outputPointCount, 3);
        expect(processed.wasDownsampled, isFalse);
        expect(output.report.wasDownsampled, isFalse);
        expect(output.report.reducedPointCount, 0);
        expect(output.report.samplingOutputRatio, 1);
        expect(output.report.samplingReductionRatio, 0);
        expect(
          output.report.resolvedSamplingStrategy,
          ChartResolvedSamplingStrategy.none,
        );
        expect(output.report.toJson()['sampleInputPointCount'], 3);
        expect(output.report.performanceSummary.sampleInputPointCount, 3);
        expect(output.report.samplingDuration, Duration.zero);
        expect(() => processed.sampledValues[0] = -1, throwsUnsupportedError);
        expect(() => processed.sourceIndices[0] = -1, throwsUnsupportedError);
      },
    );

    test('keeps single-point viewport windows visible', () {
      final series = [
        Series(type: ChartType.line, data: List.generate(10, (i) => i)),
      ];

      final output = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 100,
        startIndex: 5,
        endIndex: 5,
        useCache: false,
      );

      expect(output.result.processed.single.sampledValues, [5]);
      expect(output.result.processed.single.sourceIndices, [5]);
      expect(output.result.processed.single.points.single.x, 5);
      expect(output.result.processed.single.stats.count, 1);
      expect(output.report.startIndex, 5);
      expect(output.report.endIndex, 5);
      expect(output.report.outputPointCount, 1);
    });

    test('skips extraction work for empty effective viewport windows', () {
      final series = [
        Series(
          type: ChartType.line,
          name: 'A',
          data: List.generate(10000, (i) => i.toDouble()),
        ),
        Series(
          type: ChartType.line,
          name: 'B',
          data: List.generate(5000, (i) => (i * 2).toDouble()),
        ),
      ];

      final output = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 10,
        startIndex: 9000,
        endIndex: 1000,
        useCache: false,
      );

      expect(output.result.processed, hasLength(2));
      expect(output.result.stats.globalMin, 0);
      expect(output.result.stats.globalMax, 100);
      expect(output.result.stats.globalSum, 0);
      expect(output.result.stats.perSeries, [
        SeriesStats.empty,
        SeriesStats.empty,
      ]);
      for (var i = 0; i < output.result.processed.length; i++) {
        final processed = output.result.processed[i];
        expect(processed.series, same(series[i]));
        expect(processed.sampledValues, isEmpty);
        expect(processed.sourceIndices, isEmpty);
        expect(processed.points, isEmpty);
        expect(processed.stats, SeriesStats.empty);
      }

      expect(output.report.effectiveDataPointCount, 0);
      expect(output.report.outputPointCount, 0);
      expect(output.report.wasDownsampled, isFalse);
      expect(
        output.report.resolvedSamplingStrategy,
        ChartResolvedSamplingStrategy.none,
      );
      expect(output.report.resolvedSamplingStrategies, [
        ChartResolvedSamplingStrategy.none,
        ChartResolvedSamplingStrategy.none,
      ]);
      expect(output.report.extractionDuration, Duration.zero);
      expect(output.report.windowDuration, Duration.zero);
      expect(output.report.statsDuration, Duration.zero);
      expect(output.report.samplingDuration, Duration.zero);
      expect(output.report.pointBuildDuration, Duration.zero);

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.extractionLookups, 0);
      expect(stats.extractionWrites, 0);
    });

    test('skips automatic result cache for zero-point viewport windows', () {
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(10000, (i) => i.toDouble()),
        ),
      ];

      final first = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 10,
        startIndex: 9000,
        endIndex: 1000,
      );
      final second = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 10,
        startIndex: 9000,
        endIndex: 1000,
      );

      final stats = ChartDataProcessor.processingCacheStats;
      expect(first.report.path, ChartDataProcessingPath.direct);
      expect(second.report.path, ChartDataProcessingPath.direct);
      expect(first.report.cacheEligible, isFalse);
      expect(first.report.extractionCacheEligible, isFalse);
      expect(
        first.report.cacheAdmissionReason,
        ChartDataCacheAdmissionReason.emptyEffectiveWindow,
      );
      expect(
        first.report.extractionCacheAdmissionReason,
        ChartDataCacheAdmissionReason.emptyEffectiveWindow,
      );
      expect(first.report.cacheAdmissionHint, contains('No effective points'));
      expect(
        first.report.extractionCacheAdmissionHint,
        contains('No effective points'),
      );
      expect(
        first.report.cacheRecommendedAction,
        ChartDataCacheRecommendedAction.none,
      );
      expect(
        first.report.extractionCacheRecommendedAction,
        ChartDataCacheRecommendedAction.none,
      );
      expect(first.report.effectiveDataPointCount, 0);
      expect(first.report.outputPointCount, 0);
      expect(stats.lookups, 0);
      expect(stats.writes, 0);
      expect(stats.size, 0);
      expect(stats.extractionLookups, 0);
    });

    test('allows forced result caching for zero-point viewport windows', () {
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(10000, (i) => i.toDouble()),
        ),
      ];

      final first = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 10,
        startIndex: 9000,
        endIndex: 1000,
        useCache: true,
      );
      final second = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 10,
        startIndex: 9000,
        endIndex: 1000,
        useCache: true,
      );

      final stats = ChartDataProcessor.processingCacheStats;
      expect(first.report.path, ChartDataProcessingPath.cacheMiss);
      expect(second.report.path, ChartDataProcessingPath.cacheHit);
      expect(first.report.cacheEligible, isTrue);
      expect(
        first.report.cacheAdmissionReason,
        ChartDataCacheAdmissionReason.forcedOn,
      );
      expect(first.report.extractionCacheEligible, isFalse);
      expect(
        first.report.extractionCacheAdmissionReason,
        ChartDataCacheAdmissionReason.emptyEffectiveWindow,
      );
      expect(first.result.processed.single.sampledValues, isEmpty);
      expect(second.result.processed.single.sampledValues, isEmpty);
      expect(stats.misses, 1);
      expect(stats.hits, 1);
      expect(stats.writes, 1);
      expect(stats.size, 1);
      expect(stats.extractionLookups, 0);
    });

    test('preserves source indices when invalid values are skipped', () {
      final result = ChartDataProcessor.process(
        [
          Series(
            type: ChartType.line,
            data: const [
              0,
              'bad',
              2,
              {'ignored': true},
              4,
            ],
          ),
        ],
        renderThreshold: 100,
        useCache: false,
      );

      expect(result.processed.single.sampledValues, [0, 2, 4]);
      expect(result.processed.single.sourceIndices, [0, 2, 4]);
      expect(result.processed.single.points.map((point) => point.x), [0, 2, 4]);
    });

    test('does not snap sparse viewport windows to previous valid points', () {
      final result = ChartDataProcessor.processWithReport(
        [
          Series(
            type: ChartType.line,
            data: const [
              10,
              'bad',
              {'ignored': true},
              40,
            ],
          ),
        ],
        renderThreshold: 100,
        startIndex: 1,
        endIndex: 2,
        useCache: false,
      );

      expect(result.result.processed.single.sampledValues, isEmpty);
      expect(result.result.processed.single.sourceIndices, isEmpty);
      expect(result.result.processed.single.points, isEmpty);
      expect(result.result.processed.single.stats.count, 0);
      expect(result.report.outputPointCount, 0);

      final trailingWindow = ChartDataProcessor.process(
        [
          Series(
            type: ChartType.line,
            data: const [
              10,
              'bad',
              {'ignored': true},
              40,
            ],
          ),
        ],
        renderThreshold: 100,
        startIndex: 2,
        endIndex: 3,
        useCache: false,
      );

      expect(trailingWindow.processed.single.sampledValues, [40]);
      expect(trailingWindow.processed.single.sourceIndices, [3]);
      expect(trailingWindow.processed.single.points.single.x, 3);
    });

    test('windows large sparse series by source-index bounds', () {
      final data = List<dynamic>.filled(10000, 'bad');
      data[100] = 10;
      data[5000] = 50;
      data[9999] = 99;

      final emptyGap = ChartDataProcessor.process(
        [Series(type: ChartType.line, data: data)],
        renderThreshold: 100,
        startIndex: 101,
        endIndex: 4999,
        useCache: false,
      );

      expect(emptyGap.processed.single.sampledValues, isEmpty);
      expect(emptyGap.processed.single.sourceIndices, isEmpty);

      final bounded = ChartDataProcessor.process(
        [Series(type: ChartType.line, data: data)],
        renderThreshold: 100,
        startIndex: 100,
        endIndex: 5000,
        useCache: false,
      );

      expect(bounded.processed.single.sampledValues, [10, 50]);
      expect(bounded.processed.single.sourceIndices, [100, 5000]);

      final trailing = ChartDataProcessor.process(
        [Series(type: ChartType.line, data: data)],
        renderThreshold: 100,
        startIndex: 5001,
        endIndex: 9999,
        useCache: false,
      );

      expect(trailing.processed.single.sampledValues, [99]);
      expect(trailing.processed.single.sourceIndices, [9999]);
    });

    test('downsamples viewport windows with original source indices', () {
      final output = ChartDataProcessor.processWithReport(
        [
          Series(
            type: ChartType.line,
            data: List.generate(1000, (i) => i.toDouble()),
          ),
        ],
        renderThreshold: 10,
        samplingStrategy: SamplingStrategy.nth,
        startIndex: 100,
        endIndex: 199,
        useCache: false,
      );

      final processed = output.result.processed.single;
      expect(processed.sampledValues.first, 100);
      expect(processed.sampledValues.last, 199);
      expect(processed.sourceIndices.first, 100);
      expect(processed.sourceIndices.last, 199);
      expect(processed.points.first.x, 100);
      expect(processed.points.last.x, 199);
      expect(processed.points.map((point) => point.y), processed.sampledValues);
      expect(output.report.effectiveDataPointCount, 100);
      expect(output.report.outputPointCount, 10);
      expect(output.report.wasDownsampled, isTrue);
      expect(output.report.reducedPointCount, 90);
      expect(
        output.report.resolvedSamplingStrategy,
        ChartResolvedSamplingStrategy.nth,
      );
      expect(output.report.resolvedSamplingStrategies, [
        ChartResolvedSamplingStrategy.nth,
      ]);
      expect(output.report.samplingOutputRatio, closeTo(0.10, 0.0001));
      expect(output.report.samplingReductionRatio, closeTo(0.90, 0.0001));
      expect(output.report.performanceSummary.wasDownsampled, isTrue);
      expect(
        output.report.performanceSummary.resolvedSamplingStrategy,
        ChartResolvedSamplingStrategy.nth,
      );
      expect(output.report.performanceSummary.reducedPointCount, 90);
      expect(
        output.report.performanceSummary.samplingReductionRatio,
        closeTo(0.90, 0.0001),
      );

      final json = output.report.toJson();
      expect(json['wasDownsampled'], isTrue);
      expect(json['reducedPointCount'], 90);
      expect(json['samplingStrategy'], 'nth');
      expect(json['resolvedSamplingStrategy'], 'nth');
      expect(json['resolvedSamplingStrategies'], ['nth']);
      expect(json['samplingOutputRatio'], closeTo(0.10, 0.0001));
      expect(json['samplingReductionRatio'], closeTo(0.90, 0.0001));
      expect(
        (json['performanceSummary'] as Map<String, dynamic>)['wasDownsampled'],
        isTrue,
      );
      expect(
        (json['performanceSummary']
            as Map<String, dynamic>)['resolvedSamplingStrategy'],
        'nth',
      );
    });

    test('reports resolved auto sampling strategy diagnostics', () {
      final series = [
        Series(
          type: ChartType.line,
          name: 'Small',
          data: List.generate(20, (i) => i.toDouble()),
        ),
        Series(
          type: ChartType.line,
          name: 'LTTB',
          data: List.generate(1000, (i) => i.toDouble()),
        ),
        Series(
          type: ChartType.line,
          name: 'MinMax',
          data: List.generate(6000, (i) => i.toDouble()),
        ),
        Series(
          type: ChartType.line,
          name: 'Nth',
          data: List.generate(51000, (i) => i.toDouble()),
        ),
      ];

      final first = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 100,
        useCache: true,
      );
      final second = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 100,
        useCache: true,
      );

      expect(first.report.cacheHit, isFalse);
      expect(second.report.cacheHit, isTrue);
      expect(first.report.samplingStrategy, isNull);
      expect(
        first.report.resolvedSamplingStrategy,
        ChartResolvedSamplingStrategy.mixed,
      );
      expect(first.report.resolvedSamplingStrategies, [
        ChartResolvedSamplingStrategy.none,
        ChartResolvedSamplingStrategy.lttb,
        ChartResolvedSamplingStrategy.minMax,
        ChartResolvedSamplingStrategy.nth,
      ]);
      expect(
        second.report.resolvedSamplingStrategies,
        first.report.resolvedSamplingStrategies,
      );
      expect(
        first.report.performanceSummary.resolvedSamplingStrategy,
        ChartResolvedSamplingStrategy.mixed,
      );

      final json = first.report.toJson();
      expect(json['samplingStrategy'], 'auto');
      expect(json['resolvedSamplingStrategy'], 'mixed');
      expect(json['resolvedSamplingStrategies'], [
        'none',
        'lttb',
        'minMax',
        'nth',
      ]);
      expect(
        (json['performanceSummary']
            as Map<String, dynamic>)['resolvedSamplingStrategies'],
        ['none', 'lttb', 'minMax', 'nth'],
      );
    });

    test('normalizes unsafe render thresholds for sampling and cache keys', () {
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => i.toDouble()),
        ),
      ];

      final first = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 0,
        samplingStrategy: SamplingStrategy.minMax,
        useCache: true,
      );
      final second = ChartDataProcessor.processWithReport(
        series,
        renderThreshold: 1,
        samplingStrategy: SamplingStrategy.minMax,
        useCache: true,
      );

      expect(first.report.renderThreshold, 2);
      expect(second.report.renderThreshold, 2);
      expect(first.result.processed.single.sampledValues, [0, 999]);
      expect(second.report.cacheHit, isTrue);
      expect(ChartDataProcessor.processingCacheStats.hits, 1);
    });

    test('evicts least recently used entries when capacity is exceeded', () {
      ChartDataProcessor.configureProcessingCache(maxEntries: 2);

      List<Series> makeSeries(int offset) => [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => (i + offset).toDouble()),
        ),
      ];

      ChartDataProcessor.process(makeSeries(0), renderThreshold: 50);
      ChartDataProcessor.process(makeSeries(1000), renderThreshold: 50);
      ChartDataProcessor.process(makeSeries(2000), renderThreshold: 50);

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.size, 2);
      expect(stats.evictions, 1);
    });

    test('evicts least recently used entries when byte budget is exceeded', () {
      ChartDataProcessor.configureProcessingCache(maxEntries: 10);

      List<Series> makeSeries(int offset) => [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => (i + offset).toDouble()),
        ),
      ];

      ChartDataProcessor.process(
        makeSeries(0),
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
      );
      final firstStats = ChartDataProcessor.processingCacheStats;
      expect(firstStats.currentBytes, greaterThan(0));
      expect(firstStats.largestEntryBytes, firstStats.currentBytes);

      ChartDataProcessor.configureProcessingCache(
        maxBytes: firstStats.currentBytes + 1,
      );
      ChartDataProcessor.process(
        makeSeries(1000),
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
      );

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.size, 1);
      expect(stats.currentBytes, lessThanOrEqualTo(stats.maxBytes));
      expect(stats.evictions, 1);
      expect(stats.evictedBytes, firstStats.currentBytes);
      expect(stats.largestEntryBytes, stats.currentBytes);
      expect(stats.toJson()['currentBytes'], stats.currentBytes);
      expect(stats.toJson()['evictedBytes'], stats.evictedBytes);
    });

    test('skips caching entries larger than the byte budget', () {
      ChartDataProcessor.configureProcessingCache(
        maxEntries: 10,
        maxBytes: 1024,
      );
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => i.toDouble()),
        ),
      ];

      ChartDataProcessor.process(
        series,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
      );
      ChartDataProcessor.process(
        series,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
      );

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.size, 0);
      expect(stats.currentBytes, 0);
      expect(stats.misses, 2);
      expect(stats.hits, 0);
      expect(stats.writes, 0);
      expect(stats.skippedWrites, 2);
      expect(stats.toJson()['skippedWrites'], 2);
    });

    test('reports processing cache write outcomes directly', () {
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => i.toDouble()),
        ),
      ];
      final result = ChartDataProcessor.process(
        series,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        useCache: false,
      );

      final rejected = ChartDataProcessor.writeProcessingCacheWithReport(
        series,
        result,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        useCache: false,
      );
      expect(rejected.written, isFalse);
      expect(rejected.reason, ChartDataCacheWriteReason.admissionRejected);
      expect(rejected.admissionReason, ChartDataCacheAdmissionReason.forcedOff);
      expect(rejected.estimatedBytes, 0);
      expect(rejected.toJson()['reason'], 'admissionRejected');
      expect(rejected.toJson()['admissionReason'], 'forcedOff');

      final written = ChartDataProcessor.writeProcessingCacheWithReport(
        series,
        result,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        useCache: true,
      );
      expect(written.written, isTrue);
      expect(written.reason, ChartDataCacheWriteReason.written);
      expect(written.admissionReason, ChartDataCacheAdmissionReason.forcedOn);
      expect(written.estimatedBytes, greaterThan(0));
      expect(
        written.maxBytes,
        ChartDataProcessor.processingCacheStats.maxBytes,
      );
      expect(written.toJson()['written'], isTrue);
      expect(written.toJson()['reason'], 'written');

      final cached = ChartDataProcessor.readProcessingCache(
        series,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        useCache: true,
      );
      expect(cached, isNotNull);
      expect(
        cached!.processed.single.sampledValues,
        result.processed.single.sampledValues,
      );
    });

    test('reports processing cache write entries over byte budget', () {
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => i.toDouble()),
        ),
      ];
      final result = ChartDataProcessor.process(
        series,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        useCache: false,
      );

      ChartDataProcessor.configureProcessingCache(maxBytes: 1);
      final report = ChartDataProcessor.writeProcessingCacheWithReport(
        series,
        result,
        renderThreshold: 100,
        samplingStrategy: SamplingStrategy.nth,
        useCache: true,
      );

      expect(report.written, isFalse);
      expect(report.reason, ChartDataCacheWriteReason.entryExceedsByteCapacity);
      expect(report.admissionReason, ChartDataCacheAdmissionReason.forcedOn);
      expect(report.estimatedBytes, greaterThan(1));
      expect(report.maxBytes, 1);
      expect(report.toJson()['reason'], 'entryExceedsByteCapacity');

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.size, 0);
      expect(stats.writes, 0);
      expect(stats.skippedWrites, 1);
    });

    test('releases extraction cache memory when disabled', () {
      final series = [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => i.toDouble()),
        ),
      ];

      ChartDataProcessor.process(
        series,
        renderThreshold: 100,
        startIndex: 0,
        endIndex: 99,
        useCache: true,
      );

      final before = ChartDataProcessor.processingCacheStats;
      expect(before.extractionSize, 1);
      expect(before.extractionCurrentBytes, greaterThan(0));

      ChartDataProcessor.configureProcessingCache(
        extractionCacheEnabled: false,
      );

      final after = ChartDataProcessor.processingCacheStats;
      expect(after.extractionCacheEnabled, isFalse);
      expect(after.extractionSize, 0);
      expect(after.extractionCurrentBytes, 0);
      expect(after.extractionWrites, before.extractionWrites);
    });

    test('prunes extraction cache when entry and byte caps shrink', () {
      List<Series> makeSeries(int offset) => [
        Series(
          type: ChartType.line,
          data: List.generate(1000, (i) => (i + offset).toDouble()),
        ),
      ];

      ChartDataProcessor.process(
        makeSeries(0),
        renderThreshold: 100,
        startIndex: 0,
        endIndex: 99,
        useCache: true,
      );
      ChartDataProcessor.process(
        makeSeries(1000),
        renderThreshold: 100,
        startIndex: 0,
        endIndex: 99,
        useCache: true,
      );

      expect(ChartDataProcessor.processingCacheStats.extractionSize, 2);

      ChartDataProcessor.configureProcessingCache(maxExtractionEntries: 1);
      final entryPruned = ChartDataProcessor.processingCacheStats;
      expect(entryPruned.extractionSize, 1);
      expect(entryPruned.extractionEvictions, 1);

      ChartDataProcessor.configureProcessingCache(maxExtractionBytes: 1);
      final bytePruned = ChartDataProcessor.processingCacheStats;
      expect(bytePruned.extractionSize, 0);
      expect(bytePruned.extractionCurrentBytes, 0);
      expect(bytePruned.extractionEvictions, 2);
    });

    test('prunes extraction cache when min point threshold increases', () {
      ChartDataProcessor.process(
        [
          Series(
            type: ChartType.line,
            data: List.generate(1000, (i) => i.toDouble()),
          ),
        ],
        renderThreshold: 100,
        startIndex: 0,
        endIndex: 99,
        useCache: true,
      );

      expect(ChartDataProcessor.processingCacheStats.extractionSize, 1);

      ChartDataProcessor.configureProcessingCache(
        minExtractionPointCount: 1001,
      );

      final stats = ChartDataProcessor.processingCacheStats;
      expect(stats.extractionSize, 0);
      expect(stats.extractionCurrentBytes, 0);
      expect(stats.extractionEvictions, 1);
      expect(stats.minExtractionPointCount, 1001);
    });
  });
}
