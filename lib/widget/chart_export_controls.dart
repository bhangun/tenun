import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/base_config.dart';
import '../core/chart_export.dart';
import '../core/chart_export_archive.dart';
import '../core/chart_export_capability.dart';
import '../core/chart_export_delivery.dart';
import '../core/chart_export_job.dart';
import '../core/chart_export_summary.dart';

typedef ChartExportStartedHandler = void Function(ChartExportFormat format);
typedef ChartExportResultHandler = void Function(ChartExportResult result);
typedef ChartExportBatchStartedHandler =
    void Function(List<ChartExportFormat> formats);
typedef ChartExportBatchResultHandler =
    void Function(ChartExportBatchResult result);
typedef ChartExportArchiveStartedHandler =
    void Function(List<ChartExportFormat> formats);
typedef ChartExportArchiveResultHandler = void Function(ChartExportFile file);
typedef ChartExportDeliveryResultHandler =
    void Function(ChartExportDeliveryResult result);
typedef ChartExportDeliveryBatchResultHandler =
    void Function(ChartExportDeliveryBatchResult result);
typedef ChartExportJobPlanHandler = void Function(ChartExportJobPlan plan);
typedef ChartExportJobResultHandler =
    void Function(ChartExportJobResult result);
typedef ChartExportControlsErrorHandler =
    void Function(Object error, StackTrace stackTrace);

/// Material export toolbar for config-driven charts.
///
/// Data exports (`csv`, `xlsx`) require [config]. Image exports (`png`, `jpeg`)
/// require either [boundaryKey] or [controller].
class ChartExportControls extends StatefulWidget {
  static const defaultFormats = [
    ChartExportFormat.csv,
    ChartExportFormat.xlsx,
    ChartExportFormat.png,
    ChartExportFormat.jpeg,
  ];

  final BaseChartConfig? config;
  final Map<String, dynamic>? jsonConfig;
  final List<List<Object?>>? rows;
  final GlobalKey? boundaryKey;
  final ExportableChartController? controller;
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
  final ChartExportCancellationToken? cancellationToken;
  final ChartExportJobPreflightPolicy preflightPolicy;
  final bool copyTextExportsToClipboard;
  final bool showStatus;
  final bool showPreflightDiagnostics;
  final bool showUnavailableFormatTooltips;
  final bool showBatchExportButton;
  final bool showArchiveExportButton;
  final bool showCancelButton;
  final bool stopBatchOnFirstFailure;
  final bool stopDeliveryBatchOnFirstFailure;
  final String batchExportLabel;
  final String archiveExportLabel;
  final String cancelExportLabel;
  final String cancelExportReason;
  final String? archiveFilename;
  final bool includeArchiveManifest;
  final String archiveManifestFilename;
  final Axis direction;
  final double spacing;
  final double runSpacing;
  final ButtonStyle? buttonStyle;
  final ChartExportDeliveryAdapter? deliveryAdapter;
  final ChartExportStartedHandler? onStarted;
  final ChartExportResultHandler? onResult;
  final ChartExportJobPlanHandler? onExportJobPlan;
  final ChartExportJobProgressHandler? onExportJobProgress;
  final ChartExportJobResultHandler? onExportJobResult;
  final ChartExportBatchStartedHandler? onBatchStarted;
  final ChartExportBatchProgressHandler? onBatchProgress;
  final ChartExportBatchResultHandler? onBatchResult;
  final ChartExportJobPlanHandler? onBatchJobPlan;
  final ChartExportJobProgressHandler? onBatchJobProgress;
  final ChartExportJobResultHandler? onBatchJobResult;
  final ChartExportArchiveStartedHandler? onArchiveStarted;
  final ChartExportJobPlanHandler? onArchiveJobPlan;
  final ChartExportJobProgressHandler? onArchiveJobProgress;
  final ChartExportJobResultHandler? onArchiveJobResult;
  final ChartExportArchiveResultHandler? onArchiveResult;
  final ChartExportDeliveryResultHandler? onDeliveryResult;
  final ChartExportDeliveryResultHandler? onArchiveDeliveryResult;
  final ChartExportDeliveryBatchProgressHandler? onDeliveryBatchProgress;
  final ChartExportDeliveryBatchResultHandler? onDeliveryBatchResult;
  final ChartExportControlsErrorHandler? onError;

