import 'package:flutter/material.dart';
import '../../core/chart_controller.dart';
import '../../core/chart_color_value.dart';
import '../../core/chart_theme.dart';
import '../../core/chart_type.dart';
import '../../core/json_value.dart';
import '../../core/title.dart';
import '../../core/base_config.dart';
import 'confusion_matrix_chart.dart';

/// Configuration for Confusion Matrix charts, used for classification model evaluation.
class ConfusionMatrixChartConfig extends BaseChartConfig {
  /// Labels for the classes (e.g., ['Cat', 'Dog', 'Bird'])
  final List<String> labels;

  /// Matrix data (rows = Actual, columns = Predicted)
  final List<List<int>> data;

  /// Color used for correctly predicted cells (the diagonal)
  final Color baseColor;

  /// Whether to show percentages in each cell
  final bool showPercentages;

  ConfusionMatrixChartConfig({
    required this.labels,
    required this.data,
    this.baseColor = Colors.blue,
    this.showPercentages = true,
    super.title,
    super.theme = ChartTheme.light,
    super.controller,
  }) : super(type: ChartType.confusionMatrix, series: []);

  factory ConfusionMatrixChartConfig.fromJson(Map<String, dynamic> json) {
    final labels = JsonValue.stringList(json['labels']) ?? const <String>[];
    final data = JsonValue.intMatrix(json['data']) ?? const <List<int>>[];

    return ConfusionMatrixChartConfig(
      labels: labels,
      data: data,
      baseColor: ChartColorValue.colorOrFallback(
        json['baseColor'],
        Colors.blue,
      ),
      showPercentages: JsonValue.boolOrNull(json['showPercentages']) ?? true,
      title: json['title'] != null ? TitlesData.fromJson(json['title']) : null,
      theme: json['theme'] != null ? ChartTheme.fromJson(json['theme']) : null,
    );
  }

  @override
  Widget buildChart() => ConfusionMatrixChartWidget(config: this);

  @override
  BaseChartConfig withTheme(ChartTheme theme) {
    return ConfusionMatrixChartConfig(
      labels: labels,
      data: data,
      baseColor: baseColor,
      showPercentages: showPercentages,
      title: title,
      theme: theme,
      controller: controller,
    );
  }

  @override
  BaseChartConfig withController(ChartController controller) {
    return ConfusionMatrixChartConfig(
      labels: labels,
      data: data,
      baseColor: baseColor,
      showPercentages: showPercentages,
      title: title,
      theme: theme,
      controller: controller,
    );
  }
}
