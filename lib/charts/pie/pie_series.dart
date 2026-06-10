import '../../core/json_value.dart';

class PieSeries {
  double? value;
  String? name;
  String? color;

  PieSeries({this.value, this.name, this.color});

  /// Converts a PieSeries instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {'value': value, 'name': name, 'color': color};
  }

  /// Creates a PieSeries instance from a JSON map.
  factory PieSeries.fromJson(Object? raw) {
    final json = JsonValue.map(raw) ?? const <String, dynamic>{};
    return PieSeries(
      value: JsonValue.doubleOrNull(json['value']),
      name: JsonValue.string(json['name']),
      color: JsonValue.string(json['color']),
    );
  }

  @override
  String toString() {
    return 'PieSeries(value: $value, name: $name)';
  }
}
