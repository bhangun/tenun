import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../line/simple_line_chart.dart';

typedef SimpleStreamgraphValueFormatter = String Function(double value);
typedef SimpleStreamgraphShareFormatter = String Function(double share);
typedef SimpleStreamgraphTapCallback =
    void Function(
      String label,
      SimpleTrendSeries series,
      double value,
      double share,
      int labelIndex,
      int seriesIndex,
    );
typedef SimpleStreamgraphTooltipBuilder =
    Widget Function(
      BuildContext context,
      String label,
      List<SimpleStreamgraphTooltipItem> items,
    );

enum SimpleStreamgraphMode { absolute, percent }

class SimpleStreamgraphTooltipItem {
  final String seriesName;
  final double value;
  final double share;
  final Color color;

  const SimpleStreamgraphTooltipItem({
    required this.seriesName,
    required this.value,
    required this.share,
    required this.color,
  });
}

/// A centered stacked area chart for showing how composition shifts over time.
class SimpleStreamgraphChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(46, 18, 18, 36);

  final List<SimpleTrendSeries> series;
  final SimpleTrendChartStyle style;
  final SimpleStreamgraphMode mode;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveLayer;
  final bool smooth;
  final double fillOpacity;
  final int gridLineCount;
  final SimpleStreamgraphValueFormatter? valueFormatter;
  final SimpleStreamgraphShareFormatter? shareFormatter;
  final SimpleStreamgraphTapCallback? onLayerTap;
  final SimpleStreamgraphTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleStreamgraphChart({
    super.key,
    required this.series,
    this.style = SimpleTrendChartStyle.elegant,
    this.mode = SimpleStreamgraphMode.absolute,
    this.height = 250,
    this.padding = _defaultPadding,
    this.palette,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveLayer = true,
    this.smooth = true,
    this.fillOpacity = 0.82,
    this.gridLineCount = 4,
    this.valueFormatter,
    this.shareFormatter,
    this.onLayerTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 760),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(fillOpacity >= 0 && fillOpacity <= 1),
       assert(gridLineCount >= 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleStreamgraphVisuals.resolve(style, colorScheme);
    final visibleSeries = series
        .where(
          (item) =>
              item.points.any((point) => point.value.isFinite) &&
              item.points.any((point) => point.label.trim().isNotEmpty),
        )
        .toList();
    final labels = _labelsFor(visibleSeries);
    final resolvedValueFormatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedShareFormatter = shareFormatter ?? _defaultShareFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleSeries.isEmpty || labels.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Streamgraph chart, no data.',
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
        final resolvedPalette = _resolvePalette(
          colorScheme,
          palette ?? visuals.palette,
        );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleSeries,
            labels,
            mode,
            resolvedValueFormatter,
            resolvedShareFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleStreamgraphChartView(
            width: width,
            height: chartHeight,
            series: visibleSeries,
            labels: labels,
            mode: mode,
            padding: padding,
            palette: resolvedPalette,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showLabels: showLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveLayer: showActiveLayer,
            smooth: smooth,
            fillOpacity: fillOpacity,
            gridLineCount: gridLineCount,
            valueFormatter: resolvedValueFormatter,
            shareFormatter: resolvedShareFormatter,
            onLayerTap: onLayerTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static List<String> _labelsFor(List<SimpleTrendSeries> series) {
    final seen = <String>{};
    final labels = <String>[];
    for (final item in series) {
      for (final point in item.points) {
        final label = point.label.trim();
        if (label.isNotEmpty && seen.add(label)) {
          labels.add(label);
        }
      }
    }
    return labels;
  }

  static String _defaultSemanticLabel(
    List<SimpleTrendSeries> series,
    List<String> labels,
    SimpleStreamgraphMode mode,
    SimpleStreamgraphValueFormatter valueFormatter,
    SimpleStreamgraphShareFormatter shareFormatter,
  ) {
    final geometryData = _StreamgraphData.resolve(series, labels, mode);
    final sample = series
        .take(4)
        .map((item) {
          final name = item.name ?? 'Series';
          final latestIndex = labels.length - 1;
          final seriesIndex = series.indexOf(item);
          final value = geometryData.values[seriesIndex][latestIndex];
          final share = geometryData.shares[seriesIndex][latestIndex];
          final formatted = mode == SimpleStreamgraphMode.percent
              ? shareFormatter(share)
              : valueFormatter(value);
          return '$name $formatted';
        })
        .join(', ');
    final suffix = series.length > 4 ? ', and ${series.length - 4} more' : '';
    return 'Streamgraph chart, ${series.length} series across '
        '${labels.length} labels. Latest ${labels.last}: $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value.abs() >= 1000) {
      final precision = value.abs() >= 10000 ? 0 : 1;
      return '${(value / 1000).toStringAsFixed(precision)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultShareFormatter(double share) {
    return '${(share * 100).toStringAsFixed(0)}%';
  }

  static List<Color> _resolvePalette(
    ColorScheme colorScheme,
    List<Color> palette,
  ) {
    if (palette.isNotEmpty) {
      return palette;
    }
    return [
      colorScheme.primary,
      colorScheme.tertiary,
      colorScheme.secondary,
      const Color(0xFF14B8A6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];
  }
}

class _SimpleStreamgraphChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleTrendSeries> series;
  final List<String> labels;
  final SimpleStreamgraphMode mode;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveLayer;
  final bool smooth;
  final double fillOpacity;
  final int gridLineCount;
  final SimpleStreamgraphValueFormatter valueFormatter;
  final SimpleStreamgraphShareFormatter shareFormatter;
  final SimpleStreamgraphTapCallback? onLayerTap;
  final SimpleStreamgraphTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleStreamgraphChartView({
    required this.width,
    required this.height,
    required this.series,
    required this.labels,
    required this.mode,
    required this.padding,
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveLayer,
    required this.smooth,
    required this.fillOpacity,
    required this.gridLineCount,
    required this.valueFormatter,
    required this.shareFormatter,
    required this.onLayerTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleStreamgraphChartView> createState() =>
      _SimpleStreamgraphChartViewState();
}

class _SimpleStreamgraphChartViewState
    extends State<_SimpleStreamgraphChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _StreamgraphHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleStreamgraphChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series ||
        oldWidget.mode != widget.mode ||
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
                    if (widget.showActiveLayer ||
                        widget.showTooltip ||
                        widget.onLayerTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit != null) {
                        widget.onLayerTap?.call(
                          widget.labels[hit.labelIndex],
                          widget.series[hit.seriesIndex],
                          hit.value,
                          hit.share,
                          hit.labelIndex,
                          hit.seriesIndex,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleStreamgraphPainter(
                        series: widget.series,
                        labels: widget.labels,
                        mode: widget.mode,
                        padding: widget.padding,
                        palette: widget.palette,
                        gridColor: widget.gridColor,
                        axisColor: widget.axisColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showGrid: widget.showGrid,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showLegend: widget.showLegend,
                        showActiveLayer: widget.showActiveLayer,
                        smooth: widget.smooth,
                        fillOpacity: widget.fillOpacity,
                        gridLineCount: widget.gridLineCount,
                        valueFormatter: widget.valueFormatter,
                        shareFormatter: widget.shareFormatter,
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

  void _setActive(_StreamgraphHit? hit) {
    if (_activeHit?.seriesIndex == hit?.seriesIndex &&
        _activeHit?.labelIndex == hit?.labelIndex) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _StreamgraphHit? _hitTest(Offset position) {
    final geometry = _StreamgraphGeometry.resolve(
      series: widget.series,
      labels: widget.labels,
      mode: widget.mode,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
    );
    for (final hit in geometry.hits.reversed) {
      if (hit.rect.inflate(4).contains(position)) {
        return hit;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _StreamgraphHit hit) {
    final geometryData = _StreamgraphData.resolve(
      widget.series,
      widget.labels,
      widget.mode,
    );
    final label = widget.labels[hit.labelIndex];
    final items = <SimpleStreamgraphTooltipItem>[];
    for (
      var seriesIndex = 0;
      seriesIndex < widget.series.length;
      seriesIndex++
    ) {
      final value = geometryData.values[seriesIndex][hit.labelIndex];
      if (value <= 0) {
        continue;
      }
      items.add(
        SimpleStreamgraphTooltipItem(
          seriesName: widget.series[seriesIndex].name ?? 'Series',
          value: value,
          share: geometryData.shares[seriesIndex][hit.labelIndex],
          color: _colorFor(seriesIndex),
        ),
      );
    }
    items.sort((a, b) => b.value.compareTo(a.value));

    final tooltip =
        widget.tooltipBuilder?.call(context, label, items) ??
        _DefaultStreamgraphTooltip(
          title: label,
          items: items,
          mode: widget.mode,
          valueFormatter: widget.valueFormatter,
          shareFormatter: widget.shareFormatter,
        );
    final left = (hit.center.dx + 12).clamp(8.0, widget.width - 214);
    final top = (hit.center.dy - 54).clamp(8.0, widget.height - 142);

    return Positioned(left: left, top: top, child: tooltip);
  }

  Color _colorFor(int index) {
    final seriesColor = widget.series[index].color;
    if (seriesColor != null) {
      return seriesColor;
    }
    return widget.palette[index % widget.palette.length];
  }
}

class _SimpleStreamgraphPainter extends CustomPainter {
  final List<SimpleTrendSeries> series;
  final List<String> labels;
  final SimpleStreamgraphMode mode;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActiveLayer;
  final bool smooth;
  final double fillOpacity;
  final int gridLineCount;
  final SimpleStreamgraphValueFormatter valueFormatter;
  final SimpleStreamgraphShareFormatter shareFormatter;
  final _StreamgraphHit? activeHit;
  final double progress;

  const _SimpleStreamgraphPainter({
    required this.series,
    required this.labels,
    required this.mode,
    required this.padding,
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActiveLayer,
    required this.smooth,
    required this.fillOpacity,
    required this.gridLineCount,
    required this.valueFormatter,
    required this.shareFormatter,
    required this.activeHit,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _StreamgraphGeometry.resolve(
      series: series,
      labels: labels,
      mode: mode,
      size: size,
      padding: padding,
    );
    if (geometry.layers.isEmpty || geometry.plot.width <= 0) {
      return;
    }

    if (showGrid) {
      _drawGrid(canvas, geometry);
    }
    for (final layer in geometry.layers) {
      _drawLayer(canvas, geometry, layer);
    }
    if (showValues) {
      _drawEndValues(canvas, geometry);
    }
    if (showLabels) {
      _drawLabels(canvas, geometry);
    }
    if (showLegend) {
      _drawLegend(canvas, geometry);
    }
  }

  void _drawGrid(Canvas canvas, _StreamgraphGeometry geometry) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 0; index < gridLineCount; index++) {
      final ratio = gridLineCount == 1 ? 0.0 : index / (gridLineCount - 1);
      final y = geometry.plot.top + geometry.plot.height * ratio;
      canvas.drawLine(
        Offset(geometry.plot.left, y),
        Offset(geometry.plot.right, y),
        paint,
      );
    }
    canvas.drawLine(
      Offset(geometry.plot.left, geometry.plot.center.dy),
      Offset(geometry.plot.right, geometry.plot.center.dy),
      Paint()
        ..color = axisColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawLayer(
    Canvas canvas,
    _StreamgraphGeometry geometry,
    _StreamgraphLayer layer,
  ) {
    final color = _colorFor(layer.seriesIndex);
    final active =
        showActiveLayer && activeHit?.seriesIndex == layer.seriesIndex;
    final path = _buildLayerPath(geometry, layer);
    final fillPaint = Paint()
      ..color = (active ? activeColor : color).withValues(
        alpha:
            (active ? math.min(1, fillOpacity + 0.1) : fillOpacity) * progress,
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: active ? 0.68 : 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 1.8 : 0.8,
    );
  }

  Path _buildLayerPath(_StreamgraphGeometry geometry, _StreamgraphLayer layer) {
    final top = <Offset>[];
    final bottom = <Offset>[];
    for (var index = 0; index < labels.length; index++) {
      final x = geometry.xFor(index);
      top.add(Offset(x, geometry.yFor(layer.tops[index] * progress)));
      bottom.add(Offset(x, geometry.yFor(layer.bottoms[index] * progress)));
    }

    final path = Path();
    if (top.length == 1) {
      final halfWidth = math.max(4.0, geometry.plot.width / 2);
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            top.first.dx - halfWidth,
            top.first.dy,
            top.first.dx + halfWidth,
            bottom.first.dy,
          ),
          const Radius.circular(6),
        ),
      );
      return path;
    }

    path.moveTo(top.first.dx, top.first.dy);
    _appendLine(path, top);
    path.lineTo(bottom.last.dx, bottom.last.dy);
    _appendLine(path, bottom.reversed.toList());
    path.close();
    return path;
  }

  void _appendLine(Path path, List<Offset> points) {
    if (points.length < 2) {
      return;
    }
    if (!smooth) {
      for (var index = 1; index < points.length; index++) {
        path.lineTo(points[index].dx, points[index].dy);
      }
      return;
    }

    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final controlX = (current.dx + next.dx) / 2;
      path.cubicTo(controlX, current.dy, controlX, next.dy, next.dx, next.dy);
    }
  }

  void _drawEndValues(Canvas canvas, _StreamgraphGeometry geometry) {
    if (labels.isEmpty || geometry.plot.width < 72) {
      return;
    }
    final lastIndex = labels.length - 1;
    for (final layer in geometry.layers) {
      final value = geometry.data.values[layer.seriesIndex][lastIndex];
      if (value <= 0) {
        continue;
      }
      final share = geometry.data.shares[layer.seriesIndex][lastIndex];
      final centerValue =
          (layer.tops[lastIndex] + layer.bottoms[lastIndex]) / 2 * progress;
      final y = geometry.yFor(centerValue);
      final text = mode == SimpleStreamgraphMode.percent
          ? shareFormatter(share)
          : valueFormatter(value);
      _drawText(
        canvas,
        text,
        Rect.fromLTWH(geometry.plot.right - 58, y - 8, 54, 16),
        valueStyle.copyWith(color: _colorFor(layer.seriesIndex)),
        align: TextAlign.right,
      );
    }
  }

  void _drawLabels(Canvas canvas, _StreamgraphGeometry geometry) {
    if (labels.isEmpty) {
      return;
    }
    final step = labels.length <= 1 ? 1 : labels.length - 1;
    final labelEvery = geometry.plot.width < 220
        ? math.max(1, (labels.length / 3).ceil())
        : math.max(1, (labels.length / 5).ceil());
    for (var index = 0; index < labels.length; index++) {
      if (index != 0 && index != step && index % labelEvery != 0) {
        continue;
      }
      final x = geometry.xFor(index);
      final align = index == 0
          ? TextAlign.left
          : index == labels.length - 1
          ? TextAlign.right
          : TextAlign.center;
      _drawText(
        canvas,
        labels[index],
        Rect.fromLTWH(x - 40, geometry.plot.bottom + 7, 80, 16),
        labelStyle,
        align: align,
      );
    }
  }

  void _drawLegend(Canvas canvas, _StreamgraphGeometry geometry) {
    if (geometry.plot.width < 148 || series.isEmpty) {
      return;
    }
    var dx = geometry.plot.left + 4;
    final y = geometry.plot.top + 4;
    for (var index = 0; index < math.min(series.length, 4); index++) {
      final name = series[index].name ?? 'Series ${index + 1}';
      final color = _colorFor(index);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(dx, y + 4, 8, 8),
          const Radius.circular(2),
        ),
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill,
      );
      final width = math.min(78.0, geometry.plot.right - dx - 12);
      if (width <= 24) {
        return;
      }
      _drawText(
        canvas,
        name,
        Rect.fromLTWH(dx + 12, y, width, 16),
        labelStyle.copyWith(color: color, fontWeight: FontWeight.w700),
      );
      dx += width + 18;
      if (dx > geometry.plot.right - 32) {
        return;
      }
    }
  }

  Color _colorFor(int index) {
    final seriesColor = series[index].color;
    if (seriesColor != null) {
      return seriesColor;
    }
    return palette[index % palette.length];
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
  bool shouldRepaint(covariant _SimpleStreamgraphPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.labels != labels ||
        oldDelegate.mode != mode ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveLayer != showActiveLayer ||
        oldDelegate.smooth != smooth ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.activeHit != activeHit ||
        oldDelegate.progress != progress;
  }
}

class _StreamgraphGeometry {
  final Rect plot;
  final _StreamgraphData data;
  final List<_StreamgraphLayer> layers;
  final List<_StreamgraphHit> hits;
  final double domainHalf;

  const _StreamgraphGeometry({
    required this.plot,
    required this.data,
    required this.layers,
    required this.hits,
    required this.domainHalf,
  });

  factory _StreamgraphGeometry.resolve({
    required List<SimpleTrendSeries> series,
    required List<String> labels,
    required SimpleStreamgraphMode mode,
    required Size size,
    required EdgeInsets padding,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    final data = _StreamgraphData.resolve(series, labels, mode);
    if (series.isEmpty ||
        labels.isEmpty ||
        plot.width <= 0 ||
        plot.height <= 0) {
      return _StreamgraphGeometry(
        plot: plot,
        data: data,
        layers: const [],
        hits: const [],
        domainHalf: 1,
      );
    }

    final maxTotal = data.totals.fold<double>(0, (maxValue, total) {
      final resolvedTotal = mode == SimpleStreamgraphMode.percent && total > 0
          ? 1.0
          : total;
      return math.max(maxValue, resolvedTotal);
    });
    final domainHalf = math.max(0.5, maxTotal / 2);
    final layers = List.generate(
      series.length,
      (seriesIndex) => _StreamgraphLayer(
        seriesIndex: seriesIndex,
        bottoms: List.filled(labels.length, 0),
        tops: List.filled(labels.length, 0),
      ),
    );
    final hits = <_StreamgraphHit>[];

    for (var labelIndex = 0; labelIndex < labels.length; labelIndex++) {
      final total = data.totals[labelIndex];
      final scaledTotal = mode == SimpleStreamgraphMode.percent && total > 0
          ? 1.0
          : total;
      var cursor = -scaledTotal / 2;
      for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
        final value = data.values[seriesIndex][labelIndex];
        final scaledValue = mode == SimpleStreamgraphMode.percent && total > 0
            ? value / total
            : value;
        final bottom = cursor;
        final top = cursor + scaledValue;
        layers[seriesIndex].bottoms[labelIndex] = bottom;
        layers[seriesIndex].tops[labelIndex] = top;
        cursor = top;

        if (value <= 0) {
          continue;
        }
        final x = _xFor(plot, labels.length, labelIndex);
        final columnHalf = labels.length == 1
            ? plot.width / 2
            : plot.width / (labels.length - 1) / 2;
        final yTop = _yFor(plot, domainHalf, top);
        final yBottom = _yFor(plot, domainHalf, bottom);
        final rect = Rect.fromLTRB(
          math.max(plot.left, x - columnHalf),
          math.min(yTop, yBottom),
          math.min(plot.right, x + columnHalf),
          math.max(yTop, yBottom),
        );
        hits.add(
          _StreamgraphHit(
            seriesIndex: seriesIndex,
            labelIndex: labelIndex,
            value: value,
            share: data.shares[seriesIndex][labelIndex],
            rect: rect,
            center: Offset(x, (yTop + yBottom) / 2),
          ),
        );
      }
    }

    return _StreamgraphGeometry(
      plot: plot,
      data: data,
      layers: layers,
      hits: hits,
      domainHalf: domainHalf,
    );
  }

  double xFor(int index) => _xFor(plot, data.labels.length, index);

  double yFor(double value) => _yFor(plot, domainHalf, value);

  static double _xFor(Rect plot, int count, int index) {
    if (count <= 1) {
      return plot.center.dx;
    }
    return plot.left + plot.width * index / (count - 1);
  }

  static double _yFor(Rect plot, double domainHalf, double value) {
    final domain = domainHalf * 2;
    if (domain <= 0) {
      return plot.center.dy;
    }
    final ratio = ((value + domainHalf) / domain).clamp(0.0, 1.0);
    return plot.bottom - plot.height * ratio;
  }
}

class _StreamgraphData {
  final List<String> labels;
  final List<List<double>> values;
  final List<List<double>> shares;
  final List<double> totals;

  const _StreamgraphData({
    required this.labels,
    required this.values,
    required this.shares,
    required this.totals,
  });

  factory _StreamgraphData.resolve(
    List<SimpleTrendSeries> series,
    List<String> labels,
    SimpleStreamgraphMode mode,
  ) {
    final values = series.map((item) {
      return labels.map((label) {
        final point = item.points.cast<SimpleTrendPoint?>().firstWhere(
          (point) => point?.label.trim() == label,
          orElse: () => null,
        );
        final value = point?.value ?? 0;
        return value.isFinite ? math.max(0.0, value) : 0.0;
      }).toList();
    }).toList();
    final totals = List<double>.generate(labels.length, (labelIndex) {
      return values.fold<double>(
        0,
        (total, itemValues) => total + itemValues[labelIndex],
      );
    });
    final shares = values.map((itemValues) {
      return List<double>.generate(labels.length, (labelIndex) {
        final total = totals[labelIndex];
        if (total <= 0) {
          return 0;
        }
        return itemValues[labelIndex] / total;
      });
    }).toList();
    return _StreamgraphData(
      labels: labels,
      values: values,
      shares: shares,
      totals: totals,
    );
  }
}

class _StreamgraphLayer {
  final int seriesIndex;
  final List<double> bottoms;
  final List<double> tops;

  const _StreamgraphLayer({
    required this.seriesIndex,
    required this.bottoms,
    required this.tops,
  });
}

class _StreamgraphHit {
  final int seriesIndex;
  final int labelIndex;
  final double value;
  final double share;
  final Rect rect;
  final Offset center;

  const _StreamgraphHit({
    required this.seriesIndex,
    required this.labelIndex,
    required this.value,
    required this.share,
    required this.rect,
    required this.center,
  });
}

class _SimpleStreamgraphVisuals {
  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;

  const _SimpleStreamgraphVisuals({
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
  });

  factory _SimpleStreamgraphVisuals.resolve(
    SimpleTrendChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleTrendChartStyle.modern:
        return _SimpleStreamgraphVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.tertiary,
            colorScheme.secondary,
            const Color(0xFF14B8A6),
            const Color(0xFFF97316),
          ],
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.58),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          activeColor: colorScheme.tertiary,
        );
      case SimpleTrendChartStyle.professional:
        return _SimpleStreamgraphVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF64748B),
            const Color(0xFF0F766E),
          ],
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.68),
          axisColor: colorScheme.outline.withValues(alpha: 0.56),
          activeColor: colorScheme.onSurface,
        );
      case SimpleTrendChartStyle.education:
        return _SimpleStreamgraphVisuals(
          palette: [
            colorScheme.secondary,
            colorScheme.primary,
            colorScheme.tertiary,
            const Color(0xFF22C55E),
            const Color(0xFFF59E0B),
          ],
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.58),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          activeColor: colorScheme.primary,
        );
      case SimpleTrendChartStyle.trendy:
        return _SimpleStreamgraphVisuals(
          palette: [
            colorScheme.tertiary,
            colorScheme.primary,
            const Color(0xFF06B6D4),
            const Color(0xFF84CC16),
            const Color(0xFFF43F5E),
          ],
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.52),
          axisColor: colorScheme.outline.withValues(alpha: 0.42),
          activeColor: colorScheme.primary,
        );
      case SimpleTrendChartStyle.elegant:
        return _SimpleStreamgraphVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.tertiary,
            colorScheme.secondary,
            const Color(0xFF0EA5E9),
            const Color(0xFFF59E0B),
          ],
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.58),
          axisColor: colorScheme.outline.withValues(alpha: 0.46),
          activeColor: colorScheme.tertiary,
        );
    }
  }
}

class _DefaultStreamgraphTooltip extends StatelessWidget {
  final String title;
  final List<SimpleStreamgraphTooltipItem> items;
  final SimpleStreamgraphMode mode;
  final SimpleStreamgraphValueFormatter valueFormatter;
  final SimpleStreamgraphShareFormatter shareFormatter;

  const _DefaultStreamgraphTooltip({
    required this.title,
    required this.items,
    required this.mode,
    required this.valueFormatter,
    required this.shareFormatter,
  });

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
        constraints: const BoxConstraints(maxWidth: 230),
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final item in items.take(5))
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.seriesName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          mode == SimpleStreamgraphMode.percent
                              ? shareFormatter(item.share)
                              : valueFormatter(item.value),
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
