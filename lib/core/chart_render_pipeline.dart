// Structured render pipeline for chart painters.
//
// Replaces the monolithic `paint()` call in each chart with an ordered,
// composable layer stack. Each layer is responsible for a single concern:
// background, grid, data, labels, overlay, tooltip. Only dirty layers
// repaint — the rest are drawn from a raster cache.
//
// Benefits:
//  - Tooltip hover no longer triggers a full canvas repaint.
//  - Grid lines are cached as a [ui.Picture] and replayed cheaply.
//  - Individual series can be marked dirty independently (e.g. after
//    a single series data update).
//  - New chart types add layers without touching existing ones.
//
// Usage in a painter:
// ```dart
// class BarChartPainter extends ChartPainterBase {
//   @override
//   void paint(Canvas canvas, Size size) {
//     _pipeline
//       ..setSize(size)
//       ..paint(canvas);
//   }
//
//   late final _pipeline = ChartRenderPipeline([
//     BackgroundLayer(theme),
//     GridLayer(viewport, yTicks),
//     BarDataLayer(processed, viewport, theme),
//     DataLabelLayer(processed, viewport, theme),
//     CrosshairLayer(crosshairX, viewport, theme),
//     TooltipLayer(tooltipLines, tooltipAnchor, theme),
//   ]);
// }
// ```

import 'package:flutter/material.dart';

import 'chart_painter_base.dart';

import 'chart_cache.dart';
import 'picture_cache.dart';
import 'chart_theme.dart';

typedef ChartRenderPipelineDiagnosticsCallback =
    void Function(ChartRenderPipelineReport report);

// ---------------------------------------------------------------------------
// Paint diagnostics
// ---------------------------------------------------------------------------

/// Per-layer timing/cache report emitted by [ChartRenderPipeline].
class ChartRenderLayerReport {
  final String name;
  final bool cacheable;
  final bool dirtyBeforePaint;
  final bool sizeChanged;
  final bool cacheHit;
  final bool recordedPicture;
  final bool retainedPicture;
  final bool skippedPictureCacheWrite;
  final bool livePaint;
  final Duration paintDuration;

  const ChartRenderLayerReport({
    required this.name,
    required this.cacheable,
    required this.dirtyBeforePaint,
    required this.sizeChanged,
    required this.cacheHit,
    required this.recordedPicture,
    this.retainedPicture = false,
    this.skippedPictureCacheWrite = false,
    required this.livePaint,
    required this.paintDuration,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'cacheable': cacheable,
    'dirtyBeforePaint': dirtyBeforePaint,
    'sizeChanged': sizeChanged,
    'cacheHit': cacheHit,
    'recordedPicture': recordedPicture,
    'retainedPicture': retainedPicture,
    'skippedPictureCacheWrite': skippedPictureCacheWrite,
    'livePaint': livePaint,
    'paintMicros': paintDuration.inMicroseconds,
  };
}

/// Aggregate paint timing/cache report for one pipeline frame.
class ChartRenderPipelineReport {
  final Size size;
  final Duration totalPaintDuration;
  final List<ChartRenderLayerReport> layers;

  const ChartRenderPipelineReport({
    required this.size,
    required this.totalPaintDuration,
    required this.layers,
  });

  int get layerCount => layers.length;
  int get cacheHits => layers.where((l) => l.cacheHit).length;
  int get cacheMisses => layers.where((l) => l.recordedPicture).length;
  int get skippedPictureCacheWrites =>
      layers.where((l) => l.skippedPictureCacheWrite).length;
  int get livePaints => layers.where((l) => l.livePaint).length;
  int get dirtyLayers => layers.where((l) => l.dirtyBeforePaint).length;
  int get sizeChangedLayers => layers.where((l) => l.sizeChanged).length;

  Map<String, dynamic> toJson() => {
    'size': {'width': size.width, 'height': size.height},
    'totalPaintMicros': totalPaintDuration.inMicroseconds,
    'layerCount': layerCount,
    'cacheHits': cacheHits,
    'cacheMisses': cacheMisses,
    'skippedPictureCacheWrites': skippedPictureCacheWrites,
    'livePaints': livePaints,
    'dirtyLayers': dirtyLayers,
    'sizeChangedLayers': sizeChangedLayers,
    'layers': layers.map((l) => l.toJson()).toList(),
  };
}

// ---------------------------------------------------------------------------
// RenderLayer — abstract base for all paint layers
// ---------------------------------------------------------------------------

/// One composable layer in a [ChartRenderPipeline].
abstract class RenderLayer {
  /// Human-readable name — used for debug logging and profiling.
  String get name;

