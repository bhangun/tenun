import 'package:tenun_core/core/chart_registry.dart';
import 'package:tenun_core/core/chart_type.dart';

// Chart config imports
import '../charts/treemap/treemap_chart.dart';
import '../charts/sunburst/sunburst.dart';

const Set<ChartType> hierarchicalTypes = {
  ChartType.treemap,
  ChartType.sunburst,
};

final treemapRegistration = ChartRegistration(
  type: ChartType.treemap,
  typeString: 'treemap',
  fromJson: TreemapChartConfig.fromJson,
  description: 'Treemap chart',
  tags: const ['hierarchical', 'advanced'],
);

final nextSunburstRegistration = ChartRegistration(
  type: ChartType.sunburst,
  typeString: 'sunburst',
  fromJson: SunburstChartConfig.fromJson,
  description: 'Next sunburst chart',
  tags: const ['hierarchical'],
);

final hierarchicalChartsBundle = RegistrationBundle(
  name: 'hierarchical',
  description: 'Treemap, Sunburst',
  registrations: [treemapRegistration, nextSunburstRegistration],
);
