import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleWordCloudValueFormatter = String Function(double value);
typedef SimpleWordCloudTapCallback =
    void Function(SimpleWordCloudData data, int index);
typedef SimpleWordCloudTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleWordCloudData data,
      int index,
      String formattedValue,
    );

enum SimpleWordCloudShape { cloud, oval, rectangle }

class SimpleWordCloudData {
  final String text;
  final double value;
  final String? group;
  final Color? color;

  const SimpleWordCloudData({
    required this.text,
    required this.value,
    this.group,
    this.color,
  });
}

/// A polished word cloud for survey themes, feedback tags, search terms,
/// learning topics, content analytics, and qualitative signal summaries.
class SimpleWordCloudChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(16, 18, 16, 16);

  final List<SimpleWordCloudData> words;
  final SimpleBarChartStyle style;
  final SimpleWordCloudShape shape;
  final double height;
  final EdgeInsets padding;
  final Color? wordColor;
  final Color? activeColor;
  final Color? labelColor;
  final TextStyle? textStyle;
  final TextStyle? valueStyle;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveWord;
  final bool allowRotation;
  final int maxWords;
  final int layoutSeed;
  final double minFontSize;
  final double maxFontSize;
  final double rotationRatio;
  final double wordGap;
  final SimpleWordCloudValueFormatter? valueFormatter;
  final SimpleWordCloudTapCallback? onWordTap;
  final SimpleWordCloudTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleWordCloudChart({
    super.key,
    required this.words,
    this.style = SimpleBarChartStyle.elegant,
    this.shape = SimpleWordCloudShape.cloud,
    this.height = 260,
    this.padding = _defaultPadding,
    this.wordColor,
    this.activeColor,
    this.labelColor,
    this.textStyle,
    this.valueStyle,
    this.showValues = false,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveWord = true,
    this.allowRotation = true,
    this.maxWords = 32,
    this.layoutSeed = 7,
    this.minFontSize = 12,
    this.maxFontSize = 44,
    this.rotationRatio = 0.16,
    this.wordGap = 6,
    this.valueFormatter,
    this.onWordTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(maxWords > 0),
       assert(minFontSize > 0),
       assert(maxFontSize >= minFontSize),
       assert(rotationRatio >= 0 && rotationRatio <= 1),
       assert(wordGap >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleWordCloudVisuals.resolve(style, colorScheme);
    final visibleWords = _resolveWords(words, maxWords);
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleWords.isEmpty) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Word cloud, no data.',
            accessibility: ChartAccessibilityOptions(
              semanticLabel: semanticLabel,
              excludeFromSemantics: excludeFromSemantics,
            ),
            child: const SizedBox.shrink(),
          );
        }

        final resolvedTextStyle =
            textStyle ??
            theme.textTheme.bodyMedium?.copyWith(
              color: wordColor ?? visuals.wordColor,
              fontWeight: FontWeight.w800,
            ) ??
            TextStyle(
              color: wordColor ?? visuals.wordColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            );
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: labelColor ?? visuals.labelColor,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: labelColor ?? visuals.labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(visibleWords, formatter),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleWordCloudView(
            width: width,
            height: chartHeight,
            words: visibleWords,
            shape: shape,
            padding: padding,
            palette: visuals.palette,
            fallbackWordColor: wordColor ?? visuals.wordColor,
            activeColor: activeColor ?? visuals.activeColor,
            labelColor: labelColor ?? visuals.labelColor,
            textStyle: resolvedTextStyle,
            valueStyle: resolvedValueStyle,
            showValues: showValues,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveWord: showActiveWord,
            allowRotation: allowRotation,
            layoutSeed: layoutSeed,
            minFontSize: minFontSize,
            maxFontSize: maxFontSize,
            rotationRatio: rotationRatio,
            wordGap: wordGap,
            valueFormatter: formatter,
            onWordTap: onWordTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static List<SimpleWordCloudData> _resolveWords(
    List<SimpleWordCloudData> words,
    int maxWords,
  ) {
    final result = <SimpleWordCloudData>[];
    final seen = <String>{};
    for (final word in words) {
      final text = word.text.trim();
      if (text.isEmpty || !word.value.isFinite || word.value <= 0) {
        continue;
      }
      final key = text.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      result.add(
        SimpleWordCloudData(
          text: text,
          value: word.value,
          group: word.group?.trim(),
          color: word.color,
        ),
      );
    }
    result.sort((a, b) => b.value.compareTo(a.value));
    return result.take(maxWords).toList();
  }

  static String _defaultSemanticLabel(
    List<SimpleWordCloudData> words,
    SimpleWordCloudValueFormatter formatter,
  ) {
    final sample = words
        .take(7)
        .map((item) => '${item.text} ${formatter(item.value)}')
        .join(', ');
    final suffix = words.length > 7 ? ', and ${words.length - 7} more' : '';
    return 'Word cloud, ${words.length} words. $sample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleWordCloudView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleWordCloudData> words;
  final SimpleWordCloudShape shape;
  final EdgeInsets padding;
  final List<Color> palette;
  final Color fallbackWordColor;
  final Color activeColor;
  final Color labelColor;
  final TextStyle textStyle;
  final TextStyle valueStyle;
  final bool showValues;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveWord;
  final bool allowRotation;
  final int layoutSeed;
  final double minFontSize;
  final double maxFontSize;
  final double rotationRatio;
  final double wordGap;
  final SimpleWordCloudValueFormatter valueFormatter;
  final SimpleWordCloudTapCallback? onWordTap;
  final SimpleWordCloudTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleWordCloudView({
    required this.width,
    required this.height,
    required this.words,
    required this.shape,
    required this.padding,
    required this.palette,
    required this.fallbackWordColor,
    required this.activeColor,
    required this.labelColor,
    required this.textStyle,
    required this.valueStyle,
    required this.showValues,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveWord,
    required this.allowRotation,
    required this.layoutSeed,
    required this.minFontSize,
    required this.maxFontSize,
    required this.rotationRatio,
    required this.wordGap,
    required this.valueFormatter,
    required this.onWordTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleWordCloudView> createState() => _SimpleWordCloudViewState();
}

class _SimpleWordCloudViewState extends State<_SimpleWordCloudView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  _WordCloudSelection? _active;
  Offset _pointer = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _SimpleWordCloudView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.words != widget.words ||
        oldWidget.shape != widget.shape ||
        oldWidget.layoutSeed != widget.layoutSeed ||
        oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.animationCurve != widget.animationCurve) {
      _controller.duration = widget.animationDuration;
      _animation = CurvedAnimation(
        parent: _controller,
        curve: widget.animationCurve,
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final geometry = _WordCloudGeometry.resolve(
            size: Size(widget.width, widget.height),
            words: widget.words,
            shape: widget.shape,
            padding: widget.padding,
            palette: widget.palette,
            fallbackWordColor: widget.fallbackWordColor,
            textStyle: widget.textStyle,
            layoutSeed: widget.layoutSeed,
            minFontSize: widget.minFontSize,
            maxFontSize: widget.maxFontSize,
            allowRotation: widget.allowRotation,
            rotationRatio: widget.rotationRatio,
            wordGap: widget.wordGap,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onHover: (event) {
                    setState(() {
                      _active = _hitTest(event.localPosition, geometry);
                      _pointer = event.localPosition;
                    });
                  },
                  onExit: (_) => setState(() => _active = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final active = _hitTest(details.localPosition, geometry);
                      setState(() {
                        _active = active;
                        _pointer = details.localPosition;
                      });
                      if (active != null) {
                        widget.onWordTap?.call(
                          active.word.source,
                          active.index,
                        );
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _SimpleWordCloudPainter(
                            geometry: geometry,
                            activeSelection: _active,
                            activeColor: widget.activeColor,
                            labelColor: widget.labelColor,
                            valueStyle: widget.valueStyle,
                            showValues: widget.showValues,
                            showLegend: widget.showLegend,
                            showActiveWord: widget.showActiveWord,
                            valueFormatter: widget.valueFormatter,
                            progress: _animation.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _active != null)
                _buildTooltip(context, Size(widget.width, widget.height)),
            ],
          );
        },
      ),
    );
  }

  _WordCloudSelection? _hitTest(Offset position, _WordCloudGeometry geometry) {
    for (var i = geometry.words.length - 1; i >= 0; i--) {
      final word = geometry.words[i];
      if (word.hitRect.contains(position)) {
        return _WordCloudSelection(word, word.index);
      }
    }
    return null;
  }

  Widget _buildTooltip(BuildContext context, Size size) {
    final selection = _active!;
    final formatted = widget.valueFormatter(selection.word.source.value);
    final child =
        widget.tooltipBuilder?.call(
          context,
          selection.word.source,
          selection.index,
          formatted,
        ) ??
        _DefaultWordCloudTooltip(
          word: selection.word.source,
          formattedValue: formatted,
        );
    const tooltipWidth = 174.0;
    const tooltipHeight = 92.0;
    final maxLeft = math.max(8.0, size.width - tooltipWidth - 8);
    final maxTop = math.max(8.0, size.height - tooltipHeight - 8);
    final left = (_pointer.dx + 12).clamp(8.0, maxLeft).toDouble();
    final top = (_pointer.dy - tooltipHeight - 8).clamp(8.0, maxTop).toDouble();
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(child: child),
    );
  }
}

