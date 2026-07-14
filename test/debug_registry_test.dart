import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  test('debug registry', () {
    ChartRegistry.clear();
    allChartsBundle.register();
    print('Enums length: ${ChartRegistry.registeredEnums.length}');
    if (ChartRegistry.registeredEnums.isNotEmpty) {
      print('First enum: ${ChartRegistry.registeredEnums.first}');
    }
    
    final line = chartCapabilitiesForType(ChartType.line);
    print('Line registered: ${line.isRegistered}');
    expect(ChartRegistry.registeredEnums.isNotEmpty, isTrue);
  });
}
