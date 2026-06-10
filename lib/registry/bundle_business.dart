import '../core/chart_registry.dart';
import '../core/chart_type.dart';
import '../charts/s_curve/s_curve_config.dart';
import '../charts/pareto/pareto_config.dart';
import '../charts/indicator/indicator_chart.dart';

final sCurveRegistration = ChartRegistration(
  type: ChartType.sCurve,
  typeString: 'sCurve',
  aliases: const ['progress_curve', 'project_curve'],
  fromJson: SCurveChartConfig.fromJson,
  description: 'S-Curve chart for project progress tracking.',
  tags: const ['business', 'project'],
);

final paretoRegistration = ChartRegistration(
  type: ChartType.pareto,
  typeString: 'pareto',
  fromJson: ParetoChartConfig.fromJson,
  description: 'Pareto chart (80/20 rule).',
  tags: const ['business', 'statistical'],
);

final indicatorRegistration = ChartRegistration(
  type: ChartType.indicator,
  typeString: 'indicator',
  aliases: const ['kpi_tile', 'stat'],
  fromJson: IndicatorChartConfig.fromJson,
  description: 'KPI indicator chart.',
  tags: const ['business', 'dashboard'],
);

final businessChartsBundle = RegistrationBundle(
  name: 'business',
  description: 'S-Curve, Pareto, Indicator',
  registrations: [
    sCurveRegistration,
    paretoRegistration,
    indicatorRegistration,
  ],
);
