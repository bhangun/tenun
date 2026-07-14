import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/candle/candlestick_ohlc_chart.dart';
import 'package:tenun/tenun.dart';

void main() {
  group('Large data auto sampling', () {
    setUp(() {
      ChartRegistry.clear();
      allChartsBundle.register();
      financialChartsBundle.register();
      LargeDataSamplingConfig.enabled = true;
      LargeDataSamplingConfig.threshold = 200;
      LargeDataSamplingConfig.strategy = null;
      LargeDataSamplingConfig.mode = ChartDataMode.auto;
    });

    test('samples numeric bar series when above threshold', () {
      final values = List.generate(5000, (i) => (i % 300).toDouble());
      final cfg = BaseChartConfig.fromJson({
        'type': 'bar',
        'xAxis': {'data': List.generate(values.length, (i) => 'C$i')},
        'series': [
          {'name': 'S1', 'data': values},
        ],
      });

      final sampled = cfg.series.first.data!;
      expect(sampled.length <= LargeDataSamplingConfig.threshold, isTrue);
      expect(sampled.length, lessThan(values.length));
    });

    test('samples numeric string series when above threshold', () {
      final values = List.generate(5000, (i) => '${i % 300}');
      final cfg = BaseChartConfig.fromJson({
        'type': 'line',
        'sampling': {'threshold': 160, 'strategy': 'nth'},
        'series': [
          {'name': 'S1', 'data': values},
        ],
      });

      final sampled = cfg.series.first.data!;
      expect(sampled.length <= 160, isTrue);
      expect(sampled.first, 0);
      expect(sampled.last, 199);
    });

    test('accepts bool-like and numeric-string sampling overrides', () {
      LargeDataSamplingConfig.enabled = false;

      final values = List.generate(5000, (i) => '${i % 300}');
      final cfg = BaseChartConfig.fromJson({
        'type': 'line',
        'sampling': {'enabled': 'yes', 'threshold': '160', 'strategy': 'nth'},
        'series': [
          {'name': 'S1', 'data': values},
        ],
      });

      final sampled = cfg.series.first.data!;
      expect(sampled.length <= 160, isTrue);
      expect(sampled.length, lessThan(values.length));
      expect(sampled.first, 0);
      expect(sampled.last, 199);
    });

    test('ignores non-finite sampling thresholds without throwing', () {
      final values = List.generate(5000, (i) => i.toDouble());
      final cfg = BaseChartConfig.fromJson({
        'type': 'line',
        'sampling': {
          'enabled': true,
          'threshold': double.nan,
          'strategy': 'nth',
        },
        'series': [
          {'name': 'S1', 'data': values},
        ],
      });

      final sampled = cfg.series.first.data!;
      expect(sampled.length <= LargeDataSamplingConfig.threshold, isTrue);
      expect(sampled.first, values.first);
      expect(sampled.last, values.last);
    });

    test('normalizes unsafe payload sampling threshold', () {
      final values = List.generate(5000, (i) => i.toDouble());
      final cfg = BaseChartConfig.fromJson({
        'type': 'line',
        'dataMode': 'large',
        'sampling': {'threshold': 0, 'strategy': 'nth'},
        'series': [
          {'name': 'S1', 'data': values},
        ],
      });

      final sampled = cfg.series.first.data!;
      expect(sampled.length, 2);
      expect(sampled.first, values.first);
      expect(sampled.last, values.last);
    });

    test('normalizes unsafe global sampling threshold', () {
      LargeDataSamplingConfig.threshold = -20;

      final values = List.generate(5000, (i) => i.toDouble());
      final cfg = LineChartConfig(
        series: [Series(type: ChartType.line, name: 'S1', data: values)],
      );

      final sampled = cfg.series.first.data!;
      expect(sampled.length, 2);
      expect(sampled.first, values.first);
      expect(sampled.last, values.last);
    });

    test('preserves unchanged series objects when sibling series samples', () {
      final smallSeries = Series(
        type: ChartType.line,
        name: 'Small',
        data: List.generate(50, (i) => i.toDouble()),
      );
      final largeSeries = Series(
        type: ChartType.line,
        name: 'Large',
        data: List.generate(5000, (i) => (i % 300).toDouble()),
      );

      final cfg = LineChartConfig(series: [smallSeries, largeSeries]);

      expect(cfg.series.first, same(smallSeries));
      expect(cfg.series.last, isNot(same(largeSeries)));
      expect(
        cfg.series.last.data!.length <= LargeDataSamplingConfig.threshold,
        isTrue,
      );
    });

    test('does not sample pie object-based data', () {
      final cfg = BaseChartConfig.fromJson({
        'type': 'pie',
        'series': [
          {
            'data': List.generate(1000, (i) => {'name': 'K$i', 'value': i + 1}),
          },
        ],
      });

      expect(cfg.series.first.data!.length, 1000);
    });

    test('samples tuple scatter series while preserving tuple shape', () {
      final points = List.generate(
        5000,
        (i) => [i.toDouble(), ((i * 7) % 200).toDouble()],
      );
      final cfg = BaseChartConfig.fromJson({
        'type': 'scatter',
        'series': [
          {'name': 'S1', 'data': points},
        ],
      });

      final sampled = cfg.series.first.data!;
      expect(sampled.length <= LargeDataSamplingConfig.threshold, isTrue);
      expect(sampled.first, points.first);
      expect(sampled.last, points.last);
      expect((sampled.first as List).length, 2);
    });

    test('samples multi-value line tuples using rendered y values', () {
      final points = List.generate(100, (i) {
        final y = i == 25 ? 1000.0 : 10.0;
        final alternate = i == 75 ? 1000.0 : 5.0;
        return [i.toDouble(), y, -1.0, alternate];
      });
      final cfg = BaseChartConfig.fromJson({
        'type': 'line',
        'sampling': {'threshold': 10, 'strategy': 'minMax'},
        'series': [
          {'name': 'S1', 'data': points},
        ],
      });

      final sampled = cfg.series.first.data!;
      final sampledSourceIndexes = sampled
          .map((row) => ((row as List).first as double).toInt())
          .toList();
      expect(sampled.length <= 10, isTrue);
      expect(sampledSourceIndexes, contains(25));
    });

    test('samples OHLC tuple series while preserving 4-value items', () {
      final ohlc = List.generate(5000, (i) {
        final open = 100 + (i % 10);
        final close = open + (i.isEven ? 2 : -1);
        final high = (open > close ? open : close) + 3;
        final low = (open < close ? open : close) - 2;
        return [
          open.toDouble(),
          high.toDouble(),
          low.toDouble(),
          close.toDouble(),
        ];
      });
      final cfg = BaseChartConfig.fromJson({
        'type': 'candlestick',
        'xAxis': {'data': List.generate(ohlc.length, (i) => 'D$i')},
        'series': [
          {'name': 'OHLC', 'data': ohlc},
        ],
      });

      expect(cfg, isA<CandlestickChartConfig>());
      final bars = (cfg as CandlestickChartConfig).bars;
      expect(bars.length <= LargeDataSamplingConfig.threshold, isTrue);
      expect(bars.isNotEmpty, isTrue);
      expect(
        ((cfg.toJson()['series'] as List).first['data'] as List).length,
        bars.length,
      );
      expect(ChartDataSignature.fromConfig(cfg).dataPointCount, bars.length);
      expect(bars.first.open, ohlc.first[0]);
      expect(bars.first.high, ohlc.first[1]);
      expect(bars.first.low, ohlc.first[2]);
      expect(bars.first.close, ohlc.first[3]);
      expect(bars.first.date, 'D0');
      expect(bars.last.close, ohlc.last[3]);
    });

    test('parses date-prefixed OHLC tuples', () {
      final cfg = BaseChartConfig.fromJson({
        'type': 'candlestick',
        'dataMode': 'regular',
        'series': [
          {
            'name': 'OHLC',
            'data': [
              ['2025-01-01', 100, 106, 98, 103, 1200],
              ['2025-01-02', 103, 109, 101, 107, 1600],
            ],
          },
        ],
      });

      expect(cfg, isA<CandlestickChartConfig>());
      final bars = (cfg as CandlestickChartConfig).bars;
      expect(bars.length, 2);
      expect(bars.first.date, '2025-01-01');
      expect(bars.first.open, 100);
      expect(bars.first.high, 106);
      expect(bars.first.low, 98);
      expect(bars.first.close, 103);
      expect(bars.first.volume, 1200);
    });

    test('samples map x/y series while preserving map payload', () {
      final points = List.generate(
        5000,
        (i) => {
          'x': i.toDouble(),
          'y': ((i * 3) % 180).toDouble(),
          'meta': 'p$i',
        },
      );
      final cfg = BaseChartConfig.fromJson({
        'type': 'line',
        'series': [
          {'name': 'S1', 'data': points},
        ],
      });

      final sampled = cfg.series.first.data!;
      expect(sampled.length <= LargeDataSamplingConfig.threshold, isTrue);
      expect((sampled.first as Map)['meta'], points.first['meta']);
      expect((sampled.last as Map)['meta'], points.last['meta']);
    });

    test('samples map close series while preserving object payload', () {
      final points = List.generate(
        5000,
        (i) => {'label': 'P$i', 'close': ((i * 11) % 240).toDouble()},
      );
      final cfg = BaseChartConfig.fromJson({
        'type': 'line',
        'sampling': {'threshold': 180, 'strategy': 'nth'},
        'series': [
          {'name': 'S1', 'data': points},
        ],
      });

      final sampled = cfg.series.first.data!;
      expect(sampled.length <= 180, isTrue);
      expect((sampled.first as Map)['label'], points.first['label']);
      expect((sampled.last as Map)['label'], points.last['label']);
    });

    test('samples mixed structured rows while preserving source payloads', () {
      final rows = List<dynamic>.generate(5000, (i) {
        if (i == 0) return 'bad-start';
        if (i == 2500) return {'ignored': true};
        if (i == 4999) return [i, (i % 180).toDouble(), 'meta-$i'];
        if (i.isEven) return [i, (i % 180).toDouble(), 'meta-$i'];
        return {'x': i, 'y': (i % 180).toDouble(), 'meta': 'p$i'};
      });

      final cfg = BaseChartConfig.fromJson({
        'type': 'line',
        'dataMode': 'large',
        'sampling': {'threshold': 120, 'strategy': 'nth'},
        'series': [
          {'name': 'Mixed', 'data': rows},
        ],
      });

      final sampled = cfg.series.first.data!;
      expect(sampled.length <= 120, isTrue);
      expect(sampled.length, lessThan(rows.length));
      expect(sampled.first, rows[1]);
      expect(sampled.last, rows.last);
      expect(sampled, isNot(contains(rows[0])));
      expect(sampled, isNot(contains(rows[2500])));
      expect(
        sampled.any(
          (item) =>
              item is Map &&
              (item['meta']?.toString().startsWith('p') ?? false),
        ),
        isTrue,
      );
      expect(sampled.any((item) => item is List && item.length == 3), isTrue);
    });

    test('compacts sparse large data when valid rows fit under threshold', () {
      final rows = List<dynamic>.filled(5000, {'ignored': true});
      rows[10] = {'x': 10, 'y': 4, 'label': 'A'};
      rows[250] = ['B', 8];
      rows[4999] = 12;

      final cfg = BaseChartConfig.fromJson({
        'type': 'area',
        'dataMode': 'large',
        'sampling': {'threshold': 120, 'strategy': 'nth'},
        'series': [
          {'name': 'Sparse', 'data': rows},
        ],
      });

      expect(cfg.series.first.data, [rows[10], rows[250], rows[4999]]);
    });

    test('regular dataMode disables sampling per payload', () {
      final values = List.generate(5000, (i) => (i % 300).toDouble());
      final cfg = BaseChartConfig.fromJson({
        'type': 'line',
        'dataMode': 'regular',
        'series': [
          {'name': 'S1', 'data': values},
        ],
      });

      expect(cfg.series.first.data!.length, values.length);
    });

    test('large dataMode forces sampling even when global disabled', () {
      LargeDataSamplingConfig.enabled = false;

      final values = List.generate(5000, (i) => (i % 300).toDouble());
      final cfg = BaseChartConfig.fromJson({
        'type': 'line',
        'dataMode': 'large',
        'sampling': {'threshold': 150, 'strategy': 'nth'},
        'series': [
          {'name': 'S1', 'data': values},
        ],
      });

      expect(cfg.series.first.data!.length <= 150, isTrue);
    });

    test('large dataMode forces sampling for candlestick tuples', () {
      LargeDataSamplingConfig.enabled = false;

      final ohlc = List.generate(2000, (i) {
        final open = 80 + (i % 12);
        final close = open + (i.isEven ? 1 : -2);
        final high = (open > close ? open : close) + 4;
        final low = (open < close ? open : close) - 3;
        return [
          open.toDouble(),
          high.toDouble(),
          low.toDouble(),
          close.toDouble(),
        ];
      });

      final cfg = BaseChartConfig.fromJson({
        'type': 'candlestick',
        'dataMode': 'large',
        'sampling': {'threshold': 140, 'strategy': 'nth'},
        'series': [
          {'name': 'OHLC', 'data': ohlc},
        ],
      });

      final bars = (cfg as CandlestickChartConfig).bars;
      expect(bars.length <= 140, isTrue);
      expect(bars.isNotEmpty, isTrue);
      expect(
        ((cfg.toJson()['series'] as List).first['data'] as List).length,
        bars.length,
      );
      expect(ChartDataSignature.fromConfig(cfg).dataPointCount, bars.length);
    });
  });
}
