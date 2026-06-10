// Caching layer for chart rendering objects.
//
// Charts call `ChartPaintCache.color()`, `ChartPaintCache.paint()` etc.
// instead of allocating new objects on every `paint()` call.
//
// Changes from v1:
// - [PaintCache.fillMutable]: fixed mutation-of-cached-paint bug — now returns
//   a **new** Paint pre-seeded from the cached one instead of mutating it.
// - [TextPainterCache]: replaced blunt clear-all eviction with a proper
//   bounded LRU (LinkedHashMap insertion-order tracking).
// - [PathCache]: new cache for pre-computed [ui.Path] / [ui.Vertices] objects
//   that are expensive to build on every frame.

import 'dart:collection';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Shared hit/miss/eviction snapshot for lightweight render-object caches.
class ChartObjectCacheStats {
  final String name;
  final int size;
  final int? maxSize;
  final int hits;
  final int misses;
  final int evictions;

  const ChartObjectCacheStats({
    required this.name,
    required this.size,
    required this.hits,
    required this.misses,
    required this.evictions,
    this.maxSize,
  });

  int get requests => hits + misses;
  double get hitRate => requests == 0 ? 0 : hits / requests;

  Map<String, dynamic> toJson() => {
    'name': name,
    'size': size,
    if (maxSize != null) 'maxSize': maxSize,
    'hits': hits,
    'misses': misses,
    'evictions': evictions,
    'requests': requests,
    'hitRate': hitRate,
  };
}

/// Combined diagnostics for the global render-object caches.
class ChartRenderCacheStats {
  final ChartObjectCacheStats colors;
  final ChartObjectCacheStats paints;
  final ChartObjectCacheStats textPainters;
  final ChartObjectCacheStats paths;

  const ChartRenderCacheStats({
    required this.colors,
    required this.paints,
    required this.textPainters,
    required this.paths,
  });

  Map<String, dynamic> toJson() => {
    'colors': colors.toJson(),
    'paints': paints.toJson(),
    'textPainters': textPainters.toJson(),
    'paths': paths.toJson(),
  };
}

// ---------------------------------------------------------------------------
// Color cache
// ---------------------------------------------------------------------------

/// Parses and caches [Color] objects from string representations.
///
/// Supports: `#RGB`, `#RRGGBB`, `#RRGGBBAA`, `rgb(r,g,b)`,
/// `rgba(r,g,b,a)`, and common named colours.
class ColorCache {
  ColorCache._({int maxSize = 512}) : _maxSize = maxSize;
  static final ColorCache _instance = ColorCache._();
  factory ColorCache() => _instance;

  final int _maxSize;
  final LinkedHashMap<String, Color> _cache = LinkedHashMap<String, Color>();
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  Color resolve(String raw) {
    final key = _normalizeColorKey(raw);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      _hits++;
      return hit;
    }

