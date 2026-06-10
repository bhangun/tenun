/// Four remaining chart types:
///   1. `NetworkChartConfig`   — node-link force-directed graph
///   2. `RadialChartConfig`    — radial bar / progress rings (multi-ring KPI)
///   3. `TimelineChartConfig`  — vertical event timeline
///   4. `WordcloudChartConfig` — proportional word cloud
library;

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
import '../../core/chart_data_signature.dart';
import '../../core/chart_series_json.dart';
import '../../core/json_value.dart';

// ═══════════════════════════════════════════════════════════
// 1. NETWORK CHART (force-directed)
// ═══════════════════════════════════════════════════════════

/// JSON:
/// ```json
/// { "type": "network",
///   "series": [{
///     "nodes": [
///       {"id":"A","name":"Server","size":20},
///       {"id":"B","name":"DB","size":15},
///       {"id":"C","name":"Cache","size":12}
///     ],
///     "links": [
///       {"source":"A","target":"B","value":5},
///       {"source":"A","target":"C","value":3}
///     ]
///   }]}
/// ```
class NetworkNode {
  final String id, name;
  final double size;
  final String? color;
  final String? group;
  // physics
  double x = 0, y = 0, vx = 0, vy = 0;

  NetworkNode({
    required this.id,
    required this.name,
    this.size = 12,
    this.color,
    this.group,
  });

  factory NetworkNode.fromJson(Map<String, dynamic> j) => NetworkNode(
    id: j['id']?.toString() ?? j['name']?.toString() ?? '',
    name: j['name']?.toString() ?? j['id']?.toString() ?? '',
    size: JsonValue.doubleOrNull(j['size']) ?? 12,
    color: j['color']?.toString(),
    group: j['group']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'size': size,
    if (color != null) 'color': color,
    if (group != null) 'group': group,
  };
}

class NetworkLink {
  final String sourceId, targetId;
  final double value;
  const NetworkLink({
    required this.sourceId,
    required this.targetId,
    this.value = 1,
  });
  factory NetworkLink.fromJson(Map<String, dynamic> j) => NetworkLink(
    sourceId: j['source']?.toString() ?? '',
    targetId: j['target']?.toString() ?? '',
    value: JsonValue.doubleOrNull(j['value']) ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'source': sourceId,
    'target': targetId,
    'value': value,
  };
}

