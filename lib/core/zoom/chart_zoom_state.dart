// Core zoom and pan state for chart interactions.
//
// Design decisions:
// - Zoom is tracked in **data space** (xStart..xEnd), not pixel space.
//   This makes it independent of canvas size and correct after resize.
// - History stack enables programmatic drill-down / back navigation.
// - Velocity is stored for momentum panning (fling).
// - All mutations return a **new** [ChartZoomState] — the class is immutable,
//   making it trivial to hold in a [ValueNotifier] or [setState].
//
// Coordinate conventions:
//   xStart / xEnd are fractional [0..1] positions in the full data range,
//   where 0 = first data point and 1 = last data point.
//   This means zoom state is independent of the actual data length.

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../json_value.dart';

// ---------------------------------------------------------------------------
// ChartZoomState
// ---------------------------------------------------------------------------

/// Immutable zoom + pan state for one axis (X).
///
/// [xStart] and [xEnd] are normalised fractions of the full data range [0..1].
/// The visible window is `[xStart, xEnd]`.
class ChartZoomState {
  /// Visible window start — normalised [0..1] fraction of full data range.
  final double xStart;

  /// Visible window end — normalised [0..1] fraction of full data range.
  final double xEnd;

  /// Current horizontal pan velocity (data-units per frame), used for fling.
  final double velocityX;

  /// Maximum allowed zoom ratio (visible fraction of data, e.g. 0.02 = 2%).
  final double minWindowFraction;

  /// The full history stack of previous zoom states (for back navigation).
  final List<_HistoryEntry> _history;

  static const ChartZoomState identity = ChartZoomState._(
    xStart: 0,
    xEnd: 1,
    velocityX: 0,
    minWindowFraction: 0.02,
    history: [],
  );

  const ChartZoomState._({
    required this.xStart,
    required this.xEnd,
    required this.velocityX,
    required this.minWindowFraction,
    required List<_HistoryEntry> history,
  }) : _history = history;

  factory ChartZoomState({
    double xStart = 0,
    double xEnd = 1,
    double velocityX = 0,
    double minWindowFraction = 0.02,
  }) {
    final minWindow = _sanitizeFraction(minWindowFraction, fallback: 0.02);
    final window = _normalizeWindow(xStart, xEnd, minWindowFraction: minWindow);
    return ChartZoomState._(
      xStart: window.start,
      xEnd: window.end,
      velocityX: velocityX.isFinite ? velocityX : 0,
      minWindowFraction: minWindow,
      history: const [],
    );
  }

  /// Current visible window size as a fraction of total data.
  double get windowSize => (xEnd - xStart).clamp(0.0, 1.0);

  /// True when showing the full data range.
  bool get isIdentity => xStart <= 0 && xEnd >= 1;

  /// True when there is zoom history to pop back to.
  bool get canPop => _history.isNotEmpty;

  /// How many history levels deep we are (= drill-down depth).
  int get depth => _history.length;

  /// Label of the current drill-down level (topmost history entry).
  String? get currentLabel => _history.isNotEmpty ? _history.last.label : null;

  /// All breadcrumb labels from root to current level.
  List<String> get breadcrumbs => _history.map((e) => e.label).toList();

  // --------------------------------------------------------------------------
  // Zoom operations — all return a new immutable state
  // --------------------------------------------------------------------------

  /// Zoom so that `[focalFraction - halfWindow .. focalFraction + halfWindow]`
  /// is visible, where [focalFraction] is the pinch focal point in [0..1].
  ChartZoomState zoomAroundFraction(
    double focalFraction,
    double scaleDelta, {
    bool pushHistory = false,
    String historyLabel = '',
  }) {
    if (!focalFraction.isFinite || !scaleDelta.isFinite || scaleDelta <= 0) {
      return this;
    }
    // New window half-size.
    final newHalf = (windowSize / 2) / scaleDelta;
    return _applyWindow(
      focalFraction - newHalf,
      focalFraction + newHalf,
      pushHistory: pushHistory,
      historyLabel: historyLabel,
    );
  }

  /// Zoom centred on screen-relative position [focalX] in [0..canvasWidth].
  ChartZoomState zoomAroundCanvas(
    double focalX,
    double canvasWidth,
    double scaleDelta, {
    bool pushHistory = false,
    String historyLabel = '',
  }) {
    if (canvasWidth <= 0 || !canvasWidth.isFinite || !focalX.isFinite) {
      return this;
    }
    final frac = xStart + (focalX / canvasWidth) * windowSize;
    return zoomAroundFraction(
      frac,
      scaleDelta,
      pushHistory: pushHistory,
      historyLabel: historyLabel,
    );
  }

