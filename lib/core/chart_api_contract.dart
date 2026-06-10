import 'chart_api_fields.dart';

enum ChartApiFamily {
  optionConfig,
  simpleWidget,
  cartesian,
  polar,
  statistical,
  hierarchyFlow,
  temporal,
  financial,
  densitySpatial,
}

class ChartApiContract {
  final String name;
  final ChartApiFamily family;
  final String description;
  final List<String> supportedFields;
  final List<String> recommendedFields;

  const ChartApiContract({
    required this.name,
    required this.family,
    required this.description,
    required this.supportedFields,
    this.recommendedFields = const <String>[],
  });

  bool supports(String field) {
    final canonical = ChartApiFields.canonicalFieldFor(field);
    return canonical != null && supportedFields.contains(canonical);
  }

  bool recommends(String field) {
    final canonical = ChartApiFields.canonicalFieldFor(field);
    return canonical != null && recommendedFields.contains(canonical);
  }

  List<ChartApiFieldSpec> get supportedSpecs {
    final specs = <ChartApiFieldSpec>[];
    for (final field in supportedFields) {
      final spec = ChartApiFields.specFor(field);
      if (spec != null) specs.add(spec);
    }
    return specs;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'family': family.name,
    'description': description,
    'supportedFields': List<String>.from(supportedFields),
    'recommendedFields': List<String>.from(recommendedFields),
  };
}

/// Shared contracts for the major Tenun chart API surfaces.
class ChartApiContracts {
  static const List<String> configFoundationFields = [
    ChartApiFields.type,
    ChartApiFields.title,
    ChartApiFields.tooltip,
    ChartApiFields.legend,
    ChartApiFields.toolbox,
    ChartApiFields.grid,
    ChartApiFields.series,
    ChartApiFields.theme,
    ChartApiFields.controller,
    ChartApiFields.xAxis,
    ChartApiFields.yAxis,
    ChartApiFields.dataMode,
    ChartApiFields.sampling,
    ChartApiFields.performancePolicy,
    ChartApiFields.diagnostics,
  ];

  static const List<String> widgetFoundationFields = [
    ChartApiFields.showTooltip,
    ChartApiFields.emptyBuilder,
    ChartApiFields.semanticLabel,
    ChartApiFields.excludeFromSemantics,
    ChartApiFields.animationDuration,
    ChartApiFields.animationCurve,
  ];

  static const List<String> displayFields = [
    ChartApiFields.showGrid,
    ChartApiFields.showLegend,
    ChartApiFields.showValues,
    ChartApiFields.showLabels,
    ChartApiFields.showAxisLabels,
    ChartApiFields.palette,
  ];

  static const List<String> layoutFields = [
    ChartApiFields.height,
    ChartApiFields.padding,
    ChartApiFields.minValue,
    ChartApiFields.maxValue,
    ChartApiFields.radius,
    ChartApiFields.spacing,
  ];

  static const List<String> formatterFields = [
    ChartApiFields.valueFormatter,
    ChartApiFields.labelFormatter,
    ChartApiFields.axisLabelFormatter,
    ChartApiFields.tooltipBuilder,
  ];

  static const List<String> interactionFields = [
    ChartApiFields.showActiveElement,
    ChartApiFields.onElementTap,
    ChartApiFields.onElementHover,
    ChartApiFields.onSelectionChanged,
  ];

  static const optionConfig = ChartApiContract(
    name: 'optionConfig',
    family: ChartApiFamily.optionConfig,
    description: 'Config and JSON-driven chart APIs.',
    supportedFields: configFoundationFields,
    recommendedFields: [
      ChartApiFields.type,
      ChartApiFields.series,
      ChartApiFields.theme,
      ChartApiFields.tooltip,
      ChartApiFields.legend,
    ],
  );

  static const simpleWidget = ChartApiContract(
    name: 'simpleWidget',
    family: ChartApiFamily.simpleWidget,
    description: 'Direct Flutter widget chart APIs.',
    supportedFields: [
      ...widgetFoundationFields,
      ...displayFields,
      ...layoutFields,
      ...formatterFields,
      ...interactionFields,
    ],
    recommendedFields: [
      ChartApiFields.showTooltip,
      ChartApiFields.emptyBuilder,
      ChartApiFields.semanticLabel,
      ChartApiFields.excludeFromSemantics,
      ChartApiFields.animationDuration,
      ChartApiFields.animationCurve,
    ],
  );

  static const cartesian = ChartApiContract(
    name: 'cartesian',
    family: ChartApiFamily.cartesian,
    description: 'Bar, line, area, scatter, range, and cartesian composites.',
    supportedFields: [
      ...configFoundationFields,
      ...widgetFoundationFields,
      ...displayFields,
      ...layoutFields,
      ...formatterFields,
      ...interactionFields,
    ],
    recommendedFields: [
      ChartApiFields.showGrid,
      ChartApiFields.showAxisLabels,
      ChartApiFields.valueFormatter,
      ChartApiFields.showTooltip,
    ],
  );

