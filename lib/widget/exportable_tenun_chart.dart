import 'package:flutter/material.dart';

import '../core/base_config.dart';
import '../core/chart_builder.dart';
import '../core/chart_config_validator.dart';
import '../core/chart_export.dart';
import '../core/chart_export_archive.dart';
import '../core/chart_export_delivery.dart';
import '../core/chart_export_job.dart';
import '../core/chart_runtime_diagnostics.dart';
import 'chart_diagnostic_fallback_options.dart';
import 'chart_export_controls.dart';

/// Turnkey chart + export controls wrapper.
///
/// Accepts either a resolved [config] or a JSON [jsonConfig]. The chart is
/// wrapped in [ExportableChart], and the same resolved config is passed to
/// [ChartExportControls] so data exports work for JSON-driven charts too.
class ExportableTenunChart extends StatefulWidget {
  final BaseChartConfig? config;
  final Map<String, dynamic>? jsonConfig;
  final ExportableChartController? exportController;
  final List<ChartExportFormat> formats;
  final List<String>? categoryLabels;
  final String filename;
  final String sheetName;
  final String delimiter;
  final String lineEnding;
  final double pixelRatio;
  final int jpegQuality;
  final Color jpegBackgroundColor;
  final Duration? exportTimeout;
  final Duration? deliveryTimeout;
  final ChartExportCancellationToken? exportCancellationToken;
  final ChartExportJobPreflightPolicy exportPreflightPolicy;
  final bool copyTextExportsToClipboard;
  final bool showExportControls;
  final bool showExportStatus;
  final bool showExportPreflightDiagnostics;
  final bool showUnavailableFormatTooltips;
  final bool showBatchExportButton;
  final bool showArchiveExportButton;
  final bool showCancelExportButton;
  final bool stopBatchOnFirstFailure;
  final bool stopDeliveryBatchOnFirstFailure;
  final String batchExportLabel;
  final String archiveExportLabel;
  final String cancelExportLabel;
  final String cancelExportReason;
  final String? archiveFilename;
  final bool includeArchiveManifest;
  final String archiveManifestFilename;
  final Axis controlsDirection;
  final ChartExportStartedHandler? onExportStarted;
  final ChartExportResultHandler? onExportResult;
  final ChartExportJobPlanHandler? onExportJobPlan;
  final ChartExportJobProgressHandler? onExportJobProgress;
  final ChartExportJobResultHandler? onExportJobResult;
  final ChartExportBatchStartedHandler? onBatchExportStarted;
  final ChartExportBatchProgressHandler? onBatchExportProgress;
  final ChartExportBatchResultHandler? onBatchExportResult;
  final ChartExportJobPlanHandler? onBatchExportJobPlan;
  final ChartExportJobProgressHandler? onBatchExportJobProgress;
  final ChartExportJobResultHandler? onBatchExportJobResult;
  final ChartExportArchiveStartedHandler? onArchiveExportStarted;
  final ChartExportJobPlanHandler? onArchiveExportJobPlan;
  final ChartExportJobProgressHandler? onArchiveExportJobProgress;
  final ChartExportJobResultHandler? onArchiveExportJobResult;
  final ChartExportArchiveResultHandler? onArchiveExportResult;
  final Widget? controlsLeading;
  final Widget? controlsTrailing;
  final MainAxisAlignment controlsMainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double controlsSpacing;
  final ButtonStyle? exportButtonStyle;
  final ChartExportDeliveryAdapter? exportDeliveryAdapter;
  final ChartExportDeliveryResultHandler? onExportDeliveryResult;
  final ChartExportDeliveryResultHandler? onArchiveExportDeliveryResult;
  final ChartExportDeliveryBatchProgressHandler? onExportDeliveryBatchProgress;
  final ChartExportDeliveryBatchResultHandler? onExportDeliveryBatchResult;
  final ChartExportControlsErrorHandler? onExportError;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? chartPadding;
  final EdgeInsetsGeometry? padding;
  final bool validatePayload;
  final bool strictValidation;
  final int validationReportMaxIssues;
  final TenunDiagnosticFallbackOptions diagnosticFallbackOptions;
  final void Function(ValidationResult result)? onValidationResult;
  final void Function(PayloadNormalizationResult result)?
  onPayloadNormalizationResult;
  final void Function(ChartRuntimeDiagnostics diagnostics)?
  onRuntimeDiagnostics;
  final ChartRuntimePerformancePolicy runtimePerformancePolicy;
  final bool catchRenderErrors;
  final bool autoNormalizePayload;
  final bool sanitizeTradingPayload;
  final bool dropUnsupportedSampling;
  final int? normalizeDefaultThreshold;
  final ChartDataMode normalizeDefaultMode;
  final PayloadNormalizationOptions? normalizationOptions;
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  const ExportableTenunChart({
    super.key,
    this.config,
    this.jsonConfig,
    this.exportController,
    this.formats = ChartExportControls.defaultFormats,
    this.categoryLabels,
    this.filename = 'chart_export',
    this.sheetName = 'Chart Data',
    this.delimiter = ',',
    this.lineEnding = '\r\n',
    this.pixelRatio = 2,
    this.jpegQuality = 90,
    this.jpegBackgroundColor = Colors.white,
    this.exportTimeout,
    this.deliveryTimeout,
    this.exportCancellationToken,
    this.exportPreflightPolicy = ChartExportJobPreflightPolicy.failOnBlockers,
    this.copyTextExportsToClipboard = true,
    this.showExportControls = true,
    this.showExportStatus = true,
    this.showExportPreflightDiagnostics = true,
    this.showUnavailableFormatTooltips = true,
    this.showBatchExportButton = true,
    this.showArchiveExportButton = false,
    this.showCancelExportButton = false,
    this.stopBatchOnFirstFailure = false,
    this.stopDeliveryBatchOnFirstFailure = false,
    this.batchExportLabel = 'All',
    this.archiveExportLabel = 'ZIP',
    this.cancelExportLabel = 'Cancel',
    this.cancelExportReason = 'Export cancelled by user.',
    this.archiveFilename,
    this.includeArchiveManifest = true,
    this.archiveManifestFilename = ChartExportArchive.defaultManifestFilename,
    this.controlsDirection = Axis.horizontal,
    this.onExportStarted,
    this.onExportResult,
    this.onExportJobPlan,
    this.onExportJobProgress,
    this.onExportJobResult,
    this.onBatchExportStarted,
    this.onBatchExportProgress,
    this.onBatchExportResult,
    this.onBatchExportJobPlan,
    this.onBatchExportJobProgress,
    this.onBatchExportJobResult,
    this.onArchiveExportStarted,
    this.onArchiveExportJobPlan,
    this.onArchiveExportJobProgress,
    this.onArchiveExportJobResult,
    this.onArchiveExportResult,
    this.controlsLeading,
    this.controlsTrailing,
    this.controlsMainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.controlsSpacing = 8,
    this.exportButtonStyle,
    this.exportDeliveryAdapter,
    this.onExportDeliveryResult,
    this.onArchiveExportDeliveryResult,
    this.onExportDeliveryBatchProgress,
    this.onExportDeliveryBatchResult,
    this.onExportError,
    this.width,
    this.height,
    this.chartPadding,
    this.padding,
    this.validatePayload = false,
    this.strictValidation = false,
    this.validationReportMaxIssues = 3,
    this.diagnosticFallbackOptions = const TenunDiagnosticFallbackOptions(),
    this.onValidationResult,
    this.onPayloadNormalizationResult,
    this.onRuntimeDiagnostics,
    this.runtimePerformancePolicy = ChartRuntimePerformancePolicy.defaults,
    this.catchRenderErrors = false,
    this.autoNormalizePayload = false,
    this.sanitizeTradingPayload = true,
    this.dropUnsupportedSampling = true,
    this.normalizeDefaultThreshold,
    this.normalizeDefaultMode = ChartDataMode.auto,
    this.normalizationOptions,
    this.errorBuilder,
  });

