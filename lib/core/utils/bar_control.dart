import 'package:flutter/material.dart';

class BarControl extends StatefulWidget {
  const BarControl({super.key});

  @override
  State<BarControl> createState() => _BarControlState();
}

class _BarControlState extends State<BarControl> {
  @override
  Widget build(BuildContext context) {
    return _buildControls();
  }

  late LabelConfig labelConfig;

  @override
  void initState() {
    super.initState();
    labelConfig = LabelConfig();
  }

  Widget _buildControls() {
    return Column(
      children: [
        Row(
          children: [
            const Text('Rotate: '),
            Expanded(
              child: Slider(
                value: labelConfig.rotate,
                min: -90,
                max: 90,
                onChanged: (value) {
                  setState(() {
                    labelConfig = labelConfig.copyWith(rotate: value);
                  });
                },
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text('Distance: '),
            Expanded(
              child: Slider(
                value: labelConfig.distance,
                min: 0,
                max: 100,
                onChanged: (value) {
                  setState(() {
                    labelConfig = labelConfig.copyWith(distance: value);
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Enum for label position options
enum LabelPosition {
  left,
  right,
  top,
  bottom,
  inside,
  insideTop,
  insideLeft,
  insideRight,
  insideBottom,
  insideTopLeft,
  insideTopRight,
  insideBottomLeft,
  insideBottomRight,
}

// Configuration class for chart labels
class LabelConfig {
  final double rotate;
  final Alignment alignment;
  final LabelPosition position;
  final double distance;

  LabelConfig({
    this.rotate = 0,
    this.alignment = Alignment.center,
    this.position = LabelPosition.top,
    this.distance = 15,
  });

  LabelConfig copyWith({
    double? rotate,
    Alignment? alignment,
    LabelPosition? position,
    double? distance,
  }) {
    return LabelConfig(
      rotate: rotate ?? this.rotate,
      alignment: alignment ?? this.alignment,
      position: position ?? this.position,
      distance: distance ?? this.distance,
    );
  }
}
