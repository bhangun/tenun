// Hierarchical drill-down state machine for charts.
//
// [ChartDrillDownController] manages a stack of [DrillDownLevel] objects.
// Each level describes what data to show and how to render it.
//
// Typical usage pattern (year → quarter → month):
// ```dart
// final drill = ChartDrillDownController(
//   root: DrillDownLevel(
//     id: 'year',
//     label: 'Annual Revenue',
//     data: yearData,
//     buildConfig: (level) => BarChartConfig(series: [Series(data: level.data)]),
//   ),
// );
//
// // When user taps a bar:
// drill.push(DrillDownLevel(
//   id: 'q2_2024',
//   label: 'Q2 2024',
//   data: quarterData,
//   buildConfig: (level) => LineChartConfig(...),
// ));
// ```

import 'package:flutter/material.dart';

import '../base_config.dart';
import '../json_value.dart';

// ---------------------------------------------------------------------------
// DrillDownLevel
// ---------------------------------------------------------------------------

/// One level in the drill-down hierarchy.
class DrillDownLevel {
  /// Unique identifier for this level (used for deduplication).
  final String id;

  /// Human-readable label shown in breadcrumbs.
  final String label;

  /// Raw data payload for this level (type is chart-specific).
  final dynamic data;

  /// Factory that builds the [BaseChartConfig] for this level.
  ///
  /// Called lazily when the level becomes active, so expensive config
  /// construction only happens on demand.
  final BaseChartConfig Function(DrillDownLevel level)? buildConfig;

  /// Pre-built config — use this when the config is already available.
  final BaseChartConfig? config;

  /// Optional metadata (e.g., selected bar value, parent category name).
  final Map<String, dynamic> _metadata;

  /// Optional metadata (e.g., selected bar value, parent category name).
  Map<String, dynamic> get metadata =>
      Map.unmodifiable(JsonValue.cloneMap(_metadata));

  /// x-range in the parent's data space [0..1] that this level represents.
  /// Used to synchronise [ChartZoomController] with the drill-down level.
  final double parentXStart;
  final double parentXEnd;

  DrillDownLevel({
    required this.id,
    required this.label,
    this.data,
    this.buildConfig,
    this.config,
    Map<String, dynamic> metadata = const {},
    this.parentXStart = 0,
    this.parentXEnd = 1,
  }) : _metadata = _immutableMetadata(metadata),
       assert(
         buildConfig != null || config != null,
         'Either buildConfig or config must be provided',
       );

  /// Resolve the config for this level.
  BaseChartConfig resolveConfig() {
    if (config != null) return config!;
    return buildConfig!(this);
  }

  /// Normalized parent x-range in [0..1].
  ///
  /// Keeps runtime drilldown/zoom sync safe when levels are created from
  /// user-provided JSON or external interaction callbacks.
  (double start, double end) get parentXRange =>
      _normalizeParentXRange(parentXStart, parentXEnd);

  @override
  String toString() => 'DrillDownLevel(id=$id, label=$label)';
}

// ---------------------------------------------------------------------------
// DrillDownState
// ---------------------------------------------------------------------------

/// Immutable snapshot of the current drill-down position.
class DrillDownState {
  /// All levels from root to current (inclusive).
  final List<DrillDownLevel> stack;

  DrillDownState({required List<DrillDownLevel> stack})
    : stack = List<DrillDownLevel>.unmodifiable(stack);

  /// The currently active level.
  DrillDownLevel get current => stack.isNotEmpty ? stack.last : _emptyLevel;

  /// True when at the root (no drill-down has occurred).
  bool get isAtRoot => stack.length <= 1;

  /// Depth from root (0 = root).
  int get depth => stack.isEmpty ? 0 : stack.length - 1;

  /// All breadcrumb labels from root to current.
  List<String> get breadcrumbs => stack.map((l) => l.label).toList();

  static final _emptyLevel = DrillDownLevel(
    id: '_empty',
    label: 'Chart',
    config: null,
    buildConfig: (_) => throw StateError('No root level configured'),
  );
}

