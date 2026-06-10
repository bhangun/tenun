import 'dart:convert';

import 'base_config.dart';

/// Stable, content-based signature for chart payload/config data.
///
/// This is intentionally independent from Dart object identity/hashCode so it
/// can safely drive memoization, callback de-duping, and diagnostics even when
/// callers rebuild equivalent maps or mutate a reused map instance.
class ChartDataSignature {
  final String hash;
  final int canonicalBytes;
  final int seriesCount;
  final int dataPointCount;
  final String? typeString;

  const ChartDataSignature({
    required this.hash,
    required this.canonicalBytes,
    required this.seriesCount,
    required this.dataPointCount,
    this.typeString,
  });

  factory ChartDataSignature.fromJson(Map<String, dynamic> json) {
    final metrics = _canonicalMetrics(json);
    return ChartDataSignature(
      hash: metrics.hash,
      canonicalBytes: metrics.canonicalBytes,
      seriesCount: _seriesCount(json),
      dataPointCount: _dataPointCount(json),
      typeString: json['type']?.toString(),
    );
  }

  factory ChartDataSignature.fromConfig(BaseChartConfig config) =>
      ChartDataSignature.fromJson(config.toJson());

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'canonicalBytes': canonicalBytes,
    'seriesCount': seriesCount,
    'dataPointCount': dataPointCount,
    if (typeString != null) 'type': typeString,
  };

  @override
  String toString() => hash;
}

/// Returns a deterministic hash for [value].
String stableChartDataHash(Object? value) => _canonicalMetrics(value).hash;

