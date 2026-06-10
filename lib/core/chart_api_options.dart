import 'package:flutter/widgets.dart';

class ChartInteractionOptions {
  final bool showTooltip;
  final bool showActiveElement;

  const ChartInteractionOptions({
    this.showTooltip = true,
    this.showActiveElement = true,
  });

  static const enabled = ChartInteractionOptions();
  static const quiet = ChartInteractionOptions(
    showTooltip: false,
    showActiveElement: false,
  );

  ChartInteractionOptions copyWith({
    bool? showTooltip,
    bool? showActiveElement,
  }) {
    return ChartInteractionOptions(
      showTooltip: showTooltip ?? this.showTooltip,
      showActiveElement: showActiveElement ?? this.showActiveElement,
    );
  }
}

class ChartVisibilityOptions {
  final bool showGrid;
  final bool showLegend;
  final bool showValues;
  final bool showLabels;
  final bool showAxisLabels;

  const ChartVisibilityOptions({
    this.showGrid = true,
    this.showLegend = true,
    this.showValues = false,
    this.showLabels = true,
    this.showAxisLabels = true,
  });

  static const clean = ChartVisibilityOptions(
    showGrid: false,
    showLegend: false,
    showValues: false,
  );

  ChartVisibilityOptions copyWith({
    bool? showGrid,
    bool? showLegend,
    bool? showValues,
    bool? showLabels,
    bool? showAxisLabels,
  }) {
    return ChartVisibilityOptions(
      showGrid: showGrid ?? this.showGrid,
      showLegend: showLegend ?? this.showLegend,
      showValues: showValues ?? this.showValues,
      showLabels: showLabels ?? this.showLabels,
      showAxisLabels: showAxisLabels ?? this.showAxisLabels,
    );
  }
}

class ChartAccessibilityOptions {
  final String? semanticLabel;
  final bool excludeFromSemantics;

  const ChartAccessibilityOptions({
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });

  static const decorative = ChartAccessibilityOptions(
    excludeFromSemantics: true,
  );

  Widget wrap(
    Widget child, {
    String? fallbackLabel,
    bool image = true,
    bool container = true,
  }) {
    if (excludeFromSemantics) {
      return ExcludeSemantics(child: child);
    }

    final label = semanticLabel?.trim().isNotEmpty == true
        ? semanticLabel!.trim()
        : fallbackLabel?.trim();
    if (label == null || label.isEmpty) return child;

    return Semantics(
      label: label,
      image: image,
      container: container,
      child: child,
    );
  }

  ChartAccessibilityOptions copyWith({
    String? semanticLabel,
    bool? excludeFromSemantics,
  }) {
    return ChartAccessibilityOptions(
      semanticLabel: semanticLabel ?? this.semanticLabel,
      excludeFromSemantics: excludeFromSemantics ?? this.excludeFromSemantics,
    );
  }
}

class ChartAnimationOptions {
  final Duration duration;
  final Curve curve;

  const ChartAnimationOptions({
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
  });

  static const standard = ChartAnimationOptions();
  static const quick = ChartAnimationOptions(
    duration: Duration(milliseconds: 280),
  );
  static const disabled = ChartAnimationOptions(
    duration: Duration.zero,
    curve: Curves.linear,
  );

  bool get isEnabled => duration > Duration.zero;

  ChartAnimationOptions copyWith({Duration? duration, Curve? curve}) {
    return ChartAnimationOptions(
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
    );
  }
}

class ChartApiDefaults {
  static const interaction = ChartInteractionOptions.enabled;
  static const visibility = ChartVisibilityOptions();
  static const accessibility = ChartAccessibilityOptions();
  static const animation = ChartAnimationOptions.standard;

  const ChartApiDefaults._();
}
