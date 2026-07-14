import 'package:tenun_core/tenun_core.dart';

import '../charts/pie/customized_pie_chart.dart';
import '../charts/pie/pie_chart_variants.dart';
import '../charts/pie/pie_config.dart';
import '../charts/pie/pie_label_align_chart.dart';
import '../charts/pie/pie_special_label_chart.dart';

// Chart config imports

const Set<ChartType> pieLikeTypes = {
  ChartType.pie,
  ChartType.donut,
  ChartType.halfDonut,
  ChartType.paddedPie,
  ChartType.nightingale,
  ChartType.nestedPie,
  ChartType.partitionPie,
  ChartType.customizedPie,
  ChartType.pieLabelAlign,
  ChartType.pieSpecialLabel,
};

final pieRegistration = ChartRegistration(
  type: ChartType.pie,
  typeString: 'pie',
  aliases: const [],
  fromJson: PieChartConfig.fromJson,
  description: 'Pie / donut chart',
  tags: const ['pie', 'core'],
);

final donutRegistration = ChartRegistration(
  type: ChartType.donut,
  typeString: 'donut',
  fromJson: PieChartConfig.fromJson,
  description: 'Donut chart',
  tags: const ['pie', 'core'],
);

final halfDonutRegistration = ChartRegistration(
  type: ChartType.halfDonut,
  typeString: 'halfdonut',
  aliases: const ['semicircle'],
  fromJson: HalfDonutChartConfig.fromJson,
  description: 'Half donut chart',
  tags: const ['pie'],
);

final paddedPieRegistration = ChartRegistration(
  type: ChartType.paddedPie,
  typeString: 'paddedpie',
  aliases: const ['gappedpie'],
  fromJson: PaddedPieChartConfig.fromJson,
  description: 'Padded pie chart',
  tags: const ['pie'],
);

final nightingaleRegistration = ChartRegistration(
  type: ChartType.nightingale,
  typeString: 'nightingale',
  aliases: const ['rose'],
  fromJson: NightingaleChartConfig.fromJson,
  description: 'Nightingale rose chart',
  tags: const ['pie', 'polar'],
);

final nestedPieRegistration = ChartRegistration(
  type: ChartType.nestedPie,
  typeString: 'nestedpie',
  aliases: const ['concentric'],
  fromJson: NestedPieChartConfig.fromJson,
  description: 'Nested concentric pie chart',
  tags: const ['pie'],
);

final partitionPieRegistration = ChartRegistration(
  type: ChartType.partitionPie,
  typeString: 'partitionpie',
  aliases: const ['drilldownpie'],
  fromJson: PartitionPieChartConfig.fromJson,
  description: 'Partition pie chart',
  tags: const ['pie'],
);

final customizedPieRegistration = ChartRegistration(
  type: ChartType.customizedPie,
  typeString: 'customizedpie',
  aliases: const ['custompie'],
  fromJson: CustomizedPieConfig.fromJson,
  description: 'Customized pie chart',
  tags: const ['pie'],
);

final pieLabelAlignRegistration = ChartRegistration(
  type: ChartType.pieLabelAlign,
  typeString: 'pielabelalign',
  aliases: const ['alignedlabels'],
  fromJson: PieLabelAlignConfig.fromJson,
  description: 'Pie label align chart',
  tags: const ['pie'],
);

final pieSpecialLabelRegistration = ChartRegistration(
  type: ChartType.pieSpecialLabel,
  typeString: 'piespeciallabel',
  aliases: const ['richlabelpie'],
  fromJson: PieSpecialLabelConfig.fromJson,
  description: 'Pie special rich-label chart',
  tags: const ['pie'],
);

final pieChartsBundle = RegistrationBundle(
  name: 'pie',
  description: 'Pie, Donut, and variants',
  registrations: [
    pieRegistration,
    donutRegistration,
    halfDonutRegistration,
    paddedPieRegistration,
    nightingaleRegistration,
    nestedPieRegistration,
    partitionPieRegistration,
    customizedPieRegistration,
    pieLabelAlignRegistration,
    pieSpecialLabelRegistration,
  ],
);
