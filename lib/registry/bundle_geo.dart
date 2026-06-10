import '../core/chart_registry.dart';
import '../core/chart_type.dart';

// Chart config imports
import '../charts/choroplet/choropleth_chart.dart' as v3choro;

const Set<ChartType> geoTypes = {
  ChartType.choropleth,
};

final choroplethRegistration = ChartRegistration(
  type: ChartType.choropleth,
  typeString: 'choropleth',
  aliases: const ['map', 'geomap'],
  fromJson: v3choro.ChoroplethChartConfig.fromJson,
  description: 'Choropleth map chart',
  tags: const ['geo'],
);

final geoChartsBundle = RegistrationBundle(
  name: 'geo',
  description: 'Choropleth Map',
  registrations: [
    choroplethRegistration,
  ],
);
