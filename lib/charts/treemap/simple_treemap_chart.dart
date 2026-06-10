import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleTreemapValueFormatter = String Function(double value);
typedef SimpleTreemapTapCallback =
    void Function(
      SimpleTreemapData data,
      List<SimpleTreemapData> path,
      double value,
      double share,
    );
typedef SimpleTreemapTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleTreemapData data,
      List<SimpleTreemapData> path,
      String formattedValue,
      String formattedShare,
    );

class SimpleTreemapData {
  final String label;
  final double value;
  final List<SimpleTreemapData> children;
  final Color? color;

  const SimpleTreemapData({
    required this.label,
    this.value = 0,
    this.children = const [],
    this.color,
  });
}

/// A lightweight treemap for hierarchical part-to-whole breakdowns.
class SimpleTreemapChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.all(12);

  final List<SimpleTreemapData> data;
  final SimpleBarChartStyle style;
  final double? totalValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? tileColor;
  final Color? borderColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showParentLabels;
  final bool showTooltip;
  final bool showActiveTile;
  final int maxDepth;
  final double tileGap;
  final double tileRadius;
  final double minLabelArea;
  final SimpleTreemapValueFormatter? valueFormatter;
  final SimpleTreemapValueFormatter? percentFormatter;
  final SimpleTreemapTapCallback? onTileTap;
  final SimpleTreemapTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleTreemapChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.totalValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.tileColor,
    this.borderColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = true,
    this.showParentLabels = true,
    this.showTooltip = true,
    this.showActiveTile = true,
    this.maxDepth = 3,
    this.tileGap = 3,
    this.tileRadius = 6,
    this.minLabelArea = 900,
    this.valueFormatter,
    this.percentFormatter,
    this.onTileTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(totalValue == null || totalValue > 0),
       assert(maxDepth >= 1),
       assert(tileGap >= 0),
       assert(tileRadius >= 0),
       assert(minLabelArea >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleTreemapVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => _nodeValue(item).isFinite && _nodeValue(item) > 0)
        .toList();
    final dataTotal = visibleData.fold<double>(
      0,
      (sum, item) => sum + _nodeValue(item),
    );
    final resolvedTotal = math.max(totalValue ?? dataTotal, dataTotal);
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedPercentFormatter =
        percentFormatter ?? _defaultPercentFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty || resolvedTotal <= 0) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Treemap chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedLabelStyle =
            labelStyle ??
            theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface) ??
            TextStyle(color: colorScheme.onSurface, fontSize: 12);
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleData,
            resolvedTotal,
            formatter,
            resolvedPercentFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleTreemapChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            total: resolvedTotal,
            padding: padding,
            palette: _resolvePalette(colorScheme, visuals.palette),
            tileColor: tileColor ?? visuals.tileColor,
            borderColor: borderColor ?? visuals.borderColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showParentLabels: showParentLabels,
            showTooltip: showTooltip,
            showActiveTile: showActiveTile,
            maxDepth: maxDepth,
            tileGap: tileGap,
            tileRadius: tileRadius,
            minLabelArea: minLabelArea,
            valueFormatter: formatter,
            percentFormatter: resolvedPercentFormatter,
            onTileTap: onTileTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(ColorScheme colorScheme, List<Color> defaults) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    if (tileColor != null) return [tileColor!];
    return defaults;
  }

  String _defaultSemanticLabel(
    List<SimpleTreemapData> visibleData,
    double resolvedTotal,
    SimpleTreemapValueFormatter formatter,
    SimpleTreemapValueFormatter resolvedPercentFormatter,
  ) {
    final leaves = _leafNodes(visibleData);
    final visibleItems = leaves
        .take(6)
        .map((item) {
          final value = _nodeValue(item);
          final share = resolvedTotal == 0 ? 0.0 : value / resolvedTotal;
          return '${item.label} ${formatter(value)}, '
              '${resolvedPercentFormatter(share)}';
        })
        .join(', ');
    final remaining = leaves.length - math.min(leaves.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = leaves.length == 1 ? 'tile' : 'tiles';
    return 'Treemap chart, ${leaves.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static List<SimpleTreemapData> _leafNodes(List<SimpleTreemapData> nodes) {
    final result = <SimpleTreemapData>[];
    for (final node in nodes) {
      final children = node.children
          .where((child) => _nodeValue(child).isFinite && _nodeValue(child) > 0)
          .toList();
      if (children.isEmpty) {
        result.add(node);
      } else {
        result.addAll(_leafNodes(children));
      }
    }
    return result;
  }

  static double _nodeValue(SimpleTreemapData item) {
    final childTotal = item.children.fold<double>(
      0,
      (sum, child) => sum + math.max(0.0, _nodeValue(child)),
    );
    final own = item.value.isFinite ? math.max(0.0, item.value) : 0.0;
    return childTotal > 0 ? math.max(own, childTotal) : own;
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) {
    return '${(value * 100).toStringAsFixed(0)}%';
  }
}

