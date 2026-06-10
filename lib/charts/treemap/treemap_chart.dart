// Treemap chart — hierarchical area chart using squarified tiling.
//
// JSON example:
// ```json
// {
//   "type": "treemap",
//   "title": { "text": "Portfolio" },
//   "series": [{
//     "data": [
//       { "name": "Tech", "value": 45, "children": [
//           { "name": "AAPL", "value": 20 },
//           { "name": "GOOGL", "value": 15 },
//           { "name": "MSFT", "value": 10 }
//       ]},
//       { "name": "Finance", "value": 30 },
//       { "name": "Healthcare", "value": 25 }
//     ]
//   }]
// }
// ```

import 'package:flutter/material.dart';

import '../../core/base_config.dart';
import '../../core/grid.dart';
import '../../core/legend.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';
import '../../core/chart_model.dart';
import '../../core/chart_cache.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_theme.dart';
import '../../core/chart_type.dart';
import '../../core/chart_series_json.dart';
import '../../core/json_value.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class TreemapNode {
  final String name;
  final double value;
  final List<TreemapNode> children;
  final String? color;

  const TreemapNode({
    required this.name,
    required this.value,
    this.children = const [],
    this.color,
  });

  bool get isLeaf => children.isEmpty;

  factory TreemapNode.fromJson(Map<String, dynamic> json) {
    final children = (JsonValue.mapList(json['children']) ?? const [])
        .map(TreemapNode.fromJson)
        .toList();

    return TreemapNode(
      name: json['name']?.toString() ?? '',
      value:
          JsonValue.doubleOrNull(json['value']) ??
          children.fold(0.0, (s, c) => s + c.value),
      children: children,
      color: json['color']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    if (color != null) 'color': color,
    if (children.isNotEmpty)
      'children': children.map((c) => c.toJson()).toList(),
  };
}

// ---------------------------------------------------------------------------
// Layout — squarified algorithm
// ---------------------------------------------------------------------------

class _LayoutRect {
  final TreemapNode node;
  final Rect rect;
  final int depth;
  const _LayoutRect(this.node, this.rect, this.depth);
}

class _Squarify {
  /// Lay out [nodes] within [bounds].
  static List<_LayoutRect> layout(
    List<TreemapNode> nodes,
    Rect bounds,
    int depth,
  ) {
    if (nodes.isEmpty) return const [];

    final total = nodes.fold(0.0, (s, n) => s + n.value);
    if (total == 0) return const [];

    final sorted = [...nodes]..sort((a, b) => b.value.compareTo(a.value));
    return _squarify(sorted, bounds, total, depth);
  }

  static List<_LayoutRect> _squarify(
    List<TreemapNode> nodes,
    Rect bounds,
    double total,
    int depth,
  ) {
    if (nodes.isEmpty) return const [];
    return _squarifyProper(nodes, bounds, total, depth);
  }

  static List<_LayoutRect> _squarifyProper(
    List<TreemapNode> nodes,
    Rect bounds,
    double total,
    int depth,
  ) {
    final List<_LayoutRect> result = [];
    if (nodes.isEmpty || total == 0) return result;

    // Convert values to areas proportional to bounds
    final area = bounds.width * bounds.height;
    final scale = area / total;

    Rect remaining = bounds;
    int start = 0;

    while (start < nodes.length) {
      // Try to find best row
      int end = start + 1;
      double rowSum = nodes[start].value * scale;

      while (end < nodes.length) {
        final newSum = rowSum + nodes[end].value * scale;
        final curr = _worstAspect(nodes, start, end - 1, rowSum, remaining);
        final next = _worstAspect(nodes, start, end, newSum, remaining);
        if (next > curr && end > start + 1) break;
        rowSum = newSum;
        end++;
      }

      // Lay out this row
      final isH = remaining.width >= remaining.height;
      final rowH = rowSum / (isH ? remaining.width : remaining.height);
      double pos = isH ? remaining.left : remaining.top;

      for (int i = start; i < end; i++) {
        final nodeArea = nodes[i].value * scale;
        final len = nodeArea / rowH;
        late Rect r;
        if (isH) {
          r = Rect.fromLTWH(pos, remaining.top, len, rowH);
          pos += len;
        } else {
          r = Rect.fromLTWH(remaining.left, pos, rowH, len);
          pos += len;
        }
        result.add(_LayoutRect(nodes[i], r, depth));
        if (!nodes[i].isLeaf) {
          result.addAll(
            _squarifyProper(
              [...nodes[i].children]
                ..sort((a, b) => b.value.compareTo(a.value)),
              r.deflate(1),
              nodes[i].value * scale,
              depth + 1,
            ),
          );
        }
      }

      // Shrink remaining rect
      if (isH) {
        remaining = Rect.fromLTRB(
          remaining.left,
          remaining.top + rowH,
          remaining.right,
          remaining.bottom,
        );
      } else {
        remaining = Rect.fromLTRB(
          remaining.left + rowH,
          remaining.top,
          remaining.right,
          remaining.bottom,
        );
      }
      start = end;
    }

    return result;
  }

