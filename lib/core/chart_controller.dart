import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'json_value.dart';

// ---------------------------------------------------------------------------
// Value types
// ---------------------------------------------------------------------------

/// Represents a selected data point.
class ChartSelection {
  final int seriesIndex;
  final int dataIndex;
  final dynamic value;

  const ChartSelection({
    required this.seriesIndex,
    required this.dataIndex,
    this.value,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartSelection &&
          runtimeType == other.runtimeType &&
          seriesIndex == other.seriesIndex &&
          dataIndex == other.dataIndex &&
          JsonValue.deepEquals(value, other.value);

  @override
  int get hashCode =>
      Object.hash(seriesIndex, dataIndex, JsonValue.deepHash(value));

  /// Returns an immutable snapshot for JSON-like selected values.
  ChartSelection snapshot() {
    final frozenValue = _freezeSelectionValue(value);
    if (identical(frozenValue, value)) return this;
    return ChartSelection(
      seriesIndex: seriesIndex,
      dataIndex: dataIndex,
      value: frozenValue,
    );
  }

  @override
  String toString() =>
      'ChartSelection(series=$seriesIndex, data=$dataIndex, value=$value)';
}

/// Defines the visible x-range and zoom level.
class ZoomRange {
  final int start;
  final int end;
  final double factor;

  const ZoomRange({this.start = 0, this.end = -1, this.factor = 1.0});

  static const ZoomRange full = ZoomRange(start: 0, end: -1, factor: 1.0);

  bool get isZoomed => factor != 1.0 || start != 0 || end != -1;

  ChartIndexRange visibleIndexRange(int dataLength) {
    if (dataLength <= 0) return ChartIndexRange.empty;

    final normalizedRange = normalized();
    final maxIndex = dataLength - 1;
    final visibleStart = normalizedRange.start.clamp(0, maxIndex);
    final rawEnd = normalizedRange.end;
    final visibleEnd = rawEnd == -1 ? maxIndex : rawEnd.clamp(0, maxIndex);

    if (visibleEnd < visibleStart) return ChartIndexRange.empty;
    return ChartIndexRange(start: visibleStart, end: visibleEnd);
  }

  ZoomRange normalized() {
    var normalizedStart = start < 0 ? 0 : start;
    var normalizedEnd = end < -1 ? -1 : end;
    if (normalizedEnd >= 0 && normalizedEnd < normalizedStart) {
      final previousStart = normalizedStart;
      normalizedStart = normalizedEnd;
      normalizedEnd = previousStart;
    }
    final normalizedFactor = factor.isFinite && factor > 0 ? factor : 1.0;
    if (normalizedStart == start &&
        normalizedEnd == end &&
        normalizedFactor == factor) {
      return this;
    }
    return ZoomRange(
      start: normalizedStart,
      end: normalizedEnd,
      factor: normalizedFactor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZoomRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          factor == other.factor;

  @override
  int get hashCode => start.hashCode ^ end.hashCode ^ factor.hashCode;

  @override
  String toString() => 'ZoomRange($start..$end × $factor)';
}

class ChartIndexRange {
  final int start;
  final int end;

  const ChartIndexRange({required this.start, required this.end});

  static const empty = ChartIndexRange(start: 0, end: -1);

  bool get isEmpty => end < start;
  bool get isNotEmpty => !isEmpty;
  int get count => isEmpty ? 0 : end - start + 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartIndexRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => isEmpty ? 'ChartIndexRange.empty' : '$start..$end';
}

// ---------------------------------------------------------------------------
// ChartController
// ---------------------------------------------------------------------------

typedef DataPointTapCallback =
    void Function(int seriesIndex, int dataIndex, dynamic value);
typedef RangeSelectCallback = void Function(int startIndex, int endIndex);
typedef CrosshairCallback =
    void Function(int? seriesIndex, int? dataIndex, dynamic value);
typedef ZoomChangeCallback = void Function(double startFrac, double endFrac);

/// Programmatic control over a live chart widget.
class ChartController extends ChangeNotifier {
  bool _disposed = false;
  int _notificationBatchDepth = 0;
  bool _hasPendingNotification = false;

  /// Whether this controller has been disposed.
  bool get isDisposed => _disposed;

  /// Whether listener notifications are currently being coalesced.
  bool get isBatchingNotifications => _notificationBatchDepth > 0;

  // ---- Callbacks ----
  DataPointTapCallback? onDataPointTap;
  RangeSelectCallback? onRangeSelect;
  CrosshairCallback? onCrosshairMove;
  ZoomChangeCallback? onZoomChanged;

  // ---- Selection ----
  ChartSelection? _selection;
  ChartSelection? get selection => _selection;

  final StreamController<ChartSelection?> _selectionCtrl =
      StreamController.broadcast();

  Stream<ChartSelection?> get onSelectionChanged => _selectionCtrl.stream;

  void _notifyIfAlive() {
    if (_disposed) return;
    if (_notificationBatchDepth > 0) {
      _hasPendingNotification = true;
      return;
    }
    notifyListeners();
  }

  void _flushPendingNotificationIfNeeded() {
    if (_disposed || _notificationBatchDepth > 0 || !_hasPendingNotification) {
      return;
    }
    _hasPendingNotification = false;
    notifyListeners();
  }

  /// Coalesce multiple controller mutations into one listener notification.
  ///
  /// Selection/export streams still emit their events as the mutations happen,
  /// but chart repaint listeners are notified once after the outermost batch.
  void batchUpdate(VoidCallback updates) {
    if (_disposed) return;
    _notificationBatchDepth++;
    try {
      updates();
    } finally {
      _notificationBatchDepth--;
      _flushPendingNotificationIfNeeded();
    }
  }

  void _emitSelection(ChartSelection? selection) {
    if (_disposed || _selectionCtrl.isClosed) return;
    _selectionCtrl.add(selection);
  }

  void selectIndex(int dataIndex, {int seriesIndex = 0, dynamic value}) {
    if (_disposed) return;
    _selection = ChartSelection(
      seriesIndex: seriesIndex,
      dataIndex: dataIndex,
      value: value,
    ).snapshot();
    _emitSelection(_selection);
    onDataPointTap?.call(seriesIndex, dataIndex, value);
    _notifyIfAlive();
  }

  /// Synchronize selection state without firing user tap callbacks.
  ///
  /// Use this from controller bridges/sync groups when another chart is the
  /// interaction source. The [onSelectionChanged] stream and listeners still
  /// receive the state change.
  void syncSelection(ChartSelection? selection) {
    if (_disposed) return;
    final nextSelection = selection?.snapshot();
    if (_selection == nextSelection) return;
    _selection = nextSelection;
    _emitSelection(nextSelection);
    _notifyIfAlive();
  }

  void clearSelection() {
    if (_disposed) return;
    if (_selection == null) return;
    _selection = null;
    _emitSelection(null);
    _notifyIfAlive();
  }

  // ---- Highlight & Visibility ----
  final Set<int> _highlightedSeries = {};
  Set<int> get highlightedSeries => Set.unmodifiable(_highlightedSeries);

  void highlightSeries(int seriesIndex) {
    if (_disposed) return;
    if (_highlightedSeries.add(seriesIndex)) {
      _notifyIfAlive();
    }
  }

  void unhighlightSeries(int seriesIndex) {
    if (_disposed) return;
    if (_highlightedSeries.remove(seriesIndex)) {
      _notifyIfAlive();
    }
  }

  void toggleSeriesHighlight(int seriesIndex) {
    if (_disposed) return;
    if (_highlightedSeries.contains(seriesIndex)) {
      _highlightedSeries.remove(seriesIndex);
    } else {
      _highlightedSeries.add(seriesIndex);
    }
    _notifyIfAlive();
  }

  final Set<int> _hiddenSeries = {};
  Set<int> get hiddenSeries => Set.unmodifiable(_hiddenSeries);

  void toggleSeriesVisibility(int seriesIndex) {
    if (_disposed) return;
    if (_hiddenSeries.contains(seriesIndex)) {
      _hiddenSeries.remove(seriesIndex);
    } else {
      _hiddenSeries.add(seriesIndex);
    }
    _notifyIfAlive();
  }

  bool isSeriesVisible(int seriesIndex) => !_hiddenSeries.contains(seriesIndex);

  /// Synchronize highlight/visibility state without replaying UI callbacks.
  void syncSeriesState({Set<int>? highlightedSeries, Set<int>? hiddenSeries}) {
    if (_disposed) return;
    var changed = false;
    if (highlightedSeries != null &&
        !setEquals(_highlightedSeries, highlightedSeries)) {
      _highlightedSeries
        ..clear()
        ..addAll(highlightedSeries);
      changed = true;
    }
    if (hiddenSeries != null && !setEquals(_hiddenSeries, hiddenSeries)) {
      _hiddenSeries
        ..clear()
        ..addAll(hiddenSeries);
      changed = true;
    }
    if (changed) _notifyIfAlive();
  }

  // ---- Zoom & Pan ----
  ZoomRange _zoom = ZoomRange.full;
  ZoomRange get zoom => _zoom;

  double _panOffset = 0;
  double get panOffset => _panOffset;

  void syncViewport(ZoomRange zoom, double panOffset) {
    if (_disposed) return;
    final nextZoom = zoom.normalized();
    final nextPanOffset = _finiteOr(panOffset, 0);
    if (_zoom == nextZoom && _panOffset == nextPanOffset) return;
    _zoom = nextZoom;
    _panOffset = nextPanOffset;
    _notifyIfAlive();
  }

  void zoomTo({int start = 0, int end = -1, double factor = 1.0}) {
    if (_disposed) return;
    final nextZoom = ZoomRange(
      start: start,
      end: end,
      factor: factor,
    ).normalized();
    if (_zoom == nextZoom) return;
    _zoom = nextZoom;
    onZoomChanged?.call(_zoom.start.toDouble(), _zoom.end.toDouble());
    _notifyIfAlive();
  }

  /// Smoothly animate zoom to a fractional range [0..1]
  Future<void> animateToRange(
    double start,
    double end, {
    Duration duration = const Duration(milliseconds: 450),
  }) async {
    if (_disposed) return;
    if (!start.isFinite || !end.isFinite) return;
    // Note: Actual animation logic typically lives in the widget layer
    // using a Ticker. This method triggers the state change.
    final s = start.clamp(0.0, 1.0);
    final e = end.clamp(0.0, 1.0);

    // Fallback point count if not provided
    const totalPoints = 100;
    final startIdx = (s * (totalPoints - 1)).round();
    final endIdx = (e * (totalPoints - 1)).round();

    zoomTo(start: startIdx, end: endIdx);
    replay();
  }

  void resetZoom() {
    if (_disposed) return;
    if (_zoom == ZoomRange.full && _panOffset == 0) return;
    _zoom = ZoomRange.full;
    _panOffset = 0;
    _notifyIfAlive();
  }

  void pan(double deltaIndex) {
    if (_disposed) return;
    if (!deltaIndex.isFinite) return;
    if (deltaIndex == 0) return;
    _panOffset += deltaIndex;
    _notifyIfAlive();
  }

  // ---- Axis range override ----
  double? _yMin;
  double? _yMax;
  double? get yMin => _yMin;
  double? get yMax => _yMax;

  void setYRange(double min, double max) {
    if (_disposed) return;
    if (!min.isFinite || !max.isFinite || min == max) return;
    if (min > max) {
      final previousMin = min;
      min = max;
      max = previousMin;
    }
    if (_yMin == min && _yMax == max) return;
    _yMin = min;
    _yMax = max;
    _notifyIfAlive();
  }

  void clearYRange() {
    if (_disposed) return;
    if (_yMin == null && _yMax == null) return;
    _yMin = null;
    _yMax = null;
    _notifyIfAlive();
  }

  // ---- Data Version & Updates ----
  int _dataVersion = 0;
  int get dataVersion => _dataVersion;

  void incrementDataVersion() {
    if (_disposed) return;
    _dataVersion++;
    _notifyIfAlive();
  }

  void updateData(List<dynamic> newData) {
    if (_disposed) return;
    incrementDataVersion();
  }

  // ---- Animation trigger ----
  bool _animationTrigger = false;
  bool get animationTrigger => _animationTrigger;

  void replay() {
    if (_disposed) return;
    _animationTrigger = !_animationTrigger;
    _notifyIfAlive();
  }

  // ---- Filter state ----
  final Map<String, dynamic> _filters = {};
  Map<String, dynamic> get filters =>
      Map.unmodifiable(JsonValue.cloneMap(_filters));

  void setFilter(String key, dynamic value) {
    if (_disposed) return;
    final next = JsonValue.freeze(value);
    if (_filters.containsKey(key) &&
        JsonValue.deepEquals(_filters[key], next)) {
      return;
    }
    _filters[key] = next;
    _notifyIfAlive();
  }

  void removeFilter(String key) {
    if (_disposed) return;
    if (_filters.containsKey(key)) {
      _filters.remove(key);
      _notifyIfAlive();
    }
  }

  void clearFilters() {
    if (_disposed) return;
    if (_filters.isEmpty) return;
    _filters.clear();
    _notifyIfAlive();
  }

  /// Synchronize filter state without firing user interaction callbacks.
  void syncFilters(Map<String, dynamic> filters) {
    if (_disposed) return;
    final next = JsonValue.freezeMap(filters);
    if (JsonValue.deepEquals(_filters, next)) return;
    _filters
      ..clear()
      ..addAll(next);
    _notifyIfAlive();
  }

  // ---- Export & Image Capturing ----
  final StreamController<void> _exportCtrl = StreamController.broadcast();
  Stream<void> get onExportRequested => _exportCtrl.stream;

  void requestExport() {
    if (_disposed || _exportCtrl.isClosed) return;
    _exportCtrl.add(null);
  }

  Future<Uint8List?> exportToImage(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    if (_disposed) return null;
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(
        pixelRatio: pixelRatio.isFinite && pixelRatio > 0 ? pixelRatio : 1.0,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // ---- Hit Testing ----
  // This is usually implemented by the painter via a mixin or delegate
  dynamic resolveHitAt(ui.Offset localPos) => null;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _notificationBatchDepth = 0;
    _hasPendingNotification = false;
    _selectionCtrl.close();
    _exportCtrl.close();
    super.dispose();
  }
}

double _finiteOr(double value, double fallback) =>
    value.isFinite ? value : fallback;

Object? _freezeSelectionValue(Object? value) {
  if (value is! Map && value is! List) return value;
  try {
    return JsonValue.freeze(value);
  } catch (_) {
    return value;
  }
}
