import 'dart:async';

import 'package:flutter/material.dart';

import 'base_config.dart';
import 'chart_export.dart';
import 'chart_export_archive.dart';
import 'chart_export_capability.dart';
import 'chart_export_delivery.dart';
import 'chart_export_filename.dart';
import 'chart_export_summary.dart';

typedef ChartExportJobProgressHandler =
    void Function(ChartExportJobProgress progress);
typedef ChartExportBatchReadyHandler =
    FutureOr<void> Function(ChartExportBatchResult batch);
typedef ChartExportJobCallbackErrorHandler =
    void Function(ChartExportJobCallbackError error);
typedef ChartExportJobEventHandler = void Function(ChartExportJobEvent event);

enum ChartExportJobStage { idle, exporting, archiving, delivering, completed }

enum ChartExportJobStatus { succeeded, completedWithIssues, failed, cancelled }

enum ChartExportJobEventType {
  planned,
  started,
  progress,
  blocked,
  exported,
  archived,
  delivered,
  cancelled,
  callbackError,
  completed,
}

enum ChartExportJobPreflightPolicy { failOnBlockers, warnOnly }

enum ChartExportJobPlanIssueSeverity { warning, blocker }

class ChartExportJobEvent {
  ChartExportJobEvent({
    required this.type,
    required this.stage,
    required this.message,
    DateTime? timestamp,
    this.completed,
    this.total,
    this.status,
    this.format,
    this.filename,
    Map<String, Object?> metadata = const {},
  }) : timestamp = (timestamp ?? DateTime.now()).toUtc(),
       metadata = Map.unmodifiable(metadata);

  final ChartExportJobEventType type;
  final ChartExportJobStage stage;
  final String message;
  final DateTime timestamp;
  final int? completed;
  final int? total;
  final ChartExportJobStatus? status;
  final ChartExportFormat? format;
  final String? filename;
  final Map<String, Object?> metadata;

  double? get fraction {
    final completedValue = completed;
    final totalValue = total;
    if (completedValue == null || totalValue == null) return null;
    if (totalValue <= 0) return 1;
    return completedValue / totalValue;
  }

  Map<String, Object?> toMetadataJson() {
    return {
      'type': type.name,
      'stage': stage.name,
      'message': message,
      'timestamp': timestamp.toUtc().toIso8601String(),
      if (completed != null) 'completed': completed,
      if (total != null) 'total': total,
      if (fraction != null) 'fraction': fraction,
      if (status != null) 'status': status!.name,
      if (format != null) 'format': format!.name,
      if (filename != null) 'filename': filename,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

class ChartExportJobPlanIssue {
  const ChartExportJobPlanIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.requestIndex,
    this.format,
  });

  final String code;
  final String message;
  final ChartExportJobPlanIssueSeverity severity;
  final int? requestIndex;
  final ChartExportFormat? format;

  bool get isWarning => severity == ChartExportJobPlanIssueSeverity.warning;

  bool get isBlocker => severity == ChartExportJobPlanIssueSeverity.blocker;

  Map<String, Object?> toMetadataJson() {
    return {
      'code': code,
      'message': message,
      'severity': severity.name,
      if (requestIndex != null) 'requestIndex': requestIndex,
      if (format != null) 'format': format!.name,
    };
  }

  @override
  String toString() => message;
}

class ChartExportJobTiming {
  ChartExportJobTiming({
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    Map<ChartExportJobStage, Duration> stageDurations = const {},
  }) : stageDurations = Map.unmodifiable(stageDurations);

  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final Map<ChartExportJobStage, Duration> stageDurations;

  int get durationMicros => duration.inMicroseconds;

  double get durationMs => duration.inMicroseconds / 1000;

  Duration? stageDuration(ChartExportJobStage stage) => stageDurations[stage];

  ChartExportJobStage? get slowestStage {
    ChartExportJobStage? stage;
    Duration? slowest;
    for (final entry in stageDurations.entries) {
      if (slowest == null || entry.value > slowest) {
        stage = entry.key;
        slowest = entry.value;
      }
    }
    return stage;
  }

  Duration? get slowestStageDuration {
    final stage = slowestStage;
    return stage == null ? null : stageDurations[stage];
  }

  String summaryText() {
    final parts = <String>['job ${_formatDuration(duration)}'];
    final stage = slowestStage;
    final stageDuration = slowestStageDuration;
    if (stage != null && stageDuration != null) {
      parts.add('${stage.name} ${_formatDuration(stageDuration)}');
    }
    return parts.join('; ');
  }

  Map<String, Object?> toMetadataJson() {
    return {
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toUtc().toIso8601String(),
      'durationMicros': durationMicros,
      'durationMs': durationMs,
      if (slowestStage != null) 'slowestStage': slowestStage!.name,
      if (slowestStageDuration != null)
        'slowestStageDurationMicros': slowestStageDuration!.inMicroseconds,
      if (slowestStageDuration != null)
        'slowestStageDurationMs': slowestStageDuration!.inMicroseconds / 1000,
      'stageDurationsMicros': {
        for (final entry in stageDurations.entries)
          entry.key.name: entry.value.inMicroseconds,
      },
      'stageDurationsMs': {
        for (final entry in stageDurations.entries)
          entry.key.name: entry.value.inMicroseconds / 1000,
      },
    };
  }
}

class ChartExportJobCallbackError {
  const ChartExportJobCallbackError({
    required this.callbackName,
    required this.error,
    required this.stackTrace,
    this.stage,
  });

  final String callbackName;
  final Object error;
  final StackTrace stackTrace;
  final ChartExportJobStage? stage;

  String get message => 'Callback $callbackName failed: $error';

  Map<String, Object?> toMetadataJson({bool includeStackTrace = false}) {
    return {
      'callbackName': callbackName,
      if (stage != null) 'stage': stage!.name,
      'error': error.toString(),
      'message': message,
      if (includeStackTrace) 'stackTrace': stackTrace.toString(),
    };
  }