  static const polar = ChartApiContract(
    name: 'polar',
    family: ChartApiFamily.polar,
    description: 'Radar, radial, rose, gauge, and other circular charts.',
    supportedFields: [
      ...configFoundationFields,
      ...widgetFoundationFields,
      ChartApiFields.showLegend,
      ChartApiFields.showLabels,
      ChartApiFields.palette,
      ChartApiFields.radius,
      ChartApiFields.valueFormatter,
      ChartApiFields.labelFormatter,
      ChartApiFields.tooltipBuilder,
      ...interactionFields,
    ],
    recommendedFields: [
      ChartApiFields.showLabels,
      ChartApiFields.showLegend,
      ChartApiFields.palette,
    ],
  );

  static const statistical = ChartApiContract(
    name: 'statistical',
    family: ChartApiFamily.statistical,
    description:
        'Distribution, uncertainty, and statistical comparison charts.',
    supportedFields: [
      ...configFoundationFields,
      ...widgetFoundationFields,
      ...displayFields,
      ...layoutFields,
      ...formatterFields,
      ...interactionFields,
    ],
    recommendedFields: [
      ChartApiFields.showGrid,
      ChartApiFields.valueFormatter,
      ChartApiFields.tooltipBuilder,
      ChartApiFields.semanticLabel,
    ],
  );

  static const hierarchyFlow = ChartApiContract(
    name: 'hierarchyFlow',
    family: ChartApiFamily.hierarchyFlow,
    description: 'Tree, treemap, sankey, chord, network, and flow charts.',
    supportedFields: [
      ...configFoundationFields,
      ...widgetFoundationFields,
      ChartApiFields.showLabels,
      ChartApiFields.showLegend,
      ChartApiFields.palette,
      ChartApiFields.padding,
      ChartApiFields.spacing,
      ChartApiFields.radius,
      ChartApiFields.labelFormatter,
      ChartApiFields.tooltipBuilder,
      ...interactionFields,
    ],
    recommendedFields: [
      ChartApiFields.showLabels,
      ChartApiFields.onElementTap,
      ChartApiFields.tooltipBuilder,
    ],
  );

  static const temporal = ChartApiContract(
    name: 'temporal',
    family: ChartApiFamily.temporal,
    description: 'Timeline, gantt, event, milestone, and temporal charts.',
    supportedFields: [
      ...configFoundationFields,
      ...widgetFoundationFields,
      ...displayFields,
      ...layoutFields,
      ...formatterFields,
      ...interactionFields,
    ],
    recommendedFields: [
      ChartApiFields.showAxisLabels,
      ChartApiFields.axisLabelFormatter,
      ChartApiFields.showTooltip,
    ],
  );

  static const financial = ChartApiContract(
    name: 'financial',
    family: ChartApiFamily.financial,
    description: 'Candlestick, OHLC, volume, and trading charts.',
    supportedFields: [
      ...configFoundationFields,
      ...widgetFoundationFields,
      ...displayFields,
      ...layoutFields,
      ...formatterFields,
      ...interactionFields,
    ],
    recommendedFields: [
      ChartApiFields.showGrid,
      ChartApiFields.axisLabelFormatter,
      ChartApiFields.valueFormatter,
      ChartApiFields.showTooltip,
    ],
  );

  static const densitySpatial = ChartApiContract(
    name: 'densitySpatial',
    family: ChartApiFamily.densitySpatial,
    description: 'Heatmap, matrix, contour, hexbin, map, and density charts.',
    supportedFields: [
      ...configFoundationFields,
      ...widgetFoundationFields,
      ChartApiFields.showLegend,
      ChartApiFields.showLabels,
      ChartApiFields.palette,
      ChartApiFields.padding,
      ChartApiFields.minValue,
      ChartApiFields.maxValue,
      ChartApiFields.valueFormatter,
      ChartApiFields.labelFormatter,
      ChartApiFields.tooltipBuilder,
      ...interactionFields,
    ],
    recommendedFields: [
      ChartApiFields.palette,
      ChartApiFields.showLegend,
      ChartApiFields.valueFormatter,
      ChartApiFields.tooltipBuilder,
    ],
  );

  static const List<ChartApiContract> all = [
    optionConfig,
    simpleWidget,
    cartesian,
    polar,
    statistical,
    hierarchyFlow,
    temporal,
    financial,
    densitySpatial,
  ];

  const ChartApiContracts._();

  static ChartApiContract? byName(String name) {
    for (final contract in all) {
      if (contract.name == name) return contract;
    }
    return null;
  }

  static List<ChartApiContract> supporting(String field) {
    return [
      for (final contract in all)
        if (contract.supports(field)) contract,
    ];
  }

  static List<Map<String, dynamic>> schemaJson() {
    return [for (final contract in all) contract.toJson()];
  }
}
