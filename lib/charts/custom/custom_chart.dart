// Custom chart - fully extensible plug-in chart type.
//
// Allows any caller to supply their own [CustomChartBuilder] or
// [CustomChartPainter] at runtime, so you can add proprietary
// visualization types without forking the library.
//
// There are three usage modes:
//
// 1. Builder callback (simplest)
// ```dart
// CustomChartConfig(
//   builder: (data, theme, size) {
//     return MyFancyWidget(data: data, theme: theme);
//   },
//   rawData: {'sales': [100, 200, 150]},
// )
// ```
//
// 2. Custom painter
// ```dart
// CustomChartConfig(
//   painterFactory: (data, theme, progress) =>
//       MyPainter(data: data, theme: theme, progress: progress),
//   rawData: {'sales': [100, 200, 150]},
// )
// ```
//
// 3. JSON-registered type
// Register your factory with [ChartRegistry] using `ChartType.custom`
// and a unique `subType` string, then drive it from JSON:
// ```json
// { "type": "custom", "subType": "myChart",
//   "data": { "values": [10, 20, 30] } }
// ```

import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_registry.dart';

// ─────────────────────────────────────────────────────────
// Callback types
// ─────────────────────────────────────────────────────────

/// A function that builds any Flutter widget given raw chart data,
/// the active theme, and the available canvas size.
typedef CustomChartBuilder =
    Widget Function(Map<String, dynamic> data, ChartTheme theme, Size size);

/// A factory that creates a [CustomPainter] for use inside [CustomPaint].
typedef CustomPainterFactory =
    CustomPainter Function(
      Map<String, dynamic> data,
      ChartTheme theme,
      double animationProgress,
    );

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

class CustomChartConfig extends BaseChartConfig {
  /// Optional widget builder — takes priority over [painterFactory].
  final CustomChartBuilder? builder;

  /// Optional custom painter factory used when [builder] is null.
  final CustomPainterFactory? painterFactory;

  /// Arbitrary JSON/map data forwarded as-is to the builder or painter.
  final Map<String, dynamic> rawData;

  /// Sub-type identifier used when resolving JSON-registered factories.
  final String? subType;

  /// Animation duration for the entrance animation (painter path only).
  final Duration animationDuration;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  CustomChartConfig({
    this.builder,
    this.painterFactory,
    this.rawData = const {},
    this.subType,
    this.theme = ChartTheme.light,
    this.animationDuration = const Duration(milliseconds: 700),
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.custom, series: const []);

  @override
  Widget buildChart() => CustomChartWidget(config: this);

  factory CustomChartConfig.fromJson(Map<String, dynamic> json) {
    final subType = json['subType']?.toString();

    // If there is a registered sub-type factory, delegate to it.
    if (subType != null) {
      final reg = CustomSubTypeRegistry.findBySubType(subType);
      if (reg != null) {
        return reg(json) as CustomChartConfig;
      }
    }

    return CustomChartConfig(
      rawData: (json['data'] as Map<String, dynamic>?) ?? {},
      subType: subType,
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      tooltip: json['tooltip'] != null
          ? ChartTooltip.fromJson(json['tooltip'])
          : null,
      legend: json['legend'] != null
          ? ChartLegend.fromJson(json['legend'])
          : null,
      toolbox: json['toolbox'] != null
          ? ChartToolbox.fromJson(json['toolbox'])
          : null,
      grid: json['grid'] != null ? GridData.fromJson(json['grid']) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'custom',
    if (subType != null) 'subType': subType,
    'data': rawData,
  };
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

class CustomChartWidget extends StatefulWidget {
  final CustomChartConfig config;
  const CustomChartWidget({super.key, required this.config});

  @override
  State<CustomChartWidget> createState() => _CustomChartState();
}

class _CustomChartState extends State<CustomChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  CustomChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: cfg.animationDuration);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (cfg.title?.text != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(
              cfg.title!.text!,
              style: cfg.theme.typography.titleStyle.copyWith(
                color: cfg.theme.titleColor,
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, con) {
              final sz = Size(con.maxWidth, con.maxHeight);

              // ── Mode 1: widget builder ─────────────────────────
              if (cfg.builder != null) {
                return cfg.builder!(cfg.rawData, cfg.theme, sz);
              }

              // ── Mode 2: custom painter ─────────────────────────
              if (cfg.painterFactory != null) {
                return RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: cfg.painterFactory!(
                      cfg.rawData,
                      cfg.theme,
                      _anim.value,
                    ),
                  ),
                );
              }

              // ── Mode 3: no-op placeholder ──────────────────────
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 48,
                        color: cfg.theme.axisLabelColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        cfg.subType != null
                            ? 'Custom chart: "${cfg.subType}"\nNo factory registered.'
                            : 'Provide a builder or painterFactory\nto render a custom chart.',
                        textAlign: TextAlign.center,
                        style: cfg.theme.typography.axisLabelStyle.copyWith(
                          color: cfg.theme.axisLabelColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Base class helpers for custom painters
// ─────────────────────────────────────────────────────────

/// Convenience base class for custom chart painters.
///
/// Extends [ChartPainterBase] so your painter gets free access to
/// [paintCache], [textPainterCache], [colorCache], [theme] helpers,
/// and axis drawing utilities.
///
/// Usage:
/// ```dart
/// class MyPainter extends CustomChartPainterBase {
///   final double progress;
///   MyPainter(Map<String,dynamic> data, ChartTheme theme, this.progress)
///       : super(data: data, theme: theme);
///
///   @override
///   void paint(Canvas canvas, Size size) {
///     // your drawing code here — use paintCache, textPainterCache, etc.
///   }
///
///   @override
///   bool shouldRepaintChart(covariant MyPainter old) =>
///       old.progress != progress;
/// }
/// ```
abstract class CustomChartPainterBase extends ChartPainterBase {
  final Map<String, dynamic> data;

  CustomChartPainterBase({required this.data, required super.theme});
}

// ─────────────────────────────────────────────────────────
// Registry helper extension
// ─────────────────────────────────────────────────────────

/// In-memory map of custom sub-type → fromJson factory.
final Map<String, BaseChartConfig Function(Map<String, dynamic>)>
_customSubTypeRegistry = {};

extension CustomSubTypeRegistry on ChartRegistry {
  /// Register a custom sub-type factory so [CustomChartConfig.fromJson]
  /// can resolve it by `"subType"` string.
  ///
  /// ```dart
  /// ChartRegistry.registerSubType('myChart', MyChartConfig.fromJson);
  /// ```
  static void registerSubType(
    String subType,
    BaseChartConfig Function(Map<String, dynamic>) factory,
  ) {
    _customSubTypeRegistry[subType] = factory;
  }

  /// Look up a registered sub-type factory, returns null if not found.
  static BaseChartConfig Function(Map<String, dynamic>)? findBySubType(
    String subType,
  ) {
    return _customSubTypeRegistry[subType];
  }
}
