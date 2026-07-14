import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimplePackedBubbleValueFormatter = String Function(double value);
typedef SimplePackedBubbleTapCallback =
    void Function(SimplePackedBubbleData data, int index, double share);
typedef SimplePackedBubbleTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimplePackedBubbleData data,
      int index,
      String formattedValue,
      String formattedShare,
    );

class SimplePackedBubbleData {
  final String label;
  final double value;
  final Color? color;

  const SimplePackedBubbleData({
    required this.label,
    required this.value,
    this.color,
  });
}

/// A compact packed bubble chart for showing part-to-whole magnitude through
/// area while keeping the composition visually approachable.
class SimplePackedBubbleChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.all(18);

  final List<SimplePackedBubbleData> data;
  final SimpleBarChartStyle style;
  final double? totalValue;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? bubbleColor;
  final Color? borderColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveBubble;
  final double? minBubbleRadius;
  final double? maxBubbleRadius;
  final double bubbleSpacing;
  final SimplePackedBubbleValueFormatter? valueFormatter;
  final SimplePackedBubbleValueFormatter? percentFormatter;
  final SimplePackedBubbleTapCallback? onBubbleTap;
  final SimplePackedBubbleTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimplePackedBubbleChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.totalValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.bubbleColor,
    this.borderColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveBubble = true,
    this.minBubbleRadius,
    this.maxBubbleRadius,
    this.bubbleSpacing = 4,
    this.valueFormatter,
    this.percentFormatter,
    this.onBubbleTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(totalValue == null || totalValue > 0),
       assert(minBubbleRadius == null || minBubbleRadius >= 0),
       assert(maxBubbleRadius == null || maxBubbleRadius >= 0),
       assert(bubbleSpacing >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimplePackedBubbleVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.label.trim().isNotEmpty && item.value > 0)
        .toList();
    final dataTotal = visibleData.fold<double>(
      0,
      (current, item) => current + item.value,
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
            emptySemanticLabel: 'Packed bubble chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedLabelStyle =
            labelStyle ??
            theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700) ??
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700);
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800) ??
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w800);
        final resolvedPalette = _resolvePalette(colorScheme, visuals.palette);

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
          child: _SimplePackedBubbleChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            total: resolvedTotal,
            padding: padding,
            palette: resolvedPalette,
            bubbleColor: bubbleColor,
            borderColor: borderColor ?? visuals.borderColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveBubble: showActiveBubble,
            minBubbleRadius: minBubbleRadius ?? visuals.minBubbleRadius,
            maxBubbleRadius: maxBubbleRadius,
            bubbleSpacing: bubbleSpacing,
            valueFormatter: formatter,
            percentFormatter: resolvedPercentFormatter,
            onBubbleTap: onBubbleTap,
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
    if (bubbleColor != null) return [bubbleColor!];
    return defaults;
  }

  String _defaultSemanticLabel(
    List<SimplePackedBubbleData> visibleData,
    double total,
    SimplePackedBubbleValueFormatter formatter,
    SimplePackedBubbleValueFormatter resolvedPercentFormatter,
  ) {
    final visibleItems = visibleData
        .take(6)
        .map((item) {
          final share = total == 0 ? 0.0 : item.value / total;
          return '${item.label} ${formatter(item.value)}, '
              '${resolvedPercentFormatter(share)}';
        })
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'bubble' : 'bubbles';
    return 'Packed bubble chart, ${visibleData.length} $countLabel. '
        '$visibleItems$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) {
    return '${(value * 100).round()}%';
  }
}

class _SimplePackedBubbleChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimplePackedBubbleData> data;
  final double total;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? bubbleColor;
  final Color borderColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveBubble;
  final double minBubbleRadius;
  final double? maxBubbleRadius;
  final double bubbleSpacing;
  final SimplePackedBubbleValueFormatter valueFormatter;
  final SimplePackedBubbleValueFormatter percentFormatter;
  final SimplePackedBubbleTapCallback? onBubbleTap;
  final SimplePackedBubbleTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimplePackedBubbleChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.total,
    required this.padding,
    required this.palette,
    required this.bubbleColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveBubble,
    required this.minBubbleRadius,
    required this.maxBubbleRadius,
    required this.bubbleSpacing,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.onBubbleTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimplePackedBubbleChartView> createState() =>
      _SimplePackedBubbleChartViewState();
}

