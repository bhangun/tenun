// Efficient data sampling utilities for large datasets.
//
// Provides:
//  - [LTTBSampler]       — Largest-Triangle-Three-Buckets (visually-accurate)
//  - [MinMaxSampler]     — Keeps local min/max per bucket (good for candlestick / precise peaks)
//  - [NthPointSampler]   — Fast uniform decimation for non-critical views
//  - [DoubleListSampler] — Operates directly on `List<double>` — avoids DataPoint allocation
//
// All samplers work on `List<DataPoint>` or raw `List<double>`.

import 'chart_data_value_reader.dart';

// ---------------------------------------------------------------------------
// DataPoint — 2D data point used across all samplers
// ---------------------------------------------------------------------------

/// A 2-D data point used across all samplers.
class DataPoint {
  final double x;
  final double y;
  const DataPoint(this.x, this.y);

  bool get isFinite => x.isFinite && y.isFinite;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'DataPoint($x, $y)';
}

// ---------------------------------------------------------------------------
// LTTB — Largest-Triangle-Three-Buckets
// Reference: Sveinn Steinarsson (2013) https://skemman.is/handle/1946/15343
//
// BUG FIX (v2): The original nextRangeStart was incorrectly set to rangeStart
// (same bucket). It must point to the START of the NEXT bucket so the
// reference point (avgX/avgY) is computed from the correct future window.
// ---------------------------------------------------------------------------

class LTTBSampler {
  /// Down-sample [data] to at most [threshold] points using the LTTB algorithm.
  ///
  /// Returns the original list when `data.length <= threshold` and all points
  /// are finite. Non-finite points are dropped before sampling.
  static List<DataPoint> sample(List<DataPoint> data, int threshold) {
    final finiteData = _finiteDataPoints(data);
    return _sampleFinite(finiteData, threshold);
  }

  static List<DataPoint> _sampleFinite(
    List<DataPoint> finiteData,
    int threshold,
  ) {
    final int length = finiteData.length;
    if (threshold >= length || threshold <= 2) {
      return _edgePoints(finiteData, threshold);
    }

    final List<int> sampled = List.filled(threshold, 0);
    // Always include the first point.
    sampled[0] = 0;

    final double bucketSize = (length - 2) / (threshold - 2);
    int a = 0; // Previously selected point index.

    for (int i = 0; i < threshold - 2; i++) {
      // Current bucket range.
      final int rangeStart = ((i + 1) * bucketSize + 1).floor();
      final int rangeEnd = (((i + 2) * bucketSize + 1).floor()).clamp(
        0,
        length - 1,
      );

      // FIXED: next bucket starts at rangeEnd+1 (not rangeStart).
      final int nextRangeStart = rangeEnd;
      final int nextRangeEnd = (((i + 3) * bucketSize + 1).floor()).clamp(
        0,
        length,
      );

      // Average point of the NEXT bucket used as look-ahead reference.
      double avgX = 0, avgY = 0;
      int avgCount = 0;
      for (int j = nextRangeStart; j < nextRangeEnd; j++) {
        avgX += finiteData[j].x;
        avgY += finiteData[j].y;
        avgCount++;
      }
      if (avgCount > 0) {
        avgX /= avgCount;
        avgY /= avgCount;
      }

      // Find the point in the current bucket with the largest triangle area.
      final DataPoint pointA = finiteData[a];
      double maxArea = -1;
      int maxAreaIdx = rangeStart;

      for (int j = rangeStart; j <= rangeEnd; j++) {
        if (j >= length) break;
        final double area =
            ((pointA.x - avgX) * (finiteData[j].y - pointA.y) -
                    (pointA.x - finiteData[j].x) * (avgY - pointA.y))
                .abs() *
            0.5;
        if (area > maxArea) {
          maxArea = area;
          maxAreaIdx = j;
        }
      }

      sampled[i + 1] = maxAreaIdx;
      a = maxAreaIdx;
    }

    // Always include the last point.
    sampled[threshold - 1] = length - 1;
    final indices = _normalizeSampledIndices(
      sampled,
      length: length,
      threshold: threshold,
    );
    return [for (final i in indices) finiteData[i]];
  }

  /// Sample from raw y-values, generating synthetic x = index.
  static List<DataPoint> sampleRaw(List<double> yValues, int threshold) {
    final indices = DoubleListSampler.lttbIndices(yValues, threshold);
    return [for (final i in indices) DataPoint(i.toDouble(), yValues[i])];
  }

