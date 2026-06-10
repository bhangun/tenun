import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleBulletValueFormatter = String Function(double value);
typedef SimpleBulletTapCallback =
    void Function(SimpleBulletChartData data, int index);
typedef SimpleBulletTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleBulletChartData data,
      int index,
      String formattedValue,
      String formattedTarget,
    );

class SimpleBulletRange {
  final double from;
  final double to;
  final Color? color;
  final String? label;

  const SimpleBulletRange({
    required this.from,
    required this.to,
    this.color,
    this.label,
  });
}

class SimpleBulletChartData {
  final String label;
  final double value;
  final double target;
  final double? minValue;
  final double? maxValue;
  final List<SimpleBulletRange> ranges;
  final Color? color;
  final Color? targetColor;

  const SimpleBulletChartData({
    required this.label,
    required this.value,
    required this.target,
    this.minValue,
    this.maxValue,
    this.ranges = const [],
    this.color,
    this.targetColor,
  });
}

/// A compact bullet chart for KPI performance against targets and ranges.
class SimpleBulletChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(96, 16, 48, 16);

  final List<SimpleBulletChartData> data;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final Color? valueColor;
  final Color? targetColor;
  final Color? rangeColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveBar;
  final double? barHeightFactor;
  final double? valueHeightFactor;
  final double? targetWidth;
  final SimpleBulletValueFormatter? valueFormatter;
  final SimpleBulletTapCallback? onBulletTap;
  final SimpleBulletTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleBulletChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 220,
    this.padding = _defaultPadding,
    this.valueColor,
    this.targetColor,
    this.rangeColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = true,
    this.showTooltip = true,
    this.showActiveBar = true,
    this.barHeightFactor,
    this.valueHeightFactor,
    this.targetWidth,
    this.valueFormatter,
    this.onBulletTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 650),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(
         barHeightFactor == null ||
             (barHeightFactor > 0 && barHeightFactor <= 1),
       ),
       assert(
         valueHeightFactor == null ||
             (valueHeightFactor > 0 && valueHeightFactor <= 1),
       ),
       assert(targetWidth == null || targetWidth > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleBulletVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.value.isFinite && item.target.isFinite)
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
            emptySemanticLabel: 'Bullet chart, no data.',
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
          child: _SimpleBulletChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            padding: padding,
            valueColor: valueColor ?? visuals.valueColor,
            targetColor: targetColor ?? visuals.targetColor,
            rangeColor: rangeColor ?? visuals.rangeColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showTooltip: showTooltip,
            showActiveBar: showActiveBar,
            barHeightFactor: barHeightFactor ?? visuals.barHeightFactor,
            valueHeightFactor: valueHeightFactor ?? visuals.valueHeightFactor,
            targetWidth: targetWidth ?? visuals.targetWidth,
            useGradient: visuals.useGradient,
            valueFormatter: formatter,
            onBulletTap: onBulletTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  String _defaultSemanticLabel(
    List<SimpleBulletChartData> visibleData,
    SimpleBulletValueFormatter formatter,
  ) {
    final summaries = visibleData
        .take(4)
        .map((item) {
          return '${item.label} ${formatter(item.value)} of target '
              '${formatter(item.target)}';
        })
        .join('; ');
    final remaining = visibleData.length - math.min(visibleData.length, 4);
    final suffix = remaining > 0 ? '; and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'item' : 'items';
    return 'Bullet chart, ${visibleData.length} $countLabel. '
        '$summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleBulletChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleBulletChartData> data;
  final EdgeInsets padding;
  final Color valueColor;
  final Color targetColor;
  final Color rangeColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveBar;
  final double barHeightFactor;
  final double valueHeightFactor;
  final double targetWidth;
  final bool useGradient;
  final SimpleBulletValueFormatter valueFormatter;
  final SimpleBulletTapCallback? onBulletTap;
  final SimpleBulletTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleBulletChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.padding,
    required this.valueColor,
    required this.targetColor,
    required this.rangeColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showTooltip,
    required this.showActiveBar,
    required this.barHeightFactor,
    required this.valueHeightFactor,
    required this.targetWidth,
    required this.useGradient,
    required this.valueFormatter,
    required this.onBulletTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleBulletChartView> createState() => _SimpleBulletChartViewState();
}

