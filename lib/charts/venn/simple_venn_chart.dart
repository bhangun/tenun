import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/chart_api_options.dart';
import '../../core/chart_api_surface.dart';
import '../bar/simple_bar_chart.dart';

typedef SimpleVennValueFormatter = String Function(double value);
typedef SimpleVennSetTapCallback = void Function(SimpleVennSet set);
typedef SimpleVennIntersectionTapCallback =
    void Function(SimpleVennIntersection intersection);
typedef SimpleVennTooltipBuilder =
    Widget Function(
      BuildContext context,
      SimpleVennSet? set,
      SimpleVennIntersection? intersection,
      String title,
      String formattedValue,
    );

class SimpleVennSet {
  final String id;
  final String label;
  final double value;
  final Color? color;

  const SimpleVennSet({
    required this.id,
    required this.label,
    required this.value,
    this.color,
  });
}

class SimpleVennIntersection {
  final List<String> setIds;
  final double value;
  final String? label;
  final Color? color;

  const SimpleVennIntersection({
    required this.setIds,
    required this.value,
    this.label,
    this.color,
  });
}

/// A simple two- or three-set Venn chart for audience overlap, feature
/// adoption, skills coverage, product bundles, and topic intersections.
class SimpleVennChart extends StatelessWidget {
  static const EdgeInsets _defaultPadding = EdgeInsets.fromLTRB(22, 22, 22, 22);

  final List<SimpleVennSet> sets;
  final List<SimpleVennIntersection> intersections;
  final SimpleBarChartStyle style;
  final double height;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color? setColor;
  final Color? intersectionColor;
  final Color? activeColor;
  final Color? borderColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showIntersectionLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveRegion;
  final double fillOpacity;
  final double borderWidth;
  final SimpleVennValueFormatter? valueFormatter;
  final SimpleVennSetTapCallback? onSetTap;
  final SimpleVennIntersectionTapCallback? onIntersectionTap;
  final SimpleVennTooltipBuilder? tooltipBuilder;
  final WidgetBuilder? emptyBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Duration animationDuration;
  final Curve animationCurve;

