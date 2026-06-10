import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimplePictogramValueFormatter = String Function(double value);
typedef SimplePictogramTapCallback =
    void Function(
      SimplePictogramChartData data,
      int index,
      double share,
      int unitCount,
    );
typedef SimplePictogramTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimplePictogramChartData data,
      int index,
      String formattedValue,
      String formattedShare,
      int unitCount,
    );

enum SimplePictogramSymbol { person, circle, square, star, check }

enum SimplePictogramFillDirection { bottomToTop, leftToRight, rightToLeft }

class SimplePictogramChartData {
  final String label;
  final double value;
  final Color? color;

  const SimplePictogramChartData({
    required this.label,
    required this.value,
    this.color,
  });
}

/// A compact icon-array chart for countable part-to-whole stories.
class SimplePictogramChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 18, 18, 18);

  final List<SimplePictogramChartData> data;
  final SimpleBarChartStyle style;
  final double? totalValue;
  final int rows;
  final int columns;
  final double height;
  final EdgeInsets padding;
  final SimplePictogramSymbol symbol;
  final SimplePictogramFillDirection fillDirection;
  final List<Color>? palette;
  final Color? symbolColor;
  final Color? emptyColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLegend;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveUnits;
  final bool showEmptyUnits;
  final double unitGap;
  final double symbolScale;
  final SimplePictogramValueFormatter? valueFormatter;
  final SimplePictogramValueFormatter? percentFormatter;
  final SimplePictogramTapCallback? onUnitTap;
  final SimplePictogramTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimplePictogramChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.totalValue,
    this.rows = 5,
    this.columns = 10,
    this.height = 260,
    this.padding = _defaultPadding,
    this.symbol = SimplePictogramSymbol.person,
    this.fillDirection = SimplePictogramFillDirection.bottomToTop,
    this.palette,
    this.symbolColor,
    this.emptyColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLegend = true,
    this.showValues = true,
    this.showTooltip = true,
    this.showActiveUnits = true,
    this.showEmptyUnits = true,
    this.unitGap = 5,
    this.symbolScale = 0.82,
    this.valueFormatter,
    this.percentFormatter,
    this.onUnitTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(rows > 0),
       assert(columns > 0),
       assert(totalValue == null || totalValue > 0),
       assert(unitGap >= 0),
       assert(symbolScale > 0 && symbolScale <= 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimplePictogramVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.value.isFinite && item.value >= 0)
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
            emptySemanticLabel: 'Pictogram chart, no data.',
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
        final resolvedPalette = _resolvePalette(colorScheme, visuals.palette);
        final allocation = _PictogramAllocation.resolve(
          data: visibleData,
          total: resolvedTotal,
          totalUnits: rows * columns,
        );

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
          child: _SimplePictogramChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            total: resolvedTotal,
            allocation: allocation,
            rows: rows,
            columns: columns,
            padding: padding,
            symbol: symbol,
            fillDirection: fillDirection,
            palette: resolvedPalette,
            emptyColor: emptyColor ?? visuals.emptyColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLegend: showLegend,
            showValues: showValues,
            showTooltip: showTooltip,
            showActiveUnits: showActiveUnits,
            showEmptyUnits: showEmptyUnits,
            unitGap: unitGap,
            symbolScale: symbolScale,
            valueFormatter: formatter,
            percentFormatter: resolvedPercentFormatter,
            onUnitTap: onUnitTap,
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
    if (symbolColor != null) {
      return [
        symbolColor!,
        colorScheme.secondary,
        colorScheme.tertiary,
        colorScheme.error,
      ];
    }
    return defaults;
  }

  String _defaultSemanticLabel(
    List<SimplePictogramChartData> visibleData,
    double total,
    SimplePictogramValueFormatter formatter,
    SimplePictogramValueFormatter resolvedPercentFormatter,
  ) {
    final summaries = visibleData
        .take(6)
        .map((item) {
          final share = total <= 0 ? 0.0 : item.value / total;
          return '${item.label} ${formatter(item.value)}, '
              '${resolvedPercentFormatter(share)}';
        })
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'category' : 'categories';
    return 'Pictogram chart, ${visibleData.length} $countLabel. '
        '$summaries$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) {
    final percent = value * 100;
    if (percent == percent.roundToDouble()) {
      return '${percent.toInt()}%';
    }
    return '${percent.toStringAsFixed(1)}%';
  }
}

