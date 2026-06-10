import '../core/chart_registry.dart';
import '../core/chart_type.dart';

// Chart config imports
import '../charts/area/area_chart_config.dart';
import '../charts/bar/bar_config.dart';
import '../charts/line/line_config.dart';
import '../charts/scatter/scatter_config.dart';
import '../charts/combo/combo_chart.dart';
import '../charts/histogram/histogram_chart.dart';
import '../charts/lollipop/lollipop_chart.dart';
import '../charts/rigeline/ridgeline_strip_error_bar_charts.dart';
import '../charts/bar/bar_chart_variants.dart' as v3bar;
import '../charts/line/line_area_variants.dart' as v3line;
import '../charts/slope/slope_dumbbell_areabump_charts.dart' as v3slope;
import '../charts/bar/rainfall_chart.dart';
import '../charts/line/multi_x_axes_chart.dart';
import '../charts/line/line_style_item_chart.dart';
import '../charts/area/large_scale_area_chart.dart';
import '../charts/area/area_time_axis_chart.dart';

const Set<ChartType> cartesianTypes = {
  ChartType.bar,
  ChartType.stackedBar,
  ChartType.groupedBar,
  ChartType.horizontalBar,
  ChartType.stackedHorizontalBar,
  ChartType.line,
  ChartType.lineArea,
  ChartType.area,
  ChartType.stackedArea,
  ChartType.scatter,
  ChartType.bubble,
  ChartType.strip,
  ChartType.combo,
  ChartType.histogram,
  ChartType.lollipop,
  ChartType.ridgeline,
  ChartType.errorBar,
  ChartType.slope,
  ChartType.dumbbell,
  ChartType.areaBump,
  ChartType.barBackground,
  ChartType.barRace,
  ChartType.barGradient,
  ChartType.barLabelRotation,
  ChartType.barRounded,
  ChartType.barNormalized,
  ChartType.negativeBar,
  ChartType.barBrush,
  ChartType.rainfall,
  ChartType.areaPieces,
  ChartType.lineGradient,
  ChartType.lineConfidenceBand,
  ChartType.lineMarkline,
  ChartType.logAxis,
  ChartType.functionPlot,
  ChartType.dynamicTimeSeries,
  ChartType.intradayLine,
  ChartType.lineClickAdd,
  ChartType.multiXAxes,
  ChartType.lineStyleItem,
  ChartType.largeScaleArea,
  ChartType.areaTimeAxis,
};

final barRegistration = ChartRegistration(
  type: ChartType.bar,
  typeString: 'bar',
  aliases: const ['groupedbar', 'horizontalbar', 'stackedhorizontalbar'],
  fromJson: BarChartConfig.fromJson,
  description: 'Bar chart family',
  tags: const ['cartesian', 'bar'],
);

final stackedBarRegistration = ChartRegistration(
  type: ChartType.stackedBar,
  typeString: 'stackedbar',
  aliases: const ['stacked_bar'],
  fromJson: BarChartConfig.fromJson,
  description: 'Stacked bar chart',
  tags: const ['cartesian', 'bar'],
);

final groupedBarRegistration = ChartRegistration(
  type: ChartType.groupedBar,
  typeString: 'groupedbar',
  aliases: const ['grouped_bar'],
  fromJson: BarChartConfig.fromJson,
  description: 'Grouped bar chart',
  tags: const ['cartesian', 'bar'],
);

final horizontalBarRegistration = ChartRegistration(
  type: ChartType.horizontalBar,
  typeString: 'horizontalbar',
  aliases: const ['horizontal_bar'],
  fromJson: BarChartConfig.fromJson,
  description: 'Horizontal bar chart',
  tags: const ['cartesian', 'bar'],
);

final stackedHorizontalBarRegistration = ChartRegistration(
  type: ChartType.stackedHorizontalBar,
  typeString: 'stackedhorizontalbar',
  aliases: const ['stacked_horizontal_bar'],
  fromJson: BarChartConfig.fromJson,
  description: 'Stacked horizontal bar chart',
  tags: const ['cartesian', 'bar'],
);

final lineRegistration = ChartRegistration(
  type: ChartType.line,
  typeString: 'line',
  aliases: const ['sparkline'],
  fromJson: LineChartConfig.fromJson,
  description: 'Line chart family',
  tags: const ['cartesian', 'line'],
);

