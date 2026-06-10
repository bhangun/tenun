import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleArcDiagramValueFormatter = String Function(double value);
typedef SimpleArcDiagramNodeTapCallback =
    void Function(SimpleArcDiagramNode node, double value);
typedef SimpleArcDiagramLinkTapCallback =
    void Function(SimpleArcDiagramLink link, int index);
typedef SimpleArcDiagramTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleArcDiagramNode? node,
      SimpleArcDiagramLink? link,
      int? linkIndex,
      String title,
      String formattedValue,
    );

class SimpleArcDiagramNode {
  final String id;
  final String label;
  final double? value;
  final Color? color;

  const SimpleArcDiagramNode({
    required this.id,
    required this.label,
    this.value,
    this.color,
  });
}

class SimpleArcDiagramLink {
  final String source;
  final String target;
  final double value;
  final String? label;
  final Color? color;

  const SimpleArcDiagramLink({
    required this.source,
    required this.target,
    required this.value,
    this.label,
    this.color,
  });
}

/// A simple arc diagram for ordered relationships, dependencies, co-usage,
/// sequence jumps, curriculum paths, and lightweight network stories.
class SimpleArcDiagramChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(54, 18, 24, 42);

  final List<SimpleArcDiagramNode> nodes;
  final List<SimpleArcDiagramLink> links;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? nodeColor;
  final Color? linkColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showAxis;
  final bool showDirection;
  final bool showTooltip;
  final bool showActiveItem;
  final double nodeRadius;
  final double minArcHeight;
  final double maxArcHeight;
  final double minStrokeWidth;
  final double maxStrokeWidth;
  final double arcOpacity;
  final SimpleArcDiagramValueFormatter? valueFormatter;
  final SimpleArcDiagramNodeTapCallback? onNodeTap;
  final SimpleArcDiagramLinkTapCallback? onLinkTap;
  final SimpleArcDiagramTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleArcDiagramChart({
    super.key,
    this.nodes = const [],
    required this.links,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.nodeColor,
    this.linkColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = true,
    this.showAxis = true,
    this.showDirection = false,
    this.showTooltip = true,
    this.showActiveItem = true,
    this.nodeRadius = 6,
    this.minArcHeight = 28,
    this.maxArcHeight = 150,
    this.minStrokeWidth = 1.6,
    this.maxStrokeWidth = 8,
    this.arcOpacity = 0.42,
    this.valueFormatter,
    this.onNodeTap,
    this.onLinkTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(nodeRadius >= 0),
       assert(minArcHeight >= 0),
       assert(maxArcHeight >= 0),
       assert(minStrokeWidth >= 0),
       assert(maxStrokeWidth >= 0),
       assert(minStrokeWidth <= maxStrokeWidth),
       assert(arcOpacity >= 0 && arcOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleArcDiagramVisuals.resolve(style, colorScheme);
    final visibleNodes = _resolveNodes(nodes, links);
    final nodeIds = visibleNodes.map((node) => node.id).toSet();
    final visibleLinks = links
        .where(
          (link) =>
              link.source.trim().isNotEmpty &&
              link.target.trim().isNotEmpty &&
              link.source != link.target &&
              nodeIds.contains(link.source) &&
              nodeIds.contains(link.target) &&
              link.value.isFinite &&
              link.value > 0,
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleNodes.length < 2 || visibleLinks.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Arc diagram, no data.',
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
            visibleNodes,
            visibleLinks,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleArcDiagramChartView(
            width: width,
            height: chartHeight,
            nodes: visibleNodes,
            links: visibleLinks,
            padding: padding,
            palette: palette,
            nodeColor: nodeColor ?? visuals.nodeColor,
            linkColor: linkColor ?? visuals.linkColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showAxis: showAxis,
            showDirection: showDirection,
            showTooltip: showTooltip,
            showActiveItem: showActiveItem,
            nodeRadius: nodeRadius,
            minArcHeight: minArcHeight,
            maxArcHeight: maxArcHeight,
            minStrokeWidth: minStrokeWidth,
            maxStrokeWidth: maxStrokeWidth,
            arcOpacity: arcOpacity,
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

  static List<SimpleArcDiagramNode> _resolveNodes(
    List<SimpleArcDiagramNode> nodes,
    List<SimpleArcDiagramLink> links,
  ) {
    final seen = <String>{};
    final result = <SimpleArcDiagramNode>[];
    for (final node in nodes) {
      final id = node.id.trim();
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      result.add(
        SimpleArcDiagramNode(
          id: id,
          label: node.label.trim().isEmpty ? id : node.label.trim(),
          value: node.value,
          color: node.color,
        ),
      );
    }
    if (result.isNotEmpty) {
      return result;
    }
    for (final link in links) {
      for (final id in [link.source.trim(), link.target.trim()]) {
        if (id.isNotEmpty && seen.add(id)) {
          result.add(SimpleArcDiagramNode(id: id, label: id));
        }
      }
    }
    return result;
  }

  static String _linkTitle(
    SimpleArcDiagramLink link,
    Map<String, SimpleArcDiagramNode> nodesById,
  ) {
    if (link.label != null && link.label!.trim().isNotEmpty) {
      return link.label!;
    }
    final source = nodesById[link.source]?.label ?? link.source;
    final target = nodesById[link.target]?.label ?? link.target;
    return '$source -> $target';
  }

  static String _defaultSemanticLabel(
    List<SimpleArcDiagramNode> nodes,
    List<SimpleArcDiagramLink> links,
    SimpleArcDiagramValueFormatter formatter,
  ) {
    final nodesById = {for (final node in nodes) node.id: node};
    final sample = links
        .take(4)
        .map(
          (link) => '${_linkTitle(link, nodesById)} ${formatter(link.value)}',
        )
        .join(', ');
    final suffix = links.length > 4 ? ', and ${links.length - 4} more' : '';
    return 'Arc diagram, ${nodes.length} nodes and ${links.length} links. '
        '$sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value >= 1000) {
      final precision = value >= 10000 ? 0 : 1;
      return '${(value / 1000).toStringAsFixed(precision)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleArcDiagramChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleArcDiagramNode> nodes;
  final List<SimpleArcDiagramLink> links;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color nodeColor;
  final Color linkColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showAxis;
  final bool showDirection;
  final bool showTooltip;
  final bool showActiveItem;
  final double nodeRadius;
  final double minArcHeight;
  final double maxArcHeight;
  final double minStrokeWidth;
  final double maxStrokeWidth;
  final double arcOpacity;
  final SimpleArcDiagramValueFormatter valueFormatter;
  final SimpleArcDiagramNodeTapCallback? onNodeTap;
  final SimpleArcDiagramLinkTapCallback? onLinkTap;
  final SimpleArcDiagramTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleArcDiagramChartView({
    required this.width,
    required this.height,
    required this.nodes,
    required this.links,
    required this.padding,
    required this.palette,
    required this.nodeColor,
    required this.linkColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showAxis,
    required this.showDirection,
    required this.showTooltip,
    required this.showActiveItem,
    required this.nodeRadius,
    required this.minArcHeight,
    required this.maxArcHeight,
    required this.minStrokeWidth,
    required this.maxStrokeWidth,
    required this.arcOpacity,
    required this.valueFormatter,
    required this.onNodeTap,
    required this.onLinkTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleArcDiagramChartView> createState() =>
      _SimpleArcDiagramChartViewState();
}

class _SimpleArcDiagramChartViewState extends State<_SimpleArcDiagramChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _ArcDiagramHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleArcDiagramChartView oldWidget) {
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
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit?.node != null) {
                        widget.onNodeTap?.call(
                          hit!.node!.node,
                          hit.node!.resolvedValue,
                        );
                      } else if (hit?.link != null) {
                        widget.onLinkTap?.call(
                          hit!.link!.link,
                          hit.link!.index,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleArcDiagramPainter(
                        nodes: widget.nodes,
                        links: widget.links,
                        padding: widget.padding,
                        palette: widget.palette,
                        nodeColor: widget.nodeColor,
                        linkColor: widget.linkColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showAxis: widget.showAxis,
                        showDirection: widget.showDirection,
                        showActiveItem: widget.showActiveItem,
                        nodeRadius: widget.nodeRadius,
                        minArcHeight: widget.minArcHeight,
                        maxArcHeight: widget.maxArcHeight,
                        minStrokeWidth: widget.minStrokeWidth,
                        maxStrokeWidth: widget.maxStrokeWidth,
                        arcOpacity: widget.arcOpacity,
                        valueFormatter: widget.valueFormatter,
                        activeHit: _activeHit,
                        progress: _animation.value,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeHit != null)
                _buildTooltip(context, _activeHit!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_ArcDiagramHit? hit) {
    if (_activeHit?.key == hit?.key) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _ArcDiagramHit? _hitTest(Offset position) {
    final geometry = _ArcDiagramGeometry.resolve(
      nodes: widget.nodes,
      links: widget.links,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      nodeRadius: widget.nodeRadius,
      minArcHeight: widget.minArcHeight,
      maxArcHeight: widget.maxArcHeight,
      minStrokeWidth: widget.minStrokeWidth,
      maxStrokeWidth: widget.maxStrokeWidth,
    );
    for (final node in geometry.nodes.reversed) {
      if ((position - node.center).distance <= widget.nodeRadius + 8) {
        return _ArcDiagramHit(node: node);
      }
    }
    for (final link in geometry.links.reversed) {
      if (link.distanceTo(position) <= math.max(8, link.strokeWidth + 5)) {
        return _ArcDiagramHit(link: link);
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _ArcDiagramHit hit) {
    final nodesById = {for (final node in widget.nodes) node.id: node};
    final node = hit.node;
    final link = hit.link;
    final title =
        node?.node.label ??
        (link == null
            ? ''
            : SimpleArcDiagramChart._linkTitle(link.link, nodesById));
    final value = node?.resolvedValue ?? link?.link.value ?? 0;
    final formattedValue = widget.valueFormatter(value);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          node?.node,
          link?.link,
          link?.index,
          title,
          formattedValue,
        ) ??
        _DefaultArcDiagramTooltip(
          title: title,
          rows: [
            if (node != null) _TooltipRow('Links', node.linkCount.toString()),
            if (link != null) ...[
              _TooltipRow(
                'From',
                nodesById[link.link.source]?.label ?? link.link.source,
              ),
              _TooltipRow(
                'To',
                nodesById[link.link.target]?.label ?? link.link.target,
              ),
            ],
            _TooltipRow('Value', formattedValue),
          ],
        );
    final anchor = node?.center ?? link?.anchor ?? Offset.zero;
    final maxLeft = math.max(8.0, widget.width - 226);
    final maxTop = math.max(8.0, widget.height - 126);
    final left = (anchor.dx + 12).clamp(8.0, maxLeft).toDouble();
    final top = (anchor.dy - 52).clamp(8.0, maxTop).toDouble();
    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleArcDiagramPainter extends CustomPainter {
  final List<SimpleArcDiagramNode> nodes;
  final List<SimpleArcDiagramLink> links;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color nodeColor;
  final Color linkColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showAxis;
  final bool showDirection;
  final bool showActiveItem;
  final double nodeRadius;
  final double minArcHeight;
  final double maxArcHeight;
  final double minStrokeWidth;
  final double maxStrokeWidth;
  final double arcOpacity;
  final SimpleArcDiagramValueFormatter valueFormatter;
  final _ArcDiagramHit? activeHit;
  final double progress;

  const _SimpleArcDiagramPainter({
    required this.nodes,
    required this.links,
    required this.padding,
    required this.palette,
    required this.nodeColor,
    required this.linkColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showAxis,
    required this.showDirection,
    required this.showActiveItem,
    required this.nodeRadius,
    required this.minArcHeight,
    required this.maxArcHeight,
    required this.minStrokeWidth,
    required this.maxStrokeWidth,
    required this.arcOpacity,
    required this.valueFormatter,
    required this.activeHit,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _ArcDiagramGeometry.resolve(
      nodes: nodes,
      links: links,
      size: size,
      padding: padding,
      nodeRadius: nodeRadius,
      minArcHeight: minArcHeight,
      maxArcHeight: maxArcHeight,
      minStrokeWidth: minStrokeWidth,
      maxStrokeWidth: maxStrokeWidth,
    );
    if (geometry.nodes.isEmpty || geometry.links.isEmpty) {
      return;
    }

    if (showAxis) {
      _drawAxis(canvas, geometry);
    }
    for (final link in geometry.links) {
      _drawLink(canvas, geometry, link);
    }
    if (showActiveItem && activeHit?.link != null) {
      _drawLink(canvas, geometry, activeHit!.link!, active: true);
    }
    for (final node in geometry.nodes) {
      _drawNode(canvas, geometry, node);
    }
  }

  void _drawAxis(Canvas canvas, _ArcDiagramGeometry geometry) {
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.baseline),
      Offset(geometry.plot.right, geometry.baseline),
      Paint()
        ..color = axisColor.withValues(alpha: 0.46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  void _drawLink(
    Canvas canvas,
    _ArcDiagramGeometry geometry,
    _ArcDiagramLinkLayout link, {
    bool active = false,
  }) {
    final color = active
        ? activeColor
        : link.link.color ?? _colorFor(link.sourceIndex);
    final path = Path()
      ..moveTo(link.start.dx, link.start.dy)
      ..quadraticBezierTo(
        link.control.dx,
        geometry.baseline - (geometry.baseline - link.control.dy) * progress,
        link.end.dx,
        link.end.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: active ? 0.88 : arcOpacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = active ? link.strokeWidth + 2 : link.strokeWidth,
    );
    if (showDirection && (active || link.strokeWidth >= 2.2)) {
      _drawArrow(canvas, geometry, link, color, active);
    }
  }

  void _drawArrow(
    Canvas canvas,
    _ArcDiagramGeometry geometry,
    _ArcDiagramLinkLayout link,
    Color color,
    bool active,
  ) {
    final t = link.sourceIndex < link.targetIndex ? 0.78 : 0.22;
    final point = link.pointAt(t);
    final next = link.pointAt((t + 0.03).clamp(0.0, 1.0));
    final direction = next - point;
    if (direction.distance <= 0) {
      return;
    }
    final angle = math.atan2(direction.dy, direction.dx);
    final size = math.max(4.5, math.min(8, link.strokeWidth + 2));
    final path = Path()
      ..moveTo(
        point.dx + math.cos(angle) * size,
        point.dy + math.sin(angle) * size,
      )
      ..lineTo(
        point.dx + math.cos(angle + 2.55) * size,
        point.dy + math.sin(angle + 2.55) * size,
      )
      ..lineTo(
        point.dx + math.cos(angle - 2.55) * size,
        point.dy + math.sin(angle - 2.55) * size,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: active ? 0.9 : arcOpacity + 0.24)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawNode(
    Canvas canvas,
    _ArcDiagramGeometry geometry,
    _ArcDiagramNodeLayout node,
  ) {
    final active = showActiveItem && activeHit?.node?.key == node.key;
    final color = active
        ? activeColor
        : node.node.color ?? _colorFor(node.index);
    canvas.drawCircle(
      node.center,
      (active ? nodeRadius + 2 : nodeRadius) * progress,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      node.center,
      (active ? nodeRadius + 2 : nodeRadius) * progress,
      Paint()
        ..color = axisColor.withValues(alpha: active ? 0.62 : 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 1.6 : 1,
    );
    if (!showLabels) {
      return;
    }
    final labelWidth = math.min(82.0, math.max(42.0, geometry.nodeGapX + 20));
    _drawText(
      canvas,
      node.node.label,
      Rect.fromCenter(
        center: Offset(node.center.dx, geometry.baseline + 18),
        width: labelWidth,
        height: 15,
      ),
      labelStyle.copyWith(color: color),
      align: TextAlign.center,
    );
    if (showValues && node.resolvedValue > 0) {
      _drawText(
        canvas,
        valueFormatter(node.resolvedValue),
        Rect.fromCenter(
          center: Offset(node.center.dx, geometry.baseline + 33),
          width: labelWidth,
          height: 14,
        ),
        valueStyle.copyWith(color: axisColor),
        align: TextAlign.center,
      );
    }
  }

  Color _colorFor(int index) {
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return linkColor;
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
  bool shouldRepaint(covariant _SimpleArcDiagramPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.links != links ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.nodeColor != nodeColor ||
        oldDelegate.linkColor != linkColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showAxis != showAxis ||
        oldDelegate.showDirection != showDirection ||
        oldDelegate.showActiveItem != showActiveItem ||
        oldDelegate.nodeRadius != nodeRadius ||
        oldDelegate.minArcHeight != minArcHeight ||
        oldDelegate.maxArcHeight != maxArcHeight ||
        oldDelegate.minStrokeWidth != minStrokeWidth ||
        oldDelegate.maxStrokeWidth != maxStrokeWidth ||
        oldDelegate.arcOpacity != arcOpacity ||
        oldDelegate.activeHit != activeHit ||
        oldDelegate.progress != progress;
  }
}

class _ArcDiagramGeometry {
  final Rect plot;
  final double baseline;
  final double nodeGapX;
  final List<_ArcDiagramNodeLayout> nodes;
  final List<_ArcDiagramLinkLayout> links;

  const _ArcDiagramGeometry({
    required this.plot,
    required this.baseline,
    required this.nodeGapX,
    required this.nodes,
    required this.links,
  });

  factory _ArcDiagramGeometry.resolve({
    required List<SimpleArcDiagramNode> nodes,
    required List<SimpleArcDiagramLink> links,
    required Size size,
    required EdgeInsets padding,
    required double nodeRadius,
    required double minArcHeight,
    required double maxArcHeight,
    required double minStrokeWidth,
    required double maxStrokeWidth,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    if (nodes.length < 2 || links.isEmpty || plot.width <= 0) {
      return _ArcDiagramGeometry(
        plot: plot,
        baseline: plot.bottom,
        nodeGapX: 0,
        nodes: const [],
        links: const [],
      );
    }

    final baseline = math.max(plot.top + 40, plot.bottom - 36);
    final gap = nodes.length <= 1 ? 0.0 : plot.width / (nodes.length - 1);
    final totals = <String, double>{for (final node in nodes) node.id: 0};
    final counts = <String, int>{for (final node in nodes) node.id: 0};
    for (final link in links) {
      totals[link.source] = (totals[link.source] ?? 0) + link.value;
      totals[link.target] = (totals[link.target] ?? 0) + link.value;
      counts[link.source] = (counts[link.source] ?? 0) + 1;
      counts[link.target] = (counts[link.target] ?? 0) + 1;
    }
    final nodeLayouts = <_ArcDiagramNodeLayout>[];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      nodeLayouts.add(
        _ArcDiagramNodeLayout(
          key: node.id,
          index: index,
          node: node,
          center: Offset(plot.left + gap * index, baseline),
          resolvedValue: node.value ?? totals[node.id] ?? 0,
          linkCount: counts[node.id] ?? 0,
        ),
      );
    }
    final byId = {for (final layout in nodeLayouts) layout.node.id: layout};
    final maxValue = links.fold<double>(
      0,
      (maxValue, link) => math.max(maxValue, link.value),
    );
    final arcLayouts = <_ArcDiagramLinkLayout>[];
    for (var index = 0; index < links.length; index++) {
      final link = links[index];
      final source = byId[link.source];
      final target = byId[link.target];
      if (source == null || target == null) {
        continue;
      }
      final span = (target.index - source.index).abs();
      final spanRatio = nodes.length <= 1 ? 0.0 : span / (nodes.length - 1);
      final height = math.min(
        math.max(minArcHeight, minArcHeight + maxArcHeight * spanRatio),
        math.max(12.0, baseline - plot.top - 8),
      );
      final normalized = maxValue <= 0 ? 0.0 : link.value / maxValue;
      final strokeWidth =
          minStrokeWidth + (maxStrokeWidth - minStrokeWidth) * normalized;
      final start = source.center;
      final end = target.center;
      final control = Offset((start.dx + end.dx) / 2, baseline - height);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      arcLayouts.add(
        _ArcDiagramLinkLayout(
          key: '$index:${link.source}:${link.target}',
          index: index,
          sourceIndex: source.index,
          targetIndex: target.index,
          link: link,
          start: start,
          control: control,
          end: end,
          strokeWidth: strokeWidth,
          path: path,
          anchor: Offset((start.dx + end.dx) / 2, baseline - height / 2),
        ),
      );
    }

    arcLayouts.sort((a, b) {
      final spanA = (a.targetIndex - a.sourceIndex).abs();
      final spanB = (b.targetIndex - b.sourceIndex).abs();
      final spanCompare = spanB.compareTo(spanA);
      if (spanCompare != 0) return spanCompare;
      return a.link.value.compareTo(b.link.value);
    });

    return _ArcDiagramGeometry(
      plot: plot,
      baseline: baseline,
      nodeGapX: gap,
      nodes: nodeLayouts,
      links: arcLayouts,
    );
  }
}

class _ArcDiagramNodeLayout {
  final String key;
  final int index;
  final SimpleArcDiagramNode node;
  final Offset center;
  final double resolvedValue;
  final int linkCount;

  const _ArcDiagramNodeLayout({
    required this.key,
    required this.index,
    required this.node,
    required this.center,
    required this.resolvedValue,
    required this.linkCount,
  });
}

class _ArcDiagramLinkLayout {
  final String key;
  final int index;
  final int sourceIndex;
  final int targetIndex;
  final SimpleArcDiagramLink link;
  final Offset start;
  final Offset control;
  final Offset end;
  final double strokeWidth;
  final Path path;
  final Offset anchor;

  const _ArcDiagramLinkLayout({
    required this.key,
    required this.index,
    required this.sourceIndex,
    required this.targetIndex,
    required this.link,
    required this.start,
    required this.control,
    required this.end,
    required this.strokeWidth,
    required this.path,
    required this.anchor,
  });

  Offset pointAt(double t) {
    final a = Offset.lerp(start, control, t)!;
    final b = Offset.lerp(control, end, t)!;
    return Offset.lerp(a, b, t)!;
  }

  double distanceTo(Offset position) {
    var best = double.infinity;
    for (var step = 0; step <= 36; step++) {
      final t = step / 36;
      best = math.min(best, (pointAt(t) - position).distance);
    }
    return best;
  }
}

class _ArcDiagramHit {
  final _ArcDiagramNodeLayout? node;
  final _ArcDiagramLinkLayout? link;

  const _ArcDiagramHit({this.node, this.link});

  String get key => node?.key ?? link?.key ?? '';
}

class _SimpleArcDiagramVisuals {
  final Color nodeColor;
  final Color linkColor;
  final Color axisColor;
  final Color activeColor;

  const _SimpleArcDiagramVisuals({
    required this.nodeColor,
    required this.linkColor,
    required this.axisColor,
    required this.activeColor,
  });

  factory _SimpleArcDiagramVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleArcDiagramVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.primary,
          axisColor: colorScheme.outline.withValues(alpha: 0.54),
          activeColor: colorScheme.tertiary,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleArcDiagramVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.primary,
          axisColor: colorScheme.outline.withValues(alpha: 0.72),
          activeColor: colorScheme.onSurface,
        );
      case SimpleBarChartStyle.education:
        return _SimpleArcDiagramVisuals(
          nodeColor: colorScheme.secondary,
          linkColor: colorScheme.secondary,
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleArcDiagramVisuals(
          nodeColor: colorScheme.tertiary,
          linkColor: colorScheme.tertiary,
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleArcDiagramVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.primary,
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
          activeColor: colorScheme.tertiary,
        );
    }
  }
}

class _DefaultArcDiagramTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultArcDiagramTooltip({required this.title, required this.rows});

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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: DefaultTextStyle(
            style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 42, child: Text(row.label)),
                        Flexible(
                          child: Text(
                            row.value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
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

class _TooltipRow {
  final String label;
  final String value;

  const _TooltipRow(this.label, this.value);
}
