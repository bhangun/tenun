import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_data_value_reader.dart';
import '../../core/utils/helper.dart';
import 'grid_painter.dart';
import 'scatter_chart_painter.dart';
import 'scatter_config.dart';

class ScatterBarChartWidget extends StatefulWidget {
  final ScatterChartConfig config;
  final double height;
  final double width;
  final bool isResponsive;

  const ScatterBarChartWidget({
    super.key,
    required this.config,
    this.height = 400,
    this.width = double.infinity,
    this.isResponsive = true,
  });

  @override
  State<ScatterBarChartWidget> createState() => _ScatterBarChartWidgetState();
}

class _ScatterBarChartWidgetState extends State<ScatterBarChartWidget> {
  static const double _zoomStep = 0.6;
  static const double _minZoomSpanRatio = 0.02;

  late int selectedPointIndex;
  late Offset? tooltipPosition;
  late double _viewMinX;
  late double _viewMaxX;
  late double _viewMinY;
  late double _viewMaxY;
  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    selectedPointIndex = -1;
    tooltipPosition = null;
    _resetViewport();
  }

  @override
  void didUpdateWidget(covariant ScatterBarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.minX != widget.config.minX ||
        oldWidget.config.maxX != widget.config.maxX ||
        oldWidget.config.minY != widget.config.minY ||
        oldWidget.config.maxY != widget.config.maxY) {
      _resetViewport();
    } else {
      _clampViewport();
    }
  }

  @override
  void dispose() {
    horizontalScrollController.dispose();
    verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.config.title != null) ...[
                  Text(
                    widget.config.title!.text!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.config.legend != null) _buildLegend(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 40, right: 16, bottom: 40),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewportConfig = _viewportConfig();
                  return Stack(
                    children: [
                      // Grid background
                      _buildGridLines(constraints, viewportConfig),

                      // Scatter plot
                      GestureDetector(
                        onTapUp: (details) {
                          _handleTapUp(details, constraints, viewportConfig);
                        },
                        onPanUpdate: (details) {
                          _handlePanUpdate(details, constraints);
                        },
                        child: CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: ScatterChartPainter(
                            config: viewportConfig,
                            selectedPointIndex: selectedPointIndex,
                          ),
                        ),
                      ),

                      // Y Axis
                      Positioned(
                        left: -40,
                        top: 0,
                        bottom: 0,
                        width: 40,
                        child: _buildYAxis(constraints, viewportConfig),
                      ),

                      // X Axis
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -40,
                        height: 40,
                        child: _buildXAxis(constraints, viewportConfig),
                      ),

                      // Tooltip
                      if (tooltipPosition != null && selectedPointIndex >= 0)
                        _buildTooltip(tooltipPosition!, selectedPointIndex),
                    ],
                  );
                },
              ),
            ),
          ),

          // Toolbar if available
          if (widget.config.toolbox?.show ?? false) _buildToolbox(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: widget.config.series.asMap().entries.map((entry) {
        final seriesIndex = entry.key;
        final series = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color:
                    series.color ??
                    safeStringToColor(
                      series.itemStyle?.color,
                      getDefaultSeriesColor(seriesIndex),
                    ),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(series.name ?? '', style: const TextStyle(fontSize: 12)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGridLines(
    BoxConstraints constraints,
    ScatterChartConfig viewportConfig,
  ) {
    return CustomPaint(
      size: Size(constraints.maxWidth, constraints.maxHeight),
      painter: GridPainter(config: viewportConfig),
    );
  }

  Widget _buildYAxis(
    BoxConstraints constraints,
    ScatterChartConfig viewportConfig,
  ) {
    final yRange = viewportConfig.maxY - viewportConfig.minY;
    final interval = _calculateAxisInterval(yRange, 5);
    final values = <double>[];

    for (
      double y = viewportConfig.minY;
      y <= viewportConfig.maxY;
      y += interval
    ) {
      values.add(y);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.reversed.map((value) {
        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 10),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildXAxis(
    BoxConstraints constraints,
    ScatterChartConfig viewportConfig,
  ) {
    final xRange = viewportConfig.maxX - viewportConfig.minX;
    final interval = _calculateAxisInterval(xRange, 5);
    final values = <double>[];

    for (
      double x = viewportConfig.minX;
      x <= viewportConfig.maxX;
      x += interval
    ) {
      values.add(x);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: values.map((value) {
        return Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 10),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTooltip(Offset position, int pointIndex) {
    final seriesIndex = _getSeriesIndexFromPointIndex(pointIndex);
    final dataIndex = _getDataIndexFromPointIndex(pointIndex, seriesIndex);

    if (seriesIndex < 0 || dataIndex < 0) return const SizedBox.shrink();

    final series = widget.config.series[seriesIndex];
    final point = _pointAt(seriesIndex, dataIndex);
    if (point == null) return const SizedBox.shrink();
    final extraValue = _extraValue(point);

    return Positioned(
      left: position.dx < 100 ? position.dx : position.dx - 100,
      top: position.dy < 70 ? position.dy + 10 : position.dy - 70,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(4),
        ),
        constraints: const BoxConstraints(maxWidth: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              series.name ?? 'Series ${seriesIndex + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'X: ${point.x.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              'Y: ${point.y.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            if (extraValue != null && extraValue != point.y)
              Text(
                'Value: ${extraValue.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbox() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 20),
            tooltip: 'Zoom in',
            onPressed: () => _zoomViewport(_zoomStep),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 20),
            tooltip: 'Zoom out',
            onPressed: () => _zoomViewport(1 / _zoomStep),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Reset zoom',
            onPressed: () {
              setState(() {
                _resetViewport();
                selectedPointIndex = -1;
                tooltipPosition = null;
              });
            },
          ),
        ],
      ),
    );
  }

  void _handleTapUp(
    TapUpDetails details,
    BoxConstraints constraints,
    ScatterChartConfig viewportConfig,
  ) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.globalToLocal(details.globalPosition);

    // Find the closest point
    int closestPointIndex = -1;
    double minDistance = double.infinity;

    int pointIndex = 0;
    for (
      int seriesIndex = 0;
      seriesIndex < widget.config.series.length;
      seriesIndex++
    ) {
      final series = widget.config.series[seriesIndex];
      final data = series.data;
      if (data == null) continue;

      for (int dataIndex = 0; dataIndex < data.length; dataIndex++) {
        final point = ChartDataValueReader.cartesian(
          data[dataIndex],
          dataIndex,
        );
        if (point == null) continue;

        final pixelX = _mapXToPixel(
          point.x,
          constraints.maxWidth,
          viewportConfig,
        );
        final pixelY = _mapYToPixel(
          point.y,
          constraints.maxHeight,
          viewportConfig,
        );

        final dx = offset.dx - pixelX;
        final dy = offset.dy - 40 - pixelY; // Adjust for top padding
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance < minDistance && distance < 20) {
          // 20 pixels tolerance
          minDistance = distance;
          closestPointIndex = pointIndex;
        }
        pointIndex++;
      }
    }

    setState(() {
      selectedPointIndex = closestPointIndex;
      if (closestPointIndex >= 0) {
        tooltipPosition = offset;
      } else {
        tooltipPosition = null;
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!_isZoomed) {
      setState(() {
        tooltipPosition = null;
        selectedPointIndex = -1;
      });
      return;
    }

    final xSpan = _viewMaxX - _viewMinX;
    final ySpan = _viewMaxY - _viewMinY;
    final dx = constraints.maxWidth <= 0
        ? 0.0
        : -details.delta.dx / constraints.maxWidth * xSpan;
    final dy = constraints.maxHeight <= 0
        ? 0.0
        : details.delta.dy / constraints.maxHeight * ySpan;

    setState(() {
      _shiftViewport(dx, dy);
      tooltipPosition = null;
      selectedPointIndex = -1;
    });
  }

  double _mapXToPixel(
    double x,
    double width,
    ScatterChartConfig viewportConfig,
  ) {
    final span = viewportConfig.maxX - viewportConfig.minX;
    if (!span.isFinite || span <= 0) return width / 2;
    return (((x - viewportConfig.minX) / span).clamp(0.0, 1.0)) * width;
  }

  double _mapYToPixel(
    double y,
    double height,
    ScatterChartConfig viewportConfig,
  ) {
    final span = viewportConfig.maxY - viewportConfig.minY;
    if (!span.isFinite || span <= 0) return height / 2;
    return height -
        (((y - viewportConfig.minY) / span).clamp(0.0, 1.0)) * height;
  }

  int _getSeriesIndexFromPointIndex(int pointIndex) {
    if (pointIndex < 0) return -1;

    int currentIndex = 0;
    for (int i = 0; i < widget.config.series.length; i++) {
      final series = widget.config.series[i];
      final data = series.data;
      if (data == null) continue;
      for (int dataIndex = 0; dataIndex < data.length; dataIndex++) {
        if (ChartDataValueReader.cartesian(data[dataIndex], dataIndex) ==
            null) {
          continue;
        }
        if (currentIndex == pointIndex) return i;
        currentIndex++;
      }
    }
    return -1;
  }

  int _getDataIndexFromPointIndex(int pointIndex, int seriesIndex) {
    if (pointIndex < 0 || seriesIndex < 0) return -1;

    int currentIndex = 0;
    for (int i = 0; i < seriesIndex; i++) {
      final series = widget.config.series[i];
      final data = series.data;
      if (data == null) continue;
      for (int dataIndex = 0; dataIndex < data.length; dataIndex++) {
        if (ChartDataValueReader.cartesian(data[dataIndex], dataIndex) !=
            null) {
          currentIndex++;
        }
      }
    }

    final target = pointIndex - currentIndex;
    if (target < 0) return -1;
    final data = widget.config.series[seriesIndex].data;
    if (data == null) return -1;

    var visibleIndex = 0;
    for (int dataIndex = 0; dataIndex < data.length; dataIndex++) {
      if (ChartDataValueReader.cartesian(data[dataIndex], dataIndex) == null) {
        continue;
      }
      if (visibleIndex == target) return dataIndex;
      visibleIndex++;
    }

    return -1;
  }

  double _calculateAxisInterval(double range, int desiredDivisions) {
    if (!range.isFinite || range <= 0) return 1;
    // Calculate a nice interval value
    final rawInterval = range / desiredDivisions;
    final magnitude = math.pow(10, (math.log(rawInterval) / math.ln10).floor());
    final normalized = rawInterval / magnitude;

    double niceInterval;
    if (normalized < 1.5) {
      niceInterval = 1;
    } else if (normalized < 3) {
      niceInterval = 2;
    } else if (normalized < 7) {
      niceInterval = 5;
    } else {
      niceInterval = 10;
    }

    return niceInterval * magnitude;
  }

  ChartPointValue? _pointAt(int seriesIndex, int dataIndex) {
    if (seriesIndex < 0 || seriesIndex >= widget.config.series.length) {
      return null;
    }
    final data = widget.config.series[seriesIndex].data;
    if (data == null || dataIndex < 0 || dataIndex >= data.length) {
      return null;
    }
    return ChartDataValueReader.cartesian(data[dataIndex], dataIndex);
  }

  double? _extraValue(ChartPointValue point) {
    final raw = point.raw;
    if (raw is Map) {
      return ChartDataValueReader.numeric(raw['value']);
    }
    return null;
  }

  ScatterChartConfig _viewportConfig() {
    return widget.config.copyWith(
      minX: _viewMinX,
      maxX: _viewMaxX,
      minY: _viewMinY,
      maxY: _viewMaxY,
    );
  }

  void _resetViewport() {
    _viewMinX = _fullMinX;
    _viewMaxX = _fullMaxX;
    _viewMinY = _fullMinY;
    _viewMaxY = _fullMaxY;
  }

  void _zoomViewport(double factor) {
    final fullXSpan = _fullXSpan;
    final fullYSpan = _fullYSpan;
    final nextXSpan = ((_viewMaxX - _viewMinX) * factor)
        .clamp(fullXSpan * _minZoomSpanRatio, fullXSpan)
        .toDouble();
    final nextYSpan = ((_viewMaxY - _viewMinY) * factor)
        .clamp(fullYSpan * _minZoomSpanRatio, fullYSpan)
        .toDouble();
    final centerX = (_viewMinX + _viewMaxX) / 2;
    final centerY = (_viewMinY + _viewMaxY) / 2;

    setState(() {
      _viewMinX = centerX - nextXSpan / 2;
      _viewMaxX = centerX + nextXSpan / 2;
      _viewMinY = centerY - nextYSpan / 2;
      _viewMaxY = centerY + nextYSpan / 2;
      _clampViewport();
      tooltipPosition = null;
      selectedPointIndex = -1;
    });
  }

  void _shiftViewport(double dx, double dy) {
    _viewMinX += dx;
    _viewMaxX += dx;
    _viewMinY += dy;
    _viewMaxY += dy;
    _clampViewport();
  }

  void _clampViewport() {
    final xSpan = (_viewMaxX - _viewMinX)
        .clamp(_fullXSpan * _minZoomSpanRatio, _fullXSpan)
        .toDouble();
    final ySpan = (_viewMaxY - _viewMinY)
        .clamp(_fullYSpan * _minZoomSpanRatio, _fullYSpan)
        .toDouble();
    _viewMinX = _clampWindowStart(_viewMinX, xSpan, _fullMinX, _fullMaxX);
    _viewMaxX = _viewMinX + xSpan;
    _viewMinY = _clampWindowStart(_viewMinY, ySpan, _fullMinY, _fullMaxY);
    _viewMaxY = _viewMinY + ySpan;
  }

  double _clampWindowStart(
    double start,
    double span,
    double fullMin,
    double fullMax,
  ) {
    final maxStart = fullMax - span;
    if (maxStart <= fullMin) return fullMin;
    return start.clamp(fullMin, maxStart).toDouble();
  }

  bool get _isZoomed {
    const epsilon = 0.0001;
    return (_viewMinX - _fullMinX).abs() > epsilon ||
        (_viewMaxX - _fullMaxX).abs() > epsilon ||
        (_viewMinY - _fullMinY).abs() > epsilon ||
        (_viewMaxY - _fullMaxY).abs() > epsilon;
  }

  double get _fullMinX =>
      widget.config.minX.isFinite ? widget.config.minX : 0.0;

  double get _fullMaxX {
    final max = widget.config.maxX;
    return max.isFinite && max > _fullMinX ? max : _fullMinX + 1;
  }

  double get _fullMinY =>
      widget.config.minY.isFinite ? widget.config.minY : 0.0;

  double get _fullMaxY {
    final max = widget.config.maxY;
    return max.isFinite && max > _fullMinY ? max : _fullMinY + 1;
  }

  double get _fullXSpan =>
      (_fullMaxX - _fullMinX).abs().clamp(1e-9, 1e18).toDouble();

  double get _fullYSpan =>
      (_fullMaxY - _fullMinY).abs().clamp(1e-9, 1e18).toDouble();
}