class _SimpleTreemapChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleTreemapData> data;
  final double total;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color tileColor;
  final Color borderColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showParentLabels;
  final bool showTooltip;
  final bool showActiveTile;
  final int maxDepth;
  final double tileGap;
  final double tileRadius;
  final double minLabelArea;
  final SimpleTreemapValueFormatter valueFormatter;
  final SimpleTreemapValueFormatter percentFormatter;
  final SimpleTreemapTapCallback? onTileTap;
  final SimpleTreemapTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleTreemapChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.total,
    required this.padding,
    required this.palette,
    required this.tileColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showParentLabels,
    required this.showTooltip,
    required this.showActiveTile,
    required this.maxDepth,
    required this.tileGap,
    required this.tileRadius,
    required this.minLabelArea,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.onTileTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleTreemapChartView> createState() =>
      _SimpleTreemapChartViewState();
}

class _SimpleTreemapChartViewState extends State<_SimpleTreemapChartView> {
  _TreemapTile? _activeTile;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveTile || widget.onTileTap != null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final chart = TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: widget.animationDuration,
            curve: widget.animationCurve,
            builder: (context, progress, child) {
              return CustomPaint(
                painter: _SimpleTreemapPainter(
                  data: widget.data,
                  total: widget.total,
                  padding: widget.padding,
                  palette: widget.palette,
                  tileColor: widget.tileColor,
                  borderColor: widget.borderColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showLabels: widget.showLabels,
                  showValues: widget.showValues,
                  showParentLabels: widget.showParentLabels,
                  showActiveTile: widget.showActiveTile,
                  maxDepth: widget.maxDepth,
                  tileGap: widget.tileGap,
                  tileRadius: widget.tileRadius,
                  minLabelArea: widget.minLabelArea,
                  valueFormatter: widget.valueFormatter,
                  percentFormatter: widget.percentFormatter,
                  activeTile: _activeTile,
                  progress: progress,
                ),
              );
            },
          );

          if (!interactionEnabled) return chart;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (event) =>
                      _setActive(_hitTest(event.localPosition, size)),
                  onExit: (_) => _setActive(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final tile = _hitTest(details.localPosition, size);
                      _setActive(tile);
                      if (tile != null) {
                        widget.onTileTap?.call(
                          tile.data,
                          tile.path,
                          tile.value,
                          tile.share,
                        );
                      }
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeTile != null)
                _buildTooltip(context, size, _activeTile!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_TreemapTile? tile) {
    if (_activeTile == tile) return;
    setState(() => _activeTile = tile);
  }

  _TreemapTile? _hitTest(Offset position, Size size) {
    final tiles = _resolveTiles(size);
    for (final tile in tiles.reversed) {
      if (tile.rect.contains(position)) return tile;
    }
    return null;
  }

  List<_TreemapTile> _resolveTiles(Size size) {
    final plot = Rect.fromLTWH(
      widget.padding.left,
      widget.padding.top,
      math.max(0.0, size.width - widget.padding.horizontal),
      math.max(0.0, size.height - widget.padding.vertical),
    );
    return _TreemapLayout.resolve(
      data: widget.data,
      total: widget.total,
      rect: plot,
      maxDepth: widget.maxDepth,
      tileGap: widget.tileGap,
    );
  }

  Widget _buildTooltip(BuildContext context, Size size, _TreemapTile tile) {
    final formattedValue = widget.valueFormatter(tile.value);
    final formattedShare = widget.percentFormatter(tile.share);
    const tooltipWidth = 198.0;
    const tooltipHeight = 86.0;
    final anchor = tile.rect.center;
    final left = (anchor.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (anchor.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            tile.data,
            tile.path,
            formattedValue,
            formattedShare,
          ) ??
          _DefaultTreemapTooltip(
            color: _tileColor(tile),
            title: tile.path.map((item) => item.label).join(' / '),
            value: formattedValue,
            share: formattedShare,
          ),
    );
  }

  Color _tileColor(_TreemapTile tile) {
    final explicit = tile.data.color;
    if (explicit != null) return explicit;
    if (widget.palette.isEmpty) return widget.tileColor;
    return widget.palette[tile.rootIndex % widget.palette.length];
  }
}

