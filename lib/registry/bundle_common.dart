import '../core/chart_registry.dart';
import '../core/chart_type.dart';

// Chart config imports
import '../charts/sparkline/sparkline_chart.dart';
import '../charts/pararel/pararel_chart.dart';
import '../charts/network/network_radial_timeline_wordcloud_charts.dart';
import '../charts/box_plot/box_plot_chart.dart';
import '../charts/violin/violin_chart.dart';
import '../charts/custom/custom_chart.dart' as v3custom;

final sparklineRegistration = ChartRegistration(
  type: ChartType.sparkline,
  typeString: 'sparkline',
  fromJson: SparklineChartConfig.fromJson,
  description: 'Sparkline chart',
  tags: const ['common', 'trend'],
);

final parallelRegistration = ChartRegistration(
  type: ChartType.parallel,
  typeString: 'parallel',
  fromJson: ParallelChartConfig.fromJson,
  description: 'Parallel coordinates chart',
  tags: const ['common', 'multivariate'],
);

final wordcloudRegistration = ChartRegistration(
  type: ChartType.wordcloud,
  typeString: 'wordcloud',
  fromJson: WordcloudChartConfig.fromJson,
  description: 'Wordcloud chart',
  tags: const ['common', 'text'],
);

final customRegistration = ChartRegistration(
  type: ChartType.custom,
  typeString: 'custom',
  aliases: const ['plugin'],
  fromJson: v3custom.CustomChartConfig.fromJson,
  description: 'Custom chart extension type',
  tags: const ['common', 'custom'],
);

final boxPlotRegistration = ChartRegistration(
  type: ChartType.boxPlot,
  typeString: 'boxplot',
  aliases: const [],
  fromJson: BoxPlotChartConfig.fromJson,
  description: 'Box plot chart',
  tags: const ['common', 'statistical'],
);

final violinAdvancedRegistration = ChartRegistration(
  type: ChartType.violin,
  typeString: 'violin',
  fromJson: ViolinChartConfig.fromJson,
  description: 'Violin chart',
  tags: const ['common', 'statistical'],
);

final commonChartsBundle = RegistrationBundle(
  name: 'common',
  description: 'Sparkline, Parallel, Wordcloud, Custom, Violin, BoxPlot',
  registrations: [
    sparklineRegistration,
    parallelRegistration,
    wordcloudRegistration,
    customRegistration,
    boxPlotRegistration,
    violinAdvancedRegistration,
  ],
);
