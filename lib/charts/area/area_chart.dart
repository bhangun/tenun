import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_animation_system.dart';
import 'package:tenun_core/core/chart_controller.dart';
import 'package:tenun_core/core/series.dart';
import 'package:tenun_core/core/utils/helper.dart';
import 'area_chart_config.dart';

const double _chartLeftPadding = 48;
const double _chartRightPadding = 12;
const double _chartTopPadding = 12;
const double _chartBottomPadding = 26;
const int _yDivisions = 5;

class AreaChartWidget extends StatefulWidget {
  final AreaChartConfig config;

  const AreaChartWidget({super.key, required this.config});

  @override
  State<AreaChartWidget> createState() => _AreaChartWidgetState();
}

class _AreaChartWidgetState extends State<AreaChartWidget>
    with SingleTickerProviderStateMixin {
  late final ChartAnimationController _anim;
  int? _activeIndex;
  Offset? _pointerLocal;

  @override
  void initState() {
    super.initState();
    _anim = ChartAnimationController(
      vsync: this,
      preset: ChartAnimationPreset.draw,
    );
    _anim.addListener(() => setState(() {}));
    _anim.forward();
  }

  @override
  void didUpdateWidget(covariant AreaChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.series != widget.config.series) {
      _anim.replay();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    if (config.series.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    final chartData = _AreaChartData.fromConfig(config);
    if (chartData.xLabels.isEmpty || chartData.seriesData.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.title?.text != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              config.title!.text!,
              style: TextStyle(
                fontSize: config.title?.fontSize ?? 16,
                fontWeight: FontWeight.w600,
                color: _safeColor(config.title?.textStyle.color, Colors.black),
              ),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              return Stack(
                children: [
                  MouseRegion(
                    onHover: (event) =>
                        _onPointer(event.localPosition, canvasSize, chartData),
                    onExit: (_) => _clearPointer(),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _onPointer(
                        details.localPosition,
                        canvasSize,
                        chartData,
                      ),
                      onTapUp: (_) => _clearPointer(),
                      onPanUpdate: (details) => _onPointer(
                        details.localPosition,
                        canvasSize,
                        chartData,
                      ),
                      onPanEnd: (_) => _clearPointer(),
                      onPanCancel: _clearPointer,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _AreaChartPainter(
                          config: config,
                          data: chartData,
                          activeIndex: _activeIndex,
                          progress: _anim.progress,
                        ),
                      ),
                    ),
                  ),
                  if (config.legend?.show == true)
                    _buildCanvasLegend(
                      size: canvasSize,
                      config: config,
                      data: chartData,
                    ),
                  if (_shouldShowTooltip(config, chartData))
                    _buildTooltip(
                      size: canvasSize,
                      config: config,
                      data: chartData,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCanvasLegend({
    required Size size,
    required AreaChartConfig config,
    required _AreaChartData data,
  }) {
    final legend = config.legend!;
    final alignment = _legendAlignment(legend);
    final insets = _legendInsets(legend, size);
    final isVertical = (legend.orient ?? '').toLowerCase() == 'vertical';

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _safeColor(legend.backgroundColor, Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: (legend.borderWidth ?? 0) > 0
            ? Border.all(
                color: _safeColor(legend.borderColor, Colors.black12),
                width: legend.borderWidth!,
              )
            : null,
      ),
      child: Wrap(
        direction: isVertical ? Axis.vertical : Axis.horizontal,
        spacing: 12,
        runSpacing: 8,
        children: data.seriesData.map((series) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: legend.iconSize,
                height: legend.iconSize,
                decoration: BoxDecoration(
                  color: series.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                series.name,
                style: TextStyle(
                  color: _safeColor(legend.textColor, Colors.black87),
                  fontSize: legend.fontSize,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: insets,
          child: Align(alignment: alignment, child: content),
        ),
      ),
    );
  }

  Alignment _legendAlignment(dynamic legend) {
    double x = 1;
    double y = -1;

    final left = (legend.left ?? '').toString().toLowerCase();
    final right = (legend.right ?? '').toString().toLowerCase();
    final top = (legend.top ?? '').toString().toLowerCase();
    final bottom = (legend.bottom ?? '').toString().toLowerCase();

    if (left == 'left') x = -1;
    if (left == 'center') x = 0;
    if (left == 'right' || right == 'right') x = 1;
    if (right == 'left') x = -1;
    if (right == 'center') x = 0;

    if (top == 'top') y = -1;
    if (top == 'middle' || top == 'center') y = 0;
    if (top == 'bottom' || bottom == 'bottom') y = 1;
    if (bottom == 'top') y = -1;
    if (bottom == 'middle' || bottom == 'center') y = 0;

    return Alignment(x, y);
  }

  EdgeInsets _legendInsets(dynamic legend, Size size) {
    final left = _parseLegendDistance(legend.left, size.width);
    final right = _parseLegendDistance(legend.right, size.width);
    final top = _parseLegendDistance(legend.top, size.height);
    final bottom = _parseLegendDistance(legend.bottom, size.height);

    return EdgeInsets.fromLTRB(left ?? 8, top ?? 8, right ?? 8, bottom ?? 8);
  }

  double? _parseLegendDistance(dynamic value, double max) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is! String) return null;

    final v = value.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'left' || v == 'right' || v == 'top' || v == 'bottom') return 8;
    if (v == 'center' || v == 'middle') return 0;
    if (v.endsWith('%')) {
      final p = double.tryParse(v.substring(0, v.length - 1));
      if (p == null) return null;
      return (p / 100) * max;
    }
    return double.tryParse(v);
  }

  void _onPointer(Offset localPosition, Size size, _AreaChartData data) {
    if (!(widget.config.tooltip?.show ?? true)) return;

    final chartRect = _chartRectForSize(size);
    if (!chartRect.contains(localPosition) || data.xLabels.length <= 1) {
      _clearPointer();
      return;
    }

    final index = _indexForLocalX(
      localPosition.dx,
      chartRect,
      data.xLabels.length,
    );
    setState(() {
      _activeIndex = index;
      _pointerLocal = localPosition;
    });
  }

  void _clearPointer() {
    if (_activeIndex == null && _pointerLocal == null) return;
    setState(() {
      _activeIndex = null;
      _pointerLocal = null;
    });
  }

  bool _shouldShowTooltip(AreaChartConfig config, _AreaChartData data) {
    return (config.tooltip?.show ?? true) &&
        _activeIndex != null &&
        _pointerLocal != null &&
        _activeIndex! >= 0 &&
        _activeIndex! < data.xLabels.length;
  }

  Widget _buildTooltip({
    required Size size,
    required AreaChartConfig config,
    required _AreaChartData data,
  }) {
    final tooltip = config.tooltip;
    final index = _activeIndex!;
    final category = data.xLabels[index];
    final precision = tooltip?.precision ?? 2;

    final entries = data.seriesData
        .map(
          (series) => _TooltipEntry(
            name: series.name,
            color: series.color,
            value: series.values[index],
          ),
        )
        .toList();

    final textColor = _safeColor(tooltip?.textColor, Colors.white);
    final bgColor = _safeColor(tooltip?.backgroundColor, Colors.black87);
    final borderColor = _safeColor(tooltip?.borderColor, Colors.transparent);
    final borderWidth = tooltip?.borderWidth ?? 0;
    final borderRadius = tooltip?.borderRadius ?? 8;
    final padding = tooltip?.padding ?? 10;
    final fontSize = tooltip?.fontSize ?? 12;

    const tooltipWidth = 200.0;
    final tooltipHeight = 30.0 + (entries.length * 20.0);
    final pointer = _pointerLocal!;

    var left = pointer.dx + 12;
    var top = pointer.dy - tooltipHeight - 8;

    if (left + tooltipWidth > size.width) {
      left = size.width - tooltipWidth - 8;
    }
    if (left < 8) left = 8;

    if (top < 8) {
      top = pointer.dy + 12;
    }
    if (top + tooltipHeight > size.height) {
      top = size.height - tooltipHeight - 8;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: tooltipWidth,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: borderWidth > 0
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                ),
              ),
              const SizedBox(height: 6),
              ...entries.map((entry) {
                final formatted = _formatTooltipLine(
                  formatter: tooltip?.formatter,
                  seriesName: entry.name,
                  category: category,
                  value: entry.value,
                  precision: precision,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: entry.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          formatted,
                          style: TextStyle(
                            color: textColor,
                            fontSize: fontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTooltipLine({
    required String? formatter,
    required String seriesName,
    required String category,
    required double value,
    required int precision,
  }) {
    final valueText = value.toStringAsFixed(precision);
    if (formatter == null || formatter.trim().isEmpty) {
      return '$seriesName: $valueText';
    }

    return formatter
        .replaceAll('{a}', seriesName)
        .replaceAll('{b}', category)
        .replaceAll('{c}', valueText)
        .replaceAll('{value}', valueText)
        .replaceAll('{series}', seriesName)
        .replaceAll('{category}', category);
  }

  int _indexForLocalX(double localX, Rect chartRect, int count) {
    if (count <= 1) return 0;
    final step = chartRect.width / (count - 1);
    final raw = ((localX - chartRect.left) / step).round();
    return raw.clamp(0, count - 1);
  }
}

class _AreaChartPainter extends CustomPainter {
  final AreaChartConfig config;
  final _AreaChartData data;
  final int? activeIndex;
  final double progress;

  _AreaChartPainter({
    required this.config,
    required this.data,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = _chartRectForSize(size);

    if (chartRect.width <= 0 || chartRect.height <= 0) return;
    data.scaled(chartRect, progress);

    _drawGrid(canvas, chartRect);
    _drawAxes(canvas, chartRect);

    if (activeIndex != null &&
        activeIndex! >= 0 &&
        activeIndex! < data.xLabels.length) {
      final x = _xForIndex(activeIndex!, data.xLabels.length, chartRect);
      final highlightPaint = Paint()
        ..color = _safeColor(
          config.tooltip?.axisPointer?.lineStyle?.color,
          Colors.grey.shade400,
        ).withValues(alpha: 0.7)
        ..strokeWidth = config.tooltip?.axisPointer?.lineStyle?.width ?? 1;
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        highlightPaint,
      );
    }

    for (int i = 0; i < data.seriesData.length; i++) {
      _drawSeries(canvas, chartRect, data.seriesData[i]);
    }

    _drawXAxisLabels(canvas, chartRect);
    _drawYAxisLabels(canvas, chartRect);
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    if (config.grid?.show == false) return;

    final horizontalPaint = Paint()
      ..color = _safeColor(config.grid?.horizontalColor, Colors.grey.shade300)
      ..strokeWidth = config.grid?.horizontalWidth ?? 0.8;

    final verticalPaint = Paint()
      ..color = _safeColor(config.grid?.verticalColor, Colors.grey.shade300)
      ..strokeWidth = config.grid?.verticalWidth ?? 0.8;

    if (config.grid?.showHorizontalLines ?? true) {
      for (int i = 0; i <= _yDivisions; i++) {
        final t = i / _yDivisions;
        final y = rect.bottom - (t * rect.height);
        canvas.drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          horizontalPaint,
        );
      }
    }

    if (config.grid?.showVerticalLines ?? true) {
      final count = data.xLabels.length;
      for (int i = 0; i < count; i++) {
        final x = _xForIndex(i, count, rect);
        canvas.drawLine(
          Offset(x, rect.top),
          Offset(x, rect.bottom),
          verticalPaint,
        );
      }
    }
  }

  void _drawAxes(Canvas canvas, Rect rect) {
    final axisColor = _safeColor(
      config.xAxis?.axisLine?.lineStyle?.color,
      Colors.grey.shade500,
    );
    final axisWidth = config.xAxis?.axisLine?.lineStyle?.width ?? 1.0;
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = axisWidth;

    final showXAxis = config.xAxis?.show ?? true;
    final showYAxis = config.yAxis?.show ?? true;

    if (showXAxis) {
      canvas.drawLine(
        Offset(rect.left, rect.bottom),
        Offset(rect.right, rect.bottom),
        axisPaint,
      );
    }

    if (showYAxis) {
      canvas.drawLine(
        Offset(rect.left, rect.top),
        Offset(rect.left, rect.bottom),
        axisPaint,
      );
    }
  }

  void _drawSeries(Canvas canvas, Rect rect, _AreaSeriesData series) {
    if (series.points.isEmpty) return;

    final linePath = Path();
    final areaPath = Path();

    final first = series.points.first;
    linePath.moveTo(first.dx, first.dy);
    areaPath.moveTo(first.dx, rect.bottom);
    areaPath.lineTo(first.dx, first.dy);

    for (int i = 1; i < series.points.length; i++) {
      final current = series.points[i - 1];
      final next = series.points[i];

      if (config.curveSmoothness > 0) {
        final distance =
            (next.dx - current.dx) * config.curveSmoothness.clamp(0.0, 0.5);
        final cp1 = Offset(current.dx + distance, current.dy);
        final cp2 = Offset(next.dx - distance, next.dy);
        linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
        areaPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
      } else {
        linePath.lineTo(next.dx, next.dy);
        areaPath.lineTo(next.dx, next.dy);
      }
    }

    areaPath.lineTo(series.points.last.dx, rect.bottom);
    areaPath.close();

    final resolvedAreaColor = _resolveAreaColor(series.color);
    final areaPaint = Paint()..style = PaintingStyle.fill;

    if (config.gradientArea) {
      areaPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          resolvedAreaColor.withValues(alpha: config.areaOpacity),
          resolvedAreaColor.withValues(alpha: 0.04),
        ],
      ).createShader(rect);
    } else {
      areaPaint.color = resolvedAreaColor.withValues(alpha: config.areaOpacity);
    }

    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = series.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = series.width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    if (config.showDots) {
      final fillPaint = Paint()..style = PaintingStyle.fill;
      final outlinePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      for (int i = 0; i < series.points.length; i++) {
        final point = series.points[i];
        fillPaint.color = series.color;
        final isActive = activeIndex != null && activeIndex == i;
        final radius = isActive ? (config.dotSize / 2) + 2 : config.dotSize / 2;
        canvas.drawCircle(point, radius, fillPaint);
        canvas.drawCircle(point, radius, outlinePaint);
      }
    }
  }

  void _drawXAxisLabels(Canvas canvas, Rect rect) {
    final labels = data.xLabels;
    if (labels.isEmpty) return;

    final showLabels = config.xAxis?.axisLabel?.show ?? true;
    if (!showLabels) return;

    final textStyle = TextStyle(
      color: _safeColor(config.xAxis?.color, Colors.grey.shade700),
      fontSize: config.xAxis?.fontSize ?? 10,
    );

    final step = labels.length > 6 ? (labels.length / 6).ceil() : 1;

    for (int i = 0; i < labels.length; i += step) {
      final painter = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 72);

      final x = _xForIndex(i, labels.length, rect) - (painter.width / 2);
      painter.paint(canvas, Offset(x, rect.bottom + 6));
    }
  }

  void _drawYAxisLabels(Canvas canvas, Rect rect) {
    final showLabels = config.yAxis?.axisLabel?.show ?? true;
    if (!showLabels) return;

    final textStyle = TextStyle(
      color: _safeColor(config.yAxis?.color, Colors.grey.shade700),
      fontSize: config.yAxis?.fontSize ?? 10,
    );

    final precision = config.yAxis?.precision ?? 0;

    for (int i = 0; i <= _yDivisions; i++) {
      final t = i / _yDivisions;
      final value = data.minY + ((data.maxY - data.minY) * t);
      final y = rect.bottom - (t * rect.height);

      final painter = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(precision),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 40);

      painter.paint(
        canvas,
        Offset(rect.left - painter.width - 8, y - (painter.height / 2)),
      );
    }
  }

  double _xForIndex(int index, int count, Rect rect) {
    if (count <= 1) return rect.left;
    return rect.left + (index / (count - 1)) * rect.width;
  }

  Color _resolveAreaColor(Color fallback) {
    if (config.areaColor.isNotEmpty) {
      return _safeColor(config.areaColor, fallback);
    }
    return fallback;
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.data != data ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _AreaChartData {
  final List<String> xLabels;
  final List<_AreaSeriesData> seriesData;
  final double minY;
  final double maxY;

  const _AreaChartData({
    required this.xLabels,
    required this.seriesData,
    required this.minY,
    required this.maxY,
  });

  factory _AreaChartData.fromConfig(AreaChartConfig config) {
    final allLabels = _resolveXLabels(config);
    final labelsLengthAll = allLabels.length;
    final visibleRange = (config.controller?.zoom ?? ZoomRange.full)
        .visibleIndexRange(labelsLengthAll);
    final startIndex = visibleRange.start;
    final endIndex = visibleRange.end;
    final categoryLabels = visibleRange.isEmpty
        ? const <String>[]
        : allLabels.sublist(startIndex, endIndex + 1);
    final labelsLength = categoryLabels.length;

    if (labelsLength == 0) {
      return const _AreaChartData(
        xLabels: [],
        seriesData: [],
        minY: 0,
        maxY: 1,
      );
    }

    final List<_AreaSeriesData> computedSeries = [];
    double minValue = 0;
    double maxValue = config.maxY > 0 ? config.maxY : 0;

    for (int i = 0; i < config.series.length; i++) {
      final series = config.series[i];
      final values = _extractValues(
        series,
        labelsLengthAll,
      ).sublist(startIndex, endIndex + 1);
      if (values.isEmpty) continue;

      final minSeriesValue = values.reduce((a, b) => a < b ? a : b);
      final maxSeriesValue = values.reduce((a, b) => a > b ? a : b);

      if (minSeriesValue < minValue) minValue = minSeriesValue;
      if (maxSeriesValue > maxValue) maxValue = maxSeriesValue;

      final seriesColor =
          series.color ??
          _safeColor(series.itemStyle?.color, getDefaultSeriesColor(i));

      computedSeries.add(
        _AreaSeriesData(
          name: series.name ?? 'Series ${i + 1}',
          values: values,
          color: seriesColor,
          width: series.width ?? 2,
        ),
      );
    }

    if (maxValue <= minValue) {
      maxValue = minValue + 1;
    }

    final paddedMax = maxValue * 1.1;

    return _AreaChartData(
      xLabels: categoryLabels,
      seriesData: computedSeries,
      minY: minValue < 0 ? minValue : 0,
      maxY: paddedMax,
    );
  }

  static List<String> _resolveXLabels(AreaChartConfig config) {
    if (config.xAxis?.data != null && config.xAxis!.data!.isNotEmpty) {
      return config.xAxis!.data!.map((e) => '$e').toList();
    }

    final maxLength = config.series.fold<int>(0, (max, s) {
      final len = s.data?.length ?? 0;
      return len > max ? len : max;
    });

    if (maxLength == 0) return [];
    return List.generate(maxLength, (index) => (index + 1).toString());
  }

  static List<double> _extractValues(Series series, int targetLength) {
    final raw = series.data;
    if (raw == null || raw.isEmpty) return [];

    final values = <double>[];

    for (final item in raw) {
      if (item is num) {
        values.add(item.toDouble());
      } else if (item is Map<String, dynamic>) {
        final value = item['y'] ?? item['value'];
        if (value is num) values.add(value.toDouble());
      } else if (item is List && item.isNotEmpty) {
        final value = item.last;
        if (value is num) values.add(value.toDouble());
      }
    }

    if (values.length < targetLength) {
      values.addAll(List.filled(targetLength - values.length, 0));
    }

    return values.take(targetLength).toList();
  }
}

class _AreaSeriesData {
  final String name;
  final List<double> values;
  final Color color;
  final double width;
  final List<Offset> points;

  _AreaSeriesData({
    required this.name,
    required this.values,
    required this.color,
    required this.width,
    List<Offset>? points,
  }) : points = points ?? [];
}

class _TooltipEntry {
  final String name;
  final Color color;
  final double value;

  const _TooltipEntry({
    required this.name,
    required this.color,
    required this.value,
  });
}

Color _safeColor(String? color, Color fallback) {
  return safeStringToColor(color, fallback);
}

Rect _chartRectForSize(Size size) {
  return Rect.fromLTRB(
    _chartLeftPadding,
    _chartTopPadding,
    size.width - _chartRightPadding,
    size.height - _chartBottomPadding,
  );
}

extension on _AreaSeriesData {
  void addAllScaledPoints(
    Rect rect,
    double minY,
    double maxY,
    int total,
    double progress,
  ) {
    points.clear();
    if (values.isEmpty) return;

    for (int i = 0; i < values.length; i++) {
      final x = total <= 1
          ? rect.left
          : rect.left + (i / (total - 1)) * rect.width;
      final normalized = (values[i] - minY) / (maxY - minY);
      final y = rect.bottom - (normalized * rect.height * progress);
      points.add(Offset(x, y));
    }
  }
}

extension on _AreaChartData {
  _AreaChartData scaled(Rect rect, double progress) {
    for (final series in seriesData) {
      series.addAllScaledPoints(rect, minY, maxY, xLabels.length, progress);
    }
    return this;
  }
}
