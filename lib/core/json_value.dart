import 'dart:collection';

/// Small, defensive helpers for reading JSON-like maps.
///
/// Flutter callers often build payloads as `Map<String, Object?>`, while
/// decoded JSON commonly arrives as `Map<String, dynamic>`. These helpers keep
/// config factories structural instead of depending on exact generic types.
class JsonValue {
  const JsonValue._();

  /// Prevents recursive JSON-like helpers from overflowing the stack on
  /// malicious or accidentally over-nested input.
  static const int maxTraversalDepth = 1024;

  /// Deep-copies JSON-like maps and lists while normalizing map keys to
  /// strings. Scalar/object values are preserved by reference.
  static Object? clone(Object? value) {
    return _clone(value, LinkedHashSet<Object>.identity(), 0);
  }

  static Object? _clone(Object? value, Set<Object> active, int depth) {
    if (value is Map) {
      _checkTraversalDepth(depth);
      _enterJsonObject(value, active);
      try {
        return <String, dynamic>{
          for (final entry in value.entries)
            entry.key.toString(): _clone(entry.value, active, depth + 1),
        };
      } finally {
        active.remove(value);
      }
    }
    if (value is List) {
      _checkTraversalDepth(depth);
      _enterJsonObject(value, active);
      try {
        return value
            .map((item) => _clone(item, active, depth + 1))
            .toList(growable: true);
      } finally {
        active.remove(value);
      }
    }
    return value;
  }

  static Map<String, dynamic> cloneMap(Map value) {
    return _clone(value, LinkedHashSet<Object>.identity(), 0)
        as Map<String, dynamic>;
  }

  /// Deep-copies and freezes JSON-like maps/lists while normalizing map keys.
  static Object? freeze(Object? value) {
    return _freeze(value, LinkedHashSet<Object>.identity(), 0);
  }

  static Object? _freeze(Object? value, Set<Object> active, int depth) {
    if (value is Map) {
      _checkTraversalDepth(depth);
      _enterJsonObject(value, active);
      try {
        return Map<String, dynamic>.unmodifiable({
          for (final entry in value.entries)
            entry.key.toString(): _freeze(entry.value, active, depth + 1),
        });
      } finally {
        active.remove(value);
      }
    }
    if (value is List) {
      _checkTraversalDepth(depth);
      _enterJsonObject(value, active);
      try {
        return List<dynamic>.unmodifiable(
          value.map((item) => _freeze(item, active, depth + 1)),
        );
      } finally {
        active.remove(value);
      }
    }
    return value;
  }

  static Map<String, dynamic> freezeMap(Map value) {
    return _freeze(value, LinkedHashSet<Object>.identity(), 0)
        as Map<String, dynamic>;
  }

  /// Deep equality for JSON-like maps/lists, with map keys compared as strings.
  static bool deepEquals(Object? a, Object? b) {
    return _deepEquals(a, b, <_IdentityPair>{}, 0);
  }

