// Sankey diagram — directional flow chart with proportional link widths.
//
// Nodes are laid out in columns by level; links curve between them.
// Hover a node or link for its value. Supports drag-to-rearrange nodes.
//
// JSON:
// ```json
// {
//   "type": "sankey",
//   "series": [{
//     "nodes": [
//       { "id": "visits",    "name": "Visits",    "column": 0 },
//       { "id": "organic",   "name": "Organic",   "column": 0 },
//       { "id": "product",   "name": "Product",   "column": 1 },
//       { "id": "checkout",  "name": "Checkout",  "column": 2 },
//       { "id": "purchase",  "name": "Purchase",  "column": 2 }
//     ],
//     "links": [
//       { "source": "visits",   "target": "product",  "value": 5000 },
//       { "source": "organic",  "target": "product",  "value": 3000 },
//       { "source": "product",  "target": "checkout", "value": 4200 },
//       { "source": "product",  "target": "purchase", "value": 1200 },
//       { "source": "checkout", "target": "purchase", "value": 3800 }
//     ]
//   }]
// }
// ```

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/chart_series_json.dart';
import 'package:tenun_core/core/json_value.dart';

// ─────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────

class SankeyNode {
  final String id;
  final String name;
  final int column; // explicit column, or -1 to auto-assign
  final String? color;

  // ── layout fields ──
  double x = 0, y = 0, width = 0, height = 0;
  double inFlow = 0, outFlow = 0;
  double _inCursor = 0, _outCursor = 0;

  SankeyNode({
    required this.id,
    required this.name,
    this.column = -1,
    this.color,
  });

  factory SankeyNode.fromJson(Map<String, dynamic> j) => SankeyNode(
    id: j['id']?.toString() ?? j['name']?.toString() ?? '',
    name: j['name']?.toString() ?? j['id']?.toString() ?? '',
    column: JsonValue.intOrNull(j['column']) ?? -1,
    color: j['color']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (column >= 0) 'column': column,
    if (color != null) 'color': color,
  };
}

class SankeyLink {
  final String sourceId;
  final String targetId;
  final double value;
  final String? color;

  SankeyLink({
    required this.sourceId,
    required this.targetId,
    required this.value,
    this.color,
  });

  factory SankeyLink.fromJson(Map<String, dynamic> j) => SankeyLink(
    sourceId: j['source']?.toString() ?? '',
    targetId: j['target']?.toString() ?? '',
    value: JsonValue.doubleOrNull(j['value']) ?? 0,
    color: j['color']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'source': sourceId,
    'target': targetId,
    'value': value,
    if (color != null) 'color': color,
  };
}

// ─────────────────────────────────────────────────────────
// Layout engine
// ─────────────────────────────────────────────────────────

class _SankeyLayout {
  static const double nodeWidth = 18;
  static const double nodePad = 12;

  void run(
    List<SankeyNode> nodes,
    List<SankeyLink> links,
    Size size, {
    double padL = 12,
    double padR = 12,
    double padT = 16,
    double padV = 24,
  }) {
    final nodeById = {for (final n in nodes) n.id: n};

    // ── assign columns via auto-BFS if not specified ──
    final cols = <String, int>{};
    for (final n in nodes) {
      if (n.column >= 0) cols[n.id] = n.column;
    }
    if (cols.isEmpty) {
      // BFS from sources (nodes with no incoming links)
      final inIds = links.map((l) => l.targetId).toSet();
      final queue = <String>[];
      for (final n in nodes) {
        if (!inIds.contains(n.id)) {
          cols[n.id] = 0;
          queue.add(n.id);
        }
      }
      while (queue.isNotEmpty) {
        final id = queue.removeAt(0);
        for (final l in links.where((l) => l.sourceId == id)) {
          final tCol = (cols[id] ?? 0) + 1;
          if (!cols.containsKey(l.targetId) || cols[l.targetId]! < tCol) {
            cols[l.targetId] = tCol;
            queue.add(l.targetId);
          }
        }
      }
    }
    for (final n in nodes) {
      n.x = (cols[n.id] ?? 0).toDouble();
    }

    // ── accumulate flows ──
    for (final n in nodes) {
      n.inFlow = 0;
      n.outFlow = 0;
    }
    for (final l in links) {
      nodeById[l.sourceId]?.outFlow += l.value;
      nodeById[l.targetId]?.inFlow += l.value;
    }
    for (final n in nodes) {
      if (n.inFlow == 0) n.inFlow = n.outFlow;
      if (n.outFlow == 0) n.outFlow = n.inFlow;
    }

    // ── column X positions ──
    final maxCol = cols.values.fold(0, math.max);
    final numCols = maxCol + 1;
    final colW =
        (size.width - padL - padR - nodeWidth) / math.max(1, numCols - 1);

    // ── node heights proportional to flow ──
    final byCol = <int, List<SankeyNode>>{};
    for (final n in nodes) {
      final c = (n.x).round();
      byCol.putIfAbsent(c, () => []).add(n);
    }

    final chartH = size.height - padT - padV;
    for (final entry in byCol.entries) {
      final colNodes = entry.value;
      final total = colNodes.fold(
        0.0,
        (s, n) => s + math.max(n.inFlow, n.outFlow),
      );
      final usable = chartH - nodePad * (colNodes.length - 1);
      double cursor = padT;
      for (final n in colNodes) {
        final flow = math.max(n.inFlow, n.outFlow);
        n.width = nodeWidth.toDouble();
        n.height = total > 0 ? (flow / total * usable).clamp(8.0, chartH) : 8.0;
        n.x = padL + entry.key * colW;
        n.y = cursor;
        n._inCursor = cursor;
        n._outCursor = cursor;
        cursor += n.height + nodePad;
      }
    }
  }
}

