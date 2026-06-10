import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleFunnelValueFormatter = String Function(double value);
typedef SimpleFunnelTapCallback =
    void Function(
      SimpleFunnelChartData data,
      int index,
      double share,
      double conversionRate,
    );
typedef SimpleFunnelTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleFunnelChartData data,
      int index,
      String formattedValue,
      String formattedShare,
      String formattedConversionRate,
    );

enum SimpleFunnelMode { funnel, pyramid }

class SimpleFunnelChartData {
  final String label;
  final double value;
  final Color? color;

  const SimpleFunnelChartData({
    required this.label,
    required this.value,
    this.color,
  });
}

/// A lightweight funnel chart for conversion, stage drop-off, pipeline, and
/// step-by-step flow summaries.
class SimpleFunnelChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(18, 14, 18, 14);

  final List<SimpleFunnelChartData> data;
  final SimpleFunnelMode mode;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? stageColor;
  final Color? trackColor;
  final Color? borderColor;
  final Color? activeColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showPercentages;
  final bool showConversionRates;
  final bool showTrack;
  final bool showTooltip;
  final bool showActiveStage;
  final double neckWidthFactor;
  final double stageGap;
  final double stageRadius;
  final bool? useGradient;
  final SimpleFunnelValueFormatter? valueFormatter;
  final SimpleFunnelValueFormatter? percentFormatter;
  final SimpleFunnelTapCallback? onStageTap;
  final SimpleFunnelTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleFunnelChart({
    super.key,
    required this.data,
    this.mode = SimpleFunnelMode.funnel,
    this.style = SimpleBarChartStyle.elegant,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.stageColor,
    this.trackColor,
    this.borderColor,
    this.activeColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = true,
    this.showPercentages = true,
    this.showConversionRates = false,
    this.showTrack = false,
    this.showTooltip = true,
    this.showActiveStage = true,
    this.neckWidthFactor = 0.22,
    this.stageGap = 6,
    this.stageRadius = 6,
    this.useGradient,
    this.valueFormatter,
    this.percentFormatter,
    this.onStageTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(neckWidthFactor >= 0 && neckWidthFactor <= 1),
       assert(stageGap >= 0),
       assert(stageRadius >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleFunnelVisuals.resolve(style, colorScheme);
    final visibleData = data
        .where((item) => item.value.isFinite && item.value >= 0)
        .toList();
    final maxValue = _maxValue(visibleData);
    final referenceValue = visibleData.isEmpty
        ? 0.0
        : math.max(visibleData.first.value, 0.0);
    final formatter = valueFormatter ?? _defaultValueFormatter;
    final resolvedPercentFormatter =
        percentFormatter ?? _defaultPercentFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleData.isEmpty || maxValue <= 0) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Funnel chart, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedLabelStyle =
            labelStyle ??
            theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            );
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
        final resolvedPalette = _resolvePalette(colorScheme, visuals.palette);

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleData,
            referenceValue > 0 ? referenceValue : maxValue,
            formatter,
            resolvedPercentFormatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleFunnelChartView(
            width: width,
            height: chartHeight,
            data: visibleData,
            mode: mode,
            padding: padding,
            palette: resolvedPalette,
            trackColor: trackColor ?? visuals.trackColor,
            borderColor: borderColor ?? visuals.borderColor,
            activeColor: activeColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showPercentages: showPercentages,
            showConversionRates: showConversionRates,
            showTrack: showTrack,
            showTooltip: showTooltip,
            showActiveStage: showActiveStage,
            neckWidthFactor: neckWidthFactor,
            stageGap: stageGap,
            stageRadius: stageRadius,
            maxValue: maxValue,
            referenceValue: referenceValue > 0 ? referenceValue : maxValue,
            useGradient: useGradient ?? visuals.useGradient,
            valueFormatter: formatter,
            percentFormatter: resolvedPercentFormatter,
            onStageTap: onStageTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  List<Color> _resolvePalette(ColorScheme colorScheme, List<Color> defaults) {
    if (palette != null && palette!.isNotEmpty) return palette!;
    if (stageColor != null) {
      return [
        stageColor!,
        colorScheme.secondary,
        colorScheme.tertiary,
        colorScheme.error,
      ];
    }
    return defaults;
  }

  String _defaultSemanticLabel(
    List<SimpleFunnelChartData> visibleData,
    double referenceValue,
    SimpleFunnelValueFormatter formatter,
    SimpleFunnelValueFormatter resolvedPercentFormatter,
  ) {
    final summaries = visibleData
        .take(6)
        .map((item) {
          final share = referenceValue <= 0 ? 0.0 : item.value / referenceValue;
          return '${item.label} ${formatter(item.value)}, '
              '${resolvedPercentFormatter(share)}';
        })
        .join(', ');
    final remaining = visibleData.length - math.min(visibleData.length, 6);
    final suffix = remaining > 0 ? ', and $remaining more' : '';
    final countLabel = visibleData.length == 1 ? 'stage' : 'stages';
    return 'Funnel chart, ${visibleData.length} $countLabel. '
        '$summaries$suffix.';
  }

  static double _maxValue(List<SimpleFunnelChartData> data) {
    if (data.isEmpty) return 0;
    return data.fold<double>(
      0,
      (current, item) => math.max(current, item.value),
    );
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  static String _defaultPercentFormatter(double value) {
    final percent = value * 100;
    if (percent == percent.roundToDouble()) {
      return '${percent.toInt()}%';
    }
    return '${percent.toStringAsFixed(1)}%';
  }
}

class _SimpleFunnelChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleFunnelChartData> data;
  final SimpleFunnelMode mode;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color trackColor;
  final Color borderColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showPercentages;
  final bool showConversionRates;
  final bool showTrack;
  final bool showTooltip;
  final bool showActiveStage;
  final double neckWidthFactor;
  final double stageGap;
  final double stageRadius;
  final double maxValue;
  final double referenceValue;
  final bool useGradient;
  final SimpleFunnelValueFormatter valueFormatter;
  final SimpleFunnelValueFormatter percentFormatter;
  final SimpleFunnelTapCallback? onStageTap;
  final SimpleFunnelTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleFunnelChartView({
    required this.width,
    required this.height,
    required this.data,
    required this.mode,
    required this.padding,
    required this.palette,
    required this.trackColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showPercentages,
    required this.showConversionRates,
    required this.showTrack,
    required this.showTooltip,
    required this.showActiveStage,
    required this.neckWidthFactor,
    required this.stageGap,
    required this.stageRadius,
    required this.maxValue,
    required this.referenceValue,
    required this.useGradient,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.onStageTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleFunnelChartView> createState() => _SimpleFunnelChartViewState();
}

class _SimpleFunnelChartViewState extends State<_SimpleFunnelChartView> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final interactionEnabled =
        widget.showTooltip ||
        widget.showActiveStage ||
        widget.onStageTap != null;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final chart = TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: widget.animationDuration,
            curve: widget.animationCurve,
            builder: (context, progress, child) {
              return CustomPaint(
                painter: _SimpleFunnelPainter(
                  data: widget.data,
                  mode: widget.mode,
                  padding: widget.padding,
                  palette: widget.palette,
                  trackColor: widget.trackColor,
                  borderColor: widget.borderColor,
                  activeColor: widget.activeColor,
                  labelStyle: widget.labelStyle,
                  valueStyle: widget.valueStyle,
                  showLabels: widget.showLabels,
                  showValues: widget.showValues,
                  showPercentages: widget.showPercentages,
                  showConversionRates: widget.showConversionRates,
                  showTrack: widget.showTrack,
                  neckWidthFactor: widget.neckWidthFactor,
                  stageGap: widget.stageGap,
                  stageRadius: widget.stageRadius,
                  maxValue: widget.maxValue,
                  referenceValue: widget.referenceValue,
                  useGradient: widget.useGradient,
                  activeIndex: widget.showActiveStage ? _activeIndex : null,
                  valueFormatter: widget.valueFormatter,
                  percentFormatter: widget.percentFormatter,
                  progress: progress,
                ),
              );
            },
          );

          if (!interactionEnabled) return chart;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (event) =>
                      _setActive(_hitTest(event.localPosition, size)),
                  onExit: (_) => _setActive(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final index = _hitTest(details.localPosition, size);
                      _setActive(index);
                      if (index == null) return;
                      widget.onStageTap?.call(
                        widget.data[index],
                        index,
                        _shareFor(index),
                        _conversionFor(index),
                      );
                    },
                    child: chart,
                  ),
                ),
              ),
              if (widget.showTooltip && _activeIndex != null)
                _buildTooltip(context, size, _activeIndex!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(int? index) {
    if (_activeIndex == index) return;
    setState(() => _activeIndex = index);
  }

  int? _hitTest(Offset position, Size size) {
    final geometry = _FunnelGeometry.resolve(
      size: size,
      data: widget.data,
      padding: widget.padding,
      mode: widget.mode,
      maxValue: widget.maxValue,
      neckWidthFactor: widget.neckWidthFactor,
      stageGap: widget.stageGap,
    );
    for (var index = 0; index < geometry.stages.length; index++) {
      if (geometry.pathFor(index, 1, widget.stageRadius).contains(position)) {
        return index;
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size, int index) {
    final item = widget.data[index];
    final formattedValue = widget.valueFormatter(item.value);
    final formattedShare = widget.percentFormatter(_shareFor(index));
    final formattedConversion = widget.percentFormatter(_conversionFor(index));
    final geometry = _FunnelGeometry.resolve(
      size: size,
      data: widget.data,
      padding: widget.padding,
      mode: widget.mode,
      maxValue: widget.maxValue,
      neckWidthFactor: widget.neckWidthFactor,
      stageGap: widget.stageGap,
    );
    final anchor = geometry.stages[index].rect.center;
    const tooltipWidth = 174.0;
    final tooltipHeight = widget.showConversionRates ? 84.0 : 68.0;
    final left = (anchor.dx + 10)
        .clamp(4.0, math.max(4.0, size.width - tooltipWidth - 4))
        .toDouble();
    final top = (anchor.dy - tooltipHeight / 2)
        .clamp(4.0, math.max(4.0, size.height - tooltipHeight - 4))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      width: tooltipWidth,
      child:
          widget.tooltipBuilder?.call(
            context,
            item,
            index,
            formattedValue,
            formattedShare,
            formattedConversion,
          ) ??
          _DefaultFunnelTooltip(
            color: _stageColor(item, index),
            title: item.label,
            rows: [
              _FunnelTooltipRow(label: 'Value', value: formattedValue),
              _FunnelTooltipRow(label: 'Share', value: formattedShare),
              if (widget.showConversionRates)
                _FunnelTooltipRow(label: 'Step', value: formattedConversion),
            ],
          ),
    );
  }

  double _shareFor(int index) {
    if (widget.referenceValue <= 0) return 0;
    return widget.data[index].value / widget.referenceValue;
  }

  double _conversionFor(int index) {
    if (index <= 0) return 1;
    final previous = widget.data[index - 1].value;
    if (previous <= 0) return 0;
    return widget.data[index].value / previous;
  }

  Color _stageColor(SimpleFunnelChartData item, int index) {
    return item.color ?? widget.palette[index % widget.palette.length];
  }
}

class _SimpleFunnelPainter extends CustomPainter {
  final List<SimpleFunnelChartData> data;
  final SimpleFunnelMode mode;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color trackColor;
  final Color borderColor;
  final Color? activeColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showPercentages;
  final bool showConversionRates;
  final bool showTrack;
  final double neckWidthFactor;
  final double stageGap;
  final double stageRadius;
  final double maxValue;
  final double referenceValue;
  final bool useGradient;
  final int? activeIndex;
  final SimpleFunnelValueFormatter valueFormatter;
  final SimpleFunnelValueFormatter percentFormatter;
  final double progress;

  const _SimpleFunnelPainter({
    required this.data,
    required this.mode,
    required this.padding,
    required this.palette,
    required this.trackColor,
    required this.borderColor,
    required this.activeColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showPercentages,
    required this.showConversionRates,
    required this.showTrack,
    required this.neckWidthFactor,
    required this.stageGap,
    required this.stageRadius,
    required this.maxValue,
    required this.referenceValue,
    required this.useGradient,
    required this.activeIndex,
    required this.valueFormatter,
    required this.percentFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _FunnelGeometry.resolve(
      size: size,
      data: data,
      padding: padding,
      mode: mode,
      maxValue: maxValue,
      neckWidthFactor: neckWidthFactor,
      stageGap: stageGap,
    );
    if (geometry.stages.isEmpty || geometry.plot.isEmpty) return;

    for (var index = 0; index < geometry.stages.length; index++) {
      final stage = geometry.stages[index];
      if (showTrack) {
        final trackStage = stage.copyWith(
          topWidth: geometry.plot.width,
          bottomWidth: geometry.plot.width,
        );
        canvas.drawPath(
          _roundedStagePath(trackStage, 1, stageRadius),
          Paint()..color = trackColor,
        );
      }

      final item = data[index];
      final color = item.color ?? palette[index % palette.length];
      final path = geometry.pathFor(index, progress, stageRadius);
      canvas.drawPath(path, _stagePaint(color, stage.rect));
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      if (activeIndex == index) {
        final active = activeColor ?? color;
        canvas.drawPath(path, Paint()..color = active.withValues(alpha: 0.16));
        canvas.drawPath(
          path,
          Paint()
            ..color = active.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      _drawStageText(canvas, stage, item, color, index);
    }
  }

  Paint _stagePaint(Color color, Rect rect) {
    if (!useGradient) return Paint()..color = color;
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.96), color.withValues(alpha: 0.72)],
      ).createShader(rect);
  }

  void _drawStageText(
    Canvas canvas,
    _FunnelStage stage,
    SimpleFunnelChartData item,
    Color color,
    int index,
  ) {
    if (!showLabels &&
        !showValues &&
        !showPercentages &&
        !showConversionRates) {
      return;
    }
    if (stage.rect.height < 24 || progress < 0.45) return;

    final textColor = color.computeLuminance() > 0.54
        ? Colors.black.withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.94);
    final line1 = showLabels ? item.label : null;
    final line2Parts = <String>[
      if (showValues) valueFormatter(item.value),
      if (showPercentages) percentFormatter(_shareFor(item)),
      if (showConversionRates && index > 0)
        '${percentFormatter(_conversionFor(index))} step',
    ];
    final line2 = line2Parts.join('  ');
    final availableWidth =
        math.max(0.0, math.max(stage.topWidth, stage.bottomWidth) * progress) -
        18;
    if (availableWidth < 28) return;

    final spans = <InlineSpan>[
      if (line1 != null)
        TextSpan(
          text: line1,
          style: labelStyle.copyWith(color: textColor),
        ),
      if (line1 != null && line2.isNotEmpty) const TextSpan(text: '\n'),
      if (line2.isNotEmpty)
        TextSpan(
          text: line2,
          style: valueStyle.copyWith(color: textColor.withValues(alpha: 0.86)),
        ),
    ];
    if (spans.isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(children: spans),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: availableWidth);

    final offset = Offset(
      stage.rect.center.dx - painter.width / 2,
      stage.rect.center.dy - painter.height / 2,
    );
    painter.paint(canvas, offset);
  }

  double _shareFor(SimpleFunnelChartData item) {
    if (referenceValue <= 0) return 0;
    return item.value / referenceValue;
  }

  double _conversionFor(int index) {
    if (index <= 0) return 1;
    final previous = data[index - 1].value;
    if (previous <= 0) return 0;
    return data[index].value / previous;
  }

  @override
  bool shouldRepaint(covariant _SimpleFunnelPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.mode != mode ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showPercentages != showPercentages ||
        oldDelegate.showConversionRates != showConversionRates ||
        oldDelegate.showTrack != showTrack ||
        oldDelegate.neckWidthFactor != neckWidthFactor ||
        oldDelegate.stageGap != stageGap ||
        oldDelegate.stageRadius != stageRadius ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.referenceValue != referenceValue ||
        oldDelegate.useGradient != useGradient ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.valueFormatter != valueFormatter ||
        oldDelegate.percentFormatter != percentFormatter ||
        oldDelegate.progress != progress;
  }
}

