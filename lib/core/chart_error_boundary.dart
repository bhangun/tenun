import 'package:flutter/material.dart';
import 'base_config.dart';

typedef ChartErrorHandler = void Function(Object error, StackTrace stack);
typedef ChartErrorWidgetBuilder =
    Widget Function(BuildContext context, Object error);

/// Wraps chart rendering to catch fatal exceptions and show a safe fallback.
///
/// This boundary protects the rest of the application from crashing if a
/// specific chart configuration or data payload is malformed.
class ChartErrorBoundary extends StatefulWidget {
  /// Function that returns the chart configuration.
  final BaseChartConfig Function() configBuilder;

  /// Optional callback triggered when an error occurs.
  final ChartErrorHandler? onError;

  /// Optional custom widget to display when an error occurs.
  final ChartErrorWidgetBuilder? errorWidget;

  /// Builder function that renders the chart using the validated configuration.
  final Widget Function(BaseChartConfig config) chartBuilder;

  const ChartErrorBoundary({
    super.key,
    required this.configBuilder,
    required this.chartBuilder,
    this.onError,
    this.errorWidget,
  });

  @override
  State<ChartErrorBoundary> createState() => _ChartErrorBoundaryState();
}

class _ChartErrorBoundaryState extends State<ChartErrorBoundary> {
  Object? _error;
  BaseChartConfig? _config;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void didUpdateWidget(covariant ChartErrorBoundary old) {
    super.didUpdateWidget(old);
    if (old.configBuilder != widget.configBuilder) {
      _loadConfig();
    }
  }

  void _loadConfig() {
    try {
      setState(() {
        _error = null;
        _config = widget.configBuilder();
      });
    } catch (e, stack) {
      setState(() => _error = e);
      widget.onError?.call(e, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorWidget?.call(context, _error!) ??
          _fallbackWidget(context, _error!);
    }
    if (_config == null) {
      return const SizedBox.shrink();
    }

    return widget.chartBuilder(_config!);
  }

  Widget _fallbackWidget(BuildContext context, Object error) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 32,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            'Chart Configuration Error',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error.toString(),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _loadConfig,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
