import 'package:tenun/charts/pie/pie_config.dart';

void main() {
  final config = PieChartConfig.fromJson({
    'type': 'pie',
    'title': {'text': 'Core pie'},
    'series': [
      {
        'name': 'Sales',
        'data': [
          {'name': 'Online', 'value': '42', 'color': '#2563EB'},
          {'name': 'Partner', 'value': 28},
        ],
      },
    ],
  });
  print('Series length: ${config.series.length}');
  print('Data length: ${config.series[0].data?.length}');
  print('First item: ${config.series[0].data?[0]}');
  print('First item type: ${config.series[0].data?[0].runtimeType}');
}
