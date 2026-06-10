import 'chart_api_field_names.dart';
import 'chart_api_field_spec.dart';

class ChartApiFieldSpecs {
  static const structure = [
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.type,
      aliases: ChartApiFieldNames.typeAliases,
      category: ChartApiFieldCategory.structure,
      valueKind: ChartApiFieldValueKind.string,
      description: 'Chart type discriminator used by JSON and builders.',
      widgetFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.title,
      aliases: ChartApiFieldNames.titleAliases,
      category: ChartApiFieldCategory.structure,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Chart title configuration.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.series,
      aliases: ChartApiFieldNames.seriesAliases,
      category: ChartApiFieldCategory.structure,
      valueKind: ChartApiFieldValueKind.list,
      description: 'One or more data series.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.xAxis,
      aliases: ChartApiFieldNames.xAxisAliases,
      category: ChartApiFieldCategory.structure,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Horizontal axis configuration.',
      widgetFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.yAxis,
      aliases: ChartApiFieldNames.yAxisAliases,
      category: ChartApiFieldCategory.structure,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Vertical axis configuration.',
      widgetFriendly: false,
    ),
  ];

  static const display = [
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.legend,
      aliases: ChartApiFieldNames.legendAliases,
      category: ChartApiFieldCategory.display,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Legend configuration.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.theme,
      aliases: ChartApiFieldNames.themeAliases,
      category: ChartApiFieldCategory.display,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Chart theme or styling system.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.showGrid,
      aliases: ChartApiFieldNames.showGridAliases,
      category: ChartApiFieldCategory.display,
      valueKind: ChartApiFieldValueKind.boolean,
      description: 'Toggles gridline rendering.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.showLegend,
      aliases: ChartApiFieldNames.showLegendAliases,
      category: ChartApiFieldCategory.display,
      valueKind: ChartApiFieldValueKind.boolean,
      description: 'Toggles legend rendering.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.showValues,
      aliases: ChartApiFieldNames.showValuesAliases,
      category: ChartApiFieldCategory.display,
      valueKind: ChartApiFieldValueKind.boolean,
      description: 'Toggles visible data values.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.showLabels,
      aliases: ChartApiFieldNames.showLabelsAliases,
      category: ChartApiFieldCategory.display,
      valueKind: ChartApiFieldValueKind.boolean,
      description: 'Toggles visible labels.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.showAxisLabels,
      aliases: ChartApiFieldNames.showAxisLabelsAliases,
      category: ChartApiFieldCategory.display,
      valueKind: ChartApiFieldValueKind.boolean,
      description: 'Toggles visible axis labels.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.emptyBuilder,
      aliases: ChartApiFieldNames.emptyBuilderAliases,
      category: ChartApiFieldCategory.display,
      valueKind: ChartApiFieldValueKind.widgetBuilder,
      description: 'Builds an empty-state placeholder.',
      configFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.palette,
      aliases: ChartApiFieldNames.paletteAliases,
      category: ChartApiFieldCategory.display,
      valueKind: ChartApiFieldValueKind.list,
      description: 'Color palette used for chart marks.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.radius,
      aliases: ChartApiFieldNames.radiusAliases,
      category: ChartApiFieldCategory.display,
      valueKind: ChartApiFieldValueKind.number,
      description: 'Corner, node, point, or mark radius.',
    ),
  ];

  static const interaction = [
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.tooltip,
      aliases: ChartApiFieldNames.tooltipAliases,
      category: ChartApiFieldCategory.interaction,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Tooltip configuration for config-driven charts.',
      widgetFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.toolbox,
      aliases: ChartApiFieldNames.toolboxAliases,
      category: ChartApiFieldCategory.interaction,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Toolbox controls for config-driven charts.',
      widgetFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.controller,
      aliases: ChartApiFieldNames.controllerAliases,
      category: ChartApiFieldCategory.interaction,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Controller used for external chart coordination.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.showTooltip,
      aliases: ChartApiFieldNames.showTooltipAliases,
      category: ChartApiFieldCategory.interaction,
      valueKind: ChartApiFieldValueKind.boolean,
      description: 'Toggles tooltip interaction.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.showActiveElement,
      aliases: ChartApiFieldNames.showActiveElementAliases,
      category: ChartApiFieldCategory.interaction,
      valueKind: ChartApiFieldValueKind.boolean,
      description: 'Toggles highlighted hover or selection affordances.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.onElementTap,
      aliases: ChartApiFieldNames.onElementTapAliases,
      category: ChartApiFieldCategory.interaction,
      valueKind: ChartApiFieldValueKind.callback,
      description: 'Callback for primary chart element taps.',
      configFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.onElementHover,
      aliases: ChartApiFieldNames.onElementHoverAliases,
      category: ChartApiFieldCategory.interaction,
      valueKind: ChartApiFieldValueKind.callback,
      description: 'Callback for primary chart element hover changes.',
      configFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.onSelectionChanged,
      aliases: ChartApiFieldNames.onSelectionChangedAliases,
      category: ChartApiFieldCategory.interaction,
      valueKind: ChartApiFieldValueKind.callback,
      description: 'Callback for selection state changes.',
      configFriendly: false,
    ),
  ];

  static const formatting = [
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.valueFormatter,
      aliases: ChartApiFieldNames.valueFormatterAliases,
      category: ChartApiFieldCategory.formatting,
      valueKind: ChartApiFieldValueKind.formatter,
      description: 'Formats numeric data values.',
      configFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.labelFormatter,
      aliases: ChartApiFieldNames.labelFormatterAliases,
      category: ChartApiFieldCategory.formatting,
      valueKind: ChartApiFieldValueKind.formatter,
      description: 'Formats category or item labels.',
      configFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.axisLabelFormatter,
      aliases: ChartApiFieldNames.axisLabelFormatterAliases,
      category: ChartApiFieldCategory.formatting,
      valueKind: ChartApiFieldValueKind.formatter,
      description: 'Formats axis labels.',
      configFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.tooltipBuilder,
      aliases: ChartApiFieldNames.tooltipBuilderAliases,
      category: ChartApiFieldCategory.formatting,
      valueKind: ChartApiFieldValueKind.widgetBuilder,
      description: 'Builds custom tooltip content.',
      configFriendly: false,
    ),
  ];

  static const accessibility = [
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.semanticLabel,
      aliases: ChartApiFieldNames.semanticLabelAliases,
      category: ChartApiFieldCategory.accessibility,
      valueKind: ChartApiFieldValueKind.string,
      description: 'Accessible chart label for assistive technologies.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.excludeFromSemantics,
      aliases: ChartApiFieldNames.excludeFromSemanticsAliases,
      category: ChartApiFieldCategory.accessibility,
      valueKind: ChartApiFieldValueKind.boolean,
      description: 'Hides decorative charts from assistive technologies.',
    ),
  ];

  static const animation = [
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.animationDuration,
      aliases: ChartApiFieldNames.animationDurationAliases,
      category: ChartApiFieldCategory.animation,
      valueKind: ChartApiFieldValueKind.duration,
      description: 'Chart transition duration.',
      configFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.animationCurve,
      aliases: ChartApiFieldNames.animationCurveAliases,
      category: ChartApiFieldCategory.animation,
      valueKind: ChartApiFieldValueKind.curve,
      description: 'Chart transition easing curve.',
      configFriendly: false,
    ),
  ];

  static const layout = [
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.grid,
      aliases: ChartApiFieldNames.gridAliases,
      category: ChartApiFieldCategory.layout,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Cartesian chart plot-area layout.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.height,
      aliases: ChartApiFieldNames.heightAliases,
      category: ChartApiFieldCategory.layout,
      valueKind: ChartApiFieldValueKind.number,
      description: 'Preferred chart height.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.padding,
      aliases: ChartApiFieldNames.paddingAliases,
      category: ChartApiFieldCategory.layout,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Chart outer or plot padding.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.minValue,
      aliases: ChartApiFieldNames.minValueAliases,
      category: ChartApiFieldCategory.layout,
      valueKind: ChartApiFieldValueKind.number,
      description: 'Lower visible domain bound.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.maxValue,
      aliases: ChartApiFieldNames.maxValueAliases,
      category: ChartApiFieldCategory.layout,
      valueKind: ChartApiFieldValueKind.number,
      description: 'Upper visible domain bound.',
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.spacing,
      aliases: ChartApiFieldNames.spacingAliases,
      category: ChartApiFieldCategory.layout,
      valueKind: ChartApiFieldValueKind.number,
      description: 'Visual gap between marks or groups.',
    ),
  ];

  static const runtime = [
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.dataMode,
      aliases: ChartApiFieldNames.dataModeAliases,
      category: ChartApiFieldCategory.runtime,
      valueKind: ChartApiFieldValueKind.string,
      description: 'Runtime data mode for regular or large datasets.',
      widgetFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.sampling,
      aliases: ChartApiFieldNames.samplingAliases,
      category: ChartApiFieldCategory.runtime,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Large-data sampling configuration.',
      widgetFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.performancePolicy,
      aliases: ChartApiFieldNames.performancePolicyAliases,
      category: ChartApiFieldCategory.runtime,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Runtime performance diagnostics policy.',
      widgetFriendly: false,
    ),
    ChartApiFieldSpec(
      canonicalField: ChartApiFieldNames.diagnostics,
      aliases: ChartApiFieldNames.diagnosticsAliases,
      category: ChartApiFieldCategory.runtime,
      valueKind: ChartApiFieldValueKind.object,
      description: 'Runtime diagnostics configuration.',
      widgetFriendly: false,
    ),
  ];

  static const List<ChartApiFieldSpec> all = [
    ...structure,
    ...display,
    ...interaction,
    ...formatting,
    ...accessibility,
    ...animation,
    ...layout,
    ...runtime,
  ];

  const ChartApiFieldSpecs._();
}
