import 'dart:collection';
import 'dart:ui' as ui;

/// Memory and cache-efficiency snapshot for [PictureCache].
class PictureCacheStats {
  final int size;
  final int currentMemoryBytes;
  final int maxMemoryBytes;
  final int hits;
  final int misses;
  final int evictions;
  final int skippedWrites;

  const PictureCacheStats({
    required this.size,
    required this.currentMemoryBytes,
    required this.maxMemoryBytes,
    required this.hits,
    required this.misses,
    required this.evictions,
    this.skippedWrites = 0,
  });

  int get requests => hits + misses;
  double get hitRate => requests == 0 ? 0 : hits / requests;

  Map<String, dynamic> toJson() => {
    'size': size,
    'currentMemoryBytes': currentMemoryBytes,
    'maxMemoryBytes': maxMemoryBytes,
    'hits': hits,
    'misses': misses,
    'evictions': evictions,
    'skippedWrites': skippedWrites,
    'requests': requests,
    'hitRate': hitRate,
  };
}

/// Result of a [PictureCache] lookup/build operation.
class PictureCacheResult {
  final ui.Picture picture;
  final bool cacheHit;
  final bool retained;
  final bool skippedWrite;

  const PictureCacheResult({
    required this.picture,
    required this.cacheHit,
    required this.retained,
    required this.skippedWrite,
  });
}

/// Advanced Picture Cache with automatic LRU eviction and memory tracking.
/// Prevents OOM crashes on large charts by disposing unused `ui.Picture`s.
class PictureCache {
  final int _maxMemoryBytes;
  final LinkedHashMap<String, _CachedPicture> _cache = LinkedHashMap();
  int _currentMemory = 0;
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _skippedWrites = 0;

  PictureCache({int maxMemoryBytes = 64 * 1024 * 1024}) // 64MB default
    : _maxMemoryBytes = maxMemoryBytes > 0 ? maxMemoryBytes : 0;

  ui.Picture getOrBuild(
    String key,
    ui.Size size,
    void Function(ui.Canvas canvas, ui.Size size) builder,
  ) => getOrBuildWithReport(key, size, builder).picture;

  PictureCacheResult getOrBuildWithReport(
    String key,
    ui.Size size,
    void Function(ui.Canvas canvas, ui.Size size) builder,
  ) {
    final safeSize = _safeCacheSize(size);
    if (_isEmptySize(safeSize)) {
      invalidate(key);
      _misses++;
      _skippedWrites++;
      return PictureCacheResult(
        picture: _recordEmptyPicture(),
        cacheHit: false,
        retained: false,
        skippedWrite: true,
      );
    }

    final cached = _cache.remove(key);
    if (cached != null && cached.size == safeSize) {
      _hits++;
      _cache[key] = cached; // Move to end (MRU)
      return PictureCacheResult(
        picture: cached.picture,
        cacheHit: true,
        retained: true,
        skippedWrite: false,
      );
    }
    if (cached != null) {
      // The same logical layer at a different size must be re-recorded.
      cached.picture.dispose();
      _currentMemory = (_currentMemory - cached.memoryBytes)
          .clamp(0, _maxTrackedMemoryBytes)
          .toInt();
    }

    _misses++;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    builder(canvas, safeSize);
    final picture = recorder.endRecording();

    // Estimate memory (RGBA pixels + ~2KB overhead).
    final estimatedBytes = estimateMemoryBytes(safeSize);
    if (!_canRetain(estimatedBytes)) {
      _skippedWrites++;
      return PictureCacheResult(
        picture: picture,
        cacheHit: false,
        retained: false,
        skippedWrite: true,
      );
    }

    _evictIfNeeded(estimatedBytes);

    _cache[key] = _CachedPicture(picture, estimatedBytes, safeSize);
    _currentMemory += estimatedBytes;
    return PictureCacheResult(
      picture: picture,
      cacheHit: false,
      retained: true,
      skippedWrite: false,
    );
  }

  void invalidate(String key) {
    final cached = _cache.remove(key);
    if (cached != null) {
      cached.picture.dispose(); // ✅ Explicit disposal
      _currentMemory = (_currentMemory - cached.memoryBytes)
          .clamp(0, _maxTrackedMemoryBytes)
          .toInt();
    }
  }

  void clear({bool resetMetrics = true}) {
    for (final c in _cache.values) {
      c.picture.dispose();
    }
    _cache.clear();
    _currentMemory = 0;
    if (resetMetrics) resetStats();
  }

  void resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _skippedWrites = 0;
  }

  int get size => _cache.length;
  int get currentMemoryBytes => _currentMemory;
  int get maxMemoryBytes => _maxMemoryBytes;

  PictureCacheStats get stats => PictureCacheStats(
    size: _cache.length,
    currentMemoryBytes: _currentMemory,
    maxMemoryBytes: _maxMemoryBytes,
    hits: _hits,
    misses: _misses,
    evictions: _evictions,
    skippedWrites: _skippedWrites,
  );

  int estimateMemoryBytes(ui.Size size) {
    final width = _safeDimension(size.width);
    final height = _safeDimension(size.height);
    final bytes = width * height * 4 + 2048;
    if (!bytes.isFinite) return _maxTrackedMemoryBytes;
    return bytes.clamp(2048, _maxTrackedMemoryBytes).round();
  }

  void _evictIfNeeded(int incomingBytes) {
    while (_currentMemory + incomingBytes > _maxMemoryBytes &&
        _cache.isNotEmpty) {
      final evicted = _cache.remove(_cache.keys.first)!;
      evicted.picture.dispose(); // ✅ LRU eviction disposal
      _currentMemory = (_currentMemory - evicted.memoryBytes)
          .clamp(0, _maxTrackedMemoryBytes)
          .toInt();
      _evictions++;
    }
  }

  bool _canRetain(int incomingBytes) =>
      _maxMemoryBytes > 0 && incomingBytes <= _maxMemoryBytes;
}

class _CachedPicture {
  final ui.Picture picture;
  final int memoryBytes;
  final ui.Size size;
  _CachedPicture(this.picture, this.memoryBytes, this.size);
}

final pictureCache = PictureCache();

const int _maxTrackedMemoryBytes = 1 << 62;

double _safeDimension(double value) => value.isFinite && value > 0 ? value : 0;

ui.Size _safeCacheSize(ui.Size size) {
  final width = _safeDimension(size.width);
  final height = _safeDimension(size.height);
  if (width == size.width && height == size.height) return size;
  return ui.Size(width, height);
}

bool _isEmptySize(ui.Size size) => size.width <= 0 || size.height <= 0;

ui.Picture _recordEmptyPicture() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder);
  return recorder.endRecording();
}
