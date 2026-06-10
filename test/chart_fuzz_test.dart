import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  setUp(() {
    ChartRegistry.clear();
    allChartsBundle.register();
  });

  test('Fuzz Test JSON Configs', () {
    final rand = Random(42);
    for (int i = 0; i < 2000; i++) {
      final json = {
        'type': ['bar', 'line', 'pie', 'area'][rand.nextInt(4)],
        'series': [
          {
            'data': List.generate(
              rand.nextInt(200),
              (_) => rand.nextDouble() * 100,
            ),
          },
        ],
        if (rand.nextBool()) 'maxY': rand.nextDouble() * 1000,
        if (rand.nextBool()) 'grid': {'show': rand.nextBool()},
      };
      try {
        BaseChartConfig.fromJson(json);
      } catch (e) {
        fail('Fuzz test failed on iteration $i: $e\nJSON: $json');
      }
    }
  });
}
