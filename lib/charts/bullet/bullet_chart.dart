/// Bullet chart — compact KPI bar showing actual vs target with qualitative bands.
///
/// Originally designed by Stephen Few as a replacement for dashboard gauges.
/// Shows: (1) qualitative bands (poor/satisfactory/good), (2) actual value bar,
/// (3) target/comparative measure marker.
///
/// JSON:
/// ```json
/// {
///   "type": "bullet",
///   "series": [{
///     "data": [
///       { "label": "Revenue",  "value": 270, "target": 300, "max": 400,
///         "bands": [{"to":200,"color":"#F44336"},{"to":280,"color":"#FF9800"},{"to":400,"color":"#4CAF50"}] },
///       { "label": "Margin",   "value": 23,  "target": 25,  "max": 35 },
///       { "label": "Customers","value": 1850,"target": 2000,"max": 2500}
///     ]
///   }]
/// }
/// ```
library;

import 'package:flutter/material.dart';

import '../../core/base_config.dart';
import '../../core/chart_type.dart';
import '../../core/chart_theme.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';
import '../../core/legend.dart';
import '../../core/grid.dart';
import '../../core/chart_model.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_data_signature.dart';
import '../../core/chart_color_value.dart';
import '../../core/chart_series_json.dart';
import '../../core/json_value.dart';

// ─────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────

class BulletBand {
  final double from;
  final double to;
  final Color color;
  const BulletBand({required this.from, required this.to, required this.color});
  factory BulletBand.fromJson(Map<String, dynamic> j) => BulletBand(
    from: JsonValue.doubleOrNull(j['from']) ?? 0,
    to: JsonValue.doubleOrNull(j['to']) ?? 100,
    color: ChartColorValue.colorOrFallback(j['color'], const Color(0xFFCCCCCC)),
  );

  Map<String, dynamic> toJson() => {
    'from': from,
    'to': to,
    'color': _colorToHex(color),
  };
}

class BulletItem {
  final String label;
  final double value;
  final double target;
  final double max;
  final List<BulletBand> bands;
  const BulletItem({
    required this.label,
    required this.value,
    required this.target,
    required this.max,
    this.bands = const [],
  });
  factory BulletItem.fromJson(Map<String, dynamic> j) => BulletItem(
    label: j['label']?.toString() ?? '',
    value: JsonValue.doubleOrNull(j['value']) ?? 0,
    target: JsonValue.doubleOrNull(j['target']) ?? 0,
    max: JsonValue.doubleOrNull(j['max']) ?? 100,
    bands: ChartSeriesJson.mapList(
      j['bands'],
    ).map(BulletBand.fromJson).toList(),
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'target': target,
    'max': max,
    if (bands.isNotEmpty) 'bands': bands.map((band) => band.toJson()).toList(),
  };
}