  /// Pan by [deltaFraction] — positive = move viewport right (data moves left).
  ChartZoomState panBy(double deltaFraction) {
    return _applyWindow(xStart + deltaFraction, xEnd + deltaFraction);
  }

  /// Pan so that [frac] is at the left edge of the viewport.
  ChartZoomState panTo(double frac) {
    return _applyWindow(frac, frac + windowSize);
  }

  /// Pan to centre [frac] in the viewport.
  ChartZoomState centreOn(double frac) {
    final half = windowSize / 2;
    return _applyWindow(frac - half, frac + half);
  }

  /// Zoom to a specific data fraction range, pushing current state to history.
  ChartZoomState zoomToRange(
    double start,
    double end, {
    String label = 'Zoom',
  }) {
    return _applyWindow(start, end, pushHistory: true, historyLabel: label);
  }

  /// Replace the visible data fraction range without pushing history.
  ///
  /// This is intended for controller synchronization, where an external
  /// viewport source should not create a new drill-down/zoom breadcrumb level.
  ChartZoomState withVisibleRange(double start, double end) {
    return _applyWindow(start, end);
  }

  /// Apply fling velocity.
  ChartZoomState withVelocity(double vx) => ChartZoomState._(
    xStart: xStart,
    xEnd: xEnd,
    velocityX: vx.isFinite ? vx : 0,
    minWindowFraction: minWindowFraction,
    history: _history,
  );

  /// Advance one fling frame — decays velocity and applies pan.
  ///
  /// Returns new state. Returns same state when velocity has decayed to zero.
  ChartZoomState advanceFling({double friction = 0.9}) {
    if (velocityX.abs() < 0.0001) return this;
    final newVel = velocityX * _sanitizeFlingFriction(friction);
    final moved = panBy(velocityX);
    return moved.withVelocity(newVel);
  }

  bool get hasMomentum => velocityX.abs() >= 0.0001;

  /// Reset to full view without pushing history.
  ChartZoomState reset() => ChartZoomState._(
    xStart: 0,
    xEnd: 1,
    velocityX: 0,
    minWindowFraction: minWindowFraction,
    history: const [],
  );

  // --------------------------------------------------------------------------
  // Drill-down / history navigation
  // --------------------------------------------------------------------------

  /// Push current state onto history and zoom to [start..end].
  ///
  /// Call [pop] to return to the pre-drill state.
  ChartZoomState drillDown(
    double start,
    double end, {
    required String label,
    Map<String, dynamic>? metadata,
  }) {
    final entry = _HistoryEntry(
      xStart: xStart,
      xEnd: xEnd,
      label: label,
      metadata: _immutableMetadata(metadata),
    );
    final window = _normalizeWindow(
      start,
      end,
      minWindowFraction: minWindowFraction,
    );
    return ChartZoomState._(
      xStart: window.start,
      xEnd: window.end,
      velocityX: 0,
      minWindowFraction: minWindowFraction,
      history: [..._history, entry],
    );
  }

  /// Pop the most recent history entry, returning to the previous zoom level.
  ///
  /// Does nothing if [canPop] is false.
  ChartZoomState pop() {
    if (!canPop) return this;
    final prev = _history.last;
    return ChartZoomState._(
      xStart: prev.xStart,
      xEnd: prev.xEnd,
      velocityX: 0,
      minWindowFraction: minWindowFraction,
      history: _history.sublist(0, _history.length - 1),
    );
  }

  /// Pop all history entries and return to full view.
  ChartZoomState popAll() => reset();

  /// Metadata stored with the current drill-down entry.
  Map<String, dynamic> get currentMetadata => _history.isNotEmpty
      ? Map.unmodifiable(JsonValue.cloneMap(_history.last.metadata))
      : const {};

  // --------------------------------------------------------------------------
  // Data-space conversion helpers
  // --------------------------------------------------------------------------

  /// Convert a normalised fraction [0..1] to a data index in [0..dataLength-1].
  int fractionToIndex(double frac, int dataLength) {
    if (dataLength <= 1) return 0;
    final normalizedFraction = _sanitizeFraction(frac, fallback: 0);
    return (normalizedFraction * (dataLength - 1)).round().clamp(
      0,
      dataLength - 1,
    );
  }

