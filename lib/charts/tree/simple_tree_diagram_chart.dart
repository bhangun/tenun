import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleTreeValueFormatter = String Function(double value);
typedef SimpleTreeNodeTapCallback =
    void Function(
      SimpleTreeDiagramData data,
      List<SimpleTreeDiagramData> path,
      double value,
      int depth,
    );
typedef SimpleTreeTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleTreeDiagramData data,
      List<SimpleTreeDiagramData> path,
      String formattedValue,
      int depth,
    );

enum SimpleTreeDiagramOrientation { vertical, horizontal }

class SimpleTreeDiagramData {
  final String label;
  final double value;
  final List<SimpleTreeDiagramData> children;
  final Color? color;

  const SimpleTreeDiagramData({
    required this.label,
    this.value = 0,
    this.children = const [],
    this.color,
  });
}

/// A simple node-link hierarchy chart for org charts, taxonomies, decision
/// trees, curriculum maps, product architecture, and nested breakdowns.
class SimpleTreeDiagramChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(28, 34, 28, 34);

  final List<SimpleTreeDiagramData> data;
  final SimpleTreeDiagramOrientation orientation;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? nodeColor;
  final Color? linkColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showRoot;
  final bool showTooltip;
  final bool showActiveNode;
  final bool curvedLinks;
  final int maxDepth;
  final double minNodeRadius;
  final double maxNodeRadius;
  final double linkWidth;
  final double siblingGap;
  final SimpleTreeValueFormatter? valueFormatter;
  final SimpleTreeNodeTapCallback? onNodeTap;
  final SimpleTreeTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleTreeDiagramChart({
    super.key,
    required this.data,
    this.orientation = SimpleTreeDiagramOrientation.vertical,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 280,
    this.padding = _defaultPadding,
    this.palette,
    this.nodeColor,
    this.linkColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = false,
    this.showRoot = true,
    this.showTooltip = true,
    this.showActiveNode = true,
    this.curvedLinks = true,
    this.maxDepth = 4,
    this.minNodeRadius = 8,
    this.maxNodeRadius = 18,
    this.linkWidth = 1.6,
    this.siblingGap = 18,
    this.valueFormatter,
    this.onNodeTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(maxDepth >= 1),
       assert(minNodeRadius > 0),
       assert(maxNodeRadius >= minNodeRadius),
       assert(linkWidth > 0),
       assert(siblingGap >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleTreeVisuals.resolve(style, colorScheme);
    final roots = _ResolvedTreeNode.resolve(data, showRoot, maxDepth);
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (roots.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Tree diagram, no data.',
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
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(roots, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleTreeDiagramView(
            width: width,
            height: chartHeight,
            roots: roots,
            orientation: orientation,
            padding: padding,
            palette: palette ?? visuals.palette,
            nodeColor: nodeColor ?? visuals.nodeColor,
            linkColor: linkColor ?? visuals.linkColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showTooltip: showTooltip,
            showActiveNode: showActiveNode,
            curvedLinks: curvedLinks,
            minNodeRadius: minNodeRadius,
            maxNodeRadius: maxNodeRadius,
            linkWidth: linkWidth,
            siblingGap: siblingGap,
            valueFormatter: formatter,
            onNodeTap: onNodeTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<_ResolvedTreeNode> roots,
    SimpleTreeValueFormatter formatter,
  ) {
    final nodes = _flatten(roots);
    final links = math.max(0, nodes.length - roots.length);
    final sample = nodes
        .take(6)
        .map((node) {
          return '${node.source.label} ${formatter(node.value)}';
        })
        .join(', ');
    final suffix = nodes.length > 6 ? ', and ${nodes.length - 6} more' : '';
    return 'Tree diagram, ${nodes.length} nodes and $links links. '
        '$sample$suffix.';
  }

  static List<_ResolvedTreeNode> _flatten(List<_ResolvedTreeNode> roots) {
    final result = <_ResolvedTreeNode>[];
    void visit(_ResolvedTreeNode node) {
      result.add(node);
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final root in roots) {
      visit(root);
    }
    return result;
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleTreeDiagramView extends StatefulWidget {
  final double width;
  final double height;
  final List<_ResolvedTreeNode> roots;
  final SimpleTreeDiagramOrientation orientation;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color nodeColor;
  final Color linkColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveNode;
  final bool curvedLinks;
  final double minNodeRadius;
  final double maxNodeRadius;
  final double linkWidth;
  final double siblingGap;
  final SimpleTreeValueFormatter valueFormatter;
  final SimpleTreeNodeTapCallback? onNodeTap;
  final SimpleTreeTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleTreeDiagramView({
    required this.width,
    required this.height,
    required this.roots,
    required this.orientation,
    required this.padding,
    required this.palette,
    required this.nodeColor,
    required this.linkColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showTooltip,
    required this.showActiveNode,
    required this.curvedLinks,
    required this.minNodeRadius,
    required this.maxNodeRadius,
    required this.linkWidth,
    required this.siblingGap,
    required this.valueFormatter,
    required this.onNodeTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleTreeDiagramView> createState() => _SimpleTreeDiagramViewState();
}

class _SimpleTreeDiagramViewState extends State<_SimpleTreeDiagramView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  _TreeNodeLayout? _active;
  Offset _pointer = Offset.zero;

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
  void didUpdateWidget(covariant _SimpleTreeDiagramView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roots != widget.roots ||
        oldWidget.orientation != widget.orientation ||
        oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.animationCurve != widget.animationCurve) {
      _controller.duration = widget.animationDuration;
      _animation = CurvedAnimation(
        parent: _controller,
        curve: widget.animationCurve,
      );
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final geometry = _TreeGeometry.resolve(
            size: Size(widget.width, widget.height),
            roots: widget.roots,
            orientation: widget.orientation,
            padding: widget.padding,
            palette: widget.palette,
            nodeColor: widget.nodeColor,
            minNodeRadius: widget.minNodeRadius,
            maxNodeRadius: widget.maxNodeRadius,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onHover: (event) {
                    setState(() {
                      _active = _hitTest(event.localPosition, geometry);
                      _pointer = event.localPosition;
                    });
                  },
                  onExit: (_) => setState(() => _active = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final active = _hitTest(details.localPosition, geometry);
                      setState(() {
                        _active = active;
                        _pointer = details.localPosition;
                      });
                      if (active != null) {
                        widget.onNodeTap?.call(
                          active.node.source,
                          active.node.path,
                          active.node.value,
                          active.node.depth,
                        );
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SimpleTreeDiagramPainter(
                            geometry: geometry,
                            orientation: widget.orientation,
                            linkColor: widget.linkColor,
                            activeColor: widget.activeColor,
                            labelStyle: widget.labelStyle,
                            valueStyle: widget.valueStyle,
                            showLabels: widget.showLabels,
                            showValues: widget.showValues,
                            showActiveNode: widget.showActiveNode,
                            curvedLinks: widget.curvedLinks,
                            linkWidth: widget.linkWidth,
                            valueFormatter: widget.valueFormatter,
                            activeNode: _active,
                            progress: _animation.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _active != null)
                _buildTooltip(context, Size(widget.width, widget.height)),
            ],
          );
        },
      ),
    );
  }

  _TreeNodeLayout? _hitTest(Offset position, _TreeGeometry geometry) {
    for (var i = geometry.nodes.length - 1; i >= 0; i--) {
      final node = geometry.nodes[i];
      if ((position - node.center).distance <= node.radius + 7) {
        return node;
      }
      if (node.labelRect.inflate(3).contains(position)) {
        return node;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final active = _active!;
    final formatted = widget.valueFormatter(active.node.value);
    final child =
        widget.tooltipBuilder?.call(
          context,
          active.node.source,
          active.node.path,
          formatted,
          active.node.depth,
        ) ??
        _DefaultTreeTooltip(
          data: active.node.source,
          path: active.node.path,
          formattedValue: formatted,
          depth: active.node.depth,
        );
    const tooltipWidth = 190.0;
    const tooltipHeight = 104.0;
    final maxLeft = math.max(8.0, size.width - tooltipWidth - 8);
    final maxTop = math.max(8.0, size.height - tooltipHeight - 8);
    final left = (_pointer.dx + 12).clamp(8.0, maxLeft).toDouble();
    final top = (_pointer.dy - tooltipHeight - 8).clamp(8.0, maxTop).toDouble();
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(child: child),
    );
  }
}

class _SimpleTreeDiagramPainter extends CustomPainter {
  final _TreeGeometry geometry;
  final SimpleTreeDiagramOrientation orientation;
  final Color linkColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showActiveNode;
  final bool curvedLinks;
  final double linkWidth;
  final SimpleTreeValueFormatter valueFormatter;
  final _TreeNodeLayout? activeNode;
  final double progress;

  const _SimpleTreeDiagramPainter({
    required this.geometry,
    required this.orientation,
    required this.linkColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showActiveNode,
    required this.curvedLinks,
    required this.linkWidth,
    required this.valueFormatter,
    required this.activeNode,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.nodes.isEmpty) {
      return;
    }
    _drawLinks(canvas);
    _drawNodes(canvas);
    if (showLabels) {
      _drawLabels(canvas);
    }
  }

  void _drawLinks(Canvas canvas) {
    final activePath = activeNode?.node.path;
    for (final link in geometry.links) {
      final active =
          activePath != null &&
          activePath.contains(link.parent.node.source) &&
          activePath.contains(link.child.node.source);
      final paint = Paint()
        ..color = linkColor.withValues(
          alpha: activeNode == null || active ? 0.42 : 0.14,
        )
        ..strokeWidth = active ? linkWidth + 1 : linkWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final from = _animatedPoint(link.parent.center);
      final to = _animatedPoint(link.child.center);
      if (curvedLinks) {
        final path = Path()..moveTo(from.dx, from.dy);
        if (orientation == SimpleTreeDiagramOrientation.vertical) {
          final midY = (from.dy + to.dy) / 2;
          path.cubicTo(from.dx, midY, to.dx, midY, to.dx, to.dy);
        } else {
          final midX = (from.dx + to.dx) / 2;
          path.cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy);
        }
        canvas.drawPath(path, paint);
      } else {
        canvas.drawLine(from, to, paint);
      }
    }
  }

  void _drawNodes(Canvas canvas) {
    final activePath = activeNode?.node.path;
    for (final node in geometry.nodes) {
      final active = activeNode?.node == node.node;
      final related =
          activePath == null || activePath.contains(node.node.source);
      final center = _animatedPoint(node.center);
      final radius = node.radius * (0.55 + 0.45 * progress);
      if (showActiveNode && active) {
        canvas.drawCircle(
          center,
          radius + 8,
          Paint()
            ..color = activeColor
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = node.color.withValues(alpha: related ? progress : 0.34)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: related ? 0.76 : 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2.4 : 1.4,
      );
      if (showValues && radius >= 11) {
        _drawText(
          canvas,
          valueFormatter(node.node.value),
          center - const Offset(18, 7),
          valueStyle.copyWith(color: Colors.white.withValues(alpha: progress)),
          maxWidth: 36,
          align: TextAlign.center,
        );
      }
    }
  }

  void _drawLabels(Canvas canvas) {
    for (final node in geometry.nodes) {
      final active = activeNode?.node == node.node;
      final style = labelStyle.copyWith(
        color: (active ? node.color : labelStyle.color)?.withValues(
          alpha: progress,
        ),
        fontWeight: active ? FontWeight.w800 : labelStyle.fontWeight,
      );
      _drawText(
        canvas,
        node.node.source.label,
        node.labelRect.topLeft,
        style,
        maxWidth: node.labelRect.width,
        align: TextAlign.center,
      );
    }
  }

  Offset _animatedPoint(Offset point) {
    final center = geometry.plotRect.center;
    return Offset(
      center.dx + (point.dx - center.dx) * progress,
      center.dy + (point.dy - center.dy) * progress,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double? maxWidth,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SimpleTreeDiagramPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.orientation != orientation ||
        oldDelegate.linkColor != linkColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showActiveNode != showActiveNode ||
        oldDelegate.curvedLinks != curvedLinks ||
        oldDelegate.linkWidth != linkWidth ||
        oldDelegate.activeNode != activeNode ||
        oldDelegate.progress != progress;
  }
}

class _ResolvedTreeNode {
  final SimpleTreeDiagramData source;
  final List<SimpleTreeDiagramData> path;
  final List<_ResolvedTreeNode> children;
  final double value;
  final int depth;
  final int index;
  final double order;

  const _ResolvedTreeNode({
    required this.source,
    required this.path,
    required this.children,
    required this.value,
    required this.depth,
    required this.index,
    required this.order,
  });

  static List<_ResolvedTreeNode> resolve(
    List<SimpleTreeDiagramData> source,
    bool showRoot,
    int maxDepth,
  ) {
    var index = 0;
    var leafOrder = 0.0;

    _ResolvedTreeNode? visit(
      SimpleTreeDiagramData item,
      List<SimpleTreeDiagramData> path,
      int depth,
    ) {
      final label = item.label.trim();
      if (label.isEmpty || depth >= maxDepth) {
        return null;
      }
      final visibleChildren = <_ResolvedTreeNode>[];
      final cleaned = SimpleTreeDiagramData(
        label: label,
        value: item.value,
        children: item.children,
        color: item.color,
      );
      final nextPath = [...path, cleaned];
      for (final child in item.children) {
        final resolved = visit(child, nextPath, depth + 1);
        if (resolved != null) {
          visibleChildren.add(resolved);
        }
      }
      final childValue = visibleChildren.fold<double>(
        0,
        (sum, child) => sum + child.value,
      );
      final value = item.value.isFinite && item.value > 0
          ? item.value
          : childValue;
      if (value <= 0 && visibleChildren.isEmpty) {
        return null;
      }
      final order = visibleChildren.isEmpty
          ? leafOrder++
          : visibleChildren
                    .map((child) => child.order)
                    .fold<double>(0, (sum, value) => sum + value) /
                visibleChildren.length;
      return _ResolvedTreeNode(
        source: cleaned,
        path: nextPath,
        children: visibleChildren,
        value: math.max(value, 0),
        depth: depth,
        index: index++,
        order: order,
      );
    }

    final roots = <_ResolvedTreeNode>[];
    for (final item in source) {
      final root = visit(item, const [], 0);
      if (root == null) {
        continue;
      }
      if (showRoot) {
        roots.add(root);
      } else {
        roots.addAll(root.children);
      }
    }
    return roots;
  }
}

class _TreeGeometry {
  final Rect plotRect;
  final List<_TreeNodeLayout> nodes;
  final List<_TreeLinkLayout> links;

  const _TreeGeometry({
    required this.plotRect,
    required this.nodes,
    required this.links,
  });

  factory _TreeGeometry.resolve({
    required Size size,
    required List<_ResolvedTreeNode> roots,
    required SimpleTreeDiagramOrientation orientation,
    required EdgeInsets padding,
    required List<Color> palette,
    required Color nodeColor,
    required double minNodeRadius,
    required double maxNodeRadius,
  }) {
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal),
      math.max(1, size.height - padding.vertical),
    );
    final allNodes = SimpleTreeDiagramChart._flatten(roots);
    if (allNodes.isEmpty) {
      return _TreeGeometry(
        plotRect: plotRect,
        nodes: const [],
        links: const [],
      );
    }
    final minDepth = allNodes
        .map((node) => node.depth)
        .fold<int>(allNodes.first.depth, math.min);
    final maxDepth = allNodes
        .map((node) => node.depth)
        .fold<int>(allNodes.first.depth, math.max);
    final maxOrder = allNodes
        .map((node) => node.order)
        .fold<double>(0, math.max);
    final maxValue = allNodes
        .map((node) => node.value)
        .fold<double>(0, math.max);
    final nodeLayouts = <_TreeNodeLayout>[];
    final byNode = <_ResolvedTreeNode, _TreeNodeLayout>{};
    for (final node in allNodes) {
      final radius =
          minNodeRadius +
          (maxNodeRadius - minNodeRadius) *
              (maxValue <= 0
                  ? 0.5
                  : (node.value / maxValue).clamp(0.0, 1.0).toDouble());
      final depthSpan = maxDepth - minDepth;
      final depthT = depthSpan == 0 ? 0.0 : (node.depth - minDepth) / depthSpan;
      final orderT = maxOrder == 0 ? 0.5 : node.order / maxOrder;
      final center = orientation == SimpleTreeDiagramOrientation.vertical
          ? Offset(
              plotRect.left + plotRect.width * orderT,
              plotRect.top + plotRect.height * depthT,
            )
          : Offset(
              plotRect.left + plotRect.width * depthT,
              plotRect.top + plotRect.height * orderT,
            );
      final color =
          node.source.color ??
          (palette.isEmpty ? nodeColor : palette[node.depth % palette.length]);
      final labelRect = orientation == SimpleTreeDiagramOrientation.vertical
          ? Rect.fromCenter(
              center: Offset(center.dx, center.dy + radius + 13),
              width: 92,
              height: 18,
            )
          : Rect.fromLTWH(center.dx + radius + 7, center.dy - 9, 94, 18);
      final layout = _TreeNodeLayout(
        node: node,
        center: center,
        radius: radius,
        color: color,
        labelRect: labelRect,
      );
      nodeLayouts.add(layout);
      byNode[node] = layout;
    }

    final links = <_TreeLinkLayout>[];
    void collectLinks(_ResolvedTreeNode node) {
      final parent = byNode[node];
      if (parent == null) {
        return;
      }
      for (final child in node.children) {
        final childLayout = byNode[child];
        if (childLayout != null) {
          links.add(_TreeLinkLayout(parent: parent, child: childLayout));
        }
        collectLinks(child);
      }
    }

    for (final root in roots) {
      collectLinks(root);
    }
    return _TreeGeometry(plotRect: plotRect, nodes: nodeLayouts, links: links);
  }
}

class _TreeNodeLayout {
  final _ResolvedTreeNode node;
  final Offset center;
  final double radius;
  final Color color;
  final Rect labelRect;

  const _TreeNodeLayout({
    required this.node,
    required this.center,
    required this.radius,
    required this.color,
    required this.labelRect,
  });
}

class _TreeLinkLayout {
  final _TreeNodeLayout parent;
  final _TreeNodeLayout child;

  const _TreeLinkLayout({required this.parent, required this.child});
}

class _SimpleTreeVisuals {
  final Color nodeColor;
  final Color linkColor;
  final Color activeColor;
  final List<Color> palette;

  const _SimpleTreeVisuals({
    required this.nodeColor,
    required this.linkColor,
    required this.activeColor,
    required this.palette,
  });

  factory _SimpleTreeVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleTreeVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.outline,
          activeColor: colorScheme.primary.withValues(alpha: 0.12),
          palette: const [
            Color(0xFF2563EB),
            Color(0xFF10B981),
            Color(0xFFF59E0B),
            Color(0xFFEF4444),
            Color(0xFF8B5CF6),
          ],
        );
      case SimpleBarChartStyle.professional:
        return _SimpleTreeVisuals(
          nodeColor: const Color(0xFF2563EB),
          linkColor: const Color(0xFF64748B),
          activeColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
          palette: const [
            Color(0xFF1D4ED8),
            Color(0xFF0F766E),
            Color(0xFF7C2D12),
            Color(0xFF6D28D9),
            Color(0xFFBE123C),
          ],
        );
      case SimpleBarChartStyle.education:
        return _SimpleTreeVisuals(
          nodeColor: const Color(0xFF2563EB),
          linkColor: const Color(0xFF94A3B8),
          activeColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
          palette: const [
            Color(0xFF2563EB),
            Color(0xFFF97316),
            Color(0xFF16A34A),
            Color(0xFFDB2777),
            Color(0xFF9333EA),
          ],
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleTreeVisuals(
          nodeColor: const Color(0xFF14B8A6),
          linkColor: colorScheme.outlineVariant,
          activeColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
          palette: const [
            Color(0xFF14B8A6),
            Color(0xFFF43F5E),
            Color(0xFF8B5CF6),
            Color(0xFFF59E0B),
            Color(0xFF06B6D4),
          ],
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleTreeVisuals(
          nodeColor: colorScheme.secondary,
          linkColor: colorScheme.outlineVariant,
          activeColor: colorScheme.secondary.withValues(alpha: 0.1),
          palette: const [
            Color(0xFF0F766E),
            Color(0xFF7C3AED),
            Color(0xFF2563EB),
            Color(0xFFE11D48),
            Color(0xFFCA8A04),
          ],
        );
    }
  }
}

class _DefaultTreeTooltip extends StatelessWidget {
  final SimpleTreeDiagramData data;
  final List<SimpleTreeDiagramData> path;
  final String formattedValue;
  final int depth;

  const _DefaultTreeTooltip({
    required this.data,
    required this.path,
    required this.formattedValue,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trail = path.map((item) => item.label).join(' / ');
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style:
              theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onInverseSurface,
                fontWeight: FontWeight.w600,
              ) ??
              TextStyle(
                color: colorScheme.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(trail, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 7),
              Row(
                children: [
                  Text('Depth $depth'),
                  const Spacer(),
                  Text(
                    formattedValue,
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