  const ChartExportControls({
    super.key,
    this.config,
    this.jsonConfig,
    this.rows,
    this.boundaryKey,
    this.controller,
    this.formats = defaultFormats,
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
    this.cancellationToken,
    this.preflightPolicy = ChartExportJobPreflightPolicy.failOnBlockers,
    this.copyTextExportsToClipboard = true,
    this.showStatus = true,
    this.showPreflightDiagnostics = true,
    this.showUnavailableFormatTooltips = true,
    this.showBatchExportButton = true,
    this.showArchiveExportButton = false,
    this.showCancelButton = false,
    this.stopBatchOnFirstFailure = false,
    this.stopDeliveryBatchOnFirstFailure = false,
    this.batchExportLabel = 'All',
    this.archiveExportLabel = 'ZIP',
    this.cancelExportLabel = 'Cancel',
    this.cancelExportReason = 'Export cancelled by user.',
    this.archiveFilename,
    this.includeArchiveManifest = true,
    this.archiveManifestFilename = ChartExportArchive.defaultManifestFilename,
    this.direction = Axis.horizontal,
    this.spacing = 8,
    this.runSpacing = 8,
    this.buttonStyle,
    this.deliveryAdapter,
    this.onStarted,
    this.onResult,
    this.onExportJobPlan,
    this.onExportJobProgress,
    this.onExportJobResult,
    this.onBatchStarted,
    this.onBatchProgress,
    this.onBatchResult,
    this.onBatchJobPlan,
    this.onBatchJobProgress,
    this.onBatchJobResult,
    this.onArchiveStarted,
    this.onArchiveJobPlan,
    this.onArchiveJobProgress,
    this.onArchiveJobResult,
    this.onArchiveResult,
    this.onDeliveryResult,
    this.onArchiveDeliveryResult,
    this.onDeliveryBatchProgress,
    this.onDeliveryBatchResult,
    this.onError,
  });

  @override
  State<ChartExportControls> createState() => _ChartExportControlsState();
}

class _ChartExportControlsState extends State<ChartExportControls> {
  ChartExportFormat? _exporting;
  bool _exportingBatch = false;
  bool _exportingArchive = false;
  ChartExportResult? _lastResult;
  ChartExportBatchResult? _lastBatchResult;
  ChartExportFile? _lastArchiveFile;
  ChartExportDeliveryResult? _lastDeliveryResult;
  ChartExportDeliveryResult? _lastArchiveDeliveryResult;
  ChartExportDeliveryBatchResult? _lastDeliveryBatchResult;
  ChartExportJobResult? _lastJobResult;
  Object? _lastControlError;
  ChartExportJobProgress? _activeJobProgress;
  ChartExportJobController? _activeJobController;
  bool _cancelRequested = false;

  @override
  Widget build(BuildContext context) {
    final capabilities = _capabilities;
    final batchFormats = capabilities.exportableFormats;
    final controls = Wrap(
      direction: widget.direction,
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      children: [
        for (final format in widget.formats)
          _buttonFor(capabilities.capabilityFor(format)),
        if (widget.showBatchExportButton && batchFormats.length > 1)
          _batchButton(batchFormats),
        if (widget.showArchiveExportButton && batchFormats.isNotEmpty)
          _archiveButton(batchFormats),
        if (widget.showCancelButton && _busy) _cancelButton(),
      ],
    );

    if (!widget.showStatus) return controls;

    final status = _statusText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        controls,
        if (status != null) ...[
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(
              color:
                  _lastControlError != null ||
                      _lastJobResult?.isFailed == true ||
                      _preflightStatusText != null ||
                      _lastResult?.success == false ||
                      _lastBatchResult?.hasFailures == true ||
                      _lastDeliveryResult?.success == false ||
                      _lastArchiveDeliveryResult?.success == false ||
                      _lastDeliveryBatchResult?.hasFailures == true
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buttonFor(ChartExportCapability capability) {
    final format = capability.format;
    final busy = _exporting == format;
    final button = OutlinedButton.icon(
      style: widget.buttonStyle,
      onPressed: capability.canExport && !_busy
          ? () => _runExport(format)
          : null,
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_iconFor(format), size: 16),
      label: Text(_labelFor(format)),
    );

    final reason = capability.disabledReason;
    if (!widget.showUnavailableFormatTooltips || reason == null) {
      return button;
    }

    return Tooltip(message: reason, child: button);
  }

  Widget _batchButton(List<ChartExportFormat> formats) {
    return OutlinedButton.icon(
      style: widget.buttonStyle,
      onPressed: !_busy ? () => _runBatchExport(formats) : null,
      icon: _exportingBatch
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_done_outlined, size: 16),
      label: Text(widget.batchExportLabel),
    );
  }

  Widget _archiveButton(List<ChartExportFormat> formats) {
    return OutlinedButton.icon(
      style: widget.buttonStyle,
      onPressed: !_busy ? () => _runArchiveExport(formats) : null,
      icon: _exportingArchive
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.archive_outlined, size: 16),
      label: Text(widget.archiveExportLabel),
    );
  }

