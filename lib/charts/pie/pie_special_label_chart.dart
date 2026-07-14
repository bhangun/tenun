import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/chart_render_pipeline.dart';
import 'pie_json_helpers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 9. PIE SPECIAL LABEL  (custom rich label per slice rendered with Flutter)
// ═══════════════════════════════════════════════════════════════════════════
class SpecialLabelSlice {
  final String name;
  final double value;
  final String? color;
  final String? emoji; // optional emoji/icon shown in label
  final String? subLabel; // secondary line in label
  const SpecialLabelSlice({
    required this.name,
    required this.value,
    this.color,
    this.emoji,
    this.subLabel,
  });
  factory SpecialLabelSlice.fromJson(Map<String, dynamic> j) =>
      SpecialLabelSlice(
        name: PieJson.string(j['name']) ?? '',
        value: PieJson.nonNegativeDouble(j['value'], 0),
        color: PieJson.string(j['color']),
        emoji: PieJson.string(j['emoji']),
        subLabel: PieJson.string(j['subLabel']),
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    if (color != null) 'color': color,
    if (emoji != null) 'emoji': emoji,
    if (subLabel != null) 'subLabel': subLabel,
  };
}

class PieSpecialLabelConfig extends BaseChartConfig {
  final List<SpecialLabelSlice> slices;
  final double innerRadiusRatio;
  final double padAngle;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  PieSpecialLabelConfig({
    required this.slices,
    this.theme = ChartTheme.light,
    this.innerRadiusRatio = 0.45,
    this.padAngle = 0.03,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.pieSpecialLabel, series: const []);

  @override
  Widget buildChart() => _PieSpecialWidget(config: this);

  factory PieSpecialLabelConfig.fromJson(Map<String, dynamic> j) {
    final slices = PieJson.sliceMaps(
      j,
    ).map(SpecialLabelSlice.fromJson).toList(growable: false);
    return PieSpecialLabelConfig(
      slices: slices,
      innerRadiusRatio: PieJson.ratio(j['innerRadiusRatio'], 0.45),
      padAngle: PieJson.angleGap(j['padAngle'], 0.03),
      title: PieJson.title(j['title']),
      tooltip: PieJson.tooltip(j['tooltip']),
      legend: PieJson.legend(j['legend']),
      toolbox: PieJson.toolbox(j['toolbox']),
      grid: PieJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'series': [
      {'data': slices.map((slice) => slice.toJson()).toList()},
    ],
    'innerRadiusRatio': innerRadiusRatio,
    'padAngle': padAngle,
  };
}

class _PieSpecialWidget extends StatefulWidget {
  final PieSpecialLabelConfig config;
  const _PieSpecialWidget({required this.config});
  @override
  State<_PieSpecialWidget> createState() => _PieSpecialState();
}

class _PieSpecialState extends State<_PieSpecialWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  ChartRenderPipeline? _pipeline;
  late String _dataSignature;
  PieSpecialLabelConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _initPipeline();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.addListener(() {
      _pipeline?.markAllDirty();
      setState(() {});
    });
    _ctrl.forward();
  }

  void _initPipeline() {
    _pipeline?.dispose();
    _pipeline = ChartRenderPipeline([
      BackgroundLayer(cfg.theme),
      _PieSpecialSlicesLayer(this),
    ]);
  }

