import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleIcicleValueFormatter = String Function(double value);
typedef SimpleIcicleTapCallback =
    void Function(
      SimpleIcicleData data,
      List<SimpleIcicleData> path,
      double value,
      double share,
    );
typedef SimpleIcicleTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleIcicleData data,
      List<SimpleIcicleData> path,
      String formattedValue,
      String formattedShare,
    );

enum SimpleIcicleOrientation { vertical, horizontal }

class SimpleIcicleData {
  final String label;
  final double value;
  final List<SimpleIcicleData> children;
  final Color? color;

  const SimpleIcicleData({
    required this.label,
    this.value = 0,
    this.children = const [],
    this.color,
  });
}

/// A compact rectangular hierarchy chart where each depth is shown as a band.
/// Useful for portfolios, taxonomies, curriculum maps, cost trees, and
/// product or system architecture.
class SimpleIcicleChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.all(12);

  final List<SimpleIcicleData> data;
  final SimpleIcicleOrientation orientation;
  final SimpleBarChartStyle style;
  final double? totalValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? segmentColor;
  final Color? borderColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showParentLabels;
  final bool showTooltip;
  final bool showActiveSegment;
  final int maxDepth;
  final double segmentGap;
  final double segmentRadius;
  final double minLabelArea;
  final SimpleIcicleValueFormatter? valueFormatter;
  final SimpleIcicleValueFormatter? percentFormatter;
  final SimpleIcicleTapCallback? onSegmentTap;
  final SimpleIcicleTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleIcicleChart({
    super.key,
    required this.data,
    this.orientation = SimpleIcicleOrientation.vertical,
    this.style = SimpleBarChartStyle.elegant,
    this.totalValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.segmentColor,
    this.borderColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = true,
    this.showParentLabels = true,
    this.showTooltip = true,
    this.showActiveSegment = true,
    this.maxDepth = 4,
    this.segmentGap = 2,
    this.segmentRadius = 5,
    this.minLabelArea = 720,
    this.valueFormatter,
    this.percentFormatter,
    this.onSegmentTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(totalValue == null || totalValue > 0),
       assert(maxDepth >= 1),
       assert(segmentGap >= 0),
       assert(segmentRadius >= 0),
       assert(minLabelArea >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleIcicleVisuals.resolve(style, colorScheme);
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
            emptySemanticLabel: 'Icicle chart, no data.',
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
          child: _SimpleIcicleChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            total: resolvedTotal,
            orientation: orientation,
            padding: padding,
            palette: palette ?? visuals.palette,
            segmentColor: segmentColor ?? visuals.segmentColor,
            borderColor: borderColor ?? visuals.borderColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showParentLabels: showParentLabels,
            showTooltip: showTooltip,
            showActiveSegment: showActiveSegment,
            maxDepth: maxDepth,
            segmentGap: segmentGap,
            segmentRadius: segmentRadius,
            minLabelArea: minLabelArea,
            valueFormatter: formatter,
            percentFormatter: resolvedPercentFormatter,
            onSegmentTap: onSegmentTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static double _nodeValue(SimpleIcicleData item) {
    final childValue = item.children.fold<double>(
      0,
      (sum, child) => sum + _nodeValue(child),
    );
    if (item.value.isFinite && item.value > 0) {
      return math.max(item.value, childValue);
    }
    return childValue;
  }

  static String _defaultSemanticLabel(
    List<SimpleIcicleData> data,
    double total,
    SimpleIcicleValueFormatter formatter,
    SimpleIcicleValueFormatter percentFormatter,
  ) {
    final segments = _leafNodes(data);
    final sample = segments
        .take(6)
        .map((item) {
          final value = _nodeValue(item);
          final share = total <= 0 ? 0.0 : value / total * 100;
          return '${item.label} ${formatter(value)}, '
              '${percentFormatter(share)}';
        })
        .join(', ');
    final suffix = segments.length > 6
        ? ', and ${segments.length - 6} more'
        : '';
    return 'Icicle chart, ${segments.length} segments. $sample$suffix.';
  }

  static List<SimpleIcicleData> _leafNodes(List<SimpleIcicleData> nodes) {
    final result = <SimpleIcicleData>[];
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

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) =>
      '${value.toStringAsFixed(0)}%';
}

class _SimpleIcicleChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleIcicleData> data;
  final double total;
  final SimpleIcicleOrientation orientation;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color segmentColor;
  final Color borderColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showParentLabels;
  final bool showTooltip;
  final bool showActiveSegment;
  final int maxDepth;
  final double segmentGap;
  final double segmentRadius;
  final double minLabelArea;
  final SimpleIcicleValueFormatter valueFormatter;
  final SimpleIcicleValueFormatter percentFormatter;
  final SimpleIcicleTapCallback? onSegmentTap;
  final SimpleIcicleTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleIcicleChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.total,
    required this.orientation,
    required this.padding,
    required this.palette,
    required this.segmentColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showParentLabels,
    required this.showTooltip,
    required this.showActiveSegment,
    required this.maxDepth,
    required this.segmentGap,
    required this.segmentRadius,
    required this.minLabelArea,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.onSegmentTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleIcicleChartView> createState() => _SimpleIcicleChartViewState();
}

class _SimpleIcicleChartViewState extends State<_SimpleIcicleChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  _IcicleSegment? _activeSegment;
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
  void didUpdateWidget(covariant _SimpleIcicleChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
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
          final segments = _IcicleLayout.resolve(
            data: widget.data,
            total: widget.total,
            size: Size(widget.width, widget.height),
            orientation: widget.orientation,
            padding: widget.padding,
            palette: widget.palette,
            segmentColor: widget.segmentColor,
            maxDepth: widget.maxDepth,
            segmentGap: widget.segmentGap,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onHover: (event) {
                    _setActive(_hitTest(event.localPosition, segments));
                    _pointer = event.localPosition;
                  },
                  onExit: (_) => _setActive(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final segment = _hitTest(details.localPosition, segments);
                      _setActive(segment);
                      _pointer = details.localPosition;
                      if (segment != null) {
                        widget.onSegmentTap?.call(
                          segment.data,
                          segment.path,
                          segment.value,
                          segment.share,
                        );
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SimpleIciclePainter(
                            segments: segments,
                            orientation: widget.orientation,
                            borderColor: widget.borderColor,
                            activeColor: widget.activeColor,
                            labelStyle: widget.labelStyle,
                            valueStyle: widget.valueStyle,
                            showLabels: widget.showLabels,
                            showValues: widget.showValues,
                            showParentLabels: widget.showParentLabels,
                            showActiveSegment: widget.showActiveSegment,
                            segmentRadius: widget.segmentRadius,
                            minLabelArea: widget.minLabelArea,
                            valueFormatter: widget.valueFormatter,
                            percentFormatter: widget.percentFormatter,
                            activeSegment: _activeSegment,
                            progress: _animation.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeSegment != null)
                _buildTooltip(context, Size(widget.width, widget.height)),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_IcicleSegment? segment) {
    if (_activeSegment == segment) {
      return;
    }
    setState(() => _activeSegment = segment);
  }

  _IcicleSegment? _hitTest(Offset position, List<_IcicleSegment> segments) {
    for (var i = segments.length - 1; i >= 0; i--) {
      if (segments[i].rect.contains(position)) {
        return segments[i];
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final segment = _activeSegment!;
    final formattedValue = widget.valueFormatter(segment.value);
    final formattedShare = widget.percentFormatter(segment.share);
    final child =
        widget.tooltipBuilder?.call(
          context,
          segment.data,
          segment.path,
          formattedValue,
          formattedShare,
        ) ??
        _DefaultIcicleTooltip(
          data: segment.data,
          path: segment.path,
          formattedValue: formattedValue,
          formattedShare: formattedShare,
        );
    const tooltipWidth = 190.0;
    const tooltipHeight = 106.0;
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

class _SimpleIciclePainter extends CustomPainter {
  final List<_IcicleSegment> segments;
  final SimpleIcicleOrientation orientation;
  final Color borderColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showParentLabels;
  final bool showActiveSegment;
  final double segmentRadius;
  final double minLabelArea;
  final SimpleIcicleValueFormatter valueFormatter;
  final SimpleIcicleValueFormatter percentFormatter;
  final _IcicleSegment? activeSegment;
  final double progress;

  const _SimpleIciclePainter({
    required this.segments,
    required this.orientation,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showParentLabels,
    required this.showActiveSegment,
    required this.segmentRadius,
    required this.minLabelArea,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.activeSegment,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final segment in segments) {
      _drawSegment(canvas, segment);
    }
  }

  void _drawSegment(Canvas canvas, _IcicleSegment segment) {
    final active = activeSegment == segment;
    final related =
        activeSegment == null ||
        activeSegment!.path.contains(segment.data) ||
        segment.path.contains(activeSegment!.data);
    final rect = _animatedRect(segment.rect);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.min(segmentRadius, rect.shortestSide / 2)),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = segment.color.withValues(
          alpha: (related ? 1 : 0.34) * progress,
        )
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor.withValues(alpha: 0.82 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2 : 1,
    );
    if (showActiveSegment && active) {
      canvas.drawRRect(
        rrect.inflate(3),
        Paint()
          ..color = activeColor.withValues(alpha: 0.22 * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    if (showLabels && rect.width * rect.height >= minLabelArea) {
      _drawLabel(canvas, segment, rect);
    }
  }

  Rect _animatedRect(Rect rect) {
    if (orientation == SimpleIcicleOrientation.vertical) {
      return Rect.fromLTWH(
        rect.left,
        rect.top,
        rect.width * progress,
        rect.height,
      );
    }
    return Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      rect.height * progress,
    );
  }

  void _drawLabel(Canvas canvas, _IcicleSegment segment, Rect rect) {
    final isParent = segment.data.children.isNotEmpty;
    if (isParent && !showParentLabels) {
      return;
    }
    final readable = _readableTextColor(segment.color);
    final labelPainter = TextPainter(
      text: TextSpan(
        text: segment.data.label,
        style: labelStyle.copyWith(
          color: readable.withValues(alpha: progress),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: math.max(0, rect.width - 12));
    labelPainter.paint(canvas, Offset(rect.left + 6, rect.top + 5));

    if (showValues && rect.height >= 36) {
      final value =
          '${valueFormatter(segment.value)} '
          '(${percentFormatter(segment.share)})';
      final valuePainter = TextPainter(
        text: TextSpan(
          text: value,
          style: valueStyle.copyWith(
            color: readable.withValues(alpha: 0.82 * progress),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: math.max(0, rect.width - 12));
      valuePainter.paint(canvas, Offset(rect.left + 6, rect.top + 22));
    }
  }

  Color _readableTextColor(Color background) {
    return background.computeLuminance() > 0.52 ? Colors.black : Colors.white;
  }

  @override
  bool shouldRepaint(covariant _SimpleIciclePainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.orientation != orientation ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showParentLabels != showParentLabels ||
        oldDelegate.showActiveSegment != showActiveSegment ||
        oldDelegate.segmentRadius != segmentRadius ||
        oldDelegate.minLabelArea != minLabelArea ||
        oldDelegate.activeSegment != activeSegment ||
        oldDelegate.progress != progress;
  }
}

class _IcicleLayout {
  static List<_IcicleSegment> resolve({
    required List<SimpleIcicleData> data,
    required double total,
    required Size size,
    required SimpleIcicleOrientation orientation,
    required EdgeInsets padding,
    required List<Color> palette,
    required Color segmentColor,
    required int maxDepth,
    required double segmentGap,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal),
      math.max(1, size.height - padding.vertical),
    );
    final maxVisibleDepth = math.max(1, _maxDepth(data, 0, maxDepth));
    final bandCount = maxVisibleDepth + 1;
    final bandExtent = orientation == SimpleIcicleOrientation.vertical
        ? plot.height / bandCount
        : plot.width / bandCount;
    final segments = <_IcicleSegment>[];
    final rootsTotal = data.fold<double>(
      0,
      (sum, item) => sum + SimpleIcicleChart._nodeValue(item),
    );
    var cursor = 0.0;
    for (final item in data) {
      final value = SimpleIcicleChart._nodeValue(item);
      if (value <= 0 || !value.isFinite) {
        continue;
      }
      final share = rootsTotal <= 0 ? 0.0 : value / rootsTotal;
      final start = cursor;
      cursor += share;
      _layoutNode(
        data: item,
        path: const [],
        depth: 0,
        start: start,
        end: cursor,
        total: total,
        plot: plot,
        orientation: orientation,
        bandExtent: bandExtent,
        palette: palette,
        segmentColor: segmentColor,
        maxDepth: maxDepth,
        segmentGap: segmentGap,
        segments: segments,
      );
    }
    return segments;
  }

  static void _layoutNode({
    required SimpleIcicleData data,
    required List<SimpleIcicleData> path,
    required int depth,
    required double start,
    required double end,
    required double total,
    required Rect plot,
    required SimpleIcicleOrientation orientation,
    required double bandExtent,
    required List<Color> palette,
    required Color segmentColor,
    required int maxDepth,
    required double segmentGap,
    required List<_IcicleSegment> segments,
  }) {
    if (depth >= maxDepth) {
      return;
    }
    final value = SimpleIcicleChart._nodeValue(data);
    if (value <= 0 || !value.isFinite) {
      return;
    }
    final nextPath = [...path, data];
    final rect = orientation == SimpleIcicleOrientation.vertical
        ? Rect.fromLTWH(
            plot.left + plot.width * start,
            plot.top + bandExtent * depth,
            plot.width * math.max(0, end - start),
            bandExtent,
          )
        : Rect.fromLTWH(
            plot.left + bandExtent * depth,
            plot.top + plot.height * start,
            bandExtent,
            plot.height * math.max(0, end - start),
          );
    final gap = math.min(segmentGap, math.min(rect.width / 3, rect.height / 3));
    final color =
        data.color ??
        (palette.isEmpty ? segmentColor : palette[depth % palette.length]);
    segments.add(
      _IcicleSegment(
        data: data,
        path: nextPath,
        value: value,
        share: total <= 0 ? 0 : value / total * 100,
        depth: depth,
        rect: rect.deflate(gap),
        color: color,
      ),
    );

    final children = data.children
        .where((child) => SimpleIcicleChart._nodeValue(child) > 0)
        .toList();
    final childTotal = children.fold<double>(
      0,
      (sum, child) => sum + SimpleIcicleChart._nodeValue(child),
    );
    if (childTotal <= 0) {
      return;
    }
    var childCursor = start;
    for (final child in children) {
      final childValue = SimpleIcicleChart._nodeValue(child);
      final span = (end - start) * childValue / childTotal;
      _layoutNode(
        data: child,
        path: nextPath,
        depth: depth + 1,
        start: childCursor,
        end: childCursor + span,
        total: total,
        plot: plot,
        orientation: orientation,
        bandExtent: bandExtent,
        palette: palette,
        segmentColor: segmentColor,
        maxDepth: maxDepth,
        segmentGap: segmentGap,
        segments: segments,
      );
      childCursor += span;
    }
  }

  static int _maxDepth(List<SimpleIcicleData> nodes, int depth, int maxDepth) {
    if (nodes.isEmpty || depth >= maxDepth - 1) {
      return depth;
    }
    var result = depth;
    for (final node in nodes) {
      final value = SimpleIcicleChart._nodeValue(node);
      if (value <= 0 || !value.isFinite) {
        continue;
      }
      result = math.max(result, _maxDepth(node.children, depth + 1, maxDepth));
    }
    return result;
  }
}

class _IcicleSegment {
  final SimpleIcicleData data;
  final List<SimpleIcicleData> path;
  final double value;
  final double share;
  final int depth;
  final Rect rect;
  final Color color;

  const _IcicleSegment({
    required this.data,
    required this.path,
    required this.value,
    required this.share,
    required this.depth,
    required this.rect,
    required this.color,
  });
}

class _SimpleIcicleVisuals {
  final Color segmentColor;
  final Color borderColor;
  final Color activeColor;
  final List<Color> palette;

  const _SimpleIcicleVisuals({
    required this.segmentColor,
    required this.borderColor,
    required this.activeColor,
    required this.palette,
  });

  factory _SimpleIcicleVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleIcicleVisuals(
          segmentColor: colorScheme.primary,
          borderColor: colorScheme.surface,
          activeColor: colorScheme.primary,
          palette: const [
            Color(0xFF2563EB),
            Color(0xFF10B981),
            Color(0xFFF59E0B),
            Color(0xFFEF4444),
            Color(0xFF8B5CF6),
          ],
        );
      case SimpleBarChartStyle.professional:
        return const _SimpleIcicleVisuals(
          segmentColor: Color(0xFF2563EB),
          borderColor: Color(0xFFFFFFFF),
          activeColor: Color(0xFF0F172A),
          palette: [
            Color(0xFF1D4ED8),
            Color(0xFF0F766E),
            Color(0xFF7C2D12),
            Color(0xFF6D28D9),
            Color(0xFFBE123C),
          ],
        );
      case SimpleBarChartStyle.education:
        return const _SimpleIcicleVisuals(
          segmentColor: Color(0xFF2563EB),
          borderColor: Color(0xFFFFFFFF),
          activeColor: Color(0xFF2563EB),
          palette: [
            Color(0xFF2563EB),
            Color(0xFFF97316),
            Color(0xFF16A34A),
            Color(0xFFDB2777),
            Color(0xFF9333EA),
          ],
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleIcicleVisuals(
          segmentColor: const Color(0xFF14B8A6),
          borderColor: colorScheme.surface,
          activeColor: const Color(0xFF8B5CF6),
          palette: const [
            Color(0xFF14B8A6),
            Color(0xFFF43F5E),
            Color(0xFF8B5CF6),
            Color(0xFFF59E0B),
            Color(0xFF06B6D4),
          ],
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleIcicleVisuals(
          segmentColor: colorScheme.secondary,
          borderColor: colorScheme.surface,
          activeColor: colorScheme.secondary,
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

class _DefaultIcicleTooltip extends StatelessWidget {
  final SimpleIcicleData data;
  final List<SimpleIcicleData> path;
  final String formattedValue;
  final String formattedShare;

  const _DefaultIcicleTooltip({
    required this.data,
    required this.path,
    required this.formattedValue,
    required this.formattedShare,
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
                  const Expanded(child: Text('Value')),
                  Text(
                    formattedValue,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Text('Share')),
                  Text(
                    formattedShare,
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