  /// Whether this layer should be cached as a [ui.Picture].
  ///
  /// - `true` → layer is recorded once and replayed on subsequent frames.
  ///   Set to `false` (via [markDirty]) to force a re-record.
  /// - `false` → layer is always drawn live (good for rapidly changing
  ///   overlays like tooltips and crosshairs).
  bool get cacheable => true;

  /// Whether this layer needs to be re-recorded on the next paint.
  bool get isDirty;

  /// Mark this layer as dirty — will be re-recorded next frame.
  void markDirty();

  /// Draw this layer onto [canvas].
  void paint(Canvas canvas, Size size);

  /// Called when canvas [size] changes so layers can recompute geometry.
  void onSizeChanged(Size size) {}
}

// ---------------------------------------------------------------------------
// _CachedLayer — wraps a RenderLayer in a ui.Picture cache
// ---------------------------------------------------------------------------

int _nextLayerCacheId = 0;

class _CachedLayer {
  final RenderLayer layer;
  final int _cacheId;
  Size _lastSize = Size.zero;

  _CachedLayer(this.layer) : _cacheId = _nextLayerCacheId++;

  String get _cacheKey => 'chart_render_pipeline_layer:$_cacheId:${layer.name}';

  void paintOnto(Canvas canvas, Size size) {
    _paintOntoFast(canvas, size);
  }

  ChartRenderLayerReport paintOntoWithReport(Canvas canvas, Size size) {
    final dirtyBeforePaint = layer.isDirty;
    final sizeChanged = size != _lastSize;
    final sw = Stopwatch()..start();
    var cacheHit = false;
    var recordedPicture = false;
    var retainedPicture = false;
    var skippedPictureCacheWrite = false;
    var livePaint = false;

    if (_isEmptySize(size)) {
      _discardPicture();
      _lastSize = size;
      sw.stop();
      return ChartRenderLayerReport(
        name: layer.name,
        cacheable: layer.cacheable,
        dirtyBeforePaint: dirtyBeforePaint,
        sizeChanged: sizeChanged,
        cacheHit: false,
        recordedPicture: false,
        retainedPicture: false,
        skippedPictureCacheWrite: false,
        livePaint: false,
        paintDuration: sw.elapsed,
      );
    }

    if (!layer.cacheable) {
      // Always live-draw non-cacheable layers.
      livePaint = true;
      layer.paint(canvas, size);
      _lastSize = size;
      _clearDirtyIfSupported();
    } else {
      final shouldInvalidate = layer.isDirty || sizeChanged;
      if (shouldInvalidate) {
        _discardPicture();
      }
      var didRecord = false;
      final result = pictureCache.getOrBuildWithReport(_cacheKey, size, (
        recordCanvas,
        recordSize,
      ) {
        didRecord = true;
        _lastSize = recordSize;
        layer.paint(recordCanvas, recordSize);
        _clearDirtyIfSupported();
      });
      if (!didRecord) {
        _lastSize = size;
      }
      cacheHit = result.cacheHit;
      recordedPicture = didRecord;
      retainedPicture = result.retained;
      skippedPictureCacheWrite = result.skippedWrite;
      canvas.drawPicture(result.picture);
      if (!result.retained) {
        result.picture.dispose();
      }
    }

    sw.stop();
    return ChartRenderLayerReport(
      name: layer.name,
      cacheable: layer.cacheable,
      dirtyBeforePaint: dirtyBeforePaint,
      sizeChanged: sizeChanged,
      cacheHit: cacheHit,
      recordedPicture: recordedPicture,
      retainedPicture: retainedPicture,
      skippedPictureCacheWrite: skippedPictureCacheWrite,
      livePaint: livePaint,
      paintDuration: sw.elapsed,
    );
  }

  void _paintOntoFast(Canvas canvas, Size size) {
    final sizeChanged = size != _lastSize;

    if (_isEmptySize(size)) {
      _discardPicture();
      _lastSize = size;
      return;
    }

    if (!layer.cacheable) {
      // Always live-draw non-cacheable layers.
      layer.paint(canvas, size);
      _lastSize = size;
      _clearDirtyIfSupported();
      return;
    }

    if (layer.isDirty || sizeChanged) {
      _discardPicture();
    }

    var didRecord = false;
    final result = pictureCache.getOrBuildWithReport(_cacheKey, size, (
      recordCanvas,
      recordSize,
    ) {
      didRecord = true;
      _lastSize = recordSize;
      layer.paint(recordCanvas, recordSize);
      _clearDirtyIfSupported();
    });
    if (!didRecord) {
      _lastSize = size;
    }

    canvas.drawPicture(result.picture);
    if (!result.retained) {
      result.picture.dispose();
    }
  }

