import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleTornadoValueFormatter = String Function(double value);

typedef SimpleTornadoTapCallback =
    void Function(
      SimpleTornadoChartData data,
      int index,
      SimpleTornadoSide side,
      double value,
      double delta,
    );

typedef SimpleTornadoTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleTornadoChartData data,
      int index,
      SimpleTornadoSide side,
      String sideLabel,
      String formattedValue,
      String formattedDelta,
    );

enum SimpleTornadoSide { low, high }

class SimpleTornadoChartData {
  final String label;
  final double low;
  final double high;
  final String? group;
  final Color? lowColor;
  final Color? highColor;

  const SimpleTornadoChartData({
    required this.label,
    required this.low,
    required this.high,
    this.group,
    this.lowColor,
    this.highColor,
  });

  double get impact => (high - low).abs();
}

/// A sensitivity chart for comparing low and high scenarios around a baseline.
class SimpleTornadoChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(
    112,
    30,
    32,
    38,
  );

  final List<SimpleTornadoChartData> data;
  final SimpleBarChartStyle style;
  final double baseline;
  final double? minValue;
  final double? maxValue;
  final String lowLabel;
  final String highLabel;
  final double height;
  final EdgeInsets padding;
  final Color? lowColor;
  final Color? highColor;
  final Color? baselineColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool sortByImpact;
  final bool showGrid;
  final bool showValues;
  final bool showLabels;
  final bool showLegend;
  final bool showBaseline;
  final bool showTooltip;
  final bool showActiveBar;
  final int gridLineCount;
  final double? barRadius;
  final double? barWidthFactor;
  final double? maxBarThickness;
  final SimpleTornadoValueFormatter? valueFormatter;
  final SimpleTornadoTapCallback? onBarTap;
  final SimpleTornadoTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleTornadoChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.baseline = 0,
    this.minValue,
    this.maxValue,
    this.lowLabel = 'Low',
    this.highLabel = 'High',
    this.height = 260,
    this.padding = _defaultPadding,
    this.lowColor,
    this.highColor,
    this.baselineColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.sortByImpact = true,
    this.showGrid = true,
    this.showValues = true,
    this.showLabels = true,
    this.showLegend = true,
    this.showBaseline = true,
    this.showTooltip = true,
    this.showActiveBar = true,
    this.gridLineCount = 4,
    this.barRadius,
    this.barWidthFactor,
    this.maxBarThickness,
    this.valueFormatter,
    this.onBarTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 720),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(baseline == baseline),
       assert(gridLineCount >= 2),
       assert(barRadius == null || barRadius >= 0),
       assert(
         barWidthFactor == null || (barWidthFactor > 0 && barWidthFactor <= 1),
       ),
       assert(maxBarThickness == null || maxBarThickness > 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleTornadoVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where(
          (item) =>
              item.label.trim().isNotEmpty &&
              item.low.isFinite &&
              item.high.isFinite,
        )
        .toList();
    if (sortByImpact) {
      visibleData.sort((a, b) => b.impact.compareTo(a.impact));
    }
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 460.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty || !baseline.isFinite) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Tornado chart, no data.',
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
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
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
          child: _SimpleTornadoChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            baseline: baseline,
            minValue: minValue,
            maxValue: maxValue,
            lowLabel: lowLabel,
            highLabel: highLabel,
            padding: padding,
            lowColor: lowColor ?? visuals.lowColor,
            highColor: highColor ?? visuals.highColor,
            baselineColor: baselineColor ?? visuals.baselineColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showValues: showValues,
            showLabels: showLabels,
            showLegend: showLegend,
            showBaseline: showBaseline,
            showTooltip: showTooltip,
            showActiveBar: showActiveBar,
            gridLineCount: gridLineCount,
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
    List<SimpleTornadoChartData> visibleData,
    SimpleTornadoValueFormatter formatter,
  ) {
    final summaries = visibleData
        .take(5)
        .map((item) {
          return '${item.label} ${formatter(item.low)} to '
              '${formatter(item.high)}, impact ${formatter(item.impact)}';
        })
        .join('; ');
    final remaining = visibleData.length - math.min(visibleData.length, 5);
    final suffix = remaining > 0 ? '; and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'driver' : 'drivers';
    return 'Tornado chart, ${visibleData.length} $countLabel around baseline '
        '${formatter(baseline)}. $summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _SimpleTornadoChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleTornadoChartData> data;
  final double baseline;
  final double? minValue;
  final double? maxValue;
  final String lowLabel;
  final String highLabel;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color baselineColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLabels;
  final bool showLegend;
  final bool showBaseline;
  final bool showTooltip;
  final bool showActiveBar;
  final int gridLineCount;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarThickness;
  final SimpleTornadoValueFormatter valueFormatter;
  final SimpleTornadoTapCallback? onBarTap;
  final SimpleTornadoTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleTornadoChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.baseline,
    required this.minValue,
    required this.maxValue,
    required this.lowLabel,
    required this.highLabel,
    required this.padding,
    required this.lowColor,
    required this.highColor,
    required this.baselineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLabels,
    required this.showLegend,
    required this.showBaseline,
    required this.showTooltip,
    required this.showActiveBar,
    required this.gridLineCount,
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
  State<_SimpleTornadoChartView> createState() =>
      _SimpleTornadoChartViewState();
}

