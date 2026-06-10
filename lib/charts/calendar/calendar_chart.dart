// ═══════════════════════════════════════════════════════════
// 2. CALENDAR HEATMAP
// ═══════════════════════════════════════════════════════════

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_color_value.dart';
import '../../core/chart_data_signature.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_series_json.dart';
import '../../core/chart_theme.dart';
import '../../core/base_config.dart';
import '../../core/chart_model.dart';
import '../../core/chart_type.dart';
import '../../core/grid.dart';
import '../../core/json_value.dart';
import '../../core/legend.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';

String _colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

/// GitHub-style activity calendar.
/// JSON:
/// ```json
/// { "type": "calendar", "year": 2024,
///   "series": [{ "data": [
///     { "date": "2024-01-15", "value": 4 },
///     { "date": "2024-03-22", "value": 7 }
///   ]}]}
/// ```
class CalendarChartConfig extends BaseChartConfig {
  final int year;
  final Map<String, double> dateValues; // "yyyy-MM-dd" -> value
  final Color emptyColor;
  final Color maxColor;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  CalendarChartConfig({
    required this.year,
    required this.dateValues,
    this.theme = ChartTheme.light,
    this.emptyColor = const Color(0xFFEEEEEE),
    this.maxColor = const Color(0xFF1B5E20),
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.calendar, series: const []);

  @override
  Widget buildChart() => CalendarChartWidget(config: this);

  factory CalendarChartConfig.fromJson(Map<String, dynamic> json) {
    final Map<String, double> dv = {};
    for (final item in ChartSeriesJson.firstSeriesData(json['series'])) {
      dv[item['date'].toString()] = JsonValue.doubleOrNull(item['value']) ?? 0;
    }

    return CalendarChartConfig(
      year: JsonValue.intOrNull(json['year']) ?? DateTime.now().year,
      dateValues: dv,
      emptyColor: ChartColorValue.colorOrFallback(
        json['emptyColor'],
        const Color(0xFFEEEEEE),
      ),
      maxColor: ChartColorValue.colorOrFallback(
        json['maxColor'],
        const Color(0xFF1B5E20),
      ),
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      tooltip: json['tooltip'] != null
          ? ChartTooltip.fromJson(json['tooltip'])
          : null,
      legend: json['legend'] != null
          ? ChartLegend.fromJson(json['legend'])
          : null,
      toolbox: json['toolbox'] != null
          ? ChartToolbox.fromJson(json['toolbox'])
          : null,
      grid: json['grid'] != null ? GridData.fromJson(json['grid']) : null,
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'year': year,
    'series': [
      {
        'data': [
          for (final entry in dateValues.entries)
            {'date': entry.key, 'value': entry.value},
        ],
      },
    ],
    'emptyColor': _colorToHex(emptyColor),
    'maxColor': _colorToHex(maxColor),
  };
}

class CalendarChartWidget extends StatefulWidget {
  final CalendarChartConfig config;
  const CalendarChartWidget({super.key, required this.config});
  @override
  State<CalendarChartWidget> createState() => _CalState();
}

class _CalState extends State<CalendarChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  String? _hovDate;
  Offset _hoverPos = Offset.zero;
  CalendarChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant CalendarChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature == _dataSignature) return;
    _dataSignature = nextSignature;
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (cfg.title?.text != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Text(
            cfg.title!.text!,
            style: cfg.theme.typography.titleStyle.copyWith(
              color: cfg.theme.titleColor,
            ),
          ),
        ),
      Expanded(
        child: LayoutBuilder(
          builder: (ctx, con) {
            final sz = Size(con.maxWidth, con.maxHeight);
            return Stack(
              children: [
                MouseRegion(
                  onHover: (e) {
                    const padL = 28.0, padT = 20.0;
                    final cellSize = (sz.width - padL) / 54;
                    final col = ((e.localPosition.dx - padL) / cellSize)
                        .floor();
                    final row = ((e.localPosition.dy - padT) / cellSize)
                        .floor();
                    if (col >= 0 && row >= 0 && row < 7) {
                      final jan1 = DateTime(cfg.year, 1, 1);
                      final jan1Dow = jan1.weekday % 7; // 0=Sun
                      final dayIdx = col * 7 + row - jan1Dow;
                      if (dayIdx >= 0) {
                        final d = jan1.add(Duration(days: dayIdx));
                        if (d.year == cfg.year) {
                          final ds =
                              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                          setState(() {
                            _hovDate = ds;
                            _hoverPos = e.localPosition;
                          });
                          return;
                        }
                      }
                    }
                    setState(() => _hovDate = null);
                  },
                  onExit: (_) => setState(() => _hovDate = null),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _CalPainter(
                        config: cfg,
                        progress: _anim.value,
                        hovDate: _hovDate,
                        dataSignature: _dataSignature,
                      ),
                    ),
                  ),
                ),
                if (_hovDate != null) _buildTooltip(sz),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _buildTooltip(Size sz) {
    final val = cfg.dateValues[_hovDate] ?? 0.0;
    double x = (_hoverPos.dx + 12).clamp(0, sz.width - 160.0);
    double y = (_hoverPos.dy - 50).clamp(0, sz.height - 60.0);
    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cfg.theme.tooltipBackgroundColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: DefaultTextStyle(
            style: cfg.theme.typography.tooltipStyle.copyWith(
              color: cfg.theme.tooltipTextColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _hovDate!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Value: ${val.toStringAsFixed(0)}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalPainter extends ChartPainterBase {
  final CalendarChartConfig config;
  final double progress;
  final String? hovDate;
  final String dataSignature;

  _CalPainter({
    required this.config,
    required this.progress,
    required this.dataSignature,
    this.hovDate,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _CalPainter old) =>
      old.progress != progress ||
      old.hovDate != hovDate ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 28.0, padT = 20.0;
    final cellSize = (size.width - padL) / 54;
    final gap = cellSize * 0.12;
    final r = cellSize * 0.25;
    final maxVal = config.dateValues.values
        .fold(0.0, math.max)
        .clamp(1.0, 1e18);

    final jan1 = DateTime(config.year, 1, 1);
    final jan1Dow = jan1.weekday % 7;

    // Month labels
    final months = [
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
    for (int m = 0; m < 12; m++) {
      final d = DateTime(config.year, m + 1, 1);
      final dayOfYear = d.difference(jan1).inDays;
      final week = (dayOfYear + jan1Dow) ~/ 7;
      final tp = textPainterCache.get(
        months[m],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
      );
      tp.paint(canvas, Offset(padL + week * cellSize + 2, 4));
    }

    // Day labels
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    for (int d = 0; d < 7; d++) {
      final tp = textPainterCache.get(
        days[d],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 8,
        ),
      );
      tp.paint(
        canvas,
        Offset(2, padT + d * cellSize + cellSize / 2 - tp.height / 2),
      );
    }

    // Cells
    for (int week = 0; week < 53; week++) {
      for (int dow = 0; dow < 7; dow++) {
        final dayIdx = week * 7 + dow - jan1Dow;
        if (dayIdx < 0) continue;
        final date = jan1.add(Duration(days: dayIdx));
        if (date.year != config.year) continue;
        final ds =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final val = config.dateValues[ds] ?? 0.0;
        final t = (val / maxVal * progress).clamp(0.0, 1.0);
        final isHov = ds == hovDate;
        final color = val == 0
            ? config.emptyColor
            : Color.lerp(config.emptyColor, config.maxColor, t)!;
        final x = padL + week * cellSize + gap / 2;
        final y = padT + dow * cellSize + gap / 2;
        final sz = cellSize - gap;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, sz, sz),
            Radius.circular(r),
          ),
          Paint()
            ..color = isHov ? Color.lerp(color, Colors.white, 0.3)! : color
            ..style = PaintingStyle.fill,
        );
      }
    }
  }
}