class _SimplePackedBubbleChartViewState
    extends State<_SimplePackedBubbleChartView> {
  _PackedBubbleSelection? _active;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveBubble ||
        widget.onBubbleTap != null;

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
                painter: _SimplePackedBubblePainter(
                  data: widget.data,
                  total: widget.total,
                  padding: widget.padding,
                  palette: widget.palette,
                  bubbleColor: widget.bubbleColor,
                  borderColor: widget.borderColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showLabels: widget.showLabels,
                  showValues: widget.showValues,
                  showLegend: widget.showLegend,
                  showActiveBubble: widget.showActiveBubble,
                  minBubbleRadius: widget.minBubbleRadius,
                  maxBubbleRadius: widget.maxBubbleRadius,
                  bubbleSpacing: widget.bubbleSpacing,
                  valueFormatter: widget.valueFormatter,
                  percentFormatter: widget.percentFormatter,
                  activeSelection: _active,
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
                      final selection = _hitTest(details.localPosition, size);
                      _setActive(selection);
                      if (selection == null) return;

                      final item = widget.data[selection.index];
                      final share = item.value / widget.total;
                      widget.onBubbleTap?.call(item, selection.index, share);
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _active != null)
                _buildTooltip(context, size, _active!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_PackedBubbleSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _PackedBubbleSelection? _hitTest(Offset position, Size size) {
    final geometry = _PackedBubbleGeometry.resolve(
      size: size,
      data: widget.data,
      total: widget.total,
      padding: widget.padding,
      showLegend: widget.showLegend,
      minBubbleRadius: widget.minBubbleRadius,
      maxBubbleRadius: widget.maxBubbleRadius,
      bubbleSpacing: widget.bubbleSpacing,
    );

    for (final bubble in geometry.bubbles.reversed) {
      if ((position - bubble.center).distance <= bubble.radius + 8) {
        return _PackedBubbleSelection(bubble.index, bubble.center);
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _PackedBubbleSelection selection,
  ) {
    final item = widget.data[selection.index];
    final share = item.value / widget.total;
    final formattedValue = widget.valueFormatter(item.value);
    final formattedShare = widget.percentFormatter(share);
    const tooltipWidth = 172.0;
    const tooltipHeight = 76.0;
    final left = (selection.position.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (selection.position.dy - tooltipHeight - 8)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            item,
            selection.index,
            formattedValue,
            formattedShare,
          ) ??
          _DefaultPackedBubbleTooltip(
            color: _itemColor(item, selection.index),
            title: item.label,
            value: formattedValue,
            share: formattedShare,
          ),
    );
  }

  Color _itemColor(SimplePackedBubbleData item, int index) {
    return item.color ??
        widget.bubbleColor ??
        widget.palette[index % widget.palette.length];
  }
}

class _SimplePackedBubblePainter extends CustomPainter {
  final List<SimplePackedBubbleData> data;
  final double total;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color? bubbleColor;
  final Color borderColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActiveBubble;
  final double minBubbleRadius;
  final double? maxBubbleRadius;
  final double bubbleSpacing;
  final SimplePackedBubbleValueFormatter valueFormatter;
  final SimplePackedBubbleValueFormatter percentFormatter;
  final _PackedBubbleSelection? activeSelection;
  final double progress;

  const _SimplePackedBubblePainter({
    required this.data,
    required this.total,
    required this.padding,
    required this.palette,
    required this.bubbleColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActiveBubble,
    required this.minBubbleRadius,
    required this.maxBubbleRadius,
    required this.bubbleSpacing,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.activeSelection,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _PackedBubbleGeometry.resolve(
      size: size,
      data: data,
      total: total,
      padding: padding,
      showLegend: showLegend,
      minBubbleRadius: minBubbleRadius,
      maxBubbleRadius: maxBubbleRadius,
      bubbleSpacing: bubbleSpacing,
    );
    if (geometry.plot.isEmpty || geometry.bubbles.isEmpty) return;

    _drawBubbles(canvas, geometry);
    if (showLegend && !geometry.legend.isEmpty) {
      _drawLegend(canvas, geometry);
    }
  }

  void _drawBubbles(Canvas canvas, _PackedBubbleGeometry geometry) {
    for (final bubble in geometry.bubbles) {
      final item = data[bubble.index];
      final color = _itemColor(item, bubble.index);
      final selected = activeSelection?.index == bubble.index;
      final animatedRadius = bubble.radius * (0.38 + progress * 0.62);
      final center =
          geometry.plot.center +
          (bubble.center - geometry.plot.center) * progress;
      final path = Path()
        ..addOval(Rect.fromCircle(center: center, radius: animatedRadius));

      canvas.drawShadow(path, Colors.black.withValues(alpha: 0.14), 6, false);
      canvas.drawCircle(
        center,
        animatedRadius,
        Paint()..color = color.withValues(alpha: 0.86),
      );
      canvas.drawCircle(
        center,
        animatedRadius,
        Paint()
          ..color = borderColor.withValues(alpha: 0.46)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      if (showActiveBubble && selected) {
        canvas.drawCircle(
          center,
          animatedRadius + 6,
          Paint()..color = activeColor.withValues(alpha: 0.14),
        );
        canvas.drawCircle(
          center,
          animatedRadius + 3,
          Paint()
            ..color = activeColor.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      if (progress > 0.72 && showLabels && animatedRadius >= 17) {
        _drawBubbleLabel(canvas, item, center, animatedRadius, color);
      }
    }
  }

  void _drawBubbleLabel(
    Canvas canvas,
    SimplePackedBubbleData item,
    Offset center,
    double radius,
    Color color,
  ) {
    final textColor = color.computeLuminance() > 0.55
        ? Colors.black.withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.96);
    final label = item.label;
    final value = valueFormatter(item.value);
    final maxWidth = radius * 1.58;
    final labelFontSize = math.min(12.0, math.max(9.0, radius * 0.24));
    final valueFontSize = math.min(13.0, math.max(9.0, radius * 0.27));

    if (showValues && radius >= 28) {
      _paintText(
        canvas,
        label,
        labelStyle.copyWith(color: textColor, fontSize: labelFontSize),
        Offset(center.dx, center.dy - 9),
        TextAlign.center,
        maxWidth,
      );
      _paintText(
        canvas,
        value,
        valueStyle.copyWith(color: textColor, fontSize: valueFontSize),
        Offset(center.dx, center.dy + 6),
        TextAlign.center,
        maxWidth,
      );
      return;
    }

    _paintText(
      canvas,
      label,
      labelStyle.copyWith(color: textColor, fontSize: labelFontSize),
      center,
      TextAlign.center,
      maxWidth,
      centeredY: true,
    );
  }

  void _drawLegend(Canvas canvas, _PackedBubbleGeometry geometry) {
    final sorted = geometry.bubbles.toList()
      ..sort((a, b) => b.radius.compareTo(a.radius));
    final style = labelStyle.copyWith(
      color: labelStyle.color?.withValues(alpha: 0.88),
      fontWeight: FontWeight.w600,
    );
    final valueStyleForLegend = valueStyle.copyWith(
      color: valueStyle.color?.withValues(alpha: 0.78),
      fontSize: math.max(9, (valueStyle.fontSize ?? 11) - 1),
    );

    if (geometry.legendOnRight) {
      var y = geometry.legend.top + 2;
      for (final bubble in sorted.take(6)) {
        final item = data[bubble.index];
        final color = _itemColor(item, bubble.index);
        final rowHeight = showValues ? 28.0 : 19.0;
        if (y + rowHeight > geometry.legend.bottom) break;
        canvas.drawCircle(
          Offset(geometry.legend.left + 5, y + 7),
          4,
          Paint()..color = color,
        );
        _paintText(
          canvas,
          item.label,
          style,
          Offset(geometry.legend.left + 16, y),
          TextAlign.left,
          geometry.legend.width - 18,
        );
        if (showValues) {
          final share = item.value / total;
          _paintText(
            canvas,
            '${valueFormatter(item.value)} · ${percentFormatter(share)}',
            valueStyleForLegend,
            Offset(geometry.legend.left + 16, y + 13),
            TextAlign.left,
            geometry.legend.width - 18,
          );
        }
        y += rowHeight;
      }
      return;
    }

    var x = geometry.legend.left;
    final y = geometry.legend.top + 7;
    for (final bubble in sorted.take(5)) {
      final item = data[bubble.index];
      final color = _itemColor(item, bubble.index);
      final rowWidth = math.min(116.0, geometry.legend.right - x);
      if (rowWidth < 42) break;
      canvas.drawCircle(Offset(x + 5, y + 6), 4, Paint()..color = color);
      _paintText(
        canvas,
        item.label,
        style,
        Offset(x + 16, y),
        TextAlign.left,
        rowWidth - 18,
      );
      x += rowWidth + 8;
      if (x >= geometry.legend.right) break;
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset anchor,
    TextAlign align,
    double maxWidth, {
    bool centeredY = false,
  }) {
    if (maxWidth <= 0) return;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);

    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.center => anchor.dx - painter.width / 2,
      _ => anchor.dx,
    };
    final dy = centeredY ? anchor.dy - painter.height / 2 : anchor.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  Color _itemColor(SimplePackedBubbleData item, int index) {
    return item.color ?? bubbleColor ?? palette[index % palette.length];
  }

  @override
  bool shouldRepaint(covariant _SimplePackedBubblePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.total != total ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.bubbleColor != bubbleColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveBubble != showActiveBubble ||
        oldDelegate.minBubbleRadius != minBubbleRadius ||
        oldDelegate.maxBubbleRadius != maxBubbleRadius ||
        oldDelegate.bubbleSpacing != bubbleSpacing ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.percentFormatter != percentFormatter ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.progress != progress;
  }
}

class _PackedBubbleGeometry {
  final Rect plot;
  final Rect legend;
  final bool legendOnRight;
  final List<_PackedBubbleLayout> bubbles;

  const _PackedBubbleGeometry({
    required this.plot,
    required this.legend,
    required this.legendOnRight,
    required this.bubbles,
  });

  factory _PackedBubbleGeometry.resolve({
    required Size size,
    required List<SimplePackedBubbleData> data,
    required double total,
    required EdgeInsets padding,
    required bool showLegend,
    required double minBubbleRadius,
    required double? maxBubbleRadius,
    required double bubbleSpacing,
  }) {
    final legendOnRight = showLegend && size.width >= 420;
    final rightLegendWidth = legendOnRight
        ? math.min(132.0, math.max(112.0, size.width * 0.26))
        : 0.0;
    final bottomLegendHeight = showLegend && !legendOnRight ? 34.0 : 0.0;
    final legendGap = showLegend ? 12.0 : 0.0;
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(
        0.0,
        size.width -
            padding.horizontal -
            rightLegendWidth -
            (rightLegendWidth > 0 ? legendGap : 0),
      ),
      math.max(
        0.0,
        size.height -
            padding.vertical -
            bottomLegendHeight -
            (bottomLegendHeight > 0 ? legendGap : 0),
      ),
    );
    final legend = showLegend
        ? (legendOnRight
              ? Rect.fromLTWH(
                  plot.right + legendGap,
                  padding.top,
                  rightLegendWidth,
                  math.max(0.0, size.height - padding.vertical),
                )
              : Rect.fromLTWH(
                  padding.left,
                  plot.bottom + legendGap,
                  math.max(0.0, size.width - padding.horizontal),
                  bottomLegendHeight,
                ))
        : Rect.zero;

    if (plot.width <= 0 || plot.height <= 0 || data.isEmpty || total <= 0) {
      return _PackedBubbleGeometry(
        plot: plot,
        legend: legend,
        legendOnRight: legendOnRight,
        bubbles: const [],
      );
    }

    final entries = <_PackedBubbleEntry>[];
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      if (item.value <= 0) continue;
      entries.add(_PackedBubbleEntry(index: index, value: item.value));
    }
    entries.sort((a, b) {
      final valueCompare = b.value.compareTo(a.value);
      if (valueCompare != 0) return valueCompare;
      return a.index.compareTo(b.index);
    });

    final layout = _pack(
      entries: entries,
      plot: plot,
      total: total,
      minBubbleRadius: minBubbleRadius,
      maxBubbleRadius: maxBubbleRadius,
      bubbleSpacing: bubbleSpacing,
    );

    return _PackedBubbleGeometry(
      plot: plot,
      legend: legend,
      legendOnRight: legendOnRight,
      bubbles: layout,
    );
  }

  static List<_PackedBubbleLayout> _pack({
    required List<_PackedBubbleEntry> entries,
    required Rect plot,
    required double total,
    required double minBubbleRadius,
    required double? maxBubbleRadius,
    required double bubbleSpacing,
  }) {
    final availableArea = plot.width * plot.height * 0.54;
    final areaScale = availableArea / math.max(total, 1);
    final maxRadius =
        maxBubbleRadius ?? math.min(58.0, plot.shortestSide * 0.28);
    final base = entries.map((entry) {
      final radius = math
          .sqrt(entry.value * areaScale / math.pi)
          .clamp(minBubbleRadius, maxRadius);
      return _PackedBubbleCandidate(
        index: entry.index,
        value: entry.value,
        radius: radius.toDouble(),
      );
    }).toList();

    for (var scale = 1.0; scale >= 0.46; scale -= 0.06) {
      final placed = <_PackedBubbleLayout>[];
      var failed = false;
      for (final candidate in base) {
        final radius = candidate.radius * scale;
        final center = _placeCircle(
          plot: plot,
          radius: radius,
          placed: placed,
          spacing: bubbleSpacing,
          seed: candidate.index,
        );
        if (center == null) {
          failed = true;
          break;
        }
        placed.add(
          _PackedBubbleLayout(
            index: candidate.index,
            value: candidate.value,
            center: center,
            radius: radius,
          ),
        );
      }
      if (!failed) return placed;
    }

    return _fallbackPack(
      entries: base,
      plot: plot,
      spacing: bubbleSpacing,
      maxRadius: maxRadius,
    );
  }

  static Offset? _placeCircle({
    required Rect plot,
    required double radius,
    required List<_PackedBubbleLayout> placed,
    required double spacing,
    required int seed,
  }) {
    final center = plot.center;
    if (placed.isEmpty && _fits(center, radius, plot, placed, spacing)) {
      return center;
    }
    final maxSearch =
        math.sqrt(plot.width * plot.width + plot.height * plot.height) / 2;
    final ringStep = math.max(6.0, radius * 0.56 + spacing);
    final angleOffset = seed * 2.399963229728653;
    Offset? best;
    var bestScore = double.infinity;

    for (var ring = 0.0; ring <= maxSearch; ring += ringStep) {
      final count = math.max(
        12,
        (2 * math.pi * math.max(ring, 1) / ringStep).ceil(),
      );
      for (var index = 0; index < count; index++) {
        final angle = angleOffset + index / count * math.pi * 2;
        final point = Offset(
          center.dx + math.cos(angle) * ring,
          center.dy + math.sin(angle) * ring,
        );
        if (!_fits(point, radius, plot, placed, spacing)) continue;
        final score =
            (point - center).distance + (point.dy - center.dy).abs() * 0.08;
        if (score < bestScore) {
          bestScore = score;
          best = point;
        }
      }
      if (best != null && ring > 0) return best;
    }
    return best;
  }

  static bool _fits(
    Offset center,
    double radius,
    Rect plot,
    List<_PackedBubbleLayout> placed,
    double spacing,
  ) {
    if (center.dx - radius < plot.left ||
        center.dx + radius > plot.right ||
        center.dy - radius < plot.top ||
        center.dy + radius > plot.bottom) {
      return false;
    }
    for (final bubble in placed) {
      if ((center - bubble.center).distance <
          radius + bubble.radius + spacing) {
        return false;
      }
    }
    return true;
  }

  static List<_PackedBubbleLayout> _fallbackPack({
    required List<_PackedBubbleCandidate> entries,
    required Rect plot,
    required double spacing,
    required double maxRadius,
  }) {
    final result = <_PackedBubbleLayout>[];
    final center = plot.center;
    final ringStep = math.max(18.0, maxRadius * 0.62 + spacing);
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final ring = ringStep * math.sqrt(index);
      final angle = index * 2.399963229728653;
      final radius = math.max(5.0, entry.radius * 0.46);
      final position = Offset(
        center.dx + math.cos(angle) * ring,
        center.dy + math.sin(angle) * ring,
      );
      final clamped = Offset(
        position.dx.clamp(plot.left + radius, plot.right - radius).toDouble(),
        position.dy.clamp(plot.top + radius, plot.bottom - radius).toDouble(),
      );
      result.add(
        _PackedBubbleLayout(
          index: entry.index,
          value: entry.value,
          center: clamped,
          radius: radius,
        ),
      );
    }
    return result;
  }
}

class _PackedBubbleEntry {
  final int index;
  final double value;

  const _PackedBubbleEntry({required this.index, required this.value});
}

class _PackedBubbleCandidate {
  final int index;
  final double value;
  final double radius;

  const _PackedBubbleCandidate({
    required this.index,
    required this.value,
    required this.radius,
  });
}

class _PackedBubbleLayout {
  final int index;
  final double value;
  final Offset center;
  final double radius;

  const _PackedBubbleLayout({
    required this.index,
    required this.value,
    required this.center,
    required this.radius,
  });
}

class _PackedBubbleSelection {
  final int index;
  final Offset position;

  const _PackedBubbleSelection(this.index, this.position);

  @override
  bool operator ==(Object other) {
    return other is _PackedBubbleSelection && other.index == index;
  }

  @override
  int get hashCode => index.hashCode;
}

class _SimplePackedBubbleVisuals {
  final List<Color> palette;
  final Color borderColor;
  final Color activeColor;
  final double minBubbleRadius;

  const _SimplePackedBubbleVisuals({
    required this.palette,
    required this.borderColor,
    required this.activeColor,
    required this.minBubbleRadius,
  });

  factory _SimplePackedBubbleVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimplePackedBubbleVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.error,
          ],
          borderColor: colorScheme.surface,
          activeColor: colorScheme.primary,
          minBubbleRadius: 13,
        );
      case SimpleBarChartStyle.professional:
        return _SimplePackedBubbleVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.onSurfaceVariant,
            colorScheme.tertiary,
          ],
          borderColor: colorScheme.outline.withValues(alpha: 0.42),
          activeColor: colorScheme.primary,
          minBubbleRadius: 12,
        );
      case SimpleBarChartStyle.education:
        return _SimplePackedBubbleVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.tertiary,
            colorScheme.primary,
            colorScheme.error,
          ],
          borderColor: colorScheme.surface,
          activeColor: colorScheme.secondary,
          minBubbleRadius: 13,
        );
      case SimpleBarChartStyle.trendy:
        return _SimplePackedBubbleVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.error,
          ],
          borderColor: colorScheme.surface,
          activeColor: colorScheme.tertiary,
          minBubbleRadius: 14,
        );
      case SimpleBarChartStyle.elegant:
        return _SimplePackedBubbleVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.tertiary,
            colorScheme.secondary,
            colorScheme.error,
          ],
          borderColor: colorScheme.surface,
          activeColor: colorScheme.primary,
          minBubbleRadius: 13,
        );
    }
  }
}

class _DefaultPackedBubbleTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String value;
  final String share;

  const _DefaultPackedBubbleTooltip({
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
                    shape: BoxShape.circle,
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
