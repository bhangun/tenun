import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:tenun/core/data_sampler.dart';

class LTTBBenchmark extends BenchmarkBase {
  LTTBBenchmark() : super('LTTB Sampling (50k pts)');
  late List<double> data;

  @override void setup() {
    data = List.generate(50000, (_) => Random().nextDouble() * 100);
  }
  @override void run() {
    DoubleListSampler.auto(data, 500);
  }
  @override void teardown() {}
}

void main() {
  test('Run Performance Benchmarks', () {
    final bench = LTTBBenchmark();
    bench.report(); // Prints to console
  });
}