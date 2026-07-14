import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';
import 'package:tenun_core/core/chart_axis_config.dart';

void main() {
  group('Core config parsing', () {
    setUp(() {
      ChartRegistry.clear();
      coreChartsBundle.register();
    });

    test('parses JSON-like typed maps for axis and style configs', () {
      final titleStyle = <String, Object?>{
        'color': '#123456',
        'fontStyle': 'italic',
        'fontWeight': 'w700',
        'fontSize': '16',
      };
      final tooltipStyle = <String, Object?>{
        'color': '#654321',
        'fontWeight': 'bold',
      };
      final axisLine = <String, Object?>{
        'show': 'true',
        'lineStyle': <String, Object?>{'color': '#222222', 'width': '2.5'},
      };
      final xAxis = <String, Object?>{
        'type': 'category',
        'data': ['A', 'B'],
        'axisLine': axisLine,
        'axisLabel': <String, Object?>{
          'show': 'true',
          'textStyle': <String, Object?>{'fontStyle': 'oblique'},
        },
      };
      final series = <String, Object?>{
        'name': 'Revenue',
        'xAxisIndex': '0',
        'data': [10, 20],
      };

      final config = BaseChartConfig.fromJson({
        'type': 'line',
        'title': <String, Object?>{'text': 'Revenue', 'textStyle': titleStyle},
        'tooltip': <String, Object?>{
          'show': 'true',
          'textStyle': tooltipStyle,
          'axisPointer': <String, Object?>{
            'type': 'line',
            'lineStyle': <String, Object?>{'width': '3'},
          },
        },
        'legend': <String, Object?>{
          'show': 'true',
          'selected': <String, Object?>{'Revenue': 'true'},
          'padding': ['4', 8],
          'textStyle': tooltipStyle,
        },
        'grid': <String, Object?>{
          'left': '12',
          'containLabel': 'true',
          'lineStyle': <String, Object?>{'width': '1.5'},
        },
        'xAxis': xAxis,
        'xAxisConfig': <String, Object?>{
          'scale': 'category',
          'categories': [1, 'B'],
          'tickCount': '2',
          'showGrid': 'false',
        },
        'series': [series],
      });

      final line = config as LineChartConfig;
      expect(line.title?.textStyle.fontStyle, FontStyle.italic);
      expect(line.title?.textStyle.fontWeight, FontWeight.w700);
      expect(line.tooltip?.textStyle, isA<ChartTextStyle>());
      expect(line.tooltip?.axisPointer?.lineStyle?.width, 3);
      expect(line.legend?.selected, {'Revenue': true});
      expect(line.legend?.padding, [4, 8]);
      expect(line.grid?.left, 12);
      expect(line.grid?.containLabel, isTrue);
      expect(line.grid?.lineStyle.width, 1.5);
      expect(line.xAxis?.axisLine?.lineStyle?.width, 2.5);
      expect(line.xAxis?.axisLabel?.textStyle?.fontStyle, FontStyle.oblique);
      expect(line.xAxisConfig?.categories, ['1', 'B']);
      expect(line.xAxisConfig?.showGrid, isFalse);
      expect(line.series.single.xAxisIndex, 0);
    });

    test('tolerates malformed optional style objects', () {
      final axis = XYAxis.fromJson({
        'axisLine': 'bad',
        'axisLabel': 42,
        'splitLine': true,
        'data': 'not-a-list',
      });
      final tooltip = ChartTooltip.fromJson({
        'textStyle': 'bad',
        'axisPointer': 1,
        'show': 'no',
      });

      expect(axis.axisLine, isNotNull);
      expect(axis.axisLine?.lineStyle, isNull);
      expect(axis.axisLabel?.show, isTrue);
      expect(axis.data, isNull);
      expect(tooltip.show, isFalse);
      expect(tooltip.textStyle, isA<ChartTextStyle>());
    });

    test('normalizes a single category axis without division by zero', () {
      const axis = ChartAxisConfig.category(categories: ['Only']);

      expect(axis.normalize(0, 0, 0), 0.5);
    });

    test('axis tick generation tolerates invalid tick counts', () {
      const zeroTicks = ChartAxisConfig.linear(tickCount: 0);
      const negativeTicks = ChartAxisConfig.linear(tickCount: -5);
      const singleTick = ChartAxisConfig.linear(tickCount: 1);

      expect(zeroTicks.computeTicks(0, 10), isEmpty);
      expect(negativeTicks.computeTicks(0, 10), isEmpty);
      expect(singleTick.computeTicks(0, 10), [5]);
    });

    test('axis tick generation caps excessive tick counts', () {
      final axis = ChartAxisConfig.fromJson({
        'scale': 'linear',
        'tickCount': '1000000',
      });

      expect(axis.computeTicks(0, 10), hasLength(1000));
    });

    test('axis normalization and ticks tolerate non-finite domains', () {
      const axis = ChartAxisConfig.linear();

      expect(axis.normalize(10, double.nan, double.infinity), 0.5);
      expect(axis.computeTicks(double.nan, double.infinity), [0, 0, 0, 0, 0]);
      expect(axis.formatTick(double.nan), isEmpty);
    });

    test('log axis tolerates invalid bases and non-positive domains', () {
      const axis = ChartAxisConfig.log(logBase: 1);

      expect(axis.normalize(100, 1, 1000), closeTo(2 / 3, 0.001));
      expect(axis.normalize(100, -10, -1), 0.5);
      expect(axis.computeTicks(-10, -1), [1e-10]);
    });
  });
}
