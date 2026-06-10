// Ready-to-use zoomable + drilldown chart widget.
//
// [ZoomableTenunChart] wraps any [BaseChartConfig]-based chart with:
//  - Pinch-to-zoom + pan + fling
//  - Double-tap to zoom in
//  - Scroll wheel (desktop/web)
//  - Zoom reset button overlay
//  - Optional minimap scrubber
//  - Crosshair on long-press
//  - Programmatic drill-down via [ChartDrillDownController]
//
// Quick usage:
// ```dart
// ZoomableTenunChart(
//   config: myBarConfig,
//   height: 300,
//   showMinimap: true,
// )
// ```
//
// Advanced usage with drill-down:
// ```dart
// final drill = ChartDrillDownController(root: myRootLevel);
//
// ZoomableTenunChart.drillDown(
//   drillController: drill,
//   height: 300,
//   onTap: (frac, zoomCtrl) {
//     // Push a new level when the user taps a bar
//     drill.push(DrillDownLevel(
//       id: 'q1',
//       label: 'Q1 Detail',
//       config: myDetailConfig,
//       parentXStart: frac - 0.1,
//       parentXEnd: frac + 0.1,
//     ));
//     // Also zoom into that x-range on the same chart
//     zoomCtrl.zoomToRange(frac - 0.1, frac + 0.1, label: 'Q1');
//   },
// )
// ```

import 'package:flutter/material.dart';

import '../chart_controller.dart';
import 'chart_drilldown_controller.dart';
import '../chart_interaction_layer.dart';
import 'chart_zoom_state.dart';
import '../base_config.dart';

// ---------------------------------------------------------------------------
// ZoomableTenunChart
// ---------------------------------------------------------------------------

class ZoomableTenunChart extends StatefulWidget {
  // ---- Simple mode ----
  final BaseChartConfig? config;

  // ---- Drill-down mode ----
  final ChartDrillDownController? drillController;

  // ---- Layout ----
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  // ---- Zoom constraints ----
  final ZoomConstraints zoomConstraints;

  // ---- Features ----
  final bool showMinimap;
  final bool showResetButton;
  final bool showBreadcrumbs;
  final double minimapHeight;

  // ---- Callbacks ----
  /// Called with the x-fraction [0..1] of the tapped position.
  final void Function(double fraction, ChartZoomController zoom)? onTap;

  /// Called with the x-fraction [0..1] during crosshair movement.
  final void Function(double fraction)? onCrosshairMove;
  final void Function()? onCrosshairEnd;

  /// Called with the x-fraction when the user double-taps.
  final void Function(double fraction, ChartZoomController zoom)? onDoubleTap;

  /// External zoom controller — pass your own to read the state elsewhere.
  final ChartZoomController? zoomController;

  const ZoomableTenunChart({
    super.key,
    this.config,
    this.drillController,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.zoomConstraints = const ZoomConstraints(),
    this.showMinimap = false,
    this.showResetButton = true,
    this.showBreadcrumbs = true,
    this.minimapHeight = 28,
    this.onTap,
    this.onCrosshairMove,
    this.onCrosshairEnd,
    this.onDoubleTap,
    this.zoomController,
  }) : assert(
         config != null || drillController != null,
         'Provide either config or drillController',
       );

  /// Convenience constructor for drill-down mode.
  const ZoomableTenunChart.drillDown({
    Key? key,
    required ChartDrillDownController drillController,
    double? width,
    double? height,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    ZoomConstraints zoomConstraints = const ZoomConstraints(),
    bool showMinimap = false,
    bool showResetButton = true,
    bool showBreadcrumbs = true,
    double minimapHeight = 28,
    void Function(double fraction, ChartZoomController zoom)? onTap,
    void Function(double fraction)? onCrosshairMove,
    void Function()? onCrosshairEnd,
    void Function(double fraction, ChartZoomController zoom)? onDoubleTap,
    ChartZoomController? zoomController,
  }) : this(
         key: key,
         drillController: drillController,
         width: width,
         height: height,
         padding: padding,
         zoomConstraints: zoomConstraints,
         showMinimap: showMinimap,
         showResetButton: showResetButton,
         showBreadcrumbs: showBreadcrumbs,
         minimapHeight: minimapHeight,
         onTap: onTap,
         onCrosshairMove: onCrosshairMove,
         onCrosshairEnd: onCrosshairEnd,
         onDoubleTap: onDoubleTap,
         zoomController: zoomController,
       );

