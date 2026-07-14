import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'polar_line_config.dart';

class PolarLineWidget extends StatefulWidget {
  final PolarLineChartConfig config;
  const PolarLineWidget({super.key, required this.config});
  @override
  State<PolarLineWidget> createState() => _PolarLineState();
}

class _PolarLineState extends State<PolarLineWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  PolarLineChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _dataSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(PolarLineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
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
            painter: _PolarLinePainter(
              cfg: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
      _buildLegend(),
    ],
  );

  Widget _buildLegend() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      spacing: 12,
      alignment: WrapAlignment.center,
      children: cfg.series.asMap().entries.map((e) {
        final color = cfg.theme.seriesColor(
          e.key,
          explicitColor: e.value.color,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: 4),
            Text(
              e.value.name ?? 'S${e.key + 1}',
              style: cfg.theme.typography.legendStyle.copyWith(
                color: cfg.theme.legendTextColor,
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );
}

class _PolarLinePainter extends ChartPainterBase {
  final PolarLineChartConfig cfg;
  final double progress;
  final String dataSignature;

  _PolarLinePainter({
    required this.cfg,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _PolarLinePainter o) =>
      o.progress != progress || o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) * 0.85;

    // Grid (circular)
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * i / 5,
        paintCache.stroke(theme.gridColor, 0.5),
      );
    }
    // Grid (spokes)
    final n = cfg.categories.length;
    for (int i = 0; i < n; i++) {
      final angle = i / n * 2 * math.pi - math.pi / 2;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      // Labels
      final tp = textPainterCache.get(
        cfg.categories[i],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
      );
      tp.paint(
        canvas,
        Offset(
          cx + (r + 12) * math.cos(angle) - tp.width / 2,
          cy + (r + 12) * math.sin(angle) - tp.height / 2,
        ),
      );
    }

    // Max val for scaling
    double maxV = 0.001;
    for (final s in cfg.series) {
      for (final v in s.data ?? []) {
        final value = ChartDataValueReader.yValue(v);
        if (value > maxV) maxV = value;
      }
    }

    // Series
    for (int si = 0; si < cfg.series.length; si++) {
      final s = cfg.series[si];
      final color = theme.seriesColor(si, explicitColor: s.color);
      final pts = <Offset>[];
      for (int i = 0; i < n; i++) {
        final d = s.data;
        if (d == null || i >= d.length) continue;
        final val = ChartDataValueReader.yValue(d[i]);
        final angle = i / n * 2 * math.pi - math.pi / 2;
        final dist = (val / maxV) * r * progress;
        pts.add(
          Offset(cx + dist * math.cos(angle), cy + dist * math.sin(angle)),
        );
      }
      if (pts.length >= 2) {
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (int i = 1; i < pts.length; i++) {
          path.lineTo(pts[i].dx, pts[i].dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: 0.2)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          paintCache.stroke(color, 2)..style = PaintingStyle.stroke,
        );
        for (final p in pts) {
          canvas.drawCircle(p, 3.5, Paint()..color = color);
          canvas.drawCircle(
            p,
            3.5,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
  }
}