final lineAreaRegistration = ChartRegistration(
  type: ChartType.lineArea,
  typeString: 'linearea',
  aliases: const ['line_area'],
  fromJson: LineChartConfig.fromJson,
  description: 'Line area chart',
  tags: const ['cartesian', 'line'],
);

final areaRegistration = ChartRegistration(
  type: ChartType.area,
  typeString: 'area',
  aliases: const [],
  fromJson: AreaChartConfig.fromJson,
  description: 'Area chart family',
  tags: const ['cartesian', 'area'],
);

final stackedAreaRegistration = ChartRegistration(
  type: ChartType.stackedArea,
  typeString: 'stackedarea',
  aliases: const ['stacked_area'],
  fromJson: AreaChartConfig.fromJson,
  description: 'Stacked area chart',
  tags: const ['cartesian', 'area'],
);

final scatterRegistration = ChartRegistration(
  type: ChartType.scatter,
  typeString: 'scatter',
  aliases: const [],
  fromJson: ScatterChartConfig.fromJson,
  description: 'Scatter / bubble chart',
  tags: const ['cartesian', 'scatter'],
);

final bubbleRegistration = ChartRegistration(
  type: ChartType.bubble,
  typeString: 'bubble',
  fromJson: ScatterChartConfig.fromJson,
  description: 'Bubble chart',
  tags: const ['cartesian', 'scatter'],
);

final comboRegistration = ChartRegistration(
  type: ChartType.combo,
  typeString: 'combo',
  aliases: const ['mixed'],
  fromJson: ComboChartConfig.fromJson,
  description: 'Combo chart (bar + line)',
  tags: const ['cartesian', 'comparison'],
);

final histogramRegistration = ChartRegistration(
  type: ChartType.histogram,
  typeString: 'histogram',
  fromJson: HistogramChartConfig.fromJson,
  description: 'Histogram chart',
  tags: const ['cartesian', 'statistical'],
);

final lollipopRegistration = ChartRegistration(
  type: ChartType.lollipop,
  typeString: 'lollipop',
  fromJson: LollipopChartConfig.fromJson,
  description: 'Lollipop chart',
  tags: const ['cartesian', 'comparison'],
);

final ridgelineRegistration = ChartRegistration(
  type: ChartType.ridgeline,
  typeString: 'ridgeline',
  aliases: const ['ridge'],
  fromJson: RidgelineChartConfig.fromJson,
  description: 'Ridgeline chart',
  tags: const ['cartesian', 'statistical'],
);

final stripAdvancedRegistration = ChartRegistration(
  type: ChartType.strip,
  typeString: 'strip',
  aliases: const ['dotplot'],
  fromJson: StripChartConfig.fromJson,
  description: 'Strip chart',
  tags: const ['cartesian', 'statistical'],
);

final errorBarRegistration = ChartRegistration(
  type: ChartType.errorBar,
  typeString: 'errorbar',
  aliases: const ['error_bar'],
  fromJson: ErrorBarChartConfig.fromJson,
  description: 'Error bar chart',
  tags: const ['cartesian', 'statistical'],
);

final barBackgroundRegistration = ChartRegistration(
  type: ChartType.barBackground,
  typeString: 'barbackground',
  aliases: const ['barwithbackground', 'bartrack'],
  fromJson: v3bar.BarBackgroundChartConfig.fromJson,
  description: 'Bar chart with background track',
  tags: const ['cartesian', 'bar'],
);

final barRaceRegistration = ChartRegistration(
  type: ChartType.barRace,
  typeString: 'barrace',
  aliases: const ['racing', 'baranimation'],
  fromJson: v3bar.BarRaceChartConfig.fromJson,
  description: 'Animated bar race chart',
  tags: const ['cartesian', 'bar', 'animated'],
);

final barGradientRegistration = ChartRegistration(
  type: ChartType.barGradient,
  typeString: 'bargradient',
  aliases: const ['gradientbar'],
  fromJson: v3bar.BarGradientChartConfig.fromJson,
  description: 'Gradient bar chart',
  tags: const ['cartesian', 'bar'],
);

final barLabelRotationRegistration = ChartRegistration(
  type: ChartType.barLabelRotation,
  typeString: 'barlabelrotation',
  aliases: const ['rotatedlabels'],
  fromJson: v3bar.BarLabelRotationConfig.fromJson,
  description: 'Bar chart with rotated labels',
  tags: const ['cartesian', 'bar'],
);

