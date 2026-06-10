class ChartExportFilename {
  const ChartExportFilename._();

  static const int defaultMaxLength = 120;
  static const String defaultFallback = 'chart_export';

  static final RegExp _unsafeCharacters = RegExp(r'[\x00-\x1F\x7F<>:"/\\|?*]+');
  static final RegExp _repeatedSeparators = RegExp(r'[_\s]+');
  static final RegExp _reservedDeviceName = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$',
    caseSensitive: false,
  );

  static String sanitize(
    String? filename, {
    String fallback = defaultFallback,
    int maxLength = defaultMaxLength,
  }) {
    final raw = filename?.trim();
    final extensionIndex = _extensionIndex(raw);
    if (extensionIndex != null) {
      return withExtension(
        raw!.substring(0, extensionIndex),
        raw.substring(extensionIndex + 1),
        fallback: fallback,
        maxLength: maxLength,
      );
    }

    final safeFallback = _sanitizeStem(fallback, defaultFallback);
    final limit = maxLength < 1 ? defaultMaxLength : maxLength;
    final sanitized = _sanitizeStem(raw, safeFallback);
    return _limitLength(sanitized, limit, fallback: safeFallback);
  }

  static String withExtension(
    String? filename,
    String extension, {
    String fallback = defaultFallback,
    int maxLength = defaultMaxLength,
  }) {
    final safeExtension = _sanitizeExtension(extension);
    if (safeExtension.isEmpty) {
      return sanitize(filename, fallback: fallback, maxLength: maxLength);
    }

    final suffix = '.$safeExtension';
    final raw = filename?.trim();
    final hasSuffix =
        raw != null && raw.toLowerCase().endsWith(suffix.toLowerCase());
    final stemInput = hasSuffix
        ? raw.substring(0, raw.length - suffix.length)
        : raw;
    final safeFallback = _fallbackStem(fallback, suffix);
    final stem = _sanitizeStem(stemInput, safeFallback);
    final limit = maxLength < suffix.length + 1 ? suffix.length + 1 : maxLength;
    final safeStem = _limitLength(
      stem,
      limit - suffix.length,
      fallback: safeFallback,
    );
    return '$safeStem$suffix';
  }

  static String _sanitizeStem(String? value, String fallback) {
    var sanitized = (value ?? '').trim();
    sanitized = sanitized.replaceAll(_unsafeCharacters, '_');
    sanitized = sanitized.replaceAll(_repeatedSeparators, '_');
    sanitized = sanitized.replaceAll(RegExp(r'^[._\s]+|[._\s]+$'), '');
    if (sanitized.isEmpty) sanitized = fallback;
    if (_reservedDeviceName.hasMatch(sanitized)) {
      sanitized = '${sanitized}_export';
    }
    return sanitized;
  }

  static String _sanitizeExtension(String extension) {
    return extension
        .replaceAll(RegExp(r'^\.+'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '')
        .toLowerCase();
  }

  static String _fallbackStem(String fallback, String suffix) {
    final raw = fallback.trim();
    final stem = raw.toLowerCase().endsWith(suffix.toLowerCase())
        ? raw.substring(0, raw.length - suffix.length)
        : raw;
    return _sanitizeStem(stem, defaultFallback);
  }

  static int? _extensionIndex(String? filename) {
    if (filename == null) return null;
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == filename.length - 1) return null;
    return dotIndex;
  }

  static String _limitLength(
    String value,
    int maxLength, {
    required String fallback,
  }) {
    if (value.length <= maxLength) return value;
    final clamped = value.substring(0, maxLength);
    final trimmed = clamped.replaceAll(RegExp(r'[._\s]+$'), '');
    if (trimmed.isNotEmpty) return trimmed;
    final fallbackEnd = fallback.length < maxLength
        ? fallback.length
        : maxLength;
    return fallback.substring(0, fallbackEnd);
  }
}
