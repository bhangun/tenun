import 'package:flutter/material.dart';

import 'chart_api_options.dart';

class ChartApiSurface extends StatelessWidget {
  final Widget child;
  final bool isEmpty;
  final double? width;
  final double? height;
  final WidgetBuilder? emptyBuilder;
  final String emptyLabel;
  final String? semanticLabel;
  final String? emptySemanticLabel;
  final ChartAccessibilityOptions accessibility;
  final bool semanticsImage;
  final bool semanticsContainer;

  const ChartApiSurface({
    super.key,
    required this.child,
    this.isEmpty = false,
    this.width,
    this.height,
    this.emptyBuilder,
    this.emptyLabel = 'No data',
    this.semanticLabel,
    this.emptySemanticLabel,
    this.accessibility = ChartApiDefaults.accessibility,
    this.semanticsImage = true,
    this.semanticsContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackLabel = isEmpty
        ? (emptySemanticLabel ?? semanticLabel)
        : semanticLabel;
    final hasSurfaceLabel =
        accessibility.semanticLabel?.trim().isNotEmpty == true ||
        fallbackLabel?.trim().isNotEmpty == true;
    final emptyContent =
        emptyBuilder?.call(context) ?? ChartApiEmptyState(label: emptyLabel);
    final content = isEmpty
        ? SizedBox(
            width: width,
            height: height,
            child: hasSurfaceLabel && !accessibility.excludeFromSemantics
                ? ExcludeSemantics(child: emptyContent)
                : emptyContent,
          )
        : child;

    return accessibility.wrap(
      content,
      fallbackLabel: fallbackLabel,
      image: semanticsImage,
      container: semanticsContainer,
    );
  }
}

class ChartApiEmptyState extends StatelessWidget {
  final String label;
  final TextStyle? style;
  final Alignment alignment;
  final EdgeInsets padding;

  const ChartApiEmptyState({
    super.key,
    this.label = 'No data',
    this.style,
    this.alignment = Alignment.center,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style:
              style ??
              theme.textTheme.bodySmall?.copyWith(color: color) ??
              TextStyle(color: color, fontSize: 12),
        ),
      ),
    );
  }
}