class _SimpleTornadoChartViewState extends State<_SimpleTornadoChartView> {
  _TornadoSelection? _active;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip || widget.showActiveBar || widget.onBarTap != null;
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
                painter: _SimpleTornadoPainter(
                  data: widget.data,
                  baseline: widget.baseline,
                  minValue: widget.minValue,
                  maxValue: widget.maxValue,
                  lowLabel: widget.lowLabel,
                  highLabel: widget.highLabel,
                  padding: widget.padding,
                  lowColor: widget.lowColor,
                  highColor: widget.highColor,
                  baselineColor: widget.baselineColor,
                  gridColor: widget.gridColor,
                  axisColor: widget.axisColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showGrid: widget.showGrid,
                  showValues: widget.showValues,
                  showLabels: widget.showLabels,
                  showLegend: widget.showLegend,
                  showBaseline: widget.showBaseline,
                  showActiveBar: widget.showActiveBar,
                  gridLineCount: widget.gridLineCount,
                  barRadius: widget.barRadius,
                  barWidthFactor: widget.barWidthFactor,
                  maxBarThickness: widget.maxBarThickness,
                  active: _active,
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
                      final selection = _hitTest(details.localPosition, size);
                      _setActive(selection);
                      if (selection == null) return;
                      widget.onBarTap?.call(
                        selection.data,
                        selection.index,
                        selection.side,
                        selection.value,
                        selection.delta,
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
    );
  }

  void _setActive(_TornadoSelection? selection) {
    if (_active == selection) return;
    setState(() => _active = selection);
  }

  _TornadoSelection? _hitTest(Offset position, Size size) {
    final geometry = _TornadoGeometry.resolve(
      size: size,
      data: widget.data,
      baseline: widget.baseline,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      padding: widget.padding,
      barWidthFactor: widget.barWidthFactor,
      maxBarThickness: widget.maxBarThickness,
    );
    for (final row in geometry.rows) {
      for (final segment in [row.lowSegment, row.highSegment]) {
        final hitRect = segment.rect.inflate(
          math.max(6, segment.rect.height / 4),
        );
        if (hitRect.contains(position)) {
          return _TornadoSelection(
            data: row.data,
            index: row.index,
            side: segment.side,
            value: segment.value,
            delta: segment.value - widget.baseline,
            position: segment.rect.center,
          );
        }
      }
    }
    return null;
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    _TornadoSelection selection,
  ) {
    final sideLabel = selection.side == SimpleTornadoSide.low
        ? widget.lowLabel
        : widget.highLabel;
    final formattedValue = widget.valueFormatter(selection.value);
    final formattedDelta = _formatDelta(selection.delta);
    const tooltipWidth = 184.0;
    const tooltipHeight = 92.0;
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
            selection.data,
            selection.index,
            selection.side,
            sideLabel,
            formattedValue,
            formattedDelta,
          ) ??
          _DefaultTornadoTooltip(
            color: _sideColor(selection.data, selection.side),
            title: selection.data.label,
            sideLabel: sideLabel,
            formattedValue: formattedValue,
            formattedDelta: formattedDelta,
          ),
    );
  }

  String _formatDelta(double delta) {
    final prefix = delta > 0 ? '+' : '';
    return '$prefix${widget.valueFormatter(delta)}';
  }

  Color _sideColor(SimpleTornadoChartData data, SimpleTornadoSide side) {
    return switch (side) {
      SimpleTornadoSide.low => data.lowColor ?? widget.lowColor,
      SimpleTornadoSide.high => data.highColor ?? widget.highColor,
    };
  }
}