class _FunnelGeometry {
  final Rect plot;
  final List<_FunnelStage> stages;

  const _FunnelGeometry({required this.plot, required this.stages});

  factory _FunnelGeometry.resolve({
    required Size size,
    required List<SimpleFunnelChartData> data,
    required EdgeInsets padding,
    required SimpleFunnelMode mode,
    required double maxValue,
    required double neckWidthFactor,
    required double stageGap,
  }) {
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(0.0, size.width - padding.horizontal),
      math.max(0.0, size.height - padding.vertical),
    );
    if (plot.width <= 0 || plot.height <= 0 || data.isEmpty || maxValue <= 0) {
      return _FunnelGeometry(plot: plot, stages: const []);
    }

    final count = data.length;
    final gap = count > 1
        ? math.min(stageGap, plot.height / (count - 1) * 0.42)
        : 0.0;
    final stageHeight = math.max(0.0, plot.height - gap * (count - 1)) / count;
    if (stageHeight <= 0) {
      return _FunnelGeometry(plot: plot, stages: const []);
    }

    double widthForValue(double value) {
      final share = (value / maxValue).clamp(0.0, 1.0).toDouble();
      return (neckWidthFactor + share * (1 - neckWidthFactor)) * plot.width;
    }

    final widths = data.map((item) => widthForValue(item.value)).toList();
    final neckWidth = neckWidthFactor * plot.width;
    final stages = <_FunnelStage>[];
    for (var index = 0; index < count; index++) {
      final rect = Rect.fromLTWH(
        plot.left,
        plot.top + index * (stageHeight + gap),
        plot.width,
        stageHeight,
      );
      final currentWidth = widths[index];
      final nextWidth = index + 1 < count ? widths[index + 1] : neckWidth;
      final topWidth = mode == SimpleFunnelMode.funnel
          ? currentWidth
          : nextWidth;
      final bottomWidth = mode == SimpleFunnelMode.funnel
          ? nextWidth
          : currentWidth;
      stages.add(
        _FunnelStage(
          rect: rect,
          topWidth: topWidth.clamp(0.0, plot.width).toDouble(),
          bottomWidth: bottomWidth.clamp(0.0, plot.width).toDouble(),
        ),
      );
    }
    return _FunnelGeometry(plot: plot, stages: stages);
  }

  Path pathFor(int index, double progress, double radius) {
    return _roundedStagePath(stages[index], progress, radius);
  }
}

