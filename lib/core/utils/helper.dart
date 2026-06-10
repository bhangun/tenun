// Helper method to assign colors (you can customize this)
import 'dart:math';

import 'package:flutter/material.dart';

import '../chart_registry.dart';
import '../chart_type.dart';
import '../series.dart';
import '../chart_model.dart';
import '../chart_data_value_reader.dart';

dynamic getChartConfig(ChartType chartType, Map<String, dynamic> json) {
  return ChartRegistry.resolveByType(chartType, json);
}

Color getDefaultSeriesColor(int index) {
  final colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.brown,
  ];

  return colors[index % colors.length];
}

/* Widget flChart(ChartType type, ChartConfig config) {
  if (config.series[0].data!.isNotEmpty &&
      config.series[0].data![0].value != null) {
    type = ChartType.pie;
  } else {
    return const Center(child: Text('Data not relevan'));
  }

  switch (type) {
    case ChartType.line || ChartType.lineArea:
      return KLine(config: config);
    case ChartType.pie || ChartType.pie:
      return KPie(config: config);
    default:
      return KBar(config: config);
  }
} */

Widget legend(ChartConfig config) {
  return Wrap(
    spacing: 16,
    runSpacing: 8,
    children: config.series.asMap().entries.map((entry) {
      final index = entry.key;
      final series = entry.value;
      final fallback = getDefaultSeriesColor(index);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            color:
                series.color ??
                safeStringToColor(series.itemStyle?.color, fallback),
          ),
          const SizedBox(width: 4),
          Text(series.name ?? 'Series ${index + 1}'),
        ],
      );
    }).toList(),
  );
}

Color stringToColor(String colorString) {
  // Trim the input string to remove any leading/trailing whitespace
  colorString = colorString.trim();

  // Handle hex colors: #RGB, #RRGGBB, #RRGGBBAA
  if (colorString.startsWith('#')) {
    return _hexToColor(colorString);
  }

  // Handle rgba strings
  if (colorString.toLowerCase().startsWith('rgba(')) {
    return rgbaStringToColor(colorString);
  }

  // Handle rgb strings
  if (colorString.toLowerCase().startsWith('rgb(')) {
    return rgbStringToColor(colorString);
  }

  // Lookup table for common color names (case-insensitive)
  final Map<String, Color> colorMap = {
    'black': Colors.black,
    'white': Colors.white,
    'red': Colors.red,
    'green': Colors.green,
    'blue': Colors.blue,
    'yellow': Colors.yellow,
    'orange': Colors.orange,
    'purple': Colors.purple,
    'pink': Colors.pink,
    'grey': Colors.grey,
    'gray': Colors.grey, // Alternate spelling
    'brown': Colors.brown,
    'cyan': Colors.cyan,
    'teal': Colors.teal,
    'indigo': Colors.indigo,
    'amber': Colors.amber,
    'lime': Colors.lime,
    'transparent': Colors.transparent,
    'olive': Colors.deepOrange.shade800,
    'navy': Colors.blue.shade900,
    'maroon': Colors.red.shade900,
    'gold': Colors.amber,
    'silver': Colors.grey.shade400,
  };

  final lowerColorString = colorString.toLowerCase();
  if (colorMap.containsKey(lowerColorString)) {
    return colorMap[lowerColorString]!;
  }

  throw FormatException('Invalid color string: $colorString');
}

Color? tryStringToColor(String? colorString) {
  if (colorString == null || colorString.trim().isEmpty) return null;

  try {
    return stringToColor(colorString);
  } on FormatException {
    return null;
  } on RangeError {
    return null;
  } on ArgumentError {
    return null;
  }
}

Color safeStringToColor(String? colorString, [Color fallback = Colors.grey]) {
  return tryStringToColor(colorString) ?? fallback;
}

/// Convert hex color string to Color
/// Supports: #RGB, #RRGGBB, #RRGGBBAA
Color _hexToColor(String hexString) {
  // Remove the # prefix
  hexString = hexString.trim().replaceFirst('#', '');

  // Handle shorthand #RGB format
  if (hexString.length == 3) {
    hexString = hexString.split('').map((c) => c + c).join();
  }

  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(hexString)) {
    throw FormatException('Invalid hex color digits: $hexString');
  }

  // Parse alpha if present (#RRGGBBAA)
  int alpha = 255;
  if (hexString.length == 8) {
    alpha = _parseHexComponent(hexString.substring(6, 8), hexString);
    hexString = hexString.substring(0, 6);
  } else if (hexString.length != 6) {
    throw FormatException('Invalid hex color length: $hexString');
  }

  final rgb = int.tryParse(hexString, radix: 16);
  if (rgb == null) {
    throw FormatException('Invalid hex color: $hexString');
  }
  return Color.fromARGB(
    alpha,
    (rgb >> 16) & 255, // Red
    (rgb >> 8) & 255, // Green
    rgb & 255, // Blue
  );
}