final barRoundedRegistration = ChartRegistration(
  type: ChartType.barRounded,
  typeString: 'barrounded',
  aliases: const ['roundedstacked'],
  fromJson: v3bar.BarRoundedStackedConfig.fromJson,
  description: 'Rounded stacked bar chart',
  tags: const ['cartesian', 'bar'],
);

final barNormalizedRegistration = ChartRegistration(
  type: ChartType.barNormalized,
  typeString: 'barnormalized',
  aliases: const ['bar100', 'percentstacked'],
  fromJson: v3bar.BarNormalizedConfig.fromJson,
  description: '100% normalized stacked bar chart',
  tags: const ['cartesian', 'bar'],
);

final negativeBarRegistration = ChartRegistration(
  type: ChartType.negativeBar,
  typeString: 'negativebar',
  aliases: const ['divergingbar'],
  fromJson: v3bar.NegativeBarConfig.fromJson,
  description: 'Negative/positive diverging bar chart',
  tags: const ['cartesian', 'bar'],
);

final barBrushRegistration = ChartRegistration(
  type: ChartType.barBrush,
  typeString: 'barbrush',
  aliases: const ['brushbar'],
  fromJson: v3bar.BarBrushConfig.fromJson,
  description: 'Bar chart with brush selection',
  tags: const ['cartesian', 'bar', 'interactive'],
);

final areaPiecesRegistration = ChartRegistration(
  type: ChartType.areaPieces,
  typeString: 'areapieces',
  aliases: const ['thresholdarea'],
  fromJson: v3line.AreaPiecesChartConfig.fromJson,
  description: 'Threshold-based area pieces chart',
  tags: const ['cartesian', 'area'],
);

final lineGradientRegistration = ChartRegistration(
  type: ChartType.lineGradient,
  typeString: 'linegradient',
  aliases: const ['gradientline'],
  fromJson: v3line.LineGradientChartConfig.fromJson,
  description: 'Gradient line chart',
  tags: const ['cartesian', 'line'],
);

final lineConfidenceBandRegistration = ChartRegistration(
  type: ChartType.lineConfidenceBand,
  typeString: 'lineconfidenceband',
  aliases: const ['confidenceband', 'errorband'],
  fromJson: v3line.LineConfidenceBandConfig.fromJson,
  description: 'Line chart with confidence band',
  tags: const ['cartesian', 'line', 'statistical'],
);

final lineMarklineRegistration = ChartRegistration(
  type: ChartType.lineMarkline,
  typeString: 'linemarkline',
  aliases: const ['markline', 'referenceline'],
  fromJson: v3line.LineMarklineConfig.fromJson,
  description: 'Line chart with reference mark lines',
  tags: const ['cartesian', 'line'],
);

final logAxisRegistration = ChartRegistration(
  type: ChartType.logAxis,
  typeString: 'logaxis',
  aliases: const ['logarithmic'],
  fromJson: v3line.LogAxisChartConfig.fromJson,
  description: 'Logarithmic axis line chart',
  tags: const ['cartesian', 'line'],
);

final functionPlotRegistration = ChartRegistration(
  type: ChartType.functionPlot,
  typeString: 'functionplot',
  aliases: const ['function'],
  fromJson: v3line.FunctionPlotConfig.fromJson,
  description: 'Function plot chart',
  tags: const ['cartesian', 'math'],
);

final dynamicTimeSeriesRegistration = ChartRegistration(
  type: ChartType.dynamicTimeSeries,
  typeString: 'dynamictimeseries',
  aliases: const ['livechart', 'realtime'],
  fromJson: v3line.DynamicTimeSeriesConfig.fromJson,
  description: 'Dynamic time series chart',
  tags: const ['cartesian', 'line', 'realtime'],
);

final intradayLineRegistration = ChartRegistration(
  type: ChartType.intradayLine,
  typeString: 'intradayline',
  aliases: const ['intraday'],
  fromJson: v3line.IntradayLineConfig.fromJson,
  description: 'Intraday line chart',
  tags: const ['cartesian', 'line'],
);

