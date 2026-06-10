/// Enum of all supported chart types.
///
/// When adding a new chart type:
///  1. Add the enum value here.
///  2. Register its config factory in `core/utils/helper.dart` → `getChartConfig`.
///  3. Add mapping in `chartTypeToString` and `getChartType`.
///
/// v2 additions:
///  - combo / mixed   : overlaid bar + line on shared axis
///  - sparkline       : minimal inline trend line (no axes/labels)
///  - violin          : distribution shape + box-plot overlay
///  - kagi            : price-reversal chart (trading)
///  - renko           : fixed-brick price chart (trading)
///  - ridgeline       : offset density/distribution curves
///  - macd            : Moving Average Convergence Divergence (trading)
///  - ohlc            : Open-High-Low-Close bar chart (trading alternative to candlestick)
///  - strip           : dot-plot strip chart (all individual data points)
///  - bullet          : horizontal performance vs target gauge bar
///  - lollipop        : bar with circle cap — cleaner than bar for comparisons
enum ChartType {
  // ---- Basic ----
  bar,
  stackedBar,
  groupedBar,
  horizontalBar,
  stackedHorizontalBar,
  line,
  lineArea,
  area,
  stackedArea,
  pie,
  donut,
  scatter,

  // ── Bar variants ────────────────────────────────────────────
  barBackground, // bar with translucent track behind each bar
  barRace, // animated racing bar chart
  barGradient, // gradient-filled clickable column chart
  barLabelRotation, // bar with rotated X-axis labels
  barRounded, // stacked bar with rounded top segment
  barNormalized, // 100 %-normalised stacked bar
  barBrush, // bar with brush-select range overlay
  negativeBar, // horizontal diverging bar (negative values)
  tangentialPolarBar, // polar bar with tangential arc labels
  ///
  // ── Line / Area variants ────────────────────────────────────
  areaPieces, // area split by threshold colour bands
  lineGradient, // gradient stroke + fill area
  lineConfidenceBand, // line + shaded confidence/error band
  lineMarkline, // line with named horizontal reference lines
  logAxis, // line on logarithmic Y axis
  functionPlot, // mathematical y = f(x) plotter
  sparklineMatrix, // grid of mini sparklines
  dynamicTimeSeries, // live-updating sliding-window series
  intradayLine, // line with explicit data-gap breaks
  lineClickAdd, // interactive — tap to add data points
  lineRace, // animated line race
  ///
  // ── Pie variants ────────────────────────────────────────────
  halfDonut, // 180° semicircle donut
  paddedPie, // pie with configurable pad angle
  nightingale, // rose / nightingale chart
  nestedPie, // concentric ring charts
  partitionPie, // one slice subdivided into sub-slices
  calendarPie, // mini pies inside a calendar grid
  ///
  // ── Remaining / specialised ──────────────────────────────────
  rainfall, // bar styled as rainfall + optional line
  multiXAxes, // line with two independent X axes
  lineStyleItem, // line with per-series dash/dot styles
  largeScaleArea, // LTTB-downsampled large-dataset area
  areaTimeAxis, // area/line with DateTime X axis
  polarLine, // line on polar coordinates
  customizedPie, // pie with per-slice explode & border
  pieLabelAlign, // pie with polyline-aligned edge labels
  pieSpecialLabel, // donut with rich multi-line labels
  slope, // before/after slope chart
  dumbbell, // connected dot-pair range chart
  areaBump, // ranking flow area chart
  // ---- Combo / Overlay ----
  /// Overlaid bar + line series on a shared axis.
  /// Use [Series.type] to tag individual series as 'bar' or 'line'.
  combo,

  // ---- Statistical ----
  boxPlot,
  histogram,
  errorBar,
  candlestick,

  /// Open-High-Low-Close bar chart (OHLC bars instead of candlestick bodies).
  ohlc,

  /// Kernel-density distribution shape with optional box-plot overlay.
  violin,