class _SimpleTornadoPainter extends CustomPainter {
  final List<SimpleTornadoChartData> data;
  final double baseline;
  final double? minValue;
  final double? maxValue;
  final String lowLabel;
  final String highLabel;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color baselineColor;
  final Color gridColor;
  final Color axisColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showValues;
  final bool showLabels;
  final bool showLegend;
  final bool showBaseline;
  final bool showActiveBar;
  final int gridLineCount;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarThickness;
  final _TornadoSelection? active;
  final SimpleTornadoValueFormatter valueFormatter;
  final double progress;

  const _SimpleTornadoPainter({
    required this.data,
    required this.baseline,
    required this.minValue,
    required this.maxValue,
    required this.lowLabel,
    required this.highLabel,
    required this.padding,
    required this.lowColor,
    required this.highColor,
    required this.baselineColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showValues,
    required this.showLabels,
    required this.showLegend,
    required this.showBaseline,
    required this.showActiveBar,
    required this.gridLineCount,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarThickness,
    required this.active,
    required this.valueFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _TornadoGeometry.resolve(
      size: size,
      data: data,
      baseline: baseline,
      minValue: minValue,
      maxValue: maxValue,
      padding: padding,
      barWidthFactor: barWidthFactor,
      maxBarThickness: maxBarThickness,
    );
    if (geometry.rows.isEmpty || geometry.plot.isEmpty) return;

    if (showGrid) _drawGrid(canvas, geometry);
    if (showBaseline) _drawBaseline(canvas, geometry);
    _drawRows(canvas, geometry);
    if (showLabels) _drawLabels(canvas, geometry);
    if (showLegend) _drawLegend(canvas, geometry);
  }

  void _drawGrid(Canvas canvas, _TornadoGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= gridLineCount; index++) {
      final value =
          geometry.min + geometry.span * (index / gridLineCount).toDouble();
      final x = geometry.xForValue(value);
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        paint,
      );
      _paintText(
        canvas,
        valueFormatter(value),
        valueStyle.copyWith(fontWeight: FontWeight.w500),
        Offset(x, geometry.plot.bottom + 5),
        TextAlign.center,
        58,
      );
    }
  }

  void _drawBaseline(Canvas canvas, _TornadoGeometry geometry) {
    final x = geometry.xForValue(baseline);
    canvas.drawLine(
      Offset(x, geometry.plot.top - 4),
      Offset(x, geometry.plot.bottom + 2),
      Paint()
        ..color = baselineColor
        ..strokeWidth = 1.6,
    );
    _paintText(
      canvas,
      'Base ${valueFormatter(baseline)}',
      valueStyle.copyWith(color: baselineColor),
      Offset(x, geometry.plot.top - 22),
      TextAlign.center,
      92,
    );
  }

  void _drawRows(Canvas canvas, _TornadoGeometry geometry) {
    for (final row in geometry.rows) {
      _drawSegment(canvas, row, row.lowSegment);
      _drawSegment(canvas, row, row.highSegment);
    }
  }

  void _drawSegment(
    Canvas canvas,
    _TornadoRowLayout row,
    _TornadoSegmentLayout segment,
  ) {
    if (segment.rect.width <= 0.5 || segment.rect.height <= 0) return;
    final color = _sideColor(row.data, segment.side);
    final animatedRect = _animatedRect(segment);
    if (animatedRect.width <= 0.5) return;
    final rrect = RRect.fromRectAndRadius(
      animatedRect,
      Radius.circular(math.min(barRadius, animatedRect.height / 2)),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withValues(alpha: 0.74), color],
        ).createShader(animatedRect),
    );

    final isActive = active?.index == row.index && active?.side == segment.side;
    if (showActiveBar && isActive) {
      final highlight = activeColor ?? color;
      canvas.drawRRect(
        rrect.inflate(3),
        Paint()..color = highlight.withValues(alpha: 0.16),
      );
      canvas.drawRRect(
        rrect.inflate(1.4),
        Paint()
          ..color = highlight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (showValues && progress > 0.62) {
      _drawValue(canvas, segment, animatedRect);
    }
  }

  Rect _animatedRect(_TornadoSegmentLayout segment) {
    final rect = segment.rect;
    if (segment.value >= baseline) {
      return Rect.fromLTRB(
        rect.left,
        rect.top,
        rect.left + rect.width * progress,
        rect.bottom,
      );
    }
    return Rect.fromLTRB(
      rect.right - rect.width * progress,
      rect.top,
      rect.right,
      rect.bottom,
    );
  }

  void _drawValue(Canvas canvas, _TornadoSegmentLayout segment, Rect rect) {
    final text = valueFormatter(segment.value);
    final outsideLeft = segment.value < baseline;
    final point = outsideLeft
        ? Offset(rect.left - 5, rect.center.dy)
        : Offset(rect.right + 5, rect.center.dy);
    _paintText(
      canvas,
      text,
      valueStyle,
      point,
      outsideLeft ? TextAlign.right : TextAlign.left,
      54,
      centeredY: true,
    );
  }

  void _drawLabels(Canvas canvas, _TornadoGeometry geometry) {
    final maxWidth = math.max(42.0, geometry.plot.left - 16);
    for (final row in geometry.rows) {
      _paintText(
        canvas,
        row.data.label,
        labelStyle,
        Offset(geometry.plot.left - 10, row.barRect.center.dy),
        TextAlign.right,
        maxWidth,
        centeredY: true,
      );
    }
  }

  void _drawLegend(Canvas canvas, _TornadoGeometry geometry) {
    final y = math.max(4.0, geometry.plot.top - 22);
    final lowWidth = _legendItemWidth(lowLabel);
    final highWidth = _legendItemWidth(highLabel);
    final totalWidth = lowWidth + 10 + highWidth;
    var x = math.max(geometry.plot.left, geometry.plot.right - totalWidth);
    x = _drawLegendItem(canvas, lowLabel, lowColor, Offset(x, y));
    _drawLegendItem(canvas, highLabel, highColor, Offset(x + 10, y));
  }

  double _legendItemWidth(String label) {
    const markerSize = 8.0;
    return markerSize + 5 + _measureText(label, valueStyle, 80).width;
  }

  double _drawLegendItem(Canvas canvas, String label, Color color, Offset at) {
    const markerSize = 8.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx, at.dy + 3, markerSize, markerSize),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
    final textSize = _measureText(label, valueStyle, 80);
    _paintText(
      canvas,
      label,
      valueStyle.copyWith(fontWeight: FontWeight.w600),
      Offset(at.dx + markerSize + 5, at.dy),
      TextAlign.left,
      80,
    );
    return at.dx + markerSize + 5 + textSize.width;
  }

  Color _sideColor(SimpleTornadoChartData item, SimpleTornadoSide side) {
    return switch (side) {
      SimpleTornadoSide.low => item.lowColor ?? lowColor,
      SimpleTornadoSide.high => item.highColor ?? highColor,
    };
  }

  @override
  bool shouldRepaint(covariant _SimpleTornadoPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.baseline != baseline ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lowLabel != lowLabel ||
        oldDelegate.highLabel != highLabel ||
        oldDelegate.padding != padding ||
        oldDelegate.lowColor != lowColor ||
        oldDelegate.highColor != highColor ||
        oldDelegate.baselineColor != baselineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showBaseline != showBaseline ||
        oldDelegate.showActiveBar != showActiveBar ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.barRadius != barRadius ||
        oldDelegate.barWidthFactor != barWidthFactor ||
        oldDelegate.maxBarThickness != maxBarThickness ||
        oldDelegate.active != active ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.progress != progress;
  }
}

