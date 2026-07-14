import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/pie/pie_config.dart';

void main() {
  testWidgets('dump widget tree', (tester) async {
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
      'sectionsSpace': '2',
      'enableSections': 'true',
    });
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 460, height: 280, child: config.buildChart()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    debugDumpApp();
  });
}