  /// Strip / dot plot — each data point drawn as a circle on a strip.
  strip,

  // ---- Relational ----
  bubble,
  heatmap,
  treemap,
  sunburst,
  network,

  // ---- Flow / Process ----
  sankey,
  funnel,
  waterfall,
  timeline,
  gantt,

  // ---- Radial / Angular ----
  radar,
  radial,
  gauge,
  polarBar,

  /// Bullet chart — horizontal bar with target marker and qualitative bands.
  bullet,

  // ---- Sparkline ----
  /// Minimal inline trend-line (no axes, no labels).
  /// Designed for embedding in tables / KPI cards.
  sparkline,

  // ---- Distribution / Continuous ----
  /// Offset, overlapping density curves per category — good for comparing
  /// distributions across many groups.
  ridgeline,

  // ---- Trading / Time-series ----
  /// Kagi chart: price-reversal lines, ignores time axis.
  kagi,

  /// Renko chart: fixed-brick reversal chart.
  renko,

  /// MACD indicator chart (bar histogram + signal lines).
  macd,

  /// Lollipop: dot + stem, cleaner alternative to bar for comparisons.
  lollipop,

  /// S-Curve: Cumulative progress/cost chart used in project management.
  sCurve,

  /// Pareto Chart: Bar chart sorted descending + cumulative percentage line.
  pareto,

  /// Indicator Chart: High-level KPI with trend/status indicator.
  indicator,

  /// Confusion Matrix: Evaluation of classification model accuracy.
  confusionMatrix,

  /// ROC Curve: True Positive Rate vs False Positive Rate for classifiers.
  rocCurve,

  // ---- Geo ----
  choropleth,

  // ---- Misc ----
  calendar,
  wordcloud,
  parallel,
  custom,
  dualaxes,
  linestyleitem,
  bigdata,
  spiderline,
  alignedlabels,
  richlabelpie,
}

