// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/area/area_time_axis_chart.dart';
import 'package:tenun/charts/area/large_scale_area_chart.dart';
import 'package:tenun/charts/candle/candlestick_ohlc_chart.dart';
import 'package:tenun/charts/sparkline/sparkline_chart.dart';

void main() {
  group('time-series config robustness', () {
    test('candlestick config tolerates stringly typed OHLC payloads', () {
      final config = CandlestickChartConfig.fromJsonCandlestick({
        'showVolume': 'false',
        'bullColor': '#00AA88',
        'bearColor': 'bad-color',
        'volumePaneFraction': '0.31',
        'xAxis': {
          'data': ['D1', 'D2', 'D3'],
        },
        'sampling': {
          'enabled': 'yes',
          'threshold': '100',
          'strategy': 'min_max',
        },
        'series': [
          {
            'data': [
              {
                'date': '2026-01-01',
                'open': '10',
                'high': '12',
                'low': '9',
                'close': '11',
                'volume': '1,500',
              },
              ['2026-01-02', '11', '13', '10', '12', '1,600'],
              [12, 14, 11, 13, 1700],
            ],
          },
        ],
      });

      expect(config.bars, hasLength(3));
      expect(config.bars.first.open, 10);
      expect(config.bars.first.volume, 1500);
      expect(config.bars[1].date, '2026-01-02');
      expect(config.bars[1].close, 12);
      expect(config.bars[2].date, 'D3');
      expect(config.showVolume, isFalse);
      expect(config.bullColor, const Color(0xFF00AA88));
      expect(config.bearColor, const Color(0xFFEF5350));
      expect(config.volumePaneFraction, 0.31);
    });

    test('area and sparkline configs tolerate stringly typed payloads', () {
      final timeArea = AreaTimeAxisConfig.fromJson({
        'fillOpacity': '0.42',
        'showLine': 'no',
        'points': [
          {'time': '2026-01-01T00:00:00.000', 'value': '1,200'},
          {'time': '2026-01-02T00:00:00.000', 'value': '1,280'},
        ],
      });
      expect(timeArea.points.map((point) => point.value), [1200, 1280]);
      expect(timeArea.showLine, isFalse);
      expect(timeArea.fillOpacity, 0.42);

      final seriesBackedTimeArea = AreaTimeAxisConfig.fromJson({
        'series': [
          {
            'data': [
              {'time': '2026-01-03T00:00:00.000', 'value': '1,340'},
            ],
          },
        ],
      });
      expect(seriesBackedTimeArea.points.single.value, 1340);

      final largeArea = LargeScaleAreaConfig.fromJson({
        'targetPoints': '120',
        'fillOpacity': '0.2',
        'series': [
          {
            'data': [
              ['1', '10'],
              {'x': '2', 'y': '20'},
            ],
          },
        ],
      });
      expect(largeArea.xData, [1, 2]);
      expect(largeArea.yData, [10, 20]);
      expect(largeArea.targetPoints, 120);
      expect(largeArea.fillOpacity, 0.2);

      final sparkline = SparklineChartConfig.fromJson({
        'sparklineType': 'bar',
        'showEndDot': '0',
        'showHighLow': 'yes',
        'strokeWidth': '3.5',
        'fillOpacity': '0.35',
        'series': [
          {
            'data': ['4', '8', '12'],
          },
          'bad-series',
        ],
      });
      expect(sparkline.series, hasLength(1));
      expect(sparkline.sparklineType, SparklineType.bar);
      expect(sparkline.showEndDot, isFalse);
      expect(sparkline.showHighLow, isTrue);
      expect(sparkline.strokeWidth, 3.5);
      expect(sparkline.fillOpacity, 0.35);
    });

    testWidgets('sparkline renders string series data without throwing', (
      tester,
    ) async {
      final config = SparklineChartConfig.fromJson({
        'sparklineType': 'area',
        'series': [
          {
            'data': ['4', '8', '12'],
          },
        ],
      });

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 160,
            height: 48,
            child: SparklineWidget(config: config),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.takeException(), isNull);
    });
  });
}
