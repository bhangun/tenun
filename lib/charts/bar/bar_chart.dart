import 'package:flutter/material.dart';

import '../../core/chart_animation_system.dart';
import '../../core/chart_controller.dart';
import '../../core/chart_data_value_reader.dart';
import '../../core/chart_data_signature.dart';
import '../../core/utils/helper.dart';
import 'bar_config.dart';

/// Bar chart widget that renders based on configuration using CustomPainter
class BarChartWidget extends StatefulWidget {
  final BarChartConfig config;

  const BarChartWidget({super.key, required this.config});

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget>
    with SingleTickerProviderStateMixin {
  late final ChartAnimationController _anim;
  late String _configSignature;
  Offset? _hoverPosition;
  Map<String, dynamic>? _tooltipData;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _configSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _anim = ChartAnimationController(
      vsync: this,
      preset: ChartAnimationPreset.grow,
    );
    _anim.addListener(() => setState(() {}));
    _anim.forward();
  }

  @override
  void didUpdateWidget(covariant BarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    if (nextSignature != _configSignature) {
      _configSignature = nextSignature;
      _anim.replay();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _hideTooltip();
    super.dispose();
  }

  void _showTooltip(Offset position, Map<String, dynamic> data) {
    _hideTooltip();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 150,
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: Offset(0, -60),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: Colors.black.withValues(alpha: 0.85),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data['label'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(
                    data['values']?.length ?? 0,
                    (index) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: data['colors']?[index] ?? Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${data['seriesNames']?[index] ?? ''}: ${data['values']?[index] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _tooltipData = null;
  }

  @override
  Widget build(BuildContext context) {
    final maxY = widget.config.maxY ?? widget.config.getMaxSeriesValue();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.config.title != null) _buildTitle(context),
        Expanded(
          child: MouseRegion(
            onExit: (_) => _hideTooltip(),
            child: CompositedTransformTarget(
              link: _layerLink,
              child: GestureDetector(
                onTapDown: widget.config.tooltip?.show == true
                    ? (details) {
                        if (_tooltipData != null && _hoverPosition != null) {
                          _showTooltip(_hoverPosition!, _tooltipData!);
                        }
                      }
                    : null,
                child: _buildChart(context, maxY),
              ),
            ),
          ),
        ),
        if (widget.config.legend != null && widget.config.legend!.show)
          Padding(padding: const EdgeInsets.all(8.0), child: _createLegend()),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.config.title!.text!,
            style: TextStyle(
              fontSize: widget.config.title!.fontSize ?? 16,
              fontWeight: FontWeight.bold,
              color:
                  widget.config.title!.color ??
                  Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          if (widget.config.title!.subtext != null &&
              widget.config.title!.subtext!.isNotEmpty)
            Text(
              widget.config.title!.subtext!,
              style: TextStyle(
                fontSize: 12,
                color: safeStringToColor(
                  widget.config.title!.subtextStyle.color,
                  Theme.of(context).textTheme.bodySmall?.color ??
                      Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, double maxY) {
    final firstSeriesLength = widget.config.series.isNotEmpty
        ? (widget.config.series.first.data?.length ?? 0)
        : 0;
    final visibleRange = (widget.config.controller?.zoom ?? ZoomRange.full)
        .visibleIndexRange(firstSeriesLength);

    return CustomPaint(
      size: Size.infinite,
      painter: BarChartPainter(
        config: widget.config,
        maxY: maxY,
        startIndex: visibleRange.start,
        endIndex: visibleRange.end,
        progress: _anim.progress,
        configSignature: _configSignature,
        onHover: widget.config.tooltip?.show == true
            ? (position, data) {
                setState(() {
                  _hoverPosition = position;
                  _tooltipData = data;
                });
                if (data != null) {
                  _showTooltip(position, data);
                } else {
                  _hideTooltip();
                }
              }
            : null,
      ),
    );
  }

  Widget _createLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: widget.config.series.map((series) {
        final color =
            series.color ??
            getDefaultSeriesColor(widget.config.series.indexOf(series));
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              series.name ?? '',
              style: TextStyle(
                color: safeStringToColor(
                  widget.config.legend?.textColor ?? '#000000',
                  Colors.black,
                ),
                fontSize: widget.config.legend?.fontSize ?? 12,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class BarChartPainter extends CustomPainter {
  final BarChartConfig config;
  final double maxY;
  final int startIndex;
  final int endIndex;
  final double progress;
  final Function(Offset, Map<String, dynamic>?)? onHover;
  final String _configSignature;

  BarChartPainter({
    required this.config,
    required this.maxY,
    required this.startIndex,
    required this.endIndex,
    required this.progress,
    this.onHover,
    String? configSignature,
  }) : _configSignature =
           configSignature ?? ChartDataSignature.fromConfig(config).hash;

  @override
  void paint(Canvas canvas, Size size) {
    _barHitTests.clear();
    if (config.isHorizontal) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  void _paintVertical(Canvas canvas, Size size) {
    final double chartWidth = size.width - 60;
    final double chartHeight = size.height - 40;

    if (config.series.isEmpty || config.series.first.data == null) return;

    final firstSeriesData = config.series.first.data as List<dynamic>;
    if (firstSeriesData.isEmpty) return;

    final visibleCount = (endIndex - startIndex + 1).clamp(
      1,
      firstSeriesData.length,
    );
    final groupWidth = chartWidth / visibleCount;
    final barsSpace = 4.0;
    final availableBarWidth =
        (groupWidth - barsSpace * (config.series.length - 1)) /
        config.series.length;

    // Draw grid lines
    _drawGrid(canvas, size, startIndex, endIndex);

    // Draw axes
    _drawAxes(canvas, size);

    // Draw bars for each series
    for (int i = startIndex; i <= endIndex; i++) {
      final xPosition = 50 + (i - startIndex) * groupWidth + barsSpace / 2;

      for (
        int seriesIndex = 0;
        seriesIndex < config.series.length;
        seriesIndex++
      ) {
        final series = config.series[seriesIndex];
        final seriesData = series.data as List<dynamic>;

        if (i < seriesData.length) {
          final value = _extractValue(seriesData[i]);
          final barHeight = (value / maxY) * chartHeight * progress;
          final color = series.color ?? getDefaultSeriesColor(seriesIndex);

          final barX =
              xPosition + seriesIndex * (availableBarWidth + barsSpace);
          final barY = size.height - 20 - barHeight;

          // Draw bar with rounded top
          final barRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, availableBarWidth, barHeight),
            config.barBorderRadiusValue != null &&
                    config.barBorderRadiusValue! > 0
                ? Radius.circular(config.barBorderRadiusValue!)
                : Radius.zero,
          );

          final barPaint = Paint()
            ..color = color
            ..style = PaintingStyle.fill;

          // Add gradient if itemStyle has color or use series color
          if (series.itemStyle != null) {
            final itemStyleColor = safeStringToColor(
              series.itemStyle?.color,
              color,
            );
            barPaint.shader =
                LinearGradient(
                  colors: [
                    itemStyleColor,
                    itemStyleColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(
                  Rect.fromLTWH(barX, barY, availableBarWidth, barHeight),
                );
          } else if (series.color != null) {
            barPaint.color = series.color!;
          }

          canvas.drawRRect(barRect, barPaint);

          // Handle hover for tooltip
          if (onHover != null) {
            final touchRect = Rect.fromLTWH(
              barX - 5,
              barY,
              availableBarWidth + 10,
              barHeight,
            );
            // Store bar hit test data
            _barHitTests.add({
              'rect': touchRect,
              'index': i,
              'seriesIndex': seriesIndex,
              'value': value,
              'color': color,
              'seriesName': series.name ?? 'Series ${seriesIndex + 1}',
              'label': _getLabel(i),
            });
          }
        }
      }
    }

    // Draw axis labels
    _drawXAxisLabels(canvas, size, startIndex, endIndex, groupWidth);
    _drawYAxisLabels(canvas, size, maxY);
  }

  void _paintHorizontal(Canvas canvas, Size size) {
    final double chartWidth = size.width - 100;
    final double chartHeight = size.height - 40;

    if (config.series.isEmpty || config.series.first.data == null) return;

    final firstSeriesData = config.series.first.data as List<dynamic>;
    if (firstSeriesData.isEmpty) return;

    final visibleCount = (endIndex - startIndex + 1).clamp(
      1,
      firstSeriesData.length,
    );
    final groupHeight = chartHeight / visibleCount;
    final barsSpace = 4.0;
    final availableBarHeight =
        (groupHeight - barsSpace * (config.series.length - 1)) /
        config.series.length;

    // Draw grid lines (vertical for horizontal chart)
    _drawHorizontalGrid(canvas, size, chartWidth, startIndex, endIndex);

    // Draw axes
    _drawHorizontalAxes(canvas, size, chartWidth);

    // Draw bars for each series
    for (int i = startIndex; i <= endIndex; i++) {
      final yPosition = (i - startIndex) * groupHeight + barsSpace / 2;

      for (
        int seriesIndex = 0;
        seriesIndex < config.series.length;
        seriesIndex++
      ) {
        final series = config.series[seriesIndex];
        final seriesData = series.data as List<dynamic>;

        if (i < seriesData.length) {
          final value = _extractValue(seriesData[i]);
          final barWidth = (value / maxY) * chartWidth * progress;
          final color = series.color ?? getDefaultSeriesColor(seriesIndex);

          final barY =
              yPosition + seriesIndex * (availableBarHeight + barsSpace);
          final barX = 90.0;

          // Draw horizontal bar with rounded right end
          final barRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, barWidth, availableBarHeight),
            config.barBorderRadiusValue != null &&
                    config.barBorderRadiusValue! > 0
                ? Radius.circular(config.barBorderRadiusValue!)
                : Radius.zero,
          );

          final barPaint = Paint()
            ..color = color
            ..style = PaintingStyle.fill;

          // Add gradient if itemStyle has color
          if (series.itemStyle != null) {
            final itemStyleColor = safeStringToColor(
              series.itemStyle?.color,
              color,
            );
            barPaint.shader =
                LinearGradient(
                  colors: [
                    itemStyleColor,
                    itemStyleColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(
                  Rect.fromLTWH(barX, barY, barWidth, availableBarHeight),
                );
          } else if (series.color != null) {
            barPaint.color = series.color!;
          }

          canvas.drawRRect(barRect, barPaint);

          // Handle hover for tooltip
          if (onHover != null) {
            final touchRect = Rect.fromLTWH(
              barX,
              barY - 5,
              barWidth,
              availableBarHeight + 10,
            );
            _barHitTests.add({
              'rect': touchRect,
              'index': i,
              'seriesIndex': seriesIndex,
              'value': value,
              'color': color,
              'seriesName': series.name ?? 'Series ${seriesIndex + 1}',
              'label': _getLabel(i),
            });
          }
        }
      }
    }

    // Draw axis labels
    _drawHorizontalXAxisLabels(canvas, size, chartWidth, maxY);
    _drawHorizontalYAxisLabels(canvas, size, startIndex, endIndex, groupHeight);
  }

  final List<Map<String, dynamic>> _barHitTests = [];

  String _getLabel(int index) {
    if (config.xAxis?.data != null && index < config.xAxis!.data!.length) {
      return config.xAxis!.data![index].toString();
    } else if (config.yAxis?.data != null &&
        index < config.yAxis!.data!.length) {
      return config.yAxis!.data![index].toString();
    }
    return 'Item ${index + 1}';
  }

  double _extractValue(dynamic dataItem) {
    return ChartDataValueReader.yValue(dataItem);
  }

  // Vertical chart drawing methods
  void _drawGrid(Canvas canvas, Size size, int startIndex, int endIndex) {
    if (config.grid?.show != true) return;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = config.grid?.horizontalWidth ?? 0.5
      ..style = PaintingStyle.stroke;

    if (config.grid?.showHorizontalLines ?? true) {
      const divisions = 5;
      for (int i = 0; i <= divisions; i++) {
        final y = (i / divisions) * (size.height - 40);
        canvas.drawLine(Offset(50, y), Offset(size.width - 10, y), gridPaint);
      }
    }

    if (config.grid?.showVerticalLines ?? false) {
      final visibleCount = (endIndex - startIndex + 1).clamp(1, 1 << 20);
      final groupWidth = (size.width - 60) / visibleCount;
      for (int i = startIndex; i <= endIndex; i++) {
        final x = 50 + (i - startIndex) * groupWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height - 20), gridPaint);
      }
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(50, size.height - 20),
      Offset(size.width - 10, size.height - 20),
      axisPaint,
    );
    canvas.drawLine(Offset(50, 0), Offset(50, size.height - 20), axisPaint);
  }

  void _drawXAxisLabels(
    Canvas canvas,
    Size size,
    int startIndex,
    int endIndex,
    double groupWidth,
  ) {
    final visibleCount = (endIndex - startIndex + 1).clamp(1, 1 << 20);
    final step = visibleCount > 10 ? (visibleCount / 10).ceil() : 1;
    for (int i = startIndex; i <= endIndex; i += step) {
      String label;
      if (config.xAxis?.data != null && i < config.xAxis!.data!.length) {
        label = config.xAxis!.data![i].toString();
      } else if (config.series.first.dataLabels != null &&
          i < config.series.first.dataLabels!.length) {
        label = config.series.first.dataLabels![i].toString();
      } else {
        label = i.toString();
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      final x =
          50 +
          (i - startIndex) * groupWidth +
          groupWidth / 2 -
          textPainter.width / 2;
      textPainter.paint(canvas, Offset(x, size.height - 15));
    }
  }

  void _drawYAxisLabels(Canvas canvas, Size size, double maxY) {
    const divisions = 5;
    for (int i = 0; i <= divisions; i++) {
      final value = (maxY * i / divisions).toStringAsFixed(0);
      final y = (size.height - 20) - (i / divisions) * (size.height - 40);

      final textPainter = TextPainter(
        text: TextSpan(
          text: value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(5 - textPainter.width, y - 6));
    }
  }

  // Horizontal chart drawing methods
  void _drawHorizontalGrid(
    Canvas canvas,
    Size size,
    double chartWidth,
    int startIndex,
    int endIndex,
  ) {
    if (config.grid?.show != true) return;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    if (config.grid?.showVerticalLines ?? true) {
      const divisions = 5;
      for (int i = 0; i <= divisions; i++) {
        final x = 90 + (i / divisions) * chartWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height - 20), gridPaint);
      }
    }

    if (config.grid?.showHorizontalLines ?? false) {
      final visibleCount = (endIndex - startIndex + 1).clamp(1, 1 << 20);
      final groupHeight = (size.height - 40) / visibleCount;
      for (int i = startIndex; i <= endIndex; i++) {
        final y = (i - startIndex) * groupHeight;
        canvas.drawLine(Offset(90, y), Offset(size.width - 10, y), gridPaint);
      }
    }
  }

  void _drawHorizontalAxes(Canvas canvas, Size size, double chartWidth) {
    final axisPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(90, size.height - 20),
      Offset(90 + chartWidth, size.height - 20),
      axisPaint,
    );
    canvas.drawLine(Offset(90, 0), Offset(90, size.height - 20), axisPaint);
  }

  void _drawHorizontalXAxisLabels(
    Canvas canvas,
    Size size,
    double chartWidth,
    double maxY,
  ) {
    const divisions = 5;
    for (int i = 0; i <= divisions; i++) {
      final value = (maxY * i / divisions).toStringAsFixed(0);
      final x = 90 + (i / divisions) * chartWidth;

      final textPainter = TextPainter(
        text: TextSpan(
          text: value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 15),
      );
    }
  }

  void _drawHorizontalYAxisLabels(
    Canvas canvas,
    Size size,
    int startIndex,
    int endIndex,
    double groupHeight,
  ) {
    final visibleCount = (endIndex - startIndex + 1).clamp(1, 1 << 20);
    final step = visibleCount > 12 ? (visibleCount / 12).ceil() : 1;
    for (int i = startIndex; i <= endIndex; i += step) {
      String label;
      if (config.yAxis?.data != null && i < config.yAxis!.data!.length) {
        label = config.yAxis!.data![i].toString();
      } else {
        label = 'Item ${i + 1}';
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      final y =
          (i - startIndex) * groupHeight +
          groupHeight / 2 -
          textPainter.height / 2;
      textPainter.paint(canvas, Offset(85 - textPainter.width, y));
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate._configSignature != _configSignature ||
        oldDelegate.maxY != maxY ||
        oldDelegate.startIndex != startIndex ||
        oldDelegate.endIndex != endIndex ||
        oldDelegate.progress != progress;
  }

  @override
  bool hitTest(Offset position) {
    for (final barData in _barHitTests) {
      if ((barData['rect'] as Rect).contains(position)) {
        // Group data by x-index for multi-series
        final currentIndex = barData['index'] as int;
        final List<Map<String, dynamic>> groupedBars = _barHitTests
            .where((b) => b['index'] == currentIndex)
            .toList();

        final tooltipData = {
          'label': barData['label'],
          'values': groupedBars
              .map((b) => (b['value'] as num).toStringAsFixed(0))
              .toList(),
          'colors': groupedBars.map((b) => b['color'] as Color).toList(),
          'seriesNames': groupedBars
              .map((b) => b['seriesName'] as String)
              .toList(),
        };

        onHover?.call(position, tooltipData);
        return true;
      }
    }

    onHover?.call(position, null);
    return false;
  }
}