// ─────────────────────────────────────────────────────────
// Resolved link (with canvas coordinates)
// ─────────────────────────────────────────────────────────

class _ResolvedLink {
  final SankeyLink link;
  final SankeyNode source;
  final SankeyNode target;
  double sy1 = 0, sy2 = 0; // y range on source right edge
  double ty1 = 0, ty2 = 0; // y range on target left edge

  _ResolvedLink({
    required this.link,
    required this.source,
    required this.target,
  });
}

List<_ResolvedLink> _resolveLinks(
  List<SankeyNode> nodes,
  List<SankeyLink> links,
) {
  final nodeById = {for (final n in nodes) n.id: n};
  final result = <_ResolvedLink>[];

  // Reset cursors
  for (final n in nodes) {
    n._inCursor = n.y;
    n._outCursor = n.y;
  }

  for (final l in links) {
    final src = nodeById[l.sourceId];
    final tgt = nodeById[l.targetId];
    if (src == null || tgt == null) continue;

    final srcFrac = l.value / math.max(src.outFlow, 1);
    final tgtFrac = l.value / math.max(tgt.inFlow, 1);

    final rLink = _ResolvedLink(link: l, source: src, target: tgt);
    rLink.sy1 = src._outCursor;
    rLink.sy2 = src._outCursor + src.height * srcFrac;
    rLink.ty1 = tgt._inCursor;
    rLink.ty2 = tgt._inCursor + tgt.height * tgtFrac;

    src._outCursor = rLink.sy2;
    tgt._inCursor = rLink.ty2;
    result.add(rLink);
  }
  return result;
}

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

class SankeyChartConfig extends BaseChartConfig {
  final List<SankeyNode> nodes;
  final List<SankeyLink> links;
  final bool showLabels;
  final bool showValues;