class _SimplePictogramChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimplePictogramChartData> data;
  final double total;
  final _PictogramAllocation allocation;
  final int rows;
  final int columns;
  final EdgeInsets padding;
  final SimplePictogramSymbol symbol;
  final SimplePictogramFillDirection fillDirection;
  final List<Color> palette;
  final Color emptyColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLegend;
  final bool showValues;
  final bool showTooltip;
  final bool showActiveUnits;
  final bool showEmptyUnits;
  final double unitGap;
  final double symbolScale;
  final SimplePictogramValueFormatter valueFormatter;
  final SimplePictogramValueFormatter percentFormatter;
  final SimplePictogramTapCallback? onUnitTap;
  final SimplePictogramTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimplePictogramChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.total,
    required this.allocation,
    required this.rows,
    required this.columns,
    required this.padding,
    required this.symbol,
    required this.fillDirection,
    required this.palette,
    required this.emptyColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLegend,
    required this.showValues,
    required this.showTooltip,
    required this.showActiveUnits,
    required this.showEmptyUnits,
    required this.unitGap,
    required this.symbolScale,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.onUnitTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimplePictogramChartView> createState() =>
      _SimplePictogramChartViewState();
}

class _SimplePictogramChartViewState extends State<_SimplePictogramChartView> {
  int? _activeDataIndex;
  Offset _activePosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveUnits ||
        widget.onUnitTap != null;

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
                painter: _SimplePictogramPainter(
                  data: widget.data,
                  total: widget.total,
                  allocation: widget.allocation,
                  rows: widget.rows,
                  columns: widget.columns,
                  padding: widget.padding,
                  symbol: widget.symbol,
                  fillDirection: widget.fillDirection,
                  palette: widget.palette,
                  emptyColor: widget.emptyColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showLegend: widget.showLegend,
                  showValues: widget.showValues,
                  showActiveUnits: widget.showActiveUnits,
                  showEmptyUnits: widget.showEmptyUnits,
                  unitGap: widget.unitGap,
                  symbolScale: widget.symbolScale,
                  activeDataIndex: _activeDataIndex,
                  valueFormatter: widget.valueFormatter,
                  percentFormatter: widget.percentFormatter,
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
                      final item = widget.data[selection.dataIndex];
                      widget.onUnitTap?.call(
                        item,
                        selection.dataIndex,
                        item.value / widget.total,
                        widget.allocation.countFor(selection.dataIndex),
                      );
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeDataIndex != null)
                _buildTooltip(context, size, _activeDataIndex!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_PictogramSelection? selection) {
    if (_activeDataIndex == selection?.dataIndex &&
        _activePosition == (selection?.position ?? Offset.zero)) {
      return;
    }
    setState(() {
      _activeDataIndex = selection?.dataIndex;
      _activePosition = selection?.position ?? Offset.zero;
    });
  }