    _misses++;
    final color = _parse(key);
    _store(key, color);
    return color;
  }

  void _store(String key, Color color) {
    if (_maxSize <= 0) return;
    if (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first);
      _evictions++;
    }
    _cache[key] = color;
  }

  void clear({bool resetMetrics = true}) {
    _cache.clear();
    if (resetMetrics) resetStats();
  }

  void resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  ChartObjectCacheStats get stats => ChartObjectCacheStats(
    name: 'colors',
    size: _cache.length,
    maxSize: _maxSize,
    hits: _hits,
    misses: _misses,
    evictions: _evictions,
  );

  // ---- parsers ----

  String _normalizeColorKey(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('#')) return trimmed.toUpperCase();
    return trimmed.toLowerCase();
  }

  Color _parse(String s) {
    if (s.startsWith('#')) return _hex(s);
    final lower = s.toLowerCase();
    if (lower.startsWith('rgba(')) return _rgba(s);
    if (lower.startsWith('rgb(')) return _rgb(s);
    return _named(lower) ?? (throw FormatException('Unknown color: $s'));
  }

  Color _hex(String s) {
    var h = s.substring(1);
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (!_hexDigits.hasMatch(h)) {
      throw FormatException('Bad hex digits: $s');
    }
    if (h.length == 6) {
      final rgb = int.tryParse(h, radix: 16);
      if (rgb == null) throw FormatException('Bad hex: $s');
      return Color(0xFF000000 | rgb);
    }
    if (h.length == 8) {
      final rgb = int.tryParse(h.substring(0, 6), radix: 16);
      final alpha = int.tryParse(h.substring(6), radix: 16);
      if (rgb == null || alpha == null) throw FormatException('Bad hex: $s');
      return Color.fromARGB(
        alpha,
        (rgb >> 16) & 0xFF,
        (rgb >> 8) & 0xFF,
        rgb & 0xFF,
      );
    }
    throw FormatException('Bad hex: $s');
  }

  Color _rgb(String s) {
    final parts = _functionalColorComponents(s, 'rgb');
    if (parts.length != 3) {
      throw FormatException('Bad rgb: $s');
    }
    return Color.fromARGB(
      255,
      _rgbComponent(parts[0], s),
      _rgbComponent(parts[1], s),
      _rgbComponent(parts[2], s),
    );
  }

  Color _rgba(String s) {
    final parts = _functionalColorComponents(s, 'rgba');
    if (parts.length != 4) {
      throw FormatException('Bad rgba: $s');
    }
    return Color.fromARGB(
      _alphaComponent(parts[3], s),
      _rgbComponent(parts[0], s),
      _rgbComponent(parts[1], s),
      _rgbComponent(parts[2], s),
    );
  }

  static final RegExp _hexDigits = RegExp(r'^[0-9A-Fa-f]+$');

  static List<String> _functionalColorComponents(
    String color,
    String function,
  ) {
    final match = RegExp(
      '^\\s*$function\\s*\\((.*)\\)\\s*\$',
      caseSensitive: false,
    ).firstMatch(color);
    if (match == null) {
      throw FormatException('Bad $function: $color');
    }
    return match.group(1)!.split(',').map((p) => p.trim()).toList();
  }

  static int _rgbComponent(String component, String source) {
    final value = int.tryParse(component);
    if (value == null) {
      throw FormatException('Bad rgb component: $source');
    }
    return value.clamp(0, 255).toInt();
  }

  static int _alphaComponent(String component, String source) {
    final value = double.tryParse(component);
    if (value == null || value.isNaN) {
      throw FormatException('Bad rgba alpha: $source');
    }
    return (value.clamp(0.0, 1.0) * 255).round();
  }

  static const _named = _namedColors;
  static Color? _namedColors(String name) => const {
    'transparent': Color(0x00000000),
    'black': Color(0xFF000000),
    'white': Color(0xFFFFFFFF),
    'red': Color(0xFFF44336),
    'green': Color(0xFF4CAF50),
    'blue': Color(0xFF2196F3),
    'yellow': Color(0xFFFFEB3B),
    'orange': Color(0xFFFF9800),
    'purple': Color(0xFF9C27B0),
    'pink': Color(0xFFE91E63),
    'cyan': Color(0xFF00BCD4),
    'teal': Color(0xFF009688),
    'indigo': Color(0xFF3F51B5),
    'amber': Color(0xFFFFC107),
    'lime': Color(0xFFCDDC39),
    'brown': Color(0xFF795548),
    'grey': Color(0xFF9E9E9E),
    'gray': Color(0xFF9E9E9E),
    'navy': Color(0xFF0D1B4B),
    'maroon': Color(0xFF7B0000),
    'gold': Color(0xFFFFC200),
    'silver': Color(0xFFC0C0C0),
    'olive': Color(0xFF6D6D00),
  }[name];
}

// ---------------------------------------------------------------------------
// Paint cache — avoids allocating Paint objects inside paint() calls
// ---------------------------------------------------------------------------

