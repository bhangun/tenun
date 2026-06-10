// Chart theming system.
//
// A [ChartTheme] holds all visual tokens (colors, typography, spacing) so that
// every chart type can render consistently without hard-coded values.
//
// Usage:
// ```dart
// TenunChart(
//   config: myConfig.withTheme(ChartTheme.material()),
// )
// ```

import 'package:flutter/material.dart';

import 'chart_cache.dart';
import 'json_value.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// An ordered list of series colors.
class ChartPalette {
  final List<String> colors;
  const ChartPalette(this.colors);

  String colorAt(int index) => colors[index % colors.length];
  Color colorObjectAt(int index) => colorCache.resolve(colorAt(index));

  // ---- Built-in palettes ----

  static const ChartPalette material = ChartPalette([
    '#2196F3',
    '#4CAF50',
    '#FF9800',
    '#E91E63',
    '#9C27B0',
    '#00BCD4',
    '#FF5722',
    '#607D8B',
    '#8BC34A',
    '#FFC107',
  ]);

  static const ChartPalette pastel = ChartPalette([
    '#AED6F1',
    '#A9DFBF',
    '#FAD7A0',
    '#F1948A',
    '#C39BD3',
    '#76D7C4',
    '#F9E79F',
    '#A8A8A8',
    '#85C1E9',
    '#F0B27A',
  ]);

  static const ChartPalette vivid = ChartPalette([
    '#FF1744',
    '#00E676',
    '#2979FF',
    '#FF6D00',
    '#D500F9',
    '#00B0FF',
    '#76FF03',
    '#FFEA00',
    '#F50057',
    '#1DE9B6',
  ]);

  static const ChartPalette earthy = ChartPalette([
    '#795548',
    '#8D6E63',
    '#A1887F',
    '#BCAAA4',
    '#D7CCC8',
    '#6D4C41',
    '#5D4037',
    '#4E342E',
    '#3E2723',
    '#BCAAA4',
  ]);

  static const ChartPalette ocean = ChartPalette([
    '#006064',
    '#00838F',
    '#00ACC1',
    '#00BCD4',
    '#26C6DA',
    '#4DD0E1',
    '#80DEEA',
    '#B2EBF2',
    '#E0F7FA',
    '#01579B',
  ]);
}

// ---------------------------------------------------------------------------
// Typography tokens
// ---------------------------------------------------------------------------

class ChartTypography {
  final double titleSize;
  final double subtitleSize;
  final double axisLabelSize;
  final double axisTitleSize;
  final double legendSize;
  final double tooltipSize;
  final double dataLabelSize;
  final String fontFamily;
  final FontWeight titleWeight;
  final FontWeight labelWeight;

  const ChartTypography({
    this.titleSize = 16,
    this.subtitleSize = 13,
    this.axisLabelSize = 11,
    this.axisTitleSize = 12,
    this.legendSize = 12,
    this.tooltipSize = 12,
    this.dataLabelSize = 10,
    this.fontFamily = '',
    this.titleWeight = FontWeight.w600,
    this.labelWeight = FontWeight.w400,
  });

  TextStyle? get dataLabelStyle => null; // resolved in caller
  TextStyle get titleStyle => TextStyle(
    fontSize: titleSize,
    fontWeight: titleWeight,
    fontFamily: fontFamily.isEmpty ? null : fontFamily,
  );

  TextStyle get axisLabelStyle => TextStyle(
    fontSize: axisLabelSize,
    fontWeight: labelWeight,
    fontFamily: fontFamily.isEmpty ? null : fontFamily,
  );

  TextStyle get legendStyle => TextStyle(
    fontSize: legendSize,
    fontWeight: labelWeight,
    fontFamily: fontFamily.isEmpty ? null : fontFamily,
  );

  TextStyle get tooltipStyle => TextStyle(
    fontSize: tooltipSize,
    fontWeight: labelWeight,
    fontFamily: fontFamily.isEmpty ? null : fontFamily,
  );
}

// ---------------------------------------------------------------------------
// Spacing / dimension tokens
// ---------------------------------------------------------------------------

class ChartSpacing {
  final double chartPaddingLeft;
  final double chartPaddingRight;
  final double chartPaddingTop;
  final double chartPaddingBottom;
  final double legendGap;
  final double legendIconSize;
  final double tooltipPadding;
  final double barBorderRadius;
  final double dotRadius;
  final double strokeWidth;
  final double gridLineWidth;

  const ChartSpacing({
    this.chartPaddingLeft = 48,
    this.chartPaddingRight = 16,
    this.chartPaddingTop = 16,
    this.chartPaddingBottom = 32,
    this.legendGap = 12,
    this.legendIconSize = 10,
    this.tooltipPadding = 8,
    this.barBorderRadius = 4,
    this.dotRadius = 4,
    this.strokeWidth = 2,
    this.gridLineWidth = 0.5,
  });
}

// ---------------------------------------------------------------------------
// ChartTheme
// ---------------------------------------------------------------------------

class ChartTheme {
  final ChartPalette palette;
  final ChartTypography typography;
  final ChartSpacing spacing;

  // General colors
  final Color backgroundColor;
  final Color gridColor;
  final Color axisColor;
  final Color axisLabelColor;
  final Color titleColor;
  final Color legendTextColor;
  final Color tooltipBackgroundColor;
  final Color tooltipTextColor;
  final Color tooltipBorderColor;
  final Color crosshairColor;