  _PictogramSelection? _hitTest(Offset position, Size size) {
    final layout = _PictogramLayout.resolve(
      size: size,
      padding: widget.padding,
      showLegend: widget.showLegend,
    );
    final geometry = _PictogramGeometry.resolve(
      layout: layout,
      allocation: widget.allocation,
      rows: widget.rows,
      columns: widget.columns,
      fillDirection: widget.fillDirection,
      unitGap: widget.unitGap,
    );
    for (final unit in geometry.units) {
      if (unit.dataIndex == null) continue;
      if (unit.rect.inflate(math.max(2, widget.unitGap)).contains(position)) {
        return _PictogramSelection(unit.dataIndex!, unit.rect.center);
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int dataIndex) {
    final item = widget.data[dataIndex];
    final share = item.value / widget.total;
    final unitCount = widget.allocation.countFor(dataIndex);
    final formattedValue = widget.valueFormatter(item.value);
    final formattedShare = widget.percentFormatter(share);
    const tooltipWidth = 174.0;
    const tooltipHeight = 76.0;
    final left = (_activePosition.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (_activePosition.dy - tooltipHeight - 8)
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
            dataIndex,
            formattedValue,
            formattedShare,
            unitCount,
          ) ??
          _DefaultPictogramTooltip(
            color: _unitColor(item, dataIndex),
            title: item.label,
            rows: [
              _PictogramTooltipRow(label: 'Value', value: formattedValue),
              _PictogramTooltipRow(label: 'Share', value: formattedShare),
              _PictogramTooltipRow(label: 'Units', value: unitCount.toString()),
            ],
          ),
    );
  }

  Color _unitColor(SimplePictogramChartData item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimplePictogramPainter extends CustomPainter {
  final List<SimplePictogramChartData> data;
  final double total;
  final _PictogramAllocation allocation;
  final int rows;
  final int columns;
  final EdgeInsets padding;
  final SimplePictogramSymbol symbol;
  final SimplePictogramFillDirection fillDirection;
  final List<Color> palette;
  final Color emptyColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLegend;
  final bool showValues;
  final bool showActiveUnits;
  final bool showEmptyUnits;
  final double unitGap;
  final double symbolScale;
  final int? activeDataIndex;
  final SimplePictogramValueFormatter valueFormatter;
  final SimplePictogramValueFormatter percentFormatter;
  final double progress;

  const _SimplePictogramPainter({
    required this.data,
    required this.total,
    required this.allocation,
    required this.rows,
    required this.columns,
    required this.padding,
    required this.symbol,
    required this.fillDirection,
    required this.palette,
    required this.emptyColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLegend,
    required this.showValues,
    required this.showActiveUnits,
    required this.showEmptyUnits,
    required this.unitGap,
    required this.symbolScale,
    required this.activeDataIndex,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _PictogramLayout.resolve(
      size: size,
      padding: padding,
      showLegend: showLegend,
    );
    final geometry = _PictogramGeometry.resolve(
      layout: layout,
      allocation: allocation,
      rows: rows,
      columns: columns,
      fillDirection: fillDirection,
      unitGap: unitGap,
    );
    if (geometry.units.isEmpty) return;

    final animatedFilledCount = (allocation.assignedUnitCount * progress)
        .ceil();
    var filledSeen = 0;
    for (final unit in geometry.units) {
      final dataIndex = unit.dataIndex;
      if (dataIndex == null) {
        if (showEmptyUnits) _drawSymbol(canvas, unit.rect, emptyColor, false);
        continue;
      }

      filledSeen += 1;
      if (filledSeen > animatedFilledCount) {
        if (showEmptyUnits) _drawSymbol(canvas, unit.rect, emptyColor, false);
        continue;
      }

      final item = data[dataIndex];
      final color = item.color ?? palette[dataIndex % palette.length];
      _drawSymbol(canvas, unit.rect, color, activeDataIndex == dataIndex);
    }

    if (showLegend) _drawLegend(canvas, layout.legendRect);
  }

  void _drawSymbol(Canvas canvas, Rect unitRect, Color color, bool active) {
    final size = unitRect.shortestSide * symbolScale;
    final rect = Rect.fromCenter(
      center: unitRect.center,
      width: size,
      height: size,
    );
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (symbol) {
      case SimplePictogramSymbol.person:
        _drawPerson(canvas, rect, paint);
      case SimplePictogramSymbol.circle:
        canvas.drawCircle(rect.center, rect.shortestSide / 2, paint);
      case SimplePictogramSymbol.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(math.min(5, rect.shortestSide / 4)),
          ),
          paint,
        );
      case SimplePictogramSymbol.star:
        canvas.drawPath(_starPath(rect), paint);
      case SimplePictogramSymbol.check:
        canvas.drawPath(
          _checkPath(rect),
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.0, rect.shortestSide * 0.16),
        );
    }

    if (!showActiveUnits || !active) return;
    final highlight = activeColor ?? color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        unitRect.inflate(1.8),
        Radius.circular(math.min(8, unitRect.shortestSide / 3)),
      ),
      Paint()
        ..color = highlight.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawPerson(Canvas canvas, Rect rect, Paint paint) {
    final headRadius = rect.width * 0.18;
    canvas.drawCircle(
      Offset(rect.center.dx, rect.top + rect.height * 0.2),
      headRadius,
      paint,
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.top + rect.height * 0.58),
        width: rect.width * 0.45,
        height: rect.height * 0.48,
      ),
      Radius.circular(rect.width * 0.16),
    );
    canvas.drawRRect(body, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + rect.width * 0.18,
          rect.top + rect.height * 0.42,
          rect.width * 0.16,
          rect.height * 0.36,
        ),
        Radius.circular(rect.width * 0.08),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.right - rect.width * 0.34,
          rect.top + rect.height * 0.42,
          rect.width * 0.16,
          rect.height * 0.36,
        ),
        Radius.circular(rect.width * 0.08),
      ),
      paint,
    );
  }

  Path _starPath(Rect rect) {
    final path = Path();
    final center = rect.center;
    final outer = rect.shortestSide / 2;
    final inner = outer * 0.44;
    for (var index = 0; index < 10; index++) {
      final radius = index.isEven ? outer : inner;
      final angle = -math.pi / 2 + index * math.pi / 5;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Path _checkPath(Rect rect) {
    return Path()
      ..moveTo(rect.left + rect.width * 0.18, rect.top + rect.height * 0.54)
      ..lineTo(rect.left + rect.width * 0.42, rect.top + rect.height * 0.76)
      ..lineTo(rect.left + rect.width * 0.82, rect.top + rect.height * 0.26);
  }

  void _drawLegend(Canvas canvas, Rect rect) {
    if (rect.width <= 0 || rect.height <= 0) return;
    final rowHeight = math.max(22.0, math.min(30.0, rect.height / data.length));
    for (var index = 0; index < data.length; index++) {
      final item = data[index];
      final y = rect.top + index * rowHeight;
      if (y > rect.bottom - 10) break;
      final color = item.color ?? palette[index % palette.length];
      _drawSymbol(
        canvas,
        Rect.fromLTWH(rect.left, y + 4, 13, 13),
        color,
        false,
      );

      final share = total <= 0 ? 0.0 : item.value / total;
      final text = showValues
          ? '${item.label}  ${percentFormatter(share)}'
          : item.label;
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: index == activeDataIndex
              ? valueStyle.copyWith(color: valueStyle.color)
              : labelStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: math.max(0.0, rect.width - 18));
      painter.paint(canvas, Offset(rect.left + 18, y + 1));
    }
  }

  @override
  bool shouldRepaint(covariant _SimplePictogramPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.total != total ||
        oldDelegate.allocation != allocation ||
        oldDelegate.rows != rows ||
        oldDelegate.columns != columns ||
        oldDelegate.padding != padding ||
        oldDelegate.symbol != symbol ||
        oldDelegate.fillDirection != fillDirection ||
        oldDelegate.palette != palette ||
        oldDelegate.emptyColor != emptyColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showActiveUnits != showActiveUnits ||
        oldDelegate.showEmptyUnits != showEmptyUnits ||
        oldDelegate.unitGap != unitGap ||
        oldDelegate.symbolScale != symbolScale ||
        oldDelegate.activeDataIndex != activeDataIndex ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.percentFormatter != percentFormatter ||
        oldDelegate.progress != progress;
  }
}

