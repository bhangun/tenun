import '../core/chart_api_contract.dart';
import '../core/chart_type.dart';
import 'chart_type_groups.dart';

const Set<ChartType> _statisticalApiContractTypes = {
  ChartType.boxPlot,
  ChartType.histogram,
  ChartType.errorBar,
  ChartType.violin,
  ChartType.strip,
  ChartType.ridgeline,
  ChartType.lineConfidenceBand,
  ChartType.pareto,
  ChartType.rocCurve,
  ChartType.confusionMatrix,
  ChartType.parallel,
};

const Set<ChartType> _temporalApiContractTypes = {
  ChartType.timeline,
  ChartType.gantt,
  ChartType.barRace,
  ChartType.lineRace,
  ChartType.dynamicTimeSeries,
  ChartType.intradayLine,
  ChartType.areaTimeAxis,
  ChartType.sCurve,
};

const Set<ChartType> _densitySpatialApiContractTypes = {ChartType.wordcloud};

const Set<ChartType> _polarApiContractTypes = {
  ChartType.indicator,
  ChartType.spiderline,
  ChartType.alignedlabels,
  ChartType.richlabelpie,
};

/// Resolves the shared API contract family for a registered chart [type].
ChartApiContract chartApiContractForType(ChartType rawType) {
  final type = canonicalChartType(rawType);
  if (financialTypes.contains(type)) return ChartApiContracts.financial;
  if (_temporalApiContractTypes.contains(type)) {
    return ChartApiContracts.temporal;
  }
  if (_statisticalApiContractTypes.contains(type)) {
    return ChartApiContracts.statistical;
  }
  if (matrixTypes.contains(type) ||
      calendarTypes.contains(type) ||
      geoTypes.contains(type) ||
      _densitySpatialApiContractTypes.contains(type)) {
    return ChartApiContracts.densitySpatial;
  }
  if (hierarchicalTypes.contains(type) ||
      flowTypes.contains(type) ||
      graphTypes.contains(type)) {
    return ChartApiContracts.hierarchyFlow;
  }
  if (radialTypes.contains(type) ||
      pieLikeTypes.contains(type) ||
      _polarApiContractTypes.contains(type)) {
    return ChartApiContracts.polar;
  }
  if (cartesianTypes.contains(type) || type == ChartType.sparkline) {
    return ChartApiContracts.cartesian;
  }
  return ChartApiContracts.optionConfig;
}
