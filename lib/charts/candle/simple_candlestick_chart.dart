import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';
import '../common/simple_chart_reference_line.dart';

// Legacy compatibility chart for the old `package:tenun` financial surface.
// Prefer `package:tenun_pro/tenun_pro_financial.dart` for new usage.

typedef SimpleCandlestickValueFormatter = String Function(double value);
typedef SimpleCandlestickVolumeFormatter = String Function(double value);
@Deprecated(
  'Financial chart widgets moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use SimpleCandlestickTapCallback from tenun_pro instead.',
)
typedef SimpleCandlestickTapCallback =
    void Function(SimpleCandlestickData data, int index);
@Deprecated(
  'Financial chart widgets moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use SimpleCandlestickTooltipBuilder from tenun_pro instead.',
)
typedef SimpleCandlestickTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleCandlestickData data,
      int index,
      String formattedOpen,
      String formattedHigh,
      String formattedLow,
      String formattedClose,
      String formattedChange,
      String? formattedVolume,
    );

@Deprecated(
  'Financial chart widgets moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use SimpleCandlestickChartMode from tenun_pro instead.',
)
enum SimpleCandlestickChartMode { candlestick, ohlc }

@Deprecated(
  'Financial chart widgets moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use SimpleCandlestickData from tenun_pro instead.',
)
class SimpleCandlestickData {
  final String label;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;
  final Color? color;

  const SimpleCandlestickData({
    required this.label,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
    this.color,
  });

  bool get isBullish => close >= open;
  double get change => close - open;
  double get changePercent => open == 0 ? 0 : change / open * 100;
  double get rangeHigh => math.max(math.max(open, close), math.max(high, low));
  double get rangeLow => math.min(math.min(open, close), math.min(high, low));
}