  /// First visible data index.
  int startIndex(int dataLength) => fractionToIndex(xStart, dataLength);

  /// Last visible data index.
  int endIndex(int dataLength) => fractionToIndex(xEnd, dataLength);

  /// Number of visible data points.
  int visibleCount(int dataLength) {
    if (dataLength <= 0) return 0;
    return (endIndex(dataLength) - startIndex(dataLength) + 1).clamp(
      1,
      dataLength,
    );
  }

  /// Convert a canvas x-pixel to a data fraction.
  double canvasToFraction(double canvasX, double canvasWidth) {
    if (canvasWidth <= 0 || !canvasWidth.isFinite || !canvasX.isFinite) {
      return xStart;
    }
    return _sanitizeFraction(
      xStart + (canvasX / canvasWidth) * windowSize,
      fallback: xStart,
    );
  }

  /// Convert a data fraction to a canvas x-pixel.
  double fractionToCanvas(double frac, double canvasWidth) {
    if (windowSize <= 0 || !canvasWidth.isFinite || !frac.isFinite) return 0;
    return ((frac - xStart) / windowSize) * canvasWidth;
  }

  // --------------------------------------------------------------------------
  // Internal
  // --------------------------------------------------------------------------

  ChartZoomState _applyWindow(
    double newStart,
    double newEnd, {
    bool pushHistory = false,
    String historyLabel = '',
  }) {
    final window = _normalizeWindow(
      newStart,
      newEnd,
      minWindowFraction: minWindowFraction,
    );
    if (window.start == xStart && window.end == xEnd) {
      if (velocityX == 0) return this;
      return ChartZoomState._(
        xStart: xStart,
        xEnd: xEnd,
        velocityX: 0,
        minWindowFraction: minWindowFraction,
        history: _history,
      );
    }

    final history = pushHistory
        ? [
            ..._history,
            _HistoryEntry(
              xStart: xStart,
              xEnd: xEnd,
              label: historyLabel,
              metadata: const {},
            ),
          ]
        : _history;

    return ChartZoomState._(
      xStart: window.start,
      xEnd: window.end,
      velocityX: 0,
      minWindowFraction: minWindowFraction,
      history: history,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChartZoomState &&
      other.xStart == xStart &&
      other.xEnd == xEnd &&
      other.velocityX == velocityX &&
      other.minWindowFraction == minWindowFraction &&
      listEquals(other._history, _history);

  @override
  int get hashCode => Object.hash(
    xStart,
    xEnd,
    velocityX,
    minWindowFraction,
    Object.hashAll(_history),
  );

  @override
  String toString() =>
      'ChartZoomState(${(xStart * 100).toStringAsFixed(1)}%'
      '..${(xEnd * 100).toStringAsFixed(1)}%, depth=$depth)';
}

// ---------------------------------------------------------------------------
// Internal history entry
// ---------------------------------------------------------------------------

class _HistoryEntry {
  final double xStart;
  final double xEnd;
  final String label;
  final Map<String, dynamic> metadata;

  const _HistoryEntry({
    required this.xStart,
    required this.xEnd,
    required this.label,
    required this.metadata,
  });

  @override
  bool operator ==(Object other) =>
      other is _HistoryEntry &&
      other.xStart == xStart &&
      other.xEnd == xEnd &&
      other.label == label &&
      JsonValue.deepEquals(other.metadata, metadata);

  @override
  int get hashCode =>
      Object.hash(xStart, xEnd, label, JsonValue.deepHash(metadata));
}

({double start, double end}) _normalizeWindow(
  double rawStart,
  double rawEnd, {
  required double minWindowFraction,
}) {
  final minWindow = _sanitizeFraction(minWindowFraction, fallback: 0.02);
  var start = _sanitizeFinite(rawStart, fallback: 0);
  var end = _sanitizeFinite(rawEnd, fallback: 1);
  if (start > end) {
    final previousStart = start;
    start = end;
    end = previousStart;
  }

  final size = (end - start).clamp(minWindow, 1.0);
  final centre = (start + end) / 2;
  final normalizedStart = (centre - size / 2).clamp(0.0, 1.0 - size);
  final normalizedEnd = (normalizedStart + size).clamp(size, 1.0);

  return (start: (normalizedEnd - size).clamp(0.0, 1.0), end: normalizedEnd);
}

double _sanitizeFraction(double value, {required double fallback}) {
  if (!value.isFinite) return fallback.clamp(0.0, 1.0);
  return value.clamp(0.0, 1.0);
}

double _sanitizeFinite(double value, {required double fallback}) =>
    value.isFinite ? value : fallback;

double _sanitizeFlingFriction(double value) {
  if (!value.isFinite || value <= 0) return 0;
  if (value >= 1) return 0.99;
  return value;
}

Map<String, dynamic> _immutableMetadata(Map<String, dynamic>? metadata) {
  if (metadata == null || metadata.isEmpty) return const {};
  return JsonValue.freezeMap(metadata);
}

// ---------------------------------------------------------------------------
// ZoomConstraints — configure min/max zoom limits
// ---------------------------------------------------------------------------

class ZoomConstraints {
  /// Minimum visible window fraction (= maximum zoom level).
  /// 0.02 = can zoom to see 2% of data at most.
  final double minWindowFraction;

  /// Maximum visible window fraction (= minimum zoom = most zoomed out).
  /// 1.0 = full data range always visible.
  final double maxWindowFraction;

  /// Minimum number of data points to show.
  final int minVisiblePoints;

  /// Whether pinch-to-zoom is enabled.
  final bool enablePinchZoom;

  /// Whether mouse-wheel zoom is enabled (web / desktop).
  final bool enableScrollZoom;

  /// Whether double-tap to zoom is enabled.
  final bool enableDoubleTapZoom;

  /// Whether pan/drag is enabled.
  final bool enablePan;

  /// Zoom factor applied per double-tap.
  final double doubleTapZoomFactor;

  /// Whether fling (momentum pan) is enabled.
  final bool enableFling;

  /// Friction coefficient for fling deceleration [0..1]. Higher = stops faster.
  final double flingFriction;

  const ZoomConstraints({
    this.minWindowFraction = 0.02,
    this.maxWindowFraction = 1.0,
    this.minVisiblePoints = 3,
    this.enablePinchZoom = true,
    this.enableScrollZoom = true,
    this.enableDoubleTapZoom = true,
    this.enablePan = true,
    this.doubleTapZoomFactor = 2.5,
    this.enableFling = true,
    this.flingFriction = 0.88,
  });

  /// No interactions at all — fully static chart.
  static const ZoomConstraints none = ZoomConstraints(
    enablePinchZoom: false,
    enableScrollZoom: false,
    enableDoubleTapZoom: false,
    enablePan: false,
    enableFling: false,
  );

  /// Only pan, no zoom.
  static const ZoomConstraints panOnly = ZoomConstraints(
    enablePinchZoom: false,
    enableScrollZoom: false,
    enableDoubleTapZoom: false,
    enablePan: true,
  );

  factory ZoomConstraints.fromJson(Object? raw) {
    final json = JsonValue.map(raw);
    if (json == null) return const ZoomConstraints();
    return ZoomConstraints(
      minWindowFraction:
          JsonValue.doubleOrNull(json['minWindowFraction']) ?? 0.02,
      maxWindowFraction:
          JsonValue.doubleOrNull(json['maxWindowFraction']) ?? 1.0,
      minVisiblePoints: JsonValue.intOrNull(json['minVisiblePoints']) ?? 3,
      enablePinchZoom: JsonValue.boolOrNull(json['enablePinchZoom']) ?? true,
      enableScrollZoom: JsonValue.boolOrNull(json['enableScrollZoom']) ?? true,
      enableDoubleTapZoom:
          JsonValue.boolOrNull(json['enableDoubleTapZoom']) ?? true,
      enablePan: JsonValue.boolOrNull(json['enablePan']) ?? true,
      doubleTapZoomFactor:
          JsonValue.doubleOrNull(json['doubleTapZoomFactor']) ?? 2.5,
      enableFling: JsonValue.boolOrNull(json['enableFling']) ?? true,
      flingFriction: JsonValue.doubleOrNull(json['flingFriction']) ?? 0.88,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZoomConstraints &&
          other.minWindowFraction == minWindowFraction &&
          other.maxWindowFraction == maxWindowFraction &&
          other.minVisiblePoints == minVisiblePoints &&
          other.enablePinchZoom == enablePinchZoom &&
          other.enableScrollZoom == enableScrollZoom &&
          other.enableDoubleTapZoom == enableDoubleTapZoom &&
          other.enablePan == enablePan &&
          other.doubleTapZoomFactor == doubleTapZoomFactor &&
          other.enableFling == enableFling &&
          other.flingFriction == flingFriction;

  @override
  int get hashCode => Object.hash(
    minWindowFraction,
    maxWindowFraction,
    minVisiblePoints,
    enablePinchZoom,
    enableScrollZoom,
    enableDoubleTapZoom,
    enablePan,
    doubleTapZoomFactor,
    enableFling,
    flingFriction,
  );
}

// ---------------------------------------------------------------------------
// ChartZoomController — ValueNotifier wrapping ChartZoomState
// ---------------------------------------------------------------------------

/// A [ValueNotifier] that owns [ChartZoomState] and exposes gesture-friendly
/// mutation helpers.
///
/// Attach to a [ChartInteractionLayer] and read `.value` in painters.
///
/// ```dart
/// final zoomCtrl = ChartZoomController();
///
/// // In a StatefulWidget:
/// zoomCtrl.addListener(() => setState(() {}));
///
/// // Programmatic zoom to data range [20%..60%]:
/// zoomCtrl.zoomToRange(0.2, 0.6, label: 'Q2');
///
/// // Back:
/// zoomCtrl.pop();
/// ```
class ChartZoomController extends ValueNotifier<ChartZoomState> {
  final ZoomConstraints constraints;
  bool _disposed = false;

  ChartZoomController({
    ChartZoomState? initial,
    this.constraints = const ZoomConstraints(),
  }) : super(initial ?? ChartZoomState.identity) {
    _applyConstraints();
  }

  /// Whether this zoom controller has been disposed.
  bool get isDisposed => _disposed;

  @override
  set value(ChartZoomState newValue) {
    if (_disposed) return;
    super.value = _constrainedState(newValue, preserveVelocity: true);
  }

  // ---- Basic operations ----

  void zoomIn(double focalFraction, {double factor = 2.0}) {
    if (_disposed) return;
    if (!constraints.enablePinchZoom && !constraints.enableDoubleTapZoom) {
      return;
    }
    if (!factor.isFinite || factor <= 0 || !focalFraction.isFinite) return;
    value = value.zoomAroundFraction(focalFraction, factor);
    _applyConstraints();
  }

  void zoomOut({double factor = 2.0}) {
    if (_disposed) return;
    if (!factor.isFinite || factor <= 0) return;
    value = value.zoomAroundFraction(
      value.xStart + value.windowSize / 2,
      1.0 / factor,
    );
    _applyConstraints();
  }

  void pan(double deltaFraction) {
    if (_disposed) return;
    if (!constraints.enablePan) return;
    if (!deltaFraction.isFinite) return;
    value = value.panBy(deltaFraction);
  }

  void reset() {
    if (_disposed) return;
    value = value.reset();
  }

  // ---- Gesture entry-points (called by ChartInteractionLayer) ----

  void onScaleUpdate(double focalX, double canvasWidth, double scale) {
    if (_disposed) return;
    if (!constraints.enablePinchZoom) return;
    if (canvasWidth <= 0 || !canvasWidth.isFinite || !focalX.isFinite) return;
    final s = scale.clamp(0.1, 10.0);
    value = value.zoomAroundCanvas(focalX, canvasWidth, s);
    _applyConstraints();
  }

  void onPanDelta(double deltaX, double canvasWidth) {
    if (_disposed) return;
    if (!constraints.enablePan) return;
    if (canvasWidth <= 0 || !canvasWidth.isFinite || !deltaX.isFinite) return;
    final deltaFrac = -(deltaX / canvasWidth) * value.windowSize;
    value = value.panBy(deltaFrac);
  }

  void onDoubleTap(double focalX, double canvasWidth) {
    if (_disposed) return;
    if (!constraints.enableDoubleTapZoom) return;
    if (canvasWidth <= 0 || !canvasWidth.isFinite || !focalX.isFinite) return;
    final frac = value.canvasToFraction(focalX, canvasWidth);
    value = value.zoomAroundFraction(frac, constraints.doubleTapZoomFactor);
    _applyConstraints();
  }

  void onFlingStart(double velocityX, double canvasWidth) {
    if (_disposed) return;
    if (!constraints.enableFling) return;
    if (canvasWidth <= 0 || !canvasWidth.isFinite || !velocityX.isFinite) {
      return;
    }
    // Convert pixel velocity to fraction velocity.
    final fracVel = -(velocityX / canvasWidth) * value.windowSize * 0.016;
    value = value.withVelocity(fracVel);
  }

  /// Call every animation frame while [hasMomentum] is true.
  void advanceFling() {
    if (_disposed) return;
    if (!value.hasMomentum) return;
    value = value.advanceFling(friction: constraints.flingFriction);
    _applyConstraints(preserveVelocity: true);
  }

  bool get hasMomentum => !_disposed && value.hasMomentum;

  // ---- Scroll wheel (desktop/web) ----
  void onScrollWheel(double deltaY, double focalX, double canvasWidth) {
    if (_disposed) return;
    if (!constraints.enableScrollZoom) return;
    if (canvasWidth <= 0 ||
        !canvasWidth.isFinite ||
        !focalX.isFinite ||
        !deltaY.isFinite) {
      return;
    }
    final scaleDelta = deltaY < 0 ? 1.15 : 0.87;
    final frac = value.canvasToFraction(focalX, canvasWidth);
    value = value.zoomAroundFraction(frac, scaleDelta);
    _applyConstraints();
  }

  // ---- Drill-down ----

  void drillDown(
    double start,
    double end, {
    required String label,
    Map<String, dynamic>? metadata,
  }) {
    if (_disposed) return;
    value = value.drillDown(start, end, label: label, metadata: metadata);
    _applyConstraints();
  }

  void pop() {
    if (_disposed) return;
    value = value.pop();
  }

  void popAll() {
    if (_disposed) return;
    value = value.popAll();
  }

  bool get canPop => value.canPop;
  int get depth => value.depth;
  List<String> get breadcrumbs => value.breadcrumbs;

  // ---- Programmatic zoom (used by ChartController bridge) ----

  void zoomToRange(double start, double end, {String label = 'Zoom'}) {
    if (_disposed) return;
    value = value.zoomToRange(start, end, label: label);
    _applyConstraints();
  }

  /// Replace the current visible range without adding zoom history.
  ///
  /// Use this for synchronization from another controller. Use [zoomToRange]
  /// when the change should become part of the user's zoom/back history.
  void setVisibleRange(double start, double end) {
    if (_disposed) return;
    value = value.withVisibleRange(start, end);
    _applyConstraints();
  }

  void zoomToIndexRange(
    int start,
    int end,
    int totalPoints, {
    String label = 'Zoom',
  }) {
    if (_disposed) return;
    if (totalPoints <= 1) return;
    final s = start / (totalPoints - 1);
    final e = end / (totalPoints - 1);
    zoomToRange(s, e, label: label);
  }

  // ---- Internal ----

  void _applyConstraints({bool preserveVelocity = false}) {
    if (_disposed) return;
    final constrained = _constrainedState(
      value,
      preserveVelocity: preserveVelocity,
    );
    if (constrained == value) return;
    super.value = constrained;
  }

  ChartZoomState _constrainedState(
    ChartZoomState state, {
    required bool preserveVelocity,
  }) {
    final minW = _constraintMinWindow;
    final maxW = _constraintMaxWindow;
    final size = state.windowSize.clamp(minW, maxW);

    final centre = (state.xStart + state.xEnd) / 2;
    var start = (centre - size / 2).clamp(0.0, 1.0 - size);
    var end = (start + size).clamp(size, 1.0);
    start = (end - size).clamp(0.0, 1.0);
    final constrained = ChartZoomState._(
      xStart: start,
      xEnd: end,
      velocityX: preserveVelocity ? state.velocityX : 0,
      minWindowFraction: minW,
      history: state._history,
    );
    return constrained == state ? state : constrained;
  }

  double get _constraintMinWindow {
    final minFromPoints = constraints.minVisiblePoints <= 1
        ? 0.0
        : constraints.minVisiblePoints / 1000.0;
    final raw = math.max(constraints.minWindowFraction, minFromPoints);
    if (!raw.isFinite) return 0.02;
    return raw.clamp(0.0, 1.0);
  }

  double get _constraintMaxWindow {
    final raw = constraints.maxWindowFraction;
    final maxWindow = raw.isFinite ? raw.clamp(0.0, 1.0) : 1.0;
    return math.max(_constraintMinWindow, maxWindow);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
