import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  group('ChartDataSignature', () {
    test('hash is stable regardless of map key order', () {
      final a = ChartDataSignature.fromJson({
        'type': 'line',
        'series': [
          {
            'name': 'S1',
            'data': [1, 2, 3],
          },
        ],
        'title': {'text': 'Demo'},
      });
      final b = ChartDataSignature.fromJson({
        'title': {'text': 'Demo'},
        'series': [
          {
            'data': [1, 2, 3],
            'name': 'S1',
          },
        ],
        'type': 'line',
      });

      expect(a.hash, b.hash);
      expect(a.seriesCount, 1);
      expect(a.dataPointCount, 3);
      expect(a.typeString, 'line');
    });

    test('streamed metrics match canonical hash and byte length', () {
      final payload = {
        'type': 'line',
        'title': {'text': 'Résumé ☕'},
        'series': [
          {
            'name': 'Satu',
            'data': [1, 2.0, 3.5],
          },
        ],
      };
      final canonical = canonicalizeChartData(payload);
      final signature = ChartDataSignature.fromJson(payload);

      expect(signature.hash, stableChartDataHashCanonical(canonical));
      expect(signature.canonicalBytes, utf8.encode(canonical).length);
      expect(stableChartDataHash(payload), signature.hash);
    });

    test('hash changes when chart data changes', () {
      final a = stableChartDataHash({
        'type': 'line',
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });
      final b = stableChartDataHash({
        'type': 'line',
        'series': [
          {
            'data': [1, 2, 4],
          },
        ],
      });

      expect(a, isNot(b));
    });

    test('canonicalizes numeric ints and whole doubles consistently', () {
      final a = stableChartDataHash({
        'series': [
          {
            'data': [1, 2, 3],
          },
        ],
      });
      final b = stableChartDataHash({
        'series': [
          {
            'data': [1.0, 2.0, 3.0],
          },
        ],
      });

      expect(a, b);
    });

    test('can summarize config objects', () {
      final config = LineChartConfig(
        series: [
          Series(type: ChartType.line, data: const [1, 2, 3]),
        ],
      );

      final signature = ChartDataSignature.fromConfig(config);

      expect(signature.typeString, 'line');
      expect(signature.seriesCount, 1);
      expect(signature.dataPointCount, 3);
      expect(signature.toJson()['hash'], signature.hash);
    });

    test('statistical and compact chart configs include payload data', () {
      final histogramA = HistogramChartConfig(
        series: [
          Series(type: ChartType.histogram, data: const [1, 2, 3]),
        ],
      );
      final histogramB = HistogramChartConfig(
        series: [
          Series(type: ChartType.histogram, data: const [1, 2, 4]),
        ],
      );

      final sparklineA = SparklineChartConfig(
        series: [
          Series(type: ChartType.sparkline, data: const [1, 2, 3]),
        ],
      );
      final sparklineB = SparklineChartConfig(
        sparklineType: SparklineType.area,
        series: [
          Series(type: ChartType.sparkline, data: const [1, 2, 3]),
        ],
      );

      final lollipopA = LollipopChartConfig(
        categories: const ['A', 'B'],
        series: [
          Series(type: ChartType.lollipop, data: const [10, 20]),
        ],
      );
      final lollipopB = LollipopChartConfig(
        categories: const ['A', 'B'],
        horizontal: true,
        series: [
          Series(type: ChartType.lollipop, data: const [10, 20]),
        ],
      );

      expect((histogramA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((sparklineA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((lollipopA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect(
        ChartDataSignature.fromConfig(histogramA).hash,
        isNot(ChartDataSignature.fromConfig(histogramB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(sparklineA).hash,
        isNot(ChartDataSignature.fromConfig(sparklineB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(lollipopA).hash,
        isNot(ChartDataSignature.fromConfig(lollipopB).hash),
      );
    });

    test('custom object chart configs include payload data', () {
      final bulletA = BulletChartConfig(
        items: const [
          BulletItem(label: 'Revenue', value: 270, target: 300, max: 400),
        ],
      );
      final bulletB = BulletChartConfig(
        items: const [
          BulletItem(label: 'Revenue', value: 271, target: 300, max: 400),
        ],
      );

      final boxA = BoxPlotChartConfig(
        categories: const ['A'],
        boxData: const [
          [BoxSummary(min: 1, q1: 2, median: 3, q3: 4, max: 5)],
        ],
      );
      final boxB = BoxPlotChartConfig(
        categories: const ['A'],
        boxData: const [
          [BoxSummary(min: 1, q1: 2, median: 4, q3: 4, max: 5)],
        ],
      );

      final violinA = ViolinChartConfig(
        categories: const ['A'],
        series: [
          Series(
            type: ChartType.violin,
            data: const [
              [1, 2, 3],
            ],
          ),
        ],
      );
      final violinB = ViolinChartConfig(
        categories: const ['A'],
        showMean: false,
        series: [
          Series(
            type: ChartType.violin,
            data: const [
              [1, 2, 3],
            ],
          ),
        ],
      );

      expect((bulletA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((boxA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((violinA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect(
        ChartDataSignature.fromConfig(bulletA).hash,
        isNot(ChartDataSignature.fromConfig(bulletB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(boxA).hash,
        isNot(ChartDataSignature.fromConfig(boxB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(violinA).hash,
        isNot(ChartDataSignature.fromConfig(violinB).hash),
      );
    });

    test('heatmap calendar and parallel configs include payload data', () {
      final heatmapA = HeatmapChartConfig(
        xLabels: const ['Mon', 'Tue'],
        yLabels: const ['AM'],
        data: const [
          [1, 2],
        ],
      );
      final heatmapB = HeatmapChartConfig(
        xLabels: const ['Mon', 'Tue'],
        yLabels: const ['AM'],
        data: const [
          [1, 3],
        ],
      );

      final calendarA = CalendarChartConfig(
        year: 2026,
        dateValues: const {'2026-01-01': 1},
      );
      final calendarB = CalendarChartConfig(
        year: 2026,
        dateValues: const {'2026-01-01': 2},
      );

      final parallelA = ParallelChartConfig(
        axes: const ['Price', 'Miles'],
        series: [
          Series(
            type: ChartType.parallel,
            data: const [
              [10, 20],
            ],
          ),
        ],
      );
      final parallelB = ParallelChartConfig(
        axes: const ['Price', 'Miles'],
        lineOpacity: 0.8,
        series: [
          Series(
            type: ChartType.parallel,
            data: const [
              [10, 20],
            ],
          ),
        ],
      );

      expect((heatmapA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((calendarA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((parallelA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect(
        ChartDataSignature.fromConfig(heatmapA).hash,
        isNot(ChartDataSignature.fromConfig(heatmapB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(calendarA).hash,
        isNot(ChartDataSignature.fromConfig(calendarB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(parallelA).hash,
        isNot(ChartDataSignature.fromConfig(parallelB).hash),
      );
    });

    test('trading configs include price payload and settings', () {
      final kagiA = KagiChartConfig(prices: const [100, 105, 99]);
      final kagiB = KagiChartConfig(
        prices: const [100, 105, 99],
        reversalPct: 5,
      );

      final renkoA = RenkoChartConfig(
        prices: const [100, 101, 103],
        brickSize: 1,
      );
      final renkoB = RenkoChartConfig(
        prices: const [100, 101, 104],
        brickSize: 1,
      );

      final macdA = MacdChartConfig(
        prices: List<double>.generate(40, (i) => 100 + i.toDouble()),
      );
      final macdB = MacdChartConfig(
        prices: List<double>.generate(40, (i) => 100 + i.toDouble()),
        signal: 10,
      );

      final candleA = CandlestickChartConfig(
        type: ChartType.candlestick,
        bars: const [
          OhlcBar(
            date: '2026-01-01',
            open: 100,
            high: 110,
            low: 95,
            close: 108,
            volume: 1200,
          ),
          OhlcBar(
            date: '2026-01-02',
            open: 108,
            high: 114,
            low: 104,
            close: 112,
            volume: 1400,
          ),
        ],
      );
      final candleB = CandlestickChartConfig(
        type: ChartType.candlestick,
        bars: const [
          OhlcBar(
            date: '2026-01-01',
            open: 100,
            high: 110,
            low: 95,
            close: 108,
            volume: 1200,
          ),
          OhlcBar(
            date: '2026-01-02',
            open: 108,
            high: 114,
            low: 104,
            close: 113,
            volume: 1400,
          ),
        ],
      );
      final ohlcA = CandlestickChartConfig(
        type: ChartType.ohlc,
        showVolume: false,
        bars: const [
          OhlcBar(
            date: '2026-01-01',
            open: 100,
            high: 110,
            low: 95,
            close: 108,
          ),
        ],
      );

      expect((kagiA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((renkoA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((macdA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((candleA.toJson()['series'] as List).first['data'], hasLength(2));
      expect(ChartDataSignature.fromConfig(candleA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(ohlcA).typeString, 'ohlc');
      expect(ChartDataSignature.fromConfig(ohlcA).dataPointCount, 1);
      expect(
        ChartDataSignature.fromConfig(kagiA).hash,
        isNot(ChartDataSignature.fromConfig(kagiB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(renkoA).hash,
        isNot(ChartDataSignature.fromConfig(renkoB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(macdA).hash,
        isNot(ChartDataSignature.fromConfig(macdB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(candleA).hash,
        isNot(ChartDataSignature.fromConfig(candleB).hash),
      );
    });

    test('mixed radial and axis configs include payload data', () {
      final comboA = ComboChartConfig(
        categories: const ['Q1', 'Q2'],
        comboSeries: [
          ComboSeries(
            base: Series(
              type: ChartType.bar,
              name: 'Revenue',
              data: const [10, 20],
            ),
          ),
          ComboSeries(
            base: Series(
              type: ChartType.line,
              name: 'Margin',
              data: const [5, 7],
            ),
            seriesType: ComboSeriesType.line,
            yAxis: 1,
          ),
        ],
      );
      final comboB = ComboChartConfig(
        categories: const ['Q1', 'Q2'],
        comboSeries: [
          ComboSeries(
            base: Series(
              type: ChartType.bar,
              name: 'Revenue',
              data: const [10, 21],
            ),
          ),
          ComboSeries(
            base: Series(
              type: ChartType.line,
              name: 'Margin',
              data: const [5, 7],
            ),
            seriesType: ComboSeriesType.line,
            yAxis: 1,
          ),
        ],
      );

      final radarA = RadarChartConfig(
        axes: const [
          RadarAxis(name: 'Speed'),
          RadarAxis(name: 'Power'),
        ],
        series: [
          Series(type: ChartType.radar, data: const [80, 70]),
        ],
      );
      final radarB = RadarChartConfig(
        axes: const [
          RadarAxis(name: 'Speed'),
          RadarAxis(name: 'Power'),
        ],
        startAngleDeg: -45,
        series: [
          Series(type: ChartType.radar, data: const [80, 70]),
        ],
      );

      final polarBarA = PolarBarChartConfig(
        categories: const ['A', 'B'],
        series: [
          Series(type: ChartType.polarBar, data: const [3, 4]),
        ],
      );
      final polarBarB = PolarBarChartConfig(
        categories: const ['A', 'B'],
        stacked: true,
        series: [
          Series(type: ChartType.polarBar, data: const [3, 4]),
        ],
      );

      final polarLineA = PolarLineChartConfig(
        categories: const ['N', 'E'],
        series: [
          Series(type: ChartType.polarLine, data: const [1, 2]),
        ],
      );
      final polarLineB = PolarLineChartConfig(
        categories: const ['N', 'E'],
        series: [
          Series(type: ChartType.polarLine, data: const [1, 3]),
        ],
      );

      final rainfallA = RainfallChartConfig(
        categories: const ['Jan', 'Feb'],
        series: [
          Series(type: ChartType.bar, data: const [20, 30]),
          Series(type: ChartType.line, data: const [12, 14]),
        ],
      );
      final rainfallB = RainfallChartConfig(
        categories: const ['Jan', 'Feb'],
        showLine: false,
        series: [
          Series(type: ChartType.bar, data: const [20, 30]),
          Series(type: ChartType.line, data: const [12, 14]),
        ],
      );

      final multiXA = MultiXAxesChartConfig(
        xAxes: const [
          XAxisDef(label: 'Month', categories: ['Jan', 'Feb']),
        ],
        series: [
          Series(type: ChartType.multiXAxes, data: const [4, 8]),
        ],
      );
      final multiXB = MultiXAxesChartConfig(
        xAxes: const [
          XAxisDef(label: 'Month', categories: ['Jan', 'Mar']),
        ],
        series: [
          Series(type: ChartType.multiXAxes, data: const [4, 8]),
        ],
      );

      expect((comboA.toJson()['series'] as List).first['seriesType'], 'bar');
      expect((radarA.toJson()['axes'] as List).first['name'], 'Speed');
      expect((polarBarA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((polarLineA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((rainfallA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((multiXA.toJson()['xAxes'] as List).first['categories'], [
        'Jan',
        'Feb',
      ]);
      expect(
        ChartDataSignature.fromConfig(comboA).hash,
        isNot(ChartDataSignature.fromConfig(comboB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(radarA).hash,
        isNot(ChartDataSignature.fromConfig(radarB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(polarBarA).hash,
        isNot(ChartDataSignature.fromConfig(polarBarB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(polarLineA).hash,
        isNot(ChartDataSignature.fromConfig(polarLineB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(rainfallA).hash,
        isNot(ChartDataSignature.fromConfig(rainfallB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(multiXA).hash,
        isNot(ChartDataSignature.fromConfig(multiXB).hash),
      );
    });

    test('timeline and standalone configs include payload data', () {
      final largeAreaA = LargeScaleAreaConfig(
        xData: const [0, 1, 2],
        yData: const [10, 20, 15],
      );
      final largeAreaB = LargeScaleAreaConfig(
        xData: const [0, 1, 2],
        yData: const [10, 21, 15],
      );

      final areaTimeA = AreaTimeAxisConfig(
        points: [
          TimePoint(time: DateTime.utc(2026, 1, 1), value: 10),
          TimePoint(time: DateTime.utc(2026, 1, 2), value: 12),
        ],
      );
      final areaTimeB = AreaTimeAxisConfig(
        points: [
          TimePoint(time: DateTime.utc(2026, 1, 1), value: 10),
          TimePoint(time: DateTime.utc(2026, 1, 2), value: 13),
        ],
      );

      final waterfallA = WaterfallChartConfig(
        items: const [
          WaterfallItem(
            name: 'Opening',
            value: 100,
            itemType: WaterfallItemType.total,
          ),
          WaterfallItem(name: 'Revenue', value: 40),
        ],
      );
      final waterfallB = WaterfallChartConfig(
        items: const [
          WaterfallItem(
            name: 'Opening',
            value: 100,
            itemType: WaterfallItemType.total,
          ),
          WaterfallItem(name: 'Revenue', value: 41),
        ],
      );

      final ganttA = GanttChartConfig(
        tasks: [
          GanttTask(
            id: 't1',
            name: 'Research',
            start: DateTime.utc(2026, 1, 1),
            end: DateTime.utc(2026, 1, 5),
            progress: 50,
          ),
        ],
      );
      final ganttB = GanttChartConfig(
        tasks: [
          GanttTask(
            id: 't1',
            name: 'Research',
            start: DateTime.utc(2026, 1, 1),
            end: DateTime.utc(2026, 1, 6),
            progress: 50,
          ),
        ],
      );

      expect(largeAreaA.toJson()['xData'], [0, 1, 2]);
      expect((areaTimeA.toJson()['points'] as List), hasLength(2));
      expect((waterfallA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((ganttA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect(ChartDataSignature.fromConfig(largeAreaA).seriesCount, 1);
      expect(ChartDataSignature.fromConfig(areaTimeA).seriesCount, 1);
      expect(ChartDataSignature.fromConfig(largeAreaA).dataPointCount, 3);
      expect(ChartDataSignature.fromConfig(areaTimeA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(waterfallA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(ganttA).dataPointCount, 1);
      expect(
        ChartDataSignature.fromConfig(largeAreaA).hash,
        isNot(ChartDataSignature.fromConfig(largeAreaB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(areaTimeA).hash,
        isNot(ChartDataSignature.fromConfig(areaTimeB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(waterfallA).hash,
        isNot(ChartDataSignature.fromConfig(waterfallB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(ganttA).hash,
        isNot(ChartDataSignature.fromConfig(ganttB).hash),
      );
    });

    test('comparison and distribution configs include payload data', () {
      final slopeA = SlopeChartConfig(
        columnLabels: const ['Before', 'After'],
        series: [
          Series(type: ChartType.slope, name: 'Revenue', data: const [10, 20]),
        ],
      );
      final slopeB = SlopeChartConfig(
        columnLabels: const ['Before', 'After'],
        series: [
          Series(type: ChartType.slope, name: 'Revenue', data: const [10, 21]),
        ],
      );

      final dumbbellA = DumbbellChartConfig(
        categories: const ['A', 'B'],
        series: [
          Series(type: ChartType.dumbbell, name: 'Low', data: const [1, 2]),
          Series(type: ChartType.dumbbell, name: 'High', data: const [3, 4]),
        ],
      );
      final dumbbellB = DumbbellChartConfig(
        categories: const ['A', 'B'],
        showValues: false,
        series: [
          Series(type: ChartType.dumbbell, name: 'Low', data: const [1, 2]),
          Series(type: ChartType.dumbbell, name: 'High', data: const [3, 4]),
        ],
      );

      final areaBumpA = AreaBumpChartConfig(
        periods: const ['Q1', 'Q2'],
        bumps: const [
          AreaBumpSeries(name: 'Product A', ranks: [1, 2]),
          AreaBumpSeries(name: 'Product B', ranks: [2, 1]),
        ],
      );
      final areaBumpB = AreaBumpChartConfig(
        periods: const ['Q1', 'Q2'],
        bumps: const [
          AreaBumpSeries(name: 'Product A', ranks: [1, 1]),
          AreaBumpSeries(name: 'Product B', ranks: [2, 2]),
        ],
      );

      final ridgeA = RidgelineChartConfig(
        categories: const ['G1'],
        series: [
          Series(
            type: ChartType.ridgeline,
            data: const [
              [1, 2, 3],
            ],
          ),
        ],
      );
      final ridgeB = RidgelineChartConfig(
        categories: const ['G1'],
        fillOpacity: 0.4,
        series: [
          Series(
            type: ChartType.ridgeline,
            data: const [
              [1, 2, 3],
            ],
          ),
        ],
      );

      final stripA = StripChartConfig(
        categories: const ['G1'],
        series: [
          Series(
            type: ChartType.strip,
            data: const [
              [4, 5, 6],
            ],
          ),
        ],
      );
      final stripB = StripChartConfig(
        categories: const ['G1'],
        jitterSeed: 7,
        series: [
          Series(
            type: ChartType.strip,
            data: const [
              [4, 5, 6],
            ],
          ),
        ],
      );

      final errorA = ErrorBarChartConfig(
        categories: const ['A'],
        errorData: const [
          [ErrorBarPoint(mean: 10, lower: 8, upper: 12)],
        ],
      );
      final errorB = ErrorBarChartConfig(
        categories: const ['A'],
        errorData: const [
          [ErrorBarPoint(mean: 10, lower: 7, upper: 12)],
        ],
      );

      expect((slopeA.toJson()['series'] as List).first['data'], [10, 20]);
      expect((dumbbellA.toJson()['series'] as List), hasLength(2));
      expect((areaBumpA.toJson()['series'] as List).first['ranks'], [1, 2]);
      expect((ridgeA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((stripA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect((errorA.toJson()['series'] as List).first['data'], isNotEmpty);
      expect(
        ChartDataSignature.fromConfig(slopeA).hash,
        isNot(ChartDataSignature.fromConfig(slopeB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(dumbbellA).hash,
        isNot(ChartDataSignature.fromConfig(dumbbellB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(areaBumpA).hash,
        isNot(ChartDataSignature.fromConfig(areaBumpB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(ridgeA).hash,
        isNot(ChartDataSignature.fromConfig(ridgeB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(stripA).hash,
        isNot(ChartDataSignature.fromConfig(stripB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(errorA).hash,
        isNot(ChartDataSignature.fromConfig(errorB).hash),
      );
    });

    test('flow map and custom pie configs include payload data', () {
      final sankeyA = SankeyChartConfig(
        nodes: [
          SankeyNode(id: 'visits', name: 'Visits', column: 0),
          SankeyNode(id: 'checkout', name: 'Checkout', column: 1),
        ],
        links: [
          SankeyLink(sourceId: 'visits', targetId: 'checkout', value: 42),
        ],
      );
      final sankeyB = SankeyChartConfig(
        nodes: [
          SankeyNode(id: 'visits', name: 'Visits', column: 0),
          SankeyNode(id: 'checkout', name: 'Checkout', column: 1),
        ],
        links: [
          SankeyLink(sourceId: 'visits', targetId: 'checkout', value: 43),
        ],
      );

      final choroplethA = ChoroplethChartConfig(
        regions: const [
          MapRegion(
            id: 'ID',
            name: 'Indonesia',
            value: 280,
            polygons: [
              [
                [95, -11],
                [141, -11],
                [141, 6],
                [95, 6],
              ],
            ],
          ),
        ],
      );
      final choroplethB = ChoroplethChartConfig(
        regions: const [
          MapRegion(
            id: 'ID',
            name: 'Indonesia',
            value: 281,
            polygons: [
              [
                [95, -11],
                [141, -11],
                [141, 6],
                [95, 6],
              ],
            ],
          ),
        ],
      );

      final customPieA = CustomizedPieConfig(
        slices: const [
          CustomPieSlice(name: 'A', value: 10, color: '#ff0000'),
          CustomPieSlice(name: 'B', value: 20, explode: 4),
        ],
      );
      final customPieB = CustomizedPieConfig(
        slices: const [
          CustomPieSlice(name: 'A', value: 11, color: '#ff0000'),
          CustomPieSlice(name: 'B', value: 20, explode: 4),
        ],
      );

      final labelPieA = PieLabelAlignConfig(
        slices: const [
          PieSlice2(name: 'A', value: 10),
          PieSlice2(name: 'B', value: 20),
        ],
      );
      final labelPieB = PieLabelAlignConfig(
        slices: const [
          PieSlice2(name: 'A', value: 10),
          PieSlice2(name: 'B', value: 21),
        ],
      );

      final specialPieA = PieSpecialLabelConfig(
        slices: const [
          SpecialLabelSlice(name: 'A', value: 10, subLabel: 'Alpha'),
          SpecialLabelSlice(name: 'B', value: 20, emoji: '*'),
        ],
      );
      final specialPieB = PieSpecialLabelConfig(
        slices: const [
          SpecialLabelSlice(name: 'A', value: 10, subLabel: 'Alpha'),
          SpecialLabelSlice(name: 'B', value: 20, emoji: '#'),
        ],
      );

      final sankeySeries = (sankeyA.toJson()['series'] as List).first as Map;
      final choroplethSeries =
          (choroplethA.toJson()['series'] as List).first as Map;
      expect(sankeySeries['nodes'], hasLength(2));
      expect(sankeySeries['links'], hasLength(1));
      expect(choroplethSeries['regions'], hasLength(1));
      expect(
        (customPieA.toJson()['series'] as List).first['data'],
        hasLength(2),
      );
      expect(
        (labelPieA.toJson()['series'] as List).first['data'],
        hasLength(2),
      );
      expect(
        (specialPieA.toJson()['series'] as List).first['data'],
        hasLength(2),
      );
      expect(ChartDataSignature.fromConfig(sankeyA).dataPointCount, 3);
      expect(ChartDataSignature.fromConfig(choroplethA).dataPointCount, 1);
      expect(ChartDataSignature.fromConfig(customPieA).dataPointCount, 2);
      expect(
        ChartDataSignature.fromConfig(sankeyA).hash,
        isNot(ChartDataSignature.fromConfig(sankeyB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(choroplethA).hash,
        isNot(ChartDataSignature.fromConfig(choroplethB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(customPieA).hash,
        isNot(ChartDataSignature.fromConfig(customPieB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(labelPieA).hash,
        isNot(ChartDataSignature.fromConfig(labelPieB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(specialPieA).hash,
        isNot(ChartDataSignature.fromConfig(specialPieB).hash),
      );
    });

    test('hierarchical configs count descendant nodes', () {
      final treemapPayload = <String, dynamic>{
        'type': 'treemap',
        'series': [
          {
            'data': [
              {
                'name': 'Tech',
                'value': 45,
                'children': [
                  {'name': 'AAPL', 'value': 20},
                  {'name': 'GOOGL', 'value': 15},
                ],
              },
              {'name': 'Finance', 'value': 30},
            ],
          },
        ],
      };
      final treemapA = TreemapChartConfig(
        nodes: const [
          TreemapNode(
            name: 'Tech',
            value: 45,
            children: [
              TreemapNode(name: 'AAPL', value: 20),
              TreemapNode(name: 'GOOGL', value: 15),
            ],
          ),
          TreemapNode(name: 'Finance', value: 30),
        ],
      );
      final treemapB = TreemapChartConfig(
        nodes: const [
          TreemapNode(
            name: 'Tech',
            value: 45,
            children: [
              TreemapNode(name: 'AAPL', value: 21),
              TreemapNode(name: 'GOOGL', value: 15),
            ],
          ),
          TreemapNode(name: 'Finance', value: 30),
        ],
      );

      final sunburstA = SunburstChartConfig(
        nodes: [
          SunburstNode(
            name: 'Product A',
            value: 40,
            children: [
              SunburstNode(name: 'Online', value: 28),
              SunburstNode(name: 'Offline', value: 12),
            ],
          ),
          SunburstNode(name: 'Product B', value: 35),
        ],
      );
      final sunburstB = SunburstChartConfig(
        nodes: [
          SunburstNode(
            name: 'Product A',
            value: 40,
            children: [
              SunburstNode(name: 'Online', value: 29),
              SunburstNode(name: 'Offline', value: 12),
            ],
          ),
          SunburstNode(name: 'Product B', value: 35),
        ],
      );

      expect(ChartDataSignature.fromJson(treemapPayload).dataPointCount, 4);
      expect(ChartDataSignature.fromConfig(treemapA).seriesCount, 1);
      expect(ChartDataSignature.fromConfig(treemapA).dataPointCount, 4);
      expect(ChartDataSignature.fromConfig(sunburstA).seriesCount, 1);
      expect(ChartDataSignature.fromConfig(sunburstA).dataPointCount, 4);
      expect(
        ChartDataSignature.fromConfig(treemapA).hash,
        isNot(ChartDataSignature.fromConfig(treemapB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(sunburstA).hash,
        isNot(ChartDataSignature.fromConfig(sunburstB).hash),
      );
    });

    test('raw variant collections are counted without normalized series', () {
      final calendarPie = ChartDataSignature.fromJson({
        'type': 'calendarPie',
        'days': [
          {
            'day': 1,
            'slices': [
              {'name': 'A', 'value': 10},
              {'name': 'B', 'value': 20},
            ],
          },
          {
            'day': 2,
            'slices': [
              {'name': 'C', 'value': 5},
            ],
          },
        ],
      });
      final nestedPie = ChartDataSignature.fromJson({
        'type': 'nestedPie',
        'rings': [
          {
            'name': 'Outer',
            'slices': [
              {'name': 'A', 'value': 10},
              {'name': 'B', 'value': 20},
            ],
          },
          {
            'name': 'Inner',
            'slices': [
              {'name': 'C', 'value': 5},
            ],
          },
        ],
      });
      final partitionPie = ChartDataSignature.fromJson({
        'type': 'partitionPie',
        'mainSlices': [
          {'name': 'A', 'value': 10},
          {'name': 'B', 'value': 20},
        ],
        'subSlices': [
          {'name': 'B1', 'value': 8},
          {'name': 'B2', 'value': 12},
        ],
      });
      final sankey = ChartDataSignature.fromJson({
        'type': 'sankey',
        'nodes': [
          {'id': 'source'},
          {'id': 'target'},
        ],
        'links': [
          {'source': 'source', 'target': 'target', 'value': 8},
        ],
      });
      final funnel = ChartDataSignature.fromJson({
        'type': 'funnel',
        'items': [
          {'name': 'Visits', 'value': 100},
          {'name': 'Leads', 'value': 40},
        ],
      });
      final trading = ChartDataSignature.fromJson({
        'type': 'kagi',
        'prices': [10, 12, 11],
      });

      expect(calendarPie.seriesCount, 1);
      expect(calendarPie.dataPointCount, 3);
      expect(nestedPie.seriesCount, 2);
      expect(nestedPie.dataPointCount, 3);
      expect(partitionPie.seriesCount, 2);
      expect(partitionPie.dataPointCount, 4);
      expect(sankey.seriesCount, 1);
      expect(sankey.dataPointCount, 3);
      expect(funnel.seriesCount, 1);
      expect(funnel.dataPointCount, 2);
      expect(trading.seriesCount, 1);
      expect(trading.dataPointCount, 3);
    });

    test('pie variant configs include payload data', () {
      const slicesA = [
        PieSlice(name: 'A', value: 10, color: '#ff0000'),
        PieSlice(name: 'B', value: 20),
      ];
      const slicesB = [
        PieSlice(name: 'A', value: 11, color: '#ff0000'),
        PieSlice(name: 'B', value: 20),
      ];

      final donutA = DonutChartConfig(slices: slicesA, centreLabel: 'Total');
      final donutB = DonutChartConfig(slices: slicesB, centreLabel: 'Total');
      final halfA = HalfDonutChartConfig(slices: slicesA, centreLabel: 'Half');
      final halfB = HalfDonutChartConfig(slices: slicesB, centreLabel: 'Half');
      final paddedA = PaddedPieChartConfig(slices: slicesA, padAngle: 0.08);
      final paddedB = PaddedPieChartConfig(slices: slicesB, padAngle: 0.08);
      final nightA = NightingaleChartConfig(slices: slicesA, mode: 'area');
      final nightB = NightingaleChartConfig(slices: slicesB, mode: 'area');

      final nestedA = NestedPieChartConfig(
        rings: const [
          PieRing(name: 'Outer', slices: slicesA),
          PieRing(
            name: 'Inner',
            slices: [PieSlice(name: 'C', value: 5)],
          ),
        ],
      );
      final nestedB = NestedPieChartConfig(
        rings: const [
          PieRing(name: 'Outer', slices: slicesB),
          PieRing(
            name: 'Inner',
            slices: [PieSlice(name: 'C', value: 5)],
          ),
        ],
      );

      final partitionA = PartitionPieChartConfig(
        mainSlices: slicesA,
        partitionIndex: 1,
        subSlices: const [
          PieSlice(name: 'B1', value: 8),
          PieSlice(name: 'B2', value: 12),
        ],
      );
      final partitionB = PartitionPieChartConfig(
        mainSlices: slicesA,
        partitionIndex: 1,
        subSlices: const [
          PieSlice(name: 'B1', value: 8),
          PieSlice(name: 'B2', value: 13),
        ],
      );

      final calendarA = CalendarPieChartConfig(
        year: 2026,
        month: 5,
        days: const [
          CalendarPieDay(day: 1, slices: slicesA),
          CalendarPieDay(day: 2, slices: [PieSlice(name: 'C', value: 5)]),
        ],
      );
      final calendarB = CalendarPieChartConfig(
        year: 2026,
        month: 5,
        days: const [
          CalendarPieDay(day: 1, slices: slicesB),
          CalendarPieDay(day: 2, slices: [PieSlice(name: 'C', value: 5)]),
        ],
      );

      final labelLineA = PieLabelLineConfig(slices: slicesA);
      final labelLineB = PieLabelLineConfig(slices: slicesB);

      expect((donutA.toJson()['series'] as List).first['data'], hasLength(2));
      expect((nestedA.toJson()['series'] as List), hasLength(2));
      expect((partitionA.toJson()['series'] as List), hasLength(2));
      expect((calendarA.toJson()['days'] as List), hasLength(2));
      expect(ChartDataSignature.fromConfig(donutA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(halfA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(paddedA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(nightA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(nestedA).seriesCount, 2);
      expect(ChartDataSignature.fromConfig(nestedA).dataPointCount, 3);
      expect(ChartDataSignature.fromConfig(partitionA).dataPointCount, 4);
      expect(ChartDataSignature.fromConfig(calendarA).dataPointCount, 3);
      expect(ChartDataSignature.fromConfig(labelLineA).dataPointCount, 2);
      expect(
        ChartDataSignature.fromConfig(donutA).hash,
        isNot(ChartDataSignature.fromConfig(donutB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(halfA).hash,
        isNot(ChartDataSignature.fromConfig(halfB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(paddedA).hash,
        isNot(ChartDataSignature.fromConfig(paddedB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(nightA).hash,
        isNot(ChartDataSignature.fromConfig(nightB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(nestedA).hash,
        isNot(ChartDataSignature.fromConfig(nestedB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(partitionA).hash,
        isNot(ChartDataSignature.fromConfig(partitionB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(calendarA).hash,
        isNot(ChartDataSignature.fromConfig(calendarB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(labelLineA).hash,
        isNot(ChartDataSignature.fromConfig(labelLineB).hash),
      );
    });

    test('line variant configs include style and point payload data', () {
      final areaPiecesA = AreaPiecesChartConfig(
        thresholds: const [
          AreaPieceThreshold(value: 10, color: '#00ff00'),
          AreaPieceThreshold(value: 20, color: '#ff0000'),
        ],
        categories: const ['A', 'B'],
        series: [
          Series(type: ChartType.line, data: const [8, 24]),
        ],
      );
      final areaPiecesB = AreaPiecesChartConfig(
        thresholds: const [
          AreaPieceThreshold(value: 10, color: '#00ff00'),
          AreaPieceThreshold(value: 22, color: '#ff0000'),
        ],
        categories: const ['A', 'B'],
        series: [
          Series(type: ChartType.line, data: const [8, 24]),
        ],
      );

      final lineGradientA = LineGradientChartConfig(
        categories: const ['A', 'B'],
        gradientStart: '#111111',
        gradientEnd: '#222222',
        series: [
          Series(type: ChartType.line, data: const [1, 2]),
        ],
      );
      final lineGradientB = LineGradientChartConfig(
        categories: const ['A', 'B'],
        gradientStart: '#111111',
        gradientEnd: '#333333',
        series: [
          Series(type: ChartType.line, data: const [1, 2]),
        ],
      );

      final confidenceA = LineConfidenceBandConfig(
        points: const [
          ConfidenceBandPoint(x: 0, y: 10, lower: 8, upper: 12),
          ConfidenceBandPoint(x: 1, y: 12, lower: 9, upper: 15),
        ],
      );
      final confidenceB = LineConfidenceBandConfig(
        points: const [
          ConfidenceBandPoint(x: 0, y: 10, lower: 8, upper: 12),
          ConfidenceBandPoint(x: 1, y: 13, lower: 9, upper: 15),
        ],
      );

      final styleA = LineStyleItemConfig(
        categories: const ['A', 'B'],
        styledSeries: const [
          LineStyleSeries(
            name: 'Dashed',
            data: [1, 2],
            lineStyle: LineStyleSpec(type: 'dashed', width: 3, dash: [6, 2]),
            itemStyle: ItemStyleSpec(shape: 'diamond', size: 8),
          ),
        ],
      );
      final styleB = LineStyleItemConfig(
        categories: const ['A', 'B'],
        styledSeries: const [
          LineStyleSeries(
            name: 'Dashed',
            data: [1, 3],
            lineStyle: LineStyleSpec(type: 'dashed', width: 3, dash: [6, 2]),
            itemStyle: ItemStyleSpec(shape: 'diamond', size: 8),
          ),
        ],
      );

      expect((areaPiecesA.toJson()['thresholds'] as List), hasLength(2));
      expect((areaPiecesA.toJson()['series'] as List).first['data'], [8, 24]);
      expect(lineGradientA.toJson()['gradientEnd'], '#222222');
      expect((confidenceA.toJson()['points'] as List), hasLength(2));
      expect(
        (styleA.toJson()['series'] as List).first['lineStyle']['type'],
        'dashed',
      );
      expect(ChartDataSignature.fromConfig(areaPiecesA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(lineGradientA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(confidenceA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(styleA).dataPointCount, 2);
      expect(
        ChartDataSignature.fromConfig(areaPiecesA).hash,
        isNot(ChartDataSignature.fromConfig(areaPiecesB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(lineGradientA).hash,
        isNot(ChartDataSignature.fromConfig(lineGradientB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(confidenceA).hash,
        isNot(ChartDataSignature.fromConfig(confidenceB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(styleA).hash,
        isNot(ChartDataSignature.fromConfig(styleB).hash),
      );
    });

    test('generated and interactive line configs include payload data', () {
      final marklineA = LineMarklineConfig(
        categories: const ['A', 'B', 'C'],
        series: [
          Series(type: ChartType.line, data: const [4, 8, 6]),
        ],
        marklines: const [
          MarkLine(label: 'Target', value: 7, color: '#ff0000'),
        ],
      );
      final marklineB = LineMarklineConfig(
        categories: const ['A', 'B', 'C'],
        series: [
          Series(type: ChartType.line, data: const [4, 8, 6]),
        ],
        marklines: const [
          MarkLine(label: 'Target', value: 9, color: '#ff0000'),
        ],
      );

      final logA = LogAxisChartConfig(
        categories: const ['A', 'B', 'C'],
        logBase: 10,
        series: [
          Series(type: ChartType.line, data: const [1, 10, 100]),
        ],
      );
      final logB = LogAxisChartConfig(
        categories: const ['A', 'B', 'C'],
        logBase: 2,
        series: [
          Series(type: ChartType.line, data: const [1, 10, 100]),
        ],
      );

      final functionA = FunctionPlotConfig(
        functions: [
          FunctionSeries.fromJson(const {'label': 'sin(x)'}),
        ],
        xMin: 0,
        xMax: 1,
        yMin: -1,
        yMax: 1,
        resolution: 5,
      );
      final functionB = FunctionPlotConfig(
        functions: [
          FunctionSeries.fromJson(const {'label': 'cos(x)'}),
        ],
        xMin: 0,
        xMax: 1,
        yMin: -1,
        yMax: 1,
        resolution: 5,
      );

      final matrixA = SparklineMatrixConfig(
        cells: const [
          SparklineMatrixCell(label: 'A', values: [1, 2, 3]),
          SparklineMatrixCell(label: 'B', values: [3, 2]),
        ],
      );
      final matrixB = SparklineMatrixConfig(
        cells: const [
          SparklineMatrixCell(label: 'A', values: [1, 2, 4]),
          SparklineMatrixCell(label: 'B', values: [3, 2]),
        ],
      );

      final intradayA = IntradayLineConfig(
        points: const [
          IntradayPoint(x: 9, y: 100),
          IntradayPoint(x: 10),
          IntradayPoint(x: 11, y: 102),
        ],
      );
      final intradayB = IntradayLineConfig(
        points: const [
          IntradayPoint(x: 9, y: 100),
          IntradayPoint(x: 10),
          IntradayPoint(x: 11, y: 103),
        ],
      );

      final clickA = LineClickAddConfig(
        initialX: const [0, 1, 2],
        initialY: const [10, 11, 12],
        seriesName: 'Editable',
      );
      final clickB = LineClickAddConfig(
        initialX: const [0, 1, 2],
        initialY: const [10, 11, 13],
        seriesName: 'Editable',
      );

      final dynamicA = DynamicTimeSeriesConfig(windowSize: 60);
      final dynamicB = DynamicTimeSeriesConfig(windowSize: 90);

      expect((marklineA.toJson()['series'] as List).first['data'], [4, 8, 6]);
      expect(marklineA.toJson()['marklines'], hasLength(1));
      expect(
        (functionA.toJson()['series'] as List).first['data'],
        hasLength(6),
      );
      expect((matrixA.toJson()['series'] as List), hasLength(2));
      expect((intradayA.toJson()['points'] as List), hasLength(3));
      expect((clickA.toJson()['series'] as List).first['data'], hasLength(3));
      expect(dynamicA.toJson()['windowSize'], 60);

      expect(ChartDataSignature.fromConfig(marklineA).dataPointCount, 3);
      expect(ChartDataSignature.fromConfig(logA).dataPointCount, 3);
      expect(ChartDataSignature.fromConfig(functionA).dataPointCount, 6);
      expect(ChartDataSignature.fromConfig(matrixA).seriesCount, 2);
      expect(ChartDataSignature.fromConfig(matrixA).dataPointCount, 5);
      expect(ChartDataSignature.fromConfig(intradayA).dataPointCount, 3);
      expect(ChartDataSignature.fromConfig(clickA).dataPointCount, 3);
      expect(ChartDataSignature.fromConfig(dynamicA).dataPointCount, 0);

      expect(
        ChartDataSignature.fromConfig(marklineA).hash,
        isNot(ChartDataSignature.fromConfig(marklineB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(logA).hash,
        isNot(ChartDataSignature.fromConfig(logB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(functionA).hash,
        isNot(ChartDataSignature.fromConfig(functionB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(matrixA).hash,
        isNot(ChartDataSignature.fromConfig(matrixB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(intradayA).hash,
        isNot(ChartDataSignature.fromConfig(intradayB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(clickA).hash,
        isNot(ChartDataSignature.fromConfig(clickB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(dynamicA).hash,
        isNot(ChartDataSignature.fromConfig(dynamicB).hash),
      );
    });

    test('bar variant configs include series and frame payload data', () {
      final backgroundA = BarBackgroundChartConfig(
        categories: const ['A', 'B'],
        series: [
          Series(type: ChartType.bar, data: const [10, 20]),
        ],
        trackOpacity: 0.2,
      );
      final backgroundB = BarBackgroundChartConfig(
        categories: const ['A', 'B'],
        series: [
          Series(type: ChartType.bar, data: const [10, 21]),
        ],
        trackOpacity: 0.2,
      );

      final raceA = BarRaceChartConfig(
        frames: const [
          BarRaceFrame(label: '2025', values: {'A': 10, 'B': 20}),
          BarRaceFrame(label: '2026', values: {'A': 12, 'B': 24}),
        ],
        markers: const {
          'A': BarRaceMarkerStyle(text: 'A', backgroundColor: '#E6F4FF'),
          'B': BarRaceMarkerStyle(imageAsset: 'assets/brand/b.png'),
        },
        frameDuration: 900,
        autoPlay: false,
        showStepControls: true,
      );
      final raceB = BarRaceChartConfig(
        frames: const [
          BarRaceFrame(label: '2025', values: {'A': 10, 'B': 20}),
          BarRaceFrame(label: '2026', values: {'A': 12, 'B': 25}),
        ],
        markers: const {
          'A': BarRaceMarkerStyle(text: 'A', backgroundColor: '#E6F4FF'),
          'B': BarRaceMarkerStyle(imageAsset: 'assets/brand/b.png'),
        },
        frameDuration: 900,
        autoPlay: false,
        showStepControls: true,
      );

      final gradientA = BarGradientChartConfig(
        categories: const ['A', 'B'],
        gradientStart: '#111111',
        gradientEnd: '#222222',
        series: [
          Series(type: ChartType.bar, data: const [5, 9]),
        ],
      );
      final gradientB = BarGradientChartConfig(
        categories: const ['A', 'B'],
        gradientStart: '#111111',
        gradientEnd: '#333333',
        series: [
          Series(type: ChartType.bar, data: const [5, 9]),
        ],
      );

      final rotationA = BarLabelRotationConfig(
        categories: const ['Long A', 'Long B'],
        labelRotation: 60,
        series: [
          Series(type: ChartType.bar, data: const [7, 11]),
        ],
      );
      final rotationB = BarLabelRotationConfig(
        categories: const ['Long A', 'Long B'],
        labelRotation: 30,
        series: [
          Series(type: ChartType.bar, data: const [7, 11]),
        ],
      );

      expect((backgroundA.toJson()['series'] as List).first['data'], [10, 20]);
      expect((raceA.toJson()['frames'] as List).first['values'], {
        'A': 10,
        'B': 20,
      });
      expect(raceA.toJson()['autoPlay'], isFalse);
      expect(raceA.toJson()['showStepControls'], isTrue);
      expect(raceA.toJson()['markers']['A']['text'], 'A');
      expect(
        raceA.toJson()['markers']['B']['imageAsset'],
        'assets/brand/b.png',
      );
      expect(gradientA.toJson()['gradientEnd'], '#222222');
      expect(rotationA.toJson()['labelRotation'], 60);
      expect(ChartDataSignature.fromConfig(backgroundA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(raceA).seriesCount, 1);
      expect(ChartDataSignature.fromConfig(raceA).dataPointCount, 4);
      expect(ChartDataSignature.fromConfig(gradientA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(rotationA).dataPointCount, 2);
      expect(
        ChartDataSignature.fromConfig(backgroundA).hash,
        isNot(ChartDataSignature.fromConfig(backgroundB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(raceA).hash,
        isNot(ChartDataSignature.fromConfig(raceB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(gradientA).hash,
        isNot(ChartDataSignature.fromConfig(gradientB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(rotationA).hash,
        isNot(ChartDataSignature.fromConfig(rotationB).hash),
      );
    });

    test('bar race parses shorthand frames and marker JSON', () {
      const payload = <String, dynamic>{
        'type': 'barRace',
        'categories': ['Alpha', 'Beta'],
        'frameLabels': ['2025', '2026'],
        'frames': [
          [10, 20],
          [12, 24],
        ],
        'markers': {
          'Alpha': {'text': 'A', 'backgroundColor': '#E6F4FF', 'size': 28},
        },
        'images': {'Beta': 'assets/beta.png'},
        'autoPlay': false,
        'showControls': true,
        'showStepControls': true,
      };
      final config = BarRaceChartConfig.fromJson(payload);
      final jsonSignature = ChartDataSignature.fromJson(payload);

      expect(config.frames, hasLength(2));
      expect(config.frames.first.label, '2025');
      expect(config.frames.first.values, {'Alpha': 10, 'Beta': 20});
      expect(config.markers['Alpha']?.text, 'A');
      expect(config.markers['Beta']?.imageAsset, 'assets/beta.png');
      expect(config.autoPlay, isFalse);
      expect(config.showControls, isTrue);
      expect(jsonSignature.seriesCount, 1);
      expect(jsonSignature.dataPointCount, 4);
      expect(ChartDataSignature.fromConfig(config).dataPointCount, 4);
    });

    test('remaining bar variants include payload and option data', () {
      final roundedA = BarRoundedStackedConfig(
        categories: const ['A', 'B'],
        cornerRadius: 8,
        showValues: true,
        series: [
          Series(type: ChartType.bar, data: const [10, 20]),
          Series(type: ChartType.bar, data: const [5, 8]),
        ],
      );
      final roundedB = BarRoundedStackedConfig(
        categories: const ['A', 'B'],
        cornerRadius: 12,
        showValues: true,
        series: [
          Series(type: ChartType.bar, data: const [10, 20]),
          Series(type: ChartType.bar, data: const [5, 8]),
        ],
      );

      final normalizedA = BarNormalizedConfig(
        categories: const ['A', 'B'],
        showPercentLabels: true,
        series: [
          Series(type: ChartType.bar, data: const [10, 20]),
          Series(type: ChartType.bar, data: const [30, 40]),
        ],
      );
      final normalizedB = BarNormalizedConfig(
        categories: const ['A', 'B'],
        showPercentLabels: false,
        series: [
          Series(type: ChartType.bar, data: const [10, 20]),
          Series(type: ChartType.bar, data: const [30, 40]),
        ],
      );

      final negativeA = NegativeBarConfig(
        categories: const ['Profit', 'Cost'],
        showValues: true,
        series: [
          Series(type: ChartType.bar, data: const [120, -80]),
        ],
      );
      final negativeB = NegativeBarConfig(
        categories: const ['Profit', 'Cost'],
        showValues: true,
        series: [
          Series(type: ChartType.bar, data: const [120, -81]),
        ],
      );

      final polarA = TangentialPolarBarConfig(
        categories: const ['Jan', 'Feb'],
        innerRadius: 0.35,
        series: [
          Series(type: ChartType.bar, data: const [90, 140]),
        ],
      );
      final polarB = TangentialPolarBarConfig(
        categories: const ['Jan', 'Feb'],
        innerRadius: 0.45,
        series: [
          Series(type: ChartType.bar, data: const [90, 140]),
        ],
      );

      final brushA = BarBrushConfig(
        categories: const ['A', 'B', 'C'],
        showValues: true,
        series: [
          Series(type: ChartType.bar, data: const [8, 12, 16]),
        ],
      );
      final brushB = BarBrushConfig(
        categories: const ['A', 'B', 'C'],
        showValues: true,
        series: [
          Series(type: ChartType.bar, data: const [8, 12, 17]),
        ],
      );

      expect((roundedA.toJson()['series'] as List).first['data'], [10, 20]);
      expect(roundedA.toJson()['cornerRadius'], 8);
      expect((normalizedA.toJson()['series'] as List).last['data'], [30, 40]);
      expect(normalizedA.toJson()['showPercentLabels'], isTrue);
      expect((negativeA.toJson()['series'] as List).first['data'], [120, -80]);
      expect(polarA.toJson()['innerRadius'], 0.35);
      expect((brushA.toJson()['series'] as List).first['data'], [8, 12, 16]);
      expect(brushA.toJson()['showValues'], isTrue);

      expect(ChartDataSignature.fromConfig(roundedA).dataPointCount, 4);
      expect(ChartDataSignature.fromConfig(normalizedA).dataPointCount, 4);
      expect(ChartDataSignature.fromConfig(negativeA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(polarA).dataPointCount, 2);
      expect(ChartDataSignature.fromConfig(brushA).dataPointCount, 3);
      expect(
        ChartDataSignature.fromConfig(roundedA).hash,
        isNot(ChartDataSignature.fromConfig(roundedB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(normalizedA).hash,
        isNot(ChartDataSignature.fromConfig(normalizedB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(negativeA).hash,
        isNot(ChartDataSignature.fromConfig(negativeB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(polarA).hash,
        isNot(ChartDataSignature.fromConfig(polarB).hash),
      );
      expect(
        ChartDataSignature.fromConfig(brushA).hash,
        isNot(ChartDataSignature.fromConfig(brushB).hash),
      );
    });
  });
}
