import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

// Enhanced data model for treemap items
class TreemapItem {
  final String label;
  final double value;
  final Color? color;
  final List<TreemapItem>? children;
  final String? description;
  final IconData? icon;
  final Map<String, dynamic>? metadata;

  const TreemapItem({
    required this.label,
    required this.value,
    this.color,
    this.children,
    this.description,
    this.icon,
    this.metadata,
  });

  // Helper methods
  bool get hasChildren => children != null && children!.isNotEmpty;
  double get totalChildrenValue => hasChildren
      ? children!.fold<double>(0, (sum, child) => sum + child.value)
      : value;
}

// Rectangle representation for layout calculation
class TreemapRect {
  final Rect rect;
  final TreemapItem item;
  final int depth;
  final TreemapRect? parent;

  const TreemapRect({
    required this.rect,
    required this.item,
    required this.depth,
    this.parent,
  });
}

// Breadcrumb navigation
class TreemapBreadcrumb {
  final String label;
  final TreemapItem item;
  final int level;

  const TreemapBreadcrumb({
    required this.label,
    required this.item,
    required this.level,
  });
}

// Tooltip data
class TreemapTooltip {
  final TreemapItem item;
  final Offset position;
  final bool isVisible;

  const TreemapTooltip({
    required this.item,
    required this.position,
    required this.isVisible,
  });
}

// Legend item
class LegendItem {
  final String label;
  final Color color;
  final double value;
  final double percentage;

  const LegendItem({
    required this.label,
    required this.color,
    required this.value,
    required this.percentage,
  });
}

// Enhanced treemap chart widget
class AdvancedTreemapChart extends StatefulWidget {
  final List<TreemapItem> data;
  final EdgeInsets padding;
  final bool showLabels;
  final bool enableInteraction;
  final bool enableDrillDown;
  final bool showLegend;
  final bool showTooltip;
  final bool showBreadcrumbs;
  final bool enableZoom;
  final bool enableExport;
  final Function(TreemapItem)? onItemTap;
  final Function(TreemapItem)? onItemHover;
  final Function(List<TreemapItem>)? onDrillDown;
  final Function()? onZoomReset;
  final Duration animationDuration;
  final TreemapColorScheme colorScheme;
  final TreemapStyle style;

  const AdvancedTreemapChart({
    super.key,
    required this.data,
    this.padding = const EdgeInsets.all(8.0),
    this.showLabels = true,
    this.enableInteraction = true,
    this.enableDrillDown = true,
    this.showLegend = true,
    this.showTooltip = true,
    this.showBreadcrumbs = true,
    this.enableZoom = true,
    this.enableExport = false,
    this.onItemTap,
    this.onItemHover,
    this.onDrillDown,
    this.onZoomReset,
    this.animationDuration = const Duration(milliseconds: 800),
    this.colorScheme = TreemapColorScheme.vibrant,
    this.style = const TreemapStyle(),
  });

  @override
  State<AdvancedTreemapChart> createState() => _AdvancedTreemapChartState();
}

// Color schemes
enum TreemapColorScheme {
  vibrant,
  pastel,
  monochrome,
  business,
  nature,
  sunset,
}

// Style configuration
class TreemapStyle {
  final double borderRadius;
  final double borderWidth;
  final Color borderColor;
  final bool showShadows;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final Color shadowColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const TreemapStyle({
    this.borderRadius = 4.0,
    this.borderWidth = 1.0,
    this.borderColor = Colors.white,
    this.showShadows = true,
    this.shadowBlurRadius = 4.0,
    this.shadowOffset = const Offset(2, 2),
    this.shadowColor = const Color(0x1A000000),
    this.labelStyle,
    this.valueStyle,
  });
}

