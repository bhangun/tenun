import 'json_value.dart';

class ChartJsonOptionPaths {
  static const String root = r'$';

  const ChartJsonOptionPaths._();

  static String normalizeContainer(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == root) return root;
    if (trimmed.startsWith(r'$.')) return trimmed.substring(2);
    return trimmed;
  }

  static bool sameContainer(String a, String b) {
    return normalizeContainer(a) == normalizeContainer(b);
  }

  static String fieldPath(String containerPath, String canonicalField) {
    final normalizedContainer = normalizeContainer(containerPath);
    final normalizedField = canonicalField.trim();
    if (normalizedContainer == root || normalizedContainer.isEmpty) {
      return normalizedField;
    }
    return '$normalizedContainer.$normalizedField';
  }

  static List<String> segments(String path) {
    final normalized = normalizeContainer(path);
    if (normalized == root || normalized.isEmpty) return const <String>[];
    return [
      for (final segment in normalized.split('.'))
        if (segment.trim().isNotEmpty) segment.trim(),
    ];
  }

  static String jsonPointer(String path) {
    final pathSegments = segments(path);
    if (pathSegments.isEmpty) return '';
    return '/${pathSegments.map(_escapeJsonPointerSegment).join('/')}';
  }

  static Map<String, dynamic> fragment(String jsonPath, Object? value) {
    final pathSegments = segments(jsonPath);
    if (pathSegments.isEmpty) return <String, dynamic>{};

    final rootFragment = <String, dynamic>{};
    var cursor = rootFragment;
    for (var i = 0; i < pathSegments.length; i++) {
      final segment = pathSegments[i];
      if (i == pathSegments.length - 1) {
        cursor[segment] = JsonValue.clone(value);
      } else {
        final next = <String, dynamic>{};
        cursor[segment] = next;
        cursor = next;
      }
    }
    return rootFragment;
  }

  static Map<String, dynamic> mergeFragment(
    Map<String, dynamic> base,
    Map<String, dynamic> fragment,
  ) {
    final merged = JsonValue.cloneMap(base);
    _mergeInto(merged, fragment);
    return merged;
  }

  static Map<String, dynamic> mergeFragments(
    Iterable<Map<String, dynamic>> fragments,
  ) {
    final merged = <String, dynamic>{};
    for (final fragment in fragments) {
      _mergeInto(merged, fragment);
    }
    return merged;
  }
}

String _escapeJsonPointerSegment(String segment) {
  return segment.replaceAll('~', '~0').replaceAll('/', '~1');
}

void _mergeInto(Map<String, dynamic> target, Map<String, dynamic> source) {
  for (final entry in source.entries) {
    final existing = target[entry.key];
    final incoming = entry.value;
    if (existing is Map && incoming is Map) {
      final existingMap = JsonValue.map(existing) ?? <String, dynamic>{};
      _mergeInto(existingMap, JsonValue.map(incoming) ?? <String, dynamic>{});
      target[entry.key] = existingMap;
    } else {
      target[entry.key] = JsonValue.clone(incoming);
    }
  }
}
