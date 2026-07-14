import 'package:flutter/material.dart';
import 'package:tenun_core/core/base_config.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/core/chart_theme.dart';
import 'package:tenun_core/core/json_value.dart';
import 'package:tenun_core/core/title.dart';
import 'package:tenun_core/core/chart_controller.dart';

class IndicatorChartConfig extends BaseChartConfig {
  final double value;
  final double? previousValue;
  final String? unit;
  final int precision;
  final String label;

  IndicatorChartConfig({
    required this.value,
    required this.label,
    this.previousValue,
    this.unit,
    this.precision = 0,
    super.theme,
    super.title,
    super.controller,
  }) : super(type: ChartType.indicator, series: []);

  factory IndicatorChartConfig.fromJson(Map<String, dynamic> json) {
    return IndicatorChartConfig(
      value: JsonValue.doubleOrNull(json['value']) ?? 0,
      label: json['label']?.toString() ?? json['title']?.toString() ?? 'KPI',
      previousValue: JsonValue.doubleOrNull(json['previousValue']),
      unit: json['unit']?.toString(),
      precision: JsonValue.intOrNull(json['precision']) ?? 0,
      theme: json['theme'] != null ? ChartTheme.fromJson(json['theme']) : null,
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
    );
  }

  @override
  Widget buildChart() => IndicatorChartWidget(config: this);

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'indicator',
      'value': value,
      'previousValue': previousValue,
      'unit': unit,
      'precision': precision,
      'label': label,
    };
  }

  @override
  BaseChartConfig withTheme(ChartTheme theme) {
    return IndicatorChartConfig(
      value: value,
      label: label,
      previousValue: previousValue,
      unit: unit,
      precision: precision,
      theme: theme,
      title: title,
      controller: controller,
    );
  }

  @override
  BaseChartConfig withController(ChartController controller) {
    return IndicatorChartConfig(
      value: value,
      label: label,
      previousValue: previousValue,
      unit: unit,
      precision: precision,
      theme: theme,
      title: title,
      controller: controller,
    );
  }
}

class IndicatorChartWidget extends StatelessWidget {
  final IndicatorChartConfig config;

  const IndicatorChartWidget({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = config.previousValue != null
        ? config.value - config.previousValue!
        : 0.0;
    final percent = config.previousValue != null && config.previousValue != 0
        ? (diff / config.previousValue!) * 100
        : 0.0;

    final isPositive = diff >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            config.label,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (config.unit != null && config.unit!.startsWith('\$'))
                Text(config.unit!, style: theme.textTheme.headlineSmall),
              Text(
                config.value.toStringAsFixed(config.precision),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              if (config.unit != null && !config.unit!.startsWith('\$'))
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(config.unit!, style: theme.textTheme.titleMedium),
                ),
            ],
          ),
          if (config.previousValue != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  '${percent.abs().toStringAsFixed(1)}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'vs previous',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