  @override
  String toString() => message;
}

class ChartExportJobOptions {
  ChartExportJobOptions({
    Iterable<ChartExportFormat> formats = ChartExportFormat.values,
    Iterable<ChartExportRequest>? requests,
    this.config,
    this.jsonConfig,
    this.rows,
    this.boundaryKey,
    this.categoryLabels,
    this.filename = ChartExportFilename.defaultFallback,
    this.sheetName = 'Chart Data',
    this.delimiter = ',',
    this.lineEnding = '\r\n',
    this.pixelRatio = 2.0,
    this.jpegQuality = 90,
    this.jpegBackgroundColor = Colors.white,
    this.exportTimeout,
    this.deliveryTimeout,
    this.cancellationToken,
    this.stopBatchOnFirstFailure = false,
    this.skipUnavailable = false,
    this.stopDeliveryOnFirstFailure = false,
    this.deliveryAdapter,
    this.deliverExports = false,
    this.createArchive = false,
    this.deliverArchive = false,
    this.archiveFilename,
    this.includeArchiveManifest = true,
    this.archiveManifestFilename = ChartExportArchive.defaultManifestFilename,
    this.preflightPolicy = ChartExportJobPreflightPolicy.failOnBlockers,
    this.continueOnCallbackError = true,
    this.onExportBatchReady,
    this.onExportProgress,
    this.onDeliveryProgress,
    this.onProgress,
    this.onCallbackError,
    this.onEvent,
  }) : formats = List.unmodifiable(formats),
       requests = requests == null ? null : List.unmodifiable(requests);

  final List<ChartExportFormat> formats;
  final List<ChartExportRequest>? requests;
  final BaseChartConfig? config;
  final Map<String, dynamic>? jsonConfig;
  final List<List<Object?>>? rows;
  final GlobalKey? boundaryKey;
  final List<String>? categoryLabels;
  final String? filename;
  final String sheetName;
  final String delimiter;
  final String lineEnding;
  final double pixelRatio;
  final int jpegQuality;
  final Color jpegBackgroundColor;
  final Duration? exportTimeout;
  final Duration? deliveryTimeout;
  final ChartExportCancellationToken? cancellationToken;
  final bool stopBatchOnFirstFailure;
  final bool skipUnavailable;
  final bool stopDeliveryOnFirstFailure;
  final ChartExportDeliveryAdapter? deliveryAdapter;
  final bool deliverExports;
  final bool createArchive;
  final bool deliverArchive;
  final String? archiveFilename;
  final bool includeArchiveManifest;
  final String archiveManifestFilename;
  final ChartExportJobPreflightPolicy preflightPolicy;
  final bool continueOnCallbackError;
  final ChartExportBatchReadyHandler? onExportBatchReady;
  final ChartExportBatchProgressHandler? onExportProgress;
  final ChartExportDeliveryBatchProgressHandler? onDeliveryProgress;
  final ChartExportJobProgressHandler? onProgress;
  final ChartExportJobCallbackErrorHandler? onCallbackError;
  final ChartExportJobEventHandler? onEvent;

  bool get hasDeliveryAdapter => deliveryAdapter != null;

  bool get shouldBuildArchive => createArchive || deliverArchive;

  bool get shouldFailOnPreflightBlockers =>
      preflightPolicy == ChartExportJobPreflightPolicy.failOnBlockers;

  List<ChartExportRequest> buildRequests() {
    final explicitRequests = requests;
    if (explicitRequests != null) return explicitRequests;

    return List.unmodifiable(
      formats.map(
        (format) => ChartExportRequest(
          format: format,
          config: config,
          jsonConfig: jsonConfig,
          rows: rows,
          boundaryKey: boundaryKey,
          categoryLabels: categoryLabels,
          filename: filename,
          sheetName: sheetName,
          delimiter: delimiter,
          lineEnding: lineEnding,
          pixelRatio: pixelRatio,
          jpegQuality: jpegQuality,
          jpegBackgroundColor: jpegBackgroundColor,
        ),
      ),
    );
  }

  ChartExportBatchOptions exportBatchOptions({
    ChartExportCancellationToken? effectiveCancellationToken,
  }) {
    return ChartExportBatchOptions(
      stopOnFirstFailure: stopBatchOnFirstFailure,
      skipUnavailable: skipUnavailable,
      continueOnProgressError: continueOnCallbackError,
      timeout: exportTimeout,
      cancellationToken: effectiveCancellationToken ?? cancellationToken,
      onProgress: onExportProgress,
    );
  }

  ChartExportDeliveryBatchOptions deliveryBatchOptions({
    ChartExportCancellationToken? effectiveCancellationToken,
    ChartExportDeliveryBatchProgressHandler? onProgress,
  }) {
    return ChartExportDeliveryBatchOptions(
      stopOnFirstFailure: stopDeliveryOnFirstFailure,
      continueOnProgressError: continueOnCallbackError,
      timeout: deliveryTimeout,
      cancellationToken: effectiveCancellationToken ?? cancellationToken,
      onProgress: onProgress ?? onDeliveryProgress,
    );
  }

  ChartExportJobPlan buildPlan() => ChartExportJobPlan.fromOptions(this);
}

class ChartExportJobPlannedRequest {
  const ChartExportJobPlannedRequest({
    required this.index,
    required this.request,
    required this.capability,
  });

  final int index;
  final ChartExportRequest request;
  final ChartExportCapability capability;

  ChartExportFormat get format => request.format;

  String get filename => request.resolvedFilename;

  bool get canExport => capability.canExport;

  bool get isUnavailable => capability.isUnavailable;

  Map<String, Object?> toMetadataJson() {
    return {
      'index': index,
      'format': format.name,
      'filename': filename,
      'canExport': canExport,
      if (capability.disabledReason != null)
        'disabledReason': capability.disabledReason,
    };
  }
}

class ChartExportJobPlan {
  ChartExportJobPlan({
    required Iterable<ChartExportJobPlannedRequest> plannedRequests,
    required this.skipUnavailable,
    required this.deliverExports,
    required this.createArchive,
    required this.deliverArchive,
    required this.hasDeliveryAdapter,
  }) : plannedRequests = List.unmodifiable(plannedRequests);

