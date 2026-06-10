import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleNetworkValueFormatter = String Function(double value);
typedef SimpleNetworkNodeTapCallback =
    void Function(SimpleNetworkNode node, int index);
typedef SimpleNetworkLinkTapCallback =
    void Function(SimpleNetworkLink link, int index);
typedef SimpleNetworkTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleNetworkSelection selection,
      String formattedValue,
    );

enum SimpleNetworkGraphLayout { radial, grouped, positioned }

enum SimpleNetworkSelectionType { node, link }

class SimpleNetworkNode {
  final String id;
  final String label;
  final double value;
  final String? group;
  final Color? color;

  /// Optional normalized x position from 0 to 1 inside the plot area.
  final double? x;

  /// Optional normalized y position from 0 to 1 inside the plot area.
  final double? y;

  const SimpleNetworkNode({
    required this.id,
    required this.label,
    this.value = 1,
    this.group,
    this.color,
    this.x,
    this.y,
  });
}

class SimpleNetworkLink {
  final String source;
  final String target;
  final double value;
  final String? label;
  final Color? color;
  final bool? directed;

  const SimpleNetworkLink({
    required this.source,
    required this.target,
    this.value = 1,
    this.label,
    this.color,
    this.directed,
  });
}

class SimpleNetworkSelection {
  final SimpleNetworkSelectionType type;
  final SimpleNetworkNode? node;
  final SimpleNetworkLink? link;
  final int index;
  final double value;

  const SimpleNetworkSelection.node({
    required this.node,
    required this.index,
    required this.value,
  }) : type = SimpleNetworkSelectionType.node,
       link = null;

  const SimpleNetworkSelection.link({
    required this.link,
    required this.index,
    required this.value,
  }) : type = SimpleNetworkSelectionType.link,
       node = null;
}

