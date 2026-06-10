// Sunburst chart — multi-ring radial hierarchy.
//
// Each ring represents a depth level. Root items occupy ring-0,
// their children ring-1, and so on. Tap a sector to drill into it.
// Tap the centre or the back button to go up.
//
// JSON:
// ```json
// {
//   "type": "sunburst",
//   "centerText": "Sales",
//   "showLabels": true,
//   "series": [{
//     "data": [
//       { "name": "Product A", "value": 40, "color": "#2196F3",
//         "children": [
//           { "name": "Online",  "value": 28 },
//           { "name": "Offline", "value": 12 }
//         ]},
//       { "name": "Product B", "value": 35, "color": "#4CAF50" },
//       { "name": "Product C", "value": 25, "color": "#FF9800" }
//     ]
//   }]
// }
// ```
import 'dart:math' as math;
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
import '../../core/chart_cache.dart';
import '../../core/chart_series_json.dart';
import '../../core/json_value.dart';

// ─────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────

class SunburstNode {
  final String name;
  final double value;
  final String? color;
  final List<SunburstNode> children;

  // ── layout fields (mutated by layout engine) ──
  double startAngle = 0;
  double sweepAngle = 0;
  int depth = 0;
  SunburstNode? parent;

  SunburstNode({
    required this.name,
    required this.value,
    this.color,
    this.children = const [],
  });

  bool get isLeaf => children.isEmpty;

  double get total =>
      isLeaf ? value : children.fold(0.0, (s, c) => s + c.total);

  factory SunburstNode.fromJson(Map<String, dynamic> j) => SunburstNode(
    name: j['name']?.toString() ?? '',
    value: JsonValue.doubleOrNull(j['value']) ?? 0,
    color: j['color']?.toString(),
    children: ChartSeriesJson.mapList(
      j['children'],
    ).map(SunburstNode.fromJson).toList(),
  );
}

// ─────────────────────────────────────────────────────────
// Layout engine
// ─────────────────────────────────────────────────────────

class _Layout {
  final double startRad;
  _Layout(double startDeg) : startRad = startDeg * math.pi / 180;

  void run(List<SunburstNode> roots) {
    final total = roots.fold(0.0, (s, n) => s + n.total).clamp(1e-9, 1e18);
    _place(roots, startRad, math.pi * 2, 0, total, null);
  }

  void _place(
    List<SunburstNode> nodes,
    double start,
    double sweep,
    int depth,
    double parentTotal,
    SunburstNode? parent,
  ) {
    double cursor = start;
    for (final n in nodes) {
      final s = (n.total / parentTotal) * sweep;
      n.startAngle = cursor;
      n.sweepAngle = s;
      n.depth = depth;
      n.parent = parent;
      if (n.children.isNotEmpty) {
        _place(n.children, cursor, s, depth + 1, n.total, n);
      }
      cursor += s;
    }
  }
}

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

class SunburstChartConfig extends BaseChartConfig {
  final List<SunburstNode> nodes;
  final bool showLabels;
  final bool showValues;
  final String? centerText;
  final double innerFraction; // hole size as % of radius
  final double startAngleDeg;