class PaintCache {
  PaintCache._({int maxSize = 512}) : _maxSize = maxSize;
  static final PaintCache _instance = PaintCache._();
  factory PaintCache() => _instance;

  // Key: "AARRGGBB_style_strokeWidth"
  final int _maxSize;
  final LinkedHashMap<String, Paint> _cache = LinkedHashMap<String, Paint>();
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  Paint fill(Color color) => _get(color, PaintingStyle.fill, 0);
  Paint stroke(Color color, double width) =>
      _get(color, PaintingStyle.stroke, width);

  Paint _get(Color color, PaintingStyle style, double strokeWidth) {
    final safeStrokeWidth = strokeWidth.isFinite && strokeWidth > 0
        ? strokeWidth
        : 0.0;
    final key = '${color.toARGB32()}_${style.index}_$safeStrokeWidth';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      _hits++;
      return hit;
    }

    _misses++;
    final paint = Paint()
      ..color = color
      ..style = style
      ..isAntiAlias = true;
    if (style == PaintingStyle.stroke) {
      paint.strokeWidth = safeStrokeWidth;
    }
    _store(key, paint);
    return paint;
  }

  void _store(String key, Paint paint) {
    if (_maxSize <= 0) return;
    if (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first);
      _evictions++;
    }
    _cache[key] = paint;
  }

  void clear({bool resetMetrics = true}) {
    _cache.clear();
    if (resetMetrics) resetStats();
  }

  void resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  ChartObjectCacheStats get stats => ChartObjectCacheStats(
    name: 'paints',
    size: _cache.length,
    maxSize: _maxSize,
    hits: _hits,
    misses: _misses,
    evictions: _evictions,
  );

  /// Returns a **new** Paint seeded from the cached fill paint.
  ///
  /// BUG FIX v2: the original implementation called `fill(color)..shader = null`
  /// which mutated the cached [Paint] object — any caller that previously set
  /// a shader on it would corrupt every subsequent use of that cache entry.
  /// Now we always return a fresh object so callers can safely mutate it.
  Paint fillMutable(Color color) {
    final cached = fill(color);
    return Paint()
      ..color = cached.color
      ..style = cached.style
      ..isAntiAlias = cached.isAntiAlias;
  }

  /// Returns a new mutable stroke paint seeded from the cache.
  Paint strokeMutable(Color color, double width) {
    final cached = stroke(color, width);
    return Paint()
      ..color = cached.color
      ..style = cached.style
      ..strokeWidth = cached.strokeWidth
      ..isAntiAlias = cached.isAntiAlias;
  }
}

// ---------------------------------------------------------------------------
// TextPainter LRU cache
// ---------------------------------------------------------------------------

/// Caches [TextPainter] layout results with bounded LRU eviction.
///
/// v2 change: uses [LinkedHashMap] with access-order tracking for true LRU
/// eviction instead of clearing the entire cache when the size limit is hit.
class TextPainterCache {
  TextPainterCache._({int maxSize = 400}) : _maxSize = maxSize;
  static final TextPainterCache _instance = TextPainterCache._();
  factory TextPainterCache() => _instance;

  final int _maxSize;

  // LinkedHashMap preserves insertion order; we use remove+re-insert on hit
  // to maintain access order (most-recently-used at the end).
  final LinkedHashMap<String, TextPainter> _cache =
      LinkedHashMap<String, TextPainter>();
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  TextPainter get(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
    TextAlign align = TextAlign.left,
  }) {
    final safeMaxWidth = _safeTextLayoutMaxWidth(maxWidth);
    final key =
        '${text.length}:$text|${style.hashCode}|$safeMaxWidth|${align.index}';

    // LRU: move hit entry to end.
    if (_cache.containsKey(key)) {
      _hits++;
      final existing = _cache.remove(key)!;
      _cache[key] = existing;
      return existing;
    }

    _misses++;

    // Evict LRU (first) entry when full.
    if (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first);
      _evictions++;
    }

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: safeMaxWidth);

    _cache[key] = painter;
    return painter;
  }

  void clear({bool resetMetrics = true}) {
    _cache.clear();
    if (resetMetrics) resetStats();
  }

  void resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  int get size => _cache.length;

  ChartObjectCacheStats get stats => ChartObjectCacheStats(
    name: 'textPainters',
    size: _cache.length,
    maxSize: _maxSize,
    hits: _hits,
    misses: _misses,
    evictions: _evictions,
  );
}