class _TornadoGeometry {
  final Rect plot;
  final double min;
  final double max;
  final List<_TornadoRowLayout> rows;

  const _TornadoGeometry({
    required this.plot,
    required this.min,
    required this.max,
    required this.rows,
  });

  double get span => max - min;

  double xForValue(double value) {
    if (span <= 0) return plot.left;
    return plot.left + (value - min) / span * plot.width;
  }

  static _TornadoGeometry resolve({
    required Size size,
    required List<SimpleTornadoChartData> data,
    required double baseline,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required double barWidthFactor,
    required double maxBarThickness,
  }) {
    final left = padding.left.clamp(0.0, size.width * 0.6).toDouble();
    final right = padding.right.clamp(0.0, size.width * 0.35).toDouble();
    final top = padding.top.clamp(0.0, size.height * 0.45).toDouble();
    final bottom = padding.bottom.clamp(0.0, size.height * 0.45).toDouble();
    final plot = Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, size.width - right),
      math.max(top + 1, size.height - bottom),
    );
    var min = minValue ?? baseline;
    var max = maxValue ?? baseline;
    for (final item in data) {
      min = math.min(min, math.min(item.low, item.high));
      max = math.max(max, math.max(item.low, item.high));
    }
    if (min == max) {
      min -= 1;
      max += 1;
    } else {
      final pad = (max - min) * 0.06;
      min = minValue ?? (min - pad);
      max = maxValue ?? (max + pad);
    }
    if (min > baseline) min = baseline;
    if (max < baseline) max = baseline;

    final rowHeight = plot.height / math.max(1, data.length);
    final barThickness = math
        .min(rowHeight * barWidthFactor, maxBarThickness)
        .clamp(3.0, math.max(3.0, rowHeight * 0.82))
        .toDouble();
    final rows = <_TornadoRowLayout>[];
    final baselineX = _valueToX(baseline, min, max, plot);

    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final centerY = plot.top + rowHeight * index + rowHeight / 2;
      final barRect = Rect.fromLTWH(
        plot.left,
        centerY - barThickness / 2,
        plot.width,
        barThickness,
      );
      final lowX = _valueToX(item.low, min, max, plot);
      final highX = _valueToX(item.high, min, max, plot);
      rows.add(
        _TornadoRowLayout(
          data: item,
          index: index,
          barRect: barRect,
          lowSegment: _TornadoSegmentLayout(
            side: SimpleTornadoSide.low,
            value: item.low,
            rect: Rect.fromLTRB(
              math.min(lowX, baselineX),
              barRect.top,
              math.max(lowX, baselineX),
              barRect.bottom,
            ),
          ),
          highSegment: _TornadoSegmentLayout(
            side: SimpleTornadoSide.high,
            value: item.high,
            rect: Rect.fromLTRB(
              math.min(highX, baselineX),
              barRect.top,
              math.max(highX, baselineX),
              barRect.bottom,
            ),
          ),
        ),
      );
    }

    return _TornadoGeometry(plot: plot, min: min, max: max, rows: rows);
  }

  static double _valueToX(double value, double min, double max, Rect plot) {
    final span = max - min;
    if (span <= 0) return plot.left;
    return plot.left + (value - min) / span * plot.width;
  }
}