class _SimpleTreemapPainter extends CustomPainter {
  final List<SimpleTreemapData> data;
  final double total;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color tileColor;
  final Color borderColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showParentLabels;
  final bool showActiveTile;
  final int maxDepth;
  final double tileGap;
  final double tileRadius;
  final double minLabelArea;
  final SimpleTreemapValueFormatter valueFormatter;
  final SimpleTreemapValueFormatter percentFormatter;
  final _TreemapTile? activeTile;
  final double progress;

  const _SimpleTreemapPainter({
    required this.data,
    required this.total,
    required this.padding,
    required this.palette,
    required this.tileColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showParentLabels,
    required this.showActiveTile,
    required this.maxDepth,
    required this.tileGap,
    required this.tileRadius,
    required this.minLabelArea,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.activeTile,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.isEmpty || data.isEmpty || total <= 0) return;

    final tiles = _TreemapLayout.resolve(
      data: data,
      total: total,
      rect: plot,
      maxDepth: maxDepth,
      tileGap: tileGap,
    );
    for (final tile in tiles) {
      _drawTile(canvas, tile, plot);
    }
  }

  void _drawTile(Canvas canvas, _TreemapTile tile, Rect plot) {
    if (tile.rect.width <= 0.5 || tile.rect.height <= 0.5) return;
    final color = _tileColor(tile);
    final selected = activeTile == tile;
    final activeExists = activeTile != null;
    final opacity = activeExists && !selected ? 0.4 : 1.0;
    final baseAlpha = tile.hasChildren ? 0.16 : 0.82;
    final animatedRect = _animatedRect(tile.rect, plot);
    final radius = Radius.circular(
      math.min(tileRadius, animatedRect.shortestSide / 3),
    );
    final rrect = RRect.fromRectAndRadius(animatedRect, radius);

    canvas.drawRRect(
      rrect,
      Paint()..color = color.withValues(alpha: baseAlpha * opacity),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = tile.depth == 0 ? 1.4 : 1,
    );

    if (showActiveTile && selected) {
      canvas.drawRRect(
        rrect.deflate(1),
        Paint()
          ..color = (activeColor ?? color).withValues(alpha: 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }

    final labelAllowed = tile.hasChildren ? showParentLabels : showLabels;
    if (labelAllowed &&
        animatedRect.width * animatedRect.height >= minLabelArea) {
      _drawLabel(canvas, tile, animatedRect, color);
    }
  }

  Rect _animatedRect(Rect rect, Rect plot) {
    final center = rect.center;
    final width = rect.width * progress;
    final height = rect.height * progress;
    final animated = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );
    return animated.intersect(plot);
  }

  void _drawLabel(Canvas canvas, _TreemapTile tile, Rect rect, Color color) {
    final textColor = _textColorFor(color);
    final padded = rect.deflate(math.min(8, rect.shortestSide * 0.12));
    if (padded.width <= 4 || padded.height <= 4) return;
    final label = tile.data.label;
    final value = valueFormatter(tile.value);
    final share = percentFormatter(tile.share);
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: labelStyle.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: math.min(labelStyle.fontSize ?? 12, padded.height * 0.32),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: padded.height > 42 ? 2 : 1,
      ellipsis: '...',
    )..layout(maxWidth: padded.width);
    labelPainter.paint(canvas, padded.topLeft);

    if (!showValues || padded.height < 34) return;
    final valueText = '$value · $share';
    final valuePainter = TextPainter(
      text: TextSpan(
        text: valueText,
        style: valueStyle.copyWith(
          color: textColor.withValues(alpha: 0.86),
          fontSize: math.max(9, (valueStyle.fontSize ?? 11) - 1),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: padded.width);
    valuePainter.paint(
      canvas,
      Offset(padded.left, padded.top + labelPainter.height + 3),
    );
  }

  Color _textColorFor(Color color) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    return brightness == Brightness.dark ? Colors.white : Colors.black87;
  }

  Color _tileColor(_TreemapTile tile) {
    if (tile.data.color != null) return tile.data.color!;
    final base = palette.isEmpty
        ? tileColor
        : palette[tile.rootIndex % palette.length];
    if (tile.depth == 0) return base;
    final blend = tile.depth.isOdd ? Colors.white : Colors.black;
    final amount = tile.depth.isOdd ? 0.12 : 0.08;
    return Color.lerp(base, blend, amount) ?? base;
  }

  @override
  bool shouldRepaint(covariant _SimpleTreemapPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.total != total ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.tileColor != tileColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showParentLabels != showParentLabels ||
        oldDelegate.showActiveTile != showActiveTile ||
        oldDelegate.maxDepth != maxDepth ||
        oldDelegate.tileGap != tileGap ||
        oldDelegate.tileRadius != tileRadius ||
        oldDelegate.minLabelArea != minLabelArea ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.percentFormatter != percentFormatter ||
        oldDelegate.activeTile != activeTile ||
        oldDelegate.progress != progress;
  }
}

class _TreemapLayout {
  static List<_TreemapTile> resolve({
    required List<SimpleTreemapData> data,
    required double total,
    required Rect rect,
    required int maxDepth,
    required double tileGap,
  }) {
    final tiles = <_TreemapTile>[];
    final nodes = data
        .where((item) => SimpleTreemapChart._nodeValue(item) > 0)
        .toList();
    _layoutLevel(
      nodes: nodes,
      rect: rect,
      depth: 0,
      total: total,
      path: const [],
      rootIndex: 0,
      maxDepth: maxDepth,
      tileGap: tileGap,
      tiles: tiles,
    );
    return tiles;
  }