class _FunnelStage {
  final Rect rect;
  final double topWidth;
  final double bottomWidth;

  const _FunnelStage({
    required this.rect,
    required this.topWidth,
    required this.bottomWidth,
  });

  _FunnelStage copyWith({Rect? rect, double? topWidth, double? bottomWidth}) {
    return _FunnelStage(
      rect: rect ?? this.rect,
      topWidth: topWidth ?? this.topWidth,
      bottomWidth: bottomWidth ?? this.bottomWidth,
    );
  }
}

Path _roundedStagePath(_FunnelStage stage, double progress, double radius) {
  final resolvedProgress = progress.clamp(0.0, 1.0).toDouble();
  final centerX = stage.rect.center.dx;
  final topWidth = stage.topWidth * resolvedProgress;
  final bottomWidth = stage.bottomWidth * resolvedProgress;
  final topLeft = Offset(centerX - topWidth / 2, stage.rect.top);
  final topRight = Offset(centerX + topWidth / 2, stage.rect.top);
  final bottomRight = Offset(centerX + bottomWidth / 2, stage.rect.bottom);
  final bottomLeft = Offset(centerX - bottomWidth / 2, stage.rect.bottom);
  return _roundedPolygonPath([
    topLeft,
    topRight,
    bottomRight,
    bottomLeft,
  ], math.min(radius, stage.rect.height / 2));
}

