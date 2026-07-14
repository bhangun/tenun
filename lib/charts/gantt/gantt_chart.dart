// Gantt chart — horizontal timeline with task bars and optional dependencies.
//
// Each task has a start/end date (or numeric start/duration).
// Supports milestones (diamond markers), dependency arrows, grouping,
// today-line marker, and progress fill inside bars.
//
// JSON:
// ```json
// {
//   "type": "gantt",
//   "dateFormat": "yyyy-MM-dd",
//   "series": [{
//     "data": [
//       { "id":"t1", "name":"Research",    "start":"2024-01-01","end":"2024-01-15","progress":100,"group":"Phase 1"},
//       { "id":"t2", "name":"Design",      "start":"2024-01-10","end":"2024-02-01","progress":80, "group":"Phase 1","deps":["t1"]},
//       { "id":"t3", "name":"Development", "start":"2024-02-01","end":"2024-03-15","progress":35, "group":"Phase 2","deps":["t2"]},
//       { "id":"t4", "name":"QA",          "start":"2024-03-10","end":"2024-04-01","progress":0,  "group":"Phase 2"},
//       { "id":"ms1","name":"Launch",      "start":"2024-04-01","milestone":true }
//     ]
//   }]
// }
// ```

import 'package:flutter/material.dart';

import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_type.dart';

import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_series_json.dart';
import 'package:tenun_core/core/json_value.dart';

// ─────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────

class GanttTask {
  final String id;
  final String name;
  final DateTime start;
  final DateTime end; // same as start for milestones
  final double progress; // 0–100
  final bool isMilestone;
  final String? group;
  final List<String> deps; // dependency task IDs
  final String? color;

  const GanttTask({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    this.progress = 0,
    this.isMilestone = false,
    this.group,
    this.deps = const [],
    this.color,
  });

  factory GanttTask.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(String? s) {
      if (s == null) return DateTime.now();
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.now();
      }
    }

    final start = parseDate(j['start']?.toString());
    final end = j['end'] != null
        ? parseDate(j['end'].toString())
        : j['duration'] != null
        ? start.add(Duration(days: JsonValue.intOrNull(j['duration']) ?? 0))
        : start;

    return GanttTask(
      id: j['id']?.toString() ?? j['name']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      start: start,
      end: end,
      progress: JsonValue.doubleOrNull(j['progress']) ?? 0,
      isMilestone: JsonValue.boolOrNull(j['milestone']) ?? false,
      group: j['group']?.toString(),
      deps: JsonValue.stringList(j['deps']) ?? const <String>[],
      color: j['color']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': start.toIso8601String(),
    if (!isMilestone) 'end': end.toIso8601String(),
    'progress': progress,
    'milestone': isMilestone,
    if (group != null) 'group': group,
    if (deps.isNotEmpty) 'deps': deps,
    if (color != null) 'color': color,
  };
}

// ─────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────

class GanttChartConfig extends BaseChartConfig {
  final List<GanttTask> tasks;
  final bool showDependencies;
  final bool showProgress;
  final bool showToday;
  final bool showGroups;
  final double rowHeight;