  factory ChartExportJobPlan.fromOptions(ChartExportJobOptions options) {
    final requests = options.buildRequests();
    return ChartExportJobPlan(
      plannedRequests: [
        for (var index = 0; index < requests.length; index++)
          ChartExportJobPlannedRequest(
            index: index,
            request: requests[index],
            capability: ChartExporter.capabilityForRequest(requests[index]),
          ),
      ],
      skipUnavailable: options.skipUnavailable,
      deliverExports: options.deliverExports,
      createArchive: options.createArchive,
      deliverArchive: options.deliverArchive,
      hasDeliveryAdapter: options.hasDeliveryAdapter,
    );
  }

  final List<ChartExportJobPlannedRequest> plannedRequests;
  final bool skipUnavailable;
  final bool deliverExports;
  final bool createArchive;
  final bool deliverArchive;
  final bool hasDeliveryAdapter;

  List<ChartExportRequest> get requests =>
      List.unmodifiable(plannedRequests.map((item) => item.request));

  List<ChartExportJobPlannedRequest> get available =>
      List.unmodifiable(plannedRequests.where((item) => item.canExport));

  List<ChartExportJobPlannedRequest> get unavailable =>
      List.unmodifiable(plannedRequests.where((item) => item.isUnavailable));

  List<ChartExportJobPlannedRequest> get requestsToRun =>
      skipUnavailable ? available : List.unmodifiable(plannedRequests);

  List<ChartExportJobPlannedRequest> get skippedUnavailable =>
      skipUnavailable ? unavailable : const [];

  List<ChartExportFormat> get formats =>
      List.unmodifiable(plannedRequests.map((item) => item.format));

  List<ChartExportFormat> get exportableFormats =>
      List.unmodifiable(available.map((item) => item.format));

  int get requestedCount => plannedRequests.length;

  int get availableCount => available.length;

  int get unavailableCount => unavailable.length;

  int get runCount => requestsToRun.length;

  int get skippedUnavailableCount => skippedUnavailable.length;

  bool get hasRequests => plannedRequests.isNotEmpty;

  bool get hasRunnableExports => requestsToRun.isNotEmpty;

  bool get hasUnavailable => unavailableCount > 0;

  bool get willAttemptUnavailable => hasUnavailable && !skipUnavailable;

  bool get willCreateArchive => createArchive || deliverArchive;

  bool get willDeliverExports => deliverExports && hasDeliveryAdapter;

  bool get willDeliverArchive => deliverArchive && hasDeliveryAdapter;

  int get estimatedDeliveryCount {
    var count = 0;
    if (willDeliverExports) count += runCount;
    if (willDeliverArchive) count += 1;
    return count;
  }

  bool get hasIssues => issues.isNotEmpty;

  bool get hasWarnings => warnings.isNotEmpty;

  bool get hasBlockers => blockers.isNotEmpty;

  bool get canRun => !hasBlockers;

  List<ChartExportJobPlanIssue> get warningIssues =>
      List.unmodifiable(issues.where((issue) => issue.isWarning));

  List<ChartExportJobPlanIssue> get blockers =>
      List.unmodifiable(issues.where((issue) => issue.isBlocker));

  int get issueCount => issues.length;

  int get warningCount => warningIssues.length;

  int get blockerCount => blockers.length;

  List<ChartExportJobPlanIssue> get issues {
    final diagnostics = <ChartExportJobPlanIssue>[];
    if (!hasRequests) {
      diagnostics.add(
        const ChartExportJobPlanIssue(
          code: 'no_requests',
          severity: ChartExportJobPlanIssueSeverity.blocker,
          message: 'No export requests were configured.',
        ),
      );
    }
    if (hasRequests && !hasRunnableExports) {
      diagnostics.add(
        const ChartExportJobPlanIssue(
          code: 'no_runnable_exports',
          severity: ChartExportJobPlanIssueSeverity.blocker,
          message:
              'No export requests can run because every configured format is unavailable.',
        ),
      );
    }
    if (willAttemptUnavailable) {
      diagnostics.add(
        ChartExportJobPlanIssue(
          code: 'unavailable_format_will_run',
          severity: ChartExportJobPlanIssueSeverity.warning,
          message:
              '$unavailableCount unavailable ${_plural('format', unavailableCount)} '
              'will be attempted and may fail.',
        ),
      );
    }
    if (deliverExports && !hasDeliveryAdapter) {
      diagnostics.add(
        const ChartExportJobPlanIssue(
          code: 'export_delivery_missing_adapter',
          severity: ChartExportJobPlanIssueSeverity.warning,
          message:
              'Export delivery is enabled but no delivery adapter was provided.',
        ),
      );
    }
    if (deliverArchive && !hasDeliveryAdapter) {
      diagnostics.add(
        const ChartExportJobPlanIssue(
          code: 'archive_delivery_missing_adapter',
          severity: ChartExportJobPlanIssueSeverity.warning,
          message:
              'Archive delivery is enabled but no delivery adapter was provided.',
        ),
      );
    }
    return List.unmodifiable(diagnostics);
  }

  List<String> get warnings {
    return List.unmodifiable(issues.map((issue) => issue.message));
  }

  String summaryText() {
    final parts = <String>[
      '$requestedCount ${_plural('export', requestedCount)} planned',
    ];

    if (availableCount > 0) {
      parts.add('$availableCount available');
    }
    if (skippedUnavailableCount > 0) {
      parts.add('$skippedUnavailableCount unavailable skipped');
    } else if (willAttemptUnavailable) {
      parts.add('$unavailableCount unavailable will run');
    }
    if (willCreateArchive) {
      parts.add('archive will be created');
    }
    if (willDeliverExports || willDeliverArchive) {
      parts.add(
        '$estimatedDeliveryCount ${_plural('delivery', estimatedDeliveryCount)} planned',
      );
    }

    return parts.join('; ');
  }

  String diagnosticsText() => warnings.join('\n');