class _SimpleBulletChartViewState extends State<_SimpleBulletChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveBar ||
        widget.onBulletTap != null;

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
                painter: _SimpleBulletPainter(
                  data: widget.data,
                  padding: widget.padding,
                  valueColor: widget.valueColor,
                  targetColor: widget.targetColor,
                  rangeColor: widget.rangeColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showLabels: widget.showLabels,
                  showValues: widget.showValues,
                  barHeightFactor: widget.barHeightFactor,
                  valueHeightFactor: widget.valueHeightFactor,
                  targetWidth: widget.targetWidth,
                  useGradient: widget.useGradient,
                  valueFormatter: widget.valueFormatter,
                  activeIndex: widget.showActiveBar ? _activeIndex : null,
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
                      final index = _hitTest(details.localPosition, size);
                      _setActive(index);
                      if (index != null) {
                        widget.onBulletTap?.call(widget.data[index], index);
                      }
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeIndex != null)
                _buildTooltip(context, size, _activeIndex!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(int? index) {
    if (_activeIndex == index) return;
    setState(() => _activeIndex = index);
  }

  int? _hitTest(Offset position, Size size) {
    final plot = _plot(size);
    if (!plot.inflate(8).contains(position)) return null;
    final rowHeight = plot.height / widget.data.length;
    final index = ((position.dy - plot.top) / rowHeight).floor();
    return index >= 0 && index < widget.data.length ? index : null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final item = widget.data[index];
    final anchor = _anchorFor(index, size);
    final formattedValue = widget.valueFormatter(item.value);
    final formattedTarget = widget.valueFormatter(item.target);
    const tooltipWidth = 188.0;
    const tooltipHeight = 66.0;
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
            index,
            formattedValue,
            formattedTarget,
          ) ??
          _DefaultBulletTooltip(
            color: item.color ?? widget.valueColor,
            title: item.label,
            rows: [
              _BulletTooltipRow(label: 'Value', value: formattedValue),
              _BulletTooltipRow(label: 'Target', value: formattedTarget),
            ],
          ),
    );
  }

  Offset _anchorFor(int index, Size size) {
    final plot = _plot(size);
    final rowHeight = plot.height / widget.data.length;
    final rowTop = plot.top + rowHeight * index;
    final item = widget.data[index];
    final range = _rangeFor(item);
    final x = _xForValue(item.value, plot, range).clamp(plot.left, plot.right);
    return Offset(x.toDouble(), rowTop + rowHeight / 2);
  }

  Rect _plot(Size size) {
    final leftPadding = widget.showLabels
        ? widget.padding.left
        : math.min(widget.padding.left, 16.0);
    final rightPadding = widget.showValues
        ? widget.padding.right
        : math.min(widget.padding.right, 16.0);
    return Rect.fromLTWH(
      leftPadding,
      widget.padding.top,
      math.max(0.0, size.width - leftPadding - rightPadding),
      math.max(0.0, size.height - widget.padding.vertical),
    );
  }

  _BulletRange _rangeFor(SimpleBulletChartData item) {
    return _resolveBulletRange(item);
  }

  double _xForValue(double value, Rect plot, _BulletRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.left + normalized * plot.width;
  }
}

class _SimpleBulletPainter extends CustomPainter {
  final List<SimpleBulletChartData> data;
  final EdgeInsets padding;
  final Color valueColor;
  final Color targetColor;
  final Color rangeColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final double barHeightFactor;
  final double valueHeightFactor;
  final double targetWidth;
  final bool useGradient;
  final SimpleBulletValueFormatter valueFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleBulletPainter({
    required this.data,
    required this.padding,
    required this.valueColor,
    required this.targetColor,
    required this.rangeColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.barHeightFactor,
    required this.valueHeightFactor,
    required this.targetWidth,
    required this.useGradient,
    required this.valueFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plot(size);
    if (plot.width <= 0 || plot.height <= 0 || data.isEmpty) return;

    final rowHeight = plot.height / data.length;
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final rowTop = plot.top + rowHeight * index;
      final row = Rect.fromLTWH(plot.left, rowTop, plot.width, rowHeight);
      _drawRow(canvas, plot, row, item, index);
    }
  }

  Rect _plot(Size size) {
    final leftPadding = showLabels
        ? padding.left
        : math.min(padding.left, 16.0);
    final rightPadding = showValues
        ? padding.right
        : math.min(padding.right, 16.0);
    return Rect.fromLTWH(
      leftPadding,
      padding.top,
      math.max(0.0, size.width - leftPadding - rightPadding),
      math.max(0.0, size.height - padding.vertical),
    );
  }

