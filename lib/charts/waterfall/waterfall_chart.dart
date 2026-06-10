// Waterfall chart — shows cumulative effect of sequential positive/negative values.
//
// Also known as a bridge chart. Each bar floats at its running-total position.
// Items can be tagged as "total" to show a full bar (e.g. opening/closing values).
//
// JSON:
// ```json
// {
//   "type": "waterfall",
//   "series": [{
//     "data": [
//       { "name": "Opening",  "value": 500,  "type": "total"    },
//       { "name": "Revenue",  "value": 320                       },
//       { "name": "Returns",  "value": -80                       },
//       { "name": "OpEx",     "value": -150                      },
//       { "name": "Tax",      "value": -45                       },
//       { "name": "Closing",  "value": 545,  "type": "total"    }
//     ]
//   }]
// }
// ```

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/chart_data_processor.dart';
import '../../core/base_config.dart';
import '../../core/chart_type.dart';
import '../../core/chart_theme.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';
import '../../core/legend.dart';
import '../../core/grid.dart';
import '../../core/chart_model.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_cache.dart';
import '../../core/chart_color_value.dart';
import '../../core/chart_data_signature.dart';
import '../../core/chart_series_json.dart';
import '../../core/json_value.dart';

// ─────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────

enum WaterfallItemType { increase, decrease, total }

class WaterfallItem {
  final String name;
  final double value;
  final WaterfallItemType itemType;
  final String? color;

  const WaterfallItem({
    required this.name,
    required this.value,
    this.itemType = WaterfallItemType.increase,
    this.color,
  });

  factory WaterfallItem.fromJson(Map<String, dynamic> j) {
    final v = JsonValue.doubleOrNull(j['value']) ?? 0;
    final typeStr = j['type']?.toString().toLowerCase();
    WaterfallItemType t;
    if (typeStr == 'total') {
      t = WaterfallItemType.total;
    } else if (typeStr == 'decrease') {
      t = WaterfallItemType.decrease;
    } else if (typeStr == 'increase') {
      t = WaterfallItemType.increase;
    } else if (v < 0) {
      t = WaterfallItemType.decrease;
    } else {
      t = WaterfallItemType.increase;
    }
    return WaterfallItem(
      name: j['name']?.toString() ?? '',
      value: v,
      itemType: t,
      color: j['color']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'type': itemType.name,
    if (color != null) 'color': color,
  };
}

String _colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

class WaterfallChartConfig extends BaseChartConfig {
  final List<WaterfallItem> items;
  final bool showConnectors;
  final bool showLabels;
  final bool showRunningTotal;
  final Color increaseColor;
  final Color decreaseColor;
  final Color totalColor;
  final double barWidthFraction;