  @override
  State<ZoomableTenunChart> createState() => _ZoomableTenunChartState();
}

class _ZoomableTenunChartState extends State<ZoomableTenunChart> {
  late ChartZoomController _zoomCtrl;
  bool _ownsZoomCtrl = false;

  @override
  void initState() {
    super.initState();
    _attachZoomController();
  }

  @override
  void didUpdateWidget(covariant ZoomableTenunChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.zoomController != widget.zoomController;
    final ownedConstraintsChanged =
        oldWidget.zoomController == null &&
        widget.zoomController == null &&
        oldWidget.zoomConstraints != widget.zoomConstraints;
    if (!controllerChanged && !ownedConstraintsChanged) return;

    final previousController = _zoomCtrl;
    final previousOwned = _ownsZoomCtrl;
    final initialState = widget.zoomController == null
        ? previousController.value
        : null;

    _attachZoomController(initial: initialState);

    if (previousOwned && previousController != _zoomCtrl) {
      previousController.dispose();
    }
  }

  @override
  void dispose() {
    if (_ownsZoomCtrl) _zoomCtrl.dispose();
    super.dispose();
  }

  void _attachZoomController({ChartZoomState? initial}) {
    final external = widget.zoomController;
    if (external != null) {
      _zoomCtrl = external;
      _ownsZoomCtrl = false;
      return;
    }
    _zoomCtrl = ChartZoomController(
      initial: initial,
      constraints: widget.zoomConstraints,
    );
    _ownsZoomCtrl = true;
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    Widget chartContent = _buildChartContent();

    // Wrap in interaction layer.
    chartContent = ChartInteractionLayer(
      zoomController: _zoomCtrl,
      onTap: (frac) => widget.onTap?.call(frac, _zoomCtrl),
      onDoubleTap: (frac) => widget.onDoubleTap?.call(frac, _zoomCtrl),
      onCrosshairMove: widget.onCrosshairMove,
      onCrosshairEnd: widget.onCrosshairEnd,
      child: chartContent,
    );

    // Zoom reset overlay.
    if (widget.showResetButton) {
      chartContent = Stack(
        children: [
          chartContent,
          ZoomResetButton(controller: _zoomCtrl),
        ],
      );
    }

    // Assemble full column: breadcrumbs + chart + minimap.
    Widget result = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Breadcrumbs (drill-down mode only).
        if (widget.showBreadcrumbs && widget.drillController != null)
          ValueListenableBuilder<DrillDownState>(
            valueListenable: widget.drillController!,
            builder: (ctx, state, _) {
              if (state.stack.length <= 1) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                      onPressed: widget.drillController!.canPop
                          ? widget.drillController!.pop
                          : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    Expanded(
                      child: DrillDownBreadcrumb(
                        controller: widget.drillController!,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.drillController!.popAll,
                      child: const Text(
                        'Reset',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        // Main chart (expands to fill available height).
        Expanded(child: chartContent),

        // Minimap scrubber.
        if (widget.showMinimap)
          ZoomMinimap(controller: _zoomCtrl, height: widget.minimapHeight),
      ],
    );

    // Size constraints.
    if (widget.height != null || widget.width != null) {
      result = SizedBox(
        width: widget.width,
        height: widget.height,
        child: result,
      );
    }

    if (widget.padding != EdgeInsets.zero) {
      result = Padding(padding: widget.padding, child: result);
    }

    return result;
  }

  Widget _buildChartContent() {
    if (widget.drillController != null) {
      return ValueListenableBuilder<DrillDownState>(
        valueListenable: widget.drillController!,
        builder: (ctx, state, _) {
          return _ZoomInjectedChart(
            config: state.current.resolveConfig(),
            zoomController: _zoomCtrl,
          );
        },
      );
    }
    return _ZoomInjectedChart(
      config: widget.config!,
      zoomController: _zoomCtrl,
    );
  }
}

// ---------------------------------------------------------------------------
// _ZoomInjectedChart — passes zoom state into chart config / painter
// ---------------------------------------------------------------------------

/// Internal widget that injects the [ChartZoomController] into the config's
/// controller so the chart's painter can read the current zoom state.
class _ZoomInjectedChart extends StatefulWidget {
  final BaseChartConfig config;
  final ChartZoomController zoomController;

  const _ZoomInjectedChart({
    required this.config,
    required this.zoomController,
  });

  @override
  State<_ZoomInjectedChart> createState() => _ZoomInjectedChartState();
}

class _ZoomInjectedChartState extends State<_ZoomInjectedChart> {
  late final ChartController _chartController;
  ChartZoomBridge? _bridge;

  int get _totalPoints {
    int maxLen = 0;
    for (final s in widget.config.series) {
      final len = s.data?.length ?? 0;
      if (len > maxLen) maxLen = len;
    }
    return maxLen;
  }

  @override
  void initState() {
    super.initState();
    _chartController = ChartController();
    final points = _totalPoints;
    if (points > 1) {
      _bridge = ChartZoomBridge(
        chartController: _chartController,
        zoomController: widget.zoomController,
        totalDataPoints: points,
      );
    }
  }

  @override
  void didUpdateWidget(covariant _ZoomInjectedChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPoints = oldWidget.config.series.fold<int>(
      0,
      (max, s) => (s.data?.length ?? 0) > max ? (s.data?.length ?? 0) : max,
    );
    final newPoints = _totalPoints;
    if (oldPoints != newPoints ||
        oldWidget.zoomController != widget.zoomController) {
      _bridge?.dispose();
      _bridge = null;
      if (newPoints > 1) {
        _bridge = ChartZoomBridge(
          chartController: _chartController,
          zoomController: widget.zoomController,
          totalDataPoints: newPoints,
        );
      }
    }
  }

  @override
  void dispose() {
    _bridge?.dispose();
    _chartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the chart every time zoom changes so the painter gets
    // updated visible index ranges.
    return ValueListenableBuilder<ChartZoomState>(
      valueListenable: widget.zoomController,
      builder: (ctx, _, _) {
        final effectiveConfig = widget.config.withController(_chartController);
        return effectiveConfig.buildChart();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ChartController <-> ChartZoomController bridge
// ---------------------------------------------------------------------------
// NOTE: When a chart's BaseChartConfig has a ChartController attached,
// call ChartZoomBridge.attach() to keep the two in sync.

/// Bridges [ChartController] zoom operations with a [ChartZoomController].
///
/// After attaching, calls to `chartCtrl.zoomTo(start, end)` will update
/// the [ChartZoomController] and vice versa.
class ChartZoomBridge {
  final ChartController chartController;
  final ChartZoomController zoomController;
  final int totalDataPoints;
  bool _syncing = false;
  bool _disposed = false;
  bool _attached = false;

  ChartZoomBridge({
    required this.chartController,
    required this.zoomController,
    required this.totalDataPoints,
  }) {
    if (totalDataPoints <= 1 ||
        chartController.isDisposed ||
        zoomController.isDisposed) {
      return;
    }
    // Sync chartController → zoomController
    chartController.addListener(_onChartControllerChange);
    // Sync zoomController → chartController
    zoomController.addListener(_onZoomControllerChange);
    _attached = true;
  }

  /// Whether this bridge has been disposed.
  bool get isDisposed => _disposed;

  /// Whether this bridge currently has listeners attached to both controllers.
  bool get isAttached => _attached;

  void _onChartControllerChange() {
    if (_disposed || _syncing) return;
    if (totalDataPoints <= 1) return;
    if (chartController.isDisposed || zoomController.isDisposed) {
      dispose();
      return;
    }

    _syncing = true;
    try {
      final maxIndex = totalDataPoints - 1;
      final visibleRange = chartController.zoom.visibleIndexRange(
        totalDataPoints,
      );
      if (visibleRange.isEmpty) return;
      final s = visibleRange.start / maxIndex;
      final e = visibleRange.end / maxIndex;
      zoomController.setVisibleRange(s, e);
    } finally {
      _syncing = false;
    }
  }

  void _onZoomControllerChange() {
    if (_disposed || _syncing) return;
    if (totalDataPoints <= 1) return;
    if (chartController.isDisposed || zoomController.isDisposed) {
      dispose();
      return;
    }

    final z = zoomController.value;
    if (z.windowSize <= 0 || !z.windowSize.isFinite) return;

    _syncing = true;
    try {
      chartController.zoomTo(
        start: z.startIndex(totalDataPoints),
        end: z.endIndex(totalDataPoints),
        factor: 1.0 / z.windowSize,
      );
    } finally {
      _syncing = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_attached) {
      if (!chartController.isDisposed) {
        chartController.removeListener(_onChartControllerChange);
      }
      if (!zoomController.isDisposed) {
        zoomController.removeListener(_onZoomControllerChange);
      }
      _attached = false;
    }
  }
}
