export 'chart_api_field_names.dart';
export 'chart_api_field_spec.dart';

import 'chart_api_field_names.dart';
import 'chart_api_field_spec.dart';
import 'chart_api_field_specs.dart';

/// Canonical chart API field names shared by JSON configs, builders, and
/// direct chart widgets.
class ChartApiFields {
  static const String type = ChartApiFieldNames.type;
  static const String title = ChartApiFieldNames.title;
  static const String tooltip = ChartApiFieldNames.tooltip;
  static const String legend = ChartApiFieldNames.legend;
  static const String toolbox = ChartApiFieldNames.toolbox;
  static const String grid = ChartApiFieldNames.grid;
  static const String series = ChartApiFieldNames.series;
  static const String theme = ChartApiFieldNames.theme;
  static const String controller = ChartApiFieldNames.controller;
  static const String xAxis = ChartApiFieldNames.xAxis;
  static const String yAxis = ChartApiFieldNames.yAxis;
  static const String showGrid = ChartApiFieldNames.showGrid;
  static const String showLegend = ChartApiFieldNames.showLegend;
  static const String showTooltip = ChartApiFieldNames.showTooltip;
  static const String showValues = ChartApiFieldNames.showValues;
  static const String showLabels = ChartApiFieldNames.showLabels;
  static const String showAxisLabels = ChartApiFieldNames.showAxisLabels;
  static const String showActiveElement = ChartApiFieldNames.showActiveElement;
  static const String valueFormatter = ChartApiFieldNames.valueFormatter;
  static const String labelFormatter = ChartApiFieldNames.labelFormatter;
  static const String axisLabelFormatter =
      ChartApiFieldNames.axisLabelFormatter;
  static const String tooltipBuilder = ChartApiFieldNames.tooltipBuilder;
  static const String emptyBuilder = ChartApiFieldNames.emptyBuilder;
  static const String semanticLabel = ChartApiFieldNames.semanticLabel;
  static const String excludeFromSemantics =
      ChartApiFieldNames.excludeFromSemantics;
  static const String animationDuration = ChartApiFieldNames.animationDuration;
  static const String animationCurve = ChartApiFieldNames.animationCurve;
  static const String height = ChartApiFieldNames.height;
  static const String padding = ChartApiFieldNames.padding;
  static const String palette = ChartApiFieldNames.palette;
  static const String minValue = ChartApiFieldNames.minValue;
  static const String maxValue = ChartApiFieldNames.maxValue;
  static const String radius = ChartApiFieldNames.radius;
  static const String spacing = ChartApiFieldNames.spacing;
  static const String onElementTap = ChartApiFieldNames.onElementTap;
  static const String onElementHover = ChartApiFieldNames.onElementHover;
  static const String onSelectionChanged =
      ChartApiFieldNames.onSelectionChanged;
  static const String dataMode = ChartApiFieldNames.dataMode;
  static const String sampling = ChartApiFieldNames.sampling;
  static const String performancePolicy = ChartApiFieldNames.performancePolicy;
  static const String diagnostics = ChartApiFieldNames.diagnostics;

  static const List<ChartApiFieldSpec> fieldSpecs = ChartApiFieldSpecs.all;
  static const List<String> canonicalFields =
      ChartApiFieldNames.canonicalFields;
  static const Set<String> allAliases = ChartApiFieldNames.allAliases;

  static String get suggestion => ChartApiFieldNames.suggestion;

  const ChartApiFields._();

  static String normalizeFieldName(String field) => field.trim();

  static String? canonicalFieldFor(String field) {
    final normalized = normalizeFieldName(field);
    for (final spec in fieldSpecs) {
      if (spec.matches(normalized)) return spec.canonicalField;
    }
    return null;
  }

  static ChartApiFieldSpec? specFor(String field) {
    final canonical = canonicalFieldFor(field);
    if (canonical == null) return null;
    for (final spec in fieldSpecs) {
      if (spec.canonicalField == canonical) return spec;
    }
    return null;
  }

  static List<String> aliasesFor(String canonicalField) {
    for (final spec in fieldSpecs) {
      if (spec.canonicalField == canonicalField) {
        return List<String>.from(spec.aliases);
      }
    }
    return const <String>[];
  }

  static List<Map<String, dynamic>> schemaJson() {
    return [for (final spec in fieldSpecs) spec.toJson()];
  }

  static bool containsAny(Map<Object?, Object?> map) {
    return allAliases.any(map.containsKey);
  }

  static String? firstField(
    Map<Object?, Object?> map,
    Iterable<String> aliases,
  ) {
    for (final alias in aliases) {
      if (map.containsKey(alias)) return alias;
    }
    return null;
  }

  static Object? readValue(
    Map<Object?, Object?> map,
    Iterable<String> aliases,
  ) {
    final field = firstField(map, aliases);
    return field == null ? null : map[field];
  }

  static String path(String prefix, String field) {
    return prefix.isEmpty ? field : '$prefix.$field';
  }
}