  static double _worstAspect(
    List<TreemapNode> nodes,
    int start,
    int end,
    double rowSum,
    Rect bounds,
  ) {
    final isH = bounds.width >= bounds.height;
    final shortSide = isH ? bounds.height : bounds.width;
    if (rowSum == 0 || shortSide == 0) return double.infinity;
    final rowH = rowSum / (isH ? bounds.width : bounds.height);
    double worst = 0;
    for (int i = start; i <= end && i < nodes.length; i++) {
      // simplified area
      final len = nodes[i].value * (bounds.width * bounds.height / rowSum);
      final aspect = rowH / len;
      final ratio = aspect > 1 ? aspect : 1 / aspect;
      if (ratio > worst) worst = ratio;
    }
    return worst;
  }
}

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

class TreemapChartConfig extends BaseChartConfig {
  final List<TreemapNode> nodes;
  final bool showLabels;
  final bool showValues;
  final double borderWidth;
  final String borderColor;

  TreemapChartConfig({
    required this.nodes,
    super.theme = ChartTheme.light,
    this.showLabels = true,
    this.showValues = true,
    this.borderWidth = 2,
    this.borderColor = '#FFFFFF',
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.treemap, series: const []);

  @override
  Widget buildChart() => TreemapChartWidget(config: this);

  factory TreemapChartConfig.fromJson(Map<String, dynamic> json) {
    final nodes = ChartSeriesJson.firstSeriesData(
      json['series'],
    ).map(TreemapNode.fromJson).toList();

    return TreemapChartConfig(
      nodes: nodes,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? true,
      showValues: JsonValue.boolOrNull(json['showValues']) ?? true,
      borderWidth: JsonValue.doubleOrNull(json['borderWidth']) ?? 2,
      borderColor: json['borderColor']?.toString() ?? '#FFFFFF',
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
    'type': 'treemap',
    'showLabels': showLabels,
    'showValues': showValues,
    'borderWidth': borderWidth,
    'borderColor': borderColor,
    if (title != null) 'title': title!.toJson(),
    'series': [
      {'data': nodes.map((n) => n.toJson()).toList()},
    ],
  };
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class TreemapChartWidget extends StatefulWidget {
  final TreemapChartConfig config;
  const TreemapChartWidget({super.key, required this.config});

  @override
  State<TreemapChartWidget> createState() => _TreemapChartWidgetState();
}

class _TreemapChartWidgetState extends State<TreemapChartWidget> {
  String? _hoveredName;
  Offset? _hoverPos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.config.title?.text != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.config.title!.text!,
                style: widget.config.theme.typography.titleStyle.copyWith(
                  color: widget.config.theme.titleColor,
                ),
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
              final total = widget.config.nodes.fold(
                0.0,
                (s, n) => s + n.value,
              );
              final layout = _Squarify.layout(widget.config.nodes, bounds, 0);

              return MouseRegion(
                onHover: (e) {
                  final hit = _hitTest(layout, e.localPosition);
                  if (hit?.name != _hoveredName) {
                    setState(() {
                      _hoveredName = hit?.name;
                      _hoverPos = e.localPosition;
                    });
                  }
                },
                onExit: (_) => setState(() {
                  _hoveredName = null;
                  _hoverPos = null;
                }),
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _TreemapPainter(
                          config: widget.config,
                          layout: layout,
                          hoveredName: _hoveredName,
                          total: total,
                        ),
                      ),
                    ),
                    if (_hoveredName != null && _hoverPos != null)
                      _buildTooltip(size),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  TreemapNode? _hitTest(List<_LayoutRect> layout, Offset pos) {
    for (final r in layout.reversed) {
      if (r.node.isLeaf && r.rect.contains(pos)) return r.node;
    }
    return null;
  }

  Widget _buildTooltip(Size size) {
    final node = widget.config.nodes.firstWhere(
      (n) => n.name == _hoveredName,
      orElse: () => TreemapNode(name: '', value: 0),
    );
    final theme = widget.config.theme;
    double x = (_hoverPos!.dx + 12).clamp(0, size.width - 150);
    double y = (_hoverPos!.dy - 40).clamp(0, size.height - 60);

    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.tooltipBackgroundColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _hoveredName ?? '',
                style: theme.typography.tooltipStyle.copyWith(
                  color: theme.tooltipTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                node.value.toStringAsFixed(1),
                style: theme.typography.tooltipStyle.copyWith(
                  color: theme.tooltipTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _TreemapPainter extends ChartPainterBase {
  final TreemapChartConfig config;
  final List<_LayoutRect> layout;
  final String? hoveredName;
  final double total;

  _TreemapPainter({
    required this.config,
    required this.layout,
    required this.hoveredName,
    required this.total,
  });

  @override
  bool shouldRepaintChart(covariant _TreemapPainter old) =>
      old.hoveredName != hoveredName || old.layout != layout;

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = strokePaint(
      resolveColor(config.borderColor, Colors.white),
      config.borderWidth,
    );

    for (int i = 0; i < layout.length; i++) {
      final lr = layout[i];
      if (!lr.node.isLeaf) continue;

      // Color: explicit node color → palette
      Color color;
      if (lr.node.color != null) {
        color = resolveColor(lr.node.color, Colors.grey);
      } else {
        // Find root-level index
        int rootIdx = config.nodes.indexWhere((n) => n.name == lr.node.name);
        if (rootIdx < 0) rootIdx = i;
        color = theme.palette.colorObjectAt(rootIdx);
      }

      final isHovered = lr.node.name == hoveredName;
      if (isHovered) color = Color.lerp(color, Colors.white, 0.2)!;

      final rr = RRect.fromRectAndRadius(lr.rect, const Radius.circular(2));
      canvas.drawRRect(rr, fillPaint(color));
      if (config.borderWidth > 0) canvas.drawRRect(rr, borderPaint);

      // Labels
      if (config.showLabels && lr.rect.width > 40 && lr.rect.height > 20) {
        _drawNodeLabel(canvas, lr, color);
      }
    }
  }

  void _drawNodeLabel(Canvas canvas, _LayoutRect lr, Color bgColor) {
    final contrastColor = _contrastColor(bgColor);
    final style =
        theme.typography.dataLabelStyle?.copyWith(
          color: contrastColor,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(
          fontSize: 11,
          color: contrastColor,
          fontWeight: FontWeight.w600,
        );

    final nameTp = textPainterCache.get(
      lr.node.name,
      style,
      maxWidth: lr.rect.width - 8,
    );
    nameTp.paint(canvas, Offset(lr.rect.left + 4, lr.rect.top + 4));

    if (config.showValues && lr.rect.height > 36) {
      final valStyle = style.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w400,
      );
      final valTp = textPainterCache.get(
        lr.node.value.toStringAsFixed(1),
        valStyle,
        maxWidth: lr.rect.width - 8,
      );
      valTp.paint(
        canvas,
        Offset(lr.rect.left + 4, lr.rect.top + 4 + nameTp.height + 2),
      );
    }
  }

  Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.35 ? Colors.black87 : Colors.white;
  }
}