class NetworkChartConfig extends BaseChartConfig {
  final List<NetworkNode> nodes;
  final List<NetworkLink> links;
  final bool showLabels;
  final int iterations; // force layout iterations
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  NetworkChartConfig({
    required this.nodes,
    required this.links,
    this.theme = ChartTheme.light,
    this.showLabels = true,
    this.iterations = 120,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.network, series: const []);

  @override
  Widget buildChart() => NetworkChartWidget(config: this);

  factory NetworkChartConfig.fromJson(Map<String, dynamic> json) {
    final s = ChartSeriesJson.firstSeries(json['series']);
    final nodes = ChartSeriesJson.mapList(
      s['nodes'],
    ).map(NetworkNode.fromJson).toList();
    final links = ChartSeriesJson.mapList(
      s['links'],
    ).map(NetworkLink.fromJson).toList();
    return NetworkChartConfig(
      nodes: nodes,
      links: links,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? true,
      iterations: JsonValue.intOrNull(json['iterations']) ?? 120,
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
    'iterations': iterations,
  };
}

class NetworkChartWidget extends StatefulWidget {
  final NetworkChartConfig config;
  const NetworkChartWidget({super.key, required this.config});
  @override
  State<NetworkChartWidget> createState() => _NetworkState();
}

class _NetworkState extends State<NetworkChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _settled = false;
  Size _lastSize = Size.zero;
  NetworkNode? _dragging;
  Offset _dragOffset = Offset.zero;
  NetworkNode? _hovered;
  Offset _hoverPos = Offset.zero;
  late String _dataSignature;
  int _layoutRevision = 0;

  NetworkChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 50),
          )
          ..addListener(_tick)
          ..repeat();
  }

  @override
  void didUpdateWidget(covariant NetworkChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature == _dataSignature) return;
    _dataSignature = nextSignature;
    _settled = false;
    _step = 0;
    _lastSize = Size.zero;
    _layoutRevision++;
    if (!_ctrl.isAnimating) _ctrl.repeat();
  }

  void _initPositions(Size sz) {
    if (_lastSize == sz) return;
    _lastSize = sz;
    final rng = math.Random(1);
    for (final n in cfg.nodes) {
      n.x = sz.width * 0.2 + rng.nextDouble() * sz.width * 0.6;
      n.y = sz.height * 0.2 + rng.nextDouble() * sz.height * 0.6;
      n.vx = 0;
      n.vy = 0;
    }
    _layoutRevision++;
  }

  int _step = 0;
  void _tick() {
    if (_settled || cfg.nodes.isEmpty) return;
    final nodeById = {for (final n in cfg.nodes) n.id: n};
    const repulsion = 3000.0,
        attraction = 0.05,
        damping = 0.85,
        targetDist = 120.0;

    for (int i = 0; i < cfg.nodes.length; i++) {
      final a = cfg.nodes[i];
      double fx = 0, fy = 0;
      // Repulsion
      for (int j = 0; j < cfg.nodes.length; j++) {
        if (i == j) continue;
        final b = cfg.nodes[j];
        final dx = a.x - b.x, dy = a.y - b.y;
        final d2 = dx * dx + dy * dy + 1;
        final f = repulsion / d2;
        fx += dx / math.sqrt(d2) * f;
        fy += dy / math.sqrt(d2) * f;
      }
      // Attraction (spring)
      for (final l in cfg.links) {
        NetworkNode? other;
        if (l.sourceId == a.id) {
          other = nodeById[l.targetId];
        } else if (l.targetId == a.id) {
          other = nodeById[l.sourceId];
        }
        if (other == null) continue;
        final dx = other.x - a.x, dy = other.y - a.y;
        final d = math.sqrt(dx * dx + dy * dy).clamp(0.1, 1e9);
        final f = (d - targetDist) * attraction;
        fx += dx / d * f;
        fy += dy / d * f;
      }
      // Centre gravity
      if (_lastSize != Size.zero) {
        fx += (_lastSize.width / 2 - a.x) * 0.005;
        fy += (_lastSize.height / 2 - a.y) * 0.005;
      }
      if (a != _dragging) {
        a.vx = (a.vx + fx) * damping;
        a.vy = (a.vy + fy) * damping;
        a.x += a.vx;
        a.y += a.vy;
      }
    }
    _step++;
    if (_step > cfg.iterations) {
      _settled = true;
      _ctrl.stop();
    }
    _layoutRevision++;
    setState(() {});
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
              _initPositions(Size(con.maxWidth, con.maxHeight));
              return Stack(
                children: [
                  MouseRegion(
                    onHover: (e) {
                      for (final n in cfg.nodes) {
                        final dx = e.localPosition.dx - n.x,
                            dy = e.localPosition.dy - n.y;
                        if (dx * dx + dy * dy <= (n.size + 4) * (n.size + 4)) {
                          setState(() {
                            _hovered = n;
                            _hoverPos = e.localPosition;
                          });
                          return;
                        }
                      }
                      setState(() => _hovered = null);
                    },
                    onExit: (_) => setState(() => _hovered = null),
                    child: GestureDetector(
                      onPanStart: (d) {
                        for (final n in cfg.nodes) {
                          final dx = d.localPosition.dx - n.x,
                              dy = d.localPosition.dy - n.y;
                          if (dx * dx + dy * dy <=
                              (n.size + 8) * (n.size + 8)) {
                            _dragging = n;
                            _dragOffset = Offset(
                              n.x - d.localPosition.dx,
                              n.y - d.localPosition.dy,
                            );
                            break;
                          }
                        }
                      },
                      onPanUpdate: (d) {
                        if (_dragging != null) {
                          setState(() {
                            _dragging!.x = d.localPosition.dx + _dragOffset.dx;
                            _dragging!.y = d.localPosition.dy + _dragOffset.dy;
                            _dragging!.vx = 0;
                            _dragging!.vy = 0;
                            _layoutRevision++;
                          });
                        }
                      },
                      onPanEnd: (_) {
                        _dragging = null;
                        _settled = false;
                        _step = 0;
                        if (!_ctrl.isAnimating) _ctrl.repeat();
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _NetworkPainter(
                            config: cfg,
                            hovered: _hovered,
                            dataSignature: _dataSignature,
                            layoutRevision: _layoutRevision,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_hovered != null)
                    _buildTooltip(Size(con.maxWidth, con.maxHeight)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTooltip(Size sz) {
    final n = _hovered!;
    final inDeg = cfg.links.where((l) => l.targetId == n.id).length;
    final outDeg = cfg.links.where((l) => l.sourceId == n.id).length;
    double x = (_hoverPos.dx + 14).clamp(0, sz.width - 170.0);
    double y = (_hoverPos.dy - 55).clamp(0, sz.height - 80.0);
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
                if (n.group != null) Text('Group: ${n.group}'),
                Text('In: $inDeg  Out: $outDeg'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkPainter extends ChartPainterBase {
  final NetworkChartConfig config;
  final NetworkNode? hovered;
  final String dataSignature;
  final int layoutRevision;
  _NetworkPainter({
    required this.config,
    required this.dataSignature,
    required this.layoutRevision,
    this.hovered,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _NetworkPainter old) =>
      old.dataSignature != dataSignature ||
      old.layoutRevision != layoutRevision ||
      old.hovered?.id != hovered?.id;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeById = {for (final n in config.nodes) n.id: n};
    final groupColors = <String, int>{};
    int groupIdx = 0;

    // Links
    for (final l in config.links) {
      final src = nodeById[l.sourceId], tgt = nodeById[l.targetId];
      if (src == null || tgt == null) continue;
      final isHov = src == hovered || tgt == hovered;
      canvas.drawLine(
        Offset(src.x, src.y),
        Offset(tgt.x, tgt.y),
        paintCache.stroke(
          theme.gridColor.withValues(alpha: isHov ? 2.5 : 1),
          isHov ? 2 : 1,
        ),
      );
    }

    // Nodes
    for (final n in config.nodes) {
      final gi = n.group != null
          ? (groupColors.putIfAbsent(n.group!, () => groupIdx++) % 100)
          : config.nodes.indexOf(n);
      final color = theme.seriesColor(gi, explicitColor: n.color);
      final isHov = n == hovered;
      final r = isHov ? n.size + 3 : n.size;
      canvas.drawCircle(
        Offset(n.x, n.y),
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        Offset(n.x, n.y),
        r,
        paintCache.stroke(Colors.white.withValues(alpha: 0.7), 1.5),
      );

      if (config.showLabels) {
        final tp = textPainterCache.get(
          n.name,
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 9.5,
          ),
        );
        tp.paint(canvas, Offset(n.x - tp.width / 2, n.y + r + 3));
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 2. RADIAL PROGRESS RINGS
// ═══════════════════════════════════════════════════════════

/// Concentric arc rings — one ring per metric, like Apple Watch activity rings.
/// JSON:
/// ```json
/// { "type": "radial",
///   "series": [{ "data": [
///     { "label": "Revenue",  "value": 78, "max": 100 },
///     { "label": "Users",    "value": 55, "max": 100 },
///     { "label": "NPS",      "value": 42, "max": 100 }
///   ]}]}
/// ```
class RadialRingItem {
  final String label;
  final double value, max;
  final String? color;
  const RadialRingItem({
    required this.label,
    required this.value,
    required this.max,
    this.color,
  });
  factory RadialRingItem.fromJson(Map<String, dynamic> j) => RadialRingItem(
    label: j['label']?.toString() ?? '',
    value: JsonValue.doubleOrNull(j['value']) ?? 0,
    max: JsonValue.doubleOrNull(j['max']) ?? 100,
    color: j['color']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'max': max,
    if (color != null) 'color': color,
  };
}

class RadialChartConfig extends BaseChartConfig {
  final List<RadialRingItem> rings;
  final bool showLabels;
  final double startAngleDeg;
  final double trackOpacity;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  RadialChartConfig({
    required this.rings,
    this.theme = ChartTheme.light,
    this.showLabels = true,
    this.startAngleDeg = -90,
    this.trackOpacity = 0.15,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.radial, series: const []);

  @override
  Widget buildChart() => RadialChartWidget(config: this);

  factory RadialChartConfig.fromJson(Map<String, dynamic> json) {
    final rings = ChartSeriesJson.firstSeriesData(
      json['series'],
    ).map(RadialRingItem.fromJson).toList();
    return RadialChartConfig(
      rings: rings,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? true,
      startAngleDeg: JsonValue.doubleOrNull(json['startAngle']) ?? -90,
      trackOpacity: JsonValue.doubleOrNull(json['trackOpacity']) ?? 0.15,
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
      {'data': rings.map((ring) => ring.toJson()).toList()},
    ],
    'showLabels': showLabels,
    'startAngle': startAngleDeg,
    'trackOpacity': trackOpacity,
  };
}

class RadialChartWidget extends StatefulWidget {
  final RadialChartConfig config;
  const RadialChartWidget({super.key, required this.config});
  @override
  State<RadialChartWidget> createState() => _RadialState();
}

class _RadialState extends State<RadialChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  RadialChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant RadialChartWidget oldWidget) {
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
            painter: _RadialPainter(
              config: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
    ],
  );
}

class _RadialPainter extends ChartPainterBase {
  final RadialChartConfig config;
  final double progress;
  final String dataSignature;
  _RadialPainter({
    required this.config,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _RadialPainter old) =>
      old.progress != progress || old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = config.rings.length;
    if (n == 0) return;
    final cx = size.width / 2, cy = size.height / 2;
    final maxR = math.min(cx, cy) * 0.88;
    final trackW = maxR / n * 0.65;
    final gap = maxR / n * 0.35;
    final startRad = config.startAngleDeg * math.pi / 180;

    for (int i = 0; i < n; i++) {
      final ring = config.rings[i];
      final r = maxR - i * (trackW + gap) - trackW / 2;
      if (r < 4) continue;
      final color = theme.seriesColor(i, explicitColor: ring.color);
      final pct = (ring.value / ring.max).clamp(0.0, 1.0);

      // Track
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = trackW
          ..color = color.withValues(alpha: config.trackOpacity)
          ..isAntiAlias = true,
      );

      // Arc
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startRad,
        math.pi * 2 * pct * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = trackW
          ..strokeCap = StrokeCap.round
          ..color = color
          ..isAntiAlias = true,
      );

      // Label
      if (config.showLabels) {
        final endAngle = startRad + math.pi * 2 * pct * progress;
        final lx = cx + (r + trackW / 2 + 6) * math.cos(endAngle);
        final ly = cy + (r + trackW / 2 + 6) * math.sin(endAngle);
        final pctStr = '${(pct * 100).toStringAsFixed(0)}%';
        final tp = textPainterCache.get(
          pctStr,
          theme.typography.axisLabelStyle.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        );
        tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));

        // Inner label at start
        final lx2 = cx + (r - trackW / 2 - 2) * math.cos(startRad - 0.08);
        final ly2 = cy + (r - trackW / 2 - 2) * math.sin(startRad - 0.08);
        final tp2 = textPainterCache.get(
          ring.label,
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 9,
          ),
        );
        tp2.paint(canvas, Offset(lx2 - tp2.width / 2, ly2 - tp2.height / 2));
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 3. TIMELINE (vertical event list)
// ═══════════════════════════════════════════════════════════

/// Vertical timeline with labeled events, icons, and connecting line.
/// JSON:
/// ```json
/// { "type": "timeline",
///   "series": [{ "data": [
///     { "date":"2020-Q1","label":"Company Founded","detail":"Series Seed raised","icon":"🚀"},
///     { "date":"2021-Q3","label":"Product Launch", "detail":"1,000 users"},
///     { "date":"2023-Q1","label":"Series A",       "detail":"$5M raised","color":"#4CAF50"}
///   ]}]}
/// ```
class TimelineEvent {
  final String date, label;
  final String? detail, icon, color;
  const TimelineEvent({
    required this.date,
    required this.label,
    this.detail,
    this.icon,
    this.color,
  });
  factory TimelineEvent.fromJson(Map<String, dynamic> j) => TimelineEvent(
    date: j['date']?.toString() ?? '',
    label: j['label']?.toString() ?? '',
    detail: j['detail']?.toString(),
    icon: j['icon']?.toString(),
    color: j['color']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'date': date,
    'label': label,
    if (detail != null) 'detail': detail,
    if (icon != null) 'icon': icon,
    if (color != null) 'color': color,
  };
}

class TimelineChartConfig extends BaseChartConfig {
  final List<TimelineEvent> events;
  final bool alternating; // alternate left/right
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  TimelineChartConfig({
    required this.events,
    this.theme = ChartTheme.light,
    this.alternating = false,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.timeline, series: const []);

  @override
  Widget buildChart() => TimelineChartWidget(config: this);

  factory TimelineChartConfig.fromJson(Map<String, dynamic> json) {
    final events = ChartSeriesJson.firstSeriesData(
      json['series'],
    ).map(TimelineEvent.fromJson).toList();
    return TimelineChartConfig(
      events: events,
      alternating: JsonValue.boolOrNull(json['alternating']) ?? false,
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
      {'data': events.map((event) => event.toJson()).toList()},
    ],
    'alternating': alternating,
  };
}

class TimelineChartWidget extends StatefulWidget {
  final TimelineChartConfig config;
  const TimelineChartWidget({super.key, required this.config});
  @override
  State<TimelineChartWidget> createState() => _TimelineState();
}

class _TimelineState extends State<TimelineChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  TimelineChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant TimelineChartWidget oldWidget) {
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
          child: SingleChildScrollView(
            child: CustomPaint(
              size: Size(
                double.infinity,
                math.max(cfg.events.length * 72.0 + 24, 200),
              ),
              painter: _TimelinePainter(
                config: cfg,
                progress: _anim.value,
                dataSignature: _dataSignature,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelinePainter extends ChartPainterBase {
  final TimelineChartConfig config;
  final double progress;
  final String dataSignature;
  _TimelinePainter({
    required this.config,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _TimelinePainter old) =>
      old.progress != progress || old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = config.events.length;
    if (n == 0) return;
    const lineX = 80.0, dotR = 7.0, rowH = 72.0, padT = 16.0;
    final visible = (n * progress).ceil();

    // Vertical line
    canvas.drawLine(
      Offset(lineX, padT),
      Offset(lineX, padT + visible * rowH - rowH / 2),
      paintCache.stroke(theme.gridColor.withValues(alpha: 2), 2),
    );

    for (int i = 0; i < visible; i++) {
      final e = config.events[i];
      final cy = padT + i * rowH + rowH / 2;
      final color = e.color != null
          ? colorCache.resolve(e.color!)
          : theme.palette.colorObjectAt(i);

      // Dot
      canvas.drawCircle(
        Offset(lineX, cy),
        dotR,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        Offset(lineX, cy),
        dotR,
        paintCache.stroke(Colors.white, 2),
      );

      // Date label (left of line)
      final dateTp = textPainterCache.get(
        e.date,
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
        maxWidth: lineX - dotR - 8,
        align: TextAlign.right,
      );
      dateTp.paint(
        canvas,
        Offset(lineX - dotR - dateTp.width - 4, cy - dateTp.height / 2),
      );

      // Label + detail (right of line)
      final labelTp = textPainterCache.get(
        e.label,
        theme.typography.axisLabelStyle.copyWith(
          color: theme.titleColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: size.width - lineX - dotR - 20,
      );
      labelTp.paint(
        canvas,
        Offset(
          lineX + dotR + 8,
          cy - (e.detail != null ? labelTp.height : labelTp.height / 2),
        ),
      );

      if (e.detail != null) {
        final detailTp = textPainterCache.get(
          e.detail!,
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 10,
          ),
          maxWidth: size.width - lineX - dotR - 20,
        );
        detailTp.paint(canvas, Offset(lineX + dotR + 8, cy + 2));
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 4. WORD CLOUD
// ═══════════════════════════════════════════════════════════

/// Proportional word layout — larger words have higher frequency/weight.
/// Uses a spiral placement algorithm to pack words without overlap.
/// JSON:
/// ```json
/// { "type": "wordcloud",
///   "series": [{ "data": [
///     { "text": "Flutter",  "weight": 95 },
///     { "text": "Dart",     "weight": 80 },
///     { "text": "Charts",   "weight": 70 },
///     { "text": "Mobile",   "weight": 55 }
///   ]}]}
/// ```
class WordItem {
  final String text;
  final double weight;
  final String? color;
  const WordItem({required this.text, required this.weight, this.color});
  factory WordItem.fromJson(Map<String, dynamic> j) => WordItem(
    text: j['text']?.toString() ?? '',
    weight: JsonValue.doubleOrNull(j['weight']) ?? 1,
    color: j['color']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'weight': weight,
    if (color != null) 'color': color,
  };
}

class WordcloudChartConfig extends BaseChartConfig {
  final List<WordItem> words;
  final double minFontSize, maxFontSize;
  final int layoutSeed;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  WordcloudChartConfig({
    required this.words,
    this.theme = ChartTheme.light,
    this.minFontSize = 10,
    this.maxFontSize = 52,
    this.layoutSeed = 0,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.wordcloud, series: const []);

  @override
  Widget buildChart() => WordcloudChartWidget(config: this);

  factory WordcloudChartConfig.fromJson(Map<String, dynamic> json) {
    final words = ChartSeriesJson.firstSeriesData(
      json['series'],
    ).map(WordItem.fromJson).toList();
    return WordcloudChartConfig(
      words: words,
      minFontSize: JsonValue.doubleOrNull(json['minFontSize']) ?? 10,
      maxFontSize: JsonValue.doubleOrNull(json['maxFontSize']) ?? 52,
      layoutSeed: JsonValue.intOrNull(json['layoutSeed']) ?? 0,
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
      {'data': words.map((word) => word.toJson()).toList()},
    ],
    'minFontSize': minFontSize,
    'maxFontSize': maxFontSize,
    'layoutSeed': layoutSeed,
  };
}

class WordcloudChartWidget extends StatefulWidget {
  final WordcloudChartConfig config;
  const WordcloudChartWidget({super.key, required this.config});
  @override
  State<WordcloudChartWidget> createState() => _WordcloudState();
}

class _WordcloudState extends State<WordcloudChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  Size _lastSize = Size.zero;
  List<_PlacedWord> _placed = [];
  late String _layoutSignature;
  WordcloudChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _layoutSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant WordcloudChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature == _layoutSignature) return;
    _layoutSignature = nextSignature;
    _lastSize = Size.zero;
    _placed = const [];
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _layout(Size sz) {
    if (sz == _lastSize || sz.isEmpty) return;
    _lastSize = sz;
    _placed = _layoutWords(
      cfg.words,
      sz,
      cfg.minFontSize,
      cfg.maxFontSize,
      cfg.layoutSeed,
    );
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
        child: LayoutBuilder(
          builder: (ctx, con) {
            final sz = Size(con.maxWidth, con.maxHeight);
            _layout(sz);
            return RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: _WordcloudPainter(
                  config: cfg,
                  placed: _placed,
                  progress: _anim.value,
                  layoutSignature: _layoutSignature,
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _PlacedWord {
  final String text;
  final double fontSize, x, y;
  final Color color;
  final bool rotated;
  const _PlacedWord({
    required this.text,
    required this.fontSize,
    required this.x,
    required this.y,
    required this.color,
    required this.rotated,
  });
}

List<_PlacedWord> _layoutWords(
  List<WordItem> words,
  Size sz,
  double minFS,
  double maxFS,
  int seed,
) {
  if (words.isEmpty) return [];
  final sorted = [...words]..sort((a, b) => b.weight.compareTo(a.weight));
  final maxW = sorted.first.weight.clamp(1.0, 1e9);
  final rng = math.Random(seed);
  final placed = <_PlacedWord>[];
  final rects = <Rect>[];

  for (int i = 0; i < sorted.length; i++) {
    final w = sorted[i];
    final fs = minFS + (w.weight / maxW) * (maxFS - minFS);
    // Approximate text size
    final tw = w.text.length * fs * 0.6;
    final th = fs * 1.3;
    final rotated = rng.nextDouble() > 0.7;
    final ew = rotated ? th : tw, eh = rotated ? tw : th;

    // Spiral search for placement
    bool placed_ = false;
    for (int step = 0; step < 500; step++) {
      final angle = step * 0.4;
      final radius = step * 1.2;
      final cx = sz.width / 2 + math.cos(angle) * radius;
      final cy = sz.height / 2 + math.sin(angle) * radius;
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: ew + 4,
        height: eh + 4,
      );
      if (rect.left < 0 ||
          rect.top < 0 ||
          rect.right > sz.width ||
          rect.bottom > sz.height) {
        continue;
      }
      if (!rects.any((r) => r.overlaps(rect))) {
        rects.add(rect);
        final color = w.color != null
            ? colorCache.resolve(w.color!)
            : _wordColor(i, maxW, w.weight);
        placed.add(
          _PlacedWord(
            text: w.text,
            fontSize: fs,
            x: cx,
            y: cy,
            color: color,
            rotated: rotated,
          ),
        );
        placed_ = true;
        break;
      }
    }
    if (!placed_) break; // canvas full
  }
  return placed;
}

Color _wordColor(int idx, double maxW, double weight) {
  final palette = [
    const Color(0xFF2196F3),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF00BCD4),
  ];
  final base = palette[idx % palette.length];
  final factor = 0.6 + (weight / maxW) * 0.4;
  return Color.fromARGB(
    (base.a * 255.0).round().clamp(0, 255),
    ((base.r * 255.0) * factor).round().clamp(0, 255),
    ((base.g * 255.0) * factor).round().clamp(0, 255),
    ((base.b * 255.0) * factor).round().clamp(0, 255),
  );
}

class _WordcloudPainter extends ChartPainterBase {
  final WordcloudChartConfig config;
  final List<_PlacedWord> placed;
  final double progress;
  final String layoutSignature;
  _WordcloudPainter({
    required this.config,
    required this.placed,
    required this.progress,
    required this.layoutSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _WordcloudPainter old) =>
      old.progress != progress ||
      old.layoutSignature != layoutSignature ||
      !identical(old.placed, placed);

  @override
  void paint(Canvas canvas, Size size) {
    final visible = (placed.length * progress).ceil();
    for (int i = 0; i < visible; i++) {
      final w = placed[i];
      final tp = textPainterCache.get(
        w.text,
        TextStyle(
          fontSize: w.fontSize,
          fontWeight: FontWeight.w700,
          color: w.color,
          fontFamily: config.theme.typography.fontFamily.isEmpty
              ? null
              : config.theme.typography.fontFamily,
        ),
      );
      canvas.save();
      canvas.translate(w.x, w.y);
      if (w.rotated) canvas.rotate(-math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}