  static void _layoutLevel({
    required List<SimpleTreemapData> nodes,
    required Rect rect,
    required int depth,
    required double total,
    required List<SimpleTreemapData> path,
    required int rootIndex,
    required int maxDepth,
    required double tileGap,
    required List<_TreemapTile> tiles,
  }) {
    if (nodes.isEmpty || rect.width <= 0 || rect.height <= 0) return;
    final values = nodes.map(SimpleTreemapChart._nodeValue).toList();
    final sum = values.fold<double>(0, (current, value) => current + value);
    if (sum <= 0) return;
    final rects = _binaryRects(nodes, values, rect);
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final value = values[index];
      final tilePath = [...path, node];
      final currentRoot = depth == 0 ? index : rootIndex;
      final tile = _TreemapTile(
        data: node,
        path: tilePath,
        rect: _safeDeflate(rects[index], tileGap / 2),
        depth: depth,
        rootIndex: currentRoot,
        value: value,
        share: total == 0 ? 0 : value / total,
        hasChildren: _visibleChildren(node).isNotEmpty,
      );
      tiles.add(tile);
      final children = _visibleChildren(node);
      if (children.isEmpty || depth + 1 >= maxDepth) continue;
      final childRect = _childRect(tile.rect, tileGap);
      if (childRect.width <= 6 || childRect.height <= 6) continue;
      _layoutLevel(
        nodes: children,
        rect: childRect,
        depth: depth + 1,
        total: total,
        path: tilePath,
        rootIndex: currentRoot,
        maxDepth: maxDepth,
        tileGap: tileGap,
        tiles: tiles,
      );
    }
  }

  static List<SimpleTreemapData> _visibleChildren(SimpleTreemapData node) {
    return node.children
        .where((child) => SimpleTreemapChart._nodeValue(child) > 0)
        .toList();
  }

  static Rect _childRect(Rect rect, double tileGap) {
    final gap = math.max(1.0, tileGap);
    final header = rect.height >= 54 ? math.min(22.0, rect.height * 0.22) : gap;
    return Rect.fromLTRB(
      rect.left + gap,
      rect.top + header,
      rect.right - gap,
      rect.bottom - gap,
    );
  }