/// A compact candlestick or OHLC chart for price action, KPI movement,
/// operational open/high/low/close ranges, and market-style dashboards.
@Deprecated(
  'Financial chart widgets moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use SimpleCandlestickChart from tenun_pro instead.',
)
class SimpleCandlestickChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(46, 18, 50, 36);

  final List<SimpleCandlestickData> data;
  final SimpleCandlestickChartMode mode;
  final SimpleBarChartStyle style;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? bullishColor;
  final Color? bearishColor;
  final Color? wickColor;
  final Color? volumeColor;
  final Color? gridColor;
  final Color? axisColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showVolume;
  final bool showTooltip;
  final bool showActiveCandle;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double volumePaneFraction;
  final double candleWidthFactor;
  final double? maxCandleWidth;
  final double wickWidth;
  final double bodyRadius;
  final SimpleCandlestickValueFormatter? valueFormatter;
  final SimpleCandlestickVolumeFormatter? volumeFormatter;
  final SimpleCandlestickTapCallback? onCandleTap;
  final SimpleCandlestickTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleCandlestickChart({
    super.key,
    required this.data,
    this.mode = SimpleCandlestickChartMode.candlestick,
    this.style = SimpleBarChartStyle.elegant,
    this.minValue,
    this.maxValue,
    this.height = 280,
    this.padding = _defaultPadding,
    this.bullishColor,
    this.bearishColor,
    this.wickColor,
    this.volumeColor,
    this.gridColor,
    this.axisColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showGrid = true,
    this.showLabels = true,
    this.showValues = false,
    this.showVolume = true,
    this.showTooltip = true,
    this.showActiveCandle = true,
    this.referenceLines = const [],
    this.referenceBands = const [],
    this.gridLineCount = 4,
    this.volumePaneFraction = 0.22,
    this.candleWidthFactor = 0.62,
    this.maxCandleWidth,
    this.wickWidth = 1.4,
    this.bodyRadius = 3,
    this.valueFormatter,
    this.volumeFormatter,
    this.onCandleTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(gridLineCount >= 2),
       assert(volumePaneFraction >= 0 && volumePaneFraction < 0.5),
       assert(candleWidthFactor > 0 && candleWidthFactor <= 1),
       assert(maxCandleWidth == null || maxCandleWidth > 0),
       assert(wickWidth > 0),
       assert(bodyRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleCandlestickVisuals.resolve(style, colorScheme);
    final visibleData = data.where(_isValid).toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedVolumeFormatter = volumeFormatter ?? _defaultVolumeFormatter;

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
            emptySemanticLabel: 'Candlestick chart, no data.',
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
          child: _SimpleCandlestickChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            mode: mode,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            bullishColor: bullishColor ?? visuals.bullishColor,
            bearishColor: bearishColor ?? visuals.bearishColor,
            wickColor: wickColor,
            volumeColor: volumeColor ?? visuals.volumeColor,
            gridColor: gridColor ?? visuals.gridColor,
            axisColor: axisColor ?? visuals.axisColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showGrid: showGrid,
            showLabels: showLabels,
            showValues: showValues,
            showVolume: showVolume,
            showTooltip: showTooltip,
            showActiveCandle: showActiveCandle,
            referenceLines: referenceLines,
            referenceBands: referenceBands,
            gridLineCount: gridLineCount,
            volumePaneFraction: volumePaneFraction,
            candleWidthFactor: candleWidthFactor,
            maxCandleWidth: maxCandleWidth ?? visuals.maxCandleWidth,
            wickWidth: wickWidth,
            bodyRadius: bodyRadius,
            valueFormatter: formatter,
            volumeFormatter: resolvedVolumeFormatter,
            onCandleTap: onCandleTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static bool _isValid(SimpleCandlestickData item) {
    return item.open.isFinite &&
        item.high.isFinite &&
        item.low.isFinite &&
        item.close.isFinite &&
        (item.volume == null || item.volume!.isFinite);
  }

  static String _defaultSemanticLabel(
    List<SimpleCandlestickData> data,
    SimpleCandlestickValueFormatter formatter,
  ) {
    final sample = data
        .take(5)
        .map((item) {
          final direction = item.isBullish ? 'up' : 'down';
          final sign = item.change >= 0 ? '+' : '';
          return '${item.label} open ${formatter(item.open)}, close '
              '${formatter(item.close)}, $direction $sign'
              '${formatter(item.change.abs())}';
        })
        .join(', ');
    final suffix = data.length > 5 ? ', and ${data.length - 5} more' : '';
    return 'Candlestick chart, ${data.length} candles. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) =>
      value.toStringAsFixed(2);

  static String _defaultVolumeFormatter(double value) {
    final abs = value.abs();
    if (abs >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (abs >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (abs >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _SimpleCandlestickChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleCandlestickData> data;
  final SimpleCandlestickChartMode mode;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color bullishColor;
  final Color bearishColor;
  final Color? wickColor;
  final Color volumeColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showVolume;
  final bool showTooltip;
  final bool showActiveCandle;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double volumePaneFraction;
  final double candleWidthFactor;
  final double maxCandleWidth;
  final double wickWidth;
  final double bodyRadius;
  final SimpleCandlestickValueFormatter valueFormatter;
  final SimpleCandlestickVolumeFormatter volumeFormatter;
  final SimpleCandlestickTapCallback? onCandleTap;
  final SimpleCandlestickTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleCandlestickChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.mode,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.bullishColor,
    required this.bearishColor,
    required this.wickColor,
    required this.volumeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showVolume,
    required this.showTooltip,
    required this.showActiveCandle,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.volumePaneFraction,
    required this.candleWidthFactor,
    required this.maxCandleWidth,
    required this.wickWidth,
    required this.bodyRadius,
    required this.valueFormatter,
    required this.volumeFormatter,
    required this.onCandleTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleCandlestickChartView> createState() =>
      _SimpleCandlestickChartViewState();
}

class _SimpleCandlestickChartViewState
    extends State<_SimpleCandlestickChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  int? _activeIndex;
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
  void didUpdateWidget(covariant _SimpleCandlestickChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.mode != widget.mode ||
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
          final size = Size(widget.width, widget.height);
          return Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onHover: (event) {
                    final index = _indexAt(event.localPosition, size);
                    setState(() {
                      _activeIndex = index;
                      _pointer = event.localPosition;
                    });
                  },
                  onExit: (_) => setState(() => _activeIndex = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final index = _indexAt(details.localPosition, size);
                      setState(() {
                        _activeIndex = index;
                        _pointer = details.localPosition;
                      });
                      if (index != null) {
                        widget.onCandleTap?.call(widget.data[index], index);
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SimpleCandlestickPainter(
                            data: widget.data,
                            mode: widget.mode,
                            minValue: widget.minValue,
                            maxValue: widget.maxValue,
                            padding: widget.padding,
                            bullishColor: widget.bullishColor,
                            bearishColor: widget.bearishColor,
                            wickColor: widget.wickColor,
                            volumeColor: widget.volumeColor,
                            gridColor: widget.gridColor,
                            axisColor: widget.axisColor,
                            activeColor: widget.activeColor,
                            labelStyle: widget.labelStyle,
                            valueStyle: widget.valueStyle,
                            showGrid: widget.showGrid,
                            showLabels: widget.showLabels,
                            showValues: widget.showValues,
                            showVolume: widget.showVolume,
                            showActiveCandle: widget.showActiveCandle,
                            referenceLines: widget.referenceLines,
                            referenceBands: widget.referenceBands,
                            gridLineCount: widget.gridLineCount,
                            volumePaneFraction: widget.volumePaneFraction,
                            candleWidthFactor: widget.candleWidthFactor,
                            maxCandleWidth: widget.maxCandleWidth,
                            wickWidth: widget.wickWidth,
                            bodyRadius: widget.bodyRadius,
                            valueFormatter: widget.valueFormatter,
                            volumeFormatter: widget.volumeFormatter,
                            activeIndex: _activeIndex,
                            progress: _animation.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip &&
                  _activeIndex != null &&
                  _activeIndex! >= 0 &&
                  _activeIndex! < widget.data.length)
                _buildTooltip(context, size, widget.data[_activeIndex!]),
            ],
          );
        },
      ),
    );
  }

  int? _indexAt(Offset position, Size size) {
    final layout = _SimpleCandlestickLayout.resolve(
      size,
      widget.padding,
      widget.showVolume && widget.data.any((item) => item.volume != null),
      widget.volumePaneFraction,
    );
    if (!layout.interactionRect.contains(position)) {
      return null;
    }
    final slotWidth = layout.priceRect.width / widget.data.length;
    if (slotWidth <= 0) {
      return null;
    }
    final index = ((position.dx - layout.priceRect.left) / slotWidth).floor();
    return index.clamp(0, widget.data.length - 1).toInt();
  }

  Widget _buildTooltip(
    BuildContext context,
    Size size,
    SimpleCandlestickData item,
  ) {
    final formattedOpen = widget.valueFormatter(item.open);
    final formattedHigh = widget.valueFormatter(item.rangeHigh);
    final formattedLow = widget.valueFormatter(item.rangeLow);
    final formattedClose = widget.valueFormatter(item.close);
    final sign = item.change >= 0 ? '+' : '-';
    final formattedChange =
        '$sign${widget.valueFormatter(item.change.abs())} '
        '($sign${item.changePercent.abs().toStringAsFixed(1)}%)';
    final formattedVolume = item.volume == null
        ? null
        : widget.volumeFormatter(item.volume!);
    final child =
        widget.tooltipBuilder?.call(
          context,
          item,
          _activeIndex!,
          formattedOpen,
          formattedHigh,
          formattedLow,
          formattedClose,
          formattedChange,
          formattedVolume,
        ) ??
        _DefaultCandlestickTooltip(
          color:
              item.color ??
              (item.isBullish ? widget.bullishColor : widget.bearishColor),
          label: item.label,
          open: formattedOpen,
          high: formattedHigh,
          low: formattedLow,
          close: formattedClose,
          change: formattedChange,
          volume: formattedVolume,
        );
    const tooltipWidth = 190.0;
    const tooltipHeight = 142.0;
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

class _SimpleCandlestickPainter extends CustomPainter {
  final List<SimpleCandlestickData> data;
  final SimpleCandlestickChartMode mode;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color bullishColor;
  final Color bearishColor;
  final Color? wickColor;
  final Color volumeColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showGrid;
  final bool showLabels;
  final bool showValues;
  final bool showVolume;
  final bool showActiveCandle;
  final List<SimpleChartReferenceLine> referenceLines;
  final List<SimpleChartReferenceBand> referenceBands;
  final int gridLineCount;
  final double volumePaneFraction;
  final double candleWidthFactor;
  final double maxCandleWidth;
  final double wickWidth;
  final double bodyRadius;
  final SimpleCandlestickValueFormatter valueFormatter;
  final SimpleCandlestickVolumeFormatter volumeFormatter;
  final int? activeIndex;
  final double progress;

  const _SimpleCandlestickPainter({
    required this.data,
    required this.mode,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.bullishColor,
    required this.bearishColor,
    required this.wickColor,
    required this.volumeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showGrid,
    required this.showLabels,
    required this.showValues,
    required this.showVolume,
    required this.showActiveCandle,
    required this.referenceLines,
    required this.referenceBands,
    required this.gridLineCount,
    required this.volumePaneFraction,
    required this.candleWidthFactor,
    required this.maxCandleWidth,
    required this.wickWidth,
    required this.bodyRadius,
    required this.valueFormatter,
    required this.volumeFormatter,
    required this.activeIndex,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      return;
    }
    final layout = _SimpleCandlestickLayout.resolve(
      size,
      padding,
      showVolume && data.any((item) => item.volume != null),
      volumePaneFraction,
    );
    if (layout.priceRect.width <= 0 || layout.priceRect.height <= 0) {
      return;
    }

    final domain = _SimpleCandlestickDomain.resolve(
      data: data,
      minValue: minValue,
      maxValue: maxValue,
      referenceLines: referenceLines,
      referenceBands: referenceBands,
    );
    final slotWidth = layout.priceRect.width / data.length;
    final candleWidth = math.min(
      maxCandleWidth,
      math.max(2.0, slotWidth * candleWidthFactor),
    );
    final labelStep = math.max(1, (44 / math.max(1, slotWidth)).ceil());

    if (showActiveCandle &&
        activeIndex != null &&
        activeIndex! >= 0 &&
        activeIndex! < data.length) {
      final left = layout.priceRect.left + activeIndex! * slotWidth;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left,
            layout.priceRect.top,
            slotWidth,
            layout.interactionRect.height,
          ),
          const Radius.circular(6),
        ),
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill,
      );
    }

    _drawReferenceBands(canvas, layout.priceRect, domain);
    if (showGrid) {
      _drawGrid(canvas, layout.priceRect, domain);
    }
    _drawReferenceLines(canvas, layout.priceRect, domain);
    _drawAxes(canvas, layout, domain);
    _drawCandles(canvas, layout.priceRect, domain, slotWidth, candleWidth);
    if (layout.hasVolume) {
      _drawVolume(canvas, layout.volumeRect, slotWidth, candleWidth);
    }
    if (showLabels) {
      _drawXLabels(canvas, layout.priceRect, slotWidth, labelStep);
    }
  }

  void _drawReferenceBands(
    Canvas canvas,
    Rect rect,
    _SimpleCandlestickDomain domain,
  ) {
    for (final band in referenceBands) {
      final low = math.min(band.from, band.to);
      final high = math.max(band.from, band.to);
      if (high < domain.min || low > domain.max) {
        continue;
      }
      final top = _yFor(
        high.clamp(domain.min, domain.max).toDouble(),
        rect,
        domain,
      );
      final bottom = _yFor(
        low.clamp(domain.min, domain.max).toDouble(),
        rect,
        domain,
      );
      canvas.drawRect(
        Rect.fromLTRB(rect.left, top, rect.right, bottom),
        Paint()
          ..color = (band.color ?? bullishColor).withValues(alpha: band.opacity)
          ..style = PaintingStyle.fill,
      );
      if (band.showLabel && band.label != null) {
        _drawText(
          canvas,
          band.label!,
          Offset(rect.left + 6, top + 3),
          labelStyle.copyWith(
            color: (band.color ?? bullishColor).withValues(alpha: 0.9),
            fontWeight: FontWeight.w700,
          ),
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, Rect rect, _SimpleCandlestickDomain domain) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 0; i <= gridLineCount; i++) {
      final t = i / gridLineCount;
      final y = rect.top + rect.height * t;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
      if (showLabels) {
        final value = domain.max - (domain.max - domain.min) * t;
        _drawText(
          canvas,
          valueFormatter(value),
          Offset(rect.right + 6, y - 7),
          labelStyle,
        );
      }
    }
  }

  void _drawReferenceLines(
    Canvas canvas,
    Rect rect,
    _SimpleCandlestickDomain domain,
  ) {
    for (final line in referenceLines) {
      if (line.value < domain.min || line.value > domain.max) {
        continue;
      }
      final y = _yFor(line.value, rect, domain);
      final color = line.color ?? axisColor;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.78)
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke;
      if (line.lineStyle == SimpleChartReferenceLineStyle.solid) {
        canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
      } else {
        final dash = line.lineStyle == SimpleChartReferenceLineStyle.dotted
            ? 2.0
            : 6.0;
        var x = rect.left;
        while (x < rect.right) {
          canvas.drawLine(
            Offset(x, y),
            Offset(math.min(x + dash, rect.right), y),
            paint,
          );
          x += dash * 2;
        }
      }
      if (line.showLabel && line.label != null) {
        _drawText(
          canvas,
          line.label!,
          Offset(rect.left + 6, y - 16),
          labelStyle.copyWith(color: color, fontWeight: FontWeight.w700),
        );
      }
    }
  }

  void _drawAxes(
    Canvas canvas,
    _SimpleCandlestickLayout layout,
    _SimpleCandlestickDomain domain,
  ) {
    final paint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(layout.priceRect.left, layout.priceRect.bottom),
      Offset(layout.priceRect.right, layout.priceRect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(layout.priceRect.left, layout.priceRect.top),
      Offset(layout.priceRect.left, layout.priceRect.bottom),
      paint,
    );
    if (layout.hasVolume) {
      canvas.drawLine(
        Offset(layout.volumeRect.left, layout.volumeRect.top),
        Offset(layout.volumeRect.right, layout.volumeRect.top),
        Paint()
          ..color = gridColor
          ..strokeWidth = 1,
      );
      if (showLabels) {
        final maxVolume = data
            .map((item) => item.volume ?? 0)
            .fold<double>(0, math.max);
        _drawText(
          canvas,
          volumeFormatter(maxVolume),
          Offset(layout.volumeRect.right + 6, layout.volumeRect.top - 6),
          labelStyle,
        );
      }
    }
  }

  void _drawCandles(
    Canvas canvas,
    Rect rect,
    _SimpleCandlestickDomain domain,
    double slotWidth,
    double candleWidth,
  ) {
    canvas.save();
    canvas.clipRect(rect);
    final labelStep = math.max(1, (50 / math.max(1, slotWidth)).ceil());
    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final centerX = rect.left + (i + 0.5) * slotWidth;
      final color =
          item.color ?? (item.isBullish ? bullishColor : bearishColor);
      final wickPaint = Paint()
        ..color = wickColor ?? color
        ..strokeWidth = wickWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      final mid = (item.open + item.close) / 2;
      final high = _lerp(mid, item.rangeHigh, progress);
      final low = _lerp(mid, item.rangeLow, progress);
      final open = _lerp(mid, item.open, progress);
      final close = _lerp(mid, item.close, progress);
      final highY = _yFor(high, rect, domain);
      final lowY = _yFor(low, rect, domain);
      final openY = _yFor(open, rect, domain);
      final closeY = _yFor(close, rect, domain);
      final isActive = i == activeIndex;
      if (isActive) {
        canvas.drawLine(
          Offset(centerX, rect.top),
          Offset(centerX, rect.bottom),
          Paint()
            ..color = color.withValues(alpha: 0.2)
            ..strokeWidth = 1,
        );
      }
      canvas.drawLine(Offset(centerX, highY), Offset(centerX, lowY), wickPaint);
      if (mode == SimpleCandlestickChartMode.ohlc) {
        canvas.drawLine(
          Offset(centerX - candleWidth / 2, openY),
          Offset(centerX, openY),
          wickPaint..strokeWidth = wickWidth + 0.5,
        );
        canvas.drawLine(
          Offset(centerX, closeY),
          Offset(centerX + candleWidth / 2, closeY),
          wickPaint,
        );
      } else {
        final top = math.min(openY, closeY);
        final bottom = math.max(openY, closeY);
        final bodyHeight = math.max(1.5, bottom - top);
        final bodyRect = Rect.fromLTWH(
          centerX - candleWidth / 2,
          top,
          candleWidth,
          bodyHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            bodyRect,
            Radius.circular(math.min(bodyRadius, candleWidth / 2)),
          ),
          fillPaint,
        );
      }
      if (showValues && slotWidth >= 34 && i % labelStep == 0) {
        final textY = math.min(openY, closeY) - 16;
        _drawText(
          canvas,
          valueFormatter(item.close),
          Offset(
            centerX - candleWidth,
            textY.clamp(rect.top, rect.bottom).toDouble(),
          ),
          valueStyle.copyWith(color: color),
        );
      }
    }
    canvas.restore();
  }

  void _drawVolume(
    Canvas canvas,
    Rect rect,
    double slotWidth,
    double candleWidth,
  ) {
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final maxVolume = data
        .map((item) => item.volume ?? 0)
        .fold<double>(0, math.max);
    if (maxVolume <= 0) {
      return;
    }
    canvas.save();
    canvas.clipRect(rect);
    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final volume = item.volume ?? 0;
      final centerX = rect.left + (i + 0.5) * slotWidth;
      final barHeight = rect.height * (volume / maxVolume) * progress;
      final color =
          (item.color ?? (item.isBullish ? bullishColor : bearishColor))
              .withValues(alpha: 0.42);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            centerX - candleWidth / 2,
            rect.bottom - barHeight,
            candleWidth,
            barHeight,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = Color.alphaBlend(volumeColor.withValues(alpha: 0.18), color)
          ..style = PaintingStyle.fill,
      );
    }
    canvas.restore();
  }

  void _drawXLabels(
    Canvas canvas,
    Rect priceRect,
    double slotWidth,
    int labelStep,
  ) {
    for (var i = 0; i < data.length; i += labelStep) {
      final centerX = priceRect.left + (i + 0.5) * slotWidth;
      _drawText(
        canvas,
        data[i].label,
        Offset(centerX - slotWidth / 2, priceRect.bottom + 8),
        labelStyle,
        maxWidth: slotWidth * labelStep,
        align: TextAlign.center,
      );
    }
  }

  double _yFor(double value, Rect rect, _SimpleCandlestickDomain domain) {
    final span = domain.max - domain.min;
    if (span <= 0) {
      return rect.center.dy;
    }
    final t = ((value - domain.min) / span).clamp(0.0, 1.0);
    return rect.bottom - rect.height * t;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double? maxWidth,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, offset);
  }

  static double _lerp(double from, double to, double t) =>
      from + (to - from) * t;

  @override
  bool shouldRepaint(covariant _SimpleCandlestickPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.mode != mode ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.bullishColor != bullishColor ||
        oldDelegate.bearishColor != bearishColor ||
        oldDelegate.wickColor != wickColor ||
        oldDelegate.volumeColor != volumeColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showVolume != showVolume ||
        oldDelegate.showActiveCandle != showActiveCandle ||
        oldDelegate.referenceLines != referenceLines ||
        oldDelegate.referenceBands != referenceBands ||
        oldDelegate.gridLineCount != gridLineCount ||
        oldDelegate.volumePaneFraction != volumePaneFraction ||
        oldDelegate.candleWidthFactor != candleWidthFactor ||
        oldDelegate.maxCandleWidth != maxCandleWidth ||
        oldDelegate.wickWidth != wickWidth ||
        oldDelegate.bodyRadius != bodyRadius ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.progress != progress;
  }
}

