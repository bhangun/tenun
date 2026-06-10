import 'package:flutter/material.dart';

import '../chart_model.dart';
import '../series.dart';
import 'helper.dart';

class LegendWidget extends StatelessWidget {
  final ChartConfig config;
  const LegendWidget({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    List<Series> series = config.series;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: series.asMap().entries.map((entry) {
        final index = entry.key;
        final seriesItem = entry.value;
        final fallback = getDefaultSeriesColor(index);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              color:
                  seriesItem.color ??
                  safeStringToColor(seriesItem.itemStyle?.color, fallback),
            ),
            const SizedBox(width: 4),
            Text(seriesItem.name ?? 'Series ${index + 1}'),
          ],
        );
      }).toList(),
    );
  }
}