  const SimpleVennChart({
    super.key,
    required this.sets,
    this.intersections = const [],
    this.style = SimpleBarChartStyle.elegant,
    this.height = 260,
    this.padding = _defaultPadding,
    this.palette,
    this.setColor,
    this.intersectionColor,
    this.activeColor,
    this.borderColor,
    this.labelStyle,
    this.valueStyle,
    this.showLabels = true,
    this.showValues = true,
    this.showIntersectionLabels = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showActiveRegion = true,
    this.fillOpacity = 0.24,
    this.borderWidth = 2,
    this.valueFormatter,
    this.onSetTap,
    this.onIntersectionTap,
    this.tooltipBuilder,
    this.emptyBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.animationDuration = const Duration(milliseconds: 700),
    this.animationCurve = Curves.easeOutCubic,
  }) : assert(height > 0),
       assert(fillOpacity >= 0 && fillOpacity <= 1),
       assert(borderWidth >= 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visuals = _SimpleVennVisuals.resolve(style, colorScheme);
    final visibleSets = sets
        .where(
          (set) =>
              set.id.trim().isNotEmpty &&
              set.label.trim().isNotEmpty &&
              set.value.isFinite &&
              set.value > 0,
        )
        .take(3)
        .toList();
    final visibleIds = visibleSets.map((set) => set.id).toSet();
    final visibleIntersections = intersections.where((intersection) {
      final ids = _normalizedIds(intersection.setIds);
      return ids.length >= 2 &&
          ids.length <= visibleSets.length &&
          ids.every(visibleIds.contains) &&
          intersection.value.isFinite &&
          intersection.value > 0;
    }).toList();
    final formatter = valueFormatter ?? _defaultValueFormatter;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 420.0;
        final chartHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : height;

        if (visibleSets.length < 2) {
          return ChartApiSurface(
            isEmpty: true,
            width: width,
            height: chartHeight,
            emptyBuilder: emptyBuilder,
            emptySemanticLabel: 'Venn chart, no data.',
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
              fontWeight: FontWeight.w800,
            ) ??
            TextStyle(
              color: colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            );
        final resolvedValueStyle =
            valueStyle ??
            theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            );

        return ChartApiSurface(
          semanticLabel: _defaultSemanticLabel(
            visibleSets,
            visibleIntersections,
            formatter,
          ),
          accessibility: ChartAccessibilityOptions(
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
          ),
          child: _SimpleVennChartView(
            width: width,
            height: chartHeight,
            sets: visibleSets,
            intersections: visibleIntersections,
            padding: padding,
            palette: palette,
            setColor: setColor ?? visuals.setColor,
            intersectionColor: intersectionColor ?? visuals.intersectionColor,
            activeColor: activeColor ?? visuals.activeColor,
            borderColor: borderColor ?? visuals.borderColor,
            labelStyle: resolvedLabelStyle,
            valueStyle: resolvedValueStyle,
            showLabels: showLabels,
            showValues: showValues,
            showIntersectionLabels: showIntersectionLabels,
            showLegend: showLegend,
            showTooltip: showTooltip,
            showActiveRegion: showActiveRegion,
            fillOpacity: fillOpacity,
            borderWidth: borderWidth,
            valueFormatter: formatter,
            onSetTap: onSetTap,
            onIntersectionTap: onIntersectionTap,
            tooltipBuilder: tooltipBuilder,
            animationDuration: animationDuration,
            animationCurve: animationCurve,
          ),
        );
      },
    );
  }

  static List<String> _normalizedIds(List<String> ids) {
    final seen = <String>{};
    final result = <String>[];
    for (final id in ids) {
      final value = id.trim();
      if (value.isNotEmpty && seen.add(value)) {
        result.add(value);
      }
    }
    result.sort();
    return result;
  }

  static String _intersectionKey(List<String> ids) =>
      _normalizedIds(ids).join('|');

  static String _defaultSemanticLabel(
    List<SimpleVennSet> sets,
    List<SimpleVennIntersection> intersections,
    SimpleVennValueFormatter formatter,
  ) {
    final setSample = sets
        .map((set) => '${set.label} ${formatter(set.value)}')
        .join(', ');
    final intersectionSample = intersections.isEmpty
        ? ''
        : '. Overlaps: ${intersections.take(4).map((intersection) {
            final title = intersection.label ?? _normalizedIds(intersection.setIds).join(' and ');
            return '$title ${formatter(intersection.value)}';
          }).join(', ')}';
    final suffix = intersections.length > 4
        ? ', and ${intersections.length - 4} more'
        : '';
    return 'Venn chart, ${sets.length} sets and ${intersections.length} '
        'intersections. $setSample$intersectionSample$suffix.';
  }

  static String _defaultValueFormatter(double value) {
    if (value >= 1000) {
      final precision = value >= 10000 ? 0 : 1;
      return '${(value / 1000).toStringAsFixed(precision)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}

class _SimpleVennChartView extends StatefulWidget {
  final double width;
  final double height;
  final List<SimpleVennSet> sets;
  final List<SimpleVennIntersection> intersections;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color setColor;
  final Color intersectionColor;
  final Color activeColor;
  final Color borderColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showIntersectionLabels;
  final bool showLegend;
  final bool showTooltip;
  final bool showActiveRegion;
  final double fillOpacity;
  final double borderWidth;
  final SimpleVennValueFormatter valueFormatter;
  final SimpleVennSetTapCallback? onSetTap;
  final SimpleVennIntersectionTapCallback? onIntersectionTap;
  final SimpleVennTooltipBuilder? tooltipBuilder;
  final Duration animationDuration;
  final Curve animationCurve;

  const _SimpleVennChartView({
    required this.width,
    required this.height,
    required this.sets,
    required this.intersections,
    required this.padding,
    required this.palette,
    required this.setColor,
    required this.intersectionColor,
    required this.activeColor,
    required this.borderColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showIntersectionLabels,
    required this.showLegend,
    required this.showTooltip,
    required this.showActiveRegion,
    required this.fillOpacity,
    required this.borderWidth,
    required this.valueFormatter,
    required this.onSetTap,
    required this.onIntersectionTap,
    required this.tooltipBuilder,
    required this.animationDuration,
    required this.animationCurve,
  });

  @override
  State<_SimpleVennChartView> createState() => _SimpleVennChartViewState();
}

class _SimpleVennChartViewState extends State<_SimpleVennChartView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _VennHit? _activeHit;

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
  void didUpdateWidget(covariant _SimpleVennChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sets != widget.sets ||
        oldWidget.intersections != widget.intersections ||
        oldWidget.animationDuration != widget.animationDuration ||
        oldWidget.animationCurve != widget.animationCurve) {
      _controller.duration = widget.animationDuration;
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
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: MouseRegion(
                  onExit: (_) => _setActive(null),
                  onHover: (event) {
                    if (widget.showActiveRegion ||
                        widget.showTooltip ||
                        widget.onSetTap != null ||
                        widget.onIntersectionTap != null) {
                      _setActive(_hitTest(event.localPosition));
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final hit = _hitTest(details.localPosition);
                      _setActive(hit);
                      if (hit?.set != null) {
                        widget.onSetTap?.call(hit!.set!.set);
                      } else if (hit?.intersection != null) {
                        widget.onIntersectionTap?.call(
                          hit!.intersection!.intersection,
                        );
                      }
                    },
                    child: CustomPaint(
                      painter: _SimpleVennPainter(
                        sets: widget.sets,
                        intersections: widget.intersections,
                        padding: widget.padding,
                        palette: widget.palette,
                        setColor: widget.setColor,
                        intersectionColor: widget.intersectionColor,
                        activeColor: widget.activeColor,
                        borderColor: widget.borderColor,
                        labelStyle: widget.labelStyle,
                        valueStyle: widget.valueStyle,
                        showLabels: widget.showLabels,
                        showValues: widget.showValues,
                        showIntersectionLabels: widget.showIntersectionLabels,
                        showLegend: widget.showLegend,
                        showActiveRegion: widget.showActiveRegion,
                        fillOpacity: widget.fillOpacity,
                        borderWidth: widget.borderWidth,
                        valueFormatter: widget.valueFormatter,
                        activeHit: _activeHit,
                        progress: _animation.value,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showTooltip && _activeHit != null)
                _buildTooltip(context, _activeHit!),
            ],
          );
        },
      ),
    );
  }

  void _setActive(_VennHit? hit) {
    if (_activeHit?.set?.index == hit?.set?.index &&
        _activeHit?.intersection?.key == hit?.intersection?.key) {
      return;
    }
    setState(() => _activeHit = hit);
  }

  _VennHit? _hitTest(Offset position) {
    final geometry = _VennGeometry.resolve(
      sets: widget.sets,
      intersections: widget.intersections,
      size: Size(widget.width, widget.height),
      padding: widget.padding,
    );

    final contained = <_VennSetLayout>[];
    for (final set in geometry.sets) {
      if ((position - set.center).distance <= geometry.radius) {
        contained.add(set);
      }
    }
    if (contained.isEmpty) {
      return null;
    }

    final containedIds = contained.map((set) => set.set.id).toList();
    final exactKey = SimpleVennChart._intersectionKey(containedIds);
    final exact = geometry.intersections[exactKey];
    if (exact != null) {
      return _VennHit(intersection: exact);
    }

    for (var length = containedIds.length - 1; length >= 2; length--) {
      for (final combination in _combinations(containedIds, length)) {
        final hit = geometry
            .intersections[SimpleVennChart._intersectionKey(combination)];
        if (hit != null) {
          return _VennHit(intersection: hit);
        }
      }
    }
    return _VennHit(set: contained.first);
  }

  List<List<String>> _combinations(List<String> values, int length) {
    final result = <List<String>>[];
    void walk(int start, List<String> current) {
      if (current.length == length) {
        result.add(List<String>.of(current));
        return;
      }
      for (var index = start; index < values.length; index++) {
        current.add(values[index]);
        walk(index + 1, current);
        current.removeLast();
      }
    }

    walk(0, []);
    return result;
  }

  Widget _buildTooltip(BuildContext context, _VennHit hit) {
    final set = hit.set;
    final intersection = hit.intersection;
    final title =
        set?.set.label ??
        intersection?.intersection.label ??
        intersection?.sets.map((item) => item.set.label).join(' & ') ??
        '';
    final value = set?.set.value ?? intersection?.intersection.value ?? 0;
    final formattedValue = widget.valueFormatter(value);
    final tooltip =
        widget.tooltipBuilder?.call(
          context,
          set?.set,
          intersection?.intersection,
          title,
          formattedValue,
        ) ??
        _DefaultVennTooltip(
          title: title,
          rows: [
            if (intersection != null)
              _TooltipRow(
                'Sets',
                intersection.sets.map((item) => item.set.label).join(', '),
              ),
            _TooltipRow(set != null ? 'Total' : 'Overlap', formattedValue),
          ],
        );
    final anchor = set?.labelAnchor ?? intersection?.center ?? Offset.zero;
    final left = (anchor.dx + 12).clamp(8.0, widget.width - 210);
    final top = (anchor.dy - 46).clamp(8.0, widget.height - 112);
    return Positioned(left: left, top: top, child: tooltip);
  }
}

