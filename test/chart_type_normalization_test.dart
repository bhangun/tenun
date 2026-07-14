import 'package:flutter_test/flutter_test.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/series.dart';

void main() {
  group('chart type normalization', () {
    test('normalizes separator variants consistently', () {
      expect(
        normalizeChartTypeKey('Stacked Horizontal Bar'),
        'stackedhorizontalbar',
      );
      expect(normalizeChartTypeKey('line-style_item'), 'linestyleitem');
      expect(normalizeChartTypeKey(null), isEmpty);
    });

    test('getChartType accepts whitespace separated aliases', () {
      expect(
        getChartType('stacked horizontal bar'),
        ChartType.stackedHorizontalBar,
      );
      expect(getChartType('line style item'), ChartType.lineStyleItem);
      expect(getChartType('live chart'), ChartType.dynamicTimeSeries);
      expect(getChartType('pie label align'), ChartType.pieLabelAlign);
      expect(
        getChartType('tangential polar bar'),
        ChartType.tangentialPolarBar,
      );
      expect(getChartType('dual axes'), ChartType.multiXAxes);
    });

    test('legacy aliases resolve to active registered chart types', () {
      expect(canonicalChartType(ChartType.dualaxes), ChartType.multiXAxes);
      expect(
        canonicalChartType(ChartType.linestyleitem),
        ChartType.lineStyleItem,
      );
      expect(canonicalChartType(ChartType.bigdata), ChartType.largeScaleArea);
      expect(canonicalChartType(ChartType.spiderline), ChartType.polarLine);
      expect(
        canonicalChartType(ChartType.alignedlabels),
        ChartType.pieLabelAlign,
      );
      expect(
        canonicalChartType(ChartType.richlabelpie),
        ChartType.pieSpecialLabel,
      );
      expect(getChartType('bigdata'), ChartType.largeScaleArea);
      expect(getChartType('spiderline'), ChartType.polarLine);
      expect(getChartType('alignedlabels'), ChartType.pieLabelAlign);
      expect(getChartType('richlabelpie'), ChartType.pieSpecialLabel);
    });

    test('Series.fromJson uses the same chart type normalization', () {
      expect(
        Series.fromJson(const {'type': 'stacked horizontal bar'}).type,
        ChartType.stackedHorizontalBar,
      );
      expect(
        Series.fromJson(const {'type': 'line-style-item'}).type,
        ChartType.lineStyleItem,
      );
    });
  });
}