  Map<String, Object?> toMetadataJson() {
    return {
      'requestedCount': requestedCount,
      'availableCount': availableCount,
      'unavailableCount': unavailableCount,
      'runCount': runCount,
      'skippedUnavailableCount': skippedUnavailableCount,
      'skipUnavailable': skipUnavailable,
      'deliverExports': deliverExports,
      'createArchive': createArchive,
      'deliverArchive': deliverArchive,
      'hasDeliveryAdapter': hasDeliveryAdapter,
      'willCreateArchive': willCreateArchive,
      'willDeliverExports': willDeliverExports,
      'willDeliverArchive': willDeliverArchive,
      'estimatedDeliveryCount': estimatedDeliveryCount,
      'canRun': canRun,
      'hasIssues': hasIssues,
      'hasBlockers': hasBlockers,
      'issueCount': issueCount,
      'warningCount': warningCount,
      'blockerCount': blockerCount,
      if (issues.isNotEmpty)
        'issues': [for (final issue in issues) issue.toMetadataJson()],
      if (blockers.isNotEmpty)
        'blockers': [for (final issue in blockers) issue.toMetadataJson()],
      if (warnings.isNotEmpty) 'warnings': warnings,
      'formats': [for (final format in formats) format.name],
      'exportableFormats': [
        for (final format in exportableFormats) format.name,
      ],
      'requests': [
        for (final request in plannedRequests) request.toMetadataJson(),
      ],
      if (skippedUnavailable.isNotEmpty)
        'skippedUnavailable': [
          for (final request in skippedUnavailable) request.toMetadataJson(),
        ],
    };
  }
}

class ChartExportJobProgress {
  const ChartExportJobProgress({
    required this.stage,
    required this.completed,
    required this.total,
    required this.message,
    this.exportProgress,
    this.deliveryProgress,
  });

  final ChartExportJobStage stage;
  final int completed;
  final int total;
  final String message;
  final ChartExportBatchProgress? exportProgress;
  final ChartExportDeliveryBatchProgress? deliveryProgress;

  int get remaining => total - completed < 0 ? 0 : total - completed;

  double get fraction => total <= 0 ? 1 : completed / total;

  bool get isComplete => completed >= total;

  Map<String, Object?> toMetadataJson({bool includePayload = false}) {
    return {
      'stage': stage.name,
      'completed': completed,
      'total': total,
      'remaining': remaining,
      'fraction': fraction,
      'isComplete': isComplete,
      'message': message,
      if (exportProgress != null)
        'exportProgress': exportProgress!.toMetadataJson(
          includePayload: includePayload,
        ),
      if (deliveryProgress != null)
        'deliveryProgress': deliveryProgress!.toMetadataJson(
          includePayload: includePayload,
        ),
    };
  }
}

class ChartExportJobResult {
  ChartExportJobResult({
    required this.exportBatch,
    this.plan,
    this.exportDelivery,
    this.archive,
    this.archiveDelivery,
    this.timing,
    this.preflightBlocked = false,
    this.cancellationReason,
    Iterable<ChartExportJobEvent> events = const [],
    Iterable<String> warnings = const [],
  }) : events = List.unmodifiable(events),
       warnings = List.unmodifiable(warnings);

  final ChartExportBatchResult exportBatch;
  final ChartExportJobPlan? plan;
  final ChartExportDeliveryBatchResult? exportDelivery;
  final ChartExportFile? archive;
  final ChartExportDeliveryResult? archiveDelivery;
  final ChartExportJobTiming? timing;
  final bool preflightBlocked;
  final String? cancellationReason;
  final List<ChartExportJobEvent> events;
  final List<String> warnings;

  bool get completed =>
      !preflightBlocked &&
      exportBatch.success &&
      (exportDelivery?.success ?? true) &&
      (archiveDelivery?.success ?? true);

  bool get success => status == ChartExportJobStatus.succeeded;

  ChartExportJobStatus get status {
    if (isCancelled) return ChartExportJobStatus.cancelled;
    if (preflightBlocked) return ChartExportJobStatus.failed;
    if (!completed) return ChartExportJobStatus.failed;
    if (hasIssues) return ChartExportJobStatus.completedWithIssues;
    return ChartExportJobStatus.succeeded;
  }

  bool get isSucceeded => status == ChartExportJobStatus.succeeded;

  bool get isCompletedWithIssues =>
      status == ChartExportJobStatus.completedWithIssues;

  bool get isFailed => status == ChartExportJobStatus.failed;

  bool get isCancelled => cancellationReason != null;

  String get statusText {
    return switch (status) {
      ChartExportJobStatus.succeeded => 'succeeded',
      ChartExportJobStatus.completedWithIssues => 'completed with issues',
      ChartExportJobStatus.failed => 'failed',
      ChartExportJobStatus.cancelled => 'cancelled',
    };
  }

  bool get hasOutput => exportBatch.hasOutput || archive != null;

  int get outputCount => exportBatch.outputCount + (archive == null ? 0 : 1);

  List<ChartExportResult> get successfulExports => exportBatch.successful;

  List<ChartExportResult> get failedExports => exportBatch.failed;

  List<ChartExportFile> get exportFiles =>
      ChartExportDelivery.filesFromBatch(exportBatch);

  List<ChartExportFile> get outputFiles {
    return List.unmodifiable([...exportFiles, ?archive]);
  }

  List<String> get outputFilenames =>
      List.unmodifiable(outputFiles.map((file) => file.filename));

  ChartExportResult? exportResultFor(ChartExportFormat format) {
    return exportBatch.resultFor(format);
  }

  ChartExportFile? exportFileFor(ChartExportFormat format) {
    for (final file in exportFiles) {
      if (file.format == format) return file;
    }
    return null;
  }

  ChartExportFile? outputFileNamed(String filename) {
    for (final file in outputFiles) {
      if (file.filename == filename) return file;
    }
    return null;
  }

  bool get hasEvents => events.isNotEmpty;

  List<ChartExportJobEvent> eventsOfType(ChartExportJobEventType type) {
    return List.unmodifiable(events.where((event) => event.type == type));
  }

  ChartExportJobEvent? get lastEvent => events.isEmpty ? null : events.last;

  Duration? get duration => timing?.duration;

