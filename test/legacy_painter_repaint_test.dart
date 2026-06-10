import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  group('legacy painter repaint signatures', () {
    test('line painter skips repaint for equivalent rebuilt config', () {
      final oldPainter = LineChartPainter(
        config: _lineConfig([1, 2, 3]),
        maxY: 4,
        startIndex: 0,
        endIndex: 2,
        progress: 1,
      );

      expect(
        LineChartPainter(
          config: _lineConfig([1, 2, 3]),
          maxY: 4,
          startIndex: 0,
          endIndex: 2,
          progress: 1,
        ).shouldRepaint(oldPainter),
        isFalse,
      );

      expect(
        LineChartPainter(
          config: _lineConfig([1, 2, 4]),
          maxY: 4,
          startIndex: 0,
          endIndex: 2,
          progress: 1,
        ).shouldRepaint(oldPainter),
        isTrue,
      );

      expect(
        LineChartPainter(
          config: _lineConfig([1, 2, 3]),
          maxY: 4,
          startIndex: 0,
          endIndex: 2,
          progress: 0.5,
        ).shouldRepaint(oldPainter),
        isTrue,
      );
    });

    test('bar painter skips repaint for equivalent rebuilt config', () {
      final oldPainter = BarChartPainter(
        config: _barConfig([1, 2, 3]),
        maxY: 4,
        startIndex: 0,
        endIndex: 2,
        progress: 1,
      );

      expect(
        BarChartPainter(
          config: _barConfig([1, 2, 3]),
          maxY: 4,
          startIndex: 0,
          endIndex: 2,
          progress: 1,
        ).shouldRepaint(oldPainter),
        isFalse,
      );

      expect(
        BarChartPainter(
          config: _barConfig([1, 2, 3]),
          maxY: 5,
          startIndex: 0,
          endIndex: 2,
          progress: 1,
        ).shouldRepaint(oldPainter),
        isTrue,
      );

      expect(
        BarChartPainter(
          config: _barConfig([1, 2, 3]),
          maxY: 4,
          startIndex: 1,
          endIndex: 2,
          progress: 1,
        ).shouldRepaint(oldPainter),
        isTrue,
      );
    });

    test('multi bar painter skips repaint for equivalent rebuilt config', () {
      final oldPainter = MultiBarChartPainter(
        config: _multiBarConfig([
          [0, 1],
          [1, 2],
        ]),
      );

      expect(
        MultiBarChartPainter(
          config: _multiBarConfig([
            [0, 1],
            [1, 2],
          ]),
        ).shouldRepaint(oldPainter),
        isFalse,
      );

      expect(
        MultiBarChartPainter(
          config: _multiBarConfig([
            [0, 1],
            [1, 3],
          ]),
        ).shouldRepaint(oldPainter),
        isTrue,
      );
    });
  });
}

LineChartConfig _lineConfig(List<num> data) {
  return LineChartConfig(
    series: [Series(type: ChartType.line, name: 'Signal', data: data)],
    showDots: false,
  );
}

BarChartConfig _barConfig(List<num> data) {
  return BarChartConfig(
    series: [Series(type: ChartType.bar, name: 'Bars', data: data)],
  );
}

BarChartConfig _multiBarConfig(List<List<num>> data) {
  return BarChartConfig(
    isMultiBar: true,
    series: [Series(type: ChartType.bar, name: 'Bars', data: data)],
  );
}