/// Returns a deterministic hash for an already-canonicalized string.
String stableChartDataHashCanonical(String canonical) {
  var hash = _fnvOffsetBasis;
  for (final unit in canonical.codeUnits) {
    hash ^= unit;
    hash = (hash * _fnvPrime) & _uint64Mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

/// Canonicalizes JSON-like chart data with sorted map keys.
String canonicalizeChartData(Object? value) {
  final buffer = StringBuffer();
  _writeCanonical(buffer, value);
  return buffer.toString();
}

const int _fnvOffsetBasis = 0xcbf29ce484222325;
const int _fnvPrime = 0x100000001b3;
const int _uint64Mask = 0xffffffffffffffff;

void _writeCanonical(StringBuffer buffer, Object? value) {
  _writeCanonicalValue(buffer.write, value);
}

_CanonicalMetrics _canonicalMetrics(Object? value) {
  final sink = _CanonicalMetricSink();
  _writeCanonicalValue(sink.write, value);
  return sink.toMetrics();
}

void _writeCanonicalValue(void Function(Object? value) write, Object? value) {
  if (value == null) {
    write('n;');
    return;
  }
  if (value is bool) {
    write('b:${value ? 1 : 0};');
    return;
  }
  if (value is num) {
    write('num:');
    write(_canonicalNumber(value));
    write(';');
    return;
  }
  if (value is String) {
    write('s:');
    write(jsonEncode(value));
    write(';');
    return;
  }
  if (value is DateTime) {
    write('dt:');
    write(value.toUtc().toIso8601String());
    write(';');
    return;
  }
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    write('m{');
    for (final entry in entries) {
      final key = entry.key.toString();
      write(jsonEncode(key));
      write(':');
      _writeCanonicalValue(write, entry.value);
    }
    write('}');
    return;
  }
  if (value is Iterable) {
    write('l[');
    for (final item in value) {
      _writeCanonicalValue(write, item);
    }
    write(']');
    return;
  }

  write('o:');
  write(value.runtimeType);
  write(':');
  write(jsonEncode(value.toString()));
  write(';');
}

class _CanonicalMetrics {
  final String hash;
  final int canonicalBytes;

  const _CanonicalMetrics({required this.hash, required this.canonicalBytes});
}

class _CanonicalMetricSink {
  var _hash = _fnvOffsetBasis;
  var _canonicalBytes = 0;

  void write(Object? value) {
    final text = value.toString();
    for (var index = 0; index < text.length; index++) {
      final unit = text.codeUnitAt(index);
      _hash ^= unit;
      _hash = (_hash * _fnvPrime) & _uint64Mask;
      _canonicalBytes += _utf8CodeUnitLength(text, index, unit);
    }
  }

  _CanonicalMetrics toMetrics() => _CanonicalMetrics(
    hash: _hash.toRadixString(16).padLeft(16, '0'),
    canonicalBytes: _canonicalBytes,
  );
}

int _utf8CodeUnitLength(String text, int index, int unit) {
  if (unit <= 0x7f) return 1;
  if (unit <= 0x7ff) return 2;

  if (_isHighSurrogate(unit) &&
      index + 1 < text.length &&
      _isLowSurrogate(text.codeUnitAt(index + 1))) {
    return 4;
  }
  if (_isLowSurrogate(unit) &&
      index > 0 &&
      _isHighSurrogate(text.codeUnitAt(index - 1))) {
    return 0;
  }

  return 3;
}

bool _isHighSurrogate(int unit) => unit >= 0xd800 && unit <= 0xdbff;

bool _isLowSurrogate(int unit) => unit >= 0xdc00 && unit <= 0xdfff;

String _canonicalNumber(num value) {
  if (value is double && !value.isFinite) return value.toString();
  if (value is int) return value.toString();
  final asDouble = value.toDouble();
  if (asDouble == asDouble.truncateToDouble()) {
    return asDouble.toInt().toString();
  }
  return asDouble.toString();
}

int _seriesCount(Map<String, dynamic> json) {
  final series = json['series'];
  if (series is List && series.isNotEmpty) return series.length;
  if (json['xData'] is List || json['yData'] is List) return 1;
  if (json['points'] is List) return 1;
  if (json['data'] is List) return 1;
  if (json['frames'] is List) return 1;
  if (json['dateValues'] is Map) return 1;
  final rings = json['rings'];
  if (rings is List && rings.isNotEmpty) return rings.length;
  final partitionSeriesCount =
      (json['mainSlices'] is List ? 1 : 0) +
      (json['subSlices'] is List ? 1 : 0);
  if (partitionSeriesCount > 0) return partitionSeriesCount;
  if (json['nodes'] is List ||
      json['links'] is List ||
      json['regions'] is List) {
    return 1;
  }
  if (_payloadCollectionPointCount(json) > 0) return 1;
  return 0;
}

int _dataPointCount(Map<String, dynamic> json) {
  final series = json['series'];
  var count = 0;
  if (series is List) {
    for (final item in series) {
      if (item is Map) {
        count += _seriesItemPointCount(item);
      }
    }
  }
  if (count > 0) return count;

  final xData = json['xData'];
  final yData = json['yData'];
  if (xData is List && yData is List) {
    return xData.length < yData.length ? xData.length : yData.length;
  }
  if (xData is List) return xData.length;
  if (yData is List) return yData.length;

  final points = json['points'];
  if (points is List) return points.length;

  final data = json['data'];
  if (data is List) return _dataListPointCount(data);

  final frames = json['frames'];
  if (frames is List) {
    var framePointCount = 0;
    for (final frame in frames) {
      framePointCount += _framePointCount(frame);
    }
    if (framePointCount > 0) return framePointCount;
    return frames.length;
  }

  final dateValues = json['dateValues'];
  if (dateValues is Map) return dateValues.length;

  final nodes = json['nodes'];
  final links = json['links'];
  final regions = json['regions'];
  if (nodes is List || links is List || regions is List) {
    return (nodes is List ? _dataListPointCount(nodes) : 0) +
        (links is List ? _dataListPointCount(links) : 0) +
        (regions is List ? _dataListPointCount(regions) : 0);
  }

  return _payloadCollectionPointCount(json);
}

int _seriesItemPointCount(Map item) {
  final data = item['data'];
  if (data is List) return _dataListPointCount(data);

  final nodes = item['nodes'];
  final links = item['links'];
  final regions = item['regions'];
  if (nodes is List || links is List || regions is List) {
    return (nodes is List ? _dataListPointCount(nodes) : 0) +
        (links is List ? _dataListPointCount(links) : 0) +
        (regions is List ? _dataListPointCount(regions) : 0);
  }

  return _payloadCollectionPointCount(item);
}

int _payloadCollectionPointCount(Map json) {
  var count = 0;
  count += _listFieldPointCount(json, 'slices');
  count += _listFieldPointCount(json, 'rings');
  count += _listFieldPointCount(json, 'mainSlices');
  count += _listFieldPointCount(json, 'subSlices');
  count += _listFieldPointCount(json, 'days');
  count += _listFieldPointCount(json, 'items');
  count += _listFieldPointCount(json, 'tasks');
  count += _listFieldPointCount(json, 'cells');
  count += _listFieldPointCount(json, 'bars');
  count += _listFieldPointCount(json, 'prices');
  count += _listFieldPointCount(json, 'values');
  return count;
}

int _listFieldPointCount(Map json, String key) {
  final value = json[key];
  if (value is! List) return 0;
  return _dataListPointCount(value);
}

int _dataListPointCount(List data) {
  var count = 0;
  for (final item in data) {
    count += _dataItemPointCount(item);
  }
  return count;
}

int _dataItemPointCount(Object? item) {
  if (item is Map) {
    final children = item['children'];
    if (children is List) {
      return 1 + _dataListPointCount(children);
    }
    final slices = item['slices'];
    if (slices is List) return _dataListPointCount(slices);
    final data = item['data'];
    if (data is List) return _dataListPointCount(data);
  }
  return 1;
}

int _framePointCount(Object? frame) {
  if (frame is List) return frame.length;
  if (frame is Map) {
    final values = frame['values'];
    if (values is Map) return values.length;

    var count = 0;
    for (final entry in frame.entries) {
      if (entry.key.toString() == 'label') continue;
      count++;
    }
    return count;
  }
  return 0;
}