  GanttChartConfig({
    required this.tasks,
    super.theme = ChartTheme.light,
    this.showDependencies = true,
    this.showProgress = true,
    this.showToday = true,
    this.showGroups = true,
    this.rowHeight = 32,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.gantt, series: const []);

  @override
  Widget buildChart() => GanttChartWidget(config: this);

  factory GanttChartConfig.fromJson(Map<String, dynamic> json) {
    final tasks = ChartSeriesJson.firstSeriesData(
      json['series'],
    ).map(GanttTask.fromJson).toList();
    return GanttChartConfig(
      tasks: tasks,
      showDependencies: JsonValue.boolOrNull(json['showDependencies']) ?? true,
      showProgress: JsonValue.boolOrNull(json['showProgress']) ?? true,
      showToday: JsonValue.boolOrNull(json['showToday']) ?? true,
      showGroups: JsonValue.boolOrNull(json['showGroups']) ?? true,
      rowHeight: JsonValue.doubleOrNull(json['rowHeight']) ?? 32,
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
    'series': [
      {'data': tasks.map((task) => task.toJson()).toList()},
    ],
    'showDependencies': showDependencies,
    'showProgress': showProgress,
    'showToday': showToday,
    'showGroups': showGroups,
    'rowHeight': rowHeight,
  };
}

// ─────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────

class GanttChartWidget extends StatefulWidget {
  final GanttChartConfig config;
  const GanttChartWidget({super.key, required this.config});

  @override
  State<GanttChartWidget> createState() => _GanttState();
}

class _GanttState extends State<GanttChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  GanttTask? _hovTask;
  Offset _hoverPos = Offset.zero;
  double _scrollX = 0;

  GanttChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _dataSignature = ChartDataSignature.fromConfig(widget.config).hash;
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(GanttChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(widget.config).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _hovTask = null;
      _scrollX = 0;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── date bounds ──
  DateTime get _minDate => cfg.tasks.isEmpty
      ? DateTime.now()
      : cfg.tasks
            .map((t) => t.start)
            .reduce((a, b) => a.isBefore(b) ? a : b)
            .subtract(const Duration(days: 2));
  DateTime get _maxDate => cfg.tasks.isEmpty
      ? DateTime.now().add(const Duration(days: 30))
      : cfg.tasks
            .map((t) => t.isMilestone ? t.start : t.end)
            .reduce((a, b) => a.isAfter(b) ? a : b)
            .add(const Duration(days: 4));

  @override
  Widget build(BuildContext context) {
    return Column(
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
                  GestureDetector(
                    onPanUpdate: (d) => setState(() {
                      _scrollX = (_scrollX - d.delta.dx).clamp(-400.0, 0.0);
                    }),
                    behavior: HitTestBehavior.opaque,
                    child: MouseRegion(
                      onHover: (e) => _onHover(e.localPosition, sz),
                      onExit: (_) => setState(() => _hovTask = null),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _GanttPainter(
                            config: cfg,
                            progress: _anim.value,
                            hovTask: _hovTask,
                            minDate: _minDate,
                            maxDate: _maxDate,
                            scrollX: _scrollX,
                            dataSignature: _dataSignature,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_hovTask != null) _buildTooltip(sz),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _onHover(Offset pos, Size sz) {
    const labelW = 110.0;
    final headerH = 32.0;
    final totalDays = _maxDate.difference(_minDate).inDays.toDouble();
    if (totalDays <= 0) return;
    final chartW = sz.width - labelW;
    for (int i = 0; i < cfg.tasks.length; i++) {
      final t = cfg.tasks[i];
      final rowY = headerH + i * cfg.rowHeight;
      final x1 =
          labelW +
          (t.start.difference(_minDate).inDays / totalDays * chartW) +
          _scrollX;
      final x2 = t.isMilestone
          ? x1 + 12
          : labelW +
                (t.end.difference(_minDate).inDays / totalDays * chartW) +
                _scrollX;
      if (pos.dy >= rowY &&
          pos.dy <= rowY + cfg.rowHeight &&
          pos.dx >= x1 - 4 &&
          pos.dx <= x2 + 4) {
        setState(() {
          _hovTask = t;
          _hoverPos = pos;
        });
        return;
      }
    }
    setState(() => _hovTask = null);
  }

  Widget _buildTooltip(Size sz) {
    final t = _hovTask!;
    final dur = t.isMilestone
        ? 'Milestone'
        : '${t.end.difference(t.start).inDays}d';
    double x = (_hoverPos.dx + 14).clamp(0, sz.width - 210.0);
    double y = (_hoverPos.dy - 65).clamp(0, sz.height - 100.0);
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
                  t.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (t.group != null) Text(t.group!),
                Text('Start: ${_fmtDate(t.start)}'),
                if (!t.isMilestone) Text('End: ${_fmtDate(t.end)}'),
                Text('Duration: $dur'),
                if (!t.isMilestone && t.progress > 0)
                  Text('Progress: ${t.progress.toStringAsFixed(0)}%'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────

class _GanttPainter extends ChartPainterBase {
  final GanttChartConfig config;
  final double progress;
  final GanttTask? hovTask;
  final DateTime minDate;
  final DateTime maxDate;
  final double scrollX;
  final String dataSignature;

  _GanttPainter({
    required this.config,
    required this.progress,
    this.hovTask,
    required this.minDate,
    required this.maxDate,
    this.scrollX = 0,
    required this.dataSignature,
  }) : super(theme: config.theme);

  @override
  bool shouldRepaintChart(covariant _GanttPainter old) =>
      old.progress != progress ||
      old.hovTask != hovTask ||
      old.scrollX != scrollX ||
      old.dataSignature != dataSignature;

  static const double _labelW = 110.0;
  static const double _headerH = 32.0;

  double _dateToX(DateTime d, double chartW) {
    final total = maxDate.difference(minDate).inDays.toDouble();
    if (total <= 0) return _labelW + chartW / 2 + scrollX;
    return _labelW + (d.difference(minDate).inDays / total * chartW) + scrollX;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (config.tasks.isEmpty) return;
    final chartW = size.width - _labelW;
    final rowH = config.rowHeight;

    // ── header background ──
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, _headerH),
      paintCache.fill(
        theme.backgroundColor == Colors.transparent
            ? const Color(0xFFF5F5F5)
            : theme.backgroundColor,
      ),
    );

    // ── date header ticks ──
    final totalDays = maxDate.difference(minDate).inDays;
    final tickInterval = totalDays > 90
        ? 30
        : totalDays > 30
        ? 7
        : 1;
    DateTime tick = DateTime(minDate.year, minDate.month, minDate.day);
    while (tick.isBefore(maxDate)) {
      final x = _dateToX(tick, chartW);
      if (x >= _labelW && x <= size.width) {
        canvas.drawLine(
          Offset(x, _headerH - 6),
          Offset(x, _headerH),
          paintCache.stroke(theme.axisColor, 1),
        );
        final label = tickInterval >= 30
            ? '${tick.month}/${tick.year}'
            : tickInterval >= 7
            ? '${tick.month}/${tick.day}'
            : '${tick.day}';
        final tp = textPainterCache.get(
          label,
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 9,
          ),
        );
        tp.paint(canvas, Offset(x - tp.width / 2, _headerH - 20));
      }
      tick = tick.add(Duration(days: tickInterval));
    }

    // ── row backgrounds + task bars ──
    final taskById = {for (final t in config.tasks) t.id: t};
    String? currentGroup;
    int colorIdx = 0;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, _headerH, size.width, size.height - _headerH),
    );

    for (int i = 0; i < config.tasks.length; i++) {
      final t = config.tasks[i];
      final rowY = _headerH + i * rowH;

      // Alternating row
      if (i % 2 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, rowY, size.width, rowH),
          paintCache.fill(const Color(0x08000000)),
        );
      }

      // Group header
      if (config.showGroups && t.group != null && t.group != currentGroup) {
        currentGroup = t.group;
        final tp = textPainterCache.get(
          t.group!,
          theme.typography.axisLabelStyle.copyWith(
            color: theme.axisLabelColor,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        );
        tp.paint(canvas, Offset(4, rowY + rowH / 2 - tp.height / 2));
      }

      // Task name
      final nameTp = textPainterCache.get(
        t.name,
        theme.typography.axisLabelStyle.copyWith(color: theme.axisLabelColor),
        maxWidth: _labelW - 8,
      );
      nameTp.paint(
        canvas,
        Offset(
          t.group != null && config.showGroups ? 12 : 4,
          rowY + rowH / 2 - nameTp.height / 2,
        ),
      );

      // Bar
      final color = theme.seriesColor(colorIdx++, explicitColor: t.color);
      final x1 = _dateToX(t.start, chartW);
      final x2 = t.isMilestone ? x1 : _dateToX(t.end, chartW);
      final barH = rowH * 0.55;
      final barY = rowY + (rowH - barH) / 2;
      final isHov = t == hovTask;

      if (t.isMilestone) {
        // Diamond
        final mx = x1, my = rowY + rowH / 2;
        final s = rowH * 0.3;
        final diamond = Path()
          ..moveTo(mx, my - s)
          ..lineTo(mx + s, my)
          ..lineTo(mx, my + s)
          ..lineTo(mx - s, my)
          ..close();
        canvas.drawPath(
          diamond,
          Paint()
            ..color = isHov ? color.withValues(alpha: 0.9) : color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
        canvas.drawPath(
          diamond,
          paintCache.stroke(Colors.white.withValues(alpha: 0.5), 1),
        );
      } else {
        // Bar (animated width)
        final animW = (x2 - x1) * progress;
        final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(x1, barY, animW, barH),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..color = isHov
                ? Color.lerp(color, Colors.white, 0.2)!
                : color.withValues(alpha: 0.85)
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );

        // Progress fill
        if (config.showProgress && t.progress > 0) {
          final progW = animW * (t.progress / 100);
          final progRR = RRect.fromRectAndRadius(
            Rect.fromLTWH(x1, barY, progW, barH),
            const Radius.circular(3),
          );
          canvas.drawRRect(
            progRR,
            Paint()
              ..color = color.withValues(alpha: 0.4)
              ..style = PaintingStyle.fill,
          );
        }
        canvas.drawRRect(
          rr,
          paintCache.stroke(Colors.white.withValues(alpha: 0.3), 0.8),
        );
      }
    }

    // ── dependency arrows ──
    if (config.showDependencies) {
      for (int i = 0; i < config.tasks.length; i++) {
        final task = config.tasks[i];
        for (final depId in task.deps) {
          final dep = taskById[depId];
          if (dep == null) continue;
          final depIdx = config.tasks.indexOf(dep);
          final srcX = _dateToX(dep.end, chartW);
          final srcY = _headerH + depIdx * rowH + rowH / 2;
          final dstX = _dateToX(task.start, chartW);
          final dstY = _headerH + i * rowH + rowH / 2;
          _drawArrow(canvas, Offset(srcX, srcY), Offset(dstX, dstY));
        }
      }
    }

    canvas.restore();

    // ── today line ──
    if (config.showToday) {
      final today = DateTime.now();
      if (today.isAfter(minDate) && today.isBefore(maxDate)) {
        final tx = _dateToX(today, chartW);
        canvas.drawLine(
          Offset(tx, _headerH),
          Offset(tx, size.height),
          paintCache.stroke(const Color(0xAAE53935), 1.5),
        );
        final tp = textPainterCache.get(
          'Today',
          theme.typography.axisLabelStyle.copyWith(
            color: const Color(0xFFE53935),
            fontSize: 9,
          ),
        );
        tp.paint(canvas, Offset(tx - tp.width / 2, _headerH + 2));
      }
    }

    // ── axes ──
    canvas.drawLine(
      Offset(_labelW, _headerH),
      Offset(_labelW, size.height),
      axisPaint,
    );
    canvas.drawLine(
      Offset(0, _headerH),
      Offset(size.width, _headerH),
      axisPaint,
    );
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to) {
    final mid = Offset(from.dx + 8, from.dy);
    final mid2 = Offset(from.dx + 8, to.dy);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(mid2.dx, mid2.dy)
      ..lineTo(to.dx, to.dy);
    canvas.drawPath(
      path,
      paintCache.stroke(theme.axisColor.withValues(alpha: 0.6), 1),
    );
    // Arrowhead
    const ah = 5.0;
    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..lineTo(to.dx - ah, to.dy - ah / 2)
        ..lineTo(to.dx - ah, to.dy + ah / 2)
        ..close(),
      paintCache.fill(theme.axisColor.withValues(alpha: 0.6)),
    );
  }
}