  Map<ChartExportJobStage, Duration> get stageDurations =>
      timing?.stageDurations ?? const <ChartExportJobStage, Duration>{};

  Duration? stageDuration(ChartExportJobStage stage) {
    return timing?.stageDuration(stage);
  }

  int get issueCount {
    var count = exportBatch.issueCount + warnings.length;
    if (cancellationReason != null && !warnings.contains(cancellationReason)) {
      count++;
    }
    final delivery = exportDelivery;
    if (delivery != null) count += delivery.issueCount;
    final archiveResult = archiveDelivery;
    if (archiveResult != null && !archiveResult.success) count++;
    return count;
  }

  bool get hasIssues => issueCount > 0;

  List<String> get issueMessages {
    final messages = <String>[];
    void addIssue(String message) {
      final normalized = message.trim();
      if (normalized.isEmpty || messages.contains(normalized)) return;
      messages.add(normalized);
    }

    for (final warning in warnings) {
      addIssue(warning);
    }

    final cancelReason = cancellationReason;
    if (cancelReason != null) {
      addIssue(cancelReason);
    }

    for (final result in exportBatch.failed) {
      addIssue(
        'Export failed for ${result.filename}: '
        '${result.error ?? 'Unknown export error.'}',
      );
    }

    for (final skipped in exportBatch.skippedUnavailable) {
      addIssue(
        '${skipped.format.name} export skipped: '
        '${skipped.disabledReason ?? 'Format is unavailable.'}',
      );
    }

    if (exportBatch.notRunCount > 0) {
      addIssue(
        '${exportBatch.notRunCount} '
        '${_plural('export', exportBatch.notRunCount)} not run.',
      );
    }

    final delivery = exportDelivery;
    if (delivery != null) {
      for (final result in delivery.failed) {
        addIssue(
          'Delivery failed for ${result.filename ?? 'export file'}: '
          '${result.errorText ?? 'Unknown delivery error.'}',
        );
      }
    }

    final archiveResult = archiveDelivery;
    if (archiveResult != null && !archiveResult.success) {
      addIssue(
        'Archive delivery failed: '
        '${archiveResult.errorText ?? 'Unknown delivery error.'}',
      );
    }

    return List.unmodifiable(messages);
  }

  String? get primaryIssue =>
      issueMessages.isEmpty ? null : issueMessages.first;

  int get totalSizeBytes =>
      exportBatch.totalSizeBytes + (archive?.sizeBytes ?? 0);

  String summaryText({bool includeSize = true, bool includeTiming = false}) {
    final parts = <String>[exportBatch.summaryText(includeSize: includeSize)];

    final delivery = exportDelivery;
    if (delivery != null) {
      parts.add(delivery.summaryText(includeSize: includeSize));
    }

    final archiveFile = archive;
    if (archiveFile != null) {
      final size = includeSize
          ? ' (${_formatBytes(archiveFile.sizeBytes)})'
          : '';
      parts.add('${archiveFile.filename} archive ready$size');
    }

    final archiveResult = archiveDelivery;
    if (archiveResult != null) {
      if (archiveResult.success) {
        final size = includeSize
            ? ' (${_formatBytes(archiveResult.sizeBytes)})'
            : '';
        parts.add('${archiveResult.filename} archive delivered$size');
      } else {
        parts.add('Archive delivery failed: ${archiveResult.errorText}');
      }
    }

    parts.addAll(warnings);
    if (includeTiming && timing != null) {
      parts.add(timing!.summaryText());
    }
    return parts.join('; ');
  }

  Map<String, Object?> toMetadataJson({bool includePayload = false}) {
    return {
      'success': success,
      'status': status.name,
      'statusText': statusText,
      'completed': completed,
      'preflightBlocked': preflightBlocked,
      'cancelled': isCancelled,
      'failed': isFailed,
      'completedWithIssues': isCompletedWithIssues,
      'hasOutput': hasOutput,
      'outputCount': outputCount,
      'outputFilenames': outputFilenames,
      'hasIssues': hasIssues,
      'issueCount': issueCount,
      'totalSizeBytes': totalSizeBytes,
      if (timing != null) 'timing': timing!.toMetadataJson(),
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      if (events.isNotEmpty)
        'events': [for (final event in events) event.toMetadataJson()],
      if (primaryIssue != null) 'primaryIssue': primaryIssue,
      if (issueMessages.isNotEmpty) 'issues': issueMessages,
      if (warnings.isNotEmpty) 'warnings': warnings,
      if (plan != null) 'plan': plan!.toMetadataJson(),
      'exportBatch': exportBatch.toMetadataJson(includePayload: includePayload),
      if (exportDelivery != null)
        'exportDelivery': exportDelivery!.toMetadataJson(
          includePayload: includePayload,
        ),
      if (archive != null)
        'archive': archive!.toMetadataJson(includePayload: includePayload),
      if (archiveDelivery != null)
        'archiveDelivery': archiveDelivery!.toMetadataJson(
          includePayload: includePayload,
        ),
    };
  }
}

class ChartExportJobController {
  ChartExportJobController({ChartExportCancellationToken? cancellationToken})
    : cancellationToken = cancellationToken ?? ChartExportCancellationToken();

  final ChartExportCancellationToken cancellationToken;

  bool _isRunning = false;
  ChartExportCancellationToken? _activeCancellationToken;

  bool get isRunning => _isRunning;

  bool get isCancelled =>
      (_activeCancellationToken ?? cancellationToken).isCancelled;

  void cancel([String reason = 'Export job cancelled.']) {
    (_activeCancellationToken ?? cancellationToken).cancel(reason);
  }