class _SimpleWordCloudPainter extends CustomPainter {
  final _WordCloudGeometry geometry;
  final _WordCloudSelection? activeSelection;
  final Color activeColor;
  final Color labelColor;
  final TextStyle valueStyle;
  final bool showValues;
  final bool showLegend;
  final bool showActiveWord;
  final SimpleWordCloudValueFormatter valueFormatter;
  final double progress;

  const _SimpleWordCloudPainter({
    required this.geometry,
    required this.activeSelection,
    required this.activeColor,
    required this.labelColor,
    required this.valueStyle,
    required this.showValues,
    required this.showLegend,
    required this.showActiveWord,
    required this.valueFormatter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.words.isEmpty) {
      return;
    }
    if (showActiveWord && activeSelection != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          activeSelection!.word.hitRect.inflate(4),
          const Radius.circular(8),
        ),
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill,
      );
    }
    for (final word in geometry.words) {
      _drawWord(canvas, word);
    }
    if (showLegend) {
      _drawLegend(canvas);
    }
  }

  void _drawWord(Canvas canvas, _WordCloudLayout word) {
    final active = activeSelection?.word == word;
    final selected = activeSelection != null;
    final opacity = selected ? (active ? 1.0 : 0.38) : 1.0;
    final scale = 0.72 + 0.28 * progress;
    final painter = TextPainter(
      text: TextSpan(
        text: word.source.text,
        style: word.style.copyWith(
          color: word.color.withValues(alpha: opacity * progress),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    canvas.save();
    canvas.translate(word.center.dx, word.center.dy);
    canvas.scale(scale);
    if (word.rotated) {
      canvas.rotate(-math.pi / 2);
    }
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();

    if (showValues && !word.rotated && word.fontSize >= 18) {
      final value = valueFormatter(word.source.value);
      final valuePainter = TextPainter(
        text: TextSpan(
          text: value,
          style: valueStyle.copyWith(
            color: labelColor.withValues(alpha: opacity * progress * 0.82),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: word.hitRect.width);
      valuePainter.paint(
        canvas,
        Offset(
          word.center.dx - valuePainter.width / 2,
          word.center.dy + word.hitRect.height / 2 + 2,
        ),
      );
    }
  }

  void _drawLegend(Canvas canvas) {
    if (geometry.groupColors.isEmpty) {
      return;
    }
    final entries = geometry.groupColors.entries.take(4).toList();
    var dx = geometry.plotRect.left;
    final y = geometry.plotRect.top - 15;
    for (final entry in entries) {
      canvas.drawCircle(
        Offset(dx + 5, y + 5),
        4,
        Paint()
          ..color = entry.value.withValues(alpha: progress)
          ..style = PaintingStyle.fill,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: valueStyle.copyWith(
            color: labelColor.withValues(alpha: progress),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: 82);
      painter.paint(canvas, Offset(dx + 13, y - 2));
      dx += math.min(105, painter.width + 28);
      if (dx > geometry.plotRect.right - 76) {
        break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleWordCloudPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.activeSelection != activeSelection ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveWord != showActiveWord ||
        oldDelegate.progress != progress;
  }
}

class _WordCloudGeometry {
  final Rect plotRect;
  final List<_WordCloudLayout> words;
  final Map<String, Color> groupColors;

  const _WordCloudGeometry({
    required this.plotRect,
    required this.words,
    required this.groupColors,
  });

  factory _WordCloudGeometry.resolve({
    required Size size,
    required List<SimpleWordCloudData> words,
    required SimpleWordCloudShape shape,
    required EdgeInsets padding,
    required List<Color> palette,
    required Color fallbackWordColor,
    required TextStyle textStyle,
    required int layoutSeed,
    required double minFontSize,
    required double maxFontSize,
    required bool allowRotation,
    required double rotationRatio,
    required double wordGap,
  }) {
    final plotRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      math.max(1, size.width - padding.horizontal),
      math.max(1, size.height - padding.vertical),
    );
    final groupColors = _resolveGroupColors(words, palette);
    final maxValue = words.map((word) => word.value).fold<double>(0, math.max);
    final minValue = words
        .map((word) => word.value)
        .fold<double>(double.infinity, math.min);
    final placed = <_WordCloudLayout>[];
    final occupied = <Rect>[];

    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      final normalized = maxValue <= minValue
          ? 0.72
          : ((word.value - minValue) / (maxValue - minValue))
                .clamp(0.0, 1.0)
                .toDouble();
      var fontSize =
          minFontSize + (maxFontSize - minFontSize) * math.sqrt(normalized);
      final rng = math.Random(layoutSeed + i * 7919);
      final rotated =
          allowRotation && i > 1 && rng.nextDouble() < rotationRatio;
      var style = textStyle.copyWith(
        fontSize: fontSize,
        fontWeight: normalized > 0.72
            ? FontWeight.w900
            : normalized > 0.36
            ? FontWeight.w800
            : FontWeight.w700,
      );
      var metrics = _measure(word.text, style, rotated);
      if (metrics.width > plotRect.width * 0.86) {
        fontSize *= (plotRect.width * 0.86 / metrics.width).clamp(0.62, 1.0);
        style = style.copyWith(fontSize: fontSize);
        metrics = _measure(word.text, style, rotated);
      }
      final color =
          word.color ??
          (word.group == null || word.group!.isEmpty
              ? palette[i % palette.length]
              : groupColors[word.group!] ?? fallbackWordColor);
      final layout = _placeWord(
        index: i,
        source: word,
        style: style,
        fontSize: fontSize,
        color: color,
        metrics: metrics,
        rotated: rotated,
        plotRect: plotRect,
        occupied: occupied,
        shape: shape,
        seed: layoutSeed,
        gap: wordGap,
      );
      if (layout != null) {
        occupied.add(layout.hitRect.inflate(wordGap));
        placed.add(layout);
      }
    }

    return _WordCloudGeometry(
      plotRect: plotRect,
      words: placed,
      groupColors: groupColors,
    );
  }

  static Map<String, Color> _resolveGroupColors(
    List<SimpleWordCloudData> words,
    List<Color> palette,
  ) {
    final result = <String, Color>{};
    for (final word in words) {
      final group = word.group;
      if (group == null || group.isEmpty || result.containsKey(group)) {
        continue;
      }
      result[group] = palette[result.length % palette.length];
    }
    return result;
  }

  static _WordMetrics _measure(String text, TextStyle style, bool rotated) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return _WordMetrics(
      width: rotated ? painter.height : painter.width,
      height: rotated ? painter.width : painter.height,
    );
  }

  static _WordCloudLayout? _placeWord({
    required int index,
    required SimpleWordCloudData source,
    required TextStyle style,
    required double fontSize,
    required Color color,
    required _WordMetrics metrics,
    required bool rotated,
    required Rect plotRect,
    required List<Rect> occupied,
    required SimpleWordCloudShape shape,
    required int seed,
    required double gap,
  }) {
    final center = plotRect.center;
    final width = metrics.width + gap;
    final height = metrics.height + gap;
    final phase = (seed % 360) * math.pi / 180;
    final maxSteps = index == 0 ? 1 : 720;
    for (var step = 0; step < maxSteps; step++) {
      final angle = phase + step * 0.42;
      final radius = index == 0 ? 0.0 : math.sqrt(step) * 5.4;
      final candidateCenter = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius * 0.78,
      );
      final rect = Rect.fromCenter(
        center: candidateCenter,
        width: width,
        height: height,
      );
      if (!plotRect.contains(rect.topLeft) ||
          !plotRect.contains(rect.bottomRight) ||
          !_insideShape(rect, plotRect, shape)) {
        continue;
      }
      if (occupied.any((item) => item.overlaps(rect))) {
        continue;
      }
      return _WordCloudLayout(
        index: index,
        source: source,
        center: candidateCenter,
        hitRect: rect,
        fontSize: fontSize,
        rotated: rotated,
        color: color,
        style: style,
      );
    }
    return null;
  }

  static bool _insideShape(
    Rect rect,
    Rect plotRect,
    SimpleWordCloudShape shape,
  ) {
    if (shape == SimpleWordCloudShape.rectangle) {
      return true;
    }
    final center = plotRect.center;
    final rx = plotRect.width / 2;
    final ry = plotRect.height / 2;
    final points = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    for (final point in points) {
      final dx = (point.dx - center.dx) / rx;
      final dy = (point.dy - center.dy) / ry;
      final distance = dx * dx + dy * dy;
      if (shape == SimpleWordCloudShape.oval && distance > 1.0) {
        return false;
      }
      if (shape == SimpleWordCloudShape.cloud) {
        final softness =
            1.0 + math.sin((point.dx - plotRect.left) * 0.035) * 0.08;
        if (distance > softness) {
          return false;
        }
      }
    }
    return true;
  }
}

class _WordMetrics {
  final double width;
  final double height;

  const _WordMetrics({required this.width, required this.height});
}

class _WordCloudLayout {
  final int index;
  final SimpleWordCloudData source;
  final Offset center;
  final Rect hitRect;
  final double fontSize;
  final bool rotated;
  final Color color;
  final TextStyle style;

  const _WordCloudLayout({
    required this.index,
    required this.source,
    required this.center,
    required this.hitRect,
    required this.fontSize,
    required this.rotated,
    required this.color,
    required this.style,
  });
}

class _WordCloudSelection {
  final _WordCloudLayout word;
  final int index;

  const _WordCloudSelection(this.word, this.index);
}

class _SimpleWordCloudVisuals {
  final Color wordColor;
  final Color activeColor;
  final Color labelColor;
  final List<Color> palette;

  const _SimpleWordCloudVisuals({
    required this.wordColor,
    required this.activeColor,
    required this.labelColor,
    required this.palette,
  });

  factory _SimpleWordCloudVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleWordCloudVisuals(
          wordColor: colorScheme.primary,
          activeColor: colorScheme.primary.withValues(alpha: 0.1),
          labelColor: colorScheme.onSurfaceVariant,
          palette: const [
            Color(0xFF2563EB),
            Color(0xFF10B981),
            Color(0xFFF59E0B),
            Color(0xFFEF4444),
            Color(0xFF8B5CF6),
          ],
        );
      case SimpleBarChartStyle.professional:
        return _SimpleWordCloudVisuals(
          wordColor: const Color(0xFF1E40AF),
          activeColor: const Color(0xFF334155).withValues(alpha: 0.08),
          labelColor: const Color(0xFF475569),
          palette: const [
            Color(0xFF1D4ED8),
            Color(0xFF0F766E),
            Color(0xFF7C2D12),
            Color(0xFF6D28D9),
            Color(0xFFBE123C),
          ],
        );
      case SimpleBarChartStyle.education:
        return _SimpleWordCloudVisuals(
          wordColor: const Color(0xFF2563EB),
          activeColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
          labelColor: const Color(0xFF475569),
          palette: const [
            Color(0xFF2563EB),
            Color(0xFFF97316),
            Color(0xFF16A34A),
            Color(0xFFDB2777),
            Color(0xFF9333EA),
          ],
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleWordCloudVisuals(
          wordColor: const Color(0xFF14B8A6),
          activeColor: const Color(0xFF8B5CF6).withValues(alpha: 0.11),
          labelColor: colorScheme.onSurfaceVariant,
          palette: const [
            Color(0xFF14B8A6),
            Color(0xFFF43F5E),
            Color(0xFF8B5CF6),
            Color(0xFFF59E0B),
            Color(0xFF06B6D4),
          ],
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleWordCloudVisuals(
          wordColor: colorScheme.secondary,
          activeColor: colorScheme.secondary.withValues(alpha: 0.1),
          labelColor: colorScheme.onSurfaceVariant,
          palette: const [
            Color(0xFF0F766E),
            Color(0xFF7C3AED),
            Color(0xFF2563EB),
            Color(0xFFE11D48),
            Color(0xFFCA8A04),
          ],
        );
    }
  }
}

class _DefaultWordCloudTooltip extends StatelessWidget {
  final SimpleWordCloudData word;
  final String formattedValue;

  const _DefaultWordCloudTooltip({
    required this.word,
    required this.formattedValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 174,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style:
              theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onInverseSurface,
                fontWeight: FontWeight.w600,
              ) ??
              TextStyle(
                color: colorScheme.onInverseSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                word.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (word.group != null && word.group!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(word.group!, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 7),
              Row(
                children: [
                  const Expanded(child: Text('Value')),
                  Text(
                    formattedValue,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