  static List<DataPoint> _edgePoints(List<DataPoint> data, int threshold) =>
      _sampleEdgePoints(data, threshold);
}

// ---------------------------------------------------------------------------
// MinMax sampler — retains local peaks and valleys per bucket
// ---------------------------------------------------------------------------

class MinMaxSampler {
  /// Down-sample [data] to at most [threshold] points by keeping local min & max.
  ///
  /// Each bucket contributes local extrema, then the result is compacted when
  /// needed so render budgets remain predictable.
  static List<DataPoint> sample(List<DataPoint> data, int threshold) {
    final finiteData = _finiteDataPoints(data);
    return _sampleFinite(finiteData, threshold);
  }

  static List<DataPoint> _sampleFinite(
    List<DataPoint> finiteData,
    int threshold,
  ) {
    if (threshold >= finiteData.length || threshold <= 2) {
      return _sampleEdgePoints(finiteData, threshold);
    }
    final yValues = List<double>.generate(
      finiteData.length,
      (index) => finiteData[index].y,
      growable: false,
    );
    final indices = DoubleListSampler.minMaxIndices(yValues, threshold);
    return [for (final i in indices) finiteData[i]];
  }
}

// ---------------------------------------------------------------------------
// Nth-point sampler — O(n) uniform decimation
// ---------------------------------------------------------------------------

class NthPointSampler {
  static List<DataPoint> sample(List<DataPoint> data, int threshold) {
    final finiteData = _finiteDataPoints(data);
    return _sampleFinite(finiteData, threshold);
  }

  static List<DataPoint> _sampleFinite(
    List<DataPoint> finiteData,
    int threshold,
  ) {
    if (threshold >= finiteData.length || threshold <= 2) {
      return _sampleEdgePoints(finiteData, threshold);
    }
    final indices = _sampleUniformIndices(finiteData.length, threshold);
    return [for (final i in indices) finiteData[i]];
  }
}

// ---------------------------------------------------------------------------
// DoubleListSampler — operates on raw doubles, avoids DataPoint allocation
// for the 95% case where x = implicit index.
// ---------------------------------------------------------------------------

/// Samples [List<double>] directly, without allocating [DataPoint] objects.
///
/// Use this path inside [ChartDataProcessor] to avoid the:
///   _extractDoubles → DataSampler.fromRaw (re-box) → sample → unbox
/// round-trip that was previously wasting heap.
class DoubleListSampler {
  /// Auto strategy selection shared by every sampler entry point.
  ///
  /// Keeping this policy in one place prevents runtime diagnostics and render
  /// sampling from drifting when thresholds change.
  static SamplingStrategy resolveStrategyForLength(
    int finiteLength, {
    SamplingStrategy? forceStrategy,
  }) {
    if (forceStrategy != null) return forceStrategy;
    return finiteLength <= 5000
        ? SamplingStrategy.lttb
        : finiteLength <= 50000
        ? SamplingStrategy.minMax
        : SamplingStrategy.nth;
  }

  /// LTTB on raw doubles. Returns indices of selected points.
  static List<int> lttbIndices(List<double> data, int threshold) {
    final finiteView = _finiteDoubleView(data);
    if (finiteView != null) {
      final indices = _lttbIndicesFinite(finiteView.values, threshold);
      return [for (final i in indices) finiteView.sourceIndices[i]];
    }
    return _lttbIndicesFinite(data, threshold);
  }

