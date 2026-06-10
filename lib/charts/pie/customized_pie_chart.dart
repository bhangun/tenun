import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/base_config.dart';
import '../../core/chart_data_signature.dart';
import '../../core/chart_render_pipeline.dart';
import '../../core/chart_type.dart';
import '../../core/chart_theme.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_cache.dart';
import 'pie_json_helpers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 7. CUSTOMIZED PIE  (per-slice custom styles + individual explode)
// ═══════════════════════════════════════════════════════════════════════════
class CustomPieSlice {
  final String name;
  final double value;
  final String? color, borderColor;
  final double borderWidth, explode;
  final bool selected;
  const CustomPieSlice({
    required this.name,
    required this.value,
    this.color,
    this.borderColor,
    this.borderWidth = 0,
    this.explode = 0,
    this.selected = false,
  });
  factory CustomPieSlice.fromJson(Map<String, dynamic> j) => CustomPieSlice(
    name: PieJson.string(j['name']) ?? '',
    value: PieJson.nonNegativeDouble(j['value'], 0),
    color: PieJson.string(j['color']),
    borderColor: PieJson.string(j['borderColor']),
    borderWidth: PieJson.nonNegativeDouble(j['borderWidth'], 0),
    explode: PieJson.nonNegativeDouble(
      j['explode'],
      0,
    ).clamp(0.0, 48.0).toDouble(),
    selected: PieJson.boolOr(j['selected'], false),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    if (color != null) 'color': color,
    if (borderColor != null) 'borderColor': borderColor,
    'borderWidth': borderWidth,
    'explode': explode,
    'selected': selected,
  };
}

class CustomizedPieConfig extends BaseChartConfig {
  final List<CustomPieSlice> slices;
  final double padAngle;
  final bool showLabels;

  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  CustomizedPieConfig({
    required this.slices,
    this.theme = ChartTheme.light,
    this.padAngle = 0.02,
    this.showLabels = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.customizedPie, series: const []);

  @override
  Widget buildChart() => _CustomPieWidget(config: this);

  factory CustomizedPieConfig.fromJson(Map<String, dynamic> j) {
    final slices = PieJson.sliceMaps(
      j,
    ).map(CustomPieSlice.fromJson).toList(growable: false);
    return CustomizedPieConfig(
      slices: slices,
      padAngle: PieJson.angleGap(j['padAngle'], 0.02),
      showLabels: PieJson.boolOr(j['showLabels'], true),
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
    'showLabels': showLabels,
  };
}

class _CustomPieWidget extends StatefulWidget {
  final CustomizedPieConfig config;
  const _CustomPieWidget({required this.config});
  @override
  State<_CustomPieWidget> createState() => _CustomPieState();
}

class _CustomPieState extends State<_CustomPieWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  ChartRenderPipeline? _pipeline;
  late String _dataSignature;
  CustomizedPieConfig get cfg => widget.config;

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
      _CustomPieSlicesLayer(this),
      _CustomPieLabelsLayer(this),
    ]);
  }

  @override
  void didUpdateWidget(_CustomPieWidget oldWidget) {
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
            painter: _CustomPiePainter(
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

class _CustomPiePainter extends ChartPainterBase {
  final ChartRenderPipeline pipeline;
  final double progress;
  final String dataSignature;

  _CustomPiePainter({
    required this.pipeline,
    required this.progress,
    required this.dataSignature,
    required super.theme,
  });

  @override
  bool shouldRepaintChart(covariant _CustomPiePainter o) =>
      o.progress != progress ||
      o.pipeline != pipeline ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    pipeline.paint(canvas, size);
  }
}

class _CustomPieSlicesLayer extends BaseRenderLayer {
  final _CustomPieState state;
  _CustomPieSlicesLayer(this.state);

  @override
  String get name => 'custom_pie_slices';

  @override
  bool get cacheable => false;

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    final theme = cfg.theme;
    final progress = state._anim.value;
    if (cfg.slices.isEmpty) return;

    final cx = size.width / 2, cy = size.height / 2;
    final maxExplode = cfg.slices.map((s) => s.explode).fold(0.0, math.max);
    final r = math.min(cx, cy) * 0.75 - maxExplode;
    if (r <= 0) return;
    final total = cfg.slices.fold(0.0, (a, s) => a + s.value);
    if (total == 0) return;

    double start = -math.pi / 2;
    for (int i = 0; i < cfg.slices.length; i++) {
      final s = cfg.slices[i];
      final sweep = s.value / total * 2 * math.pi * progress;
      final midAngle = start + sweep / 2;
      final explode = s.explode + (s.selected ? 8.0 : 0.0);
      final oc = Offset(
        cx + explode * math.cos(midAngle),
        cy + explode * math.sin(midAngle),
      );

      Color fill;
      try {
        fill = s.color != null
            ? colorCache.resolve(s.color!)
            : theme.palette.colorObjectAt(i);
      } catch (_) {
        fill = theme.palette.colorObjectAt(i);
      }

      final path = Path()
        ..moveTo(oc.dx, oc.dy)
        ..arcTo(
          Rect.fromCircle(center: oc, radius: r),
          start + cfg.padAngle / 2,
          sweep - cfg.padAngle,
          false,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = fill
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      if (s.borderWidth > 0) {
        Color bc;
        try {
          bc = s.borderColor != null
              ? colorCache.resolve(s.borderColor!)
              : Colors.white;
        } catch (_) {
          bc = Colors.white;
        }
        canvas.drawPath(
          path,
          paintCache.stroke(bc, s.borderWidth)..isAntiAlias = true,
        );
      }
      start += sweep;
    }
    clearDirty();
  }
}

class _CustomPieLabelsLayer extends BaseRenderLayer {
  final _CustomPieState state;
  _CustomPieLabelsLayer(this.state);

  @override
  String get name => 'custom_pie_labels';

  @override
  bool get cacheable => false;

  @override
  void paint(Canvas canvas, Size size) {
    final cfg = state.widget.config;
    if (!cfg.showLabels) return;
    final theme = cfg.theme;
    final progress = state._anim.value;
    if (cfg.slices.isEmpty) return;

    final cx = size.width / 2, cy = size.height / 2;
    final maxExplode = cfg.slices.map((s) => s.explode).fold(0.0, math.max);
    final r = math.min(cx, cy) * 0.75 - maxExplode;
    if (r <= 0) return;
    final total = cfg.slices.fold(0.0, (a, s) => a + s.value);
    if (total == 0) return;

    double start = -math.pi / 2;
    for (int i = 0; i < cfg.slices.length; i++) {
      final s = cfg.slices[i];
      final sweep = s.value / total * 2 * math.pi * progress;
      final midAngle = start + sweep / 2;

      if (sweep > 0.2) {
        final explode = s.explode + (s.selected ? 8.0 : 0.0);
        final oc = Offset(
          cx + explode * math.cos(midAngle),
          cy + explode * math.sin(midAngle),
        );
        final lr = r * 0.65;
        final lx = oc.dx + lr * math.cos(midAngle);
        final ly = oc.dy + lr * math.sin(midAngle);
        final pct = '${(s.value / total * 100).toStringAsFixed(0)}%';
        final tp = textPainterCache.get(
          pct,
          (theme.typography.dataLabelStyle ?? theme.typography.axisLabelStyle)
              .copyWith(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
        );
        tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
      }
      start += sweep;
    }
    clearDirty();
  }
}