class _PictogramAllocation {
  final List<int?> units;
  final List<int> counts;

  const _PictogramAllocation({required this.units, required this.counts});

  int get assignedUnitCount => units.whereType<int>().length;

  int countFor(int dataIndex) {
    if (dataIndex < 0 || dataIndex >= counts.length) return 0;
    return counts[dataIndex];
  }

  factory _PictogramAllocation.resolve({
    required List<SimplePictogramChartData> data,
    required double total,
    required int totalUnits,
  }) {
    final raw = data
        .map((item) => total <= 0 ? 0.0 : item.value / total * totalUnits)
        .toList();
    final counts = raw.map((value) => value.floor()).toList();
    var assigned = counts.fold<int>(0, (current, value) => current + value);
    var remaining = math.max(0, totalUnits - assigned);

    final remainders = List<int>.generate(data.length, (index) => index)
      ..sort((a, b) {
        final byRemainder = (raw[b] - raw[b].floor()).compareTo(
          raw[a] - raw[a].floor(),
        );
        if (byRemainder != 0) return byRemainder;
        return data[b].value.compareTo(data[a].value);
      });
    for (final index in remainders) {
      if (remaining <= 0) break;
      if (data[index].value <= 0) continue;
      counts[index] += 1;
      remaining -= 1;
    }

    assigned = counts.fold<int>(0, (current, value) => current + value);
    if (assigned > totalUnits) {
      for (var index = counts.length - 1; index >= 0; index--) {
        while (assigned > totalUnits && counts[index] > 0) {
          counts[index] -= 1;
          assigned -= 1;
        }
      }
    }

    final units = <int?>[];
    for (var index = 0; index < counts.length; index++) {
      units.addAll(List<int?>.filled(counts[index], index));
    }
    while (units.length < totalUnits) {
      units.add(null);
    }
    if (units.length > totalUnits) {
      units.removeRange(totalUnits, units.length);
    }
    return _PictogramAllocation(units: units, counts: counts);
  }
}