  static List<int> _lttbIndicesFinite(List<double> data, int threshold) {
    final int n = data.length;
    if (threshold >= n || threshold <= 2) {
      return _sampleEdgeIndices(n, threshold);
    }

    final List<int> selected = List.filled(threshold, 0);
    selected[0] = 0;

    final double bucketSize = (n - 2) / (threshold - 2);
    int a = 0;

    for (int i = 0; i < threshold - 2; i++) {
      final int rangeStart = ((i + 1) * bucketSize + 1).floor();
      final int rangeEnd = (((i + 2) * bucketSize + 1).floor()).clamp(0, n - 1);

      // FIXED: look-ahead from next bucket.
      final int nextStart = rangeEnd;
      final int nextEnd = (((i + 3) * bucketSize + 1).floor()).clamp(0, n);

      double avgY = 0;
      double avgX = 0;
      int cnt = 0;
      for (int j = nextStart; j < nextEnd; j++) {
        avgX += j;
        avgY += data[j];
        cnt++;
      }
      if (cnt > 0) {
        avgX /= cnt;
        avgY /= cnt;
      }

      final double ax = a.toDouble();
      final double ay = data[a];
      double maxArea = -1;
      int maxIdx = rangeStart;
      for (int j = rangeStart; j <= rangeEnd; j++) {
        if (j >= n) break;
        final double area =
            ((ax - avgX) * (data[j] - ay) - (ax - j) * (avgY - ay)).abs() * 0.5;
        if (area > maxArea) {
          maxArea = area;
          maxIdx = j;
        }
      }
      selected[i + 1] = maxIdx;
      a = maxIdx;
    }
    selected[threshold - 1] = n - 1;
    return _normalizeSampledIndices(selected, length: n, threshold: threshold);
  }

  /// Returns sampled doubles from LTTB indices.
  static List<double> lttb(List<double> data, int threshold) {
    final indices = lttbIndices(data, threshold);
    return [for (final i in indices) data[i]];
  }

  /// Returns sampled doubles keeping local min/max per bucket.
  static List<double> minMax(List<double> data, int threshold) {
    final indices = minMaxIndices(data, threshold);
    return [for (final i in indices) data[i]];
  }

  /// Returns indices sampled with min/max bucket strategy.
  static List<int> minMaxIndices(List<double> data, int threshold) {
    final finiteView = _finiteDoubleView(data);
    if (finiteView != null) {
      final indices = _minMaxIndicesFinite(finiteView.values, threshold);
      return [for (final i in indices) finiteView.sourceIndices[i]];
    }
    return _minMaxIndicesFinite(data, threshold);
  }

  static List<int> _minMaxIndicesFinite(List<double> data, int threshold) {
    final int n = data.length;
    if (threshold >= n || threshold <= 2) {
      return _sampleEdgeIndices(n, threshold);
    }
    final int buckets = (threshold / 2).ceil();
    final double bucketSize = n / buckets;
    final result = <int>[0];
    for (int b = 0; b < buckets; b++) {
      final int start = (b * bucketSize).floor();
      final int end = ((b + 1) * bucketSize).floor().clamp(0, n);
      if (start >= end) continue;
      int minI = start;
      int maxI = start;
      double minV = data[start];
      double maxV = data[start];
      for (int i = start + 1; i < end; i++) {
        final v = data[i];
        if (v < minV) {
          minV = v;
          minI = i;
        }
        if (v > maxV) {
          maxV = v;
          maxI = i;
        }
      }
      if (minI <= maxI) {
        if (result.last != minI) result.add(minI);
        if (result.last != maxI) result.add(maxI);
      } else {
        if (result.last != maxI) result.add(maxI);
        if (result.last != minI) result.add(minI);
      }
      if (result.length >= threshold) break;
    }
    if (result.last != n - 1) result.add(n - 1);
    if (result.length > threshold) {
      final compact = <int>[result.first];
      final step = ((result.length - 1) / (threshold - 1)).ceil();
      for (int i = step; i < result.length - 1; i += step) {
        compact.add(result[i]);
      }
      if (compact.last != result.last) compact.add(result.last);
      return _normalizeSampledIndices(compact, length: n, threshold: threshold);
    }
    return _normalizeSampledIndices(result, length: n, threshold: threshold);
  }

  /// Returns every Nth point.
  static List<double> nth(List<double> data, int threshold) {
    final indices = nthIndices(data, threshold);
    return [for (final i in indices) data[i]];
  }

  /// Returns sampled indices for Nth-point strategy.
  static List<int> nthIndices(List<double> data, int threshold) {
    final finiteView = _finiteDoubleView(data);
    if (finiteView != null) {
      final indices = _nthIndicesFinite(finiteView.values, threshold);
      return [for (final i in indices) finiteView.sourceIndices[i]];
    }
    return _nthIndicesFinite(data, threshold);
  }

  static List<int> _nthIndicesFinite(List<double> data, int threshold) {
    final int n = data.length;
    if (threshold >= n || threshold <= 2) {
      return _sampleEdgeIndices(n, threshold);
    }
    return _sampleUniformIndices(n, threshold);
  }