  static Rect _safeDeflate(Rect rect, double value) {
    if (rect.width <= value * 2 || rect.height <= value * 2) return rect;
    return rect.deflate(value);
  }

  static List<Rect> _binaryRects(
    List<SimpleTreemapData> nodes,
    List<double> values,
    Rect rect,
  ) {
    if (nodes.length == 1) return [rect];
    final indexed = List.generate(nodes.length, (index) => index)
      ..sort((a, b) => values[b].compareTo(values[a]));
    final sortedValues = indexed.map((index) => values[index]).toList();
    final sortedRects = _splitSorted(sortedValues, rect);
    final output = List<Rect>.filled(nodes.length, Rect.zero);
    for (var index = 0; index < indexed.length; index++) {
      output[indexed[index]] = sortedRects[index];
    }
    return output;
  }

  static List<Rect> _splitSorted(List<double> values, Rect rect) {
    if (values.isEmpty) return const [];
    if (values.length == 1) return [rect];
    final sum = values.fold<double>(0, (current, value) => current + value);
    if (sum <= 0) return List<Rect>.filled(values.length, rect);
    var running = 0.0;
    var split = 0;
    for (var index = 0; index < values.length; index++) {
      if (index > 0 &&
          (running + values[index] - sum / 2).abs() >
              (running - sum / 2).abs()) {
        break;
      }
      running += values[index];
      split = index + 1;
    }
    split = split.clamp(1, values.length - 1);
    final firstValues = values.take(split).toList();
    final secondValues = values.skip(split).toList();
    final firstSum = firstValues.fold<double>(0, (a, b) => a + b);
    final ratio = firstSum / sum;
    late Rect firstRect;
    late Rect secondRect;
    if (rect.width >= rect.height) {
      final width = rect.width * ratio;
      firstRect = Rect.fromLTRB(
        rect.left,
        rect.top,
        rect.left + width,
        rect.bottom,
      );
      secondRect = Rect.fromLTRB(
        rect.left + width,
        rect.top,
        rect.right,
        rect.bottom,
      );
    } else {
      final height = rect.height * ratio;
      firstRect = Rect.fromLTRB(
        rect.left,
        rect.top,
        rect.right,
        rect.top + height,
      );
      secondRect = Rect.fromLTRB(
        rect.left,
        rect.top + height,
        rect.right,
        rect.bottom,
      );
    }
    return [
      ..._splitSorted(firstValues, firstRect),
      ..._splitSorted(secondValues, secondRect),
    ];
  }
}

class _TreemapTile {
  final SimpleTreemapData data;
  final List<SimpleTreemapData> path;
  final Rect rect;
  final int depth;
  final int rootIndex;
  final double value;
  final double share;
  final bool hasChildren;

  const _TreemapTile({
    required this.data,
    required this.path,
    required this.rect,
    required this.depth,
    required this.rootIndex,
    required this.value,
    required this.share,
    required this.hasChildren,
  });
}

class _SimpleTreemapVisuals {
  final List<Color> palette;
  final Color tileColor;
  final Color borderColor;

  const _SimpleTreemapVisuals({
    required this.palette,
    required this.tileColor,
    required this.borderColor,
  });

  factory _SimpleTreemapVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleTreemapVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.error,
          ],
          tileColor: colorScheme.primary,
          borderColor: colorScheme.surface,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleTreemapVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.outline,
            colorScheme.tertiary,
          ],
          tileColor: colorScheme.primary,
          borderColor: colorScheme.surface,
        );
      case SimpleBarChartStyle.education:
        return _SimpleTreemapVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            colorScheme.error,
          ],
          tileColor: colorScheme.secondary,
          borderColor: colorScheme.surface,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleTreemapVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.error,
          ],
          tileColor: colorScheme.tertiary,
          borderColor: colorScheme.surface,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleTreemapVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.error,
          ],
          tileColor: colorScheme.primary,
          borderColor: colorScheme.surface,
        );
    }
  }
}

class _DefaultTreemapTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String share;

  const _DefaultTreemapTooltip({
    required this.color,
    required this.title,
    required this.value,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TooltipRow(
              label: 'Value',
              value: value,
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _TooltipRow(
              label: 'Share',
              value: share,
              labelStyle: labelStyle,
              valueStyle: valueStyle?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _TooltipRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