  static bool _deepEquals(
    Object? a,
    Object? b,
    Set<_IdentityPair> active,
    int depth,
  ) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (depth >= maxTraversalDepth) return false;
      final pair = _IdentityPair(a, b);
      if (!active.add(pair)) return true;
      try {
        final left = _stringKeyedMap(a);
        final right = _stringKeyedMap(b);
        if (left.length != right.length) return false;
        for (final entry in left.entries) {
          if (!right.containsKey(entry.key)) return false;
          if (!_deepEquals(entry.value, right[entry.key], active, depth + 1)) {
            return false;
          }
        }
        return true;
      } finally {
        active.remove(pair);
      }
    }
    if (a is List && b is List) {
      if (depth >= maxTraversalDepth) return false;
      final pair = _IdentityPair(a, b);
      if (!active.add(pair)) return true;
      try {
        if (a.length != b.length) return false;
        for (var i = 0; i < a.length; i++) {
          if (!_deepEquals(a[i], b[i], active, depth + 1)) return false;
        }
        return true;
      } finally {
        active.remove(pair);
      }
    }
    return a == b;
  }

  /// Deep hash matching [deepEquals] for JSON-like maps/lists.
  static int deepHash(Object? value) {
    return _deepHash(value, LinkedHashSet<Object>.identity(), 0);
  }

  static int _deepHash(Object? value, Set<Object> active, int depth) {
    if (value is Map) {
      if (depth >= maxTraversalDepth) return _depthLimitHash;
      if (!active.add(value)) return _cycleHash;
      try {
        final map = _stringKeyedMap(value);
        return Object.hashAllUnordered(
          map.entries.map(
            (entry) => Object.hash(
              entry.key,
              _deepHash(entry.value, active, depth + 1),
            ),
          ),
        );
      } finally {
        active.remove(value);
      }
    }
    if (value is List) {
      if (depth >= maxTraversalDepth) return _depthLimitHash;
      if (!active.add(value)) return _cycleHash;
      try {
        return Object.hashAll(
          value.map((item) => _deepHash(item, active, depth + 1)),
        );
      } finally {
        active.remove(value);
      }
    }
    return value.hashCode;
  }

  static void _enterJsonObject(Object value, Set<Object> active) {
    if (!active.add(value)) {
      throw UnsupportedError('Cyclic JSON-like maps/lists are not supported.');
    }
  }

  static void _checkTraversalDepth(int depth) {
    if (depth >= maxTraversalDepth) {
      throw UnsupportedError(
        'JSON-like maps/lists exceed max traversal depth '
        'of $maxTraversalDepth.',
      );
    }
  }

  static const int _cycleHash = 0x3d4a7c19;
  static const int _depthLimitHash = 0x5b2f8e71;

  static Map<String, dynamic>? map(Object? value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      };
    }
    return null;
  }

  static List<dynamic>? list(Object? value) {
    if (value is List) return value;
    return null;
  }

  static List<Map<String, dynamic>>? mapList(Object? value) {
    final raw = list(value);
    if (raw == null) return null;
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      final parsed = map(item);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  static String? string(Object? value) {
    if (value == null) return null;
    return value.toString();
  }

  static double? doubleOrNull(Object? value) {
    if (value is num) {
      final parsed = value.toDouble();
      return parsed.isFinite ? parsed : null;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final direct = double.tryParse(trimmed);
      if (direct != null) return direct.isFinite ? direct : null;
      final normalized = _normalizeNumericString(trimmed);
      if (normalized == trimmed) return null;
      final parsed = double.tryParse(normalized);
      return parsed != null && parsed.isFinite ? parsed : null;
    }
    return null;
  }

  static int? intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.isFinite ? value.toInt() : null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final direct = int.tryParse(trimmed);
      if (direct != null) return direct;
      final normalized = _normalizeNumericString(trimmed);
      if (normalized == trimmed) return null;
      return int.tryParse(normalized);
    }
    return null;
  }

  static bool? boolOrNull(Object? value) {
    if (value is bool) return value;
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
    }
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
        case 'y':
          return true;
        case 'false':
        case '0':
        case 'no':
        case 'n':
          return false;
      }
    }
    return null;
  }

  static List<String>? stringList(Object? value) {
    final raw = list(value);
    if (raw == null) return null;
    return raw.map((item) => item.toString()).toList(growable: false);
  }

  static List<int>? intList(Object? value) {
    final raw = list(value);
    if (raw == null) return null;
    final out = <int>[];
    for (final item in raw) {
      final parsed = intOrNull(item);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  static List<List<int>>? intMatrix(Object? value) {
    final raw = list(value);
    if (raw == null) return null;
    final out = <List<int>>[];
    for (final row in raw) {
      final parsed = intList(row);
      if (parsed != null && parsed.isNotEmpty) {
        out.add(parsed);
      }
    }
    return out;
  }

  static List<double>? doubleList(Object? value) {
    final raw = list(value);
    if (raw == null) return null;
    final out = <double>[];
    for (final item in raw) {
      final parsed = doubleOrNull(item);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  static Map<String, bool>? boolMap(Object? value) {
    final raw = map(value);
    if (raw == null) return null;
    final out = <String, bool>{};
    for (final entry in raw.entries) {
      final parsed = boolOrNull(entry.value);
      if (parsed != null) out[entry.key] = parsed;
    }
    return out.isEmpty ? null : out;
  }

  static T? enumValue<T extends Enum>(
    Iterable<T> values,
    Object? raw, {
    T? fallback,
  }) {
    if (raw is T) return raw;
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    final normalized = _normalizeToken(text);
    for (final value in values) {
      if (_normalizeToken(value.name) == normalized) return value;
    }
    return fallback;
  }

  static String _normalizeToken(String value) =>
      value.toLowerCase().replaceAll('_', '').replaceAll('-', '');

  static Map<String, Object?> _stringKeyedMap(Map value) {
    return <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }

  static String _normalizeNumericString(String value) {
    if (!_groupedNumberPattern.hasMatch(value)) return value;
    return value.replaceAll(',', '').replaceAll('_', '');
  }

  static final RegExp _groupedNumberPattern = RegExp(
    r'^[+-]?\d+(?:[,_]\d+)*(?:\.\d+)?(?:[eE][+-]?\d+)?$',
  );
}

class _IdentityPair {
  const _IdentityPair(this.left, this.right);

  final Object left;
  final Object right;

  @override
  bool operator ==(Object other) {
    return other is _IdentityPair &&
        identical(left, other.left) &&
        identical(right, other.right);
  }

  @override
  int get hashCode =>
      Object.hash(identityHashCode(left), identityHashCode(right));
}
