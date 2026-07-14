import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_render_pipeline.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_cache.dart';
import 'pie_json_helpers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 8. PIE LABEL ALIGN  (polyline to right-aligned labels)
// ═══════════════════════════════════════════════════════════════════════════
class PieLabelAlignConfig extends BaseChartConfig {
  final List<PieSlice2> slices;
  final double padAngle;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  PieLabelAlignConfig({
    required this.slices,
    this.theme = ChartTheme.light,
    this.padAngle = 0.02,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.pieLabelAlign, series: const []);

  @override
  Widget buildChart() => _PieLabelAlignWidget(config: this);

  factory PieLabelAlignConfig.fromJson(Map<String, dynamic> j) {
    final slices = PieJson.sliceMaps(
      j,
    ).map(PieSlice2.fromJson).toList(growable: false);
    return PieLabelAlignConfig(
      slices: slices,
      padAngle: PieJson.angleGap(j['padAngle'], 0.02),
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
    'padAngle': padAngle,
  };
}

class PieSlice2 {
  final String name;
  final double value;
  final String? color;
  const PieSlice2({required this.name, required this.value, this.color});
  factory PieSlice2.fromJson(Map<String, dynamic> j) => PieSlice2(
    name: PieJson.string(j['name']) ?? '',
    value: PieJson.nonNegativeDouble(j['value'], 0),
    color: PieJson.string(j['color']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    if (color != null) 'color': color,
  };
}

class _PieLabelAlignWidget extends StatefulWidget {
  final PieLabelAlignConfig config;
  const _PieLabelAlignWidget({required this.config});
  @override
  State<_PieLabelAlignWidget> createState() => _PieLAState();
}

class _PieLAState extends State<_PieLabelAlignWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  ChartRenderPipeline? _pipeline;
  late String _dataSignature;
  PieLabelAlignConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _initPipeline();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
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
      _PieLASlicesLayer(this),
      _PieLALabelsLayer(this),
    ]);
  }

  @override
  void didUpdateWidget(_PieLabelAlignWidget oldWidget) {
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
  Widget build(BuildContext context) => Column(
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
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _PieLAPainter(
              pipeline: _pipeline!,
              progress: _anim.value,
              dataSignature: _dataSignature,
              theme: cfg.theme,
            ),
          ),
        ),
      ),
    ],
  );
}

class _PieLAPainter extends ChartPainterBase {
  final ChartRenderPipeline pipeline;
  final double progress;
  final String dataSignature;

  _PieLAPainter({
    required this.pipeline,
    required this.progress,
    required this.dataSignature,
    required super.theme,
  });

  @override
  bool shouldRepaintChart(covariant _PieLAPainter o) =>
      o.progress != progress ||
      o.pipeline != pipeline ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    pipeline.paint(canvas, size);
  }
}

class _PieLASlicesLayer extends BaseRenderLayer {
  final _PieLAState state;
  _PieLASlicesLayer(this.state);

  @override
  String get name => 'pie_la_slices';

  @override
  bool get cacheable => false;

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final progress = state._anim.value;
    if (cfg.slices.isEmpty) return;

    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) * 0.5;
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
        ..moveTo(cx, cy)
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          start + cfg.padAngle / 2,
          sweep - cfg.padAngle,
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
      start += sweep;
    }
    clearDirty();
  }
}

class _PieLALabelsLayer extends BaseRenderLayer {
  final _PieLAState state;
  _PieLALabelsLayer(this.state);

  @override
  String get name => 'pie_la_labels';

  @override
  bool get cacheable => false;

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final progress = state._anim.value;
    if (cfg.slices.isEmpty) return;

    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) * 0.5;
    final total = cfg.slices.fold(0.0, (a, s) => a + s.value);
    if (total == 0) return;

    final labelData =
        <
          ({
            Offset anchor,
            Offset elbow,
            bool isRight,
            String text,
            Color color,
          })
        >[];
    double start = -math.pi / 2;
    for (int i = 0; i < cfg.slices.length; i++) {
      final s = cfg.slices[i];
      final sweep = s.value / total * 2 * math.pi * progress;
      final mid = start + sweep / 2;
      Color color;
      try {
        color = s.color != null
            ? colorCache.resolve(s.color!)
            : theme.palette.colorObjectAt(i);
      } catch (_) {
        color = theme.palette.colorObjectAt(i);
      }

      final anchor = Offset(cx + r * math.cos(mid), cy + r * math.sin(mid));
      final elbow = Offset(
        cx + (r + 24) * math.cos(mid),
        cy + (r + 24) * math.sin(mid),
      );
      final isRight = math.cos(mid) >= 0;
      final pct = '${(s.value / total * 100).toStringAsFixed(1)}%';
      labelData.add((
        anchor: anchor,
        elbow: elbow,
        isRight: isRight,
        text: '${s.name}  $pct',
        color: color,
      ));
      start += sweep;
    }

    const edgeX = 12.0, elbowEndX = 16.0;
    final rightLabels = labelData.where((l) => l.isRight).toList()
      ..sort((a, b) => a.elbow.dy.compareTo(b.elbow.dy));
    final leftLabels = labelData.where((l) => !l.isRight).toList()
      ..sort((a, b) => a.elbow.dy.compareTo(b.elbow.dy));

    void drawLabel(
      ({Offset anchor, Offset elbow, bool isRight, String text, Color color})
      ld,
      double alignedY,
    ) {
      final tp = textPainterCache.get(
        ld.text,
        theme.typography.axisLabelStyle.copyWith(
          color: ld.color,
          fontSize: 9.5,
        ),
      );
      final endX = ld.isRight ? size.width - edgeX - tp.width : edgeX;
      final p3 = Offset(ld.isRight ? endX + tp.width : endX, alignedY);
      canvas.drawLine(ld.anchor, ld.elbow, paintCache.stroke(ld.color, 1.0));
      canvas.drawLine(ld.elbow, p3, paintCache.stroke(ld.color, 1.0));
      canvas.drawLine(
        p3,
        Offset(p3.dx + (ld.isRight ? elbowEndX : -elbowEndX), p3.dy),
        paintCache.stroke(ld.color, 1.0),
      );
      tp.paint(canvas, Offset(endX, alignedY - tp.height / 2));
    }

    for (int i = 0; i < rightLabels.length; i++) {
      final spacing = math.max(
        14.0,
        (size.height - 32) / math.max(rightLabels.length, 1),
      );
      drawLabel(rightLabels[i], 16 + i * spacing);
    }
    for (int i = 0; i < leftLabels.length; i++) {
      final spacing = math.max(
        14.0,
        (size.height - 32) / math.max(leftLabels.length, 1),
      );
      drawLabel(leftLabels[i], 16 + i * spacing);
    }
    clearDirty();
  }
}