/// Convert a string to [ChartType].
ChartType getChartType(String type) {
  switch (normalizeChartTypeKey(type)) {
    // basic
    case 'bar':
      return ChartType.bar;
    case 'stackedbar':
      return ChartType.stackedBar;
    case 'groupedbar':
      return ChartType.groupedBar;
    case 'horizontalbar':
      return ChartType.horizontalBar;
    case 'stackedhorizontalbar':
      return ChartType.stackedHorizontalBar;
    case 'line':
      return ChartType.line;
    case 'linearea':
      return ChartType.lineArea;
    case 'area':
      return ChartType.area;
    case 'stackedarea':
      return ChartType.stackedArea;
    case 'pie':
      return ChartType.pie;
    case 'donut':
      return ChartType.donut;
    case 'scatter':
      return ChartType.scatter;
    case 'barbackground':
      return ChartType.barBackground;
    case 'barrace':
      return ChartType.barRace;
    case 'bargradient':
      return ChartType.barGradient;
    case 'barlabelrotation':
      return ChartType.barLabelRotation;
    case 'barrounded':
      return ChartType.barRounded;
    case 'barnormalized':
    case 'bar100':
      return ChartType.barNormalized;
    case 'barbrush':
      return ChartType.barBrush;
    case 'negativebar':
      return ChartType.negativeBar;
    case 'tangentialpolarbar':
    case 'tangentialpolarbbar':
    case 'tangentialpolarbr':
      return ChartType.tangentialPolarBar;
    // line/area variants
    case 'areapieces':
      return ChartType.areaPieces;
    case 'linegradient':
      return ChartType.lineGradient;
    case 'lineconfidenceband':
    case 'confidenceband':
      return ChartType.lineConfidenceBand;
    case 'linemarkline':
    case 'markline':
      return ChartType.lineMarkline;
    case 'logaxis':
    case 'logarithmic':
      return ChartType.logAxis;
    case 'functionplot':
    case 'function':
      return ChartType.functionPlot;
    case 'sparklinematrix':
    case 'minilines':
      return ChartType.sparklineMatrix;
    case 'dynamictimeseries':
    case 'livechart':
      return ChartType.dynamicTimeSeries;
    case 'intradayline':
    case 'intraday':
      return ChartType.intradayLine;
    case 'lineclickadd':
    case 'clicktoadd':
      return ChartType.lineClickAdd;
    case 'linerace':
      return ChartType.lineRace;
    // pie variants
    case 'halfdonut':
    case 'semicircle':
      return ChartType.halfDonut;
    case 'paddedpie':
    case 'gappedpie':
      return ChartType.paddedPie;
    case 'nightingale':
    case 'rose':
      return ChartType.nightingale;
    case 'nestedpie':
    case 'concentric':
      return ChartType.nestedPie;
    case 'partitionpie':
    case 'drilldownpie':
      return ChartType.partitionPie;
    case 'calendarpie':
      return ChartType.calendarPie;
    // remaining
    case 'rainfall':
      return ChartType.rainfall;
    case 'multixaxes':
      return ChartType.multiXAxes;
    case 'dualaxes':
    case 'dualxaxis':
      return ChartType.multiXAxes;
    case 'linestyleitem':
    case 'styledline':
      return ChartType.lineStyleItem;
    case 'largescalearea':
      return ChartType.largeScaleArea;

    case 'bigdata':
      return ChartType.largeScaleArea;
    case 'areatimeaxis':
      return ChartType.areaTimeAxis;
    case 'polarline':
      return ChartType.polarLine;

    case 'spiderline':
      return ChartType.polarLine;

    case 'customizedpie':
      return ChartType.customizedPie;
    case 'pielabelalign':
      return ChartType.pieLabelAlign;
    case 'piespeciallabel':
      return ChartType.pieSpecialLabel;
    case 'slope':
    case 'slopegraph':
      return ChartType.slope;
    case 'dumbbell':
    case 'dotrange':
      return ChartType.dumbbell;
    case 'areabump':
    case 'bump':
      return ChartType.areaBump;

    case 'alignedlabels':
      return ChartType.pieLabelAlign;
    case 'richlabelpie':
      return ChartType.pieSpecialLabel;
    // combo
    case 'combo':
    case 'mixed':
      return ChartType.combo;
    // statistical
    case 'boxplot':
      return ChartType.boxPlot;
    case 'histogram':
      return ChartType.histogram;
    case 'errorbar':
      return ChartType.errorBar;
    case 'candlestick':
      return ChartType.candlestick;
    case 'ohlc':
      return ChartType.ohlc;
    case 'violin':
      return ChartType.violin;
    case 'strip':
    case 'dotplot':
      return ChartType.strip;
    // relational
    case 'bubble':
      return ChartType.bubble;
    case 'heatmap':
      return ChartType.heatmap;
    case 'treemap':
      return ChartType.treemap;
    case 'sunburst':
      return ChartType.sunburst;
    case 'network':
      return ChartType.network;
    // flow
    case 'sankey':
      return ChartType.sankey;
    case 'funnel':
      return ChartType.funnel;
    case 'waterfall':
      return ChartType.waterfall;
    case 'timeline':
      return ChartType.timeline;
    case 'gantt':
      return ChartType.gantt;
    // radial
    case 'radar':
      return ChartType.radar;
    case 'radial':
      return ChartType.radial;
    case 'gauge':
      return ChartType.gauge;
    case 'polarbar':
      return ChartType.polarBar;
    case 'bullet':
      return ChartType.bullet;
    // sparkline
    case 'sparkline':
      return ChartType.sparkline;
    // distribution
    case 'ridgeline':
    case 'ridge':
      return ChartType.ridgeline;
    // trading
    case 'kagi':
      return ChartType.kagi;
    case 'renko':
      return ChartType.renko;
    case 'macd':
      return ChartType.macd;
    case 'lollipop':
      return ChartType.lollipop;
    case 'scurve':
      return ChartType.sCurve;
    case 'pareto':
      return ChartType.pareto;
    case 'indicator':
      return ChartType.indicator;
    case 'confusionmatrix':
      return ChartType.confusionMatrix;
    case 'roccurve':
      return ChartType.rocCurve;
    // geo
    case 'choropleth':
      return ChartType.choropleth;
    // misc
    case 'calendar':
      return ChartType.calendar;
    case 'wordcloud':
      return ChartType.wordcloud;
    case 'parallel':
      return ChartType.parallel;
    case 'custom':
      return ChartType.custom;
    default:
      return ChartType.line;
  }
}