class _PictogramLayout {
  final Rect gridRect;
  final Rect legendRect;

  const _PictogramLayout({required this.gridRect, required this.legendRect});

  factory _PictogramLayout.resolve({
    required Size size,
    required EdgeInsets padding,
    required bool showLegend,
  }) {
    final content = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (!showLegend) {
      return _PictogramLayout(gridRect: content, legendRect: Rect.zero);
    }

    final compact = content.width < 420;
    if (compact) {
      final legendHeight = math.min(64.0, content.height * 0.28);
      final gridArea = Rect.fromLTRB(
        content.left,
        content.top,
        content.right,
        math.max(content.top, content.bottom - legendHeight - 12),
      );
      return _PictogramLayout(
        gridRect: gridArea,
        legendRect: Rect.fromLTRB(
          content.left,
          gridArea.bottom + 12,
          content.right,
          content.bottom,
        ),
      );
    }

    final legendWidth = math.min(168.0, content.width * 0.36);
    return _PictogramLayout(
      gridRect: Rect.fromLTRB(
        content.left,
        content.top,
        math.max(content.left, content.right - legendWidth - 16),
        content.bottom,
      ),
      legendRect: Rect.fromLTRB(
        content.right - legendWidth,
        content.top,
        content.right,
        content.bottom,
      ),
    );
  }
}

class _PictogramGeometry {
  final List<_PictogramUnit> units;

  const _PictogramGeometry({required this.units});