  Future<ChartExportJobResult> run(ChartExportJobOptions options) async {
    if (_isRunning) {
      throw StateError('A chart export job is already running.');
    }

    _isRunning = true;
    final token = options.cancellationToken ?? cancellationToken;
    _activeCancellationToken = token;

    try {
      final jobStartedAt = DateTime.now().toUtc();
      final jobStopwatch = Stopwatch()..start();
      final stageDurations = <ChartExportJobStage, Duration>{};
      final warnings = <String>[];
      final events = <ChartExportJobEvent>[];
      final plan = options.buildPlan();
      _recordEvent(
        options,
        warnings,
        events,
        ChartExportJobEvent(
          type: ChartExportJobEventType.planned,
          stage: ChartExportJobStage.idle,
          message: plan.summaryText(),
          total: plan.requestedCount,
          metadata: {
            'canRun': plan.canRun,
            'issueCount': plan.issueCount,
            'warningCount': plan.warningCount,
            'blockerCount': plan.blockerCount,
          },
        ),
      );
      if (!plan.canRun) {
        for (final issue in plan.issues) {
          _addWarning(warnings, issue.message);
        }
      }
      if (!plan.canRun && options.shouldFailOnPreflightBlockers) {
        _recordEvent(
          options,
          warnings,
          events,
          ChartExportJobEvent(
            type: ChartExportJobEventType.blocked,
            stage: ChartExportJobStage.completed,
            message: plan.diagnosticsText(),
            completed: 0,
            total: plan.requestedCount,
            status: ChartExportJobStatus.failed,
            metadata: {
              'blockers': [
                for (final blocker in plan.blockers) blocker.toMetadataJson(),
              ],
            },
          ),
        );
        jobStopwatch.stop();
        final timing = ChartExportJobTiming(
          startedAt: jobStartedAt,
          endedAt: DateTime.now().toUtc(),
          duration: jobStopwatch.elapsed,
          stageDurations: stageDurations,
        );
        final result = ChartExportJobResult(
          exportBatch: ChartExportBatchResult(
            const [],
            skippedUnavailable: [
              for (final request in plan.skippedUnavailable) request.capability,
            ],
            requestedCount: plan.requestedCount,
          ),
          plan: plan,
          timing: timing,
          preflightBlocked: true,
          cancellationReason: _cancelled(token) ? token.reason : null,
          events: events,
          warnings: warnings,
        );
        _emit(
          options,
          warnings,
          ChartExportJobProgress(
            stage: ChartExportJobStage.completed,
            completed: 0,
            total: plan.requestedCount,
            message:
                'Export job blocked before running: '
                '${plan.diagnosticsText()}',
          ),
        );
        _recordEvent(
          options,
          warnings,
          events,
          ChartExportJobEvent(
            type: ChartExportJobEventType.completed,
            stage: ChartExportJobStage.completed,
            message: result.summaryText(),
            completed: 0,
            total: plan.requestedCount,
            status: result.status,
          ),
        );
        return ChartExportJobResult(
          exportBatch: result.exportBatch,
          plan: plan,
          timing: timing,
          preflightBlocked: true,
          cancellationReason: _cancelled(token) ? token.reason : null,
          events: events,
          warnings: warnings,
        );
      }
      final requests = plan.requests;
      _recordEvent(
        options,
        warnings,
        events,
        ChartExportJobEvent(
          type: ChartExportJobEventType.started,
          stage: ChartExportJobStage.exporting,
          message: 'Export job started.',
          completed: 0,
          total: requests.length,
        ),
      );
      final exportBatch = await _timedStage(
        stageDurations,
        ChartExportJobStage.exporting,
        () async {
          _emit(
            options,
            warnings,
            ChartExportJobProgress(
              stage: ChartExportJobStage.exporting,
              completed: 0,
              total: requests.length,
              message: plan.summaryText(),
            ),
          );

          final batch = await ChartExporter.exportAll(
            requests,
            options: ChartExportBatchOptions(
              stopOnFirstFailure: options.stopBatchOnFirstFailure,
              skipUnavailable: options.skipUnavailable,
              continueOnProgressError: options.continueOnCallbackError,
              timeout: options.exportTimeout,
              cancellationToken: token,
              onProgress: (progress) {
                _callCallback(
                  options,
                  warnings,
                  'onExportProgress',
                  ChartExportJobStage.exporting,
                  () => options.onExportProgress?.call(progress),
                );
                _emit(
                  options,
                  warnings,
                  ChartExportJobProgress(
                    stage: ChartExportJobStage.exporting,
                    completed: progress.completed,
                    total: progress.total,
                    message: progress.result.success
                        ? 'Exported ${progress.result.filename}.'
                        : 'Export failed for ${progress.result.filename}.',
                    exportProgress: progress,
                  ),
                );
              },
              onProgressError: (error, stackTrace, _) {
                _handleCallbackError(
                  options,
                  warnings,
                  'onExportProgress',
                  ChartExportJobStage.exporting,
                  error,
                  stackTrace,
                );
              },
            ),
          );

          _emit(
            options,
            warnings,
            ChartExportJobProgress(
              stage: ChartExportJobStage.exporting,
              completed: batch.results.length + batch.skippedUnavailableCount,
              total: batch.requestedCount,
              message: batch.summaryText(),
            ),
          );
          await _callAsyncCallback(
            options,
            warnings,
            'onExportBatchReady',
            ChartExportJobStage.exporting,
            () => options.onExportBatchReady?.call(batch),
          );
          return batch;
        },
      );
      _recordEvent(
        options,
        warnings,
        events,
        ChartExportJobEvent(
          type: ChartExportJobEventType.exported,
          stage: ChartExportJobStage.exporting,
          message: exportBatch.summaryText(),
          completed:
              exportBatch.results.length + exportBatch.skippedUnavailableCount,
          total: exportBatch.requestedCount,
          metadata: {
            'successCount': exportBatch.successCount,
            'failureCount': exportBatch.failureCount,
            'skippedUnavailableCount': exportBatch.skippedUnavailableCount,
            'notRunCount': exportBatch.notRunCount,
          },
        ),
      );

      ChartExportDeliveryBatchResult? exportDelivery;
      ChartExportFile? archive;
      ChartExportDeliveryResult? archiveDelivery;

      final adapter = options.deliveryAdapter;
      if (_cancelled(token)) {
        if (!exportBatch.hasFailures) {
          warnings.add(token.reason ?? 'Export job cancelled.');
        }
      } else if (options.deliverExports) {
        if (adapter == null) {
          warnings.add(
            'Export delivery skipped because no delivery adapter was provided.',
          );
        } else {
          final deliveryBatch = await _timedStage(
            stageDurations,
            ChartExportJobStage.delivering,
            () =>
                _deliverExports(options, exportBatch, adapter, token, warnings),
          );
          exportDelivery = deliveryBatch;
          _recordEvent(
            options,
            warnings,
            events,
            ChartExportJobEvent(
              type: ChartExportJobEventType.delivered,
              stage: ChartExportJobStage.delivering,
              message: deliveryBatch.summaryText(),
              completed: deliveryBatch.results.length,
              total: deliveryBatch.results.length,
              metadata: {
                'successCount': deliveryBatch.successCount,
                'failureCount': deliveryBatch.failureCount,
              },
            ),
          );
        }
      }

      if (!_cancelled(token) && options.shouldBuildArchive) {
        final archiveFile = _timedSyncStage(
          stageDurations,
          ChartExportJobStage.archiving,
          () {
            _emit(
              options,
              warnings,
              const ChartExportJobProgress(
                stage: ChartExportJobStage.archiving,
                completed: 0,
                total: 1,
                message: 'Creating export archive.',
              ),
            );
            final archiveFile = ChartExportArchive.exportBatchZip(
              exportBatch,
              filename:
                  options.archiveFilename ??
                  options.filename ??
                  ChartExportArchive.defaultExportFilename,
              includeManifest: options.includeArchiveManifest,
              manifestFilename: options.archiveManifestFilename,
            );
            _emit(
              options,
              warnings,
              ChartExportJobProgress(
                stage: ChartExportJobStage.archiving,
                completed: 1,
                total: 1,
                message: 'Archive ready: ${archiveFile.filename}.',
              ),
            );
            return archiveFile;
          },
        );
        archive = archiveFile;
        _recordEvent(
          options,
          warnings,
          events,
          ChartExportJobEvent(
            type: ChartExportJobEventType.archived,
            stage: ChartExportJobStage.archiving,
            message: 'Archive ready: ${archiveFile.filename}.',
            completed: 1,
            total: 1,
            filename: archiveFile.filename,
            metadata: {'sizeBytes': archiveFile.sizeBytes},
          ),
        );
      }

      if (!_cancelled(token) && options.deliverArchive) {
        if (adapter == null) {
          warnings.add(
            'Archive delivery skipped because no delivery adapter was provided.',
          );
        } else if (archive != null) {
          final archiveFile = archive;
          final delivery = await _timedStage(
            stageDurations,
            ChartExportJobStage.delivering,
            () async {
              _emit(
                options,
                warnings,
                ChartExportJobProgress(
                  stage: ChartExportJobStage.delivering,
                  completed: 0,
                  total: 1,
                  message: 'Delivering archive ${archiveFile.filename}.',
                ),
              );
              final delivery = await ChartExportDelivery.deliverFile(
                archiveFile,
                adapter,
                timeout: options.deliveryTimeout,
                cancellationToken: token,
              );
              _emit(
                options,
                warnings,
                ChartExportJobProgress(
                  stage: ChartExportJobStage.delivering,
                  completed: 1,
                  total: 1,
                  message: delivery.success
                      ? 'Archive delivered: ${archiveFile.filename}.'
                      : 'Archive delivery failed: ${delivery.errorText}.',
                ),
              );
              return delivery;
            },
          );
          archiveDelivery = delivery;
          _recordEvent(
            options,
            warnings,
            events,
            ChartExportJobEvent(
              type: ChartExportJobEventType.delivered,
              stage: ChartExportJobStage.delivering,
              message: delivery.success
                  ? 'Archive delivered: ${archiveFile.filename}.'
                  : 'Archive delivery failed: ${delivery.errorText}.',
              completed: 1,
              total: 1,
              filename: archiveFile.filename,
              metadata: delivery.toMetadataJson(),
            ),
          );
        }
      }

      if (_cancelled(token) && warnings.isEmpty && !exportBatch.hasFailures) {
        warnings.add(token.reason ?? 'Export job cancelled.');
      }
      if (_cancelled(token)) {
        _recordEvent(
          options,
          warnings,
          events,
          ChartExportJobEvent(
            type: ChartExportJobEventType.cancelled,
            stage: ChartExportJobStage.completed,
            message: token.reason ?? 'Export job cancelled.',
            status: ChartExportJobStatus.cancelled,
          ),
        );
      }

      jobStopwatch.stop();
      final timing = ChartExportJobTiming(
        startedAt: jobStartedAt,
        endedAt: DateTime.now().toUtc(),
        duration: jobStopwatch.elapsed,
        stageDurations: stageDurations,
      );
      final resultBeforeCompletedProgress = ChartExportJobResult(
        exportBatch: exportBatch,
        plan: plan,
        exportDelivery: exportDelivery,
        archive: archive,
        archiveDelivery: archiveDelivery,
        timing: timing,
        cancellationReason: _cancelled(token) ? token.reason : null,
        events: events,
        warnings: warnings,
      );
      _emit(
        options,
        warnings,
        ChartExportJobProgress(
          stage: ChartExportJobStage.completed,
          completed: 1,
          total: 1,
          message: resultBeforeCompletedProgress.summaryText(),
        ),
      );
      _recordEvent(
        options,
        warnings,
        events,
        ChartExportJobEvent(
          type: ChartExportJobEventType.completed,
          stage: ChartExportJobStage.completed,
          message: resultBeforeCompletedProgress.summaryText(),
          completed: 1,
          total: 1,
          status: resultBeforeCompletedProgress.status,
        ),
      );
      return ChartExportJobResult(
        exportBatch: exportBatch,
        plan: plan,
        exportDelivery: exportDelivery,
        archive: archive,
        archiveDelivery: archiveDelivery,
        timing: timing,
        cancellationReason: _cancelled(token) ? token.reason : null,
        events: events,
        warnings: warnings,
      );
    } finally {
      _activeCancellationToken = null;
      _isRunning = false;
    }
  }

