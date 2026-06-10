import '../core/chart_registry.dart';
import '../core/chart_type.dart';

// Chart config imports
import '../charts/gauge/gauge_config.dart';
import '../charts/radar/radar_config.dart';
import '../charts/polar_bar/polar_bar_chart.dart';
import '../charts/bullet/bullet_chart.dart';
import '../charts/network/network_radial_timeline_wordcloud_charts.dart';
import '../charts/bar/bar_chart_variants.dart' as v3bar;
import '../charts/polar_line/polar_line_config.dart';

const Set<ChartType> radialTypes = {
  ChartType.radar,
  ChartType.radial,
  ChartType.gauge,
  ChartType.polarBar,
  ChartType.polarLine,
  ChartType.tangentialPolarBar,
  ChartType.bullet,
};

final gaugeRegistration = ChartRegistration(
  type: ChartType.gauge,
  typeString: 'gauge',
  fromJson: GaugeChartConfig.fromJson,
  description: 'Gauge chart',
  tags: const ['radial', 'gauge'],
);

final radarRegistration = ChartRegistration(
  type: ChartType.radar,
  typeString: 'radar',
  aliases: const ['spider', 'web'],
  fromJson: RadarChartConfig.fromJson,
  description: 'Radar chart',
  tags: const ['radial'],
);

final nextPolarBarRegistration = ChartRegistration(
  type: ChartType.polarBar,
  typeString: 'polarbar',
  aliases: const ['polar_bar'],
  fromJson: PolarBarChartConfig.fromJson,
  description: 'Next polar bar chart',
  tags: const ['radial'],
);

final tangentialPolarBarRegistration = ChartRegistration(
  type: ChartType.tangentialPolarBar,
  typeString: 'tangentialpolarbar',
  aliases: const ['polarbartangential'],
  fromJson: v3bar.TangentialPolarBarConfig.fromJson,
  description: 'Tangential polar bar chart',
  tags: const ['radial', 'polar'],
);

final polarLineRegistration = ChartRegistration(
  type: ChartType.polarLine,
  typeString: 'polarline',
  aliases: const ['spiderline'],
  fromJson: PolarLineChartConfig.fromJson,
  description: 'Polar line chart',
  tags: const ['radial', 'polar'],
);

final radialRegistration = ChartRegistration(
  type: ChartType.radial,
  typeString: 'radial',
  fromJson: RadialChartConfig.fromJson,
  description: 'Radial chart',
  tags: const ['radial'],
);

final bulletRegistration = ChartRegistration(
  type: ChartType.bullet,
  typeString: 'bullet',
  fromJson: BulletChartConfig.fromJson,
  description: 'Bullet KPI chart',
  tags: const ['radial', 'kpi'],
);

final radialChartsBundle = RegistrationBundle(
  name: 'radial',
  description: 'Gauge, Radar, PolarBar, Radial, Bullet',
  registrations: [
    gaugeRegistration,
    radarRegistration,
    nextPolarBarRegistration,
    tangentialPolarBarRegistration,
    polarLineRegistration,
    radialRegistration,
    bulletRegistration,
  ],
);