  /// Auto-selects strategy. Same thresholds as [DataSampler.auto].
  static List<double> auto(
    List<double> data,
    int threshold, {
    SamplingStrategy? forceStrategy,
  }) {
    final indices = autoIndices(data, threshold, forceStrategy: forceStrategy);
    return [for (final i in indices) data[i]];
  }

  static List<int> _autoIndicesFinite(
    List<double> data,
    int threshold, {
    SamplingStrategy? forceStrategy,
  }) {
    if (data.length <= threshold || threshold <= 2) {
      return _sampleEdgeIndices(data.length, threshold);
    }
    final strategy = resolveStrategyForLength(
      data.length,
      forceStrategy: forceStrategy,
    );
    switch (strategy) {
      case SamplingStrategy.lttb:
        return _lttbIndicesFinite(data, threshold);
      case SamplingStrategy.minMax:
        return _minMaxIndicesFinite(data, threshold);
      case SamplingStrategy.nth:
        return _nthIndicesFinite(data, threshold);
    }
  }

  /// Auto-selects strategy and returns sampled indices.
  static List<int> autoIndices(
    List<double> data,
    int threshold, {
    SamplingStrategy? forceStrategy,
  }) {
    final finiteView = _finiteDoubleView(data);
    if (finiteView != null) {
      final indices = _autoIndicesFinite(
        finiteView.values,
        threshold,
        forceStrategy: forceStrategy,
      );
      return [for (final i in indices) finiteView.sourceIndices[i]];
    }
    return _autoIndicesFinite(data, threshold, forceStrategy: forceStrategy);
  }
}

// ---------------------------------------------------------------------------
// SamplingStrategy enum — shared across all samplers
// ---------------------------------------------------------------------------

enum SamplingStrategy { lttb, minMax, nth }

// ---------------------------------------------------------------------------
// DataSampler — convenience wrapper (DataPoint-based API)
// ---------------------------------------------------------------------------

class DataSampler {
  /// Automatically samples [data] to [threshold] points.
  ///
  /// Strategy selection:
  /// - ≤ 5 000 pts → LTTB (best visual accuracy)
  /// - ≤ 50 000 pts → MinMax (fast, keeps peaks)
  /// - > 50 000 pts → Nth-point (fastest)
  static List<DataPoint> auto(
    List<DataPoint> data,
    int threshold, {
    SamplingStrategy? forceStrategy,
  }) {
    final finiteData = _finiteDataPoints(data);
    if (finiteData.length <= threshold || threshold <= 2) {
      return _sampleEdgePoints(finiteData, threshold);
    }

    final strategy = DoubleListSampler.resolveStrategyForLength(
      finiteData.length,
      forceStrategy: forceStrategy,
    );

    switch (strategy) {
      case SamplingStrategy.lttb:
        return LTTBSampler._sampleFinite(finiteData, threshold);
      case SamplingStrategy.minMax:
        return MinMaxSampler._sampleFinite(finiteData, threshold);
      case SamplingStrategy.nth:
        return NthPointSampler._sampleFinite(finiteData, threshold);
    }
  }

  /// Convert raw numeric series data to [DataPoint] list.
  static List<DataPoint> fromRaw(List<dynamic> raw) {
    final List<DataPoint> pts = List.filled(
      raw.length,
      const DataPoint(0, 0),
      growable: false,
    );
    int writeIdx = 0;
    for (int i = 0; i < raw.length; i++) {
      final point = ChartDataValueReader.cartesian(raw[i], i);
      if (point != null) pts[writeIdx++] = DataPoint(point.x, point.y);
    }
    return writeIdx == raw.length ? pts : pts.sublist(0, writeIdx);
  }

  /// Convert [List<double>] to [DataPoint] list with index-based x values,
  /// skipping non-finite values.
  static List<DataPoint> fromDoubles(List<double> values) {
    final points = List<DataPoint>.filled(
      values.length,
      const DataPoint(0, 0),
      growable: false,
    );
    var writeIdx = 0;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (!value.isFinite) continue;
      points[writeIdx++] = DataPoint(i.toDouble(), value);
    }
    return writeIdx == values.length ? points : points.sublist(0, writeIdx);
  }
}