  @override
  void didUpdateWidget(_PieSpecialWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    final dataChanged = nextSignature != _dataSignature;
    if (widget.config != oldWidget.config || dataChanged) {
      _dataSignature = nextSignature;
      _initPipeline();
      if (dataChanged) _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pipeline?.dispose();
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
              final size = Size(con.maxWidth, con.maxHeight);
              final cx = size.width / 2, cy = size.height / 2;
              final r = math.min(cx, cy) * 0.55;
              final innerR = r * cfg.innerRadiusRatio;
              final total = cfg.slices.fold(0.0, (a, s) => a + s.value);

              // Build label overlays
              final labels = <Widget>[];
              if (_anim.value > 0.6) {
                double start = -math.pi / 2;
                for (int i = 0; i < cfg.slices.length; i++) {
                  final s = cfg.slices[i];
                  final sweep = total > 0
                      ? s.value / total * 2 * math.pi * _anim.value
                      : 0;
                  final mid = start + sweep / 2;
                  final lr = (r + innerR) / 2;
                  final lx = cx + lr * math.cos(mid);
                  final ly = cy + lr * math.sin(mid);
                  if (sweep > 0.25) {
                    labels.add(
                      Positioned(
                        left: lx - 30,
                        top: ly - 24,
                        width: 60,
                        height: 48,
                        child: Opacity(
                          opacity: ((_anim.value - 0.6) / 0.4).clamp(0, 1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (s.emoji != null)
                                Text(
                                  s.emoji!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              Text(
                                '${(s.value / total * 100).toStringAsFixed(0)}%',
                                textAlign: TextAlign.center,
                                style: cfg.theme.typography.axisLabelStyle
                                    .copyWith(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              if (s.subLabel != null)
                                Text(
                                  s.subLabel!,
                                  textAlign: TextAlign.center,
                                  style: cfg.theme.typography.axisLabelStyle
                                      .copyWith(
                                        color: Colors.white70,
                                        fontSize: 8,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  start += sweep;
                }
              }

              return Stack(
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _PieSpecialPainter(
                        pipeline: _pipeline!,
                        progress: _anim.value,
                        dataSignature: _dataSignature,
                        theme: cfg.theme,
                      ),
                    ),
                  ),
                  ...labels,
                ],
              );
            },
          ),
        ),
        // Bottom legend
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: cfg.slices.asMap().entries.map((e) {
              Color color;
              try {
                color = e.value.color != null
                    ? colorCache.resolve(e.value.color!)
                    : cfg.theme.palette.colorObjectAt(e.key);
              } catch (_) {
                color = cfg.theme.palette.colorObjectAt(e.key);
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    e.value.name,
                    style: cfg.theme.typography.legendStyle.copyWith(
                      color: cfg.theme.legendTextColor,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PieSpecialPainter extends ChartPainterBase {
  final ChartRenderPipeline pipeline;
  final double progress;
  final String dataSignature;
  _PieSpecialPainter({
    required this.pipeline,
    required this.progress,
    required this.dataSignature,
    required super.theme,
  });
  @override
  bool shouldRepaintChart(covariant _PieSpecialPainter o) =>
      o.progress != progress ||
      o.pipeline != pipeline ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    pipeline.paint(canvas, size);
  }
}

class _PieSpecialSlicesLayer extends BaseRenderLayer {
  final _PieSpecialState state;
  _PieSpecialSlicesLayer(this.state);

  @override
  String get name => 'pie_special_slices';

  @override
  bool get cacheable => false;

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final progress = state._anim.value;

    if (cfg.slices.isEmpty) return;
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) * 0.55;
    final innerR = r * cfg.innerRadiusRatio;
    final total = cfg.slices.fold(0.0, (a, s) => a + s.value);
    if (total == 0) return;

    double start = -math.pi / 2;
    for (int i = 0; i < cfg.slices.length; i++) {
      final s = cfg.slices[i];
      final sweep = s.value / total * 2 * math.pi * progress;
      Color color;
      try {
        color = s.color != null
            ? colorCache.resolve(s.color!)
            : theme.palette.colorObjectAt(i);
      } catch (_) {
        color = theme.palette.colorObjectAt(i);
      }

      final path = Path()
        ..moveTo(
          cx + innerR * math.cos(start + cfg.padAngle / 2),
          cy + innerR * math.sin(start + cfg.padAngle / 2),
        )
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          start + cfg.padAngle / 2,
          sweep - cfg.padAngle,
          false,
        )
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
          start + sweep - cfg.padAngle / 2,
          -(sweep - cfg.padAngle),
          false,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = theme.backgroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..isAntiAlias = true,
      );
      start += sweep;
    }
    clearDirty();
  }
}