  SankeyChartConfig({
    required this.nodes,
    required this.links,
    super.theme = ChartTheme.light,
    this.showLabels = true,
    this.showValues = false,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.sankey, series: const []);

  @override
  Widget buildChart() => SankeyChartWidget(config: this);

  factory SankeyChartConfig.fromJson(Map<String, dynamic> json) {
    final series = ChartSeriesJson.firstSeries(json['series']);

    final nodes = ChartSeriesJson.mapList(
      series['nodes'],
    ).map(SankeyNode.fromJson).toList();
    final links = ChartSeriesJson.mapList(
      series['links'],
    ).map(SankeyLink.fromJson).toList();

    return SankeyChartConfig(
      nodes: nodes,
      links: links,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? true,
      showValues: JsonValue.boolOrNull(json['showValues']) ?? false,
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
      {
        'nodes': nodes.map((node) => node.toJson()).toList(),
        'links': links.map((link) => link.toJson()).toList(),
      },
    ],
    'showLabels': showLabels,
    'showValues': showValues,
  };
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

class SankeyChartWidget extends StatefulWidget {
  final SankeyChartConfig config;
  const SankeyChartWidget({super.key, required this.config});

  @override
  State<SankeyChartWidget> createState() => _SankeyState();
}

class _SankeyState extends State<SankeyChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  SankeyNode? _hovNode;
  _ResolvedLink? _hovLink;
  Offset _hoverPos = Offset.zero;
  late String _dataSignature;

  List<_ResolvedLink> _resolved = [];
  Size _lastSize = Size.zero;

  SankeyChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(SankeyChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _resolved = [];
      _lastSize = Size.zero;
      _hovNode = null;
      _hovLink = null;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _doLayout(Size sz) {
    if (sz == _lastSize) return;
    _lastSize = sz;
    _SankeyLayout().run(cfg.nodes, cfg.links, sz);
    _resolved = _resolveLinks(cfg.nodes, cfg.links);
  }

  void _onHover(Offset pos, Size sz) {
    SankeyNode? node;
    for (final n in cfg.nodes) {
      if (pos.dx >= n.x &&
          pos.dx <= n.x + n.width &&
          pos.dy >= n.y &&
          pos.dy <= n.y + n.height) {
        node = n;
        break;
      }
    }
    setState(() {
      _hovNode = node;
      _hovLink = null;
      _hoverPos = pos;
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
              _doLayout(sz);
              return Stack(
                children: [
                  MouseRegion(
                    onHover: (e) => _onHover(e.localPosition, sz),
                    onExit: (_) => setState(() {
                      _hovNode = null;
                      _hovLink = null;
                    }),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _SankeyPainter(
                          config: cfg,
                          resolved: _resolved,
                          progress: _anim.value,
                          hovNode: _hovNode,
                          hovLink: _hovLink,
                          dataSignature: _dataSignature,
                        ),
                      ),
                    ),
                  ),
                  if (_hovNode != null) _buildNodeTooltip(sz),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNodeTooltip(Size sz) {
    final n = _hovNode!;
    double x = (_hoverPos.dx + 14).clamp(0, sz.width - 180.0);
    double y = (_hoverPos.dy - 55).clamp(0, sz.height - 100.0);
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
                  n.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('In:  ${n.inFlow.toStringAsFixed(0)}'),
                Text('Out: ${n.outFlow.toStringAsFixed(0)}'),
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

class _SankeyPainter extends ChartPainterBase {
  final SankeyChartConfig config;
  final List<_ResolvedLink> resolved;
  final double progress;
  final SankeyNode? hovNode;
  final _ResolvedLink? hovLink;
  final String dataSignature;

  _SankeyPainter({
    required this.config,
    required this.resolved,
    required this.progress,
    required this.dataSignature,
    this.hovNode,
    this.hovLink,
  }) : super(theme: config.theme);

  @override
  bool shouldRepaintChart(covariant _SankeyPainter old) =>
      old.progress != progress ||
      old.hovNode != hovNode ||
      old.hovLink != hovLink ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    // ── Draw links ──
    for (int i = 0; i < resolved.length; i++) {
      _drawLink(canvas, resolved[i], i);
    }
    // ── Draw nodes ──
    for (int i = 0; i < config.nodes.length; i++) {
      _drawNode(canvas, config.nodes[i], i);
    }
  }

  void _drawLink(Canvas canvas, _ResolvedLink r, int idx) {
    final isHov = r == hovLink;
    final srcColor = _nodeColor(config.nodes.indexOf(r.source));
    final tgtColor = _nodeColor(config.nodes.indexOf(r.target));

    final sx = r.source.x + r.source.width;
    final tx = r.target.x;

    // Animate link width
    final sy1 = r.sy1 + (r.sy2 - r.sy1) * (1 - progress) / 2;
    final sy2 = r.sy2 - (r.sy2 - r.sy1) * (1 - progress) / 2;
    final ty1 = r.ty1 + (r.ty2 - r.ty1) * (1 - progress) / 2;
    final ty2 = r.ty2 - (r.ty2 - r.ty1) * (1 - progress) / 2;

    final cp = (tx - sx) * 0.45;
    final path = Path()
      ..moveTo(sx, sy1)
      ..cubicTo(sx + cp, sy1, tx - cp, ty1, tx, ty1)
      ..lineTo(tx, ty2)
      ..cubicTo(tx - cp, ty2, sx + cp, sy2, sx, sy2)
      ..close();

    final gradient =
        LinearGradient(
          colors: [
            srcColor.withValues(alpha: isHov ? 0.7 : 0.35),
            tgtColor.withValues(alpha: isHov ? 0.7 : 0.35),
          ],
        ).createShader(
          Rect.fromLTRB(sx, math.min(sy1, sy2), tx, math.max(ty1, ty2)),
        );

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  void _drawNode(Canvas canvas, SankeyNode node, int idx) {
    final color = _nodeColor(idx);
    final isHov = node == hovNode;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(node.x, node.y, node.width, node.height * progress),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = isHov ? Color.lerp(color, Colors.white, 0.25)! : color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    if (config.showLabels) {
      final tp = textPainterCache.get(
        node.name,
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 10,
        ),
      );
      final labelX = node.x + node.width + 5;
      final labelY = node.y + node.height / 2 - tp.height / 2;
      tp.paint(canvas, Offset(labelX, labelY));
    }
  }

  Color _nodeColor(int idx) {
    final n = config.nodes[idx >= 0 ? idx : 0];
    return theme.seriesColor(idx, explicitColor: n.color);
  }
}
