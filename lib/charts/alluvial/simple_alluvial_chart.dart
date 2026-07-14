import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleAlluvialValueFormatter = String Function(double value);
typedef SimpleAlluvialNodeTapCallback = void Function(SimpleAlluvialNode node);
typedef SimpleAlluvialFlowTapCallback =
    void Function(SimpleAlluvialFlow flow, int index);
typedef SimpleAlluvialTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleAlluvialNode? node,
      SimpleAlluvialFlow? flow,
      int? flowIndex,
      String title,
      String formattedValue,
    );

class SimpleAlluvialFlow {
  final List<String> categories;
  final double value;
  final String? label;
  final Color? color;

  const SimpleAlluvialFlow({
    required this.categories,
    required this.value,
    this.label,
    this.color,
  });
}

class SimpleAlluvialNode {
  final int stageIndex;
  final String stageLabel;
  final String category;
  final double value;
  final int flowCount;
  final Color? color;

  const SimpleAlluvialNode({
    required this.stageIndex,
    required this.stageLabel,
    required this.category,
    required this.value,
    required this.flowCount,
    this.color,
  });
}

/// A simple alluvial chart for multi-stage journeys, cohort transitions,
/// attribution paths, curriculum pathways, and operational flow stories.
class SimpleAlluvialChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(68, 22, 68, 44);

  final List<String> stageLabels;
  final List<SimpleAlluvialFlow> flows;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? nodeColor;
  final Color? ribbonColor;
  final Color? borderColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showStageLabels;
  final bool showNodeLabels;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveItem;
  final double nodeWidth;
  final double nodeGap;
  final double minRibbonWidth;
  final double ribbonOpacity;
  final double curveTension;
  final SimpleAlluvialValueFormatter? valueFormatter;
  final SimpleAlluvialNodeTapCallback? onNodeTap;
  final SimpleAlluvialFlowTapCallback? onFlowTap;
  final SimpleAlluvialTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleAlluvialChart({
    super.key,
    required this.flows,
    this.stageLabels = const [],
    this.style = SimpleBarChartStyle.elegant,
    this.height = 280,
    this.padding = _defaultPadding,
    this.palette,
    this.nodeColor,
    this.ribbonColor,
    this.borderColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showStageLabels = true,
    this.showNodeLabels = true,
    this.showValues = true,
    this.showTooltip = true,
    this.showActiveItem = true,
    this.nodeWidth = 16,
    this.nodeGap = 12,
    this.minRibbonWidth = 1.2,
    this.ribbonOpacity = 0.34,
    this.curveTension = 0.55,
    this.valueFormatter,
    this.onNodeTap,
    this.onFlowTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(nodeWidth > 0),
       assert(nodeGap >= 0),
       assert(minRibbonWidth >= 0),
       assert(ribbonOpacity >= 0 && ribbonOpacity <= 1),
       assert(curveTension >= 0 && curveTension <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleAlluvialVisuals.resolve(style, colorScheme);
    final stageCount = _stageCount(stageLabels, flows);
    final resolvedStageLabels = List<String>.generate(stageCount, (index) {
      if (index < stageLabels.length && stageLabels[index].trim().isNotEmpty) {
        return stageLabels[index].trim();
      }
      return 'Stage ${index + 1}';
    });
    final visibleFlows = flows
        .where(
          (flow) =>
              flow.categories.length >= stageCount &&
              flow.value.isFinite &&
              flow.value > 0 &&
              List.generate(
                stageCount,
                (index) => _categoryAt(flow, index),
              ).every((item) => item.isNotEmpty),
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

        if (stageCount < 2 || visibleFlows.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Alluvial chart, no data.',
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
            resolvedStageLabels,
            visibleFlows,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleAlluvialChartView(
            width: width,
            height: chartHeight,
            stageLabels: resolvedStageLabels,
            flows: visibleFlows,
            padding: padding,
            palette: palette,
            nodeColor: nodeColor ?? visuals.nodeColor,
            ribbonColor: ribbonColor ?? visuals.ribbonColor,
            borderColor: borderColor ?? visuals.borderColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showStageLabels: showStageLabels,
            showNodeLabels: showNodeLabels,
            showValues: showValues,
            showTooltip: showTooltip,
            showActiveItem: showActiveItem,
            nodeWidth: nodeWidth,
            nodeGap: nodeGap,
            minRibbonWidth: minRibbonWidth,
            ribbonOpacity: ribbonOpacity,
            curveTension: curveTension,
            valueFormatter: formatter,
            onNodeTap: onNodeTap,
            onFlowTap: onFlowTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static int _stageCount(
    List<String> stageLabels,
    List<SimpleAlluvialFlow> flows,
  ) {
    if (stageLabels.isNotEmpty) {
      return stageLabels.length;
    }
    var count = 0;
    for (final flow in flows) {
      count = math.max(count, flow.categories.length);
    }
    return count;
  }

  static String _categoryAt(SimpleAlluvialFlow flow, int index) =>
      flow.categories[index].trim();

  static String _flowTitle(SimpleAlluvialFlow flow, int stageCount) {
    if (flow.label != null && flow.label!.trim().isNotEmpty) {
      return flow.label!;
    }
    return List.generate(
      stageCount,
      (index) => _categoryAt(flow, index),
    ).join(' -> ');
  }

  static String _defaultSemanticLabel(
    List<String> stageLabels,
    List<SimpleAlluvialFlow> flows,
    SimpleAlluvialValueFormatter formatter,
  ) {
    final sample = flows
        .take(4)
        .map(
          (flow) =>
              '${_flowTitle(flow, stageLabels.length)} ${formatter(flow.value)}',
        )
        .join(', ');
    final suffix = flows.length > 4 ? ', and ${flows.length - 4} more' : '';
    return 'Alluvial chart, ${stageLabels.length} stages and ${flows.length} '
        'flows. $sample$suffix.';
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

class _SimpleAlluvialChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<String> stageLabels;
  final List<SimpleAlluvialFlow> flows;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color nodeColor;
  final Color ribbonColor;
  final Color borderColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showStageLabels;
  final bool showNodeLabels;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveItem;
  final double nodeWidth;
  final double nodeGap;
  final double minRibbonWidth;
  final double ribbonOpacity;
  final double curveTension;
  final SimpleAlluvialValueFormatter valueFormatter;
  final SimpleAlluvialNodeTapCallback? onNodeTap;
  final SimpleAlluvialFlowTapCallback? onFlowTap;
  final SimpleAlluvialTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleAlluvialChartView({
    required this.width,
    required this.height,
    required this.stageLabels,
    required this.flows,
    required this.padding,
    required this.palette,
    required this.nodeColor,
    required this.ribbonColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showStageLabels,
    required this.showNodeLabels,
    required this.showValues,
    required this.showTooltip,
    required this.showActiveItem,
    required this.nodeWidth,
    required this.nodeGap,
    required this.minRibbonWidth,
    required this.ribbonOpacity,
    required this.curveTension,
    required this.valueFormatter,
    required this.onNodeTap,
    required this.onFlowTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleAlluvialChartView> createState() =>
      _SimpleAlluvialChartViewState();
}

class _SimpleAlluvialChartViewState extends State<_SimpleAlluvialChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _AlluvialHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleAlluvialChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flows != widget.flows ||
        oldWidget.stageLabels != widget.stageLabels ||
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
                        widget.onFlowTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit?.node != null) {
                        widget.onNodeTap?.call(hit!.node!.node);
                      } else if (hit?.segment != null) {
                        widget.onFlowTap?.call(
                          hit!.segment!.flow,
                          hit.segment!.flowIndex,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleAlluvialPainter(
                        stageLabels: widget.stageLabels,
                        flows: widget.flows,
                        padding: widget.padding,
                        palette: widget.palette,
                        nodeColor: widget.nodeColor,
                        ribbonColor: widget.ribbonColor,
                        borderColor: widget.borderColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showStageLabels: widget.showStageLabels,
                        showNodeLabels: widget.showNodeLabels,
                        showValues: widget.showValues,
                        showActiveItem: widget.showActiveItem,
                        nodeWidth: widget.nodeWidth,
                        nodeGap: widget.nodeGap,
                        minRibbonWidth: widget.minRibbonWidth,
                        ribbonOpacity: widget.ribbonOpacity,
                        curveTension: widget.curveTension,
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

  void _setActive(_AlluvialHit? hit) {
    if (_activeHit?.key == hit?.key) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _AlluvialHit? _hitTest(Offset position) {
    final geometry = _AlluvialGeometry.resolve(
      stageLabels: widget.stageLabels,
      flows: widget.flows,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      nodeWidth: widget.nodeWidth,
      nodeGap: widget.nodeGap,
      minRibbonWidth: widget.minRibbonWidth,
      curveTension: widget.curveTension,
    );
    for (final node in geometry.nodes.reversed) {
      if (node.rect.contains(position)) {
        return _AlluvialHit(node: node);
      }
    }
    for (final segment in geometry.segments.reversed) {
      if (segment.path.contains(position)) {
        return _AlluvialHit(segment: segment);
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _AlluvialHit hit) {
    final node = hit.node;
    final segment = hit.segment;
    final flow = segment?.flow;
    final title =
        node?.node.category ??
        (flow == null
            ? ''
            : SimpleAlluvialChart._flowTitle(flow, widget.stageLabels.length));
    final value = node?.node.value ?? flow?.value ?? 0;
    final formattedValue = widget.valueFormatter(value);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          node?.node,
          flow,
          segment?.flowIndex,
          title,
          formattedValue,
        ) ??
        _DefaultAlluvialTooltip(
          title: title,
          rows: [
            if (node != null) _TooltipRow('Stage', node.node.stageLabel),
            if (flow != null)
              _TooltipRow(
                'Path',
                List.generate(
                  widget.stageLabels.length,
                  (index) => SimpleAlluvialChart._categoryAt(flow, index),
                ).join(' -> '),
              ),
            if (node != null)
              _TooltipRow('Flows', node.node.flowCount.toString()),
            _TooltipRow('Value', formattedValue),
          ],
        );
    final anchor = node?.rect.center ?? segment?.center ?? Offset.zero;
    final maxLeft = math.max(8.0, widget.width - 226);
    final maxTop = math.max(8.0, widget.height - 136);
    final left = (anchor.dx + 12).clamp(8.0, maxLeft).toDouble();
    final top = (anchor.dy - 52).clamp(8.0, maxTop).toDouble();
    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleAlluvialPainter extends CustomPainter {
  final List<String> stageLabels;
  final List<SimpleAlluvialFlow> flows;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color nodeColor;
  final Color ribbonColor;
  final Color borderColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showStageLabels;
  final bool showNodeLabels;
  final bool showValues;
  final bool showActiveItem;
  final double nodeWidth;
  final double nodeGap;
  final double minRibbonWidth;
  final double ribbonOpacity;
  final double curveTension;
  final SimpleAlluvialValueFormatter valueFormatter;
  final _AlluvialHit? activeHit;
  final double progress;

  const _SimpleAlluvialPainter({
    required this.stageLabels,
    required this.flows,
    required this.padding,
    required this.palette,
    required this.nodeColor,
    required this.ribbonColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showStageLabels,
    required this.showNodeLabels,
    required this.showValues,
    required this.showActiveItem,
    required this.nodeWidth,
    required this.nodeGap,
    required this.minRibbonWidth,
    required this.ribbonOpacity,
    required this.curveTension,
    required this.valueFormatter,
    required this.activeHit,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _AlluvialGeometry.resolve(
      stageLabels: stageLabels,
      flows: flows,
      size: size,
      padding: padding,
      nodeWidth: nodeWidth,
      nodeGap: nodeGap,
      minRibbonWidth: minRibbonWidth,
      curveTension: curveTension,
    );
    if (geometry.nodes.isEmpty || geometry.segments.isEmpty) {
      return;
    }

    for (final segment in geometry.segments) {
      _drawRibbon(canvas, segment);
    }
    if (showActiveItem && activeHit?.segment != null) {
      for (final segment in geometry.segments.where(
        (item) => item.flowIndex == activeHit!.segment!.flowIndex,
      )) {
        _drawRibbon(canvas, segment, active: true);
      }
    }
    for (final node in geometry.nodes) {
      _drawNode(canvas, geometry, node);
    }
    if (showStageLabels) {
      _drawStageLabels(canvas, geometry);
    }
  }

  void _drawRibbon(
    Canvas canvas,
    _AlluvialSegmentLayout segment, {
    bool active = false,
  }) {
    final color = active
        ? activeColor
        : segment.flow.color ?? _colorForFlow(segment.flowIndex);
    canvas.drawPath(
      segment.path,
      Paint()
        ..color = color.withValues(
          alpha: (active ? 0.68 : ribbonOpacity) * progress,
        )
        ..style = PaintingStyle.fill,
    );
  }

  void _drawNode(
    Canvas canvas,
    _AlluvialGeometry geometry,
    _AlluvialNodeLayout node,
  ) {
    final active = showActiveItem && activeHit?.node?.key == node.key;
    final color = active ? activeColor : node.node.color ?? nodeColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(node.rect, const Radius.circular(4)),
      Paint()
        ..color = color.withValues(alpha: active ? 1 : 0.92)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(node.rect, const Radius.circular(4)),
      Paint()
        ..color = (active ? activeColor : borderColor).withValues(
          alpha: active ? 0.8 : 0.55,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 1.6 : 1,
    );
    if (!showNodeLabels) {
      return;
    }

    final isFirst = node.node.stageIndex == 0;
    final isLast = node.node.stageIndex == stageLabels.length - 1;
    final labelRect = isFirst
        ? Rect.fromLTRB(0, node.rect.top, node.rect.left - 8, node.rect.bottom)
        : isLast
        ? Rect.fromLTRB(
            node.rect.right + 8,
            node.rect.top,
            geometry.size.width,
            node.rect.bottom,
          )
        : Rect.fromCenter(
            center: Offset(node.rect.center.dx, node.rect.center.dy - 7),
            width: math.min(82, math.max(44, geometry.stageGap - nodeWidth)),
            height: 15,
          );
    _drawText(
      canvas,
      node.node.category,
      labelRect,
      labelStyle.copyWith(color: isFirst || isLast ? color : Colors.white),
      align: isFirst
          ? TextAlign.right
          : isLast
          ? TextAlign.left
          : TextAlign.center,
    );
    if (showValues && node.rect.height >= 20) {
      final valueRect = isFirst || isLast
          ? labelRect.translate(0, 13)
          : Rect.fromCenter(
              center: Offset(node.rect.center.dx, node.rect.center.dy + 7),
              width: labelRect.width,
              height: 14,
            );
      _drawText(
        canvas,
        valueFormatter(node.node.value),
        valueRect,
        valueStyle.copyWith(
          color: isFirst || isLast
              ? (valueStyle.color ?? color).withValues(alpha: 0.84)
              : Colors.white.withValues(alpha: 0.9),
        ),
        align: isFirst
            ? TextAlign.right
            : isLast
            ? TextAlign.left
            : TextAlign.center,
      );
    }
  }

  void _drawStageLabels(Canvas canvas, _AlluvialGeometry geometry) {
    for (var index = 0; index < stageLabels.length; index++) {
      final x = geometry.stageX[index];
      _drawText(
        canvas,
        stageLabels[index],
        Rect.fromCenter(
          center: Offset(x, geometry.plot.bottom + 18),
          width: math.min(96, math.max(52, geometry.stageGap + nodeWidth)),
          height: 16,
        ),
        valueStyle.copyWith(color: borderColor, fontWeight: FontWeight.w800),
        align: TextAlign.center,
      );
    }
  }

  Color _colorForFlow(int index) {
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return ribbonColor;
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
  bool shouldRepaint(covariant _SimpleAlluvialPainter oldDelegate) {
    return oldDelegate.stageLabels != stageLabels ||
        oldDelegate.flows != flows ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.nodeColor != nodeColor ||
        oldDelegate.ribbonColor != ribbonColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showStageLabels != showStageLabels ||
        oldDelegate.showNodeLabels != showNodeLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showActiveItem != showActiveItem ||
        oldDelegate.nodeWidth != nodeWidth ||
        oldDelegate.nodeGap != nodeGap ||
        oldDelegate.minRibbonWidth != minRibbonWidth ||
        oldDelegate.ribbonOpacity != ribbonOpacity ||
        oldDelegate.curveTension != curveTension ||
        oldDelegate.activeHit != activeHit ||
        oldDelegate.progress != progress;
  }
}

class _AlluvialGeometry {
  final Size size;
  final Rect plot;
  final List<double> stageX;
  final List<_AlluvialNodeLayout> nodes;
  final List<_AlluvialSegmentLayout> segments;
  final double stageGap;

  const _AlluvialGeometry({
    required this.size,
    required this.plot,
    required this.stageX,
    required this.nodes,
    required this.segments,
    required this.stageGap,
  });

  factory _AlluvialGeometry.resolve({
    required List<String> stageLabels,
    required List<SimpleAlluvialFlow> flows,
    required Size size,
    required EdgeInsets padding,
    required double nodeWidth,
    required double nodeGap,
    required double minRibbonWidth,
    required double curveTension,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    if (stageLabels.length < 2 || flows.isEmpty || plot.width <= 0) {
      return _AlluvialGeometry(
        size: size,
        plot: plot,
        stageX: const [],
        nodes: const [],
        segments: const [],
        stageGap: 0,
      );
    }

    final stageCount = stageLabels.length;
    final stageX = List<double>.generate(stageCount, (index) {
      return stageCount == 1
          ? plot.left
          : plot.left + plot.width * index / (stageCount - 1);
    });
    final accumulators = List.generate(
      stageCount,
      (_) => <String, _AlluvialNodeAccumulator>{},
    );
    for (var flowIndex = 0; flowIndex < flows.length; flowIndex++) {
      final flow = flows[flowIndex];
      for (var stageIndex = 0; stageIndex < stageCount; stageIndex++) {
        final category = SimpleAlluvialChart._categoryAt(flow, stageIndex);
        final accumulator = accumulators[stageIndex].putIfAbsent(
          category,
          () => _AlluvialNodeAccumulator(
            stageIndex: stageIndex,
            category: category,
          ),
        );
        accumulator.add(flow);
      }
    }

    var valueScale = double.infinity;
    for (final stage in accumulators) {
      final total = stage.values.fold<double>(
        0,
        (sum, item) => sum + item.value,
      );
      final available = math.max(
        0.0,
        plot.height - nodeGap * (stage.length - 1),
      );
      if (total > 0) {
        valueScale = math.min(valueScale, available / total);
      }
    }
    if (!valueScale.isFinite || valueScale <= 0) {
      valueScale = 0;
    }

    final nodes = <_AlluvialNodeLayout>[];
    final nodesByKey = <String, _AlluvialNodeLayout>{};
    for (var stageIndex = 0; stageIndex < stageCount; stageIndex++) {
      final stageNodes = accumulators[stageIndex].values.toList()
        ..sort((a, b) {
          final valueCompare = b.value.compareTo(a.value);
          if (valueCompare != 0) return valueCompare;
          return a.category.compareTo(b.category);
        });
      final totalHeight =
          stageNodes.fold<double>(
            0,
            (sum, item) => sum + math.max(2.0, item.value * valueScale),
          ) +
          nodeGap * math.max(0, stageNodes.length - 1);
      var top = plot.top + math.max(0, (plot.height - totalHeight) / 2);
      for (final item in stageNodes) {
        final height = math.max(2.0, item.value * valueScale);
        final rect = Rect.fromLTWH(
          stageX[stageIndex] - nodeWidth / 2,
          top,
          nodeWidth,
          height,
        );
        final node = SimpleAlluvialNode(
          stageIndex: stageIndex,
          stageLabel: stageLabels[stageIndex],
          category: item.category,
          value: item.value,
          flowCount: item.flowCount,
          color: _sharedColor(item.flows),
        );
        final layout = _AlluvialNodeLayout(
          key: _nodeKey(stageIndex, item.category),
          node: node,
          rect: rect,
        );
        nodes.add(layout);
        nodesByKey[layout.key] = layout;
        top += height + nodeGap;
      }
    }

    final cursors = {for (final node in nodes) node.key: node.rect.top};
    final segments = <_AlluvialSegmentLayout>[];
    for (var pairIndex = 0; pairIndex < stageCount - 1; pairIndex++) {
      for (var flowIndex = 0; flowIndex < flows.length; flowIndex++) {
        final flow = flows[flowIndex];
        final sourceKey = _nodeKey(
          pairIndex,
          SimpleAlluvialChart._categoryAt(flow, pairIndex),
        );
        final targetKey = _nodeKey(
          pairIndex + 1,
          SimpleAlluvialChart._categoryAt(flow, pairIndex + 1),
        );
        final source = nodesByKey[sourceKey];
        final target = nodesByKey[targetKey];
        if (source == null || target == null) {
          continue;
        }
        final ribbonHeight = math.max(minRibbonWidth, flow.value * valueScale);
        final sourceTop = cursors[sourceKey] ?? source.rect.top;
        final targetTop = cursors[targetKey] ?? target.rect.top;
        final sourceCenter = sourceTop + ribbonHeight / 2;
        final targetCenter = targetTop + ribbonHeight / 2;
        cursors[sourceKey] = sourceTop + ribbonHeight;
        cursors[targetKey] = targetTop + ribbonHeight;
        final path = _ribbonPath(
          source.rect.right,
          sourceCenter,
          target.rect.left,
          targetCenter,
          ribbonHeight,
          curveTension,
        );
        segments.add(
          _AlluvialSegmentLayout(
            key: '$flowIndex:$pairIndex',
            flowIndex: flowIndex,
            pairIndex: pairIndex,
            flow: flow,
            path: path,
            center: Offset(
              (source.rect.right + target.rect.left) / 2,
              (sourceCenter + targetCenter) / 2,
            ),
          ),
        );
      }
    }

    return _AlluvialGeometry(
      size: size,
      plot: plot,
      stageX: stageX,
      nodes: nodes,
      segments: segments,
      stageGap: stageCount <= 1 ? 0 : plot.width / (stageCount - 1),
    );
  }

  static String _nodeKey(int stageIndex, String category) =>
      '$stageIndex::$category';

  static Path _ribbonPath(
    double x0,
    double y0,
    double x1,
    double y1,
    double height,
    double tension,
  ) {
    final top0 = y0 - height / 2;
    final bottom0 = y0 + height / 2;
    final top1 = y1 - height / 2;
    final bottom1 = y1 + height / 2;
    final dx = x1 - x0;
    final c0 = x0 + dx * tension;
    final c1 = x1 - dx * tension;
    return Path()
      ..moveTo(x0, top0)
      ..cubicTo(c0, top0, c1, top1, x1, top1)
      ..lineTo(x1, bottom1)
      ..cubicTo(c1, bottom1, c0, bottom0, x0, bottom0)
      ..close();
  }

  static Color? _sharedColor(List<SimpleAlluvialFlow> flows) {
    Color? color;
    for (final flow in flows) {
      if (flow.color == null) {
        continue;
      }
      color ??= flow.color;
      if (color != flow.color) {
        return null;
      }
    }
    return color;
  }
}

class _AlluvialNodeAccumulator {
  final int stageIndex;
  final String category;
  final List<SimpleAlluvialFlow> flows = [];
  double value = 0;

  _AlluvialNodeAccumulator({required this.stageIndex, required this.category});

  int get flowCount => flows.length;

  void add(SimpleAlluvialFlow flow) {
    flows.add(flow);
    value += flow.value;
  }
}

class _AlluvialNodeLayout {
  final String key;
  final SimpleAlluvialNode node;
  final Rect rect;

  const _AlluvialNodeLayout({
    required this.key,
    required this.node,
    required this.rect,
  });
}

class _AlluvialSegmentLayout {
  final String key;
  final int flowIndex;
  final int pairIndex;
  final SimpleAlluvialFlow flow;
  final Path path;
  final Offset center;

  const _AlluvialSegmentLayout({
    required this.key,
    required this.flowIndex,
    required this.pairIndex,
    required this.flow,
    required this.path,
    required this.center,
  });
}

class _AlluvialHit {
  final _AlluvialNodeLayout? node;
  final _AlluvialSegmentLayout? segment;

  const _AlluvialHit({this.node, this.segment});

  String get key => node?.key ?? segment?.key ?? '';
}

class _SimpleAlluvialVisuals {
  final Color nodeColor;
  final Color ribbonColor;
  final Color borderColor;
  final Color activeColor;

  const _SimpleAlluvialVisuals({
    required this.nodeColor,
    required this.ribbonColor,
    required this.borderColor,
    required this.activeColor,
  });

  factory _SimpleAlluvialVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleAlluvialVisuals(
          nodeColor: colorScheme.primary,
          ribbonColor: colorScheme.primary,
          borderColor: colorScheme.outline.withValues(alpha: 0.42),
          activeColor: colorScheme.tertiary,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleAlluvialVisuals(
          nodeColor: colorScheme.primary,
          ribbonColor: colorScheme.primary,
          borderColor: colorScheme.outline.withValues(alpha: 0.58),
          activeColor: colorScheme.onSurface,
        );
      case SimpleBarChartStyle.education:
        return _SimpleAlluvialVisuals(
          nodeColor: colorScheme.secondary,
          ribbonColor: colorScheme.secondary,
          borderColor: colorScheme.outline.withValues(alpha: 0.48),
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleAlluvialVisuals(
          nodeColor: colorScheme.tertiary,
          ribbonColor: colorScheme.tertiary,
          borderColor: colorScheme.outline.withValues(alpha: 0.36),
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleAlluvialVisuals(
          nodeColor: colorScheme.primary,
          ribbonColor: colorScheme.primary,
          borderColor: colorScheme.outline.withValues(alpha: 0.48),
          activeColor: colorScheme.tertiary,
        );
    }
  }
}

class _DefaultAlluvialTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultAlluvialTooltip({required this.title, required this.rows});

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
                        SizedBox(width: 44, child: Text(row.label)),
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
