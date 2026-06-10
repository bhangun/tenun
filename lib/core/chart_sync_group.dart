import 'package:flutter/foundation.dart';
import 'chart_controller.dart';

/// Links multiple [ChartController] instances for dashboard-style sync.
/// Synchronizes: zoom window, pan offset, and data selection.
///
/// Typical use-case: a dashboard where a date-range selection on a line chart
/// should also zoom a bar chart showing the same period.
///
/// ```dart
/// final group = ChartSyncGroup();
/// final lineCtrl = group.add(ChartController());
/// final barCtrl  = group.add(ChartController());
///
/// // Zooming lineCtrl will now also zoom barCtrl.
/// lineCtrl.zoomTo(start: 10, end: 50);
/// ```
class ChartSyncGroup extends ChangeNotifier {
  final List<ChartController> _controllers = [];
  final Map<ChartController, VoidCallback> _listeners = {};
  bool _isSyncing = false;
  bool _disposed = false;

  /// Whether this sync group has been disposed.
  bool get isDisposed => _disposed;

  /// Number of live controllers currently registered in the group.
  int get controllerCount => _controllers.length;

  /// Add a controller to the group and wire it up for synchronization.
  ChartController add(ChartController ctrl) {
    if (_disposed || ctrl.isDisposed) return ctrl;
    _detachDisposedControllers();
    if (!_controllers.contains(ctrl)) {
      _controllers.add(ctrl);
      void listener() => _propagateChanges(ctrl);
      _listeners[ctrl] = listener;
      ctrl.addListener(listener);
    }
    return ctrl;
  }

  /// Remove a controller from the group and stop synchronization.
  void remove(ChartController ctrl) {
    if (_disposed) return;
    if (_controllers.remove(ctrl)) {
      _detach(ctrl);
    }
  }

  void _propagateChanges(ChartController source) {
    if (_disposed || _isSyncing) return;
    if (source.isDisposed) {
      remove(source);
      return;
    }
    _isSyncing = true;
    try {
      _detachDisposedControllers();
      for (final ctrl in _controllers) {
        if (identical(ctrl, source)) continue;

        ctrl.batchUpdate(() {
          // Sync zoom/pan
          if (ctrl.zoom != source.zoom || ctrl.panOffset != source.panOffset) {
            ctrl.syncViewport(source.zoom, source.panOffset);
          }

          // Sync selection state without replaying tap callbacks on peers.
          if (ctrl.selection != source.selection) {
            ctrl.syncSelection(source.selection);
          }

          // Sync legend/filter state for linked dashboard controls.
          ctrl.syncSeriesState(
            highlightedSeries: source.highlightedSeries,
            hiddenSeries: source.hiddenSeries,
          );
          ctrl.syncFilters(source.filters);
        });
      }
    } finally {
      _isSyncing = false;
    }
  }

  void _detach(ChartController ctrl) {
    final listener = _listeners.remove(ctrl);
    if (listener != null && !ctrl.isDisposed) {
      ctrl.removeListener(listener);
    }
  }

  void _detachDisposedControllers() {
    final disposedControllers = _controllers
        .where((c) => c.isDisposed)
        .toList();
    for (final ctrl in disposedControllers) {
      _controllers.remove(ctrl);
      _detach(ctrl);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final entry in _listeners.entries) {
      if (!entry.key.isDisposed) {
        entry.key.removeListener(entry.value);
      }
    }
    _listeners.clear();
    _controllers.clear();
    super.dispose();
  }
}
