import 'package:tenun_core/core/chart_registry.dart';
import 'package:tenun_core/core/chart_type.dart';

// Chart config imports
import '../charts/heatmap/heatmap_calendar_parallel_charts.dart';
import '../charts/line/line_area_variants.dart' as v3line;

const Set<ChartType> matrixTypes = {
  ChartType.heatmap,
  ChartType.sparklineMatrix,
};

final heatmapRegistration = ChartRegistration(
  type: ChartType.heatmap,
  typeString: 'heatmap',
  fromJson: HeatmapChartConfig.fromJson,
  description: 'Heatmap chart',
  tags: const ['matrix', 'heatmap'],
);

final sparklineMatrixRegistration = ChartRegistration(
  type: ChartType.sparklineMatrix,
  typeString: 'sparklinematrix',
  aliases: const ['minilines', 'kpigrid'],
  fromJson: v3line.SparklineMatrixConfig.fromJson,
  description: 'Sparkline matrix chart',
  tags: const ['matrix', 'sparkline'],
);

final matrixChartsBundle = RegistrationBundle(
  name: 'matrix',
  description: 'Heatmap, Sparkline Matrix',
  registrations: [heatmapRegistration, sparklineMatrixRegistration],
);