class _SimpleCandlestickLayout {
  final Rect priceRect;
  final Rect volumeRect;
  final Rect interactionRect;
  final bool hasVolume;

  const _SimpleCandlestickLayout({
    required this.priceRect,
    required this.volumeRect,
    required this.interactionRect,
    required this.hasVolume,
  });

  factory _SimpleCandlestickLayout.resolve(
    Size size,
    EdgeInsets padding,
    bool hasVolume,
    double volumePaneFraction,
  ) {
    final width = math.max(1.0, size.width - padding.left - padding.right);
    final height = math.max(1.0, size.height - padding.top - padding.bottom);
    final volumeHeight = hasVolume ? height * volumePaneFraction : 0.0;
    final gap = hasVolume ? 12.0 : 0.0;
    final priceHeight = math.max(1.0, height - volumeHeight - gap);
    final priceRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      width,
      priceHeight,
    );
    final volumeRect = hasVolume
        ? Rect.fromLTWH(
            padding.left,
            priceRect.bottom + gap,
            width,
            volumeHeight,
          )
        : Rect.zero;
    final interactionRect = Rect.fromLTRB(
      priceRect.left,
      priceRect.top,
      priceRect.right,
      hasVolume ? volumeRect.bottom : priceRect.bottom,
    );
    return _SimpleCandlestickLayout(
      priceRect: priceRect,
      volumeRect: volumeRect,
      interactionRect: interactionRect,
      hasVolume: hasVolume,
    );
  }
}

