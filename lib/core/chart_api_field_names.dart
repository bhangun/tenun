class ChartApiFieldNames {
  static const String type = 'type';
  static const String title = 'title';
  static const String tooltip = 'tooltip';
  static const String legend = 'legend';
  static const String toolbox = 'toolbox';
  static const String grid = 'grid';
  static const String series = 'series';
  static const String theme = 'theme';
  static const String controller = 'controller';
  static const String xAxis = 'xAxis';
  static const String yAxis = 'yAxis';

  static const String showGrid = 'showGrid';
  static const String showLegend = 'showLegend';
  static const String showTooltip = 'showTooltip';
  static const String showValues = 'showValues';
  static const String showLabels = 'showLabels';
  static const String showAxisLabels = 'showAxisLabels';
  static const String showActiveElement = 'showActiveElement';

  static const String valueFormatter = 'valueFormatter';
  static const String labelFormatter = 'labelFormatter';
  static const String axisLabelFormatter = 'axisLabelFormatter';
  static const String tooltipBuilder = 'tooltipBuilder';
  static const String emptyBuilder = 'emptyBuilder';

  static const String semanticLabel = 'semanticLabel';
  static const String excludeFromSemantics = 'excludeFromSemantics';
  static const String animationDuration = 'animationDuration';
  static const String animationCurve = 'animationCurve';

  static const String height = 'height';
  static const String padding = 'padding';
  static const String palette = 'palette';
  static const String minValue = 'minValue';
  static const String maxValue = 'maxValue';
  static const String radius = 'radius';
  static const String spacing = 'spacing';

  static const String onElementTap = 'onElementTap';
  static const String onElementHover = 'onElementHover';
  static const String onSelectionChanged = 'onSelectionChanged';

  static const String dataMode = 'dataMode';
  static const String sampling = 'sampling';
  static const String performancePolicy = 'performancePolicy';
  static const String diagnostics = 'diagnostics';

  static const List<String> typeAliases = [type, 'chartType'];
  static const List<String> titleAliases = [title, 'titles', 'chartTitle'];
  static const List<String> tooltipAliases = [
    tooltip,
    'tooltips',
    'tooltipConfig',
  ];
  static const List<String> legendAliases = [legend, 'legendConfig'];
  static const List<String> toolboxAliases = [
    toolbox,
    'tools',
    'toolboxConfig',
  ];
  static const List<String> gridAliases = [grid, 'plotArea', 'gridConfig'];
  static const List<String> seriesAliases = [series, 'datasets', 'dataSeries'];
  static const List<String> themeAliases = [theme, 'chartTheme'];
  static const List<String> controllerAliases = [controller, 'chartController'];
  static const List<String> xAxisAliases = [
    xAxis,
    'xAxisConfig',
    'horizontalAxis',
  ];
  static const List<String> yAxisAliases = [
    yAxis,
    'yAxisConfig',
    'verticalAxis',
  ];

  static const List<String> showGridAliases = [showGrid, 'gridVisible'];
  static const List<String> showLegendAliases = [showLegend, 'legendVisible'];
  static const List<String> showTooltipAliases = [
    showTooltip,
    'enableTooltip',
    'showTooltips',
    'tooltipEnabled',
  ];
  static const List<String> showValuesAliases = [showValues, 'showDataValues'];
  static const List<String> showLabelsAliases = [showLabels, 'labelsVisible'];
  static const List<String> showAxisLabelsAliases = [
    showAxisLabels,
    'axisLabelsVisible',
  ];
  static const List<String> showActiveElementAliases = [
    showActiveElement,
    'showActivePoint',
    'showActiveBar',
    'showActiveCell',
    'showActiveBubble',
    'showActiveNode',
    'showActiveSegment',
    'showActiveTile',
    'showActiveBin',
    'showActiveBox',
    'showActiveWord',
    'showActiveRegion',
  ];

  static const List<String> valueFormatterAliases = [
    valueFormatter,
    'formatValue',
  ];
  static const List<String> labelFormatterAliases = [
    labelFormatter,
    'formatLabel',
  ];
  static const List<String> axisLabelFormatterAliases = [
    axisLabelFormatter,
    'formatAxisLabel',
  ];
  static const List<String> tooltipBuilderAliases = [
    tooltipBuilder,
    'buildTooltip',
  ];
  static const List<String> emptyBuilderAliases = [
    emptyBuilder,
    'buildEmpty',
    'emptyStateBuilder',
  ];

  static const List<String> semanticLabelAliases = [
    semanticLabel,
    'semanticsLabel',
    'accessibilityLabel',
  ];
  static const List<String> excludeFromSemanticsAliases = [
    excludeFromSemantics,
    'hideFromSemantics',
  ];
  static const List<String> animationDurationAliases = [
    animationDuration,
    'duration',
  ];
  static const List<String> animationCurveAliases = [animationCurve, 'curve'];

  static const List<String> heightAliases = [height, 'chartHeight'];
  static const List<String> paddingAliases = [padding, 'chartPadding'];
  static const List<String> paletteAliases = [
    palette,
    'colors',
    'colorPalette',
  ];
  static const List<String> minValueAliases = [minValue, 'minY', 'min'];
  static const List<String> maxValueAliases = [maxValue, 'maxY', 'max'];
  static const List<String> radiusAliases = [radius, 'cornerRadius'];
  static const List<String> spacingAliases = [spacing, 'gap'];

  static const List<String> onElementTapAliases = [
    onElementTap,
    'onPointTap',
    'onBarTap',
    'onCellTap',
    'onNodeTap',
    'onSegmentTap',
    'onItemTap',
  ];
  static const List<String> onElementHoverAliases = [
    onElementHover,
    'onPointHover',
    'onBarHover',
    'onCellHover',
    'onNodeHover',
    'onSegmentHover',
    'onItemHover',
  ];
  static const List<String> onSelectionChangedAliases = [
    onSelectionChanged,
    'onSelectionChange',
    'onSelected',
  ];

  static const List<String> dataModeAliases = [dataMode, 'chartDataMode'];
  static const List<String> samplingAliases = [
    sampling,
    'dataSampling',
    'samplingPolicy',
  ];
  static const List<String> performancePolicyAliases = [
    performancePolicy,
    'runtimePerformancePolicy',
  ];
  static const List<String> diagnosticsAliases = [
    diagnostics,
    'runtimeDiagnostics',
  ];

  static const List<String> canonicalFields = [
    type,
    title,
    tooltip,
    legend,
    toolbox,
    grid,
    series,
    theme,
    controller,
    xAxis,
    yAxis,
    showGrid,
    showLegend,
    showTooltip,
    showValues,
    showLabels,
    showAxisLabels,
    showActiveElement,
    valueFormatter,
    labelFormatter,
    axisLabelFormatter,
    tooltipBuilder,
    emptyBuilder,
    semanticLabel,
    excludeFromSemantics,
    animationDuration,
    animationCurve,
    height,
    padding,
    palette,
    minValue,
    maxValue,
    radius,
    spacing,
    onElementTap,
    onElementHover,
    onSelectionChanged,
    dataMode,
    sampling,
    performancePolicy,
    diagnostics,
  ];

  static const Set<String> allAliases = {
    ...typeAliases,
    ...titleAliases,
    ...tooltipAliases,
    ...legendAliases,
    ...toolboxAliases,
    ...gridAliases,
    ...seriesAliases,
    ...themeAliases,
    ...controllerAliases,
    ...xAxisAliases,
    ...yAxisAliases,
    ...showGridAliases,
    ...showLegendAliases,
    ...showTooltipAliases,
    ...showValuesAliases,
    ...showLabelsAliases,
    ...showAxisLabelsAliases,
    ...showActiveElementAliases,
    ...valueFormatterAliases,
    ...labelFormatterAliases,
    ...axisLabelFormatterAliases,
    ...tooltipBuilderAliases,
    ...emptyBuilderAliases,
    ...semanticLabelAliases,
    ...excludeFromSemanticsAliases,
    ...animationDurationAliases,
    ...animationCurveAliases,
    ...heightAliases,
    ...paddingAliases,
    ...paletteAliases,
    ...minValueAliases,
    ...maxValueAliases,
    ...radiusAliases,
    ...spacingAliases,
    ...onElementTapAliases,
    ...onElementHoverAliases,
    ...onSelectionChangedAliases,
    ...dataModeAliases,
    ...samplingAliases,
    ...performancePolicyAliases,
    ...diagnosticsAliases,
  };

  static String get suggestion =>
      'Use ${canonicalFields.take(canonicalFields.length - 1).join(', ')}, '
      'or ${canonicalFields.last}.';

  const ChartApiFieldNames._();
}
