import 'dart:ui' as ui;

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  setUp(() {
    clearChartRenderCaches();
    pictureCache.clear();
  });

  group('render object caches', () {
    test('color cache normalizes equivalent string keys and reports stats', () {
      final first = colorCache.resolve(' red ');
      final second = colorCache.resolve('RED');

      expect(first, second);
      expect(chartRenderCacheStats.colors.size, 1);
      expect(chartRenderCacheStats.colors.misses, 1);
      expect(chartRenderCacheStats.colors.hits, 1);
      expect(chartRenderCacheStats.colors.hitRate, closeTo(0.5, 1e-9));
      expect(chartRenderCacheStats.toJson()['colors']['requests'], 2);
    });

    test('color cache stays bounded with LRU eviction', () {
      String hex(int value) => '#${value.toRadixString(16).padLeft(6, '0')}';

      final maxSize = chartRenderCacheStats.colors.maxSize!;
      for (var i = 0; i < maxSize; i++) {
        colorCache.resolve(hex(i));
      }
      colorCache.resolve(hex(0));
      colorCache.resolve(hex(maxSize));

      expect(chartRenderCacheStats.colors.size, maxSize);
      expect(chartRenderCacheStats.colors.hits, 1);
      expect(chartRenderCacheStats.colors.misses, maxSize + 1);
      expect(chartRenderCacheStats.colors.evictions, 1);

      colorCache.resolve(hex(1));
      colorCache.resolve(hex(0));

      expect(chartRenderCacheStats.colors.hits, 2);
      expect(chartRenderCacheStats.colors.misses, maxSize + 2);
      expect(chartRenderCacheStats.colors.evictions, 2);
    });

    test('color cache reports malformed inputs as format errors', () {
      const malformed = [
        '#xyz',
        '#12345',
        'rgb(1, 2)',
        'rgb(1, nope, 3)',
        'rgb(1, 2, 3, 4)',
        'rgba(1, 2, 3)',
        'rgba(1, 2, 3, nope)',
        'rgba(1, 2, 3, nan)',
      ];

      for (final raw in malformed) {
        expect(
          () => colorCache.resolve(raw),
          throwsFormatException,
          reason: raw,
        );
      }

      expect(chartRenderCacheStats.colors.size, 0);
      expect(chartRenderCacheStats.colors.misses, malformed.length);
      expect(chartRenderCacheStats.colors.hits, 0);
    });

    test('color cache clamps valid functional color components', () {
      expect(
        colorCache.resolve('rgb(-10, 300, 20)'),
        const material.Color(0xFF00FF14),
      );
      expect(
        colorCache.resolve('rgba(10, 20, 30, 2)'),
        const material.Color(0xFF0A141E),
      );
      expect(
        colorCache.resolve('rgba(10, 20, 30, -1)'),
        const material.Color(0x000A141E),
      );
    });

    test('paint cache preserves distinct stroke widths', () {
      final thin = paintCache.stroke(material.Colors.blue, 1.04);
      final thick = paintCache.stroke(material.Colors.blue, 1.06);
      final thinAgain = paintCache.stroke(material.Colors.blue, 1.04);

      expect(thin.strokeWidth, closeTo(1.04, 1e-6));
      expect(thick.strokeWidth, closeTo(1.06, 1e-6));
      expect(identical(thin, thick), isFalse);
      expect(identical(thin, thinAgain), isTrue);
      expect(chartRenderCacheStats.paints.misses, 2);
      expect(chartRenderCacheStats.paints.hits, 1);
    });

    test('paint cache stays bounded with LRU eviction', () {
      final maxSize = chartRenderCacheStats.paints.maxSize!;
      for (var i = 0; i < maxSize; i++) {
        paintCache.stroke(material.Colors.blue, i.toDouble());
      }
      paintCache.stroke(material.Colors.blue, 0);
      paintCache.stroke(material.Colors.blue, maxSize.toDouble());

      expect(chartRenderCacheStats.paints.size, maxSize);
      expect(chartRenderCacheStats.paints.hits, 1);
      expect(chartRenderCacheStats.paints.misses, maxSize + 1);
      expect(chartRenderCacheStats.paints.evictions, 1);

      paintCache.stroke(material.Colors.blue, 1);
      paintCache.stroke(material.Colors.blue, 0);

      expect(chartRenderCacheStats.paints.hits, 2);
      expect(chartRenderCacheStats.paints.misses, maxSize + 2);
      expect(chartRenderCacheStats.paints.evictions, 2);
    });

    test('paint cache normalizes invalid stroke widths', () {
      final negative = paintCache.stroke(material.Colors.blue, -1);
      final nan = paintCache.stroke(material.Colors.blue, double.nan);
      final zero = paintCache.stroke(material.Colors.blue, 0);

      expect(negative.strokeWidth, 0);
      expect(identical(negative, nan), isTrue);
      expect(identical(negative, zero), isTrue);
      expect(chartRenderCacheStats.paints.misses, 1);
      expect(chartRenderCacheStats.paints.hits, 2);
    });

    test('text painter cache key includes full text style identity', () {
      final normal = textPainterCache.get(
        'Revenue',
        const material.TextStyle(
          fontSize: 12,
          fontWeight: material.FontWeight.w400,
        ),
      );
      final bold = textPainterCache.get(
        'Revenue',
        const material.TextStyle(
          fontSize: 12,
          fontWeight: material.FontWeight.w700,
        ),
      );
      final normalAgain = textPainterCache.get(
        'Revenue',
        const material.TextStyle(
          fontSize: 12,
          fontWeight: material.FontWeight.w400,
        ),
      );

      expect(identical(normal, bold), isFalse);
      expect(identical(normal, normalAgain), isTrue);
      expect(
        (normal.text as material.TextSpan).style?.fontWeight,
        material.FontWeight.w400,
      );
      expect(
        (bold.text as material.TextSpan).style?.fontWeight,
        material.FontWeight.w700,
      );
      expect(chartRenderCacheStats.textPainters.misses, 2);
      expect(chartRenderCacheStats.textPainters.hits, 1);
    });

    test('text painter cache keeps bounded LRU eviction metrics', () {
      const style = material.TextStyle(fontSize: 10);

      for (var i = 0; i < 401; i++) {
        textPainterCache.get('label-$i', style);
      }

      expect(textPainterCache.size, 400);
      expect(chartRenderCacheStats.textPainters.maxSize, 400);
      expect(chartRenderCacheStats.textPainters.evictions, 1);
    });

    test('text painter cache sanitizes invalid max widths', () {
      const style = material.TextStyle(fontSize: 12);

      final nan = textPainterCache.get('Revenue', style, maxWidth: double.nan);
      final unconstrained = textPainterCache.get('Revenue', style);
      final negative = textPainterCache.get('Revenue', style, maxWidth: -20);
      final negativeInfinity = textPainterCache.get(
        'Revenue',
        style,
        maxWidth: double.negativeInfinity,
      );

      expect(identical(nan, unconstrained), isTrue);
      expect(identical(negative, negativeInfinity), isTrue);
      expect(nan.width, greaterThanOrEqualTo(0));
      expect(negative.width, greaterThanOrEqualTo(0));
      expect(chartRenderCacheStats.textPainters.misses, 2);
      expect(chartRenderCacheStats.textPainters.hits, 2);
    });

    test('path cache reports hits, misses, and evictions', () {
      var builds = 0;

      ui.Path buildPath() {
        builds++;
        return ui.Path()
          ..moveTo(0, 0)
          ..lineTo(10, 10);
      }

      final first = pathCache.getOrBuild('series-a', buildPath);
      final second = pathCache.getOrBuild('series-a', buildPath);

      expect(identical(first, second), isTrue);
      expect(builds, 1);
      expect(chartRenderCacheStats.paths.misses, 1);
      expect(chartRenderCacheStats.paths.hits, 1);

      for (var i = 0; i < 200; i++) {
        pathCache.getOrBuild('series-$i', buildPath);
      }

      expect(pathCache.size, 200);
      expect(chartRenderCacheStats.paths.evictions, 1);
    });

    test(
      'picture cache tracks memory and evicts least recently used entries',
      () {
        final cache = PictureCache(maxMemoryBytes: 9000);
        addTearDown(cache.clear);
        var builds = 0;

        void draw(ui.Canvas canvas, ui.Size size) {
          builds++;
          canvas.drawRect(
            ui.Offset.zero & size,
            ui.Paint()..color = material.Colors.orange,
          );
        }

        final first = cache.getOrBuild('a', const ui.Size(40, 40), draw);
        final firstAgain = cache.getOrBuild('a', const ui.Size(40, 40), draw);
        expect(identical(first, firstAgain), isTrue);
        expect(cache.stats.hits, 1);
        expect(cache.stats.misses, 1);

        cache.getOrBuild('b', const ui.Size(40, 40), draw);

        expect(builds, 2);
        expect(cache.size, 1);
        expect(cache.stats.evictions, 1);
        expect(
          cache.currentMemoryBytes,
          cache.estimateMemoryBytes(const ui.Size(40, 40)),
        );
        expect(cache.stats.toJson()['requests'], 3);
      },
    );

    test('picture cache skips entries larger than the memory budget', () {
      final cache = PictureCache(maxMemoryBytes: 4096);
      addTearDown(cache.clear);
      var builds = 0;

      void draw(ui.Canvas canvas, ui.Size size) {
        builds++;
        canvas.drawRect(
          ui.Offset.zero & size,
          ui.Paint()..color = material.Colors.deepOrange,
        );
      }

      final first = cache.getOrBuild('large', const ui.Size(40, 40), draw);
      final second = cache.getOrBuild('large', const ui.Size(40, 40), draw);
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      expect(identical(first, second), isFalse);
      expect(builds, 2);
      expect(cache.size, 0);
      expect(cache.currentMemoryBytes, 0);
      expect(cache.stats.misses, 2);
      expect(cache.stats.hits, 0);
      expect(cache.stats.skippedWrites, 2);
      expect(cache.stats.toJson()['skippedWrites'], 2);
    });

    test(
      'picture cache treats non-positive memory budgets as no-retain mode',
      () {
        final cache = PictureCache(maxMemoryBytes: -1);
        addTearDown(cache.clear);
        var builds = 0;

        void draw(ui.Canvas canvas, ui.Size size) {
          builds++;
          canvas.drawRect(
            ui.Offset.zero & size,
            ui.Paint()..color = material.Colors.indigo,
          );
        }

        final picture = cache.getOrBuild('disabled', const ui.Size(1, 1), draw);
        addTearDown(picture.dispose);

        expect(builds, 1);
        expect(cache.maxMemoryBytes, 0);
        expect(cache.size, 0);
        expect(cache.currentMemoryBytes, 0);
        expect(cache.stats.skippedWrites, 1);
      },
    );

    test('picture cache rebuilds a key when canvas size changes', () {
      final cache = PictureCache(maxMemoryBytes: 128 * 1024);
      addTearDown(cache.clear);
      var builds = 0;

      void draw(ui.Canvas canvas, ui.Size size) {
        builds++;
        canvas.drawRect(
          ui.Offset.zero & size,
          ui.Paint()..color = material.Colors.teal,
        );
      }

      final first = cache.getOrBuild('layer', const ui.Size(40, 40), draw);
      final resized = cache.getOrBuild('layer', const ui.Size(80, 40), draw);
      final resizedAgain = cache.getOrBuild(
        'layer',
        const ui.Size(80, 40),
        draw,
      );

      expect(identical(first, resized), isFalse);
      expect(identical(resized, resizedAgain), isTrue);
      expect(builds, 2);
      expect(cache.stats.misses, 2);
      expect(cache.stats.hits, 1);
      expect(cache.size, 1);
      expect(
        cache.currentMemoryBytes,
        cache.estimateMemoryBytes(const ui.Size(80, 40)),
      );
    });

    test('picture cache memory estimate tolerates invalid dimensions', () {
      final cache = PictureCache();

      expect(
        cache.estimateMemoryBytes(const ui.Size(double.nan, double.infinity)),
        2048,
      );
      expect(cache.estimateMemoryBytes(const ui.Size(-10, 20)), 2048);
      expect(cache.estimateMemoryBytes(const ui.Size(10, 20)), 2848);
    });

    test('picture cache skips builder and retention for invalid sizes', () {
      final cache = PictureCache();
      addTearDown(cache.clear);
      var builds = 0;

      void draw(ui.Canvas canvas, ui.Size size) {
        builds++;
        canvas.drawRect(
          ui.Offset.zero & size,
          ui.Paint()..color = material.Colors.purple,
        );
      }

      final result = cache.getOrBuildWithReport(
        'invalid',
        const ui.Size(double.nan, double.infinity),
        draw,
      );
      addTearDown(result.picture.dispose);

      expect(builds, 0);
      expect(result.cacheHit, isFalse);
      expect(result.retained, isFalse);
      expect(result.skippedWrite, isTrue);
      expect(cache.size, 0);
      expect(cache.currentMemoryBytes, 0);
      expect(cache.stats.misses, 1);
      expect(cache.stats.skippedWrites, 1);
    });

    test('picture cache invalid size request drops stale retained key', () {
      final cache = PictureCache(maxMemoryBytes: 128 * 1024);
      addTearDown(cache.clear);
      var builds = 0;

      void draw(ui.Canvas canvas, ui.Size size) {
        builds++;
        canvas.drawRect(
          ui.Offset.zero & size,
          ui.Paint()..color = material.Colors.cyan,
        );
      }

      cache.getOrBuild('layer', const ui.Size(40, 40), draw);
      expect(cache.size, 1);
      expect(cache.currentMemoryBytes, greaterThan(0));

      final empty = cache.getOrBuildWithReport(
        'layer',
        const ui.Size(0, 40),
        draw,
      );
      addTearDown(empty.picture.dispose);

      expect(builds, 1);
      expect(empty.retained, isFalse);
      expect(empty.skippedWrite, isTrue);
      expect(cache.size, 0);
      expect(cache.currentMemoryBytes, 0);

      cache.getOrBuild('layer', const ui.Size(40, 40), draw);
      expect(builds, 2);
      expect(cache.stats.hits, 0);
      expect(cache.stats.misses, 3);
    });
  });
}