Map<String, dynamic> _immutableMetadata(Map<String, dynamic> metadata) {
  if (metadata.isEmpty) return const {};
  return JsonValue.freezeMap(metadata);
}

// ---------------------------------------------------------------------------
// ChartDrillDownController
// ---------------------------------------------------------------------------

/// A [ValueNotifier<DrillDownState>] managing hierarchical drill-down.
///
/// ```dart
/// // Listen for level changes:
/// drillCtrl.addListener(() {
///   final config = drillCtrl.currentConfig;
///   setState(() => _activeConfig = config);
/// });
///
/// // Navigate down:
/// drillCtrl.push(myLevel);
///
/// // Navigate up:
/// drillCtrl.pop();
///
/// // Jump to root:
/// drillCtrl.popAll();
/// ```
class ChartDrillDownController extends ValueNotifier<DrillDownState> {
  bool _disposed = false;

  ChartDrillDownController({required DrillDownLevel root})
    : super(DrillDownState(stack: [root]));

  // ---- Accessors ----

  /// Whether this drill-down controller has been disposed.
  bool get isDisposed => _disposed;

  DrillDownLevel get currentLevel => value.current;
  BaseChartConfig get currentConfig => value.current.resolveConfig();
  bool get canPop => !value.isAtRoot;
  int get depth => value.depth;
  List<String> get breadcrumbs => value.breadcrumbs;

  /// The x-range [start, end] in the root data space for the current level.
  (double start, double end) get currentXRange => currentLevel.parentXRange;

  @override
  set value(DrillDownState newValue) {
    if (_disposed) return;
    super.value = newValue;
  }

  // ---- Navigation ----

  /// Push a new drill-down level.
  void push(DrillDownLevel level) {
    if (_disposed) return;
    value = DrillDownState(stack: [...value.stack, level]);
  }

  /// Pop back to the previous level.
  ///
  /// Does nothing when already at root.
  void pop() {
    if (_disposed) return;
    if (!canPop) return;
    value = DrillDownState(
      stack: value.stack.sublist(0, value.stack.length - 1),
    );
  }

  /// Pop back to root, clearing the entire drill-down history.
  void popAll() {
    if (_disposed || value.stack.length <= 1) return;
    value = DrillDownState(stack: [value.stack.first]);
  }

  /// Pop back to the level with [id], if it exists in the stack.
  void popTo(String id) {
    if (_disposed) return;
    final idx = value.stack.indexWhere((l) => l.id == id);
    if (idx < 0 || idx == value.stack.length - 1) return;
    value = DrillDownState(stack: value.stack.sublist(0, idx + 1));
  }