  void _clearDirtyIfSupported() {
    final baseLayer = layer;
    if (baseLayer is BaseRenderLayer) {
      baseLayer.clearDirty();
    }
  }

  void dispose() {
    _discardPicture();
  }

  void markDirty() {
    layer.markDirty();
    _discardPicture();
  }

  void _discardPicture() {
    pictureCache.invalidate(_cacheKey);
  }
}

// ---------------------------------------------------------------------------
// ChartRenderPipeline
// ---------------------------------------------------------------------------

/// Orchestrates an ordered stack of [RenderLayer] objects.
///
/// Layers are painted in order (index 0 = bottom, last = top).
class ChartRenderPipeline {
  final List<_CachedLayer> _layers;
  final ChartRenderPipelineDiagnosticsCallback? onReport;
  final bool enableDiagnostics;
  Size _size = Size.zero;
  ChartRenderPipelineReport? _lastReport;
  bool _disposed = false;

  ChartRenderPipeline(
    List<RenderLayer> layers, {
    this.onReport,
    this.enableDiagnostics = false,
  }) : _layers = layers.map(_CachedLayer.new).toList(growable: false);

  bool get isDisposed => _disposed;
  ChartRenderPipelineReport? get lastReport => _lastReport;

  /// Update canvas size — propagated to all layers.
  void setSize(Size size) {
    if (_disposed) return;
    final safeSize = _safePaintSize(size);
    if (safeSize != _size) {
      _size = safeSize;
      for (final l in _layers) {
        l.layer.onSizeChanged(safeSize);
      }
    }
  }

  /// Execute all layers in order onto [canvas].
  void paint(Canvas canvas, Size size) {
    if (_disposed) return;
    final safeSize = _safePaintSize(size);
    setSize(safeSize);
    if (!enableDiagnostics && onReport == null) {
      for (final l in _layers) {
        l.paintOnto(canvas, safeSize);
      }
      return;
    }

    final sw = Stopwatch()..start();
    final layerReports = <ChartRenderLayerReport>[];
    for (final l in _layers) {
      layerReports.add(l.paintOntoWithReport(canvas, safeSize));
    }
    sw.stop();

    final report = ChartRenderPipelineReport(
      size: safeSize,
      totalPaintDuration: sw.elapsed,
      layers: List.unmodifiable(layerReports),
    );
    _lastReport = report;
    onReport?.call(report);
  }

  /// Mark a specific layer dirty by type [T].
  void markDirty<T extends RenderLayer>() {
    if (_disposed) return;
    for (final l in _layers) {
      if (l.layer is T) l.markDirty();
    }
  }

  /// Mark all layers dirty (equivalent to full repaint).
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

Size _safePaintSize(Size size) {
  final width = _safePaintDimension(size.width);
  final height = _safePaintDimension(size.height);
  if (width == size.width && height == size.height) return size;
  return Size(width, height);
}

double _safePaintDimension(double value) =>
    value.isFinite && value > 0 ? value : 0;

bool _isEmptySize(Size size) => size.width <= 0 || size.height <= 0;

// ---------------------------------------------------------------------------
// Base layer implementations
// ---------------------------------------------------------------------------

/// Base class that tracks a single dirty flag.
abstract class BaseRenderLayer implements RenderLayer {
  bool _dirty = true;

  @override
  bool get isDirty => _dirty;

  @override
  void markDirty() => _dirty = true;

  @override
  bool get cacheable => true;

  @override
  void onSizeChanged(Size size) {}

  /// Call at the end of [paint] to clear the dirty flag.
  void clearDirty() => _dirty = false;
}

// ---------------------------------------------------------------------------
// BackgroundLayer
// ---------------------------------------------------------------------------

class BackgroundLayer extends BaseRenderLayer {
  final ChartTheme theme;
  BackgroundLayer(this.theme);

  @override
  String get name => 'background';

  @override
  void paint(Canvas canvas, Size size) {
    if (theme.backgroundColor != Colors.transparent) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        paintCache.fill(theme.backgroundColor),
      );
    }
    clearDirty();
  }
}

// ---------------------------------------------------------------------------
// GridLayer
// ---------------------------------------------------------------------------

class GridLayer extends BaseRenderLayer {
  final ChartViewport viewport;
  final List<double> yTicks;
  final List<double> xPositions;
  final bool dashedH;
  final bool dashedV;
  final ChartTheme theme;

  GridLayer({
    required this.viewport,
    required this.theme,
    this.yTicks = const [],
    this.xPositions = const [],
    this.dashedH = true,
    this.dashedV = false,
  });

