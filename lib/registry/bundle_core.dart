import '../charts/area/area_chart_config.dart';
import '../charts/bar/bar_config.dart';
import '../charts/line/line_config.dart';
import '../charts/pie/pie_config.dart';
import '../charts/scatter/scatter_config.dart';
import '../core/chart_registry.dart';
import '../core/chart_type.dart';

/// Apache/free-tier chart registrations.
///
/// Keep this bundle intentionally small. It is the stable adoption surface for
/// the open-source package: core rendering, JSON configs, and standard chart
/// families. Advanced enterprise, financial, statistical, hierarchical, export,
/// and large-data features belong in `tenun_pro`.
final coreChartsBundle = RegistrationBundle(
  name: 'core',
  description: 'Free core charts: Bar, Line, Area, Pie, Donut, and Scatter',
  registrations: [
    coreBarRegistration,
    coreStackedBarRegistration,
    coreGroupedBarRegistration,
    coreHorizontalBarRegistration,
    coreStackedHorizontalBarRegistration,
    coreLineRegistration,
    coreLineAreaRegistration,
    coreAreaRegistration,
    coreStackedAreaRegistration,
    corePieRegistration,
    coreDonutRegistration,
    coreScatterRegistration,
  ],
);

final coreBarRegistration = ChartRegistration(
  type: ChartType.bar,
  typeString: 'bar',
  fromJson: BarChartConfig.fromJson,
  description: 'Bar chart family',
  tags: const ['core', 'cartesian', 'bar'],
);

final coreStackedBarRegistration = ChartRegistration(
  type: ChartType.stackedBar,
  typeString: 'stackedbar',
  aliases: const ['stacked_bar'],
  fromJson: BarChartConfig.fromJson,
  description: 'Stacked bar chart',
  tags: const ['core', 'cartesian', 'bar'],
);

final coreGroupedBarRegistration = ChartRegistration(
  type: ChartType.groupedBar,
  typeString: 'groupedbar',
  aliases: const ['grouped_bar'],
  fromJson: BarChartConfig.fromJson,
  description: 'Grouped bar chart',
  tags: const ['core', 'cartesian', 'bar'],
);

final coreHorizontalBarRegistration = ChartRegistration(
  type: ChartType.horizontalBar,
  typeString: 'horizontalbar',
  aliases: const ['horizontal_bar'],
  fromJson: BarChartConfig.fromJson,
  description: 'Horizontal bar chart',
  tags: const ['core', 'cartesian', 'bar'],
);

final coreStackedHorizontalBarRegistration = ChartRegistration(
  type: ChartType.stackedHorizontalBar,
  typeString: 'stackedhorizontalbar',
  aliases: const ['stacked_horizontal_bar'],
  fromJson: BarChartConfig.fromJson,
  description: 'Stacked horizontal bar chart',
  tags: const ['core', 'cartesian', 'bar'],
);

final coreLineRegistration = ChartRegistration(
  type: ChartType.line,
  typeString: 'line',
  aliases: const ['sparkline'],
  fromJson: LineChartConfig.fromJson,
  description: 'Line chart family',
  tags: const ['core', 'cartesian', 'line'],
);

final coreLineAreaRegistration = ChartRegistration(
  type: ChartType.lineArea,
  typeString: 'linearea',
  aliases: const ['line_area'],
  fromJson: LineChartConfig.fromJson,
  description: 'Line area chart',
  tags: const ['core', 'cartesian', 'line'],
);

final coreAreaRegistration = ChartRegistration(
  type: ChartType.area,
  typeString: 'area',
  fromJson: AreaChartConfig.fromJson,
  description: 'Area chart family',
  tags: const ['core', 'cartesian', 'area'],
);

final coreStackedAreaRegistration = ChartRegistration(
  type: ChartType.stackedArea,
  typeString: 'stackedarea',
  aliases: const ['stacked_area'],
  fromJson: AreaChartConfig.fromJson,
  description: 'Stacked area chart',
  tags: const ['core', 'cartesian', 'area'],
);

final corePieRegistration = ChartRegistration(
  type: ChartType.pie,
  typeString: 'pie',
  fromJson: PieChartConfig.fromJson,
  description: 'Pie chart',
  tags: const ['core', 'pie'],
);

final coreDonutRegistration = ChartRegistration(
  type: ChartType.donut,
  typeString: 'donut',
  fromJson: PieChartConfig.fromJson,
  description: 'Donut chart',
  tags: const ['core', 'pie'],
);

final coreScatterRegistration = ChartRegistration(
  type: ChartType.scatter,
  typeString: 'scatter',
  fromJson: ScatterChartConfig.fromJson,
  description: 'Scatter chart',
  tags: const ['core', 'cartesian', 'scatter'],
);
