import 'json_value.dart';

/// Helpers for chart payloads that follow the common `series[0].data` shape.
class ChartSeriesJson {
  const ChartSeriesJson._();

  static List<Map<String, dynamic>> mapList(Object? raw) {
    return JsonValue.mapList(raw) ?? const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> firstSeries(Object? raw) {
    final series = mapList(raw);
    return series.isEmpty ? const <String, dynamic>{} : series.first;
  }

  static List<Map<String, dynamic>> firstSeriesData(Object? raw) {
    return mapList(firstSeries(raw)['data']);
  }

  static List<dynamic> firstSeriesRawData(Object? raw) {
    return JsonValue.list(firstSeries(raw)['data']) ?? const <dynamic>[];
  }
}
