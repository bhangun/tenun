import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_api_options.dart';
import 'package:tenun_core/core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleCalendarHeatmapValueFormatter = String Function(double value);
typedef SimpleCalendarHeatmapDateFormatter = String Function(DateTime date);
typedef SimpleCalendarHeatmapTapCallback =
    void Function(
      SimpleCalendarHeatmapData? data,
      DateTime date,
      double? value,
    );
typedef SimpleCalendarHeatmapTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleCalendarHeatmapData? data,
      DateTime date,
      String formattedDate,
      String formattedValue,
    );

class SimpleCalendarHeatmapData {
  final DateTime date;
  final double value;
  final String? label;
  final Color? color;

  const SimpleCalendarHeatmapData({
    required this.date,
    required this.value,
    this.label,
    this.color,
  });
}

/// A compact calendar heatmap for daily activity, volume, habits, and load.
class SimpleCalendarHeatmapChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(34, 20, 16, 42);

  final List<SimpleCalendarHeatmapData> data;
  final SimpleBarChartStyle style;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minValue;
  final double? maxValue;
  final double height;
  final EdgeInsets padding;
  final Color? lowColor;
  final Color? highColor;
  final Color? emptyColor;
  final Color? gridColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool startWeekOnMonday;
  final bool showMonthLabels;
  final bool showWeekdayLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveDay;
  final double cellGap;
  final double cellRadius;
  final SimpleCalendarHeatmapValueFormatter? valueFormatter;
  final SimpleCalendarHeatmapDateFormatter? dateFormatter;
  final SimpleCalendarHeatmapTapCallback? onDayTap;
  final SimpleCalendarHeatmapTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleCalendarHeatmapChart({
    super.key,
    required this.data,
    this.style = SimpleBarChartStyle.elegant,
    this.startDate,
    this.endDate,
    this.minValue,
    this.maxValue,
    this.height = 240,
    this.padding = _defaultPadding,
    this.lowColor,
    this.highColor,
    this.emptyColor,
    this.gridColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.startWeekOnMonday = true,
    this.showMonthLabels = true,
    this.showWeekdayLabels = true,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveDay = true,
    this.cellGap = 3,
    this.cellRadius = 4,
    this.valueFormatter,
    this.dateFormatter,
    this.onDayTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 680),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(cellGap >= 0),
       assert(cellRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleCalendarHeatmapVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.value.isFinite)
        .map(
          (item) => SimpleCalendarHeatmapData(
            date: _dateOnly(item.date),
            value: item.value,
            label: item.label,
            color: item.color,
          ),
        )
        .toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedDateFormatter = dateFormatter ?? _defaultDateFormatter;

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
            emptySemanticLabel: 'Calendar heatmap, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedRange = _CalendarRange.resolve(
          data: visibleData,
          startDate: startDate,
          endDate: endDate,
        );
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
              fontSize: 10,
              fontWeight: FontWeight.w700,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleData,
            resolvedRange,
            formatter,
            resolvedDateFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleCalendarHeatmapChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            range: resolvedRange,
            minValue: minValue,
            maxValue: maxValue,
            padding: padding,
            lowColor: lowColor ?? visuals.lowColor,
            highColor: highColor ?? visuals.highColor,
            emptyColor: emptyColor ?? visuals.emptyColor,
            gridColor: gridColor ?? visuals.gridColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            startWeekOnMonday: startWeekOnMonday,
            showMonthLabels: showMonthLabels,
            showWeekdayLabels: showWeekdayLabels,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveDay: showActiveDay,
            cellGap: cellGap,
            cellRadius: cellRadius,
            valueFormatter: formatter,
            dateFormatter: resolvedDateFormatter,
            onDayTap: onDayTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static String _defaultSemanticLabel(
    List<SimpleCalendarHeatmapData> data,
    _CalendarRange range,
    SimpleCalendarHeatmapValueFormatter formatter,
    SimpleCalendarHeatmapDateFormatter dateFormatter,
  ) {
    final sorted = [...data]..sort((a, b) => a.date.compareTo(b.date));
    final sample = sorted
        .take(5)
        .map((item) {
          return '${dateFormatter(item.date)} ${formatter(item.value)}';
        })
        .join(', ');
    final suffix = sorted.length > 5 ? ', and ${sorted.length - 5} more' : '';
    return 'Calendar heatmap, ${sorted.length} days from '
        '${dateFormatter(range.start)} to ${dateFormatter(range.end)}. '
        '$sample$suffix.';
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _defaultValueFormatter(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultDateFormatter(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _SimpleCalendarHeatmapChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleCalendarHeatmapData> data;
  final _CalendarRange range;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool startWeekOnMonday;
  final bool showMonthLabels;
  final bool showWeekdayLabels;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveDay;
  final double cellGap;
  final double cellRadius;
  final SimpleCalendarHeatmapValueFormatter valueFormatter;
  final SimpleCalendarHeatmapDateFormatter dateFormatter;
  final SimpleCalendarHeatmapTapCallback? onDayTap;
  final SimpleCalendarHeatmapTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleCalendarHeatmapChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.range,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.startWeekOnMonday,
    required this.showMonthLabels,
    required this.showWeekdayLabels,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveDay,
    required this.cellGap,
    required this.cellRadius,
    required this.valueFormatter,
    required this.dateFormatter,
    required this.onDayTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleCalendarHeatmapChartView> createState() =>
      _SimpleCalendarHeatmapChartViewState();
}

class _SimpleCalendarHeatmapChartViewState
    extends State<_SimpleCalendarHeatmapChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _CalendarDayCell? _activeCell;

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
  void didUpdateWidget(covariant _SimpleCalendarHeatmapChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.range != widget.range ||
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
                    if (widget.showActiveDay ||
                        widget.showTooltip ||
                        widget.onDayTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final cell = _hitTest(details.localPosition);
                      _setActive(cell);
                      if (cell != null) {
                        widget.onDayTap?.call(
                          cell.data,
                          cell.date,
                          cell.data?.value,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleCalendarHeatmapPainter(
                        data: widget.data,
                        range: widget.range,
                        minValue: widget.minValue,
                        maxValue: widget.maxValue,
                        padding: widget.padding,
                        lowColor: widget.lowColor,
                        highColor: widget.highColor,
                        emptyColor: widget.emptyColor,
                        gridColor: widget.gridColor,
                        activeColor: widget.activeColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        startWeekOnMonday: widget.startWeekOnMonday,
                        showMonthLabels: widget.showMonthLabels,
                        showWeekdayLabels: widget.showWeekdayLabels,
                        showValues: widget.showValues,
                        showLegend: widget.showLegend,
                        cellGap: widget.cellGap,
                        cellRadius: widget.cellRadius,
                        valueFormatter: widget.valueFormatter,
                        activeDate: widget.showActiveDay
                            ? _activeCell?.date
                            : null,
                        progress: _animation.value,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeCell != null)
                _buildTooltip(context, _activeCell!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_CalendarDayCell? cell) {
    if (_sameDate(_activeCell?.date, cell?.date)) {
      return;
    }
    setState(() => _activeCell = cell);
  }

  _CalendarDayCell? _hitTest(Offset position) {
    final geometry = _CalendarHeatmapGeometry.resolve(
      data: widget.data,
      range: widget.range,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
      minValue: widget.minValue,
      maxValue: widget.maxValue,
      startWeekOnMonday: widget.startWeekOnMonday,
      showMonthLabels: widget.showMonthLabels,
      showWeekdayLabels: widget.showWeekdayLabels,
      showLegend: widget.showLegend,
      cellGap: widget.cellGap,
    );
    for (final cell in geometry.cells) {
      if (cell.rect.inflate(3).contains(position)) {
        return cell;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, _CalendarDayCell cell) {
    final formattedDate = widget.dateFormatter(cell.date);
    final formattedValue = cell.data == null
        ? 'No data'
        : widget.valueFormatter(cell.data!.value);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          cell.data,
          cell.date,
          formattedDate,
          formattedValue,
        ) ??
        _DefaultCalendarHeatmapTooltip(
          title: cell.data?.label ?? formattedDate,
          rows: [
            _TooltipRow('Date', formattedDate),
            _TooltipRow('Value', formattedValue),
          ],
        );
    final left = (cell.rect.right + 10).clamp(8.0, widget.width - 176);
    final top = (cell.rect.center.dy - 46).clamp(8.0, widget.height - 94);

    return Positioned(left: left, top: top, child: tooltip);
  }

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _SimpleCalendarHeatmapPainter extends CustomPainter {
  final List<SimpleCalendarHeatmapData> data;
  final _CalendarRange range;
  final double? minValue;
  final double? maxValue;
  final EdgeInsets padding;
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;
  final Color activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool startWeekOnMonday;
  final bool showMonthLabels;
  final bool showWeekdayLabels;
  final bool showValues;
  final bool showLegend;
  final double cellGap;
  final double cellRadius;
  final SimpleCalendarHeatmapValueFormatter valueFormatter;
  final DateTime? activeDate;
  final double progress;

  const _SimpleCalendarHeatmapPainter({
    required this.data,
    required this.range,
    required this.minValue,
    required this.maxValue,
    required this.padding,
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.gridColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.startWeekOnMonday,
    required this.showMonthLabels,
    required this.showWeekdayLabels,
    required this.showValues,
    required this.showLegend,
    required this.cellGap,
    required this.cellRadius,
    required this.valueFormatter,
    required this.activeDate,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _CalendarHeatmapGeometry.resolve(
      data: data,
      range: range,
      size: size,
      padding: padding,
      minValue: minValue,
      maxValue: maxValue,
      startWeekOnMonday: startWeekOnMonday,
      showMonthLabels: showMonthLabels,
      showWeekdayLabels: showWeekdayLabels,
      showLegend: showLegend,
      cellGap: cellGap,
    );
    if (geometry.cells.isEmpty || geometry.cellSize <= 0) {
      return;
    }

    _drawLabels(canvas, geometry);
    _drawCells(canvas, geometry);
    if (showLegend) {
      _drawLegend(canvas, geometry);
    }
  }

  void _drawLabels(Canvas canvas, _CalendarHeatmapGeometry geometry) {
    if (showMonthLabels) {
      var previousMonth = -1;
      for (final cell in geometry.cells) {
        if (cell.date.month != previousMonth) {
          previousMonth = cell.date.month;
          _drawText(
            canvas,
            _monthLabel(cell.date.month),
            Rect.fromLTWH(
              cell.rect.left,
              geometry.grid.top - 18,
              math.max(32, geometry.cellSize * 3),
              14,
            ),
            labelStyle,
          );
        }
      }
    }

    if (showWeekdayLabels) {
      final labels = startWeekOnMonday
          ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      for (var row = 0; row < labels.length; row++) {
        if (row.isOdd && geometry.cellSize < 12) {
          continue;
        }
        final y = geometry.grid.top + row * (geometry.cellSize + cellGap) - 1;
        _drawText(
          canvas,
          labels[row],
          Rect.fromLTWH(
            padding.left,
            y,
            math.max(0, geometry.grid.left - padding.left - 6),
            geometry.cellSize + 2,
          ),
          labelStyle,
          align: TextAlign.right,
        );
      }
    }
  }

  void _drawCells(Canvas canvas, _CalendarHeatmapGeometry geometry) {
    final borderPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    for (final cell in geometry.cells) {
      final data = cell.data;
      final color = data?.color ?? _colorFor(cell.value, geometry);
      final fill = data == null
          ? emptyColor
          : color.withValues(alpha: 0.2 + progress * 0.8);
      final rect = cell.rect;
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(math.min(cellRadius, rect.shortestSide / 2)),
      );
      final paint = Paint()
        ..color = fill
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rrect, paint);
      canvas.drawRRect(rrect, borderPaint);

      if (_sameDate(activeDate, cell.date)) {
        canvas.drawRRect(rrect.inflate(2), activePaint);
      }

      if (showValues && data != null && rect.shortestSide >= 18) {
        _drawText(
          canvas,
          valueFormatter(data.value),
          rect.deflate(1),
          valueStyle,
          align: TextAlign.center,
        );
      }
    }
  }

  void _drawLegend(Canvas canvas, _CalendarHeatmapGeometry geometry) {
    const steps = 5;
    final cell = math.min(14.0, math.max(8.0, geometry.cellSize));
    final y = math.min(
      geometry.size.height - padding.bottom + 18,
      geometry.size.height - cell - 6,
    );
    final totalWidth = steps * cell + (steps - 1) * 4 + 74;
    final startX = math.max(padding.left, geometry.grid.right - totalWidth);

    _drawText(
      canvas,
      'Less',
      Rect.fromLTWH(startX, y - 1, 32, cell + 2),
      labelStyle,
      align: TextAlign.right,
    );
    var x = startX + 38;
    for (var i = 0; i < steps; i++) {
      final t = i / (steps - 1);
      final color = Color.lerp(lowColor, highColor, t)!;
      final rect = Rect.fromLTWH(x, y, cell, cell);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cellRadius)),
        Paint()..color = color,
      );
      x += cell + 4;
    }
    _drawText(
      canvas,
      'More',
      Rect.fromLTWH(x + 2, y - 1, 36, cell + 2),
      labelStyle,
    );
  }

  Color _colorFor(double? value, _CalendarHeatmapGeometry geometry) {
    if (value == null) {
      return emptyColor;
    }
    final span = geometry.maxValue - geometry.minValue;
    final t = span <= 0
        ? 1.0
        : ((value - geometry.minValue) / span).clamp(0.0, 1.0);
    return Color.lerp(lowColor, highColor, t)!;
  }

  String _monthLabel(int month) {
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return labels[month - 1];
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

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  bool shouldRepaint(covariant _SimpleCalendarHeatmapPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.range != range ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.padding != padding ||
        oldDelegate.lowColor != lowColor ||
        oldDelegate.highColor != highColor ||
        oldDelegate.emptyColor != emptyColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.startWeekOnMonday != startWeekOnMonday ||
        oldDelegate.showMonthLabels != showMonthLabels ||
        oldDelegate.showWeekdayLabels != showWeekdayLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.cellGap != cellGap ||
        oldDelegate.cellRadius != cellRadius ||
        oldDelegate.activeDate != activeDate ||
        oldDelegate.progress != progress;
  }
}

class _CalendarHeatmapGeometry {
  final Size size;
  final Rect grid;
  final double cellSize;
  final double minValue;
  final double maxValue;
  final List<_CalendarDayCell> cells;

  const _CalendarHeatmapGeometry({
    required this.size,
    required this.grid,
    required this.cellSize,
    required this.minValue,
    required this.maxValue,
    required this.cells,
  });

  factory _CalendarHeatmapGeometry.resolve({
    required List<SimpleCalendarHeatmapData> data,
    required _CalendarRange range,
    required Size size,
    required EdgeInsets padding,
    required double? minValue,
    required double? maxValue,
    required bool startWeekOnMonday,
    required bool showMonthLabels,
    required bool showWeekdayLabels,
    required bool showLegend,
    required double cellGap,
  }) {
    final dataByDay = <int, SimpleCalendarHeatmapData>{};
    for (final item in data) {
      dataByDay[_dayKey(item.date)] = item;
    }
    final values = data.map((item) => item.value).toList();
    final dataMin = values.fold<double>(
      values.first,
      (value, next) => math.min(value, next),
    );
    final dataMax = values.fold<double>(
      values.first,
      (value, next) => math.max(value, next),
    );
    final resolvedMin = minValue ?? math.min(0, dataMin);
    final resolvedMax = math.max(maxValue ?? dataMax, resolvedMin + 1);

    final startOffset = _weekdayIndex(range.start, startWeekOnMonday);
    final dayCount = range.end.difference(range.start).inDays + 1;
    final weekCount = math.max(1, ((startOffset + dayCount) / 7).ceil());
    final monthLabelHeight = showMonthLabels ? 18.0 : 0.0;
    final weekdayLabelWidth = showWeekdayLabels ? 30.0 : 0.0;
    final legendHeight = showLegend ? 24.0 : 0.0;
    final area = Rect.fromLTRB(
      padding.left + weekdayLabelWidth,
      padding.top + monthLabelHeight,
      math.max(padding.left + weekdayLabelWidth, size.width - padding.right),
      math.max(
        padding.top + monthLabelHeight,
        size.height - padding.bottom - legendHeight,
      ),
    );
    final cellWidth =
        (area.width - cellGap * math.max(0, weekCount - 1)) / weekCount;
    final cellHeight = (area.height - cellGap * 6) / 7;
    final cellSize = math.max(0.0, math.min(cellWidth, cellHeight));
    final gridWidth =
        weekCount * cellSize + math.max(0, weekCount - 1) * cellGap;
    final gridHeight = 7 * cellSize + 6 * cellGap;
    final grid = Rect.fromLTWH(
      area.left + math.max(0, area.width - gridWidth) / 2,
      area.top + math.max(0, area.height - gridHeight) / 2,
      gridWidth,
      gridHeight,
    );

    final cells = <_CalendarDayCell>[];
    for (var offset = 0; offset < dayCount; offset++) {
      final date = range.start.add(Duration(days: offset));
      final slot = startOffset + offset;
      final column = slot ~/ 7;
      final row = slot % 7;
      final rect = Rect.fromLTWH(
        grid.left + column * (cellSize + cellGap),
        grid.top + row * (cellSize + cellGap),
        cellSize,
        cellSize,
      );
      final item = dataByDay[_dayKey(date)];
      cells.add(
        _CalendarDayCell(
          date: date,
          data: item,
          value: item?.value,
          rect: rect,
          row: row,
          column: column,
        ),
      );
    }

    return _CalendarHeatmapGeometry(
      size: size,
      grid: grid,
      cellSize: cellSize,
      minValue: resolvedMin.toDouble(),
      maxValue: resolvedMax.toDouble(),
      cells: cells,
    );
  }

  static int _weekdayIndex(DateTime date, bool startWeekOnMonday) {
    if (startWeekOnMonday) {
      return date.weekday - 1;
    }
    return date.weekday % 7;
  }

  static int _dayKey(DateTime date) {
    return DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
  }
}

class _CalendarDayCell {
  final DateTime date;
  final SimpleCalendarHeatmapData? data;
  final double? value;
  final Rect rect;
  final int row;
  final int column;

  const _CalendarDayCell({
    required this.date,
    required this.data,
    required this.value,
    required this.rect,
    required this.row,
    required this.column,
  });
}

class _CalendarRange {
  final DateTime start;
  final DateTime end;

  const _CalendarRange({required this.start, required this.end});

  factory _CalendarRange.resolve({
    required List<SimpleCalendarHeatmapData> data,
    required DateTime? startDate,
    required DateTime? endDate,
  }) {
    final sorted = [...data]..sort((a, b) => a.date.compareTo(b.date));
    final first = sorted.first.date;
    final last = sorted.last.date;
    var start = startDate == null
        ? DateTime(first.year, 1, 1)
        : SimpleCalendarHeatmapChart._dateOnly(startDate);
    var end = endDate == null
        ? DateTime(last.year, 12, 31)
        : SimpleCalendarHeatmapChart._dateOnly(endDate);
    if (end.isBefore(start)) {
      final previousStart = start;
      start = end;
      end = previousStart;
    }
    return _CalendarRange(start: start, end: end);
  }

  @override
  bool operator ==(Object other) {
    return other is _CalendarRange && other.start == start && other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

class _SimpleCalendarHeatmapVisuals {
  final Color lowColor;
  final Color highColor;
  final Color emptyColor;
  final Color gridColor;
  final Color activeColor;

  const _SimpleCalendarHeatmapVisuals({
    required this.lowColor,
    required this.highColor,
    required this.emptyColor,
    required this.gridColor,
    required this.activeColor,
  });

  factory _SimpleCalendarHeatmapVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleCalendarHeatmapVisuals(
          lowColor: colorScheme.primary.withValues(alpha: 0.18),
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.46,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.12),
          activeColor: colorScheme.tertiary,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleCalendarHeatmapVisuals(
          lowColor: colorScheme.primary.withValues(alpha: 0.2),
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.22),
          activeColor: colorScheme.onSurface,
        );
      case SimpleBarChartStyle.education:
        return _SimpleCalendarHeatmapVisuals(
          lowColor: colorScheme.secondary.withValues(alpha: 0.18),
          highColor: colorScheme.secondary,
          emptyColor: colorScheme.secondaryContainer.withValues(alpha: 0.26),
          gridColor: colorScheme.outline.withValues(alpha: 0.18),
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleCalendarHeatmapVisuals(
          lowColor: colorScheme.tertiary.withValues(alpha: 0.18),
          highColor: colorScheme.tertiary,
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.1),
          activeColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleCalendarHeatmapVisuals(
          lowColor: colorScheme.primary.withValues(alpha: 0.16),
          highColor: colorScheme.primary,
          emptyColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.42,
          ),
          gridColor: colorScheme.outline.withValues(alpha: 0.16),
          activeColor: colorScheme.tertiary,
        );
    }
  }
}

class _DefaultCalendarHeatmapTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultCalendarHeatmapTooltip({
    required this.title,
    required this.rows,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: DefaultTextStyle(
          style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final row in rows)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 50, child: Text(row.label)),
                    Text(
                      row.value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

class _TooltipRow {
  final String label;
  final String value;

  const _TooltipRow(this.label, this.value);
}