  factory _PictogramGeometry.resolve({
    required _PictogramLayout layout,
    required _PictogramAllocation allocation,
    required int rows,
    required int columns,
    required SimplePictogramFillDirection fillDirection,
    required double unitGap,
  }) {
    final totalGapX = unitGap * math.max(0, columns - 1);
    final totalGapY = unitGap * math.max(0, rows - 1);
    final unitSize = math.max(
      0.0,
      math.min(
        (layout.gridRect.width - totalGapX) / columns,
        (layout.gridRect.height - totalGapY) / rows,
      ),
    );
    if (unitSize <= 0) return const _PictogramGeometry(units: []);

    final actualWidth = unitSize * columns + totalGapX;
    final actualHeight = unitSize * rows + totalGapY;
    final left =
        layout.gridRect.left + (layout.gridRect.width - actualWidth) / 2;
    final top =
        layout.gridRect.top + (layout.gridRect.height - actualHeight) / 2;
    final units = <_PictogramUnit>[];

    for (var index = 0; index < rows * columns; index++) {
      final gridPosition = _positionFor(index, rows, columns, fillDirection);
      final rect = Rect.fromLTWH(
        left + gridPosition.column * (unitSize + unitGap),
        top + gridPosition.row * (unitSize + unitGap),
        unitSize,
        unitSize,
      );
      units.add(
        _PictogramUnit(
          rect: rect,
          dataIndex: index < allocation.units.length
              ? allocation.units[index]
              : null,
        ),
      );
    }
    return _PictogramGeometry(units: units);
  }

  static _PictogramGridPosition _positionFor(
    int index,
    int rows,
    int columns,
    SimplePictogramFillDirection direction,
  ) {
    final row = index ~/ columns;
    final column = index % columns;
    switch (direction) {
      case SimplePictogramFillDirection.leftToRight:
        return _PictogramGridPosition(row, column);
      case SimplePictogramFillDirection.rightToLeft:
        return _PictogramGridPosition(row, columns - 1 - column);
      case SimplePictogramFillDirection.bottomToTop:
        return _PictogramGridPosition(rows - 1 - row, column);
    }
  }
}

class _PictogramUnit {
  final Rect rect;
  final int? dataIndex;

  const _PictogramUnit({required this.rect, required this.dataIndex});
}

class _PictogramGridPosition {
  final int row;
  final int column;

  const _PictogramGridPosition(this.row, this.column);
}

class _PictogramSelection {
  final int dataIndex;
  final Offset position;

  const _PictogramSelection(this.dataIndex, this.position);
}

class _SimplePictogramVisuals {
  final List<Color> palette;
  final Color emptyColor;

  const _SimplePictogramVisuals({
    required this.palette,
    required this.emptyColor,
  });

  factory _SimplePictogramVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimplePictogramVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFFF97316),
          ],
          emptyColor: colorScheme.primary.withValues(alpha: 0.1),
        );
      case SimpleBarChartStyle.professional:
        return _SimplePictogramVisuals(
          palette: [
            colorScheme.primary,
            const Color(0xFF475569),
            const Color(0xFF0F766E),
            const Color(0xFF1D4ED8),
            const Color(0xFF64748B),
          ],
          emptyColor: colorScheme.outline.withValues(alpha: 0.12),
        );
      case SimpleBarChartStyle.education:
        return _SimplePictogramVisuals(
          palette: [
            colorScheme.secondary,
            const Color(0xFF3B82F6),
            const Color(0xFFF59E0B),
            const Color(0xFF10B981),
            const Color(0xFF8B5CF6),
          ],
          emptyColor: colorScheme.secondary.withValues(alpha: 0.1),
        );
      case SimpleBarChartStyle.trendy:
        return _SimplePictogramVisuals(
          palette: [
            colorScheme.tertiary,
            const Color(0xFF06B6D4),
            const Color(0xFF22C55E),
            const Color(0xFFEC4899),
            const Color(0xFFF97316),
          ],
          emptyColor: colorScheme.tertiary.withValues(alpha: 0.1),
        );
      case SimpleBarChartStyle.elegant:
        return _SimplePictogramVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFFF59E0B),
          ],
          emptyColor: colorScheme.primary.withValues(alpha: 0.09),
        );
    }
  }
}

class _DefaultPictogramTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final List<_PictogramTooltipRow> rows;

  const _DefaultPictogramTooltip({
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
                    shape: BoxShape.circle,
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
                            alpha: 0.72,
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

class _PictogramTooltipRow {
  final String label;
  final String value;

  const _PictogramTooltipRow({required this.label, required this.value});
}
