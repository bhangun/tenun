import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/base_config.dart';
import '../core/chart_controller.dart';

/// Wraps charts in `Semantics`, handles RTL mirroring & keyboard focus.
class ChartAccessibilityLayer extends StatelessWidget {
  final Widget child;
  final BaseChartConfig config;
  final ChartController? controller;

  const ChartAccessibilityLayer({
    super.key,
    required this.child,
    required this.config,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final totalPts = config.series.fold(0, (s, d) => s + (d.data?.length ?? 0));

    return Semantics(
      label: config.title?.text ?? 'Interactive Chart',
      value: '${config.series.length} series, $totalPts data points',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Focus(
          canRequestFocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                controller?.selectIndex(
                  (controller!.zoom.start + 1).clamp(0, 999),
                );
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                controller?.selectIndex(
                  (controller!.zoom.start - 1).clamp(0, 999),
                );
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: child,
        ),
      ),
    );
  }
}