class _TornadoRowLayout {
  final SimpleTornadoChartData data;
  final int index;
  final Rect barRect;
  final _TornadoSegmentLayout lowSegment;
  final _TornadoSegmentLayout highSegment;

  const _TornadoRowLayout({
    required this.data,
    required this.index,
    required this.barRect,
    required this.lowSegment,
    required this.highSegment,
  });
}

class _TornadoSegmentLayout {
  final SimpleTornadoSide side;
  final double value;
  final Rect rect;

  const _TornadoSegmentLayout({
    required this.side,
    required this.value,
    required this.rect,
  });
}

class _TornadoSelection {
  final SimpleTornadoChartData data;
  final int index;
  final SimpleTornadoSide side;
  final double value;
  final double delta;
  final Offset position;

  const _TornadoSelection({
    required this.data,
    required this.index,
    required this.side,
    required this.value,
    required this.delta,
    required this.position,
  });

  @override
  bool operator ==(Object other) {
    return other is _TornadoSelection &&
        other.index == index &&
        other.side == side &&
        other.position == position;
  }

  @override
  int get hashCode => Object.hash(index, side, position);
}

class _SimpleTornadoVisuals {
  final Color lowColor;
  final Color highColor;
  final Color baselineColor;
  final Color gridColor;
  final Color axisColor;
  final double barRadius;
  final double barWidthFactor;
  final double maxBarThickness;

