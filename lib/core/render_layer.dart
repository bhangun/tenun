import 'dart:ui' as ui;

/// Abstract base for composable chart render layers.
abstract class RenderLayer {
  String get name;
  bool get cacheable => true;
  bool get isDirty;
  void markDirty();
  void paint(ui.Canvas canvas, ui.Size size);
  void onSizeChanged(ui.Size size) {}
  void clearDirty();
}

/// Base implementation with dirty flag tracking.
abstract class BaseRenderLayer implements RenderLayer {
  bool _dirty = true;

  @override
  bool get isDirty => _dirty;

  @override
  void markDirty() => _dirty = true;

  @override
  bool get cacheable => true;

  @override
  void onSizeChanged(ui.Size size) {}

  @override
  void clearDirty() => _dirty = false;
}

/// Wraps a RenderLayer with `ui.Picture` caching & safe disposal.
class _CachedLayer {
  final RenderLayer layer;
  ui.Picture? _picture;
  ui.Size _lastSize = ui.Size.zero;

  _CachedLayer(this.layer);

  void paintOnto(ui.Canvas canvas, ui.Size size) {
    if (_isEmptySize(size)) {
      dispose();
      _lastSize = size;
      return;
    }

    if (!layer.cacheable) {
      layer.paint(canvas, size);
      _lastSize = size;
      return;
    }

    final sizeChanged = size != _lastSize;
    if (layer.isDirty || sizeChanged || _picture == null) {
      final recorder = ui.PictureRecorder();
      final recordCanvas = ui.Canvas(recorder);

      layer.paint(recordCanvas, size);
      _picture?.dispose(); // ✅ Dispose old picture before replacing
      _picture = recorder.endRecording();
      _lastSize = size;
      layer.clearDirty();
    }

    if (_picture != null) {
      canvas.drawPicture(_picture!);
    }
  }

  void dispose() {
    _picture?.dispose();
    _picture = null;
  }

  void markDirty() {
    layer.markDirty();
    dispose();
  }
}

/// Orchestrates layers in order.
class ChartRenderPipeline {
  final List<_CachedLayer> _layers;
  ui.Size _size = ui.Size.zero;
  bool _disposed = false;

  ChartRenderPipeline(List<RenderLayer> layers)
    : _layers = layers.map(_CachedLayer.new).toList(growable: false);

  bool get isDisposed => _disposed;

  void setSize(ui.Size size) {
    if (_disposed) return;
    final safeSize = _safePaintSize(size);
    if (safeSize != _size) {
      _size = safeSize;
      for (final l in _layers) {
        l.layer.onSizeChanged(safeSize);
      }
    }
  }

  void paint(ui.Canvas canvas, ui.Size size) {
    if (_disposed) return;
    final safeSize = _safePaintSize(size);
    setSize(safeSize);
    for (final l in _layers) {
      l.paintOnto(canvas, safeSize);
    }
  }

  void markDirty<T extends RenderLayer>() {
    if (_disposed) return;
    for (final l in _layers) {
      if (l.layer is T) {
        l.markDirty();
      }
    }
  }

  void markAllDirty() {
    if (_disposed) return;
    for (final l in _layers) {
      l.markDirty();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final l in _layers) {
      l.dispose();
    }
  }
}

ui.Size _safePaintSize(ui.Size size) {
  final width = _safePaintDimension(size.width);
  final height = _safePaintDimension(size.height);
  if (width == size.width && height == size.height) return size;
  return ui.Size(width, height);
}

double _safePaintDimension(double value) =>
    value.isFinite && value > 0 ? value : 0;

bool _isEmptySize(ui.Size size) => size.width <= 0 || size.height <= 0;