  Future<ChartExportDeliveryBatchResult> _deliverExports(
    ChartExportJobOptions options,
    ChartExportBatchResult exportBatch,
    ChartExportDeliveryAdapter adapter,
    ChartExportCancellationToken token,
    List<String> warnings,
  ) {
    _emit(
      options,
      warnings,
      ChartExportJobProgress(
        stage: ChartExportJobStage.delivering,
        completed: 0,
        total: exportBatch.results.length,
        message:
            'Delivering ${exportBatch.results.length} '
            '${_plural('export file', exportBatch.results.length)}.',
      ),
    );

    return ChartExportDelivery.deliverBatch(
      exportBatch,
      adapter,
      timeout: options.deliveryTimeout,
      cancellationToken: token,
      batchOptions: ChartExportDeliveryBatchOptions(
        stopOnFirstFailure: options.stopDeliveryOnFirstFailure,
        continueOnProgressError: options.continueOnCallbackError,
        timeout: options.deliveryTimeout,
        cancellationToken: token,
        onProgress: (progress) {
          _callCallback(
            options,
            warnings,
            'onDeliveryProgress',
            ChartExportJobStage.delivering,
            () => options.onDeliveryProgress?.call(progress),
          );
          _emit(
            options,
            warnings,
            ChartExportJobProgress(
              stage: ChartExportJobStage.delivering,
              completed: progress.completed,
              total: progress.total,
              message: progress.result.success
                  ? 'Delivered ${progress.result.filename}.'
                  : 'Delivery failed for ${progress.result.filename}.',
              deliveryProgress: progress,
            ),
          );
        },
        onProgressError: (error, stackTrace, _) {
          _handleCallbackError(
            options,
            warnings,
            'onDeliveryProgress',
            ChartExportJobStage.delivering,
            error,
            stackTrace,
          );
        },
      ),
    );
  }