  // Interaction
  final Color highlightOverlayColor;
  final double highlightOverlayOpacity;

  const ChartTheme({
    this.palette = ChartPalette.material,
    this.typography = const ChartTypography(),
    this.spacing = const ChartSpacing(),
    this.backgroundColor = Colors.transparent,
    this.gridColor = const Color(0x1A000000), // 10% black
    this.axisColor = const Color(0x33000000), // 20% black
    this.axisLabelColor = const Color(0xFF666666),
    this.titleColor = const Color(0xFF1A1A1A),
    this.legendTextColor = const Color(0xFF444444),
    this.tooltipBackgroundColor = const Color(0xFF1A1A2E),
    this.tooltipTextColor = Colors.white,
    this.tooltipBorderColor = Colors.transparent,
    this.crosshairColor = const Color(0x44000000),
    this.highlightOverlayColor = Colors.white,
    this.highlightOverlayOpacity = 0.15,
  });

  // ---- Built-in themes ----

  /// Clean light theme (default).
  static const ChartTheme light = ChartTheme();

  /// Dark theme.
  static const ChartTheme dark = ChartTheme(
    palette: ChartPalette.vivid,
    backgroundColor: Color(0xFF1E1E2E),
    gridColor: Color(0x22FFFFFF),
    axisColor: Color(0x44FFFFFF),
    axisLabelColor: Color(0xFFAAAAAA),
    titleColor: Color(0xFFEEEEEE),
    legendTextColor: Color(0xFFCCCCCC),
    tooltipBackgroundColor: Color(0xFF2A2A3E),
    tooltipTextColor: Colors.white,
    crosshairColor: Color(0x66FFFFFF),
  );

  /// High-contrast accessibility theme.
  static const ChartTheme highContrast = ChartTheme(
    palette: ChartPalette.vivid,
    typography: ChartTypography(
      axisLabelSize: 13,
      titleSize: 18,
      legendSize: 13,
    ),
    spacing: ChartSpacing(strokeWidth: 3, gridLineWidth: 1),
    gridColor: Color(0xFF444444),
    axisColor: Color(0xFF000000),
    axisLabelColor: Color(0xFF000000),
    titleColor: Color(0xFF000000),
  );

  /// Resolve a series color — prefers explicit series color, falls back to palette.
  /// Supports both String hex colors and Color objects to ease compatibility.
  Color seriesColor(int index, {Object? explicitColor}) {
    if (explicitColor is Color) {
      return explicitColor;
    }
    if (explicitColor is String && explicitColor.isNotEmpty) {
      try {
        return colorCache.resolve(explicitColor);
      } catch (_) {}
    }
    return palette.colorObjectAt(index);
  }

  /// Create a copy with overridden values.
  ChartTheme copyWith({
    ChartPalette? palette,
    ChartTypography? typography,
    ChartSpacing? spacing,
    Color? backgroundColor,
    Color? gridColor,
    Color? axisColor,
    Color? axisLabelColor,
    Color? titleColor,
    Color? legendTextColor,
    Color? tooltipBackgroundColor,
    Color? tooltipTextColor,
    Color? tooltipBorderColor,
    Color? crosshairColor,
  }) => ChartTheme(
    palette: palette ?? this.palette,
    typography: typography ?? this.typography,
    spacing: spacing ?? this.spacing,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    gridColor: gridColor ?? this.gridColor,
    axisColor: axisColor ?? this.axisColor,
    axisLabelColor: axisLabelColor ?? this.axisLabelColor,
    titleColor: titleColor ?? this.titleColor,
    legendTextColor: legendTextColor ?? this.legendTextColor,
    tooltipBackgroundColor:
        tooltipBackgroundColor ?? this.tooltipBackgroundColor,
    tooltipTextColor: tooltipTextColor ?? this.tooltipTextColor,
    tooltipBorderColor: tooltipBorderColor ?? this.tooltipBorderColor,
    crosshairColor: crosshairColor ?? this.crosshairColor,
  );

  /// Parse from JSON config (e.g., passed alongside chart config).
  factory ChartTheme.fromJson(Object? raw) {
    final json = JsonValue.map(raw);
    if (json == null) return ChartTheme.light;
    final mode = json['mode']?.toString().toLowerCase();
    if (mode == 'dark') return ChartTheme.dark;
    if (mode == 'highcontrast') return ChartTheme.highContrast;

    Color? bgColor;
    if (json['backgroundColor'] != null) {
      try {
        bgColor = colorCache.resolve(json['backgroundColor']);
      } catch (_) {}
    }

    final rawPalette = JsonValue.list(json['palette']);
    final paletteColors = rawPalette == null
        ? null
        : [
            for (final value in rawPalette)
              if (_isResolvableColor(value?.toString())) value!.toString(),
          ];

    return ChartTheme.light.copyWith(
      backgroundColor: bgColor,
      palette: paletteColors != null && paletteColors.isNotEmpty
          ? ChartPalette(paletteColors)
          : null,
    );
  }
}

bool _isResolvableColor(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return false;
  try {
    colorCache.resolve(text);
    return true;
  } catch (_) {
    return false;
  }
}
