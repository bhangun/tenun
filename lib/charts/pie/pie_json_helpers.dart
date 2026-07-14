import 'package:tenun_core/core/chart_model.dart';
import 'package:tenun_core/core/grid.dart';
import 'package:tenun_core/core/json_value.dart';
import 'package:tenun_core/core/legend.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/tooltip.dart';

/// Shared defensive JSON helpers for pie-style chart configurations.
///
/// Pie variants commonly accept either a top-level `slices` list or an
/// ECharts-like `series[].data` payload. Keeping that normalization here makes
/// each config factory smaller and keeps future pie variants consistent.
class PieJson {
  const PieJson._();

  static List<Map<String, dynamic>> mapList(Object? raw) {
    return JsonValue.mapList(raw) ?? const <Map<String, dynamic>>[];
  }

  static List<Map<String, dynamic>> sliceMaps(
    Map<String, dynamic> json, {
    List<String> directKeys = const ['slices'],
    String seriesKey = 'series',
  }) {
    for (final key in directKeys) {
      final direct = mapList(json[key]);
      if (direct.isNotEmpty) return direct;
    }
    return seriesSliceMaps(json[seriesKey]);
  }

  static List<Map<String, dynamic>> seriesMaps(Object? raw) {
    final single = JsonValue.map(raw);
    if (single != null) return <Map<String, dynamic>>[single];
    return mapList(raw);
  }

  static List<Map<String, dynamic>> seriesSliceMaps(Object? raw) {
    final series = seriesMaps(raw);
    final out = <Map<String, dynamic>>[];
    for (final item in series) {
      final data = mapList(item['data']);
      if (data.isNotEmpty) {
        out.addAll(data);
      } else if (item.containsKey('value')) {
        out.add(item);
      }
    }
    return out;
  }

  static String? string(Object? raw) => JsonValue.string(raw);

  static double doubleOr(Object? raw, double fallback) {
    return JsonValue.doubleOrNull(raw) ?? fallback;
  }

  static double nonNegativeDouble(Object? raw, double fallback) {
    final value = doubleOr(raw, fallback);
    return value < 0 ? 0 : value;
  }

  static double angleGap(Object? raw, double fallback) {
    return doubleOr(raw, fallback).clamp(0.0, 1.5707963267948966).toDouble();
  }

  static double ratio(Object? raw, double fallback) {
    return doubleOr(raw, fallback).clamp(0.0, 1.0).toDouble();
  }

  static int intOr(Object? raw, int fallback) {
    return JsonValue.intOrNull(raw) ?? fallback;
  }

  static bool boolOr(Object? raw, bool fallback) {
    return JsonValue.boolOrNull(raw) ?? fallback;
  }

  static TitlesData? title(Object? raw) {
    final json = JsonValue.map(raw);
    return json == null ? null : TitlesData.fromJson(json);
  }

  static ChartTooltip? tooltip(Object? raw) {
    final json = JsonValue.map(raw);
    return json == null ? null : ChartTooltip.fromJson(json);
  }

  static ChartLegend? legend(Object? raw) {
    final json = JsonValue.map(raw);
    return json == null ? null : ChartLegend.fromJson(json);
  }

  static ChartToolbox? toolbox(Object? raw) {
    final json = JsonValue.map(raw);
    return json == null ? null : ChartToolbox.fromJson(json);
  }

  static GridData? grid(Object? raw) {
    final json = JsonValue.map(raw);
    return json == null ? null : GridData.fromJson(json);
  }
}
