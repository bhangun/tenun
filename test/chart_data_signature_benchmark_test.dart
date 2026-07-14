import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';
import 'package:tenun_core/tenun_core.dart';

Object? _signatureBenchmarkSink;

void main() {
  group('ChartDataSignature benchmark coverage', () {
    test('reports streamed signature timings for large JSON payloads', () {
      final reports = <_SignatureBenchmarkReport>[];

      for (final pointCount in const [1000, 10000, 50000]) {
        final payload = _buildPayload(pointCount);
        final canonical = _legacySignatureMetrics(payload);
        final streamed = ChartDataSignature.fromJson(payload);

        expect(streamed.hash, canonical.hash);
        expect(streamed.canonicalBytes, canonical.canonicalBytes);
        expect(streamed.dataPointCount, pointCount);

        final iterations = _iterationsFor(pointCount);
        final streamedDuration = _measure(iterations, () {
          final signature = ChartDataSignature.fromJson(payload);
          _signatureBenchmarkSink = signature.hash;
        });
        final legacyDuration = _measure(iterations, () {
          final signature = _legacySignatureMetrics(payload);
          _signatureBenchmarkSink = signature.hash;
        });

        reports.add(
          _SignatureBenchmarkReport(
            pointCount: pointCount,
            canonicalBytes: streamed.canonicalBytes,
            iterations: iterations,
            streamedDuration: streamedDuration,
            legacyDuration: legacyDuration,
          ),
        );
      }

      for (final report in reports) {
        debugPrint(report.toLogLine());
        expect(report.streamedMicrosPerRun, greaterThan(0));
        expect(report.legacyMicrosPerRun, greaterThan(0));
        expect(report.canonicalBytes, greaterThan(0));
      }
      expect(_signatureBenchmarkSink, isNotNull);
    });
  });
}

Map<String, dynamic> _buildPayload(int pointCount) {
  return {
    'type': 'line',
    'title': {'text': 'Signature benchmark $pointCount'},
    'sampling': {'enabled': true, 'threshold': 1200, 'strategy': 'lttb'},
    'xAxis': {'data': List.generate(pointCount, (index) => 'T$index')},
    'series': [
      {
        'type': 'line',
        'name': 'Throughput',
        'data': List.generate(
          pointCount,
          (index) => {
            'x': index,
            'y': (index * 17 % 113) + (index / pointCount),
            'label': 'P${index % 31}',
          },
        ),
      },
    ],
  };
}

_LegacySignatureMetrics _legacySignatureMetrics(Map<String, dynamic> payload) {
  final canonical = canonicalizeChartData(payload);
  return _LegacySignatureMetrics(
    hash: stableChartDataHashCanonical(canonical),
    canonicalBytes: utf8.encode(canonical).length,
  );
}

Duration _measure(int iterations, VoidCallback run) {
  run();
  final stopwatch = Stopwatch()..start();
  for (var index = 0; index < iterations; index++) {
    run();
  }
  stopwatch.stop();
  return stopwatch.elapsed;
}

int _iterationsFor(int pointCount) {
  if (pointCount <= 1000) return 8;
  if (pointCount <= 10000) return 3;
  return 1;
}

class _LegacySignatureMetrics {
  final String hash;
  final int canonicalBytes;

  const _LegacySignatureMetrics({
    required this.hash,
    required this.canonicalBytes,
  });
}

class _SignatureBenchmarkReport {
  final int pointCount;
  final int canonicalBytes;
  final int iterations;
  final Duration streamedDuration;
  final Duration legacyDuration;

  const _SignatureBenchmarkReport({
    required this.pointCount,
    required this.canonicalBytes,
    required this.iterations,
    required this.streamedDuration,
    required this.legacyDuration,
  });

  double get streamedMicrosPerRun =>
      streamedDuration.inMicroseconds / iterations;

  double get legacyMicrosPerRun => legacyDuration.inMicroseconds / iterations;

  double get speedup =>
      streamedMicrosPerRun <= 0 ? 0 : legacyMicrosPerRun / streamedMicrosPerRun;

  String toLogLine() {
    return 'ChartDataSignature benchmark: points=$pointCount '
        'bytes=$canonicalBytes iterations=$iterations '
        'streamed=${streamedMicrosPerRun.toStringAsFixed(1)}us/run '
        'legacy=${legacyMicrosPerRun.toStringAsFixed(1)}us/run '
        'speedup=${speedup.toStringAsFixed(2)}x';
  }
}
