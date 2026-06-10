import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun_core.dart';

void main() {
  test('core bundle exposes standard charts only', () {
    final coreTypes = {
      for (final registration in coreChartsBundle.registrations)
        registration.type,
    };

    expect(coreTypes, contains(ChartType.bar));
    expect(coreTypes, contains(ChartType.line));
    expect(coreTypes, contains(ChartType.area));
    expect(coreTypes, contains(ChartType.pie));
    expect(coreTypes, contains(ChartType.scatter));
    expect(coreTypes, isNot(contains(ChartType.candlestick)));
    expect(coreTypes, isNot(contains(ChartType.heatmap)));
    expect(coreTypes, isNot(contains(ChartType.treemap)));
  });

  test('core bundle can bootstrap local JSON rendering types', () {
    final previous = ChartRegistry.snapshot();
    try {
      ChartRegistry.clear();
      coreChartsBundle.register();

      expect(ChartRegistry.isRegisteredString('bar'), isTrue);
      expect(ChartRegistry.isRegisteredString('line'), isTrue);
      expect(ChartRegistry.isRegisteredString('pie'), isTrue);
      expect(ChartRegistry.isRegisteredString('candlestick'), isFalse);
    } finally {
      ChartRegistry.restore(previous);
    }
  });
}