class _SimpleCandlestickDomain {
  final double min;
  final double max;

  const _SimpleCandlestickDomain(this.min, this.max);

  factory _SimpleCandlestickDomain.resolve({
    required List<SimpleCandlestickData> data,
    required double? minValue,
    required double? maxValue,
    required List<SimpleChartReferenceLine> referenceLines,
    required List<SimpleChartReferenceBand> referenceBands,
  }) {
    final values = <double>[
      for (final item in data) ...[item.rangeLow, item.rangeHigh],
      for (final line in referenceLines) line.value,
      for (final band in referenceBands) ...[band.from, band.to],
    ].where((value) => value.isFinite).toList();
    var min = minValue ?? values.reduce(math.min);
    var max = maxValue ?? values.reduce(math.max);
    if (!min.isFinite || !max.isFinite) {
      min = 0;
      max = 1;
    }
    if (min == max) {
      final pad = min.abs() * 0.08 + 1;
      min -= pad;
      max += pad;
    } else {
      final pad = (max - min) * 0.06;
      min = minValue ?? min - pad;
      max = maxValue ?? max + pad;
    }
    if (min > max) {
      final tmp = min;
      min = max;
      max = tmp;
    }
    return _SimpleCandlestickDomain(min, max);
  }
}

class _SimpleCandlestickVisuals {
  final Color bullishColor;
  final Color bearishColor;
  final Color volumeColor;
  final Color gridColor;
  final Color axisColor;
  final Color activeColor;
  final double maxCandleWidth;