final lineClickAddRegistration = ChartRegistration(
  type: ChartType.lineClickAdd,
  typeString: 'lineclickadd',
  aliases: const ['clicktoadd'],
  fromJson: v3line.LineClickAddConfig.fromJson,
  description: 'Interactive click-to-add line chart',
  tags: const ['cartesian', 'line', 'interactive'],
);

final slopeRegistration = ChartRegistration(
  type: ChartType.slope,
  typeString: 'slope',
  aliases: const ['slopegraph'],
  fromJson: v3slope.SlopeChartConfig.fromJson,
  description: 'Slope chart',
  tags: const ['cartesian', 'comparison'],
);

final dumbbellRegistration = ChartRegistration(
  type: ChartType.dumbbell,
  typeString: 'dumbbell',
  aliases: const ['dotrange'],
  fromJson: v3slope.DumbbellChartConfig.fromJson,
  description: 'Dumbbell chart',
  tags: const ['cartesian', 'comparison'],
);

final areaBumpRegistration = ChartRegistration(
  type: ChartType.areaBump,
  typeString: 'areabump',
  aliases: const ['bump'],
  fromJson: v3slope.AreaBumpChartConfig.fromJson,
  description: 'Area bump ranking chart',
  tags: const ['cartesian', 'ranking'],
);

final rainfallRegistration = ChartRegistration(
  type: ChartType.rainfall,
  typeString: 'rainfall',
  aliases: const ['precipitation'],
  fromJson: RainfallChartConfig.fromJson,
  description: 'Rainfall chart',
  tags: const ['cartesian', 'bar'],
);

final multiXAxesRegistration = ChartRegistration(
  type: ChartType.multiXAxes,
  typeString: 'multixaxes',
  aliases: const ['dualxaxis', 'dualaxes'],
  fromJson: MultiXAxesChartConfig.fromJson,
  description: 'Multi X-axes chart',
  tags: const ['cartesian', 'line'],
);

final lineStyleItemRegistration = ChartRegistration(
  type: ChartType.lineStyleItem,
  typeString: 'lineStyleItem',
  aliases: const ['styledline'],
  fromJson: LineStyleItemConfig.fromJson,
  description: 'Line style item chart',
  tags: const ['cartesian', 'line'],
);

final largeScaleAreaRegistration = ChartRegistration(
  type: ChartType.largeScaleArea,
  typeString: 'largescalearea',
  aliases: const ['bigdata'],
  fromJson: LargeScaleAreaConfig.fromJson,
  description: 'Large-scale area chart',
  tags: const ['cartesian', 'area'],
);

final areaTimeAxisRegistration = ChartRegistration(
  type: ChartType.areaTimeAxis,
  typeString: 'areatimeaxis',
  aliases: const ['timearea'],
  fromJson: AreaTimeAxisConfig.fromJson,
  description: 'Area chart with time axis',
  tags: const ['cartesian', 'area'],
);

final cartesianChartsBundle = RegistrationBundle(
  name: 'cartesian',
  description: 'Bar, Line, Area, Scatter, and variants',
  registrations: [
    barRegistration,
    stackedBarRegistration,
    groupedBarRegistration,
    horizontalBarRegistration,
    stackedHorizontalBarRegistration,
    lineRegistration,
    lineAreaRegistration,
    areaRegistration,
    stackedAreaRegistration,
    scatterRegistration,
    bubbleRegistration,
    comboRegistration,
    histogramRegistration,
    lollipopRegistration,
    ridgelineRegistration,
    stripAdvancedRegistration,
    errorBarRegistration,
    barBackgroundRegistration,
    barRaceRegistration,
    barGradientRegistration,
    barLabelRotationRegistration,
    barRoundedRegistration,
    barNormalizedRegistration,
    negativeBarRegistration,
    barBrushRegistration,
    areaPiecesRegistration,
    lineGradientRegistration,
    lineConfidenceBandRegistration,
    lineMarklineRegistration,
    logAxisRegistration,
    functionPlotRegistration,
    dynamicTimeSeriesRegistration,
    intradayLineRegistration,
    lineClickAddRegistration,
    slopeRegistration,
    dumbbellRegistration,
    areaBumpRegistration,
    rainfallRegistration,
    multiXAxesRegistration,
    lineStyleItemRegistration,
    largeScaleAreaRegistration,
    areaTimeAxisRegistration,
  ],
);
