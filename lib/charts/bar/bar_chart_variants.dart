/// Bar chart variants — 13 specialized bar/column chart types.
///
/// Charts in this file:
///   • [BarBackgroundChartConfig]   — bar with translucent background track
///   • [BarRaceChartConfig]         — animated bar race (sorted, racing frames)
///   • [BarGradientChartConfig]     — per-bar gradient fill + click selection
///   • [BarLabelRotationConfig]     — configurable axis-label rotation angle
///   • [BarRoundedStackedConfig]    — stacked bars with rounded top segment
///   • [BarNormalizedConfig]        — 100 %-normalised stacked bar
///   • [BarBrushConfig]             — bar with interactive brush range-select
///   • [NegativeBarConfig]          — horizontal bar with negative-value support
///   • [TangentialPolarBarConfig]   — polar bar with tangential label layout
///
/// The remaining variants (stacked column, stacked horizontal, mixed line+bar)
/// are already covered by [stackedBar], [stackedHorizontalBar], and [combo]
/// in the existing library — this file adds *new* sub-variants only.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../core/chart_cache.dart';
import '../../core/chart_data_signature.dart';
import '../../core/chart_data_processor.dart';
import '../../core/chart_painter_base.dart';
import '../../core/chart_theme.dart';
import '../../core/base_config.dart';
import '../../core/chart_type.dart';
import '../../core/series.dart';
import 'bar_json_helpers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════

List<Series> _seriesFromJson(Object? value) => BarJson.series(value);

double? _seriesValueAt(Series series, int index) {
  final data = series.data;
  if (data == null || index < 0 || index >= data.length) return null;
  return BarJson.doubleOrNull(data[index]);
}

double _labelRotation(Object? raw) {
  return BarJson.doubleOr(raw, 45.0).clamp(0.0, 90.0).toDouble();
}

double _innerRadius(Object? raw) {
  return BarJson.doubleOr(raw, 0.3).clamp(0.0, 0.85).toDouble();
}

double _positiveStackTotalAt(List<Series> series, int index) {
  double total = 0;
  for (final item in series) {
    final value = _seriesValueAt(item, index);
    if (value != null && value > 0) total += value;
  }
  return total;
}

int _lastPositiveSeriesIndexAt(List<Series> series, int index) {
  for (var i = series.length - 1; i >= 0; i--) {
    final value = _seriesValueAt(series[i], index);
    if (value != null && value > 0) return i;
  }
  return -1;
}

