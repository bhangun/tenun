import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_data_value_reader.dart';
import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/json_value.dart';

String _colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

// ═══════════════════════════════════════════════════════════
// 1. HEATMAP
// ═══════════════════════════════════════════════════════════

/// JSON:
/// ```json
/// { "type": "heatmap",
///   "xLabels": ["Mon","Tue","Wed","Thu","Fri"],
///   "yLabels": ["Morning","Afternoon","Evening"],
///   "series": [{ "data": [
///     [12,18,9,15,22],
///     [8,14,20,11,17],
///     [5,10,16,8,13]
///   ]}]}
/// ```
class HeatmapChartConfig extends BaseChartConfig {
  final List<String> xLabels, yLabels;
  final List<List<double>> data; // [row][col]
  final Color lowColor, highColor;
  final bool showValues;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  HeatmapChartConfig({
    required this.xLabels,
    required this.yLabels,
    required this.data,
    this.theme = ChartTheme.light,
    this.lowColor = const Color(0xFFE3F2FD),
    this.highColor = const Color(0xFF0D47A1),
    this.showValues = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.heatmap, series: const []);

  @override
  Widget buildChart() => HeatmapChartWidget(config: this);

  factory HeatmapChartConfig.fromJson(Map<String, dynamic> json) {
    final data = _parseHeatmapMatrix(_heatmapDataSource(json));
    final xl = _normalizeHeatmapLabels(
      JsonValue.stringList(json['xLabels']),
      data.fold<int>(0, (max, row) => row.length > max ? row.length : max),
      'Column',
    );
    final yl = _normalizeHeatmapLabels(
      JsonValue.stringList(json['yLabels']),
      data.length,
      'Row',
    );
    Color? c(String? k) {
      try {
        return colorCache.resolve(k ?? '');
      } catch (_) {
        return null;
      }
    }

    return HeatmapChartConfig(
      xLabels: xl,
      yLabels: yl,
      data: data,
      showValues: JsonValue.boolOrNull(json['showValues']) ?? true,
      lowColor: c(json['lowColor']?.toString()) ?? const Color(0xFFE3F2FD),
      highColor: c(json['highColor']?.toString()) ?? const Color(0xFF0D47A1),
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
    'xLabels': xLabels,
    'yLabels': yLabels,
    'series': [
      {'data': data},
    ],
    'lowColor': _colorToHex(lowColor),
    'highColor': _colorToHex(highColor),
    'showValues': showValues,
  };
}

Object? _heatmapDataSource(Map<String, dynamic> json) {
  if (json.containsKey('data')) return json['data'];

  final series = JsonValue.list(json['series']);
  if (series == null || series.isEmpty) return null;

  final firstSeriesMap = JsonValue.map(series.first);
  if (firstSeriesMap != null) return firstSeriesMap['data'];

  return series;
}

List<List<double>> _parseHeatmapMatrix(Object? raw) {
  final rows = JsonValue.list(raw);
  if (rows == null) return const <List<double>>[];

  final matrix = <List<double>>[];
  for (final rawRow in rows) {
    final rowMap = JsonValue.map(rawRow);
    final rowSource = rowMap != null && rowMap.containsKey('data')
        ? rowMap['data']
        : rawRow;
    final rowItems = JsonValue.list(rowSource);
    if (rowItems == null) {
      final value = ChartDataValueReader.yValueOrNull(rowSource);
      if (value != null) matrix.add(<double>[value]);
      continue;
    }

    matrix.add(
      rowItems
          .map((cell) => ChartDataValueReader.yValueOrNull(cell) ?? 0.0)
          .toList(growable: false),
    );
  }

  return matrix;
}

List<String> _normalizeHeatmapLabels(
  List<String>? labels,
  int expectedLength,
  String fallbackPrefix,
) {
  final normalized = List<String>.from(labels ?? const <String>[]);
  for (var i = normalized.length; i < expectedLength; i++) {
    normalized.add('$fallbackPrefix ${i + 1}');
  }
  return normalized;
}

class HeatmapChartWidget extends StatefulWidget {
  final HeatmapChartConfig config;
  const HeatmapChartWidget({super.key, required this.config});
  @override
  State<HeatmapChartWidget> createState() => _HeatmapState();
}

class _HeatmapState extends State<HeatmapChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  int _hovRow = -1, _hovCol = -1;
  Offset _hoverPos = Offset.zero;
  HeatmapChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant HeatmapChartWidget oldWidget) {
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
                    const padL = 60.0, padT = 24.0;
                    final cols = cfg.xLabels.length, rows = cfg.yLabels.length;
                    if (cols == 0 || rows == 0) return;
                    final plotWidth = sz.width - padL - 8;
                    final plotHeight = sz.height - padT - 8;
                    if (plotWidth <= 0 || plotHeight <= 0) return;
                    final cW = plotWidth / cols;
                    final rH = plotHeight / rows;
                    setState(() {
                      _hovCol = ((e.localPosition.dx - padL) / cW)
                          .floor()
                          .clamp(0, cols - 1);
                      _hovRow = ((e.localPosition.dy - padT) / rH)
                          .floor()
                          .clamp(0, rows - 1);
                      _hoverPos = e.localPosition;
                    });
                  },
                  onExit: (_) => setState(() {
                    _hovRow = -1;
                    _hovCol = -1;
                  }),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _HeatmapPainter(
                        config: cfg,
                        progress: _anim.value,
                        hovRow: _hovRow,
                        hovCol: _hovCol,
                        dataSignature: _dataSignature,
                      ),
                    ),
                  ),
                ),
                if (_hovRow >= 0 && _hovCol >= 0) _buildTooltip(sz),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _buildTooltip(Size sz) {
    final val =
        _hovRow < cfg.data.length && _hovCol < (cfg.data[_hovRow].length)
        ? cfg.data[_hovRow][_hovCol]
        : 0.0;
    double x = (_hoverPos.dx + 12).clamp(0, sz.width - 170.0);
    double y = (_hoverPos.dy - 55).clamp(0, sz.height - 70.0);
    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                  '${_hovRow < cfg.yLabels.length ? cfg.yLabels[_hovRow] : ""} / ${_hovCol < cfg.xLabels.length ? cfg.xLabels[_hovCol] : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Value: ${val.toStringAsFixed(1)}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends ChartPainterBase {
  final HeatmapChartConfig config;
  final double progress;
  final int hovRow, hovCol;
  final String dataSignature;

  _HeatmapPainter({
    required this.config,
    required this.progress,
    required this.hovRow,
    required this.hovCol,
    required this.dataSignature,
  }) : super(theme: config.theme);
  @override
  bool shouldRepaintChart(covariant _HeatmapPainter old) =>
      old.progress != progress ||
      old.hovRow != hovRow ||
      old.hovCol != hovCol ||
      old.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 60.0, padT = 24.0, padR = 8.0, padB = 8.0;
    final cols = config.xLabels.length, rows = config.yLabels.length;
    if (cols == 0 || rows == 0 || config.data.isEmpty) return;
    final plotWidth = size.width - padL - padR;
    final plotHeight = size.height - padT - padB;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    double lo = double.infinity, hi = double.negativeInfinity;
    for (final row in config.data) {
      for (final v in row) {
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    final range = (hi - lo).clamp(1.0, 1e18);

    final cW = plotWidth / cols;
    final rH = plotHeight / rows;

    for (int r = 0; r < rows; r++) {
      if (r >= config.data.length) break;
      for (int c = 0; c < cols; c++) {
        if (c >= config.data[r].length) break;
        final v = config.data[r][c];
        final t = ((v - lo) / range * progress).clamp(0.0, 1.0);
        final color = Color.lerp(config.lowColor, config.highColor, t)!;
        final isHov = r == hovRow && c == hovCol;
        final rect = Rect.fromLTWH(
          padL + c * cW + 1,
          padT + r * rH + 1,
          cW - 2,
          rH - 2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()
            ..color = isHov ? Color.lerp(color, Colors.white, 0.25)! : color
            ..style = PaintingStyle.fill,
        );
        if (config.showValues && cW > 24 && rH > 16) {
          final tp = textPainterCache.get(
            v.toStringAsFixed(0),
            theme.typography.axisLabelStyle.copyWith(
              color: t > 0.6 ? Colors.white : Colors.black87,
              fontSize: 9,
            ),
            align: TextAlign.center,
            maxWidth: cW - 4,
          );
          tp.paint(
            canvas,
            Offset(
              padL + c * cW + cW / 2 - tp.width / 2,
              padT + r * rH + rH / 2 - tp.height / 2,
            ),
          );
        }
      }
    }
    // X labels
    for (int c = 0; c < cols; c++) {
      final tp = textPainterCache.get(
        config.xLabels[c],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
        maxWidth: cW,
      );
      tp.paint(canvas, Offset(padL + c * cW + cW / 2 - tp.width / 2, 4));
    }
    // Y labels
    for (int r = 0; r < rows; r++) {
      final tp = textPainterCache.get(
        config.yLabels[r],
        theme.typography.axisLabelStyle.copyWith(color: theme.axisLabelColor),
        maxWidth: padL - 4,
        align: TextAlign.right,
      );
      tp.paint(
        canvas,
        Offset(padL - tp.width - 4, padT + r * rH + rH / 2 - tp.height / 2),
      );
    }
  }
}