  void _drawRow(
    Canvas canvas,
    Rect plot,
    Rect row,
    SimpleBulletChartData item,
    int index,
  ) {
    final range = _resolveBulletRange(item);
    final rowCenter = row.center.dy;
    final trackHeight = math.max(8.0, row.height * barHeightFactor);
    final valueHeight = math.max(4.0, trackHeight * valueHeightFactor);
    final track = Rect.fromLTWH(
      row.left,
      rowCenter - trackHeight / 2,
      row.width,
      trackHeight,
    );
    final valueX = _xForValue(item.value, plot, range);
    final zeroX = _xForValue(0, plot, range).clamp(plot.left, plot.right);
    final animatedValueX = zeroX + (valueX - zeroX) * progress;
    final valueRect = Rect.fromLTRB(
      math.min(zeroX, animatedValueX).toDouble(),
      rowCenter - valueHeight / 2,
      math.max(zeroX, animatedValueX).toDouble(),
      rowCenter + valueHeight / 2,
    );

    if (index == activeIndex) {
      canvas.drawRect(
        Rect.fromLTWH(plot.left, row.top, plot.width, row.height),
        Paint()
          ..color = (activeColor ?? item.color ?? valueColor).withValues(
            alpha: 0.055,
          ),
      );
    }

    _drawRanges(canvas, track, item, range);

    if (valueRect.width > 0.5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(valueRect, Radius.circular(valueHeight / 2)),
        _valuePaint(item.color ?? valueColor, valueRect),
      );
    }