/// Normalizes chart type strings in the same way the registry resolves JSON
/// keys, so nested series and top-level config payloads accept the same
/// separator variants.
String normalizeChartTypeKey(Object? raw) {
  final text = raw?.toString().trim().toLowerCase();
  if (text == null || text.isEmpty) return '';
  return text.replaceAll(RegExp(r'[\s_\-]+'), '');
}

/// Maps retained legacy enum values onto the implemented chart type that owns
/// their parser/registration.
ChartType canonicalChartType(ChartType type) => switch (type) {
  ChartType.dualaxes => ChartType.multiXAxes,
  ChartType.linestyleitem => ChartType.lineStyleItem,
  ChartType.bigdata => ChartType.largeScaleArea,
  ChartType.spiderline => ChartType.polarLine,
  ChartType.alignedlabels => ChartType.pieLabelAlign,
  ChartType.richlabelpie => ChartType.pieSpecialLabel,
  _ => type,
};

/// Convert [ChartType] back to a canonical string.
String chartTypeToString(ChartType type) {
  switch (canonicalChartType(type)) {
    case ChartType.bar:
      return 'bar';
    case ChartType.stackedBar:
      return 'stackedBar';
    case ChartType.groupedBar:
      return 'groupedBar';
    case ChartType.dualaxes:
      return 'dualaxes';
    case ChartType.linestyleitem:
      return 'linestyleitem';
    case ChartType.bigdata:
      return 'bigdata';
    case ChartType.spiderline:
      return 'spiderline';
    case ChartType.alignedlabels:
      return 'alignedlabels';
    case ChartType.richlabelpie:
      return 'richlabelpie';
    case ChartType.horizontalBar:
      return 'horizontalBar';
    case ChartType.stackedHorizontalBar:
      return 'stackedHorizontalBar';
    case ChartType.line:
      return 'line';
    case ChartType.lineArea:
      return 'lineArea';
    case ChartType.area:
      return 'area';
    case ChartType.stackedArea:
      return 'stackedArea';
    case ChartType.pie:
      return 'pie';
    case ChartType.donut:
      return 'donut';
    case ChartType.scatter:
      return 'scatter';

    ///
    /// ═══════════════════════════════════════════════════════════════════
    /// STEP 3 — Add to chartTypeToString() switch
    /// ═══════════════════════════════════════════════════════════════════
    ///
    case ChartType.barBackground:
      return 'barBackground';
    case ChartType.barRace:
      return 'barRace';
    case ChartType.barGradient:
      return 'barGradient';
    case ChartType.barLabelRotation:
      return 'barLabelRotation';
    case ChartType.barRounded:
      return 'barRounded';
    case ChartType.barNormalized:
      return 'barNormalized';
    case ChartType.barBrush:
      return 'barBrush';
    case ChartType.negativeBar:
      return 'negativeBar';
    case ChartType.tangentialPolarBar:
      return 'tangentialPolarBar';
    case ChartType.areaPieces:
      return 'areaPieces';
    case ChartType.lineGradient:
      return 'lineGradient';
    case ChartType.lineConfidenceBand:
      return 'lineConfidenceBand';
    case ChartType.lineMarkline:
      return 'lineMarkline';
    case ChartType.logAxis:
      return 'logAxis';
    case ChartType.functionPlot:
      return 'functionPlot';
    case ChartType.sparklineMatrix:
      return 'sparklineMatrix';
    case ChartType.dynamicTimeSeries:
      return 'dynamicTimeSeries';
    case ChartType.intradayLine:
      return 'intradayLine';
    case ChartType.lineClickAdd:
      return 'lineClickAdd';
    case ChartType.lineRace:
      return 'lineRace';
    case ChartType.halfDonut:
      return 'halfDonut';
    case ChartType.paddedPie:
      return 'paddedPie';
    case ChartType.nightingale:
      return 'nightingale';
    case ChartType.nestedPie:
      return 'nestedPie';
    case ChartType.partitionPie:
      return 'partitionPie';
    case ChartType.calendarPie:
      return 'calendarPie';
    case ChartType.rainfall:
      return 'rainfall';
    case ChartType.multiXAxes:
      return 'multiXAxes';
    case ChartType.lineStyleItem:
      return 'lineStyleItem';
    case ChartType.largeScaleArea:
      return 'largeScaleArea';
    case ChartType.areaTimeAxis:
      return 'areaTimeAxis';
    case ChartType.polarLine:
      return 'polarLine';
    case ChartType.customizedPie:
      return 'customizedPie';
    case ChartType.pieLabelAlign:
      return 'pieLabelAlign';
    case ChartType.pieSpecialLabel:
      return 'pieSpecialLabel';
    case ChartType.slope:
      return 'slope';
    case ChartType.dumbbell:
      return 'dumbbell';
    case ChartType.areaBump:
      return 'areaBump';
    case ChartType.combo:
      return 'combo';
    case ChartType.boxPlot:
      return 'boxPlot';
    case ChartType.histogram:
      return 'histogram';
    case ChartType.errorBar:
      return 'errorBar';
    case ChartType.candlestick:
      return 'candlestick';
    case ChartType.ohlc:
      return 'ohlc';
    case ChartType.violin:
      return 'violin';
    case ChartType.strip:
      return 'strip';
    case ChartType.bubble:
      return 'bubble';
    case ChartType.heatmap:
      return 'heatmap';
    case ChartType.treemap:
      return 'treemap';
    case ChartType.sunburst:
      return 'sunburst';
    case ChartType.network:
      return 'network';
    case ChartType.sankey:
      return 'sankey';
    case ChartType.funnel:
      return 'funnel';
    case ChartType.waterfall:
      return 'waterfall';
    case ChartType.timeline:
      return 'timeline';
    case ChartType.gantt:
      return 'gantt';
    case ChartType.radar:
      return 'radar';
    case ChartType.radial:
      return 'radial';
    case ChartType.gauge:
      return 'gauge';
    case ChartType.polarBar:
      return 'polarBar';
    case ChartType.bullet:
      return 'bullet';
    case ChartType.sparkline:
      return 'sparkline';
    case ChartType.ridgeline:
      return 'ridgeline';
    case ChartType.kagi:
      return 'kagi';
    case ChartType.renko:
      return 'renko';
    case ChartType.macd:
      return 'macd';
    case ChartType.lollipop:
      return 'lollipop';
    case ChartType.sCurve:
      return 'sCurve';
    case ChartType.pareto:
      return 'pareto';
    case ChartType.indicator:
      return 'indicator';
    case ChartType.confusionMatrix:
      return 'confusionMatrix';
    case ChartType.rocCurve:
      return 'rocCurve';
    case ChartType.choropleth:
      return 'choropleth';
    case ChartType.calendar:
      return 'calendar';
    case ChartType.wordcloud:
      return 'wordcloud';
    case ChartType.parallel:
      return 'parallel';
    case ChartType.custom:
      return 'custom';
  }
}
