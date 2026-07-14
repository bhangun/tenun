// Choropleth chart - colour-encoded geographic map.
// JSON: { "type":"choropleth", "series":[{"regions":[{"id":"US",
//   "name":"United States","value":331000000,
//   "polygon":[[-125,49],[-67,49],[-67,25],[-125,25]]}]}]}

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_color_value.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';
import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/chart_cache.dart';
import 'package:tenun_core/core/chart_data_signature.dart';
import 'package:tenun_core/core/chart_painter_base.dart';
import 'package:tenun_core/core/chart_series_json.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/json_value.dart';

// MapRegion model
class MapRegion {
  final String id, name;
  final double? value;
  final String? color;
  final List<List<List<double>>> polygons;
  const MapRegion({
    required this.id,
    required this.name,
    this.value,
    this.color,
    required this.polygons,
  });
  factory MapRegion.fromJson(Map<String, dynamic> j) {
    final singlePolygon = _readPolygon(j["polygon"]);
    final polys = j.containsKey("polygons")
        ? _readMultiPolygon(j["polygons"])
        : singlePolygon.length >= 3
        ? [singlePolygon]
        : <List<List<double>>>[];
    return MapRegion(
      id: j["id"]?.toString() ?? "",
      name: j["name"]?.toString() ?? j["id"]?.toString() ?? "",
      value: JsonValue.doubleOrNull(j["value"]),
      color: JsonValue.string(j["color"]),
      polygons: polys,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (value != null) 'value': value,
    if (color != null) 'color': color,
    'polygons': polygons,
  };
}

List<List<List<double>>> _readMultiPolygon(Object? raw) {
  final rawPolygons = JsonValue.list(raw) ?? const <dynamic>[];
  return rawPolygons
      .map(_readPolygon)
      .where((polygon) => polygon.length >= 3)
      .toList(growable: false);
}

List<List<double>> _readPolygon(Object? raw) {
  final rawPoints = JsonValue.list(raw) ?? const <dynamic>[];
  return rawPoints
      .map(_readCoordinate)
      .whereType<List<double>>()
      .toList(growable: false);
}

List<double>? _readCoordinate(Object? raw) {
  final point = JsonValue.list(raw);
  if (point == null || point.length < 2) return null;

  final lon = JsonValue.doubleOrNull(point[0]);
  final lat = JsonValue.doubleOrNull(point[1]);
  if (lon == null || lat == null) return null;

  return <double>[lon, lat];
}

enum ChoroplethColorScheme { sequential, diverging, categorical }

class _CS {
  final List<Color> stops;
  const _CS(this.stops);
  Color lerp(double t) {
    if (stops.isEmpty) return Colors.grey;
    t = t.clamp(0.0, 1.0);
    final s = t * (stops.length - 1);
    final lo = s.floor().clamp(0, stops.length - 2);
    return Color.lerp(stops[lo], stops[lo + 1], s - lo)!;
  }

  static const seq = _CS([
    Color(0xFFEDE7F6),
    Color(0xFF9575CD),
    Color(0xFF4527A0),
  ]);
  static const div = _CS([
    Color(0xFFC62828),
    Color(0xFFEF9A9A),
    Color(0xFFF5F5F5),
    Color(0xFF90CAF9),
    Color(0xFF1565C0),
  ]);
}

class _Merc {
  final double lonMin, lonMax, latMin, latMax, cl, ct, cw, ch, zoom;
  final Offset pan;
  const _Merc({
    required this.lonMin,
    required this.lonMax,
    required this.latMin,
    required this.latMax,
    required this.cl,
    required this.ct,
    required this.cw,
    required this.ch,
    this.zoom = 1.0,
    this.pan = Offset.zero,
  });
  static double _y(double d) {
    final r = d.clamp(-85.0, 85.0) * math.pi / 180;
    return math.log(math.tan(math.pi / 4 + r / 2));
  }

