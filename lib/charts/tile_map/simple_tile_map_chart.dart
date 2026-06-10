import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleTileMapValueFormatter = String Function(double value);
typedef SimpleTileMapTapCallback =
    void Function(SimpleTileMapData data, int index);
typedef SimpleTileMapTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleTileMapData data,
      int index,
      String formattedValue,
    );

enum SimpleTileMapShape { rounded, square, circle, hexagon }

class SimpleTileMapData {
  final String label;
  final String? code;
  final double value;
  final int row;
  final int column;
  final Color? color;

  const SimpleTileMapData({
    required this.label,
    required this.value,
    required this.row,
    required this.column,
    this.code,
    this.color,
  });
}

/// A simple tile-map choropleth for regional, territorial, classroom,
/// department, branch, or grid-based comparisons without requiring map shapes.
class SimpleTileMapChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 18, 18, 18);

  final List<SimpleTileMapData> data;
  final SimpleTileMapShape shape;
  final SimpleBarChartStyle style;
  final int? rows;
  final int? columns;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? lowColor;
  final Color? highColor;
  final Color? emptyColor;
  final Color? borderColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveTile;
  final bool showEmptyTiles;
  final double tileGap;
  final double tileRadius;
  final SimpleTileMapValueFormatter? valueFormatter;
  final SimpleTileMapTapCallback? onTileTap;
  final SimpleTileMapTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleTileMapChart({
    super.key,
    required this.data,
    this.shape = SimpleTileMapShape.rounded,
    this.style = SimpleBarChartStyle.elegant,
    this.rows,
    this.columns,
    this.minValue,
    this.maxValue,
    this.height = 260,
    this.padding = _defaultPadding,
    this.lowColor,
    this.highColor,
    this.emptyColor,
    this.borderColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveTile = true,
    this.showEmptyTiles = true,
    this.tileGap = 4,
    this.tileRadius = 7,
    this.valueFormatter,
    this.onTileTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 680),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(rows == null || rows > 0),
       assert(columns == null || columns > 0),
       assert(minValue == null || maxValue == null || minValue < maxValue),
       assert(tileGap >= 0),
       assert(tileRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleTileMapVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where(
          (item) => item.value.isFinite && item.row >= 0 && item.column >= 0,
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
            emptySemanticLabel: 'Tile map, no data.',
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
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w800,
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
          child: _SimpleTileMapView(
            width: width,
            height: chartHeight,
            data: visibleData,
            shape: shape,
            rows: rows,
            columns: columns,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            lowColor: lowColor ?? visuals.lowColor,
            highColor: highColor ?? visuals.highColor,
            emptyColor: emptyColor ?? visuals.emptyColor,
            borderColor: borderColor ?? visuals.borderColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveTile: showActiveTile,
            showEmptyTiles: showEmptyTiles,
            tileGap: tileGap,
            tileRadius: tileRadius,
            valueFormatter: formatter,
            onTileTap: onTileTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleTileMapData> data,
    SimpleTileMapValueFormatter formatter,
  ) {
    final sample = data
        .take(7)
        .map((item) => '${item.label} ${formatter(item.value)}')
        .join(', ');
    final suffix = data.length > 7 ? ', and ${data.length - 7} more' : '';
    return 'Tile map, ${data.length} tiles. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleTileMapView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleTileMapData> data;
  final SimpleTileMapShape shape;
  final int? rows;
  final int? columns;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color borderColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveTile;
  final bool showEmptyTiles;
  final double tileGap;
  final double tileRadius;
  final SimpleTileMapValueFormatter valueFormatter;
  final SimpleTileMapTapCallback? onTileTap;
  final SimpleTileMapTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleTileMapView({
    required this.width,
    required this.height,
    required this.data,
    required this.shape,
    required this.rows,
    required this.columns,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveTile,
    required this.showEmptyTiles,
    required this.tileGap,
    required this.tileRadius,
    required this.valueFormatter,
    required this.onTileTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleTileMapView> createState() => _SimpleTileMapViewState();
}

class _SimpleTileMapViewState extends State<_SimpleTileMapView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  _TileLayout? _activeTile;
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
  void didUpdateWidget(covariant _SimpleTileMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.shape != widget.shape ||
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
          final geometry = _TileMapGeometry.resolve(
            size: Size(widget.width, widget.height),
            data: widget.data,
            shape: widget.shape,
            rows: widget.rows,
            columns: widget.columns,
            minValue: widget.minValue,
            maxValue: widget.maxValue,
            padding: widget.padding,
            lowColor: widget.lowColor,
            highColor: widget.highColor,
            emptyColor: widget.emptyColor,
            showLegend: widget.showLegend,
            showEmptyTiles: widget.showEmptyTiles,
            tileGap: widget.tileGap,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onHover: (event) {
                    _setActive(_hitTest(event.localPosition, geometry));
                    _pointer = event.localPosition;
                  },
                  onExit: (_) => _setActive(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final tile = _hitTest(details.localPosition, geometry);
                      _setActive(tile);
                      _pointer = details.localPosition;
                      if (tile?.data != null) {
                        widget.onTileTap?.call(tile!.data!, tile.index);
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SimpleTileMapPainter(
                            geometry: geometry,
                            shape: widget.shape,
                            borderColor: widget.borderColor,
                            activeColor: widget.activeColor,
                            labelStyle: widget.labelStyle,
                            valueStyle: widget.valueStyle,
                            showLabels: widget.showLabels,
                            showValues: widget.showValues,
                            showLegend: widget.showLegend,
                            showActiveTile: widget.showActiveTile,
                            tileRadius: widget.tileRadius,
                            valueFormatter: widget.valueFormatter,
                            activeTile: _activeTile,
                            progress: _animation.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeTile?.data != null)
                _buildTooltip(context, Size(widget.width, widget.height)),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_TileLayout? tile) {
    if (_activeTile == tile) {
      return;
    }
    setState(() => _activeTile = tile);
  }

  _TileLayout? _hitTest(Offset position, _TileMapGeometry geometry) {
    for (var i = geometry.tiles.length - 1; i >= 0; i--) {
      final tile = geometry.tiles[i];
      if (tile.data != null && tile.rect.contains(position)) {
        return tile;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final tile = _activeTile!;
    final data = tile.data!;
    final formattedValue = widget.valueFormatter(data.value);
    final child =
        widget.tooltipBuilder?.call(
          context,
          data,
          tile.index,
          formattedValue,
        ) ??
        _DefaultTileMapTooltip(data: data, formattedValue: formattedValue);
    const tooltipWidth = 176.0;
    const tooltipHeight = 86.0;
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

class _SimpleTileMapPainter extends CustomPainter {
  final _TileMapGeometry geometry;
  final SimpleTileMapShape shape;
  final Color borderColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showLegend;
  final bool showActiveTile;
  final double tileRadius;
  final SimpleTileMapValueFormatter valueFormatter;
  final _TileLayout? activeTile;
  final double progress;

  const _SimpleTileMapPainter({
    required this.geometry,
    required this.shape,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showLegend,
    required this.showActiveTile,
    required this.tileRadius,
    required this.valueFormatter,
    required this.activeTile,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final tile in geometry.tiles) {
      _drawTile(canvas, tile);
    }
    if (showLegend) {
      _drawLegend(canvas);
    }
  }

  void _drawTile(Canvas canvas, _TileLayout tile) {
    final drawProgress = progress.isFinite
        ? progress.clamp(0.0, 1.0).toDouble()
        : 1.0;
    final rect = Rect.fromCenter(
      center: tile.rect.center,
      width: tile.rect.width * drawProgress,
      height: tile.rect.height * drawProgress,
    );
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final path = _tilePath(rect);
    final active = activeTile == tile;
    if (showActiveTile && active) {
      canvas.drawPath(
        _tilePath(rect.inflate(4)),
        Paint()
          ..color = activeColor.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = tile.color.withValues(alpha: tile.data == null ? 0.34 : 1)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor.withValues(alpha: 0.86)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2 : 1
        ..isAntiAlias = true,
    );
    if (tile.data != null && (showLabels || showValues)) {
      _drawTileText(canvas, tile, rect, drawProgress);
    }
  }

  Path _tilePath(Rect rect) {
    switch (shape) {
      case SimpleTileMapShape.square:
        return Path()..addRect(rect);
      case SimpleTileMapShape.circle:
        return Path()..addOval(rect);
      case SimpleTileMapShape.hexagon:
        final cx = rect.center.dx;
        final cy = rect.center.dy;
        final rx = rect.width / 2;
        final ry = rect.height / 2;
        return Path()
          ..moveTo(cx + rx, cy)
          ..lineTo(cx + rx / 2, cy + ry)
          ..lineTo(cx - rx / 2, cy + ry)
          ..lineTo(cx - rx, cy)
          ..lineTo(cx - rx / 2, cy - ry)
          ..lineTo(cx + rx / 2, cy - ry)
          ..close();
      case SimpleTileMapShape.rounded:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(math.min(tileRadius, rect.shortestSide / 2)),
          ),
        );
    }
  }

  void _drawTileText(
    Canvas canvas,
    _TileLayout tile,
    Rect rect,
    double drawProgress,
  ) {
    final maxTextWidth = math.max(0.0, rect.width - 8);
    if (maxTextWidth <= 0 || rect.height <= 0) {
      return;
    }
    final data = tile.data!;
    final readable = _readableTextColor(tile.color);
    final label = data.code?.trim().isNotEmpty == true
        ? data.code!
        : data.label;
    if (showLabels) {
      _drawText(
        canvas,
        label,
        Offset(rect.left + 4, rect.center.dy - (showValues ? 14 : 7)),
        labelStyle.copyWith(
          color: readable.withValues(alpha: drawProgress),
          fontWeight: FontWeight.w900,
        ),
        maxWidth: maxTextWidth,
        align: TextAlign.center,
      );
    }
    if (showValues && rect.height >= 34) {
      _drawText(
        canvas,
        valueFormatter(data.value),
        Offset(rect.left + 4, rect.center.dy + (showLabels ? 2 : -7)),
        valueStyle.copyWith(
          color: readable.withValues(alpha: 0.86 * drawProgress),
        ),
        maxWidth: maxTextWidth,
        align: TextAlign.center,
      );
    }
  }

  void _drawLegend(Canvas canvas) {
    final rect = geometry.legendRect;
    if (rect.isEmpty) {
      return;
    }
    final gradientRect = Rect.fromLTWH(
      rect.center.dx - 5,
      rect.top + 10,
      10,
      math.max(20, rect.height - 34),
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [geometry.lowColor, geometry.highColor],
      ).createShader(gradientRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(gradientRect, const Radius.circular(6)),
      paint,
    );
    _drawText(
      canvas,
      valueFormatter(geometry.maxValue),
      Offset(rect.left, gradientRect.top - 12),
      valueStyle,
      maxWidth: rect.width,
      align: TextAlign.center,
    );
    _drawText(
      canvas,
      valueFormatter(geometry.minValue),
      Offset(rect.left, gradientRect.bottom + 4),
      valueStyle,
      maxWidth: rect.width,
      align: TextAlign.center,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double? maxWidth,
    TextAlign align = TextAlign.left,
  }) {
    if (maxWidth != null && (!maxWidth.isFinite || maxWidth <= 0)) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, offset);
  }

  Color _readableTextColor(Color background) {
    return background.computeLuminance() > 0.52 ? Colors.black : Colors.white;
  }

  @override
  bool shouldRepaint(covariant _SimpleTileMapPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.shape != shape ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveTile != showActiveTile ||
        oldDelegate.tileRadius != tileRadius ||
        oldDelegate.activeTile != activeTile ||
        oldDelegate.progress != progress;
  }
}

class _TileMapGeometry {
  final List<_TileLayout> tiles;
  final Rect legendRect;
  final double minValue;
  final double maxValue;
  final Color lowColor;
  final Color highColor;

  const _TileMapGeometry({
    required this.tiles,
    required this.legendRect,
    required this.minValue,
    required this.maxValue,
    required this.lowColor,
    required this.highColor,
  });

  factory _TileMapGeometry.resolve({
    required Size size,
    required List<SimpleTileMapData> data,
    required SimpleTileMapShape shape,
    required int? rows,
    required int? columns,
    required double? minValue,
    required double? maxValue,
    required EdgeInsets padding,
    required Color lowColor,
    required Color highColor,
    required Color emptyColor,
    required bool showLegend,
    required bool showEmptyTiles,
    required double tileGap,
  }) {
    final resolvedRows =
        rows ?? data.map((item) => item.row).fold<int>(0, math.max) + 1;
    final resolvedColumns =
        columns ?? data.map((item) => item.column).fold<int>(0, math.max) + 1;
    final legendWidth = showLegend ? 44.0 : 0.0;
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal - legendWidth),
      math.max(1, size.height - padding.vertical),
    );
    final slot = math.min(
      plotRect.width / resolvedColumns,
      plotRect.height / resolvedRows,
    );
    final tileSize = math.max(1.0, slot - tileGap);
    final gridWidth = slot * resolvedColumns;
    final gridHeight = slot * resolvedRows;
    final origin = Offset(
      plotRect.left + (plotRect.width - gridWidth) / 2,
      plotRect.top + (plotRect.height - gridHeight) / 2,
    );
    final values = data.map((item) => item.value).toList();
    var low = minValue ?? values.reduce(math.min);
    var high = maxValue ?? values.reduce(math.max);
    if (low == high) {
      high = low + 1;
    }
    final byPosition = <String, (SimpleTileMapData, int)>{};
    for (var i = 0; i < data.length; i++) {
      byPosition['${data[i].row}:${data[i].column}'] = (data[i], i);
    }
    final tiles = <_TileLayout>[];
    for (var row = 0; row < resolvedRows; row++) {
      for (var column = 0; column < resolvedColumns; column++) {
        final entry = byPosition['$row:$column'];
        if (entry == null && !showEmptyTiles) {
          continue;
        }
        final data = entry?.$1;
        final index = entry?.$2 ?? -1;
        final center = Offset(
          origin.dx + column * slot + slot / 2,
          origin.dy + row * slot + slot / 2,
        );
        final rect = Rect.fromCenter(
          center: center,
          width: shape == SimpleTileMapShape.hexagon
              ? tileSize * 0.92
              : tileSize,
          height: tileSize,
        );
        final color =
            data?.color ??
            (data == null
                ? emptyColor
                : _colorFor(data.value, low, high, lowColor, highColor));
        tiles.add(
          _TileLayout(
            data: data,
            index: index,
            row: row,
            column: column,
            rect: rect,
            color: color,
          ),
        );
      }
    }
    final legendRect = showLegend
        ? Rect.fromLTWH(
            size.width - padding.right - legendWidth + 4,
            padding.top,
            legendWidth - 8,
            math.max(1, size.height - padding.vertical),
          )
        : Rect.zero;
    return _TileMapGeometry(
      tiles: tiles,
      legendRect: legendRect,
      minValue: low,
      maxValue: high,
      lowColor: lowColor,
      highColor: highColor,
    );
  }

  static Color _colorFor(
    double value,
    double minValue,
    double maxValue,
    Color lowColor,
    Color highColor,
  ) {
    final span = maxValue - minValue;
    final t = span <= 0 ? 0.0 : ((value - minValue) / span).clamp(0.0, 1.0);
    return Color.lerp(lowColor, highColor, t.toDouble()) ?? highColor;
  }
}

class _TileLayout {
  final SimpleTileMapData? data;
  final int index;
  final int row;
  final int column;
  final Rect rect;
  final Color color;

  const _TileLayout({
    required this.data,
    required this.index,
    required this.row,
    required this.column,
    required this.rect,
    required this.color,
  });
}

class _SimpleTileMapVisuals {
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color borderColor;
  final Color activeColor;

  const _SimpleTileMapVisuals({
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.borderColor,
    required this.activeColor,
  });

  factory _SimpleTileMapVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleTileMapVisuals(
          lowColor: colorScheme.primaryContainer,
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.42,
          ),
          borderColor: colorScheme.surface,
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.professional:
        return const _SimpleTileMapVisuals(
          lowColor: Color(0xFFDBEAFE),
          highColor: Color(0xFF1D4ED8),
          emptyColor: Color(0xFFE2E8F0),
          borderColor: Color(0xFFFFFFFF),
          activeColor: Color(0xFF0F172A),
        );
      case SimpleBarChartStyle.education:
        return const _SimpleTileMapVisuals(
          lowColor: Color(0xFFFFEDD5),
          highColor: Color(0xFFF97316),
          emptyColor: Color(0xFFE0F2FE),
          borderColor: Color(0xFFFFFFFF),
          activeColor: Color(0xFF2563EB),
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleTileMapVisuals(
          lowColor: const Color(0xFFCCFBF1),
          highColor: const Color(0xFF8B5CF6),
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.38,
          ),
          borderColor: colorScheme.surface,
          activeColor: const Color(0xFFF43F5E),
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleTileMapVisuals(
          lowColor: colorScheme.secondaryContainer,
          highColor: colorScheme.secondary,
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.44,
          ),
          borderColor: colorScheme.surface,
          activeColor: colorScheme.secondary,
        );
    }
  }
}

class _DefaultTileMapTooltip extends StatelessWidget {
  final SimpleTileMapData data;
  final String formattedValue;

  const _DefaultTileMapTooltip({
    required this.data,
    required this.formattedValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 176,
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
              if (data.code != null && data.code!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(data.code!, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
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
            ],
          ),
        ),
      ),
    );
  }
}
