import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimplePopulationPyramidValueFormatter = String Function(double value);
typedef SimplePopulationPyramidTapCallback =
    void Function(
      SimplePopulationPyramidData data,
      int index,
      SimplePopulationPyramidSide side,
      double value,
    );
typedef SimplePopulationPyramidTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimplePopulationPyramidData data,
      int index,
      SimplePopulationPyramidSide side,
      String sideLabel,
      String formattedValue,
    );

enum SimplePopulationPyramidSide { left, right }

class SimplePopulationPyramidData {
  final String label;
  final double leftValue;
  final double rightValue;
  final Color? leftColor;
  final Color? rightColor;

  const SimplePopulationPyramidData({
    required this.label,
    required this.leftValue,
    required this.rightValue,
    this.leftColor,
    this.rightColor,
  });
}

/// A mirrored horizontal bar chart for demographic, cohort, and two-sided
/// segment comparisons.
class SimplePopulationPyramidChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 28, 18, 36);

  final List<SimplePopulationPyramidData> data;
  final SimpleBarChartStyle style;
  final String leftLabel;
  final String rightLabel;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? leftColor;
  final Color? rightColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showCenterLabels;
  final bool showTooltip;
  final bool showActiveBar;
  final int gridLineCount;
  final double centerLabelWidth;
  final double? barRadius;
  final double? barWidthFactor;
  final double? maxBarThickness;
  final SimplePopulationPyramidValueFormatter? valueFormatter;
  final SimplePopulationPyramidTapCallback? onBarTap;
  final SimplePopulationPyramidTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimplePopulationPyramidChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.leftLabel = 'Left',
    this.rightLabel = 'Right',
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.leftColor,
    this.rightColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showValues = true,
    this.showLegend = true,
    this.showCenterLabels = true,
    this.showTooltip = true,
    this.showActiveBar = true,
    this.gridLineCount = 4,
    this.centerLabelWidth = 66,
    this.barRadius,
    this.barWidthFactor,
    this.maxBarThickness,
    this.valueFormatter,
    this.onBarTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(centerLabelWidth >= 0),
       assert(barRadius == null || barRadius >= 0),
       assert(
         barWidthFactor == null || (barWidthFactor > 0 && barWidthFactor <= 1),
       ),
       assert(maxBarThickness == null || maxBarThickness > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimplePopulationPyramidVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where(
          (item) =>
              item.leftValue.isFinite &&
              item.rightValue.isFinite &&
              item.leftValue >= 0 &&
              item.rightValue >= 0,
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Population pyramid chart, no data.',
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
            ) ??
            TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12);
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
          semanticLabel: _defaultSemanticLabel(visibleData, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimplePopulationPyramidChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            leftLabel: leftLabel,
            rightLabel: rightLabel,
            maxValue: maxValue,
            padding: padding,
            leftColor: leftColor ?? visuals.leftColor,
            rightColor: rightColor ?? visuals.rightColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showLegend: showLegend,
            showCenterLabels: showCenterLabels,
            showTooltip: showTooltip,
            showActiveBar: showActiveBar,
            gridLineCount: gridLineCount,
            centerLabelWidth: centerLabelWidth,
            barRadius: barRadius ?? visuals.barRadius,
            barWidthFactor: barWidthFactor ?? visuals.barWidthFactor,
            maxBarThickness: maxBarThickness ?? visuals.maxBarThickness,
            valueFormatter: formatter,
            onBarTap: onBarTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(
    List<SimplePopulationPyramidData> visibleData,
    SimplePopulationPyramidValueFormatter formatter,
  ) {
    final summaries = visibleData
        .take(6)
        .map((item) {
          return '${item.label} $leftLabel ${formatter(item.leftValue)}, '
              '$rightLabel ${formatter(item.rightValue)}';
        })
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'group' : 'groups';
    return 'Population pyramid chart, ${visibleData.length} $countLabel. '
        '$summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimplePopulationPyramidChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimplePopulationPyramidData> data;
  final String leftLabel;
  final String rightLabel;
  final double? maxValue;
  final EdgeInsets padding;
  final Color leftColor;
  final Color rightColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLegend;
  final bool showCenterLabels;
  final bool showTooltip;
  final bool showActiveBar;
  final int gridLineCount;
  final double centerLabelWidth;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarThickness;
  final SimplePopulationPyramidValueFormatter valueFormatter;
  final SimplePopulationPyramidTapCallback? onBarTap;
  final SimplePopulationPyramidTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimplePopulationPyramidChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.leftLabel,
    required this.rightLabel,
    required this.maxValue,
    required this.padding,
    required this.leftColor,
    required this.rightColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLegend,
    required this.showCenterLabels,
    required this.showTooltip,
    required this.showActiveBar,
    required this.gridLineCount,
    required this.centerLabelWidth,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarThickness,
    required this.valueFormatter,
    required this.onBarTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimplePopulationPyramidChartView> createState() =>
      _SimplePopulationPyramidChartViewState();
}

class _SimplePopulationPyramidChartViewState
    extends State<_SimplePopulationPyramidChartView> {
  _PyramidSelection? _active;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveBar || widget.onBarTap != null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          if (widget.showLegend) _buildLegend(context),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final chart = TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: widget.animationDuration,
                  curve: widget.animationCurve,
                  builder: (context, progress, child) {
                    return CustomPaint(
                      painter: _SimplePopulationPyramidPainter(
                        data: widget.data,
                        leftLabel: widget.leftLabel,
                        rightLabel: widget.rightLabel,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        leftColor: widget.leftColor,
                        rightColor: widget.rightColor,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showValues: widget.showValues,
                        showCenterLabels: widget.showCenterLabels,
                        showActiveBar: widget.showActiveBar,
                        gridLineCount: widget.gridLineCount,
                        centerLabelWidth: widget.centerLabelWidth,
                        barRadius: widget.barRadius,
                        barWidthFactor: widget.barWidthFactor,
                        maxBarThickness: widget.maxBarThickness,
                        activeSelection: _active,
                        valueFormatter: widget.valueFormatter,
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
                            final selection = _hitTest(
                              details.localPosition,
                              size,
                            );
                            _setActive(selection);
                            if (selection == null) return;
                            final item = widget.data[selection.index];
                            widget.onBarTap?.call(
                              item,
                              selection.index,
                              selection.side,
                              _valueFor(item, selection.side),
                            );
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
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: [
          _PyramidLegendItem(
            label: widget.leftLabel,
            color: widget.leftColor,
            textStyle: widget.labelStyle,
          ),
          _PyramidLegendItem(
            label: widget.rightLabel,
            color: widget.rightColor,
            textStyle: widget.labelStyle,
          ),
        ],
      ),
    );
  }

  void _setActive(_PyramidSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _PyramidSelection? _hitTest(Offset position, Size size) {
    final geometry = _PyramidGeometry.resolve(
      size: size,
      data: widget.data,
      maxValue: widget.maxValue,
      padding: widget.padding,
      centerLabelWidth: widget.centerLabelWidth,
      barWidthFactor: widget.barWidthFactor,
      maxBarThickness: widget.maxBarThickness,
    );
    for (var index = 0; index < geometry.items.length; index++) {
      final layout = geometry.items[index];
      if (layout.leftRect.inflate(5).contains(position)) {
        return _PyramidSelection(index, SimplePopulationPyramidSide.left);
      }
      if (layout.rightRect.inflate(5).contains(position)) {
        return _PyramidSelection(index, SimplePopulationPyramidSide.right);
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _PyramidSelection selection,
  ) {
    final item = widget.data[selection.index];
    final value = _valueFor(item, selection.side);
    final color = _colorFor(item, selection.side);
    final sideLabel = selection.side == SimplePopulationPyramidSide.left
        ? widget.leftLabel
        : widget.rightLabel;
    final formattedValue = widget.valueFormatter(value);
    final geometry = _PyramidGeometry.resolve(
      size: size,
      data: widget.data,
      maxValue: widget.maxValue,
      padding: widget.padding,
      centerLabelWidth: widget.centerLabelWidth,
      barWidthFactor: widget.barWidthFactor,
      maxBarThickness: widget.maxBarThickness,
    );
    final anchor = selection.side == SimplePopulationPyramidSide.left
        ? geometry.items[selection.index].leftRect.center
        : geometry.items[selection.index].rightRect.center;
    const tooltipWidth = 174.0;
    const tooltipHeight = 64.0;
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
            item,
            selection.index,
            selection.side,
            sideLabel,
            formattedValue,
          ) ??
          _DefaultPyramidTooltip(
            color: color,
            title: item.label,
            label: sideLabel,
            value: formattedValue,
          ),
    );
  }

  double _valueFor(
    SimplePopulationPyramidData item,
    SimplePopulationPyramidSide side,
  ) {
    return side == SimplePopulationPyramidSide.left
        ? item.leftValue
        : item.rightValue;
  }

  Color _colorFor(
    SimplePopulationPyramidData item,
    SimplePopulationPyramidSide side,
  ) {
    if (side == SimplePopulationPyramidSide.left) {
      return item.leftColor ?? widget.leftColor;
    }
    return item.rightColor ?? widget.rightColor;
  }
}

class _SimplePopulationPyramidPainter extends CustomPainter {
  final List<SimplePopulationPyramidData> data;
  final String leftLabel;
  final String rightLabel;
  final double? maxValue;
  final EdgeInsets padding;
  final Color leftColor;
  final Color rightColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showCenterLabels;
  final bool showActiveBar;
  final int gridLineCount;
  final double centerLabelWidth;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarThickness;
  final _PyramidSelection? activeSelection;
  final SimplePopulationPyramidValueFormatter valueFormatter;
  final double progress;

  const _SimplePopulationPyramidPainter({
    required this.data,
    required this.leftLabel,
    required this.rightLabel,
    required this.maxValue,
    required this.padding,
    required this.leftColor,
    required this.rightColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showCenterLabels,
    required this.showActiveBar,
    required this.gridLineCount,
    required this.centerLabelWidth,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarThickness,
    required this.activeSelection,
    required this.valueFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _PyramidGeometry.resolve(
      size: size,
      data: data,
      maxValue: maxValue,
      padding: padding,
      centerLabelWidth: centerLabelWidth,
      barWidthFactor: barWidthFactor,
      maxBarThickness: maxBarThickness,
    );
    if (geometry.items.isEmpty || geometry.plot.isEmpty) return;

    if (showGrid) _drawGrid(canvas, geometry);
    _drawCenterAxis(canvas, geometry);
    _drawBars(canvas, geometry);
    if (showCenterLabels) _drawCenterLabels(canvas, geometry);
  }

  void _drawGrid(Canvas canvas, _PyramidGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final ratio = index / gridLineCount;
      final leftX = geometry.leftRect.right - geometry.leftRect.width * ratio;
      final rightX = geometry.rightRect.left + geometry.rightRect.width * ratio;
      canvas.drawLine(
        Offset(leftX, geometry.plot.top),
        Offset(leftX, geometry.plot.bottom),
        paint,
      );
      canvas.drawLine(
        Offset(rightX, geometry.plot.top),
        Offset(rightX, geometry.plot.bottom),
        paint,
      );
      final tick = valueFormatter(geometry.maxValue * ratio);
      _paintText(
        canvas,
        tick,
        labelStyle.copyWith(
          color: labelStyle.color?.withValues(alpha: 0.72),
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
        ),
        Offset(leftX, geometry.plot.bottom + 6),
        TextAlign.center,
        52,
      );
      _paintText(
        canvas,
        tick,
        labelStyle.copyWith(
          color: labelStyle.color?.withValues(alpha: 0.72),
          fontSize: math.max(9, (labelStyle.fontSize ?? 12) - 1),
        ),
        Offset(rightX, geometry.plot.bottom + 6),
        TextAlign.center,
        52,
      );
    }
  }

  void _drawCenterAxis(Canvas canvas, _PyramidGeometry geometry) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(geometry.centerRect.left, geometry.plot.top),
      Offset(geometry.centerRect.left, geometry.plot.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(geometry.centerRect.right, geometry.plot.top),
      Offset(geometry.centerRect.right, geometry.plot.bottom),
      paint,
    );
  }

  void _drawBars(Canvas canvas, _PyramidGeometry geometry) {
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final layout = geometry.items[index];
      final left = _animatedLeftRect(layout.leftRect);
      final right = _animatedRightRect(layout.rightRect);
      _drawBar(
        canvas,
        left,
        item.leftColor ?? leftColor,
        _PyramidSelection(index, SimplePopulationPyramidSide.left),
      );
      _drawBar(
        canvas,
        right,
        item.rightColor ?? rightColor,
        _PyramidSelection(index, SimplePopulationPyramidSide.right),
      );
      if (showValues && progress > 0.55) {
        _drawValues(canvas, layout, item);
      }
    }
  }

  Rect _animatedLeftRect(Rect rect) {
    final width = rect.width * progress;
    return Rect.fromLTRB(rect.right - width, rect.top, rect.right, rect.bottom);
  }

  Rect _animatedRightRect(Rect rect) {
    final width = rect.width * progress;
    return Rect.fromLTWH(rect.left, rect.top, width, rect.height);
  }

  void _drawBar(
    Canvas canvas,
    Rect rect,
    Color color,
    _PyramidSelection selection,
  ) {
    if (rect.width <= 0.4 || rect.height <= 0.4) return;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.min(barRadius, rect.height / 2)),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: selection.side == SimplePopulationPyramidSide.left
              ? Alignment.centerLeft
              : Alignment.centerRight,
          end: selection.side == SimplePopulationPyramidSide.left
              ? Alignment.centerRight
              : Alignment.centerLeft,
          colors: [color.withValues(alpha: 0.72), color],
        ).createShader(rect),
    );

    if (!showActiveBar || activeSelection != selection) return;
    final highlight = activeColor ?? color;
    canvas.drawRRect(
      rrect.inflate(3),
      Paint()..color = highlight.withValues(alpha: 0.14),
    );
    canvas.drawRRect(
      rrect.inflate(1.4),
      Paint()
        ..color = highlight.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawValues(
    Canvas canvas,
    _PyramidItemLayout layout,
    SimplePopulationPyramidData item,
  ) {
    _paintText(
      canvas,
      valueFormatter(item.leftValue),
      valueStyle,
      Offset(layout.leftRect.left - 4, layout.leftRect.center.dy),
      TextAlign.right,
      56,
      centeredY: true,
    );
    _paintText(
      canvas,
      valueFormatter(item.rightValue),
      valueStyle,
      Offset(layout.rightRect.right + 4, layout.rightRect.center.dy),
      TextAlign.left,
      56,
      centeredY: true,
    );
  }

  void _drawCenterLabels(Canvas canvas, _PyramidGeometry geometry) {
    for (var index = 0; index < data.length; index++) {
      final layout = geometry.items[index];
      _paintText(
        canvas,
        data[index].label,
        labelStyle,
        Offset(geometry.centerRect.center.dx, layout.leftRect.center.dy),
        TextAlign.center,
        math.max(0.0, geometry.centerRect.width - 4),
        centeredY: true,
      );
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

  @override
  bool shouldRepaint(covariant _SimplePopulationPyramidPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.leftLabel != leftLabel ||
        oldDelegate.rightLabel != rightLabel ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.leftColor != leftColor ||
        oldDelegate.rightColor != rightColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showCenterLabels != showCenterLabels ||
        oldDelegate.showActiveBar != showActiveBar ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.centerLabelWidth != centerLabelWidth ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.barWidthFactor != barWidthFactor ||
        oldDelegate.maxBarThickness != maxBarThickness ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _PyramidGeometry {
  final Rect plot;
  final Rect leftRect;
  final Rect centerRect;
  final Rect rightRect;
  final double maxValue;
  final List<_PyramidItemLayout> items;

  const _PyramidGeometry({
    required this.plot,
    required this.leftRect,
    required this.centerRect,
    required this.rightRect,
    required this.maxValue,
    required this.items,
  });

  factory _PyramidGeometry.resolve({
    required Size size,
    required List<SimplePopulationPyramidData> data,
    required double? maxValue,
    required EdgeInsets padding,
    required double centerLabelWidth,
    required double barWidthFactor,
    required double maxBarThickness,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0 || data.isEmpty) {
      return _PyramidGeometry(
        plot: plot,
        leftRect: Rect.zero,
        centerRect: Rect.zero,
        rightRect: Rect.zero,
        maxValue: 1,
        items: const [],
      );
    }

    final resolvedCenterWidth = math.min(centerLabelWidth, plot.width * 0.34);
    final sideWidth = math.max(0.0, (plot.width - resolvedCenterWidth) / 2);
    final leftRect = Rect.fromLTWH(plot.left, plot.top, sideWidth, plot.height);
    final centerRect = Rect.fromLTWH(
      leftRect.right,
      plot.top,
      resolvedCenterWidth,
      plot.height,
    );
    final rightRect = Rect.fromLTWH(
      centerRect.right,
      plot.top,
      sideWidth,
      plot.height,
    );
    final peak =
        maxValue ??
        data.fold<double>(
          0,
          (current, item) =>
              math.max(current, math.max(item.leftValue, item.rightValue)),
        );
    final resolvedMax = peak <= 0 ? 1.0 : peak;
    final categoryHeight = plot.height / data.length;
    final barHeight = math.min(
      maxBarThickness,
      math.max(4.0, categoryHeight * barWidthFactor),
    );
    final items = <_PyramidItemLayout>[];
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final centerY = plot.top + categoryHeight * index + categoryHeight / 2;
      final leftWidth =
          leftRect.width * (item.leftValue / resolvedMax).clamp(0, 1);
      final rightWidth =
          rightRect.width * (item.rightValue / resolvedMax).clamp(0, 1);
      items.add(
        _PyramidItemLayout(
          leftRect: Rect.fromLTRB(
            leftRect.right - leftWidth,
            centerY - barHeight / 2,
            leftRect.right,
            centerY + barHeight / 2,
          ),
          rightRect: Rect.fromLTWH(
            rightRect.left,
            centerY - barHeight / 2,
            rightWidth,
            barHeight,
          ),
        ),
      );
    }
    return _PyramidGeometry(
      plot: plot,
      leftRect: leftRect,
      centerRect: centerRect,
      rightRect: rightRect,
      maxValue: resolvedMax,
      items: items,
    );
  }
}

class _PyramidItemLayout {
  final Rect leftRect;
  final Rect rightRect;

  const _PyramidItemLayout({required this.leftRect, required this.rightRect});
}

class _PyramidSelection {
  final int index;
  final SimplePopulationPyramidSide side;

  const _PyramidSelection(this.index, this.side);

  @override
  bool operator ==(Object other) {
    return other is _PyramidSelection &&
        other.index == index &&
        other.side == side;
  }

  @override
  int get hashCode => Object.hash(index, side);
}

class _SimplePopulationPyramidVisuals {
  final Color leftColor;
  final Color rightColor;
  final Color gridColor;
  final Color axisColor;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarThickness;

  const _SimplePopulationPyramidVisuals({
    required this.leftColor,
    required this.rightColor,
    required this.gridColor,
    required this.axisColor,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarThickness,
  });

  factory _SimplePopulationPyramidVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimplePopulationPyramidVisuals(
          leftColor: colorScheme.primary,
          rightColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          axisColor: colorScheme.outline.withValues(alpha: 0.52),
          barRadius: 8,
          barWidthFactor: 0.58,
          maxBarThickness: 28,
        );
      case SimpleBarChartStyle.professional:
        return _SimplePopulationPyramidVisuals(
          leftColor: colorScheme.primary,
          rightColor: const Color(0xFF475569),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.7),
          barRadius: 4,
          barWidthFactor: 0.6,
          maxBarThickness: 24,
        );
      case SimpleBarChartStyle.education:
        return _SimplePopulationPyramidVisuals(
          leftColor: colorScheme.secondary,
          rightColor: const Color(0xFFF59E0B),
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          axisColor: colorScheme.outline.withValues(alpha: 0.62),
          barRadius: 6,
          barWidthFactor: 0.62,
          maxBarThickness: 26,
        );
      case SimpleBarChartStyle.trendy:
        return _SimplePopulationPyramidVisuals(
          leftColor: colorScheme.tertiary,
          rightColor: const Color(0xFFEC4899),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          barRadius: 10,
          barWidthFactor: 0.56,
          maxBarThickness: 30,
        );
      case SimpleBarChartStyle.elegant:
        return _SimplePopulationPyramidVisuals(
          leftColor: colorScheme.primary,
          rightColor: colorScheme.secondary,
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          barRadius: 7,
          barWidthFactor: 0.58,
          maxBarThickness: 26,
        );
    }
  }
}

class _PyramidLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final TextStyle textStyle;

  const _PyramidLegendItem({
    required this.label,
    required this.color,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: textStyle),
      ],
    );
  }
}

class _DefaultPyramidTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String label;
  final String value;

  const _DefaultPyramidTooltip({
    required this.color,
    required this.title,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onInverseSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onInverseSurface.withValues(
                        alpha: 0.76,
                      ),
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
