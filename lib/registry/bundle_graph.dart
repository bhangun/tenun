import '../core/chart_registry.dart';
import '../core/chart_type.dart';

// Chart config imports
import '../charts/network/network_radial_timeline_wordcloud_charts.dart';

const Set<ChartType> graphTypes = {
  ChartType.network,
};

final networkRegistration = ChartRegistration(
  type: ChartType.network,
  typeString: 'network',
  fromJson: NetworkChartConfig.fromJson,
  description: 'Network chart',
  tags: const ['graph', 'relational'],
);

final graphChartsBundle = RegistrationBundle(
  name: 'graph',
  description: 'Network Graph',
  registrations: [
    networkRegistration,
  ],
);