  double get _yMin => _y(latMin);
  double get _yMax => _y(latMax);
  Offset project(double lon, double lat) {
    final tx = (lon - lonMin) / (lonMax - lonMin);
    final ty = 1.0 - (_y(lat) - _yMin) / (_yMax - _yMin);
    return Offset(cl + tx * cw * zoom + pan.dx, ct + ty * ch * zoom + pan.dy);
  }
}

class ChoroplethChartConfig extends BaseChartConfig {
  final List<MapRegion> regions;
  final ChoroplethColorScheme colorScheme;
  final bool showLegend, showGraticule, showLabels;
  final double? minValue, maxValue;
  final String noDataLabel;
  final Color noDataColor, borderColor;
  final double borderWidth;
  @override
  // ignore: overridden_fields
  final ChartTheme theme;
  ChoroplethChartConfig({
    required this.regions,
    this.theme = ChartTheme.light,
    this.colorScheme = ChoroplethColorScheme.sequential,
    this.showLegend = true,
    this.showGraticule = false,
    this.showLabels = false,
    this.minValue,
    this.maxValue,
    this.noDataLabel = "No data",
    this.noDataColor = const Color(0xFFE0E0E0),
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = 0.8,
    super.title,
    super.tooltip,
    super.legend,
    super.toolbox,
    super.grid,
  }) : super(type: ChartType.choropleth, series: const []);
  @override
  Widget buildChart() => ChoroplethChartWidget(config: this);
  factory ChoroplethChartConfig.fromJson(Map<String, dynamic> json) {
    final series = ChartSeriesJson.firstSeries(json['series']);
    final rawRegions =
        JsonValue.list(series['regions']) ??
        JsonValue.list(json['regions']) ??
        const <dynamic>[];
    final regions = rawRegions
        .map(JsonValue.map)
        .whereType<Map<String, dynamic>>()
        .map(MapRegion.fromJson)
        .toList();
    final s =
        JsonValue.string(json['colorScheme'])?.toLowerCase() ?? 'sequential';

    return ChoroplethChartConfig(
      regions: regions,
      colorScheme: s == 'diverging'
          ? ChoroplethColorScheme.diverging
          : s == 'categorical'
          ? ChoroplethColorScheme.categorical
          : ChoroplethColorScheme.sequential,
      showLegend: JsonValue.boolOrNull(json['showLegend']) ?? true,
      showGraticule: JsonValue.boolOrNull(json['showGraticule']) ?? false,
      showLabels: JsonValue.boolOrNull(json['showLabels']) ?? false,
      minValue: JsonValue.doubleOrNull(json['minValue']),
      maxValue: JsonValue.doubleOrNull(json['maxValue']),
      noDataLabel: json['noDataLabel']?.toString() ?? 'No data',
      noDataColor: ChartColorValue.colorOrFallback(
        json['noDataColor'],
        const Color(0xFFE0E0E0),
      ),
      borderColor: ChartColorValue.colorOrFallback(
        json['borderColor'],
        const Color(0xFFFFFFFF),
      ),
      borderWidth: JsonValue.doubleOrNull(json['borderWidth']) ?? 0.8,
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
      {'regions': regions.map((region) => region.toJson()).toList()},
    ],
    'colorScheme': colorScheme.name,
    'showLegend': showLegend,
    'showGraticule': showGraticule,
    'showLabels': showLabels,
    if (minValue != null) 'minValue': minValue,
    if (maxValue != null) 'maxValue': maxValue,
    'noDataLabel': noDataLabel,
    'noDataColor': _colorToHex(noDataColor),
    'borderColor': _colorToHex(borderColor),
    'borderWidth': borderWidth,
  };
}

String _colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

// ── Widget ──────────────────────────────────────────────────

class ChoroplethChartWidget extends StatefulWidget {
  final ChoroplethChartConfig config;
  const ChoroplethChartWidget({super.key, required this.config});
  @override
  State<ChoroplethChartWidget> createState() => _ChoroplethState();
}

class _ChoroplethState extends State<ChoroplethChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _zoom = 1.0;
  Offset _pan = Offset.zero, _hoverPos = Offset.zero;
  Offset? _lastFocal;
  double? _lastScale;
  MapRegion? _hovered;
  double _lonMin = -180, _lonMax = 180, _latMin = -60, _latMax = 85;
  late String _dataSignature;
  ChoroplethChartConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    _dataSignature = ChartDataSignature.fromConfig(cfg).hash;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.addListener(() => setState(() {}));
    _ctrl.forward();
    _bounds();
  }

  @override
  void didUpdateWidget(ChoroplethChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = ChartDataSignature.fromConfig(cfg).hash;
    if (nextSignature != _dataSignature) {
      _dataSignature = nextSignature;
      _hovered = null;
      _pan = Offset.zero;
      _zoom = 1.0;
      _bounds();
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _bounds() {
    if (cfg.regions.isEmpty) {
      _lonMin = -180;
      _lonMax = 180;
      _latMin = -60;
      _latMax = 85;
      return;
    }
    double lo = 180, hi = -180, la = 90, lb = -90;
    for (final r in cfg.regions) {
      for (final p in r.polygons) {
        for (final ll in p) {
          if (ll[0] < lo) lo = ll[0];
          if (ll[0] > hi) hi = ll[0];
          if (ll[1] < la) la = ll[1];
          if (ll[1] > lb) lb = ll[1];
        }
      }
    }
    _lonMin = lo - (hi - lo) * .05 - 1;
    _lonMax = hi + (hi - lo) * .05 + 1;
    _latMin = la - (lb - la) * .05 - 1;
    _latMax = lb + (lb - la) * .05 + 1;
  }

  _Merc _merc(Size sz) => _Merc(
    lonMin: _lonMin,
    lonMax: _lonMax,
    latMin: _latMin,
    latMax: _latMax,
    cl: 8,
    ct: 8,
    cw: sz.width - 16,
    ch: sz.height - 40,
    zoom: _zoom,
    pan: _pan,
  );

  MapRegion? _hit(Offset pos, Size sz) {
    final m = _merc(sz);
    for (final r in cfg.regions.reversed) {
      for (final poly in r.polygons) {
        if (poly.length < 3) continue;
        bool inside = false;
        int j = poly.length - 1;
        for (int i = 0; i < poly.length; i++) {
          final pi = m.project(poly[i][0], poly[i][1]);
          final pj = m.project(poly[j][0], poly[j][1]);
          if ((pi.dy > pos.dy) != (pj.dy > pos.dy) &&
              pos.dx <
                  (pj.dx - pi.dx) * (pos.dy - pi.dy) / (pj.dy - pi.dy) +
                      pi.dx) {
            inside = !inside;
          }
          j = i;
        }
        if (inside) return r;
      }
    }
    return null;
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
                  Listener(
                    onPointerSignal: (e) {
                      if (e is PointerScrollEvent) {
                        setState(() {
                          final f = e.localPosition;
                          final nz =
                              (_zoom * (e.scrollDelta.dy > 0 ? .85 : 1.18))
                                  .clamp(.5, 20.0);
                          final s = nz / _zoom;
                          _pan = Offset(
                            f.dx + (_pan.dx - f.dx) * s,
                            f.dy + (_pan.dy - f.dy) * s,
                          );
                          _zoom = nz;
                        });
                      }
                    },
                    child: GestureDetector(
                      onScaleStart: (d) {
                        _lastFocal = d.localFocalPoint;
                        _lastScale = _zoom;
                      },
                      onScaleUpdate: (d) => setState(() {
                        final nz = (_lastScale! * d.scale).clamp(.5, 20.0);
                        final s = nz / _zoom;
                        final fp = d.localFocalPoint;
                        final pd = _lastFocal != null
                            ? fp - _lastFocal!
                            : Offset.zero;
                        _pan = Offset(
                          fp.dx + (_pan.dx - fp.dx) * s + pd.dx,
                          fp.dy + (_pan.dy - fp.dy) * s + pd.dy,
                        );
                        _lastFocal = fp;
                        _zoom = nz;
                      }),
                      onScaleEnd: (_) {
                        _lastFocal = null;
                        _lastScale = null;
                      },
                      onDoubleTap: () => setState(() {
                        _zoom = 1;
                        _pan = Offset.zero;
                      }),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.precise,
                        onHover: (e) {
                          final r = _hit(e.localPosition, sz);
                          setState(() {
                            _hovered = r;
                            _hoverPos = e.localPosition;
                          });
                        },
                        onExit: (_) => setState(() => _hovered = null),
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _ChoroplethPainter(
                              config: cfg,
                              progress: _anim.value,
                              zoom: _zoom,
                              pan: _pan,
                              hoveredId: _hovered?.id,
                              dataSignature: _dataSignature,
                              lonMin: _lonMin,
                              lonMax: _lonMax,
                              latMin: _latMin,
                              latMax: _latMax,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_hovered != null) _tip(sz),
                  if (_zoom != 1 || _pan != Offset.zero)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _zoom = 1;
                          _pan = Offset.zero;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cfg.theme.tooltipBackgroundColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.zoom_out_map,
                                size: 12,
                                color: cfg.theme.tooltipTextColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reset',
                                style: cfg.theme.typography.tooltipStyle
                                    .copyWith(
                                      color: cfg.theme.tooltipTextColor,
                                      fontSize: 10,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (cfg.showLegend) _legend(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tip(Size sz) {
    final r = _hovered!;
    final v = r.value != null ? _fmt(r.value!) : cfg.noDataLabel;
    final x = (_hoverPos.dx + 14).clamp(0.0, sz.width - 185.0);
    final y = (_hoverPos.dy - 62).clamp(0.0, sz.height - 78.0);
    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  r.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Value: $v'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    final vals = cfg.regions
        .where((r) => r.value != null)
        .map((r) => r.value!)
        .toList();
    if (vals.isEmpty) return const SizedBox();
    final lo = cfg.minValue ?? vals.reduce(math.min);
    final hi = cfg.maxValue ?? vals.reduce(math.max);
    final sc = cfg.colorScheme == ChoroplethColorScheme.diverging
        ? _CS.div
        : _CS.seq;
    return Positioned(
      left: 12,
      bottom: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: cfg.theme.tooltipBackgroundColor.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [sc.lerp(0), sc.lerp(.33), sc.lerp(.66), sc.lerp(1)],
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fmt(lo),
                  style: cfg.theme.typography.axisLabelStyle.copyWith(
                    color: cfg.theme.axisLabelColor,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(width: 100),
                Text(
                  _fmt(hi),
                  style: cfg.theme.typography.axisLabelStyle.copyWith(
                    color: cfg.theme.axisLabelColor,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v.abs() >= 1e9) return '${(v / 1e9).toStringAsFixed(1)}B';
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(v == v.truncateToDouble() ? 0 : 2);
  }
}

// ── Painter ─────────────────────────────────────────────────

class _ChoroplethPainter extends ChartPainterBase {
  final ChoroplethChartConfig config;
  final double progress, zoom;
  final Offset pan;
  final String? hoveredId;
  final String dataSignature;
  final double lonMin, lonMax, latMin, latMax;

  _ChoroplethPainter({
    required this.config,
    required this.progress,
    required this.zoom,
    required this.pan,
    required this.hoveredId,
    required this.dataSignature,
    required this.lonMin,
    required this.lonMax,
    required this.latMin,
    required this.latMax,
  }) : super(theme: config.theme);

  @override
  bool shouldRepaintChart(covariant _ChoroplethPainter o) =>
      o.progress != progress ||
      o.zoom != zoom ||
      o.pan != pan ||
      o.hoveredId != hoveredId ||
      o.dataSignature != dataSignature;

  (double lo, double hi) get _range {
    final v = config.regions.where((r) => r.value != null).map((r) => r.value!);
    if (v.isEmpty) return (0, 1);
    return (
      config.minValue ?? v.reduce(math.min),
      config.maxValue ?? v.reduce(math.max),
    );
  }

  Color _col(MapRegion r, double lo, double hi, int i) {
    if (r.color != null) {
      try {
        return colorCache.resolve(r.color!);
      } catch (_) {}
    }
    if (config.colorScheme == ChoroplethColorScheme.categorical) {
      return theme.palette.colorObjectAt(i);
    }
    if (r.value == null) return config.noDataColor;
    final t = ((r.value! - lo) / (hi - lo).clamp(1e-9, 1e18)).clamp(0.0, 1.0);
    return (config.colorScheme == ChoroplethColorScheme.diverging
            ? _CS.div
            : _CS.seq)
        .lerp(t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (config.regions.isEmpty) return;
    final m = _Merc(
      lonMin: lonMin,
      lonMax: lonMax,
      latMin: latMin,
      latMax: latMax,
      cl: 8,
      ct: 8,
      cw: size.width - 16,
      ch: size.height - 40,
      zoom: zoom,
      pan: pan,
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (config.showGraticule) {
      final gp = paintCache.stroke(theme.gridColor.withValues(alpha: .3), .5);
      for (double lat = -60; lat <= 80; lat += 20) {
        canvas.drawLine(m.project(lonMin, lat), m.project(lonMax, lat), gp);
      }
      for (double lon = -180; lon <= 180; lon += 30) {
        canvas.drawLine(
          m.project(lon, latMin.clamp(-80.0, 80.0)),
          m.project(lon, latMax.clamp(-80.0, 80.0)),
          gp,
        );
      }
    }
    final (lo, hi) = _range;
    for (int i = 0; i < config.regions.length; i++) {
      final r = config.regions[i];
      final isH = r.id == hoveredId;
      final base = _col(r, lo, hi, i);
      final fill = isH ? Color.lerp(base, Colors.white, .28)! : base;
      final fp = Paint()
        ..color = fill.withValues(alpha: progress.clamp(0.0, 1.0).toDouble())
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      final sp = Paint()
        ..color = config.borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isH ? config.borderWidth * 2 : config.borderWidth
        ..isAntiAlias = true;
      for (final poly in r.polygons) {
        if (poly.length < 3) continue;
        final path = Path();
        bool first = true;
        for (final ll in poly) {
          final pt = m.project(ll[0], ll[1]);
          if (first) {
            path.moveTo(pt.dx, pt.dy);
            first = false;
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(path, fp);
        canvas.drawPath(path, sp);
      }
      if (config.showLabels && r.id.length <= 4 && r.polygons.isNotEmpty) {
        final poly = r.polygons.first;
        double cx = 0, cy = 0;
        for (final ll in poly) {
          final pt = m.project(ll[0], ll[1]);
          cx += pt.dx;
          cy += pt.dy;
        }
        cx /= poly.length;
        cy /= poly.length;
        final tp = textPainterCache.get(
          r.id,
          theme.typography.axisLabelStyle.copyWith(
            color: Colors.white.withValues(alpha: .9),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        );
        tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
      }
    }
    canvas.restore();
  }
}
