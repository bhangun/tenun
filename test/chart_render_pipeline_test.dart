import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun_core/tenun_core.dart';

void main() {
  group('ChartRenderPipeline diagnostics', () {
    setUp(() {
      pictureCache.clear();
    });

    test('reports cache misses, cache hits, and live paints', () {
      final cached = _CountingLayer('cached');
      final live = _CountingLayer('live', cacheable: false);
      final reports = <ChartRenderPipelineReport>[];
      final pipeline = ChartRenderPipeline([
        cached,
        live,
      ], onReport: reports.add);

      _paintPipeline(pipeline, const Size(100, 80));
      expect(cached.paintCount, 1);
      expect(live.paintCount, 1);
      expect(cached.sizeChangedCount, 1);
      expect(live.sizeChangedCount, 1);
      expect(reports.single.cacheMisses, 1);
      expect(reports.single.cacheHits, 0);
      expect(reports.single.livePaints, 1);

      _paintPipeline(pipeline, const Size(100, 80));
      expect(cached.paintCount, 1);
      expect(live.paintCount, 2);
      expect(cached.sizeChangedCount, 1);
      expect(live.sizeChangedCount, 1);
      expect(reports.last.cacheMisses, 0);
      expect(reports.last.cacheHits, 1);
      expect(reports.last.livePaints, 1);

      final json = reports.last.toJson();
      expect(json['layerCount'], 2);
      expect(json['cacheHits'], 1);
      expect(json['layers'], isA<List<dynamic>>());

      pipeline.dispose();
    });

    test('uses shared picture cache for retained cacheable layers', () {
      final layer = _CountingLayer('cached');
      final reports = <ChartRenderPipelineReport>[];
      final pipeline = ChartRenderPipeline([layer], onReport: reports.add);

      _paintPipeline(pipeline, const Size(100, 80));

      expect(layer.paintCount, 1);
      expect(pictureCache.size, 1);
      expect(pictureCache.stats.misses, 1);
      expect(reports.single.cacheMisses, 1);
      expect(reports.single.layers.single.retainedPicture, isTrue);

      _paintPipeline(pipeline, const Size(100, 80));

      expect(layer.paintCount, 1);
      expect(pictureCache.stats.hits, 1);
      expect(reports.last.cacheHits, 1);
      expect(reports.last.skippedPictureCacheWrites, 0);
      expect(reports.last.toJson()['skippedPictureCacheWrites'], 0);

      pipeline.dispose();

      expect(pictureCache.size, 0);
    });

    test('oversized cacheable layers bypass shared picture retention', () {
      final layer = _CountingLayer('huge');
      final reports = <ChartRenderPipelineReport>[];
      final pipeline = ChartRenderPipeline([layer], onReport: reports.add);

      _paintPipeline(pipeline, const Size(5000, 5000));
      _paintPipeline(pipeline, const Size(5000, 5000));

      expect(layer.paintCount, 2);
      expect(pictureCache.size, 0);
      expect(pictureCache.stats.skippedWrites, 2);
      expect(reports.last.cacheMisses, 1);
      expect(reports.last.cacheHits, 0);
      expect(reports.last.skippedPictureCacheWrites, 1);
      final jsonLayer = (reports.last.toJson()['layers'] as List).single;
      expect(jsonLayer['retainedPicture'], isFalse);
      expect(jsonLayer['skippedPictureCacheWrite'], isTrue);

      pipeline.dispose();
    });

    test('auto-clears dirty cacheable layers after recording', () {
      final layer = _CountingLayer('cacheable', clearDuringPaint: false);
      final pipeline = ChartRenderPipeline([layer], enableDiagnostics: true);

      _paintPipeline(pipeline, const Size(100, 80));
      expect(layer.paintCount, 1);
      expect(layer.isDirty, isFalse);

      _paintPipeline(pipeline, const Size(100, 80));
      expect(layer.paintCount, 1);
      expect(pipeline.lastReport?.cacheHits, 1);

      layer.markDirty();
      _paintPipeline(pipeline, const Size(100, 80));
      expect(layer.paintCount, 2);
      expect(pipeline.lastReport?.cacheMisses, 1);

      pipeline.dispose();
    });

    test('markDirty drops retained picture before the next paint', () {
      final layer = _CountingLayer('cacheable');
      final pipeline = ChartRenderPipeline([layer], enableDiagnostics: true);

      _paintPipeline(pipeline, const Size(100, 80));
      expect(layer.paintCount, 1);
      expect(layer.isDirty, isFalse);
      expect(pictureCache.size, 1);

      pipeline.markDirty<_CountingLayer>();
      expect(layer.isDirty, isTrue);
      expect(pictureCache.size, 0);

      _paintPipeline(pipeline, const Size(100, 80));
      expect(layer.paintCount, 2);
      expect(layer.isDirty, isFalse);
      expect(pictureCache.size, 1);
      expect(pipeline.lastReport?.cacheMisses, 1);

      pipeline.dispose();
    });

    test('markAllDirty drops every retained picture immediately', () {
      final first = _CountingLayer('first');
      final second = _CountingLayer('second');
      final pipeline = ChartRenderPipeline([
        first,
        second,
      ], enableDiagnostics: true);

      _paintPipeline(pipeline, const Size(100, 80));
      expect(first.paintCount, 1);
      expect(second.paintCount, 1);
      expect(pictureCache.size, 2);

      pipeline.markAllDirty();
      expect(first.isDirty, isTrue);
      expect(second.isDirty, isTrue);
      expect(pictureCache.size, 0);

      _paintPipeline(pipeline, const Size(100, 80));
      expect(first.paintCount, 2);
      expect(second.paintCount, 2);
      expect(pictureCache.size, 2);

      pipeline.dispose();
    });

    test('notifies each layer once when size changes', () {
      final layer = _CountingLayer('cached');
      final pipeline = ChartRenderPipeline([layer], enableDiagnostics: true);

      _paintPipeline(pipeline, const Size(100, 80));
      _paintPipeline(pipeline, const Size(120, 80));

      expect(layer.sizeChangedCount, 2);
      expect(layer.paintCount, 2);
      expect(pipeline.lastReport?.sizeChangedLayers, 1);

      pipeline.dispose();
    });

    test('skips painting and drops cached pictures for empty sizes', () {
      final layer = _CountingLayer('cached');
      final pipeline = ChartRenderPipeline([layer], enableDiagnostics: true);

      _paintPipeline(pipeline, const Size(100, 80));
      expect(layer.paintCount, 1);

      _paintPipeline(pipeline, const Size(0, 80));
      expect(layer.paintCount, 1);
      expect(layer.sizeChangedCount, 2);
      expect(pipeline.lastReport?.size, const Size(0, 80));
      expect(pipeline.lastReport?.cacheMisses, 0);
      expect(pipeline.lastReport?.cacheHits, 0);
      expect(pipeline.lastReport?.livePaints, 0);

      _paintPipeline(pipeline, const Size(100, 80));
      expect(layer.paintCount, 2);
      expect(pipeline.lastReport?.cacheMisses, 1);

      pipeline.dispose();
    });

    test('normalizes non-finite sizes before notifying layers', () {
      final layer = _CountingLayer('cached');
      final reports = <ChartRenderPipelineReport>[];
      final pipeline = ChartRenderPipeline([layer], onReport: reports.add);

      _paintPipeline(pipeline, const Size(double.nan, double.infinity));

      expect(layer.paintCount, 0);
      expect(layer.sizeChangedCount, 0);
      expect(reports.single.size, Size.zero);
      expect(reports.single.cacheMisses, 0);
      expect(reports.single.cacheHits, 0);
      expect(reports.single.livePaints, 0);

      _paintPipeline(pipeline, const Size(120, 80));
      expect(layer.paintCount, 1);
      expect(layer.sizeChangedCount, 1);
      expect(reports.last.size, const Size(120, 80));

      pipeline.dispose();
    });

    test('dispose is idempotent and blocks late paints or dirty marks', () {
      final layer = _CountingLayer('cached');
      final reports = <ChartRenderPipelineReport>[];
      final pipeline = ChartRenderPipeline([layer], onReport: reports.add);

      _paintPipeline(pipeline, const Size(100, 80));

      final lastReport = pipeline.lastReport;
      expect(pictureCache.size, 1);
      expect(layer.isDirty, isFalse);
      expect(pipeline.isDisposed, isFalse);

      pipeline.dispose();
      pipeline.dispose();

      expect(pipeline.isDisposed, isTrue);
      expect(pictureCache.size, 0);

      pipeline.setSize(const Size(200, 120));
      pipeline.markDirty<_CountingLayer>();
      pipeline.markAllDirty();
      _paintPipeline(pipeline, const Size(200, 120));

      expect(layer.paintCount, 1);
      expect(layer.sizeChangedCount, 1);
      expect(layer.isDirty, isFalse);
      expect(pictureCache.size, 0);
      expect(reports.length, 1);
      expect(pipeline.lastReport, same(lastReport));
    });
  });
}

void _paintPipeline(ChartRenderPipeline pipeline, Size size) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  pipeline.paint(canvas, size);
  recorder.endRecording().dispose();
}

class _CountingLayer extends BaseRenderLayer {
  @override
  final String name;

  @override
  final bool cacheable;

  final bool clearDuringPaint;
  int paintCount = 0;
  int sizeChangedCount = 0;

  _CountingLayer(
    this.name, {
    this.cacheable = true,
    this.clearDuringPaint = true,
  });

  @override
  void onSizeChanged(Size size) {
    sizeChangedCount++;
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintCount++;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
    if (clearDuringPaint) {
      clearDirty();
    }
  }
}