class _SimpleVennPainter extends CustomPainter {
  final List<SimpleVennSet> sets;
  final List<SimpleVennIntersection> intersections;
  final EdgeInsets padding;
  final List<Color>? palette;
  final Color setColor;
  final Color intersectionColor;
  final Color activeColor;
  final Color borderColor;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool showLabels;
  final bool showValues;
  final bool showIntersectionLabels;
  final bool showLegend;
  final bool showActiveRegion;
  final double fillOpacity;
  final double borderWidth;
  final SimpleVennValueFormatter valueFormatter;
  final _VennHit? activeHit;
  final double progress;

  const _SimpleVennPainter({
    required this.sets,
    required this.intersections,
    required this.padding,
    required this.palette,
    required this.setColor,
    required this.intersectionColor,
    required this.activeColor,
    required this.borderColor,
    required this.labelStyle,
    required this.valueStyle,
    required this.showLabels,
    required this.showValues,
    required this.showIntersectionLabels,
    required this.showLegend,
    required this.showActiveRegion,
    required this.fillOpacity,
    required this.borderWidth,
    required this.valueFormatter,
    required this.activeHit,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = _VennGeometry.resolve(
      sets: sets,
      intersections: intersections,
      size: size,
      padding: padding,
    );
    if (geometry.sets.isEmpty || geometry.radius <= 0) {
      return;
    }

    for (final set in geometry.sets) {
      _drawSet(canvas, geometry, set);
    }
    if (showActiveRegion && activeHit?.intersection != null) {
      _drawActiveIntersection(canvas, activeHit!.intersection!);
    }
    if (showIntersectionLabels) {
      for (final intersection in geometry.intersections.values) {
        _drawIntersectionLabel(canvas, geometry, intersection);
      }
    }
    if (showLabels) {
      for (final set in geometry.sets) {
        _drawSetLabel(canvas, geometry, set);
      }
    }
    if (showLegend) {
      _drawLegend(canvas, geometry);
    }
  }

  void _drawSet(Canvas canvas, _VennGeometry geometry, _VennSetLayout set) {
    final active = showActiveRegion && activeHit?.set?.index == set.index;
    final color = active ? activeColor : _colorFor(set.index);
    final radius = geometry.radius * progress;
    canvas.drawCircle(
      set.center,
      radius,
      Paint()
        ..color = color.withValues(alpha: fillOpacity)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      set.center,
      radius,
      Paint()
        ..color = (active ? activeColor : borderColor).withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? math.max(2, borderWidth + 1) : borderWidth,
    );
  }

  void _drawActiveIntersection(
    Canvas canvas,
    _VennIntersectionLayout intersection,
  ) {
    canvas.drawCircle(
      intersection.center,
      math.max(18, 26 * progress),
      Paint()
        ..color = activeColor.withValues(alpha: 0.14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      intersection.center,
      math.max(10, 16 * progress),
      Paint()
        ..color = activeColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawSetLabel(
    Canvas canvas,
    _VennGeometry geometry,
    _VennSetLayout set,
  ) {
    final color = _colorFor(set.index);
    final width = math.min(112.0, math.max(56.0, geometry.plot.width / 3));
    _drawText(
      canvas,
      set.set.label,
      Rect.fromCenter(center: set.labelAnchor, width: width, height: 16),
      labelStyle.copyWith(color: color),
      align: TextAlign.center,
    );
    if (showValues) {
      _drawText(
        canvas,
        valueFormatter(set.set.value),
        Rect.fromCenter(
          center: set.labelAnchor + const Offset(0, 15),
          width: width,
          height: 14,
        ),
        valueStyle.copyWith(color: color.withValues(alpha: 0.9)),
        align: TextAlign.center,
      );
    }
  }

  void _drawIntersectionLabel(
    Canvas canvas,
    _VennGeometry geometry,
    _VennIntersectionLayout intersection,
  ) {
    if (geometry.plot.width < 132) {
      return;
    }
    final color = intersection.intersection.color ?? intersectionColor;
    final title = intersection.intersection.label;
    final width = math.min(86.0, math.max(44.0, geometry.plot.width / 3.5));
    if (title != null && showLabels) {
      _drawText(
        canvas,
        title,
        Rect.fromCenter(
          center: intersection.center - const Offset(0, 7),
          width: width,
          height: 14,
        ),
        valueStyle.copyWith(color: color, fontWeight: FontWeight.w800),
        align: TextAlign.center,
      );
    }
    if (showValues) {
      _drawText(
        canvas,
        valueFormatter(intersection.intersection.value),
        Rect.fromCenter(
          center: intersection.center + Offset(0, title == null ? 0 : 7),
          width: width,
          height: 14,
        ),
        valueStyle.copyWith(color: color, fontWeight: FontWeight.w800),
        align: TextAlign.center,
      );
    }
  }

  void _drawLegend(Canvas canvas, _VennGeometry geometry) {
    if (geometry.plot.width < 176 || geometry.sets.length < 2) {
      return;
    }
    var dx = geometry.plot.left + 4;
    final y = geometry.plot.bottom - 16;
    for (final set in geometry.sets) {
      final color = _colorFor(set.index);
      canvas.drawCircle(
        Offset(dx + 5, y + 8),
        5,
        Paint()
          ..color = color.withValues(alpha: fillOpacity + 0.22)
          ..style = PaintingStyle.fill,
      );
      final width = math.min(72.0, geometry.plot.right - dx - 12);
      if (width <= 26) {
        return;
      }
      _drawText(
        canvas,
        set.set.label,
        Rect.fromLTWH(dx + 14, y, width, 16),
        valueStyle.copyWith(color: color),
      );
      dx += width + 22;
      if (dx > geometry.plot.right - 32) {
        return;
      }
    }
  }

  Color _colorFor(int index) {
    if (sets[index].color != null) {
      return sets[index].color!;
    }
    final colors = palette;
    if (colors != null && colors.isNotEmpty) {
      return colors[index % colors.length];
    }
    return setColor;
  }

  void _drawText(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: rect.width);
    final dx = switch (align) {
      TextAlign.right => rect.right - painter.width,
      TextAlign.center => rect.left + (rect.width - painter.width) / 2,
      _ => rect.left,
    };
    final dy = rect.top + (rect.height - painter.height) / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _SimpleVennPainter oldDelegate) {
    return oldDelegate.sets != sets ||
        oldDelegate.intersections != intersections ||
        oldDelegate.padding != padding ||
        oldDelegate.palette != palette ||
        oldDelegate.setColor != setColor ||
        oldDelegate.intersectionColor != intersectionColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.valueStyle != valueStyle ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.showValues != showValues ||
        oldDelegate.showIntersectionLabels != showIntersectionLabels ||
        oldDelegate.showLegend != showLegend ||
        oldDelegate.showActiveRegion != showActiveRegion ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.activeHit != activeHit ||
        oldDelegate.progress != progress;
  }
}

class _VennGeometry {
  final Rect plot;
  final double radius;
  final List<_VennSetLayout> sets;
  final Map<String, _VennIntersectionLayout> intersections;

  const _VennGeometry({
    required this.plot,
    required this.radius,
    required this.sets,
    required this.intersections,
  });

  factory _VennGeometry.resolve({
    required List<SimpleVennSet> sets,
    required List<SimpleVennIntersection> intersections,
    required Size size,
    required EdgeInsets padding,
  }) {
    final plot = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    if (sets.length < 2 || plot.width <= 0 || plot.height <= 0) {
      return _VennGeometry(
        plot: plot,
        radius: 0,
        sets: const [],
        intersections: const {},
      );
    }

    final count = sets.length;
    final radius = math.max(
      18.0,
      math.min(plot.width, plot.height) * (count == 2 ? 0.34 : 0.31),
    );
    final centers = _centersFor(plot, radius, count);
    final setLayouts = <_VennSetLayout>[];
    for (var index = 0; index < count; index++) {
      setLayouts.add(
        _VennSetLayout(
          index: index,
          set: sets[index],
          center: centers[index],
          labelAnchor: _labelAnchor(plot, centers, radius, index),
        ),
      );
    }
    final byId = {for (final layout in setLayouts) layout.set.id: layout};
    final intersectionLayouts = <String, _VennIntersectionLayout>{};
    for (final intersection in intersections) {
      final ids = SimpleVennChart._normalizedIds(intersection.setIds);
      final members = ids
          .map((id) => byId[id])
          .whereType<_VennSetLayout>()
          .toList();
      if (members.length != ids.length || members.length < 2) {
        continue;
      }
      final center = _intersectionCenter(members, plot);
      final key = SimpleVennChart._intersectionKey(ids);
      intersectionLayouts[key] = _VennIntersectionLayout(
        key: key,
        intersection: intersection,
        sets: members,
        center: center,
      );
    }
    return _VennGeometry(
      plot: plot,
      radius: radius,
      sets: setLayouts,
      intersections: intersectionLayouts,
    );
  }

  static List<Offset> _centersFor(Rect plot, double radius, int count) {
    final center = plot.center;
    if (count == 2) {
      final dx = radius * 0.46;
      return [center - Offset(dx, 0), center + Offset(dx, 0)];
    }
    final dx = radius * 0.46;
    return [
      center + Offset(-dx, -radius * 0.22),
      center + Offset(dx, -radius * 0.22),
      center + Offset(0, radius * 0.52),
    ];
  }

  static Offset _labelAnchor(
    Rect plot,
    List<Offset> centers,
    double radius,
    int index,
  ) {
    if (centers.length == 2) {
      final direction = index == 0 ? -1.0 : 1.0;
      return Offset(
        (centers[index].dx + direction * radius * 0.46).clamp(
          plot.left + 36,
          plot.right - 36,
        ),
        centers[index].dy - radius * 0.08,
      );
    }
    final offsets = [
      Offset(-radius * 0.36, -radius * 0.26),
      Offset(radius * 0.36, -radius * 0.26),
      Offset(0, radius * 0.42),
    ];
    final anchor = centers[index] + offsets[index];
    return Offset(
      anchor.dx.clamp(plot.left + 36, plot.right - 36),
      anchor.dy.clamp(plot.top + 18, plot.bottom - 28),
    );
  }

  static Offset _intersectionCenter(List<_VennSetLayout> members, Rect plot) {
    var dx = 0.0;
    var dy = 0.0;
    for (final member in members) {
      dx += member.center.dx;
      dy += member.center.dy;
    }
    final center = Offset(dx / members.length, dy / members.length);
    return Offset(
      center.dx.clamp(plot.left + 26, plot.right - 26),
      center.dy.clamp(plot.top + 24, plot.bottom - 24),
    );
  }
}

class _VennSetLayout {
  final int index;
  final SimpleVennSet set;
  final Offset center;
  final Offset labelAnchor;

  const _VennSetLayout({
    required this.index,
    required this.set,
    required this.center,
    required this.labelAnchor,
  });
}

class _VennIntersectionLayout {
  final String key;
  final SimpleVennIntersection intersection;
  final List<_VennSetLayout> sets;
  final Offset center;

  const _VennIntersectionLayout({
    required this.key,
    required this.intersection,
    required this.sets,
    required this.center,
  });
}

class _VennHit {
  final _VennSetLayout? set;
  final _VennIntersectionLayout? intersection;

  const _VennHit({this.set, this.intersection});
}

class _SimpleVennVisuals {
  final Color setColor;
  final Color intersectionColor;
  final Color activeColor;
  final Color borderColor;

  const _SimpleVennVisuals({
    required this.setColor,
    required this.intersectionColor,
    required this.activeColor,
    required this.borderColor,
  });

  factory _SimpleVennVisuals.resolve(
    SimpleBarChartStyle style,
    ColorScheme colorScheme,
  ) {
    switch (style) {
      case SimpleBarChartStyle.modern:
        return _SimpleVennVisuals(
          setColor: colorScheme.primary,
          intersectionColor: colorScheme.tertiary,
          activeColor: colorScheme.tertiary,
          borderColor: colorScheme.primary,
        );
      case SimpleBarChartStyle.professional:
        return _SimpleVennVisuals(
          setColor: colorScheme.primary,
          intersectionColor: colorScheme.onSurface,
          activeColor: colorScheme.onSurface,
          borderColor: colorScheme.outline,
        );
      case SimpleBarChartStyle.education:
        return _SimpleVennVisuals(
          setColor: colorScheme.secondary,
          intersectionColor: colorScheme.primary,
          activeColor: colorScheme.primary,
          borderColor: colorScheme.secondary,
        );
      case SimpleBarChartStyle.trendy:
        return _SimpleVennVisuals(
          setColor: colorScheme.tertiary,
          intersectionColor: colorScheme.primary,
          activeColor: colorScheme.primary,
          borderColor: colorScheme.tertiary,
        );
      case SimpleBarChartStyle.elegant:
        return _SimpleVennVisuals(
          setColor: colorScheme.primary,
          intersectionColor: colorScheme.tertiary,
          activeColor: colorScheme.tertiary,
          borderColor: colorScheme.primary,
        );
    }
  }
}

class _DefaultVennTooltip extends StatelessWidget {
  final String title;
  final List<_TooltipRow> rows;

  const _DefaultVennTooltip({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: DefaultTextStyle(
            style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 48, child: Text(row.label)),
                        Flexible(
                          child: Text(
                            row.value,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TooltipRow {
  final String label;
  final String value;

  const _TooltipRow(this.label, this.value);
}
