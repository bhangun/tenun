import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/charts/bar/bar_chart.dart';
import 'package:tenun/charts/bar/bar_config.dart';
import 'package:tenun/core/chart_type.dart';
import 'package:tenun/core/grid.dart';
import 'package:tenun/core/label.dart';
import 'package:tenun/core/legend.dart';
import 'package:tenun/core/series.dart';
import 'package:tenun/core/text_style.dart' as tenun_style;
import 'package:tenun/core/title.dart';
import 'package:tenun/core/utils/helper.dart';
import 'package:tenun/core/xyaxis.dart';

void main() {
  group('Color parsing helpers', () {
    test('preserves strict parser failures while exposing safe fallbacks', () {
      expect(() => stringToColor('not-a-color'), throwsFormatException);
      expect(tryStringToColor('not-a-color'), isNull);
      expect(safeStringToColor('not-a-color', Colors.pink), Colors.pink);
      expect(safeStringToColor(null, Colors.orange), Colors.orange);
    });

    test('parses supported color formats consistently', () {
      expect(stringToColor('#0f8'), const Color(0xFF00FF88));
      expect(stringToColor('#11223344'), const Color(0x44112233));
      expect(stringToColor('RGB(10, 20, 30)'), const Color(0xFF0A141E));
      expect(
        rgbaStringToColor('rgba(10, 20, 30, 0.5)'),
        const Color(0x800A141E),
      );
      expect(convertColor(null), Colors.grey);
    });

    test('reports malformed functional colors as format errors', () {
      expect(() => rgbStringToColor('rgb(1, 2)'), throwsFormatException);
      expect(() => rgbStringToColor('rgb(1, nope, 3)'), throwsFormatException);
      expect(
        () => rgbaStringToColor('rgba(1, 2, 3, nope)'),
        throwsFormatException,
      );
    });

    test('computes max series value for mixed data without throwing', () {
      expect(getMaxSeriesValue(const <Series>[]), 100);
      expect(
        getMaxSeriesValue([
          Series(
            type: ChartType.line,
            data: const [
              {'value': 42},
              [1, 55],
              'ignored',
            ],
          ),
        ]),
        75,
      );
    });
  });

  testWidgets('legacy bar chart falls back for malformed color strings', (
    tester,
  ) async {
    final config = BarChartConfig(
      title: TitlesData(
        text: 'Sales',
        subtext: 'Invalid colors should not crash',
        subtextStyle: tenun_style.ChartTextStyle(color: 'bad-subtitle'),
      ),
      legend: ChartLegend(show: true, textColor: 'bad-legend'),
      grid: GridData(show: true, horizontalColor: 'bad-grid'),
      xAxis: XYAxis(data: const ['A', 'B']),
      series: [
        Series(
          type: ChartType.bar,
          name: 'Revenue',
          data: const [10, 20],
          itemStyle: ItemStyle(color: 'bad-series'),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 260,
          child: BarChartWidget(config: config),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Revenue'), findsOneWidget);
  });
}
