import '../core/chart_registry.dart';
import '../core/chart_type.dart';

// Chart config imports
import '../charts/funnel/funnel_config.dart';
import '../charts/sankey/sankey.dart';
import '../charts/waterfall/waterfall_chart.dart';
import '../charts/gantt/gantt_chart.dart';
import '../charts/network/network_radial_timeline_wordcloud_charts.dart';

const Set<ChartType> flowTypes = {
  ChartType.sankey,
  ChartType.funnel,
  ChartType.waterfall,
  ChartType.gantt,
  ChartType.timeline,
};

final funnelRegistration = ChartRegistration(
  type: ChartType.funnel,
  typeString: 'funnel',
  aliases: const ['pyramid'],
  fromJson: FunnelChartConfig.fromJson,
  description: 'Funnel chart',
  tags: const ['flow'],
);

final nextSankeyRegistration = ChartRegistration(
  type: ChartType.sankey,
  typeString: 'sankey',
  fromJson: SankeyChartConfig.fromJson,
  description: 'Next sankey chart',
  tags: const ['flow'],
);

final nextWaterfallRegistration = ChartRegistration(
  type: ChartType.waterfall,
  typeString: 'waterfall',
  fromJson: WaterfallChartConfig.fromJson,
  description: 'Next waterfall chart',
  tags: const ['flow'],
);

final nextGanttRegistration = ChartRegistration(
  type: ChartType.gantt,
  typeString: 'gantt',
  fromJson: GanttChartConfig.fromJson,
  description: 'Next gantt chart',
  tags: const ['flow', 'timeline'],
);

final timelineRegistration = ChartRegistration(
  type: ChartType.timeline,
  typeString: 'timeline',
  fromJson: TimelineChartConfig.fromJson,
  description: 'Timeline chart',
  tags: const ['flow', 'timeline'],
);

final flowChartsBundle = RegistrationBundle(
  name: 'flow',
  description: 'Sankey, Funnel, Waterfall, Timeline, Gantt',
  registrations: [
    funnelRegistration,
    nextSankeyRegistration,
    nextWaterfallRegistration,
    nextGanttRegistration,
    timelineRegistration,
  ],
);