    _drawTarget(canvas, plot, rowCenter, item, range, trackHeight);
    _drawLabels(canvas, plot, row, item);
  }

  void _drawRanges(
    Canvas canvas,
    Rect track,
    SimpleBulletChartData item,
    _BulletRange range,
  ) {
    final ranges = item.ranges.isEmpty
        ? _defaultRanges(range, rangeColor)
        : item.ranges;
    for (var index = 0; index < ranges.length; index++) {
      final band = ranges[index];
      if (!band.from.isFinite || !band.to.isFinite) continue;
      final left = _xForValue(
        band.from,
        track,
        range,
      ).clamp(track.left, track.right);
      final right = _xForValue(
        band.to,
        track,
        range,
      ).clamp(track.left, track.right);
      final rect = Rect.fromLTRB(
        math.min(left, right).toDouble(),
        track.top,
        math.max(left, right).toDouble(),
        track.bottom,
      );
      if (rect.width <= 0.5) continue;

      final color =
          band.color ??
          rangeColor.withValues(alpha: (0.26 - index * 0.055).clamp(0.1, 0.26));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(track.height / 2)),
        Paint()..color = color,
      );
    }
  }

  List<SimpleBulletRange> _defaultRanges(_BulletRange range, Color color) {
    final span = range.span;
    return [
      SimpleBulletRange(
        from: range.min,
        to: range.min + span * 0.55,
        color: color.withValues(alpha: 0.16),
      ),
      SimpleBulletRange(
        from: range.min + span * 0.55,
        to: range.min + span * 0.82,
        color: color.withValues(alpha: 0.24),
      ),
      SimpleBulletRange(
        from: range.min + span * 0.82,
        to: range.max,
        color: color.withValues(alpha: 0.32),
      ),
    ];
  }

  void _drawTarget(
    Canvas canvas,
    Rect plot,
    double rowCenter,
    SimpleBulletChartData item,
    _BulletRange range,
    double trackHeight,
  ) {
    final targetX = _xForValue(
      item.target,
      plot,
      range,
    ).clamp(plot.left, plot.right);
    final markerHeight = trackHeight * 1.28;
    final rect = Rect.fromCenter(
      center: Offset(targetX.toDouble(), rowCenter),
      width: targetWidth,
      height: markerHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(targetWidth / 2)),
      Paint()..color = item.targetColor ?? targetColor,
    );
  }

  void _drawLabels(
    Canvas canvas,
    Rect plot,
    Rect row,
    SimpleBulletChartData item,
  ) {
    if (showLabels) {
      final painter = _textPainter(
        item.label,
        labelStyle,
        maxWidth: padding.left - 12,
        textAlign: TextAlign.right,
      )..layout(maxWidth: padding.left - 12);
      painter.paint(
        canvas,
        Offset(
          plot.left - painter.width - 8,
          row.center.dy - painter.height / 2,
        ),
      );
    }

    if (showValues) {
      final painter = _textPainter(
        valueFormatter(item.value),
        valueStyle,
        maxWidth: padding.right - 10,
      )..layout(maxWidth: padding.right - 10);
      painter.paint(
        canvas,
        Offset(plot.right + 8, row.center.dy - painter.height / 2),
      );
    }
  }

  Paint _valuePaint(Color color, Rect rect) {
    if (!useGradient) return Paint()..color = color;
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [color.withValues(alpha: 0.78), color.withValues(alpha: 0.98)],
      ).createShader(rect);
  }

  double _xForValue(double value, Rect plot, _BulletRange range) {
    final normalized = (value - range.min) / range.span;
    return plot.left + normalized * plot.width;
  }

  TextPainter _textPainter(
    String text,
    TextStyle style, {
    double? maxWidth,
    TextAlign textAlign = TextAlign.left,
  }) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
      ellipsis: maxWidth == null ? null : '...',
    );
  }

  @override
  bool shouldRepaint(covariant _SimpleBulletPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.padding != padding ||
        oldDelegate.valueColor != valueColor ||
        oldDelegate.targetColor != targetColor ||
        oldDelegate.rangeColor != rangeColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.barHeightFactor != barHeightFactor ||
        oldDelegate.valueHeightFactor != valueHeightFactor ||
        oldDelegate.targetWidth != targetWidth ||
        oldDelegate.useGradient != useGradient ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

_BulletRange _resolveBulletRange(SimpleBulletChartData item) {
  var lower = item.minValue ?? math.min(0.0, math.min(item.value, item.target));
  var upper = item.maxValue ?? math.max(item.value, item.target);

  for (final range in item.ranges) {
    if (!range.from.isFinite || !range.to.isFinite) continue;
    lower = math.min(lower, math.min(range.from, range.to));
    upper = math.max(upper, math.max(range.from, range.to));
  }

  if (lower > upper) {
    final previousLower = lower;
    lower = upper;
    upper = previousLower;
  }

  if (lower == upper) {
    final pad = lower == 0 ? 1.0 : lower.abs() * 0.2;
    lower -= pad;
    upper += pad;
  } else {
    final pad = (upper - lower).abs() * 0.06;
    lower -= pad;
    upper += pad;
  }

  return _BulletRange(lower, upper);
}

class _SimpleBulletVisuals {
  final Color valueColor;
  final Color targetColor;
  final Color rangeColor;
  final double barHeightFactor;
  final double valueHeightFactor;
  final double targetWidth;
  final bool useGradient;

  const _SimpleBulletVisuals({
    required this.valueColor,
    required this.targetColor,
    required this.rangeColor,
    required this.barHeightFactor,
    required this.valueHeightFactor,
    required this.targetWidth,
    required this.useGradient,
  });

  factory _SimpleBulletVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleBulletVisuals(
          valueColor: colorScheme.primary,
          targetColor: colorScheme.onSurface,
          rangeColor: colorScheme.primary,
          barHeightFactor: 0.42,
          valueHeightFactor: 0.42,
          targetWidth: 3,
          useGradient: true,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleBulletVisuals(
          valueColor: colorScheme.primary,
          targetColor: colorScheme.onSurface,
          rangeColor: colorScheme.outline,
          barHeightFactor: 0.38,
          valueHeightFactor: 0.36,
          targetWidth: 2.4,
          useGradient: false,
        );
      case SimpleBarChartStyle.education:
        return _SimpleBulletVisuals(
          valueColor: colorScheme.secondary,
          targetColor: colorScheme.onSurface,
          rangeColor: colorScheme.secondary,
          barHeightFactor: 0.4,
          valueHeightFactor: 0.42,
          targetWidth: 3,
          useGradient: false,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleBulletVisuals(
          valueColor: colorScheme.tertiary,
          targetColor: colorScheme.onSurface,
          rangeColor: colorScheme.tertiary,
          barHeightFactor: 0.44,
          valueHeightFactor: 0.42,
          targetWidth: 3.4,
          useGradient: true,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleBulletVisuals(
          valueColor: colorScheme.primary,
          targetColor: colorScheme.onSurface,
          rangeColor: colorScheme.primary,
          barHeightFactor: 0.4,
          valueHeightFactor: 0.4,
          targetWidth: 2.8,
          useGradient: true,
        );
    }
  }
}

class _DefaultBulletTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final List<_BulletTooltipRow> rows;

  const _DefaultBulletTooltip({
    required this.color,
    required this.title,
    required this.rows,
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
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
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
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: TextStyle(
                          color: colorScheme.onInverseSurface.withValues(
                            alpha: 0.78,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      row.value,
                      style: TextStyle(
                        color: colorScheme.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletTooltipRow {
  final String label;
  final String value;

  const _BulletTooltipRow({required this.label, required this.value});
}

class _BulletRange {
  final double min;
  final double max;

  const _BulletRange(this.min, this.max);

  double get span => max - min;
}
