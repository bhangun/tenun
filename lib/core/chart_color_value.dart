import 'dart:ui';

import 'json_value.dart';
import 'utils/helper.dart';

/// Defensive parser for JSON-like color values used by chart configs.
class ChartColorValue {
  const ChartColorValue._();

  static Color? colorOrNull(Object? raw) {
    if (raw is Color) return raw;
    if (raw is int) return Color(raw);
    if (raw is num && raw.isFinite) return Color(raw.toInt());

    final text = JsonValue.string(raw)?.trim();
    if (text == null || text.isEmpty) return null;

    final namedOrCss = tryStringToColor(text);
    if (namedOrCss != null) return namedOrCss;

    final normalized = text.toLowerCase().startsWith('0x')
        ? text.substring(2)
        : text;
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return null;

    return Color(normalized.length <= 6 ? 0xFF000000 | parsed : parsed);
  }

  static Color colorOrFallback(Object? raw, Color fallback) {
    return colorOrNull(raw) ?? fallback;
  }
}
