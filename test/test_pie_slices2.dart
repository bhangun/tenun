import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/pie/pie_config.dart';

void main() {
  testWidgets('dump slices', (tester) async {
    final config = PieChartConfig.fromJson({
      'type': 'pie',
      'title': {'text': 'Core pie'},
      'series': [
        {
          'name': 'Sales',
          'data': [
            {'name': 'Online', 'value': '42', 'color': '#2563EB'},
            {'name': 'Partner', 'value': 28},
          ],
        },
      ],
    });
    
    final widget = PieChartWidget(config: config);
    // Use reflection or just instantiate a similar test to see what it does
    // Actually, I can just patch PieChartWidget to print slices length
  });
}
