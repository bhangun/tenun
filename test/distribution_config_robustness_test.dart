import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  group('Distribution config robustness', () {
    testWidgets('ridgeline accepts flexible JSON values', (tester) async {
      final config = RidgelineChartConfig.fromJson({
        'categories': ['A', 2],
        'overlap': '0.25',
        'fillOpacity': '0.45',
        'series': [
          {
            'data': [
              [1, '2', 'bad'],
              '3',
              {'ignored': true},
            ],
          },
        ],
      });

      expect(config.categories, ['A', '2']);
      expect(config.overlap, 0.25);
      expect(config.fillOpacity, 0.45);

      await _pumpChart(tester, config.buildChart());
      expect(find.byType(RidgelineChartWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('strip accepts flexible JSON values', (tester) async {
      final config = StripChartConfig.fromJson({
        'categories': ['Control', 'Program'],
        'dotRadius': '5',
        'dotOpacity': '0.5',
        'showMean': 'no',
        'showMedian': 'yes',
        'series': [
          {
            'data': [
              [1, '2', 'bad'],
              '4',
            ],
          },
        ],
      });

      expect(config.categories, ['Control', 'Program']);
      expect(config.dotRadius, 5);
      expect(config.dotOpacity, 0.5);
      expect(config.showMean, isFalse);
      expect(config.showMedian, isTrue);

      await _pumpChart(tester, config.buildChart());
      expect(find.byType(StripChartWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error bar accepts flexible JSON values', (tester) async {
      final config = ErrorBarChartConfig.fromJson({
        'categories': ['North', 'South', 'East'],
        'horizontal': 'yes',
        'showLine': 'no',
        'series': [
          {
            'data': [
              {'mean': '4', 'error': '1'},
              '7',
              {'value': 'bad', 'lower': '1', 'upper': '2'},
              'bad',
            ],
          },
        ],
      });

      expect(config.categories, ['North', 'South', 'East']);
      expect(config.horizontal, isTrue);
      expect(config.showLine, isFalse);
      expect(config.errorData.single, hasLength(3));
      expect(config.errorData.single.first.mean, 4);
      expect(config.errorData.single.first.lower, 3);
      expect(config.errorData.single.first.upper, 5);
      expect(config.errorData.single[1].mean, 7);

      await _pumpChart(tester, config.buildChart());
      expect(find.byType(ErrorBarChartWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('box plot accepts flexible JSON values', (tester) async {
      final config = BoxPlotChartConfig.fromJson({
        'categories': ['A', 2, 'C', 'D'],
        'showMean': 'no',
        'showNotch': 'yes',
        'boxWidth': '0.35',
        'series': [
          {
            'data': [
              [1, '2', 'bad', 4],
              {
                'min': '1',
                'q1': '2',
                'median': '3',
                'q3': '4',
                'max': '5',
                'mean': '3.5',
                'outliers': ['bad', '8'],
              },
              {
                'values': ['2', '3', '4', 'bad'],
              },
              '7',
              {'ignored': true},
              'bad',
            ],
          },
        ],
      });

      expect(config.categories, ['A', '2', 'C', 'D']);
      expect(config.showMean, isFalse);
      expect(config.showNotch, isTrue);
      expect(config.boxWidthFraction, 0.35);
      expect(config.boxData.single, hasLength(4));
      expect(config.boxData.single[1].median, 3);
      expect(config.boxData.single[1].outliers, [8]);
      expect(config.boxData.single[3].median, 7);

      await _pumpChart(tester, config.buildChart());
      expect(find.byType(BoxPlotChartWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('violin accepts flexible JSON values', (tester) async {
      final config = ViolinChartConfig.fromJson({
        'categories': ['A', 2, 'C'],
        'showBoxPlot': 'no',
        'showMean': 'yes',
        'widthFraction': '0.45',
        'series': [
          {
            'name': 'Score',
            'data': [
              [1, '2', 'bad'],
              '3',
              {'ignored': true},
            ],
          },
          'bad',
        ],
      });

      expect(config.categories, ['A', '2', 'C']);
      expect(config.showBoxPlot, isFalse);
      expect(config.showMean, isTrue);
      expect(config.widthFraction, 0.45);
      expect(config.series, hasLength(1));

      await _pumpChart(tester, config.buildChart());
      expect(find.byType(ViolinChartWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('histogram skips malformed mixed series entries', (
      tester,
    ) async {
      final config = HistogramChartConfig.fromJson({
        'showStats': 'no',
        'series': [
          {
            'name': 'A',
            'data': ['1', '2'],
          },
          'bad',
          {
            'name': 'B',
            'data': [
              {'y': '3'},
              {'ignored': true},
            ],
          },
        ],
      });

      expect(config.series, hasLength(2));
      expect(config.showStats, isFalse);

      await _pumpChart(tester, config.buildChart());
      expect(find.byType(HistogramChartWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpChart(WidgetTester tester, Widget chart) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox(width: 460, height: 280, child: chart)),
    ),
  );
  await tester.pumpAndSettle();
}