  WaterfallChartConfig({
    required this.items,
    super.theme = ChartTheme.light,
    this.showConnectors = true,
    this.showLabels = true,
    this.showRunningTotal = false,
    this.increaseColor = const Color(0xFF4CAF50),
    this.decreaseColor = const Color(0xFFF44336),
    this.totalColor = const Color(0xFF2196F3),
    this.barWidthFraction = 0.65,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.waterfall, series: const []);

  @override
  Widget buildChart() => WaterfallChartWidget(config: this);

  factory WaterfallChartConfig.fromJson(Map<String, dynamic> json) {
    final items = ChartSeriesJson.firstSeriesData(
      json['series'],
    ).map(WaterfallItem.fromJson).toList();

    return WaterfallChartConfig(
      items: items,
      showConnectors: JsonValue.boolOrNull(json['showConnectors']) ?? true,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? true,
      showRunningTotal: JsonValue.boolOrNull(json['showRunningTotal']) ?? false,
      increaseColor: ChartColorValue.colorOrFallback(
        json['increaseColor'],
        const Color(0xFF4CAF50),
      ),
      decreaseColor: ChartColorValue.colorOrFallback(
        json['decreaseColor'],
        const Color(0xFFF44336),
      ),
      totalColor: ChartColorValue.colorOrFallback(
        json['totalColor'],
        const Color(0xFF2196F3),
      ),
      barWidthFraction:
          JsonValue.doubleOrNull(json['barWidthFraction']) ?? 0.65,
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
    ...super.toJson(),
    'series': [
      {'data': items.map((item) => item.toJson()).toList()},
    ],
    'showConnectors': showConnectors,
    'showLabels': showLabels,
    'showRunningTotal': showRunningTotal,
    'increaseColor': _colorToHex(increaseColor),
    'decreaseColor': _colorToHex(decreaseColor),
    'totalColor': _colorToHex(totalColor),
    'barWidthFraction': barWidthFraction,
  };
}

// ─────────────────────────────────────────────────────────
// Computed item (running totals)
// ─────────────────────────────────────────────────────────

class _Computed {
  final WaterfallItem item;
  final double base; // bottom of bar in data space
  final double top; // top of bar in data space
  _Computed({required this.item, required this.base, required this.top});
}

List<_Computed> _compute(List<WaterfallItem> items) {
  final result = <_Computed>[];
  double running = 0;
  for (final item in items) {
    if (item.itemType == WaterfallItemType.total) {
      result.add(_Computed(item: item, base: 0, top: item.value));
      running = item.value;
    } else {
      final base = running;
      running += item.value;
      final top = running;
      result.add(
        _Computed(
          item: item,
          base: item.value >= 0 ? base : top,
          top: item.value >= 0 ? top : base,
        ),
      );
    }
  }
  return result;
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

class WaterfallChartWidget extends StatefulWidget {
  final WaterfallChartConfig config;
  const WaterfallChartWidget({super.key, required this.config});

  @override
  State<WaterfallChartWidget> createState() => _WaterfallState();
}

class _WaterfallState extends State<WaterfallChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  int _hoveredIndex = -1;
  Offset _hoverPos = Offset.zero;

  WaterfallChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _dataSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(WaterfallChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _hoveredIndex = -1;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final computed = _compute(cfg.items);

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
              return Stack(
                children: [
                  MouseRegion(
                    onHover: (e) => setState(() {
                      _hoveredIndex = _hitTest(e.localPosition, sz, computed);
                      _hoverPos = e.localPosition;
                    }),
                    onExit: (_) => setState(() => _hoveredIndex = -1),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => setState(
                        () => _hoveredIndex = _hitTest(
                          d.localPosition,
                          sz,
                          computed,
                        ),
                      ),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _WaterfallPainter(
                            config: cfg,
                            computed: computed,
                            progress: _anim.value,
                            hoveredIndex: _hoveredIndex,
                            dataSignature: _dataSignature,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_hoveredIndex >= 0) _buildTooltip(sz, computed),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  int _hitTest(Offset pos, Size sz, List<_Computed> computed) {
    if (computed.isEmpty) return -1;
    final sp = cfg.theme.spacing;
    final vp = _makeVp(sz, computed, sp);
    final slotW = vp.width / computed.length;
    final barW = slotW * cfg.barWidthFraction;
    for (int i = 0; i < computed.length; i++) {
      final c = computed[i];
      final cx = vp.left + (i + 0.5) * slotW;
      final y1 = vp.toCanvasY(c.top);
      final y2 = vp.toCanvasY(c.base);
      if (pos.dx >= cx - barW / 2 &&
          pos.dx <= cx + barW / 2 &&
          pos.dy >= math.min(y1, y2) &&
          pos.dy <= math.max(y1, y2)) {
        return i;
      }
    }
    return -1;
  }

  ChartViewport _makeVp(Size sz, List<_Computed> computed, ChartSpacing sp) {
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final c in computed) {
      if (c.base < minY) minY = c.base;
      if (c.top > maxY) maxY = c.top;
    }
    final pad = (maxY - minY) * 0.12 + 1;
    return ChartViewport(
      left: sp.chartPaddingLeft,
      top: sp.chartPaddingTop,
      right: sz.width - sp.chartPaddingRight,
      bottom: sz.height - sp.chartPaddingBottom,
      dataMinX: 0,
      dataMaxX: computed.length.toDouble(),
      dataMinY: (minY - pad).clamp(double.negativeInfinity, 0),
      dataMaxY: maxY + pad,
    );
  }

  Widget _buildTooltip(Size sz, List<_Computed> computed) {
    final c = computed[_hoveredIndex];
    final sign = c.item.value >= 0 ? '+' : '';
    double x = (_hoverPos.dx + 14).clamp(0, sz.width - 180.0);
    double y = (_hoverPos.dy - 60).clamp(0, sz.height - 90.0);
    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: cfg.theme.tooltipBackgroundColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: DefaultTextStyle(
            style: cfg.theme.typography.tooltipStyle.copyWith(
              color: cfg.theme.tooltipTextColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('$sign${c.item.value.toStringAsFixed(0)}'),
                Text('Running total: ${c.top.toStringAsFixed(0)}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────

class _WaterfallPainter extends ChartPainterBase {
  final WaterfallChartConfig config;
  final List<_Computed> computed;
  final double progress;
  final int hoveredIndex;
  final String dataSignature;

  _WaterfallPainter({
    required this.config,
    required this.computed,
    required this.progress,
    required this.hoveredIndex,
    required this.dataSignature,
  }) : super(theme: config.theme);

  @override
  bool shouldRepaintChart(covariant _WaterfallPainter old) =>
      old.progress != progress ||
      old.hoveredIndex != hoveredIndex ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    if (computed.isEmpty) return;
    final sp = theme.spacing;

    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final c in computed) {
      if (c.base < minY) minY = c.base;
      if (c.top > maxY) maxY = c.top;
    }
    final pad = (maxY - minY) * 0.12 + 1;
    final vp = ChartViewport(
      left: sp.chartPaddingLeft,
      top: sp.chartPaddingTop,
      right: size.width - sp.chartPaddingRight,
      bottom: size.height - sp.chartPaddingBottom,
      dataMinX: 0,
      dataMaxX: computed.length.toDouble(),
      dataMinY: (minY - pad).clamp(double.negativeInfinity, 0),
      dataMaxY: maxY + pad,
    );

    final yTicks = ChartDataProcessor.niceYTicks(vp.dataMinY, vp.dataMaxY);
    drawHorizontalGrid(canvas, vp, yTicks);
    drawYAxisLabels(canvas, vp, yTicks, (v) => v.toStringAsFixed(0));

    // Zero line
    if (vp.dataMinY < 0) {
      final zy = vp.toCanvasY(0);
      canvas.drawLine(
        Offset(vp.left, zy),
        Offset(vp.right, zy),
        paintCache.stroke(theme.axisColor, 1.5),
      );
    }

    final slotW = vp.width / computed.length;
    final barW = slotW * config.barWidthFraction;

    for (int i = 0; i < computed.length; i++) {
      final c = computed[i];
      final cx = vp.left + (i + 0.5) * slotW;
      final x1 = cx - barW / 2;
      final topData = c.top;
      final baseData = c.base;

      // Animated bar height
      final topY = vp.toCanvasY(topData);
      final baseY = vp.toCanvasY(baseData);
      final barH = (baseY - topY).abs() * progress;
      final barTop = math.min(topY, baseY);

      Color color;
      if (c.item.color != null) {
        color = colorCache.resolve(c.item.color!);
      } else {
        color = switch (c.item.itemType) {
          WaterfallItemType.increase => config.increaseColor,
          WaterfallItemType.decrease => config.decreaseColor,
          WaterfallItemType.total => config.totalColor,
        };
      }
      final isHov = i == hoveredIndex;
      if (isHov) color = Color.lerp(color, Colors.white, 0.2)!;

      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(x1, barTop, barW, barH),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawRRect(
        rr,
        paintCache.stroke(Colors.white.withValues(alpha: 0.3), 0.8),
      );

      // Connector line to next bar
      if (config.showConnectors && i < computed.length - 1) {
        final connY = vp.toCanvasY(
          c.item.itemType == WaterfallItemType.total ? c.top : c.top,
        );
        canvas.drawLine(
          Offset(x1 + barW, connY),
          Offset(x1 + slotW, connY),
          paintCache.stroke(theme.axisColor.withValues(alpha: 0.5), 1),
        );
      }

      // Label above bar
      if (config.showLabels) {
        final sign =
            c.item.value >= 0 && c.item.itemType != WaterfallItemType.total
            ? '+'
            : '';
        final label = '$sign${c.item.value.toStringAsFixed(0)}';
        final tp = textPainterCache.get(
          label,
          theme.typography.axisLabelStyle.copyWith(color: color, fontSize: 9.5),
        );
        tp.paint(canvas, Offset(cx - tp.width / 2, barTop - tp.height - 2));
      }

      // X-axis label
      final labelTp = textPainterCache.get(
        c.item.name,
        theme.typography.axisLabelStyle.copyWith(color: theme.axisLabelColor),
        maxWidth: slotW - 4,
        align: TextAlign.center,
      );
      labelTp.paint(canvas, Offset(cx - labelTp.width / 2, vp.bottom + 4));
    }

    // Axes
    canvas.drawLine(
      Offset(vp.left, vp.bottom),
      Offset(vp.right, vp.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(vp.left, vp.top),
      Offset(vp.left, vp.bottom),
      axisPaint,
    );
  }
}
