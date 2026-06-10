import 'package:flutter/material.dart';
import 'chart_controller.dart';

/// Unified hit-test result emitted by chart painters.
class ChartHitResult {
  final int seriesIndex;
  final int dataIndex;
  final Offset localPosition;
  final dynamic value;
  const ChartHitResult({
    required this.seriesIndex,
    required this.dataIndex,
    required this.localPosition,
    this.value,
  });
}

typedef ChartTapCallback = void Function(ChartHitResult hit);
typedef ChartCrosshairCallback = void Function(ChartHitResult? hit);

/// Drop-in interaction layer that wraps any Tenun chart.
/// Handles:
/// - RTL-aware coordinate flipping
/// - Screen reader semantics
/// - Crosshair & tooltip anchoring
/// - Unified callback signatures
class TenunInteractionLayer extends StatefulWidget {
  final Widget child;
  final ChartController? controller;
  final ChartTapCallback? onTap;
  final ChartCrosshairCallback? onCrosshairMove;
  final String? semanticsLabel;
  final bool enableRtl;
  final bool showCrosshair;

  const TenunInteractionLayer({
    super.key,
    required this.child,
    this.controller,
    this.onTap,
    this.onCrosshairMove,
    this.semanticsLabel,
    this.enableRtl = true,
    this.showCrosshair = true,
  });

  @override
  State<TenunInteractionLayer> createState() => _TenunInteractionLayerState();
}

class _TenunInteractionLayerState extends State<TenunInteractionLayer> {
  bool _isHovering = false;
  Offset _pointerPos = Offset.zero;
  ChartHitResult? _activeHit;

  @override
  Widget build(BuildContext context) {
    final textDir = widget.enableRtl
        ? (Directionality.maybeOf(context) ?? TextDirection.ltr)
        : TextDirection.ltr;
    final isRtl = textDir == TextDirection.rtl;
    final chartSize = MediaQuery.sizeOf(context);

    return Semantics(
      label: widget.semanticsLabel ?? 'Interactive data chart',
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (details) {
          if (_activeHit != null) widget.onTap?.call(_activeHit!);
        },
        child: MouseRegion(
          onHover: (e) => _handleMove(e.localPosition, isRtl, chartSize),
          onExit: (_) => _handleExit(),
          child: Stack(
            children: [
              widget.child,
              if (widget.showCrosshair && _isHovering)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CrosshairPainter(
                        x: _pointerPos.dx,
                        y: _pointerPos.dy,
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMove(Offset localPos, bool isRtl, Size chartSize) {
    final adjustedPos = isRtl
        ? Offset(chartSize.width - localPos.dx, localPos.dy)
        : localPos;
    setState(() {
      _isHovering = true;
      _pointerPos = adjustedPos;
      // Hit-testing is delegated to the chart painter via controller
      _activeHit = widget.controller?.resolveHitAt(adjustedPos);
      widget.onCrosshairMove?.call(_activeHit);
    });
  }

  void _handleExit() {
    setState(() {
      _isHovering = false;
      _activeHit = null;
    });
    widget.onCrosshairMove?.call(null);
  }
}

class _CrosshairPainter extends CustomPainter {
  final double x, y;
  final Color color;
  _CrosshairPainter({required this.x, required this.y, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter old) =>
      old.x != x || old.y != y;
}
