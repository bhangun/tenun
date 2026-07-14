import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleSankeyValueFormatter = String Function(double value);
typedef SimpleSankeyNodeTapCallback =
    void Function(SimpleSankeyNode node, double value);
typedef SimpleSankeyLinkTapCallback =
    void Function(SimpleSankeyLink link, double value);
typedef SimpleSankeyTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleSankeyNode? node,
      SimpleSankeyLink? link,
      String title,
      String formattedValue,
    );

class SimpleSankeyNode {
  final String id;
  final String label;
  final int? column;
  final Color? color;

  const SimpleSankeyNode({
    required this.id,
    required this.label,
    this.column,
    this.color,
  });
}

class SimpleSankeyLink {
  final String source;
  final String target;
  final double value;
  final String? label;
  final Color? color;

  const SimpleSankeyLink({
    required this.source,
    required this.target,
    required this.value,
    this.label,
    this.color,
  });
}

/// A lightweight Sankey chart for proportional flow between stages, teams,
/// channels, budgets, or journey steps.
class SimpleSankeyChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(68, 18, 68, 36);

  final List<SimpleSankeyNode> nodes;
  final List<SimpleSankeyLink> links;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? nodeColor;
  final Color? linkColor;
  final Color? borderColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showNodeValues;
  final bool showTooltip;
  final bool showActiveItem;
  final double nodeWidth;
  final double nodeGap;
  final double minNodeHeight;
  final double linkOpacity;
  final double curveTension;
  final SimpleSankeyValueFormatter? valueFormatter;
  final SimpleSankeyNodeTapCallback? onNodeTap;
  final SimpleSankeyLinkTapCallback? onLinkTap;
  final SimpleSankeyTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleSankeyChart({
    super.key,
    this.nodes = const [],
    required this.links,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 280,
    this.padding = _defaultPadding,
    this.palette,
    this.nodeColor,
    this.linkColor,
    this.borderColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = true,
    this.showNodeValues = false,
    this.showTooltip = true,
    this.showActiveItem = true,
    this.nodeWidth = 18,
    this.nodeGap = 14,
    this.minNodeHeight = 8,
    this.linkOpacity = 0.28,
    this.curveTension = 0.54,
    this.valueFormatter,
    this.onNodeTap,
    this.onLinkTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(nodeWidth > 0),
       assert(nodeGap >= 0),
       assert(minNodeHeight >= 0),
       assert(linkOpacity >= 0 && linkOpacity <= 1),
       assert(curveTension >= 0 && curveTension <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleSankeyVisuals.resolve(style, colorScheme);
    final visibleLinks = links
        .where(
          (item) =>
              item.source.trim().isNotEmpty &&
              item.target.trim().isNotEmpty &&
              item.value.isFinite &&
              item.value > 0,
        )
        .toList();
    final resolvedNodes = _resolveNodes(nodes, visibleLinks);
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleLinks.isEmpty || resolvedNodes.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Sankey chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedLabelStyle =
            labelStyle ??
            theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            resolvedNodes,
            visibleLinks,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleSankeyChartView(
            width: width,
            height: chartHeight,
            nodes: resolvedNodes,
            links: visibleLinks,
            padding: padding,
            palette: palette,
            nodeColor: nodeColor ?? visuals.nodeColor,
            linkColor: linkColor ?? visuals.linkColor,
            borderColor: borderColor ?? visuals.borderColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showNodeValues: showNodeValues,
            showTooltip: showTooltip,
            showActiveItem: showActiveItem,
            nodeWidth: nodeWidth,
            nodeGap: nodeGap,
            minNodeHeight: minNodeHeight,
            linkOpacity: linkOpacity,
            curveTension: curveTension,
            valueFormatter: formatter,
            onNodeTap: onNodeTap,
            onLinkTap: onLinkTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static List<SimpleSankeyNode> _resolveNodes(
    List<SimpleSankeyNode> nodes,
    List<SimpleSankeyLink> links,
  ) {
    final byId = <String, SimpleSankeyNode>{
      for (final node in nodes)
        if (node.id.trim().isNotEmpty) node.id: node,
    };
    final result = <SimpleSankeyNode>[];
    final seen = <String>{};

    void add(String id) {
      if (seen.contains(id)) {
        return;
      }
      seen.add(id);
      result.add(byId[id] ?? SimpleSankeyNode(id: id, label: id));
    }

    for (final node in nodes) {
      if (node.id.trim().isNotEmpty) {
        add(node.id);
      }
    }
    for (final link in links) {
      add(link.source);
      add(link.target);
    }
    return result;
  }

  static String _defaultSemanticLabel(
    List<SimpleSankeyNode> nodes,
    List<SimpleSankeyLink> links,
    SimpleSankeyValueFormatter formatter,
  ) {
    final sample = links
        .take(5)
        .map((link) {
          return '${link.source} to ${link.target} ${formatter(link.value)}';
        })
        .join(', ');
    final suffix = links.length > 5 ? ', and ${links.length - 5} more' : '';
    return 'Sankey chart, ${nodes.length} nodes and ${links.length} links. '
        '$sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}m';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleSankeyChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleSankeyNode> nodes;
  final List<SimpleSankeyLink> links;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color nodeColor;
  final Color linkColor;
  final Color borderColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showNodeValues;
  final bool showTooltip;
  final bool showActiveItem;
  final double nodeWidth;
  final double nodeGap;
  final double minNodeHeight;
  final double linkOpacity;
  final double curveTension;
  final SimpleSankeyValueFormatter valueFormatter;
  final SimpleSankeyNodeTapCallback? onNodeTap;
  final SimpleSankeyLinkTapCallback? onLinkTap;
  final SimpleSankeyTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleSankeyChartView({
    required this.width,
    required this.height,
    required this.nodes,
    required this.links,
    required this.padding,
    required this.palette,
    required this.nodeColor,
    required this.linkColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showNodeValues,
    required this.showTooltip,
    required this.showActiveItem,
    required this.nodeWidth,
    required this.nodeGap,
    required this.minNodeHeight,
    required this.linkOpacity,
    required this.curveTension,
    required this.valueFormatter,
    required this.onNodeTap,
    required this.onLinkTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleSankeyChartView> createState() => _SimpleSankeyChartViewState();
}

class _SimpleSankeyChartViewState extends State<_SimpleSankeyChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _SankeySelection? _activeSelection;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _SimpleSankeyChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes ||
        oldWidget.links != widget.links ||
        oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.animationCurve != widget.animationCurve) {
      _controller.duration = widget.animationDuration;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onExit: (_) => _setActive(null),
                  onHover: (event) {
                    if (widget.showActiveItem ||
                        widget.showTooltip ||
                        widget.onNodeTap != null ||
                        widget.onLinkTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final selection = _hitTest(details.localPosition);
                      _setActive(selection);
                      if (selection?.node != null) {
                        widget.onNodeTap?.call(
                          selection!.node!.source,
                          selection.node!.value,
                        );
                      } else if (selection?.link != null) {
                        widget.onLinkTap?.call(
                          selection!.link!.source,
                          selection.link!.source.value,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleSankeyPainter(
                        nodes: widget.nodes,
                        links: widget.links,
                        padding: widget.padding,
                        palette: widget.palette,
                        nodeColor: widget.nodeColor,
                        linkColor: widget.linkColor,
                        borderColor: widget.borderColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showNodeValues: widget.showNodeValues,
                        nodeWidth: widget.nodeWidth,
                        nodeGap: widget.nodeGap,
                        minNodeHeight: widget.minNodeHeight,
                        linkOpacity: widget.linkOpacity,
                        curveTension: widget.curveTension,
                        valueFormatter: widget.valueFormatter,
                        activeNodeId: widget.showActiveItem
                            ? _activeSelection?.node?.source.id
                            : null,
                        activeLinkIndex: widget.showActiveItem
                            ? _activeSelection?.link?.index
                            : null,
                        progress: _animation.value,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeSelection != null)
                _buildTooltip(context, _activeSelection!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_SankeySelection? selection) {
    if (_activeSelection == selection) {
      return;
    }
    setState(() => _activeSelection = selection);
  }

  _SankeySelection? _hitTest(Offset position) {
    final geometry = _SankeyGeometry.resolve(
      nodes: widget.nodes,
      links: widget.links,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      nodeWidth: widget.nodeWidth,
      nodeGap: widget.nodeGap,
      minNodeHeight: widget.minNodeHeight,
      curveTension: widget.curveTension,
    );
    for (final node in geometry.nodes) {
      if (node.rect.inflate(4).contains(position)) {
        return _SankeySelection.node(node);
      }
    }
    for (final link in geometry.links.reversed) {
      if (_linkContains(link, position)) {
        return _SankeySelection.link(link);
      }
    }
    return null;
  }

  bool _linkContains(_ResolvedSankeyLink link, Offset position) {
    if (!link.hitBounds.inflate(6).contains(position)) {
      return false;
    }
    final totalDx = link.end.dx - link.start.dx;
    if (totalDx.abs() < 1e-6) {
      return (position.dy - link.start.dy).abs() <= link.thickness / 2 + 6;
    }
    final t = ((position.dx - link.start.dx) / totalDx).clamp(0.0, 1.0);
    final y = _cubic(
      link.start.dy,
      link.control1.dy,
      link.control2.dy,
      link.end.dy,
      t,
    );
    return (position.dy - y).abs() <= link.thickness / 2 + 7;
  }

  double _cubic(double a, double b, double c, double d, double t) {
    final mt = 1 - t;
    return mt * mt * mt * a +
        3 * mt * mt * t * b +
        3 * mt * t * t * c +
        t * t * t * d;
  }

  Widget _buildTooltip(BuildContext context, _SankeySelection selection) {
    final node = selection.node;
    final link = selection.link;
    final title = node != null
        ? node.source.label
        : '${link!.sourceNode.source.label} -> ${link.target.source.label}';
    final value = node?.value ?? link!.source.value;
    final formattedValue = widget.valueFormatter(value);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          node?.source,
          link?.source,
          title,
          formattedValue,
        ) ??
        _DefaultSankeyTooltip(
          title: title,
          rows: [_TooltipRow(node != null ? 'Flow' : 'Value', formattedValue)],
        );
    final anchor = node?.rect.center ?? link!.midpoint;
    final left = (anchor.dx + 12).clamp(8.0, widget.width - 176);
    final top = (anchor.dy - 44).clamp(8.0, widget.height - 92);

    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleSankeyPainter extends CustomPainter {
  final List<SimpleSankeyNode> nodes;
  final List<SimpleSankeyLink> links;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color nodeColor;
  final Color linkColor;
  final Color borderColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showNodeValues;
  final double nodeWidth;
  final double nodeGap;
  final double minNodeHeight;
  final double linkOpacity;
  final double curveTension;
  final SimpleSankeyValueFormatter valueFormatter;
  final String? activeNodeId;
  final int? activeLinkIndex;
  final double progress;

  const _SimpleSankeyPainter({
    required this.nodes,
    required this.links,
    required this.padding,
    required this.palette,
    required this.nodeColor,
    required this.linkColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showNodeValues,
    required this.nodeWidth,
    required this.nodeGap,
    required this.minNodeHeight,
    required this.linkOpacity,
    required this.curveTension,
    required this.valueFormatter,
    required this.activeNodeId,
    required this.activeLinkIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _SankeyGeometry.resolve(
      nodes: nodes,
      links: links,
      size: size,
      padding: padding,
      nodeWidth: nodeWidth,
      nodeGap: nodeGap,
      minNodeHeight: minNodeHeight,
      curveTension: curveTension,
    );
    if (geometry.nodes.isEmpty || geometry.links.isEmpty) {
      return;
    }

    for (final link in geometry.links) {
      _drawLink(canvas, link);
    }
    for (final node in geometry.nodes) {
      _drawNode(canvas, geometry, node);
    }
  }

  void _drawLink(Canvas canvas, _ResolvedSankeyLink link) {
    final active =
        activeLinkIndex == link.index ||
        activeNodeId == link.sourceNode.source.id ||
        activeNodeId == link.target.source.id;
    final color =
        link.sourceNode.source.color ??
        link.source.color ??
        (active ? activeColor : linkColor);
    final paint = Paint()
      ..color = color.withValues(alpha: active ? 0.58 : linkOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, link.thickness * progress)
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(link.start.dx, link.start.dy)
      ..cubicTo(
        link.control1.dx,
        link.control1.dy,
        link.control2.dx,
        link.control2.dy,
        link.end.dx,
        link.end.dy,
      );
    canvas.drawPath(path, paint);
  }

  void _drawNode(
    Canvas canvas,
    _SankeyGeometry geometry,
    _ResolvedSankeyNode node,
  ) {
    final active = activeNodeId == node.source.id;
    final color = _nodeColor(node, geometry.nodes.indexOf(node));
    final animatedRect = Rect.fromLTRB(
      node.rect.left,
      node.rect.bottom - node.rect.height * progress,
      node.rect.right,
      node.rect.bottom,
    );
    final radius = Radius.circular(math.min(6, nodeWidth / 2));
    final rrect = RRect.fromRectAndRadius(animatedRect, radius);
    final paint = Paint()
      ..color = active ? activeColor : color
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (!showLabels) {
      return;
    }

    final isLastColumn = node.column == geometry.maxColumn;
    final labelWidth = math.max(0.0, padding.left - 10);
    final value = valueFormatter(node.value);
    final labelRect = isLastColumn
        ? Rect.fromLTWH(
            node.rect.right + 6,
            node.rect.top,
            math.max(0, padding.right - 10),
            math.min(34, node.rect.height + 8),
          )
        : Rect.fromLTWH(
            node.rect.left - labelWidth - 8,
            node.rect.top,
            labelWidth,
            math.min(34, node.rect.height + 8),
          );
    _drawText(
      canvas,
      node.source.label,
      labelRect,
      labelStyle,
      align: isLastColumn ? TextAlign.left : TextAlign.right,
    );
    if (showValues || showNodeValues) {
      _drawText(
        canvas,
        value,
        labelRect.translate(0, 14),
        valueStyle,
        align: isLastColumn ? TextAlign.left : TextAlign.right,
      );
    }
  }

  Color _nodeColor(_ResolvedSankeyNode node, int index) {
    if (node.source.color != null) {
      return node.source.color!;
    }
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return nodeColor;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: rect.width);
    final dx = switch (align) {
      TextAlign.right => rect.right - painter.width,
      TextAlign.center => rect.left + (rect.width - painter.width) / 2,
      _ => rect.left,
    };
    final dy = rect.top + (rect.height - painter.height) / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _SimpleSankeyPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.links != links ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.nodeColor != nodeColor ||
        oldDelegate.linkColor != linkColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showNodeValues != showNodeValues ||
        oldDelegate.nodeWidth != nodeWidth ||
        oldDelegate.nodeGap != nodeGap ||
        oldDelegate.minNodeHeight != minNodeHeight ||
        oldDelegate.linkOpacity != linkOpacity ||
        oldDelegate.curveTension != curveTension ||
        oldDelegate.activeNodeId != activeNodeId ||
        oldDelegate.activeLinkIndex != activeLinkIndex ||
        oldDelegate.progress != progress;
  }
}

class _SankeyGeometry {
  final Rect plot;
  final int maxColumn;
  final List<_ResolvedSankeyNode> nodes;
  final List<_ResolvedSankeyLink> links;

  const _SankeyGeometry({
    required this.plot,
    required this.maxColumn,
    required this.nodes,
    required this.links,
  });

  factory _SankeyGeometry.resolve({
    required List<SimpleSankeyNode> nodes,
    required List<SimpleSankeyLink> links,
    required Size size,
    required EdgeInsets padding,
    required double nodeWidth,
    required double nodeGap,
    required double minNodeHeight,
    required double curveTension,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final sourceById = {for (final node in nodes) node.id: node};
    final incoming = {for (final node in nodes) node.id: 0.0};
    final outgoing = {for (final node in nodes) node.id: 0.0};
    for (final link in links) {
      outgoing[link.source] = (outgoing[link.source] ?? 0) + link.value;
      incoming[link.target] = (incoming[link.target] ?? 0) + link.value;
    }
    final columns = _assignColumns(nodes, links);
    final maxColumn = columns.values.fold<int>(0, math.max);
    final valueById = <String, double>{};
    for (final node in nodes) {
      valueById[node.id] = math.max(
        incoming[node.id] ?? 0,
        outgoing[node.id] ?? 0,
      );
    }

    final byColumn = <int, List<SimpleSankeyNode>>{};
    for (final node in nodes) {
      byColumn.putIfAbsent(columns[node.id] ?? 0, () => []).add(node);
    }
    var scale = double.infinity;
    for (final entry in byColumn.entries) {
      final total = entry.value.fold<double>(
        0,
        (sum, node) => sum + (valueById[node.id] ?? 0),
      );
      final available =
          plot.height - nodeGap * math.max(0, entry.value.length - 1);
      if (total > 0 && available > 0) {
        scale = math.min(scale, available / total);
      }
    }
    if (!scale.isFinite || scale <= 0) {
      scale = 1;
    }

    final resolvedNodes = <_ResolvedSankeyNode>[];
    for (final entry in byColumn.entries) {
      final column = entry.key;
      final columnNodes = entry.value;
      final totalHeight =
          columnNodes.fold<double>(
            0,
            (sum, node) =>
                sum +
                math.max(minNodeHeight, (valueById[node.id] ?? 0) * scale),
          ) +
          nodeGap * math.max(0, columnNodes.length - 1);
      var cursor = plot.top + math.max(0, plot.height - totalHeight) / 2;
      final x = maxColumn == 0
          ? plot.left + (plot.width - nodeWidth) / 2
          : plot.left + column / maxColumn * (plot.width - nodeWidth);
      for (final node in columnNodes) {
        final value = valueById[node.id] ?? 0;
        final height = math.max(minNodeHeight, value * scale);
        resolvedNodes.add(
          _ResolvedSankeyNode(
            source: sourceById[node.id] ?? node,
            rect: Rect.fromLTWH(x, cursor, nodeWidth, height),
            column: column,
            value: value,
            incoming: incoming[node.id] ?? 0,
            outgoing: outgoing[node.id] ?? 0,
          ),
        );
        cursor += height + nodeGap;
      }
    }

    final resolvedById = {
      for (final node in resolvedNodes) node.source.id: node,
    };
    final inCursor = <String, double>{
      for (final node in resolvedNodes) node.source.id: 0,
    };
    final outCursor = <String, double>{
      for (final node in resolvedNodes) node.source.id: 0,
    };
    final resolvedLinks = <_ResolvedSankeyLink>[];
    for (var index = 0; index < links.length; index++) {
      final link = links[index];
      final source = resolvedById[link.source];
      final target = resolvedById[link.target];
      if (source == null || target == null) {
        continue;
      }
      final sourceHeight = source.outgoing > 0
          ? source.rect.height * (link.value / source.outgoing)
          : link.value * scale;
      final targetHeight = target.incoming > 0
          ? target.rect.height * (link.value / target.incoming)
          : link.value * scale;
      final sy =
          source.rect.top +
          (outCursor[source.source.id] ?? 0) +
          sourceHeight / 2;
      final ty =
          target.rect.top +
          (inCursor[target.source.id] ?? 0) +
          targetHeight / 2;
      outCursor[source.source.id] =
          (outCursor[source.source.id] ?? 0) + sourceHeight;
      inCursor[target.source.id] =
          (inCursor[target.source.id] ?? 0) + targetHeight;
      final start = Offset(source.rect.right, sy);
      final end = Offset(target.rect.left, ty);
      final dx = (end.dx - start.dx).abs() * curveTension;
      final control1 = Offset(start.dx + dx, start.dy);
      final control2 = Offset(end.dx - dx, end.dy);
      final thickness = math.max(1.4, link.value * scale);
      resolvedLinks.add(
        _ResolvedSankeyLink(
          source: link,
          index: index,
          sourceNode: source,
          target: target,
          start: start,
          end: end,
          control1: control1,
          control2: control2,
          thickness: thickness,
          midpoint: Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2),
          hitBounds: Rect.fromLTRB(
            math.min(start.dx, end.dx),
            math.min(start.dy, end.dy) - thickness / 2,
            math.max(start.dx, end.dx),
            math.max(start.dy, end.dy) + thickness / 2,
          ),
        ),
      );
    }

    return _SankeyGeometry(
      plot: plot,
      maxColumn: maxColumn,
      nodes: resolvedNodes,
      links: resolvedLinks,
    );
  }

  static Map<String, int> _assignColumns(
    List<SimpleSankeyNode> nodes,
    List<SimpleSankeyLink> links,
  ) {
    final columns = <String, int>{};
    for (final node in nodes) {
      if (node.column != null) {
        columns[node.id] = node.column!.clamp(0, 1000);
      }
    }
    final incomingIds = links.map((link) => link.target).toSet();
    for (final node in nodes) {
      if (!incomingIds.contains(node.id)) {
        columns.putIfAbsent(node.id, () => 0);
      }
    }

    var changed = true;
    var guard = 0;
    while (changed && guard < nodes.length + links.length + 8) {
      changed = false;
      guard++;
      for (final link in links) {
        final sourceColumn = columns[link.source];
        if (sourceColumn == null) {
          continue;
        }
        final proposed = sourceColumn + 1;
        if ((columns[link.target] ?? -1) < proposed) {
          columns[link.target] = proposed;
          changed = true;
        }
      }
    }
    for (final node in nodes) {
      columns.putIfAbsent(node.id, () => 0);
    }
    return columns;
  }
}

class _ResolvedSankeyNode {
  final SimpleSankeyNode source;
  final Rect rect;
  final int column;
  final double value;
  final double incoming;
  final double outgoing;

  const _ResolvedSankeyNode({
    required this.source,
    required this.rect,
    required this.column,
    required this.value,
    required this.incoming,
    required this.outgoing,
  });
}

class _ResolvedSankeyLink {
  final SimpleSankeyLink source;
  final int index;
  final _ResolvedSankeyNode sourceNode;
  final _ResolvedSankeyNode target;
  final Offset start;
  final Offset end;
  final Offset control1;
  final Offset control2;
  final double thickness;
  final Offset midpoint;
  final Rect hitBounds;

  const _ResolvedSankeyLink({
    required this.source,
    required this.index,
    required this.sourceNode,
    required this.target,
    required this.start,
    required this.end,
    required this.control1,
    required this.control2,
    required this.thickness,
    required this.midpoint,
    required this.hitBounds,
  });
}

class _SankeySelection {
  final _ResolvedSankeyNode? node;
  final _ResolvedSankeyLink? link;

  const _SankeySelection._({this.node, this.link});

  factory _SankeySelection.node(_ResolvedSankeyNode node) {
    return _SankeySelection._(node: node);
  }

  factory _SankeySelection.link(_ResolvedSankeyLink link) {
    return _SankeySelection._(link: link);
  }

  @override
  bool operator ==(Object other) {
    return other is _SankeySelection &&
        other.node?.source.id == node?.source.id &&
        other.link?.index == link?.index;
  }

  @override
  int get hashCode => Object.hash(node?.source.id, link?.index);
}

class _SimpleSankeyVisuals {
  final Color nodeColor;
  final Color linkColor;
  final Color borderColor;
  final Color activeColor;

  const _SimpleSankeyVisuals({
    required this.nodeColor,
    required this.linkColor,
    required this.borderColor,
    required this.activeColor,
  });

  factory _SimpleSankeyVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleSankeyVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.primary,
          borderColor: colorScheme.outline.withValues(alpha: 0.18),
          activeColor: colorScheme.tertiary,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleSankeyVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.primary,
          borderColor: colorScheme.outline.withValues(alpha: 0.32),
          activeColor: colorScheme.onSurface,
        );
      case SimpleBarChartStyle.education:
        return _SimpleSankeyVisuals(
          nodeColor: colorScheme.secondary,
          linkColor: colorScheme.secondary,
          borderColor: colorScheme.outline.withValues(alpha: 0.24),
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleSankeyVisuals(
          nodeColor: colorScheme.tertiary,
          linkColor: colorScheme.tertiary,
          borderColor: colorScheme.outline.withValues(alpha: 0.16),
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleSankeyVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.primary,
          borderColor: colorScheme.outline.withValues(alpha: 0.22),
          activeColor: colorScheme.tertiary,
        );
    }
  }
}

class _DefaultSankeyTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultSankeyTooltip({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: DefaultTextStyle(
          style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final row in rows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 46, child: Text(row.label)),
                    Text(
                      row.value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TooltipRow {
  final String label;
  final String value;

  const _TooltipRow(this.label, this.value);
}
