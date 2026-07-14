import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleChordValueFormatter = String Function(double value);
typedef SimpleChordNodeTapCallback =
    void Function(SimpleChordNode node, double value);
typedef SimpleChordLinkTapCallback =
    void Function(SimpleChordLink link, double value);
typedef SimpleChordTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleChordNode? node,
      SimpleChordLink? link,
      String title,
      String formattedValue,
    );

class SimpleChordNode {
  final String id;
  final String label;
  final Color? color;

  const SimpleChordNode({required this.id, required this.label, this.color});
}

class SimpleChordLink {
  final String source;
  final String target;
  final double value;
  final String? label;
  final Color? color;

  const SimpleChordLink({
    required this.source,
    required this.target,
    required this.value,
    this.label,
    this.color,
  });
}

/// A compact chord chart for relationship strength, migration, referrals,
/// co-occurrence, transfers, and network-style flow between categories.
class SimpleChordChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(24, 22, 24, 22);

  final List<SimpleChordNode> nodes;
  final List<SimpleChordLink> links;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? nodeColor;
  final Color? linkColor;
  final Color? activeColor;
  final Color? labelColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveItem;
  final double arcWidth;
  final double gapAngle;
  final double minLinkWidth;
  final double maxLinkWidth;
  final double linkOpacity;
  final SimpleChordValueFormatter? valueFormatter;
  final SimpleChordNodeTapCallback? onNodeTap;
  final SimpleChordLinkTapCallback? onLinkTap;
  final SimpleChordTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleChordChart({
    super.key,
    this.nodes = const [],
    required this.links,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 280,
    this.padding = _defaultPadding,
    this.palette,
    this.nodeColor,
    this.linkColor,
    this.activeColor,
    this.labelColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = true,
    this.showTooltip = true,
    this.showActiveItem = true,
    this.arcWidth = 14,
    this.gapAngle = 0.035,
    this.minLinkWidth = 2.2,
    this.maxLinkWidth = 18,
    this.linkOpacity = 0.32,
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
       assert(arcWidth > 0),
       assert(gapAngle >= 0),
       assert(minLinkWidth >= 0),
       assert(maxLinkWidth >= minLinkWidth),
       assert(linkOpacity >= 0 && linkOpacity <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleChordVisuals.resolve(style, colorScheme);
    final visibleLinks = links
        .where(
          (link) =>
              link.source.trim().isNotEmpty &&
              link.target.trim().isNotEmpty &&
              link.source != link.target &&
              link.value.isFinite &&
              link.value > 0,
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

        if (visibleLinks.isEmpty || resolvedNodes.length < 2) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Chord chart, no data.',
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
              color: labelColor ?? colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: labelColor ?? colorScheme.onSurface,
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
          child: _SimpleChordChartView(
            width: width,
            height: chartHeight,
            nodes: resolvedNodes,
            links: visibleLinks,
            padding: padding,
            palette: palette,
            nodeColor: nodeColor ?? visuals.nodeColor,
            linkColor: linkColor ?? visuals.linkColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showTooltip: showTooltip,
            showActiveItem: showActiveItem,
            arcWidth: arcWidth,
            gapAngle: gapAngle,
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

  static List<SimpleChordNode> _resolveNodes(
    List<SimpleChordNode> nodes,
    List<SimpleChordLink> links,
  ) {
    final byId = <String, SimpleChordNode>{
      for (final node in nodes)
        if (node.id.trim().isNotEmpty) node.id: node,
    };
    final result = <SimpleChordNode>[];
    final seen = <String>{};

    void add(String id) {
      if (!seen.add(id)) {
        return;
      }
      final node = byId[id];
      result.add(
        node ?? SimpleChordNode(id: id, label: _titleCaseIdentifier(id)),
      );
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

  static String _titleCaseIdentifier(String value) {
    final normalized = value.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (normalized.isEmpty) return value;
    return normalized
        .split(RegExp(r'\s+'))
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  static String _defaultSemanticLabel(
    List<SimpleChordNode> nodes,
    List<SimpleChordLink> links,
    SimpleChordValueFormatter formatter,
  ) {
    final sample = links
        .take(5)
        .map(
          (link) =>
              '${link.source} to ${link.target} '
              '${formatter(link.value)}',
        )
        .join(', ');
    final suffix = links.length > 5 ? ', and ${links.length - 5} more' : '';
    return 'Chord chart, ${nodes.length} nodes and ${links.length} links. '
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

class _SimpleChordChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleChordNode> nodes;
  final List<SimpleChordLink> links;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color nodeColor;
  final Color linkColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveItem;
  final double arcWidth;
  final double gapAngle;
  final double minLinkWidth;
  final double maxLinkWidth;
  final double linkOpacity;
  final SimpleChordValueFormatter valueFormatter;
  final SimpleChordNodeTapCallback? onNodeTap;
  final SimpleChordLinkTapCallback? onLinkTap;
  final SimpleChordTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleChordChartView({
    required this.width,
    required this.height,
    required this.nodes,
    required this.links,
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
    required this.showActiveItem,
    required this.arcWidth,
    required this.gapAngle,
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
  State<_SimpleChordChartView> createState() => _SimpleChordChartViewState();
}

class _SimpleChordChartViewState extends State<_SimpleChordChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _ChordHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleChordChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.links != widget.links ||
        oldWidget.nodes != widget.nodes ||
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
                      if (hit == null) {
                        return;
                      }
                      if (hit.node != null) {
                        widget.onNodeTap?.call(hit.node!.node, hit.node!.value);
                      } else if (hit.link != null) {
                        widget.onLinkTap?.call(hit.link!.link, hit.link!.value);
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleChordPainter(
                        nodes: widget.nodes,
                        links: widget.links,
                        padding: widget.padding,
                        palette: widget.palette,
                        nodeColor: widget.nodeColor,
                        linkColor: widget.linkColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showActiveItem: widget.showActiveItem,
                        arcWidth: widget.arcWidth,
                        gapAngle: widget.gapAngle,
                        minLinkWidth: widget.minLinkWidth,
                        maxLinkWidth: widget.maxLinkWidth,
                        linkOpacity: widget.linkOpacity,
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

  void _setActive(_ChordHit? hit) {
    if (_activeHit?.node?.index == hit?.node?.index &&
        _activeHit?.link?.index == hit?.link?.index) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _ChordHit? _hitTest(Offset position) {
    final geometry = _ChordGeometry.resolve(
      nodes: widget.nodes,
      links: widget.links,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      gapAngle: widget.gapAngle,
      arcWidth: widget.arcWidth,
      minLinkWidth: widget.minLinkWidth,
      maxLinkWidth: widget.maxLinkWidth,
    );

    for (final node in geometry.nodes) {
      if (_pointInNode(position, geometry, node)) {
        return _ChordHit(node: node);
      }
    }
    for (final link in geometry.links.reversed) {
      if (link.hitRect.contains(position) ||
          _distanceToSegment(position, link.startPoint, link.endPoint) <=
              link.width + 10) {
        return _ChordHit(link: link);
      }
    }
    return null;
  }

  bool _pointInNode(
    Offset position,
    _ChordGeometry geometry,
    _ChordNodeLayout node,
  ) {
    final vector = position - geometry.center;
    final distance = vector.distance;
    if (distance < geometry.radius - widget.arcWidth - 8 ||
        distance > geometry.radius + 10) {
      return false;
    }
    var angle = math.atan2(vector.dy, vector.dx);
    while (angle < -math.pi / 2) {
      angle += math.pi * 2;
    }
    return angle >= node.startAngle && angle <= node.endAngle;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared <= 0) {
      return (point - start).distance;
    }
    final t =
        ((point.dx - start.dx) * segment.dx +
            (point.dy - start.dy) * segment.dy) /
        lengthSquared;
    final clamped = t.clamp(0.0, 1.0);
    final projection = Offset(
      start.dx + segment.dx * clamped,
      start.dy + segment.dy * clamped,
    );
    return (point - projection).distance;
  }

  Widget _buildTooltip(BuildContext context, _ChordHit hit) {
    final node = hit.node;
    final link = hit.link;
    final title = node != null
        ? node.node.label
        : link?.link.label ??
              '${link?.source.node.label ?? ''} to ${link?.target.node.label ?? ''}';
    final value = node?.value ?? link?.value ?? 0;
    final formattedValue = widget.valueFormatter(value);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          node?.node,
          link?.link,
          title,
          formattedValue,
        ) ??
        _DefaultChordTooltip(
          title: title,
          rows: [
            if (link != null) _TooltipRow('From', link.source.node.label),
            if (link != null) _TooltipRow('To', link.target.node.label),
            _TooltipRow(node != null ? 'Total' : 'Value', formattedValue),
          ],
        );
    final anchor = node?.labelAnchor ?? link?.center ?? Offset.zero;
    final left = (anchor.dx + 12).clamp(8.0, widget.width - 206);
    final top = (anchor.dy - 50).clamp(8.0, widget.height - 118);
    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleChordPainter extends CustomPainter {
  final List<SimpleChordNode> nodes;
  final List<SimpleChordLink> links;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color nodeColor;
  final Color linkColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showActiveItem;
  final double arcWidth;
  final double gapAngle;
  final double minLinkWidth;
  final double maxLinkWidth;
  final double linkOpacity;
  final SimpleChordValueFormatter valueFormatter;
  final _ChordHit? activeHit;
  final double progress;

  const _SimpleChordPainter({
    required this.nodes,
    required this.links,
    required this.padding,
    required this.palette,
    required this.nodeColor,
    required this.linkColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showActiveItem,
    required this.arcWidth,
    required this.gapAngle,
    required this.minLinkWidth,
    required this.maxLinkWidth,
    required this.linkOpacity,
    required this.valueFormatter,
    required this.activeHit,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _ChordGeometry.resolve(
      nodes: nodes,
      links: links,
      size: size,
      padding: padding,
      gapAngle: gapAngle,
      arcWidth: arcWidth,
      minLinkWidth: minLinkWidth,
      maxLinkWidth: maxLinkWidth,
    );
    if (geometry.nodes.isEmpty || geometry.radius <= 0) {
      return;
    }

    for (final link in geometry.links) {
      _drawLink(canvas, geometry, link);
    }
    for (final node in geometry.nodes) {
      _drawNode(canvas, geometry, node);
    }
    if (showLabels && geometry.radius > 54) {
      _drawLabels(canvas, geometry);
    }
  }

  void _drawLink(
    Canvas canvas,
    _ChordGeometry geometry,
    _ChordLinkLayout link,
  ) {
    final active = showActiveItem && activeHit?.link?.index == link.index;
    final incidentActive =
        showActiveItem &&
        activeHit?.node != null &&
        (activeHit!.node!.index == link.source.index ||
            activeHit!.node!.index == link.target.index);
    final color = active
        ? activeColor
        : link.link.color ??
              link.source.node.color ??
              _colorFor(link.source.index).withValues(alpha: 1);
    final path = Path()
      ..moveTo(link.startPoint.dx, link.startPoint.dy)
      ..cubicTo(
        geometry.center.dx,
        geometry.center.dy,
        geometry.center.dx,
        geometry.center.dy,
        link.endPoint.dx,
        link.endPoint.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(
          alpha:
              (active
                  ? 0.66
                  : incidentActive
                  ? 0.48
                  : linkOpacity) *
              progress,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = link.width * progress
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawNode(
    Canvas canvas,
    _ChordGeometry geometry,
    _ChordNodeLayout node,
  ) {
    final active = showActiveItem && activeHit?.node?.index == node.index;
    final color = active ? activeColor : _colorFor(node.index);
    final rect = Rect.fromCircle(
      center: geometry.center,
      radius: geometry.radius - arcWidth / 2,
    );
    canvas.drawArc(
      rect,
      node.startAngle,
      node.sweep * progress,
      false,
      Paint()
        ..color = color.withValues(alpha: active ? 1 : 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawLabels(Canvas canvas, _ChordGeometry geometry) {
    if (geometry.plot.width < 150) {
      return;
    }
    for (final node in geometry.nodes) {
      final color = _colorFor(node.index);
      _drawText(
        canvas,
        node.node.label,
        Rect.fromCenter(
          center: node.labelAnchor,
          width: math.min(86, geometry.plot.width / 2),
          height: 16,
        ),
        labelStyle.copyWith(color: color),
        align: TextAlign.center,
      );
      if (showValues && geometry.radius > 76) {
        _drawText(
          canvas,
          valueFormatter(node.value),
          Rect.fromCenter(
            center: node.labelAnchor + const Offset(0, 14),
            width: math.min(72, geometry.plot.width / 2),
            height: 14,
          ),
          valueStyle.copyWith(color: color.withValues(alpha: 0.86)),
          align: TextAlign.center,
        );
      }
    }
  }

  Color _colorFor(int index) {
    final node = nodes[index];
    if (node.color != null) {
      return node.color!;
    }
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return nodeColor == linkColor ? nodeColor : nodeColor;
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
  bool shouldRepaint(covariant _SimpleChordPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.links != links ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.nodeColor != nodeColor ||
        oldDelegate.linkColor != linkColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showActiveItem != showActiveItem ||
        oldDelegate.arcWidth != arcWidth ||
        oldDelegate.gapAngle != gapAngle ||
        oldDelegate.minLinkWidth != minLinkWidth ||
        oldDelegate.maxLinkWidth != maxLinkWidth ||
        oldDelegate.linkOpacity != linkOpacity ||
        oldDelegate.activeHit != activeHit ||
        oldDelegate.progress != progress;
  }
}

class _ChordGeometry {
  final Rect plot;
  final Offset center;
  final double radius;
  final List<_ChordNodeLayout> nodes;
  final List<_ChordLinkLayout> links;

  const _ChordGeometry({
    required this.plot,
    required this.center,
    required this.radius,
    required this.nodes,
    required this.links,
  });

  factory _ChordGeometry.resolve({
    required List<SimpleChordNode> nodes,
    required List<SimpleChordLink> links,
    required Size size,
    required EdgeInsets padding,
    required double gapAngle,
    required double arcWidth,
    required double minLinkWidth,
    required double maxLinkWidth,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final center = plot.center;
    final radius = math
        .max(0.0, math.min(plot.width, plot.height) / 2 - 18)
        .toDouble();
    if (nodes.length < 2 || links.isEmpty || radius <= 0) {
      return _ChordGeometry(
        plot: plot,
        center: center,
        radius: radius,
        nodes: const [],
        links: const [],
      );
    }

    final totals = <String, double>{for (final node in nodes) node.id: 0};
    for (final link in links) {
      totals[link.source] = (totals[link.source] ?? 0) + link.value;
      totals[link.target] = (totals[link.target] ?? 0) + link.value;
    }
    final total = totals.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return _ChordGeometry(
        plot: plot,
        center: center,
        radius: radius,
        nodes: const [],
        links: const [],
      );
    }

    final maxGap = math.pi * 2 / nodes.length * 0.35;
    final resolvedGap = gapAngle.clamp(0.0, maxGap).toDouble();
    final usableAngle = math.pi * 2 - resolvedGap * nodes.length;
    var cursor = -math.pi / 2;
    final nodeLayouts = <_ChordNodeLayout>[];
    final byId = <String, _ChordNodeLayout>{};
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final value = totals[node.id] ?? 0;
      final sweep = value <= 0 ? 0.0 : usableAngle * value / total;
      final midAngle = cursor + sweep / 2;
      final layout = _ChordNodeLayout(
        index: index,
        node: node,
        value: value,
        startAngle: cursor,
        endAngle: cursor + sweep,
        sweep: sweep,
        labelAnchor:
            center +
            Offset(math.cos(midAngle), math.sin(midAngle)) *
                (radius + arcWidth + 18),
      );
      nodeLayouts.add(layout);
      byId[node.id] = layout;
      cursor += sweep + resolvedGap;
    }

    final cursors = <String, double>{
      for (final node in nodeLayouts) node.node.id: node.startAngle,
    };
    final maxValue = links.fold<double>(
      0,
      (maxValue, link) => math.max(maxValue, link.value),
    );
    final linkLayouts = <_ChordLinkLayout>[];
    for (var index = 0; index < links.length; index++) {
      final link = links[index];
      final source = byId[link.source];
      final target = byId[link.target];
      if (source == null || target == null) {
        continue;
      }
      final sourceSpan = _reserveSpan(cursors, source, link.value);
      final targetSpan = _reserveSpan(cursors, target, link.value);
      final sourceAngle = (sourceSpan.start + sourceSpan.end) / 2;
      final targetAngle = (targetSpan.start + targetSpan.end) / 2;
      final linkRadius = math.max(0.0, radius - arcWidth - 8).toDouble();
      final startPoint =
          center +
          Offset(math.cos(sourceAngle), math.sin(sourceAngle)) * linkRadius;
      final endPoint =
          center +
          Offset(math.cos(targetAngle), math.sin(targetAngle)) * linkRadius;
      final width = maxValue <= 0
          ? minLinkWidth
          : minLinkWidth +
                (maxLinkWidth - minLinkWidth) *
                    math.sqrt(link.value / maxValue).clamp(0.0, 1.0).toDouble();
      final hitRect = Rect.fromPoints(startPoint, endPoint)
          .expandToInclude(Rect.fromCircle(center: center, radius: 2))
          .inflate(width + 12);
      linkLayouts.add(
        _ChordLinkLayout(
          index: index,
          link: link,
          value: link.value,
          source: source,
          target: target,
          sourceSpan: sourceSpan,
          targetSpan: targetSpan,
          startPoint: startPoint,
          endPoint: endPoint,
          center: Offset.lerp(startPoint, endPoint, 0.5)!,
          width: width,
          hitRect: hitRect,
        ),
      );
    }

    return _ChordGeometry(
      plot: plot,
      center: center,
      radius: radius,
      nodes: nodeLayouts,
      links: linkLayouts,
    );
  }

  static _AngleSpan _reserveSpan(
    Map<String, double> cursors,
    _ChordNodeLayout node,
    double value,
  ) {
    final start = cursors[node.node.id] ?? node.startAngle;
    final span = node.value <= 0 ? 0.0 : node.sweep * value / node.value;
    final end = start + span;
    cursors[node.node.id] = end;
    return _AngleSpan(start, end);
  }
}

class _ChordNodeLayout {
  final int index;
  final SimpleChordNode node;
  final double value;
  final double startAngle;
  final double endAngle;
  final double sweep;
  final Offset labelAnchor;

  const _ChordNodeLayout({
    required this.index,
    required this.node,
    required this.value,
    required this.startAngle,
    required this.endAngle,
    required this.sweep,
    required this.labelAnchor,
  });
}

class _ChordLinkLayout {
  final int index;
  final SimpleChordLink link;
  final double value;
  final _ChordNodeLayout source;
  final _ChordNodeLayout target;
  final _AngleSpan sourceSpan;
  final _AngleSpan targetSpan;
  final Offset startPoint;
  final Offset endPoint;
  final Offset center;
  final double width;
  final Rect hitRect;

  const _ChordLinkLayout({
    required this.index,
    required this.link,
    required this.value,
    required this.source,
    required this.target,
    required this.sourceSpan,
    required this.targetSpan,
    required this.startPoint,
    required this.endPoint,
    required this.center,
    required this.width,
    required this.hitRect,
  });
}

class _AngleSpan {
  final double start;
  final double end;

  const _AngleSpan(this.start, this.end);
}

class _ChordHit {
  final _ChordNodeLayout? node;
  final _ChordLinkLayout? link;

  const _ChordHit({this.node, this.link});
}

class _SimpleChordVisuals {
  final Color nodeColor;
  final Color linkColor;
  final Color activeColor;

  const _SimpleChordVisuals({
    required this.nodeColor,
    required this.linkColor,
    required this.activeColor,
  });

  factory _SimpleChordVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleChordVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.primary,
          activeColor: colorScheme.tertiary,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleChordVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.outline,
          activeColor: colorScheme.onSurface,
        );
      case SimpleBarChartStyle.education:
        return _SimpleChordVisuals(
          nodeColor: colorScheme.secondary,
          linkColor: colorScheme.secondary,
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleChordVisuals(
          nodeColor: colorScheme.tertiary,
          linkColor: colorScheme.tertiary,
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleChordVisuals(
          nodeColor: colorScheme.primary,
          linkColor: colorScheme.primary,
          activeColor: colorScheme.tertiary,
        );
    }
  }
}

class _DefaultChordTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultChordTooltip({required this.title, required this.rows});

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
        constraints: const BoxConstraints(maxWidth: 220),
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
                        SizedBox(width: 38, child: Text(row.label)),
                        Flexible(
                          child: Text(
                            row.value,
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