String _colorToHex(Color color) {
  String channel(double value) =>
      (value * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${channel(color.a)}${channel(color.r)}${channel(color.g)}${channel(color.b)}';
}

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

class BulletChartConfig extends BaseChartConfig {
  final List<BulletItem> items;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;
  final double barHeightFraction;
  final bool showLabels;
  final bool showValues;

  BulletChartConfig({
    required this.items,
    this.theme = ChartTheme.light,
    this.barHeightFraction = 0.35,
    this.showLabels = true,
    this.showValues = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.bullet, series: const []);

  @override
  Widget buildChart() => BulletChartWidget(config: this);

  factory BulletChartConfig.fromJson(Map<String, dynamic> json) {
    final items = ChartSeriesJson.firstSeriesData(
      json['series'],
    ).map(BulletItem.fromJson).toList();
    return BulletChartConfig(
      items: items,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? true,
      showValues: JsonValue.boolOrNull(json['showValues']) ?? true,
      barHeightFraction:
          JsonValue.doubleOrNull(json['barHeightFraction']) ?? 0.35,
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
    'barHeightFraction': barHeightFraction,
    'showLabels': showLabels,
    'showValues': showValues,
  };
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

class BulletChartWidget extends StatefulWidget {
  final BulletChartConfig config;
  const BulletChartWidget({super.key, required this.config});
  @override
  State<BulletChartWidget> createState() => _BulletState();
}

class _BulletState extends State<BulletChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  int _hovIdx = -1;
  Offset _hoverPos = Offset.zero;

  BulletChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant BulletChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature == _dataSignature) return;
    _dataSignature = nextSignature;
    _ctrl.forward(from: 0);
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
              return Stack(
                children: [
                  MouseRegion(
                    onHover: (e) => setState(() {
                      if (cfg.items.isEmpty) {
                        _hovIdx = -1;
                        return;
                      }
                      final rowH = sz.height / cfg.items.length;
                      _hovIdx = ((e.localPosition.dy) / rowH).floor().clamp(
                        0,
                        cfg.items.length - 1,
                      );
                      _hoverPos = e.localPosition;
                    }),
                    onExit: (_) => setState(() => _hovIdx = -1),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _BulletPainter(
                          config: cfg,
                          progress: _anim.value,
                          hovIdx: _hovIdx,
                          dataSignature: _dataSignature,
                        ),
                      ),
                    ),
                  ),
                  if (_hovIdx >= 0) _buildTooltip(sz),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTooltip(Size sz) {
    final item = cfg.items[_hovIdx];
    final pct = (item.value / item.max * 100).toStringAsFixed(1);
    final tpct = (item.target / item.max * 100).toStringAsFixed(1);
    double x = (_hoverPos.dx + 12).clamp(0, sz.width - 200.0);
    double y = (_hoverPos.dy - 70).clamp(0, sz.height - 100.0);
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
                  item.label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Actual:  ${item.value.toStringAsFixed(0)} ($pct%)'),
                Text('Target:  ${item.target.toStringAsFixed(0)} ($tpct%)'),
                Text(
                  'vs Target: ${((item.value / item.target - 1) * 100).toStringAsFixed(1)}%',
                ),
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

class _BulletPainter extends ChartPainterBase {
  final BulletChartConfig config;
  final double progress;
  final int hovIdx;
  final String dataSignature;

  _BulletPainter({
    required this.config,
    required this.progress,
    required this.hovIdx,
    required this.dataSignature,
  }) : super(theme: config.theme);

  @override
  bool shouldRepaintChart(covariant _BulletPainter old) =>
      old.progress != progress ||
      old.hovIdx != hovIdx ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    if (config.items.isEmpty) return;
    const labelW = 90.0, padR = 16.0, padV = 8.0;
    final n = config.items.length;
    final rowH = (size.height - padV * 2) / n;

    for (int i = 0; i < n; i++) {
      final item = config.items[i];
      final isHov = i == hovIdx;
      final rowY = padV + i * rowH;
      final chartX = labelW;
      final chartW = size.width - labelW - padR;
      final barH = rowH * config.barHeightFraction;
      final barY = rowY + (rowH - barH) / 2;

      // Background bands
      final hasBands = item.bands.isNotEmpty;
      if (hasBands) {
        for (final band in item.bands) {
          final x1 = chartX + (band.from / item.max) * chartW;
          final x2 = chartX + (band.to / item.max) * chartW;
          canvas.drawRect(
            Rect.fromLTWH(x1, rowY + rowH * 0.1, x2 - x1, rowH * 0.8),
            Paint()
              ..color = band.color.withValues(alpha: 0.3)
              ..style = PaintingStyle.fill,
          );
        }
      } else {
        // Default 3-band grey gradient
        for (int b = 0; b < 3; b++) {
          final x1 = chartX + b / 3 * chartW;
          final bw = chartW / 3;
          canvas.drawRect(
            Rect.fromLTWH(x1, rowY + rowH * 0.1, bw, rowH * 0.8),
            Paint()
              ..color = Color.lerp(
                const Color(0xFFE0E0E0),
                const Color(0xFF9E9E9E),
                b / 2,
              )!.withValues(alpha: 0.4)
              ..style = PaintingStyle.fill,
          );
        }
      }

      // Actual bar
      final actualW = (item.value / item.max * chartW * progress).clamp(
        0.0,
        chartW,
      );
      final barColor = isHov
          ? Color.lerp(theme.palette.colorObjectAt(0), Colors.white, 0.2)!
          : theme.palette.colorObjectAt(0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chartX, barY, actualW, barH),
          const Radius.circular(2),
        ),
        Paint()
          ..color = barColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      // Target marker (vertical line)
      final targetX =
          chartX + (item.target / item.max * chartW).clamp(0.0, chartW);
      canvas.drawLine(
        Offset(targetX, rowY + rowH * 0.15),
        Offset(targetX, rowY + rowH * 0.85),
        paintCache.stroke(const Color(0xFF1A1A1A), 3),
      );

      // Label
      if (config.showLabels) {
        final tp = textPainterCache.get(
          item.label,
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 11,
          ),
          maxWidth: labelW - 4,
          align: TextAlign.right,
        );
        tp.paint(
          canvas,
          Offset(labelW - tp.width - 4, rowY + rowH / 2 - tp.height / 2),
        );
      }

      // Value label
      if (config.showValues) {
        final vtp = textPainterCache.get(
          item.value.toStringAsFixed(0),
          theme.typography.axisLabelStyle.copyWith(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        );
        if (actualW > vtp.width + 6) {
          vtp.paint(
            canvas,
            Offset(
              chartX + actualW - vtp.width - 4,
              barY + barH / 2 - vtp.height / 2,
            ),
          );
        }
      }
    }
  }
}
