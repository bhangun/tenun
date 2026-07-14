import 'package:flutter_test/flutter_test.dart';
import 'package:tenun_core/core/data_sampler.dart';

void main() {
  group('Data sampler edge thresholds', () {
    final points = List<DataPoint>.generate(
      5,
      (index) => DataPoint(index.toDouble(), (index * index).toDouble()),
    );
    final values = points.map((point) => point.y).toList(growable: false);

    test('DataPoint compares by value for diagnostics and assertions', () {
      expect(const DataPoint(1, 2), const DataPoint(1, 2));
      expect(const DataPoint(1, 2), isNot(const DataPoint(2, 1)));
      final unique = <DataPoint>{};
      unique.add(const DataPoint(1, 2));
      unique.add(const DataPoint(1, 2));
      expect(unique, hasLength(1));
      expect(const DataPoint(1, 2).toString(), 'DataPoint(1.0, 2.0)');
    });

    test('DataPoint samplers respect zero, one, and two point thresholds', () {
      for (final sample in <List<DataPoint> Function(int)>[
        (threshold) => LTTBSampler.sample(points, threshold),
        (threshold) => MinMaxSampler.sample(points, threshold),
        (threshold) => NthPointSampler.sample(points, threshold),
        (threshold) => DataSampler.auto(points, threshold),
      ]) {
        expect(sample(0), isEmpty);
        expect(sample(1).map((point) => point.x), [0]);
        expect(sample(2).map((point) => point.x), [0, 4]);
      }
    });

    test('DataPoint samplers return full data when threshold covers input', () {
      for (final sample in <List<DataPoint> Function(int)>[
        (threshold) => LTTBSampler.sample(points, threshold),
        (threshold) => MinMaxSampler.sample(points, threshold),
        (threshold) => NthPointSampler.sample(points, threshold),
        (threshold) => DataSampler.auto(points, threshold),
      ]) {
        expect(sample(5).map((point) => point.x), [0, 1, 2, 3, 4]);
        expect(sample(10).map((point) => point.x), [0, 1, 2, 3, 4]);
      }
    });

    test('DoubleListSampler value APIs respect tiny thresholds', () {
      for (final sample in <List<double> Function(int)>[
        (threshold) => DoubleListSampler.lttb(values, threshold),
        (threshold) => DoubleListSampler.minMax(values, threshold),
        (threshold) => DoubleListSampler.nth(values, threshold),
        (threshold) => DoubleListSampler.auto(values, threshold),
      ]) {
        expect(sample(0), isEmpty);
        expect(sample(1), [0]);
        expect(sample(2), [0, 16]);
      }
    });

    test('DoubleListSampler index APIs return full data when unsampled', () {
      for (final sample in <List<int> Function(int)>[
        (threshold) => DoubleListSampler.lttbIndices(values, threshold),
        (threshold) => DoubleListSampler.minMaxIndices(values, threshold),
        (threshold) => DoubleListSampler.nthIndices(values, threshold),
        (threshold) => DoubleListSampler.autoIndices(values, threshold),
      ]) {
        expect(sample(5), [0, 1, 2, 3, 4]);
        expect(sample(10), [0, 1, 2, 3, 4]);
      }
    });

    test(
      'DoubleListSampler index APIs respect zero, one, and two thresholds',
      () {
        for (final sample in <List<int> Function(int)>[
          (threshold) => DoubleListSampler.lttbIndices(values, threshold),
          (threshold) => DoubleListSampler.minMaxIndices(values, threshold),
          (threshold) => DoubleListSampler.nthIndices(values, threshold),
          (threshold) => DoubleListSampler.autoIndices(values, threshold),
        ]) {
          expect(sample(0), isEmpty);
          expect(sample(1), [0]);
          expect(sample(2), [0, 4]);
        }
      },
    );

    test('samplers hard-cap odd render thresholds while keeping endpoints', () {
      final largeValues = List<double>.generate(
        6001,
        (index) => index.isEven ? index.toDouble() : -index.toDouble(),
      );
      final largePoints = [
        for (var i = 0; i < largeValues.length; i++)
          DataPoint(i.toDouble(), largeValues[i]),
      ];

      final sampledPoints = MinMaxSampler.sample(largePoints, 9);
      final sampledValues = DoubleListSampler.minMax(largeValues, 9);
      final nthPoints = NthPointSampler.sample(largePoints, 9);
      final nthValues = DoubleListSampler.nth(largeValues, 9);
      final autoPoints = DataSampler.auto(largePoints, 9);
      final autoValues = DoubleListSampler.auto(largeValues, 9);

      for (final sample in [
        sampledPoints.map((point) => point.y).toList(),
        sampledValues,
        nthPoints.map((point) => point.y).toList(),
        nthValues,
        autoPoints.map((point) => point.y).toList(),
        autoValues,
      ]) {
        expect(sample.length <= 9, isTrue);
        expect(sample.first, largeValues.first);
        expect(sample.last, largeValues.last);
      }
    });

    test('DataSampler.auto matches direct finite strategy outputs', () {
      final values = List<DataPoint>.generate(257, (index) {
        final y = index.isEven ? index.toDouble() : -index.toDouble();
        return DataPoint(index.toDouble(), y);
      });

      expect(
        DataSampler.auto(values, 17, forceStrategy: SamplingStrategy.lttb),
        LTTBSampler.sample(values, 17),
      );
      expect(
        DataSampler.auto(values, 17, forceStrategy: SamplingStrategy.minMax),
        MinMaxSampler.sample(values, 17),
      );
      expect(
        DataSampler.auto(values, 17, forceStrategy: SamplingStrategy.nth),
        NthPointSampler.sample(values, 17),
      );
    });

    test('auto strategy selection is centralized and forceable', () {
      expect(
        DoubleListSampler.resolveStrategyForLength(0),
        SamplingStrategy.lttb,
      );
      expect(
        DoubleListSampler.resolveStrategyForLength(5000),
        SamplingStrategy.lttb,
      );
      expect(
        DoubleListSampler.resolveStrategyForLength(5001),
        SamplingStrategy.minMax,
      );
      expect(
        DoubleListSampler.resolveStrategyForLength(50000),
        SamplingStrategy.minMax,
      );
      expect(
        DoubleListSampler.resolveStrategyForLength(50001),
        SamplingStrategy.nth,
      );
      expect(
        DoubleListSampler.resolveStrategyForLength(
          50001,
          forceStrategy: SamplingStrategy.minMax,
        ),
        SamplingStrategy.minMax,
      );

      final lttbValues = List<double>.generate(5000, (i) => i.toDouble());
      final minMaxValues = List<double>.generate(5001, (i) => i.toDouble());
      final nthValues = List<double>.generate(50001, (i) => i.toDouble());
      expect(
        DoubleListSampler.autoIndices(lttbValues, 37),
        DoubleListSampler.lttbIndices(lttbValues, 37),
      );
      expect(
        DoubleListSampler.autoIndices(minMaxValues, 37),
        DoubleListSampler.minMaxIndices(minMaxValues, 37),
      );
      expect(
        DoubleListSampler.autoIndices(nthValues, 37),
        DoubleListSampler.nthIndices(nthValues, 37),
      );
    });

    test('samplers drop non-finite values while keeping source positions', () {
      final mixedValues = <double>[
        double.nan,
        1,
        double.infinity,
        2,
        3,
        double.negativeInfinity,
        4,
      ];
      final mixedPoints = [
        for (var i = 0; i < mixedValues.length; i++)
          DataPoint(i.toDouble(), mixedValues[i]),
      ];

      expect(
        DataSampler.fromDoubles(mixedValues).map((point) => (point.x, point.y)),
        [(1.0, 1.0), (3.0, 2.0), (4.0, 3.0), (6.0, 4.0)],
      );

      for (final sample in <List<double> Function(int)>[
        (threshold) => DoubleListSampler.lttb(mixedValues, threshold),
        (threshold) => DoubleListSampler.minMax(mixedValues, threshold),
        (threshold) => DoubleListSampler.nth(mixedValues, threshold),
        (threshold) => DoubleListSampler.auto(mixedValues, threshold),
      ]) {
        expect(sample(10), [1, 2, 3, 4]);
        expect(sample(2), [1, 4]);
      }

      for (final sample in <List<int> Function(int)>[
        (threshold) => DoubleListSampler.lttbIndices(mixedValues, threshold),
        (threshold) => DoubleListSampler.minMaxIndices(mixedValues, threshold),
        (threshold) => DoubleListSampler.nthIndices(mixedValues, threshold),
        (threshold) => DoubleListSampler.autoIndices(mixedValues, threshold),
      ]) {
        expect(sample(10), [1, 3, 4, 6]);
        expect(sample(2), [1, 6]);
      }

      for (final sample in <List<DataPoint> Function(int)>[
        (threshold) => LTTBSampler.sample(mixedPoints, threshold),
        (threshold) => MinMaxSampler.sample(mixedPoints, threshold),
        (threshold) => NthPointSampler.sample(mixedPoints, threshold),
        (threshold) => DataSampler.auto(mixedPoints, threshold),
      ]) {
        expect(sample(10).map((point) => point.x), [1, 3, 4, 6]);
        expect(sample(10).map((point) => point.y), [1, 2, 3, 4]);
        expect(sample(2).map((point) => point.x), [1, 6]);
        expect(sample(2).map((point) => point.y), [1, 4]);
      }
    });

    test(
      'index samplers keep ordered unique source indices under threshold',
      () {
        final values = List<double>.generate(257, (index) {
          if (index == 0 || index == 256 || index % 53 == 0) return double.nan;
          if (index % 47 == 0) return double.infinity;
          return index.isEven ? index.toDouble() : -index.toDouble();
        });

        for (final threshold in [3, 7, 11, 29]) {
          for (final sample in <List<int> Function()>[
            () => DoubleListSampler.lttbIndices(values, threshold),
            () => DoubleListSampler.minMaxIndices(values, threshold),
            () => DoubleListSampler.nthIndices(values, threshold),
            () => DoubleListSampler.autoIndices(values, threshold),
          ]) {
            final indices = sample();
            expect(indices.length <= threshold, isTrue);
            expect(indices.first, 1);
            expect(indices.last, 255);
            _expectStrictlyIncreasing(indices);
            expect(
              indices.map((index) => values[index].isFinite),
              everyElement(isTrue),
            );
          }
        }
      },
    );

    test(
      'raw LTTB sampling skips non-finite values and preserves source x',
      () {
        final values = <double>[
          double.nan,
          1,
          double.infinity,
          2,
          3,
          double.negativeInfinity,
          4,
        ];

        final full = LTTBSampler.sampleRaw(values, 10);
        expect(full.map((point) => point.x), [1, 3, 4, 6]);
        expect(full.map((point) => point.y), [1, 2, 3, 4]);

        final endpoints = LTTBSampler.sampleRaw(values, 2);
        expect(endpoints.map((point) => point.x), [1, 6]);
        expect(endpoints.map((point) => point.y), [1, 4]);
      },
    );
  });
}

void _expectStrictlyIncreasing(List<int> values) {
  for (var i = 1; i < values.length; i++) {
    expect(values[i], greaterThan(values[i - 1]));
  }
}