  Widget _cancelButton() {
    return OutlinedButton.icon(
      style: widget.buttonStyle,
      onPressed: _cancelRequested || _activeJobController == null
          ? null
          : _cancelActiveJob,
      icon: const Icon(Icons.cancel_outlined, size: 16),
      label: Text(widget.cancelExportLabel),
    );
  }

  GlobalKey? get _boundaryKey =>
      widget.boundaryKey ?? widget.controller?.boundaryKey;

  bool get _busy => _exporting != null || _exportingBatch || _exportingArchive;

  ChartExportCapabilities get _capabilities => ChartExportCapabilities.evaluate(
    formats: widget.formats,
    config: widget.config,
    jsonConfig: widget.jsonConfig,
    rows: widget.rows,
    boundaryKey: _boundaryKey,
  );

  Future<void> _runExport(ChartExportFormat format) async {
    setState(() {
      _exporting = format;
      _lastBatchResult = null;
      _lastArchiveFile = null;
      _lastDeliveryResult = null;
      _lastArchiveDeliveryResult = null;
      _lastDeliveryBatchResult = null;
      _lastJobResult = null;
      _lastControlError = null;
      _activeJobProgress = null;
      _cancelRequested = false;
    });
    _callSafely(() => widget.onStarted?.call(format));

    try {
      final jobOptions = _jobOptionsFor(
        [format],
        deliverExports: widget.deliveryAdapter != null,
        onProgress: widget.onExportJobProgress,
        onExportBatchReady: (batch) =>
            _copyTextResultsToClipboard(batch.results),
        forwardBatchProgress: false,
        forwardDeliveryBatchProgress: false,
      );
      final plan = jobOptions.buildPlan();
      _callSafely(() => widget.onExportJobPlan?.call(plan));

      final jobResult = await _runJob(jobOptions);
      if (!mounted) return;

      final result = _resultFor(jobResult.exportBatch, format);
      final delivery = _firstDelivery(jobResult.exportDelivery);
      setState(() {
        _lastResult = result;
        _lastDeliveryResult = delivery;
        _lastJobResult = jobResult;
        _exporting = null;
        _activeJobProgress = null;
        _cancelRequested = false;
      });
      _callSafely(() => widget.onExportJobResult?.call(jobResult));
      if (result != null) {
        _callSafely(() => widget.onResult?.call(result));
      }
      if (delivery != null) {
        _callSafely(() => widget.onDeliveryResult?.call(delivery));
      }
    } catch (error, stackTrace) {
      _captureControlError(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _exporting = null;
        _activeJobProgress = null;
        _cancelRequested = false;
      });
    }
  }

  Future<void> _runBatchExport(List<ChartExportFormat> formats) async {
    setState(() {
      _exportingBatch = true;
      _lastResult = null;
      _lastBatchResult = null;
      _lastArchiveFile = null;
      _lastDeliveryResult = null;
      _lastArchiveDeliveryResult = null;
      _lastDeliveryBatchResult = null;
      _lastJobResult = null;
      _lastControlError = null;
      _activeJobProgress = null;
      _cancelRequested = false;
    });
    final resolvedFormats = List<ChartExportFormat>.unmodifiable(formats);
    _callSafely(() => widget.onBatchStarted?.call(resolvedFormats));

    try {
      final jobOptions = _jobOptionsFor(
        resolvedFormats,
        deliverExports: widget.deliveryAdapter != null,
        onProgress: widget.onBatchJobProgress,
        onExportBatchReady: (batch) =>
            _copyTextResultsToClipboard(batch.results),
      );
      final plan = jobOptions.buildPlan();
      _callSafely(() => widget.onBatchJobPlan?.call(plan));

      final jobResult = await _runJob(jobOptions);
      if (!mounted) return;

      setState(() {
        _lastBatchResult = jobResult.exportBatch;
        _lastDeliveryBatchResult = jobResult.exportDelivery;
        _lastJobResult = jobResult;
        _exportingBatch = false;
        _activeJobProgress = null;
        _cancelRequested = false;
      });
      _callSafely(() => widget.onBatchJobResult?.call(jobResult));
      for (final result in jobResult.exportBatch.results) {
        _callSafely(() => widget.onResult?.call(result));
      }
      _callSafely(() => widget.onBatchResult?.call(jobResult.exportBatch));
      final delivery = jobResult.exportDelivery;
      if (delivery != null) {
        _callSafely(() => widget.onDeliveryBatchResult?.call(delivery));
      }
    } catch (error, stackTrace) {
      _captureControlError(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _exportingBatch = false;
        _activeJobProgress = null;
        _cancelRequested = false;
      });
    }
  }

  Future<void> _runArchiveExport(List<ChartExportFormat> formats) async {
    setState(() {
      _exportingArchive = true;
      _lastResult = null;
      _lastBatchResult = null;
      _lastArchiveFile = null;
      _lastDeliveryResult = null;
      _lastArchiveDeliveryResult = null;
      _lastDeliveryBatchResult = null;
      _lastJobResult = null;
      _lastControlError = null;
      _activeJobProgress = null;
      _cancelRequested = false;
    });
    final resolvedFormats = List<ChartExportFormat>.unmodifiable(formats);
    _callSafely(() => widget.onArchiveStarted?.call(resolvedFormats));
    _callSafely(() => widget.onBatchStarted?.call(resolvedFormats));

    try {
      final jobOptions = _jobOptionsFor(
        resolvedFormats,
        createArchive: true,
        deliverArchive: widget.deliveryAdapter != null,
        onProgress: widget.onArchiveJobProgress,
      );
      final plan = jobOptions.buildPlan();
      _callSafely(() => widget.onArchiveJobPlan?.call(plan));

      final jobResult = await _runJob(jobOptions);
      if (!mounted) return;

      setState(() {
        _lastBatchResult = jobResult.exportBatch;
        _lastArchiveFile = jobResult.archive;
        _lastArchiveDeliveryResult = jobResult.archiveDelivery;
        _lastJobResult = jobResult;
        _exportingArchive = false;
        _activeJobProgress = null;
        _cancelRequested = false;
      });
      _callSafely(() => widget.onArchiveJobResult?.call(jobResult));
      for (final result in jobResult.exportBatch.results) {
        _callSafely(() => widget.onResult?.call(result));
      }
      _callSafely(() => widget.onBatchResult?.call(jobResult.exportBatch));
      final archive = jobResult.archive;
      if (archive != null) {
        _callSafely(() => widget.onArchiveResult?.call(archive));
      }
      final delivery = jobResult.archiveDelivery;
      if (delivery != null) {
        _callSafely(() => widget.onArchiveDeliveryResult?.call(delivery));
      }
    } catch (error, stackTrace) {
      _captureControlError(error, stackTrace);
      if (!mounted) return;
      setState(() {
        _exportingArchive = false;
        _activeJobProgress = null;
        _cancelRequested = false;
      });
    }
  }

  ChartExportJobOptions _jobOptionsFor(
    List<ChartExportFormat> formats, {
    bool deliverExports = false,
    bool createArchive = false,
    bool deliverArchive = false,
    ChartExportJobProgressHandler? onProgress,
    ChartExportBatchReadyHandler? onExportBatchReady,
    bool forwardBatchProgress = true,
    bool forwardDeliveryBatchProgress = true,
  }) {
    return ChartExportJobOptions(
      formats: formats,
      config: widget.config,
      jsonConfig: widget.jsonConfig,
      rows: widget.rows,
      boundaryKey: _boundaryKey,
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
      cancellationToken: widget.cancellationToken,
      preflightPolicy: widget.preflightPolicy,
      stopBatchOnFirstFailure: widget.stopBatchOnFirstFailure,
      stopDeliveryOnFirstFailure: widget.stopDeliveryBatchOnFirstFailure,
      deliveryAdapter: widget.deliveryAdapter,
      deliverExports: deliverExports,
      createArchive: createArchive,
      deliverArchive: deliverArchive,
      archiveFilename: widget.archiveFilename ?? widget.filename,
      includeArchiveManifest: widget.includeArchiveManifest,
      archiveManifestFilename: widget.archiveManifestFilename,
      onExportBatchReady: onExportBatchReady,
      onExportProgress: forwardBatchProgress
          ? _guardBatchProgress(widget.onBatchProgress)
          : null,
      onDeliveryProgress: forwardDeliveryBatchProgress
          ? _guardDeliveryBatchProgress(widget.onDeliveryBatchProgress)
          : null,
      onProgress: _guardJobProgress(onProgress),
    );
  }

  ChartExportResult? _resultFor(
    ChartExportBatchResult batch,
    ChartExportFormat format,
  ) {
    return batch.resultFor(format) ??
        (batch.results.isEmpty ? null : batch.results.first);
  }

  ChartExportJobController _activateJobController() {
    final controller = ChartExportJobController(
      cancellationToken: widget.cancellationToken,
    );
    _activeJobController = controller;
    return controller;
  }

  Future<ChartExportJobResult> _runJob(ChartExportJobOptions options) async {
    final controller = _activateJobController();
    try {
      return await controller.run(options);
    } finally {
      _clearActiveJobController(controller);
    }
  }

  void _clearActiveJobController(ChartExportJobController controller) {
    if (_activeJobController == controller) {
      _activeJobController = null;
    }
  }

  void _cancelActiveJob() {
    final controller = _activeJobController;
    if (controller == null || controller.isCancelled) return;
    controller.cancel(widget.cancelExportReason);
    setState(() {
      _cancelRequested = true;
    });
  }

  ChartExportDeliveryResult? _firstDelivery(
    ChartExportDeliveryBatchResult? batch,
  ) {
    if (batch == null || batch.results.isEmpty) return null;
    return batch.results.first;
  }

  Future<void> _copyTextResultsToClipboard(
    Iterable<ChartExportResult> results,
  ) async {
    if (!widget.copyTextExportsToClipboard) return;
    final textResults = [
      for (final result in results)
        if (result.success && result.text != null) result,
    ];
    if (textResults.isEmpty) return;

    final clipboardText = textResults.length == 1
        ? textResults.single.text!
        : textResults
              .map((result) => '--- ${result.filename} ---\n${result.text!}')
              .join('\n\n');
    try {
      await Clipboard.setData(ClipboardData(text: clipboardText));
    } catch (error) {
      debugPrint('ChartExportControls clipboard error: $error');
    }
  }

  ChartExportBatchProgressHandler? _guardBatchProgress(
    ChartExportBatchProgressHandler? handler,
  ) {
    if (handler == null) return null;
    return (progress) => _callSafely(() => handler(progress));
  }

  ChartExportDeliveryBatchProgressHandler? _guardDeliveryBatchProgress(
    ChartExportDeliveryBatchProgressHandler? handler,
  ) {
    if (handler == null) return null;
    return (progress) => _callSafely(() => handler(progress));
  }

  ChartExportJobProgressHandler _guardJobProgress(
    ChartExportJobProgressHandler? handler,
  ) {
    return (progress) {
      if (mounted) {
        setState(() {
          _activeJobProgress = progress;
        });
      }
      if (handler != null) {
        _callSafely(() => handler(progress));
      }
    };
  }

  void _callSafely(void Function() callback) {
    try {
      callback();
    } catch (error, stackTrace) {
      _captureControlError(error, stackTrace);
      if (mounted) setState(() {});
    }
  }

  void _captureControlError(Object error, StackTrace stackTrace) {
    _lastControlError = error;
    debugPrint('ChartExportControls callback error: $error');
    _notifyError(error, stackTrace);
  }

  void _notifyError(Object error, StackTrace stackTrace) {
    final handler = widget.onError;
    if (handler == null) return;
    try {
      handler(error, stackTrace);
    } catch (handlerError) {
      debugPrint('ChartExportControls onError callback error: $handlerError');
    }
  }

  String? get _statusText {
    final exporting = _exporting;
    if (_cancelRequested) return 'Cancelling export...';
    if (exporting != null) {
      return _activeProgressText('Exporting ${_labelFor(exporting)}...');
    }
    if (_exportingBatch) {
      return _activeProgressText('Exporting ${widget.batchExportLabel}...');
    }
    if (_exportingArchive) {
      return _activeProgressText('Exporting ${widget.archiveExportLabel}...');
    }

    final controlError = _lastControlError;
    if (controlError != null) {
      return 'Export control error: $controlError';
    }

    final jobResult = _lastJobResult;
    if (jobResult != null && jobResult.preflightBlocked) {
      return 'Export blocked: ${jobResult.primaryIssue ?? 'preflight failed'}';
    }

    final archiveDelivery = _lastArchiveDeliveryResult;
    if (archiveDelivery != null) {
      if (!archiveDelivery.success) {
        return 'Archive delivery failed: ${archiveDelivery.errorText ?? 'unknown error'}';
      }
      final issueText = _archiveIssueSuffix;
      return '${archiveDelivery.filename ?? 'Archive'} delivered '
          '(${_formatBytes(archiveDelivery.sizeBytes)})$issueText';
    }

    final deliveryBatch = _lastDeliveryBatchResult;
    if (deliveryBatch != null) {
      return deliveryBatch.summaryText();
    }

    final deliveryResult = _lastDeliveryResult;
    if (deliveryResult != null) {
      if (!deliveryResult.success) {
        return 'Delivery failed: ${deliveryResult.errorText ?? 'unknown error'}';
      }
      return '${deliveryResult.filename ?? 'Export'} delivered '
          '(${_formatBytes(deliveryResult.sizeBytes)})';
    }

    final archiveFile = _lastArchiveFile;
    if (archiveFile != null) {
      return '${archiveFile.filename} ready '
          '(${_formatBytes(archiveFile.sizeBytes)})$_archiveIssueSuffix';
    }

    final batchResult = _lastBatchResult;
    if (batchResult != null) {
      return batchResult.summaryText();
    }

    final result = _lastResult;
    if (result == null) return _preflightStatusText;
    if (!result.success) {
      return 'Export failed: ${result.error ?? result.format.name}';
    }
    return '${result.filename} ready (${_formatBytes(result.sizeBytes)})';
  }

  String? get _preflightStatusText {
    if (!widget.showPreflightDiagnostics || _busy) return null;
    if (widget.formats.isEmpty) {
      return 'Export unavailable: no formats configured.';
    }

    final plan = _diagnosticPreflightPlan;
    if (plan.canRun) return null;

    final issue = plan.blockers.isNotEmpty
        ? plan.blockers.first.message
        : plan.diagnosticsText();
    if (issue.isEmpty) return 'Export unavailable.';
    return 'Export unavailable: $issue';
  }

  ChartExportJobPlan get _diagnosticPreflightPlan {
    return ChartExportJobOptions(
      formats: widget.formats,
      config: widget.config,
      jsonConfig: widget.jsonConfig,
      rows: widget.rows,
      boundaryKey: _boundaryKey,
      categoryLabels: widget.categoryLabels,
      filename: widget.filename,
      sheetName: widget.sheetName,
      delimiter: widget.delimiter,
      lineEnding: widget.lineEnding,
      pixelRatio: widget.pixelRatio,
      jpegQuality: widget.jpegQuality,
      jpegBackgroundColor: widget.jpegBackgroundColor,
      preflightPolicy: widget.preflightPolicy,
      skipUnavailable: true,
    ).buildPlan();
  }

  String _activeProgressText(String fallback) {
    final progress = _activeJobProgress;
    if (progress == null) return fallback;

    final message = progress.message.trim();
    final base = message.isEmpty ? fallback : message;
    if (progress.total <= 0) return base;
    return '$base (${progress.completed}/${progress.total})';
  }

  String get _archiveIssueSuffix {
    final batch = _lastBatchResult;
    if (batch == null || !batch.hasIssues) return '';

    final issues = <String>[];
    if (batch.failureCount > 0) {
      final plural = batch.failureCount == 1 ? '' : 's';
      issues.add('${batch.failureCount} export$plural failed');
    }
    if (batch.skippedUnavailableCount > 0) {
      final plural = batch.skippedUnavailableCount == 1 ? '' : 's';
      issues.add(
        '${batch.skippedUnavailableCount} unavailable format$plural skipped',
      );
    }
    if (batch.notRunCount > 0) {
      final plural = batch.notRunCount == 1 ? '' : 's';
      issues.add('${batch.notRunCount} export$plural not run');
    }

    return issues.isEmpty ? '' : '; ${issues.join(', ')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _labelFor(ChartExportFormat format) {
    return switch (format) {
      ChartExportFormat.csv => 'CSV',
      ChartExportFormat.xlsx => 'XLSX',
      ChartExportFormat.png => 'PNG',
      ChartExportFormat.jpeg => 'JPEG',
    };
  }

  IconData _iconFor(ChartExportFormat format) {
    return switch (format) {
      ChartExportFormat.csv => Icons.table_rows_outlined,
      ChartExportFormat.xlsx => Icons.grid_on_outlined,
      ChartExportFormat.png => Icons.image_outlined,
      ChartExportFormat.jpeg => Icons.photo_outlined,
    };
  }
}