  const _SimpleTornadoVisuals({
    required this.lowColor,
    required this.highColor,
    required this.baselineColor,
    required this.gridColor,
    required this.axisColor,
    required this.barRadius,
    required this.barWidthFactor,
    required this.maxBarThickness,
  });

  static _SimpleTornadoVisuals resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    final grid = colorScheme.outlineVariant.withValues(alpha: 0.56);
    final axis = colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleTornadoVisuals(
          lowColor: const Color(0xFFF97316),
          highColor: const Color(0xFF2563EB),
          baselineColor: colorScheme.primary,
          gridColor: grid,
          axisColor: axis,
          barRadius: 5,
          barWidthFactor: 0.52,
          maxBarThickness: 24,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleTornadoVisuals(
          lowColor: const Color(0xFF64748B),
          highColor: const Color(0xFF0F766E),
          baselineColor: const Color(0xFF334155),
          gridColor: grid,
          axisColor: axis,
          barRadius: 3,
          barWidthFactor: 0.5,
          maxBarThickness: 22,
        );
      case SimpleBarChartStyle.education:
        return _SimpleTornadoVisuals(
          lowColor: const Color(0xFFF59E0B),
          highColor: const Color(0xFF22C55E),
          baselineColor: const Color(0xFF3B82F6),
          gridColor: grid,
          axisColor: axis,
          barRadius: 6,
          barWidthFactor: 0.56,
          maxBarThickness: 25,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleTornadoVisuals(
          lowColor: const Color(0xFFF43F5E),
          highColor: const Color(0xFF8B5CF6),
          baselineColor: const Color(0xFF06B6D4),
          gridColor: grid,
          axisColor: axis,
          barRadius: 7,
          barWidthFactor: 0.58,
          maxBarThickness: 26,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleTornadoVisuals(
          lowColor: const Color(0xFFBE123C),
          highColor: const Color(0xFF059669),
          baselineColor: colorScheme.primary,
          gridColor: grid,
          axisColor: axis,
          barRadius: 5,
          barWidthFactor: 0.52,
          maxBarThickness: 24,
        );
    }
  }
}

class _DefaultTornadoTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final String sideLabel;
  final String formattedValue;
  final String formattedDelta;

  const _DefaultTornadoTooltip({
    required this.color,
    required this.title,
    required this.sideLabel,
    required this.formattedValue,
    required this.formattedDelta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TornadoTooltipRow(label: sideLabel, value: formattedValue),
            _TornadoTooltipRow(label: 'Delta', value: formattedDelta),
          ],
        ),
      ),
    );
  }
}

class _TornadoTooltipRow extends StatelessWidget {
  final String label;
  final String value;

  const _TornadoTooltipRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Size _measureText(String text, TextStyle style, double maxWidth) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  return painter.size;
}

void _paintText(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset offset,
  TextAlign align,
  double maxWidth, {
  bool centeredY = false,
}) {
  if (text.isEmpty || maxWidth <= 0) return;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  var dx = offset.dx;
  if (align == TextAlign.center) {
    dx -= painter.width / 2;
  } else if (align == TextAlign.right || align == TextAlign.end) {
    dx -= painter.width;
  }
  final dy = centeredY ? offset.dy - painter.height / 2 : offset.dy;
  painter.paint(canvas, Offset(dx, dy));
}
