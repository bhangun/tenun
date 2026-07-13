import '../core/chart_type.dart';

/// Metadata-only chart type groups used by registry tooling.
///
/// These constants intentionally avoid importing chart implementations, so the
/// basic package surface can classify Pro chart types without compiling their
/// renderers into `package:tenun`.
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

/// Metadata-only pie-like chart type group.
const Set<ChartType> pieLikeTypes = {
  ChartType.pie,
  ChartType.donut,
  ChartType.halfDonut,
  ChartType.paddedPie,
  ChartType.nightingale,
  ChartType.nestedPie,
  ChartType.partitionPie,
  ChartType.customizedPie,
  ChartType.pieLabelAlign,
  ChartType.pieSpecialLabel,
};

/// Metadata-only radial chart type group.
const Set<ChartType> radialTypes = {
  ChartType.radar,
  ChartType.radial,
  ChartType.gauge,
  ChartType.polarBar,
  ChartType.polarLine,
  ChartType.tangentialPolarBar,
  ChartType.bullet,
};

/// Metadata-only hierarchical chart type group.
const Set<ChartType> hierarchicalTypes = {
  ChartType.treemap,
  ChartType.sunburst,
};

/// Metadata-only flow chart type group.
const Set<ChartType> flowTypes = {
  ChartType.sankey,
  ChartType.funnel,
  ChartType.waterfall,
  ChartType.gantt,
  ChartType.timeline,
};

/// Metadata-only matrix chart type group.
const Set<ChartType> matrixTypes = {
  ChartType.heatmap,
  ChartType.sparklineMatrix,
};

/// Metadata-only calendar chart type group.
const Set<ChartType> calendarTypes = {
  ChartType.calendar,
  ChartType.calendarPie,
};

/// Metadata-only geospatial chart type group.
const Set<ChartType> geoTypes = {ChartType.choropleth};

/// Metadata-only graph chart type group.
const Set<ChartType> graphTypes = {ChartType.network};

/// Metadata-only financial chart type group.
const Set<ChartType> financialTypes = {
  ChartType.candlestick,
  ChartType.ohlc,
  ChartType.kagi,
  ChartType.renko,
  ChartType.macd,
};