  /// Replace the current level (in-place update without history push).
  void replace(DrillDownLevel level) {
    if (_disposed) return;
    if (value.stack.isEmpty) {
      push(level);
      return;
    }
    value = DrillDownState(
      stack: [...value.stack.sublist(0, value.stack.length - 1), level],
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

(double start, double end) _normalizeParentXRange(
  double rawStart,
  double rawEnd,
) {
  var start = rawStart.isFinite ? rawStart : 0.0;
  var end = rawEnd.isFinite ? rawEnd : 1.0;
  if (start > end) {
    final previousStart = start;
    start = end;
    end = previousStart;
  }
  return (start.clamp(0.0, 1.0), end.clamp(0.0, 1.0));
}

// ---------------------------------------------------------------------------
// DrillDownBreadcrumb widget
// ---------------------------------------------------------------------------

/// A row of tappable breadcrumb chips showing the current drill-down path.
///
/// ```dart
/// DrillDownBreadcrumb(controller: drillCtrl)
/// ```
class DrillDownBreadcrumb extends StatelessWidget {
  final ChartDrillDownController controller;
  final TextStyle? textStyle;
  final Color chipColor;
  final Color activeChipColor;

  const DrillDownBreadcrumb({
    super.key,
    required this.controller,
    this.textStyle,
    this.chipColor = const Color(0xFFE3F2FD),
    this.activeChipColor = const Color(0xFF2196F3),
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DrillDownState>(
      valueListenable: controller,
      builder: (context, state, _) {
        if (state.stack.length <= 1) return const SizedBox.shrink();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: state.stack.asMap().entries.map((e) {
              final isLast = e.key == state.stack.length - 1;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.key > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: Colors.black38,
                      ),
                    ),
                  GestureDetector(
                    onTap: isLast ? null : () => controller.popTo(e.value.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isLast ? activeChipColor : chipColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isLast
                              ? activeChipColor
                              : const Color(0xFFBBDEFB),
                        ),
                      ),
                      child: Text(
                        e.value.label,
                        style: (textStyle ?? const TextStyle(fontSize: 12))
                            .copyWith(
                              color: isLast ? Colors.white : Colors.black87,
                              fontWeight: isLast
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// DrillDownChartView — all-in-one widget
// ---------------------------------------------------------------------------

/// A complete drill-down-capable chart view.
///
/// Combines:
/// - Current chart rendering (driven by [ChartDrillDownController])
/// - Breadcrumb navigation bar
/// - Back button
///
/// ```dart
/// DrillDownChartView(
///   controller: drillCtrl,
///   builder: (config) => TenunChart(config: config),
///   onLevelChanged: (level) => print('Now at: ${level.label}'),
/// )
/// ```
class DrillDownChartView extends StatefulWidget {
  final ChartDrillDownController controller;

  /// Builds the chart widget for the given config.
  final Widget Function(BaseChartConfig config) builder;

  /// Called when the active level changes.
  final void Function(DrillDownLevel level)? onLevelChanged;

  /// Whether to show the breadcrumb row above the chart.
  final bool showBreadcrumbs;

  /// Whether to show the back button when drilled down.
  final bool showBackButton;

  const DrillDownChartView({
    super.key,
    required this.controller,
    required this.builder,
    this.onLevelChanged,
    this.showBreadcrumbs = true,
    this.showBackButton = true,
  });

  @override
  State<DrillDownChartView> createState() => _DrillDownChartViewState();
}

class _DrillDownChartViewState extends State<DrillDownChartView> {
  String? _lastEmittedLevelSignature;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleLevelChangedIfNeeded);
    _scheduleLevelChangedIfNeeded();
  }

  @override
  void didUpdateWidget(covariant DrillDownChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleLevelChangedIfNeeded);
      widget.controller.addListener(_scheduleLevelChangedIfNeeded);
      _lastEmittedLevelSignature = null;
      _scheduleLevelChangedIfNeeded();
      return;
    }

    if (oldWidget.onLevelChanged != widget.onLevelChanged) {
      _lastEmittedLevelSignature = null;
      _scheduleLevelChangedIfNeeded();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleLevelChangedIfNeeded);
    super.dispose();
  }

  void _scheduleLevelChangedIfNeeded() {
    final callback = widget.onLevelChanged;
    if (callback == null) return;

    final level = widget.controller.currentLevel;
    final signature = _levelSignature(level);
    if (_lastEmittedLevelSignature == signature) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_levelSignature(widget.controller.currentLevel) != signature) return;
      if (_lastEmittedLevelSignature == signature) return;

      _lastEmittedLevelSignature = signature;
      widget.onLevelChanged?.call(level);
    });
  }

  String _levelSignature(DrillDownLevel level) {
    return '${widget.controller.depth}:${level.id}:${identityHashCode(level)}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DrillDownState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        final config = state.current.resolveConfig();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Breadcrumb bar
            if (widget.showBreadcrumbs && state.stack.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    if (widget.showBackButton && widget.controller.canPop)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                        onPressed: widget.controller.pop,
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    Expanded(
                      child: DrillDownBreadcrumb(controller: widget.controller),
                    ),
                    if (state.stack.length > 1)
                      TextButton(
                        onPressed: widget.controller.popAll,
                        child: const Text(
                          'Reset',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),

            // Chart
            Expanded(child: widget.builder(config)),
          ],
        );
      },
    );
  }
}