  @override
  State<ExportableTenunChart> createState() => _ExportableTenunChartState();
}

class _ExportableTenunChartState extends State<ExportableTenunChart> {
  late final ExportableChartController _ownedController;

  @override
  void initState() {
    super.initState();
    _ownedController = ExportableChartController();
  }

  ExportableChartController get _controller =>
      widget.exportController ?? _ownedController;

  @override
  Widget build(BuildContext context) {
    Widget result = _buildResolvedContent(context);
    if (widget.padding != null) {
      result = Padding(padding: widget.padding!, child: result);
    }
    return result;
  }

  Widget _buildResolvedContent(BuildContext context) {
    final resolved = _resolveChart(context);
    final config = resolved.config;
    if (config == null) return resolved.fallback ?? const SizedBox.shrink();

    final chart = ExportableChart(
      controller: _controller,
      child: TenunChart(
        config: config,
        width: widget.width,
        height: widget.height,
        padding: widget.chartPadding,
        validatePayload: widget.validatePayload,
        strictValidation: widget.strictValidation,
        validationReportMaxIssues: widget.validationReportMaxIssues,
        diagnosticFallbackOptions: widget.diagnosticFallbackOptions,
        onValidationResult: widget.onValidationResult,
        onRuntimeDiagnostics: widget.onRuntimeDiagnostics,
        runtimePerformancePolicy: widget.runtimePerformancePolicy,
        catchRenderErrors: widget.catchRenderErrors,
      ),
    );

    if (!widget.showExportControls) return chart;

    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldExpandChart = constraints.maxHeight.isFinite;
        return Column(
          crossAxisAlignment: widget.crossAxisAlignment,
          children: [
            if (shouldExpandChart) Expanded(child: chart) else chart,
            SizedBox(height: widget.controlsSpacing),
            _buildControls(config),
          ],
        );
      },
    );
  }

  Widget _buildControls(BaseChartConfig config) {
    final controls = ChartExportControls(
      config: config,
      jsonConfig: widget.jsonConfig,
      controller: _controller,
      formats: widget.formats,
      categoryLabels: widget.categoryLabels,
      filename: widget.filename,
      sheetName: widget.sheetName,
      delimiter: widget.delimiter,
      lineEnding: widget.lineEnding,
      pixelRatio: widget.pixelRatio,
      jpegQuality: widget.jpegQuality,
      jpegBackgroundColor: widget.jpegBackgroundColor,
      exportTimeout: widget.exportTimeout,
      deliveryTimeout: widget.deliveryTimeout,
      cancellationToken: widget.exportCancellationToken,
      preflightPolicy: widget.exportPreflightPolicy,
      copyTextExportsToClipboard: widget.copyTextExportsToClipboard,
      showStatus: widget.showExportStatus,
      showPreflightDiagnostics: widget.showExportPreflightDiagnostics,
      showUnavailableFormatTooltips: widget.showUnavailableFormatTooltips,
      showBatchExportButton: widget.showBatchExportButton,
      showArchiveExportButton: widget.showArchiveExportButton,
      showCancelButton: widget.showCancelExportButton,
      stopBatchOnFirstFailure: widget.stopBatchOnFirstFailure,
      stopDeliveryBatchOnFirstFailure: widget.stopDeliveryBatchOnFirstFailure,
      batchExportLabel: widget.batchExportLabel,
      archiveExportLabel: widget.archiveExportLabel,
      cancelExportLabel: widget.cancelExportLabel,
      cancelExportReason: widget.cancelExportReason,
      archiveFilename: widget.archiveFilename,
      includeArchiveManifest: widget.includeArchiveManifest,
      archiveManifestFilename: widget.archiveManifestFilename,
      direction: widget.controlsDirection,
      buttonStyle: widget.exportButtonStyle,
      deliveryAdapter: widget.exportDeliveryAdapter,
      onStarted: widget.onExportStarted,
      onResult: widget.onExportResult,
      onExportJobPlan: widget.onExportJobPlan,
      onExportJobProgress: widget.onExportJobProgress,
      onExportJobResult: widget.onExportJobResult,
      onBatchStarted: widget.onBatchExportStarted,
      onBatchProgress: widget.onBatchExportProgress,
      onBatchResult: widget.onBatchExportResult,
      onBatchJobPlan: widget.onBatchExportJobPlan,
      onBatchJobProgress: widget.onBatchExportJobProgress,
      onBatchJobResult: widget.onBatchExportJobResult,
      onArchiveStarted: widget.onArchiveExportStarted,
      onArchiveJobPlan: widget.onArchiveExportJobPlan,
      onArchiveJobProgress: widget.onArchiveExportJobProgress,
      onArchiveJobResult: widget.onArchiveExportJobResult,
      onArchiveResult: widget.onArchiveExportResult,
      onDeliveryResult: widget.onExportDeliveryResult,
      onArchiveDeliveryResult: widget.onArchiveExportDeliveryResult,
      onDeliveryBatchProgress: widget.onExportDeliveryBatchProgress,
      onDeliveryBatchResult: widget.onExportDeliveryBatchResult,
      onError: widget.onExportError,
    );

    return Row(
      mainAxisAlignment: widget.controlsMainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.controlsLeading != null) ...[
          widget.controlsLeading!,
          SizedBox(width: widget.controlsSpacing),
        ],
        Flexible(child: controls),
        if (widget.controlsTrailing != null) ...[
          SizedBox(width: widget.controlsSpacing),
          widget.controlsTrailing!,
        ],
      ],
    );
  }

  _ResolvedExportableChart _resolveChart(BuildContext context) {
    final config = widget.config;
    if (config != null) return _ResolvedExportableChart.config(config);
    final json = widget.jsonConfig;
    if (json == null) return const _ResolvedExportableChart.empty();

    try {
      return _ResolvedExportableChart.config(
        ChartFactory.fromJson(
          json,
          validatePayload: widget.validatePayload,
          strictValidation: widget.strictValidation,
          validationReportMaxIssues: widget.validationReportMaxIssues,
          autoNormalizePayload: widget.autoNormalizePayload,
          sanitizeTradingPayload: widget.sanitizeTradingPayload,
          dropUnsupportedSampling: widget.dropUnsupportedSampling,
          normalizeDefaultThreshold: widget.normalizeDefaultThreshold,
          normalizeDefaultMode: widget.normalizeDefaultMode,
          normalizationOptions: widget.normalizationOptions,
          onValidationResult: widget.onValidationResult,
          onPayloadNormalizationResult: widget.onPayloadNormalizationResult,
        ),
      );
    } catch (error) {
      if (widget.errorBuilder != null) {
        return _ResolvedExportableChart.fallback(
          widget.errorBuilder!(context, error),
        );
      }
      if (!widget.catchRenderErrors) rethrow;
      return _ResolvedExportableChart.fallback(
        _DefaultExportableChartError(error: error),
      );
    }
  }
}

class _ResolvedExportableChart {
  final BaseChartConfig? config;
  final Widget? fallback;

  const _ResolvedExportableChart._({this.config, this.fallback});

  const _ResolvedExportableChart.empty() : this._();

  const _ResolvedExportableChart.config(BaseChartConfig config)
    : this._(config: config);

  const _ResolvedExportableChart.fallback(Widget fallback)
    : this._(fallback: fallback);
}

class _DefaultExportableChartError extends StatelessWidget {
  final Object error;

  const _DefaultExportableChartError({required this.error});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Unable to resolve exportable chart: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
