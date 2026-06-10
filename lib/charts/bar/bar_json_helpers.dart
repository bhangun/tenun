import '../../core/chart_data_value_reader.dart';
import '../../core/chart_model.dart';
import '../../core/chart_series_json.dart';
import '../../core/grid.dart';
import '../../core/json_value.dart';
import '../../core/legend.dart';
import '../../core/series.dart';
import '../../core/title.dart';
import '../../core/tooltip.dart';

/// Shared defensive JSON helpers for bar-style chart configurations.
///
/// Bar variants accept a mix of hand-authored Dart maps and decoded JSON. This
/// helper keeps parsing consistent across variants without growing each config
/// factory into a bespoke parser.
class BarJson {
  const BarJson._();

  static List<Series> series(Object? raw) {
    return ChartSeriesJson.mapList(
      raw,
    ).map(Series.fromJson).toList(growable: false);
  }

  static List<dynamic> list(Object? raw) {
    return JsonValue.list(raw) ?? const <dynamic>[];
  }

  static List<Map<String, dynamic>> mapList(Object? raw) {
    return JsonValue.mapList(raw) ?? const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic>? map(Object? raw) => JsonValue.map(raw);

  static Map<String, double> doubleMap(Object? raw) {
    final json = JsonValue.map(raw);
    if (json == null) return const <String, double>{};
    final values = <String, double>{};
    for (final entry in json.entries) {
      final value = doubleOrNull(entry.value);
      if (value != null) values[entry.key] = value;
    }
    return values;
  }

  static List<String> stringList(Object? raw) {
    return JsonValue.stringList(raw) ?? const <String>[];
  }

  static String? string(Object? raw) => JsonValue.string(raw);

  static double? doubleOrNull(Object? raw) {
    return ChartDataValueReader.yValueOrNull(raw);
  }

  static double doubleOr(Object? raw, double fallback) {
    return doubleOrNull(raw) ?? fallback;
  }

  static double nonNegativeDouble(Object? raw, double fallback) {
    final value = doubleOr(raw, fallback);
    return value < 0 ? 0 : value;
  }

  static double ratio(Object? raw, double fallback) {
    return doubleOr(raw, fallback).clamp(0.0, 1.0).toDouble();
  }

  static int positiveInt(Object? raw, int fallback) {
    final value = JsonValue.intOrNull(raw) ?? fallback;
    return value < 1 ? 1 : value;
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
