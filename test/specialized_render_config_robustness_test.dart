import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/ai_ml/roc_curve_config.dart';
import 'package:tenun/charts/pareto/pareto_config.dart';
import 'package:tenun/charts/s_curve/s_curve_config.dart';

void main() {
  group('specialized render config robustness', () {
    testWidgets('roc pareto and s-curve render string data without throwing', (
      tester,
    ) async {
      final charts = [
        ROCCurveChartConfig.fromJson({
          'showChanceLine': 'true',
          'series': [
            {
              'name': 'Model',
              'data': [
                ['0', '0'],
                ['0.2', '0.7'],
                ['1', '1'],
              ],
            },
          ],
        }).buildChart(),
        ParetoChartConfig.fromJson({
          'autoSort': 'yes',
          'series': [
            {
              'name': 'Causes',
              'data': [
                {'name': 'Docs', 'value': '52'},
                {'name': 'API', 'value': '28'},
              ],
            },
          ],
        }).buildChart(),
        SCurveChartConfig.fromJson({
          'autoCumulative': 'yes',
          'targetValue': '100',
          'series': [
            {
              'name': 'Actual',
              'data': [
                {'value': '8'},
                '22',
                '35',
              ],
            },
          ],
        }).buildChart(),
      ];

      for (final chart in charts) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(width: 320, height: 240, child: chart),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1000));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