int _parseHexComponent(String component, String source) {
  final parsed = int.tryParse(component, radix: 16);
  if (parsed == null) {
    throw FormatException('Invalid hex color: $source');
  }
  return parsed;
}

/// Convert rgb string to Color
/// Format: rgb(r, g, b)
Color rgbStringToColor(String rgbString) {
  final components = _functionalColorComponents(rgbString, 'rgb');
  if (components.length != 3) {
    throw FormatException('Invalid rgb color: $rgbString');
  }

  final red = _parseRgbComponent(components[0], rgbString);
  final green = _parseRgbComponent(components[1], rgbString);
  final blue = _parseRgbComponent(components[2], rgbString);

  return Color.fromARGB(255, red, green, blue);
}

Color rgbaStringToColor(String rgbaString) {
  final components = _functionalColorComponents(rgbaString, 'rgba');
  if (components.length != 4) {
    throw FormatException('Invalid rgba color: $rgbaString');
  }

  final red = _parseRgbComponent(components[0], rgbaString);
  final green = _parseRgbComponent(components[1], rgbaString);
  final blue = _parseRgbComponent(components[2], rgbaString);
  final alpha = double.tryParse(components[3]);
  if (alpha == null) {
    throw FormatException('Invalid rgba alpha: $rgbaString');
  }
  final alphaInt = (alpha.clamp(0.0, 1.0) * 255).round();

  return Color.fromARGB(alphaInt, red, green, blue);
}

List<String> _functionalColorComponents(String colorString, String function) {
  final match = RegExp(
    '^\\s*$function\\s*\\((.*)\\)\\s*\$',
    caseSensitive: false,
  ).firstMatch(colorString);
  if (match == null) {
    throw FormatException('Invalid $function color: $colorString');
  }
  return match.group(1)!.split(',').map((part) => part.trim()).toList();
}

int _parseRgbComponent(String component, String source) {
  final parsed = int.tryParse(component);
  if (parsed == null) {
    throw FormatException('Invalid rgb component: $source');
  }
  return parsed.clamp(0, 255).toInt();
}

Color convertColor(String? name) {
  return safeStringToColor(name, Colors.grey);
}

double getMaxSeriesValue(List<Series> series) {
  double? maxValue;

  for (final seriesItem in series) {
    final data = seriesItem.data;
    if (data == null) continue;

    for (final item in data) {
      final value = ChartDataValueReader.yValueOrNull(item);
      if (value == null || !value.isFinite) continue;
      maxValue = maxValue == null || value > maxValue ? value : maxValue;
    }
  }

  if (maxValue == null || maxValue <= 0) return 100;
  final padding = maxValue.abs().toStringAsFixed(0).length * 10;
  return maxValue + padding;
}

Color getRandomColor() {
  Random random = Random();
  // Generate random RGB values
  int red = random.nextInt(256);
  int green = random.nextInt(256);
  int blue = random.nextInt(256);

  // Ensure the values remain in valid color range [0, 255]
  red = red.clamp(0, 255).toInt();
  green = green.clamp(0, 255).toInt();
  blue = blue.clamp(0, 255).toInt();
  Color color = Color.fromARGB(255, red, green, blue);
  return color; // Always full opacity
}

String getStringRandomColor() {
  // List of common color names
  final List<String> colorNames = [
    'black',
    'white',
    'red',
    'green',
    'blue',
    'yellow',
    'orange',
    'purple',
    'pink',
    'grey',
    'brown',
    'cyan',
    'teal',
    'indigo',
    'amber',
    'lime',
    'transparent',
  ];

  // Random number generator
  final Random random = Random();

  // Decide randomly whether to return a named color or an rgba string
  if (random.nextBool()) {
    // Return a random named color
    return colorNames[random.nextInt(colorNames.length)];
  } else {
    // Return a random rgba string
    int r = random.nextInt(256); // Red (0-255)
    int g = random.nextInt(256); // Green (0-255)
    int b = random.nextInt(256); // Blue (0-255)
    double a = (random.nextInt(101) / 100).clamp(0.0, 1.0); // Alpha (0.0-1.0)

    return 'rgba($r, $g, $b, $a)';
  }
}

Color getContrastColor(Color color) {
  // Calculate brightness using the luminance formula
  double brightness =
      (0.299 * (color.r * 255.0) +
          0.587 * (color.g * 255.0) +
          0.114 * (color.b * 255.0)) /
      255;

  // If the brightness is high, return black; otherwise, return white
  return brightness > 0.5 ? Color(0xFF000000) : Color(0xFFFFFFFF);
}