  const _SimpleCandlestickVisuals({
    required this.bullishColor,
    required this.bearishColor,
    required this.volumeColor,
    required this.gridColor,
    required this.axisColor,
    required this.activeColor,
    required this.maxCandleWidth,
  });

  factory _SimpleCandlestickVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleCandlestickVisuals(
          bullishColor: const Color(0xFF10B981),
          bearishColor: colorScheme.error,
          volumeColor: colorScheme.primary,
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          axisColor: colorScheme.outline.withValues(alpha: 0.52),
          activeColor: colorScheme.primary.withValues(alpha: 0.08),
          maxCandleWidth: 22,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleCandlestickVisuals(
          bullishColor: const Color(0xFF0F766E),
          bearishColor: const Color(0xFFB91C1C),
          volumeColor: const Color(0xFF475569),
          gridColor: const Color(0xFF94A3B8).withValues(alpha: 0.28),
          axisColor: const Color(0xFF475569).withValues(alpha: 0.7),
          activeColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
          maxCandleWidth: 18,
        );
      case SimpleBarChartStyle.education:
        return _SimpleCandlestickVisuals(
          bullishColor: const Color(0xFF2563EB),
          bearishColor: const Color(0xFFF97316),
          volumeColor: const Color(0xFF7C3AED),
          gridColor: const Color(0xFF94A3B8).withValues(alpha: 0.2),
          axisColor: const Color(0xFF475569).withValues(alpha: 0.58),
          activeColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
          maxCandleWidth: 24,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleCandlestickVisuals(
          bullishColor: const Color(0xFF14B8A6),
          bearishColor: const Color(0xFFF43F5E),
          volumeColor: const Color(0xFF8B5CF6),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.28),
          axisColor: colorScheme.outline.withValues(alpha: 0.55),
          activeColor: const Color(0xFF8B5CF6).withValues(alpha: 0.09),
          maxCandleWidth: 26,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleCandlestickVisuals(
          bullishColor: const Color(0xFF059669),
          bearishColor: const Color(0xFFE11D48),
          volumeColor: colorScheme.secondary,
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
          axisColor: colorScheme.outline.withValues(alpha: 0.48),
          activeColor: colorScheme.secondary.withValues(alpha: 0.09),
          maxCandleWidth: 20,
        );
    }
  }
}

class _DefaultCandlestickTooltip extends StatelessWidget {
  final Color color;
  final String label;
  final String open;
  final String high;
  final String low;
  final String close;
  final String change;
  final String? volume;

  const _DefaultCandlestickTooltip({
    required this.color,
    required this.label,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.change,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _TooltipRow(label: 'Open', value: open),
              _TooltipRow(label: 'High', value: high),
              _TooltipRow(label: 'Low', value: low),
              _TooltipRow(label: 'Close', value: close),
              _TooltipRow(label: 'Change', value: change, valueColor: color),
              if (volume != null) _TooltipRow(label: 'Volume', value: volume!),
            ],
          ),
        ),
      ),
    );
  }
}

class _TooltipRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _TooltipRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