  SunburstChartConfig({
    required this.nodes,
    super.theme = ChartTheme.light,
    this.showLabels = true,
    this.showValues = false,
    this.centerText,
    this.innerFraction = 0.18,
    this.startAngleDeg = -90,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.sunburst, series: const []);

  @override
  Widget buildChart() => SunburstChartWidget(config: this);

  factory SunburstChartConfig.fromJson(Map<String, dynamic> json) {
    final nodes = ChartSeriesJson.firstSeriesData(
      json['series'],
    ).map(SunburstNode.fromJson).toList();

    return SunburstChartConfig(
      nodes: nodes,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? true,
      showValues: JsonValue.boolOrNull(json['showValues']) ?? false,
      centerText: json['centerText']?.toString(),
      innerFraction: JsonValue.doubleOrNull(json['innerFraction']) ?? 0.18,
      startAngleDeg: JsonValue.doubleOrNull(json['startAngle']) ?? -90,
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
    'type': 'sunburst',
    'showLabels': showLabels,
    'showValues': showValues,
    if (centerText != null) 'centerText': centerText,
    'innerFraction': innerFraction,
    'startAngle': startAngleDeg,
    'series': [
      {'data': nodes.map((n) => _nodeToJson(n)).toList()},
    ],
  };

  Map<String, dynamic> _nodeToJson(SunburstNode n) => {
    'name': n.name,
    'value': n.value,
    if (n.color != null) 'color': n.color,
    if (n.children.isNotEmpty) 'children': n.children.map(_nodeToJson).toList(),
  };
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

class SunburstChartWidget extends StatefulWidget {
  final SunburstChartConfig config;
  const SunburstChartWidget({super.key, required this.config});

  @override
  State<SunburstChartWidget> createState() => _SunburstState();
}

class _SunburstState extends State<SunburstChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  SunburstNode? _hovered;
  Offset _hoverPos = Offset.zero;
  SunburstNode? _drillRoot; // null = show full tree

  SunburstChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _layout();
    _ctrl.forward();
  }

  void _layout() => _Layout(cfg.startAngleDeg).run(cfg.nodes);

  @override
  void didUpdateWidget(covariant SunburstChartWidget old) {
    super.didUpdateWidget(old);
    if (old.config != widget.config) {
      _layout();
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── helpers ──

  int _maxDepth(List<SunburstNode> ns) {
    int m = 0;
    for (final n in ns) {
      final d = n.isLeaf ? n.depth : _maxDepth(n.children);
      if (d > m) m = d;
    }
    return m;
  }

  SunburstNode? _hitTest(Offset pos, Size sz) {
    final cx = sz.width / 2, cy = sz.height / 2;
    final maxR = math.min(cx, cy) * 0.92;
    final dx = pos.dx - cx, dy = pos.dy - cy;
    final r = math.sqrt(dx * dx + dy * dy);
    final ang = math.atan2(dy, dx);
    return _hitNodes(cfg.nodes, r, ang, maxR);
  }

  SunburstNode? _hitNodes(
    List<SunburstNode> ns,
    double r,
    double ang,
    double maxR,
  ) {
    final total = _maxDepth(cfg.nodes) + 2;
    for (final n in ns) {
      final d = n.depth + 1;
      final rW = maxR * (1 - cfg.innerFraction) / total;
      final inner = cfg.innerFraction * maxR + (d - 1) * rW;
      final outer = inner + rW;
      if (r >= inner && r <= outer) {
        final a = _norm(ang);
        final s = _norm(n.startAngle);
        double e = _norm(n.startAngle + n.sweepAngle);
        if (e < s) e += math.pi * 2;
        final aa = a < s ? a + math.pi * 2 : a;
        if (aa >= s && aa <= e) return n;
      }
      if (n.children.isNotEmpty) {
        final hit = _hitNodes(n.children, r, ang, maxR);
        if (hit != null) return hit;
      }
    }
    return null;
  }

  double _norm(double a) {
    while (a < 0) {
      a += math.pi * 2;
    }
    while (a >= math.pi * 2) {
      a -= math.pi * 2;
    }
    return a;
  }

  void _onTap(Offset pos, Size sz) {
    final hit = _hitTest(pos, sz);
    setState(() {
      if (hit != null && hit.children.isNotEmpty) {
        _drillRoot = hit;
      } else if (hit == null) {
        _drillRoot = _drillRoot?.parent;
      }
      _ctrl.forward(from: 0);
    });
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
                      _hovered = _hitTest(e.localPosition, sz);
                      _hoverPos = e.localPosition;
                    }),
                    onExit: (_) => setState(() => _hovered = null),
                    child: GestureDetector(
                      onTapUp: (d) => _onTap(d.localPosition, sz),
                      behavior: HitTestBehavior.opaque,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _SunburstPainter(
                            nodes: cfg.nodes,
                            theme: cfg.theme,
                            progress: _anim.value,
                            hovered: _hovered,
                            showLabels: cfg.showLabels,
                            showValues: cfg.showValues,
                            innerFraction: cfg.innerFraction,
                            centerText: _drillRoot?.name ?? cfg.centerText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tooltip
                  if (_hovered != null)
                    _Tooltip(
                      node: _hovered!,
                      pos: _hoverPos,
                      size: sz,
                      theme: cfg.theme,
                    ),
                  // Back button
                  if (_drillRoot != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _BackButton(
                        onTap: () => setState(() {
                          _drillRoot = _drillRoot!.parent;
                          _ctrl.forward(from: 0);
                        }),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────

class _SunburstPainter extends ChartPainterBase {
  final List<SunburstNode> nodes;
  final double progress;
  final SunburstNode? hovered;
  final bool showLabels;
  final bool showValues;
  final double innerFraction;
  final String? centerText;

  _SunburstPainter({
    required this.nodes,
    required super.theme,
    required this.progress,
    this.hovered,
    this.showLabels = true,
    this.showValues = false,
    this.innerFraction = 0.18,
    this.centerText,
  });

  @override
  bool shouldRepaintChart(covariant _SunburstPainter old) =>
      old.progress != progress || old.hovered != hovered || old.nodes != nodes;

  int _maxDepth(List<SunburstNode> ns) {
    int m = 0;
    for (final n in ns) {
      final d = n.isLeaf ? n.depth : _maxDepth(n.children);
      if (d > m) m = d;
    }
    return m;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final maxR = math.min(cx, cy) * 0.92;
    final totalRings = _maxDepth(nodes) + 2;

    _paintNodes(canvas, nodes, cx, cy, maxR, totalRings);

    // Centre text
    if (centerText != null && centerText!.isNotEmpty) {
      final innerR = innerFraction * maxR;
      final tp = textPainterCache.get(
        centerText!,
        theme.typography.titleStyle.copyWith(
          color: theme.titleColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: innerR * 1.8,
        align: TextAlign.center,
      );
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  void _paintNodes(
    Canvas canvas,
    List<SunburstNode> ns,
    double cx,
    double cy,
    double maxR,
    int totalRings,
  ) {
    for (final n in ns) {
      _paintNode(canvas, n, cx, cy, maxR, totalRings);
      if (n.children.isNotEmpty) {
        _paintNodes(canvas, n.children, cx, cy, maxR, totalRings);
      }
    }
  }

  void _paintNode(
    Canvas canvas,
    SunburstNode node,
    double cx,
    double cy,
    double maxR,
    int totalRings,
  ) {
    final depth = node.depth + 1;
    final ringW = maxR * (1 - innerFraction) / totalRings;
    final inner = innerFraction * maxR + (depth - 1) * ringW;
    final outer = inner + ringW - 1.5; // 1.5px gap between rings

    final sweep = node.sweepAngle * progress;
    if (sweep < 0.005) return;

    final isHovered = node == hovered;
    final push = isHovered ? 5.0 : 0.0;

    // ── resolve colour ──
    Color base;
    if (node.color != null) {
      base = colorCache.resolve(node.color!);
    } else {
      // Find root ancestor to pick palette colour
      SunburstNode root = node;
      while (root.parent != null) {
        root = root.parent!;
      }
      final rootIdx = nodes.indexOf(root).clamp(0, 100);
      base = theme.palette.colorObjectAt(rootIdx);
      // Progressively darken for deeper rings
      final factor = 1.0 - node.depth * 0.12;
      base = Color.fromARGB(
        (base.a * 255.0).round().clamp(0, 255),
        (base.r * 255.0 * factor).round().clamp(0, 255),
        (base.g * 255.0 * factor).round().clamp(0, 255),
        (base.b * 255.0 * factor).round().clamp(0, 255),
      );
    }

    final fillPt = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = isHovered ? Color.lerp(base, Colors.white, 0.2)! : base;

    // ── build arc path ──
    final path = Path();
    path.addArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: outer + push),
      node.startAngle,
      sweep,
    );
    // line to inner arc start
    path.lineTo(
      cx + inner * math.cos(node.startAngle + sweep),
      cy + inner * math.sin(node.startAngle + sweep),
    );
    path.addArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: inner),
      node.startAngle + sweep,
      -sweep,
    );
    path.close();

    canvas.drawPath(path, fillPt);
    canvas.drawPath(
      path,
      paintCache.stroke(Colors.white.withValues(alpha: 0.55), 0.9),
    );

    // ── label ──
    if (showLabels && sweep > 0.18) {
      final midAngle = node.startAngle + sweep / 2;
      final midR = (inner + outer + push) / 2;
      final lx = cx + midR * math.cos(midAngle);
      final ly = cy + midR * math.sin(midAngle);
      final text = showValues
          ? '${node.name}\n${node.total.toStringAsFixed(0)}'
          : node.name;
      final tp = textPainterCache.get(
        text,
        theme.typography.axisLabelStyle.copyWith(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: ringW * 1.8,
        align: TextAlign.center,
      );
      canvas.save();
      canvas.translate(lx, ly);
      double rot = midAngle + math.pi / 2;
      if (rot > math.pi / 2 && rot < 3 * math.pi / 2) rot += math.pi;
      canvas.rotate(rot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}

// ─────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────

class _Tooltip extends StatelessWidget {
  final SunburstNode node;
  final Offset pos;
  final Size size;
  final ChartTheme theme;
  const _Tooltip({
    required this.node,
    required this.pos,
    required this.size,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    double x = (pos.dx + 14).clamp(0, size.width - 170.0);
    double y = (pos.dy - 55).clamp(0, size.height - 80.0);
    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: theme.tooltipBackgroundColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: DefaultTextStyle(
            style: theme.typography.tooltipStyle.copyWith(
              color: theme.tooltipTextColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  node.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Value: ${node.total.toStringAsFixed(1)}'),
                if (node.parent != null)
                  Text(
                    '${(node.total / node.parent!.total * 100).toStringAsFixed(1)}% of ${node.parent!.name}',
                    style: TextStyle(
                      color: theme.tooltipTextColor.withValues(alpha: 0.65),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.arrow_back_ios_new, size: 11, color: Colors.white),
          SizedBox(width: 4),
          Text('Back', style: TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    ),
  );
}
