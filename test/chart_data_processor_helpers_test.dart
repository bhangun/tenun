import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/core/chart_data_processor.dart';
import 'package:tenun/core/chart_type.dart';
import 'package:tenun/core/series.dart';

void main() {
  group('ChartDataProcessor numeric helpers', () {
    test('SeriesStats percentiles and deviation ignore unsafe values', () {
      final stats = SeriesStats(
        min: 10,
        max: 40,
        sum: 100,
        avg: double.nan,
        count: 6,
        values: [double.nan, 10, 20, double.infinity, 30, 40],
      );

      expect(stats.percentile(-25), 10);
      expect(stats.percentile(25), closeTo(17.5, 0.0001));
      expect(stats.percentile(double.nan), 25);
      expect(stats.percentile(double.infinity), 40);
      expect(stats.percentile(double.negativeInfinity), 10);
      expect(stats.q1, closeTo(17.5, 0.0001));
      expect(stats.median, 25);
      expect(stats.q3, closeTo(32.5, 0.0001));
      expect(stats.iqr, 15);
      expect(stats.stdDev, closeTo(11.1803, 0.0001));

      const unsafeOnly = SeriesStats(
        min: 0,
        max: 0,
        sum: 0,
        avg: double.nan,
        count: 2,
        values: [double.nan, double.infinity],
      );
      expect(unsafeOnly.percentile(50), 0);
      expect(unsafeOnly.stdDev, 0);
    });

    test('normalize returns deterministic finite fallbacks', () {
      expect(ChartDataProcessor.normalize(5, 0, 10, 0, 100), 50);
      expect(ChartDataProcessor.normalize(5, 5, 5, 0, 100), 0);
      expect(ChartDataProcessor.normalize(double.nan, 0, 10, 0, 100), 50);
      expect(
        ChartDataProcessor.normalize(5, double.nan, double.infinity, 0, 100),
        50,
      );
      expect(
        ChartDataProcessor.normalize(5, 0, 10, double.nan, double.infinity),
        0,
      );
    });

    test('niceYTicks tolerates invalid domains and tick counts', () {
      expect(ChartDataProcessor.niceYTicks(double.nan, double.infinity), [
        0,
        0,
        0,
        0,
        0,
      ]);
      expect(ChartDataProcessor.niceYTicks(10, 0, tickCount: 3), [0, 5, 10]);
      expect(ChartDataProcessor.niceYTicks(5, 5, tickCount: 3), [5, 5, 5]);
      expect(ChartDataProcessor.niceYTicks(0, 10, tickCount: 1), [5]);
      expect(ChartDataProcessor.niceYTicks(0, 10, tickCount: 0), isEmpty);
      expect(
        ChartDataProcessor.niceYTicks(0, 10, tickCount: 2000),
        hasLength(1000),
      );
    });

    test('fiveNumberSummary ignores non-finite values', () {
      final summary = ChartDataProcessor.fiveNumberSummary([
        double.nan,
        10,
        20,
        double.infinity,
        30,
        double.negativeInfinity,
      ]);

      expect(summary.min, 10);
      expect(summary.q1, 15);
      expect(summary.median, 20);
      expect(summary.q3, 25);
      expect(summary.max, 30);
      expect(
        ChartDataProcessor.fiveNumberSummary([double.nan, double.infinity]),
        (min: 0, q1: 0, median: 0, q3: 0, max: 0),
      );
    });

    test('histogram ignores non-finite values and normalizes ranges', () {
      final bins = ChartDataProcessor.histogram([
        double.nan,
        1,
        2,
        3,
        double.infinity,
      ], binCount: 2);

      expect(bins, hasLength(2));
      expect(bins.map((bin) => bin.count), [1, 2]);
      expect(bins.first.start, 1);
      expect(bins.last.end, 3);

      final reversed = ChartDataProcessor.histogram(
        [0, 5, 10],
        binCount: 2,
        forcedMin: 10,
        forcedMax: 0,
      );
      expect(reversed.map((bin) => bin.count), [1, 2]);
      expect(ChartDataProcessor.histogram([1, 2, 3], binCount: 0), isEmpty);
      expect(ChartDataProcessor.histogram([double.nan]), isEmpty);
      expect(
        ChartDataProcessor.histogram(
          [1, 2],
          binCount: 5000,
          forcedMin: double.nan,
          forcedMax: double.infinity,
        ),
        hasLength(1000),
      );
    });

    test('stacked helpers treat non-finite values as absent', () {
      final stacked = ChartDataProcessor.computeStackedValues([
        Series(type: ChartType.bar, data: [1, double.nan, 3]),
        Series(type: ChartType.bar, data: [2, double.infinity, -1]),
      ]);

      expect(stacked, [
        [1, 0, 3],
        [3, 0, -1],
      ]);
      expect(
        ChartDataProcessor.maxStackedValue([
          Series(type: ChartType.bar, data: [double.nan, double.infinity]),
        ]),
        0,
      );
    });

    test('stacked helpers read structured JSON row values consistently', () {
      final stacked = ChartDataProcessor.computeStackedValues([
        Series(
          type: ChartType.bar,
          data: const [
            {'value': '10'},
            ['North', '20'],
            [2, -5],
            {'ignored': true},
          ],
        ),
        Series(
          type: ChartType.bar,
          data: const [
            {'y': 7},
            [1, -3],
            {'amount': '4'},
            '6',
          ],
        ),
      ]);

      expect(stacked, [
        [10, 20, -5, 0],
        [17, -3, 4, 6],
      ]);
      expect(
        ChartDataProcessor.maxStackedValue([
          Series(
            type: ChartType.bar,
            data: const [
              {'value': '10'},
              ['North', '20'],
              [2, -5],
            ],
          ),
          Series(
            type: ChartType.bar,
            data: const [
              {'y': 7},
              [1, -3],
              {'amount': '4'},
            ],
          ),
        ]),
        20,
      );
    });
  });
}