List<DataPoint> _finiteDataPoints(List<DataPoint> data) {
  for (var i = 0; i < data.length; i++) {
    if (data[i].isFinite) continue;
    final output = <DataPoint>[for (var j = 0; j < i; j++) data[j]];
    for (var j = i + 1; j < data.length; j++) {
      final point = data[j];
      if (point.isFinite) output.add(point);
    }
    return output;
  }
  return data;
}

_FiniteDoubleView? _finiteDoubleView(List<double> data) {
  for (var i = 0; i < data.length; i++) {
    if (data[i].isFinite) continue;
    final values = <double>[];
    final sourceIndices = <int>[];
    for (var j = 0; j < i; j++) {
      values.add(data[j]);
      sourceIndices.add(j);
    }
    for (var j = i + 1; j < data.length; j++) {
      final value = data[j];
      if (!value.isFinite) continue;
      values.add(value);
      sourceIndices.add(j);
    }
    return _FiniteDoubleView(values, sourceIndices);
  }
  return null;
}

class _FiniteDoubleView {
  final List<double> values;
  final List<int> sourceIndices;

  const _FiniteDoubleView(this.values, this.sourceIndices);
}

List<DataPoint> _sampleEdgePoints(List<DataPoint> data, int threshold) {
  if (data.isEmpty || threshold <= 0) return const <DataPoint>[];
  if (threshold >= data.length) return data;
  if (threshold == 1) return <DataPoint>[data.first];
  return <DataPoint>[data.first, data.last];
}

List<int> _sampleEdgeIndices(int length, int threshold) {
  if (length <= 0 || threshold <= 0) return const <int>[];
  if (threshold >= length) {
    return List<int>.generate(length, (index) => index, growable: false);
  }
  if (threshold == 1) return const <int>[0];
  return <int>[0, length - 1];
}

List<int> _sampleUniformIndices(int length, int threshold) {
  if (length <= 0 || threshold <= 0) return const <int>[];
  if (threshold >= length || threshold <= 2) {
    return _sampleEdgeIndices(length, threshold);
  }

  final result = <int>[];
  final maxIndex = length - 1;
  final step = maxIndex / (threshold - 1);
  var previous = -1;
  for (var i = 0; i < threshold; i++) {
    final index = (i * step).round().clamp(0, maxIndex);
    if (index == previous) continue;
    result.add(index);
    previous = index;
  }
  if (result.last != maxIndex) {
    if (result.length == threshold) {
      result[result.length - 1] = maxIndex;
    } else {
      result.add(maxIndex);
    }
  }
  return result;
}

List<int> _normalizeSampledIndices(
  List<int> indices, {
  required int length,
  required int threshold,
}) {
  if (length <= 0 || threshold <= 0 || indices.isEmpty) return const <int>[];
  if (threshold >= length) return _sampleEdgeIndices(length, threshold);

  final maxIndex = length - 1;
  final unique = <int>{};
  for (final rawIndex in indices) {
    unique.add(_clampIndex(rawIndex, maxIndex));
  }
  unique.add(0);
  unique.add(maxIndex);

  final ordered = unique.toList(growable: false)..sort();
  if (ordered.length <= threshold) return ordered;
  if (threshold == 1) return const <int>[0];
  if (threshold == 2) return <int>[0, maxIndex];

  final interiorBudget = threshold - 2;
  final interior = ordered.sublist(1, ordered.length - 1);
  final compact = <int>[0];
  if (interior.length <= interiorBudget) {
    compact.addAll(interior);
  } else if (interiorBudget == 1) {
    compact.add(interior[interior.length ~/ 2]);
  } else {
    final lastInteriorIndex = interior.length - 1;
    var previousInteriorIndex = -1;
    for (var i = 0; i < interiorBudget; i++) {
      var interiorIndex = _clampIndex(
        (i * lastInteriorIndex / (interiorBudget - 1)).round(),
        lastInteriorIndex,
      );
      while (interiorIndex <= previousInteriorIndex &&
          interiorIndex < lastInteriorIndex) {
        interiorIndex++;
      }
      if (interiorIndex > previousInteriorIndex) {
        compact.add(interior[interiorIndex]);
        previousInteriorIndex = interiorIndex;
      }
    }
  }
  if (compact.last != maxIndex) compact.add(maxIndex);
  return compact;
}

int _clampIndex(int value, int maxIndex) {
  if (value < 0) return 0;
  if (value > maxIndex) return maxIndex;
  return value;
}