/// Draw a rounded-top rect on [canvas] (only top corners rounded).
void _drawRoundedTopRect(Canvas canvas, Rect rect, double radius, Paint paint) {
  if (radius <= 0 || rect.height <= 0) {
    canvas.drawRect(rect, paint);
    return;
  }
  final r = math.min(radius, rect.height / 2);
  final path = Path()
    ..moveTo(rect.left, rect.bottom)
    ..lineTo(rect.left, rect.top + r)
    ..arcToPoint(
      Offset(rect.left + r, rect.top),
      radius: Radius.circular(r),
      clockwise: false,
    )
    ..lineTo(rect.right - r, rect.top)
    ..arcToPoint(
      Offset(rect.right, rect.top + r),
      radius: Radius.circular(r),
      clockwise: false,
    )
    ..lineTo(rect.right, rect.bottom)
    ..close();
  canvas.drawPath(path, paint);
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. BAR WITH BACKGROUND TRACK
// ═══════════════════════════════════════════════════════════════════════════
/// A vertical bar chart where each bar sits inside a full-height translucent
/// background track, making it easier to read proportions.
///
/// JSON:
/// ```json
/// { "type": "barBackground", "trackOpacity": 0.12,
///   "categories": ["Mon","Tue","Wed","Thu","Fri"],
///   "series": [{ "name": "Sales", "data": [120,200,150,80,70] }] }
/// ```
class BarBackgroundChartConfig extends BaseChartConfig {
  final List<String> categories;
  final double trackOpacity;
  final double barWidthRatio;
  final bool showValues;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  BarBackgroundChartConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.trackOpacity = 0.12,
    this.barWidthRatio = 0.55,
    this.showValues = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.barBackground);

  @override
  Widget buildChart() => _SimpleBarWidget(config: this);

  factory BarBackgroundChartConfig.fromJson(Map<String, dynamic> j) {
    final cats = BarJson.stringList(
      j['categories'] ?? j['labels'] ?? j['xLabels'],
    );
    final s = _seriesFromJson(j['series']);
    return BarBackgroundChartConfig(
      categories: cats,
      series: s,
      trackOpacity: BarJson.ratio(j['trackOpacity'], 0.12),
      barWidthRatio: BarJson.ratio(j['barWidthRatio'], 0.55),
      showValues: BarJson.boolOr(j['showValues'], true),
      title: BarJson.title(j['title']),
      tooltip: BarJson.tooltip(j['tooltip']),
      legend: BarJson.legend(j['legend']),
      toolbox: BarJson.toolbox(j['toolbox']),
      grid: BarJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'trackOpacity': trackOpacity,
    'barWidthRatio': barWidthRatio,
    'showValues': showValues,
  };
}

class _SimpleBarWidget extends StatefulWidget {
  final BarBackgroundChartConfig config;
  const _SimpleBarWidget({required this.config});
  @override
  State<_SimpleBarWidget> createState() => _SimpleBarState();
}

class _SimpleBarState extends State<_SimpleBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _hovIdx = -1;
  Offset _hovPos = Offset.zero;
  late String _dataSignature;

  BarBackgroundChartConfig get cfg => widget.config;

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
  void didUpdateWidget(_SimpleBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _hovIdx = -1;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                  MouseRegion(
                    onHover: (e) {
                      final n = cfg.categories.length;
                      if (n == 0) return;
                      final slotW = (sz.width - 80.0) / n;
                      final idx = ((e.localPosition.dx - 40) / slotW)
                          .floor()
                          .clamp(0, n - 1);
                      setState(() {
                        _hovIdx = idx;
                        _hovPos = e.localPosition;
                      });
                    },
                    onExit: (_) => setState(() => _hovIdx = -1),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _BarBgPainter(
                          cfg: cfg,
                          progress: _anim.value,
                          hovIdx: _hovIdx,
                          dataSignature: _dataSignature,
                        ),
                      ),
                    ),
                  ),
                  if (_hovIdx >= 0) _tooltip(sz),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tooltip(Size sz) {
    final rows = cfg.series.map((series) {
      final value = _seriesValueAt(series, _hovIdx);
      if (value == null) return null;
      return '${series.name ?? ''}: ${value.toStringAsFixed(1)}';
    }).whereType<String>();
    double x = (_hovPos.dx + 12).clamp(0.0, sz.width - 160.0);
    double y = (_hovPos.dy - 60).clamp(0.0, sz.height - 80.0);
    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: cfg.theme.tooltipBackgroundColor,
            borderRadius: BorderRadius.circular(7),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
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
                  _hovIdx < cfg.categories.length
                      ? cfg.categories[_hovIdx]
                      : '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ...rows.map((r) => Text(r)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarBgPainter extends ChartPainterBase {
  final BarBackgroundChartConfig cfg;
  final double progress;
  final int hovIdx;
  final String dataSignature;
  _BarBgPainter({
    required this.cfg,
    required this.progress,
    required this.hovIdx,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _BarBgPainter o) =>
      o.progress != progress ||
      o.hovIdx != hovIdx ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = cfg.categories.length;
    if (n == 0 || cfg.series.isEmpty) return;
    const padL = 48.0, padR = 12.0, padT = 24.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final slotW = plotW / n;
    final barW = slotW * cfg.barWidthRatio;

    // Max value across all series for Y scale
    double maxVal = 0;
    for (final s in cfg.series) {
      final data = s.data ?? const <dynamic>[];
      for (var index = 0; index < data.length; index++) {
        final d = _seriesValueAt(s, index);
        if (d == null) continue;
        if (d > maxVal) maxVal = d;
      }
    }
    if (maxVal == 0) return;
    maxVal *= 1.1;

    double toY(double v) => padT + plotH * (1 - v / maxVal * progress);

    // Y axis ticks
    final ticks = ChartDataProcessor.niceYTicks(0, maxVal / 1.1);
    for (final t in ticks) {
      final y = padT + plotH * (1 - t / maxVal);
      canvas.drawLine(
        Offset(padL, y),
        Offset(padL + plotW, y),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final tp = textPainterCache.get(
        t.toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
        align: TextAlign.right,
        maxWidth: 40,
      );
      tp.paint(canvas, Offset(padL - tp.width - 4, y - tp.height / 2));
    }

    final nseries = cfg.series.length;
    final groupBarW = barW / nseries;

    for (int ci = 0; ci < n; ci++) {
      final cx = padL + (ci + 0.5) * slotW;
      final isHov = ci == hovIdx;

      for (int si = 0; si < nseries; si++) {
        final s = cfg.series[si];
        final d = s.data;
        if (d == null || ci >= d.length) continue;
        final val = _seriesValueAt(s, ci);
        if (val == null) continue;
        final color = theme.seriesColor(si, explicitColor: s.color);

        final barX = cx - barW / 2 + si * groupBarW;

        // Background track
        canvas.drawRect(
          Rect.fromLTWH(barX, padT, groupBarW - 2, plotH),
          Paint()
            ..color = color.withValues(alpha: cfg.trackOpacity)
            ..style = PaintingStyle.fill,
        );

        // Actual bar
        final y = toY(val);
        final barRect = Rect.fromLTWH(barX, y, groupBarW - 2, padT + plotH - y);
        _drawRoundedTopRect(
          canvas,
          barRect,
          3,
          Paint()
            ..color = isHov ? color.withValues(alpha: cfg.trackOpacity) : color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );

        // Value label
        if (cfg.showValues) {
          final tp = textPainterCache.get(
            val.toStringAsFixed(0),
            (theme.typography.dataLabelStyle ?? theme.typography.axisLabelStyle)
                .copyWith(color: theme.titleColor, fontSize: 9),
          );
          tp.paint(
            canvas,
            Offset(
              barX + (groupBarW - 2) / 2 - tp.width / 2,
              y - tp.height - 2,
            ),
          );
        }
      }

      // Category label
      final lbl = textPainterCache.get(
        cfg.categories[ci],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9.5,
        ),
      );
      lbl.paint(canvas, Offset(cx - lbl.width / 2, padT + plotH + 4));
    }

    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. BAR RACE (animated ranking)
// ═══════════════════════════════════════════════════════════════════════════
/// Animated bar race chart. Provide a list of frames (each frame is a map
/// of label → value); the chart transitions between frames, sorting bars
/// by value each frame with smooth animation.
///
/// JSON:
/// ```json
/// { "type": "barRace", "frameDuration": 1200,
///   "frames": [
///     { "label": "2020", "values": {"China":1440,"India":1380,"USA":330,"Brazil":213} },
///     { "label": "2021", "values": {"China":1444,"India":1393,"USA":333,"Brazil":215} }
///   ] }
/// ```
class BarRaceFrame {
  final String label;
  final Map<String, double> values;
  const BarRaceFrame({required this.label, required this.values});

  factory BarRaceFrame.fromJson(Map<String, dynamic> j) => BarRaceFrame(
    label: BarJson.string(j['label']) ?? '',
    values: BarJson.doubleMap(j['values']),
  );

  Map<String, dynamic> toJson() => {'label': label, 'values': values};
}

class BarRaceMarkerStyle {
  final String? text;
  final String? imageAsset;
  final String? imageUrl;
  final double size;
  final String? backgroundColor;
  final String? borderColor;
  final double borderWidth;
  final double borderRadius;
  final double padding;

  const BarRaceMarkerStyle({
    this.text,
    this.imageAsset,
    this.imageUrl,
    this.size = 26,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.borderRadius = 999,
    this.padding = 2,
  });

  factory BarRaceMarkerStyle.fromJson(Object? value) {
    if (value is String) {
      final text = value.trim();
      if (_looksLikeImageUrl(text)) {
        return BarRaceMarkerStyle(imageUrl: text);
      }
      return BarRaceMarkerStyle(text: text);
    }

    final json = BarJson.map(value);
    if (json == null) return const BarRaceMarkerStyle();

    final rawImage =
        json['image'] ?? json['src'] ?? json['asset'] ?? json['imageAsset'];
    final imageText = BarJson.string(rawImage);
    final explicitImageUrl = BarJson.string(json['imageUrl']);
    final explicitImageAsset = BarJson.string(json['imageAsset']);
    final imageUrl =
        explicitImageUrl ??
        (imageText != null && _looksLikeImageUrl(imageText) ? imageText : null);
    final imageAsset =
        explicitImageAsset ??
        (imageText != null && !_looksLikeImageUrl(imageText)
            ? imageText
            : null);

    return BarRaceMarkerStyle(
      text: BarJson.string(
        json['text'] ?? json['icon'] ?? json['fallbackText'],
      ),
      imageAsset: imageAsset,
      imageUrl: imageUrl,
      size: BarJson.nonNegativeDouble(json['size'], 26),
      backgroundColor: BarJson.string(
        json['backgroundColor'] ?? json['background'],
      ),
      borderColor: BarJson.string(json['borderColor']),
      borderWidth: BarJson.nonNegativeDouble(json['borderWidth'], 0),
      borderRadius: BarJson.nonNegativeDouble(json['borderRadius'], 999),
      padding: BarJson.nonNegativeDouble(json['padding'], 2),
    );
  }

  bool get hasImage => imageAsset != null || imageUrl != null;

  Map<String, dynamic> toJson() => {
    'text': text,
    'imageAsset': imageAsset,
    'imageUrl': imageUrl,
    'size': size,
    'backgroundColor': backgroundColor,
    'borderColor': borderColor,
    'borderWidth': borderWidth,
    'borderRadius': borderRadius,
    'padding': padding,
  };

  static bool _looksLikeImageUrl(String value) {
    final normalized = value.toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }
}

List<BarRaceFrame> _barRaceFramesFromJson(Map<String, dynamic> json) {
  final rawFrames = _barRaceRawFrames(json['frames']);
  final categories = BarJson.stringList(
    json['categories'] ?? json['dataLabels'],
  );
  final frameLabels = BarJson.stringList(json['frameLabels'] ?? json['labels']);

  return rawFrames.asMap().entries.map((entry) {
    final index = entry.key;
    final raw = entry.value;
    final fallbackLabel = index < frameLabels.length
        ? frameLabels[index]
        : (index + 1).toString();

    final frameJson = BarJson.map(raw);
    if (frameJson != null) {
      if (frameJson.containsKey('values')) {
        return BarRaceFrame.fromJson({
          ...frameJson,
          'label': frameJson['label'] ?? fallbackLabel,
        });
      }

      final values = <String, double>{};
      frameJson.forEach((key, value) {
        if (key == 'label') return;
        final parsed = BarJson.doubleOrNull(value);
        if (parsed != null) values[key.toString()] = parsed;
      });
      return BarRaceFrame(
        label: BarJson.string(frameJson['label']) ?? fallbackLabel,
        values: values,
      );
    }

    final rawList = BarJson.list(raw);
    if (rawList.isNotEmpty) {
      return BarRaceFrame(
        label: fallbackLabel,
        values: {
          for (var i = 0; i < math.min(categories.length, rawList.length); i++)
            if (BarJson.doubleOrNull(rawList[i]) != null)
              categories[i]: BarJson.doubleOrNull(rawList[i])!,
        },
      );
    }

    return BarRaceFrame(label: fallbackLabel, values: const {});
  }).toList();
}

List<dynamic> _barRaceRawFrames(Object? raw) {
  final frames = BarJson.list(raw);
  if (frames.isNotEmpty) return frames;
  final frameMap = BarJson.map(raw);
  if (frameMap == null) return const <dynamic>[];
  return [
    for (final entry in frameMap.entries) _barRaceFrameFromMapEntry(entry),
  ];
}

Map<String, dynamic> _barRaceFrameFromMapEntry(
  MapEntry<String, dynamic> entry,
) {
  final frameJson = BarJson.map(entry.value);
  if (frameJson != null && frameJson.containsKey('values')) {
    return {...frameJson, 'label': frameJson['label'] ?? entry.key};
  }
  return {'label': entry.key, 'values': entry.value};
}

Duration _barRaceTransitionDuration(int frameDuration) {
  return Duration(milliseconds: math.max(1, (frameDuration * 0.8).round()));
}

Map<String, BarRaceMarkerStyle> _barRaceMarkersFromJson(
  Map<String, dynamic> json,
) {
  final markers = <String, BarRaceMarkerStyle>{};

  void merge(Object? value, BarRaceMarkerStyle Function(Object?) parser) {
    final json = BarJson.map(value);
    if (json == null) return;
    json.forEach((key, rawMarker) {
      markers[key.toString()] = parser(rawMarker);
    });
  }

  merge(json['markers'], BarRaceMarkerStyle.fromJson);
  merge(json['icons'], (value) => BarRaceMarkerStyle(text: value?.toString()));
  merge(json['images'], (value) {
    final src = value?.toString();
    if (src == null || src.isEmpty) return const BarRaceMarkerStyle();
    return BarRaceMarkerStyle._looksLikeImageUrl(src)
        ? BarRaceMarkerStyle(imageUrl: src)
        : BarRaceMarkerStyle(imageAsset: src);
  });

  return markers;
}

class BarRaceChartConfig extends BaseChartConfig {
  final List<BarRaceFrame> frames;
  final Map<String, BarRaceMarkerStyle> markers;
  final int frameDuration; // ms per frame
  final bool autoPlay;
  final bool loop;
  final bool showControls;
  final bool showStepControls;
  final bool showProgressIndicator;
  final bool showFrameLabel;
  final int maxBars;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  BarRaceChartConfig({
    required this.frames,
    this.markers = const {},
    this.theme = ChartTheme.light,
    this.frameDuration = 1500,
    this.autoPlay = true,
    this.loop = true,
    this.showControls = true,
    this.showStepControls = true,
    this.showProgressIndicator = true,
    this.showFrameLabel = true,
    this.maxBars = 10,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.barRace, series: const []);

  @override
  Widget buildChart() => BarRaceChartWidget(config: this);

  factory BarRaceChartConfig.fromJson(Map<String, dynamic> j) {
    final frames = _barRaceFramesFromJson(j);
    return BarRaceChartConfig(
      frames: frames,
      markers: _barRaceMarkersFromJson(j),
      frameDuration: BarJson.positiveInt(j['frameDuration'], 1500),
      autoPlay: BarJson.boolOr(j['autoPlay'], true),
      loop: BarJson.boolOr(j['loop'], true),
      showControls: BarJson.boolOr(j['showControls'], true),
      showStepControls: BarJson.boolOr(j['showStepControls'], true),
      showProgressIndicator: BarJson.boolOr(j['showProgressIndicator'], true),
      showFrameLabel: BarJson.boolOr(j['showFrameLabel'], true),
      maxBars: BarJson.positiveInt(j['maxBars'], 10),
      title: BarJson.title(j['title']),
      tooltip: BarJson.tooltip(j['tooltip']),
      legend: BarJson.legend(j['legend']),
      toolbox: BarJson.toolbox(j['toolbox']),
      grid: BarJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'frames': frames.map((frame) => frame.toJson()).toList(),
    'markers': markers.map((label, marker) => MapEntry(label, marker.toJson())),
    'frameDuration': frameDuration,
    'autoPlay': autoPlay,
    'loop': loop,
    'showControls': showControls,
    'showStepControls': showStepControls,
    'showProgressIndicator': showProgressIndicator,
    'showFrameLabel': showFrameLabel,
    'maxBars': maxBars,
  };
}

class BarRaceChartWidget extends StatefulWidget {
  final BarRaceChartConfig config;
  const BarRaceChartWidget({super.key, required this.config});
  @override
  State<BarRaceChartWidget> createState() => _BarRaceState();
}

class _BarRaceState extends State<BarRaceChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _transCtrl;
  late Animation<double> _transAnim;
  late AnimationController _frameTimer;
  int _currentFrame = 0;
  Map<String, double> _fromValues = {};
  Map<String, double> _toValues = {};
  bool _playing = true;
  late String _dataSignature;
  Map<String, ui.Image> _markerImages = {};
  final Map<String, ImageStream> _markerImageStreams = {};
  final Map<String, ImageStreamListener> _markerImageListeners = {};

  BarRaceChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _transCtrl = AnimationController(
      vsync: this,
      duration: _barRaceTransitionDuration(cfg.frameDuration),
    );
    _transAnim = CurvedAnimation(parent: _transCtrl, curve: Curves.easeInOut);
    _transCtrl.addListener(() => setState(() {}));

    _resetRaceState();

    if (cfg.autoPlay && cfg.frames.length > 1) {
      _frameTimer = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: cfg.frameDuration),
      );
      _frameTimer.addStatusListener((s) {
        if (s == AnimationStatus.completed && _playing) _advanceFrame();
      });
      _frameTimer.forward();
    } else {
      _frameTimer = AnimationController(vsync: this, duration: Duration.zero);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMarkerImages();
  }

  @override
  void didUpdateWidget(BarRaceChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _transCtrl.duration = _barRaceTransitionDuration(cfg.frameDuration);
      _frameTimer.duration = Duration(milliseconds: cfg.frameDuration);
      _resetRaceState();
      _syncMarkerImages();
      _transCtrl.forward(from: 0);
      if (_playing && cfg.frames.length > 1) {
        _frameTimer.forward(from: 0);
      } else {
        _frameTimer.stop();
      }
    }
  }

  void _resetRaceState() {
    _currentFrame = 0;
    _playing = cfg.autoPlay;
    if (cfg.frames.isNotEmpty) {
      _toValues = Map.from(cfg.frames[0].values);
      _fromValues = Map.from(_toValues);
    } else {
      _toValues = {};
      _fromValues = {};
    }
  }

  void _advanceFrame() {
    if (cfg.frames.isEmpty) return;
    if (!cfg.loop && _currentFrame >= cfg.frames.length - 1) {
      setState(() => _playing = false);
      _frameTimer.stop();
      return;
    }
    final nextFrame = (_currentFrame + 1) % cfg.frames.length;
    _goToFrame(nextFrame, restartTimer: true);
  }

  void _goToFrame(int index, {bool restartTimer = false}) {
    if (cfg.frames.isEmpty) return;
    final nextFrame = cfg.loop
        ? index % cfg.frames.length
        : index.clamp(0, cfg.frames.length - 1);
    setState(() {
      _fromValues = Map.from(_toValues);
      _toValues = Map.from(cfg.frames[nextFrame].values);
      _currentFrame = nextFrame;
    });
    _transCtrl.forward(from: 0);
    if (_playing && restartTimer && cfg.frames.length > 1) {
      _frameTimer.forward(from: 0);
    }
  }

  void _togglePlaying() {
    setState(() => _playing = !_playing);
    if (_playing && cfg.frames.length > 1) {
      _frameTimer.forward();
    } else {
      _frameTimer.stop();
    }
  }

  void _nextManualFrame() {
    _goToFrame(_currentFrame + 1, restartTimer: _playing);
  }

  void _previousManualFrame() {
    _goToFrame(_currentFrame - 1, restartTimer: _playing);
  }

  void _restartRace() {
    _goToFrame(0, restartTimer: _playing);
  }

  void _syncMarkerImages() {
    _releaseMarkerImageListeners();
    _markerImages = {};

    if (cfg.markers.isEmpty) return;

    final imageConfiguration = createLocalImageConfiguration(context);
    for (final entry in cfg.markers.entries) {
      final marker = entry.value;
      if (!marker.hasImage) continue;

      final ImageProvider provider = marker.imageAsset != null
          ? AssetImage(marker.imageAsset!)
          : NetworkImage(marker.imageUrl!);
      final stream = provider.resolve(imageConfiguration);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (imageInfo, synchronousCall) {
          if (!mounted) return;
          if (synchronousCall) {
            _markerImages = {..._markerImages, entry.key: imageInfo.image};
          } else {
            setState(() {
              _markerImages = {..._markerImages, entry.key: imageInfo.image};
            });
          }
        },
        onError: (Object error, StackTrace? stackTrace) {
          // Marker images are decorative; fall back to text/initial markers.
        },
      );
      stream.addListener(listener);
      _markerImageStreams[entry.key] = stream;
      _markerImageListeners[entry.key] = listener;
    }
  }

  void _releaseMarkerImageListeners() {
    for (final entry in _markerImageStreams.entries) {
      final listener = _markerImageListeners[entry.key];
      if (listener != null) {
        entry.value.removeListener(listener);
      }
    }
    _markerImageStreams.clear();
    _markerImageListeners.clear();
  }

  @override
  void dispose() {
    _releaseMarkerImageListeners();
    _transCtrl.dispose();
    _frameTimer.dispose();
    super.dispose();
  }

  Map<String, double> get _interpolatedValues {
    final t = _transAnim.value;
    final keys = {..._fromValues.keys, ..._toValues.keys};
    return {
      for (final k in keys)
        k:
            (_fromValues[k] ?? 0) +
            ((_toValues[k] ?? 0) - (_fromValues[k] ?? 0)) * t,
    };
  }

  @override
  Widget build(BuildContext context) {
    final vals = _interpolatedValues;
    final sorted = vals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(cfg.maxBars).toList();
    final frameLabel = cfg.frames.isNotEmpty
        ? cfg.frames[_currentFrame].label
        : '';

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
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarRacePainter(
                cfg: cfg,
                entries: top,
                frameLabel: frameLabel,
                markerImages: _markerImages,
                dataSignature: _dataSignature,
              ),
            ),
          ),
        ),
        if (cfg.showControls) _buildControls(frameLabel),
      ],
    );
  }

  Widget _buildControls(String frameLabel) {
    final frameCount = cfg.frames.length;
    final textStyle = cfg.theme.typography.axisLabelStyle.copyWith(
      color: cfg.theme.axisLabelColor,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (cfg.showProgressIndicator && frameCount > 1)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 3,
                value: (_currentFrame + 1) / frameCount,
                color: cfg.theme.palette.colorObjectAt(0),
                backgroundColor: cfg.theme.gridColor.withValues(alpha: 0.3),
              ),
            ),
          Row(
            children: [
              IconButton(
                tooltip: _playing ? 'Pause race' : 'Play race',
                visualDensity: VisualDensity.compact,
                onPressed: _togglePlaying,
                icon: Icon(
                  _playing ? Icons.pause_circle : Icons.play_circle,
                  size: 28,
                  color: cfg.theme.titleColor,
                ),
              ),
              if (cfg.showStepControls) ...[
                IconButton(
                  tooltip: 'Previous frame',
                  visualDensity: VisualDensity.compact,
                  onPressed: frameCount > 1 ? _previousManualFrame : null,
                  icon: Icon(
                    Icons.skip_previous,
                    color: cfg.theme.axisLabelColor,
                  ),
                ),
                IconButton(
                  tooltip: 'Restart race',
                  visualDensity: VisualDensity.compact,
                  onPressed: frameCount > 1 ? _restartRace : null,
                  icon: Icon(Icons.replay, color: cfg.theme.axisLabelColor),
                ),
                IconButton(
                  tooltip: 'Next frame',
                  visualDensity: VisualDensity.compact,
                  onPressed: frameCount > 1 ? _nextManualFrame : null,
                  icon: Icon(Icons.skip_next, color: cfg.theme.axisLabelColor),
                ),
              ],
              if (cfg.showFrameLabel)
                Expanded(
                  child: Text(
                    'Frame: $frameLabel',
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                )
              else
                const Spacer(),
              Text(
                frameCount == 0
                    ? '0 / 0'
                    : '${_currentFrame + 1} / $frameCount',
                style: textStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarRacePainter extends ChartPainterBase {
  final BarRaceChartConfig cfg;
  final List<MapEntry<String, double>> entries;
  final String frameLabel;
  final Map<String, ui.Image> markerImages;
  final String dataSignature;
  _BarRacePainter({
    required this.cfg,
    required this.entries,
    required this.frameLabel,
    required this.markerImages,
    required this.dataSignature,
  }) : super(theme: cfg.theme);

  @override
  bool shouldRepaintChart(covariant _BarRacePainter o) =>
      o.entries != entries ||
      o.frameLabel != frameLabel ||
      o.markerImages != markerImages ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;
    const padL = 8.0, padR = 16.0, padT = 8.0, padB = 16.0;
    const valueW = 52.0;
    final hasMarkers = cfg.markers.isNotEmpty;
    final markerW = hasMarkers ? _maxMarkerSize() + 10 : 0.0;
    final labelW = hasMarkers ? 144.0 : 110.0;
    final labelTextW = math.max(40.0, labelW - markerW);
    final plotW = size.width - padL - padR - labelW - valueW;
    final n = entries.length;
    final rowH = (size.height - padT - padB) / n;
    final barH = rowH * 0.62;
    final maxVal = entries.first.value;

    // Frame watermark
    final wm = textPainterCache.get(
      frameLabel,
      theme.typography.titleStyle.copyWith(
        color: theme.titleColor.withValues(alpha: 0.06),
        fontSize: 56,
        fontWeight: FontWeight.w900,
      ),
    );
    wm.paint(
      canvas,
      Offset(size.width / 2 - wm.width / 2, size.height / 2 - wm.height / 2),
    );

    for (int i = 0; i < n; i++) {
      final e = entries[i];
      final color = theme.palette.colorObjectAt(e.key.hashCode.abs() % 10);
      final cy = padT + (i + 0.5) * rowH;
      final barLen = maxVal > 0 ? (e.value / maxVal) * plotW : 0.0;

      // Bar
      final barRect = Rect.fromLTWH(padL + labelW, cy - barH / 2, barLen, barH);
      _drawRoundedTopRect(
        canvas,
        barRect,
        4,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      if (hasMarkers) {
        final markerSize = cfg.markers[e.key]?.size ?? _maxMarkerSize();
        final markerRect = Rect.fromCenter(
          center: Offset(padL + markerW / 2, cy),
          width: markerSize,
          height: markerSize,
        );
        _drawMarker(canvas, e.key, markerRect, color);
      }

      // Label
      final lbl = textPainterCache.get(
        e.key,
        theme.typography.axisLabelStyle.copyWith(
          color: theme.titleColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
        maxWidth: labelTextW - 8,
        align: TextAlign.right,
      );
      lbl.paint(
        canvas,
        Offset(
          padL + markerW + labelTextW - lbl.width - 6,
          cy - lbl.height / 2,
        ),
      );

      // Value
      final fmtVal = e.value >= 1e9
          ? '${(e.value / 1e9).toStringAsFixed(1)}B'
          : e.value >= 1e6
          ? '${(e.value / 1e6).toStringAsFixed(1)}M'
          : e.value >= 1e3
          ? '${(e.value / 1e3).toStringAsFixed(1)}K'
          : e.value.toStringAsFixed(0);
      final vtp = textPainterCache.get(
        fmtVal,
        theme.typography.axisLabelStyle.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      vtp.paint(
        canvas,
        Offset(padL + labelW + barLen + 6, cy - vtp.height / 2),
      );
    }
  }

  double _maxMarkerSize() {
    if (cfg.markers.isEmpty) return 0;
    return cfg.markers.values.fold<double>(
      0,
      (maxSize, marker) => math.max(maxSize, marker.size),
    );
  }

  void _drawMarker(
    Canvas canvas,
    String label,
    Rect rect,
    Color fallbackColor,
  ) {
    final marker = cfg.markers[label];
    if (marker == null) return;

    final radius = math.min(marker.borderRadius, rect.shortestSide / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final backgroundColor = _safeColor(
      marker.backgroundColor,
      fallbackColor.withValues(alpha: 0.16),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    if (marker.borderWidth > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = _safeColor(marker.borderColor, fallbackColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = marker.borderWidth
          ..isAntiAlias = true,
      );
    }

    final contentRect = rect.deflate(marker.padding);
    final image = markerImages[label];
    if (image != null) {
      final inputSize = Size(image.width.toDouble(), image.height.toDouble());
      final fitted = applyBoxFit(BoxFit.cover, inputSize, contentRect.size);
      final src = Alignment.center.inscribe(
        fitted.source,
        Offset.zero & inputSize,
      );
      final dst = Alignment.center.inscribe(fitted.destination, contentRect);
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(contentRect, Radius.circular(radius)),
      );
      canvas.drawImageRect(image, src, dst, Paint()..isAntiAlias = true);
      canvas.restore();
      return;
    }

    final markerText = (marker.text?.isNotEmpty ?? false)
        ? marker.text!
        : (label.isEmpty ? '?' : label.substring(0, 1));
    final tp = textPainterCache.get(
      markerText,
      theme.typography.axisLabelStyle.copyWith(
        color: _safeColor(marker.borderColor, fallbackColor),
        fontSize: contentRect.height * 0.52,
        fontWeight: FontWeight.w800,
      ),
      maxWidth: contentRect.width,
      align: TextAlign.center,
    );
    tp.paint(
      canvas,
      Offset(
        contentRect.center.dx - tp.width / 2,
        contentRect.center.dy - tp.height / 2,
      ),
    );
  }

  Color _safeColor(String? value, Color fallback) {
    if (value == null || value.isEmpty) return fallback;
    try {
      return colorCache.resolve(value);
    } catch (_) {
      return fallback;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. BAR WITH GRADIENT + CLICK SELECTION
// ═══════════════════════════════════════════════════════════════════════════
/// Each bar is filled with a vertical gradient. Clicking a bar selects it
/// (highlighted with a brighter gradient + border). Fires [onBarTap].
///
/// JSON:
/// ```json
/// { "type": "barGradient",
///   "categories": ["Q1","Q2","Q3","Q4"],
///   "gradientStart": "#42A5F5", "gradientEnd": "#0D47A1",
///   "series": [{ "data": [120,200,150,80] }] }
/// ```
class BarGradientChartConfig extends BaseChartConfig {
  final List<String> categories;
  final String gradientStart;
  final String gradientEnd;
  final double barWidthRatio;
  final bool showValues;
  final void Function(int index, double value)? onBarTap;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  BarGradientChartConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.gradientStart = '#42A5F5',
    this.gradientEnd = '#0D47A1',
    this.barWidthRatio = 0.6,
    this.showValues = true,
    this.onBarTap,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.barGradient);

  @override
  Widget buildChart() => BarGradientWidget(config: this);

  factory BarGradientChartConfig.fromJson(Map<String, dynamic> j) {
    final cats = BarJson.stringList(
      j['categories'] ?? j['labels'] ?? j['xLabels'],
    );
    final s = _seriesFromJson(j['series']);
    return BarGradientChartConfig(
      categories: cats,
      series: s,
      gradientStart: BarJson.string(j['gradientStart']) ?? '#42A5F5',
      gradientEnd: BarJson.string(j['gradientEnd']) ?? '#0D47A1',
      barWidthRatio: BarJson.ratio(j['barWidthRatio'], 0.6),
      showValues: BarJson.boolOr(j['showValues'], true),
      title: BarJson.title(j['title']),
      tooltip: BarJson.tooltip(j['tooltip']),
      legend: BarJson.legend(j['legend']),
      toolbox: BarJson.toolbox(j['toolbox']),
      grid: BarJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'gradientStart': gradientStart,
    'gradientEnd': gradientEnd,
    'barWidthRatio': barWidthRatio,
    'showValues': showValues,
  };
}

class BarGradientWidget extends StatefulWidget {
  final BarGradientChartConfig config;
  const BarGradientWidget({super.key, required this.config});
  @override
  State<BarGradientWidget> createState() => _BarGradientState();
}

class _BarGradientState extends State<BarGradientWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _selected = -1;
  late String _dataSignature;
  BarGradientChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(BarGradientWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _selected = -1;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
              final n = cfg.categories.length;
              final slotW = n > 0 ? (sz.width - 56.0) / n : 1.0;
              return GestureDetector(
                onTapDown: (d) {
                  final idx = ((d.localPosition.dx - 40) / slotW).floor().clamp(
                    0,
                    n - 1,
                  );
                  setState(() => _selected = _selected == idx ? -1 : idx);
                  final series = cfg.series.firstOrNull;
                  if (series != null) {
                    final value = _seriesValueAt(series, idx);
                    if (value != null) cfg.onBarTap?.call(idx, value);
                  }
                },
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _BarGradientPainter(
                      cfg: cfg,
                      progress: _anim.value,
                      selected: _selected,
                      dataSignature: _dataSignature,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BarGradientPainter extends ChartPainterBase {
  final BarGradientChartConfig cfg;
  final double progress;
  final int selected;
  final String dataSignature;
  _BarGradientPainter({
    required this.cfg,
    required this.progress,
    required this.selected,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _BarGradientPainter o) =>
      o.progress != progress ||
      o.selected != selected ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = cfg.categories.length;
    if (n == 0 || cfg.series.isEmpty) return;
    const padL = 48.0, padR = 12.0, padT = 24.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final slotW = plotW / n;
    final barW = slotW * cfg.barWidthRatio;

    Color cStart, cEnd;
    try {
      cStart = colorCache.resolve(cfg.gradientStart);
    } catch (_) {
      cStart = Colors.blue;
    }
    try {
      cEnd = colorCache.resolve(cfg.gradientEnd);
    } catch (_) {
      cEnd = Colors.indigo;
    }

    double maxVal = 0;
    for (final s in cfg.series) {
      final data = s.data ?? const <dynamic>[];
      for (var index = 0; index < data.length; index++) {
        final d = _seriesValueAt(s, index);
        if (d == null) continue;
        if (d > maxVal) {
          maxVal = d;
        }
      }
    }
    if (maxVal == 0) return;
    maxVal *= 1.1;

    double toY(double v) => padT + plotH * (1 - v / maxVal * progress);

    final ticks = ChartDataProcessor.niceYTicks(0, maxVal / 1.1);
    for (final t in ticks) {
      final y = padT + plotH * (1 - t / maxVal);
      canvas.drawLine(
        Offset(padL, y),
        Offset(padL + plotW, y),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final tp = textPainterCache.get(
        t.toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
        align: TextAlign.right,
        maxWidth: 40,
      );
      tp.paint(canvas, Offset(padL - tp.width - 4, y - tp.height / 2));
    }

    for (int ci = 0; ci < n; ci++) {
      final val = _seriesValueAt(cfg.series.first, ci) ?? 0;
      final cx = padL + (ci + 0.5) * slotW;
      final barX = cx - barW / 2;
      final y = toY(val);
      final isSel = ci == selected;

      final rect = Rect.fromLTWH(barX, y, barW, padT + plotH - y);
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isSel
            ? [
                Color.lerp(cStart, Colors.white, 0.3)!,
                Color.lerp(cEnd, Colors.white, 0.1)!,
              ]
            : [cStart, cEnd],
      ).createShader(rect);

      _drawRoundedTopRect(
        canvas,
        rect,
        4,
        Paint()
          ..shader = gradient
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      if (isSel) {
        _drawRoundedTopRect(
          canvas,
          rect,
          4,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..isAntiAlias = true,
        );
      }

      if (cfg.showValues) {
        final tp = textPainterCache.get(
          val.toStringAsFixed(0),
          (theme.typography.dataLabelStyle ?? theme.typography.axisLabelStyle)
              .copyWith(
                color: isSel ? cEnd : theme.titleColor,
                fontSize: 9.5,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
        );
        tp.paint(canvas, Offset(cx - tp.width / 2, y - tp.height - 2));
      }

      final lbl = textPainterCache.get(
        cfg.categories[ci],
        theme.typography.axisLabelStyle.copyWith(
          color: isSel ? cEnd : theme.axisLabelColor,
          fontSize: 9.5,
        ),
      );
      lbl.paint(canvas, Offset(cx - lbl.width / 2, padT + plotH + 4));
    }

    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. BAR WITH LABEL ROTATION
// ═══════════════════════════════════════════════════════════════════════════
/// Standard bar chart where X-axis category labels are rendered at a
/// configurable rotation angle (default 45°). Useful for long labels.
///
/// JSON:
/// ```json
/// { "type": "barLabelRotation", "labelRotation": 45,
///   "categories": ["January","February","March","April"],
///   "series": [{ "name": "Revenue", "data": [820,932,901,934] }] }
/// ```
class BarLabelRotationConfig extends BaseChartConfig {
  final List<String> categories;
  final double labelRotation; // degrees, 0–90
  final double barWidthRatio;
  final bool showValues;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  BarLabelRotationConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.labelRotation = 45.0,
    this.barWidthRatio = 0.55,
    this.showValues = false,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.barLabelRotation);

  @override
  Widget buildChart() => BarLabelRotationWidget(config: this);

  factory BarLabelRotationConfig.fromJson(Map<String, dynamic> j) {
    final cats = BarJson.stringList(
      j['categories'] ?? j['labels'] ?? j['xLabels'],
    );
    final s = _seriesFromJson(j['series']);
    return BarLabelRotationConfig(
      categories: cats,
      series: s,
      labelRotation: _labelRotation(j['labelRotation']),
      barWidthRatio: BarJson.ratio(j['barWidthRatio'], 0.55),
      showValues: BarJson.boolOr(j['showValues'], false),
      title: BarJson.title(j['title']),
      tooltip: BarJson.tooltip(j['tooltip']),
      legend: BarJson.legend(j['legend']),
      toolbox: BarJson.toolbox(j['toolbox']),
      grid: BarJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'labelRotation': labelRotation,
    'barWidthRatio': barWidthRatio,
    'showValues': showValues,
  };
}

class BarLabelRotationWidget extends StatefulWidget {
  final BarLabelRotationConfig config;
  const BarLabelRotationWidget({super.key, required this.config});
  @override
  State<BarLabelRotationWidget> createState() => _BarLabelRotState();
}

class _BarLabelRotState extends State<BarLabelRotationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  BarLabelRotationConfig get cfg => widget.config;

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
  void didUpdateWidget(BarLabelRotationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _ctrl.forward(from: 0);
    }
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
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarRotLblPainter(
              cfg: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
    ],
  );
}

class _BarRotLblPainter extends ChartPainterBase {
  final BarLabelRotationConfig cfg;
  final double progress;
  final String dataSignature;
  _BarRotLblPainter({
    required this.cfg,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _BarRotLblPainter o) =>
      o.progress != progress || o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = cfg.categories.length;
    if (n == 0 || cfg.series.isEmpty) return;
    final angle = cfg.labelRotation * math.pi / 180;
    // Estimate bottom padding from rotated label height
    final approxLabelH = (10.0 * math.sin(angle) * 8 + 20).clamp(24.0, 80.0);
    const padL = 48.0, padR = 12.0, padT = 24.0;
    final padB = approxLabelH + 6;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final slotW = plotW / n;
    final barW = slotW * cfg.barWidthRatio;

    double maxVal = 0;
    for (final s in cfg.series) {
      final data = s.data ?? const <dynamic>[];
      for (var index = 0; index < data.length; index++) {
        final d = _seriesValueAt(s, index);
        if (d == null) continue;
        if (d > maxVal) {
          maxVal = d;
        }
      }
    }
    if (maxVal == 0) return;
    maxVal *= 1.1;

    double toY(double v) => padT + plotH * (1 - v / maxVal * progress);

    final ticks = ChartDataProcessor.niceYTicks(0, maxVal / 1.1);
    for (final t in ticks) {
      final y = padT + plotH * (1 - t / maxVal);
      canvas.drawLine(
        Offset(padL, y),
        Offset(padL + plotW, y),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final tp = textPainterCache.get(
        t.toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
        align: TextAlign.right,
        maxWidth: 40,
      );
      tp.paint(canvas, Offset(padL - tp.width - 4, y - tp.height / 2));
    }

    final nseries = cfg.series.length;
    for (int ci = 0; ci < n; ci++) {
      final cx = padL + (ci + 0.5) * slotW;

      for (int si = 0; si < nseries; si++) {
        final s = cfg.series[si];
        final d = s.data;
        if (d == null || ci >= d.length) continue;
        final color = theme.seriesColor(si, explicitColor: s.color);
        final val = _seriesValueAt(s, ci);
        if (val == null) continue;
        final groupBarW = barW / nseries;
        final barX = cx - barW / 2 + si * groupBarW;
        final y = toY(val);
        _drawRoundedTopRect(
          canvas,
          Rect.fromLTWH(barX, y, groupBarW - 2, padT + plotH - y),
          3,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
      }

      // Rotated label
      final lbl = textPainterCache.get(
        cfg.categories[ci],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9.5,
        ),
      );
      canvas.save();
      canvas.translate(cx, padT + plotH + 4);
      canvas.rotate(angle);
      lbl.paint(canvas, Offset(0, 0));
      canvas.restore();
    }

    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. STACKED BAR WITH ROUNDED CORNERS
// ═══════════════════════════════════════════════════════════════════════════
/// Stacked column chart where only the topmost segment has rounded corners.
///
/// JSON:
/// ```json
/// { "type": "barRounded", "cornerRadius": 6,
///   "categories": ["Jan","Feb","Mar"],
///   "series": [
///     {"name":"A","data":[100,130,90]},
///     {"name":"B","data":[80,60,100]},
///     {"name":"C","data":[50,90,70]}
///   ]}
/// ```
class BarRoundedStackedConfig extends BaseChartConfig {
  final List<String> categories;
  final double cornerRadius;
  final bool showValues;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  BarRoundedStackedConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.cornerRadius = 6.0,
    this.showValues = false,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.barRounded);

  @override
  Widget buildChart() => _BarRoundedWidget(config: this);

  factory BarRoundedStackedConfig.fromJson(Map<String, dynamic> j) {
    final cats = BarJson.stringList(
      j['categories'] ?? j['labels'] ?? j['xLabels'],
    );
    final s = _seriesFromJson(j['series']);
    return BarRoundedStackedConfig(
      categories: cats,
      series: s,
      cornerRadius: BarJson.nonNegativeDouble(j['cornerRadius'], 6.0),
      showValues: BarJson.boolOr(j['showValues'], false),
      title: BarJson.title(j['title']),
      tooltip: BarJson.tooltip(j['tooltip']),
      legend: BarJson.legend(j['legend']),
      toolbox: BarJson.toolbox(j['toolbox']),
      grid: BarJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'cornerRadius': cornerRadius,
    'showValues': showValues,
  };
}

class _BarRoundedWidget extends StatefulWidget {
  final BarRoundedStackedConfig config;
  const _BarRoundedWidget({required this.config});
  @override
  State<_BarRoundedWidget> createState() => _BarRoundedState();
}

class _BarRoundedState extends State<_BarRoundedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  int _hovIdx = -1;
  BarRoundedStackedConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _BarRoundedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _hovIdx = -1;
      _ctrl.forward(from: 0);
    }
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
        child: MouseRegion(
          onHover: (e) {
            final n = cfg.categories.length;
            if (n == 0) return;
            setState(
              () => _hovIdx =
                  ((e.localPosition.dx - 48) /
                          ((MediaQuery.of(context).size.width - 60) / n))
                      .floor()
                      .clamp(0, n - 1),
            );
          },
          onExit: (_) => setState(() => _hovIdx = -1),
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _BarRoundedPainter(
                cfg: cfg,
                progress: _anim.value,
                hovIdx: _hovIdx,
                dataSignature: _dataSignature,
              ),
            ),
          ),
        ),
      ),
      _buildLegend(),
    ],
  );

  Widget _buildLegend() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      spacing: 12,
      alignment: WrapAlignment.center,
      children: cfg.series.asMap().entries.map((e) {
        final color = cfg.theme.seriesColor(
          e.key,
          explicitColor: e.value.color,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: 4),
            Text(
              e.value.name ?? 'S${e.key + 1}',
              style: cfg.theme.typography.legendStyle.copyWith(
                color: cfg.theme.legendTextColor,
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );
}

class _BarRoundedPainter extends ChartPainterBase {
  final BarRoundedStackedConfig cfg;
  final double progress;
  final int hovIdx;
  final String dataSignature;
  _BarRoundedPainter({
    required this.cfg,
    required this.progress,
    required this.hovIdx,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _BarRoundedPainter o) =>
      o.progress != progress ||
      o.hovIdx != hovIdx ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = cfg.categories.length;
    final ns = cfg.series.length;
    if (n == 0 || ns == 0) return;
    const padL = 48.0, padR = 12.0, padT = 24.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final slotW = plotW / n;
    const barWRatio = 0.6;
    final barW = slotW * barWRatio;

    // Total stacked max
    double maxTotal = 0;
    for (int ci = 0; ci < n; ci++) {
      final total = _positiveStackTotalAt(cfg.series, ci);
      if (total > maxTotal) maxTotal = total;
    }
    if (maxTotal == 0) return;
    maxTotal *= 1.1;

    final ticks = ChartDataProcessor.niceYTicks(0, maxTotal / 1.1);
    for (final t in ticks) {
      final y = padT + plotH * (1 - t / maxTotal);
      canvas.drawLine(
        Offset(padL, y),
        Offset(padL + plotW, y),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final tp = textPainterCache.get(
        t.toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
        align: TextAlign.right,
        maxWidth: 42,
      );
      tp.paint(canvas, Offset(padL - tp.width - 4, y - tp.height / 2));
    }

    for (int ci = 0; ci < n; ci++) {
      final cx = padL + (ci + 0.5) * slotW;
      final barX = cx - barW / 2;
      double stackY = padT + plotH; // bottom
      final isHov = ci == hovIdx;
      final topIndex = _lastPositiveSeriesIndexAt(cfg.series, ci);

      for (int si = 0; si < ns; si++) {
        final s = cfg.series[si];
        final val = _seriesValueAt(s, ci);
        if (val == null || val <= 0) continue;
        final segH = (val / maxTotal) * plotH * progress;
        final color = theme
            .seriesColor(si, explicitColor: s.color)
            .withValues(alpha: isHov ? 0.9 : 1.0);

        final isTop = si == topIndex;
        final rect = Rect.fromLTWH(barX, stackY - segH, barW, segH);

        if (isTop) {
          _drawRoundedTopRect(
            canvas,
            rect,
            cfg.cornerRadius,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill
              ..isAntiAlias = true,
          );
        } else {
          canvas.drawRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill
              ..isAntiAlias = true,
          );
        }

        if (cfg.showValues && segH > 14) {
          final tp = textPainterCache.get(
            val.toStringAsFixed(0),
            (theme.typography.dataLabelStyle ?? theme.typography.axisLabelStyle)
                .copyWith(color: Colors.white, fontSize: 8.5),
          );
          tp.paint(
            canvas,
            Offset(cx - tp.width / 2, stackY - segH + (segH - tp.height) / 2),
          );
        }

        stackY -= segH;
      }

      final lbl = textPainterCache.get(
        cfg.categories[ci],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9.5,
        ),
      );
      lbl.paint(canvas, Offset(cx - lbl.width / 2, padT + plotH + 4));
    }

    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. 100% NORMALIZED STACKED BAR
// ═══════════════════════════════════════════════════════════════════════════
/// All bars normalised to 100 %. Y-axis shows percentages.
///
/// JSON:
/// ```json
/// { "type": "barNormalized",
///   "categories": ["Jan","Feb","Mar"],
///   "series": [
///     {"name":"A","data":[100,130,90]},
///     {"name":"B","data":[80, 60,100]},
///     {"name":"C","data":[50, 90, 70]}
///   ]}
/// ```
class BarNormalizedConfig extends BaseChartConfig {
  final List<String> categories;
  final bool showPercentLabels;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  BarNormalizedConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.showPercentLabels = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.barNormalized);

  @override
  Widget buildChart() => _BarNormalizedWidget(config: this);

  factory BarNormalizedConfig.fromJson(Map<String, dynamic> j) {
    final cats = BarJson.stringList(
      j['categories'] ?? j['labels'] ?? j['xLabels'],
    );
    final s = _seriesFromJson(j['series']);
    return BarNormalizedConfig(
      categories: cats,
      series: s,
      showPercentLabels: BarJson.boolOr(j['showPercentLabels'], true),
      title: BarJson.title(j['title']),
      tooltip: BarJson.tooltip(j['tooltip']),
      legend: BarJson.legend(j['legend']),
      toolbox: BarJson.toolbox(j['toolbox']),
      grid: BarJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'showPercentLabels': showPercentLabels,
  };
}

class _BarNormalizedWidget extends StatefulWidget {
  final BarNormalizedConfig config;
  const _BarNormalizedWidget({required this.config});
  @override
  State<_BarNormalizedWidget> createState() => _BarNormState();
}

class _BarNormState extends State<_BarNormalizedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  BarNormalizedConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _BarNormalizedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _ctrl.forward(from: 0);
    }
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
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _BarNormPainter(
              cfg: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
      _legend(),
    ],
  );

  Widget _legend() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Wrap(
      spacing: 12,
      alignment: WrapAlignment.center,
      children: cfg.series.asMap().entries.map((e) {
        final color = cfg.theme.seriesColor(
          e.key,
          explicitColor: e.value.color,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: 4),
            Text(
              e.value.name ?? 'S${e.key + 1}',
              style: cfg.theme.typography.legendStyle.copyWith(
                color: cfg.theme.legendTextColor,
              ),
            ),
          ],
        );
      }).toList(),
    ),
  );
}

class _BarNormPainter extends ChartPainterBase {
  final BarNormalizedConfig cfg;
  final double progress;
  final String dataSignature;
  _BarNormPainter({
    required this.cfg,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _BarNormPainter o) =>
      o.progress != progress || o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = cfg.categories.length;
    final ns = cfg.series.length;
    if (n == 0 || ns == 0) return;
    const padL = 48.0, padR = 12.0, padT = 24.0, padB = 28.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final slotW = plotW / n;
    final barW = slotW * 0.6;

    // Y ticks 0 – 100 %
    for (int pct = 0; pct <= 100; pct += 20) {
      final y = padT + plotH * (1 - pct / 100.0);
      canvas.drawLine(
        Offset(padL, y),
        Offset(padL + plotW, y),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final tp = textPainterCache.get(
        '$pct%',
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
        align: TextAlign.right,
        maxWidth: 38,
      );
      tp.paint(canvas, Offset(padL - tp.width - 4, y - tp.height / 2));
    }

    for (int ci = 0; ci < n; ci++) {
      // Compute totals
      final total = _positiveStackTotalAt(cfg.series, ci);
      if (total == 0) continue;

      final cx = padL + (ci + 0.5) * slotW;
      final barX = cx - barW / 2;
      double stackY = padT + plotH;
      final topIndex = _lastPositiveSeriesIndexAt(cfg.series, ci);

      for (int si = 0; si < ns; si++) {
        final s = cfg.series[si];
        final val = _seriesValueAt(s, ci);
        if (val == null || val <= 0) continue;
        final pct = val / total;
        final segH = pct * plotH * progress;
        final color = theme.seriesColor(si, explicitColor: s.color);
        final isTop = si == topIndex;
        final rect = Rect.fromLTWH(barX, stackY - segH, barW, segH);
        if (isTop) {
          _drawRoundedTopRect(
            canvas,
            rect,
            4,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill
              ..isAntiAlias = true,
          );
        } else {
          canvas.drawRect(
            rect,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill
              ..isAntiAlias = true,
          );
        }

        if (cfg.showPercentLabels && segH > 16) {
          final tp = textPainterCache.get(
            '${(pct * 100).toStringAsFixed(0)}%',
            (theme.typography.dataLabelStyle ?? theme.typography.axisLabelStyle)
                .copyWith(color: Colors.white, fontSize: 8.5),
          );
          tp.paint(
            canvas,
            Offset(cx - tp.width / 2, stackY - segH + (segH - tp.height) / 2),
          );
        }
        stackY -= segH;
      }

      final lbl = textPainterCache.get(
        cfg.categories[ci],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9.5,
        ),
      );
      lbl.paint(canvas, Offset(cx - lbl.width / 2, padT + plotH + 4));
    }

    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(Offset(padL, padT), Offset(padL, padT + plotH), axisPaint);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 7. HORIZONTAL BAR WITH NEGATIVE VALUES
// ═══════════════════════════════════════════════════════════════════════════
/// Horizontal diverging bar chart — bars extend left for negative,
/// right for positive values with a shared zero baseline.
///
/// JSON:
/// ```json
/// { "type": "negativeBar",
///   "categories": ["Profit","Revenue","Costs","Growth"],
///   "series": [
///     {"name":"2024","data":[120,-80,200,-30]}
///   ]}
/// ```
class NegativeBarConfig extends BaseChartConfig {
  final List<String> categories;
  final bool showValues;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  NegativeBarConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.showValues = true,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.negativeBar);

  @override
  Widget buildChart() => _NegativeBarWidget(config: this);

  factory NegativeBarConfig.fromJson(Map<String, dynamic> j) {
    return NegativeBarConfig(
      categories: BarJson.stringList(
        j['categories'] ?? j['labels'] ?? j['xLabels'],
      ),
      series: _seriesFromJson(j['series']),
      showValues: BarJson.boolOr(j['showValues'], true),
      title: BarJson.title(j['title']),
      tooltip: BarJson.tooltip(j['tooltip']),
      legend: BarJson.legend(j['legend']),
      toolbox: BarJson.toolbox(j['toolbox']),
      grid: BarJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'showValues': showValues,
  };
}

class _NegativeBarWidget extends StatefulWidget {
  final NegativeBarConfig config;
  const _NegativeBarWidget({required this.config});
  @override
  State<_NegativeBarWidget> createState() => _NegBarState();
}

class _NegBarState extends State<_NegativeBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  NegativeBarConfig get cfg => widget.config;

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
  void didUpdateWidget(covariant _NegativeBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _ctrl.forward(from: 0);
    }
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
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _NegBarPainter(
              cfg: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
    ],
  );
}

class _NegBarPainter extends ChartPainterBase {
  final NegativeBarConfig cfg;
  final double progress;
  final String dataSignature;
  _NegBarPainter({
    required this.cfg,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _NegBarPainter o) =>
      o.progress != progress || o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = cfg.categories.length;
    if (n == 0 || cfg.series.isEmpty) return;
    const padL = 90.0, padR = 24.0, padT = 16.0, padB = 24.0;
    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;
    final rowH = plotH / n;
    final barH = rowH * 0.55;

    // X range
    double minVal = 0, maxVal = 0;
    for (final s in cfg.series) {
      for (final v in s.data ?? []) {
        final d = BarJson.doubleOrNull(v);
        if (d == null) continue;
        if (d < minVal) {
          minVal = d;
        }
        if (d > maxVal) {
          maxVal = d;
        }
      }
    }
    final absMax = math.max(minVal.abs(), maxVal.abs()) * 1.15;
    if (absMax == 0) return;

    // Zero line X
    final zeroX =
        padL +
        plotW *
            (minVal.abs() / (minVal.abs() + maxVal.abs())).clamp(0.05, 0.95);

    double toX(double v) => zeroX + (v / absMax) * (plotW * 0.5) * progress;

    // Grid lines
    final ticks = ChartDataProcessor.niceYTicks(minVal, maxVal);
    for (final t in ticks) {
      final x = toX(t);
      if (x < padL || x > padL + plotW) continue;
      canvas.drawLine(
        Offset(x, padT),
        Offset(x, padT + plotH),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final tp = textPainterCache.get(
        t.toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 8.5,
        ),
      );
      tp.paint(canvas, Offset(x - tp.width / 2, padT + plotH + 3));
    }

    // Zero line
    canvas.drawLine(
      Offset(zeroX, padT - 4),
      Offset(zeroX, padT + plotH),
      paintCache.stroke(theme.axisColor, 1.2),
    );

    final ns = cfg.series.length;
    for (int ci = 0; ci < n; ci++) {
      final cy = padT + (ci + 0.5) * rowH;

      // Label
      final lbl = textPainterCache.get(
        cfg.categories[ci],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9.5,
        ),
        maxWidth: padL - 8,
        align: TextAlign.right,
      );
      lbl.paint(canvas, Offset(padL - lbl.width - 6, cy - lbl.height / 2));

      for (int si = 0; si < ns; si++) {
        final s = cfg.series[si];
        final val = _seriesValueAt(s, ci);
        if (val == null) continue;
        final isNeg = val < 0;
        final color = isNeg
            ? const Color(0xFFEF5350)
            : theme.seriesColor(si, explicitColor: s.color);

        final bH = barH / ns;
        final bY = cy - barH / 2 + si * bH;
        final x1 = toX(val);
        final left = isNeg ? x1 : zeroX;
        final right = isNeg ? zeroX : x1;

        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, bY, (right - left).abs(), bH - 2),
            topRight: Radius.circular(isNeg ? 0 : 3),
            bottomRight: Radius.circular(isNeg ? 0 : 3),
            topLeft: Radius.circular(isNeg ? 3 : 0),
            bottomLeft: Radius.circular(isNeg ? 3 : 0),
          ),
          Paint()
            ..color = color
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );

        if (cfg.showValues) {
          final vtp = textPainterCache.get(
            val.toStringAsFixed(0),
            (theme.typography.dataLabelStyle ?? theme.typography.axisLabelStyle)
                .copyWith(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
          );
          final vx = isNeg ? x1 - vtp.width - 4 : x1 + 4;
          vtp.paint(canvas, Offset(vx, bY + (bH - vtp.height) / 2));
        }
      }
    }

    canvas.drawLine(
      Offset(padL, padT + plotH),
      Offset(padL + plotW, padT + plotH),
      axisPaint,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 8. TANGENTIAL POLAR BAR LABELS
// ═══════════════════════════════════════════════════════════════════════════
/// Polar bar chart where category labels are rotated tangentially (90°
/// offset from the radial direction) so they read along the arc.
///
/// JSON:
/// ```json
/// { "type": "tangentialPolarBar",
///   "categories": ["Jan","Feb","Mar","Apr","May","Jun"],
///   "series": [{ "data": [120,200,150,80,70,110] }] }
/// ```
class TangentialPolarBarConfig extends BaseChartConfig {
  final List<String> categories;
  final bool showValues;
  final double innerRadius;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  TangentialPolarBarConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.showValues = true,
    this.innerRadius = 0.3,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.tangentialPolarBar);

  @override
  Widget buildChart() => _TangentialPolarWidget(config: this);

  factory TangentialPolarBarConfig.fromJson(Map<String, dynamic> j) {
    return TangentialPolarBarConfig(
      categories: BarJson.stringList(
        j['categories'] ?? j['labels'] ?? j['xLabels'],
      ),
      series: _seriesFromJson(j['series']),
      showValues: BarJson.boolOr(j['showValues'], true),
      innerRadius: _innerRadius(j['innerRadius']),
      title: BarJson.title(j['title']),
      tooltip: BarJson.tooltip(j['tooltip']),
      legend: BarJson.legend(j['legend']),
      toolbox: BarJson.toolbox(j['toolbox']),
      grid: BarJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'showValues': showValues,
    'innerRadius': innerRadius,
  };
}

class _TangentialPolarWidget extends StatefulWidget {
  final TangentialPolarBarConfig config;
  const _TangentialPolarWidget({required this.config});
  @override
  State<_TangentialPolarWidget> createState() => _TangPolState();
}

class _TangPolState extends State<_TangentialPolarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  TangentialPolarBarConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _TangentialPolarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _ctrl.forward(from: 0);
    }
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
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _TangPolPainter(
              cfg: cfg,
              progress: _anim.value,
              dataSignature: _dataSignature,
            ),
          ),
        ),
      ),
    ],
  );
}

class _TangPolPainter extends ChartPainterBase {
  final TangentialPolarBarConfig cfg;
  final double progress;
  final String dataSignature;
  _TangPolPainter({
    required this.cfg,
    required this.progress,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _TangPolPainter o) =>
      o.progress != progress || o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = cfg.categories.length;
    if (n == 0 || cfg.series.isEmpty) return;
    final cx = size.width / 2, cy = size.height / 2;
    final outerR = math.min(cx, cy) * 0.78;
    if (outerR <= 0) return;
    final innerR = outerR * cfg.innerRadius;
    const pad = 20.0;

    double maxVal = 0;
    for (final s in cfg.series) {
      for (final v in s.data ?? []) {
        final d = BarJson.doubleOrNull(v);
        if (d == null) continue;
        if (d > maxVal) {
          maxVal = d;
        }
      }
    }
    if (maxVal == 0) return;

    final sliceAngle = 2 * math.pi / n;
    final startOffset = -math.pi / 2;

    for (int i = 0; i < n; i++) {
      final rawValue = _seriesValueAt(cfg.series.first, i);
      final val = rawValue == null || rawValue < 0 ? 0.0 : rawValue;
      final color = theme.seriesColor(i, explicitColor: cfg.series.first.color);
      final availableR = math.max(0.0, outerR - innerR - pad);
      final barR = innerR + (availableR * val / maxVal * progress);
      final startAngle = startOffset + i * sliceAngle + sliceAngle * 0.05;
      final sweepAngle = sliceAngle * 0.9;

      final path = Path()
        ..moveTo(
          cx + innerR * math.cos(startAngle),
          cy + innerR * math.sin(startAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
          startAngle,
          sweepAngle,
          false,
        )
        ..lineTo(
          cx + barR * math.cos(startAngle + sweepAngle),
          cy + barR * math.sin(startAngle + sweepAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: barR),
          startAngle + sweepAngle,
          -sweepAngle,
          false,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      // Tangential label at outer edge, rotated 90° from radial
      final midAngle = startAngle + sweepAngle / 2;
      final labelR = barR + 14;
      final lx = cx + labelR * math.cos(midAngle);
      final ly = cy + labelR * math.sin(midAngle);
      final tp = textPainterCache.get(
        cfg.categories[i],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9.5,
        ),
      );
      canvas.save();
      canvas.translate(lx, ly);
      // tangential = radial + 90°
      double rot = midAngle + math.pi / 2;
      if (rot > math.pi / 2 && rot < 3 * math.pi / 2) rot += math.pi;
      canvas.rotate(rot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 9. BRUSH SELECT ON BAR CHART
// ═══════════════════════════════════════════════════════════════════════════
/// Bar chart with a drag-to-select horizontal brush overlay.
/// Selected bars are highlighted; [onBrushChange] fires with selected indices.
///
/// JSON:
/// ```json
/// { "type": "barBrush",
///   "categories": ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug"],
///   "series": [{ "data": [120,200,150,80,70,110,130,90] }] }
/// ```
class BarBrushConfig extends BaseChartConfig {
  final List<String> categories;
  final bool showValues;
  final void Function(int startIdx, int endIdx)? onBrushChange;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;

  BarBrushConfig({
    required this.categories,
    required super.series,
    this.theme = ChartTheme.light,
    this.showValues = false,
    this.onBrushChange,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.barBrush);

  @override
  Widget buildChart() => BarBrushWidget(config: this);

  factory BarBrushConfig.fromJson(Map<String, dynamic> j) {
    return BarBrushConfig(
      categories: BarJson.stringList(
        j['categories'] ?? j['labels'] ?? j['xLabels'],
      ),
      series: _seriesFromJson(j['series']),
      showValues: BarJson.boolOr(j['showValues'], false),
      title: BarJson.title(j['title']),
      tooltip: BarJson.tooltip(j['tooltip']),
      legend: BarJson.legend(j['legend']),
      toolbox: BarJson.toolbox(j['toolbox']),
      grid: BarJson.grid(j['grid']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'categories': categories,
    'showValues': showValues,
  };
}

class BarBrushWidget extends StatefulWidget {
  final BarBrushConfig config;
  const BarBrushWidget({super.key, required this.config});
  @override
  State<BarBrushWidget> createState() => _BarBrushState();
}

class _BarBrushState extends State<BarBrushWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  late String _dataSignature;
  double? _brushStart, _brushEnd;
  BarBrushConfig get cfg => widget.config;

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
  void didUpdateWidget(covariant BarBrushWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _brushStart = null;
      _brushEnd = null;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _xToIdx(double x, double plotL, double slotW) {
    if (cfg.categories.isEmpty) return 0;
    return ((x - plotL) / slotW).floor().clamp(0, cfg.categories.length - 1);
  }

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
              const padL = 48.0;
              final plotW = math.max(1.0, sz.width - padL - 12.0);
              final n = cfg.categories.length;
              final slotW = n > 0 ? plotW / n : 1.0;
              return GestureDetector(
                onPanStart: (d) {
                  setState(() {
                    _brushStart = d.localPosition.dx;
                    _brushEnd = null;
                  });
                },
                onPanUpdate: (d) {
                  setState(() {
                    _brushEnd = d.localPosition.dx;
                  });
                  if (_brushStart != null && _brushEnd != null) {
                    final si = _xToIdx(
                      math.min(_brushStart!, _brushEnd!),
                      padL,
                      slotW,
                    );
                    final ei = _xToIdx(
                      math.max(_brushStart!, _brushEnd!),
                      padL,
                      slotW,
                    );
                    cfg.onBrushChange?.call(si, ei);
                  }
                },
                onPanEnd: (_) => setState(() {}),
                onTap: () => setState(() {
                  _brushStart = null;
                  _brushEnd = null;
                }),
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _BarBrushPainter(
                          cfg: cfg,
                          progress: _anim.value,
                          brushStart: _brushStart,
                          brushEnd: _brushEnd,
                          plotLeft: padL,
                          slotW: slotW,
                          dataSignature: _dataSignature,
                        ),
                      ),
                    ),
                    if (_brushStart != null && _brushEnd != null)
                      Positioned(
                        top: 8,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cfg.theme.tooltipBackgroundColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Selected: ${_xToIdx(math.min(_brushStart!, _brushEnd!), padL, slotW) + 1}'
                            '–${_xToIdx(math.max(_brushStart!, _brushEnd!), padL, slotW) + 1}',
                            style: cfg.theme.typography.tooltipStyle.copyWith(
                              color: cfg.theme.tooltipTextColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BarBrushPainter extends ChartPainterBase {
  final BarBrushConfig cfg;
  final double progress;
  final double? brushStart, brushEnd;
  final double plotLeft, slotW;
  final String dataSignature;
  _BarBrushPainter({
    required this.cfg,
    required this.progress,
    required this.brushStart,
    required this.brushEnd,
    required this.plotLeft,
    required this.slotW,
    required this.dataSignature,
  }) : super(theme: cfg.theme);
  @override
  bool shouldRepaintChart(covariant _BarBrushPainter o) =>
      o.progress != progress ||
      o.brushStart != brushStart ||
      o.brushEnd != brushEnd ||
      o.dataSignature != dataSignature;

  @override
  void paint(Canvas canvas, Size size) {
    final n = cfg.categories.length;
    if (n == 0 || cfg.series.isEmpty) return;
    const padT = 24.0, padB = 28.0, padR = 12.0;
    final plotW = size.width - plotLeft - padR;
    final plotH = size.height - padT - padB;

    double maxVal = 0;
    for (final s in cfg.series) {
      for (final v in s.data ?? []) {
        final d = BarJson.doubleOrNull(v);
        if (d == null) continue;
        if (d > maxVal) {
          maxVal = d;
        }
      }
    }
    if (maxVal == 0) return;
    maxVal *= 1.1;

    // Brush range
    int brushSI = -1, brushEI = -1;
    if (brushStart != null && brushEnd != null) {
      brushSI = ((math.min(brushStart!, brushEnd!) - plotLeft) / slotW)
          .floor()
          .clamp(0, n - 1);
      brushEI = ((math.max(brushStart!, brushEnd!) - plotLeft) / slotW)
          .floor()
          .clamp(0, n - 1);
    }

    final ticks = ChartDataProcessor.niceYTicks(0, maxVal / 1.1);
    for (final t in ticks) {
      final y = padT + plotH * (1 - t / maxVal);
      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(plotLeft + plotW, y),
        paintCache.stroke(theme.gridColor, 0.5),
      );
      final tp = textPainterCache.get(
        t.toStringAsFixed(0),
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9,
        ),
        align: TextAlign.right,
        maxWidth: 40,
      );
      tp.paint(canvas, Offset(plotLeft - tp.width - 4, y - tp.height / 2));
    }

    final barW = slotW * 0.6;
    for (int ci = 0; ci < n; ci++) {
      final rawValue = _seriesValueAt(cfg.series.first, ci);
      final val = rawValue == null || rawValue < 0 ? 0.0 : rawValue;
      final cx = plotLeft + (ci + 0.5) * slotW;
      final barX = cx - barW / 2;
      final y = padT + plotH * (1 - val / maxVal * progress);
      final isSelected = brushSI >= 0 && ci >= brushSI && ci <= brushEI;
      final color = isSelected
          ? theme.seriesColor(0).withValues(alpha: 1.0)
          : theme.seriesColor(0).withValues(alpha: 0.35);

      _drawRoundedTopRect(
        canvas,
        Rect.fromLTWH(barX, y, barW, padT + plotH - y),
        3,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );

      final lbl = textPainterCache.get(
        cfg.categories[ci],
        theme.typography.axisLabelStyle.copyWith(
          color: theme.axisLabelColor,
          fontSize: 9.5,
        ),
      );
      lbl.paint(canvas, Offset(cx - lbl.width / 2, padT + plotH + 4));
    }

    // Brush overlay
    if (brushStart != null && brushEnd != null) {
      final bx = math.min(brushStart!, brushEnd!);
      final bw = (brushEnd! - brushStart!).abs();
      canvas.drawRect(
        Rect.fromLTWH(bx, padT, bw, plotH),
        Paint()
          ..color = theme.palette.colorObjectAt(0).withValues(alpha: 0.1)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        Rect.fromLTWH(bx, padT, bw, plotH),
        Paint()
          ..color = theme.palette.colorObjectAt(0).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.drawLine(
      Offset(plotLeft, padT + plotH),
      Offset(plotLeft + plotW, padT + plotH),
      axisPaint,
    );
    canvas.drawLine(
      Offset(plotLeft, padT),
      Offset(plotLeft, padT + plotH),
      axisPaint,
    );
  }
}
