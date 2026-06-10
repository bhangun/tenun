import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/core/render_layer.dart' as legacy;

void main() {
  group('legacy ChartRenderPipeline', () {
    test('notifies size changes once for cacheable layers', () {
      final layer = _CountingLayer('cached');
      final pipeline = legacy.ChartRenderPipeline([layer]);

      _paintPipeline(pipeline, const ui.Size(100, 80));
      _paintPipeline(pipeline, const ui.Size(100, 80));
      _paintPipeline(pipeline, const ui.Size(120, 80));

      expect(layer.sizeChangedCount, 2);
      expect(layer.paintCount, 2);
      expect(layer.isDirty, isFalse);

      pipeline.dispose();
    });

    test('normalizes invalid sizes and skips empty paints', () {
      final layer = _CountingLayer('cached');
      final pipeline = legacy.ChartRenderPipeline([layer]);

      _paintPipeline(pipeline, const ui.Size(double.nan, double.infinity));

      expect(layer.sizeChangedCount, 0);
      expect(layer.paintCount, 0);

      _paintPipeline(pipeline, const ui.Size(100, 80));
      expect(layer.sizeChangedCount, 1);
      expect(layer.paintCount, 1);

      _paintPipeline(pipeline, const ui.Size(0, 80));
      expect(layer.sizeChangedCount, 2);
      expect(layer.paintCount, 1);

      pipeline.dispose();
    });

    test('dispose is idempotent and blocks late work', () {
      final layer = _CountingLayer('cached');
      final pipeline = legacy.ChartRenderPipeline([layer]);

      _paintPipeline(pipeline, const ui.Size(100, 80));
      expect(pipeline.isDisposed, isFalse);

      pipeline.dispose();
      pipeline.dispose();

      expect(pipeline.isDisposed, isTrue);

      pipeline.setSize(const ui.Size(200, 120));
      pipeline.markDirty<_CountingLayer>();
      _paintPipeline(pipeline, const ui.Size(200, 120));

      expect(layer.sizeChangedCount, 1);
      expect(layer.paintCount, 1);
      expect(layer.isDirty, isFalse);
    });

    test('markAllDirty invalidates every cacheable layer', () {
      final first = _CountingLayer('first');
      final second = _CountingLayer('second');
      final pipeline = legacy.ChartRenderPipeline([first, second]);

      _paintPipeline(pipeline, const ui.Size(100, 80));
      _paintPipeline(pipeline, const ui.Size(100, 80));

      expect(first.paintCount, 1);
      expect(second.paintCount, 1);
      expect(first.isDirty, isFalse);
      expect(second.isDirty, isFalse);

      pipeline.markAllDirty();
      expect(first.isDirty, isTrue);
      expect(second.isDirty, isTrue);

      _paintPipeline(pipeline, const ui.Size(100, 80));
      expect(first.paintCount, 2);
      expect(second.paintCount, 2);
      expect(first.isDirty, isFalse);
      expect(second.isDirty, isFalse);

      pipeline.dispose();
    });
  });
}

void _paintPipeline(legacy.ChartRenderPipeline pipeline, ui.Size size) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  pipeline.paint(canvas, size);
  recorder.endRecording().dispose();
}

class _CountingLayer extends legacy.BaseRenderLayer {
  @override
  final String name;

  int paintCount = 0;
  int sizeChangedCount = 0;

  _CountingLayer(this.name);

  @override
  void onSizeChanged(ui.Size size) {
    sizeChangedCount++;
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    paintCount++;
    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()..color = const ui.Color(0xff1565c0),
    );
    clearDirty();
  }
}