Path _roundedPolygonPath(List<Offset> points, double radius) {
  final path = Path();
  if (points.isEmpty) return path;
  if (radius <= 0) {
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  Offset cornerStart(int index) {
    final point = points[index];
    final previous = points[(index - 1 + points.length) % points.length];
    final distance = (previous - point).distance;
    if (distance <= 0) return point;
    final amount = math.min(radius, distance / 2);
    return Offset(
      point.dx + (previous.dx - point.dx) / distance * amount,
      point.dy + (previous.dy - point.dy) / distance * amount,
    );
  }

  Offset cornerEnd(int index) {
    final point = points[index];
    final next = points[(index + 1) % points.length];
    final distance = (next - point).distance;
    if (distance <= 0) return point;
    final amount = math.min(radius, distance / 2);
    return Offset(
      point.dx + (next.dx - point.dx) / distance * amount,
      point.dy + (next.dy - point.dy) / distance * amount,
    );
  }

  final first = cornerStart(0);
  path.moveTo(first.dx, first.dy);
  for (var index = 0; index < points.length; index++) {
    final point = points[index];
    final end = cornerEnd(index);
    path.quadraticBezierTo(point.dx, point.dy, end.dx, end.dy);
    final nextStart = cornerStart((index + 1) % points.length);
    path.lineTo(nextStart.dx, nextStart.dy);
  }
  path.close();
  return path;
}

class _SimpleFunnelVisuals {
  final List<Color> palette;
  final Color trackColor;
  final Color borderColor;
  final bool useGradient;

  const _SimpleFunnelVisuals({
    required this.palette,
    required this.trackColor,
    required this.borderColor,
    required this.useGradient,
  });

  factory _SimpleFunnelVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleFunnelVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFF6366F1),
          ],
          trackColor: colorScheme.primary.withValues(alpha: 0.08),
          borderColor: colorScheme.surface.withValues(alpha: 0.55),
          useGradient: true,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleFunnelVisuals(
          palette: [
            colorScheme.primary,
            const Color(0xFF475569),
            const Color(0xFF64748B),
            const Color(0xFF0F766E),
            const Color(0xFF1D4ED8),
          ],
          trackColor: colorScheme.outline.withValues(alpha: 0.08),
          borderColor: colorScheme.surface.withValues(alpha: 0.7),
          useGradient: false,
        );
      case SimpleBarChartStyle.education:
        return _SimpleFunnelVisuals(
          palette: [
            colorScheme.secondary,
            const Color(0xFF3B82F6),
            const Color(0xFFF59E0B),
            const Color(0xFF10B981),
            const Color(0xFF8B5CF6),
          ],
          trackColor: colorScheme.secondary.withValues(alpha: 0.09),
          borderColor: colorScheme.surface.withValues(alpha: 0.65),
          useGradient: false,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleFunnelVisuals(
          palette: [
            colorScheme.tertiary,
            const Color(0xFF06B6D4),
            const Color(0xFF22C55E),
            const Color(0xFFF97316),
            const Color(0xFFEC4899),
          ],
          trackColor: colorScheme.tertiary.withValues(alpha: 0.08),
          borderColor: colorScheme.surface.withValues(alpha: 0.5),
          useGradient: true,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleFunnelVisuals(
          palette: [
            colorScheme.primary,
            colorScheme.secondary,
            colorScheme.tertiary,
            const Color(0xFF14B8A6),
            const Color(0xFFF59E0B),
          ],
          trackColor: colorScheme.primary.withValues(alpha: 0.07),
          borderColor: colorScheme.surface.withValues(alpha: 0.6),
          useGradient: true,
        );
    }
  }
}

class _DefaultFunnelTooltip extends StatelessWidget {
  final Color color;
  final String title;
  final List<_FunnelTooltipRow> rows;

  const _DefaultFunnelTooltip({
    required this.color,
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: TextStyle(
                          color: colorScheme.onInverseSurface.withValues(
                            alpha: 0.72,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      row.value,
                      style: TextStyle(
                        color: colorScheme.onInverseSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FunnelTooltipRow {
  final String label;
  final String value;

  const _FunnelTooltipRow({required this.label, required this.value});
}
