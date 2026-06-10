import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  setUp(() {
    ChartRegistry.clear();
    allChartsBundle.register();
  });

  testWidgets('registry funnel renders initial animation frame safely', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 300,
            child: TenunChartFromJson(
              jsonConfig: {
                'type': 'funnel',
                'title': {'text': 'Funnel'},
                'showPercentage': true,
                'series': [
                  {
                    'data': [
                      {'name': 'Visits', 'value': 10000},
                      {'name': 'Leads', 'value': 6200},
                      {'name': 'Prospects', 'value': 3100},
                      {'name': 'Qualified', 'value': 1400},
                      {'name': 'Closed', 'value': 420},
                    ],
                  },
                ],
              },
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TenunChartFromJson), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
