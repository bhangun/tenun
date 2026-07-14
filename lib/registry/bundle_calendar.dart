import 'package:tenun_core/core/chart_registry.dart';
import 'package:tenun_core/core/chart_type.dart';

// Chart config imports
import '../charts/calendar/calendar_chart.dart';
import '../charts/pie/pie_chart_variants.dart' as v3pie;

const Set<ChartType> calendarTypes = {
  ChartType.calendar,
  ChartType.calendarPie,
};

final calendarRegistration = ChartRegistration(
  type: ChartType.calendar,
  typeString: 'calendar',
  fromJson: CalendarChartConfig.fromJson,
  description: 'Calendar chart',
  tags: const ['calendar'],
);

final calendarPieRegistration = ChartRegistration(
  type: ChartType.calendarPie,
  typeString: 'calendarpie',
  aliases: const ['piecal'],
  fromJson: v3pie.CalendarPieChartConfig.fromJson,
  description: 'Calendar mini-pie chart',
  tags: const ['calendar', 'pie'],
);

final calendarChartsBundle = RegistrationBundle(
  name: 'calendar',
  description: 'Calendar, Calendar Pie',
  registrations: [calendarRegistration, calendarPieRegistration],
);