  Future<T> _timedStage<T>(
    Map<ChartExportJobStage, Duration> stageDurations,
    ChartExportJobStage stage,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await operation();
    } finally {
      stopwatch.stop();
      _addStageDuration(stageDurations, stage, stopwatch.elapsed);
    }
  }

  T _timedSyncStage<T>(
    Map<ChartExportJobStage, Duration> stageDurations,
    ChartExportJobStage stage,
    T Function() operation,
  ) {
    final stopwatch = Stopwatch()..start();
    try {
      return operation();
    } finally {
      stopwatch.stop();
      _addStageDuration(stageDurations, stage, stopwatch.elapsed);
    }
  }

  void _addStageDuration(
    Map<ChartExportJobStage, Duration> stageDurations,
    ChartExportJobStage stage,
    Duration duration,
  ) {
    stageDurations[stage] = (stageDurations[stage] ?? Duration.zero) + duration;
  }

  void _recordEvent(
    ChartExportJobOptions options,
    List<String> warnings,
    List<ChartExportJobEvent> events,
    ChartExportJobEvent event,
  ) {
    events.add(event);
    final handler = options.onEvent;
    if (handler == null) return;

    try {
      handler(event);
    } catch (error, stackTrace) {
      final callbackError = ChartExportJobCallbackError(
        callbackName: 'onEvent',
        stage: event.stage,
        error: error,
        stackTrace: stackTrace,
      );
      events.add(
        ChartExportJobEvent(
          type: ChartExportJobEventType.callbackError,
          stage: event.stage,
          message: callbackError.message,
          metadata: callbackError.toMetadataJson(),
        ),
      );
      _handleCallbackError(
        options,
        warnings,
        'onEvent',
        event.stage,
        error,
        stackTrace,
      );
    }
  }

  void _emit(
    ChartExportJobOptions options,
    List<String> warnings,
    ChartExportJobProgress progress,
  ) {
    _callCallback(
      options,
      warnings,
      'onProgress',
      progress.stage,
      () => options.onProgress?.call(progress),
    );
  }

  Future<void> _callAsyncCallback(
    ChartExportJobOptions options,
    List<String> warnings,
    String callbackName,
    ChartExportJobStage? stage,
    FutureOr<void> Function() callback,
  ) async {
    try {
      await callback();
    } catch (error, stackTrace) {
      _handleCallbackError(
        options,
        warnings,
        callbackName,
        stage,
        error,
        stackTrace,
      );
    }
  }

  void _callCallback(
    ChartExportJobOptions options,
    List<String> warnings,
    String callbackName,
    ChartExportJobStage? stage,
    void Function() callback,
  ) {
    try {
      callback();
    } catch (error, stackTrace) {
      _handleCallbackError(
        options,
        warnings,
        callbackName,
        stage,
        error,
        stackTrace,
      );
    }
  }

  void _handleCallbackError(
    ChartExportJobOptions options,
    List<String> warnings,
    String callbackName,
    ChartExportJobStage? stage,
    Object error,
    StackTrace stackTrace,
  ) {
    final callbackError = ChartExportJobCallbackError(
      callbackName: callbackName,
      stage: stage,
      error: error,
      stackTrace: stackTrace,
    );
    _addWarning(warnings, callbackError.message);

    final handler = options.onCallbackError;
    if (handler != null) {
      try {
        handler(callbackError);
      } catch (handlerError, handlerStackTrace) {
        final handlerCallbackError = ChartExportJobCallbackError(
          callbackName: 'onCallbackError',
          stage: stage,
          error: handlerError,
          stackTrace: handlerStackTrace,
        );
        _addWarning(warnings, handlerCallbackError.message);
        if (!options.continueOnCallbackError) {
          Error.throwWithStackTrace(handlerError, handlerStackTrace);
        }
      }
    }

    if (!options.continueOnCallbackError) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  bool _cancelled(ChartExportCancellationToken token) => token.isCancelled;
}

void _addWarning(List<String> warnings, String warning) {
  final normalized = warning.trim();
  if (normalized.isEmpty || warnings.contains(normalized)) return;
  warnings.add(normalized);
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _formatDuration(Duration duration) {
  if (duration.inMicroseconds < 1000) return '${duration.inMicroseconds}us';
  if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds}ms';
  return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
}

String _plural(String singular, int count) {
  if (count == 1) return singular;
  return switch (singular) {
    'delivery' => 'deliveries',
    _ => '${singular}s',
  };
}