class _AdvancedTreemapChartState extends State<AdvancedTreemapChart>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _zoomController;
  late Animation<double> _animation;
  late Animation<double> _zoomAnimation;

  List<TreemapItem> _currentData = [];
  List<TreemapBreadcrumb> _breadcrumbs = [];
  TreemapItem? _hoveredItem;
  TreemapItem? _selectedItem;
  TreemapTooltip? _tooltip;
  List<TreemapRect> _currentRects = [];

  // Zoom and pan
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _isZoomed = false;

  // Search and filter
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentData = widget.data;

    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );

    _zoomAnimation = CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOutQuart,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with controls
        _buildHeader(),

        // Breadcrumbs
        if (widget.showBreadcrumbs && _breadcrumbs.isNotEmpty)
          _buildBreadcrumbs(),

        // Main content
        Expanded(
          child: Row(
            children: [
              // Treemap
              Expanded(flex: widget.showLegend ? 3 : 1, child: _buildTreemap()),

              // Legend
              if (widget.showLegend)
                SizedBox(width: 250, child: _buildLegend()),
            ],
          ),
        ),

        // Footer with statistics
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Title
          Expanded(
            child: Text(
              'Advanced Treemap Chart',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),

          // Search
          SizedBox(
            width: 200,
            height: 40,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          const SizedBox(width: 16),

          // Controls
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      children: [
        // Zoom reset
        if (widget.enableZoom && _isZoomed)
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: 'Reset Zoom',
            onPressed: _resetZoom,
          ),

        // Export
        if (widget.enableExport)
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Chart',
            onPressed: _exportChart,
          ),

        // Fullscreen
        IconButton(
          icon: const Icon(Icons.fullscreen),
          tooltip: 'Fullscreen',
          onPressed: _toggleFullscreen,
        ),
      ],
    );
  }

  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.home, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          ...List.generate(_breadcrumbs.length, (index) {
            final breadcrumb = _breadcrumbs[index];
            return Row(
              children: [
                if (index > 0) ...[
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                ],
                InkWell(
                  onTap: () => _navigateToBreadcrumb(index),
                  child: Text(
                    breadcrumb.label,
                    style: TextStyle(
                      color: index == _breadcrumbs.length - 1
                          ? Colors.blue.shade700
                          : Colors.blue.shade600,
                      fontWeight: index == _breadcrumbs.length - 1
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTreemap() {
    return Stack(
      children: [
        // Main treemap
        GestureDetector(
          onTapDown: widget.enableInteraction ? _handleTapDown : null,
          onScaleStart: widget.enableZoom ? _handleScaleStart : null,
          onScaleUpdate: widget.enableZoom ? _handleScaleUpdate : null,
          onScaleEnd: widget.enableZoom ? _handleScaleEnd : null,
          child: MouseRegion(
            onHover: widget.enableInteraction ? _handleHover : null,
            onExit: widget.enableInteraction ? _handleExit : null,
            child: AnimatedBuilder(
              animation: Listenable.merge([_animation, _zoomAnimation]),
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scaleByDouble(_scale, _scale, 1.0, 1.0)
                    ..translateByDouble(_offset.dx, _offset.dy, 0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: AdvancedTreemapPainter(
                        data: _getFilteredData(),
                        padding: widget.padding,
                        showLabels: widget.showLabels,
                        hoveredItem: _hoveredItem,
                        selectedItem: _selectedItem,
                        animationValue: _animation.value,
                        colorScheme: widget.colorScheme,
                        style: widget.style,
                        searchQuery: _searchQuery,
                        onRectsCalculated: (rects) => _currentRects = rects,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Tooltip
        if (widget.showTooltip && _tooltip != null && _tooltip!.isVisible)
          _buildTooltip(),

        // Loading indicator
        if (_animation.value < 1.0)
          Container(
            color: Colors.white.withValues(alpha: 0.7),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildTooltip() {
    if (_tooltip == null || !_tooltip!.isVisible) return const SizedBox();

    return Positioned(
      left: _tooltip!.position.dx + 10,
      top: _tooltip!.position.dy - 10,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and title
              Row(
                children: [
                  if (_tooltip!.item.icon != null) ...[
                    Icon(_tooltip!.item.icon, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _tooltip!.item.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Value
              Text(
                'Value: ${_formatValue(_tooltip!.item.value)}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),

              // Description
              if (_tooltip!.item.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  _tooltip!.item.description!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],

              // Metadata
              if (_tooltip!.item.metadata != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 4),
                ..._tooltip!.item.metadata!.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final legendItems = _generateLegendItems();

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              itemCount: legendItems.length,
              itemBuilder: (context, index) {
                final item = legendItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${_formatValue(item.value)} (${item.percentage.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final totalValue = _currentData.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );
    final itemCount = _currentData.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            'Items: $itemCount',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(width: 24),
          Text(
            'Total Value: ${_formatValue(totalValue)}',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const Spacer(),
          if (_searchQuery.isNotEmpty)
            Chip(
              label: Text('Search: $_searchQuery'),
              onDeleted: () {
                setState(() {
                  _searchQuery = '';
                });
              },
              deleteIcon: const Icon(Icons.close, size: 16),
            ),
        ],
      ),
    );
  }

  // Event handlers
  void _handleTapDown(TapDownDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    final tappedItem = _findItemAtPosition(localPosition);
    if (tappedItem != null) {
      setState(() {
        _selectedItem = tappedItem;
      });

      widget.onItemTap?.call(tappedItem);

      // Handle drill down
      if (widget.enableDrillDown && tappedItem.hasChildren) {
        _drillDown(tappedItem);
      }
    }
  }

  void _handleHover(PointerHoverEvent event) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(event.position);

    final hoveredItem = _findItemAtPosition(localPosition);
    if (hoveredItem != _hoveredItem) {
      setState(() {
        _hoveredItem = hoveredItem;

        if (widget.showTooltip && hoveredItem != null) {
          _tooltip = TreemapTooltip(
            item: hoveredItem,
            position: localPosition,
            isVisible: true,
          );
        } else {
          _tooltip = null;
        }
      });

      if (hoveredItem != null) {
        widget.onItemHover?.call(hoveredItem);
      }
    }
  }

  void _handleExit(PointerExitEvent event) {
    setState(() {
      _hoveredItem = null;
      _tooltip = null;
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    // Start zoom/pan gesture
    _zoomController.stop();
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_scale * details.scale).clamp(0.5, 3.0);
      _offset += details.focalPointDelta;
      _isZoomed = _scale != 1.0 || _offset != Offset.zero;
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // Snap back if needed
    if (_scale < 1.0) {
      _zoomController.animateTo(1.0).then((_) {
        setState(() {
          _scale = 1.0;
          _isZoomed = _offset != Offset.zero;
        });
      });
    }
  }

  // Navigation methods
  void _drillDown(TreemapItem item) {
    if (!item.hasChildren) return;

    setState(() {
      _breadcrumbs.add(
        TreemapBreadcrumb(
          label: item.label,
          item: item,
          level: _breadcrumbs.length,
        ),
      );
      _currentData = item.children!;
      _selectedItem = null;
      _hoveredItem = null;
    });

    _animationController.reset();
    _animationController.forward();

    widget.onDrillDown?.call(item.children!);
  }

  void _navigateToBreadcrumb(int index) {
    if (index < 0 || index >= _breadcrumbs.length) return;

    setState(() {
      if (index == 0) {
        _currentData = widget.data;
        _breadcrumbs.clear();
      } else {
        final targetBreadcrumb = _breadcrumbs[index];
        _currentData = targetBreadcrumb.item.children!;
        _breadcrumbs = _breadcrumbs.take(index + 1).toList();
      }
      _selectedItem = null;
      _hoveredItem = null;
    });

    _animationController.reset();
    _animationController.forward();
  }

  void _resetZoom() {
    _zoomController.animateTo(0.0).then((_) {
      setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
        _isZoomed = false;
      });
    });

    widget.onZoomReset?.call();
  }

  void _exportChart() async {
    try {
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;

        // In a real app, you would save this to file or share it
        await Clipboard.setData(const ClipboardData(text: 'Chart exported'));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chart exported to clipboard')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _toggleFullscreen() {
    // In a real app, you would implement fullscreen functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fullscreen functionality would be implemented here'),
      ),
    );
  }

  // Helper methods
  TreemapItem? _findItemAtPosition(Offset position) {
    for (final rect in _currentRects) {
      if (rect.rect.contains(position)) {
        return rect.item;
      }
    }
    return null;
  }

  List<TreemapItem> _getFilteredData() {
    if (_searchQuery.isEmpty) return _currentData;

    return _currentData.where((item) {
      return item.label.toLowerCase().contains(_searchQuery) ||
          (item.description?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  List<LegendItem> _generateLegendItems() {
    final totalValue = _currentData.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );

    return _currentData.map((item) {
      final percentage = totalValue > 0 ? (item.value / totalValue) * 100 : 0;
      return LegendItem(
        label: item.label,
        color: item.color ?? _getColorFromScheme(widget.colorScheme, 0),
        value: item.value,
        percentage: percentage.toDouble(),
      );
    }).toList();
  }

  String _formatValue(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  Color _getColorFromScheme(TreemapColorScheme scheme, int index) {
    switch (scheme) {
      case TreemapColorScheme.vibrant:
        final colors = [
          Colors.blue.shade400,
          Colors.green.shade400,
          Colors.orange.shade400,
          Colors.purple.shade400,
          Colors.red.shade400,
          Colors.teal.shade400,
          Colors.indigo.shade400,
          Colors.pink.shade400,
        ];
        return colors[index % colors.length];

      case TreemapColorScheme.pastel:
        final colors = [
          Colors.blue.shade200,
          Colors.green.shade200,
          Colors.orange.shade200,
          Colors.purple.shade200,
          Colors.red.shade200,
          Colors.teal.shade200,
          Colors.indigo.shade200,
          Colors.pink.shade200,
        ];
        return colors[index % colors.length];

      case TreemapColorScheme.business:
        final colors = [
          const Color(0xFF2E86AB),
          const Color(0xFFA23B72),
          const Color(0xFFF18F01),
          const Color(0xFFC73E1D),
          const Color(0xFF592E83),
          const Color(0xFF048A81),
          const Color(0xFF54478C),
          const Color(0xFF83677B),
        ];
        return colors[index % colors.length];

      default:
        return Colors.blue.shade400;
    }
  }
}

// Enhanced custom painter
class AdvancedTreemapPainter extends CustomPainter {
  final List<TreemapItem> data;
  final EdgeInsets padding;
  final bool showLabels;
  final TreemapItem? hoveredItem;
  final TreemapItem? selectedItem;
  final double animationValue;
  final TreemapColorScheme colorScheme;
  final TreemapStyle style;
  final String searchQuery;
  final Function(List<TreemapRect>)? onRectsCalculated;

  AdvancedTreemapPainter({
    required this.data,
    required this.padding,
    required this.showLabels,
    this.hoveredItem,
    this.selectedItem,
    required this.animationValue,
    required this.colorScheme,
    required this.style,
    required this.searchQuery,
    this.onRectsCalculated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final availableRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );

    final rects = _calculateLayout(data, availableRect);
    onRectsCalculated?.call(rects);

    // Draw background pattern
    _drawBackgroundPattern(canvas, size);

    // Draw rectangles with enhanced effects
    for (int i = 0; i < rects.length; i++) {
      _drawEnhancedRect(canvas, rects[i], i);
    }

    // Draw selection indicators
    _drawSelectionIndicators(canvas, rects);
  }

  void _drawBackgroundPattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade100.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const gridSize = 20.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawEnhancedRect(Canvas canvas, TreemapRect treeRect, int index) {
    final rect = treeRect.rect;
    final item = treeRect.item;

    // Animate rectangle appearance with stagger
    final staggerDelay = (index * 0.1).clamp(0.0, 0.5);
    final adjustedAnimation =
        ((animationValue - staggerDelay) / (1.0 - staggerDelay)).clamp(
          0.0,
          1.0,
        );

    final animatedRect = Rect.fromLTWH(
      rect.left + (rect.width * (1 - adjustedAnimation)) / 2,
      rect.top + (rect.height * (1 - adjustedAnimation)) / 2,
      rect.width * adjustedAnimation,
      rect.height * adjustedAnimation,
    );

    if (animatedRect.width <= 0 || animatedRect.height <= 0) return;

    // Determine colors and effects
    Color fillColor = item.color ?? _getColorFromScheme(colorScheme, index);
    Color strokeColor = style.borderColor;
    double strokeWidth = style.borderWidth;
    double elevation = 0.0;

    // Search highlight
    if (searchQuery.isNotEmpty &&
        (item.label.toLowerCase().contains(searchQuery) ||
            (item.description?.toLowerCase().contains(searchQuery) ?? false))) {
      fillColor = fillColor.withValues(alpha: 1.0);
      strokeColor = Colors.yellow.shade600;
      strokeWidth = 3.0;
      elevation = 4.0;
    }

    // Apply hover effects
    if (item == hoveredItem) {
      fillColor = Color.lerp(fillColor, Colors.white, 0.2)!;
      elevation = 6.0;
      strokeWidth = 2.0;
      strokeColor = Colors.blue.shade400;
    }

    // Apply selection effects
    if (item == selectedItem) {
      strokeWidth = 4.0;
      strokeColor = Colors.blue.shade700;
      elevation = 8.0;
    }

    // Draw shadow with elevation
    if (style.showShadows && elevation > 0) {
      final shadowPaint = Paint()
        ..color = style.shadowColor.withValues(alpha: 0.3 + (elevation / 20))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          style.shadowBlurRadius + elevation,
        );

      final shadowRect = RRect.fromRectAndRadius(
        animatedRect.shift(
          style.shadowOffset + Offset(elevation / 2, elevation / 2),
        ),
        Radius.circular(style.borderRadius),
      );
      canvas.drawRRect(shadowRect, shadowPaint);
    }

    // Draw gradient fill
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [fillColor, fillColor.withValues(alpha: 0.8)],
        stops: const [0.0, 1.0],
      ).createShader(animatedRect);

    final rrect = RRect.fromRectAndRadius(
      animatedRect,
      Radius.circular(style.borderRadius),
    );

    canvas.drawRRect(rrect, gradientPaint);

    // Draw pattern overlay for children items
    if (item.hasChildren) {
      _drawPatternOverlay(canvas, rrect, fillColor);
    }

    // Draw border
    if (strokeWidth > 0) {
      final borderPaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawRRect(rrect, borderPaint);
    }

    // Draw icon
    if (item.icon != null &&
        animatedRect.width > 40 &&
        animatedRect.height > 40) {
      _drawIcon(canvas, animatedRect, item.icon!, fillColor);
    }

    // Draw labels with enhanced styling
    if (showLabels && animatedRect.width > 60 && animatedRect.height > 30) {
      _drawEnhancedLabel(canvas, animatedRect, item, fillColor);
    }

    // Draw progress indicator for items with children
    if (item.hasChildren && animatedRect.width > 80) {
      _drawProgressIndicator(canvas, animatedRect, item);
    }
  }

  void _drawPatternOverlay(Canvas canvas, RRect rrect, Color baseColor) {
    final patternPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rect = rrect.outerRect;
    const spacing = 8.0;

    // Draw diagonal lines pattern
    for (double i = -rect.height; i < rect.width; i += spacing) {
      final start = Offset(rect.left + i, rect.top);
      final end = Offset(rect.left + i + rect.height, rect.bottom);
      canvas.drawLine(start, end, patternPaint);
    }
  }

  void _drawIcon(
    Canvas canvas,
    Rect rect,
    IconData icon,
    Color backgroundColor,
  ) {
    final iconSize = math
        .min(rect.width * 0.2, rect.height * 0.3)
        .clamp(16.0, 24.0);
    final iconColor = _getContrastColor(backgroundColor);

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          color: iconColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final iconOffset = Offset(rect.right - iconSize - 8, rect.top + 8);

    textPainter.paint(canvas, iconOffset);
  }

  void _drawEnhancedLabel(
    Canvas canvas,
    Rect rect,
    TreemapItem item,
    Color backgroundColor,
  ) {
    final textColor = _getContrastColor(backgroundColor);
    final fontSize = _calculateFontSize(rect);

    // Draw label with shadow
    final shadowPainter = TextPainter(
      text: TextSpan(
        text: item.label,
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.3),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      textAlign: TextAlign.center,
    );

    shadowPainter.layout(maxWidth: rect.width - 16);

    final labelPainter = TextPainter(
      text: TextSpan(
        text: item.label,
        style:
            style.labelStyle?.copyWith(color: textColor, fontSize: fontSize) ??
            TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      textAlign: TextAlign.center,
    );

    labelPainter.layout(maxWidth: rect.width - 16);

    final labelOffset = Offset(
      rect.left + (rect.width - labelPainter.width) / 2,
      rect.top + (rect.height - labelPainter.height) / 2,
    );

    // Draw shadow
    shadowPainter.paint(canvas, labelOffset + const Offset(1, 1));

    // Draw main text
    labelPainter.paint(canvas, labelOffset);

    // Draw value below label if there's space
    if (rect.height > 60) {
      final valuePainter = TextPainter(
        text: TextSpan(
          text: _formatValue(item.value),
          style:
              style.valueStyle?.copyWith(
                color: textColor.withValues(alpha: 0.8),
                fontSize: fontSize * 0.8,
              ) ??
              TextStyle(
                color: textColor.withValues(alpha: 0.8),
                fontSize: fontSize * 0.8,
                fontWeight: FontWeight.w400,
              ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textAlign: TextAlign.center,
      );

      valuePainter.layout(maxWidth: rect.width - 16);

      final valueOffset = Offset(
        rect.left + (rect.width - valuePainter.width) / 2,
        labelOffset.dy + labelPainter.height + 4,
      );

      valuePainter.paint(canvas, valueOffset);
    }
  }

  void _drawProgressIndicator(Canvas canvas, Rect rect, TreemapItem item) {
    if (!item.hasChildren) return;

    final totalValue = item.totalChildrenValue;
    final progressHeight = 4.0;
    final progressRect = Rect.fromLTWH(
      rect.left + 8,
      rect.bottom - progressHeight - 8,
      rect.width - 16,
      progressHeight,
    );

    // Background
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(progressRect, const Radius.circular(2)),
      backgroundPaint,
    );

    // Progress bars for children
    double currentX = progressRect.left;
    final colors = [
      Colors.blue.shade300,
      Colors.green.shade300,
      Colors.orange.shade300,
      Colors.purple.shade300,
    ];

    for (int i = 0; i < item.children!.length && i < 4; i++) {
      final child = item.children![i];
      final percentage = child.value / totalValue;
      final segmentWidth = progressRect.width * percentage;

      final segmentRect = Rect.fromLTWH(
        currentX,
        progressRect.top,
        segmentWidth,
        progressRect.height,
      );

      final segmentPaint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(segmentRect, const Radius.circular(2)),
        segmentPaint,
      );

      currentX += segmentWidth;
    }
  }

  void _drawSelectionIndicators(Canvas canvas, List<TreemapRect> rects) {
    // Draw connection lines for drill-down capability
    for (final rect in rects) {
      if (rect.item.hasChildren && rect.item == hoveredItem) {
        _drawDrillDownIndicator(canvas, rect.rect);
      }
    }
  }

  void _drawDrillDownIndicator(Canvas canvas, Rect rect) {
    final indicatorSize = 20.0;
    final indicatorRect = Rect.fromLTWH(
      rect.right - indicatorSize - 4,
      rect.bottom - indicatorSize - 4,
      indicatorSize,
      indicatorSize,
    );

    // Background circle
    final backgroundPaint = Paint()
      ..color = Colors.blue.shade600
      ..style = PaintingStyle.fill;

    canvas.drawCircle(indicatorRect.center, indicatorSize / 2, backgroundPaint);

    // Arrow icon
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final center = indicatorRect.center;
    final arrowSize = indicatorSize * 0.3;

    // Draw arrow pointing right and down
    canvas.drawLine(
      center + Offset(-arrowSize / 2, -arrowSize / 2),
      center + Offset(arrowSize / 2, arrowSize / 2),
      arrowPaint,
    );
    canvas.drawLine(
      center + Offset(-arrowSize / 2, arrowSize / 2),
      center + Offset(arrowSize / 2, arrowSize / 2),
      arrowPaint,
    );
    canvas.drawLine(
      center + Offset(arrowSize / 2, -arrowSize / 2),
      center + Offset(arrowSize / 2, arrowSize / 2),
      arrowPaint,
    );
  }

  // Layout calculation methods (squarified algorithm)
  List<TreemapRect> _calculateLayout(List<TreemapItem> items, Rect rect) {
    final result = <TreemapRect>[];
    final totalValue = items.fold<double>(0, (sum, item) => sum + item.value);

    if (totalValue <= 0) return result;

    final sortedItems = List<TreemapItem>.from(items)
      ..sort((a, b) => b.value.compareTo(a.value));

    _squarify(sortedItems, [], rect, result, totalValue, 0);

    return result;
  }

  void _squarify(
    List<TreemapItem> items,
    List<TreemapItem> row,
    Rect rect,
    List<TreemapRect> result,
    double totalValue,
    int depth,
  ) {
    if (items.isEmpty) {
      if (row.isNotEmpty) {
        _layoutRow(row, rect, result, totalValue, depth);
      }
      return;
    }

    final item = items.first;
    final newRow = [...row, item];

    if (row.isEmpty ||
        _calculateAspectRatio(row, rect, totalValue) >=
            _calculateAspectRatio(newRow, rect, totalValue)) {
      _squarify(
        items.skip(1).toList(),
        newRow,
        rect,
        result,
        totalValue,
        depth,
      );
    } else {
      final layoutRect = _layoutRow(row, rect, result, totalValue, depth);
      _squarify(items, [], layoutRect, result, totalValue, depth);
    }
  }

  double _calculateAspectRatio(
    List<TreemapItem> row,
    Rect rect,
    double totalValue,
  ) {
    if (row.isEmpty) return double.infinity;

    final rowSum = row.fold<double>(0, (sum, item) => sum + item.value);
    final rowMax = row.map((item) => item.value).reduce(math.max);
    final rowMin = row.map((item) => item.value).reduce(math.min);

    final rectArea = rect.width * rect.height;
    final normalizedRowSum = (rowSum / totalValue) * rectArea;

    final shortSide = math.min(rect.width, rect.height);

    if (shortSide == 0) return double.infinity;

    final w = normalizedRowSum / shortSide;
    final aspectMax = math.max(
      w / (rowMax / rowSum * normalizedRowSum / w),
      (rowMax / rowSum * normalizedRowSum / w) / w,
    );
    final aspectMin = math.max(
      w / (rowMin / rowSum * normalizedRowSum / w),
      (rowMin / rowSum * normalizedRowSum / w) / w,
    );

    return math.max(aspectMax, aspectMin);
  }

  Rect _layoutRow(
    List<TreemapItem> row,
    Rect rect,
    List<TreemapRect> result,
    double totalValue,
    int depth,
  ) {
    if (row.isEmpty) return rect;

    final rowSum = row.fold<double>(0, (sum, item) => sum + item.value);
    final rectArea = rect.width * rect.height;
    final normalizedRowSum = (rowSum / totalValue) * rectArea;

    final longSide = math.max(rect.width, rect.height);

    final isHorizontal = rect.width == longSide;
    final thickness = normalizedRowSum / longSide;

    double position = 0;

    for (final item in row) {
      final normalizedValue = (item.value / totalValue) * rectArea;
      final length = normalizedValue / thickness;

      Rect itemRect;
      if (isHorizontal) {
        itemRect = Rect.fromLTWH(
          rect.left,
          rect.top + position,
          thickness,
          length,
        );
      } else {
        itemRect = Rect.fromLTWH(
          rect.left + position,
          rect.top,
          length,
          thickness,
        );
      }

      result.add(TreemapRect(rect: itemRect, item: item, depth: depth));

      position += length;
    }

    // Return remaining rectangle
    if (isHorizontal) {
      return Rect.fromLTWH(
        rect.left + thickness,
        rect.top,
        rect.width - thickness,
        rect.height,
      );
    } else {
      return Rect.fromLTWH(
        rect.left,
        rect.top + thickness,
        rect.width,
        rect.height - thickness,
      );
    }
  }

  Color _getColorFromScheme(TreemapColorScheme scheme, int index) {
    switch (scheme) {
      case TreemapColorScheme.vibrant:
        final colors = [
          Colors.blue.shade400,
          Colors.green.shade400,
          Colors.orange.shade400,
          Colors.purple.shade400,
          Colors.red.shade400,
          Colors.teal.shade400,
          Colors.indigo.shade400,
          Colors.pink.shade400,
        ];
        return colors[index % colors.length];

      case TreemapColorScheme.pastel:
        final colors = [
          Colors.blue.shade200,
          Colors.green.shade200,
          Colors.orange.shade200,
          Colors.purple.shade200,
          Colors.red.shade200,
          Colors.teal.shade200,
          Colors.indigo.shade200,
          Colors.pink.shade200,
        ];
        return colors[index % colors.length];

      case TreemapColorScheme.monochrome:
        final baseColor = Colors.grey.shade600;
        final opacity = 1.0 - (index * 0.1).clamp(0.0, 0.8);
        return baseColor.withValues(alpha: opacity);

      case TreemapColorScheme.business:
        final colors = [
          const Color(0xFF2E86AB),
          const Color(0xFFA23B72),
          const Color(0xFFF18F01),
          const Color(0xFFC73E1D),
          const Color(0xFF592E83),
          const Color(0xFF048A81),
          const Color(0xFF54478C),
          const Color(0xFF83677B),
        ];
        return colors[index % colors.length];

      case TreemapColorScheme.nature:
        final colors = [
          const Color(0xFF2D5016),
          const Color(0xFF61A5C2),
          const Color(0xFFA9BA9D),
          const Color(0xFFC9ADA7),
          const Color(0xFFE9C46A),
          const Color(0xFFF4A261),
          const Color(0xFFE76F51),
          const Color(0xFF264653),
        ];
        return colors[index % colors.length];

      case TreemapColorScheme.sunset:
        final colors = [
          const Color(0xFFFF6B6B),
          const Color(0xFF4ECDC4),
          const Color(0xFF45B7D1),
          const Color(0xFF96CEB4),
          const Color(0xFFFECB77),
          const Color(0xFFFF8B94),
          const Color(0xFFFFB347),
          const Color(0xFF87CEEB),
        ];
        return colors[index % colors.length];
    }
  }

  Color _getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  double _calculateFontSize(Rect rect) {
    final area = rect.width * rect.height;
    if (area < 1000) return 8;
    if (area < 2000) return 10;
    if (area < 5000) return 12;
    if (area < 10000) return 14;
    if (area < 20000) return 16;
    return 18;
  }

  String _formatValue(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(AdvancedTreemapPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.hoveredItem != hoveredItem ||
        oldDelegate.selectedItem != selectedItem ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.searchQuery != searchQuery;
  }
}

// Enhanced demo with hierarchical data and all features
class AdvancedTreemapDemo extends StatelessWidget {
  const AdvancedTreemapDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final hierarchicalData = [
      TreemapItem(
        label: 'Technology',
        value: 45000,
        color: Colors.blue.shade400,
        icon: Icons.computer,
        description:
            'Technology sector including software, hardware, and services',
        metadata: {'Growth': '+12.5%', 'Employees': '125K', 'Region': 'Global'},
        children: [
          TreemapItem(
            label: 'Software',
            value: 25000,
            color: Colors.blue.shade500,
            icon: Icons.code,
            description: 'Software development and SaaS',
          ),
          TreemapItem(
            label: 'Hardware',
            value: 15000,
            color: Colors.blue.shade300,
            icon: Icons.memory,
            description: 'Computer hardware and components',
          ),
          TreemapItem(
            label: 'Services',
            value: 5000,
            color: Colors.blue.shade200,
            icon: Icons.support_agent,
            description: 'IT consulting and support services',
          ),
        ],
      ),
      TreemapItem(
        label: 'Finance',
        value: 32000,
        color: Colors.green.shade400,
        icon: Icons.account_balance,
        description: 'Financial services and banking',
        metadata: {
          'Growth': '+8.3%',
          'Employees': '89K',
          'Region': 'North America',
        },
        children: [
          TreemapItem(
            label: 'Banking',
            value: 18000,
            color: Colors.green.shade500,
            icon: Icons.account_balance,
          ),
          TreemapItem(
            label: 'Insurance',
            value: 10000,
            color: Colors.green.shade300,
            icon: Icons.security,
          ),
          TreemapItem(
            label: 'Investment',
            value: 4000,
            color: Colors.green.shade200,
            icon: Icons.trending_up,
          ),
        ],
      ),
      TreemapItem(
        label: 'Healthcare',
        value: 28000,
        color: Colors.red.shade400,
        icon: Icons.local_hospital,
        description: 'Healthcare and medical services',
        metadata: {'Growth': '+15.2%', 'Employees': '156K', 'Region': 'Global'},
        children: [
          TreemapItem(
            label: 'Pharmaceuticals',
            value: 16000,
            color: Colors.red.shade500,
            icon: Icons.medication,
          ),
          TreemapItem(
            label: 'Medical Devices',
            value: 8000,
            color: Colors.red.shade300,
            icon: Icons.medical_services,
          ),
          TreemapItem(
            label: 'Digital Health',
            value: 4000,
            color: Colors.red.shade200,
            icon: Icons.health_and_safety,
          ),
        ],
      ),
      TreemapItem(
        label: 'Education',
        value: 18000,
        color: Colors.orange.shade400,
        icon: Icons.school,
        description: 'Educational services and e-learning',
        metadata: {'Growth': '+22.1%', 'Employees': '67K', 'Region': 'Global'},
      ),
      TreemapItem(
        label: 'Retail',
        value: 15000,
        color: Colors.purple.shade400,
        icon: Icons.shopping_cart,
        description: 'Retail and e-commerce',
        metadata: {'Growth': '+5.7%', 'Employees': '234K', 'Region': 'Global'},
      ),
      TreemapItem(
        label: 'Manufacturing',
        value: 12000,
        color: Colors.teal.shade400,
        icon: Icons.precision_manufacturing,
        description: 'Manufacturing and industrial production',
        metadata: {
          'Growth': '+3.2%',
          'Employees': '189K',
          'Region': 'Asia-Pacific',
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Treemap Chart'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AdvancedTreemapChart(
        data: hierarchicalData,
        colorScheme: TreemapColorScheme.vibrant,
        style: const TreemapStyle(
          borderRadius: 8.0,
          borderWidth: 2.0,
          showShadows: true,
          shadowBlurRadius: 6.0,
        ),
        onItemTap: (item) {
          debugPrint('Tapped: ${item.label} - ${item.value}');
        },
        onItemHover: (item) {
          debugPrint('Hovered: ${item.label}');
        },
        onDrillDown: (items) {
          debugPrint('Drilled down to ${items.length} items');
        },
        onZoomReset: () {
          debugPrint('Zoom reset');
        },
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(home: AdvancedTreemapDemo()));
}