double _safeTextLayoutMaxWidth(double value) {
  if (value.isNaN) return double.infinity;
  if (value < 0) return 0;
  return value;
}

// ---------------------------------------------------------------------------
// PathCache — cache expensive Path / geometry computations
// ---------------------------------------------------------------------------

/// Caches pre-computed [ui.Path] objects to avoid rebuilding them on every
/// `paint()` call when the underlying data has not changed.
///
/// Usage in a painter:
/// ```dart
/// final path = pathCache.getOrBuild('line_series_0_${hashCode}', () {
///   final p = ui.Path();
///   // ... build the path from data ...
///   return p;
/// });
/// canvas.drawPath(path, strokePaint(color, 2));
/// ```
class PathCache {
  PathCache._({int maxSize = 200}) : _maxSize = maxSize;
  static final PathCache _instance = PathCache._();
  factory PathCache() => _instance;

  final int _maxSize;
  final LinkedHashMap<String, ui.Path> _cache = LinkedHashMap();
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  /// Returns cached path for [key], or builds and caches it via [builder].
  ui.Path getOrBuild(String key, ui.Path Function() builder) {
    if (_cache.containsKey(key)) {
      _hits++;
      final hit = _cache.remove(key)!;
      _cache[key] = hit;
      return hit;
    }
    _misses++;
    if (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first);
      _evictions++;
    }
    final path = builder();
    _cache[key] = path;
    return path;
  }

  /// Invalidate a specific key (call when data changes).
  void invalidate(String key) => _cache.remove(key);

  /// Invalidate all keys with a given prefix (e.g., invalidate all paths for
  /// a series: `invalidatePrefix('series_0_')`).
  void invalidatePrefix(String prefix) {
    final toRemove = _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in toRemove) {
      _cache.remove(k);
    }
  }

  void clear({bool resetMetrics = true}) {
    _cache.clear();
    if (resetMetrics) resetStats();
  }

  void resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  int get size => _cache.length;

  ChartObjectCacheStats get stats => ChartObjectCacheStats(
    name: 'paths',
    size: _cache.length,
    maxSize: _maxSize,
    hits: _hits,
    misses: _misses,
    evictions: _evictions,
  );
}

// ---------------------------------------------------------------------------
// Global convenience accessors
// ---------------------------------------------------------------------------

final colorCache = ColorCache();
final paintCache = PaintCache();
final textPainterCache = TextPainterCache();
final pathCache = PathCache();

ChartRenderCacheStats get chartRenderCacheStats => ChartRenderCacheStats(
  colors: colorCache.stats,
  paints: paintCache.stats,
  textPainters: textPainterCache.stats,
  paths: pathCache.stats,
);

void clearChartRenderCaches({bool resetMetrics = true}) {
  colorCache.clear(resetMetrics: resetMetrics);
  paintCache.clear(resetMetrics: resetMetrics);
  textPainterCache.clear(resetMetrics: resetMetrics);
  pathCache.clear(resetMetrics: resetMetrics);
}

void resetChartRenderCacheStats() {
  colorCache.resetStats();
  paintCache.resetStats();
  textPainterCache.resetStats();
  pathCache.resetStats();
}

/// Resolve a nullable color string with a fallback.
Color resolveColor(String? raw, Color fallback) {
  if (raw == null || raw.isEmpty) return fallback;
  try {
    return colorCache.resolve(raw);
  } catch (_) {
    return fallback;
  }
}