/// A simple node-link network graph for dependencies, relationships,
/// stakeholder maps, ecosystems, systems, and knowledge graphs.
class SimpleNetworkGraphChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(24, 22, 24, 24);

  final List<SimpleNetworkNode> nodes;
  final List<SimpleNetworkLink> links;
  final SimpleNetworkGraphLayout layout;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final Color? nodeColor;
  final Color? linkColor;
  final Color? activeColor;
  final Color? labelColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool directed;
  final bool showLabels;
  final bool showValues;
  final bool showLinkLabels;
  final bool showLegend;
  final bool showGroupHulls;
  final bool showTooltip;
  final bool showActiveItem;
  final double minNodeRadius;
  final double maxNodeRadius;
  final double minLinkWidth;
  final double maxLinkWidth;
  final double linkOpacity;
  final SimpleNetworkValueFormatter? valueFormatter;
  final SimpleNetworkNodeTapCallback? onNodeTap;
  final SimpleNetworkLinkTapCallback? onLinkTap;
  final SimpleNetworkTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleNetworkGraphChart({
    super.key,
    required this.nodes,
    required this.links,
    this.layout = SimpleNetworkGraphLayout.radial,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 280,
    this.padding = _defaultPadding,
    this.nodeColor,
    this.linkColor,
    this.activeColor,
    this.labelColor,
    this.labelStyle,
    this.valueStyle,
    this.directed = false,
    this.showLabels = true,
    this.showValues = false,
    this.showLinkLabels = false,
    this.showLegend = true,
    this.showGroupHulls = true,
    this.showTooltip = true,
    this.showActiveItem = true,
    this.minNodeRadius = 8,
    this.maxNodeRadius = 22,
    this.minLinkWidth = 1.2,
    this.maxLinkWidth = 5,
    this.linkOpacity = 0.38,
    this.valueFormatter,
    this.onNodeTap,
    this.onLinkTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(minNodeRadius > 0),
       assert(maxNodeRadius >= minNodeRadius),
       assert(minLinkWidth > 0),
       assert(maxLinkWidth >= minLinkWidth),
       assert(linkOpacity >= 0 && linkOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleNetworkVisuals.resolve(style, colorScheme);
    final resolved = _ResolvedNetwork.from(nodes: nodes, links: links);
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (resolved.nodes.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Network graph, no data.',
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
              color: labelColor ?? visuals.labelColor,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: labelColor ?? visuals.labelColor,
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
          semanticLabel: _defaultSemanticLabel(resolved, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleNetworkGraphView(
            width: width,
            height: chartHeight,
            network: resolved,
            layout: layout,
            padding: padding,
            palette: visuals.palette,
            nodeColor: nodeColor ?? visuals.nodeColor,
            linkColor: linkColor ?? visuals.linkColor,
            activeColor: activeColor ?? visuals.activeColor,
            hullColor: visuals.hullColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            directed: directed,
            showLabels: showLabels,
            showValues: showValues,
            showLinkLabels: showLinkLabels,
            showLegend: showLegend,
            showGroupHulls: showGroupHulls,
            showTooltip: showTooltip,
            showActiveItem: showActiveItem,
            minNodeRadius: minNodeRadius,
            maxNodeRadius: maxNodeRadius,
            minLinkWidth: minLinkWidth,
            maxLinkWidth: maxLinkWidth,
            linkOpacity: linkOpacity,
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

  static String _defaultSemanticLabel(
    _ResolvedNetwork network,
    SimpleNetworkValueFormatter formatter,
  ) {
    final sample = network.links
        .take(5)
        .map((link) {
          final source = network.nodeById[link.source]?.label ?? link.source;
          final target = network.nodeById[link.target]?.label ?? link.target;
          return '$source to $target ${formatter(link.value)}';
        })
        .join(', ');
    final suffix = network.links.length > 5
        ? ', and ${network.links.length - 5} more'
        : '';
    return 'Network graph, ${network.nodes.length} nodes and '
        '${network.links.length} links. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleNetworkGraphView extends StatefulWidget {
  final double width;
  final double height;
  final _ResolvedNetwork network;
  final SimpleNetworkGraphLayout layout;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color nodeColor;
  final Color linkColor;
  final Color activeColor;
  final Color hullColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool directed;
  final bool showLabels;
  final bool showValues;
  final bool showLinkLabels;
  final bool showLegend;
  final bool showGroupHulls;
  final bool showTooltip;
  final bool showActiveItem;
  final double minNodeRadius;
  final double maxNodeRadius;
  final double minLinkWidth;
  final double maxLinkWidth;
  final double linkOpacity;
  final SimpleNetworkValueFormatter valueFormatter;
  final SimpleNetworkNodeTapCallback? onNodeTap;
  final SimpleNetworkLinkTapCallback? onLinkTap;
  final SimpleNetworkTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleNetworkGraphView({
    required this.width,
    required this.height,
    required this.network,
    required this.layout,
    required this.padding,
    required this.palette,
    required this.nodeColor,
    required this.linkColor,
    required this.activeColor,
    required this.hullColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.directed,
    required this.showLabels,
    required this.showValues,
    required this.showLinkLabels,
    required this.showLegend,
    required this.showGroupHulls,
    required this.showTooltip,
    required this.showActiveItem,
    required this.minNodeRadius,
    required this.maxNodeRadius,
    required this.minLinkWidth,
    required this.maxLinkWidth,
    required this.linkOpacity,
    required this.valueFormatter,
    required this.onNodeTap,
    required this.onLinkTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleNetworkGraphView> createState() =>
      _SimpleNetworkGraphViewState();
}

class _SimpleNetworkGraphViewState extends State<_SimpleNetworkGraphView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  SimpleNetworkSelection? _selection;
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
  void didUpdateWidget(covariant _SimpleNetworkGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.network != widget.network ||
        oldWidget.layout != widget.layout ||
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
          final size = Size(widget.width, widget.height);
          final geometry = _NetworkGeometry.resolve(
            size: size,
            network: widget.network,
            layout: widget.layout,
            padding: widget.padding,
            palette: widget.palette,
            fallbackNodeColor: widget.nodeColor,
            minNodeRadius: widget.minNodeRadius,
            maxNodeRadius: widget.maxNodeRadius,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onHover: (event) {
                    setState(() {
                      _selection = _hitTest(event.localPosition, geometry);
                      _pointer = event.localPosition;
                    });
                  },
                  onExit: (_) => setState(() => _selection = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final selection = _hitTest(
                        details.localPosition,
                        geometry,
                      );
                      setState(() {
                        _selection = selection;
                        _pointer = details.localPosition;
                      });
                      if (selection?.node != null) {
                        widget.onNodeTap?.call(
                          selection!.node!,
                          selection.index,
                        );
                      } else if (selection?.link != null) {
                        widget.onLinkTap?.call(
                          selection!.link!,
                          selection.index,
                        );
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SimpleNetworkGraphPainter(
                            geometry: geometry,
                            linkColor: widget.linkColor,
                            activeColor: widget.activeColor,
                            hullColor: widget.hullColor,
                            labelStyle: widget.labelStyle,
                            valueStyle: widget.valueStyle,
                            directed: widget.directed,
                            showLabels: widget.showLabels,
                            showValues: widget.showValues,
                            showLinkLabels: widget.showLinkLabels,
                            showLegend: widget.showLegend,
                            showGroupHulls: widget.showGroupHulls,
                            showActiveItem: widget.showActiveItem,
                            minLinkWidth: widget.minLinkWidth,
                            maxLinkWidth: widget.maxLinkWidth,
                            linkOpacity: widget.linkOpacity,
                            valueFormatter: widget.valueFormatter,
                            selection: _selection,
                            progress: _animation.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _selection != null)
                _buildTooltip(context, size),
            ],
          );
        },
      ),
    );
  }

  SimpleNetworkSelection? _hitTest(Offset position, _NetworkGeometry geometry) {
    for (var i = geometry.nodes.length - 1; i >= 0; i--) {
      final node = geometry.nodes[i];
      if ((position - node.center).distance <= node.radius + 4) {
        return SimpleNetworkSelection.node(
          node: node.source,
          index: node.index,
          value: node.source.value,
        );
      }
    }
    for (var i = geometry.links.length - 1; i >= 0; i--) {
      final link = geometry.links[i];
      final distance = _distanceToSegment(
        position,
        link.source.center,
        link.target.center,
      );
      if (distance <= math.max(7, link.width + 4)) {
        return SimpleNetworkSelection.link(
          link: link.sourceLink,
          index: link.index,
          value: link.sourceLink.value,
        );
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final selection = _selection!;
    final formatted = widget.valueFormatter(selection.value);
    final child =
        widget.tooltipBuilder?.call(context, selection, formatted) ??
        _DefaultNetworkTooltip(selection: selection, formattedValue: formatted);
    const tooltipWidth = 184.0;
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

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (ab2 <= 0) {
      return (p - a).distance;
    }
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / ab2).clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - closest).distance;
  }
}

class _SimpleNetworkGraphPainter extends CustomPainter {
  final _NetworkGeometry geometry;
  final Color linkColor;
  final Color activeColor;
  final Color hullColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool directed;
  final bool showLabels;
  final bool showValues;
  final bool showLinkLabels;
  final bool showLegend;
  final bool showGroupHulls;
  final bool showActiveItem;
  final double minLinkWidth;
  final double maxLinkWidth;
  final double linkOpacity;
  final SimpleNetworkValueFormatter valueFormatter;
  final SimpleNetworkSelection? selection;
  final double progress;

  const _SimpleNetworkGraphPainter({
    required this.geometry,
    required this.linkColor,
    required this.activeColor,
    required this.hullColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.directed,
    required this.showLabels,
    required this.showValues,
    required this.showLinkLabels,
    required this.showLegend,
    required this.showGroupHulls,
    required this.showActiveItem,
    required this.minLinkWidth,
    required this.maxLinkWidth,
    required this.linkOpacity,
    required this.valueFormatter,
    required this.selection,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.nodes.isEmpty) {
      return;
    }
    if (showGroupHulls) {
      _drawGroupHulls(canvas);
    }
    _drawLinks(canvas);
    _drawNodes(canvas);
    if (showLabels) {
      _drawLabels(canvas);
    }
    if (showLegend) {
      _drawLegend(canvas);
    }
  }

  void _drawGroupHulls(Canvas canvas) {
    final byGroup = <String, List<_NetworkNodeLayout>>{};
    for (final node in geometry.nodes) {
      final group = node.source.group;
      if (group == null || group.isEmpty) {
        continue;
      }
      byGroup.putIfAbsent(group, () => []).add(node);
    }
    for (final entry in byGroup.entries) {
      if (entry.value.length < 2) {
        continue;
      }
      final center =
          entry.value.fold<Offset>(
            Offset.zero,
            (sum, node) => sum + node.center,
          ) /
          entry.value.length.toDouble();
      final radius =
          entry.value
              .map((node) => (node.center - center).distance + node.radius + 12)
              .fold<double>(0, math.max) *
          progress;
      final color = geometry.groupColors[entry.key] ?? hullColor;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _drawLinks(Canvas canvas) {
    final selectedNodeId = selection?.node?.id;
    final selectedLink = selection?.link;
    final maxValue = geometry.maxLinkValue <= 0 ? 1 : geometry.maxLinkValue;
    for (final link in geometry.links) {
      final related =
          selectedNodeId == null ||
          link.source.source.id == selectedNodeId ||
          link.target.source.id == selectedNodeId ||
          selectedLink == link.sourceLink;
      final active = selectedLink == link.sourceLink;
      final alpha = showActiveItem && selection != null
          ? (related ? linkOpacity + 0.28 : 0.1)
          : linkOpacity;
      final width =
          minLinkWidth +
          (maxLinkWidth - minLinkWidth) *
              (link.sourceLink.value / maxValue).clamp(0.0, 1.0);
      final color = link.sourceLink.color ?? link.source.color;
      final paint = Paint()
        ..color = (active ? activeColor : color).withValues(
          alpha: alpha.clamp(0.0, 1.0).toDouble(),
        )
        ..strokeWidth = active ? width + 1.2 : width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final sourceCenter = _animatedPoint(link.source.center);
      final targetCenter = _animatedPoint(link.target.center);
      final path = Path()
        ..moveTo(sourceCenter.dx, sourceCenter.dy)
        ..lineTo(targetCenter.dx, targetCenter.dy);
      canvas.drawPath(path, paint);

      if (directed || link.sourceLink.directed == true) {
        _drawArrow(canvas, sourceCenter, targetCenter, paint.color);
      }
      if (showLinkLabels) {
        final mid = Offset(
          (sourceCenter.dx + targetCenter.dx) / 2,
          (sourceCenter.dy + targetCenter.dy) / 2,
        );
        _drawText(
          canvas,
          link.sourceLink.label ?? valueFormatter(link.sourceLink.value),
          mid + const Offset(4, -13),
          valueStyle.copyWith(color: paint.color.withValues(alpha: 0.9)),
          maxWidth: 74,
        );
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final target = Offset(
      to.dx - math.cos(angle) * 12,
      to.dy - math.sin(angle) * 12,
    );
    const size = 7.0;
    final p1 = Offset(
      target.dx - math.cos(angle - math.pi / 6) * size,
      target.dy - math.sin(angle - math.pi / 6) * size,
    );
    final p2 = Offset(
      target.dx - math.cos(angle + math.pi / 6) * size,
      target.dy - math.sin(angle + math.pi / 6) * size,
    );
    canvas.drawPath(
      Path()
        ..moveTo(target.dx, target.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close(),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  void _drawNodes(Canvas canvas) {
    final selectedNodeId = selection?.node?.id;
    for (final node in geometry.nodes) {
      final related =
          selectedNodeId == null ||
          node.source.id == selectedNodeId ||
          geometry.links.any(
            (link) =>
                (link.source.source.id == selectedNodeId &&
                    link.target.source.id == node.source.id) ||
                (link.target.source.id == selectedNodeId &&
                    link.source.source.id == node.source.id),
          );
      final active = node.source.id == selectedNodeId;
      final center = _animatedPoint(node.center);
      final radius = node.radius * (0.45 + 0.55 * progress);
      if (showActiveItem && active) {
        canvas.drawCircle(
          center,
          radius + 7,
          Paint()
            ..color = activeColor.withValues(alpha: 0.18)
            ..style = PaintingStyle.fill,
        );
      }
      final alpha = showActiveItem && selection != null
          ? (related ? 1.0 : 0.34)
          : 1.0;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = node.color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 2.4 : 1.4,
      );
      if (showValues && radius >= 12) {
        final valueText = valueFormatter(node.source.value);
        _drawText(
          canvas,
          valueText,
          center - const Offset(18, 7),
          valueStyle.copyWith(color: Colors.white),
          maxWidth: 36,
          align: TextAlign.center,
        );
      }
    }
  }

  void _drawLabels(Canvas canvas) {
    for (final node in geometry.nodes) {
      final center = _animatedPoint(node.center);
      final label = node.source.label;
      final labelOffset = Offset(center.dx - 42, center.dy + node.radius + 5);
      _drawText(
        canvas,
        label,
        labelOffset,
        labelStyle,
        maxWidth: 84,
        align: TextAlign.center,
      );
    }
  }

  void _drawLegend(Canvas canvas) {
    if (geometry.groupColors.isEmpty) {
      return;
    }
    final entries = geometry.groupColors.entries.take(4).toList();
    var dx = geometry.plotRect.left;
    final y = geometry.plotRect.top - 14;
    for (final entry in entries) {
      canvas.drawCircle(
        Offset(dx + 5, y + 5),
        4,
        Paint()
          ..color = entry.value
          ..style = PaintingStyle.fill,
      );
      final textWidth = _measureText(entry.key, labelStyle).width;
      _drawText(
        canvas,
        entry.key,
        Offset(dx + 13, y - 2),
        labelStyle.copyWith(fontSize: (labelStyle.fontSize ?? 12) * 0.92),
        maxWidth: 82,
      );
      dx += math.min(104, textWidth + 26);
      if (dx > geometry.plotRect.right - 80) {
        break;
      }
    }
  }

  Offset _animatedPoint(Offset point) {
    final center = geometry.plotRect.center;
    return Offset(
      center.dx + (point.dx - center.dx) * progress,
      center.dy + (point.dy - center.dy) * progress,
    );
  }

  Size _measureText(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.size;
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
  bool shouldRepaint(covariant _SimpleNetworkGraphPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.linkColor != linkColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.hullColor != hullColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.directed != directed ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLinkLabels != showLinkLabels ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showGroupHulls != showGroupHulls ||
        oldDelegate.showActiveItem != showActiveItem ||
        oldDelegate.minLinkWidth != minLinkWidth ||
        oldDelegate.maxLinkWidth != maxLinkWidth ||
        oldDelegate.linkOpacity != linkOpacity ||
        oldDelegate.selection != selection ||
        oldDelegate.progress != progress;
  }
}

class _ResolvedNetwork {
  final List<SimpleNetworkNode> nodes;
  final List<SimpleNetworkLink> links;
  final Map<String, SimpleNetworkNode> nodeById;

  const _ResolvedNetwork({
    required this.nodes,
    required this.links,
    required this.nodeById,
  });

  factory _ResolvedNetwork.from({
    required List<SimpleNetworkNode> nodes,
    required List<SimpleNetworkLink> links,
  }) {
    final nodeById = <String, SimpleNetworkNode>{};
    final ordered = <SimpleNetworkNode>[];
    for (final node in nodes) {
      final id = node.id.trim();
      if (id.isEmpty || !node.value.isFinite || nodeById.containsKey(id)) {
        continue;
      }
      final resolved = SimpleNetworkNode(
        id: id,
        label: node.label.trim().isEmpty ? id : node.label.trim(),
        value: math.max(0, node.value),
        group: node.group,
        color: node.color,
        x: node.x,
        y: node.y,
      );
      nodeById[id] = resolved;
      ordered.add(resolved);
    }

    final resolvedLinks = <SimpleNetworkLink>[];
    for (final link in links) {
      final source = link.source.trim();
      final target = link.target.trim();
      if (source.isEmpty ||
          target.isEmpty ||
          source == target ||
          !link.value.isFinite) {
        continue;
      }
      nodeById.putIfAbsent(source, () {
        final node = SimpleNetworkNode(
          id: source,
          label: _titleCaseIdentifier(source),
        );
        ordered.add(node);
        return node;
      });
      nodeById.putIfAbsent(target, () {
        final node = SimpleNetworkNode(
          id: target,
          label: _titleCaseIdentifier(target),
        );
        ordered.add(node);
        return node;
      });
      resolvedLinks.add(
        SimpleNetworkLink(
          source: source,
          target: target,
          value: math.max(0, link.value),
          label: link.label,
          color: link.color,
          directed: link.directed,
        ),
      );
    }

    return _ResolvedNetwork(
      nodes: ordered,
      links: resolvedLinks,
      nodeById: nodeById,
    );
  }

  static String _titleCaseIdentifier(String value) {
    return value
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }
}

class _NetworkGeometry {
  final Rect plotRect;
  final List<_NetworkNodeLayout> nodes;
  final List<_NetworkLinkLayout> links;
  final Map<String, Color> groupColors;
  final double maxLinkValue;

  const _NetworkGeometry({
    required this.plotRect,
    required this.nodes,
    required this.links,
    required this.groupColors,
    required this.maxLinkValue,
  });

  factory _NetworkGeometry.resolve({
    required Size size,
    required _ResolvedNetwork network,
    required SimpleNetworkGraphLayout layout,
    required EdgeInsets padding,
    required List<Color> palette,
    required Color fallbackNodeColor,
    required double minNodeRadius,
    required double maxNodeRadius,
  }) {
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal),
      math.max(1, size.height - padding.vertical),
    );
    final groupColors = _resolveGroupColors(network.nodes, palette);
    final maxNodeValue = network.nodes
        .map((node) => node.value)
        .fold<double>(0, math.max);
    final positions = _resolvePositions(
      network: network,
      layout: layout,
      plotRect: plotRect,
    );
    final nodeLayouts = <_NetworkNodeLayout>[];
    for (var i = 0; i < network.nodes.length; i++) {
      final node = network.nodes[i];
      final t = maxNodeValue <= 0
          ? 0.5
          : (node.value / maxNodeValue).clamp(0.0, 1.0).toDouble();
      final radius = minNodeRadius + (maxNodeRadius - minNodeRadius) * t;
      nodeLayouts.add(
        _NetworkNodeLayout(
          source: node,
          index: i,
          center: positions[node.id] ?? plotRect.center,
          radius: radius,
          color:
              node.color ??
              (node.group == null
                  ? fallbackNodeColor
                  : groupColors[node.group] ?? fallbackNodeColor),
        ),
      );
    }
    final byId = {for (final node in nodeLayouts) node.source.id: node};
    final linkLayouts = <_NetworkLinkLayout>[];
    var maxLinkValue = 0.0;
    for (var i = 0; i < network.links.length; i++) {
      final link = network.links[i];
      final source = byId[link.source];
      final target = byId[link.target];
      if (source == null || target == null) {
        continue;
      }
      maxLinkValue = math.max(maxLinkValue, link.value);
      linkLayouts.add(
        _NetworkLinkLayout(
          sourceLink: link,
          index: i,
          source: source,
          target: target,
          width: link.value,
        ),
      );
    }
    return _NetworkGeometry(
      plotRect: plotRect,
      nodes: nodeLayouts,
      links: linkLayouts,
      groupColors: groupColors,
      maxLinkValue: maxLinkValue,
    );
  }

  static Map<String, Color> _resolveGroupColors(
    List<SimpleNetworkNode> nodes,
    List<Color> palette,
  ) {
    final result = <String, Color>{};
    for (final node in nodes) {
      final group = node.group;
      if (group == null || group.isEmpty || result.containsKey(group)) {
        continue;
      }
      result[group] = palette[result.length % palette.length];
    }
    return result;
  }

  static Map<String, Offset> _resolvePositions({
    required _ResolvedNetwork network,
    required SimpleNetworkGraphLayout layout,
    required Rect plotRect,
  }) {
    final positioned = <String, Offset>{};
    var positionedCount = 0;
    for (final node in network.nodes) {
      if (node.x != null && node.y != null) {
        positioned[node.id] = Offset(
          plotRect.left + plotRect.width * node.x!.clamp(0.0, 1.0).toDouble(),
          plotRect.top + plotRect.height * node.y!.clamp(0.0, 1.0).toDouble(),
        );
        positionedCount++;
      }
    }
    if (layout == SimpleNetworkGraphLayout.positioned ||
        positionedCount == network.nodes.length) {
      return {..._radialPositions(network.nodes, plotRect), ...positioned};
    }
    if (layout == SimpleNetworkGraphLayout.grouped) {
      return {..._groupedPositions(network.nodes, plotRect), ...positioned};
    }
    return {..._radialPositions(network.nodes, plotRect), ...positioned};
  }

  static Map<String, Offset> _radialPositions(
    List<SimpleNetworkNode> nodes,
    Rect plotRect,
  ) {
    final result = <String, Offset>{};
    if (nodes.length == 1) {
      result[nodes.first.id] = plotRect.center;
      return result;
    }
    final radius = math.max(
      12.0,
      math.min(plotRect.width, plotRect.height) / 2 - 42,
    );
    for (var i = 0; i < nodes.length; i++) {
      final angle = -math.pi / 2 + math.pi * 2 * i / nodes.length;
      result[nodes[i].id] = Offset(
        plotRect.center.dx + math.cos(angle) * radius,
        plotRect.center.dy + math.sin(angle) * radius,
      );
    }
    return result;
  }

  static Map<String, Offset> _groupedPositions(
    List<SimpleNetworkNode> nodes,
    Rect plotRect,
  ) {
    final byGroup = <String, List<SimpleNetworkNode>>{};
    for (final node in nodes) {
      byGroup.putIfAbsent(node.group ?? 'Other', () => []).add(node);
    }
    final result = <String, Offset>{};
    final groups = byGroup.entries.toList();
    final clusterRadius = math.max(
      16.0,
      math.min(plotRect.width, plotRect.height) / 2 - 54,
    );
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex].value;
      final groupAngle =
          -math.pi / 2 + math.pi * 2 * groupIndex / groups.length;
      final groupCenter = groups.length == 1
          ? plotRect.center
          : Offset(
              plotRect.center.dx + math.cos(groupAngle) * clusterRadius * 0.64,
              plotRect.center.dy + math.sin(groupAngle) * clusterRadius * 0.64,
            );
      final innerRadius = math.max(18.0, clusterRadius * 0.34);
      for (var i = 0; i < group.length; i++) {
        if (group.length == 1) {
          result[group[i].id] = groupCenter;
          continue;
        }
        final angle = -math.pi / 2 + math.pi * 2 * i / group.length;
        result[group[i].id] = Offset(
          groupCenter.dx + math.cos(angle) * innerRadius,
          groupCenter.dy + math.sin(angle) * innerRadius,
        );
      }
    }
    return result;
  }
}

class _NetworkNodeLayout {
  final SimpleNetworkNode source;
  final int index;
  final Offset center;
  final double radius;
  final Color color;

  const _NetworkNodeLayout({
    required this.source,
    required this.index,
    required this.center,
    required this.radius,
    required this.color,
  });
}

class _NetworkLinkLayout {
  final SimpleNetworkLink sourceLink;
  final int index;
  final _NetworkNodeLayout source;
  final _NetworkNodeLayout target;
  final double width;

  const _NetworkLinkLayout({
    required this.sourceLink,
    required this.index,
    required this.source,
    required this.target,
    required this.width,
  });
}

class _SimpleNetworkVisuals {
  final Color nodeColor;
  final Color linkColor;
  final Color activeColor;
  final Color hullColor;
  final Color labelColor;
  final List<Color> palette;

  const _SimpleNetworkVisuals({
    required this.nodeColor,
    required this.linkColor,
    required this.activeColor,
    required this.hullColor,
    required this.labelColor,
    required this.palette,
  });

  factory _SimpleNetworkVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleNetworkVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.outline,
          activeColor: colorScheme.primary.withValues(alpha: 0.14),
          hullColor: colorScheme.primary,
          labelColor: colorScheme.onSurfaceVariant,
          palette: const [
            Color(0xFF2563EB),
            Color(0xFF10B981),
            Color(0xFFF59E0B),
            Color(0xFFEF4444),
            Color(0xFF8B5CF6),
          ],
        );
      case SimpleBarChartStyle.professional:
        return _SimpleNetworkVisuals(
          nodeColor: const Color(0xFF2563EB),
          linkColor: const Color(0xFF64748B),
          activeColor: const Color(0xFF0F172A).withValues(alpha: 0.08),
          hullColor: const Color(0xFF64748B),
          labelColor: const Color(0xFF334155),
          palette: const [
            Color(0xFF0F766E),
            Color(0xFF2563EB),
            Color(0xFF7C2D12),
            Color(0xFF6D28D9),
            Color(0xFFBE123C),
          ],
        );
      case SimpleBarChartStyle.education:
        return _SimpleNetworkVisuals(
          nodeColor: const Color(0xFF2563EB),
          linkColor: const Color(0xFF94A3B8),
          activeColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
          hullColor: const Color(0xFF2563EB),
          labelColor: const Color(0xFF475569),
          palette: const [
            Color(0xFF2563EB),
            Color(0xFFF97316),
            Color(0xFF16A34A),
            Color(0xFFDB2777),
            Color(0xFF9333EA),
          ],
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleNetworkVisuals(
          nodeColor: const Color(0xFF14B8A6),
          linkColor: colorScheme.outlineVariant,
          activeColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
          hullColor: const Color(0xFF8B5CF6),
          labelColor: colorScheme.onSurfaceVariant,
          palette: const [
            Color(0xFF14B8A6),
            Color(0xFFF43F5E),
            Color(0xFF8B5CF6),
            Color(0xFFF59E0B),
            Color(0xFF06B6D4),
          ],
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleNetworkVisuals(
          nodeColor: colorScheme.secondary,
          linkColor: colorScheme.outlineVariant,
          activeColor: colorScheme.secondary.withValues(alpha: 0.1),
          hullColor: colorScheme.secondary,
          labelColor: colorScheme.onSurfaceVariant,
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

class _DefaultNetworkTooltip extends StatelessWidget {
  final SimpleNetworkSelection selection;
  final String formattedValue;

  const _DefaultNetworkTooltip({
    required this.selection,
    required this.formattedValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title =
        selection.node?.label ??
        selection.link?.label ??
        '${selection.link?.source ?? ''} -> ${selection.link?.target ?? ''}';
    final subtitle =
        selection.node?.group ??
        (selection.link == null
            ? null
            : '${selection.link!.source} to ${selection.link!.target}');
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 184,
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
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 7),
              Row(
                children: [
                  const Expanded(child: Text('Value')),
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