  @override
  String get name => 'grid';

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = paintCache.stroke(
      theme.gridColor,
      theme.spacing.gridLineWidth,
    );

    // Horizontal grid lines.
    for (final y in yTicks) {
      final cy = viewport.toCanvasY(y);
      canvas.drawLine(
        Offset(viewport.left, cy),
        Offset(viewport.right, cy),
        gridPaint,
      );
    }

    // Vertical grid lines.
    for (final x in xPositions) {
      canvas.drawLine(
        Offset(x, viewport.top),
        Offset(x, viewport.bottom),
        gridPaint,
      );
    }
    clearDirty();
  }
}

// ---------------------------------------------------------------------------
// CrosshairLayer — non-cacheable overlay
// ---------------------------------------------------------------------------

class CrosshairLayer extends BaseRenderLayer {
  double? crosshairX;
  double? crosshairY;
  final ChartViewport viewport;
  final ChartTheme theme;

  CrosshairLayer({
    required this.viewport,
    required this.theme,
    this.crosshairX,
    this.crosshairY,
  });

  @override
  String get name => 'crosshair';

  @override
  bool get cacheable => false; // Always drawn live.

  @override
  void paint(Canvas canvas, Size size) {
    if (crosshairX == null && crosshairY == null) return;
    final paint = paintCache.stroke(theme.crosshairColor, 1.0);
    if (crosshairX != null) {
      canvas.drawLine(
        Offset(crosshairX!, viewport.top),
        Offset(crosshairX!, viewport.bottom),
        paint,
      );
    }
    if (crosshairY != null) {
      canvas.drawLine(
        Offset(viewport.left, crosshairY!),
        Offset(viewport.right, crosshairY!),
        paint,
      );
    }
    clearDirty();
  }
}

// ---------------------------------------------------------------------------
// TooltipLayer — non-cacheable overlay
// ---------------------------------------------------------------------------

class TooltipLayer extends BaseRenderLayer {
  List<String>? lines;
  Offset? anchor;
  final ChartTheme theme;

  TooltipLayer({required this.theme, this.lines, this.anchor});

  @override
  String get name => 'tooltip';

  @override
  bool get cacheable => false;

  @override
  void paint(Canvas canvas, Size size) {
    if (lines == null || lines!.isEmpty || anchor == null) return;
    _drawTooltip(canvas, size, anchor!, lines!);
    clearDirty();
  }

  void _drawTooltip(
    Canvas canvas,
    Size canvasSize,
    Offset anchor,
    List<String> lines,
  ) {
    const padding = 8.0;
    const radius = 6.0;
    const lineSpacing = 4.0;

    final style = theme.typography.tooltipStyle.copyWith(
      color: theme.tooltipTextColor,
    );

    final painters = lines
        .map((l) => textPainterCache.get(l, style, maxWidth: 220))
        .toList();
    final maxW = painters.fold<double>(0, (m, p) => p.width > m ? p.width : m);
    final totalH =
        painters.fold<double>(0, (s, p) => s + p.height) +
        lineSpacing * (painters.length - 1);

    double x = anchor.dx + 12;
    double y = anchor.dy - totalH / 2 - padding;
    x = x.clamp(0, canvasSize.width - maxW - padding * 2 - 12);
    y = y.clamp(0, canvasSize.height - totalH - padding * 2);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, maxW + padding * 2, totalH + padding * 2),
      const Radius.circular(radius),
    );
    canvas.drawRRect(rect, paintCache.fill(theme.tooltipBackgroundColor));

    double textY = y + padding;
    for (final tp in painters) {
      tp.paint(canvas, Offset(x + padding, textY));
      textY += tp.height + lineSpacing;
    }
  }
}

// ---------------------------------------------------------------------------
// SelectionHighlightLayer — highlights a selected bar/segment
// ---------------------------------------------------------------------------

class SelectionHighlightLayer extends BaseRenderLayer {
  int? selectedIndex;
  final Color highlightColor;
  final double Function(int index) getX;
  final double slotWidth;
  final ChartViewport viewport;

  SelectionHighlightLayer({
    required this.getX,
    required this.slotWidth,
    required this.viewport,
    this.selectedIndex,
    this.highlightColor = const Color(0x33000000),
  });

  @override
  String get name => 'selection_highlight';

  @override
  bool get cacheable => false;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedIndex == null) return;
    final cx = getX(selectedIndex!);
    canvas.drawRect(
      Rect.fromLTWH(
        cx - slotWidth / 2,
        viewport.top,
        slotWidth,
        viewport.height,
      ),
      paintCache.fill(highlightColor),
    );
    clearDirty();
  }
}
